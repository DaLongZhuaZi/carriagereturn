/**
 * 26 号稿 §7.8（本批 binding 修正 1／2／3）：键盘网格 —— 5 行真键盘。
 *
 * 口径：
 *  - 键位＝附录 A（全键位一个不少）；键宽按修正 1 的表写死，逐行总宽 ≤338.7vp；
 *    数字行 13 键、Q 行 13 键、A 行 15 键（SHIFT LOCK＋13×17.25＋RETURN）、
 *    Z 行 12 键（SHIFT＋10×21.17＋SHIFT）、空格 1 键。
 *  - 帽身＝生成件 cap3d-<slug>.png（503×512，顶面＋四边侧壁＋底影）＋ ArkUI Text 叠加图例；
 *    红 RETURN＝cap3d-return.png；空格＝cap3d-space-<slug>.png 九宫格中心拉伸（只拉中间段）。
 *  - 图例不 baked；图例中心＝顶面中心：整组上移 5.0vp（27.6×0.181，修正 2）。
 *  - 键杆：竖缝暗色竖条（本批加深到与 #050506 井底有可辨对比）。
 *  - 按压：pressedId 下沉 2vp（SHIFT／SHIFT LOCK 不改帽色）。
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
/** 修正 2：图例上移 = 帽高 × 0.181。 */
const KB_LEGEND_UP: number = 5.0;
/** 键杆（帽间竖缝）可见段。 */
const KB_STEM_H: number = 6.6;

interface K33Key { label: string; legend: string; sub: string; w: number; kind: string; up: string; alt: string; }
interface K33Row { y: number; keys: K33Key[]; }
interface K33Placed { label: string; legend: string; sub: string; x: number; y: number; w: number; kind: string; id: string; up: string; alt: string; }

function K(label: string, legend: string, sub: string, w: number, kind: string, up: string, alt: string): K33Key {
  return { label: label, legend: legend, sub: sub, w: w, kind: kind, up: up, alt: alt };
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

  private space3dRawfile(): string {
    return 'ui-parts/cap3d-space-' + this.slug() + '.png';
  }

  /** 5 行键位表（附录 A；键宽＝修正 1 的表，写死）。 */
  private rows(): K33Row[] {
    const digit: K33Key[] = [
      K('1', '!', '1', 21.6, 'k', '!', '!'), K('2', '@', '2', 21.6, 'k', '@', '@'),
      K('3', '#', '3', 21.6, 'k', '#', '#'), K('4', '$', '4', 21.6, 'k', '$', '$'),
      K('5', '%', '5', 21.6, 'k', '%', '%'), K('6', '^', '6', 21.6, 'k', '^', '^'),
      K('7', '&', '7', 21.6, 'k', '&', '&'), K('8', '*', '8', 21.6, 'k', '*', '*'),
      K('9', '(', '9', 21.6, 'k', '(', '('), K('0', ')', '0', 21.6, 'k', ')', ')'),
      K('-', '-', '', 21.6, 'k', '_', '-'), K('=', '=', '', 21.6, 'k', '+', '='),
      K('Backspace', 'BACK SPACE', '', 43.2, 'back', '', ''),
    ];
    const q: K33Key[] = [
      K('Tab', 'TAB', '', 33.6, 'tab', '', ''),
      K('q', 'Q', '', 22.4, 'k', '', ''), K('w', 'W', '', 22.4, 'k', '', ''),
      K('e', 'E', '', 22.4, 'k', '', ''), K('r', 'R', '', 22.4, 'k', '', ''),
      K('t', 'T', '', 22.4, 'k', '', ''), K('y', 'Y', '', 22.4, 'k', '', ''),
      K('u', 'U', '', 22.4, 'k', '', ''), K('i', 'I', '', 22.4, 'k', '', ''),
      K('o', 'O', '', 22.4, 'k', '', ''), K('p', 'P', '', 22.4, 'k', '', ''),
      K('[', '[', '', 22.4, 'k', '{', '['), K(']', ']', '', 22.4, 'k', '}', ']'),
    ];
    const a: K33Key[] = [
      K('Caps Lock', 'SHIFT LOCK', '', 31, 'caps', '', ''),
      K('a', 'A', '', 17.25, 'k', '', ''), K('s', 'S', '', 17.25, 'k', '', ''),
      K('d', 'D', '', 17.25, 'k', '', ''), K('f', 'F', '', 17.25, 'k', '', ''),
      K('g', 'G', '', 17.25, 'k', '', ''), K('h', 'H', '', 17.25, 'k', '', ''),
      K('j', 'J', '', 17.25, 'k', '', ''), K('k', 'K', '', 17.25, 'k', '', ''),
      K('l', 'L', '', 17.25, 'k', '', ''), K(';', ';', '', 17.25, 'k', ':', ';'),
      K(':', ':', '', 17.25, 'k', ':', ':'), K('\'', '\'', '', 17.25, 'k', '"', '\''),
      K('"', '"', '', 17.25, 'k', '"', '"'),
      K('Return', 'RETURN', '', 41.4, 'return', '', ''),
    ];
    const z: K33Key[] = [
      K('Shift', 'SHIFT', '', 47, 'shift', '', ''),
      K('z', 'Z', '', 21.17, 'k', '', ''), K('x', 'X', '', 21.17, 'k', '', ''),
      K('c', 'C', '', 21.17, 'k', '', ''), K('v', 'V', '', 21.17, 'k', '', ''),
      K('b', 'B', '', 21.17, 'k', '', ''), K('n', 'N', '', 21.17, 'k', '', ''),
      K('m', 'M', '', 21.17, 'k', '', ''), K(',', ',', '', 21.17, 'k', '<', ','),
      K('.', '.', '', 21.17, 'k', '>', '.'), K('/', '/', '', 21.17, 'k', '?', '/'),
      K('Shift', 'SHIFT', '', 47, 'shift', '', ''),
    ];
    const space: K33Key[] = [K(' ', '', '', 237, 'space', '', '')];
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
        let px: number = x;
        if (k.kind === 'space') {
          px = KB_X0 + (KB_W - k.w) / 2;
        }
        out.push({
          label: k.label, legend: k.legend, sub: k.sub, x: px,
          y: rows[r].y + (KB_ROW_H - KB_CAP_H) / 2, w: k.w, kind: k.kind,
          id: this.slug() + ':' + rows[r].y.toString() + ':' + i.toString(),
          up: k.up, alt: k.alt,
        });
        x += k.w + KB_HGAP;
      }
    }
    return out;
  }

  /** 逐行总宽（含横缝），报告 §0 验算表用。 */
  private rowWidths(): number[] {
    const out: number[] = [];
    const rows: K33Row[] = this.rows();
    for (let r = 0; r < rows.length; r++) {
      const keys: K33Key[] = rows[r].keys;
      let sum: number = 0;
      for (let i = 0; i < keys.length; i++) {
        sum += keys[i].w;
      }
      out.push(sum + KB_HGAP * (keys.length - 1));
    }
    return out;
  }

  /** 键杆：竖缝里的暗色竖条（帽底与下一行帽顶之间的可见段）。 */
  private stems(): K33Placed[] {
    const out: K33Placed[] = [];
    const rows: K33Row[] = this.rows();
    for (let r = 1; r < rows.length; r++) {
      let x: number = KB_X0;
      const keys: K33Key[] = rows[r].keys;
      for (let i = 0; i < keys.length; i++) {
        out.push({
          label: '', legend: '', sub: '', x: x + keys[i].w + KB_HGAP / 2 - 1,
          y: rows[r].y - KB_VGAP / 2 - KB_STEM_H / 2 + KB_VGAP, w: 2, kind: 'stem', id: 'stem:' + r + ':' + i,
          up: '', alt: '',
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
      shape: 'rounded-rect', upText: p.up, altText: p.alt,
    };
  }

  private labelSize(p: K33Placed): number {
    if (p.kind === 'space') { return 0; }
    if (p.kind === 'back' || p.kind === 'caps' || p.kind === 'return' || p.kind === 'tab' || p.kind === 'shift') { return 7; }
    return 12;
  }

  /** 帽身图（$rawfile 只吃编译期常量，故按机／按键静态分支）。 */
  @Builder
  capImage(p: K33Placed) {
    if (p.kind === 'return') {
      Image($rawfile('ui-parts/cap3d-return-v2.png'))
        .objectFit(ImageFit.Fill).width('100%').height('100%')
        .hitTestBehavior(HitTestMode.None)
    } else if (p.kind === 'space') {
      if (this.machineKind === MachineKind.UPRIGHT_1920S) {
        Image($rawfile('ui-parts/cap3d-space-1920s.png'))
          .objectFit(ImageFit.Fill).width('100%').height('100%')
          .resizable({ slice: { left: 64, right: 64, top: 6, bottom: 6 } })
          .hitTestBehavior(HitTestMode.None)
      } else if (this.machineKind === MachineKind.PORTABLE_1930S) {
        Image($rawfile('ui-parts/cap3d-space-1930s.png'))
          .objectFit(ImageFit.Fill).width('100%').height('100%')
          .resizable({ slice: { left: 64, right: 64, top: 6, bottom: 6 } })
          .hitTestBehavior(HitTestMode.None)
      } else if (this.machineKind === MachineKind.STREAMLINED_1950S) {
        Image($rawfile('ui-parts/cap3d-space-1950s.png'))
          .objectFit(ImageFit.Fill).width('100%').height('100%')
          .resizable({ slice: { left: 64, right: 64, top: 6, bottom: 6 } })
          .hitTestBehavior(HitTestMode.None)
      } else {
        Image($rawfile('ui-parts/cap3d-space-1960s.png'))
          .objectFit(ImageFit.Fill).width('100%').height('100%')
          .resizable({ slice: { left: 64, right: 64, top: 6, bottom: 6 } })
          .hitTestBehavior(HitTestMode.None)
      }
    } else {
      if (this.machineKind === MachineKind.UPRIGHT_1920S) {
        Image($rawfile('ui-parts/cap3d-1920s.png'))
          .objectFit(ImageFit.Fill).width('100%').height('100%')
          .hitTestBehavior(HitTestMode.None)
      } else if (this.machineKind === MachineKind.PORTABLE_1930S) {
        Image($rawfile('ui-parts/cap3d-1930s.png'))
          .objectFit(ImageFit.Fill).width('100%').height('100%')
          .hitTestBehavior(HitTestMode.None)
      } else if (this.machineKind === MachineKind.STREAMLINED_1950S) {
        Image($rawfile('ui-parts/cap3d-1950s.png'))
          .objectFit(ImageFit.Fill).width('100%').height('100%')
          .hitTestBehavior(HitTestMode.None)
      } else {
        Image($rawfile('ui-parts/cap3d-1960s.png'))
          .objectFit(ImageFit.Fill).width('100%').height('100%')
          .hitTestBehavior(HitTestMode.None)
      }
    }
  }

  aboutToAppear(): void {
    const w: number[] = this.rowWidths();
    hilog.info(KDOMAIN, KTAG,
      'mount x=%{public}s y=%{public}s w=%{public}s h=%{public}s caps=%{public}d rows=%{public}s slug=%{public}s (26 v2)',
      this.originXVp.toFixed(1), this.originYVp.toFixed(1), this.widthVp.toFixed(1), this.heightVp.toFixed(1),
      this.placed().length,
      w[0].toFixed(2) + '/' + w[1].toFixed(2) + '/' + w[2].toFixed(2) + '/' + w[3].toFixed(2) + '/' + w[4].toFixed(2),
      this.slug());
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 键杆（竖缝，暗色；井底 #050506 上可见）
      ForEach(this.stems(), (s: K33Placed) => {
        Column()
          .width(s.w).height(KB_STEM_H)
          .backgroundColor('#4a4136')
          .position({ x: s.x, y: s.y })
          .hitTestBehavior(HitTestMode.None)
      }, (s: K33Placed) => s.id)

      // 逐帽：Button{ Image(帽身) + 图例 }；按压下沉 2vp
      ForEach(this.placed(), (p: K33Placed) => {
        Button({ type: ButtonType.Normal, stateEffect: false }) {
          Stack() {
            // 帽身（空格九宫格中心拉伸；红 RETURN 用 cap3d-return.png）
            this.capImage(p)
            if (p.sub.length > 0 && p.kind === 'k') {
              // 数字行双图例：符号上、数字下（整组上移到顶面中心）
              Column() {
                Text(p.legend).fontSize(11).fontColor('#1a1a1a')
                  .fontFamily(this.overlayFontFamily).maxLines(1)
                Text(p.sub).fontSize(8).fontColor('#3a3630')
                  .fontFamily(this.overlayFontFamily).maxLines(1)
              }
              .justifyContent(FlexAlign.Center)
              .width('100%').height('100%')
              .translate({ y: -KB_LEGEND_UP })
              .hitTestBehavior(HitTestMode.None)
            } else if (p.kind === 'caps') {
              // 26 号稿：SHIFT LOCK 两行小字（31vp 键宽放不下单行 10 字）
              Column() {
                Text('SHIFT').fontSize(6.5).fontColor('#1a1a1a')
                  .fontFamily(this.overlayFontFamily).maxLines(1)
                Text('LOCK').fontSize(6.5).fontColor('#1a1a1a')
                  .fontFamily(this.overlayFontFamily).maxLines(1)
              }
              .justifyContent(FlexAlign.Center)
              .width('100%').height('100%')
              .translate({ y: -KB_LEGEND_UP })
              .hitTestBehavior(HitTestMode.None)
            } else {
              Text(p.legend)
                .fontSize(this.labelSize(p))
                .fontColor(p.kind === 'return' ? '#ffffff' : '#1a1a1a')
                .fontFamily(this.overlayFontFamily)
                .width('100%').textAlign(TextAlign.Center).maxLines(1)
                .translate({ y: -KB_LEGEND_UP })
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
