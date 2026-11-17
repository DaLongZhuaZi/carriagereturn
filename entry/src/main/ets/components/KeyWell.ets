/**
 * 第 33 批（26 号稿 §7.8）：键盘黑井 —— 键床底板上的黑色井底，四角开孔露出钢板螺丝。
 * z 4.0（挂在 SteelPlate z 3.9 之后、KeyGrid 之前）。
 */
import { MachineKind } from '../model/DocModel';
import { tierToken } from '../model/MachineCatalog';

@Component
export struct KeyWell {
  @Prop machine: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop widthVp: number = 346.7;
  @Prop heightVp: number = 172.6;

  /** §10 键帽/井底 token：1920s #050506；其余机按同族深色（见批报告登记）。 */
  private wellColor(): string {
    if (this.machine === MachineKind.PORTABLE_1930S) { return '#070606'; }
    if (this.machine === MachineKind.STREAMLINED_1950S) { return '#0a0908'; }
    if (this.machine === MachineKind.ELECTRIC_1960S) { return '#080808'; }
    return '#050506';
  }

  @Builder
  screw(x: number, y: number) {
    Circle().width(5).height(5).fill(tierToken(this.machine, 'steel'))
      .position({ x: x, y: y })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column().width('100%').height('100%').backgroundColor(this.wellColor())
      // 四角螺丝（绝对坐标 (16,630)/(346,630)/(16,787)/(346,787)，本地 = 减挂载原点 (8,622.3)）
      this.screw(8 - 2.5, 7.7 - 2.5)
      this.screw(338 - 2.5, 7.7 - 2.5)
      this.screw(8 - 2.5, 164.7 - 2.5)
      this.screw(338 - 2.5, 164.7 - 2.5)
    }
    .width(this.widthVp)
    .height(this.heightVp)
    .borderRadius(10)
    .clip(true)
    .hitTestBehavior(HitTestMode.None)
  }
}
