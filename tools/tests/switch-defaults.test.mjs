// 回车 · 开关默认值静态断言（源码级，不编译）
// 背景：2026-11-09 精修复核推翻了三路评审的原判——GUIDE_ENABLED / CUSTOM_ENABLED
// 的 'true' 不是事故，是已评审的决定（F1 批内一次交付完整，默认 on；F3 开发期默认
// off、静态验收后批末改 on，第 2 批评审 M-14）。本测试把“登记值＝消费方 fallback＝
// 已评审的意图”锁死，防以后再把“默认 off”误读成代码 bug 而误改。
// 运行：node --experimental-strip-types --test tools/tests/switch-defaults.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const read = (rel) => fs.readFileSync(path.join(root, rel), 'utf8');

const prefs = read('entry/src/main/ets/services/AppPreferences.ets');
const guideService = read('entry/src/main/ets/services/GuideService.ets');
const customizeStore = read('entry/src/main/ets/services/CustomizeStore.ets');
const index = read('entry/src/main/ets/pages/Index.ets');

function registryDefault(constName) {
  const m = prefs.match(
    new RegExp(`PrefKeys\\.${constName}, type: 'boolean', defaultValue: '(true|false)'`)
  );
  assert.ok(m, `登记表缺 ${constName} 的 boolean 默认值`);
  return m[1];
}

test('登记值：三项均为 true（各有已评审依据）', () => {
  assert.equal(registryDefault('GUIDE_ENABLED'), 'true', 'guide.enabled 默认 on：F1 批内一次交付完整');
  assert.equal(registryDefault('CUSTOM_ENABLED'), 'true', 'custom.enabled 批末改 on：第 2 批 M-14');
  // 第 8 批 R4：1920s 基线已于 bc6edce 重拍，登记表 note 写明的开启前置已满足 → 默认改 on
  assert.equal(registryDefault('CUSTOM_KNOB_ENABLED'), 'true', '旋钮默认 on：第 8 批 R4，基线重拍前置已满足');
});

test('消费方 fallback 必须与登记值一致（防漂移；旋钮改读登记表默认值）', () => {
  assert.match(guideService, /getBool\(PrefKeys\.GUIDE_ENABLED, true\)/);
  assert.match(customizeStore, /getBool\(PrefKeys\.CUSTOM_ENABLED, true\)/);
  // 第 8 批 R4：旋钮不再硬编码 false，改为读登记表（默认值只在 PrefRegistry 写一次）
  assert.match(index, /getBool\(PrefKeys\.CUSTOM_KNOB_ENABLED,\s*\n?\s*AppPreferences\.defaultBool\(PrefKeys\.CUSTOM_KNOB_ENABLED\)\)/);
});

test('登记 note 必须写明开启依据（读登记表就能知道为什么不是 off）', () => {
  assert.match(prefs, /GUIDE_ENABLED[\s\S]{0,200}F1 批内一次交付完整/);
  assert.match(prefs, /CUSTOM_ENABLED[\s\S]{0,200}第 2 批 M-14/);
  assert.match(prefs, /CUSTOM_KNOB_ENABLED[\s\S]{0,240}第 8 批 R4 起默认 on/);
});
