// 回车 · ExportCore 纯函数单测（第 3 批 F4＋F16）
// 运行：node --experimental-strip-types --test tools/tests/export-core.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));

// 与 guide-core.test.mjs 同一加载方式：.ets 复制成 .ts 后由 node 类型剥离加载
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'exportcore-'));
const ts = path.join(tmp, 'ExportCore.ts');
fs.copyFileSync(path.join(root, 'entry/src/main/ets/model/ExportCore.ets'), ts);
const mod = await import('file://' + ts.replace(/\\/g, '/'));

test('safeFileName：非法字符全部去掉，格式 回车-<title>-<yyyyMMdd-HHmmss>.<ext>', () => {
  const ts = new Date(2026, 10, 9, 4, 33, 4).getTime(); // 本地时间 2026-11-09 04:33:04
  // 用字符码拼非法集（\ / : * ? " < > |），避免源码里的转义歧义
  const illegal = ['/', ':', '*', '?', '"', '<', '>', '|', String.fromCharCode(92)];
  const name = mod.safeFileName('a' + illegal.join('') + 'b', 'txt', ts);
  for (const ch of illegal) {
    assert.ok(!name.includes(ch), `文件名仍含非法字符 ${ch}: ${name}`);
  }
  assert.equal(name, '回车-ab-20261109-043304.txt');
  assert.match(name, /^回车-.+-\d{8}-\d{6}\.txt$/);
  // 反斜杠必须真被去掉（旧实现曾漏掉 \，单测看不出）
  const bs = String.fromCharCode(92);
  assert.ok(!mod.safeFileName('x' + bs + 'y', 'txt', ts).includes(bs), '反斜杠没被去掉');
});

test('safeFileName：空标题/纯非法字符回落「回车」', () => {
  const ts = new Date(2026, 0, 2, 3, 4, 5).getTime();
  assert.equal(mod.safeFileName('', 'png', ts), '回车-回车-20260102-030405.png');
  assert.equal(mod.safeFileName('   ', 'pdf', ts), '回车-回车-20260102-030405.pdf');
  assert.equal(mod.safeFileName('///:::', 'pdf', ts), '回车-回车-20260102-030405.pdf');
});

test('safeFileName：时间戳补零到 yyyyMMdd-HHmmss；扩展名可带点', () => {
  const ts = new Date(2026, 8, 1, 0, 0, 0).getTime();
  assert.equal(mod.safeFileName('信', 'txt', ts), '回车-信-20260901-000000.txt');
  assert.equal(mod.safeFileName('信', '.txt', ts), '回车-信-20260901-000000.txt');
});

test('resultText：三种组合键名固定，且永不含“已分享成功”', () => {
  assert.equal(mod.resultText(true, false), 'export_result_saved');
  assert.equal(mod.resultText(false, true), 'export_result_shared');
  assert.equal(mod.resultText(true, true), 'export_result_saved_shared');
  assert.equal(mod.resultText(false, false), '');
  for (const pair of [[true, false], [false, true], [true, true], [false, false]]) {
    const key = mod.resultText(pair[0], pair[1]);
    assert.ok(!key.includes('已分享成功'), `禁止词命中: ${key}`);
    assert.ok(!key.includes('分享成功'), `禁止词命中: ${key}`);
  }
  // 键名只能取自白名单（任何“成功”语义都不许出现）
  const allowed = new Set([
    'export_result_saved', 'export_result_shared', 'export_result_saved_shared', '',
  ]);
  assert.ok(allowed.has(mod.resultText(true, true)));
});

test('machineTitleKey：四机映射 + 未知回落 1920s', () => {
  assert.equal(mod.machineTitleKey('1920s-upright'), 'machine_name_1920s');
  assert.equal(mod.machineTitleKey('1930s-portable'), 'machine_name_1930s');
  assert.equal(mod.machineTitleKey('1950s-streamlined'), 'machine_name_1950s');
  assert.equal(mod.machineTitleKey('1960s-electric'), 'machine_name_1960s');
  assert.equal(mod.machineTitleKey('1999s-unknown'), 'machine_name_1920s');
  assert.equal(mod.machineTitleKey(''), 'machine_name_1920s');
});

test('templateLayout：全部在 1080×1440 内、自上而下递增、互不重叠', () => {
  const L = mod.templateLayout();
  const W = mod.EXPORT_TEMPLATE_W;
  const H = mod.EXPORT_TEMPLATE_H;
  assert.equal(W, 1080);
  assert.equal(H, 1440);
  for (const [name, y] of Object.entries({
    titleY: L.titleY, machineY: L.machineY, dateY: L.dateY, bodyTop: L.bodyTop, pageNoY: L.pageNoY,
  })) {
    assert.ok(y >= 0 && y < H, `${name}=${y} 越界（0..${H}）`);
  }
  const rects = [
    { name: 'title', top: L.titleY, h: mod.EXPORT_TITLE_H },
    { name: 'machine', top: L.machineY, h: mod.EXPORT_MACHINE_H },
    { name: 'date', top: L.dateY, h: mod.EXPORT_DATE_H },
    { name: 'body', top: L.bodyTop, h: mod.EXPORT_BODY_LINES * L.bodyLine },
    { name: 'pageNo', top: L.pageNoY, h: mod.EXPORT_PAGE_H },
  ];
  for (let i = 1; i < rects.length; i++) {
    const prev = rects[i - 1];
    assert.ok(rects[i].top > prev.top, `${rects[i].name} 未在 ${prev.name} 之后`);
    assert.ok(prev.top + prev.h <= rects[i].top, `${prev.name} 与 ${rects[i].name} 重叠`);
  }
  const last = rects[rects.length - 1];
  assert.ok(last.top + last.h <= H, '页码越出画布底边');
  // 画布宽内（左右边距 + 内容宽 ≤ 画布宽）
  assert.ok(mod.EXPORT_MARGIN_X > 0 && mod.EXPORT_MARGIN_X * 2 < W, '左右边距不合理');
  assert.ok(L.bodyTop > L.dateY, 'bodyTop 必须在 dateY 之下');
  assert.ok(L.bodyLine > 0, 'bodyLine 必须为正');
});

test('常量钉死：进度/淡出/模板尺寸/临时目录', () => {
  assert.equal(mod.EXPORT_PROGRESS_MIN_MS, 300);
  assert.equal(mod.EXPORT_RESULT_FADE_MS, 0);
  assert.equal(mod.EXPORT_TEMPLATE_W, 1080);
  assert.equal(mod.EXPORT_TEMPLATE_H, 1440);
  assert.equal(mod.EXPORT_TMP_DIR, 'export-tmp');
  assert.equal(mod.EXPORT_BODY_LINES, 12);
});

test('ExportCore 保持纯：不 import 任何 @kit', () => {
  const src = fs.readFileSync(path.join(root, 'entry/src/main/ets/model/ExportCore.ets'), 'utf8');
  assert.ok(!/@kit\./.test(src), 'ExportCore 不许 import @kit');
  assert.ok(!/\bfs\./.test(src), 'ExportCore 不许做文件 I/O');
});