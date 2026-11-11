import { CarriageLayers } from './CarriageLayers';

/**
 * 1920s 金属件总成（§14 蓝图）：底座／压纸卷／中央件，几何与锚点在本文件内。
 * 冻结件 CarriageLayers 不认 machineKind，1920s 常量全在其内部。
 */
@Component
export struct MetalAssembly1920 {
  @Prop stageWidth: number = 390;
  @Prop paperWidthVp: number = 242;
  @Prop paperLeftVp: number = 74;
  @Prop strikeXVp: number = 102;
  @Prop strikeYVp: number = 0;
  @Prop carriageHeight: number = 75;
  @Prop carriageTopVp: number = 400;
  @Prop carriageOffsetVp: number = 0;
  @Prop rollerOffsetVp: number = 0;
  @Prop joltYVp: number = 0;
  @Prop knobAngleDeg: number = 0;
  @Prop canvasOffsetVp: number = 0;
  @Prop texOffsetYVp: number = 0;
  @Prop paperLeftFixedVp: number = 0;
  @Prop bailShiftVp: number = 0;

  build() {
    CarriageLayers({
      stageWidth: this.stageWidth,
      joltYVp: this.joltYVp,
      knobAngleDeg: this.knobAngleDeg,
      part: 'metal',
      paperWidthVp: this.paperWidthVp,
      paperLeftVp: this.paperLeftVp,
      strikeXVp: this.strikeXVp,
      rollerOffsetVp: this.rollerOffsetVp,
      canvasOffsetVp: this.canvasOffsetVp,
      paperLeftFixedVp: this.paperLeftFixedVp,
      texOffsetYVp: this.texOffsetYVp,
      bailShiftVp: this.bailShiftVp,
      strikeYVp: this.strikeYVp,
    })
      // 金属件顶 y = Ht − Hc（与滚筒同锚点）
      .offset({ y: this.carriageTopVp - this.carriageHeight / 2 })
  }
}