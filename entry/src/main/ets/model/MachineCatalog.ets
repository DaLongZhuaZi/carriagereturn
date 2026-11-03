/**
 * 回车 · 机器 / 纸张 / 色带 / 字体 目录（阶段1 定稿）
 *
 * 所有 rawfile 路径与展示参数集中在此，组件不写死路径。
 * 素材进仓方式：rawfile 下按机器图 / 纸纹 / 字体 / 音效分目录（技术架构设计 §3）。
 * 资源文件名去品牌化：品牌名只留在 SOURCE.txt，不进资源路径或界面文案。
 */

import { MachineKind, PaperFont, PaperKind, RibbonKind } from './DocModel';

/** 一台机器在阶段1 需要的资源与字形参数。 */
export interface MachineSpec {
  kind: MachineKind;
  /** 机器 hero 图 rawfile 相对路径（不含 'machine/' 前缀）。 */
  heroRawfile: string;
  /** 主屏键盘区使用的音效包目录名（rawfile/sound/<pack>/）。 */
  soundPack: string;
  /** 键帽底色（风格板 §2 各台取色锁定）。 */
  keycapColor: string;
  /** 机身主色，用于主屏背景与阴影。 */
  bodyColor: string;
  /** 纸面字号（vp），各台纸面适配不同。 */
  fontScale: number;
  /** 纸面行高倍率，各台纸面适配不同。 */
  lineHeightRatio: number;
}

/** 一张纸的资源与字样参数。格线 / 边距 / 红格 / 页眉一律代码层画，不 baked 进纹理。 */
export interface PaperSpec {
  kind: PaperKind;
  /** 纸纹 rawfile 相对路径（不含 'paper/' 前缀）。 */
  textureRawfile: string;
  /** 会画格线吗（稿纸为方格）。 */
  hasGrid: boolean;
  /** 会画页眉吗（信纸）。 */
  hasHeader: boolean;
  /** 内容区左右边距（vp）。 */
  marginH: number;
  /** 内容区上下边距（vp）。 */
  marginV: number;
}

/** 色带的墨色与做旧参数。 */
export interface RibbonSpec {
  kind: RibbonKind;
  /** 落字颜色（ARGB 串，直接给 Text.fontColor）。 */
  inkColor: string;
  /** 该色带的纸面整体透明度，做旧以行为单位微调（风格板 §5）。 */
  inkAlpha: number;
}

/** 一款纸面字体。 */
export interface FontSpec {
  font: PaperFont;
  /** rawfile 下的字体文件（不含 'font/' 前缀）。 */
  rawfile: string;
  /** registerFont 的 familyName。 */
  familyName: string;
}

export const DEFAULT_MACHINE: MachineKind = MachineKind.UPRIGHT_1920S;
export const DEFAULT_PAPER: PaperKind = PaperKind.LETTER;
export const DEFAULT_RIBBON: RibbonKind = RibbonKind.BLACK;
export const DEFAULT_FONT: PaperFont = PaperFont.COURIER_PRIME;

/** 阶段1 只实现默认机；其余三台资源在仓内，随阶段3 上线。 */
export const MACHINES: MachineSpec[] = [
  {
    kind: MachineKind.UPRIGHT_1920S,
    heroRawfile: 'machine/1920s-upright-hero-3q.jpg',
    soundPack: 'pack',
    keycapColor: '#dbccb3',
    bodyColor: '#312b24',
    fontScale: 16,
    lineHeightRatio: 1.7,
  },
  {
    kind: MachineKind.PORTABLE_1930S,
    heroRawfile: 'machine/1930s-portable-hero.jpg',
    soundPack: 'pack',
    keycapColor: '#342e28',
    bodyColor: '#3d3732',
    fontScale: 16,
    lineHeightRatio: 1.7,
  },
  {
    kind: MachineKind.STREAMLINED_1950S,
    heroRawfile: 'machine/1950s-streamlined-hero.jpg',
    soundPack: 'pack',
    keycapColor: '#d0c1ad',
    bodyColor: '#b4ab9f',
    fontScale: 17,
    lineHeightRatio: 1.65,
  },
  {
    kind: MachineKind.ELECTRIC_1960S,
    heroRawfile: 'machine/1960s-electric-hero.jpg',
    soundPack: 'pack',
    keycapColor: '#bfb8ae',
    bodyColor: '#928b82',
    fontScale: 17,
    lineHeightRatio: 1.65,
  },
];

export const PAPERS: PaperSpec[] = [
  { kind: PaperKind.LETTER, textureRawfile: 'paper/paper-letter.jpg', hasGrid: false, hasHeader: true, marginH: 28, marginV: 32 },
  { kind: PaperKind.MANUSCRIPT, textureRawfile: 'paper/paper-manuscript.jpg', hasGrid: true, hasHeader: false, marginH: 24, marginV: 28 },
  { kind: PaperKind.POSTCARD, textureRawfile: 'paper/paper-postcard.jpg', hasGrid: false, hasHeader: false, marginH: 22, marginV: 24 },
  { kind: PaperKind.MEMO, textureRawfile: 'paper/paper-memo.jpg', hasGrid: false, hasHeader: false, marginH: 20, marginV: 22 },
];

export const RIBBONS: RibbonSpec[] = [
  { kind: RibbonKind.BLACK, inkColor: '#15120e', inkAlpha: 1 },
  { kind: RibbonKind.BLUE, inkColor: '#1c2f52', inkAlpha: 0.95 },
  { kind: RibbonKind.RED, inkColor: '#6d1f18', inkAlpha: 0.95 },
];

/** 阶段1 只注册英文默认字体；中文两款随阶段2 中文通道上线。 */
export const FONTS: FontSpec[] = [
  { font: PaperFont.COURIER_PRIME, rawfile: 'font/CourierPrime-Regular.ttf', familyName: 'CourierPrime' },
  { font: PaperFont.SPECIAL_ELITE, rawfile: 'font/SpecialElite-Regular.ttf', familyName: 'SpecialElite' },
  { font: PaperFont.NOTO_SERIF_SC, rawfile: 'font/NotoSerifSC-wght.ttf', familyName: 'NotoSerifSC' },
  { font: PaperFont.LXGW_WENKAI, rawfile: 'font/LXGWWenKai-Regular.ttf', familyName: 'LXGWWenKai' },
];

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
