/**
 * 字车分层（§2.9 纸为锚点，2026-11-05）
 *
 * 全部尺寸由纸派生，不用舞台宽：
 *   Pw = 纸宽、Ph = 纸高；Hc = Pw×0.17
 *   中央件 Hg = Hc×1.5、宽 = Hg×0.848，窗中心 = 打击行，x = 纸中心 + O
 *   旋钮直径 = Hc×0.92，x 在纸宽之外（左 = 纸左缘 − 直径 − 4vp，右 = 纸右缘 + 4vp），y 与滚筒中心同高
 *   压纸卷带长 = 纸宽 + 2×旋钮直径，辊子落在纸面上
 *   part='roller' 只画滚筒（纸后）；part='metal' 只画压纸卷+中央件+旋钮（纸前）
 */
import { hilog } from '@kit.PerformanceAnalysisKit';

const CDOMAIN: number = 0x0100;
const CTAG: string = 'CarriageLayers';

@Component
export struct CarriageLayers {
  /** 舞台宽（vp）：只用于画布宽。 */
  @Prop stageWidth: number = 390;
  /** 纸宽（vp）。 */
  @Prop paperWidthVp: number = 242;
  /** 纸中心 x（相对舞台左缘，vp）。 */
  @Prop paperCenterXVp: number = 195;
  /** 最大行程（vp）。 */
  @Prop maxTravelVp: number = 334;
  @Prop carriageOffsetVp: number = 0;
  @Prop joltYVp: number = 0;
  @Prop knobAngleDeg: number = 0;
  @Prop part: string = 'roller';
  /** 中央件窗中心 y（相对金属顶，vp）。 */
  @Prop strikeYVp: number = 0;

  /** 滚筒高 Hc = 纸宽 × 0.17。 */
  private hc(): number {
    return this.paperWidthVp * 0.17;
  }

  private canvasW(): number {
    return this.stageWidth + this.maxTravelVp;
  }

  /** 旋钮直径 = Hc×0.92。 */
  private knobD(): number {
    return this.hc() * 0.92;
  }

  /** 纸左缘 x（相对舞台左缘）。 */
  private paperLeft(): number {
    return this.paperCenterXVp - this.paperWidthVp / 2;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.part === 'roller') {
        Stack({ alignContent: Alignment.TopStart }) {
          Image($rawfile('layers/1920s-upright/roller-texture.jpg'))
            .width(this.canvasW())
            .height(this.hc())
            .objectFit(ImageFit.Cover)
        }
        .width(this.canvasW())
        .height(this.hc())
        .clip(true)
        .translate({ x: this.carriageOffsetVp })
      }

      if (this.part === 'metal') {
        // 压纸卷：带长 = 纸宽 + 2×旋钮直径，辊子压在纸面上
        Image($rawfile('layers/1920s-upright/paper-bail.png'))
          .width(this.paperWidthVp + 2 * this.knobD())
          .height((this.paperWidthVp + 2 * this.knobD()) / 15.32)
          .objectFit(ImageFit.Fill)
          .position({
            x: this.paperLeft() - this.knobD() + this.carriageOffsetVp,
            y: this.strikeYVp - 6 - (this.paperWidthVp + 2 * this.knobD()) / 15.32,
          })

        // 中央件：Hg = Hc×1.5，窗中心 = 打击行，x = 纸中心 + O
        Image($rawfile('layers/1920s-upright/central-guide.png'))
          .width(this.hc() * 1.5 * 0.848)
          .height(this.hc() * 1.5)
          .objectFit(ImageFit.Contain)
          .position({
            x: this.paperCenterXVp - this.hc() * 1.5 * 0.848 / 2 + this.carriageOffsetVp,
            y: this.strikeYVp - this.hc() * 1.5 * 0.550,
          })

        // 左旋钮：纸左缘 − 直径 − 4vp
        Image($rawfile('layers/1920s-upright/knob.png'))
          .width(this.knobD())
          .height(this.knobD())
          .objectFit(ImageFit.Contain)
          .position({
            x: this.paperLeft() - this.knobD() - 4 + this.carriageOffsetVp,
            y: this.hc() / 2 - this.knobD() / 2,
          })
          .rotate({ angle: this.knobAngleDeg })

        // 右旋钮：纸右缘 + 4vp
        Image($rawfile('layers/1920s-upright/knob.png'))
          .width(this.knobD())
          .height(this.knobD())
          .objectFit(ImageFit.Contain)
          .position({
            x: this.paperLeft() + this.paperWidthVp + 4 + this.carriageOffsetVp,
            y: this.hc() / 2 - this.knobD() / 2,
          })
          .rotate({ angle: this.knobAngleDeg })
      }
    }
    .width(this.stageWidth)
    .height(this.hc())
    .translate({ y: this.joltYVp })
    .clip(false)
    .onAreaChange((oldA: Area, newA: Area) => {
      const w: number = newA.width as number;
      hilog.info(CDOMAIN, CTAG, 'part=%{public}s w=%{public}s Hc=%{public}s Pw=%{public}s',
        this.part, w.toFixed(1), this.hc().toFixed(1), this.paperWidthVp.toFixed(1));
    })
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [['#171310', 0.0], ['#241c16', 1.0]],
    })
  }
}
