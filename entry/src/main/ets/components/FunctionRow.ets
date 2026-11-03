/**
 * 功能行（§2.3）：52vp，代码画金属键质感 —— 深色金属渐变 + 顶部高光线；
 * 换行键为浅色金属渐变。三键：中/EN、删除、换行。不许加 Shift/123/空格。
 * 本步（第 1 步）只画外观并留回调；命中与缩放反馈在第 3 步接线。
 */
@Component
export struct FunctionRow {
  @Prop heightVp: number = 52;
  @Prop langLabel: string = '';
  @Prop deleteLabel: string = '';
  @Prop newlineLabel: string = '';
  onLang: () => void = (): void => {};
  onDelete: () => void = (): void => {};
  onNewline: () => void = (): void => {};

  @Builder
  metalKey(label: string, light: boolean, cb: () => void) {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .borderRadius(8)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: light
            ? [['#e8ddc9', 0.0], ['#cdbfa8', 0.55], ['#b3a48d', 1.0]]
            : [['#4a423a', 0.0], ['#312b24', 0.5], ['#1b1712', 1.0]],
        })
      // 顶部高光线
      Column()
        .width('100%')
        .height(1)
        .backgroundColor(light ? '#f6efe2' : '#6b6055')
        .position({ x: 0, y: 1 })
      Text(label)
        .fontSize(14)
        .fontColor(light ? '#312b24' : '#dbccb3')
        .maxLines(1)
    }
    .width('100%')
    .height('100%')
    .padding(6)
    .onClick(() => {
      cb();
    })
  }

  build() {
    Row({ space: 6 }) {
      Column() {
        this.metalKey(this.langLabel, false, (): void => {
          this.onLang();
        })
      }
      .layoutWeight(1)
      .height('100%')

      Column() {
        this.metalKey(this.deleteLabel, false, (): void => {
          this.onDelete();
        })
      }
      .layoutWeight(1)
      .height('100%')

      Column() {
        this.metalKey(this.newlineLabel, true, (): void => {
          this.onNewline();
        })
      }
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .height(this.heightVp)
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    .backgroundColor('#241c16')
  }
}
