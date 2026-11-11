// 回车 · F13 旋钮静态断言（第 5 批立项；第 12 批 ① 删除旋钮后改为「删除态」断言）
// 事实源变更：旋钮原先由 components/KnobLayer.ets 在 Index 的一个子栈里挂载，
// 真机实测整棵子树不参与绘制（红底探针 0 px）；第 8 批 R4 改到 machines/1920s/CarriageLayers.ets
// 的 metal 分支（与底座/压纸卷同一套 .position 画法，已实证能出像素），开关经
// Index → MetalAssembly1920 → CarriageLayers 的 knobVisible 透传。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const layers = fs.readFileSync(path.join(root, 'entry/src/main/ets/machines/1920s/CarriageLayers.ets'), 'utf8');
const metal = fs.readFileSync(path.join(root, 'entry/src/main/ets/machines/1920s/MetalAssembly1920.ets'), 'utf8');
const index = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8');
const prefs = fs.readFileSync(path.join(root, 'entry/src/main/ets/services/AppPreferences.ets'), 'utf8');

test('旋钮：1920s 机件不再渲染 knob.png（第 12 批 ① 用户定「把那两个轮子删掉」）', () => {
  assert.ok(!layers.includes("$rawfile('layers/1920s-upright/knob.png')"), 'CarriageLayers 不许再引用 knob.png');
  assert.ok(!layers.includes('knobVisible'), 'knobVisible 闸门应随旋钮一起删除');
  assert.ok(!metal.includes('knobVisible'), 'MetalAssembly1920 不许再透传 knobVisible');
  assert.ok(!index.includes('knobEnabled'), 'Index 不许再有 knobEnabled 状态');
});

test('开关：CUSTOM_KNOB_ENABLED 已从登记表与 isRegistered() 固定列表删除', () => {
  assert.ok(!prefs.includes("CUSTOM_KNOB_ENABLED: string = 'custom.knob.enabled'"), '常量应删除');
  assert.ok(!/CUSTOM_KNOB_ENABLED/.test(prefs), '登记表与 isRegistered 都不许残留 CUSTOM_KNOB_ENABLED');
  assert.ok(!index.includes('knobVisible: this.knobEnabled'), 'Index 不许再传开关');
});

test('不碰几何：knobD／knobAngle 仍保留（滚筒转角与底座宽照旧用它们）', () => {
  assert.ok(layers.includes('knobAngleDeg'), '滚筒转角仍由 knobAngle 驱动');
  assert.ok(layers.includes('knobD()'), '底座宽/左缘仍用 knobD 几何');
  assert.ok(!layers.includes('if (this.knobVisible)'), '旋钮渲染块已删除');
});
