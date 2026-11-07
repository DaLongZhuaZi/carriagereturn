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
  private handlers: CnHandlers | null = null;

  isAttached(): boolean {
    return this.attached;
  }

  /** 订阅全部事件后再 attach；anchor 为编辑区光标矩形（单位 px）。 */
  async attach(h: CnHandlers, left: number, top: number, width: number, height: number): Promise<boolean> {
    if (this.attached) {
      return true;
    }
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
        hilog.info(0x0000, 'CnInput', 'insertText len=%{public}s', text.length.toString());
        if (this.handlers !== null) { this.handlers.onInsertText(text); }
      });
      c.on('deleteLeft', (len: number) => {
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
      this.attached = true;
      hilog.info(0x0000, 'CnInput', 'attached ok');
      return true;
    } catch (e) {
      const err: BusinessError = e as BusinessError;
      hilog.error(0x0000, 'CnInput', 'attach failed code=%{public}s msg=%{public}s',
        err.code.toString(), err.message);
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
