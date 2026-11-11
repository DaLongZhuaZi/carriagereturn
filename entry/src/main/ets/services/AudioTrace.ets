/**
 * 回车 · 音效观测钩子（第 0 批，测试构建专用）。
 *
 * 空输出 PCM 捕获的"选择层"证据：记录每次 emit 的角色／文件／音量／rate，
 * 证明"某台机、某个动作选了哪一个音效文件"。"响不响"（频谱/包络）由
 * tools/audio-verify.py 离线解码 rawfile 音频计算；真机扬声器听感留第 7 批冒烟。
 *
 * 发布构建：TestHooks.enabled() === false 时 emitTrace 第一行即返回，零成本。
 */

import { TestHooks } from './TestHooks';

/** 一次音效发射的观测记录。 */
export interface AudioEmitTrace {
  role: string;
  file: string;
  /** 第 4 批 F8：音效包名（证明“每台独立”选择层）。 */
  pack: string;
  volume: number;
  rate: number;
  atMs: number;
}

export type AudioEmitCallback = (t: AudioEmitTrace) => void;

/** 音效观测（静态，无 UI 依赖）。 */
export class AudioTrace {
  private static emitCb: AudioEmitCallback | null = null;

  /** 注册发射记录回调（仅测试构建有效）。 */
  static onEmit(cb: AudioEmitCallback): void {
    if (!TestHooks.audioTraceEnabled()) {
      return;
    }
    AudioTrace.emitCb = cb;
  }

  /** AudioService.emit() 调用；发布构建立即返回。 */
  static emitTrace(role: string, file: string, volume: number, rate: number, pack: string): void {
    if (!TestHooks.audioTraceEnabled() || AudioTrace.emitCb === null) {
      return;
    }
    AudioTrace.emitCb({
      role: role,
      file: file,
      pack: pack,
      volume: volume,
      rate: rate,
      atMs: Date.now(),
    });
  }
}