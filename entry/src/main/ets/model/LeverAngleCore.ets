/**
 * 回车 · 拨杆角纯函数驱动器（第 0b 批）。
 *
 * 铁律（总纲/拨杆隔离）：
 *  - 纯函数：拖拽偏移 → 角度，**不含任何机型分支**；
 *  - 冻结常量：静止角／摆幅／1920s 图宽高比／支点比例——值不许改；
 *  - f(0) = 各自静止角（冻结断言测试覆盖四台机）。
 *
 * 各机型的 leverAspect / pivot 仍由 MachineCatalog.MachineSpec 提供（每台不同，
 * 见 MachineCatalog: 0.2125/0.3264/0.09/0.12），本文件不复制这些值，只冻结
 * 1920s 渲染件实际使用的常量与所有机型共用的静止角／摆幅。
 */

/** 平板静止角（度）。 */
export const LEVER_REST_DEG_TABLET: number = 30;
/** 手机静止角（度）。 */
export const LEVER_REST_DEG_PHONE: number = 15;
/** 平板摆幅（度）。 */
export const LEVER_SWING_DEG_TABLET: number = 35;
/** 手机摆幅（度）。 */
export const LEVER_SWING_DEG_PHONE: number = 20;
/** 1920s 拨杆图宽高比（536／2522，写死，不许方形层套 Contain）。 */
export const LEVER_ASPECT_1920: number = 536 / 2522;
/** 1920s 支点比例（图内 0..1）。 */
export const LEVER_PIVOT_X_1920: number = 0.500;
export const LEVER_PIVOT_Y_1920: number = 0.952;
/** 松手判定：拉过杆长一半＝换行。 */
export const LEVER_COMMIT_RATIO: number = 0.5;

/** 静止角：平板 30／手机 15。 */
export function restDegFor(isTablet: boolean): number {
  return isTablet ? LEVER_REST_DEG_TABLET : LEVER_REST_DEG_PHONE;
}

/** 摆幅：平板 35／手机 20。 */
export function swingDegFor(isTablet: boolean): number {
  return isTablet ? LEVER_SWING_DEG_TABLET : LEVER_SWING_DEG_PHONE;
}

/** 比例 clamp 到 0..1（NaN 按 0）。 */
export function clampRatio(ratio: number): number {
  if (!isFinite(ratio) || ratio <= 0) {
    return 0;
  }
  return ratio >= 1 ? 1 : ratio;
}

/** 拖拽 dy（vp）→ 比例：负截 0、超杆长截 1；杆长 ≤0 按 0。 */
export function dragRatioFor(dy: number, leverH: number): number {
  if (!isFinite(leverH) || leverH <= 0) {
    return 0;
  }
  return clampRatio(dy / leverH);
}

/** 比例 → 角度（不套动画，跟手直接赋值）：f(0) = restDeg，f(1) = restDeg + swingDeg。 */
export function angleFor(restDeg: number, swingDeg: number, ratio: number): number {
  return restDeg + clampRatio(ratio) * swingDeg;
}

/** 松手是否够换行（≥ 0.5）。 */
export function pulledEnough(ratio: number): boolean {
  return clampRatio(ratio) >= LEVER_COMMIT_RATIO;
}