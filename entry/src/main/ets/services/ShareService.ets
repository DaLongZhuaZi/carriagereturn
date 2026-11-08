/**
 * 回车 · 分享唯一入口（第 0 批）。
 *
 * Index 里现有的 systemShare 调用全部迁入本服务；以后各批（F4 导出／碰一碰）只调这里，
 * 不许在页面里再直接 import ShareKit。行为与本批前完全一致：fileUri → SharedData →
 * ShareController.show，面板调起算成功，**不宣称"已分享成功"**（系统面板看不到对方是否接收）。
 */

import { common } from '@kit.AbilityKit';
import { fileUri } from '@kit.CoreFileKit';
import { systemShare } from '@kit.ShareKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'ShareService';

/** 分享结果（只说明"面板是否调起"，不说明对方是否完成）。 */
export interface ShareResult {
  /** 是否成功调起系统分享面板。 */
  shown: boolean;
  /** 失败时的原文错误（成功为空）。 */
  error: string;
}

/** 分享服务（唯一入口）。 */
export class ShareService {
  /**
   * 分享一个本地文件。
   * @param ctx UIAbilityContext
   * @param path 应用沙箱内绝对路径（filesDir/...）
   * @param utd 统一类型描述符，如 general.plain-text／general.png／general.pdf
   */
  static shareFile(ctx: common.UIAbilityContext, path: string, utd: string): Promise<ShareResult> {
    return new Promise<ShareResult>((resolve: (r: ShareResult) => void) => {
      try {
        const uri: string = fileUri.getUriFromPath(path);
        const data: systemShare.SharedData = new systemShare.SharedData({
          utd: utd,
          uri: uri,
        });
        const controller: systemShare.ShareController = new systemShare.ShareController(data);
        const opts: systemShare.ShareControllerOptions = {};
        controller.show(ctx, opts)
          .then(() => {
            hilog.info(DOMAIN, TAG, 'share panel shown uri=%{public}s', uri);
            resolve({ shown: true, error: '' });
          })
          .catch((e: BusinessError) => {
            hilog.error(DOMAIN, TAG, 'share panel failed code=%{public}s msg=%{public}s',
              e.code === undefined ? '' : e.code.toString(),
              e.message === undefined ? '' : e.message);
            resolve({ shown: false, error: e.message === undefined ? 'share failed' : e.message });
          });
        hilog.info(DOMAIN, TAG, 'share requested uri=%{public}s', uri);
      } catch (e) {
        const err: BusinessError = e as BusinessError;
        hilog.error(DOMAIN, TAG, 'share failed: %{public}s', JSON.stringify(err));
        resolve({ shown: false, error: err.message === undefined ? 'share failed' : err.message });
      }
    });
  }
}