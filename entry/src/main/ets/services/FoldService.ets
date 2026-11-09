/**
 * 回车 · 折叠感知服务（第 5 批回批 F7，设计稿 v8 D2 定稿）。
 *
 * 单一状态源：订阅挂 EntryAbility.onCreate（一次），Ability onDestroy 全量 off；
 * Index 不保留 foldState 镜像，只注册 onFoldChange 回调、派生 layoutMode。
 *
 * 坐标帧：creaseRect 为显示屏 px（与窗口同向），left/top/width/height（display.d.ts Rect）。
 * FoldService 对外一律给 vp（经 UIContext.px2vp 换算；UIContext 由 Index aboutToAppear 注入）。
 *
 * 非折叠设备：isFoldable()==false → 恒 EXPAND，foldAngle=null、creaseRect=null、
 * creaseHorizontal=true（默认），不订阅角度事件，App 行为零变化。
 */

import { display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'FoldService';

export type FoldState = 'EXPAND' | 'HALF_FOLD' | 'FOLDED';

/** 折痕区（vp 单位，D1 口径：display px 经 px2vp 换算后）。 */
export interface CreaseRectVp {
  x: number;
  y: number;
  w: number;
  h: number;
}

/** 冷启动暂定态：HALF_FOLDED＋横折痕时按桌台暂定，等首个角度回调纠正。 */
export class FoldService {
  private static foldState: FoldState = 'EXPAND';
  private static foldAngle: number | null = null;
  private static creaseRect: CreaseRectVp | null = null;
  private static creaseHorizontal: boolean = true;
  private static isFoldableDev: boolean = false;
  private static angleKnown: boolean = true;
  private static prevAngleInRange: boolean = false;
  private static physStatus: number = -1;
  private static cb: ((s: FoldState) => void) | null = null;
  private static subscribed: boolean = false;
  private static pxToVp: number = 0;
  private static ready: boolean = false;

  static isReady(): boolean {
    return FoldService.ready;
  }

  static state(): FoldState {
    return FoldService.foldState;
  }

  static angle(): number | null {
    return FoldService.foldAngle;
  }

  static crease(): CreaseRectVp | null {
    return FoldService.creaseRect;
  }

  static isCreaseHorizontal(): boolean {
    return FoldService.creaseHorizontal;
  }

  static angleKnownNow(): boolean {
    return FoldService.angleKnown;
  }

  /** px→vp 换算系数＝UIContext.px2vp(1)（每 px 的 vp 数）；Index aboutToAppear 时注入。 */
  static setPxPerVp(r: number): void {
    if (r > 0) {
      FoldService.pxToVp = r;
    }
  }

  private static px2vp(px: number): number {
    return FoldService.pxToVp > 0 ? px * FoldService.pxToVp : px;
  }

  /**
   * 订阅入口（EntryAbility.onCreate 调一次）。同步读原始态＋折痕区，跑一次入场门（D2）。
   * HALF_FOLDED＋横折痕 → 暂定 HALF_FOLD，angleKnown=false，等首个角度回调纠正。
   */
  static subscribe(): void {
    if (FoldService.subscribed) {
      return;
    }
    try {
      FoldService.isFoldableDev = display.isFoldable();
    } catch (e) {
      FoldService.isFoldableDev = false;
    }
    if (!FoldService.isFoldableDev) {
      FoldService.foldState = 'EXPAND';
      FoldService.ready = true;
      hilog.info(DOMAIN, TAG, 'subscribe: not foldable, stay EXPAND');
      return;
    }
    try {
      FoldService.readCrease();
      const raw: number = display.getFoldStatus();
      FoldService.physStatus = raw;
      hilog.info(DOMAIN, TAG, 'subscribe: raw status=%{public}s creaseH=%{public}s',
        raw.toString(), FoldService.creaseHorizontal ? 'true' : 'false');
      if (raw === display.FoldStatus.FOLD_STATUS_FOLDED) {
        FoldService.foldState = 'FOLDED';
      } else if (raw === display.FoldStatus.FOLD_STATUS_HALF_FOLDED) {
        if (FoldService.creaseHorizontal) {
          FoldService.foldState = 'HALF_FOLD';
          FoldService.angleKnown = false;
          hilog.info(DOMAIN, TAG, 'cold-start HALF_FOLD (angle unknown, provisional)');
        } else {
          FoldService.foldState = 'HALF_FOLD';
        }
      } else {
        FoldService.foldState = 'EXPAND';
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'subscribe init failed: %{public}s', JSON.stringify(e));
      FoldService.foldState = 'EXPAND';
    }
    try {
      display.on('foldStatusChange', (st: display.FoldStatus) => {
        FoldService.physStatus = st as number;
        hilog.info(DOMAIN, TAG, 'foldStatusChange -> %{public}s', st.toString());
        FoldService.applyStatus(st as number, 'event');
      });
      display.on('foldAngleChange', (angles: Array<number>) => {
        const a: number = angles.length > 0 ? angles[0] : -1;
        FoldService.foldAngle = a;
        hilog.info(DOMAIN, TAG, 'foldAngleChange angle=%{public}s known=%{public}s',
          a.toString(), FoldService.angleKnown ? 'true' : 'false');
        FoldService.onAngle(a);
      });
      FoldService.subscribed = true;
      hilog.info(DOMAIN, TAG, 'subscribed foldStatusChange + foldAngleChange');
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'display.on failed: %{public}s', JSON.stringify(e));
    }
    FoldService.ready = true;
    hilog.info(DOMAIN, TAG, 'subscribe done, state=%{public}s', FoldService.foldState);
  }

  /** Ability onDestroy：全量取消。 */
  static unsubscribeAll(): void {
    try {
      display.off('foldStatusChange');
      display.off('foldAngleChange');
      hilog.info(DOMAIN, TAG, 'unsubscribed all');
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'display.off failed: %{public}s', JSON.stringify(e));
    }
    FoldService.subscribed = false;
    FoldService.cb = null;
  }

  /** Index aboutToAppear 注册一次；状态变化守卫在 setFoldState 内（不同才回调）。 */
  static onFoldChange(cb: (s: FoldState) => void): void {
    FoldService.cb = cb;
  }

  /** measureStage 内重读折痕区（D1：refresh 在 derive 之前）。 */
  static refreshCrease(): void {
    if (!FoldService.isFoldableDev) {
      return;
    }
    FoldService.readCrease();
  }

  private static readCrease(): void {
    try {
      const region: display.FoldCreaseRegion = display.getCurrentFoldCreaseRegion();
      const rects: Array<display.Rect> = region.creaseRects;
      // 合理性校验（D1 失败动作）：rect 须落在物理屏 px 帧内（Pura X Max 内屏 1828×2584，
      // 外屏 1264×1848；实测该 API 返回过 (0,9029px?,…) 系坐标帧不符的脏值）——
      // 不在已知屏幕 px 帧内即视为无回值，走 50% 回退（D1），不静默用错值。
      let raw: display.Rect | null = null;
      if (rects !== undefined && rects !== null && rects.length > 0) {
        const cand: display.Rect = rects[0];
        const fitInner: boolean = cand.left >= 0 && cand.top >= 0
          && cand.left + cand.width <= 1828 + 1 && cand.top + cand.height <= 2584 + 1;
        const fitOuter: boolean = cand.left >= 0 && cand.top >= 0
          && cand.left + cand.width <= 1264 + 1 && cand.top + cand.height <= 1848 + 1;
        if (fitInner || fitOuter) {
          raw = cand;
        } else {
          hilog.warn(DOMAIN, TAG,
            'crease rect out of screen px frame: (%{public}s,%{public}s,%{public}s,%{public}s) -> 50% fallback',
            cand.left.toString(), cand.top.toString(), cand.width.toString(), cand.height.toString());
        }
      }
      if (raw !== null) {
        const rect: CreaseRectVp = {
          x: FoldService.px2vp(raw.left),
          y: FoldService.px2vp(raw.top),
          w: FoldService.px2vp(raw.width),
          h: FoldService.px2vp(raw.height),
        };
        FoldService.creaseRect = rect;
        FoldService.creaseHorizontal = raw.width > raw.height;
        hilog.info(DOMAIN, TAG,
          'crease vp=(%{public}s,%{public}s,%{public}s,%{public}s) horizontal=%{public}s',
          FoldService.creaseRect.x.toFixed(1), FoldService.creaseRect.y.toFixed(1),
          FoldService.creaseRect.w.toFixed(1), FoldService.creaseRect.h.toFixed(1),
          FoldService.creaseHorizontal ? 'true' : 'false');
      } else {
        // 50% 回退：API 无回值/脏值 → 分界取窗口高 50%，带高 0，Spacer=0（D1）
        FoldService.creaseRect = null;
        FoldService.creaseHorizontal = true;
        hilog.warn(DOMAIN, TAG, 'crease unavailable; fallback 50% line, band height 0');
      }
    } catch (e) {
      FoldService.creaseRect = null;
      FoldService.creaseHorizontal = true;
      hilog.warn(DOMAIN, TAG, 'getCurrentFoldCreaseRegion failed: %{public}s', JSON.stringify(e));
    }
  }

  /** 折痕带 vp（窗口坐标系）：y=top, bottom=top+h；无回值时 50% 线、带高 0。 */
  static creaseTopVp(winHvp: number): number {
    return FoldService.creaseRect !== null ? FoldService.creaseRect.y : winHvp / 2;
  }

  static creaseBottomVp(winHvp: number): number {
    return FoldService.creaseRect !== null
      ? FoldService.creaseRect.y + FoldService.creaseRect.h
      : winHvp / 2;
  }

  /** setFoldState：不同则先赋值、再回调（回调里读到新值）；相同则不回调（v8 S-R2-N1）。 */
  private static setFoldState(next: FoldState): void {
    if (FoldService.foldState === next) {
      return;
    }
    FoldService.foldState = next;
    hilog.info(DOMAIN, TAG, 'foldState -> %{public}s', next);
    const cb = FoldService.cb;
    if (cb !== null) {
      cb(next);
    }
  }

  /** foldStatusChange / 冷启动共用：按物理态＋折痕朝向定 foldState（真值表 D2）。 */
  private static applyStatus(raw: number, src: string): void {
    if (raw === display.FoldStatus.FOLD_STATUS_FOLDED) {
      FoldService.setFoldState('FOLDED');
      return;
    }
    if (raw === display.FoldStatus.FOLD_STATUS_EXPANDED) {
      FoldService.setFoldState('EXPAND');
      return;
    }
    if (raw === display.FoldStatus.FOLD_STATUS_HALF_FOLDED) {
      FoldService.readCrease();
      if (FoldService.creaseHorizontal) {
        // 角度判定：冷启动暂定（angleKnown=false）直接 HALF_FOLD；事件路径按上一状态守恒＋边沿规则
        if (!FoldService.angleKnown) {
          FoldService.setFoldState('HALF_FOLD');
          return;
        }
        const a: number | null = FoldService.foldAngle;
        if (a !== null && (a < 60 || a > 120)) {
          // 保持上一 foldState（不跳变），记 hilog（真值表第 4 行）
          hilog.info(DOMAIN, TAG,
            'HALF_FOLDED angle %{public}s out of [60,120], keep %{public}s (src=%{public}s)',
            a.toString(), FoldService.foldState, src);
          return;
        }
        FoldService.setFoldState('HALF_FOLD');
        return;
      }
      // 纵向折痕：状态如实报，布局回退展开态（deriveLayoutMode 处理）
      FoldService.setFoldState('HALF_FOLD');
      return;
    }
    // 其余枚举（11 等）按 EXPAND 处理并记日志
    hilog.info(DOMAIN, TAG, 'unhandled fold status %{public}s, treat as EXPAND', raw.toString());
    FoldService.setFoldState('EXPAND');
  }

  /**
   * 角度回调：更新 angle；冷启动暂定态首个回调视为初始读数（纠正或确认）；
   * 边沿触发进入（D2）：!prevAngleInRange && angle∈[60,120] && 物理态 HALF_FOLDED && 横折痕 → 重估入场门。
   * 角度漂出区间不动（漂移不退出）。不逐度触发布局重算。
   */
  private static onAngle(a: number): void {
    const inRange: boolean = a >= 60 && a <= 120;
    if (!FoldService.angleKnown) {
      FoldService.angleKnown = true;
      if (FoldService.foldState === 'HALF_FOLD' && FoldService.creaseHorizontal) {
        if (!inRange) {
          hilog.info(DOMAIN, TAG, 'cold-start angle corrected: %{public}s -> EXPAND', a.toString());
          FoldService.setFoldState('EXPAND');
        } else {
          hilog.info(DOMAIN, TAG, 'cold-start provisional HALF_FOLD confirmed at %{public}s',
            a.toString());
        }
      }
      FoldService.prevAngleInRange = inRange;
      return;
    }
    if (!FoldService.prevAngleInRange && inRange
      && FoldService.physStatus === display.FoldStatus.FOLD_STATUS_HALF_FOLDED
      && FoldService.creaseHorizontal) {
      hilog.info(DOMAIN, TAG, 'edge-enter [60,120] at %{public}s, re-run entry gate', a.toString());
      FoldService.applyStatus(display.FoldStatus.FOLD_STATUS_HALF_FOLDED, 'angle-edge');
    }
    FoldService.prevAngleInRange = inRange;
  }
}