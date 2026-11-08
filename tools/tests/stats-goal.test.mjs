// 回车 · 第 4 批 F11／F14 纯函数单测
// 覆盖：mergeDailyChars（同日累加/跨日归零/负数不扣/NaN）、paperKindsMerge（去重/排序/空）、目标 clamp 100–2000
// 运行：node --experimental-strip-types --test tools/tests/stats-goal.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const src = path.join(root, 'entry/src/main/ets/model/StatsCore.ets');
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'statsgoal-'));
const tsPath = path.join(tmpDir, 'StatsCore.ts');
fs.copyFileSync(src, tsPath);
const mod = await import('file://' + tsPath.replace(/\\/g, '/'));

test('mergeDailyChars：同日累加', () => {
  assert.equal(mod.mergeDailyChars('2026-11-09', 100, '2026-11-09', 5), 105);
  assert.equal(mod.mergeDailyChars('2026-11-09', 0, '2026-11-09', 1), 1);
  assert.equal(mod.mergeDailyChars('2026-11-09', 100, '2026-11-09', 0), 100);
});

test('mergeDailyChars：跨日归零后只加 delta', () => {
  assert.equal(mod.mergeDailyChars('2026-11-08', 100, '2026-11-09', 5), 5);
  assert.equal(mod.mergeDailyChars('', 0, '2026-11-09', 7), 7);
  assert.equal(mod.mergeDailyChars('2026-11-08', 100, '2026-11-09', 0), 0);
});

test('mergeDailyChars：负数/非有限 delta 不扣减', () => {
  assert.equal(mod.mergeDailyChars('2026-11-09', 100, '2026-11-09', -5), 100);
  assert.equal(mod.mergeDailyChars('2026-11-08', 100, '2026-11-09', -5), 0);
  assert.equal(mod.mergeDailyChars('2026-11-09', 100, '2026-11-09', NaN), 100);
  assert.equal(mod.mergeDailyChars('2026-11-09', 100, '2026-11-09', Infinity), 100);
});

test('mergeDailyChars：非有限 prev 不污染结果', () => {
  assert.equal(mod.mergeDailyChars('2026-11-09', NaN, '2026-11-09', 5), 5);
  assert.equal(mod.mergeDailyChars('2026-11-09', -10, '2026-11-09', 5), 5);
  assert.equal(mod.mergeDailyChars('2026-11-09', NaN, '2026-11-09', NaN), 0);
});

test('mergeDailyChars：小数向下取整（逐次落字都是整数，防御历史脏值）', () => {
  assert.equal(mod.mergeDailyChars('2026-11-09', 1.9, '2026-11-09', 2.9), 3);
});

test('paperKindsMerge：去重', () => {
  assert.equal(mod.paperKindsMerge('letter', 'letter'), 'letter');
  assert.equal(mod.paperKindsMerge('letter,memo,letter', 'memo'), 'letter,memo');
  assert.equal(mod.paperKindsMerge('', 'letter'), 'letter');
});

test('paperKindsMerge：排序稳定（字母序）', () => {
  assert.equal(mod.paperKindsMerge('memo,letter', 'postcard'), 'letter,memo,postcard');
  assert.equal(mod.paperKindsMerge('postcard', 'letter'), 'letter,postcard');
  // 幂等：同一集合任意顺序写入两次结果一致
  const once = mod.paperKindsMerge(mod.paperKindsMerge('', 'memo'), 'letter');
  const twice = mod.paperKindsMerge('letter', 'memo');
  assert.equal(once, twice);
  assert.equal(once, 'letter,memo');
});

test('paperKindsMerge：空 kind 原样返回（含首尾空白归一化）', () => {
  assert.equal(mod.paperKindsMerge('letter,memo', ''), 'letter,memo');
  assert.equal(mod.paperKindsMerge('letter,memo', '   '), 'letter,memo');
  assert.equal(mod.paperKindsMerge('', ''), '');
  assert.equal(mod.paperKindsMerge(' letter , memo ', 'letter'), 'letter,memo');
});

test('clampDailyGoal：100–2000', () => {
  assert.equal(mod.clampDailyGoal(50), 100);
  assert.equal(mod.clampDailyGoal(100), 100);
  assert.equal(mod.clampDailyGoal(1000), 1000);
  assert.equal(mod.clampDailyGoal(2000), 2000);
  assert.equal(mod.clampDailyGoal(5000), 2000);
  assert.equal(mod.clampDailyGoal(1500.9), 1500);
  assert.equal(mod.clampDailyGoal(NaN, 500), 500);
  assert.equal(mod.clampDailyGoal(NaN), 100);
  assert.equal(mod.clampDailyGoal(-5, 800), 800);
  assert.equal(mod.DAILY_GOAL_MIN, 100);
  assert.equal(mod.DAILY_GOAL_MAX, 2000);
  assert.equal(mod.DAILY_GOAL_STEP, 100);
});