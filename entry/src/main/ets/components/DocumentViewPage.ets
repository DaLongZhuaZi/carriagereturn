/**
 * 回车 · 文档视图（§5.3）+ 沉浸式（§2.10）
 *
 * 标题页与正文页并排（间距 16vp、左右边距 20vp）；底栏加页/分享/删除各占 1/3；
 * 点正文页进主屏编辑。沉浸式：两纸顶距 = topInset、底栏底距 = bottomInset。
 */

import { DocSummary, PaperKind } from '../model/DocModel';
import { docStore } from '../services/DocStore';
import { dossierStore, Dossier } from '../services/DossierStore';
import { applyImmersive, Insets } from '../services/Immersive';
import { hilog } from '@kit.PerformanceAnalysisKit';

const PAPER_RAW: Record<string, string> = {
  'letter': 'paper/paper-letter.jpg',
  'manuscript': 'paper/paper-manuscript.jpg',
  'postcard': 'paper/paper-postcard.jpg',
  'memo': 'paper/paper-memo.jpg',
};

@Component
export struct DocumentViewPage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  @Prop docId: string = '';
  @State topInset: number = 28;
  @State bottomInset: number = 0;
  @State title: string = '';
  @State lines: string[] = [];
  @State dossierName: string = '';
  @State paperKey: string = 'LETTER';
  @State dateText: string = '';
  onBack: () => void = (): void => {};
  onEdit: (id: string) => void = (): void => {};
  onDelete: (id: string) => void = (): void => {};
  /** P1-5：加页（文档末尾加一行并落盘）。 */
  onAddPage: (id: string) => void = (): void => {};

  aboutToAppear(): void {
    this.load();
    this.applyInsets();
  }

  private async applyInsets(): Promise<void> {
    const ins: Insets = await applyImmersive(this.getUIContext());
    this.topInset = ins.top;
    this.bottomInset = ins.bottom;
    hilog.info(0x0000, 'DocumentView', 'insets top=%{public}s bottom=%{public}s',
      ins.top.toFixed(1), ins.bottom.toFixed(1));
  }

  private load(): void {
    const text: string = docStore.readPlainText(this.docId);
    const arr: string[] = text.split('\n');
    this.lines = arr;
    this.title = arr.length > 0 && arr[0].length > 0 ? arr[0] : '未命名';
    const sum: DocSummary | null = this.findSummary();
    this.paperKey = sum === null ? 'LETTER' : (sum.paper as string);
    const ts: number = sum === null ? Date.now() : sum.updatedAt;
    const d: Date = new Date(ts);
    this.dateText = '写于 ' + (d.getMonth() + 1).toString() + ' 月 ' + d.getDate().toString() + ' 日';
    const did: string | null | undefined = sum === null ? null : sum.dossierId;
    const ds: Dossier | null = (did === undefined || did === null) ? null : dossierStore.find(did);
    this.dossierName = ds === null ? '未归档' : ds.name;
  }

  private findSummary(): DocSummary | null {
    const all: DocSummary[] = docStore.list();
    for (let i = 0; i < all.length; i++) {
      if (all[i].id === this.docId) {
        return all[i];
      }
    }
    return null;
  }

  private bodyText(): string {
    let out: string = '';
    for (let i = 0; i < this.lines.length; i++) {
      out += this.lines[i];
      if (i < this.lines.length - 1) { out += '\n'; }
    }
    return out.length > 0 ? out : ' ';
  }

  @Builder
  titleSheet(w: number) {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Text(this.title).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#2a2118')
          .textAlign(TextAlign.Center).width('100%')
        Text(this.dossierName).fontSize(13).fontColor('#6b5c48')
          .textAlign(TextAlign.Center).width('100%').margin({ top: 8 })
      }
      .width('100%').height('100%').padding({ top: 28, left: 18, right: 18 })

      // 右上角斜贴照片位
      Column() {
        Text('照片').fontSize(11).fontColor('#8a7a64')
      }
      .width(120).height(120).backgroundColor('#d8cfc0').borderRadius(3)
      .justifyContent(FlexAlign.Center)
      .rotate({ angle: 6 })
      .position({ x: w - 130, y: 96 })

      Text('题注').fontSize(12).fontColor('#8a7a64')
        .position({ x: w - 126, y: 230 })
      Text(this.dateText).fontSize(12).fontColor('#8a7a64')
        .position({ x: 18, y: 470 })
    }
    .width(w).height('100%')
    .backgroundColor('#f3e9d6').borderRadius(6)
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.35)', offsetX: 0, offsetY: 3 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        // §2.10：两纸顶距 = topInset
        Column().width('100%').height(this.topInset)

        // 返回
        Row() {
          Text('‹').fontSize(26).fontColor('#e8ddc9')
            .width(44).height(44).textAlign(TextAlign.Center)
            .onClick(() => { this.onBack(); })
        }.width('100%').padding({ left: 12 })

        // 两张纸并排
        Row() {
          this.titleSheet((this.widthVp - 56) / 2)
          Column().width(16)
          // 正文页：纸纹 + 正文，超出裁掉不滚动；点它进主屏编辑
          Stack({ alignContent: Alignment.TopStart }) {
            Image($rawfile(PAPER_RAW[this.paperKey]))
              .width('100%').height('100%').objectFit(ImageFit.Cover)
              .hitTestBehavior(HitTestMode.None)
            Text(this.bodyText())
              .fontSize(15).lineHeight(24).fontColor('#2a2118')
              .fontFamily('CourierPrime, Noto Serif SC')
              .padding(16).width('100%')
              .maxLines(20).textOverflow({ overflow: TextOverflow.Clip })
              .hitTestBehavior(HitTestMode.None)
          }
          .width((this.widthVp - 56) / 2)
          .layoutWeight(1)
          .height('100%')
          .clip(true).borderRadius(6)
          .shadow({ radius: 8, color: 'rgba(0,0,0,0.35)', offsetX: 0, offsetY: 3 })
          .onClick(() => {
            hilog.info(0x0000, 'DocumentView', 'body tapped doc=%{public}s', this.docId);
            this.onEdit(this.docId);
          })
        }
        .width('100%').layoutWeight(1)
        .padding({ left: 20, right: 20 }).alignItems(VerticalAlign.Top)


        // 底栏：加页 / 分享 / 删除，各 1/3
        Row() {
          Text('加页').fontSize(15).fontColor('#c9a45c')
            .id('dv_addpage')
            .layoutWeight(1).textAlign(TextAlign.Center)
            .onClick(() => { this.onAddPage(this.docId); })
          // P1-5：分享当批做不了 → 置灰 + 标注「待实现」，不留可点无反应的按钮
          Text('分享·待实现').fontSize(13).fontColor('rgba(232,221,201,0.28)')
            .layoutWeight(1).textAlign(TextAlign.Center)
          Text('删除').fontSize(15).fontColor('rgba(232,221,201,0.6)')
            .layoutWeight(1).textAlign(TextAlign.Center)
            .onClick(() => { this.onDelete(this.docId); })
        }
        .width('100%').height(56)
        // §2.10：底栏底距 = bottomInset
        .margin({ bottom: this.bottomInset })
      }
      .width('100%').height('100%')
    }
    .width(this.widthVp).height(this.heightVp)
    .backgroundColor('#171310')
    .linearGradient({ direction: GradientDirection.Bottom,
      colors: [['#171310', 0.0], ['#241c16', 1.0]] })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
