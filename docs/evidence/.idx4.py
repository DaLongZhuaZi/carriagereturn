import io
p = 'entry/src/main/ets/pages/Index.ets'
s = io.open(p, encoding='utf-8', newline=None).read()

# 1) 删除 onboardingSteps()
old = """  private onboardingSteps(): GuideStep[] {
    return [
      { text: $r('app.string.guide_onboarding_1') },
      { text: $r('app.string.guide_onboarding_2') },
      { text: $r('app.string.guide_onboarding_3') },
      { text: $r('app.string.guide_onboarding_4') },
    ];
  }

"""
assert old in s
s = s.replace(old, "")

# 2) closeOnboarding：删 120ms 补弹，落主页 seen，重置页号
old = """  private closeOnboarding(): void {
    GuideService.markOnboardingSeen();
    this.onboardingVisible = false;
    setTimeout(() => { this.maybeShowPageGuide(); }, 120);
  }"""
new = """  private closeOnboarding(): void {
    GuideService.markOnboardingSeen();
    // 第 13 批 ④：新引导已介绍主页 → 关闭时直接落主页 seen，不再 120ms 补弹主页聚光灯
    GuideService.markSeen(GUIDE_PAGE_HOME);
    this.onboardingVisible = false;
    this.onboardingPage = 0;
  }"""
assert old in s
s = s.replace(old, new)

# 3) replayOnboarding 重置页号
old = """  private replayOnboarding(): void {
    GuideService.resetOnboarding();
    this.onboardingVisible = true;
  }"""
new = """  private replayOnboarding(): void {
    GuideService.resetOnboarding();
    this.onboardingPage = 0;
    this.onboardingVisible = true;
  }"""
assert old in s
s = s.replace(old, new)

# 4) onBackPress：新引导页号感知（上一页 / 首屏跳过）
old = """    if (this.onboardingVisible) {
      this.closeOnboarding();
      return true;
    }"""
new = """    if (this.onboardingVisible) {
      // 第 13 批 ④：返回＝上一页；第一页返回＝跳过（关闭）
      if (this.onboardingPage > 0) {
        this.onboardingPage = this.onboardingPage - 1;
      } else {
        this.closeOnboarding();
      }
      return true;
    }"""
assert old in s
s = s.replace(old, new)

# 5) 600ms 首启触发：成就弹窗门控 + 页号重置
old = """    if (!GuideService.onboardingSeen()) {
      setTimeout(() => { this.onboardingVisible = true; }, 600);
    } else {"""
new = """    if (!GuideService.onboardingSeen()) {
      setTimeout(() => {
        // 第 13 批 ④：成就弹窗优先——开着即跳过本次冷启动，不重试（与聚光灯同口径）
        if (this.achNoticeKind.length > 0) {
          hilog.info(DOMAIN, TAG, 'onboarding skipped: achievement notice open');
          return;
        }
        this.onboardingPage = 0;
        this.onboardingVisible = true;
      }, 600);
    } else {"""
assert old in s
s = s.replace(old, new)

# 6) 挂载点：GuideOverlay -> OnboardingGuide（文件保留供回滚）
old = """      // 第 1 批：引导浮层（唯一挂载点；启动引导优先，页面引导次之）
      GuideOverlay({
        visible: this.onboardingVisible,
        title: $r('app.string.guide_onboarding_title'),
        steps: this.onboardingSteps(),
        showSkip: true,
        onNext: (): void => { this.closeOnboarding(); },
        onSkip: (): void => { this.closeOnboarding(); },
        onClose: (): void => { this.closeOnboarding(); },
      })"""
new = """      // 第 13 批 ④：启动引导改为新全屏组件（GuideOverlay.ets 保留作回滚对照）
      OnboardingGuide({
        visible: this.onboardingVisible,
        page: $onboardingPage,
        onSkip: (): void => { this.closeOnboarding(); },
        onStart: (): void => { this.closeOnboarding(); },
      })"""
assert old in s
s = s.replace(old, new)

io.open(p, 'w', encoding='utf-8', newline='\r\n').write(s)
print('index 4 ok')

