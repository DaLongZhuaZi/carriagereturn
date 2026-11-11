// 回车 · 引导键与页面引用静态断言（第 1 批）
// 运行：node --experimental-strip-types --test tools/tests/guide-keys.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'guidekeys-'));
const ts = path.join(tmp, 'GuideCore.ts');
fs.copyFileSync(path.join(root, 'entry/src/main/ets/model/GuideCore.ets'), ts);
const core = await import('file://' + ts.replace(/\\/g, '/'));

const strings = JSON.parse(fs.readFileSync(
  path.join(root, 'entry/src/main/resources/base/element/string.json'), 'utf8'));
const byName = new Map(strings.string.map((e) => [e.name, e.value]));

test('string.json：guide 资源键齐全且非空', () => {
  for (const key of core.allResourceKeys()) {
    assert.ok(byName.has(key), `缺资源键 ${key}`);
    assert.ok(String(byName.get(key)).length > 0, `空文案 ${key}`);
  }
});

test('13 个页面源码都有对应 guideSteps 导出且引用字面量资源键', () => {
  const pages = core.allPages();
  const files = {
    home: 'entry/src/main/ets/components/HomePage.ets',
    dossier: 'entry/src/main/ets/components/DossierPage.ets',
    dossier_detail: 'entry/src/main/ets/components/DossierDetailPage.ets',
    document_view: 'entry/src/main/ets/components/DocumentViewPage.ets',
    collection: 'entry/src/main/ets/components/CollectionPage.ets',
    collection_detail: 'entry/src/main/ets/components/CollectionDetailPage.ets',
    customize: 'entry/src/main/ets/components/CustomizePage.ets',
    settings: 'entry/src/main/ets/components/SettingsPage.ets',
    export: 'entry/src/main/ets/components/ExportPage.ets',
    pinyin_settings: 'entry/src/main/ets/components/PinyinSettingsPage.ets',
    font_manager: 'entry/src/main/ets/components/FontManagerPage.ets',
    paper_custom: 'entry/src/main/ets/components/PaperCustomPage.ets',
    trash: 'entry/src/main/ets/components/TrashPage.ets',
  };
  for (const p of pages) {
    if (p === 'typewriter') continue; // 打字机引导在 Index 内联（下方单独断言）
    const text = fs.readFileSync(path.join(root, files[p]), 'utf8');
    assert.ok(/export function guideStepsFor[A-Za-z]+\(\): SpotlightStep\[\]/.test(text), `${p} 缺 guideSteps 导出`);
    for (let i = 1; i <= core.stepsExpected(p); i++) {
      assert.ok(text.includes(`$r('app.string.${core.pageStepKey(p, i)}')`), `${p} 缺 ${i} 条`);
    }
  }
});

test('12 个 PageShell 页有常驻说明行 subtitle（打字机/首页除外）', () => {
  const shellPages = ['dossier', 'dossier_detail', 'document_view', 'collection',
    'collection_detail', 'customize', 'settings', 'export', 'pinyin_settings',
    'font_manager', 'paper_custom', 'trash'];
  const files = {
    dossier: 'DossierPage.ets', dossier_detail: 'DossierDetailPage.ets',
    document_view: 'DocumentViewPage.ets', collection: 'CollectionPage.ets',
    collection_detail: 'CollectionDetailPage.ets', customize: 'CustomizePage.ets',
    settings: 'SettingsPage.ets', export: 'ExportPage.ets', pinyin_settings: 'PinyinSettingsPage.ets',
    font_manager: 'FontManagerPage.ets', paper_custom: 'PaperCustomPage.ets',
    trash: 'TrashPage.ets',
  };
  for (const p of shellPages) {
    const text = fs.readFileSync(path.join(root, 'entry/src/main/ets/components', files[p]), 'utf8');
    assert.ok(text.includes(`subtitle: $r('app.string.${core.pageHintKey(p)}')`), `${p} 缺 subtitle`);
    assert.ok(text.includes('showSubtitle: true'), `${p} 缺 showSubtitle`);
  }
});

test('Index：typewriter 引导函数与启动引导 4 条键在 Index', () => {
  const index = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8');
  for (const key of core.onboardingKeys()) {
    assert.ok(index.includes(`$r('app.string.${key}')`), `Index 缺 ${key}`);
  }
  assert.ok(index.includes("$r('app.string.guide_typewriter_1')") ||
    index.includes('guideStepsForTypewriter'), 'Index 缺打字机引导');
});

test('anchorId 全仓唯一且每页按 §6 配对表挂到目标组件', () => {
  const pageFiles = {
    home: 'HomePage.ets', dossier: 'DossierPage.ets', dossier_detail: 'DossierDetailPage.ets',
    document_view: 'DocumentViewPage.ets', collection: 'CollectionPage.ets',
    collection_detail: 'CollectionDetailPage.ets', customize: 'CustomizePage.ets',
    settings: 'SettingsPage.ets', export: 'ExportPage.ets',
    pinyin_settings: 'PinyinSettingsPage.ets', font_manager: 'FontManagerPage.ets',
    paper_custom: 'PaperCustomPage.ets', trash: 'TrashPage.ets',
  };
  const seen = new Map();
  for (const [page, file] of Object.entries(pageFiles)) {
    const text = fs.readFileSync(path.join(root, 'entry/src/main/ets/components', file), 'utf8');
    const ids = [...text.matchAll(/anchorId: '([^']+)'/g)].map((m) => m[1]);
    assert.ok(ids.length >= 1, `${page} 缺 anchorId`);
    for (const id of ids) {
      assert.ok(!seen.has(id) || seen.get(id) === page, `anchorId 跨页重名 ${id}`);
      seen.set(id, page);
      // 明确已挂 .id() 的锚点必须真的挂上；其余按 §2.4 fallback，列 miss 清单（批报告 §4）
      const attached = new Set([
        'home__hero', 'home__start_btn', 'home__bottom_nav',
        'settings__sound_row', 'settings__defaults', 'settings__replay',
        'dossier__list', 'dossier__new_btn',
        'collection__grid',
        'trash__list', 'trash__hint',
        'dossier_detail__list', 'dossier_detail__new_btn',
        'collection_detail__intro',
        'customize__options',
        'export__formats',
        'pinyin__engine',
        'font_manager__list',
        'paper_custom__controls',
        'document_view__content', 'document_view__delete_btn',
        'typewriter__lever', 'typewriter__paper', 'typewriter__paper_change_btn',
        'collection_detail__progress', 'collection_detail__set_btn',
        'customize__machine', 'customize__manage_entry',
        'export__actions', 'export__share_btn',
        'pinyin__candidate', 'pinyin__userwords',
        'font_manager__import_btn',
        'paper_custom__texture_import', 'paper_custom__preset',
      ]);
      if (attached.has(id)) {
        assert.ok(text.includes(`.id('${id}')`), `${page} 的 ${id} 没有挂 .id()`);
      }
    }
  }
  // 打字机三条在 Index 内联
  const idx = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8');
  for (const id of ['typewriter__lever', 'typewriter__paper_change_btn', 'typewriter__paper']) {
    assert.ok(idx.includes(`anchorId: '${id}'`), `Index 缺 ${id}`);
  }
});
