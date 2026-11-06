/**
 * 回车 · 卷宗页（§5.1）
 *
 * 两列网格（列数随可用宽走）、新建卷宗（先输名、再选四种封面）、
 * 未归档单独一格（浅灰纸纹，不用卷宗封面图）。
 * 封面图 rawfile/dossiers/dossier-<style>.jpg 尚未进仓 —— 缺失时按 coverStyle 用纯色占位，
 * 不假装有图、也不把占位写进设计事实源。
 */

import { Dossier, CoverStyle, dossierStore } from '../services/DossierStore';
import { DocSummary } from '../model/DocModel';

const COVER_COLOR: Record<string, string> = {
  'kraft': '#b98b5e',
  'leather': '#6b3f2a',
  'manila': '#d8c9a3',
  'cloth': '#4a5340',
};

const COVER_NAME: Record<string, string> = {
  'kraft': '牛皮',
  'leather': '皮革',
  'manila': '马尼拉',
  'cloth': '布面',
};

@Component
export struct DossierPage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  @Prop docs: DocSummary[] = [];
  @State dossiers: Dossier[] = [];
  @State creating: boolean = false;
  @State draftName: string = '';
  @State draftCover: string = 'kraft';
  onBack: () => void = (): void => {};
  onOpenDossier: (id: string) => void = (): void => {};

  aboutToAppear(): void {
    this.reload();
  }

  private reload(): void {
    this.dossiers = dossierStore.list();
  }

  /** 列数随可用宽走：每列最小 150vp。 */
  private cols(): number {
    const n: number = Math.floor((this.widthVp - 32) / 150);
    return n < 2 ? 2 : (n > 4 ? 4 : n);
  }

  private paperCount(id: string): number {
    let n: number = 0;
    for (let i = 0; i < this.docs.length; i++) {
      if ((this.docs[i].dossierId === undefined ? null : this.docs[i].dossierId) === id) {
        n = n + 1;
      }
    }
    return n;
  }

  private unfiledCount(): number {
    let n: number = 0;
    for (let i = 0; i < this.docs.length; i++) {
      const d: string | null | undefined = this.docs[i].dossierId;
      if (d === undefined || d === null) {
        n = n + 1;
      }
    }
    return n;
  }

  private dateText(ts: number): string {
    const d: Date = new Date(ts);
    return (d.getMonth() + 1).toString() + ' 月 ' + d.getDate().toString() + ' 日';
  }

  @Builder
  coverTile(style: string, w: number, h: number) {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(w).height(h)
        .borderRadius(8)
        .backgroundColor(COVER_COLOR[style] === undefined ? '#b98b5e' : COVER_COLOR[style])
      // 占位纹理：斜向纸纹线，仅当封面图缺失时可见
      Text(COVER_NAME[style] === undefined ? '' : COVER_NAME[style])
        .fontSize(12).fontColor('rgba(255,255,255,0.72)')
    }
    .width(w).height(h)
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Text('卷宗').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
        Blank()
        Text('新建卷宗').fontSize(14).fontColor('#c9a45c')
          .onClick(() => {
            this.draftName = '';
            this.draftCover = 'kraft';
            this.creating = true;
          })
      }
      .width('100%').height(56).padding({ left: 16, right: 16 })

      if (this.dossiers.length === 0 && this.unfiledCount() === 0) {
        Column() {
          Text('还没有卷宗。新建一个，把纸装进去吧。')
            .fontSize(13).fontColor('rgba(232,221,201,0.55)')
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Grid() {
          // 未归档：单独一格，浅灰纸纹封面，不用卷宗封面图
          GridItem() {
            Column() {
              Stack({ alignContent: Alignment.Center }) {
                Column().width('100%').height(96).borderRadius(8).backgroundColor('#cfc7b8')
                Text('未归档').fontSize(13).fontColor('#4a3d2c')
              }.width('100%').height(96)
              Text('未归档').fontSize(15).fontColor('#e8ddc9').margin({ top: 6 })
              Text(this.unfiledCount().toString() + ' 张纸')
                .fontSize(12).fontColor('rgba(232,221,201,0.55)')
            }
            .onClick(() => { this.onOpenDossier(''); })
          }

          ForEach(this.dossiers, (d: Dossier) => {
            GridItem() {
              Column() {
                this.coverTile(d.coverStyle, 150, 96)
                Text(d.name).fontSize(15).fontColor('#e8ddc9').margin({ top: 6 })
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.paperCount(d.id).toString() + ' 张纸 · 更新于 ' + this.dateText(d.updatedAt))
                  .fontSize(12).fontColor('rgba(232,221,201,0.55)')
              }
              .onClick(() => { this.onOpenDossier(d.id); })
            }
          }, (d: Dossier) => d.id + ':' + d.updatedAt.toString())
        }
        .columnsTemplate(this.cols() === 2 ? '1fr 1fr'
          : (this.cols() === 3 ? '1fr 1fr 1fr' : '1fr 1fr 1fr 1fr'))
        .columnsGap(12).rowsGap(16)
        .width('100%').layoutWeight(1).padding({ left: 16, right: 16 })
      }
    }
    .width(this.widthVp).height(this.heightVp)

    // 新建卷宗浮层
    if (this.creating) {
      Column() {
        Column() {
          Text('新建卷宗').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
          TextInput({ placeholder: '卷宗名', text: this.draftName })
            .onChange((v: string) => { this.draftName = v; })
            .margin({ top: 12 })
          Row() {
            ForEach(['kraft', 'leather', 'manila', 'cloth'], (s: string) => {
              Stack({ alignContent: Alignment.Center }) {
                Column()
                  .width(56).height(36).borderRadius(6)
                  .backgroundColor(COVER_COLOR[s])
                  .border({ width: this.draftCover === s ? 2 : 0, color: '#c9a45c' })
              }
              .margin({ right: 10 })
              .onClick(() => { this.draftCover = s; })
            }, (s: string) => s)
          }.margin({ top: 14 })
          Row() {
            Text('取消').fontSize(14).fontColor('rgba(232,221,201,0.6)')
              .onClick(() => { this.creating = false; })
            Blank()
            Text('创建').fontSize(14).fontColor('#c9a45c')
              .onClick(() => {
                const nm: string = this.draftName.length > 0 ? this.draftName : '未命名卷宗';
                const d: Dossier = dossierStore.create(nm, this.draftCover as CoverStyle);
                this.creating = false;
                this.reload();
                this.onOpenDossier(d.id);
              })
          }.width('100%').margin({ top: 16 })
        }
        .width(300).padding(18).borderRadius(12).backgroundColor('#211b16')
      }
      .width('100%').height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor('rgba(0,0,0,0.55)')
    }
  }
}
