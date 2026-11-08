import { LeverLayer } from './LeverLayer';
import { MachineKind } from '../../model/DocModel';

/**
 * 1920s 拨杆（§14 蓝图）：几何在蓝图里，常量与 7fd6305^ 原件一致
 * （leverW = Hc×1.84×0.212；杆长 ÷(536/2522)；支点孔 (0.503,0.293)；×0.952）。
 */
@Component
export struct LeverOnlyAssembly1920 {
  @Prop stageWidth: number = 390;
  @Prop paperWidthVp: number = 242;
  @Prop carriageHeight: number = 75;
  @Prop carriageTopVp: number = 400;
  @Prop isTablet: boolean = true;
  @Prop newlineTick: number = 0;
  @Prop dragRatio: number = 0;
  onSwingStart: () => void = (): void => {};
  onLeverTap: () => void = (): void => {};

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

  private pinXRel(): number {
    return this.bracketLeftRel() + 0.503 * this.bracketW();
  }

  private pinYRel(): number {
    return this.bracketTopRel() + 0.293 * this.bracketH();
  }

  private leverW(): number {
    if (this.isTablet) {
      return this.carriageHeight * 1.84 * 0.212;
    }
    let h: number = this.carriageHeight * 2.5;
    const reachMax: number = this.stageWidth - 8 - this.pinXRel();
    const maxH: number = reachMax / Math.sin(35 * Math.PI / 180);
    if (maxH > 0 && h > maxH) {
      h = maxH;
    }
    return h * 0.212;
  }

  build() {
    // 100% 容器：LeverLayer 内部用 width/height 100%，必须有同尺寸父层，否则参考系塌成 0
    Stack({ alignContent: Alignment.TopStart }) {
      LeverLayer({
      layerSizeVp: this.leverW(),
      // 1920s 常量：宽高比 536/2522、支点孔 (0.500, 0.952)
      machineKind: MachineKind.UPRIGHT_1920S,
      leverAspect: 536 / 2522,
      leverPivotX: 0.500,
      leverPivotY: 0.952,
      newlineTick: this.newlineTick,
      restDeg: this.isTablet ? 30 : 15,
      swingDeg: this.isTablet ? 35 : 20,
      dragRatio: this.dragRatio,
      offsetXVp: this.pinXRel() - this.leverW() / 2,
      offsetYVp: this.carriageTopVp - this.carriageHeight / 2 + this.pinYRel()
        - (this.leverW() / (536 / 2522)) * 0.952,
      onSwingStart: (): void => {
        this.onSwingStart();
      },
      onLeverTap: (): void => {
        this.onLeverTap();
      },
      })
    }
    .width('100%')
    .height('100%')
    .zIndex(9)
  }
}