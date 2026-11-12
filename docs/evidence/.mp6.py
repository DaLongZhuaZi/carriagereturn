import io

p = 'entry/src/main/ets/services/ExportService.ets'
s = io.open(p, encoding='utf-8', newline=None).read()

anchor = """  /**
   * PDF 导出：PDF 首页顶部画「机器名＋文档标题＋日期＋页码」文字抬头"""
new_method = """  /**
   * 第 13 批 ⑥：多张模板 PNG → 一份多页 PDF（逐纸先出单页 PDF，再合并）。
   *
   * 能力出处：SDK `hms` 侧 @hms.officeservice.pdfservice 的 PdfDocument 提供
   * createDocument / loadDocument / insertPageFromDocument / deletePage / saveDocument
   * （sdk/default/hms/ets/api/@hms.officeservice.pdfservice.d.ts L647–782）。
   * 单页铺图口径复用 buildPdfFromImage（A4 居中、模板比例）。
   *
   * @param pngPaths 每纸一张模板 PNG（调用方按页码顺序给）
   * @param outPath  沙箱内目标 PDF 路径
   */
  static buildPdfFromImages(pngPaths: string[], outPath: string): ExportResult {
    if (pngPaths.length === 0) {
      return { ok: false, bytes: null, error: 'no pages' };
    }
    const singles: string[] = [];
    let master: pdfService.PdfDocument | null = null;
    try {
      for (let i = 0; i < pngPaths.length; i++) {
        const single: string = outPath + '.p' + i.toString() + '.pdf';
        const r: ExportResult = ExportService.buildPdfFromImage(pngPaths[i], single);
        if (!r.ok) {
          hilog.error(DOMAIN, TAG, 'buildPdfFromImages page %{public}s failed: %{public}s',
            i.toString(), r.error);
          return { ok: false, bytes: null, error: 'page ' + i.toString() + ': ' + r.error };
        }
        singles.push(single);
      }
      const doc: pdfService.PdfDocument = new pdfService.PdfDocument();
      master = doc;
      if (!doc.createDocument(PDF_PAGE_W, PDF_PAGE_H)) {
        return { ok: false, bytes: null, error: 'createDocument failed' };
      }
      for (let i = 0; i < singles.length; i++) {
        const src: pdfService.PdfDocument = new pdfService.PdfDocument();
        try {
          src.loadDocument(singles[i]);
          if (src.getPageCount() < 1) {
            return { ok: false, bytes: null, error: 'page ' + i.toString() + ' unreadable' };
          }
          doc.insertPageFromDocument(src, 0, 1, i);
        } finally {
          try {
            src.releaseDocument();
          } catch (e) {
            hilog.warn(DOMAIN, TAG, 'release src page doc failed');
          }
        }
      }
      // createDocument 自带一页空白；插页后它在末尾，删掉
      doc.deletePage(singles.length, 1);
      if (!doc.saveDocument(outPath)) {
        return { ok: false, bytes: null, error: 'saveDocument failed' };
      }
      const bytes: ArrayBuffer | null = ExportService.readFileBytes(outPath);
      hilog.info(DOMAIN, TAG, 'buildPdfFromImages ok pages=%{public}s bytes=%{public}s',
        singles.length.toString(), bytes === null ? 'null' : bytes.byteLength.toString());
      return { ok: true, bytes: bytes, error: '' };
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'buildPdfFromImages failed: %{public}s', ExportService.errText(err));
      return { ok: false, bytes: null, error: ExportService.errText(err) };
    } finally {
      for (const sp of singles) {
        try {
          fs.unlinkSync(sp);
        } catch (e) {
          hilog.warn(DOMAIN, TAG, 'unlink page pdf failed');
        }
      }
      if (master !== null) {
        try {
          master.releaseDocument();
        } catch (e) {
          hilog.warn(DOMAIN, TAG, 'release master pdf failed');
        }
      }
    }
  }

  /**
   * PDF 导出：PDF 首页顶部画「机器名＋文档标题＋日期＋页码」文字抬头"""
assert anchor in s
s = s.replace(anchor, new_method, 1)
io.open(p, 'w', encoding='utf-8', newline='\r\n').write(s)
print('service multipage ok')
