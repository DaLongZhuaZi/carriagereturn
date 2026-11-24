import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * 批 64（阶段 1）· 舞台容器 Stage26
 *
 * 口径（设计稿 §3.2 换算表／§3.10 规则 2）：
 *  - 舞台宽 = 可用宽 availW（**不设上限**，776 已删）；舞台高 = 可用高 availH；在窗口内居中。
 *  - 机器宽 machineW = min(availW, availH × 362.7/822.5)（长宽比适配）；机器在舞台内居中，不拉伸。
 *  - 五区按纵向 Column 排：固定高区（TopBar 56／功能行 36／字体条 28／候选栏 44／机身底缘 27.6）
 *    ＋ 三个权重区（纸区 320／字篮井 138／键盘井 172.6）。
 *  - 超高设备的纸区上限：纸区 = min(权重分配值, 纸最大高 + 18vp)；超出部分按 138:172.6 分给字篮井与键盘井。
 *
 * 本文件只提供「舞台容器 + 区高算法 + 槽位」；各区的实际组件由 Index 通过 @BuilderParam 传入，
 * 以便把旧绝对定位组件逐个换进来（阶段 1 分批迁移），不在本文件里重写组件。
 */

/** 固定高区（vp，手机／平板一致）。 */
const TOP_BAR_H: number = 56;
const FUNC_ROW_H: number = 67;
const FONT_BAR_H: number = 28;
const CAND_BAR_H: number = 44;
const BOTTOM_EDGE_H: number = 27.6;
/** 基准键盘总高 = 5 行 × 34.5 + 4 纵缝 × 6.9 = 200.1vp（批 65：键盘井高由它 × kx 导出）。 */
const KEYBOARD_BASE_H: number = 200.1;
/** 纸区／字篮井在剩余高度里的权重（批 65：不再给键盘井分权重）。 */
const W_PAPER_ONLY: number = 320;
const W_BASKET_ONLY: number = 138;
const W_REST_SUM: number = W_PAPER_ONLY + W_BASKET_ONLY;   // 458
const FIXED_SUM: number = TOP_BAR_H + FUNC_ROW_H + FONT_BAR_H + CAND_BAR_H + BOTTOM_EDGE_H;   // 222.5（批66：功能行 36→67）
const W_PAPER: number = 320;
const W_BASKET: number = 138;
const W_KEYS: number = 172.6;
const W_SUM: number = W_PAPER + W_BASKET + W_KEYS;   // 630.6
/** 机器自然长宽比（宽:高）。 */
const MACHINE_RATIO: number = 362.7 / 822.5;   // 0.441
/** 纸最大高按纸宽缩放：306 × (Pw/220)，Pw = 机器宽 × 0.606。 */
const PAPER_MAX_RATIO: number = 306 * 0.606 / 220;   // ≈0.8428（乘机器宽即得纸最大高）

/** 舞台几何（vp）。纯数据类，供布局与打点共用。 */
export class StageLayout {
  stageW: number = 0;
  stageH: number = 0;
  /** 机器宽（信 lane 内所有视觉件的基准）。 */
  machineW: number = 0;
  /** 机器在舞台内的水平偏移（舞台居中机器）。 */
  machineLeft: number = 0;
  topBarH: number = TOP_BAR_H;
  paperH: number = 0;
  basketH: number = 0;
  funcRowH: number = FUNC_ROW_H;
  fontBarH: number = FONT_BAR_H;
  candBarH: number = CAND_BAR_H;
  keyH: number = 0;
  bottomEdgeH: number = BOTTOM_EDGE_H;
  /** 纸宽 Pw = 机器宽 × 0.606（驱动字号与每行字数）。 */
  paperW: number = 0;
  /** 纸最大高 = 306 × (Pw/220)。 */
  paperMaxH: number = 0;
  /** 纸区是否被上限截断（true 时多出来的高度分给了字篮井与键盘井）。 */
  paperCapped: boolean = false;

  constructor(availW: number, availH: number) {
    this.stageW = availW;
    this.stageH = availH;
    /**
     * 批 64（用户 2026-11-21 定）：机器宽＝**可用宽**（铺满），不再按机器长宽比封顶。
     *
     * 旧口径 `min(availW, availH × 362.7/822.5)` 在竖屏平板上恒为 475.3vp（按高度算），
     * 永远比屏宽 673.7vp 窄 198vp ⇒ 打字页左右两侧各空 99vp。用户判定「依然没有正确自适应」。
     * 新口径：机器横向铺满；高度仍由「固定高 + 320:138:172.6 权重」分配，
     * 机器的长宽比只作参考，不再约束宽度。
     */
    this.machineW = availW;
    this.machineLeft = 0;
    this.paperW = this.machineW * 0.606;
    this.paperMaxH = this.machineW * PAPER_MAX_RATIO;

    const remaining: number = availH - FIXED_SUM;
    /**
     * 批 65（增补-30 任务 2）：键盘井高**由 kx 导出**，不再按权重分。
     * 井是装键盘的——键盘（键帽＋行距＋纵缝）整体是按 kx 等比缩放的，所以井高 = 200.1×kx。
     * 纸区与字篮井分「剩余 − 井高」，仍按 28 号稿的 320:138。这是选项 B 的取舍：
     * 键变大 ⇒ 纸区与字篮让出纵向空间（平板 纸区 ~449.7→359.5vp、字篮 ~194→155.1vp）。
     */
    const kx: number = this.machineW / 362.7;
    this.keyH = KEYBOARD_BASE_H * kx;
    const rest: number = remaining - this.keyH;
    const cap: number = this.paperMaxH + 18;
    const byWeight: number = rest * W_PAPER_ONLY / W_REST_SUM;
    if (byWeight > cap) {
      this.paperCapped = true;
      this.paperH = cap;
      this.basketH = rest - cap;
    } else {
      this.paperH = byWeight;
      this.basketH = rest * W_BASKET_ONLY / W_REST_SUM;
    }
  }

  /**
   * 纸字号（批 64 用户 2026-11-21「自适应字数」）。
   *
   * 错误做法（已作废）：`Pw/220 × 11.9` —— 字号随纸宽**线性**放大，
   * 于是 `行宽 / 字宽` 恒等于 17，大屏一点字都没多（等于整版等比缩放）。
   * 正确做法：字号按 **√(纸宽)** 增长（视觉上"稍大一点"，但增速远慢于纸宽）
   * ⇒ 纸越宽，每行字数越多：手机 11.9vp ≈ 15 字、平板 673.7 宽时 16.2vp ≈ 31 字。
   */
  fontSizeVp(): number {
    const ratio: number = this.paperW > 0 ? this.paperW / 220 : 1;
    return 11.9 * Math.sqrt(ratio);
  }

  /** 行高 = 字号 × 30/17。 */
  lineHeightVp(): number {
    return this.fontSizeVp() * 30 / 17;
  }

  /** 每行字数（英文 0.6em）：行宽 = 235 × 机器宽/362.7。 */
  charsPerLineEng(): number {
    const lineW: number = 235 * this.machineW / 362.7;
    const adv: number = this.fontSizeVp() * 0.6;
    return adv > 0 ? Math.floor(lineW / adv) : 0;
  }

  /** 一句话打点：舞台／机器／五区／纸，便于真机对账。 */
  describe(): string {
    return 'stage=' + this.stageW.toFixed(1) + 'x' + this.stageH.toFixed(1)
      + ' machineW=' + this.machineW.toFixed(1) + ' left=' + this.machineLeft.toFixed(1)
      + ' paperH=' + this.paperH.toFixed(1) + ' basketH=' + this.basketH.toFixed(1)
      + ' keyH=' + this.keyH.toFixed(1) + ' fixed=' + FIXED_SUM.toFixed(1)
      + ' Pw=' + this.paperW.toFixed(1) + ' fs=' + this.fontSizeVp().toFixed(2)
      + ' cpl=' + this.charsPerLineEng().toString() + ' capped=' + (this.paperCapped ? '1' : '0');
  }
}


const DOMAIN: number = 0xA00100;
const TAG: string = 'Stage26';

/**
 * 舞台容器（flex 化后的唯一坐标系）。
 * 各届由 Index 用 @BuilderParam 传入；高度按 StageLayout 的换算表写死，机器宽列在舞台内居中。
 *
 * 绘制序（批 64 T2 第一步实测口径）：顶栏槽位**单独作为覆盖层排在 Column 之后**。
 * 原因：现行 z 序里顶栏（返回拨杆／边铃／出纸槽／铭牌）压在纸面与纸顶之上——纸顶允许出屏、
 * 出纸槽压在纸右缘；若把顶栏当普通 Column 子项排在最前，纸面会盖住顶栏与槽。故 Column 首槽只占位，
 * 真正的顶栏在 Column 之上再画一层。其余七槽仍按设计稿顺序在 Column 内。
 */
@Component
export struct Stage26 {
  @Prop @Watch('onAvailChange') availW: number = 362.7;
  @Prop @Watch('onAvailChange') availH: number = 822.5;
  @State layout: StageLayout = new StageLayout(362.7, 822.5);
  @BuilderParam topBarZone: () => void = this.emptyZone;
  @BuilderParam paperZone: () => void = this.emptyZone;
  @BuilderParam basketZone: () => void = this.emptyZone;
  @BuilderParam funcRowZone: () => void = this.emptyZone;
  @BuilderParam fontBarZone: () => void = this.emptyZone;
  @BuilderParam candBarZone: () => void = this.emptyZone;
  @BuilderParam keyZone: () => void = this.emptyZone;
  @BuilderParam bottomZone: () => void = this.emptyZone;

  @Builder
  emptyZone() {
    Column().width(0).height(0)
  }

  aboutToAppear(): void {
    this.layout = new StageLayout(this.availW, this.availH);
    hilog.info(DOMAIN, TAG, 'zone %{public}s', this.layout.describe());
  }

  /** 可用宽高变化（换机／旋屏／折叠）就重算区高；不重算会让槽位停在旧尺寸上。 */
  onAvailChange(): void {
    this.layout = new StageLayout(this.availW, this.availH);
    hilog.info(DOMAIN, TAG, 'zone %{public}s', this.layout.describe());
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // ---- 纵向槽列（首槽只留占位高度，顶栏作为覆盖层在下面单独绘制）----
      Row() {
        Column() {
          Column().width('100%').height(this.layout.topBarH)
          Column() { this.paperZone() }.width('100%').height(this.layout.paperH)
          Column() { this.basketZone() }.width('100%').height(this.layout.basketH)
          Column() { this.funcRowZone() }.width('100%').height(this.layout.funcRowH)
          Column() { this.fontBarZone() }.width('100%').height(this.layout.fontBarH)
          Column() { this.candBarZone() }.width('100%').height(this.layout.candBarH)
          Column() { this.keyZone() }.width('100%').height(this.layout.keyH)
          Column() { this.bottomZone() }.width('100%').height(this.layout.bottomEdgeH)
        }
        .width(this.layout.machineW)
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)

      // ---- 顶栏覆盖层（压在纸面／出纸槽之上，保持现行 z 序）----
      // 批 79（任务 1）：**显式置顶**——批 70 把纸视口上沿扩到屏顶后，纸的触摸面与顶栏带重叠；
      // 只靠「后渲染的兄弟在上」不够保险（纸的负 margin 溢出会把命中序列搅乱），
      // 这里给顶栏一个独立 zIndex，保证纸张再长、字车再靠左，返回拨杆/出纸槽也永远先命中。
      Row() {
        Column() { this.topBarZone() }.width(this.layout.machineW).height(this.layout.topBarH)
      }
      .width('100%')
      .height(this.layout.topBarH)
      .justifyContent(FlexAlign.Center)
      .zIndex(10)
    }
    .width('100%')
    .height('100%')
  }
}
