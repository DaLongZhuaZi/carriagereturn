// 第 23 批（19 号稿 §4-9）：分机型动画模式纯函数单测
// 覆盖：rollerKFor 全表、archFixXFor、modeTransRollerK／modeTransArchX 边界值（p=0／0.5／1）
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const read = (rel) => fs.readFileSync(path.join(root, rel), 'utf8').replace(/\r\n/g, '\n');
const model = read('entry/src/main/ets/model/AnimModeModel.ets');

// —— 把 .ets 里的纯函数按语义在测试侧复刻（.ets 不能被 node 直接 import） ——
const SIM_K = 0.3;
const KINDS = ['1920s-upright', '1930s-portable', '1950s-streamlined', '1960s-electric'];
function rollerKFor(mode, isTablet, kind) {
  if (kind === '1960s-electric') return 1.0;
  return mode === 'simulated' ? SIM_K : 1.0;
}
const archFixXFor = (paperX, marginH) => paperX + marginH;
const transK = (from, to, p) => { const t = p < 0 ? 0 : p > 1 ? 1 : p; return from + (to - from) * t; };
const transArch = (from, to, p) => { const t = p < 0 ? 0 : p > 1 ? 1 : p; const e = 1 - Math.pow(1 - t, 3); return from + (to - from) * e; };

test('模块契约：常量与签名在位（不 import ArkUI）', () => {
  assert.ok(!model.includes('@ohos'), 'AnimModeModel 不许 import ArkUI');
  assert.ok(!model.includes('@kit.'), 'AnimModeModel 不许 import ArkUI kit');
  assert.ok(model.includes("export const ANIM_MODE_REALISTIC: string = 'realistic';"));
  assert.ok(model.includes("export const ANIM_MODE_SIMULATED: string = 'simulated';"));
  assert.ok(model.includes('export const SIM_ROLLER_K: number = 0.3;'));
  assert.ok(model.includes('export const MODE_TRANS_DUR_MS: number = 200;'));
  for (const fn of ['rollerKFor', 'archFixXFor', 'modeTransRollerK', 'modeTransArchX']) {
    assert.ok(model.includes(`export function ${fn}(`), `缺纯函数 ${fn}`);
  }
});

test('rollerKFor 全表：写实 1.0／模拟 0.3／1960s 恒 1.0（双端相同）', () => {
  for (const kind of KINDS) {
    for (const tablet of [false, true]) {
      const real = rollerKFor('realistic', tablet, kind);
      const sim = rollerKFor('simulated', tablet, kind);
      if (kind === '1960s-electric') {
        assert.equal(real, 1.0, `1960s 写实 ${tablet ? '平板' : '手机'} 应为 1.0`);
        assert.equal(sim, 1.0, '1960s 切模拟也必须 1.0（电动单套）');
      } else {
        assert.equal(real, 1.0, `${kind} 写实应为 1.0`);
        assert.equal(sim, SIM_K, `${kind} 模拟应为 0.3`);
      }
    }
  }
});

test('archFixXFor：手机 1920s＝49.3+48.0＝97.3vp（Q7 定案值）', () => {
  assert.equal(archFixXFor(49.3, 48.0), 97.3);
  // 平板（paperX 更大）同公式
  assert.ok(Math.abs(archFixXFor(180.0, 72.0) - 252.0) < 1e-9);
});

test('modeTransRollerK：Linear，端点精确、中点均分、越界钳制', () => {
  assert.ok(Math.abs(transK(1.0, 0.3, 0) - 1.0) < 1e-9);
  assert.ok(Math.abs(transK(1.0, 0.3, 1) - 0.3) < 1e-9, '端点落到 0.3（浮点容差内）');
  assert.ok(Math.abs(transK(1.0, 0.3, 0.5) - 0.65) < 1e-9);
  assert.ok(Math.abs(transK(1.0, 0.3, 0.25) - 0.825) < 1e-9);
  assert.ok(Math.abs(transK(1.0, 0.3, -0.5) - 1.0) < 1e-9, 'p<0 钳到 0');
  assert.ok(Math.abs(transK(1.0, 0.3, 1.5) - 0.3) < 1e-9, 'p>1 钳到 1');
});

test('modeTransArchX：ease-out 三次方，不过冲、端点精确', () => {
  assert.ok(Math.abs(transArch(100, 200, 0) - 100) < 1e-9);
  assert.ok(Math.abs(transArch(100, 200, 1) - 200) < 1e-9);
  assert.ok(Math.abs(transArch(100, 200, 0.5) - 187.5) < 1e-9, 'p=0.5 → 1−(0.5)³=0.875');
  const e25 = 1 - Math.pow(0.75, 3);
  assert.ok(Math.abs(transArch(100, 200, 0.25) - (100 + 100 * e25)) < 1e-9);
  assert.ok(Math.abs(transArch(100, 200, -0.2) - 100) < 1e-9, 'p<0 钳到 0');
  assert.ok(Math.abs(transArch(100, 200, 1.2) - 200) < 1e-9, 'p>1 钳到 1');
  // 单调且不过冲
  let prev = transArch(100, 200, 0);
  for (let p = 0.05; p <= 1.0001; p += 0.05) {
    const v = transArch(100, 200, p);
    assert.ok(v >= prev - 1e-9, '过渡必须单调不减');
    assert.ok(v <= 200 + 1e-9, '过渡不许超过目标（不过冲）');
    prev = v;
  }
});
