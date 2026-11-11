/**
 * 回车 · 文档视图（§5.3）+ 沉浸式（§2.10）
 *
 * 标题页与正文页并排（间距 16vp、左右边距 20vp）；底栏加页/分享/删除各占 1/3；
 * 点正文页进主屏编辑。沉浸式：两纸顶距 = topInset、底栏底距 = bottomInset。
 */

import { DocSummary } from '../model/DocModel';
import { docStore } from '../services/DocStore';
import { dossierStore, Dossier } from '../services/DossierStore';
import { PageShell } from './PageShell';
import { AppDialog } from './AppDialog';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SpotlightStep } from './SpotlightOverlay';

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
  /** 第 6 批 F10：删除方式三档（'direct'|'ask'|'trash'）；确认归页面，文案按档（M-4）。 */
  @Prop deleteMode: string = 'trash';
  /** 第 6 批 F10：删除二次确认弹窗开关。 */
  @State confirmDel: boolean = false;
  /** D6：入场 stagger 计数。 */
  @State revealN: number = 0;
  @State title: string = '';
  @State lines: string[] = [];
  @State dossierName: string = '';
  /** P2-7：默认值改 'letter'（PAPER_RAW 的键是小写，'LETTER' 查不到会回落成空图） */
  @State paperKey: string = 'letter';
  @State dateText: string = '';
  onBack: () => void = (): void => {};
  onEdit: (id: string) => void = (): void => {};
  onDelete: (id: string) => void = (): void => {};
  /** P1-5：加页（文档末尾加一行并落盘）。 */
  onAddPage: (id: string) => void = (): void => {};

  aboutToAppear(): void {
    this.load();
    // insets 交给 PageShell；D6：两纸 60ms 逐块淡入
    this.revealN = 0;
    for (let i = 0; i < 2; i++) {
      setTimeout(() => { this.revealN = i + 1; }, i * 60);
    }
  }

  private load(): void {
    const text: string = docStore.readPlainText(this.docId);
    const arr: string[] = text.split('\n');
    this.lines = arr;
    this.title = arr.length > 0 && arr[0].length > 0 ? arr[0] : '未命名';
    const sum: DocSummary | null = this.findSummary();
    this.paperKey = sum === null ? 'letter' : (sum.paper as string);
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

  /** 删除确认文案按档：direct＝不可恢复；ask/trash＝进回收站可恢复（M-4）。 */
  private deleteConfirmText(): ResourceStr {
    return this.deleteMode === 'direct'
      ? $r('app.string.delete_direct_confirm')
      : $r('app.string.delete_trash_confirm');
  }

  @Builder
  titleSheet(w: number) {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Text(this.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1a1a1a')
          .textAlign(TextAlign.Center).width('100%')
        Text(this.dossierName).fontSize(12).fontColor('#1a1a1a')
          .textAlign(TextAlign.Center).width('100%').margin({ top: 8 })
      }
      .width('100%').height('100%').padding({ top: 28, left: 18, right: 18 })

      // P2-8：照片位先置灰并标注「待实现」（系统相册选图本批未接）
      Column() {
        Text('照片').fontSize(12).fontColor('rgba(138,122,100,0.55)')
        Text('待实现').fontSize(12).fontColor('rgba(138,122,100,0.45)').margin({ top: 2 })
      }
      .width(120).height(120).backgroundColor('#eee4ce').borderRadius(8)
      .justifyContent(FlexAlign.Center)
      .rotate({ angle: 6 })
      .position({ x: w - 130, y: 96 })

      // P2-8：题注先留空（无题注不显示「题注」二字）；日期改相对布局，不用绝对 y
      Column() {
        Blank()
        Text(this.dateText).fontSize(12).fontColor('rgba(232,221,201,0.6)')
          .width('100%').textAlign(TextAlign.Start).margin({ bottom: 24 })
      }
      .width('100%').height('100%').padding({ left: 18, right: 18 })
      .justifyContent(FlexAlign.End)
    }
    .width(w).height('100%')
    .opacity(this.revealN > 0 ? 1 : 0)
    .animation({ duration: 180, curve: Curve.EaseOut })
    .backgroundColor('#eee4ce').borderRadius(8)
  }

  @Builder
  body() {
    Column() {
        // P2-6：平板并排、手机上下排（标题页在上、正文页在下）
        Flex({ direction: this.widthVp < 600 ? FlexDirection.Column : FlexDirection.Row }) {
          this.titleSheet(this.widthVp < 600 ? this.widthVp - 40 : (this.widthVp - 56) / 2)
          Column().width(16).height(this.widthVp < 600 ? 12 : 16)
          // 正文页：纸纹 + 正文，超出裁掉不滚动；点它进主屏编辑
          Stack({ alignContent: Alignment.TopStart }) {
            Image($rawfile(PAPER_RAW[this.paperKey]))
              .width('100%').height('100%').objectFit(ImageFit.Cover)
              .hitTestBehavior(HitTestMode.None)
            Text(this.bodyText())
              .fontSize(15).lineHeight(24).fontColor('#1a1a1a')
              .fontFamily('CourierPrime, Noto Serif SC')
              .padding(16).width('100%')
              .maxLines(20).textOverflow({ overflow: TextOverflow.Clip })
              .hitTestBehavior(HitTestMode.None)
          }
          .width(this.widthVp < 600 ? this.widthVp - 40 : (this.widthVp - 56) / 2)
          .layoutWeight(1)
          .height(this.widthVp < 600 ? 360 : '100%')
          .opacity(this.revealN > 1 ? 1 : 0)
          .animation({ duration: 180, curve: Curve.EaseOut })
          .clip(true).borderRadius(8)
          .onClick(() => {
            hilog.info(0x0000, 'DocumentView', 'body tapped doc=%{public}s', this.docId);
            this.onEdit(this.docId);
          })
        }
        .width('100%').layoutWeight(1)
        .padding({ left: 20, right: 20 })


        // 底栏：加页 / 分享 / 删除，各 1/3
        // D13：三段文字钮改为深色按钮（与其余页底部主操作同重量）
        Row() {
          Text('加页').fontSize(15).fontColor('#e8ddc9')
            .id('dv_addpage')
            .layoutWeight(1).height(44).textAlign(TextAlign.Center)
            .borderRadius(28).backgroundColor('#2e2620')
            .margin({ right: 8 })
            .onClick(() => { this.onAddPage(this.docId); })
          Text('分享·待实现').fontSize(15).fontColor('rgba(232,221,201,0.4)')
            .layoutWeight(1).height(44).textAlign(TextAlign.Center)
            .borderRadius(28).backgroundColor('#241c16')
            .margin({ right: 8 })
          Text($r('app.string.delete')).fontSize(15).fontColor('rgba(232,221,201,0.6)')
            .id('dv_del')
            .layoutWeight(1).height(44).textAlign(TextAlign.Center)
            .borderRadius(28).backgroundColor('#241c16')
            // 第 6 批 F10：先二次确认（文案按 deleteMode），确认后才 onDelete
            .onClick(() => { this.confirmDel = true; })
        }
        .width('100%').height(56).padding({ left: 20, right: 20 })
    }
    .width('100%').height('100%')
  }

  /** 第 6 批 F10：删除确认弹窗（遮罩/卡片由 AppDialog 内部同层兄弟实现）。 */
  @Builder
  delBody() {
    Column() {
      Text($r('app.string.delete_paper_title')).fontSize(17).fontWeight(FontWeight.Bold)
        .fontColor('#e8ddc9')
      Text(this.deleteConfirmText()).fontSize(12).fontColor('rgba(232,221,201,0.75)')
        .margin({ top: 10 })
      Text($r('app.string.delete')).fontSize(15).fontColor('#a33327')
        .id('dv_dlg_del')
        .width('100%').textAlign(TextAlign.Center).margin({ top: 18 })
        .onClick(() => {
          const id: string = this.docId;
          this.confirmDel = false;
          this.onDelete(id);
        })
      Text($r('app.string.cancel')).fontSize(15).fontColor('rgba(232,221,201,0.6)')
        .id('dv_dlg_cancel')
        .width('100%').textAlign(TextAlign.Center).margin({ top: 16 })
        .onClick(() => { this.confirmDel = false; })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  build() {
    // D2：根节点多余的 backgroundColor('#171310') 已删（渐变由 PageShell 统一给）
    Stack({ alignContent: Alignment.TopStart }) {
      PageShell({
        guidePage: 'document_view',
        widthVp: this.widthVp,
        heightVp: this.heightVp,
        title: $r('app.string.page_document'),
        onBack: () => { this.onBack(); },
        subtitle: $r('app.string.guide_document_view_hint'),
        showSubtitle: true,
        content: (): void => { this.body() },
      })
      AppDialog({
        visible: this.confirmDel,
        widthVp: this.widthVp,
        heightVp: this.heightVp,
        onClose: () => { this.confirmDel = false; },
        content: (): void => { this.delBody() },
      })
    }
    .width(this.widthVp).height(this.heightVp)
  }
}

/** DocumentView 页首次引导（与功能同处一源；文案键见 string.json）。 */
export function guideStepsForDocumentView(): SpotlightStep[] {
  return [
    { text: $r('app.string.guide_document_view_1'), anchorId: 'document_view__content' },
    { text: $r('app.string.guide_document_view_2'), anchorId: 'document_view__edit_btn' },
    { text: $r('app.string.guide_document_view_3'), anchorId: 'document_view__delete_btn' },
  ];
}
