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
