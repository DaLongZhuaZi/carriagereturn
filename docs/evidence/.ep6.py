import io

p = 'entry/src/main/ets/components/ExportPage.ets'
s = io.open(p, encoding='utf-8', newline=None).read()

# 0) import DocLine
old = "import { DocData } from '../model/DocModel';"
if old in s and 'DocLine' not in s.split('import { DocData')[1][:80]:
    s = s.replace(old, "import { DocData, DocLine } from '../model/DocModel';", 1)

# 1) 私有逐纸渲染字段
old = """  private tmpFiles: string[] = [];
  private progTimer: number = -1;"""
new = """  private tmpFiles: string[] = [];
  /** 第 13 批 ⑥：离屏逐纸渲染的当前页数据（非 @State：builder 一次性读取，无需触发重渲染）。 */
  private pageLines: string[] = [];
  private pageNo: number = 1;
  private pageTotal: number = 1;
  private progTimer: number = -1;"""
assert old in s
s = s.replace(old, new, 1)

# 2) 日期取文档 createdAt（第 13 批 ⑥ 行为变更）
old = """    this.dateText = this.todayText();"""
new = """    this.dateText = this.templateDateText();"""
assert old in s
s = s.replace(old, new, 1)

# 3) 新助手：模板日期与逐纸分组（插在 todayText 之前）
old = """  private todayText(): string {"""
new = """  /** 第 13 批 ⑥：模板日期取文档 meta.createdAt（已批准的行为变更；无文档时回落当天）。 */
  private templateDateText(): string {
    const d: DocData | null = this.docId.length > 0 ? docStore.load(this.docId) : null;
    if (d === null) {
      return this.todayText();
    }
    return formatDateText(d.meta.createdAt);
  }

  /** 第 13 批 ⑥：本篇逐纸行分组（归档纸在前、当前纸最后；空白纸也算一页）。 */
  private pageGroups(): string[][] {
    const groups: string[][] = [];
    const d: DocData | null = this.docId.length > 0 ? docStore.load(this.docId) : null;
    const sheets: DocLine[][] = d === null || d.sheets === undefined ? [] : d.sheets;
    for (let si = 0; si < sheets.length; si++) {
      const rows: string[] = [];
      for (const line of sheets[si]) {
        rows.push(line.text);
      }
      groups.push(rows);
    }
    const cur: string[] = [];
    if (d !== null) {
      for (const line of d.lines) {
        cur.push(line.text);
      }
    }
    groups.push(cur);
    return groups;
  }

  private todayText(): string {"""
assert old in s
s = s.replace(old, new, 1)

# 4) buildFor：pdf 逐纸渲染 + 合并
old = """      const path: string = dir + '/' + safeFileName(this.docTitleState, 'pdf', Date.now());
      // 第 9 批 P1（用户真机反馈）：PDF 要**和图片导出同一视觉**（本机纸张＋机器框＋抬头），
      // 不再是一页默认字体的纯文本。做法＝先出 F16 模板 PNG，再把它铺进 A4 首页。
      const ui: UIContext = this.getUIContext();
      const t: ExportResult = await ExportService.buildPngTemplate(ui, this.docId, this.machineKind,
        this.docTitleState, this.dateText, (): void => { this.templateBuilder(); });
      if (t.ok && t.bytes !== null) {
        const pngPath: string = dir + '/' + safeFileName(this.docTitleState, 'pngimg', Date.now());
        if (ExportService.writeBytes(pngPath, t.bytes)) {
          const r2: ExportResult = ExportService.buildPdfFromImage(pngPath, path);
          if (r2.ok) {
            this.tmpFiles.push(path);
            this.tmpFiles.push(pngPath);
            return { ok: true, bytes: r2.bytes, path: path, error: '' };
          }
          hilog.warn(DOMAIN, TAG, 'pdf image build failed, fallback to text: %{public}s', r2.error);
        } else {
          hilog.warn(DOMAIN, TAG, 'pdf template png write failed, fallback to text');
        }
      } else {
        hilog.warn(DOMAIN, TAG, 'pdf template failed, fallback to text: %{public}s', t.error);
      }"""
new = """      const path: string = dir + '/' + safeFileName(this.docTitleState, 'pdf', Date.now());
      // 第 9 批 P1（用户真机反馈）：PDF 要**和图片导出同一视觉**（本机纸张＋机器框＋抬头），
      // 不再是一页默认字体的纯文本。做法＝先出 F16 模板 PNG，再把它铺进 A4 首页。
      // 第 13 批 ⑥：逐纸渲染（归档纸＋当前纸各一页），多页走 insertPageFromDocument 合并。
      const ui: UIContext = this.getUIContext();
      const groups: string[][] = this.pageGroups();
      const total: number = groups.length;
      const pngPaths: string[] = [];
      let allOk: boolean = true;
      for (let pi = 0; pi < total; pi++) {
        this.pageLines = groups[pi].slice(0, EXPORT_BODY_LINES);
        this.pageNo = pi + 1;
        this.pageTotal = total;
        const t: ExportResult = await ExportService.buildPngTemplate(ui, this.docId, this.machineKind,
          this.docTitleState, this.dateText, (): void => { this.templateBuilder(); });
        if (!t.ok || t.bytes === null) {
          hilog.warn(DOMAIN, TAG, 'pdf page %{public}s template failed: %{public}s',
            (pi + 1).toString(), t.error);
          allOk = false;
          break;
        }
        const pngPath: string = dir + '/' + safeFileName(this.docTitleState + '-' + (pi + 1).toString(),
          'png', Date.now());
        if (!ExportService.writeBytes(pngPath, t.bytes)) {
          hilog.warn(DOMAIN, TAG, 'pdf page %{public}s png write failed', (pi + 1).toString());
          allOk = false;
          break;
        }
        pngPaths.push(pngPath);
        this.tmpFiles.push(pngPath);
      }
      if (allOk && pngPaths.length > 0) {
        const r2: ExportResult = pngPaths.length > 1
          ? ExportService.buildPdfFromImages(pngPaths, path)
          : ExportService.buildPdfFromImage(pngPaths[0], path);
        if (r2.ok) {
          this.tmpFiles.push(path);
          hilog.info(DOMAIN, TAG, 'export pdf pages=%{public}s', pngPaths.length.toString());
          return { ok: true, bytes: r2.bytes, path: path, error: '' };
        }
        hilog.warn(DOMAIN, TAG, 'pdf image build failed, fallback to text: %{public}s', r2.error);
      } else {
        hilog.warn(DOMAIN, TAG, 'pdf template failed, fallback to text');
      }"""
assert old in s
s = s.replace(old, new, 1)

# 5) image 分支：只渲第一页（PNG 仅「当前纸」可用；整篇时取首纸）
old = """    // 图片：F16 模板优先（含机器框）
    const ui: UIContext = this.getUIContext();
    const t: ExportResult = await ExportService.buildPngTemplate(ui, this.docId, this.machineKind,
      this.docTitleState, this.dateText, (): void => { this.templateBuilder(); });"""
new = """    // 图片：F16 模板优先（含机器框）；整篇/整卷宗时 PNG 只出首纸
    const ui: UIContext = this.getUIContext();
    const imgGroups: string[][] = this.pageGroups();
    this.pageLines = imgGroups.length > 0 ? imgGroups[0].slice(0, EXPORT_BODY_LINES) : [];
    this.pageNo = 1;
    this.pageTotal = Math.max(1, imgGroups.length);
    const t: ExportResult = await ExportService.buildPngTemplate(ui, this.docId, this.machineKind,
      this.docTitleState, this.dateText, (): void => { this.templateBuilder(); });"""
assert old in s
s = s.replace(old, new, 1)

# 6) builder 传逐纸 props
old = """      ExportTemplate({
        docId: this.docId,
        machineKind: this.machineKind,
        title: this.docTitleState,
        dateText: this.dateText,
      })"""
new = """      ExportTemplate({
        docId: this.docId,
        machineKind: this.machineKind,
        title: this.docTitleState,
        dateText: this.dateText,
        sheetLines: this.pageLines,
        pageNo: this.pageNo,
        pageTotal: this.pageTotal,
      })"""
assert old in s
s = s.replace(old, new, 1)

# 7) import formatDateText
old = "import { EXPORT_TEMPLATE_W, EXPORT_TEMPLATE_H, safeFileName, ExportResult, EXPORT_BODY_LINES } from '../model/ExportCore';"
if old in s:
    s = s.replace(old, "import { EXPORT_TEMPLATE_W, EXPORT_TEMPLATE_H, safeFileName, ExportResult, EXPORT_BODY_LINES,\n  formatDateText } from '../model/ExportCore';", 1)
else:
    # 兜底：在最后一个 ExportCore import 行后加
    idx = s.find("from '../model/ExportCore';")
    if idx > 0:
        end = s.find('\n', idx)
        s = s[:end] + "\nimport { formatDateText } from '../model/ExportCore';" + s[end:]

io.open(p, 'w', encoding='utf-8', newline='\r\n').write(s)
print('exportpage multipage ok')
