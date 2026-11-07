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
import { PageShell } from './PageShell';
import { AppDialog } from './AppDialog';
import { AppIcon } from './AppIcon';
import { AppMenu } from './AppMenu';
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

  onBack: () => void = (): void => {};
  onOpenPaper: (id: string) => void = (): void => {};
  onNewPaper: () => void = (): void => {};
  onDeletePaper: (id: string) => void = (): void => {};
  /** 点缩略图 → 文档视图（§5.3）。 */
  onOpenDoc: (id: string) => void = (): void => {};
  /** P1-2：改名后通知外层递增 docsRev，使卷宗页列表随之刷新。 */
  onRenamed: () => void = (): void => {};
  /** 删卷宗：mode='unfile' 纸移出（变未归档）｜'purge' 连纸一起删。 */
  onDeleteDossier: (mode: string) => void = (): void => {};
  @State confirmDel: boolean = false;
  /** P1-1：待确认删除的纸 id（空＝无）。 */
  @State pendingDelPaper: string = '';
  /** P1-2：改名状态与草稿。 */
  @State renaming: boolean = false;
  /** D13：⋯ 改真菜单（改名／新建纸张／删除卷宗）。 */
  @State moreOpen: boolean = false;
  @State draftName: string = '';

  aboutToAppear(): void {
    this.reload();
    hilog.info(0x0000, 'DossierDetail', 'aboutToAppear dossier=%{public}s papers=%{public}s',
      this.dossierId, this.papers.length.toString());
  }

  /** docs 变化（新建/删除纸后 Index 递增 docsRev）时重算纸列表。 */
  /** P1-11：docs 变化只重算列表，**不重播飞出动画**（新纸/删纸都应直接在位）。 */
  onDocsChanged(): void {
    this.reloadList(false);
  }

  private reload(): void {
    this.reloadList(true);
  }

  /** replay=true 仅 aboutToAppear 首次进入时用；之后一律 false。 */
  private reloadList(replay: boolean): void {
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
    if (replay) {
      this.initFly();
    } else {
      // 不重播：所有纸直接就位（透明度 1、无偏移）
      const ops: number[] = [];
      for (let i = 0; i < list.length; i++) {
        ops.push(1);
      }
      this.flyOp = ops;
    }
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
  /** P1-7：开口点＝页眉小封面的**实测矩形**顶部中央（左缘＋55vp，封面上缘）。
   *  若尚未测到则回退到布局公式：左 47+12+44+55=158、顶 topInset+6+4=topInset+10。 */
  @State openMeasured: boolean = false;
  @State openXVp: number = 158;
  @State openYVp: number = 38;

  private openingX(): number { return this.openXVp; }
  private openingY(): number { return this.openYVp; }

  /** 量页眉小封面：getRectangleById 取 screenOffset/size，px2vp 后算「顶部中央」。 */
  private measureOpening(ui: UIContext): void {
    try {
      const rect: componentUtils.ComponentInfo =
        ui.getComponentUtils().getRectangleById('hdr_cover');
      const left: number = ui.px2vp(rect.screenOffset.x as number);
      const top: number = ui.px2vp(rect.screenOffset.y as number);
      const w: number = ui.px2vp(rect.size.width as number);
      this.openXVp = left + w / 2;
      this.openYVp = top;
      this.openMeasured = true;
      hilog.info(0x0000, 'DossierDetail', 'opening measured left=%{public}s top=%{public}s w=%{public}s -> (%{public}s,%{public}s)',
        left.toFixed(1), top.toFixed(1), w.toFixed(1),
        this.openXVp.toFixed(1), this.openYVp.toFixed(1));
    } catch (e) {
      hilog.warn(0x0000, 'DossierDetail', 'opening measure failed, fallback formula');
    }
  }

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

  /** P2-12：二次贝塞尔在 t 处的切线角（度）。控制点 = 两点中点上方 120vp。 */
  private tangentDeg(sx: number, sy: number, ex: number, ey: number, t: number): number {
    const mcx: number = (sx + ex) / 2;
    const mcy: number = (sy + ey) / 2 - 120;
    const dx: number = 2 * (1 - t) * (mcx - sx) + 2 * t * (ex - mcx);
    const dy: number = 2 * (1 - t) * (mcy - sy) + 2 * t * (ey - mcy);
    return Math.atan2(dy, dx) * 180 / Math.PI;
  }

  /** P0-2：首屏格数 = 列数 × 可视行数（按可用高与卡片行距现算，不写死 4）。 */
  private firstScreenCount(): number {
    const cols: number = this.colCount();
    // topInset 现由 PageShell 承担（平板/手机实测 43.8/43.9），页眉高 96
    const headH: number = 96 + 44;
    const rowH: number = 246; // 卡片高约 230vp + 行距 16vp（实测 229vp 行距）
    const rows: number = Math.max(1, Math.floor((this.heightVp - headH) / rowH));
    return cols * rows;
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
      // P1-7：先量页眉小封面，得到真实「开口点」（不再用写死常量）
      this.measureOpening(this.getUIContext());
      this.measureCards();
      // P0-2：只有「首屏」的纸做飞出动画；屏外纸直接可见（flyOp=1），不许写死 4
      const anim: number = this.firstScreenCount();
      const ops: number[] = [];
      for (let i = 0; i < n; i++) {
        ops.push(i < anim ? 0 : 1);
      }
      this.flyOp = ops;
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
      // P2-12：起步旋转 0°（不是 -14°），淡入从 0 起
      xs[i] = sx - cxs; ys[i] = sy - cys; rs[i] = 0; os[i] = 0.0;
      this.flyX = xs; this.flyY = ys; this.flyRot = rs; this.flyOp = os;
      // P2-12：5 段 × 70ms = 350ms
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
          // P2-12：飞行中按切线方向微旋转（≤15°），落地回 0°
          rs2[i] = k === steps ? 0 : Math.max(-15, Math.min(15,
            this.tangentDeg(sx, sy, cxs, cys, t)));
          os2[i] = t;
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
        }, 70 * k * FLY_DUR_SCALE);
      }
    }, (200 + i * 100) * FLY_DELAY_SCALE);
  }

  /** P2-9：正文直接用 DocSummary.preview（list() 里算好），build 期不再读文件。 */
  private previewText(p: DocSummary): string {
    const t: string = p.preview === undefined ? '' : p.preview;
    return t.length > 0 ? t : ' ';
  }



  @Builder
  hdrRow() {
        Row() {
          Stack() {
            AppIcon({ kind: 'back', iconSize: 24, color: '#e8ddc9' })
          }
          .width(44).height(44)
          .onClick(() => { this.onBack(); })
          // D13：手机端页眉重算——小封面缩小到 72×50（362vp 宽内不许挤爆换行）
          if (this.dCover.length > 0) {
            Image($rawfile(COVER_RAW[this.dCover]))
              .id('hdr_cover')
              .width(this.widthVp < 600 ? 72 : 110)
              .height(this.widthVp < 600 ? 50 : 74)
              .borderRadius(8).objectFit(ImageFit.Cover)
          } else {
            Column().id('hdr_cover')
              .width(this.widthVp < 600 ? 72 : 110)
              .height(this.widthVp < 600 ? 50 : 74)
              .borderRadius(8).backgroundColor('#eee4ce')
          }
          Column() {
            Text(this.dName).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
              .maxLines(1)
              .onClick(() => {
                // P1-2：点卷宗名改名（复用新建卷宗的输入框式样）
                this.draftName = this.dName;
                this.renaming = true;
              })
            Text(this.papers.length.toString() + ' 张纸')
              .fontSize(12).fontColor('rgba(232,221,201,0.6)').margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start).margin({ left: 14 }).layoutWeight(1)

          Stack() {
            AppIcon({ kind: 'more', iconSize: 22, color: '#e8ddc9' })
          }
          .width(36).height(36)
          .onClick(() => { this.moreOpen = true; })
          // D13：手机端「新建纸张」收进 ⋯ 菜单，不再挤页眉
          if (this.widthVp >= 600) {
            Text('新建纸张').fontSize(12).fontColor('#e8ddc9')
              .padding({ left: 14, right: 14, top: 7, bottom: 7 })
              .borderRadius(28).backgroundColor('#2e2620')
              .margin({ left: 8 })
              .onClick(() => { this.onNewPaper(); })
          }
        }
        .width('100%').height(96).padding({ left: 20, right: 20 })
  }

  @Builder
  body() {
        if (this.papers.length === 0) {
          Column() {
            Text('这里还没有纸。点右上角「新建纸张」放一张进来。')
              .fontSize(12).fontColor('rgba(232,221,201,0.6)')
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
                    Text(this.previewText(p))
                      .fontSize(12).fontColor('#1a1a1a')
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
                    .fontSize(12).fontColor('rgba(232,221,201,0.6)').margin({ top: 2 })
                  Row() {
                    Blank()
                    Text('打开').fontSize(12).fontColor('#c9a45c')
                      .id('open_' + p.id)
                      .onClick(() => { this.onOpenPaper(p.id); })
                    Text('·').fontSize(12).fontColor('rgba(232,221,201,0.4)').margin({ left: 6, right: 6 })
                    Text('删除').fontSize(12).fontColor('rgba(232,221,201,0.6)')
                      .id('del_' + p.id)
                      .onClick(() => { this.pendingDelPaper = p.id; })
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
        }
  }
  @Builder
  delDossierBody() {
    Column() {
      Text('删除「' + this.dName + '」').fontSize(17).fontWeight(FontWeight.Bold)
        .fontColor('#e8ddc9')
      Text('卷宗里的 ' + this.papers.length.toString() + ' 张纸怎么办？')
        .fontSize(12).fontColor('rgba(232,221,201,0.75)').margin({ top: 10 })
      Text('移出卷宗（纸变未归档）').fontSize(15).fontColor('#c9a45c')
        .width('100%').textAlign(TextAlign.Center).margin({ top: 18 })
        .onClick(() => { this.confirmDel = false; this.onDeleteDossier('unfile'); })
      Text('连纸一起删').fontSize(15).fontColor('#a33327')
        .width('100%').textAlign(TextAlign.Center).margin({ top: 14 })
        .onClick(() => { this.confirmDel = false; this.onDeleteDossier('purge'); })
      Text('取消').fontSize(15).fontColor('rgba(232,221,201,0.6)')
        .width('100%').textAlign(TextAlign.Center).margin({ top: 16 })
        .onClick(() => { this.confirmDel = false; })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  delPaperBody() {
    Column() {
      Text('删除这张纸？').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
      Text('删除后不可恢复。').fontSize(12).fontColor('rgba(232,221,201,0.75)')
        .margin({ top: 10 })
      Text('删除').fontSize(15).fontColor('#a33327')
        .id('dlg_del')
        .width('100%').textAlign(TextAlign.Center).margin({ top: 18 })
        .onClick(() => {
          const id: string = this.pendingDelPaper;
          this.pendingDelPaper = '';
          this.onDeletePaper(id);
        })
      Text('取消').fontSize(15).fontColor('rgba(232,221,201,0.6)')
        .id('dlg_cancel')
        .width('100%').textAlign(TextAlign.Center).margin({ top: 16 })
        .onClick(() => { this.pendingDelPaper = ''; })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  renameBody() {
    Column() {
      Text('重命名卷宗').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
      TextInput({ placeholder: '给卷宗起个名字', text: this.draftName })
        .fontSize(15).fontColor('#e8ddc9').margin({ top: 14 })
        .onChange((v: string) => { this.draftName = v; })
      Row() {
        Text('取消').fontSize(15).fontColor('rgba(232,221,201,0.6)')
          .onClick(() => { this.renaming = false; })
        Blank()
        Text('保存').fontSize(15).fontColor('#c9a45c').id('rename_ok')
          .onClick(() => {
            const nm: string = this.draftName.length > 0 ? this.draftName : this.dName;
            dossierStore.rename(this.dossierId, nm);
            this.dName = nm;
            this.renaming = false;
            this.onRenamed();
            hilog.info(0x0000, 'DossierDetail', 'renamed to %{public}s', nm);
          })
      }.width('100%').margin({ top: 18 })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      PageShell({
        widthVp: this.widthVp,
        heightVp: this.heightVp,
        title: '',
        customHeader: true,
        onBack: () => { this.onBack(); },
        content: (): void => { this.body() },
        header: (): void => { this.hdrRow() },
      })
      // D13：⋯ 真菜单（改名／新建纸张／删除卷宗）
      AppMenu({
        visible: this.moreOpen,
        topVp: 56,
        items: [['改名', 'rename'], ['新建纸张', 'newpaper'], ['删除卷宗', 'delete']],
        onClose: () => { this.moreOpen = false; },
        onPick: (key: string): void => {
          if (key === 'rename') {
            this.draftName = this.dName;
            this.renaming = true;
          }
          if (key === 'newpaper') { this.onNewPaper(); }
          if (key === 'delete') { this.confirmDel = true; }
        },
      })
      AppDialog({
        visible: this.confirmDel, widthVp: this.widthVp, heightVp: this.heightVp,
        onClose: () => { this.confirmDel = false; },
        content: (): void => { this.delDossierBody() },
      })
      AppDialog({
        visible: this.pendingDelPaper.length > 0, widthVp: this.widthVp, heightVp: this.heightVp,
        onClose: () => { this.pendingDelPaper = ''; },
        content: (): void => { this.delPaperBody() },
      })
      AppDialog({
        visible: this.renaming, widthVp: this.widthVp, heightVp: this.heightVp,
        onClose: () => { this.renaming = false; },
        content: (): void => { this.renameBody() },
      })
    }
    .width(this.widthVp).height(this.heightVp)
  }
}
