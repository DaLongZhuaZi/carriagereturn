/**
 * 回车 · 字体管理页（第 2 批 F3，§2.10 沉浸式）。
 *
 * 列表读 prefs 的导入字体（CustomizeStore.importedFonts）；
 * 导入链：FileHelper.pickFont → 扩展名/≤20MB 校验 → copyToSandbox('fonts')
 *        → FontService.registerFromFile（familyName 唯一前缀 `imp-<ts>-<name>`）
 *        → 成功/失败都入列表（status 'ok' / 'failed'）。
 * 失败行显示「未生效（设备不支持）」，不崩溃、不污染随包字体（评审 B-1／R1）。
 * 删除清 prefs 并尝试删沙箱文件（fileIo.unlinkSync，包 try/catch）。
 *
 * 探针状态：registerFont／FilePicker 均 UNVERIFIED_NO_DEVICE（按公开 API 实现）。
 */

import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PageShell } from './PageShell';
import { SpotlightStep } from './SpotlightOverlay';
import { PickedFile, FileHelper } from '../services/FileHelper';
import { FontService } from '../services/FontService';
import { MachineKind } from '../model/DocModel';
import { CustomizeStore } from '../services/CustomizeStore';
import { ImportedFont, fontListAdd, fontListOf, fontListRemove, fontListToJson, validFamilyName }
  from '../model/CustomizeCore';

const DOMAIN: number = 0x0000;
const TAG: string = 'FontManagerPage';
/** 单个字体文件上限 20MB（评审 R1：过大文件不落盘）。 */
const FONT_IMPORT_MAX_BYTES: number = 20 * 1024 * 1024;

/** 错误种类：0 无 / 1 扩展名 / 2 大小 / 3 拷贝写盘 / 4 上下文缺失 / 5 其他异常。 */
const ERR_NONE: number = 0;
const ERR_TYPE: number = 1;
const ERR_SIZE: number = 2;
const ERR_COPY: number = 3;
const ERR_CTX: number = 4;
const ERR_GENERIC: number = 5;

@Component
export struct FontManagerPage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  @State fonts: ImportedFont[] = [];
  @State errKind: number = 0;
  @State importing: boolean = false;
  @State pressedKey: string = '';
  /** 第 2 批 F3：当前机型 + 应用字体回调（把导入族名写入 custom.font.<machine>.family）。 */
  @Prop currentMachine: string = '';
  onApplyFamily: (familyName: string) => void = (familyName: string): void => {};
  onBack: () => void = (): void => {};

  aboutToAppear(): void {
    this.fonts = CustomizeStore.importedFonts();
  }

  /** 文件大小展示（KB，四舍五入；0 表示未知）。 */
  private sizeText(bytes: number): string {
    if (bytes <= 0) {
      return '0 KB';
    }
    return Math.round(bytes / 1024).toString() + ' KB';
  }

  /** 行状态文案：'ok' 已生效，其余一律「未生效（设备不支持）」。 */
  private statusText(f: ImportedFont): Resource {
    return f.status === 'ok' ? $r('app.string.font_status_ok') : $r('app.string.font_status_failed');
  }

  /** 当前错误提示（无错误返回空串，由调用方判空跳过渲染）。 */
  private errorText(): ResourceStr {
    if (this.errKind === ERR_TYPE) {
      return $r('app.string.font_error_type');
    }
    if (this.errKind === ERR_SIZE) {
      return $r('app.string.font_error_size');
    }
    if (this.errKind === ERR_COPY) {
      return $r('app.string.font_error_copy');
    }
    if (this.errKind === ERR_CTX) {
      return $r('app.string.font_error_copy');
    }
    if (this.errKind === ERR_GENERIC) {
      return $r('app.string.font_error_generic');
    }
    return '';
  }

  /**
   * 导入一次字体。取消选择＝静默返回；校验失败＝显示对应错误；注册失败仍入列表（status failed）。
   */
  private async importFont(): Promise<void> {
    if (this.importing) {
      return;
    }
    this.importing = true;
    this.errKind = ERR_NONE;
    try {
      const host = this.getUIContext().getHostContext();
      if (host === undefined || host === null) {
        this.errKind = ERR_CTX;
        return;
      }
      const ctx: common.UIAbilityContext = host as common.UIAbilityContext;

      const picked: PickedFile | null = await FileHelper.pickFont(ctx);
      if (picked === null) {
        return; // 用户取消，不算错误
      }
      const lower: string = picked.name.toLowerCase();
      const tail4: string = lower.length >= 4 ? lower.substring(lower.length - 4) : '';
      if (tail4 !== '.ttf' && tail4 !== '.otf') {
        this.errKind = ERR_TYPE;
        return;
      }
      const size: number = FileHelper.statOf(picked.uri);
      if (size > FONT_IMPORT_MAX_BYTES) {
        this.errKind = ERR_SIZE;
        return;
      }
      const dest: string | null = await FileHelper.copyToSandbox(ctx, picked.uri, 'fonts');
      if (dest === null) {
        this.errKind = ERR_COPY;
        return;
      }
      const base: string = validFamilyName(picked.name);
      const familyName: string = 'imp-' + Date.now().toString() + '-' + base;
      const ok: boolean = FontService.registerFromFile(this.getUIContext(), familyName, dest);
      const entry: ImportedFont = {
        familyName: familyName,
        path: dest,
        size: size,
        status: ok ? 'ok' : 'failed',
      };
      const mergedJson: string = fontListAdd(
        fontListToJson(CustomizeStore.importedFonts()), entry);
      this.fonts = fontListOf(mergedJson);
      CustomizeStore.setImportedFonts(this.fonts);
      hilog.info(DOMAIN, TAG, 'import done family=%{public}s ok=%{public}s size=%{public}s',
        familyName, ok ? 'true' : 'false', size.toString());
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'import failed: %{public}s', JSON.stringify(e));
      this.errKind = ERR_GENERIC;
    } finally {
      this.importing = false;
    }
  }

  /** 删除一行：先从列表移除，再尝试删沙箱文件；删文件失败不阻断列表更新。 */
  private removeFont(familyName: string): void {
    let target: string = '';
    const list: ImportedFont[] = this.fonts;
    for (let i = 0; i < list.length; i++) {
      if (list[i].familyName === familyName) {
        target = list[i].path;
      }
    }
    if (target.length > 0) {
      try {
        fileIo.unlinkSync(target);
        hilog.info(DOMAIN, TAG, 'unlink ok %{public}s', target);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'unlink failed %{public}s', target);
      }
    }
    const next: ImportedFont[] = fontListOf(
      fontListRemove(fontListToJson(list), familyName));
    this.fonts = next;
    CustomizeStore.setImportedFonts(next);
    // 第 8 批 R3：删掉的字体若正被任何一台机引用，必须把该机回退到默认字体，
    // 否则机器继续指向已删 family（真机实测：删除后打字机标签仍显示 imp-1729…）。
    const kinds: string[] = [MachineKind.UPRIGHT_1920S as string, MachineKind.PORTABLE_1930S as string,
      MachineKind.STREAMLINED_1950S as string, MachineKind.ELECTRIC_1960S as string];
    for (let i = 0; i < kinds.length; i++) {
      if (CustomizeStore.fontFamily(kinds[i]) === familyName) {
        CustomizeStore.setFontFamily(kinds[i], '');
        hilog.info(DOMAIN, TAG, 'machine %{public}s font reverted (deleted %{public}s)',
          kinds[i], familyName);
      }
    }
  }

  @Builder
  body() {
    Scroll() {
      Column() {
        // 导入入口
        Row() {
          Text($r('app.string.font_import'))
            .fontSize(15)
            .fontColor('#c9a45c')
            .opacity(this.importing ? 0.5 : 1)
          Blank()
        }
        .width('100%')
        .height(52)
        .scale({ x: this.pressedKey === 'import' ? 0.97 : 1,
          y: this.pressedKey === 'import' ? 0.97 : 1 })
        .animation({ duration: 120, curve: Curve.EaseOut })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
            this.pressedKey = 'import';
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.pressedKey = '';
          }
        })
        .onClick(() => { this.importFont(); })

        // 错误行：无错误时不渲染
        if (this.errKind !== ERR_NONE) {
          Text(this.errorText())
            .fontSize(12)
            .fontColor('#a33327')
            .width('100%')
            .margin({ bottom: 8 })
        }

        Column().width('100%').height(1).backgroundColor('rgba(232,221,201,0.12)')

        // 导入字体列表
        ForEach(this.fonts, (f: ImportedFont) => {
          Row() {
            Column() {
              Text(f.familyName)
                .fontSize(15)
                .fontColor('#e8ddc9')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
              Text(this.sizeText(f.size))
                .fontSize(12)
                .fontColor('rgba(232,221,201,0.5)')
                .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text(this.statusText(f))
              .fontSize(12)
              .fontColor(f.status === 'ok' ? 'rgba(232,221,201,0.6)' : '#a33327')
            Text($r('app.string.font_apply'))
              .fontSize(14)
              .fontColor('#c9a45c')
              .margin({ left: 12 })
              .onClick(() => { this.onApplyFamily(f.familyName); })
            Text($r('app.string.font_delete'))
              .fontSize(14)
              .fontColor('#a33327')
              .margin({ left: 14 })
              .onClick(() => { this.removeFont(f.familyName); })
          }
          .width('100%')
          .height(58)
          .padding({ left: 12, right: 12 })
          .margin({ bottom: 4 })
        }, (f: ImportedFont) => f.familyName + ':' + f.status)

        Column().width('100%').height(24)
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
  }

  build() {
    PageShell({
        guidePage: 'font_manager',
      widthVp: this.widthVp,
      heightVp: this.heightVp,
      title: $r('app.string.font_manager_title'),
      onBack: (): void => { this.onBack(); },
      subtitle: $r('app.string.guide_font_manager_hint'),
      showSubtitle: true,
      content: (): void => { this.body() },
    })
  }
}

/** 字体管理页首次引导（与功能同处一源；文案键见 string.json）。 */
export function guideStepsForFontManager(): SpotlightStep[] {
  return [
    { text: $r('app.string.guide_font_manager_1'), anchorId: 'font_manager__import_btn' },
    { text: $r('app.string.guide_font_manager_2'), anchorId: 'font_manager__list' },
    { text: $r('app.string.guide_font_manager_3'), anchorId: 'font_manager__list' },
  ];
}
