/**
 * 回车 · 卷宗页（§5.1）— 已接入 PageShell / AppDialog（D2/D3）
 *
 * 深底、顶部「卷宗」18vp 加粗 + 右「新建卷宗」深色胶囊（走 PageShell 的 trailing）；
 * 封面图 rawfile/dossiers/dossier-<style>.jpg（Cover、圆角 8vp、不叠字）；
 * 两列网格起、列数随可用宽走；进页各格淡入 60ms。
 */

import { Dossier, CoverStyle, dossierStore } from '../services/DossierStore';
import { DocSummary } from '../model/DocModel';
import { PageShell } from './PageShell';
import { AppDialog } from './AppDialog';

const COVER_RAW: Record<string, string> = {
  'kraft': 'dossiers/dossier-kraft.jpg',
  'leather': 'dossiers/dossier-leather.jpg',
  'manila': 'dossiers/dossier-manila.jpg',
  'cloth': 'dossiers/dossier-cloth.jpg',
};

@Component
export struct DossierPage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  /** P1-3：docs 变化时刷新列表。 */
  @Prop @Watch('onDocsChanged') docs: DocSummary[] = [];
  @State dossiers: Dossier[] = [];
  @State creating: boolean = false;
  @State draftName: string = '';
  @State draftCover: string = 'kraft';
  @State revealN: number = 0;
  /** D4：按压统一 0.97 / 120ms。 */
  @State pressedIdx: number = -1;
  @State winW: number = 0;
  @State winH: number = 0;
  onBack: () => void = (): void => {};
  onOpenDossier: (id: string) => void = (): void => {};

  aboutToAppear(): void {
    this.reload();
    this.runReveal();
  }

  onDocsChanged(): void {
    this.reload();
  }

  private reload(): void {
    this.dossiers = dossierStore.list();
  }

  private runReveal(): void {
    this.revealN = 0;
    const total: number = this.dossiers.length + 1;
    for (let i = 0; i < total; i++) {
      setTimeout(() => { this.revealN = i + 1; }, i * 60);
    }
  }

  private colsTemplate(): string {
    const w: number = this.winW > 0 ? this.winW : this.widthVp;
    const usable: number = w - 40;
    const n: number = Math.floor((usable + 16) / 260);
    const c: number = n < 2 ? 2 : (n > 4 ? 4 : n);
    if (c === 2) { return '1fr 1fr'; }
    if (c === 3) { return '1fr 1fr 1fr'; }
    return '1fr 1fr 1fr 1fr';
  }

  private paperCount(id: string): number {
    let n: number = 0;
    for (let i = 0; i < this.docs.length; i++) {
      const d: string | null | undefined = this.docs[i].dossierId;
      if (d !== undefined && d !== null && d === id) { n = n + 1; }
    }
    return n;
  }

  private unfiledCount(): number {
    let n: number = 0;
    for (let i = 0; i < this.docs.length; i++) {
      const d: string | null | undefined = this.docs[i].dossierId;
      if (d === undefined || d === null) { n = n + 1; }
    }
    return n;
  }

  private dateText(ts: number): string {
    const d: Date = new Date(ts);
    return (d.getMonth() + 1).toString() + ' 月 ' + d.getDate().toString() + ' 日';
  }

  @Builder
  trailingBtn() {
    Text('新建卷宗').fontSize(12).fontColor('#e8ddc9')
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .borderRadius(28)
      .backgroundColor('#2e2620')
      .onClick(() => {
        this.draftName = '';
        this.draftCover = 'kraft';
        this.creating = true;
      })
  }

  @Builder
  body() {
    Column() {
      if (this.dossiers.length === 0 && this.unfiledCount() === 0) {
        Column() {
          Text('还没有卷宗。新建一个，把纸装进去吧。')
            .fontSize(12).fontColor('rgba(232,221,201,0.6)')
          if (dossierStore.isIndexCorrupted()) {
            Text('索引损坏，已备份。')
              .fontSize(12).fontColor('#a33327').margin({ top: 8 })
          }
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Grid() {
          if (this.unfiledCount() > 0 || this.dossiers.length === 0) {
            GridItem() {
              Column() {
                Column().width('100%').height(140).borderRadius(8).backgroundColor('#eee4ce')
                Text('未归档').fontSize(15).fontColor('#e8ddc9').margin({ top: 8 })
                  .hitTestBehavior(HitTestMode.None)
                Text(this.unfiledCount().toString() + ' 张纸')
                  .fontSize(12).fontColor('rgba(232,221,201,0.6)').margin({ top: 2 })
                  .hitTestBehavior(HitTestMode.None)
              }
              .width('100%')
              .opacity(this.revealN > 0 ? 1 : 0)
              .animation({ duration: 180, curve: Curve.EaseOut })
              .onClick(() => { this.onOpenDossier(''); })
            }
          }
          ForEach(this.dossiers, (d: Dossier, idx: number) => {
            GridItem() {
              Column() {
                Image($rawfile(COVER_RAW[d.coverStyle]))
                  .width('100%').height(140).borderRadius(8).objectFit(ImageFit.Cover)
                Text(d.name).fontSize(15).fontColor('#e8ddc9').margin({ top: 8 })
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .hitTestBehavior(HitTestMode.None)
                Text(this.paperCount(d.id).toString() + ' 张纸 · 更新于 ' + this.dateText(d.updatedAt))
                  .fontSize(12).fontColor('rgba(232,221,201,0.6)').margin({ top: 2 })
                  .hitTestBehavior(HitTestMode.None)
              }
              .width('100%')
              .opacity(this.revealN > idx + 1 ? 1 : 0)
              .animation({ duration: 180, curve: Curve.EaseOut })
              .scale({ x: this.pressedIdx === idx + 1 ? 0.97 : 1,
                y: this.pressedIdx === idx + 1 ? 0.97 : 1 })
              .animation({ duration: 120, curve: Curve.EaseOut })
              .onTouch((e: TouchEvent) => {
                if (e.type === TouchType.Down) {
                  this.pressedIdx = idx + 1;
                } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
                  this.pressedIdx = -1;
                }
              })
              .onClick(() => { this.onOpenDossier(d.id); })
            }
          }, (d: Dossier) => d.id + ':' + d.updatedAt.toString())
        }
        .columnsTemplate(this.colsTemplate())
        .columnsGap(16).rowsGap(16)
        .width('100%').layoutWeight(1)
        .padding({ left: 20, right: 20 })
      }
    }
    .width('100%').height('100%')
  }

  @Builder
  dialogBody() {
    Column() {
      Text('新建卷宗').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
      TextInput({ placeholder: '给卷宗起个名字', text: this.draftName })
        .fontSize(15).fontColor('#e8ddc9').margin({ top: 14 })
        .onChange((v: string) => { this.draftName = v; })
      Row() {
        ForEach(['kraft', 'leather', 'manila', 'cloth'], (s: string) => {
          Image($rawfile(COVER_RAW[s]))
            .width(60).height(40).borderRadius(8).objectFit(ImageFit.Cover)
            .border({ width: this.draftCover === s ? 2 : 0, color: '#c9a45c' })
            .margin({ right: 10 })
            .onClick(() => { this.draftCover = s; })
        }, (s: string) => s)
      }.margin({ top: 16 })
      Row() {
        Text('取消').fontSize(15).fontColor('rgba(232,221,201,0.6)')
          .onClick(() => { this.creating = false; })
        Blank()
        Text('创建').fontSize(15).fontColor('#c9a45c')
          .onClick(() => {
            const nm: string = this.draftName.length > 0 ? this.draftName : '未命名卷宗';
            const d: Dossier = dossierStore.create(nm, this.draftCover as CoverStyle);
            this.creating = false;
            this.reload();
            this.onOpenDossier(d.id);
          })
      }.width('100%').margin({ top: 18 })
    }
    .width('100%').alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      PageShell({
        widthVp: this.widthVp,
        heightVp: this.heightVp,
        title: '卷宗',
        showTrailing: true,
        onBack: () => { this.onBack(); },
        content: (): void => { this.body() },
        trailing: (): void => { this.trailingBtn() },
      })
      AppDialog({
        visible: this.creating,
        widthVp: this.widthVp,
        heightVp: this.heightVp,
        onClose: () => { this.creating = false; },
        content: (): void => { this.dialogBody() },
      })
    }
    .width(this.widthVp).height(this.heightVp)
    .onAreaChange((oldA: Area, newA: Area) => {
      const w: number = newA.width as number;
      const h: number = newA.height as number;
      if (Math.abs(w - this.winW) < 1 && Math.abs(h - this.winH) < 1) {
        return;
      }
      this.winW = w;
      this.winH = h;
    })
  }
}
