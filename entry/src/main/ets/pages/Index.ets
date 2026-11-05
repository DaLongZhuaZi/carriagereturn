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
import { hilog } from '@kit.PerformanceAnalysisKit';
import { resourceManager } from '@kit.LocalizationKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { CorrectionMode, MachineKind, PaperKind, RibbonKind } from '../model/DocModel';
import {
  CARRIAGE_PAPER_OVERLAP_VP, DEFAULT_FONT, DEFAULT_MACHINE, DEFAULT_PAPER, DEFAULT_RIBBON,
  FONT_BAR_HEIGHT_VP, FUNCTION_ROW_HEIGHT_VP, PAPER_TOP_GAP_VP, TOP_BAR_HEIGHT_VP,
  findFont, findMachine, findPaper, findRibbon, fontDisplayName,
} from '../model/MachineCatalog';
import { CapDef, KeymapLayout, KeymapParser, readRawTextSync } from '../model/KeymapModel';
import { PaperRow } from '../ui/PaperSheet';
import { DocModel } from '../model/DocModelCore';
import { docStore } from '../services/DocStore';
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
  @State strikeLineVp: number = 0;
  @State carriageTopVp: number = 0;
  /** 换行计数：驱动 LeverLayer 摆动。 */
  @State newlineTick: number = 0;
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
  @State correctionMode: CorrectionMode = CorrectionMode.MODERN;
  /** 1920s 分层字车是否可用（层文件缺失时回退旧 strip，不许空白/崩溃）。 */
  @State useLayers: boolean = false;
  /** 动态安全区（vp）：取不到时 topInset 回退 28、bottomInset 回退 0（§2.9）。 */
  @State topInset: number = 28;
  @State bottomInset: number = 0;

  aboutToAppear(): void {
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

      // 字号 = (可用宽 − 56) / 30，钳制 17–24
      let fs: number = (availW - 56) / 30;
      if (fs < 17) {
        fs = 17;
      }
      if (fs > 24) {
        fs = 24;
      }
      this.fontSizeVp = fs;
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
    const perLine: number = Math.floor(usable / (this.fontSizeVp * 0.6));
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
    const limit: number = -(this.stageWidth - 2 * 28);
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
    this.getUIContext().animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
      this.carriageOffsetVp = 0;
      this.joltYVp = 2;
    });
    this.getUIContext().animateTo({ duration: 60, delay: 200, curve: Curve.FastOutSlowIn }, () => {
      this.joltYVp = 0;
    });
    // 旋钮走纸期间累计转 21°/行，线性、不回零
    this.getUIContext().animateTo({ duration: 200, curve: Curve.Linear }, () => {
      this.knobAngle = this.knobAngle + 21;
    });
    void start;
  }

  // ---------------- 换装 ----------------

  private applyMachine(kind: MachineKind): void {
    this.machineKind = kind;
    this.docModel.setMachine(kind);
  }

  private applyPaper(kind: PaperKind): void {
    this.paperKind = kind;
    // 字号/行高由 measureStage 的公式统一决定（§2.6），换纸不再覆盖，避免公式被机器基数冲掉
    this.fontFamily = findFont(DEFAULT_FONT).familyName;
    this.docModel.setPaper(kind);
    this.recalcPaperHeight();
  }

  private applyRibbon(kind: RibbonKind): void {
    this.ribbon = kind;
    this.inkColor = findRibbon(kind).inkColor;
    this.docModel.setRibbon(kind);
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
    // f1a52f1 口径：y 一律相对总成 Stack 顶，不再减 bodyTop
    const H: number = this.availableHeightVp > 0 ? this.availableHeightVp : this.regionHeightVp;
    const rows: number = this.docModel.getLines().length;
    const step: number = 0.0283 * H;
    let top: number = 0.25 * H - (rows - 1) * step;
    if (top < 0.10 * H) {
      top = 0.10 * H;
    }
    this.carriageTopVp = 0.56 * H;
    this.paperTopVp = top;
    this.strikeLineVp = top + 0.03 * H + (rows - 1) * step;
    this.paperHeightVp = this.carriageTopVp - this.paperTopVp;
    // Pw 单源固定值（唯一写 Pw 的地方）
    this.paperWidthVp = 370;
    this.carriageHeight = this.paperWidthVp * 0.17;
    hilog.info(DOMAIN, TAG,
      'modelB rows=%{public}s top=%{public}s strike=%{public}s carr=%{public}s pw=%{public}s',
      rows.toString(), this.paperTopVp.toFixed(1), this.strikeLineVp.toFixed(1),
      this.carriageTopVp.toFixed(1), this.paperWidthVp.toFixed(1));
    return;
    const lineCount: number = this.docModel.getLines().length;
    const rawHeight: number = PAPER_INITIAL_HEIGHT_VP + (lineCount - 1) * this.lineHeightVp;
    if (rawHeight <= this.regionHeightVp) {
      this.paperHeightVp = rawHeight;
      this.creepOffsetVp = 0;
    } else {
      this.paperHeightVp = this.regionHeightVp;
      this.creepOffsetVp = -(rawHeight - this.regionHeightVp);
    }
  }

  private animatePaperHeight(): void {
    const lc: number = this.docModel.getLines().length;
    let target: number = PAPER_INITIAL_HEIGHT_VP + (lc - 1) * this.lineHeightVp;
    if (target > this.regionHeightVp) {
      target = this.regionHeightVp;
    }
    this.getUIContext().animateTo({ duration: GROW_DURATION_MS, curve: Curve.FastOutSlowIn }, () => {
      this.paperHeightVp = target;
    });
    return;
    const lineCount: number = this.docModel.getLines().length;
    const rawHeight: number = (this.isTablet ? this.regionHeightVp : PAPER_INITIAL_HEIGHT_VP) + (lineCount - 1) * this.lineHeightVp;
    const targetHeight: number = rawHeight <= this.regionHeightVp ? rawHeight : this.regionHeightVp;
    const targetCreep: number = rawHeight <= this.regionHeightVp ? 0 : -(rawHeight - this.regionHeightVp);
    this.getUIContext().animateTo({
      duration: GROW_DURATION_MS,
      curve: curves.springCurve(0, 1, 190, 22),
    }, () => {
      this.paperHeightVp = targetHeight;
      this.creepOffsetVp = targetCreep;
    });
  }

  // ---------------- 击打链 ----------------

  private charWidthVp(ch: string): number {
    const code: number = ch.length > 0 ? ch.charCodeAt(0) : 65;
    return code > 127 ? this.fontSizeVp : this.fontSizeVp * 0.6;
  }

  private currentLineWidthVp(): number {
    const cursor = this.docModel.getCursor();
    const line = this.docModel.getLines()[cursor.line];
    let w: number = 0;
    for (let i = 0; i < line.text.length; i++) {
      w += this.charWidthVp(line.text.charAt(i));
    }
    return w;
  }

  /** 行宽只认舞台宽（§2.5）。 */
  private charsPerLine(): number {
    // 可用行宽 = 纸宽 − 2×28vp（不用舞台宽）
    const usable: number = this.paperWidthVp - 2 * findPaper(this.paperKind).marginH;
    const n: number = Math.floor(usable / (this.fontSizeVp * 0.6));
    return n > 6 ? n : 6;
  }

  private onCapDown(cap: CapDef): void {
    if (cap.isExtra) {
      return;
    }
    if (cap.label === ' ') {
      this.audioService.playSpace();
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
      return;
    }
    // Down 只给高亮 + 震动；主击打音移到 onArrive（与落字、纸移动同帧）
    this.audioService.vibrate();
    this.queueChar(cap.label.toLowerCase());
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
    this.hintText = '';
    const outcome = this.docModel.insertText(ch, this.charsPerLine());
    this.syncRows();
    this.animateGuide();
    this.stepCarriageLeft();
    this.scheduleSave();
    if (outcome.marginBell) {
      this.audioService.playBell();
    }
    // 行满自动换行：同样走换行回位，不许让字车条停在行末位置开始下一行
    if (this.docModel.getCursor().offset >= this.charsPerLineNum) {
      this.onNewline();
    }
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
    const limit: number = -(this.stageWidth - 2 * findPaper(this.paperKind).marginH);
    let o: number = -w;
    if (o < limit) {
      o = limit;
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
    if (this.correctionMode === CorrectionMode.OVERWRITE) {
      const o2 = this.docModel.overwriteBack();
      if (o2.changed) {
        this.syncRows();
        this.animateGuide();
        this.stepCarriageRight();
      }
      return;
    }
    const o = this.docModel.backspace();
    if (o.changed) {
      this.syncRows();
      this.animateGuide();
      this.stepCarriageRight();
    }
  }

  private onNewline(): void {
    this.hintText = '';
    this.docModel.newline();
    this.syncRows();
    this.animatePaperHeight();
    this.audioService.playCarriageReset();
    this.audioService.vibrate();
    this.scheduleSave();
    this.resetCarriageAndGuide();
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
        TopBar({ title: this.docTitle, heightVp: this.topBarHeight })

        Column() {
          Column().width('100%').height(this.paperTopGap)

          Stack({ alignContent: Alignment.TopStart }) {
            // ---- 字杆层（1920s）：zIndex 置顶，渲染在 PaperStage 之上；所在 Stack 不 clip 杆区 ----
            if (this.machineKind === MachineKind.UPRIGHT_1920S) {
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
                offsetYVp: 0.885 * this.stageWidth - this.carriageHeight / 2
                  - findPaper(this.paperKind).marginBottom - this.lineHeightVp / 2,
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
                paperWidthVp: this.paperWidthVp,
                paperLeftVp: (this.stageWidth - this.paperWidthVp) / 2 + this.carriageOffsetVp,
                strikeXVp: (this.stageWidth - this.paperWidthVp) / 2 + this.carriageOffsetVp
                  + findPaper(this.paperKind).marginH + this.currentLineWidthVp(),
                canvasOffsetVp: this.carriageOffsetVp,
                strikeYVp: 0,
              })
                // 滚筒顶 y = Ht − Hc（实测 Ht），与金属件同一锚点
                .offset({ y: this.carriageTopVp })
                .zIndex(1)
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
                  strikeXVp: (this.stageWidth - this.paperWidthVp) / 2 + this.carriageOffsetVp
                    + findPaper(this.paperKind).marginH + this.currentLineWidthVp(),
                  canvasOffsetVp: this.carriageOffsetVp,
                    strikeYVp: this.strikeLineVp - this.carriageTopVp,
                })
                  // 金属组件顶 y = Ht − Hc（滚筒顶），用实测 Ht
                  .offset({ y: this.carriageTopVp })

                // 拨杆：支点 = 车条右端 + O，支点 y = Hc/2（滚筒中心相对金属顶）
                LeverLayer({
                  layerSizeVp: this.carriageHeight * 2.5 * 0.212,
                  newlineTick: this.newlineTick,
                  // 拨杆支点 x = 纸屏左 + Pw − 层宽/2
                  offsetXVp: (this.stageWidth - this.paperWidthVp) / 2 + this.carriageOffsetVp
                    + this.paperWidthVp - this.carriageHeight * 2.5 * 0.212 / 2,
                  offsetYVp: this.carriageHeight / 2 - (this.stageWidth * 0.16 / (536 / 2522)) * 0.952,
                  onSwingStart: (): void => {
                    this.audioService.playCarriageReset();
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
                creepOffsetVp: this.creepOffsetVp,
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
                offsetXVp: this.carriageOffsetVp,
                cursorXVp: findPaper(this.paperKind).marginH + this.currentLineWidthVp(),
                cursorYVp: this.strikeLineVp - this.paperTopVp - this.lineHeightVp,
                cursorVisible: true,
                // 字杆层与拨杆层在纸之上渲染（E 项）

              })
                .width('100%')

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

            .width(this.paperWidthVp)
            .height(this.paperHeightVp)
            .offset({ x: (this.stageWidth - this.paperWidthVp) / 2, y: this.paperTopVp })
          }
          .width('100%')
          .height(this.availableHeightVp)
          .clip(false)
          .onAreaChange((oldA: Area, newA: Area) => {
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

        FontBar({
          fontFamily: this.fontFamily,
          fontLabel: fontDisplayName(DEFAULT_FONT),
          heightVp: this.fontBarHeight,
        })

        PhotoKeybed({
          machineKind: this.machineKind,
          foldBand: false,
          widthVp: this.photoW(),
          heightVp: this.keybedHeight,
          layout: this.keymapLayout,
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
          },
        })

        FunctionRow({
          heightVp: this.functionRowHeight,
          langLabel: this.langZh
            ? this.resolveString($r('app.string.keyboard_lang_zh'))
            : this.resolveString($r('app.string.keyboard_lang_en')),
          deleteLabel: this.resolveString($r('app.string.keyboard_delete')),
          newlineLabel: this.resolveString($r('app.string.keyboard_newline')),
          onLang: (): void => {
            this.langZh = !this.langZh;
            // 语言切换同步改行高与纸高（中文 fs×30/17、英文 fs×28/17）
            this.lineHeightVp = this.langZh ? this.fontSizeVp * (30 / 17) : this.fontSizeVp * (28 / 17);
            this.recalcPaperHeight();
          },
          onDelete: (): void => {
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