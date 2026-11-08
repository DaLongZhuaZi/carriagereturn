/**
 * 字车分层（§2.9 纸屏左起算，2026-11-05）
 *
 * 全部 x 从「纸屏左」（布局左 + O）起算：
 *   中央件 x = 纸屏左 + marginH + 已落字总宽 − 中央件宽/2（打击点，随字右移）
 *   压纸卷 x = 纸屏左 − 旋钮直径
 *   左旋钮 x = 纸屏左 − 直径 − 4；右旋钮 x = 纸屏左 + Pw + 4
 *   Hc = Pw×0.17；中央件 Hg = Hc×1.5、宽 = Hg×0.848；旋钮直径 = Hc×0.92
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MachineKind } from '../model/DocModel';

const CDOMAIN: number = 0x0100;
const CTAG: string = 'CarriageLayers';

@Component
export struct CarriageLayers {
  @Prop stageWidth: number = 390;
  /** 纸宽 Pw（vp）。 */
  @Prop paperWidthVp: number = 242;
  /** 纸屏左 = 布局左 + O（vp，相对舞台左缘）。 */
  @Prop paperLeftVp: number = 74;
  /** 打击点 x（= 纸屏左 + marginH + 已落字总宽，相对舞台左缘）。 */
  @Prop strikeXVp: number = 102;
  /** §18.7：滚筒横向偏移（= carriageOffsetVp × 系数 k）。只调滚筒，纸张／压纸卷／中央件仍用满 O */
  @Prop rollerOffsetVp: number = 0;
  /** §4 多机型：机型＋几何参数（按机型取数，不写死） */
  @Prop machineKind: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop rollerWidthRatio: number = 0.9528;
  @Prop baseRailAspect: number = 7.562;
  @Prop basketAspect: number = 4.70;
  @Prop bailRollerLX: number = 0.280;
  @Prop bailRollerRX: number = 0.724;
  @Prop bailRollerY: number = 0.747;
  @Prop centralWindowX: number = 0.500;
  @Prop centralWindowY: number = 0.550;

  /** §4：素材按机型静态分支（$rawfile 只吃编译期常量） */
  private imgBase(): Resource {
    if (this.machineKind === MachineKind.PORTABLE_1930S) {
      return $rawfile('layers/1930s-portable/carriage-base-rail.png');
    }
    return $rawfile('layers/1920s-upright/carriage-base-rail.png');
  }

  private imgBasket(): Resource {
    if (this.machineKind === MachineKind.PORTABLE_1930S) {
      return $rawfile('layers/1930s-portable/typebar-basket-strip.png');
    }
    return $rawfile('layers/1920s-upright/typebar-basket-strip.png');
  }

  private imgBail(): Resource {
    if (this.machineKind === MachineKind.PORTABLE_1930S) {
      return $rawfile('layers/1930s-portable/paper-bail-v2.png');
    }
    return $rawfile('layers/1920s-upright/paper-bail-v2.png');
  }

  private imgCentral(): Resource {
    if (this.machineKind === MachineKind.PORTABLE_1930S) {
      return $rawfile('layers/1930s-portable/central-guide.png');
    }
    return $rawfile('layers/1920s-upright/central-guide.png');
  }

  private imgRoller(): Resource {
    if (this.machineKind === MachineKind.PORTABLE_1930S) {
      return $rawfile('layers/1930s-portable/roller-texture-v7.jpg');
    }
    return $rawfile('layers/1920s-upright/roller-texture-v7.jpg');
  }
  @Prop joltYVp: number = 0;
  @Prop knobAngleDeg: number = 0;
  /** 滚筒纹理转角（与旋钮同角，纹理须能旋转）。 */
  @Prop rollerAngleDeg: number = 0;
  @Prop part: string = 'roller';
  /** 中央件窗中心 y（相对金属顶）。 */
  @Prop strikeYVp: number = 0;
  /** 画布横向偏移（滚筒等宽图件用，一般等于 O）。 */
  @Prop canvasOffsetVp: number = 0;
  /** 固定左缘（不含 O）：木底座/沟槽/铭牌等机身固定件用它，不跟字车走。 */
  @Prop paperLeftFixedVp: number = 0;
  /** 滚筒纹理纵向滚动量（vp，负值=向上滚）。 */
  @Prop texOffsetYVp: number = 0;
  /** 压纸卷竖向偏移（vp）：平板 -15（横杆上移），手机 0。 */
  @Prop bailShiftVp: number = 0;

  private hc(): number {
    return this.paperWidthVp * 0.17;
  }

  private knobD(): number {
    return this.hc() * 0.92;
  }

  /** 压纸卷带长 = 纸宽 + 2×旋钮直径。 */
  /** 压纸卷横杆与纸卷同宽（左右对齐纸缘），不再加旋钮直径。 */
  private bailW(): number {
    return this.paperWidthVp;
  }

  /** 木底座宽 = Pw + 2×knobD（整机最宽，左右各出纸缘一个旋钮直径）。 */
  private baseW(): number {
    return this.paperWidthVp + 2 * this.knobD();
  }

  /** 木底座左缘 = 纸左缘 − knobD。 */
  private baseLeft(): number {
    // §19 兜底钳制：零件再怎么算也不许出屏（正常布局里不应触发，触发即记日志＝约束算错）
    let x: number = this.paperLeftFixedVp - this.knobD();
    if (x < 0) {
      hilog.warn(CDOMAIN, CTAG, 'phone clamp: baseLeft raw=%{public}s -> 0', x.toFixed(2));
      x = 0;
    }
    const right: number = x + this.baseW();
    if (right > this.stageWidth) {
      hilog.warn(CDOMAIN, CTAG, 'phone clamp: baseRight %{public}s > stage %{public}s',
        right.toFixed(2), this.stageWidth.toFixed(2));
    }
    return x;
  }

  /** 纹理滚动量归一化到 [−Hc, 0)，便于无缝拼接。 */
  private texOff(): number {
    const h: number = this.hc();
    const m: number = this.texOffsetYVp % h;
    return m > 0 ? m - h : m;
  }

  /** 木底座顶 = 滚筒中心 + Hc/2 + 2vp（组件顶 = 滚筒顶，故相对 y = Hc + 2）。 */
  private baseTop(): number {
    return this.hc() + 2;
  }

  /** 沟槽左右：底座内缩 10vp。 */
  private grooveLeft(): number {
    return this.baseLeft() + 10;
  }

  private grooveW(): number {
    return this.baseW() - 20;
  }

  /** 沟槽顶 = 底座顶面下 6vp。 */
  private grooveTop(): number {
    return this.baseTop() + 6;
  }

  /** 铭牌左 = 底座左缘 + 底座宽×0.32 − 55。 */
  private plateLeft(): number {
    return this.baseLeft() + this.baseW() * 0.32 - 55;
  }

  /** 滚筒总宽：v3 素材里纸卷部分占 95.28% → W = Pw / 0.9528（金属帽各露 (W−Pw)/2）。 */
  private rollW(): number {
    return this.paperWidthVp / this.rollerWidthRatio;
  }

  private rollX(): number {
    // §18.7：滚筒只走 k×O（纸张走满 O）。k 由 Index 的 ROLLER_K 决定。
    let x: number = this.paperLeftFixedVp + this.rollerOffsetVp - (this.rollW() - this.paperWidthVp) / 2;
    // 钳制兜底：滚筒左缘不许左出底座左缘（手机 k 上限只有 0.612，单靠系数守不住）
    const bl: number = this.baseLeft();
    if (x < bl) {
      x = bl;
    }
    return x;
  }

  private canvasW(): number {
    return this.stageWidth + 2 * this.hc();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.part === 'roller') {
        Stack({ alignContent: Alignment.TopStart }) {
          // 滚筒纹理 v3（平光无缝、两端自带旧钢金属帽）：纵向平移滚动，不旋转
          Stack({ alignContent: Alignment.TopStart }) {
            // 顶缘高光（保留）
            Column().width(this.rollW()).height(1)
              .backgroundColor('rgba(255,246,230,0.18)').position({ x: 0, y: 0 })
            // 两份拼接 + 父层 clip：texOff 归一化到 [−Hc,0) 即无缝
            Image(this.imgRoller())
              .width(this.rollW()).height(this.hc()).objectFit(ImageFit.Cover)
              .position({ x: 0, y: this.texOff() })
            Image(this.imgRoller())
              .width(this.rollW()).height(this.hc()).objectFit(ImageFit.Cover)
              .position({ x: 0, y: this.texOff() + this.hc() })
          }
          .width(this.rollW())
          .height(this.hc())
          .clip(true)
          .position({ x: this.rollX() - this.canvasOffsetVp, y: 0 })

          // 柱面明暗罩：固定不动、盖在整个滚筒上（纹理转、罩不转）——立体感由它提供
          Column()
            .width(this.rollW())
            .height(this.hc())
            .position({ x: this.rollX() - this.canvasOffsetVp, y: 0 })
            .linearGradient({
              direction: GradientDirection.Bottom,
              // 只露下半时必须从中心亮(~230)一路暗到底缘(~75)，落差约 150 点才读得出圆柱
              // 可见段只有下 47%（纸盖到 50%）：在 52% 处加白 bump 提亮端口，底缘加深到 0.72
              colors: [
                ['rgba(255,246,230,0.30)', 0.00],
                ['rgba(255,246,230,0.10)', 0.15],
                ['rgba(0,0,0,0)', 0.35],
                ['rgba(255,246,230,0.32)', 0.52],
                ['rgba(0,0,0,0)', 0.60],
                ['rgba(0,0,0,0.20)', 0.70],
                ['rgba(0,0,0,0.42)', 0.82],
                ['rgba(0,0,0,0.60)', 0.92],
                ['rgba(0,0,0,0.72)', 1.00],
              ],
            })

          // 滚筒后进纸边：纸从滚筒后卷入，滚筒下缘露出一截纸边
          Row()
            .width(this.rollW())
            .height(5)
            .backgroundColor('#e8ddc9')
            .opacity(0.85)
            .position({ x: this.rollX(), y: this.hc() })
        }
        .width(this.stageWidth)
        .height(this.hc())
        .clip(true)
        .translate({ x: this.canvasOffsetVp })
      }

      if (this.part === 'basket') {
        // 字杆篮扇面：纸后、滚筒前的独立层。宽度比纸宽（两侧各留 80vp），
        // 只在纸左右两侧与纸下方露出扇形竖杆，绝不盖纸面。容器不 clip。
        Image(this.imgBasket())
          .width(this.paperWidthVp + 160)
          .height((this.paperWidthVp + 160) / this.basketAspect)
          .objectFit(ImageFit.Fill)
          .opacity(0.6)
          .position({
            x: this.paperLeftVp - 80,
            // 扇面顶约在 carrTop − 70vp；组件顶 = carrTop − Hc/2，故相对 y = Hc/2 − 70
            y: this.hc() / 2 - 70,
          })
      }

      if (this.part === 'metal') {
        // 字杆篮扇面：字车后方（压暗 0.6）。放在 metal 件里才不会被子层级 clip 掉
        // 木底座（整机最宽）：宽 = Pw + 2×knobD，左右各出纸缘一个旋钮直径；顶在滚筒中心 + Hc/2 + 2vp
        Image(this.imgBase())
          .width(this.baseW())
          .height(this.baseW() / this.baseRailAspect)
          .objectFit(ImageFit.Fill)
          .position({ x: this.baseLeft(), y: this.baseTop() })
          .zIndex(0)

        // 沟槽：高 14vp，槽顶在底座顶面下 6vp；槽内深色 + 上缘高光 + 下缘阴影
        Column()
          .width(this.grooveW())
          .height(14)
          .backgroundColor('#120d08')
          .opacity(0.92)
          .position({ x: this.grooveLeft(), y: this.grooveTop() })
          .zIndex(1)
        Column()
          .width(this.grooveW())
          .height(2)
          .backgroundColor('rgba(255,255,255,0.19)')
          .position({ x: this.grooveLeft(), y: this.grooveTop() })
          .zIndex(2)
        Column()
          .width(this.grooveW())
          .height(2)
          .backgroundColor('rgba(0,0,0,0.4)')
          .position({ x: this.grooveLeft(), y: this.grooveTop() + 12 })
          .zIndex(2)

        // 铭牌：黄铜小牌 110×26，嵌在沟槽中左（中心 = 底座左缘 + 底座宽×0.32）
        Column() {
          Text('1920s')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#3a2410')
            .textAlign(TextAlign.Center)
            .width('100%')
        }
        .width(110)
        .height(26)
        .borderRadius(4)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [['#f0d79a', 0.0], ['#c9a45c', 0.55], ['#8a6a2f', 1.0]],
        })
        .position({ x: this.plateLeft(), y: this.grooveTop() - 6 })
        .zIndex(3)

        // 压纸卷：x = 纸屏左 − 旋钮直径
        // 压纸卷 v2（深色钢杆＋两个黑滚轮，素材 2736×283）：杆宽 = 纸宽、对齐纸缘
        Image(this.imgBail())
          .width(this.bailW())
          .height(this.bailW() / 9.6678)
          .objectFit(ImageFit.Fill)
          .position({
            x: this.paperLeftVp,
            // 杆身中心落在滚筒**中心** Y = Hc/2（不是底缘 Hc）：图顶 = Hc/2 − bailH/2（平板 37.8−23=14.8vp）
            y: this.hc() / 2 - this.bailW() / 9.6678 / 2 + this.bailShiftVp,
          })
          // 压在底座(0)/沟槽(1,2)/铭牌(3) 之上：杆身不被木底座盖住
          .zIndex(4)

        // 中央件：窗口中心仍在打击行，但底部裁到「打击行 +10vp」以内，不盖下一行文字
        Stack({ alignContent: Alignment.TopStart }) {
          Image(this.imgCentral())
            .width(this.hc() * 1.5 * 0.848)
            .height(this.hc() * 1.5)
            .objectFit(ImageFit.Contain)
            .position({ x: 0, y: 0 })
        }
        .width(this.hc() * 1.5 * 0.848)
        // 全高：不再裁掉拱下半（旧口径 +10 只留到打击行下 10vp，拱只剩半截）
        .height(this.hc() * 1.5)
        .clip(true)
        .position({
          x: this.strikeXVp - this.hc() * 1.5 * 0.848 / 2,
          y: this.strikeYVp - this.hc() * 1.5 * this.centralWindowY,
        })

        // 本批撤掉两枚圆形旋钮：真机正面只见旋钮侧面而非整面圆盘，
        // 现两个大圆盘摆在纸卷两端像轮子。knobAngle 逻辑保留，待按「只露侧面」重设计外观。
      }
    }
    .width(this.stageWidth)
    .height(this.hc())
    .translate({ y: this.joltYVp })
    .clip(false)
    .onAreaChange((oldA: Area, newA: Area) => {
      hilog.info(CDOMAIN, CTAG,
        'part=%{public}s Hc=%{public}s Pw=%{public}s paperL=%{public}s strikeX=%{public}s',
        this.part, this.hc().toFixed(1), this.paperWidthVp.toFixed(1),
        this.paperLeftVp.toFixed(1), this.strikeXVp.toFixed(1));
    })
    // 根 Stack 不许铺整块不透明深底：金属件（zIndex 3）在纸之上，
    // 该深底会盖住纸的下半截（实测纸从 103.5vp 缩到 77.3vp）。各件均为独立 Image，无需底色。
  }
}
