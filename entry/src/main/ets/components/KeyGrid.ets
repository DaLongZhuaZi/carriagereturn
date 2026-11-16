/**
 * 第 24 批（23 号稿批 1／§8.1）：键盘网格 —— 取代 `PhotoKeybed` 的机器照片带。
 *
 * 口径（23 号稿）：
 *  - 键帽是**真正的 Button**，图例是 Button 里的**真文字**（§2.3／§3.3 第 4 项「无 baked 文字」）；
 *  - 帽面用仓内图片贴片 `ui-parts/keycap-face-<slug>.png`，按下态用 `keycap-pressed-<slug>.png`；
 *  - **帽面与图例是两个显式的兄弟层**（Stack 内 Image ＋ Text）——第 6 轮实测「Button＋backgroundImage＋Text」
 *    时文字没上屏（截图 1701 帽面全空白），故改成兄弟层，不再依赖 backgroundImage 与子内容的绘制次序；
 *  - `hitAt` 语义与 `PhotoKeybed` L181 一致：每个 CapDef 直接摆成一个 Button，点按即命中该帽；
 *  - 按下态可见：命中帽下沉 2vp（§2.3 第 4 条）；
 *  - 长标签（Shift／Backspace／Return／Caps Lock）必须完整显示：宽度约束＋`minFontSize` 自适应，不许截断。
 */
import { MachineKind } from '../model/DocModel';
import { CapDef, KeymapLayout } from '../model/KeymapModel';

function emptyLayout(): KeymapLayout {
  return {
    machine: '', caps: [], spaceXMin: 0, spaceXMax: 0, spaceYMin: 0, spaceYMax: 0,
    hitRadius: 10, spaceR: 8, overlayColor: '#000000', overlayFontSize: 14, widthVp: 390, heightVp: 186,
  };
}

@Component
export struct KeyGrid {
  @Prop machineKind: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop widthVp: number = 362.7;
  @Prop heightVp: number = 186;
  @Prop layout: KeymapLayout = emptyLayout();
  @Prop shiftActive: boolean = false;
  @Prop capsActive: boolean = false;
  @Prop overlayFontFamily: string = 'CourierPrime';
  @Prop overlayFontSize: number = 15;
  @Prop labelColor: string = '#2b2620';
  /** 过渡期惰性 prop：PhotoKeybed 挂载块原样保留用（KeyGrid 不消费）。 */
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

  private isCapsLock(cap: CapDef): boolean { return cap.label === 'Caps Lock' || cap.label === 'Shift'; }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 空格条
      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Stack() {
          Image($rawfile('ui-parts/spacebar-face-' + this.slug() + '.png'))
            .objectFit(ImageFit.Fill)
            .width('100%')
            .height('100%')
            .hitTestBehavior(HitTestMode.None)
          Text(' ')
            .fontSize(this.overlayFontSize)
            .fontColor(this.labelColor)
            .fontFamily(this.overlayFontFamily)
        }
        .width('100%')
        .height('100%')
      }
      .width(Math.max(1, this.layout.spaceXMax - this.layout.spaceXMin))
      .height(Math.max(1, this.layout.spaceYMax - this.layout.spaceYMin))
      .position({ x: this.layout.spaceXMin, y: this.layout.spaceYMin })
      .backgroundColor(Color.Transparent)
      .borderRadius(0)
      .translate({ y: this.pressedId === 'space' ? 2 : 0 })

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
              .fontSize(this.overlayFontSize)
              .fontColor(this.labelColor)
              .fontFamily(this.overlayFontFamily)
              .width(this.capW(cap) - 4)
              .textAlign(TextAlign.Center)
              .maxLines(1)
              .minFontSize(6)
              .maxFontSize(this.overlayFontSize)
          }
          .width('100%')
          .height('100%')
        }
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
  }
}

