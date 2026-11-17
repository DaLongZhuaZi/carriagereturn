/**
 * 第 31 批（24 号稿 §2.4／§6 批 31）：侧颊 —— 16vp 宽竖条，贴纸区左右两缘。
 * 背景取该机纸井档 token＋贴片（MachineCatalog.tierToken / tierTileRawfile）。
 */
import { MachineKind } from '../model/DocModel';
import { tierTileRawfile, tierToken } from '../model/MachineCatalog';

@Component
export struct Cheek {
  @Prop machine: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop heightVp: number = 258;

  build() {
    Column()
      .width(16)
      .height(this.heightVp)
      .backgroundColor(tierToken(this.machine, 'paperwell'))
      .backgroundImage($rawfile(tierTileRawfile(this.machine, 'paperwell')), ImageRepeat.XY)
      .hitTestBehavior(HitTestMode.None)
  }
}
