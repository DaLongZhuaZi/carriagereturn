import io
p = 'entry/src/main/ets/components/CanvasTypewriter.ets'
s = io.open(p, encoding='utf-8', newline=None).read()

old = '  private spec(): MachineSpec {'
new = """  /** Canvas font 字符串只取单一族名（逗号列表在 Canvas 里会回落系统字体）。 */
  private canvasFont(): string {
    const i: number = this.fontFamily.indexOf(',');
    return i > 0 ? this.fontFamily.substring(0, i).trim() : this.fontFamily;
  }

  private spec(): MachineSpec {"""
assert old in s
s = s.replace(old, new, 1)

s = s.replace("this.fontSizeVp.toString() + 'vp ' + this.fontFamily",
              "this.fontSizeVp.toString() + 'vp ' + this.canvasFont()")
s = s.replace("this.keymap.overlayFontSize.toString() + 'vp ' + this.fontFamily",
              "this.keymap.overlayFontSize.toString() + 'vp ' + this.canvasFont()")
s = s.replace("'13vp ' + this.fontFamily", "'13vp ' + this.canvasFont()")

old2 = """    ctx.fillStyle = this.inkColor;
    ctx.font = this.fontSizeVp.toString() + 'vp ' + this.canvasFont();
    ctx.textAlign = 'left';
    const contentTop: number = paperTop + this.marginTVp + 20;
    for (let i = 0; i < this.lines.length; i++) {
      const line: string = this.lines[i];
      if (line.length > 0) {
        ctx.fillText(line, paperLeft + this.marginHVp, contentTop + (i + 1) * this.lineHeightVp - 6);
      }
    }"""
new2 = """    ctx.fillStyle = this.inkColor;
    ctx.font = this.fontSizeVp.toString() + 'vp ' + this.canvasFont();
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    const contentTop: number = paperTop + this.marginTVp + 20;
    for (let i = 0; i < this.lines.length; i++) {
      const line: string = this.lines[i];
      if (line.length > 0) {
        ctx.fillText(line, paperLeft + this.marginHVp, contentTop + i * this.lineHeightVp + this.lineHeightVp / 2);
      }
    }"""
assert old2 in s
s = s.replace(old2, new2, 1)

old3 = '  private drawTexts(ctx: CanvasRenderingContext2D): void {'
new3 = "  private drawTexts(ctx: CanvasRenderingContext2D): void {\n    ctx.textBaseline = 'middle';"
assert old3 in s
s = s.replace(old3, new3, 1)

io.open(p, 'w', encoding='utf-8', newline='\r\n').write(s)
print('canvas font baseline fix ok')
