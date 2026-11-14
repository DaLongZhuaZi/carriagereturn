/**
 * 第 16 批 2A：Canvas 打字机主屏（骨架＋静态层）
 *
 * 设计依据：docs/designs/16-Canvas实施设计-增量设计.md §2.1／§3／§4。
 * 2A 范围：Canvas 盒子＋变换矩阵＋分层（L0 底色／L1 静态层／L2 纸层／L3 骨架），
 * 静态整机（滚筒、底座、压纸卷、中央件、拨杆、键带、功能行、字体条）＋纸面静态文字；
 * TopBar 保留 ArkUI 叠加并按变换矩阵定位；IME 锚点透明层挂载（不接事件）。
 *
 * 坐标口径：本组件按当前 Index stage 布局取值（stageWidth=窗口宽，stageHeight=窗口高），
 * 绘制坐标与 Index 现行 @State 几何同源；纯几何公式见 model/CanvasGeometry.ets。
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { image } from '@kit.ImageKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { MachineKind, PaperKind } from '../model/DocModel';
import { findMachine, findPaper, MachineSpec, PaperSpec, TOP_BAR_HEIGHT_VP, PAPER_TOP_GAP_VP,
  FONT_BAR_HEIGHT_VP, FUNCTION_ROW_HEIGHT_VP } from '../model/MachineCatalog';
import { KeymapParser, KeymapLayout, CapDef } from '../model/KeymapModel';
import { CanvasTransform, computeTransform, referenceMetrics } from '../model/CanvasGeometry';
import { restDegFor, swingDegFor } from '../model/LeverAngleCore';
import { TopBar } from './TopBar';

const CDOMAIN: number = 0x0100;
const CTAG: string = 'CanvasTypewriter';

/** 参考机坐标常量（本组件内部以 stage 坐标为绘制单位）。 */
const KEYBAND_ASPECT: number = 2048 / 975;

interface CanvasLayoutInner {
  w: number;
  h: number;
  top: number;
  bottom: number;
  stackTop: number;
  paperX: number;
  paperY: number;
  carrAbs: number;
}

@Component
export struct CanvasTypewriter {
  @Prop widthVp: number = 362.7;
  @Prop heightVp: number = 822.5;
  @Prop topInset: number = 0;
  @Prop bottomInset: number = 0;
  @Prop isTablet: boolean = false;
  @Prop @Watch('onMachineKindChanged') machineKind: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop @Watch('onPaperKindChanged') paperKind: PaperKind = PaperKind.LETTER;
  @Prop docTitle: string = '未命名';
  @Prop guideEnabled: boolean = true;
  // Index 现行几何（2A 保持与 ArkUI 主屏同源；2B 切主屏后仍由 Index 传入）
  @Prop paperWidthVp: number = 264.1;
  @Prop paperHeightVp: number = 373.5;
  @Prop carriageTopVp: number = 300.0;
  @Prop carriageHeightVp: number = 44.9;
  @Prop strikeLineVp: number = 270.0;
  @Prop fontSizeVp: number = 17;
  @Prop lineHeightVp: number = 30;
  @Prop marginHVp: number = 48;
  @Prop marginTVp: number = 24;
  @Prop marginBVp: number = 20;
  @Prop pageNo: number = 1;
  @Prop pageCount: number = 1;
  @Prop hintText: string = '';
  @Prop @Watch('onDocChanged') lines: string[] = [''];
  @Prop @Watch('onDocChanged') paperTopVp: number = 206;
  @Prop @Watch('onDocChanged') paperContainerVp: number = 96;
  @Prop @Watch('onDocChanged') cursorXVp: number = 48;
  @Prop @Watch('onDocChanged') cursorYVp: number = 0;
  @Prop @Watch('onDocChanged') leverRatio: number = 0;
  @Prop keybedHeightVp: number = 172.7;
  @Prop functionRowHeightVp: number = 52;
  @Prop fontBarHeightVp: number = 38;
  @Prop candBarHeightVp: number = 44;
  @Prop langLabel: string = 'EN';
  @Prop deleteLabel: string = '删除';
  @Prop newlineLabel: string = '换行';
  @Prop paperLabel: string = '换纸';
  @Prop backLineLabel: string = '退行';
  @Prop charLabel: string = '字符';
  @Prop fontFamily: string = 'CourierPrime';
  @Prop fontLabel: string = 'Courier Prime';
  @Prop inkColor: string = '#1a1a1a';
  onOpenHome: () => void = (): void => {};
  onOpenMenu: () => void = (): void => {};
  // 2B 交互：键帽 Down/Up、拨杆三阶段
  onCapDown: (cap: CapDef) => void = (_cap: CapDef): void => {};
  onCapUp: (cap: CapDef) => void = (_cap: CapDef): void => {};
  onLeverStart: (x: number) => void = (_x: number): void => {};
  onLeverUpdate: (dy: number) => void = (_dy: number): void => {};
  onLeverEnd: () => void = (): void => {};

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;
  private machineLayer: ImageBitmap | null = null;
  private machineFrontLayer: ImageBitmap | null = null;
  private paperLayer: ImageBitmap | null = null;
  private keymap: KeymapLayout = {
    machine: '', caps: [], spaceXMin: 0, spaceXMax: 0, spaceYMin: 0, spaceYMax: 0,
    hitRadius: 10, spaceR: 8, overlayColor: '#312b24', overlayFontSize: 14,
    widthVp: 0, heightVp: 0,
  };
  private imgRoller: image.PixelMap | null = null;
  private imgBase: image.PixelMap | null = null;
  private imgBail: image.PixelMap | null = null;
  private imgCentral: image.PixelMap | null = null;
  private imgBracket: image.PixelMap | null = null;
  private imgLever: image.PixelMap | null = null;
  private imgTypebar: image.PixelMap | null = null;
  private imgKeyband: image.PixelMap | null = null;
  private imgPaper: image.PixelMap | null = null;
  private machineBuildCount: number = 0;
  private paperBuildCount: number = 0;
  private heldCaps: Map<number, CapDef> = new Map<number, CapDef>();
  private leverActive: boolean = false;
  private leverStartY: number = 0;

  /** 2B：文档/光标变化时重画纸面（静态纸层不变）。 */
  onDocChanged(): void {
    this.draw();
  }

  /** 2A-4：换机只重建机器层；换纸只重建纸层。 */
  onMachineKindChanged(): void {
    this.loadMachineImages().then(() => {
      this.buildMachineLayer();
      this.draw();
    });
  }

  onPaperKindChanged(): void {
    this.loadPaperImage().then(() => {
      this.buildPaperLayer();
      this.draw();
    });
  }

  aboutToAppear(): void {
    hilog.info(CDOMAIN, CTAG,
      'layout W=%{public}s H=%{public}s top=%{public}s bottom=%{public}s Pw=%{public}s paperTop=%{public}s paperBox=%{public}s carrTop=%{public}s Hc=%{public}s strike=%{public}s fs=%{public}s lh=%{public}s',
      this.widthVp.toFixed(1), this.heightVp.toFixed(1), this.topInset.toFixed(1), this.bottomInset.toFixed(1),
      this.paperWidthVp.toFixed(1), this.paperTopVp.toFixed(1), this.paperContainerVp.toFixed(1),
      this.carriageTopVp.toFixed(1), this.carriageHeightVp.toFixed(1), this.strikeLineVp.toFixed(1),
      this.fontSizeVp.toFixed(1), this.lineHeightVp.toFixed(1));
    const tr: CanvasTransform = computeTransform(this.widthVp, this.heightVp, this.topInset);
    const ref = referenceMetrics(this.isTablet);
    hilog.info(CDOMAIN, CTAG,
      'transform scale=%{public}s tx=%{public}s ty=%{public}s refPaperTop=%{public}s refCarriageTop=%{public}s refStrike=%{public}s',
      tr.scale.toFixed(4), tr.tx.toFixed(2), tr.ty.toFixed(2), ref.paperTop.toFixed(2),
      ref.carriageTop.toFixed(2), ref.strikeLine.toFixed(2));
    this.prepare();
  }

  private logTopBarRect(): void {
    try {
      const info = this.getUIContext().getComponentUtils().getRectangleById('canvas_topbar');
      const vp2px: number = this.getUIContext().vp2px(1);
      const expX: number = 0;
      const expY: number = this.topInset * vp2px;
      const expW: number = this.widthVp * vp2px;
      const expH: number = 56 * vp2px;
      hilog.info(CDOMAIN, CTAG,
        'topbar rect=%{public}s,%{public}s,%{public}s,%{public}s expect=%{public}s,%{public}s,%{public}s,%{public}s dX=%{public}s dY=%{public}s dW=%{public}s dH=%{public}s',
        info.screenOffset.x.toFixed(1), info.screenOffset.y.toFixed(1), info.size.width.toFixed(1),
        info.size.height.toFixed(1), expX.toFixed(1), expY.toFixed(1), expW.toFixed(1), expH.toFixed(1),
        Math.abs(info.screenOffset.x - expX * vp2px).toFixed(1),
        Math.abs(info.screenOffset.y - expY).toFixed(1),
        Math.abs(info.size.width - expW).toFixed(1), Math.abs(info.size.height - expH).toFixed(1));
    } catch (e) {
      hilog.warn(CDOMAIN, CTAG, 'topbar rect failed');
    }
  }

  /** Canvas font 字符串只取单一族名（逗号列表在 Canvas 里会回落系统字体）。 */
  private canvasFont(): string {
    const i: number = this.fontFamily.indexOf(',');
    return i > 0 ? this.fontFamily.substring(0, i).trim() : this.fontFamily;
  }

  private spec(): MachineSpec {
    return findMachine(this.machineKind);
  }

  private paperSpec(): PaperSpec {
    return findPaper(this.paperKind);
  }

  private slug(): string {
    if (this.machineKind === MachineKind.UPRIGHT_1920S) { return '1920s-upright'; }
    if (this.machineKind === MachineKind.PORTABLE_1930S) { return '1930s-portable'; }
    if (this.machineKind === MachineKind.STREAMLINED_1950S) { return '1950s-streamlined'; }
    return '1960s-electric';
  }

  private keybandPath(): string {
    if (this.machineKind === MachineKind.UPRIGHT_1920S) { return 'machine/1920s-upright-keyband-phone.jpg'; }
    if (this.machineKind === MachineKind.PORTABLE_1930S) { return 'machine/1930s-portable-keyband-phone.jpg'; }
    if (this.machineKind === MachineKind.STREAMLINED_1950S) { return 'machine/1950s-streamlined-keyband-phone.jpg'; }
    return 'machine/1960s-electric-keyband-phone.jpg';
  }

  private async loadRaw(path: string): Promise<image.PixelMap | null> {
    try {
      const bytes: Uint8Array = getContext(this).resourceManager.getRawFileContentSync(path);
      const ab: ArrayBuffer = new ArrayBuffer(bytes.length);
      const view: Uint8Array = new Uint8Array(ab);
      for (let i = 0; i < bytes.length; i++) {
        view[i] = bytes[i];
      }
      const src: image.ImageSource = image.createImageSource(ab);
      return await src.createPixelMap();
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(CDOMAIN, CTAG, 'image load failed path=%{public}s code=%{public}d msg=%{public}s',
        path, err.code === undefined ? -1 : err.code, err.message === undefined ? '?' : err.message);
      return null;
    }
  }

  private utf8ToString(bytes: Uint8Array): string {
    let out: string = '';
    let i: number = 0;
    while (i < bytes.length) {
      const c: number = bytes[i];
      if (c < 0x80) { out += String.fromCharCode(c); i += 1; }
      else if (c < 0xE0 && i + 1 < bytes.length) {
        out += String.fromCharCode(((c & 0x1F) << 6) | (bytes[i + 1] & 0x3F)); i += 2;
      } else if (c < 0xF0 && i + 2 < bytes.length) {
        out += String.fromCharCode(((c & 0x0F) << 12) | ((bytes[i + 1] & 0x3F) << 6) | (bytes[i + 2] & 0x3F)); i += 3;
      } else if (i + 3 < bytes.length) {
        const cp: number = ((c & 0x07) << 18) | ((bytes[i + 1] & 0x3F) << 12) |
          ((bytes[i + 2] & 0x3F) << 6) | (bytes[i + 3] & 0x3F);
        out += String.fromCharCode(0xD800 + ((cp - 0x10000) >> 10), 0xDC00 + ((cp - 0x10000) & 0xFFFF));
        i += 4;
      } else { break; }
    }
    return out;
  }

  private async loadMachineImages(): Promise<void> {
    const slug: string = this.slug();
    this.imgRoller = await this.loadRaw('layers/' + slug + '/roller-texture-v7.jpg');
    this.imgBase = await this.loadRaw('layers/' + slug + '/carriage-base-rail.png');
    this.imgBail = await this.loadRaw('layers/' + slug + '/paper-bail-v2.png');
    this.imgCentral = await this.loadRaw('layers/' + slug + '/central-guide.png');
    this.imgBracket = await this.loadRaw('layers/' + slug + '/lever-pivot-bracket.png');
    if (this.machineKind === MachineKind.PORTABLE_1930S) {
      this.imgLever = await this.loadRaw('layers/1930s-portable/lever.png');
    } else if (this.machineKind === MachineKind.STREAMLINED_1950S) {
      this.imgLever = await this.loadRaw('layers/1950s-streamlined/lever.png');
    } else if (this.machineKind === MachineKind.ELECTRIC_1960S) {
      this.imgLever = await this.loadRaw('layers/1960s-electric/lever.png');
    } else {
      this.imgLever = await this.loadRaw('layers/1920s-upright/lever.png');
    }
    if (this.machineKind === MachineKind.UPRIGHT_1920S) {
      this.imgTypebar = null;
    } else if (this.machineKind === MachineKind.PORTABLE_1930S) {
      this.imgTypebar = await this.loadRaw('typebar/1930s-portable-typebar-vertical.png');
    } else if (this.machineKind === MachineKind.STREAMLINED_1950S) {
      this.imgTypebar = await this.loadRaw('typebar/1950s-streamlined-typebar-vertical.png');
    } else {
      this.imgTypebar = await this.loadRaw('typebar/1960s-electric-typebar-vertical.png');
    }
    this.imgKeyband = await this.loadRaw(this.keybandPath());
    try {
      const kmBytes: Uint8Array = getContext(this).resourceManager.getRawFileContentSync(this.spec().keymapRawfile);
      const kmText: string = this.utf8ToString(kmBytes);
      this.keymap = KeymapParser.parse(kmText, this.machineKind as string, false, this.keybedWidth(),
        this.keybedHeightVp, this.spec().overlayColor, this.spec().overlayFontSizeVp);
    } catch (e) {
      hilog.error(CDOMAIN, CTAG, 'keymap load failed');
    }
  }

  private async loadPaperImage(): Promise<void> {
    this.imgPaper = await this.loadRaw(this.paperSpec().textureRawfile);
  }

  private async prepare(): Promise<void> {
    await this.loadMachineImages();
    await this.loadPaperImage();
    this.ready = true;
    this.buildStaticLayers();
    this.draw();
    setTimeout(() => { this.logTopBarRect(); }, 100);
  }

  private keybedWidth(): number {
    return this.widthVp;
  }

  private stackTop(): number {
    return this.topInset + TOP_BAR_HEIGHT_VP + PAPER_TOP_GAP_VP;
  }

  private paperX(): number {
    return (this.widthVp - this.paperWidthVp) / 2;
  }

  private paperY(): number {
    return this.stackTop() + this.paperTopVp;
  }

  private keybedTop(): number {
    return this.heightVp - this.bottomInset - this.functionRowHeightVp - this.keybedHeightVp;
  }

  private fontBarTop(): number {
    return this.keybedTop() - this.fontBarHeightVp;
  }

  private candBarTop(): number {
    return this.fontBarTop() - this.candBarHeightVp;
  }

  private buildStaticLayers(): void {
    if (!this.ready) { return; }
    this.buildMachineLayer();
    this.buildPaperLayer();
  }

  /** L1 静态层：机身／键带／功能行／字体条（只缓存当前机型＋当前纸种）。 */
  private buildMachineLayer(): void {
    const w: number = Math.max(1, Math.round(this.widthVp));
    const h: number = Math.max(1, Math.round(this.heightVp));
    const off: OffscreenCanvas = new OffscreenCanvas(w, h);
    const ctx: OffscreenCanvasRenderingContext2D = off.getContext('2d');
    const offFront: OffscreenCanvas = new OffscreenCanvas(w, h);
    const ctxFront: OffscreenCanvasRenderingContext2D = offFront.getContext('2d');
    const spec: MachineSpec = this.spec();
    const Hc: number = this.carriageHeightVp;
    const carrAbs: number = this.stackTop() + this.carriageTopVp;
    const paperLeft: number = this.paperX();
    const knobD: number = Hc * 0.92;
    const baseW: number = this.paperWidthVp + 2 * knobD;
    const baseLeft: number = Math.max(0, paperLeft - knobD);
    const rollW: number = this.paperWidthVp / spec.rollerWidthRatio;
    const rollX: number = paperLeft - (rollW - this.paperWidthVp) / 2;
    // 滚筒纹理（纵向滚动量 = 0）
    if (this.imgRoller !== null) {
      ctx.drawImage(this.imgRoller, rollX, carrAbs - Hc / 2, rollW, Hc);
    }
    // 柱面明暗罩（简化 3 段）
    const shade: CanvasGradient = ctx.createLinearGradient(0, carrAbs - Hc / 2, 0, carrAbs + Hc / 2);
    shade.addColorStop(0.0, 'rgba(255,246,230,0.30)');
    shade.addColorStop(0.35, 'rgba(0,0,0,0)');
    shade.addColorStop(0.52, 'rgba(255,246,230,0.32)');
    shade.addColorStop(0.82, 'rgba(0,0,0,0.42)');
    shade.addColorStop(1.0, 'rgba(0,0,0,0.72)');
    ctx.fillStyle = shade;
    ctx.fillRect(rollX, carrAbs - Hc / 2, rollW, Hc);
    // 滚筒后进纸边
    ctx.fillStyle = 'rgba(232,221,201,0.85)';
    ctx.fillRect(rollX, carrAbs + Hc / 2, rollW, 5);
    // 木底座
    const baseY: number = carrAbs + Hc / 2 + 2;
    const baseH: number = Math.min(baseW / spec.baseRailAspect, Hc);
    if (this.imgBase !== null) {
      ctx.drawImage(this.imgBase, baseLeft, baseY, baseW, baseH);
    }
    // 沟槽
    ctx.fillStyle = 'rgba(18,13,8,0.92)';
    ctx.fillRect(baseLeft + 10, baseY + 6, baseW - 20, 14);
    // 铭牌（黄铜渐变 + 文字）
    const plateLeft: number = baseLeft + baseW * 0.32 - 55;
    const plateGrad: CanvasGradient = ctx.createLinearGradient(0, baseY + 0, 0, baseY + 26);
    plateGrad.addColorStop(0, '#f0d79a');
    plateGrad.addColorStop(0.55, '#c9a45c');
    plateGrad.addColorStop(1, '#8a6a2f');
    ctx.fillStyle = plateGrad;
    ctx.fillRect(plateLeft, baseY, 110, 26);
    ctx.fillStyle = '#3a2410';
    ctx.font = '13vp sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(this.machineNamePlate(), plateLeft + 55, baseY + 18);
    // 压纸卷（纸之上）
    const bailH: number = this.paperWidthVp / 9.6678;
    const bailY: number = carrAbs - bailH / 2 + (this.isTablet ? -15 : 0);
    if (this.imgBail !== null) {
      ctxFront.drawImage(this.imgBail, paperLeft, bailY, this.paperWidthVp, bailH);
    }
    // 中央件（纸之上）
    const Hg: number = Hc * 1.5;
    const strikeX: number = paperLeft + this.marginHVp;
    const strikeAbs: number = this.stackTop() + this.strikeLineVp;
    const centralW: number = Hg * spec.centralAspect;
    if (this.imgCentral !== null) {
      ctxFront.drawImage(this.imgCentral, strikeX - centralW / 2, strikeAbs - Hg * spec.centralWindowY, centralW, Hg);
    }
    // 拨杆支点支架
    const bracketW: number = 60;
    const bracketH: number = bracketW / spec.bracketAspect;
    const bracketLeft: number = baseLeft + baseW - bracketW - 10;
    const bracketTop: number = carrAbs - Hc / 2 + Hc + 24 - bracketH;
    if (this.imgBracket !== null) {
      ctxFront.drawImage(this.imgBracket, bracketLeft, bracketTop, bracketW, bracketH);
    }

    // 字杆静止层：非 1920s 机型画（1920s 当前主屏静止态不可见，画了反而破坏 0.00%）
    if (this.imgTypebar !== null) {
      const tbSize: number = Hc * 2.5;
      const tbX: number = paperLeft + this.marginHVp - tbSize / 2;
      const tbY: number = this.stackTop() + this.strikeLineVp - 0.115 * tbSize;
      ctxFront.save();
      ctxFront.translate(tbX + tbSize * 0.5, tbY + tbSize * 0.867);
      ctxFront.rotate(55 * Math.PI / 180);
      ctxFront.drawImage(this.imgTypebar, -tbSize * 0.5, -tbSize * 0.867, tbSize, tbSize);
      ctxFront.restore();
    }
    // 键带图
    if (this.imgKeyband !== null) {
      ctx.drawImage(this.imgKeyband, 0, this.keybedTop(), this.widthVp, this.keybedHeightVp);
    }
    // 字体条分隔线
    ctx.fillStyle = '#3a332b';
    ctx.fillRect(0, this.fontBarTop(), this.widthVp, 1);
    ctx.fillRect(0, this.fontBarTop() + this.fontBarHeightVp - 1, this.widthVp, 1);
    // 功能行
    ctx.fillStyle = '#241c16';
    ctx.fillRect(0, this.heightVp - this.bottomInset - this.functionRowHeightVp, this.widthVp, this.functionRowHeightVp);
    this.drawFunctionRow(ctx);
    this.machineLayer = off.transferToImageBitmap();
    this.machineFrontLayer = offFront.transferToImageBitmap();
    this.machineBuildCount++;
    hilog.info(CDOMAIN, CTAG, 'static layer rebuilt: machine count=%{public}d', this.machineBuildCount);
  }

  private leverSizeRatio(spec: MachineSpec): number {
    // 各机蓝图 leverSizeRatio（machines/<kind>/Blueprint.ets，2026-11-14 亲核）
    if (this.machineKind === MachineKind.UPRIGHT_1920S) { return 0.212; }
    if (this.machineKind === MachineKind.PORTABLE_1930S) { return 0.3264; }
    if (this.machineKind === MachineKind.STREAMLINED_1950S) { return 0.09; }
    return 0.12;
  }

  private machineNamePlate(): string {
    if (this.machineKind === MachineKind.UPRIGHT_1920S) { return '1920s'; }
    if (this.machineKind === MachineKind.PORTABLE_1930S) { return '1930s'; }
    if (this.machineKind === MachineKind.STREAMLINED_1950S) { return '1950s'; }
    return '1960s';
  }

  private drawFunctionRow(ctx: OffscreenCanvasRenderingContext2D): void {
    const y0: number = this.heightVp - this.bottomInset - this.functionRowHeightVp + 6;
    const h: number = this.functionRowHeightVp - 12;
    const left: number = 8;
    const right: number = this.widthVp - 8;
    const gap: number = 6;
    const keyW: number = (right - left - gap * 5) / 6;
    for (let i = 0; i < 6; i++) {
      const x: number = left + i * (keyW + gap);
      ctx.fillStyle = '#2e2823';
      ctx.fillRect(x, y0, keyW, h);
      ctx.strokeStyle = i === 0 || i === 5 || i === 2 ? '#c9a45c' : '#6b6055';
      ctx.lineWidth = 1;
      ctx.strokeRect(x + 0.5, y0 + 0.5, keyW - 1, h - 1);
    }
  }

  /** L2 纸层：纸纹＋页眉＋页码＋行文字＋引导文案＋光标三角。 */
  private buildPaperLayer(): void {
    const w: number = Math.max(1, Math.round(this.paperWidthVp));
    const h: number = Math.max(1, Math.round(this.paperHeightVp));
    const off: OffscreenCanvas = new OffscreenCanvas(w, h);
    const ctx: OffscreenCanvasRenderingContext2D = off.getContext('2d');
    if (this.imgPaper !== null) {
      ctx.drawImage(this.imgPaper, 0, 0, this.paperWidthVp, this.paperHeightVp);
    } else {
      ctx.fillStyle = '#f4ecd8';
      ctx.fillRect(0, 0, this.paperWidthVp, this.paperHeightVp);
    }
    const ps: PaperSpec = this.paperSpec();
    if (ps.hasHeader) {
      ctx.fillStyle = '#c8b9a6';
      ctx.fillRect(0, this.marginTVp, this.paperWidthVp, 1);
      ctx.fillRect(0, this.marginTVp + 4, this.paperWidthVp, 1);
    }
    if (ps.hasRuledGrid) {
      ctx.fillStyle = '#c8a49a';
      ctx.fillRect(this.marginHVp - 8, 0, 1, this.paperHeightVp);
    }
    this.paperLayer = off.transferToImageBitmap();
    this.paperBuildCount++;
    hilog.info(CDOMAIN, CTAG, 'static layer rebuilt: paper count=%{public}d', this.paperBuildCount);
  }

  private draw(): void {
    if (!this.ready) { return; }
    const ctx: CanvasRenderingContext2D = this.ctx;
    ctx.clearRect(0, 0, this.widthVp, this.heightVp);
    // L0 底色（铺满整屏含余量区）
    const bg: CanvasGradient = ctx.createLinearGradient(0, 0, 0, this.heightVp);
    bg.addColorStop(0, '#171310');
    bg.addColorStop(1, '#241c16');
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, this.widthVp, this.heightVp);
    if (this.machineLayer !== null) {
      ctx.drawImage(this.machineLayer, 0, 0);
    }
    if (this.paperLayer !== null) {
      ctx.save();
      ctx.beginPath();
      ctx.rect(this.paperX(), this.paperY(), this.paperWidthVp, this.paperContainerVp);
      ctx.clip();
      ctx.drawImage(this.paperLayer, this.paperX(), this.paperY());
      ctx.restore();
    }
    if (this.machineFrontLayer !== null) {
      ctx.drawImage(this.machineFrontLayer, 0, 0);
    }
    this.drawLever(ctx);
    this.drawTexts(ctx);
  }

  /** 拨杆按 leverRatio 实时重画（静止角/摆幅按机；0=静止，1=满摆）。 */
  private drawLever(ctx: CanvasRenderingContext2D): void {
    if (this.imgLever === null) {
      return;
    }
    const spec: MachineSpec = this.spec();
    const Hc: number = this.carriageHeightVp;
    const paperLeft: number = this.paperX();
    const knobD: number = Hc * 0.92;
    const baseLeft: number = (this.widthVp - this.paperWidthVp) / 2 - knobD;
    const baseW: number = this.paperWidthVp + 2 * knobD;
    const bracketW: number = 60;
    const bracketH: number = bracketW / spec.bracketAspect;
    const bracketLeft: number = baseLeft + baseW - bracketW - 10;
    const bracketTop: number = this.carriageTopVp - Hc / 2 + Hc + 24 - bracketH;
    const leverW: number = this.isTablet
      ? Hc * 1.84 * this.leverSizeRatio(spec)
      : Hc * 2.5 * this.leverSizeRatio(spec);
    const leverH: number = leverW / spec.leverAspect;
    const pinX: number = bracketLeft + spec.bracketPivotX * bracketW;
    const pinY: number = bracketTop + spec.bracketPivotY * bracketH;
    const angleDeg: number = restDegFor(this.isTablet) + swingDegFor(this.isTablet) * this.leverRatio;
    ctx.save();
    ctx.translate(pinX, pinY);
    ctx.rotate(angleDeg * Math.PI / 180);
    ctx.drawImage(this.imgLever, -leverW * spec.leverPivotX, -leverH * spec.leverPivotY, leverW, leverH);
    ctx.restore();
  }

  /** 文字统一在主 Canvas 上画（OffscreenCanvas 看不到 registerFont 注册字体，会回落到系统字体）。 */
  private drawTexts(ctx: CanvasRenderingContext2D): void {
    ctx.textBaseline = 'middle';
    // 纸面文字（裁剪到纸容器）
    ctx.save();
    ctx.beginPath();
    ctx.rect(this.paperX(), this.paperY(), this.paperWidthVp, this.paperContainerVp);
    ctx.clip();
    const paperLeft: number = this.paperX();
    const paperTop: number = this.paperY();
    const ps: PaperSpec = this.paperSpec();
    if (ps.hasHeader) {
      ctx.fillStyle = '#8a7f70';
      ctx.font = '12vp sans-serif';
      ctx.textAlign = 'right';
      ctx.fillText(this.pageNo.toString() + ' / ' + this.pageCount.toString(),
        paperLeft + this.paperWidthVp - this.marginHVp, paperTop + this.marginTVp + 18);
    }
    ctx.fillStyle = this.inkColor;
    ctx.font = this.fontSizeVp.toString() + 'vp ' + this.canvasFont();
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    const contentTop: number = paperTop + this.marginTVp + 20;
    for (let i = 0; i < this.lines.length; i++) {
      const line: string = this.lines[i];
      if (line.length > 0) {
        ctx.fillText(line, paperLeft + this.marginHVp, contentTop + i * this.lineHeightVp + this.lineHeightVp / 2);
      }
    }
    if (this.lines.length <= 1 && this.hintText.length > 0) {
      ctx.fillStyle = '#8a7f70';
      ctx.font = '13vp sans-serif';
      ctx.textAlign = 'left';
      ctx.fillText(this.hintText, paperLeft + this.marginHVp,
        paperTop + this.paperHeightVp - this.marginBVp - this.lineHeightVp + 16);
    }
    // 光标三角
    ctx.fillStyle = this.inkColor;
    ctx.beginPath();
    ctx.moveTo(paperLeft + this.cursorXVp, paperTop + this.cursorYVp);
    ctx.lineTo(paperLeft + this.cursorXVp + 8, paperTop + this.cursorYVp);
    ctx.lineTo(paperLeft + this.cursorXVp + 4, paperTop + this.cursorYVp + 6);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
    // 键帽叠字（裁剪到键带区）
    ctx.save();
    ctx.beginPath();
    ctx.rect(0, this.keybedTop(), this.widthVp, this.keybedHeightVp);
    ctx.clip();
    ctx.fillStyle = this.keymap.overlayColor;
    ctx.font = this.keymap.overlayFontSize.toString() + 'vp ' + (this.machineKind === MachineKind.UPRIGHT_1920S ? 'NotoSerifSC' : this.canvasFont());
    ctx.textAlign = 'center';
    for (let i = 0; i < this.keymap.caps.length; i++) {
      const cap: CapDef = this.keymap.caps[i];
      if (cap.isExtra || cap.label === ' ') { continue; }
      ctx.fillText(cap.label, cap.xRatio * this.keybedWidth(), this.keybedTop() + cap.yRatio * this.keybedHeightVp);
    }
    ctx.restore();
    // 字体条
    ctx.fillStyle = '#beb4a8';
    ctx.font = '13vp ' + this.canvasFont();
    ctx.textAlign = 'center';
    ctx.fillText(this.fontLabel, this.widthVp / 2, this.fontBarTop() + this.fontBarHeightVp / 2);
    // 功能行文字
    const labels: string[] = [this.langLabel, this.deleteLabel, this.newlineLabel,
      this.paperLabel, this.backLineLabel, this.charLabel];
    const y0: number = this.heightVp - this.bottomInset - this.functionRowHeightVp + 6;
    const h: number = this.functionRowHeightVp - 12;
    const left: number = 8;
    const right: number = this.widthVp - 8;
    const gap: number = 6;
    const keyW: number = (right - left - gap * 5) / 6;
    ctx.font = '14vp sans-serif';
    ctx.textAlign = 'center';
    for (let i = 0; i < 6; i++) {
      ctx.fillStyle = i === 2 ? '#c9a45c' : '#dbccb3';
      ctx.fillText(labels[i], left + i * (keyW + gap) + keyW / 2, y0 + h / 2);
    }
  }

  private onCanvasTouch(e: TouchEvent): void {
    const touches = e.touches;
    hilog.info(CDOMAIN, CTAG, 'touch type=%{public}d n=%{public}d x=%{public}s y=%{public}s', e.type, touches.length, touches.length>0?touches[0].x.toFixed(1):'-', touches.length>0?touches[0].y.toFixed(1):'-');
    if (touches.length === 0) {
      return;
    }
    const t = touches[0];
    if (e.type === TouchType.Down) {
      const cap: CapDef | null = KeymapParser.hitTest(this.keymap, t.x, t.y - this.keybedTop());
      if (cap !== null && !cap.isExtra) {
        hilog.info(CDOMAIN, CTAG, 'hit cap=%{public}s x=%{public}s y=%{public}s', cap.label, t.x.toFixed(1), t.y.toFixed(1));
        this.heldCaps.set(t.id, cap);
        this.onCapDown(cap);
        return;
      }
      if (t.x > this.widthVp * 0.78 && t.y > this.carriageTopVp
        && t.y < this.carriageTopVp + this.carriageHeightVp) {
        this.leverActive = true;
        this.leverStartY = t.y;
        this.onLeverStart(t.x);
      }
      return;
    }
    if (e.type === TouchType.Move && this.leverActive) {
      this.onLeverUpdate(t.y - this.leverStartY);
      return;
    }
    if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
      if (this.leverActive) {
        this.leverActive = false;
        this.onLeverEnd();
      }
      this.heldCaps.forEach((cap: CapDef) => {
        this.onCapUp(cap);
      });
      this.heldCaps.clear();
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Canvas(this.ctx)
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .onReady(() => {
          this.ctx.font = '24vp CourierPrime';
          const probeW: number = this.ctx.measureText('Hello, World! 0123456789').width;
          hilog.info(CDOMAIN, CTAG, 'canvas ready w=%{public}s h=%{public}s fontProbeW=%{public}s',
            this.widthVp.toFixed(1), this.heightVp.toFixed(1), probeW.toFixed(2));
        })
      // TopBar 保留 ArkUI 叠加；位置由同一几何算出（x=0 因 stage 宽=窗口宽，y=topInset）
      TopBar({
        title: this.docTitle,
        heightVp: TOP_BAR_HEIGHT_VP,
        guideEnabled: this.guideEnabled,
        onOpenHome: (): void => { this.onOpenHome(); },
        onOpenMenu: (): void => { this.onOpenMenu(); },
      })
        .id('canvas_topbar')
        .width(this.widthVp)
        .position({ x: 0, y: this.topInset })
      // IME 锚点透明层（2A 只挂载、不接事件）
      TextInput({ placeholder: '' })
        .id('cn_anchor')
        .width(1).height(1).opacity(0.01)
        .hitTestBehavior(HitTestMode.None)
        .position({ x: this.paperX() + this.marginHVp, y: this.paperY() + this.cursorYVp })
    }
    .width('100%')
    .height('100%')
    .onTouch((e: TouchEvent): void => { this.onCanvasTouch(e); })
  }
}
