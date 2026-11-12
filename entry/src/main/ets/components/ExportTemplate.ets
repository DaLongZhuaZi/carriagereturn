/**
 * 回车 · F16 导出模板（离屏渲染用；1080×1440 固定尺寸）
 *
 * 只被 ExportService.buildPngTemplate 的 `createFromBuilder` builder 使用：**不挂可见节点**、
 * 不依赖导出页布局（增量设计 §1.1 / B-1 resolve：现有 `export_preview` 不含机器框，
 * 故另做离屏渲染）。
 *
 * 版式全部来自 model/ExportCore.templateLayout()（纯函数，单测 export-pixels）。
 * 机器框图沿用 CollectionDetailPage 的动态拼串先例：`machine/<kind>-side.jpg`。
 * 背景纸色 #f4ecd8，纸面区 #eee4ce，正文摘要取文档前 12 行（fontSize 20 / lineHeight 34）。
 *
 * 注意：本组件的 build 会读一次 docStore（离屏快照是一次性渲染，不进列表/热路径）；
 * 若将来改为常驻可见组件，须像卡片那样把正文在进入前算好再传进来。
 */

import { DocData } from '../model/DocModel';
import { docStore } from '../services/DocStore';
import {
  EXPORT_TEMPLATE_W, EXPORT_TEMPLATE_H, EXPORT_MARGIN_X, EXPORT_TITLE_SIZE, EXPORT_TITLE_H,
  EXPORT_MACHINE_H, EXPORT_DATE_SIZE, EXPORT_DATE_H, EXPORT_BODY_SIZE, EXPORT_BODY_LINES,
  EXPORT_BODY_LINE, EXPORT_PAGE_SIZE, TemplateLayout, TemplateVisibility,
  templateLayout, allVisible,
} from '../model/ExportCore';

/** 机器框图内容宽（画布宽减左右边距）。 */
const FRAME_W: number = EXPORT_TEMPLATE_W - EXPORT_MARGIN_X * 2;
/** 纸面底板宽与左右余量（比版心各宽 40，做出“纸压在垫上”的层）。 */
const PLATE_W: number = 1000;
const PLATE_X: number = (EXPORT_TEMPLATE_W - PLATE_W) / 2;
const PLATE_PAD_X: number = 40;
const PLATE_PAD_Y: number = 24;
// 纸面底板高：12 行正文 + 上下 padding。
const PLATE_H: number = EXPORT_BODY_LINES * EXPORT_BODY_LINE + PLATE_PAD_Y * 2;

/** 纸色（§1 色板：整幅底 #f4ecd8，纸面 #eee4ce，字 #2a231d）。 */
const TEMPLATE_BG: string = '#f4ecd8';
const PLATE_BG: string = '#eee4ce';
const INK: string = '#2a231d';
const INK_SOFT: string = 'rgba(42,35,29,0.68)';

@Component
export struct ExportTemplate {
  @Prop docId: string = '';
  @Prop machineKind: string = '1920s-upright';
  @Prop title: string = '';
  @Prop dateText: string = '';
  /** 第 13 批 ⑥：逐纸渲染入口——正文行由调用方传入（空数组才回落读文档）。 */
  @Prop sheetLines: string[] = [];
  /** 第 13 批 ⑥：页码与总页数（整篇导出时逐纸渲染）。 */
  @Prop pageNo: number = 1;
  @Prop pageTotal: number = 1;
  /** 第 13 批 ⑥：纸色/字体/墨色（跟随当前主题与纸张）。 */
  @Prop paperBg: string = '#eee4ce';
  @Prop fontFamily: string = '';
  @Prop inkColor: string = '#2a231d';
  /** 第 13 批 ⑥：卷宗名（整卷宗导出时显示；空串不显示）。 */
  @Prop dossierName: string = '';
  /** 第 13 批 ⑥：自定义区 5 布尔（可见块）。 */
  @Prop visTitle: boolean = true;
  @Prop visMachine: boolean = true;
  @Prop visDate: boolean = true;
  @Prop visBody: boolean = true;
  @Prop visPageNo: boolean = true;

  /** 版式（纯函数；隐藏块不占位）。 */
  private layout(): TemplateLayout {
    const v: TemplateVisibility = {
      title: this.visTitle, machine: this.visMachine, date: this.visDate,
      body: this.visBody, pageNo: this.visPageNo,
    };
    return templateLayout(v);
  }

  /** 正文摘要：优先用调用方传入的逐纸行；缺省回落读文档前 13 行。 */
  private bodyText(): string {
    if (this.sheetLines.length > 0) {
      const rows: string[] = [];
      for (let i = 0; i < this.sheetLines.length && i < EXPORT_BODY_LINES; i++) {
        rows.push(this.sheetLines[i]);
      }
      return rows.join('\n');
    }
    const d: DocData | null = this.docId.length > 0 ? docStore.load(this.docId) : null;
    if (d === null) {
      return '';
    }
    const parts: string[] = [];
    for (let i = 0; i < d.lines.length && i < EXPORT_BODY_LINES; i++) {
      parts.push(d.lines[i].text);
    }
    return parts.join('\n');
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 标题（可隐藏）
      if (this.visTitle) {
        Text(this.title)
        .fontSize(EXPORT_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(INK)
        .width(FRAME_W).height(EXPORT_TITLE_H).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .position({ x: EXPORT_MARGIN_X, y: this.layout().titleY })

      }
      // 机器框图（顶部；有边框，含机器照片；可隐藏）
      if (this.visMachine) {
        Stack() {
        Image($rawfile('machine/' + this.machineKind + '-side.jpg'))
          .width('100%').height('100%').objectFit(ImageFit.Cover)
      }
      .width(FRAME_W).height(EXPORT_MACHINE_H)
      .backgroundColor(PLATE_BG).borderRadius(10).clip(true)
      .border({ width: 3, color: '#2b2621' })
      .position({ x: EXPORT_MARGIN_X, y: this.layout().machineY })
      }

      // 日期（可隐藏）
      if (this.visDate) {
        Text(this.dateText)
        .fontSize(EXPORT_DATE_SIZE).fontColor(INK_SOFT)
        .width(FRAME_W).height(EXPORT_DATE_H).maxLines(1)
        .position({ x: EXPORT_MARGIN_X, y: this.layout().dateY })
      }

      // 纸面区：底板 + 正文摘要（可隐藏）
      if (this.visBody) {
        Column() {
        Text(this.bodyText())
          .fontSize(EXPORT_BODY_SIZE).lineHeight(EXPORT_BODY_LINE).fontColor(INK)
          .width('100%').maxLines(EXPORT_BODY_LINES)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width(PLATE_W).height(PLATE_H)
      .padding({ left: PLATE_PAD_X, right: PLATE_PAD_X, top: PLATE_PAD_Y, bottom: PLATE_PAD_Y })
      .backgroundColor(this.paperBg).borderRadius(6)
      .alignItems(HorizontalAlign.Start)
      .position({ x: PLATE_X, y: this.layout().bodyTop - PLATE_PAD_Y })
      }

      // 页码（逐纸：pageNo / pageTotal；可隐藏）
      if (this.visPageNo) {
        Text(this.pageNo.toString() + ' / ' + this.pageTotal.toString())
        .fontSize(EXPORT_PAGE_SIZE).fontColor(INK_SOFT)
        .width(FRAME_W).textAlign(TextAlign.End)
        .position({ x: EXPORT_MARGIN_X, y: this.layout().pageNoY })
      }
    }
    .width(EXPORT_TEMPLATE_W).height(EXPORT_TEMPLATE_H)
    .backgroundColor(TEMPLATE_BG)
    .id('export_template')
  }
}