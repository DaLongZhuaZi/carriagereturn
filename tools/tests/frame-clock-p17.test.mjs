// 回车 · 第 17 批批 1（帧时钟迁移收尾：换纸／退行纸段／初值同步／onDocChanged 去重）
// 两类证据：
//   ① 静态接线断言——直接读 ArkTS 源，证明「触发通道＝tick＋目标 prop」「目标先写后发 tick」
//      「一条纸段通道」「初值只读一次」「redrawPaper 不再上屏」这些结构事实；
//   ② 时序仿真——用与 ArkTS 里**同一组公式与同一组时长**跑帧序列（120Hz／60Hz／掉帧），
//      证明数值按时间算、落点精确、掉帧不累计误差、各段时长符合 16 号稿 §3.3／17 号稿 §2.6。
// 这不是设备证据；真机 hilog 仍须补（见 docs/自检记录.md 的不符点）。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const read = (rel) => fs.readFileSync(path.join(root, rel), 'utf8');
const canvas = read('entry/src/main/ets/components/CanvasTypewriter.ets');
const index = read('entry/src/main/ets/pages/Index.ets');

/** 取一个成员函数体（从 `signature` 起，到下一个 `\n  ` 顶格成员前）。 */
function bodyOf(src, signature) {
  const at = src.indexOf(signature);
  assert.ok(at >= 0, `找不到成员：${signature}`);
  const rest = src.slice(at + signature.length);
  const end = rest.search(/\n  (?:\/\*\*|@|\w|private|on\w|\/\*)/);
  return end < 0 ? rest : rest.slice(0, end);
}

// ---------------- ① 静态接线断言 ----------------

test('换纸：canvasPaperTick＋目标 prop 两侧齐备，且 Index 先写目标再递增 tick', () => {
  assert.ok(canvas.includes("@Prop @Watch('onPaperTickChanged') canvasPaperTick"), 'Canvas 缺纸段 tick prop');
  for (const p of ['canvasPaperMode', 'canvasPaperFromTopVp', 'canvasPaperFromBoxVp',
    'canvasPaperTopTargetVp', 'canvasPaperBoxTargetVp', 'canvasPaperDurMs']) {
    assert.ok(canvas.includes(`@Prop ${p}: number`), `Canvas 缺目标 prop ${p}`);
    assert.ok(index.includes(`${p}: this.${p},`), `Index 未传 ${p}`);
  }
  const pt = bodyOf(index, 'private paperTick(');
  const iTarget = pt.indexOf('this.canvasPaperTopTargetVp = top;');
  const iTick = pt.indexOf('this.canvasPaperTick = this.canvasPaperTick + 1;');
  assert.ok(iTarget >= 0 && iTick > iTarget, 'paperTick 必须先写目标再递增 tick（§2.4）');
  assert.ok(index.includes("this.paperTick(outTop, this.paperHeightVp, 300, 1, 0, 0, 'paper1')"),
    '换纸第 1 段未走纸段 tick');
  assert.ok(index.includes("this.paperTick(this.paperTopTargetVp, this.paperContainerTargetVp, 300, 2,"),
    '换纸第 2 段未走纸段 tick（mode 2 显式 from）');
  assert.ok(index.includes('this.carriageTopVp, 2, \'paper2\')') || index.includes("this.carriageTopVp, 2, 'paper2')"),
    '换纸第 2 段 from 不是滚筒处（纸应藏在滚筒里再长出来）');
});

test('退行：O 250ms 与纸 300ms 是两条独立通道（back 处理里不再碰纸字段）', () => {
  const b = bodyOf(canvas, 'private startBackO(): void');
  assert.ok(b.includes('this.oDur = 250;'), '退行 O 不是 250ms');
  assert.ok(!b.includes('paperFromTop'), '退行仍在 back 处理里自己起纸动画（纸段应只由纸段 tick 驱动）');
  assert.ok(b.includes("this.markFirstFrame('back')"));
  // 纸段由 Index 侧退行发：recalcPaperHeight 的 canvas 分支发 tick，退行传 kind='back'
  assert.ok(index.includes("this.recalcPaperHeight('back');"), '退行未把纸段交给 recalcPaperHeight(back)');
});

test('初值同步：一次性 prop＋aboutToAppear／切机／切纸各读一次', () => {
  for (const p of ['initialCarriageOffsetVp', 'initialArchXVp', 'initialPaperTopVp', 'initialPaperContainerVp']) {
    assert.ok(canvas.includes(`@Prop ${p}: number`), `Canvas 缺初值 prop ${p}`);
    assert.ok(index.includes(`${p}: this.`), `Index 未传 ${p}`);
  }
  assert.ok(canvas.includes('private applyInitialSync(): void'));
  assert.ok(bodyOf(canvas, 'aboutToAppear(): void').includes('this.applyInitialSync()'),
    'aboutToAppear 未走初值同步');
  assert.ok(bodyOf(canvas, 'onMachineKindChanged(): void').includes('this.applyInitialSync()'),
    '切机未重置内部渲染字段');
  assert.ok(bodyOf(canvas, 'onPaperKindChanged(): void').includes('this.applyInitialSync()'),
    '切纸未重置内部渲染字段');
});

test('onDocChanged 去重：只失效纸层、不上屏；空闲时才补一次 draw', () => {
  const d = bodyOf(canvas, 'onDocChanged(): void');
  assert.ok(d.includes('this.paperDirty = true;'), 'onDocChanged 未标脏');
  assert.ok(d.includes('if (!this.frameActive()) { this.draw(); }'), 'onDocChanged 未按帧时钟活动分流');
  assert.ok(!/this\.draw\(\);\s*\n\s*\}/.test(d) || d.includes('frameActive'),
    'onDocChanged 仍无条件 draw（未去重）');
  const r = bodyOf(canvas, 'private redrawPaper(): void');
  assert.ok(!r.includes('drawImage'), 'redrawPaper 仍在上屏画位图（应只标脏）');
  assert.ok(!r.includes('clearRect'), 'redrawPaper 仍在清屏（应只标脏）');
  assert.ok(r.includes('this.paperDirty = true;'));
  assert.ok(r.includes('if (!this.frameActive()) { this.draw(); }'), '空闲时未立即补 draw（文字会延迟）');
  assert.ok(bodyOf(canvas, 'private frameActive(): boolean').includes('this.paperActive'), 'frameActive 漏纸段');
  assert.ok(bodyOf(canvas, 'private frameActive(): boolean').includes('this.newlineOActive'), 'frameActive 漏换行 O');
  // 纸的位置只由纸段 tick 决定：onDocChanged 不许拿逻辑 prop 覆盖渲染值（防同一任务里抢跑一帧闪跳）
  assert.ok(!d.includes('this.renderPaperTop = this.paperTopVp'), 'onDocChanged 仍在同步逻辑 prop 到渲染值');
  // 无动画重算也要发一条 dur=0 的纸段 tick
  assert.ok(bodyOf(index, 'private recalcPaperHeight(').includes('this.paperTick(this.paperTopVp, this.paperContainerVp, 0, 0, 0, 0, kind)'),
    '无动画重算未发 dur=0 纸段 tick（纸位置失去唯一通道）');
});

test('换行纸段：目标在 150ms 边界由 Index 算好后发 tick（不在 tick 时读滞后 prop）', () => {
  assert.ok(index.includes("this.animatePaperHeight('newline');"), '换行未在 150ms 处发纸段 tick');
  const recalc = bodyOf(index, 'private recalcPaperHeight(');
  assert.ok(recalc.includes('this.paperTick(this.paperTopVp, this.paperContainerVp, 300, 0, 0, 0, kind)'),
    'recalcPaperHeight 的 Canvas 分支未发纸段 tick');
  assert.ok(recalc.includes('if (this.canvasEnabled)'), 'recalcPaperHeight 未按 canvasEnabled 分流（回滚分支丢失）');
  // 换行 O：t0+450ms 起 250ms，jolt 峰值 2vp
  const oStart = canvas.indexOf('if (this.newlineOActive) {');
  const oEnd = canvas.indexOf('if (this.oActive)', oStart);
  assert.ok(oStart > 0 && oEnd > oStart, '找不到换行 O 帧内块');
  const oframe = canvas.slice(oStart, oEnd);
  assert.ok(oframe.includes('>= 450') && oframe.includes('/ 250'), '换行 O 不是 450ms 后 250ms');
  assert.ok(oframe.includes('this.nlJoltActive = true;'), '换行复位 jolt 未起');
  assert.ok(canvas.includes('this.nlJolt = 2 * nt / 20;'), '换行复位 jolt 峰值不是 2vp');
  assert.ok(canvas.includes('this.strikeJolt = jt / 20;'), '打击 jolt 峰值不是 1vp');
  assert.ok(canvas.includes('const joltSum: number = this.joltYVp + this.strikeJolt + this.nlJolt;'),
    'drawTexts 未把三路 jolt 相加');
});

test('tick 启动推迟一帧：watch 只登记，onframe 读目标（防 @Prop 逐 prop 同步读到旧目标）', () => {
  const w = bodyOf(canvas, 'onPaperTickChanged(): void');
  assert.ok(w.includes('this.pendingPaper = true;'), 'paper watch 未只登记待启动');
  assert.ok(!w.includes('canvasPaperTopTargetVp'), 'paper watch 仍在 watch 里直接读目标（会读到旧值）');
  assert.ok(canvas.includes('if (this.pendingPaper) { this.pendingPaper = false; this.startPaperSegment(); }'),
    'onframe 未统一启动纸段');
  assert.ok(canvas.includes('if (this.pendingBack) { this.pendingBack = false; this.startBackO(); }'),
    'onframe 未统一启动退行 O');
  assert.ok(canvas.includes('if (this.pendingNewline) { this.pendingNewline = false; this.startNewlineO(); }'),
    'onframe 未统一启动换行 O');
  assert.ok(canvas.includes('if (this.pendingDelete) { this.pendingDelete = false; this.startDeleteO(); }'),
    'onframe 未统一启动删除 O');
  // 瞬时 tick 撞上在播纸段时不许拍回去
  assert.ok(bodyOf(canvas, 'private startPaperSegment(): void').includes('paper instant skipped (active)'),
    '缺「瞬时 tick 不打断在播纸段」守卫');
});

test('无残留死字段／死代码（纸段旧通道与「只建不启」的 32ms 字杆钟）', () => {
  for (const dead of ['paperDelay', 'paperFromContainer', 'paperToContainer', 'strikeAnimator', 'ensureStrikeAnimator', 'typebarAngleAnimator']) {
    assert.ok(!canvas.includes(dead), `仍有死字段 ${dead}`);
  }
  // 帧时钟配置定死（§2.2）
  assert.ok(canvas.includes('duration: 1000000, easing: \'linear\''), '帧时钟配置缺失');
  assert.ok(canvas.includes('iterations: -1'), '帧时钟不是常驻（iterations=-1）');
  // 打击不得回到 setTimeout 跳变
  assert.ok(!canvas.includes('setTimeout(() => this.onStrikeArrive'), '打击退回定时器跳变');
});

test('日志口径（§5.8）：trigger／anim start／anim arrive／frame tick 都能落进 hilog', () => {
  for (const kind of ['strike', 'delete', 'newline', 'paper', 'back']) {
    assert.ok(index.includes(`'trigger ${kind} t=`), `Index 缺 trigger ${kind} 打点`);
  }
  assert.ok(canvas.includes("'anim start paper t0="), 'Canvas 缺 anim start paper');
  assert.ok(canvas.includes("'anim arrive paper t="), 'Canvas 缺 anim arrive paper');
  assert.ok(canvas.includes("'anim arrive newline O t="), 'Canvas 缺换行 O 到达打点');
  assert.ok(canvas.includes("'anim arrive O t="), 'Canvas 缺 O 到达打点');
  assert.ok(canvas.includes("'frame tick now="), 'Canvas 缺帧间隔打点');
  assert.ok(canvas.includes("'first frame %{public}s t="), 'Canvas 缺启动延迟首帧打点');
});

// ---------------- ② 时序仿真（同一组公式／同一组时长） ----------------

const DUR = {
  strikeArch: 90, joltRise: 20, joltFall: 20, deleteSpring: 70,
  newlineODelay: 450, newlineODur: 250, newlinePaperDur: 300, newlinePaperDelay: 150,
  paperStage: 300, backODur: 250, backPaperDur: 300,
};

/** 与 ArkTS 里逐字相同的曲线（CanvasTypewriter onframe）。 */
const easeInOutQuad = (p) => (p < 0.5 ? 2 * p * p : 1 - Math.pow(-2 * p + 2, 2) / 2);
const springOut = (p) => 1 - Math.pow(1 - p, 3);
const linear = (p) => p;
const jolt1 = (t) => (t <= 20 ? t / 20 : t <= 40 ? 1 - (t - 20) / 20 : 0);
const jolt2 = (t) => (t <= 20 ? (2 * t) / 20 : t <= 40 ? 2 * (1 - (t - 20) / 20) : 0);

/** 帧序列（绝对 now，毫秒）。dropEvery>0 时每第 N+1 帧丢一帧，模拟掉帧。 */
function makeFrames(step, dropEvery = 0) {
  const out = [];
  for (let i = 0; i < 400; i++) {
    if (dropEvery > 0 && i > 0 && i % dropEvery === 0) { continue; }
    out.push(i * step);
  }
  return out;
}

/** 按 2.1 公式跑一段：返回样本、首次到达帧、是否精确落点。 */
function runSegment(frames, t0, durMs, from, to, ease) {
  const samples = [];
  let arriveAt = null;
  for (const now of frames) {
    const p = (now - t0) / durMs;
    if (p <= 0) { samples.push({ now, v: from }); continue; }
    if (p >= 1) { samples.push({ now, v: to }); arriveAt = now; break; }
    samples.push({ now, v: from + (to - from) * ease(p) });
  }
  return { samples, arriveAt, durMs };
}

test('60Hz／120Hz：同一动画时长与落点相同（打击拱 90ms、删除 70ms、O 30/250ms）', () => {
  const cases = [
    ['打击拱', DUR.strikeArch, easeInOutQuad, 0, 100],
    ['删除弹簧', DUR.deleteSpring, springOut, 0, 12.8],
    ['换行 O', DUR.newlineODur, linear, -64, 0],
    ['退行 O', DUR.backODur, linear, 0, -32],
    ['纸上滑', DUR.paperStage, easeInOutQuad, 206, 176],
  ];
  for (const [name, dur, ease, from, to] of cases) {
    const a = runSegment(makeFrames(8.3333), 0, dur, from, to, ease);
    const b = runSegment(makeFrames(16.6667), 0, dur, from, to, ease);
    assert.ok(a.arriveAt !== null && b.arriveAt !== null, `${name} 未到达`);
    assert.ok(a.arriveAt >= dur - 0.01, `${name} 120Hz 提前到达 ${a.arriveAt}`);
    assert.ok(b.arriveAt >= dur - 0.01, `${name} 60Hz 提前到达 ${b.arriveAt}`);
    assert.ok(a.arriveAt < dur + 8.34, `${name} 120Hz 到达超出一帧（${a.arriveAt}）`);
    assert.ok(b.arriveAt < dur + 16.68, `${name} 60Hz 到达超出一帧（${b.arriveAt}）`);
    assert.equal(a.samples.at(-1).v, to, `${name} 120Hz 未精确落点`);
    assert.equal(b.samples.at(-1).v, to, `${name} 60Hz 未精确落点`);
    // 单调朝目标推进（不回头）
    for (const s of [a, b]) {
      const dir = Math.sign(to - from);
      let prev = from;
      for (const { v } of s.samples) {
        assert.ok(dir >= 0 ? v >= prev - 1e-9 : v <= prev + 1e-9, `${name} 出现回跳`);
        prev = v;
      }
    }
  }
});

test('掉帧不累计误差：隔帧采样仍按时到达、落点不变', () => {
  const dur = DUR.strikeArch;
  const normal = runSegment(makeFrames(8.3333), 0, dur, 0, 100, easeInOutQuad);
  const dropped = runSegment(makeFrames(8.3333, 3), 0, dur, 0, 100, easeInOutQuad); // 每第 3 帧丢一帧
  assert.ok(dropped.arriveAt >= dur, `掉帧场景提前到达 ${dropped.arriveAt}`);
  assert.ok(dropped.arriveAt < dur + 2 * 8.34, `掉帧场景拖长超过两帧（${dropped.arriveAt}）`);
  assert.equal(dropped.samples.at(-1).v, 100, '掉帧场景落点不精确');
  assert.ok(dropped.samples.length < normal.samples.length, '掉帧场景帧数应更少（帧数是屏幕决定的，不是动画决定的）');
});

test('换行三段：150ms 后纸上滑 300ms；450ms 后 O 回位 250ms；jolt 峰值 2vp／40ms', () => {
  const fr = makeFrames(8.3333);
  const paper = runSegment(fr, DUR.newlinePaperDelay, DUR.newlinePaperDur, 206, 176, easeInOutQuad);
  assert.ok(paper.arriveAt >= DUR.newlinePaperDelay + DUR.newlinePaperDur - 0.01,
    `纸上滑未满 300ms 就到达（${paper.arriveAt}）`);
  const o = runSegment(fr, DUR.newlineODelay, DUR.newlineODur, -64, 0, linear);
  assert.ok(o.arriveAt >= DUR.newlineODelay + DUR.newlineODur - 0.01, `O 未满 250ms 就到达（${o.arriveAt}）`);
  assert.ok(o.arriveAt < DUR.newlineODelay + DUR.newlineODur + 8.34, `O 到达超出一帧（${o.arriveAt}）`);
  // jolt：0 起 40ms 内 ≥0，20ms 处为峰值 2vp，40ms 归零
  assert.equal(jolt2(0), 0);
  assert.equal(jolt2(20), 2);
  assert.equal(jolt2(40), 0);
  assert.ok(jolt2(10) > 0 && jolt2(30) > 0);
  assert.ok(jolt1(20) === 1 && jolt1(40) === 0, '打击 jolt 峰值不是 1vp／40ms 归零');
});

test('换纸两段 300＋300ms：第 1 段飞出、第 2 段从滚筒处长出', () => {
  const fr = makeFrames(8.3333);
  const s1 = runSegment(fr, 0, DUR.paperStage, 206, 206 - 373.5, easeInOutQuad); // 上卷一个纸高
  const s2 = runSegment(fr, DUR.paperStage, DUR.paperStage, 300, 206, easeInOutQuad); // 滚筒处 → 起打位
  assert.ok(s1.arriveAt >= 300 - 0.01 && s1.arriveAt < 300 + 8.34, `第 1 段时长不符（${s1.arriveAt}）`);
  assert.ok(s2.arriveAt >= 600 - 0.01 && s2.arriveAt < 600 + 8.34, `第 2 段到达不是 600ms（${s2.arriveAt}）`);
  assert.equal(s2.samples.at(-1).v, 206);
});

test('20 连打：只要 90ms 打击按帧到达，200ms armFallback 不会触发（时序余量解析）', () => {
  // armFallback 判据：landHead 会更新 lastArriveMs；armed 之后只要发生过 arrive，since 记 0 并重挂。
  // 因此只有当「连续 200ms 内没有任何 arrive」时才会 fallback。打击周期 90ms≪200ms → 不可能触发。
  const strikePeriod = DUR.strikeArch;
  let lastArrive = 0;
  let fallbackFires = 0;
  for (let i = 1; i <= 20; i++) {
    const arrive = i * strikePeriod + (i % 3) * 2; // 人为给 ±2ms 抖动，仍远小于 200ms
    assert.ok(arrive - lastArrive < 200, `第 ${i} 字间隔 ${arrive - lastArrive}ms 触到兜底阈值`);
    lastArrive = arrive;
    // armFallback 在 landHead 后立刻重挂；arrivedSince=true → since=0 → 不触发
  }
  assert.equal(fallbackFires, 0);
});
