/**
 * 回车 · 滚筒旋钮视觉层（第 5 批 F13）。
 *
 * 铁律：旋钮是**随纸转动的视觉指示件，不是触摸目标**。
 * - `.hitTestBehavior(HitTestMode.None)`，不接任何手势/点击；
 * - 左右两枚 knob.png ＋ 金色指针细线，整体随 angleDeg 旋转（指针让转动可见）；
 * - 只对 1920s 挂载（Index 门控 `custom.knob.enabled` 默认 off，默认不渲染→门图像素不变）。
 */
import { hilog } from '@kit.PerformanceAnalysisKit';

@Component
export struct KnobLayer {
  /** 旋钮直径（vp）= Index.knobD() = Pw×0.17×0.92。 */
  @Prop sizeVp: number = 120;
  /** 累计转角（度）。 */
  @Prop angleDeg: number = 0;
  /** 左旋钮 x（相对父 Stack 左上角，vp）。 */
  @Prop leftXVp: number = 0;
  /** 右旋钮 x（vp）。 */
  @Prop rightXVp: number = 0;
  /** 旋钮顶 y（vp；中心 = topYVp + size/2）。 */
  @Prop topYVp: number = 0;

  @Builder
  knobAt(x: number) {
    Stack({ alignContent: Alignment.TopStart }) {
      Image($rawfile('layers/1920s-upright/knob.png'))
        .width(this.sizeVp)
        .height(this.sizeVp)
        .objectFit(ImageFit.Fill)
      // 金色指针：从圆心向上伸到近边缘，让"随纸转动"可见
      Column()
        .width(2)
        .height(this.sizeVp * 0.44)
        .backgroundColor('#c9a45c')
        .position({ x: this.sizeVp / 2 - 1, y: this.sizeVp * 0.04 })
    }
    .width(this.sizeVp)
    .height(this.sizeVp)
    .rotate({
      angle: this.angleDeg,
      centerX: this.sizeVp / 2,
      centerY: this.sizeVp / 2,
    })
    .position({ x: x, y: this.topYVp })
  }

  aboutToAppear(): void {
    // 第 8 批 R4 诊断（临时）：证明旋钮层确实挂载并落位
    hilog.info(0x0000, 'CarriageReturn/KnobLayer',
      'KnobLayer mount size=%{public}s left=%{public}s right=%{public}s top=%{public}s',
      this.sizeVp.toFixed(1), this.leftXVp.toFixed(1), this.rightXVp.toFixed(1), this.topYVp.toFixed(1));
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.knobAt(this.leftXVp)
      this.knobAt(this.rightXVp)
    }
    .width('100%')
    .height('100%')
    // 视觉件：不吃触摸
    .hitTestBehavior(HitTestMode.None)
    .zIndex(30)
  }
}