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
  @Prop paperLabel: string = '';
  @Prop backLineLabel: string = '';
  @Prop charLabel: string = '';
  onLang: () => void = (): void => {};
  onDelete: () => void = (): void => {};
  onNewline: () => void = (): void => {};
  onPaperChange: () => void = (): void => {};
  onBackLine: () => void = (): void => {};
  onSymbols: () => void = (): void => {};

  @State pressedKey: string = '';

  @Builder
  metalKey(id: string, label: string, light: boolean, cb: () => void) {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .borderRadius(8)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: light
            ? (this.pressedKey === id
              ? [['#c9bda6', 0.0], ['#b0a189', 0.55], ['#96876f', 1.0]]
              : [['#e8ddc9', 0.0], ['#cdbfa8', 0.55], ['#b3a48d', 1.0]])
            : (this.pressedKey === id
              ? [['#2e2823', 0.0], ['#1f1a15', 0.5], ['#120f0b', 1.0]]
              : [['#4a423a', 0.0], ['#312b24', 0.5], ['#1b1712', 1.0]]),
        })
      // 顶部高光线
      if (this.pressedKey !== id) {
        Column()
          .width('100%')
          .height(1)
          .backgroundColor(light ? '#f6efe2' : '#6b6055')
          .position({ x: 0, y: 1 })
      }
      Text(label)
        .fontSize(14)
        .fontColor(light ? '#312b24' : '#dbccb3')
        .maxLines(1)
        .translate({ y: this.pressedKey === id ? 1 : 0 })
    }
    .width('100%')
    .height('100%')
    .padding(6)
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressedKey = id;
        cb();
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressedKey = '';
      }
    })
  }

  build() {
    Row({ space: 6 }) {
      Column() {
        this.metalKey('lang', this.langLabel, false, (): void => {
          this.onLang();
        })
      }
      .layoutWeight(1)
      .height('100%')

      Column() {
        this.metalKey('del', this.deleteLabel, false, (): void => {
          this.onDelete();
        })
      }
      .layoutWeight(1)
      .height('100%')

      Column() {
        this.metalKey('nl', this.newlineLabel, true, (): void => {
          this.onNewline();
        })
      }
      .layoutWeight(1)
      .height('100%')

      // 换纸：一次性手动动作（§2.9 完整规格）
      Column() {
        this.metalKey('paper', this.paperLabel, false, (): void => {
          this.onPaperChange();
        })
      }
      .layoutWeight(1)
      .height('100%')

      // 退行：回到上一行文字末尾
      Column() {
        this.metalKey('backline', this.backLineLabel, false, (): void => {
          this.onBackLine();
        })
      }
      .layoutWeight(1)
      .height('100%')

      // 字符 / 字母：符号键盘开关（按当前语言切换符号表）
      Column() {
        this.metalKey('symbols', this.charLabel, false, (): void => {
          this.onSymbols();
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
