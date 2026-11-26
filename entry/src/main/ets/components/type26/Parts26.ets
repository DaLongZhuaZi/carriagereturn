import { curves } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
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
interface CapArgs {
  label: string;
  idx: number;
  cb: () => void;
  active: boolean;
}

@Component
export struct TopDeck26 {
  @Prop machine: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop widthVp: number = 362.7;
  @Prop heightVp: number = 104;
  @Prop sx: number = 1;
  @Prop sy: number = 1;

  /**
   * 批 75：按**机盖 base 的明度**分浅/深两支（不再写死 1950s）。
   * 相对亮度 = 0.299R + 0.587G + 0.114B；>140 视为浅 base。
   * 实测：1920s #1e1c1a=28.3 深／1930s #3a4038=61.3 深／
   *       1950s #d8cbb0=203.9 浅／1960s #a8a8a0=167.0 浅／2020s #adc4b8=187.8 浅。
   */
  private isLightBase(): boolean {
    const hex: string = tierToken(this.machine, 'base');
    const h: string = hex.charAt(0) === '#' ? hex.substring(1) : hex;
    if (h.length < 6) { return false; }
    const r: number = parseInt(h.substring(0, 2), 16);
    const g: number = parseInt(h.substring(2, 4), 16);
    const b: number = parseInt(h.substring(4, 6), 16);
    return (0.299 * r + 0.587 * g + 0.114 * b) > 140;
  }

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
  onExportSlot: () => void = (): void => {};

  build() {
    // 批 64（T8）：顶栏改 flex 行——返回拨杆在左、出纸槽在右（Blank 撑开），两者顶边都落在 48·sy
    // （批 63 实测：y=14·sy 会被画到状态栏底下，节点 y≈76px、屏上不可见）。
    // 右内距 = 机器宽 − 350·sx，使槽口左缘仍落在 300·sx（N6 的 (1170,149) 不变）。
    Column() {
      Row() {
        // 这里保持最简结构：视觉件本体挂 onClick，不再套热区壳。
        // 返回拨杆（竖钢拨杆＋球头，与边铃横向错开）
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
        // E4/I-1：热区放大到 ≥44×44vp（原 16×32vp 太小）；拨杆造型与枢轴位置不动
        .width(44 * Math.max(1, this.sx)).height(44 * Math.max(1, this.sy))
        .id('typewriter__lever')
        .accessibilityText('返回')
        .accessibilityLevel('yes')
        .onClick(() => { this.onBack(); })

        Blank()

        // 出纸槽（行内右侧子项；点按行为＝导出 txt ＋ 300ms 纸片滑出，hilog 三连可证）
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
        .id('p26_export_slot')
        .accessibilityText('出纸槽')
        .accessibilityLevel('yes')
        .onClick(() => { this.onExportSlot(); })
      }
      .width('100%')
      .padding({ left: 8 * this.sx, right: this.padRightSlot() })
      .alignItems(VerticalAlign.Top)
    }
    .width(this.widthVp).height(this.heightVp)
    .padding({ top: 48 * this.sy })
    .alignItems(HorizontalAlign.Start)
    .clip(true)
    // 空白处不挡下面字车拨杆的拖拽（子件仍各自可点）
    .hitTestBehavior(HitTestMode.Transparent)
  }

  /** 出纸槽右内距：让槽口左缘落在 300·sx（机器宽不足时保底 4vp）。 */
  private padRightSlot(): number {
    const p: number = this.widthVp - 350 * this.sx;
    return p > 4 ? p : 4;
  }
}

// ---------------------------------------------------------------------------
// 盖子（机身）：木纹＋柔光＋字篮区 4 颗螺丝（另 4 颗在钢板四角，由 KeyWell 开孔露出）
// ---------------------------------------------------------------------------

/**
 * 批 78：柔光素材是同一设计的两种画幅（数值是**素材自身属性**，不是设备常量）：
 *   手机版 `lid-sheen-v2.png`     1224×2776 ⇒ 0.4409
 *   平板宽版 `lid-sheen-v2-wide.png` 1600×2560 ⇒ 0.625
 * 选图只比「盖板盒宽高比（widthVp/heightVp）更接近哪张」，再配 ImageFit.Contain——
 * 盒比与图比 1:1 ⇒ 铺满且零拉伸（不再需要 Fill 例外）。
 */
const LID_SHEEN_ASPECT_PHONE: number = 1224 / 2776;
const LID_SHEEN_ASPECT_WIDE: number = 1600 / 2560;
const LID_LOG_TAG: string = 'Lid26';
const LID_LOG_DOMAIN: number = 0x0100;

@Component
export struct Lid26 {
  @Prop machine: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop widthVp: number = 362.7;
  @Prop heightVp: number = 822.5;
  @Prop sx: number = 1;
  @Prop sy: number = 1;
  @Prop topVp: number = 104;

  /** 批 78：选图打点（每次盖板组件创建一次，供真机取证）。 */
  aboutToAppear(): void {
    hilog.info(LID_LOG_DOMAIN, LID_LOG_TAG, 'lidSheen wide=%{public}d aspect=%{public}s',
      this.lidSheenWide() ? 1 : 0, this.lidAspect().toFixed(4));
  }

  /** 盖板盒宽高比：由布局量 widthVp/heightVp 派生（异常值回落手机画幅）。 */
  private lidAspect(): number {
    if (this.widthVp > 0 && this.heightVp > 0) {
      return this.widthVp / this.heightVp;
    }
    return LID_SHEEN_ASPECT_PHONE;
  }

  /** 批 78：盒比更接近平板画幅（0.625）用宽版，否则用手机原图（0.4409）。 */
  private lidSheenWide(): boolean {
    const a: number = this.lidAspect();
    return Math.abs(a - LID_SHEEN_ASPECT_WIDE) < Math.abs(a - LID_SHEEN_ASPECT_PHONE);
  }

  /** 柔光层：Contain＋等画幅图 ⇒ 1:1 铺满、不拉伸、无留白。 */
  @Builder
  sheen() {
    if (this.lidSheenWide()) {
      Image($rawfile('ui-parts/lid-sheen-v2-wide.png'))
        .width('100%').height('100%').objectFit(ImageFit.Contain)
        .hitTestBehavior(HitTestMode.None)
    } else {
      Image($rawfile('ui-parts/lid-sheen-v2.png'))
        .width('100%').height('100%').objectFit(ImageFit.Contain)
        .hitTestBehavior(HitTestMode.None)
    }
  }

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
      // 批 40（任务 1）：机盖柔光改预渲染贴图（真机 radial/blur 会出黄块，一律走 PNG 叠加）；
      // 批 78：按盖板盒宽高比选画幅＋Contain（盒比＝图比 1:1，铺满不拉伸，取消 Fill 例外）。
      this.sheen()

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
// 字篮（扇形井：曲线口＋字盘／字杆扇＋井边阴影缝）
// ---------------------------------------------------------------------------

/**
 * 批 77／批 79：字杆的 QWERTY 排布——42 个字符键按**键盘 x 从左到右**排序（数据源＝
 * keymap 1920s-upright-keymap.json；五台机 keymap 同布局）。x 只用来定顺序，不进布局算式。
 *
 * 2026-11-19 定稿（批 77 按此整块重做；批 79 修正字头行最左一块）：
 *  - 枢轴在**井顶**（纸面/压纸滚筒一侧），字杆从枢轴向下垂进篮子，静止字头在篮底；
 *  - 静止排布 **Q 最左（−45°）**、H 中间（+3°）、P 最右（+45°），左键左倾、右键右倾；
 *  - 批 79（任务 2）：键盘 x 小于 Q 的键（A、1）不走「排在最左」，一律移到 Q 右侧紧邻，
 *    字头行第一块从此恒为 Q，其次 1、A；其余键保持键盘 x 顺序；
 *  - 细密薄杆 40 多根（本批 42 根，杆宽 1.6×sx），小字头块排在底缘弧上；
 *  - 打击几何：真实杆长＝井高×74/138，静止字头＝枢轴正下方同距，打击点＝枢轴正上方同距
 *    （180° 对称，(181,426)→(181,500)、(181,351.5)），所有键同一落点。
 *    TypebarLayer 打击动画仍暂缓；本静态扇的枢轴／角度排布与该几何同源。
 */
const TB_KEYS: string[] = [
  'Q', '1', 'A', 'S', '2', 'Z', 'W', 'D', '3', 'X', 'E', 'F', '4', 'C', 'R', 'G', '5', 'V',
  'T', 'H', '6', 'B', 'Y', 'J', '7', 'N', 'U', 'K', '8', 'M', 'I', 'L', '9', ',', 'O', ';',
  '0', '.', 'P', "'", '-', '/'
];
/** 三锚点在 TB_KEYS 里的下标（批 79：Q 移到第 0 位；H／P 原位不动）。 */
const TB_I_Q: number = 0;
const TB_I_H: number = 19;
const TB_I_P: number = 38;
const TB_I_LAST: number = 41;

@Component
export struct Basket26 {
  /** 批 61：Shift 抬扇（0／−10vp，组件侧弹簧驱动；只抬扇、井背不动）。 */
  @Prop shiftLiftVp: number = 0;
  @Prop machine: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop widthVp: number = 240;
  @Prop heightVp: number = 138;
  @Prop sx: number = 1;
  @Prop sy: number = 1;
  /** 批 66：是否用 2.6 宽版扇图（平板 true、手机 false）。 */
  @Prop fanWide: boolean = false;
  /** 批 66：当前扇图的宽高比（平板 2.6、手机 1.69），用于让盒高正好等于图高。 */
  @Prop fanAspect: number = 1.69;

  /** 批 22～批 76：扇图盒比（`fanWide`／`fanAspect` 仍由 Index 传入；批 77 起扇改代码画，盒比不再参与）。 */

  /** 批 76：杆影道数——由井宽派生，不写死。N = max(5, floor(井宽 / 30vp))。 */
  private stemCount(): number {
    const n: number = Math.floor(this.widthVp / 30);
    return n > 5 ? n : 5;
  }

  /** 批 76：0..N-1 索引数组（ForEach 用）。 */
  private stemIndexes(): number[] {
    const out: number[] = [];
    const n: number = this.stemCount();
    for (let i = 0; i < n; i++) {
      out.push(i);
    }
    return out;
  }

  /** 批 76：第 i 道杆影的 x（N 道均匀，间距 = 井宽/(N+1)）。 */
  private stemShadowX(i: number): number {
    const n: number = this.stemCount();
    return this.widthVp / (n + 1) * (i + 1) - 0.75 * this.sx;
  }

  /**
   * 批 77：枢轴竖直位置＝井高 × 50/138。
   * 定稿几何（26 号稿基准）：井顶 376、篮高 138 ⇒ 枢轴 (181, 426)，静止字头 (181, 500)。
   * 不写死 50vp：换分辨率时按井高等比走。
   */
  private pivotY(): number {
    return this.heightVp * (50 / 138);
  }

  /** 批 77：静止字头到枢轴的竖直距离＝井高 × 74/138（定稿杆长 74vp／篮高 138vp）。 */
  private restDrop(): number {
    return this.heightVp * (74 / 138);
  }

  /**
   * 批 77：张角上界——由**井宽与井高共同派生**。
   * 杆头落在井底浅弧上，横向上把两侧填到 94% 井宽：
   *   θmax = atan(0.47×井宽 ÷ (0.94×静止下坠))。
   * 手机 240×120.5 ⇒ 61.7°，平板 445.8×145.7 ⇒ 70.7°。
   * 批 76 的 ±38° 固定张角是手机扇只占井中央一半、平板只占三分之一的根因。
   */
  private spreadDeg(): number {
    const halfW: number = this.widthVp * 0.47;
    const edgeDrop: number = this.restDrop() * 0.94;
    const deg: number = Math.atan2(halfW, edgeDrop) * 180 / Math.PI;
    return deg;
  }

  /** 批 77：杆头下坠量——中杆最深，两侧浅 6%（底缘浅弧，井下方不留大块空白）。 */
  private dropFor(deg: number): number {
    const u: number = Math.abs(deg) / this.spreadDeg();
    return this.restDrop() * (1 - 0.06 * u * u);
  }

  /**
   * 批 77／批 79：第 i 根字杆的角度（度）。三锚点按定稿标定：
   * Q（i=0）＝−45°、H（i=19）＝+3°、P（i=38）＝+45°。
   * 批 79：Q 是字头行**第一块**（−45° 锚点不变），左侧不再有 θmax 外延段；
   * P 之后的 3 根（' - /）仍按 θmax 向右展开（θmax 由 spreadDeg() 按井宽/井高派生，不写死）。
   * 全程分段线性，段内等步长；批 76 的 A–Z 循环字母与 ±38° 固定张角作废。
   */
  private barAngle(i: number): number {
    const top: number = this.spreadDeg();
    if (i <= TB_I_H) {
      return -45 + (i / TB_I_H) * 48;
    }
    if (i <= TB_I_P) {
      return 3 + ((i - TB_I_H) / (TB_I_P - TB_I_H)) * 42;
    }
    return 45 + ((i - TB_I_P) / (TB_I_LAST - TB_I_P)) * (top - 45);
  }

  /**
   * 批 77：第 i 根字杆的画长＝下坠量 / cosθ（正视图里字头落在底缘浅弧上）。
   * 定稿的**真实杆长**是 restDrop()（74/138×井高，所有键相同，打击点才同点）；
   * 这里的画长是正视图 3D 投影（两侧杆看起来更长），与 v4 扇素材同一口径。
   */
  private barLength(i: number): number {
    const deg: number = this.barAngle(i);
    const c: number = Math.cos(deg * Math.PI / 180);
    return this.dropFor(deg) / (c > 0.02 ? c : 0.02);
  }

  /** 批 77：第 i 根字杆的字头字符＝键盘字符（QWERTY 排布，不再 A–Z 循环）。 */
  private barLetter(i: number): string {
    return TB_KEYS[i];
  }

  /** 批 77：字杆数＝42（keymap 的 42 个字符键）——"40 多根细密薄杆"。 */
  private barIndexes(): number[] {
    const out: number[] = [];
    for (let i = 0; i <= TB_I_LAST; i++) {
      out.push(i);
    }
    return out;
  }

  /** 批 77：字头块边长——由中段相邻字头的弧长间距派生（≈1 个间距：成排紧挨，不叠死也不留缝）。 */
  private plateSize(): number {
    const minStepDeg: number = Math.min(48 / (TB_I_H - TB_I_Q), 42 / (TB_I_P - TB_I_H));
    const step: number = this.restDrop() * minStepDeg * Math.PI / 180;
    const s: number = step * 1.15;
    const lo: number = 2.6 * this.sx;
    const hi: number = 4.8 * this.sx;
    return s < lo ? lo : (s > hi ? hi : s);
  }

  /** 批 77：字头块底色——钢 token 提亮，保证小字（#141414）在 6–10px 尺寸下仍可辨。 */
  private plateColor(): string {
    return lighten(tierToken(this.machine, 'steel'), 0.32);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 井：曲线口（顶部半圆拱；井宽 240 → 拱半径 120，矢高 138vp＝466px）
      Stack({ alignContent: Alignment.Bottom }) {
        // 批 38 §2：井底去黑——与盖面同色薄荷绿（扇直接长在机身上）
        Column().width('100%').height('100%').backgroundColor(lidColor(this.machine))
        // 批 76：井背改**代码画**（替掉批 40 的 fanwell-back-v2.png 定图，文件留仓）
        // 上＝paperwell 浅、下＝base 深，随 tierToken 自动跟机型色——根治批 75 补记的「定图不跟 base、露浅薄荷绿块」
        Column().width('100%').height('100%')
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [[tierToken(this.machine, 'paperwell'), 0.0], [tierToken(this.machine, 'base'), 1.0]]
          })
          .position({ x: 0, y: 0 })
          .hitTestBehavior(HitTestMode.None)
        // 批 76：杆影 N 道（N 与字杆同源，间距 = 井宽/(N+1)），只画在井背层、不压扇
        ForEach(this.stemIndexes(), (i: number) => {
          Column().width(1.5 * this.sx).height(this.heightVp)
            .backgroundColor('#000000').opacity(0.10).borderRadius(0.75 * this.sx)
            .position({ x: this.stemShadowX(i), y: 0 })
            .hitTestBehavior(HitTestMode.None)
        }, (i: number) => 'p76sh' + i.toString())
        // 批 77：字杆扇——**枢轴在井顶**，42 根细杆向下垂、字头块沿底缘浅弧排开。
        // 每根：杆身（上端深、下端亮）＋底端字头块（钢座 + 键字符）。
        // 旋转中心＝杆顶（centerY 0）＝枢轴；杆长/角度由井宽井高派生（见 barAngle/barLength）。
        Stack({ alignContent: Alignment.TopStart }) {
          ForEach(this.barIndexes(), (i: number) => {
            Column() {
              // 杆身（上段，长度＝画长扣掉字头块）
              Column()
                .width(1.6 * this.sx).height(Math.max(0, this.barLength(i) - this.plateSize()))
                .linearGradient({
                  direction: GradientDirection.Bottom,
                  colors: [['#4c4c4f', 0.0], [STEEL_HI, 1.0]]
                })
                .borderRadius(0.8 * this.sx)
                .hitTestBehavior(HitTestMode.None)
              // 字头块（杆的下端）：钢座 + 键字符
              Column() {
                Text(this.barLetter(i)).fontSize(0.72 * this.plateSize())
                  .fontColor('#141414').maxLines(1)
              }
              .width(this.plateSize()).height(this.plateSize())
              .backgroundColor(this.plateColor())
              .border({ width: 0.5 * this.sx, color: darken(tierToken(this.machine, 'steel'), 0.15) })
              .borderRadius(0.8 * this.sx)
              .justifyContent(FlexAlign.Center)
              .hitTestBehavior(HitTestMode.None)
            }
            // 批 77（批 76 实发教训）：外层 Column **必须显式定高**，否则被父 Stack 的井高截短、
            // 杆顶离开枢轴（平板最短时曾在下半部穿插成 X）。
            .width(this.plateSize()).height(this.barLength(i))
            .position({ x: this.widthVp / 2 - this.plateSize() / 2, y: this.pivotY() })
            // 旋转中心＝杆顶（centerY 0）＝井顶枢轴；杆向下垂、两翼张开。
            // 批 79（任务 2）：**取负号**——ArkUI rotate 正角是顺时针，向下垂的杆顺时针摆会往左；
            // 而定稿角度（Q −45°／H +3°／P +45°）是数学正角（正角＝向右）。
            // 批 77 直接传原值 ⇒ 整排左右镜像（A 落到最右、Q 落到右侧），本批纠正。
            .rotate({ angle: -this.barAngle(i), centerX: '50%', centerY: 0 })
            .hitTestBehavior(HitTestMode.None)
          }, (i: number) => 'p77bar' + i.toString())
        }
        .width(this.widthVp).height(this.heightVp)
        // 批 61：Shift 抬扇——整组字杆同上抬（只抬杆，不抬字盘；杆顶滑进字盘下沿，不露缝）
        .translate({ y: this.shiftLiftVp })
        .animation({ duration: 260, curve: curves.springMotion(0.3, 0.55) })
        .shadow({ radius: 11, color: '#00000040', offsetX: 0, offsetY: 3 })
        .hitTestBehavior(HitTestMode.None)
        // 批 77：字盘（枢轴毂）——压在杆顶，盖住杆根；尺寸由井宽/井高派生
        Stack({ alignContent: Alignment.TopStart }) {
          Column().width(this.widthVp * 0.44).height(this.heightVp * 0.26)
            .linearGradient({
              direction: GradientDirection.Bottom,
              colors: [[STEEL_HI, 0.0], [tierToken(this.machine, 'steel'), 0.55], ['#3a3a3d', 1.0]]
            })
            .borderRadius({
              topLeft: this.widthVp * 0.22, topRight: this.widthVp * 0.22,
              bottomLeft: 2 * this.sx, bottomRight: 2 * this.sx
            })
            .border({ width: 1 * this.sx, color: '#2a2a2c' })
          // 杆出口暗槽（字盘下沿中央）
          Column().width(this.widthVp * 0.30).height(2.8 * this.sy)
            .backgroundColor('#0d0d0f').opacity(0.75).borderRadius(1.4 * this.sy)
            .position({ x: this.widthVp * 0.07, y: this.heightVp * 0.26 - 4.2 * this.sy })
          // 三颗铆钉
          Circle().width(2.4 * this.sx).height(2.4 * this.sx).fill('#9a9aa0')
            .border({ width: 0.5 * this.sx, color: '#2a2a2c' })
            .position({ x: this.widthVp * 0.09, y: this.heightVp * 0.06 })
            .hitTestBehavior(HitTestMode.None)
          Circle().width(2.4 * this.sx).height(2.4 * this.sx).fill('#9a9aa0')
            .border({ width: 0.5 * this.sx, color: '#2a2a2c' })
            .position({ x: this.widthVp * 0.33, y: this.heightVp * 0.06 })
            .hitTestBehavior(HitTestMode.None)
          Circle().width(1.8 * this.sx).height(1.8 * this.sx).fill('#6f6f74')
            .position({ x: this.widthVp * 0.21, y: this.heightVp * 0.025 })
            .hitTestBehavior(HitTestMode.None)
        }
        .width(this.widthVp * 0.44).height(this.heightVp * 0.26)
        .position({ x: this.widthVp * 0.28, y: this.pivotY() - this.heightVp * 0.26 })
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
  @Prop langActive: boolean = false;
  /** F5/R17：语言键标签直接订阅 AppStorage 字符串，切中英后必刷新。 */
  @StorageLink('langLabel') langDyn: string = 'EN';
  @StorageLink('langZh') zhState: boolean = false;
  @Prop symbolActive: boolean = false;
  /** 批 71：功能行按下态（-1＝无）。与 KeyGrid.pressedId 同口径，驱动下沉 2vp + scaleY 0.94。 */
  @State pressedIdx: number = -1;
  onLang: () => void = (): void => {};
  onDelete: () => void = (): void => {};
  onNewline: () => void = (): void => {};
  onPaper: () => void = (): void => {};
  onBackLine: () => void = (): void => {};
  onSymbols: () => void = (): void => {};

  /** F5：@Builder 用单个对象参数（按引用），标签/按下态才会随状态刷新。 */
  @Builder
  cap(args: CapArgs) {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [['#f4efe3', 0.0], ['#eae5d9', 0.5], ['#bfb6a4', 1.0]],
        })
        .borderRadius(4)
        .border({ width: 1, color: args.active ? '#c8322d' : '#8f8677' })
        .shadow({ radius: 4, color: '#00000088', offsetX: 0, offsetY: 2 })
      if (args.label === 'BL') {
        // 退行：矢量箭头（不用 ↩ 字符，系统字体把它渲成蓝底 emoji）
        Stack({ alignContent: Alignment.TopStart }) {
          Path({ commands: 'M15 3 L4 3 L4 16' }).stroke('#241f1a').strokeWidth(1.6).fillOpacity(0)
            .width(17).height(18)
          Path({ commands: 'M0 0 L5 3.2 L0 6.4 Z' }).fill('#241f1a')
            .width(5).height(6.4).position({ x: 1.5, y: 12.4 })
        }
        .width(19 * this.sx).height(20 * this.sx)
        .translate({ y: -1.5 * this.sy })
      } else {
        Text(args.label)
          .fontSize((args.label.length > 1 ? 11 : 14) * this.sx)
          .fontColor('#241f1a')
          .fontFamily('CourierPrime')
          .maxLines(1)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ left: 2, right: 2 })
          .translate({ y: -1.5 })
      }
      Column().width(38 * this.sx).height(2 * this.sx).backgroundColor('#2a221b')
        .position({ x: -1 * this.sx, y: 31 * this.sx })
    }
    // 批 66：功能行六键按 kx 等比放大（36×30 → 66.9×55.7，宽高同系数，不拉伸）
    .width(36 * this.sx).height(30 * this.sx)
    .position({ x: (args.idx * 36) * this.sx, y: 3 * this.sx })
    // 批 71（用户 2026-11-22 定）：功能键要有**和键盘一样的按下效果**。
    // 口径与 KeyGrid.capCell 完全一致：下沉 2vp（绝对值，不随 sx 缩放——键盘在平板也是 2vp）、
    // scaleY 0.94、90ms springMotion(0.34, 0.9)；按下态由本组件的 pressedIdx 驱动。
    .translate({ y: this.pressedIdx === args.idx ? 2 : 0 })
    .scale({ y: this.pressedIdx === args.idx ? 0.94 : 1 })
    .animation({ duration: 90, curve: curves.springMotion(0.34, 0.9) })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressedIdx = args.idx;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressedIdx = -1;
      }
    })
    // 批 62 收尾：功能行六键的无障碍文本（读屏朗读名与按钮显示一致）
    .accessibilityText(args.label === 'BL' ? '退行' : args.label)
    .accessibilityLevel('yes')
    .onClick(() => { args.cb(); })
  }

  build() {
    // F5/R17：标签直接由语言状态决定，不依赖父级拼好的字符串（原先切中文后仍显示 EN）
    Stack({ alignContent: Alignment.TopStart }) {
      this.cap({ label: this.langDyn.length > 0 ? this.langDyn : 'EN', idx: 0,
        cb: this.onLang, active: this.langActive || this.zhState })
      this.cap({ label: '⌫', idx: 1, cb: this.onDelete, active: false })
      this.cap({ label: '⏎', idx: 2, cb: this.onNewline, active: false })
      this.cap({ label: '↻', idx: 3, cb: this.onPaper, active: false })
      this.cap({ label: 'BL', idx: 4, cb: this.onBackLine, active: false })
      this.cap({ label: 'Aa', idx: 5, cb: this.onSymbols, active: this.symbolActive })
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
    // 批 62 收尾：无障碍文本（读屏朗读名与元素一致）
    .accessibilityText('字体')
    .accessibilityLevel('yes')
    .onClick(() => { this.onFont(); })
  }
}

// ---------------------------------------------------------------------------
// 候选条（盖上的深色纸条；F5/R1：数量与字号跟设置走，超宽翻页；无候选留空）
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
  /** F5/R1：候选字号与页码走 AppStorage（@Prop 经 Stage26 槽位不刷新）。 */
  @StorageLink('candFont') fontSizeVp: number = 15;
  @StorageLink('candPage') pageNo: number = 0;
  @StorageLink('candPages') pageCount: number = 0;
  onPick: (i: number) => void = (_i: number): void => {};
  onPrevPage: () => void = (): void => {};
  onNextPage: () => void = (): void => {};

  private shown(): string[] {
    // F5 返工（R1）：按实际宽度累加（字数×字号＋间隔 8vp），行宽 264vp（扣拼音串）即断页；
    // 与 Index.candRanges 同口径，这里只做兜底（Index 已按同规则切页）。
    const budget: number = 264;
    const out: string[] = [];
    let used: number = 0;
    for (let i = 0; i < this.candidates.length; i++) {
      const c: string = this.candidates[i];
      const w: number = c.length * this.fontSizeVp + 8;
      if (used > 0 && used + w > budget) { break; }
      used += w;
      out.push(c);
    }
    return out;
  }
  private canPage(): boolean {
    return this.pageCount > 1;
  }

  /**
   * 批 75：按**机盖 base 的明度**分浅/深两支（不再写死 1950s）。
   * 相对亮度 = 0.299R + 0.587G + 0.114B；>140 视为浅 base。
   * 实测：1920s #1e1c1a=28.3 深／1930s #3a4038=61.3 深／
   *       1950s #d8cbb0=203.9 浅／1960s #a8a8a0=167.0 浅／2020s #adc4b8=187.8 浅。
   */
  private isLightBase(): boolean {
    const hex: string = tierToken(this.machine, 'base');
    const h: string = hex.charAt(0) === '#' ? hex.substring(1) : hex;
    if (h.length < 6) { return false; }
    const r: number = parseInt(h.substring(0, 2), 16);
    const g: number = parseInt(h.substring(2, 4), 16);
    const b: number = parseInt(h.substring(4, 6), 16);
    return (0.299 * r + 0.587 * g + 0.114 * b) > 140;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row()
        .width(300 * this.sx).height(30 * this.sy)
        .backgroundColor(this.isLightBase() ? '#e8dfcc' : '#241f19')
        .border({ width: 1.2, color: this.isLightBase() ? '#7a6647' : '#0b0908' })
        .borderRadius(2)
        .shadow({ radius: 3, color: '#00000099', offsetX: 0, offsetY: 1 })
        .position({ x: (this.widthVp - 300 * this.sx) / 2, y: 7 * this.sy })
      Row({ space: 8 * this.sx }) {
        if (this.pinyin.length > 0 && this.candidates.length > 0) {
          Text(this.pinyin + ' ').fontSize(13)
            .fontColor(this.isLightBase() ? '#5a4a33' : '#b8a98f')
            .fontFamily('CourierPrime')
        }
        ForEach(this.shown(), (c: string, i: number) => {
          Text(c)
            .fontSize(this.fontSizeVp)
            .fontColor(this.isLightBase() ? '#241f19' : '#f0e8d8')
            .maxLines(1)
            // 批 62 收尾：候选格的无障碍文本＝候选词本身（读屏朗读与格内显示一致）
            .accessibilityText(c)
            .accessibilityLevel('yes')
            .onClick(() => { this.onPick(i); })
        }, (c: string, i: number) => this.pageNo.toString() + '_' + i.toString() + c)
      }
      .width(264 * this.sx)
      .clip(true)
      .justifyContent(FlexAlign.Center)
      .position({ x: (this.widthVp - 300 * this.sx) / 2 + 18 * this.sx, y: 14 * this.sy })
      // F5/R1：翻页箭头绝对定位在纸条两端（Roll 内部放不下时也不会被挤掉）
      if (this.canPage() && this.pageNo > 0) {
        Text('‹').fontSize(18)
          .fontColor(this.isLightBase() ? '#5a4a33' : '#d8c9ab')
          .position({ x: (this.widthVp - 300 * this.sx) / 2 + 2 * this.sx, y: 12 * this.sy })
          .accessibilityText('上一页候选')
          .onClick(() => { this.onPrevPage(); })
      }
      if (this.canPage() && this.pageNo + 1 < this.pageCount) {
        Text('›').fontSize(18)
          .fontColor(this.isLightBase() ? '#5a4a33' : '#d8c9ab')
          .position({ x: (this.widthVp + 300 * this.sx) / 2 - 16 * this.sx, y: 12 * this.sy })
          .accessibilityText('下一页候选')
          .onClick(() => { this.onNextPage(); })
      }
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
  /** 批 62（任务 3）：纸张自定义——底色／纹理／横线（空/未开则落回纸种默认）。 */
  @Prop customPaperColor: string = '';
  @Prop customTextureRawfile: string = '';
  @Prop ruledOn: boolean = false;
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
    // 批 62（任务 3）：自定义底色（在最底层；空则透明，不干扰纸种）
    if (this.customPaperColor.length > 0) {
      Column().width('100%').height('100%')
        .backgroundColor(this.customPaperColor)
        .position({ x: 0, y: 0 })
        .hitTestBehavior(HitTestMode.None)
    }
    // 批 64（T3）：纸盒改 flex 后，纸的宽高比＝Pw/纸高＝0.7183（与贴图 1484×2066 一致），
    // 所以贴图改回 Fill——Contain 在「窄高盒」里会留白（真机 2280 前身实测：纸顶/纸底各一条白带）。
    // F2/A142：导入纸纹是沙箱文件（绝对路径），$rawfile 只认 HAP 内资源名，会报 AceResource 9001005；
    // 自定义纸纹改走 file:// 路径加载（与 PaperStage／字体导入同一口径），内置四种纸纹仍走 $rawfile。
    if (this.customTextureRawfile.length > 0) {
      Image('file://' + this.customTextureRawfile)
        .width('100%').height('100%').objectFit(ImageFit.Fill).opacity(1.0)
        .onError(() => {
          hilog.error(0x0100, 'Paper26', 'custom texture load failed path=%{public}s', this.customTextureRawfile);
        })
    } else {
      Image($rawfile(this.textureRawfile.length > 0 ? this.textureRawfile : 'ui-parts/paper-cream-v5.png'))
        .width('100%').height('100%').objectFit(ImageFit.Fill).opacity(1.0)
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column().width('100%').height('100%').backgroundColor('#faf8f2')
      this.texture()
      // 批 62（任务 3）：横线（与纸自定义预览同口径：每 lineHeightVp 一条，从上内边距起）
      if (this.ruledOn) {
        ForEach(new Array(Math.max(1, Math.floor((this.heightVp - this.marginTVp) / this.lineHeightVp))),
          (x: undefined, k: number) => {
            Column().width(this.widthVp - this.marginLVp * 2).height(0.6)
              .backgroundColor('#00000014')
              .position({ x: this.marginLVp, y: this.marginTVp + k * this.lineHeightVp })
              .hitTestBehavior(HitTestMode.None)
          }, (x: undefined, k: number) => 'rule' + k.toString())
      }
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