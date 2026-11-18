/**
 * 批 35（26 号稿「修正口径」）· 字车总成容器。
 *
 * 核心口径（用户 2026-11-18 binding）：
 *  - 字车是一个容器，纸／滚筒／卷曲／横尺／色带／压纸杆／拨杆／旋钮同属一个容器、同一次位移；
 *  - 容器内以「字车中心＝滚筒中心＝纸中心」为 0：V=0 时容器中心 266vp，纸左缘 156vp，纸宽 220vp，
 *    滚筒宽 277.2vp（−138.6～＋138.6），滚筒中心 y 104vp；
 *  - 打字时容器整体左移（每字约 7vp），行末中心 101vp（纸左缘 −9vp）；
 *  - 滚筒中心＝纸中心（批 34 的「滚筒按机中心 181、纸按落字点 156」错位 85vp 作废）。
 *
 * 所有零件用「V=0 时的屏幕坐标」写在容器里，整容器用 translate({x: offsetXVp}) 一次位移——
 * 不存在第二套独立定位。
 */
import { MachineKind } from '../../model/DocModel';
import { PaperPanel26, TriMark26, BRASS, BRASS_HI } from './Parts26';

/** 字车中心（V=0，vp）＝滚筒中心＝纸中心。 */
const CX0: number = 266;
/** 滚筒宽（vp）。 */
const ROLLER_W: number = 277.2;
/** 纸宽（vp）与纸左缘（V=0）。 */
const PAPER_W: number = 220;
const PAPER_LEFT: number = 156;
/** 滚筒：中心 y 104、可见高 88（y 60–148）。 */
const ROLLER_Y: number = 60;
const ROLLER_H: number = 88;
/** 横尺／色带／压纸杆。 */
const RULER_Y: number = 356;
const RIBBON_Y: number = 370;

/** paper-curl-v2.png（1400×277）实测：纸部分 x 308–1089（宽 781px，居中）。 */
const CURL_IMG_W: number = 1400;
const CURL_IMG_H: number = 277;
const CURL_PAPER_X0: number = 308;
const CURL_PAPER_X1: number = 1089;

@Component
export struct Carriage26 {
  @Prop machine: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop widthVp: number = 362.7;
  @Prop heightVp: number = 822.5;
  @Prop sx: number = 1;
  @Prop sy: number = 1;
  /** 字车行程 V（vp，0 → −165）。 */
  @Prop offsetXVp: number = 0;
  @Prop leverAngle: number = 0;
  @Prop knobAngle: number = 0;
  @Prop strikePhase: number = 0;
  @Prop knobDVp: number = 46.5;
  /** 边铃状态（开＝直立＋红点）。 */
  @Prop soundOn: boolean = true;

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
  @Prop docTitle: string = '';
  /** 批 43：装纸/出纸的纸位移（0＝到位；−362＝整张在屏幕上方）。 */
  @Prop paperSlideVp: number = 0;
  /** 批 43：标题/光标不透明度（纸到位后才淡入）。 */
  @Prop contentOpacity: number = 1;
  @Prop pageNo: string = '';

  // ---- 交互 ----
  onKnob: () => void = (): void => {};
  onLeverTap: () => void = (): void => {};
  onLeverStart: () => void = (): void => {};
  onLeverUpdate: (dy: number) => void = (_dy: number): void => {};
  onLeverEnd: () => void = (): void => {};

  /** 字车中心（V=0 局部坐标）。 */
  private cx(): number {
    return CX0 * this.sx;
  }

  /** 卷曲：按「纸部分＝220vp」换算整图尺寸（等比，不裁弧）。 */
  private curlScale(): number {
    const paperPx: number = CURL_PAPER_X1 - CURL_PAPER_X0;
    return (PAPER_W * this.sx) / paperPx;
  }

  private curlW(): number {
    return CURL_IMG_W * this.curlScale();
  }

  private curlH(): number {
    return CURL_IMG_H * this.curlScale();
  }

  /** 卷曲左缘：让图片里的纸部分左缘落在纸左缘。 */
  private curlLeft(): number {
    return PAPER_LEFT * this.sx - CURL_PAPER_X0 * this.curlScale();
  }

  /** 卷曲顶：图片下沿＝滚筒下沿（paper-curl-v2 是裁到滚筒底缘的成品条）。 */
  private curlTop(): number {
    return (ROLLER_Y + ROLLER_H) * this.sy - this.curlH();
  }

  /** 横尺刻度（每 4vp 一根，覆盖 700vp 宽）。 */
  private rulerTicksPath(): string {
    let d: string = '';
    const w: number = 700 * this.sx;
    let x: number = 6 * this.sx;
    while (x < w) {
      d += 'M' + x.toFixed(1) + ' 0 V' + (5 * this.sy).toFixed(1) + ' ';
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

  /** 锯齿边（齿高 3vp、齿宽 4vp，覆盖 700vp 宽）。 */
  private sawPath(): string {
    const maxX: number = 700 * this.sx;
    const w: number = 4 * this.sx;
    const h: number = 3 * this.sy;
    let d: string = 'M0 0';
    let x: number = 0;
    while (x < maxX) {
      d += ' L' + (x + w / 2).toFixed(1) + ' ' + h.toFixed(1) + ' L' + (x + w).toFixed(1) + ' 0';
      x += w;
    }
    return d;
  }

  /** 横尺上的红三角（左右边距标记，随纸走）。 */
  private triPath(): string {
    return 'M0 0 L' + (7 * this.sx).toFixed(1) + ' 0 L' + (3.5 * this.sx).toFixed(1) + ' ' + (6 * this.sy).toFixed(1) + ' Z';
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // ---- 活纸（连续纸条，行文随字车上移）----
      PaperPanel26({
        widthVp: PAPER_W * this.sx,
        heightVp: 306.4 * this.sy,
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
        docTitle: this.docTitle,
        contentOpacity: this.contentOpacity,
        pageNo: this.pageNo,
      })
        .id('p35_paper')
          .hitTestBehavior(HitTestMode.None)
        .position({ x: PAPER_LEFT * this.sx, y: 56 * this.sy + this.paperSlideVp })
        // 批 39 修订：滚筒删除后纸顶＝干净直边；只加一条极淡的上缘阴影（1.5vp、黑 8%）
        Column().width(PAPER_W * this.sx).height(1.5 * this.sy)
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [['#00000014', 0.0], ['#00000000', 1.0]],
          })
          .shadow({ radius: 11, color: '#00000040', offsetX: 0, offsetY: 3 })

      // ---- 横尺（700vp 宽，随机宽覆盖；随字车移动）----
      Stack({ alignContent: Alignment.TopStart }) {
        Column().width(700 * this.sx).height(12 * this.sy)
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [['#e6e6e8', 0.0], ['#b4b4b4', 0.45], ['#7d7d80', 1.0]],
          })
          .position({ x: 0, y: 0 })
        Path({ commands: this.rulerTicksPath() })
          .stroke('#3d3d40').strokeWidth(0.8).fillOpacity(0)
          .width(700 * this.sx).height(12 * this.sy)
          .position({ x: 0, y: 0 })
        // 两个边距红三角（纸左缘 156／纸右缘 376；与中央指针 181 分明）
        TriMark26({ w: 7, h: 6, sx: this.sx, sy: this.sy })
          .position({ x: (PAPER_LEFT - (CX0 - 350)) * this.sx - 3.5 * this.sx, y: 4 * this.sy })
        TriMark26({ w: 7, h: 6, sx: this.sx, sy: this.sy })
          .position({ x: (PAPER_LEFT + PAPER_W - (CX0 - 350)) * this.sx - 3.5 * this.sx, y: 4 * this.sy })
        // 锯齿下沿
        // 锯齿下沿（可见三角齿：齿宽 2vp、齿高 3vp、间距 2vp；175 齿覆盖 700vp）
        Row({ space: 2 * this.sx }) {
          ForEach(this.teeth(), (t: number) => {
            Column().width(2 * this.sx).height(3 * this.sy).backgroundColor('#2b2b2f')
          }, (t: number) => 'saw' + t.toString())
        }
        .width(700 * this.sx).height(3 * this.sy)
        .position({ x: 0, y: 9 * this.sy })
      }
      .width(700 * this.sx).height(12 * this.sy)
      .clip(true)
      .position({ x: this.cx() - 350 * this.sx, y: RULER_Y * this.sy })
      .hitTestBehavior(HitTestMode.None)

      // ---- 压纸杆（2vp 细钢杆跨纸宽＋两端小黑轮）----
      Column()
        .width(PAPER_W * this.sx).height(2 * this.sy)
        .linearGradient({ direction: GradientDirection.Bottom, colors: [['#cfcfd2', 0.0], ['#5c5c5f', 1.0]] })
        .position({ x: PAPER_LEFT * this.sx, y: 344 * this.sy })
        .hitTestBehavior(HitTestMode.None)
      Column().width(7 * this.sx).height(7 * this.sx).backgroundColor('#111111')
        .borderRadius(3.5 * this.sx)
        .position({ x: (PAPER_LEFT - 3.5) * this.sx, y: 341.5 * this.sy })
      Column().width(7 * this.sx).height(7 * this.sx).backgroundColor('#111111')
        .borderRadius(3.5 * this.sx)
        .position({ x: (PAPER_LEFT + PAPER_W - 3.5) * this.sx, y: 341.5 * this.sy })


    }
    .width(this.widthVp).height(this.heightVp)
    .translate({ x: this.offsetXVp })
    // 空白处不挡下层的顶区按钮（子件各自可点）
    .hitTestBehavior(HitTestMode.Transparent)
  }

  /** 旋钮直径的横向量纲（与 sx 同源；单列出来避免长表达式）。 */
  private xk2(): number {
    return this.sx;
  }
}
