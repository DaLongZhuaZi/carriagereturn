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

test('11 个页面源码都有对应 guideSteps 导出且引用字面量资源键', () => {
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
    assert.ok(/export function guideStepsFor[A-Za-z]+\(\): GuideStep\[\]/.test(text), `${p} 缺 guideSteps 导出`);
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