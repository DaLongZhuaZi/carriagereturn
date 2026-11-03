import { AbilityConstant, UIAbility, Want, common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FileUtils, logger, ngfI18nManagerFacade, ngfStarterKernel, ngfThemeManagerFacade, uiContextManager } from 'ngf_framework';
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
    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, '%{public}s', 'loadContent succeeded');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'EntryAbility onBackground');
  }
}
