/**
 * 回车 - 首页占位页 (脚手架)。
 *
 * 本页只是工程脚手架的占位: 正式主屏 (打字机 + 纸面 + 键盘) 在开工提示词
 * 阶段 1 实现, 不要在本页堆砌打字机实现。
 */
@Entry
@Component
struct Index {
  build() {
    Column({ space: 12 }) {
      Text('回车')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 48 })
      Text('拟物打字机 · 脚手架已就绪')
        .fontSize(14)
        .fontColor(Color.Gray)
      Text('主屏按 docs/开工提示词.md 阶段 1 实现')
        .fontSize(14)
        .margin({ top: 24 })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
