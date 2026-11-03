/**
 * 回车 · 自绘 QWERTY 机械键盘（阶段1 实现）
 *
 * 契约：entry/src/main/ets/ui/KeyboardPanel.ets（KeyAction / KeyCommit / KeyboardCallbacks /
 * KeyboardViewSpec）——字段名与路径按契约，不改。主屏用法：
 *   KeyboardPanel({ spec: this.keyboardSpec, callbacks: this.keyboardCallbacks })
 *   .width('100%').height(this.keyboardSpec.heightVp)
 *
 * 硬性做法（调研报告 §1 + 风格板 §5 + 任务卡 11 点）：
 * 1. 容器级 onTouch + 坐标到键位映射：只有根 Stack 挂 onTouch，键帽子组件不挂；
 * 2. 不用 onClick：onClick 单点、抬手才触发，拿不到按下当刻，也做不了多指同按；
 * 3. 多点触控走 TouchRouter 的 Map<触点 id, 键 id>：touches 不保证按 id 排序，一律按 id 查表；
 *    Up / Cancel 必须清理该 id（系统会复用 id）；
 * 4. 按下 animateTo + curves.springCurve(0, 1, 200, 18)、缩放 0.92；
 *    松开 animateTo + curves.springMotion()；不用 keyframeAnimateTo（不支持弹簧曲线）；
 * 5. 动画只动 transform（scale / translate）与透明度：按下瞬间不改宽高、字号、padding、布局；
 *    每个键一个 @Observed 状态对象 + 子组件 @ObjectLink，敲一个键只刷新该键的组件；
 * 6. 声音在 TouchType.Down 当刻回调 onKeyDown，不等 Up；Up 只做视觉回弹并回调 onKeyUp；
 * 7. 键位：顶栏功能位 + 数字行 + QWERTY 三行 + Shift + 空格，共 41 键（固定数量，不用 LazyForEach）；
 * 8. Shift 锁定态由本组件维护：按一次锁定、再按解除，锁定态提交大写字母 / 上档符号；
 * 9. 顶栏一行功能位：中 / EN 切换（KeyAction.SWITCH_LANGUAGE，阶段1 只回调）+ 退格 + 回车；
 * 10. 视觉：键帽浮雕（底色 + 暗边 + 顶面高光条）与短而实的下沉阴影；键帽底色走
 *     KeyboardViewSpec.keycapColor；键帽字符由代码文本层绘制，绝不 baked 进图片；
 * 11. 行末预告铃的 8 字阈值由主屏 / 文档模型判定：本组件不计算阈值、不主动响铃，
 *     只按契约暴露 KeyboardCallbacks.onBell 供调用方触发。
 */

import { curves } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { KeyAction, KeyCommit, KeyboardCallbacks, KeyboardViewSpec } from '../ui/KeyboardPanel';
import { KeycapTable, KEYCAP_RAWFILE, parseKeycapTable } from './keyboard/Keycaps';
import { KeycapPalette, deriveKeycapPalette, NEUTRAL_KEYCAP_PALETTE } from './keyboard/ColorUtil';
import { buildKeyLayout, hitTestKey, KEY_HIT_TOLERANCE_VP, KEY_ID_SHIFT, KeyDef } from './keyboard/KeyboardLayout';
import { TouchRouter } from './keyboard/TouchRouter';

const TAG: string = 'KeyboardPanel';
const HILOG_DOMAIN: number = 0x0000;

/** 按下缩放（风格板 §5：约 0.92，下沉干脆）。 */
const PRESS_SCALE: number = 0.92;
/** 按下弹簧：高刚度短弹簧，社区实践值 0 / 1 / 200 / 18（调研报告 §1）。 */
const PRESS_SPRING_VELOCITY: number = 0;
const PRESS_SPRING_MASS: number = 1;
const PRESS_SPRING_STIFFNESS: number = 200;
const PRESS_SPRING_DAMPING: number = 18;
/** 按下持续时间（弹簧曲线下时长由弹簧参数主导，这里给一个与手感匹配的值）。 */
const PRESS_DURATION_MS: number = 200;
/** 回弹持续时间（springMotion 低刚度，带一次微震荡）。 */
const RELEASE_DURATION_MS: number = 320;
/** 尺寸去抖阈值（vp）：小于它视为同一次尺寸，避免 onAreaChange / onSizeChange 反复重算。 */
const SIZE_EPSILON_VP: number = 0.5;

/** 键帽运行时状态：每个键一个实例。@Observed + @ObjectLink，改一个键只刷新该键的组件。 */
@Observed
class KeyRuntimeState {
  /** 手指是否按住（按下 / 回弹动画的唯一驱动）。 */
  pressed: boolean = false;
  /** 锁定态（目前只有 Shift 键用：真实打字机的字档锁定）。 */
  locked: boolean = false;
}

/** 父组件漏传 callbacks 时的兜底：不发声、不上屏、不崩。 */
class SilentCallbacks implements KeyboardCallbacks {
  onKeyDown(key: string, action: KeyAction): void {
    // 兜底实现：父组件未接线时不做事。
  }
  onKeyUp(key: string, action: KeyAction): void {
    // 兜底实现：父组件未接线时不做事。
  }
  onCommit(commit: KeyCommit): void {
    // 兜底实现：父组件未接线时不做事。
  }
  onBell(): void {
    // 兜底实现：父组件未接线时不做事。
  }
}

/** Length -> vp 数值；拿不到（undefined / Resource / 非法串）返回 -1。 */
function lengthToVp(value: Length | undefined): number {
  if (value === undefined) {
    return -1;
  }
  if (typeof value === 'number') {
    return value;
  }
  if (typeof value === 'string') {
    const trimmed: string = value.trim();
    const keep: number = trimmed.endsWith('vp') ? trimmed.length - 2 : trimmed.length;
    const parsed: number = parseFloat(trimmed.substring(0, keep));
    if (isNaN(parsed)) {
      return -1;
    }
    return parsed;
  }
  return -1;
}

/**
 * 单个键帽。
 *
 * 只读字段、不做方法调用：@Prop 的深拷贝会丢掉类原型（见官方 arkts-prop.md），
 * 因此渲染里所有派生值（圆角 / 字号 / 高光条几何 / 下沉量）都已在 KeyDef 里算好。
 */
@Component
struct KeyCap {
  /** 键位定义（结构 + 字符 + 几何 + 视觉派生值）。 */
  @Prop def: KeyDef;
  /** 键帽派生配色（换机时整体更新）。 */
  @Prop pal: KeycapPalette;
  /** Shift 锁定态：锁定后字符键显示 / 提交上档字符。 */
  @Prop shiftLocked: boolean;
  /** 该键运行时状态（按住 / 锁定）。@ObjectLink 不深拷贝，改属性只刷新本键。 */
  @ObjectLink state: KeyRuntimeState;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // (1) 键槽：短而实的下沉阴影；键帽压下去时被盖住，只改透明度
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.pal.well)
        .borderRadius(this.def.radius)
        .translate({ y: this.def.shadowDrop })
        .opacity(this.state.pressed ? 0.26 : 0.62)

      // (2) 键帽：底色 + 暗边 + 顶面高光条 = 浮雕感；按下只改 scale / translate
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.pal.cap)
          .borderRadius(this.def.radius)
          .border({ width: 1, color: this.pal.capEdge })

        Column()
          .width(this.def.hlW)
          .height(this.def.hlH)
          .backgroundColor(this.pal.capHighlight)
          .borderRadius(this.def.hlH / 2)
          .position({ x: this.def.hlX, y: this.def.hlY })
          .opacity(0.5)

        if (this.def.action === KeyAction.SHIFT) {
          // 锁定态：一层半透明暗色覆盖（只改透明度，不改布局）
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(this.pal.capEdge)
            .borderRadius(this.def.radius)
            .opacity(this.state.locked ? 0.55 : 0)
        }

        // (3) 字符层：代码文本层矢量绘制（不 baked 进图片）
        //     字母 / 数字 / 上档符号来自 keycaps.json；功能键标签走 string.json 资源键
        if (this.def.action === KeyAction.INSERT) {
          Text(this.shiftLocked ? this.def.charShift : this.def.charBase)
            .fontSize(this.def.labelSize)
            .fontColor(this.pal.label)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
        } else if (this.def.action === KeyAction.SHIFT) {
          Text($r('app.string.keyboard_shift'))
            .fontSize(this.def.labelSize)
            .fontColor(this.pal.label)
            .maxLines(1)
        } else if (this.def.action === KeyAction.BACKSPACE) {
          Text($r('app.string.keyboard_backspace'))
            .fontSize(this.def.labelSize)
            .fontColor(this.pal.label)
            .maxLines(1)
        } else if (this.def.action === KeyAction.RETURN) {
          Text($r('app.string.keyboard_return'))
            .fontSize(this.def.labelSize)
            .fontColor(this.pal.label)
            .maxLines(1)
        } else if (this.def.action === KeyAction.SWITCH_LANGUAGE) {
          Column() {
            Text($r('app.string.keyboard_lang_zh'))
              .fontSize(this.def.labelSize)
              .fontColor(this.pal.label)
              .maxLines(1)
            Text($r('app.string.keyboard_lang_en'))
              .fontSize(this.def.labelSize)
              .fontColor(this.pal.label)
              .maxLines(1)
          }
        }
      }
      .width('100%')
      .height('100%')
      .scale({ x: this.state.pressed ? PRESS_SCALE : 1, y: this.state.pressed ? PRESS_SCALE : 1 })
      .translate({ y: this.state.pressed ? this.def.sink : 0 })
    }
    .width(this.def.w)
    .height(this.def.h)
    .position({ x: this.def.x, y: this.def.y })
    .opacity(this.def.visible ? 1 : 0)
  }
}

/**
 * 键盘面板。主屏只换 KeyboardViewSpec（换机 / 三态），不重建组件实例。
 */
@Component
export struct KeyboardPanel {
  /** 显示参数：键帽底色 / 键盘区总高 / 是否显示中英切换键。由主屏算出后传入。 */
  @Prop @Watch('onSpecChanged') spec: KeyboardViewSpec;
  /** 对外回调。普通成员：构造时一次性传入（函数对象不做状态序列化）。 */
  callbacks: KeyboardCallbacks = new SilentCallbacks();

  /** 键位表（含几何）。尺寸变化时整体替换，键 id 稳定 → 子组件复用、只更新数值。 */
  @State private defs: KeyDef[] = [];
  /** 键帽派生配色。 */
  @State private pal: KeycapPalette = NEUTRAL_KEYCAP_PALETTE;
  /** Shift 锁定态：真实打字机行为，按一次锁定、再按解除。 */
  @State private shiftLocked: boolean = false;

  /** 每键运行时状态（结构固定，与几何解耦；@ObjectLink 目标）。 */
  private states: KeyRuntimeState[] = [];
  /** 键 id -> states 下标。 */
  private stateIndex: Map<string, number> = new Map<string, number>();
  /** 多点触控路由：触点 id -> 键 id。 */
  private router: TouchRouter = new TouchRouter();
  /** 键帽字符表（rawfile 读一次，常驻）。 */
  private table: KeycapTable = new KeycapTable();
  /** 当前布局里语言键是否编入结构（跟随 spec.showLanguageKey）。 */
  private langKeyIncluded: boolean = true;
  /** 已应用的容器尺寸（vp），与回调去重。 */
  private appliedWidthVp: number = -1;
  private appliedHeightVp: number = -1;

  aboutToAppear(): void {
    this.pal = deriveKeycapPalette(this.spec.keycapColor);
    this.langKeyIncluded = this.spec.showLanguageKey;
    this.table = this.loadKeycaps();
    this.buildRuntimeStates();
  }

  /** spec 变化（换机 / 三态切换）：只换显示参数，不重建组件实例。 */
  onSpecChanged(): void {
    this.pal = deriveKeycapPalette(this.spec.keycapColor);
    if (this.spec.showLanguageKey !== this.langKeyIncluded) {
      this.langKeyIncluded = this.spec.showLanguageKey;
      this.applySize(this.appliedWidthVp, this.appliedHeightVp, true);
    }
  }

  /** 读 rawfile/keyboard/keycaps.json 并解析；任何失败都降级为空表并记日志，不崩。 */
  private loadKeycaps(): KeycapTable {
    const host = this.getUIContext().getHostContext();
    if (host === undefined) {
      hilog.error(HILOG_DOMAIN, TAG, 'host context unavailable, keycap table empty');
      return new KeycapTable();
    }
    let text: string = '';
    try {
      const bytes: Uint8Array = host.resourceManager.getRawFileContentSync(KEYCAP_RAWFILE);
      text = util.TextDecoder.create('utf-8', { ignoreBOM: true }).decodeToString(bytes);
    } catch (e) {
      hilog.error(HILOG_DOMAIN, TAG, 'read rawfile failed: %{public}s', KEYCAP_RAWFILE);
      return new KeycapTable();
    }
    const table: KeycapTable = parseKeycapTable(text);
    if (table.isEmpty()) {
      hilog.error(HILOG_DOMAIN, TAG, 'keycap table empty, check rawfile: %{public}s', KEYCAP_RAWFILE);
    }
    return table;
  }

  /** 建每键运行时状态。键位结构固定（41 键），只在构造期建一次。 */
  private buildRuntimeStates(): void {
    const structural: KeyDef[] = buildKeyLayout(0, 0, this.table, this.langKeyIncluded);
    const states: KeyRuntimeState[] = [];
    const index: Map<string, number> = new Map<string, number>();
    for (let i = 0; i < structural.length; i++) {
      states.push(new KeyRuntimeState());
      index.set(structural[i].id, i);
    }
    this.states = states;
    this.stateIndex = index;
  }

  /** 容器尺寸变化：重算键位几何。绘制与命中测试共用这份矩形。 */
  private applySize(widthVp: number, heightVp: number, force: boolean): void {
    if (widthVp <= 0 || heightVp <= 0) {
      return;
    }
    const sameWidth: boolean = Math.abs(widthVp - this.appliedWidthVp) < SIZE_EPSILON_VP;
    const sameHeight: boolean = Math.abs(heightVp - this.appliedHeightVp) < SIZE_EPSILON_VP;
    if (!force && sameWidth && sameHeight) {
      return;
    }
    this.appliedWidthVp = widthVp;
    this.appliedHeightVp = heightVp;
    this.defs = buildKeyLayout(widthVp, heightVp, this.table, this.langKeyIncluded);
  }

  private onAreaChanged(oldValue: Area, newValue: Area): void {
    this.applySize(lengthToVp(newValue.width), lengthToVp(newValue.height), false);
  }

  private onSizeChanged(oldValue: SizeOptions, newValue: SizeOptions): void {
    this.applySize(lengthToVp(newValue.width), lengthToVp(newValue.height), false);
  }

  /** 按下弹簧：高刚度短弹簧。 */
  private pressParam(): AnimateParam {
    const param: AnimateParam = {
      duration: PRESS_DURATION_MS,
      curve: curves.springCurve(PRESS_SPRING_VELOCITY, PRESS_SPRING_MASS, PRESS_SPRING_STIFFNESS, PRESS_SPRING_DAMPING),
    };
    return param;
  }

  /** 回弹弹簧：springMotion，带一次微震荡的 Q 弹回弹。 */
  private releaseParam(): AnimateParam {
    const param: AnimateParam = {
      duration: RELEASE_DURATION_MS,
      curve: curves.springMotion(),
    };
    return param;
  }

  /**
   * 容器级触摸分发。逐条对照调研报告 §1：
   * - 按 changedTouches 走，不看 touches 顺序（顺序不保证，id 才是身份）；
   * - Down：命中 -> 登记 -> 按下动画 -> 声音回调 -> 上屏；
   * - Move：滑出松键、滑入只做按下反馈不上屏（避免手指滑动误落字）；
   * - Up：清理该触点 id 并回弹（id 会被系统复用，必须清理）；
   * - Cancel：清空整张表并逐个回弹。
   */
  private handleTouch(event: TouchEvent): void {
    const changed: TouchObject[] = event.changedTouches;
    if (event.type === TouchType.Down) {
      for (let i = 0; i < changed.length; i++) {
        const touch: TouchObject = changed[i];
        const keyId: string = hitTestKey(this.defs, touch.x, touch.y, KEY_HIT_TOLERANCE_VP);
        if (keyId.length === 0) {
          continue;
        }
        if (!this.router.press(touch.id, keyId)) {
          continue;
        }
        this.pressKey(keyId);
      }
      return;
    }
    if (event.type === TouchType.Move) {
      for (let i = 0; i < changed.length; i++) {
        const touch: TouchObject = changed[i];
        const keyId: string = hitTestKey(this.defs, touch.x, touch.y, KEY_HIT_TOLERANCE_VP);
        const held: string = this.router.keyOf(touch.id);
        if (held === keyId) {
          continue;
        }
        if (held.length > 0) {
          this.router.release(touch.id);
          this.releaseKey(held);
        }
        if (keyId.length > 0 && this.router.press(touch.id, keyId)) {
          this.slideKey(keyId);
        }
      }
      return;
    }
    if (event.type === TouchType.Up) {
      for (let i = 0; i < changed.length; i++) {
        const released: string = this.router.release(changed[i].id);
        if (released.length > 0) {
          this.releaseKey(released);
        }
      }
      return;
    }
    const all: string[] = this.router.releaseAll();
    for (let i = 0; i < all.length; i++) {
      this.releaseKey(all[i]);
    }
  }

  /** Down 当刻：先动画，再声音回调，最后上屏（三者同步触发，都不 await）。 */
  private pressKey(keyId: string): void {
    const def: KeyDef | undefined = this.defOf(keyId);
    if (def === undefined) {
      return;
    }
    this.animatePressed(keyId, true);
    this.callbacks.onKeyDown(keyId, def.action);
    this.applyAction(def);
  }

  /** 抬手：只做视觉回弹并回调 onKeyUp，不播音。 */
  private releaseKey(keyId: string): void {
    const def: KeyDef | undefined = this.defOf(keyId);
    if (def === undefined) {
      return;
    }
    this.animatePressed(keyId, false);
    this.callbacks.onKeyUp(keyId, def.action);
  }

  /** Move 滑入：只按下（视觉 + 声音回调），不上屏——手指滑动换键不该落字。 */
  private slideKey(keyId: string): void {
    const def: KeyDef | undefined = this.defOf(keyId);
    if (def === undefined) {
      return;
    }
    this.animatePressed(keyId, true);
    this.callbacks.onKeyDown(keyId, def.action);
  }

  /** 按下 / 回弹动画：只改 scale 与 translate（transform），不动宽高、字号、布局。 */
  private animatePressed(keyId: string, pressed: boolean): void {
    const state: KeyRuntimeState | undefined = this.stateOf(keyId);
    if (state === undefined) {
      return;
    }
    // 用 UIContext.animateTo（全局 animateTo 自 API 18 起废弃，见 UIContext.d.ts:4703）
    const ui = this.getUIContext();
    if (pressed) {
      ui.animateTo(this.pressParam(), () => {
        state.pressed = true;
      });
    } else {
      ui.animateTo(this.releaseParam(), () => {
        state.pressed = false;
      });
    }
  }

  /** 键帽语义：Shift 切档（锁定态由本组件维护），其余把字符交给文档模型。 */
  private applyAction(def: KeyDef): void {
    if (def.action === KeyAction.SHIFT) {
      this.shiftLocked = !this.shiftLocked;
      const shiftState: KeyRuntimeState | undefined = this.stateOf(KEY_ID_SHIFT);
      if (shiftState !== undefined) {
        shiftState.locked = this.shiftLocked;
      }
    }
    const commit: KeyCommit = { ch: this.commitCharOf(def), action: def.action };
    this.callbacks.onCommit(commit);
  }

  /** 本次提交的字符：字符键按 Shift 锁定态取上档字符，空格取空格符，功能键为空串。 */
  private commitCharOf(def: KeyDef): string {
    if (def.action === KeyAction.INSERT) {
      return this.shiftLocked ? def.charShift : def.charBase;
    }
    if (def.action === KeyAction.SPACE) {
      return def.charBase;
    }
    return '';
  }

  /** 键 id -> 键位定义（结构与 states 同序，见 buildRuntimeStates）。 */
  private defOf(keyId: string): KeyDef | undefined {
    const index: number | undefined = this.stateIndex.get(keyId);
    if (index === undefined || index >= this.defs.length) {
      return undefined;
    }
    return this.defs[index];
  }

  /** 键 id -> 运行时状态。 */
  private stateOf(keyId: string): KeyRuntimeState | undefined {
    const index: number | undefined = this.stateIndex.get(keyId);
    if (index === undefined || index >= this.states.length) {
      return undefined;
    }
    return this.states[index];
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 键盘底板（机架）：键帽嵌在它上面
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.pal.deck)

      // 机架上沿亮边：只画一层窄条，不做常驻装饰阴影
      Row()
        .width('100%')
        .height(2)
        .backgroundColor(this.pal.capEdge)
        .opacity(0.35)

      // 键位：位置来自布局算出的矩形，本组件与命中测试共用同一份数据
      ForEach(this.defs, (def: KeyDef, index: number) => {
        KeyCap({
          def: def,
          pal: this.pal,
          shiftLocked: this.shiftLocked,
          state: this.states[index]
        })
      }, (def: KeyDef) => def.id)
    }
    .width('100%')
    .height('100%')
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.onAreaChanged(oldValue, newValue);
    })
    .onSizeChange((oldValue: SizeOptions, newValue: SizeOptions) => {
      this.onSizeChanged(oldValue, newValue);
    })
    .onTouch((event: TouchEvent) => {
      this.handleTouch(event);
    })
  }
}
