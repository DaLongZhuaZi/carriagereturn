/**
 * 回车 · 文档数据模型（界面重设计稿定稿；逐行呈现字段在 §7.1 实施步再扩）
 *
 * 硬约束（开工提示词 §三）：文档按行存数组 + 元数据 JSON，另存纯文本 .txt；
 * 绝不学 Rebi 存图片。ArkTS 显式类型，禁 any/unknown、禁模板字面量。
 */

/** 色带（墨色）。黑为默认。§1 色板：黑 #1a1a1a / 蓝 #24407c / 红 #a33327。 */
export enum RibbonKind {
  BLACK = 'black',
  BLUE = 'blue',
  RED = 'red',
}

/** 纸张。信纸为默认。 */
export enum PaperKind {
  LETTER = 'letter',
  MANUSCRIPT = 'manuscript',
  POSTCARD = 'postcard',
  MEMO = 'memo',
}

/** 机器（虚构时代机）。1920s 直立式座机为默认机。 */
export enum MachineKind {
  UPRIGHT_1920S = '1920s-upright',
  PORTABLE_1930S = '1930s-portable',
  STREAMLINED_1950S = '1950s-streamlined',
  ELECTRIC_1960S = '1960s-electric',
}

/** 纸面字体（17 款，§8.4 全量进换装字体区）。 */
export enum PaperFont {
  COURIER_PRIME = 'courier-prime',
  SPECIAL_ELITE = 'special-elite',
  IM_FELL_ENGLISH = 'im-fell-english',
  ANONYMOUS_PRO = 'anonymous-pro',
  SPACE_MONO = 'space-mono',
  XANH_MONO = 'xanh-mono',
  NOTO_SERIF_SC = 'noto-serif-sc',
  LXGW_WENKAI = 'lxgw-wenkai',
  ZHUQUE_FANGSONG = 'zhuque-fangsong',
  MA_SHAN_ZHENG = 'ma-shan-zheng',
  ZHI_MANG_XING = 'zhi-mang-xing',
  LONG_CANG = 'long-cang',
  CAVEAT = 'caveat',
  KALAM = 'kalam',
  PATRICK_HAND = 'patrick-hand',
  SHADOWS_INTO_LIGHT = 'shadows-into-light',
  HOMEMADE_APPLE = 'homemade-apple',
}

/** 修正方式（§6 设置页 / §7.3 第 8 步）。 */
export enum CorrectionMode {
  MODERN = 'modern',
  OVERWRITE = 'overwrite',
}

/**
 * 一行落字。
 * - text 只存该行可见字符，不含换行符（换行以"新的一行"表示）。
 * - ribbon 记录该行落字时的色带：同一文档内换装不影响已有落字。
 */
export interface DocLine {
  text: string;
  ribbon: RibbonKind;
}

/** 一份文档的元数据。 */
export interface DocMeta {
  machine: MachineKind;
  paper: PaperKind;
  ribbon: RibbonKind;
  font: PaperFont;
  createdAt: number;
  updatedAt: number;
  /** 第 12 批 ②：当前纸序号（1 起，换纸+1；老文档缺省按 1 计）。 */
  sheetNo?: number;
  /** 第 12 批 ②：本篇文档用过的纸总数（无翻页时恒等于 sheetNo）。 */
  sheetCount?: number;
}

/** 刻度光标。line 为 lines 下标，offset 为该行内字符偏移（0..text.length）。 */
export interface CursorPos {
  line: number;
  offset: number;
}

/** 一份完整文档。 */
export interface DocData {
  lines: DocLine[];
  cursor: CursorPos;
  meta: DocMeta;
  /** 所属卷宗 id；null/缺省 = 未归档（§5 卷宗系统）。 */
  dossierId?: string | null;
}

/** 文档库列表项。 */
export interface DocSummary {
  id: string;
  title: string;
  createdAt: number;
  updatedAt: number;
  machine: MachineKind;
  paper: PaperKind;
  /** 所属卷宗 id；null/缺省 = 未归档。 */
  dossierId?: string | null;
  /** 正文字数（去空白），随列表一起算好，避免卡片渲染期读文件。 */
  charCount?: number;
  /** P2-9：缩略图正文（前 3 行），随列表一次算好，卡片不再 build 期读文件。 */
  preview?: string;
  /** 第 6 批 F10：入回收站时间（active 文档无值）。 */
  trashedAt?: number;
  /** 第 6 批 F10：入回收站前所属卷宗（恢复时回原卷宗）。 */
  origDossierId?: string | null;
}
