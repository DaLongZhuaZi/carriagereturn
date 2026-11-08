/**
 * 拨杆层（§2.9 第 6 项）：支点在车条右端，按 lever 图支点孔比例 (0.500,0.952) 旋转。
 * 换行开始摆出约 35°、150ms，回位完成后再回位。
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MachineKind } from '../model/DocModel';
import { LEVER_REST_DEG_TABLET, LEVER_SWING_DEG_TABLET, angleFor, dragRatioFor, pulledEnough } from '../model/LeverAngleCore';

const LDOMAIN: number = 0x0100;
const LTAG: string = 'LeverLayer';
/** 静止／摆幅常量统一在 model/LeverAngleCore（冻结值，第 0b 批只搬不改）。 */
/** 层素材 536×2522，宽高比写死，不许方形层套 Contain。 */
const LEVER_ASPECT: number = 536 / 2522;
const SWING_MS: number = 150;
const BACK_MS: number = 200;
const PIVOT_X_RATIO: number = 0.500;
const PIVOT_Y_RATIO: number = 0.952;

@Component
export struct LeverLayer {
  @Prop layerSizeVp: number = 120;
  /** §4：机型（决定取哪份素材） */
  @Prop machineKind: MachineKind = MachineKind.UPRIGHT_1920S;
  /** §4：拨杆图宽高比／支点孔比例（按机型取数，不再写死常量） */
  @Prop leverAspect: number = 0.2125;
  @Prop leverPivotX: number = 0.500;
  @Prop leverPivotY: number = 0.952;
  /** 换行计数：+1 触发一次摆动。 */
  /** 换行计数：+1 触发一次摆动（@Watch 直接挂它，避免复制属性竞态）。 */
  @Prop @Watch('onTickChanged') newlineTick: number = 0;
  @Prop offsetXVp: number = 0;
  @Prop offsetYVp: number = 0;
  /** §19.1：静止角／摆幅（度）。平板 30/35，手机 15/20 */
  @Prop restDeg: number = LEVER_REST_DEG_TABLET;
  @Prop swingDeg: number = LEVER_SWING_DEG_TABLET;
  /** §18.11：外部驱动的拉杆比例 0..1（拨杆节点自身收不到触摸，改由 Index 在字车层接手势） */
  @Prop @Watch('onDragRatio') dragRatio: number = 0;
  /** 第 0b 批：切机纪元；变化即回静止角（不带动画），切断在途摆动跨机。 */
  @Prop @Watch('onResetEpoch') resetEpoch: number = 0;

  @State angle: number = 30;
  /** §18.11：拖拽中（跟手控角），拖动中跳过 tick 摆动，避免与直接控角抢 angle */
  @State dragging: boolean = false;
  /** 本次拖拽的纵向位移（松手判阈值用） */
  private dragOffsetY: number = 0;

  /** 杆长（vp）= 图高。向下拉满一杆长 = 摆满 swingDeg */
  /** §4：素材按机型静态分支取（$rawfile 只吃编译期常量，不许拼变量） */
  private leverH(): number {
    return this.layerSizeVp / this.leverAspect;
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

  /** 外部拖拽比例变化：跟手控角（不套动画）；回到 0 时弹回静止角 */
  onDragRatio(): void {
    if (this.dragging) {
      this.angle = angleFor(this.restDeg, this.swingDeg, this.dragRatio);
      return;
    }
    if (this.dragRatio <= 0.001) {
      this.getUIContext().animateTo({ duration: 150, curve: Curve.FastOutSlowIn }, () => {
        this.angle = this.restDeg;
      });
    }
  }

  /** 切机纪元变化：立即回静止角（不带动画），并清掉本机拖拽中间态。 */
  onResetEpoch(): void {
    this.dragging = false;
    this.dragOffsetY = 0;
    this.angle = this.restDeg;
    hilog.info(LDOMAIN, LTAG, 'lever reset epoch=%{public}s', this.resetEpoch.toString());
  }

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
      if (this.machineKind === MachineKind.PORTABLE_1930S) {
        Image($rawfile('layers/1930s-portable/lever.png'))
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
              this.angle = angleFor(this.restDeg, this.swingDeg, dragRatioFor(dy, h));
            })
            .onActionEnd(() => {
              const h: number = this.leverH();
              const pulled: number = this.dragOffsetY;
              this.dragging = false;
              this.dragOffsetY = 0;
              if (h > 0 && pulledEnough(dragRatioFor(pulled, h))) {
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
        .height(this.layerSizeVp / this.leverAspect)
        .objectFit(ImageFit.Fill)
        .rotate({
          angle: this.angle,
          centerX: this.layerSizeVp * this.leverPivotX,
          centerY: (this.layerSizeVp / this.leverAspect) * this.leverPivotY,
        })
        // §18.11：用 .position() 而不是 .offset()——.offset 只挪渲染位置、不挪命中区，
        // 导致拨杆"看得见却点不到/拉不动"（真机手指实测也无效）
        .position({ x: this.offsetXVp, y: this.offsetYVp })
        // §18.11：拨杆再抬一层 zIndex，确保它在这层 Stack 内最上（下方压纸卷/中央件不吃它）
        .zIndex(9)
        // §18.11 第 5 条：拨杆图很细（手机宽约 24vp），扩热区到 ≥44×44，不改视觉大小
        .responseRegion({
          x: -Math.max(0, (44 - this.layerSizeVp) / 2),
          y: -Math.max(0, (44 - this.layerSizeVp / this.leverAspect) / 2),
          width: Math.max(44, this.layerSizeVp),
          height: Math.max(44, this.layerSizeVp / this.leverAspect),
        })
      } else {
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
              this.angle = angleFor(this.restDeg, this.swingDeg, dragRatioFor(dy, h));
            })
            .onActionEnd(() => {
              const h: number = this.leverH();
              const pulled: number = this.dragOffsetY;
              this.dragging = false;
              this.dragOffsetY = 0;
              if (h > 0 && pulledEnough(dragRatioFor(pulled, h))) {
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
        .height(this.layerSizeVp / this.leverAspect)
        .objectFit(ImageFit.Fill)
        .rotate({
          angle: this.angle,
          centerX: this.layerSizeVp * this.leverPivotX,
          centerY: (this.layerSizeVp / this.leverAspect) * this.leverPivotY,
        })
        // §18.11：用 .position() 而不是 .offset()——.offset 只挪渲染位置、不挪命中区，
        // 导致拨杆"看得见却点不到/拉不动"（真机手指实测也无效）
        .position({ x: this.offsetXVp, y: this.offsetYVp })
        // §18.11：拨杆再抬一层 zIndex，确保它在这层 Stack 内最上（下方压纸卷/中央件不吃它）
        .zIndex(9)
        // §18.11 第 5 条：拨杆图很细（手机宽约 24vp），扩热区到 ≥44×44，不改视觉大小
        .responseRegion({
          x: -Math.max(0, (44 - this.layerSizeVp) / 2),
          y: -Math.max(0, (44 - this.layerSizeVp / this.leverAspect) / 2),
          width: Math.max(44, this.layerSizeVp),
          height: Math.max(44, this.layerSizeVp / this.leverAspect),
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
