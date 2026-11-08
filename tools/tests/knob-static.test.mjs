// 回车 · F13 旋钮静态断言（第 5 批）
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const knob = fs.readFileSync(path.join(root, 'entry/src/main/ets/components/KnobLayer.ets'), 'utf8');
const index = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8');
const prefs = fs.readFileSync(path.join(root, 'entry/src/main/ets/services/AppPreferences.ets'), 'utf8');

test('KnobLayer：两枚 knob.png＋金色指针＋旋转＋非触摸', () => {
  assert.ok(knob.includes("$rawfile('layers/1920s-upright/knob.png')"));
  assert.ok((knob.match(/knob\.png/g) || []).length >= 2);
  assert.ok(knob.includes('#c9a45c'), '缺金色指针');
  assert.ok(knob.includes('.rotate('));
  assert.ok(knob.includes('hitTestBehavior(HitTestMode.None)'));
  assert.ok(knob.includes('this.knobAt(this.leftXVp)'));
  assert.ok(knob.includes('this.knobAt(this.rightXVp)'));
});

test('Index：开关默认 off；仅 1920s＋useLayers＋knobEnabled 挂载；位置公式', () => {
  assert.ok(prefs.includes("CUSTOM_KNOB_ENABLED: string = 'custom.knob.enabled'"));
  assert.ok(prefs.includes("defaultValue: 'false'"));
  assert.ok(index.includes('custom.knob.enabled') || index.includes('PrefKeys.CUSTOM_KNOB_ENABLED'));
  assert.ok(index.includes('this.hasLayers()'));
  assert.ok(index.includes('this.useLayers && this.knobEnabled'));
  assert.ok(index.includes('this.machineKind === MachineKind.UPRIGHT_1920S'));
  assert.ok(index.includes('this.paperLeftFixed() - this.knobD() - 4'));
  assert.ok(index.includes('this.paperLeftFixed() + this.paperWidthVp + 4'));
  assert.ok(index.includes('this.carriageTopVp - this.knobD() / 2'));
});

test('不碰触摸/几何：KnobLayer 无 onClick/gesture；Index 不因旋钮改 measureStage', () => {
  assert.ok(!knob.includes('onClick('));
  assert.ok(!knob.includes('onTouch('));
  assert.ok(!knob.includes('.gesture('));
  // 旋钮条件块不出现 measureStage/recalc 调用
  const start = index.indexOf('if (this.machineKind === MachineKind.UPRIGHT_1920S && this.hasLayers()');
  const end = index.indexOf('}', index.indexOf('KnobLayer({', start));
  const block = index.slice(start, end);
  assert.ok(!block.includes('measureStage'));
  assert.ok(!block.includes('recalcPaperHeight'));
});