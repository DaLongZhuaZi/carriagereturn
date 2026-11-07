/**
 * 回车 · 主屏（§2.5 自适应几何重构版）
 *
 * 唯一全局规则：舞台定宽、高度全屏。
 *   stageWidth = min(屏宽, 屏高 × 390/844)，舞台高 = 屏高，舞台水平居中，两侧是同一深底背景。
 * 顶栏 / 纸面区 / 字车条 / 字体条 / 键区 / 功能行 / 字杆层 全部放进舞台容器，宽一律 = stageWidth。
 *
 * 只允许两类数值（§2.5）：① 与图片无关的绝对 vp（56 / 38 / 52 / 字号 17 / 行高 28、30 / 边距 28、24、20）；
 * ② 由图片宽高比派生的高度（键区 = stageWidth ÷ 2.101，字车条 = stageWidth ÷ 7.14）。不设 uiScale。
 */
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { curves, display, window } from '@kit.ArkUI';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';
import { image } from '@kit.ImageKit';
import { pdfService } from '@kit.PDFKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { resourceManager } from '@kit.LocalizationKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { CorrectionMode, DocLine, MachineKind, PaperKind, RibbonKind } from '../model/DocModel';
import {
  CARRIAGE_PAPER_OVERLAP_VP, DEFAULT_FONT, DEFAULT_MACHINE, DEFAULT_PAPER, DEFAULT_RIBBON,
  FONT_BAR_HEIGHT_VP, FUNCTION_ROW_HEIGHT_VP, PAPER_TOP_GAP_VP, TOP_BAR_HEIGHT_VP,
  findFont, findMachine, findPaper, findRibbon, fontDisplayName,
  FONTS,
} from '../model/MachineCatalog';
import { CapDef, KeymapLayout, KeymapParser, readRawTextSync } from '../model/KeymapModel';
import { PaperRow } from '../ui/PaperSheet';
import { DocModel } from '../model/DocModelCore';
import { docStore } from '../services/DocStore';
import { dossierStore } from '../services/DossierStore';
import { DossierPage } from '../components/DossierPage';
import { DossierDetailPage } from '../components/DossierDetailPage';
import { DocumentViewPage } from '../components/DocumentViewPage';
import { CollectionPage } from '../components/CollectionPage';
import { CustomizePage } from '../components/CustomizePage';
import { CollectionDetailPage } from '../components/CollectionDetailPage';
import { SettingsPage } from '../components/SettingsPage';
import { ExportPage } from '../components/ExportPage';
import { HomePage } from '../components/HomePage';
import { chineseInput } from '../services/ChineseInput';
import { PinyinEngine, PinyinSession, Candidate, PickResult } from '../services/PinyinEngine';
import { CandidateBar } from '../components/CandidateBar';
import { PinyinSettingsPage } from '../components/PinyinSettingsPage';
import { appPreferences, PrefKeys } from '../services/AppPreferences';
import { KeyboardAvoidMode as UcKeyboardAvoidMode } from '@ohos.arkui.UIContext';
import { AppMenu } from '../components/AppMenu';
import { DocData, DocSummary } from '../model/DocModel';
import { AudioService } from '../services/AudioService';
import { TopBar } from '../components/TopBar';
import { CarriageStrip } from '../components/CarriageStrip';
import { FontBar } from '../components/FontBar';
import { PhotoKeybed } from '../components/PhotoKeybed';
import { FunctionRow } from '../components/FunctionRow';
import { PageRail } from '../components/PageRail';
import { PaperStage, PAPER_INITIAL_HEIGHT_VP } from '../components/PaperStage';
import { TypebarLayer } from '../components/TypebarLayer';
import { CarriageLayers } from '../components/CarriageLayers';
import { LeverLayer } from '../components/LeverLayer';

const TAG: string = 'MainScreen';
const DOMAIN: number = 0x0100;
const DESIGN_W: number = 390;
const DESIGN_H: number = 844;
/** 键带手机宽高比 2048/975；字车条 2048/287。 */
const KEYBAND_ASPECT: number = 2048 / 975;
const CARRIAGE_STRIP_ASPECT: number = 2048 / 287;
const GROW_DURATION_MS: number = 60; // 硬曲线：纸移动 50–70ms，写死
const BELL_REMAINING: number = 8;

function emptyLayout(): KeymapLayout {
  return {
    machine: '', caps: [], spaceXMin: 0, spaceXMax: 0, spaceYMin: 0, spaceYMax: 0,
    hitRadius: 10, overlayColor: '#000000', overlayFontSize: 14, widthVp: 0, heightVp: 0,
  };
}

// ---- 字符键盘表（不进 keymap json；按行顺序，与 4 行键位一一对应）----
const SYM_EN: string[][] = [
  '! @ # $ % ^ & * ( ) _'.split(' '),
  '+ - = [ ] { } ; : \''.split(' '),
  '" , . / < > ? \\ | ~ `'.split(' '),
  '€ £ ¥ ¢ § © ® ™ ° ±'.split(' '),
];
const SYM_ZH: string[][] = [
  '， 。 ！ ？ ； ： 、 （ ） 《 》'.split(' '),
  '「 」 『 』 【 】 … — · ￥'.split(' '),
  '％ ＃ ＠ ～ ＋ － ＝ ＿ ｜ ＼ ／'.split(' '),
  '＜ ＞ ＂ ＇ ※ ☆ ★ ○ ● ◆'.split(' '),
];
/** 数字/标点键的上档映射。 */
const SHIFT_MAP: Record<string, string> = {
  '1': '!', '2': '@', '3': '#', '4': '$', '5': '%', '6': '^', '7': '&', '8': '*', '9': '(', '0': ')',
  '-': '_', ';': ':', '\'': '"', ',': '<', '.': '>', '/': '?',
};

@Entry
@Component
struct Index {
  private docModel: DocModel = new DocModel();
  private docId: string = '';
  private saveTimer: number = -1;
  private lastArriveMs: number = 0;
  private arriveGapSumMs: number = 0;
  private arriveGapCount: number = 0;
  private droppedTicks: number = 0;
  private soundCount: number = 0;
  private fastCount: number = 0;
  @State arriveCount: number = 0;
  /** 总成竖向 jolt（vp）：打字当刻下沉 1vp。 */
  @State joltYVp: number = 0;
  /** 落字计数：驱动 PhotoKeybed 清高亮。 */
  @State commitSeq: number = 0;
  /** 旋钮累计转角（度，走纸期间线性增加，不回零）。 */
  @State knobAngle: number = 0;
  /** 总成 Stack 实测高度 Ht（vp）：不用 paperHeightVp 冒充。 */
  @State assemblyHeightVp: number = 0;
  /** 模型 B：纸顶 / 落字行 / 字车条 三处 y（相对总成 Stack 顶，vp）。 */
  @State paperTopVp: number = 0;
  /** 换纸进行中：禁打字。 */
  @State paperChanging: boolean = false;
  /** 换纸时旧纸淡出用。 */
  @State paperOpacity: number = 1;
  /** 换纸第①步：纸容器切「整张模式」（高=Ph、不裁），整张纸飞出去。 */
  @State paperFullSheet: boolean = false;
  /** 滚筒纹理纵向滚动量（vp）：随纸上滑同步，换纸两段各滚半圈。 */
  @State texOffsetVp: number = 0;
  /** 换行 600ms 编排进行中：落字先排队，编排完成后再落（不丢字、不错位）。 */
  @State newlineBusy: boolean = false;
  /** 退行动画进行中（纸 200ms + O 250ms）：落字先排队。 */
  @State backBusy: boolean = false;
  /** 本次换行是否为「下移一行」（下方有内容，不插行）。 */
  @State newlineMoveDown: boolean = false;
  /** 「下移」时字车要滑到的 O（小行程口径）。 */
  @State newlineCarriageTargetO: number = 0;
  private queuedChars: string[] = [];
  /** 纸片容器高 = 纸顶到滚筒（容器 clip，纸底藏在里面）。 */
  @State paperContainerVp: number = 0;
  @State paperTopTargetVp: number = 0;
  @State paperContainerTargetVp: number = 0;
  private paperAnimateNext: boolean = false;
  @State contentTopVp: number = 44;
  @State stackTopGlobalYVp: number = 0;
  /** H 冻结值（首次稳定测到的可用高）。 */
  private frozenHVp: number = 0;
  @State strikeLineVp: number = 0;
  @State carriageTopVp: number = 0;
  /** 换行计数：驱动 LeverLayer 摆动。 */
  @State newlineTick: number = 0;
  /** 实测单字 advance（vp）：隐藏 Text 量宽得到，中英分开。 */
  @State advEngVp: number = 0;
  @State advCjkVp: number = 0;
  /** 整行渲染实测宽（隐藏 Text 的 onAreaChange）。 */
  @State lineWidthMeasuredVp: number = -1;
  private audioService: AudioService = new AudioService();
  private pendingChars: string[] = [];
  private bellRungLines: Set<number> = new Set<number>();

  @State rows: PaperRow[] = [];
  @State machineKind: MachineKind = DEFAULT_MACHINE;
  @State paperKind: PaperKind = DEFAULT_PAPER;
  @State ribbon: RibbonKind = DEFAULT_RIBBON;
  @State hintText: string = '';
  @State docTitle: string = '';
  @State inkColor: string = '#1a1a1a';
  @State keymapLayout: KeymapLayout = emptyLayout();

  /** 舞台几何（§2.5）。 */
  @State stageWidth: number = DESIGN_W;
  @State stageHeight: number = DESIGN_H;
  @State topBarHeight: number = TOP_BAR_HEIGHT_VP;
  @State paperTopGap: number = PAPER_TOP_GAP_VP;
  @State carriageHeight: number = DESIGN_W / CARRIAGE_STRIP_ASPECT;
  @State fontBarHeight: number = FONT_BAR_HEIGHT_VP;
  @State keybedHeight: number = DESIGN_W / KEYBAND_ASPECT;
  @State functionRowHeight: number = FUNCTION_ROW_HEIGHT_VP;
  @State regionHeightVp: number = 461;
  /** 窗口可用尺寸（vp，onAreaChange 实测，减 inset 后）。 */
  private winWidthVp: number = 0;
  private winHeightVp: number = 0;
  @State availableWidthVp: number = 390;
  @State availableHeightVp: number = 720;
  /** 平板级（可用宽 ≥600vp）。 */
  @State isTablet: boolean = false;
  /** 大屏独立设计宽：平板 min(stageWidth, 440)，手机 = stageWidth（原样）。 */
  private geoWidthVp(): number {
    if (this.isTablet) {
      return this.stageWidth < 440 ? this.stageWidth : 440;
    }
    return this.stageWidth;
  }
  /** 照片组件宽封顶（原生像素 guard，2048/vp2px(1)）。 */
  @State photoWidthCap: number = 0;

  @State paperHeightVp: number = PAPER_INITIAL_HEIGHT_VP;
  /** 纸宽 = 纸高 / 1.414（A4）。 */
  @State paperWidthVp: number = 240;
  /** 纸中心 x（相对舞台左缘）。 */
  @State paperCenterXVp: number = 195;
  @State creepOffsetVp: number = 0;
  @State lineHeightVp: number = 28;
  @State fontSizeVp: number = 17;
  @State fontFamily: string = 'CourierPrime';

  @State guideXVp: number = 28;
  /** 字车条累计左移量（vp）：负值左移，行首为 0。不是"换行时 12→0 的 bump"。 */
  @State carriageOffsetVp: number = 0;
  /** 每行可容纳字数（按舞台宽算，非屏幕宽）。 */
  private charsPerLineNum: number = 43;
  /** 每字行程 = 最大行程 / 每行字数。 */
  private travelPerChar: number = 1.5;
  /** 最大行程（vp）。 */
  private maxTravelVp: number = 64;
  @State strikeTick: number = 0;
  @State langZh: boolean = false;
  /** 中文预编辑串（只显示，不进模型）。 */
  @State cnPreview: string = '';
  /** 中文整词拆单字的 FIFO 队列与出队定时器。 */
  private cnQueue: string[] = [];
  private cnTimer: number = -1;
  @State cnKbShown: boolean = false;
  /** 锚点 TextInput 已消费的文本（用于算增量，避免重复落字）。 */
  private cnAnchorPrev: string = '';
  /** 本轮已选词次数（节流落盘用）。 */
  private cnPickCount: number = 0;
  /** 学习记录防抖落盘定时器。 */
  private learnSaveTimer: number = -1;
  @State fuzzyOn: boolean = false;
  @State userWordsFlat: string[] = [];
  @State dictInfo: string = '';
  /** 加词弹窗里可编辑的拼音串（§13 第 5 步 b）。 */
  @State draftPinyin: string = '';
  /** 上一个已提交字（§13 第 7 步上下文微调用）。 */
  private lastCommittedChar: string = '';
  @State learnCount: number = 0;

  /** 刷新拼音设置页展示数据。 */
  private refreshPinyinMeta(): void {
    this.fuzzyOn = appPreferences.getBool(PrefKeys.CN_FUZZY, false);
    try {
      const flat: string[] = [];
      if (this.pinyinEngine !== null) {
        const ex: Record<string, string[]> = this.pinyinEngine.exportUserWords();
        const ks: string[] = Object.keys(ex);
        for (let i = 0; i < ks.length; i++) {
          const arr: string[] = ex[ks[i]];
          for (let j = 0; j < arr.length; j++) { flat.push(arr[j]); }
        }
      }
      this.userWordsFlat = flat;
    } catch (e) {
      this.userWordsFlat = [];
    }
    // §13 第 4 步：词库信息读实际数，不许再手写
    if (this.pinyinEngine !== null) {
      this.dictInfo = '内置拼音词库 ' + this.pinyinEngine.syllableCount().toString() + ' 音节 / '
        + this.pinyinEngine.wordCount().toString() + ' 词条 / 含我的词库 '
        + this.userWordsFlat.length.toString() + ' 条';
    } else {
      this.dictInfo = '词库未加载';
    }
    let lc: number = 0;
    if (this.pinyinEngine !== null) {
      const ex: Record<string, Record<string, number>> = this.pinyinEngine.exportLearn();
      const ks2: string[] = Object.keys(ex);
      for (let i = 0; i < ks2.length; i++) { lc += Object.keys(ex[ks2[i]]).length; }
    }
    this.learnCount = lc;
  }

  private toggleFuzzy(): void {
    const next: boolean = !this.fuzzyOn;
    this.fuzzyOn = next;
    appPreferences.setBool(PrefKeys.CN_FUZZY, next);
    if (this.pinyinEngine !== null) {
      this.pinyinEngine.setFuzzy(next);
    }
    this.pinyinRefresh();
  }

  private async addUserWord(w: string): Promise<void> {
    // 设置页里引擎可能还没加载（引擎原本只在进中文模式时加载）
    await this.ensurePinyinEngine();
    if (this.pinyinEngine === null) {
      this.hintText = '词库未加载，暂时加不了';
      return;
    }
    const py: string = this.pinyinOfWordForAdd(w);
    if (py.length === 0) {
      this.hintText = '这个词里有字库外的字，暂时加不了';
      return;
    }
    // 多读音变体一起入库（大龙爪子：zhuazi 与 zhaozi 都能打出来）
    const vars: string[] = this.pinyinEngine.pinyinVariantsOfWord(w);
    for (let i = 0; i < vars.length; i++) {
      this.pinyinEngine.addUserWordWithPinyin(vars[i], w);
    }
    this.pinyinEngine.addUserWordWithPinyin(py, w);
    this.pinyinEngine.rebuildAbbrev();
    this.persistUserWords();
    this.refreshPinyinMeta();
  }

  /** 加词用的拼音（用户可在弹窗里改；未改则用引擎推导）。 */
  private pinyinOfWordForAdd(w: string): string {
    if (this.pinyinEngine === null) {
      return '';
    }
    if (this.draftPinyin.length > 0) {
      return this.draftPinyin.trim().toLowerCase();
    }
    return this.pinyinEngine.pinyinOfWord(w);
  }

  private deleteUserWord(w: string): void {
    if (this.pinyinEngine === null) {
      return;
    }
    try {
      const uj: string = appPreferences.getString(PrefKeys.CN_USERWORDS, '');
      if (uj.length > 2) {
        const data: Record<string, string[]> = JSON.parse(uj) as Record<string, string[]>;
        const ks: string[] = Object.keys(data);
        for (let i = 0; i < ks.length; i++) {
          const arr: string[] = data[ks[i]];
          const idx: number = arr.indexOf(w);
          if (idx >= 0) {
            arr.splice(idx, 1);
          }
          if (arr.length === 0) {
            data[ks[i]] = [];
          }
        }
        appPreferences.setString(PrefKeys.CN_USERWORDS, JSON.stringify(data));
        this.pinyinEngine.setUserWords(data);
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'delete user word failed');
    }
    this.refreshPinyinMeta();
  }

  private clearLearn(): void {
    appPreferences.setString(PrefKeys.CN_LEARN, '{}');
    appPreferences.setString(PrefKeys.CN_BIGRAM, '{}');
    if (this.pinyinEngine !== null) {
      this.pinyinEngine.setLearnData({});
      this.pinyinEngine.setBigrams({});
    }
    this.refreshPinyinMeta();
    this.hintText = '学习记录已清除';
  }

  /** 落我的词库：直接取引擎当前状态（含刚加入的词），不用过期的展示列表。 */
  private persistUserWords(): void {
    if (this.pinyinEngine === null) {
      return;
    }
    try {
      const dump: Record<string, string[]> = this.pinyinEngine.exportUserWords();
      appPreferences.setString(PrefKeys.CN_USERWORDS, JSON.stringify(dump));
      hilog.info(DOMAIN, TAG, 'userwords saved keys=%{public}s', Object.keys(dump).length.toString());
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'persist user words failed');
    }
  }

  // ---------------- 内置拼音（设计稿 §1／§3／§4） ----------------
  /** 中文引擎：'builtin' 内置拼音（默认）｜'system' 系统输入法通道。 */
  @State cnEngine: string = 'builtin';
  /** 候选栏当前页候选（最多 9 个）与页码。 */
  @State candCurrent: string[] = [];
  @State candPage: number = 0;
  @State candPages: number = 1;
  /** 组词中的拼音串（显示在候选栏左侧，并复用 cnPreview 做预编辑）。 */
  @State cnPinyin: string = '';
  @State pinyinReady: boolean = false;
  @State pinyinLoadFailed: boolean = false;
  private pinyinEngine: PinyinEngine | null = null;
  private pinyinSession: PinyinSession | null = null;
  private candAll: Candidate[] = [];

  /** 读偏好里的引擎（设置页改了就落盘）。 */
  private readCnEngine(): void {
    this.cnEngine = appPreferences.getString(PrefKeys.CN_ENGINE, 'builtin');
  }

  /** 异步加载拼音词库（不许主线程同步解析几 MB）。 */
  private async ensurePinyinEngine(): Promise<void> {
    if (this.pinyinEngine !== null || this.pinyinLoadFailed) {
      return;
    }
    try {
      const rm = this.getUIContext().getHostContext()?.resourceManager;
      if (rm === undefined || rm === null) {
        this.pinyinLoadFailed = true;
        return;
      }
      const bytes: Uint8Array = await rm.getRawFileContent('dict/pinyin-chars.json');
      const charsText: string = this.decodeUtf8(bytes);
      const wordsBytes: Uint8Array = await rm.getRawFileContent('dict/pinyin-words.json');
      const wordsText: string = this.decodeUtf8(wordsBytes);
      const chars: Record<string, string[]> = JSON.parse(charsText) as Record<string, string[]>;
      const words: Record<string, string[]> = JSON.parse(wordsText) as Record<string, string[]>;
      this.pinyinEngine = PinyinEngine.fromData({ chars: chars, words: words });
      this.pinyinSession = new PinyinSession(this.pinyinEngine);
      this.pinyinReady = true;
      // 套用持久化：模糊音开关、选词学习、我的词库
      this.pinyinEngine.setFuzzy(appPreferences.getBool(PrefKeys.CN_FUZZY, false));
      this.loadLearnAndUserWords();
      this.ensureBigrams();
      hilog.info(DOMAIN, TAG, 'pinyin engine ready syllables=%{public}s',
        this.pinyinEngine.syllableCount().toString());
    } catch (e) {
      this.pinyinLoadFailed = true;
      hilog.error(DOMAIN, TAG, 'pinyin dict load failed');
    }
  }

  /**
   * §13 第 7 步：字符级 bigram（只读本机文档，零遥测）。
   * 优先用已落盘数据；没有则扫全部文档正文统计相邻字对（上限 5000），并落盘。
   */
  private ensureBigrams(): void {
    if (this.pinyinEngine === null) {
      return;
    }
    try {
      const saved: string = appPreferences.getString(PrefKeys.CN_BIGRAM, '');
      if (saved.length > 2) {
        const data: Record<string, Record<string, number>> =
          JSON.parse(saved) as Record<string, Record<string, number>>;
        this.pinyinEngine.setBigrams(data);
        hilog.info(DOMAIN, TAG, 'bigram loaded pairs=%{public}s',
          this.pinyinEngine.bigramCount().toString());
        return;
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'bigram json bad');
    }
    const counts: Map<string, Map<string, number>> = new Map<string, Map<string, number>>();
    let pairs: number = 0;
    const list: DocSummary[] = docStore.list();
    for (let i = 0; i < list.length; i++) {
      const d: DocData | null = docStore.load(list[i].id);
      if (d === null) {
        continue;
      }
      let prev: string = '';
      for (let ln = 0; ln < d.lines.length; ln++) {
        const text: string = d.lines[ln].text;
        for (let c = 0; c < text.length; c++) {
          const ch: string = text.charAt(c);
          if (prev.length > 0) {
            let m: Map<string, number> | undefined = counts.get(prev);
            if (m === undefined) {
              m = new Map<string, number>();
              counts.set(prev, m);
            }
            const cur: number = m.get(ch) === undefined ? 0 : m.get(ch) as number;
            if (cur === 0) {
              pairs = pairs + 1;
            }
            m.set(ch, cur + 1);
          }
          prev = ch;
        }
        prev = '';
      }
    }
    const dump: Record<string, Record<string, number>> = {};
    let kept: number = 0;
    counts.forEach((m: Map<string, number>, k: string) => {
      if (kept >= 5000) {
        return;
      }
      const inner: Record<string, number> = {};
      m.forEach((n: number, w: string) => { inner[w] = n; });
      dump[k] = inner;
      kept = kept + m.size;
    });
    this.pinyinEngine.setBigrams(dump);
    appPreferences.setString(PrefKeys.CN_BIGRAM, JSON.stringify(dump));
    hilog.info(DOMAIN, TAG, 'bigram built pairs=%{public}s from docs=%{public}s',
      this.pinyinEngine.bigramCount().toString(), list.length.toString());
  }

  /** 读学习记录与我的词库（JSON 存 AppPreferences）。 */
  private loadLearnAndUserWords(): void {
    if (this.pinyinEngine === null) {
      return;
    }
    try {
      const lj: string = appPreferences.getString(PrefKeys.CN_LEARN, '');
      if (lj.length > 2) {
        const data: Record<string, Record<string, number>> = JSON.parse(lj) as Record<string, Record<string, number>>;
        this.pinyinEngine.setLearnData(data);
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'learn json bad');
    }
    try {
      const uj: string = appPreferences.getString(PrefKeys.CN_USERWORDS, '');
      if (uj.length > 2) {
        const data2: Record<string, string[]> = JSON.parse(uj) as Record<string, string[]>;
        this.pinyinEngine.setUserWords(data2);
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'userwords json bad');
    }
  }

  /** 落学习记录（节流：离开中文模式时 + 每 10 次选词）。 */
  private saveLearn(): void {
    if (this.pinyinEngine === null) {
      return;
    }
    try {
      const data: Record<string, Record<string, number>> = this.pinyinEngine.exportLearn();
      appPreferences.setString(PrefKeys.CN_LEARN, JSON.stringify(data));
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'save learn failed');
    }
  }

  /** Uint8Array → UTF-8 字符串（与 KeymapModel.readRawTextSync 同口径）。 */
  private decodeUtf8(bytes: Uint8Array): string {
    let out: string = '';
    let i: number = 0;
    while (i < bytes.length) {
      const c: number = bytes[i];
      if (c < 0x80) {
        out += String.fromCharCode(c);
        i += 1;
      } else if (c < 0xE0 && i + 1 < bytes.length) {
        out += String.fromCharCode(((c & 0x1F) << 6) | (bytes[i + 1] & 0x3F));
        i += 2;
      } else if (c < 0xF0 && i + 2 < bytes.length) {
        out += String.fromCharCode(((c & 0x0F) << 12) | ((bytes[i + 1] & 0x3F) << 6) | (bytes[i + 2] & 0x3F));
        i += 3;
      } else if (i + 3 < bytes.length) {
        const cp: number = ((c & 0x07) << 18) | ((bytes[i + 1] & 0x3F) << 12) | ((bytes[i + 2] & 0x3F) << 6) | (bytes[i + 3] & 0x3F);
        out += String.fromCodePoint(cp);
        i += 4;
      } else {
        break;
      }
    }
    return out;
  }
  /** 键盘避让上移量（vp）：键盘弹起时按打击行位置算，收起归零。 */
  @State kbShift: number = 0;

  /** 中文通道：整词拆单字，40ms 逐字走 commitChar（复用现有落字链）。 */
  private enqueueChinese(text: string): void {
    for (let i = 0; i < text.length; i++) {
      const ch: string = text.charAt(i);
      if (ch === '\n') {
        this.onNewline();
      } else {
        this.cnQueue.push(ch);
      }
    }
    if (this.cnTimer < 0) {
      this.cnTimer = setInterval(() => {
        if (this.cnQueue.length === 0) {
          clearInterval(this.cnTimer);
          this.cnTimer = -1;
          return;
        }
        const c: string = this.cnQueue.shift() as string;
        this.lastCommittedChar = c;
        hilog.info(DOMAIN, TAG, 'cn commit ch=%{public}s left=%{public}s docLen=%{public}s',
          c, this.cnQueue.length.toString(), this.docModel.getLines().length.toString());
        this.commitChar(c);
      }, 40);
    }
  }

  /** 中文模式下要离页：先退回英文（键盘是独立窗口，不会跟着收）。防重入由 detach 自身保证。 */
  private leaveChinese(): void {
    if (!this.langZh) {
      return;
    }
    if (this.cnEngine === 'builtin') {
      // 内置拼音：退出组词先提交首选候选，绝不丢已敲字母；并把学习记录落盘
      this.pinyinCommitTop();
      this.saveLearn();
      this.cnPinyin = '';
      this.candAll = [];
      this.candCurrent = [];
    }
    this.langZh = false;
    this.cnPreview = '';
    chineseInput.detach();
    hilog.info(DOMAIN, TAG, 'cn leave page -> back to EN');
  }

  /** 把当前光标矩形推给输入法（候选窗跟随光标）。与 attach 同一口径：vp → px。 */
  private pushCnCursor(): void {
    if (!this.langZh) {
      return;
    }
    const ui = this.getUIContext();
    chineseInput.updateCursorRect(
      ui.vp2px((this.stageWidth - this.paperWidthVp) / 2),
      ui.vp2px(this.strikeLineVp),
      ui.vp2px(this.paperWidthVp),
      ui.vp2px(this.lineHeightVp));
  }

  /** 中/EN 切换：只在这里 attach / detach（换行、换纸、换机都不动）。 */
  private async applyChineseMode(on: boolean): Promise<void> {
    if (on && this.cnEngine === 'builtin') {
      // 内置拼音：绝不 attach、绝不 focus 锚点、不弹系统键盘
      this.cnPreview = '';
      this.cnPinyin = '';
      await this.ensurePinyinEngine();
      if (this.pinyinLoadFailed) {
        this.hintText = '词库加载失败，仅单字';
      }
      hilog.info(DOMAIN, TAG, 'cn builtin mode ready=%{public}s', this.pinyinReady ? 'true' : 'false');
      return;
    }
    if (on) {
      // 锚点必须聚焦，否则 attach 报 12800009（input method client detached）
      focusControl.requestFocus('cn_anchor');
      await new Promise<void>((resolve: () => void) => {
        setTimeout(() => { resolve(); }, 150);
      });
      const ui = this.getUIContext();
      const left: number = ui.vp2px((this.stageWidth - this.paperWidthVp) / 2);
      const top: number = ui.vp2px(this.strikeLineVp);
      const ok: boolean = await chineseInput.attach({
        onInsertText: (t: string): void => { this.enqueueChinese(t); },
        onDeleteLeft: (n: number): void => {
          if (this.cnPreview.length > 0) {
            // 拼音未上屏：退格只属于预编辑，等 setPreviewText 缩短预编辑串，不许删已提交字符
            hilog.info(DOMAIN, TAG, 'cn deleteLeft n=%{public}s preview locked', n.toString());
            return;
          }
          hilog.info(DOMAIN, TAG, 'cn deleteLeft n=%{public}s', n.toString());
          for (let i = 0; i < n; i++) { this.onDelete(); }
        },
        onDeleteRight: (n: number): void => {
          // 光标恒在行尾、右侧无字 → 无操作（走 onDelete 会误删最后一个字）
          hilog.info(DOMAIN, TAG, 'cn deleteRight n=%{public}s ignored', n.toString());
        },
        onMoveCursor: (dir: number): void => {
          hilog.info(DOMAIN, TAG, 'cn moveCursor dir=%{public}s (append-only)', dir.toString());
        },
        onPreview: (t: string): void => {
          hilog.info(DOMAIN, TAG, 'cn preview len=%{public}s', t.length.toString());
          this.cnPreview = t;
        },
        onFinishPreview: (): void => {
          hilog.info(DOMAIN, TAG, 'cn finishPreview');
          this.cnPreview = '';
        },
        onEnter: (): void => {
          hilog.info(DOMAIN, TAG, 'cn enter');
          this.onNewline();
          // 换行编排有动画，稍等再推一次光标矩形
          setTimeout(() => { this.pushCnCursor(); }, 300);
        },
        onKeyboardShown: (s: boolean): void => { this.cnKbShown = s; },
      }, left, top, ui.vp2px(this.paperWidthVp), ui.vp2px(this.lineHeightVp));
      hilog.info(DOMAIN, TAG, 'cn attach ok=%{public}s', ok ? 'true' : 'false');
      if (!ok) {
        // 兜底：不许静默死在「中文模式但没键盘」
        this.langZh = false;
        this.cnPreview = '';
        this.hintText = '输入法连接失败，已切回英文';
        hilog.error(DOMAIN, TAG, 'cn attach failed -> fallback to EN');
      }
    } else {
      this.cnPreview = '';
      await chineseInput.detach();
    }
  }
  /** 卷宗页开合（§5.1）。 */
  @State dossierOpen: boolean = false;
  /** 当前打开的卷宗 id（空串＝未归档）。 */
  @State openDossierId: string = '';
  /** 卷宗内页是否展开（§5.2）；与 openDossierId 分开，避免空 id 恒真。 */
  @State detailOpen: boolean = false;
  /** 纸列表版本号：卷宗内页每次新建/删除纸后 +1，驱动重算。 */
  @State docsRev: number = 0;
  /** 文档视图（§5.3）：非空则显示。 */
  @State openDocId: string = '';
  /** 收藏页（§3）开合。 */
  @State collectionOpen: boolean = false;
  /** 换装页（§4）开合。 */
  @State customizeOpen: boolean = false;
  /** 收藏详情页：非空则显示（已解锁机器）。 */
  @State collectionDetailKind: string = '';
  /** §6.1／§6.2 设置页与导出页。 */
  @State settingsOpen: boolean = false;
  @State pinyinSettingsOpen: boolean = false;
  @State exportOpen: boolean = false;
  /** §11：冷启动首帧就是主页。 */
  @State homeOpen: boolean = true;

  /** 导航栈（AGENTS「导航」）：栈底永远是 'home'。页内返回与系统返回都走弹栈。 */
  @State navStack: string[] = ['home'];
  /** 冷启动首帧不做进入动画；第一次页面切换后才启用过渡。 */
  @State navAnimated: boolean = false;

  /** 按栈同步各覆盖层开合（渲染仍读这些布尔量）。 */
  private syncFromStack(): void {
    const has = (k: string): boolean => this.navStack.indexOf(k) >= 0;
    this.homeOpen = this.navStack.length === 1;
    this.dossierOpen = has('dossier') || has('detail') || has('docview');
    this.detailOpen = has('detail') || has('docview');
    if (!has('docview')) { this.openDocId = ''; }
    this.collectionOpen = has('collection') || has('collectiondetail');
    if (!has('collectiondetail')) { this.collectionDetailKind = ''; }
    this.customizeOpen = has('customize');
    this.settingsOpen = has('settings') || has('pinyinsettings');
    this.pinyinSettingsOpen = has('pinyinsettings');
    this.exportOpen = has('export');
    hilog.info(DOMAIN, TAG, 'nav depth=%{public}s top=%{public}s',
      this.navStack.length.toString(), this.navStack[this.navStack.length - 1]);
  }

  private pushPage(k: string): void {
    this.leaveChinese();
    this.navAnimated = true;
    // 同 key 已在栈顶时不重复压栈（返回少走一步）
    if (this.navStack[this.navStack.length - 1] === k) {
      return;
    }
    const s: string[] = this.navStack.slice();
    s.push(k);
    this.navStack = s;
    this.syncFromStack();
  }

  /** 回退到栈中的某页（连同其上所有页一起撤掉）。 */
  private popTo(k: string): void {
    const idx: number = this.navStack.indexOf(k);
    if (idx < 0) { return; }
    this.leaveChinese();
    this.navAnimated = true;
    const s: string[] = this.navStack.slice(0, idx + 1);
    this.navStack = s;
    this.syncFromStack();
  }

  /** 弹一层；栈底是主页时返回 false（交给系统退出 App）。 */
  private popPage(): boolean {
    if (this.navStack.length <= 1) { return false; }
    this.leaveChinese();
    this.navAnimated = true;
    const s: string[] = this.navStack.slice();
    s.pop();
    this.navStack = s;
    this.syncFromStack();
    return true;
  }

  /** 系统返回：先关菜单，再弹栈；栈底主页时返回 false。 */
  onBackPress(): boolean {
    hilog.info(DOMAIN, TAG, 'onBackPress depth=%{public}s', this.navStack.length.toString());
    if (this.menuOpen) {
      this.menuOpen = false;
      return true;
    }
    return this.popPage();
  }
  /** D1：汉堡下拉菜单。 */
  @State menuOpen: boolean = false;
  /** 换装淡入淡出（§4：200ms，不重建编辑器、不丢光标）。1 = 正常，切换瞬间压到 0.35 再回到 1。 */
  @State switchFade: number = 1;
  /** P1-4：注册失败的字体族名（换装页据此标「未加载」）。 */
  @State fontLoadFailed: string[] = [];
  /** P1-8：list() 结果缓存（docsRev 变才重算，不许 build 里每次都调）。 */
  private docsCache: DocSummary[] = [];
  private docsCacheRev: number = -1;
  /** Shift 锁定式（打字机字档锁）：按一次开、再按关。 */
  @State shiftActive: boolean = false;
  /** 底部「字符」键：true = 符号键盘。 */
  @State symbolMode: boolean = false;
  @State correctionMode: CorrectionMode = CorrectionMode.MODERN;
  /** 1920s 分层字车是否可用（层文件缺失时回退旧 strip，不许空白/崩溃）。 */
  @State useLayers: boolean = false;
  /** 动态安全区（vp）：取不到时 topInset 回退 28、bottomInset 回退 0（§2.9）。 */
  @State topInset: number = 28;
  @State bottomInset: number = 0;

  aboutToAppear(): void {
    // 读取持久化的中文引擎（默认内置拼音）
    this.readCnEngine();
    // §7.4：系统键盘弹起时页面整体上移（OFFSET），保打击行可见
    try {
      // 用 UIContext 导出的 KeyboardAvoidMode（OFFSET=0 页面上移 / RESIZE=1），避开组件作用域同名枚举
      this.getUIContext().setKeyboardAvoidMode(UcKeyboardAvoidMode.OFFSET);
      // 监听键盘高度：按「打击行 vs 键盘顶」差值上移舞台，保打击行可见
      window.getLastWindow(this.getUIContext().getHostContext() as common.Context)
        .then((win: window.Window) => {
          win.on('keyboardHeightChange', (h: number) => {
            const kbVp: number = this.getUIContext().px2vp(h);
            const top: number = this.stageHeight - kbVp;
            this.kbShift = h > 0 ? Math.max(0, this.strikeLineVp + 40 - top) : 0;
            hilog.info(DOMAIN, TAG, 'kb height=%{public}s shift=%{public}s',
              h.toString(), this.kbShift.toFixed(1));
          });
        })
        .catch((e: BusinessError) => {
          hilog.warn(DOMAIN, TAG, 'keyboard listener failed code=%{public}s', e.code.toString());
        });
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'setKeyboardAvoidMode failed');
    }
    // 字体注册放在页面（UIContext 已就绪）而不是 Ability.onCreate：
    // 上一轮实测 onCreate 里注册两次都打 ok 但 i/m 仍比例字体
    // P1-4：按 MachineCatalog.FONTS 表逐一注册 17 款字体（原来只注册了 CourierPrime，
    // 其余 16 款在换装页会静默回落到系统字体 → 17 行试写分不出差别）
    const failed: string[] = [];
    for (let i = 0; i < FONTS.length; i++) {
      try {
        this.getUIContext().getFont().registerFont({
          familyName: FONTS[i].familyName,
          familySrc: $rawfile(FONTS[i].rawfile),
        });
        hilog.info(DOMAIN, TAG, 'registerFont ok %{public}s <- %{public}s',
          FONTS[i].familyName, FONTS[i].rawfile);
      } catch (e) {
        failed.push(FONTS[i].familyName);
        hilog.error(DOMAIN, TAG, 'registerFont FAILED %{public}s <- %{public}s',
          FONTS[i].familyName, FONTS[i].rawfile);
      }
    }
    this.fontLoadFailed = failed;
    hilog.info(DOMAIN, TAG, 'registerFont total=%{public}s failed=%{public}s',
      FONTS.length.toString(), failed.length.toString());

    const host = this.getUIContext().getHostContext();
    if (host !== undefined && host !== null) {
      this.audioService.attachContext(host as common.Context);
    }
    this.docTitle = this.resolveString($r('app.string.doc_untitled'));
    this.measureStage();
    this.applyMachine(DEFAULT_MACHINE);
    this.applyPaper(DEFAULT_PAPER);
    this.applyRibbon(DEFAULT_RIBBON);
    this.reloadKeymap();
    this.detectLayers();
    this.applyImmersive();
    this.hintText = this.resolveString($r('app.string.hint_new_paper'));
    this.restoreLastDocument();
    this.syncRows();
    // 启动即有 O：按当前行光标重算，不许归 0
    this.recalcTravel();
    this.recalcOffsetFromCursor();
    this.audioService.preload('pack');
  }

  aboutToDisappear(): void {
    this.audioService.release();
  }

  // ---------------- §2.5 舞台几何 ----------------

  /**
   * 全屏对角线英寸数（§2.6）：用全屏 display 的 px 与 densityDPI 算，只用于判定设备尺寸，
   * 量窗口仍用 onAreaChange。
   */
  private screenDiagonalInch(): number {
    try {
      const d = display.getDefaultDisplaySync();
      const dx: number = d.width / d.densityDPI;
      const dy: number = d.height / d.densityDPI;
      return Math.sqrt(dx * dx + dy * dy);
    } catch (e) {
      return 0;
    }
  }

  /** 照片组件宽：超过原生像素 guard 封顶并居中（舞台宽本身不封顶）。 */
  private photoW(): number {
    if (this.photoWidthCap > 0 && this.stageWidth > this.photoWidthCap) {
      return this.photoWidthCap;
    }
    return this.stageWidth;
  }

  /** 设备类型（phone / tablet / 2in1 / ...）。 */
  private deviceTypeName(): string {
    try {
      return deviceInfo.deviceType;
    } catch (e) {
      return 'unknown';
    }
  }

  private measureStage(): void {
    try {
      // §2.6/§2.9：输入一律来自 onAreaChange 存的窗口宽高，不再读 display
      const winW: number = this.winWidthVp;
      const winH: number = this.winHeightVp;
      if (winW <= 0 || winH <= 0) {
        hilog.error(DOMAIN, TAG, 'measureStage skipped: winW=%{public}s winH=%{public}s',
          winW.toFixed(1), winH.toFixed(1));
        return;
      }
      // 可用宽 = 窗口宽 − 左右安全区（本批只取上下，左右按 0）
      const availW: number = winW;
      // 可用高 = 窗口高 − topInset − bottomInset
      const availH: number = winH - this.topInset - this.bottomInset;
      if (availH <= 240) {
        return;
      }
      this.availableWidthVp = availW;
      this.availableHeightVp = availH;
      // §2.9 新口径：deviceType 为 tablet/2in1 且可用宽 ≥600vp 才是平板级；其余 deviceType 回退宽度单条件
      // §2.6：tabletDevice = deviceType tablet/2in1 或 全屏对角线 ≥7.0 英寸（仅算设备尺寸，量窗口仍用 onAreaChange）
      const dev: string = this.deviceTypeName();
      const diagInch: number = this.screenDiagonalInch();
      const tabletDevice: boolean = dev === 'tablet' || dev === '2in1' || diagInch >= 7.0;
      // 真两级判定：先判设备，再判宽度
      const newTablet: boolean = tabletDevice && (availW >= 600);
      // 舞台宽：平板级 = min(可用宽, 776) 居中；手机级 = 可用宽
      let stageW: number = availW;
      if (newTablet && stageW > 776) {
        stageW = 776;
      }
      const prevStageW: number = this.stageWidth;
      const prevKeybedH: number = this.keybedHeight;
      const prevTablet: boolean = this.isTablet;
      const prevRegion: number = this.regionHeightVp;
      this.isTablet = newTablet;
      this.stageWidth = stageW;
      // 舞台高改回窗口高（region 仍按可用高算）
      this.stageHeight = winH;
      this.topBarHeight = TOP_BAR_HEIGHT_VP;
      this.paperTopGap = PAPER_TOP_GAP_VP;
      // 照片高度只由宽高比派生
      // 物理模型：行程上限 = 可用行宽（舞台宽 − 2×28），不再是 min(舞台宽×0.35,180)
      this.maxTravelVp = stageW - 2 * 28;
      this.carriageHeight = (stageW + this.maxTravelVp) / CARRIAGE_STRIP_ASPECT;
      this.fontBarHeight = FONT_BAR_HEIGHT_VP;
      this.keybedHeight = stageW / KEYBAND_ASPECT;
      this.functionRowHeight = FUNCTION_ROW_HEIGHT_VP;
      const carriageConsumed: number = this.carriageHeight - CARRIAGE_PAPER_OVERLAP_VP;
      const region: number = availH - this.topBarHeight - this.paperTopGap - carriageConsumed
        - this.fontBarHeight - this.keybedHeight - this.functionRowHeight;
      this.regionHeightVp = region > 120 ? region : 120;

      // ③字号保 DPI：目标物理 57px（= 手机 17vp×3.375）÷ vp2px
      //    平板 vp2px=2.375 → 24vp；手机 3.375 → 16.9 钳到 17（与改前一致）
      const pxPerVp0: number = this.getUIContext().vp2px(1);
      let fs: number = 57 / (pxPerVp0 > 0 ? pxPerVp0 : 3.375);
      if (fs < 17) {
        fs = 17;
      }
      if (fs > 26) {
        fs = 26;
      }
      this.fontSizeVp = fs;
      this.measureAdvance();
      // 行高：中文 fs×30/17、英文 fs×28/17（随语言切换同步）
      this.lineHeightVp = this.langZh ? fs * (30 / 17) : fs * (28 / 17);

      // 原生像素 guard：整套封顶（照片宽 + 键区高 + 字车高都按封顶宽重算，不许只封 Image）
      const vp2px: number = this.getUIContext().vp2px(1);
      this.photoWidthCap = (availW * vp2px > 2048) ? 2048 / vp2px : 0;
      if (this.photoWidthCap > 0 && stageW > this.photoWidthCap) {
        const capped: number = this.photoWidthCap;
        this.keybedHeight = capped / KEYBAND_ASPECT;
        this.carriageHeight = (capped + this.maxTravelVp) / CARRIAGE_STRIP_ASPECT;
      }

      // 字号定后立刻重算每行字数与每字行程
      this.recalcTravel();
      // carriageHeight 必须在 maxTravelVp 定稿之后再算，否则 Hc 与 CarriageLayers 不同源
      // 第 2 版：纸宽 Pw = regionHeight/1.414；纸高从 96 起按行生长，上限 regionHeight
      // ①纸宽：平板 0.72×stageWidth（MLR 485vp / 72%），手机维持 0.82×stageWidth
      // 纸卷收窄留边：平板 0.66×stageWidth（左右各留深底空隙），手机维持 0.82
      this.paperWidthVp = (this.isTablet ? 0.66 : 0.82) * this.stageWidth;
      // ①零件尺寸加顶：Hc 取 min(Pw×0.17, 纸带高×0.67)，使 Hg=1.5Hc 不超纸带、
    // 旋钮/拨杆/字杆随 Hc 同步缩小；字杆/拨杆锚点（打击行/滚筒）不动。
    // 手机纸带 316vp 时 min 取 Pw×0.17（不回归）；平板 1 行纸带 92vp 时被 0.67×92 顶住。
    this.carriageHeight = this.paperWidthVp * 0.17;
      this.maxTravelVp = Math.min(64, this.paperWidthVp * 0.25);
      this.recalcTravel();
      this.recalcPaperHeight();

      // —— measureStage 末尾同步重算依赖项（回归修复）——
      // stageWidth / keybedHeight 变化 ≥1vp → 键位表按新宽重算（否则叠字停在旧坐标）
      if (Math.abs(stageW - prevStageW) >= 1 || Math.abs(this.keybedHeight - prevKeybedH) >= 1) {
        this.reloadKeymap();
      }
      // isTablet / region 变化 → 纸高瞬时重算（不走打字弹簧动画）
      if (newTablet !== prevTablet || Math.abs(this.regionHeightVp - prevRegion) >= 1) {
        this.recalcPaperHeight();
      }

      hilog.info(DOMAIN, TAG,
        'layout dev=%{public}s diag=%{public}s availW=%{public}s availH=%{public}s tablet=%{public}s stageW=%{public}s region=%{public}s fs=%{public}s paper=%{public}s kmW=%{public}s kmH=%{public}s cap=%{public}s',
        dev, diagInch.toFixed(2), availW.toFixed(1), availH.toFixed(1), newTablet ? 'true' : 'false',
        stageW.toFixed(1), this.regionHeightVp.toFixed(1), fs.toFixed(2),
        this.paperHeightVp.toFixed(1), this.keymapLayout.widthVp.toFixed(1),
        this.keymapLayout.heightVp.toFixed(1), this.photoWidthCap.toFixed(1));
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'measureStage failed: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 字车条行程（§2.1 字车条动效）：最大行程 = min(64vp, 舞台宽 × 0.16)；
   * 每字行程 = 最大行程 / 每行字数；每行字数按舞台宽算，不用屏幕宽。
   */
  private recalcTravel(): void {
    const usable: number = this.stageWidth - 2 * findPaper(this.paperKind).marginH;
    const perLine: number = Math.floor(usable / (this.advEngVp > 0 ? this.advEngVp : this.fontSizeVp));
    this.charsPerLineNum = perLine > 6 ? perLine : 6;
    // 物理模型：最大行程 = 可用行宽（舞台宽 − 2×28vp），不许再写回 min(×0.35,180)
    // 小幅纸移动：最大行程 = min(64vp, 纸宽×0.25)
    const smallT: number = this.paperWidthVp * 0.25;
    this.maxTravelVp = smallT < 64 ? smallT : 64;
    this.travelPerChar = this.maxTravelVp / this.charsPerLineNum;
    hilog.info(DOMAIN, TAG, 'recalcTravel max=%{public}s perChar=%{public}s cpl=%{public}s',
      this.maxTravelVp.toFixed(2), this.travelPerChar.toFixed(3), this.charsPerLineNum.toString());
  }

  /**
   * 每落一字：纸与字车共用的偏移 O 左移「当前字宽」（物理模型，§2.7 解除授权后）。
   * 不用 travelPerChar（最大行程/每行字数）—— 那会让纸移得比字距慢、末字屏 x 右漂。
   */
  private stepCarriageLeft(): void {
    // 小幅纸移动：每字 dO = travelPerChar（= 小行程 / 每行字数），不是字宽
    const dO: number = this.travelPerChar;
    let target: number = this.carriageOffsetVp - dO;
    // 限位与载入钳制同口径：[-maxTravelVp, 0]（旧公式 -(stageWidth−56) 是错的，平板差 9.6 倍）
    const limit: number = -this.maxTravelVp;
    if (target < limit) {
      target = limit;
    }
    // 30ms 线性单步（弹簧作废）
    this.getUIContext().animateTo({ duration: 30, curve: Curve.Linear }, () => {
      this.carriageOffsetVp = target;
    });
    // 总成竖向 jolt 1vp：击打当刻下沉 40ms 回弹
    this.getUIContext().animateTo({ duration: 20, curve: Curve.Linear }, () => {
      this.joltYVp = 1;
    });
    this.getUIContext().animateTo({ duration: 20, delay: 20, curve: Curve.Linear }, () => {
      this.joltYVp = 0;
    });
    this.commitSeq = this.commitSeq + 1;
    hilog.info(DOMAIN, TAG, 'carriage offset -> %{public}s', target.toFixed(2));
  }

  /** 删除/覆盖删除：字车条右退一格，上限 0。 */
  private stepCarriageRight(): void {
    let target: number = this.carriageOffsetVp + this.travelPerChar;
    if (target > 0) {
      target = 0;
    }
    this.getUIContext().animateTo({ duration: 70, curve: curves.springCurve(0, 1, 260, 20) }, () => {
      this.carriageOffsetVp = target;
    });
  }

  /** 换行回位：250ms 弹簧从累计量一次性滑回 0，与拨杆摆动 + 叮声 + 导件回左缘同步。 */
  private resetCarriage(): void {
    // 快速回位：200ms fast-out，末端 2vp 叩击回弹（不用 250ms 弹簧）
    const start: number = this.carriageOffsetVp;
    this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseInOut }, () => {
      this.carriageOffsetVp = 0;
      this.joltYVp = 2;
    });
    this.getUIContext().animateTo({ duration: 40, delay: 150, curve: Curve.FastOutSlowIn }, () => {
      this.joltYVp = 0;
    });
    // 旋钮走纸期间累计转 21°/行，线性、不回零
    // 转角物理口径：一行行高 ÷ 滚筒周长 × 360（平板约 59°/行），滚筒与旋钮同角
    const perLineDeg: number = this.lineHeightVp / (Math.PI * this.carriageHeight) * 360;
    this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseInOut }, () => {
      this.knobAngle = this.knobAngle + perLineDeg;
    });
    void start;
  }

  // ---------------- 换装 ----------------

  /** §4：换装 200ms 淡入淡出——只动透明度，不重建编辑器、不丢光标。 */
  private fadeSwitch(): void {
    this.switchFade = 0.35;
    this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      this.switchFade = 1;
    });
  }

  private applyMachine(kind: MachineKind): void {
    // 换机时防御性清空预编辑串
    this.cnPreview = '';
    this.machineKind = kind;
    this.docModel.setMachine(kind);
    // P0-4：机器变了就重解析键位表，不管尺寸变没变
    this.reloadKeymap();
    // P1-10：换装落盘（有内容才存，空纸不存）
    this.flushSave();
    this.fadeSwitch();
  }

  private applyPaper(kind: PaperKind): void {
    this.paperKind = kind;
    // 字号/行高由 measureStage 的公式统一决定（§2.6），换纸不再覆盖，避免公式被机器基数冲掉
    // 回落链：英文走 Courier Prime，中文/符号由系统按字回落到 Noto Serif SC
    this.fontFamily = findFont(DEFAULT_FONT).familyName + ', Noto Serif SC';
    this.docModel.setPaper(kind);
    this.recalcPaperHeight();
    this.fadeSwitch();
    // P1-10：换装落盘
    this.flushSave();
  }

  private applyRibbon(kind: RibbonKind): void {
    this.ribbon = kind;
    this.inkColor = findRibbon(kind).inkColor;
    this.docModel.setRibbon(kind);
    this.fadeSwitch();
    // P1-10：换装落盘
    this.flushSave();
  }

  private reloadKeymap(): void {
    try {
      const host = this.getUIContext().getHostContext();
      if (host === undefined || host === null) {
        return;
      }
      const rm: resourceManager.ResourceManager = host.resourceManager;
      const spec = findMachine(this.machineKind);
      hilog.info(DOMAIN, TAG, 'reloadKeymap called: stageW=%{public}s keybedH=%{public}s path=%{public}s',
        this.stageWidth.toFixed(1), this.keybedHeight.toFixed(1), spec.keymapRawfile);
      const text: string = readRawTextSync(rm, spec.keymapRawfile);
      this.keymapLayout = KeymapParser.parse(text, this.machineKind as string, false,
        this.stageWidth, this.keybedHeight, spec.overlayColor, spec.overlayFontSizeVp);
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'reloadKeymap failed: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * §2.9 沉浸式：栏可见、内容伸到栏下、用安全区避让（不是 FULL_IMMERSIVE）。
   * 状态栏 / 导航栏 / 导航指示器一律保持启用，透明底，内容色 #dbccb3。
   * 安全区动态取；取不到回退 top 28vp / bottom 0，并记 hilog。
   */
  private async applyImmersive(): Promise<void> {
    const host = this.getUIContext().getHostContext();
    if (host === undefined || host === null) {
      hilog.error(DOMAIN, TAG, 'no host context, keep fallback insets');
      return;
    }
    try {
      const win: window.Window = await window.getLastWindow(host as common.UIAbilityContext);
      await win.setWindowLayoutFullScreen(true);
      await win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: '#dbccb3',
        navigationBarContentColor: '#dbccb3',
      });
      await win.setSpecificSystemBarEnabled('status', true, true);
      await win.setSpecificSystemBarEnabled('navigation', true, true);

      const sys = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const nav = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const top: number = this.getUIContext().px2vp(sys.topRect.height);
      const bottom: number = this.getUIContext().px2vp(nav.bottomRect.height);
      this.topInset = top;
      this.bottomInset = bottom;
      // insets 到达后必须重算（初值 28/0 只作占位，不当终值）
      this.measureStage();
      hilog.info(DOMAIN, TAG, 'insets top=%{public}s bottom=%{public}s', top.toFixed(1), bottom.toFixed(1));
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      this.topInset = 28;
      this.bottomInset = 0;
      hilog.error(DOMAIN, TAG, 'immersive failed, fallback insets: %{public}s', JSON.stringify(err));
    }
  }

  /** 探测 1920s 分层素材是否齐备；缺失则回退旧 carriage-strip.png。 */
  private detectLayers(): void {
    if (this.machineKind !== MachineKind.UPRIGHT_1920S) {
      this.useLayers = false;
      return;
    }
    try {
      const host = this.getUIContext().getHostContext();
      if (host === undefined || host === null) {
        this.useLayers = false;
        return;
      }
      const rm: resourceManager.ResourceManager = host.resourceManager;
      const names: string[] = rm.getRawFileListSync('layers/1920s-upright');
      const need: string[] = ['knob.png', 'central-guide.png', 'paper-bail.png', 'roller-texture.jpg'];
      let all: boolean = true;
      for (const n of need) {
        let found: boolean = false;
        for (const got of names) {
          if (got === n || got.endsWith('/' + n)) {
            found = true;
            break;
          }
        }
        if (!found) {
          all = false;
        }
      }
      this.useLayers = all;
      let joined: string = '';
      for (const n of names) {
        joined += n + ',';
      }
      hilog.info(DOMAIN, TAG, 'detectLayers names=[%{public}s] all=%{public}s count=%{public}s useLayers=%{public}s',
        joined, all ? 'true' : 'false', names.length.toString(), this.useLayers ? 'true' : 'false');
    } catch (e) {
      this.useLayers = false;
      hilog.error(DOMAIN, TAG, 'detectLayers failed, fallback to strip');
    }
  }

  // ---------------- 纸片 ----------------

  /**
   * 模型 B（屏高百分比三态）：
   *   paperTop = max(10%, 25% − (行−1)×2.83%) × 屏高
   *   strike   = paperTop + 3% + (行−1)×2.83%   ← 封顶前纸上移抵消、封顶后实打实下移
   *   carriageTop = 56% × 屏高（三态同高，不动）
   *   paperHeight = carriageTop − paperTop，Pw = paperHeight / 1.414
   */
  private recalcPaperHeight(): void {
    // H 冻结：只用首次稳定测到的 availableHeightVp，不每轮重读 live inset
    if (this.frozenHVp <= 0 && this.availableHeightVp > 0) {
      this.frozenHVp = this.availableHeightVp;
    }
    const H: number = this.frozenHVp > 0 ? this.frozenHVp : this.availableHeightVp;
    const rows: number = this.docModel.getLines().length;
    this.carriageTopVp = 0.56 * H;
    // 打击行固定：字车条顶 − 底边距 20 − 行高/2，行数变化也不动
    // 平板：打击行上移 15vp（与横杆上移联动，横杆不挡字）；手机走原值
    const strikeShift: number = this.isTablet ? 15 : 0;
    this.strikeLineVp = this.carriageTopVp - 20 - this.lineHeightVp / 2 - strikeShift;
    // 纸高定值（唯一一处）：Ph = Pw × 1.414，行数变了不动
    this.paperHeightVp = this.paperWidthVp * 1.414;
    // 纸顶动、纸底藏：纸顶每换行上移一个行高，纸底始终在滚筒下方（被容器裁掉）
    // 纸带基数随字号同步变：20（底边距）+ 行高 + 44（内容顶）
    const bandShift: number = this.isTablet ? 15 : 0;
    const paperBandBase: number = 20 + this.lineHeightVp + 44 + bandShift;
    // 纸顶只由「光标行」派生（空行也占行），换行/退行不再手动 ±行高
    this.paperTopTargetVp = this.carriageTopVp - paperBandBase
      - this.docModel.getCursor().line * this.lineHeightVp;
    // 纸片容器高 = 纸顶到滚筒
    // 纸底伸到 carriageTop 下 2vp：纸叠进滚筒 40vp（滚筒顶 = carriageTop − Hc/2），同一张纸
    this.paperContainerTargetVp = this.carriageTopVp - this.paperTopTargetVp + 2;
    if (this.paperAnimateNext) {
      // 换行编排第 2 段：纸上滑 200ms FastOutSlowIn（不许直接赋值跳变）
      this.paperAnimateNext = false;
      this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
        this.paperTopVp = this.paperTopTargetVp;
        this.paperContainerVp = this.paperContainerTargetVp;
      });
    } else {
      this.paperTopVp = this.paperTopTargetVp;
      this.paperContainerVp = this.paperContainerTargetVp;
    }
    this.contentTopVp = 44;
    // Pw 单源固定值（唯一写 Pw 的地方）
    // ④Hc 加顶：min(Pw×0.17, 由「中央件顶 ≥ 纸顶」反推的上限)
    //    中央件顶 = strikeLine − 1.5Hc×0.55，令其 ≥ 纸顶 → Hc ≤ (strikeLine − 纸顶)/0.825
    const hcByPw: number = this.paperWidthVp * 0.17;
    const hcByCeil: number = (this.strikeLineVp - this.paperTopTargetVp) / 0.825;
    this.carriageHeight = hcByPw < hcByCeil ? hcByPw : hcByCeil;
    // 拨杆高 = 支点 − 纸顶（平板 1.84×Hc 使顶端与纸顶齐平），手机维持 2.5
    hilog.info(DOMAIN, TAG,
      'assembly baseW=%{public}s baseLeft=%{public}s plateLeft=%{public}s grooveTop=%{public}s bracketTop=%{public}s pinX=%{public}s pinY=%{public}s leverW=%{public}s',
      this.baseW().toFixed(1), this.baseLeftRel().toFixed(1),
      (this.baseLeftRel() + this.baseW() * 0.32 - 55).toFixed(1),
      (this.carriageHeight + 8).toFixed(1), this.bracketTopRel().toFixed(1),
      this.pinXRel().toFixed(1), this.pinYRel().toFixed(1), this.leverW().toFixed(1));
    hilog.info(DOMAIN, TAG, 'assemblyAbs bracketTopAbs=%{public}s pinYAbs=%{public}s grooveBottomAbs=%{public}s',
      (this.carriageTopVp - this.carriageHeight / 2 + this.bracketTopRel()).toFixed(1),
      (this.carriageTopVp - this.carriageHeight / 2 + this.pinYRel()).toFixed(1),
      (this.carriageTopVp - this.carriageHeight / 2 + this.carriageHeight + 22).toFixed(1));
    const lf: number = this.isTablet ? 1.84 : 2.5;
    const leverHActual: number = this.carriageHeight * lf;
    const leverPivotY: number = this.carriageTopVp + this.carriageHeight / 2;
    hilog.info(DOMAIN, TAG, 'leverH actual=%{public}s pivotY=%{public}s topY=%{public}s paperTop=%{public}s',
      leverHActual.toFixed(1), leverPivotY.toFixed(1), (leverPivotY - leverHActual).toFixed(1), this.paperTopVp.toFixed(1));
    hilog.info(DOMAIN, TAG,
      'parts stageW=%{public}s geoW=%{public}s fs=%{public}s lh=%{public}s Pw=%{public}s H=%{public}s carrTop=%{public}s paperTop=%{public}s paperBox=%{public}s Hc=%{public}s Hg=%{public}s knobD=%{public}s leverH=%{public}s typebarH=%{public}s keybedH=%{public}s',
      this.stageWidth.toFixed(1), this.geoWidthVp().toFixed(1),
      this.fontSizeVp.toFixed(2), this.lineHeightVp.toFixed(1), this.paperWidthVp.toFixed(1), H.toFixed(1),
      this.carriageTopVp.toFixed(1), this.paperTopVp.toFixed(1), this.paperContainerVp.toFixed(1),
      this.carriageHeight.toFixed(1), (this.carriageHeight * 1.5).toFixed(1),
      (this.carriageHeight * 0.92).toFixed(1), (this.carriageHeight * 2.5).toFixed(1),
      (this.carriageHeight * 2.5).toFixed(1), this.carriageHeight.toFixed(1));
    hilog.info(DOMAIN, TAG,
      'modelB rows=%{public}s top=%{public}s strike=%{public}s carr=%{public}s pw=%{public}s H=%{public}s inset=%{public}s stackTop=%{public}s',
      rows.toString(), this.paperTopVp.toFixed(1), this.strikeLineVp.toFixed(1),
      this.carriageTopVp.toFixed(1), this.paperWidthVp.toFixed(1), H.toFixed(1),
      this.topInset.toFixed(1), this.stackTopGlobalYVp.toFixed(1));
    return;
    const lineCount: number = this.docModel.getLines().length;
    const rawHeight: number = PAPER_INITIAL_HEIGHT_VP + (lineCount - 1) * this.lineHeightVp;
    if (rawHeight <= this.regionHeightVp) {


    } else {


    }
  }

  /** 换行与行数变化一律走 recalcPaperHeight（纸高不再增长，只动纸顶）。 */
  private animatePaperHeight(): void {
    this.paperAnimateNext = true;
    this.recalcPaperHeight();
  }

  // ---------------- 击打链 ----------------

  /** 实测单字 advance（MeasureUtils，px→vp）：字号或字体变时重测。 */
  private measureAdvance(): void {
    try {
      const mu = this.getUIContext().getMeasureUtils();
      const ePx: number = mu.measureText({ textContent: 'V', fontSize: this.fontSizeVp, fontFamily: this.fontFamily });
      const cPx: number = mu.measureText({ textContent: '永', fontSize: this.fontSizeVp, fontFamily: this.fontFamily });
      // Courier Prime 的 hmtx 实测 1228/2048 = 0.600 em（fontTools 直读 ttf）。
      // MeasureUtils 看不到 registerFont 注册的族名（会回落系统比例字体），故只记录、不回写。
      this.advEngVp = this.fontSizeVp * 0.6;
      this.advCjkVp = this.fontSizeVp;
      const iPx: number = mu.measureText({ textContent: 'i', fontSize: this.fontSizeVp, fontFamily: this.fontFamily });
      const mPx: number = mu.measureText({ textContent: 'm', fontSize: this.fontSizeVp, fontFamily: this.fontFamily });
      hilog.info(DOMAIN, TAG,
        'advance eng=%{public}s cjk=%{public}s i=%{public}s m=%{public}s fs=%{public}s mono=%{public}s',
        this.advEngVp.toFixed(2), this.advCjkVp.toFixed(2),
        this.getUIContext().px2vp(iPx).toFixed(2), this.getUIContext().px2vp(mPx).toFixed(2),
        this.fontSizeVp.toFixed(2), Math.abs(iPx - mPx) < 0.5 ? 'true' : 'false');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'measureAdvance failed');
    }
  }

  /** 字宽一律用实测 advance；未测到前退回字号（不作长期口径）。 */
  /** 单字 advance：按 Unicode 范围定全角/半角，不许用 code > 127 一刀切。 */
  private charWidthVp(ch: string): number {
    const code: number = ch.length > 0 ? ch.charCodeAt(0) : 65;
    if (this.isFullWidth(code)) {
      return this.advCjkVp > 0 ? this.advCjkVp : this.fontSizeVp;
    }
    return this.advEngVp > 0 ? this.advEngVp : this.fontSizeVp * 0.6;
  }

  /** 全角判定：CJK 表意文字、假名、谚文、全角形、CJK 符号标点、em dash、省略号。 */
  private isFullWidth(code: number): boolean {
    if (code >= 0x1100 && code <= 0x115F) { return true; }
    if (code >= 0x2E80 && code <= 0x9FFF) { return true; }
    if (code >= 0x3000 && code <= 0x303F) { return true; }
    if (code >= 0x3040 && code <= 0x30FF) { return true; }
    if (code >= 0x3400 && code <= 0x4DBF) { return true; }
    if (code >= 0xAC00 && code <= 0xD7AF) { return true; }
    if (code >= 0xF900 && code <= 0xFAFF) { return true; }
    if (code >= 0xFE30 && code <= 0xFE4F) { return true; }
    if (code >= 0xFF00 && code <= 0xFF60) { return true; }
    if (code >= 0xFFE0 && code <= 0xFFE6) { return true; }
    if (code >= 0x20000 && code <= 0x2FA1F) { return true; }
    if (code === 0x2014 || code === 0x2026) { return true; }
    return false;
  }

  // ---- 字车总成 v8/v9 拼装几何（相对金属件顶）----
  private knobD(): number {
    return this.carriageHeight * 0.92;
  }

  private baseW(): number {
    return this.paperWidthVp + 2 * this.knobD();
  }

  /** 机身固定件左缘（不含 O）：底座/沟槽/铭牌/支架/拨杆都用它，不跟字车走。 */
  private baseLeftRel(): number {
    return (this.stageWidth - this.paperWidthVp) / 2 - this.knobD();
  }

  private paperLeftFixed(): number {
    return (this.stageWidth - this.paperWidthVp) / 2;
  }

  private bracketW(): number {
    return 60;
  }

  private bracketH(): number {
    return this.bracketW() / 0.8042;
  }

  /** 支架底面 = 沟槽底 + 2vp；沟槽底 = Hc + 22（底座顶 Hc+2，槽顶 +6，槽高 14）。 */
  private bracketTopRel(): number {
    return this.carriageHeight + 24 - this.bracketH();
  }

  private bracketLeftRel(): number {
    return this.baseLeftRel() + this.baseW() - this.bracketW() - 10;
  }

  /** 销钉孔 (0.503, 0.293) 即拨杆支点。 */
  private pinXRel(): number {
    return this.bracketLeftRel() + 0.503 * this.bracketW();
  }

  private pinYRel(): number {
    return this.bracketTopRel() + 0.293 * this.bracketH();
  }

  private leverW(): number {
    return (this.isTablet ? this.carriageHeight * 1.84 : this.carriageHeight * 2.5) * 0.212;
  }

  /** 扣子中心 x 硬钳制：永不超出纸右缘 − 扣子半宽。 */
  private clampedStrikeXVp(): number {
    const paperLeft: number = (this.stageWidth - this.paperWidthVp) / 2 + this.carriageOffsetVp;
    const raw: number = paperLeft + findPaper(this.paperKind).marginH + this.currentLineWidthVp();
    const paperRight: number = paperLeft + this.paperWidthVp;
    const knobHalf: number = this.carriageHeight * 0.92 / 2;
    const limit: number = paperRight - knobHalf;
    if (raw > limit) {
      return limit;
    }
    return raw;
  }

  /** 当前行文本（供隐藏 Text 实测宽）。 */
  private currentLineText(): string {
    const cursor = this.docModel.getCursor();
    const line = this.docModel.getLines()[cursor.line];
    return line.text.length > 0 ? line.text : ' ';
  }

  /** 优先用整行渲染实测宽；未测到才退回逐字累加。 */
  private currentLineWidthVp(): number {
    // 只用 ttf 度量（0.600em）累加；隐藏 Text 的实测只记录，不参与布局——
    // 两者在长行上差 ~70vp，实测串可能吃到回落比例字体

    const cursor = this.docModel.getCursor();
    const line = this.docModel.getLines()[cursor.line];
    let w: number = 0;
    for (let i = 0; i < line.text.length; i++) {
      w += this.charWidthVp(line.text.charAt(i));
    }
    return w;
  }

  /**
   * §12.2 第 2 条：删后若某逻辑行超纸宽，按纸宽断成多行，恢复不变量「逻辑行不超纸宽」。
   * 光标落到合并点所在那一段的末尾。宽度口径与 commitChar 的位置触发同源（charWidthVp）。
   */
  private rewrapOverwideLines(lineIdx: number, mergeAt: number): boolean {
    const lines: DocLine[] = this.docModel.getLines();
    if (lineIdx < 0 || lineIdx >= lines.length) {
      return false;
    }
    const usable: number = this.paperWidthVp - 2 * findPaper(this.paperKind).marginH;
    let idx: number = lineIdx;
    let cursorLine: number = this.docModel.getCursor().line;
    let cursorOffset: number = this.docModel.getCursor().offset;
    let changed: boolean = false;
    let guard: number = 0;
    while (guard < 64 && idx < lines.length) {
      const cur: DocLine = lines[idx];
      let acc: number = 0;
      let cut: number = -1;
      for (let i = 0; i < cur.text.length; i++) {
        const w: number = this.charWidthVp(cur.text.charAt(i));
        if (acc + w > usable + 0.5) {
          cut = i;
          break;
        }
        acc += w;
      }
      if (cut < 0) {
        break;
      }
      const tail: string = cur.text.substring(cut);
      cur.text = cur.text.substring(0, cut);
      const created: DocLine = { text: tail, ribbon: cur.ribbon };
      lines.splice(idx + 1, 0, created);
      changed = true;
      if (cursorLine === idx && cursorOffset > cut) {
        cursorLine = idx + 1;
        cursorOffset = cursorOffset - cut;
      } else if (cursorLine > idx) {
        cursorLine = cursorLine + 1;
      }
      idx = idx + 1;
      guard = guard + 1;
    }
    if (changed) {
      this.docModel.setCursor({ line: cursorLine, offset: cursorOffset });
      hilog.info(DOMAIN, TAG, 'rewrap from line=%{public}s mergeAt=%{public}s -> cursor=%{public}s/%{public}s',
        lineIdx.toString(), mergeAt.toString(), cursorLine.toString(), cursorOffset.toString());
    }
    return changed;
  }

  /** 行宽只认舞台宽（§2.5）。 */
  private charsPerLine(): number {
    // 可用行宽 = 纸宽 − 2×28vp（不用舞台宽）
    const usable: number = this.paperWidthVp - 2 * findPaper(this.paperKind).marginH;
    // §12.2 第 3 条：中文按 CJK 字宽算（约 16 字/行），英文按英文字宽（约 26 字/行）
    const unit: number = this.langZh
      ? (this.advCjkVp > 0 ? this.advCjkVp : this.fontSizeVp)
      : (this.advEngVp > 0 ? this.advEngVp : this.fontSizeVp);
    const n: number = Math.floor(usable / unit);
    return n > 6 ? n : 6;
  }

  /** 派生显示布局：keymapLayout(原表) + shiftActive + symbolMode + langZh → 新 layout。 */
  private displayLayout(): KeymapLayout {
    const base: KeymapLayout = this.keymapLayout;
    const sym: string[][] = this.langZh ? SYM_ZH : SYM_EN;
    const rowIdx: number[] = [0, 0, 0, 0];
    const caps: CapDef[] = [];
    for (let i = 0; i < base.caps.length; i++) {
      const c: CapDef = base.caps[i];
      const ri: number = c.rowIndex >= 0 && c.rowIndex < 4 ? c.rowIndex : 0;
      const inRow: number = rowIdx[ri];
      rowIdx[ri] = inRow + 1;
      let label: string = c.label;
      if (this.symbolMode) {
        // 符号模式：Shift 位保持 'Shift'（布局稳定），其余按行内序号取符号
        if (c.label !== 'Shift' && !c.isExtra) {
          const arr: string[] = sym[ri];
          const k: number = ri === 3 ? inRow - 1 : inRow;
          if (k >= 0 && k < arr.length) {
            label = arr[k];
          }
        }
      } else if (this.shiftActive) {
        // Shift 模式：数字/标点换上档符号；字母帽本来就是大写，不变
        const up: string | undefined = SHIFT_MAP[c.label];
        if (up !== undefined) {
          label = up;
        }
      }
      caps.push({
        id: c.id, label: label, cx: c.cx, cy: c.cy, rowIndex: c.rowIndex,
        isExtra: c.isExtra, xRatio: c.xRatio, yRatio: c.yRatio,
      });
    }
    return {
      machine: base.machine, caps: caps,
      spaceXMin: base.spaceXMin, spaceXMax: base.spaceXMax,
      spaceYMin: base.spaceYMin, spaceYMax: base.spaceYMax,
      hitRadius: base.hitRadius, overlayColor: base.overlayColor,
      overlayFontSize: base.overlayFontSize, widthVp: base.widthVp, heightVp: base.heightVp,
    };
  }

  // ---------------- 内置拼音输入（设计稿 §4） ----------------

  private isBuiltinCn(): boolean {
    return this.langZh && this.cnEngine === 'builtin';
  }

  /** 重算候选（page 0），并把拼音串镜像到预编辑显示。 */
  private pinyinRefresh(): void {
    if (this.pinyinSession === null) {
      return;
    }
    this.cnPinyin = this.pinyinSession.getBuffer();
    this.cnPreview = this.cnPinyin.length > 0 ? this.pinyinSession.getBuffer() : '';
    this.candAll = this.pinyinSession.currentCandidates(64, this.lastCommittedChar);
    this.candPage = 0;
    this.candPages = Math.max(1, Math.ceil(this.candAll.length / 9));
    this.pinyinShown();
    // 打点：buffer / 候选数 / 当前页候选
    const cur: string = this.candCurrent.join(',');
    hilog.info(DOMAIN, TAG, 'cn pinyin buf=%{public}s candAll=%{public}s candCur=%{public}s',
      this.cnPinyin, this.candAll.length.toString(), cur);
  }

  private pinyinShown(): void {
    const start: number = this.candPage * 9;
    const out: string[] = [];
    for (let i = start; i < this.candAll.length && out.length < 9; i++) {
      out.push(this.candAll[i].text);
    }
    this.candCurrent = out;
  }

  /** 选第 index 个（当前页 0 起）。走 enqueueChinese（40ms 逐字），余量字母继续组词。 */
  private pinyinPick(index: number): void {
    hilog.info(DOMAIN, TAG, 'cn pick idx=%{public}s candCur=%{public}s',
      index.toString(), this.candCurrent.join(','));
    if (this.pinyinSession === null) {
      return;
    }
    const abs: number = this.candPage * 9 + index;
    if (abs < 0 || abs >= this.candAll.length) {
      return;
    }
    const c: Candidate = this.candAll[abs];
    // 学习键＝用户此刻打的整串（不是候选消费的短前缀），这样「再打同一拼音」能命中
    const typedBuf: string = this.pinyinSession.getBuffer();
    const r: PickResult = this.pinyinSession.pick(c);
    // §11.2 学习：记 (拼音串, 词, 次数)，节流落盘（每 10 次）
    if (this.pinyinEngine !== null && r.text.length > 0) {
      this.pinyinEngine.learnWord(typedBuf.length > 0 ? typedBuf : c.pinyin, r.text);
      this.cnPickCount = this.cnPickCount + 1;
      // 防抖落盘：选词后 1.5s 存一次（不是每击键，也不会因杀进程丢记录）
      if (this.learnSaveTimer >= 0) {
        clearTimeout(this.learnSaveTimer);
      }
      this.learnSaveTimer = setTimeout(() => {
        this.learnSaveTimer = -1;
        this.saveLearn();
        hilog.info(DOMAIN, TAG, 'learn saved picks=%{public}s', this.cnPickCount.toString());
      }, 1500);
    }
    this.enqueueChinese(r.text);
    this.cnPinyin = this.pinyinSession.getBuffer();
    this.cnPreview = this.cnPinyin;
    if (this.cnPinyin.length > 0) {
      this.candAll = this.pinyinSession.currentCandidates(64, this.lastCommittedChar);
      this.candPage = 0;
      this.candPages = Math.max(1, Math.ceil(this.candAll.length / 9));
      this.pinyinShown();
    } else {
      this.candAll = [];
      this.candCurrent = [];
      this.candPage = 0;
      this.candPages = 1;
    }
  }

  /** 退出组词：提交首选候选（换行除外）。 */
  private pinyinCommitTop(): void {
    if (this.pinyinSession === null || this.pinyinSession.getBuffer().length === 0) {
      return;
    }
    if (this.candAll.length > 0) {
      this.pinyinPick(0);
    } else {
      // 无候选：按原样上屏拉丁字母（不丢已敲字母）
      this.enqueueChinese(this.pinyinSession.getBuffer());
      this.pinyinSession.cancel();
      this.cnPinyin = '';
      this.cnPreview = '';
      this.candAll = [];
      this.candCurrent = [];
    }
  }

  /** 内置中文下的按键语义（设计稿 §4 表）。返回 true 表示已消费。 */
  private onBuiltinCnCap(cap: CapDef): boolean {
    const s: PinyinSession | null = this.pinyinSession;
    if (s === null) {
      return false;
    }
    const label: string = cap.label;
    const composing: boolean = s.getBuffer().length > 0;

    if (label === 'Shift') {
      // 先提交首选，再进入大写一次性状态
      this.pinyinCommitTop();
      this.shiftActive = true;
      return true;
    }
    if (label === 'Backspace') {
      if (composing) {
        s.backspace();
        this.audioService.playBackspace();
        this.audioService.vibrate();
        this.pinyinRefresh();
        return true;
      }
      return false;
    }
    if (label === ' ') {
      if (composing) {
        this.pinyinPick(0);
        this.audioService.playSpace();
        return true;
      }
      return false;
    }
    if (label === 'Return') {
      if (composing) {
        // 先把拼音串按原样上屏（拉丁字母），下一次换行才是真换行
        this.enqueueChinese(s.getBuffer());
        s.cancel();
        this.cnPinyin = '';
        this.cnPreview = '';
        this.candAll = [];
        this.candCurrent = [];
        return true;
      }
      return false;
    }
    if (label.length === 1 && label >= '0' && label <= '9') {
      if (composing && this.candCurrent.length > 0) {
        const idx: number = label === '0' ? -1 : Number.parseInt(label) - 1;
        if (idx >= 0 && idx < this.candCurrent.length) {
          this.pinyinPick(idx);
          return true;
        }
      }
      return false;
    }
    if (label.length === 1 && label.toLowerCase() >= 'a' && label.toLowerCase() <= 'z') {
      if (this.shiftActive) {
        // 中文里插英文的逃生口：先提交首选，再按原样打大写
        this.pinyinCommitTop();
        this.shiftActive = false;
        this.queueChar(label);
        return true;
      }
      s.typeLetter(label);
      this.audioService.vibrate();
      this.pinyinRefresh();
      return true;
    }
    // 字符键／中 EN 切换／换纸／换机／离页：统一先提交首选（不丢字母）
    if (composing) {
      this.pinyinCommitTop();
    }
    return false;
  }

  private onCapDown(cap: CapDef): void {
    if (cap.isExtra) {
      return;
    }
    if (this.isBuiltinCn()) {
      if (this.onBuiltinCnCap(cap)) {
        return;
      }
    }
    if (cap.label === ' ') {
      // 空格直通落字：不进 queueChar（那会给 strikeTick+1 触发字杆摆动，导致一声两响）
      // playSpace 保留在 Down 处，只出一声；stepCarriageLeft 左进一格 + jolt 照常
      this.audioService.playSpace();
      this.audioService.vibrate();
      this.commitChar(' ');
      return;
    }
    if (cap.label === 'Backspace') {
      this.onDelete();
      return;
    }
    if (cap.label === 'Return') {
      this.onNewline();
      return;
    }
    if (cap.label === 'Shift') {
      // 按下模式：按住才大写，松开即 false（onCapUp 里清）。符号模式下无动作。
      if (!this.symbolMode) {
        this.shiftActive = true;
      }
      return;
    }
    // Down 只给高亮 + 震动；主击打音移到 onArrive（与落字、纸移动同帧）
    this.audioService.vibrate();
    if (this.symbolMode) {
      // 符号模式：直接提交帽上字符，不做大小写转换、不查上档表
      this.queueChar(cap.label);
      return;
    }
    const ch: string = this.shiftActive ? cap.label : cap.label.toLowerCase();
    this.queueChar(ch);
  }

  private queueChar(ch: string): void {
    this.pendingChars.push(ch);
    // 兜底：200ms 内若无 onArrive，强制落字（动画缺失时打字不许静默全死）
    const chSnapshot: string = ch;
    setTimeout(() => {
      const idx: number = this.pendingChars.indexOf(chSnapshot);
      if (idx >= 0) {
        this.pendingChars.splice(idx, 1);
        this.droppedTicks += 1;
        hilog.error(DOMAIN, TAG, 'typebar fallback: flush char=%{public}s', chSnapshot);
        this.commitChar(chSnapshot);
      }
    }, 200);
    if (this.machineKind === MachineKind.UPRIGHT_1920S) {
      this.strikeTick = this.strikeTick + 1;
    } else {
      this.flushPending();
    }
  }

  private flushPending(): void {
    const ch: string | undefined = this.pendingChars.shift();
    if (ch === undefined) {
      return;
    }
    this.commitChar(ch);
  }

  private onStrikeArrive(): void {
    // 主击打音与落字、纸移动同帧；快速连打换 key-transient 短音，每字仍一音
    const now: number = Date.now();
    const gapMs: number = this.lastArriveMs > 0 ? now - this.lastArriveMs : 9999;
    const fast: boolean = gapMs < 150 || this.pendingChars.length >= 1;
    if (fast) {
      this.audioService.playKeyTransient();
    } else {
      this.audioService.playKey();
    }
    this.soundCount += 1;
    this.fastCount += fast ? 1 : 0;
    this.arriveCount += 1;
    if (this.lastArriveMs > 0) {
      this.arriveGapSumMs += now - this.lastArriveMs;
      this.arriveGapCount += 1;
    }
    this.lastArriveMs = now;
    this.flushPending();
    if (this.arriveCount <= 10 || this.arriveCount % 10 === 0) {
      const avgGap: number = this.arriveGapCount > 0 ? this.arriveGapSumMs / this.arriveGapCount : 0;
      hilog.info(DOMAIN, TAG,
        'strike metrics arrives=%{public}s avgGap=%{public}sms queue=%{public}s dropped=%{public}s sounds=%{public}s fast=%{public}s audio[%{public}s]',
        this.arriveCount.toString(), avgGap.toFixed(1), this.pendingChars.length.toString(),
        this.droppedTicks.toString(), this.soundCount.toString(), this.fastCount.toString(),
        this.audioService.metrics());
    }
  }

  private commitChar(ch: string): void {
    if (this.paperChanging) {
      return;
    }
    // 换行编排未完成时排队，完成后统一补落（不丢字）
    if (this.newlineBusy || this.backBusy) {
      this.queuedChars.push(ch);
      hilog.info(DOMAIN, TAG, 'char queued during newline ch=%{public}s n=%{public}s',
        ch, this.queuedChars.length.toString());
      return;
    }
    this.hintText = '';
    // ② 位置触发自动换行：下一字会让扣子触顶时先换行，不认字数
    //    raw > limit 与 clampedStrikeXVp 同一判据
    const paperLeft: number = (this.stageWidth - this.paperWidthVp) / 2 + this.carriageOffsetVp;
    const nextRaw: number = paperLeft + findPaper(this.paperKind).marginH
      + this.currentLineWidthVp() + this.charWidthVp(ch);
    const limit: number = paperLeft + this.paperWidthVp - this.carriageHeight * 0.92 / 2;
    if (nextRaw > limit && this.docModel.getCursor().offset > 0) {
      hilog.info(DOMAIN, TAG,
        'autoWrap by position offset=%{public}s strikeX=%{public}s nextRaw=%{public}s limit=%{public}s',
        this.carriageOffsetVp.toFixed(2), this.clampedStrikeXVp().toFixed(2),
        nextRaw.toFixed(2), limit.toFixed(2));
      this.onNewline();
    }
    const outcome = this.docModel.insertText(ch, this.charsPerLine());
    this.syncRows();
    this.animateGuide();
    this.stepCarriageLeft();
    try {
      const px: number = this.getUIContext().getMeasureUtils().measureText({
        textContent: this.currentLineText(),
        fontSize: this.fontSizeVp,
        fontFamily: this.fontFamily,
      });
      this.lineWidthMeasuredVp = this.getUIContext().px2vp(px);
    } catch (e) {
      // 量宽失败保留旧值
    }
    hilog.info(DOMAIN, TAG, 'committed ch=[%{public}s] shift=%{public}s sym=%{public}s', ch,
      this.shiftActive ? 'on' : 'off', this.symbolMode ? 'on' : 'off');
    hilog.info(DOMAIN, TAG, 'landTrace line=%{public}s col=%{public}s paperTop=%{public}s O=%{public}s',
      this.docModel.getCursor().line.toString(), this.docModel.getCursor().offset.toString(),
      this.paperTopVp.toFixed(1), this.carriageOffsetVp.toFixed(1));
    hilog.info(DOMAIN, TAG, 'charTrace O=%{public}s measW=%{public}s accumW=%{public}s strikeX=%{public}s',
      this.carriageOffsetVp.toFixed(2), this.lineWidthMeasuredVp.toFixed(2),
      this.currentLineWidthVp().toFixed(2), this.clampedStrikeXVp().toFixed(2));
    this.scheduleSave();
    if (outcome.marginBell) {
      this.audioService.playBell();
    }
    // 行满自动换行：同样走换行回位，不许让字车条停在行末位置开始下一行
    if (this.docModel.getCursor().offset >= this.charsPerLine()) {
      this.onNewline();
    }
    // 每次落字后把光标矩形推给输入法，候选窗跟着走
    this.pushCnCursor();
  }

  /**
   * 启动 / 载入文档时按当前行光标重算 O（不许归 0）：
   * O = −当前行已落字总宽，钳制到 −可用行宽，使末字落在导件处、中央件随手左移。
   */
  private recalcOffsetFromCursor(): void {
    const cursor = this.docModel.getCursor();
    const line = this.docModel.getLines()[cursor.line];
    let w: number = 0;
    for (let i = 0; i < cursor.offset && i < line.text.length; i++) {
      w += this.charWidthVp(line.text.charAt(i));
    }
    // 载入 O 与打字同口径：O = −travelPerChar × 光标列，钳制到 [−maxTravelVp, 0]
    // （旧写法用 −(stageWidth−56)=−306.7vp 当限，与打字的 −maxTravelVp=−64vp 差 4.8 倍）
    let o: number = -this.travelPerChar * cursor.offset;
    if (o < -this.maxTravelVp) {
      o = -this.maxTravelVp;
    }
    if (o > 0) {
      o = 0;
    }
    this.carriageOffsetVp = o;
    hilog.info(DOMAIN, TAG,
      'recalcOffset cursor=%{public}s lineW=%{public}s O=%{public}s guideX=%{public}s lastCharX=%{public}s',
      cursor.offset.toString(), w.toFixed(1), o.toFixed(1), (this.stageWidth * 0.5).toFixed(1),
      // 末字屏 x = 纸偏移(guide − 边距 + O) + 纸内文本起点(边距) + 行宽 = guide + O + w
      (this.stageWidth * 0.5 + o + w).toFixed(1));
  }

  /**
   * 导件固定在舞台中心（本批定稿）：不随光标右移、不随 carriageOffset 平移。
   * 上一版「行首中央件窗中心」与「guide = 边距 + 行宽」两种右移口径均作废。
   */
  private animateGuide(): void {
    const fixed: number = this.stageWidth * 0.5;
    if (this.guideXVp !== fixed) {
      this.guideXVp = fixed;
    }
  }

  private onDelete(): void {
    this.audioService.playBackspace();
    this.audioService.vibrate();
    // 诊断：删除前后的光标行／总行数／纸顶
    const c0 = this.docModel.getCursor();
    const linesBefore: number = this.docModel.getLines().length;
    hilog.info(DOMAIN, TAG, 'del before line=%{public}s lines=%{public}s paperTop=%{public}s',
      c0.line.toString(), linesBefore.toString(), this.paperTopVp.toFixed(1));
    if (this.correctionMode === CorrectionMode.OVERWRITE) {
      const o2 = this.docModel.overwriteBack();
      if (o2.changed) {
        this.syncRows();
        this.animateGuide();
        this.stepCarriageRight();
        // 删除后推一次光标矩形，候选窗跟上
        this.pushCnCursor();
      }
      return;
    }
    const o = this.docModel.backspace();
    if (o.changed) {
      this.syncRows();
      this.animateGuide();
      this.stepCarriageRight();
      // 删除后推一次光标矩形，候选窗跟上
      this.pushCnCursor();
      // §12.2 第 2／3 条：行数变了 → 合并行重排 + 纸顶重算（与 onBackLine 同口径，纸滑不跳变）
      if (this.docModel.getLines().length !== linesBefore) {
        const cm = this.docModel.getCursor();
        if (this.rewrapOverwideLines(cm.line, cm.offset)) {
          this.syncRows();
        }
        this.paperAnimateNext = true;
        this.recalcPaperHeight();
      }
      const c1 = this.docModel.getCursor();
      hilog.info(DOMAIN, TAG, 'del after line=%{public}s lines=%{public}s paperTop=%{public}s',
        c1.line.toString(), this.docModel.getLines().length.toString(), this.paperTopVp.toFixed(1));
    }
  }

  /** 退行：回到上一行文字末尾（不删当前行）；已在第一行则无动作。 */
  private onBackLine(): void {
    const cur = this.docModel.getCursor();
    if (cur.line <= 0) {
      return;
    }
    const prevText: string = this.docModel.getLines()[cur.line - 1].text;
    const prevLen: number = prevText.length;
    // O 与落字宽同源：用上一行实际字宽累加（与 currentLineWidthVp 同一算法），不用 travelPerChar×字数
    let prevW: number = 0;
    for (let i = 0; i < prevText.length; i++) {
      prevW += this.charWidthVp(prevText.charAt(i));
    }
    this.docModel.setCursor({ line: cur.line - 1, offset: prevLen });
    this.syncRows();
    this.hintText = '';
    // O 是字车小行程口径（travelPerChar×字数，上限 maxTravelVp）；
    // 落字位置由 currentLineWidthVp() 全宽管，prevW 不再塞进 O（口径混淆）
    const targetO: number = Math.max(-this.maxTravelVp, -(prevLen * this.travelPerChar));
    // 纸下移一行高（纸上移的逆操作）200ms；字车 O 滑到上一行文字末尾 250ms
    // 纸顶不再手动拨：交给 recalcPaperHeight（由光标行派生）走动画
    this.paperAnimateNext = true;
    this.recalcPaperHeight();
    this.backBusy = true;
    this.getUIContext().animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
      this.carriageOffsetVp = targetO;
    });
    setTimeout(() => {
      this.backBusy = false;
      const q: string[] = this.queuedChars.slice(0);
      this.queuedChars = [];
      for (let i = 0; i < q.length; i++) {
        this.commitChar(q[i]);
      }
    }, 270);
    hilog.info(DOMAIN, TAG, 'backLine to line=%{public}s col=%{public}s O=%{public}s paperTop=%{public}s',
      (cur.line - 1).toString(), prevLen.toString(), targetO.toFixed(1), this.paperTopVp.toFixed(1));
  }

  /** 换纸：一次性手动动作，600ms（旧纸卷出 300 + 新纸卷入 300），期间禁打字。 */
  private onPaperChange(): void {
    // 换纸时防御性清空预编辑串
    this.cnPreview = '';
    if (this.paperChanging) {
      return;
    }
    this.paperChanging = true;
    const startTop: number = this.paperTopVp;
    hilog.info(DOMAIN, TAG, 'paperChange start top=%{public}s box=%{public}s', startTop.toFixed(1), this.paperContainerVp.toFixed(1));
    // ① 整张模式：容器高 = Ph、不裁，整张纸才能整片飞出（不再只露一截）
    this.paperFullSheet = true;
    this.paperContainerVp = this.paperHeightVp;
    // ① 旧纸向上卷出顶部 300ms：纸整体上移约一个纸高并淡出（不是沉进滚筒），滚筒同转
    this.getUIContext().animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
      this.paperTopVp = startTop - this.paperHeightVp;
      this.paperOpacity = 0;
      this.knobAngle = this.knobAngle + 180;
      // 半圈对应的筒面长度 = π×Hc/2，纹理纵向滚同样长度
      this.texOffsetVp = this.texOffsetVp - Math.PI * this.carriageHeight / 2;
    });
    // animateTo 立即赋终值：同步读即为目标态，可证明方向（负值=向上卷出）
    hilog.info(DOMAIN, TAG, 'paperChange step1 target top=%{public}s opacity=%{public}s (neg=up)',
      this.paperTopVp.toFixed(1), this.paperOpacity.toFixed(2));
    setTimeout(() => {
      // ② 新纸从滚筒后卷入 300ms：纸回到起打位，滚筒继续转
      this.docModel.clear();
      this.syncRows();
      this.hintText = '';
      this.carriageOffsetVp = 0;
      // ★改：新纸从滚筒里卷出——动画开始前先把纸顶放到滚筒处藏起来（只露 2vp 纸底缘），
      // 再让 recalcPaperHeight() 把它推到起打位。纸顶从滚筒处往上长出来，不是从天上掉下来。
      this.paperTopVp = this.carriageTopVp;
      this.paperContainerVp = 2;
      // ★改：opacity 与整张模式都在动画开始前恢复（否则纸在滚筒处透明/中途 clip 突变闪现）
      this.paperOpacity = 1;
      this.paperFullSheet = false;
      // 打点在 animateTo 之前：此时 paperTop 就是「藏在滚筒处」的值（应 ≈ carriageTop）
      hilog.info(DOMAIN, TAG, 'paperChange step2 hide top=%{public}s box=%{public}s carriageTop=%{public}s',
        this.paperTopVp.toFixed(1), this.paperContainerVp.toFixed(1), this.carriageTopVp.toFixed(1));
      this.getUIContext().animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
        this.recalcPaperHeight();
        this.knobAngle = this.knobAngle + 180;
        this.texOffsetVp = this.texOffsetVp - Math.PI * this.carriageHeight / 2;
      });
      hilog.info(DOMAIN, TAG, 'paperChange step2 top=%{public}s opacity=%{public}s',
        this.paperTopVp.toFixed(1), this.paperOpacity.toFixed(2));
      hilog.info(DOMAIN, TAG, 'paperChange done at 600ms knob=%{public}s top=%{public}s',
        this.knobAngle.toFixed(1), this.paperTopVp.toFixed(1));
      setTimeout(() => {
        this.paperChanging = false;
      }, 320);
    }, 300);
  }

  private onNewline(): void {
    // 第三方输入法可能不发 finishTextPreview，换行时防御性清空预编辑串
    this.cnPreview = '';
    // 三段编排 600ms：t=0 拨杆摆 35°/150ms → t=150 纸上移一行+滚筒转 200ms
    //              → t=350 字车回位 250ms（末端叩击回弹）→ t=600 叮声（与到达同帧）
    // 末行判定：可写行数 = floor((Ph − 内容顶 44 − 底边距 20) / 行高)；光标已在最后一行则换纸
    const allLines = this.docModel.getLines();
    const cur = this.docModel.getCursor();
    const isLastLine: boolean = cur.line >= allLines.length - 1;

    if (!isLastLine) {
      // 下方有内容：只「下移一行」，不插行、不挤下面。光标落到下一行文字末尾（与退行对称）
      const nextText: string = allLines[cur.line + 1].text;
      const nextLen: number = nextText.length;
      this.newlineMoveDown = true;
      this.newlineCarriageTargetO = Math.max(-this.maxTravelVp, -(nextLen * this.travelPerChar));
      this.docModel.setCursor({ line: cur.line + 1, offset: nextLen });
      this.syncRows();
      this.scheduleSave();
      this.newlineBusy = true;
      this.newlineTick = this.newlineTick + 1;
      this.hintText = '';
      hilog.info(DOMAIN, TAG, 'newlineMoveDown to line=%{public}s col=%{public}s O=%{public}s rows=%{public}s',
        (cur.line + 1).toString(), nextLen.toString(),
        this.newlineCarriageTargetO.toFixed(1), allLines.length.toString());
    } else {
      // 末行：先判行数上限（换纸），否则插一行
      const maxRows: number = Math.max(1, Math.floor((this.paperHeightVp - 44 - 20) / this.lineHeightVp));
      if (allLines.length >= maxRows) {
        hilog.info(DOMAIN, TAG, 'newlineAtLastRow -> paperChange maxRows=%{public}s', maxRows.toString());
        this.onPaperChange();
        return;
      }
      this.newlineMoveDown = false;
      this.newlineCarriageTargetO = 0;
      this.newlineBusy = true;
      this.newlineTick = this.newlineTick + 1;
      this.hintText = '';
      this.docModel.newline();
      this.syncRows();
      this.scheduleSave();
    }
    // 纸上滑与滚筒转角都在 t=150 起（拨杆摆出 150ms 之后）
    setTimeout(() => {
      this.animatePaperHeight();
      // 纹理纵向滚一行高（纸速=筒面线速度），与纸上滑同步 200ms FastOutSlowIn
      // 纹理滚动与纸上滑同一起点(t=150)、同一时长(300ms)、同一曲线(EaseInOut)
      this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
        this.texOffsetVp = this.texOffsetVp - this.lineHeightVp;
      });
    }, 150);
    // 编排自测：0/150/350/600 采样（数字代替录屏验单调性）
    const marks: number[] = [0, 150, 350, 600];
    for (let k = 0; k < marks.length; k++) {
      const ms: number = marks[k];
      setTimeout(() => {
        hilog.info(DOMAIN, TAG, 'choreoTrace t=%{public}s offset=%{public}s paperTop=%{public}s knob=%{public}s',
          ms.toString(), this.carriageOffsetVp.toFixed(2), this.paperTopVp.toFixed(1), this.knobAngle.toFixed(1));
      }, ms);
    }
    const t0: number = 450;
    setTimeout(() => {
      if (this.newlineCarriageTargetO < -0.001 || this.newlineMoveDown) {
        // 「下移一行」分支：字车滑到下一行文字末尾的 O（小行程口径），不回 0
        this.getUIContext().animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
          this.carriageOffsetVp = this.newlineCarriageTargetO;
        });
        const perLineDeg2: number = this.lineHeightVp / (Math.PI * this.carriageHeight) * 360;
        this.getUIContext().animateTo({ duration: 250, curve: Curve.Linear }, () => {
          this.knobAngle = this.knobAngle + perLineDeg2;
        });
      } else {
        this.resetCarriageAndGuide();
      }
    }, t0);
    setTimeout(() => {
      // 字车 250ms 回位结束同帧：叮声 + 振动
      this.audioService.playCarriageReset();
      this.audioService.vibrate();
      hilog.info(DOMAIN, TAG, 'newline choreo bell at %{public}sms offset=%{public}s paperTop=%{public}s tick=%{public}s',
        (t0 + 250).toString(), this.carriageOffsetVp.toFixed(2),
        this.paperTopVp.toFixed(1), this.newlineTick.toString());
      // 换行完成定位日志 + 释放排队字
      hilog.info(DOMAIN, TAG, 'newlineDone rows=%{public}s paperTop=%{public}s line=%{public}s col=%{public}s O=%{public}s',
        this.docModel.getLines().length.toString(), this.paperTopVp.toFixed(1),
        this.docModel.getCursor().line.toString(), this.docModel.getCursor().offset.toString(),
        this.carriageOffsetVp.toFixed(1));
      this.newlineBusy = false;
      const q: string[] = this.queuedChars.slice(0);
      this.queuedChars = [];
      for (let i = 0; i < q.length; i++) {
        this.commitChar(q[i]);
      }
    }, t0 + 250);
  }

  /** 换行回位（§2.1）：字车条一次性跳回 0 + 导件回左缘，250ms 弹簧，与叮声同步。 */
  private resetCarriageAndGuide(): void {
    const base: number = findPaper(this.paperKind).marginH;
    this.resetCarriage();
    this.getUIContext().animateTo({ duration: 250, curve: curves.springMotion() }, () => {
      this.guideXVp = base;
    });
  }

  /** 只刷新行数据；顶栏标题绝不随打字变化（§2.5）。 */
  /** 防抖落盘（重设计重写时丢失，本次补回）：停顿 800ms 存一次。 */
  private scheduleSave(): void {
    if (this.saveTimer !== -1) {
      clearTimeout(this.saveTimer);
    }
    this.saveTimer = setTimeout(() => {
      this.saveTimer = -1;
      this.flushSave();
    }, 800);
  }

  /** §6.2：把刚导出的文件交给系统分享面板。失败只记日志，不影响已落盘的文件。 */
  private shareFile(path: string, utd: string): void {
    try {
      const host = this.getUIContext().getHostContext();
      if (host === undefined || host === null) {
        return;
      }
      const uri: string = fileUri.getUriFromPath(path);
      const data: systemShare.SharedData = new systemShare.SharedData({
        utd: utd,
        uri: uri,
      });
      const controller: systemShare.ShareController = new systemShare.ShareController(data);
      const opts: systemShare.ShareControllerOptions = {};
      controller.show(host as common.UIAbilityContext, opts)
        .then(() => { hilog.info(DOMAIN, TAG, 'share panel shown'); })
        .catch(() => { hilog.error(DOMAIN, TAG, 'share panel failed'); });
      hilog.info(DOMAIN, TAG, 'share shown uri=%{public}s', uri);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'share failed: %{public}s', JSON.stringify(e));
    }
  }

  private flushSave(): void {
    if (!docStore.isReady() || this.docModel.isEmpty()) {
      return;
    }
    try {
      this.docId = docStore.save(this.docId, this.docModel.toDocData(),
        this.resolveString($r('app.string.doc_untitled')));
      hilog.info(DOMAIN, TAG, 'saved doc id=%{public}s', this.docId);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'flushSave failed');
    }
  }

  /** 启动时恢复上一次编辑的文档（JSON + 元数据），光标一并恢复。 */
  private restoreLastDocument(): void {
    try {
      const list: DocSummary[] = docStore.list();
      if (list.length === 0) {
        return;
      }
      const data: DocData | null = docStore.load(list[0].id);
      if (data === null) {
        return;
      }
      this.docId = list[0].id;
      this.docModel = new DocModel(data);
      this.hintText = '';
      hilog.info(DOMAIN, TAG, 'restored doc id=%{public}s lines=%{public}s',
        this.docId, data.lines.length.toString());
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'restoreLastDocument failed');
    }
  }

  private syncRows(): void {
    const lines = this.docModel.getLines();
    const cursor = this.docModel.getCursor();
    const next: PaperRow[] = [];
    for (let i = 0; i < lines.length; i++) {
      const row: PaperRow = { line: i, text: lines[i].text, ribbon: lines[i].ribbon, active: i === cursor.line };
      next.push(row);
    }
    this.rows = next;
  }

  /** 打开一张纸到主屏编辑（§5.2/§5.3）：加载 JSON 内容并同步机器/纸/色带/字体。 */
  private loadDocument(id: string): void {
    const data: DocData | null = docStore.load(id);
    if (data === null) {
      hilog.warn(DOMAIN, TAG, 'loadDocument miss id=%{public}s', id);
      return;
    }
    this.docId = id;
    this.docModel = new DocModel(data);
    this.machineKind = data.meta.machine;
    this.paperKind = data.meta.paper;
    this.ribbon = data.meta.ribbon;
    this.carriageOffsetVp = 0;
    this.paperAnimateNext = false;
    this.syncRows();
    this.recalcPaperHeight();
    // 私有 docModel 不是 @State：借 docsRev 触发一次重建，纸面才会换成新文档
    this.docsRev = this.docsRev + 1;
    // P0-4：纸张记录的机器可能与本机不同，加载后必须重解析键位表
    this.reloadKeymap();
    // P0-3 断言：加载后归属必须还在（否则下一次保存会把它变未归档）
    hilog.info(DOMAIN, TAG, 'dossierAssert load id=%{public}s dossierId=%{public}s',
      id, this.docModel.getDossierId() === null ? 'null' : this.docModel.getDossierId());
    hilog.info(DOMAIN, TAG, 'loadDocument id=%{public}s rows=%{public}s',
      id, this.docModel.getLines().length.toString());
  }

  /** §5.4 删卷宗：mode='unfile' 纸移出变未归档；'purge' 连纸一起删。只删索引，不默认连删。 */
  private deleteDossier(id: string, mode: string): void {
    const all: DocSummary[] = docStore.list();
    let n: number = 0;
    for (let i = 0; i < all.length; i++) {
      const did: string | null | undefined = all[i].dossierId;
      if (did === undefined || did === null || did !== id) {
        continue;
      }
      n = n + 1;
      if (mode === 'purge') {
        docStore.remove(all[i].id);
      } else {
        const data: DocData | null = docStore.load(all[i].id);
        if (data !== null) {
          data.dossierId = null;
          docStore.save(all[i].id, data, '未命名');
        }
      }
    }
    dossierStore.removeIndexOnly(id);
    hilog.info(DOMAIN, TAG, 'deleteDossier id=%{public}s mode=%{public}s papers=%{public}s',
      id, mode, n.toString());
    this.detailOpen = false;
    this.openDossierId = '';
    this.docsRev = this.docsRev + 1;
  }

  /** 卷宗内页用：读一次 docsRev 以建立依赖，再取列表。 */
  /** P1-8：带缓存的列表读取——docsRev 不变就复用上一次结果。 */
  /** 顶栏下沿（菜单浮层锚点）。 */
  private topInsetValue(): number {
    return this.topInset + this.topBarHeight;
  }

  private listDocs(): DocSummary[] {
    const rev: number = this.docsRev;
    if (rev !== this.docsCacheRev) {
      this.docsCache = docStore.list();
      this.docsCacheRev = rev;
    }
    return this.docsCache;
  }

  /** §5.2 新建纸张：在该卷宗里建一张空白纸（dossierId 记当前卷宗）。 */
  private newPaperInDossier(): void {
    const data: DocData = {
      lines: [{ text: '', ribbon: this.docModel.toDocData().meta.ribbon }],
      cursor: { line: 0, offset: 0 },
      meta: {
        machine: this.machineKind,
        paper: this.paperKind,
        ribbon: this.ribbon,
        font: this.docModel.toDocData().meta.font,
        createdAt: Date.now(),
        updatedAt: Date.now(),
      },
      dossierId: this.openDossierId.length > 0 ? this.openDossierId : null,
    };
    const id: string = docStore.save('', data, '未命名');
    hilog.info(DOMAIN, TAG, 'newPaper in dossier=%{public}s doc=%{public}s',
      this.openDossierId, id);
    this.docsRev = this.docsRev + 1;
  }

  private resolveString(res: Resource): string {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx !== undefined && ctx !== null) {
        return ctx.resourceManager.getStringSync(res.id);
      }
    } catch (e) {
      // 资源缺失降级空串
    }
    return '';
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 中文输入锚点：隐藏 TextInput（只做 IME 绑定锚点，不显示、不参与排版）
      TextInput({ text: '' })
        .id('cn_anchor')
        .width(1).height(1).opacity(0.01)
        .position({ x: 0, y: 0 })
        .enabled(this.langZh)
        // 诊断：若提交串被这个隐藏字段吞掉，这里能看到
        .onChange((v: string) => {
          // 系统输入法把提交串投给了这个隐藏字段（控制器收不到，见诊断日志），
          // 这里取增量转发进同一条落字链；缩短时只更新基线，不动文档
          const prev: string = this.cnAnchorPrev;
          if (v.length > prev.length) {
            const added: string = v.substring(prev.length);
            hilog.info(DOMAIN, TAG, 'cn anchor delta=%{public}s', added.length.toString());
            this.enqueueChinese(added);
          } else if (v.length < prev.length) {
            // 输入法退格把锚点文本缩短 → 对称地删已提交字符（预编辑中不动文档）
            const d: number = prev.length - v.length;
            hilog.info(DOMAIN, TAG, 'cn anchor shrink=%{public}s preview=%{public}s',
              d.toString(), this.cnPreview.length.toString());
            if (this.cnPreview.length === 0) {
              for (let i = 0; i < d; i++) { this.onDelete(); }
            }
          }
          this.cnAnchorPrev = v;
        })

      // 隐藏整行 Text：实测纸面真实渲染宽（三角/打击点/扣子走它）
      Row() {
        Text(this.currentLineText())
          .fontSize(this.fontSizeVp)
          .fontFamily(this.fontFamily)
          .opacity(0)
          .onAreaChange((oldA: Area, newA: Area) => {
            const w: number = newA.width as number;
            if (Math.abs(w - this.lineWidthMeasuredVp) >= 0.1) {
              this.lineWidthMeasuredVp = w;
              hilog.info(DOMAIN, TAG, 'lineW measured=%{public}s', w.toFixed(2));
            }
          })
      }
      .width('100%')
      .height(1)
      .opacity(0)

      // §2.9 内容伸到栏下，用安全区避让
      // 深底背景铺满整屏；舞台居中
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [['#171310', 0.0], ['#241c16', 1.0]],
        })

      Column() {
        // 顶栏 56vp 本体不变，顶距 = 动态 topInset（深底渐变伸到状态栏下）
        Column().width('100%').height(this.topInset)
        TopBar({ title: this.docTitle, heightVp: this.topBarHeight,
          onOpenHome: (): void => { this.popTo('home'); },
          onOpenMenu: (): void => { this.menuOpen = true; } })

        Column() {
          Column().width('100%').height(this.paperTopGap)

          Stack({ alignContent: Alignment.TopStart }) {
            // ---- 字杆层（1920s）：zIndex 置顶，渲染在 PaperStage 之上；所在 Stack 不 clip 杆区 ----
            // 字杆本批隐藏（五件拼顺后再按 v5 加回）；开关不动素材、不删文件
            if (false && this.machineKind === MachineKind.UPRIGHT_1920S) {
              TypebarLayer({
                layerWidthVp: this.carriageHeight * 2.5,
                layerHeightVp: this.carriageHeight * 2.5,
                strikeTick: this.strikeTick,
                animScale: 1,
                // 字杆支点 x = 打击点（纸屏左 + marginH + 已落字总宽）
                offsetXVp: (this.stageWidth - this.paperWidthVp) / 2 + this.carriageOffsetVp
                  + findPaper(this.paperKind).marginH + this.currentLineWidthVp() - this.carriageHeight * 2.5 / 2,
                // 杆头落在打击行（纸底 − 底边距 − 行高/2），不是纸底缘
                // 层内杆尖 y = 0.115×H（H=stageWidth），故 offsetY = strikeY − 0.115×H
                // 总成坐标系：层底对齐 Stack 底，杆尖 0.115×H；offsetY 使杆尖落在打击行
                // 杆尖 y = strikeLineVp：层内杆尖在 0.115×层高处
                offsetYVp: this.strikeLineVp - 0.115 * (this.carriageHeight * 2.5),
                onArrive: (): void => {
                  this.onStrikeArrive();
                },
              })
                .zIndex(10)
            }

            // ---- 滚筒（纸后）：底对齐纸面区底，纸底锚定在滚筒中心 ----
            if (this.machineKind === MachineKind.UPRIGHT_1920S && this.useLayers) {
              CarriageLayers({
                stageWidth: this.photoW(),
                joltYVp: this.joltYVp,
                knobAngleDeg: this.knobAngle,
                part: 'roller',
                rollerAngleDeg: this.knobAngle,
                paperWidthVp: this.paperWidthVp,
                paperLeftVp: (this.stageWidth - this.paperWidthVp) / 2 + this.carriageOffsetVp,
                strikeXVp: this.clampedStrikeXVp(),
                canvasOffsetVp: this.carriageOffsetVp,
                strikeYVp: 0,
                paperLeftFixedVp: this.paperLeftFixed(),
                texOffsetYVp: this.texOffsetVp,
              })
                // 滚筒顶 y = Ht − Hc（实测 Ht），与金属件同一锚点
                // 滚筒锚点钉死：offset y = carriageTopVp − Hc/2（纸底 = carriageTopVp + Hc/2）
                .offset({ y: this.carriageTopVp - this.carriageHeight / 2 })
                .zIndex(1)
            }

            // ---- 字杆篮扇面（纸后、滚筒前）：独立层，不放进带 clip 的 roller Stack ----
            // 篮扇本批隐藏（五件拼顺后再按 v5 加回）；开关不动素材
            if (false && this.machineKind === MachineKind.UPRIGHT_1920S && this.useLayers) {
              CarriageLayers({
                stageWidth: this.photoW(),
                joltYVp: this.joltYVp,
                knobAngleDeg: this.knobAngle,
                part: 'basket',
                paperWidthVp: this.paperWidthVp,
                paperLeftVp: (this.stageWidth - this.paperWidthVp) / 2 + this.carriageOffsetVp,
                strikeXVp: this.clampedStrikeXVp(),
                canvasOffsetVp: this.carriageOffsetVp,
                strikeYVp: 0,
              })
                .offset({ y: this.carriageTopVp - this.carriageHeight / 2 })
                .zIndex(1.5)
            }

            // ---- 压纸卷 + 中央件 + 旋钮（纸前）：包在 Stack 里，zIndex 3 盖在纸上 ----
            Stack({ alignContent: Alignment.TopStart }) {
              if (this.machineKind === MachineKind.UPRIGHT_1920S && this.useLayers) {
                CarriageLayers({
                  stageWidth: this.photoW(),
                  joltYVp: this.joltYVp,
                  knobAngleDeg: this.knobAngle,
                    part: 'metal',
                  paperWidthVp: this.paperWidthVp,
                  paperLeftVp: (this.stageWidth - this.paperWidthVp) / 2 + this.carriageOffsetVp,
                  strikeXVp: this.clampedStrikeXVp(),
                  canvasOffsetVp: this.carriageOffsetVp,
                  paperLeftFixedVp: this.paperLeftFixed(),
                  texOffsetYVp: this.texOffsetVp,
                  bailShiftVp: this.isTablet ? -15 : 0,
                    strikeYVp: this.strikeLineVp - (this.carriageTopVp - this.carriageHeight / 2),
                })
                  // 金属组件顶 y = Ht − Hc（滚筒顶），用实测 Ht
                  // 金属件与滚筒同锚点：旋钮中心 y = 滚筒中心
                  .offset({ y: this.carriageTopVp - this.carriageHeight / 2 })

                // 拨杆支点支架：销钉中心对齐 lever.png 支点孔 (0.500,0.952)
                Image($rawfile('layers/1920s-upright/lever-pivot-bracket.png'))
                  .width(this.bracketW())
                  .height(this.bracketH())
                  .objectFit(ImageFit.Fill)
                  .position({
                    x: this.bracketLeftRel(),
                    y: this.carriageTopVp - this.carriageHeight / 2 + this.bracketTopRel(),
                  })
                  .zIndex(8)

                // 拨杆：支点 = 车条右端 + O，支点 y = Hc/2（滚筒中心相对金属顶）
                LeverLayer({
                  // 拨杆：平板用 Hc×2.0（顶端不高于纸顶 311.2），手机 Hc×2.5 不动
                  layerSizeVp: this.leverW(),
                  newlineTick: this.newlineTick,
                  // 支点 = 支架销钉孔 (0.503,0.293)；拨杆静止外倾 30°（LeverLayer 内 REST_DEG）
                  offsetXVp: this.pinXRel() - this.leverW() / 2,
                  offsetYVp: this.carriageTopVp - this.carriageHeight / 2 + this.pinYRel()
                    - (this.leverW() / (536 / 2522)) * 0.952,
                  onSwingStart: (): void => {
                    this.audioService.playCarriageReset();
                  },
                  onLeverTap: (): void => {
                    this.onNewline();
                  },
                })
              }
            }
            .width('100%')
            .height('100%')
            .hitTestBehavior(HitTestMode.Transparent)
            .zIndex(3)

            // 页码轨锚定纸片：与纸片同高、同底
            Stack({ alignContent: Alignment.TopEnd }) {
              PaperStage({
                regionHeightVp: this.regionHeightVp,
                paperHeightVp: this.paperHeightVp,
                paperKind: this.paperKind,
                hasHeader: findPaper(this.paperKind).hasHeader,
                hasRuledGrid: findPaper(this.paperKind).hasRuledGrid,
                rows: this.rows,
                hintText: this.hintText,
                lineHeightVp: this.lineHeightVp,
                fontSizeVp: this.fontSizeVp,
                fontFamily: this.fontFamily,
                marginHVp: findPaper(this.paperKind).marginH,
                marginTopVp: findPaper(this.paperKind).marginTop,
                marginBottomVp: findPaper(this.paperKind).marginBottom,
                inkColor: this.inkColor,
                pageNo: 1,
                // 物理模型：纸偏移 = (导件 − 左边距) + O，行首即让第一字落在导件
                offsetXVp: 0,
                cursorXVp: findPaper(this.paperKind).marginH + this.currentLineWidthVp(),
                // 三角 y = 打击行（相对纸顶）− 8vp，且 ≥0
                // 三角 y = 打击行 − 纸顶 − 8vp，且 ≥0（打击行固定）
                cursorYVp: Math.max(0, this.strikeLineVp - this.paperTopVp - 8),
                cursorVisible: true,
                visibleBottomVp: this.paperContainerVp,
                // 字杆层与拨杆层在纸之上渲染（E 项）

              })
                .width('100%')
                .height(this.paperHeightVp)

              Row() {
                PageRail({ pageNo: 1, pageCount: 1 })
              }
              .width('100%')
              .height(this.paperHeightVp)
              .justifyContent(FlexAlign.End)
              .alignItems(VerticalAlign.Top)
              .padding({ right: 2, top: 6 })
              .hitTestBehavior(HitTestMode.Transparent)
            }

            // 纸片容器：高 = 纸顶到滚筒，clip(true) 把纸底裁掉，不许在字体条/键盘区露出
            .width(this.paperWidthVp)
            .height(this.paperContainerVp)
            // 纸与字同一刚体：容器 x 带 O，纸内不再重复 translate(O)
            .offset({ x: (this.stageWidth - this.paperWidthVp) / 2 + this.carriageOffsetVp, y: this.paperTopVp })
            // 平时 clip(true) 裁掉纸底；换纸第①步切整张模式时不裁，整片飞出去
            .clip(!this.paperFullSheet)
            // 纸面不透明度 × 换装淡入淡出（§4：200ms，不重建编辑器）
            .opacity(this.paperOpacity * this.switchFade)
            // 纸夹在滚筒(1)与金属件(3)之间：滚筒只露下半截，纸须延伸到滚筒中心
            .zIndex(2)
          }
          .width('100%')
          .height(this.availableHeightVp)
          .clip(false)
          .onAreaChange((oldA: Area, newA: Area) => {
            this.stackTopGlobalYVp = newA.globalPosition.y as number;
            const ht: number = newA.height as number;
            if (Math.abs(ht - this.assemblyHeightVp) >= 1) {
              this.assemblyHeightVp = ht;
              hilog.info(DOMAIN, TAG, 'assembly Ht=%{public}s Hc=%{public}s', ht.toFixed(1), this.carriageHeight.toFixed(1));
            }
          })
        }
        .width('100%')
        .layoutWeight(1)

        if (this.machineKind === MachineKind.UPRIGHT_1920S && this.useLayers) {
          // 1920s 的滚筒/中央件已在总成 Stack 内渲染；此处只占位保持纵向构成高度
          Column().width('100%').height(0)
        } else {
          CarriageStrip({
            machineKind: this.machineKind,
            widthVp: this.photoW(),
            photoWidthVp: this.stageWidth + this.maxTravelVp,
            heightVp: this.carriageHeight,
            guideXVp: this.guideXVp,
            carriageOffsetVp: this.carriageOffsetVp,
            guideVisible: false,
          })
            .margin({ top: -CARRIAGE_PAPER_OVERLAP_VP })
        }

        // 内置中文常驻候选栏（44vp 占位，不随组词伸缩）：设计稿 §5
        if (this.isBuiltinCn()) {
          CandidateBar({
            candidates: this.candCurrent,
            pinyin: this.cnPinyin,
            pages: this.candPages,
            page: this.candPage,
            onPick: (i: number): void => { this.pinyinPick(i); },
            onPrev: (): void => {
              if (this.candPage > 0) {
                this.candPage = this.candPage - 1;
                this.pinyinShown();
              }
            },
            onNext: (): void => {
              if (this.candPage + 1 < this.candPages) {
                this.candPage = this.candPage + 1;
                this.pinyinShown();
              }
            },
          })
        }

        FontBar({
          fontFamily: this.fontFamily,
          fontLabel: fontDisplayName(this.docModel.toDocData().meta.font),
          heightVp: this.fontBarHeight,
          onOpenCustomize: (): void => { this.pushPage('customize'); },
        })

        PhotoKeybed({
          machineKind: this.machineKind,
          foldBand: false,
          widthVp: this.photoW(),
          heightVp: this.keybedHeight,
          layout: this.displayLayout(),
          overlayFontFamily: this.fontFamily,
          commitSeq: this.commitSeq,
          onCapDown: (cap: CapDef): void => {
            this.onCapDown(cap);
          },
          onCapSlide: (cap: CapDef): void => {
            if (!cap.isExtra && cap.label !== ' ') {
              this.audioService.playKey();
            }
          },
          onCapUp: (cap: CapDef): void => {
            // Shift 松开即清（多触点：松开 Shift 不影响正在按的字母）
            if (cap.label === 'Shift') {
              this.shiftActive = false;
            }
          },
        })

        FunctionRow({
          heightVp: this.functionRowHeight,
          langLabel: this.langZh
            ? this.resolveString($r('app.string.keyboard_lang_zh'))
            : this.resolveString($r('app.string.keyboard_lang_en')),
          deleteLabel: this.resolveString($r('app.string.keyboard_delete')),
          newlineLabel: this.resolveString($r('app.string.keyboard_newline')),
          paperLabel: this.resolveString($r('app.string.keyboard_paper')),
          backLineLabel: this.resolveString($r('app.string.keyboard_backline')),
          charLabel: this.resolveString(this.symbolMode
            ? $r('app.string.keyboard_letters') : $r('app.string.keyboard_symbols')),
          onSymbols: (): void => {
            this.symbolMode = !this.symbolMode;
          },
          onBackLine: (): void => {
            this.onBackLine();
          },
          onPaperChange: (): void => {
            this.onPaperChange();
          },
          onLang: (): void => {
            this.langZh = !this.langZh;
            this.applyChineseMode(this.langZh);
            // 语言切换同步改行高与纸高（中文 fs×30/17、英文 fs×28/17）
            this.lineHeightVp = this.langZh ? this.fontSizeVp * (30 / 17) : this.fontSizeVp * (28 / 17);
            this.recalcPaperHeight();
          },
          onDelete: (): void => {
            // §13 第 9 步：组词中按删除只删拼音字母，不许删文档字符
            if (this.isBuiltinCn() && this.pinyinSession !== null
              && this.pinyinSession.getBuffer().length > 0) {
              this.pinyinSession.backspace();
              this.audioService.playBackspace();
              this.audioService.vibrate();
              this.pinyinRefresh();
              hilog.info(DOMAIN, TAG, 'cn backspace in compose buf=%{public}s',
                this.pinyinSession.getBuffer());
              return;
            }
            this.onDelete();
          },
          onNewline: (): void => {
            this.onNewline();
          },
        })

        // 功能行 52vp 本体不变，底距 = 动态 bottomInset
        Column().width('100%').height(this.bottomInset)
      }
      .width(this.stageWidth)
      .height(this.stageHeight)
      .alignItems(HorizontalAlign.Start)
      // 键盘避让：整体上移保打击行可见；收起归零，不留空区
      .translate({ y: -this.kbShift })

      // 卷宗页（§5.1）：整页覆盖层，最后绘制、盖住主屏
      // §11 主页：冷启动首帧；从任何页返回也回这里
      // 主页常驻以便滑入时垫底；但栈顶是 typewriter 时必须让位（否则盖住打字机）
      if (this.navStack.indexOf('home') >= 0
        && this.navStack[this.navStack.length - 1] !== 'typewriter') {
        HomePage({
          widthVp: this.winWidthVp > 0 ? this.winWidthVp : this.stageWidth,
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          onContinue: (): void => {
            const list = docStore.list();
            if (list.length > 0) {
              this.loadDocument(list[0].id);
              this.pushPage('typewriter');
            }
          },
          onStartTyping: (): void => {
            // 新建一张空白纸并进入打字机
            const meta = this.docModel.toDocData().meta;
            const fresh: DocData = {
              lines: [{ text: '', ribbon: this.ribbon }],
              cursor: { line: 0, offset: 0 },
              meta: meta,
            };
            const nid: string = docStore.save('', fresh, '未命名');
            this.docsRev = this.docsRev + 1;
            this.loadDocument(nid);
            this.pushPage('typewriter');
          },
          onOpen: (key: string): void => {
            if (key === 'dossier') { this.pushPage('dossier'); }
            if (key === 'collection') { this.pushPage('collection'); }
            if (key === 'customize') { this.pushPage('customize'); }
            if (key === 'settings') { this.pushPage('settings'); }
            if (key === 'export') { this.pushPage('export'); }
          },
        })
          // 与另外 8 个分支完全相同的过渡；冷启动首帧不启用
          .transition(this.navAnimated
            ? TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut })
            : TransitionEffect.IDENTITY)
      }

      if (this.dossierOpen) {
        DossierPage({
          widthVp: this.winWidthVp > 0 ? this.winWidthVp : this.stageWidth,
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          docs: docStore.list(),
          onBack: (): void => { this.popPage(); },
          onOpenDossier: (id: string): void => { this.openDossierId = id; this.pushPage('detail'); },
        })
          .transition(TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut }))
      }

      // 卷宗内页（§5.2）
      // 换装页（§4）：换装即时生效（改状态后主屏下一帧即换装，不重建编辑器）
      if (this.customizeOpen) {
        CustomizePage({
          widthVp: this.winWidthVp > 0 ? this.winWidthVp : this.stageWidth,
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          machineKind: this.machineKind as string,
          paperKind: this.paperKind as string,
          ribbonKind: this.ribbon as string,
          fontKind: this.docModel.toDocData().meta.font as string,
          failedFonts: this.fontLoadFailed,
          onBack: (): void => { this.popPage(); },
          onPickMachine: (k: string): void => {
            this.applyMachine(k as MachineKind);
            hilog.info(DOMAIN, TAG, 'customize machine -> %{public}s', k);
          },
          onPickPaper: (k: string): void => {
            this.applyPaper(k as PaperKind);
            hilog.info(DOMAIN, TAG, 'customize paper -> %{public}s', k);
          },
          onPickRibbon: (k: string): void => {
            this.applyRibbon(k as RibbonKind);
            hilog.info(DOMAIN, TAG, 'customize ribbon -> %{public}s ink=%{public}s',
              k, this.inkColor);
          },
          onPickFont: (f: string): void => {
            // §4 换装即时生效：切换纸面字体（docModel + 渲染族名）
            for (let i = 0; i < FONTS.length; i++) {
              if ((FONTS[i].font as string) === f) {
                this.docModel.setFont(FONTS[i].font);
                this.fontFamily = FONTS[i].familyName + ', Noto Serif SC';
                this.flushSave();
                hilog.info(DOMAIN, TAG, 'customize font -> %{public}s family=%{public}s',
                  f, FONTS[i].familyName);
                break;
              }
            }
          },
        })
          .transition(TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut }))
      }

      // 收藏页（§3）：先渲染，详情页在其后渲染才能盖在它上面
      if (this.collectionOpen) {
        CollectionPage({
          widthVp: this.winWidthVp > 0 ? this.winWidthVp : this.stageWidth,
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          currentMachine: this.machineKind as string,
          onBack: (): void => { this.popPage(); },
          onPick: (kind: string): void => { this.collectionDetailKind = kind; this.pushPage('collectiondetail'); },
        })
          .transition(TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut }))
      }

      // 收藏详情页（§3）：只对已解锁机器开放；必须排在收藏页之后（后者先绘制）
      if (this.collectionOpen && this.collectionDetailKind.length > 0) {
        CollectionDetailPage({
          widthVp: this.winWidthVp > 0 ? this.winWidthVp : this.stageWidth,
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          machineKind: this.collectionDetailKind,
          onBack: (): void => { this.popPage(); },
          onSetCurrent: (kind: string): void => {
            this.applyMachine(kind as MachineKind);
            this.collectionDetailKind = '';
            this.collectionOpen = false;
            hilog.info(DOMAIN, TAG, 'collection setCurrent -> %{public}s', kind);
          },
        })
          .transition(TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut }))
      }


      // D1：汉堡下拉菜单（最上层）

      // §6.1 设置页（最后渲染，盖在其他覆盖层之上）
      if (this.settingsOpen) {
        SettingsPage({
          widthVp: this.winWidthVp > 0 ? this.winWidthVp : this.stageWidth,
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          machineLabel: this.machineKind as string,
          paperLabel: this.paperKind as string,
          cnEngine: this.cnEngine,
          onOpenPinyinSettings: (): void => {
            this.refreshPinyinMeta();
            this.pushPage('pinyinsettings');
            // 设置页要用引擎（加词／学习计数），先异步加载
            this.ensurePinyinEngine().then(() => {
              this.refreshPinyinMeta();
            });
          },
          onPickCnEngine: (): void => {
            const next: string = this.cnEngine === 'builtin' ? 'system' : 'builtin';
            this.cnEngine = next;
            appPreferences.setString(PrefKeys.CN_ENGINE, next);
            // 切换后立即按新引擎重进/退出中文，避免残留状态
            if (this.langZh) {
              this.applyChineseMode(false);
              this.langZh = false;
            }
            hilog.info(DOMAIN, TAG, 'cn engine -> %{public}s', next);
          },
          onBack: (): void => { this.popPage(); },
        })
          .transition(TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut }))
      }

      // §6.2 导出页
      if (this.exportOpen) {
        ExportPage({
          widthVp: this.winWidthVp > 0 ? this.winWidthVp : this.stageWidth,
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          docId: this.docId,
          onBack: (): void => { this.popPage(); },
          onShare: (format: string): void => {
            // P1-6：三种格式。当前实现纯文本（.txt 可再编辑）；图片/PDF 走占位并明确记录
            hilog.info(DOMAIN, TAG, 'export share format=%{public}s', format);
            if (format === '纯文本') {
              try {
                const host = this.getUIContext().getHostContext();
                const dir: string = host === undefined || host === null ? ''
                  : (host as common.Context).filesDir;
                if (dir.length > 0) {
                  const p: string = dir + '/export-' + Date.now().toString() + '.txt';
                  const f: fs.File = fs.openSync(p,
                    fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
                  fs.writeSync(f.fd, docStore.readPlainText(this.docId));
                  fs.closeSync(f);
                  hilog.info(DOMAIN, TAG, 'export txt ok path=%{public}s', p);
                  this.shareFile(p, 'general.plain-text');
                }
              } catch (e) {
                hilog.error(DOMAIN, TAG, 'export txt failed');
              }
            } else if (format === '图片') {
              // §6.2：图片＝所见即所得离屏渲染（点击时抓，不在构建期）
              const host = this.getUIContext().getHostContext();
              const dir: string = host === undefined || host === null ? ''
                : (host as common.Context).filesDir;
              if (dir.length > 0) {
                const p: string = dir + '/export-' + Date.now().toString() + '.png';
                this.getUIContext().getComponentSnapshot().get('export_preview')
                  .then((pm: image.PixelMap) => {
                    const packer: image.ImagePacker = image.createImagePacker();
                    packer.packToData(pm, { format: 'image/png', quality: 100 })
                      .then((buf: ArrayBuffer) => {
                        try {
                          const f: fs.File = fs.openSync(p,
                            fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
                          fs.writeSync(f.fd, buf);
                          fs.closeSync(f);
                          hilog.info(DOMAIN, TAG, 'export png ok path=%{public}s bytes=%{public}s',
                            p, buf.byteLength.toString());
                        } catch (e2) {
                          hilog.error(DOMAIN, TAG, 'export png write failed');
                        }
                        this.shareFile(p, 'general.png');
                      })
                      .catch(() => { hilog.error(DOMAIN, TAG, 'export png pack failed'); });
                  })
                  .catch(() => { hilog.error(DOMAIN, TAG, 'export png snapshot failed'); });
              }
            } else if (format === 'PDF') {
              // §6.2：PDF＝PDF Kit 文本路径
              try {
                const host = this.getUIContext().getHostContext();
                const dir: string = host === undefined || host === null ? ''
                  : (host as common.Context).filesDir;
                const p: string = dir + '/export-' + Date.now().toString() + '.pdf';
                const pdf: pdfService.PdfDocument = new pdfService.PdfDocument();
                if (pdf.createDocument(595, 842)) {
                  const page: pdfService.PdfPage = pdf.getPage(0);
                  const style: pdfService.TextStyle = new pdfService.TextStyle();
                  style.textSize = 11;
                  const lines: string[] = docStore.readPlainText(this.docId).split('\n');
                  let y: number = 800;
                  for (let i = 0; i < lines.length && y > 40; i++) {
                    if (lines[i].length > 0) {
                      page.addTextObject(lines[i], 48, y, style);
                    }
                    y -= 16;
                  }
                  const ok: boolean = pdf.saveDocument(p);
                  pdf.releaseDocument();
                  hilog.info(DOMAIN, TAG, 'export pdf ok=%{public}s path=%{public}s',
                    ok ? 'true' : 'false', p);
                  this.shareFile(p, 'general.pdf');
                } else {
                  hilog.error(DOMAIN, TAG, 'export pdf createDocument failed');
                }
              } catch (e) {
                hilog.error(DOMAIN, TAG, 'export pdf failed: %{public}s', JSON.stringify(e));
              }
            } else {
              hilog.warn(DOMAIN, TAG, 'export %{public}s not implemented yet', format);
            }
          },
        })
          .transition(TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut }))
      }

      if (this.dossierOpen && this.detailOpen) {
        DossierDetailPage({
          widthVp: this.winWidthVp > 0 ? this.winWidthVp : this.stageWidth,
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          dossierId: this.openDossierId,
          docs: this.listDocs(),
          onBack: (): void => { this.popPage(); },
          onOpenPaper: (id: string): void => {
            // §5.2：点「打开」进打字页——栈退到 typewriter 层再载入
            this.loadDocument(id);
            this.popTo('typewriter');
          },
          onDeleteDossier: (mode: string): void => { this.deleteDossier(this.openDossierId, mode); },
          onNewPaper: (): void => { this.newPaperInDossier(); },
          onOpenDoc: (id: string): void => { this.openDocId = id; this.pushPage('docview'); },
          onRenamed: (): void => {
            this.docsRev = this.docsRev + 1;
            hilog.info(DOMAIN, TAG, 'renamed rev=%{public}s (list will refresh)', this.docsRev.toString());
          },
          onDeletePaper: (id: string): void => {
            docStore.remove(id);
            this.docsRev = this.docsRev + 1;
            hilog.info(DOMAIN, TAG, 'paperDeleted id=%{public}s rev=%{public}s',
              id, this.docsRev.toString());
          },
        })
          .transition(TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut }))
      }

      // 文档视图（§5.3）：必须排在卷宗内页之后，才能盖在内页之上
      if (this.dossierOpen && this.openDocId.length > 0) {
        DocumentViewPage({
          widthVp: this.winWidthVp > 0 ? this.winWidthVp : this.stageWidth,
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          docId: this.openDocId,
          onBack: (): void => { this.popPage(); },
          onEdit: (id: string): void => {
            // 点正文页进打字机：栈退到 typewriter 层
            this.loadDocument(id);
            this.popTo('typewriter');
          },
          onDelete: (id: string): void => {
            docStore.remove(id);
            this.openDocId = '';
            this.docsRev = this.docsRev + 1;
          },
          onAddPage: (id: string): void => {
            // P1-5：入口日志——点了没有这一行说明点击没到按钮
            hilog.info(DOMAIN, TAG, 'addPage enter id=%{public}s', id);
            const data: DocData | null = docStore.load(id);
            if (data !== null) {
              data.lines.push({ text: '', ribbon: this.ribbon });
              docStore.save(id, data, '未命名');
              this.docsRev = this.docsRev + 1;
              hilog.info(DOMAIN, TAG, 'addPage ok id=%{public}s lines=%{public}s',
                id, data.lines.length.toString());
            }
          },
        })
          .transition(TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut }))
      }

      if (this.pinyinSettingsOpen) {
        PinyinSettingsPage({
          widthVp: this.winWidthVp > 0 ? this.winWidthVp : this.stageWidth,
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          fuzzyOn: this.fuzzyOn,
          userWords: this.userWordsFlat,
          dictInfo: this.dictInfo,
          learnCount: this.learnCount,
          onBack: (): void => { this.popPage(); },
          onToggleFuzzy: (): void => { this.toggleFuzzy(); },
          addPinyin: this.draftPinyin,
          onWordChanged: (w: string): void => {
            this.draftPinyin = this.pinyinEngine === null ? '' : this.pinyinEngine.pinyinOfWord(w);
          },
          onPinyinEdited: (p: string): void => { this.draftPinyin = p; },
          onAddWord: (w: string, py: string): void => {
            this.draftPinyin = py.trim();
            this.addUserWord(w);
          },
          onDeleteWord: (w: string): void => { this.deleteUserWord(w); },
          onClearLearn: (): void => { this.clearLearn(); },
        })
          .transition(this.navAnimated
            ? TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut })
            : TransitionEffect.IDENTITY)
      }

      if (this.menuOpen) {
      AppMenu({
        visible: this.menuOpen,
        topVp: this.topInsetValue(),
        onClose: (): void => { this.menuOpen = false; },
        onPick: (key: string): void => {
          if (key === 'collection') { this.pushPage('collection'); }
          if (key === 'settings') { this.pushPage('settings'); }
          if (key === 'export') { this.pushPage('export'); }
        },
      })
          // 关闭淡出 150ms（打开动画在 AppMenu 内部）
          .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.EaseOut }))
      }

      // 悬浮 A 键只在 system 模式出现（设计稿 §1：builtin 没有系统键盘盖住底行，不需要它）
      if (this.langZh && this.cnEngine === 'system') {
        Text('A')
          .fontSize(15).fontWeight(FontWeight.Bold).fontColor('#171310')
          .width(44).height(44).textAlign(TextAlign.Center)
          .borderRadius(28).backgroundColor('#c9a45c')
          // 顶栏下方、纸面区右缘内侧（避开顶栏汉堡/文件夹与底部功能行）
          .position({ x: this.stageWidth - 56, y: this.topInset + this.topBarHeight + 16 })
          .onClick(() => {
            this.langZh = false;
            this.applyChineseMode(false);
          })
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onAreaChange((oldArea: Area, newArea: Area) => {
      const w: number = newArea.width as number;
      const h: number = newArea.height as number;
      const dw: number = Math.abs(w - this.winWidthVp);
      const dh: number = Math.abs(h - this.winHeightVp);
      // 去抖：小于 1vp 视为同一次
      if (dw < 1 && dh < 1 && this.winWidthVp > 0) {
        return;
      }
      this.winWidthVp = w;
      this.winHeightVp = h;
      this.measureStage();
    })
  }
}