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
  /** 中文输入引擎：'builtin'（默认，内置拼音）| 'system'（系统输入法通道）。 */
  static readonly CN_ENGINE: string = 'cn_engine';
  /** 选词学习记录 JSON：{拼音串: {词: 次数}}。 */
  static readonly CN_LEARN: string = 'cn_learn';
  /** 我的词库 JSON：{拼音串: [词]}。 */
  static readonly CN_USERWORDS: string = 'cn_userwords';
  /** 模糊拼音开关（默认关）。 */
  static readonly CN_FUZZY: string = 'cn_fuzzy';
  /** 字符级 bigram（用户本机语料，只存本地）。 */
  static readonly CN_BIGRAM: string = 'cn_bigram';
  /** §10：机型是全局偏好（文档不再记住自己的机型） */
  static readonly MACHINE: string = 'machine';

  // ---- 第 0 批：命名空间与登记规则（新键一律走前缀；不许各组件裸写字符串）----
  /** 引导：`guide.<page>.seen`；首次启动引导复用既有 ONBOARDING_SEEN 键。 */
  static readonly GUIDE_PREFIX: string = 'guide.';
  /** 第 1 批：引导产品开关（默认 on）与测试模式（仅测试构建可置 true）。 */
  static readonly GUIDE_ENABLED: string = 'guide.enabled';
  static readonly GUIDE_TEST_MODE: string = 'guide.testMode';
  /** 自定义：`custom.font.<machine>.<field>`／`custom.paper.<paperKind>.<field>`。 */
  static readonly CUSTOM_FONT_PREFIX: string = 'custom.font.';
  static readonly CUSTOM_PAPER_PREFIX: string = 'custom.paper.';
  /** 第 2 批 F3：自定义功能总开关（默认 off；静态验收后批末改 on，移除点＝第 7 批）。 */
  static readonly CUSTOM_ENABLED: string = 'custom.enabled';
  /** 第 2 批 F3：导入字体列表 JSON（familyName／path／size／status），冷启动重注册的数据源。 */
  static readonly CUSTOM_FONT_IMPORTED: string = 'custom.font.imported';
  /** 第 2 批 F3：纸张预设 JSON（`{名称: 预设}`）。 */
  static readonly CUSTOM_PAPER_PRESETS: string = 'custom.paper.presets';
  /** 第 2 批 F15：候选栏选项。 */
  static readonly CUSTOM_CANDIDATE_COUNT: string = 'custom.candidate.count';
  static readonly CUSTOM_CANDIDATE_SIZE: string = 'custom.candidate.size';
  /** 统计：事件计数与日计数器。 */
  static readonly STATS_PREFIX: string = 'stats.';
  static readonly STATS_DAY_KEY: string = 'stats.day.key';
  static readonly STATS_DAY_CHARS: string = 'stats.day.chars';
  static readonly STATS_DAILY_GOAL: string = 'stats.daily_goal';
  /** 用过的纸张种类集合（逗号分隔，第 4 批 F14）。 */
  static readonly STATS_PAPER_KINDS: string = 'stats.paper.kinds';
  static readonly STATS_EVENT_PREFIX: string = 'stats.event.';
  /** 成就：`achieve.<id>`。 */
  static readonly ACHIEVE_PREFIX: string = 'achieve.';

  /** 某页首次引导是否已看（页名用稳定英文 id，不用中文标题）。 */
  static guideSeen(page: string): string {
    return PrefKeys.GUIDE_PREFIX + page + '.seen';
  }

  /** 某台机的字体搭配键（field 例：family／size）。 */
  static customFont(machine: string, field: string): string {
    return PrefKeys.CUSTOM_FONT_PREFIX + machine + '.' + field;
  }

  /** 纸张自定义键（field 例：color／margin／texture）。 */
  static customPaper(field: string): string {
    return PrefKeys.CUSTOM_PAPER_PREFIX + field;
  }

  /** 某张纸的自定义键（第 2 批 M-3：`custom.paper.<paperKind>.<field>`；field 例：color／ruled／marginH／texture）。 */
  static customPaperOf(paperKind: string, field: string): string {
    return PrefKeys.CUSTOM_PAPER_PREFIX + paperKind + '.' + field;
  }

  /** 统计事件计数键。 */
  static statsEvent(event: string): string {
    return PrefKeys.STATS_EVENT_PREFIX + event;
  }

  /** 成就键（kind 例：machine_1950s）。 */
  static achieve(kind: string): string {
    return PrefKeys.ACHIEVE_PREFIX + kind;
  }
}

/** 一个 prefs 键的登记项（类型／默认值／归属／说明）。 */
export interface PrefKeySpec {
  key: string;
  type: string;
  defaultValue: string;
  owner: string;
  note: string;
}

/**
 * prefs 键登记表（第 0 批定，后面各批只增不改）。
 * 规则：新键必须在此登记；前缀键登记前缀本身，并由对应 key builder 生成具体键。
 */
export class PrefRegistry {
  static specs(): PrefKeySpec[] {
    return [
      { key: PrefKeys.ONBOARDING_SEEN, type: 'boolean', defaultValue: 'false', owner: 'F1', note: '首次启动引导 seen（复用旧键）' },
      { key: PrefKeys.SOUND_ENABLED, type: 'boolean', defaultValue: 'true', owner: 'F6', note: '音效开关' },
      { key: PrefKeys.VOLUME, type: 'number', defaultValue: '0.7', owner: 'F6', note: '音量 0..1（第 6 批接线；首次缺省 0.7）' },
      { key: PrefKeys.VIBRATION_ENABLED, type: 'boolean', defaultValue: 'true', owner: 'F6', note: '震动开关' },
      { key: PrefKeys.CN_ENGINE, type: 'string', defaultValue: 'builtin', owner: '既有', note: '中文引擎' },
      { key: PrefKeys.MACHINE, type: 'string', defaultValue: '1920s', owner: '既有', note: '默认机型' },
      { key: PrefKeys.GUIDE_PREFIX, type: 'boolean', defaultValue: 'false', owner: 'F1／F2', note: '每页首次引导：guide.<page>.seen' },
      { key: PrefKeys.GUIDE_ENABLED, type: 'boolean', defaultValue: 'true', owner: 'F1', note: '引导产品开关（移除点：第 7 批）' },
      { key: PrefKeys.GUIDE_TEST_MODE, type: 'boolean', defaultValue: 'false', owner: 'F1', note: '测试模式（仅测试构建可置 true）' },
      { key: PrefKeys.CUSTOM_FONT_PREFIX, type: 'string', defaultValue: '', owner: 'F3', note: '每机字体搭配：custom.font.<machine>.<field>' },
      { key: PrefKeys.CUSTOM_PAPER_PREFIX, type: 'string', defaultValue: '', owner: 'F3', note: '纸张自定义：custom.paper.<paperKind>.<field>' },
      { key: PrefKeys.CUSTOM_ENABLED, type: 'boolean', defaultValue: 'true', owner: 'F3', note: '自定义功能总开关（批末已开；移除点第 7 批）' },
      { key: PrefKeys.CUSTOM_FONT_IMPORTED, type: 'string', defaultValue: '', owner: 'F3', note: '导入字体列表 JSON（familyName／path／size／status）' },
      { key: PrefKeys.CUSTOM_PAPER_PRESETS, type: 'string', defaultValue: '{}', owner: 'F3', note: '纸张预设 JSON（{名称: 预设}）' },
      { key: PrefKeys.CUSTOM_CANDIDATE_COUNT, type: 'number', defaultValue: '9', owner: 'F15', note: '候选数量 5–15，默认 9' },
      { key: PrefKeys.CUSTOM_CANDIDATE_SIZE, type: 'number', defaultValue: '15', owner: 'F15', note: '候选字号 12–20，默认 15' },
      { key: PrefKeys.STATS_PREFIX, type: 'number', defaultValue: '0', owner: 'F11／F5', note: '统计计数器（事件计数／日字数）' },
      { key: PrefKeys.STATS_DAILY_GOAL, type: 'number', defaultValue: '500', owner: 'F11', note: '每日目标字数，缺省 500' },
      { key: PrefKeys.STATS_PAPER_KINDS, type: 'string', defaultValue: '', owner: 'F14', note: '用过的纸张种类集合（逗号）' },
      { key: PrefKeys.ACHIEVE_PREFIX, type: 'boolean', defaultValue: 'false', owner: 'F5', note: '成就解锁状态' },
    ];
  }

  /** key 是否已登记（固定键精确匹配；前缀键按前缀）。 */
  static isRegistered(key: string): boolean {
    const fixed: string[] = [
      PrefKeys.ONBOARDING_SEEN, PrefKeys.SOUND_ENABLED, PrefKeys.VOLUME,
      PrefKeys.VIBRATION_ENABLED, PrefKeys.CN_ENGINE, PrefKeys.CN_LEARN,
      PrefKeys.CN_USERWORDS, PrefKeys.CN_FUZZY, PrefKeys.CN_BIGRAM, PrefKeys.MACHINE,
      PrefKeys.STATS_DAY_KEY, PrefKeys.STATS_DAY_CHARS, PrefKeys.STATS_DAILY_GOAL,
      PrefKeys.GUIDE_ENABLED, PrefKeys.GUIDE_TEST_MODE,
      PrefKeys.CUSTOM_CANDIDATE_COUNT, PrefKeys.CUSTOM_CANDIDATE_SIZE,
      PrefKeys.STATS_PAPER_KINDS,
      PrefKeys.CUSTOM_ENABLED, PrefKeys.CUSTOM_FONT_IMPORTED, PrefKeys.CUSTOM_PAPER_PRESETS,
    ];
    if (fixed.indexOf(key) >= 0) {
      return true;
    }
    const prefixes: string[] = [
      PrefKeys.GUIDE_PREFIX, PrefKeys.CUSTOM_FONT_PREFIX, PrefKeys.CUSTOM_PAPER_PREFIX,
      PrefKeys.STATS_EVENT_PREFIX, PrefKeys.ACHIEVE_PREFIX,
    ];
    for (let i = 0; i < prefixes.length; i++) {
      if (key.indexOf(prefixes[i]) === 0 && key.length > prefixes[i].length) {
        return true;
      }
    }
    return false;
  }
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

  getString(key: string, fallback: string): string {
    if (this.store !== null) {
      try {
        return this.store.getSync(key, fallback) as string;
      } catch (e) {
        return fallback;
      }
    }
    const raw: string | undefined = this.memory.get(key);
    return raw === undefined ? fallback : raw;
  }

  setString(key: string, value: string): void {
    this.memory.set(key, value);
    if (this.store !== null) {
      try {
        this.store.putSync(key, value);
        this.store.flush();
      } catch (e) {
        // 落盘失败不阻断交互；内存值仍然生效
      }
    }
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
