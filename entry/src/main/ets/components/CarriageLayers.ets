/**
 * 字车分层（§2.8，仅 1920s-upright 启用）
 *
 * 容器：宽 = 舞台宽、clip、背景主屏深底渐变；高 Hc = (舞台宽 + 最大行程) / 7.14。
 * 宽画布：宽 = 舞台宽 + 最大行程、高 Hc，画布 x = carriageOffset（0 → −最大行程），四层同进同退。
 *
 * 四层全部用比例落位（不用母版像素）：
 *  滚筒   x=0,y=0,w=画布宽,h=Hc；源图 3200×502 纵向居中裁至 7.14（Cover 在 7.14 容器上即此裁切）；JPG 无 alpha
 *  压纸卷 x=0,y=0,w=画布宽,h=画布宽/15.32（2789/182），顶对齐容器顶
 *  旋钮   边长 = Hc×0.92，y=(Hc−边长)/2；左 x=0，右 x=画布宽−边长
 *  中央件 Hg=Hc×1.5，宽=Hg×0.848（1138/1342）；x=画布宽/2−宽/2；顶 y = 打击行 y − Hg×0.550
 *         打击行 y = 容器顶 − 12vp，故中央件向上伸出容器（本组件根不 clip，只有滚筒组 clip）
 */
import { curves } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const CDOMAIN: number = 0x0100;
const CTAG: string = 'CarriageLayers';

@Component
export struct CarriageLayers {
  /** 舞台宽（vp）。 */
  @Prop stageWidth: number = 390;
  /** 最大行程（vp）。 */
  @Prop maxTravelVp: number = 136;
  /** 当前偏移（vp，0 → −maxTravelVp）。 */
  @Prop carriageOffsetVp: number = 0;
  /** 总成竖向 jolt（vp）。 */
  @Prop joltYVp: number = 0;
  /** 旋钮累计转角（度）：走纸期间线性增加、不回零；打字时只平移不转。 */
  @Prop knobAngleDeg: number = 0;
  /** 渲染部位：'roller' 只画滚筒（在纸后）；'metal' 只画压纸卷+中央件+旋钮（在纸前）。 */
  @Prop part: string = 'roller';
  /** 中央件窗中心的目标 y（相对本组件顶，vp）；'metal' 时按它反推中央件顶。 */
  @Prop strikeYVp: number = -1;

  /** 容器高 Hc。 */
  private hc(): number {
    return (this.stageWidth + this.maxTravelVp) / 7.14;
  }

  private canvasW(): number {
    return this.stageWidth + this.maxTravelVp;
  }

  /** 打击点屏 x（相对容器左缘）：固定，不随 carriageOffset / 光标变化。 */
  private strikeXVp(): number {
    return this.stageWidth * 0.5;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // ---- 滚筒（纸后，仅 part='roller'）----
      if (this.part === 'roller') {
        Stack({ alignContent: Alignment.TopStart }) {
        // 滚筒：不透明 JPG，7.14 容器上 Cover = 纵向居中裁掉上下各 27px，不拉伸、不走 alpha
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

      // ---- 压纸卷 + 中央件 + 旋钮（纸前，仅 part='metal'）----
      if (this.part === 'metal') {
        // 压纸卷：辊子落在纸面上（打击行上方 4vp），x 随 O
        Image($rawfile('layers/1920s-upright/paper-bail.png'))
          .width(this.canvasW())
          .height(this.canvasW() / 15.32)
          .objectFit(ImageFit.Fill)
          .position({ x: this.carriageOffsetVp, y: this.strikeYVp - 4 - this.canvasW() / 15.32 })

        // 中央件：窗中心落在打击行，向上伸进纸面
        Image($rawfile('layers/1920s-upright/central-guide.png'))
          .width(this.hc() * 1.5 * 0.848)
          .height(this.hc() * 1.5)
          .objectFit(ImageFit.Contain)
          .position({
            x: this.canvasW() / 2 - this.hc() * 1.5 * 0.848 / 2 + this.carriageOffsetVp,
            y: this.strikeYVp - this.hc() * 1.5 * 0.550,
          })

        // 左旋钮（y 与滚筒中心同高，x = 滚筒端 + O）
        Image($rawfile('layers/1920s-upright/knob.png'))
          .width(this.hc() * 0.92)
          .height(this.hc() * 0.92)
          .objectFit(ImageFit.Contain)
          .position({ x: 0 + this.carriageOffsetVp, y: (this.hc() - this.hc() * 0.92) / 2 })
          .rotate({ angle: this.knobAngleDeg })

        // 右旋钮
        Image($rawfile('layers/1920s-upright/knob.png'))
          .width(this.hc() * 0.92)
          .height(this.hc() * 0.92)
          .objectFit(ImageFit.Contain)
          .position({ x: this.canvasW() - this.hc() * 0.92 + this.carriageOffsetVp, y: (this.hc() - this.hc() * 0.92) / 2 })
          .rotate({ angle: this.knobAngleDeg })
      }

      // ---- 缝隙小三角（8vp 缝隙内）：尖朝上顶纸底缘，底座落字车顶缘，屏 x 恒为舞台中心 ----
      Path()
        .width(10)
        .height(8)
        .commands('M5 0 L10 8 L0 8 Z')
        .fill('#e8ddc9')
        .stroke('#15120e')
        .strokeWidth(1)
        .position({ x: this.stageWidth * 0.5 - 5, y: -8 })
    }
    .width(this.stageWidth)
    .height(this.hc())
    .translate({ y: this.joltYVp })
    // §2.9：外层不 clip，否则中央件上半被切；只留滚筒组内层 clip
    .clip(false)
    .onAreaChange((oldA: Area, newA: Area) => {
      const w: number = newA.width as number;
      const topY: number = newA.globalPosition.y as number;
      hilog.info(CDOMAIN, CTAG,
        'carriage w=%{public}s Hc=%{public}s canvasW=%{public}s topY=%{public}s bottomY=%{public}s',
        w.toFixed(1), this.hc().toFixed(1), this.canvasW().toFixed(1),
        topY.toFixed(1), (topY + this.hc()).toFixed(1));
    })
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [['#171310', 0.0], ['#241c16', 1.0]],
    })
  }
}
