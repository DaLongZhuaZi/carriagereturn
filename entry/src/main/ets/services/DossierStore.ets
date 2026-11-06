/**
 * 回车 · 卷宗本地存储（§5 卷宗系统 · 数据层）
 *
 * 与文档索引分开存、分开删：dossiers-index.json 只放卷宗元数据；
 * 每张纸属于哪个卷宗记在文档 JSON 的 dossierId 上（null = 未归档）。
 * 全部落在应用沙箱 context.filesDir，不联网、不上传、零遥测。
 */

import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';

const DOMAIN: number = 0x0000;
const TAG: string = 'DossierStore';

const INDEX_FILE: string = 'dossiers-index.json';
const INDEX_VERSION: number = 1;

/** 四种封面（对应 rawfile/dossiers/dossier-<style>.jpg）。 */
export type CoverStyle = 'kraft' | 'leather' | 'manila' | 'cloth';

export interface Dossier {
  id: string;
  name: string;
  coverStyle: CoverStyle;
  createdAt: number;
  updatedAt: number;
}

interface DossierIndex {
  version: number;
  dossiers: Dossier[];
}

export class DossierStore {
  private baseDir: string = '';
  private initialized: boolean = false;

  init(filesDir: string): void {
    this.baseDir = filesDir;
    this.initialized = true;
  }

  isReady(): boolean {
    return this.initialized;
  }

  private indexPath(): string {
    return this.baseDir + '/' + INDEX_FILE;
  }

  /** 读索引；文件缺失或损坏一律返回空表（不抛、不带崩列表页）。 */
  private readIndex(): DossierIndex {
    if (!this.initialized) {
      return { version: INDEX_VERSION, dossiers: [] };
    }
    try {
      const exists: boolean = fs.accessSync(this.indexPath());
      if (!exists) {
        hilog.warn(DOMAIN, TAG, 'readIndex: index not exist path=%{public}s', this.indexPath());
        return { version: INDEX_VERSION, dossiers: [] };
      }
      const stat = fs.statSync(this.indexPath());
      const buf = new ArrayBuffer(stat.size);
      const file = fs.openSync(this.indexPath(), fs.OpenMode.READ_ONLY);
      fs.readSync(file.fd, buf);
      fs.closeSync(file);
      const text: string = new util.TextDecoder().decodeToString(new Uint8Array(buf));
      const parsed: DossierIndex = JSON.parse(text) as DossierIndex;
      if (parsed.dossiers === undefined || parsed.dossiers === null) {
        hilog.warn(DOMAIN, TAG, 'readIndex: dossiers missing in json');
        return { version: INDEX_VERSION, dossiers: [] };
      }
      hilog.info(DOMAIN, TAG, 'readIndex ok count=%{public}s', parsed.dossiers.length.toString());
      return parsed;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'readIndex failed: %{public}s', JSON.stringify(e));
      return { version: INDEX_VERSION, dossiers: [] };
    }
  }

  private writeIndex(index: DossierIndex): void {
    if (!this.initialized) {
      return;
    }
    try {
      const file: fs.File = fs.openSync(this.indexPath(),
        fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, JSON.stringify(index));
      fs.closeSync(file);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'writeIndex failed: %{public}s', JSON.stringify(e));
    }
  }

  /** 全部卷宗，按更新时间倒序。 */
  list(): Dossier[] {
    const index: DossierIndex = this.readIndex();
    index.dossiers.sort((a: Dossier, b: Dossier) => b.updatedAt - a.updatedAt);
    return index.dossiers;
  }

  find(id: string): Dossier | null {
    const all: Dossier[] = this.readIndex().dossiers;
    for (let i = 0; i < all.length; i++) {
      if (all[i].id === id) {
        return all[i];
      }
    }
    return null;
  }

  create(name: string, coverStyle: CoverStyle): Dossier {
    const now: number = Date.now();
    const d: Dossier = {
      id: 'd' + now.toString() + Math.floor(Math.random() * 1000).toString(),
      name: name,
      coverStyle: coverStyle,
      createdAt: now,
      updatedAt: now,
    };
    const index: DossierIndex = this.readIndex();
    index.dossiers.push(d);
    this.writeIndex(index);
    const back: Dossier[] = this.list();
    hilog.info(DOMAIN, TAG, 'dossier created id=%{public}s style=%{public}s listCount=%{public}s',
      d.id, coverStyle, back.length.toString());
    return d;
  }

  /** 纸增删改后刷新卷宗的更新时间（列表按它倒序）。 */
  touch(id: string): void {
    const index: DossierIndex = this.readIndex();
    for (let i = 0; i < index.dossiers.length; i++) {
      if (index.dossiers[i].id === id) {
        index.dossiers[i].updatedAt = Date.now();
        this.writeIndex(index);
        return;
      }
    }
  }

  rename(id: string, name: string): void {
    const index: DossierIndex = this.readIndex();
    for (let i = 0; i < index.dossiers.length; i++) {
      if (index.dossiers[i].id === id) {
        index.dossiers[i].name = name;
        index.dossiers[i].updatedAt = Date.now();
        this.writeIndex(index);
        return;
      }
    }
  }

  /**
   * 只删卷宗索引项，**不碰任何纸**。
   * 纸的去向由调用方先问用户：移出卷宗（dossierId 置 null）或连纸一起删；
   * 本方法不提供「默认连删」，避免误删。
   */
  removeIndexOnly(id: string): void {
    const index: DossierIndex = this.readIndex();
    const kept: Dossier[] = [];
    for (let i = 0; i < index.dossiers.length; i++) {
      if (index.dossiers[i].id !== id) {
        kept.push(index.dossiers[i]);
      }
    }
    index.dossiers = kept;
    this.writeIndex(index);
    hilog.info(DOMAIN, TAG, 'dossier index removed id=%{public}s', id);
  }
}

export const dossierStore: DossierStore = new DossierStore();
