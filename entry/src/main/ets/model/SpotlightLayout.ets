/**
 * 回车 · 聚光灯气泡位置换算（第 10 批引导重设计，评审 M16 必做纯函数）。
 *
 * 输入：目标矩形（vp）、屏幕尺寸（vp）、气泡内容尺寸（vp）、折痕带、键盘区顶部。
 * 输出：气泡矩形＋箭头位置＋是否与目标重叠（理论分支）。
 * 纯函数：不读全局、不依赖 UI，可 Node 单测。
 */

export interface RectVp {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface BubbleLayout {
  x: number;
  y: number;
  w: number;
  h: number;
  /** 箭头 x（指向目标中心，clamp 在气泡宽度内）。 */
  arrowX: number;
  /** 箭头 y（气泡在上方时指向气泡底边，下方时指向顶边）。 */
  arrowY: number;
  /** 'below' | 'above' | 'center' */
  side: string;
  /** true＝气泡与目标重叠（两侧都放不下且空余区小于气泡高的理论分支）。 */
  overlap: boolean;
}

const EDGE: number = 16;
const GAP: number = 8;

function intersectsBand(top: number, bottom: number, bandTop: number, bandBottom: number): boolean {
  if (bandBottom <= bandTop) {
    return false;
  }
  return bottom > bandTop && top < bandBottom;
}

/** 主入口。 */
export function layoutSpotlight(target: RectVp, screenW: number, screenH: number,
  contentW: number, contentH: number, creaseTop: number, creaseBottom: number,
  keyboardTop: number): BubbleLayout {
  const w: number = Math.min(contentW, screenW - 2 * EDGE);
  const h: number = contentH;
  const cx: number = target.x + target.w / 2;
  const cy: number = target.y + target.h / 2;
  let side: string = cy < screenH / 2 ? 'below' : 'above';

  const spaceBelow: number = screenH - (target.y + target.h) - GAP - EDGE;
  const spaceAbove: number = target.y - GAP - EDGE;

  let y: number = 0;
  let overlap: boolean = false;
  const fitsBelow: boolean = spaceBelow >= h;
  const fitsAbove: boolean = spaceAbove >= h;
  if (side === 'below' && !fitsBelow && fitsAbove) {
    side = 'above';
  } else if (side === 'above' && !fitsAbove && fitsBelow) {
    side = 'below';
  }
  if ((side === 'below' && fitsBelow) || (side === 'above' && fitsAbove)) {
    y = side === 'below' ? target.y + target.h + GAP : target.y - GAP - h;
  } else {
    // 两侧都放不下：放在较大的空余区；若仍小于气泡高 → 居中并记 overlap
    const biggerBelow: boolean = spaceBelow >= spaceAbove;
    const space: number = biggerBelow ? spaceBelow : spaceAbove;
    if (space >= h) {
      y = biggerBelow ? target.y + target.h + GAP : target.y - GAP - h;
      side = biggerBelow ? 'below' : 'above';
    } else {
      y = Math.max(EDGE, (screenH - h) / 2);
      side = 'center';
      overlap = h > screenH - 2 * EDGE;
    }
  }

  // 左右：以目标中心对齐，clamp 到屏内
  let x: number = cx - w / 2;
  if (x < EDGE) {
    x = EDGE;
  }
  if (x + w > screenW - EDGE) {
    x = screenW - EDGE - w;
  }

  // 折痕带禁区（desk 半开态）：撞带则向最近一侧移出
  if (intersectsBand(y, y + h, creaseTop, creaseBottom)) {
    const upY: number = creaseTop - GAP - h;
    const downY: number = creaseBottom + GAP;
    if (upY >= EDGE) {
      y = upY;
    } else if (downY + h <= screenH - EDGE) {
      y = downY;
    }
  }

  // 键盘区禁区：气泡底越过键盘顶则上移
  if (keyboardTop > 0 && y + h > keyboardTop - GAP) {
    const shifted: number = keyboardTop - GAP - h;
    if (shifted >= EDGE) {
      y = shifted;
    }
  }

  // 箭头独立跟目标中心：x clamp 在气泡内，y 在气泡朝向目标的一边
  let arrowX: number = cx;
  if (arrowX < x + 12) {
    arrowX = x + 12;
  }
  if (arrowX > x + w - 12) {
    arrowX = x + w - 12;
  }
  const arrowY: number = side === 'below' ? y : y + h;

  return { x: x, y: y, w: w, h: h, arrowX: arrowX, arrowY: arrowY, side: side, overlap: overlap };
}
