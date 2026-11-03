/**
 * 回车 · 本地偏好（阶段1 只有"首次使用引导是否已看过"与音效/震动开关）。
 *
 * 全部落应用沙箱（@ohos.data.preferences），不联网、不上传、零遥测。
 * 键名集中在此，避免各组件各写一套字符串。
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME: string = 'carriagereturn_prefs';

/** 偏好键名。 */
export class PrefKeys {
  /** 首次使用引导是否已看过：true 后永久不再出现。 */
  static readonly ONBOARDING_SEEN: string = 'onboarding_seen';
  /** 音效开关。 */
  static readonly SOUND_ENABLED: string = 'sound_enabled';
  /** 音量 0..1。 */
  static readonly VOLUME: string = 'volume';
  /** 震动开关。 */
  static readonly VIBRATION_ENABLED: string = 'vibration_enabled';
}

/** 偏好读写门面。初始化失败时全部走内存默认值，不阻断主屏。 */
export class AppPreferences {
  private static instance: AppPreferences | null = null;
  private store: preferences.Preferences | null = null;
  private memory: Map<string, string> = new Map<string, string>();

  static getInstance(): AppPreferences {
    if (AppPreferences.instance === null) {
      AppPreferences.instance = new AppPreferences();
    }
    return AppPreferences.instance;
  }

  /** Ability 启动时调一次（context 就绪后）。 */
  init(context: common.UIAbilityContext): void {
    try {
      const options: preferences.Options = { name: STORE_NAME };
      this.store = preferences.getPreferencesSync(context, options);
    } catch (e) {
      this.store = null;
    }
  }

  getBool(key: string, fallback: boolean): boolean {
    if (this.store !== null) {
      try {
        return this.store.getSync(key, fallback) as boolean;
      } catch (e) {
        return fallback;
      }
    }
    const raw: string | undefined = this.memory.get(key);
    return raw === undefined ? fallback : raw === 'true';
  }

  setBool(key: string, value: boolean): void {
    this.memory.set(key, value ? 'true' : 'false');
    if (this.store !== null) {
      try {
        this.store.putSync(key, value);
        this.store.flush();
      } catch (e) {
        // 落盘失败不阻断交互；内存值仍然生效
      }
    }
  }

  getNumber(key: string, fallback: number): number {
    if (this.store !== null) {
      try {
        return this.store.getSync(key, fallback) as number;
      } catch (e) {
        return fallback;
      }
    }
    const raw: string | undefined = this.memory.get(key);
    return raw === undefined ? fallback : Number(raw);
  }

  setNumber(key: string, value: number): void {
    this.memory.set(key, String(value));
    if (this.store !== null) {
      try {
        this.store.putSync(key, value);
        this.store.flush();
      } catch (e) {
        // 同上
      }
    }
  }
}

export const appPreferences: AppPreferences = AppPreferences.getInstance();
