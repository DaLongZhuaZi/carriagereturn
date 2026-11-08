// 回车 · F12 换纸静态断言（第 5 批：未复现，保留打点，挂起）
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const index = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8');

test('换纸三段时长（300/300/320）未被本批改动', () => {
  const start = index.indexOf('private onPaperChange(): void {');
  assert.ok(start > 0);
  const end = index.indexOf('private onNewline(): void {', start);
  const body = index.slice(start, end);
  assert.ok(body.includes('duration: 300'), '缺 step1 300ms');
  assert.equal((body.match(/duration: 300/g) || []).length, 2, 'step1/step2 各 300ms');
  assert.ok(body.includes('}, 300);'), '缺 step2 定时 300ms');
  assert.ok(body.includes('}, 320);'), '缺收尾 320ms');
});

test('打点开关保持编译期 false，不改换纸时序', () => {
  assert.ok(index.includes('const PAPER_CHANGE_TRACE: boolean = false;'));
  // pcTrace 仍是零成本 early return
  assert.ok(index.includes('if (!PAPER_CHANGE_TRACE)'));
});