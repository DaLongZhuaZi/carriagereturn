// 回车 · 第 6 批静态断言（设置收敛/删除分派/搜索/回收站导航/引导）
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const read = (rel) => fs.readFileSync(path.join(root, rel), 'utf8');
const settings = read('entry/src/main/ets/components/SettingsPage.ets');
const index = read('entry/src/main/ets/pages/Index.ets');
const detail = read('entry/src/main/ets/components/DossierDetailPage.ets');
const trash = read('entry/src/main/ets/components/TrashPage.ets');
const docstore = read('entry/src/main/ets/services/DocStore.ets');

test('F6：设置页收敛到 SettingsRow，七行仍在，无僵尸 candidate props', () => {
  for (const key of ['settings_sound', 'settings_delete_mode', 'settings_default_machine',
    'settings_default_paper', 'settings_trash', 'settings_goal']) {
    assert.ok(settings.includes(key), `SettingsPage 缺 ${key}`);
  }
  const rowUses = (settings.match(/SettingsRow\(\{/g) || []).length;
  assert.ok(rowUses >= 9, `SettingsRow 使用数=${rowUses}`);
  assert.ok(!settings.includes('candidateCount'), '设置页仍有 candidate props');
  assert.ok(!index.includes('SettingsPage({') || !index.slice(index.indexOf('SettingsPage({'),
    index.indexOf('ExportPage({')).includes('candidateCount'), 'Index 仍向设置页传 candidate');
});

test('F6：启动读 PAPER/VOLUME 并灌 AudioService；默认机/纸选择即生效', () => {
  assert.ok(index.includes('PrefKeys.PAPER'));
  assert.ok(index.includes('paperPrefOf('));
  assert.ok(index.includes('this.audioService.setVolume('));
  assert.ok(index.includes('this.audioService.setSoundEnabled('));
  assert.ok(index.includes('this.audioService.setVibrationEnabled('));
  assert.ok(settings.includes('nextDeleteMode'));
});

test('F10：删除分派/回收站方法/trash 页导航五处', () => {
  assert.ok(index.includes('private deletePaper(id: string): void'));
  assert.ok(index.includes("deleteModeOf(this.deleteMode) === 'direct'"));
  assert.ok(index.includes('docStore.removePermanently(id)'));
  assert.ok(index.includes('docStore.remove(id)'));
  assert.ok(index.includes("this.trashOpen = has('trash')"));
  assert.ok(index.includes('GUIDE_PAGE_TRASH'));
  assert.ok(index.includes('guideStepsForTrash'));
  assert.ok(index.includes('guide_trash_title'));
  // 渲染顺序：TrashPage 在 SettingsPage 之后
  assert.ok(index.indexOf('TrashPage({') > index.indexOf('SettingsPage({'));
});

test('F10：搜索在卷宗内页，150ms 防抖 + limit 50 + 无结果态', () => {
  assert.ok(detail.includes('docStore.search(q,'));
  assert.ok(detail.includes('150'), '缺 150ms 防抖');
  assert.ok(detail.includes('limit: 50'));
  assert.ok(detail.includes('search_empty'));
  assert.ok(detail.includes('onRenamePaper'));
  assert.ok(detail.includes('deleteMode'));
});

test('F10：回收站页三列/恢复/彻底删/空态/保留期/引导/PageShell', () => {
  for (const k of ['trash_empty', 'trash_keep_days', 'trash_restore', 'trash_purge',
    'trash_unknown_dossier', 'guide_trash_hint']) {
    assert.ok(trash.includes(k), `TrashPage 缺 ${k}`);
  }
  assert.ok(trash.includes('PageShell('));
  assert.ok(trash.includes('expandSafeArea'));
  assert.ok(trash.includes('onPurge'));
  assert.ok(trash.includes('sort') === false, '回收站页不应运行时排序');
});

test('DocStore：removePermanently 与 list active-only', () => {
  assert.ok(docstore.includes('removePermanently(id: string): boolean'));
  const listStart = docstore.indexOf('list(): DocSummary[] {');
  const listBody = docstore.slice(listStart, docstore.indexOf('\n  }', listStart));
  assert.ok(listBody.includes('activeRecords('));
});