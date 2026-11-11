/**
 * 回车 · 拼音设置页（设计稿 §11.6）
 *
 * 模糊拼音开关 / 我的词库（添加＋管理）/ 清除学习记录 / 词库信息。
 * 走 PageShell（§2.10 沉浸式）；进出走 Index 导航栈。
 */

import { PageShell } from './PageShell';
import { AppDialog } from './AppDialog';
import { AppIcon } from './AppIcon';
import { SettingsRow } from './SettingsRow';
import { SpotlightStep } from './SpotlightOverlay';

@Component
export struct PinyinSettingsPage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  @Prop fuzzyOn: boolean = false;
  @Prop userWords: string[] = [];
  @Prop dictInfo: string = '';
  @Prop learnCount: number = 0;
  /** 第 2 批 F15：候选栏选项。 */
  @Prop candidateCount: number = 9;
  @Prop candidateSize: number = 15;
  onCandidateCount: (n: number) => void = (n: number): void => {};
  onCandidateSize: (n: number) => void = (n: number): void => {};
  @State managing: boolean = false;
  @State adding: boolean = false;
  @State draftWord: string = '';
  @State revealN: number = 0;
  @State pressKey: string = '';
  onBack: () => void = (): void => {};
  onToggleFuzzy: () => void = (): void => {};
  /** 加词弹窗里可编辑的拼音串（§13 第 5 步 b） */
  @Prop addPinyin: string = '';
  onWordChanged: (w: string) => void = (): void => {};
  onPinyinEdited: (p: string) => void = (): void => {};
  onAddWord: (w: string, py: string) => void = (): void => {};
  onDeleteWord: (w: string) => void = (): void => {};
  onClearLearn: () => void = (): void => {};

  aboutToAppear(): void {
    this.revealN = 0;
    setTimeout(() => { this.revealN = 1; }, 60);
  }

  @Builder
  body() {
    Scroll() {
      Column() {
        Text('候选栏').fontSize(12).fontColor('rgba(232,221,201,0.6)')
          .width('100%').margin({ top: 18, bottom: 6 })
        SettingsRow({
          label: '候选数量',
          mode: 'slider',
          sliderValue: this.candidateCount,
          sliderMin: 5,
          sliderMax: 15,
          sliderStep: 1,
          onSlide: (v: number): void => { this.onCandidateCount(v); },
        })
        Column().width('100%').height(1).backgroundColor('rgba(232,221,201,0.12)')
        SettingsRow({
          label: '候选字号',
          mode: 'slider',
          sliderValue: this.candidateSize,
          sliderMin: 12,
          sliderMax: 20,
          sliderStep: 1,
          onSlide: (v: number): void => { this.onCandidateSize(v); },
        })
        Column().width('100%').height(1).backgroundColor('rgba(232,221,201,0.12)')

        Text('模糊拼音').fontSize(12).fontColor('rgba(232,221,201,0.6)')
          .width('100%').margin({ top: 18, bottom: 6 })
        Row() {
          Text('模糊拼音').fontSize(15).fontColor('#e8ddc9')
          Blank()
          Text(this.fuzzyOn ? '开' : '关').fontSize(15).fontColor('rgba(232,221,201,0.6)')
        }
        .width('100%').height(52)
        .scale({ x: this.pressKey === 'fuzzy' ? 0.97 : 1, y: this.pressKey === 'fuzzy' ? 0.97 : 1 })
        .animation({ duration: 120, curve: Curve.EaseOut })
        .onClick(() => {
          this.pressKey = 'fuzzy';
          setTimeout(() => { this.pressKey = ''; }, 120);
          this.onToggleFuzzy();
        })
        Text('zh↔z、ch↔c、sh↔s、in↔ing、en↔eng、an↔ang、n↔l、f↔h')
          .fontSize(12).fontColor('rgba(232,221,201,0.4)').width('100%')
        Column().width('100%').height(1).backgroundColor('rgba(232,221,201,0.12)')
          .margin({ top: 6 })

        Text('我的词库').fontSize(12).fontColor('rgba(232,221,201,0.6)')
          .width('100%').margin({ top: 18, bottom: 6 })
        Row() {
          Text('添加词组').fontSize(15).fontColor('#e8ddc9')
          Blank()
          AppIcon({ kind: 'chevron', iconSize: 18, color: 'rgba(232,221,201,0.6)' })
        }
        .width('100%').height(52)
        .onClick(() => { this.draftWord = ''; this.adding = true; })
        Row() {
          Text('管理我的词库').fontSize(15).fontColor('#e8ddc9')
          Blank()
          Text(this.userWords.length.toString() + ' 条').fontSize(15).fontColor('rgba(232,221,201,0.6)')
          AppIcon({ kind: 'chevron', iconSize: 18, color: 'rgba(232,221,201,0.6)' }).margin({ left: 6 })
        }
        .width('100%').height(52)
        .onClick(() => { this.managing = true; })
        Column().width('100%').height(1).backgroundColor('rgba(232,221,201,0.12)')

        Text('学习记录').fontSize(12).fontColor('rgba(232,221,201,0.6)')
          .width('100%').margin({ top: 18, bottom: 6 })
        Row() {
          Text('清除学习与联想记录').fontSize(15).fontColor('#e8ddc9')
          Blank()
          Text(this.learnCount.toString() + ' 条').fontSize(15).fontColor('rgba(232,221,201,0.6)')
        }
        .width('100%').height(52)
        .onClick(() => { this.onClearLearn(); })
        Column().width('100%').height(1).backgroundColor('rgba(232,221,201,0.12)')

        Text('词库信息').fontSize(12).fontColor('rgba(232,221,201,0.6)')
          .width('100%').margin({ top: 18, bottom: 6 })
        Text(this.dictInfo).fontSize(12).fontColor('rgba(232,221,201,0.6)')
          .width('100%').margin({ bottom: 24 })
      }
      .width('100%').padding({ left: 20, right: 20 })
      .opacity(this.revealN > 0 ? 1 : 0)
      .animation({ duration: 180, curve: Curve.EaseOut })
    }
    .layoutWeight(1).width('100%').scrollBar(BarState.Off)
  }

  build() {
    Stack() {
      PageShell({
        guidePage: 'pinyin_settings',
        widthVp: this.widthVp,
        heightVp: this.heightVp,
        title: '拼音设置',
        onBack: (): void => { this.onBack(); },
        subtitle: $r('app.string.guide_pinyin_settings_hint'),
        showSubtitle: true,
        content: (): void => { this.body() },
      })

      AppDialog({
        visible: this.adding, widthVp: this.widthVp, heightVp: this.heightVp,
        onClose: (): void => { this.adding = false; },
        content: (): void => { this.addDialog() },
      })

      AppDialog({
        visible: this.managing, widthVp: this.widthVp, heightVp: this.heightVp,
        onClose: (): void => { this.managing = false; },
        content: (): void => { this.manageDialog() },
      })
    }
    .width(this.widthVp).height(this.heightVp)
  }

  @Builder
  addDialog() {
    Column() {
      Text('添加词组').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
      TextInput({ placeholder: '输入中文词组' })
        .fontSize(15).fontColor('#e8ddc9').margin({ top: 14 })
        .defaultFocus(true)
        .onChange((v: string) => {
          this.draftWord = v;
          this.onWordChanged(v);
        })
      Text('拼音（可改）').fontSize(12).fontColor('rgba(232,221,201,0.6)')
        .width('100%').margin({ top: 10 })
      TextInput({ placeholder: '如 dalongzhuazi', text: this.addPinyin })
        .fontSize(15).fontColor('#e8ddc9').margin({ top: 4 })
        .onChange((v: string) => { this.onPinyinEdited(v); })
      Row() {
        Text('取消').fontSize(15).fontColor('rgba(232,221,201,0.6)')
          .onClick(() => { this.adding = false; })
        Blank()
        Text('添加').fontSize(15).fontColor('#c9a45c')
          .onClick(() => {
            const w: string = this.draftWord.trim();
            if (w.length > 0) { this.onAddWord(w, this.addPinyin); }
            this.adding = false;
          })
      }.width('100%').margin({ top: 20 })
    }.width('100%')
  }

  @Builder
  manageDialog() {
    Column() {
      Text('我的词库').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
      if (this.userWords.length === 0) {
        Text('还没有自定义词组').fontSize(15).fontColor('rgba(232,221,201,0.4)')
          .margin({ top: 16 })
      } else {
        Scroll() {
          Column() {
            ForEach(this.userWords, (w: string) => {
              Row() {
                Text(w).fontSize(15).fontColor('#e8ddc9')
                Blank()
                AppIcon({ kind: 'delete', iconSize: 18, color: '#a33327' })
              }
              .width('100%').height(44)
              .onClick(() => { this.onDeleteWord(w); })
            }, (w: string) => w)
          }.width('100%')
        }
        .height(this.userWords.length > 6 ? 240 : this.userWords.length * 44)
        .scrollBar(BarState.Off)
        .margin({ top: 10 })
      }
      Row() {
        Blank()
        Text('完成').fontSize(15).fontColor('#c9a45c')
          .onClick(() => { this.managing = false; })
      }.width('100%').margin({ top: 16 })
    }.width('100%')
  }
}

/** PinyinSettings 页首次引导（与功能同处一源；文案键见 string.json）。 */
export function guideStepsForPinyinSettings(): SpotlightStep[] {
  return [
    { text: $r('app.string.guide_pinyin_settings_1'), anchorId: 'pinyin__engine' },
    { text: $r('app.string.guide_pinyin_settings_2'), anchorId: 'pinyin__candidate' },
    { text: $r('app.string.guide_pinyin_settings_3'), anchorId: 'pinyin__userwords' },
  ];
}
