/**
 * 回车 · 纸面行数据源（LazyForEach 的 IDataSource 实现）
 *
 * 设计要点（调研报告 §2）：
 * - `getData` 只做一次数组下标读取，绝不做耗时计算——LazyForEach 在滚动时会高频调用它；
 * - 行数据是"值对象"（PaperRow 只有 text / ribbon / active 三个可变字段），
 *   增量通知按行比对得出，绝不整表 onDataReloaded：一次落字只让 1～2 行变化；
 * - 数据源同时持有"上一帧快照"，组件把新的 rows 交给 sync() 就能拿到最小通知集合。
 */

import { PaperRow } from '../../ui/PaperSheet';

/** 一行是否发生了可见变化（文本 / 墨色 / 光标是否在本行）。 */
function rowChanged(prev: PaperRow, next: PaperRow): boolean {
  return prev.text !== next.text || prev.ribbon !== next.ribbon || prev.active !== next.active;
}

/**
 * 纸面行数据源。
 *
 * 只持有"当前行数组"一份引用：PaperRow 由调用方在每次 sync() 时按行重建，
 * 组件侧不再复制，避免大文档下的额外内存与比较开销。
 */
export class PaperDataSource implements IDataSource {
  private rows: PaperRow[] = [];
  private listeners: DataChangeListener[] = [];

  /** 行数（LazyForEach 用它决定还要不要继续取数据）。 */
  totalCount(): number {
    return this.rows.length;
  }

  /** 取第 index 行；getData 内不做任何计算或匹配，保证滚动帧率。 */
  getData(index: number): PaperRow {
    return this.rows[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const at: number = this.listeners.indexOf(listener);
    if (at >= 0) {
      this.listeners.splice(at, 1);
    }
  }

  /**
   * 用最新的行数组做增量刷新。
   *
   * 逐行比对 text / ribbon / active，只对真正变化的行发通知：
   * - 行数不变：只 notifyDataChange 变化行（一次落字通常只有 1 行）；
   * - 行数变多：先补变化行，再从末尾 notifyDataAdd（回车换行走这一路）；
   * - 行数变少：先补变化行，再从末尾 notifyDataDelete（行首退格并行走这一路）。
   *
   * 只有调用方明确要求整表重建（换纸 / 打开另一篇文档）才走 reload()。
   */
  sync(next: PaperRow[]): void {
    const prev: PaperRow[] = this.rows;
    this.rows = next;

    const prevLen: number = prev.length;
    const nextLen: number = next.length;
    const common: number = prevLen < nextLen ? prevLen : nextLen;

    for (let i: number = 0; i < common; i++) {
      if (rowChanged(prev[i], next[i])) {
        this.notifyChange(i);
      }
    }
    if (nextLen > prevLen) {
      for (let i: number = prevLen; i < nextLen; i++) {
        this.notifyAdd(i);
      }
    } else if (nextLen < prevLen) {
      for (let i: number = prevLen - 1; i >= nextLen; i--) {
        this.notifyDelete(i);
      }
    }
  }

  /** 整表重建（换纸 / 打开文档等结构性变化时由组件显式调用）。 */
  reload(next: PaperRow[]): void {
    this.rows = next;
    this.notifyReload();
  }

  private notifyChange(index: number): void {
    for (let i: number = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataChange(index);
    }
  }

  private notifyAdd(index: number): void {
    for (let i: number = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataAdd(index);
    }
  }

  private notifyDelete(index: number): void {
    for (let i: number = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataDelete(index);
    }
  }

  private notifyReload(): void {
    for (let i: number = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataReloaded();
    }
  }
}
