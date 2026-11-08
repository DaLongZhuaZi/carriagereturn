/**
 * 回车 · 文件选择／保存共享 helper（第 0 批）。
 *
 * 统一 FilePicker 的权限、uri→沙箱拷贝、错误处理；F3（字体／纸纹导入）与
 * F4（导出保存到用户可见位置）共用。**不在这里做业务校验**（字体文件头校验在
 * FontService／第 2 批，图片尺寸校验在第 3 批）。
 *
 * 说明：本机无 SDK / 无设备，API 形态按公开 API 12+ 写；探针 `probe_file_picker.py`
 * 负责在真机核对（通过标准见脚本头）。所有入口失败返回 null 并打原文错误，不抛。
 */

import { common } from '@kit.AbilityKit';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SaveResult } from '../model/ExportCore';

const DOMAIN: number = 0x0000;
const TAG: string = 'FileHelper';
/** 导入文件落到应用沙箱的子目录（相对 filesDir）。 */
const IMPORT_DIR: string = 'imports';
/**
 * picker 用户取消的错误码（13900042 “User operation cancelled”）。
 * 第 3 批起 saveBytes 要把「取消」和「失败」分开：取消回 idle，失败进错误态。
 * 该码值来自 user file service 通行约定，**设备未验**（第 7 批冒烟核对）。
 */
const PICKER_CANCEL_CODE: number = 13900042;

/** 用户选中的一个文件。 */
export interface PickedFile {
  /** picker 返回的 uri（file://...）。 */
  uri: string;
  /** 展示名（uri 末段解码）。 */
  name: string;
  /** 字节数；取不到为 0。 */
  size: number;
}

/** 文件选择／保存 helper（全静态，无状态）。 */
export class FileHelper {
  /** uri 末段 → 展示名。 */
  private static nameOf(uri: string): string {
    const clean: string = uri.split('?')[0];
    const parts: string[] = clean.split('/');
    const last: string = parts.length > 0 ? parts[parts.length - 1] : '';
    try {
      return decodeURIComponent(last);
    } catch (e) {
      return last;
    }
  }

  /** 取文件大小；uri 打不开按 0（调用方按"未知大小"处理，不据此拒绝）。 */
  private static sizeOf(uri: string): number {
    try {
      const st: fs.Stat = fs.statSync(uri);
      return st.size > 0 ? st.size : 0;
    } catch (e) {
      return 0;
    }
  }

  private static toPicked(uri: string): PickedFile {
    return { uri: uri, name: FileHelper.nameOf(uri), size: FileHelper.sizeOf(uri) };
  }

  /**
   * 选一个字体文件（.ttf／.otf）。
   * @param ctx UIAbilityContext（picker 需要）
   */
  static async pickFont(ctx: common.UIAbilityContext): Promise<PickedFile | null> {
    return FileHelper.pickDocument(ctx, ['字体文件|.ttf,.otf']);
  }

  /** 选一个图片（PhotoViewPicker；纸纹导入用）。 */
  static async pickImage(ctx: common.UIAbilityContext): Promise<PickedFile | null> {
    try {
      const photoPicker: picker.PhotoViewPicker = new picker.PhotoViewPicker();
      const options: picker.PhotoSelectOptions = new picker.PhotoSelectOptions();
      options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result: picker.PhotoSelectResult = await photoPicker.select(options);
      const uris: string[] = result.photoUris;
      if (uris === undefined || uris.length === 0) {
        return null;
      }
      return FileHelper.toPicked(uris[0]);
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'pickImage failed code=%{public}s msg=%{public}s',
        err.code === undefined ? '' : err.code.toString(),
        err.message === undefined ? '' : err.message);
      return null;
    }
  }

  /** 通用选文件（后缀过滤器形如 ['字体文件|.ttf,.otf']）。 */
  static async pickDocument(ctx: common.UIAbilityContext, suffixFilters: string[]):
    Promise<PickedFile | null> {
    try {
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(ctx);
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.fileSuffixFilters = suffixFilters;
      const uris: string[] = await documentPicker.select(options);
      if (uris === undefined || uris.length === 0) {
        return null;
      }
      return FileHelper.toPicked(uris[0]);
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'pickDocument failed code=%{public}s msg=%{public}s',
        err.code === undefined ? '' : err.code.toString(),
        err.message === undefined ? '' : err.message);
      return null;
    }
  }

  /**
   * 让用户选保存位置并写入字节（第 3 批 F4：返回值改为 SaveResult）。
   *
   * 三个分支必须分开（增量设计 §1.2 / M-10）：
   *   - 写入成功 → `{ status:'ok', uri }`（页面显示“已保存”）；
   *   - 用户取消选位置 → `{ status:'cancel' }`（页面回 idle，**不报错**）；
   *   - 其它异常 → `{ status:'error', error }`（页面显示原文错误）。
   *
   * @param suggestedName 默认文件名（由 `ExportCore.safeFileName` 生成，带时间戳）
   * @param ext 扩展名（不带点：png／pdf／txt）；非空时用于 `fileSuffixChoices`
   * @param data 要写入的字节（ArrayBuffer）或文本
   */
  static async saveBytes(ctx: common.UIAbilityContext, suggestedName: string, ext: string,
    data: ArrayBuffer | string): Promise<SaveResult> {
    let target: string = '';
    try {
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(ctx);
      const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      options.newFileNames = [suggestedName];
      // fileSuffixChoices 形如 '<描述>|.<后缀>'；描述用大写后缀，避免在服务层写中文文案
      if (ext.length > 0) {
        options.fileSuffixChoices = [ext.toUpperCase() + '|.' + ext];
      }
      let uris: string[] = [];
      try {
        uris = await documentPicker.save(options);
      } catch (e) {
        const err: BusinessError = e as BusinessError;
        const msg: string = err.message === undefined ? '' : err.message;
        if (FileHelper.isCancel(err)) {
          hilog.info(DOMAIN, TAG, 'saveBytes cancelled by user');
          return { status: 'cancel', uri: '', error: '' };
        }
        hilog.error(DOMAIN, TAG, 'saveBytes picker failed code=%{public}s msg=%{public}s',
          err.code === undefined ? '' : err.code.toString(), msg);
        return { status: 'error', uri: '', error: msg.length > 0 ? msg : 'save failed' };
      }
      if (uris === undefined || uris.length === 0) {
        // picker 用「空数组」表示用户取消（与取消码两条路径都兜住）
        hilog.info(DOMAIN, TAG, 'saveBytes cancelled: empty uri list');
        return { status: 'cancel', uri: '', error: '' };
      }
      target = uris[0];
      const file: fs.File = fs.openSync(target,
        fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(file.fd, data);
      } finally {
        fs.closeSync(file);
      }
      hilog.info(DOMAIN, TAG, 'saveBytes ok uri=%{public}s', target);
      return { status: 'ok', uri: target, error: '' };
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      const msg: string = err.message === undefined ? '' : err.message;
      hilog.error(DOMAIN, TAG, 'saveBytes failed code=%{public}s msg=%{public}s',
        err.code === undefined ? '' : err.code.toString(), msg);
      return { status: 'error', uri: target, error: msg.length > 0 ? msg : 'save failed' };
    }
  }

  /** 是否是用户取消（错误码 + 消息两种线索；都拿不到就按失败处理，不吞错）。 */
  private static isCancel(err: BusinessError): boolean {
    if (err.code !== undefined && err.code === PICKER_CANCEL_CODE) {
      return true;
    }
    const msg: string = err.message === undefined ? '' : err.message;
    return msg.toLowerCase().indexOf('cancel') >= 0;
  }

  /** 文件大小（字节）；取不到 0（供导入配额/展示用）。 */
  static statOf(uri: string): number {
    return FileHelper.sizeOf(uri);
  }

  /**
   * 把 picker 选中的 uri 拷贝到应用沙箱（字体导入 / 纸纹导入都要先落到可读路径）。
   * @returns 沙箱绝对路径；失败 null。
   */
  static copyToSandbox(ctx: common.UIAbilityContext, uri: string, subDir: string):
    Promise<string | null> {
    return new Promise<string | null>((resolve: (v: string | null) => void) => {
      try {
        const dir: string = ctx.filesDir + '/' + IMPORT_DIR +
          (subDir.length > 0 ? '/' + subDir : '');
        if (!fs.accessSync(dir)) {
          fs.mkdirSync(dir, true);
        }
        const name: string = FileHelper.nameOf(uri);
        const dest: string = dir + '/' + Date.now().toString() + '-' + name;
        fs.copyFileSync(uri, dest);
        resolve(dest);
      } catch (e) {
        const err: BusinessError = e as BusinessError;
        hilog.error(DOMAIN, TAG, 'copyToSandbox failed code=%{public}s msg=%{public}s',
          err.code === undefined ? '' : err.code.toString(),
          err.message === undefined ? '' : err.message);
        resolve(null);
      }
    });
  }
}