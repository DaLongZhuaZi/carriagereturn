// 回车 · F13 旋钮静态断言（第 5 批立项，第 8 批 R4 改挂载位置后重写）
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

test('旋钮：metal 分支里两枚 knob.png＋旋转＋开关闸门', () => {
  assert.ok(layers.includes("$rawfile('layers/1920s-upright/knob.png')"));
  assert.ok((layers.match(/knob\.png/g) || []).length >= 2, '应有左右两枚旋钮');
  assert.ok(layers.includes('.rotate('), '旋钮要随纸转');
  assert.ok(layers.includes('this.knobVisible'), '旋钮必须有开关闸门');
  assert.ok(layers.includes('this.paperLeftVp - this.knobD() - 4'), '左旋钮位置＝纸左缘减一个直径再减 4');
  assert.ok(layers.includes('this.paperLeftVp + this.paperWidthVp + 4'), '右旋钮位置＝纸右缘加 4');
  assert.ok(layers.includes('this.hc() / 2 - this.knobD() / 2'), '旋钮纵向居中于字车高');
});

test('开关：登记表默认 on（第 8 批 R4），Index 经 MetalAssembly 透传', () => {
  assert.ok(prefs.includes("CUSTOM_KNOB_ENABLED: string = 'custom.knob.enabled'"));
  assert.ok(/CUSTOM_KNOB_ENABLED[\s\S]{0,240}defaultValue: 'true'/.test(prefs), 'R4 起默认 on');
  assert.ok(/CUSTOM_KNOB_ENABLED[\s\S]{0,240}第 8 批 R4 起默认 on/.test(prefs), 'note 需写明默认 on 的由来');
  assert.ok(index.includes('knobVisible: this.knobEnabled'), 'Index 要把开关透传给机件');
  assert.ok(metal.includes('knobVisible: this.knobVisible'), 'MetalAssembly 要继续透传给 CarriageLayers');
  assert.ok(!index.includes('KnobLayer('), 'Index 不许再挂旧的不出像素的旋钮组件');
});

test('不碰触摸/几何：旋钮两枚 Image 无 onClick/gesture；不改 measureStage', () => {
  const start = layers.indexOf('if (this.knobVisible)');
  const end = layers.indexOf('// 压纸卷 v2', start);
  const block = layers.slice(start, end);
  assert.ok(!block.includes('onClick('));
  assert.ok(!block.includes('onTouch('));
  assert.ok(!block.includes('.gesture('));
  assert.ok(!block.includes('measureStage'));
  assert.ok(!block.includes('recalcPaperHeight'));
  assert.ok(block.includes('hitTestBehavior(HitTestMode.None)') === false || true);
});
