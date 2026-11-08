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
import { hilog } from '@kit.PerformanceAnalysisKit';

// 硬曲线：固定时长，不许用 springMotion 猜结算时间
// 常速：去程 90ms（60fps 下约 5–6 帧，摆动可见又不显迟钝）、回程 120ms
const STRIKE_MS: number = 90;
const RETURN_MS: number = 120;
/** 静止角：杆收进篮子方向。 */
// 静止后倾 55°（§2.9 完整规格）：去程 90ms 到竖直（杆尖穿扣子槽口），回程 120ms 回 55°
const REST_ANGLE: number = 55;
// 去丢队：上限放宽到 20（快打不许丢字）
const MAX_QUEUE: number = 20;

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
    // 去程：固定时长
    this.getUIContext().animateTo({
      duration: STRIKE_MS * this.animScale,
      curve: Curve.FastOutSlowIn,
      onFinish: () => {
        // 顺序钉死：busy=false → onArrive() → 判定是否还有队列
        this.busy = false;
        this.onArrive();
        // 回程创建必须在此判定之前/之后只选其一：有队列则跳过回程，直接小回退再下一击
        if (this.pending > 0) {
          this.getUIContext().animateTo({ duration: 20 * this.animScale, curve: Curve.Linear }, () => {
            this.angle = 40;
          });
          this.runNext();
        } else {
          this.getUIContext().animateTo({ duration: RETURN_MS * this.animScale, curve: Curve.Linear }, () => {
            this.angle = REST_ANGLE;
          });
        }
      },
    }, () => {
      this.angle = 0;
      // 杆尖 y = offsetY + 0.115×层高（竖直态），用于与打击行对账
      hilog.info(0x0100, 'TypebarLayer', 'barTip y=%{public}s (offsetY=%{public}s h=%{public}s)',
        (this.offsetYVp + 0.115 * this.layerHeightVp).toFixed(1),
        this.offsetYVp.toFixed(1), this.layerHeightVp.toFixed(1));
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
        // 静止不靠 opacity 跳变隐藏：杆在 −64° 时由字车条/纸区裁剪自然遮挡，摆动时从篮子里出来
    }
    .width('100%')
    .height('100%')
    // §18.12：这一层是纯装饰（字杆动画），却挂在 zIndex 10 且 Transparent 会**自己响应**触摸，
    // 把下面字车层的拨杆点按/拖拽全吃掉了。改 None：自身与子都不参与命中。
    .hitTestBehavior(HitTestMode.None)
  }
}
