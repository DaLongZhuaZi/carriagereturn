// 回车 · F12 换纸静态断言（第 5 批立项；第 9 批 F12 打点默认开启后按新事实更新）
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const index = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8');

test('换纸三段时长（300/300/320）未被改动', () => {
  const start = index.indexOf("private onPaperChange(entry: string = 'manual'): void {");
  assert.ok(start > 0);
  const end = index.indexOf('private onNewline(): void {', start);
  const body = index.slice(start, end);
  assert.ok(body.includes('duration: 300'), '缺 step1 300ms');
  assert.equal((body.match(/duration: 300/g) || []).length, 2, 'step1/step2 各 300ms');
  assert.ok(body.includes('}, 300);'), '缺 step2 定时 300ms');
  assert.ok(body.includes('}, 320);'), '缺收尾 320ms');
});

test('打点开关第 9 批起默认 true；pcTrace 仍保留开关早退（可改回 false 零成本关闭）', () => {
  assert.ok(index.includes('const PAPER_CHANGE_TRACE: boolean = true;'));
  assert.ok(index.includes('if (!PAPER_CHANGE_TRACE)'));
});

test('第 9 批 F12 新增打点齐全：step1-settled / step2-work / resume / entry+lines', () => {
  assert.ok(index.includes("pcTrace('step1-settled'"), '缺 step1-settled');
  assert.ok(index.includes("pcTrace('step2-work'"), '缺 step2-work');
  assert.ok(index.includes("pcTrace('resume'"), '缺 resume');
  assert.ok(index.includes("'trace=on entry=' + entry"), 'start 缺 entry 字段');
  assert.ok(index.includes("' lines=' + this.docModel.getLines().length.toString()"), 'start 缺 lines 字段');
  assert.ok(index.includes('pcDelFlushActive'), '缺 delete-flush 排除标记');
});