/**
 * 回车 · 统计派生层（第 0 批）。
 *
 * 单一派生层：总字数／连续天数各**一个**实现（都走 model/StatsCore 的纯函数），
 * F5／F11／F14 只消费本服务的结果，不许在 UI 里再自算一份。
 *
 * 数据来源（总纲"统计口径"）：DocStore 派生（文档 charCount／updatedAt）＋ prefs 计数器
 * （非文档事件：导出、换字体/色带、半开折叠打字）。**不建追加式事件账本**。
 *
 * 写入时机（第 4 批）：落字热路径只 recordChar() 内存 +1（不写盘）；离页/切页/导出前/退出时
 * flushPending() 批量写 `stats.day.*`。其它事件计数仍在保存／导出时更新。
 */

import { appPreferences, PrefKeys } from './AppPreferences';
import { docStore } from './DocStore';
import { DocSummary } from '../model/DocModel';
import { consecutiveDays as statsConsecutiveDays, dayKey, progressRatio, dayIndex, sumCounts,
  clampDailyGoal, mergeDailyChars, paperKindsMerge } from '../model/StatsCore';

/**
 * 纸张种类集合（逗号分隔）：applyPaper 成功时由 Index 调 recordPaperKind 写入。
 * 设计 §1.8 的键名 `stats.paper.kinds`；未进 PrefRegistry（本文件不能改 AppPreferences，
 * 留给第 5 批登记），读写都走本常量。
 */
/** 统计事件名（总纲第 0 批定的枚举；字符串常量，避免 Node 单测受 TS enum 限制）。 */
export class StatsEvents {
  static readonly DOC_SAVED: string = 'doc_saved';
  static readonly DOC_EXPORTED: string = 'doc_exported';
  static readonly FONT_CHANGED: string = 'font_changed';
  static readonly RIBBON_CHANGED: string = 'ribbon_changed';
  static readonly PAPER_CHANGED: string = 'paper_changed';
  static readonly FOLD_TYPED: string = 'fold_typed';
  static all(): string[] {
    return [
      StatsEvents.DOC_SAVED, StatsEvents.DOC_EXPORTED, StatsEvents.FONT_CHANGED,
      StatsEvents.RIBBON_CHANGED, StatsEvents.PAPER_CHANGED, StatsEvents.FOLD_TYPED,
    ];
  }
}

export const DEFAULT_DAILY_GOAL: number = 500;

/** 统计派生门面（单例）。 */
export class StatsService {
  /**
   * 落字热路径的内存增量（设计 §1.3 B-2）：recordChar 每次 +1，只进内存不写盘；
   * flushPending 在离页/切页/导出前/退出时批量写一次。静态内存＝跨实例共享、进程内有效。
   */
  private static pendingBuf: number = 0;
  /** pending 所属自然日；跨日后 recordChar 先 flush 旧日，避免把昨天的字记到今天。 */
  private static pendingDayKey: string = '';
  /** 本地自然日的时区偏移（分钟）：Asia/Hong_Kong = 480。 */
  tzOffsetMinutes(): number {
    return -new Date().getTimezoneOffset();
  }

  /** 今天的时间戳（测试注入缝：判定逻辑在 StatsCore 里以参数接收，不在那里读时钟）。 */
  nowMs(): number {
    return Date.now();
  }

  // ---- 单一派生：总字数／连续天数（各一个实现）----

  /** 总字数＝全部 active 文档 charCount 之和（回收站不计）。 */
  totalWords(): number {
    const list: DocSummary[] = docStore.listActive();
    const counts: number[] = [];
    for (let i = 0; i < list.length; i++) {
      const c: number | undefined = list[i].charCount;
      counts.push(c === undefined ? 0 : c);
    }
    return sumCounts(counts);
  }

  /** 连续天数＝active 文档 updatedAt 去重自然日、以今天为终点连续算（今天无落字＝0）。 */
  consecutiveDays(): number {
    const list: DocSummary[] = docStore.listActive();
    const stamps: number[] = [];
    for (let i = 0; i < list.length; i++) {
      stamps.push(list[i].updatedAt);
    }
    return statsConsecutiveDays(stamps, this.nowMs(), this.tzOffsetMinutes());
  }

  /**
   * 今天已落字数＝已落盘日字数（跨日归零）＋内存 pending。
   * 读时不写盘；跨日判定由 mergeDailyChars 统一（纯函数单测）。
   */
  todayChars(): number {
    const key: string = dayKey(this.nowMs(), this.tzOffsetMinutes());
    const storedKey: string = appPreferences.getString(PrefKeys.STATS_DAY_KEY, '');
    const stored: number = appPreferences.getNumber(PrefKeys.STATS_DAY_CHARS, 0);
    const base: number = mergeDailyChars(storedKey, stored, key, 0);
    const pending: number = StatsService.pendingDayKey === key ? StatsService.pendingBuf : 0;
    return base + pending;
  }

  /** 落字成功一次 +1（只进内存，不写盘；删除字不扣减）。 */
  recordChar(): void {
    const key: string = dayKey(this.nowMs(), this.tzOffsetMinutes());
    if (StatsService.pendingDayKey.length > 0 && StatsService.pendingDayKey !== key) {
      this.flushPending();
    }
    StatsService.pendingDayKey = key;
    StatsService.pendingBuf = StatsService.pendingBuf + 1;
  }

  /** 尚未落盘的落字数。 */
  pendingChars(): number {
    return StatsService.pendingBuf;
  }

  /**
   * 把内存 pending 合并写 `stats.day.*` 后清零（离页/切页/导出前/退出时调）。
   * 跨日按 mergeDailyChars 归零，避免把昨天的 pending 记到昨天。
   */
  flushPending(): void {
    const pending: number = StatsService.pendingBuf;
    if (pending <= 0) {
      return;
    }
    const now: number = this.nowMs();
    const today: string = dayKey(now, this.tzOffsetMinutes());
    // 写 pending 所属的那一天（跨日时 pendingDayKey 是旧日，不能记到今天）
    const key: string = StatsService.pendingDayKey.length > 0 ? StatsService.pendingDayKey : today;
    const storedKey: string = appPreferences.getString(PrefKeys.STATS_DAY_KEY, '');
    const stored: number = appPreferences.getNumber(PrefKeys.STATS_DAY_CHARS, 0);
    const next: number = mergeDailyChars(storedKey, stored, key, pending);
    appPreferences.setString(PrefKeys.STATS_DAY_KEY, key);
    appPreferences.setNumber(PrefKeys.STATS_DAY_CHARS, next);
    StatsService.pendingBuf = 0;
    StatsService.pendingDayKey = '';
  }

  /** 记今天落字数（保存事件时批量调用；非热路径）。 */
  recordChars(count: number): void {
    if (!isFinite(count) || count <= 0) {
      return;
    }
    const now: number = this.nowMs();
    const key: string = dayKey(now, this.tzOffsetMinutes());
    const storedKey: string = appPreferences.getString(PrefKeys.STATS_DAY_KEY, '');
    const stored: number = appPreferences.getNumber(PrefKeys.STATS_DAY_CHARS, 0);
    appPreferences.setString(PrefKeys.STATS_DAY_KEY, key);
    appPreferences.setNumber(PrefKeys.STATS_DAY_CHARS, mergeDailyChars(storedKey, stored, key, count));
  }

  // ---- 第 4 批 F14：纸张种类（数据源 prefs `stats.paper.kinds`）----

  /** 用过多少种纸（`applyPaper` 成功时 recordPaperKind 写入；空集＝0）。 */
  paperKindsUsed(): number {
    const raw: string = appPreferences.getString(PrefKeys.STATS_PAPER_KINDS, '');
    if (raw.length === 0) {
      return 0;
    }
    const parts: string[] = raw.split(',');
    let n: number = 0;
    for (let i = 0; i < parts.length; i++) {
      if (parts[i].trim().length > 0) {
        n = n + 1;
      }
    }
    return n;
  }

  /** 记一种用过的纸（逗号集合去重＋稳定排序；空 kind 不写）。 */
  recordPaperKind(kind: string): void {
    const k: string = kind.trim();
    if (k.length === 0) {
      return;
    }
    const prev: string = appPreferences.getString(PrefKeys.STATS_PAPER_KINDS, '');
    const merged: string = paperKindsMerge(prev, k);
    if (merged !== prev) {
      appPreferences.setString(PrefKeys.STATS_PAPER_KINDS, merged);
    }
  }

  /** 每日目标（默认 500；clamp 100–2000，非法值回落缺省）。 */
  dailyGoal(): number {
    const g: number = appPreferences.getNumber(PrefKeys.STATS_DAILY_GOAL, DEFAULT_DAILY_GOAL);
    return clampDailyGoal(g, DEFAULT_DAILY_GOAL);
  }

  setDailyGoal(goal: number): void {
    if (isFinite(goal) && goal > 0) {
      appPreferences.setNumber(PrefKeys.STATS_DAILY_GOAL, clampDailyGoal(Math.floor(goal), DEFAULT_DAILY_GOAL));
    }
  }

  /** 今日进度 0..1（clamp）。 */
  goalProgress(): number {
    return progressRatio(this.todayChars(), this.dailyGoal());
  }

  /** 今日是否达成目标。 */
  goalReached(): boolean {
    return this.goalProgress() >= 1;
  }

  // ---- 事件计数（非文档事件；标量，无增长问题）----

  recordEvent(event: string): void {
    if (StatsEvents.all().indexOf(event) < 0) {
      return;
    }
    const key: string = PrefKeys.statsEvent(event);
    const n: number = appPreferences.getNumber(key, 0);
    appPreferences.setNumber(key, (isFinite(n) ? n : 0) + 1);
  }

  eventCount(event: string): number {
    const n: number = appPreferences.getNumber(PrefKeys.statsEvent(event), 0);
    return isFinite(n) && n > 0 ? Math.floor(n) : 0;
  }

  /** 某天字数（第 6 批成就判定与审计用；今天以外的历史不保留逐日明细，返回 -1）。 */
  charsOnDay(dayIdx: number): number {
    const todayIdx: number = dayIndex(this.nowMs(), this.tzOffsetMinutes());
    if (dayIdx === todayIdx) {
      return this.todayChars();
    }
    return -1;
  }
}

export const statsService: StatsService = new StatsService();