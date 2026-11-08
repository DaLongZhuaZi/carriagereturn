/**
 * 回车 · 自定义纯函数（第 2 批 F3：字体／字号／纸张）。
 *
 * 本文件**不 import 任何 @kit／服务**，只用标准 JS，可 Node `--experimental-strip-types` 直接单测
 * （见 tools/tests/customize-core.test.mjs）。I/O 一律留在 services/CustomizeStore.ets。
 *
 * 字号语义（评审 B-3）：`custom.font.<machine>.size` 是**用户覆盖值**；键不存在 → 0（占位），
 * 调用方沿用 `measureStage` 现算值。clamp 范围 12–26，不再套 17 下限。
 * 行高恒 `fontSize × 30/17`（§18.9 常量行高，唯一公式）。
 * 边距两套（评审 M-3）：手机 H 24–40 / T 16–32 / B 16–28；平板 H 40–56 / T 24–40 / B 20–32。
 */

/** 字号范围（用户覆盖值）。 */
export const FONT_SIZE_MIN: number = 12;
export const FONT_SIZE_MAX: number = 26;
/** 非法输入（NaN/≤0）的回落字号：手机现算默认 17；仅用于坏输入，不当下限。 */
export const FONT_SIZE_FALLBACK: number = 17;
/** §18.9：行高 / 字号 比例（30 / 17）。 */
export const LINE_HEIGHT_RATIO: number = 30 / 17;

/** 手机边距范围（vp）。 */
export const MARGIN_PHONE_H_MIN: number = 24;
export const MARGIN_PHONE_H_MAX: number = 40;
export const MARGIN_PHONE_T_MIN: number = 16;
export const MARGIN_PHONE_T_MAX: number = 32;
export const MARGIN_PHONE_B_MIN: number = 16;
export const MARGIN_PHONE_B_MAX: number = 28;
/** 平板边距范围（vp）。 */
export const MARGIN_TABLET_H_MIN: number = 40;
export const MARGIN_TABLET_H_MAX: number = 56;
export const MARGIN_TABLET_T_MIN: number = 24;
export const MARGIN_TABLET_T_MAX: number = 40;
export const MARGIN_TABLET_B_MIN: number = 20;
export const MARGIN_TABLET_B_MAX: number = 32;

/** 纸张色板（3–5 个合法 #RRGGBB；选中即用纯色纸，替代默认 JPG 纸纹）。 */
export const PAPER_COLORS: string[] = ['#f4ecd8', '#f7f3e8', '#efe3c5', '#e9e2d4', '#f2e7dc'];

/**
 * 一张导入字体（prefs `custom.font.imported` 的数组元素）。
 * status：'ok' 已注册生效 / 'failed' 未生效（设备不支持或注册失败）。
 */
export interface ImportedFont {
  familyName: string;
  path: string;
  size: number;
  status: string;
}

/** 一套纸张自定义值（与 CustomizeStore.paper() 返回同形）。 */
export interface PaperPreset {
  /** 纯色纸（'' = 不使用颜色，走默认纸纹）。 */
  color: string;
  /** 横线 / 稿纸红格。 */
  ruled: boolean;
  /** 边距（vp）；0 = 未设置（调用方回落 catalog 默认值）。 */
  marginH: number;
  marginT: number;
  marginB: number;
  /** 导出的纸纹沙箱路径（'' = 不使用纸纹）。 */
  texture: string;
}

/** JSON 里的原始条目（字段可能缺失／类型不对，读取时逐项校验）。 */
interface RawFontEntry {
  familyName?: string;
  path?: string;
  size?: number;
  status?: string;
}

/** JSON 里的原始预设（字段可能缺失）。 */
interface RawPaperPreset {
  color?: string;
  ruled?: boolean;
  marginH?: number;
  marginT?: number;
  marginB?: number;
  texture?: string;
}

/** 整数 clamp；非有限值或 ≤0 视作"未设置"，取 min。 */
function clampInt(v: number, min: number, max: number): number {
  if (!isFinite(v) || v <= 0) {
    return min;
  }
  const n: number = Math.round(v);
  if (n < min) {
    return min;
  }
  if (n > max) {
    return max;
  }
  return n;
}

/** 字号 clamp 到 12–26；NaN/≤0 回落 17（仅坏输入，非下限）。 */
export function clampFontSize(n: number): number {
  if (!isFinite(n) || n <= 0) {
    return FONT_SIZE_FALLBACK;
  }
  const v: number = Math.round(n);
  if (v < FONT_SIZE_MIN) {
    return FONT_SIZE_MIN;
  }
  if (v > FONT_SIZE_MAX) {
    return FONT_SIZE_MAX;
  }
  return v;
}

/**
 * 生效字号：userSize ≤ 0（键缺失／未设置）→ computed（measureStage 现算值）；
 * 否则用用户覆盖值（clamp 12–26）。
 */
export function effectiveFontSize(userSize: number, computed: number): number {
  const base: number = isFinite(computed) && computed > 0 ? computed : FONT_SIZE_FALLBACK;
  if (!isFinite(userSize) || userSize <= 0) {
    return base;
  }
  return clampFontSize(userSize);
}

/**
 * 行高 = 字号 × 30/17（§18.9 钉死的唯一公式；不许各处另写比例）。
 * 17 → 30（中文行高）；保留小数，交给布局层用。
 */
export function lineHeightOf(fontSize: number): number {
  if (!isFinite(fontSize) || fontSize <= 0) {
    return FONT_SIZE_FALLBACK * LINE_HEIGHT_RATIO;
  }
  // 先乘后除：17 → 30（整数不漂）；24 → 42.3529…
  return (fontSize * 30) / 17;
}

/** 左右边距 clamp（手机 24–40 / 平板 40–56）。 */
export function clampMarginH(isTablet: boolean, v: number): number {
  return isTablet
    ? clampInt(v, MARGIN_TABLET_H_MIN, MARGIN_TABLET_H_MAX)
    : clampInt(v, MARGIN_PHONE_H_MIN, MARGIN_PHONE_H_MAX);
}

/** 上边距 clamp（手机 16–32 / 平板 24–40）。 */
export function clampMarginT(isTablet: boolean, v: number): number {
  return isTablet
    ? clampInt(v, MARGIN_TABLET_T_MIN, MARGIN_TABLET_T_MAX)
    : clampInt(v, MARGIN_PHONE_T_MIN, MARGIN_PHONE_T_MAX);
}

/** 下边距 clamp（手机 16–28 / 平板 20–32）。 */
export function clampMarginB(isTablet: boolean, v: number): number {
  return isTablet
    ? clampInt(v, MARGIN_TABLET_B_MIN, MARGIN_TABLET_B_MAX)
    : clampInt(v, MARGIN_PHONE_B_MIN, MARGIN_PHONE_B_MAX);
}

/**
 * 把导入文件名／路径揉成可做 familyName 的片段：取末段、去扩展名、只保留
 * [A-Za-z0-9_-]（空格→'-'），空结果回落 'font'，最长 32 字符。
 * 最终族名由调用方加唯一前缀：`imp-<ts>-<片段>`（评审 N-2）。
 */
export function validFamilyName(rawName: string): string {
  let s: string = rawName;
  const slash: number = s.lastIndexOf('/');
  if (slash >= 0) {
    s = s.substring(slash + 1);
  }
  const dot: number = s.lastIndexOf('.');
  if (dot > 0) {
    s = s.substring(0, dot);
  }
  let out: string = '';
  for (let i = 0; i < s.length; i++) {
    const c: string = s.charAt(i);
    const isLower: boolean = c >= 'a' && c <= 'z';
    const isUpper: boolean = c >= 'A' && c <= 'Z';
    const isDigit: boolean = c >= '0' && c <= '9';
    if (isLower || isUpper || isDigit || c === '-' || c === '_') {
      out += c;
    } else if (c === ' ') {
      out += '-';
    }
  }
  if (out.length === 0) {
    out = 'font';
  }
  if (out.length > 32) {
    out = out.substring(0, 32);
  }
  return out;
}

/** 导入字体列表 JSON → 数组；坏 JSON／非数组／坏条目一律跳过，不抛。 */
export function fontListOf(raw: string): ImportedFont[] {
  if (raw.length === 0) {
    return [];
  }
  let arr: (RawFontEntry | null)[] = [];
  try {
    arr = JSON.parse(raw) as (RawFontEntry | null)[];
  } catch (e) {
    return [];
  }
  if (!Array.isArray(arr)) {
    return [];
  }
  const out: ImportedFont[] = [];
  for (let i = 0; i < arr.length; i++) {
    const it: RawFontEntry | null = arr[i];
    if (it === undefined || it === null) {
      continue;
    }
    const fam: string = it.familyName === undefined ? '' : it.familyName;
    if (fam.length === 0) {
      continue;
    }
    out.push({
      familyName: fam,
      path: it.path === undefined ? '' : it.path,
      size: it.size === undefined || !isFinite(it.size) ? 0 : it.size,
      status: it.status === undefined ? 'failed' : it.status,
    });
  }
  return out;
}

/** 导入字体数组 → JSON（字段顺序固定，便于 prefs 对比）。 */
export function fontListToJson(list: ImportedFont[]): string {
  const arr: ImportedFont[] = [];
  for (let i = 0; i < list.length; i++) {
    arr.push({
      familyName: list[i].familyName,
      path: list[i].path,
      size: list[i].size,
      status: list[i].status,
    });
  }
  return JSON.stringify(arr);
}

/**
 * 加一条导入字体（按 familyName 去重：已存在则替换，保证"重导入同名"不涨列表）。
 * 坏 JSON 按空列表处理。
 */
export function fontListAdd(raw: string, item: ImportedFont): string {
  const list: ImportedFont[] = fontListOf(raw);
  const out: ImportedFont[] = [];
  let replaced: boolean = false;
  for (let i = 0; i < list.length; i++) {
    if (list[i].familyName === item.familyName) {
      out.push(item);
      replaced = true;
    } else {
      out.push(list[i]);
    }
  }
  if (!replaced) {
    out.push(item);
  }
  return fontListToJson(out);
}

/** 按 familyName 删除一条；坏 JSON 返回空列表 JSON。 */
export function fontListRemove(raw: string, familyName: string): string {
  const list: ImportedFont[] = fontListOf(raw);
  const out: ImportedFont[] = [];
  for (let i = 0; i < list.length; i++) {
    if (list[i].familyName !== familyName) {
      out.push(list[i]);
    }
  }
  return fontListToJson(out);
}

/** 单个字符是否十六进制。 */
function isHexChar(c: string): boolean {
  const lower: boolean = c >= 'a' && c <= 'f';
  const upper: boolean = c >= 'A' && c <= 'F';
  const digit: boolean = c >= '0' && c <= '9';
  return lower || upper || digit;
}

/** `#RRGGBB` 校验：合法原样返回，否则回落 fallback（不做颜色空间换算）。 */
export function hexColorOr(fallback: string, v: string): string {
  if (v.length !== 7 || v.charAt(0) !== '#') {
    return fallback;
  }
  for (let i = 1; i < 7; i++) {
    if (!isHexChar(v.charAt(i))) {
      return fallback;
    }
  }
  return v;
}

/** 预设里的边距：非有限值或 <0 → 0（0 = 未设置）。 */
function presetMargin(v: number | undefined): number {
  if (v === undefined || !isFinite(v) || v < 0) {
    return 0;
  }
  return Math.round(v);
}

/** 原始预设 → 补齐默认值（color ''／ruled false／边距 0／texture ''）。 */
function normalizePreset(raw: RawPaperPreset | null): PaperPreset {
  if (raw === undefined || raw === null) {
    return { color: '', ruled: false, marginH: 0, marginT: 0, marginB: 0, texture: '' };
  }
  return {
    color: hexColorOr('', raw.color === undefined ? '' : raw.color),
    ruled: raw.ruled === true,
    marginH: presetMargin(raw.marginH),
    marginT: presetMargin(raw.marginT),
    marginB: presetMargin(raw.marginB),
    texture: raw.texture === undefined ? '' : raw.texture,
  };
}

/** 预设 → JSON（字段顺序固定）。 */
export function paperPresetToJson(preset: PaperPreset): string {
  const p: PaperPreset = normalizePreset({
    color: preset.color, ruled: preset.ruled, marginH: preset.marginH,
    marginT: preset.marginT, marginB: preset.marginB, texture: preset.texture,
  });
  return JSON.stringify(p);
}

/** JSON → 预设；坏 JSON／缺字段一律补齐默认（不抛）。 */
export function paperPresetFromJson(raw: string): PaperPreset {
  if (raw.length === 0) {
    return normalizePreset(null);
  }
  let obj: RawPaperPreset | null = null;
  try {
    obj = JSON.parse(raw) as RawPaperPreset | null;
  } catch (e) {
    return normalizePreset(null);
  }
  if (typeof obj !== 'object' || obj === null || Array.isArray(obj)) {
    return normalizePreset(null);
  }
  return normalizePreset(obj);
}

/** 预设表 JSON（`{名称: 预设}`）→ 名称列表（插入序）；坏 JSON 返回空。 */
export function presetsOf(raw: string): string[] {
  if (raw.length === 0) {
    return [];
  }
  let map: Record<string, RawPaperPreset> = {};
  try {
    map = JSON.parse(raw) as Record<string, RawPaperPreset>;
  } catch (e) {
    return [];
  }
  if (typeof map !== 'object' || map === null || Array.isArray(map)) {
    return [];
  }
  const keys: string[] = Object.keys(map);
  const out: string[] = [];
  for (let i = 0; i < keys.length; i++) {
    if (keys[i].length > 0) {
      out.push(keys[i]);
    }
  }
  return out;
}

/** 读一张预设；不存在／坏 JSON 返回 null。 */
export function presetOf(raw: string, name: string): PaperPreset | null {
  if (raw.length === 0) {
    return null;
  }
  let map: Record<string, RawPaperPreset> = {};
  try {
    map = JSON.parse(raw) as Record<string, RawPaperPreset>;
  } catch (e) {
    return null;
  }
  if (typeof map !== 'object' || map === null || Array.isArray(map)) {
    return null;
  }
  const keys: string[] = Object.keys(map);
  for (let i = 0; i < keys.length; i++) {
    if (keys[i] === name) {
      return normalizePreset(map[name]);
    }
  }
  return null;
}

/** 写一张预设（覆盖同名）；坏 JSON 按空表处理。 */
export function presetAdd(raw: string, name: string, preset: PaperPreset): string {
  const map: Record<string, PaperPreset> = {};
  if (raw.length > 0) {
    let parsed: Record<string, RawPaperPreset> = {};
    try {
      parsed = JSON.parse(raw) as Record<string, RawPaperPreset>;
    } catch (e) {
      parsed = {};
    }
    if (typeof parsed === 'object' && parsed !== null && !Array.isArray(parsed)) {
      const keys: string[] = Object.keys(parsed);
      for (let i = 0; i < keys.length; i++) {
        map[keys[i]] = normalizePreset(parsed[keys[i]]);
      }
    }
  }
  map[name] = normalizePreset({
    color: preset.color, ruled: preset.ruled, marginH: preset.marginH,
    marginT: preset.marginT, marginB: preset.marginB, texture: preset.texture,
  });
  return JSON.stringify(map);
}

/** 删一张预设；坏 JSON 返回空表 JSON。 */
export function presetRemove(raw: string, name: string): string {
  const map: Record<string, RawPaperPreset> = {};
  if (raw.length > 0) {
    let parsed: Record<string, RawPaperPreset> = {};
    try {
      parsed = JSON.parse(raw) as Record<string, RawPaperPreset>;
    } catch (e) {
      parsed = {};
    }
    if (typeof parsed === 'object' && parsed !== null && !Array.isArray(parsed)) {
      const keys: string[] = Object.keys(parsed);
      for (let i = 0; i < keys.length; i++) {
        if (keys[i] !== name) {
          map[keys[i]] = parsed[keys[i]];
        }
      }
    }
  }
  return JSON.stringify(map);
}
