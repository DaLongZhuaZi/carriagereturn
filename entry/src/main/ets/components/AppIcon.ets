/**
 * 回车 · 图标集（AGENTS「图标」）：全部用系统 SymbolGlyph，禁止手画 Path / 文字符号。
 *
 * 第 0 批：kind 收敛为注册表（`IconKind` 常量 + `iconResourceOf()` 唯一映射 + `all()` 清单），
 * 供 `tools/audit-icons.py` 审计；本批只登记现有 13 种，各批新增 kind 时在此追加。
 *
 * 符号名以 SDK 为准（sys.symbol.*）；查不到的符号不许现编。
 */

export class IconKind {
  static readonly BACK: string = 'back';
  static readonly CHEVRON_UP: string = 'chevron_up';
  static readonly PLUS: string = 'plus';
  static readonly CHEVRON: string = 'chevron';
  static readonly FOLDER: string = 'folder';
  static readonly MENU: string = 'menu';
  static readonly MORE: string = 'more';
  static readonly CHECK: string = 'check';
  static readonly SETTINGS: string = 'settings';
  static readonly EXPORT: string = 'export';
  static readonly RENAME: string = 'rename';
  static readonly DELETE: string = 'delete';
  static readonly LOCK: string = 'lock';
  /** 第 10 批：引导 "?" 入口。 */
  static readonly HELP: string = 'help';
  /** 第 13 批 ④：新启动引导 5 页图标。 */
  static readonly ONBOARD_TYPE: string = 'onboard_type';
  static readonly ONBOARD_MACHINE: string = 'onboard_machine';
  static readonly ONBOARD_PAPER: string = 'onboard_paper';
  static readonly ONBOARD_EXPORT: string = 'onboard_export';
  static readonly ONBOARD_INPUT: string = 'onboard_input';

  /** 全部已登记 kind（审计与断言用）。 */
  static all(): string[] {
    return [
      IconKind.BACK, IconKind.CHEVRON_UP, IconKind.PLUS, IconKind.CHEVRON,
      IconKind.FOLDER, IconKind.MENU, IconKind.MORE, IconKind.CHECK,
      IconKind.SETTINGS, IconKind.EXPORT, IconKind.RENAME, IconKind.DELETE, IconKind.LOCK, IconKind.HELP,
      IconKind.ONBOARD_TYPE, IconKind.ONBOARD_MACHINE, IconKind.ONBOARD_PAPER,
      IconKind.ONBOARD_EXPORT, IconKind.ONBOARD_INPUT,
    ];
  }

  /** kind 是否已登记。 */
  static isRegistered(kind: string): boolean {
    return IconKind.all().indexOf(kind) >= 0;
  }
}

/** 语义 kind → 系统符号资源（唯一映射点；未知 kind 回落 back，不崩）。 */
export function iconResourceOf(kind: string): Resource {
  if (kind === IconKind.BACK) { return $r('sys.symbol.chevron_left'); }
  if (kind === IconKind.CHEVRON_UP) { return $r('sys.symbol.chevron_up'); }
  if (kind === IconKind.PLUS) { return $r('sys.symbol.plus'); }
  if (kind === IconKind.CHEVRON) { return $r('sys.symbol.chevron_right'); }
  if (kind === IconKind.FOLDER) { return $r('sys.symbol.folder'); }
  if (kind === IconKind.MENU) { return $r('sys.symbol.line_3_horizontal'); }
  if (kind === IconKind.MORE) { return $r('sys.symbol.dot_grid_2x2'); }
  if (kind === IconKind.CHECK) { return $r('sys.symbol.checkmark'); }
  if (kind === IconKind.SETTINGS) { return $r('sys.symbol.gearshape'); }
  if (kind === IconKind.EXPORT) { return $r('sys.symbol.share'); }
  if (kind === IconKind.RENAME) { return $r('sys.symbol.square_and_pencil'); }
  if (kind === IconKind.DELETE) { return $r('sys.symbol.trash'); }
  if (kind === IconKind.LOCK) { return $r('sys.symbol.lock'); }
  if (kind === IconKind.HELP) { return $r('sys.symbol.questionmark_circle'); }
  // 第 13 批 ④：新引导 5 页（P1–P4 复用仓内已证实符号；P5 取 SDK resources.txt id:125832099 'keyboard'）
  if (kind === IconKind.ONBOARD_TYPE) { return $r('sys.symbol.square_and_pencil'); }
  if (kind === IconKind.ONBOARD_MACHINE) { return $r('sys.symbol.dot_grid_2x2'); }
  if (kind === IconKind.ONBOARD_PAPER) { return $r('sys.symbol.folder'); }
  if (kind === IconKind.ONBOARD_EXPORT) { return $r('sys.symbol.share'); }
  if (kind === IconKind.ONBOARD_INPUT) { return $r('sys.symbol.keyboard'); }
  return $r('sys.symbol.chevron_left');
}

@Component
export struct AppIcon {
  @Prop kind: string = IconKind.BACK;
  @Prop iconSize: number = 24;
  @Prop color: string = '#e8ddc9';

  build() {
    SymbolGlyph(iconResourceOf(this.kind))
      .fontSize(this.iconSize)
      .fontColor([this.color])
      .width(this.iconSize)
      .height(this.iconSize)
  }
}