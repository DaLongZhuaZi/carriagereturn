/**
 * 回车 · 拨杆状态机纯函数（第 0b 批）。
 *
 * 目的：把"哪台机用哪份状态"与"切机怎么重置"从 Index 的 UI 代码里抽出来，
 * 让 Node 单测能证明隔离机制（Index struct 本身无法被 Node 导入）。
 *
 * 纯函数：不读全局、不 import @kit。machine 用 MachineKind 的字符串值。
 */

/** 机型 → 状态槽位（0=1920s，1=1930s，2=1950s，3=1960s；未知回落 0）。 */
export function slotOf(machine: string): number {
  if (machine === '1930s-portable') {
    return 1;
  }
  if (machine === '1950s-streamlined') {
    return 2;
  }
  if (machine === '1960s-electric') {
    return 3;
  }
  return 0;
}

/** 四份比例状态的初值（全 0）。 */
export function zeroRatios(): number[] {
  return [0, 0, 0, 0];
}

/** 四份换行计数的初值（全 0）。 */
export function zeroTicks(): number[] {
  return [0, 0, 0, 0];
}

/** 切机纪元递增（渲染件 Watch 到变化立即回静止角、不带动画）。 */
export function nextEpoch(epoch: number): number {
  return (isFinite(epoch) ? epoch : 0) + 1;
}

/** 切机是否需要重置（同机不重置；异机重置）。 */
export function shouldResetOnSwitch(prevMachine: string, nextMachine: string): boolean {
  return prevMachine !== nextMachine;
}