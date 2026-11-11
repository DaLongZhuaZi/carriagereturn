/**
 * 回车 · 导出页（§6.2）+ 沉浸式（§2.10）
 *
 * 第 3 批（F4 文件保存与分享＋F16 导出模板）：
 *   - 顶部纸面预览（高 480vp、圆角 12、不可点）＋三行格式（行高 110vp）；
 *   - 底部**双按钮**：保存到本地（主）／分享（次），高 56vp、圆角 28、左右边距 20vp；
 *   - 状态机 idle → building → saving|sharing → result，失败进 error，空文档进 empty；
 *   - 进度浮层：生成 <300ms 不显示；一旦显示最少展示 300ms（ExportCore.EXPORT_PROGRESS_MIN_MS）；
 *   - 结果态**常驻不淡出**（EXPORT_RESULT_FADE_MS = 0），文案到“已调起分享”为止；
 *   - busy（building/saving/sharing）时返回不响应；
 *   - 分享临时文件落 filesDir/export-tmp/，aboutToDisappear 统一清理。
 *
 * 文案一律 `$r('app.string.export_*')`（格式名/说明也在 string.json，不硬编码中文）。
 * 服务边界：字节构建＝ExportService，选位置写盘＝FileHelper.saveBytes（返回 SaveResult），
 * 分享＝ShareService（唯一入口），本页只做编排与状态。
 */

import { PageShell } from './PageShell';
import { AppIcon } from './AppIcon';
import { DocData } from '../model/DocModel';
import { docStore } from '../services/DocStore';
import { ExportService } from '../services/ExportService';
import { FileHelper } from '../services/FileHelper';
import { ShareService, ShareResult } from '../services/ShareService';
import { ExportTemplate } from './ExportTemplate';
import { EXPORT_TEMPLATE_W, EXPORT_TEMPLATE_H } from '../model/ExportCore';
import { SpotlightStep } from './SpotlightOverlay';
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { UIContext } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  ExportResult, SaveResult, safeFileName, resultText, machineTitleKey,
  EXPORT_PROGRESS_MIN_MS, EXPORT_TMP_DIR,
} from '../model/ExportCore';

const DOMAIN: number = 0x0000;
const TAG: string = 'ExportPage';

const PHASE_IDLE: string = 'idle';
const PHASE_BUILDING: string = 'building';
const PHASE_SAVING: string = 'saving';
const PHASE_SHARING: string = 'sharing';
const PHASE_RESULT: string = 'result';
const PHASE_ERROR: string = 'error';
const PHASE_EMPTY: string = 'empty';

/** 一种导出格式。id 是回调 token（不随文案变），label/desc 全部走 string.json。 */
interface FormatSpec {
  id: string;
  label: Resource;
  desc: Resource;
  ext: string;
  utd: string;
}

const FORMATS: FormatSpec[] = [
  {
    id: 'image',
    label: $r('app.string.export_fmt_image'),
    desc: $r('app.string.export_fmt_image_desc'),
    ext: 'png',
    utd: 'general.png',
  },
  {
    id: 'pdf',
    label: $r('app.string.export_fmt_pdf'),
    desc: $r('app.string.export_fmt_pdf_desc'),
    ext: 'pdf',
    utd: 'general.pdf',
  },
  {
    id: 'text',
    label: $r('app.string.export_fmt_text'),
    desc: $r('app.string.export_fmt_text_desc'),
    ext: 'txt',
    utd: 'general.plain-text',
  },
];

/** 一次构建的产物：字节＋（pdf 才有）沙箱内临时文件路径。 */
interface BuildOutcome {
  ok: boolean;
  bytes: ArrayBuffer | null;
  path: string;
  error: string;
}

@Component
export struct ExportPage {
  @Prop widthVp: number = 673.7;
  @Prop heightVp: number = 720;
  @Prop docId: string = '';
  @Prop machineKind: string = '1920s-upright';
  /** 返回（页内返回按钮）；busy 时由本页拦下，不调用它。 */
  onBack: () => void = (): void => {};
  /** 保存/分享前问 Index：先 flushSave()，返回 false = 空文档（不可导出）。 */
  onBeforeExport: () => boolean = (): boolean => true;
  onSaved: (format: string) => void = (): void => {};
  onShared: (format: string) => void = (): void => {};
  /** 第 3 批：busy 状态回传 Index（系统返回拦截用）。 */
  onBusyChange: (busy: boolean) => void = (busy: boolean): void => {};

  @State picked: number = -1;
  @State previewOp: number = 0;
  @State rowN: number = 0;
  @State pressedRow: number = -1;
  @State btnPressed: string = '';
  /** idle | building | saving | sharing | result | error | empty */
  @State phase: string = PHASE_IDLE;
  /** 结果态资源键名（渲染时 if 分支映射到 $r；键名便于比较与单测）。 */
  @State resultKey: string = '';
  /** 失败标题资源键名（export_save_failed / export_share_failed）。 */
  @State failKey: string = 'export_save_failed';
  @State errorMsg: string = '';
  @State progressVisible: boolean = false;
  @State progressValue: number = 0;
  /** F16 模板渲染失败回退 preview 时，结果态补一行说明。 */
  @State templateFallback: boolean = false;
  /** 进入页面时算好的预览正文/标题/日期（build 期不读文件）。 */
  @State previewText: string = '';
  @State docTitleState: string = '';
  @State dateText: string = '';

  /** 本次页面写下的分享临时文件；aboutToDisappear 统一删。 */
  private tmpFiles: string[] = [];
  private progTimer: number = -1;
  private opStartMs: number = 0;
  private progressShownAt: number = 0;
  private disposed: boolean = false;

  aboutToAppear(): void {
    this.disposed = false;
    this.phase = PHASE_IDLE;
    const d: DocData | null = this.docId.length > 0 ? docStore.load(this.docId) : null;
    this.previewText = this.previewOf(d);
    this.docTitleState = this.titleOf(d);
    this.dateText = this.todayText();
    // D6：入场 预览 200ms，三行格式间隔 60ms
    this.previewOp = 0;
    this.rowN = 0;
    setTimeout(() => { this.previewOp = 1; }, 30);
    for (let i = 0; i < 3; i++) {
      setTimeout(() => { this.rowN = i + 1; }, 200 + i * 60);
    }
  }

  aboutToDisappear(): void {
    this.disposed = true;
    this.stopTimer();
    this.cleanTmp();
  }

  /* --------------------------------------------------------------------- *
   * 文档 → 显示用字符串（只在进入页面时算一次）
   * --------------------------------------------------------------------- */

  private previewOf(d: DocData | null): string {
    if (d === null) {
      return '';
    }
    const parts: string[] = [];
    for (let i = 0; i < d.lines.length; i++) {
      parts.push(d.lines[i].text);
    }
    return parts.join('\n');
  }

  private titleOf(d: DocData | null): string {
    if (d !== null) {
      for (let i = 0; i < d.lines.length; i++) {
        const t: string = d.lines[i].text.trim();
        if (t.length > 0) {
          return t.length > 24 ? t.substring(0, 24) : t;
        }
      }
    }
    return this.resolveString($r('app.string.doc_untitled'));
  }

  private todayText(): string {
    const d: Date = new Date();
    const m: number = d.getMonth() + 1;
    const day: number = d.getDate();
    return d.getFullYear().toString() + '-' + (m < 10 ? '0' + m.toString() : m.toString()) +
      '-' + (day < 10 ? '0' + day.toString() : day.toString());
  }

  /** Resource → 本地化字符串（与 Index.resolveString 同口径；失败降级空串）。 */
  private resolveString(res: Resource): string {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx !== undefined && ctx !== null) {
        return ctx.resourceManager.getStringSync(res.id);
      }
    } catch (e) {
      // 资源缺失降级空串
    }
    return '';
  }

  /** 机名（PDF 抬头/日志用）：machineTitleKey → string.json 的本地化值。 */
  private machineLabel(): string {
    const ctx: common.UIAbilityContext | null = this.hostCtx();
    if (ctx === null) {
      return this.machineKind;
    }
    try {
      return ctx.resourceManager.getStringByNameSync(machineTitleKey(this.machineKind));
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'machineLabel resolve failed kind=%{public}s', this.machineKind);
      return this.machineKind;
    }
  }

  /* --------------------------------------------------------------------- *
   * 环境与临时目录
   * --------------------------------------------------------------------- */

  private hostCtx(): common.UIAbilityContext | null {
    const host = this.getUIContext().getHostContext();
    if (host === undefined || host === null) {
      return null;
    }
    return host as common.UIAbilityContext;
  }

  /** 分享/PDF 用的沙箱临时目录（filesDir/export-tmp）；失败返回空串。 */
  private ensureTmpDir(ctx: common.UIAbilityContext): string {
    try {
      const dir: string = ctx.filesDir + '/' + EXPORT_TMP_DIR;
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true);
      }
      return dir;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(DOMAIN, TAG, 'ensureTmpDir failed: %{public}s',
        err.message === undefined ? '' : err.message);
      return '';
    }
  }

  /** 写字节到沙箱文件；成功返回空串，失败返回原文错误。 */
  private writeBytes(path: string, data: ArrayBuffer): string {
    let file: fs.File | null = null;
    try {
      file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, data);
      return '';
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      const msg: string = err.message === undefined ? '' : err.message;
      hilog.error(DOMAIN, TAG, 'writeBytes failed path=%{public}s msg=%{public}s', path, msg);
      return msg.length > 0 ? msg : 'write failed';
    } finally {
      if (file !== null) {
        try {
          fs.closeSync(file);
        } catch (e2) {
          hilog.warn(DOMAIN, TAG, 'writeBytes close failed');
        }
      }
    }
  }

  /** aboutToDisappear：删掉本页写下的分享临时文件（失败只记日志）。 */
  private cleanTmp(): void {
    for (let i = 0; i < this.tmpFiles.length; i++) {
      const p: string = this.tmpFiles[i];
      try {
        fs.unlinkSync(p);
        hilog.info(DOMAIN, TAG, 'tmp cleaned path=%{public}s', p);
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'tmp clean failed path=%{public}s', p);
      }
    }
    this.tmpFiles = [];
  }

  /* --------------------------------------------------------------------- *
   * 状态机
   * --------------------------------------------------------------------- */

  private isBusy(): boolean {
    return this.phase === PHASE_BUILDING || this.phase === PHASE_SAVING ||
      this.phase === PHASE_SHARING;
  }

  private canExport(): boolean {
    return this.phase !== PHASE_EMPTY && !this.isBusy();
  }

  private currentFormat(): FormatSpec {
    return this.picked < 0 || this.picked >= FORMATS.length ? FORMATS[0] : FORMATS[this.picked];
  }

  private failWith(key: string, err: string): void {
    this.phase = PHASE_ERROR;
    this.failKey = key;
    this.errorMsg = err.length > 0 ? err : 'export failed';
    hilog.error(DOMAIN, TAG, 'export failed key=%{public}s err=%{public}s', key, this.errorMsg);
  }

  /** 保存：onBeforeExport → building → ExportService → FileHelper.saveBytes（ok/cancel/error）。 */
  private async runSave(): Promise<void> {
    if (this.isBusy() || this.phase === PHASE_EMPTY) {
      return;
    }
    if (!this.onBeforeExport()) {
      this.phase = PHASE_EMPTY;
      hilog.info(DOMAIN, TAG, 'export blocked: empty document');
      return;
    }
    const ctx: common.UIAbilityContext | null = this.hostCtx();
    if (ctx === null) {
      this.failWith('export_save_failed', 'no context');
      return;
    }
    const fmt: FormatSpec = this.currentFormat();
    this.beginOp();
    this.phase = PHASE_BUILDING;
    hilog.info(DOMAIN, TAG, 'export save start format=%{public}s', fmt.id);
    try {
      const out: BuildOutcome = await this.buildFor(fmt);
      if (!out.ok) {
        this.failWith('export_save_failed', out.error);
        return;
      }
      const data: ArrayBuffer | null = out.bytes;
      if (data === null) {
        this.failWith('export_save_failed', 'no bytes');
        return;
      }
      this.phase = PHASE_SAVING;
      const name: string = safeFileName(this.docTitleState, fmt.ext, Date.now());
      const r: SaveResult = await FileHelper.saveBytes(ctx, name, fmt.ext, data);
      if (r.status === 'ok') {
        this.phase = PHASE_RESULT;
        this.resultKey = resultText(true, false);
        this.onSaved(fmt.id);
        hilog.info(DOMAIN, TAG, 'export save ok format=%{public}s uri=%{public}s', fmt.id, r.uri);
      } else if (r.status === 'cancel') {
        this.phase = PHASE_IDLE;
        hilog.info(DOMAIN, TAG, 'export save cancelled by user');
      } else {
        this.failWith('export_save_failed', r.error);
      }
    } finally {
      this.endOp();
    }
  }

  /** 分享：onBeforeExport → building → 写临时文件 → ShareService（已调起即成功）。 */
  private async runShare(): Promise<void> {
    if (this.isBusy() || this.phase === PHASE_EMPTY) {
      return;
    }
    if (!this.onBeforeExport()) {
      this.phase = PHASE_EMPTY;
      hilog.info(DOMAIN, TAG, 'export blocked: empty document');
      return;
    }
    const ctx: common.UIAbilityContext | null = this.hostCtx();
    if (ctx === null) {
      this.failWith('export_share_failed', 'no context');
      return;
    }
    const fmt: FormatSpec = this.currentFormat();
    this.beginOp();
    this.phase = PHASE_BUILDING;
    hilog.info(DOMAIN, TAG, 'export share start format=%{public}s', fmt.id);
    try {
      const out: BuildOutcome = await this.buildFor(fmt);
      if (!out.ok) {
        this.failWith('export_share_failed', out.error);
        return;
      }
      let path: string = out.path;
      if (path.length === 0) {
        const data: ArrayBuffer | null = out.bytes;
        if (data === null) {
          this.failWith('export_share_failed', 'no bytes');
          return;
        }
        const dir: string = this.ensureTmpDir(ctx);
        if (dir.length === 0) {
          this.failWith('export_share_failed', 'no tmp dir');
          return;
        }
        path = dir + '/' + safeFileName(this.docTitleState, fmt.ext, Date.now());
        const werr: string = this.writeBytes(path, data);
        if (werr.length > 0) {
          this.failWith('export_share_failed', werr);
          return;
        }
        // 保留到 aboutToDisappear 统一清理（分享面板可能在后台读文件）
        this.tmpFiles.push(path);
      }
      this.phase = PHASE_SHARING;
      const sr: ShareResult = await ShareService.shareFile(ctx, path, fmt.utd);
      if (sr.shown) {
        this.phase = PHASE_RESULT;
        this.resultKey = resultText(false, true);
        this.onShared(fmt.id);
        hilog.info(DOMAIN, TAG, 'export share panel shown format=%{public}s path=%{public}s',
          fmt.id, path);
      } else {
        this.failWith('export_share_failed', sr.error);
      }
    } finally {
      this.endOp();
    }
  }

  /**
   * 按格式构建字节。
   * - 纯文本/PDF：ExportService 直接给字节；
   * - 图片：先走 F16 离屏模板（含机器框），失败回退现有 export_preview 快照（§5 R1）。
   */
  private async buildFor(fmt: FormatSpec): Promise<BuildOutcome> {
    if (fmt.id === 'text') {
      const r: ExportResult = ExportService.buildTxt(this.docId);
      return { ok: r.ok, bytes: r.bytes, path: '', error: r.error };
    }
    if (fmt.id === 'pdf') {
      const ctx: common.UIAbilityContext | null = this.hostCtx();
      const dir: string = ctx === null ? '' : this.ensureTmpDir(ctx);
      if (dir.length === 0) {
        return { ok: false, bytes: null, path: '', error: 'no tmp dir' };
      }
      const path: string = dir + '/' + safeFileName(this.docTitleState, 'pdf', Date.now());
      // 第 9 批 P1（用户真机反馈）：PDF 要**和图片导出同一视觉**（本机纸张＋机器框＋抬头），
      // 不再是一页默认字体的纯文本。做法＝先出 F16 模板 PNG，再把它铺进 A4 首页。
      const ui: UIContext = this.getUIContext();
      const t: ExportResult = await ExportService.buildPngTemplate(ui, this.docId, this.machineKind,
        this.docTitleState, this.dateText, (): void => { this.templateBuilder(); });
      if (t.ok && t.bytes !== null) {
        const pngPath: string = dir + '/' + safeFileName(this.docTitleState, 'pngimg', Date.now());
        if (ExportService.writeBytes(pngPath, t.bytes)) {
          const r2: ExportResult = ExportService.buildPdfFromImage(pngPath, path);
          if (r2.ok) {
            this.tmpFiles.push(path);
            this.tmpFiles.push(pngPath);
            return { ok: true, bytes: r2.bytes, path: path, error: '' };
          }
          hilog.warn(DOMAIN, TAG, 'pdf image build failed, fallback to text: %{public}s', r2.error);
        } else {
          hilog.warn(DOMAIN, TAG, 'pdf template png write failed, fallback to text');
        }
      } else {
        hilog.warn(DOMAIN, TAG, 'pdf template failed, fallback to text: %{public}s', t.error);
      }
      // 回退：仍用文字版（保证不会退化成空白页）
      const r: ExportResult = ExportService.buildPdf(this.docId, this.machineLabel(),
        this.docTitleState, this.dateText, path);
      if (r.ok) {
        this.tmpFiles.push(path);
      }
      return { ok: r.ok, bytes: r.bytes, path: r.ok ? path : '', error: r.error };
    }
    // 图片：F16 模板优先（含机器框）
    const ui: UIContext = this.getUIContext();
    const t: ExportResult = await ExportService.buildPngTemplate(ui, this.docId, this.machineKind,
      this.docTitleState, this.dateText, (): void => { this.templateBuilder(); });
    if (t.ok) {
      return { ok: true, bytes: t.bytes, path: '', error: '' };
    }
    hilog.warn(DOMAIN, TAG, 'template failed, fallback to preview: %{public}s', t.error);
    const p: ExportResult = await ExportService.buildPngFromPreview(ui, 'export_preview');
    if (!p.ok) {
      return { ok: false, bytes: null, path: '', error: p.error };
    }
    this.templateFallback = true;
    return { ok: true, bytes: p.bytes, path: '', error: '' };
  }

  /** 离屏模板 builder（createFromBuilder 要求组件作用域的 @Builder，服务拿不到）。 */
  @Builder
  templateBuilder() {
    // 第 7 批收尾（F16 修复）：离屏 builder 的根必须是**显式定尺容器**。
    // 直接放 ExportTemplate（其根已有 1080×1440）时，真机实测离屏渲染会被窗口约束
    // 成 640×1024vp，截出 1600×2560 px 的窗口图与裁切版式；这里再包一层定尺 Stack
    // 并把 clip 打开，让 createFromBuilder 拿到 1080×1440 的画布。
    Stack() {
      ExportTemplate({
        docId: this.docId,
        machineKind: this.machineKind,
        title: this.docTitleState,
        dateText: this.dateText,
      })
    }
    .width(EXPORT_TEMPLATE_W)
    .height(EXPORT_TEMPLATE_H)
    .clip(true)
  }

  /* --------------------------------------------------------------------- *
   * 进度浮层：<300ms 不显示；显示后最少 300ms；结果态不淡出
   * --------------------------------------------------------------------- */

  private beginOp(): void {
    this.onBusyChange(true);
    this.opStartMs = Date.now();
    this.progressShownAt = 0;
    this.progressVisible = false;
    this.progressValue = 6;
    this.stopTimer();
    this.progTimer = setInterval(() => {
      if (this.disposed || !this.isBusy()) {
        return;
      }
      if (Date.now() - this.opStartMs >= EXPORT_PROGRESS_MIN_MS) {
        if (this.progressShownAt === 0) {
          this.progressShownAt = Date.now();
        }
        this.progressVisible = true;
        const v: number = this.progressValue + 6;
        this.progressValue = v > 92 ? 92 : v;
      }
    }, 120);
  }

  private stopTimer(): void {
    if (this.progTimer >= 0) {
      clearInterval(this.progTimer);
      this.progTimer = -1;
    }
  }

  private endOp(): void {
    this.onBusyChange(false);
    this.stopTimer();
    if (!this.progressVisible) {
      return;
    }
    const shownFor: number = Date.now() - this.progressShownAt;
    const wait: number = shownFor < EXPORT_PROGRESS_MIN_MS ? EXPORT_PROGRESS_MIN_MS - shownFor : 0;
    if (wait <= 0) {
      this.progressVisible = false;
      return;
    }
    setTimeout(() => {
      if (!this.disposed) {
        this.progressVisible = false;
      }
    }, wait);
  }

  /* --------------------------------------------------------------------- *
   * 返回拦截
   * --------------------------------------------------------------------- */

  private handleBack(): void {
    if (this.isBusy()) {
      hilog.info(DOMAIN, TAG, 'export busy, back ignored phase=%{public}s', this.phase);
      return;
    }
    this.onBack();
  }

  /* --------------------------------------------------------------------- *
   * 资源映射（渲染时 if 分支，避免把 Resource 存进状态比较）
   * --------------------------------------------------------------------- */

  private resultRes(): Resource {
    if (this.resultKey === 'export_result_shared') {
      return $r('app.string.export_result_shared');
    }
    if (this.resultKey === 'export_result_saved_shared') {
      return $r('app.string.export_result_saved_shared');
    }
    return $r('app.string.export_result_saved');
  }

  private failRes(): Resource {
    if (this.failKey === 'export_share_failed') {
      return $r('app.string.export_share_failed');
    }
    return $r('app.string.export_save_failed');
  }

  private phaseRes(): Resource {
    if (this.phase === PHASE_SAVING) {
      return $r('app.string.export_saving');
    }
    if (this.phase === PHASE_SHARING) {
      return $r('app.string.export_sharing');
    }
    return $r('app.string.export_building');
  }

  /* --------------------------------------------------------------------- *
   * 视图
   * --------------------------------------------------------------------- */

  @Builder
  formatRows() {
    Column() {
      ForEach(FORMATS, (f: FormatSpec, idx: number) => {
        Row() {
          Column() {
            Text(f.label).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
            Text(f.desc).fontSize(12).fontColor('rgba(232,221,201,0.6)').margin({ top: 4 })
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          AppIcon({ kind: 'chevron', iconSize: 18, color: 'rgba(232,221,201,0.6)' })
        }
        .width('100%').height(110).padding({ left: 16, right: 16 })
        .backgroundColor(this.picked === idx ? '#2e2620' : '#241c16')
        .animation({ duration: 100 })
        .scale({ x: this.pressedRow === idx ? 0.97 : 1, y: this.pressedRow === idx ? 0.97 : 1 })
        .animation({ duration: 120, curve: Curve.EaseOut })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
            this.pressedRow = idx;
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.pressedRow = -1;
          }
        })
        .opacity(this.rowN > idx ? 1 : 0)
        .animation({ duration: 180, curve: Curve.EaseOut })
        .onClick(() => {
          if (this.isBusy()) {
            return;
          }
          this.picked = idx;
        })
      }, (f: FormatSpec, idx: number) => 'fmt' + idx.toString())
    }
    .width('100%')
    .borderRadius(12)
    .clip(true)
  }

  /** 结果/错误/空态行（常驻；不自动消失）。 */
  @Builder
  statusArea() {
    Column() {
      if (this.phase === PHASE_RESULT) {
        Text(this.resultRes()).fontSize(13).fontColor('#c9a45c')
        if (this.templateFallback) {
          Text($r('app.string.export_template_fallback'))
            .fontSize(11).fontColor('rgba(232,221,201,0.55)').margin({ top: 4 })
        }
      } else if (this.phase === PHASE_ERROR) {
        Text(this.failRes()).fontSize(13).fontColor('#d98a7c')
        Text(this.errorMsg).fontSize(11).fontColor('rgba(232,221,201,0.55)')
          .margin({ top: 4 }).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      } else if (this.phase === PHASE_EMPTY) {
        Text($r('app.string.export_empty')).fontSize(12).fontColor('rgba(232,221,201,0.6)')
      }
    }
    .width('100%').padding({ left: 20, right: 20 }).alignItems(HorizontalAlign.Center)
  }

  @Builder
  actionButtons() {
    Row() {
      // 主：保存到本地
      Row() {
        Text($r('app.string.export_save'))
          .fontSize(17).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
      }
      .height(56).layoutWeight(1).justifyContent(FlexAlign.Center)
      .borderRadius(28).backgroundColor('#2e2620')
      .scale({ x: this.btnPressed === 'save' ? 0.97 : 1, y: this.btnPressed === 'save' ? 0.97 : 1 })
      .animation({ duration: 120, curve: Curve.EaseOut })
      .opacity(this.canExport() ? 1 : 0.45)
      .enabled(this.canExport())
      .onTouch((e: TouchEvent) => { this.pressBtn('save', e); })
      .onClick(() => {
        this.runSave().catch((e: BusinessError) => {
          this.failWith('export_save_failed', e.message === undefined ? '' : e.message);
        });
      })

      Column().width(12)

      // 次：分享（描边，不抢主按钮）
      Row() {
        Text($r('app.string.export_share'))
          .fontSize(17).fontColor('rgba(232,221,201,0.88)')
      }
      .height(56).layoutWeight(1).justifyContent(FlexAlign.Center)
      .borderRadius(28).border({ width: 1, color: 'rgba(232,221,201,0.32)' })
      .scale({ x: this.btnPressed === 'share' ? 0.97 : 1, y: this.btnPressed === 'share' ? 0.97 : 1 })
      .animation({ duration: 120, curve: Curve.EaseOut })
      .opacity(this.canExport() ? 1 : 0.45)
      .enabled(this.canExport())
      .onTouch((e: TouchEvent) => { this.pressBtn('share', e); })
      .onClick(() => {
        this.runShare().catch((e: BusinessError) => {
          this.failWith('export_share_failed', e.message === undefined ? '' : e.message);
        });
      })
      .id('export__share_btn')
    }
    .width('100%').padding({ left: 20, right: 20 }).margin({ bottom: 8 })
    .id('export__actions')
  }

  private pressBtn(kind: string, e: TouchEvent): void {
    if (e.type === TouchType.Down) {
      this.btnPressed = kind;
    } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
      this.btnPressed = '';
    }
  }

  @Builder
  progressOverlay() {
    Column() {
      Text(this.phaseRes()).fontSize(13).fontColor('#e8ddc9')
      Progress({ value: this.progressValue, total: 100, type: ProgressType.Linear })
        .width(180).height(4).color('#c9a45c').margin({ top: 12 })
    }
    .width(220).padding(16).borderRadius(8).backgroundColor('rgba(20,16,12,0.92)')
  }

  @Builder
  body() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Scroll() {
          Column() {
            // 纸面预览：当前文档第一页（不可点、不可编辑）
            Stack({ alignContent: Alignment.TopStart }) {
              Image($rawfile('paper/paper-letter.jpg'))
                .width('100%').height(480).objectFit(ImageFit.Cover).borderRadius(12)
              Text(this.previewText).fontSize(12).lineHeight(22).fontColor('#1a1a1a')
                .width('100%').padding({ left: 22, right: 22, top: 26 })
                .maxLines(16).textOverflow({ overflow: TextOverflow.Clip })
            }
            .id('export_preview')
            .width('100%').height(480).clip(true).borderRadius(12)
            .opacity(this.previewOp)
            .animation({ duration: 200, curve: Curve.EaseOut })

            Column().width('100%').height(16)

            this.formatRows()
          }
          .width('100%').padding({ left: 20, right: 20 })
        }
        .id('export__formats')
        .layoutWeight(1).width('100%').scrollBar(BarState.Off)

        this.statusArea()

        // §2.10 第 7 条：小字在按钮上方；按钮行底距 = bottomInset（PageShell 内容区 padding 承担）
        Text($r('app.string.guide_export_hint'))
          .fontSize(12).fontColor('rgba(232,221,201,0.4)')
          .width('100%').textAlign(TextAlign.Center)
          .margin({ top: 10, bottom: 8 })

        this.actionButtons()
      }
      .width('100%').height('100%')

      if (this.progressVisible) {
        this.progressOverlay()
      }
    }
    .width('100%').height('100%')
  }

  build() {
    PageShell({
        guidePage: 'export',
      widthVp: this.widthVp,
      heightVp: this.heightVp,
      title: $r('app.string.page_export'),
      onBack: () => { this.handleBack(); },
      subtitle: $r('app.string.guide_export_hint'),
      showSubtitle: true,
      content: (): void => { this.body() },
    })
  }
}

/** Export 页首次引导（与功能同处一源；文案键见 string.json）。 */
export function guideStepsForExport(): SpotlightStep[] {
  return [
    { text: $r('app.string.guide_export_1'), anchorId: 'export__formats' },
    { text: $r('app.string.guide_export_2'), anchorId: 'export__actions' },
    { text: $r('app.string.guide_export_3'), anchorId: 'export__share_btn' },
  ];
}