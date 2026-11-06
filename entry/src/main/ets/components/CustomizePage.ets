/**
 * 回车 · 换装页（§4）+ 沉浸式（§2.10）
 *
 * 四个区上下排布：机器（4 胶囊）/ 纸张（4 纸卡）/ 色带（3 胶囊）/ 字体（17 款分组列表）。
 * 换装即时生效：回调回主屏，纸面与键盘立即换装（不重启、不重建编辑器）。
 */

import { MachineKind, PaperKind, RibbonKind, PaperFont } from '../model/DocModel';
import { MACHINES, PAPERS, RIBBONS, FONTS, FontSpec, MachineSpec, PaperSpec, RibbonSpec } from '../model/MachineCatalog';
import { applyImmersive, Insets } from '../services/Immersive';
import { hilog } from '@kit.PerformanceAnalysisKit';

const MACHINE_LABEL: Record<string, string> = {
  '1920s-upright': '1920s',
  '1930s-portable': '1930s',
  '1950s-streamlined': '1950s',
  '1960s-electric': '1960s',
};

const PAPER_LABEL: Record<string, string> = {
  'LETTER': '信纸', 'MANUSCRIPT': '稿纸', 'POSTCARD': '明信片', 'MEMO': '便签',
};

const GROUP_LABEL: Record<string, string> = {
  'english': '英文打字机体', 'chinese': '中文 宋体 / 楷体 / 仿宋', 'handwriting': '手写体',
};

@Component
export struct CustomizePage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  @Prop machineKind: string = '1920s-upright';
  @Prop paperKind: string = 'LETTER';
  @Prop ribbonKind: string = 'BLACK';
  @Prop fontKind: string = '';
  @State topInset: number = 28;
  @State bottomInset: number = 0;
  @State revealN: number = 0;
  onBack: () => void = (): void => {};
  onPickMachine: (k: string) => void = (): void => {};
  onPickPaper: (k: string) => void = (): void => {};
  onPickRibbon: (k: string) => void = (): void => {};
  onPickFont: (f: string) => void = (): void => {};

  aboutToAppear(): void {
    this.applyInsets();
    for (let i = 0; i < 4; i++) {
      setTimeout(() => { this.revealN = i + 1; }, i * 80);
    }
  }

  private async applyInsets(): Promise<void> {
    const ins: Insets = await applyImmersive(this.getUIContext());
    this.topInset = ins.top;
    this.bottomInset = ins.bottom;
    hilog.info(0x0000, 'Customize', 'insets top=%{public}s bottom=%{public}s',
      ins.top.toFixed(1), ins.bottom.toFixed(1));
  }

  private unlockedMachine(kind: string): boolean {
    return kind === '1920s-upright';
  }

  private groups(): string[] { return ['english', 'chinese', 'handwriting']; }

  private fontsOf(g: string): FontSpec[] {
    const out: FontSpec[] = [];
    for (let i = 0; i < FONTS.length; i++) {
      if (FONTS[i].group === g) { out.push(FONTS[i]); }
    }
    return out;
  }

  @Builder
  sectionTitle(t: string) {
    Text(t).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
      .width('100%').margin({ bottom: 12 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        // §2.10：顶栏顶距 = topInset
        Column().width('100%').height(this.topInset)
        Row() {
          Text('‹').fontSize(26).fontColor('#e8ddc9')
            .width(44).height(44).textAlign(TextAlign.Center)
            .onClick(() => { this.onBack(); })
          Text('换装').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
            .margin({ left: 4 })
        }.width('100%').padding({ left: 12, top: 6, bottom: 6 })

        Scroll() {
          Column() {
            // ① 机器：四枚圆角胶囊
            Column() {
              this.sectionTitle('机器')
              Row() {
                ForEach(MACHINES, (m: MachineSpec) => {
                  Text(MACHINE_LABEL[m.kind as string])
                    .fontSize(14)
                    .fontColor(this.machineKind === (m.kind as string) ? '#241c16' : '#e8ddc9')
                    .textAlign(TextAlign.Center)
                    .layoutWeight(1).height(48)
                    .borderRadius(24)
                    .backgroundColor(this.machineKind === (m.kind as string)
                      ? '#bea05a'
                      : (this.unlockedMachine(m.kind as string) ? '#3c3026' : '#2a241f'))
                    .opacity(this.unlockedMachine(m.kind as string) ? 1 : 0.55)
                    .margin({ right: 10 })
                    .onClick(() => {
                      if (this.unlockedMachine(m.kind as string)) {
                        this.onPickMachine(m.kind as string);
                      }
                    })
                }, (m: MachineSpec) => m.kind as string)
              }.width('100%')
            }
            .width('100%')
            .opacity(this.revealN > 0 ? 1 : 0)
            .animation({ duration: 180, curve: Curve.EaseOut })

            // ② 纸张：四张纸卡
            Column() {
              this.sectionTitle('纸张')
              Row() {
                ForEach(PAPERS, (p: PaperSpec) => {
                  Column() {
                    Image($rawfile(p.textureRawfile))
                      .width('100%').height(74).borderRadius(8).objectFit(ImageFit.Cover)
                      .hitTestBehavior(HitTestMode.None)
                    Text(PAPER_LABEL[p.kind as string]).fontSize(13).fontColor('#2a2118')
                      .margin({ top: 6 })
                      .hitTestBehavior(HitTestMode.None)
                  }
                  .layoutWeight(1).height(120)
                  .borderRadius(12)
                  .backgroundColor('#efe2c9')
                  .border({ width: this.paperKind === (p.kind as string) ? 2 : 0, color: '#c9a45c' })
                  .margin({ right: 10 })
                  .onClick(() => { this.onPickPaper(p.kind as string); })
                }, (p: PaperSpec) => p.kind as string)
              }.width('100%')
            }
            .width('100%').margin({ top: 24 })
            .opacity(this.revealN > 1 ? 1 : 0)
            .animation({ duration: 180, curve: Curve.EaseOut })

            // ③ 色带：三枚胶囊
            Column() {
              this.sectionTitle('色带')
              Row() {
                ForEach(RIBBONS, (r: RibbonSpec) => {
                  Text('')
                    .layoutWeight(1).height(48)
                    .borderRadius(24)
                    .backgroundColor(r.inkColor)
                    .border({ width: this.ribbonKind === (r.kind as string) ? 2 : 0, color: '#c9a45c' })
                    .margin({ right: 10 })
                    .onClick(() => { this.onPickRibbon(r.kind as string); })
                }, (r: RibbonSpec) => r.kind as string)
              }.width('100%')
            }
            .width('100%').margin({ top: 24 })
            .opacity(this.revealN > 2 ? 1 : 0)
            .animation({ duration: 180, curve: Curve.EaseOut })

            // ④ 字体：17 款分组列表
            Column() {
              this.sectionTitle('字体')
              ForEach(this.groups(), (g: string) => {
                Text(GROUP_LABEL[g]).fontSize(12).fontColor('rgba(232,221,201,0.5)')
                  .width('100%').margin({ top: 12, bottom: 6 })
                ForEach(this.fontsOf(g), (f: FontSpec) => {
                  Row() {
                    Text(f.sample).fontSize(17)
                      .fontFamily(f.familyName)
                      .fontColor('#e8ddc9')
                      .width(56)
                    Text(f.familyName).fontSize(15).fontColor('rgba(232,221,201,0.75)')
                    Blank()
                    if (this.fontKind === (f.font as string)) {
                      Text('✓').fontSize(17).fontColor('#c9a45c')
                    }
                  }
                  .width('100%').height(52).borderRadius(12)
                  .padding({ left: 14, right: 14 })
                  .backgroundColor(this.fontKind === (f.font as string) ? '#3c3026' : '#2a241f')
                  .margin({ bottom: 6 })
                  .onClick(() => { this.onPickFont(f.font as string); })
                }, (f: FontSpec) => f.font as string)
              }, (g: string) => g)
            }
            .width('100%').margin({ top: 24 })
            .opacity(this.revealN > 3 ? 1 : 0)
            .animation({ duration: 180, curve: Curve.EaseOut })

            Column().width('100%').height(this.bottomInset)
          }
          .width('100%').padding({ left: 20, right: 20 })
        }
        .layoutWeight(1).width('100%').scrollBar(BarState.Off)
      }
      .width('100%').height('100%')
    }
    .width(this.widthVp).height(this.heightVp)
    .linearGradient({ direction: GradientDirection.Bottom,
      colors: [['#171310', 0.0], ['#241c16', 1.0]] })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
