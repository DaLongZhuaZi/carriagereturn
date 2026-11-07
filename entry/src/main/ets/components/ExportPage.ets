/**
 * 回车 · 导出页（§6.2）+ 沉浸式（§2.10）
 *
 * 顶部纸面预览（高 480vp、圆角 12、不可点）；三行格式（图片/PDF/纯文本，行高 110vp）；
 * 底部全宽「分享」按钮（高 80vp、圆角 16、底距 = bottomInset）；底部小字「导出不加水印。」
 */

import { applyImmersive, Insets } from '../services/Immersive';
import { DocData } from '../model/DocModel';
import { docStore } from '../services/DocStore';
import { hilog } from '@kit.PerformanceAnalysisKit';

const FORMATS: string[][] = [
  ['图片', '所见即所得，分享到任何地方'],
  ['PDF', '文本路径，可打印、可存档'],
  ['纯文本', '.txt，可再编辑'],
];

@Component
export struct ExportPage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  @Prop docId: string = '';
  @State topInset: number = 28;
  @State bottomInset: number = 0;
  @State picked: number = -1;
  @State previewOp: number = 0;
  @State rowN: number = 0;
  @State btnScale: number = 1;
  onBack: () => void = (): void => {};
  onShare: (format: string) => void = (): void => {};

  aboutToAppear(): void {
    this.applyInsets();
    this.previewOp = 0;
    this.rowN = 0;
    setTimeout(() => { this.previewOp = 1; }, 30);
    for (let i = 0; i < 3; i++) {
      setTimeout(() => { this.rowN = i + 1; }, 200 + i * 80);
    }
  }

  private async applyInsets(): Promise<void> {
    const ins: Insets = await applyImmersive(this.getUIContext());
    this.topInset = ins.top;
    this.bottomInset = ins.bottom;
    hilog.info(0x0000, 'Export', 'insets top=%{public}s bottom=%{public}s',
      ins.top.toFixed(1), ins.bottom.toFixed(1));
  }

  private bodyText(): string {
    const d: DocData | null = this.docId.length > 0 ? docStore.load(this.docId) : null;
    if (d === null) {
      return '';
    }
    const parts: string[] = [];
    for (let i = 0; i < d.lines.length; i++) {
      parts.push(d.lines[i].text);
    }
    return parts.join('\n');
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Column().width('100%').height(this.topInset)
        Row() {
          Text('‹').fontSize(26).fontColor('#e8ddc9')
            .width(44).height(44).textAlign(TextAlign.Center)
            .onClick(() => { this.onBack(); })
          Text('导出').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
            .margin({ left: 4 })
        }.width('100%').padding({ left: 12, top: 6, bottom: 6 })

        Scroll() {
          Column() {
            // 纸面预览：当前文档第一页（不可点、不可编辑）
            Stack({ alignContent: Alignment.TopStart }) {
              Image($rawfile('paper/paper-letter.jpg'))
                .width('100%').height(480).objectFit(ImageFit.Cover).borderRadius(12)
              Text(this.bodyText()).fontSize(13).lineHeight(22).fontColor('#2a2118')
                .width('100%').padding({ left: 22, right: 22, top: 26 })
                .maxLines(16).textOverflow({ overflow: TextOverflow.Clip })
            }
            .id('export_preview')
            .width('100%').height(480).clip(true).borderRadius(12)
            .opacity(this.previewOp)
            .animation({ duration: 200, curve: Curve.EaseOut })

            Column().width('100%').height(16)

            ForEach(FORMATS, (f: string[], idx: number) => {
              Row() {
                Column() {
                  Text(f[0]).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
                  Text(f[1]).fontSize(13).fontColor('rgba(232,221,201,0.55)').margin({ top: 4 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text('›').fontSize(16).fontColor('rgba(232,221,201,0.5)')
              }
              .width('100%').height(110).padding({ left: 16, right: 16 })
              .backgroundColor(this.picked === idx ? '#2e2620' : '#241c16')
              .animation({ duration: 100 })
              .opacity(this.rowN > idx ? 1 : 0)
              .animation({ duration: 180, curve: Curve.EaseOut })
              .onClick(() => { this.picked = idx; })
            }, (f: string[], idx: number) => 'fmt' + idx.toString())
          }
          .width('100%').padding({ left: 20, right: 20 })
        }
        .layoutWeight(1).width('100%').scrollBar(BarState.Off)

        Text('分享')
          .fontSize(17).fontColor('#e8ddc9')
          .width('100%').height(80).textAlign(TextAlign.Center)
          .borderRadius(16).backgroundColor('#2e2620')
          .margin({ left: 20, right: 20, top: 10 })
          .scale({ x: this.btnScale, y: this.btnScale })
          .animation({ duration: 120 })
          .onClick(() => {
            this.btnScale = 0.97;
            setTimeout(() => { this.btnScale = 1; }, 120);
            const f: string = this.picked < 0 ? '图片' : FORMATS[this.picked][0];
            this.onShare(f);
          })

        Text('导出不加水印。')
          .fontSize(12).fontColor('rgba(232,221,201,0.4)')
          .width('100%').textAlign(TextAlign.Center)
          .margin({ top: 8, bottom: this.bottomInset + 8 })
      }
      .width('100%').height('100%')
    }
    .width(this.widthVp).height(this.heightVp)
    .linearGradient({ direction: GradientDirection.Bottom,
      colors: [['#171310', 0.0], ['#241c16', 1.0]] })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
