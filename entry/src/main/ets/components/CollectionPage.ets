/**
 * 回车 · 收藏页（§3）+ 沉浸式（§2.10）
 *
 * 两列网格（大屏更多列）；卡片＝深色底 #342c26 + 剪影区 200vp + 名字 + 状态 + 条件行。
 * 锁定态铁律：未解锁只给深色占位 + 灰色纸片剪影 + 线形锁，不许放完整机器图。
 */

import { MachineKind } from '../model/DocModel';
import { applyImmersive, Insets } from '../services/Immersive';
import { hilog } from '@kit.PerformanceAnalysisKit';

// P2-5：文案全部走 resources/base/element/string.json，代码只读资源
const M_NAME: Record<string, Resource> = {
  '1920s-upright': $r('app.string.machine_name_1920s'),
  '1930s-portable': $r('app.string.machine_name_1930s'),
  '1950s-streamlined': $r('app.string.machine_name_1950s'),
  '1960s-electric': $r('app.string.machine_name_1960s'),
};

const M_COND: Record<string, Resource> = {
  '1920s-upright': $r('app.string.machine_cond_1920s'),
  '1930s-portable': $r('app.string.machine_cond_1930s'),
  '1950s-streamlined': $r('app.string.machine_cond_1950s'),
  '1960s-electric': $r('app.string.machine_cond_1960s'),
};

@Component
export struct CollectionPage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  @Prop currentMachine: string = '1920s-upright';
  @State topInset: number = 28;
  @State bottomInset: number = 0;
  @State revealN: number = 0;
  /** P1-9：锁定态提示文案（空＝不显示）。 */
  @State hintText: Resource | null = null;
  onBack: () => void = (): void => {};
  onPick: (kind: string) => void = (): void => {};

  private readonly kinds: string[] = ['1920s-upright', '1930s-portable', '1950s-streamlined', '1960s-electric'];

  aboutToAppear(): void {
    this.applyInsets();
    // P2-13：先归零再逐格揭示（同 DossierPage.runReveal），避免二次进入时不重播
    this.revealN = 0;
    for (let i = 0; i < this.kinds.length; i++) {
      setTimeout(() => { this.revealN = i + 1; }, i * 60);
    }
  }

  private async applyInsets(): Promise<void> {
    const ins: Insets = await applyImmersive(this.getUIContext());
    this.topInset = ins.top;
    this.bottomInset = ins.bottom;
    hilog.info(0x0000, 'Collection', 'insets top=%{public}s bottom=%{public}s',
      ins.top.toFixed(1), ins.bottom.toFixed(1));
  }

  /** 解锁判定：目前只有 1920s 默认解锁（其余解锁条件未实现，按锁定渲染）。 */
  private unlocked(kind: string): boolean {
    return kind === '1920s-upright';
  }

  private colsTemplate(): string {
    const usable: number = this.widthVp - 40;
    const n: number = Math.floor((usable + 16) / 260);
    const c: number = n < 2 ? 2 : (n > 4 ? 4 : n);
    if (c === 2) { return '1fr 1fr'; }
    if (c === 3) { return '1fr 1fr 1fr'; }
    return '1fr 1fr 1fr 1fr';
  }

  /** 线形锁：半圆挂环 + 圆角矩形锁体。 */
  @Builder
  lockIcon() {
    Column() {
      Column()
        .width(18).height(9)
        .border({ width: 2, color: 'rgba(232,221,201,0.55)', radius: { topLeft: 9, topRight: 9 } })
      Column()
        .width(24).height(18).borderRadius(3)
        .border({ width: 2, color: 'rgba(232,221,201,0.55)' })
    }.alignItems(HorizontalAlign.Center)
  }

  @Builder
  card(kind: string, idx: number) {
    Column() {
      // 剪影区 200vp
      Stack({ alignContent: Alignment.Center }) {
        Column().width('100%').height(200)
          .backgroundColor(this.unlocked(kind) ? '#2b241f' : '#241f1b')
        // P2-4：剪影改用 *-front.jpg 裁切——只露纸＋滚筒/底座轮廓（不许整图展示）
        Image($rawfile('machine/' + kind + '-front.jpg'))
          .width('100%').height(200).objectFit(ImageFit.Cover)
          .opacity(this.unlocked(kind) ? 0.92 : 0.35)
          .clip(true)
        // 未解锁：深色罩
        if (!this.unlocked(kind)) {
          Column().width('100%').height(200).backgroundColor('rgba(20,17,14,0.55)')
        }
        if (!this.unlocked(kind)) {
          this.lockIcon()
        }
      }
      .width('100%').height(200).clip(true)

      Text(M_NAME[kind]).fontSize(17).fontColor('#e8ddc9').margin({ top: 10 })
        .maxLines(1)
      Text(this.unlocked(kind) ? '已拥有' : '未解锁')
        .fontSize(13)
        .fontColor(this.unlocked(kind) ? '#c9a45c' : 'rgba(232,221,201,0.45)')
        .margin({ top: 4 })
      Text(M_COND[kind]).fontSize(12).fontColor('rgba(232,221,201,0.5)')
        .margin({ top: 4 }).maxLines(1)
    }
    .width('100%')
    .padding({ bottom: 12 })
    .borderRadius(10)
    .backgroundColor('#342c26')
    .clip(true)
    .opacity(this.revealN > idx ? 1 : 0)
    .animation({ duration: 180, curve: Curve.EaseOut })
    .onClick(() => {
      // P1-9：锁定态弹条件提示（文案就是卡片上那行）；已解锁才进详情
      if (this.unlocked(kind)) {
        this.onPick(kind);
      } else {
        const c: Resource | undefined = M_COND[kind];
        this.hintText = c === undefined ? null : c;
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        // §2.10：顶栏顶距 = topInset
        Column().width('100%').height(this.topInset)
        Row() {
          Text('‹').fontSize(26).fontColor('#e8ddc9')
            .width(44).height(44).textAlign(TextAlign.Center)
            .onClick(() => { this.onBack(); })
          Text('收藏').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
            .margin({ left: 4 })
        }.width('100%').padding({ left: 12, top: 6, bottom: 6 })

        Grid() {
          ForEach(this.kinds, (k: string, idx: number) => {
            GridItem() {
              this.card(k, idx)
            }
          }, (k: string) => k)
        }
        .columnsTemplate(this.colsTemplate())
        .columnsGap(16).rowsGap(16)
        .width('100%').layoutWeight(1)
        .padding({ left: 20, right: 20 })
        // §2.10：网格底距 = bottomInset
        .margin({ bottom: this.bottomInset })
      }
      .width('100%').height('100%')

      // P1-9：锁定提示条（与解锁提示条同样式），点一下即消失
      if (this.hintText !== null) {
        Row() {
          Text(this.hintText).fontSize(13).fontColor('#e8ddc9')
        }
        .padding({ left: 18, right: 18, top: 12, bottom: 12 })
        .borderRadius(10).backgroundColor('rgba(46,38,32,0.96)')
        .position({ x: 20, y: this.heightVp - this.bottomInset - 76 })
        .onClick(() => { this.hintText = null; })
      }
    }
    .width(this.widthVp).height(this.heightVp)
    .linearGradient({ direction: GradientDirection.Bottom,
      colors: [['#171310', 0.0], ['#241c16', 1.0]] })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
