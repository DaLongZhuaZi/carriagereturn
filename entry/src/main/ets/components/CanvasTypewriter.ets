/**
 * 第 16 批 2A：Canvas 打字机主屏（骨架＋静态层）
 *
 * 设计依据：docs/designs/16-Canvas实施设计-增量设计.md §2.1／§3／§4。
 * 2A 范围：Canvas 盒子＋变换矩阵＋分层（L0 底色／L1 静态层／L2 纸层／L3 骨架），
 * 静态整机（滚筒、底座、压纸卷、中央件、拨杆、键带、功能行、字体条）＋纸面静态文字；
 * TopBar 保留 ArkUI 叠加并按变换矩阵定位；IME 锚点透明层挂载（不接事件）。
 *
 * 坐标口径：本组件按当前 Index stage 布局取值（stageWidth=窗口宽，stageHeight=窗口高），
 * 绘制坐标与 Index 现行 @State 几何同源；纯几何公式见 model/CanvasGeometry.ets。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { Animator, AnimatorOptions, AnimatorResult } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { MachineKind, PaperKind } from '../model/DocModel';
import { findMachine, findPaper, MachineSpec, PaperSpec, TOP_BAR_HEIGHT_VP, PAPER_TOP_GAP_VP,
  FONT_BAR_HEIGHT_VP, FUNCTION_ROW_HEIGHT_VP } from '../model/MachineCatalog';
import { KeymapParser, KeymapLayout, CapDef } from '../model/KeymapModel';
import { CanvasTransform, computeTransform, referenceMetrics } from '../model/CanvasGeometry';
import { restDegFor, swingDegFor, dragRatioFor } from '../model/LeverAngleCore';
import { TopBar } from './TopBar';

const CDOMAIN: number = 0x0100;
const CTAG: string = 'CanvasTypewriter';

/** 参考机坐标常量（本组件内部以 stage 坐标为绘制单位）。 */
const KEYBAND_ASPECT: number = 2048 / 975;

interface CanvasLayoutInner {
  w: number;
  h: number;
  top: number;
  bottom: number;
  stackTop: number;
  paperX: number;
  paperY: number;
  carrAbs: number;
}

@Component
export struct CanvasTypewriter {
  @Prop widthVp: number = 362.7;
  @Prop heightVp: number = 822.5;
  @Prop topInset: number = 0;
  @Prop bottomInset: number = 0;
  @Prop isTablet: boolean = false;
  @Prop @Watch('onMachineKindChanged') machineKind: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop @Watch('onPaperKindChanged') paperKind: PaperKind = PaperKind.LETTER;
  @Prop docTitle: string = '未命名';
  @Prop guideEnabled: boolean = true;
  // Index 现行几何（2A 保持与 ArkUI 主屏同源；2B 切主屏后仍由 Index 传入）
  @Prop paperWidthVp: number = 264.1;
  @Prop paperHeightVp: number = 373.5;
  @Prop carriageTopVp: number = 300.0;
  @Prop carriageHeightVp: number = 44.9;
  @Prop strikeLineVp: number = 270.0;
  @Prop fontSizeVp: number = 17;
  @Prop lineHeightVp: number = 30;
  @Prop marginHVp: number = 48;
  @Prop marginTVp: number = 24;
  @Prop marginBVp: number = 20;
  @Prop pageNo: number = 1;
  @Prop pageCount: number = 1;
  @Prop hintText: string = '';
  @Prop @Watch('onDocChanged') lines: string[] = [''];
  @Prop @Watch('onDocChanged') paperTopVp: number = 206;
  @Prop @Watch('onDocChanged') paperContainerVp: number = 96;
  /** 换纸/纸容器尺寸剧变后触发一次完整重绘，清掉裁剪区外的旧纸像素。 */
  @Prop @Watch('onPaperReset') paperResetTick: number = 0;
  @Prop @Watch('onDocChanged') cursorXVp: number = 48;
  @Prop @Watch('onDocChanged') cursorYVp: number = 0;
  /** 落字纸面/inк jolt（vp，由 Index 的 1–2vp 回弹驱动）。 */
  @Prop @Watch('onJoltChanged') joltYVp: number = 0;
  /** 字车横向步进（vp，负=向左）；只移动前层与拨杆，底座/键床保持固定。 */
  @Prop @Watch('onCarriageChanged') carriageOffsetVp: number = 0;
  /** 批 20：拱的唯一渲染源是本组件的帧时钟；Index 只发「换行/退行/换纸」的目标 tick。 */
  @Prop @Watch('onArchTickChanged') canvasArchTick: number = 0;
  @Prop canvasArchTargetVp: number = 0;
  @Prop canvasArchDurMs: number = 90;
  @Prop @Watch('onCanvasStrikeTickChanged') canvasStrikeTick: number = 0;
  @Prop canvasEnabled: boolean = false;
  @Prop @Watch('onDeleteTickChanged') canvasDeleteTick: number = 0;
  @Prop canvasDeleteTargetVp: number = 0;
  /**
   * 批 2 拨杆直驱（§7）：角度归 Canvas、逻辑归 Index。
   * `leverHDragVp` 是 Index 的 leverHForDrag()（含手机「尖端不出屏」钳制）——两侧必须用同一个杆长，
   * 否则 Canvas 渲染的角与 Index 的过半判定会分叉。
   */
  @Prop leverHDragVp: number = 69.5;
  /** 释放 tick：Index 判定完过半后递增；Canvas 下一帧按 canvasLeverReleaseCommit 播提交/回弹。 */
  @Prop @Watch('onLeverReleaseTickChanged') canvasLeverReleaseTick: number = 0;
  @Prop canvasLeverReleaseCommit: boolean = false;
  @Prop @Watch('onNewlineTickChanged') canvasNewlineTick: number = 0;
  @Prop canvasNewlineCarriageTargetVp: number = 0;
  @Prop @Watch('onBackTickChanged') canvasBackTick: number = 0;
  @Prop canvasBackTargetVp: number = 0;
  /**
   * 纸段 tick（§2.4：换纸 canvasPaperTick）——纸层动画的唯一触发通道。
   * 换行纸上滑（Index 在 t=150 发）、退行纸飞（t=0 发）、换纸两段（t=0 / t=300 各发一次）共用：
   * 纸的目标在**发 tick 时**已由 Index 算好并写进 canvasPaperTopTargetVp／BoxTargetVp，
   * Canvas 不自己猜目标（旧写法在 tick 时读 paperTopVp 会读到滞后值，是纸上滑不动的根因）。
   */
  @Prop @Watch('onPaperTickChanged') canvasPaperTick: number = 0;
  /** 纸段模式：0=从当前渲染值起；1=同 0 且纸盒立即取目标（换纸第 1 段）；2=从下面两个显式 from 起（换纸第 2 段）。 */
  @Prop canvasPaperMode: number = 0;
  @Prop canvasPaperFromTopVp: number = 206;
  @Prop canvasPaperFromBoxVp: number = 96;
  @Prop canvasPaperTopTargetVp: number = 206;
  @Prop canvasPaperBoxTargetVp: number = 96;
  @Prop canvasPaperDurMs: number = 300;
  /** §2.5 一次性初值同步：Canvas 在 aboutToAppear／切机／切纸各读一次，之后不参与逐帧。 */
  @Prop initialCarriageOffsetVp: number = 0;
  @Prop initialArchXVp: number = -1;
  @Prop initialPaperTopVp: number = 206;
  @Prop initialPaperContainerVp: number = 96;
  @Prop @Watch('onClockActiveChanged') clockActive: boolean = true;
  onStrikeArrive: () => void = (): void => {};
  @Prop keybedHeightVp: number = 172.7;
  @Prop functionRowHeightVp: number = 52;
  @Prop fontBarHeightVp: number = 38;
  @Prop candBarHeightVp: number = 44;
  @Prop langLabel: string = 'EN';
  @Prop deleteLabel: string = '删除';
  @Prop newlineLabel: string = '换行';
  @Prop paperLabel: string = '换纸';
  @Prop backLineLabel: string = '退行';
  @Prop charLabel: string = '字符';
  @Prop fontFamily: string = 'CourierPrime';
  @Prop fontLabel: string = 'Courier Prime';
  @Prop inkColor: string = '#1a1a1a';
  /** 2C-2：无障碍透明原生按钮覆盖层（设置项 a11y.overlay.enabled，缺省 false）。 */
  @Prop a11yEnabled: boolean = false;
  onOpenHome: () => void = (): void => {};
  onOpenMenu: () => void = (): void => {};
  // 2B 交互：键帽 Down/Up、拨杆三阶段
  onCapDown: (cap: CapDef) => void = (_cap: CapDef): void => {};
  onCapUp: (cap: CapDef) => void = (_cap: CapDef): void => {};
  onLeverStart: (x: number) => void = (_x: number): void => {};
  onLeverUpdate: (dy: number) => void = (_dy: number): void => {};
  onLeverEnd: () => void = (): void => {};
  onFunctionKey: (key: string) => void = (_key: string): void => {};
  @Prop @Watch('onCandidatesChanged') candidates: string[] = [];
  onCandidatePick: (index: number) => void = (_index: number): void => {};
  onCandidateLong: (index: number) => void = (_index: number): void => {};

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  /**
   * 18 号稿 Phase 1 B2：下层静态 Canvas。背景渐变＋机身＋键带＋功能行＋字体条**只画一次**；
   * 上层字车 Canvas 每帧只画动层（滚筒/纸/拱/压纸卷/支架/拨杆/字杆/文字），不再每帧 blit 全屏背景。
   * Phase 0 E4 已证「成本与目标 clip 面积无关、只与被 blit 的源位图有关」，故两层都用全屏尺寸（不做带高，避免几何风险）。
   */
  private ctxStatic: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private staticReady: boolean = false;
  private ready: boolean = false;
  private machineLayer: ImageBitmap | null = null;
  private bailLayer: ImageBitmap | null = null;
  private bracketLayer: ImageBitmap | null = null;
  private bailY: number = 0;
  private bracketX0: number = 0;
  private bracketY0: number = 0;
  private bracketW: number = 60;
  private bracketH: number = 26;
  private paperLayer: ImageBitmap | null = null;
  private backgroundLayer: ImageBitmap | null = null;
  @State keymap: KeymapLayout = {
    machine: '', caps: [], spaceXMin: 0, spaceXMax: 0, spaceYMin: 0, spaceYMax: 0,
    hitRadius: 10, spaceR: 8, overlayColor: '#312b24', overlayFontSize: 14,
    widthVp: 0, heightVp: 0,
  };
  private imgRoller: image.PixelMap | null = null;
  private imgBase: image.PixelMap | null = null;
  private imgBail: image.PixelMap | null = null;
  private imgCentral: image.PixelMap | null = null;
  private imgBracket: image.PixelMap | null = null;
  private imgLever: image.PixelMap | null = null;
  private imgTypebar: image.PixelMap | null = null;
  private imgKeyband: image.PixelMap | null = null;
  private imgPaper: image.PixelMap | null = null;
  private machineBuildCount: number = 0;
  private paperBuildCount: number = 0;
  /** §0：滚筒明暗渐变缓存（几何不变就复用，避免每帧 createLinearGradient 造成 GPU 侧膨胀）。 */
  private rollerShade: CanvasGradient | null = null;
  private rollerShadeKey: string = '';
  private heldCaps: Map<number, CapDef> = new Map<number, CapDef>();
  private candScroll: number = 0;
  private candDragX: number = -1;
  private candDragOrigin: number = 0;
  private candDragged: boolean = false;
  private leverActive: boolean = false;
  private leverStartY: number = 0;
  private candidateDownIndex: number = -1;
  private candidateDownTime: number = 0;
  @State typebarAngle: number = 55;
  private strikePending: number = 0;
  private strikeBusy: boolean = false;
  private lastCanvasStrikeTick: number = 0;
  /** §17 帧时钟：单一常驻 Animator；now = onFrame 的 value（流逝毫秒）。 */
  private frameClock: AnimatorResult | null = null;
  private frameNow: number = 0;
  private frameSeq: number = 0;
  private frameLastLogMs: number = 0;
  private strikeWait: boolean = false;
  private strikeT0: number = 0;
  private strikeJolt: number = 0;
  private renderArchX: number = -1;
  private archFromX: number = 0;
  private archToX: number = 0;
  private archT0: number = 0;
  private archActive: boolean = false;
  /** 批 20：本段时长（打击 90／换行退行 200／换纸 300，由 Index tick 或打击给）。 */
  private archDur: number = 90;
  /** 下一段用的时长（Index tick 给的时长在下一段起段时消费）。 */
  private archDurNext: number = 90;
  private pendingArch: boolean = false;
  private lastArchTick: number = 0;
  private renderO: number = 0;
  private oActive: boolean = false;
  private oFrom: number = 0;
  private oTo: number = 0;
  private oT0: number = 0;
  private pendingOAfterLand: boolean = false;
  private oDur: number = 30;
  private oSpring: boolean = false;
  private lastDeleteTick: number = 0;
  private renderPaperTop: number = -1;
  private renderPaperContainer: number = -1;
  /** 纸段动画：换行纸上滑／换纸两段／退行纸飞共用一条插值通道，各自 t0 由 tick 给出。 */
  private paperActive: boolean = false;
  private paperT0: number = 0;
  private paperFromTop: number = 0;
  private paperToTop: number = 0;
  private paperFromBox: number = 0;
  private paperToBox: number = 0;
  private paperDur: number = 300;
  private paperSnapBox: boolean = false;
  private lastPaperTick: number = 0;
  /** §2.7 去重：文档变化只失效纸层，上屏交给帧时钟下一帧 draw()。 */
  private paperDirty: boolean = false;
  private newlineOActive: boolean = false;
  private newlineOFrom: number = 0;
  private newlineOTo: number = 0;
  private newlineOT0: number = 0;
  private newlineOJoltStarted: boolean = false;
  private nlJolt: number = 0;
  private nlJoltT0: number = 0;
  private nlJoltActive: boolean = false;
  private lastNewlineTick: number = 0;
  private lastBackTick: number = 0;
  /**
   * ArkUI 的 @Prop @Watch 是**逐 prop** 同步的：tick 的 watch 可能先跑，
   * 此时同批写入的目标 prop 还是旧值（实测 paper1 被读成旧目标 206/96）。
   * 定死口径：watch 里只登记「待启动」，下一帧 onframe 统一读目标并起段——
   * 那时整批 prop 一定已经同步完（延迟 ≤1 帧，在启动预算内）。
   */
  private pendingStrike: boolean = false;
  private pendingDelete: boolean = false;
  private pendingBack: boolean = false;
  private pendingNewline: boolean = false;
  private pendingPaper: boolean = false;
  private pendingLeverRelease: boolean = false;
  /** 批 2：拨杆渲染比例（Canvas 内部，不经过 @State/@Prop）；拖拽 Move 直接写，帧时钟每帧画。 */
  private renderLeverRatio: number = 0;
  private lastLeverReleaseTick: number = 0;
  private leverAnimActive: boolean = false;
  private leverAnimFrom: number = 0;
  private leverAnimTo: number = 0;
  private leverAnimT0: number = 0;
  private leverAnimDur: number = 150;
  /** 0=提交（摆到满摆）1=回程（满摆回静止）2=回弹（拖拽未过半回静止） */
  private leverAnimPhase: number = 2;
  /** 跟手打点：最近一次 Move 的墙钟时间与序号。 */
  private leverMoveWall: number = 0;
  private leverMoveCount: number = 0;
  /**
   * 拨杆拖拽期间只在「有 Move 的那一帧」上屏（§7 的 ≤1 帧语义不变：Move 后第一帧就画），
   * 空帧不画——逐帧全屏重绘在真机上会打爆 GPU 预算（实测 RENDER_MEMORY_OVER_ERROR: gpu≈2.156GB）。
   */
  private leverDirty: boolean = false;
  private frameLastValue: number = 0;
  /** 批 20 帧率取证：当前绘制所属动画种类标签。 */
  private drawKindTag: string = 'idle';
  /**
   * Phase 2 前置：文字独立上层 Canvas。拱/纸/拨杆转原生 transform 后必然压在字车 Canvas 之上，
   * 只有把文字再抬到它们之上，才保得住「纸 → 拱 → 压纸卷 → 文字」的原 z 序（批 21 实拍验证过被遮）。
   */
  private ctxText: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private textReady: boolean = false;
  /** §8 启动延迟打点：tick 到来时记 kind＋t0，紧随的那一帧记 first frame。 */
  private firstKind: string = '';
  private firstT0: number = 0;
  private firstLogged: boolean = true;

  /** 退行触发（§2.6）：O 250ms＋纸 300ms 各一条通道，均由下一帧启动。 */
  onBackTickChanged(): void {
    if (this.canvasBackTick === this.lastBackTick) { return; }
    this.lastBackTick = this.canvasBackTick;
    this.pendingBack = true;
  }
  /** 换行触发：O 回位在 t0+450ms 起 250ms；纸上滑由纸段 tick 在 150ms 给 t0。 */
  onNewlineTickChanged(): void {
    if (this.canvasNewlineTick === this.lastNewlineTick) { return; }
    this.lastNewlineTick = this.canvasNewlineTick;
    this.pendingNewline = true;
  }
  /** 纸段触发（换行纸上滑／换纸两段／退行纸飞共用）。 */
  onPaperTickChanged(): void {
    if (this.canvasPaperTick === this.lastPaperTick) { return; }
    this.lastPaperTick = this.canvasPaperTick;
    this.pendingPaper = true;
  }
  onDeleteTickChanged(): void {
    if (this.canvasDeleteTick === this.lastDeleteTick) { return; }
    this.lastDeleteTick = this.canvasDeleteTick;
    this.pendingDelete = true;
  }

  /** 批 2：松手——判定归 Index，这里只登记；下一帧按判定结果播提交/回弹（§7）。 */
  onLeverReleaseTickChanged(): void {
    if (this.canvasLeverReleaseTick === this.lastLeverReleaseTick) { return; }
    this.lastLeverReleaseTick = this.canvasLeverReleaseTick;
    this.pendingLeverRelease = true;
  }

  /**
   * 释放动画（§7）：过半＝200ms 摆到满摆（再 200ms 回程回静止，对应 16 号稿 §3.3 去程/回程）；
   * 不到半＝150ms 回弹回静止角（对应「拖拽回 0 时 150ms」）。各段用各自的 t0。
   */
  private startLeverRelease(): void {
    this.leverAnimFrom = this.renderLeverRatio;
    if (this.canvasLeverReleaseCommit) {
      this.leverAnimTo = 1;
      this.leverAnimDur = 200;
      this.leverAnimPhase = 0;
    } else {
      this.leverAnimTo = 0;
      this.leverAnimDur = 150;
      this.leverAnimPhase = 2;
    }
    this.leverAnimT0 = this.frameNow;
    this.leverAnimActive = true;
    this.drawKindTag = 'lever';
    hilog.info(CDOMAIN, CTAG, 'anim start lever phase=%{public}d from=%{public}s to=%{public}s dur=%{public}d wall=%{public}s',
      this.leverAnimPhase, this.leverAnimFrom.toFixed(3), this.leverAnimTo.toFixed(3),
      this.leverAnimDur, Date.now().toString());
  }

  /** 退行·O：250ms（§2.6 退行·O）。 */
  private startBackO(): void {
    this.syncRenderPaperOnce();
    this.oFrom = this.renderO;
    this.oTo = this.canvasBackTargetVp;
    this.oT0 = this.frameNow;
    this.oDur = 250;
    this.oSpring = false;
    this.oActive = true;
    this.drawKindTag = 'back';
    this.markFirstFrame('back');
    hilog.info(CDOMAIN, CTAG, 'anim start back O t0=%{public}s target=%{public}s wall=%{public}s',
      this.frameNow.toFixed(1), this.oTo.toFixed(2), Date.now().toString());
  }

  /** 换行·O 回位：t0+450ms 起 250ms，复位 jolt 峰值 2vp 与回位同起点（§2.6）。 */
  private startNewlineO(): void {
    this.syncRenderPaperOnce();
    this.newlineOFrom = this.renderO;
    this.newlineOTo = this.canvasNewlineCarriageTargetVp;
    this.newlineOActive = true;
    this.newlineOT0 = this.frameNow;
    this.newlineOJoltStarted = false;
    this.nlJoltActive = false;
    this.nlJolt = 0;
    this.drawKindTag = 'newline';
    this.markFirstFrame('newline');
    hilog.info(CDOMAIN, CTAG, 'anim start newline O t0=%{public}s target=%{public}s wall=%{public}s',
      this.frameNow.toFixed(1), this.newlineOTo.toFixed(2), Date.now().toString());
  }

  /** 纸段：目标由 Index 在发 tick 前算好；dur<=0 为瞬时落位（布局重算等）。 */
  private startPaperSegment(): void {
    this.syncRenderPaperOnce();
    const mode: number = this.canvasPaperMode;
    if (mode === 2) {
      this.renderPaperTop = this.canvasPaperFromTopVp;
      this.renderPaperContainer = this.canvasPaperFromBoxVp;
    }
    this.paperFromTop = this.renderPaperTop;
    this.paperFromBox = this.renderPaperContainer;
    this.paperToTop = this.canvasPaperTopTargetVp;
    this.paperToBox = this.canvasPaperBoxTargetVp;
    this.paperSnapBox = mode === 1;
    if (this.paperSnapBox) { this.paperFromBox = this.paperToBox; }
    this.paperDur = this.canvasPaperDurMs > 1 ? this.canvasPaperDurMs : 0;
    this.paperT0 = this.frameNow;
    if (this.paperDur <= 0) {
      if (this.paperActive) {
        // 布局重算的瞬时 tick 撞上正在播的纸段：以在播动画的目标为准，不许把它拍回去。
        hilog.info(CDOMAIN, CTAG, 'paper instant skipped (active) t=%{public}s', this.frameNow.toFixed(1));
        return;
      }
      this.renderPaperTop = this.paperToTop;
      this.renderPaperContainer = this.paperToBox;
      this.paperActive = false;
      this.paperDirty = true;
      hilog.info(CDOMAIN, CTAG, 'paper instant t=%{public}s top=%{public}s box=%{public}s wall=%{public}s',
        this.frameNow.toFixed(1), this.renderPaperTop.toFixed(1), this.renderPaperContainer.toFixed(1),
        Date.now().toString());
      if (!this.frameActive()) { this.draw(); }
      return;
    }
    this.paperActive = true;
    this.paperDirty = true;
    this.drawKindTag = 'paper';
    this.markFirstFrame('paper');
    hilog.info(CDOMAIN, CTAG,
      'anim start paper t0=%{public}s mode=%{public}d from=%{public}s/%{public}s to=%{public}s/%{public}s dur=%{public}d wall=%{public}s',
      this.frameNow.toFixed(1), mode, this.paperFromTop.toFixed(1), this.paperFromBox.toFixed(1),
      this.paperToTop.toFixed(1), this.paperToBox.toFixed(1), this.paperDur, Date.now().toString());
  }

  /** 删除·O 弹簧：70ms（§2.6，springCurve(0,1,260,20) 的三次缓动近似同现行）。 */
  private startDeleteO(): void {
    this.syncRenderPaperOnce();
    this.oFrom = this.renderO;
    this.oTo = this.canvasDeleteTargetVp;
    this.oT0 = this.frameNow;
    this.oDur = 70;
    this.oSpring = true;
    this.oActive = true;
    this.drawKindTag = 'delete';
    this.markFirstFrame('delete');
    hilog.info(CDOMAIN, CTAG, 'anim start delete O t0=%{public}s target=%{public}s wall=%{public}s',
      this.frameNow.toFixed(1), this.oTo.toFixed(2), Date.now().toString());
  }

  /** §2.5：内部渲染字段只在「还没同步过」时取一次初值（-1 是未初始化哨兵）。 */
  private syncRenderPaperOnce(): void {
    if (this.renderPaperTop < 0) { this.renderPaperTop = this.initialPaperTopVp; }
    if (this.renderPaperContainer < 0) { this.renderPaperContainer = this.initialPaperContainerVp; }
  }

  /** §2.5 初值同步：aboutToAppear／切机／切纸各读一次，之后不再参与逐帧。 */
  private applyInitialSync(): void {
    this.renderO = this.initialCarriageOffsetVp;
    this.renderArchX = this.initialArchXVp > 0 ? this.initialArchXVp : -1;
    this.renderPaperTop = this.initialPaperTopVp;
    this.renderPaperContainer = this.initialPaperContainerVp;
    hilog.info(CDOMAIN, CTAG,
      'initial sync O=%{public}s arch=%{public}s paperTop=%{public}s box=%{public}s',
      this.renderO.toFixed(2), this.renderArchX.toFixed(2),
      this.renderPaperTop.toFixed(1), this.renderPaperContainer.toFixed(1));
  }

  /** §8 启动预算：记下本次触发的 t0，紧随的那一帧写 first frame。 */
  private markFirstFrame(kind: string): void {
    this.firstKind = kind;
    this.firstT0 = this.frameNow;
    this.firstLogged = false;
  }

  /** 是否有活动动画或拨杆拖拽（§2.2 空闲规则／§2.7 去重的唯一判据）。 */
  private frameActive(): boolean {
    return this.strikeWait || this.archActive || this.oActive || this.paperActive
      || this.newlineOActive || this.nlJoltActive || this.leverActive || this.leverAnimActive;
  }
  onCarriageChanged(): void {
    if (this.oActive) { return; }
    if (this.pendingOAfterLand) {
      this.pendingOAfterLand = false;
      if (Math.abs(this.carriageOffsetVp - this.renderO) > 0.1) {
        this.oFrom = this.renderO;
        this.oTo = this.carriageOffsetVp;
        this.oT0 = this.frameNow;
        this.oDur = 30;
        this.oSpring = false;
        this.oActive = true;
        this.drawKindTag = 'O';
        this.markFirstFrame('O');
        hilog.info(CDOMAIN, CTAG, 'anim start O step t0=%{public}s target=%{public}s wall=%{public}s',
          this.frameNow.toFixed(1), this.oTo.toFixed(2), Date.now().toString());
        return;
      }
    }
    this.renderO = this.carriageOffsetVp;
    if (!this.frameActive()) { this.draw(); }
  }
  /** 批 20：换行/退行/换纸的拱目标 tick——只登记时长；目标按「paperX + renderO + cursorXVp」每帧实时算。 */
  onArchTickChanged(): void {
    if (this.canvasArchTick === this.lastArchTick) { return; }
    this.lastArchTick = this.canvasArchTick;
    this.pendingArch = true;
  }
  onClockActiveChanged(): void {
    if (this.clockActive) {
      this.ensureFrameClock().play();
      hilog.info(CDOMAIN, CTAG, 'frame clock active play');
    } else {
      this.frameClock?.pause();
      hilog.info(CDOMAIN, CTAG, 'frame clock inactive pause');
    }
  }
  onJoltChanged(): void {
    hilog.info(CDOMAIN, CTAG, 'canvas jolt=%{public}s', this.joltYVp.toFixed(1));
    // 逐字 jolt 只有 1–2vp；重绘纸层文字，不整屏重绘。
    this.redrawPaper();
  }
  onPaperReset(): void {
    // 纸容器从整张 Ph 缩回纸盒时必须全画布重绘；redrawPaper 只清裁剪区，旧纸会残留。
    // 18 号稿 §4.3：与 onFrame 同源守卫——帧时钟活动时只置脏，上屏交给下一帧，回到「每帧最多一次 draw()」。
    this.paperDirty = true;
    if (!this.frameActive()) { this.draw(); }
  }
  onDocChanged(): void {
    // §2.7 去重：只失效纸层、不上屏；上屏由帧时钟下一帧 draw() 完成（≤1 帧）。
    // 纸的位置**只由纸段 tick 决定**（含 dur=0 的瞬时 tick），这里不拿逻辑 prop 覆盖渲染值，
    // 避免「同一任务里先改 prop 后发 tick」时按 prop 顺序抢跑出一帧闪跳。
    this.paperDirty = true;
    if (!this.frameActive()) { this.draw(); }
  }

  onCandidatesChanged(): void {
    // 18 号稿 §4.3：候选栏变更是低频事件，但动画期间同帧再调 draw() 会变 double-draw；加同源守卫。
    this.paperDirty = true;
    if (!this.frameActive()) { this.draw(); }
  }

  /** 2A-4：换机只重建机器层；换纸只重建纸层；两者都走一次 §2.5 初值同步（字段按新机/新纸重置）。 */
  onMachineKindChanged(): void {
    this.applyInitialSync();
    this.loadMachineImages().then(() => {
      this.buildMachineLayer();
      this.draw();
    });
  }

  onPaperKindChanged(): void {
    this.applyInitialSync();
    this.loadPaperImage().then(() => {
      this.buildPaperLayer();
      this.draw();
    });
  }

  aboutToAppear(): void {
    // §2.5：初值只在这里（以及切机/切纸）读一次，之后内部字段归帧时钟管。
    this.applyInitialSync();
    this.ensureFrameClock().play();
    hilog.info(CDOMAIN, CTAG, 'frame clock resume');
    hilog.info(CDOMAIN, CTAG,
      'layout W=%{public}s H=%{public}s top=%{public}s bottom=%{public}s Pw=%{public}s paperTop=%{public}s paperBox=%{public}s carrTop=%{public}s Hc=%{public}s strike=%{public}s fs=%{public}s lh=%{public}s',
      this.widthVp.toFixed(1), this.heightVp.toFixed(1), this.topInset.toFixed(1), this.bottomInset.toFixed(1),
      this.paperWidthVp.toFixed(1), this.paperTopVp.toFixed(1), this.paperContainerVp.toFixed(1),
      this.carriageTopVp.toFixed(1), this.carriageHeightVp.toFixed(1), this.strikeLineVp.toFixed(1),
      this.fontSizeVp.toFixed(1), this.lineHeightVp.toFixed(1));
    const tr: CanvasTransform = computeTransform(this.widthVp, this.heightVp, this.topInset);
    const ref = referenceMetrics(this.isTablet);
    hilog.info(CDOMAIN, CTAG,
      'transform scale=%{public}s tx=%{public}s ty=%{public}s refPaperTop=%{public}s refCarriageTop=%{public}s refStrike=%{public}s',
      tr.scale.toFixed(4), tr.tx.toFixed(2), tr.ty.toFixed(2), ref.paperTop.toFixed(2),
      ref.carriageTop.toFixed(2), ref.strikeLine.toFixed(2));
    this.prepare();
  }

  private logTopBarRect(): void {
    try {
      const info = this.getUIContext().getComponentUtils().getRectangleById('canvas_topbar');
      const vp2px: number = this.getUIContext().vp2px(1);
      const expX: number = 0;
      const expY: number = this.topInset * vp2px;
      const expW: number = this.widthVp * vp2px;
      const expH: number = 56 * vp2px;
      hilog.info(CDOMAIN, CTAG,
        'topbar rect=%{public}s,%{public}s,%{public}s,%{public}s expect=%{public}s,%{public}s,%{public}s,%{public}s dX=%{public}s dY=%{public}s dW=%{public}s dH=%{public}s',
        info.screenOffset.x.toFixed(1), info.screenOffset.y.toFixed(1), info.size.width.toFixed(1),
        info.size.height.toFixed(1), expX.toFixed(1), expY.toFixed(1), expW.toFixed(1), expH.toFixed(1),
        Math.abs(info.screenOffset.x - expX * vp2px).toFixed(1),
        Math.abs(info.screenOffset.y - expY).toFixed(1),
        Math.abs(info.size.width - expW).toFixed(1), Math.abs(info.size.height - expH).toFixed(1));
    } catch (e) {
      hilog.warn(CDOMAIN, CTAG, 'topbar rect failed');
    }
  }

  /** Canvas font 字符串只取单一族名（逗号列表在 Canvas 里会回落系统字体）。 */
  private canvasFont(): string {
    const i: number = this.fontFamily.indexOf(',');
    return i > 0 ? this.fontFamily.substring(0, i).trim() : this.fontFamily;
  }

  private spec(): MachineSpec {
    return findMachine(this.machineKind);
  }

  private paperSpec(): PaperSpec {
    return findPaper(this.paperKind);
  }

  private slug(): string {
    if (this.machineKind === MachineKind.UPRIGHT_1920S) { return '1920s-upright'; }
    if (this.machineKind === MachineKind.PORTABLE_1930S) { return '1930s-portable'; }
    if (this.machineKind === MachineKind.STREAMLINED_1950S) { return '1950s-streamlined'; }
    return '1960s-electric';
  }

  private keybandPath(): string {
    if (this.machineKind === MachineKind.UPRIGHT_1920S) { return 'machine/1920s-upright-keyband-phone.jpg'; }
    if (this.machineKind === MachineKind.PORTABLE_1930S) { return 'machine/1930s-portable-keyband-phone.jpg'; }
    if (this.machineKind === MachineKind.STREAMLINED_1950S) { return 'machine/1950s-streamlined-keyband-phone.jpg'; }
    return 'machine/1960s-electric-keyband-phone.jpg';
  }

  private async loadRaw(path: string): Promise<image.PixelMap | null> {
    try {
      const bytes: Uint8Array = getContext(this).resourceManager.getRawFileContentSync(path);
      const ab: ArrayBuffer = new ArrayBuffer(bytes.length);
      const view: Uint8Array = new Uint8Array(ab);
      for (let i = 0; i < bytes.length; i++) {
        view[i] = bytes[i];
      }
      const src: image.ImageSource = image.createImageSource(ab);
      return await src.createPixelMap();
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(CDOMAIN, CTAG, 'image load failed path=%{public}s code=%{public}d msg=%{public}s',
        path, err.code === undefined ? -1 : err.code, err.message === undefined ? '?' : err.message);
      return null;
    }
  }

  private utf8ToString(bytes: Uint8Array): string {
    let out: string = '';
    let i: number = 0;
    while (i < bytes.length) {
      const c: number = bytes[i];
      if (c < 0x80) { out += String.fromCharCode(c); i += 1; }
      else if (c < 0xE0 && i + 1 < bytes.length) {
        out += String.fromCharCode(((c & 0x1F) << 6) | (bytes[i + 1] & 0x3F)); i += 2;
      } else if (c < 0xF0 && i + 2 < bytes.length) {
        out += String.fromCharCode(((c & 0x0F) << 12) | ((bytes[i + 1] & 0x3F) << 6) | (bytes[i + 2] & 0x3F)); i += 3;
      } else if (i + 3 < bytes.length) {
        const cp: number = ((c & 0x07) << 18) | ((bytes[i + 1] & 0x3F) << 12) |
          ((bytes[i + 2] & 0x3F) << 6) | (bytes[i + 3] & 0x3F);
        out += String.fromCharCode(0xD800 + ((cp - 0x10000) >> 10), 0xDC00 + ((cp - 0x10000) & 0xFFFF));
        i += 4;
      } else { break; }
    }
    return out;
  }

  private async loadMachineImages(): Promise<void> {
    const slug: string = this.slug();
    this.imgRoller = await this.loadRaw('layers/' + slug + '/roller-texture-v7.jpg');
    this.imgBase = await this.loadRaw('layers/' + slug + '/carriage-base-rail.png');
    this.imgBail = await this.loadRaw('layers/' + slug + '/paper-bail-v2.png');
    this.imgCentral = await this.loadRaw('layers/' + slug + '/central-guide.png');
    this.imgBracket = await this.loadRaw('layers/' + slug + '/lever-pivot-bracket.png');
    if (this.machineKind === MachineKind.PORTABLE_1930S) {
      this.imgLever = await this.loadRaw('layers/1930s-portable/lever.png');
    } else if (this.machineKind === MachineKind.STREAMLINED_1950S) {
      this.imgLever = await this.loadRaw('layers/1950s-streamlined/lever.png');
    } else if (this.machineKind === MachineKind.ELECTRIC_1960S) {
      this.imgLever = await this.loadRaw('layers/1960s-electric/lever.png');
    } else {
      this.imgLever = await this.loadRaw('layers/1920s-upright/lever.png');
    }
    if (this.machineKind === MachineKind.UPRIGHT_1920S) {
      this.imgTypebar = null;
    } else if (this.machineKind === MachineKind.PORTABLE_1930S) {
      this.imgTypebar = await this.loadRaw('typebar/1930s-portable-typebar-vertical.png');
    } else if (this.machineKind === MachineKind.STREAMLINED_1950S) {
      this.imgTypebar = await this.loadRaw('typebar/1950s-streamlined-typebar-vertical.png');
    } else {
      this.imgTypebar = await this.loadRaw('typebar/1960s-electric-typebar-vertical.png');
    }
    this.imgKeyband = await this.loadRaw(this.keybandPath());
    try {
      const kmBytes: Uint8Array = getContext(this).resourceManager.getRawFileContentSync(this.spec().keymapRawfile);
      const kmText: string = this.utf8ToString(kmBytes);
      this.keymap = KeymapParser.parse(kmText, this.machineKind as string, false, this.keybedWidth(),
        this.keybedHeightVp, this.spec().overlayColor, this.spec().overlayFontSizeVp);
    } catch (e) {
      hilog.error(CDOMAIN, CTAG, 'keymap load failed');
    }
  }

  private async loadPaperImage(): Promise<void> {
    this.imgPaper = await this.loadRaw(this.paperSpec().textureRawfile);
  }

  private async prepare(): Promise<void> {
    await this.loadMachineImages();
    await this.loadPaperImage();
    this.ready = true;
    this.buildStaticLayers();
    this.draw();
    setTimeout(() => { this.logTopBarRect(); }, 100);
  }

  private keybedWidth(): number {
    return this.widthVp;
  }

  private stackTop(): number {
    return this.topInset + TOP_BAR_HEIGHT_VP + PAPER_TOP_GAP_VP;
  }

  private paperX(): number {
    return (this.widthVp - this.paperWidthVp) / 2;
  }

  private paperY(): number {
    return this.stackTop() + (this.renderPaperTop >= 0 ? this.renderPaperTop : this.paperTopVp);
  }

  private keybedTop(): number {
    return this.heightVp - this.bottomInset - this.functionRowHeightVp - this.keybedHeightVp;
  }

  private fontBarTop(): number {
    return this.keybedTop() - this.fontBarHeightVp;
  }

  private candBarTop(): number {
    return this.fontBarTop() - this.candBarHeightVp;
  }

  private buildStaticLayers(): void {
    if (!this.ready) { return; }
    this.buildMachineLayer();
    this.buildPaperLayer();
    this.buildBackgroundLayer();
  }

  /** L1 静态层：机身／键带／功能行／字体条（只缓存当前机型＋当前纸种）。 */
  private buildMachineLayer(): void {
    const w: number = Math.max(1, Math.round(this.widthVp));
    const h: number = Math.max(1, Math.round(this.heightVp));
    const off: OffscreenCanvas = new OffscreenCanvas(w, h);
    const ctx: OffscreenCanvasRenderingContext2D = off.getContext('2d');
    // 18 号稿 B1：前层不再用全屏透明位图；拆成「压纸卷条带」＋「拨杆支架小框」两块小纹理，
    // 都按 renderO=0 烘焙，draw() 里带 live O 上屏（省掉每帧 13.6MB 的全屏透明 blit）。
    const bailH0: number = this.paperWidthVp / 9.6678;
    const offBail: OffscreenCanvas = new OffscreenCanvas(Math.max(1, Math.round(this.paperWidthVp)),
      Math.max(1, Math.round(bailH0)));
    const ctxBail: OffscreenCanvasRenderingContext2D = offBail.getContext('2d');
    const bkW0: number = 60;
    const bkH0: number = bkW0 / this.spec().bracketAspect;
    const offBk: OffscreenCanvas = new OffscreenCanvas(Math.max(1, Math.round(bkW0)),
      Math.max(1, Math.round(bkH0)));
    const ctxBk: OffscreenCanvasRenderingContext2D = offBk.getContext('2d');
    const spec: MachineSpec = this.spec();
    const Hc: number = this.carriageHeightVp;
    const carrAbs: number = this.stackTop() + this.carriageTopVp;
    const paperLeft: number = this.paperX() + this.renderO;
    const knobD: number = Hc * 0.92;
    const baseW: number = this.paperWidthVp + 2 * knobD;
    const baseLeft: number = Math.max(0, paperLeft - knobD);
    const rollW: number = this.paperWidthVp / spec.rollerWidthRatio;
    const rollX: number = paperLeft - (rollW - this.paperWidthVp) / 2;
    // 滚筒/明暗罩/进纸边改为 drawRollerLayer 单独绘制（随 carriageOffsetVp 步进）。
    // 木底座
    const baseY: number = carrAbs + Hc / 2 + 2;
    const baseH: number = Math.min(baseW / spec.baseRailAspect, Hc);
    if (this.imgBase !== null) {
      ctx.drawImage(this.imgBase, baseLeft, baseY, baseW, baseH);
    }
    // 沟槽
    ctx.fillStyle = 'rgba(18,13,8,0.92)';
    ctx.fillRect(baseLeft + 10, baseY + 6, baseW - 20, 14);
    // 铭牌（黄铜渐变 + 文字）
    const plateLeft: number = baseLeft + baseW * 0.32 - 55;
    const plateGrad: CanvasGradient = ctx.createLinearGradient(0, baseY + 0, 0, baseY + 26);
    plateGrad.addColorStop(0, '#f0d79a');
    plateGrad.addColorStop(0.55, '#c9a45c');
    plateGrad.addColorStop(1, '#8a6a2f');
    ctx.fillStyle = plateGrad;
    ctx.fillRect(plateLeft, baseY, 110, 26);
    ctx.fillStyle = '#3a2410';
    ctx.font = '13vp sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(this.machineNamePlate(), plateLeft + 55, baseY + 18);
    // 压纸卷（纸之上）：18 号稿 B1——烘焙进独立条带，blit 时带 live O（不再用全屏透明前层）
    this.bailY = carrAbs - bailH0 / 2 + (this.isTablet ? -15 : 0);
    if (this.imgBail !== null) {
      ctxBail.drawImage(this.imgBail, 0, 0, this.paperWidthVp, bailH0);
    }
    // 中央件改为 drawArchLayer 按 archXVp 单独绘制。
    // 拨杆支点支架：烘焙进独立小框（O=0 基准），blit 时带 live O
    const bracketW: number = bkW0;
    const bracketH: number = bkH0;
    const baseLeft0: number = Math.max(0, this.paperX() - knobD);
    this.bracketX0 = baseLeft0 + baseW - bracketW - 10;
    this.bracketY0 = carrAbs - Hc / 2 + Hc + 24 - bracketH;
    this.bracketW = bracketW;
    this.bracketH = bracketH;
    if (this.imgBracket !== null) {
      ctxBk.drawImage(this.imgBracket, 0, 0, bracketW, bracketH);
    }

    // 键带图
    if (this.imgKeyband !== null) {
      ctx.drawImage(this.imgKeyband, 0, this.keybedTop(), this.widthVp, this.keybedHeightVp);
    }
    // 字体条分隔线
    ctx.fillStyle = '#3a332b';
    ctx.fillRect(0, this.fontBarTop(), this.widthVp, 1);
    ctx.fillRect(0, this.fontBarTop() + this.fontBarHeightVp - 1, this.widthVp, 1);
    // 功能行
    ctx.fillStyle = '#241c16';
    ctx.fillRect(0, this.heightVp - this.bottomInset - this.functionRowHeightVp, this.widthVp, this.functionRowHeightVp);
    this.drawFunctionRow(ctx);
    this.machineLayer = off.transferToImageBitmap();
    this.bailLayer = offBail.transferToImageBitmap();
    this.bracketLayer = offBk.transferToImageBitmap();
    this.machineBuildCount++;
    hilog.info(CDOMAIN, CTAG, 'static layer rebuilt: machine count=%{public}d', this.machineBuildCount);
  }

  private leverSizeRatio(spec: MachineSpec): number {
    // 各机蓝图 leverSizeRatio（machines/<kind>/Blueprint.ets，2026-11-14 亲核）
    if (this.machineKind === MachineKind.UPRIGHT_1920S) { return 0.212; }
    if (this.machineKind === MachineKind.PORTABLE_1930S) { return 0.3264; }
    if (this.machineKind === MachineKind.STREAMLINED_1950S) { return 0.09; }
    return 0.12;
  }

  private machineNamePlate(): string {
    if (this.machineKind === MachineKind.UPRIGHT_1920S) { return '1920s'; }
    if (this.machineKind === MachineKind.PORTABLE_1930S) { return '1930s'; }
    if (this.machineKind === MachineKind.STREAMLINED_1950S) { return '1950s'; }
    return '1960s';
  }

  private drawFunctionRow(ctx: OffscreenCanvasRenderingContext2D): void {
    const y0: number = this.heightVp - this.bottomInset - this.functionRowHeightVp + 6;
    const h: number = this.functionRowHeightVp - 12;
    const left: number = 8;
    const right: number = this.widthVp - 8;
    const gap: number = 6;
    const keyW: number = (right - left - gap * 5) / 6;
    for (let i = 0; i < 6; i++) {
      const x: number = left + i * (keyW + gap);
      ctx.fillStyle = '#2e2823';
      ctx.fillRect(x, y0, keyW, h);
      ctx.strokeStyle = i === 0 || i === 5 || i === 2 ? '#c9a45c' : '#6b6055';
      ctx.lineWidth = 1;
      ctx.strokeRect(x + 0.5, y0 + 0.5, keyW - 1, h - 1);
    }
  }

  /** L2 纸层：纸纹＋页眉＋页码＋行文字＋引导文案＋光标三角。 */
  private buildBackgroundLayer(): void {
    const off: OffscreenCanvas = new OffscreenCanvas(this.widthVp, this.heightVp);
    const ctx: OffscreenCanvasRenderingContext2D = off.getContext('2d');
    const grad: CanvasGradient = ctx.createLinearGradient(0, 0, 0, this.heightVp);
    grad.addColorStop(0.0, '#171310');
    grad.addColorStop(1.0, '#241c16');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, this.widthVp, this.heightVp);
    if (this.machineLayer !== null) {
      ctx.drawImage(this.machineLayer, 0, 0);
    }
    this.backgroundLayer = off.transferToImageBitmap();
    this.drawStatic();
  }

  /** 18 号稿 B2：下层静态 Canvas——背景渐变＋机身＋键带＋功能行＋字体条，只在重建时画一次。 */
  private drawStatic(): void {
    if (!this.staticReady || !this.ready) { return; }
    hilog.info(CDOMAIN, CTAG, 'static draw once');
    this.ctxStatic.clearRect(0, 0, this.widthVp, this.heightVp);
    if (this.backgroundLayer !== null) {
      this.ctxStatic.drawImage(this.backgroundLayer, 0, 0);
    } else if (this.machineLayer !== null) {
      this.ctxStatic.drawImage(this.machineLayer, 0, 0);
    }
  }

  private buildPaperLayer(): void {
    const w: number = Math.max(1, Math.round(this.paperWidthVp));
    const h: number = Math.max(1, Math.round(this.paperHeightVp));
    const off: OffscreenCanvas = new OffscreenCanvas(w, h);
    const ctx: OffscreenCanvasRenderingContext2D = off.getContext('2d');
    if (this.imgPaper !== null) {
      ctx.drawImage(this.imgPaper, 0, 0, this.paperWidthVp, this.paperHeightVp);
    } else {
      ctx.fillStyle = '#f4ecd8';
      ctx.fillRect(0, 0, this.paperWidthVp, this.paperHeightVp);
    }
    const ps: PaperSpec = this.paperSpec();
    if (ps.hasHeader) {
      ctx.fillStyle = '#c8b9a6';
      ctx.fillRect(0, this.marginTVp, this.paperWidthVp, 1);
      ctx.fillRect(0, this.marginTVp + 4, this.paperWidthVp, 1);
    }
    if (ps.hasRuledGrid) {
      ctx.fillStyle = '#c8a49a';
      ctx.fillRect(this.marginHVp - 8, 0, 1, this.paperHeightVp);
    }
    this.paperLayer = off.transferToImageBitmap();
    this.paperBuildCount++;
    hilog.info(CDOMAIN, CTAG, 'static layer rebuilt: paper count=%{public}d', this.paperBuildCount);
  }

  /**
   * §2.7 去重：文档内容变化**只失效纸层**（纸纹位图不变，文字/光标由 draw() 重画），不上屏；
   * 上屏交给帧时钟下一帧 draw()（≤1 帧）。帧时钟空闲（无活动动画）时直接补一次 draw()，
   * 避免文字延迟出现。旧实现在每次 onDocChanged 时局部 blit 一次，与帧时钟同帧重复画。
   */
  private redrawPaper(): void {
    if (!this.ready) { return; }
    this.paperDirty = true;
    if (!this.frameActive()) { this.draw(); }
  }

  /** 可移动滚筒层：随 carriageOffsetVp 平移；底座/键床不动。 */
  private drawRollerLayer(ctx: CanvasRenderingContext2D): void {
    const spec: MachineSpec = this.spec();
    const Hc: number = this.carriageHeightVp;
    const paperLeft: number = this.paperX() + this.renderO;
    const rollW: number = this.paperWidthVp / spec.rollerWidthRatio;
    const rollX: number = paperLeft - (rollW - this.paperWidthVp) / 2;
    const carrAbs: number = this.stackTop() + this.carriageTopVp;
    if (this.imgRoller !== null) {
      ctx.drawImage(this.imgRoller, rollX, carrAbs - Hc / 2, rollW, Hc);
    }
    // 设计稿 §0：原来每帧新建 CanvasGradient（1 次 createLinearGradient＋5 次 addColorStop）。
    // 批 2 实测到 GPU 显存被打爆（RENDER_MEMORY_OVER_ERROR: gpu[2156140980]）→ 按设计既定首选缓存渐变：
    // 几何（Hc／carrAbs）不变就复用同一个渐变对象，只变 fillRect 的位置。
    const gradKey: string = Hc.toFixed(2) + '|' + carrAbs.toFixed(2) + '|' + rollW.toFixed(2);
    if (this.rollerShade === null || this.rollerShadeKey !== gradKey) {
      const shade: CanvasGradient = ctx.createLinearGradient(0, carrAbs - Hc / 2, 0, carrAbs + Hc / 2);
      shade.addColorStop(0.0, 'rgba(255,246,230,0.30)');
      shade.addColorStop(0.35, 'rgba(0,0,0,0)');
      shade.addColorStop(0.52, 'rgba(255,246,230,0.32)');
      shade.addColorStop(0.82, 'rgba(0,0,0,0.42)');
      shade.addColorStop(1.0, 'rgba(0,0,0,0.72)');
      this.rollerShade = shade;
      this.rollerShadeKey = gradKey;
    }
    ctx.fillStyle = this.rollerShade;
    ctx.fillRect(rollX, carrAbs - Hc / 2, rollW, Hc);
    ctx.fillStyle = 'rgba(232,221,201,0.85)';
    ctx.fillRect(rollX, carrAbs + Hc / 2, rollW, 5);
  }

  /** 哥特拱/中央件：x 由 Index animateArch 插值（90/200/300ms）后传入。 */
  private drawArchLayer(ctx: CanvasRenderingContext2D): void {
    if (this.imgCentral === null) { return; }
    const spec: MachineSpec = this.spec();
    const Hg: number = this.carriageHeightVp * 1.5;
    const w: number = Hg * spec.centralAspect;
    const strikeAbs: number = this.stackTop() + this.strikeLineVp;
    const ax: number = this.renderArchX >= 0 ? this.renderArchX
      : this.paperX() + this.renderO + this.cursorXVp;
    ctx.drawImage(this.imgCentral, ax - w / 2, strikeAbs - Hg * spec.centralWindowY, w, Hg);
  }

  private draw(): void {
    if (!this.ready) { return; }
    // 批 20 帧率取证：每次真正上屏都记一条（含时钟时间戳与墙钟），用于数「一次动画上了几帧」。
    hilog.info(CDOMAIN, CTAG, 'draw frame t=%{public}s ms=%{public}s tag=%{public}s',
      this.frameNow.toFixed(1), Date.now().toString(), this.drawKindTag);
    const ctx: CanvasRenderingContext2D = this.ctx;
    ctx.clearRect(0, 0, this.widthVp, this.heightVp);
    // 18 号稿 B2：背景（渐变＋机身）已移到下层静态 Canvas，只画一次；这里不再每帧 blit 全屏背景。
    this.drawRollerLayer(ctx);
    if (this.paperLayer !== null) {
      ctx.save();
      ctx.beginPath();
      const clipY: number = Math.max(this.paperY(), this.stackTop() + TOP_BAR_HEIGHT_VP);
      const clipH: number = Math.max(0, this.paperY() + (this.renderPaperContainer >= 0 ? this.renderPaperContainer : this.paperContainerVp) - clipY);
      ctx.rect(this.paperX() + this.renderO, clipY, this.paperWidthVp, clipH);
      ctx.clip();
      ctx.drawImage(this.paperLayer, this.paperX() + this.renderO, this.paperY());
      ctx.restore();
    }
    this.drawArchLayer(ctx);
    if (this.bailLayer !== null) {
      ctx.drawImage(this.bailLayer, this.paperX() + this.renderO, this.bailY);
    }
    if (this.bracketLayer !== null) {
      ctx.drawImage(this.bracketLayer, this.bracketX0 + this.renderO, this.bracketY0);
    }
    this.drawLever(ctx);
    this.drawTypebar(ctx);
    this.drawTextOverlay();
    this.paperDirty = false;
  }

  /** 打击 90ms 由 Canvas 帧时钟驱动，结束帧调 onStrikeArrive；200ms fallback 由 Index 保留。 */
  onCanvasStrikeTickChanged(): void {
    if (this.canvasStrikeTick === this.lastCanvasStrikeTick) {
      return;
    }
    this.lastCanvasStrikeTick = this.canvasStrikeTick;
    this.strikePending += 1;
    this.runCanvasStrike();
  }

  private ensureFrameClock(): AnimatorResult {
    if (this.frameClock === null) {
      const opts: AnimatorOptions = {
        duration: 1000000, easing: 'linear', delay: 0, fill: 'forwards',
        direction: 'normal', iterations: -1, begin: 0, end: 1000000,
      };
      this.frameClock = Animator.create(opts);
      this.frameClock.onFrame = (value: number): void => {
        this.frameSeq += 1;
        this.frameNow = value;
        if (this.strikeWait) {
          const jt: number = value - this.strikeT0;
          if (jt <= 20) { this.strikeJolt = jt / 20; }
          else if (jt <= 40) { this.strikeJolt = 1 - (jt - 20) / 20; }
          else { this.strikeJolt = 0; }
        }
        if (this.nlJoltActive) {
          const nt: number = value - this.nlJoltT0;
          if (nt <= 20) { this.nlJolt = 2 * nt / 20; }
          else if (nt <= 40) { this.nlJolt = 2 * (1 - (nt - 20) / 20); }
          else { this.nlJolt = 0; this.nlJoltActive = false; }
        }
        // 批 20：拱＝单一帧时钟驱动的追踪器。目标每帧实时算（paperX + renderO + cursorXVp，
        // 与 Index clampedStrikeXVp 同口径）；目标动了就按时间重锚一段（打击 90／换行退行 200／换纸 300），
        // ease-out 不过冲 → 单调收敛，不再出现「多跑一截再往回拉」的双驱动。
        const archTarget: number = this.paperX() + this.carriageOffsetVp + this.cursorXVp;
        if (this.renderArchX < 0) { this.renderArchX = archTarget; }
        if (this.pendingArch) {
          this.pendingArch = false;
          this.archDurNext = this.canvasArchDurMs > 1 ? this.canvasArchDurMs : 200;
        }
        if (this.archActive) {
          if (Math.abs(archTarget - this.archToX) > 0.4) {
            this.archFromX = this.renderArchX;
            this.archToX = archTarget;
            this.archT0 = value;
          }
          const at: number = (value - this.archT0) / this.archDur;
          if (at >= 1) {
            this.renderArchX = this.archToX;
            this.archActive = false;
            hilog.info(CDOMAIN, CTAG, 'anim arrive arch t=%{public}s dt=%{public}s x=%{public}s',
              value.toFixed(1), (value - this.archT0).toFixed(1), this.renderArchX.toFixed(2));
          } else {
            const ae: number = 1 - Math.pow(1 - at, 3);
            this.renderArchX = this.archFromX + (this.archToX - this.archFromX) * ae;
          }
        }
        if (!this.archActive && Math.abs(archTarget - this.renderArchX) > 0.2) {
          this.archFromX = this.renderArchX;
          this.archToX = archTarget;
          this.archT0 = value;
          this.archDur = this.archDurNext;
          this.archActive = true;
          hilog.info(CDOMAIN, CTAG, 'anim start arch t0=%{public}s from=%{public}s to=%{public}s dur=%{public}d',
            value.toFixed(1), this.archFromX.toFixed(2), this.archToX.toFixed(2), this.archDur);
        }
        if (this.paperActive) {
          const ptt: number = (value - this.paperT0) / this.paperDur;
          if (ptt >= 1) {
            this.renderPaperTop = this.paperToTop;
            this.renderPaperContainer = this.paperToBox;
            this.paperActive = false;
            hilog.info(CDOMAIN, CTAG, 'anim arrive paper t=%{public}s dt=%{public}s top=%{public}s box=%{public}s',
              value.toFixed(1), (value - this.paperT0).toFixed(1),
              this.renderPaperTop.toFixed(1), this.renderPaperContainer.toFixed(1));
          } else {
            const pe: number = ptt < 0.5 ? 2 * ptt * ptt : 1 - Math.pow(-2 * ptt + 2, 2) / 2;
            this.renderPaperTop = this.paperFromTop + (this.paperToTop - this.paperFromTop) * pe;
            this.renderPaperContainer = this.paperFromBox + (this.paperToBox - this.paperFromBox) * pe;
          }
        }
        if (this.newlineOActive) {
          if (!this.newlineOJoltStarted && value - this.newlineOT0 >= 450) {
            this.newlineOJoltStarted = true;
            this.nlJoltT0 = value;
            this.nlJolt = 0;
            this.nlJoltActive = true;
            hilog.info(CDOMAIN, CTAG, 'anim start newline reset t=%{public}s dt=%{public}s',
              value.toFixed(1), (value - this.newlineOT0).toFixed(1));
          }
          const no: number = (value - this.newlineOT0 - 450) / 250;
          if (no >= 1) {
            this.renderO = this.newlineOTo;
            this.newlineOActive = false;
            this.newlineOJoltStarted = false;
            hilog.info(CDOMAIN, CTAG, 'anim arrive newline O t=%{public}s dt=%{public}s',
              value.toFixed(1), (value - this.newlineOT0 - 450).toFixed(1));
          } else if (no > 0) {
            this.renderO = this.newlineOFrom + (this.newlineOTo - this.newlineOFrom) * no;
          }
        }
        if (this.oActive) {
          const ot: number = (value - this.oT0) / this.oDur;
          if (ot >= 1) {
            this.renderO = this.oTo;
            this.oActive = false;
            this.oSpring = false;
            hilog.info(CDOMAIN, CTAG, 'anim arrive O t=%{public}s dt=%{public}s',
              value.toFixed(1), (value - this.oT0).toFixed(1));
          } else {
            const oe: number = this.oSpring ? (1 - Math.pow(1 - ot, 3)) : ot;
            this.renderO = this.oFrom + (this.oTo - this.oFrom) * oe;
          }
        }
        // 批 2 拨杆：释放动画由帧时钟驱动；提交段结束自动接回程段（各段各自 t0）。
        if (this.leverAnimActive) {
          const lp: number = (value - this.leverAnimT0) / this.leverAnimDur;
          if (lp >= 1) {
            this.renderLeverRatio = this.leverAnimTo;
            hilog.info(CDOMAIN, CTAG, 'anim arrive lever phase=%{public}d t=%{public}s dt=%{public}s ratio=%{public}s',
              this.leverAnimPhase, value.toFixed(1), (value - this.leverAnimT0).toFixed(1),
              this.renderLeverRatio.toFixed(3));
            if (this.leverAnimPhase === 0) {
              this.leverAnimFrom = 1;
              this.leverAnimTo = 0;
              this.leverAnimT0 = value;
              this.leverAnimDur = 200;
              this.leverAnimPhase = 1;
            } else {
              this.leverAnimActive = false;
            }
          } else {
            const le: number = 1 - Math.pow(1 - lp, 3);
            this.renderLeverRatio = this.leverAnimFrom + (this.leverAnimTo - this.leverAnimFrom) * le;
          }
        }
        // §2.4：tick 的启动统一推迟到本帧末尾——先结算上一段（含到达打点），再起本段。
        // 这样 @Prop 批量同步已落地，目标读到的才是本批目标；也不会把上一段的到达帧吞掉。
        if (this.pendingBack) { this.pendingBack = false; this.startBackO(); }
        if (this.pendingDelete) { this.pendingDelete = false; this.startDeleteO(); }
        if (this.pendingNewline) { this.pendingNewline = false; this.startNewlineO(); }
        if (this.pendingPaper) { this.pendingPaper = false; this.startPaperSegment(); }
        if (this.pendingLeverRelease) { this.pendingLeverRelease = false; this.startLeverRelease(); }
        const activeNow: boolean = this.frameActive();
        const otherActive: boolean = this.strikeWait || this.archActive || this.oActive || this.paperActive
          || this.newlineOActive || this.nlJoltActive || this.leverAnimActive;
        const needDraw: boolean = otherActive || (this.leverActive && this.leverDirty);
        if (needDraw) {
          this.draw();
          this.leverDirty = false;
          if (this.leverActive) {
            // §8 拨杆跟手打点：本帧真正把新角度画上屏的时刻（与最近一次 Move 的 wall 相减即延迟）。
            hilog.info(CDOMAIN, CTAG, 'lever draw wall=%{public}s ratio=%{public}s',
              Date.now().toString(), this.renderLeverRatio.toFixed(3));
          }
        }
        if (!this.firstLogged) {
          this.firstLogged = true;
          hilog.info(CDOMAIN, CTAG, 'first frame %{public}s t=%{public}s dt=%{public}s wall=%{public}s',
            this.firstKind, value.toFixed(1), (value - this.firstT0).toFixed(1), Date.now().toString());
        }
        if (this.strikeWait && value - this.strikeT0 >= 90) {
          this.strikeJolt = 0;
          this.strikeWait = false;
          hilog.info(CDOMAIN, CTAG, 'canvas landHead dt=%{public}d', value - this.strikeT0);
          this.pendingOAfterLand = true;
          this.onStrikeArrive();
          if (this.strikePending > 0) { this.runCanvasStrike(); }
        }
        if (activeNow && value > this.frameLastValue) {
          hilog.info(CDOMAIN, CTAG, 'frame tick now=%{public}s interval=%{public}s',
            value.toFixed(1), (value - this.frameLastValue).toFixed(1));
        }
        this.frameLastValue = value;
        if (this.frameSeq === 1 || value - this.frameLastLogMs >= 500) {
          this.frameLastLogMs = value;
          hilog.info(CDOMAIN, CTAG, 'frame tick seq=%{public}d now=%{public}s', this.frameSeq, value.toFixed(1));
        }
      };
    }
    return this.frameClock;
  }

  private runCanvasStrike(): void {
    if (this.strikePending <= 0 || this.strikeWait) {
      return;
    }
    this.strikePending -= 1;
    this.strikeT0 = this.frameNow;
    this.strikeWait = true;
    this.markFirstFrame('strike');
    // 打击的拱由帧时钟追踪器负责（90ms 一段），这里只把时长交下去。
    this.archDurNext = 90;
    this.drawKindTag = 'strike';
    hilog.info(CDOMAIN, CTAG, 'anim start strike t0=%{public}s wall=%{public}s',
      this.frameNow.toFixed(1), Date.now().toString());
  }

  /** 字杆按 typebarAngle 画（1920s 静止不可见；其余机 rest55° 与基线一致）。 */
  private drawTypebar(ctx: CanvasRenderingContext2D): void {
    if (this.imgTypebar === null || this.machineKind === MachineKind.UPRIGHT_1920S) {
      return;
    }
    const Hc: number = this.carriageHeightVp;
    const tbSize: number = Hc * 2.5;
    const tbX: number = this.paperX() + this.marginHVp - tbSize / 2;
    const tbY: number = this.stackTop() + this.strikeLineVp - 0.115 * tbSize;
    ctx.save();
    ctx.translate(tbX + tbSize * 0.5, tbY + tbSize * 0.867);
    ctx.rotate(this.typebarAngle * Math.PI / 180);
    ctx.drawImage(this.imgTypebar, -tbSize * 0.5, -tbSize * 0.867, tbSize, tbSize);
    ctx.restore();
  }

  /** 拨杆按 leverRatio 实时重画（静止角/摆幅按机；0=静止，1=满摆）。 */
  private drawLever(ctx: CanvasRenderingContext2D): void {
    if (this.imgLever === null) {
      return;
    }
    const spec: MachineSpec = this.spec();
    const Hc: number = this.carriageHeightVp;
    const paperLeft: number = this.paperX() + this.renderO;
    const knobD: number = Hc * 0.92;
    const baseLeft: number = (this.widthVp - this.paperWidthVp) / 2 - knobD;
    const baseW: number = this.paperWidthVp + 2 * knobD;
    const bracketW: number = 60;
    const bracketH: number = bracketW / spec.bracketAspect;
    const bracketLeft: number = baseLeft + baseW - bracketW - 10 + this.renderO;
    const bracketTop: number = this.carriageTopVp - Hc / 2 + Hc + 24 - bracketH;
    const leverW: number = this.isTablet
      ? Hc * 1.84 * this.leverSizeRatio(spec)
      : Hc * 2.5 * this.leverSizeRatio(spec);
    const leverH: number = leverW / spec.leverAspect;
    const pinX: number = bracketLeft + spec.bracketPivotX * bracketW;
    const pinY: number = bracketTop + spec.bracketPivotY * bracketH;
    const angleDeg: number = restDegFor(this.isTablet) + swingDegFor(this.isTablet) * this.renderLeverRatio;
    ctx.save();
    ctx.translate(pinX, pinY);
    ctx.rotate(angleDeg * Math.PI / 180);
    ctx.drawImage(this.imgLever, -leverW * spec.leverPivotX, -leverH * spec.leverPivotY, leverW, leverH);
    ctx.restore();
  }

  /** Phase 2 前置：文字层——只清屏＋重绘文字，不做任何位图 blit（Phase 0 已证 CPU 不是瓶颈）。 */
  private drawTextOverlay(): void {
    if (!this.textReady) { return; }
    this.ctxText.clearRect(0, 0, this.widthVp, this.heightVp);
    this.drawTexts(this.ctxText);
  }

  /** 文字统一在主 Canvas 上画（OffscreenCanvas 看不到 registerFont 注册字体，会回落到系统字体）。 */
  private drawTexts(ctx: CanvasRenderingContext2D): void {
    ctx.textBaseline = 'middle';
    // 纸面文字（裁剪到纸容器）
    ctx.save();
    ctx.beginPath();
    ctx.rect(this.paperX() + this.renderO, this.paperY(), this.paperWidthVp, this.paperContainerVp);
    ctx.clip();
    const paperLeft: number = this.paperX() + this.renderO;
    const paperTop: number = this.paperY();
    const ps: PaperSpec = this.paperSpec();
    if (ps.hasHeader) {
      ctx.fillStyle = '#8a7f70';
      ctx.font = '12vp sans-serif';
      ctx.textAlign = 'right';
      ctx.fillText(this.pageNo.toString() + ' / ' + this.pageCount.toString(),
        paperLeft + this.paperWidthVp - this.marginHVp, paperTop + this.marginTVp + 18);
    }
    ctx.fillStyle = this.inkColor;
    ctx.font = this.fontSizeVp.toString() + 'vp ' + this.canvasFont();
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    const contentTop: number = paperTop + this.marginTVp + 20;
    // §2.6 jolt：打击 1vp（帧时钟 strikeJolt）＋换行/复位 2vp（帧时钟 nlJolt）＋ArkUI 回滚分支的 joltYVp
    const joltSum: number = this.joltYVp + this.strikeJolt + this.nlJolt;
    for (let i = 0; i < this.lines.length; i++) {
      const line: string = this.lines[i];
      if (line.length > 0) {
        ctx.fillText(line, paperLeft + this.marginHVp, contentTop + i * this.lineHeightVp + this.lineHeightVp / 2 + joltSum);
      }
    }
    if (this.lines.length <= 1 && this.hintText.length > 0) {
      ctx.fillStyle = '#8a7f70';
      ctx.font = '13vp sans-serif';
      ctx.textAlign = 'left';
      ctx.fillText(this.hintText, paperLeft + this.marginHVp,
        paperTop + this.paperHeightVp - this.marginBVp - this.lineHeightVp + 16);
    }
    // 光标三角
    ctx.fillStyle = this.inkColor;
    ctx.beginPath();
    ctx.moveTo(paperLeft + this.cursorXVp, paperTop + this.cursorYVp + joltSum);
    ctx.lineTo(paperLeft + this.cursorXVp + 8, paperTop + this.cursorYVp + joltSum);
    ctx.lineTo(paperLeft + this.cursorXVp + 4, paperTop + this.cursorYVp + 6 + joltSum);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
    // 键帽叠字（裁剪到键带区）
    ctx.save();
    ctx.beginPath();
    ctx.rect(0, this.keybedTop(), this.widthVp, this.keybedHeightVp);
    ctx.clip();
    ctx.fillStyle = this.keymap.overlayColor;
    ctx.font = this.keymap.overlayFontSize.toString() + 'vp ' + (this.machineKind === MachineKind.UPRIGHT_1920S ? 'NotoSerifSC' : this.canvasFont());
    ctx.textAlign = 'center';
    for (let i = 0; i < this.keymap.caps.length; i++) {
      const cap: CapDef = this.keymap.caps[i];
      if (cap.isExtra || cap.label === ' ') { continue; }
      ctx.fillText(cap.label, cap.xRatio * this.keybedWidth(), this.keybedTop() + cap.yRatio * this.keybedHeightVp);
    }
    ctx.restore();
    // 候选栏（中文候选 chip）
    if (this.candBarHeightVp > 0 && this.candidates.length > 0) {
      const cy: number = this.fontBarTop() - this.candBarHeightVp;
      ctx.fillStyle = '#1a1713';
      ctx.fillRect(0, cy, this.widthVp, this.candBarHeightVp);
      const n: number = this.candidates.length;
      const chipW: number = 64;
      const maxScroll: number = Math.max(0, 16 + n * chipW - this.widthVp);
      if (this.candScroll > maxScroll) { this.candScroll = maxScroll; }
      if (this.candScroll < 0) { this.candScroll = 0; }
      ctx.save();
      ctx.beginPath();
      ctx.rect(0, cy, this.widthVp, this.candBarHeightVp);
      ctx.clip();
      for (let i = 0; i < n; i++) {
        ctx.fillStyle = i === 0 ? '#c9a45c' : '#dbccb3';
        ctx.font = '16vp sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText(this.candidates[i], 8 + i * chipW + chipW / 2 - this.candScroll,
          cy + this.candBarHeightVp / 2);
      }
      ctx.restore();
    }
    // 字体条
    ctx.fillStyle = '#beb4a8';
    ctx.font = '13vp ' + this.canvasFont();
    ctx.textAlign = 'center';
    ctx.fillText(this.fontLabel, this.widthVp / 2, this.fontBarTop() + this.fontBarHeightVp / 2);
    // 功能行文字
    const labels: string[] = [this.langLabel, this.deleteLabel, this.newlineLabel,
      this.paperLabel, this.backLineLabel, this.charLabel];
    const y0: number = this.heightVp - this.bottomInset - this.functionRowHeightVp + 6;
    const h: number = this.functionRowHeightVp - 12;
    const left: number = 8;
    const right: number = this.widthVp - 8;
    const gap: number = 6;
    const keyW: number = (right - left - gap * 5) / 6;
    ctx.font = '14vp sans-serif';
    ctx.textAlign = 'center';
    for (let i = 0; i < 6; i++) {
      ctx.fillStyle = i === 2 ? '#c9a45c' : '#dbccb3';
      ctx.fillText(labels[i], left + i * (keyW + gap) + keyW / 2, y0 + h / 2);
    }
  }

  private onCanvasTouch(e: TouchEvent): void {
    const touches = e.touches;
    hilog.info(CDOMAIN, CTAG, 'touch type=%{public}d n=%{public}d x=%{public}s y=%{public}s', e.type, touches.length, touches.length>0?touches[0].x.toFixed(1):'-', touches.length>0?touches[0].y.toFixed(1):'-');
    if (touches.length === 0) {
      return;
    }
    const t = touches[0];
    if (e.type === TouchType.Down) {
      // 功能行六键
      const funcTop: number = this.heightVp - this.bottomInset - this.functionRowHeightVp;
      if (t.y >= funcTop && t.y <= funcTop + this.functionRowHeightVp) {
        const left: number = 8;
        const right: number = this.widthVp - 8;
        const gap: number = 6;
        const keyW: number = (right - left - gap * 5) / 6;
        const idx: number = Math.floor((t.x - left) / (keyW + gap));
        const keys: string[] = ['lang', 'delete', 'newline', 'paper', 'backline', 'char'];
        if (idx >= 0 && idx < 6) {
          this.onFunctionKey(keys[idx]);
        }
        return;
      }
      // 候选栏 chip
      if (this.candBarHeightVp > 0 && this.candidates.length > 0
        && t.y >= this.fontBarTop() - this.candBarHeightVp && t.y < this.fontBarTop()) {
        const n: number = this.candidates.length;
        const chipW: number = 64;
        const ci: number = Math.floor((t.x + this.candScroll - 8) / chipW);
        this.candDragX = t.x;
        this.candDragOrigin = this.candScroll;
        this.candDragged = false;
        if (ci >= 0 && ci < n) {
          this.candidateDownIndex = ci;
          this.candidateDownTime = Date.now();
        }
        return;
      }
      let hitAny: boolean = false;
      for (let i: number = 0; i < touches.length; i++) {
        const tt = touches[i];
        const cap: CapDef | null = KeymapParser.hitTest(this.keymap, tt.x, tt.y - this.keybedTop());
        if (cap !== null && !cap.isExtra) {
          hilog.info(CDOMAIN, CTAG, 'hit cap=%{public}s id=%{public}d x=%{public}s y=%{public}s',
            cap.label, tt.id, tt.x.toFixed(1), tt.y.toFixed(1));
          this.heldCaps.set(tt.id, cap);
          this.onCapDown(cap);
          hitAny = true;
        }
      }
      if (hitAny) {
        return;
      }
      if (t.x > this.widthVp * 0.78 && t.y > this.carriageTopVp
        && t.y < this.carriageTopVp + this.carriageHeightVp) {
        // 批 2（§7）：按下从静止角起算；角度只写 Canvas 内部字段。
        this.leverActive = true;
        this.leverStartY = t.y;
        this.renderLeverRatio = 0;
        this.leverMoveWall = Date.now();
        this.leverMoveCount = 0;
        this.onLeverStart(t.x);
      }
      return;
    }
    if (e.type === TouchType.Move && this.candDragX >= 0) {
      const dx: number = t.x - this.candDragX;
      if (Math.abs(dx) > 4) { this.candDragged = true; }
      const n: number = this.candidates.length;
      const maxScroll: number = Math.max(0, 16 + n * 64 - this.widthVp);
      let ns: number = this.candDragOrigin - dx;
      if (ns < 0) { ns = 0; }
      if (ns > maxScroll) { ns = maxScroll; }
      this.candScroll = ns;
      this.draw();
      return;
    }
    if (e.type === TouchType.Move && this.leverActive) {
      // §7：Move 里只改字段、不直接 draw()——重画由帧时钟下一帧完成（≤1 帧）。
      const dy: number = t.y - this.leverStartY;
      this.renderLeverRatio = dragRatioFor(dy, this.leverHDragVp);
      this.leverMoveWall = Date.now();
      this.leverMoveCount += 1;
      hilog.info(CDOMAIN, CTAG, 'lever move n=%{public}d dy=%{public}s ratio=%{public}s wall=%{public}s',
        this.leverMoveCount, dy.toFixed(1), this.renderLeverRatio.toFixed(3), this.leverMoveWall.toString());
      // 只用于 Index 的过半逻辑；Index 不回写角度。
      this.leverDirty = true;
      this.onLeverUpdate(dy);
      return;
    }
    if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
      if (this.candidateDownIndex >= 0) {
        const ci: number = this.candidateDownIndex;
        const ms: number = Date.now() - this.candidateDownTime;
        this.candidateDownIndex = -1;
        this.candDragX = -1;
        if (this.candDragged) {
          this.candDragged = false;
          return;
        }
        if (ms >= 600) {
          hilog.info(CDOMAIN, CTAG, 'candidate long ms=%{public}d idx=%{public}d', ms, ci);
          this.onCandidateLong(ci);
        } else {
          hilog.info(CDOMAIN, CTAG, 'candidate tap ms=%{public}d idx=%{public}d', ms, ci);
          this.onCandidatePick(ci);
        }
        return;
      }
      this.candDragX = -1;
      this.candDragged = false;
      if (this.leverActive) {
        this.leverActive = false;
        this.onLeverEnd();
      }
      const upIds: number[] = [];
      for (let i: number = 0; i < touches.length; i++) {
        upIds.push(touches[i].id);
      }
      this.heldCaps.forEach((cap: CapDef, id: number) => {
        if (upIds.indexOf(id) >= 0 || e.type === TouchType.Cancel) {
          this.onCapUp(cap);
          this.heldCaps.delete(id);
        }
      });
    }
  }

  @Builder
  a11yLayer() {
    // 四机键帽 + 空格条（透明原生按钮，opacity 0.02；供读屏与 dump 节点计数）
    ForEach(this.keymap.caps, (cap: CapDef) => {
      Button('keycap ' + cap.label)
        .width(Math.max(1, cap.wRatio * this.widthVp))
        .height(Math.max(1, cap.hRatio * this.keybedHeightVp))
        .position({
          x: cap.cx - cap.wRatio * this.widthVp / 2,
          y: this.keybedTop() + cap.cy - cap.hRatio * this.keybedHeightVp / 2,
        })
        .backgroundColor(Color.Transparent)
        .opacity(0.02)
        .hitTestBehavior(HitTestMode.None)
        .id('a11y_cap_' + cap.id)
        .onClick(() => { this.onCapDown(cap); this.onCapUp(cap); })
    }, (cap: CapDef) => cap.id)
    Button('space bar')
      .width(Math.max(1, this.keymap.spaceXMax - this.keymap.spaceXMin))
      .height(Math.max(1, this.keymap.spaceYMax - this.keymap.spaceYMin))
      .position({ x: this.keymap.spaceXMin, y: this.keybedTop() + this.keymap.spaceYMin })
      .backgroundColor(Color.Transparent)
      .opacity(0.02)
        .hitTestBehavior(HitTestMode.None)
      .id('a11y_space')
      .onClick(() => { this.onFunctionKey('space'); })
    // 功能行六键
    ForEach(['lang', 'delete', 'newline', 'paper', 'backline', 'char'], (key: string, i: number) => {
      Button('function ' + key)
        .width((this.widthVp - 16 - 30) / 6)
        .height(this.functionRowHeightVp)
        .position({ x: 8 + i * ((this.widthVp - 16 - 30) / 6 + 6),
          y: this.heightVp - this.bottomInset - this.functionRowHeightVp })
        .backgroundColor(Color.Transparent)
        .opacity(0.02)
        .hitTestBehavior(HitTestMode.None)
        .id('a11y_func_' + key)
        .onClick(() => { this.onFunctionKey(key); })
    }, (key: string) => key)
    // 候选 chip（3 候选态时由 dump 计入）
    ForEach(this.candidates, (cand: string, i: number) => {
      Button('candidate ' + cand)
        .width((this.widthVp - 16) / Math.max(1, this.candidates.length))
        .height(this.candBarHeightVp)
        .position({ x: 8 + i * ((this.widthVp - 16) / Math.max(1, this.candidates.length)),
          y: this.fontBarTop() - this.candBarHeightVp })
        .backgroundColor(Color.Transparent)
        .opacity(0.02)
        .hitTestBehavior(HitTestMode.None)
        .id('a11y_cand_' + i.toString())
        .onClick(() => { this.onCandidatePick(i); })
    }, (cand: string, i: number) => cand + i.toString())
  }

  aboutToDisappear(): void {
    hilog.info(CDOMAIN, CTAG, 'frame clock pause');
    this.frameClock?.pause();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Canvas(this.ctxStatic)
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .onReady(() => {
          this.staticReady = true;
          this.drawStatic();
        })
      Canvas(this.ctx)
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .onReady(() => {
          this.ctx.font = '24vp CourierPrime';
          const probeW: number = this.ctx.measureText('Hello, World! 0123456789').width;
          hilog.info(CDOMAIN, CTAG, 'canvas ready w=%{public}s h=%{public}s fontProbeW=%{public}s',
            this.widthVp.toFixed(1), this.heightVp.toFixed(1), probeW.toFixed(2));
        })
      // Phase 2 前置：文字层（最上层 Canvas）。拱/纸后续转原生 transform 时，文字仍压在它们之上。
      Canvas(this.ctxText)
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .onReady(() => {
          this.textReady = true;
          this.drawTextOverlay();
        })
      // 2C：Canvas 页透明原生锚点（SpotlightOverlay getRectangleById 用；不参与命中）
      Column().id('typewriter__paper').width(this.paperWidthVp).height(this.paperContainerVp)
        .position({ x: this.paperX(), y: this.paperY() })
        .opacity(0.01).hitTestBehavior(HitTestMode.None)
      Column().id('typewriter__lever').width(this.widthVp * 0.20).height(this.carriageHeightVp)
        .position({ x: this.widthVp * 0.76, y: this.carriageTopVp })
        .opacity(0.01).hitTestBehavior(HitTestMode.None)
      Column().id('typewriter__function_row').width(this.widthVp).height(this.functionRowHeightVp)
        .position({ x: 0, y: this.heightVp - this.bottomInset - this.functionRowHeightVp })
        .opacity(0.01).hitTestBehavior(HitTestMode.None)
      if (this.a11yEnabled) {
        this.a11yLayer()
      }
      // TopBar 保留 ArkUI 叠加；位置由同一几何算出（x=0 因 stage 宽=窗口宽，y=topInset）
      TopBar({
        title: this.docTitle,
        heightVp: TOP_BAR_HEIGHT_VP,
        guideEnabled: this.guideEnabled,
        onOpenHome: (): void => { this.onOpenHome(); },
        onOpenMenu: (): void => { this.onOpenMenu(); },
      })
        .id('canvas_topbar')
        .width(this.widthVp)
        .position({ x: 0, y: this.topInset })
      // IME 锚点透明层（2A 只挂载、不接事件）
      TextInput({ placeholder: '' })
        .id('cn_anchor')
        .width(1).height(1).opacity(0.01)
        .hitTestBehavior(HitTestMode.None)
        .position({ x: this.paperX() + this.marginHVp, y: this.paperY() + this.cursorYVp })
    }
    .width('100%')
    .height('100%')
    .onTouch((e: TouchEvent): void => { this.onCanvasTouch(e); })
  }
}




