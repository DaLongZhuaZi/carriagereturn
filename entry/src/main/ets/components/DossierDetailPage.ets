/**
 * 回车 · 卷宗内页（§5.2）
 *
 * 页眉：返回箭头 + 小封面(110×74) + 右并排卷宗名(17vp 加粗) + 「N 张纸」 + 右「新建纸张」。
 * 纸两列网格（大屏更多列），按更新时间倒序；纸卡片＝缩略图(150vp，纸纹+前 3 行) + 标题 + 元数据 + 打开·删除。
 * 飞出动画：纸从卷宗顶部开口处出发，沿二次贝塞尔弧线飞到各自格子（首屏纸才做）。
 */

import { Dossier, dossierStore } from '../services/DossierStore';
import { DocSummary, PaperKind } from '../model/DocModel';
import { docStore } from '../services/DocStore';
import { applyImmersive, Insets } from '../services/Immersive';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { componentUtils } from '@kit.ArkUI';

const COVER_RAW: Record<string, string> = {
  'kraft': 'dossiers/dossier-kraft.jpg',
  'leather': 'dossiers/dossier-leather.jpg',
  'manila': 'dossiers/dossier-manila.jpg',
  'cloth': 'dossiers/dossier-cloth.jpg',
};

const PAPER_RAW: Record<string, string> = {
  'letter': 'paper/paper-letter.jpg',
  'manuscript': 'paper/paper-manuscript.jpg',
  'postcard': 'paper/paper-postcard.jpg',
  'memo': 'paper/paper-memo.jpg',
};

/** 起飞延迟倍率：1 = 正常（200 + i×100）；调大只推迟起飞，不改变飞行速度，用于抓「刚起飞」的帧。 */
const FLY_DELAY_SCALE: number = 1;
/** 飞行时长倍率：1 = 正常（350ms 采样 / 120ms 弹簧）。 */
const FLY_DUR_SCALE: number = 1;

@Component
export struct DossierDetailPage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  @Prop dossierId: string = '';
  @Prop @Watch('onDocsChanged') docs: DocSummary[] = [];
  @State papers: DocSummary[] = [];
  @State dName: string = '';
  @State dCover: string = 'kraft';
  /** 每张纸的飞行偏移 / 旋转 / 不透明度 / 缩放。 */
  @State flyX: number[] = [];
  @State flyY: number[] = [];
  @State flyRot: number[] = [];
  @State flyOp: number[] = [];
  @State flySc: number[] = [];
  /** 实测卡片中心（vp，相对页面）：onAreaChange 写入，动画用它算起点偏移。 */
  private measuredCx: number[] = [];
  private measuredCy: number[] = [];
  /** §2.10 动态安全区。 */
  @State topInset: number = 28;
  @State bottomInset: number = 0;
  onBack: () => void = (): void => {};
  onOpenPaper: (id: string) => void = (): void => {};
  onNewPaper: () => void = (): void => {};
  onDeletePaper: (id: string) => void = (): void => {};
  /** 点缩略图 → 文档视图（§5.3）。 */
  onOpenDoc: (id: string) => void = (): void => {};
  /** 删卷宗：mode='unfile' 纸移出（变未归档）｜'purge' 连纸一起删。 */
  onDeleteDossier: (mode: string) => void = (): void => {};
  @State confirmDel: boolean = false;

  aboutToAppear(): void {
    this.reload();
    hilog.info(0x0000, 'DossierDetail', 'aboutToAppear dossier=%{public}s papers=%{public}s',
      this.dossierId, this.papers.length.toString());
    this.applyInsets();
  }

  private async applyInsets(): Promise<void> {
    const ins: Insets = await applyImmersive(this.getUIContext());
    this.topInset = ins.top;
    this.bottomInset = ins.bottom;
    hilog.info(0x0000, 'DossierDetail', 'insets top=%{public}s bottom=%{public}s',
      ins.top.toFixed(1), ins.bottom.toFixed(1));
  }

  /** docs 变化（新建/删除纸后 Index 递增 docsRev）时重算纸列表。 */
  onDocsChanged(): void {
    this.reload();
  }

  private reload(): void {
    const d: Dossier | null = this.dossierId.length > 0 ? dossierStore.find(this.dossierId) : null;
    this.dName = d === null ? '未归档' : d.name;
    this.dCover = d === null ? '' : d.coverStyle;
    const list: DocSummary[] = [];
    for (let i = 0; i < this.docs.length; i++) {
      const did: string | null | undefined = this.docs[i].dossierId;
      const want: string = this.dossierId;
      const has: boolean = did !== undefined && did !== null && did === want;
      const unfiled: boolean = want.length === 0 && (did === undefined || did === null);
      if (has || unfiled) { list.push(this.docs[i]); }
    }
    list.sort((a: DocSummary, b: DocSummary) => b.updatedAt - a.updatedAt);
    this.papers = list;
    this.initFly();
  }

  private colsTemplate(): string {
    const usable: number = this.widthVp - 40;
    const n: number = Math.floor((usable + 16) / 260);
    const c: number = n < 2 ? 2 : (n > 4 ? 4 : n);
    if (c === 2) { return '1fr 1fr'; }
    if (c === 3) { return '1fr 1fr 1fr'; }
    return '1fr 1fr 1fr 1fr';
  }

  private colCount(): number {
    const t: string = this.colsTemplate();
    return t.split(' ').length;
  }

  /** 开口点：卷宗封面顶部纸露出处（页眉小封面右上）。 */
  private openingX(): number { return 150; }
  private openingY(): number { return 96; }

  /** 卡片中心（按网格推算）。 */
  private cardCx(i: number): number {
    const c: number = this.colCount();
    const w: number = (this.widthVp - 40 - 16 * (c - 1)) / c;
    const col: number = i % c;
    return 20 + col * (w + 16) + w / 2;
  }
  private cardCy(i: number): number {
    const c: number = this.colCount();
    const row: number = Math.floor(i / c);
    return 120 + row * 260 + 105;
  }

  /** 二次贝塞尔采样：起(开口) → 控制(中点上方 120) → 落(格子)。 */
  private bezier(sx: number, sy: number, ex: number, ey: number, t: number): number[] {
    const cx: number = (sx + ex) / 2;
    const cy: number = (sy + ey) / 2 - 120;
    const u: number = 1 - t;
    return [u * u * sx + 2 * u * t * cx + t * t * ex, u * u * sy + 2 * u * t * cy + t * t * ey];
  }

  private initFly(): void {
    const n: number = this.papers.length;
    const x: number[] = []; const y: number[] = []; const r: number[] = [];
    const o: number[] = []; const s: number[] = [];
    for (let i = 0; i < n; i++) {
      x.push(0); y.push(0); r.push(0); o.push(0); s.push(1);
    }
    this.flyX = x; this.flyY = y; this.flyRot = r; this.flyOp = o; this.flySc = s;
    // 先等一帧布局，再用 getRectangleById 量每张卡的真实矩形，最后发射
    setTimeout(() => {
      this.measureCards();
      const anim: number = n > 4 ? 4 : n;
      for (let i = 0; i < anim; i++) {
        this.launch(i);
      }
    }, 32);
  }

  /** 用 getRectangleById 取每张卡的真实矩形（px→vp），作为飞出落点。 */
  private measureCards(): void {
    const ui: UIContext = this.getUIContext();
    const cx: number[] = [];
    const cy: number[] = [];
    for (let i = 0; i < this.papers.length && i < 4; i++) {
      try {
        const rect: componentUtils.ComponentInfo =
          ui.getComponentUtils().getRectangleById('flycard_' + i.toString());
        const x: number = ui.px2vp(rect.screenOffset.x as number) + ui.px2vp(rect.size.width as number) / 2;
        const y: number = ui.px2vp(rect.screenOffset.y as number) + ui.px2vp(rect.size.height as number) / 2;
        cx.push(x);
        cy.push(y);
        hilog.info(0x0000, 'DossierDetail', 'cardMeasure i=%{public}s c=(%{public}s,%{public}s)',
          i.toString(), x.toFixed(0), y.toFixed(0));
      } catch (e) {
        cx.push(this.cardCx(i));
        cy.push(this.cardCy(i));
        hilog.warn(0x0000, 'DossierDetail', 'cardMeasure fail i=%{public}s', i.toString());
      }
    }
    this.measuredCx = cx;
    this.measuredCy = cy;
  }

  private launch(i: number): void {

    // 优先用实测中心；还没量到才退回算术推算（两者差 40-70vp，实测才对得上格子）
    const cxs: number = this.measuredCx.length > i ? this.measuredCx[i] : this.cardCx(i);
    const cys: number = this.measuredCy.length > i ? this.measuredCy[i] : this.cardCy(i);
    const sx: number = this.openingX();
    const sy: number = this.openingY();
    hilog.info(0x0000, 'DossierDetail', 'flyStart i=%{public}s from=(%{public}s,%{public}s) to=(%{public}s,%{public}s)',
      i.toString(), sx.toFixed(0), sy.toFixed(0), cxs.toFixed(0), cys.toFixed(0));
    setTimeout(() => {
      const xs: number[] = this.flyX.slice();
      const ys: number[] = this.flyY.slice();
      const rs: number[] = this.flyRot.slice();
      const os: number[] = this.flyOp.slice();
      xs[i] = sx - cxs; ys[i] = sy - cys; rs[i] = -14; os[i] = 0.0;
      this.flyX = xs; this.flyY = ys; this.flyRot = rs; this.flyOp = os;
      // 5 段线性采样近似 350ms 弧线
      const steps: number = 5;
      for (let k = 1; k <= steps; k++) {
        setTimeout(() => {
          const t: number = k / steps;
          const p: number[] = this.bezier(sx, sy, cxs, cys, t);
          const xs2: number[] = this.flyX.slice();
          const ys2: number[] = this.flyY.slice();
          const rs2: number[] = this.flyRot.slice();
          const os2: number[] = this.flyOp.slice();
          xs2[i] = p[0] - cxs; ys2[i] = p[1] - cys;
          rs2[i] = -14 * (1 - t);
          os2[i] = 0.35 + 0.65 * t;
          this.flyX = xs2; this.flyY = ys2; this.flyRot = rs2; this.flyOp = os2;
          if (k === steps) {
            // 落位小弹簧：1.05 → 1.0
            setTimeout(() => {
              const s1: number[] = this.flySc.slice(); s1[i] = 1.05; this.flySc = s1;
              setTimeout(() => {
                const s2: number[] = this.flySc.slice(); s2[i] = 1.0; this.flySc = s2;
                const r2: number[] = this.flyRot.slice(); r2[i] = 0; this.flyRot = r2;
              }, 120 * FLY_DUR_SCALE);
            }, 0);
          }
        }, 87 * k * FLY_DUR_SCALE);
      }
    }, (200 + i * 100) * FLY_DELAY_SCALE);
  }

  private previewText(id: string): string {
    const t: string = docStore.readPlainText(id);
    const lines: string[] = t.split('\n');
    let out: string = '';
    const n: number = lines.length > 3 ? 3 : lines.length;
    for (let i = 0; i < n; i++) {
      out += lines[i];
      if (i < n - 1) { out += '\n'; }
    }
    return out.length > 0 ? out : ' ';
  }

  private charCount(id: string): number {
    const raw: string = docStore.readPlainText(id);
    const n: number = raw.replace(/\s/g, '').length;
    hilog.info(0x0000, 'DossierDetail', 'charCount id=%{public}s rawLen=%{public}s n=%{public}s',
      id, raw.length.toString(), n.toString());
    return n;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        // §2.10：页眉顶距 = topInset
        Column().width('100%').height(this.topInset)
        // 页眉
        Row() {
          Text('‹').fontSize(26).fontColor('#e8ddc9')
            .width(44).height(44).textAlign(TextAlign.Center)
            .onClick(() => { this.onBack(); })
          if (this.dCover.length > 0) {
            Image($rawfile(COVER_RAW[this.dCover]))
              .width(110).height(74).borderRadius(8).objectFit(ImageFit.Cover)
          } else {
            Column().width(110).height(74).borderRadius(8).backgroundColor('#cfc7b8')
          }
          Column() {
            Text(this.dName).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
              .maxLines(1)
            Text(this.papers.length.toString() + ' 张纸')
              .fontSize(12).fontColor('rgba(232,221,201,0.55)').margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start).margin({ left: 14 }).layoutWeight(1)

          Text('⋯').fontSize(20).fontColor('#e8ddc9')
            .width(36).height(36).textAlign(TextAlign.Center)
            .onClick(() => { this.confirmDel = true; })
          Text('新建纸张').fontSize(13).fontColor('#e8ddc9')
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .borderRadius(28).backgroundColor('#2e2620')
            .margin({ left: 8 })
            .onClick(() => { this.onNewPaper(); })
        }
        .width('100%').height(96).padding({ left: 20, right: 20 })

        if (this.papers.length === 0) {
          Column() {
            Text('这里还没有纸。点右上角「新建纸张」放一张进来。')
              .fontSize(13).fontColor('rgba(232,221,201,0.55)')
          }
          .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          Grid() {
            ForEach(this.papers, (p: DocSummary, idx: number) => {
              GridItem() {
                Column() {
                  // 缩略图：纸纹 + 前 3 行
                  Stack({ alignContent: Alignment.TopStart }) {
                    Image($rawfile(PAPER_RAW[p.paper.toString()]))
                      .width('100%').height(150).borderRadius(12).objectFit(ImageFit.Cover)
                    Text(this.previewText(p.id))
                      .fontSize(9).fontColor('#2a2118')
                      .fontFamily('CourierPrime, Noto Serif SC')
                      .maxLines(3).textOverflow({ overflow: TextOverflow.Clip })
                      .padding(10).width('100%')
                  }
                  .width('100%').height(150).clip(true).borderRadius(12)
                  // §5.3：点缩略图进「文档视图」（阅读视图）；「打开」文字链仍直接进主屏编辑（§5.2）
                  .onClick(() => { this.onOpenDoc(p.id); })

                  Text(p.title.length > 0 ? p.title : '未命名')
                    .fontSize(17).fontColor('#e8ddc9').margin({ top: 8 }).maxLines(1)
                  Text((p.charCount === undefined ? 0 : p.charCount).toString() + ' 字 · '
                    + (new Date(p.updatedAt).getMonth() + 1).toString() + ' 月 '
                    + new Date(p.updatedAt).getDate().toString() + ' 日')
                    .fontSize(12).fontColor('rgba(232,221,201,0.55)').margin({ top: 2 })
                  Row() {
                    Blank()
                    Text('打开').fontSize(12).fontColor('#c9a45c')
                      .onClick(() => { this.onOpenPaper(p.id); })
                    Text('·').fontSize(12).fontColor('rgba(232,221,201,0.4)').margin({ left: 6, right: 6 })
                    Text('删除').fontSize(12).fontColor('rgba(232,221,201,0.55)')
                      .onClick(() => { this.onDeletePaper(p.id); })
                  }.width('100%').margin({ top: 6 })
                }
                .width('100%')
                .id('flycard_' + idx.toString())
                .translate({ x: idx < this.flyX.length ? this.flyX[idx] : 0,
                  y: idx < this.flyY.length ? this.flyY[idx] : 0 })
                // 量每张卡的真实中心（vp，相对页面左上），供飞出动画算起点偏移
                .onAreaChange((oldA: Area, newA: Area) => {
                  const ui: UIContext = this.getUIContext();
                  const cx: number = ui.px2vp(newA.globalPosition.x as number) +
                    ui.px2vp(newA.width as number) / 2;
                  const cy: number = ui.px2vp(newA.globalPosition.y as number) +
                    ui.px2vp(newA.height as number) / 2;
                  while (this.measuredCx.length <= idx) {
                    this.measuredCx.push(0);
                    this.measuredCy.push(0);
                  }
                  this.measuredCx[idx] = cx;
                  this.measuredCy[idx] = cy;
                })
                .rotate({ angle: idx < this.flyRot.length ? this.flyRot[idx] : 0 })
                .scale({ x: idx < this.flySc.length ? this.flySc[idx] : 1,
                  y: idx < this.flySc.length ? this.flySc[idx] : 1 })
                .opacity(idx < this.flyOp.length ? this.flyOp[idx] : 1)
                .animation({ duration: 87, curve: Curve.Linear })
              }
            }, (p: DocSummary) => p.id + ':' + p.updatedAt.toString())
          }
          .columnsTemplate(this.colsTemplate())
          .columnsGap(16).rowsGap(16)
          .width('100%').layoutWeight(1)
          .padding({ left: 20, right: 20 })
          // §2.10：纸网格底距 = bottomInset
          .margin({ bottom: this.bottomInset })
        }
      }
      .width(this.widthVp).height(this.heightVp)
      .linearGradient({ direction: GradientDirection.Bottom,
        colors: [['#171310', 0.0], ['#241c16', 1.0]] })

      // 删卷宗：先问「卷宗里的纸怎么办」，不许默认连删
    if (this.confirmDel) {
      Column() {
        Column() {
          Text('删除「' + this.dName + '」').fontSize(16).fontWeight(FontWeight.Bold)
            .fontColor('#e8ddc9')
          Text('卷宗里的 ' + this.papers.length.toString() + ' 张纸怎么办？')
            .fontSize(13).fontColor('rgba(232,221,201,0.7)').margin({ top: 10 })
          Text('移出卷宗（纸变未归档）').fontSize(14).fontColor('#c9a45c')
            .width('100%').textAlign(TextAlign.Center).margin({ top: 18 })
            .onClick(() => { this.confirmDel = false; this.onDeleteDossier('unfile'); })
          Text('连纸一起删').fontSize(14).fontColor('#c06a5a')
            .width('100%').textAlign(TextAlign.Center).margin({ top: 14 })
            .onClick(() => { this.confirmDel = false; this.onDeleteDossier('purge'); })
          Text('取消').fontSize(14).fontColor('rgba(232,221,201,0.6)')
            .width('100%').textAlign(TextAlign.Center).margin({ top: 16 })
            .onClick(() => { this.confirmDel = false; })
        }
        .width(320).padding(20).borderRadius(14).backgroundColor('#211b16')
      }
      .width('100%').height('100%').justifyContent(FlexAlign.Center)
      .backgroundColor('rgba(0,0,0,0.6)')
      }
    }
    .width(this.widthVp).height(this.heightVp)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
