/**
 * 回车 · 文档模型内核（纯逻辑，零平台依赖）
 *
 * 单独成文件的理由：本模块不 import 任何 @kit.* / @ohos.*，
 * 因此可以在本地单测（entry/src/test/LocalUnit.test.ets）里直接跑，
 * 不需要真机或模拟器。存储 I/O 在 services/DocStore.ets。
 *
 * 硬约束：文档按行存数组 + 元数据 JSON（技术架构设计 §2），绝不存图片。
 */

import { CursorPos, DocData, DocLine, DocMeta, MachineKind, PaperFont, PaperKind, RibbonKind } from './DocModel';
import { DEFAULT_FONT, DEFAULT_MACHINE, DEFAULT_PAPER, DEFAULT_RIBBON } from './MachineCatalog';

/** 行内文本编辑结果，供上层决定是否触发行末预告铃。 */
export interface EditOutcome {
  /** 是否真的改变了文档内容。 */
  changed: boolean;
  /** 是否应响行末预告铃（距右边界约 8 字，且本行此前没响过）。 */
  marginBell: boolean;
  /** 是否发生了换行（上层做纸张弹簧上移 + 叮声）。 */
  lineBreak: boolean;
}

export function emptyDoc(): DocData {
  const now: number = Date.now();
  const meta: DocMeta = {
    machine: DEFAULT_MACHINE,
    paper: DEFAULT_PAPER,
    ribbon: DEFAULT_RIBBON,
    font: DEFAULT_FONT,
    createdAt: now,
    updatedAt: now,
  };
  const lines: DocLine[] = [{ text: '', ribbon: DEFAULT_RIBBON }];
  return { lines: lines, cursor: { line: 0, offset: 0 }, meta: meta };
}

/**
 * 文档内存模型。所有编辑返回 EditOutcome，绝不静默吞掉输入。
 *
 * 光标语义：cursor.offset 是"插入点"，0 表示该行最前，text.length 表示行尾。
 * 跨行退格：行首退格把本行并入上一行（对齐真实打字机行为）。
 */
export class DocModel {
  private lines: DocLine[] = [{ text: '', ribbon: DEFAULT_RIBBON }];
  private cursorPos: CursorPos = { line: 0, offset: 0 };
  private meta: DocMeta = emptyDoc().meta;
  /** 已响过预告铃的行号，避免同一行反复响。 */
  private bellRungLines: Set<number> = new Set<number>();

  constructor(data?: DocData) {
    if (data !== undefined) {
      this.lines = data.lines.length > 0 ? data.lines : [{ text: '', ribbon: DEFAULT_RIBBON }];
      this.cursorPos = this.clampCursor(data.cursor);
      this.meta = data.meta;
    }
  }

  getLines(): DocLine[] {
    return this.lines;
  }

  /** 换纸：清空为一张空白新纸（单空行、光标归零）。 */
  clear(): void {
    this.lines = [{ text: '', ribbon: DEFAULT_RIBBON }];
    this.cursorPos = { line: 0, offset: 0 };
    this.bellRungLines.clear();
  }

  getCursor(): CursorPos {
    return this.cursorPos;
  }

  getMeta(): DocMeta {
    return this.meta;
  }

  setMachine(kind: MachineKind): void {
    this.meta.machine = kind;
  }

  setPaper(kind: PaperKind): void {
    this.meta.paper = kind;
  }

  setFont(font: PaperFont): void {
    this.meta.font = font;
  }

  setRibbon(kind: RibbonKind): void {
    this.meta.ribbon = kind;
  }

  /** 当前文档是否只有一行且为空（用于判断"新纸"）。 */
  isEmpty(): boolean {
    return this.lines.length === 1 && this.lines[0].text.length === 0;
  }

  /** 全文字符数（成就系统累计字数口径用，阶段3）。 */
  charCount(): number {
    let n: number = 0;
    for (const line of this.lines) {
      n += line.text.length;
    }
    return n;
  }

  /**
   * 插入字符到光标处（单字符；中文走逐字落字时上层逐次调用）。
   *
   * @param ch 非空单字符
   * @param charsPerLine 当前纸面一行可容纳的字符数估算（用于行末预告铃）
   */
  insertText(ch: string, charsPerLine: number): EditOutcome {
    if (ch.length === 0) {
      return { changed: false, marginBell: false, lineBreak: false };
    }
    const lineIndex: number = this.cursorPos.line;
    const line: DocLine = this.lines[lineIndex];
    const offset: number = this.cursorPos.offset;
    line.text = line.text.substring(0, offset) + ch + line.text.substring(offset);
    this.cursorPos = { line: lineIndex, offset: offset + ch.length };
    this.meta.updatedAt = Date.now();

    let ring: boolean = false;
    const remaining: number = charsPerLine - this.cursorPos.offset;
    if (remaining <= 8 && remaining > 0 && !this.bellRungLines.has(lineIndex)) {
      this.bellRungLines.add(lineIndex);
      ring = true;
    }
    return { changed: true, marginBell: ring, lineBreak: false };
  }

  /** 在当前行插入一个空格并前进光标。 */
  insertSpace(charsPerLine: number): EditOutcome {
    return this.insertText(' ', charsPerLine);
  }

  /**
   * 退格删左侧。行首退格把本行并入上一行。
   * 中文"无预编辑时 deleteLeft 才删正文"的语义由输入法通道层保证，本类只执行删除。
   */
  backspace(): EditOutcome {
    const lineIndex: number = this.cursorPos.line;
    const offset: number = this.cursorPos.offset;
    const line: DocLine = this.lines[lineIndex];

    if (offset > 0) {
      line.text = line.text.substring(0, offset - 1) + line.text.substring(offset);
      this.cursorPos = { line: lineIndex, offset: offset - 1 };
      this.meta.updatedAt = Date.now();
      return { changed: true, marginBell: false, lineBreak: false };
    }
    if (lineIndex === 0) {
      return { changed: false, marginBell: false, lineBreak: false };
    }
    // 行首：本行并入上一行。
    const prev: DocLine = this.lines[lineIndex - 1];
    const mergeAt: number = prev.text.length;
    prev.text = prev.text + line.text;
    this.lines.splice(lineIndex, 1);
    this.cursorPos = { line: lineIndex - 1, offset: mergeAt };
    this.bellRungLines = this.shiftBellLines(lineIndex);
    this.meta.updatedAt = Date.now();
    return { changed: true, marginBell: false, lineBreak: false };
  }

  /**
   * XXX 覆盖（§7.3 第 8 步）：光标回退一格并在该字上打 X，错字保留 X 痕，光标停在 X 之后。
   * 与现代删除的区别：不删字，只覆盖；行首无可覆盖字符时返回 changed=false。
   */
  overwriteBack(): EditOutcome {
    const lineIndex: number = this.cursorPos.line;
    const offset: number = this.cursorPos.offset;
    if (offset <= 0) {
      return { changed: false, marginBell: false, lineBreak: false };
    }
    const line: DocLine = this.lines[lineIndex];
    line.text = line.text.substring(0, offset - 1) + 'X' + line.text.substring(offset);
    // 光标回退一格停在 X 上（§7.3 第 8 步：光标回退一格，错字保留 X 痕）
    this.cursorPos = { line: lineIndex, offset: offset - 1 };
    this.meta.updatedAt = Date.now();
    return { changed: true, marginBell: false, lineBreak: false };
  }

  /** 回车：在光标处断行（光标之后的文本移到新行）。 */
  newline(): EditOutcome {
    const lineIndex: number = this.cursorPos.line;
    const offset: number = this.cursorPos.offset;
    const line: DocLine = this.lines[lineIndex];
    const tail: string = line.text.substring(offset);
    line.text = line.text.substring(0, offset);
    const created: DocLine = { text: tail, ribbon: this.meta.ribbon };
    this.lines.splice(lineIndex + 1, 0, created);
    this.cursorPos = { line: lineIndex + 1, offset: 0 };
    this.bellRungLines = this.shiftBellLines(lineIndex + 1, 1);
    this.meta.updatedAt = Date.now();
    return { changed: true, marginBell: false, lineBreak: true };
  }

  /** 设置光标（阶段3 文档库 / 点击纸面用）。 */
  setCursor(pos: CursorPos): void {
    this.cursorPos = this.clampCursor(pos);
  }

  /** 导出为可落盘 DocData。 */
  toDocData(): DocData {
    return { lines: this.lines, cursor: this.cursorPos, meta: this.meta };
  }

  /** 纯文本视图：行与行用换行相连，末尾补一个换行。 */
  toPlainText(): string {
    const parts: string[] = [];
    for (const line of this.lines) {
      parts.push(line.text);
    }
    return parts.join('\n') + '\n';
  }

  /** 首行非空文本作标题，空则回退到调用方给的占位标题。 */
  title(fallback: string): string {
    for (const line of this.lines) {
      const t: string = line.text.trim();
      if (t.length > 0) {
        return t.length > 24 ? t.substring(0, 24) : t;
      }
    }
    return fallback;
  }

  private clampCursor(pos: CursorPos): CursorPos {
    const line: number = Math.max(0, Math.min(pos.line, this.lines.length - 1));
    const maxOffset: number = this.lines[line].text.length;
    return { line: line, offset: Math.max(0, Math.min(pos.offset, maxOffset)) };
  }

  /** 行插入后，把已响铃行号整体后移。 */
  private shiftBellLines(fromLine: number, delta: number = 1): Set<number> {
    const next: Set<number> = new Set<number>();
    this.bellRungLines.forEach((n: number) => {
      if (n >= fromLine) {
        next.add(n + delta);
      } else {
        next.add(n);
      }
    });
    return next;
  }
}
