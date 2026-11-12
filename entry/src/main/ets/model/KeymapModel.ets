/**
 * 回车 · 键位坐标表解析（界面重设计稿 §2.3）
 *
 * 每台一张 <机型>-keymap.json：
 *   master_size [2048,2048]、rows[{y, caps[{x,label}]}]、space{x_min,x_max,y_min,y_max}、bands{phone,fold}、overlay
 *
 * 换算（§2.3 钉死）：带坐标 = 母版坐标 − 带 y0，再按带宽缩放。
 *   bandPxX = masterX − band.x0；bandPxY = masterY − band.y0；
 *   显示 vp = bandPx × (显示宽 vp ÷ band.w)
 *
 * 命中判定用「键位坐标表最近的帽心」，不套统一网格（行距与帽距逐行不等）。
 * label 为 'extra' 的帽不叠字、不落字。
 */

import { resourceManager } from '@kit.LocalizationKit';

/** 一个键帽在显示坐标系里的定义。 */
export interface CapDef {
  id: string;
  label: string;
  /** 帽心 x（vp，相对键区左缘）。 */
  cx: number;
  /** 帽心 y（vp，相对键区上缘）。 */
  cy: number;
  rowIndex: number;
  /** extra 帽：留空、不可落字。 */
  isExtra: boolean;
  /** 比例坐标：渲染时用「比例 × 当前宽高」现算，避免缓存 layout 跟不上尺寸变化。 */
  xRatio: number;
  yRatio: number;
  /** 第 13 批 ①：键帽宽/高/圆角（比例，分母同上：w 用带宽、h 用 phone 带高 975）。 */
  wRatio: number;
  hRatio: number;
  rRatio: number;
  /** 第 13 批 ①：形状 'circle' | 'rounded-rect'。 */
  shape: string;
}

/** 一台机器的键位表（已换算到显示 vp）。 */
export interface KeymapLayout {
  machine: string;
  caps: CapDef[];
  /** 空格条矩形（vp）。 */
  spaceXMin: number;
  spaceXMax: number;
  spaceYMin: number;
  spaceYMax: number;
  /** 命中半径（vp）：取行距的 0.42 倍（作无逐帽几何时的回落）。 */
  hitRadius: number;
  /** 第 13 批 ①：空格条圆角（vp；缺失 → 8）。 */
  spaceR: number;
  /** 叠字颜色。 */
  overlayColor: string;
  /** 叠字字号（vp）。 */
  overlayFontSize: number;
  /** 键区满宽 vp（用于换算）。 */
  widthVp: number;
  /** 键区满高 vp。 */
  heightVp: number;
}

interface RawCap {
  x: number;
  label: string;
  /** 第 13 批 ①：逐帽几何（比例；老 keymap 缺失即回落）。 */
  wRatio?: number;
  hRatio?: number;
  rRatio?: number;
  shape?: string;
}

interface RawRow {
  y: number;
  caps: RawCap[];
}

interface RawBand {
  x0: number;
  y0: number;
  w: number;
  h: number;
}

interface RawBands {
  phone: RawBand;
  fold: RawBand;
}

interface RawOverlay {
  color_1920s?: string;
  color_1930s?: string;
  color_1950s?: string;
  color_1960s?: string;
}

interface RawSpace {
  x_min: number;
  x_max: number;
  y_min: number;
  y_max: number;
  /** 第 13 批 ①：空格条圆角（比例，分母带宽；缺失 → 8vp）。 */
  rRatio?: number;
}

interface RawKeymap {
  master_size: number[];
  rows: RawRow[];
  space: RawSpace;
  bands: RawBands;
  overlay: RawOverlay;
}

/** 解析结果缓存（按 machine + band + 尺寸）。 */
export class KeymapParser {
  /**
   * 把一份 keymap JSON 换算成**比例**键位表（§2.5：只用比例，绝不用单缩放）。
   *
   * xRatio = (母版 x − 带 x0) / 带宽
   * yRatio = (母版 y − 带 y0) / 带高
   * 显示坐标：cx = xRatio × widthVp，cy = yRatio × heightVp。
   *
   * 旧实现用单一 scale = widthVp / 带宽 同时算 cx 与 cy，只有在键区高恰好
   * = 宽 × 带高/带宽 时才成立；宽高比对不上时 cy 被系统性放大，行 y 越大偏越多
   * （§2.5 已判为错，本实现作废该式）。
   */
  static parse(jsonText: string, machine: string, fold: boolean, widthVp: number, heightVp: number,
    overlayColor: string, overlayFontSize: number): KeymapLayout {
    const raw: RawKeymap = JSON.parse(jsonText) as RawKeymap;
    const band: RawBand = fold ? raw.bands.fold : raw.bands.phone;
    // 第 13 批 ①：hRatio 分母恒为 phone 带高 975；fold 带高 853 时按 975/853 重算
    const hK: number = fold ? (975.0 / 853.0) : 1.0;
    let rowGapMin: number = 100000;
    for (let r = 1; r < raw.rows.length; r++) {
      const gapRatio: number = (raw.rows[r].y - raw.rows[r - 1].y) / band.h;
      const gap: number = gapRatio * heightVp;
      if (gap > 0 && gap < rowGapMin) {
        rowGapMin = gap;
      }
    }
    const hitRadius: number = rowGapMin < 100000 ? rowGapMin * 0.42 : heightVp * 0.09;
    const fallbackW: number = (hitRadius * 2) / widthVp;
    const caps: CapDef[] = [];
    for (let r = 0; r < raw.rows.length; r++) {
      const row: RawRow = raw.rows[r];
      for (let c = 0; c < row.caps.length; c++) {
        const cap: RawCap = row.caps[c];
        const label: string = cap.label;
        const xRatio: number = (cap.x - band.x0) / band.w;
        const yRatio: number = (row.y - band.y0) / band.h;
        const shape: string = (cap.shape === undefined || cap.shape.length === 0)
          ? 'circle' : cap.shape;
        // 回落：w 缺失 → 2×hitRadius；h 缺失 → w；r 缺失 → h/2（circle 取 w/2）
        const wr: number = cap.wRatio === undefined ? fallbackW : cap.wRatio;
        const hr: number = cap.hRatio === undefined ? wr * (widthVp / heightVp) : cap.hRatio * hK;
        const rr: number = cap.rRatio === undefined
          ? (shape === 'circle' ? wr / 2 : hr * (widthVp / heightVp) / 2)
          : cap.rRatio;
        caps.push({
          id: machine + ':' + r.toString() + ':' + c.toString(),
          label: label,
          cx: xRatio * widthVp,
          cy: yRatio * heightVp,
          rowIndex: r,
          isExtra: label === 'extra',
          xRatio: xRatio,
          yRatio: yRatio,
          wRatio: wr,
          hRatio: hr,
          rRatio: rr,
          shape: shape,
        });
      }
    }
    return {
      machine: machine,
      caps: caps,
      spaceXMin: ((raw.space.x_min - band.x0) / band.w) * widthVp,
      spaceXMax: ((raw.space.x_max - band.x0) / band.w) * widthVp,
      spaceYMin: ((raw.space.y_min - band.y0) / band.h) * heightVp,
      spaceYMax: ((raw.space.y_max - band.y0) / band.h) * heightVp,
      hitRadius: hitRadius,
      spaceR: raw.space.rRatio === undefined ? 8 : raw.space.rRatio * widthVp,
      overlayColor: overlayColor,
      overlayFontSize: overlayFontSize,
      widthVp: widthVp,
      heightVp: heightVp,
    };
  }

  /** 命中：先判空格条矩形，再取最近帽心（阈值 hitRadius）；都不中返回 null。 */
  static hitTest(layout: KeymapLayout, x: number, y: number): CapDef | null {
    if (x >= layout.spaceXMin && x <= layout.spaceXMax && y >= layout.spaceYMin && y <= layout.spaceYMax) {
      return {
        id: layout.machine + ':space',
        label: ' ',
        cx: (layout.spaceXMin + layout.spaceXMax) / 2,
        cy: (layout.spaceYMin + layout.spaceYMax) / 2,
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
    // 第 13 批 ①：有逐帽几何的按矩形判定（重叠区取帽心最近者）；无几何回落圆阈值
    let best: CapDef | null = null;
    let bestD2: number = 1e12;
    for (const cap of layout.caps) {
      const w: number = cap.wRatio * layout.widthVp;
      const h: number = cap.hRatio * layout.heightVp;
      const dx: number = x - cap.cx;
      const dy: number = y - cap.cy;
      if (w > 0 && h > 0) {
        if (Math.abs(dx) <= w / 2 && Math.abs(dy) <= h / 2) {
          const d2: number = dx * dx + dy * dy;
          if (d2 < bestD2) {
            bestD2 = d2;
            best = cap;
          }
        }
      } else {
        const dist: number = Math.sqrt(dx * dx + dy * dy);
        if (dist <= layout.hitRadius && dist * dist < bestD2) {
          bestD2 = dist * dist;
          best = cap;
        }
      }
    }
    return best;
  }
}

/** 读 rawfile 里的 keymap 文本。 */
export function readRawTextSync(rm: resourceManager.ResourceManager, path: string): string {
  const bytes: Uint8Array = rm.getRawFileContentSync(path);
  let out: string = '';
  let i: number = 0;
  while (i < bytes.length) {
    const c: number = bytes[i];
    if (c < 0x80) {
      out += String.fromCharCode(c);
      i += 1;
    } else if (c < 0xE0 && i + 1 < bytes.length) {
      out += String.fromCharCode(((c & 0x1F) << 6) | (bytes[i + 1] & 0x3F));
      i += 2;
    } else if (c < 0xF0 && i + 2 < bytes.length) {
      out += String.fromCharCode(((c & 0x0F) << 12) | ((bytes[i + 1] & 0x3F) << 6) | (bytes[i + 2] & 0x3F));
      i += 3;
    } else if (i + 3 < bytes.length) {
      const cp: number = ((c & 0x07) << 18) | ((bytes[i + 1] & 0x3F) << 12) | ((bytes[i + 2] & 0x3F) << 6) | (bytes[i + 3] & 0x3F);
      out += String.fromCodePoint(cp);
      i += 4;
    } else {
      i += 1;
    }
  }
  return out;
}
