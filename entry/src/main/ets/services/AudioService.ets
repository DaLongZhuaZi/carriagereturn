/**
 * 回车 · 音频引擎（阶段1 实现）
 *
 * 职责（核心打字体验调研报告 §1、技术架构设计 §5）：
 * - media.createSoundPool 在启动时一次性预加载整套机器音包（绝不现用现加载）；
 * - rendererFlags: 1 走低延迟通道，usage: StreamUsage.STREAM_USAGE_MUSIC（media.d.ts createSoundPool 注释原文）；
 * - 声音在 TouchType.Down 当刻触发：本类所有 play* 都是 fire-and-forget、同步返回 void、内部不 await，
 *   调用方可以在同一个 Down 回调里「动画 → 播音 → 震动」依次调用，不会因为等震动而叠加延迟；
 * - 同 soundId 重播会先停再播造成「吃音」：按角色做变体轮询（KEY 12 变体、BELL 3 变体）
 *   并用 PlayParameters.pitch 轻微随机（0.97~1.03）避免机关枪效应；
 * - 震动走 @ohos.vibrator，15~30ms、usage: 'touch'：系统触感开关可能关掉震动，
 *   所以震动只做加分项，失败一律静默，不抛不崩；
 * - 失败降级：SoundPool 创建失败 / 单音加载失败 → ready=false 静默，单个音失败不影响其他音；
 * - 零联网：只读本地 rawfile，不引入任何网络 API、遥测、服务器依赖。
 *
 * 角色 → 文件映射（实测 assets/sounds/pack/BUILD-REPORT.txt 的 23 个文件名）：
 * | SoundRole.KEY            | key-01.ogg ~ key-12.ogg（12 变体轮询）
 * | SoundRole.SPACE          | space-01.ogg
 * | SoundRole.BELL           | bell-01.ogg ~ bell-03.ogg（3 变体轮询）
 * | SoundRole.CARRIAGE_RESET | carriage-reset-01.ogg
 * | SoundRole.BACKSPACE      | key-alt-01.ogg（0.090s 短音）；包内没有 alt 变体时退回 key-11.ogg
 * | 预载但不入角色池         | key-transient.ogg（瞬态层）、pack2-key-01..04.ogg（第二台机变体；包名为 pack2 时才入 KEY 池）
 * 运行时以 rawfile/sound/<pack>/ 的真实目录列举为准（getRawFileListSync），列举失败才退回上面的兜底表。
 * 音效包落位由资源任务负责；rawfile/sound/pack/ 落位后需真机复验文件名是否与上面一致。
 *
 * 未验证点（产品定义稿 §8.1 第 4 项，本机无法判定，待真机）：
 * 1) SoundPool 同 soundId 重播到底是「停旧启新」还是「多流重叠」：变体轮询是按最坏情况
 *    （停旧启新）做的缓解；真机若证实为多流重叠，轮询也不必撤，它仍能消除机关枪感。
 * 2) load(fd, offset, length) 的 fd 关闭时机：本实现按 getRawFd 的 NOTE「用完关闭，防句柄泄漏」
 *    在 load 的 Promise 落定后 closeRawFdSync；若真机出现 5400103 I/O error，再改长驻 fd 复验。
 * 3) PlayParameters.rate 在真实 d.ts 里是 AudioRendererRate 枚举（0/1/2），不是浮点倍率，
 *    因此调研报告里「rate 0.97~1.03」按真实签名落到 PlayParameters.pitch（0.25~4.0，API 26 起）。
 *    若运行时拒绝 pitch（401），本类自动关掉 pitch 用默认音高重播一次，不会整套静音。
 *
 * ArkTS 显式类型，禁 any/unknown；日志为英文诊断串，界面文案不落在这里。
 */

import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { common } from '@kit.AbilityKit';
import { resourceManager } from '@kit.LocalizationKit';
import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AudioEngineExposed, SoundRole } from '../ui/AudioEngine';
import { AudioTrace } from './AudioTrace';

const DOMAIN: number = 0x0000;
const TAG: string = 'AudioService';

/** 音效包父目录：resources/rawfile/sound/（技术架构设计 §3）。 */
const SOUND_ROOT: string = 'sound';
const OGG_SUFFIX: string = '.ogg';
/** 默认机音效包目录名：assets/sounds/pack/ 落位后即 rawfile/sound/pack/。 */
const DEFAULT_PACK_NAME: string = 'pack';
/** 并发流上限：快速连打叠加铃与回车复位要留足并发（调研报告 §1 建议 8~16）。 */
const MAX_STREAMS: number = 12;
/** 低延迟通道：media.d.ts createSoundPool 注释「SoundPool supports setting rendererFlags to 1 for low-latency」。 */
const LOW_LATENCY_RENDERER_FLAGS: number = 1;
const DEFAULT_VOLUME: number = 0.8;
const MIN_VOLUME: number = 0.0;
const MAX_VOLUME: number = 1.0;
/** pitch 抖动区间：同一变体连续重播时去机械化。 */
const PITCH_MIN: number = 0.97;
const PITCH_MAX: number = 1.03;
/** 震动时长 15~30ms，取中值 20ms（@ohos.vibrator VibrateTime.duration）。 */
const VIBRATE_DURATION_MS: number = 20;
const VIBRATE_ID: number = 0;
/** VibrateAttribute.usage 的 Usage 字符串联合类型（@ohos.vibrator.d.ts:502）。 */
const VIBRATE_USAGE: vibrator.Usage = 'touch';
/** 参数错误码：pitch 被运行时拒绝时用它做降级判定。 */
const PARAM_ERROR_CODE: number = 401;
/** 主键变体数 key-01..key-12。 */
const KEY_VARIANT_COUNT: number = 12;
/** 第二台机包变体数 pack2-key-01..04。 */
const MACHINE2_VARIANT_COUNT: number = 4;
/** 退格兜底变体：包内没有 alt 变体时用最短的主键变体。 */
const BACKSPACE_FALLBACK_STEM: string = 'key-11';
/** 兜底文件名表：目录列举失败时按 assets/sounds/pack/ 实测名单独个试载。 */
const FALLBACK_SHARED_STEMS: string[] = [
  'space-01',
  'bell-01',
  'bell-02',
  'bell-03',
  'carriage-reset-01',
  'key-transient',
  'key-alt-01',
];

/** 一个角色的播放池：soundIds 为已加载变体，cursor 为轮询游标。 */
interface SoundBank {
  soundIds: number[];
  cursor: number;
}

function logInfo(msg: string): void {
  hilog.info(DOMAIN, TAG, '%{public}s', msg);
}

function logWarn(msg: string): void {
  hilog.warn(DOMAIN, TAG, '%{public}s', msg);
}

function pad2(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}

/**
 * 音频引擎。实现 ui/AudioEngine.ets 的 AudioEngineExposed 契约。
 *
 * 接线：页面（或 Ability）先把 Context 注入进来最稳：
 *   audioService.attachContext(this.getUIContext().getHostContext() as common.Context);
 * 必须注入：页面在 preload() 之前调 attachContext()。不再用全局 getContext() 兜底（API 18 起废弃）。
 */
export class AudioService implements AudioEngineExposed {
  private pool: media.SoundPool | null = null;
  private resourceMgr: resourceManager.ResourceManager | null = null;
  private banks: Map<SoundRole, SoundBank> = new Map<SoundRole, SoundBank>();
  private stemIds: Map<string, number> = new Map<string, number>();
  /** 第 0 批：soundId → stem 反查（测试构建音效观测用；发布构建不读）。 */
  private idToStem: Map<number, string> = new Map<number, string>();
  private loadedStems: string[] = [];
  private packName: string = '';
  private packPath: string = '';
  /** 第 4 批 F8：preload 代际；旧的过期请求不得覆盖新包。 */
  private preloadGeneration: number = 0;
  private ready: boolean = false;
  private soundEnabled: boolean = true;
  private vibrationEnabled: boolean = true;
  private volume: number = DEFAULT_VOLUME;
  /** pitch 是否被运行时接受；收到 401 后关掉并用默认音高重播。 */
  private pitchAccepted: boolean = true;

  /** 流控（§2.9 第 2 项）：按角色记并发 streamId，满则停最旧；铃/复位受保护永不被顶。 */
  private streams: number[] = [];
  private streamRole: Map<number, SoundRole> = new Map<number, SoundRole>();
  private streamAt: Map<number, number> = new Map<number, number>();
  private peakConcurrent: number = 0;
  private refusedCount: number = 0;

  /** 各角色并发上限：主键 6、空格 2、铃 1、复位 1、删除 2。 */
  private capFor(role: SoundRole): number {
    if (role === SoundRole.KEY) { return 6; }
    if (role === SoundRole.SPACE) { return 2; }
    if (role === SoundRole.BELL) { return 1; }
    if (role === SoundRole.CARRIAGE_RESET) { return 1; }
    return 2;
  }

  /** 受保护角色：铃与回车复位，永不被顶掉。 */
  private isProtected(role: SoundRole): boolean {
    return role === SoundRole.BELL || role === SoundRole.CARRIAGE_RESET;
  }

  metrics(): string {
    return 'peak=' + this.peakConcurrent.toString() + ' refused=' + this.refusedCount.toString()
      + ' live=' + this.streams.length.toString();
  }

  // ------------------------------------------------------------------
  // 契约外的接线辅助（不改契约字段，只是让 service 层拿得到 resourceManager）
  // ------------------------------------------------------------------

  /** 注入宿主 Context（推荐在页面 aboutToAppear 里注入）。 */
  attachContext(context: common.Context): void {
    this.resourceMgr = context.resourceManager;
  }

  /** 音频是否就绪；未就绪时所有 play* 都是静默空实现（契约外，供上层诊断）。 */
  isReady(): boolean {
    return this.ready;
  }

  // ------------------------------------------------------------------
  // 契约实现
  // ------------------------------------------------------------------

  /** 预加载整套机器音包；失败不抛，回退为静音并置 ready=false。 */
  async preload(packName: string): Promise<boolean> {
    const path: string = this.packPathOf(packName);
    if (this.ready && this.packPath === path) {
      return true;
    }
    const gen: number = this.preloadGeneration + 1;
    this.preloadGeneration = gen;

    const rm: resourceManager.ResourceManager | null = this.resolveResourceManager();
    if (rm === null) {
      logWarn('preload skipped: no resourceManager, stay silent');
      return false;
    }

    // 第 4 批 F8（B-5/M-12）：双缓冲。已有 pool 不复用 teardown——旧 banks 继续可播，
    // 新包加载完再原子替换；旧请求由 preloadGeneration 丢弃。
    let pool: media.SoundPool | null = this.pool;
    if (pool === null) {
      const rendererInfo: audio.AudioRendererInfo = {
        usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
        rendererFlags: LOW_LATENCY_RENDERER_FLAGS,
      };
      try {
        pool = await media.createSoundPool(MAX_STREAMS, rendererInfo);
      } catch (err) {
        pool = null;
      }
      if (pool === null) {
        logWarn('createSoundPool failed, stay silent');
        return false;
      }
      this.pool = pool;
    }
    if (gen !== this.preloadGeneration) {
      return false;
    }

    const stems: string[] = this.listStems(rm, path, packName);
    const nextLoaded: string[] = [];
    const nextStemIds: Map<string, number> = new Map<string, number>();
    const nextIdToStem: Map<number, string> = new Map<number, string>();
    for (const stem of stems) {
      const soundId: number = await this.loadOne(rm, path, stem);
      if (gen !== this.preloadGeneration) {
        // 过期请求：不替换任何当前状态，丢弃已加载 id
        if (soundId > 0 && this.pool !== null) {
          this.pool.unload(soundId).catch(() => {});
        }
        return false;
      }
      if (soundId > 0) {
        nextLoaded.push(stem);
        nextStemIds.set(stem, soundId);
        nextIdToStem.set(soundId, stem);
      }
    }
    nextLoaded.sort();

    // 记录旧 id 供替换后卸载（旧 banks 在新 banks 建好前仍可播）
    const oldIds: number[] = [];
    this.banks.forEach((bank: SoundBank) => {
      for (let i = 0; i < bank.soundIds.length; i++) {
        oldIds.push(bank.soundIds[i]);
      }
    });
    this.stemIds.forEach((id: number) => { oldIds.push(id); });

    this.loadedStems = nextLoaded;
    this.stemIds = nextStemIds;
    this.idToStem = nextIdToStem;
    this.packName = packName;
    this.packPath = path;
    this.banks = new Map<SoundRole, SoundBank>();
    this.buildBanks(packName);
    this.ready = this.hasAnySound();

    for (let i = 0; i < oldIds.length; i++) {
      if (nextStemIds.get(this.idToStemName(oldIds[i])) === undefined && this.pool !== null) {
        this.pool.unload(oldIds[i]).catch(() => {});
      }
    }

    const loadedText: string = this.loadedStems.length.toString();
    const readyText: string = this.ready ? 'true' : 'false';
    logInfo('preload pack=' + path + ' loaded=' + loadedText + ' ready=' + readyText);
    return this.ready;
  }

  /** 旧 id 是否仍在新 stems 里（名字反查；找不到不卸载也无害）。 */
  private idToStemName(id: number): string {
    const stem: string | undefined = this.idToStem.get(id);
    return stem === undefined ? '' : stem;
  }

  /** 第 4 批 F8：机型 → 音效包目录（1920s 基线，其余各一包）。 */
  static packForMachine(machine: string): string {
    if (machine === '1930s-portable') { return 'pack-1930'; }
    if (machine === '1950s-streamlined') { return 'pack-1950'; }
    if (machine === '1960s-electric') { return 'pack-1960'; }
    return DEFAULT_PACK_NAME;
  }

  /** 按键主音：Down 当刻同步调用，内部 fire-and-forget，绝不 await。 */
  playKey(): void {
    this.playByRole(SoundRole.KEY);
  }

  playSpace(): void {
    this.playByRole(SoundRole.SPACE);
  }

  playBell(): void {
    this.playByRole(SoundRole.BELL);
  }

  playCarriageReset(): void {
    this.playByRole(SoundRole.CARRIAGE_RESET);
  }

  playBackspace(): void {
    this.playByRole(SoundRole.BACKSPACE);
  }

  /** 按角色播放（契约外的通用入口，语义与上面五个方法一致，同步返回）。 */
  playByRole(role: SoundRole): void {
    if (!this.ready || !this.soundEnabled) {
      return;
    }
    const pool: media.SoundPool | null = this.pool;
    if (pool === null) {
      return;
    }
    const bank: SoundBank | undefined = this.banks.get(role);
    if (bank === undefined || bank.soundIds.length === 0) {
      return;
    }
    let index: number = bank.cursor;
    if (index >= bank.soundIds.length) {
      index = 0;
    }
    bank.cursor = (index + 1) % bank.soundIds.length;
    this.emit(pool, bank.soundIds[index], this.pitchAccepted, role);
  }

  /** 快速连打用的短音（key-transient.ogg，0.117s）；缺该 stem 时退回主键音。 */
  playKeyTransient(): void {
    if (!this.ready || !this.soundEnabled) {
      return;
    }
    const pool: media.SoundPool | null = this.pool;
    if (pool === null) {
      return;
    }
    const sid: number | undefined = this.stemIds.get('key-transient');
    if (sid === undefined || sid <= 0) {
      this.playByRole(SoundRole.KEY);
      return;
    }
    this.emit(pool, sid, this.pitchAccepted, SoundRole.KEY);
  }

  /** 单次触感反馈 15~30ms；系统触感开关关闭 / 无马达 / 权限被拒均静默。 */
  vibrate(): void {
    if (!this.vibrationEnabled) {
      return;
    }
    const effect: vibrator.VibrateTime = { type: 'time', duration: VIBRATE_DURATION_MS };
    const attribute: vibrator.VibrateAttribute = { id: VIBRATE_ID, usage: VIBRATE_USAGE };
    try {
      vibrator.startVibration(effect, attribute).then(() => {
        // 已触发，无后续动作；绝不在 Down 回调里等它，避免给播音叠加延迟。
      }).catch((err: BusinessError) => {
        logWarn('vibrate rejected: ' + err.message);
      });
    } catch (err) {
      logWarn('vibrate threw synchronously');
    }
  }

  setVolume(volume: number): void {
    if (volume < MIN_VOLUME) {
      this.volume = MIN_VOLUME;
      return;
    }
    if (volume > MAX_VOLUME) {
      this.volume = MAX_VOLUME;
      return;
    }
    this.volume = volume;
  }

  setSoundEnabled(enabled: boolean): void {
    this.soundEnabled = enabled;
  }

  setVibrationEnabled(enabled: boolean): void {
    this.vibrationEnabled = enabled;
  }

  /** 页面退出时释放 SoundPool 与资源；之后可再次 preload。 */
  release(): void {
    this.teardown();
    logInfo('released');
  }

  // ------------------------------------------------------------------
  // 内部实现
  // ------------------------------------------------------------------

  /** 真正发声：play 是 Promise，但这里只挂 then/catch，绝不同步等待。 */
  private emit(pool: media.SoundPool, soundId: number, withPitch: boolean, role: SoundRole): void {
    // 第 0 批：测试构建音效观测（发布构建 TestHooks=false，emitTrace 第一行即返回，零成本）
    const stemName: string | undefined = this.idToStem.get(soundId);
    AudioTrace.emitTrace(role.toString(), stemName === undefined ? '' : stemName, this.volume, 1, this.packName);
    this.trimStreams(pool, role);
    let params: media.PlayParameters;
    if (withPitch) {
      params = {
        loop: 0,
        rate: audio.AudioRendererRate.RENDER_RATE_NORMAL,
        leftVolume: this.volume,
        rightVolume: this.volume,
        pitch: PITCH_MIN + Math.random() * (PITCH_MAX - PITCH_MIN),
      };
    } else {
      params = {
        loop: 0,
        rate: audio.AudioRendererRate.RENDER_RATE_NORMAL,
        leftVolume: this.volume,
        rightVolume: this.volume,
      };
    }
    try {
      pool.play(soundId, params).then((streamId: number) => {
        // 回收 streamId 并记并发（§2.9 第 2 项）
        this.streams.push(streamId);
        this.streamRole.set(streamId, role);
        this.streamAt.set(streamId, Date.now());
        if (this.streams.length > this.peakConcurrent) {
          this.peakConcurrent = this.streams.length;
        }
      }).catch((err: BusinessError) => {
        this.refusedCount += 1;
        this.onPlayRejected(pool, soundId, err, role);
      });
    } catch (err) {
      logWarn('play threw synchronously');
    }
  }

  /**
   * 流控（§2.9 第 2 项）：先按 2s 老化剪枝，再按角色上限停最旧；
   * 同角色达上限先停该角色最旧流；总流达 12 时先停最旧主键流，绝不先停铃/复位。
   * stop 是异步，只挂 catch，不同步等待。
   */
  private trimStreams(pool: media.SoundPool, role: SoundRole): void {
    const now: number = Date.now();
    const kept: number[] = [];
    for (const sid of this.streams) {
      const at: number = this.streamAt.get(sid) ?? 0;
      if (now - at > 2000) {
        this.streamRole.delete(sid);
        this.streamAt.delete(sid);
      } else {
        kept.push(sid);
      }
    }
    this.streams = kept;

    // 同角色上限：停该角色最旧
    const cap: number = this.capFor(role);
    let count: number = 0;
    for (const sid of this.streams) {
      if (this.streamRole.get(sid) === role) {
        count += 1;
      }
    }
    while (count >= cap && this.streams.length > 0) {
      let victim: number = -1;
      for (const sid of this.streams) {
        if (this.streamRole.get(sid) === role) {
          victim = sid;
          break;
        }
      }
      if (victim < 0) {
        break;
      }
      this.stopAndForget(pool, victim);
      count -= 1;
    }

    // 总流上限 12：先停最旧主键；没有主键才停最旧的非受保护流
    while (this.streams.length >= 12) {
      let victim: number = -1;
      for (const sid of this.streams) {
        if (this.streamRole.get(sid) === SoundRole.KEY) {
          victim = sid;
          break;
        }
      }
      if (victim < 0) {
        for (const sid of this.streams) {
          const r: SoundRole | undefined = this.streamRole.get(sid);
          if (r !== undefined && !this.isProtected(r)) {
            victim = sid;
            break;
          }
        }
      }
      if (victim < 0) {
        break;
      }
      this.stopAndForget(pool, victim);
    }
  }

  private stopAndForget(pool: media.SoundPool, streamId: number): void {
    const idx: number = this.streams.indexOf(streamId);
    if (idx >= 0) {
      this.streams.splice(idx, 1);
    }
    this.streamRole.delete(streamId);
    this.streamAt.delete(streamId);
    try {
      pool.stop(streamId).catch(() => {
        // 流已自然结束：忽略
      });
    } catch (err) {
      // 忽略
    }
  }

  /**
   * 播放被拒的降级路径：401 参数错误通常是运行时不认 pitch，
   * 关掉 pitch 用默认音高重播一次，避免因为一个可选参数让整套音静音。
   */
  private onPlayRejected(pool: media.SoundPool, soundId: number, err: BusinessError, role: SoundRole): void {
    if (this.pitchAccepted && err.code === PARAM_ERROR_CODE) {
      this.pitchAccepted = false;
      this.refusedCount -= 1; // 参数降级重播不算拒播
      logWarn('play rejected with 401, retry without pitch');
      this.emit(pool, soundId, false, role);
      return;
    }
    logWarn('play rejected: ' + err.message);
  }

  /** 'pack' → 'sound/pack'；已经带 '/' 的相对路径则原样使用。 */
  private packPathOf(packName: string): string {
    if (packName.indexOf('/') >= 0) {
      return packName;
    }
    return SOUND_ROOT + '/' + packName;
  }

  /**
   * 拿 resourceManager：**只认显式注入**。
   *
   * 不再退回全局 getContext()：该 API 自 API 18 起废弃（API 26 编译告警），
   * 且组件外调用依赖不确定的全局态。页面必须在 preload() 之前调 attachContext()。
   * 类型依据：application/Context.d.ts:46 resourceManager 属性。
   */
  private resolveResourceManager(): resourceManager.ResourceManager | null {
    const injected: resourceManager.ResourceManager | null = this.resourceMgr;
    if (injected !== null) {
      return injected;
    }
    logWarn('resourceManager not attached; call attachContext() before preload()');
    return null;
  }

  /** 列包内 .ogg（运行时以真实目录为准）；列举不可用时退回兜底文件名表。 */
  private listStems(rm: resourceManager.ResourceManager, path: string, packName: string): string[] {
    let names: string[] = [];
    try {
      names = rm.getRawFileListSync(path);
    } catch (err) {
      names = [];
    }
    const stems: string[] = [];
    for (const name of names) {
      if (!this.endsWithOgg(name)) {
        continue;
      }
      // 列举 API 若返回带子目录前缀的名字，只取末段文件名，拼路径时才不会重复前缀。
      const plain: string = this.plainName(name);
      stems.push(plain.substring(0, plain.length - OGG_SUFFIX.length));
    }
    if (stems.length === 0) {
      logWarn('getRawFileListSync empty for ' + path + ', fallback to known file names');
      for (const stem of this.fallbackStems(packName)) {
        stems.push(stem);
      }
    }
    stems.sort();
    return stems;
  }

  private endsWithOgg(name: string): boolean {
    return name.lastIndexOf(OGG_SUFFIX) === name.length - OGG_SUFFIX.length;
  }

  private plainName(name: string): string {
    const slash: number = name.lastIndexOf('/');
    return slash >= 0 ? name.substring(slash + 1) : name;
  }

  private fallbackStems(packName: string): string[] {
    const stems: string[] = [];
    if (packName === DEFAULT_PACK_NAME) {
      for (let i: number = 1; i <= KEY_VARIANT_COUNT; i++) {
        stems.push('key-' + pad2(i));
      }
    } else {
      // 第 4 批 F8：每包文件无前缀（key-01…），不再拼 '<pack>-key-01'
      for (let i: number = 1; i <= KEY_VARIANT_COUNT; i++) {
        stems.push('key-' + pad2(i));
      }
    }
    for (const shared of FALLBACK_SHARED_STEMS) {
      stems.push(shared);
    }
    return stems;
  }

  /** 载入单个音：任何失败都只返回 -1（静默），不抛也不影响其他音。 */
  private async loadOne(rm: resourceManager.ResourceManager, path: string, stem: string): Promise<number> {
    const pool: media.SoundPool | null = this.pool;
    if (pool === null) {
      return -1;
    }
    const relPath: string = path + '/' + stem + OGG_SUFFIX;
    const fd: resourceManager.RawFileDescriptor | null = this.rawFdOf(rm, relPath);
    if (fd === null) {
      return -1;
    }
    let soundId: number = -1;
    try {
      soundId = await pool.load(fd.fd, fd.offset, fd.length);
    } catch (err) {
      soundId = -1;
    }
    try {
      rm.closeRawFdSync(relPath);
    } catch (err) {
      logWarn('closeRawFdSync failed for ' + relPath);
    }
    return soundId;
  }

  private rawFdOf(rm: resourceManager.ResourceManager, relPath: string): resourceManager.RawFileDescriptor | null {
    try {
      return rm.getRawFdSync(relPath);
    } catch (err) {
      return null;
    }
  }

  /** 把已加载的音按角色分池；不属于本包主键前缀的变体（如 pack2-*）预载但不入池。 */
  private buildBanks(packName: string): void {
    const keys: number[] = [];
    const spaces: number[] = [];
    const bells: number[] = [];
    const resets: number[] = [];
    const alts: number[] = [];
    for (const stem of this.loadedStems) {
      const soundId: number = this.soundIdOf(stem);
      if (soundId <= 0) {
        continue;
      }
      if (stem.indexOf('transient') >= 0) {
        continue;
      }
      if (stem.indexOf('bell') >= 0) {
        bells.push(soundId);
        continue;
      }
      if (stem.indexOf('space') >= 0) {
        spaces.push(soundId);
        continue;
      }
      if (stem.indexOf('carriage') >= 0 || stem.indexOf('reset') >= 0) {
        resets.push(soundId);
        continue;
      }
      if (stem.indexOf('alt') >= 0) {
        alts.push(soundId);
        continue;
      }
      if (this.isKeyVariantOfPack(stem, packName)) {
        keys.push(soundId);
      }
    }
    if (alts.length === 0) {
      const fallbackId: number = this.soundIdOf(BACKSPACE_FALLBACK_STEM);
      if (fallbackId > 0) {
        alts.push(fallbackId);
      } else {
        for (const id of keys) {
          alts.push(id);
        }
      }
    }
    this.banks.set(SoundRole.KEY, this.newBank(keys));
    this.banks.set(SoundRole.SPACE, this.newBank(spaces));
    this.banks.set(SoundRole.BELL, this.newBank(bells));
    this.banks.set(SoundRole.CARRIAGE_RESET, this.newBank(resets));
    this.banks.set(SoundRole.BACKSPACE, this.newBank(alts));
  }

  /**
   * 是否属于本包的主键变体：
   * 'key-01'（无前缀）算本包；'pack2-key-01' 这类带 '<前缀>-key-' 的只算前缀为 packName 的那个包。
   */
  private isKeyVariantOfPack(stem: string, packName: string): boolean {
    const at: number = stem.indexOf('-key-');
    if (at > 0) {
      return stem.substring(0, at) === packName;
    }
    return stem.indexOf('key-') === 0;
  }

  private soundIdOf(stem: string): number {
    const id: number | undefined = this.stemIds.get(stem);
    return id === undefined ? -1 : id;
  }

  private newBank(soundIds: number[]): SoundBank {
    return { soundIds: soundIds, cursor: 0 };
  }

  private hasAnySound(): boolean {
    let hasSound: boolean = false;
    this.banks.forEach((bank: SoundBank) => {
      if (bank.soundIds.length > 0) {
        hasSound = true;
      }
    });
    return hasSound;
  }

  /** 释放 SoundPool 与全部加载结果；重复调用安全。 */
  private teardown(): void {
    const pool: media.SoundPool | null = this.pool;
    this.pool = null;
    this.ready = false;
    this.loadedStems = [];
    this.stemIds = new Map<string, number>();
    this.idToStem = new Map<number, string>();
    this.banks = new Map<SoundRole, SoundBank>();
    this.packPath = '';
    this.pitchAccepted = true;
    if (pool === null) {
      return;
    }
    try {
      pool.release().then(() => {
        // 已交给系统回收，无后续动作。
      }).catch((err: BusinessError) => {
        logWarn('release rejected: ' + err.message);
      });
    } catch (err) {
      logWarn('release threw synchronously');
    }
  }
}

/** 全局单例：页面直接 import { audioService } 使用；多实例会各自占一份 SoundPool，不建议。 */
export const audioService: AudioService = new AudioService();
