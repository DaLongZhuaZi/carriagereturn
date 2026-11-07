/**
 * 回车 CarriageReturn —— 内置拼音引擎（纯 TypeScript，不含任何鸿蒙 API／装饰器）
 *
 * 设计事实源：docs/内置拼音输入法设计.md §3。
 * 本文件必须能在 Node 下直接跑单测（测试时复制为 .ts 或经 tsc 编译）。
 *
 * 数据：音节表、charMap（音节→字[]）、wordMap（拼音串→词[]，已按词频序）。
 */

export interface PinyinDictData {
  /** 音节 → 字（按常用度近似序） */
  chars: Record<string, string[]>;
  /** 拼音串（无调、v=ü）→ 词（词频降序） */
  words: Record<string, string[]>;
}

/** 会话三态（设计稿 §4）。用常量对象而非 enum —— enum 不是可擦除语法，Node strip-types 跑不了。 */
export const PinyinState = {
  IDLE: 0,
  COMPOSING: 1,
  RESIDUAL: 2,
};
export type PinyinStateValue = number;

export interface Candidate {
  text: string;
  /** 0 = 词，1 = 单字回退 */
  kind: number;
  /** 来源拼音（整串或音节） */
  pinyin: string;
}

export class PinyinEngine {
  private syllables: Set<string> = new Set<string>();
  private maxSylLen: number = 0;
  private chars: Map<string, string[]> = new Map<string, string[]>();
  private words: Map<string, string[]> = new Map<string, string[]>();

  /** 从词库 JSON 构造（Node 与 ArkTS 同一入口）。 */
  static fromData(data: PinyinDictData): PinyinEngine {
    const e = new PinyinEngine();
    e.load(data);
    return e;
  }

  load(data: PinyinDictData): void {
    this.chars.clear();
    this.words.clear();
    this.syllables.clear();
    this.maxSylLen = 0;
    const ck: string[] = Object.keys(data.chars || {});
    for (let i = 0; i < ck.length; i++) {
      const k: string = ck[i];
      this.chars.set(k, data.chars[k]);
      this.addSyllable(k);
    }
    const wk: string[] = Object.keys(data.words || {});
    for (let i = 0; i < wk.length; i++) {
      const k: string = wk[i];
      this.words.set(k, data.words[k]);
    }
  }

  private addSyllable(s: string): void {
    if (!s || s.length === 0) {
      return;
    }
    this.syllables.add(s);
    if (s.length > this.maxSylLen) {
      this.maxSylLen = s.length;
    }
  }

  syllableCount(): number {
    return this.syllables.size;
  }

  /** 单音节查字（候选用）。 */
  charsOf(syl: string): string[] {
    const v = this.chars.get(syl);
    return v === undefined ? [] : v;
  }

  wordsOf(py: string): string[] {
    const v = this.words.get(py);
    return v === undefined ? [] : v;
  }

  /**
   * 切分：把字母串按音节表 DP 拆开。返回所有「全音节覆盖」的拆法（最多 64 种，防爆炸）。
   * 拆不出（含非法片段）返回空数组。
   */
  segments(input: string): string[][] {
    const s: string = input.toLowerCase();
    const n: number = s.length;
    const out: string[][] = [];
    if (n === 0) {
      return out;
    }
    const limit: number = 64;
    const walk = (pos: number, acc: string[]): void => {
      if (out.length >= limit) {
        return;
      }
      if (pos === n) {
        out.push(acc.slice());
        return;
      }
      const maxLen: number = Math.min(this.maxSylLen, n - pos);
      for (let len = maxLen; len >= 1; len--) {
        const piece: string = s.substring(pos, pos + len);
        if (this.syllables.has(piece)) {
          acc.push(piece);
          walk(pos + len, acc);
          acc.pop();
        }
      }
    };
    walk(0, []);
    return out;
  }

  /** 该串是否为合法拼音（能被音节表完整覆盖）。 */
  isValid(input: string): boolean {
    return this.segments(input).length > 0;
  }

  /**
   * 候选：整串词优先（词频序），其后按切分逐段补单词与单字。
   * 返回最多 limit 条。
   */
  candidates(input: string, limit: number = 8): Candidate[] {
    const s: string = input.toLowerCase();
    const res: Candidate[] = [];
    const seen: Set<string> = new Set<string>();
    const push = (text: string, kind: number, py: string): void => {
      if (res.length >= limit || seen.has(text)) {
        return;
      }
      seen.add(text);
      res.push({ text: text, kind: kind, pinyin: py });
    };
    const whole: string[] = this.wordsOf(s);
    for (let i = 0; i < whole.length; i++) {
      push(whole[i], 0, s);
    }
    const segs: string[][] = this.segments(s);
    for (let i = 0; i < segs.length; i++) {
      const seg: string[] = segs[i];
      for (let j = 0; j < seg.length; j++) {
        // 从第 j 个音节起逐段累加，查多音节词（这样候选带着「消费了几个音节」的拼音串）
        // 长词优先：先试最长（最多 4 个音节），再逐段缩短；单音节词不算「词」，
        // 否则「ni→你」会抢在「nihao→你好」前面
        for (let span = Math.min(4, seg.length - j); span >= 2; span--) {
          let acc: string = '';
          for (let k = j; k < j + span; k++) {
            acc = acc + seg[k];
          }
          if (acc === s) {
            continue;
          }
          const ws: string[] = this.wordsOf(acc);
          for (let m = 0; m < ws.length && m < 3; m++) {
            push(ws[m], 0, acc);
          }
        }
        const cs: string[] = this.charsOf(seg[j]);
        for (let m = 0; m < cs.length && m < 4; m++) {
          push(cs[m], 1, seg[j]);
        }
      }
    }
    const cs0: string[] = this.charsOf(s);
    for (let k = 0; k < cs0.length && k < 4; k++) {
      push(cs0[k], 1, s);
    }
    return res;
  }
}

/**
 * 会话：三态机，只管拼音串与余量，不碰 UI、不碰文档。
 * 接线（第 3 批）时由 onCapDown 驱动。
 */
export class PinyinSession {
  private engine: PinyinEngine;
  private buffer: string = '';
  private residual: string = '';
  private state: PinyinState = PinyinState.IDLE;
  private picked: string[] = [];

  constructor(engine: PinyinEngine) {
    this.engine = engine;
  }

  getState(): PinyinState {
    return this.state;
  }

  /** 组词中/余量时的拼音串 */
  getBuffer(): string {
    return this.buffer;
  }

  getResidual(): string {
    return this.residual;
  }

  isComposing(): boolean {
    return this.buffer.length > 0;
  }

  /** 一次字母输入；返回是否需要刷新候选栏。 */
  typeLetter(ch: string): boolean {
    if (!/^[a-zA-Z]$/.test(ch)) {
      return false;
    }
    this.buffer = this.buffer + ch.toLowerCase();
    this.state = PinyinState.COMPOSING;
    return true;
  }

  currentCandidates(limit: number = 8): Candidate[] {
    if (this.buffer.length === 0) {
      return [];
    }
    return this.engine.candidates(this.buffer, limit);
  }

  /** 退格：只动拼音串。 */
  backspace(): boolean {
    if (this.buffer.length === 0) {
      return false;
    }
    this.buffer = this.buffer.substring(0, this.buffer.length - 1);
    if (this.buffer.length === 0) {
      this.state = PinyinState.IDLE;
    }
    return true;
  }

  /**
   * 选词：把选中的词提交，余量字母（若候选拼音短于 buffer）继续组词。
   * 返回 { text, residual }。
   */
  pick(c: Candidate): { text: string, residual: string } {
    const usedPy: string = c.pinyin;
    let rest: string = '';
    if (this.buffer.length > usedPy.length && this.buffer.indexOf(usedPy) === 0) {
      rest = this.buffer.substring(usedPy.length);
    }
    this.picked.push(c.text);
    this.buffer = rest;
    this.residual = rest;
    this.state = rest.length > 0 ? PinyinState.RESIDUAL : PinyinState.IDLE;
    if (this.state === PinyinState.RESIDUAL) {
      this.state = PinyinState.COMPOSING;
    }
    return { text: c.text, residual: rest };
  }

  /** 取消组词（Esc）。 */
  cancel(): void {
    this.buffer = '';
    this.residual = '';
    this.state = PinyinState.IDLE;
  }

  pickedCount(): number {
    return this.picked.length;
  }
}
