/**
 * 字体条（§2.1）：38vp，当前字体名用该字体本身渲染，上下各一条细线分隔。
 * 字体族从调用方传入（已按机/换装解析好的 familyName）。
 * 第 2 批 F3（评审 M-1）：机器偏好为渲染唯一来源——`currentFamilyName` 非空时优先它，
 * 原 fontFamily／fontLabel 逻辑保留（空串时行为与改造前一致）。
 */
@Component
export struct FontBar {
  @Prop fontFamily: string = 'CourierPrime';
  @Prop fontLabel: string = '';
  @Prop heightVp: number = 38;
  /** 当前机器的字体族（CustomizeStore.fontFamily(machine)，空串 = 未设置，回落原逻辑）。 */
  @Prop currentFamilyName: string = '';
  /** 点字体条进换装页（§4）；不改布局，只加一个点击入口。 */
  onOpenCustomize: () => void = (): void => {};

  build() {
    Column() {
      Column().width('100%').height(1).backgroundColor('#3a332b')
      // 第 5 批回批：文字用显示名（'Courier Prime'），字体族仍用传入族名（M-1：机器偏好是唯一渲染来源）
      Text(this.fontLabel.length > 0 ? this.fontLabel : this.currentFamilyName)
        .fontSize(13)
        .fontColor('#beb4a8')
        .fontFamily(this.currentFamilyName.length > 0 ? this.currentFamilyName : this.fontFamily)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Column().width('100%').height(1).backgroundColor('#3a332b')
    }
    .width('100%')
    .height(this.heightVp)
    .justifyContent(FlexAlign.Center)
    .onClick(() => { this.onOpenCustomize(); })
  }
}
