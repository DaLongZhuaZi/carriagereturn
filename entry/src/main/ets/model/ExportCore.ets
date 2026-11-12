/**
 * 回车 · 导出纯逻辑（第 3 批：F4 文件保存与分享＋F16 导出模板）
 *
 * 只放**纯函数与常量**：不 import 任何 @kit、不读文件、不碰 picker/分享，
 * 因此可以被 `node --experimental-strip-types --test` 直接加载单测
 * （tools/tests/export-core.test.mjs、export-pixels.test.mjs）。
 *
 * 边界（增量设计 §1.2 resolve）：
 *   - 字节构建归 services/ExportService.ets（可 import @kit）；
 *   - 选位置/写盘归 services/FileHelper.ets；
 *   - 分享面板归 services/ShareService.ets；
 *   - 进度/结果状态归 components/ExportPage.ets。
 */

/** 一次导出的字节结果（失败时 bytes 为 null，error 为原文错误）。 */
export interface ExportResult {
  ok: boolean;
  bytes: ArrayBuffer | null;
  error: string;
}

/**
 * 一次「保存到用户可见位置」的结果。
 * status：'ok' 已写入 | 'cancel' 用户取消选位置 | 'error' 失败。
 */
export interface SaveResult {
  status: string;
  uri: string;
  error: string;
}

/* ------------------------------------------------------------------------- *
 * 反馈 token（§1.10 resolve；docs/界面重设计稿.md §1.1.1 D7）
 * ------------------------------------------------------------------------- */

/** 生成耗时低于该值不显示进度浮层（避免 300ms 级抖动闪一下）。 */
export const EXPORT_PROGRESS_MIN_MS: number = 300;
/** 结果态不淡出（常驻到用户离开导出页）。0 = 不等待。 */
export const EXPORT_RESULT_FADE_MS: number = 0;

/* ------------------------------------------------------------------------- *
 * 分享临时文件目录（filesDir 下；aboutToDisappear 统一清理）
 * ------------------------------------------------------------------------- */

export const EXPORT_TMP_DIR: string = 'export-tmp';

/* ------------------------------------------------------------------------- *
 * F16 离屏模板版式（单位 vp；根节点 1080×1440）
 * ------------------------------------------------------------------------- */

export const EXPORT_TEMPLATE_W: number = 1080;
export const EXPORT_TEMPLATE_H: number = 1440;

/** 模板左右边距（标题/机器框/页码同一条基线）。 */
export const EXPORT_MARGIN_X: number = 80;

/** 第 13 批 ⑥：多纸 TXT 的纸间分隔行（.txt 孪生与 TXT 导出共用同一格式）。 */
export function sheetSeparatorText(no: number, total: number): string {
  return '--- 第 ' + no.toString() + ' / ' + total.toString() + ' 纸 ---';
}

/** 第 13 批 ⑥：整卷宗 TXT 的篇间分隔行。 */
export function docSeparatorText(title: string): string {
  return '=== ' + title + ' ===';
}
/** 标题字号与占位高。 */
export const EXPORT_TITLE_SIZE: number = 56;
export const EXPORT_TITLE_H: number = 72;
/** 标题与机器框之间、机器框与日期之间的间距。 */
export const EXPORT_BLOCK_GAP: number = 32;
/** 机器框图高（宽 = 画布宽 - 2×边距）。 */
export const EXPORT_MACHINE_H: number = 320;
/** 日期字号与占位高。 */
export const EXPORT_DATE_SIZE: number = 28;
export const EXPORT_DATE_H: number = 38;
/** 日期与纸面正文区之间的间距。 */
export const EXPORT_BODY_GAP: number = 40;
/** 纸面正文摘要：行数、行高、字号。 */
export const EXPORT_BODY_LINES: number = 13;
export const EXPORT_BODY_LINE: number = 34;
export const EXPORT_BODY_SIZE: number = 20;
/** 页码字号、占位高与底距。 */
export const EXPORT_PAGE_SIZE: number = 22;
export const EXPORT_PAGE_H: number = 30;
export const EXPORT_PAGE_GAP: number = 40;

/** 模板各元素的纵向位置（全部相对 1080×1440 画布左上角）。 */
export interface TemplateLayout {
  /** 标题文字顶边 y。 */
  titleY: number;
  /** 机器框图顶边 y。 */
  machineY: number;
  /** 日期文字顶边 y。 */
  dateY: number;
  /** 纸面正文第一行顶边 y。 */
  bodyTop: number;
  /** 正文行距。 */
  bodyLine: number;
  /** 页码文字顶边 y。 */
  pageNoY: number;
}

/**
 * 第 13 批 ⑥：模板可见块（自定义区 5 布尔）。
 * 隐藏的块不占位，templateLayout 按可见块重算 Y（自上而下紧排）。
 */
export interface TemplateVisibility {
  title: boolean;
  machine: boolean;
  date: boolean;
  body: boolean;
  pageNo: boolean;
}

/** 全部可见（导出页缺省）。 */
export function allVisible(): TemplateVisibility {
  return { title: true, machine: true, date: true, body: true, pageNo: true };
}

/**
 * 版式纯计算：标题 → 机器框 → 日期 → 纸面正文 → 页码，自上而下、互不重叠。
 * 第 13 批 ⑥：可见块决定哪些行走；隐藏块连同其间距一起跳过。
 * 返回的 6 个数全部落在 1080×1440 内（export-pixels.test.mjs 断言）。
 */
export function templateLayout(visible: TemplateVisibility = allVisible()): TemplateLayout {
  const titleY: number = 96;
  let cursor: number = titleY;
  let machineY: number = titleY;
  let dateY: number = titleY;
  let bodyTop: number = titleY;
  if (visible.title) {
    cursor = titleY + EXPORT_TITLE_H + EXPORT_BLOCK_GAP;
  }
  machineY = cursor;
  if (visible.machine) {
    cursor = cursor + EXPORT_MACHINE_H + EXPORT_BLOCK_GAP;
  }
  dateY = cursor;
  if (visible.date) {
    cursor = cursor + EXPORT_DATE_H + EXPORT_BODY_GAP;
  }
  bodyTop = cursor;
  const pageNoY: number = EXPORT_TEMPLATE_H - EXPORT_PAGE_GAP - EXPORT_PAGE_H;
  return {
    titleY: titleY,
    machineY: machineY,
    dateY: dateY,
    bodyTop: bodyTop,
    bodyLine: EXPORT_BODY_LINE,
    pageNoY: pageNoY,
  };
}

/** 第 13 批 ⑥：时间戳 → yyyy-MM-dd（模板日期取文档 meta.createdAt，不再取当天）。 */
export function formatDateText(ts: number): string {
  const d: Date = new Date(ts);
  const m: number = d.getMonth() + 1;
  const day: number = d.getDate();
  return d.getFullYear().toString() + '-' + (m < 10 ? '0' + m.toString() : m.toString()) +
    '-' + (day < 10 ? '0' + day.toString() : day.toString());
}

/**
 * 第 13 批 ⑥：一篇文章的多纸纯文本（纸间分隔行；当前纸在最后、无分隔行）。
 */
export function assembleSheetText(sheets: string[][], current: string[]): string {
  const parts: string[] = [];
  const total: number = sheets.length + 1;
  for (let i = 0; i < sheets.length; i++) {
    for (const line of sheets[i]) {
      parts.push(line);
    }
    parts.push(sheetSeparatorText(i + 1, total));
  }
  for (const line of current) {
    parts.push(line);
  }
  return parts.join('\n') + '\n';
}

/**
 * 第 13 批 ⑥：整卷宗多篇纯文本（篇间 `=== <标题> ===`，篇内纸分隔同 assembleSheetText）。
 */
export function assembleDossierText(docs: string[]): string {
  const parts: string[] = [];
  for (let i = 0; i < docs.length; i++) {
    if (i > 0) {
      parts.push('');
    }
    parts.push(docs[i].replace(/\n+$/, ''));
  }
  return parts.join('\n') + '\n';
}

/* ------------------------------------------------------------------------- *
 * 文件名（§1.11 resolve / M-10）
 * ------------------------------------------------------------------------- */

/** 文件系统非法字符（Windows 与 HarmonyOS 文件管理器同口径）。 */
const ILLEGAL_NAME_CHARS: string = '\\/:*?"<>|';

function pad2(n: number): string {
  return n < 10 ? '0' + n.toString() : n.toString();
}

/** 时间戳 → yyyyMMdd-HHmmss（本地时区，与用户所见一致）。 */
function stampOf(ts: number): string {
  const d: Date = new Date(ts);
  return d.getFullYear().toString() + pad2(d.getMonth() + 1) + pad2(d.getDate()) +
    '-' + pad2(d.getHours()) + pad2(d.getMinutes()) + pad2(d.getSeconds());
}

/** 去非法字符/控制字符，压缩空白串，去首尾空白。 */
function sanitize(raw: string): string {
  let out: string = '';
  let lastSpace: boolean = false;
  for (let i = 0; i < raw.length; i++) {
    const ch: string = raw.charAt(i);
    const code: number = raw.charCodeAt(i);
    if (code < 32 || ILLEGAL_NAME_CHARS.indexOf(ch) >= 0) {
      continue;
    }
    const isSpace: boolean = ch === ' ' || ch === '\t';
    if (isSpace) {
      if (lastSpace || out.length === 0) {
        continue;
      }
      lastSpace = true;
      out += ' ';
      continue;
    }
    lastSpace = false;
    out += ch;
  }
  // 去掉尾部空白（循环已压掉头部与连续空白）
  while (out.length > 0 && out.charAt(out.length - 1) === ' ') {
    out = out.substring(0, out.length - 1);
  }
  return out;
}

/**
 * 生成默认文件名：`回车-<title>-<yyyyMMdd-HHmmss>.<ext>`。
 * 非法字符 `\ / : * ? " < > |` 一律去掉；标题为空（或只剩非法字符）回落「回车」。
 * @param title 文档标题（可为空）
 * @param ext 扩展名（可带前导点，空则不加扩展名）
 * @param ts 时间戳（ms）；非法值用当前时间
 */
export function safeFileName(title: string, ext: string, ts: number): string {
  const safeTitle: string = sanitize(title);
  const name: string = safeTitle.length > 0 ? safeTitle : '回车';
  let e: string = sanitize(ext);
  if (e.length > 0 && e.charAt(0) === '.') {
    e = sanitize(e.substring(1));
  }
  const stamp: string = stampOf(isFinite(ts) ? ts : Date.now());
  const base: string = '回车-' + name + '-' + stamp;
  return e.length > 0 ? base + '.' + e : base;
}

/* ------------------------------------------------------------------------- *
 * 机器名资源键（M-1 resolve：机名在 string.json，不在这里写中文）
 * ------------------------------------------------------------------------- */

const MACHINE_NAME_1920S: string = 'machine_name_1920s';

/**
 * 机器 kind → `machine_name_*` 资源键；未知 kind 回落 1920s 默认机。
 * 只返回**键名**：拿中文串由调用方（页面）走 resourceManager。
 */
export function machineTitleKey(kind: string): string {
  if (kind === '1930s-portable') {
    return 'machine_name_1930s';
  }
  if (kind === '1950s-streamlined') {
    return 'machine_name_1950s';
  }
  if (kind === '1960s-electric') {
    return 'machine_name_1960s';
  }
  return MACHINE_NAME_1920S;
}

/* ------------------------------------------------------------------------- *
 * 结果态文案键（M-5 resolve：永不宣称“已分享成功”）
 * ------------------------------------------------------------------------- */

/**
 * 一次导出成功后该显示哪句文案，返回**资源键名**（页面里再映射到 $r）。
 * 仅保存 → export_result_saved；仅分享 → export_result_shared；
 * 两者 → export_result_saved_shared；都没发生 → 空串（不进结果态）。
 * 系统分享面板只能证明“已调起”，本函数不会产出任何“已分享成功”的键。
 */
export function resultText(saved: boolean, shared: boolean): string {
  if (saved && shared) {
    return 'export_result_saved_shared';
  }
  if (saved) {
    return 'export_result_saved';
  }
  if (shared) {
    return 'export_result_shared';
  }
  return '';
}