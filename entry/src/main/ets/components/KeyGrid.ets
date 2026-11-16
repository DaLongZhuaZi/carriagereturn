/**
 * 第 24 批（23 号稿批 1／§8.1）：键盘网格 —— 取代 `PhotoKeybed` 的机器照片带。
 *
 * 口径（23 号稿）：
 *  - 键帽是**真正的 Button**，图例是 Button 里的**真文字**（§2.3／§3.3 第 4 项「无 baked 文字」）；
 *  - 帽面用仓内图片贴片 `ui-parts/keycap-face-<slug>.png`，按下态用 `keycap-pressed-<slug>.png`；
 *  - **帽面与图例是两个显式的兄弟层**（Stack 内 Image ＋ Text）；Button 一律 padding 0，
 *    否则子层被默认内边距挤成 0 宽 → 图例不上屏（第 24 批实测教训）；
 *  - `hitAt` 语义与 `PhotoKeybed` L181 一致：每个 CapDef 直接摆成一个 Button，点按即命中该帽；
 *  - 按下态可见：命中帽下沉 2vp（§2.3 第 4 条）；
 *  - 长标签（Shift／Backspace／Return／Caps Lock）必须完整显示：字号按「帽宽 ÷ 标签字数」现算，
 *    不靠 minFontSize 自适应（实测自适应在窄帽里把字压到不可读甚至不绘制）。
 *
 * 过渡态（R-B5，批 2 机身面板挂载后删）：`showBacking` 为真时先铺一块机身色底板，
 * 遮住 Canvas 旧键带照片（含照片里 baked 的 "hift" 叠字）；底板不属于键盘网格件本体。
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MachineKind } from '../model/DocModel';
import { CapDef, KeymapLayout } from '../model/KeymapModel';

const KDOMAIN: number = 0x0000;
const KTAG: string = 'KeyGrid';

function emptyLayout(): KeymapLayout {
  return {
    machine: '', caps: [], spaceXMin: 0, spaceXMax: 0, spaceYMin: 0, spaceYMax: 0,
    hitRadius: 10, spaceR: 8, overlayColor: '#000000', overlayFontSize: 14, widthVp: 390, heightVp: 186,
  };
}

@Component
export struct KeyGrid {
  @Prop machineKind: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop widthVp: number = 390;
  @Prop heightVp: number = 186;
  @Prop layout: KeymapLayout = emptyLayout();
  @Prop shiftActive: boolean = false;
  @Prop capsActive: boolean = false;
  @Prop overlayFontFamily: string = 'CourierPrime';
  @Prop overlayFontSize: number = 15;
  @Prop labelColor: string = '#312b24';
  /** 过渡态键区底板色（机身色）；批 2 机身面板接管后本 prop 删。 */
  @Prop backingColor: string = '#312b24';
  @Prop showBacking: boolean = true;
  /** 组件原点（vp，绝对坐标）：只用于打点核对挂载位置。 */
  @Prop originXVp: number = 0;
  @Prop originYVp: number = 0;
  /** 过渡期惰性 prop（PhotoKeybed 挂载块原样保留用，KeyGrid 不消费）。 */
  @Prop foldBand: boolean = false;
  @Prop commitSeq: number = 0;
  /** 当前被按下的帽 id（按下态图＋下沉 2vp）。 */
  @State pressedId: string = '';
  onCapDown: (cap: CapDef) => void = (cap: CapDef): void => {};
  onCapUp: (cap: CapDef) => void = (cap: CapDef): void => {};
  /** 过渡期惰性回调（PhotoKeybed 的滑动语义，KeyGrid 暂不消费）。 */
  onCapSlide: (cap: CapDef) => void = (cap: CapDef): void => {};

  /** 机型短名：'1920s-upright' → '1920s'（贴片命名口径，§7.4）。 */
  private slug(): string {
    const k: string = this.machineKind as string;
    const i: number = k.indexOf('-');
    return i > 0 ? k.substring(0, i) : k;
  }

  private labelOf(cap: CapDef): string {
    if (cap.rowIndex >= 0 && (this.shiftActive || this.capsActive)) {
      return cap.label.toUpperCase();
    }
    return cap.label;
  }

  private capW(cap: CapDef): number { return Math.max(1, cap.wRatio * this.widthVp); }

  private capH(cap: CapDef): number { return Math.max(1, cap.hRatio * this.heightVp); }

  /**
   * 图例字号：按帽宽与标签字数现算（长标签缩小、短标签放大，恒 ≤ overlayFontSize×0.8）。
   * 0.62em 是等宽字体的字符宽比（与纸面 advance 口径同源）。
   */
  private fontSizeOf(cap: CapDef): number {
    const n: number = Math.max(1, this.labelOf(cap).length);
    const box: number = Math.max(4, this.capW(cap) - 1);
    // 0.60em＝等宽字体字符宽比（与纸面 advance 同源）；长标签按字数缩到放得下为止。
    const fit: number = box / (n * 0.60);
    const maxFs: number = this.overlayFontSize * 0.8;
    return Math.max(2, Math.min(maxFs, fit));
  }

  aboutToAppear(): void {
    hilog.info(KDOMAIN, KTAG, 'mount x=%{public}s y=%{public}s w=%{public}s h=%{public}s caps=%{public}d spaceW=%{public}s slug=%{public}s',
      this.originXVp.toFixed(1), this.originYVp.toFixed(1), this.widthVp.toFixed(1), this.heightVp.toFixed(1),
      this.layout.caps.length, (this.layout.spaceXMax - this.layout.spaceXMin).toFixed(1), this.slug());
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 过渡态底板：机身色，遮住 Canvas 旧键带照片（批 2 删）
      if (this.showBacking) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.backingColor)
      }

      // 空格条
      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Stack() {
          Image($rawfile('ui-parts/spacebar-face-' + this.slug() + '.png'))
            .objectFit(ImageFit.Fill)
            .width('100%')
            .height('100%')
            .hitTestBehavior(HitTestMode.None)
        }
        .width('100%')
        .height('100%')
      }
      .padding(0)
      .width(Math.max(1, this.layout.spaceXMax - this.layout.spaceXMin))
      .height(Math.max(1, this.layout.spaceYMax - this.layout.spaceYMin))
      .position({ x: this.layout.spaceXMin, y: this.layout.spaceYMin })
      .backgroundColor(Color.Transparent)
      .borderRadius(0)
      .translate({ y: this.pressedId === 'space' ? 2 : 0 })
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
          this.pressedId = 'space';
          this.onCapDown(this.spaceCap());
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.pressedId = '';
          this.onCapUp(this.spaceCap());
        }
      })

      // 逐帽：Button 内 Stack{ Image(帽面/按下态) + Text(图例) }
      ForEach(this.layout.caps, (cap: CapDef) => {
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          Stack() {
            Image($rawfile(this.pressedId === cap.id
              ? 'ui-parts/keycap-pressed-' + this.slug() + '.png'
              : 'ui-parts/keycap-face-' + this.slug() + '.png'))
              .objectFit(ImageFit.Fill)
              .width('100%')
              .height('100%')
              .hitTestBehavior(HitTestMode.None)
            Text(this.labelOf(cap))
              .fontSize(this.fontSizeOf(cap))
              .fontColor(this.labelColor)
              .fontFamily(this.overlayFontFamily)
              .width(this.capW(cap))
              .textAlign(TextAlign.Center)
              .maxLines(1)
          }
          .width('100%')
          .height('100%')
        }
        .padding(0)
        .width(this.capW(cap))
        .height(this.capH(cap))
        .position({
          x: cap.xRatio * this.widthVp - this.capW(cap) / 2,
          y: cap.yRatio * this.heightVp - this.capH(cap) / 2,
        })
        .backgroundColor(Color.Transparent)
        .borderRadius(0)
        .translate({ y: this.pressedId === cap.id ? 2 : 0 })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
            this.pressedId = cap.id;
            this.onCapDown(cap);
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.pressedId = '';
            this.onCapUp(cap);
          }
        })
      }, (cap: CapDef) => cap.id)
    }
    .width(this.widthVp)
    .height(this.heightVp)
    .clip(true)
    // 定位由 Index 在挂载处用 .position 施加（自定义组件根节点上的 .position 会被父 Stack 对齐覆盖——第 24 批实测）
  }

  /** 空格帽定义（与 PhotoKeybed hitAt 的空格分支同口径）。 */
  private spaceCap(): CapDef {
    return {
      id: this.layout.machine + ':space',
      label: ' ',
      cx: (this.layout.spaceXMin + this.layout.spaceXMax) / 2,
      cy: (this.layout.spaceYMin + this.layout.spaceYMax) / 2,
      rowIndex: -1,
      isExtra: false,
      xRatio: 0.5,
      yRatio: 0.5,
      wRatio: 0.5,
      hRatio: 0.5,
      rRatio: 0.1,
      shape: 'rounded-rect',
    };
  }
}
