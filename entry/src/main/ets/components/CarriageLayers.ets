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

@Component
export struct CarriageLayers {
  /** 舞台宽（vp）。 */
  @Prop stageWidth: number = 390;
  /** 最大行程（vp）。 */
  @Prop maxTravelVp: number = 136;
  /** 当前偏移（vp，0 → −maxTravelVp）。 */
  @Prop carriageOffsetVp: number = 0;

  /** 容器高 Hc。 */
  private hc(): number {
    return (this.stageWidth + this.maxTravelVp) / 7.14;
  }

  private canvasW(): number {
    return this.stageWidth + this.maxTravelVp;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // ---- 滚筒 / 压纸卷 / 左手把，三件在宽画布内同进同退，由父级 clip 裁到舞台宽 ----
      Stack({ alignContent: Alignment.TopStart }) {
        // 滚筒：不透明 JPG，7.14 容器上 Cover = 纵向居中裁掉上下各 27px，不拉伸、不走 alpha
        Image($rawfile('layers/1920s-upright/roller-texture.jpg'))
          .width(this.canvasW())
          .height(this.hc())
          .objectFit(ImageFit.Cover)

        // 压纸卷：杆在上、两辊在下压滚筒上部；顶对齐容器顶
        Image($rawfile('layers/1920s-upright/paper-bail.png'))
          .width(this.canvasW())
          .height(this.canvasW() / 15.32)
          .objectFit(ImageFit.Contain)
          .position({ x: 0, y: 0 })

        // 左旋钮
        Image($rawfile('layers/1920s-upright/knob.png'))
          .width(this.hc() * 0.92)
          .height(this.hc() * 0.92)
          .objectFit(ImageFit.Contain)
          .position({ x: 0, y: (this.hc() - this.hc() * 0.92) / 2 })

        // 右旋钮（同一张复用）
        Image($rawfile('layers/1920s-upright/knob.png'))
          .width(this.hc() * 0.92)
          .height(this.hc() * 0.92)
          .objectFit(ImageFit.Contain)
          .position({ x: this.canvasW() - this.hc() * 0.92, y: (this.hc() - this.hc() * 0.92) / 2 })
      }
      .width(this.canvasW())
      .height(this.hc())
      .clip(true)
      .translate({ x: this.carriageOffsetVp })

      // ---- 中央件：机器坐标系，宽画布内居中，向上伸出容器（不被 clip）----
      Image($rawfile('layers/1920s-upright/central-guide.png'))
        .width(this.hc() * 1.5 * 0.848)
        .height(this.hc() * 1.5)
        .objectFit(ImageFit.Contain)
        .position({
          x: this.canvasW() / 2 - this.hc() * 1.5 * 0.848 / 2 + this.carriageOffsetVp,
          y: -12 - this.hc() * 1.5 * 0.550,
        })
    }
    .width(this.stageWidth)
    .height(this.hc())
    // §2.9：外层不 clip，否则中央件上半被切；只留滚筒组内层 clip
    .clip(false)
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [['#171310', 0.0], ['#241c16', 1.0]],
    })
  }
}
