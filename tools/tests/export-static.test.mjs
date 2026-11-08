// 回车 · 第 3 批 F4/F16 静态断言（源码级，不编译）
// 运行：node --experimental-strip-types --test tools/tests/export-static.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const read = (rel) => fs.readFileSync(path.join(root, rel), 'utf8');

const service = read('entry/src/main/ets/services/ExportService.ets');
const page = read('entry/src/main/ets/components/ExportPage.ets');
const template = read('entry/src/main/ets/components/ExportTemplate.ets');
const helper = read('entry/src/main/ets/services/FileHelper.ets');
const strings = JSON.parse(read('entry/src/main/resources/base/element/string.json'));
const byName = new Map(strings.string.map((e) => [e.name, e.value]));

/** 截取一个方法体（从 marker 到下一个 marker 之前）。 */
function between(src, from, to) {
  const a = src.indexOf(from);
  assert.ok(a >= 0, `找不到起点 ${from}`);
  const b = src.indexOf(to, a + from.length);
  assert.ok(b > a, `找不到终点 ${to}`);
  return src.slice(a, b);
}

test('ExportService：四个 build 方法齐全，且不碰 picker/分享', () => {
  assert.match(service, /static buildTxt\(docId: string\): ExportResult/);
  assert.match(service, /static buildPdf\(docId: string, machineLabel: string, title: string, dateText: string,\s*\n?\s*outPath: string\): ExportResult/);
  assert.match(service, /static async buildPngFromPreview\(ui: UIContext, nodeId: string\): Promise<ExportResult>/);
  assert.match(service, /static async buildPngTemplate\(ui: UIContext, docId: string, machineKind: string,/);
  // 字节服务不许越界做 picker / 分享
  assert.ok(!/picker/.test(service), 'ExportService 不许 import/使用 picker');
  assert.ok(!/import .*ShareService|import .*systemShare/.test(service), 'ExportService 不许 import 分享入口');
  assert.ok(!/ShareService\.shareFile/.test(service), 'ExportService 不许调用分享');
  // F16 离屏渲染按 SDK 形态调用：createFromBuilder(builder, 320, true)
  assert.match(service, /createFromBuilder\(builder, 320, true\)/);
  // 失败统一 {ok:false}
  assert.match(service, /ok: false, bytes: null, error:/);
});

test('ExportPage：调 ExportService / FileHelper.saveBytes / ShareService', () => {
  assert.match(page, /ExportService\.buildTxt\(/);
  assert.match(page, /ExportService\.buildPdf\(/);
  assert.match(page, /ExportService\.buildPngTemplate\(/);
  assert.match(page, /ExportService\.buildPngFromPreview\(ui, 'export_preview'\)/);
  assert.match(page, /FileHelper\.saveBytes\(ctx, name, fmt\.ext, data\)/);
  assert.match(page, /ShareService\.shareFile\(ctx, path, fmt\.utd\)/);
});

test('ExportPage：不许自己生成 PDF（无 inline pdfService）', () => {
  assert.ok(!/new pdfService\.PdfDocument/.test(page), 'ExportPage 里不许 new pdfService.PdfDocument');
  assert.ok(!/pdfService/.test(page), 'ExportPage 不许 import PDFKit');
  assert.ok(!/systemShare/.test(page), 'ExportPage 不许直接 import ShareKit');
});

test('ExportPage：保存与分享前都先调 onBeforeExport', () => {
  const saveBlock = between(page, 'private async runSave', 'private async runShare');
  const shareBlock = between(page, 'private async runShare', 'private async buildFor');
  for (const [name, block] of [['runSave', saveBlock], ['runShare', shareBlock]]) {
    const guard = block.indexOf('this.onBeforeExport()');
    const build = block.indexOf('await this.buildFor(');
    assert.ok(guard >= 0, `${name} 缺 onBeforeExport`);
    assert.ok(build > guard, `${name}：onBeforeExport 必须在 buildFor 之前`);
    assert.match(block, /this\.phase = PHASE_EMPTY/, `${name} 空文档要进 empty 态`);
  }
});

test('ExportPage：状态机/进度/结果/清理都在', () => {
  for (const p of ['idle', 'building', 'saving', 'sharing', 'result', 'error', 'empty']) {
    assert.ok(page.includes(`PHASE_${p.toUpperCase()}: string = '${p}'`), `缺 phase ${p}`);
  }
  assert.match(page, /EXPORT_PROGRESS_MIN_MS/);
  assert.match(page, /Date\.now\(\) - this\.opStartMs/, '进度必须用 Date.now() 差判定 300ms');
  assert.match(page, /Promise<BuildOutcome>/);
  assert.match(page, /resultText\(true, false\)/);
  assert.match(page, /resultText\(false, true\)/);
  // 结果态常驻不淡出：只由成功分支设置，且不许挂自动消失定时器
  assert.match(page, /this\.phase = PHASE_RESULT/);
  assert.ok(!/PHASE_RESULT[\s\S]{0,200}setTimeout/.test(page), '结果态不许挂自动消失定时器');
  // 分享临时目录 + 离页清理
  assert.match(page, /EXPORT_TMP_DIR/);
  assert.match(page, /aboutToDisappear\(\): void/);
  assert.match(page, /fs\.unlinkSync\(p\)/);
  // busy 拦返回
  assert.match(page, /private handleBack\(\): void \{[\s\S]*?if \(this\.isBusy\(\)\)[\s\S]*?return;/);
  // 文本/分享状态都在页内（不用 HintBar）
  assert.ok(!/HintBar/.test(page), 'ExportPage 不许使用 HintBar');
});

test('ExportPage：文案全走资源键，值里没有“已分享成功”', () => {
  for (const name of [
    'export_save', 'export_share', 'export_building', 'export_saving', 'export_sharing',
    'export_result_saved', 'export_result_shared', 'export_result_saved_shared',
    'export_save_failed', 'export_share_failed', 'export_empty', 'export_template_fallback',
  ]) {
    assert.ok(byName.has(name), `string.json 缺 ${name}`);
  }
  for (const [name, value] of byName) {
    assert.ok(!value.includes('已分享成功'), `${name} 出现了禁用词「已分享成功」`);
  }
  assert.equal(byName.get('export_result_shared'), '已调起分享');
  assert.equal(byName.get('export_result_saved_shared'), '已保存，已调起分享');
  assert.equal(byName.get('export_save'), '保存到本地');
  assert.equal(byName.get('export_empty'), '这张纸还没有字');
  assert.equal(byName.get('export_template_fallback'), '模板导出失败，已用基础图');
  // 页内不再硬编码中文格式名
  assert.match(page, /\$r\('app\.string\.export_fmt_image'\)/);
  assert.match(page, /\$r\('app\.string\.export_fmt_pdf'\)/);
  assert.match(page, /\$r\('app\.string\.export_fmt_text'\)/);
  assert.ok(!page.includes("'图片'"), 'ExportPage 不许再硬编码「图片」');
  assert.ok(!page.includes("'纯文本'"), 'ExportPage 不许再硬编码「纯文本」');
});

test('guide_export_2 值：可以只保存到本地，也可以直接分享', () => {
  assert.equal(byName.get('guide_export_2'), '可以只保存到本地，也可以直接分享');
  assert.equal(byName.get('guide_export_3'), '分享只会调起系统面板，不保证对方已收到。');
  assert.equal(byName.get('guide_export_hint'), '导出不加水印。');
});

test('ExportTemplate：1080×1440 画布 + 机器框图 + 前 12 行正文 + id', () => {
  assert.ok(template.includes('1080'), 'ExportTemplate 缺 1080');
  assert.ok(template.includes('1440'), 'ExportTemplate 缺 1440');
  assert.match(template, /EXPORT_TEMPLATE_W/);
  assert.match(template, /EXPORT_TEMPLATE_H/);
  assert.match(template, /\$rawfile\('machine\/' \+ this\.machineKind \+ '-side\.jpg'\)/);
  assert.match(template, /EXPORT_BODY_LINES/);
  assert.match(template, /docStore\.load\(this\.docId\)/);
  assert.match(template, /\.id\('export_template'\)/);
  assert.match(template, /templateLayout\(\)/);
  assert.ok(!/@kit\./.test(template), 'ExportTemplate 不 import @kit');
});

test('FileHelper.saveBytes：返回 SaveResult（ok/cancel/error），按后缀给 fileSuffixChoices', () => {
  assert.match(helper, /static async saveBytes\(ctx: common\.UIAbilityContext, suggestedName: string, ext: string,\s*\n?\s*data: ArrayBuffer \| string\): Promise<SaveResult>/);
  assert.match(helper, /options\.newFileNames = \[suggestedName\]/);
  assert.match(helper, /options\.fileSuffixChoices = \[ext\.toUpperCase\(\) \+ '\|\.' \+ ext\]/);
  assert.match(helper, /status: 'ok'/);
  assert.match(helper, /status: 'cancel'/);
  assert.match(helper, /status: 'error'/);
  assert.match(helper, /import \{ SaveResult \} from '\.\.\/model\/ExportCore'/);
});

test('ExportCore 是唯一文案键来源：resultText 只出白名单键', () => {
  const core = read('entry/src/main/ets/model/ExportCore.ets');
  const keys = [...core.matchAll(/'(export_result_[a-z_]+)'/g)].map((m) => m[1]);
  assert.deepEqual(new Set(keys), new Set([
    'export_result_saved', 'export_result_shared', 'export_result_saved_shared',
  ]));
  const quoted = [...core.matchAll(/'([^']*)'/g)].map((m) => m[1]);
  assert.ok(!quoted.some((v) => v.includes('已分享成功')), 'ExportCore 的字符串字面量里出现禁用词');
});