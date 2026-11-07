/**
 * 回车 · 卷宗页（§5.1）
 *
 * 深底、顶部「卷宗」18vp 加粗 + 右「新建卷宗」深色胶囊；
 * 封面图用 rawfile/dossiers/dossier-<style>.jpg（Cover 裁切、圆角 8vp、不叠字）；
 * 两列网格起、列数随可用宽走；进页各格淡入间隔 60ms。
 */

import { Dossier, CoverStyle, dossierStore } from '../services/DossierStore';
import { DocSummary } from '../model/DocModel';
import { applyImmersive, Insets } from '../services/Immersive';
import { hilog } from '@kit.PerformanceAnalysisKit';

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
  /** P1-3：docs 变化（删卷宗/删纸后 Index 递增 docsRev）时刷新列表。 */
  @Prop @Watch('onDocsChanged') docs: DocSummary[] = [];
  @State dossiers: Dossier[] = [];
  @State creating: boolean = false;
  @State draftName: string = '';
  @State draftCover: string = 'kraft';
  @State revealN: number = 0;
  /** §2.10 动态安全区（不许写死顶距）。 */
  @State topInset: number = 28;
  @State bottomInset: number = 0;
  @State winW: number = 0;
  @State winH: number = 0;
  onBack: () => void = (): void => {};
  onOpenDossier: (id: string) => void = (): void => {};

  aboutToAppear(): void {
    this.reload();
    this.runReveal();
    this.applyInsets();
  }

  private async applyInsets(): Promise<void> {
    const ins: Insets = await applyImmersive(this.getUIContext());
    this.topInset = ins.top;
    this.bottomInset = ins.bottom;
    hilog.info(0x0000, 'DossierPage', 'insets top=%{public}s bottom=%{public}s',
      ins.top.toFixed(1), ins.bottom.toFixed(1));
  }

  private runReveal(): void {
    this.revealN = 0;
    const total: number = this.dossiers.length + 1;
    for (let i = 0; i < total; i++) {
      setTimeout(() => {
        this.revealN = i + 1;
      }, i * 60);
    }
  }

  onDocsChanged(): void {
    this.reload();
  }

  private reload(): void {
    this.dossiers = dossierStore.list();
  }

  private colsTemplate(): string {
    // P2-16：三页列数除数统一为 260（卡片最小宽 260vp；236 会让三列在平板上挤成 3×窄卡）
    // winW 是 onAreaChange 实测到的可用宽，优先用它；未测到（0）时回退 widthVp
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

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
    Column() {
      // §2.10：顶栏顶距 = topInset（深底渐变已在根 Stack，伸到状态栏下）
      Column().width('100%').height(this.topInset)
      Row() {
        // §5.1 补：返回箭头（44×44，与其他页一致）
        Text('‹').fontSize(26).fontColor('#e8ddc9')
          .width(44).height(44).textAlign(TextAlign.Center)
          .margin({ right: 4 })
          .onClick(() => { this.onBack(); })
        Text('卷宗').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
        Blank()
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
      .width('100%').height(64).padding({ left: 20, right: 20 })

      if (this.dossiers.length === 0 && this.unfiledCount() === 0) {
        Column() {
          Text('还没有卷宗。新建一个，把纸装进去吧。')
            .fontSize(12).fontColor('rgba(232,221,201,0.6)')
          // P2-11：索引损坏并已备份时，空状态补一句
          if (dossierStore.isIndexCorrupted()) {
            Text('索引损坏，已备份。')
              .fontSize(12).fontColor('rgba(192,106,90,0.85)').margin({ top: 8 })
          }
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Grid() {
          // P2-15：没有未归档纸且已有卷宗时不渲染「未归档」格
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
              .onClick(() => { this.onOpenDossier(d.id); })
            }
          }, (d: Dossier) => d.id + ':' + d.updatedAt.toString())
        }
        .columnsTemplate(this.colsTemplate())
        .columnsGap(16).rowsGap(16)
        .width('100%').layoutWeight(1)
        .padding({ left: 20, right: 20 })
        // §2.10：网格底距 = bottomInset（最后一行不被导航栏裁）
        .margin({ bottom: this.bottomInset })
      }
    }
    .width(this.widthVp).height(this.heightVp)
    .linearGradient({ direction: GradientDirection.Bottom,
      colors: [['#171310', 0.0], ['#241c16', 1.0]] })
    // §2.10：量实际窗口（去抖 <1vp），供列数按可用宽算
    .onAreaChange((oldA: Area, newA: Area) => {
      const w: number = newA.width as number;
      const h: number = newA.height as number;
      if (Math.abs(w - this.winW) < 1 && Math.abs(h - this.winH) < 1) {
        return;
      }
      this.winW = w;
      this.winH = h;
    })

    if (this.creating) {
      Column() {
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
        .width(320).padding(20).borderRadius(12).backgroundColor('#211b16')
      }
      .width('100%').height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor('rgba(0,0,0,0.6)')
    }
    }
    .width(this.widthVp)
    .height(this.heightVp)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
