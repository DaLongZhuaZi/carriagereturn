import io

p = 'entry/src/main/ets/components/ExportPage.ets'
s = io.open(p, encoding='utf-8', newline=None).read()

def rep(old, new):
    global s
    if old not in s:
        raise SystemExit('MISS: %r' % old[:90])
    s = s.replace(old, new, 1)

# ---- buildFor：text 分支支持整卷宗 ----
rep("""    if (fmt.id === 'text') {
      const r: ExportResult = ExportService.buildTxt(this.docId);
      return { ok: r.ok, bytes: r.bytes, path: '', error: r.error };
    }""",
"""    if (fmt.id === 'text') {
      if (this.range === 'dossier' && this.dossierId.length > 0) {
        const docs: DocSummary[] = docStore.listByDossier(this.dossierId);
        const texts: string[] = [];
        for (const sum of docs) {
          const dd: DocData | null = docStore.load(sum.id);
          const groups: string[][] = this.groupsOf(dd);
          const archived: string[][] = groups.length > 0 ? groups.slice(0, groups.length - 1) : [];
          const cur: string[] = groups.length > 0 ? groups[groups.length - 1] : [];
          texts.push(assembleSheetText(archived, cur));
        }
        const rt: ExportResult = ExportService.buildTxtFromText(assembleDossierText(texts));
        return { ok: rt.ok, bytes: rt.bytes, path: '', error: rt.error };
      }
      const r: ExportResult = ExportService.buildTxt(this.docId);
      return { ok: r.ok, bytes: r.bytes, path: '', error: r.error };
    }""")

# ---- buildFor：PDF 逐页计划（含整卷宗） ----
rep("""      const groups: string[][] = this.pageGroups();
      const total: number = groups.length;
      const pngPaths: string[] = [];
      let allOk: boolean = true;
      for (let pi = 0; pi < total; pi++) {
        this.pageLines = groups[pi].slice(0, EXPORT_BODY_LINES);
        this.pageNo = pi + 1;
        this.pageTotal = total;
        const t: ExportResult = await ExportService.buildPngTemplate(ui, this.docId, this.machineKind,
          this.docTitleState, this.dateText, (): void => { this.templateBuilder(); });""",
"""      const plans: PagePlan[] = this.pagePlans();
      const total: number = plans.length;
      const pngPaths: string[] = [];
      let allOk: boolean = true;
      for (let pi = 0; pi < total; pi++) {
        const plan: PagePlan = plans[pi];
        this.pageLines = plan.lines.slice(0, EXPORT_BODY_LINES);
        this.pageNo = plan.pageNo;
        this.pageTotal = plan.pageTotal;
        this.pageTitle = plan.title;
        this.pageDate = plan.dateText;
        this.pageDossier = plan.dossierName;
        const t: ExportResult = await ExportService.buildPngTemplate(ui, plan.docId, this.machineKind,
          plan.title, plan.dateText, (): void => { this.templateBuilder(); });""")

# ---- buildFor：图片分支用计划首页 ----
rep("""    const imgGroups: string[][] = this.pageGroups();
    this.pageLines = imgGroups.length > 0 ? imgGroups[0].slice(0, EXPORT_BODY_LINES) : [];
    this.pageNo = 1;
    this.pageTotal = Math.max(1, imgGroups.length);""",
"""    const imgPlans: PagePlan[] = this.pagePlans();
    this.pageLines = imgPlans.length > 0 ? imgPlans[0].lines.slice(0, EXPORT_BODY_LINES) : [];
    this.pageNo = 1;
    this.pageTotal = Math.max(1, imgPlans.length);
    this.pageTitle = imgPlans.length > 0 ? imgPlans[0].title : this.docTitleState;
    this.pageDate = imgPlans.length > 0 ? imgPlans[0].dateText : this.dateText;
    this.pageDossier = imgPlans.length > 0 ? imgPlans[0].dossierName : '';""")

# ---- builder 用逐页字段 ----
rep("""      ExportTemplate({
        docId: this.docId,
        machineKind: this.machineKind,
        title: this.docTitleState,
        dateText: this.dateText,
        sheetLines: this.pageLines,
        pageNo: this.pageNo,
        pageTotal: this.pageTotal,
      })""",
"""      ExportTemplate({
        docId: this.docId,
        machineKind: this.machineKind,
        title: this.pageTitle,
        dateText: this.pageDate,
        dossierName: this.pageDossier,
        sheetLines: this.pageLines,
        pageNo: this.pageNo,
        pageTotal: this.pageTotal,
      })""")

io.open(p, 'w', encoding='utf-8', newline='\r\n').write(s)
print('exportpage part2 ok')
