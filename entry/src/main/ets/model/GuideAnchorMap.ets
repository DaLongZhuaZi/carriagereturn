/**
 * 第 16 批 2C：Canvas 页面的引导锚点登记表。
 * 说明：Canvas 绘制内容没有原生节点，必须额外挂透明原生锚点供 SpotlightOverlay
 * 的 getRectangleById 取矩形；id 必须与 Guide 步骤里的 anchorId 完全一致。
 */
export interface CanvasAnchorSpec {
  id: string;
  /** 相对 Canvas 宽高的比例矩形（0–1），用于文档说明与 fallback 校核。 */
  xRatio: number;
  yRatio: number;
  wRatio: number;
  hRatio: number;
}

export const CANVAS_ANCHORS: CanvasAnchorSpec[] = [
  { id: 'typewriter__paper', xRatio: 0.10, yRatio: 0.25, wRatio: 0.80, hRatio: 0.25 },
  { id: 'typewriter__lever', xRatio: 0.76, yRatio: 0.36, wRatio: 0.20, hRatio: 0.10 },
  { id: 'typewriter__function_row', xRatio: 0.00, yRatio: 0.90, wRatio: 1.00, hRatio: 0.06 },
];

export function canvasAnchorById(id: string): CanvasAnchorSpec | null {
  for (const a of CANVAS_ANCHORS) {
    if (a.id === id) {
      return a;
    }
  }
  return null;
}
