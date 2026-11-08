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