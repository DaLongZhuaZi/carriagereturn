/**
 * 回车 · 收藏页（§3）+ 沉浸式（§2.10）
 *
 * 两列网格（大屏更多列）；卡片＝深色底 #241c16 + 剪影区 200vp + 名字 + 状态 + 条件行。
 * 锁定态铁律：未解锁只给深色占位 + 灰色纸片剪影 + 线形锁，不许放完整机器图。
 */

import { MachineKind } from '../model/DocModel';
import { PageShell } from './PageShell';
import { HintBar } from './HintBar';
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

  @State revealN: number = 0;
  /** P1-9：锁定态提示文案（空＝不显示）。 */
  @State hintText: Resource | null = null;
  /** D3：提示条触发计数（每次 +1 让 HintBar 重新下滑）。 */
  @State hintNonce: number = 0;
  /** P2-14：点按缩放反馈（0.97／120ms）。 */
  @State pressedIdx: number = -1;
  onBack: () => void = (): void => {};
  onPick: (kind: string) => void = (): void => {};

  private readonly kinds: string[] = ['1920s-upright', '1930s-portable', '1950s-streamlined', '1960s-electric'];

  aboutToAppear(): void {
    // insets 交给 PageShell；D6：60ms 逐格揭示
    this.revealN = 0;
    for (let i = 0; i < this.kinds.length; i++) {
      setTimeout(() => { this.revealN = i + 1; }, i * 60);
    }
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
        .border({ width: 2, color: 'rgba(232,221,201,0.6)', radius: { topLeft: 9, topRight: 9 } })
      Column()
        .width(24).height(18).borderRadius(8)
        .border({ width: 2, color: 'rgba(232,221,201,0.6)' })
    }.alignItems(HorizontalAlign.Center)
  }

  @Builder
  card(kind: string, idx: number) {
    Column() {
      // 剪影区 200vp
      Stack({ alignContent: Alignment.Center }) {
        Column().width('100%').height(200)
          .backgroundColor(this.unlocked(kind) ? '#241c16' : '#241c16')
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
        .fontSize(12)
        .fontColor(this.unlocked(kind) ? '#c9a45c' : 'rgba(232,221,201,0.4)')
        .margin({ top: 4 })
      Text(M_COND[kind]).fontSize(12).fontColor('rgba(232,221,201,0.6)')
        .margin({ top: 4 }).maxLines(1)
    }
    .width('100%')
    .padding({ bottom: 12 })
    .borderRadius(10)
    .backgroundColor('#241c16')
    .clip(true)
    .scale({ x: this.pressedIdx === idx ? 0.97 : 1, y: this.pressedIdx === idx ? 0.97 : 1 })
    .animation({ duration: 120, curve: Curve.EaseOut })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressedIdx = idx;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressedIdx = -1;
      }
    })
    .opacity(this.revealN > idx ? 1 : 0)
    .animation({ duration: 180, curve: Curve.EaseOut })
    .onClick(() => {
      // P1-9：锁定态弹条件提示（文案就是卡片上那行）；已解锁才进详情
      if (this.unlocked(kind)) {
        this.onPick(kind);
      } else {
        const c: Resource | undefined = M_COND[kind];
        this.hintText = c === undefined ? null : c;
        this.hintNonce = this.hintNonce + 1;
      }
    })
  }

  @Builder
  body() {
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
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      PageShell({
        widthVp: this.widthVp,
        heightVp: this.heightVp,
        title: '收藏',
        onBack: () => { this.onBack(); },
        content: (): void => { this.body() },
      })
      // D3：锁定提示改顶部下滑条（3 秒自动消失、点按关闭）
      HintBar({
        text: this.hintText === null ? '' : this.hintText,
        nonce: this.hintNonce,
        topInset: 44,
        onDismiss: () => { this.hintText = null; },
      })
    }
    .width(this.widthVp).height(this.heightVp)
  }
}
