/**
 * 顶栏（§2.1）：56vp，左文档库图标 / 中文档标题 / 右汉堡菜单；底色透明、无分割线。
 * 图标全部用 Path 画线形，不用图片、不用文字符号。
 */
@Component
export struct TopBar {
  @Prop title: string = '';
  @Prop heightVp: number = 56;
  /** §11：左文件夹回主页（卷宗入口在主页内）。 */
  onOpenHome: () => void = (): void => {};
  /** 右汉堡：下拉菜单（收藏／设置／导出）。 */
  onOpenMenu: () => void = (): void => {};

  build() {
    Row() {
      // 左：线形文件夹（24vp）
      Stack() {
        Path()
          .width(24)
          .height(24)
          .commands('M3 7 L9 7 L11 9 L21 9 L21 19 L3 19 Z')
          .fillOpacity(0)
          .stroke('#beb4a8')
          .strokeWidth(1.6)
      }
      .width(44)
      .height(44)
      .onClick(() => {
        this.onOpenHome();
      })

      // 中：文档标题（系统字体 15vp 居中）
      Text(this.title)
        .fontSize(15)
        .fontColor('#dbccb3')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      // 右：汉堡菜单（三条线）—— §2.1 三件套，D1：设置／导出文字钮已撤，入口进下拉菜单
      Column({ space: 4 }) {
        Column().width(18).height(1.6).backgroundColor('#beb4a8')
        Column().width(18).height(1.6).backgroundColor('#beb4a8')
        Column().width(18).height(1.6).backgroundColor('#beb4a8')
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => {
        this.onOpenMenu();
      })
    }
    .width('100%')
    .height(this.heightVp)
    .padding({ left: 8, right: 8 })
    .alignItems(VerticalAlign.Center)
  }
}
