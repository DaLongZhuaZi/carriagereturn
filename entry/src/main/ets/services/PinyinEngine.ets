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
export interface PinyinStateValues {
  IDLE: number;
  COMPOSING: number;
  RESIDUAL: number;
}
export const PinyinState: PinyinStateValues = {
  IDLE: 0,
  COMPOSING: 1,
  RESIDUAL: 2,
};

/** 选词结果：提交文本 + 余量拼音串。 */
export interface PickResult {
  text: string;
  residual: string;
}

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
  /** 用户自定义词：拼音串 → 词（置顶） */
  private userWords: Map<string, string[]> = new Map<string, string[]>();
  /** 选词学习：拼音串 → (词 → 次数)。次数越高越靠前。 */
  private learn: Map<string, Map<string, number>> = new Map<string, Map<string, number>>();
  /** 模糊音开关（默认关）。 */
  private fuzzy: boolean = false;

  /** 从词库 JSON 构造（Node 与 ArkTS 同一入口）。 */
  static fromData(data: PinyinDictData): PinyinEngine {
    const e: PinyinEngine = new PinyinEngine();
    e.load(data);
    return e;
  }

  load(data: PinyinDictData): void {
    this.chars.clear();
    this.words.clear();
    this.syllables.clear();
    this.maxSylLen = 0;
    const ck: string[] = Object.keys(data.chars);
    for (let i = 0; i < ck.length; i++) {
      const k: string = ck[i];
      this.chars.set(k, data.chars[k]);
      this.addSyllable(k);
    }
    const wk: string[] = Object.keys(data.words);
    for (let i = 0; i < wk.length; i++) {
      const k: string = wk[i];
      this.words.set(k, data.words[k]);
    }
  }

  /** §11.3 模糊表：8 组（双向）。键为规范形，值为等价形列表。 */
  private static readonly FUZZY_PAIRS: string[][] = [
    ['zh', 'z'], ['ch', 'c'], ['sh', 's'],
    ['in', 'ing'], ['en', 'eng'], ['an', 'ang'],
    ['n', 'l'], ['f', 'h'],
  ];

  setFuzzy(on: boolean): void {
    this.fuzzy = on;
  }

  isFuzzy(): boolean {
    return this.fuzzy;
  }

  /** 把音节按模糊表展开成等价集合（含自身）。 */
  private fuzzyVariants(syl: string): string[] {
    if (!this.fuzzy) {
      return [syl];
    }
    let forms: string[] = [syl];
    for (let p = 0; p < PinyinEngine.FUZZY_PAIRS.length; p++) {
      const a: string = PinyinEngine.FUZZY_PAIRS[p][0];
      const b: string = PinyinEngine.FUZZY_PAIRS[p][1];
      const next: string[] = [];
      for (let i = 0; i < forms.length; i++) {
        const f: string = forms[i];
        next.push(f);
        if (f.startsWith(a)) {
          const v: string = b + f.substring(a.length);
          if (next.indexOf(v) < 0) { next.push(v); }
        }
        if (f.startsWith(b)) {
          const v2: string = a + f.substring(b.length);
          if (next.indexOf(v2) < 0) { next.push(v2); }
        }
      }
      forms = next;
    }
    return forms;
  }

  /** 判断某字母片段是否可由音节（或其模糊等价形）覆盖。 */
  private matchSyllable(piece: string): string[] {
    const hits: string[] = [];
    if (this.syllables.has(piece)) {
      hits.push(piece);
    }
    if (this.fuzzy) {
      const forms: string[] = this.fuzzyVariants(piece);
      for (let i = 0; i < forms.length; i++) {
        if (forms[i] !== piece && this.syllables.has(forms[i])) {
          hits.push(forms[i]);
        }
      }
    }
    return hits;
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
        const hits: string[] = this.matchSyllable(piece);
        for (let h = 0; h < hits.length; h++) {
          acc.push(hits[h]);
          walk(pos + len, acc);
          acc.pop();
        }
      }
    };
    walk(0, []);
    return out;
  }

  /** 我的词库：拼音串 → 词（置顶）。 */
  setUserWords(data: Record<string, string[]>): void {
    this.userWords.clear();
    const keys: string[] = Object.keys(data);
    for (let i = 0; i < keys.length; i++) {
      this.userWords.set(keys[i], data[keys[i]]);
    }
  }

  /** 选词学习：拼音串 → (词 → 次数)。 */
  setLearnData(data: Record<string, Record<string, number>>): void {
    this.learn.clear();
    const keys: string[] = Object.keys(data);
    for (let i = 0; i < keys.length; i++) {
      const inner: Record<string, number> = data[keys[i]];
      const m: Map<string, number> = new Map<string, number>();
      const wk: string[] = Object.keys(inner);
      for (let j = 0; j < wk.length; j++) {
        m.set(wk[j], inner[wk[j]]);
      }
      this.learn.set(keys[i], m);
    }
  }

  learnWord(py: string, word: string): void {
    let m: Map<string, number> | undefined = this.learn.get(py);
    if (m === undefined) {
      m = new Map<string, number>();
      this.learn.set(py, m);
    }
    m.set(word, (m.get(word) === undefined ? 0 : m.get(word) as number) + 1);
  }

  /** 导出学习记录（供落盘）。 */
  exportLearn(): Record<string, Record<string, number>> {
    const out: Record<string, Record<string, number>> = {};
    this.learn.forEach((m: Map<string, number>, py: string) => {
      const inner: Record<string, number> = {};
      m.forEach((n: number, w: string) => { inner[w] = n; });
      out[py] = inner;
    });
    return out;
  }

  /** 我的词库入库：拼音串 + 词（置顶）。 */
  addUserWordWithPinyin(py: string, word: string): void {
    let arr: string[] | undefined = this.userWords.get(py);
    if (arr === undefined) {
      arr = [];
      this.userWords.set(py, arr);
    }
    if (arr.indexOf(word) < 0) {
      arr.unshift(word);
    }
  }

  /** 导出我的词库（供落盘）。 */
  exportUserWords(): Record<string, string[]> {
    const out: Record<string, string[]> = {};
    this.userWords.forEach((arr: string[], py: string) => {
      out[py] = arr;
    });
    return out;
  }

  /** 由中文词组推导拼音：逐字取字表首位读音。 */
  pinyinOfWord(word: string): string {
    const inv: Map<string, string> = new Map<string, string>();
    this.chars.forEach((arr: string[], syl: string) => {
      for (let i = 0; i < arr.length; i++) {
        if (!inv.has(arr[i])) {
          inv.set(arr[i], syl);
        }
      }
    });
    let py: string = '';
    for (let i = 0; i < word.length; i++) {
      const s: string | undefined = inv.get(word.charAt(i));
      if (s === undefined) {
        return '';
      }
      py = py + s;
    }
    return py;
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
    // ① 我的词库（置顶）
    const mine: string[] = this.userWords.get(s) === undefined ? [] : this.userWords.get(s) as string[];
    for (let i = 0; i < mine.length; i++) {
      push(mine[i], 0, s);
    }
    // ② 学习记录（同拼音串内按次数降序置顶）
    const learned: Map<string, number> | undefined = this.learn.get(s);
    if (learned !== undefined) {
      const lw: string[] = [];
      learned.forEach((n: number, w: string) => {
        for (let k = 0; k < n && lw.length < 8; k++) {
          lw.push(w);
        }
      });
      const seenL: Set<string> = new Set<string>();
      for (let i = 0; i < lw.length; i++) {
        if (!seenL.has(lw[i])) {
          seenL.add(lw[i]);
          push(lw[i], 0, s);
        }
      }
    }
    // ③ 内置整串词
    const whole: string[] = this.wordsOf(s);
    for (let i = 0; i < whole.length; i++) {
      push(whole[i], 0, s);
    }
    let segs: string[][] = this.segments(s);
    if (segs.length === 0 && s.length > 1) {
      // §11.1：整串无合法切分 → 退到最长合法前缀出候选（nih → 按 ni 出候选）
      let best: string = '';
      let bestSegs: string[][] = [];
      for (let len = s.length - 1; len >= 1; len--) {
        const pre: string = s.substring(0, len);
        const ps: string[][] = this.segments(pre);
        if (ps.length > 0) {
          best = pre;
          bestSegs = ps;
          break;
        }
      }
      if (best.length > 0) {
        // 前缀本身若是整词，也放进候选
        const pw: string[] = this.wordsOf(best);
        for (let i = 0; i < pw.length; i++) {
          push(pw[i], 0, best);
        }
        const pm: string[] = this.userWords.get(best) === undefined ? [] : this.userWords.get(best) as string[];
        for (let i = 0; i < pm.length; i++) {
          push(pm[i], 0, best);
        }
        segs = bestSegs;
      }
    }
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
  private state: number = PinyinState.IDLE;
  private picked: string[] = [];

  constructor(engine: PinyinEngine) {
    this.engine = engine;
  }

  getState(): number {
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
  pick(c: Candidate): PickResult {
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
    const result: PickResult = { text: c.text, residual: rest };
    return result;
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
