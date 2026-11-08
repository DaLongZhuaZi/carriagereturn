// 回车 · CustomizeCore 纯函数单测（第 2 批 F3）
// 运行：node --experimental-strip-types --test tools/tests/customize-core.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'customcore-'));
const ts = path.join(tmp, 'CustomizeCore.ts');
fs.copyFileSync(path.join(root, 'entry/src/main/ets/model/CustomizeCore.ets'), ts);
const mod = await import('file://' + ts.replace(/\\/g, '/'));

test('字号：范围 12–26，坏输入回落 17（不套 17 下限）', () => {
  assert.equal(mod.FONT_SIZE_MIN, 12);
  assert.equal(mod.FONT_SIZE_MAX, 26);
  assert.equal(mod.clampFontSize(12), 12);
  assert.equal(mod.clampFontSize(13), 13, '13 必须原样通过（B-3 删 17 下限）');
  assert.equal(mod.clampFontSize(17), 17);
  assert.equal(mod.clampFontSize(26), 26);
  assert.equal(mod.clampFontSize(1), 12);
  assert.equal(mod.clampFontSize(99), 26);
  assert.equal(mod.clampFontSize(Number.NaN), 17);
  assert.equal(mod.clampFontSize(0), 17);
});

test('生效字号：userSize<=0／NaN → computed 现算值', () => {
  assert.equal(mod.effectiveFontSize(0, 24), 24);
  assert.equal(mod.effectiveFontSize(-3, 17), 17);
  assert.equal(mod.effectiveFontSize(Number.NaN, 24), 24);
  assert.equal(mod.effectiveFontSize(0, 0), 17, 'computed 非法时回落 17');
  assert.equal(mod.effectiveFontSize(13, 24), 13);
  assert.equal(mod.effectiveFontSize(99, 17), 26);
});

test('行高恒 fontSize × 30/17（§18.9）', () => {
  assert.equal(mod.LINE_HEIGHT_RATIO, 30 / 17);
  assert.equal(mod.lineHeightOf(17), 30);
  assert.ok(Math.abs(mod.lineHeightOf(24) - 42.35294117647059) < 1e-9,
    `lineHeight(24)=${mod.lineHeightOf(24)}`);
  assert.ok(Math.abs(mod.lineHeightOf(12) - 21.176470588235293) < 1e-9);
  assert.ok(mod.lineHeightOf(0) > 0, '坏输入也返回正行高');
});

test('边距两套：手机 H 24–40 / T 16–32 / B 16–28', () => {
  assert.equal(mod.clampMarginH(false, 10), 24);
  assert.equal(mod.clampMarginH(false, 30), 30);
  assert.equal(mod.clampMarginH(false, 100), 40);
  assert.equal(mod.clampMarginT(false, 1), 16);
  assert.equal(mod.clampMarginT(false, 32), 32);
  assert.equal(mod.clampMarginT(false, 40), 32);
  assert.equal(mod.clampMarginB(false, 1), 16);
  assert.equal(mod.clampMarginB(false, 28), 28);
  assert.equal(mod.clampMarginB(false, 30), 28);
  assert.equal(mod.clampMarginH(false, Number.NaN), 24, '坏值取 min');
});

test('边距两套：平板 H 40–56 / T 24–40 / B 20–32', () => {
  assert.equal(mod.clampMarginH(true, 10), 40);
  assert.equal(mod.clampMarginH(true, 48), 48, 'catalog 默认 48 在平板范围内');
  assert.equal(mod.clampMarginH(true, 100), 56);
  assert.equal(mod.clampMarginT(true, 1), 24);
  assert.equal(mod.clampMarginT(true, 40), 40);
  assert.equal(mod.clampMarginT(true, 50), 40);
  assert.equal(mod.clampMarginB(true, 1), 20);
  assert.equal(mod.clampMarginB(true, 32), 32);
  assert.equal(mod.clampMarginB(true, 50), 32);
});

test('字体列表：去重、删除、坏 JSON 返回空', () => {
  const a = { familyName: 'imp-1-A', path: '/files/a.ttf', size: 1024, status: 'ok' };
  assert.deepEqual(mod.fontListOf(''), []);
  assert.deepEqual(mod.fontListOf('not-json'), []);
  assert.deepEqual(mod.fontListOf('{"a":1}'), [], '非数组按空处理');

  const added = mod.fontListAdd('', a);
  assert.equal(JSON.parse(added).length, 1);
  assert.equal(mod.fontListOf(added)[0].familyName, 'imp-1-A');

  // 同 familyName 再导入：替换而非追加（status 更新）
  const replaced = mod.fontListAdd(added,
    { familyName: 'imp-1-A', path: '/files/a2.ttf', size: 2048, status: 'failed' });
  const after = mod.fontListOf(replaced);
  assert.equal(after.length, 1);
  assert.equal(after[0].status, 'failed');
  assert.equal(after[0].path, '/files/a2.ttf');

  // 坏 JSON 起点：按空列表 + 新条目
  assert.equal(mod.fontListOf(mod.fontListAdd('garbage', a)).length, 1);

  assert.equal(mod.fontListOf(mod.fontListRemove(replaced, 'imp-1-A')).length, 0);
  assert.equal(mod.fontListRemove('garbage', 'imp-1-A'), '[]');

  // 缺 familyName 的坏条目跳过
  const withBad = '[{"path":"/x"},{"familyName":"B","path":"/b","size":1,"status":"ok"}]';
  assert.equal(mod.fontListOf(withBad).length, 1);
});

test('预设 JSON：坏 JSON／缺字段补默认（color ""／ruled false／边距 0／texture ""）', () => {
  const defaults = { color: '', ruled: false, marginH: 0, marginT: 0, marginB: 0, texture: '' };
  assert.deepEqual(mod.paperPresetFromJson(''), defaults);
  assert.deepEqual(mod.paperPresetFromJson('not-json'), defaults);
  assert.deepEqual(mod.paperPresetFromJson('[1,2]'), defaults, '非对象按默认');

  const p = mod.paperPresetFromJson(
    '{"color":"#123456","ruled":true,"marginH":30,"marginT":-4,"marginB":2.6,"texture":"/p/x.jpg"}');
  assert.equal(p.color, '#123456');
  assert.equal(p.ruled, true);
  assert.equal(p.marginH, 30);
  assert.equal(p.marginT, 0, '负边距回落 0');
  assert.equal(p.marginB, 3, '边距取整');
  assert.equal(p.texture, '/p/x.jpg');

  assert.equal(mod.paperPresetFromJson('{"color":"red"}').color, '', '非法颜色回落空');
  // 往返
  assert.deepEqual(mod.paperPresetFromJson(mod.paperPresetToJson(p)), p);
});

test('预设表：增删与坏 JSON 空表', () => {
  const d = { color: '', ruled: false, marginH: 0, marginT: 0, marginB: 0, texture: '' };
  assert.deepEqual(mod.presetsOf('{}'), []);
  assert.deepEqual(mod.presetsOf('garbage'), []);
  assert.deepEqual(mod.presetsOf('[1,2]'), [], '数组不是预设表');
  const one = mod.presetAdd('{}', '温暖', d);
  assert.deepEqual(mod.presetsOf(one), ['温暖']);
  assert.deepEqual(mod.presetsOf(mod.presetAdd('[1,2]', '温暖', d)), ['温暖'], '数组起点按空表');
  assert.deepEqual(mod.presetOf(one, '温暖'), d);
  assert.equal(mod.presetOf(one, '没有'), null);
  const two = mod.presetAdd(one, '冷', { color: '#aabbcc', ruled: true, marginH: 24, marginT: 16, marginB: 16, texture: '' });
  assert.deepEqual(mod.presetsOf(two), ['温暖', '冷']);
  assert.deepEqual(mod.presetsOf(mod.presetRemove(two, '温暖')), ['冷']);
  assert.deepEqual(mod.presetsOf(mod.presetRemove('garbage', 'x')), []);
});

test('hexColorOr：只认 #RRGGBB', () => {
  assert.equal(mod.hexColorOr('#000000', '#a1b2c3'), '#a1b2c3');
  assert.equal(mod.hexColorOr('#000000', '#AABBCC'), '#AABBCC');
  assert.equal(mod.hexColorOr('#000000', 'a1b2c3'), '#000000');
  assert.equal(mod.hexColorOr('#000000', '#a1b2c'), '#000000');
  assert.equal(mod.hexColorOr('#000000', '#gggggg'), '#000000');
  assert.equal(mod.hexColorOr('#000000', ''), '#000000');
});

test('PAPER_COLORS：3–5 个合法 #RRGGBB 且不重复', () => {
  assert.ok(mod.PAPER_COLORS.length >= 3 && mod.PAPER_COLORS.length <= 5);
  for (const c of mod.PAPER_COLORS) {
    assert.match(c, /^#[0-9a-fA-F]{6}$/);
  }
  assert.equal(new Set(mod.PAPER_COLORS).size, mod.PAPER_COLORS.length);
});

test('validFamilyName：去目录/扩展名、非法字符剔除、空回落 font、截断 32', () => {
  assert.equal(mod.validFamilyName('My Font.ttf'), 'My-Font');
  assert.equal(mod.validFamilyName('/sandbox/imports/fonts/c.otf'), 'c');
  assert.equal(mod.validFamilyName('汉字.ttf'), 'font');
  assert.equal(mod.validFamilyName(''), 'font');
  const long = mod.validFamilyName('a'.repeat(40) + '.ttf');
  assert.equal(long.length, 32);
  assert.equal(mod.validFamilyName('ok_name-1.ttf'), 'ok_name-1');
});
