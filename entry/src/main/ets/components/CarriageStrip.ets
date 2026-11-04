/**
 * 字车条（§2.1）：55vp 照片条 + 代码叠画的字车导件。
 *
 * 导件口径（2026-11-04 用户定）：照片本身不动，照片里的中央金属件只是机器部件；
 * 打击点由代码在字车条上叠画一根竖向导件指示，x 随光标走，初始在文本区左缘。
 * 换行时导件回左缘，且照片做一小段向右滑动回位（幅度 ≤16vp，不许整条平移一整行）。
 */
import { MachineKind } from '../model/DocModel';

@Component
export struct CarriageStrip {
  @Prop machineKind: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop heightVp: number = 55;
  /** 舞台宽（vp）：字车条宽 = 舞台宽，高由 2048/287 宽高比派生。 */
  @Prop widthVp: number = 390;
  /** 照片宽 = 舞台宽 + 最大行程（§2.1 平移宽图）；容器仍是舞台宽。 */
  @Prop photoWidthVp: number = 390;
  /** 导件 x（vp，相对字车条左缘）。 */
  @Prop guideXVp: number = 28;
  /** 字车条累计左移量（vp，负值左移，行首 0）；导件不随它平移。 */
  @Prop carriageOffsetVp: number = 0;
  @Prop guideVisible: boolean = true;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.machineKind === MachineKind.UPRIGHT_1920S) {
        Image($rawfile('carriage/1920s-upright-carriage-strip.png')).width(this.photoWidthVp).height(this.photoWidthVp / 7.14).objectFit(ImageFit.Contain)
          .translate({ x: this.carriageOffsetVp })
      } else if (this.machineKind === MachineKind.PORTABLE_1930S) {
        Image($rawfile('carriage/1930s-portable-carriage-strip.png')).width(this.photoWidthVp).height(this.photoWidthVp / 7.14).objectFit(ImageFit.Contain)
          .translate({ x: this.carriageOffsetVp })
      } else if (this.machineKind === MachineKind.STREAMLINED_1950S) {
        Image($rawfile('carriage/1950s-streamlined-carriage-strip.png')).width(this.photoWidthVp).height(this.photoWidthVp / 7.14).objectFit(ImageFit.Contain)
          .translate({ x: this.carriageOffsetVp })
      } else {
        Image($rawfile('carriage/1960s-electric-carriage-strip.png')).width(this.photoWidthVp).height(this.photoWidthVp / 7.14).objectFit(ImageFit.Contain)
          .translate({ x: this.carriageOffsetVp })
      }

      // 竖向导件：2vp 深的竖条，指向纸面打击点
      if (this.guideVisible) {
        Column()
          .width(2)
          .height(this.heightVp * 0.82)
          .backgroundColor('#e8ddc9')
          .opacity(0.85)
          .borderRadius(1)
          .position({ x: this.guideXVp - 1, y: this.heightVp * 0.10 })
      }
    }
    .width(this.widthVp)
    .height(this.photoWidthVp / 7.14)
    .clip(true)
    // 字车条左移时右侧露出的是深底，不留白：容器背景与主屏同一渐变（§2.1）
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [['#171310', 0.0], ['#241c16', 1.0]],
    })
  }
}