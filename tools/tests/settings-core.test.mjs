// 回车 · 第 6 批 SettingsCore 单测（删除方式/音量/纸张）
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'setcore-'));
const ts = path.join(tmp, 'SettingsCore.ts');
fs.copyFileSync(path.join(root, 'entry/src/main/ets/model/SettingsCore.ets'), ts);
const mod = await import('file://' + ts.replace(/\\/g, '/'));

test('deleteModeOf：稳定 id 白名单，非法回落 trash', () => {
  assert.equal(mod.deleteModeOf('direct'), 'direct');
  assert.equal(mod.deleteModeOf('ask'), 'ask');
  assert.equal(mod.deleteModeOf('trash'), 'trash');
  assert.equal(mod.deleteModeOf('现代删除'), 'trash');
  assert.equal(mod.deleteModeOf(''), 'trash');
});

test('nextDeleteMode：trash→ask→direct→trash（缺省首点不跳到不可恢复档）', () => {
  assert.equal(mod.nextDeleteMode('trash'), 'ask');
  assert.equal(mod.nextDeleteMode('ask'), 'direct');
  assert.equal(mod.nextDeleteMode('direct'), 'trash');
});

test('volumeToPref / prefToVolume：clamp 与缺省', () => {
  assert.equal(mod.volumeToPref(70), 0.7);
  assert.equal(mod.volumeToPref(-5), 0);
  assert.equal(mod.volumeToPref(150), 1);
  assert.equal(mod.volumeToPref(Number.NaN), 0.7);
  assert.equal(mod.prefToVolume(0.7), 70);
  assert.equal(mod.prefToVolume(-1), 0);
  assert.equal(mod.prefToVolume(2), 100);
});

test('paperPrefOf：白名单/非法回落', () => {
  assert.equal(mod.paperPrefOf('manuscript', 'letter'), 'manuscript');
  assert.equal(mod.paperPrefOf('memo', 'letter'), 'memo');
  assert.equal(mod.paperPrefOf('bad', 'letter'), 'letter');
});