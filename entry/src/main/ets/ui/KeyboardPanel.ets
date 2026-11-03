/**
 * 回车 · 自绘 QWERTY 机械键盘契约（阶段1 定稿）
 *
 * 实现要求（调研报告 §1 + 风格板 §5）：
 * - 容器级 onTouch + 坐标到键位映射，不要每键各挂 onTouch；
 * - 不用 onClick：onClick 单点、抬手才触发，拿不到按下当刻，也做不了多指同按；
 * - Map<触点id, 键> 维护状态；TouchObject.touches 不保证按 id 顺序，不要按数组序取；
 *   抬手后 id 会复用，Up/Cancel 必须清理该 id；
 * - 按下 animateTo + springCurve(0, 1, 200, 18)，缩放约 0.92；松开 springMotion()；
 *   禁用 keyframeAnimateTo（不支持弹簧曲线）；
 * - 动画只动 transform 与透明度，不在按下瞬间改宽高 / 字号 / 布局；
 * - 声音必须在 TouchType.Down 当刻触发（实现方在 onKeyDown 回调里 fire-and-forget）。
 */

/** 一次按键提交。`ch` 为空串表示这是一次纯功能键（此时 `action` 必为功能枚举）。 */
export interface KeyCommit {
  /** 单次上屏的字符；可为空（功能键）。 */
  ch: string;
  /** 该键帽的语义动作，供文档模型决定插入还是删除。 */
  action: KeyAction;
}

/** 键帽的语义动作。 */
export enum KeyAction {
  /** 插入 ch 到光标处。 */
  INSERT = 'insert',
  /** 打一个空格（走空格音效）。 */
  SPACE = 'space',
  /** 退格删左侧。 */
  BACKSPACE = 'backspace',
  /** 回车换行（走回车复位音效）。 */
  RETURN = 'return',
  /** 切档（Shift 锁定态由键盘内部维护，提交时把结果字符一并给出）。 */
  SHIFT = 'shift',
  /** 切换为中文系统输入法通道（阶段2 接线，阶段1 只留回调）。 */
  SWITCH_LANGUAGE = 'switch-language',
}

/** 键盘对外回调。实现方在 TouchType.Down 当刻同步调用 onKeyDown，不等 Up。 */
export interface KeyboardCallbacks {
  /** 按下当刻：实现方在这里播音 / 震动 / 起落字动画。 */
  onKeyDown(key: string, action: KeyAction): void;
  /** 抬手：仅用于键帽视觉回弹，不播音。 */
  onKeyUp(key: string, action: KeyAction): void;
  /** 真正把字符交给文档模型（可实现为按下当刻立即调用）。 */
  onCommit(commit: KeyCommit): void;
  /** 行末预告铃等键盘侧副作用由实现方自行触发。 */
  onBell(): void;
}

/** 键盘显示参数（三态与换机时只换这些，不重建组件实例）。 */
export interface KeyboardViewSpec {
  keycapColor: string;
  /** 键盘区总高（vp），由主屏按屏高与纸面高度算出。 */
  heightVp: number;
  /** 是否显示中文 / 英文切换键（阶段2 起可隐藏）。 */
  showLanguageKey: boolean;
}
