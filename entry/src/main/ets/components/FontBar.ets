/**
 * 字体条（§2.1）：38vp，当前字体名用该字体本身渲染，上下各一条细线分隔。
 * 字体族从调用方传入（已按机/换装解析好的 familyName）。
 */
@Component
export struct FontBar {
  @Prop fontFamily: string = 'CourierPrime';
  @Prop fontLabel: string = '';
  @Prop heightVp: number = 38;
  /** 点字体条进换装页（§4）；不改布局，只加一个点击入口。 */
  onOpenCustomize: () => void = (): void => {};

  build() {
    Column() {
      Column().width('100%').height(1).backgroundColor('#3a332b')
      Text(this.fontLabel)
        .fontSize(13)
        .fontColor('#beb4a8')
        .fontFamily(this.fontFamily)
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
