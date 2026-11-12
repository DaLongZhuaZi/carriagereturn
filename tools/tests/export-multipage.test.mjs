// 第 13 批 ⑥：模板可见块版式 / 日期口径 / 多纸与多篇纯文本组装
// 运行：node --experimental-strip-types --test tools/tests/export-multipage.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'exportmp-'));
const ts = path.join(tmp, 'ExportCore.ts');
fs.copyFileSync(path.join(root, 'entry/src/main/ets/model/ExportCore.ets'), ts);
const mod = await import('file://' + ts.replace(/\\/g, '/'));

test('templateLayout(visible)：隐藏块不占位、其余块仍自上而下且不越界', () => {
  const H = mod.EXPORT_TEMPLATE_H;
  const full = mod.templateLayout(mod.allVisible());
  // 全隐藏：所有块顶边落在标题位（不出现负值/越界）
  const none = mod.templateLayout({ title: false, machine: false, date: false, body: false, pageNo: false });
  assert.equal(none.machineY, 96, '隐藏标题后机器块回到标题位');
  assert.equal(none.dateY, none.machineY, '隐藏机器框后日期块回到机器位');
  assert.ok(none.bodyTop <= H, '正文顶不越界');
  // 只保留正文：正文顶应上移到标题位（96）
  const bodyOnly = mod.templateLayout({ title: false, machine: false, date: false, body: true, pageNo: false });
  assert.equal(bodyOnly.bodyTop, 96);
  // 全部可见时与旧版式一致（titleY 96 / machineY 200）
  assert.equal(full.titleY, 96);
  assert.equal(full.machineY, 200);
  // 各字段仍是整数
  for (const v of Object.values(full)) {
    assert.equal(Number.isInteger(v), true, `布局字段必须整数: ${v}`);
  }
});

test('formatDateText：取时间戳（文档 createdAt）而非当天', () => {
  const tsLocal = new Date(2026, 0, 5, 12, 0, 0).getTime();
  assert.equal(mod.formatDateText(tsLocal), '2026-01-05');
  const ts2 = new Date(2025, 11, 31, 23, 59, 59).getTime();
  assert.equal(mod.formatDateText(ts2), '2025-12-31');
});

test('assembleSheetText：归档纸在前、每纸后加分隔行、当前纸收尾无分隔', () => {
  const text = mod.assembleSheetText([['aaa'], ['bbb']], ['ccc']);
  assert.equal(text, 'aaa\n--- 第 1 / 3 纸 ---\nbbb\n--- 第 2 / 3 纸 ---\nccc\n');
});

test('assembleSheetText：无归档纸时只有当前纸', () => {
  assert.equal(mod.assembleSheetText([], ['x']), 'x\n');
});

test('assembleDossierText：篇间空行分隔、篇内保留纸分隔、结尾有换行', () => {
  const a = mod.assembleSheetText([], ['p1']);
  const b = mod.assembleSheetText([['q1']], ['q2']);
  const text = mod.assembleDossierText([a, b]);
  assert.equal(text, 'p1\n\nq1\n--- 第 1 / 2 纸 ---\nq2\n');
});

test('sheetSeparatorText/docSeparatorText 字面与设计稿一致', () => {
  assert.equal(mod.sheetSeparatorText(2, 5), '--- 第 2 / 5 纸 ---');
  assert.equal(mod.docSeparatorText('我的卷宗'), '=== 我的卷宗 ===');
});
