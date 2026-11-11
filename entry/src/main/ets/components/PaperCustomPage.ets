/**
 * 回车 · 纸张自定义页（第 2 批 F3，§2.10 沉浸式）。
 *
 * 色板（CustomizeCore.PAPER_COLORS）／横线开关／边距三滑杆（手机与平板两套范围，
 * isTablet 由 widthVp ≥ 600 判断）／纸纹导入（FileHelper.pickImage → copyToSandbox('paper')）
 * ／预设保存与删除（行内 TextInput，不求精致）。
 *
 * 小样预览只用 PaperStage（评审 M-2：PaperSheet 自带 1.7 行高是死代码，不能当预览）。
 * 未设置的字段回落 catalog 现值（CustomizeStore.paper），默认像素不变。
 */

import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PaperKind } from '../model/DocModel';
import { PaperRow } from '../ui/PaperSheet';
import { PageShell } from './PageShell';
import { SettingsRow } from './SettingsRow';
import { PaperStage } from './PaperStage';
import { SpotlightStep } from './SpotlightOverlay';
import { PickedFile, FileHelper } from '../services/FileHelper';
import { CustomizeStore, PaperValues } from '../services/CustomizeStore';
import {
  PaperPreset, PAPER_COLORS, clampMarginH, clampMarginT, clampMarginB,
  MARGIN_PHONE_H_MIN, MARGIN_PHONE_H_MAX, MARGIN_PHONE_T_MIN, MARGIN_PHONE_T_MAX,
  MARGIN_PHONE_B_MIN, MARGIN_PHONE_B_MAX, MARGIN_TABLET_H_MIN, MARGIN_TABLET_H_MAX,
  MARGIN_TABLET_T_MIN, MARGIN_TABLET_T_MAX, MARGIN_TABLET_B_MIN, MARGIN_TABLET_B_MAX,
} from '../model/CustomizeCore';

const DOMAIN: number = 0x0000;
const TAG: string = 'PaperCustomPage';
/** 错误种类：0 无 / 1 上下文缺失 / 2 拷贝失败 / 3 其他异常。 */
const ERR_NONE: number = 0;
const ERR_CTX: number = 1;
const ERR_COPY: number = 2;
const ERR_GENERIC: number = 3;
/** 平板判定阈值（vp）：≥600 视作平板（与 Index 同口径）。 */
const TABLET_MIN_WIDTH_VP: number = 600;

@Component
export struct PaperCustomPage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  /** 当前编辑的纸张（小写 paperKind，与 PaperKind 枚举值一致）。 */
  @Prop paperKind: string = 'letter';

  @State color: string = '';
  @State ruled: boolean = false;
  @State marginH: number = 48;
  @State marginT: number = 24;
  @State marginB: number = 20;
  @State texture: string = '';
  @State presetNames: string[] = [];
  @State presetDraft: string = '';
  @State errKind: number = 0;
  @State importBusy: boolean = false;
  @State pressedKey: string = '';
  /** 小样预览行（PaperStage 只读）。 */
  @State previewRows: PaperRow[] = [
    { line: 0, text: 'The quick brown fox', ribbon: 'black', active: false },
  ];
  onBack: () => void = (): void => {};

  aboutToAppear(): void {
    const v: PaperValues = CustomizeStore.paper(this.paperKind);
    this.color = v.color;
    this.ruled = v.ruled;
    this.marginH = v.marginH;
    this.marginT = v.marginT;
    this.marginB = v.marginB;
    this.texture = v.texture;
    this.presetNames = CustomizeStore.presets();
  }

  private isTablet(): boolean {
    return this.widthVp >= TABLET_MIN_WIDTH_VP;
  }

  // 边距滑杆范围（手机／平板两套，值全部来自 CustomizeCore 常量）
  private hMin(): number {
    return this.isTablet() ? MARGIN_TABLET_H_MIN : MARGIN_PHONE_H_MIN;
  }

  private hMax(): number {
    return this.isTablet() ? MARGIN_TABLET_H_MAX : MARGIN_PHONE_H_MAX;
  }

  private tMin(): number {
    return this.isTablet() ? MARGIN_TABLET_T_MIN : MARGIN_PHONE_T_MIN;
  }

  private tMax(): number {
    return this.isTablet() ? MARGIN_TABLET_T_MAX : MARGIN_PHONE_T_MAX;
  }

  private bMin(): number {
    return this.isTablet() ? MARGIN_TABLET_B_MIN : MARGIN_PHONE_B_MIN;
  }

  private bMax(): number {
    return this.isTablet() ? MARGIN_TABLET_B_MAX : MARGIN_PHONE_B_MAX;
  }

  /** 纸纹文件名（取沙箱路径末段）。 */
  private textureName(): string {
    const p: string = this.texture;
    const slash: number = p.lastIndexOf('/');
    return slash >= 0 ? p.substring(slash + 1) : p;
  }

  /**
   * 滑杆显示值：默认边距来自 catalog（如 48）可能超出手机档范围（24–40），
   * 只把**显示**值收进范围，不写 prefs——默认像素与默认值保持不变。
   */
  private sliderValue(v: number, min: number, max: number): number {
    if (v < min) {
      return min;
    }
    if (v > max) {
      return max;
    }
    return v;
  }

  /** 当前错误提示；无错误返回空串。 */
  private errorText(): ResourceStr {
    if (this.errKind === ERR_CTX) {
      return $r('app.string.paper_error_texture');
    }
    if (this.errKind === ERR_COPY) {
      return $r('app.string.paper_error_texture');
    }
    if (this.errKind === ERR_GENERIC) {
      return $r('app.string.paper_error_texture');
    }
    return '';
  }

  /** 导入一张纸纹图片：picker → 沙箱 'paper' 子目录 → 存 prefs（预览立即生效）。 */
  private async importTexture(): Promise<void> {
    if (this.importBusy) {
      return;
    }
    this.importBusy = true;
    this.errKind = ERR_NONE;
    try {
      const host = this.getUIContext().getHostContext();
      if (host === undefined || host === null) {
        this.errKind = ERR_CTX;
        return;
      }
      const ctx: common.UIAbilityContext = host as common.UIAbilityContext;
      const picked: PickedFile | null = await FileHelper.pickImage(ctx);
      if (picked === null) {
        return; // 用户取消
      }
      const dest: string | null = await FileHelper.copyToSandbox(ctx, picked.uri, 'paper');
      if (dest === null) {
        this.errKind = ERR_COPY;
        return;
      }
      this.texture = dest;
      CustomizeStore.setPaperTexture(this.paperKind, dest);
      hilog.info(DOMAIN, TAG, 'texture imported name=%{public}s', picked.name);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'texture import failed: %{public}s', JSON.stringify(e));
      this.errKind = ERR_GENERIC;
    } finally {
      this.importBusy = false;
    }
  }

  /** 保存当前设置为预设（空名不存）。 */
  private savePreset(): void {
    const name: string = this.presetDraft.trim();
    if (name.length === 0) {
      return;
    }
    const preset: PaperPreset = {
      color: this.color,
      ruled: this.ruled,
      marginH: this.marginH,
      marginT: this.marginT,
      marginB: this.marginB,
      texture: this.texture,
    };
    CustomizeStore.savePreset(name, preset);
    this.presetNames = CustomizeStore.presets();
    this.presetDraft = '';
  }

  private deletePreset(name: string): void {
    CustomizeStore.deletePreset(name);
    this.presetNames = CustomizeStore.presets();
  }

  @Builder
  sectionLabel(t: Resource) {
    Text(t)
      .fontSize(12)
      .fontColor('rgba(232,221,201,0.6)')
      .width('100%')
      .margin({ top: 18, bottom: 6 })
  }

  @Builder
  body() {
    Scroll() {
      Column() {
        // 小样预览（只用 PaperStage；降低高度，避免挡住下面的编辑区）
        Row() {
          Column() {
            PaperStage({
              regionHeightVp: 210,
              paperHeightVp: 210,
              paperKind: this.paperKind as PaperKind,
              hasHeader: false,
              hasRuledGrid: this.ruled,
              rows: this.previewRows,
              hintText: '',
              lineHeightVp: 28,
              fontSizeVp: 17,
              fontFamily: 'CourierPrime',
              marginHVp: this.marginH,
              marginTopVp: this.marginT,
              marginBottomVp: this.marginB,
              headerBandVp: 20,
              inkColor: '#1a1a1a',
              pageNo: 1,
              cursorVisible: false,
              visibleBottomVp: 0,
              offsetXVp: 0,
              paperColor: this.color,
              texturePath: this.texture,
            })
          }
          .width(260)
          .height(210)
        }
        .width('100%')
        .height(220)
        .justifyContent(FlexAlign.Center)

        // 颜色
        this.sectionLabel($r('app.string.paper_color'))
        Row() {
          ForEach(PAPER_COLORS, (c: string) => {
            Column()
              .width(44)
              .height(44)
              .borderRadius(8)
              .backgroundColor(c)
              .border({ width: this.color === c ? 2 : 0, color: '#c9a45c' })
              .margin({ right: 10 })
              .onClick(() => {
                this.color = c;
                CustomizeStore.setPaperColor(this.paperKind, c);
              })
          }, (c: string) => c)
        }
        .width('100%')
        .height(48)

        // 横线
        Row() {
          Text($r('app.string.paper_ruled')).fontSize(15).fontColor('#e8ddc9')
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.ruled })
            .selectedColor('#c9a45c')
            .onChange((on: boolean) => {
              if (on !== this.ruled) {
                this.ruled = on;
                CustomizeStore.setPaperRuled(this.paperKind, on);
              }
            })
        }
        .width('100%')
        .height(52)
        Column().width('100%').height(1).backgroundColor('rgba(232,221,201,0.12)')

        // 三个边距滑杆（SettingsRow 的 label 是 string，故标题用资源行、行内 label 留空）
        this.sectionLabel($r('app.string.paper_margin_h'))
        SettingsRow({
          label: '',
          mode: 'slider',
          sliderValue: this.sliderValue(this.marginH, this.hMin(), this.hMax()),
          sliderMin: this.hMin(),
          sliderMax: this.hMax(),
          sliderStep: 1,
          onSlide: (v: number): void => {
            const c: number = clampMarginH(this.isTablet(), v);
            this.marginH = c;
            CustomizeStore.setPaperMarginH(this.paperKind, c);
          },
        })
        Column().width('100%').height(1).backgroundColor('rgba(232,221,201,0.12)')

        this.sectionLabel($r('app.string.paper_margin_t'))
        SettingsRow({
          label: '',
          mode: 'slider',
          sliderValue: this.sliderValue(this.marginT, this.tMin(), this.tMax()),
          sliderMin: this.tMin(),
          sliderMax: this.tMax(),
          sliderStep: 1,
          onSlide: (v: number): void => {
            const c: number = clampMarginT(this.isTablet(), v);
            this.marginT = c;
            CustomizeStore.setPaperMarginT(this.paperKind, c);
          },
        })
        Column().width('100%').height(1).backgroundColor('rgba(232,221,201,0.12)')

        this.sectionLabel($r('app.string.paper_margin_b'))
        SettingsRow({
          label: '',
          mode: 'slider',
          sliderValue: this.sliderValue(this.marginB, this.bMin(), this.bMax()),
          sliderMin: this.bMin(),
          sliderMax: this.bMax(),
          sliderStep: 1,
          onSlide: (v: number): void => {
            const c: number = clampMarginB(this.isTablet(), v);
            this.marginB = c;
            CustomizeStore.setPaperMarginB(this.paperKind, c);
          },
        })
        Column().width('100%').height(1).backgroundColor('rgba(232,221,201,0.12)')

        // 纸纹导入
        this.sectionLabel($r('app.string.paper_texture'))
        Row() {
          Text($r('app.string.paper_texture_import')).fontSize(15).fontColor('#c9a45c')
            .opacity(this.importBusy ? 0.5 : 1)
          Blank()
          if (this.texture.length > 0) {
            Text(this.textureName())
              .fontSize(12)
              .fontColor('rgba(232,221,201,0.6)')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width(160)
          }
        }
        .width('100%')
        .height(52)
        .scale({ x: this.pressedKey === 'texture' ? 0.97 : 1,
          y: this.pressedKey === 'texture' ? 0.97 : 1 })
        .animation({ duration: 120, curve: Curve.EaseOut })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
            this.pressedKey = 'texture';
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.pressedKey = '';
          }
        })
        .onClick(() => { this.importTexture(); })
        Column().width('100%').height(1).backgroundColor('rgba(232,221,201,0.12)')

        // 预设：保存 + 列表删除
        this.sectionLabel($r('app.string.paper_preset_save'))
        Row() {
          TextInput({ text: this.presetDraft })
            .fontSize(15)
            .fontColor('#e8ddc9')
            .placeholderColor('rgba(232,221,201,0.4)')
            .backgroundColor('#241c16')
            .layoutWeight(1)
            .onChange((v: string) => { this.presetDraft = v; })
          Text($r('app.string.paper_preset_save'))
            .fontSize(14)
            .fontColor('#c9a45c')
            .margin({ left: 10 })
            .onClick(() => { this.savePreset(); })
        }
        .width('100%')
        .height(52)

        ForEach(this.presetNames, (n: string) => {
          Row() {
            Text(n)
              .fontSize(15)
              .fontColor('#e8ddc9')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text($r('app.string.paper_preset_delete'))
              .fontSize(13)
              .fontColor('#a33327')
              .onClick(() => { this.deletePreset(n); })
          }
          .width('100%')
          .height(48)
        }, (n: string) => n)

        // 错误行（无错误不渲染）
        if (this.errKind !== ERR_NONE) {
          Text(this.errorText())
            .fontSize(12)
            .fontColor('#a33327')
            .width('100%')
            .margin({ top: 8 })
        }
        Column().width('100%').height(24)
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
    }
    .layoutWeight(1)
    .width('100%')
    .id('paper_custom__controls')
    .scrollBar(BarState.Off)
  }

  build() {
    PageShell({
        guidePage: 'paper_custom',
      widthVp: this.widthVp,
      heightVp: this.heightVp,
      title: $r('app.string.paper_custom_title'),
      onBack: (): void => { this.onBack(); },
      subtitle: $r('app.string.guide_paper_custom_hint'),
      showSubtitle: true,
      content: (): void => { this.body() },
    })
  }
}

/** 纸张自定义页首次引导（与功能同处一源；文案键见 string.json）。 */
export function guideStepsForPaperCustom(): SpotlightStep[] {
  return [
    { text: $r('app.string.guide_paper_custom_1'), anchorId: 'paper_custom__controls' },
    { text: $r('app.string.guide_paper_custom_2'), anchorId: 'paper_custom__texture_import' },
    { text: $r('app.string.guide_paper_custom_3'), anchorId: 'paper_custom__preset' },
  ];
}
