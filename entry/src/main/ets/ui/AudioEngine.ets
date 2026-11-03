/**
 * 回车 · 音频引擎契约（阶段1 定稿）
 *
 * 实现要求（调研报告 §1）：
 * - media.createSoundPool，启动时预加载整套机器音包（不要现用现加载）；
 * - 单音解码后不超过 1MB、时长建议 100ms 内；
 * - 同 soundId 重播会先停再播造成"吃音"，用 2~3 个同类变体轮询 + rate 轻微随机缓解；
 * - rendererFlags: 1 走低延迟通道，StreamUsage.STREAM_USAGE_MUSIC；
 * - 声音必须在 TouchType.Down 当刻触发，不等 Up；
 * - 震动 @ohos.vibrator，15~30ms，usage: 'touch'；系统触感开关可能关掉震动，
 *   震动只能做加分项，不能做唯一反馈；同一 Down 回调里依次触发动画、播音、震动，
 *   且不要 await 震动再播声音（会叠加延迟）。
 */

/** 音效角色。文件与角色的对应关系由实现方按 rawfile/sound/pack/ 实际文件名定。 */
export enum SoundRole {
  /** 按键主音（12 变体轮询）。 */
  KEY = 'key',
  /** 空格键。 */
  SPACE = 'space',
  /** 行末预告铃（约 8 字时响一声）。 */
  BELL = 'bell',
  /** 回车 / 拨杆换行复位。 */
  CARRIAGE_RESET = 'carriage-reset',
  /** 退格。 */
  BACKSPACE = 'backspace',
}

/** 音频引擎对外接口。 */
export interface AudioEngineExposed {
  /** 预加载整套机器音包；失败不抛，回退为静音并置 ready=false。 */
  preload(packName: string): Promise<boolean>;
  /** 按下当刻同步调用，内部 fire-and-forget，绝不 await。 */
  playKey(): void;
  playSpace(): void;
  playBell(): void;
  playCarriageReset(): void;
  playBackspace(): void;
  /** 单次触感反馈 15~30ms。 */
  vibrate(): void;
  /** 设置项联动。 */
  setVolume(volume: number): void;
  setSoundEnabled(enabled: boolean): void;
  setVibrationEnabled(enabled: boolean): void;
  /** 页面退出时释放 SoundPool 与资源。 */
  release(): void;
}
