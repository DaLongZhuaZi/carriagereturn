/**
 * 第 13 批 ④：新启动引导（全屏、5 页、真分页＋圆点、symbol 图标）。
 *
 * - 只走明确操作关闭：跳过／开始写作／系统返回（返回键＝上一页，第一页＝跳过，由 Index.onBackPress 转发 onBack()）。
 * - 不设点遮罩关闭（全屏形态下误触丢失风险大）。
 * - 触发／seen／重播／总开关仍在 Index 与 GuideService，本组件只管展示与翻页。
 * - GuideOverlay.ets 保留作回滚对照。
 */
import { AppIcon, IconKind } from './AppIcon';

interface OnboardPage {
  icon: string;
  title: Resource;
  body: Resource;
}

@Component
export struct OnboardingGuide {
  @Prop visible: boolean = false;
  /** 跳过（第 1–4 页）／首屏返回：均按「关闭」语义，由 Index 落 seen。 */
  onSkip: () => void = (): void => {};
  /** 第 5 页「开始写作」。 */
  onStart: () => void = (): void => {};
  /** 系统返回：上一页；第一页等同于跳过。 */
  onBack: () => void = (): void => {};

  /** 当前页（@Link：Index.onBackPress 需要页号做「上一页／首屏跳过」）。 */
  @Link page: number;
  @State pageOpacity: number = 1;

  private pages(): OnboardPage[] {
    return [
      { icon: IconKind.ONBOARD_TYPE, title: $r('app.string.guide_onboarding2_p1_title'), body: $r('app.string.guide_onboarding2_p1_body') },
      { icon: IconKind.ONBOARD_MACHINE, title: $r('app.string.guide_onboarding2_p2_title'), body: $r('app.string.guide_onboarding2_p2_body') },
      { icon: IconKind.ONBOARD_PAPER, title: $r('app.string.guide_onboarding2_p3_title'), body: $r('app.string.guide_onboarding2_p3_body') },
      { icon: IconKind.ONBOARD_EXPORT, title: $r('app.string.guide_onboarding2_p4_title'), body: $r('app.string.guide_onboarding2_p4_body') },
      { icon: IconKind.ONBOARD_INPUT, title: $r('app.string.guide_onboarding2_p5_title'), body: $r('app.string.guide_onboarding2_p5_body') },
    ];
  }

  private pageCount(): number {
    return 5;
  }

  /** 翻页 150ms 淡出→换页→淡入（SpotlightOverlay 同款观感）。 */
  private go(next: number): void {
    if (next === this.page) {
      return;
    }
    const target: number = next < 0 ? 0 : (next >= this.pageCount() ? this.pageCount() - 1 : next);
    this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
      this.pageOpacity = 0;
    });
    setTimeout(() => {
      this.page = target;
      this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
        this.pageOpacity = 1;
      });
    }, 150);
  }

  /** Index.onBackPress 的入口：上一页；第一页返回 true 表示交给 Index 走「跳过」关闭。 */
  back(): boolean {
    if (this.page <= 0) {
      return false;
    }
    this.go(this.page - 1);
    return true;
  }

  build() {
    if (this.visible) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#241c16')

        Column() {
          Column() {
            AppIcon({ kind: this.pages()[this.page].icon, iconSize: 56, color: '#c9a45c' })
            Text(this.pages()[this.page].title)
              .fontSize(20)
              .fontFamily('Noto Serif SC')
              .fontColor('#e8ddc9')
              .margin({ top: 24 })
            Text(this.pages()[this.page].body)
              .fontSize(15)
              .fontColor('rgba(232,221,201,0.78)')
              .lineHeight(24)
              .textAlign(TextAlign.Center)
              .margin({ top: 16 })
          }
          .width('100%')
          .padding({ left: 32, right: 32 })

          // 圆点指示（8vp，当前页金色）
          Row({ space: 8 }) {
            ForEach([0, 1, 2, 3, 4], (i: number) => {
              Circle()
                .width(8)
                .height(8)
                .fill(i === this.page ? '#c9a45c' : 'rgba(232,221,201,0.28)')
            }, (i: number) => 'dot' + i.toString())
          }
          .margin({ top: 32 })

          // 按钮行（两键等宽、间距 12vp、行高 56vp）
          Row({ space: 12 }) {
            if (this.page < this.pageCount() - 1) {
              Text($r('app.string.guide_btn_skip'))
                .fontSize(15)
                .fontColor('rgba(232,221,201,0.6)')
                .textAlign(TextAlign.Center)
                .layoutWeight(1)
                .height(56)
                .onClick(() => { this.onSkip(); })
              Text($r('app.string.guide_btn_next'))
                .fontSize(15)
                .fontColor('#c9a45c')
                .textAlign(TextAlign.Center)
                .layoutWeight(1)
                .height(56)
                .onClick(() => { this.go(this.page + 1); })
            } else {
              Text($r('app.string.guide_btn_prev'))
                .fontSize(15)
                .fontColor('rgba(232,221,201,0.6)')
                .textAlign(TextAlign.Center)
                .layoutWeight(1)
                .height(56)
                .onClick(() => { this.go(this.page - 1); })
              Text($r('app.string.guide_onboarding2_start'))
                .fontSize(15)
                .fontColor('#c9a45c')
                .textAlign(TextAlign.Center)
                .layoutWeight(1)
                .height(56)
                .onClick(() => { this.onStart(); })
            }
          }
          .width('100%')
          .padding({ left: 32, right: 32 })
          .margin({ top: 24 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .opacity(this.pageOpacity)
      }
      .width('100%')
      .height('100%')
      .zIndex(120)
    }
  }
}
