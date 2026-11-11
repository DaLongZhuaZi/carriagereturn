// 回车 · AppIcon 映射不变单测（第 0 批 A10）
// 运行：node --experimental-strip-types --test tools/tests/app-icon.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const text = fs.readFileSync(path.join(root, 'entry/src/main/ets/components/AppIcon.ets'), 'utf8');

test('14 种 kind 全部登记（第 10 批新增 help）', () => {
  const kinds = [...text.matchAll(/static readonly [A-Z_]+: string = '([^']+)'/g)].map((m) => m[1]);
  assert.equal(kinds.length, 14);
  assert.deepEqual(kinds, [
    'back', 'chevron_up', 'plus', 'chevron', 'folder', 'menu', 'more',
    'check', 'settings', 'export', 'rename', 'delete', 'lock', 'help',
  ]);
});

test('iconResourceOf 对每个 kind 都有分支', () => {
  const kinds = [...text.matchAll(/static readonly [A-Z_]+: string = '([^']+)'/g)].map((m) => m[1]);
  for (const k of kinds) {
    assert.ok(text.includes(`kind === IconKind.${k.toUpperCase()}`) ||
      text.includes(`kind === IconKind.${k.toUpperCase().replace(/_/g, '_')}`),
      `缺少 iconResourceOf 分支: ${k}`);
  }
});

test('系统符号名未被改动（14 个映射）', () => {
  const symbols = [...text.matchAll(/\$r\('sys\.symbol\.([a-z0-9_]+)'\)/g)].map((m) => m[1]);
  const unique = [...new Set(symbols)];
  assert.deepEqual(unique.sort(), [
    'checkmark', 'chevron_left', 'chevron_right', 'chevron_up', 'dot_grid_2x2',
    'folder', 'gearshape', 'line_3_horizontal', 'lock', 'plus', 'share',
    'square_and_pencil', 'trash', 'questionmark_circle',
  ].sort());
});

test('未知 kind 回落 back（不抛）', () => {
  assert.ok(/return \$r\('sys\.symbol\.chevron_left'\);\s*\n}/.test(text));
});