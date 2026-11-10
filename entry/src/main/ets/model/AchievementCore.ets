/**
 * 回车 · F5 成就判定纯函数（第 9 批）
 *
 * 输入＝派生值＋事件计数（全部由调用方取好传进来）；输出＝已达成 id 集合。
 * 本文件**不读 prefs、不读时钟、不读 UI**，因此可被 Node（--experimental-strip-types）直接单测。
 *
 * 铁律：判定只读 `model/AchievementDefs.ets` 的成就表；UI 只消费结果，不许再算一份。
 */

import type { AchievementDef, AchievementMetric } from './AchievementDefs';
import { ACHIEVEMENTS } from './AchievementDefs';

/** 判定输入（一次 flush 之后的快照）。 */
export interface AchievementInputs {
  /** 持久化累计落字数（只增不减，删除文档不扣减）。 */
  totalChars: number;
  /** 连续天数（当日快照：今天没落字＝0）。 */
  streakDays: number;
  /** 今日是否达成每日目标（当日瞬时值）。 */
  goalReached: boolean;
  /** 分享面板调起次数（`doc_shared`）。 */
  shareCount: number;
  /** 用过的纸张种类数（`stats.paper.kinds`）。 */
  paperKinds: number;
  /** 换字体次数（`font_changed`）。 */
  fontChanges: number;
  /** 换色带次数（`ribbon_changed`）。 */
  ribbonChanges: number;
  /** 半开落字数（`fold_typed`）。 */
  foldChars: number;
  /** 保存次数（`doc_saved`）。 */
  saves: number;
  /** 当前设备是否可折叠（A13 设备差异；false 时 A13 永不达成）。 */
  foldableDevice: boolean;
}

/** 取某个数据源的当前值（metrу 只在这里映射一次）。 */
export function metricValue(metric: AchievementMetric, inputs: AchievementInputs): number {
  if (metric === 'words') { return inputs.totalChars; }
  if (metric === 'streak') { return inputs.streakDays; }
  if (metric === 'goal') { return inputs.goalReached ? 1 : 0; }
  if (metric === 'share') { return inputs.shareCount; }
  if (metric === 'paper') { return inputs.paperKinds; }
  if (metric === 'font') { return inputs.fontChanges; }
  if (metric === 'ribbon') { return inputs.ribbonChanges; }
  if (metric === 'fold') { return inputs.foldChars; }
  if (metric === 'saved') { return inputs.saves; }
  return 0;
}

/** 单项是否达成（含折叠设备闸门与阈值边界：达到阈值即达成，阈值-1 不达成）。 */
export function isAchieved(def: AchievementDef, inputs: AchievementInputs): boolean {
  if (def.foldOnly && !inputs.foldableDevice) {
    return false;
  }
  return metricValue(def.metric, inputs) >= def.threshold;
}

/** 判定入口：返回**已达成 id 的集合**（顺序＝成就表顺序）。 */
export function evaluateAchieved(inputs: AchievementInputs): string[] {
  const out: string[] = [];
  for (let i = 0; i < ACHIEVEMENTS.length; i++) {
    if (isAchieved(ACHIEVEMENTS[i], inputs)) {
      out.push(ACHIEVEMENTS[i].id);
    }
  }
  return out;
}

/** 进度 0..1（UI 用：当前值／阈值，超过 1 截到 1；折叠设备闸门不满足时返回 0）。 */
export function achievementProgress(def: AchievementDef, inputs: AchievementInputs): number {
  if (def.foldOnly && !inputs.foldableDevice) {
    return 0;
  }
  if (def.threshold <= 0) {
    return 1;
  }
  const v: number = metricValue(def.metric, inputs);
  const r: number = v / def.threshold;
  return r > 1 ? 1 : (r < 0 ? 0 : r);
}
