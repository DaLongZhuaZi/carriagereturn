/**
 * 回车 · 候选栏选项纯函数（第 2 批 F15）。
 * 候选数量默认 9（5–15）；候选字号 12–20；chip 高预算 ≤44vp（固定栏高）。
 */

export const CANDIDATE_COUNT_DEFAULT: number = 9;
export const CANDIDATE_COUNT_MIN: number = 5;
export const CANDIDATE_COUNT_MAX: number = 15;
export const CANDIDATE_SIZE_DEFAULT: number = 15;
export const CANDIDATE_SIZE_MIN: number = 12;
export const CANDIDATE_SIZE_MAX: number = 20;
export const CANDIDATE_CHIP_MAX_HEIGHT: number = 44;

/** 数量 clamp 到 5..15（NaN/0 回落默认）。 */
export function clampCandidateCount(n: number): number {
  if (!isFinite(n) || n <= 0) {
    return CANDIDATE_COUNT_DEFAULT;
  }
  const v: number = Math.floor(n);
  if (v < CANDIDATE_COUNT_MIN) { return CANDIDATE_COUNT_MIN; }
  if (v > CANDIDATE_COUNT_MAX) { return CANDIDATE_COUNT_MAX; }
  return v;
}

/** 字号 clamp 到 12..20（NaN/0 回落默认）。 */
export function clampCandidateSize(n: number): number {
  if (!isFinite(n) || n <= 0) {
    return CANDIDATE_SIZE_DEFAULT;
  }
  const v: number = Math.floor(n);
  if (v < CANDIDATE_SIZE_MIN) { return CANDIDATE_SIZE_MIN; }
  if (v > CANDIDATE_SIZE_MAX) { return CANDIDATE_SIZE_MAX; }
  return v;
}

/** chip 估算高：字号 × 1.4 行高 + 上下 padding 12 + 边框 4。 */
export function chipHeightOf(fontSize: number): number {
  const fs: number = clampCandidateSize(fontSize);
  return Math.round(fs * 1.4 + 12 + 4);
}

/** 该字号是否在 44vp 栏高预算内。 */
export function chipFits(fontSize: number): boolean {
  return chipHeightOf(fontSize) <= CANDIDATE_CHIP_MAX_HEIGHT;
}