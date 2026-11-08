/**
 * 功能行（§2.3）：52vp，代码画金属键质感 —— 深色金属渐变 + 顶部高光线；
 * 换行键为浅色金属渐变。六键：中/EN、删除、换行、换纸、退行、字符。
 *
 * 注意：键帽文字必须走子组件 @Prop（MetalKey），不要用 @Builder 按值传 label——
 * ArkUI 的 @Builder 按值传参不建立依赖，label 变化时 Text 不会刷新（2026-11-09 真机定位：
 * 切中文后 langZh=true 但按钮仍显示 EN；切符号后「字符」不变「字母」）。
 */
@Component
struct MetalKey {
  @Prop keyId: string = '';
  @Prop label: string = '';
  @Prop light: boolean = false;
  onPress: () => void = (): void => {};

  @State pressed: boolean = false;

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .borderRadius(8)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: this.light
            ? (this.pressed
              ? [['#c9bda6', 0.0], ['#b0a189', 0.55], ['#96876f', 1.0]]
              : [['#e8ddc9', 0.0], ['#cdbfa8', 0.55], ['#b3a48d', 1.0]])
            : (this.pressed
              ? [['#2e2823', 0.0], ['#1f1a15', 0.5], ['#120f0b', 1.0]]
              : [['#4a423a', 0.0], ['#312b24', 0.5], ['#1b1712', 1.0]]),
        })
      // 顶部高光线
      if (!this.pressed) {
        Column()
          .width('100%')
          .height(1)
          .backgroundColor(this.light ? '#f6efe2' : '#6b6055')
          .position({ x: 0, y: 1 })
      }
      Text(this.label)
        .fontSize(14)
        .fontColor(this.light ? '#312b24' : '#dbccb3')
        .maxLines(1)
        .translate({ y: this.pressed ? 1 : 0 })
    }
    .width('100%')
    .height('100%')
    .padding(6)
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressed = true;
        this.onPress();
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
  }
}

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

  build() {
    Row({ space: 6 }) {
      Column() {
        MetalKey({
          keyId: 'lang', label: this.langLabel, light: false,
          onPress: (): void => { this.onLang(); },
        })
      }
      .layoutWeight(1)
      .height('100%')

      Column() {
        MetalKey({
          keyId: 'del', label: this.deleteLabel, light: false,
          onPress: (): void => { this.onDelete(); },
        })
      }
      .layoutWeight(1)
      .height('100%')

      Column() {
        MetalKey({
          keyId: 'nl', label: this.newlineLabel, light: true,
          onPress: (): void => { this.onNewline(); },
        })
      }
      .layoutWeight(1)
      .height('100%')

      // 换纸：一次性手动动作（§2.9 完整规格）
      Column() {
        MetalKey({
          keyId: 'paper', label: this.paperLabel, light: false,
          onPress: (): void => { this.onPaperChange(); },
        })
      }
      .layoutWeight(1)
      .height('100%')

      // 退行：回到上一行文字末尾
      Column() {
        MetalKey({
          keyId: 'backline', label: this.backLineLabel, light: false,
          onPress: (): void => { this.onBackLine(); },
        })
      }
      .layoutWeight(1)
      .height('100%')

      // 字符 / 字母：符号键盘开关（按当前语言切换符号表）
      Column() {
        MetalKey({
          keyId: 'symbols', label: this.charLabel, light: false,
          onPress: (): void => { this.onSymbols(); },
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
