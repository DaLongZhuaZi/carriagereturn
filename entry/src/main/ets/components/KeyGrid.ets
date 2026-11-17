/**
 * 第 33 批（26 号稿 §7.8）：键盘网格 —— 5 行 3D 键帽真键盘。
 *
 * 口径（26 号稿）：
 *  - 键帽＝生成帽身（顶面＋侧壁＋底影，cap3d-<slug>.png）＋ ArkUI Text 叠加图例（不 baked）；
 *  - 5 行几何写死（§7.8 表）：键区 x 12–350.7、行高 34.5、帽高 27.6、竖缝 6.9、横缝 3；
 *  - 图例：数字行符号在上、数字在下（双图例）；字母居中；长标签缩小字号；
 *  - 红 RETURN：A 行右端红色帽＋白字；SHIFT／SHIFT LOCK 按压态沿用 pressedId 下沉 2vp；
 *  - 键杆：帽间竖缝里的暗色竖条（行间可见段 8vp），按压时帽下沉、可见段缩短。
 *
 * 旧 4 行键带（11/10/11/11）由本文件 5 行取代；旧 keymap 只保留给行情/命中兼容。
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MachineKind } from '../model/DocModel';
import { CapDef, KeymapLayout } from '../model/KeymapModel';

const KDOMAIN: number = 0x0000;
const KTAG: string = 'KeyGrid';

/** §7.8 键盘几何（vp，写死）——蓝图字段登记处。 */
const KB_X0: number = 12;
const KB_W: number = 338.7;
const KB_ROW_H: number = 34.5;
const KB_CAP_H: number = 27.6;
const KB_VGAP: number = 6.9;
const KB_HGAP: number = 3;

interface K33Key { label: string; legend: string; sub: string; w: number; kind: string; }
interface K33Row { y: number; keys: K33Key[]; }
interface K33Placed { label: string; legend: string; sub: string; x: number; y: number; w: number; kind: string; id: string; }

function K(label: string, legend: string, sub: string, w: number, kind: string): K33Key {
  return { label: label, legend: legend, sub: sub, w: w, kind: kind };
}

@Component
export struct KeyGrid {
  @Prop machineKind: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop widthVp: number = 390;
  @Prop heightVp: number = 186;
  @Prop layout: KeymapLayout = { machine: '', caps: [], spaceXMin: 0, spaceXMax: 0, spaceYMin: 0, spaceYMax: 0, hitRadius: 10, spaceR: 8, overlayColor: '#000000', overlayFontSize: 14, widthVp: 390, heightVp: 186 };
  @Prop shiftActive: boolean = false;
  @Prop capsActive: boolean = false;
  @Prop overlayFontFamily: string = 'CourierPrime';
  @Prop overlayFontSize: number = 15;
  @Prop labelColor: string = '#312b24';
  @Prop capShape: string = 'rounded-rect';
  @Prop originXVp: number = 0;
  @Prop originYVp: number = 0;
  @Prop foldBand: boolean = false;
  @Prop commitSeq: number = 0;
  @State pressedId: string = '';
  onCapDown: (cap: CapDef) => void = (cap: CapDef): void => {};
  onCapUp: (cap: CapDef) => void = (cap: CapDef): void => {};
  onCapSlide: (cap: CapDef) => void = (cap: CapDef): void => {};

  private slug(): string {
    const k: string = this.machineKind as string;
    const i: number = k.indexOf('-');
    return i > 0 ? k.substring(0, i) : k;
  }

  private cap3dRawfile(): string {
    return 'ui-parts/cap3d-' + this.slug() + '.png';
  }

  /** 5 行键位表（§7.8 附录 A；宽表见 §7.8 表）。 */
  private rows(): K33Row[] {
    const digit: K33Key[] = [
      K('!', '!', '1', 21.6, 'k'), K('@', '@', '2', 21.6, 'k'), K('#', '#', '3', 21.6, 'k'),
      K('$', '$', '4', 21.6, 'k'), K('%', '%', '5', 21.6, 'k'), K('^', '^', '6', 21.6, 'k'),
      K('&', '&', '7', 21.6, 'k'), K('*', '*', '8', 21.6, 'k'), K('(', '(', '9', 21.6, 'k'),
      K(')', ')', '0', 21.6, 'k'), K('-', '-', '', 21.6, 'k'), K('=', '=', '', 21.6, 'k'),
      K('Backspace', 'BACK SPACE', '', 43.2, 'back'),
    ];
    const q: K33Key[] = [
      K('Tab', 'TAB', '', 33.6, 'tab'),
      K('q', 'Q', '', 22.4, 'k'), K('w', 'W', '', 22.4, 'k'), K('e', 'E', '', 22.4, 'k'),
      K('r', 'R', '', 22.4, 'k'), K('t', 'T', '', 22.4, 'k'), K('y', 'Y', '', 22.4, 'k'),
      K('u', 'U', '', 22.4, 'k'), K('i', 'I', '', 22.4, 'k'), K('o', 'O', '', 22.4, 'k'),
      K('p', 'P', '', 22.4, 'k'), K('[', '[', '', 22.4, 'k'), K(']', ']', '', 22.4, 'k'),
    ];
    const a: K33Key[] = [
      K('Caps Lock', 'SHIFT LOCK', '', 31, 'caps'),
      K('a', 'A', '', 20.7, 'k'), K('s', 'S', '', 20.7, 'k'), K('d', 'D', '', 20.7, 'k'),
      K('f', 'F', '', 20.7, 'k'), K('g', 'G', '', 20.7, 'k'), K('h', 'H', '', 20.7, 'k'),
      K('j', 'J', '', 20.7, 'k'), K('k', 'K', '', 20.7, 'k'), K('l', 'L', '', 20.7, 'k'),
      K(';', ';', '', 20.7, 'k'), K(':', ':', '', 20.7, 'k'),
      K('Return', 'RETURN', '', 41.4, 'return'),
    ];
    const z: K33Key[] = [
      K('Shift', 'SHIFT', '', 47, 'shift'),
      K('z', 'Z', '', 23.5, 'k'), K('x', 'X', '', 23.5, 'k'), K('c', 'C', '', 23.5, 'k'),
      K('v', 'V', '', 23.5, 'k'), K('b', 'B', '', 23.5, 'k'), K('n', 'N', '', 23.5, 'k'),
      K('m', 'M', '', 23.5, 'k'), K(',', ',', '', 23.5, 'k'), K('.', '.', '', 23.5, 'k'),
      K('/', '/', '', 23.5, 'k'),
      K('Shift', 'SHIFT', '', 47, 'shift'),
    ];
    const space: K33Key[] = [K(' ', '', '', 237, 'space')];
    return [
      { y: 0, keys: digit },
      { y: KB_ROW_H, keys: q },
      { y: KB_ROW_H * 2, keys: a },
      { y: KB_ROW_H * 3, keys: z },
      { y: KB_ROW_H * 4, keys: space },
    ];
  }

  /** 平铺后每个键的绝对位置（键区内 x 从 12 起，横缝 3）。 */
  private placed(): K33Placed[] {
    const out: K33Placed[] = [];
    const rows: K33Row[] = this.rows();
    for (let r = 0; r < rows.length; r++) {
      let x: number = KB_X0;
      const keys: K33Key[] = rows[r].keys;
      for (let i = 0; i < keys.length; i++) {
        const k: K33Key = keys[i];
        // 空格行居中
        let px: number = x;
        if (k.kind === 'space') {
          px = KB_X0 + (KB_W - k.w) / 2;
        }
        out.push({
          label: k.label, legend: k.legend, sub: k.sub, x: px,
          y: rows[r].y + (KB_ROW_H - KB_CAP_H) / 2, w: k.w, kind: k.kind,
          id: this.slug() + ':' + rows[r].y.toString() + ':' + i.toString(),
        });
        x += k.w + KB_HGAP;
      }
    }
    return out;
  }

  /** 键杆：每行（除首行）每个键边界处的暗色竖条。 */
  private stems(): K33Placed[] {
    const out: K33Placed[] = [];
    const rows: K33Row[] = this.rows();
    for (let r = 1; r < rows.length; r++) {
      let x: number = KB_X0;
      const keys: K33Key[] = rows[r].keys;
      for (let i = 0; i < keys.length; i++) {
        out.push({
          label: '', legend: '', sub: '', x: x + keys[i].w + KB_HGAP / 2 - 1,
          y: rows[r].y - KB_VGAP + 1, w: 2, kind: 'stem', id: 'stem:' + r + ':' + i,
        });
        x += keys[i].w + KB_HGAP;
      }
    }
    return out;
  }

  private capFor(p: K33Placed): CapDef {
    return {
      id: p.id, label: p.label, cx: p.x + p.w / 2, cy: p.y + KB_CAP_H / 2, rowIndex: 0,
      isExtra: false, xRatio: (p.x + p.w / 2) / this.widthVp, yRatio: (p.y + KB_CAP_H / 2) / this.heightVp,
      wRatio: p.w / this.widthVp, hRatio: KB_CAP_H / this.heightVp, rRatio: 8 / this.widthVp,
      shape: 'rounded-rect',
    };
  }

  private labelSize(p: K33Placed): number {
    if (p.kind === 'space') { return 0; }
    if (p.kind === 'back' || p.kind === 'caps' || p.kind === 'return' || p.kind === 'tab' || p.kind === 'shift') { return 7; }
    return 12;
  }

  aboutToAppear(): void {
    hilog.info(KDOMAIN, KTAG, 'mount x=%{public}s y=%{public}s w=%{public}s h=%{public}s caps=%{public}d spaceW=%{public}s slug=%{public}s (5-row v33)',
      this.originXVp.toFixed(1), this.originYVp.toFixed(1), this.widthVp.toFixed(1), this.heightVp.toFixed(1),
      this.placed().length, '237', this.slug());
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 键杆（帽间竖缝，暗色）
      ForEach(this.stems(), (s: K33Placed) => {
        Column()
          .width(s.w).height(8)
          .backgroundColor('#141210')
          .position({ x: s.x, y: s.y })
          .hitTestBehavior(HitTestMode.None)
      }, (s: K33Placed) => s.id)

      // 逐帽：Button{ Image(帽身) + 图例 }；按压下沉 2vp、键杆可见段缩短
      ForEach(this.placed(), (p: K33Placed) => {
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          Stack() {
            Image($rawfile(this.cap3dRawfile()))
              .objectFit(ImageFit.Fill)
              .width('100%').height('100%')
              .hitTestBehavior(HitTestMode.None)
            if (p.kind === 'return') {
              Column().width('100%').height('100%')
                .backgroundColor('#c8322d')
                .borderRadius(6)
                .hitTestBehavior(HitTestMode.None)
                .opacity(0.92)
            }
            if (p.sub.length > 0) {
              Column() {
                Text(p.legend).fontSize(11).fontColor(p.kind === 'return' ? '#ffffff' : '#1a1a1a')
                  .fontFamily(this.overlayFontFamily).maxLines(1)
                Text(p.sub).fontSize(8).fontColor(p.kind === 'return' ? '#ffffff' : '#3a3630')
                  .fontFamily(this.overlayFontFamily).maxLines(1)
              }.justifyContent(FlexAlign.Center).width('100%').height('100%')
                .hitTestBehavior(HitTestMode.None)
            } else {
              Text(p.legend)
                .fontSize(this.labelSize(p))
                .fontColor(p.kind === 'return' ? '#ffffff' : '#1a1a1a')
                .fontFamily(this.overlayFontFamily)
                .width('100%').textAlign(TextAlign.Center).maxLines(1)
                .hitTestBehavior(HitTestMode.None)
            }
          }
          .width('100%').height('100%')
        }
        .padding(0)
        .width(p.w)
        .height(KB_CAP_H)
        .position({ x: p.x, y: p.y })
        .backgroundColor(Color.Transparent)
        .borderRadius(0)
        .translate({ y: this.pressedId === p.id ? 2 : 0 })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
            this.pressedId = p.id;
            this.onCapDown(this.capFor(p));
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.pressedId = '';
            this.onCapUp(this.capFor(p));
          }
        })
      }, (p: K33Placed) => p.id)
    }
    .width(this.widthVp)
    .height(this.heightVp)
    .clip(true)
  }
}
