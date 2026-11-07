/**
 * 回车 · 设置页（§6.1）— 已接入共享 PageShell（D2）
 *
 * 5 组分组列表（声音 / 触感 / 修正方式 / 默认 / 关于），组标题 12vp 灰，
 * 行高 52vp、1vp 分割线、左右 20vp；入场按组 60ms 逐组淡入（D6）。
 */

import { PageShell } from './PageShell';
import { AppIcon } from './AppIcon';

@Component
export struct SettingsPage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  @Prop machineLabel: string = '1920s';
  @Prop paperLabel: string = '信纸';
  /** 中文输入引擎：'builtin' 内置拼音｜'system' 系统输入法（设计稿 §1）。 */
  @Prop cnEngine: string = 'builtin';
  onPickCnEngine: () => void = (): void => {};
  /** §11.6：拼音设置页入口 */
  onOpenPinyinSettings: () => void = (): void => {};
  @State volume: number = 70;
  @State newlineSound: boolean = true;
  @State keyVibrate: boolean = true;
  @State deleteMode: string = '现代删除';
  @State revealN: number = 0;
  /** D4：按压统一 0.97 / 120ms（原 §6.1「底色加深 100ms」作废）。 */
  @State pressedRow: string = '';
  onBack: () => void = (): void => {};

  aboutToAppear(): void {
    // D6：逐组 60ms（原来是 30ms 后一次性 revealN=6）
    this.revealN = 0;
    for (let i = 0; i < 5; i++) {
      setTimeout(() => { this.revealN = i + 1; }, i * 60);
    }
  }

  @Builder
  groupTitle(t: string) {
    Text(t).fontSize(12).fontColor('rgba(232,221,201,0.4)')
      .width('100%').margin({ top: 24, bottom: 6 })
  }

  @Builder
  divider() {
    Column().width('100%').height(1).backgroundColor('rgba(232,221,201,0.4)')
  }

  @Builder
  row(label: string, right: string, rightColor: string, idx: number) {
    Row() {
      Text(label).fontSize(15).fontColor('#e8ddc9')
      Blank()
      Text(right).fontSize(15).fontColor(rightColor)
    }
    .width('100%').height(52)
    .opacity(this.revealN > idx ? 1 : 0)
    .animation({ duration: 180, curve: Curve.EaseOut })
    .scale({ x: this.pressedRow === label ? 0.97 : 1, y: this.pressedRow === label ? 0.97 : 1 })
    .animation({ duration: 120, curve: Curve.EaseOut })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressedRow = label;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressedRow = '';
      }
    })
  }

  @Builder
  body() {
    Scroll() {
      Column() {
        // 1 声音
        Column() {
          this.groupTitle('声音')
          Row() {
            Text('音量').fontSize(15).fontColor('#e8ddc9')
            Blank()
            Slider({ value: this.volume, min: 0, max: 100 })
              .width(180).trackThickness(2).selectedColor('#c9a45c')
              .onChange((v: number, mode: SliderChangeMode) => { this.volume = Math.round(v); })
          }.width('100%').height(52)
          this.divider()
          Row() {
            Text('换行叮声').fontSize(15).fontColor('#e8ddc9')
            Blank()
            Text(this.newlineSound ? '开' : '关').fontSize(15).fontColor('#c9a45c')
              .animation({ duration: 150 })
              .onClick(() => { this.newlineSound = !this.newlineSound; })
          }.width('100%').height(52)
        }
        .width('100%')
        .opacity(this.revealN > 0 ? 1 : 0)
        .animation({ duration: 180, curve: Curve.EaseOut })

        // 2 触感
        Column() {
          this.groupTitle('触感')
          Row() {
            Text('按键震动').fontSize(15).fontColor('#e8ddc9')
            Blank()
            Text(this.keyVibrate ? '开' : '关').fontSize(15).fontColor('#c9a45c')
              .animation({ duration: 150 })
              .onClick(() => { this.keyVibrate = !this.keyVibrate; })
          }.width('100%').height(52)
        }
        .width('100%')
        .opacity(this.revealN > 1 ? 1 : 0)
        .animation({ duration: 180, curve: Curve.EaseOut })

        // 3 修正方式
        Column() {
          this.groupTitle('修正方式')
          Row() {
            Text('删除方式').fontSize(15).fontColor('#e8ddc9')
            Blank()
            Text(this.deleteMode).fontSize(15).fontColor('rgba(232,221,201,0.6)')
          }.width('100%').height(52)
            .onClick(() => {
              this.deleteMode = this.deleteMode === '现代删除' ? 'XXX 覆盖' : '现代删除';
            })
          // 中文输入：内置拼音（默认）｜系统输入法。必须落 AppPreferences（设计稿 §1／§7）
          Row() {
            Text('中文输入').fontSize(15).fontColor('#e8ddc9')
            Blank()
            Text(this.cnEngine === 'builtin' ? '内置拼音' : '系统输入法')
              .fontSize(15).fontColor('rgba(232,221,201,0.6)')
          }.width('100%').height(52)
            .onClick(() => {
              this.onPickCnEngine();
            })
          // 拼音设置（模糊音／我的词库／学习记录／词库信息）：设计稿 §11.6
          Row() {
            Text('拼音设置').fontSize(15).fontColor('#e8ddc9')
            Blank()
            AppIcon({ kind: 'chevron', iconSize: 18, color: 'rgba(232,221,201,0.6)' })
          }.width('100%').height(52)
            .onClick(() => {
              this.onOpenPinyinSettings();
            })
          this.divider()
        }
        .width('100%')
        .opacity(this.revealN > 2 ? 1 : 0)
        .animation({ duration: 180, curve: Curve.EaseOut })

        // 4 默认
        Column() {
          this.groupTitle('默认')
          Row() {
            Text('默认机器').fontSize(15).fontColor('#e8ddc9')
            Blank()
            Text(this.machineLabel).fontSize(15).fontColor('rgba(232,221,201,0.6)')
          }.width('100%').height(52)
          this.divider()
          Row() {
            Text('默认纸张').fontSize(15).fontColor('#e8ddc9')
            Blank()
            Text(this.paperLabel).fontSize(15).fontColor('rgba(232,221,201,0.6)')
          }.width('100%').height(52)
        }
        .width('100%')
        .opacity(this.revealN > 3 ? 1 : 0)
        .animation({ duration: 180, curve: Curve.EaseOut })

        // 5 关于
        Column() {
          this.groupTitle('关于')
          Row() {
            Text('音效致谢').fontSize(15).fontColor('#e8ddc9')
            Blank()
            Text('—').fontSize(15).fontColor('rgba(232,221,201,0.4)')
          }.width('100%').height(52)
          this.divider()
          Row() {
            Text('版本').fontSize(15).fontColor('#e8ddc9')
            Blank()
            Text('1.0.0').fontSize(15).fontColor('rgba(232,221,201,0.4)')
          }.width('100%').height(52)

          Column().width('100%').height(24)
        }
        .width('100%')
        .opacity(this.revealN > 4 ? 1 : 0)
        .animation({ duration: 180, curve: Curve.EaseOut })

        // 底部常驻声明（§6.1）
        Text('完全离线：文档与按键数据只存本地，不收集、不上传。')
          .fontSize(12).fontColor('rgba(232,221,201,0.4)')
          .width('100%').textAlign(TextAlign.Center)
          .margin({ top: 8, bottom: 10 })
      }
      .width('100%').padding({ left: 20, right: 20 })
    }
    .width('100%').height('100%').scrollBar(BarState.Off)
  }

  build() {
    PageShell({
      widthVp: this.widthVp,
      heightVp: this.heightVp,
      title: $r('app.string.page_settings'),
      onBack: () => { this.onBack(); },
      content: (): void => { this.body() },
    })
  }
}
