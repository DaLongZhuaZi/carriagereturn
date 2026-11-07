/**
 * 顶栏（§2.1）：56vp，左文档库图标 / 中文档标题 / 右汉堡菜单；底色透明、无分割线。
 * 图标全部用 Path 画线形，不用图片、不用文字符号。
 */
@Component
export struct TopBar {
  @Prop title: string = '';
  @Prop heightVp: number = 56;
  /** 文档库入口。 */
  onOpenLibrary: () => void = (): void => {};
  /** 汉堡菜单（设置等入口）。 */
  onOpenMenu: () => void = (): void => {};
  /** §6.1/§6.2：顶栏菜单入口（设置／导出）。顶栏中部有空位，放得下，故不占用主屏功能行。 */
  onOpenSettings: () => void = (): void => {};
  onOpenExport: () => void = (): void => {};

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
        this.onOpenLibrary();
      })

      // 中：文档标题（系统字体 15vp 居中）
      Text(this.title)
        .fontSize(15)
        .fontColor('#dbccb3')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      // 右：设置／导出（§6.1/§6.2 入口，44×26 紧凑文字钮，不占主屏功能行）
      Text('设置').fontSize(12).fontColor('rgba(190,180,168,0.85)')
        .width(44).height(44).textAlign(TextAlign.Center)
        .onClick(() => { this.onOpenSettings(); })
      Text('导出').fontSize(12).fontColor('rgba(190,180,168,0.85)')
        .width(44).height(44).textAlign(TextAlign.Center)
        .onClick(() => { this.onOpenExport(); })

      // 右：汉堡菜单（三条线）
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
