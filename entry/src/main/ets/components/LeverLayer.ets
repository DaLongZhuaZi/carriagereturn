/**
 * 拨杆层（§2.9 第 6 项）：支点在车条右端，按 lever 图支点孔比例 (0.500,0.952) 旋转。
 * 换行开始摆出约 35°、150ms，回位完成后再回位。
 */
import { hilog } from '@kit.PerformanceAnalysisKit';

const LDOMAIN: number = 0x0100;
const LTAG: string = 'LeverLayer';
const SWING_DEG: number = 35;
const SWING_MS: number = 150;
const BACK_MS: number = 200;
const PIVOT_X_RATIO: number = 0.500;
const PIVOT_Y_RATIO: number = 0.952;

@Component
export struct LeverLayer {
  @Prop layerSizeVp: number = 120;
  /** 换行计数：+1 触发一次摆动。 */
  @Prop newlineTick: number = 0;
  @Prop offsetXVp: number = 0;
  @Prop offsetYVp: number = 0;

  @State angle: number = 0;
  private lastTick: number = 0;

  /** 摆动开始回调（铃/复位音与回位开始同帧）。 */
  onSwingStart: () => void = (): void => {};

  @Prop @Watch('onTickChanged') tickWatch: number = 0;

  onTickChanged(): void {
    if (this.newlineTick === this.lastTick) {
      return;
    }
    this.lastTick = this.newlineTick;
    this.onSwingStart();
    this.getUIContext().animateTo({ duration: SWING_MS, curve: Curve.FastOutSlowIn }, () => {
      this.angle = SWING_DEG;
    });
    this.getUIContext().animateTo({ duration: BACK_MS, delay: SWING_MS, curve: Curve.FastOutSlowIn }, () => {
      this.angle = 0;
    });
    hilog.info(LDOMAIN, LTAG, 'lever swing tick=%{public}s', this.newlineTick.toString());
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image($rawfile('typebar/1920s-lever-single.png'))
        .width(this.layerSizeVp)
        .height(this.layerSizeVp)
        .objectFit(ImageFit.Contain)
        .rotate({
          angle: this.angle,
          centerX: this.layerSizeVp * PIVOT_X_RATIO,
          centerY: this.layerSizeVp * PIVOT_Y_RATIO,
        })
        .offset({ x: this.offsetXVp, y: this.offsetYVp })
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
