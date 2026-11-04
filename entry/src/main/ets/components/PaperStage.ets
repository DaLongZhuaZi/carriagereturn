/**
 * 回车 · 纸面舞台（界面重设计稿 §2.2 纸张生长与走纸，2026-11-04 定稿）
 *
 * 核心模型（几何自洽）：
 * - 纸片下缘锚定在字车条上缘下方 8vp，换行/走纸时下缘不动；纸片向上生长。
 * - 已落字从**纸片顶缘**起算（所以纸片长高时，字随纸片一起上移）。
 * - 纸片高 = 初始 96 + 行数 × 行高（未满幅）；满幅后高度不变，内容整体上移（creep）。
 * - 由此推出：当前打击行永远落在「纸片底缘 − 底边距 20vp」上方，无需单独推位置。
 *
 * 纸面不画光标：打击点由字车条中央竖向导件指示（§2.2）。
 * 纸面区上部空出的部分是深底渐变背景（由 Index 铺），本组件只管纸片本身。
 */

import { PaperKind } from '../model/DocModel';
import { PaperRow } from '../ui/PaperSheet';
import { hilog } from '@kit.PerformanceAnalysisKit';

const PDOMAIN: number = 0x0100;
const PTAG: string = 'PaperStage';

/** 新纸初始高（vp）：顶边距 24 + 页眉区约 20 + 1 行 28 + 底边距 20 ≈ 92，取整 96。 */
export const PAPER_INITIAL_HEIGHT_VP: number = 96;

@Component
export struct PaperStage {
  /** 纸面区满高（vp）：纸片长到这个高度后停止生长，改为走纸。 */
  @Prop regionHeightVp: number = 461;
  /** 当前纸片高（vp），由 Index 做弹簧动画。 */
  @Prop paperHeightVp: number = PAPER_INITIAL_HEIGHT_VP;
  /** 满幅后内容上移量（vp，负值向上），由 Index 做弹簧动画。 */
  @Prop creepOffsetVp: number = 0;
  @Prop paperKind: PaperKind = PaperKind.LETTER;
  @Prop hasHeader: boolean = true;
  @Prop hasRuledGrid: boolean = false;
  @Prop rows: PaperRow[] = [];
  @Prop hintText: string = '';
  @Prop lineHeightVp: number = 28;
  @Prop fontSizeVp: number = 17;
  @Prop fontFamily: string = 'CourierPrime';
  @Prop marginHVp: number = 28;
  @Prop marginTopVp: number = 24;
  @Prop marginBottomVp: number = 20;
  /** 页眉带高度（vp）：双细线 + 页码所占。 */
  @Prop headerBandVp: number = 20;
  /** 墨色（色带）。 */
  @Prop inkColor: string = '#1a1a1a';
  @Prop pageNo: number = 1;
  /** 纸面光标 x（vp，相对纸片左缘）：舞台左缘 + 28 + 当前行已落字总宽。 */
  @Prop cursorXVp: number = 28;
  /** 纸面光标可见（行首也可，始终可见）。 */
  @Prop cursorVisible: boolean = true;

  /** 页眉带 + 顶边距 = 内容起始 y。 */
  private contentTop(): number {
    return this.marginTopVp + this.headerBandVp;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 纸纹：只铺纸片本身；圆角 12vp；下缘短实阴影（被字车条压住处的厚度感）
      if (this.paperKind === PaperKind.MANUSCRIPT) {
        Image($rawfile('paper/paper-manuscript.jpg')).width('100%').height('100%')
          .objectFit(ImageFit.Cover).borderRadius(12)
      } else if (this.paperKind === PaperKind.POSTCARD) {
        Image($rawfile('paper/paper-postcard.jpg')).width('100%').height('100%')
          .objectFit(ImageFit.Cover).borderRadius(12)
      } else if (this.paperKind === PaperKind.MEMO) {
        Image($rawfile('paper/paper-memo.jpg')).width('100%').height('100%')
          .objectFit(ImageFit.Cover).borderRadius(12)
      } else {
        Image($rawfile('paper/paper-letter.jpg')).width('100%').height('100%')
          .objectFit(ImageFit.Cover).borderRadius(12)
      }

      // 页眉双细线 + 右上角页码（随纸片顶缘一起上移）
      if (this.hasHeader) {
        Stack({ alignContent: Alignment.TopStart }) {
          Column()
            .width('100%')
            .height(1)
            .backgroundColor('#c8b9a6')
            .margin({ top: this.marginTopVp })
          Column()
            .width('100%')
            .height(1)
            .backgroundColor('#c8b9a6')
            .margin({ top: this.marginTopVp + 4 })
          // 页码：右上角（§2.2）
          Row() {
            Text(this.pageNo.toString())
              .fontSize(12)
              .fontColor('#8a7f70')
          }
          .width('100%')
          .padding({ right: this.marginHVp })
          .justifyContent(FlexAlign.End)
          .margin({ top: this.marginTopVp + 6 })
        }
        .width('100%')
        .height(this.contentTop())
      }

      // 稿纸红格 + 横线（代码画）：红格左线 + 每行一条 1vp 横线
      if (this.hasRuledGrid) {
        Column()
          .width(1)
          .height('100%')
          .backgroundColor('#c8a49a')
          .position({ x: this.marginHVp - 8, y: 0 })
      }

      // 已落字：从纸片顶缘起算，满幅后整体上移（creepOffsetVp）
      Column() {
        ForEach(this.rows, (row: PaperRow) => {
          Text(row.text.length > 0 ? row.text : ' ')
            .width('100%')
            .height(this.lineHeightVp)
            .fontSize(this.fontSizeVp)
            .fontColor(this.inkColor)
            .fontFamily(this.fontFamily)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Clip })
            .textAlign(TextAlign.Start)
        }, (row: PaperRow, index: number) => row.line.toString() + ':' + row.text.length.toString())
      }
      .width('100%')
      .padding({ left: this.marginHVp, right: this.marginHVp })
      .margin({ top: this.contentTop() })
      .translate({ y: this.creepOffsetVp })
      .clip(false)

      // 常驻引导：随第一行走，位置在纸片底部（不在纸面区顶部）
      if (this.rows.length <= 1 && this.hintText.length > 0) {
        // 引导文案：随第一行走、位置在纸片底部；左右边距必须真正落到文本区（§2.2 边距 28vp）。
        // 用底部对齐的 Column + padding 实现，不用 position（position 会绕过 padding 导致首字贴边）。
        Column() {
          Text(this.hintText)
            .width('100%')
            .fontSize(13)
            .fontColor('#8a7f70')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Start)
        }
        .width('100%')
        .padding({ left: this.marginHVp, right: this.marginHVp })
        .margin({ top: this.paperHeightVp - this.marginBottomVp - this.lineHeightVp })
      }

      // 纸面光标（§2.8 改名：画在纸面上，不是字车条上的细线）
      // y = 纸片下缘 − 20vp − 行高 至 纸片下缘 − 20vp，宽 2vp，颜色 = 当前墨色
      if (this.cursorVisible) {
        Column()
          .width(2)
          .height(this.lineHeightVp)
          .backgroundColor(this.inkColor)
          .position({ x: this.cursorXVp, y: this.paperHeightVp - this.marginBottomVp - this.lineHeightVp })
          .hitTestBehavior(HitTestMode.None)
      }

      // 下缘短实阴影（纸压在字车上）
      Column()
        .width('100%')
        .height(3)
        .backgroundColor('#33120e0a')
        .position({ x: 0, y: this.paperHeightVp - 3 })
    }
    .width('100%')
    .height(this.paperHeightVp)
    .clip(true)
    .onAreaChange((oldA: Area, newA: Area) => {
      // 取证：纸片 rect + 纸底 y + 纸片高（与 Keybed / CarriageLayers 同一次运行）
      const w: number = newA.width as number;
      const h: number = newA.height as number;
      const topY: number = newA.globalPosition.y as number;
      const leftX: number = newA.globalPosition.x as number;
      hilog.info(PDOMAIN, PTAG,
        'paper left=%{public}s w=%{public}s topY=%{public}s h=%{public}s bottomY=%{public}s',
        leftX.toFixed(1), w.toFixed(1), topY.toFixed(1), h.toFixed(1), (topY + h).toFixed(1));
    })
  }
}
