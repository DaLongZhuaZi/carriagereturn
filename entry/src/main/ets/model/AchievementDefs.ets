/**
 * 回车 · F5 成就清单（行为绑定版，第 9 批）
 *
 * 单一事实源：14 项成就的 id／资源键／数据源／阈值**只在本文件写一次**。
 * 判定逻辑（`model/AchievementCore.ets`）只读这张表，UI 不做第二份计算。
 *
 * 铁律（用户 2026-11-10 定）：
 * - 成就与**使用行为**绑定，不与机型绑定：本表 14 项无一以 MachineKind 为条件，
 *   判定里也不许出现机型；四台机永久全开，成就是纯徽章＋进度。
 * - 阈值与成就名已由用户批准（设计稿 §2 表 / §12），改动须走设计稿变更。
 *
 * 本文件必须可被 Node（--experimental-strip-types）直接加载：
 * 不许用枚举、不许用 $r、不许 import 任何运行时依赖。
 */

/** 成就数据源（判定用的派生量）＝纯字符串标签，避免枚举（Node 类型剥离不支持 enum）。 */
export type AchievementMetric =
  | 'words'      // 持久化累计落字数（只增不减）
  | 'streak'     // consecutiveDays() 当日快照
  | 'goal'       // goalReached() 当日瞬时（达成＝1）
  | 'share'      // eventCount('doc_shared')
  | 'paper'      // paperKindsUsed() 集合大小
  | 'font'       // eventCount('font_changed')
  | 'ribbon'     // eventCount('ribbon_changed')
  | 'fold'       // fold_typed 累计字数
  | 'saved';     // eventCount('doc_saved')

/** 一项成就的定义。资源键后缀约定：`app.string.ach_name_<id>`、`app.string.ach_desc_<id>`。 */
export interface AchievementDef {
  id: string;
  nameRes: string;
  descRes: string;
  metric: AchievementMetric;
  threshold: number;
  /** 折叠设备专属（A13）：非折叠设备不判定、UI 显示「仅折叠设备」。 */
  foldOnly: boolean;
}

// ---- 阈值常量（用户已批准；只在这里写一次）----

/** A1 累计落字。 */
export const ACH_WORDS_1: number = 1000;
/** A2 累计落字。 */
export const ACH_WORDS_2: number = 5000;
/** A3 累计落字。 */
export const ACH_WORDS_3: number = 20000;
/** A4 连续天数。 */
export const ACH_STREAK_1: number = 3;
/** A5 连续天数。 */
export const ACH_STREAK_2: number = 7;
/** A6 单日达标次数（goalReached 视为 1 次）。 */
export const ACH_GOAL_1: number = 1;
/** A7 分享次数。 */
export const ACH_SHARE_1: number = 1;
/** A8 分享次数。 */
export const ACH_SHARE_2: number = 10;
/** A9 纸张种类。 */
export const ACH_PAPER_1: number = 2;
/** A10 纸张种类。 */
export const ACH_PAPER_2: number = 4;
/** A11 换字体次数。 */
export const ACH_FONT_1: number = 1;
/** A12 换色带次数。 */
export const ACH_RIBBON_1: number = 1;
/** A13 半开落字数。 */
export const ACH_FOLD_1: number = 1;
/** A14 保存次数。 */
export const ACH_SAVED_1: number = 10;

/** 14 项成就（顺序＝弹窗/列表顺序）。 */
export const ACHIEVEMENTS: AchievementDef[] = [
  { id: 'words_1000', nameRes: 'ach_name_words_1000', descRes: 'ach_desc_words_1000',
    metric: 'words', threshold: ACH_WORDS_1, foldOnly: false },
  { id: 'words_5000', nameRes: 'ach_name_words_5000', descRes: 'ach_desc_words_5000',
    metric: 'words', threshold: ACH_WORDS_2, foldOnly: false },
  { id: 'words_20000', nameRes: 'ach_name_words_20000', descRes: 'ach_desc_words_20000',
    metric: 'words', threshold: ACH_WORDS_3, foldOnly: false },
  { id: 'streak_3', nameRes: 'ach_name_streak_3', descRes: 'ach_desc_streak_3',
    metric: 'streak', threshold: ACH_STREAK_1, foldOnly: false },
  { id: 'streak_7', nameRes: 'ach_name_streak_7', descRes: 'ach_desc_streak_7',
    metric: 'streak', threshold: ACH_STREAK_2, foldOnly: false },
  { id: 'goal_1', nameRes: 'ach_name_goal_1', descRes: 'ach_desc_goal_1',
    metric: 'goal', threshold: ACH_GOAL_1, foldOnly: false },
  { id: 'share_1', nameRes: 'ach_name_share_1', descRes: 'ach_desc_share_1',
    metric: 'share', threshold: ACH_SHARE_1, foldOnly: false },
  { id: 'share_10', nameRes: 'ach_name_share_10', descRes: 'ach_desc_share_10',
    metric: 'share', threshold: ACH_SHARE_2, foldOnly: false },
  { id: 'paper_2', nameRes: 'ach_name_paper_2', descRes: 'ach_desc_paper_2',
    metric: 'paper', threshold: ACH_PAPER_1, foldOnly: false },
  { id: 'paper_4', nameRes: 'ach_name_paper_4', descRes: 'ach_desc_paper_4',
    metric: 'paper', threshold: ACH_PAPER_2, foldOnly: false },
  { id: 'font_1', nameRes: 'ach_name_font_1', descRes: 'ach_desc_font_1',
    metric: 'font', threshold: ACH_FONT_1, foldOnly: false },
  { id: 'ribbon_1', nameRes: 'ach_name_ribbon_1', descRes: 'ach_desc_ribbon_1',
    metric: 'ribbon', threshold: ACH_RIBBON_1, foldOnly: false },
  { id: 'fold_1', nameRes: 'ach_name_fold_1', descRes: 'ach_desc_fold_1',
    metric: 'fold', threshold: ACH_FOLD_1, foldOnly: true },
  { id: 'docs_10', nameRes: 'ach_name_docs_10', descRes: 'ach_desc_docs_10',
    metric: 'saved', threshold: ACH_SAVED_1, foldOnly: false },
];

/** 按 id 取定义（找不到返回 null）。 */
export function achievementById(id: string): AchievementDef | null {
  for (let i = 0; i < ACHIEVEMENTS.length; i++) {
    if (ACHIEVEMENTS[i].id === id) {
      return ACHIEVEMENTS[i];
    }
  }
  return null;
}
