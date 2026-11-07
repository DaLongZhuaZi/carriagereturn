/**
 * 回车 · 内置拼音候选栏（设计稿 §5）
 *
 * 一排候选词 + 翻页。内置中文模式下常驻 44vp（无组词时是空栏），不随组词伸缩。
 * 点击走 onPick(index)（全局序号，0 起）。
 */

import { AppIcon } from './AppIcon';

@Component
export struct CandidateBar {
  /** 当前页候选（最多 9 个） */
  @Prop candidates: string[] = [];
  /** 词首选中的拼音提示（组词中显示，如 nihao） */
  @Prop pinyin: string = '';
  /** 总页数（>1 才显示翻页键） */
  @Prop pages: number = 1;
  @Prop page: number = 0;
  onPick: (index: number) => void = (): void => {};
  onPrev: () => void = (): void => {};
  onNext: () => void = (): void => {};

  @Builder
  chip(text: string, index: number) {
    Text((index + 1).toString() + ' ' + text)
      .fontSize(15).fontColor('#e8ddc9')
      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .margin({ right: 6 })
      .borderRadius(8)
      .backgroundColor(index === 0 ? '#2e2620' : '#241c16')
      .border({ width: index === 0 ? 2 : 0, color: '#c9a45c' })
      .onClick(() => { this.onPick(index); })
  }

  build() {
    Row() {
      if (this.pinyin.length > 0) {
        Text(this.pinyin)
          .fontSize(12).fontColor('rgba(232,221,201,0.6)')
          .maxLines(1).margin({ right: 10 })
      }
      Scroll() {
        Row() {
          ForEach(this.candidates, (c: string, i: number) => {
            this.chip(c, i)
          }, (c: string, i: number) => c + '_' + i.toString())
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .layoutWeight(1)

      if (this.pages > 1) {
        AppIcon({ kind: 'back', iconSize: 18, color: 'rgba(232,221,201,0.6)' })
          .margin({ left: 6 })
          .onClick(() => { this.onPrev(); })
        Text((this.page + 1).toString() + '/' + this.pages.toString())
          .fontSize(12).fontColor('rgba(232,221,201,0.6)')
          .margin({ left: 6, right: 6 })
        AppIcon({ kind: 'chevron', iconSize: 18, color: 'rgba(232,221,201,0.6)' })
          .onClick(() => { this.onNext(); })
      }
    }
    .width('100%').height(44)
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor('rgba(23,19,16,0.92)')
  }
}
