import { TypebarLayer } from './TypebarLayer';

/**
 * 1920s 字杆总成（§14 蓝图）：素材、几何、击打锚点全部在本文件内。
 * Index 只传与机型无关的引擎状态与回调。常量与 7fd6305^ 原件一致，不许改。
 */
@Component
export struct TypebarAssembly1920 {
  @Prop stageWidth: number = 390;
  @Prop paperWidthVp: number = 242;
  @Prop carriageOffsetVp: number = 0;
  @Prop currentLineWidthVp: number = 0;
  @Prop paperMarginH: number = 28;
  @Prop carriageHeight: number = 75;
  @Prop strikeLineVp: number = 300;
  @Prop strikeTick: number = 0;
  @Prop animScale: number = 1;
  onArrive: () => void = (): void => {};

  /** 层边长：Hc × 2.5（1920s 常量，写在蓝图里） */
  private layerSizeVp(): number {
    return this.carriageHeight * 2.5;
  }

  build() {
    TypebarLayer({
      layerWidthVp: this.layerSizeVp(),
      layerHeightVp: this.layerSizeVp(),
      strikeTick: this.strikeTick,
      animScale: this.animScale,
      offsetXVp: (this.stageWidth - this.paperWidthVp) / 2 + this.carriageOffsetVp
        + this.paperMarginH + this.currentLineWidthVp - this.layerSizeVp() / 2,
      offsetYVp: this.strikeLineVp - 0.115 * this.layerSizeVp(),
      onArrive: (): void => {
        this.onArrive();
      },
    })
      .zIndex(10)
  }
}