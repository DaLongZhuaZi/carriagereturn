/**
 * 回车 · 共享弹窗 AppDialog（D3，§1.1 surface/dialog）
 *
 * 遮罩与卡片是 Stack 同层兄弟：点遮罩关、点卡片不关。
 * 出现动画由 visible 的 @Watch 驱动（不能用 aboutToAppear——组件在页面挂载时就存在，
 * visible 变真时不会再触发 aboutToAppear，op 会一直是 0，卡片永久透明）。
 */

@Component
export struct AppDialog {
  @Prop @Watch('onVisible') visible: boolean = false;
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  @State op: number = 0;
  onClose: () => void = (): void => {};
  @BuilderParam content: () => void;

  aboutToAppear(): void {
    this.onVisible();
  }

  onVisible(): void {
    if (this.visible) {
      this.op = 0;
      setTimeout(() => { this.op = 1; }, 16);
    } else {
      this.op = 0;
    }
  }

  build() {
    if (this.visible) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width('100%').height('100%')
          .backgroundColor('rgba(0,0,0,0.6)')
          .onClick(() => { this.onClose(); })
        Column() {
          this.content()
        }
        .width(320).padding(20).borderRadius(12).backgroundColor('#211b16')
        .opacity(this.op)
        .animation({ duration: 200, curve: Curve.EaseOut })
      }
      .width('100%').height('100%')
    }
  }
}
