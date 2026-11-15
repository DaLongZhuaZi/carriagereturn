// 回车 · 第 20 批：拱单驱动修复（双驱动 conformance 修复）＋帧率取证打点的静态断言
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

test('拱单驱动：canvas 开时 Index 不再 animateTo 拱（fromStrike 不发 tick、换行退行发 tick）', () => {
  const f = bodyOf(index, 'private animateArch(');
  assert.ok(f.includes('if (this.canvasEnabled) {'), 'animateArch 未按 canvasEnabled 分流');
  // canvas 分支里不许出现 animateTo
  const canvasBranch = f.slice(f.indexOf('if (this.canvasEnabled) {'), f.indexOf('const archStarted'));
  assert.ok(!canvasBranch.includes('animateTo'), 'canvas 开时 Index 仍在 animateTo 拱（双驱动未除');
  assert.ok(canvasBranch.includes('this.archXVp = target;'), 'canvas 开时未同步逻辑值');
  assert.ok(canvasBranch.includes('if (!fromStrike) {'), '未按 fromStrike 区分打击/其他');
  assert.ok(canvasBranch.includes('this.canvasArchTick = this.canvasArchTick + 1;'), '未发拱目标 tick');
  // canvas 关的分支仍保留 animateTo（回滚）
  assert.ok(f.includes('curve: Curve.FastOutSlowIn'), 'canvas 关的 animateTo 回滚路径被删了');
  // 打击落字那次必须走 fromStrike
  assert.ok(index.includes('this.animateArch(90, true);'), '落字后的 animateArch 未标 fromStrike');
});

test('Canvas 侧：archXVp prop／snap 已删，拱目标改为实时算（paperX+renderO+cursorXVp）', () => {
  assert.ok(!canvas.includes("onArchChanged"), 'Canvas 仍有 arch 的 @Watch（snap 源）');
  assert.ok(!canvas.includes("archXVp: number = 0"), 'Canvas 仍保留 archXVp @Prop');
  assert.ok(canvas.includes('const archTarget: number = this.paperX() + this.carriageOffsetVp + this.cursorXVp;'),
    '拱目标不是 paperX+renderO+cursorXVp（与 Index clampedStrikeXVp 同口径）');
  assert.ok(!canvas.includes('const ax: number = this.renderArchX >= 0 ? this.renderArchX\n      : (this.archXVp'),
    'drawArchLayer 仍读 archXVp');
});

test('拱追踪器：目标动了就重锚、ease-out 不过冲、按时长收敛', () => {
  const onframe = canvas.slice(canvas.indexOf('const archTarget: number'), canvas.indexOf('if (this.newlineOActive)'));
  assert.ok(onframe.includes('Math.abs(archTarget - this.archToX) > 0.4'), '目标变化未重锚');
  assert.ok(onframe.includes('const ae: number = 1 - Math.pow(1 - at, 3);'), '拱不是 ease-out（会过冲）');
  assert.ok(onframe.includes('this.archDur = this.archDurNext;'), '拱段时长未走 archDurNext');
  assert.ok(canvas.includes("this.drawKindTag = 'strike';"), '打击未把拱时长交下去');
  assert.ok(canvas.includes("this.archDurNext = 90;"), '打击段时长不是 90ms');
});

test('帧率取证打点：draw() 每次上屏都记 draw frame t/ms/tag', () => {
  const d = bodyOf(canvas, 'private draw(): void');
  assert.ok(d.includes("'draw frame t=%{public}s ms=%{public}s tag=%{public}s'"), 'draw() 缺帧打点');
  assert.ok(d.includes('this.drawKindTag'), 'draw() 打点缺动画标签');
  for (const tag of ['newline', 'back', 'paper', 'strike', 'lever']) {
    assert.ok(canvas.includes(`this.drawKindTag = '${tag}';`), `缺 ${tag} 标签`);
  }
});

test('追踪器仿真：单调收敛、不过冲、60/120Hz 同时长同落点', () => {
  const ease = (p) => 1 - Math.pow(1 - p, 3);
  function chase(frames, targets, durMs) {
    let x = targets(0);
    const out = [x];
    let seg = null;
    for (const now of frames) {
      const tgt = targets(now / 1000);
      if (seg === null) {
        if (Math.abs(tgt - x) > 0.2) seg = { from: x, to: tgt, t0: now, dur: durMs };
      }
      if (seg) {
        if (Math.abs(tgt - seg.to) > 0.4) seg = { from: x, to: tgt, t0: now, dur: seg.dur };
        const p = (now - seg.t0) / seg.dur;
        if (p >= 1) { x = seg.to; seg = null; } else { x = seg.from + (seg.to - seg.from) * ease(p); }
      }
      out.push(x);
    }
    return out;
  }
  // 目标逐级左移（快速连打：每 120ms 目标 −4vp），120Hz 与 60Hz 各跑一遍
  const tickTargets = (t) => 200 - 4 * Math.floor(t / 0.12);
  const a = chase(Array.from({ length: 200 }, (_, i) => i * 8.3333), tickTargets, 90);
  const b = chase(Array.from({ length: 100 }, (_, i) => i * 16.6667), tickTargets, 90);
  for (const s of [a, b]) {
    for (let i = 1; i < s.length; i++) {
      assert.ok(s[i] <= s[i - 1] + 0.05, `拱出现回拉：${s[i - 1]} → ${s[i]}`);
    }
    const lastT = (s.length - 1) * (s === a ? 8.3333 : 16.6667) / 1000;
    assert.ok(Math.abs(s[s.length - 1] - tickTargets(lastT)) < 1.5,
      '末端未收敛到目标：' + String(s[s.length - 1]) + ' vs ' + String(tickTargets(lastT)));
  }
  // 收敛性：目标不动时最终精确落到目标
  const steady = chase(Array.from({ length: 60 }, (_, i) => i * 8.3333), () => 150, 90);
  assert.equal(steady[steady.length - 1], 150);
});


