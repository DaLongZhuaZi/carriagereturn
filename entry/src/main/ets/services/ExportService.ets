/**
 * 回车 · 导出字节构建服务（第 3 批：F4 文件保存与分享＋F16 导出模板）
 *
 * 服务边界（增量设计 §1.2 resolve / B-2）：
 *   - 本服务**只做「文档 → 字节」**：txt／pdf／png；
 *   - 让用户选位置并写盘归 services/FileHelper.ets；
 *   - 系统分享面板归 services/ShareService.ets；
 *   - 进度/结果 @State 与临时文件清理归 components/ExportPage.ets。
 * 所有入口**不抛异常**：失败返回 `{ ok:false, bytes:null, error:<原文> }`。
 *
 * 已知未验项（批报告记录）：
 *   - PDF 中文是否能正确出字：沿用既有 pdfService 文本路径，设备未验（UNVERIFIED）；
 *   - PDF 只出第一页（沿用第 0 批 Index 现码：正文写到页底为止，不做分页）；
 *   - `createFromBuilder` 离屏渲染在本机无设备，仅按 SDK 声明实现（见 buildPngTemplate）。
 */

import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';
import { UIContext } from '@kit.ArkUI';
import { pdfService } from '@kit.PDFKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { docStore } from './DocStore';
import { ExportResult, EXPORT_TEMPLATE_W, EXPORT_TEMPLATE_H } from '../model/ExportCore';

const DOMAIN: number = 0x0000;
const TAG: string = 'ExportService';

/** PDF 页面尺寸（A4，pt）与版心。 */
const PDF_PAGE_W: number = 595;
const PDF_PAGE_H: number = 842;
const PDF_MARGIN_X: number = 48;
// R1（第 8 批）：pdfService 的 TextStyle 必须带 fontInfo，缺它 addTextObject 静默不落笔，
// 导出的 PDF 会没有 /Contents（整页空白）。用系统 CJK 字体（含中文字形）。
const PDF_FONT_PATH: string = '/system/fonts/HarmonyOS_Sans.ttf';
const PDF_FONT_NAME: string = 'HarmonyOS Sans';
const PDF_HEAD_Y: number = 806;
const PDF_BODY_TOP_Y: number = 754;
const PDF_BODY_LINE: number = 16;
const PDF_BODY_MIN_Y: number = 48;

/** 导出字节构建（全静态，无状态）。 */
export class ExportService {
  /**
   * 纯文本导出：读文档 .txt → UTF-8 字节。
   * 文本为空也返回 ok（由导出页的 onBeforeExport 负责“空文档”判定）。
   */
  static buildTxt(docId: string): ExportResult {
    try {
      const text: string = docStore.readPlainText(docId);
      const encoded: Uint8Array = new util.TextEncoder().encodeInto(text);
      const words: ArrayBuffer = new ArrayBuffer(encoded.length);
      const view: Uint8Array = new Uint8Array(words);
      for (let i = 0; i < encoded.length; i++) {
        view[i] = encoded[i];
      }
      hilog.info(DOMAIN, TAG, 'buildTxt ok doc=%{public}s bytes=%{public}s',
        docId, encoded.length.toString());
      return { ok: true, bytes: words, error: '' };
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'buildTxt failed: %{public}s', ExportService.errText(err));
      return { ok: false, bytes: null, error: ExportService.errText(err) };
    }
  }

  /**
   * PDF 导出（图文版，第 9 批 P1）：把 F16 的离屏模板 PNG（1080×1440，含机器框／纸张／抬头）
   * 铺进 A4 首页——PDF 与「图片」导出**同一视觉**，不再是一页默认字体的纯文本。
   * 版式：A4 595×842pt，两侧各留 24pt，图按 1080:1440 等比缩放后纵向居中。
   *
   * @param pngPath 沙箱内已落盘的模板 PNG 绝对路径（addImageObject 只认真实路径）
   * @param outPath 沙箱内目标 PDF 路径
   */
  static buildPdfFromImage(pngPath: string, outPath: string): ExportResult {
    let pdf: pdfService.PdfDocument | null = null;
    try {
      const doc: pdfService.PdfDocument = new pdfService.PdfDocument();
      pdf = doc;
      if (!doc.createDocument(PDF_PAGE_W, PDF_PAGE_H)) {
        hilog.error(DOMAIN, TAG, 'buildPdfFromImage createDocument failed');
        return { ok: false, bytes: null, error: 'createDocument failed' };
      }
      const page: pdfService.PdfPage = doc.getPage(0);
      const imgW: number = PDF_PAGE_W - 2 * PDF_MARGIN_X;
      const imgH: number = imgW * (EXPORT_TEMPLATE_H / EXPORT_TEMPLATE_W);
      const top: number = (PDF_PAGE_H - imgH) / 2;
      page.addImageObject(pngPath, PDF_MARGIN_X, top, imgW, imgH);
      const ok: boolean = doc.saveDocument(outPath);
      if (!ok) {
        hilog.error(DOMAIN, TAG, 'buildPdfFromImage saveDocument failed path=%{public}s', outPath);
        return { ok: false, bytes: null, error: 'saveDocument failed' };
      }
      const bytes: ArrayBuffer | null = ExportService.readFileBytes(outPath);
      hilog.info(DOMAIN, TAG, 'buildPdfFromImage ok img=%{public}s bytes=%{public}s',
        pngPath, bytes === null ? 'null' : bytes.byteLength.toString());
      return { ok: true, bytes: bytes, error: '' };
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'buildPdfFromImage failed: %{public}s', ExportService.errText(err));
      return { ok: false, bytes: null, error: ExportService.errText(err) };
    } finally {
      if (pdf !== null) {
        try {
          pdf.releaseDocument();
        } catch (e) {
          const err2: BusinessError = e as BusinessError;
          hilog.warn(DOMAIN, TAG, 'releaseDocument: %{public}s', ExportService.errText(err2));
        }
      }
    }
  }

  /**
   * PDF 导出：PDF 首页顶部画「机器名＋文档标题＋日期＋页码」文字抬头（§1.5 resolve：
   * 只画文字；pdfService 无画线 API 实证，双细线不做），正文沿用现有文本路径。
   * 生成的文件写在 outPath（调用方给沙箱内路径），并把读回的字节放入 `bytes`
   * 供「保存到用户可见位置」直接写入；读回失败时 bytes 为 null（分享仍可用文件）。
   *
   * @param machineLabel 机器名（页面已解析为本地化字符串；服务读不了 string 资源）
   * @param title 文档标题
   * @param dateText 日期文本（页面已格式化）
   * @param outPath 沙箱内目标路径
   */
  /** R1：构造带 fontInfo 的文字样式（缺 fontInfo 时 pdfService 不落笔，见 PDF_FONT_PATH 注释）。 */
  private static pdfTextStyle(size: number): pdfService.TextStyle {
    const st: pdfService.TextStyle = new pdfService.TextStyle();
    st.textSize = size;
    const fi: pdfService.FontInfo = new pdfService.FontInfo();
    fi.fontPath = PDF_FONT_PATH;
    fi.fontName = PDF_FONT_NAME;
    st.fontInfo = fi;
    return st;
  }

  static buildPdf(docId: string, machineLabel: string, title: string, dateText: string,
    outPath: string): ExportResult {
    let pdf: pdfService.PdfDocument | null = null;
    try {
      const text: string = docStore.readPlainText(docId);
      const lines: string[] = text.split('\n');
      const doc: pdfService.PdfDocument = new pdfService.PdfDocument();
      pdf = doc;
      if (!doc.createDocument(PDF_PAGE_W, PDF_PAGE_H)) {
        hilog.error(DOMAIN, TAG, 'buildPdf createDocument failed');
        return { ok: false, bytes: null, error: 'createDocument failed' };
      }
      const page: pdfService.PdfPage = doc.getPage(0);

      // 信纸头：机名（12pt）／标题（12pt）／日期＋页码（9pt），只画文字
      const headStyle: pdfService.TextStyle = ExportService.pdfTextStyle(12);
      page.addTextObject(machineLabel, PDF_MARGIN_X, PDF_HEAD_Y, headStyle);
      page.addTextObject(title, PDF_MARGIN_X, PDF_HEAD_Y - 18, headStyle);
      const subStyle: pdfService.TextStyle = ExportService.pdfTextStyle(9);
      page.addTextObject(dateText + '  ·  1', PDF_MARGIN_X, PDF_HEAD_Y - 34, subStyle);

      // 正文（与第 0 批同口径：写到页底为止，不分页）
      const bodyStyle: pdfService.TextStyle = ExportService.pdfTextStyle(11);
      let y: number = PDF_BODY_TOP_Y;
      let drawn: number = 0;
      for (let i = 0; i < lines.length && y > PDF_BODY_MIN_Y; i++) {
        if (lines[i].length > 0) {
          page.addTextObject(lines[i], PDF_MARGIN_X, y, bodyStyle);
          drawn += 1;
        }
        y -= PDF_BODY_LINE;
      }
      const ok: boolean = doc.saveDocument(outPath);
      if (!ok) {
        hilog.error(DOMAIN, TAG, 'buildPdf saveDocument failed path=%{public}s', outPath);
        return { ok: false, bytes: null, error: 'saveDocument failed' };
      }
      if (drawn < lines.length) {
        hilog.warn(DOMAIN, TAG, 'buildPdf single page: drawn=%{public}s of %{public}s lines',
          drawn.toString(), lines.length.toString());
      }
      const bytes: ArrayBuffer | null = ExportService.readFileBytes(outPath);
      hilog.info(DOMAIN, TAG, 'buildPdf ok doc=%{public}s lines=%{public}s bytes=%{public}s',
        docId, drawn.toString(), bytes === null ? 'null' : bytes.byteLength.toString());
      return { ok: true, bytes: bytes, error: '' };
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'buildPdf failed: %{public}s', ExportService.errText(err));
      return { ok: false, bytes: null, error: ExportService.errText(err) };
    } finally {
      if (pdf !== null) {
        try {
          pdf.releaseDocument();
        } catch (e2) {
          hilog.warn(DOMAIN, TAG, 'buildPdf releaseDocument failed');
        }
      }
    }
  }

  /**
   * F4 现有快照路径：抓导出页可见的 `export_preview`（纸面＋正文，**不含机器框**）。
   * 同时作为 F16 模板渲染失败时的回退（§5 R1）。
   */
  static async buildPngFromPreview(ui: UIContext, nodeId: string): Promise<ExportResult> {
    try {
      const pm: image.PixelMap = await ui.getComponentSnapshot().get(nodeId);
      const bytes: ArrayBuffer = await ExportService.packPng(pm);
      hilog.info(DOMAIN, TAG, 'buildPngFromPreview ok node=%{public}s bytes=%{public}s',
        nodeId, bytes.byteLength.toString());
      return { ok: true, bytes: bytes, error: '' };
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'buildPngFromPreview failed: %{public}s', ExportService.errText(err));
      return { ok: false, bytes: null, error: ExportService.errText(err) };
    }
  }

  /**
   * F16 离屏模板：`UIContext.getComponentSnapshot().createFromBuilder(builder, 320, true)`
   * 直接渲染 1080×1440 的 ExportTemplate（含机器框图），再打包成 PNG 字节。
   *
   * **builder 为什么是第 6 个参数**：SDK 明确 `createFromBuilder` 的 builder 必须是
   * 自定义组件作用域里的 @Builder（「The global builder is not supported」），
   * 服务是静态类、拿不到组件作用域，所以由 ExportPage 传入自己的 @Builder。
   * 前 5 个业务参数用于日志（渲染内容的唯一事实源是 builder 里传给 ExportTemplate 的 props）。
   *
   * 失败（含图片未就绪 160001）返回 ok:false，调用方回退 buildPngFromPreview。
   */
  static async buildPngTemplate(ui: UIContext, docId: string, machineKind: string,
    title: string, dateText: string, builder: () => void): Promise<ExportResult> {
    try {
      hilog.info(DOMAIN, TAG, 'buildPngTemplate start doc=%{public}s kind=%{public}s title=%{public}s date=%{public}s',
        docId, machineKind, title, dateText);
      const pm: image.PixelMap = await ui.getComponentSnapshot().createFromBuilder(builder, 320, true);
      const bytes: ArrayBuffer = await ExportService.packPng(pm);
      hilog.info(DOMAIN, TAG, 'buildPngTemplate ok bytes=%{public}s', bytes.byteLength.toString());
      return { ok: true, bytes: bytes, error: '' };
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'buildPngTemplate failed: %{public}s', ExportService.errText(err));
      return { ok: false, bytes: null, error: ExportService.errText(err) };
    }
  }

  /** PixelMap → PNG 字节；无论成功失败都释放 packer 与 PixelMap。 */
  private static async packPng(pm: image.PixelMap): Promise<ArrayBuffer> {
    const packer: image.ImagePacker = image.createImagePacker();
    try {
      const opts: image.PackingOption = { format: 'image/png', quality: 100 };
      return await packer.packToData(pm, opts);
    } finally {
      try {
        await packer.release();
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'packer release failed');
      }
      try {
        await pm.release();
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'pixelmap release failed');
      }
    }
  }

  /** 读整个文件为 ArrayBuffer；读不到返回 null（不抛）。 */
  /** 把字节写到沙箱文件（供「先出模板 PNG、再铺进 PDF」用）。 */
  static writeBytes(filePath: string, bytes: ArrayBuffer): boolean {
    try {
      const f: fs.File = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(f.fd, bytes);
      } finally {
        fs.closeSync(f);
      }
      return true;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'writeBytes failed %{public}s: %{public}s', filePath,
        ExportService.errText(err));
      return false;
    }
  }

  private static readFileBytes(filePath: string): ArrayBuffer | null {
    let file: fs.File | null = null;
    try {
      const stat: fs.Stat = fs.statSync(filePath);
      if (stat.size <= 0) {
        return null;
      }
      const words: ArrayBuffer = new ArrayBuffer(stat.size);
      file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      fs.readSync(file.fd, words);
      return words;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'readFileBytes failed: %{public}s', ExportService.errText(err));
      return null;
    } finally {
      if (file !== null) {
        try {
          fs.closeSync(file);
        } catch (e2) {
          hilog.warn(DOMAIN, TAG, 'readFileBytes close failed');
        }
      }
    }
  }

  /** 错误原文（空消息回落一句固定英文，避免界面出现空错误行）。 */
  private static errText(err: BusinessError): string {
    const msg: string = err.message === undefined ? '' : err.message;
    return msg.length > 0 ? msg : 'export failed';
  }
}