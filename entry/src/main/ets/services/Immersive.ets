/**
 * 回车 · 新页沉浸式（§2.10 通则）
 *
 * 照 Index.ets 的现成实现抽出来一份公用函数，七页共用同一套，不许各写平行规则。
 * 只做窗口侧：全屏布局 + 系统栏透明 + 内容色 + 动态安全区读数。
 * 页面自己负责把 topInset/bottomInset 用到顶栏/底距上。
 */

import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'Immersive';

export interface Insets {
  top: number;
  bottom: number;
}

/** 打开沉浸式并读回安全区；失败回退 28/0 并记日志，不抛。 */
export async function applyImmersive(ui: UIContext): Promise<Insets> {
  const host = ui.getHostContext();
  if (host === undefined || host === null) {
    hilog.error(DOMAIN, TAG, 'no host context, fallback insets 28/0');
    return { top: 28, bottom: 0 };
  }
  try {
    const win: window.Window = await window.getLastWindow(host as common.UIAbilityContext);
    await win.setWindowLayoutFullScreen(true);
    await win.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: '#dbccb3',
      navigationBarContentColor: '#dbccb3',
    });
    await win.setSpecificSystemBarEnabled('status', true, true);
    await win.setSpecificSystemBarEnabled('navigation', true, true);

    const sys = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    const nav = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
    const top: number = ui.px2vp(sys.topRect.height);
    const bottom: number = ui.px2vp(nav.bottomRect.height);
    hilog.info(DOMAIN, TAG, 'insets top=%{public}s bottom=%{public}s',
      top.toFixed(1), bottom.toFixed(1));
    return { top: top, bottom: bottom };
  } catch (e) {
    const err: BusinessError = e as BusinessError;
    hilog.error(DOMAIN, TAG, 'immersive failed, fallback insets: %{public}s', JSON.stringify(err));
    return { top: 28, bottom: 0 };
  }
}
