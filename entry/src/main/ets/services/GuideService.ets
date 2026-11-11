/**
 * 回车 · 引导状态服务（第 1 批）。
 *
 * 只做 prefs 读写与判定；GuideOverlay 保持纯渲染器（第 0 批契约）。
 * 页面 id 与键名规则来自 model/GuideCore.ets（纯函数，可单测）。
 */

import { appPreferences, PrefKeys } from './AppPreferences';
import { allPages, isValidPage } from '../model/GuideCore';
import { TestHooks } from './TestHooks';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class GuideService {
  /** 产品开关（默认 on；F1 批内一次交付完整、无半成品窗口，见 1-引导与拨杆跟手-增量设计 §1.6；移除点：第 8 轮）。 */
  static enabled(): boolean {
    return appPreferences.getBool(PrefKeys.GUIDE_ENABLED, true);
  }

  static setEnabled(on: boolean): void {
    appPreferences.setBool(PrefKeys.GUIDE_ENABLED, on);
  }

  /** 测试模式（仅测试构建由脚本置 true；发布构建无入口）。 */
  static testMode(): boolean {
    return appPreferences.getBool(PrefKeys.GUIDE_TEST_MODE, false);
  }

  static setTestMode(on: boolean): void {
    appPreferences.setBool(PrefKeys.GUIDE_TEST_MODE, on);
  }

  /** 某页是否已看过。 */
  static seen(page: string): boolean {
    return appPreferences.getBool(PrefKeys.guideSeen(page), false);
  }

  /**
   * 回归模式：仅测试构建生效（TEST_HOOKS_BUILD=true 且 guide.testMode=false）时引导关闭。
   * 发布构建 TestHooks.enabled() 恒 false，因此真实用户不受影响。
   */
  static regressionMode(): boolean {
    return TestHooks.enabled() && !appPreferences.getBool(PrefKeys.GUIDE_TEST_MODE, false);
  }

  /** 是否应显示该页引导（开关开 && 未看过 && 非回归模式）。 */
  static shouldShow(page: string): boolean {
    if (!isValidPage(page) || !GuideService.enabled() || GuideService.regressionMode()) {
      return false;
    }
    return !GuideService.seen(page);
  }

  static markSeen(page: string): void {
    if (isValidPage(page)) {
      appPreferences.setBool(PrefKeys.guideSeen(page), true);
    }
  }

  /** 清 14 页的 seen（不动 ONBOARDING_SEEN）。 */
  static resetPages(): void {
    const pages: string[] = allPages();
    for (let i = 0; i < pages.length; i++) {
      appPreferences.setBool(PrefKeys.guideSeen(pages[i]), false);
    }
    hilog.info(0x0000, 'GuideService', 'guide reset pages count=%{public}s', pages.length.toString());
  }

  // ---- 启动引导 ----

  static onboardingSeen(): boolean {
    return appPreferences.getBool(PrefKeys.ONBOARDING_SEEN, false);
  }

  static markOnboardingSeen(): void {
    appPreferences.setBool(PrefKeys.ONBOARDING_SEEN, true);
  }

  static resetOnboarding(): void {
    appPreferences.setBool(PrefKeys.ONBOARDING_SEEN, false);
  }
}