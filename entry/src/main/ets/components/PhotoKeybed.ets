/**
 * 照片键区（§2.3）：照片带 + 键帽叠字 + 容器级触摸。
 *
 * 铁律：
 * - 底图只用 keyband-phone / keyband-fold，绝不用 keyboard.jpg 裁带、绝不用 hero 整机图。
 * - 命中按键位坐标表（KeymapLayout）最近的帽心判定，不套统一网格。
 * - 照片帽按不下去：**不做缩放、不动 transform**，按下只叠一层高亮。
 * - 容器级 onTouch + Map<触点 id, 帽> 维护多点状态；Up/Cancel 清理该 id。
 * - 滑入只发声不上屏（防误落字）。
 */
import { MachineKind } from '../model/DocModel';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CapDef, KeymapLayout } from '../model/KeymapModel';

const KDOMAIN: number = 0x0100;
const KTAG: string = 'Keybed';

/** 空键位表：未加载时用，保证 layout 永不为 null（避免非空断言）。 */
function emptyLayout(): KeymapLayout {
  return {
    machine: '', caps: [], spaceXMin: 0, spaceXMax: 0, spaceYMin: 0, spaceYMax: 0,
    hitRadius: 10, overlayColor: '#000000', overlayFontSize: 14, widthVp: 390, heightVp: 186,
  };
}

/** 触点 id → 帽 id（多点状态）。 */
interface TouchState {
  map: Map<number, string>;
}

@Component
export struct PhotoKeybed {
  @Prop machineKind: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop foldBand: boolean = false;
  @Prop widthVp: number = 390;
  @Prop heightVp: number = 186;
  @Prop layout: KeymapLayout = emptyLayout();
  @Prop overlayFontFamily: string = 'CourierPrime';

  @State heldIds: string[] = [];

  private touchState: TouchState = { map: new Map<number, string>() };

  /** 按下当刻（同一回调内由主屏做：高亮 → 播音 → 震动 → 杆 → 落字）。 */
  onCapDown: (cap: CapDef) => void = (cap: CapDef): void => {};
  /** 抬手。 */
  onCapUp: (cap: CapDef) => void = (cap: CapDef): void => {};
  /** 滑入新帽：只发声，不上屏。 */
  onCapSlide: (cap: CapDef) => void = (cap: CapDef): void => {};

  private capIndex(id: string): number {
    const arr: string[] = this.heldIds;
    for (let i = 0; i < arr.length; i++) {
      if (arr[i] === id) {
        return i;
      }
    }
    return -1;
  }

  private addHeld(id: string): void {
    if (this.capIndex(id) >= 0) {
      return;
    }
    const next: string[] = [];
    for (const s of this.heldIds) {
      next.push(s);
    }
    next.push(id);
    this.heldIds = next;
  }

  private removeHeld(id: string): void {
    const next: string[] = [];
    for (const s of this.heldIds) {
      if (s !== id) {
        next.push(s);
      }
    }
    this.heldIds = next;
  }

  private handleTouch(event: TouchEvent): void {
    const layout: KeymapLayout = this.layout;
    if (event.type === TouchType.Down) {
      for (const t of event.changedTouches) {
        const cap: CapDef | null = this.hitAt(layout, t.x, t.y);
        hilog.info(KDOMAIN, KTAG,
          'DOWN t=(%{public}s,%{public}s) comp=%{public}sx%{public}s layout=%{public}sx%{public}s hitR=%{public}s hit=%{public}s',
          t.x.toFixed(1), t.y.toFixed(1), this.widthVp.toFixed(1), this.heightVp.toFixed(1),
          layout.widthVp.toFixed(1), layout.heightVp.toFixed(1),
          layout.hitRadius.toFixed(2), cap === null ? 'null' : cap.label);
        if (cap !== null) {
          this.touchState.map.set(t.id, cap.id);
          this.addHeld(cap.id);
          this.onCapDown(cap);
        }
      }
      return;
    }
    if (event.type === TouchType.Move) {
      // 滑入换帽：只发声不上屏
      for (const t of event.changedTouches) {
        const prevId: string | undefined = this.touchState.map.get(t.id);
        const cap: CapDef | null = this.hitAt(layout, t.x, t.y);
        const nextId: string = cap === null ? '' : cap.id;
        if (prevId !== undefined && prevId !== nextId) {
          this.removeHeld(prevId);
          if (cap !== null) {
            this.touchState.map.set(t.id, cap.id);
            this.addHeld(cap.id);
            this.onCapSlide(cap);
          } else {
            this.touchState.map.delete(t.id);
          }
        }
      }
      return;
    }
    // Up / Cancel：清理该触点 id（id 会被复用，必须清）
    for (const t of event.changedTouches) {
      const prevId: string | undefined = this.touchState.map.get(t.id);
      if (prevId !== undefined) {
        this.removeHeld(prevId);
        this.touchState.map.delete(t.id);
        const cap: CapDef | null = this.findById(layout, prevId);
        if (cap !== null) {
          this.onCapUp(cap);
        }
      }
    }
    if (event.type === TouchType.Cancel) {
      this.touchState.map.clear();
      this.heldIds = [];
    }
  }

  private findById(layout: KeymapLayout, id: string): CapDef | null {
    for (const cap of layout.caps) {
      if (cap.id === id) {
        return cap;
      }
    }
    return null;
  }

  private hitAt(layout: KeymapLayout, x: number, y: number): CapDef | null {
    let best: CapDef | null = null;
    let bestDist: number = layout.hitRadius;
    if (x >= layout.spaceXMin && x <= layout.spaceXMax && y >= layout.spaceYMin && y <= layout.spaceYMax) {
      for (const cap of layout.caps) {
        if (cap.rowIndex === -1) {
          return cap;
        }
      }
      // 空格条不在 caps 里时构造一个（主屏按 label ' ' 处理）
      return {
        id: layout.machine + ':space',
        label: ' ',
        cx: (layout.spaceXMin + layout.spaceXMax) / 2,
        cy: (layout.spaceYMin + layout.spaceYMax) / 2,
        rowIndex: -1,
        isExtra: false,
        xRatio: 0.5,
        yRatio: 0.5,
      };
    }
    for (const cap of layout.caps) {
      // 命中同样用比例现算，与叠字同一坐标系
      const dx: number = cap.xRatio * this.widthVp - x;
      const dy: number = cap.yRatio * this.heightVp - y;
      const d: number = Math.sqrt(dx * dx + dy * dy);
      if (d <= bestDist) {
        bestDist = d;
        best = cap;
      }
    }
    return best;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 照片带：机型 × 手机/折叠 静态分支
      if (this.machineKind === MachineKind.UPRIGHT_1920S) {
        if (this.foldBand) {
          Image($rawfile('machine/1920s-upright-keyband-fold.jpg')).width(this.widthVp).height(this.heightVp).objectFit(ImageFit.Contain)
        } else {
          Image($rawfile('machine/1920s-upright-keyband-phone.jpg')).width(this.widthVp).height(this.heightVp).objectFit(ImageFit.Contain)
        }
      } else if (this.machineKind === MachineKind.PORTABLE_1930S) {
        Image($rawfile('machine/1930s-portable-keyband-phone.jpg')).width(this.widthVp).height(this.heightVp).objectFit(ImageFit.Contain)
      } else if (this.machineKind === MachineKind.STREAMLINED_1950S) {
        if (this.foldBand) {
          Image($rawfile('machine/1950s-streamlined-keyband-fold.jpg')).width(this.widthVp).height(this.heightVp).objectFit(ImageFit.Contain)
        } else {
          Image($rawfile('machine/1950s-streamlined-keyband-phone.jpg')).width(this.widthVp).height(this.heightVp).objectFit(ImageFit.Contain)
        }
      } else {
        if (this.foldBand) {
          Image($rawfile('machine/1960s-electric-keyband-fold.jpg')).width(this.widthVp).height(this.heightVp).objectFit(ImageFit.Contain)
        } else {
          Image($rawfile('machine/1960s-electric-keyband-phone.jpg')).width(this.widthVp).height(this.heightVp).objectFit(ImageFit.Contain)
        }
      }

      // 键帽叠字（extra 不叠）+ 按下高亮（只叠层，不动照片）
      ForEach(this.layout.caps, (cap: CapDef) => {
        // 一个 item 只能有一个根节点：叠字与按下高亮都放进这个 Stack
        Stack({ alignContent: Alignment.Center }) {
          if (this.capIndex(cap.id) >= 0) {
            Column()
              .width(this.layout.hitRadius * 1.9)
              .height(this.layout.hitRadius * 1.6)
              .borderRadius(6)
              .backgroundColor('#f2e6c9')
              .opacity(0.45)
          }
          if (!cap.isExtra) {
            Text(cap.label)
              .fontSize(this.layout.overlayFontSize)
              .fontColor(this.layout.overlayColor)
              .fontFamily(this.overlayFontFamily)
              .maxLines(1)
              .textAlign(TextAlign.Center)
          }
        }
        .width(this.layout.hitRadius * 2)
        .height(this.layout.hitRadius * 1.7)
        // 方案二：渲染时用当前宽高 × 比例现算，不依赖缓存 layout 里的绝对坐标
        .position({
          x: cap.xRatio * this.widthVp - this.layout.hitRadius,
          y: cap.yRatio * this.heightVp - this.layout.hitRadius * 0.85,
        })
        .hitTestBehavior(HitTestMode.None)
      }, (cap: CapDef) => cap.id)
    }
    .width(this.widthVp)
    .height(this.heightVp)
    .clip(true)
    .onAreaChange((oldA: Area, newA: Area) => {
      // 取证：组件宽高 + Contain 下 Image 实际绘制矩形 + 组件顶 y
      const w: number = newA.width as number;
      const h: number = newA.height as number;
      const imgAspect: number = 2048 / 975;
      let dw: number = w;
      let dh: number = w / imgAspect;
      if (dh > h) {
        dh = h;
        dw = h * imgAspect;
      }
      const topY: number = newA.globalPosition.y as number;
      hilog.info(KDOMAIN, KTAG,
        'keybed w=%{public}s h=%{public}s aspect=%{public}s imgDraw=%{public}sx%{public}s insetX=%{public}s insetY=%{public}s topY=%{public}s',
        w.toFixed(1), h.toFixed(1), (w / h).toFixed(4), dw.toFixed(1), dh.toFixed(1),
        ((w - dw) / 2).toFixed(1), ((h - dh) / 2).toFixed(1), topY.toFixed(1));
    })
    .onTouch((event: TouchEvent) => {
      this.handleTouch(event);
    })
  }
}