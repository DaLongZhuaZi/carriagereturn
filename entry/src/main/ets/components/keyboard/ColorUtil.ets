/**
 * 回车 · 键帽浮雕配色派生
 *
 * 键帽底色只有 KeyboardViewSpec.keycapColor 一个来源（各台机器取色已锁定，见风格板 §2）。
 * 键帽边沿、顶面高光、字符墨色、键槽阴影、键盘底板一律由底色派生：
 * 换装时不需要给键盘加任何新字段，也不会在代码里写死颜色。
 *
 * 纯函数、无 UI 依赖，可离线自测（node 跑同一份逻辑）。
 */

/** 派生出的一套键帽颜色。字段均为 "#RRGGBB" / "#AARRGGBB" 串，直接给 ArkUI 用。 */
export class KeycapPalette {
  /** 键帽底色：由调用方传入的 keycapColor 原样带入（风格板 §2 各台取色）。 */
  readonly cap: string;
  /** 键帽边沿：底色压暗一档，做键帽的暗边。 */
  readonly capEdge: string;
  /** 顶面高光：底色提亮一档，做浮雕受光面。 */
  readonly capHighlight: string;
  /** 键帽字符墨色：亮底用深字、深底用亮字（自动按亮度选）。 */
  readonly label: string;
  /** 键盘底板（机架）：底色压到最暗，托住键槽。 */
  readonly deck: string;
  /** 键槽阴影：底色压暗，做短而实的下沉阴影。 */
  readonly well: string;

  constructor(cap: string, capEdge: string, capHighlight: string, label: string, deck: string, well: string) {
    this.cap = cap;
    this.capEdge = capEdge;
    this.capHighlight = capHighlight;
    this.label = label;
    this.deck = deck;
    this.well = well;
  }
}

/** 中性兜底色：只在调用方还没把 keycapColor 传进来时用一帧，不影响各台机器的锁定取色。 */
export const NEUTRAL_KEYCAP_HEX: string = '#808080';

/**
 * 中性兜底配色。
 *
 * 刻意用字面量直接构造、不在模块初始化期调用 deriveKeycapPalette：
 * 模块级 const 之间有初始化顺序约束（派生函数还依赖后面的常量），
 * 一旦顺序变动就变成初始化期 TDZ 崩溃 —— 自测已复现过该问题，故这里不留隐患。
 * 这组灰不是任何机器的取色，只做一帧兜底；机器取色一律走 KeyboardViewSpec.keycapColor。
 */
export const NEUTRAL_KEYCAP_PALETTE: KeycapPalette = new KeycapPalette('#808080', '#5C5C5C', '#B8B8B8', '#141414', '#1C1C1C', '#333333');

/** 亮度阈值：底色亮于此值用深字，否则用亮字。 */
const LIGHT_CAP_LUMINANCE: number = 0.55;

/**
 * 派生整套键帽配色。
 * 输入非法（不是 #rgb / #rrggbb / #aarrggbb）时原样返回，不改变任何颜色。
 */
export function deriveKeycapPalette(keycapColor: string): KeycapPalette {
  const rgb: string = normalizeHex(keycapColor);
  if (rgb.length === 0) {
    return new KeycapPalette(keycapColor, keycapColor, keycapColor, keycapColor, keycapColor, keycapColor);
  }
  // 注意两点：shiftHex 要拿原始色值（带 # 与可能的 alpha）；
  // 亮度判断走 luminanceOfRgb（rgb 已去掉 #，不能再进一次 normalizeHex 否则会被判成非法色）。
  const labelBase: string = luminanceOfRgb(rgb) >= LIGHT_CAP_LUMINANCE ? shiftHex(keycapColor, -0.78) : shiftHex(keycapColor, 0.72);
  return new KeycapPalette(
    keycapColor,
    shiftHex(keycapColor, -0.28),
    shiftHex(keycapColor, 0.45),
    labelBase,
    shiftHex(keycapColor, -0.78),
    shiftHex(keycapColor, -0.62)
  );
}

/**
 * 把颜色按 amount 提亮（正）或压暗（负）。amount 取值 [-1, 1]。
 * 保留输入原有的 alpha 通道（8 位色值格式不变）。
 */
export function shiftHex(hex: string, amount: number): string {
  const rgb: string = normalizeHex(hex);
  if (rgb.length === 0) {
    return hex;
  }
  const r: number = channelShift(hexChannel(rgb, 0), amount);
  const g: number = channelShift(hexChannel(rgb, 1), amount);
  const b: number = channelShift(hexChannel(rgb, 2), amount);
  return composeHex(hex, toHexPair(r) + toHexPair(g) + toHexPair(b));
}

/** 颜色亮度（0 黑 - 1 白）；非法输入返回 0。 */
export function luminance(hex: string): number {
  const rgb: string = normalizeHex(hex);
  if (rgb.length === 0) {
    return 0;
  }
  return luminanceOfRgb(rgb);
}

/** 亮度的内部实现：rgb 必须已是 6 位十六进制通道串（不含 #）。 */
function luminanceOfRgb(rgb: string): number {
  return (0.2126 * hexChannel(rgb, 0) + 0.7152 * hexChannel(rgb, 1) + 0.0722 * hexChannel(rgb, 2)) / 255;
}

/** 规范化成 6 位 "#RRGGBB" 的通道串（不含 #）；非法返回空串。 */
function normalizeHex(hex: string): string {
  if (hex.length === 0 || hex.charAt(0) !== '#') {
    return '';
  }
  const body: string = hex.substring(1).toUpperCase();
  if (body.length === 3) {
    const r: string = body.charAt(0) + body.charAt(0);
    const g: string = body.charAt(1) + body.charAt(1);
    const b: string = body.charAt(2) + body.charAt(2);
    return isHexDigits(r + g + b) ? r + g + b : '';
  }
  if (body.length === 6) {
    return isHexDigits(body) ? body : '';
  }
  if (body.length === 8) {
    const tail: string = body.substring(2);
    return isHexDigits(body) ? tail : '';
  }
  return '';
}

/** 取第 index 个通道（0=R,1=G,2=B）的值，0-255。 */
function hexChannel(rgb: string, index: number): number {
  const pair: string = rgb.substring(index * 2, index * 2 + 2);
  return parseInt(pair, 16);
}

/** 单通道提亮 / 压暗并夹到 0-255。 */
function channelShift(value: number, amount: number): number {
  let next: number = amount >= 0 ? value + (255 - value) * amount : value * (1 + amount);
  if (next < 0) {
    next = 0;
  }
  if (next > 255) {
    next = 255;
  }
  return Math.round(next);
}

/** 十六进制字符表：不依赖 Number.toString(radix) 的平台差异。 */
const HEX_DIGITS: string = '0123456789ABCDEF';

/** 数字转两位十六进制。 */
function toHexPair(value: number): string {
  const high: number = Math.floor(value / 16);
  const low: number = value - high * 16;
  return HEX_DIGITS.charAt(high) + HEX_DIGITS.charAt(low);
}

/** 拼回颜色串：输入带 alpha（8 位）则保留原 alpha。 */
function composeHex(source: string, rgb: string): string {
  const body: string = source.substring(1);
  if (body.length === 8) {
    return '#' + body.substring(0, 2) + rgb;
  }
  return '#' + rgb;
}

/** 是否全为十六进制字符。 */
function isHexDigits(text: string): boolean {
  if (text.length === 0) {
    return false;
  }
  for (let i = 0; i < text.length; i++) {
    const c: string = text.charAt(i);
    const isDigit: boolean = c >= '0' && c <= '9';
    const isUpper: boolean = c >= 'A' && c <= 'F';
    if (!isDigit && !isUpper) {
      return false;
    }
  }
  return true;
}
