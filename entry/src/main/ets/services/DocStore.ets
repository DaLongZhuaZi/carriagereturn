/**
 * 回车 · 文档本地存储（阶段1 实现）
 *
 * 只做 I/O：JSON（文本行 + 元数据）与纯文本 .txt 成对保存、成对删除，
 * 全部落在应用沙箱 context.filesDir，不联网、不上传、零遥测。
 * 文档模型本身在 model/DocModelCore.ets（纯逻辑，可单测）。
 *
 * 技术架构设计 §2：文档存两份 —— JSON（文本 + 机器/纸张/色带/字体/时间戳）
 * 与纯文本（UTF-8，可再编辑）；绝不学 Rebi 存图片。
 */

import { fileIo as fs } from '@kit.CoreFileKit';
import { sheetSeparatorText } from '../model/ExportCore';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DocData, DocLine, DocSummary, MachineKind, PaperKind } from '../model/DocModel';
import { DEFAULT_MACHINE, DEFAULT_PAPER } from '../model/MachineCatalog';
import {
  DocIndexRecord, DocSearchHit, DocSearchOptions, activeRecords, expiredRecords, renameRecord,
  restoreRecord, searchRecords, trashRecord, trashedRecords,
} from '../model/DocStoreStateCore';

const DOMAIN: number = 0x0000;
const TAG: string = 'DocStore';

const DOC_DIR: string = 'documents';
const TEXT_DIR: string = 'documents-text';
const INDEX_FILE: string = 'documents-index.json';

/** 一份文档的落盘索引项（状态字段见 model/DocStoreStateCore）。 */
export interface DocIndexEntry extends DocIndexRecord {
}

interface DocIndex {
  version: number;
  entries: DocIndexEntry[];
}

/**
 * 文档本地存储。
 * 生命周期：Ability.onCreate 里 init(context.filesDir) 一次；页面与服务共用单例。
 */
export class DocStore {
  private baseDir: string = '';
  private initialized: boolean = false;

  /** 必须在 Ability 里先调一次（filesDir 就绪后）。 */
  init(filesDir: string): void {
    this.baseDir = filesDir;
    this.initialized = true;
  }

  isReady(): boolean {
    return this.initialized;
  }

  private docPath(id: string): string {
    return this.baseDir + '/' + DOC_DIR + '/' + id + '.json';
  }

  private textPath(id: string): string {
    return this.baseDir + '/' + TEXT_DIR + '/' + id + '.txt';
  }

  private indexPath(): string {
    return this.baseDir + '/' + INDEX_FILE;
  }

  private ensureDirs(): void {
    this.mkdirIfAbsent(this.baseDir + '/' + DOC_DIR);
    this.mkdirIfAbsent(this.baseDir + '/' + TEXT_DIR);
  }

  private mkdirIfAbsent(path: string): void {
    try {
      if (!fs.accessSync(path)) {
        fs.mkdirSync(path);
      }
    } catch (e) {
      // 已存在或并发创建：忽略
    }
  }

  /** 保存一份文档；id 为空则新建。返回实际使用的 id。 */
  save(id: string, data: DocData, fallbackTitle: string): string {
    if (!this.initialized) {
      return id;
    }
    this.ensureDirs();
    // P2-10：新 id 加随机后缀，避免同一毫秒内连续新建撞号（同 DossierStore 的做法）
    const docId: string = id.length > 0 ? id
      : 'doc-' + Date.now().toString() + '-' + Math.floor(Math.random() * 100000).toString();
    this.writeText(this.docPath(docId), JSON.stringify(data));

    // 纯文本与 JSON 成对保存（内容可再编辑，绝不只存图片）。
    this.writeText(this.textPath(docId), this.plainTextOf(data));

    this.upsertIndex(docId, this.titleOf(data, fallbackTitle), data.meta.createdAt, data.meta.updatedAt,
      data.dossierId === undefined ? null : data.dossierId,
      data.meta.machine as string, data.meta.paper as string);
    return docId;
  }

  /** 读取一份文档；不存在或损坏返回 null（不抛，避免打断主屏）。 */
  load(id: string): DocData | null {
    if (!this.initialized) {
      return null;
    }
    try {
      const text: string = this.readText(this.docPath(id));
      if (text.length === 0) {
        return null;
      }
      const parsed: DocData = JSON.parse(text) as DocData;
      if (parsed.lines === undefined || parsed.lines.length === 0) {
        return null;
      }
      return parsed;
    } catch (e) {
      return null;
    }
  }

  /**
   * 第 6 批 F10：删除＝**移入回收站**（语义已从硬删翻转；见 docs/designs/6-…§1.3）。
   * 彻底删除只走 removePermanently（回收站「彻底删除」/直接删除档/删卷宗 purge）。
   */
  remove(id: string): boolean {
    return this.trash(id, Date.now());
  }

  /** 旧硬删语义（第 6 批改名保留）：JSON 与 .txt 成对删除 + 从索引移除。 */
  removePermanently(id: string): boolean {
    if (!this.initialized) {
      return false;
    }
    this.unlinkIfPresent(this.docPath(id));
    this.unlinkIfPresent(this.textPath(id));
    this.removeFromIndex(id);
    return true;
  }

  /** 第 6 批 F10：30 天过期清理（EntryAbility init 后调一次；纯逻辑在 DocStoreStateCore）。 */
  housekeeping(nowMs: number, retentionDays: number = 30): number {
    if (!this.initialized) {
      return 0;
    }
    const index: DocIndex = this.readIndex();
    const expired: string[] = expiredRecords(index.entries, nowMs, retentionDays);
    for (let i = 0; i < expired.length; i++) {
      this.removePermanently(expired[i]);
    }
    if (expired.length > 0) {
      hilog.info(DOMAIN, TAG, 'housekeeping purged=%{public}s retention=%{public}s',
        expired.length.toString(), retentionDays.toString());
    }
    return expired.length;
  }

  // ---- 文档状态模型接口（active／trashed）----
  // 第 0 批只落模型与签名；**第 6 批 F10 已翻转**：remove()＝trash、list() 只返回 active、
  // 新增 removePermanently/housekeeping。trash／restore／rename／search 由 F10 UI 消费。

  /** 移入回收站；返回 false＝不存在或本来就在回收站。 */
  trash(id: string, nowMs: number): boolean {
    if (!this.initialized) {
      return false;
    }
    const index: DocIndex = this.readIndex();
    const changed: boolean = trashRecord(index.entries, id, nowMs);
    if (changed) {
      this.writeIndex(index);
    }
    return changed;
  }

  /** 从回收站恢复（回原卷宗）；返回 false＝不存在或本来就是 active。 */
  restore(id: string): boolean {
    if (!this.initialized) {
      return false;
    }
    const index: DocIndex = this.readIndex();
    const changed: boolean = restoreRecord(index.entries, id);
    if (changed) {
      this.writeIndex(index);
    }
    return changed;
  }

  /** 重命名（空标题不改）；返回是否改了。 */
  rename(id: string, title: string): boolean {
    if (!this.initialized) {
      return false;
    }
    const index: DocIndex = this.readIndex();
    const changed: boolean = renameRecord(index.entries, id, title);
    if (changed) {
      this.writeIndex(index);
    }
    return changed;
  }

  /** 回收站列表（第 6 批回收站 UI 消费；本批只提供数据）。 */
  listTrashed(): DocSummary[] {
    if (!this.initialized) {
      return [];
    }
    const index: DocIndex = this.readIndex();
    const records: DocIndexRecord[] = trashedRecords(index.entries);
    const out: DocSummary[] = [];
    for (const entry of records) {
      out.push({
        id: entry.id,
        title: entry.title,
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
        machine: (entry.machine === undefined ? DEFAULT_MACHINE as string : entry.machine) as MachineKind,
        paper: (entry.paper === undefined ? DEFAULT_PAPER as string : entry.paper) as PaperKind,
        dossierId: entry.dossierId === undefined ? null : entry.dossierId,
        charCount: this.countCharsFromJson(entry.id),
        preview: this.previewFromJson(entry.id),
        trashedAt: entry.trashedAt === undefined ? entry.updatedAt : entry.trashedAt,
        origDossierId: entry.origDossierId === undefined ? null : entry.origDossierId,
      });
    }
    return out;
  }

  /**
   * 搜索（标题＋正文；默认只搜 active）。
   * 正文走 .txt（与导出同源）；第 6 批若改为逐文档 load() 全文扫，只换这一处实现。
   */
  search(query: string, opts: DocSearchOptions): DocSearchHit[] {
    if (!this.initialized) {
      return [];
    }
    const index: DocIndex = this.readIndex();
    return searchRecords(index.entries, query, opts,
      (id: string): string => this.readPlainText(id));
  }

  /** active 记录数（第 6 批 list() 切换前的过渡查询用；不改既有 list()). */
  activeCount(): number {
    if (!this.initialized) {
      return 0;
    }
    return activeRecords(this.readIndex().entries).length;
  }

  /** 文档库列表（按更新时间倒序）。 */
  /** 第 13 批 ⑥：按卷宗取摘要（顺序与 list() 一致＝updatedAt 倒序；空串 dossierId 返回未归档）。 */
  listByDossier(dossierId: string): DocSummary[] {
    const all: DocSummary[] = this.list();
    const out: DocSummary[] = [];
    for (const d of all) {
      const did: string = d.dossierId === undefined || d.dossierId === null ? '' : d.dossierId;
      if (did === dossierId) {
        out.push(d);
      }
    }
    return out;
  }

  list(): DocSummary[] {
    if (!this.initialized) {
      return [];
    }
    const index: DocIndex = this.readIndex();
    // 第 6 批 F10：list() 默认只返回 active（trashed 走 listTrashed）
    const entries: DocIndexRecord[] = activeRecords(index.entries);
    const out: DocSummary[] = [];
    for (const entry of entries) {
      out.push({
        id: entry.id,
        title: entry.title,
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
        machine: (entry.machine === undefined ? DEFAULT_MACHINE as string : entry.machine) as MachineKind,
        paper: (entry.paper === undefined ? DEFAULT_PAPER as string : entry.paper) as PaperKind,
        dossierId: entry.dossierId === undefined ? null : entry.dossierId,
        charCount: this.countCharsFromJson(entry.id),
        preview: this.previewFromJson(entry.id),
      });
    }
    return out;
  }

  /**
   * 第 0 批：active-only 列表（第 6 批 list() 翻转前的过渡实现；StatsService 用它，
   * 保证回收站文档不进总字数/连续天数）。list() 本批语义不动。
   */
  listActive(): DocSummary[] {
    if (!this.initialized) {
      return [];
    }
    const index: DocIndex = this.readIndex();
    const entries: DocIndexRecord[] = activeRecords(index.entries);
    const out: DocSummary[] = [];
    for (const entry of entries) {
      out.push({
        id: entry.id,
        title: entry.title,
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
        machine: (entry.machine === undefined ? DEFAULT_MACHINE as string : entry.machine) as MachineKind,
        paper: (entry.paper === undefined ? DEFAULT_PAPER as string : entry.paper) as PaperKind,
        dossierId: entry.dossierId === undefined ? null : entry.dossierId,
        charCount: this.countCharsFromJson(entry.id),
        preview: this.previewFromJson(entry.id),
      });
    }
    return out;
  }

  /**
   * P1-8：字数**从 JSON 的 lines 现算**，不读 txt。
   * 此前读 txt 会与 JSON 脱节（txt 可能未被写/被覆盖），导致卡片字数停在旧值。
   */
  /** P2-9：缩略图正文＝前 3 行非空文本，随 list() 一次算好。 */
  private previewFromJson(id: string): string {
    try {
      const text: string = this.readText(this.docPath(id));
      if (text.length === 0) {
        return '';
      }
      const data: DocData = JSON.parse(text) as DocData;
      if (data.lines === undefined || data.lines === null) {
        return '';
      }
      const out: string[] = [];
      for (let i = 0; i < data.lines.length && out.length < 3; i++) {
        if (data.lines[i].text.length > 0) {
          out.push(data.lines[i].text);
        }
      }
      return out.join('\n');
    } catch (e) {
      return '';
    }
  }

  private countCharsFromJson(id: string): number {
    try {
      const text: string = this.readText(this.docPath(id));
      if (text.length === 0) {
        return 0;
      }
      const data: DocData = JSON.parse(text) as DocData;
      if (data.lines === undefined || data.lines === null) {
        return 0;
      }
      let n: number = 0;
      for (let i = 0; i < data.lines.length; i++) {
        n += data.lines[i].text.replace(/\s/g, '').length;
      }
      return n;
    } catch (e) {
      return 0;
    }
  }

  /** 暴露给导出（阶段3）：读某文档的纯文本。 */
  readPlainText(id: string): string {
    if (!this.initialized) {
      return '';
    }
    try {
      return this.readText(this.textPath(id));
    } catch (e) {
      return '';
    }
  }

  private plainTextOf(data: DocData): string {
    // 第 13 批 ⑥：先拼归档纸（每纸后加分隔行），再拼当前纸——.txt 即含整篇，搜索自动覆盖旧纸
    const parts: string[] = [];
    const sheets: DocLine[][] = data.sheets === undefined ? [] : data.sheets;
    const total: number = sheets.length + 1;
    for (let i = 0; i < sheets.length; i++) {
      for (const line of sheets[i]) {
        parts.push(line.text);
      }
      parts.push(sheetSeparatorText(i + 1, total));
    }
    for (const line of data.lines) {
      parts.push(line.text);
    }
    return parts.join('\n') + '\n';
  }

  private titleOf(data: DocData, fallback: string): string {
    for (const line of data.lines) {
      const t: string = line.text.trim();
      if (t.length > 0) {
        return t.length > 24 ? t.substring(0, 24) : t;
      }
    }
    return fallback;
  }

  /** 写整个文本文件。异常就地处理（文件 I/O 全部可能抛），失败只记日志不向上抛。 */
  private writeText(path: string, content: string): void {
    let file: fs.File | null = null;
    try {
      file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, content);
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'writeText failed: %{public}s', JSON.stringify(err));
    } finally {
      this.closeQuietly(file);
    }
  }

  /** 读整个文本文件；任何异常（不存在 / 无权限 / 读失败）返回空串。 */
  private readText(path: string): string {
    let file: fs.File | null = null;
    try {
      const stat: fs.Stat = fs.statSync(path);
      if (stat.size <= 0) {
        return '';
      }
      file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const buf: ArrayBuffer = new ArrayBuffer(stat.size);
      const readLen: number = fs.readSync(file.fd, buf);
      return this.decodeUtf8(buf, readLen);
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.warn(DOMAIN, TAG, 'readText failed: %{public}s', JSON.stringify(err));
      return '';
    } finally {
      this.closeQuietly(file);
    }
  }

  /** 关闭文件句柄；关闭本身失败不再抛（避免覆盖上面的真实错误）。 */
  private closeQuietly(file: fs.File | null): void {
    if (file === null) {
      return;
    }
    try {
      fs.closeSync(file);
    } catch (e) {
      // 句柄已关闭或进程退出中：忽略
    }
  }

  private unlinkIfPresent(path: string): void {
    try {
      fs.unlinkSync(path);
    } catch (e) {
      // 文件已不存在视为成功
    }
  }

  private readIndex(): DocIndex {
    try {
      const text: string = this.readText(this.indexPath());
      if (text.length === 0) {
        return { version: 1, entries: [] };
      }
      const parsed: DocIndex = JSON.parse(text) as DocIndex;
      if (parsed.entries === undefined) {
        return { version: 1, entries: [] };
      }
      return parsed;
    } catch (e) {
      return { version: 1, entries: [] };
    }
  }

  private upsertIndex(id: string, title: string, createdAt: number, updatedAt: number,
    dossierId: string | null, machine: string, paper: string): void {
    const index: DocIndex = this.readIndex();
    let found: boolean = false;
    for (const entry of index.entries) {
      if (entry.id === id) {
        entry.title = title;
        entry.updatedAt = updatedAt;
        entry.dossierId = dossierId;
        entry.machine = machine;
        entry.paper = paper;
        found = true;
        break;
      }
    }
    if (!found) {
      index.entries.push({ id: id, title: title, createdAt: createdAt, updatedAt: updatedAt,
        dossierId: dossierId, machine: machine, paper: paper });
    }
    index.entries.sort((a: DocIndexEntry, b: DocIndexEntry) => b.updatedAt - a.updatedAt);
    this.writeIndex(index);
  }

  private removeFromIndex(id: string): void {
    const index: DocIndex = this.readIndex();
    const kept: DocIndexEntry[] = [];
    for (const entry of index.entries) {
      if (entry.id !== id) {
        kept.push(entry);
      }
    }
    index.entries = kept;
    this.writeIndex(index);
  }

  private writeIndex(index: DocIndex): void {
    try {
      this.writeText(this.indexPath(), JSON.stringify(index));
    } catch (e) {
      // 索引失败不阻断文档保存
    }
  }

  /** UTF-8 解码（含 4 字节码元），避免依赖 util.TextDecoder 的平台差异。 */
  private decodeUtf8(buf: ArrayBuffer, length: number): string {
    const bytes: Uint8Array = new Uint8Array(buf);
    const end: number = Math.min(length, bytes.length);
    let out: string = '';
    let i: number = 0;
    while (i < end) {
      const c: number = bytes[i];
      if (c < 0x80) {
        out += String.fromCharCode(c);
        i += 1;
      } else if (c < 0xE0 && i + 1 < end) {
        out += String.fromCharCode(((c & 0x1F) << 6) | (bytes[i + 1] & 0x3F));
        i += 2;
      } else if (c < 0xF0 && i + 2 < end) {
        out += String.fromCharCode(((c & 0x0F) << 12) | ((bytes[i + 1] & 0x3F) << 6) | (bytes[i + 2] & 0x3F));
        i += 3;
      } else if (i + 3 < end) {
        const cp: number = ((c & 0x07) << 18) | ((bytes[i + 1] & 0x3F) << 12) | ((bytes[i + 2] & 0x3F) << 6) | (bytes[i + 3] & 0x3F);
        out += String.fromCodePoint(cp);
        i += 4;
      } else {
        i += 1;
      }
    }
    return out;
  }
}

/** 全局单例：Ability 里 init(filesDir) 一次，页面与服务共用。 */
export const docStore: DocStore = new DocStore();
