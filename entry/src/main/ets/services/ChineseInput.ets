/**
 * 回车 · 中文输入通道（§7.2 双通道）
 *
 * 用 IME Kit 的 InputMethodController 作为「自定义编辑框」接入系统输入法：
 * attach 前先订阅 setPreviewText / finishTextPreview（API 17+，本工程 compatibleSdkVersion 26.0.0），
 * 再接管 insertText / deleteLeft / deleteRight / moveCursor / sendFunctionKey。
 *
 * 只做「接字」——不建拼音候选行、不做切分/词库/联想。整词拆单字由调用方（Index）负责。
 */

import { inputMethod } from '@kit.IMEKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

export interface CnHandlers {
  onInsertText: (text: string) => void;
  onDeleteLeft: (len: number) => void;
  onDeleteRight: (len: number) => void;
  onMoveCursor: (dir: number) => void;
  onPreview: (text: string) => void;
  onFinishPreview: () => void;
  onEnter: () => void;
  onKeyboardShown: (shown: boolean) => void;
}

export class ChineseInput {
  private controller: inputMethod.InputMethodController | null = null;
  private attached: boolean = false;
  /** attach 进行中守卫（await 之前就置位）。 */
  private attaching: boolean = false;
  private handlers: CnHandlers | null = null;
  /** 诊断：attach 代数与 insertText 到达序号。 */
  private gen: number = 0;
  private seq: number = 0;

  isAttached(): boolean {
    return this.attached;
  }

  /** 订阅全部事件后再 attach；anchor 为编辑区光标矩形（单位 px）。 */
  async attach(h: CnHandlers, left: number, top: number, width: number, height: number): Promise<boolean> {
    if (this.attached) {
      return true;
    }
    // 同步守卫：await 之前就置位，防并发重复订阅
    if (this.attaching) {
      hilog.warn(0x0000, 'CnInput', 'attach skipped: already attaching');
      return false;
    }
    this.attaching = true;
    this.handlers = h;
    try {
      this.controller = inputMethod.getController();
      const c: inputMethod.InputMethodController = this.controller;

      // 预编辑（API 17+）：必须先订阅再 attach
      c.on('setPreviewText', (text: string, range: inputMethod.Range) => {
        hilog.info(0x0000, 'CnInput', 'preview len=%{public}s', text.length.toString());
        if (this.handlers !== null) { this.handlers.onPreview(text); }
      });
      c.on('finishTextPreview', () => {
        hilog.info(0x0000, 'CnInput', 'finishPreview');
        if (this.handlers !== null) { this.handlers.onFinishPreview(); }
      });
      c.on('insertText', (text: string) => {
        this.seq = this.seq + 1;
        hilog.info(0x0000, 'CnInput', 'cn evt insertText seq=%{public}s gen=%{public}s len=%{public}s',
          this.seq.toString(), this.gen.toString(), text.length.toString());
        if (this.handlers !== null) { this.handlers.onInsertText(text); }
      });
      c.on('deleteLeft', (len: number) => {
        hilog.info(0x0000, 'CnInput', 'cn evt deleteLeft n=%{public}s gen=%{public}s',
          len.toString(), this.gen.toString());
        if (this.handlers !== null) { this.handlers.onDeleteLeft(len); }
      });
      c.on('deleteRight', (len: number) => {
        if (this.handlers !== null) { this.handlers.onDeleteRight(len); }
      });
      c.on('moveCursor', (dir: inputMethod.Direction) => {
        if (this.handlers !== null) { this.handlers.onMoveCursor(dir as number); }
      });
      c.on('sendFunctionKey', (fk: inputMethod.FunctionKey) => {
        // 只有「换行类」键型才走换行；GO/SEARCH/SEND/DONE 等其他键型只记日志
        const isNewline: boolean = fk.enterKeyType === inputMethod.EnterKeyType.NEWLINE;
        hilog.info(0x0000, 'CnInput', 'functionKey enter=%{public}s newline=%{public}s',
          fk.enterKeyType.toString(), isNewline ? 'true' : 'false');
        if (isNewline && this.handlers !== null) { this.handlers.onEnter(); }
      });
      c.on('sendKeyboardStatus', (st: inputMethod.KeyboardStatus) => {
        const shown: boolean = st === inputMethod.KeyboardStatus.SHOW;
        if (this.handlers !== null) { this.handlers.onKeyboardShown(shown); }
      });

      const cfg: inputMethod.TextConfig = {
        inputAttribute: {
          textInputType: inputMethod.TextInputType.NONE,
          enterKeyType: inputMethod.EnterKeyType.UNSPECIFIED,
        },
        cursorInfo: { left: left, top: top, width: width, height: height },
        newEditBox: true,
      };
      await c.attach(true, cfg);
      this.attaching = false;
      this.attached = true;
      this.gen = this.gen + 1;
      hilog.info(0x0000, 'CnInput', 'attached ok gen=%{public}s', this.gen.toString());
      return true;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(0x0000, 'CnInput', 'attach failed code=%{public}s msg=%{public}s',
        err.code.toString(), err.message);
      this.attaching = false;
      this.attached = false;
      return false;
    }
  }

  /** 光标矩形变化时同步给输入法（候选窗跟随光标）。 */
  updateCursorRect(left: number, top: number, width: number, height: number): void {
    hilog.info(0x0000, 'CnInput', 'updateCursorRect (%{public}s,%{public}s %{public}sx%{public}s) attached=%{public}s',
      left.toFixed(0), top.toFixed(0), width.toFixed(0), height.toFixed(0),
      this.attached ? 'true' : 'false');
    if (!this.attached || this.controller === null) {
      return;
    }
    try {
      const cfg: inputMethod.TextConfig = {
        inputAttribute: {
          textInputType: inputMethod.TextInputType.NONE,
          enterKeyType: inputMethod.EnterKeyType.UNSPECIFIED,
        },
        cursorInfo: { left: left, top: top, width: width, height: height },
      };
      this.controller.attach(false, cfg);
    } catch (e) {
      hilog.warn(0x0000, 'CnInput', 'updateCursorRect failed');
    }
  }

  /** 退出中文通道：只在中/EN 切换或页面失焦时调用。 */
  async detach(): Promise<void> {
    if (!this.attached || this.controller === null) {
      return;
    }
    try {
      // 先 off 全部订阅，再 detach（否则每次 attach 都会累积一份监听 → 多重输入）
      const c: inputMethod.InputMethodController = this.controller;
      let offs: number = 0;
      const offOne = (name: string, fn: () => void): void => {
        try { fn(); offs = offs + 1; } catch (e) { hilog.warn(0x0000, 'CnInput', 'off %{public}s failed', name); }
      };
      offOne('insertText', () => { c.off('insertText'); });
      offOne('deleteLeft', () => { c.off('deleteLeft'); });
      offOne('deleteRight', () => { c.off('deleteRight'); });
      offOne('moveCursor', () => { c.off('moveCursor'); });
      offOne('setPreviewText', () => { c.off('setPreviewText'); });
      offOne('finishTextPreview', () => { c.off('finishTextPreview'); });
      offOne('sendFunctionKey', () => { c.off('sendFunctionKey'); });
      offOne('sendKeyboardStatus', () => { c.off('sendKeyboardStatus'); });
      hilog.info(0x0000, 'CnInput', 'cn off events=%{public}s', offs.toString());
      await this.controller.detach();
      hilog.info(0x0000, 'CnInput', 'detached');
    } catch (e) {
      hilog.warn(0x0000, 'CnInput', 'detach failed');
    }
    this.attached = false;
    this.controller = null;
  }
}

export const chineseInput: ChineseInput = new ChineseInput();
