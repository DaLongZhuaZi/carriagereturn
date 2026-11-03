/**
 * 回车 · 主屏（第 3/4 步：照片键区 + 击打链闭合）
 *
 * 纵向构成与纸张生长已是第 1/2 步定稿，本步只接：键位图叠字与触摸、功能行、击打链。
 *
 * 击打链（§7.3，顺序钉死，同一 Down 回调内前四步）：
 *   帽上高亮（组件内）→ 播音 → 震动 → 字杆摆动 → 杆到位同帧落字 → 光标/导件前进 → 行末铃 → 换行
 * 仅 1920s 有字杆动画层；其余三台不编造动画层，落字在播音同拍完成（时序仍按同一回调）。
 */

import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { curves, display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { resourceManager } from '@kit.LocalizationKit';
import { CorrectionMode, MachineKind, PaperKind, RibbonKind } from '../model/DocModel';
import {
  CARRIAGE_PAPER_OVERLAP_VP, CARRIAGE_STRIP_HEIGHT_VP, DEFAULT_FONT, DEFAULT_MACHINE, DEFAULT_PAPER,
  DEFAULT_RIBBON, FONT_BAR_HEIGHT_VP, FUNCTION_ROW_HEIGHT_VP, KEYBED_HEIGHT_VP, PAPER_TOP_GAP_VP,
  TOP_BAR_HEIGHT_VP, findFont, findMachine, findPaper, findRibbon, fontDisplayName,
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

const TAG: string = 'MainScreen';
const DOMAIN: number = 0x0100;
const DESIGN_WIDTH_VP: number = 390;
const DESIGN_HEIGHT_VP: number = 844;
const GROW_DURATION_MS: number = 260;
/** 微距：行末预告铃触发阈值（距右边界约 8 字）。 */
const BELL_REMAINING: number = 8;

@Entry
@Component
struct Index {
  private docModel: DocModel = new DocModel();
  private audioService: AudioService = new AudioService();
  private uiScale: number = 1;
  private screenWidthVp: number = 390;
  /** 待落字队列：字杆到位后按序落字（同帧保证）。 */
  private pendingChars: string[] = [];
  private bellRungLines: Set<number> = new Set<number>();

  @State rows: PaperRow[] = [];
  @State machineKind: MachineKind = DEFAULT_MACHINE;
  @State paperKind: PaperKind = DEFAULT_PAPER;
  @State ribbon: RibbonKind = DEFAULT_RIBBON;
  @State hintText: string = '';
  @State docTitle: string = '';
  @State inkColor: string = '#1a1a1a';
  @State keymapLayout: KeymapLayout = KeymapParser.parse(
    '{"master_size":[2048,2048],"rows":[],"space":{"x_min":0,"x_max":0,"y_min":0,"y_max":0},"bands":{"phone":{"x0":0,"y0":0,"w":2048,"h":975},"fold":{"x0":0,"y0":0,"w":2048,"h":853}},"overlay":{}}',
    '', false, 390, 186, '#312b24', 14);

  @State topBarHeight: number = TOP_BAR_HEIGHT_VP;
  @State paperTopGap: number = PAPER_TOP_GAP_VP;
  @State carriageHeight: number = CARRIAGE_STRIP_HEIGHT_VP;
  @State fontBarHeight: number = FONT_BAR_HEIGHT_VP;
  @State keybedHeight: number = KEYBED_HEIGHT_VP;
  @State functionRowHeight: number = FUNCTION_ROW_HEIGHT_VP;

  @State regionHeightVp: number = 461;
  @State paperHeightVp: number = PAPER_INITIAL_HEIGHT_VP;
  @State creepOffsetVp: number = 0;
  @State lineHeightVp: number = 28;
  @State fontSizeVp: number = 17;
  @State fontFamily: string = 'CourierPrime';

  /** 字车导件 x（vp，相对字车条左缘）。 */
  @State guideXVp: number = 28;
  /** 字车条照片回位位移（vp，≤16）。 */
  @State photoShiftVp: number = 0;
  /** 字杆击打触发计数。 */
  @State strikeTick: number = 0;
  @State langZh: boolean = false;
  @State correctionMode: CorrectionMode = CorrectionMode.MODERN;

  aboutToAppear(): void {
    const host = this.getUIContext().getHostContext();
    if (host !== undefined && host !== null) {
      this.audioService.attachContext(host as common.Context);
    }
    this.measureLayout();
    this.applyMachine(DEFAULT_MACHINE);
    this.applyPaper(DEFAULT_PAPER);
    this.applyRibbon(DEFAULT_RIBBON);
    this.reloadKeymap();
    this.hintText = this.resolveString($r('app.string.hint_new_paper'));
    this.docTitle = this.docModel.title(this.resolveString($r('app.string.doc_untitled')));
    this.syncRows();
    this.audioService.preload('pack');
  }

  aboutToDisappear(): void {
    this.audioService.release();
  }

  // ---------------- 布局 ----------------

  private measureLayout(): void {
    try {
      const d = display.getDefaultDisplaySync();
      const widthVp: number = this.getUIContext().px2vp(d.width);
      const heightVp: number = this.getUIContext().px2vp(d.height);
      this.screenWidthVp = widthVp;
      const sx: number = widthVp / DESIGN_WIDTH_VP;
      const sy: number = heightVp / DESIGN_HEIGHT_VP;
      this.uiScale = sx < sy ? sx : sy;
      this.topBarHeight = TOP_BAR_HEIGHT_VP * this.uiScale;
      this.paperTopGap = PAPER_TOP_GAP_VP * this.uiScale;
      this.carriageHeight = CARRIAGE_STRIP_HEIGHT_VP * this.uiScale;
      this.fontBarHeight = FONT_BAR_HEIGHT_VP * this.uiScale;
      this.keybedHeight = KEYBED_HEIGHT_VP * this.uiScale;
      this.functionRowHeight = FUNCTION_ROW_HEIGHT_VP * this.uiScale;
      const carriageConsumed: number = this.carriageHeight - CARRIAGE_PAPER_OVERLAP_VP * this.uiScale;
      this.regionHeightVp = heightVp - this.topBarHeight - this.paperTopGap - carriageConsumed
        - this.fontBarHeight - this.keybedHeight - this.functionRowHeight;
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

  private applyPaper(kind: PaperKind): void {
    this.paperKind = kind;
    const paper = findPaper(kind);
    const machine = findMachine(this.machineKind);
    this.lineHeightVp = machine.englishLineHeightVp;
    this.fontSizeVp = machine.fontScale;
    this.fontFamily = findFont(DEFAULT_FONT).familyName;
    this.docModel.setPaper(kind);
    this.recalcPaperHeight();
    hilog.info(DOMAIN, TAG, 'paper=%{public}s margin=%{public}s', kind, paper.marginH.toString());
  }

  private applyRibbon(kind: RibbonKind): void {
    this.ribbon = kind;
    this.inkColor = findRibbon(kind).inkColor;
    this.docModel.setRibbon(kind);
  }

  /** 载入当前机型的键位坐标表（带坐标 = 母版坐标 − 带 y0，再按带宽缩放）。 */
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
        this.screenWidthVp, this.keybedHeight, spec.overlayColor, spec.overlayFontSizeVp);
      hilog.info(DOMAIN, TAG, 'keymap caps=%{public}s', this.keymapLayout.caps.length.toString());
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'reloadKeymap failed: %{public}s', JSON.stringify(err));
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

  /** 每字宽（vp）：英文等宽约 0.6em，中文全角 1em。 */
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

  private charsPerLine(): number {
    const usable: number = this.screenWidthVp - 2 * findPaper(this.paperKind).marginH;
    const n: number = Math.floor(usable / (this.fontSizeVp * 0.6));
    return n > 6 ? n : 6;
  }

  /** 帽按下当刻（同一回调内：播音 → 震动 → 杆/落字）。 */
  private onCapDown(cap: CapDef): void {
    if (cap.isExtra) {
      return; // extra 帽：不叠字、不落字、不发声
    }
    if (cap.label === ' ') {
      this.audioService.playSpace();
      this.audioService.vibrate();
      this.queueChar(' ');
      return;
    }
    if (cap.label === 'Shift' || cap.label === 'Backspace' || cap.label === 'Return') {
      // 照片键区里的功能帽：Shift 暂无锁定态语义，Backspace/Return 走删除/换行
      if (cap.label === 'Backspace') {
        this.onDelete();
      } else if (cap.label === 'Return') {
        this.onNewline();
      }
      return;
    }
    this.audioService.playKey();
    this.audioService.vibrate();
    this.queueChar(cap.label.toLowerCase());
  }

  /** 入队并触发击打；1920s 走字杆到位回调，其余机型直接落字（同一回调内、时序不变）。 */
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
    if (outcome.marginBell) {
      this.onMarginBell();
    }
  }

  private onMarginBell(): void {
    this.audioService.playBell();
    hilog.info(DOMAIN, TAG, 'margin bell');
  }

  private animateGuide(): void {
    const target: number = findPaper(this.paperKind).marginH + this.currentLineWidthVp();
    this.getUIContext().animateTo({
      duration: 90,
      curve: curves.springCurve(0, 1, 240, 20),
    }, () => {
      this.guideXVp = target;
    });
  }

  // ---------------- 删除 / 换行 ----------------

  private onDelete(): void {
    this.audioService.playBackspace();
    this.audioService.vibrate();
    if (this.correctionMode === CorrectionMode.OVERWRITE) {
      const o2 = this.docModel.overwriteBack();
      if (o2.changed) {
        this.syncRows();
        this.animateGuide();
      }
      return;
    }
    const o = this.docModel.backspace();
    if (o.changed) {
      this.syncRows();
      this.animateGuide();
    }
  }

  private onNewline(): void {
    this.hintText = '';
    this.docModel.newline();
    this.syncRows();
    this.animatePaperHeight();
    this.audioService.playCarriageReset();
    this.audioService.vibrate();
    this.animateCarriageReturn();
  }

  /** 换行回位：导件回左缘 + 字车条照片 ≤16vp 向右滑动再弹回（不许整条平移一整行）。 */
  private animateCarriageReturn(): void {
    const base: number = findPaper(this.paperKind).marginH;
    this.getUIContext().animateTo({ duration: 120, curve: curves.springCurve(0, 1, 220, 18) }, () => {
      this.photoShiftVp = 12;
    });
    this.getUIContext().animateTo({ duration: 260, delay: 120, curve: curves.springMotion() }, () => {
      this.photoShiftVp = 0;
    });
    this.getUIContext().animateTo({ duration: 200, curve: curves.springMotion() }, () => {
      this.guideXVp = base;
    });
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
    this.docTitle = this.docModel.title(this.resolveString($r('app.string.doc_untitled')));
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

        Stack({ alignContent: Alignment.Bottom }) {
          // 字杆层（仅 1920s）：支点落在字车条上缘，随导件水平跟手
          if (this.machineKind === MachineKind.UPRIGHT_1920S && this.regionHeightVp > 80) {
            TypebarLayer({
              layerWidthVp: this.regionHeightVp * 0.9,
              layerHeightVp: this.regionHeightVp * 0.9,
              strikeTick: this.strikeTick,
              animScale: 1,
              offsetXVp: this.guideXVp - this.regionHeightVp * 0.45,
              offsetYVp: this.regionHeightVp - this.regionHeightVp * 0.9 * 0.867,
              onArrive: (): void => {
                this.onStrikeArrive();
              },
            })
          }

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

      CarriageStrip({
        machineKind: this.machineKind,
        heightVp: this.carriageHeight,
        guideXVp: this.guideXVp,
        photoShiftVp: this.photoShiftVp,
        guideVisible: true,
      })
        .width('100%')
        .margin({ top: -CARRIAGE_PAPER_OVERLAP_VP * this.uiScale })

      FontBar({
        fontFamily: this.fontFamily,
        fontLabel: fontDisplayName(DEFAULT_FONT),
        heightVp: this.fontBarHeight,
      })

      PhotoKeybed({
        machineKind: this.machineKind,
        foldBand: false,
        widthVp: this.screenWidthVp,
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
          // 视觉回弹由组件内部处理
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
          // §7.2 双通道切换：中文通道（系统输入法 attach）下一步接入
          this.langZh = !this.langZh;
        },
        onDelete: (): void => {
          this.onDelete();
        },
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
