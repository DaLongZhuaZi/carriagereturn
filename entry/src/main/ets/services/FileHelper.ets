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

const DOMAIN: number = 0x0000;
const TAG: string = 'FileHelper';
/** 导入文件落到应用沙箱的子目录（相对 filesDir）。 */
const IMPORT_DIR: string = 'imports';

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
   * 让用户选保存位置并写入字节。
   * @returns 写入成功的 uri；用户取消或失败返回 null。
   */
  static async saveBytes(ctx: common.UIAbilityContext, suggestedName: string, mime: string,
    data: ArrayBuffer | string): Promise<string | null> {
    try {
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(ctx);
      const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      options.newFileNames = [suggestedName];
      if (mime.length > 0) {
        options.fileSuffixChoices = [mime];
      }
      const uris: string[] = await documentPicker.save(options);
      if (uris === undefined || uris.length === 0) {
        return null;
      }
      const target: string = uris[0];
      const file: fs.File = fs.openSync(target,
        fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(file.fd, data);
      } finally {
        fs.closeSync(file);
      }
      hilog.info(DOMAIN, TAG, 'saveBytes ok uri=%{public}s', target);
      return target;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'saveBytes failed code=%{public}s msg=%{public}s',
        err.code === undefined ? '' : err.code.toString(),
        err.message === undefined ? '' : err.message);
      return null;
    }
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