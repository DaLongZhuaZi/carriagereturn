/**
 * 回车 · 机器 / 纸张 / 色带 / 字体 目录（界面重设计稿 §2.1 §2.3 §8.1 定稿）
 *
 * 所有 rawfile 路径与展示参数集中在此，组件不写死路径。
 * 素材节：machine/ 键带与服务端母版、keymap/ 键位坐标、carriage/ 字车条、typebar/ 动画层。
 * 资源文件名去品牌化：品牌名只留在 SOURCE.txt，不进资源路径或界面文案。
 *
 * ⚠️ $rawfile() 只接受编译期字符串常量，故本文件只提供「路径常量 + 按枚举分支」，
 *    组件里用 if/else 静态分支取图，不要拼变量。
 */

import { MachineKind, PaperFont, PaperKind, RibbonKind } from './DocModel';

/** 一台机器的资源与字形参数。 */
export interface MachineSpec {
  kind: MachineKind;
  /** 第 13 批 ⑤：主页 hero 整机全图（正面全貌，Contain 呈现；运行期按静态分支取字面量）。 */
  frontRawfile: string;
  /** 键位坐标表。 */
  keymapRawfile: string;
  /** 键帽叠字颜色（§2.3 钉死）。 */
  overlayColor: string;
  /** 键帽叠字字号（vp）。 */
  overlayFontSizeVp: number;
  /** 机身主色。 */
  bodyColor: string;
  /** 纸面英文字号（vp）。 */
  fontScale: number;
  /** 纸面英文行高（vp）。 */
  englishLineHeightVp: number;
  /** §4 几何参数（多机型逻辑层设计）：按机型取数，不许写死 */
  leverAspect: number;
  leverPivotX: number;
  leverPivotY: number;
  bracketAspect: number;
  bracketPivotX: number;
  bracketPivotY: number;
  rollerWidthRatio: number;
  baseRailAspect: number;
  basketAspect: number;
  bailRollerLX: number;
  bailRollerRX: number;
  bailRollerY: number;
  centralWindowX: number;
  centralWindowY: number;
  /** §11 C：中央件宽高比（1920s 0.848、1930s 1.091） */
  centralAspect: number;
  /** 纸面中文行高（vp）。 */
  chineseLineHeightVp: number;
}

/** 纸张资源与字样参数。格线 / 边距 / 红格 / 页眉一律代码层画，不 baked 进纹理。 */
export interface PaperSpec {
  kind: PaperKind;
  textureRawfile: string;
  /** 稿纸红格 + 横线。 */
  hasRuledGrid: boolean;
  /** 信纸页眉双细线 + 右上角页码。 */
  hasHeader: boolean;
  /** 左右边距（vp）：便签 36，其余 28。 */
  marginH: number;
  /** 顶边距（vp）。 */
  marginTop: number;
  /** 底边距（vp）。 */
  marginBottom: number;
}

/** 色带的墨色与做旧参数（§1 色板钉死：黑 #1a1a1a / 蓝 #24407c / 红 #a33327）。 */
export interface RibbonSpec {
  kind: RibbonKind;
  inkColor: string;
  inkAlpha: number;
}

/** 一款纸面字体。 */
export interface FontSpec {
  font: PaperFont;
  rawfile: string;
  familyName: string;
  /** §8.4 分组：english / chinese / handwriting。 */
  group: string;
  /** 试写用样本（英文 Ag / 中文 永 / 手写 回车）。 */
  sample: string;
}

export const DEFAULT_MACHINE: MachineKind = MachineKind.UPRIGHT_1920S;
export const DEFAULT_PAPER: PaperKind = PaperKind.LETTER;
export const DEFAULT_RIBBON: RibbonKind = RibbonKind.BLACK;
export const DEFAULT_FONT: PaperFont = PaperFont.COURIER_PRIME;

/** 主屏纵向构成常量（§2.1，390×844 基准，其余按比例缩放）。 */
export const TOP_BAR_HEIGHT_VP: number = 56;
export const PAPER_TOP_GAP_VP: number = 4;
export const CARRIAGE_STRIP_HEIGHT_VP: number = 55;
export const CARRIAGE_PAPER_OVERLAP_VP: number = 8;
export const FONT_BAR_HEIGHT_VP: number = 38;
/** §18.8／§19：候选栏高度（常驻占位）。CandidateBar 与布局 region 共用这一个常量，不许两处各写 44 */
export const CANDIDATE_BAR_HEIGHT_VP: number = 44;
export const KEYBED_HEIGHT_VP: number = 186;

/**
 * 第 28 批（24 号稿 §2.1）：机身三档色 token（4 机×3 档＝12 个）。
 * 顺序固定 [纸井 paperwell, 机身基准 base, 键床 keybed]；相对亮度 L 与档差 ΔL 见稿内表。
 * 校验口径：每档采样对照本档 token ±10%（32×32 区块均值），ΔL 下限 0.010。
 */
const TIER_TOKENS: Record<string, string[]> = {
  // 第 32 批（25 号稿 §2.1）：第 4 元 steel（钢板）；顺序钉死 [paperwell, base, keybed, steel]
  // 批 37（增补-2 §2）：base 改薄荷绿系（同一色相、不同明度）；paperwell/keybed/steel 不动
  '1920s-upright': ['#25201b', '#1e1c1a', '#3b342b', '#5e5e5e'],
  '1930s-portable': ['#342f2b', '#3a4038', '#453e38', '#636363'],
  '1950s-streamlined': ['#c6b7a4', '#d8cbb0', '#cabba7', '#d0c9b9'],
  '1960s-electric': ['#8e8880', '#a8a8a0', '#96908a', '#a59f96'],
  // 批 74：现代机（与 1920s 同色——现代机即当前“26”主题，几何与色板一致）
  '2020s-modern': ['#25201b', '#adc4b8', '#3b342b', '#5e5e5e'],
};

/** 四档 token 的索引：paperwell=0／base=1／keybed=2／steel=3（第 32 批加 steel）。 */
export function tierIndex(tier: string): number {
  if (tier === 'paperwell') { return 0; }
  if (tier === 'keybed') { return 2; }
  if (tier === 'steel') { return 3; }
  return 1;
}

/**
 * 取某机某档的色值（§2.1）。供分区背景／边线／Cheek（批 31）使用；
 * 非法机型回落 1920s，非法档回落 base。
 */
export function tierToken(machine: MachineKind, tier: 'paperwell' | 'base' | 'keybed' | 'steel'): string {
  const row: string[] | undefined = TIER_TOKENS[machine as string];
  const idx: number = tierIndex(tier);
  if (row !== undefined) {
    return row[idx];
  }
  return TIER_TOKENS['1920s-upright'][idx];
}

/**
 * 第 32 批（25 号稿 §2.4）：按目标亮度差 ΔL 整体缩放 sRGB 色（线性空间缩放各通道，回 sRGB 取整）。
 * 代码一律调本函数，不写死端色。
 */
export function shiftHexColor(hex: string, dL: number): string {
  const toLin = (v: number): number => {
    const c: number = v / 255;
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  };
  const toSrgb = (c: number): number => {
    const v: number = c <= 0.0031308 ? c * 12.92 : 1.055 * Math.pow(c, 1 / 2.4) - 0.055;
    return v;
  };
  const lr: number = toLin(Number.parseInt(hex.substring(1, 3), 16));
  const lg: number = toLin(Number.parseInt(hex.substring(3, 5), 16));
  const lb: number = toLin(Number.parseInt(hex.substring(5, 7), 16));
  const L: number = 0.2126 * lr + 0.7152 * lg + 0.0722 * lb;
  if (L <= 0.00001) {
    return hex;
  }
  const k: number = (L + dL) / L;
  const out = (c: number): string => {
    const v: number = Math.max(0, Math.min(255, Math.round(toSrgb(c * k) * 255)));
    return (v < 16 ? '0' : '') + v.toString(16);
  };
  return '#' + out(lr) + out(lg) + out(lb);
}

/** 第 28 批：每档贴片名（ui-parts 下，slug 词表钉死；不含 steel）。 */
export function tierTileRawfile(machine: MachineKind, tier: 'paperwell' | 'base' | 'keybed'): string {
  const k: string = machine as string;
  const i: number = k.indexOf('-');
  const slug: string = i > 0 ? k.substring(0, i) : k;
  return 'ui-parts/tile-' + slug + '-' + tier + '.png';
}
export const FUNCTION_ROW_HEIGHT_VP: number = 52;
export const KEYBOARD_HEIGHT_VP: number = KEYBED_HEIGHT_VP + FUNCTION_ROW_HEIGHT_VP;

export const MACHINES: MachineSpec[] = [
  {
    kind: MachineKind.UPRIGHT_1920S,
    frontRawfile: 'machine/1920s-upright-front.jpg',
    keymapRawfile: 'keymap/1920s-upright-keymap.json',
    overlayColor: '#312b24',
    overlayFontSizeVp: 14,
    bodyColor: '#1e1c1a',
    fontScale: 17,
    englishLineHeightVp: 28,
    chineseLineHeightVp: 30,
    leverAspect: 0.2125,
    leverPivotX: 0.5,
    leverPivotY: 0.952,
    bracketAspect: 0.8042,
    bracketPivotX: 0.503,
    bracketPivotY: 0.293,
    rollerWidthRatio: 0.9528,
    baseRailAspect: 7.56,
    basketAspect: 4.7,
    bailRollerLX: 0.28,
    bailRollerRX: 0.724,
    bailRollerY: 0.747,
    centralWindowX: 0.5,
    centralWindowY: 0.55,
    centralAspect: 0.848,
  },
  {
    kind: MachineKind.PORTABLE_1930S,
    frontRawfile: 'machine/1930s-portable-front.jpg',
    keymapRawfile: 'keymap/1930s-portable-keymap.json',
    // §4：1930s 分层素材已到，三个字段填上
    overlayColor: '#dbccb3',
    overlayFontSizeVp: 14,
    bodyColor: '#3a4038',
    fontScale: 17,
    englishLineHeightVp: 28,
    chineseLineHeightVp: 30,
    leverAspect: 0.3264,
    leverPivotX: 0.538,
    leverPivotY: 0.96,
    bracketAspect: 1.2921,
    bracketPivotX: 0.519,
    bracketPivotY: 0.199,
    rollerWidthRatio: 0.9528,
    baseRailAspect: 2.95,
    basketAspect: 3.1,
    bailRollerLX: 0.027,
    bailRollerRX: 0.974,
    bailRollerY: 0.5,
    centralWindowX: 0.502,
    centralWindowY: 0.522,
    centralAspect: 1.091,
  },
  {
    kind: MachineKind.STREAMLINED_1950S,
    frontRawfile: 'machine/1950s-streamlined-front.jpg',
    keymapRawfile: 'keymap/1950s-streamlined-keymap.json',
    overlayColor: '#312b24',
    overlayFontSizeVp: 14,
    bodyColor: '#d8cbb0',
    fontScale: 17,
    englishLineHeightVp: 28,
    chineseLineHeightVp: 30,
    leverAspect: 0.09,
    leverPivotX: 0.496,
    leverPivotY: 0.942,
    bracketAspect: 0.87,
    bracketPivotX: 0.504,
    bracketPivotY: 0.427,
    rollerWidthRatio: 0.9528,
    baseRailAspect: 14.54,
    basketAspect: 4.70,
    bailRollerLX: 0.058,
    bailRollerRX: 0.954,
    bailRollerY: 0.475,
    centralWindowX: 0.499,
    centralWindowY: 0.558,
    centralAspect: 0.93,
  },
  {
    kind: MachineKind.ELECTRIC_1960S,
    frontRawfile: 'machine/1960s-electric-front.jpg',
    keymapRawfile: 'keymap/1960s-electric-keymap.json',
    overlayColor: '#312b24',
    overlayFontSizeVp: 14,
    bodyColor: '#a8a8a0',
    fontScale: 17,
    englishLineHeightVp: 28,
    chineseLineHeightVp: 30,
    leverAspect: 0.12,
    leverPivotX: 0.502,
    leverPivotY: 0.948,
    bracketAspect: 0.71,
    bracketPivotX: 0.498,
    bracketPivotY: 0.358,
    rollerWidthRatio: 0.9528,
    baseRailAspect: 8.66,
    basketAspect: 2.94,
    bailRollerLX: 0.054,
    bailRollerRX: 0.966,
    bailRollerY: 0.500,
    centralWindowX: 0.501,
    centralWindowY: 0.451,
    centralAspect: 1.19,
  },
  {
    kind: MachineKind.MODERN_2020S,
    frontRawfile: 'machine/2020s-modern-front.jpg',
    keymapRawfile: 'keymap/2020s-modern-keymap.json',
    overlayColor: '#312b24',
    overlayFontSizeVp: 14,
    bodyColor: '#adc4b8',
    fontScale: 17,
    englishLineHeightVp: 28,
    chineseLineHeightVp: 30,
    leverAspect: 0.2125,
    leverPivotX: 0.5,
    leverPivotY: 0.952,
    bracketAspect: 0.8042,
    bracketPivotX: 0.503,
    bracketPivotY: 0.293,
    rollerWidthRatio: 0.9528,
    baseRailAspect: 7.56,
    basketAspect: 4.7,
    bailRollerLX: 0.28,
    bailRollerRX: 0.724,
    bailRollerY: 0.747,
    centralWindowX: 0.5,
    centralWindowY: 0.55,
    centralAspect: 0.848,
  },
];

export const PAPERS: PaperSpec[] = [
  { kind: PaperKind.LETTER, textureRawfile: 'paper/paper-letter.jpg', hasRuledGrid: false, hasHeader: true, marginH: 48, marginTop: 24, marginBottom: 20 },
  { kind: PaperKind.MANUSCRIPT, textureRawfile: 'paper/paper-manuscript.jpg', hasRuledGrid: true, hasHeader: true, marginH: 48, marginTop: 24, marginBottom: 20 },
  { kind: PaperKind.POSTCARD, textureRawfile: 'paper/paper-postcard.jpg', hasRuledGrid: false, hasHeader: false, marginH: 48, marginTop: 24, marginBottom: 20 },
  { kind: PaperKind.MEMO, textureRawfile: 'paper/paper-memo.jpg', hasRuledGrid: false, hasHeader: false, marginH: 48, marginTop: 24, marginBottom: 20 },
];

export const RIBBONS: RibbonSpec[] = [
  { kind: RibbonKind.BLACK, inkColor: '#1a1a1a', inkAlpha: 1 },
  { kind: RibbonKind.BLUE, inkColor: '#24407c', inkAlpha: 1 },
  { kind: RibbonKind.RED, inkColor: '#a33327', inkAlpha: 1 },
];

/** 17 款字体（§8.4）。group: english / chinese / handwriting。 */
export const FONTS: FontSpec[] = [
  { font: PaperFont.COURIER_PRIME, rawfile: 'font/CourierPrime-Regular.ttf', familyName: 'CourierPrime', group: 'english', sample: 'Ag' },
  { font: PaperFont.SPECIAL_ELITE, rawfile: 'font/SpecialElite-Regular.ttf', familyName: 'SpecialElite', group: 'english', sample: 'Ag' },
  { font: PaperFont.IM_FELL_ENGLISH, rawfile: 'font/IMFeENrm28P.ttf', familyName: 'IMFellEnglish', group: 'english', sample: 'Ag' },
  { font: PaperFont.ANONYMOUS_PRO, rawfile: 'font/AnonymousPro-Regular.ttf', familyName: 'AnonymousPro', group: 'english', sample: 'Ag' },
  { font: PaperFont.SPACE_MONO, rawfile: 'font/SpaceMono-Regular.ttf', familyName: 'SpaceMono', group: 'english', sample: 'Ag' },
  { font: PaperFont.XANH_MONO, rawfile: 'font/XanhMono-Regular.ttf', familyName: 'XanhMono', group: 'english', sample: 'Ag' },
  { font: PaperFont.NOTO_SERIF_SC, rawfile: 'font/NotoSerifSC-wght.ttf', familyName: 'NotoSerifSC', group: 'chinese', sample: '永' },
  { font: PaperFont.LXGW_WENKAI, rawfile: 'font/LXGWWenKai-Regular.ttf', familyName: 'LXGWWenKai', group: 'chinese', sample: '永' },
  { font: PaperFont.ZHUQUE_FANGSONG, rawfile: 'font/ZhuqueFangsong-Regular.ttf', familyName: 'ZhuqueFangsong', group: 'chinese', sample: '永' },
  { font: PaperFont.MA_SHAN_ZHENG, rawfile: 'font/MaShanZheng-Regular.ttf', familyName: 'MaShanZheng', group: 'chinese', sample: '永' },
  { font: PaperFont.ZHI_MANG_XING, rawfile: 'font/ZhiMangXing-Regular.ttf', familyName: 'ZhiMangXing', group: 'chinese', sample: '永' },
  { font: PaperFont.LONG_CANG, rawfile: 'font/LongCang-Regular.ttf', familyName: 'LongCang', group: 'chinese', sample: '永' },
  { font: PaperFont.CAVEAT, rawfile: 'font/Caveat-Regular.ttf', familyName: 'Caveat', group: 'handwriting', sample: '回车' },
  { font: PaperFont.KALAM, rawfile: 'font/Kalam-Regular.ttf', familyName: 'Kalam', group: 'handwriting', sample: '回车' },
  { font: PaperFont.PATRICK_HAND, rawfile: 'font/PatrickHand-Regular.ttf', familyName: 'PatrickHand', group: 'handwriting', sample: '回车' },
  { font: PaperFont.SHADOWS_INTO_LIGHT, rawfile: 'font/ShadowsIntoLight-Regular.ttf', familyName: 'ShadowsIntoLight', group: 'handwriting', sample: '回车' },
  { font: PaperFont.HOMEMADE_APPLE, rawfile: 'font/HomemadeApple-Regular.ttf', familyName: 'HomemadeApple', group: 'handwriting', sample: '回车' },
];

/** 字体条的显示名（界面用，非界面文案硬编码：属字体专名，不翻译）。 */
export function fontDisplayName(font: PaperFont): string {
  if (font === PaperFont.COURIER_PRIME) { return 'Courier Prime'; }
  if (font === PaperFont.SPECIAL_ELITE) { return 'Special Elite'; }
  if (font === PaperFont.IM_FELL_ENGLISH) { return 'IM Fell English'; }
  if (font === PaperFont.ANONYMOUS_PRO) { return 'Anonymous Pro'; }
  if (font === PaperFont.SPACE_MONO) { return 'Space Mono'; }
  if (font === PaperFont.XANH_MONO) { return 'Xanh Mono'; }
  if (font === PaperFont.NOTO_SERIF_SC) { return 'Noto Serif SC'; }
  if (font === PaperFont.LXGW_WENKAI) { return 'LXGW WenKai'; }
  if (font === PaperFont.ZHUQUE_FANGSONG) { return 'Zhuque Fangsong'; }
  if (font === PaperFont.MA_SHAN_ZHENG) { return 'Ma Shan Zheng'; }
  if (font === PaperFont.ZHI_MANG_XING) { return 'Zhi Mang Xing'; }
  if (font === PaperFont.LONG_CANG) { return 'Long Cang'; }
  if (font === PaperFont.CAVEAT) { return 'Caveat'; }
  if (font === PaperFont.KALAM) { return 'Kalam'; }
  if (font === PaperFont.PATRICK_HAND) { return 'Patrick Hand'; }
  if (font === PaperFont.SHADOWS_INTO_LIGHT) { return 'Shadows Into Light'; }
  if (font === PaperFont.HOMEMADE_APPLE) { return 'Homemade Apple'; }
  return 'Courier Prime';
}

/**
 * 字体族名 → 界面显示名（第 5 批回批补：F3 起字体条改渲染「当前字体族名」，
 * 但族名是 'CourierPrime' 这类无空格形式，界面上应显示 'Courier Prime'。
 * 未登记的族名（用户导入字体）原样返回。
 */
export function fontDisplayNameByFamily(family: string): string {
  if (family.length === 0) {
    return family;
  }
  for (const f of FONTS) {
    if (f.familyName === family) {
      return fontDisplayName(f.font);
    }
  }
  return family;
}

export function findMachine(kind: MachineKind): MachineSpec {
  for (const m of MACHINES) {
    if (m.kind === kind) {
      return m;
    }
  }
  return MACHINES[0];
}

export function findPaper(kind: PaperKind): PaperSpec {
  for (const p of PAPERS) {
    if (p.kind === kind) {
      return p;
    }
  }
  return PAPERS[0];
}

export function findRibbon(kind: RibbonKind): RibbonSpec {
  for (const r of RIBBONS) {
    if (r.kind === kind) {
      return r;
    }
  }
  return RIBBONS[0];
}

export function findFont(font: PaperFont): FontSpec {
  for (const f of FONTS) {
    if (f.font === font) {
      return f;
    }
  }
  return FONTS[0];
}