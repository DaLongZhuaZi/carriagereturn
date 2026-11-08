// 回车 · F9 拨杆去门控静态断言（第 1 批）
// 运行：node --test tools/tests/lever-gate.test.mjs（无 TS 依赖，纯文本断言）
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const LEVERS = [
  'entry/src/main/ets/components/LeverLayer.ets',
  'entry/src/main/ets/machines/1930s/LeverLayer1930.ets',
  'entry/src/main/ets/machines/1950s/LeverLayer.ets',
  'entry/src/main/ets/machines/1960s/LeverLayer.ets',
];

function bodyOf(text, method) {
  const start = text.indexOf(method);
  assert.ok(start >= 0, `找不到 ${method}`);
  const brace = text.indexOf('{', start);
  let depth = 0;
  for (let i = brace; i < text.length; i++) {
    if (text[i] === '{') depth += 1;
    if (text[i] === '}') {
      depth -= 1;
      if (depth === 0) return text.slice(brace + 1, i);
    }
  }
  throw new Error('unbalanced');
}

test('四份 LeverLayer：onDragRatio 目标体（复位分支＋150ms＋early return＋angleFor）', () => {
  for (const rel of LEVERS) {
    const text = fs.readFileSync(path.join(root, rel), 'utf8');
    const body = bodyOf(text, 'onDragRatio(): void');
    assert.ok(!/if\s*\(this\.dragging\)/.test(body), `${rel} 仍有 dragging 门控`);
    assert.ok(/dragRatio\s*<=\s*0\.001/.test(body), `${rel} 缺复位分支`);
    assert.ok(/duration:\s*150/.test(body), `${rel} 复位分支缺 150ms`);
    assert.ok(/return;/.test(body), `${rel} 复位分支缺 early return`);
    assert.ok(/angleFor\(this\.restDeg,\s*this\.swingDeg,\s*this\.dragRatio\)/.test(body),
      `${rel} ratio 分支未走 angleFor`);
    // 顺序：复位分支必须在 angleFor 之前（避免 ratio=0 时先瞬时置角）
    const resetAt = body.indexOf('dragRatio <= 0.001');
    const angleAt = body.indexOf('angleFor(');
    assert.ok(resetAt >= 0 && angleAt > resetAt, `${rel} 分支顺序错误`);
  }
});

test('四份 LeverLayer：局部 PanGesture/onClick 已删除（Index 为唯一生产者）', () => {
  for (const rel of LEVERS) {
    const text = fs.readFileSync(path.join(root, rel), 'utf8');
    assert.ok(!/\.gesture\(/.test(text), `${rel} 仍有局部手势`);
    assert.ok(!/onLeverTap\(\);/.test(text), `${rel} 仍有局部 onLeverTap 调用`);
    assert.ok(!/this\.dragging\s*=/.test(text), `${rel} 仍有 dragging 赋值`);
  }
});

test('onTickChanged 跳过条件改为 dragRatio>0.001（不再依赖 dragging）', () => {
  for (const rel of LEVERS) {
    const text = fs.readFileSync(path.join(root, rel), 'utf8');
    const body = bodyOf(text, 'onTickChanged(): void');
    assert.ok(/this\.dragRatio\s*>\s*0\.001/.test(body), `${rel} 未改跳过条件`);
    assert.ok(!/this\.dragging/.test(body), `${rel} 仍引用 dragging`);
  }
});

test('Index 四个拨杆实例都传 dragRatio: this.leverRatio()', () => {
  const index = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8');
  const count = (index.match(/dragRatio:\s*this\.leverRatio\(\)/g) || []).length;
  assert.equal(count, 4, `期望 4 个 dragRatio 实例，实际 ${count}`);
});

test('死代码 machines/1920s/LeverLayer.ets 不存在，且不被引用', () => {
  assert.ok(!fs.existsSync(path.join(root, 'entry/src/main/ets/machines/1920s/LeverLayer.ets')));
  const hits = [];
  const walk = (dir) => {
    for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, ent.name);
      if (ent.isDirectory()) walk(full);
      else if (ent.name.endsWith('.ets')) {
        const t = fs.readFileSync(full, 'utf8');
        if (t.includes("machines/1920s/LeverLayer") || t.includes("./LeverLayer'")) hits.push(full);
      }
    }
  };
  walk(path.join(root, 'entry/src/main/ets/machines/1920s'));
  assert.equal(hits.length, 0, `仍有引用: ${hits.join(', ')}`);
});