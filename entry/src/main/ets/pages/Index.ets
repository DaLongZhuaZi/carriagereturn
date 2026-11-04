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
import { CorrectionMode, MachineKind, PaperKind, RibbonKind } from '../model/DocModel';
import {
  CARRIAGE_PAPER_OVERLAP_VP, DEFAULT_FONT, DEFAULT_MACHINE, DEFAULT_PAPER, DEFAULT_RIBBON,
  FONT_BAR_HEIGHT_VP, FUNCTION_ROW_HEIGHT_VP, PAPER_TOP_GAP_VP, TOP_BAR_HEIGHT_VP,
  findFont, findMachine, findPaper, findRibbon, fontDisplayName,
} from '../model/MachineCatalog';
import { CapDef, KeymapLayout, KeymapParser, readRawTextSync } from '../model/KeymapModel';
import { PaperRow } from '../ui/PaperSheet';
import { DocModel } from '../model/DocModelCore';
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

const TAG: string = 'MainScreen';
const DOMAIN: number = 0x0100;
const DESIGN_W: number = 390;
const DESIGN_H: number = 844;
/** 键带手机宽高比 2048/975；字车条 2048/287。 */
const KEYBAND_ASPECT: number = 2048 / 975;
const CARRIAGE_STRIP_ASPECT: number = 2048 / 287;
const GROW_DURATION_MS: number = 260;
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
    this.syncRows();
    this.audioService.preload('pack');
  }

  aboutToDisappear(): void {
    this.audioService.release();
  }

  // ---------------- §2.5 舞台几何 ----------------

  private measureStage(): void {
    try {
      const d = display.getDefaultDisplaySync();
      const w: number = this.getUIContext().px2vp(d.width);
      const hRaw: number = this.getUIContext().px2vp(d.height);
      // §2.9：可用高 = 窗口高 − topInset − bottomInset，不许再用全屏高
      const h: number = hRaw - this.topInset - this.bottomInset;
      const byHeight: number = h * DESIGN_W / DESIGN_H;
      const stageW: number = w < byHeight ? w : byHeight;
      this.stageWidth = stageW;
      this.stageHeight = h;
      this.topBarHeight = TOP_BAR_HEIGHT_VP;
      this.paperTopGap = PAPER_TOP_GAP_VP;
      // 照片高度只由宽高比派生（不设 uiScale）
      // 照片宽 = 舞台宽 + 最大行程；高按 (舞台宽+行程)/7.14 派生，否则 Contain 会把宽图缩回舞台宽、平移失效
      this.maxTravelVp = stageW * 0.35 < 180 ? stageW * 0.35 : 180;
      this.carriageHeight = (stageW + this.maxTravelVp) / CARRIAGE_STRIP_ASPECT;
      this.fontBarHeight = FONT_BAR_HEIGHT_VP;
      this.keybedHeight = stageW / KEYBAND_ASPECT;
      this.functionRowHeight = FUNCTION_ROW_HEIGHT_VP;
      const carriageConsumed: number = this.carriageHeight - CARRIAGE_PAPER_OVERLAP_VP;
      const region: number = h - this.topBarHeight - this.paperTopGap - carriageConsumed
        - this.fontBarHeight - this.keybedHeight - this.functionRowHeight;
      this.regionHeightVp = region > 120 ? region : 120;
      this.recalcTravel();
      hilog.info(DOMAIN, TAG, 'stage w=%{public}s h=%{public}s region=%{public}s',
        stageW.toFixed(1), h.toFixed(1), this.regionHeightVp.toFixed(1));
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
    // §2.1 平移宽图：最大行程 = min(舞台宽 × 0.35, 180)
    const byWidth: number = this.stageWidth * 0.35;
    this.maxTravelVp = byWidth < 180 ? byWidth : 180;
    this.travelPerChar = this.maxTravelVp / this.charsPerLineNum;
    hilog.info(DOMAIN, TAG, 'recalcTravel max=%{public}s perChar=%{public}s cpl=%{public}s',
      this.maxTravelVp.toFixed(2), this.travelPerChar.toFixed(3), this.charsPerLineNum.toString());
  }

  /** 每落一字：字车条左移一格（70ms 弹簧快步）。 */
  private stepCarriageLeft(): void {
    let target: number = this.carriageOffsetVp - this.travelPerChar;
    if (target < -this.maxTravelVp) {
      target = -this.maxTravelVp;
    }
    this.getUIContext().animateTo({ duration: 70, curve: curves.springCurve(0, 1, 260, 20) }, () => {
      this.carriageOffsetVp = target;
    });
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
    this.getUIContext().animateTo({ duration: 250, curve: curves.springMotion() }, () => {
      this.carriageOffsetVp = 0;
    });
  }

  // ---------------- 换装 ----------------

  private applyMachine(kind: MachineKind): void {
    this.machineKind = kind;
    this.docModel.setMachine(kind);
  }

  private applyPaper(kind: PaperKind): void {
    this.paperKind = kind;
    const machine = findMachine(this.machineKind);
    this.lineHeightVp = machine.englishLineHeightVp;
    this.fontSizeVp = machine.fontScale;
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
      hilog.info(DOMAIN, TAG, 'layers available=%{public}s count=%{public}s', all ? 'true' : 'false', names.length.toString());
    } catch (e) {
      this.useLayers = false;
      hilog.error(DOMAIN, TAG, 'detectLayers failed, fallback to strip');
    }
  }

  // ---------------- 纸片 ----------------

  private recalcPaperHeight(): void {
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
    const lineCount: number = this.docModel.getLines().length;
    const rawHeight: number = PAPER_INITIAL_HEIGHT_VP + (lineCount - 1) * this.lineHeightVp;
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
    const usable: number = this.stageWidth - 2 * findPaper(this.paperKind).marginH;
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
    this.audioService.playKey();
    this.audioService.vibrate();
    this.queueChar(cap.label.toLowerCase());
  }

  private queueChar(ch: string): void {
    this.pendingChars.push(ch);
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
    this.flushPending();
  }

  private commitChar(ch: string): void {
    this.hintText = '';
    const outcome = this.docModel.insertText(ch, this.charsPerLine());
    this.syncRows();
    this.animateGuide();
    this.stepCarriageLeft();
    if (outcome.marginBell) {
      this.audioService.playBell();
    }
    // 行满自动换行：同样走换行回位，不许让字车条停在行末位置开始下一行
    if (this.docModel.getCursor().offset >= this.charsPerLineNum) {
      this.onNewline();
    }
  }

  private animateGuide(): void {
    const target: number = findPaper(this.paperKind).marginH + this.currentLineWidthVp();
    this.getUIContext().animateTo({ duration: 90, curve: curves.springCurve(0, 1, 240, 20) }, () => {
      this.guideXVp = target;
    });
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

          Stack({ alignContent: Alignment.Bottom }) {
            if (this.machineKind === MachineKind.UPRIGHT_1920S) {
              // 字杆层：尺寸由 stageWidth 派生；支点锚定字车条下方（笼子位置）
              TypebarLayer({
                layerWidthVp: this.stageWidth,
                layerHeightVp: this.stageWidth,
                strikeTick: this.strikeTick,
                animScale: 1,
                offsetXVp: this.guideXVp - this.stageWidth * 0.5,
                offsetYVp: this.regionHeightVp + 0.752 * this.stageWidth - this.stageWidth * 0.867,
                onArrive: (): void => {
                  this.onStrikeArrive();
                },
              })
            }

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
                cursorXVp: this.guideXVp,
                cursorVisible: true,
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
            .width('100%')
            .height(this.paperHeightVp)
            .offset({ y: 0 })
          }
          .width('100%')
          .layoutWeight(1)
          .clip(true)
        }
        .width('100%')
        .layoutWeight(1)

        if (this.machineKind === MachineKind.UPRIGHT_1920S && this.useLayers) {
          CarriageLayers({
            stageWidth: this.stageWidth,
            maxTravelVp: this.maxTravelVp,
            carriageOffsetVp: this.carriageOffsetVp,
          })
            .margin({ top: -CARRIAGE_PAPER_OVERLAP_VP })
        } else {
          CarriageStrip({
            machineKind: this.machineKind,
            widthVp: this.stageWidth,
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
          widthVp: this.stageWidth,
          heightVp: this.keybedHeight,
          layout: this.keymapLayout,
          overlayFontFamily: this.fontFamily,
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
