/**
 * 回车 · 主屏（界面重设计稿 §2.1 纵向构成 · 第 1 步）
 *
 * 纵向：顶栏 56 → 纸面区上边距 4 → 纸面（弹性，390×844 下 461）→ 字车条 55（与纸面 -8 重叠）
 *       → 字体条 38 → 键盘 238（照片键区 186 + 功能行 52）。
 * 参考尺寸 390×844，其余尺寸按比例缩放（scale = min(w/390, h/844)），不改结构。
 *
 * 本步只做「机器 / 纸 / 键盘连成一台」的构成；键盘触摸与叠字在第 3 步接入，
 * 纸面舞台与行内光标在第 2 步重做。文档模型、存储、音效引擎保持不动。
 */

import { BusinessError } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MachineKind, PaperKind } from '../model/DocModel';
import {
  CARRIAGE_PAPER_OVERLAP_VP, CARRIAGE_STRIP_HEIGHT_VP, DEFAULT_FONT, DEFAULT_MACHINE, DEFAULT_PAPER,
  FONT_BAR_HEIGHT_VP, FUNCTION_ROW_HEIGHT_VP, KEYBED_HEIGHT_VP, PAPER_TOP_GAP_VP, TOP_BAR_HEIGHT_VP,
  findFont, findMachine, findPaper, fontDisplayName,
} from '../model/MachineCatalog';
import { PageRail } from '../components/PageRail';
import { PaperRow, PaperViewSpec } from '../ui/PaperSheet';
import { DocModel } from '../model/DocModelCore';
import { TopBar } from '../components/TopBar';
import { CarriageStrip } from '../components/CarriageStrip';
import { FontBar } from '../components/FontBar';
import { PhotoKeybed } from '../components/PhotoKeybed';
import { FunctionRow } from '../components/FunctionRow';
import { PaperSheet } from '../components/PaperSheet';

const TAG: string = 'MainScreen';
const DOMAIN: number = 0x0100;
const DESIGN_WIDTH_VP: number = 390;
const DESIGN_HEIGHT_VP: number = 844;

@Entry
@Component
struct Index {
  private docModel: DocModel = new DocModel();
  /** 参考尺寸 → 真机尺寸的缩放比。 */
  private uiScale: number = 1;

  @State rows: PaperRow[] = [];
  @State activeLine: number = 0;
  @State hintText: string = '';
  @State docTitle: string = '';
  @State machineKind: MachineKind = DEFAULT_MACHINE;
  @State paperSpec: PaperViewSpec = {
    paperKind: DEFAULT_PAPER,
    paperTexture: 'paper/paper-letter.jpg',
    paperWidthVp: 390,
    fontSizeVp: 17,
    lineHeightRatio: 1.647,
    marginHVp: 28,
    marginVVp: 24,
    fontFamily: 'CourierPrime',
    hasGrid: false,
    hasHeader: true,
  };
  @State topBarHeight: number = TOP_BAR_HEIGHT_VP;
  @State paperTopGap: number = PAPER_TOP_GAP_VP;
  @State carriageHeight: number = CARRIAGE_STRIP_HEIGHT_VP;
  @State fontBarHeight: number = FONT_BAR_HEIGHT_VP;
  @State keybedHeight: number = KEYBED_HEIGHT_VP;
  @State functionRowHeight: number = FUNCTION_ROW_HEIGHT_VP;

  aboutToAppear(): void {
    this.measureLayout();
    this.applyMachine(DEFAULT_MACHINE);
    this.applyPaper(DEFAULT_PAPER);
    this.hintText = this.resolveString($r('app.string.hint_new_paper'));
    this.docTitle = this.docModel.title(this.resolveString($r('app.string.doc_untitled')));
    this.syncRows();
  }

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
      hilog.info(DOMAIN, TAG, 'layout scale=%{public}s width=%{public}s height=%{public}s',
        this.uiScale.toFixed(3), widthVp.toFixed(1), heightVp.toFixed(1));
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'measureLayout failed: %{public}s', JSON.stringify(err));
    }
  }

  private applyMachine(kind: MachineKind): void {
    this.machineKind = kind;
    this.docModel.setMachine(kind);
  }

  private applyPaper(kind: PaperKind): void {
    const paper = findPaper(kind);
    const machine = findMachine(this.machineKind);
    this.paperSpec = {
      paperKind: kind,
      paperTexture: paper.textureRawfile,
      paperWidthVp: DESIGN_WIDTH_VP * this.uiScale,
      fontSizeVp: machine.fontScale,
      lineHeightRatio: machine.englishLineHeightVp / machine.fontScale,
      marginHVp: paper.marginH,
      marginVVp: paper.marginTop,
      fontFamily: findFont(DEFAULT_FONT).familyName,
      hasGrid: paper.hasRuledGrid,
      hasHeader: paper.hasHeader,
    };
    this.docModel.setPaper(kind);
  }

  private syncRows(): void {
    const lines = this.docModel.getLines();
    const next: PaperRow[] = [];
    for (let i = 0; i < lines.length; i++) {
      const row: PaperRow = { line: i, text: lines[i].text, ribbon: lines[i].ribbon, active: i === 0 };
      next.push(row);
    }
    this.rows = next;
    this.activeLine = 0;
  }

  private resolveString(res: Resource): string {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx !== undefined && ctx !== null) {
        return ctx.resourceManager.getStringSync(res.id);
      }
    } catch (e) {
      // 资源缺失降级空串，绝不崩主屏
    }
    return '';
  }

  build() {
    Column() {
      TopBar({
        title: this.docTitle,
        heightVp: this.topBarHeight,
      })

      // 纸面区（弹性）：上边距 4 + 纸面
      Column() {
        Column().width('100%').height(this.paperTopGap)
        Stack({ alignContent: Alignment.TopStart }) {
          PaperSheet({
            spec: this.paperSpec,
            rows: this.rows,
            hintText: this.hintText,
            activeLine: this.activeLine,
          })
            .width('100%')
            .height('100%')

          // 页码轨：贴纸面右缘（不占顶栏、不遮正文；正文右侧 44vp 安全区由纸面边距保证）
          Row() {
            PageRail({ pageNo: 1, pageCount: 1 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.End)
          .alignItems(VerticalAlign.Top)
          .padding({ right: 6, top: 64 })
          .hitTestBehavior(HitTestMode.Transparent)
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .layoutWeight(1)

      // 字车条：与纸面下缘重叠 8vp，让纸像从机器里穿出来
      CarriageStrip({
        machineKind: this.machineKind,
        heightVp: this.carriageHeight,
      })
        .width('100%')
        .margin({ top: -CARRIAGE_PAPER_OVERLAP_VP * this.uiScale })

      FontBar({
        fontFamily: this.paperSpec.fontFamily,
        fontLabel: fontDisplayName(DEFAULT_FONT),
        heightVp: this.fontBarHeight,
      })

      PhotoKeybed({
        machineKind: this.machineKind,
        foldBand: false,
        heightVp: this.keybedHeight,
      })

      FunctionRow({
        heightVp: this.functionRowHeight,
        langLabel: this.resolveString($r('app.string.keyboard_lang_zh')) + '/' + this.resolveString($r('app.string.keyboard_lang_en')),
        deleteLabel: this.resolveString($r('app.string.keyboard_delete')),
        newlineLabel: this.resolveString($r('app.string.keyboard_newline')),
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#171310')
  }
}
