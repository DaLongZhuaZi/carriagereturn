/**
 * 回车 · 文档数据模型（阶段1 定稿）
 *
 * 硬约束（开工提示词 §三）：文档按行存数组 + 元数据 JSON，另存纯文本 .txt；
 * 绝不学 Rebi 存图片。ArkTS 显式类型，禁 any/unknown。
 *
 * 本文件是阶段1 的接口契约：字段名一旦定下，各组件与服务按此实现，
 * 改动需同步 DocStore / PaperSheet / MainScreen 与本文件注释。
 */

/** 色带（墨色）。黑为默认。 */
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

/** 机器（虚构时代机）。1920s 直立式座机为默认机，其余由成就解锁。 */
export enum MachineKind {
  UPRIGHT_1920S = '1920s-upright',
  PORTABLE_1930S = '1930s-portable',
  STREAMLINED_1950S = '1950s-streamlined',
  ELECTRIC_1960S = '1960s-electric',
}

/** 纸面字体（资源文件内注册的 familyName，见 resource/MachineCatalog.ets）。 */
export enum PaperFont {
  COURIER_PRIME = 'CourierPrime',
  SPECIAL_ELITE = 'SpecialElite',
  NOTO_SERIF_SC = 'NotoSerifSC',
  LXGW_WENKAI = 'LXGWWenKai',
}

/**
 * 一行落字。
 *
 * - `text` 只存该行可见字符，不含换行符（换行以"新的一行"表示）。
 * - `ribbon` 记录该行落字时的色带：同一文档内换装不影响已有落字，
 *   已落字保留换装前的色带呈现（技术架构设计 §2）。
 */
export interface DocLine {
  text: string;
  ribbon: RibbonKind;
}

/** 一份文档的元数据。 */
export interface DocMeta {
  /** 每次换机写入当前值，不回溯修改已落字。 */
  machine: MachineKind;
  paper: PaperKind;
  /** 新建文档时的默认色带；行进级色带在 DocLine.ribbon。 */
  ribbon: RibbonKind;
  font: PaperFont;
  createdAt: number;
  updatedAt: number;
}

/** 刻度光标。`line` 为 lines 下标，`offset` 为该行内字符偏移（0..text.length）。 */
export interface CursorPos {
  line: number;
  offset: number;
}

/** 一份完整文档。 */
export interface DocData {
  lines: DocLine[];
  cursor: CursorPos;
  meta: DocMeta;
}

/** 新建文档的标题/文件名。取首行非空文本，空则回退。 */
export interface DocSummary {
  id: string;
  title: string;
  createdAt: number;
  updatedAt: number;
  machine: MachineKind;
  paper: PaperKind;
}
