// 回车 · LeverAngleCore 纯函数 + 冻结常量单测（第 0b 批）
// 运行：node --experimental-strip-types --test tools/tests/lever-angle.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const src = path.join(root, 'entry/src/main/ets/model/LeverAngleCore.ets');
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'levercore-'));
const tsPath = path.join(tmpDir, 'LeverAngleCore.ts');
fs.copyFileSync(src, tsPath);
const mod = await import('file://' + tsPath.replace(/\\/g, '/'));

test('冻结常量：静止角/摆幅（平板 30/35，手机 15/20）', () => {
  assert.equal(mod.LEVER_REST_DEG_TABLET, 30);
  assert.equal(mod.LEVER_REST_DEG_PHONE, 15);
  assert.equal(mod.LEVER_SWING_DEG_TABLET, 35);
  assert.equal(mod.LEVER_SWING_DEG_PHONE, 20);
  assert.equal(mod.LEVER_COMMIT_RATIO, 0.5);
});

test('冻结常量：1920s 拨杆图宽高比与支点比例', () => {
  assert.ok(Math.abs(mod.LEVER_ASPECT_1920 - 536 / 2522) < 1e-12);
  assert.equal(mod.LEVER_PIVOT_X_1920, 0.5);
  assert.equal(mod.LEVER_PIVOT_Y_1920, 0.952);
});

test('f(0) = 各自静止角（四台机 × 平板/手机）', () => {
  const rests = [30, 30, 30, 30, 15, 15, 15, 15];
  for (const rest of rests) {
    const swing = rest === 30 ? 35 : 20;
    assert.equal(mod.angleFor(rest, swing, 0), rest);
  }
});

test('angleFor：单调递增、clamp 到 [0,1]、NaN 按 0', () => {
  const rest = 30;
  const swing = 35;
  assert.equal(mod.angleFor(rest, swing, 1), 65);
  assert.ok(mod.angleFor(rest, swing, 0.25) < mod.angleFor(rest, swing, 0.5));
  assert.ok(mod.angleFor(rest, swing, 0.5) < mod.angleFor(rest, swing, 0.75));
  assert.equal(mod.angleFor(rest, swing, 1.7), 65);
  assert.equal(mod.angleFor(rest, swing, -0.3), rest);
  assert.equal(mod.angleFor(rest, swing, Number.NaN), rest);
});

test('dragRatioFor：负截 0、满杆 1、超杆 1、杆长 0 安全', () => {
  assert.equal(mod.dragRatioFor(-100, 200), 0);
  assert.equal(mod.dragRatioFor(0, 200), 0);
  assert.equal(mod.dragRatioFor(100, 200), 0.5);
  assert.equal(mod.dragRatioFor(200, 200), 1);
  assert.equal(mod.dragRatioFor(999, 200), 1);
  assert.equal(mod.dragRatioFor(50, 0), 0);
});

test('pulledEnough：0.5 算过，0.4999 不算', () => {
  assert.equal(mod.pulledEnough(0.5), true);
  assert.equal(mod.pulledEnough(0.5001), true);
  assert.equal(mod.pulledEnough(0.4999), false);
  assert.equal(mod.pulledEnough(0), false);
});

test('restDegFor / swingDegFor：平板/手机分支', () => {
  assert.equal(mod.restDegFor(true), 30);
  assert.equal(mod.restDegFor(false), 15);
  assert.equal(mod.swingDegFor(true), 35);
  assert.equal(mod.swingDegFor(false), 20);
});

test('冻结源检查：四份渲染件都从 LeverAngleCore 取常量，无本地 REST_DEG/SWING_DEG', () => {
  const files = [
    'entry/src/main/ets/components/LeverLayer.ets',
    'entry/src/main/ets/machines/1930s/LeverLayer1930.ets',
    'entry/src/main/ets/machines/1950s/LeverLayer.ets',
    'entry/src/main/ets/machines/1960s/LeverLayer.ets',
  ];
  for (const rel of files) {
    const text = fs.readFileSync(path.join(root, rel), 'utf8');
    assert.ok(text.includes("from '../model/LeverAngleCore'") || text.includes("from '../../model/LeverAngleCore'"),
      `${rel} 未 import LeverAngleCore`);
    assert.ok(!/const\s+REST_DEG\s*=/.test(text), `${rel} 仍有本地 REST_DEG`);
    assert.ok(!/const\s+SWING_DEG\s*=/.test(text), `${rel} 仍有本地 SWING_DEG`);
    assert.ok(text.includes('angleFor('), `${rel} 未走 angleFor`);
  }
});

test('冻结源检查：MachineCatalog 四台机 leverAspect/pivot 未被改动', () => {
  const text = fs.readFileSync(path.join(root, 'entry/src/main/ets/model/MachineCatalog.ets'), 'utf8');
  const aspects = [...text.matchAll(/leverAspect:\s*([0-9.]+)/g)].map((m) => Number(m[1]));
  const pivotsX = [...text.matchAll(/leverPivotX:\s*([0-9.]+)/g)].map((m) => Number(m[1]));
  const pivotsY = [...text.matchAll(/leverPivotY:\s*([0-9.]+)/g)].map((m) => Number(m[1]));
  assert.deepEqual(aspects, [0.2125, 0.3264, 0.09, 0.12]);
  assert.deepEqual(pivotsX, [0.5, 0.538, 0.496, 0.502]);
  assert.deepEqual(pivotsY, [0.952, 0.96, 0.942, 0.948]);
});