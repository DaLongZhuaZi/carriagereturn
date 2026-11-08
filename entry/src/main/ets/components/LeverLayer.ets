/**
 * 拨杆层（§2.9 第 6 项）：支点在车条右端，按 lever 图支点孔比例 (0.500,0.952) 旋转。
 * 换行开始摆出约 35°、150ms，回位完成后再回位。
 */
import { hilog } from '@kit.PerformanceAnalysisKit';

const LDOMAIN: number = 0x0100;
const LTAG: string = 'LeverLayer';
/** 静止外倾 30°（不竖直）；摆幅仍 35° → 摆出到 65°，回 30°。 */
/** 默认角度（平板口径）；手机由 Index 传入更小的值（§19.1：尖端不许出屏） */
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
  /** §19.1：静止角／摆幅（度）。平板 30/35，手机 15/20 */
  @Prop restDeg: number = REST_DEG;
  @Prop swingDeg: number = SWING_DEG;

  @State angle: number = 30;
  /** §18.11：拖拽中（跟手控角），拖动中跳过 tick 摆动，避免与直接控角抢 angle */
  @State dragging: boolean = false;
  /** 本次拖拽的纵向位移（松手判阈值用） */
  private dragOffsetY: number = 0;

  /** 杆长（vp）= 图高。向下拉满一杆长 = 摆满 swingDeg */
  private leverH(): number {
    return this.layerSizeVp / LEVER_ASPECT;
  }

  aboutToAppear(): void {
    // §19.1：初始静止角跟随传入值（手机 15°，平板 30°）
    this.angle = this.restDeg;
  }
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
    if (this.dragging) {
      // §18.11 第 4 条：拖动中不许与直接控角抢 angle，跳过摆动
      hilog.info(LDOMAIN, LTAG, 'lever swing skipped (dragging) tick=%{public}s', this.newlineTick.toString());
      return;
    }
    this.onSwingStart();
    this.getUIContext().animateTo({ duration: SWING_MS, curve: Curve.FastOutSlowIn }, () => {
      this.angle = this.restDeg + this.swingDeg;
    });
    this.getUIContext().animateTo({ duration: BACK_MS, delay: SWING_MS, curve: Curve.FastOutSlowIn }, () => {
      this.angle = this.restDeg;
    });
    hilog.info(LDOMAIN, LTAG, 'lever swing tick=%{public}s', this.newlineTick.toString());
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image($rawfile('layers/1920s-upright/lever.png'))
        .onClick(() => {
          hilog.info(LDOMAIN, LTAG, 'lever tap hit');
          this.onLeverTap();
        })
        .hitTestBehavior(HitTestMode.Block)
        // §18.11：拉下拨杆换行（只跟纵向位移；向下为正）
        .gesture(
          PanGesture({ direction: PanDirection.Vertical })
            .onActionStart(() => {
              this.dragging = true;
              this.dragOffsetY = 0;
            })
            .onActionUpdate((e: GestureEvent) => {
              const h: number = this.leverH();
              let dy: number = e.offsetY;
              if (dy < 0) {
                dy = 0;  // 不许往上转
              }
              if (dy > h) {
                dy = h;
              }
              this.dragOffsetY = dy;
              // 跟手直接赋值（不套动画，拉才有手感）
              this.angle = this.restDeg + (dy / h) * this.swingDeg;
            })
            .onActionEnd(() => {
              const h: number = this.leverH();
              const pulled: number = this.dragOffsetY;
              this.dragging = false;
              this.dragOffsetY = 0;
              if (h > 0 && pulled >= h / 2) {
                // 拉过一半：松手触发换行（一次拉动只换一行）
                hilog.info(LDOMAIN, LTAG, 'lever drag commit pull=%{public}s h=%{public}s',
                  pulled.toFixed(1), h.toFixed(1));
                this.onLeverTap();
              } else {
                // 不到一半：弹回静止角，不换行
                hilog.info(LDOMAIN, LTAG, 'lever drag cancel pull=%{public}s', pulled.toFixed(1));
                this.getUIContext().animateTo({ duration: 150, curve: Curve.FastOutSlowIn }, () => {
                  this.angle = this.restDeg;
                });
              }
            })
        )
        .width(this.layerSizeVp)
        .height(this.layerSizeVp / LEVER_ASPECT)
        .objectFit(ImageFit.Fill)
        .rotate({
          angle: this.angle,
          centerX: this.layerSizeVp * PIVOT_X_RATIO,
          centerY: (this.layerSizeVp / LEVER_ASPECT) * PIVOT_Y_RATIO,
        })
        .offset({ x: this.offsetXVp, y: this.offsetYVp })
        // §18.11 第 5 条：拨杆图很细（手机宽约 24vp），扩热区到 ≥44×44，不改视觉大小
        .responseRegion({
          x: -Math.max(0, (44 - this.layerSizeVp) / 2),
          y: -Math.max(0, (44 - this.layerSizeVp / LEVER_ASPECT) / 2),
          width: Math.max(44, this.layerSizeVp),
          height: Math.max(44, this.layerSizeVp / LEVER_ASPECT),
        })
    }
    .width('100%')
    .height('100%')
  }
}
