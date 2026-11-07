/**
 * 回车 · 设置页（§6.1）+ 沉浸式（§2.10）
 *
 * 5 组分组列表（声音 / 触感 / 修正方式 / 默认 / 关于），组标题 12vp 灰，
 * 行高 52vp、1vp 分割线 #3c342c、左右 20vp，整页可滚动；
 * 底部常驻「完全离线…」12vp 灰。
 */

import { applyImmersive, Insets } from '../services/Immersive';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Component
export struct SettingsPage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  @Prop machineLabel: string = '1920s';
  @Prop paperLabel: string = '信纸';
  @State topInset: number = 28;
  @State bottomInset: number = 0;
  @State volume: number = 70;
  @State newlineSound: boolean = true;
  @State keyVibrate: boolean = true;
  @State deleteMode: string = '现代删除';
  @State revealN: number = 0;
  onBack: () => void = (): void => {};

  aboutToAppear(): void {
    this.applyInsets();
    this.revealN = 0;
    setTimeout(() => { this.revealN = 6; }, 30);
  }

  private async applyInsets(): Promise<void> {
    const ins: Insets = await applyImmersive(this.getUIContext());
    this.topInset = ins.top;
    this.bottomInset = ins.bottom;
    hilog.info(0x0000, 'Settings', 'insets top=%{public}s bottom=%{public}s',
      ins.top.toFixed(1), ins.bottom.toFixed(1));
  }

  @Builder
  groupTitle(t: string) {
    Text(t).fontSize(12).fontColor('rgba(232,221,201,0.45)')
      .width('100%').margin({ top: 24, bottom: 6 })
  }

  @Builder
  divider() {
    Column().width('100%').height(1).backgroundColor('#3c342c')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Column().width('100%').height(this.topInset)
        Row() {
          Text('‹').fontSize(26).fontColor('#e8ddc9')
            .width(44).height(44).textAlign(TextAlign.Center)
            .onClick(() => { this.onBack(); })
          Text('设置').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
            .margin({ left: 4 })
        }.width('100%').padding({ left: 12, top: 6, bottom: 6 })

        Scroll() {
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
              Text(this.newlineSound ? '开' : '关').fontSize(14).fontColor('#c9a45c')
                .animation({ duration: 150 })
                .onClick(() => { this.newlineSound = !this.newlineSound; })
            }.width('100%').height(52)

            this.groupTitle('触感')
            Row() {
              Text('按键震动').fontSize(15).fontColor('#e8ddc9')
              Blank()
              Text(this.keyVibrate ? '开' : '关').fontSize(14).fontColor('#c9a45c')
                .animation({ duration: 150 })
                .onClick(() => { this.keyVibrate = !this.keyVibrate; })
            }.width('100%').height(52)

            this.groupTitle('修正方式')
            Row() {
              Text('删除方式').fontSize(15).fontColor('#e8ddc9')
              Blank()
              Text(this.deleteMode + ' ›').fontSize(14).fontColor('rgba(232,221,201,0.6)')
            }.width('100%').height(52)
              .onClick(() => {
                this.deleteMode = this.deleteMode === '现代删除' ? 'XXX 覆盖' : '现代删除';
              })
            this.divider()

            this.groupTitle('默认')
            Row() {
              Text('默认机器').fontSize(15).fontColor('#e8ddc9')
              Blank()
              Text(this.machineLabel + ' ›').fontSize(14).fontColor('rgba(232,221,201,0.6)')
            }.width('100%').height(52)
            this.divider()
            Row() {
              Text('默认纸张').fontSize(15).fontColor('#e8ddc9')
              Blank()
              Text(this.paperLabel + ' ›').fontSize(14).fontColor('rgba(232,221,201,0.6)')
            }.width('100%').height(52)

            this.groupTitle('关于')
            Row() {
              Text('音效致谢').fontSize(15).fontColor('#e8ddc9')
              Blank()
              Text('›').fontSize(14).fontColor('rgba(232,221,201,0.6)')
            }.width('100%').height(52)
            this.divider()
            Row() {
              Text('版本').fontSize(15).fontColor('#e8ddc9')
              Blank()
              Text('1.0.0').fontSize(14).fontColor('rgba(232,221,201,0.4)')
            }.width('100%').height(52)

            Column().width('100%').height(24)
          }
          .width('100%').padding({ left: 20, right: 20 })
          .opacity(this.revealN > 0 ? 1 : 0)
          .animation({ duration: 200, curve: Curve.EaseOut })
        }
        .layoutWeight(1).width('100%').scrollBar(BarState.Off)

        Text('完全离线：文档与按键数据只存本地，不收集、不上传。')
          .fontSize(12).fontColor('rgba(232,221,201,0.4)')
          .width('100%').textAlign(TextAlign.Center)
          .margin({ top: 8, bottom: this.bottomInset + 10 })
      }
      .width('100%').height('100%')
    }
    .width(this.widthVp).height(this.heightVp)
    .linearGradient({ direction: GradientDirection.Bottom,
      colors: [['#171310', 0.0], ['#241c16', 1.0]] })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
