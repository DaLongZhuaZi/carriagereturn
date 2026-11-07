/**
 * 页码轨（§2.1）：贴纸面右缘的半透明深色小 pill：上箭头 / 当前页码 / 加页号。
 * 不占顶栏、不遮正文（纸面右留 44vp 安全区由 PaperStage 保证）。
 */
import { AppIcon } from './AppIcon';

@Component
export struct PageRail {
  @Prop pageNo: number = 1;
  @Prop pageCount: number = 1;
  /** 普通成员：API 23+ 禁止 @Prop 修饰函数类型。 */
  onAddPage: () => void = (): void => {};

  build() {
    Column({ space: 2 }) {
      // 上箭头（系统 symbol）
      AppIcon({ kind: 'chevron_up', iconSize: 10, color: '#eee4ce' })
      Text(this.pageNo.toString())
        .fontSize(12)
        .fontColor('#eee4ce')
      AppIcon({ kind: 'plus', iconSize: 13, color: '#eee4ce' })
        .onClick(() => {
          this.onAddPage();
        })
    }
    .padding({ top: 6, bottom: 6, left: 5, right: 5 })
    .backgroundColor('#99171310')
    .borderRadius(8)
  }
}
