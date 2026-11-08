/**
 * 回车 · 测试钩子开关（第 0 批）。
 *
 * 铁律（总纲）：状态注入面／空输出 PCM 捕获／测试时钟等测试钩子**只在测试构建开启**，
 * 发布构建全部关掉。本文件是唯一开关点；各钩子实现必须先问 TestHooks。
 *
 * 本机无 hvigor，暂不做构建变体：TEST_HOOKS_BUILD 默认 false，测试构建时由构建脚本
 * 改成 true（第 7 批补构建变体后改为编译期注入）。
 */

/** 构建期常量：发布构建 false；测试构建 true。 */
export const TEST_HOOKS_BUILD: boolean = false;

export class TestHooks {
  /** 全部钩子总开关。 */
  static enabled(): boolean {
    return TEST_HOOKS_BUILD;
  }

  /** 音效观测（角色/文件/音量/rate + PCM 捕获）。 */
  static audioTraceEnabled(): boolean {
    return TEST_HOOKS_BUILD;
  }

  /** 拨杆状态注入（必须走与手势相同的处理函数）。 */
  static leverInjectEnabled(): boolean {
    return TEST_HOOKS_BUILD;
  }

  /** 确定性测试时钟（探针通过前不建）。 */
  static testClockEnabled(): boolean {
    return TEST_HOOKS_BUILD;
  }
}