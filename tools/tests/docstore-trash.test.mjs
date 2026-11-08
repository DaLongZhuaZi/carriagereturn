// 回车 · 第 6 批 DocStore 回收站纯逻辑 + 静态断言
// 运行：node --experimental-strip-types --test tools/tests/docstore-trash.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'trashcore-'));
const ts = path.join(tmp, 'DocStoreStateCore.ts');
fs.copyFileSync(path.join(root, 'entry/src/main/ets/model/DocStoreStateCore.ets'), ts);
const mod = await import('file://' + ts.replace(/\\/g, '/'));

const DAY = 86400000;
function rec(id, updatedAt, extra = {}) {
  return { id, title: id, createdAt: 1, updatedAt, ...extra };
}

test('expiredRecords：30 天边界（trashedAt 恰好 30 天不删）', () => {
  const now = 100 * DAY;
  const index = [
    rec('old', now - 40 * DAY, { state: 'trashed', trashedAt: now - 31 * DAY }),
    rec('edge', now - 40 * DAY, { state: 'trashed', trashedAt: now - 30 * DAY }),
    rec('fresh', now - 1 * DAY, { state: 'trashed', trashedAt: now - 1 * DAY }),
    rec('active', now - 40 * DAY),
  ];
  const out = mod.expiredRecords(index, now, 30);
  assert.deepEqual(out, ['old']);
});

test('expiredRecords：trashedAt 缺失按 updatedAt 兜底', () => {
  const now = 100 * DAY;
  const index = [
    rec('old', now - 31 * DAY, { state: 'trashed' }),
    rec('recent', now - 2 * DAY, { state: 'trashed' }),
  ];
  assert.deepEqual(mod.expiredRecords(index, now, 30), ['old']);
});

test('trash→restore→active 仍保持原卷宗', () => {
  const index = [rec('a', 10, { dossierId: 'd1' })];
  assert.equal(mod.trashRecord(index, 'a', 100), true);
  assert.deepEqual(mod.activeRecords(index), []);
  assert.equal(mod.restoreRecord(index, 'a'), true);
  assert.equal(index[0].dossierId, 'd1');
  assert.equal(mod.activeRecords(index).length, 1);
});

test('DocStore/Index 静态：remove 走 trash、list 走 active、housekeeping 用永久删、purge 用永久删', () => {
  const store = fs.readFileSync(path.join(root, 'entry/src/main/ets/services/DocStore.ets'), 'utf8');
  const removeBody = store.slice(store.indexOf('remove(id: string): boolean {'),
    store.indexOf('removePermanently(id: string): boolean {'));
  assert.ok(removeBody.includes('this.trash('), 'remove 未走 trash');
  assert.ok(!removeBody.includes('unlinkIfPresent'), 'remove 仍硬删');
  const listStart = store.indexOf('list(): DocSummary[] {');
  const listBody = store.slice(listStart, store.indexOf('\n  }', listStart));
  assert.ok(listBody.includes('activeRecords('), 'list 未过滤 active');
  assert.ok(store.includes('removePermanently(expired[i])'), 'housekeeping 未永久删');
  const index = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8');
  const dd = index.slice(index.indexOf('private deleteDossier('), index.indexOf('private listDocs('));
  assert.ok(dd.includes('docStore.removePermanently(all[i].id)'), 'deleteDossier purge 未永久删');
});

test('check-contracts 已同步 remove 翻转断言', () => {
  const cc = fs.readFileSync(path.join(root, 'tools/check-contracts.py'), 'utf8');
  assert.ok(cc.includes('trashRecord'), '契约检查未改 remove 断言');
  assert.ok(!cc.includes('第 0 批要求仍硬删'), '契约检查仍要求硬删');
});