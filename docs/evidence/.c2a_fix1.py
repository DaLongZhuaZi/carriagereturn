import io
p = 'entry/src/main/ets/components/CanvasTypewriter.ets'
s = io.open(p, encoding='utf-8', newline=None).read()

def rep(old, new):
    global s
    if old not in s:
        raise SystemExit('MISS %r' % old[:110])
    s = s.replace(old, new, 1)

# fields
rep("""  private machineLayer: ImageBitmap | null = null;
  private paperLayer: ImageBitmap | null = null;""",
"""  private machineLayer: ImageBitmap | null = null;
  private machineFrontLayer: ImageBitmap | null = null;
  private paperLayer: ImageBitmap | null = null;""")

# buildMachineLayer start: two offscreens
rep("""    const off: OffscreenCanvas = new OffscreenCanvas(w, h);
    const ctx: OffscreenCanvasRenderingContext2D = off.getContext('2d');
    const spec: MachineSpec = this.spec();""",
"""    const off: OffscreenCanvas = new OffscreenCanvas(w, h);
    const ctx: OffscreenCanvasRenderingContext2D = off.getContext('2d');
    const offFront: OffscreenCanvas = new OffscreenCanvas(w, h);
    const ctxFront: OffscreenCanvasRenderingContext2D = offFront.getContext('2d');
    const spec: MachineSpec = this.spec();""")

# front-of-paper parts: bail block through lever block switch to ctxFront
old_front = """    // 压纸卷
    const bailH: number = this.paperWidthVp / 9.6678;
    const bailY: number = carrAbs - bailH / 2 + (this.isTablet ? -15 : 0);
    if (this.imgBail !== null) {
      ctx.drawImage(this.imgBail, paperLeft, bailY, this.paperWidthVp, bailH);
    }
    // 中央件
    const Hg: number = Hc * 1.5;
    const strikeX: number = paperLeft + this.marginHVp;
    const strikeAbs: number = this.stackTop() + this.strikeLineVp;
    const centralW: number = Hg * spec.centralAspect;
    if (this.imgCentral !== null) {
      ctx.drawImage(this.imgCentral, strikeX - centralW / 2, strikeAbs - Hg * spec.centralWindowY, centralW, Hg);
    }
    // 拨杆支点支架
    const bracketW: number = 60;
    const bracketH: number = bracketW / spec.bracketAspect;
    const bracketLeft: number = baseLeft + baseW - bracketW - 10;
    const bracketTop: number = carrAbs - Hc / 2 + Hc + 24 - bracketH;
    if (this.imgBracket !== null) {
      ctx.drawImage(this.imgBracket, bracketLeft, bracketTop, bracketW, bracketH);
    }
    // 拨杆（静止角：平板 30／手机 15；摆幅 35／20，见 LeverAngleCore）
    if (this.imgLever !== null) {
      const leverW: number = this.isTablet
        ? Hc * 1.84 * this.leverSizeRatio(spec)
        : Hc * 2.5 * this.leverSizeRatio(spec);
      const leverH: number = leverW / spec.leverAspect;
      const pinX: number = bracketLeft + spec.bracketPivotX * bracketW;
      const pinY: number = bracketTop + spec.bracketPivotY * bracketH;
      const restDeg: number = this.isTablet ? 30 : 15;
      ctx.save();
      ctx.translate(pinX, pinY);
      ctx.rotate(restDeg * Math.PI / 180);
      ctx.drawImage(this.imgLever, -leverW * spec.leverPivotX, -leverH * spec.leverPivotY, leverW, leverH);
      ctx.restore();
    }"""
new_front = """    // 压纸卷（纸之上）
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
    // 拨杆（静止角：平板 30／手机 15；摆幅 35／20，见 LeverAngleCore）
    if (this.imgLever !== null) {
      const leverW: number = this.isTablet
        ? Hc * 1.84 * this.leverSizeRatio(spec)
        : Hc * 2.5 * this.leverSizeRatio(spec);
      const leverH: number = leverW / spec.leverAspect;
      const pinX: number = bracketLeft + spec.bracketPivotX * bracketW;
      const pinY: number = bracketTop + spec.bracketPivotY * bracketH;
      const restDeg: number = this.isTablet ? 30 : 15;
      ctxFront.save();
      ctxFront.translate(pinX, pinY);
      ctxFront.rotate(restDeg * Math.PI / 180);
      ctxFront.drawImage(this.imgLever, -leverW * spec.leverPivotX, -leverH * spec.leverPivotY, leverW, leverH);
      ctxFront.restore();
    }"""
assert old_front in s
s = s.replace(old_front, new_front, 1)

# end assignment
rep("""    this.machineLayer = off.transferToImageBitmap();
    this.machineBuildCount++;""",
"""    this.machineLayer = off.transferToImageBitmap();
    this.machineFrontLayer = offFront.transferToImageBitmap();
    this.machineBuildCount++;""")

# draw order
rep("""    if (this.machineLayer !== null) {
      ctx.drawImage(this.machineLayer, 0, 0);
    }
    if (this.paperLayer !== null) {""",
"""    if (this.machineLayer !== null) {
      ctx.drawImage(this.machineLayer, 0, 0);
    }
    if (this.paperLayer !== null) {""")

rep("""      ctx.drawImage(this.paperLayer, this.paperX(), this.paperY());
      ctx.restore();
    }
  }""",
"""      ctx.drawImage(this.paperLayer, this.paperX(), this.paperY());
      ctx.restore();
    }
    if (this.machineFrontLayer !== null) {
      ctx.drawImage(this.machineFrontLayer, 0, 0);
    }
  }""")

# geometry log in aboutToAppear
rep("""  aboutToAppear(): void {
    this.prepare();
  }""",
"""  aboutToAppear(): void {
    hilog.info(CDOMAIN, CTAG,
      'layout W=%{public}s H=%{public}s top=%{public}s bottom=%{public}s Pw=%{public}s paperTop=%{public}s paperBox=%{public}s carrTop=%{public}s Hc=%{public}s strike=%{public}s fs=%{public}s lh=%{public}s',
      this.widthVp.toFixed(1), this.heightVp.toFixed(1), this.topInset.toFixed(1), this.bottomInset.toFixed(1),
      this.paperWidthVp.toFixed(1), this.paperTopVp.toFixed(1), this.paperContainerVp.toFixed(1),
      this.carriageTopVp.toFixed(1), this.carriageHeightVp.toFixed(1), this.strikeLineVp.toFixed(1),
      this.fontSizeVp.toFixed(1), this.lineHeightVp.toFixed(1));
    this.prepare();
  }""")

io.open(p, 'w', encoding='utf-8', newline='\r\n').write(s)
print('canvas layer split + log ok')
