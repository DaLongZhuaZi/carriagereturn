/**
 * 回车 · 共享弹窗 AppDialog（D3，§1.1 surface/dialog）
 *
 * 宽 320、圆角 12、底 #211b16、遮罩 rgba(0,0,0,0.6)、出现/消失 200ms、
 * 点遮罩关闭。4 个手写弹窗全部改用它。
 */

@Component
export struct AppDialog {
  @Prop visible: boolean = false;
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  @State op: number = 0;
  onClose: () => void = (): void => {};
  @BuilderParam content: () => void;

  aboutToAppear(): void {
    if (this.visible) {
      setTimeout(() => { this.op = 1; }, 16);
    }
  }

  build() {
    if (this.visible) {
      Column() {
        Column() {
          this.content()
        }
        .width(320).padding(20).borderRadius(12).backgroundColor('#211b16')
        .opacity(this.op)
        .animation({ duration: 200, curve: Curve.EaseOut })
      }
      .width('100%').height('100%').justifyContent(FlexAlign.Center)
      .backgroundColor('rgba(0,0,0,0.6)')
      .onClick(() => { this.onClose(); })
    }
  }
}
