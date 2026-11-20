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
const FUNC_ROW_H: number = 36;
const FONT_BAR_H: number = 28;
const CAND_BAR_H: number = 44;
const BOTTOM_EDGE_H: number = 27.6;
const FIXED_SUM: number = TOP_BAR_H + FUNC_ROW_H + FONT_BAR_H + CAND_BAR_H + BOTTOM_EDGE_H;   // 191.6
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
    const byH: number = availH * MACHINE_RATIO;
    this.stageW = availW;
    this.stageH = availH;
    this.machineW = availW < byH ? availW : byH;
    this.machineLeft = (availW - this.machineW) / 2;
    this.paperW = this.machineW * 0.606;
    this.paperMaxH = this.machineW * PAPER_MAX_RATIO;

    const remaining: number = availH - FIXED_SUM;
    const byWeight: number = remaining * W_PAPER / W_SUM;
    const cap: number = this.paperMaxH + 18;
    if (byWeight > cap) {
      this.paperCapped = true;
      this.paperH = cap;
      const extra: number = remaining - cap;
      this.basketH = extra * W_BASKET / (W_BASKET + W_KEYS);
      this.keyH = extra * W_KEYS / (W_BASKET + W_KEYS);
    } else {
      this.paperH = byWeight;
      this.basketH = remaining * W_BASKET / W_SUM;
      this.keyH = remaining * W_KEYS / W_SUM;
    }
  }

  /** 纸字号：Pw/220 × 11.9（设计稿 §3.3；平板 15.58vp、手机 11.9vp）。 */
  fontSizeVp(): number {
    return this.paperW / 220 * 11.9;
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
 */
@Component
export struct Stage26 {
  @Prop availW: number = 362.7;
  @Prop availH: number = 822.5;
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

  build() {
    Row() {
      Column() {
        Column() { this.topBarZone() }.width('100%').height(this.layout.topBarH)
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
  }
}
