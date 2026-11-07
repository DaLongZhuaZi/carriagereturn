/**
 * 回车 · 顶栏下拉菜单（D1，§1.1）
 *
 * 汉堡点开：收藏／设置／导出三项。深底、圆角 12、200ms 淡入。
 */

@Component
export struct AppMenu {
  @Prop visible: boolean = false;
  @Prop topVp: number = 56;
  @State op: number = 0;
  onClose: () => void = (): void => {};
  onPick: (key: string) => void = (): void => {};

  @Builder
  item(label: string, key: string) {
    Text(label).fontSize(15).fontColor('#e8ddc9')
      .width('100%').height(48).textAlign(TextAlign.Start)
      .padding({ left: 16 })
      .onClick(() => {
        this.onClose();
        this.onPick(key);
      })
  }

  build() {
    if (this.visible) {
      Stack({ alignContent: Alignment.TopEnd }) {
        // 点空白关闭
        Column().width('100%').height('100%')
          .backgroundColor('rgba(0,0,0,0.35)')
          .onClick(() => { this.onClose(); })
        Column() {
          this.item('收藏', 'collection')
          this.item('设置', 'settings')
          this.item('导出', 'export')
        }
        .width(160)
        .padding({ top: 6, bottom: 6 })
        .borderRadius(12)
        .backgroundColor('#211b16')
        .margin({ top: this.topVp, right: 12 })
        .opacity(this.op)
        .animation({ duration: 200, curve: Curve.EaseOut })
        .onClick(() => {})
      }
      .width('100%').height('100%')
      .onAppear(() => { this.op = 1; })
    }
  }
}
