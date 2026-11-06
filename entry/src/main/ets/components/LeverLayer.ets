/**
 * 拨杆层（§2.9 第 6 项）：支点在车条右端，按 lever 图支点孔比例 (0.500,0.952) 旋转。
 * 换行开始摆出约 35°、150ms，回位完成后再回位。
 */
import { hilog } from '@kit.PerformanceAnalysisKit';

const LDOMAIN: number = 0x0100;
const LTAG: string = 'LeverLayer';
/** 静止外倾 30°（不竖直）；摆幅仍 35° → 摆出到 65°，回 30°。 */
const REST_DEG: number = 30;
const SWING_DEG: number = 35;
/** 层素材 536×2522，宽高比写死，不许方形层套 Contain。 */
const LEVER_ASPECT: number = 536 / 2522;
const SWING_MS: number = 150;
const BACK_MS: number = 200;
const PIVOT_X_RATIO: number = 0.500;
const PIVOT_Y_RATIO: number = 0.952;

@Component
export struct LeverLayer {
  @Prop layerSizeVp: number = 120;
  /** 换行计数：+1 触发一次摆动。 */
  /** 换行计数：+1 触发一次摆动（@Watch 直接挂它，避免复制属性竞态）。 */
  @Prop @Watch('onTickChanged') newlineTick: number = 0;
  @Prop offsetXVp: number = 0;
  @Prop offsetYVp: number = 0;

  @State angle: number = REST_DEG;
  private lastTick: number = 0;

  /** 摆动开始回调（铃/复位音与回位开始同帧）。 */
  onSwingStart: () => void = (): void => {};
  /** 点拨杆 = 换行一次（与底部换行键同义）。 */
  onLeverTap: () => void = (): void => {};

  onTickChanged(): void {
    if (this.newlineTick === this.lastTick) {
      return;
    }
    this.lastTick = this.newlineTick;
    this.onSwingStart();
    this.getUIContext().animateTo({ duration: SWING_MS, curve: Curve.FastOutSlowIn }, () => {
      this.angle = REST_DEG + SWING_DEG;
    });
    this.getUIContext().animateTo({ duration: BACK_MS, delay: SWING_MS, curve: Curve.FastOutSlowIn }, () => {
      this.angle = REST_DEG;
    });
    hilog.info(LDOMAIN, LTAG, 'lever swing tick=%{public}s', this.newlineTick.toString());
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image($rawfile('layers/1920s-upright/lever.png'))
        .onClick(() => {
          this.onLeverTap();
        })
        .width(this.layerSizeVp)
        .height(this.layerSizeVp / LEVER_ASPECT)
        .objectFit(ImageFit.Fill)
        .rotate({
          angle: this.angle,
          centerX: this.layerSizeVp * PIVOT_X_RATIO,
          centerY: (this.layerSizeVp / LEVER_ASPECT) * PIVOT_Y_RATIO,
        })
        .offset({ x: this.offsetXVp, y: this.offsetYVp })
    }
    .width('100%')
    .height('100%')
  }
}
