// 第 13 批 ①：keymap 逐帽几何字段校验（两副本一致 + 字段合法 + 圆/圆角自洽）
// 运行：node --experimental-strip-types --test tools/tests/keymap-geometry.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const MACHINES = ['1920s-upright', '1930s-portable', '1950s-streamlined', '1960s-electric'];
const read = (rel) => JSON.parse(fs.readFileSync(path.join(root, rel), 'utf8'));

for (const m of MACHINES) {
  test(`${m}: 两副本逐帽字段一致`, () => {
    const a = read(`entry/src/main/resources/rawfile/keymap/${m}-keymap.json`);
    const b = read(`assets/images/machines/${m}-keymap.json`);
    assert.deepEqual(a.rows, b.rows, 'rows 两副本必须逐帽一致');
    assert.deepEqual(a.space, b.space, 'space 两副本必须一致');
  });

  test(`${m}: 每帽 w/h/r/shape 合法且自洽`, () => {
    const d = read(`entry/src/main/resources/rawfile/keymap/${m}-keymap.json`);
    let n = 0;
    for (const row of d.rows) {
      for (const cap of row.caps) {
        n += 1;
        assert.ok(cap.shape === 'circle' || cap.shape === 'rounded-rect', `${m} ${cap.label} shape 非法`);
        assert.ok(cap.wRatio > 0 && cap.wRatio < 0.3, `${m} ${cap.label} wRatio 越界`);
        assert.ok(cap.hRatio > 0 && cap.hRatio < 0.3, `${m} ${cap.label} hRatio 越界`);
        assert.ok(cap.rRatio > 0 && cap.rRatio < 0.15, `${m} ${cap.label} rRatio 越界`);
        if (cap.shape === 'circle') {
          // 正圆：圆角 = 半径 = 宽/2
          assert.ok(Math.abs(cap.rRatio - cap.wRatio / 2) < 1e-3, `${m} ${cap.label} 圆形圆角应=宽/2`);
        }
      }
    }
    assert.ok(n >= 40, `${m} 帽数异常 ${n}`);
    assert.ok(d.space.rRatio > 0 && d.space.rRatio < 0.05, `${m} space.rRatio 越界`);
  });
}

test('老 keymap 缺失几何时可按回落跑（字段校验只对新增字段做可选断言）', () => {
  // 用一份最小 JSON 模拟老格式：无 wRatio/hRatio/rRatio/shape
  const legacy = {
    master_size: [2048, 2048],
    rows: [{ y: 100, caps: [{ x: 100, label: 'A' }] }],
    space: { x_min: 0, x_max: 100, y_min: 200, y_max: 300 },
    bands: { phone: { x0: 0, y0: 0, w: 2048, h: 975 }, fold: { x0: 0, y0: 0, w: 2048, h: 853 } },
    overlay: {},
  };
  const cap = legacy.rows[0].caps[0];
  assert.equal(cap.wRatio, undefined);
  assert.equal(legacy.space.rRatio, undefined);
});
