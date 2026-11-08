/**
 * 回车 · DocStore 状态模型的纯逻辑（第 0 批）。
 *
 * 状态：active（默认）／trashed（回收站）。第 0 批只定模型与签名；
 * **第 6 批 F10 已翻转**：DocStore.remove()＝trash、list() 只返回 active，
 * 新增 expiredRecords（30 天清理）。
 *
 * 纯函数：不碰文件、不 import @kit，可 Node 单测。
 * DocStore 只做 I/O：读索引 → 调本文件 → 写索引。
 */

/** 索引记录（与 DocStore.DocIndexEntry 同构；DocStore 的接口 extends 本类型）。 */
export interface DocIndexRecord {
  id: string;
  title: string;
  createdAt: number;
  updatedAt: number;
  dossierId?: string | null;
  machine?: string;
  paper?: string;
  /** 'active' | 'trashed'；缺省（旧文档）＝ active。 */
  state?: string;
  /** 入回收站时间（ms）；只有 trashed 有值。 */
  trashedAt?: number;
  /** 入回收站前所属卷宗；恢复时回到原卷宗。 */
  origDossierId?: string | null;
}

/** 搜索选项。 */
export interface DocSearchOptions {
  includeTrashed?: boolean;
  /** 命中上限，缺省 20。 */
  limit?: number;
}

/** 一条搜索命中。 */
export interface DocSearchHit {
  id: string;
  title: string;
  /** 'title' | 'content' */
  matchedIn: string;
  /** 正文命中时的一行摘要（title 命中为空）。 */
  snippet: string;
  updatedAt: number;
}

export const DOC_STATE_ACTIVE: string = 'active';
export const DOC_STATE_TRASHED: string = 'trashed';

/** 记录状态（旧文档缺字段＝active）。 */
export function stateOf(rec: DocIndexRecord): string {
  return rec.state === undefined || rec.state === null || rec.state.length === 0
    ? DOC_STATE_ACTIVE : rec.state;
}

/** 是否 active。 */
export function isActive(rec: DocIndexRecord): boolean {
  return stateOf(rec) === DOC_STATE_ACTIVE;
}

/** 是否 trashed。 */
export function isTrashed(rec: DocIndexRecord): boolean {
  return stateOf(rec) === DOC_STATE_TRASHED;
}

/** 把一条记录移入回收站；返回是否真的改了。 */
export function trashRecord(index: DocIndexRecord[], id: string, nowMs: number): boolean {
  for (let i = 0; i < index.length; i++) {
    const rec: DocIndexRecord = index[i];
    if (rec.id !== id) {
      continue;
    }
    if (isTrashed(rec)) {
      return false;
    }
    rec.state = DOC_STATE_TRASHED;
    rec.trashedAt = nowMs;
    rec.origDossierId = rec.dossierId === undefined ? null : rec.dossierId;
    // 从卷宗里移出（active 列表与卷宗内页都不再显示）；恢复时回原卷宗
    rec.dossierId = null;
    return true;
  }
  return false;
}

/** 从回收站恢复；返回是否真的改了。 */
export function restoreRecord(index: DocIndexRecord[], id: string): boolean {
  for (let i = 0; i < index.length; i++) {
    const rec: DocIndexRecord = index[i];
    if (rec.id !== id) {
      continue;
    }
    if (isActive(rec)) {
      return false;
    }
    rec.state = DOC_STATE_ACTIVE;
    rec.trashedAt = undefined;
    rec.dossierId = rec.origDossierId === undefined ? null : rec.origDossierId;
    rec.origDossierId = undefined;
    return true;
  }
  return false;
}

/** 改名（标题去掉首尾空白；空标题不改）。返回是否改了。 */
export function renameRecord(index: DocIndexRecord[], id: string, title: string): boolean {
  const next: string = title.trim();
  if (next.length === 0) {
    return false;
  }
  for (let i = 0; i < index.length; i++) {
    if (index[i].id === id) {
      index[i].title = next;
      return true;
    }
  }
  return false;
}

/** active 列表（保持索引原顺序；DocStore.list() 第 6 批才切到这里）。 */
export function activeRecords(index: DocIndexRecord[]): DocIndexRecord[] {
  const out: DocIndexRecord[] = [];
  for (let i = 0; i < index.length; i++) {
    if (isActive(index[i])) {
      out.push(index[i]);
    }
  }
  return out;
}

/** 回收站列表。 */
export function trashedRecords(index: DocIndexRecord[]): DocIndexRecord[] {
  const out: DocIndexRecord[] = [];
  for (let i = 0; i < index.length; i++) {
    if (isTrashed(index[i])) {
      out.push(index[i]);
    }
  }
  return out;
}

/** 正文摘要：第一行含 query 的文本，压到 48 字符。 */
function snippetOf(content: string, query: string): string {
  const lines: string[] = content.split('\n');
  const q: string = query.toLowerCase();
  for (let i = 0; i < lines.length; i++) {
    const line: string = lines[i].trim();
    if (line.length > 0 && line.toLowerCase().indexOf(q) >= 0) {
      return line.length > 48 ? line.substring(0, 48) : line;
    }
  }
  const first: string = content.trim();
  return first.length > 48 ? first.substring(0, 48) : first;
}

/**
 * 搜索：标题优先；标题不中再扫正文（contentOf 由调用方注入：默认读 .txt，
 * 第 6 批可改逐文档 load()）。结果按 updatedAt 倒序，最多 limit 条。
 */
export function searchRecords(index: DocIndexRecord[], query: string, opts: DocSearchOptions,
  contentOf: (id: string) => string): DocSearchHit[] {
  const q: string = query.trim().toLowerCase();
  if (q.length === 0) {
    return [];
  }
  const includeTrashed: boolean = opts.includeTrashed === true;
  const limit: number = opts.limit === undefined || opts.limit <= 0 ? 20 : opts.limit;
  const hits: DocSearchHit[] = [];
  for (let i = 0; i < index.length; i++) {
    const rec: DocIndexRecord = index[i];
    if (!includeTrashed && !isActive(rec)) {
      continue;
    }
    if (rec.title.toLowerCase().indexOf(q) >= 0) {
      hits.push({ id: rec.id, title: rec.title, matchedIn: 'title', snippet: '',
        updatedAt: rec.updatedAt });
      continue;
    }
    const content: string = contentOf(rec.id);
    if (content.length > 0 && content.toLowerCase().indexOf(q) >= 0) {
      hits.push({ id: rec.id, title: rec.title, matchedIn: 'content',
        snippet: snippetOf(content, q), updatedAt: rec.updatedAt });
    }
  }
  hits.sort((a: DocSearchHit, b: DocSearchHit) => b.updatedAt - a.updatedAt);
  return hits.length > limit ? hits.slice(0, limit) : hits;
}

/** 回收站保留期（天）：缺省 30（总纲第 6 批）。 */
export const TRASH_RETENTION_DAYS: number = 30;

/**
 * 过期回收站记录 id：trashedAt 超过 retentionDays；trashedAt 缺失按 updatedAt 兜底
 * （旧索引/半途崩溃不误删刚入站的文件）。
 */
export function expiredRecords(index: DocIndexRecord[], nowMs: number,
  retentionDays: number = TRASH_RETENTION_DAYS): string[] {
  const out: string[] = [];
  const days: number = retentionDays > 0 ? retentionDays : TRASH_RETENTION_DAYS;
  const cutoff: number = nowMs - days * 86400000;
  for (let i = 0; i < index.length; i++) {
    const rec: DocIndexRecord = index[i];
    if (!isTrashed(rec)) {
      continue;
    }
    const at: number = rec.trashedAt === undefined ? rec.updatedAt : rec.trashedAt;
    if (isFinite(at) && at < cutoff) {
      out.push(rec.id);
    }
  }
  return out;
}
