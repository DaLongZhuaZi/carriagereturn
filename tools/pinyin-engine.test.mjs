// 回车 · 内置拼音引擎 Node 单测（node --test）
// 运行：node --experimental-strip-types --test tools/pinyin-engine.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(here);
const etsPath = path.join(root, 'entry/src/main/ets/services/PinyinEngine.ets');
const dictDir = path.join(root, 'entry/src/main/resources/rawfile/dict');

// .ets 复制成 .ts 供 Node strip-types 载入（设计稿允许「复制为 .ts」）
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'pyeng-'));
const tsPath = path.join(tmpDir, 'PinyinEngine.ts');
fs.copyFileSync(etsPath, tsPath);

const mod = await import('file://' + tsPath.replace(/\\/g, '/'))
;
const { PinyinEngine, PinyinSession, PinyinState } = mod;

const chars = JSON.parse(fs.readFileSync(path.join(dictDir, 'pinyin-chars.json'), 'utf8'));
const words = JSON.parse(fs.readFileSync(path.join(dictDir, 'pinyin-words.json'), 'utf8'));
const engine = PinyinEngine.fromData({ chars, words });

test('切分：nihao', () => {
  const segs = engine.segments('nihao');
  assert.ok(segs.length > 0);
  assert.ok(segs.some(s => s.join('|') === 'ni|hao'));
});

test('切分：xian', () => {
  const segs = engine.segments('xian');
  assert.ok(segs.some(s => s.join('|') === 'xian'));
  assert.ok(segs.some(s => s.join('|') === 'xi|an'));
});

test('切分：shanghai', () => {
  assert.ok(engine.segments('shanghai').some(s => s.join('|') === 'shang|hai'));
});

test('切分：zhongguo', () => {
  assert.ok(engine.segments('zhongguo').some(s => s.join('|') === 'zhong|guo'));
});

test('切分：nvhai（v=ü）', () => {
  assert.ok(engine.segments('nvhai').some(s => s.join('|') === 'nv|hai'));
});

test('不完整 nih 与无效 xyz', () => {
  assert.equal(engine.segments('nih').length, 0);
  assert.equal(engine.segments('xyz').length, 0);
});

test('排序：nihao 首选你好', () => {
  const c = engine.candidates('nihao', 5);
  assert.equal(c[0].text, '你好');
});

test('选词余量：nihaoma 选你好后剩 ma', () => {
  const s = new PinyinSession(engine);
  for (const ch of 'nihaoma') s.typeLetter(ch);
  const c = s.currentCandidates(5);
  assert.equal(c[0].text, '你好');
  const r = s.pick(c[0]);
  assert.equal(r.residual, 'ma');
  assert.equal(s.getBuffer(), 'ma');
});

test('多音字：重庆/音乐/银行/行/乐/长', () => {
  assert.equal(engine.candidates('chongqing', 3)[0].text, '重庆');
  assert.equal(engine.candidates('yinyue', 3)[0].text, '音乐');
  assert.equal(engine.candidates('yinhang', 3)[0].text, '银行');
  const xing = engine.candidates('xing', 3).map(c => c.text);
  assert.ok(xing.includes('行') || xing.includes('性'));
  const le = engine.candidates('le', 3).map(c => c.text);
  assert.ok(le.length > 0);
  const chang = engine.candidates('chang', 3).map(c => c.text);
  assert.ok(chang.length > 0);
});

test('性能：每击键 p95 < 1ms', () => {
  const corpus = ['nihao','xian','shanghai','zhongguo','nvhai','chongqing','yinyue','yinhang','women','zhonghua','renmin','gongheguo','xuexi','gongzuo','shenghuo'];
  const samples = [];
  for (let round = 0; round < 40; round++) {
    for (const w of corpus) {
      const t0 = process.hrtime.bigint();
      engine.candidates(w, 8);
      const t1 = process.hrtime.bigint();
      samples.push(Number(t1 - t0) / 1e6);
    }
  }
  samples.sort((a, b) => a - b);
  const p95 = samples[Math.floor(samples.length * 0.95)];
  console.log('    p95 =', p95.toFixed(4), 'ms, 样本', samples.length);
  assert.ok(p95 < 1.0, 'p95=' + p95);
});

test('§11.1 前缀候选：nih / niha / zhongg 都有候选', () => {
  assert.ok(engine.candidates('nih', 5).length > 0, 'nih');
  assert.ok(engine.candidates('niha', 5).length > 0, 'niha');
  assert.ok(engine.candidates('zhongg', 5).length > 0, 'zhongg');
  const c = engine.candidates('nih', 5)[0];
  assert.equal(c.pinyin, 'ni', '前缀候选应消费 ni');
});

test('§11.1 选词后余量：nih 选词后余 h', () => {
  const s = new PinyinSession(engine);
  for (const ch of 'nih') s.typeLetter(ch);
  const c = s.currentCandidates(5)[0];
  const r = s.pick(c);
  assert.equal(r.residual, 'h');
});

test('§11.2 学习：选过的词置顶', () => {
  engine.learnWord('nihao', '你号');
  const c = engine.candidates('nihao', 5);
  assert.equal(c[0].text, '你号');
});

test('§11.3 模糊音：声母对与韵母对都要真命中', () => {
  const e = PinyinEngine.fromData({ chars, words });
  e.setFuzzy(true);
  const must = [
    ['nin', '宁'], ['ban', '帮'], ['chen', '成'], ['ning', '您'],
    ['zhao', '找'], ['zao', '找'], ['zhi', '只'], ['zi', '只'],
  ];
  for (const pair of must) {
    const list = e.candidates(pair[0], 60).map((x) => x.text);
    assert.ok(list.includes(pair[1]), pair[0] + ' 必须出 ' + pair[1]);
  }
  e.setFuzzy(false);
  const off = e.candidates('nin', 60).map((x) => x.text);
  assert.ok(!off.includes('宁'), '关模糊音后 nin 不许出宁');
});
test('§11.4 我的词库：推导拼音 + 置顶 + 可查', () => {
  const py = engine.pinyinOfWord('大龙爪子');
  assert.ok(py.length > 0, 'pinyinOfWord 应能推导');
  engine.addUserWordWithPinyin(py, '大龙爪子');
  const c = engine.candidates(py, 5);
  assert.equal(c[0].text, '大龙爪子');
});
test('§11.2 学习：按用户打的整串置顶（模拟 pinyinPick 路径）', () => {
  const e2 = PinyinEngine.fromData({ chars, words });
  const s2 = new PinyinSession(e2);
  for (const ch of 'nihao') s2.typeLetter(ch);
  const typed = s2.getBuffer();
  const c0 = s2.currentCandidates(9);
  assert.equal(c0[0].text, '你好');
  const pick = c0[1];
  e2.learnWord(typed, pick.text);
  const c1 = e2.candidates('nihao', 9);
  assert.equal(c1[0].text, pick.text, '选过的词应置顶');
});

test('§11.2 学习记录可导出（模拟落盘再载入）', () => {
  const e3 = PinyinEngine.fromData({ chars, words });
  e3.learnWord('nihao', '泥');
  const dump = e3.exportLearn();
  assert.equal(dump['nihao']['泥'], 1);
  const e4 = PinyinEngine.fromData({ chars, words });
  e4.setLearnData(dump);
  assert.equal(e4.candidates('nihao', 9)[0].text, '泥', '载入后仍置顶');
});