import io
p = 'tools/tests/app-icon.test.mjs'
s = io.open(p, encoding='utf-8', newline=None).read()
old = """test('14 种 kind 全部登记（第 10 批新增 help）', () => {
  const kinds = [...text.matchAll(/static readonly [A-Z_]+: string = '([^']+)'/g)].map((m) => m[1]);
  assert.equal(kinds.length, 14);
  assert.deepEqual(kinds, [
    'back', 'chevron_up', 'plus', 'chevron', 'folder', 'menu', 'more',
    'check', 'settings', 'export', 'rename', 'delete', 'lock', 'help',
  ]);
});"""
new = """test('19 种 kind 全部登记（第 13 批 ④ 新增 5 个引导图标）', () => {
  const kinds = [...text.matchAll(/static readonly [A-Z_]+: string = '([^']+)'/g)].map((m) => m[1]);
  assert.equal(kinds.length, 19);
  assert.deepEqual(kinds, [
    'back', 'chevron_up', 'plus', 'chevron', 'folder', 'menu', 'more',
    'check', 'settings', 'export', 'rename', 'delete', 'lock', 'help',
    'onboard_type', 'onboard_machine', 'onboard_paper', 'onboard_export', 'onboard_input',
  ]);
});"""
assert old in s
s = s.replace(old, new)
io.open(p, 'w', encoding='utf-8', newline='\r\n').write(s)

p2 = 'tools/tests/guide-keys.test.mjs'
s2 = io.open(p2, encoding='utf-8', newline=None).read()
old2 = """test('Index：typewriter 引导函数与启动引导 4 条键在 Index', () => {
  const index = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8');
  for (const key of core.onboardingKeys()) {
    assert.ok(index.includes(`$r('app.string.${key}')`), `Index 缺 ${key}`);
  }
  assert.ok(index.includes("$r('app.string.guide_typewriter_1')") ||
    index.includes('guideStepsForTypewriter'), 'Index 缺打字机引导');
});"""
new2 = """test('Index：typewriter 引导函数；启动引导 4 条旧键已随旧卡片删除，新引导 11 键在新组件', () => {
  const index = fs.readFileSync(path.join(root, 'entry/src/main/ets/pages/Index.ets'), 'utf8');
  const onboarding = fs.readFileSync(
    path.join(root, 'entry/src/main/ets/components/OnboardingGuide.ets'), 'utf8');
  // 第 13 批 ④：onboardingSteps() 删除，Index 只挂新组件
  assert.ok(!index.includes('onboardingSteps'), 'Index 不应再有旧 onboardingSteps()');
  assert.ok(!index.includes("$r('app.string.guide_onboarding_1')"), '旧 4 行文案应随旧卡片删除');
  assert.ok(index.includes('OnboardingGuide({'), 'Index 缺新引导挂载');
  for (const key of core.onboarding2Keys()) {
    assert.ok(onboarding.includes(`$r('app.string.${key}')`), `OnboardingGuide 缺 ${key}`);
  }
  assert.ok(index.includes("$r('app.string.guide_typewriter_1')") ||
    index.includes('guideStepsForTypewriter'), 'Index 缺打字机引导');
});"""
assert old2 in s2
s2 = s2.replace(old2, new2)
io.open(p2, 'w', encoding='utf-8', newline='\r\n').write(s2)
print('tests ok')
