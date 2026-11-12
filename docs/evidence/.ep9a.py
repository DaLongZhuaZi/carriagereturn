import io

p = 'entry/src/main/ets/components/ExportPage.ets'
s = io.open(p, encoding='utf-8', newline=None).read()

def rep(old, new):
    global s
    if old not in s:
        raise SystemExit('MISS: %r' % old[:80])
    s = s.replace(old, new, 1)

# ---- imports ----
rep("import { DocData, DocLine } from '../model/DocModel';",
    "import { DocData, DocLine, DocSummary } from '../model/DocModel';")
rep("  EXPORT_PROGRESS_MIN_MS, EXPORT_TMP_DIR, EXPORT_BODY_LINES,\n} from '../model/ExportCore';",
    "  EXPORT_PROGRESS_MIN_MS, EXPORT_TMP_DIR, EXPORT_BODY_LINES,\n  assembleSheetText, assembleDossierText,\n} from '../model/ExportCore';")
rep("import { FileHelper } from '../services/FileHelper';",
    "import { FileHelper } from '../services/FileHelper';\nimport { dossierStore } from '../services/DossierStore';")

# ---- PagePlan 接口（放在 FormatSpec 之后） ----
rep("""/** 一次构建的产物：字节＋（pdf 才有）沙箱内临时文件路径。 */""",
"""/** 第 13 批 ⑥：一页的渲染计划（整篇/整卷宗统一口径；页码全局连续）。 */
interface PagePlan {
  docId: string;
  title: string;
  dateText: string;
  dossierName: string;
  lines: string[];
  pageNo: number;
  pageTotal: number;
}

/** 一次构建的产物：字节＋（pdf 才有）沙箱内临时文件路径。 */""")

# ---- 私有渲染字段 ----
rep("""  private pageLines: string[] = [];
  private pageNo: number = 1;
  private pageTotal: number = 1;""",
"""  private pageLines: string[] = [];
  private pageNo: number = 1;
  private pageTotal: number = 1;
  private pageTitle: string = '';
  private pageDate: string = '';
  private pageDossier: string = '';""")

# ---- 预览：进入页面与范围切换都走 previewForRange ----
rep("    this.previewText = this.previewOf(d);",
    "    this.refreshPreview();")

# ---- 助手方法（插在 templateDateText 之前） ----
rep("""  /** 第 13 批 ⑥：模板日期取文档 meta.createdAt（已批准的行为变更；无文档时回落当天）。 */""",
"""  /** 第 13 批 ⑥：范围切换后重算预览，并把 PNG 从「非当前纸」范围强制回 PDF。 */
  private refreshPreview(): void {
    const d: DocData | null = this.docId.length > 0 ? docStore.load(this.docId) : null;
    this.previewText = this.previewForRange(d);
    if (this.range !== 'paper' && this.picked === 0) {
      this.picked = 1;
    }
  }

  /** 第 13 批 ⑥：预览跟随范围（当前纸 / 整篇 / 整卷宗；不跟随自定义开关）。 */
  private previewForRange(d: DocData | null): string {
    if (this.range === 'dossier' && this.dossierId.length > 0) {
      const docs: DocSummary[] = docStore.listByDossier(this.dossierId);
      const lines: string[] = [];
      for (const sum of docs) {
        const dd: DocData | null = docStore.load(sum.id);
        const sheets: DocLine[][] = dd === null || dd.sheets === undefined ? [] : dd.sheets;
        lines.push(sum.title + ' · ' + (sheets.length + 1).toString() + ' 纸');
      }
      if (lines.length > 16) {
        const head: string[] = [];
        for (let i = 0; i < 15; i++) {
          head.push(lines[i]);
        }
        head.push('……共 ' + lines.length.toString() + ' 篇');
        return head.join('\\n');
      }
      return lines.join('\\n') + (lines.length > 0 ? '\\n\\n共 ' + lines.length.toString() + ' 篇' : '');
    }
    if (d === null) {
      return '';
    }
    if (this.range === 'paper') {
      return this.previewOf(d);
    }
    const sheets: DocLine[][] = d.sheets === undefined ? [] : d.sheets;
    const first: DocLine[] = sheets.length > 0 ? sheets[0] : d.lines;
    const parts: string[] = [];
    for (let i = 0; i < first.length; i++) {
      parts.push(first[i].text);
    }
    return parts.join('\\n') + '\\n\\n共 ' + (sheets.length + 1).toString() + ' 纸';
  }

  /** 第 13 批 ⑥：整卷宗名（模板抬头用；非卷宗导出为空串）。 */
  private dossierNameOf(): string {
    if (this.dossierId.length === 0) {
      return '';
    }
    const list = dossierStore.list();
    for (const ds of list) {
      if (ds.id === this.dossierId) {
        return ds.name;
      }
    }
    return '';
  }

  /** 拆分一篇的逐纸行（归档纸在前＋当前纸最后）。 */
  private groupsOf(d: DocData | null): string[][] {
    const groups: string[][] = [];
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

  /** 第 13 批 ⑥：逐页计划（整篇＝归档纸＋当前纸；整卷宗＝逐篇逐纸，页码全局连续）。 */
  private pagePlans(): PagePlan[] {
    const plans: PagePlan[] = [];
    if (this.range === 'dossier' && this.dossierId.length > 0) {
      const docs: DocSummary[] = docStore.listByDossier(this.dossierId);
      const dn: string = this.dossierNameOf();
      for (const sum of docs) {
        const dd: DocData | null = docStore.load(sum.id);
        const groups: string[][] = this.groupsOf(dd);
        const dateText: string = formatDateText(dd === null ? sum.createdAt : dd.meta.createdAt);
        for (let pi = 0; pi < groups.length; pi++) {
          plans.push({
            docId: sum.id, title: sum.title, dateText: dateText, dossierName: dn,
            lines: groups[pi], pageNo: 0, pageTotal: 0,
          });
        }
      }
    } else if (this.docId.length > 0) {
      const dd: DocData | null = docStore.load(this.docId);
      const groups: string[][] = this.groupsOf(dd);
      const title: string = this.docTitleState.length > 0 ? this.docTitleState : this.titleOf(dd);
      const dateText: string = this.templateDateText();
      for (let pi = 0; pi < groups.length; pi++) {
        plans.push({
          docId: this.docId, title: title, dateText: dateText, dossierName: '',
          lines: groups[pi], pageNo: 0, pageTotal: 0,
        });
      }
    }
    const total: number = plans.length;
    for (let i = 0; i < total; i++) {
      plans[i].pageNo = i + 1;
      plans[i].pageTotal = total;
    }
    return plans;
  }

  /** 第 13 批 ⑥：模板日期取文档 meta.createdAt（已批准的行为变更；无文档时回落当天）。 */""")

# ---- 旧 pageGroups 改为委托 groupsOf ----
rep("""  /** 第 13 批 ⑥：本篇逐纸行分组（归档纸在前、当前纸最后；空白纸也算一页）。 */
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
  }""",
"""  /** 第 13 批 ⑥：本篇逐纸行分组（归档纸在前、当前纸最后；空白纸也算一页）。 */
  private pageGroups(): string[][] {
    const d: DocData | null = this.docId.length > 0 ? docStore.load(this.docId) : null;
    return this.groupsOf(d);
  }""")

io.open(p, 'w', encoding='utf-8', newline='\r\n').write(s)
print('exportpage part1 ok')
