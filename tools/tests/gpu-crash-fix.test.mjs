// 回车 · 第 21 批（GPU 闪退修复）：预算算术＋结构守卫断言
// Phase 0 结论：成本 ∝ 每帧被 blit 的源位图，与目标 clip 无关；主修法 (b) 分层 + (c) transform。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const read = (rel) => fs.readFileSync(path.join(root, rel), 'utf8').replace(/\r\n/g, '\n');
const canvas = read('entry/src/main/ets/components/CanvasTypewriter.ets');

function bodyOf(src, signature) {
  const at = src.indexOf(signature);
  assert.ok(at >= 0, `找不到成员：${signature}`);
  const rest = src.slice(at + signature.length);
  const end = rest.search(/\n  (?:\/\*\*|@|\w|private|on\w|\/\*)/);
  return end < 0 ? rest : rest.slice(0, end);
}

test('预算算术：现状 10.7MB/draw 下 100 字必死，transform 路线只剩基线', () => {
  const drawPerChar = 11;            // 90ms 拱动画 @120Hz
  const drawsPerNewline = 84;
  const directExtra = 100;           // 无守卫直接 draw（现已被 Phase 2 守卫压掉）
  const chars = 100, newlines = 6;
  const total = chars * drawPerChar + newlines * drawsPerNewline + directExtra;
  assert.equal(total, 1704);
  const cap = 2157;                  // MB，18 号稿钉死的硬顶
  const perDraw = 10.7;
  assert.ok(total * perDraw > cap * 5, '现状预算应远超硬顶（算术自检）');
  // transform 路线：动画帧 draw=0 → 只剩基线
  assert.ok(chars * 1 * perDraw < cap, '每字只重画一次纸内容时远低于硬顶');
});

test('Phase 1 B1：前层已拆成 bail 条带 + bracket 小框，全屏透明前层不再存在', () => {
  assert.ok(!canvas.includes('machineFrontLayer'), '仍有全屏透明前层字段');
  assert.ok(canvas.includes('private bailLayer: ImageBitmap | null = null;'));
  assert.ok(canvas.includes('private bracketLayer: ImageBitmap | null = null;'));
  assert.ok(canvas.includes('ctxBail.drawImage(this.imgBail, 0, 0, this.paperWidthVp, bailH0);'),
    '压纸卷不是按 O=0 烘焙进独立条带');
  assert.ok(canvas.includes('ctx.drawImage(this.bailLayer, this.paperX() + this.visualO(), this.bailY);'),
    'bail 条带未带 live O 上屏');
  // 批 22 起：支架固定（用户定案「机器固定、只有纸走」之前的口径已改），bail 仍随纸走。
  assert.ok(canvas.includes('ctx.drawImage(this.bracketLayer, this.bracketX0, this.bracketY0);'),
    'bracket 未按固定位置上屏（批 22 起支架应固定、不带 renderO）');
});

test('Phase 1 B2：静态 Canvas 只画一次，字车 Canvas 不再每帧 blit 全屏背景', () => {
  assert.ok(canvas.includes('private ctxStatic: CanvasRenderingContext2D'),
    '缺下层静态 Canvas');
  assert.ok(canvas.includes('private drawStatic(): void'), '缺 drawStatic()');
  const d = bodyOf(canvas, 'private draw(): void');
  assert.ok(!d.includes('drawImage(this.backgroundLayer'), '字车 Canvas 仍在每帧 blit 全屏背景');
  assert.ok(bodyOf(canvas, 'private drawStatic(): void').includes('drawImage(this.backgroundLayer'),
    '静态 Canvas 未负责背景');
});

test('Phase 2 守卫：onPaperReset／onCandidatesChanged 只置脏，不再无守卫直接 draw', () => {
  const pr = bodyOf(canvas, 'onPaperReset(): void');
  assert.ok(pr.includes('if (!this.frameActive()) { this.draw(); }'), 'onPaperReset 无同源守卫');
  assert.ok(pr.includes('this.paperDirty = true;'), 'onPaperReset 未置脏');
  const cc = bodyOf(canvas, 'onCandidatesChanged(): void');
  assert.ok(cc.includes('if (!this.frameActive()) { this.draw(); }'), 'onCandidatesChanged 无同源守卫');
});

test('Phase 0 打点仍在：draw frame / frame tick / anim arrive（验收口径不退化）', () => {
  assert.ok(canvas.includes("'draw frame t=%{public}s ms=%{public}s tag=%{public}s'"));
  assert.ok(canvas.includes("'frame tick now=%{public}s interval=%{public}s'"));
  assert.ok(canvas.includes("'anim arrive arch t=%{public}s dt=%{public}s x=%{public}s'"));
});

