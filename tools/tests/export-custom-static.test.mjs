// 第 13 批 ⑥：导出页自定义区/逐纸渲染/可见块接线（静态断言，配合 export-multipage 布局单测）
// 运行：node --experimental-strip-types --test tools/tests/export-custom-static.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const page = fs.readFileSync(path.join(root, 'entry/src/main/ets/components/ExportPage.ets'), 'utf8');
const tpl = fs.readFileSync(path.join(root, 'entry/src/main/ets/components/ExportTemplate.ets'), 'utf8');

test('ExportTemplate：5 个可见块都有条件渲染，外观三参都进样式', () => {
  for (const flag of ['visTitle', 'visMachine', 'visDate', 'visBody', 'visPageNo']) {
    assert.ok(tpl.includes(`if (this.${flag})`), `缺可见块条件: ${flag}`);
  }
  assert.ok(tpl.includes('this.paperBg'), '纸面底色应取 paperBg');
  assert.ok(tpl.includes('this.fontFamily'), '字体应取 fontFamily');
  assert.ok(tpl.includes('this.inkColor'), '墨色应取 inkColor');
  assert.ok(tpl.includes('this.dossierName'), '卷宗名应参与渲染');
});

test('ExportTemplate：正文优先用逐纸行、页码按 pageNo/pageTotal 渲染', () => {
  assert.ok(tpl.includes('this.sheetLines.length > 0'), '正文应优先用 sheetLines');
  assert.ok(tpl.includes('this.pageNo.toString() + \' / \' + this.pageTotal.toString()'),
    '页码应为 n / m');
});

test('ExportPage：逐纸渲染把计划页数据传给模板（sheetLines/pageNo/pageTotal/可见块/外观）', () => {
  const builderBlock = page.slice(page.indexOf('templateBuilder()'));
  for (const prop of ['sheetLines: this.pageLines', 'pageNo: this.pageNo',
    'pageTotal: this.pageTotal', 'paperBg: this.templatePaperBg()',
    'fontFamily: this.templateFont()', 'inkColor: this.templateInk()',
    'visTitle: this.optTitle', 'visMachine: this.optMachine', 'visDate: this.optDate',
    'visBody: this.optBody', 'visPageNo: this.optPageNo']) {
    assert.ok(builderBlock.includes(prop), `builder 缺 ${prop}`);
  }
});

test('ExportPage：PagePlan 逐页计划存在，且整卷宗逐篇逐纸、页码全局连续', () => {
  assert.ok(page.includes('interface PagePlan'), '缺 PagePlan');
  assert.ok(page.includes('private pagePlans(): PagePlan[]'), '缺 pagePlans()');
  assert.ok(page.includes('docStore.listByDossier(this.targetDossierId)'), '整卷宗应按卷宗取列表');
  assert.ok(page.includes('plans[i].pageNo = i + 1'), '页码应全局连续');
  assert.ok(page.includes('plans[i].pageTotal = total'), '总页数应逐页一致');
});

test('ExportPage：文件名可改并有兜底（自定义优先、空/非法回落 回车）', () => {
  assert.ok(page.includes('private fileNameFor(ext: string): string'), '缺 fileNameFor');
  assert.ok(page.includes("safeFileName(base.length > 0 ? base : '回车'"), '兜底应为 回车');
  assert.ok(page.includes("fileNameFor('pdf')"), 'PDF 路径应使用自定义文件名');
  assert.ok(page.includes('this.fileNameFor(fmt.ext)'), '保存对话框名应使用自定义文件名');
});

test('ExportPage：PNG 在非当前纸范围置灰（不可点+注记）', () => {
  assert.ok(page.includes("return id === 'image' && this.range !== 'paper';"), '缺 fmtDisabled 规则');
  assert.ok(page.includes('this.fmtDisabled(f.id)'), '格式行应依据 f.id 置灰');
  assert.ok(page.includes("$r('app.string.export_range_png_hint')"), '置灰时应显示多页提示');
});
