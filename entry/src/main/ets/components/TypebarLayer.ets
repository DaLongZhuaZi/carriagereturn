/**
 * 字杆击打层（§7.3 第 4 步；仅 1920s 有完整动画层，其余三台不编造动画层）。
 *
 * 素材：typebar-vertical.png = **竖直击打态**，2048×2048，透明 PNG；
 *       支点 = 底端圆孔中心 (1024,1776)（2048 层坐标）；静止态由绕支点旋转回去得到。
 *
 * 时序铁律：字母出现在纸面的时刻必须与杆到位同帧 → 落字挂在去程动画的 onFinish 上，
 *          不用 setTimeout 猜时间。快速连打串行排队，一次只跑一个击打周期。
 */
import { curves } from '@kit.ArkUI';

const STRIKE_MS: number = 70;
const RETURN_MS: number = 110;
/** 静止角：杆收进篮子方向。 */
const REST_ANGLE: number = -64;
const MAX_QUEUE: number = 3;

@Component
export struct TypebarLayer {
  @Prop layerWidthVp: number = 390;
  @Prop layerHeightVp: number = 420;
  @Prop @Watch('onTickChanged') strikeTick: number = 0;
  @Prop animScale: number = 1;
  /** 层在纸面区内的相对位置（左上）。 */
  @Prop offsetXVp: number = 0;
  @Prop offsetYVp: number = 0;

  @State angle: number = REST_ANGLE;
  private busy: boolean = false;
  private pending: number = 0;
  private lastTick: number = 0;

  /** 杆到位那一帧回调（主屏在此落字）。 */
  onArrive: () => void = (): void => {};

  onTickChanged(): void {
    this.onTick();
  }

  private onTick(): void {
    if (this.strikeTick === this.lastTick) {
      return;
    }
    this.lastTick = this.strikeTick;
    if (this.pending < MAX_QUEUE) {
      this.pending += 1;
    }
    this.runNext();
  }

  private runNext(): void {
    if (this.busy || this.pending <= 0) {
      return;
    }
    this.busy = true;
    this.pending -= 1;
    // 去程：快
    this.getUIContext().animateTo({
      duration: STRIKE_MS * this.animScale,
      curve: curves.responsiveSpringMotion(0.2, 1.0),
      onFinish: () => {
        this.onArrive();
        // 回程：稍慢，带一次微震荡
        this.getUIContext().animateTo({
          duration: RETURN_MS * this.animScale,
          curve: curves.springMotion(),
          onFinish: () => {
            this.busy = false;
            this.runNext();
          },
        }, () => {
          this.angle = REST_ANGLE;
        });
      },
    }, () => {
      this.angle = 0;
    });
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image($rawfile('typebar/1920s-typebar-vertical.png'))
        .width(this.layerWidthVp)
        .height(this.layerHeightVp)
        .objectFit(ImageFit.Contain)
        .rotate({
          angle: this.angle,
          centerX: this.layerWidthVp * 0.5,
          centerY: this.layerHeightVp * 0.867,
        })
        .offset({ x: this.offsetXVp, y: this.offsetYVp })
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
