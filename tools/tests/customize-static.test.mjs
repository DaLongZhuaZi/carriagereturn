// 回车 · 第 2 批 F3 静态断言（源码级，不编译）
// 运行：node --experimental-strip-types --test tools/tests/customize-static.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const read = (rel) => fs.readFileSync(path.join(root, rel), 'utf8');

// GuideCore 纯函数：与 guide-core.test.mjs 同一加载方式（复制成 .ts）
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'customstatic-'));
const guideTs = path.join(tmp, 'GuideCore.ts');
fs.copyFileSync(path.join(root, 'entry/src/main/ets/model/GuideCore.ets'), guideTs);
const guide = await import('file://' + guideTs.replace(/\\/g, '/'));

const paperStage = read('entry/src/main/ets/components/PaperStage.ets');
const fontPage = read('entry/src/main/ets/components/FontManagerPage.ets');
const paperPage = read('entry/src/main/ets/components/PaperCustomPage.ets');
const customizePage = read('entry/src/main/ets/components/CustomizePage.ets');
const store = read('entry/src/main/ets/services/CustomizeStore.ets');
const prefs = read('entry/src/main/ets/services/AppPreferences.ets');
const fontBar = read('entry/src/main/ets/components/FontBar.ets');
const strings = JSON.parse(read('entry/src/main/resources/base/element/string.json'));
const byName = new Map(strings.string.map((e) => [e.name, e.value]));

test('PaperStage：新增 paperColor/texturePath（默认空串），分支顺序 纹理→纯色→原 JPG', () => {
  assert.match(paperStage, /@Prop paperColor: string = ''/);
  assert.match(paperStage, /@Prop texturePath: string = ''/);

  const textureAt = paperStage.indexOf('this.texturePath.length > 0');
  const colorAt = paperStage.indexOf('this.paperColor.length > 0');
  const rawAt = paperStage.indexOf("$rawfile('paper/paper-letter.jpg')");
  assert.ok(textureAt > 0, '缺导入纸纹分支');
  assert.ok(colorAt > 0, '缺纯色纸分支');
  assert.ok(rawAt > 0, '默认 JPG 分支必须保留');
  assert.ok(textureAt < colorAt && colorAt < rawAt, '分支顺序必须是 纹理 → 纯色 → 默认 JPG');
  // 纯色分支是 Column 背景色（不是 Image 盖不透明 JPG）
  assert.match(paperStage, /backgroundColor\(this\.paperColor\)/);
  assert.match(paperStage, /Image\('file:\/\/' \+ this\.texturePath\)/);
});

test('FontManagerPage：导入链与失败状态全在（pickFont→校验→copyToSandbox→registerFromFile）', () => {
  assert.match(fontPage, /FileHelper\.pickFont\(ctx\)/);
  assert.match(fontPage, /FileHelper\.statOf\(picked\.uri\)/);
  assert.match(fontPage, /FileHelper\.copyToSandbox\(ctx, picked\.uri, 'fonts'\)/);
  assert.match(fontPage, /FontService\.registerFromFile\(this\.getUIContext\(\), familyName, dest\)/);
  assert.match(fontPage, /validFamilyName\(picked\.name\)/);
  assert.match(fontPage, /'imp-' \+ Date\.now\(\)/);
  assert.match(fontPage, /fontListAdd\(/);
  assert.match(fontPage, /status: ok \? 'ok' : 'failed'/);
  assert.match(fontPage, /fileIo\.unlinkSync\(target\)/);
  assert.match(fontPage, /FONT_IMPORT_MAX_BYTES: number = 20 \* 1024 \* 1024/);
  assert.match(fontPage, /'\.ttf'/);
  assert.match(fontPage, /'\.otf'/);
  assert.match(fontPage, /getHostContext\(\)/);
  assert.match(fontPage, /common\.UIAbilityContext/);
  assert.match(fontPage, /export function guideStepsForFontManager\(\): GuideStep\[\]/);
  for (let i = 1; i <= 3; i++) {
    assert.ok(fontPage.includes(`$r('app.string.guide_font_manager_${i}')`), `缺引导条 ${i}`);
  }
});

test('PaperCustomPage：色板/横线/三滑杆/纸纹/预设 + PaperStage 小样预览', () => {
  assert.match(paperPage, /PaperStage\(\{/);
  assert.match(paperPage, /paperColor: this\.color/);
  assert.match(paperPage, /texturePath: this\.texture/);
  assert.match(paperPage, /PAPER_COLORS/);
  assert.match(paperPage, /clampMarginH\(this\.isTablet\(\), v\)/);
  assert.match(paperPage, /clampMarginT\(this\.isTablet\(\), v\)/);
  assert.match(paperPage, /clampMarginB\(this\.isTablet\(\), v\)/);
  assert.match(paperPage, /return this\.widthVp >= TABLET_MIN_WIDTH_VP/);
  assert.match(paperPage, /FileHelper\.pickImage\(ctx\)/);
  assert.match(paperPage, /FileHelper\.copyToSandbox\(ctx, picked\.uri, 'paper'\)/);
  assert.match(paperPage, /CustomizeStore\.savePreset\(/);
  assert.match(paperPage, /CustomizeStore\.deletePreset\(/);
  assert.match(paperPage, /SettingsRow\(\{/);
  assert.match(paperPage, /export function guideStepsForPaperCustom\(\): GuideStep\[\]/);
  for (let i = 1; i <= 3; i++) {
    assert.ok(paperPage.includes(`$r('app.string.guide_paper_custom_${i}')`), `缺引导条 ${i}`);
  }
  // 新页文案不硬编码中文：$r 之外的引号串不应含 CJK
  const latinCode = paperPage.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '');
  const cjkInCode = latinCode.match(/['"][^'"\n]*[\u4e00-\u9fff][^'"\n]*['"]/g) || [];
  assert.deepEqual(cjkInCode, [], `PaperCustomPage 代码里有硬编码中文：${cjkInCode.join(', ')}`);
});

test('CustomizePage：两个入口行 + 字号滑杆 + 每机字体（不破坏旧回调）', () => {
  assert.match(customizePage, /onOpenFontManager: \(\) => void/);
  assert.match(customizePage, /onOpenPaperCustom: \(\) => void/);
  assert.match(customizePage, /onFontSize: \(v: number\) => void/);
  assert.match(customizePage, /@Prop fontSize: number = 0/);
  assert.match(customizePage, /@Prop machineFonts: string\[\] = \[\]/);
  assert.match(customizePage, /SettingsRow\(\{/);
  assert.match(customizePage, /onRowClick: \(\): void => \{ this\.onOpenFontManager\(\); \}/);
  assert.match(customizePage, /onRowClick: \(\): void => \{ this\.onOpenPaperCustom\(\); \}/);
  assert.match(customizePage, /onSlide: \(v: number\): void => \{ this\.onFontSize\(v\); \}/);
  assert.match(customizePage, /this\.machineFamily\(index\)/);
  assert.match(customizePage, /export function guideStepsForCustomize/);
  // 旧回调与旧区块仍在
  assert.match(customizePage, /onPickMachine: \(k: string\) => void/);
  assert.match(customizePage, /onPickFont: \(f: string\) => void/);
  assert.match(customizePage, /sectionTitle\('机器'\)/);
});

test('CustomizeStore：只引用 PrefKeys，不裸写 prefs 字符串键、不碰 @kit', () => {
  assert.ok(store.includes('PrefKeys.'), '必须经 PrefKeys 生成键');
  assert.doesNotMatch(store, /['"]custom\.[a-z]/i, '不许裸写 custom.* 字符串键');
  assert.ok(!store.includes('@kit.ArkData'), 'Store 不许直接依赖 preferences');
  assert.ok(!store.includes('@kit.CoreFileKit'), 'Store 只做 prefs 读写');

  for (const m of ['fontFamily', 'setFontFamily', 'fontSize', 'setFontSize',
    'importedFonts', 'setImportedFonts', 'paper', 'presets', 'savePreset', 'deletePreset',
    'candidateCount', 'candidateSize', 'enabled']) {
    assert.match(store, new RegExp(`static ${m}\\(`), `缺方法 ${m}`);
  }
  // 每机字体／纸张键都经 builder
  assert.match(store, /PrefKeys\.customFont\(machine, FIELD_/);
  assert.match(store, /PrefKeys\.customPaperOf\(paperKind, FIELD_/);
  assert.match(store, /PrefKeys\.CUSTOM_FONT_IMPORTED/);
  assert.match(store, /PrefKeys\.CUSTOM_PAPER_PRESETS/);
  assert.match(store, /PrefKeys\.CUSTOM_ENABLED/);
  // 未设置回落 catalog 默认（默认像素不变的来源）
  assert.match(store, /mh > 0 \? mh : base\.marginH/);
  assert.match(store, /findPaper\(paperKind as PaperKind\)/);
});

test('AppPreferences：custom.enabled / custom.font.imported / custom.paper.presets 已登记', () => {
  for (const key of ["'custom.enabled'", "'custom.font.imported'", "'custom.paper.presets'"]) {
    assert.ok(prefs.includes(key), `缺键 ${key}`);
  }
  assert.match(prefs, /static customPaperOf\(paperKind: string, field: string\): string/);
  assert.match(prefs, /CUSTOM_ENABLED: string = 'custom\.enabled'/);
  assert.match(prefs, /CUSTOM_FONT_IMPORTED: string = 'custom\.font\.imported'/);
  assert.match(prefs, /CUSTOM_PAPER_PRESETS: string = 'custom\.paper\.presets'/);
  assert.match(prefs, /PrefKeys\.CUSTOM_ENABLED, PrefKeys\.CUSTOM_FONT_IMPORTED, PrefKeys\.CUSTOM_PAPER_PRESETS/,
    'isRegistered 必须收录三个新固定键');
  // 登记表条目
  assert.match(prefs, /key: PrefKeys\.CUSTOM_ENABLED/);
  assert.match(prefs, /key: PrefKeys\.CUSTOM_FONT_IMPORTED/);
  assert.match(prefs, /key: PrefKeys\.CUSTOM_PAPER_PRESETS/);
});

test('FontBar：currentFamilyName 非空时优先，空时走原逻辑', () => {
  assert.match(fontBar, /@Prop currentFamilyName: string = ''/);
  assert.match(fontBar, /this\.currentFamilyName\.length > 0 \? this\.currentFamilyName : this\.fontLabel/);
  assert.match(fontBar, /fontFamily\(this\.currentFamilyName\.length > 0 \? this\.currentFamilyName : this\.fontFamily\)/);
});

test('GuideCore：页面清单 14 个（含 font_manager / paper_custom / trash），新页 3 条', () => {
  const pages = guide.allPages();
  assert.equal(pages.length, 14);
  assert.ok(pages.includes('font_manager'));
  assert.ok(pages.includes('paper_custom'));
  assert.equal(guide.stepsExpected('font_manager'), 3);
  assert.equal(guide.stepsExpected('paper_custom'), 3);
  assert.equal(guide.pageStepKey('font_manager', 1), 'guide_font_manager_1');
  assert.equal(guide.pageHintKey('paper_custom'), 'guide_paper_custom_hint');
});

test('string.json：第 2 批新增文案键齐全且非空', () => {
  const required = [
    'guide_font_manager_title', 'guide_font_manager_1', 'guide_font_manager_2',
    'guide_font_manager_3', 'guide_font_manager_hint',
    'guide_paper_custom_title', 'guide_paper_custom_1', 'guide_paper_custom_2',
    'guide_paper_custom_3', 'guide_paper_custom_hint',
    'font_manager_title', 'font_import', 'font_delete', 'font_status_ok', 'font_status_failed',
    'font_error_type', 'font_error_size',
    'paper_custom_title', 'paper_color', 'paper_ruled', 'paper_margin_h', 'paper_margin_t',
    'paper_margin_b', 'paper_texture', 'paper_texture_import', 'paper_preset_save',
    'paper_preset_delete', 'custom_font_size',
  ];
  for (const key of required) {
    assert.ok(byName.has(key), `缺资源键 ${key}`);
    assert.ok(String(byName.get(key)).length > 0, `空文案 ${key}`);
  }
  // 无重复键名
  assert.equal(byName.size, strings.string.length);
});
