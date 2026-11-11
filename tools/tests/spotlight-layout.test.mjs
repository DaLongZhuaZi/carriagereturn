// 回车 · 聚光灯气泡位置换算单测（第 10 批引导重设计，评审 M16）
// 运行：node --experimental-strip-types --test tools/tests/spotlight-layout.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'spotlight-'));
const ts = path.join(tmp, 'SpotlightLayout.ts');
fs.copyFileSync(path.join(root, 'entry/src/main/ets/model/SpotlightLayout.ets'), ts);
const L = await import('file://' + ts.replace(/\\/g, '/'));

const screenW = 673.7;
const screenH = 720;

test('目标在上半区 → 气泡在下方，水平居中对齐目标中心', () => {
  const t = { x: 100, y: 100, w: 200, h: 80 };
  const b = L.layoutSpotlight(t, screenW, screenH, 300, 150, 0, 0, 0);
  assert.equal(b.side, 'below');
  assert.ok(Math.abs(b.y - (t.y + t.h + 8)) < 0.001);
  assert.ok(Math.abs(b.x - (100 + 100 - 150)) < 0.001);
});

test('目标在下半区 → 气泡在上方', () => {
  const t = { x: 100, y: 560, w: 200, h: 60 };
  const b = L.layoutSpotlight(t, screenW, screenH, 300, 150, 0, 0, 0);
  assert.equal(b.side, 'above');
  assert.ok(Math.abs(b.y - (t.y - 8 - 150)) < 0.001);
});

test('左右 clamp：目标靠左/靠右时气泡不出屏', () => {
  const left = L.layoutSpotlight({ x: 0, y: 100, w: 40, h: 40 }, screenW, screenH, 300, 150, 0, 0, 0);
  assert.ok(left.x >= 16 - 0.001);
  const right = L.layoutSpotlight({ x: 640, y: 100, w: 30, h: 40 }, screenW, screenH, 300, 150, 0, 0, 0);
  assert.ok(right.x + right.w <= screenW - 16 + 0.001);
});

test('desk 折痕带：气泡撞带时移出带外', () => {
  const t = { x: 300, y: 300, w: 60, h: 40 };
  const b = L.layoutSpotlight(t, screenW, screenH, 300, 150, 380, 460, 0);
  const overlap = b.y < 460 && b.y + b.h > 380;
  assert.equal(overlap, false, '气泡不得压在折痕带 380–460');
});

test('键盘禁区：气泡底不得越过键盘顶', () => {
  const t = { x: 300, y: 300, w: 60, h: 40 };
  const b = L.layoutSpotlight(t, screenW, screenH, 300, 150, 0, 0, 600);
  assert.ok(b.y + b.h <= 600 - 8 + 0.001, '气泡应在键盘顶上方');
});

test('两侧都放不下：落到较大空余区，箭头仍指目标中心', () => {
  const t = { x: 300, y: 330, w: 60, h: 40 };
  const b = L.layoutSpotlight(t, screenW, screenH, 300, 200, 0, 0, 0);
  assert.ok(b.y >= 16);
  assert.ok(b.arrowX >= b.x && b.arrowX <= b.x + b.w);
});

test('箭头独立跟目标中心（气泡被 clamp 后箭头仍指目标横坐标）', () => {
  const t = { x: 0, y: 100, w: 30, h: 40 };
  const b = L.layoutSpotlight(t, screenW, screenH, 300, 150, 0, 0, 0);
  assert.ok(b.arrowX >= b.x && b.arrowX <= b.x + b.w);
  assert.ok(Math.abs(b.arrowX - (t.x + t.w / 2)) <= b.w / 2 + 0.001);
});
