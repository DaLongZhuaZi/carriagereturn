/**
 * 回车 · 设置页纯逻辑（第 6 批 F6）。
 *
 * 稳定 id（N-1）：删除方式持久化 'direct'|'ask'|'trash'，显示文案走 string.json；
 * 音量 0..1（prefs）与 UI 0..100 的换算；默认纸张 id 白名单。
 */

export const DELETE_MODE_DIRECT: string = 'direct';
export const DELETE_MODE_ASK: string = 'ask';
export const DELETE_MODE_TRASH: string = 'trash';
export const DELETE_MODE_DEFAULT: string = DELETE_MODE_TRASH;

/** 删除方式白名单；非法/空回落 'trash'（最安全，可恢复）。 */
export function deleteModeOf(raw: string): string {
  if (raw === DELETE_MODE_DIRECT || raw === DELETE_MODE_ASK || raw === DELETE_MODE_TRASH) {
    return raw;
  }
  return DELETE_MODE_DEFAULT;
}

/** 下一档：direct→ask→trash→direct（设置页点击循环）。 */
export function nextDeleteMode(raw: string): string {
  const m: string = deleteModeOf(raw);
  if (m === DELETE_MODE_DIRECT) { return DELETE_MODE_ASK; }
  if (m === DELETE_MODE_ASK) { return DELETE_MODE_TRASH; }
  return DELETE_MODE_DIRECT;
}

/** 音量 0..100 → prefs 0..1；非法按 0.7。 */
export function volumeToPref(v0to100: number): number {
  if (!isFinite(v0to100)) { return 0.7; }
  const v: number = v0to100 < 0 ? 0 : (v0to100 > 100 ? 100 : v0to100);
  return v / 100;
}

/** prefs 0..1 → UI 0..100；非法按 70。 */
export function prefToVolume(pref: number): number {
  if (!isFinite(pref)) { return 70; }
  const p: number = pref < 0 ? 0 : (pref > 1 ? 1 : pref);
  return Math.round(p * 100);
}

/** 纸张 id 白名单（与 PaperKind 枚举值一致）；非法回落 fallback。 */
export function paperPrefOf(raw: string, fallback: string): string {
  if (raw === 'letter' || raw === 'manuscript' || raw === 'postcard' || raw === 'memo') {
    return raw;
  }
  return fallback;
}
