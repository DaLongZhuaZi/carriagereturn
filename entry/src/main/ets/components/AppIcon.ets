/**
 * 回车 · 图标集（AGENTS「图标」）：全部用系统 SymbolGlyph，禁止手画 Path / 文字符号。
 *
 * 符号名以 SDK 为准（sys.symbol.*）；nameFor() 只做「语义 → 系统符号名」映射。
 */

@Component
export struct AppIcon {
  @Prop kind: string = 'back';
  @Prop iconSize: number = 24;
  @Prop color: string = '#e8ddc9';

  private nameFor(): Resource {
    if (this.kind === 'back') { return $r('sys.symbol.chevron_left'); }
    if (this.kind === 'chevron_up') { return $r('sys.symbol.chevron_up'); }
    if (this.kind === 'plus') { return $r('sys.symbol.plus'); }
    if (this.kind === 'chevron') { return $r('sys.symbol.chevron_right'); }
    if (this.kind === 'folder') { return $r('sys.symbol.folder'); }
    if (this.kind === 'menu') { return $r('sys.symbol.line_3_horizontal'); }
    if (this.kind === 'more') { return $r('sys.symbol.dot_grid_2x2'); }
    if (this.kind === 'check') { return $r('sys.symbol.checkmark'); }
    if (this.kind === 'settings') { return $r('sys.symbol.gearshape'); }
    if (this.kind === 'export') { return $r('sys.symbol.share'); }
    if (this.kind === 'rename') { return $r('sys.symbol.square_and_pencil'); }
    if (this.kind === 'delete') { return $r('sys.symbol.trash'); }
    if (this.kind === 'lock') { return $r('sys.symbol.lock'); }
    return $r('sys.symbol.chevron_left');
  }

  build() {
    SymbolGlyph(this.nameFor())
      .fontSize(this.iconSize)
      .fontColor([this.color])
      .width(this.iconSize)
      .height(this.iconSize)
  }
}
