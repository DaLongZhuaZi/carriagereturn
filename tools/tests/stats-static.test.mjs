// 回车 · 第 4 批静态断言（G1／G2／G3 的静态证据）
// 运行：node --experimental-strip-types --test tools/tests/stats-static.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(path.dirname(here));
const read = (rel) => fs.readFileSync(path.join(root, rel), 'utf8');

const HOME = 'entry/src/main/ets/components/HomePage.ets';
const SETTINGS = 'entry/src/main/ets/components/SettingsPage.ets';
const ROW = 'entry/src/main/ets/components/SettingsRow.ets';
const COLLECTION = 'entry/src/main/ets/components/CollectionPage.ets';
const DETAIL = 'entry/src/main/ets/components/CollectionDetailPage.ets';
const STATS_SERVICE = 'entry/src/main/ets/services/StatsService.ets';
const STRINGS = 'entry/src/main/resources/base/element/string.json';

test('HomePage：统计只剩单一派生层（无第二处求和/连续天数）', () => {
  const src = read(HOME);
  assert.equal(/days\.sort/.test(src), false, 'HomePage 仍有 days.sort（第二套连续天数）');
  assert.equal(/total\s*\+=/.test(src), false, 'HomePage 仍有 total +=（第二套总字数）');
  assert.equal(/total\s*=\s*total\s*\+/.test(src), false, 'HomePage 仍有 total = total +');
  assert.equal(/list\[i\]\.charCount/.test(src), false, 'HomePage 仍直接读 charCount 求总字数');
  assert.equal(
    /for\s*\(\s*let\s+i\s*=\s*0;\s*i\s*<\s*list\.length;\s*i\+\+\s*\)\s*\{\s*total/.test(src),
    false, 'HomePage 仍有 list 求和循环');
  assert.ok(src.includes('statsService.totalWords()'), '未调用 statsService.totalWords()');
  assert.ok(src.includes('statsService.consecutiveDays()'), '未调用 statsService.consecutiveDays()');
  // latest 仍从 docStore.list() 第一条取
  assert.ok(src.includes('docStore.list()'), '未从 docStore.list() 取最新文档');
});

test('HomePage：目标行与 statsRev @Watch 接线存在', () => {
  const src = read(HOME);
  assert.ok(/@Prop\s+@Watch\('onStatsRev'\)\s+statsRev/.test(src), '缺 statsRev @Watch');
  assert.ok(/onStatsRev\(\)/.test(src), '缺 onStatsRev 回调');
  assert.ok(src.includes("$r('app.string.home_today')"), '目标行缺 home_today');
  assert.ok(src.includes("$r('app.string.home_goal')"), '目标行缺 home_goal');
  assert.ok(src.includes("$r('app.string.home_unit')"), '目标行缺 home_unit');
  assert.ok(src.includes("$r('app.string.home_goal_met')"), '目标行缺 home_goal_met');
  assert.ok(src.includes('ProgressType.Linear'), '目标行缺线性进度条');
  assert.ok(/\.width\(160\)\.height\(3\)/.test(src), '进度条尺寸须 160×3');
  assert.ok(src.includes("'#c9a45c'"), '进度条须金色');
  // 目标行不受 totalChars>0 守卫（空文档也显示）：统计 if 块在"目标行"注释前闭合
  const statsIf = src.indexOf('if (this.totalChars > 0)');
  const goalMarker = src.indexOf('// ⑥ 目标行');
  const goalRow = src.indexOf("$r('app.string.home_today')");
  assert.ok(statsIf >= 0 && goalMarker > statsIf && goalRow > goalMarker,
    '目标行应在统计行 if 块之后');
  const statsBlock = src.slice(statsIf, goalMarker);
  assert.equal((statsBlock.match(/\{/g) || []).length, (statsBlock.match(/\}/g) || []).length,
    '统计 if 块未在目标行前闭合（目标行被包进了 totalChars>0 分支）');
});

test('StatsService：pending 内存增量与纸张种类存在', () => {
  const src = read(STATS_SERVICE);
  assert.ok(/static\s+pendingBuf/.test(src), '缺静态 pending');
  assert.ok(/recordChar\(\): void/.test(src), '缺 recordChar()');
  assert.ok(/pendingChars\(\): number/.test(src), '缺 pendingChars()');
  assert.ok(/flushPending\(\): void/.test(src), '缺 flushPending()');
  assert.ok(/static\s+pendingDayKey/.test(src), '缺 pending 所属日，跨日会记错天');
  assert.ok(/pendingDayKey === key/.test(src), 'todayChars 未按 pending 所属日过滤');
  assert.ok(/paperKindsUsed\(\): number/.test(src), '缺 paperKindsUsed()');
  assert.ok(/recordPaperKind\(kind: string\): void/.test(src), '缺 recordPaperKind()');
  assert.ok(src.includes('mergeDailyChars('), '日字数合并未走 StatsCore.mergeDailyChars');
  assert.ok(src.includes('stats.paper.kinds'), '纸张种类键名应为 stats.paper.kinds');
  assert.ok(/totalWords\(\): number/.test(src) && /consecutiveDays\(\): number/.test(src),
    'totalWords/consecutiveDays 口径不得移除');
});

test('CollectionPage / CollectionDetailPage：进度 props 与"待定"条件', () => {
  const page = read(COLLECTION);
  assert.ok(/@Prop\s+totalWords: number/.test(page), 'CollectionPage 缺 totalWords');
  assert.ok(/@Prop\s+streakDays: number/.test(page), 'CollectionPage 缺 streakDays');
  assert.ok(page.includes("$r('app.string.collection_progress')"), 'CollectionPage 缺 collection_progress');

  const detail = read(DETAIL);
  assert.ok(/@Prop\s+totalWords: number/.test(detail), 'DetailPage 缺 totalWords');
  assert.ok(/@Prop\s+streakDays: number/.test(detail), 'DetailPage 缺 streakDays');
  assert.ok(/@Prop\s+paperKindsUsed: number/.test(detail), 'DetailPage 缺 paperKindsUsed');
  assert.ok(detail.includes("$r('app.string.collection_total_words')"), '缺 collection_total_words');
  assert.ok(detail.includes("$r('app.string.collection_streak')"), '缺 collection_streak');
  assert.ok(detail.includes("$r('app.string.collection_paper_kinds')"), '缺 collection_paper_kinds');
  assert.ok(detail.includes("$r('app.string.collection_pending')"), '缺 collection_pending 条件行');
  assert.ok(/for \(let i = 0; i < 4; i\+\+\)/.test(detail), 'reveal 循环未扩到 4');
  assert.equal(/for \(let i = 0; i < 3; i\+\+\)/.test(detail), false, 'reveal 循环仍是 3');
  assert.ok(detail.includes('this.revealN > 3'), '进度区未用 revealN > 3');
});

test('string.json：machine_cond_* 不含数字阈值，必要键齐全', () => {
  const data = JSON.parse(read(STRINGS));
  const byName = new Map();
  for (const item of data.string) {
    assert.equal(byName.has(item.name), false, `string.json 键重复: ${item.name}`);
    byName.set(item.name, item.value);
  }
  for (const name of ['machine_cond_1920s', 'machine_cond_1930s', 'machine_cond_1950s', 'machine_cond_1960s']) {
    assert.ok(byName.has(name), `缺 ${name}`);
    assert.equal(/[0-9]/.test(byName.get(name)), false, `${name} 仍含数字阈值: ${byName.get(name)}`);
  }
  assert.equal(byName.get('machine_cond_1930s'), '待定（阈值待批准）');
  assert.equal(byName.get('machine_cond_1950s'), '待定（阈值待批准）');
  assert.equal(byName.get('machine_cond_1960s'), '待定（阈值待批准）');
  assert.equal(byName.get('machine_cond_1920s'), '默认机器');

  const exact = {
    home_today: '今日',
    home_goal: '目标',
    home_unit: '字',
    home_goal_met: '今日目标已达成',
    settings_goal: '每日目标',
    collection_progress: '当前总字数',
    collection_total_words: '总字数',
    collection_streak: '连续天数',
    collection_paper_kinds: '用过纸张种类',
    collection_pending: '待定（阈值待批准）',
  };
  for (const [name, value] of Object.entries(exact)) {
    assert.ok(byName.has(name), `缺新增文案键 ${name}`);
    assert.equal(byName.get(name), value, `${name} 值不符`);
  }
  assert.ok(byName.has('sound_credit'), '缺 sound_credit');
  assert.ok(/CC BY/.test(byName.get('sound_credit')), 'sound_credit 须含 CC BY 署名说明');
  assert.ok(/ddohler/.test(byName.get('sound_credit')), 'sound_credit 须含 SOURCE.txt 的 CC BY 作者 ddohler');
});

test('SettingsPage / SettingsRow：每日目标行', () => {
  const page = read(SETTINGS);
  assert.ok(page.includes("$r('app.string.settings_goal')"), 'SettingsPage 缺 settings_goal');
  assert.ok(/@Prop\s+dailyGoal: number/.test(page), 'SettingsPage 缺 dailyGoal prop');
  assert.ok(/onGoal: \(n: number\) => void/.test(page), 'SettingsPage 缺 onGoal');
  assert.ok(/sliderMin: 100/.test(page) && /sliderMax: 2000/.test(page) && /sliderStep: 100/.test(page),
    '每日目标滑杆范围/步进不符');
  assert.ok(page.includes('clampDailyGoal('), '滑杆值未 clamp');
  assert.ok(page.includes('for (let i = 0; i < 6; i++)'), '设置页 reveal 组数未随新增组调整');

  const row = read(ROW);
  assert.ok(/@Prop\s+sliderValueText: string/.test(row), 'SettingsRow 缺 sliderValueText');
  assert.ok(row.indexOf('this.sliderValueText.length > 0') < row.indexOf('Slider({ value: this.sliderValue'),
    'sliderValueText 应在 Slider 左侧渲染');
  assert.ok(/\.fontSize\(14\)/.test(row) && row.includes("'#c9a45c'"), 'sliderValueText 须 14vp 金色');
});