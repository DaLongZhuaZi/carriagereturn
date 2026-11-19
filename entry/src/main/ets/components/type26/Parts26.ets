import { curves } from '@kit.ArkUI';
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
    Image($rawfile('ui-parts/tile-1920s-base-v2.png')).width('100%').height('100%').objectFit(ImageFit.Fill).opacity(1.0)
  } else if (machine === MachineKind.PORTABLE_1930S) {
    Image($rawfile('ui-parts/tile-1930s-base-v2.png')).width('100%').height('100%').objectFit(ImageFit.Fill).opacity(1.0)
  } else if (machine === MachineKind.STREAMLINED_1950S) {
    Image($rawfile('ui-parts/tile-1950s-base-v2.png')).width('100%').height('100%').objectFit(ImageFit.Fill).opacity(1.0)
  } else {
    Image($rawfile('ui-parts/tile-1960s-base-v2.png')).width('100%').height('100%').objectFit(ImageFit.Fill).opacity(1.0)
  }
}

/** 字篮扇形（生成件）。 */
@Builder
export function basketFanImage(machine: MachineKind) {
  if (machine === MachineKind.UPRIGHT_1920S) {
    Image($rawfile('ui-parts/basket-fan-3d-v4.png')).width('100%').height('100%').objectFit(ImageFit.Contain)
  } else if (machine === MachineKind.PORTABLE_1930S) {
    Image($rawfile('ui-parts/basket-fan-3d-v4.png')).width('100%').height('100%').objectFit(ImageFit.Contain)
  } else if (machine === MachineKind.STREAMLINED_1950S) {
    Image($rawfile('ui-parts/basket-fan-3d-v4.png')).width('100%').height('100%').objectFit(ImageFit.Contain)
  } else {
    Image($rawfile('ui-parts/basket-fan-3d-v4.png')).width('100%').height('100%').objectFit(ImageFit.Contain)
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

/** 批 37：按通道等量加减（L 对称移动，均值不变——用于盖面清漆渐变）。 */
export function shiftColor(hex: string, d: number): string {
  const h: string = hex.charAt(0) === '#' ? hex.substring(1) : hex;
  if (h.length < 6) { return '#adc4b8'; }
  const f: (v: number) => string = (v: number): string => {
    const x: number = Math.round(v + d);
    const c: number = x < 0 ? 0 : (x > 255 ? 255 : x);
    const t: string = c.toString(16);
    return t.length < 2 ? '0' + t : t;
  };
  return '#' + f(parseInt(h.substring(0, 2), 16)) + f(parseInt(h.substring(2, 4), 16)) + f(parseInt(h.substring(4, 6), 16));
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
  @Prop machine: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop widthVp: number = 362.7;
  @Prop heightVp: number = 104;
  @Prop sx: number = 1;
  @Prop sy: number = 1;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 批 38 §3：顶栏去黑——与盖面同色薄荷绿（四机各用本机 token）
      Column()
        .width('100%').height('100%')
        .backgroundColor('#00000000')
      Column().width('100%').height(1.2 * this.sy)
        .backgroundColor(shiftColor(lidColor(this.machine), -12))
        .position({ x: 0, y: this.heightVp - 1.2 * this.sy })
    }
    .width(this.widthVp).height(this.heightVp)
  }
}

/** 边距三角标记（批 36 修正：ArkUI 的 Path/Polygon fill 在真机不显色，改用逐行 Column 叠出三角，颜色必生效）。 */
@Component
export struct TriMark26 {
  @Prop w: number = 7;
  @Prop h: number = 6;
  @Prop sx: number = 1;
  @Prop sy: number = 1;
  @Prop color: string = '#c8322d';

  private stepRows(): number[] {
    const a: number[] = [];
    for (let i = 0; i < 8; i++) {
      a.push(i);
    }
    return a;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(this.stepRows(), (i: number) => {
        Column()
          .width((this.w * (8 - i) / 8) * this.sx)
          .height((this.h / 8) * this.sy)
          .backgroundColor(this.color)
          .position({
            x: (this.w * i / 16) * this.sx,
            y: (this.h * i / 8) * this.sy,
          })
      }, (i: number) => 'tri' + i.toString())
    }
    .width(this.w * this.sx).height(this.h * this.sy)
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
  onBell: () => void = (): void => {};
  onExportSlot: () => void = (): void => {};
  onPlate: () => void = (): void => {};

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 返回拨杆（x 8–24，y 48–80）：竖钢拨杆＋球头，与边铃横向错开
      Stack({ alignContent: Alignment.TopStart }) {
        Column().width(4 * this.sx).height(24 * this.sy)
          .linearGradient({ direction: GradientDirection.Right, colors: [[STEEL_HI, 0.0], [STEEL, 0.5], ['#4a4a4d', 1.0]] })
          .borderRadius(2)
          .rotate({ angle: 16 })
          .position({ x: 8 * this.sx, y: 5 * this.sy })
        Column().width(9 * this.sx).height(9 * this.sx)
          .backgroundColor(BRASS_HI)
          .border({ width: 1, color: '#5a4520' })
          .borderRadius(5 * this.sx)
          .position({ x: 4 * this.sx, y: 0 })
      }
      .width(16 * this.sx).height(32 * this.sy)
      .position({ x: 8 * this.sx, y: 48 * this.sy })
      .onClick(() => { this.onBack(); })

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
      .position({ x: 300 * this.sx, y: 14 * this.sy })
      .onClick(() => { this.onExportSlot(); })

    }
    .width(this.widthVp).height(this.heightVp)
    .clip(true)
    // 空白处不挡下面字车拨杆的拖拽（子件仍各自可点）
    .hitTestBehavior(HitTestMode.Transparent)
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
      // 批 42：沉孔暗环（比盖面暗 L≈0.06）→ 盘面（上亮下暗）→ 一字槽（长 70%、带高光边）
      Column().width(11 * this.sx).height(11 * this.sx)
        .backgroundColor('#0e1a15').opacity(0.45).borderRadius(5.5 * this.sx)
        .position({ x: -2.5 * this.sx, y: -2 * this.sy })
      Column().width(7 * this.sx).height(7 * this.sx)
        .linearGradient({ direction: GradientDirection.Bottom,
          colors: [['#e6e6ea', 0.0], ['#a9a9b0', 0.45], ['#5f5f66', 1.0]] })
        .borderRadius(3.5 * this.sx)
      Column().width(4.9 * this.sx).height(1.2 * this.sy)
        .backgroundColor('#2b2b2e').rotate({ angle: 24 })
      Column().width(4.9 * this.sx).height(0.5 * this.sy)
        .backgroundColor('#f2f2f5').opacity(0.55).rotate({ angle: 24 })
        .translate({ x: 0, y: -0.8 * this.sy })
    }
    .width(6 * this.sx).height(6 * this.sx)
    .position({ x: cx * this.sx - 3 * this.sx, y: cy * this.sy - 3 * this.sx })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 批 38 §1a：光滑珐琅——纯色底＋边缘倒角线（1.5vp、比 token 亮 L+0.08）
      Column().width('100%').height('100%').backgroundColor(lidColor(this.machine))
        .hitTestBehavior(HitTestMode.None)
      // 批 40（任务 1）：机盖柔光改预渲染贴图（真机 radial/blur 会出黄块，一律走 PNG 1:1 叠加）
      Image($rawfile('ui-parts/lid-sheen-v2.png'))
        .width('100%').height('100%').objectFit(ImageFit.Contain)
        .hitTestBehavior(HitTestMode.None)

      // 批 38 §1b：边缘倒角线（最上层，1.5vp、比 token 亮 L+0.08，沿盖面边缘一圈）
      Column().width('100%').height('100%')
        .border({ width: 1.5 * this.sx, color: shiftColor(lidColor(this.machine), 26) })
        .hitTestBehavior(HitTestMode.None)

      // 字篮井区左右各两颗螺丝（上沿 y390、腰部 y470）
      this.screw(24, 200)
      this.screw(338, 200)
      this.screw(24, 390)
      this.screw(338, 390)
      this.screw(24, 470)
      this.screw(338, 470)
      this.screw(24, 700)
      this.screw(338, 700)
    }
    .width(this.widthVp).height(this.heightVp)
    .clip(true)
  }
}

// ---------------------------------------------------------------------------
// 字篮（扇形井：曲线口＋3D 扇形＋枢轴＋井边阴影缝）
// ---------------------------------------------------------------------------
@Component
export struct Basket26 {
  /** 批 61：Shift 抬扇（0／−10vp，组件侧弹簧驱动；只抬扇、井背不动）。 */
  @Prop shiftLiftVp: number = 0;
  @Prop machine: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop widthVp: number = 240;
  @Prop heightVp: number = 138;
  @Prop sx: number = 1;
  @Prop sy: number = 1;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 井：曲线口（顶部半圆拱；井宽 240 → 拱半径 120，矢高 138vp＝466px）
      Stack({ alignContent: Alignment.Bottom }) {
        // 批 38 §2：井底去黑——与盖面同色薄荷绿（扇直接长在机身上）
        Column().width('100%').height('100%').backgroundColor(lidColor(this.machine))
        // 批 40（任务 3）：井背改预渲染贴图（纵向渐变＋7 道杆影，上亮下暗）
        Image($rawfile('ui-parts/fanwell-back-v2.png'))
          .width('100%').height('100%').objectFit(ImageFit.Contain)
          .position({ x: 0, y: 0 })
          .hitTestBehavior(HitTestMode.None)
        // 3D 扇形：缩进井里——高 134（扇顶 y 380，在色带 370–374 下方），宽 213（等比）
        Stack({ alignContent: Alignment.Bottom }) {
          basketFanImage(this.machine)
        }
        .width(213 * this.sx).height(126.3 * this.sy)
        // 批 61：Shift 抬扇——整扇上抬 10vp，弹簧（轻微过冲）；显示盒不变，只加 translate
        .translate({ y: this.shiftLiftVp * this.sy })
        .animation({ duration: 260, curve: curves.springMotion(0.3, 0.55) })
        .shadow({ radius: 11, color: '#00000040', offsetX: 0, offsetY: 3 })
        .hitTestBehavior(HitTestMode.None)
      }
      .width(this.widthVp).height(this.heightVp)
      .borderRadius({ topLeft: this.widthVp / 2, topRight: this.widthVp / 2, bottomLeft: 0, bottomRight: 0 })
      .clip(true)
      // 批 38 §2：井口曲线＝一条细阴影线（1.2vp、黑 50%），不再是一圈实黑
      .border({ width: 1.2 * this.sx, color: '#00000080' })

      // 批 39（任务 4）：扇井口沿在盖面上留一道软影（实色低透明，右下偏移）
      Column().width(this.widthVp * 0.9).height(10 * this.sy)
        .backgroundColor('#0b1a14').opacity(0.10).borderRadius(5 * this.sy)
        .position({ x: this.widthVp * 0.05, y: this.heightVp - 4 * this.sy })
        .hitTestBehavior(HitTestMode.None)

      // 枢轴（井底中央 y 514、x 181）——批 42：加接触影＋同心环纹＋中心铆钉点
      Column().width(24 * this.sx).height(3 * this.sy)
        .backgroundColor('#000000').opacity(0.10).borderRadius(2 * this.sx)
        .position({ x: this.widthVp / 2 - 12 * this.sx, y: this.heightVp - 1 * this.sy })
        .hitTestBehavior(HitTestMode.None)
      Row()
        .width(26 * this.sx).height(8 * this.sy)
        .linearGradient({ direction: GradientDirection.Bottom, colors: [[STEEL_HI, 0.0], ['#4c4c4f', 1.0]] })
        .borderRadius(4)
        .position({ x: this.widthVp / 2 - 13 * this.sx, y: this.heightVp - 8 * this.sy })
      Circle().width(9 * this.sx).height(9 * this.sx)
        .fill('#00000000').border({ width: 0.5 * this.sx, color: '#00000055' })
        .position({ x: this.widthVp / 2 - 4.5 * this.sx, y: this.heightVp - 7.5 * this.sy })
        .hitTestBehavior(HitTestMode.None)
      Circle().width(5 * this.sx).height(5 * this.sx)
        .fill('#00000000').border({ width: 0.5 * this.sx, color: '#00000066' })
        .position({ x: this.widthVp / 2 - 2.5 * this.sx, y: this.heightVp - 5.5 * this.sy })
        .hitTestBehavior(HitTestMode.None)
      Circle().width(2.5 * this.sx).height(2.5 * this.sx)
        .fill('#d8d8dc').opacity(0.85)
        .position({ x: this.widthVp / 2 - 1.25 * this.sx, y: this.heightVp - 4.25 * this.sy })
        .hitTestBehavior(HitTestMode.None)
    }
    .width(this.widthVp).height(this.heightVp)
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
        .shadow({ radius: 4, color: '#00000088', offsetX: 0, offsetY: 2 })
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
      Column().width(38 * this.sx).height(2 * this.sy).backgroundColor('#2a221b')
        .position({ x: -1 * this.sx, y: 31 * this.sy })
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
        .shadow({ radius: 3, color: '#00000099', offsetX: 0, offsetY: 1 })
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
  @Prop machine: MachineKind = MachineKind.UPRIGHT_1920S;
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
        .backgroundColor(this.machine === MachineKind.STREAMLINED_1950S ? '#e8dfcc' : '#241f19')
        .border({ width: 1.2, color: this.machine === MachineKind.STREAMLINED_1950S ? '#7a6647' : '#0b0908' })
        .borderRadius(2)
        .shadow({ radius: 3, color: '#00000099', offsetX: 0, offsetY: 1 })
        .position({ x: (this.widthVp - 300 * this.sx) / 2, y: 7 * this.sy })
      Row({ space: 12 * this.sx }) {
        if (this.pinyin.length > 0) {
          Text(this.pinyin + ' ').fontSize(13)
            .fontColor(this.machine === MachineKind.STREAMLINED_1950S ? '#5a4a33' : '#b8a98f')
            .fontFamily('CourierPrime')
        }
        ForEach(this.shown(), (c: string, i: number) => {
          Text(c)
            .fontSize(16)
            .fontColor(this.machine === MachineKind.STREAMLINED_1950S ? '#241f19' : '#f0e8d8')
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
  /** 批 36 §4.3：纸面标题（文档名）与页码（右上）。 */
  @Prop docTitle: string = '';
  @Prop pageNo: string = '';
  /** 批 43：装纸/出纸时标题与光标淡入淡出（纸纹理不参与）。 */
  @Prop contentOpacity: number = 1;
  /** 批 39 任务 8：打击相位 0..1（字杆影／色带影同步）。 */
  @Prop strikePhase: number = 0;

  private textW(): number {
    return this.widthVp - this.marginLVp - this.marginRVp;
  }

  @Builder
  texture() {
    // 批 39（任务 7）：统一换成 paper-cream-v1 中性纸纹理——opacity 1.0、Cover（等比缩放＋居中裁切，不 Fill 硬拉）
    // 批 44：纸 v2——顶缘卷曲＋厚度＋卷底淡影已烤进贴图（1484×2066，与纸盒 0.7183 一致）
    Image($rawfile('ui-parts/paper-cream-v5.png'))
      .width('100%').height('100%').objectFit(ImageFit.Contain).opacity(1.0)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column().width('100%').height('100%').backgroundColor('#faf8f2')
      this.texture()
      // 批 39 任务 7：左右纸边极淡阴影（1.5vp、黑 9%），读得出纸有厚度
      Column().width(1.5 * this.sx).height('100%')
        .linearGradient({ direction: GradientDirection.Right, colors: [['#00000017', 0.0], ['#00000000', 1.0]] })
        .position({ x: 0, y: 0 })
        .hitTestBehavior(HitTestMode.None)
      Column().width(1.5 * this.sx).height('100%')
        .linearGradient({ direction: GradientDirection.Left, colors: [['#00000017', 0.0], ['#00000000', 1.0]] })
        .position({ x: this.widthVp - 1.5 * this.sx, y: 0 })
        .hitTestBehavior(HitTestMode.None)
      // 批 39 任务 8：纸下沿静影（横尺压住纸下缘的上下关系，2vp）
      Column().width('100%').height(2 * this.sy)
        .linearGradient({ direction: GradientDirection.Top, colors: [['#0000001a', 0.0], ['#00000000', 1.0]] })
        .position({ x: 0, y: this.heightVp - 2 * this.sy })
        .hitTestBehavior(HitTestMode.None)
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
      .position({
        x: this.marginLVp,
        y: this.marginTVp,   // 批 47：纸上无标题，正文从内边距处开始
      })
      .translate({ y: -this.scrollYVp })
      .hitTestBehavior(HitTestMode.None)

      // 落字点（细竖标）
      if (this.cursorYVp >= 0 && this.cursorYVp < this.heightVp) {
        Column().width(1.6).height(this.fontSizeVp + 2)
          .backgroundColor('#3a342c')
          .opacity(this.contentOpacity)
          // 批 48：光标垂直居中到字上（行高 31.5、光标 13.9 → 下移 ≈8.8vp）
          .position({ x: this.marginLVp + this.cursorXVp,
            y: this.cursorYVp + (this.lineHeightVp - (this.fontSizeVp + 2)) / 2 })
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width(this.widthVp).height(this.heightVp)
    .clip(true)
    .hitTestBehavior(HitTestMode.None)
  }
}
