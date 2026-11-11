/**
 * 顶栏（§2.1）：56vp，左文档库图标 / 中文档标题 / 右汉堡菜单；底色透明、无分割线。
 * 图标全部用 Path 画线形，不用图片、不用文字符号。
 */
import { AppIcon } from './AppIcon';
import { GuideBridge } from '../services/GuideBridge';

@Component
export struct TopBar {
  @Prop title: string = '';
  @Prop heightVp: number = 56;
  /** §11：左文件夹回主页（卷宗入口在主页内）。 */
  onOpenHome: () => void = (): void => {};
  /** 第 10 批：引导 "?"（guideEnabled=false 时隐藏）。 */
  @Prop guideEnabled: boolean = true;
  /** 右汉堡：下拉菜单（收藏／设置／导出）。 */
  onOpenMenu: () => void = (): void => {};

  build() {
    Row() {
      // 左：主页（系统 symbol）
      Stack() {
        AppIcon({ kind: 'folder', iconSize: 24, color: '#dbccb3' })
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

      // 第 10 批：引导 "?"
      if (this.guideEnabled) {
        Stack() {
          SymbolGlyph($r('sys.symbol.questionmark_circle'))
            .fontSize(24).fontColor(['#dbccb3'])
        }
        .width(44)
        .height(44)
        .onClick(() => { GuideBridge.request('typewriter'); })
      }

      // 右：汉堡菜单（系统 symbol）—— §2.1 三件套
      Stack() {
        AppIcon({ kind: 'menu', iconSize: 24, color: '#dbccb3' })
      }
      .width(44)
      .height(44)
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
