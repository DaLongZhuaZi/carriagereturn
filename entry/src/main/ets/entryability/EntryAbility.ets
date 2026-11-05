import { AbilityConstant, UIAbility, Want, common } from '@kit.AbilityKit';
import { font, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FileUtils, logger, ngfDeviceAdaptationFacade, ngfI18nManagerFacade, ngfPlatformWindowManagerFacade, ngfStarterKernel, ngfThemeManagerFacade, uiContextManager } from 'ngf_framework';
import { docStore } from '../services/DocStore';
import { appPreferences } from '../services/AppPreferences';

const TAG: string = 'EntryAbility';
const DOMAIN: number = 0x0000;

/**
 * 回车主 Ability。
 *
 * NGF 接线顺序（对照 airwavefootprints 的 EntryAbility 范式）：
 * 1. uiContextManager.bindAbilityContext —— 框架各门面要拿 filesDir；
 * 2. FileUtils.setSandboxBaseDir —— 沙箱基础目录必须早于任何文件读写；
 * 3. ngfStarterKernel.bootstrap() —— 核心服务与模块引导；
 * 4. 主题 / i18n 门面 initializeDefaults —— 必须在 bootstrap 之后。
 *
 * 回车的文档存储（DocStore）也要 filesDir，故在本方法里 init；
 * DocStore 不依赖 UI，页面用同一单例即可。
 */
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    uiContextManager.bindAbilityContext(this.context as common.UIAbilityContext);
    FileUtils.setSandboxBaseDir(this.context.filesDir);
    docStore.init(this.context.filesDir);
    appPreferences.init(this.context as common.UIAbilityContext);

    let bootstrapped: boolean = false;
    try {
      bootstrapped = ngfStarterKernel.bootstrap();
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'NGF bootstrap failed: %{public}s', JSON.stringify(err));
    }
    logger.startup(TAG, 'NGF 引导启动完成', '成功=' + bootstrapped);

    try {
      ngfThemeManagerFacade.initializeDefaults();
      ngfI18nManagerFacade.initializeDefaults();
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'facade init failed: %{public}s', JSON.stringify(err));
    }
  }

  onDestroy(): void {
    uiContextManager.clearAbilityContext();
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 注册 Courier Prime（此前全仓无一处 registerFont，纸面 Text 回落系统比例字体）
    try {
      font.registerFont({ familyName: 'CourierPrime', familySrc: $rawfile('font/CourierPrime-Regular.ttf') });
      hilog.info(DOMAIN, TAG, 'registerFont CourierPrime ok');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'registerFont failed');
    }
    // §2.9 沉浸式按 NGF 标准接线（照源仓 af-app）：两行都要有，否则 NGF 沉浸式栈是死代码。
    // 本批只调用已有门面，不改 vendored 框架副本（AGENTS.md）。
    ngfPlatformWindowManagerFacade.bindWindowStage(windowStage);
    ngfDeviceAdaptationFacade.bindWindowStage(windowStage);
    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, '%{public}s', 'loadContent succeeded');
    });
  }

  onWindowStageDestroy(): void {
    ngfPlatformWindowManagerFacade.clearWindowStage();
    ngfDeviceAdaptationFacade.clearWindowStage();
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onBackground');
  }
}
