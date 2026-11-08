// 回车 · CandidateCore 单测（第 2 批 F15）
// 运行：node --experimental-strip-types --test tools/tests/candidate-core.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'candcore-'));
const ts = path.join(tmp, 'CandidateCore.ts');
fs.copyFileSync(path.join(root, 'entry/src/main/ets/model/CandidateCore.ets'), ts);
const mod = await import('file://' + ts.replace(/\\/g, '/'));

test('候选数量：默认 9，范围 5–15', () => {
  assert.equal(mod.CANDIDATE_COUNT_DEFAULT, 9);
  assert.equal(mod.clampCandidateCount(9), 9);
  assert.equal(mod.clampCandidateCount(1), 5);
  assert.equal(mod.clampCandidateCount(99), 15);
  assert.equal(mod.clampCandidateCount(Number.NaN), 9);
});

test('候选字号：默认 15，范围 12–20', () => {
  assert.equal(mod.CANDIDATE_SIZE_DEFAULT, 15);
  assert.equal(mod.clampCandidateSize(12), 12);
  assert.equal(mod.clampCandidateSize(20), 20);
  assert.equal(mod.clampCandidateSize(8), 12);
  assert.equal(mod.clampCandidateSize(30), 20);
});

test('chip 高预算：最大字号 20 仍 ≤44vp', () => {
  assert.ok(mod.chipHeightOf(20) <= 44, `chipHeight=${mod.chipHeightOf(20)}`);
  assert.equal(mod.chipFits(20), true);
  assert.equal(mod.chipHeightOf(15) <= 44, true);
});