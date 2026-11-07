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
  /** 词频序（加载顺序即词频序）：缩写候选按它排序，避免被 nanhai 这类同缩写词挤掉你好。 */
  private wordRank: Map<string, number> = new Map<string, number>();
  /** 缩写候选的先后＝首次出现的先后（JSON 键顺序即词频序），不再逐词建 wordRank */
  private abbrevOrder: Map<string, number> = new Map<string, number>();
  private abbrevSeq: number = 0;
  /** 词频序键数组（JSON 键顺序＝词频序），缩写排序用 */
  private freqKeys: string[] = [];
  /** 词 → 所在键的下标（缩写排序用，惰性填充） */
  private wordKeyCache: Map<string, number> = new Map<string, number>();
  /** 全部拼音键的有序数组（词前缀候选用二分查找，不许每击键全表扫）。 */
  private sortedKeys: string[] = [];
  /** 声母缩写索引：词的拼音按音节取首字母（如 你好→nh），上限 4 字母。 */
  private abbrev: Map<string, string[]> = new Map<string, string[]>();
  /** 用户自定义词：拼音串 → 词（置顶） */
  private userWords: Map<string, string[]> = new Map<string, string[]>();
  /** 选词学习：拼音串 → (词 → 次数)。次数越高越靠前。 */
  private learn: Map<string, Map<string, number>> = new Map<string, Map<string, number>>();
  /** 模糊音开关（默认关）。 */
  private fuzzy: boolean = false;
  /** 字符级 bigram：前字 → (后字 → 次数)，来自用户本机文档，只存内存/本地。 */
  private bigrams: Map<string, Map<string, number>> = new Map<string, Map<string, number>>();

  /** 从词库 JSON 构造（Node 与 ArkTS 同一入口）。 */
  /** 懒加载模式：直接持有原始 JSON 对象，不建 Map／索引（启动不卡 UI）。 */
  private rawWords: Record<string, string[]> = {};
  private rawChars: Record<string, string[]> = {};
  private lazyMode: boolean = false;
  private indexesReady: boolean = false;
  /** 表结构已就绪、只差缩写索引 */
  private pendingAbbrev: boolean = false;

  /**
   * §17.3 懒加载工厂：只做「引用赋值＋音节表」，建 Map／缩写索引全部延后。
   * 启动耗时 ≈ decode + JSON.parse，与词表大小基本无关。
   */
  static fromDataLazy(data: PinyinDictData): PinyinEngine {
    const e: PinyinEngine = new PinyinEngine();
    e.lazyMode = true;
    e.rawChars = data.chars;
    e.rawWords = data.words;
    // 设备实测：ArkTS 里 42 万次 Map.set 要 27 秒（debug/release 一样慢），
    // 所以**不建 Map**——直接持有原始对象，按需用原生属性查找。
    // 必须建的是音节表（409 项，走 addSyllable 维护 maxSylLen，否则 segments() 失效）。
    e.rawChars = data.chars;
    e.rawWords = data.words;
    const ck: string[] = Object.keys(data.chars);
    for (let i = 0; i < ck.length; i++) {
      e.addSyllable(ck[i]);
      e.chars.set(ck[i], data.chars[ck[i]]);
    }
    e.lazyMode = true;
    e.pendingAbbrev = true;
    return e;
  }

  /** 后台分片建索引（缩写 + 词频序）：每 300 键让出一次事件循环。 */
  async buildIndexesAsync(): Promise<void> {
    if (!this.pendingAbbrev || this.indexesReady) {
      return;
    }
    const keys: string[] = Object.keys(this.rawWords);
    if (this.sortedKeys.length === 0) {
      this.sortedKeys = keys.slice();
      this.sortedKeys.sort();
    }
    // 每 25 键让出 24ms：设备上 300 键/片会把 UI 线程占满导致系统判无响应
    const SEG: number = 25;
    for (let i = 0; i < keys.length; i++) {
      const k: string = keys[i];
      this.addAbbrevFor(k, this.rawWords[k]);
      if (i > 0 && i % SEG === 0) {
        await new Promise<void>((resolve: () => void) => { setTimeout(resolve, 24); });
      }
    }
    this.finishAbbrev();
    this.indexesReady = true;
    this.pendingAbbrev = false;
  }

  indexesAreReady(): boolean {
    return this.indexesReady || !this.pendingAbbrev;
  }

  static fromData(data: PinyinDictData): PinyinEngine {
    const e: PinyinEngine = new PinyinEngine();
    e.load(data);
    return e;
  }

  /**
   * 异步版（§17.3 第 4 条）：建索引分段让出事件循环，UI 全程可响应。
   * 词表已就绪前 candidates() 返回空，调用方须先看 isReady()。
   */
  static async fromDataAsync(data: PinyinDictData): Promise<PinyinEngine> {
    const e: PinyinEngine = new PinyinEngine();
    await e.loadBasicsAsync(data);
    await e.buildAbbrevAsync();
    e.ready = true;
    return e;
  }

  /** 词库是否已建好索引（异步加载期间为 false）。 */
  private ready: boolean = true;

  isReady(): boolean {
    return this.ready;
  }

  /** 只做轻量部分：音节表、字表、词表、有序键、词频序（不含缩写索引）。 */
  private async loadBasicsAsync(data: PinyinDictData): Promise<void> {
    const ck: string[] = Object.keys(data.chars);
    for (let i = 0; i < ck.length; i++) {
      // 必须走 addSyllable()：它顺带维护 maxSylLen，segments() 的 DP 上界靠它
      this.addSyllable(ck[i]);
      this.chars.set(ck[i], data.chars[ck[i]]);
    }
    const wk: string[] = Object.keys(data.words);
    for (let i = 0; i < wk.length; i++) {
      this.words.set(wk[i], data.words[wk[i]]);
      if (i > 0 && i % 2000 === 0) {
        await new Promise<void>((resolve: () => void) => { setTimeout(resolve, 0); });
      }
    }
    this.sortedKeys = wk.slice();
    this.sortedKeys.sort();
    this.wordRank.clear();
    let rank: number = 0;
    for (let i = 0; i < wk.length; i++) {
      const arr: string[] = data.words[wk[i]];
      for (let j = 0; j < arr.length; j++) {
        if (!this.wordRank.has(arr[j])) {
          this.wordRank.set(arr[j], rank);
          rank = rank + 1;
        }
      }
      if (i > 0 && i % 2000 === 0) {
        await new Promise<void>((resolve: () => void) => { setTimeout(resolve, 0); });
      }
    }
  }

  private loadBasics(data: PinyinDictData): void {
    const ck: string[] = Object.keys(data.chars);
    for (let i = 0; i < ck.length; i++) {
      // 必须走 addSyllable()：它顺带维护 maxSylLen，segments() 的 DP 上界靠它
      this.addSyllable(ck[i]);
      this.chars.set(ck[i], data.chars[ck[i]]);
    }
    const wk: string[] = Object.keys(data.words);
    for (let i = 0; i < wk.length; i++) {
      this.words.set(wk[i], data.words[wk[i]]);
    }
    this.sortedKeys = wk.slice();
    this.sortedKeys.sort();
    this.wordRank.clear();
    let rank: number = 0;
    for (let i = 0; i < wk.length; i++) {
      const arr: string[] = data.words[wk[i]];
      for (let j = 0; j < arr.length; j++) {
        if (!this.wordRank.has(arr[j])) {
          this.wordRank.set(arr[j], rank);
          rank = rank + 1;
        }
      }
    }
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
    this.sortedKeys = wk.slice();
    this.sortedKeys.sort();
    // 词频序：JSON 键顺序 = 生成时的词频序；每键内数组也已按频序
    this.wordRank.clear();
    let rank: number = 0;
    for (let i = 0; i < wk.length; i++) {
      const arr: string[] = data.words[wk[i]];
      for (let j = 0; j < arr.length; j++) {
        if (!this.wordRank.has(arr[j])) {
          this.wordRank.set(arr[j], rank);
          rank = rank + 1;
        }
      }
    }
    this.buildAbbrev();
  }

  /**
   * 缩写即席匹配（§17.3）：不预建索引——预建 17 万键在设备上要 27 秒，必卡死。
   * 只扫「首字母相同」的有界区间（最多 9000 键），够用且只在 2–4 字母查询时发生。
   */
  private abbrevScan(s: string, limit: number): string[] {
    const res: string[] = [];
    if (this.sortedKeys.length === 0) {
      const rk2: string[] = Object.keys(this.rawWords);
      if (rk2.length > 0) {
        this.sortedKeys = rk2;
      } else {
        const mk2: string[] = [];
        this.words.forEach((a: string[], k: string) => { mk2.push(k); });
        this.sortedKeys = mk2;
      }
      this.sortedKeys.sort();
    }
    const first: string = s.charAt(0);
    let lo: number = 0;
    let hi: number = this.sortedKeys.length;
    while (lo < hi) {
      const mid: number = (lo + hi) >> 1;
      if (this.sortedKeys[mid] < first) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    // 2 字母缩写（nh/zg）要把首字母整组扫完，否则「你好」会被同组长尾挡在外面；
    // 3–4 字母只扫 9000 键即可
    if (this.freqKeys.length === 0) {
      // 懒模式用原始对象；非懒模式（fromData，单测走这条）用 words Map 的键序
      const rk: string[] = Object.keys(this.rawWords);
      if (rk.length > 0) {
        this.freqKeys = rk;
      } else {
        const mk: string[] = [];
        this.words.forEach((a: string[], k: string) => { mk.push(k); });
        this.freqKeys = mk;
      }
    }
    const ranks: number[] = [];
    const cap: number = s.length === 2 ? 40000 : 9000;
    let scanned: number = 0;
    for (let i = lo; i < this.sortedKeys.length && scanned < cap && res.length < 200; i++) {
      const k: string = this.sortedKeys[i];
      if (k.charAt(0) !== first) {
        break;
      }
      scanned = scanned + 1;
      const seg: string[] | null = this.greedySplit(k);
      if (seg === null || seg.length < 2 || seg.length > 4) {
        continue;
      }
      let ab: string = '';
      for (let j = 0; j < seg.length; j++) {
        ab = ab + seg[j].charAt(0);
      }
      if (ab !== s) {
        continue;
      }
      const ws: string[] = this.wordsOf(k);
      const kr: number = this.freqKeys.indexOf(k);
      for (let j = 0; j < ws.length && res.length < 200; j++) {
        if (res.indexOf(ws[j]) < 0) {
          res.push(ws[j]);
          ranks.push(kr < 0 ? 999999 : kr);
        }
      }
    }
    // 按词频序（JSON 键顺序）重排：同缩写的「nahan(呐喊)」与「nihao(你好)」靠这个分先后
    if (res.length > 1) {
      const idx: number[] = [];
      for (let i = 0; i < res.length; i++) {
        idx.push(i);
      }
      idx.sort((a: number, b: number) => ranks[a] - ranks[b]);
      const sorted: string[] = [];
      for (let i = 0; i < idx.length; i++) {
        sorted.push(res[idx[i]]);
      }
      res.length = 0;
      for (let i = 0; i < sorted.length; i++) {
        res.push(sorted[i]);
      }
      if (res.length > limit) {
        res.length = limit;
      }
    }
    return res;
  }

  /** 词→词频序（缓存键序，只算一次）。 */
  private freqRankOf(w: string): number {
    const c: number = this.wordKeyCache.get(w) === undefined ? -1 : this.wordKeyCache.get(w) as number;
    if (c >= 0) {
      return c;
    }
    return 999999;
  }

  /** 词前缀候选（§16）：打半词也能出完整词。二分定位后线性收集。 */
  private prefixWords(s: string, limit: number): string[] {
    const res: string[] = [];
    if (s.length < 2) {
      return res;
    }
    if (this.sortedKeys.length === 0) {
      // 懒模式：首次用到前缀时再建有序键（一次排序，之后常驻）
      this.sortedKeys = Object.keys(this.rawWords);
      this.sortedKeys.sort();
    }
    if (this.sortedKeys.length === 0) {
      return res;
    }
    let lo: number = 0;
    let hi: number = this.sortedKeys.length;
    while (lo < hi) {
      const mid: number = (lo + hi) >> 1;
      if (this.sortedKeys[mid] < s) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    // 收集所有以 s 开头的键（最多 200 个），按「键长升序」排序——
    // 越接近输入的键越先出（否则 weixi 会被 weixiashu 这类长键占满）
    const keys: string[] = [];
    for (let i = lo; i < this.sortedKeys.length && keys.length < 200; i++) {
      const k: string = this.sortedKeys[i];
      if (!k.startsWith(s)) {
        break;
      }
      if (k === s) {
        continue;
      }
      keys.push(k);
    }
    // 排序：键长升序（越接近输入越先），同长度按首词词频（wordfreq 序）——
    // 这样 zhongg 能先看到中国所在的 zhongguo，而不是被一堆同长度的生僻键占满
    keys.sort((a: string, b: string) => {
      if (a.length !== b.length) {
        return a.length - b.length;
      }
      const wa: string[] = this.wordsOf(a);
      const wb: string[] = this.wordsOf(b);
      const ra: number = wa.length > 0 && this.wordRank.get(wa[0]) !== undefined
        ? this.wordRank.get(wa[0]) as number : 999999;
      const rb: number = wb.length > 0 && this.wordRank.get(wb[0]) !== undefined
        ? this.wordRank.get(wb[0]) as number : 999999;
      return ra - rb;
    });
    // 返回**键**而不是词：调用方要用「键」当拼音串，选词后余量才算得对
    for (let i = 0; i < keys.length && res.length < limit; i++) {
      if (res.indexOf(keys[i]) < 0) {
        res.push(keys[i]);
      }
    }
    return res;
  }

  /**
   * 半音节前缀键（§17.2）：整串不是合法拼音、但去掉末字母后合法时，
   * 用**原串**去匹配完整键（taob→taobao、weix→weixin、zhongg→zhongguo）。
   */
  private halfPrefixKeys(s: string): string[] {
    if (s.length < 3) {
      return [];
    }
    if (this.segments(s).length > 0) {
      return [];
    }
    const head: string = s.substring(0, s.length - 1);
    if (this.segments(head).length === 0) {
      return [];
    }
    // 多取几个键（半音节时键名长短不一，微信在 weixin、中国在 zhongguo）
    return this.prefixWords(s, 14);
  }

  /** 由词表预建声母缩写索引（加载时一次，不许每击键扫全表）。 */
  private buildAbbrev(): void {
    this.abbrev.clear();
    this.words.forEach((arr: string[], py: string) => {
      this.addAbbrevFor(py, arr);
    });
    this.userWords.forEach((arr2: string[], py2: string) => {
      this.addAbbrevFor(py2, arr2);
    });
    this.finishAbbrev();
  }

  /** 缩写收口：每个缩写列表只排一次序、截 30（§17.3）。 */
  private finishAbbrev(): void {
    this.abbrev.forEach((list: string[]) => {
      list.sort((a: string, b: string) => {
        const ra: number = this.abbrevOrder.get(a) === undefined ? 999999 : this.abbrevOrder.get(a) as number;
        const rb: number = this.abbrevOrder.get(b) === undefined ? 999999 : this.abbrevOrder.get(b) as number;
        return ra - rb;
      });
      if (list.length > 30) {
        list.length = 30;
      }
    });
  }

  /** 分段建缩写索引（§17.3 第 4 条）：每 SEG 个键让出一次事件循环，UI 不卡死。 */
  private async buildAbbrevAsync(): Promise<void> {
    this.abbrev.clear();
    const keys: string[] = [];
    this.words.forEach((arr: string[], py: string) => { keys.push(py); });
    this.userWords.forEach((arr2: string[], py2: string) => { keys.push(py2); });
    // 每 300 键让出一次事件循环：单段 300 次 DP 切分约 10–30ms，不会堵死一帧以上
    const SEG: number = 300;
    for (let i = 0; i < keys.length; i++) {
      const k: string = keys[i];
      const arr: string[] | undefined = this.words.get(k) === undefined
        ? this.userWords.get(k) : this.words.get(k);
      if (arr !== undefined) {
        this.addAbbrevFor(k, arr);
      }
      if (i > 0 && i % SEG === 0) {
        await new Promise<void>((resolve: () => void) => { setTimeout(resolve, 0); });
      }
    }
    this.finishAbbrev();
  }

  /**
   * 贪心切分（缩写索引用）：不做 DP，最长匹配音节，一趟扫完。
   * 比 segments() 快一个量级——17 万键全量建索引必须用它。
   */
  private greedySplit(py: string): string[] | null {
    const res: string[] = [];
    let i: number = 0;
    while (i < py.length) {
      let matched: string = '';
      for (let len = 6; len >= 1; len--) {
        if (i + len > py.length) {
          continue;
        }
        const cand: string = py.substring(i, i + len);
        if (this.syllables.has(cand)) {
          matched = cand;
          break;
        }
      }
      if (matched.length === 0) {
        return null;
      }
      res.push(matched);
      i += matched.length;
    }
    return res;
  }

  private addAbbrevFor(py: string, words: string[]): void {
    const seg: string[] | null = this.greedySplit(py);
    if (seg === null || seg.length < 2 || seg.length > 4) {
      return;
    }
    if (seg.length < 2 || seg.length > 4) {
      return;
    }
    let ab: string = '';
    for (let i = 0; i < seg.length; i++) {
      ab = ab + seg[i].charAt(0);
    }
    if (ab.length < 2) {
      return;
    }
    let list: string[] | undefined = this.abbrev.get(ab);
    if (list === undefined) {
      list = [];
      this.abbrev.set(ab, list);
    }
    // 先全收（上限 200），按词频序排序后再截 30——否则高频词在收集阶段就被同缩写的长尾挤掉
    for (let j = 0; j < words.length && list.length < 200; j++) {
      if (list.indexOf(words[j]) < 0) {
        list.push(words[j]);
        if (!this.abbrevOrder.has(words[j])) {
          this.abbrevOrder.set(words[j], this.abbrevSeq);
          this.abbrevSeq = this.abbrevSeq + 1;
        }
      }
    }
    // §17.3：这里不许排序——每键排一次会让 17 万个键各排一遍。
    // 只收集（上限 200），全部键跑完后由 finishAbbrev() 统一排一次并截 30。
  }

  /** 重建缩写索引（我的词库变更后调用）。 */
  rebuildAbbrev(): void {
    this.buildAbbrev();
  }

  abbrevCount(): number {
    return this.abbrev.size;
  }

  /** §11.3 模糊表：8 组（双向）。键为规范形，值为等价形列表。 */
  /** 声母对：前缀替换（zh/z、ch/c、sh/s、n/l、f/h） */
  private static readonly FUZZY_INITIALS: string[][] = [
    ['zh', 'z'], ['ch', 'c'], ['sh', 's'], ['n', 'l'], ['f', 'h'],
  ];
  /** 韵母对：后缀替换（in/ing、en/eng、an/ang）。韵母只在音节尾部，前缀替换永远匹配不到。 */
  private static readonly FUZZY_FINALS: string[][] = [
    ['in', 'ing'], ['en', 'eng'], ['an', 'ang'],
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
    // ① 声母对：只在音节开头替换
    for (let p = 0; p < PinyinEngine.FUZZY_INITIALS.length; p++) {
      const a: string = PinyinEngine.FUZZY_INITIALS[p][0];
      const b: string = PinyinEngine.FUZZY_INITIALS[p][1];
      const next: string[] = [];
      for (let i = 0; i < forms.length; i++) {
        const f: string = forms[i];
        if (next.indexOf(f) < 0) { next.push(f); }
        if (f.length > a.length && f.startsWith(a)) {
          const v: string = b + f.substring(a.length);
          if (next.indexOf(v) < 0) { next.push(v); }
        }
        if (f.length > b.length && f.startsWith(b)) {
          const v2: string = a + f.substring(b.length);
          if (next.indexOf(v2) < 0) { next.push(v2); }
        }
      }
      forms = next;
    }
    // ② 韵母对：只在音节尾部替换（nin→ning、ban→bang、chen→cheng，反向亦然）
    for (let q = 0; q < PinyinEngine.FUZZY_FINALS.length; q++) {
      const c: string = PinyinEngine.FUZZY_FINALS[q][0];
      const d: string = PinyinEngine.FUZZY_FINALS[q][1];
      const next2: string[] = [];
      for (let i = 0; i < forms.length; i++) {
        const f: string = forms[i];
        if (next2.indexOf(f) < 0) { next2.push(f); }
        if (f.endsWith(c)) {
          const v: string = f.substring(0, f.length - c.length) + d;
          if (next2.indexOf(v) < 0) { next2.push(v); }
        }
        if (f.endsWith(d)) {
          const v2: string = f.substring(0, f.length - d.length) + c;
          if (next2.indexOf(v2) < 0) { next2.push(v2); }
        }
      }
      forms = next2;
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

  /** 词条总数（供设置页显示真实数字，不再手写）。 */
  wordCount(): number {
    let n: number = 0;
    if (this.lazyMode) {
      const ks: string[] = Object.keys(this.rawWords);
      for (let i = 0; i < ks.length; i++) {
        n += this.rawWords[ks[i]].length;
      }
    } else {
      this.words.forEach((arr: string[]) => { n += arr.length; });
    }
    this.userWords.forEach((arr2: string[]) => { n += arr2.length; });
    return n;
  }

  /** 音节数（词库信息用）。 */
  syllableTotal(): number {
    return this.syllables.size;
  }

  /** 单音节查字（候选用）。 */
  charsOf(syl: string): string[] {
    if (this.lazyMode) {
      const r: string[] | undefined = this.rawChars[syl];
      return r === undefined ? [] : r;
    }
    const v = this.chars.get(syl);
    return v === undefined ? [] : v;
  }

  wordsOf(py: string): string[] {
    if (this.lazyMode) {
      const r: string[] | undefined = this.rawWords[py];
      return r === undefined ? [] : r;
    }
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
    // 「次数＋新近」：刚选的词取「当前同串最大次数 + 1」，保证它在同串内排第一；
    // 其余词保留历史次数，作为之后的次序依据
    let maxN: number = 0;
    m.forEach((n: number) => {
      if (n > maxN) {
        maxN = n;
      }
    });
    m.set(word, maxN + 1);
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

  /**
   * 一个词的全部拼音变体（每个字的所有读音组合，最多 4 个）：
   * 让「大龙爪子」同时可按 dalongzhuazi 与 dalongzhaozi 打出来。
   */
  pinyinVariantsOfWord(word: string): string[] {
    const perChar: string[][] = [];
    this.chars.forEach((arr: string[], syl: string) => {
      for (let i = 0; i < arr.length; i++) {
        const idx: number = word.indexOf(arr[i]);
        if (idx < 0) {
          continue;
        }
        if (perChar[idx] === undefined) {
          perChar[idx] = [];
        }
        if (perChar[idx].indexOf(syl) < 0) {
          perChar[idx].push(syl);
        }
      }
    });
    let variants: string[] = [''];
    for (let i = 0; i < word.length; i++) {
      const opts: string[] = perChar[i] === undefined ? [] : perChar[i];
      if (opts.length === 0) {
        return [];
      }
      const next: string[] = [];
      for (let v = 0; v < variants.length; v++) {
        for (let o = 0; o < opts.length && next.length < 4; o++) {
          next.push(variants[v] + opts[o]);
        }
      }
      variants = next;
    }
    return variants;
  }

  /** 载入 bigram（用户语料，本地）。 */
  setBigrams(data: Record<string, Record<string, number>>): void {
    this.bigrams.clear();
    const ks: string[] = Object.keys(data);
    for (let i = 0; i < ks.length; i++) {
      const inner: Record<string, number> = data[ks[i]];
      const m: Map<string, number> = new Map<string, number>();
      const wk: string[] = Object.keys(inner);
      for (let j = 0; j < wk.length; j++) {
        m.set(wk[j], inner[wk[j]]);
      }
      this.bigrams.set(ks[i], m);
    }
  }

  bigramCount(): number {
    let n: number = 0;
    this.bigrams.forEach((m: Map<string, number>) => { n += m.size; });
    return n;
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
    // 多读音字：取「该字在音节表里排得最靠前」的读音（chars 已按常用度排序，越靠前越常用）
    const best: Map<string, number> = new Map<string, number>();
    const bestSyl: Map<string, string> = new Map<string, string>();
    this.chars.forEach((arr: string[], syl: string) => {
      for (let i = 0; i < arr.length; i++) {
        const ch: string = arr[i];
        const cur: number | undefined = best.get(ch);
        if (cur === undefined || i < cur) {
          best.set(ch, i);
          bestSyl.set(ch, syl);
        }
      }
    });
    let py: string = '';
    for (let i = 0; i < word.length; i++) {
      const s: string | undefined = bestSyl.get(word.charAt(i));
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
  candidates(input: string, limit: number = 8, prevChar: string = ''): Candidate[] {
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
    // ③ 整串词：先出前 2 个，把第 3 个往后的位置让给「词前缀候选」，
    // 否则打半词（weixi）时整词会把候选栏占满、看不到完整词（微信）
    const whole: string[] = this.wordsOf(s);
    for (let i = 0; i < whole.length && i < 2; i++) {
      push(whole[i], 0, s);
    }
    // ③.2 词前缀候选（§16）：打「weixi」也要能看到「微信」。
    // 候选的拼音串用**命中的键**（weixin），选词后余量才正确
    // 只在「整串本身是合法拼音」时才做词前缀（weixi ✓）；
    // 不合法（nih）交给下面「最长合法前缀」回退，避免抢走 ni 的候选与 pinyin 口径
    const pkeys: string[] = this.segments(s).length > 0 ? this.prefixWords(s, 8) : [];
    // ③.4 半音节前缀（§17.2）：taob / weix / zhongg —— 末尾音节没打完也要能出完整词。
    // 这些候选排在正常候选之后，不抢首选（nih 仍按 ni 出候选）
    const halfKeys: string[] = this.halfPrefixKeys(s);
    for (let i = 0; i < pkeys.length; i++) {
      const kw: string[] = this.wordsOf(pkeys[i]);
      for (let j = 0; j < kw.length && j < 2; j++) {
        push(kw[j], 0, pkeys[i]);
      }
    }
    for (let i = 2; i < whole.length; i++) {
      push(whole[i], 0, s);
    }
    // ③.3 声母缩写候选（nh→你好）：排在整词/前缀词之后、单字回退之前，
    // 否则会被单字候选挤出候选栏前 9
    if (s.length >= 2 && s.length <= 4 && res.length < limit) {
      const ab: string[] = this.abbrevScan(s, 8);
      for (let i = 0; i < ab.length && res.length < limit; i++) {
        push(ab[i], 2, s);
      }
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
    // ③.5 上下文微调（§13 第 7 步）：同一拼音串内，跟在 prevChar 后高频的字优先；
    // 只做同串内稳定重排，不跨拼音串抢位
    if (prevChar.length > 0 && res.length > 1) {
      const m: Map<string, number> | undefined = this.bigrams.get(prevChar);
      if (m !== undefined) {
        const scored: Candidate[] = res.slice();
        scored.sort((a: Candidate, b: Candidate) => {
          const sa: number = m.get(a.text.charAt(0)) === undefined ? 0 : m.get(a.text.charAt(0)) as number;
          const sb: number = m.get(b.text.charAt(0)) === undefined ? 0 : m.get(b.text.charAt(0)) as number;
          return sb - sa;
        });
        res.length = 0;
        for (let i = 0; i < scored.length; i++) {
          res.push(scored[i]);
        }
      }
    }
    // ③.4 半音节前缀：插在第 3 位之后（能看见、不抢首选；nih 仍按 ni 出候选）
    if (halfKeys.length > 0) {
      const halfWords: Candidate[] = [];
      // 每个键只取首词、多覆盖几个键（否则 4 个名额会被同长度的邻近键吃光）
      for (let i = 0; i < halfKeys.length && halfWords.length < 6; i++) {
        const kw: string[] = this.wordsOf(halfKeys[i]);
        for (let j = 0; j < kw.length && j < 1 && halfWords.length < 6; j++) {
          halfWords.push({ text: kw[j], pinyin: halfKeys[i], kind: 1 });
        }
      }
      const at: number = res.length > 3 ? 3 : res.length;
      for (let i = 0; i < halfWords.length; i++) {
        let dup: boolean = false;
        for (let k = 0; k < res.length; k++) {
          if (res[k].text === halfWords[i].text) {
            dup = true;
            break;
          }
        }
        if (!dup) {
          res.splice(at + i, 0, halfWords[i]);
        }
      }
      // 插完可能超出 limit，截回
      while (res.length > limit) {
        res.pop();
      }
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

  currentCandidates(limit: number = 8, prevChar: string = ''): Candidate[] {
    if (this.buffer.length === 0) {
      return [];
    }
    return this.engine.candidates(this.buffer, limit, prevChar);
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
