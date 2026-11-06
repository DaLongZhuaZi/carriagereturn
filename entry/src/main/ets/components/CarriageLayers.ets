/**
 * 字车分层（§2.9 纸屏左起算，2026-11-05）
 *
 * 全部 x 从「纸屏左」（布局左 + O）起算：
 *   中央件 x = 纸屏左 + marginH + 已落字总宽 − 中央件宽/2（打击点，随字右移）
 *   压纸卷 x = 纸屏左 − 旋钮直径
 *   左旋钮 x = 纸屏左 − 直径 − 4；右旋钮 x = 纸屏左 + Pw + 4
 *   Hc = Pw×0.17；中央件 Hg = Hc×1.5、宽 = Hg×0.848；旋钮直径 = Hc×0.92
 */
import { hilog } from '@kit.PerformanceAnalysisKit';

const CDOMAIN: number = 0x0100;
const CTAG: string = 'CarriageLayers';

@Component
export struct CarriageLayers {
  @Prop stageWidth: number = 390;
  /** 纸宽 Pw（vp）。 */
  @Prop paperWidthVp: number = 242;
  /** 纸屏左 = 布局左 + O（vp，相对舞台左缘）。 */
  @Prop paperLeftVp: number = 74;
  /** 打击点 x（= 纸屏左 + marginH + 已落字总宽，相对舞台左缘）。 */
  @Prop strikeXVp: number = 102;
  @Prop joltYVp: number = 0;
  @Prop knobAngleDeg: number = 0;
  /** 滚筒纹理转角（与旋钮同角，纹理须能旋转）。 */
  @Prop rollerAngleDeg: number = 0;
  @Prop part: string = 'roller';
  /** 中央件窗中心 y（相对金属顶）。 */
  @Prop strikeYVp: number = 0;
  /** 画布横向偏移（滚筒等宽图件用，一般等于 O）。 */
  @Prop canvasOffsetVp: number = 0;

  private hc(): number {
    return this.paperWidthVp * 0.17;
  }

  private knobD(): number {
    return this.hc() * 0.92;
  }

  /** 压纸卷带长 = 纸宽 + 2×旋钮直径。 */
  /** 压纸卷横杆与纸卷同宽（左右对齐纸缘），不再加旋钮直径。 */
  private bailW(): number {
    return this.paperWidthVp;
  }

  /** 木底座宽 = Pw + 2×knobD（整机最宽，左右各出纸缘一个旋钮直径）。 */
  private baseW(): number {
    return this.paperWidthVp + 2 * this.knobD();
  }

  /** 木底座左缘 = 纸左缘 − knobD。 */
  private baseLeft(): number {
    return this.paperLeftVp - this.knobD();
  }

  /** 木底座顶 = 滚筒中心 + Hc/2 + 2vp（组件顶 = 滚筒顶，故相对 y = Hc + 2）。 */
  private baseTop(): number {
    return this.hc() + 2;
  }

  /** 沟槽左右：底座内缩 10vp。 */
  private grooveLeft(): number {
    return this.baseLeft() + 10;
  }

  private grooveW(): number {
    return this.baseW() - 20;
  }

  /** 沟槽顶 = 底座顶面下 6vp。 */
  private grooveTop(): number {
    return this.baseTop() + 6;
  }

  /** 铭牌左 = 底座左缘 + 底座宽×0.32 − 55。 */
  private plateLeft(): number {
    return this.baseLeft() + this.baseW() * 0.32 - 55;
  }

  private canvasW(): number {
    return this.stageWidth + 2 * this.hc();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.part === 'roller') {
        Stack({ alignContent: Alignment.TopStart }) {
          // 滚筒纹理：不旋转。rotate 是屏面内 2D 转动，横滚筒转 59° 会斜、换纸转 360° 等于风车
          // 滚筒与纸卷同宽、左右对齐纸缘：不再横贯全宽（那是纸后宽暗带的来源）
          Image($rawfile('layers/1920s-upright/roller-texture.jpg'))
            .width(this.paperWidthVp)
            .height(this.hc())
            .objectFit(ImageFit.Cover)
            .position({ x: this.paperLeftVp - this.canvasOffsetVp, y: 0 })

          // 柱面感：上亮下暗的纵向明暗，暗示直径 Hc 的圆柱曲面
          Column()
            .width(this.paperWidthVp)
            .height(this.hc())
            .position({ x: this.paperLeftVp - this.canvasOffsetVp, y: 0 })
            .linearGradient({
              direction: GradientDirection.Bottom,
              colors: [
                ['rgba(255,246,230,0.22)', 0.0],
                ['rgba(0,0,0,0)', 0.45],
                ['rgba(0,0,0,0.30)', 0.82],
                ['rgba(0,0,0,0.55)', 1.0],
              ],
            })

          // 滚筒后进纸边：纸从滚筒后卷入，滚筒下缘露出一截纸边
          Row()
            .width(this.paperWidthVp)
            .height(5)
            .backgroundColor('#e8ddc9')
            .opacity(0.85)
            .position({ x: this.paperLeftVp, y: this.hc() - 5 })
        }
        .width(this.stageWidth)
        .height(this.hc())
        .clip(true)
        .translate({ x: this.canvasOffsetVp })
      }

      if (this.part === 'basket') {
        // 字杆篮扇面：纸后、滚筒前的独立层。宽度比纸宽（两侧各留 80vp），
        // 只在纸左右两侧与纸下方露出扇形竖杆，绝不盖纸面。容器不 clip。
        Image($rawfile('layers/1920s-upright/typebar-basket-strip.png'))
          .width(this.paperWidthVp + 160)
          .height((this.paperWidthVp + 160) * 0.213)
          .objectFit(ImageFit.Fill)
          .opacity(0.6)
          .position({
            x: this.paperLeftVp - 80,
            // 扇面顶约在 carrTop − 70vp；组件顶 = carrTop − Hc/2，故相对 y = Hc/2 − 70
            y: this.hc() / 2 - 70,
          })
      }

      if (this.part === 'metal') {
        // 字杆篮扇面：字车后方（压暗 0.6）。放在 metal 件里才不会被子层级 clip 掉
        // 木底座（整机最宽）：宽 = Pw + 2×knobD，左右各出纸缘一个旋钮直径；顶在滚筒中心 + Hc/2 + 2vp
        Image($rawfile('layers/1920s-upright/carriage-base-rail.png'))
          .width(this.baseW())
          .height(this.baseW() / 7.562)
          .objectFit(ImageFit.Fill)
          .position({ x: this.baseLeft(), y: this.baseTop() })
          .zIndex(0)

        // 沟槽：高 14vp，槽顶在底座顶面下 6vp；槽内深色 + 上缘高光 + 下缘阴影
        Column()
          .width(this.grooveW())
          .height(14)
          .backgroundColor('#120d08')
          .opacity(0.92)
          .position({ x: this.grooveLeft(), y: this.grooveTop() })
          .zIndex(1)
        Column()
          .width(this.grooveW())
          .height(2)
          .backgroundColor('rgba(255,255,255,0.19)')
          .position({ x: this.grooveLeft(), y: this.grooveTop() })
          .zIndex(2)
        Column()
          .width(this.grooveW())
          .height(2)
          .backgroundColor('rgba(0,0,0,0.4)')
          .position({ x: this.grooveLeft(), y: this.grooveTop() + 12 })
          .zIndex(2)

        // 铭牌：黄铜小牌 110×26，嵌在沟槽中左（中心 = 底座左缘 + 底座宽×0.32）
        Column() {
          Text('1920s')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3a2410')
            .textAlign(TextAlign.Center)
            .width('100%')
        }
        .width(110)
        .height(26)
        .borderRadius(4)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [['#f0d79a', 0.0], ['#c9a45c', 0.55], ['#8a6a2f', 1.0]],
        })
        .position({ x: this.plateLeft(), y: this.grooveTop() - 6 })
        .zIndex(3)

        // 压纸卷：x = 纸屏左 − 旋钮直径
        // 压纸卷 v2（深色钢杆＋两个黑滚轮，素材 2736×283）：杆宽 = 纸宽、对齐纸缘
        Image($rawfile('layers/1920s-upright/paper-bail-v2.png'))
          .width(this.bailW())
          .height(this.bailW() / 9.6678)
          .objectFit(ImageFit.Fill)
          .position({
            x: this.paperLeftVp,
            // 辊子中心贴滚筒轴线 y = Hc/2
            y: this.hc() / 2 - this.bailW() / 9.6678 / 2,
          })

        // 中央件：x = 打击点 − 宽/2
        Image($rawfile('layers/1920s-upright/central-guide.png'))
          .width(this.hc() * 1.5 * 0.848)
          .height(this.hc() * 1.5)
          .objectFit(ImageFit.Contain)
          .position({
            x: this.strikeXVp - this.hc() * 1.5 * 0.848 / 2,
            y: this.strikeYVp - this.hc() * 1.5 * 0.550,
          })

        // 本批撤掉两枚圆形旋钮：真机正面只见旋钮侧面而非整面圆盘，
        // 现两个大圆盘摆在纸卷两端像轮子。knobAngle 逻辑保留，待按「只露侧面」重设计外观。
      }
    }
    .width(this.stageWidth)
    .height(this.hc())
    .translate({ y: this.joltYVp })
    .clip(false)
    .onAreaChange((oldA: Area, newA: Area) => {
      hilog.info(CDOMAIN, CTAG,
        'part=%{public}s Hc=%{public}s Pw=%{public}s paperL=%{public}s strikeX=%{public}s',
        this.part, this.hc().toFixed(1), this.paperWidthVp.toFixed(1),
        this.paperLeftVp.toFixed(1), this.strikeXVp.toFixed(1));
    })
    // 根 Stack 不许铺整块不透明深底：金属件（zIndex 3）在纸之上，
    // 该深底会盖住纸的下半截（实测纸从 103.5vp 缩到 77.3vp）。各件均为独立 Image，无需底色。
  }
}
