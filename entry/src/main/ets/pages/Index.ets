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
// 第 26 批（批 3／§4.3）：帧时钟迁入 Index（Animator，全稿单一时间源）
import Animator, { AnimatorOptions, AnimatorResult } from '@ohos.animator';
import { ANIM_MODE_REALISTIC, ANIM_MODE_SIMULATED, SIM_ROLLER_K, MODE_TRANS_DUR_MS, rollerKFor } from '../model/AnimModeModel';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { ExportService } from '../services/ExportService';
import { ExportResult, formatDateText } from '../model/ExportCore';
import { resourceManager } from '@kit.LocalizationKit';
import { util } from '@kit.ArkTS';
import { deviceInfo } from '@kit.BasicServicesKit';
import { CorrectionMode, DocLine, MachineKind, PaperKind, RibbonKind } from '../model/DocModel';
import {
  CARRIAGE_PAPER_OVERLAP_VP, DEFAULT_FONT, DEFAULT_MACHINE, DEFAULT_PAPER, DEFAULT_RIBBON,
  CANDIDATE_BAR_HEIGHT_VP,
  FONT_BAR_HEIGHT_VP, FUNCTION_ROW_HEIGHT_VP, PAPER_TOP_GAP_VP, TOP_BAR_HEIGHT_VP,
  findFont, findMachine, findPaper, findRibbon, fontDisplayName, fontDisplayNameByFamily,
  FONTS, MACHINES, FontSpec,
} from '../model/MachineCatalog';
import { CapDef, KeymapLayout, KeymapParser, readRawTextSync } from '../model/KeymapModel';
import { PaperRow } from '../ui/PaperSheet';
import { Stage26, StageLayout } from '../components/type26/Stage26';
import { DocModel } from '../model/DocModelCore';
import { docStore } from '../services/DocStore';
import { dossierStore } from '../services/DossierStore';
import { DossierPage, guideStepsForDossier } from '../components/DossierPage';
import { DossierDetailPage, guideStepsForDossierDetail } from '../components/DossierDetailPage';
import { DocumentViewPage, guideStepsForDocumentView } from '../components/DocumentViewPage';
import { CollectionPage, guideStepsForCollection } from '../components/CollectionPage';
import { CustomizePage, guideStepsForCustomize } from '../components/CustomizePage';
import { FontManagerPage, guideStepsForFontManager } from '../components/FontManagerPage';
import { PaperCustomPage, guideStepsForPaperCustom } from '../components/PaperCustomPage';
import { TrashPage, guideStepsForTrash } from '../components/TrashPage';
import { CollectionDetailPage, guideStepsForCollectionDetail } from '../components/CollectionDetailPage';
import { SettingsPage, guideStepsForSettings } from '../components/SettingsPage';
import { ExportPage, guideStepsForExport } from '../components/ExportPage';
// 第 26 批（批 3／§8.2）：CanvasTypewriter 整文件已退役删除（R-B3）。
import { setExportTarget } from '../model/ExportTarget';
import { HomePage, guideStepsForHome } from '../components/HomePage';
import { chineseInput } from '../services/ChineseInput';
import { PinyinEngine, PinyinSession, Candidate, PickResult } from '../services/PinyinEngine';
import { CandidateBar } from '../components/CandidateBar';
import { PinyinSettingsPage, guideStepsForPinyinSettings } from '../components/PinyinSettingsPage';
import { AppPreferences, appPreferences, PrefKeys } from '../services/AppPreferences';
import { KeyboardAvoidMode as UcKeyboardAvoidMode } from '@ohos.arkui.UIContext';
import { AppMenu } from '../components/AppMenu';
import { DocData, DocMeta, DocSummary } from '../model/DocModel';
import { AudioService } from '../services/AudioService';
import { SoundRole } from '../ui/AudioEngine';
import { FontService, FontRegisterResult } from '../services/FontService';
import { ShareService, ShareResult } from '../services/ShareService';
import { statsService, StatsEvents } from '../services/StatsService';
import { AchievementService, AchieveNotice } from '../services/AchievementService';
import { achievementById } from '../model/AchievementDefs';
import { AppDialog } from '../components/AppDialog';
import { FoldService, FoldState } from '../services/FoldService';
import { GuideOverlay, GuideStep } from '../components/GuideOverlay';
import { OnboardingGuide } from '../components/OnboardingGuide';
import { SpotlightOverlay, SpotlightStep } from '../components/SpotlightOverlay';
import { GuideService } from '../services/GuideService';
import { GuideBridge } from '../services/GuideBridge';
import { GUIDE_PAGE_HOME, GUIDE_PAGE_DOSSIER, GUIDE_PAGE_DOSSIER_DETAIL, GUIDE_PAGE_DOCUMENT_VIEW, GUIDE_PAGE_COLLECTION, GUIDE_PAGE_COLLECTION_DETAIL, GUIDE_PAGE_CUSTOMIZE, GUIDE_PAGE_SETTINGS, GUIDE_PAGE_EXPORT, GUIDE_PAGE_PINYIN_SETTINGS, GUIDE_PAGE_TYPEWRITER, GUIDE_PAGE_FONT_MANAGER, GUIDE_PAGE_PAPER_CUSTOM, GUIDE_PAGE_TRASH } from '../model/GuideCore';
import { TopBar } from '../components/TopBar';
import { CarriageStrip } from '../components/CarriageStrip';
import { FontBar } from '../components/FontBar';
// 第 25 批（批 2／§8.1）：PhotoKeybed 整文件已退役删除（R-m20），keyband 照片同步清理。
import { KeyGrid } from '../components/KeyGrid';
import { FunctionRow } from '../components/FunctionRow';
import { PaperStage, PAPER_INITIAL_HEIGHT_VP } from '../components/PaperStage';
// 第 24 批（23 号稿批 1／§4.4）：新 UI 件——纸面板（纸是 UI 面板，文字是 Text）
import { PaperPanel } from '../components/PaperPanel';
// 第 25 批（批 2／§3.2 #3）：落字导件（矢量例外：1vp 虚线＋倒三角）
import { StrikeGuide } from '../components/StrikeGuide';
// 第 27 批（批 4／R-m24）：标准件变体（10 件 × 4 机型 = 40 键）
import { bodyColorOfVariant, bodySlugOfVariant, PART_VARIANTS } from '../model/PartVariants';
// 第 28 批（24 号稿 §2.1）：三档 token 与贴片
import { plateRawfile, shiftHexColor, tierTileRawfile, tierToken } from '../model/MachineCatalog';
import { Cheek } from '../components/Cheek';
import { SteelPlate } from '../components/SteelPlate';
import { KeyWell } from '../components/KeyWell';
import { TopZone26, Lid26, Basket26, FunctionCaps26, FontPlate26, CandStrip26, TopDeck26, TriMark26 } from '../components/type26/Parts26';
import { Carriage26 } from '../components/type26/Carriage26';

import { TypebarLayer } from '../components/TypebarLayer';
import { CarriageLayers } from '../components/CarriageLayers';
import { LeverLayer } from '../components/LeverLayer';
import { TypebarAssembly1920 } from '../machines/1920s/TypebarAssembly1920';
import { BracketAssembly1920 } from '../machines/1920s/BracketAssembly1920';
import { RollerAssembly1920 } from '../machines/1920s/RollerAssembly1920';
import { MetalAssembly1920 } from '../machines/1920s/MetalAssembly1920';
import { CarriageLayers1930 } from '../machines/1930s/CarriageLayers1930';
// §14：拨杆暂留 Index（几何已由 Blueprint 提供）
import { TypebarLayer1930 } from '../machines/1930s/TypebarLayer1930';
import { MachineBlueprint } from '../machines/BlueprintTypes';
import { dragRatioFor, pulledEnough, restDegFor, swingDegFor } from '../model/LeverAngleCore';
import { CANDIDATE_COUNT_DEFAULT, CANDIDATE_SIZE_DEFAULT, clampCandidateCount, clampCandidateSize } from '../model/CandidateCore';
import { CustomizeStore, PaperValues } from '../services/CustomizeStore';
import { deleteModeOf, volumeToPref, prefToVolume, paperPrefOf } from '../model/SettingsCore';
import { clampFontSize, effectiveFontSize, lineHeightOf, ImportedFont } from '../model/CustomizeCore';
import { nextEpoch, shouldResetOnSwitch, slotOf } from '../model/LeverStateCore';
import { BLUEPRINT_1920 } from '../machines/1920s/Blueprint';
import { BLUEPRINT_1930 } from '../machines/1930s/Blueprint';
import { BLUEPRINT_1950 } from '../machines/1950s/Blueprint';
import { BLUEPRINT_1960 } from '../machines/1960s/Blueprint';
import { CarriageLayers1950 } from '../machines/1950s/CarriageLayers';
import { CarriageLayers1960 } from '../machines/1960s/CarriageLayers';
import { LeverLayer1930 } from '../machines/1930s/LeverLayer1930';
import { LeverLayer1950 } from '../machines/1950s/LeverLayer';
import { LeverLayer1960 } from '../machines/1960s/LeverLayer';
import { TypebarLayer1950 } from '../machines/1950s/TypebarLayer';
import { TypebarLayer1960 } from '../machines/1960s/TypebarLayer';

/** 第 28 批：两色中点（档界 1vp 边线用；相邻档中间值）。 */
function mixHexColor(a: string, b: string): string {
  const pa: number[] = [Number.parseInt(a.substring(1, 3), 16), Number.parseInt(a.substring(3, 5), 16),
    Number.parseInt(a.substring(5, 7), 16)];
  const pb: number[] = [Number.parseInt(b.substring(1, 3), 16), Number.parseInt(b.substring(3, 5), 16),
    Number.parseInt(b.substring(5, 7), 16)];
  let out: string = '#';
  for (let i = 0; i < 3; i++) {
    const v: number = Math.round((pa[i] + pb[i]) / 2);
    out += (v < 16 ? '0' : '') + v.toString(16);
  }
  return out;
}

const TAG: string = 'MainScreen';
const DOMAIN: number = 0x0100;
const DESIGN_W: number = 390;
const DESIGN_H: number = 844;
/** 键带手机宽高比 2048/975；字车条 2048/287。 */
const KEYBAND_ASPECT: number = 2048 / 975;
// 第 5 批回批 F7：折叠带比值（1920s/1950s/1960s 折叠带 2048×853；1930s 复用手机带 2.101，设计稿 §2.5）
const KEYBAND_ASPECT_FOLD: number = 2048 / 853;
const CARRIAGE_STRIP_ASPECT: number = 2048 / 287;
const GROW_DURATION_MS: number = 60; // 硬曲线：纸移动 50–70ms，写死
const BELL_REMAINING: number = 8;
/** 换纸计时打点开关（第 0 批；第 9 批 F12 起默认 true＝随正常构建开启；只写 hilog，不写 prefs、不上传；排查完也不回滚）。 */
const PAPER_CHANGE_TRACE: boolean = true;
/**
 * 第 24 批（23 号稿 §4.4 Q16(a)）：纸面板满幅口径的两侧面板边距。
 * 23 号稿 362.7vp 档的基线数 Pw＝330.7 → panelMargin＝(362.7−330.7)/2＝16vp；本机按实测 stageW 重算。
 */
const PANEL_MARGIN_VP: number = 16;
// 第 25 批（23 号稿 §3.2.1 五区分配）：批 2 实测登记（ADA-AL00U 362.7×822.5vp）
/** 横尺高（§2.5 第 1 条：8vp）。 */
const H_RULER_VP: number = 8;
/** 字篮区高（§3.2.1 ④ h≈w×0.5；w＝stageW×0.8＝290.2 → 取 130，实测登记）。 */
const H_BASKET_VP: number = 130;
/** 功能行高（§D22：40vp；第 25 批按设计值，旧 52vp 常量留给旧页）。 */
const H_FUNC_ROW_V2_VP: number = 40;
/** 第 27 批（Q11a）：候选栏在键盘网格上方 44vp 常驻占位（中文模式显示候选、英文留空）。 */
const H_CAND_V2_VP: number = 44;

function emptyLayout(): KeymapLayout {
  return {
    machine: '', caps: [], spaceXMin: 0, spaceXMax: 0, spaceYMin: 0, spaceYMax: 0,
    hitRadius: 10, spaceR: 8, overlayColor: '#000000', overlayFontSize: 14, widthVp: 0, heightVp: 0,
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
  // 批 64（T6 余项）：第 17 批的 Canvas 纸段 tick 通道（canvasPaperTick/Mode/From/Target/Dur、
  // canvasPaperResetTick、paperSuppressTickOnce）整体删除——canvasEnabled 恒 false 且无组件 @Watch 这些值，
  // 纸段动画只剩 ArkUI animateTo 一条路径。
  /** 第 9 批 F12：换纸恢复打点起点（换纸入口写 pcT0；锁放开后首个被接受的 commitChar 记 dt 并清零）。 */
  private pcResumeT0: number = 0;
  /** 第 9 批 F12：onDelete 的「先落队再删」循环期间为 true——该循环触发的 commitChar 不算恢复。 */
  private pcDelFlushActive: boolean = false;
  /** §18.7：滚筒横向速度系数（滚筒走 k×O，纸张走满 O）。平板几何上限 0.914，手机 0.612——手机靠 rollX 钳制兜底 */
  private readonly ROLLER_K: number = 1.0;
  /** §19.2：手机滚筒走满 O（与纸永远对齐）；滚筒不出屏改由 maxTravel 封顶兜底 */
  private readonly ROLLER_K_PHONE: number = 1.0;
  /** §18.11：拉杆拖拽状态（拨杆节点不可触摸，改由字车层接管）。
   *  第 0b 批：按机隔离——四份独立比例状态，切机全清零；不再共享单一 leverDragRatio。 */
  @State leverRatio1920: number = 0;
  @State leverRatio1930: number = 0;
  @State leverRatio1950: number = 0;
  @State leverRatio1960: number = 0;
  /** 第 0b 批：切机纪元——渲染件 Watch 到变化立即回静止角（不带动画），切断在途摆动跨机。 */
  @State leverEpoch: number = 0;
  private leverDragActive: boolean = false;
  /** 批 2（§7）：Index 侧只留「逻辑比例」（过半判定用），不写 @State、不回写给 Canvas。 */
  private leverRatioLogical: number = 0;
  /** 批 2：松手判定结果与释放 tick（Canvas 下一帧按 commit 播提交/回弹）。 */
  @State canvasLeverReleaseTick: number = 0;
  @State canvasLeverReleaseCommit: boolean = false;
  /** 批 20：拱的目标 tick（换行/退行/换纸发；打击由 Canvas 自跟，不发）。 */
  // 第 26 批（批 3）：canvasArchTick／canvasArchTargetVp／canvasArchDurMs 随 Canvas 退役删除（R-B3）
  /** §18.8：候选栏区常驻高度（英文态也占位，不许 0/44 跳变） */
  private readonly CAND_BAR_HEIGHT_VP: number = 44;
  /** 换纸时旧纸淡出用。 */
  @State paperOpacity: number = 1;
  /** 换纸第①步：纸容器切「整张模式」（高=Ph、不裁），整张纸飞出去。 */
  // 批 64（T6 余项）：paperFullSheet（整张模式）无消费者，随容器一并删除。
  /** 滚筒纹理纵向滚动量（vp）：随纸上滑同步，换纸两段各滚半圈。 */
  @State texOffsetVp: number = 0;
  /** 换行 700ms 编排（t0=450＋250）进行中：落字先排队，编排完成后再落（不丢字、不错位）。 */
  @State newlineBusy: boolean = false;
  /** 退行动画进行中（纸 200ms + O 250ms）：落字先排队。 */
  @State backBusy: boolean = false;
  /** 本次换行是否为「下移一行」（下方有内容，不插行）。 */
  @State newlineMoveDown: boolean = false;
  /** 「下移」时字车要滑到的 O（小行程口径）。 */
  @State newlineCarriageTargetO: number = 0;
  private queuedChars: string[] = [];
  // 批 64（T6 余项）：纸片容器高 paperContainerVp 已删除——纸高/纸顶只由 flex（Carriage26 纸贴底）
  // 的 paperGrowVp 决定；旧容器值只在 parts 日志里按 paperTop 派生。
  /**
   * 第 26 批（批 3／§4.3）：帧时钟驱动的 ArkUI 字段（Canvas 退役后唯一的动画事实源）。
   * paperOffsetVp＝K×O（纸面板左移）；guideXVp＝落字导件 x；leverAngleVp＝拨杆摆角；
   * strikePhase＝打击相位 0..1（字杆/色带）。旋钮改读累积 knobAngle（第 31 批）。
   */
  @State paperOffsetVp: number = 0;
  @State leverAngleVp: number = 0;
  @State strikePhase: number = 0;
  /** 第 27 批：变体变更计数（换装页改一件 → 重建该件，其余不动）。 */
  @State partsRev: number = 0;
  /** 帧时钟本体（Animator，duration 1,000,000ms 线性、iterations −1）。 */
  private frameClock: AnimatorResult | null = null;
  private frameNowMs: number = 0;
  /** 本击落地时刻（帧毫秒）；−1＝无击打。 */
  private strikeAtMs: number = -1;
  /** 打击时长（§4.3：snap 约 85ms）。 */
  private readonly strikeDurMs: number = 85;
  /** 模式系数 K（§4.2）：写实 1.0／模拟 0.3；200ms 过渡期内插。 */
  private modeK: number = 1.0;
  private modeKFrom: number = 1.0;
  private modeKTo: number = 1.0;
  private modeT0: number = -1;
  /** 帧时钟 300 字会话计数（§10.5）。 */
  private frameCount: number = 0;
  @State paperTopTargetVp: number = 0;
  private paperAnimateNext: boolean = false;
  @State contentTopVp: number = 44;
  @State stackTopGlobalYVp: number = 0;
  /** H 冻结值（首次稳定测到的可用高）。 */
  private frozenHVp: number = 0;
  @State strikeLineVp: number = 0;
  @State carriageTopVp: number = 0;
  /** 换行计数：驱动 LeverLayer 摆动。第 0b 批：四份独立计数，不再跨机共享。 */
  @State newlineTick1920: number = 0;
  @State newlineTick1930: number = 0;
  @State newlineTick1950: number = 0;
  @State newlineTick1960: number = 0;
  /** §18.6 第 2 件：退行代际，防上一次 setTimeout 提前清旗 */
  @State backLineTick: number = 0;
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
  /** 第 12 批 ②：真实页码（按换纸计数；无翻页时 sheetCount===sheetNo）。 */
  @State sheetNo: number = 1;
  @State sheetCount: number = 1;
  @State paperKind: PaperKind = DEFAULT_PAPER;
  /** 第 2 批 F3：当前纸的自定义值缓存（paperKind 变/自定义页保存时刷新）。 */
  @State customMarginH: number = 0;
  @State customMarginT: number = 0;
  @State customMarginB: number = 0;
  @State customPaperColor: string = '';
  @State customPaperTexture: string = '';
  /** 批 62（任务 3）：纸自定义横线开关。 */
  @State customPaperRuled: boolean = false;
  /** 第 2 批 F3：字体偏好变更计数（触发换装页四机字体行刷新）。 */
  @State fontPrefsRev: number = 0;
  @State ribbon: RibbonKind = DEFAULT_RIBBON;
  @State hintText: string = '';
  @State docTitle: string = '';
  /** 26 号稿：黄铜铭牌点按显示文档名（1.6s 后自动收起）。 */
  @State plateHint: boolean = false;
  /** 批 36：成就解锁铭牌亮起（600ms）。 */
  @State plateGlow: boolean = false;
  /** 批 36：出纸槽滑出副本动画进度 0..1（300ms）。 */
  @State slotFly: number = 0;
  @State slotFlyVisible: boolean = false;
  /** 上次导出格式（出纸槽直出用；导出页保存时同步）。 */
  @State lastExportFormat: string = 'text';
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
  /** 批 45：装纸高度（0＝缩在滚筒里，306＝到位）。 */
  @State paperGrowVp: number = 306;
  /** 批 43：标题/光标不透明度（纸到位后才淡入）。 */
  @State paperContentOpacity: number = 1;
  /**
   * 批 68（任务 2）：用户拖动纸的位移（vp）。0＝落字位；＞0＝纸被向下拉、露出上半截。
   * 钳制上界＝max(0, 纸高 − 视口高)，由 layout 与纸内容高推导，不写死。
   */
  @State paperUserOffsetVp: number = 0;
  /** 批 68（任务 4）：换纸动画位移（vp）。负＝旧纸向上飞出；正＝新纸藏在视口下方。 */
  @State paperFlyVp: number = 0;
  /** 手势起点偏移（拖动开始时记一次，update 用「起点＋累计位移」）。 */
  private panStartOffsetVp: number = 0;
  @State functionRowHeight: number = FUNCTION_ROW_HEIGHT_VP;
  @State regionHeightVp: number = 461;
  /** 窗口可用尺寸（vp，onAreaChange 实测，减 inset 后）。 */
  private winWidthVp: number = 0;
  private winHeightVp: number = 0;
  @State availableWidthVp: number = 390;
  @State availableHeightVp: number = 720;
  /** 平板级（可用宽 ≥600vp）。 */
  @State isTablet: boolean = false;
  /** 第 8 批 R2：首帧布局是否已定稿。拨杆按“布局分级”取常量（平板 30°/手机 15°、杆长按 stageW），
   *  若在定稿前挂载就会拿到手机档（实测 DIAG init rest=15.0 size=21.6），能否同步回来取决于时序 →
   *  跨会话抖动。故等 measureStage 定稿后再挂载拨杆。 */
  @State stageReady: boolean = false;
  /** 第 5 批回批 F7：折叠布局模式（单一派生值，D0b-1）。初值 phone，首帧 aboutToAppear 派生。 */
  @State layoutMode: string = 'phone';
  /** 折痕带 vp（窗口坐标）：desk 模式下 region/Spacer 的分界（D0b-2/D1）。 */
  private creaseTopVp: number = 0;
  private creaseBottomVp: number = 0;
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
  @State fontSizeVp: number = 20;   // 批 61：与 FONT_SIZE_FALLBACK 一致
  @State fontPlateLabel: string = 'Courier Prime';
  @State fontFamily: string = 'Courier Prime';

  @State guideXVp: number = 28;
  /** 字车条累计左移量（vp）：负值左移，行首为 0。不是"换行时 12→0 的 bump"。 */
  @State carriageOffsetVp: number = 0;
  @State canvasDeleteTick: number = 0;
  @State canvasDeleteTargetVp: number = 0;
  @State canvasBackTick: number = 0;
  @State canvasBackTargetVp: number = 0;
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
  /** 字杆层是否可见（当前 Index 里该层被 `if (false && …)` 隐藏，拼装期；加回时置 true） */
  private leverEnabled: boolean = true;
  /** 非 1920s 机的落字起搏器（§14.3 第 2 条） */
  private pacerTimer: number = -1;
  private canvasLandTimer: number = -1;
  /** 队首字兜底看门狗（§14.3 第 3 条） */
  private fallbackTimer: number = -1;
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
  /** 候选栏当前页候选（最多 N 个，N=candPageSize）与页码。 */
  @State candCurrent: string[] = [];
  @State canvasStrikeTick: number = 0;
  /** 第 2 批 F15：候选数量（5–15，默认 9）与字号（12–20，默认 15）。 */
  @State candPageSize: number = CANDIDATE_COUNT_DEFAULT;
  @State candChipFontSize: number = CANDIDATE_SIZE_DEFAULT;
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
      // §17.5：字母序键表由管线预排（177,615 键），运行时绝不 sort
      let keysArr: string[] = [];
      try {
        const keysBytes: Uint8Array = await rm.getRawFileContent('dict/pinyin-keys.json');
        const keysText: string = this.decodeUtf8(keysBytes);
        keysArr = JSON.parse(keysText) as string[];
        hilog.info(DOMAIN, TAG, 'keys loaded n=%{public}s', keysArr.length.toString());
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'keys fallback: pinyin-keys.json 读不到，前缀候选将不可用');
      }
      const chars: Record<string, string[]> = JSON.parse(charsText) as Record<string, string[]>;
      const words: Record<string, string[]> = JSON.parse(wordsText) as Record<string, string[]>;
      const tLoad: number = Date.now();
      // §17.3：建索引已降到 ~550ms（贪心切分替代 DP）；分段 await 反而因 590 次
      // setTimeout 让出事件循环累计到 26s，实测更糟，故用同步建索引 + 延迟预加载
      // §17.3：懒加载——启动只解码＋解析（约 500ms），建索引交给后台分片
      this.pinyinEngine = PinyinEngine.fromDataLazy({ chars: chars, words: words });
      if (keysArr.length > 0) {
        this.pinyinEngine.setSortedKeys(keysArr);
      } else {
        hilog.warn(DOMAIN, TAG, 'keys fallback: sortedKeys 为空，prefixWords 直接返回空');
      }
      this.pinyinSession = new PinyinSession(this.pinyinEngine);
      this.pinyinReady = true;
      hilog.info(DOMAIN, TAG, 'index ms=%{public}s (lazy)',
        (Date.now() - tLoad).toString());
      // §17.3：不再后台预建缩写索引——17 万键在设备上要 27 秒，必触发系统 ANR。
      // 缩写改「即席有界扫描」（abbrevScan），只在 2–4 字母查询时发生。
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
        const lkeys: string[] = Object.keys(data);
        let detail: string = '';
        if (lkeys.indexOf('nihao') >= 0) {
          const inner: Record<string, number> = data['nihao'];
          const wk: string[] = Object.keys(inner);
          for (let i = 0; i < wk.length; i++) {
            detail = detail + wk[i] + ':' + inner[wk[i]].toString() + ' ';
          }
        }
        hilog.info(DOMAIN, TAG, 'learn loaded keys=%{public}s nihao=%{public}s',
          lkeys.length.toString(), detail);
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
  /**
   * §17.3 第 1 条：优先用平台原生 TextDecoder；拿不到就 64KB 分块解码。
   * 绝不逐字节拼接（v3 词表 5.23MB 会卡死 UI 线程数秒）。
   */
  private decodeUtf8(bytes: Uint8Array): string {
    const t0: number = Date.now();
    try {
      const dec = util.TextDecoder.create('utf-8');
      const s: string = dec.decodeToString(bytes);
      hilog.info(DOMAIN, TAG, 'decode ms=%{public}s via=TextDecoder bytes=%{public}s',
        (Date.now() - t0).toString(), bytes.length.toString());
      return s;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'TextDecoder unavailable, chunked fallback');
    }
    const CH: number = 65536;
    let out2: string = '';
    let off: number = 0;
    while (off < bytes.length) {
      const end: number = Math.min(off + CH, bytes.length);
      let part: string = '';
      for (let i = off; i < end; i++) {
        part += String.fromCharCode(bytes[i]);
      }
      out2 += decodeURIComponent(escape(part));
      off = end;
    }
    hilog.info(DOMAIN, TAG, 'decode ms=%{public}s via=chunked bytes=%{public}s',
      (Date.now() - t0).toString(), bytes.length.toString());
    return out2;
  }

  private decodeUtf8Old(bytes: Uint8Array): string {
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

  /**
   * 中文通道：整词拆单字，**逐字进同一条落字队列**（§14.3 第 1 条）。
   * 不许再另起定时器直落 commitChar——那会绕过字杆与音效、且每字一个 30ms 字车动画互相打断。
   */
  private enqueueChinese(text: string): void {
    for (let i = 0; i < text.length; i++) {
      const ch: string = text.charAt(i);
      if (ch === '\n') {
        this.onNewline();
      } else {
        this.queueChar(ch);
      }
    }
    hilog.info(DOMAIN, TAG, 'cn enqueue len=%{public}s queue=%{public}s',
      text.length.toString(), this.pendingChars.length.toString());
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
    hilog.info(DOMAIN, TAG, 'applyChineseMode on=%{public}s engine=%{public}s', on ? 'true' : 'false', this.cnEngine);
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
  /** 第 9 批 F5：成就弹窗（一次只一条；kind='' 表示没有）。 */
  @State achNoticeKind: string = '';
  @State achNoticeId: string = '';
  @State achNoticeCount: number = 0;
  /** 成就/事件变化计数（传给收藏页，触发重读进度）。 */
  @State achieveRev: number = 0;
  /** 换装页（§4）开合。 */
  @State customizeOpen: boolean = false;
  /** 第 2 批 F3：换装子页。 */
  @State fontManagerOpen: boolean = false;
  @State paperCustomOpen: boolean = false;
  /** 收藏详情页：非空则显示（已解锁机器）。 */
  @State collectionDetailKind: string = '';
  /** §6.1／§6.2 设置页与导出页。 */
  @State settingsOpen: boolean = false;
  @State pinyinSettingsOpen: boolean = false;
  @State exportOpen: boolean = false;
  /** 第 3 批：导出页 busy（系统返回拦截）。 */
  @State exportBusy: boolean = false;
  /** 第 16 批 2A：Canvas 静态主屏调试页（临时入口，2B 切换后删除）。 */
  private canvasDebugOpen: boolean = false;
  /** 第 26 批（批 3）：Canvas 已退役；保留只读 false 供历史分支走 ArkUI 路径（SWITCH_KEYS 4→3）。 */
  private readonly canvasEnabled: boolean = false;
  /** 第 23 批（19 号稿 §4-3）：当前机型的动画模式；1960s 恒 realistic（电动单套）。 */
  @State animMode: string = 'realistic';
  /** 机型页四行的模式回显（顺序＝ANIM_ROWS：1920s／1930s／1950s；1960s 固定 realistic）。 */
  @State animModes: string[] = ['realistic', 'realistic', 'realistic'];
  @State a11yOverlayEnabled: boolean = false;
  /** §11：冷启动首帧就是主页。 */
  @State homeOpen: boolean = true;
  /** 第 6 批 F6/F10：设置接线与回收站。 */
  @State deleteMode: string = 'trash';
  @State volume0to100: number = 70;
  @State soundEnabled: boolean = true;
  @State vibrationEnabled: boolean = true;
  @State @Watch('onTrashChanged') trashOpen: boolean = false;
  @State trashDocs: DocSummary[] = [];
  /** 第 4 批 F11：统计刷新计数（设置目标/返回主页/导出后递增）。 */
  @State statsRev: number = 0;

  /** 第 1 批：引导（Index 单挂载点；页面只提供 guideSteps 数据）。 */
  @State guideVisible: boolean = false;
  @State guidePage: string = '';
  @State guideTitle: ResourceStr = '';
  @State guideSteps: SpotlightStep[] = [];
  @State onboardingVisible: boolean = false;
  /** 第 13 批 ④：新引导当前页（@Link 给 OnboardingGuide，供返回键做「上一页／首屏跳过」）。 */
  @State onboardingPage: number = 0;
  /** 第 13 批 ⑥：导出目标（入口显式置 scope，不留空；缺省全部空串＝走 live 文档整篇）。 */
  @State exportDocId: string = '';
  @State exportDossierId: string = '';
  @State exportScope: string = '';
  /** 第 10 批：引导总开关（冷启动读 GuideService.enabled；false 时三处 "?" 隐藏）。 */
  @State guideEnabled: boolean = true;
  /** 第 10 批：上次栈深（普通 private 字段，不触发重渲染）；只在变深时弹引导。 */
  private lastStackDepth: number = 1;
  /** 第 10 批：冷启动主页引导只补跑一次。 */
  private coldStartGuideChecked: boolean = false;

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
    this.fontManagerOpen = has('fontmanager');
    this.paperCustomOpen = has('papercustom');
    this.trashOpen = has('trash');
    this.settingsOpen = has('settings') || has('pinyinsettings');
    this.pinyinSettingsOpen = has('pinyinsettings');
    this.exportOpen = has('export');
    this.canvasDebugOpen = has('canvasDebug');
    hilog.info(DOMAIN, TAG, 'nav depth=%{public}s top=%{public}s',
      this.navStack.length.toString(), this.navStack[this.navStack.length - 1]);
    // §4.1：只在栈深变大（前进）时弹；返回/不变不弹
    const depth: number = this.navStack.length;
    const grew: boolean = depth > this.lastStackDepth;
    this.lastStackDepth = depth;
    if (grew) {
      this.maybeShowPageGuide();
    }
    // 第 2 批 F3：从纸张自定义页返回时刷新自定义值缓存（系统返回也覆盖）
    this.refreshPaperCustom();
  }

  // ---- 第 1 批：引导（Index 单挂载点）----

  /** 页面 id → guideSteps 数据（页面各自声明，Index 只做映射）。 */
  private guideStepsOf(page: string): SpotlightStep[] {
    if (page === GUIDE_PAGE_HOME) { return guideStepsForHome(); }
    if (page === GUIDE_PAGE_DOSSIER) { return guideStepsForDossier(); }
    if (page === GUIDE_PAGE_DOSSIER_DETAIL) { return guideStepsForDossierDetail(); }
    if (page === GUIDE_PAGE_DOCUMENT_VIEW) { return guideStepsForDocumentView(); }
    if (page === GUIDE_PAGE_COLLECTION) { return guideStepsForCollection(); }
    if (page === GUIDE_PAGE_COLLECTION_DETAIL) { return guideStepsForCollectionDetail(); }
    if (page === GUIDE_PAGE_CUSTOMIZE) { return guideStepsForCustomize(); }
    if (page === GUIDE_PAGE_FONT_MANAGER) { return guideStepsForFontManager(); }
    if (page === GUIDE_PAGE_PAPER_CUSTOM) { return guideStepsForPaperCustom(); }
    if (page === GUIDE_PAGE_TRASH) { return guideStepsForTrash(); }
    if (page === GUIDE_PAGE_SETTINGS) { return guideStepsForSettings(); }
    if (page === GUIDE_PAGE_EXPORT) { return guideStepsForExport(); }
    if (page === GUIDE_PAGE_PINYIN_SETTINGS) { return guideStepsForPinyinSettings(); }
    if (page === GUIDE_PAGE_TYPEWRITER) {
      return [
        { text: $r('app.string.guide_typewriter_1'), anchorId: 'typewriter__lever' },
        { text: $r('app.string.guide_typewriter_2'), anchorId: 'typewriter__function_row' },
        { text: $r('app.string.guide_typewriter_3'), anchorId: 'typewriter__paper' },
      ];
    }
    return [];
  }

  private guideTitleOf(page: string): ResourceStr {
    if (page === GUIDE_PAGE_HOME) { return $r('app.string.guide_home_title'); }
    if (page === GUIDE_PAGE_DOSSIER) { return $r('app.string.guide_dossier_title'); }
    if (page === GUIDE_PAGE_DOSSIER_DETAIL) { return $r('app.string.guide_dossier_detail_title'); }
    if (page === GUIDE_PAGE_DOCUMENT_VIEW) { return $r('app.string.guide_document_view_title'); }
    if (page === GUIDE_PAGE_COLLECTION) { return $r('app.string.guide_collection_title'); }
    if (page === GUIDE_PAGE_COLLECTION_DETAIL) { return $r('app.string.guide_collection_detail_title'); }
    if (page === GUIDE_PAGE_CUSTOMIZE) { return $r('app.string.guide_customize_title'); }
    if (page === GUIDE_PAGE_FONT_MANAGER) { return $r('app.string.guide_font_manager_title'); }
    if (page === GUIDE_PAGE_PAPER_CUSTOM) { return $r('app.string.guide_paper_custom_title'); }
    if (page === GUIDE_PAGE_TRASH) { return $r('app.string.guide_trash_title'); }
    if (page === GUIDE_PAGE_SETTINGS) { return $r('app.string.guide_settings_title'); }
    if (page === GUIDE_PAGE_EXPORT) { return $r('app.string.guide_export_title'); }
    if (page === GUIDE_PAGE_PINYIN_SETTINGS) { return $r('app.string.guide_pinyin_settings_title'); }
    if (page === GUIDE_PAGE_TYPEWRITER) { return $r('app.string.guide_typewriter_title'); }
    return '';
  }

  /** 当前页只认导航栈栈顶（第 10 批：不再读布尔标志优先级链）。 */
  private currentGuidePage(): string {
    const top: string = this.navStack.length > 0 ? this.navStack[this.navStack.length - 1] : 'home';
    if (top === 'home') { return GUIDE_PAGE_HOME; }
    if (top === 'typewriter') { return GUIDE_PAGE_TYPEWRITER; }
    if (top === 'dossier') { return GUIDE_PAGE_DOSSIER; }
    if (top === 'detail') { return GUIDE_PAGE_DOSSIER_DETAIL; }
    if (top === 'docview') { return GUIDE_PAGE_DOCUMENT_VIEW; }
    if (top === 'collection') { return GUIDE_PAGE_COLLECTION; }
    if (top === 'collectiondetail') { return GUIDE_PAGE_COLLECTION_DETAIL; }
    if (top === 'customize') { return GUIDE_PAGE_CUSTOMIZE; }
    if (top === 'settings') { return GUIDE_PAGE_SETTINGS; }
    if (top === 'pinyinsettings') { return GUIDE_PAGE_PINYIN_SETTINGS; }
    if (top === 'export') { return GUIDE_PAGE_EXPORT; }
    if (top === 'fontmanager') { return GUIDE_PAGE_FONT_MANAGER; }
    if (top === 'papercustom') { return GUIDE_PAGE_PAPER_CUSTOM; }
    if (top === 'trash') { return GUIDE_PAGE_TRASH; }
    return GUIDE_PAGE_HOME;
  }

  private maybeShowPageGuide(): void {
    if (this.onboardingVisible || this.guideVisible) {
      return;
    }
    // §4.3：成就弹窗开着时不弹（等关掉也不补弹）
    if (this.achNoticeKind.length > 0) {
      return;
    }
    const page: string = this.currentGuidePage();
    if (page.length === 0 || !GuideService.shouldShow(page)) {
      return;
    }
    this.openGuide(page);
  }

  /** 手动 "?" 或自动弹的共用入口；manual 时不看 seen，只看总开关与重入守卫。 */
  private showPageGuide(page: string, manual: boolean = false): void {
    if (!this.guideEnabled) {
      return;
    }
    if (this.guideVisible || this.onboardingVisible) {
      return;
    }
    if (!manual && !GuideService.shouldShow(page)) {
      return;
    }
    this.openGuide(page);
  }

  private openGuide(page: string): void {
    this.guidePage = page;
    this.guideTitle = this.guideTitleOf(page);
    this.guideSteps = this.guideStepsOf(page);
    this.guideVisible = true;
  }

  private closePageGuide(): void {
    if (this.guidePage.length > 0) {
      GuideService.markSeen(this.guidePage);
    }
    this.guideVisible = false;
  }

  private closeOnboarding(): void {
    GuideService.markOnboardingSeen();
    // 第 13 批 ④：新引导已介绍主页 → 关闭时直接落主页 seen，不再 120ms 补弹主页聚光灯
    GuideService.markSeen(GUIDE_PAGE_HOME);
    this.onboardingVisible = false;
    this.onboardingPage = 0;
  }

  private replayPageGuide(): void {
    GuideService.resetPages();
    this.hintText = '已重置，下次进入页面生效';
  }

  /** 批 38（平板竖屏首验）：关键件屏幕矩形打点（px），用来给「纸被推到左边／过窄」定坐标证据。 */
  private logRects(): void {
    try {
      const cu = this.getUIContext().getComponentUtils();
      const ids: string[] = ['p26_lid', 'p26_top_deck', 'p35_carriage', 'p35_paper', 'p26_basket', 'p33_key_well', 'p25_key_grid'];
      for (let i = 0; i < ids.length; i++) {
        const r = cu.getRectangleById(ids[i]);
        hilog.info(DOMAIN, TAG, 'rect %{public}s x=%{public}s y=%{public}s w=%{public}s h=%{public}s',
          ids[i], r.screenOffset.x.toFixed(1), r.screenOffset.y.toFixed(1),
          r.size.width.toFixed(1), r.size.height.toFixed(1));
      }
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'logRects failed: %{public}s', JSON.stringify(err));
    }
  }

  private replayOnboarding(): void {
    GuideService.resetOnboarding();
    this.onboardingPage = 0;
    this.onboardingVisible = true;
  }

  /** 批 43：装纸——纸从屏幕上方 600ms 滑入（ease-out），到位后 150ms 标题/光标淡入。 */
  private playPaperLoad(): void {
    this.paperGrowVp = 0;
    this.paperContentOpacity = 0;
    const growTarget: number = this.paperVisibleTargetVp();
    this.getUIContext().animateTo({ duration: 600, curve: Curve.FastOutSlowIn }, () => {
      this.paperGrowVp = growTarget;
    });
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
        this.paperContentOpacity = 1;
      });
      hilog.info(DOMAIN, TAG, 'paper load done grow=%{public}s', this.paperGrowVp.toFixed(1));
      this.logRects();
    }, 600);
    hilog.info(DOMAIN, TAG, 'paper load start from -362');
  }

  /** 批 43：出纸——标题/光标先淡出 150ms，纸再 600ms 上滑出屏（ease-in）。 */
  private playPaperUnload(then: () => void): void {
    this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
      this.paperContentOpacity = 0;
    });
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 600, curve: Curve.EaseIn }, () => {
        this.paperGrowVp = 0;
      });
      setTimeout(() => {
        this.paperGrowVp = this.paperVisibleTargetVp();
        this.paperContentOpacity = 1;
        hilog.info(DOMAIN, TAG, 'paper unload done');
        then();
      }, 620);
    }, 150);
  }

  /** 批 43：离开打字页——先出纸再弹栈。 */
  private leaveTyping(): void {
    const top: string = this.navStack.length > 0 ? this.navStack[this.navStack.length - 1] : 'home';
    if (top === 'typewriter') {
      this.playPaperUnload(() => { this.popPage(); });
    } else {
      this.popPage();
    }
  }

  private pushPage(k: string): void {
    statsService.flushPending();
    statsService.flushFoldTyped();
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
    this.applyStatusBarForTop();
    if (k === 'typewriter') { this.playPaperLoad(); }
  }

  /** 回退到栈中的某页（连同其上所有页一起撤掉）。 */
  private popTo(k: string): void {
    statsService.flushPending();
    statsService.flushFoldTyped();
    const idx: number = this.navStack.indexOf(k);
    if (idx < 0) { return; }
    this.leaveChinese();
    this.navAnimated = true;
    const s: string[] = this.navStack.slice(0, idx + 1);
    this.navStack = s;
    this.syncFromStack();
    this.applyStatusBarForTop();
  }

  /** 弹一层；栈底是主页时返回 false（交给系统退出 App）。 */
  private popPage(): boolean {
    if (this.navStack.length <= 1) { return false; }
    statsService.flushPending();
    statsService.flushFoldTyped();
    this.leaveChinese();
    this.navAnimated = true;
    const s: string[] = this.navStack.slice();
    s.pop();
    this.navStack = s;
    this.syncFromStack();
    this.applyStatusBarForTop();
    if (this.homeOpen) {
      // 第 4 批 F11：回主页时重取统计（卷宗删除/设置改目标后不依赖 aboutToAppear）
      this.statsRev = this.statsRev + 1;
    }
    return true;
  }

  /** 系统返回：先关菜单，再弹栈；栈底主页时返回 false。 */
  onBackPress(): boolean {
    hilog.info(DOMAIN, TAG, 'onBackPress depth=%{public}s', this.navStack.length.toString());
    if (this.cnKbShown) {
      this.langZh = false;
      this.cnPreview = '';
      this.applyChineseMode(false);
      return true;
    }
    if (this.onboardingVisible) {
      // 第 13 批 ④：返回＝上一页；第一页返回＝跳过（关闭）
      if (this.onboardingPage > 0) {
        this.onboardingPage = this.onboardingPage - 1;
      } else {
        this.closeOnboarding();
      }
      return true;
    }
    if (this.guideVisible) {
      this.closePageGuide();
      return true;
    }
    if (this.exportOpen && this.exportBusy) {
      hilog.info(DOMAIN, TAG, 'export busy: back ignored');
      return true;
    }
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
  /** 批 61：Shift 抬扇目标（0／−10vp，组件侧弹簧驱动）。 */
  @State shiftLiftVp: number = 0;
  /** 第 13 批：大写锁定（Caps Lock 键切换；与 Shift 的按住态互相独立）。 */
  @State capsLock: boolean = false;
  /** 底部「字符」键：true = 符号键盘。 */
  @State symbolMode: boolean = false;
  /**
   * 批 72（修 Aa 切换闪屏）：键盘整体不透明度。
   * 切换字母/符号时先设 0.25 再动画回 1 —— 新键盘「柔和浮现」，而不是重建导致的一帧硬切。
   */
  @State keyboardFade: number = 1;
  @State correctionMode: CorrectionMode = CorrectionMode.MODERN;
  /** 1920s 分层字车是否可用（层文件缺失时回退旧 strip，不许空白/崩溃）。 */
  @State useLayers: boolean = true;
  /** 动态安全区（vp）：取不到时 topInset 回退 28、bottomInset 回退 0（§2.9）。 */
  @State topInset: number = 28;
  @State bottomInset: number = 0;

  aboutToAppear(): void {
    // 第 26 批（批 3／R-B4）：帧时钟宿主迁入 Index——冷启动即起，全稿单一时间源
    this.ensureFrameClock();
    // 第 9 批 F5：成就服务变化 → 刷新弹窗与收藏页进度
    AchievementService.setListener((): void => { this.refreshAchieveNotice(); });
    // 落字兜底基准：进入页面即视为「刚刚落过」，避免首字被兜底直接闪现
    this.lastArriveMs = Date.now();
    // §17.3 第 3 条：首帧画完再后台预加载词库（延迟 3s，避免和首屏渲染抢 UI 线程）
    setTimeout(() => {
      this.ensurePinyinEngine().then(() => {
        hilog.info(DOMAIN, TAG, 'pinyin preload done ready=%{public}s', this.pinyinReady ? 'true' : 'false');
      }).catch(() => {
        hilog.warn(DOMAIN, TAG, 'pinyin preload failed');
      });
    }, 380);
    // 读取持久化的中文引擎（默认内置拼音）
    this.readCnEngine();
    // 第 1 批：首启启动引导（ONBOARDING_SEEN 控制；延迟到首帧后）
    this.guideEnabled = GuideService.enabled();
    GuideBridge.set(this.guideEnabled, (page: string): void => { this.showPageGuide(page, true); });
    this.lastStackDepth = this.navStack.length;
    if (!GuideService.onboardingSeen()) {
      setTimeout(() => {
        // 第 13 批 ④：成就弹窗优先——开着即跳过本次冷启动，不重试（与聚光灯同口径）
        if (this.achNoticeKind.length > 0) {
          hilog.info(DOMAIN, TAG, 'onboarding skipped: achievement notice open');
          return;
        }
        this.onboardingPage = 0;
        this.onboardingVisible = true;
      }, 600);
    } else {
      // 第 10 批 §4.1 冷启动例外：回访用户主页是栈底、永不被 push → 首次布局稳定后补跑一次主页引导
      setTimeout(() => {
        if (!this.coldStartGuideChecked) {
          this.coldStartGuideChecked = true;
          if (this.guideEnabled && !this.guideVisible && !this.onboardingVisible &&
            GuideService.shouldShow(GUIDE_PAGE_HOME)) {
            this.maybeShowPageGuide();
          }
        }
      }, 450);
    }
    // 第 2 批 F15：候选栏选项（缺省 9／15）
    this.candPageSize = clampCandidateCount(
      appPreferences.getNumber(PrefKeys.CUSTOM_CANDIDATE_COUNT, CANDIDATE_COUNT_DEFAULT));
    this.candChipFontSize = clampCandidateSize(
      appPreferences.getNumber(PrefKeys.CUSTOM_CANDIDATE_SIZE, CANDIDATE_SIZE_DEFAULT));
    // §7.4：系统键盘弹起时页面整体上移（OFFSET），保打击行可见
    try {
      // 用 UIContext 导出的 KeyboardAvoidMode（OFFSET=0 页面上移 / RESIZE=1），避开组件作用域同名枚举
      this.getUIContext().setKeyboardAvoidMode(UcKeyboardAvoidMode.OFFSET);
      // 监听键盘高度：按「打击行 vs 键盘顶」差值上移舞台，保打击行可见
      window.getLastWindow(this.getUIContext().getHostContext() as common.Context)
        .then((win: window.Window) => {
          win.on('keyboardHeightChange', (h: number) => {
            // 第 5 批回批 F7（D4 kbShift 行）：缓存 h，折叠回调与监听共用同一缓存
            this.kbHeightCachedPx = h;
            this.recalcKbShift();
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
    // 第 0 批：注册循环搬进 FontService（同一函数），Index 只调一次。
    const fontResult: FontRegisterResult = FontService.registerBundled(this.getUIContext(), FONTS);
    // 批 53：把系统字体清单打进 hilog（看有没有内置等宽字体）
    try {
      const sysFonts: string[] = this.getUIContext().getFont().getSystemFontList();
      hilog.info(DOMAIN, TAG, 'system fonts count=%{public}s list=%{public}s',
        sysFonts.length.toString(), sysFonts.join('|'));
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'getSystemFontList failed');
    }

    this.fontLoadFailed = fontResult.failed;
    // 第 2 批 F3（评审 B-2）：导入字体冷启动重注册（失败标 failed，不污染随包字体）
    this.registerImportedFonts();

    const host = this.getUIContext().getHostContext();
    if (host !== undefined && host !== null) {
      this.audioService.attachContext(host as common.Context);
    }
    // 第 5 批回批 F7（D0b-4）：注入 px2vp 换算系数（px2vp(100)/100 = 每像素 vp 数的倒数即 px/vp）
    // + 注册折叠回调一次（Index 不留 foldState 镜像，单一事实源 FoldService）
    const pxPerVp: number = this.getUIContext().px2vp(1);
    FoldService.setPxPerVp(pxPerVp > 0 ? pxPerVp : 0);
    FoldService.onFoldChange((st: FoldState): void => {
      this.onFoldStateChanged(st);
    });
    this.docTitle = this.resolveString($r('app.string.doc_untitled'));
    // 第 6 批 F6：启动灌 prefs 音量/开关（AudioService 私有默认 0.8/全开）
    this.volume0to100 = prefToVolume(appPreferences.getNumber(PrefKeys.VOLUME, 0.7));
    this.soundEnabled = appPreferences.getBool(PrefKeys.SOUND_ENABLED, true);
    this.vibrationEnabled = appPreferences.getBool(PrefKeys.VIBRATION_ENABLED, true);
    this.audioService.setVolume(volumeToPref(this.volume0to100));
    this.audioService.setSoundEnabled(this.soundEnabled);
    this.audioService.setVibrationEnabled(this.vibrationEnabled);
    this.deleteMode = deleteModeOf(appPreferences.getString(PrefKeys.DELETE_MODE, 'trash'));
    this.measureStage();
    // §10：机型从全局偏好读（读不到回落 DEFAULT_MACHINE），不再每次回 1920s
    const savedMachine: string = appPreferences.getString(PrefKeys.MACHINE, DEFAULT_MACHINE as string);
    this.applyMachine(savedMachine as MachineKind);
    this.applyPaper(paperPrefOf(appPreferences.getString(PrefKeys.PAPER, DEFAULT_PAPER as string),
      DEFAULT_PAPER as string) as PaperKind);
    this.applyRibbon(DEFAULT_RIBBON);
    this.reloadKeymap();
    // 第 26 批（批 3）：detectLayers 随 Canvas 机器层退役删除（R-B2）
    this.applyImmersive();
    this.hintText = this.resolveString($r('app.string.hint_new_paper'));
    this.restoreLastDocument();
    this.syncRows();
    // 启动即有 O：按当前行光标重算，不许归 0
    this.recalcTravel();
    this.recalcOffsetFromCursor();
  }

  aboutToDisappear(): void {
    AchievementService.setListener(null);
    statsService.flushPending();
    statsService.flushFoldTyped();
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

  // ---------------- 第 24 批：新 UI 件（批 1 试点）几何（23 号稿 §3.2.1／附录 A） ----------------

  /** 画布高（vp）：Canvas 的 heightVp 同式（批 3 去掉 Canvas 后改为 stageHeight 直读）。 */
  private canvasHeightVp(): number {
    return this.winHeightVp > 0 ? this.winHeightVp : this.stageHeight;
  }

  /** 画布宽（vp）：Canvas 的 widthVp 同式。 */
  private canvasWidthVp(): number {
    return this.winWidthVp > 0 ? this.winWidthVp : this.stageWidth;
  }

  // ===== 26 号稿 §6：五区 y-map（手机 362.7×822.5 基准，绝对屏幕坐标）=====
  /** 批 36 §7：平板/折叠按同一台机器等比放大（k = min 宽比, 高比），手机 k=1。 */
  private machineK26(): number {
    const kw: number = this.stageWidth > 0 ? this.stageWidth / 362.7 : 1;
    const kh: number = this.canvasHeightVp() > 0 ? this.canvasHeightVp() / 822.5 : 1;
    const k: number = Math.min(kw, kh);
    return k > 0 ? k : 1;
  }
  /** 等比缩放后机身水平居中偏移。 */
  /**
   * 批 64（用户 2026-11-21 定）：覆盖页根宽＝**可用宽**（真正自适应），不再按机器长宽比封顶。
   *
   * 旧口径（批 63 阶段 0 R4）是 `min(可用宽, 可用高 × 362.7/822.5)`：平板算出 475.4vp，
   * 而屏幕可用宽 673.7vp ⇒ 14 个覆盖页全被锁进中间一条窄带，两侧各空 99vp
   * （1600px 只用到 1129px）。用户判定「从主页开始所有页面只在中央一小块，根本没体现自适应」。
   * 新口径：页面铺满可用宽；需要「内容不要太宽」的地方由各自内容区自己加内边距/最大宽，不在根宽上封顶。
   */
  private overlayWidthVp(): number {
    const w: number = this.winWidthVp > 0 ? this.winWidthVp : this.stageWidth;
    return w > 0 ? w : 360;
  }

  /** 批 64（N2）：机器宽＝舞台宽（批 64 用户 2026-11-21：打字页横向铺满，不再按机器长宽比收窄）。 */
  private machineWidth26(): number {
    return this.stageWidth > 0 ? this.stageWidth : 362.7 * this.machineK26();
  }

  /** 批 64（T3）：舞台换算表（与 Stage26 同式同参），供纸区等槽位取区高。 */
  private stageLayout26(): StageLayout {
    return new StageLayout(this.stageWidth, this.winHeightVp > 0 ? this.winHeightVp : this.canvasHeightVp());
  }

  private machineOffsetX26(): number {
    const w: number = 362.7 * this.machineK26();
    return (this.stageWidth - w) / 2;
  }
  /**
   * 横向缩放＝机器宽 / 362.7（批 64 用户 2026-11-21）。
   *
   * 旧口径 `xk() === yk() === machineK26() === min(宽比, 高比)`：竖屏平板上被**高度**卡死在 1.3106，
   * 于是所有横向基准（纸宽、字体条、键井、纸面板内距）都停在手机比例的 1.31 倍，
   * 机器宽 475.3vp 而屏宽 673.7vp ⇒ 打字页左右各空 99vp。用户判定「依然没有正确自适应」。
   * 新口径：横向独立按机器宽铺满（1.857），纵向仍按高度比（1.3106）——即允许非等比，换来铺满。
   * 33 处 `this.xk()` 调用点因此自动跟随，不需要逐个改。
   */
  private xk(): number { return this.machineWidth26() / 362.7; }
  private yk(): number { return this.machineK26(); }
  private t26x(base: number): number { return base * this.xk(); }
  private t26y(base: number): number { return base * this.yk(); }

  /** 批 64（T3）：纸宽＝机器宽×0.606（设计稿 §3.3；手机 219.8vp／平板 288.1vp）。 */
  private paperPanelWidthVp(): number {
    return this.machineWidth26() * 0.606;
  }
  /** 批 64（T3）：行宽＝纸宽 − 左右边距。旧口径 235·k（平板 307.9）比纸还宽，纸面会溢出，作废。 */
  private lineWidth26(): number {
    // 批 64（用户 2026-11-21）：与 stagePaper 的 marginLVp/marginRVp 同口径——边距不随屏幕放大
    const ml: number = this.customMarginH > 0 ? this.customMarginH : 25;
    const mr: number = this.customMarginH > 0 ? this.customMarginH : 30;
    const w: number = this.paperPanelWidthVp() - ml - mr;
    return w > 40 ? w : 40;
  }
  /** §6.1：正文 11.9vp（≈7vp/字 → 行宽 165vp ≈ 23 字）。 */
  private typeFontSize(): number { return 11.9; }   // 批 45：字距 7.14 不动，字号不随纸宽缩放
  /** 批 46：纸可见高随行数生长——起始 90vp（卷＋标题／首行），每行 +25vp，上限 306vp。 */
  /** 批 54：把 17 款注册字体映射到系统实际可用的通用族（registerFont 平台层无效，见批 51–53）。 */
  private genericFamilyFor(family: string): string {
    const mono: string[] = ['CourierPrime', 'AnonymousPro', 'SpaceMono', 'XanhMono', 'SpecialElite'];
    const serif: string[] = ['IMFellEnglish', 'NotoSerifSC', 'LXGWWenKai', 'LongCang', 'ZhuqueFangsong'];
    if (mono.indexOf(family) >= 0) { return 'monospace'; }
    if (serif.indexOf(family) >= 0) { return 'serif'; }
    return 'cursive';
  }

  /**
   * 批 68（任务 1/2）：纸视口高（vp）——与 `Carriage26.paperAreaH()` 同口径：
   * 纸区槽高 − 底部家具 18vp（「横尺 12 ＋ 间隙 2 ＋ 色带 4」是批 64 flex 化的既有家具高，不是新常数）。
   */
  private paperAreaHVp(): number {
    const h: number = this.stageLayout26().paperH - 18;
    return h > 0 ? h : 0;
  }

  /**
   * 批 68（任务 2）：滑动位移钳制 `[0, max(0, 纸高 − 视口高)]`。
   * 自适应：上界由纸内容高与 layout 推导，纸比视口短时上界为 0 ⇒ 不可滑。
   */
  private clampPaperOffsetVp(v: number): number {
    const maxV: number = Math.max(0, this.paperGrowVp - this.paperAreaHVp());
    if (v < 0) { return 0; }
    return v > maxV ? maxV : v;
  }

  /** 批 68（任务 2）：拖动开始——记起点偏移。 */
  private onPaperPanStart(): void {
    this.panStartOffsetVp = this.paperUserOffsetVp;
  }

  /** 批 68（任务 2）：拖动更新——手指位移量即纸位移量（vp），不另设速率。 */
  private onPaperPanUpdate(dy: number): void {
    this.paperUserOffsetVp = this.clampPaperOffsetVp(this.panStartOffsetVp + dy);
    hilog.info(DOMAIN, TAG, 'paperPan dy=%{public}s off=%{public}s max=%{public}s',
      dy.toFixed(1), this.paperUserOffsetVp.toFixed(1),
      Math.max(0, this.paperGrowVp - this.paperAreaHVp()).toFixed(1));
  }

  /** 批 68（任务 3）：下一次落字时把滑动位移动画回 0（250ms）。 */
  private settlePaperOffset(): void {
    if (this.paperUserOffsetVp <= 0) { return; }
    hilog.info(DOMAIN, TAG, 'paperOffset settle from=%{public}s -> 0',
      this.paperUserOffsetVp.toFixed(1));
    this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
      this.paperUserOffsetVp = 0;
    });
  }

  private paperVisibleTargetVp(): number {
    // 批 69：**撤掉纸高封顶**——纸高只由内容决定（31 ＋ 行高 × 行数 ＋ 6），只保留 58 下限
    // （1 行纸不塌掉）。纸高可以远超视口高（20 行约 609vp），纸底仍由批 68 的视口锚定
    // （Carriage26 内层 Column .height(paperAreaH())）钉住，多出来的部分从视口顶出去、被视口 clip 裁住。
    const lines: number = this.docModel.getLines().length > 0 ? this.docModel.getLines().length : 1;
    const v: number = 31 + this.lineHeightVp * lines + 6;   // 批 49：+6 让末行下沿不被纸底/压纸杆切
    return v > 58 ? v : 58;
  }

  /** §6.1：纸 V=0 左缘（156vp）。 */
  private paperPanelBaseXVp(): number { return 36 * this.xk(); }
  /** 批 35 修正口径：字车中心＝滚筒中心＝纸中心；V=0 在 266vp。 */
  private carriageCenterXVp(): number { return 181 * this.xk() + this.carriageOffsetVp; }
  private paperPanelLeftVp(): number { return this.carriageCenterXVp() - 110 * this.xk(); }
  private paperPanelTopVp(): number { return this.t26y(56); }
  private paperZoneTopVp(): number { return this.t26y(104); }
  private hPaperZoneVp(): number { return this.t26y(306.4); }
  private paperZoneBottomVp(): number { return this.t26y(362.4); }
  private rulerTopVp(): number { return this.t26y(356); }
  private basketTopVp(): number { return this.t26y(376); }
  private funcRowTopVp(): number { return this.t26y(514); }
  private fontBarTopVp(): number { return this.t26y(550); }
  private candBarTopVp(): number { return this.t26y(578); }
  private keyGridTopVp(): number { return this.t26y(622.3); }

  /** 批 36 §4.3：标题占一行时的额外顶部偏移。 */
  private paperTitleExtraVp(): number {
    return 0;   // 批 47：纸上不再放标题（只在顶栏显示），不占行
  }

  /** 纸面页码（右上）：当前纸序号。 */
  private paperPageNo(): string {
    const meta = this.docModel.toDocData().meta;
    const no: number = meta.sheetNo !== undefined && meta.sheetNo !== null ? meta.sheetNo : 0;
    return no > 0 ? no.toString() : '1';
  }

  /** 纸卷上移量（光标行超出可见区时整卷上移）。 */
  private paperScroll26(): number {
    // 批 47：滚动只按"当前纸高"算——纸没满高时 scroll=0，满高后每行滚一个行高
    const n: number = this.docModel.getCursor().line;
    const lh: number = this.lineHeightVp;
    const topMargin: number = 31 * this.yk() + this.paperTitleExtraVp();
    const paperH: number = this.paperVisibleTargetVp();
    const over: number = topMargin + n * lh + lh - paperH;
    return over > 0 ? over : 0;
  }
  /** 落字点 y（相对纸顶）。 */
  private paperCursorY26(): number {
    return 31 * this.yk() + this.paperTitleExtraVp() + this.docModel.getCursor().line * this.lineHeightVp - this.paperScroll26();
  }

  /** 旋钮直径：46.5vp live（§6.2，沿用现行值）。 */
  private knobDVp26(): number { return 46.5 * this.xk(); }
  /** 拨杆几何（旧接口保留给引导锚点）。 */
  private leverWidthVp(): number { return 10; }
  private leverMarginVp(): number { return 8; }
  private leverTopVp(): number { return this.paperZoneTopVp() + this.hPaperZoneVp() * 0.2; }
  private leverHeightVp(): number { return this.hPaperZoneVp() * 0.6; }

  /** 机身材质贴片（§2.5 第 5 条：机身面板；批 2 起取代 KeyGrid 过渡底板）。 */
  // 第 33 批（批 29 并入项）：bodyPanelRawfile 已删——旧 grain 图 4 张同日删除，机身底改 tierTile。

  /** 字杆贴片（§7.4 typebar-<machine>.png；§4.3 打击动件）。 */
  private typebarRawfile(): string {
    const k: string = this.machineKind as string;
    const i: number = k.indexOf('-');
    const slug: string = i > 0 ? k.substring(0, i) : k;
    return 'ui-parts/typebar-' + slug + '.png';
  }

  /** 字篮扇形贴片（§7.4 basket-fan-<machine>.png）。 */
  private basketFanRawfile(): string {
    const k: string = this.machineKind as string;
    const i: number = k.indexOf('-');
    const slug: string = i > 0 ? k.substring(0, i) : k;
    // 第 27 批：字篮风格变体（flat-line★／metal-gradient）
    const v: string = CustomizeStore.partVariant('basket', k);
    return v === 'metal-gradient'
      ? 'ui-parts/basket-fan-metal-' + slug + '.png'
      : 'ui-parts/basket-fan-' + slug + '.png';
  }

  /** 第 27 批：旋钮面变体（metal-knurl★／matte-black，通用图）。 */
  private knobRawfile(): string {
    const v: string = CustomizeStore.partVariant('knob', this.machineKind as string);
    return v === 'matte-black' ? 'ui-parts/knob-matteblack.png' : 'ui-parts/knob-metal.png';
  }

  /** 第 27 批：键盘帽形变体（rounded-rect★／round）。 */
  private capShape(): string {
    return CustomizeStore.partVariant('key-grid', this.machineKind as string);
  }

  /** 落字点标记的 y（相对纸面板顶；批 2 先按最后一行行中，批 3 帧时钟接管）。 */
  private paperCursorYVp(): number {
    const n: number = this.rows.length > 0 ? this.rows.length - 1 : 0;
    return this.marginT() + 20 + n * this.lineHeightVp + this.lineHeightVp / 2;
  }

  /** 色带条 y（相对页顶；批 2 藏在纸面之下＝落字点下方一行）。 */
  private ribbonTopVp(): number {
    return this.paperZoneTopVp() + this.paperCursorYVp() + this.lineHeightVp;
  }

  /** 纸纹贴片名（§7.4：纸只有 texture 维，无 machine 维）。 */
  private paperPanelTexture(): string {
    // 批 62 收尾（任务 2）：四种纸各用一张带卷曲的纹理（卷与 paper-cream-v5 同形同位），并补上 ui-parts/ 前缀
    // （批 62 原写法返回裸文件名，$rawfile 会去 rawfile 根目录找、找不到 → 纸面其实是空的）
    if (this.paperKind === PaperKind.MANUSCRIPT) { return 'ui-parts/paper-manuscript-curl.png'; }
    if (this.paperKind === PaperKind.POSTCARD) { return 'ui-parts/paper-postcard-curl.png'; }
    if (this.paperKind === PaperKind.MEMO) { return 'ui-parts/paper-memo-curl.png'; }
    return 'ui-parts/paper-letter-curl.png';
  }

  /** 第 25 批（批 2）：浅机身（1950s 奶油／1960s 浅灰）→ App 铬与系统栏用深色文字。 */
  private isLightMachine(): boolean {
    return this.machineKind === MachineKind.STREAMLINED_1950S
      || this.machineKind === MachineKind.ELECTRIC_1960S;
  }

  /** App 铬前景色（顶栏图标／标题／字体条）：深机身米白，浅机身深色。 */
  private chromeFgColor(): string { return this.isLightMachine() ? '#2b2620' : '#dbccb3'; }

  /** 第 25 批（批 2）：系统栏图标色随机身明暗切换（浅机身用深色，否则米白）。 */
  private applySystemBarContentColor(): void {
    const ctx = this.getUIContext().getHostContext();
    if (ctx === undefined || ctx === null) { return; }
    const color: string = this.chromeFgColor();
    window.getLastWindow(ctx as common.UIAbilityContext).then((win: window.Window) => {
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: color,
        navigationBarContentColor: color,
      }).then(() => {
        hilog.info(DOMAIN, TAG, 'system bar content color=%{public}s', color);
      }).catch(() => {});
    }).catch(() => {});
  }

  /** 字体条上下细线：浅机身加深，保证可读。 */
  private chromeLineColor(): string { return this.isLightMachine() ? '#8a7f70' : '#3a332b'; }

  /** 键区过渡态底板色（23 号稿 §2.5 第 5 条机身色；批 2 机身面板挂载后由面板接管）。 */
  /** 第 28 批（24 号稿 §2.1）：三档色（paperwell／base／keybed）。 */
  private tierColor(tier: 'paperwell' | 'base' | 'keybed' | 'steel'): string {
    return tierToken(this.machineKind, tier);
  }

  /** 第 28 批：三档颗粒贴片（ui-parts/tile-<slug>-<tier>.png）。 */
  private tierTile(tier: 'paperwell' | 'base' | 'keybed'): string {
    return tierTileRawfile(this.machineKind, tier);
  }

  /** 第 32 批（25 号稿 §2.3）：凹槽框内侧阴影 ΔL（1920s/1930s −0.008、1960s −0.015、1950s −0.030）。 */
  private grooveInnerDL(): number {
    if (this.machineKind === MachineKind.STREAMLINED_1950S) { return -0.030; }
    if (this.machineKind === MachineKind.ELECTRIC_1960S) { return -0.015; }
    return -0.008;
  }

  /** 第 31 批（a443787 L2643 照抄）：四机都有分层件，恒 true。 */
  private hasLayers(): boolean {
    return this.machineKind === MachineKind.UPRIGHT_1920S
      || this.machineKind === MachineKind.PORTABLE_1930S
      || this.machineKind === MachineKind.STREAMLINED_1950S
      || this.machineKind === MachineKind.ELECTRIC_1960S;
  }

  private machineBodyColor(): string {
    // 第 27 批：取机身配色变体（缺省＝本机 colorway）
    const v: string = CustomizeStore.partVariant('body-panel', this.machineKind as string);
    return bodyColorOfVariant(v);
  }

  /** 设备类型（phone / tablet / 2in1 / ...）。 */
  private deviceTypeName(): string {
    try {
      return deviceInfo.deviceType;
    } catch (e) {
      return 'unknown';
    }
  }

  /**
   * 第 5 批回批 F7（D0b-3/4）：折叠回调。依次 deriveLayoutMode() → measureStage()（内含 derive
   * 幂等重算 + recalcPaperHeight）；折叠切换走瞬时赋值（paperAnimateNext=false，不新起编排动画）；
   * kbShift 按 D4 状态表重算。HALF_FOLD 时窗口不变 onAreaChange 不 fire，必须显式触发；
   * FOLDED/EXPAND 的重算由 onAreaChange 驱动，回调不为这两态强制立即重算（避免旧窗+新态杂交帧）。
   */
  private onFoldStateChanged(st: FoldState): void {
    hilog.info(DOMAIN, TAG, 'onFoldChange state=%{public}s mode(before)=%{public}s',
      st, this.layoutMode);
    this.layoutMode = this.deriveLayoutMode();
    if (this.layoutMode === 'desk') {
      // 折叠切换走瞬时赋值：先置 false 再重算，换行中途折叠时不新起编排动画
      this.paperAnimateNext = false;
      this.measureStage();
      this.recalcKbShift();
    }
  }

  /** 第 5 批回批 F7（D0b-1）：layoutMode 单一派生。唯一判定式；几何函数只读本 @State。 */
  private deriveLayoutMode(): string {
    const st: FoldState = FoldService.state();
    if (st === 'FOLDED') {
      return 'phone';
    }
    if (st === 'HALF_FOLD' && FoldService.isCreaseHorizontal()) {
      return 'desk';
    }
    if (st === 'HALF_FOLD') {
      // 纵向折痕：状态如实报 HALF_FOLD，布局回退展开态（D2 真值表）
      return this.isTablet ? 'tablet' : 'phone';
    }
    return this.isTablet ? 'tablet' : 'phone';
  }

  /** 折痕带 vp 重读（measureStage 内、derive 之前调；D1 顺序）。 */
  private refreshCreaseVp(winH: number): void {
    FoldService.refreshCrease();
    this.creaseTopVp = FoldService.creaseTopVp(winH);
    this.creaseBottomVp = FoldService.creaseBottomVp(winH);
  }

  /** 键盘避让重算（D4 状态表 kbShift 行）：折叠回调与 keyboardHeightChange 共用上次缓存 h。 */
  private kbHeightCachedPx: number = 0;

  private recalcKbShift(): void {
    const hPx: number = this.kbHeightCachedPx;
    if (hPx <= 0) {
      this.kbShift = 0;
      return;
    }
    // 批 64（T7／R5）：口径改为「把候选栏顶到系统键盘之上」。
    // 旧口径只保打击行（strikeLine+40 < 键盘顶时恒为 0——真机实测 shift=0.0，候选栏被键盘压住）。
    const kbVp: number = this.getUIContext().px2vp(hPx);
    const kbTop: number = this.canvasHeightVp() - kbVp;
    const lay: StageLayout = this.stageLayout26();
    const candBottom: number = lay.topBarH + lay.paperH + lay.basketH + lay.funcRowH + lay.fontBarH + lay.candBarH;
    const need: number = candBottom + 6 - kbTop;
    this.kbShift = need > 0 ? need : 0;
    hilog.info(DOMAIN, TAG, 'kb height=%{public}s top=%{public}s candBottom=%{public}s shift=%{public}s',
      hPx.toString(), kbTop.toFixed(1), candBottom.toFixed(1), this.kbShift.toFixed(1));
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
      // 第 5 批回批 F7（D1/D0b-1 顺序）：newTablet 定稿 → refreshCrease 重读折痕 → derive → 分支
      this.refreshCreaseVp(winH);
      const prevMode: string = this.layoutMode;
      this.layoutMode = this.deriveLayoutMode();
      this.stageWidth = stageW;
      // 舞台高改回窗口高（region 仍按可用高算）
      this.stageHeight = winH;
      this.topBarHeight = TOP_BAR_HEIGHT_VP;
      this.paperTopGap = PAPER_TOP_GAP_VP;
      // 照片高度只由宽高比派生
      // 物理模型：行程上限 = 可用行宽（舞台宽 − 2×28），不再是 min(舞台宽×0.35,180)
      this.maxTravelVp = stageW - 2 * 28;
      this.carriageHeight = (stageW + this.maxTravelVp) / CARRIAGE_STRIP_ASPECT;
      this.fontBarHeight = 28 * (this.canvasHeightVp() > 0 ? this.canvasHeightVp() / 822.5 : 1);
      this.keybedHeight = stageW / KEYBAND_ASPECT;
      // 26 号稿 §6.4：平板键井高按 stageW/2.1005；若超出 26 y-map 的键盘槽位则压到槽内
      if (newTablet) {
        const slotTop: number = 622.3 * (winH > 0 ? winH / 822.5 : 1);
        const maxH: number = winH - slotTop - this.bottomInset - 4;
        if (maxH > 120 && this.keybedHeight > maxH) {
          this.keybedHeight = maxH;
        }
      }
      this.functionRowHeight = FUNCTION_ROW_HEIGHT_VP;
      const carriageConsumed: number = this.carriageHeight - CARRIAGE_PAPER_OVERLAP_VP;
      // §18.8／§19：候选栏区**常驻 44vp**，已含在布局里——手机 region 必须减掉它，
      // 否则总成溢出、底座被候选栏盖住。平板公式不动。
      // 第 5 批回批 F7（D0b-2）：desk 模式按折痕重排——纸区=上半区，candBar 平板口径（0），
      // keybed 用折叠带比值（1920s/1950s/1960s=2.401；1930s 复用手机带 2.101）。
      const isDesk: boolean = this.layoutMode === 'desk';
      const isFoldPhone: boolean = this.layoutMode === 'phone';
      let keybedAspect: number = KEYBAND_ASPECT;
      if (isDesk) {
        keybedAspect = this.machineKind === MachineKind.PORTABLE_1930S ? KEYBAND_ASPECT : KEYBAND_ASPECT_FOLD;
        this.keybedHeight = stageW / keybedAspect;
      }
      const candBarVp: number = (this.isTablet || isDesk) ? 0 : CANDIDATE_BAR_HEIGHT_VP;
      let region: number;
      if (isDesk) {
        // 纸区 = 上半区（D0b-2 原式）：region = creaseTop − topInset − topBar − paperTopGap
        //   − carriageConsumed（fontBar/functionRow/candBar 在下半区/布局尾段，不从上半区扣）
        region = this.creaseTopVp - this.topInset - this.topBarHeight - this.paperTopGap
          - carriageConsumed;
      } else {
        region = availH - this.topBarHeight - this.paperTopGap - carriageConsumed
          - this.fontBarHeight - this.keybedHeight - this.functionRowHeight - candBarVp;
      }
      this.regionHeightVp = region > 120 ? region : 120;
      if (isDesk !== (prevMode === 'desk') || isFoldPhone) {
        hilog.info(DOMAIN, TAG, 'fold layout mode=%{public}s creaseTop=%{public}s creaseBottom=%{public}s region=%{public}s keybed=%{public}s aspect=%{public}s',
          this.layoutMode, this.creaseTopVp.toFixed(1), this.creaseBottomVp.toFixed(1),
          this.regionHeightVp.toFixed(1), this.keybedHeight.toFixed(1), keybedAspect.toFixed(3));
      }

      // ③字号保 DPI：目标物理 57px（= 手机 17vp×3.375）÷ vp2px
      //    平板 vp2px=2.375 → 24vp；手机 3.375 → 16.9 钳到 17（与改前一致）
      const pxPerVp0: number = this.getUIContext().vp2px(1);
      let computedFs: number = 57 / (pxPerVp0 > 0 ? pxPerVp0 : 3.375);
      if (computedFs < 17) {
        computedFs = 17;
      }
      if (computedFs > 26) {
        computedFs = 26;
      }
      // 批 62（任务 1）：字号读回——存过的用存的值（clamp [12,26]）；没存过才用 220vp 口径的现算值
      const storedFs: number = CustomizeStore.fontSize(this.machineKind as string);
      this.fontSizeVp = storedFs > 0 ? storedFs : (11.9 * Math.sqrt(this.paperPanelWidthVp() / 220));
      this.measureAdvance();
      // §18.9：行高与语言无关，唯一公式 fontSize×30/17
      this.lineHeightVp = lineHeightOf(this.fontSizeVp);

      // 原生像素 guard：整套封顶（照片宽 + 键区高 + 字车高都按封顶宽重算，不许只封 Image）
      const vp2px: number = this.getUIContext().vp2px(1);
      this.photoWidthCap = (availW * vp2px > 2048) ? 2048 / vp2px : 0;
      if (this.photoWidthCap > 0 && stageW > this.photoWidthCap) {
        const capped: number = this.photoWidthCap;
        // 第 5 批回批 F7：desk 时 guard 同步用折叠带比值，否则折叠带图被压扁约 14%（D0b-2）
        const guardAspect: number = this.layoutMode === 'desk'
          && this.machineKind !== MachineKind.PORTABLE_1930S ? KEYBAND_ASPECT_FOLD : KEYBAND_ASPECT;
        this.keybedHeight = capped / guardAspect;
        this.carriageHeight = (capped + this.maxTravelVp) / CARRIAGE_STRIP_ASPECT;
      }

      // 字号定后立刻重算每行字数与每字行程
      this.recalcTravel();
      // carriageHeight 必须在 maxTravelVp 定稿之后再算，否则 Hc 与 CarriageLayers 不同源
      // 第 2 版：纸宽 Pw = regionHeight/1.414；纸高从 96 起按行生长，上限 regionHeight
      // ①纸宽：平板 0.72×stageWidth（MLR 485vp / 72%），手机维持 0.82×stageWidth
      // 纸卷收窄留边：平板 0.66×stageWidth（左右各留深底空隙），手机维持 0.82
      this.paperWidthVp = this.paperPanelWidthVp();
      // 26 号稿 §6.1：纸宽 220vp 固定；行宽 165vp 由边距导出（旧 275.4vp 作废）
      this.carriageHeight = this.paperWidthVp * 0.17;
      this.maxTravelVp = this.lineWidth26();
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
        stageW.toFixed(1), this.regionHeightVp.toFixed(1), this.fontSizeVp.toFixed(2),
        this.paperHeightVp.toFixed(1), this.keymapLayout.widthVp.toFixed(1),
        this.keymapLayout.heightVp.toFixed(1), this.photoWidthCap.toFixed(1));
      // 批 64 阶段 1：舞台容器换算表打点（真机对账五区高度，与设计稿 §3.2 表比对）
      const stageL: StageLayout = new StageLayout(stageW, this.winHeightVp > 0 ? this.winHeightVp : winH);
      hilog.info(DOMAIN, TAG, 'stage26 %{public}s', stageL.describe());
      // 批 38（平板竖屏首验）：几何打点——k／居中偏移／画布／纸面板宽，与 Carriage26 的 geom 行对账
      hilog.info(DOMAIN, TAG, 'geom26 k=%{public}s offsetX=%{public}s canvas=%{public}sx%{public}s Pw=%{public}s paper290k=%{public}s win=%{public}sx%{public}s',
        this.xk().toFixed(3), this.machineOffsetX26().toFixed(1),
        this.canvasWidthVp().toFixed(1), this.canvasHeightVp().toFixed(1),
        this.paperPanelWidthVp().toFixed(1), (290 * this.xk()).toFixed(1),
        this.winWidthVp.toFixed(1), this.winHeightVp.toFixed(1));
      // R2：布局定稿后放开拨杆挂载（同一帧完成，不引入额外可见帧）
      if (!this.stageReady) {
        this.stageReady = true;
        hilog.info(DOMAIN, TAG, 'stageReady set (isTablet=%{public}s)', this.isTablet ? 'true' : 'false');
      }
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'measureStage failed: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 字车条行程（§2.1 字车条动效）：最大行程 = min(64vp, 舞台宽 × 0.16)；
   * 每字行程 = 最大行程 / 每行字数；每行字数按舞台宽算，不用屏幕宽。
   */
  /** 当前语言的一个字符 advance（EN 0.6em／中文 1.0em，D5 口径）。 */
  private currentAdvance(): number {
    const adv: number = this.langZh
      ? (this.advCjkVp > 0 ? this.advCjkVp : this.fontSizeVp)
      : (this.advEngVp > 0 ? this.advEngVp : this.fontSizeVp);
    return adv > 0 ? adv : 10.2;
  }

  /**
   * 第 26 批（批 3／§4.1 D5–D6）：O 范围改成 [−lineWidth, 0]，lineWidth＝charsPerLine×advance。
   * 旧口径（travelPerChar＝min(64, Pw×0.25)/字数、20 字/行）随本批作废。
   */
  private recalcTravel(): void {
    // D5：可用行宽＝纸面板 Pw − 2×marginH（不是旧纸宽 paperWidthVp）
    const usable: number = this.lineWidth26();
    const adv: number = this.currentAdvance();
    const perLine: number = Math.floor(usable / adv);
    this.charsPerLineNum = perLine > 6 ? perLine : 6;
    // D5：lineWidth＝charsPerLine×advance；D6：O∈[−lineWidth,0]
    this.maxTravelVp = this.charsPerLineNum * adv;
    // travelPerChar 保留字段但语义已改为「一个字宽」（兼容旧调用点，不再当行程）
    this.travelPerChar = adv;
    hilog.info(DOMAIN, TAG, 'recalcTravel lineWidth=%{public}s adv=%{public}s cpl=%{public}s (D5/D6)',
      this.maxTravelVp.toFixed(2), adv.toFixed(2), this.charsPerLineNum.toString());
  }

  /**
   * 每落一字：纸与字车共用的偏移 O 左移「当前字宽」（物理模型，§2.7 解除授权后）。
   * 不用 travelPerChar（最大行程/每行字数）—— 那会让纸移得比字距慢、末字屏 x 右漂。
   */
  private stepCarriageLeft(): void {
    // D3：O −= advance（当前字符宽），不再用 travelPerChar 当行程
    const dO: number = this.currentAdvance();
    let target: number = this.carriageOffsetVp - dO;
    // 批 55：行程限幅——O 一律钳在 [−65, 0]（纸左缘最多出屏 10%）
    const limit: number = -Math.min(this.maxTravelVp, this.CARRIAGE_TRAVEL_LIMIT_VP);
    if (target < limit) {
      target = limit;
    }
    this.carriageOffsetVp = target;
    // 帧时钟下一帧把 paperOffsetVp 写成 K×O；这里只改逻辑值（纯数据，无 animateTo）
    this.commitSeq = this.commitSeq + 1;
    hilog.info(DOMAIN, TAG, 'carriage offset -> %{public}s (dO=%{public}s)', target.toFixed(2), dO.toFixed(2));
  }

  /** 删除/覆盖删除：字车条右退一格，上限 0。 */
  private stepCarriageRight(): void {
    // D3 对称：删除时 O += advance，上限 0；70ms 弹簧由帧时钟的 deleteAnim 段驱动
    let target: number = this.carriageOffsetVp + this.currentAdvance();
    if (target > 0) {
      target = 0;
    }
    const springStarted: number = Date.now();
    hilog.info(DOMAIN, TAG, 'carriage spring start dur=70 target=%{public}s', target.toFixed(2));
    this.getUIContext().animateTo({
      duration: 70,
      curve: curves.springCurve(0, 1, 260, 20),
      onFinish: (): void => {
        hilog.info(DOMAIN, TAG, 'carriage spring finish dur=70 dt=%{public}d value=%{public}s target=%{public}s',
          Date.now() - springStarted, this.carriageOffsetVp.toFixed(2), target.toFixed(2));
      }
    }, () => {
      this.carriageOffsetVp = target;
    });
  }

  /** 换行回位：250ms 弹簧从累计量一次性滑回 0，与拨杆摆动 + 叮声 + 导件回左缘同步。 */
  private resetCarriage(): void {
    // 快速回位：200ms fast-out，末端 2vp 叩击回弹（不用 250ms 弹簧）
    const start: number = this.carriageOffsetVp;
    if (this.canvasEnabled) {
      // 第 17 批批 1：Canvas 路径的 O 回位与 2vp jolt 归帧时钟（newline O 段 t0+450ms 起 250ms），
      // 这里只落逻辑值，避免 animateTo 每帧写 prop 与帧时钟抢驱。
      this.carriageOffsetVp = 0;
    } else {
      this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseInOut }, () => {
        this.carriageOffsetVp = 0;
        this.joltYVp = 2;
      });
      this.getUIContext().animateTo({ duration: 40, delay: 150, curve: Curve.FastOutSlowIn }, () => {
        this.joltYVp = 0;
      });
    }
    // 第 31 批：旋钮累积已提前到 t=150（advancePaperOneLine），此处不再累加
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

  /** 第 2 批 F3：启动时重注册已导入字体（CUJ2 重启后仍有效）。 */
  private registerImportedFonts(): void {
    const list: ImportedFont[] = CustomizeStore.importedFonts();
    if (list.length === 0) {
      return;
    }
    let changed: boolean = false;
    for (let i = 0; i < list.length; i++) {
      const ok: boolean = FontService.registerFromFile(this.getUIContext(), list[i].familyName, list[i].path);
      const next: string = ok ? 'ok' : 'failed';
      if (list[i].status !== next) {
        list[i].status = next;
        changed = true;
      }
    }
    this.registerImportedFontsChanged(changed, list);
  }

  private registerImportedFontsChanged(changed: boolean, list: ImportedFont[]): void {
    if (changed) {
      CustomizeStore.setImportedFonts(list);
      hilog.info(DOMAIN, TAG, 'imported fonts re-registered n=%{public}s', list.length.toString());
    }
  }

  /** 第 2 批 F3：四台机当前字体族（给换装页展示）。 */
  private machineFontsList(): string[] {
    // 读一下 rev 建立 @State 依赖：字体管理页应用后换装页四行能刷新
    const rev: number = this.fontPrefsRev;
    if (rev < 0) {
      hilog.warn(DOMAIN, TAG, 'fontPrefsRev negative');
    }
    const out: string[] = [];
    for (let i = 0; i < MACHINES.length; i++) {
      const fam: string = CustomizeStore.fontFamily(MACHINES[i].kind as string);
      out.push(fam.length > 0 ? fam : findFont(DEFAULT_FONT).familyName);
    }
    return out;
  }

  /** 第 2 批 F3：按机器偏好应用字体（familyName 为空回落默认）。 */
  /** 第 10 批 R3：删字体后同会话刷新当前机型字体（重读 store＋apply，不轮询）。 */
  private refreshFontAfterDelete(): void {
    const family: string = CustomizeStore.fontFamily(this.machineKind as string);
    this.applyMachineFont(family);
    this.fontPrefsRev = this.fontPrefsRev + 1;
    hilog.info(DOMAIN, TAG, 'font refresh after delete machine=%{public}s family=%{public}s',
      this.machineKind as string, family);
  }

  private applyMachineFont(family: string): void {
    let chosen: FontSpec | null = null;
    if (family.length > 0) {
      for (let i = 0; i < FONTS.length; i++) {
        if (FONTS[i].familyName === family) {
          chosen = FONTS[i];
          break;
        }
      }
      if (chosen === null) {
        // 导入字体（imp-*）：直接采用族名，不回落到随包默认
        this.fontFamily = family;
        hilog.info(DOMAIN, TAG, 'apply imported font family=%{public}s', family);
        return;
      }
    }
    if (chosen === null) {
      chosen = findFont(DEFAULT_FONT);
    }
    this.fontFamily = chosen.familyName;
    this.docModel.setFont(chosen.font);
    this.fontPlateLabel = fontDisplayName(chosen.font);
  }

  /** 字体条显示名（'Courier Prime'）：族名无空格，不能直接当界面文字（第 5 批回批修正）。 */
  private fontLabelOfCurrentMachine(): string {
    const family: string = CustomizeStore.fontFamily(this.machineKind as string);
    if (family.length > 0) {
      return fontDisplayNameByFamily(family);
    }
    return fontDisplayName(findFont(DEFAULT_FONT).font);
  }

  private fontKindOfCurrentMachine(): string {
    const family: string = CustomizeStore.fontFamily(this.machineKind as string);
    for (let i = 0; i < FONTS.length; i++) {
      if (FONTS[i].familyName === family) {
        return FONTS[i].font as string;
      }
    }
    return '';
  }

  /** 第 2 批 F3：刷新当前纸的自定义值缓存（默认值来自 catalog，像素零变化）。 */
  private refreshPaperCustom(): void {
    const p: PaperValues = CustomizeStore.paper(this.paperKind as string);
    this.customMarginH = p.marginH;
    this.customMarginT = p.marginT;
    this.customMarginB = p.marginB;
    this.customPaperColor = p.color;
    this.customPaperTexture = p.texture;
    this.customPaperRuled = p.ruled;
  }

  private marginH(): number {
    return this.customMarginH > 0 ? this.customMarginH : findPaper(this.paperKind).marginH;
  }

  private marginT(): number {
    return this.customMarginT > 0 ? this.customMarginT : findPaper(this.paperKind).marginTop;
  }

  private marginB(): number {
    return this.customMarginB > 0 ? this.customMarginB : findPaper(this.paperKind).marginBottom;
  }

  /** 第 2 批 F3：字号变更后固定重排（评审 M-6 五步）。 */
  private applyFontSize(value: number): void {
    const v: number = clampFontSize(value);
    CustomizeStore.setFontSize(this.machineKind as string, v);
    this.fontSizeVp = v;
    this.lineHeightVp = lineHeightOf(v);
    this.measureAdvance();
    this.recalcTravel();
    this.rewrapAllOnLoad();
    this.syncRows();
    this.recalcPaperHeight();
    hilog.info(DOMAIN, TAG, 'fontSize apply=%{public}s lineHeight=%{public}s',
      v.toString(), this.lineHeightVp.toFixed(2));
  }

  /** 第 3 批：导出前 flush 保存并判定非空（M-6）；第 13 批 ⑥：按范围分支。 */
  private prepareExport(scope: string, dossierId: string): boolean {
    statsService.flushPending();
    statsService.flushFoldTyped();
    if (scope === 'dossier') {
      // 整卷宗：不依赖 live docId；先查卷宗内文档，再逐篇判有内容（归档纸沿用非空字符口径）
      const list: DocSummary[] = docStore.listByDossier(dossierId);
      if (list.length === 0) {
        return false;
      }
      for (const sum of list) {
        const d: DocData | null = docStore.load(sum.id);
        if (d === null) {
          continue;
        }
        for (let i = 0; i < d.lines.length; i++) {
          if (d.lines[i].text.replace(/\s/g, '').length > 0) {
            return true;
          }
        }
        const sheets: DocLine[][] = d.sheets === undefined ? [] : d.sheets;
        for (let si = 0; si < sheets.length; si++) {
          for (let li = 0; li < sheets[si].length; li++) {
            if (sheets[si][li].text.replace(/\s/g, '').length > 0) {
              return true;
            }
          }
        }
      }
      return false;
    }
    this.flushSave();
    const targetId: string = this.exportDocId.length > 0 ? this.exportDocId : this.docId;
    if (targetId.length === 0) {
      return false;
    }
    const live: DocData = this.docModel.toDocData();
    if (targetId === this.docId) {
      for (let i = 0; i < live.lines.length; i++) {
        if (live.lines[i].text.replace(/\s/g, '').length > 0) {
          return true;
        }
      }
      return false;
    }
    const d: DocData | null = docStore.load(targetId);
    if (d === null) {
      return false;
    }
    for (let i = 0; i < d.lines.length; i++) {
      if (d.lines[i].text.replace(/\s/g, '').length > 0) {
        return true;
      }
    }
    return false;
  }

  /** 第 13 批 ⑥：文档视图页导出入口（整篇）。 */
  private onExportDoc(docId: string): void {
    this.exportDocId = docId;
    this.exportDossierId = '';
    this.exportScope = 'doc';
    // 目标走模块级传递（见 model/ExportTarget），页面 prop 时序不再影响
    setExportTarget({ docId: docId, dossierId: '', scope: 'doc' });
    this.pushPage('export');
  }

  /** 第 13 批 ⑥：卷宗详情页导出入口（整卷宗）。 */
  private onExportDossier(dossierId: string): void {
    hilog.info(DOMAIN, TAG, 'onExportDossier id=%{public}s', dossierId);
    this.exportDocId = '';
    this.exportDossierId = dossierId;
    this.exportScope = 'dossier';
    setExportTarget({ docId: '', dossierId: dossierId, scope: 'dossier' });
    this.pushPage('export');
  }

  /** 第 23 批（19 号稿 §4-9／§4-7）：三台手动机的模式回显（1960s 不在此列，固定电动单套）。 */
  private refreshAnimModes(): void {
    const manual: string[] = [MachineKind.UPRIGHT_1920S as string,
      MachineKind.PORTABLE_1930S as string, MachineKind.STREAMLINED_1950S as string];
    const next: string[] = [];
    for (let i = 0; i < manual.length; i++) {
      next.push(CustomizeStore.animMode(manual[i]));
    }
    this.animModes = next;
  }

  /** 机型页切模式：落盘 + 刷新回显 + 若切的是当前机则立即生效（重挂载/过渡由 Canvas 处理）。 */
  private setAnimMode(machine: string, mode: string): void {
    CustomizeStore.setAnimMode(machine, mode);
    this.refreshAnimModes();
    if ((machine as MachineKind) === this.machineKind) {
      this.animMode = machine === (MachineKind.ELECTRIC_1960S as string) ? 'realistic' : mode;
      // 第 26 批（批 3）：切模式跑 200ms 内插（K 从旧值到新值）
      this.setModeK(true);
    }
    hilog.info(DOMAIN, TAG, 'anim mode set machine=%{public}s mode=%{public}s', machine, mode);
  }

  /**
   * 第 26 批（批 3／§4.2）：模式系数 K 的生效——切模式 200ms 内插（D20），切机/冷启动直接落值。
   * K＝1.0 写实／0.3 模拟；V＝K×O。过渡期间禁打字由 pendingChars 队列天然串行化（不另立旗）。
   */
  private setModeK(animate: boolean): void {
    const to: number = rollerKFor(this.animMode, this.isTablet, this.machineKind);
    if (!animate) {
      this.modeK = to;
      this.modeKFrom = to;
      this.modeKTo = to;
      this.modeT0 = -1;
      hilog.info(DOMAIN, TAG, 'modeK set k=%{public}s mode=%{public}s', to.toFixed(3), this.animMode);
      return;
    }
    if (Math.abs(this.modeK - to) < 0.001) {
      return;
    }
    this.ensureFrameClock();
    this.modeKFrom = this.modeK;
    this.modeKTo = to;
    this.modeT0 = this.frameNowMs;
    hilog.info(DOMAIN, TAG, 'modeTrans start from=%{public}s to=%{public}s dur=%{public}s',
      this.modeKFrom.toFixed(3), this.modeKTo.toFixed(3), MODE_TRANS_DUR_MS.toString());
  }
  private applyMachine(kind: MachineKind): void {
    // 换机时防御性清空预编辑串
    this.cnPreview = '';
    const prevKind: MachineKind = this.machineKind;
    this.machineKind = kind;
    // 第 23 批（19 号稿 §4-3）：换机即读该机的动画模式（1960s 恒 realistic，电动单套）。
    this.animMode = kind === MachineKind.ELECTRIC_1960S ? 'realistic' : CustomizeStore.animMode(kind as string);
    this.refreshAnimModes();
    // 第 26 批（批 3）：换机不跑 200ms 过渡（直接落 K）
    this.setModeK(false);
    // 第 2 批 F3：字体跟机器走（custom.font.<machine>.family 为渲染唯一来源）
    this.applyMachineFont(CustomizeStore.fontFamily(kind as string));
    // 第 4 批 F8：每机独立音效包（唯一 preload 入口；双缓冲不静音）
    this.audioService.preload(AudioService.packForMachine(kind as string))
      .then((ok: boolean) => {
        hilog.info(DOMAIN, TAG, 'audio pack=%{public}s ready=%{public}s',
          AudioService.packForMachine(kind as string), ok ? 'true' : 'false');
      })
      .catch(() => { hilog.warn(DOMAIN, TAG, 'audio pack preload failed'); });
    // 第 0b 批隔离：换机即清空四份拨杆比例与拖拽旗，并递增纪元让渲染件立即回静止角
    if (shouldResetOnSwitch(prevKind as string, kind as string)) {
      this.resetLeverStates();
      this.leverEpoch = nextEpoch(this.leverEpoch);
    }
    // §10：机型改成全局偏好——换机即落盘，重启仍记得
    appPreferences.setString(PrefKeys.MACHINE, kind as string);
    this.docModel.setMachine(kind);
    // P0-4：机器变了就重解析键位表，不管尺寸变没变
    this.reloadKeymap();
    // P1-10：换装落盘（有内容才存，空纸不存）
    this.flushSave();
    // 第 2 批 F3：每机字号是用户覆盖值，换机后按新机重新量一次（含 measureAdvance）
    this.measureStage();
    // 第 25 批（批 2）：机身明暗变了 → 顶栏/字体条/系统栏前景色跟着换（浅机身用深色）
    this.applySystemBarContentColor();
    this.fadeSwitch();
  }

  private applyPaper(kind: PaperKind, userAction: boolean = false): void {
    this.paperKind = kind;
    // 字号/行高由 measureStage 的公式统一决定（§2.6），换纸不再覆盖
    // 第 2 批 F3：换纸不重置字体（字体跟机器走，applyPaper 不再碰 fontFamily）
    this.refreshPaperCustom();
    statsService.recordPaperKind(kind as string);
    // 第 9 批 F5：纸张事件只记**用户主动换纸**（启动恢复不算换纸，否则每次冷启动都 +1）
    if (userAction) {
      statsService.recordEvent(StatsEvents.PAPER_CHANGED);
    }
    this.docModel.setPaper(kind);
    this.recalcPaperHeight();
    this.fadeSwitch();
    // P1-10：换装落盘
    this.flushSave();
  }

  private applyRibbon(kind: RibbonKind, userAction: boolean = false): void {
    // 第 9 批 F5：换色带事件只记用户主动切换（启动恢复不算，否则 A12 会被冷启动白送）
    if (userAction) {
      statsService.recordEvent(StatsEvents.RIBBON_CHANGED);
    }
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

  /** 批 41：状态栏内容色随页切换——打字机页是浅薄荷底，用深色图标；其余深底页用浅色。 */
  private async applyStatusBarForTop(): Promise<void> {
    const host = this.getUIContext().getHostContext();
    if (host === undefined || host === null) { return; }
    const top: string = this.navStack.length > 0 ? this.navStack[this.navStack.length - 1] : 'home';
    const color: string = top === 'typewriter' ? '#3a3a3a' : '#dbccb3';
    try {
      const win: window.Window = await window.getLastWindow(host as common.UIAbilityContext);
      await win.setWindowSystemBarProperties({ statusBarContentColor: color });
      hilog.info(DOMAIN, TAG, 'statusBarContentColor -> %{public}s (top=%{public}s)', color, top);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'statusBarContentColor switch failed');
    }
  }

  // 第 26 批（批 3／R-B2）：detectLayers 已删除（无机器图层可检测；layers/ 素材在批 3 清理）

  // ---------------- 纸片 ----------------

  /**
   * 模型 B（屏高百分比三态）：
   *   paperTop = max(10%, 25% − (行−1)×2.83%) × 屏高
   *   strike   = paperTop + 3% + (行−1)×2.83%   ← 封顶前纸上移抵消、封顶后实打实下移
   *   carriageTop = 56% × 屏高（三态同高，不动）
   *   paperHeight = carriageTop − paperTop，Pw = paperHeight / 1.414
   */
  private recalcPaperHeight(kind: string = 'recalc'): void {
    // H 冻结：只用首次稳定测到的 availableHeightVp，不每轮重读 live inset
    // 第 5 批回批 F7（D0b-2）：冻结只适用于非折叠态；desk 用上半区高，frozenHVp 不清零
    // （切回 EXPAND 继续用冻结值，避免反复冻结/解冻）。
    const isDesk: boolean = this.layoutMode === 'desk';
    if (this.frozenHVp <= 0 && this.availableHeightVp > 0 && !isDesk) {
      this.frozenHVp = this.availableHeightVp;
    }
    // §19：手机 H 用 region（纸面区真高），平板沿用冻结的 availableHeightVp；desk 用上半区高
    const H: number = isDesk
      ? (this.creaseTopVp - this.topInset)
      : (this.isTablet
        ? (this.frozenHVp > 0 ? this.frozenHVp : this.availableHeightVp)
        : this.regionHeightVp);
    const rows: number = this.docModel.getLines().length;
    // §19 定案：手机系数 0.64（平板 0.56 不动）。下限：carriageTopVp 不得小于 10×行高，
    // 否则字车会顶到顶栏。真机量底部余量，仍 >40vp 就继续往上调（上限 0.75）。
    // 第 5 批回批 F7（D0b-2）：desk 时 kTop 沿用平板 0.56、strikeShift/bandShift 取 15
    const kTop: number = (this.isTablet || isDesk) ? 0.56 : 0.64;
    let top: number = kTop * H;
    const topFloor: number = 10 * this.lineHeightVp;
    if (!this.isTablet && !isDesk && top < topFloor) {
      top = topFloor;
    }
    this.carriageTopVp = top;
    // 打击行固定：字车条顶 − 底边距 20 − 行高/2，行数变化也不动
    // 平板：打击行上移 15vp（与横杆上移联动，横杆不挡字）；手机走原值
    const strikeShift: number = (this.isTablet || isDesk) ? 15 : 0;
    this.strikeLineVp = this.carriageTopVp - this.marginB() - this.lineHeightVp / 2 - strikeShift;
    // 纸高定值（唯一一处）：Ph = Pw × 1.414，行数变了不动
    this.paperHeightVp = this.paperWidthVp * 1.414;
    // 纸顶动、纸底藏：纸顶每换行上移一个行高，纸底始终在滚筒下方（被容器裁掉）
    // 纸带基数随字号同步变：20（底边距）+ 行高 + 44（内容顶）
    const bandShift: number = (this.isTablet || isDesk) ? 15 : 0;
    const paperBandBase: number = this.marginB() + this.lineHeightVp + 44 + bandShift;
    // 纸顶只由「光标行」派生（空行也占行），换行/退行不再手动 ±行高
    this.paperTopTargetVp = this.carriageTopVp - paperBandBase
      - this.docModel.getCursor().line * this.lineHeightVp;
    // 批 69：**撤掉纸顶下限 capTop**——纸顶只由「光标行」派生，没有任何下限：
    // 光标每加一行纸顶就上移一个行高，可一路到负值（屏幕上沿之上），永不回头。
    // （原来 capTop 钳制会让纸顶撞限后停住、纸高继续长 ⇒ 纸底被迫下移，这就是「占满上半部后向下延伸」。）
    // 第 5 批回批 F7（D4 裁剪）：desk 半开时可见纸高已由 flex 纸区（上半区）限制，
    // 旧的容器 cap（creaseTop − paperTop）随容器删除退役。
    if (this.paperAnimateNext) {
      // 换行编排第 2 段：纸上滑 300ms EaseInOut（不许直接赋值跳变）
      this.paperAnimateNext = false;
      // 批 64（T6 余项）：Canvas 纸段路径删除（canvasEnabled 恒 false，tick 无消费者）——只剩 animateTo。
      this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
        this.paperTopVp = this.paperTopTargetVp;
      });
    } else {
      // 无动画重算：逻辑值瞬时落位（不再发 dur=0 的纸段 tick，不存在跨 prop 抢跑）。
      this.paperTopVp = this.paperTopTargetVp;
    }
    // 批 64（T6 尾项）：可见纸高恒与行数同步——历史上只有「换行」才更新（旧 syncVisible 开关），
    // 退格删行／换纸清空都不更新，实测 1 行时可见纸高仍卡在满纸 366.9vp（截图纸高 863px 不变）。
    // 批 69：纸高不再封顶，这里直接按内容求一次（原复用上面已算好的 capPaperH，capTop 段已删）。
    this.paperGrowVp = this.paperVisibleTargetVp();
    // 批 69 打点：行数／纸高／纸顶／纸底和——用来证明「一路在变、没停在旧封顶」。
    hilog.info(DOMAIN, TAG,
      'paper69 kind=%{public}s lines=%{public}d grow=%{public}s top=%{public}s bottom=%{public}s',
      kind, rows, this.paperGrowVp.toFixed(1), this.paperTopVp.toFixed(1),
      (this.paperTopVp + this.paperGrowVp).toFixed(1));
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
      this.carriageTopVp.toFixed(1), this.paperTopVp.toFixed(1),
      (this.carriageTopVp - this.paperTopVp + 2).toFixed(1),
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
  private animatePaperHeight(kind: string = 'newline'): void {
    this.paperAnimateNext = true;
    this.recalcPaperHeight(kind);
  }

  // 批 64（T6 余项）：paperTick()（第 17 批 Canvas 纸段触发）已删除——纸段只剩 animateTo，
  // 换纸分段打点由 pcTrace('start'/'step1'/'step1-settled'/'step2-work'/'step2-hide'/'end') 承担。

  // ---------------- 击打链 ----------------

  /** 实测单字 advance（MeasureUtils，px→vp）：字号或字体变时重测。 */
  private measureAdvance(): void {
    try {
      const mu = this.getUIContext().getMeasureUtils();
      const ePx: number = mu.measureText({ textContent: 'V', fontSize: this.fontSizeVp, fontFamily: this.genericFamilyFor(this.fontFamily) });
      const cPx: number = mu.measureText({ textContent: '永', fontSize: this.fontSizeVp, fontFamily: this.genericFamilyFor(this.fontFamily) });
      // Courier Prime 的 hmtx 实测 1228/2048 = 0.600 em（fontTools 直读 ttf）。
      // MeasureUtils 看不到 registerFont 注册的族名（会回落系统比例字体），故只记录、不回写。
      this.advEngVp = this.fontSizeVp * 0.6;
      this.advCjkVp = this.fontSizeVp;
      const iPx: number = mu.measureText({ textContent: 'i', fontSize: this.fontSizeVp, fontFamily: this.genericFamilyFor(this.fontFamily) });
      const mPx: number = mu.measureText({ textContent: 'm', fontSize: this.fontSizeVp, fontFamily: this.genericFamilyFor(this.fontFamily) });
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
    return this.bracketW() / this.bp().bracketAspect;
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
    return this.bracketLeftRel() + this.bp().bracketPivotX * this.bracketW();
  }

  private pinYRel(): number {
    return this.bracketTopRel() + this.bp().bracketPivotY * this.bracketH();
  }

  /** 拨杆支架素材按机型静态分支（§11 A：1930s 是 T 形支架，不许顶 1920s 矩形板） */
  /** §14：支架素材由蓝图提供 —— Index 里不再出现任何机型资产路径 */
  private bracketSrc(): Resource {
    return this.bp().bracketRawfile();
  }

  /** 当前机型的拨杆拖拽比例（读当前机型那一份，依赖按机建立）。 */
  private leverRatio(): number {
    const slot: number = slotOf(this.machineKind as string);
    if (slot === 0) { return this.leverRatio1920; }
    if (slot === 1) { return this.leverRatio1930; }
    if (slot === 2) { return this.leverRatio1950; }
    return this.leverRatio1960;
  }

  /** 写当前机型的拨杆拖拽比例（只动本机那一份）。 */
  private setLeverRatio(v: number): void {
    const slot: number = slotOf(this.machineKind as string);
    if (slot === 0) {
      this.leverRatio1920 = v;
      return;
    }
    if (slot === 1) {
      this.leverRatio1930 = v;
      return;
    }
    if (slot === 2) {
      this.leverRatio1950 = v;
      return;
    }
    this.leverRatio1960 = v;
  }

  /** 当前机型的换行计数（第 0b 批四份独立，不再共享）。 */
  private newlineTick(): number {
    const slot: number = slotOf(this.machineKind as string);
    if (slot === 0) { return this.newlineTick1920; }
    if (slot === 1) { return this.newlineTick1930; }
    if (slot === 2) { return this.newlineTick1950; }
    return this.newlineTick1960;
  }

  /** 只递增当前机型的换行计数（驱动该机拨杆摆动）。 */
  private bumpNewlineTick(): void {
    const slot: number = slotOf(this.machineKind as string);
    if (slot === 0) {
      this.newlineTick1920 = this.newlineTick1920 + 1;
      return;
    }
    if (slot === 1) {
      this.newlineTick1930 = this.newlineTick1930 + 1;
      return;
    }
    if (slot === 2) {
      this.newlineTick1950 = this.newlineTick1950 + 1;
      return;
    }
    this.newlineTick1960 = this.newlineTick1960 + 1;
  }

  /** 切机时清空四份比例与拖拽旗（隔离：跨机型不携带任何在途状态）。 */
  private resetLeverStates(): void {
    this.leverRatio1920 = 0;
    this.leverRatio1930 = 0;
    this.leverRatio1950 = 0;
    this.leverRatio1960 = 0;
    this.leverDragActive = false;
    this.leverRatioLogical = 0;
  }

  // ---- 第 0b 批：拖拽处理唯一实现（原三份复制粘贴收敛于此）----
  // 批 2（§7）：canvas 开时角度归 Canvas（内部字段直驱），Index 只留「逻辑比例」用于过半判定，
  // 不回写角度、不写 @State（避免每帧 Move 触发 ArkUI 重渲染）。canvas 关时仍走旧路径。

  /** 拖拽开始：active 由调用方按热区判定（字车层按 x，覆盖层恒 true）。 */
  private leverPanStart(active: boolean, source: string): void {
    this.leverDragActive = active;
    this.leverRatioLogical = 0;
    if (!this.canvasEnabled) { this.setLeverRatio(0); }
    hilog.info(DOMAIN, TAG, 'lever pan start src=%{public}s active=%{public}s canvas=%{public}s',
      source, active ? 'true' : 'false', this.canvasEnabled ? 'true' : 'false');
  }

  /** 拖拽更新：dy 截断在 [0, 杆长]，换算比例走纯函数（两侧同一函数、同一杆长）。 */
  private leverPanUpdate(dyRaw: number): void {
    if (!this.leverDragActive) {
      return;
    }
    this.leverRatioLogical = dragRatioFor(dyRaw, this.leverHForDrag());
    if (!this.canvasEnabled) { this.setLeverRatio(this.leverRatioLogical); }
  }

  /** 拖拽结束：过半换行；canvas 开时释放动画交给 Canvas（判定归 Index）。 */
  private leverPanEnd(): void {
    if (!this.leverDragActive) {
      return;
    }
    const pulled: number = this.canvasEnabled ? this.leverRatioLogical : this.leverRatio();
    this.leverDragActive = false;
    hilog.info(DOMAIN, TAG, 'lever pan end pull=%{public}s canvas=%{public}s',
      pulled.toFixed(3), this.canvasEnabled ? 'true' : 'false');
    const commit: boolean = pulledEnough(pulled);
    if (this.canvasEnabled) {
      // 判定结果交给 Canvas 播 200ms 提交／150ms 回弹；Index 不写角度。
      this.canvasLeverReleaseCommit = commit;
      this.canvasLeverReleaseTick = this.canvasLeverReleaseTick + 1;
      hilog.info(DOMAIN, TAG, 'trigger lever t=%{public}s commit=%{public}s pull=%{public}s',
        Date.now().toString(), commit ? 'true' : 'false', pulled.toFixed(3));
    } else {
      this.setLeverRatio(0);
    }
    if (commit) {
      this.onNewline();
    }
  }

  /** §18.11：拖拽用的杆长（与 LeverLayer 的 layerSizeVp / LEVER_ASPECT 同源） */
  private leverHForDrag(): number {
    return this.leverW() / this.bp().leverAspect;
  }

  // 第 26 批（批 3）：hasLayers 随 Canvas 机器层退役删除
  /** §14：机型蓝图的唯一选择点（Index 里唯一的机型分派） */
  private bp(): MachineBlueprint {
    if (this.machineKind === MachineKind.UPRIGHT_1920S) {
      return BLUEPRINT_1920;
    }
    if (this.machineKind === MachineKind.PORTABLE_1930S) {
      return BLUEPRINT_1930;
    }
    if (this.machineKind === MachineKind.STREAMLINED_1950S) {
      return BLUEPRINT_1950;
    }
    return BLUEPRINT_1960;
  }

  private leverW(): number {
    if (this.isTablet) {
      // §11 B：0.212 是 1920s 拨杆宽高比，改用机型值
      return this.carriageHeight * 1.84 * this.bp().leverSizeRatio;
    }
    // §19.1：手机按「尖端不出屏」反推杆长——leverReachMax = stageW − 8 − pinXRel()，
    // leverH ≤ leverReachMax / sin(最大摆角 35°)。平板不受影响。
    let h: number = this.carriageHeight * 2.5;
    const reachMax: number = this.stageWidth - 8 - this.pinXRel();
    const maxH: number = reachMax / Math.sin(35 * Math.PI / 180);
    if (maxH > 0 && h > maxH) {
      h = maxH;
    }
    return h * this.bp().leverSizeRatio;
  }

  /** 扣子中心 x 硬钳制：永不超出纸右缘 − 扣子半宽。 */
  /** §18 第 1 件：拱的实际位置（唯一渲染源），由 animateArch 平滑跟随目标 */
  @State archXVp: number = 0;
  private archInited: boolean = false;

  /**
   * §18 第 1 件：把拱从当前位置平滑滑到目标。只跟 target，不跟 O 的中间值
   * （O 自己的动画继续走，两层不互相等待）。
   * 批 20：canvas 开时**这一层不许再发 animateTo**——拱的唯一渲染源是 Canvas 帧时钟（17 号稿 §5.3）。
   * 双驱动（Index animateTo ＋ Canvas 帧时钟）是「拱多跑一截再往回拉」的根因。
   * fromStrike=true 表示这次调用是落字后的那次（拱由 Canvas 打击段自己跟，不再发 tick）。
   */


  /** 当前行文本（供隐藏 Text 实测宽）。 */
  /** 第 16 批 2A：把 PaperRow[] 转成 Canvas 静态层需要的字符串数组。 */
  private docLineTexts(): string[] {
    const out: string[] = [];
    for (let i = 0; i < this.rows.length; i++) {
      out.push(this.rows[i].text);
    }
    return out;
  }

  private currentLineText(): string {
    const cursor = this.docModel.getCursor();
    const line = this.docModel.getLines()[cursor.line];
    return line.text.length > 0 ? line.text : ' ';
  }

  /** 批 56：落字指针屏上 x ＝ 纸左缘 36 ＋ 内边距 25 ＋ 光标纸内 x ＋ 字车偏移 O。 */
  private pointerXVp(): number {
    return 61 + this.cursorXVp26() + this.carriageOffsetVp;
  }

  /** 批 55：字车行程上限——纸左缘出屏 ≤10%（36 − 65 ＝ −29vp）。 */
  private readonly CARRIAGE_TRAVEL_LIMIT_VP: number = 65;

  /**
   * 主动量化当前行的渲染宽（落字／退格共用）。
   * 修 bug（BACKSPACE 后光标不跟随）：`cursorXVp26()` 在行尾读的是 `lineWidthMeasuredVp`，
   * 原来只有落字会主动重算它，退格删字后仍是旧值 ⇒ 光标停在原处。此处统一收口。
   */
  /** 修 bug 用：把光标的三个分量一起打出来（curX／measW／accumW／O／pointerX）。 */
  private logPointerTrace(tag: string): void {
    hilog.info(DOMAIN, TAG,
      'pointerTrace %{public}s curX=%{public}s measW=%{public}s accumW=%{public}s O=%{public}s pointerX=%{public}s',
      tag, this.cursorXVp26().toFixed(2), this.lineWidthMeasuredVp.toFixed(2),
      this.currentLineWidthVp().toFixed(2), this.carriageOffsetVp.toFixed(2),
      this.pointerXVp().toFixed(2));
  }

  private measureLineWidth(): void {
    try {
      const px: number = this.getUIContext().getMeasureUtils().measureText({
        textContent: this.currentLineText(),
        fontSize: this.fontSizeVp,
        fontFamily: this.genericFamilyFor(this.fontFamily),
      });
      this.lineWidthMeasuredVp = this.getUIContext().px2vp(px);
    } catch (e) {
      // 量宽失败保留旧值
    }
  }

  /** 批 50：光标 X——行尾时直接用隐藏 Text 的实测渲染宽，未测到才退回累加。 */
  private cursorXVp26(): number {
    const c = this.docModel.getCursor();
    const lines = this.docModel.getLines();
    const line = c.line < lines.length ? lines[c.line] : undefined;
    if (line !== undefined && line.text.length === 0) {
      return 0;   // 批 56：空行必须归零，否则会读到上一行的陈旧实测宽（指针复位卡在 111vp 即此因）
    }
    if (line !== undefined && c.offset >= line.text.length && this.lineWidthMeasuredVp >= 0) {
      return this.lineWidthMeasuredVp;
    }
    return this.currentLineWidthVp();
  }

  /** 优先用整行渲染实测宽；未测到才退回逐字累加。 */
  private currentLineWidthVp(): number {
    // 只用 ttf 度量（0.600em）累加；隐藏 Text 的实测只记录，不参与布局——
    // 两者在长行上差 ~70vp，实测串可能吃到回落比例字体

    // §18 第 3 件：只累加到**光标 offset**为止（不是整行）。
    // 光标恒在行尾时两者相同；合并点光标在行中时拱跟光标走，不被整行宽钳住。
    const cursor = this.docModel.getCursor();
    const line = this.docModel.getLines()[cursor.line];
    const end: number = cursor.offset < line.text.length ? cursor.offset : line.text.length;
    let w: number = 0;
    for (let i = 0; i < end; i++) {
      w += this.charWidthVp(line.text.charAt(i));
    }
    return w;
  }

  /**
   * §12.2 第 2 条：删后若某逻辑行超纸宽，按纸宽断成多行，恢复不变量「逻辑行不超纸宽」。
   * 光标落到合并点所在那一段的末尾。宽度口径与 commitChar 的位置触发同源（charWidthVp）。
   */
  /** §15 第 2 步：载入时对全部行跑一遍重排（超宽行按纸宽断开）。 */
  private rewrapAllOnLoad(): void {
    let idx: number = 0;
    let total: number = 0;
    let guard: number = 0;
    while (idx < this.docModel.getLines().length && guard < 2000) {
      guard = guard + 1;
      if (this.rewrapOverwideLines(idx, -1)) {
        total = total + 1;
      } else {
        idx = idx + 1;
      }
    }
    if (total > 0) {
      hilog.info(DOMAIN, TAG, 'rewrap on load fixes=%{public}s lines=%{public}s',
        total.toString(), this.docModel.getLines().length.toString());
    }
  }

  private rewrapOverwideLines(lineIdx: number, mergeAt: number): boolean {
    const lines: DocLine[] = this.docModel.getLines();
    if (lineIdx < 0 || lineIdx >= lines.length) {
      return false;
    }
    const usable: number = this.paperWidthVp - 2 * this.marginH();
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
    // 26 号稿 §6.1：可用行宽 165vp（纸宽 220 − 左 25 − 右 30），不是 paper-kind 的 marginH×2
    const usable: number = this.lineWidth26();
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
        // 第 12 批 ④：第 5 行（rowIndex 4）锁定为标点，不参与符号重映射
        if (c.label !== 'Shift' && !c.isExtra && c.rowIndex < 4) {
          const arr: string[] = sym[ri];
          const k: number = ri === 3 ? inRow - 1 : inRow;
          if (k >= 0 && k < arr.length) {
            label = arr[k];
          }
        }
      } else if (this.shiftActive || this.capsLock) {
        // Shift 模式：数字/标点换上档符号；字母帽本来就是大写，不变
        const up: string | undefined = SHIFT_MAP[c.label];
        if (up !== undefined) {
          label = up;
        }
      }
      caps.push({
        id: c.id, label: label, cx: c.cx, cy: c.cy, rowIndex: c.rowIndex,
        isExtra: c.isExtra, xRatio: c.xRatio, yRatio: c.yRatio,
        wRatio: c.wRatio, hRatio: c.hRatio, rRatio: c.rRatio, shape: c.shape,
      });
    }
    return {
      machine: base.machine, caps: caps,
      spaceXMin: base.spaceXMin, spaceXMax: base.spaceXMax,
      spaceYMin: base.spaceYMin, spaceYMax: base.spaceYMax,
      hitRadius: base.hitRadius, spaceR: base.spaceR, overlayColor: base.overlayColor,
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
    this.candPages = Math.max(1, Math.ceil(this.candAll.length / this.candPageSize));
    this.pinyinShown();
    // 打点：buffer / 候选数 / 当前页候选
    const cur: string = this.candCurrent.join(',');
    hilog.info(DOMAIN, TAG, 'cn pinyin buf=%{public}s candAll=%{public}s candCur=%{public}s',
      this.cnPinyin, this.candAll.length.toString(), cur);
  }

  private pinyinShown(): void {
    const start: number = this.candPage * this.candPageSize;
    const out: string[] = [];
    for (let i = start; i < this.candAll.length && out.length < this.candPageSize; i++) {
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
    const abs: number = this.candPage * this.candPageSize + index;
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
      this.candPages = Math.max(1, Math.ceil(this.candAll.length / this.candPageSize));
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
      // 批 36 修正 A3：无候选不落原始拼音；直接丢弃缓冲
      hilog.info(DOMAIN, TAG, 'cn commitTop: no candidates, drop buffer=%{public}s',
        this.pinyinSession.getBuffer());
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
    if (label === 'Caps Lock') {
      this.capsLock = !this.capsLock;
      hilog.info(DOMAIN, TAG, 'caps lock (cn) -> %{public}s', this.capsLock ? 'on' : 'off');
      return true;
    }
    if (label === 'Tab') {
      if (composing) {
        this.pinyinCommitTop();
      }
      for (let ti = 0; ti < 4; ti++) {
        this.queueChar(' ');
      }
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
        // 批 36 修正 A3：拼音串绝不上纸——有候选先选首选，无候选直接丢弃，然后放行换行
        if (this.candAll.length > 0) {
          this.pinyinPick(0);
        }
        if (this.pinyinSession !== null) {
          this.pinyinSession.cancel();
        }
        s.cancel();
        this.cnPinyin = '';
        this.cnPreview = '';
        this.candAll = [];
        this.candCurrent = [];
        hilog.info(DOMAIN, TAG, 'cn return: pinyin buffer dropped (no raw letters on paper)');
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
        this.shiftLiftVp = 0;
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

  /** 26 号稿 §8：出纸槽点按（按上次格式导出；格式选择在导出设置页，暂走导出页入口）。 */
  private onExportSlot(): void {
    hilog.info(DOMAIN, TAG, 'export slot tap -> direct export format=%{public}s', this.lastExportFormat);
    this.directExport();
  }

  /** 26 号稿 §8：黄铜铭牌点按仅显示文档名（改名入口在文档列表页）。 */
  private onPlateTap(): void {
    this.plateHint = true;
    hilog.info(DOMAIN, TAG, 'plate tap title=%{public}s', this.docTitle);
    setTimeout(() => { this.plateHint = false; }, 1600);
    // §8：成就解锁时铭牌亮起，点开看成就（目标页＝现行成就列表页＝收藏页）
    if (this.achieveRev > 0) {
      this.pushPage('collection');
    }
  }

  /** 批 36 §3.4：字体条点按直接轮换到下一个字体（不打开换装页）。 */
  private cycleFont(): void {
    const family: string = CustomizeStore.fontFamily(this.machineKind as string);
    let idx: number = -1;
    for (let i = 0; i < FONTS.length; i++) {
      if (FONTS[i].familyName === family) {
        idx = i;
        break;
      }
    }
    const next: number = (idx + 1) % FONTS.length;
    const fam: string = FONTS[next].familyName;
    CustomizeStore.setFontFamily(this.machineKind as string, fam);
    this.applyMachineFont(fam);
    this.fontPrefsRev = this.fontPrefsRev + 1;
    statsService.recordEvent(StatsEvents.FONT_CHANGED);
    this.flushSave();
    hilog.info(DOMAIN, TAG, 'font cycle -> %{public}s (idx %{public}d/%{public}d)',
      fam, next, FONTS.length);
  }

  /** 批 36 §3.5：出纸槽直出——按上次格式导出，不弹格式选择；落盘到应用 exports/ 目录。 */
  private async directExport(): Promise<void> {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (ctx === undefined || ctx === null) {
      hilog.error(DOMAIN, TAG, 'direct export: no context');
      return;
    }
    if (this.docId.length === 0) {
      hilog.error(DOMAIN, TAG, 'direct export: no docId');
      return;
    }
    const fmt: string = this.lastExportFormat;
    const dir: string = ctx.filesDir + '/exports';
    try {
      fs.mkdirSync(dir);
    } catch (e) {
      // 目录已存在
    }
    let outPath: string = dir + '/carriage-' + Date.now().toString();
    let ok: boolean = false;
    if (fmt === 'image') {
      // 批 36 修正 A4：不悄悄回落——图片直出需要导出模板渲染（在 ExportPage 内），
      // 先明确报缺并保持不动，设计口径待用户定夺
      hilog.error(DOMAIN, TAG,
        'direct export image unsupported: needs ExportTemplate render in ExportPage (no fallback)');
      return;
    }
    if (fmt === 'pdf') {
      outPath += '.pdf';
      const meta = this.docModel.toDocData().meta;
      const r: ExportResult = ExportService.buildPdf(this.docId, this.machineLabelText(),
        this.docTitle, formatDateText(meta.createdAt), outPath);
      ok = r.ok;
      if (!r.ok) {
        hilog.error(DOMAIN, TAG, 'direct export pdf failed: %{public}s', r.error);
      }
    } else {
      outPath += '.txt';
      const r: ExportResult = ExportService.buildTxt(this.docId);
      if (r.ok && r.bytes !== null) {
        try {
          const f = fs.openSync(outPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
          fs.writeSync(f.fd, r.bytes);
          fs.closeSync(f);
          ok = true;
        } catch (e) {
          hilog.error(DOMAIN, TAG, 'direct export write failed: %{public}s', JSON.stringify(e));
        }
      } else {
        hilog.error(DOMAIN, TAG, 'direct export txt failed: %{public}s', r.error);
      }
    }
    if (!ok) {
      return;
    }
    statsService.recordEvent(StatsEvents.DOC_EXPORTED);
    AchievementService.evaluate();
    hilog.info(DOMAIN, TAG, 'direct export ok format=%{public}s path=%{public}s', fmt, outPath);
    this.playSlotFly();
  }

  /** 批 36 §3.5：纸片从出纸槽滑出 40vp 后淡出（300ms）。 */
  private playSlotFly(): void {
    this.slotFlyVisible = true;
    this.slotFly = 0;
    const t0: number = Date.now();
    hilog.info(DOMAIN, TAG, 'slot fly start ms=%{public}s dur=300', t0.toString());
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
        this.slotFly = 1;
      });
    }, 16);
    setTimeout(() => {
      this.slotFlyVisible = false;
      this.slotFly = 0;
      hilog.info(DOMAIN, TAG, 'slot fly end ms=%{public}s elapsed=%{public}s',
        Date.now().toString(), (Date.now() - t0).toString());
    }, 380);
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
      // §14.3 第 5 条：空格也进落字队列（落地时由 landHead 播 playSpace），不许直落
      this.audioService.vibrate();
      this.queueChar(' ');
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
        this.shiftLiftVp = -10;
      }
      return;
    }
    if (cap.label === 'Caps Lock') {
      // 第 13 批：大写锁定——按一次锁存、再按一次解除（与 Shift 的按住态独立）
      this.capsLock = !this.capsLock;
      hilog.info(DOMAIN, TAG, 'caps lock -> %{public}s', this.capsLock ? 'on' : 'off');
      return;
    }
    if (cap.label === 'Tab') {
      // 第 13 批：制表键——插入 4 个空格（走同一落字队列，不直落）
      this.audioService.vibrate();
      for (let ti = 0; ti < 4; ti++) {
        this.queueChar(' ');
      }
      return;
    }
    // Down 只给高亮 + 震动；主击打音移到 onArrive（与落字、纸移动同帧）
    this.audioService.vibrate();
    if (this.symbolMode) {
      // 符号模式：优先落 altText（数字行／标点的符号面），否则落 label
      const alt: string | undefined = cap.altText;
      this.queueChar(alt !== undefined && alt.length > 0 ? alt : cap.label);
      return;
    }
    const up: boolean = this.shiftActive || this.capsLock;
    if (up) {
      // 26 号稿：上档字符优先（数字行的 !@#$…、标点的 _ + { } 等）
      const upText: string | undefined = cap.upText;
      if (upText !== undefined && upText.length > 0) {
        this.queueChar(upText);
        return;
      }
    }
    const ch: string = up ? cap.label.toUpperCase() : cap.label.toLowerCase();
    this.queueChar(ch);
  }

  private onCapUp(cap: CapDef): void {
    if (cap.label === 'Shift') {
      this.shiftActive = false;
    }
  }

  private queueChar(ch: string): void {
    const wasEmpty: boolean = this.pendingChars.length === 0;
    this.pendingChars.push(ch);
    // 第 26 批（批 3）：唯一打击泵＝Index 帧时钟（85ms；字杆/色带由 strikePhase 驱动）。
    // 旧三路（Canvas tick／1920s 字杆 onArrive／120ms 起搏器）随 Canvas 退役删除。
    if (wasEmpty) {
      this.armStrike();
    }
    this.armFallback();
  }

  // ---------------- 第 26 批：帧时钟（§4.3／R-B4） ----------------

  /** 帧时钟宿主（Index）：Animator，1,000,000ms 线性、iterations −1；全稿只此一个时间源。 */
  private ensureFrameClock(): void {
    if (this.frameClock !== null) {
      return;
    }
    const opts: AnimatorOptions = {
      duration: 1000000, easing: 'linear', delay: 0, fill: 'forwards',
      direction: 'normal', iterations: -1, begin: 0, end: 1000000,
    };
    const clock: AnimatorResult = Animator.create(opts);
    clock.onFrame = (value: number): void => {
      this.frameNowMs = value;
      this.frameCount += 1;
      this.tickFrame(value);
    };
    this.frameClock = clock;
    clock.play();
    hilog.info(DOMAIN, TAG, 'frame clock start (Index host)');
  }

  /** 每帧：打击落地、模式过渡内插、纸位移/导件字段回写。 */
  private tickFrame(v: number): void {
    // ① 打击：到点落字（§4.3 snap 约 85ms）
    if (this.strikeAtMs >= 0) {
      const t: number = v - this.strikeAtMs + this.strikeDurMs;
      if (t >= this.strikeDurMs) {
        this.strikeAtMs = -1;
        this.strikePhase = 0;
        this.onStrikeArrive();
        if (this.pendingChars.length > 0) {
          this.armStrike();
        }
      } else {
        // 三角相位：去程 45ms 上升、回落 40ms
        this.strikePhase = t < 45 ? t / 45.0 : (85.0 - t) / 40.0;
      }
    }
    // ② 模式过渡 200ms（§4.2／D20）
    if (this.modeT0 >= 0) {
      const mt: number = v - this.modeT0;
      if (mt >= 200) {
        this.modeK = this.modeKTo;
        this.modeT0 = -1;
        hilog.info(DOMAIN, TAG, 'modeTrans finish dt=%{public}s k=%{public}s',
          mt.toFixed(0), this.modeK.toFixed(3));
      } else {
        const p: number = mt / 200.0;
        this.modeK = this.modeKFrom + (this.modeKTo - this.modeKFrom) * p;
      }
    }
    // ③ 字段回写：纸面板 V＝K×O；导件写实固定/模拟追踪（§4.1 D3–D4、D10）
    this.paperOffsetVp = this.modeK * this.carriageOffsetVp;
    this.leverAngleVp = restDegFor(false) + swingDegFor(false) * this.leverRatioLogical;
    const fixed: number = this.stageWidth * 0.5;
    if (this.animMode === ANIM_MODE_SIMULATED) {
      const tracked: number = Math.min(fixed + 0.7 * (-this.carriageOffsetVp), this.stageWidth);
      this.guideXVp = tracked;
    } else {
      this.guideXVp = fixed;
    }
  }

  /** 第 31 批（Q15a）：旋钮点按进纸一行——只动纸与筒面，不动字车、不复位导件、不发叮声。 */
  private advancePaperOneLine(): void {
    // 批 42（增补-8 §3）：与字车回位同步、同曲线、同时长（250ms FastOutSlowIn）
    this.getUIContext().animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
      this.animatePaperHeight('newline');
      this.texOffsetVp = this.texOffsetVp - this.lineHeightVp;
      this.knobAngle = this.knobAngle + this.perLineDeg();
    });
  }

  /** 一行行高对应的滚筒／旋钮转角（度）：lineHeight ÷ 滚筒周长 × 360。 */
  private perLineDeg(): number {
    return this.lineHeightVp / (Math.PI * this.carriageHeight) * 360;
  }

  /** 第 31 批（Q15a）：点按进纸；newlineBusy 忙时忽略本次点按（不排队、不震动）。 */
  private onKnobAdvance(): void {
    if (this.newlineBusy) {
      hilog.info(DOMAIN, TAG, 'knob advance ignored: newline busy');
      return;
    }
    this.audioService.vibrate();
    this.advancePaperOneLine();
    hilog.info(DOMAIN, TAG, 'knob advance line paperTop=%{public}s knob=%{public}s',
      this.paperTopVp.toFixed(1), this.knobAngle.toFixed(1));
  }

  /** 武装一击：85ms 后由帧时钟触发 landHead；队列内连续击打串行。 */
  private armStrike(): void {
    if (this.strikeAtMs >= 0) {
      return;
    }
    this.ensureFrameClock();
    this.strikeAtMs = this.frameNowMs + this.strikeDurMs;
    this.strikePhase = 0.01;
    hilog.info(DOMAIN, TAG, 'strike start t=%{public}s target=%{public}s dur=85',
      Date.now().toString(), (this.stageWidth * 0.5).toFixed(2));
  }

  /** 非 1920s 起搏器：每 120ms 落一字；队列空即停。 */
  private startPacer(): void {
    if (this.pacerTimer >= 0) {
      return;
    }
    this.pacerTimer = setInterval(() => {
      if (this.pendingChars.length === 0) {
        clearInterval(this.pacerTimer);
        this.pacerTimer = -1;
        return;
      }
      this.landHead();
    }, 120);
  }

  /**
   * 队首兜底（§14.3 第 3 条）：只对**队首字**，且 200ms 内没有 onArrive 才触发；
   * 触发后仍走正常落字链（音＋落字），不许直接 commitChar 静默落字。
   */
  private armFallback(): void {
    if (this.fallbackTimer >= 0) {
      clearTimeout(this.fallbackTimer);
    }
    const armMs: number = Date.now();
    this.fallbackTimer = setTimeout(() => {
      this.fallbackTimer = -1;
      if (this.pendingChars.length === 0) {
        return;
      }
      // 判据：自「武装兜底」以来有没有发生过 onArrive（不是距上次落字多久——
      // 那会让长时间没打字后的首字立刻吃兜底、直接闪现）
      const arrivedSince: boolean = this.lastArriveMs > armMs;
      const since: number = arrivedSince ? 0 : Date.now() - armMs;
      if (since < 200) {
        this.armFallback();
        return;
      }
      this.droppedTicks += 1;
      hilog.error(DOMAIN, TAG, 'typebar fallback head=%{public}s since=%{public}s',
        this.pendingChars[0], since.toString());
      this.landHead();
      if (this.pendingChars.length > 0) {
        this.armFallback();
      }
    }, 200);
  }

  /** 落队首字：空格播 playSpace，其余播主键音（快速连打走 transient）。 */
  private landHead(): void {
    hilog.info(DOMAIN, TAG, 'landHead entry at=%{public}s', Date.now().toString());
    const head: string | undefined = this.pendingChars[0];
    if (head === undefined) {
      return;
    }
    if (this.canvasDebugOpen) {
      // 2B-6 调试时钟：跳过音频启动开销，先验字杆/落字时序
    } else if (head === ' ') {
      this.audioService.playSpace();
    } else {
      const now: number = Date.now();
      const gapMs: number = this.lastArriveMs > 0 ? now - this.lastArriveMs : 9999;
      const fast: boolean = gapMs < 150 || this.pendingChars.length >= 2;
      if (fast) {
        this.audioService.playKeyTransient();
      } else {
        this.audioService.playKey();
      }
      this.fastCount += fast ? 1 : 0;
    }
    this.soundCount += 1;
    const prevMs: number = this.lastArriveMs;
    this.lastArriveMs = Date.now();
    if (prevMs > 0) {
      this.arriveGapSumMs += this.lastArriveMs - prevMs;
      this.arriveGapCount += 1;
    }
    this.arriveCount += 1;
    this.flushPending();
    // 队列还有字：续踢下一击（字杆串行，每字一摆）
    if (this.pendingChars.length > 0) {
      this.armStrike();
    }
    const avg: number = this.arriveGapCount > 0 ? this.arriveGapSumMs / this.arriveGapCount : 0;
    hilog.info(DOMAIN, TAG,
      'land metrics lands=%{public}s avgGap=%{public}sms queue=%{public}s dropped=%{public}s sounds=%{public}s ch=%{public}s',
      this.arriveCount.toString(), avg.toFixed(1), this.pendingChars.length.toString(),
      this.droppedTicks.toString(), this.soundCount.toString(), head);
  }

  private flushPending(): void {
    const ch: string | undefined = this.pendingChars.shift();
    if (ch === undefined) {
      return;
    }
    this.lastCommittedChar = ch;
    this.commitChar(ch);
  }

  private onStrikeArrive(): void {
    // 字杆到位：音＋落字同帧（音由 landHead 按落地字决定：空格 playSpace，其余主键音）
    // 计数与间距统一由 landHead 统计（这里不再重复计，避免 arriveCount 双计）
    this.landHead();
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
    // 批 68（任务 3）：落字即回位——把用户拖出的滑动位动画回 0（250ms）
    this.settlePaperOffset();
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
    // 第 9 批 F12：resume——锁放开后第一个被接受的落字（自换纸入口 pcT0 起算）。
    // 排除 onDelete 的「先落队再删」循环：那是删除动作的副作用，不是用户恢复打字。
    if (this.pcResumeT0 > 0 && !this.pcDelFlushActive) {
      this.pcTrace('resume', this.pcResumeT0, 'firstKeystroke=1');
      this.pcResumeT0 = 0;
    }
    this.hintText = '';
    // ② 位置触发自动换行：下一字会让扣子触顶时先换行，不认字数
    //    raw > limit 与 clampedStrikeXVp 同一判据
    // 批 36 §4.1（门八唯一例外）：换行阈值＝26 号稿行宽 165vp——23 字正好放下、第 24 字才换行
    const nextRaw: number = this.currentLineWidthVp() + this.charWidthVp(ch);
    const limit: number = this.lineWidth26();
    // 批 55：累加或**实测**任一超限即换行（比例字体下实测更宽，防止字溢出纸右缘）
    let nextMeas: number = -1;
    try {
      const curLine: string = this.currentLineText() + ch;
      const px: number = this.getUIContext().getMeasureUtils().measureText({
        textContent: curLine, fontSize: this.fontSizeVp,
        fontFamily: this.genericFamilyFor(this.fontFamily),
      });
      nextMeas = this.getUIContext().px2vp(px);
    } catch (e) {
      nextMeas = -1;
    }
    if ((nextRaw > limit || (nextMeas >= 0 && nextMeas > limit)) && this.docModel.getCursor().offset > 0) {
      hilog.info(DOMAIN, TAG,
        'autoWrap by position offset=%{public}s strikeX=%{public}s nextRaw=%{public}s limit=%{public}s',
        this.carriageOffsetVp.toFixed(2), (this.stageWidth * 0.5).toFixed(2),
        nextRaw.toFixed(2), limit.toFixed(2));
      this.onNewline();
    }
    const outcome = this.docModel.insertText(ch, this.charsPerLine());
    this.syncRows();
    this.animateGuide();
    this.stepCarriageLeft();
    // 批 54：量宽族与渲染族同源；此处与退格共用 measureLineWidth()
    this.measureLineWidth();
    hilog.info(DOMAIN, TAG, 'committed ch=[%{public}s] shift=%{public}s sym=%{public}s', ch,
      this.shiftActive ? 'on' : 'off', this.symbolMode ? 'on' : 'off');
    hilog.info(DOMAIN, TAG, 'landTrace line=%{public}s col=%{public}s paperTop=%{public}s O=%{public}s',
      this.docModel.getCursor().line.toString(), this.docModel.getCursor().offset.toString(),
      this.paperTopVp.toFixed(1), this.carriageOffsetVp.toFixed(1));
    this.logPointerTrace('afterCommit');
    this.scheduleSave();
    // 第 4 批 F11：落字成功即内存自增（不写盘；离页/导出前批量 flush）
    statsService.recordChar();
    // 第 5 批回批 F7（D5）：半开桌台态落字 → fold_typed 发射（内存计数＋hilog；批量落盘在 flush）
    if (this.layoutMode === 'desk') {
      statsService.recordFoldTyped();
    }
    if (outcome.marginBell) {
      this.audioService.playBell();
    }
    // 行满自动换行：同样走换行回位，不许让字车条停在行末位置开始下一行
    if (this.docModel.getCursor().offset > this.charsPerLine()) {
      this.onNewline();
    }
    // 每次落字后把光标矩形推给输入法，候选窗跟着走
    this.pushCnCursor();
    this.animateGuide();
  }

  /**
   * 启动 / 载入文档时按当前行光标重算 O（不许归 0）：
   * O = −当前行已落字总宽，钳制到 −可用行宽，使末字落在导件处、中央件随手左移。
   */
  private recalcOffsetFromCursor(duration: number = 0): void {
    const cursor = this.docModel.getCursor();
    const line = this.docModel.getLines()[cursor.line];
    let w: number = 0;
    for (let i = 0; i < cursor.offset && i < line.text.length; i++) {
      w += this.charWidthVp(line.text.charAt(i));
    }
    // 载入 O 与打字同口径：O = −travelPerChar × 光标列，钳制到 [−maxTravelVp, 0]
    // （旧写法用 −(stageWidth−56)=−306.7vp 当限，与打字的 −maxTravelVp=−64vp 差 4.8 倍）
    let o: number = -this.travelPerChar * cursor.offset;
    // 批 55：与打字同一限幅口径
    // 批 63 阶段 0（任务 1／N1）：超限后赋的是 limit 本身（−65vp），与 stepCarriageLeft 同款；
    // 旧写法赋 −maxTravelVp（平板上 −308vp）会把纸推出画面左缘。
    if (o < -Math.min(this.maxTravelVp, this.CARRIAGE_TRAVEL_LIMIT_VP)) {
      o = -Math.min(this.maxTravelVp, this.CARRIAGE_TRAVEL_LIMIT_VP);
    }
    if (o > 0) {
      o = 0;
    }
    if (duration > 0) {
      // §18 返工：合并时 O 也必须**动画**过去；直接赋值会让纸/字车偏移瞬间跳到底，
      // 看起来就是「拱瞬移到上一行末、不像换行那样平滑」
      this.getUIContext().animateTo({ duration: duration, curve: Curve.FastOutSlowIn }, () => {
        this.carriageOffsetVp = o;
      });
    } else {
      this.carriageOffsetVp = o;
    }
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
    // 写实：导件固定 archFixX（D1）；模拟：追踪落字点（D10，屏边停住）。
    // 最终字段由帧时钟 tickFrame 每帧回写；这里负责切模式/落字时的目标计算与日志口径。
    const fixed: number = this.stageWidth * 0.5;
    let target: number = fixed;
    if (this.animMode === ANIM_MODE_SIMULATED) {
      target = Math.min(fixed + 0.7 * (-this.carriageOffsetVp), this.stageWidth);
    }
    if (Math.abs(this.guideXVp - target) > 0.01) {
      this.guideXVp = target;
    }
  }

  private onDelete(): void {
    // §18.6 第 1 件：删／换行／退行三操作统一守旗（与 commitChar 同口径，两面旗都要查）。
    // 显式按键被忽略后用户可再按；**不许排队**（排队删会删错字）。
    if (this.newlineBusy || this.backBusy) {
      hilog.info(DOMAIN, TAG, 'del skipped: busy nl=%{public}s bl=%{public}s',
        this.newlineBusy ? 'true' : 'false', this.backBusy ? 'true' : 'false');
      return;
    }
    // §18.6 第 3 件：换纸 600ms 内删会撞 DocModelCore.clear()（与 commitChar 同口径）
    if (this.paperChanging) {
      hilog.info(DOMAIN, TAG, 'del skipped: paperChanging');
      return;
    }
    // §15 第 1 步：队列非空 → **先同步落队再正常删除**。
    // 旧口径「只取消队尾就返回」作废：取消的是看不见的排队字，纸面与拱都不动，
    // 用户感知为「删了字、拱停在行末」。
    if (this.pendingChars.length > 0) {
      const n: number = this.pendingChars.length;
      // 第 9 批 F12：该循环触发的 commitChar 是删除副作用，不得记为 resume
      this.pcDelFlushActive = true;
      while (this.pendingChars.length > 0) {
        const ch: string | undefined = this.pendingChars.shift();
        if (ch !== undefined) {
          this.commitChar(ch);
        }
      }
      this.pcDelFlushActive = false;
      if (this.pacerTimer >= 0) {
        clearInterval(this.pacerTimer);
        this.pacerTimer = -1;
      }
      hilog.info(DOMAIN, TAG, 'del flush n=%{public}s', n.toString());
    }
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
        // 修 bug：同上，覆盖态退格也要重量行宽
        this.measureLineWidth();
        // 修 bug：同上，覆盖态退格也不拨字车
        this.animateGuide();
        // 删除后推一次光标矩形，候选窗跟上
        this.pushCnCursor();
      }
      return;
    }
    // 批 68（任务 3）：退格也回位
    this.settlePaperOffset();
    const o = this.docModel.backspace();
    if (o.changed) {
      this.syncRows();
      // 修 bug：删字后必须重新量化行宽，否则行尾光标仍读旧宽而停在原处
      this.measureLineWidth();
      // 修 bug：退格**不能**再拨字车右移——物理打字机退格是「纸不动、打印点回到前一格」，
      // stepCarriageRight 会把 O 往 0 推，正好抵消 curX 的减小 ⇒ 光标停在原处。
      this.animateGuide();
      this.logPointerTrace('afterBackspace');
      // 删除后推一次光标矩形，候选窗跟上
      this.pushCnCursor();
      // §12.2 第 2／3 条：行数变了 → 合并行重排 + 纸顶重算（与 onBackLine 同口径，纸滑不跳变）
      if (this.docModel.getLines().length !== linesBefore) {
        const cm = this.docModel.getCursor();
        if (this.rewrapOverwideLines(cm.line, cm.offset)) {
          this.syncRows();
        }
        // §18 第 2 件：合并后必须按当前光标重算 O（原来只被 stepCarriageRight 拨了 +4vp，
        // 拱比正确位置偏右约 64vp 并被钳在右缘）
        // 与换行／退行同拍：O 200ms 动画，拱 200ms 跟随，纸 250ms 上滑
        this.recalcOffsetFromCursor(200);
        this.paperAnimateNext = true;
        this.recalcPaperHeight();
        this.animateGuide();
      } else {
        this.animateGuide();
      }
      const c1 = this.docModel.getCursor();
      hilog.info(DOMAIN, TAG, 'del after line=%{public}s lines=%{public}s paperTop=%{public}s',
        c1.line.toString(), this.docModel.getLines().length.toString(), this.paperTopVp.toFixed(1));
      // §18 第 0 步：拱位置定性日志
      const pl: number = (this.stageWidth - this.paperWidthVp) / 2 + this.carriageOffsetVp;
      const rawX: number = pl + this.marginH() + this.currentLineWidthVp();
      const limX: number = pl + this.paperWidthVp - this.carriageHeight * 0.92 / 2;
      hilog.info(DOMAIN, TAG,
        'archTrace strikeX=%{public}s raw=%{public}s limit=%{public}s O=%{public}s lineW=%{public}s curLine=%{public}s curOff=%{public}s',
        this.archXVp.toFixed(2), rawX.toFixed(2), limX.toFixed(2), this.carriageOffsetVp.toFixed(2),
        this.currentLineWidthVp().toFixed(2), c1.line.toString(), c1.offset.toString());
    }
  }

  /** 退行：回到上一行文字末尾（不删当前行）；已在第一行则无动作。 */
  private onBackLine(): void {
    // §18.6 第 1 件：与删／换行统一守旗（连按两次退行时第二次被忽略，不会提前清旗）
    if (this.newlineBusy || this.backBusy) {
      hilog.info(DOMAIN, TAG, 'backLine skipped: busy nl=%{public}s bl=%{public}s',
        this.newlineBusy ? 'true' : 'false', this.backBusy ? 'true' : 'false');
      return;
    }
    const cur = this.docModel.getCursor();
    if (cur.line <= 0) {
      return;
    }
    // 第 13 批 ②：退行音效（复用 carriage-reset；t=0 与按下同步，t≈470ms 停流）
    this.audioService.playCarriageReset();
    this.audioService.vibrate();
    hilog.info(DOMAIN, TAG, 'backline sound at O=%{public}s paperTop=%{public}s',
      this.carriageOffsetVp.toFixed(1), this.paperTopVp.toFixed(1));
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
    this.canvasBackTargetVp = targetO;
    this.canvasBackTick = this.canvasBackTick + 1;
    hilog.info(DOMAIN, TAG, 'trigger back t=%{public}s target=%{public}s',
      Date.now().toString(), targetO.toFixed(2));
    // 纸下移一行高（纸上移的逆操作）300ms；字车 O 滑到上一行文字末尾 250ms
    // 纸顶不再手动拨：交给 recalcPaperHeight（由光标行派生）走动画（Canvas 路径发纸段 tick）
    this.paperAnimateNext = true;
    this.recalcPaperHeight('back');
    this.backBusy = true;
    // §18.6 第 2 件：代际守卫——本轮 setTimeout 只负责自己那一代
    this.backLineTick = this.backLineTick + 1;
    const myTick: number = this.backLineTick;
    if (this.canvasEnabled) {
      // 第 17 批批 1：O 250ms 由帧时钟的 back O 段插值（t0 与纸段同为退行触发时）；这里只落逻辑值。
      this.carriageOffsetVp = targetO;
    } else {
      this.getUIContext().animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
        this.carriageOffsetVp = targetO;
      });
    }
    setTimeout(() => {
      if (myTick !== this.backLineTick) {
        hilog.info(DOMAIN, TAG, 'backLine release stale tick=%{public}s cur=%{public}s',
          myTick.toString(), this.backLineTick.toString());
        return;
      }
      this.backBusy = false;
      // §18 第 1 件：退行与纸移动同拍（250ms），拱 200ms 平滑滑到新目标
      this.animateGuide();
      // §14.3 第 4 条：排队字逐字回落字队列（走字杆／起搏），不许循环直落
      // §18 第 4 件：放行前先确认忙窗已清
      if (!this.backBusy) {
        const q: string[] = this.queuedChars.slice(0);
        this.queuedChars = [];
        for (let i = 0; i < q.length; i++) {
          this.queueChar(q[i]);
        }
      }
      // 第 13 批 ②：动作结束（t≈470ms）停掉复位音流，避免 1.14–2.68s 拖尾；沿用代际守卫
      setTimeout(() => {
        if (myTick !== this.backLineTick) {
          return;
        }
        this.audioService.stopRole(SoundRole.CARRIAGE_RESET);
      }, 200);
    }, 270);
    hilog.info(DOMAIN, TAG, 'backLine to line=%{public}s col=%{public}s O=%{public}s paperTop=%{public}s',
      (cur.line - 1).toString(), prevLen.toString(), targetO.toFixed(1), this.paperTopVp.toFixed(1));
  }

  /** 换纸计时打点（第 0 批）：只加日志，不改任何动画时长与顺序。 */
  private pcTrace(stage: string, t0: number, extra: string): void {
    if (!PAPER_CHANGE_TRACE) {
      return;
    }
    hilog.info(DOMAIN, TAG, 'paperChange trace stage=%{public}s dt=%{public}s %{public}s',
      stage, (Date.now() - t0).toString(), extra);
  }

  /** 换纸：一次性手动动作，600ms（旧纸卷出 300 + 新纸卷入 300），期间禁打字。 */
  private onPaperChange(entry: string = 'manual'): void {
    // 换纸时防御性清空预编辑串
    this.cnPreview = '';
    // 第 12 批 ②：换纸计数——判定必须在 clear() 之前；逐行看 text.length>0（不复用 isEmpty()：
    // 多空行纸会误判为空），有内容才 +1；只打空格也算有内容（空格进落字队列、计入字符）。
    let sheetHasContent: boolean = false;
    const sheetLines = this.docModel.getLines();
    for (let si = 0; si < sheetLines.length; si++) {
      if (sheetLines[si].text.length > 0) {
        sheetHasContent = true;
        break;
      }
    }
    if (sheetHasContent) {
      this.sheetNo = this.sheetNo + 1;
      if (this.sheetCount < this.sheetNo) {
        this.sheetCount = this.sheetNo;
      }
      const meta0 = this.docModel.getMeta();
      meta0.sheetNo = this.sheetNo;
      meta0.sheetCount = this.sheetCount;
      hilog.info(DOMAIN, TAG, 'sheet count -> %{public}s/%{public}s entry=%{public}s',
        this.sheetNo.toString(), this.sheetCount.toString(), entry);
    }
    if (this.paperChanging) {
      return;
    }
    const pcT0: number = Date.now();
    this.paperChanging = true;
    // 第 9 批 F12：记录恢复打点起点（锁放开后首个被接受的 commitChar 用它算 resume dt）
    this.pcResumeT0 = pcT0;
    this.pcTrace('start', pcT0,
      'trace=on entry=' + entry + ' lines=' + this.docModel.getLines().length.toString() +
      ' paperH=' + this.paperHeightVp.toFixed(1));
    const startTop: number = this.paperTopVp;
    // 批 64（T6 余项）：box 改为按纸顶派生（容器字段已删）；整张模式 paperFullSheet 无消费者，一并删除。
    hilog.info(DOMAIN, TAG, 'paperChange start top=%{public}s box=%{public}s',
      startTop.toFixed(1), (this.carriageTopVp - startTop + 2).toFixed(1));
    // ① 批 68（任务 4）：旧纸**向上飞出视口顶** 300ms，同时淡出。
    // 飞出距离＝纸高＋视口高（全由 layout 与纸内容高推导），保证整张纸完全出顶。
    const outFly: number = -(this.paperGrowVp + this.paperAreaHVp());
    this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseIn }, () => {
      this.paperFlyVp = outFly;
      this.paperContentOpacity = 0;
      this.knobAngle = this.knobAngle + 180;
      // 半圈对应的筒面长度 = π×Hc/2，纹理纵向滚同样长度
      this.texOffsetVp = this.texOffsetVp - Math.PI * this.carriageHeight / 2;
    });
    hilog.info(DOMAIN, TAG, 'paperChange step1 fly=%{public}s opacity=%{public}s (neg=up)',
      this.paperFlyVp.toFixed(1), this.paperContentOpacity.toFixed(2));
    this.pcTrace('step1', pcT0, 'fly=' + this.paperFlyVp.toFixed(1));
    setTimeout(() => {
      // 第 9 批 F12：step1-settled——300ms 定时器回调第一行，dt 即定时器漂移量（期望 ≈300ms，允 ±50）
      this.pcTrace('step1-settled', pcT0, 'expect=300');
      // ② 新纸从滚筒后卷入 300ms：纸回到起打位，滚筒继续转
      const work0: number = Date.now();
      // 第 13 批 ⑥：归档旧纸（与页码计数同一条件；必须在 clear() 紧前，否则旧纸内容无处可取）
      if (sheetHasContent) {
        const archived: DocLine[] = [];
        const curLines = this.docModel.getLines();
        for (let ai = 0; ai < curLines.length; ai++) {
          archived.push({ text: curLines[ai].text, ribbon: curLines[ai].ribbon });
        }
        this.docModel.pushSheet(archived);
      }
      this.docModel.clear();
      const work1: number = Date.now();
      this.syncRows();
      // 批 64（T6 尾项）记账：换纸清空**不落盘**——flushSave() 有 `docModel.isEmpty()` 守卫（设计「空纸不存」），
      // 所以换纸后重启会把旧纸读回来（实测：换纸后 1 行 → 重启回到 12 行空纸）。真正修法是给 flushSave 加
      // 强制保存入口（需产品决定「空纸是否入卷宗」），本轮不擅改，已记进自检待办。
      const work2: number = Date.now();
      // 第 9 批 F12：step2-work——clear() 与 syncRows() 各自计时（期望合计 ＜50ms）
      this.pcTrace('step2-work', pcT0, 'clear=' + (work1 - work0).toString() + ' sync=' + (work2 - work1).toString() + ' total=' + (work2 - work0).toString());
      this.hintText = '';
      this.carriageOffsetVp = 0;
      // §18.10：换纸后拱必须滑回行首。此处 clear()+syncRows()+O=0 已就绪，
      // clampedStrikeXVp() 的目标即行首；300ms 与第②步新纸卷入同窗，t=600ms 同时到达。
      this.animateGuide();
      // ★改：新纸从滚筒里卷出——动画开始前先把纸顶放到滚筒处藏起来（只露 2vp 纸底缘），
      // 再让 recalcPaperHeight() 把它推到起打位。纸顶从滚筒处往上长出来，不是从天上掉下来。
      this.paperTopVp = this.carriageTopVp;
      // 批 68（任务 4）：新纸先藏到**视口下方**（＋视口高，被视口 clip 藏住、透明度 0），
      // 再滑到 0 并淡入 ⇒ 新纸从下方出现、落到落字位。
      this.paperFlyVp = this.paperAreaHVp();
      this.paperContentOpacity = 0;
      this.pcTrace('step2-hide', pcT0, 'fly=' + this.paperFlyVp.toFixed(1));
      hilog.info(DOMAIN, TAG, 'paperChange step2 hide fly=%{public}s areaH=%{public}s',
        this.paperFlyVp.toFixed(1), this.paperAreaHVp().toFixed(1));
      this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
        this.recalcPaperHeight('paper2');
        this.paperFlyVp = 0;
        this.paperContentOpacity = 1;
        this.knobAngle = this.knobAngle + 180;
        this.texOffsetVp = this.texOffsetVp - Math.PI * this.carriageHeight / 2;
      });
      hilog.info(DOMAIN, TAG, 'paperChange step2 fly=%{public}s opacity=%{public}s',
        this.paperFlyVp.toFixed(1), this.paperContentOpacity.toFixed(2));
      hilog.info(DOMAIN, TAG, 'paperChange done at 600ms knob=%{public}s top=%{public}s',
        this.knobAngle.toFixed(1), this.paperTopVp.toFixed(1));
      this.pcTrace('step2-begin', pcT0, 'knob=' + this.knobAngle.toFixed(1));
      setTimeout(() => {
        this.paperChanging = false;
        this.pcTrace('end', pcT0, 'total=' + (Date.now() - pcT0).toString());
      }, 320);
    }, 300);
  }

  private onNewline(): void {
    // 批 68（任务 3）：回车也回位
    this.settlePaperOffset();
    // §18.6 第 1 件：与删／退行统一守旗
    if (this.newlineBusy || this.backBusy) {
      hilog.info(DOMAIN, TAG, 'newline skipped: busy nl=%{public}s bl=%{public}s',
        this.newlineBusy ? 'true' : 'false', this.backBusy ? 'true' : 'false');
      return;
    }
    // 第三方输入法可能不发 finishTextPreview，换行时防御性清空预编辑串
    this.cnPreview = '';
    hilog.info(DOMAIN, TAG, 'trigger newline t=%{public}s tick=%{public}s',
      Date.now().toString(), this.newlineTick().toString());
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
      this.bumpNewlineTick();
      this.hintText = '';
      hilog.info(DOMAIN, TAG, 'newlineMoveDown to line=%{public}s col=%{public}s O=%{public}s rows=%{public}s',
        (cur.line + 1).toString(), nextLen.toString(),
        this.newlineCarriageTargetO.toFixed(1), allLines.length.toString());
    } else {
      // 末行：先判行数上限（换纸），否则插一行
      const maxRows: number = Math.max(1, Math.floor((this.paperHeightVp - 44 - 20) / this.lineHeightVp));
      if (allLines.length >= maxRows) {
        hilog.info(DOMAIN, TAG, 'newlineAtLastRow -> paperChange maxRows=%{public}s', maxRows.toString());
        this.onPaperChange('newline-auto');
        return;
      }
      this.newlineMoveDown = false;
      this.newlineCarriageTargetO = 0;
      this.newlineBusy = true;
      this.bumpNewlineTick();
      this.hintText = '';
      this.docModel.newline();
      this.syncRows();
      this.scheduleSave();
    }
    // §18.6 第 2 件：捕获本轮换行代际
    const myNlTick: number = this.newlineTick();
    // 纸上滑与滚筒转角都在 t=150 起（拨杆摆出 150ms 之后）
    setTimeout(() => {
      // 第 17 批批 1：Canvas 路径由 recalcPaperHeight 内部算目标后发纸段 tick（kind=newline）；
      // ArkUI 回滚分支仍走 animateTo。旧写法在 tick 时读滞后 prop，纸上滑实际不动。
      // 第 31 批（Q15a）：纸上滑＋筒面纹理＋转角三件同拍（300ms EaseInOut，t=150 起）
      this.advancePaperOneLine();
    }, 0);
    // 编排自测：0/150/350/600 采样（数字代替录屏验单调性）
    const marks: number[] = [0, 125, 250];
    for (let k = 0; k < marks.length; k++) {
      const ms: number = marks[k];
      setTimeout(() => {
        hilog.info(DOMAIN, TAG, 'choreoTrace t=%{public}s offset=%{public}s paperTop=%{public}s knob=%{public}s',
          ms.toString(), this.carriageOffsetVp.toFixed(2), this.paperTopVp.toFixed(1), this.knobAngle.toFixed(1));
      }, ms);
    }
    const t0: number = 0;   // 批 42：与纸上滑同时起（原 450 为顺序编排）
    setTimeout(() => {
      if (this.canvasEnabled) {
        // 第 17 批批 1：Canvas 路径——O 回位由帧时钟在 t0+450ms 起 250ms 插值（jolt 2vp 同起点），
        // 逻辑值在这里直接落到目标（与 animateTo「同步赋终值」同口径）；旋钮角照旧走 ArkUI 值。
        this.carriageOffsetVp = (this.newlineCarriageTargetO < -0.001 || this.newlineMoveDown)
          ? this.newlineCarriageTargetO : 0;
        if (this.newlineCarriageTargetO >= -0.001 && !this.newlineMoveDown) {
          this.guideXVp = this.marginH();
        }
      } else if (this.newlineCarriageTargetO < -0.001 || this.newlineMoveDown) {
        // 「下移一行」分支：字车滑到下一行文字末尾的 O（小行程口径），不回 0
        this.getUIContext().animateTo({ duration: 250, curve: Curve.FastOutSlowIn }, () => {
          this.carriageOffsetVp = this.newlineCarriageTargetO;
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
        this.paperTopVp.toFixed(1), this.newlineTick().toString());
      // 换行完成定位日志 + 释放排队字
      hilog.info(DOMAIN, TAG, 'newlineDone rows=%{public}s paperTop=%{public}s line=%{public}s col=%{public}s O=%{public}s',
        this.docModel.getLines().length.toString(), this.paperTopVp.toFixed(1),
        this.docModel.getCursor().line.toString(), this.docModel.getCursor().offset.toString(),
        this.carriageOffsetVp.toFixed(1));
      // 批 63 阶段 0（任务 5）：纸高已由 animatePaperHeight → recalcPaperHeight(kind) 在换行同一帧
      // 落位；这里不再二次改 height（旧写法 250ms 后才长高，造成纸面滞后、纸顶出屏）。
      hilog.info(DOMAIN, TAG, 'newline paperGrow=%{public}s target=%{public}s',
        this.paperGrowVp.toFixed(1), this.paperVisibleTargetVp().toFixed(1));
      // §18.6 第 2 件：代际守卫（newlineTick 变了说明已被新一轮接管，本轮不许清旗／释放）
      if (this.newlineTick() !== myNlTick) {
        hilog.info(DOMAIN, TAG, 'newline release stale tick=%{public}s cur=%{public}s',
          myNlTick.toString(), this.newlineTick().toString());
        return;
      }
      this.newlineBusy = false;
      this.animateGuide();
      // §14.3 第 4 条：换行编排结束后，排队字逐字回落字队列
      const q: string[] = this.queuedChars.slice(0);
      this.queuedChars = [];
      for (let i = 0; i < q.length; i++) {
        this.queueChar(q[i]);
      }
      if (q.length > 0) {
        hilog.info(DOMAIN, TAG, 'newline release n=%{public}s', q.length.toString());
      }
    }, t0 + 250);
  }

  /** 换行回位（§2.1）：字车条一次性跳回 0 + 导件回左缘，250ms 弹簧，与叮声同步。 */
  private resetCarriageAndGuide(): void {
    const base: number = this.marginH();
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
    // 第 0 批：分享唯一入口 ShareService（原 systemShare 逻辑原样搬入；行为不变）
    try {
      const host = this.getUIContext().getHostContext();
      if (host === undefined || host === null) {
        return;
      }
      ShareService.shareFile(host as common.UIAbilityContext, path, utd)
        .then((r: ShareResult) => {
          if (r.shown) {
            hilog.info(DOMAIN, TAG, 'share panel shown via ShareService');
          } else {
            hilog.error(DOMAIN, TAG, 'share panel failed via ShareService: %{public}s', r.error);
          }
        });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'share failed: %{public}s', JSON.stringify(e));
    }
  }

  /** 第 9 批 F5：把成就服务当前该弹的那条同步到 UI（一次只弹一个）。 */
  private refreshAchieveNotice(): void {
    const n: AchieveNotice | null = AchievementService.pending();
    // 第 10 批 §4.5：成就弹窗要出现时，引导先关（记 seen），不许被引导盖住
    if (n !== null && this.guideVisible) {
      this.closePageGuide();
    }
    this.achieveRev = this.achieveRev + 1;
    if (n !== null) {
      // 批 36：成就解锁时铭牌亮起 600ms
      this.plateGlow = true;
      setTimeout(() => { this.plateGlow = false; }, 600);
      hilog.info(DOMAIN, TAG, 'plate glow on achievement=%{public}s', n.id);
    }
    if (n === null) {
      this.achNoticeKind = '';
      this.achNoticeId = '';
      this.achNoticeCount = 0;
      return;
    }
    this.achNoticeKind = n.kind;
    this.achNoticeId = n.id;
    this.achNoticeCount = n.count;
  }

  /** 第 9 批 F5：成就弹窗内容（单项：名＋说明；汇总：已达成 N 项＋去收藏页）。 */
  @Builder
  achDialogBody() {
    Column() {
      Text($r('app.string.ach_dialog_title'))
        .fontSize(13).fontColor('rgba(232,221,201,0.55)')
      if (this.achNoticeKind === 'summary') {
        Text($r('app.string.ach_summary_title', this.achNoticeCount))
          .fontSize(19).fontColor('#e8ddc9').margin({ top: 10 })
        Text($r('app.string.ach_summary_body'))
          .fontSize(12).fontColor('rgba(232,221,201,0.65)')
          .margin({ top: 8 }).maxLines(2)
      } else {
        Text(this.achNameOf(this.achNoticeId))
          .fontSize(19).fontColor('#c9a45c').margin({ top: 10 })
        Text(this.achDescOf(this.achNoticeId))
          .fontSize(12).fontColor('rgba(232,221,201,0.65)')
          .margin({ top: 8 }).maxLines(2)
      }
      Row({ space: 12 }) {
        if (this.achNoticeKind === 'summary') {
          Button($r('app.string.ach_summary_goto'))
            .fontSize(13).fontColor('#c9a45c').backgroundColor('#2a211a')
            .height(36).layoutWeight(1)
            .onClick(() => {
              AchievementService.dismiss();
              this.refreshAchieveNotice();
              this.pushPage('collection');
            })
        }
        Button($r('app.string.ach_dialog_close'))
          .fontSize(13).fontColor('#1a1713').backgroundColor('#c9a45c')
          .height(36).layoutWeight(1)
          .onClick(() => {
            AchievementService.dismiss();
            this.refreshAchieveNotice();
          })
      }
      .width('100%').margin({ top: 16 })
    }
    .alignItems(HorizontalAlign.Start)
  }

  /** 成就名（资源名 → 字符串；动态 $r 不允许，走 resourceManager 按名取）。 */
  private achNameOf(id: string): string {
    return this.achTextByKey('ach_name_' + id);
  }

  /** 成就说明（资源名 → 字符串）。 */
  private achDescOf(id: string): string {
    return this.achTextByKey('ach_desc_' + id);
  }

  /** 按资源名取字符串（取不到返回空串，不抛）。 */
  private achTextByKey(name: string): string {
    try {
      const host = this.getUIContext().getHostContext();
      if (host === undefined || host === null) {
        return '';
      }
      return host.resourceManager.getStringByNameSync(name);
    } catch (e) {
      return '';
    }
  }

  private flushSave(): void {
    // 第 9 批 F5：判定必须在 flush **完成之后**（设计 §3 不变量）——先把内存里的落字数
    // 落进 stats.day.*／累计计数器，再跑成就判定；否则首次越过阈值那一下会被漏判。
    statsService.flushPending();
    statsService.flushFoldTyped();
    if (!docStore.isReady() || this.docModel.isEmpty()) {
      // 第 9 批 F5：即使没有内容可存，也要跑一次成就判定——consecutiveDays／goalReached 是
      // 当日快照，跨日后必须靠这个边界补判，否则会漏判（设计 §3 不变量）
      AchievementService.evaluate();
      return;
    }
    try {
      this.docId = docStore.save(this.docId, this.docModel.toDocData(),
        this.resolveString($r('app.string.doc_untitled')));
      hilog.info(DOMAIN, TAG, 'saved doc id=%{public}s', this.docId);
      // 第 9 批 F5：保存计数（A14）＋在 flush 完成之后跑一次成就判定
      // （判定不走打字热路径；consecutiveDays/goalReached 都是当日快照，跨日后靠这里补判）
      statsService.recordEvent(StatsEvents.DOC_SAVED);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'flushSave failed');
    }
    AchievementService.evaluate();
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
      // 第 12 批 ②：冷启动恢复路径同样要恢复页码（不经过 loadDocument）
      this.sheetNo = data.meta.sheetNo === undefined ? 1 : data.meta.sheetNo;
      this.sheetCount = data.meta.sheetCount === undefined ? 1 : data.meta.sheetCount;
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
    // 第 12 批 ②：载入恢复页码（老文档缺省 1／1）
    this.sheetNo = data.meta.sheetNo === undefined ? 1 : data.meta.sheetNo;
    this.sheetCount = data.meta.sheetCount === undefined ? 1 : data.meta.sheetCount;
    // §10：文档不再驱动机型——沿用当前全局机型，下次保存时写回 meta.machine
    this.docModel.setMachine(this.machineKind);
    this.paperKind = data.meta.paper;
    this.ribbon = data.meta.ribbon;
    this.carriageOffsetVp = 0;
    this.paperAnimateNext = false;
    // §15 第 2 步：旧文档的超宽行进纸即修（不许留着等用户删到才暴露）
    this.rewrapAllOnLoad();
    this.syncRows();
    // §18 第 2 件：载入后按当前光标重算 O（原来直接归 0，光标在深处时 O 与光标脱节）
    this.recalcOffsetFromCursor();
    this.animateGuide();
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
  // ---- 第 6 批 F6/F10：删除方式、回收站、设置接线 ----

  /** 统一删纸入口：direct＝彻底删；ask/trash＝入回收站（确认由页面按档负责）。 */
  private deletePaper(id: string): void {
    if (deleteModeOf(this.deleteMode) === 'direct') {
      docStore.removePermanently(id);
      hilog.info(DOMAIN, TAG, 'paper deleted permanently id=%{public}s', id);
    } else {
      docStore.remove(id);
      hilog.info(DOMAIN, TAG, 'paper trashed id=%{public}s', id);
    }
    this.docsRev = this.docsRev + 1;
  }

  private renameDocument(id: string, name: string): void {
    if (docStore.rename(id, name)) {
      this.docsRev = this.docsRev + 1;
      hilog.info(DOMAIN, TAG, 'doc renamed id=%{public}s name=%{public}s', id, name);
    }
  }

  private refreshTrashDocs(): void {
    this.trashDocs = docStore.listTrashed();
  }

  private openTrash(): void {
    this.refreshTrashDocs();
    this.pushPage('trash');
  }

  private onTrashChanged(): void {
    if (this.trashOpen) {
      this.refreshTrashDocs();
    }
  }

  private restoreTrash(id: string): void {
    docStore.restore(id);
    // 第 6 批 F10：恢复后若原卷宗已不存在，落为未归档，避免不可达文档
    const data: DocData | null = docStore.load(id);
    if (data !== null) {
      const did: string | null | undefined = data.dossierId;
      if (did !== undefined && did !== null && did.length > 0 && dossierStore.find(did) === null) {
        data.dossierId = null;
        docStore.save(id, data, '未命名');
        hilog.info(DOMAIN, TAG, 'restored orphan -> unfiled id=%{public}s', id);
      }
    }
    this.docsRev = this.docsRev + 1;
    this.refreshTrashDocs();
    hilog.info(DOMAIN, TAG, 'trash restored id=%{public}s', id);
  }

  private purgeTrash(id: string): void {
    docStore.removePermanently(id);
    this.docsRev = this.docsRev + 1;
    this.refreshTrashDocs();
    hilog.info(DOMAIN, TAG, 'trash purged id=%{public}s', id);
  }

  private setDeleteMode(mode: string): void {
    this.deleteMode = deleteModeOf(mode);
    appPreferences.setString(PrefKeys.DELETE_MODE, this.deleteMode);
  }

  private toggleSound(): void {
    this.soundEnabled = !this.soundEnabled;
    appPreferences.setBool(PrefKeys.SOUND_ENABLED, this.soundEnabled);
    this.audioService.setSoundEnabled(this.soundEnabled);
  }

  private toggleVibrate(): void {
    this.vibrationEnabled = !this.vibrationEnabled;
    appPreferences.setBool(PrefKeys.VIBRATION_ENABLED, this.vibrationEnabled);
    this.audioService.setVibrationEnabled(this.vibrationEnabled);
  }

  private setVolume(v0to100: number): void {
    this.volume0to100 = Math.round(v0to100);
    const pref: number = volumeToPref(this.volume0to100);
    appPreferences.setNumber(PrefKeys.VOLUME, pref);
    this.audioService.setVolume(pref);
  }

  /** 第 6 批 F6：设置页回显本地化机名（原来直接显示 kind id）。 */
  private machineLabelText(): string {
    if (this.machineKind === MachineKind.PORTABLE_1930S) { return this.resolveString($r('app.string.machine_name_1930s')); }
    if (this.machineKind === MachineKind.STREAMLINED_1950S) { return this.resolveString($r('app.string.machine_name_1950s')); }
    if (this.machineKind === MachineKind.ELECTRIC_1960S) { return this.resolveString($r('app.string.machine_name_1960s')); }
    return this.resolveString($r('app.string.machine_name_1920s'));
  }

  /** 第 6 批 F6：设置页回显本地化纸名。 */
  private paperLabelText(): string {
    if (this.paperKind === PaperKind.MANUSCRIPT) { return this.resolveString($r('app.string.paper_manuscript')); }
    if (this.paperKind === PaperKind.POSTCARD) { return this.resolveString($r('app.string.paper_postcard')); }
    if (this.paperKind === PaperKind.MEMO) { return this.resolveString($r('app.string.paper_memo')); }
    return this.resolveString($r('app.string.paper_letter'));
  }

  private cycleMachine(): void {
    const all: string[] = ['1920s-upright', '1930s-portable', '1950s-streamlined', '1960s-electric'];
    const idx: number = all.indexOf(this.machineKind as string);
    const next: MachineKind = all[(idx + 1) % all.length] as MachineKind;
    this.applyMachine(next);
  }

  private cyclePaper(): void {
    const all: string[] = ['letter', 'manuscript', 'postcard', 'memo'];
    const idx: number = all.indexOf(this.paperKind as string);
    const next: PaperKind = all[(idx + 1) % all.length] as PaperKind;
    appPreferences.setString(PrefKeys.PAPER, next as string);
    this.applyPaper(next, true);
  }

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
        // 第 6 批 F10：卷宗连纸一起删＝彻底删（remove() 已翻转为入回收站）
        docStore.removePermanently(all[i].id);
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

  // ===== 批 64（T2）：Stage26 的槽位注入 =====
  // 槽位 builder 必须单个根节点；组件内仍用各自既有的 sx/sy 换算，逐步改为 flex。
  /** topBarZone：顶栏（返回拨杆／边铃／出纸槽／铭牌／机身顶带）。 */
  @Builder
  stageTopBar() {
    TopZone26({
      machine: this.machineKind,
      // 批 64（N2）：顶区宽＝机器宽（右缘落在机器右缘内）
      widthVp: this.machineWidth26(),
      heightVp: this.t26y(104),
      sx: this.xk(), sy: this.yk(),
      docTitle: this.docTitle,
      soundOn: this.soundEnabled,
      guideEnabled: this.guideEnabled,
      achGlow: this.plateGlow,
      onBack: (): void => { this.leaveTyping(); },
      onBell: (): void => { this.toggleSound(); },
      onExportSlot: (): void => { this.onExportSlot(); },
      onPlate: (): void => { this.onPlateTap(); },
    })
      .id('p26_top_zone')
  }

  /** 批 64（T3）：纸区（纸／压纸杆／落字指针／横尺／色带）——纸区槽位内容。 */
  @Builder
  stagePaper() {
    Carriage26({
      machine: this.machineKind,
      machineWVp: this.machineWidth26(),
      // 批 70：顶栏高（纸视口据此上移到屏顶）
      topBarHVp: this.stageLayout26().topBarH,
      zoneHVp: this.stageLayout26().paperH,
      paperWVp: this.paperPanelWidthVp(),
      // 装纸/出纸动画：paperGrowVp 就是「可见纸高」（0 → 内容高），flex 下直接当纸高用，
      // 不再手算 y=362·sy−paperGrowVp 的位移（T3：PAPER_W／paperGrow 位移退役）
      paperHVp: this.paperGrowVp,
      sx: this.xk(), sy: this.yk(),
      offsetXVp: this.carriageOffsetVp,
      // 批 68：纸的滑动位移（任务 2）与换纸飞行位移（任务 4），均在 Carriage26 内叠加到 translate
      paperUserOffsetVp: this.paperUserOffsetVp,
      paperFlyVp: this.paperFlyVp,
      onPaperPanStart: (): void => { this.onPaperPanStart(); },
      onPaperPanUpdate: (dy: number): void => { this.onPaperPanUpdate(dy); },
      strikePhase: this.strikePhase,
      lines: this.docLineTexts(),
      fontSizeVp: this.fontSizeVp,
      lineHeightVp: this.lineHeightVp,
      // 批 62（任务 4）：自定义边距接上——未自定义时用现行等效默认值（左25/右30/上31），外观不变
      // 批 64（用户 2026-11-21）：边距是**版心留白**，不随屏幕放大（否则字距/边距一起涨，每行字数永远不变）
      marginLVp: this.customMarginH > 0 ? this.customMarginH : 25,
      marginRVp: this.customMarginH > 0 ? this.customMarginH : 30,
      marginTVp: (this.customMarginT > 0 ? this.customMarginT : 31) * this.yk(),
      fontFamily: this.genericFamilyFor(this.fontFamily),   // 批 54：字体条切换即改变纸面渲染
      textColor: this.inkColor,
      cursorXVp: this.cursorXVp26(),
      cursorYVp: this.paperCursorY26(),
      scrollYVp: this.paperScroll26(),
      textureRawfile: this.paperPanelTexture(),
      customPaperColor: this.customPaperColor,
      customTextureRawfile: this.customPaperTexture,
      ruledOn: this.customPaperRuled,
      docTitle: this.docTitle,
      contentOpacity: this.paperContentOpacity,
      pageNo: this.paperPageNo(),
    })
      .id('p35_carriage')
  }

  /** basketZone 槽位：Basket26。 */
  @Builder
  stageBasket() {
    Basket26({
      shiftLiftVp: this.shiftLiftVp,
      machine: this.machineKind,
      widthVp: 240 * this.xk(),
      // 批 67（任务 1）：井高＝字篮槽位高（同源）。原 this.t26y(138)=180.9vp 比槽位 145.7vp 高 35.2vp，
      // 井/扇整体下沉，上撞纸、下撞功能行。
      heightVp: this.stageLayout26().basketH,
      sx: this.xk(), sy: this.yk(),
      // 批 66：平板用 2.6 宽版扇图，盒高按图比例（手机仍 1.69 原图、盒高≈126）
      fanWide: this.isTablet,
      fanAspect: this.isTablet ? 2.6 : 1.69,
    })
      .id('p26_basket')
  }

  /** funcRowZone 槽位：FunctionCaps26。 */
  @Builder
  stageFuncRow() {
    FunctionCaps26({
      // 批 66：功能行按 kx 等比放大（六键 66.9×55.7、行 401×67），选项 B 的延续
      widthVp: 401,
      heightVp: 67,
      sx: this.xk(), sy: this.yk(),
      langLabel: this.langZh
        ? this.resolveString($r('app.string.keyboard_lang_zh'))
        : this.resolveString($r('app.string.keyboard_lang_en')),
      langActive: this.langZh,
      symbolActive: this.symbolMode,
      onLang: (): void => {
        this.langZh = !this.langZh;
        this.applyChineseMode(this.langZh);
        this.recalcTravel();
        this.paperAnimateNext = true;
        this.recalcPaperHeight();
      },
      onDelete: (): void => {
        if (this.isBuiltinCn() && this.pinyinSession !== null
          && this.pinyinSession.getBuffer().length > 0) {
          this.pinyinSession.backspace();
          this.audioService.playBackspace();
          this.audioService.vibrate();
          this.pinyinRefresh();
          return;
        }
        this.onDelete();
      },
      onNewline: (): void => {
        if (this.isBuiltinCn() && this.pinyinSession !== null
          && this.pinyinSession.getBuffer().length > 0) {
          const buf: string = this.pinyinSession.getBuffer();
          this.enqueueChinese(buf);
          this.pinyinSession.cancel();
          this.cnPinyin = '';
          this.cnPreview = '';
          this.candAll = [];
          this.candCurrent = [];
          return;
        }
        this.onNewline();
      },
      onPaper: (): void => { this.onPaperChange(); },
      onBackLine: (): void => { this.onBackLine(); },
      onSymbols: (): void => {
        this.symbolMode = !this.symbolMode;
        // 批 72：重建后的新键盘从 0.25 淡入到 1（140ms EaseOut）——「柔和浮现」而非硬闪
        this.keyboardFade = 0.25;
        this.getUIContext().animateTo({ duration: 140, curve: Curve.EaseOut }, () => {
          this.keyboardFade = 1;
        });
      },
    })
      .id('p26_function_caps')
  }

  /** fontBarZone 槽位：FontPlate26。 */
  @Builder
  stageFontBar() {
    FontPlate26({
      widthVp: 346.7 * this.xk(),
      heightVp: this.t26y(28),
      sx: this.xk(), sy: this.yk(),
      label: this.fontPlateLabel,
      onFont: (): void => { this.cycleFont(); },
    })
      .id('p26_font_plate')
  }

  /** candBarZone 槽位：CandStrip26。 */
  @Builder
  stageCandBar() {
    CandStrip26({
      machine: this.machineKind,
      widthVp: 346.7 * this.xk(),
      heightVp: this.t26y(44),
      sx: this.xk(), sy: this.yk(),
      candidates: this.langZh && this.pinyinReady ? this.candCurrent : [],
      pinyin: this.langZh && this.pinyinReady ? this.cnPinyin : '',
      onPick: (i: number): void => { this.pinyinPick(i); },
    })
      .id('p26_cand_strip')
  }

  /** keyZone 槽位：黑井＋键网格（井为底、键陷在井里；逐键 flex 属 T4 后半）。 */
  @Builder
  stageKeys() {
    Stack({ alignContent: Alignment.Top }) {
      KeyWell({
        machine: this.machineKind,
        widthVp: 346.7 * this.xk(),
        // 批 64（T4）：黑井高＝键盘井槽高（259.9vp），不再是写了 30 批的 keybedHeight（230.6）
        heightVp: this.stageLayout26().keyH,
      })
        .id('p33_key_well')

      KeyGrid({
        machineKind: this.machineKind,
        shiftActive: this.shiftActive,
        symbolMode: this.symbolMode,
        kbOpacity: this.keyboardFade,
        sx: this.xk(), sy: this.yk(),
        capsActive: this.capsLock,
        foldBand: this.layoutMode === 'desk',
        widthVp: this.machineWidth26(),
        heightVp: this.stageLayout26().keyH,
        layout: this.displayLayout(),
        overlayFontFamily: this.genericFamilyFor(this.fontFamily),
        overlayFontSize: 15,
        capShape: this.capShape(),
        labelColor: this.displayLayout().overlayColor,
        originXVp: 0,
        originYVp: 0,
        commitSeq: this.commitSeq,
        onCapDown: (cap: CapDef): void => { this.onCapDown(cap); },
        onCapSlide: (cap: CapDef): void => {
          if (!cap.isExtra && cap.label !== ' ') {
            this.audioService.playKey();
          }
        },
        onCapUp: (cap: CapDef): void => {
          if (cap.label === 'Shift') { this.shiftActive = false; }
        },
      })
        .id('p25_key_grid')

    }
    .width('100%')
    .height('100%')
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


      // 卷宗页（§5.1）：整页覆盖层，最后绘制、盖住主屏
      // §11 主页：冷启动首帧；从任何页返回也回这里
      // 主页常驻以便滑入时垫底；但栈顶是 typewriter 时必须让位（否则盖住打字机）
      if (this.navStack.indexOf('home') >= 0
        && this.navStack[this.navStack.length - 1] !== 'typewriter') {
        HomePage({
          widthVp: this.overlayWidthVp(),
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          // 第 13 批 ⑤：主页 hero 跟随当前启用机型
          machineKind: this.machineKind,
          guideEnabled: this.guideEnabled,
          statsRev: this.statsRev,
          onContinue: (): void => {
            const list = docStore.list();
            if (list.length > 0) {
              this.loadDocument(list[0].id);
              this.measureStage();
              this.recalcPaperHeight();
              this.pushPage('typewriter');
            }
          },
          onStartTyping: (): void => {
            // 新建一张空白纸并进入打字机
            // 第 12 批 ②：展开复制 meta 并重置 sheet 字段（不许直接改原 meta 对象，否则连旧文档内存 meta 一起改）
            // ArkTS 禁对象展开（arkts-no-spread），按字段逐个复制并重置 sheet 字段（语义等同展开复制，不改原对象）
            const srcMeta: DocMeta = this.docModel.toDocData().meta;
            const meta: DocMeta = {
              machine: srcMeta.machine, paper: srcMeta.paper, ribbon: srcMeta.ribbon,
              font: srcMeta.font, createdAt: srcMeta.createdAt, updatedAt: srcMeta.updatedAt,
              sheetNo: 1, sheetCount: 1,
            };
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
          widthVp: this.overlayWidthVp(),
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          docs: docStore.list(),
          onBack: (): void => { this.leaveTyping(); },
          onOpenDossier: (id: string): void => {
            this.openDossierId = id;
            hilog.info(DOMAIN, TAG, 'onOpenDossier id=%{public}s', id);
            this.pushPage('detail');
          },
        })
          .transition(TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut }))
      }

      // 卷宗内页（§5.2）
      // 换装页（§4）：换装即时生效（改状态后主屏下一帧即换装，不重建编辑器）
      if (this.customizeOpen) {
        CustomizePage({
          widthVp: this.overlayWidthVp(),
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          machineKind: this.machineKind as string,
          paperKind: this.paperKind as string,
          ribbonKind: this.ribbon as string,
          fontKind: this.fontKindOfCurrentMachine(),
          fontSize: CustomizeStore.fontSize(this.machineKind as string),
          machineFonts: this.machineFontsList(),
          failedFonts: this.fontLoadFailed,
          onOpenFontManager: (): void => { this.pushPage('fontmanager'); },
          onOpenPaperCustom: (): void => { this.pushPage('papercustom'); },
          onFontSize: (v: number): void => { this.applyFontSize(v); },
          animModes: this.animModes,
          onPickAnimMode: (machine: string, mode: string): void => { this.setAnimMode(machine, mode); },
          // 第 27 批（批 4）：标准件变体——只换 token、几何不动；换一件其余九件不动
          onPickPart: (part: string, value: string): void => {
            CustomizeStore.setPartVariant(part, this.machineKind as string, value);
            this.partsRev = this.partsRev + 1;
            hilog.info(DOMAIN, TAG, 'part variant part=%{public}s value=%{public}s machine=%{public}s',
              part, value, this.machineKind as string);
          },
          onBack: (): void => { this.leaveTyping(); },
          onPickMachine: (k: string): void => {
            this.applyMachine(k as MachineKind);
            hilog.info(DOMAIN, TAG, 'customize machine -> %{public}s', k);
          },
          onPickPaper: (k: string): void => {
            this.applyPaper(k as PaperKind, true);
            hilog.info(DOMAIN, TAG, 'customize paper -> %{public}s', k);
          },
          onPickRibbon: (k: string): void => {
            this.applyRibbon(k as RibbonKind, true);
            hilog.info(DOMAIN, TAG, 'customize ribbon -> %{public}s ink=%{public}s',
              k, this.inkColor);
          },
          onPickFont: (f: string): void => {
            // §4 换装即时生效：切换纸面字体（docModel + 渲染族名）
            for (let i = 0; i < FONTS.length; i++) {
              if ((FONTS[i].font as string) === f) {
                // 第 9 批 F5：换字体事件（A11）——换装页选字体与字体管理页「应用到当前机」两处都记
                statsService.recordEvent(StatsEvents.FONT_CHANGED);
                this.docModel.setFont(FONTS[i].font);
                this.fontFamily = FONTS[i].familyName;
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

      // 第 2 批 F3：换装子页（字体管理／纸张自定义）
      if (this.fontManagerOpen) {
        FontManagerPage({
          widthVp: this.overlayWidthVp(),
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          currentMachine: this.machineKind as string,
          onApplyFamily: (family: string): void => {
            // 第 9 批 F5：换字体事件（A11）
            statsService.recordEvent(StatsEvents.FONT_CHANGED);
            CustomizeStore.setFontFamily(this.machineKind as string, family);
            this.applyMachineFont(family);
            this.fontPrefsRev = this.fontPrefsRev + 1;
            hilog.info(DOMAIN, TAG, 'font applied machine=%{public}s family=%{public}s',
              this.machineKind as string, family);
          },
          onFontDeleted: (): void => { this.refreshFontAfterDelete(); },
          onBack: (): void => { this.leaveTyping(); },
        })
          .transition(TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut }))
      }
      if (this.paperCustomOpen) {
        PaperCustomPage({
          widthVp: this.overlayWidthVp(),
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          paperKind: this.paperKind as string,
          onBack: (): void => {
            this.refreshPaperCustom();
            this.recalcPaperHeight();
            this.popPage();
          },
        })
          .transition(TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut }))
      }

      // 收藏页（§3）：先渲染，详情页在其后渲染才能盖在它上面
      if (this.collectionOpen) {
        CollectionPage({
          widthVp: this.overlayWidthVp(),
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          currentMachine: this.machineKind as string,
          achieveRev: this.achieveRev,
          totalWords: statsService.totalWords(),
          streakDays: statsService.consecutiveDays(),
          onBack: (): void => { this.leaveTyping(); },
          onPick: (kind: string): void => { this.collectionDetailKind = kind; this.pushPage('collectiondetail'); },
        })
          .transition(TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut }))
      }

      // 收藏详情页（§3）：只对已解锁机器开放；必须排在收藏页之后（后者先绘制）
      if (this.collectionOpen && this.collectionDetailKind.length > 0) {
        CollectionDetailPage({
          widthVp: this.overlayWidthVp(),
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          machineKind: this.collectionDetailKind,
          totalWords: statsService.totalWords(),
          streakDays: statsService.consecutiveDays(),
          paperKindsUsed: statsService.paperKindsUsed(),
          onBack: (): void => { this.leaveTyping(); },
          onSetCurrent: (kind: string): void => {
            this.applyMachine(kind as MachineKind);
            // §10：手动关两个布尔量不够——栈里还留着 collection／collectiondetail，
            // 下次 pushPage('typewriter') 触发 syncFromStack() 会用 has() 重算 collectionOpen=true
            // 把收藏页重新盖回来。popTo('home') 截栈并重算，收藏页才真的退出。
            this.popTo('home');
            hilog.info(DOMAIN, TAG, 'collection setCurrent -> %{public}s', kind);
          },
        })
          .transition(TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut }))
      }


      // D1：汉堡下拉菜单（最上层）

      // §6.1 设置页（最后渲染，盖在其他覆盖层之上）
      // 第 16 批 2A：Canvas 静态主屏调试页（临时；2B 切主屏后删除）

      // ---- 第 25 批（23 号稿批 2）：五区 UI 件按设计序挂在 Canvas 之上（与 Canvas 兄弟级）----
      // 设计序：顶栏 → 纸区（纸面板＋横尺＋落字导件＋拨杆＋旋钮）→ 字篮区 → 功能行 → 字体条 → 键盘区。
      // z 序按 §3.1：机身面板 0 → 色带条/纸面板 1 → 横尺 2 → 落字导件 3 → 字篮 4 → 功能行 5 →
      // 键盘网格 6 → 拨杆/旋钮 7 。批 3 删 Canvas 挂载时这些件原地留下、不再重挂。
      if (this.navStack[this.navStack.length - 1] === 'typewriter') {
        // ===== 26 号稿（打字页面推倒重来）：整屏一台打字机，五区绝对定位（§6 y-map）=====
        // 层序：盖子 → 顶区 → 滚筒 → 纸 → 卷曲 → 字车正面 → 字篮 → 功能行／字体牌／候选条 → 黑井 → 键帽
        Lid26({
          machine: this.machineKind,
          widthVp: this.canvasWidthVp(),
          heightVp: this.canvasHeightVp(),
          sx: this.xk(), sy: this.yk(),
        })
          .id('p26_lid')

        // 机器顶部深色带（顶区底）
        TopDeck26({
          machine: this.machineKind,
          widthVp: this.canvasWidthVp(),
          heightVp: this.t26y(104),
          sx: this.xk(), sy: this.yk(),
        })
          .id('p26_top_deck')
          .position({ x: 0, y: 0 })


        // 批 64（T3）：纸区（纸／压纸杆／落字指针／横尺／色带）已整体搬进 Stage26 的 paperZone 槽位
        // （见 @Builder stagePaper）。本层不再挂绝对定位的 Carriage／色带／指针。


        // 批 64（T2 第一步）：舞台容器 Stage26 就位。顶栏进 topBarZone 槽位（Stage26 内作为覆盖层绘制，
        // 保持「顶栏压纸面/出纸槽」的现行 z 序）；其余七槽先留空——纸区/字篮井/功能行/字体条/候选栏/键盘井/底缘
        // 仍按旧绝对定位挂在 Stack 上，随后逐个搬进槽位。
        // availH 取 winHeightVp：与设计稿 §3.2 验收数字（418.7/207.8/259.8）同口径（§5.1 正文写的 availH=1006.3
        // 会算成 392.1/187.7/234.9），差异已在自检记账，未擅改。
        Stage26({
          availW: this.stageWidth,
          availH: this.winHeightVp > 0 ? this.winHeightVp : this.canvasHeightVp(),
          // 注意（本仓既有约定，见 AppDialog 的 content）：@BuilderParam 必须用箭头包一层调用父组件 @Builder，
          // 直接把 `this.stageTopBar` 交出去会让 builder 内的 this 指向子组件（Stage26），父组件方法全部取不到。
          topBarZone: (): void => { this.stageTopBar() },
          paperZone: (): void => { this.stagePaper() },
          basketZone: (): void => { this.stageBasket() },
          funcRowZone: (): void => { this.stageFuncRow() },
          fontBarZone: (): void => { this.stageFontBar() },
          candBarZone: (): void => { this.stageCandBar() },
          keyZone: (): void => { this.stageKeys() },
        })
          .id('p26_stage')
          // 批 64（T7／R5）：系统键盘弹起时整台机器上移，让候选栏停在键盘之上。
          // translate 不动布局（纸区高度不变）；纸顶／顶栏允许出屏，与 §3.3「纸顶可出屏」同口径。
          .translate({ y: -this.kbShift })
          .animation({ duration: 220, curve: Curve.EaseOut })



        // 出纸槽滑出副本（300ms，纸片从槽口向上 40vp 后淡出）
        if (this.slotFlyVisible) {
          Column()
            .width(46 * this.xk()).height(10 * this.yk())
            .linearGradient({
              direction: GradientDirection.Bottom,
              colors: [['#fbf6e8', 0.0], ['#eee4ce', 0.6], ['#cfc4ad', 1.0]],
            })
            .borderRadius(1)
            .border({ width: 1, color: '#8a7f6b' })
            .position({ x: 302 * this.xk() + this.machineOffsetX26(), y: 62 * this.yk() - 40 * this.yk() * this.slotFly })
            .opacity(1 - this.slotFly)
            .hitTestBehavior(HitTestMode.None)
        }

        // 批 64（T2）：字篮井已搬进 Stage26 的 basketZone 槽位（见 @Builder stageBasket）

        // 批 64（T2）：功能行六键已搬进 Stage26 的 funcRowZone 槽位（见 @Builder stageFuncRow）

        // 批 64（T2）：字体条已搬进 Stage26 的 fontBarZone 槽位（见 @Builder stageFontBar）

        // 批 64（T2）：候选栏已搬进 Stage26 的 candBarZone 槽位（见 @Builder stageCandBar）

        // 黑井（z 4.0，盖钢板；四角开孔露钢板螺丝）
        // 批 64（T2/T4）：黑井＋键网格已搬进 Stage26 的 keyZone 槽位（见 @Builder stageKeys）


        // 黄铜铭牌点按提示（文档名，1.6s 自动收起）
        if (this.plateHint) {
          Text(this.docTitle.length > 0 ? this.docTitle : '未命名')
            .fontSize(13).fontColor('#2a1f10').maxLines(1)
            .textAlign(TextAlign.Center)
            .width(140 * this.xk()).height(24 * this.yk())
            .backgroundColor('#d8b874')
            .border({ width: 1, color: '#6d5326' })
            .borderRadius(3)
            .position({ x: 150 * this.xk() + 62 * this.xk() + 8 * this.xk(), y: 16 * this.yk() })
            .hitTestBehavior(HitTestMode.None)
        }
      }

      if (this.settingsOpen) {
        SettingsPage({
          widthVp: this.overlayWidthVp(),
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          machineLabel: this.machineLabelText(),
          paperLabel: this.paperLabelText(),
          volume0to100: this.volume0to100,
          soundEnabled: this.soundEnabled,
          vibrationEnabled: this.vibrationEnabled,
          deleteMode: this.deleteMode,
          onToggleSound: (): void => { this.toggleSound(); },
          onToggleVibrate: (): void => { this.toggleVibrate(); },
          a11yEnabled: this.a11yOverlayEnabled,
          onToggleA11y: (): void => { this.a11yOverlayEnabled = !this.a11yOverlayEnabled; },
          onVolume: (v: number): void => { this.setVolume(v); },
          onDeleteMode: (mode: string): void => { this.setDeleteMode(mode); },
          onPickMachine: (): void => { this.cycleMachine(); },
          onPickPaper: (): void => { this.cyclePaper(); },
          onOpenTrash: (): void => { this.openTrash(); },
          dailyGoal: statsService.dailyGoal(),
          onGoal: (n: number): void => {
            statsService.setDailyGoal(n);
            this.statsRev = this.statsRev + 1;
          },
          cnEngine: this.cnEngine,
          onOpenPinyinSettings: (): void => {
            this.refreshPinyinMeta();
            this.pushPage('pinyinsettings');
            // 设置页要用引擎（加词／学习计数），先异步加载
            this.ensurePinyinEngine().then(() => {
              this.refreshPinyinMeta();
            });
          },
          onReplayPageGuide: (): void => { this.replayPageGuide(); },
          onReplayOnboarding: (): void => { this.replayOnboarding(); },
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
          onBack: (): void => { this.leaveTyping(); },
        })
          .transition(TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut }))
      }

      // 第 6 批 F10：回收站（排在设置页之后，保证盖在设置页上）
      if (this.trashOpen) {
        TrashPage({
          widthVp: this.overlayWidthVp(),
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          docs: this.trashDocs,
          onBack: (): void => { this.leaveTyping(); },
          onRestore: (id: string): void => { this.restoreTrash(id); },
          onPurge: (id: string): void => { this.purgeTrash(id); },
        })
          .transition(TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut }))
      }


      if (this.dossierOpen && this.detailOpen) {
        DossierDetailPage({
          widthVp: this.overlayWidthVp(),
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          dossierId: this.openDossierId,
          docs: this.listDocs(),
          deleteMode: this.deleteMode,
          onBack: (): void => { this.leaveTyping(); },
          onOpenPaper: (id: string): void => {
            // §5.2：点「打开」进打字页——栈退到 typewriter 层再载入
            this.loadDocument(id);
            this.popTo('typewriter');
          },
          onDeleteDossier: (mode: string): void => { this.deleteDossier(this.openDossierId, mode); },
          // 第 13 批 ⑥：页面 @Prop dossierId 实测可能为空（同 tick 压栈的旧值），以 Index 自己的 openDossierId 为准
          onExport: (dossierId: string): void => {
            this.onExportDossier(this.openDossierId.length > 0 ? this.openDossierId : dossierId);
          },
          onNewPaper: (): void => { this.newPaperInDossier(); },
          onRenamePaper: (id: string, name: string): void => { this.renameDocument(id, name); },
          onOpenDoc: (id: string): void => {
            this.openDocId = id;
            this.pushPage('docview');
          },
          onRenamed: (): void => {
            this.docsRev = this.docsRev + 1;
            hilog.info(DOMAIN, TAG, 'renamed rev=%{public}s (list will refresh)', this.docsRev.toString());
          },
          onDeletePaper: (id: string): void => { this.deletePaper(id); },
        })
          .transition(TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut }))
      }

      // 文档视图（§5.3）：必须排在卷宗内页之后，才能盖在内页之上
      if (this.dossierOpen && this.openDocId.length > 0) {
        DocumentViewPage({
          widthVp: this.overlayWidthVp(),
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          docId: this.openDocId,
          deleteMode: this.deleteMode,
          onBack: (): void => { this.leaveTyping(); },
          onExport: (docId: string): void => { this.onExportDoc(docId); },
          onEdit: (id: string): void => {
            // 点正文页进打字机：栈退到 typewriter 层
            this.loadDocument(id);
            this.popTo('typewriter');
          },
          onDelete: (id: string): void => {
            this.deletePaper(id);
            this.openDocId = '';
            // 删掉正在看的文档后回卷宗内页（避免停在空白文档视图）
            this.popPage();
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

      // §6.2 导出页（第 3 批：双按钮/进度/结果态；构建与分享在 ExportPage 内部）
      if (this.exportOpen) {
        ExportPage({
          widthVp: this.overlayWidthVp(),
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          docId: this.exportDocId.length > 0 ? this.exportDocId : this.docId,
          dossierId: this.exportDossierId,
          scope: this.exportScope,
          machineKind: this.machineKind as string,
          onBack: (): void => { this.leaveTyping(); },
          onBeforeExport: (scope: string, dossierId: string): boolean => {
            return this.prepareExport(scope, dossierId);
          },
          onSaved: (format: string): void => {
            this.lastExportFormat = format;
            statsService.recordEvent(StatsEvents.DOC_EXPORTED);
            // 第 9 批 F5：导出即边界——记完事件立刻判定一次（不等下一次保存）
            AchievementService.evaluate();
            hilog.info(DOMAIN, TAG, 'export saved format=%{public}s', format);
          },
          onShared: (format: string): void => {
            // 第 9 批 F5：分享单独计（A7/A8 用 doc_shared；此前与 doc_exported 共用会导致
            // 只保存不分享也触发分享成就）；记完立刻判定一次
            statsService.recordEvent(StatsEvents.DOC_SHARED);
            AchievementService.evaluate();
            hilog.info(DOMAIN, TAG, 'export shared format=%{public}s', format);
          },
          onBusyChange: (busy: boolean): void => { this.exportBusy = busy; },
        })
          .transition(TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut }))
      }

      if (this.pinyinSettingsOpen) {
        PinyinSettingsPage({
          widthVp: this.overlayWidthVp(),
          heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
          fuzzyOn: this.fuzzyOn,
          userWords: this.userWordsFlat,
          dictInfo: this.dictInfo,
          learnCount: this.learnCount,
          candidateCount: this.candPageSize,
          candidateSize: this.candChipFontSize,
          onCandidateCount: (n: number): void => {
            this.candPageSize = clampCandidateCount(n);
            appPreferences.setNumber(PrefKeys.CUSTOM_CANDIDATE_COUNT, this.candPageSize);
            this.pinyinShown();
          },
          onCandidateSize: (n: number): void => {
            this.candChipFontSize = clampCandidateSize(n);
            appPreferences.setNumber(PrefKeys.CUSTOM_CANDIDATE_SIZE, this.candChipFontSize);
          },
          onBack: (): void => { this.leaveTyping(); },
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

      // 第 13 批 ④：启动引导改为新全屏组件（GuideOverlay.ets 保留作回滚对照）
      OnboardingGuide({
        visible: this.onboardingVisible,
        page: $onboardingPage,
        onSkip: (): void => { this.closeOnboarding(); },
        onStart: (): void => { this.closeOnboarding(); },
      })
      // 第 10 批：页面引导改挂聚光灯浮层；启动引导已是全屏 OnboardingGuide（2C-5 修正过期注释）
      SpotlightOverlay({
        visible: this.guideVisible && !this.onboardingVisible,
        page: this.guidePage,
        steps: this.guideSteps,
        screenW: this.winWidthVp > 0 ? this.winWidthVp : this.stageWidth,
        screenH: this.winHeightVp > 0 ? this.winHeightVp : 720,
        creaseTop: this.creaseTopVp,
        creaseBottom: this.creaseBottomVp,
        keyboardTop: this.winHeightVp - this.keybedHeight - FUNCTION_ROW_HEIGHT_VP,
        onClose: (page: string): void => { this.closePageGuide(); },
      })
      // 第 9 批 F5：成就达成弹窗（挂在最上层；一次只弹一条，关掉再弹下一条）
      AppDialog({
        visible: this.achNoticeKind.length > 0,
        widthVp: this.overlayWidthVp(),
        heightVp: this.winHeightVp > 0 ? this.winHeightVp : 720,
        onClose: (): void => {
          AchievementService.dismiss();
          this.refreshAchieveNotice();
        },
        content: (): void => { this.achDialogBody() },
      })
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



