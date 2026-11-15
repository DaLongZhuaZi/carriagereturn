// 回车 · 第 17 批批 2（拨杆直驱：角度归 Canvas、逻辑归 Index）
// 静态接线断言 + 释放动画时序仿真。设备证据见 docs/自检记录.md（批 2 节）。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const read = (rel) => fs.readFileSync(path.join(root, rel), 'utf8').replace(/\r\n/g, '\n');
const canvas = read('entry/src/main/ets/components/CanvasTypewriter.ets');
const index = read('entry/src/main/ets/pages/Index.ets');

function bodyOf(src, signature) {
  const at = src.indexOf(signature);
  assert.ok(at >= 0, `找不到成员：${signature}`);
  const rest = src.slice(at + signature.length);
  const end = rest.search(/\n  (?:\/\*\*|@|\w|private|on\w|\/\*)/);
  return end < 0 ? rest : rest.slice(0, end);
}

test('角度归 Canvas：内部字段直驱、不再有 leverRatio @Prop', () => {
  assert.ok(canvas.includes('private renderLeverRatio: number = 0;'), '缺 Canvas 内部拨杆比例字段');
  assert.ok(!canvas.includes("leverRatio: number = 0"), 'Canvas 仍有 leverRatio @Prop');
  assert.ok(canvas.includes("import { restDegFor, swingDegFor, dragRatioFor } from '../model/LeverAngleCore';"),
    'Canvas 未复用 LeverAngleCore 纯函数');
  assert.ok(!index.includes('leverRatio: this.leverRatio(),'), 'Index 仍向 Canvas 传 leverRatio prop');
});

test('触摸 Move：只改字段、不直接 draw；onLeverUpdate 仍发给 Index', () => {
  const mv = canvas.slice(canvas.indexOf('if (e.type === TouchType.Move && this.leverActive)'),
    canvas.indexOf('if (e.type === TouchType.Up'));
  assert.ok(mv.includes('this.renderLeverRatio = dragRatioFor(dy, this.leverHDragVp);'),
    'Move 未用同一纯函数＋同一杆长算角');
  assert.ok(!mv.includes('this.draw()'), 'Move 里直接 draw（应与帧时钟并行、由下一帧画）');
  assert.ok(mv.includes('this.onLeverUpdate(dy)'), 'Move 未把 dy 转给 Index 做逻辑');
  // 按下从静止角起算
  assert.ok(bodyOf(canvas, 'private onCanvasTouch(').includes('this.renderLeverRatio = 0;'),
    '按下未把拨杆归零/静止');
});

test('逻辑归 Index：不写 @State、判定过半后发 commit＋tick，仍触发换行', () => {
  const up = bodyOf(index, 'private leverPanUpdate(dyRaw: number): void');
  assert.ok(up.includes('this.leverRatioLogical = dragRatioFor(dyRaw, this.leverHForDrag());'),
    'Index 未用同一纯函数算逻辑比例');
  assert.ok(up.includes('if (!this.canvasEnabled) { this.setLeverRatio(this.leverRatioLogical); }'),
    'canvas 开时 Index 仍回写角度 @State');
  const end = bodyOf(index, 'private leverPanEnd(): void');
  assert.ok(end.includes('this.canvasLeverReleaseCommit = commit;'), 'Index 未把过半判定交给 Canvas');
  assert.ok(end.includes('this.canvasLeverReleaseTick = this.canvasLeverReleaseTick + 1;'),
    'Index 未发释放 tick');
  assert.ok(end.includes('if (commit) {\n      this.onNewline();'), '过半未换行（C2 语义）');
  assert.ok(index.includes('leverHDragVp: this.leverHForDrag(),'), '未把两侧共用的杆长传下去');
});

test('释放编排：过半 200ms 摆到满摆→200ms 回程；不到半 150ms 回弹', () => {
  const r = bodyOf(canvas, 'private startLeverRelease(): void');
  assert.ok(r.includes('this.leverAnimTo = 1;') && r.includes('this.leverAnimDur = 200;'),
    '过半不是 200ms 摆到满摆');
  assert.ok(r.includes('this.leverAnimTo = 0;') && r.includes('this.leverAnimDur = 150;'),
    '不到半不是 150ms 回弹');
  assert.ok(canvas.includes('anim arrive lever phase='), '释放段缺到达打点');
  // 提交段结束后接回程段（否则拨杆停在满摆）
  assert.ok(canvas.includes('this.leverAnimPhase = 1;'), '提交结束后未接回程段');
});

test('释放动画时序仿真：200/200 与 150 各自 t0，落点精确（120Hz/60Hz 同时长）', () => {
  const easeOut = (p) => 1 - Math.pow(1 - p, 3);
  const frames = (step, dropEvery = 0) => {
    const out = [];
    for (let i = 0; i < 400; i++) {
      if (dropEvery > 0 && i > 0 && i % dropEvery === 0) continue;
      out.push(i * step);
    }
    return out;
  };
  const run = (fr, t0, dur, from, to) => {
    for (const now of fr) {
      const p = (now - t0) / dur;
      if (p >= 1) return { arrive: now, v: to };
      if (p > 0) { const v = from + (to - from) * easeOut(p); if (v < Math.min(from, to) - 1e-9) return { bad: v }; }
    }
    return { arrive: null };
  };
  for (const [step, tol] of [[8.3333, 8.34], [16.6667, 16.68]]) {
    const fr = frames(step);
    const c = run(fr, 0, 200, 0.4, 1);   // 提交：0.4 → 满摆
    assert.ok(c.arrive >= 200 - 0.01 && c.arrive < 200 + tol, `提交段时长不符 ${c.arrive}`);
    assert.equal(c.v, 1);
    const ret = run(fr, 400, 200, 1, 0); // 回程：满摆 → 静止
    assert.ok(ret.arrive >= 600 - 0.01 && ret.arrive < 600 + tol, `回程段到达不符 ${ret.arrive}`);
    const reb = run(fr, 0, 150, 0.2, 0);  // 回弹
    assert.ok(reb.arrive >= 150 - 0.01 && reb.arrive < 150 + tol, `回弹时长不符 ${reb.arrive}`);
    assert.equal(reb.v, 0);
  }
  // 掉帧不累计误差
  const dropped = run(frames(8.3333, 3), 0, 150, 0.2, 0);
  assert.ok(dropped.arrive >= 150 && dropped.arrive < 150 + 2 * 8.34, `掉帧场景回弹拖长 ${dropped.arrive}`);
});


