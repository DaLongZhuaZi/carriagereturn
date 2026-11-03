/**
 * 字车条（§2.1）：55vp 照片条，各机 carriage-strip.png 满宽铺底。
 * 带高宽比：2048×287（约 7.14:1），铺满宽度即约 55vp（390vp 宽时）。
 * $rawfile 只接受编译期常量 → 按机型静态分支。
 */
import { MachineKind } from '../model/DocModel';

@Component
export struct CarriageStrip {
  @Prop machineKind: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop heightVp: number = 55;
  /** 换行回位位移（vp），由主屏驱动；静止为 0。 */
  @Prop shiftVp: number = 0;

  build() {
    Stack() {
      if (this.machineKind === MachineKind.UPRIGHT_1920S) {
        Image($rawfile('carriage/1920s-upright-carriage-strip.png')).width('100%').height('100%').objectFit(ImageFit.Fill)
      } else if (this.machineKind === MachineKind.PORTABLE_1930S) {
        Image($rawfile('carriage/1930s-portable-carriage-strip.png')).width('100%').height('100%').objectFit(ImageFit.Fill)
      } else if (this.machineKind === MachineKind.STREAMLINED_1950S) {
        Image($rawfile('carriage/1950s-streamlined-carriage-strip.png')).width('100%').height('100%').objectFit(ImageFit.Fill)
      } else {
        Image($rawfile('carriage/1960s-electric-carriage-strip.png')).width('100%').height('100%').objectFit(ImageFit.Fill)
      }
    }
    .width('100%')
    .height(this.heightVp)
    .translate({ x: this.shiftVp })
    .clip(true)
  }
}
