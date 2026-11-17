/**
 * 26 号稿（打字页面推倒重来）· 零件层：整机一体的盖子／字车／字篮／融盖控件／纸。
 *
 * 基准坐标系：手机 stageW=362.7vp、stageH=822.5vp（§6 y-map，绝对屏幕坐标）。
 * 组件一律收 (sx, sy) 两个缩放因子：sx＝stageW/362.7，sy＝stageH/822.5。
 * 所有 y 值以设计稿 §6 的 vp 数为准，乘 sy 使用。
 *
 * 层序（自下而上，由 Index 按挂载顺序实现）：
 *   Lid26 → Roller26 → PaperPanel26 → Curl26 → CarriageFront26（横尺／色带／压纸杆／旋钮／拨杆）
 *   → Basket26 → 功能行／字体牌／候选条 → KeyWell → KeyGrid
 */

import { MachineKind } from '../../model/DocModel';
import { tierToken } from '../../model/MachineCatalog';

/** §6 y-map（手机 vp，绝对屏幕坐标）。 */
export const T26_BASE_W: number = 362.7;
export const T26_BASE_H: number = 822.5;
export const Y_TOPDECK: number = 104;
export const Y_PAPER_BOTTOM: number = 362.4;
export const Y_RULER: number = 356;
export const H_RULER: number = 12;
export const Y_RIBBON: number = 370;
export const H_RIBBON: number = 4;
export const Y_BASKET: number = 376;
export const H_BASKET: number = 138;
export const Y_FUNC: number = 514;
export const H_FUNC: number = 36;
export const Y_FONT: number = 550;
export const H_FONT: number = 28;
export const Y_CAND: number = 578;
export const H_CAND: number = 44;
export const Y_GRID: number = 622.3;
export const H_GRID: number = 172.6;
export const MACHINE_X0: number = 8;
export const MACHINE_X1: number = 354.7;

/** 木纹贴片（$rawfile 需字面量，按机静态分支）。 */
@Builder
export function lidTileImage(machine: MachineKind) {
  if (machine === MachineKind.UPRIGHT_1920S) {
    Image($rawfile('ui-parts/tile-1920s-base.png')).width('100%').height('100%').objectFit(ImageFit.Fill).opacity(0.92)
  } else if (machine === MachineKind.PORTABLE_1930S) {
    Image($rawfile('ui-parts/tile-1930s-base.png')).width('100%').height('100%').objectFit(ImageFit.Fill).opacity(0.92)
  } else if (machine === MachineKind.STREAMLINED_1950S) {
    Image($rawfile('ui-parts/tile-1950s-base.png')).width('100%').height('100%').objectFit(ImageFit.Fill).opacity(0.92)
  } else {
    Image($rawfile('ui-parts/tile-1960s-base.png')).width('100%').height('100%').objectFit(ImageFit.Fill).opacity(0.92)
  }
}

/** 字篮扇形（生成件）。 */
@Builder
export function basketFanImage(machine: MachineKind) {
  if (machine === MachineKind.UPRIGHT_1920S) {
    Image($rawfile('ui-parts/basket-fan-3d.png')).width('100%').height('100%').objectFit(ImageFit.Fill)
  } else if (machine === MachineKind.PORTABLE_1930S) {
    Image($rawfile('ui-parts/basket-fan-3d.png')).width('100%').height('100%').objectFit(ImageFit.Fill)
  } else if (machine === MachineKind.STREAMLINED_1950S) {
    Image($rawfile('ui-parts/basket-fan-3d.png')).width('100%').height('100%').objectFit(ImageFit.Fill)
  } else {
    Image($rawfile('ui-parts/basket-fan-3d.png')).width('100%').height('100%').objectFit(ImageFit.Fill)
  }
}

/** 机身基准色（§10）。 */
export function lidColor(machine: MachineKind): string {
  return tierToken(machine, 'base');
}

/** 机身基准色的更暗版本（顶栏黑区／井底邻接）。 */
export function darken(hex: string, k: number): string {
  const h: string = hex.charAt(0) === '#' ? hex.substring(1) : hex;
  if (h.length < 6) { return '#120f0c'; }
  const r: number = Math.round(parseInt(h.substring(0, 2), 16) * (1 - k));
  const g: number = Math.round(parseInt(h.substring(2, 4), 16) * (1 - k));
  const b: number = Math.round(parseInt(h.substring(4, 6), 16) * (1 - k));
  const t: (v: number) => string = (v: number): string => {
    const s: string = v.toString(16);
    return s.length < 2 ? '0' + s : s;
  };
  return '#' + t(r) + t(g) + t(b);
}

/** 亮化（负 k 为压暗）。 */
export function lighten(hex: string, k: number): string {
  const h: string = hex.charAt(0) === '#' ? hex.substring(1) : hex;
  if (h.length < 6) { return '#3a3330'; }
  const r0: number = parseInt(h.substring(0, 2), 16);
  const g0: number = parseInt(h.substring(2, 4), 16);
  const b0: number = parseInt(h.substring(4, 6), 16);
  const f: (v: number) => number = (v: number): number => {
    const x: number = Math.round(v + (255 - v) * k);
    return x < 0 ? 0 : (x > 255 ? 255 : x);
  };
  const t: (v: number) => string = (v: number): string => {
    const s: string = v.toString(16);
    return s.length < 2 ? '0' + s : s;
  };
  return '#' + t(f(r0)) + t(f(g0)) + t(f(b0));
}

/** 黄铜token。 */
export const BRASS: string = '#b08d4f';
export const BRASS_HI: string = '#d8b874';
export const STEEL: string = '#8f8f92';
export const STEEL_HI: string = '#cfcfd2';
export const RED26: string = '#c8322d';

/** 机器顶部深色带（顶栏黑区 0–104vp 的底）。 */
@Component
export struct TopDeck26 {
  @Prop widthVp: number = 362.7;
  @Prop heightVp: number = 104;
  @Prop sx: number = 1;
  @Prop sy: number = 1;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%').height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [['#0d0b09', 0.0], ['#181310', 0.72], ['#241c16', 1.0]],
        })
      Column().width('100%').height(1).backgroundColor('#3b3128')
        .position({ x: 0, y: this.heightVp - 1 })
    }
    .width(this.widthVp).height(this.heightVp)
  }
}

// ---------------------------------------------------------------------------
// 顶区（黑区 0–104）：黄铜铭牌／返回拨杆／边铃／出纸槽／库与菜单
// ---------------------------------------------------------------------------
@Component
export struct TopZone26 {
  @Prop machine: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop widthVp: number = 362.7;
  @Prop heightVp: number = 104;
  @Prop sx: number = 1;
  @Prop sy: number = 1;
  @Prop docTitle: string = '';
  @Prop soundOn: boolean = true;
  @Prop guideEnabled: boolean = true;
  /** 成就解锁高亮（铭牌亮起）。 */
  @Prop achGlow: boolean = false;
  onBack: () => void = (): void => {};
  onMenu: () => void = (): void => {};
  onLibrary: () => void = (): void => {};
  onBell: () => void = (): void => {};
  onExportSlot: () => void = (): void => {};
  onPlate: () => void = (): void => {};
  onGuide: () => void = (): void => {};

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 黄铜铭牌（x 150–212，y 8–48；写文档名；点按显示文档名）
      Column() {
        Text(this.docTitle.length > 0 ? this.docTitle : '未命名')
          .fontSize(9).fontColor('#2a1f10')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center).width('100%').padding({ left: 3, right: 3 })
      }
      .justifyContent(FlexAlign.Center)
      .width(62 * this.sx).height(40 * this.sy)
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: [[BRASS_HI, 0.0], [BRASS, 0.55], ['#8a6a33', 1.0]],
      })
      .borderRadius(3)
      .border({ width: 1, color: this.achGlow ? '#ffe9a8' : '#6d5326' })
      .shadow({ radius: this.achGlow ? 10 : 3, color: this.achGlow ? '#ffd777' : '#00000088' })
      .position({ x: 150 * this.sx, y: 8 * this.sy })
      .onClick(() => { this.onPlate(); })

      // 返回拨杆（机身左上角，y 48 起避开状态栏）：小钢拨杆＋球头
      Stack({ alignContent: Alignment.TopStart }) {
        Column().width(5 * this.sx).height(22 * this.sy)
          .linearGradient({ direction: GradientDirection.Right, colors: [[STEEL_HI, 0.0], [STEEL, 0.5], ['#4a4a4d', 1.0]] })
          .borderRadius(2)
          .rotate({ angle: 18 })
          .position({ x: 8 * this.sx, y: 6 * this.sy })
        Circle().width(9 * this.sx).height(9 * this.sx)
          .fill(BRASS_HI).stroke('#5a4520').strokeWidth(1)
          .position({ x: 3 * this.sx, y: 1 * this.sy })
      }
      .width(34 * this.sx).height(34 * this.sy)
      .position({ x: 10 * this.sx, y: 46 * this.sy })
      .onClick(() => { this.onBack(); })

      // 边铃（x 12–40，y 60–88）：开＝直立＋小红点，关＝倾斜 15°＋无红点
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(24 * this.sx).height(22 * this.sy)
          .linearGradient({ direction: GradientDirection.Bottom, colors: [[BRASS_HI, 0.0], [BRASS, 0.6], ['#7c5f2d', 1.0]] })
          .borderRadius({ topLeft: 12 * this.sx, topRight: 12 * this.sx, bottomLeft: 3, bottomRight: 3 })
          .border({ width: 1, color: '#5f4a22' })
        Column().width(26 * this.sx).height(2).backgroundColor('#6b5327').position({ x: 1 * this.sx, y: 21 * this.sy })
        if (this.soundOn) {
          Circle().width(5).height(5).fill('#e0483c').position({ x: 18 * this.sx, y: 2 * this.sy })
        }
      }
      .width(28 * this.sx).height(26 * this.sy)
      .rotate({ angle: this.soundOn ? 0 : 15 })
      .position({ x: 12 * this.sx, y: 62 * this.sy })
      .onClick(() => { this.onBell(); })

      // 出纸槽（x 300–350，y 60–72）：深槽＋钢唇＋纸舌
      Stack({ alignContent: Alignment.TopStart }) {
        Column().width(50 * this.sx).height(10 * this.sy)
          .backgroundColor('#0b0a09')
          .border({ width: 1, color: '#6d6d70' })
          .borderRadius(2)
        Column().width(44 * this.sx).height(3 * this.sy)
          .linearGradient({ direction: GradientDirection.Right, colors: [['#f2ead8', 0.0], ['#cfc4ad', 1.0]] })
          .position({ x: 3 * this.sx, y: 1 * this.sy })
      }
      .width(50 * this.sx).height(12 * this.sy)
      .position({ x: 300 * this.sx, y: 60 * this.sy })
      .onClick(() => { this.onExportSlot(); })

      // 库／菜单／引导（机身右上小钢件，避开状态栏）
      Stack({ alignContent: Alignment.Center }) {
        Column().width(24 * this.sx).height(24 * this.sy).backgroundColor('#3b332a')
          .border({ width: 1.2, color: '#9a8158' }).borderRadius(12)
          .shadow({ radius: 3, color: '#000000aa' })
        Column().width(10 * this.sx).height(2).backgroundColor('#d9c9a8').position({ x: 6 * this.sx, y: 8 * this.sy })
        Column().width(10 * this.sx).height(2).backgroundColor('#d9c9a8').position({ x: 6 * this.sx, y: 12 * this.sy })
      }
      .width(24 * this.sx).height(24 * this.sy)
      .position({ x: Math.max(10, this.widthVp - 36 * this.sx), y: 44 * this.sy })
      .onClick(() => { this.onMenu(); })

      Stack({ alignContent: Alignment.Center }) {
        Column().width(24 * this.sx).height(24 * this.sy).backgroundColor('#3b332a')
          .border({ width: 1.2, color: '#9a8158' }).borderRadius(12)
          .shadow({ radius: 3, color: '#000000aa' })
        Column().width(11 * this.sx).height(8 * this.sy).border({ width: 1.4, color: '#d9c9a8' })
          .borderRadius(1)
      }
      .width(24 * this.sx).height(24 * this.sy)
      .position({ x: Math.max(10, this.widthVp - 66 * this.sx), y: 44 * this.sy })
      .onClick(() => { this.onLibrary(); })

      if (this.guideEnabled) {
        Stack({ alignContent: Alignment.Center }) {
          Text('?').fontSize(13).fontColor('#d9c9a8').fontWeight(FontWeight.Bold)
        }
        .width(22 * this.sx).height(22 * this.sy)
        .border({ width: 1, color: '#6b5a44' }).borderRadius(11)
        .position({ x: Math.max(10, this.widthVp - 90 * this.sx), y: 46 * this.sy })
        .onClick(() => { this.onGuide(); })
      }
    }
    .width(this.widthVp).height(this.heightVp)
    .clip(true)
  }
}

// ---------------------------------------------------------------------------
// 盖子（机身）：木纹＋柔光＋字篮区 4 颗螺丝（另 4 颗在钢板四角，由 KeyWell 开孔露出）
// ---------------------------------------------------------------------------
@Component
export struct Lid26 {
  @Prop machine: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop widthVp: number = 362.7;
  @Prop heightVp: number = 822.5;
  @Prop sx: number = 1;
  @Prop sy: number = 1;
  @Prop topVp: number = 104;

  @Builder
  screw(cx: number, cy: number) {
    Stack({ alignContent: Alignment.Center }) {
      Column().width(6 * this.sx).height(6 * this.sx)
        .linearGradient({ direction: GradientDirection.Bottom, colors: [[STEEL_HI, 0.0], [STEEL, 0.55], ['#4d4d50', 1.0]] })
        .borderRadius(3 * this.sx)
      Column().width(4 * this.sx).height(1).backgroundColor('#242422').rotate({ angle: 28 })
    }
    .width(6 * this.sx).height(6 * this.sx)
    .position({ x: cx * this.sx - 3 * this.sx, y: cy * this.sy - 3 * this.sx })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 木纹底：base token ＋ 批 28 贴片（横向平铺、纵向拉伸）
      Column().width('100%').height('100%').backgroundColor(lidColor(this.machine))
      lidTileImage(this.machine)
      // 柔光渐变：顶部略亮、底部略暗（清漆光泽）
      Column().width('100%').height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [[lighten(lidColor(this.machine), 0.10), 0.0],
            [lighten(lidColor(this.machine), 0.02), 0.35],
            [lighten(lidColor(this.machine), -0.16), 1.0]],
        })
        .opacity(0.55)
        .hitTestBehavior(HitTestMode.None)
      // 清漆高光：上沿一道窄亮带
      Column().width('100%').height(10 * this.sy)
        .linearGradient({ direction: GradientDirection.Bottom, colors: [['#ffffff44', 0.0], ['#ffffff00', 1.0]] })
        .position({ x: 0, y: 0 })
        .hitTestBehavior(HitTestMode.None)

      // 字篮井区左右各两颗螺丝（上沿 y390、腰部 y470）
      this.screw(24, 390)
      this.screw(338, 390)
      this.screw(24, 470)
      this.screw(338, 470)
    }
    .width(this.widthVp).height(this.heightVp)
    .clip(true)
  }
}

// ---------------------------------------------------------------------------
// 滚筒（纸后）：深钢柱面＋两端筒身（旋钮在 CarriageFront 里，画在纸之上）
// ---------------------------------------------------------------------------
@Component
export struct Roller26 {
  @Prop machine: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop widthVp: number = 362.7;
  @Prop sx: number = 1;
  @Prop sy: number = 1;
  @Prop joltYVp: number = 0;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 柱身：x 8–354.7，中心 y 104（高 88）；纵向柱面明暗（上亮、中暗、下反光）
      Column()
        .width((MACHINE_X1 - MACHINE_X0) * this.sx)
        .height(88 * this.sy)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [['#5a5a5f', 0.0], ['#3a3a3e', 0.12], ['#141416', 0.55],
            ['#0e0e10', 0.72], ['#33333a', 0.9], ['#1c1c20', 1.0]],
        })
        .borderRadius(6)
        .position({ x: MACHINE_X0 * this.sx, y: 60 * this.sy })
        .translate({ y: this.joltYVp })
      // 上沿高光
      Column().width((MACHINE_X1 - MACHINE_X0) * this.sx).height(2 * this.sy)
        .linearGradient({ direction: GradientDirection.Bottom, colors: [['#8f8f95', 0.0], ['#8f8f9500', 1.0]] })
        .position({ x: MACHINE_X0 * this.sx, y: 60 * this.sy })
      // 两端轴头（露出的筒身）
      Column().width(10 * this.sx).height(40 * this.sy).backgroundColor('#2a2a2d')
        .position({ x: MACHINE_X0 * this.sx, y: 84 * this.sy })
      Column().width(10 * this.sx).height(40 * this.sy).backgroundColor('#2a2a2d')
        .position({ x: (MACHINE_X1 - 10) * this.sx, y: 84 * this.sy })
    }
    .width(this.widthVp).height(180 * this.sy)
    .hitTestBehavior(HitTestMode.None)
  }
}

// ---------------------------------------------------------------------------
// 纸顶卷曲覆盖层：把 paper-curl.png 的纸区裁到纸宽（只留卷起的纸，不留它的滚筒）
// ---------------------------------------------------------------------------
@Component
export struct Curl26 {
  @Prop sx: number = 1;
  @Prop sy: number = 1;
  @Prop paperLeftVp: number = 156;
  @Prop paperWidthVp: number = 220;
  @Prop paperTopVp: number = 104;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image($rawfile('ui-parts/paper-curl.png'))
        .width(379 * this.sx)
        .height(123 * this.sy)
        .objectFit(ImageFit.Fill)
        .position({ x: -61.4 * this.sx, y: 0 })
        .hitTestBehavior(HitTestMode.None)
    }
    .width(this.paperWidthVp)
    .height(70 * this.sy)
    .clip(true)
    .hitTestBehavior(HitTestMode.None)
  }
}

// ---------------------------------------------------------------------------
// 字车正面：横尺＋锯齿边＋红三角＋中央指针＋色带＋压纸杆＋旋钮＋拨杆
// 全部画在纸之上（z 5.2 起）。
// ---------------------------------------------------------------------------
@Component
export struct CarriageFront26 {
  @Prop machine: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop widthVp: number = 362.7;
  @Prop sx: number = 1;
  @Prop sy: number = 1;
  @Prop paperLeftVp: number = 156;
  @Prop paperWidthVp: number = 220;
  @Prop leverOffsetVp: number = 0;
  @Prop leverAngle: number = 0;
  @Prop knobAngle: number = 0;
  @Prop strikePhase: number = 0;
  @Prop knobDVp: number = 46.5;
  onKnob: () => void = (): void => {};
  onLeverTap: () => void = (): void => {};
  onLeverStart: () => void = (): void => {};
  onLeverUpdate: (dy: number) => void = (_dy: number): void => {};
  onLeverEnd: () => void = (): void => {};

  /** 横尺刻度：密排短竖线（每 4vp 一根）。 */
  private ticks(): number[] {
    const out: number[] = [];
    for (let x = 14; x < MACHINE_X1 - 10; x += 4) {
      out.push(x);
    }
    return out;
  }

  /** 锯齿边：横尺下沿一排小三角。 */
  private sawPath(): string {
    const maxX: number = (MACHINE_X1 - MACHINE_X0) * this.sx;
    const toothW: number = 4 * this.sx;
    const toothH: number = 3 * this.sy;
    let d: string = 'M0 0';
    let x: number = 0;
    while (x < maxX) {
      d += ' L' + (x + toothW / 2).toFixed(1) + ' ' + toothH.toFixed(1) + ' L' + (x + toothW).toFixed(1) + ' 0';
      x += toothW;
    }
    return d;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // ---- 横尺（y 356–368）----
      Stack({ alignContent: Alignment.TopStart }) {
        Column().width('100%').height('100%')
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [['#e6e6e8', 0.0], ['#b4b4b4', 0.45], ['#7d7d80', 1.0]],
          })
        // 细刻度
        ForEach(this.ticks(), (x: number) => {
          Column().width(1).height(5 * this.sy).backgroundColor('#3d3d40')
            .position({ x: (x - MACHINE_X0) * this.sx, y: 0 })
        }, (x: number) => 't' + x.toString())
        // 两个红三角（左右边距标记，随纸走）
        Path({ commands: 'M0 0 L' + (7 * this.sx).toFixed(1) + ' 0 L' + (3.5 * this.sx).toFixed(1) + ' ' + (6 * this.sy).toFixed(1) + ' Z' }).fill(RED26)
          .width(7 * this.sx).height(6 * this.sy)
          .position({ x: (this.paperLeftVp + 25 - MACHINE_X0) * this.sx - 3.5 * this.sx, y: 5 * this.sy })
        Path({ commands: 'M0 0 L' + (7 * this.sx).toFixed(1) + ' 0 L' + (3.5 * this.sx).toFixed(1) + ' ' + (6 * this.sy).toFixed(1) + ' Z' }).fill(RED26)
          .width(7 * this.sx).height(6 * this.sy)
          .position({ x: (this.paperLeftVp + 25 + 165 - MACHINE_X0) * this.sx - 3.5 * this.sx, y: 5 * this.sy })
        // 锯齿下沿
        Path({ commands: this.sawPath() }).fill('#6a6a6d')
          .width((MACHINE_X1 - MACHINE_X0) * this.sx).height(3 * this.sy)
          .position({ x: 0, y: 9 * this.sy })
      }
      .width((MACHINE_X1 - MACHINE_X0) * this.sx)
      .height(12 * this.sy)
      .clip(true)
      .position({ x: MACHINE_X0 * this.sx, y: Y_RULER * this.sy })

      // ---- 中央指针（金属针＋红三角尖，钉在机中心 181vp）----
      Column().width(3 * this.sx).height(14 * this.sy)
        .linearGradient({ direction: GradientDirection.Bottom, colors: [[STEEL_HI, 0.0], [STEEL, 1.0]] })
        .position({ x: (181 - MACHINE_X0) * this.sx - 1.5 * this.sx, y: (Y_RULER - 14) * this.sy })
      Path({ commands: 'M0 0 L' + (8 * this.sx).toFixed(1) + ' 0 L' + (4 * this.sx).toFixed(1) + ' ' + (7 * this.sy).toFixed(1) + ' Z' }).fill(RED26)
        .width(8 * this.sx).height(7 * this.sy)
        .position({ x: (181 - MACHINE_X0) * this.sx - 4 * this.sx, y: (Y_RULER - 7) * this.sy })

      // ---- 色带（y 370–374）：常态即红带，击打时抬起 12vp ----
      Column().width((MACHINE_X1 - MACHINE_X0) * this.sx).height(4 * this.sy)
        .linearGradient({ direction: GradientDirection.Bottom, colors: [['#e04a42', 0.0], [RED26, 0.55], ['#8f1f1c', 1.0]] })
        .position({ x: MACHINE_X0 * this.sx, y: Y_RIBBON * this.sy })
        .translate({ y: -12 * this.sy * this.strikePhase })

      // ---- 压纸杆（细金属杆横过纸面下部，两端小黑压轮）----
      Column().width((MACHINE_X1 - MACHINE_X0 - 30) * this.sx).height(4 * this.sy)
        .linearGradient({ direction: GradientDirection.Bottom, colors: [[STEEL_HI, 0.0], ['#5c5c5f', 1.0]] })
        .position({ x: (MACHINE_X0 + 15) * this.sx, y: 344 * this.sy })
      Circle().width(9 * this.sx).height(9 * this.sx).fill('#111111')
        .position({ x: (MACHINE_X0 + 15) * this.sx, y: 341.5 * this.sy })
      Circle().width(9 * this.sx).height(9 * this.sx).fill('#111111')
        .position({ x: (MACHINE_X1 - 24) * this.sx, y: 341.5 * this.sy })

      // ---- 旋钮（双端，d 46.5，点按进纸一行）----
      Image($rawfile('ui-parts/knob-metal.png'))
        .width(this.knobDVp * this.sx).height(this.knobDVp * this.sx)
        .objectFit(ImageFit.Fill)
        .rotate({ angle: this.knobAngle })
        .position({ x: -16 * this.sx, y: (104 - this.knobDVp / 2) * this.sy })
        .onClick(() => { this.onKnob(); })
      Image($rawfile('ui-parts/knob-metal.png'))
        .width(this.knobDVp * this.sx).height(this.knobDVp * this.sx)
        .objectFit(ImageFit.Fill)
        .rotate({ angle: this.knobAngle })
        .position({
          x: MACHINE_X1 * this.sx - 18 * this.sx,
          y: (104 - this.knobDVp / 2) * this.sy,
        })
        .onClick(() => { this.onKnob(); })

      // ---- 拨杆（装在字车上，随字车移动；V=0 x 165–225）----
      Stack({ alignContent: Alignment.TopStart }) {
        Image($rawfile('ui-parts/lever.png'))
          .width(34 * this.sx).height(110 * this.sy)
          .objectFit(ImageFit.Fill)
      }
      .width(34 * this.sx).height(110 * this.sy)
      .rotate({ angle: this.leverAngle })
      .position({ x: 165 * this.sx + this.leverOffsetVp, y: 230 * this.sy })
      .onClick(() => { this.onLeverTap(); })
      .gesture(PanGesture({ direction: PanDirection.Vertical })
        .onActionStart(() => { this.onLeverStart(); })
        .onActionUpdate((e: GestureEvent) => { this.onLeverUpdate(e.offsetY); })
        .onActionEnd(() => { this.onLeverEnd(); }))
    }
    .width(this.widthVp)
    .height(Y_GRID * this.sy)
    .hitTestBehavior(HitTestMode.Transparent)
  }
}

// ---------------------------------------------------------------------------
// 字篮（扇形井：曲线口＋3D 扇形＋枢轴＋井边阴影缝）
// ---------------------------------------------------------------------------
@Component
export struct Basket26 {
  @Prop machine: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop widthVp: number = 346.7;
  @Prop heightVp: number = 138;
  @Prop sx: number = 1;
  @Prop sy: number = 1;

  /** 井口曲线（矢高 14vp，按屏幕实际 vp 生成）。 */
  private wellPath(): string {
    const w: number = this.widthVp;
    const h: number = this.heightVp;
    const sag: number = 14 * (this.heightVp / 138);
    return 'M0 ' + sag.toFixed(1) + ' Q' + (w / 2).toFixed(1) + ' 0 ' + w.toFixed(1) + ' '
      + sag.toFixed(1) + ' L' + w.toFixed(1) + ' ' + h.toFixed(1) + ' L0 ' + h.toFixed(1) + ' Z';
  }

  private maskPath(): string {
    const w: number = this.widthVp;
    const sag: number = 14 * (this.heightVp / 138);
    return 'M0 -20 L' + w.toFixed(1) + ' -20 L' + w.toFixed(1) + ' ' + sag.toFixed(1)
      + ' Q' + (w / 2).toFixed(1) + ' 0 0 ' + sag.toFixed(1) + ' Z';
  }

  private arcPath(): string {
    const w: number = this.widthVp;
    const sag: number = 14 * (this.heightVp / 138);
    return 'M0 ' + sag.toFixed(1) + ' Q' + (w / 2).toFixed(1) + ' 0 ' + w.toFixed(1) + ' ' + sag.toFixed(1);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 井底（深色，随井口曲线裁）
      Path({ commands: this.wellPath() }).fill('#100e0c')
        .width(this.widthVp).height(this.heightVp)

      // 3D 扇形（占井宽 80%，枢轴在底部中央，顶部被井口罩住）
      Stack({ alignContent: Alignment.Bottom }) {
        basketFanImage(this.machine)
      }
      .width(277 * this.sx).height(174 * this.sy)
      .position({ x: (this.widthVp - 277 * this.sx) / 2, y: this.heightVp - 174 * this.sy })
      .hitTestBehavior(HitTestMode.None)

      // 井口罩（盖色）＋井边阴影缝（2–4px）
      Path({ commands: this.maskPath() }).fill(lidColor(this.machine))
        .width(this.widthVp).height(this.heightVp)
        .hitTestBehavior(HitTestMode.None)
      Path({ commands: this.arcPath() }).stroke('#000000').strokeWidth(1.2).fillOpacity(0)
        .width(this.widthVp).height(this.heightVp)
        .hitTestBehavior(HitTestMode.None)
      Path({ commands: this.arcPath() }).stroke('#6a6259').strokeWidth(0.6).fillOpacity(0)
        .width(this.widthVp).height(this.heightVp)
        .translate({ y: 1.2 })
        .hitTestBehavior(HitTestMode.None)

      // 枢轴（y 514 = 井底，x 181）
      Row()
        .width(26 * this.sx).height(8 * this.sy)
        .linearGradient({ direction: GradientDirection.Bottom, colors: [[STEEL_HI, 0.0], ['#4c4c4f', 1.0]] })
        .borderRadius(4)
        .position({ x: this.widthVp / 2 - 13 * this.sx, y: this.heightVp - 8 * this.sy })
    }
    .width(this.widthVp).height(this.heightVp)
    .clip(true)
  }
}

// ---------------------------------------------------------------------------
// 功能行（6 颗象牙键帽，融盖）
// ---------------------------------------------------------------------------
@Component
export struct FunctionCaps26 {
  @Prop widthVp: number = 346.7;
  @Prop heightVp: number = 36;
  @Prop sx: number = 1;
  @Prop sy: number = 1;
  @Prop langLabel: string = 'EN';
  @Prop langActive: boolean = false;
  @Prop symbolActive: boolean = false;
  onLang: () => void = (): void => {};
  onDelete: () => void = (): void => {};
  onNewline: () => void = (): void => {};
  onPaper: () => void = (): void => {};
  onBackLine: () => void = (): void => {};
  onSymbols: () => void = (): void => {};

  @Builder
  cap(label: string, idx: number, cb: () => void, active: boolean) {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [['#f4efe3', 0.0], ['#eae5d9', 0.5], ['#bfb6a4', 1.0]],
        })
        .borderRadius(4)
        .border({ width: 1, color: active ? '#c8322d' : '#8f8677' })
      if (label === 'BL') {
        // 退行：矢量箭头（不用 ↩ 字符，系统字体把它渲成蓝底 emoji）
        Stack({ alignContent: Alignment.TopStart }) {
          Path({ commands: 'M15 3 L4 3 L4 16' }).stroke('#241f1a').strokeWidth(1.6).fillOpacity(0)
            .width(17).height(18)
          Path({ commands: 'M0 0 L5 3.2 L0 6.4 Z' }).fill('#241f1a')
            .width(5).height(6.4).position({ x: 1.5, y: 12.4 })
        }
        .width(19).height(20)
        .translate({ y: -1.5 * this.sy })
      } else {
        Text(label)
          .fontSize(label.length > 1 ? 11 : 14)
          .fontColor('#241f1a')
          .fontFamily('CourierPrime')
          .maxLines(1)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ left: 2, right: 2 })
          .translate({ y: -1.5 * this.sy })
      }
    }
    .width(36 * this.sx).height(30 * this.sy)
    .position({ x: (idx * 36) * this.sx, y: 3 * this.sy })
    .onClick(() => { cb(); })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.cap(this.langLabel, 0, this.onLang, this.langActive)
      this.cap('⌫', 1, this.onDelete, false)
      this.cap('⏎', 2, this.onNewline, false)
      this.cap('↻', 3, this.onPaper, false)
      this.cap('BL', 4, this.onBackLine, false)
      this.cap('Aa', 5, this.onSymbols, this.symbolActive)
    }
    .width(this.widthVp).height(this.heightVp)
  }
}

// ---------------------------------------------------------------------------
// 字体条（盖上的刻字金属牌）
// ---------------------------------------------------------------------------
@Component
export struct FontPlate26 {
  @Prop widthVp: number = 346.7;
  @Prop heightVp: number = 28;
  @Prop sx: number = 1;
  @Prop sy: number = 1;
  @Prop label: string = 'Courier Prime';
  onFont: () => void = (): void => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(240 * this.sx).height(20 * this.sy)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [[BRASS_HI, 0.0], [BRASS, 0.5], ['#7a5f2e', 1.0]],
        })
        .borderRadius(2)
        .border({ width: 1, color: '#5c4720' })
      Text(this.label)
        .fontSize(11).fontColor('#2a1f10').fontFamily('CourierPrime').maxLines(1)
        .textAlign(TextAlign.Center).width(240 * this.sx)
        .translate({ y: -1 * this.sy })
    }
    .width(this.widthVp).height(this.heightVp)
    .onClick(() => { this.onFont(); })
  }
}

// ---------------------------------------------------------------------------
// 候选条（盖上的深色纸条；最多 5 个候选，超截断；无候选留空）
// ---------------------------------------------------------------------------
@Component
export struct CandStrip26 {
  @Prop widthVp: number = 346.7;
  @Prop heightVp: number = 44;
  @Prop sx: number = 1;
  @Prop sy: number = 1;
  @Prop candidates: string[] = [];
  @Prop pinyin: string = '';
  onPick: (i: number) => void = (_i: number): void => {};

  private shown(): string[] {
    const out: string[] = [];
    const n: number = this.candidates.length > 5 ? 5 : this.candidates.length;
    for (let i = 0; i < n; i++) {
      out.push(this.candidates[i]);
    }
    return out;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row()
        .width(300 * this.sx).height(30 * this.sy)
        .backgroundColor('#241f19')
        .border({ width: 1, color: '#4a4033' })
        .borderRadius(2)
        .position({ x: (this.widthVp - 300 * this.sx) / 2, y: 7 * this.sy })
      Row({ space: 12 * this.sx }) {
        if (this.pinyin.length > 0) {
          Text(this.pinyin + ' ').fontSize(13).fontColor('#b8a98f').fontFamily('CourierPrime')
        }
        ForEach(this.shown(), (c: string, i: number) => {
          Text(c)
            .fontSize(16).fontColor('#f0e8d8')
            .maxLines(1)
            .onClick(() => { this.onPick(i); })
        }, (c: string, i: number) => i.toString() + c)
      }
      .width(300 * this.sx)
      .justifyContent(FlexAlign.Center)
      .position({ x: (this.widthVp - 300 * this.sx) / 2, y: 14 * this.sy })
    }
    .width(this.widthVp).height(this.heightVp)
  }
}

// ---------------------------------------------------------------------------
// 纸（活纸：纸纹＋真文字＋落字点；连续纸条，上端被卷曲覆盖）
// ---------------------------------------------------------------------------
@Component
export struct PaperPanel26 {
  @Prop leftVp: number = 156;
  @Prop topVp: number = 104;
  @Prop widthVp: number = 220;
  @Prop heightVp: number = 258.4;
  @Prop sx: number = 1;
  @Prop sy: number = 1;
  @Prop lines: string[] = [];
  @Prop fontSizeVp: number = 11.9;
  @Prop lineHeightVp: number = 21;
  @Prop marginLVp: number = 25;
  @Prop marginRVp: number = 30;
  @Prop marginTVp: number = 12;
  @Prop fontFamily: string = 'CourierPrime';
  @Prop textColor: string = '#1a1a1a';
  @Prop cursorXVp: number = 25;
  @Prop cursorYVp: number = 12;
  /** 整卷上移量（光标行超出可见区时）。 */
  @Prop scrollYVp: number = 0;
  @Prop textureRawfile: string = 'paper-letter.png';

  private textW(): number {
    return this.widthVp - this.marginLVp - this.marginRVp;
  }

  @Builder
  texture() {
    // $rawfile 需字面量：按纸种静态分支
    if (this.textureRawfile === 'paper-manuscript.png') {
      Image($rawfile('ui-parts/paper-manuscript.png')).width('100%').height('100%').objectFit(ImageFit.Fill).opacity(0.55)
    } else if (this.textureRawfile === 'paper-postcard.png') {
      Image($rawfile('ui-parts/paper-postcard.png')).width('100%').height('100%').objectFit(ImageFit.Fill).opacity(0.55)
    } else if (this.textureRawfile === 'paper-memo.png') {
      Image($rawfile('ui-parts/paper-memo.png')).width('100%').height('100%').objectFit(ImageFit.Fill).opacity(0.55)
    } else {
      Image($rawfile('ui-parts/paper-letter.png')).width('100%').height('100%').objectFit(ImageFit.Fill).opacity(0.55)
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column().width('100%').height('100%').backgroundColor('#eee4ce')
      this.texture()
      // 纸面文字（行高 lineHeight，左内缩 marginL，上内缩 marginT；整卷随 typing 上移）
      Column() {
        ForEach(this.lines, (line: string, i: number) => {
          Text(line.length > 0 ? line : ' ')
            .fontSize(this.fontSizeVp)
            .fontFamily(this.fontFamily)
            .fontColor(this.textColor)
            .lineHeight(this.lineHeightVp)
            .width(this.textW())
            .textAlign(TextAlign.Start)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Clip })
        }, (line: string, i: number) => i.toString() + ':' + line)
      }
      .width(this.textW())
      .alignItems(HorizontalAlign.Start)
      .position({ x: this.marginLVp, y: this.marginTVp })
      .translate({ y: -this.scrollYVp })
      .hitTestBehavior(HitTestMode.None)

      // 落字点（细竖标）
      if (this.cursorYVp >= 0 && this.cursorYVp < this.heightVp) {
        Column().width(1.6).height(this.fontSizeVp + 5)
          .backgroundColor('#3a342c')
          .position({ x: this.marginLVp + this.cursorXVp, y: this.cursorYVp })
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width(this.widthVp).height(this.heightVp)
    .clip(true)
    .hitTestBehavior(HitTestMode.None)
  }
}
