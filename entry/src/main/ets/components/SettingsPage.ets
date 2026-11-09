/**
 * 回车 · 设置页（§6.1）— 已接入共享 PageShell（D2）
 *
 * 6 组分组列表（声音 / 触感 / 修正方式 / 统计 / 默认 / 关于），组标题 12vp 灰，
 * 行高 52vp、1vp 分割线、左右 20vp；入场按组 60ms 逐组淡入（D6）。
 *
 * 第 6 批 F6（M-11 resolve）：所有开关／滑杆／链接行一律走 SettingsRow
 * （switch／slider／link／value）；手写 Row 只留纯展示（音效致谢／版本／底部离线声明）。
 * 本页**不写盘**：开关、音量、删除方式、默认机纸都由 Index 持久化后以 props 回传，
 * 保证"当前值＝默认值"回显（M-3）。
 *
 * 删除方式三档用稳定 id `'direct' | 'ask' | 'trash'`（N-1），显示走资源键；
 * 点击循环 direct → ask → trash → direct；非法 id 一律按 trash 显示（回落口径在 SettingsCore）。
 *
 * 候选栏两行已迁到 PinyinSettingsPage（M-1）：本页不再收 candidate props。
 */

import { PageShell } from './PageShell';
import { SettingsRow } from './SettingsRow';
import { GuideStep } from './GuideOverlay';
import { clampDailyGoal } from '../model/StatsCore';
import { DELETE_MODE_DIRECT, DELETE_MODE_ASK, deleteModeOf, nextDeleteMode } from '../model/SettingsCore';
import { common } from '@kit.AbilityKit';

@Component
export struct SettingsPage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  @Prop machineLabel: string = '1920s';
  @Prop paperLabel: string = '信纸';
  /** 中文输入引擎：'builtin' 内置拼音｜'system' 系统输入法（设计稿 §1）。 */
  @Prop cnEngine: string = 'builtin';
  /** 第 4 批 F11：每日目标字数（100–2000，step 100；Index 持久化后回传）。 */
  @Prop dailyGoal: number = 500;
  /** F6：音量百分数 0–100（AppPreferences VOLUME 0..1 的百分数；Index 持久化后回传）。 */
  @Prop volume0to100: number = 70;
  /** F6：音效总开关（SOUND_ENABLED）；行名"音效"＝全关/全开，不再暗示只关叮声（M-2）。 */
  @Prop soundEnabled: boolean = true;
  /** F6：按键震动（VIBRATION_ENABLED）。 */
  @Prop vibrationEnabled: boolean = true;
  /** F6：删除方式稳定 id 'direct'|'ask'|'trash'（缺省进回收站）。 */
  @Prop deleteMode: string = 'trash';
  onGoal: (n: number) => void = (n: number): void => {};
  onPickCnEngine: () => void = (): void => {};
  /** §11.6：拼音设置页入口 */
  onOpenPinyinSettings: () => void = (): void => {};
  /** 第 1 批：重播引导（页面引导 / 启动引导） */
  onReplayPageGuide: () => void = (): void => {};
  onReplayOnboarding: () => void = (): void => {};
  /** F6：真实写盘与生效都在 Index（本页只发意图）。 */
  onToggleSound: () => void = (): void => {};
  onToggleVibrate: () => void = (): void => {};
  onVolume: (v0to100: number) => void = (v0to100: number): void => {};
  onDeleteMode: (mode: string) => void = (mode: string): void => {};
  onPickMachine: () => void = (): void => {};
  onPickPaper: () => void = (): void => {};
  onOpenTrash: () => void = (): void => {};
  @State revealN: number = 0;
  onBack: () => void = (): void => {};

  aboutToAppear(): void {
    // D6：逐组 60ms（第 4 批加入"统计"组，第 6 批仍为 6 组：声音/触感/修正方式/统计/默认/关于）
    this.revealN = 0;
    for (let i = 0; i < 6; i++) {
      setTimeout(() => { this.revealN = i + 1; }, i * 60);
    }
  }

  /** 删除方式显示：稳定 id → 资源键 → 本地化字符串（SettingsRow.value 是 string）。 */
  private deleteModeText(): string {
    const m: string = deleteModeOf(this.deleteMode);
    if (m === DELETE_MODE_DIRECT) {
      return this.resolveString($r('app.string.delete_mode_direct'));
    }
    if (m === DELETE_MODE_ASK) {
      return this.resolveString($r('app.string.delete_mode_ask'));
    }
    return this.resolveString($r('app.string.delete_mode_trash'));
  }

  /** 点击循环 direct → ask → trash → direct（口径在 SettingsCore，页面不重写一套）。 */
  private nextMode(): string {
    return nextDeleteMode(this.deleteMode);
  }

  /** Resource → 本地化字符串（与 ExportPage／Index 的 resolveString 同口径；失败降级空串）。 */
  private resolveString(res: Resource): string {
    try {
      const ctx: common.UIAbilityContext | null = this.hostCtx();
      if (ctx !== null) {
        return ctx.resourceManager.getStringSync(res.id);
      }
    } catch (e) {
      // 资源缺失降级空串
    }
    return '';
  }

  private hostCtx(): common.UIAbilityContext | null {
    const host = this.getUIContext().getHostContext();
    if (host === undefined || host === null) {
      return null;
    }
    return host as common.UIAbilityContext;
  }

  @Builder
  groupTitle(t: string) {
    Text(t).fontSize(12).fontColor('rgba(232,221,201,0.4)')
      .width('100%').margin({ top: 24, bottom: 6 })
  }

  @Builder
  divider() {
    Column().width('100%').height(1).backgroundColor('rgba(232,221,201,0.4)')
  }

  @Builder
  body() {
    Scroll() {
      Column() {
        // 1 声音（音效总开关＋音量；M-2：行名"音效"，不叫"换行叮声"）
        Column() {
          this.groupTitle('声音')
          SettingsRow({
            label: $r('app.string.settings_sound'),
            mode: 'switch',
            switchOn: this.soundEnabled,
            onToggle: (): void => { this.onToggleSound(); },
          })
          this.divider()
          SettingsRow({
            label: '音量',
            mode: 'slider',
            sliderValue: this.volume0to100,
            sliderMin: 0,
            sliderMax: 100,
            sliderStep: 1,
            sliderValueText: this.volume0to100.toString() + '%',
            onSlide: (v: number): void => { this.onVolume(Math.round(v)); },
          })
        }
        .width('100%')
        .opacity(this.revealN > 0 ? 1 : 0)
        .animation({ duration: 180, curve: Curve.EaseOut })

        // 2 触感
        Column() {
          this.groupTitle('触感')
          SettingsRow({
            label: '按键震动',
            mode: 'switch',
            switchOn: this.vibrationEnabled,
            onToggle: (): void => { this.onToggleVibrate(); },
          })
        }
        .width('100%')
        .opacity(this.revealN > 1 ? 1 : 0)
        .animation({ duration: 180, curve: Curve.EaseOut })

        // 3 修正方式（删除方式三档／中文输入／拼音设置）
        Column() {
          this.groupTitle('修正方式')
          SettingsRow({
            label: $r('app.string.settings_delete_mode'),
            mode: 'value',
            value: this.deleteModeText(),
            onRowClick: (): void => { this.onDeleteMode(this.nextMode()); },
          })
          this.divider()
          // 中文输入：内置拼音（默认）｜系统输入法。必须落 AppPreferences（设计稿 §1／§7）
          SettingsRow({
            label: '中文输入',
            mode: 'value',
            value: this.cnEngine === 'builtin' ? '内置拼音' : '系统输入法',
            onRowClick: (): void => { this.onPickCnEngine(); },
          })
          this.divider()
          // 拼音设置（模糊音／我的词库／学习记录／词库信息）：设计稿 §11.6
          SettingsRow({
            label: '拼音设置',
            mode: 'link',
            value: '',
            onRowClick: (): void => { this.onOpenPinyinSettings(); },
          })
        }
        .width('100%')
        .opacity(this.revealN > 2 ? 1 : 0)
        .animation({ duration: 180, curve: Curve.EaseOut })

        // 4 统计（第 4 批 F11：每日目标；100–2000 步进 100，滑杆左侧回显"X 字"）
        Column() {
          this.groupTitle('统计')
          SettingsRow({
            label: $r('app.string.settings_goal'),
            mode: 'slider',
            sliderValue: this.dailyGoal,
            sliderMin: 100,
            sliderMax: 2000,
            sliderStep: 100,
            // N-1：SettingsRow 的 sliderValueText 是 string prop，$r 不能拼字符串，故这里用拼接
            sliderValueText: this.dailyGoal.toString() + ' 字',
            onSlide: (v: number): void => {
              this.onGoal(clampDailyGoal(Math.round(v), this.dailyGoal));
            },
          })
        }
        .width('100%')
        .opacity(this.revealN > 3 ? 1 : 0)
        .animation({ duration: 180, curve: Curve.EaseOut })

        // 5 默认（M-3：选择即生效、行回显当前值＝默认值；回收站入口同组）
        Column() {
          this.groupTitle('默认')
          SettingsRow({
            label: $r('app.string.settings_default_machine'),
            mode: 'link',
            value: this.machineLabel,
            onRowClick: (): void => { this.onPickMachine(); },
          })
          this.divider()
          SettingsRow({
            label: $r('app.string.settings_default_paper'),
            mode: 'link',
            value: this.paperLabel,
            onRowClick: (): void => { this.onPickPaper(); },
          })
          this.divider()
          SettingsRow({
            label: $r('app.string.settings_trash'),
            mode: 'link',
            value: '',
            onRowClick: (): void => { this.onOpenTrash(); },
          })
        }
        .width('100%')
        .opacity(this.revealN > 4 ? 1 : 0)
        .animation({ duration: 180, curve: Curve.EaseOut })

        // 6 关于（重播引导两行＋音效致谢＋版本；后两行是纯展示，保留手写 Row）
        Column() {
          this.groupTitle('关于')
          SettingsRow({
            label: '重播页面引导',
            mode: 'link',
            value: '',
            onRowClick: (): void => { this.onReplayPageGuide(); },
          })
          this.divider()
          SettingsRow({
            label: '重播启动引导',
            mode: 'link',
            value: '',
            onRowClick: (): void => { this.onReplayOnboarding(); },
          })
          this.divider()
          Row() {
            Text('音效致谢').fontSize(15).fontColor('#e8ddc9')
            Blank()
            Text($r('app.string.sound_credit'))
              .fontSize(12).fontColor('rgba(232,221,201,0.6)')
              .maxLines(2).textAlign(TextAlign.End).layoutWeight(1)
              .margin({ left: 12 })
          }.width('100%').height(52)
          this.divider()
          Row() {
            Text('版本').fontSize(15).fontColor('#e8ddc9')
            Blank()
            Text('1.0.0').fontSize(15).fontColor('rgba(232,221,201,0.4)')
          }.width('100%').height(52)

          Column().width('100%').height(24)
        }
        .width('100%')
        .opacity(this.revealN > 5 ? 1 : 0)
        .animation({ duration: 180, curve: Curve.EaseOut })

        // 底部常驻声明（§6.1）
        Text('完全离线：文档与按键数据只存本地，不收集、不上传。')
          .fontSize(12).fontColor('rgba(232,221,201,0.4)')
          .width('100%').textAlign(TextAlign.Center)
          .margin({ top: 8, bottom: 10 })
      }
      .width('100%').padding({ left: 20, right: 20 })
    }
    .width('100%').height('100%').scrollBar(BarState.Off)
  }

  build() {
    PageShell({
      widthVp: this.widthVp,
      heightVp: this.heightVp,
      title: $r('app.string.page_settings'),
      onBack: () => { this.onBack(); },
      subtitle: $r('app.string.guide_settings_hint'),
      showSubtitle: true,
      content: (): void => { this.body() },
    })
  }
}

/** Settings 页首次引导（与功能同处一源；文案键见 string.json）。 */
export function guideStepsForSettings(): GuideStep[] {
  return [
    { text: $r('app.string.guide_settings_1') },
    { text: $r('app.string.guide_settings_2') },
    { text: $r('app.string.guide_settings_3') },
  ];
}