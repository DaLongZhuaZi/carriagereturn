/**
 * 回车 · 主屏（界面重设计稿 §2.1 纵向构成 + §2.2 纸张生长，2026-11-04 修正版）
 *
 * 纵向：顶栏 56 → 纸面区上边距 4 → 纸面区（弹性）→ 字车条 55（上叠，压住纸片下缘 8vp）
 *       → 字体条 38 → 键盘 238（照片键区 186 + 功能行 52）。
 * 底是深底渐变 #171310 → #241c16（§9：hero 整机图不进主屏，只用于解锁庆祝背景）。
 * 参考尺寸 390×844，其余按比例缩放 scale = min(w/390, h/844)，结构不变。
 *
 * 纸片：下缘锚定在字车条上缘下方 8vp；新纸 96vp 起长，每换行 +1 行高，
 *       满纸面区高度后停止生长、改为内容弹簧上移（creep）。
 */

import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { curves, display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MachineKind, PaperKind, RibbonKind } from '../model/DocModel';
import {
  CARRIAGE_PAPER_OVERLAP_VP, CARRIAGE_STRIP_HEIGHT_VP, DEFAULT_FONT, DEFAULT_MACHINE, DEFAULT_PAPER,
  DEFAULT_RIBBON, FONT_BAR_HEIGHT_VP, FUNCTION_ROW_HEIGHT_VP, KEYBED_HEIGHT_VP, PAPER_TOP_GAP_VP,
  TOP_BAR_HEIGHT_VP, findFont, findMachine, findPaper, findRibbon, fontDisplayName,
} from '../model/MachineCatalog';
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

const TAG: string = 'MainScreen';
const DOMAIN: number = 0x0100;
const DESIGN_WIDTH_VP: number = 390;
const DESIGN_HEIGHT_VP: number = 844;
const GROW_DURATION_MS: number = 260;

@Entry
@Component
struct Index {
  private docModel: DocModel = new DocModel();
  private audioService: AudioService = new AudioService();
  private uiScale: number = 1;

  @State rows: PaperRow[] = [];
  @State machineKind: MachineKind = DEFAULT_MACHINE;
  @State paperKind: PaperKind = DEFAULT_PAPER;
  @State ribbon: RibbonKind = DEFAULT_RIBBON;
  @State hintText: string = '';
  @State docTitle: string = '';
  @State inkColor: string = '#1a1a1a';

  @State topBarHeight: number = TOP_BAR_HEIGHT_VP;
  @State paperTopGap: number = PAPER_TOP_GAP_VP;
  @State carriageHeight: number = CARRIAGE_STRIP_HEIGHT_VP;
  @State fontBarHeight: number = FONT_BAR_HEIGHT_VP;
  @State keybedHeight: number = KEYBED_HEIGHT_VP;
  @State functionRowHeight: number = FUNCTION_ROW_HEIGHT_VP;

  /** 纸面区满高（纸片可生长的上限）。 */
  @State regionHeightVp: number = 461;
  /** 当前纸片高（弹簧动画）。 */
  @State paperHeightVp: number = PAPER_INITIAL_HEIGHT_VP;
  /** 满幅后内容上移量（弹簧动画）。 */
  @State creepOffsetVp: number = 0;
  @State lineHeightVp: number = 28;
  @State fontSizeVp: number = 17;
  @State fontFamily: string = 'CourierPrime';

  aboutToAppear(): void {
    const host = this.getUIContext().getHostContext();
    if (host !== undefined && host !== null) {
      this.audioService.attachContext(host as common.Context);
    }
    this.measureLayout();
    this.applyMachine(DEFAULT_MACHINE);
    this.applyPaper(DEFAULT_PAPER);
    this.applyRibbon(DEFAULT_RIBBON);
    this.hintText = this.resolveString($r('app.string.hint_new_paper'));
    this.docTitle = this.docModel.title(this.resolveString($r('app.string.doc_untitled')));
    this.syncRows();
    this.audioService.preload(findMachine(DEFAULT_MACHINE).kind === MachineKind.UPRIGHT_1920S ? 'pack' : 'pack');
  }

  aboutToDisappear(): void {
    this.audioService.release();
  }

  // ---------------- 布局测量 ----------------

  private measureLayout(): void {
    try {
      const d = display.getDefaultDisplaySync();
      const widthVp: number = this.getUIContext().px2vp(d.width);
      const heightVp: number = this.getUIContext().px2vp(d.height);
      const sx: number = widthVp / DESIGN_WIDTH_VP;
      const sy: number = heightVp / DESIGN_HEIGHT_VP;
      this.uiScale = sx < sy ? sx : sy;
      this.topBarHeight = TOP_BAR_HEIGHT_VP * this.uiScale;
      this.paperTopGap = PAPER_TOP_GAP_VP * this.uiScale;
      this.carriageHeight = CARRIAGE_STRIP_HEIGHT_VP * this.uiScale;
      this.fontBarHeight = FONT_BAR_HEIGHT_VP * this.uiScale;
      this.keybedHeight = KEYBED_HEIGHT_VP * this.uiScale;
      this.functionRowHeight = FUNCTION_ROW_HEIGHT_VP * this.uiScale;
      // 字车条上叠 8vp，故它实际占位 = 高度 − 重叠
      const carriageConsumed: number = this.carriageHeight - CARRIAGE_PAPER_OVERLAP_VP * this.uiScale;
      this.regionHeightVp = heightVp - this.topBarHeight - this.paperTopGap - carriageConsumed
        - this.fontBarHeight - this.keybedHeight - this.functionRowHeight;
      hilog.info(DOMAIN, TAG, 'layout scale=%{public}s region=%{public}s',
        this.uiScale.toFixed(3), this.regionHeightVp.toFixed(1));
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'measureLayout failed: %{public}s', JSON.stringify(err));
    }
  }

  // ---------------- 换装 ----------------

  private applyMachine(kind: MachineKind): void {
    this.machineKind = kind;
    this.docModel.setMachine(kind);
  }

  /** 换纸 / 换字体：按新行高重算纸片高（§2.2）。换机不改纸片高。 */
  private applyPaper(kind: PaperKind): void {
    this.paperKind = kind;
    const paper = findPaper(kind);
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

  /** 按行数重算纸片高与 creep 偏移（未满幅生长、满幅走纸）。 */
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

  /** 弹簧动画地重算纸片高（换行时调用）。 */
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

  // ---------------- 换行（§7.3 第 7 步；拨杆层第 4 步接） ----------------

  private onNewline(): void {
    this.hintText = '';
    this.docModel.newline();
    this.syncRows();
    this.animatePaperHeight();
    this.audioService.playCarriageReset();
    this.audioService.vibrate();
  }

  private syncRows(): void {
    const lines = this.docModel.getLines();
    const next: PaperRow[] = [];
    const cursor = this.docModel.getCursor();
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
    Column() {
      TopBar({ title: this.docTitle, heightVp: this.topBarHeight })

      Column() {
        Column().width('100%').height(this.paperTopGap)

        // 纸面区：上部空出的是深底渐变背景，不是纸
        Stack({ alignContent: Alignment.Bottom }) {
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
          })
            .width('100%')

          Row() {
            PageRail({ pageNo: 1, pageCount: 1 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.End)
          .alignItems(VerticalAlign.Top)
          .padding({ right: 6, top: 8 })
          .hitTestBehavior(HitTestMode.Transparent)
        }
        .width('100%')
        .layoutWeight(1)
        .clip(true)
      }
      .width('100%')
      .layoutWeight(1)

      // 字车条：上叠，压住纸片下缘 8vp
      CarriageStrip({ machineKind: this.machineKind, heightVp: this.carriageHeight })
        .width('100%')
        .margin({ top: -CARRIAGE_PAPER_OVERLAP_VP * this.uiScale })

      FontBar({
        fontFamily: this.fontFamily,
        fontLabel: fontDisplayName(DEFAULT_FONT),
        heightVp: this.fontBarHeight,
      })

      PhotoKeybed({ machineKind: this.machineKind, foldBand: false, heightVp: this.keybedHeight })

      FunctionRow({
        heightVp: this.functionRowHeight,
        langLabel: this.resolveString($r('app.string.keyboard_lang_zh')) + '/' + this.resolveString($r('app.string.keyboard_lang_en')),
        deleteLabel: this.resolveString($r('app.string.keyboard_delete')),
        newlineLabel: this.resolveString($r('app.string.keyboard_newline')),
        onNewline: (): void => {
          this.onNewline();
        },
      })
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [['#171310', 0.0], ['#241c16', 1.0]],
    })
  }
}
