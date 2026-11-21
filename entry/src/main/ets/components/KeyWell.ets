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

  /** 批 75：井底按机型取年代底图（1170×582，Contain 铺满——沿用 v2 的做法，只换图）。 */
  private floorRawfile(): string {
    if (this.machine === MachineKind.UPRIGHT_1920S) { return 'ui-parts/keywell-floor-1920s.png'; }
    if (this.machine === MachineKind.PORTABLE_1930S) { return 'ui-parts/keywell-floor-1930s.png'; }
    if (this.machine === MachineKind.STREAMLINED_1950S) { return 'ui-parts/keywell-floor-1950s.png'; }
    if (this.machine === MachineKind.ELECTRIC_1960S) { return 'ui-parts/keywell-floor-1960s.png'; }
    return 'ui-parts/keywell-floor-2020s.png';
  }

  @Builder
  screw(x: number, y: number) {
    Circle().width(5).height(5).fill(tierToken(this.machine, 'steel'))
      .position({ x: x, y: y })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column().width('100%').height('100%').backgroundColor(this.wellColor())
      // 批 40（任务 2）：井底改预渲染贴图（中央亮、边缘暗的径向渐变，1:1 铺满井）
      Image($rawfile(this.floorRawfile()))
        .width('100%').height('100%').objectFit(ImageFit.Contain)
        .hitTestBehavior(HitTestMode.None)
      // 井内侧壁：上沿亮线、下沿暗线
      Column().width('100%').height(1.5).backgroundColor('#ffffff').opacity(0.12)
        .position({ x: 0, y: 0 })
        .hitTestBehavior(HitTestMode.None)
      Column().width('100%').height(2).backgroundColor('#000000').opacity(0.35)
        .position({ x: 0, y: this.heightVp - 2 })
        .hitTestBehavior(HitTestMode.None)
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
