/**
 * 批 64（阶段 1 / T3）· 纸区内容容器 Carriage26（flex 化后）
 *
 * 口径（设计稿 §3.3＋§3.4）：
 *  - 本组件是 **纸区（paperZone）** 的内容，不再自带绝对坐标：
 *    纸底由 `justifyContent(FlexAlign.End)` 贴住纸区底部，纸高＝内容高（story：Index 的 paperGrowVp
 *    就是「可见纸高」，31＋lh×行数＋6，封顶 306×Pw/220），纸向上生长。
 *  - 纸宽＝机器宽×0.606（`paperWVp`，Index 传 paperPanelWidthVp() 同源），水平居中于纸区。
 *  - 纸区底部 18vp 是「横尺 12 ＋ 间隙 2 ＋ 色带 4」，纵向 flex 子项排布，不再钉 y=356/370；
 *    纸最大高＋18 ＝ 纸区高，所以纸到顶时纸顶正好落在纸区顶。
 *  - 字车组（纸／压纸杆／指针／横尺）整体 `translate({x: offsetXVp})` 一次位移；
 *    色带是机架固定件（批 36 口径：不随字车），排在字车组之后、不参与 translate。
 *  - 横尺 700·sx 的绘制保留，但外层 `width('100%')`＋`clip(true)` 裁到机器宽（N2：右缘不再越界）。
 */
import { MachineKind } from '../../model/DocModel';
import { PaperPanel26, TriMark26 } from './Parts26';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0xA00100;
const TAG: string = 'Carriage26';

/** 字车中心（V=0，vp）＝旧横尺对位口径。 */
const CX0: number = 266;
/** 纸区底部固定件（vp，手机／平板一致）。 */
const RULER_H: number = 12;
const RIB_GAP: number = 2;
const RIBBON_H: number = 4;
/** 纸区底部三段合计（设计稿 §3.2：纸最大高＋18 ＝ 纸区高）。 */
const BOTTOM_FURNITURE: number = RULER_H + RIB_GAP + RIBBON_H;   // 18

@Component
export struct Carriage26 {
  @Prop machine: MachineKind = MachineKind.UPRIGHT_1920S;
  /** 纸区宽（＝机器宽）。 */
  @Prop machineWVp: number = 475.3;
  /** 纸区高（StageLayout.paperH）。 */
  @Prop zoneHVp: number = 418.6;
  /** 纸宽（＝机器宽×0.606）。 */
  @Prop paperWVp: number = 288.1;
  /** 可见纸高（内容高／装纸生长量，0＝还没出纸）。 */
  @Prop paperHVp: number = 306.4;
  @Prop @Watch('onGeomChange') sx: number = 1;
  @Prop @Watch('onGeomChange') sy: number = 1;
  /** 字车行程 V（vp，0 → −65）。 */
  @Prop offsetXVp: number = 0;

  // ---- 活纸 ----
  @Prop lines: string[] = [];
  @Prop fontSizeVp: number = 11.9;
  @Prop lineHeightVp: number = 21;
  @Prop marginLVp: number = 25;
  @Prop marginRVp: number = 30;
  @Prop marginTVp: number = 12;
  @Prop fontFamily: string = 'CourierPrime';
  @Prop textColor: string = '#1a1a1a';
  @Prop cursorXVp: number = 0;
  @Prop cursorYVp: number = 12;
  @Prop scrollYVp: number = 0;
  @Prop textureRawfile: string = 'paper-letter.png';
  @Prop customPaperColor: string = '';
  @Prop customTextureRawfile: string = '';
  @Prop ruledOn: boolean = false;
  @Prop docTitle: string = '';
  @Prop contentOpacity: number = 1;
  @Prop pageNo: string = '';
  @Prop strikePhase: number = 0;

  /** 批 38（平板竖屏首验）：几何打点——用来对账「纸实际画在哪、多宽」。 */
  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'geom init zone=%{public}sx%{public}s paperW=%{public}s paperH=%{public}s offX=%{public}s',
      this.machineWVp.toFixed(1), this.zoneHVp.toFixed(1),
      this.paperWVp.toFixed(1), this.paperHVp.toFixed(1), this.offsetXVp.toFixed(1));
  }

  onGeomChange(): void {
    hilog.info(DOMAIN, TAG, 'geom change zone=%{public}sx%{public}s paperW=%{public}s paperH=%{public}s offX=%{public}s',
      this.machineWVp.toFixed(1), this.zoneHVp.toFixed(1),
      this.paperWVp.toFixed(1), this.paperHVp.toFixed(1), this.offsetXVp.toFixed(1));
  }

  /** 字车中心（局部，横尺对位用）。 */
  private cx(): number {
    return CX0 * this.sx;
  }

  /** 纸左缘（纸区局部坐标）。 */
  private paperLeft(): number {
    return (this.machineWVp - this.paperWVp) / 2;
  }

  /** 纸区上部（纸可视区）高＝纸区高 − 底部三段。 */
  private paperAreaH(): number {
    const h: number = this.zoneHVp - BOTTOM_FURNITURE;
    return h > 0 ? h : 0;
  }

  /** 可见纸高（clamp ≥0；装纸时从 0 长出来）。 */
  private paperH(): number {
    return this.paperHVp > 0 ? this.paperHVp : 0;
  }

  /** 落字指针 x（字车组局部坐标；不再乘 k、不再加 61 魔法数）。 */
  private strikeX(): number {
    return this.paperLeft() + this.marginLVp + this.cursorXVp;
  }

  /** 横尺刻度（每 4vp 一根，覆盖 700vp 宽）。 */
  private rulerTicksPath(): string {
    let d: string = '';
    const w: number = 700 * this.sx;
    let x: number = 6 * this.sx;
    while (x < w) {
      d += 'M' + x.toFixed(1) + ' 0 V5 ';
      x += 4 * this.sx;
    }
    return d;
  }

  /** 锯齿齿序列（175 齿 × 2vp ＋ 174 缝 × 2vp ＝ 698vp）。 */
  private teeth(): number[] {
    const out: number[] = [];
    for (let i = 0; i < 175; i++) {
      out.push(i);
    }
    return out;
  }

  build() {
    Column() {
      // ---- 字车组（纸／压纸杆／指针／横尺）：整体随字车一次位移 ----
      Column() {
        // 纸视口：纸底贴住这里的底部（justifyContent End），纸向上生长
        Stack({ alignContent: Alignment.TopStart }) {
          Column() {
            // 纸上缘极淡阴影（批 39：滚筒删除后纸顶是干净直边）
            Column().width(this.paperWVp).height(1.5)
              .linearGradient({
                direction: GradientDirection.Bottom,
                colors: [['#00000014', 0.0], ['#00000000', 1.0]],
              })
              .shadow({ radius: 11, color: '#00000040', offsetX: 0, offsetY: 3 })
              .hitTestBehavior(HitTestMode.None)
            // 活纸：纸高＝内容高，底端由 justifyContent(End) 固定
            if (this.paperH() > 0) {
              PaperPanel26({
                widthVp: this.paperWVp,
                heightVp: this.paperH(),
                sx: this.sx, sy: this.sy,
                lines: this.lines,
                fontSizeVp: this.fontSizeVp,
                lineHeightVp: this.lineHeightVp,
                marginLVp: this.marginLVp,
                marginRVp: this.marginRVp,
                marginTVp: this.marginTVp,
                fontFamily: this.fontFamily,
                textColor: this.textColor,
                cursorXVp: this.cursorXVp,
                cursorYVp: this.cursorYVp,
                strikePhase: this.strikePhase,
                scrollYVp: this.scrollYVp,
                textureRawfile: this.textureRawfile,
                customPaperColor: this.customPaperColor,
                customTextureRawfile: this.customTextureRawfile,
                ruledOn: this.ruledOn,
                docTitle: this.docTitle,
                contentOpacity: this.contentOpacity,
                pageNo: this.pageNo,
              })
                .id('p35_paper')
                .hitTestBehavior(HitTestMode.None)
            }
            // 压纸杆（3D 钢杆贴图，压住纸下缘）：作为 flex 子项排在纸下方，负 margin 叠住纸底 4vp
            Image($rawfile('ui-parts/pressbar-steel-v1.png'))
              .width(this.paperWVp).height(4)
              .objectFit(ImageFit.Contain)
              .margin({ top: -4 })
              .hitTestBehavior(HitTestMode.None)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.End)
          .alignItems(HorizontalAlign.Center)

          // 落字指针（跟随光标：纸左缘 ＋ 左边距 ＋ 光标纸内 x ＋ 字车 O；由字车组统一位移）
          Column().width(2).height(10)
            .backgroundColor('#8f8f92')
            .position({ x: this.strikeX(), y: this.paperAreaH() - 15 })
            .animation({ duration: 250, curve: Curve.EaseOut })
            .hitTestBehavior(HitTestMode.None)
          TriMark26({ w: 7, h: 6, sx: 1, sy: 1 })
            .position({ x: this.strikeX() - 3.5, y: this.paperAreaH() - 6 })
            .animation({ duration: 250, curve: Curve.EaseOut })
            .hitTestBehavior(HitTestMode.None)
        }
        .width('100%')
        .height(this.paperAreaH())

        // ---- 横尺（绘制宽 700·sx 保留；外层裁到机器宽，修 N2 越界）----
        Row() {
          Stack({ alignContent: Alignment.TopStart }) {
            // 杆身渐变
            Column().width(700 * this.sx).height(RULER_H)
              .linearGradient({
                direction: GradientDirection.Bottom,
                colors: [['#e6e6e8', 0.0], ['#b4b4b4', 0.45], ['#7d7d80', 1.0]],
              })
              .position({ x: 0, y: 0 })
            // 刻度：175 根，节距 4vp；次刻度 4vp 高／0.8vp 宽，主刻度每 5 根 7vp 高／1.2vp 宽
            Stack({ alignContent: Alignment.TopStart }) {
              ForEach(this.teeth(), (t: number, i: number) => {
                Column()
                  .width((i % 5 === 0 ? 1.2 : 0.8) * this.sx)
                  .height(i % 5 === 0 ? 7 : 4)
                  .backgroundColor(i % 5 === 0 ? '#2b2b2f' : '#3d3d40')
                  .position({ x: (i * 4) * this.sx, y: 0 })
              }, (t: number) => 'tick' + t.toString())
            }
            .width(700 * this.sx).height(RULER_H)
            .position({ x: 0, y: 0 })
            // 两个边距红三角（纸左缘／纸右缘，随纸宽走）
            TriMark26({ w: 7, h: 6, sx: 1, sy: 1 })
              .position({ x: this.paperLeft() - (this.cx() - 350 * this.sx) - 3.5, y: 6 })
            TriMark26({ w: 7, h: 6, sx: 1, sy: 1 })
              .position({ x: this.paperLeft() + this.paperWVp - (this.cx() - 350 * this.sx) - 3.5, y: 6 })
          }
          .width(700 * this.sx).height(RULER_H)
          .translate({ x: this.cx() - 350 * this.sx })
        }
        .width('100%').height(RULER_H)
        .clip(true)
        .hitTestBehavior(HitTestMode.None)
      }
      .width('100%')
      .translate({ x: this.offsetXVp })

      // ---- 色带（机架固定件，不随字车；批 59：静态不上抬）----
      Column().height(RIB_GAP)
      Column()
        .width(346.7 * this.sx).height(RIBBON_H)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [['#a8352f', 0.0], ['#e04a42', 0.35], ['#d23a33', 0.62], ['#8f1f1c', 1.0]],
        })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
    .alignItems(HorizontalAlign.Center)
    // 空白处不挡下层的顶区按钮（子件各自可点）
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
