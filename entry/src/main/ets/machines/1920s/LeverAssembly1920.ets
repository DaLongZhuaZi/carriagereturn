import { LeverLayer } from './LeverLayer';

/**
 * 1920s 拨杆总成（§14 蓝图）：支架几何 + 拨杆几何 + 素材全部在本文件内。
 * 常量与 7fd6305^ 原件一致（bracketW 60／÷0.8042／孔 0.503,0.293／leverH÷(536/2522)×0.952），不许改。
 */
@Component
export struct LeverAssembly1920 {
  @Prop stageWidth: number = 390;
  @Prop paperWidthVp: number = 242;
  @Prop carriageHeight: number = 75;
  @Prop carriageTopVp: number = 400;
  @Prop isTablet: boolean = true;
  @Prop newlineTick: number = 0;
  @Prop dragRatio: number = 0;
  onSwingStart: () => void = (): void => {};
  onLeverTap: () => void = (): void => {};

  /** 旋钮直径（1920s：Hc × 0.92） */
  private knobD(): number {
    return this.carriageHeight * 0.92;
  }

  /** 底座宽／左缘（支架定位用） */
  private baseW(): number {
    return this.paperWidthVp + 2 * this.knobD();
  }

  private baseLeftRel(): number {
    return (this.stageWidth - this.paperWidthVp) / 2 - this.knobD();
  }

  /** 支架图宽固定 60vp，高按 1920s 宽高比 0.8042 */
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

  /** 销钉孔（1920s 锚点 0.503 / 0.293） */
  private pinXRel(): number {
    return this.bracketLeftRel() + 0.503 * this.bracketW();
  }

  private pinYRel(): number {
    return this.bracketTopRel() + 0.293 * this.bracketH();
  }

  /** 拨杆层宽：平板 Hc×1.84×0.212；手机按尖端不出屏反推（与原件同口径） */
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
    Stack({ alignContent: Alignment.TopStart }) {
      // 拨杆支点支架：销钉中心对齐 lever.png 支点孔 (0.500,0.952)
      Image($rawfile('layers/1920s-upright/lever-pivot-bracket.png'))
        .width(this.bracketW())
        .height(this.bracketH())
        .objectFit(ImageFit.Fill)
        .position({
          x: this.bracketLeftRel(),
          y: this.carriageTopVp - this.carriageHeight / 2 + this.bracketTopRel(),
        })
        .zIndex(8)

      LeverLayer({
        layerSizeVp: this.leverW(),
        newlineTick: this.newlineTick,
        restDeg: this.isTablet ? 30 : 15,
        swingDeg: this.isTablet ? 35 : 20,
        dragRatio: this.dragRatio,
        offsetXVp: this.pinXRel() - this.leverW() / 2,
        // 支点 y = 车条中心 + 销钉孔 y；杆长 = leverW ÷ (536/2522)
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
    // 与 Index 外层 Stack 同尺寸：子件的 .position() 坐标系才对得上
    .width('100%')
    .height('100%')
  }
}