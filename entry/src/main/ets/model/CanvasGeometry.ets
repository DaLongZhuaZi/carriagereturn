/**
 * 第 16 批 2A：Canvas 几何纯函数模块（设计稿 16 号 §3.2）
 *
 * 只接受参数、只返回数值，不读写 @State、不依赖 UI 上下文。
 * 参考机坐标系：673.7 × 1006.3vp（15 号稿 §1.3）；变换矩阵：translate(tx,ty) ∘ scale(s)。
 * 说明：产品页当前仍沿用 Index 的 stage 布局（stageWidth=窗口宽）；本模块同时提供
 * 参考机变换与若干可复用几何函数，CanvasTypewriter 绘制时使用同一套公式。
 */

export interface CanvasTransform {
  scale: number;
  tx: number;
  ty: number;
}

/** 参考机宽度／高度（vp）。 */
export const REF_WIDTH_VP: number = 673.7;
export const REF_HEIGHT_VP: number = 1006.3;

/** §1.4 变换矩阵：scale=min(屏宽/673.7, 屏高/1006.3) 上限 1，水平居中，顶对齐 topInset。 */
export function computeTransform(viewW: number, viewH: number, topInset: number): CanvasTransform {
  const s: number = Math.min(viewW / REF_WIDTH_VP, viewH / REF_HEIGHT_VP, 1.0);
  return {
    scale: s,
    tx: (viewW - REF_WIDTH_VP * s) / 2,
    ty: topInset,
  };
}

/** 字车几何：Hc = Pw×0.17（CarriageLayers / Index 同源）。 */
export function carriageHeightOf(paperWidthVp: number): number {
  return paperWidthVp * 0.17;
}

export function knobDOf(carriageHeightVp: number): number {
  return carriageHeightVp * 0.92;
}

export function baseWOf(paperWidthVp: number, carriageHeightVp: number): number {
  return paperWidthVp + 2 * knobDOf(carriageHeightVp);
}

export function baseLeftOf(stageWidthVp: number, paperWidthVp: number, carriageHeightVp: number): number {
  const x: number = (stageWidthVp - paperWidthVp) / 2 - knobDOf(carriageHeightVp);
  return x < 0 ? 0 : x;
}

export function rollWOf(paperWidthVp: number, rollerWidthRatio: number): number {
  return paperWidthVp / rollerWidthRatio;
}

export function rollXOf(stageWidthVp: number, paperWidthVp: number, rollerWidthRatio: number): number {
  const rollW: number = rollWOf(paperWidthVp, rollerWidthRatio);
  return (stageWidthVp - paperWidthVp) / 2 - (rollW - paperWidthVp) / 2;
}

/** 纸带基数：marginB + lineHeight + 44 + bandShift（§3.2）。
 *  paperTop = carriageTop − 本函数 − cursorLine×lineHeight。 */
export function paperBandBaseOf(marginBVp: number, lineHeightVp: number, bandShiftVp: number): number {
  return marginBVp + lineHeightVp + 44 + bandShiftVp;
}

/** 打击行 = 字车条顶 − 底边距 − 行高/2 − strikeShift。 */
export function strikeLineOf(carriageTopVp: number, marginBVp: number, lineHeightVp: number,
  strikeShiftVp: number): number {
  return carriageTopVp - marginBVp - lineHeightVp / 2 - strikeShiftVp;
}

/** 纸高定值：Ph = Pw × 1.414。 */
export function paperHeightOf(paperWidthVp: number): number {
  return paperWidthVp * 1.414;
}

/** 每行字数：floor((Pw − 2×marginH) / charWidth)，下限 6。 */
export function charsPerLineOf(paperWidthVp: number, marginHVp: number, charWidthVp: number): number {
  if (charWidthVp <= 0) {
    return 6;
  }
  const n: number = Math.floor((paperWidthVp - 2 * marginHVp) / charWidthVp);
  return n > 6 ? n : 6;
}

/** 每字行程 = maxTravel / charsPerLine（参考机坐标）。 */
export function travelPerCharOf(maxTravelVp: number, charsPerLine: number): number {
  return charsPerLine > 0 ? maxTravelVp / charsPerLine : maxTravelVp;
}

/** 字号链（15 号稿 §7.3 口径 b）：17–24vp，lineHeight=fs×30/17。 */
export function fontSizeClamp(fs: number): number {
  if (fs < 17) {
    return 17;
  }
  if (fs > 24) {
    return 24;
  }
  return fs;
}

export function lineHeightOf(fontSizeVp: number): number {
  return fontSizeVp * (30 / 17);
}

/** 拨杆几何（LeverAngleCore / 蓝图）：宽 = Hc×比例；高 = 宽 / leverAspect。 */
export function leverWidthOf(carriageHeightVp: number, sizeRatio: number): number {
  return carriageHeightVp * 1.84 * sizeRatio;
}

export function leverHeightOf(leverWidthVp: number, leverAspect: number): number {
  return leverWidthVp / leverAspect;
}

/** 拨杆角：静止 + 摆幅 × 拖拽比例（0..1）。 */
export function leverAngleAt(restDeg: number, swingDeg: number, ratio: number): number {
  const r: number = ratio < 0 ? 0 : (ratio > 1 ? 1 : ratio);
  return restDeg + swingDeg * r;
}

/** 拨杆比例：纵向拖拽 / leverH，0..1；≥0.5 为过半（C2）。 */
export function dragRatioOf(dyRawVp: number, leverHeightVp: number): number {
  if (leverHeightVp <= 0) {
    return 0;
  }
  const r: number = dyRawVp / leverHeightVp;
  return r < 0 ? 0 : (r > 1 ? 1 : r);
}

/** 过半判定（LEVER_COMMIT_RATIO=0.5）。 */
export function pulledEnoughOf(ratio: number): boolean {
  return ratio >= 0.5;
}

/** 2A-3 的参考验算值（供批报告与 hilog）：按平台返回 §7.3 的 paperTop/carriageTop。 */
export interface RefMetrics {
  paperTop: number;
  carriageTop: number;
  strikeLine: number;
}

export function referenceMetrics(isTablet: boolean): RefMetrics {
  if (isTablet) {
    return { paperTop: 281.8, carriageTop: 403.2, strikeLine: 347.0 };
  }
  return { paperTop: 123.0, carriageTop: 217.0, strikeLine: 182.0 };
}
