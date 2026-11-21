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
import { curves } from '@kit.ArkUI';
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
/** 键杆（帽间竖缝）可见段：高 6.6vp（行间距 6.9 里的可见段），宽 2vp（批 64 恢复时沿用旧口径）。 */
const KB_STEM_H: number = 6.6;
const KB_STEM_W: number = 2;

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
  /** 批 36 §3.3：符号面板（Aa 切换）。 */
  @Prop symbolMode: boolean = false;
  /** 批 36 §7：平板等比缩放（手机 1）。 */
  @Prop sx: number = 1;
  @Prop sy: number = 1;
  @Prop capsActive: boolean = false;
  /**
   * 批 72（修 Aa 切换闪屏）：键盘整体不透明度。
   * Index 在切换字母/符号后把它从 0.25 动画回 1 —— 重建出来的新键盘是「柔和浮现」，
   * 而不是一帧硬切（重建本身躲不掉，但视觉上不再闪）。
   */
  @Prop kbOpacity: number = 1;
  /**
   * 批 73（用户 2026-11-22 01:30 定）：键盘整体纵向位移（vp）。
   * 切换字母/符号时做「旧键沉下去消失、新键从下方替补上来」：
   * 旧键 → +下沉量并淡出（被键盘井裁掉）；新键 → 从 +下沉量升回 0 并淡入。
   */
  @Prop kbShiftY: number = 0;
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
    return 'ui-parts/cap3d-' + this.slug() + '-matte.png';
  }

  private space3dRawfile(): string {
    return 'ui-parts/cap3d-space-' + this.slug() + '.png';
  }

  /** 符号面板键位（与字母面板同键数／同宽，label 即所落字符）。 */
  private symbolRows(): K33Row[] {
    const r1: K33Key[] = [
      K('~', '~', '', 21.6, 'k', '', ''), K('!', '!', '', 21.6, 'k', '', ''),
      K('@', '@', '', 21.6, 'k', '', ''), K('#', '#', '', 21.6, 'k', '', ''),
      K('$', '$', '', 21.6, 'k', '', ''), K('%', '%', '', 21.6, 'k', '', ''),
      K('^', '^', '', 21.6, 'k', '', ''), K('&', '&', '', 21.6, 'k', '', ''),
      K('*', '*', '', 21.6, 'k', '', ''), K('(', '(', '', 21.6, 'k', '', ''),
      K(')', ')', '', 21.6, 'k', '', ''), K('+', '+', '', 21.6, 'k', '', ''),
      K('Backspace', 'BACK SPACE', '', 43.2, 'back', '', ''),
    ];
    const r2: K33Key[] = [
      K('Tab', 'TAB', '', 33.6, 'tab', '', ''),
      K('{', '{', '', 22.4, 'k', '', ''), K('}', '}', '', 22.4, 'k', '', ''),
      K('[', '[', '', 22.4, 'k', '', ''), K(']', ']', '', 22.4, 'k', '', ''),
      K('|', '|', '', 22.4, 'k', '', ''), K('\\', '\\', '', 22.4, 'k', '', ''),
      K(':', ':', '', 22.4, 'k', '', ''), K('"', '"', '', 22.4, 'k', '', ''),
      K('<', '<', '', 22.4, 'k', '', ''), K('>', '>', '', 22.4, 'k', '', ''),
      K('?', '?', '', 22.4, 'k', '', ''), K('/', '/', '', 22.4, 'k', '', ''),
    ];
    const r3: K33Key[] = [
      K('Caps Lock', 'SHIFT LOCK', '', 31, 'caps', '', ''),
      K(';', ';', '', 17.25, 'k', '', ''), K('\'', '\'', '', 17.25, 'k', '', ''),
      K(',', ',', '', 17.25, 'k', '', ''), K('.', '.', '', 17.25, 'k', '', ''),
      K('-', '-', '', 17.25, 'k', '', ''), K('/', '/', '', 17.25, 'k', '', ''),
      K('=', '=', '', 17.25, 'k', '', ''), K('+', '+', '', 17.25, 'k', '', ''),
      K('*', '*', '', 17.25, 'k', '', ''), K('&', '&', '', 17.25, 'k', '', ''),
      K('^', '^', '', 17.25, 'k', '', ''), K('%', '%', '', 17.25, 'k', '', ''),
      K('$', '$', '', 17.25, 'k', '', ''),
      K('Return', 'RETURN', '', 41.4, 'return', '', ''),
    ];
    const r4: K33Key[] = [
      K('Shift', 'SHIFT', '', 47, 'shift', '', ''),
      K('§', '§', '', 21.17, 'k', '', ''), K('±', '±', '', 21.17, 'k', '', ''),
      K('×', '×', '', 21.17, 'k', '', ''), K('÷', '÷', '', 21.17, 'k', '', ''),
      K('≠', '≠', '', 21.17, 'k', '', ''), K('≤', '≤', '', 21.17, 'k', '', ''),
      K('≥', '≥', '', 21.17, 'k', '', ''), K('∞', '∞', '', 21.17, 'k', '', ''),
      K('¥', '¥', '', 21.17, 'k', '', ''), K('€', '€', '', 21.17, 'k', '', ''),
      K('Shift', 'SHIFT', '', 47, 'shift', '', ''),
    ];
    const space: K33Key[] = [K(' ', '', '', 237, 'space', '', '')];
    return [
      { y: 0, keys: r1 },
      { y: KB_ROW_H, keys: r2 },
      { y: KB_ROW_H * 2, keys: r3 },
      { y: KB_ROW_H * 3, keys: r4 },
      { y: KB_ROW_H * 4, keys: space },
    ];
  }

  /** 5 行键位表（附录 A；键宽＝修正 1 的表，写死）。 */
  private rows(): K33Row[] {
    if (this.symbolMode) {
      return this.symbolRows();
    }
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

  /**
   * 键帽等比缩放系数（批 65／增补-30 §2.1：**只按机器宽比**）。
   *
   * 作废两版错的：
   *  · 第 29 步 `widthVp/362.7` 只放大宽、不放大高 ⇒ 键拉扁；
   *  · 第 30 步 `min(宽比, 高比)` ⇒ 键被压小、余量全变缝 ⇒ 键行稀疏。
   * 本版：系数只按宽比；**宽、高、行高、纵缝、横缝全部乘同一系数**（等比，不变形）；
   * 井高由本系数导出（Stage26 `keyH = 200.1 × kx`），所以不再需要 min 兜底。
   * 平板 kx = 673.7/362.7 = 1.857 ⇒ 键 40.1×51.3vp、行高 64.1vp、纵缝 12.8vp、横缝 5.6vp。
   */
  private kx(): number {
    return this.widthVp > 0 ? this.widthVp / 362.7 : 1;
  }

  /** 平铺后每个键的绝对位置（键区内 x 从 12 起，横缝 3）。 */
  private placed(): K33Placed[] {
    const out: K33Placed[] = [];
    const rows: K33Row[] = this.rows();
    const kx: number = this.kx();
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
          label: k.label, legend: k.legend, sub: k.sub, x: px * kx,
          // 批 65：y 也按 kx（行 y = 行号×(行高+纵缝)×kx，键在行内垂直居中）
          y: (r * (KB_ROW_H + KB_VGAP) + (KB_ROW_H - KB_CAP_H) / 2) * kx,
          w: k.w * kx, kind: k.kind,
          id: (this.symbolMode ? 'S' : 'L') + ':' + rows[r].y.toString() + ':' + i.toString(),
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

  /**
   * 键杆横向中心（相对 Row 内容左缘，vp）。
   * 批 64：T4 改 flex 后行内间距由 `justifyContent(SpaceBetween)` **均分**，不再是固定 KB_HGAP，
   * 旧实现在 KB_W 绝对坐标上算 x 必然错位（键杆因此一直没挂）。这里按行实际内容宽反推间距：
   *   gap = (widthVp − 2×KB_X0 − Σ键宽) / (键数 − 1)
   * 第 i 个杆的中心 = 前 i 个键宽与间距的累计 + 半个间距。
   * 行数 = 5、每行键数不同（13/12/14/12/1），所以逐行算、不共用一份。
   */
  private stemXs(r: number): number[] {
    const out: number[] = [];
    const rows: K33Row[] = this.rows();
    if (r < 0 || r >= rows.length) {
      return out;
    }
    const keys: K33Key[] = rows[r].keys;
    if (keys.length < 2) {
      return out;
    }
    let sumW: number = 0;
    const kx: number = this.kx();
    for (let i = 0; i < keys.length; i++) {
      sumW += keys[i].w * kx;
    }
    const rowW: number = this.widthVp - KB_X0 * 2;
    const gap: number = (rowW - sumW) / (keys.length - 1);
    if (gap <= 0) {
      return out;
    }
    let x: number = 0;
    for (let i = 0; i < keys.length - 1; i++) {
      x += keys[i].w * kx;
      out.push(x + gap / 2);
      x += gap;
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
      } else if (this.machineKind === MachineKind.MODERN_2020S) {
        // 批 74：第 5 台现代机的空格条（不补这条会落到 else＝1960s 的图）
        Image($rawfile('ui-parts/cap3d-space-2020s.png'))
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
        Image($rawfile('ui-parts/cap3d-1920s-matte.png'))
          .objectFit(ImageFit.Fill).width('100%').height('100%')
          .hitTestBehavior(HitTestMode.None)
      } else if (this.machineKind === MachineKind.PORTABLE_1930S) {
        Image($rawfile('ui-parts/cap3d-1930s-matte.png'))
          .objectFit(ImageFit.Fill).width('100%').height('100%')
          .hitTestBehavior(HitTestMode.None)
      } else if (this.machineKind === MachineKind.STREAMLINED_1950S) {
        Image($rawfile('ui-parts/cap3d-1950s-matte.png'))
          .objectFit(ImageFit.Fill).width('100%').height('100%')
          .hitTestBehavior(HitTestMode.None)
      } else if (this.machineKind === MachineKind.MODERN_2020S) {
        // 批 74：第 5 台现代机的普通键帽（不补这条会落到 else＝1960s 的图）
        Image($rawfile('ui-parts/cap3d-2020s-matte.png'))
          .objectFit(ImageFit.Fill).width('100%').height('100%')
          .hitTestBehavior(HitTestMode.None)
      } else {
        Image($rawfile('ui-parts/cap3d-1960s-matte.png'))
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
    // 批 64（本轮）：键杆恢复后打点——行内容宽与各行杆数（0/1/2/3 行），用来对账「杆数 = 键数 − 1」。
    hilog.info(KDOMAIN, KTAG,
      'stems rowW=%{public}s n0=%{public}d n1=%{public}d n2=%{public}d n3=%{public}d stemW=%{public}s stemH=%{public}s',
      (this.widthVp - KB_X0 * 2).toFixed(1),
      this.stemXs(0).length, this.stemXs(1).length, this.stemXs(2).length, this.stemXs(3).length,
      (KB_STEM_W * this.kx()).toFixed(1), (KB_STEM_H * this.kx()).toFixed(1));
    // 批 65（增补-30 §5 验收）：键帽/行高/缝的权威数值——PIL 只能量到键帽亮面，这里是代码真值。
    hilog.info(KDOMAIN, KTAG,
      'geom65 kx=%{public}s capW=%{public}s capH=%{public}s rowH=%{public}s vgap=%{public}s hpad=%{public}s wellH=%{public}s',
      this.kx().toFixed(3),
      (21.6 * this.kx()).toFixed(1), (KB_CAP_H * this.kx()).toFixed(1),
      (KB_ROW_H * this.kx()).toFixed(1), (KB_VGAP * this.kx()).toFixed(1),
      (KB_X0 * this.kx()).toFixed(1), this.heightVp.toFixed(1));
  }

  /** 键帽（一个原生 Button；尺寸固定，不随 sx/sy 缩放——设计稿 §3.4）。 */
  @Builder
  capCell(p: K33Placed) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Stack() {
        this.capImage(p)
        // 批 42：帽底接触影＋顶面内凹
        Column().width('88%').height(1)
          .backgroundColor('#000000').opacity(0.08)
          .position({ x: '6%', y: '97%' })
          .hitTestBehavior(HitTestMode.None)
        Column().width('62%').height('52%')
          .backgroundColor('#000000').opacity(0.05)
          .borderRadius(6)
          .hitTestBehavior(HitTestMode.None)
        if (p.sub.length > 0 && p.kind === 'k') {
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
    // 批 65：键高也乘 kx（此前写死 27.6 ⇒ 只放大宽、把键拉扁）
    .height(KB_CAP_H * this.kx())
    .backgroundColor(Color.Transparent)
    .borderRadius(0)
    .accessibilityText(p.legend.length > 0 ? p.legend : p.label)
    .accessibilityLevel('yes')
    .accessibilityDescription(p.sub.length > 0 ? p.sub : p.label)
    // 批 61 口径保留，幅度改绝对值（设计稿 §3.4：行程 2／空格 3vp，scaleY 0.94）
    .translate({ y: this.pressedId === p.id ? (p.kind === 'space' ? 3 : 2) : 0 })
    .scale({ y: this.pressedId === p.id ? 0.94 : 1 })
    .animation({ duration: 90, curve: curves.springMotion(0.34, 0.9) })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressedId = p.id;
        this.onCapDown(this.capFor(p));
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressedId = '';
        this.onCapUp(this.capFor(p));
      }
    })
  }

  /** 某一行的键（沿用 placed() 的 id／图例，供 CapDef 与无障碍用）。 */
  private placedRow(r: number): K33Placed[] {
    const rows: K33Row[] = this.rows();
    if (r < 0 || r >= rows.length) {
      return [];
    }
    const prefix: string = (this.symbolMode ? 'S' : 'L') + ':' + rows[r].y.toString() + ':';
    return this.placed().filter((p: K33Placed) => p.id.indexOf(prefix) === 0);
  }

  build() {
    // 批 64（T4）：键盘井内容改纵向 flex——每行 `Row(justifyContent: SpaceBetween)`；
    // 键帽固定尺寸（不随 sx/sy 缩放，手机／平板一致），多余宽度全部由行内间距吸收；
    // layoutWeight 不挂键帽（固定宽子项挂 layoutWeight 会被拉伸），只用于「间距」这一层。
    // 间距上限 1.5×键宽：平板实测间距≈9.4vp、键宽 21.6vp，不触发（触发时改 Center＋固定间距）。
    Column() {
      ForEach(this.rows(), (row: K33Row, r: number) => {
        Row() {
          ForEach(this.placedRow(r), (p: K33Placed) => {
            this.capCell(p)
          }, (p: K33Placed) => p.id)
        }
        .width('100%')
        .height(KB_ROW_H * this.kx())
        // 批 65（增补-30 §2.3）：单键行（空格）改 Center——SpaceBetween 时单个子项落在行首，
        // 于是空格键左对齐、右侧全空（用户报「空格键完全错位」的根因）。
        .justifyContent(this.rows()[r].keys.length === 1 ? FlexAlign.Center : FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)
        // 批 64（本轮）：键杆恢复——杆带占原 `margin bottom` 的 6.9vp 行间距（布局总高不变），
        // x 用 stemXs() 按 flex 实际均分间距算，颜色取比井底 #050506 可辨的 #3b3733。
        if (r < this.rows().length - 1) {
          Stack({ alignContent: Alignment.TopStart }) {
            ForEach(this.stemXs(r), (sx: number, i: number) => {
              Column()
                .width(KB_STEM_W * this.kx())
                .height(KB_STEM_H * this.kx())
                .backgroundColor('#3b3733')
                .borderRadius(1)
                .position({ x: sx - KB_STEM_W / 2, y: 0 })
                .hitTestBehavior(HitTestMode.None)
            }, (sx: number, i: number) => 'stem' + r.toString() + ':' + i.toString())
          }
          .width('100%')
          .height(KB_VGAP * this.kx())
          .hitTestBehavior(HitTestMode.None)
        }
      }, (row: K33Row, r: number) => 'row' + r.toString())
    }
    .width('100%')
    .height('100%')
    // 批 65：行内左右留白也按 kx（横缝基准 3×kx＝5.6vp，与纵缝同比）
    .padding({ left: KB_X0 * this.kx(), right: KB_X0 * this.kx() })
    .justifyContent(FlexAlign.Center)
    // 批 72：切换字母/符号后整体柔和高透明度淡入（重建躲不掉，但视觉上不再硬闪）
    .opacity(this.kbOpacity)
    // 批 73：纵向位移——旧键下沉出井、新键从井下方升上来
    .translate({ y: this.kbShiftY })
  }
}
