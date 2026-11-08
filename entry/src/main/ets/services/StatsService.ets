/**
 * 回车 · 统计派生层（第 0 批）。
 *
 * 单一派生层：总字数／连续天数各**一个**实现（都走 model/StatsCore 的纯函数），
 * F5／F11／F14 只消费本服务的结果，不许在 UI 里再自算一份。
 *
 * 数据来源（总纲"统计口径"）：DocStore 派生（文档 charCount／updatedAt）＋ prefs 计数器
 * （非文档事件：导出、换字体/色带、半开折叠打字）。**不建追加式事件账本**。
 *
 * 写入时机：保存／导出等事件时更新，不走打字热路径（日汇总由调用方按保存事件批量记）。
 */

import { appPreferences, PrefKeys } from './AppPreferences';
import { docStore } from './DocStore';
import { DocSummary } from '../model/DocModel';
import { consecutiveDays as statsConsecutiveDays, dayKey, progressRatio, dayIndex, sumCounts } from '../model/StatsCore';

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

  /** 今天已落字数（prefs 日计数器；跨日自动归零，读时不写）。 */
  todayChars(): number {
    const key: string = dayKey(this.nowMs(), this.tzOffsetMinutes());
    const storedKey: string = appPreferences.getString(PrefKeys.STATS_DAY_KEY, '');
    if (storedKey !== key) {
      return 0;
    }
    const n: number = appPreferences.getNumber(PrefKeys.STATS_DAY_CHARS, 0);
    return isFinite(n) && n > 0 ? Math.floor(n) : 0;
  }

  /** 记今天落字数（保存事件时批量调用；非热路径）。 */
  recordChars(count: number): void {
    if (!isFinite(count) || count <= 0) {
      return;
    }
    const now: number = this.nowMs();
    const key: string = dayKey(now, this.tzOffsetMinutes());
    const storedKey: string = appPreferences.getString(PrefKeys.STATS_DAY_KEY, '');
    const base: number = storedKey === key
      ? appPreferences.getNumber(PrefKeys.STATS_DAY_CHARS, 0) : 0;
    appPreferences.setString(PrefKeys.STATS_DAY_KEY, key);
    appPreferences.setNumber(PrefKeys.STATS_DAY_CHARS, Math.floor(base + count));
  }

  /** 每日目标（默认 500；非法值回落缺省）。 */
  dailyGoal(): number {
    const g: number = appPreferences.getNumber(PrefKeys.STATS_DAILY_GOAL, DEFAULT_DAILY_GOAL);
    return isFinite(g) && g > 0 ? Math.floor(g) : DEFAULT_DAILY_GOAL;
  }

  setDailyGoal(goal: number): void {
    if (isFinite(goal) && goal > 0) {
      appPreferences.setNumber(PrefKeys.STATS_DAILY_GOAL, Math.floor(goal));
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