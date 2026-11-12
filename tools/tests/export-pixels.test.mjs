// 回车 · F16 模板版式像素/矩形断言（纯函数，无设备）
// 运行：node --experimental-strip-types --test tools/tests/export-pixels.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'exportpixels-'));
const ts = path.join(tmp, 'ExportCore.ts');
fs.copyFileSync(path.join(root, 'entry/src/main/ets/model/ExportCore.ets'), ts);
const mod = await import('file://' + ts.replace(/\\/g, '/'));

const W = mod.EXPORT_TEMPLATE_W;
const H = mod.EXPORT_TEMPLATE_H;
const L = mod.templateLayout();

/** 各元素占位矩形（x 用统一左右边距，正文用纸面底板边距）。 */
function rects() {
  return [
    { name: 'title', x: mod.EXPORT_MARGIN_X, y: L.titleY, w: W - mod.EXPORT_MARGIN_X * 2, h: mod.EXPORT_TITLE_H },
    { name: 'machine', x: mod.EXPORT_MARGIN_X, y: L.machineY, w: W - mod.EXPORT_MARGIN_X * 2, h: mod.EXPORT_MACHINE_H },
    { name: 'date', x: mod.EXPORT_MARGIN_X, y: L.dateY, w: W - mod.EXPORT_MARGIN_X * 2, h: mod.EXPORT_DATE_H },
    { name: 'body', x: mod.EXPORT_MARGIN_X, y: L.bodyTop, w: W - mod.EXPORT_MARGIN_X * 2, h: mod.EXPORT_BODY_LINES * L.bodyLine },
    { name: 'pageNo', x: mod.EXPORT_MARGIN_X, y: L.pageNoY, w: W - mod.EXPORT_MARGIN_X * 2, h: mod.EXPORT_PAGE_H },
  ];
}

function overlaps(a, b) {
  return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
}

test('画布钉死 1080×1440（F16 离屏尺寸）', () => {
  assert.equal(W, 1080);
  assert.equal(H, 1440);
  assert.equal(W / H, 3 / 4, '模板必须是 3:4 竖版');
});

test('每个元素矩形都在画布内（含左右边距）', () => {
  for (const r of rects()) {
    assert.ok(r.x >= 0, `${r.name}.x=${r.x} 越界`);
    assert.ok(r.y >= 0, `${r.name}.y=${r.y} 越界`);
    assert.ok(r.x + r.w <= W, `${r.name} 右边界越界`);
    assert.ok(r.y + r.h <= H, `${r.name} 底边界越界`);
    assert.ok(r.w > 0 && r.h > 0, `${r.name} 尺寸非正`);
    assert.ok(r.x >= mod.EXPORT_MARGIN_X, `${r.name} 未守左右边距`);
  }
});

test('五块矩形两两不重叠', () => {
  const rs = rects();
  for (let i = 0; i < rs.length; i++) {
    for (let j = i + 1; j < rs.length; j++) {
      assert.ok(!overlaps(rs[i], rs[j]), `${rs[i].name} 与 ${rs[j].name} 重叠`);
    }
  }
});

test('自下而上顺序：标题 < 机器框 < 日期 < 正文 < 页码', () => {
  assert.ok(L.titleY < L.machineY, '标题必须在机器框之上');
  assert.ok(L.machineY < L.dateY, '机器框必须在日期之上');
  assert.ok(L.dateY < L.bodyTop, '日期必须在正文之上');
  assert.ok(L.bodyTop < L.pageNoY, '正文必须在页码之上');
  assert.equal(L.bodyLine, mod.EXPORT_BODY_LINE);
  assert.equal(L.bodyLine, 34, '正文行高 34');
});

test('正文区：13 行、行高 34、不压到页码（第 13 批 ⑥ 12→13）', () => {
  assert.equal(mod.EXPORT_BODY_LINES, 13);
  assert.equal(mod.EXPORT_BODY_LINE, 34);
  assert.equal(mod.EXPORT_BODY_SIZE, 20);
  const bodyBottom = L.bodyTop + mod.EXPORT_BODY_LINES * L.bodyLine;
  assert.ok(bodyBottom <= L.pageNoY, `正文底 ${bodyBottom} 压到页码 ${L.pageNoY}`);
  assert.ok(bodyBottom <= H, '正文底越出画布');
});

test('版式是纯函数：两次调用逐字段相等（与设备密度无关）', () => {
  const a = mod.templateLayout();
  const b = mod.templateLayout();
  assert.deepEqual(a, b);
  for (const v of Object.values(a)) {
    assert.equal(Number.isInteger(v), true, `布局字段必须整数: ${v}`);
  }
});