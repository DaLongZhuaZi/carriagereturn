// 回车 · GuideCore 纯函数单测（第 1 批）
// 运行：node --experimental-strip-types --test tools/tests/guide-core.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'guidecore-'));
const ts = path.join(tmp, 'GuideCore.ts');
fs.copyFileSync(path.join(root, 'entry/src/main/ets/model/GuideCore.ets'), ts);
const mod = await import('file://' + ts.replace(/\\/g, '/'));

test('14 个 page id 固定且合法', () => {
  const pages = mod.allPages();
  assert.equal(pages.length, 14);
  assert.deepEqual(pages, [
    'home', 'dossier', 'dossier_detail', 'document_view', 'collection',
    'collection_detail', 'customize', 'settings', 'export', 'pinyin_settings', 'typewriter',
    'font_manager', 'paper_custom', 'trash',
  ]);
  for (const p of pages) assert.equal(mod.isValidPage(p), true);
  assert.equal(mod.isValidPage('unknown'), false);
});

test('每页 2–4 条：本批固定 3 条', () => {
  for (const p of mod.allPages()) {
    const n = mod.stepsExpected(p);
    assert.ok(n >= 2 && n <= 4, `${p} count=${n}`);
    assert.equal(n, 3);
  }
});

test('资源键命名规则', () => {
  assert.equal(mod.pageStepKey('home', 1), 'guide_home_1');
  assert.equal(mod.pageHintKey('home'), 'guide_home_hint');
  assert.equal(mod.pageTitleKey('home'), 'guide_home_title');
  assert.deepEqual(mod.onboardingKeys(), [
    'guide_onboarding_1', 'guide_onboarding_2', 'guide_onboarding_3', 'guide_onboarding_4',
  ]);
});

test('allResourceKeys 覆盖 14 页×3＋13 hint＋14 title＋4+1＋2 且无重复', () => {
  const keys = mod.allResourceKeys();
  assert.equal(new Set(keys).size, keys.length);
  assert.equal(keys.length, 14 * 3 + 13 + 14 + 4 + 1 + 2);
});