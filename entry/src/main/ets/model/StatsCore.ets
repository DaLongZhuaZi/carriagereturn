/**
 * 回车 · 统计派生纯函数（第 0 批）。
 *
 * 单一事实源：总字数与连续天数只在这里定义算法；StatsService 只做
 * "取 DocStore 数据 → 调本文件 → 返回结果"，不许在 UI 里再写第二套。
 *
 * 纯函数：不读 Date.now()、不读文件、不 import @kit（可 Node 单测）。
 * "天"的定义：自然日（按传入的时区偏移），有任意落字（≥1 字）即计一天。
 */

/** 一天的毫秒数。 */
export const DAY_MS: number = 86400000;

/** 两位补零。 */
function pad2(n: number): string {
  return n < 10 ? '0' + n.toString() : n.toString();
}

/**
 * 把时间戳换成"该时区下的自然日序号"（1970-01-01 起的天数，向下取整）。
 * tzOffsetMinutes 用"本地时间相对 UTC 的分钟偏移"（Asia/Hong_Kong = 480）。
 */
export function dayIndex(ms: number, tzOffsetMinutes: number): number {
  return Math.floor((ms + tzOffsetMinutes * 60000) / DAY_MS);
}

/** 自然日键 YYYY-MM-DD（用于 prefs 日计数器与日志）。 */
export function dayKey(ms: number, tzOffsetMinutes: number): string {
  const idx: number = dayIndex(ms, tzOffsetMinutes);
  const d: Date = new Date(idx * DAY_MS);
  const y: string = d.getUTCFullYear().toString();
  const m: string = pad2(d.getUTCMonth() + 1);
  const day: string = pad2(d.getUTCDate());
  return y + '-' + m + '-' + day;
}

/** 由自然日键反推日序号（解析失败返回 -1，调用方跳过）。 */
export function dayIndexOfKey(key: string): number {
  if (key.length < 8) {
    return -1;
  }
  const parts: string[] = key.split('-');
  if (parts.length !== 3) {
    return -1;
  }
  const y: number = Number(parts[0]);
  const m: number = Number(parts[1]);
  const d: number = Number(parts[2]);
  if (!isFinite(y) || !isFinite(m) || !isFinite(d) || m < 1 || m > 12 || d < 1 || d > 31) {
    return -1;
  }
  const ms: number = Date.UTC(y, m - 1, d);
  return Math.floor(ms / DAY_MS);
}

/**
 * 连续天数：updatedAt 去重为自然日，**以今天为终点**往回数连续段。
 * 今天没有落字 → 0（与 HomePage 既有口径一致）。
 */
export function consecutiveDays(updatedAtMs: number[], todayMs: number,
  tzOffsetMinutes: number): number {
  const days: Set<number> = new Set<number>();
  for (let i = 0; i < updatedAtMs.length; i++) {
    const ms: number = updatedAtMs[i];
    if (isFinite(ms) && ms > 0) {
      days.add(dayIndex(ms, tzOffsetMinutes));
    }
  }
  let cursor: number = dayIndex(todayMs, tzOffsetMinutes);
  let streak: number = 0;
  while (days.has(cursor)) {
    streak = streak + 1;
    cursor = cursor - 1;
  }
  return streak;
}

/** 总字数：全部文档 charCount 之和（缺省按 0）。 */
export function sumCounts(counts: number[]): number {
  let total: number = 0;
  for (let i = 0; i < counts.length; i++) {
    const n: number = counts[i];
    if (isFinite(n) && n > 0) {
      total = total + Math.floor(n);
    }
  }
  return total;
}

/** 每日目标进度：0..1；目标 ≤0 时按 0 进度（不除零）。 */
export function progressRatio(chars: number, goal: number): number {
  if (!isFinite(chars) || chars <= 0) {
    return 0;
  }
  if (!isFinite(goal) || goal <= 0) {
    return 0;
  }
  const r: number = chars / goal;
  return r > 1 ? 1 : r;
}

/** 目标是否达成（进度满格且字数 ≥1）。 */
export function goalReached(chars: number, goal: number): boolean {
  return isFinite(chars) && chars > 0 && isFinite(goal) && goal > 0 && chars >= goal;
}

// ---- 第 4 批 F11／F14：日字数合并、目标 clamp、纸张种类合并（纯函数，Node 可测）----

/** 每日目标上下限（与设置页滑杆 100–2000 同口径）。 */
export const DAILY_GOAL_MIN: number = 100;
export const DAILY_GOAL_MAX: number = 2000;
/** 每日目标步进（设置页滑杆用）。 */
export const DAILY_GOAL_STEP: number = 100;

/**
 * 每日目标 clamp 到 100–2000（守住设置页滑杆的上下限）。
 * 非有限值/≤0 先取 fallback（缺省 DAILY_GOAL_MIN），再 clamp；小数向下取整。
 */
export function clampDailyGoal(goal: number, fallback: number = DAILY_GOAL_MIN): number {
  let g: number = isFinite(goal) && goal > 0 ? Math.floor(goal) : fallback;
  if (!isFinite(g) || g <= 0) {
    g = DAILY_GOAL_MIN;
  }
  if (g < DAILY_GOAL_MIN) {
    return DAILY_GOAL_MIN;
  }
  if (g > DAILY_GOAL_MAX) {
    return DAILY_GOAL_MAX;
  }
  return g;
}

/**
 * 今日字数合并：日键相同则累加，跨日归零后只加 delta。
 * delta 只加不减（负数/非有限值按 0），删除字不扣减（设计 §1.3）。
 */
export function mergeDailyChars(prevKey: string, prevChars: number, todayKey: string, delta: number): number {
  const base: number = prevKey === todayKey && isFinite(prevChars) && prevChars > 0
    ? Math.floor(prevChars) : 0;
  const add: number = isFinite(delta) && delta > 0 ? Math.floor(delta) : 0;
  return base + add;
}

/** 纸张种类集合的小数组插入排序（确定性；避开仓规禁止的运行时排序）。 */
function sortedUniqueKinds(parts: string[]): string[] {
  const out: string[] = [];
  for (let i = 0; i < parts.length; i++) {
    const v: string = parts[i];
    let pos: number = out.length;
    for (let j = 0; j < out.length; j++) {
      if (v < out[j]) {
        pos = j;
        break;
      }
    }
    out.push('');
    for (let j = out.length - 1; j > pos; j--) {
      out[j] = out[j - 1];
    }
    out[pos] = v;
  }
  return out;
}

/**
 * 纸张种类集合合并：逗号去重＋按字母序稳定排序。
 * kind 为空（或全空白）原样返回 prev（不做归一化，保证"空 kind 不写盘"）。
 */
export function paperKindsMerge(prev: string, kind: string): string {
  const k: string = kind.trim();
  if (k.length === 0) {
    return prev;
  }
  const seen: Set<string> = new Set<string>();
  const list: string[] = [];
  const parts: string[] = prev.split(',');
  for (let i = 0; i < parts.length; i++) {
    const p: string = parts[i].trim();
    if (p.length > 0 && !seen.has(p)) {
      seen.add(p);
      list.push(p);
    }
  }
  if (!seen.has(k)) {
    seen.add(k);
    list.push(k);
  }
  return sortedUniqueKinds(list).join(',');
}
