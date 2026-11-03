/**
 * 回车 · 纸面渲染组件契约（阶段1 定稿）
 *
 * 实现要求（调研报告 §2 + 风格板 §5）：
 * - 纸面主体 List + LazyForEach + @Reusable，cachedCount 约半屏；
 * - 光标行锚定：纸张随打字上移，当前行停在打字区高度，不每敲一字移动整张纸；
 * - 墨色以段为单位换 fontColor（RibbonKind 落在行上），做旧深浅以行为单位微调透明度；
 * - 格线 / 边距 / 红格 / 页眉一律代码层画，纸纹只作背景。
 *
 * 服务不写死文案：纸面常驻引导句由调用方传入 resource 句柄解析后的字符串。
 */

import { CursorPos, DocLine, PaperFont } from '../model/DocModel';

export interface PaperRow {
  /** DocLine 的索引，作为 LazyForEach 的 key 与 List 位置。 */
  line: number;
  text: string;
  /** 该行落字时的色带。 */
  ribbon: string;
  /** 该行是否仍在编辑中（决定光标是否画在此行）。 */
  active: boolean;
}

/** 纸面显示参数。三态切换只换这些布局参数，不重建编辑器（技术架构设计 §4）。 */
export interface PaperViewSpec {
  paperKind: string;
  paperTexture: string;
  paperWidthVp: number;
  fontSizeVp: number;
  lineHeightRatio: number;
  marginHVp: number;
  marginVVp: number;
  fontFamily: string;
  hasGrid: boolean;
  hasHeader: boolean;
}

/** 纸面组件对外接口。 */
export interface PaperSheetExposed {
  /** 行数据变化后调用；实现方需做增量刷新，避免整表重建。 */
  refresh(): void;
  /** 光标移动后调用，负责把当前行滚入可见区。 */
  followCursor(pos: CursorPos): void;
}
