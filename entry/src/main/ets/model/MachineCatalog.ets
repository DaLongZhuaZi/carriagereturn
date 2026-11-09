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
  /** 解锁庆祝背景（主屏不用，见 §8.1）。 */
  heroRawfile: string;
  /** 主屏照片键区：手机带（2048×975，2.1:1）。 */
  keybandPhoneRawfile: string;
  /** 主屏照片键区：折叠半开下半屏带（2048×853，2.4:1；1930s 复用手机带）。 */
  keybandFoldRawfile: string;
  /** 键位坐标表。 */
  keymapRawfile: string;
  /** 主屏字车条（carriage-strip.png，各机已按 45%~59% 等带切好）。 */
  carriageStripRawfile: string;
  /** 主屏字杆击打层（仅 1920s 有完整动画层，其余三台延后，不用占位顶替）。 */
  typebarRawfile: string;
  /** 主屏拨杆动画层（同上）。 */
  leverRawfile: string;
  /** 字车层（换行回位用）。 */
  carriageLayerRawfile: string;
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
export const FUNCTION_ROW_HEIGHT_VP: number = 52;
export const KEYBOARD_HEIGHT_VP: number = KEYBED_HEIGHT_VP + FUNCTION_ROW_HEIGHT_VP;

export const MACHINES: MachineSpec[] = [
  {
    kind: MachineKind.UPRIGHT_1920S,
    heroRawfile: 'machine/1920s-upright-hero-3q.jpg',
    keybandPhoneRawfile: 'machine/1920s-upright-keyband-phone.jpg',
    keybandFoldRawfile: 'machine/1920s-upright-keyband-fold.jpg',
    keymapRawfile: 'keymap/1920s-upright-keymap.json',
    carriageStripRawfile: 'carriage/1920s-upright-carriage-strip.png',
    typebarRawfile: 'typebar/1920s-typebar-vertical.png',
    leverRawfile: 'typebar/1920s-lever-single.png',
    carriageLayerRawfile: 'typebar/1920s-carriage-layer.png',
    overlayColor: '#312b24',
    overlayFontSizeVp: 14,
    bodyColor: '#312b24',
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
    heroRawfile: 'machine/1930s-portable-hero.jpg',
    keybandPhoneRawfile: 'machine/1930s-portable-keyband-phone.jpg',
    // §4：fold 图已入仓（machine/1930s-portable-keyband-fold.jpg），改指 fold 带
    keybandFoldRawfile: 'machine/1930s-portable-keyband-fold.jpg',
    keymapRawfile: 'keymap/1930s-portable-keymap.json',
    carriageStripRawfile: 'carriage/1930s-portable-carriage-strip.png',
    // §4：1930s 分层素材已到，三个字段填上
    typebarRawfile: 'typebar/1930s-portable-typebar-vertical.png',
    leverRawfile: 'typebar/1930s-portable-lever-single.png',
    carriageLayerRawfile: 'typebar/1930s-portable-carriage-layer.png',
    overlayColor: '#dbccb3',
    overlayFontSizeVp: 14,
    bodyColor: '#3d3732',
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
    heroRawfile: 'machine/1950s-streamlined-hero.jpg',
    keybandPhoneRawfile: 'machine/1950s-streamlined-keyband-phone.jpg',
    keybandFoldRawfile: 'machine/1950s-streamlined-keyband-fold.jpg',
    keymapRawfile: 'keymap/1950s-streamlined-keymap.json',
    carriageStripRawfile: 'carriage/1950s-streamlined-carriage-strip.png',
    typebarRawfile: 'typebar/1950s-streamlined-typebar-vertical.png',
    leverRawfile: 'typebar/1950s-streamlined-lever-single.png',
    carriageLayerRawfile: 'typebar/1950s-streamlined-carriage-layer.png',
    overlayColor: '#312b24',
    overlayFontSizeVp: 14,
    bodyColor: '#c8b9a6',
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
    heroRawfile: 'machine/1960s-electric-hero.jpg',
    keybandPhoneRawfile: 'machine/1960s-electric-keyband-phone.jpg',
    keybandFoldRawfile: 'machine/1960s-electric-keyband-fold.jpg',
    keymapRawfile: 'keymap/1960s-electric-keymap.json',
    carriageStripRawfile: 'carriage/1960s-electric-carriage-strip.png',
    typebarRawfile: 'typebar/1960s-electric-typebar-vertical.png',
    leverRawfile: 'typebar/1960s-electric-lever-single.png',
    carriageLayerRawfile: 'typebar/1960s-electric-carriage-layer.png',
    overlayColor: '#312b24',
    overlayFontSizeVp: 14,
    bodyColor: '#928b82',
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
