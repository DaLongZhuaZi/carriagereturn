/**
 * 回车 · 聚光灯引导浮层（第 10 批引导重设计）。
 *
 * 形态：四块压暗矩形给目标组件开洞＋金色描边框＋透明捕捉层；气泡带箭头；
 * 底部按钮：上一步／下一步／跳过／知道了；步骤点用 Circle 绘制（不用文字符号）。
 * 单挂载点仍在 Index；与启动引导互斥（启动引导优先）。
 */
import { componentUtils } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { RectVp, BubbleLayout, layoutSpotlight } from '../model/SpotlightLayout';

const DOMAIN: number = 0x0000;
const TAG: string = 'Spotlight';

/** 一条聚光灯步骤：文案＋锚点组件 id。 */
export interface SpotlightStep {
  text: ResourceStr;
  anchorId: string;
}

@Component
export struct SpotlightOverlay {
  @Prop @Watch('onVisibleChanged') visible: boolean = false;
  @Prop page: string = '';
  @Prop @Watch('onStepsChanged') steps: SpotlightStep[] = [];
  @Prop screenW: number = 673.7;
  @Prop screenH: number = 720;
  @Prop creaseTop: number = 0;
  @Prop creaseBottom: number = 0;
  @Prop keyboardTop: number = 0;
  @State index: number = 0;
  @State rect: RectVp = { x: 0, y: 0, w: 0, h: 0 };
  @State hasRect: boolean = false;
  @State bubble: BubbleLayout = { x: 0, y: 0, w: 280, h: 150, arrowX: 0, arrowY: 0, side: 'center', overlap: false };
  @State fading: boolean = false;
  onClose: (page: string) => void = (p: string): void => {};

  aboutToAppear(): void {
    if (this.visible) {
      this.scheduleMeasure(0);
    }
  }

  onVisibleChanged(): void {
    if (this.visible) {
      this.index = 0;
      this.hasRect = false;
      // §8.1：入场过渡 250ms＋一帧后再量（冷启动由 Index 控制先等一帧，这里仍留 270ms 兜底）
      this.scheduleMeasure(270);
    }
  }

  onStepsChanged(): void {
    if (this.visible) {
      this.scheduleMeasure(0);
    }
  }

  private scheduleMeasure(delayMs: number): void {
    setTimeout(() => { this.measureCurrent(); }, delayMs);
  }

  /** 量当前步锚点：px→vp，两次量测复核（§8.2）。 */
  private measureCurrent(): void {
    if (!this.visible || this.steps.length === 0) {
      return;
    }
    const step: SpotlightStep = this.steps[Math.min(this.index, this.steps.length - 1)];
    const r1: RectVp | null = this.rectOf(step.anchorId);
    if (r1 === null) {
      this.fallback(step.anchorId);
      return;
    }
    const r2: RectVp | null = this.rectOf(step.anchorId);
    let use: RectVp = r1;
    if (r2 !== null) {
      const diff: number = Math.abs(r2.x - r1.x) + Math.abs(r2.y - r1.y) +
        Math.abs(r2.w - r1.w) + Math.abs(r2.h - r1.h);
      if (diff > 1) {
        use = r2;
        hilog.info(DOMAIN, TAG, 'guide remeasure %{public}s/%{public}s %{public}s',
          this.page, (this.index + 1).toString(), step.anchorId);
      }
    }
    this.rect = use;
    this.hasRect = true;
    this.computeBubble(use);
    hilog.info(DOMAIN, TAG, 'guide anchor %{public}s/%{public}s id=%{public}s rect=%{public}s,%{public}s,%{public}s,%{public}s',
      this.page, (this.index + 1).toString(), step.anchorId,
      use.x.toFixed(1), use.y.toFixed(1), use.w.toFixed(1), use.h.toFixed(1));
  }

  private rectOf(anchorId: string): RectVp | null {
    try {
      const ui: UIContext = this.getUIContext();
      const info: componentUtils.ComponentInfo = ui.getComponentUtils().getRectangleById(anchorId);
      const x: number = ui.px2vp(info.screenOffset.x as number);
      const y: number = ui.px2vp(info.screenOffset.y as number);
      const w: number = ui.px2vp(info.size.width as number);
      const h: number = ui.px2vp(info.size.height as number);
      if (w <= 0 || h <= 0) {
        return null;
      }
      return { x: x, y: y, w: w, h: h };
    } catch (e) {
      return null;
    }
  }

  private fallback(anchorId: string): void {
    this.hasRect = false;
    hilog.info(DOMAIN, TAG, 'guide anchor miss %{public}s/%{public}s %{public}s',
      this.page, (this.index + 1).toString(), anchorId);
    this.computeBubble({ x: this.screenW / 2, y: this.screenH / 2, w: 0, h: 0 });
  }

  private computeBubble(target: RectVp): void {
    const b: BubbleLayout = layoutSpotlight(target, this.screenW, this.screenH, 300, 150,
      this.creaseTop, this.creaseBottom, this.keyboardTop);
    if (b.overlap) {
      hilog.info(DOMAIN, TAG, 'guide bubble overlap %{public}s/%{public}s',
        this.page, (this.index + 1).toString());
    }
    this.bubble = b;
  }

  private goNext(): void {
    if (this.fading) {
      return;
    }
    if (this.index >= this.steps.length - 1) {
      this.onClose(this.page);
      return;
    }
    this.fading = true;
    // §3.5：先量下一步，再切（150ms 淡入淡出由 opacity 动画承担）
    this.index = this.index + 1;
    this.measureCurrent();
    setTimeout(() => { this.fading = false; }, 150);
  }

  private goPrev(): void {
    if (this.fading || this.index <= 0) {
      return;
    }
    this.fading = true;
    this.index = this.index - 1;
    this.measureCurrent();
    setTimeout(() => { this.fading = false; }, 150);
  }

  @Builder
  maskRect(x: number, y: number, w: number, h: number) {
    Column()
      .width(Math.max(0, w)).height(Math.max(0, h))
      .backgroundColor('rgba(0,0,0,0.55)')
      .position({ x: x, y: y })
      .onClick(() => { this.onClose(this.page); })
  }

  @Builder
  dots() {
    Row({ space: 6 }) {
      ForEach(this.steps, (s: SpotlightStep, i: number) => {
        Circle()
          .width(i === this.index ? 8 : 6)
          .height(i === this.index ? 8 : 6)
          .fill(i === this.index ? '#c9a45c' : 'rgba(232,221,201,0.35)')
      }, (s: SpotlightStep, i: number) => i.toString())
    }
  }

  build() {
    if (this.visible && this.steps.length > 0) {
      Stack({ alignContent: Alignment.TopStart }) {
        // 四块压暗遮罩（洞口外侧）
        if (this.hasRect) {
          this.maskRect(0, 0, this.screenW, this.rect.y)
          this.maskRect(0, this.rect.y + this.rect.h, this.screenW, this.screenH - this.rect.y - this.rect.h)
          this.maskRect(0, this.rect.y, this.rect.x, this.rect.h)
          this.maskRect(this.rect.x + this.rect.w, this.rect.y, this.screenW - this.rect.x - this.rect.w, this.rect.h)
          // 洞口描边框（透明底＋金边）
          Column()
            .width(this.rect.w).height(this.rect.h)
            .backgroundColor(Color.Transparent)
            .border({ width: 2, color: '#c9a45c', radius: 8 })
            .position({ x: this.rect.x, y: this.rect.y })
            .hitTestBehavior(HitTestMode.None)
          // 洞内透明捕捉层：目标可见但不可点，点击关闭
          Column()
            .width(this.rect.w).height(this.rect.h)
            .backgroundColor(Color.Transparent)
            .position({ x: this.rect.x, y: this.rect.y })
            .onClick(() => { this.onClose(this.page); })
        } else {
          // 量不到：全屏遮罩＋居中气泡（§2.4 fallback）
          Column().width('100%').height('100%')
            .backgroundColor('rgba(0,0,0,0.55)')
            .onClick(() => { this.onClose(this.page); })
        }

        // 气泡卡片（吞点击）
        Column() {
          Text(this.steps[Math.min(this.index, this.steps.length - 1)].text)
            .fontSize(14).fontColor('#e8ddc9').width('100%').maxLines(3)
          Row() {
            this.dots()
            Blank()
            if (this.index > 0) {
              Text($r('app.string.guide_btn_prev'))
                .fontSize(13).fontColor('rgba(232,221,201,0.8)')
                .padding({ left: 6, right: 6 })
                .onClick(() => { this.goPrev(); })
            }
            if (this.index < this.steps.length - 1) {
              Text($r('app.string.guide_btn_next'))
                .fontSize(13).fontColor('#c9a45c')
                .padding({ left: 6, right: 6 })
                .onClick(() => { this.goNext(); })
            } else {
              Text($r('app.string.guide_btn_ok'))
                .fontSize(13).fontColor('#c9a45c')
                .padding({ left: 6, right: 6 })
                .onClick(() => { this.onClose(this.page); })
            }
            Text($r('app.string.guide_btn_skip'))
              .fontSize(13).fontColor('rgba(232,221,201,0.6)')
              .padding({ left: 10, right: 2 })
              .onClick(() => { this.onClose(this.page); })
          }
          .width('100%').margin({ top: 12 })
        }
        .width(this.bubble.w)
        .height(this.bubble.h)
        .padding(14)
        .borderRadius(10)
        .backgroundColor('#211b16')
        .border({ width: 1, color: 'rgba(201,164,92,0.5)' })
        .position({ x: this.bubble.x, y: this.bubble.y })
        .onClick(() => {})
        .opacity(this.fading ? 0.4 : 1)
        .animation({ duration: 150, curve: Curve.EaseOut })
      }
      .width('100%').height('100%')
      .zIndex(90)
    }
  }
}
