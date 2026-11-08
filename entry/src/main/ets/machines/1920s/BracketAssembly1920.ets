import { MachineKind } from '../../model/DocModel';

/**
 * 1920s 拨杆支架（§14 蓝图）：只是一张图，几何在蓝图里。
 * 常量与 7fd6305^ 原件一致（宽 60／÷0.8042／底座宽 = Pw + 2×knobD）。
 */
@Component
export struct BracketAssembly1920 {
  @Prop stageWidth: number = 390;
  @Prop paperWidthVp: number = 242;
  @Prop carriageHeight: number = 75;
  @Prop carriageTopVp: number = 400;

  private knobD(): number {
    return this.carriageHeight * 0.92;
  }

  private baseW(): number {
    return this.paperWidthVp + 2 * this.knobD();
  }

  private baseLeftRel(): number {
    return (this.stageWidth - this.paperWidthVp) / 2 - this.knobD();
  }

  private bracketW(): number {
    return 60;
  }

  private bracketH(): number {
    return this.bracketW() / 0.8042;
  }

  private bracketLeftRel(): number {
    return this.baseLeftRel() + this.baseW() - this.bracketW() - 10;
  }

  private bracketTopRel(): number {
    return this.carriageHeight + 24 - this.bracketH();
  }

  build() {
    Image($rawfile('layers/1920s-upright/lever-pivot-bracket.png'))
      .width(this.bracketW())
      .height(this.bracketH())
      .objectFit(ImageFit.Fill)
      .position({
        x: this.bracketLeftRel(),
        y: this.carriageTopVp - this.carriageHeight / 2 + this.bracketTopRel(),
      })
      .zIndex(8)
  }
}