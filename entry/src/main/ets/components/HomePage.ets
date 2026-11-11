/**
 * 回车 · 主页（§11 极简方向 C）
 *
 * 自上而下：机器图区 → 回车大字 → 引导语 → 金色按钮 → 统计行 → 目标行 → 底部入口行。
 * 数据（单一派生层，第 4 批 B-1）：总字数／连续天数／今日字数／每日目标全部取 StatsService；
 * 这里不再自算（latestId/latestTitle 仍从 docStore.list() 第一条取）。
 */

import { DocSummary } from '../model/DocModel';
import { docStore } from '../services/DocStore';
import { statsService } from '../services/StatsService';
import { applyImmersive, Insets } from '../services/Immersive';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SpotlightStep } from './SpotlightOverlay';
import { GuideBridge } from '../services/GuideBridge';

@Component
export struct HomePage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  /** F11 刷新时机（M-7）：Index 在改目标/返回主页/导出保存后递增，触发 refresh。 */
  @Prop @Watch('onStatsRev') statsRev: number = 0;
  @State topInset: number = 28;
  @State bottomInset: number = 0;
  @State latestId: string = '';
  @State latestTitle: string = '';
  @State totalChars: number = 0;
  @State streakDays: number = 0;
  @State todayChars: number = 0;
  @State dailyGoal: number = 500;
  @State goalProgress: number = 0;
  @State op: number = 0;
  /** 第 10 批：引导入口总开关（false 时隐藏）。 */
  @Prop guideEnabled: boolean = true;
  onContinue: () => void = (): void => {};
  onStartTyping: () => void = (): void => {};
  onOpen: (key: string) => void = (): void => {};

  aboutToAppear(): void {
    this.applyInsets();
    this.refresh();
    // AGENTS 页面切换：主页不许每次回都重播淡入
    this.op = 1;
  }

  /** @Watch 回调：Index 的 statsRev 变化即重取统计（空文档也刷新目标行）。 */
  onStatsRev(): void {
    this.refresh();
  }

  private async applyInsets(): Promise<void> {
    const ins: Insets = await applyImmersive(this.getUIContext());
    this.topInset = ins.top;
    this.bottomInset = ins.bottom;
    hilog.info(0x0000, 'HomePage', 'insets top=%{public}s bottom=%{public}s',
      ins.top.toFixed(1), ins.bottom.toFixed(1));
  }

  private refresh(): void {
    // 单一派生层：统计口径只在 StatsService／StatsCore
    this.totalChars = statsService.totalWords();
    this.streakDays = statsService.consecutiveDays();
    this.todayChars = statsService.todayChars();
    this.dailyGoal = statsService.dailyGoal();
    this.goalProgress = statsService.goalProgress();
    // latest 仍从文档列表取（只取第一条，不做第二套统计）
    const list: DocSummary[] = docStore.list();
    if (list.length > 0) {
      this.latestId = list[0].id;
      this.latestTitle = list[0].title;
    }
    hilog.info(0x0000, 'HomePage',
      'data docs=%{public}s total=%{public}s streak=%{public}s today=%{public}s goal=%{public}s',
      list.length.toString(), this.totalChars.toString(), this.streakDays.toString(),
      this.todayChars.toString(), this.dailyGoal.toString());
  }

  @Builder
  entryLink(label: string, key: string) {
    Text(label).fontSize(15).fontColor('#e8ddc9')
      .layoutWeight(1).textAlign(TextAlign.Center)
      .onClick(() => { this.onOpen(key); })
  }

  build() {
    Column() {
      Column().width('100%').height(this.topInset)
      if (this.guideEnabled) {
        Row() {
          Blank()
          Stack() {
            Text('?')
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
          }
          .width(44).height(44)
          .onClick(() => { GuideBridge.request('home'); })
        }.width('100%').height(44).padding({ left: 12, right: 12 })
      }

      Scroll() {
        Column() {
          // ① 机器图区（现有 rawfile，全宽 Cover）
          Image($rawfile('machine/1920s-upright-side.jpg'))
            .width('100%').height(220).objectFit(ImageFit.Cover)
            .opacity(0.9)
            .id('home__hero')

          // ② 回车大字
          Text('回车').fontSize(44).fontFamily('Noto Serif SC')
            .fontColor('#e8ddc9').width('100%').textAlign(TextAlign.Center)
            .margin({ top: 20 })

          // ③ 引导语
          Text('这是一台打字机。敲下去，字就落在纸上。')
            .fontSize(15).fontColor('rgba(232,221,201,0.75)')
            .width('100%').textAlign(TextAlign.Center).margin({ top: 10 })

          // ④ 金色按钮
          Text(this.latestId.length > 0 ? '继续写作' : '开始打字')
            .id('home__start_btn')
            .fontSize(17).fontWeight(FontWeight.Bold).fontColor('#171310')
            .width('100%').height(56).textAlign(TextAlign.Center)
            .borderRadius(28).backgroundColor('#c9a45c')
            .margin({ top: 28 })
            .onClick(() => {
              if (this.latestId.length > 0) {
                this.onContinue();
              } else {
                this.onStartTyping();
              }
            })

          // ⑤ 统计行（总字数 0 时整行不显示）
          if (this.totalChars > 0) {
            Text(this.streakDays > 0
              ? '已写 ' + this.totalChars.toString() + ' 字 · 连续 ' + this.streakDays.toString() + ' 天'
              : '已写 ' + this.totalChars.toString() + ' 字')
              .fontSize(12).fontColor('rgba(232,221,201,0.6)')
              .width('100%').textAlign(TextAlign.Center).margin({ top: 12 })
          }

          // ⑥ 目标行（F11）：空文档也显示（今日 0 / 目标 500 字），线性进度条 160×3 金色
          Row({ space: 4 }) {
            Text($r('app.string.home_today'))
              .fontSize(13).fontColor('rgba(232,221,201,0.6)')
            Text(this.todayChars.toString())
              .fontSize(13).fontColor('#c9a45c')
            Text('/')
              .fontSize(13).fontColor('rgba(232,221,201,0.4)')
            Text($r('app.string.home_goal'))
              .fontSize(13).fontColor('rgba(232,221,201,0.6)')
            Text(this.dailyGoal.toString())
              .fontSize(13).fontColor('#c9a45c')
            Text($r('app.string.home_unit'))
              .fontSize(13).fontColor('rgba(232,221,201,0.6)')
            Progress({ value: this.goalProgress * 100, total: 100, type: ProgressType.Linear })
              .width(160).height(3)
              .color('#c9a45c')
              .backgroundColor('rgba(201,164,92,0.25)')
              .margin({ left: 6 })
          }
          .width('100%').justifyContent(FlexAlign.Center).margin({ top: 8 })

          if (this.goalProgress >= 1) {
            Text($r('app.string.home_goal_met'))
              .fontSize(12).fontColor('#c9a45c')
              .width('100%').textAlign(TextAlign.Center).margin({ top: 4 })
          }

          Column().width('100%').height(24)
        }
        .width('100%')
        .opacity(this.op)
        .animation({ duration: 200, curve: Curve.EaseOut })
      }
      .layoutWeight(1).width('100%').scrollBar(BarState.Off)

      // ⑦ 底部入口行（底距 = bottomInset）
      Row() {
        this.entryLink('卷宗', 'dossier')
        this.entryLink('收藏', 'collection')
        this.entryLink('换装', 'customize')
        this.entryLink('设置', 'settings')
        this.entryLink('导出', 'export')
      }
      .id('home__bottom_nav')
      .width('100%').height(56)
      .padding({ left: 8, right: 8 })
      .margin({ bottom: this.bottomInset })
    }
    .width(this.widthVp).height(this.heightVp)
    .linearGradient({ direction: GradientDirection.Bottom,
      colors: [['#171310', 0.0], ['#241c16', 1.0]] })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

/** Home 页首次引导（与功能同处一源；文案键见 string.json）。 */
export function guideStepsForHome(): SpotlightStep[] {
  return [
    { text: $r('app.string.guide_home_1'), anchorId: 'home__hero' },
    { text: $r('app.string.guide_home_2'), anchorId: 'home__start_btn' },
    { text: $r('app.string.guide_home_3'), anchorId: 'home__bottom_nav' },
  ];
}
