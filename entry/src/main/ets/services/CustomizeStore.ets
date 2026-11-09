/**
 * 回车 · 自定义偏好读写（第 2 批 F3）。
 *
 * 只做 prefs 读写（services/AppPreferences 的 PrefKeys），**不写任何业务 UI、不做渲染决策**。
 * 纯逻辑（clamp／JSON 解析／去重／预设补默认值）全在 model/CustomizeCore.ets（可 Node 单测）；
 * 本文件只被 customize-static 测试做代码断言。
 *
 * 所有 get 失败／坏 JSON 一律回落默认，不抛（prefs 未初始化时 AppPreferences 走内存默认值）。
 */

import { appPreferences, PrefKeys } from './AppPreferences';
import { findPaper, PaperSpec } from '../model/MachineCatalog';
import { PaperKind } from '../model/DocModel';
import {
  ImportedFont, PaperPreset, clampFontSize, fontListOf, fontListToJson, hexColorOr,
  presetAdd, presetOf, presetRemove, presetsOf,
} from '../model/CustomizeCore';
import {
  CANDIDATE_COUNT_DEFAULT, CANDIDATE_SIZE_DEFAULT, clampCandidateCount, clampCandidateSize,
} from '../model/CandidateCore';

/** 某张纸当前生效的自定义值（未设置的字段已回落 catalog 默认值）。 */
export interface PaperValues {
  color: string;
  ruled: boolean;
  marginH: number;
  marginT: number;
  marginB: number;
  texture: string;
}

// prefs 键的 field 段（不是完整键；完整键一律经 PrefKeys 生成，不裸写 'custom.*'）。
const FIELD_FAMILY: string = 'family';
const FIELD_SIZE: string = 'size';
const FIELD_COLOR: string = 'color';
const FIELD_RULED: string = 'ruled';
const FIELD_MARGIN_H: string = 'marginH';
const FIELD_MARGIN_T: string = 'marginT';
const FIELD_MARGIN_B: string = 'marginB';
const FIELD_TEXTURE: string = 'texture';

/** 自定义值的唯一读写入口（全静态，无状态）。 */
export class CustomizeStore {
  // ---- 每机字体（M-1：渲染唯一来源）----

  /** 某台机的字体族名；未设置返回 ''（下游用它回落该机的默认字体）。 */
  static fontFamily(machine: string): string {
    return appPreferences.getString(PrefKeys.customFont(machine, FIELD_FAMILY), '');
  }

  static setFontFamily(machine: string, familyName: string): void {
    appPreferences.setString(PrefKeys.customFont(machine, FIELD_FAMILY), familyName);
  }

  /** 某台机的用户覆盖字号；键不存在／非法返回 0（0 = 沿用 measureStage 现算值，B-3）。 */
  static fontSize(machine: string): number {
    const v: number = appPreferences.getNumber(PrefKeys.customFont(machine, FIELD_SIZE), 0);
    return v <= 0 ? 0 : clampFontSize(v);
  }

  static setFontSize(machine: string, size: number): void {
    appPreferences.setNumber(PrefKeys.customFont(machine, FIELD_SIZE), size <= 0 ? 0 : clampFontSize(size));
  }

  // ---- 导入字体列表（B-2 冷启动重注册的数据源）----

  static importedFonts(): ImportedFont[] {
    return fontListOf(appPreferences.getString(PrefKeys.CUSTOM_FONT_IMPORTED, ''));
  }

  static setImportedFonts(list: ImportedFont[]): void {
    appPreferences.setString(PrefKeys.CUSTOM_FONT_IMPORTED, fontListToJson(list));
  }

  // ---- 纸张（M-3：custom.paper.<paperKind>.<field>）----

  /** 某张纸的自定义值；未设置的字段回落 findPaper(paperKind) 的现值（默认像素不变）。 */
  static paper(paperKind: string): PaperValues {
    const base: PaperSpec = findPaper(paperKind as PaperKind);
    const color: string = hexColorOr('',
      appPreferences.getString(PrefKeys.customPaperOf(paperKind, FIELD_COLOR), ''));
    const ruled: boolean = appPreferences.getBool(
      PrefKeys.customPaperOf(paperKind, FIELD_RULED), base.hasRuledGrid);
    const mh: number = appPreferences.getNumber(PrefKeys.customPaperOf(paperKind, FIELD_MARGIN_H), 0);
    const mt: number = appPreferences.getNumber(PrefKeys.customPaperOf(paperKind, FIELD_MARGIN_T), 0);
    const mb: number = appPreferences.getNumber(PrefKeys.customPaperOf(paperKind, FIELD_MARGIN_B), 0);
    return {
      color: color,
      ruled: ruled,
      marginH: mh > 0 ? mh : base.marginH,
      marginT: mt > 0 ? mt : base.marginTop,
      marginB: mb > 0 ? mb : base.marginBottom,
      texture: appPreferences.getString(PrefKeys.customPaperOf(paperKind, FIELD_TEXTURE), ''),
    };
  }

  static setPaperColor(paperKind: string, color: string): void {
    appPreferences.setString(PrefKeys.customPaperOf(paperKind, FIELD_COLOR), hexColorOr('', color));
  }

  static setPaperRuled(paperKind: string, on: boolean): void {
    appPreferences.setBool(PrefKeys.customPaperOf(paperKind, FIELD_RULED), on);
  }

  /** 边距写入：调用方已按 isTablet 用 CustomizeCore.clampMargin* clamp；≤0 视为未设置。 */
  static setPaperMarginH(paperKind: string, v: number): void {
    appPreferences.setNumber(PrefKeys.customPaperOf(paperKind, FIELD_MARGIN_H), v > 0 ? v : 0);
  }

  static setPaperMarginT(paperKind: string, v: number): void {
    appPreferences.setNumber(PrefKeys.customPaperOf(paperKind, FIELD_MARGIN_T), v > 0 ? v : 0);
  }

  static setPaperMarginB(paperKind: string, v: number): void {
    appPreferences.setNumber(PrefKeys.customPaperOf(paperKind, FIELD_MARGIN_B), v > 0 ? v : 0);
  }

  static setPaperTexture(paperKind: string, path: string): void {
    appPreferences.setString(PrefKeys.customPaperOf(paperKind, FIELD_TEXTURE), path);
  }

  /** 预设名称列表（插入序）；坏 JSON 返回空。 */
  static presets(): string[] {
    return presetsOf(appPreferences.getString(PrefKeys.CUSTOM_PAPER_PRESETS, '{}'));
  }

  static preset(name: string): PaperPreset | null {
    return presetOf(appPreferences.getString(PrefKeys.CUSTOM_PAPER_PRESETS, '{}'), name);
  }

  /** 保存／覆盖一张预设；空名不写。 */
  static savePreset(name: string, preset: PaperPreset): void {
    const n: string = name.trim();
    if (n.length === 0) {
      return;
    }
    const raw: string = appPreferences.getString(PrefKeys.CUSTOM_PAPER_PRESETS, '{}');
    appPreferences.setString(PrefKeys.CUSTOM_PAPER_PRESETS, presetAdd(raw, n, preset));
  }

  static deletePreset(name: string): void {
    const n: string = name.trim();
    if (n.length === 0) {
      return;
    }
    const raw: string = appPreferences.getString(PrefKeys.CUSTOM_PAPER_PRESETS, '{}');
    appPreferences.setString(PrefKeys.CUSTOM_PAPER_PRESETS, presetRemove(raw, n));
  }

  // ---- 候选栏（F15；clamp 与 CandidateCore 同一实现）----

  static candidateCount(): number {
    return clampCandidateCount(
      appPreferences.getNumber(PrefKeys.CUSTOM_CANDIDATE_COUNT, CANDIDATE_COUNT_DEFAULT));
  }

  static candidateSize(): number {
    return clampCandidateSize(
      appPreferences.getNumber(PrefKeys.CUSTOM_CANDIDATE_SIZE, CANDIDATE_SIZE_DEFAULT));
  }

  static setCandidateCount(n: number): void {
    appPreferences.setNumber(PrefKeys.CUSTOM_CANDIDATE_COUNT, clampCandidateCount(n));
  }

  static setCandidateSize(n: number): void {
    appPreferences.setNumber(PrefKeys.CUSTOM_CANDIDATE_SIZE, clampCandidateSize(n));
  }

  // ---- 产品开关（M-14：开发期默认 off，静态验收全过后批末改 on；移除点＝第 8 轮）----

  static enabled(): boolean {
    return appPreferences.getBool(PrefKeys.CUSTOM_ENABLED, true);
  }
}
