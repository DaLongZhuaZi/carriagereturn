/**
 * 回车 · 主页（§11 极简方向 C）
 *
 * 自上而下：机器图区 → 回车大字 → 引导语 → 金色按钮 → 统计行 → 底部入口行。
 * 数据：继续写作＝最近修改的一张纸；总字数＝全部文档 charCount 之和；连续天数＝updatedAt 去重日期以今天为终点连续算。
 */

import { DocSummary } from '../model/DocModel';
import { docStore } from '../services/DocStore';
import { applyImmersive, Insets } from '../services/Immersive';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GuideStep } from './GuideOverlay';

@Component
export struct HomePage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  @State topInset: number = 28;
  @State bottomInset: number = 0;
  @State latestId: string = '';
  @State latestTitle: string = '';
  @State totalChars: number = 0;
  @State streakDays: number = 0;
  @State op: number = 0;
  onContinue: () => void = (): void => {};
  onStartTyping: () => void = (): void => {};
  onOpen: (key: string) => void = (): void => {};

  aboutToAppear(): void {
    this.applyInsets();
    this.refresh();
    // AGENTS 页面切换：主页不许每次回都重播淡入
    this.op = 1;
  }

  private async applyInsets(): Promise<void> {
    const ins: Insets = await applyImmersive(this.getUIContext());
    this.topInset = ins.top;
    this.bottomInset = ins.bottom;
    hilog.info(0x0000, 'HomePage', 'insets top=%{public}s bottom=%{public}s',
      ins.top.toFixed(1), ins.bottom.toFixed(1));
  }

  private refresh(): void {
    const list: DocSummary[] = docStore.list();
    let total: number = 0;
    for (let i = 0; i < list.length; i++) {
      total += list[i].charCount === undefined ? 0 : list[i].charCount as number;
    }
    this.totalChars = total;
    if (list.length > 0) {
      this.latestId = list[0].id;
      this.latestTitle = list[0].title;
    }
    // 连续天数：updatedAt 去重日期，以今天为终点
    const days: number[] = [];
    for (let i = 0; i < list.length; i++) {
      const d: Date = new Date(list[i].updatedAt);
      const k: number = d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate();
      if (days.indexOf(k) < 0) { days.push(k); }
    }
    days.sort((a: number, b: number) => b - a);
    let streak: number = 0;
    const today: Date = new Date();
    const tk: number = today.getFullYear() * 10000 + (today.getMonth() + 1) * 100 + today.getDate();
    let cursor: number = tk;
    for (let i = 0; i < days.length; i++) {
      if (days[i] === cursor) {
        streak = streak + 1;
        const d: Date = new Date(cursor / 10000 | 0, ((cursor % 10000) / 100 | 0) - 1, cursor % 100);
        d.setDate(d.getDate() - 1);
        cursor = d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate();
      } else if (days[i] < cursor) {
        break;
      }
    }
    this.streakDays = streak;
    hilog.info(0x0000, 'HomePage', 'data docs=%{public}s total=%{public}s streak=%{public}s',
      list.length.toString(), total.toString(), streak.toString());
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

      Scroll() {
        Column() {
          // ① 机器图区（现有 rawfile，全宽 Cover）
          Image($rawfile('machine/1920s-upright-side.jpg'))
            .width('100%').height(220).objectFit(ImageFit.Cover)
            .opacity(0.9)

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

          Column().width('100%').height(24)
        }
        .width('100%')
        .opacity(this.op)
        .animation({ duration: 200, curve: Curve.EaseOut })
      }
      .layoutWeight(1).width('100%').scrollBar(BarState.Off)

      // ⑥ 底部入口行（底距 = bottomInset）
      Row() {
        this.entryLink('卷宗', 'dossier')
        this.entryLink('收藏', 'collection')
        this.entryLink('换装', 'customize')
        this.entryLink('设置', 'settings')
        this.entryLink('导出', 'export')
      }
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
export function guideStepsForHome(): GuideStep[] {
  return [
    { text: $r('app.string.guide_home_1') },
    { text: $r('app.string.guide_home_2') },
    { text: $r('app.string.guide_home_3') },
  ];
}
