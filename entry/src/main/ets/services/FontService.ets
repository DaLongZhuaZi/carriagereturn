/**
 * 回车 · 字体服务（第 0 批）。
 *
 * 薄封装：**复用启动注册循环的同一函数**（从 Index 原样搬入），不许另写一套注册逻辑。
 * 第 2 批字体导入只调 registerFromFile（私有目录动态注册），不复制本文件逻辑。
 */

import { UIContext } from '@ohos.arkui.UIContext';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FontSpec } from '../model/MachineCatalog';

const DOMAIN: number = 0x0000;
const TAG: string = 'FontService';

/** 注册结果：成功与失败的 familyName。 */
export interface FontRegisterResult {
  ok: string[];
  failed: string[];
}

/** 字体注册服务（薄封装，无状态）。 */
export class FontService {
  /**
   * 注册随包字体（启动时调用一次）。原 Index 循环的逐项 try/catch 与日志口径保持不变。
   */
  static registerBundled(ui: UIContext, fonts: FontSpec[]): FontRegisterResult {
    const ok: string[] = [];
    const failed: string[] = [];
    for (let i = 0; i < fonts.length; i++) {
      try {
        ui.getFont().registerFont({
          familyName: fonts[i].familyName,
          familySrc: $rawfile(fonts[i].rawfile),
        });
        ok.push(fonts[i].familyName);
        hilog.info(DOMAIN, TAG, 'registerFont ok %{public}s <- %{public}s',
          fonts[i].familyName, fonts[i].rawfile);
      } catch (e) {
        failed.push(fonts[i].familyName);
        hilog.error(DOMAIN, TAG, 'registerFont FAILED %{public}s <- %{public}s',
          fonts[i].familyName, fonts[i].rawfile);
      }
    }
    hilog.info(DOMAIN, TAG, 'registerFont total=%{public}s failed=%{public}s',
      fonts.length.toString(), failed.length.toString());
    return { ok: ok, failed: failed };
  }

  /**
   * 从应用私有目录注册一个字体（第 2 批 F3 导入用；本批只留签名）。
   * @param ui UIContext（页面就绪后调用）
   * @param familyName 注册族名（导入时生成唯一名，避免与随包 17 款冲突）
   * @param filePath 沙箱绝对路径（FileHelper.copyToSandbox 的返回值）
   * @returns 是否注册成功；失败原文进 hilog，不抛
   */
  static registerFromFile(ui: UIContext, familyName: string, filePath: string): boolean {
    try {
      ui.getFont().registerFont({
        familyName: familyName,
        familySrc: 'file://' + filePath,
      });
      hilog.info(DOMAIN, TAG, 'registerFont private ok %{public}s <- %{public}s',
        familyName, filePath);
      return true;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'registerFont private FAILED %{public}s code=%{public}s msg=%{public}s',
        familyName,
        err.code === undefined ? '' : err.code.toString(),
        err.message === undefined ? '' : err.message);
      return false;
    }
  }
}