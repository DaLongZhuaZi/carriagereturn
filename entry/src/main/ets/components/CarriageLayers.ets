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
  private bailW(): number {
    return this.paperWidthVp + 2 * this.knobD();
  }

  private canvasW(): number {
    return this.stageWidth + 2 * this.hc();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.part === 'roller') {
        Stack({ alignContent: Alignment.TopStart }) {
          // 字杆篮扇面：字车后方（压暗 0.6），中间被纸与木底座挡住
          Image($rawfile('layers/1920s-upright/typebar-basket-strip.png'))
            .width(820)
            .height(175)
            .objectFit(ImageFit.Fill)
            .opacity(0.6)
            .position({ x: this.paperLeftVp + this.paperWidthVp / 2 - 410, y: -16 })

          // 滚筒纹理随转角旋转：换行/换纸时与旋钮同角
          Image($rawfile('layers/1920s-upright/roller-texture.jpg'))
            .width(this.canvasW())
            .height(this.hc())
            .objectFit(ImageFit.Cover)
            .rotate({ angle: this.rollerAngleDeg, centerX: this.canvasW() / 2, centerY: this.hc() / 2 })

          // 滚筒后进纸边：纸从滚筒后卷入，滚筒下缘露出一截纸边
          Row()
            .width(this.paperWidthVp)
            .height(5)
            .backgroundColor('#e8ddc9')
            .opacity(0.85)
            .position({ x: this.paperLeftVp, y: this.hc() - 5 })

          // 木底座：横在滚筒下方，宽 = Pw + 2×旋钮直径，高 83vp
          Image($rawfile('layers/1920s-upright/carriage-base-rail.png'))
            .width(this.paperWidthVp + 2 * this.knobD())
            .height(83)
            .objectFit(ImageFit.Fill)
            .position({ x: this.paperLeftVp - this.knobD(), y: this.hc() })
        }
        .width(this.stageWidth)
        .height(this.hc())
        .clip(true)
        .translate({ x: this.canvasOffsetVp })
      }

      if (this.part === 'metal') {
        // 压纸卷：x = 纸屏左 − 旋钮直径
        Image($rawfile('layers/1920s-upright/paper-bail.png'))
          .width(this.bailW())
          .height(this.bailW() / 15.32)
          .objectFit(ImageFit.Fill)
          .position({
            x: this.paperLeftVp - this.knobD(),
            // 压纸卷贴滚筒轴线：辊子中心 y = Hc/2（= 滚筒中心），横杆在当前行下方
            y: this.hc() / 2 - this.bailW() / 15.32 / 2,
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

        Image($rawfile('layers/1920s-upright/knob.png'))
          .width(this.knobD())
          .height(this.knobD())
          .objectFit(ImageFit.Contain)
          // 中心贴纸左缘（半个旋钮压在纸缘上），y = 滚筒中心
          .position({ x: this.paperLeftVp - this.knobD() / 2, y: this.hc() / 2 - this.knobD() / 2 })
          .rotate({ angle: this.knobAngleDeg })

        Image($rawfile('layers/1920s-upright/knob.png'))
          .width(this.knobD())
          .height(this.knobD())
          .objectFit(ImageFit.Contain)
          // 中心贴纸右缘
          .position({ x: this.paperLeftVp + this.paperWidthVp - this.knobD() / 2, y: this.hc() / 2 - this.knobD() / 2 })
          .rotate({ angle: this.knobAngleDeg })
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
