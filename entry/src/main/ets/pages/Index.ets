/**
 * 回车 · 主屏（阶段1：打字闭环）
 *
 * 首屏标准（产品定义稿 v3.3）：打开即一台美机加一张纸加一句引导，3 秒内能敲出第一声。
 * 结构：机器舞台（上）→ 纸面（中，List+LazyForEach+@Reusable）→ 自绘键盘（下）。
 *
 * 交互链路（全部在 TouchType.Down 当刻起跑，fire-and-forget）：
 *   键盘 onTouch Down → callbacks.onKeyDown → 播音 + 震动
 *                     → callbacks.onCommit → 文档模型落字 → 纸面增量刷新
 * 声音不等 Up；震动不 await；动画由键盘自己起，主屏不参与。
 */

import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { display, font } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { KeyAction, KeyCommit, KeyboardCallbacks, KeyboardViewSpec } from '../ui/KeyboardPanel';
import { PaperRow, PaperViewSpec } from '../ui/PaperSheet';
import { CursorPos, MachineKind, PaperKind } from '../model/DocModel';
import { DEFAULT_FONT, DEFAULT_MACHINE, DEFAULT_PAPER, findFont, findMachine, findPaper } from '../model/MachineCatalog';
import { DocModel } from '../model/DocModelCore';
import { docStore } from '../services/DocStore';
import { appPreferences, PrefKeys } from '../services/AppPreferences';
import { AudioService } from '../services/AudioService';
import { KeyboardPanel } from '../components/KeyboardPanel';
import { PaperSheet } from '../components/PaperSheet';
import { MachineStage } from '../components/MachineStage';

const TAG: string = 'MainScreen';
const DOMAIN: number = 0x0100;
/** 纸面一行可容纳的字符数估算基准：等宽字体 advance ≈ 0.6em。 */
const CHAR_WIDTH_RATIO: number = 0.6;
/** 编辑后自动落盘的防抖间隔（ms）。 */
const SAVE_DEBOUNCE_MS: number = 1200;

/**
 * KeyboardCallbacks 的类实现（ArkTS: arkts-no-untyped-obj-literals）。
 * 页面把四个行为以函数注入，本类只做转发。
 */
class MainKeyboardCallbacks implements KeyboardCallbacks {
  private onDown: (key: string, action: KeyAction) => void;
  private onUp: (key: string, action: KeyAction) => void;
  private onCommitFn: (commit: KeyCommit) => void;
  private onBellFn: () => void;

  constructor(
    onDown: (key: string, action: KeyAction) => void,
    onUp: (key: string, action: KeyAction) => void,
    onCommitFn: (commit: KeyCommit) => void,
    onBellFn: () => void,
  ) {
    this.onDown = onDown;
    this.onUp = onUp;
    this.onCommitFn = onCommitFn;
    this.onBellFn = onBellFn;
  }

  onKeyDown(key: string, action: KeyAction): void {
    this.onDown(key, action);
  }

  onKeyUp(key: string, action: KeyAction): void {
    this.onUp(key, action);
  }

  onCommit(commit: KeyCommit): void {
    this.onCommitFn(commit);
  }

  onBell(): void {
    this.onBellFn();
  }
}

@Entry
@Component
struct Index {
  /** 文档模型（不随布局重建；阶段3 三态切换也复用同一实例）。 */
  private docModel: DocModel = new DocModel();
  /** 音频引擎。 */
  private audioService: AudioService = new AudioService();
  private charsPerLine: number = 30;
  private saveTimer: number = -1;
  private documentId: string = '';
  private machineKind: MachineKind = DEFAULT_MACHINE;

  @State rows: PaperRow[] = [];
  @State activeLine: number = 0;
  @State hintText: string = '';
  @State showOnboarding: boolean = false;
  @State paperSpec: PaperViewSpec = {
    paperKind: DEFAULT_PAPER,
    paperTexture: 'paper/paper-letter.jpg',
    paperWidthVp: 360,
    fontSizeVp: 16,
    lineHeightRatio: 1.7,
    marginHVp: 28,
    marginVVp: 32,
    fontFamily: 'CourierPrime',
    hasGrid: false,
    hasHeader: true,
  };
  @State keyboardSpec: KeyboardViewSpec = {
    keycapColor: '#dbccb3',
    heightVp: 296,
    showLanguageKey: true,
  };
  @State stageHeightVp: number = 200;
  /** 机器主色（@State 便于换机时随状态刷新）。 */
  @State bodyColor: string = '#312b24';

  /** 键盘回调：用显式类实现（ArkTS 不允许拿对象字面量去实现带方法签名的接口）。 */
  private keyboardCallbacks: KeyboardCallbacks = new MainKeyboardCallbacks(
    (key: string, action: KeyAction): void => {
      this.handleKeyDown(key, action);
    },
    (key: string, action: KeyAction): void => {
      // 视觉回弹由键盘自己处理，主屏无需动作
    },
    (commit: KeyCommit): void => {
      this.handleCommit(commit);
    },
    (): void => {
      this.audioService.playBell();
    },
  );

  aboutToAppear(): void {
    // 音频引擎需要 resourceManager 读 rawfile：先注入宿主 Context 再 preload
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext !== undefined && hostContext !== null) {
      this.audioService.attachContext(hostContext as common.Context);
    }
    this.registerPaperFonts();
    this.measureLayout();
    this.applyMachine(DEFAULT_MACHINE);
    this.applyPaper(DEFAULT_PAPER);

    // 首次使用引导：只看一次，永久不再出现
    this.showOnboarding = !appPreferences.getBool(PrefKeys.ONBOARDING_SEEN, false);
    // 常驻引导：每张新纸一行，输入后消失
    this.hintText = this.resolveString($r('app.string.hint_new_paper'));
    this.syncRows();

    // 音效包预加载（失败不阻断主屏，回退静音）
    this.audioService.setVolume(appPreferences.getNumber(PrefKeys.VOLUME, 0.8));
    this.audioService.setSoundEnabled(appPreferences.getBool(PrefKeys.SOUND_ENABLED, true));
    this.audioService.setVibrationEnabled(appPreferences.getBool(PrefKeys.VIBRATION_ENABLED, true));
    const spec = findMachine(DEFAULT_MACHINE);
    this.audioService.preload(spec.soundPack);
  }

  aboutToDisappear(): void {
    this.flushSave();
    this.audioService.release();
  }

  onPageHide(): void {
    this.flushSave();
  }

  // ---------------- 交互 ----------------

  private handleKeyDown(key: string, action: KeyAction): void {
    // 声音必须在 TouchType.Down 当刻触发；顺序：动画（键盘内部）→ 播音 → 震动，全部 fire-and-forget
    if (action === KeyAction.SPACE) {
      this.audioService.playSpace();
    } else if (action === KeyAction.BACKSPACE) {
      this.audioService.playBackspace();
    } else if (action === KeyAction.RETURN) {
      this.audioService.playCarriageReset();
    } else if (action === KeyAction.SHIFT) {
      this.audioService.playKey();
      return;
    } else if (action === KeyAction.SWITCH_LANGUAGE) {
      this.audioService.playKey();
      return;
    } else {
      this.audioService.playKey();
    }
    this.audioService.vibrate();
  }

  private handleCommit(commit: KeyCommit): void {
    if (commit.action === KeyAction.INSERT) {
      this.applyInsert(commit.ch);
      return;
    }
    if (commit.action === KeyAction.SPACE) {
      this.applyInsert(' ');
      return;
    }
    if (commit.action === KeyAction.BACKSPACE) {
      this.applyBackspace();
      return;
    }
    if (commit.action === KeyAction.RETURN) {
      this.applyReturn();
      return;
    }
  }

  private applyInsert(ch: string): void {
    if (ch.length === 0) {
      return;
    }
    this.hintText = '';
    const outcome = this.docModel.insertText(ch, this.charsPerLine);
    if (outcome.marginBell) {
      // 行末约 8 字：预告铃（与按键音叠加，真实打字机行为）
      this.audioService.playBell();
    }
    this.syncRows();
    this.scheduleSave();
  }

  private applyBackspace(): void {
    const outcome = this.docModel.backspace();
    if (outcome.changed) {
      this.syncRows();
      this.scheduleSave();
    }
  }

  private applyReturn(): void {
    this.hintText = '';
    const outcome = this.docModel.newline();
    if (outcome.changed) {
      this.syncRows();
      this.scheduleSave();
    }
  }

  // ---------------- 视图状态 ----------------

  private syncRows(): void {
    const lines = this.docModel.getLines();
    const cursor: CursorPos = this.docModel.getCursor();
    const next: PaperRow[] = [];
    for (let i = 0; i < lines.length; i++) {
      const row: PaperRow = {
        line: i,
        text: lines[i].text,
        ribbon: lines[i].ribbon,
        active: i === cursor.line,
      };
      next.push(row);
    }
    this.rows = next;
    this.activeLine = cursor.line;
  }

  private applyMachine(kind: MachineKind): void {
    this.machineKind = kind;
    const spec = findMachine(kind);
    this.bodyColor = spec.bodyColor;
    this.keyboardSpec = {
      keycapColor: spec.keycapColor,
      heightVp: this.keyboardSpec.heightVp,
      showLanguageKey: true,
    };
    this.docModel.setMachine(kind);
  }

  private applyPaper(kind: PaperKind): void {
    const paper = findPaper(kind);
    const machine = findMachine(this.machineKind);
    this.paperSpec = {
      paperKind: kind,
      paperTexture: paper.textureRawfile,
      paperWidthVp: this.paperSpec.paperWidthVp,
      fontSizeVp: machine.fontScale,
      lineHeightRatio: machine.lineHeightRatio,
      marginHVp: paper.marginH,
      marginVVp: paper.marginV,
      fontFamily: findFont(DEFAULT_FONT).familyName,
      hasGrid: paper.hasGrid,
      hasHeader: paper.hasHeader,
    };
    this.docModel.setPaper(kind);
    this.recomputeCharsPerLine();
  }

  private recomputeCharsPerLine(): void {
    const usable: number = this.paperSpec.paperWidthVp - this.paperSpec.marginHVp * 2;
    const charWidth: number = this.paperSpec.fontSizeVp * CHAR_WIDTH_RATIO;
    const n: number = Math.floor(usable / charWidth);
    this.charsPerLine = n > 4 ? n : 4;
  }

  private measureLayout(): void {
    try {
      const d = display.getDefaultDisplaySync();
      const widthVp: number = this.getUIContext().px2vp(d.width);
      const heightVp: number = this.getUIContext().px2vp(d.height);
      this.paperSpec = {
        paperKind: this.paperSpec.paperKind,
        paperTexture: this.paperSpec.paperTexture,
        paperWidthVp: widthVp,
        fontSizeVp: this.paperSpec.fontSizeVp,
        lineHeightRatio: this.paperSpec.lineHeightRatio,
        marginHVp: this.paperSpec.marginHVp,
        marginVVp: this.paperSpec.marginVVp,
        fontFamily: this.paperSpec.fontFamily,
        hasGrid: this.paperSpec.hasGrid,
        hasHeader: this.paperSpec.hasHeader,
      };
      // 机器 26% / 键盘 38% / 其余给纸面；纸面永远是画面最亮处
      this.stageHeightVp = Math.round(heightVp * 0.26);
      this.keyboardSpec = {
        keycapColor: this.keyboardSpec.keycapColor,
        heightVp: Math.round(heightVp * 0.38),
        showLanguageKey: true,
      };
      this.recomputeCharsPerLine();
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'measureLayout failed: %{public}s', JSON.stringify(err));
    }
  }

  private registerPaperFonts(): void {
    try {
      font.registerFont({ familyName: 'CourierPrime', familySrc: $rawfile('font/CourierPrime-Regular.ttf') });
      font.registerFont({ familyName: 'SpecialElite', familySrc: $rawfile('font/SpecialElite-Regular.ttf') });
      font.registerFont({ familyName: 'NotoSerifSC', familySrc: $rawfile('font/NotoSerifSC-wght.ttf') });
      font.registerFont({ familyName: 'LXGWWenKai', familySrc: $rawfile('font/LXGWWenKai-Regular.ttf') });
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'registerFont failed: %{public}s', JSON.stringify(err));
    }
  }

  private resolveString(res: Resource): string {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx !== undefined && ctx !== null) {
        return ctx.resourceManager.getStringSync(res.id);
      }
    } catch (e) {
      // 资源缺失时降级为空串，绝不崩主屏
    }
    return '';
  }

  // ---------------- 落盘 ----------------

  private scheduleSave(): void {
    if (this.saveTimer !== -1) {
      clearTimeout(this.saveTimer);
    }
    this.saveTimer = setTimeout(() => {
      this.saveTimer = -1;
      this.flushSave();
    }, SAVE_DEBOUNCE_MS);
  }

  private flushSave(): void {
    if (!docStore.isReady() || this.docModel.isEmpty()) {
      return;
    }
    try {
      const fallback: string = this.resolveString($r('app.string.doc_untitled'));
      this.documentId = docStore.save(this.documentId, this.docModel.toDocData(), fallback);
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'save failed: %{public}s', JSON.stringify(err));
    }
  }

  // ---------------- UI ----------------

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        MachineStage({
          machineKind: this.machineKind,
          bodyColor: this.bodyColor,
          stageHeightVp: this.stageHeightVp,
        })

        PaperSheet({
          spec: this.paperSpec,
          rows: this.rows,
          hintText: this.hintText,
          activeLine: this.activeLine,
        })
          .layoutWeight(1)
          .margin({ top: -18 })

        KeyboardPanel({
          spec: this.keyboardSpec,
          callbacks: this.keyboardCallbacks,
        })
          .width('100%')
          .height(this.keyboardSpec.heightVp)
      }
      .width('100%')
      .height('100%')

      if (this.showOnboarding) {
        this.onboardingOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#af9d8b')
  }

  @Builder
  onboardingOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .opacity(0.45)

      Column({ space: 14 }) {
        Text(this.resolveString($r('app.string.onboarding_first_title')))
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .fontColor('#312b24')
          .fontFamily('CourierPrime')
        Text(this.resolveString($r('app.string.onboarding_first_body')))
          .fontSize(14)
          .fontColor('#574d43')
          .lineHeight(22)
        Button(this.resolveString($r('app.string.onboarding_first_start')))
          .fontSize(15)
          .fontColor('#eee4ce')
          .backgroundColor('#312b24')
          .height(44)
          .width('100%')
          .onClick(() => {
            this.showOnboarding = false;
            appPreferences.setBool(PrefKeys.ONBOARDING_SEEN, true);
          })
      }
      .width('84%')
      .padding(24)
      .backgroundColor('#eee4ce')
      .borderRadius(10)
      .shadow({ radius: 24, color: '#3315120e', offsetY: 8 })
    }
    .width('100%')
    .height('100%')
  }
}
