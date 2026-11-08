// 回车 · 资源键完整性（静态：所有 $r('app.string.*') 必须在 base string.json 存在）
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const RES = path.join(root, 'entry/src/main/resources/base/element/string.json');
const ETS = path.join(root, 'entry/src/main/ets');

test('所有 $r(app.string.*) 键都在 base string.json 中', () => {
  const names = new Set(JSON.parse(fs.readFileSync(RES, 'utf8')).string.map((x) => x.name));
  const missing = new Map();
  const walk = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) { walk(full); continue; }
      if (!entry.name.endsWith('.ets')) { continue; }
      const text = fs.readFileSync(full, 'utf8');
      for (const m of text.matchAll(/\$r\('app\.string\.([A-Za-z0-9_]+)'\)/g)) {
        if (!names.has(m[1])) {
          if (!missing.has(m[1])) { missing.set(m[1], []); }
          missing.get(m[1]).push(path.relative(root, full));
        }
      }
    }
  };
  walk(ETS);
  assert.equal(missing.size, 0, `缺键：${[...missing.keys()].join(', ')}`);
});