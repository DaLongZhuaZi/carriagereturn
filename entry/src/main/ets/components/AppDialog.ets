/**
 * 回车 · 共享弹窗 AppDialog（D3，§1.1 surface/dialog）
 *
 * 遮罩与卡片是 **Stack 同层兄弟**：点遮罩关、点卡片不关（卡片内点击不再冒泡关窗）。
 * 宽 320、圆角 12、底 #211b16、遮罩 rgba(0,0,0,0.6)、出现 200ms。
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
      Stack({ alignContent: Alignment.Center }) {
        // 遮罩（兄弟节点 1）：点它才关
        Column()
          .width('100%').height('100%')
          .backgroundColor('rgba(0,0,0,0.6)')
          .onClick(() => { this.onClose(); })
        // 卡片（兄弟节点 2）：在遮罩之上，点击落在自己身上，不会传到遮罩
        Column() {
          this.content()
        }
        .width(320).padding(20).borderRadius(12).backgroundColor('#211b16')
        .opacity(this.op)
        .animation({ duration: 200, curve: Curve.EaseOut })
        .onClick(() => {})
      }
      .width('100%').height('100%')
    }
  }
}
