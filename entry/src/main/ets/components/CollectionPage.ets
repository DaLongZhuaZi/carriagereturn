/**
 * 回车 · 收藏页（§3）+ 沉浸式（§2.10）
 *
 * 两列网格（大屏更多列）；卡片＝深色底 #241c16 + 剪影区 200vp + 名字 + 状态 + 条件行。
 * 第 9 批 F5 起四台机永久全开，锁定态（深色罩／锁图标／剪影 0.35）已删；成就是纯徽章＋进度。
 */

import { MachineKind } from '../model/DocModel';
import { PageShell } from './PageShell';
import { HintBar } from './HintBar';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { GuideStep } from './GuideOverlay';
import { AchievementDef, ACHIEVEMENTS } from '../model/AchievementDefs';
import { AchievementInputs } from '../model/AchievementCore';
import { AchievementService } from '../services/AchievementService';

// P2-5：文案全部走 resources/base/element/string.json，代码只读资源
const M_NAME: Record<string, Resource> = {
  '1920s-upright': $r('app.string.machine_name_1920s'),
  '1930s-portable': $r('app.string.machine_name_1930s'),
  '1950s-streamlined': $r('app.string.machine_name_1950s'),
  '1960s-electric': $r('app.string.machine_name_1960s'),
};

const ACH_NAME: Record<string, Resource> = {
  'words_1000': $r('app.string.ach_name_words_1000'),
  'words_5000': $r('app.string.ach_name_words_5000'),
  'words_20000': $r('app.string.ach_name_words_20000'),
  'streak_3': $r('app.string.ach_name_streak_3'),
  'streak_7': $r('app.string.ach_name_streak_7'),
  'goal_1': $r('app.string.ach_name_goal_1'),
  'share_1': $r('app.string.ach_name_share_1'),
  'share_10': $r('app.string.ach_name_share_10'),
  'paper_2': $r('app.string.ach_name_paper_2'),
  'paper_4': $r('app.string.ach_name_paper_4'),
  'font_1': $r('app.string.ach_name_font_1'),
  'ribbon_1': $r('app.string.ach_name_ribbon_1'),
  'fold_1': $r('app.string.ach_name_fold_1'),
  'docs_10': $r('app.string.ach_name_docs_10'),
};

const ACH_DESC: Record<string, Resource> = {
  'words_1000': $r('app.string.ach_desc_words_1000'),
  'words_5000': $r('app.string.ach_desc_words_5000'),
  'words_20000': $r('app.string.ach_desc_words_20000'),
  'streak_3': $r('app.string.ach_desc_streak_3'),
  'streak_7': $r('app.string.ach_desc_streak_7'),
  'goal_1': $r('app.string.ach_desc_goal_1'),
  'share_1': $r('app.string.ach_desc_share_1'),
  'share_10': $r('app.string.ach_desc_share_10'),
  'paper_2': $r('app.string.ach_desc_paper_2'),
  'paper_4': $r('app.string.ach_desc_paper_4'),
  'font_1': $r('app.string.ach_desc_font_1'),
  'ribbon_1': $r('app.string.ach_desc_ribbon_1'),
  'fold_1': $r('app.string.ach_desc_fold_1'),
  'docs_10': $r('app.string.ach_desc_docs_10'),
};

const M_COND: Record<string, Resource> = {
  '1920s-upright': $r('app.string.machine_cond_1920s'),
  '1930s-portable': $r('app.string.machine_cond_1930s'),
  '1950s-streamlined': $r('app.string.machine_cond_1950s'),
  '1960s-electric': $r('app.string.machine_cond_1960s'),
};

@Component
export struct CollectionPage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  @Prop currentMachine: string = '1920s-upright';
  /** 第 4 批 F14：当前进度（全局统计，锁定卡也可见；数值取 StatsService）。 */
  @Prop totalWords: number = 0;
  @Prop streakDays: number = 0;
  /** 第 9 批 F5：成就/事件变化计数（Index 侧变更即自增，用来驱动本页重读成就状态）。 */
  @Prop achieveRev: number = 0;

  @State revealN: number = 0;
  /** P1-9：锁定态提示文案（空＝不显示）。 */
  @State hintText: Resource | null = null;
  /** D3：提示条触发计数（每次 +1 让 HintBar 重新下滑）。 */
  @State hintNonce: number = 0;
  /** P2-14：点按缩放反馈（0.97／120ms）。 */
  @State pressedIdx: number = -1;
  onBack: () => void = (): void => {};
  onPick: (kind: string) => void = (): void => {};

  private readonly kinds: string[] = ['1920s-upright', '1930s-portable', '1950s-streamlined', '1960s-electric'];

  aboutToAppear(): void {
    // insets 交给 PageShell；D6：60ms 逐格揭示
    this.revealN = 0;
    for (let i = 0; i < this.kinds.length; i++) {
      setTimeout(() => { this.revealN = i + 1; }, i * 60);
    }
  }

  /** 机器永不锁定：第 9 批 F5 起**永久全开**（成就只奖行为、不再开机器；旧「改回按条件判定」的说法已作废）。 */
  private unlocked(kind: string): boolean {
    return true;
  }

  private colsTemplate(): string {
    const usable: number = this.widthVp - 40;
    const n: number = Math.floor((usable + 16) / 260);
    const c: number = n < 2 ? 2 : (n > 4 ? 4 : n);
    if (c === 2) { return '1fr 1fr'; }
    if (c === 3) { return '1fr 1fr 1fr'; }
    return '1fr 1fr 1fr 1fr';
  }

  @Builder
  card(kind: string, idx: number) {
    Column() {
      // 剪影区 200vp
      Stack({ alignContent: Alignment.Center }) {
        Column().width('100%').height(200).backgroundColor('#241c16')
        // P2-4：剪影改用 *-front.jpg 裁切——只露纸＋滚筒/底座轮廓（不许整图展示）
        Image($rawfile('machine/' + kind + '-front.jpg'))
          .width('100%').height(200).objectFit(ImageFit.Cover)
          .opacity(0.92)
          .clip(true)
        // 第 9 批 F5：机器永久全开，锁定态（深色罩／锁图标／剪影 0.35）已删——不再有死代码
      }
      .width('100%').height(200).clip(true)

      Text(M_NAME[kind]).fontSize(17).fontColor('#e8ddc9').margin({ top: 10 })
        .maxLines(1)
      Text($r('app.string.collection_owned'))
        .fontSize(12)
        .fontColor('#c9a45c')
        .margin({ top: 4 })
      // F14：当前进度（条件行位置；锁定态也可见）。文案走资源键，不在本页写死进度短语。
      Row({ space: 2 }) {
        Text($r('app.string.collection_progress'))
          .fontSize(12).fontColor('rgba(232,221,201,0.5)').maxLines(1)
        Text(this.totalWords.toString())
          .fontSize(12).fontColor('rgba(232,221,201,0.8)')
        Text($r('app.string.home_unit'))
          .fontSize(12).fontColor('rgba(232,221,201,0.5)')
        Text('·')
          .fontSize(12).fontColor('rgba(232,221,201,0.35)')
        Text($r('app.string.collection_streak'))
          .fontSize(12).fontColor('rgba(232,221,201,0.5)').maxLines(1)
        Text(this.streakDays.toString())
          .fontSize(12).fontColor('rgba(232,221,201,0.8)')
      }
      .width('100%').justifyContent(FlexAlign.Center).margin({ top: 4 })
      Text(M_COND[kind]).fontSize(12).fontColor('rgba(232,221,201,0.6)')
        .margin({ top: 4 }).maxLines(1)
    }
    .width('100%')
    .padding({ bottom: 12 })
    .borderRadius(10)
    .backgroundColor('#241c16')
    .clip(true)
    .scale({ x: this.pressedIdx === idx ? 0.97 : 1, y: this.pressedIdx === idx ? 0.97 : 1 })
    .animation({ duration: 120, curve: Curve.EaseOut })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressedIdx = idx;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressedIdx = -1;
      }
    })
    .opacity(this.revealN > idx ? 1 : 0)
    .animation({ duration: 180, curve: Curve.EaseOut })
    .onClick(() => { this.onPick(kind); })
  }

  /** 判定输入快照（成就进度显示用；判定本身在 AchievementCore 纯函数里）。 */
  private inputs(): AchievementInputs {
    return AchievementService.buildInputs();
  }

  /** 一项成就进度行：名＋说明＋进度条＋当前值/阈值（或已达成／仅折叠设备）。 */
  @Builder
  achRow(id: string) {
    Row() {
      Column() {
        Text(ACH_NAME[id])
          .fontSize(14).fontColor(AchievementService.isAchieved(id) ? '#c9a45c' : '#e8ddc9')
          .maxLines(1)
        Text(ACH_DESC[id])
          .fontSize(11).fontColor('rgba(232,221,201,0.55)').maxLines(1)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1)

      Column() {
        Text(this.achValueText(id))
          .fontSize(11).fontColor(AchievementService.isAchieved(id) ? '#c9a45c' : 'rgba(232,221,201,0.6)')
        Progress({
          value: Math.round(AchievementService.progressOf(id, this.inputs()) * 100),
          total: 100, type: ProgressType.Linear,
        })
          .width(120).height(4)
          .color(AchievementService.isAchieved(id) ? '#c9a45c' : 'rgba(232,221,201,0.35)')
          .margin({ top: 6 })
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .borderRadius(8)
    .backgroundColor('#1f1813')
  }

  /** 进度文案：已达成／仅折叠设备／当前值/阈值。 */
  private achValueText(id: string): string {
    if (AchievementService.isAchieved(id)) {
      return this.resolveStr($r('app.string.ach_unlocked'));
    }
    const def = ACHIEVEMENTS.find((d) => d.id === id);
    if (def === undefined) {
      return '';
    }
    if (def.foldOnly && !AchievementService.foldableDevice()) {
      return this.resolveStr($r('app.string.ach_fold_only'));
    }
    const v: number = this.achRawValue(def.metric);
    return v.toString() + '/' + def.threshold.toString();
  }

  /** 取数据源原值（与 AchievementCore.metricValue 同口径；这里只为显示数字）。 */
  private achRawValue(metric: string): number {
    const i: AchievementInputs = this.inputs();
    if (metric === 'words') { return i.totalChars; }
    if (metric === 'streak') { return i.streakDays; }
    if (metric === 'goal') { return i.goalReached ? 1 : 0; }
    if (metric === 'share') { return i.shareCount; }
    if (metric === 'paper') { return i.paperKinds; }
    if (metric === 'font') { return i.fontChanges; }
    if (metric === 'ribbon') { return i.ribbonChanges; }
    if (metric === 'fold') { return i.foldChars; }
    if (metric === 'saved') { return i.saves; }
    return 0;
  }

  /** 取资源文案（Resource → string）。 */
  private resolveStr(r: Resource): string {
    try {
      const host = getContext(this) as common.UIAbilityContext;
      return host.resourceManager.getStringSync(r.id);
    } catch (e) {
      return '';
    }
  }

  @Builder
  body() {
    Column() {
      // F14 进度收敛到成就列表顶部：总字数／连续天数／已达成数
      Row({ space: 10 }) {
        Text($r('app.string.collection_progress'))
          .fontSize(12).fontColor('rgba(232,221,201,0.5)')
        Text(this.totalWords.toString())
          .fontSize(12).fontColor('rgba(232,221,201,0.85)')
        Text($r('app.string.home_unit'))
          .fontSize(12).fontColor('rgba(232,221,201,0.5)')
        Text('·')
          .fontSize(12).fontColor('rgba(232,221,201,0.35)')
        Text($r('app.string.collection_streak'))
          .fontSize(12).fontColor('rgba(232,221,201,0.5)')
        Text(this.streakDays.toString())
          .fontSize(12).fontColor('rgba(232,221,201,0.85)')
        Blank()
        Text($r('app.string.ach_list_title'))
          .fontSize(12).fontColor('rgba(232,221,201,0.5)')
        Text(AchievementService.achievedCount().toString() + '/' + ACHIEVEMENTS.length.toString())
          .fontSize(12).fontColor('#c9a45c')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 4, bottom: 10 })

      Grid() {
        ForEach(this.kinds, (k: string, idx: number) => {
          GridItem() {
            this.card(k, idx)
          }
        }, (k: string) => k)
      }
      .columnsTemplate(this.colsTemplate())
      .columnsGap(16).rowsGap(16)
      .width('100%').layoutWeight(1)
      .padding({ left: 20, right: 20 })

      // 成就列表区（14 项，可滚动；每项名／说明／进度／已达成态）
      Text($r('app.string.ach_list_title'))
        .fontSize(13).fontColor('#c9a45c')
        .width('100%').padding({ left: 20, right: 20, top: 6, bottom: 6 })
      Scroll() {
        Column({ space: 6 }) {
          ForEach(ACHIEVEMENTS, (d: AchievementDef) => {
            this.achRow(d.id)
          }, (d: AchievementDef) => d.id)
        }
        .width('100%').padding({ left: 20, right: 20, bottom: 12 })
      }
      .scrollBar(BarState.Off)
      .width('100%').height(250)
    }
    .width('100%').height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      PageShell({
        widthVp: this.widthVp,
        heightVp: this.heightVp,
        title: $r('app.string.page_collection'),
        onBack: () => { this.onBack(); },
        subtitle: $r('app.string.guide_collection_hint'),
        showSubtitle: true,
        content: (): void => { this.body() },
      })
      // D3：锁定提示改顶部下滑条（3 秒自动消失、点按关闭）
      HintBar({
        text: this.hintText === null ? '' : this.hintText,
        nonce: this.hintNonce,
        topInset: 44,
        onDismiss: () => { this.hintText = null; },
      })
    }
    .width(this.widthVp).height(this.heightVp)
  }
}

/** Collection 页首次引导（与功能同处一源；文案键见 string.json）。 */
export function guideStepsForCollection(): GuideStep[] {
  return [
    { text: $r('app.string.guide_collection_1') },
    { text: $r('app.string.guide_collection_2') },
    { text: $r('app.string.guide_collection_3') },
  ];
}
