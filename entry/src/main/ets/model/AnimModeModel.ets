/**
 * 第 23 批 · 19 号稿 §4-2：分机型动画模式的**纯函数模型**。
 *
 * 约束（19 号稿 §4-2）：本文件不 import ArkUI（也不 import 任何渲染层），只为被 Canvas 与单测共用。
 * 口径（19 号稿 §2.5 模式矩阵）：
 *   写实（1920s／1930s／1950s）：视觉位移 V = O（rollerK = 1.0），拱固定 archFixX；
 *   模拟（同三机）：V = 0.3×O（rollerK = 0.3），拱追踪落字点；
 *   电动（1960s）：单套，V = O（rollerK = 1.0），拱固定 archFixX。
 * 不变量（§2.1）：逻辑 O 永远全幅，与模式无关；纸筒一体；底座／支架不动；时序不变。
 */
import { MachineKind } from './DocModel';

/** 模式标识（与 `anim.mode.<machine>` 落盘值一致）。 */
export const ANIM_MODE_REALISTIC: string = 'realistic';
export const ANIM_MODE_SIMULATED: string = 'simulated';

/** 模拟模式位移系数（19 号稿 Q2(a) 定案 0.3）。 */
export const SIM_ROLLER_K: number = 0.3;

/** 模式切换过渡时长（19 号稿 §3.3：200ms）。 */
export const MODE_TRANS_DUR_MS: number = 200;

/**
 * 视觉位移系数 K：V = K × O。
 * - 1960s：单套电动，恒 1.0（不受模式影响）。
 * - 其余三机：写实 1.0；模拟 0.3。
 * isTablet 为同签名保留参数（双端 K 相同），19 号稿 §4-2 明确「模拟 0.3 双端」。
 */
export function rollerKFor(mode: string, isTablet: boolean, machineKind: MachineKind): number {
  if (machineKind === MachineKind.ELECTRIC_1960S) {
    return 1.0;
  }
  return mode === ANIM_MODE_SIMULATED ? SIM_ROLLER_K : 1.0;
}

/** 写实／电动模式下拱的固定位置＝行首落字点（Q7(a)：paperX + marginH，手机 97.3vp）。 */
export function archFixXFor(paperX: number, marginH: number): number {
  return paperX + marginH;
}

/** 过渡：滚筒系数 Linear 内插。 */
export function modeTransRollerK(from: number, to: number, p: number): number {
  const t: number = p < 0 ? 0 : (p > 1 ? 1 : p);
  return from + (to - from) * t;
}

/** 过渡：拱位置 ease-out 三次方内插（1−(1−p)³），与打击段同曲线，不过冲。 */
export function modeTransArchX(from: number, to: number, p: number): number {
  const t: number = p < 0 ? 0 : (p > 1 ? 1 : p);
  const e: number = 1 - Math.pow(1 - t, 3);
  return from + (to - from) * e;
}
