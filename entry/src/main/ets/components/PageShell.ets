/**
 * 回车 · 共享页壳 PageShell（D2，§2.10）
 *
 * 统一：applyImmersive + 动态 insets + 深底渐变 + expandSafeArea + 返回行
 * （44×44 返回图标 + 18vp 加粗标题）。
 * bottomInset 只有一种落法：内容区底部 padding = bottomInset（页内不许再加）。
 */

import { applyImmersive, Insets } from '../services/Immersive';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppIcon } from './AppIcon';
import { GuideBridge } from '../services/GuideBridge';

@Component
export struct PageShell {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  @Prop title: ResourceStr = '';
  @Prop showBack: boolean = true;
  /** 第 1 批：页首常驻说明行（静态说明；打字机页不用）。 */
  @Prop subtitle: ResourceStr = '';
  @Prop showSubtitle: boolean = false;
  /** 标题右侧的自定义区（如「新建卷宗」胶囊）。 */
  @Prop showTrailing: boolean = false;
  @State topInset: number = 28;
  @State bottomInset: number = 0;
  onBack: () => void = (): void => {};
  /** 第 10 批：本页 page id（"?" 入口用）。空串则不显示 "?"。 */
  @Prop guidePage: string = '';
  /** 第 10 批：引导总开关（false 时 "?" 隐藏）。 */
  @Prop guideEnabled: boolean = true;
  /** 自定义页眉（卷宗内页需要小封面+名字+⋯，用这个槽替换默认返回+标题行）。 */
  @Prop customHeader: boolean = false;
  @BuilderParam content: () => void;
  @BuilderParam trailing: () => void = this.emptyTrailing;
  @BuilderParam header: () => void = this.emptyTrailing;

  @Builder
  emptyTrailing() {
    Column().width(0).height(0)
  }

  aboutToAppear(): void {
    this.applyInsets();
  }

  /** 供子内容读取动态 insets 用（页内需要 topInset 时）。 */
  private async applyInsets(): Promise<void> {
    const ins: Insets = await applyImmersive(this.getUIContext());
    this.topInset = ins.top;
    this.bottomInset = ins.bottom;
    hilog.info(0x0000, 'PageShell', 'insets top=%{public}s bottom=%{public}s title=%{public}s',
      ins.top.toFixed(1), ins.bottom.toFixed(1), this.title);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Column().width('100%').height(this.topInset)
        if (this.customHeader) {
          this.header()
        } else {
          Row() {
            if (this.showBack) {
              Stack() {
                AppIcon({ kind: 'back', iconSize: 24, color: '#e8ddc9' })
              }
              .width(44).height(44)
              .onClick(() => { this.onBack(); })
            }
            Text(this.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
              .margin({ left: this.showBack ? 4 : 12 })
              .maxLines(1)
            Blank()
            if (this.showTrailing) {
              this.trailing()
            }
            if (this.guideEnabled && this.guidePage.length > 0) {
              Stack() {
                Text('?')
                  .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
              }
              .width(44).height(44)
              .onClick(() => { GuideBridge.request(this.guidePage); })
            }
          }.width('100%').height(56).padding({ left: 12, right: 12 })
        }

        if (this.showSubtitle) {
          Text(this.subtitle)
            .fontSize(12)
            .fontColor('rgba(232,221,201,0.6)')
            .width('100%')
            .padding({ left: 20, right: 20, bottom: 6 })
            .maxLines(2)
        }

        Column() {
          this.content()
        }
        .width('100%').layoutWeight(1)
        // §2.10：bottomInset 唯一落法
        .padding({ bottom: this.bottomInset })
      }
      .width('100%').height('100%')
    }
    .width(this.widthVp).height(this.heightVp)
    .linearGradient({ direction: GradientDirection.Bottom,
      colors: [['#171310', 0.0], ['#241c16', 1.0]] })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    // D5：页面进出统一 200ms 淡入淡出（与换装 fadeSwitch 同值同曲线）

  }
}
