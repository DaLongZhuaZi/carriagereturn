// 回车 · LeverStateCore 纯函数单测（第 0b 批）
// 运行：node --experimental-strip-types --test tools/tests/lever-state.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const src = path.join(root, 'entry/src/main/ets/model/LeverStateCore.ets');
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'leverstate-'));
const tsPath = path.join(tmpDir, 'LeverStateCore.ts');
fs.copyFileSync(src, tsPath);
const mod = await import('file://' + tsPath.replace(/\\/g, '/'));

test('slotOf：四机映射 0..3', () => {
  assert.equal(mod.slotOf('1920s-upright'), 0);
  assert.equal(mod.slotOf('1930s-portable'), 1);
  assert.equal(mod.slotOf('1950s-streamlined'), 2);
  assert.equal(mod.slotOf('1960s-electric'), 3);
});

test('slotOf：未知机型回落 0（不抛）', () => {
  assert.equal(mod.slotOf(''), 0);
  assert.equal(mod.slotOf('unknown'), 0);
});

test('nextEpoch：递增且容错', () => {
  assert.equal(mod.nextEpoch(0), 1);
  assert.equal(mod.nextEpoch(41), 42);
  assert.equal(mod.nextEpoch(Number.NaN), 1);
});

test('shouldResetOnSwitch：同机 false，异机 true', () => {
  assert.equal(mod.shouldResetOnSwitch('1920s-upright', '1920s-upright'), false);
  assert.equal(mod.shouldResetOnSwitch('1920s-upright', '1950s-streamlined'), true);
});