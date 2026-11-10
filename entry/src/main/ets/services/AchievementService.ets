/**
 * 回车 · F5 成就服务（第 9 批）
 *
 * 唯一职责：
 * 1. **判定入口**——保存／导出边界（`Index.flushSave()` 完成之后）调一次 `evaluate()`；
 *    判定本身在 `model/AchievementCore.ets` 的纯函数里，本服务只负责取数、落盘、排队与通知。
 * 2. **达成落盘**——新达成的写 `achieve.<id>`（只写一次，不重复提示），hilog 打 `achieve <id> reached`
 *    （不用"解锁"词汇）。
 * 3. **弹窗排队**——一次只给一条：`pending()` 返回当前该弹的那条，UI 关掉后调 `dismiss()` 再取下一条。
 *    多成就同时达成时按成就表顺序排队，绝不叠弹窗。
 * 4. **上线追认**——首次评估（`achieve.migrated` 未置位）把已达成的全部落盘，但只弹**一个汇总条**，
 *    不逐个弹；同时把累计落字计数器以当前 `totalWords()` 为初值写入一次（近似值，非真实历史累计）。
 *
 * 铁律：判定不走打字热路径；达标即落盘，次日快照归零不影响已达成态。
 */

import { display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { appPreferences, PrefKeys } from './AppPreferences';
import { statsService, StatsEvents } from './StatsService';
import { ACHIEVEMENTS, achievementById } from '../model/AchievementDefs';
import { AchievementInputs, evaluateAchieved, achievementProgress } from '../model/AchievementCore';

const DOMAIN: number = 0x0000;
const TAG: string = 'AchievementService';

/** 一条待弹提示：`item`＝单项成就；`summary`＝追认汇总（`count` 项）。 */
export interface AchieveNotice {
  kind: string;
  id: string;
  count: number;
}

export class AchievementService {
  /** 待弹成就（按成就表顺序；一次只弹队首）。 */
  private static queue: string[] = [];
  /** 追认汇总条数（>0 时先弹汇总；弹完清零）。 */
  private static summaryCount: number = 0;
  /** UI 侧变化通知（Index 注册；弹窗队列变化即回调）。 */
  private static listener: (() => void) | null = null;
  /** 防重入（evaluate 内部会读写 prefs）。 */
  private static running: boolean = false;

  static setListener(cb: (() => void) | null): void {
    AchievementService.listener = cb;
  }

  private static notify(): void {
    const cb: (() => void) | null = AchievementService.listener;
    if (cb !== null) {
      cb();
    }
  }

  /** 当前设备是否可折叠（A13 的设备差异；取不到就按不可折叠处理）。 */
  static foldableDevice(): boolean {
    try {
      return display.isFoldable();
    } catch (e) {
      return false;
    }
  }

  /** 取判定输入（全部派生值／事件计数，本服务不自己算统计）。 */
  static buildInputs(): AchievementInputs {
    return {
      totalChars: statsService.totalChars(),
      streakDays: statsService.consecutiveDays(),
      goalReached: statsService.goalReached(),
      shareCount: statsService.eventCount(StatsEvents.DOC_SHARED),
      paperKinds: statsService.paperKindsUsed(),
      fontChanges: statsService.eventCount(StatsEvents.FONT_CHANGED),
      ribbonChanges: statsService.eventCount(StatsEvents.RIBBON_CHANGED),
      foldChars: statsService.eventCount(StatsEvents.FOLD_TYPED),
      saves: statsService.eventCount(StatsEvents.DOC_SAVED),
      foldableDevice: AchievementService.foldableDevice(),
    };
  }

  /** 单项是否已达成（落盘口径，供 UI 显示已达成态）。 */
  static isAchieved(id: string): boolean {
    return appPreferences.getBool(PrefKeys.achieve(id), false);
  }

  /** 已达成总数。 */
  static achievedCount(): number {
    let n: number = 0;
    for (let i = 0; i < ACHIEVEMENTS.length; i++) {
      if (AchievementService.isAchieved(ACHIEVEMENTS[i].id)) {
        n = n + 1;
      }
    }
    return n;
  }

  /** 单项进度 0..1（UI 用；判定仍以 evaluateAchieved 为准）。 */
  static progressOf(id: string, inputs: AchievementInputs): number {
    const def = achievementById(id);
    if (def === null) {
      return 0;
    }
    return achievementProgress(def, inputs);
  }

  /**
   * 判定一次：读快照 → 纯函数判定 → 新达成的落盘 → 排队弹窗。
   * 调用点：`Index.flushSave()` 完成之后（保存／导出即 flush，每日至少一次）。
   */
  static evaluate(): void {
    if (AchievementService.running) {
      return;
    }
    AchievementService.running = true;
    try {
      const migrated: boolean = appPreferences.getBool(PrefKeys.ACHIEVE_MIGRATED, false);
      if (!migrated) {
        // 上线追认：累计落字计数器以当前 totalWords() 为初值写一次（近似值，须在批报告写明）
        const seeded: boolean = statsService.initTotalCharsIfAbsent(statsService.totalWords());
        hilog.info(DOMAIN, TAG, 'first evaluation (migration) seeded=%{public}s totalWords=%{public}s',
          seeded ? 'true' : 'false', statsService.totalWords().toString());
      }
      const inputs: AchievementInputs = AchievementService.buildInputs();
      const achieved: string[] = evaluateAchieved(inputs);
      const fresh: string[] = [];
      for (let i = 0; i < achieved.length; i++) {
        const id: string = achieved[i];
        if (!AchievementService.isAchieved(id)) {
          appPreferences.setBool(PrefKeys.achieve(id), true);
          fresh.push(id);
        }
      }
      if (!migrated) {
        appPreferences.setBool(PrefKeys.ACHIEVE_MIGRATED, true);
        // 追认只弹一个汇总条，不逐个弹
        if (fresh.length > 0) {
          AchievementService.summaryCount = fresh.length;
          hilog.info(DOMAIN, TAG, 'achievements migrated/backfilled count=%{public}s ids=%{public}s',
            fresh.length.toString(), fresh.join(','));
        } else {
          hilog.info(DOMAIN, TAG, 'achievements migrated: none achieved yet');
        }
        AchievementService.notify();
        return;
      }
      if (fresh.length > 0) {
        for (let i = 0; i < fresh.length; i++) {
          hilog.info(DOMAIN, TAG, 'achieve %{public}s reached', fresh[i]);
          AchievementService.queue.push(fresh[i]);
        }
        AchievementService.notify();
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'evaluate failed: %{public}s', JSON.stringify(e));
    } finally {
      AchievementService.running = false;
    }
  }

  /** 当前该弹的那条（汇总优先；没了返回 null）。UI 每次重建时读一次。 */
  static pending(): AchieveNotice | null {
    if (AchievementService.summaryCount > 0) {
      return {
        kind: 'summary',
        id: '',
        count: AchievementService.summaryCount,
      };
    }
    if (AchievementService.queue.length > 0) {
      return {
        kind: 'item',
        id: AchievementService.queue[0],
        count: 0,
      };
    }
    return null;
  }

  /** 用户关掉当前那条：消费掉它，并把下一条通知给 UI（一次只弹一个）。 */
  static dismiss(): void {
    if (AchievementService.summaryCount > 0) {
      AchievementService.summaryCount = 0;
    } else if (AchievementService.queue.length > 0) {
      AchievementService.queue.shift();
    }
    AchievementService.notify();
  }

  /** 清空待弹队列（测试／调试用；正式流程不调）。 */
  static clearQueue(): void {
    AchievementService.queue = [];
    AchievementService.summaryCount = 0;
    AchievementService.notify();
  }
}

