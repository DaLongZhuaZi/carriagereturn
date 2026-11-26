/**
 * 回车 · 换装页（§4）+ 沉浸式（§2.10）
 *
 * 四个区上下排布：机器（4 胶囊）/ 纸张（4 纸卡）/ 色带（3 胶囊）/ 字体（17 款分组列表）。
 * 换装即时生效：回调回主屏，纸面与键盘立即换装（不重启、不重建编辑器）。
 */

import { MachineKind, PaperKind, RibbonKind, PaperFont } from '../model/DocModel';
import { MACHINES, PAPERS, RIBBONS, FONTS, FontSpec, MachineSpec, PaperSpec, RibbonSpec } from '../model/MachineCatalog';
import { FONT_SIZE_MIN, FONT_SIZE_MAX, FONT_SIZE_FALLBACK } from '../model/CustomizeCore';
import { PageShell } from './PageShell';
import { AppIcon } from './AppIcon';
import { SettingsRow } from './SettingsRow';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SpotlightStep } from './SpotlightOverlay';
// 第 27 批（批 4）：标准件变体读写与登记
import { CustomizeStore } from '../services/CustomizeStore';
import { PART_VARIANTS, PartVariantSpec } from '../model/PartVariants';

/** 换装页「标准件」分区只展示可切的四件（其余六件本批无变体或由既有入口驱动）。 */
const PART_ROWS: string[] = ['key-grid', 'basket', 'knob', 'body-panel'];

/** 第 23 批（19 号稿 §4-7）：机型页动画模式四行。 */
interface AnimModeRow {
  machine: string;
  label: string;
  noteReal: string;
  noteSim: string;
  electric: boolean;
}

const ANIM_MODE_ROWS: AnimModeRow[] = [
  { machine: '1920s-upright', label: '1920s 直立式', noteReal: '写实：纸筒带纸全幅，拱固定', noteSim: '模拟：拱移动，纸筒小幅', electric: false },
  { machine: '1930s-portable', label: '1930s 便携式', noteReal: '写实：纸筒带纸全幅，拱固定', noteSim: '模拟：拱移动，纸筒小幅', electric: false },
  { machine: '1950s-streamlined', label: '1950s 流线型', noteReal: '写实：纸筒带纸全幅，拱固定', noteSim: '模拟：拱移动，纸筒小幅', electric: false },
  { machine: '1960s-electric', label: '1960s 电动式', noteReal: '电动单套动画：纸筒全幅、拱固定、回位 150ms', noteSim: '电动单套动画', electric: true },
];
const MACHINE_LABEL: Record<string, string> = {
  '1920s-upright': '1920s',
  '1930s-portable': '1930s',
  '1950s-streamlined': '1950s',
  '1960s-electric': '1960s',
  // 批 74：第 5 台现代机（不补这行，主题页那颗胶囊是空文本、点不到）
  '2020s-modern': '2020s',
};

const PAPER_LABEL: Record<string, string> = {
  'letter': '信纸', 'manuscript': '稿纸', 'postcard': '明信片', 'memo': '便签',
};

// P2-5：分组标题走 string.json
const GROUP_LABEL: Record<string, Resource> = {
  'english': $r('app.string.font_group_english'),
  'chinese': $r('app.string.font_group_chinese'),
  'handwriting': $r('app.string.font_group_handwriting'),
};

@Component
export struct CustomizePage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  @Prop machineKind: string = '1920s-upright';
  /** 第 27 批：换一件变体（只换 token，几何不动）。 */
  onPickPart: (part: string, value: string) => void = (part: string, value: string): void => {};
  @Prop paperKind: string = 'LETTER';
  @Prop ribbonKind: string = 'BLACK';
  @Prop fontKind: string = '';

  @State revealN: number = 0;
  /** P1-4：注册失败的字体族名（行上标「未加载」，不许静默回落）。 */
  @Prop failedFonts: string[] = [];
  /** 第 2 批 F3：字号（0 = 未设置，沿用 measureStage 现算值）；当前机器。 */
  @Prop @Watch('onFontSizeProp') fontSize: number = 0;
  /** F6/R27：字号回显文本本地即时更新。 */
  @State sizeText: string = '';
  @State sizeValue: number = 0;
  /** 第 2 批 F3：四台机器各自的字体族名（与 MACHINES 同序；空串 = 未设置）。 */
  @Prop machineFonts: string[] = [];
  /** P2-14：点按缩放反馈（0.95／100ms）。 */
  @State pressedKey: string = '';
  onBack: () => void = (): void => {};
  onPickMachine: (k: string) => void = (): void => {};
  /** 第 23 批（19 号稿 §4-7）：三台手动机的模式回显（1920s／1930s／1950s）。 */
  @Prop animModes: string[] = ['realistic', 'realistic', 'realistic'];
  onPickAnimMode: (machine: string, mode: string) => void = (): void => {};
  onPickPaper: (k: string) => void = (): void => {};
  onPickRibbon: (k: string) => void = (): void => {};
  onPickFont: (f: string) => void = (): void => {};
  /** 第 2 批 F3：两个新覆盖层入口 + 字号回调（Index 接线）。 */
  onOpenFontManager: () => void = (): void => {};
  onOpenPaperCustom: () => void = (): void => {};
  onFontSize: (v: number) => void = (v: number): void => {};

  onFontSizeProp(): void {
    this.sizeValue = this.sliderFontSize();
    this.sizeText = this.sliderFontSize().toString();
  }

  aboutToAppear(): void {
    this.sizeValue = this.sliderFontSize();
    this.sizeText = this.sliderFontSize().toString();
    // insets 交给 PageShell；D6：60ms 逐区揭示（原 80ms）
    this.revealN = 0;
    for (let i = 0; i < 4; i++) {
      setTimeout(() => { this.revealN = i + 1; }, i * 60);
    }
  }

  /** 机器永不锁定：第 9 批 F5 起**永久全开**（成就只奖行为、不再开机器；旧「改回按条件判定」的临时口径已作废）。 */
  private unlockedMachine(kind: string): boolean {
    return true;
  }

  private groups(): string[] { return ['english', 'chinese', 'handwriting']; }

  private fontsOf(g: string): FontSpec[] {
    const out: FontSpec[] = [];
    for (let i = 0; i < FONTS.length; i++) {
      if (FONTS[i].group === g) { out.push(FONTS[i]); }
    }
    return out;
  }

  /** 第 2 批 F3：某台机的字体族名（越界返回空串）。 */
  private machineFamily(index: number): string {
    return this.machineFonts.length > index ? this.machineFonts[index] : '';
  }

  /** 字号滑杆显示值：0（未设置）显示回落值，避免滑杆停在范围外。 */
  private sliderFontSize(): number {
    return this.fontSize > 0 ? this.fontSize : FONT_SIZE_FALLBACK;
  }

  @Builder
  sectionTitle(t: string) {
    Text(t).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
      .width('100%').margin({ bottom: 12 })
  }

  @Builder
  body() {
    // 批 63 阶段 0（任务 4／F-6）：字号滑杆移到固定区（顶栏下方、不随列表滚动）。
    // 原位置在 17 款字体之后；行级 onTouch 吞掉竖向拖拽 → 列表滚不到底、平板上不可达。
    Column() {
      SettingsRow({
        label: '字号',
        mode: 'slider',
        sliderValue: this.sizeValue,
        sliderMin: FONT_SIZE_MIN,
        sliderMax: FONT_SIZE_MAX,
        sliderStep: 1,
        sliderValueText: this.sizeText,
        reveal: true,
        onSlide: (v: number): void => {
          const sv: number = Math.round(v);
          this.sizeValue = sv;
          this.sizeText = sv.toString();
          this.onFontSize(sv);
        },
        onSlideLive: (v: number): void => {
          this.sizeValue = Math.round(v);
          this.sizeText = Math.round(v).toString();
        },
      })
      Column().width('100%').height(1).backgroundColor('rgba(232,221,201,0.12)')
    }
    .width('100%')
    .padding({ left: 14, right: 14 })
    .margin({ bottom: 8 })

        Scroll() {
          Column() {
            // 第 2 批 F3：两个覆盖层入口（字体管理 / 纸张自定义）。
            // SettingsRow.label 是 string 类型（SettingsRow 已冻结），文案沿用本页既有写法。
            Column() {
              SettingsRow({
                label: '字体管理',
                mode: 'link',
                value: '',
                reveal: this.revealN > 0,
                onRowClick: (): void => { this.onOpenFontManager(); },
              })
              Column().width('100%').height(1).backgroundColor('rgba(232,221,201,0.12)')
              SettingsRow({
                label: '纸张自定义',
                mode: 'link',
                value: '',
                reveal: this.revealN > 0,
                onRowClick: (): void => { this.onOpenPaperCustom(); },
              })
              Column().width('100%').height(1).backgroundColor('rgba(232,221,201,0.12)')
            }
            .width('100%')
            .id('customize__manage_entry')
            .margin({ bottom: 8 })

            // ① 机器：四枚圆角胶囊
            Column() {
              this.sectionTitle('机器')
              Row() {
                ForEach(MACHINES, (m: MachineSpec) => {
                  Text(MACHINE_LABEL[m.kind as string])
                    .fontSize(15)
                    .fontColor('#e8ddc9')
                    .textAlign(TextAlign.Center)
                    .layoutWeight(1).height(48)
                    .borderRadius(28)
                    // D7：选中态统一 2vp 金描边 + #2e2620 底（金底作废）
                    .backgroundColor(this.machineKind === (m.kind as string) ? '#2e2620' : '#241c16')
                    .border({ width: this.machineKind === (m.kind as string) ? 2 : 0, color: '#c9a45c' })
                    .opacity(this.unlockedMachine(m.kind as string) ? 1 : 0.55)
                    // D4：按压统一 0.97 / 120ms
                    .scale({ x: this.pressedKey === (m.kind as string) ? 0.97 : 1,
                      y: this.pressedKey === (m.kind as string) ? 0.97 : 1 })
                    .animation({ duration: 120, curve: Curve.EaseOut })
                    .onTouch((e: TouchEvent) => {
                      const k: string = m.kind as string;
                      if (e.type === TouchType.Down) {
                        this.pressedKey = k;
                      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
                        this.pressedKey = '';
                      }
                    })
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
            .id('customize__machine')
            .opacity(this.revealN > 0 ? 1 : 0)
            .animation({ duration: 180, curve: Curve.EaseOut })

            // ② 动画模式（第 23 批／19 号稿 §4-7）：每机一行；1960s 行写「电动单套」，不留空
            Column() {
              this.sectionTitle('动画')
              ForEach(ANIM_MODE_ROWS, (r: AnimModeRow, i: number) => {
                Column() {
                  Row() {
                    Text(r.label).fontSize(13).fontColor('#1a1a1a').layoutWeight(1)
                      .hitTestBehavior(HitTestMode.None)
                    if (r.electric) {
                      Text('电动单套').fontSize(12).fontColor('#6b6156')
                        .hitTestBehavior(HitTestMode.None)
                    } else {
                      Row() {
                        Text('写实').fontSize(12)
                          .fontColor(this.modeAt(i) === 'realistic' ? '#1a1a1a' : '#8a7f70')
                          .padding({ left: 10, right: 10, top: 4, bottom: 4 }).borderRadius(8)
                          .backgroundColor(this.modeAt(i) === 'realistic' ? '#e6d3ad' : '#f3ece0')
                          .onClick(() => { this.onPickAnimMode(r.machine, 'realistic'); })
                        Text('模拟').fontSize(12)
                          .fontColor(this.modeAt(i) === 'simulated' ? '#1a1a1a' : '#8a7f70')
                          .padding({ left: 10, right: 10, top: 4, bottom: 4 }).borderRadius(8)
                          .backgroundColor(this.modeAt(i) === 'simulated' ? '#e6d3ad' : '#f3ece0')
                          .margin({ left: 6 })
                          .onClick(() => { this.onPickAnimMode(r.machine, 'simulated'); })
                      }
                    }
                  }.width('100%')
                  Text(r.electric ? r.noteReal : (this.modeAt(i) === 'simulated' ? r.noteSim : r.noteReal))
                    .fontSize(11).fontColor('#6b6156').margin({ top: 3 })
                    .hitTestBehavior(HitTestMode.None)
                }.width('100%').margin({ top: 10 })
              }, (r: AnimModeRow, idx: number) => r.machine + ':' + this.modeAt(idx))
            }
            .width('100%').margin({ top: 24 })
            .opacity(this.revealN > 0 ? 1 : 0)

            // ①b 第 27 批（批 4）：标准件变体（按区域换 token；换一件、其余九件不动）
            Column() {
              this.sectionTitle('标准件')
              ForEach(PART_ROWS, (part: string) => {
                Column() {
                  Text(part === 'key-grid' ? '键盘帽形' : (part === 'basket' ? '字篮风格'
                    : (part === 'knob' ? '旋钮面' : '机身配色')))
                    .fontSize(13).fontColor('#8a7f70').width('100%')
                    .hitTestBehavior(HitTestMode.None)
                  Row() {
                    ForEach(PART_VARIANTS.filter((s: PartVariantSpec) => s.part === part)[0].values,
                      (v: string) => {
                        Text(v)
                          .fontSize(12)
                          .fontColor(CustomizeStore.partVariant(part, this.machineKind) === v ? '#1a1a1a' : '#8a7f70')
                          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                          .borderRadius(10)
                          .backgroundColor(CustomizeStore.partVariant(part, this.machineKind) === v ? '#c9a45c' : '#f3ead8')
                          .margin({ right: 8 })
                          .onClick(() => { this.onPickPart(part, v); })
                      }, (v: string) => part + ':' + v)
                  }.width('100%').margin({ top: 6 })
                }.width('100%').margin({ top: 10 })
              }, (part: string) => part)
            }
            .width('100%').margin({ top: 24 })
            .opacity(this.revealN > 0 ? 1 : 0)

            // ② 纸张：四张纸卡
            Column() {
              this.sectionTitle('纸张')
              Row() {
                ForEach(PAPERS, (p: PaperSpec) => {
                  Column() {
                    Image($rawfile(p.textureRawfile))
                      .width('100%').height(74).borderRadius(8).objectFit(ImageFit.Cover)
                      .hitTestBehavior(HitTestMode.None)
                    Text(PAPER_LABEL[p.kind as string]).fontSize(12).fontColor('#1a1a1a')
                      .margin({ top: 6 })
                      .hitTestBehavior(HitTestMode.None)
                  }
                  .layoutWeight(1).height(120)
                  .borderRadius(12)
                  .backgroundColor('#eee4ce')
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
                  Text(r.kind === 'black' ? '黑' : (r.kind === 'blue' ? '蓝' : '红'))
                    .fontSize(15).fontColor('#eee4ce').textAlign(TextAlign.Center)
                    .layoutWeight(1).height(48)
                    .borderRadius(28)
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
                Text(GROUP_LABEL[g]).fontSize(12).fontColor('rgba(232,221,201,0.6)')
                  .width('100%').margin({ top: 12, bottom: 6 })
                ForEach(this.fontsOf(g), (f: FontSpec) => {
                  Row() {
                    Text(f.sample).fontSize(17)
                      .fontFamily(f.familyName)
                      .fontColor('#e8ddc9')
                      .width(56)
                    Text(f.familyName).fontSize(15).fontColor('rgba(232,221,201,0.75)')
                    Blank()
                    if (this.failedFonts.indexOf(f.familyName) >= 0) {
                      Text('未加载').fontSize(12).fontColor('#a33327')
                    } else if (this.fontKind === (f.font as string)) {
                      AppIcon({ kind: 'check', iconSize: 17, color: '#c9a45c' })
                    }
                  }
                  .width('100%').height(52).borderRadius(12)
                  .padding({ left: 14, right: 14 })
                  .backgroundColor(this.fontKind === (f.font as string) ? '#2e2620' : '#241c16')
                  .margin({ bottom: 6 })
                  .onClick(() => { this.onPickFont(f.font as string); })
                }, (f: FontSpec) => f.font as string)
              }, (g: string) => g)
            }
            .width('100%').margin({ top: 24 })
            .opacity(this.revealN > 3 ? 1 : 0)
            .animation({ duration: 180, curve: Curve.EaseOut })

            // 第 2 批 F3：字号滑杆 + 每机字体（只读展示；换字体走「字体管理」页）
            Column() {

              Text('每机字体').fontSize(15).fontColor('#e8ddc9')
                .width('100%').margin({ top: 16, bottom: 4 })
              ForEach(MACHINES, (m: MachineSpec, index: number) => {
                Row() {
                  Text(MACHINE_LABEL[m.kind as string]).fontSize(13)
                    .fontColor('rgba(232,221,201,0.6)').width(72)
                  Text(this.machineFamily(index))
                    .fontSize(14)
                    .fontColor('rgba(232,221,201,0.75)')
                    .fontFamily(this.machineFamily(index).length > 0
                      ? this.machineFamily(index) : 'CourierPrime')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                }
                .width('100%').height(34)
              }, (m: MachineSpec) => m.kind as string)
            }
            .width('100%').margin({ top: 24 })
            .opacity(this.revealN > 3 ? 1 : 0)
            .animation({ duration: 180, curve: Curve.EaseOut })

          }
          .width('100%').padding({ left: 20, right: 20 })
        }
        .id('customize__options')
        .layoutWeight(1).width('100%').scrollBar(BarState.Off)
  }

  /** 第 23 批：第 i 行的当前模式（1960s 不在回显数组里，恒写实）。 */
  private modeAt(i: number): string {
    return i < this.animModes.length ? this.animModes[i] : 'realistic';
  }
  build() {
    PageShell({
        guidePage: 'customize',
      widthVp: this.widthVp,
      heightVp: this.heightVp,
      title: $r('app.string.page_customize'),
      onBack: () => { this.onBack(); },
      subtitle: $r('app.string.guide_customize_hint'),
      showSubtitle: true,
      content: (): void => { this.body() },
    })
  }
}

/** Customize 页首次引导（与功能同处一源；文案键见 string.json）。 */
export function guideStepsForCustomize(): SpotlightStep[] {
  return [
    { text: $r('app.string.guide_customize_1'), anchorId: 'customize__machine' },
    { text: $r('app.string.guide_customize_2'), anchorId: 'customize__options' },
    { text: $r('app.string.guide_customize_3'), anchorId: 'customize__manage_entry' },
  ];
}


