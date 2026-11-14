import io
p = 'entry/src/main/ets/components/CanvasTypewriter.ets'
s = io.open(p, encoding='utf-8', newline=None).read()

def rep(old, new):
    global s
    if old not in s:
        raise SystemExit('MISS %r' % old[:120])
    s = s.replace(old, new, 1)

rep("""  @Prop machineKind: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop paperKind: PaperKind = PaperKind.LETTER;""",
"""  @Prop @Watch('onMachineKindChanged') machineKind: MachineKind = MachineKind.UPRIGHT_1920S;
  @Prop @Watch('onPaperKindChanged') paperKind: PaperKind = PaperKind.LETTER;""")

# add watch methods after aboutToAppear
rep("""  aboutToAppear(): void {
    hilog.info(CDOMAIN, CTAG,""",
"""  /** 2A-4：换机只重建机器层；换纸只重建纸层。 */
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
    hilog.info(CDOMAIN, CTAG,""")

# split prepare into loadMachineImages/loadPaperImage
old_prepare = """  private async prepare(): Promise<void> {
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
    this.imgKeyband = await this.loadRaw(this.keybandPath());
    this.imgPaper = await this.loadRaw(this.paperSpec().textureRawfile);
    try {
      const kmBytes: Uint8Array = getContext(this).resourceManager.getRawFileContentSync(this.spec().keymapRawfile);
      const kmText: string = this.utf8ToString(kmBytes);
      this.keymap = KeymapParser.parse(kmText, this.machineKind as string, false, this.keybedWidth(),
        this.keybedHeightVp, this.spec().overlayColor, this.spec().overlayFontSizeVp);
    } catch (e) {
      hilog.error(CDOMAIN, CTAG, 'keymap load failed');
    }
    this.ready = true;
    this.buildStaticLayers();
    this.draw();
  }"""
new_prepare = """  private async loadMachineImages(): Promise<void> {
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
  }"""
assert old_prepare in s
s = s.replace(old_prepare, new_prepare, 1)

io.open(p, 'w', encoding='utf-8', newline='\r\n').write(s)
print('watch rebuild ok')
