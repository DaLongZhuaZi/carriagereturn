import { CarriageLayers } from './CarriageLayers';

/**
 * 1920s 滚筒总成（§14 蓝图）：只包一层，几何/锚点在本文件内。
 * 冻结件 CarriageLayers 不认 machineKind，1920s 常量全在其内部。
 */
@Component
export struct RollerAssembly1920 {
  @Prop stageWidth: number = 390;
  @Prop paperWidthVp: number = 242;
  @Prop paperLeftVp: number = 74;
  @Prop strikeXVp: number = 102;
  @Prop carriageHeight: number = 75;
  @Prop carriageTopVp: number = 400;
  @Prop carriageOffsetVp: number = 0;
  @Prop rollerOffsetVp: number = 0;
  @Prop joltYVp: number = 0;
  @Prop knobAngleDeg: number = 0;
  @Prop canvasOffsetVp: number = 0;
  @Prop texOffsetYVp: number = 0;
  @Prop paperLeftFixedVp: number = 0;

  build() {
    CarriageLayers({
      stageWidth: this.stageWidth,
      joltYVp: this.joltYVp,
      knobAngleDeg: this.knobAngleDeg,
      part: 'roller',
      rollerAngleDeg: this.knobAngleDeg,
      paperWidthVp: this.paperWidthVp,
      paperLeftVp: this.paperLeftVp,
      strikeXVp: this.strikeXVp,
      rollerOffsetVp: this.rollerOffsetVp,
      canvasOffsetVp: this.canvasOffsetVp,
      strikeYVp: 0,
      paperLeftFixedVp: this.paperLeftFixedVp,
      texOffsetYVp: this.texOffsetYVp,
    })
      .offset({ y: this.carriageTopVp - this.carriageHeight / 2 })
      .zIndex(1)
  }
}