// 回车 · F5 成就判定纯函数单测（第 9 批）
// 运行：node --experimental-strip-types --test tools/tests/achievement.test.mjs
// 覆盖：每项成就「阈值-1 不达成 / 阈值达成」、多成就同时达成、折叠设备闸门、进度截断、重复调用幂等。
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'achcore-'));

// AchievementCore 依赖 AchievementDefs：两份都拷进同一临时目录，并把 import 补成 .ts（Node ESM 要显式扩展名）
fs.copyFileSync(path.join(root, 'entry/src/main/ets/model/AchievementDefs.ets'),
  path.join(tmp, 'AchievementDefs.ts'));
const coreSrc = fs.readFileSync(path.join(root, 'entry/src/main/ets/model/AchievementCore.ets'), 'utf8')
  .replaceAll("from './AchievementDefs'", "from './AchievementDefs.ts'");
fs.writeFileSync(path.join(tmp, 'AchievementCore.ts'), coreSrc);

const core = await import('file://' + path.join(tmp, 'AchievementCore.ts').replace(/\\/g, '/'));
const defs = await import('file://' + path.join(tmp, 'AchievementDefs.ts').replace(/\\/g, '/'));

/** 空白输入（全 0／false）。 */
function empty() {
  return {
    totalChars: 0, streakDays: 0, goalReached: false, shareCount: 0, paperKinds: 0,
    fontChanges: 0, ribbonChanges: 0, foldChars: 0, saves: 0, foldableDevice: true,
  };
}

/** 按 id 取阈值。 */
function thresholdOf(id) {
  const d = defs.ACHIEVEMENTS.find((x) => x.id === id);
  assert.ok(d, `成就表缺 ${id}`);
  return d.threshold;
}

/** 把某个数据源设到指定值。 */
function withMetric(metric, value) {
  const i = empty();
  if (metric === 'words') { i.totalChars = value; }
  else if (metric === 'streak') { i.streakDays = value; }
  else if (metric === 'goal') { i.goalReached = value >= 1; }
  else if (metric === 'share') { i.shareCount = value; }
  else if (metric === 'paper') { i.paperKinds = value; }
  else if (metric === 'font') { i.fontChanges = value; }
  else if (metric === 'ribbon') { i.ribbonChanges = value; }
  else if (metric === 'fold') { i.foldChars = value; }
  else if (metric === 'saved') { i.saves = value; }
  return i;
}

test('成就表：14 项、id 唯一、阈值全部正数、无一以机型为条件', () => {
  assert.equal(defs.ACHIEVEMENTS.length, 14, '成就表必须正好 14 项');
  const ids = defs.ACHIEVEMENTS.map((x) => x.id);
  assert.equal(new Set(ids).size, ids.length, 'id 不许重复');
  for (const d of defs.ACHIEVEMENTS) {
    assert.ok(d.threshold > 0, `${d.id} 阈值必须为正`);
    assert.ok(d.nameRes.startsWith('ach_name_'), `${d.id} 资源键前缀不对`);
    assert.ok(d.descRes.startsWith('ach_desc_'), `${d.id} 资源键前缀不对`);
    // 铁律：判定表里不许出现机型
    assert.ok(!String(d.metric).includes('machine'), `${d.id} 不许以机型为条件`);
  }
  const fold = defs.ACHIEVEMENTS.filter((x) => x.foldOnly);
  assert.equal(fold.length, 1, '只有 A13 是折叠设备专属');
  assert.equal(fold[0].id, 'fold_1');
});

test('每项成就：阈值-1 不达成，阈值达成（逐项边界）', () => {
  const cases = [
    ['words_1000', 'words'], ['words_5000', 'words'], ['words_20000', 'words'],
    ['streak_3', 'streak'], ['streak_7', 'streak'],
    ['goal_1', 'goal'],
    ['share_1', 'share'], ['share_10', 'share'],
    ['paper_2', 'paper'], ['paper_4', 'paper'],
    ['font_1', 'font'], ['ribbon_1', 'ribbon'],
    ['fold_1', 'fold'],
    ['docs_10', 'saved'],
  ];
  for (const [id, metric] of cases) {
    const t = thresholdOf(id);
    const under = core.evaluateAchieved(withMetric(metric, t - 1));
    assert.ok(!under.includes(id), `${id} 在 ${t - 1} 时不该达成`);
    const at = core.evaluateAchieved(withMetric(metric, t));
    assert.ok(at.includes(id), `${id} 在 ${t} 时必须达成`);
    const over = core.evaluateAchieved(withMetric(metric, t + 1));
    assert.ok(over.includes(id), `${id} 在 ${t + 1} 时仍达成`);
  }
});

test('多成就同时达成：一次判定返回全部命中的 id（顺序＝成就表顺序）', () => {
  const i = empty();
  i.totalChars = 20000;
  i.streakDays = 7;
  i.shareCount = 10;
  i.paperKinds = 4;
  i.fontChanges = 1;
  i.ribbonChanges = 1;
  i.saves = 10;
  i.goalReached = true;
  i.foldChars = 1;
  const got = core.evaluateAchieved(i);
  assert.equal(got.length, 14, '14 项全达成（含可折叠设备上的 A13）');
  const expected = defs.ACHIEVEMENTS.map((d) => d.id);
  assert.deepEqual(got, expected, '顺序必须与成就表一致');
  // 非折叠设备上同样的输入少 A13 一项
  i.foldableDevice = false;
  const got2 = core.evaluateAchieved(i);
  assert.equal(got2.length, 13);
  assert.ok(!got2.includes('fold_1'));
});

test('A13 折叠设备闸门：非折叠设备即使半开字数够也不达成', () => {
  const i = empty();
  i.foldChars = 5;
  i.foldableDevice = false;
  const got = core.evaluateAchieved(i);
  assert.ok(!got.includes('fold_1'), '非折叠设备不许达成 A13');
  assert.equal(core.achievementProgress(defs.ACHIEVEMENTS.find((d) => d.id === 'fold_1'), i), 0,
    '非折叠设备上 A13 进度显示 0（UI 另显示「仅折叠设备」）');
  i.foldableDevice = true;
  assert.ok(core.evaluateAchieved(i).includes('fold_1'), '折叠设备上半开 1 字即达成');
});

test('空白输入：一项都不达成', () => {
  assert.deepEqual(core.evaluateAchieved(empty()), []);
});

test('幂等：同一输入重复判定结果相同（判定本身不写状态）', () => {
  const i = empty();
  i.totalChars = 1000;
  const a = core.evaluateAchieved(i);
  const b = core.evaluateAchieved(i);
  assert.deepEqual(a, b);
  assert.deepEqual(a, ['words_1000']);
});

test('进度：0..1 截断，阈值处为 1，超阈值仍 1', () => {
  const streak3 = defs.ACHIEVEMENTS.find((d) => d.id === 'streak_3');
  assert.equal(core.achievementProgress(streak3, withMetric('streak', 0)), 0);
  assert.ok(Math.abs(core.achievementProgress(streak3, withMetric('streak', 1)) - 1 / 3) < 1e-9);
  assert.equal(core.achievementProgress(streak3, withMetric('streak', 3)), 1);
  assert.equal(core.achievementProgress(streak3, withMetric('streak', 9)), 1, '超阈值截到 1');
});

test('metricValue 映射与成就表数据源一致', () => {
  const i = empty();
  i.totalChars = 11; i.streakDays = 2; i.goalReached = true; i.shareCount = 3;
  i.paperKinds = 4; i.fontChanges = 5; i.ribbonChanges = 6; i.foldChars = 7; i.saves = 8;
  assert.equal(core.metricValue('words', i), 11);
  assert.equal(core.metricValue('streak', i), 2);
  assert.equal(core.metricValue('goal', i), 1);
  assert.equal(core.metricValue('share', i), 3);
  assert.equal(core.metricValue('paper', i), 4);
  assert.equal(core.metricValue('font', i), 5);
  assert.equal(core.metricValue('ribbon', i), 6);
  assert.equal(core.metricValue('fold', i), 7);
  assert.equal(core.metricValue('saved', i), 8);
});
