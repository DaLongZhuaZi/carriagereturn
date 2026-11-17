/**
 * 第 32 批（25 号稿 §2.2）：钢板 —— 键床底板。
 * 拉丝贴片（Tile，plate-<machine>.png）＋纵向／横向渐变（±0.02／±0.03 L）＋四条 2vp 斜面带；圆角 12vp。
 */
import { MachineKind } from '../model/DocModel';
import { plateRawfile, shiftHexColor, tierToken } from '../model/MachineCatalog';

@Component
export struct SteelPlate {
  @Prop machine: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop widthVp: number = 354.7;
  @Prop heightVp: number = 172.7;

  /** 斜面 ΔL：1920s/1930s ±0.02、1960s ±0.03、1950s ±0.05（25 号稿 §2.2）。 */
  private bevelDL(): number {
    if (this.machine === MachineKind.STREAMLINED_1950S) { return 0.05; }
    if (this.machine === MachineKind.ELECTRIC_1960S) { return 0.03; }
    return 0.02;
  }

  private steel(): string {
    return tierToken(this.machine, 'steel');
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 拉丝底纹（不透明，平铺）
      Column()
        .width('100%').height('100%')
        .backgroundColor(this.steel())
        .backgroundImage($rawfile(plateRawfile(this.machine)), ImageRepeat.XY)
      // 纵向渐变：顶 +0.02、底 −0.02 L
      Column()
        .width('100%').height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [[shiftHexColor(this.steel(), 0.02), 0.0], [shiftHexColor(this.steel(), -0.02), 1.0]],
        })
        .opacity(0.18)
      // 横向渐变：左 +0.03、右 −0.03 L
      Column()
        .width('100%').height('100%')
        .linearGradient({
          direction: GradientDirection.Right,
          colors: [[shiftHexColor(this.steel(), 0.03), 0.0], [shiftHexColor(this.steel(), -0.03), 1.0]],
        })
        .opacity(0.18)
      // 斜面带 2vp：上／下通长，左／右内缩 2vp
      Column()
        .width('100%').height(2)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [[shiftHexColor(this.steel(), this.bevelDL()), 0.0], [shiftHexColor(this.steel(), 0.0), 1.0]],
        })
        .position({ x: 0, y: 0 })
      Column()
        .width('100%').height(2)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [[shiftHexColor(this.steel(), 0.0), 0.0], [shiftHexColor(this.steel(), -this.bevelDL()), 1.0]],
        })
        .position({ x: 0, y: this.heightVp - 2 })
      Column()
        .width(2).height(this.heightVp - 4)
        .linearGradient({
          direction: GradientDirection.Right,
          colors: [[shiftHexColor(this.steel(), this.bevelDL()), 0.0], [shiftHexColor(this.steel(), 0.0), 1.0]],
        })
        .position({ x: 0, y: 2 })
      Column()
        .width(2).height(this.heightVp - 4)
        .linearGradient({
          direction: GradientDirection.Right,
          colors: [[shiftHexColor(this.steel(), 0.0), 0.0], [shiftHexColor(this.steel(), -this.bevelDL()), 1.0]],
        })
        .position({ x: this.widthVp - 2, y: 2 })
    }
    .width(this.widthVp)
    .height(this.heightVp)
    .borderRadius(12)
    .clip(true)
    .hitTestBehavior(HitTestMode.None)
  }
}
