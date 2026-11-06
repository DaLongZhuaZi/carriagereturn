/**
 * 回车 · 纸面舞台（界面重设计稿 §2.2 纸张生长与走纸，2026-11-04 定稿）
 *
 * 核心模型（几何自洽）：
 * - 纸片下缘锚定在字车条上缘下方 8vp，换行/走纸时下缘不动；纸片向上生长。
 * - 已落字从**纸片顶缘**起算（所以纸片长高时，字随纸片一起上移）。
 * - 纸片高 = 初始 96 + 行数 × 行高（未满幅）；满幅后高度不变，内容整体上移（creep）。
 * - 由此推出：当前打击行永远落在「纸片底缘 − 底边距 20vp」上方，无需单独推位置。
 *
 * 模型 B（2026-11-05）：纸高按屏高百分比三态生长；光标为墨色小三角，尖朝下悬在下一字上方。
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
  /** 小三角光标：x 相对纸片左缘、y 相对纸片顶（vn），尖朝下悬在下一字正上方。 */
  @Prop cursorXVp: number = 28;
  @Prop cursorYVp: number = 0;
  @Prop cursorVisible: boolean = true;
  /** 纸在容器里的可见底缘 y（相对纸片顶）：柱面渐变与接缝线画在这里。 */
  @Prop visibleBottomVp: number = 0;
  /** 纸与字车共用的偏移 O（vp，≤0）：纸随 O 左移，与字车同弹簧同帧。 */
  @Prop offsetXVp: number = 0;


  /** 纸底柱面收尾高度：只做轻微视觉收尾，取 min(15vp, 可见高×15%)。 */
  private curlH(): number {
    // 纸向下弯进滚筒的卷曲阴影：固定 40vp（不超过可见纸高）
    return this.visibleBottomVp > 40 ? 40 : this.visibleBottomVp;
  }

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
            // 字距就是 advance 本身：显式写 0，防后来人加正值导致落字与渲染脱节
            .letterSpacing(0)
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

      // 小三角光标：墨色、尖朝下，只留一个，不画竖线
      if (this.cursorVisible) {
        Path()
          .width(8)
          .height(6)
          .commands('M0 0 L8 0 L4 6 Z')
          .fill(this.inkColor)
          .position({ x: this.cursorXVp, y: this.cursorYVp >= 0 ? this.cursorYVp : 0 })
          .hitTestBehavior(HitTestMode.None)
      }

      // 纸卷左右两缘暗边：暗示卷的侧面厚度（立体感）
      if (this.visibleBottomVp > 0) {
        Row() {
          Column()
            .width(3)
            .height('100%')
            .linearGradient({
              direction: GradientDirection.Right,
              colors: [['rgba(0,0,0,0.22)', 0.0], ['rgba(0,0,0,0)', 1.0]],
            })
          Column()
            .width(3)
            .height('100%')
            .linearGradient({
              direction: GradientDirection.Left,
              colors: [['rgba(0,0,0,0.22)', 0.0], ['rgba(0,0,0,0)', 1.0]],
            })
        }
        .width('100%')
        .height(this.visibleBottomVp)
        .position({ x: 0, y: 0 })
        .hitTestBehavior(HitTestMode.None)
      }

      // 纸卷柱面：纸底 34vp 向下渐暗，模拟纸面包着滚筒弯下去
      if (this.visibleBottomVp > 40) {
        Column()
          .width('100%')
          .height(this.curlH())
          .linearGradient({
            direction: GradientDirection.Bottom,
            // 最暗点挪到 0.80，最后 20% 不再加深（0.30 封顶），与滚筒在该处亮度衔接
            colors: [['rgba(0,0,0,0)', 0.0], ['rgba(30,20,12,0.18)', 0.45],
              ['rgba(30,20,12,0.30)', 0.80], ['rgba(30,20,12,0.30)', 1.0]],
          })
          .position({ x: 0, y: this.visibleBottomVp - this.curlH() })
          .hitTestBehavior(HitTestMode.None)

        // 接缝线已删（v11：纸底不许画硬边/黑线/描边）；交界靠渐变与滚筒明暗衔接
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
    .translate({ x: this.offsetXVp })
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
