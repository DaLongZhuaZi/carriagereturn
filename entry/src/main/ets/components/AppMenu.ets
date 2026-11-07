/**
 * 回车 · 下拉菜单（AGENTS「下拉菜单」）
 *
 * 无全屏有色遮罩（点空白关闭用透明点透层）；菜单锚定在触发按钮下方，
 * 出现：淡入 + 缩放 0.96→1 + 上移 4→0，160ms。
 */

@Component
export struct AppMenu {
  @Prop @Watch('onVisible') visible: boolean = false;
  @Prop topVp: number = 56;
  @Prop items: string[][] = [['收藏', 'collection'], ['设置', 'settings'], ['导出', 'export']];
  @State op: number = 0;
  @State sc: number = 0.96;
  @State ty: number = 4;
  onClose: () => void = (): void => {};
  onPick: (key: string) => void = (): void => {};

  aboutToAppear(): void {
    this.onVisible();
  }

  onVisible(): void {
    if (this.visible) {
      this.op = 0;
      this.sc = 0.96;
      this.ty = 4;
      setTimeout(() => {
        this.op = 1;
        this.sc = 1;
        this.ty = 0;
      }, 16);
    } else {
      this.op = 0;
    }
  }

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
        // 透明点透层（无颜色）：只负责「点空白关闭」，不压暗底层
        Column().width('100%').height('100%')
          .backgroundColor(Color.Transparent)
          .onClick(() => { this.onClose(); })
        Column() {
          ForEach(this.items, (it: string[]) => {
            this.item(it[0], it[1])
          }, (it: string[]) => it[1])
        }
        .width(160)
        .padding({ top: 6, bottom: 6 })
        .borderRadius(12)
        .backgroundColor('#211b16')
        .margin({ top: this.topVp, right: 12 })
        .opacity(this.op)
        .scale({ x: this.sc, y: this.sc })
        .translate({ y: this.ty })
        .animation({ duration: 160, curve: Curve.EaseOut })
      }
      .width('100%').height('100%')
    }
  }
}
