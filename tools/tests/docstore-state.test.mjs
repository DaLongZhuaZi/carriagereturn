// 回车 · DocStoreStateCore 纯逻辑单测（第 0 批）
// 运行：node --experimental-strip-types --test tools/tests/docstore-state.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const src = path.join(root, 'entry/src/main/ets/model/DocStoreStateCore.ets');
const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'docstate-'));
const tsPath = path.join(tmpDir, 'DocStoreStateCore.ts');
fs.copyFileSync(src, tsPath);
const mod = await import('file://' + tsPath.replace(/\\/g, '/'));

function record(id, title, updatedAt, extra = {}) {
  return { id, title, createdAt: 1, updatedAt, ...extra };
}

test('stateOf：旧文档缺字段＝active', () => {
  assert.equal(mod.stateOf(record('a', 'A', 10)), 'active');
  assert.equal(mod.isActive(record('a', 'A', 10)), true);
  assert.equal(mod.isTrashed(record('a', 'A', 10)), false);
});

test('trashRecord：入回收站、记时间与原因卷宗、从 active 消失', () => {
  const index = [record('a', 'A', 10, { dossierId: 'd1' }), record('b', 'B', 20)];
  assert.equal(mod.trashRecord(index, 'a', 123456), true);
  assert.equal(mod.isTrashed(index[0]), true);
  assert.equal(index[0].trashedAt, 123456);
  assert.equal(index[0].origDossierId, 'd1');
  assert.equal(index[0].dossierId, null);
  assert.equal(mod.activeRecords(index).length, 1);
  assert.equal(mod.trashedRecords(index).length, 1);
  // 重复 trash 返回 false
  assert.equal(mod.trashRecord(index, 'a', 999), false);
});

test('restoreRecord：回原卷宗、trashed 清空', () => {
  const index = [record('a', 'A', 10, { dossierId: 'd1' })];
  mod.trashRecord(index, 'a', 100);
  assert.equal(mod.restoreRecord(index, 'a'), true);
  assert.equal(mod.isActive(index[0]), true);
  assert.equal(index[0].dossierId, 'd1');
  assert.equal(index[0].trashedAt, undefined);
  // 已是 active，再 restore 返回 false
  assert.equal(mod.restoreRecord(index, 'a'), false);
});

test('renameRecord：trim 后改名；空标题不改', () => {
  const index = [record('a', '旧名', 10)];
  assert.equal(mod.renameRecord(index, 'a', '  新名  '), true);
  assert.equal(index[0].title, '新名');
  assert.equal(mod.renameRecord(index, 'a', '   '), false);
  assert.equal(mod.renameRecord(index, 'missing', 'x'), false);
});

test('searchRecords：标题优先、正文命中带摘要、active-only 默认', () => {
  const index = [
    record('a', '会议记录', 10),
    record('b', '随笔', 30),
    record('c', '回收站里的会议', 20),
  ];
  mod.trashRecord(index, 'c', 100);
  const content = {
    a: '今天开会\n讨论了回车项目',
    b: '今天会议讨论别的',
    c: '会议',
  };
  const hits = mod.searchRecords(index, '会议', {}, (id) => content[id] || '');
  assert.deepEqual(hits.map((h) => h.id), ['b', 'a']); // 按 updatedAt 倒序：b(30) 在 a(10) 前
  assert.equal(hits[0].matchedIn, 'content');
  assert.equal(hits[1].id, 'a');
  assert.equal(hits[1].matchedIn, 'title'); // '会议记录' 标题命中优先
  // 标题命中优先于正文
  const titleHits = mod.searchRecords(index, '随笔', {}, (id) => content[id] || '');
  assert.equal(titleHits[0].matchedIn, 'title');
  // includeTrashed 才出现 c
  const withTrash = mod.searchRecords(index, '会议', { includeTrashed: true }, (id) => content[id] || '');
  assert.equal(withTrash.length, 3);
});

test('searchRecords：空查询返回空、limit 生效', () => {
  const index = [record('a', 'x1', 1), record('b', 'x2', 2), record('c', 'x3', 3)];
  assert.deepEqual(mod.searchRecords(index, '   ', {}, () => ''), []);
  assert.equal(mod.searchRecords(index, 'x', { limit: 2 }, () => '').length, 2);
});