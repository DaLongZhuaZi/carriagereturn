// 回车 · StatsCore 纯函数单测（第 0 批）
// 运行：node --experimental-strip-types --test tools/tests/stats-core.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const src = path.join(root, 'entry/src/main/ets/model/StatsCore.ets');
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'statscore-'));
const tsPath = path.join(tmpDir, 'StatsCore.ts');
fs.copyFileSync(src, tsPath);
const mod = await import('file://' + tsPath.replace(/\\/g, '/'));

const HKT = 480; // UTC+8

function ms(iso) {
  return Date.parse(iso);
}

test('dayKey：香港时区跨 UTC 日界', () => {
  assert.equal(mod.dayKey(ms('2026-11-09T03:00:00+08:00'), HKT), '2026-11-09');
  assert.equal(mod.dayKey(ms('2026-11-09T00:30:00+08:00'), HKT), '2026-11-09');
  // UTC 11-08 16:30 = 香港 11-09 00:30
  assert.equal(mod.dayKey(ms('2026-11-08T16:30:00Z'), HKT), '2026-11-09');
  // UTC 11-08 15:30 = 香港 11-08 23:30
  assert.equal(mod.dayKey(ms('2026-11-08T15:30:00Z'), HKT), '2026-11-08');
});

test('dayIndex / dayIndexOfKey 往返一致', () => {
  const t = ms('2026-11-09T12:00:00+08:00');
  const key = mod.dayKey(t, HKT);
  assert.equal(mod.dayIndexOfKey(key), mod.dayIndex(t, HKT));
  assert.equal(mod.dayIndexOfKey('bad'), -1);
  assert.equal(mod.dayIndexOfKey('2026-13-01'), -1);
});

test('consecutiveDays：今天起连续 3 天', () => {
  const today = ms('2026-11-09T20:00:00+08:00');
  const list = [
    ms('2026-11-09T09:00:00+08:00'),
    ms('2026-11-08T09:00:00+08:00'),
    ms('2026-11-07T09:00:00+08:00'),
  ];
  assert.equal(mod.consecutiveDays(list, today, HKT), 3);
});

test('consecutiveDays：今天没写＝0（与 HomePage 既有口径一致）', () => {
  const today = ms('2026-11-09T20:00:00+08:00');
  const list = [ms('2026-11-08T09:00:00+08:00'), ms('2026-11-07T09:00:00+08:00')];
  assert.equal(mod.consecutiveDays(list, today, HKT), 0);
});

test('consecutiveDays：断档只算到断点', () => {
  const today = ms('2026-11-09T20:00:00+08:00');
  const list = [
    ms('2026-11-09T09:00:00+08:00'),
    ms('2026-11-08T09:00:00+08:00'),
    // 11-07 缺
    ms('2026-11-06T09:00:00+08:00'),
  ];
  assert.equal(mod.consecutiveDays(list, today, HKT), 2);
});

test('consecutiveDays：同一天多文档去重', () => {
  const today = ms('2026-11-09T20:00:00+08:00');
  const list = [
    ms('2026-11-09T09:00:00+08:00'),
    ms('2026-11-09T10:00:00+08:00'),
    ms('2026-11-09T11:00:00+08:00'),
  ];
  assert.equal(mod.consecutiveDays(list, today, HKT), 1);
});

test('sumCounts：负数/NaN 不计', () => {
  assert.equal(mod.sumCounts([3, 5, 0]), 8);
  assert.equal(mod.sumCounts([3, -2, Number.NaN, 4]), 7);
  assert.equal(mod.sumCounts([]), 0);
});

test('progressRatio：clamp 0..1，目标 0 不除零', () => {
  assert.equal(mod.progressRatio(0, 500), 0);
  assert.equal(mod.progressRatio(250, 500), 0.5);
  assert.equal(mod.progressRatio(900, 500), 1);
  assert.equal(mod.progressRatio(100, 0), 0);
  assert.equal(mod.progressRatio(-10, 500), 0);
});

test('goalReached', () => {
  assert.equal(mod.goalReached(500, 500), true);
  assert.equal(mod.goalReached(499, 500), false);
  assert.equal(mod.goalReached(0, 0), false);
});