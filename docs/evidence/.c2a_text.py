import io
p = 'entry/src/main/ets/components/CanvasTypewriter.ets'
s = io.open(p, encoding='utf-8', newline=None).read()

def rep(old, new):
    global s
    if old not in s:
        raise SystemExit('MISS %r' % old[:120])
    s = s.replace(old, new, 1)

# 1) remove keycap overlay text from machine layer
rep("""    // 键帽叠字
    ctx.textAlign = 'center';
    ctx.fillStyle = this.keymap.overlayColor;
    ctx.font = this.keymap.overlayFontSize.toString() + 'vp ' + this.fontFamily;
    for (let i = 0; i < this.keymap.caps.length; i++) {
      const cap: CapDef = this.keymap.caps[i];
      if (cap.isExtra || cap.label === ' ') { continue; }
      ctx.fillText(cap.label, cap.xRatio * this.keybedWidth(), this.keybedTop() + cap.yRatio * this.keybedHeightVp);
    }
    // 字体条
    ctx.fillStyle = '#3a332b';
    ctx.fillRect(0, this.fontBarTop(), this.widthVp, 1);
    ctx.fillRect(0, this.fontBarTop() + this.fontBarHeightVp - 1, this.widthVp, 1);
    ctx.fillStyle = '#beb4a8';
    ctx.font = '13vp ' + this.fontFamily;
    ctx.textAlign = 'center';
    ctx.fillText(this.fontLabel, this.widthVp / 2, this.fontBarTop() + this.fontBarHeightVp / 2 + 5);
    // 功能行""",
"""    // 字体条分隔线
    ctx.fillStyle = '#3a332b';
    ctx.fillRect(0, this.fontBarTop(), this.widthVp, 1);
    ctx.fillRect(0, this.fontBarTop() + this.fontBarHeightVp - 1, this.widthVp, 1);
    // 功能行""")

# 2) drawFunctionRow: boxes only
rep("""  private drawFunctionRow(ctx: OffscreenCanvasRenderingContext2D): void {
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
      const x: number = left + i * (keyW + gap);
      ctx.fillStyle = '#2e2823';
      ctx.fillRect(x, y0, keyW, h);
      ctx.strokeStyle = i === 0 || i === 5 ? '#c9a45c' : (i === 2 ? '#6b6055' : '#6b6055');
      ctx.lineWidth = 1;
      ctx.strokeRect(x + 0.5, y0 + 0.5, keyW - 1, h - 1);
      ctx.fillStyle = i === 2 ? '#c9a45c' : '#dbccb3';
      ctx.fillText(labels[i], x + keyW / 2, y0 + h / 2 + 5);
    }
  }""",
"""  private drawFunctionRow(ctx: OffscreenCanvasRenderingContext2D): void {
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
  }""")

# 3) paper layer: remove text/cursor drawing
rep("""    const ps: PaperSpec = this.paperSpec();
    if (ps.hasHeader) {
      ctx.fillStyle = '#c8b9a6';
      ctx.fillRect(0, this.marginTVp, this.paperWidthVp, 1);
      ctx.fillRect(0, this.marginTVp + 4, this.paperWidthVp, 1);
      ctx.fillStyle = '#8a7f70';
      ctx.font = '12vp sans-serif';
      ctx.textAlign = 'right';
      ctx.fillText(this.pageNo.toString() + ' / ' + this.pageCount.toString(),
        this.paperWidthVp - this.marginHVp, this.marginTVp + 18);
    }
    if (ps.hasRuledGrid) {
      ctx.fillStyle = '#c8a49a';
      ctx.fillRect(this.marginHVp - 8, 0, 1, this.paperHeightVp);
    }
    ctx.fillStyle = this.inkColor;
    ctx.font = this.fontSizeVp.toString() + 'vp ' + this.fontFamily;
    ctx.textAlign = 'left';
    const contentTop: number = this.marginTVp + 20;
    for (let i = 0; i < this.lines.length; i++) {
      const line: string = this.lines[i];
      if (line.length > 0) {
        ctx.fillText(line, this.marginHVp, contentTop + (i + 1) * this.lineHeightVp - 6);
      }
    }
    if (this.lines.length <= 1 && this.hintText.length > 0) {
      ctx.fillStyle = '#8a7f70';
      ctx.font = '13vp sans-serif';
      ctx.textAlign = 'left';
      ctx.fillText(this.hintText, this.marginHVp, this.paperHeightVp - this.marginBVp - this.lineHeightVp + 16);
    }
    // 光标三角
    ctx.fillStyle = this.inkColor;
    ctx.beginPath();
    ctx.moveTo(this.cursorXVp, this.cursorYVp);
    ctx.lineTo(this.cursorXVp + 8, this.cursorYVp);
    ctx.lineTo(this.cursorXVp + 4, this.cursorYVp + 6);
    ctx.closePath();
    ctx.fill();
    this.paperLayer = off.transferToImageBitmap();""",
"""    const ps: PaperSpec = this.paperSpec();
    if (ps.hasHeader) {
      ctx.fillStyle = '#c8b9a6';
      ctx.fillRect(0, this.marginTVp, this.paperWidthVp, 1);
      ctx.fillRect(0, this.marginTVp + 4, this.paperWidthVp, 1);
    }
    if (ps.hasRuledGrid) {
      ctx.fillStyle = '#c8a49a';
      ctx.fillRect(this.marginHVp - 8, 0, 1, this.paperHeightVp);
    }
    this.paperLayer = off.transferToImageBitmap();""")

# 4) add drawTexts after front layer draw
rep("""    if (this.machineFrontLayer !== null) {
      ctx.drawImage(this.machineFrontLayer, 0, 0);
    }
  }""",
"""    if (this.machineFrontLayer !== null) {
      ctx.drawImage(this.machineFrontLayer, 0, 0);
    }
    this.drawTexts(ctx);
  }

  /** 文字统一在主 Canvas 上画（OffscreenCanvas 看不到 registerFont 注册字体，会回落到系统字体）。 */
  private drawTexts(ctx: CanvasRenderingContext2D): void {
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
    ctx.font = this.fontSizeVp.toString() + 'vp ' + this.fontFamily;
    ctx.textAlign = 'left';
    const contentTop: number = paperTop + this.marginTVp + 20;
    for (let i = 0; i < this.lines.length; i++) {
      const line: string = this.lines[i];
      if (line.length > 0) {
        ctx.fillText(line, paperLeft + this.marginHVp, contentTop + (i + 1) * this.lineHeightVp - 6);
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
    ctx.font = this.keymap.overlayFontSize.toString() + 'vp ' + this.fontFamily;
    ctx.textAlign = 'center';
    for (let i = 0; i < this.keymap.caps.length; i++) {
      const cap: CapDef = this.keymap.caps[i];
      if (cap.isExtra || cap.label === ' ') { continue; }
      ctx.fillText(cap.label, cap.xRatio * this.keybedWidth(), this.keybedTop() + cap.yRatio * this.keybedHeightVp);
    }
    ctx.restore();
    // 字体条
    ctx.fillStyle = '#beb4a8';
    ctx.font = '13vp ' + this.fontFamily;
    ctx.textAlign = 'center';
    ctx.fillText(this.fontLabel, this.widthVp / 2, this.fontBarTop() + this.fontBarHeightVp / 2 + 5);
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
      ctx.fillText(labels[i], left + i * (keyW + gap) + keyW / 2, y0 + h / 2 + 5);
    }
  }""")

io.open(p, 'w', encoding='utf-8', newline='\r\n').write(s)
print('text moved to main canvas ok')
