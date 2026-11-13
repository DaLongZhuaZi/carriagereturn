/**
 * 第 15 批 · Canvas Phase 0 探针页（**临时件**，探针结束随 Index 挂载分支一并删除）
 *
 * 依据：docs/designs/15-Canvas渲染-可行性方案.md v2（已批准，按缺省执行）§8.1。
 * 六项探针：P1 字体 / P6 图片取图（先于 P2）/ P2 帧率 / P3 触摸 / P4 输入 / P5 取证。
 * 探针页只做验证，不写实施设计、不动主屏渲染链、不碰第 13 批文件。
 */

import { AppIcon } from './AppIcon';
import { applyImmersive, Insets } from '../services/Immersive';
import { Animator, AnimatorOptions, AnimatorResult, KeyboardAvoidMode, UIContext, window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'CanvasProbe';

/** 参考机坐标系（§1.3）：宽／高／外壳高。 */
const REF_W: number = 673.7;
const REF_H: number = 1006.3;

/** P1 固定测试串（不得更改）§3.2。 */
const P1_STR: string = 'Hello, World! 0123456789';
const P1_FONT_VP: number = 24;

/** P2 落字测试字符数。 */
const P2_TYPE_CHARS: number = 20;
const P2_TYPE_INTERVAL_MS: number = 120;

/** 1920s 键带母版参数（keymap bands.phone 与母版尺寸）。 */
const KB_BAND_Y0: number = 704;
const KB_BAND_H: number = 975;
const KB_BAND_W: number = 2048;

/** 一帽（探针命中表）。 */
interface ProbeCap {
  label: string;
  x: number;
  y: number;
  row: number;
}

/** 一帧记录。 */
interface FrameRec {
  tMs: number;
  drawMs: number;
}

/** 面板按钮项。 */
interface ProbeAction {
  label: string;
  act: () => void;
}

@Component
export struct CanvasProbePage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 1000;
  onBack: () => void = (): void => {};

  // ---------------- Canvas ----------------
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @State boxW: number = 0;
  @State boxH: number = 0;
  @State cw: number = 0;
  @State ch: number = 0;
  @State canvasScale: number = 1;
  @State canvasX: number = 0;
  @State canvasY: number = 0;
  @State topInset: number = 0;
  @State bottomInset: number = 0;

  // ---------------- 面板与结果 ----------------
  @State panelOpen: boolean = false;
  /** P5：隐藏页内浮层（返回/标题/面板按钮/面板），让 screenCap 与组件快照内容可直接逐像素比对。 */
  @State chromeHidden: boolean = false;
  @State lines: string[] = [];
  @State p1Line: string = '';
  @State p6Line: string = '';
  @State p2Line: string = '';
  @State p2TypingLine: string = '';
  @State p3Line: string = '';
  @State p4Line: string = '';
  @State p5Line: string = '';
  @State phase: string = 'idle';

  // ---------------- 资源 ----------------
  private frontBitmap: ImageBitmap | null = null;
  private frontPixel: image.PixelMap | null = null;
  private staticBitmap: ImageBitmap | null = null;
  private paperBitmap: ImageBitmap | null = null;
  private caps: ProbeCap[] = [];
  private drawnMode: string = 'idle';

  // ---------------- P1 ----------------
  @State textRefVp: number = -1;

  // ---------------- P2 ----------------
  private anim: AnimatorResult | null = null;
  private frames: FrameRec[] = [];
  private frameStartMs: number = 0;
  private p2Mode: string = 'idle';
  private typedCount: number = 0;
  private nextTypeMs: number = 0;
  private carriageO: number = 0;
  private paperShift: number = 0;
  private leverAngle: number = 0;

  // ---------------- P3 ----------------
  private rectX: number = 0;
  private rectY: number = 0;
  private rectW: number = 0;
  private rectH: number = 0;
  private capsLogged: boolean = false;
  private leverDragActive: boolean = false;
  private leverMoveCount: number = 0;
  private leverTouchMs: number = 0;
  private leverFrameMs: number = 0;
  private leverFrameAngle: number = 0;

  // ---------------- P4 ----------------
  @State imeMode: string = 'unset';
  private areaBeforeW: number = 0;
  private areaBeforeH: number = 0;

  // ---------------- P5 ----------------
  private snapBytes: Uint8Array = new Uint8Array(0);

  aboutToAppear(): void {
    this.log('probe page appear');
    applyImmersive(this.getUIContext()).then((ins: Insets) => {
      this.topInset = ins.top;
      this.bottomInset = ins.bottom;
      this.log('probe insets top=' + ins.top.toFixed(1) + ' bottom=' + ins.bottom.toFixed(1));
      if (this.boxW > 0) {
        this.layoutCanvas(this.boxW, Math.max(1, this.boxH - ins.top - ins.bottom));
        setTimeout(() => { this.refreshRect(); }, 60);
      }
    }).catch(() => {});
  }

  aboutToDisappear(): void {
    if (this.anim !== null) {
      try {
        this.anim.cancel();
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'anim cancel failed');
      }
      this.anim = null;
    }
  }

  // ---------------- 基础设施 ----------------
  private log(line: string): void {
    hilog.info(DOMAIN, TAG, '%{public}s', line);
    const next: string[] = this.lines.slice();
    next.push(line);
    while (next.length > 40) {
      next.shift();
    }
    this.lines = next;
  }

  private host(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext;
  }

  private vp2px(): number {
    return this.getUIContext().vp2px(1);
  }

  /** Area 的 width/height 是 Length（vp 数值或字符串），统一转 number。 */
  private toNum(v: Length): number {
    if (typeof v === 'number') {
      return v as number;
    }
    if (typeof v === 'string') {
      return Number.parseFloat(v as string);
    }
    return 0;
  }

  private errText(e: BusinessError): string {
    return 'code=' + (e.code === undefined ? '?' : e.code.toString()) +
      ' msg=' + (e.message === undefined ? '?' : e.message);
  }

  private layoutCanvas(areaW: number, areaH: number): void {
    const s: number = Math.min(areaW / REF_W, areaH / REF_H, 1.0);
    this.canvasScale = s;
    this.cw = REF_W * s;
    this.ch = REF_H * s;
    this.canvasX = (areaW - this.cw) / 2;
    this.canvasY = this.topInset;
    this.log('probe layout area=' + areaW.toFixed(1) + 'x' + areaH.toFixed(1) +
      ' scale=' + s.toFixed(4) + ' canvas=' + this.cw.toFixed(1) + 'x' + this.ch.toFixed(1));
  }

  private refreshRect(): void {
    try {
      const info = this.getUIContext().getComponentUtils().getRectangleById('probe__canvas');
      this.rectX = info.screenOffset.x;
      this.rectY = info.screenOffset.y;
      this.rectW = info.size.width;
      this.rectH = info.size.height;
      this.log('probe rect px x=' + this.rectX.toFixed(2) + ' y=' + this.rectY.toFixed(2) +
        ' w=' + this.rectW.toFixed(2) + ' h=' + this.rectH.toFixed(2) +
        ' vp2px=' + this.vp2px().toFixed(3));
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      this.log('probe rect failed: ' + this.errText(err));
    }
  }

  // ---------------- 绘制 ----------------
  private drawIdle(): void {
    const ctx: CanvasRenderingContext2D = this.ctx;
    ctx.clearRect(0, 0, this.cw, this.ch);
    ctx.fillStyle = '#241c16';
    ctx.fillRect(0, 0, this.cw, this.ch);
    ctx.fillStyle = '#dbccb3';
    ctx.font = '14vp sans-serif';
    ctx.fillText('probe ready · scale=' + this.canvasScale.toFixed(3), 16, 32);
    ctx.fillStyle = '#6b6055';
    ctx.font = '12vp sans-serif';
    ctx.fillText('P1 字体 / P6 取图 / P2 帧率 / P3 触摸 / P4 输入 / P5 取证（右上角「探针面板」）', 16, 56);
    this.drawnMode = 'idle';
  }

  private canvasReady(): void {
    this.drawIdle();
    setTimeout(() => { this.refreshRect(); }, 60);
    this.log('probe canvas onReady cw=' + this.cw.toFixed(1) + ' ch=' + this.ch.toFixed(1));
  }

  // ---------------- P6 ----------------
  private copyRawToSandbox(rawPath: string, fileName: string): string {
    try {
      const rm = this.host().resourceManager;
      const bytes: Uint8Array = rm.getRawFileContentSync(rawPath);
      const ab: ArrayBuffer = new ArrayBuffer(bytes.length);
      const view: Uint8Array = new Uint8Array(ab);
      for (let i = 0; i < bytes.length; i++) {
        view[i] = bytes[i];
      }
      const filePath: string = this.host().filesDir + '/' + fileName;
      const f: fs.File = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(f.fd, ab);
      } finally {
        fs.closeSync(f);
      }
      this.log('P6 sandbox copy ok path=' + filePath + ' bytes=' + bytes.length.toString());
      return filePath;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      this.log('P6 sandbox copy failed: ' + this.errText(err));
      return '';
    }
  }

  private async decodeRawToPixel(rawPath: string): Promise<image.PixelMap | null> {
    try {
      const bytes: Uint8Array = this.host().resourceManager.getRawFileContentSync(rawPath);
      const ab: ArrayBuffer = new ArrayBuffer(bytes.length);
      const view: Uint8Array = new Uint8Array(ab);
      for (let i = 0; i < bytes.length; i++) {
        view[i] = bytes[i];
      }
      const src: image.ImageSource = image.createImageSource(ab);
      const pm: image.PixelMap = await src.createPixelMap();
      this.log('P6 decode ok raw=' + rawPath);
      return pm;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      this.log('P6 decode failed raw=' + rawPath + ' ' + this.errText(err));
      return null;
    }
  }

  private async runP6(): Promise<void> {
    this.phase = 'P6';
    this.log('P6 start');
    // 取法 1：rawfile → 沙箱文件 → new ImageBitmap(src) 直接构造
    const path: string = this.copyRawToSandbox('machine/1920s-upright-front.jpg', 'probe-machine.jpg');
    if (path.length > 0) {
      try {
        this.frontBitmap = new ImageBitmap(path);
        this.log('P6 ImageBitmap ok src=' + path);
      } catch (e) {
        const err: BusinessError = e as BusinessError;
        this.log('P6 ImageBitmap failed: ' + this.errText(err));
      }
    }
    // 取法 2：rawfile → ImageSource → PixelMap → drawImage(PixelMap)
    this.frontPixel = await this.decodeRawToPixel('machine/1920s-upright-keyband-phone.jpg');
    if (this.frontPixel !== null) {
      const pi = this.frontPixel.getImageInfoSync();
      this.log('P6 PixelMap ok size=' + pi.size.width.toString() + 'x' + pi.size.height.toString());
    }
    const ctx: CanvasRenderingContext2D = this.ctx;
    ctx.clearRect(0, 0, this.cw, this.ch);
    ctx.fillStyle = '#241c16';
    ctx.fillRect(0, 0, this.cw, this.ch);
    let okCount: number = 0;
    if (this.frontBitmap !== null) {
      const h: number = this.ch / 2;
      const w: number = Math.min(this.cw, h * (2048 / 975));
      ctx.drawImage(this.frontBitmap, (this.cw - w) / 2, 0, w, h);
      okCount++;
    }
    if (this.frontPixel !== null) {
      const h: number = this.ch / 2;
      const w: number = Math.min(this.cw, h * (2048 / 975));
      ctx.drawImage(this.frontPixel, (this.cw - w) / 2, this.ch / 2, w, h);
      okCount++;
    }
    ctx.fillStyle = '#dbccb3';
    ctx.font = '13vp sans-serif';
    ctx.fillText('P6: ImageBitmap(top) + PixelMap(bottom) ok=' + okCount.toString() + '/2', 12, 20);
    this.drawnMode = 'p6';
    this.p6Line = 'P6 images=' + okCount.toString() + '/2';
    this.log('PROBE P6 ok=' + okCount.toString() + '/2');
    this.phase = 'idle';
  }

  // ---------------- P1 ----------------
  private runP1(): void {
    this.phase = 'P1';
    this.log('P1 start');
    const ctx: CanvasRenderingContext2D = this.ctx;
    ctx.clearRect(0, 0, this.cw, this.ch);
    ctx.fillStyle = '#eee4ce';
    ctx.fillRect(0, 0, this.cw, this.ch);
    ctx.fillStyle = '#1a1a1a';
    ctx.font = P1_FONT_VP.toString() + 'vp CourierPrime';
    const wC: number = ctx.measureText(P1_STR).width;
    ctx.fillText(P1_STR, 16, 60);
    ctx.font = P1_FONT_VP.toString() + 'vp sans-serif';
    const wS: number = ctx.measureText(P1_STR).width;
    ctx.fillText(P1_STR, 16, 120);
    ctx.font = '12vp sans-serif';
    ctx.fillStyle = '#2a231d';
    ctx.fillText('CourierPrime 宽=' + wC.toFixed(2), 16, 170);
    ctx.fillText('sans-serif  宽=' + wS.toFixed(2), 16, 190);
    ctx.fillText('隐藏 Text 参照=' + this.textRefVp.toFixed(2) + 'vp', 16, 210);
    const diff: number = Math.abs(wC - wS);
    const v2p: number = this.vp2px();
    const dVp: number = Math.abs(wC - this.textRefVp);
    const dPx: number = Math.abs(wC / v2p - this.textRefVp);
    const unitVp: boolean = dVp <= dPx;
    const refDelta: number = Math.min(dVp, dPx);
    this.p1Line = 'P1 wC=' + wC.toFixed(2) + ' wS=' + wS.toFixed(2) + ' diff=' + diff.toFixed(2) +
      ' ref=' + this.textRefVp.toFixed(2) + ' refDelta=' + refDelta.toFixed(2) +
      ' unit=' + (unitVp ? 'vp' : 'px');
    this.log('PROBE P1 ' + this.p1Line);
    this.drawnMode = 'p1';
    this.phase = 'idle';
  }

  // ---------------- P2 ----------------
  private ensureLayers(): void {
    if (this.staticBitmap === null) {
      const off: OffscreenCanvas = new OffscreenCanvas(Math.round(this.cw), Math.round(this.ch));
      const octx: OffscreenCanvasRenderingContext2D = off.getContext('2d');
      octx.fillStyle = '#241c16';
      octx.fillRect(0, 0, this.cw, this.ch);
      if (this.frontBitmap !== null) {
        const h: number = this.ch * 0.62;
        const w: number = Math.min(this.cw, h * (2048 / 975));
        octx.drawImage(this.frontBitmap, (this.cw - w) / 2, 0, w, h);
      }
      if (this.frontPixel !== null) {
        const kh: number = this.cw / 2.1;
        octx.drawImage(this.frontPixel, 0, this.ch - kh, this.cw, kh);
      }
      this.staticBitmap = off.transferToImageBitmap();
      this.log('P2 static layer built');
    }
    if (this.paperBitmap === null) {
      const off: OffscreenCanvas = new OffscreenCanvas(Math.round(this.cw), Math.round(this.ch));
      const octx: OffscreenCanvasRenderingContext2D = off.getContext('2d');
      const pw: number = this.cw * 0.66;
      const ph: number = this.ch * 0.62;
      const px: number = (this.cw - pw) / 2;
      octx.fillStyle = '#f4ecd8';
      octx.fillRect(px, 0, pw, ph);
      octx.fillStyle = '#2a231d';
      octx.font = '12vp CourierPrime';
      octx.fillText('Hello, World! 0123456789', px + 20, 40);
      octx.fillText('probe paper bitmap', px + 20, 64);
      octx.fillText('line 3', px + 20, 88);
      this.paperBitmap = off.transferToImageBitmap();
      this.log('P2 paper layer built');
    }
  }

  private drawDynFrame(): void {
    const t0: number = Date.now();
    const ctx: CanvasRenderingContext2D = this.ctx;
    ctx.clearRect(0, 0, this.cw, this.ch);
    if (this.staticBitmap !== null) {
      ctx.drawImage(this.staticBitmap, 0, 0);
    }
    if (this.paperBitmap !== null) {
      ctx.drawImage(this.paperBitmap, 0, this.paperShift);
    }
    const chRef: number = 75.6 * this.canvasScale;
    ctx.fillStyle = '#2b2621';
    ctx.fillRect(this.cw * 0.12 + this.carriageO * this.canvasScale, 0, this.cw * 0.76, chRef);
    ctx.save();
    ctx.translate(this.cw * 0.9, this.ch * 0.62);
    ctx.rotate(this.leverAngle * Math.PI / 180);
    ctx.fillStyle = '#c9a45c';
    ctx.fillRect(-2, 0, 4, this.ch * 0.25);
    ctx.restore();
    this.leverFrameAngle = this.leverAngle;
    this.leverFrameMs = Date.now();
    const drawMs: number = Date.now() - t0;
    this.frames.push({ tMs: Date.now(), drawMs: drawMs });
    if (this.p2Mode === 'typing') {
      const now: number = Date.now() - this.frameStartMs;
      while (this.typedCount < P2_TYPE_CHARS && now >= this.nextTypeMs) {
        this.typedCount++;
        this.nextTypeMs += P2_TYPE_INTERVAL_MS;
        this.carriageO = Math.max(-110, this.carriageO - 4.571);
      }
    }
  }

  private p2Start(mode: string): void {
    if (this.anim !== null) {
      try {
        this.anim.cancel();
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'old anim cancel failed');
      }
      this.anim = null;
    }
    this.frames = [];
    this.frameStartMs = Date.now();
    this.p2Mode = mode;
    this.typedCount = 0;
    this.nextTypeMs = P2_TYPE_INTERVAL_MS;
    this.carriageO = 0;
    this.paperShift = 0;
    this.leverAngle = 0;
    try {
      this.ensureLayers();
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      this.log('P2 layers failed: ' + this.errText(err));
    }
    const opt: AnimatorOptions = {
      duration: 1000000,
      easing: 'linear',
      delay: 0,
      fill: 'forwards',
      direction: 'normal',
      iterations: 1,
      begin: 0,
      end: 1,
    };
    const a: AnimatorResult = Animator.create(opt);
    this.anim = a;
    a.onFrame = (progress: number): void => {
      const elapsed: number = Date.now() - this.frameStartMs;
      if (mode === 'newline') {
        const leverT: number = Math.min(1, elapsed / 150);
        this.leverAngle = 35 * leverT;
        if (elapsed > 150 && elapsed <= 450) {
          this.paperShift = 40 * ((elapsed - 150) / 300);
        } else if (elapsed > 450) {
          this.paperShift = 0;
          this.carriageO = 0;
        }
      }
      this.drawDynFrame();
      if (mode === 'newline' && elapsed > 780) {
        this.p2Finish('newline');
      } else if (mode === 'typing' && this.typedCount >= P2_TYPE_CHARS &&
        elapsed > P2_TYPE_CHARS * P2_TYPE_INTERVAL_MS + 200) {
        this.p2Finish('typing');
      }
    };
    a.play();
    this.drawnMode = 'p2';
    this.phase = 'P2-' + mode;
    this.log('P2 start mode=' + mode);
  }

  private p2Finish(mode: string): void {
    if (this.anim !== null) {
      try {
        this.anim.cancel();
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'anim finish cancel failed');
      }
      this.anim = null;
    }
    this.p2Mode = 'idle';
    this.phase = 'idle';
    const n: number = this.frames.length;
    let sum: number = 0;
    let maxDraw: number = 0;
    const draws: number[] = [];
    for (let i = 0; i < n; i++) {
      const d: number = this.frames[i].drawMs;
      sum += d;
      draws.push(d);
      if (d > maxDraw) {
        maxDraw = d;
      }
    }
    draws.sort((a: number, b: number): number => a - b);
    const p95: number = n > 0 ? draws[Math.min(n - 1, Math.floor(n * 0.95))] : 0;
    const totalMs: number = n > 1 ? this.frames[n - 1].tMs - this.frames[0].tMs : 0;
    const fps: number = totalMs > 0 ? ((n - 1) * 1000) / totalMs : 0;
    const line: string = 'mode=' + mode + ' frames=' + n.toString() + ' fps=' + fps.toFixed(1) +
      ' avgDraw=' + (n > 0 ? (sum / n).toFixed(2) : '0') + 'ms p95Draw=' + p95.toFixed(2) +
      'ms maxDraw=' + maxDraw.toFixed(2) + 'ms typed=' + this.typedCount.toString() +
      '/' + P2_TYPE_CHARS.toString() + ' totalMs=' + totalMs.toFixed(0);
    this.log('PROBE P2 ' + line);
    if (mode === 'newline') {
      this.p2Line = 'P2 newline ' + line;
    } else {
      this.p2TypingLine = 'P2 typing ' + line;
    }
    this.runConsistency();
    this.drawSummary(line);
  }

  private runConsistency(): void {
    const s: number = this.canvasScale;
    const tablet: boolean = this.widthVp >= 600;
    const fsVp: number = tablet ? 24 : 17;
    const lh: number = fsVp * (30 / 17);
    const bandShift: number = tablet ? 15 : 0;
    const paperBandBase: number = 20 + lh + 44 + bandShift;
    const carriageTop: number = 403.2 * s;
    const paperTop: number = carriageTop - paperBandBase;
    const strikeLine: number = carriageTop - 20 - lh / 2 - bandShift;
    const paperBottom: number = paperTop + 628.7 * s;
    const baseLeft: number = (tablet ? 45.0 : 24.2) * s;
    const roll0: number = (tablet ? 103.5 : 55.7) * s;
    const rollClamp: number = (tablet ? 52.3 : 28.1) * s;
    const expPaperTop: number = tablet ? 281.8 : 123.0;
    const expCarriageTop: number = tablet ? 403.2 : 217.0;
    const dPaper: number = Math.abs(paperTop - expPaperTop);
    const dCarr: number = Math.abs(carriageTop - expCarriageTop);
    const inPaper: boolean = (paperTop < strikeLine) && (strikeLine < paperBottom);
    const crosses: boolean = (paperTop < carriageTop) && (carriageTop < paperBottom);
    const rollOk: boolean = roll0 >= baseLeft && rollClamp >= baseLeft;
    this.log('PROBE P2 consistency scale=' + s.toFixed(4) + ' fs=' + fsVp.toFixed(2) +
      ' lh=' + lh.toFixed(2) + ' paperTop=' + paperTop.toFixed(2) + ' carriageTop=' + carriageTop.toFixed(2) +
      ' strikeLine=' + strikeLine.toFixed(2) + ' dPaper=' + dPaper.toFixed(2) +
      ' dCarr=' + dCarr.toFixed(2) + ' inPaper=' + (inPaper ? '1' : '0') +
      ' crosses=' + (crosses ? '1' : '0') + ' rollOk=' + (rollOk ? '1' : '0'));
  }

  private drawSummary(line: string): void {
    const ctx: CanvasRenderingContext2D = this.ctx;
    ctx.fillStyle = 'rgba(36,28,22,0.82)';
    ctx.fillRect(0, this.ch - 96, this.cw, 96);
    ctx.fillStyle = '#dbccb3';
    ctx.font = '12vp CourierPrime';
    ctx.fillText('P2 ' + line, 12, this.ch - 66);
  }

  // ---------------- P3 ----------------
  private loadCaps(): void {
    try {
      const bytes: Uint8Array = this.host().resourceManager.getRawFileContentSync('keymap/1920s-upright-keymap.json');
      const text: string = this.utf8ToString(bytes);
      const raw: RawKeymap = JSON.parse(text) as RawKeymap;
      const kbTopRef: number = REF_H - (REF_W / 2.1);
      this.caps = [];
      for (let r = 0; r < raw.rows.length; r++) {
        const row: RawRow = raw.rows[r];
        for (let c = 0; c < row.caps.length; c++) {
          const cap: RawCap = row.caps[c];
          const cx: number = (cap.x / KB_BAND_W) * REF_W;
          const cy: number = kbTopRef + ((row.y - KB_BAND_Y0) / KB_BAND_H) * (REF_W / 2.1);
          this.caps.push({ label: cap.label, x: cx, y: cy, row: r });
        }
      }
      this.log('P3 caps loaded n=' + this.caps.length.toString());
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      this.log('P3 loadCaps failed: ' + this.errText(err));
    }
  }

  private utf8ToString(bytes: Uint8Array): string {
    let out: string = '';
    let i: number = 0;
    while (i < bytes.length) {
      const c: number = bytes[i];
      if (c < 0x80) {
        out += String.fromCharCode(c);
        i += 1;
      } else if (c < 0xE0 && i + 1 < bytes.length) {
        out += String.fromCharCode(((c & 0x1F) << 6) | (bytes[i + 1] & 0x3F));
        i += 2;
      } else if (c < 0xF0 && i + 2 < bytes.length) {
        out += String.fromCharCode(((c & 0x0F) << 12) | ((bytes[i + 1] & 0x3F) << 6) | (bytes[i + 2] & 0x3F));
        i += 3;
      } else if (i + 3 < bytes.length) {
        const cp: number = ((c & 0x07) << 18) | ((bytes[i + 1] & 0x3F) << 12) |
          ((bytes[i + 2] & 0x3F) << 6) | (bytes[i + 3] & 0x3F);
        out += String.fromCharCode(0xD800 + ((cp - 0x10000) >> 10), 0xDC00 + ((cp - 0x10000) & 0x3FF));
        i += 4;
      } else {
        break;
      }
    }
    return out;
  }

  private runP3Draw(): void {
    this.phase = 'P3';
    if (this.caps.length === 0) {
      this.loadCaps();
    }
    this.refreshRect();
    const ctx: CanvasRenderingContext2D = this.ctx;
    ctx.clearRect(0, 0, this.cw, this.ch);
    ctx.fillStyle = '#241c16';
    ctx.fillRect(0, 0, this.cw, this.ch);
    const kh: number = this.cw / 2.1;
    const top: number = this.ch - kh;
    if (this.frontPixel !== null) {
      ctx.drawImage(this.frontPixel, 0, top, this.cw, kh);
    } else {
      ctx.fillStyle = '#3a322a';
      ctx.fillRect(0, top, this.cw, kh);
    }
    ctx.strokeStyle = '#c9a45c';
    ctx.lineWidth = 1;
    for (let i = 0; i < this.caps.length; i++) {
      ctx.beginPath();
      ctx.arc(this.caps[i].x * this.canvasScale, this.caps[i].y * this.canvasScale, 3, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.fillStyle = 'rgba(201,164,92,0.12)';
    ctx.fillRect(this.cw * 0.78, top, this.cw * 0.22, kh);
    if (!this.capsLogged) {
      this.capsLogged = true;
      const v2p: number = this.vp2px();
      const list: string[] = [];
      for (let i = 0; i < this.caps.length; i++) {
        const sx: number = this.rectX + this.caps[i].x * this.canvasScale * v2p;
        const sy: number = this.rectY + this.caps[i].y * this.canvasScale * v2p;
        list.push(this.caps[i].label + ':' + this.caps[i].row.toString() + ':' +
          sx.toFixed(1) + ':' + sy.toFixed(1));
      }
      this.log('PROBE P3 caps=' + this.caps.length.toString());
      this.log('PROBE P3 coords ' + list.join(';'));
    }
    this.p3Line = 'P3 caps=' + this.caps.length.toString() + ' · 逐帽点按 3 次';
    this.drawnMode = 'p3';
    this.phase = 'idle';
  }

  /** P3 动态帧：键带 + 帽心点 + 拨杆（按 leverAngle 旋转，跟手可视证据）。 */
  private drawP3Frame(): void {
    const ctx: CanvasRenderingContext2D = this.ctx;
    const t0: number = Date.now();
    ctx.clearRect(0, 0, this.cw, this.ch);
    ctx.fillStyle = '#241c16';
    ctx.fillRect(0, 0, this.cw, this.ch);
    const kh: number = this.cw / 2.1;
    const top: number = this.ch - kh;
    if (this.frontPixel !== null) {
      ctx.drawImage(this.frontPixel, 0, top, this.cw, kh);
    } else {
      ctx.fillStyle = '#3a322a';
      ctx.fillRect(0, top, this.cw, kh);
    }
    ctx.strokeStyle = '#c9a45c';
    ctx.lineWidth = 1;
    for (let i = 0; i < this.caps.length; i++) {
      ctx.beginPath();
      ctx.arc(this.caps[i].x * this.canvasScale, this.caps[i].y * this.canvasScale, 3, 0, Math.PI * 2);
      ctx.stroke();
    }
    // 拨杆（右侧竖条，绕支点旋转）
    ctx.save();
    ctx.translate(this.cw * 0.9, this.ch * 0.62);
    ctx.rotate(this.leverAngle * Math.PI / 180);
    ctx.fillStyle = '#c9a45c';
    ctx.fillRect(-3, 0, 6, this.ch * 0.22);
    ctx.restore();
    // 拨杆区底色
    ctx.fillStyle = 'rgba(201,164,92,0.10)';
    ctx.fillRect(this.cw * 0.78, top, this.cw * 0.22, kh);
    this.leverFrameAngle = this.leverAngle;
    this.leverFrameMs = Date.now();
    const drawMs: number = Date.now() - t0;
    this.log('PROBE P3 frame angle=' + this.leverAngle.toFixed(1) + ' drawMs=' + drawMs.toString());
  }

  /** 指针 y → 摆角（0..35°）：支点 y = ch*0.62，行程 = ch*0.2。 */
  private leverAngleFromY(y: number): number {
    const startY: number = this.ch * 0.62;
    const dy: number = y - startY;
    const a: number = (dy / (this.ch * 0.2)) * 35;
    return Math.max(0, Math.min(35, a));
  }

  private hitCap(localX: number, localY: number): ProbeCap | null {
    const rx: number = localX / this.canvasScale;
    const ry: number = localY / this.canvasScale;
    let best: ProbeCap | null = null;
    let bestD: number = 1e9;
    for (let i = 0; i < this.caps.length; i++) {
      const dx: number = rx - this.caps[i].x;
      const dy: number = ry - this.caps[i].y;
      const d: number = Math.sqrt(dx * dx + dy * dy);
      if (d <= 44.4 && d < bestD) {
        bestD = d;
        best = this.caps[i];
      }
    }
    return best;
  }

  private onCanvasTouch(e: TouchEvent): void {
    if (this.drawnMode !== 'p3' || e.touches.length === 0) {
      return;
    }
    const first: TouchObject = e.touches[0];
    const inLever: boolean = first.x > this.cw * 0.78;
    if (e.type === TouchType.Down) {
      for (let i = 0; i < e.touches.length; i++) {
        const x: number = e.touches[i].x;
        const y: number = e.touches[i].y;
        const cap: ProbeCap | null = this.hitCap(x, y);
        if (cap === null) {
          this.log('PROBE P3 touch miss x=' + x.toFixed(1) + ' y=' + y.toFixed(1));
          this.p3Line = 'P3 miss x=' + x.toFixed(1) + ' y=' + y.toFixed(1);
        } else {
          this.log('PROBE P3 touch hit=' + cap.label + '@' + cap.row.toString() +
            ' x=' + x.toFixed(1) + ' y=' + y.toFixed(1) + ' pointers=' + e.touches.length.toString());
          this.p3Line = 'P3 hit ' + cap.label + '@' + cap.row.toString() +
            ' pointers=' + e.touches.length.toString();
        }
      }
      if (inLever) {
        this.leverDragActive = true;
        this.leverMoveCount = 0;
        this.leverTouchMs = Date.now();
        this.leverAngle = this.leverAngleFromY(first.y);
        this.drawP3Frame();
        this.log('PROBE P3 lever drag start y=' + first.y.toFixed(1) +
          ' angle=' + this.leverAngle.toFixed(1));
      }
    } else if (e.type === TouchType.Move && this.leverDragActive) {
      this.leverMoveCount++;
      this.leverAngle = this.leverAngleFromY(first.y);
      this.drawP3Frame();
      this.leverTouchMs = Date.now();
    } else if ((e.type === TouchType.Up || e.type === TouchType.Cancel) && this.leverDragActive) {
      this.leverDragActive = false;
      this.drawP3Frame();
      const dAngle: number = Math.abs(this.leverAngle - this.leverFrameAngle);
      const dMs: number = this.leverFrameMs - this.leverTouchMs;
      this.log('PROBE P3 lever drag end angle=' + this.leverAngle.toFixed(1) +
        ' drawnAngle=' + this.leverFrameAngle.toFixed(1) +
        ' dAngle=' + dAngle.toFixed(2) + ' moves=' + this.leverMoveCount.toString() +
        ' touchToFrameMs=' + dMs.toString());
    }
  }

  // ---------------- P4 ----------------
  private async runP4(mode: string): Promise<void> {
    this.phase = 'P4';
    this.refreshRect();
    this.log('P4 start mode=' + mode);
    try {
      const win: window.Window = await window.getLastWindow(this.host());
      const ui: UIContext = this.getUIContext();
      if (mode === 'RESIZE') {
        ui.setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
      } else {
        ui.setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET);
      }
      const cur = ui.getKeyboardAvoidMode();
      this.imeMode = (mode === 'RESIZE' ? 'RESIZE' : 'OFFSET') + '/' +
        (cur === KeyboardAvoidMode.RESIZE ? 'RESIZE' : 'OFFSET');
      this.areaBeforeW = this.boxW;
      this.areaBeforeH = this.boxH;
      const wp = win.getWindowProperties();
      this.log('PROBE P4 mode=' + this.imeMode + ' before=' + this.boxW.toFixed(1) + 'x' +
        this.boxH.toFixed(1) + ' win=' + wp.windowRect.width.toString() + 'x' +
        wp.windowRect.height.toString());
      const tablet: boolean = this.widthVp >= 600;
      const lh: number = (tablet ? 24 : 17) * (30 / 17);
      const paperTop: number = (403.2 * this.canvasScale) - (20 + lh + 44 + (tablet ? 15 : 0));
      const refX: number = REF_W * 0.5;
      const refY: number = Math.max(paperTop, 0) + 20 + 2;
      const v2p: number = this.vp2px();
      const px: number = this.rectX + refX * this.canvasScale * v2p;
      const py: number = this.rectY + refY * this.canvasScale * v2p;
      const dPaper: number = Math.abs(paperTop - 281.8);
      this.log('PROBE P4 cursor ref=' + refX.toFixed(1) + ',' + refY.toFixed(1) +
        ' px=' + px.toFixed(1) + ',' + py.toFixed(1) +
        ' scale=' + this.canvasScale.toFixed(4) + ' rectX=' + this.rectX.toFixed(1) +
        ' paperTopRef=' + paperTop.toFixed(2) + ' dPaperRef=' + dPaper.toFixed(2));
      this.getUIContext().getFocusController().requestFocus('probe__ime');
      this.log('PROBE P4 focus requested');
      setTimeout(() => {
        try {
          const avoid: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_KEYBOARD);
          const kbHpx: number = avoid.bottomRect.height;
          const winHpx: number = wp.windowRect.height;
          const v2p: number = this.vp2px();
          const canvasBottomPx: number = this.rectY + this.ch * v2p;
          const kbTopPx: number = winHpx - kbHpx;
          const overlapPx: number = canvasBottomPx - kbTopPx;
          const areaNow: number = this.boxH;
          this.log('PROBE P4 keyboard mode=' + this.imeMode + ' kbHpx=' + kbHpx.toFixed(1) +
            ' winHpx=' + winHpx.toString() + ' canvasBottomPx=' + canvasBottomPx.toFixed(1) +
            ' kbTopPx=' + kbTopPx.toFixed(1) + ' overlapPx=' + overlapPx.toFixed(1) +
            ' overlapVp=' + (overlapPx / v2p).toFixed(2) + ' areaNow=' + areaNow.toFixed(1) +
            ' paperTopRef=281.8(expect 281.8±2) cursorPx=' + this.rectY + '+' + (this.ch * v2p).toFixed(0));
        } catch (e) {
          const err: BusinessError = e as BusinessError;
          this.log('PROBE P4 avoid read failed: ' + this.errText(err));
        }
      }, 900);
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      this.log('P4 failed: ' + this.errText(err));
    }
    this.phase = 'idle';
  }

  private onRootArea(w: number, h: number): void {
    this.boxW = w;
    this.boxH = h;
    if (w > 0 && h > 0) {
      this.layoutCanvas(w, Math.max(1, h - this.topInset - this.bottomInset));
    }
    if (this.areaBeforeW > 0 &&
      (Math.abs(w - this.areaBeforeW) > 1 || Math.abs(h - this.areaBeforeH) > 1)) {
      this.log('PROBE P4 area=' + w.toFixed(1) + 'x' + h.toFixed(1) +
        ' delta=' + (w - this.areaBeforeW).toFixed(1) + 'x' + (h - this.areaBeforeH).toFixed(1) +
        ' mode=' + this.imeMode);
      this.areaBeforeW = w;
      this.areaBeforeH = h;
    } else {
      this.log('PROBE P4 area=' + w.toFixed(1) + 'x' + h.toFixed(1) + ' mode=' + this.imeMode);
    }
  }

  // ---------------- P5 ----------------
  private async runP5(): Promise<void> {
    this.phase = 'P5';
    this.panelOpen = false;
    this.chromeHidden = true;
    this.log('P5 start (chrome hidden)');
    this.refreshRect();
    const v2p: number = this.vp2px();
    const tx: number = this.boxW > 0 ? (this.boxW - this.cw) / 2 : this.canvasX;
    this.log('PROBE P5 matrix tx=' + tx.toFixed(2) + ' ty=' + this.canvasY.toFixed(2) +
      ' w=' + (this.cw * v2p).toFixed(2) + ' h=' + (this.ch * v2p).toFixed(2) +
      ' rect=' + this.rectX.toFixed(2) + ',' + this.rectY.toFixed(2) + ',' +
      this.rectW.toFixed(2) + ',' + this.rectH.toFixed(2) +
      ' dW=' + Math.abs(this.rectW - this.cw * v2p).toFixed(2) +
      ' dH=' + Math.abs(this.rectH - this.ch * v2p).toFixed(2));
    let pm: image.PixelMap | null = null;
    for (let i = 0; i < 3 && pm === null; i++) {
      try {
        pm = await this.getUIContext().getComponentSnapshot().get('probe__canvas');
        this.log('PROBE P5 snapshot ok try=' + (i + 1).toString());
      } catch (e) {
        const err: BusinessError = e as BusinessError;
        this.log('PROBE P5 snapshot failed try=' + (i + 1).toString() + ' ' + this.errText(err));
      }
    }
    if (pm === null) {
      this.p5Line = 'P5 snapshot failed 3x';
      this.log('PROBE P5 FAILED snapshot 3x');
      this.phase = 'idle';
      return;
    }
    const pi = pm.getImageInfoSync();
    this.log('PROBE P5 snapshot size=' + pi.size.width.toString() + 'x' + pi.size.height.toString());
    try {
      const packer: image.ImagePacker = image.createImagePacker();
      const bytes: ArrayBuffer = await packer.packToData(pm, { format: 'image/png', quality: 100 });
      this.snapBytes = new Uint8Array(bytes);
      this.log('PROBE P5 snapshot png bytes=' + this.snapBytes.length.toString());
      const b64: string = new util.Base64Helper().encodeToStringSync(this.snapBytes);
      const chunk: number = 1800;
      const total: number = Math.ceil(b64.length / chunk);
      this.log('PROBE P5 b64 begin len=' + b64.length.toString() + ' chunks=' + total.toString());
      for (let i = 0; i < total; i++) {
        hilog.info(DOMAIN, TAG, 'PROBE P5 b64 %{public}s/%{public}s: %{public}s',
          (i + 1).toString(), total.toString(),
          b64.substring(i * chunk, Math.min(b64.length, (i + 1) * chunk)));
      }
      this.log('PROBE P5 b64 end');
      this.p5Line = 'P5 snapshot ' + pi.size.width.toString() + 'x' + pi.size.height.toString() +
        ' bytes=' + this.snapBytes.length.toString();
      pm.release();
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      this.log('P5 pack failed: ' + this.errText(err));
      this.p5Line = 'P5 pack failed';
    }
    this.phase = 'idle';
  }

  private runP5Transition(): void {
    this.log('PROBE P5 transition start');
    animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
      this.canvasX = -this.cw;
    });
    setTimeout(() => {
      animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
        this.canvasX = (this.boxW - this.cw) / 2;
      });
      this.log('PROBE P5 transition end');
    }, 300);
  }

  // ---------------- UI ----------------
  private actions(): ProbeAction[] {
    return [
      { label: 'P1 字体', act: (): void => { this.runP1(); } },
      { label: 'P6 取图', act: (): void => { this.runP6(); } },
      { label: 'P2 换行', act: (): void => { this.p2Start('newline'); } },
      { label: 'P2 落字', act: (): void => { this.p2Start('typing'); } },
      { label: 'P3 画键帽', act: (): void => { this.runP3Draw(); } },
      { label: 'P4 RESIZE', act: (): void => { this.runP4('RESIZE'); } },
      { label: 'P4 OFFSET', act: (): void => { this.runP4('OFFSET'); } },
      { label: 'P5 取证', act: (): void => { this.runP5(); } },
      { label: 'P5 转场', act: (): void => { this.runP5Transition(); } },
      { label: '清屏', act: (): void => { this.drawIdle(); } },
    ];
  }

  @Builder
  panel() {
    Column() {
      Text('Canvas Phase 0 探针（临时件）').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#dbccb3')
      Text('数值见 hilog TAG=CanvasProbe').fontSize(11).fontColor('rgba(232,221,201,0.6)')
        .margin({ top: 2 })
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.actions(), (a: ProbeAction) => {
          Text(a.label)
            .fontSize(13).fontColor('#e8ddc9')
            .height(34).padding({ left: 10, right: 10 })
            .borderRadius(8).backgroundColor('#2e2620')
            .margin({ right: 8, bottom: 8 })
            .onClick(() => { a.act(); })
        }, (a: ProbeAction) => a.label)
      }
      .width('100%').margin({ top: 10 })
      Text(this.p1Line).fontSize(11).fontColor('#c9a45c')
      Text(this.p6Line).fontSize(11).fontColor('#c9a45c')
      Text(this.p2Line).fontSize(11).fontColor('#c9a45c')
      Text(this.p2TypingLine).fontSize(11).fontColor('#c9a45c')
      Text(this.p3Line).fontSize(11).fontColor('#c9a45c')
      Text(this.p4Line).fontSize(11).fontColor('#c9a45c')
      Text(this.p5Line).fontSize(11).fontColor('#c9a45c')
      Scroll() {
        Column() {
          ForEach(this.lines, (l: string, i: number) => {
            Text(l).fontSize(10).fontColor('rgba(232,221,201,0.7)').width('100%')
          }, (l: string, i: number) => i.toString() + ':' + l.substring(0, Math.min(10, l.length)))
        }
        .width('100%').alignItems(HorizontalAlign.Start)
      }
      .height(110).width('100%').margin({ top: 6 })
    }
    .padding(14)
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('rgba(20,15,12,0.94)')
    .borderRadius(14)
  }


  @Builder
  pageBody() {
        Stack({ alignContent: Alignment.TopStart }) {
          Column()
            .width('100%')
            .height('100%')
            .onAreaChange((o: Area, n: Area) => {
              this.onRootArea(this.toNum(n.width), this.toNum(n.height));
            })

          Canvas(this.ctx)
            .id('probe__canvas')
            .width(this.cw > 0 ? this.cw : 1)
            .height(this.ch > 0 ? this.ch : 1)
            .position({ x: this.canvasX, y: this.canvasY })
            .onReady(() => { this.canvasReady(); })
            .onTouch((e: TouchEvent) => { this.onCanvasTouch(e); })

          Text(P1_STR)
            .fontSize(P1_FONT_VP).fontFamily('CourierPrime').maxLines(1).opacity(0)
            .position({ x: 0, y: 0 })
            .onAreaChange((o: Area, n: Area) => {
              this.textRefVp = this.toNum(n.width);
              this.log('PROBE P1 textRef vp=' + this.textRefVp.toFixed(2) +
                ' h=' + this.toNum(n.height).toFixed(2));
            })

          TextInput({ placeholder: '' })
            .id('probe__ime')
            .width(120).height(36).opacity(0.01)
            .position({ x: 8, y: this.boxH - 44 })

          if (!this.chromeHidden) {
            Text(this.panelOpen ? '收起' : '探针面板')
            .fontSize(12).fontColor('#e8ddc9')
            .height(32).padding({ left: 12, right: 12 })
            .borderRadius(16).backgroundColor('#2e2620')
            .position({ x: this.boxW > 100 ? this.boxW - 96 : 8, y: this.topInset + 8 })
              .onClick(() => { this.panelOpen = !this.panelOpen; })
          }

          if (this.panelOpen) {
            Scroll() {
              this.panel()
            }
            .width('100%')
            .constraintSize({ maxHeight: this.boxH * 0.74 })
            .position({ x: 0, y: this.topInset + 48 })
          }
        }
        .width('100%')
        .height('100%')
      }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 全屏探针画布区（沉浸式：顶距 = topInset，§1.4 ty = topInset）
      Column()
        .width('100%').height('100%')
        .padding({ top: this.topInset, bottom: this.bottomInset })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        .onAreaChange((o: Area, n: Area) => {
          this.onRootArea(this.toNum(n.width), this.toNum(n.height));
        })

      this.pageBody()

      // 顶部返回（图标用 SymbolGlyph 封装；图标铁律）；P5 取证时隐藏
      if (!this.chromeHidden) {
        Row() {
          AppIcon({ kind: 'back', iconSize: 24, color: '#e8ddc9' })
        }
        .width(44).height(44)
        .borderRadius(22).backgroundColor('rgba(20,15,12,0.55)')
        .position({ x: 8, y: this.topInset + 4 })
        .onClick(() => { this.onBack(); })

        Text('Canvas 探针').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#dbccb3')
          .position({ x: 64, y: this.topInset + 14 })
      }
    }
    .width('100%').height('100%')
  }
}

/** keymap JSON 最小结构（探针只用 x／y／label）。 */
interface RawCap {
  x: number;
  label: string;
}

interface RawRow {
  y: number;
  caps: RawCap[];
}

interface RawKeymap {
  rows: RawRow[];
}
