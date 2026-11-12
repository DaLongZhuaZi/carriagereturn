import io

# ---------------- Index：写入模块目标、恢复同步压栈 ----------------
p = 'entry/src/main/ets/pages/Index.ets'
s = io.open(p, encoding='utf-8', newline=None).read()

def rep(old, new):
    global s
    if old not in s:
        raise SystemExit('MISS in index: %r' % old[:80])
    s = s.replace(old, new, 1)

rep("import { ExportPage, guideStepsForExport } from '../components/ExportPage';",
    "import { ExportPage, guideStepsForExport } from '../components/ExportPage';\nimport { setExportTarget } from '../model/ExportTarget';")

rep("""  private onExportDoc(docId: string): void {
    this.exportDocId = docId;
    this.exportDossierId = '';
    this.exportScope = 'doc';
    // 状态与压栈同一 tick 时子组件拿不到新 prop（实测 ExportPage 读到空 dossierId），下一帧再压
    setTimeout(() => { this.pushPage('export'); }, 60);
  }""",
"""  private onExportDoc(docId: string): void {
    this.exportDocId = docId;
    this.exportDossierId = '';
    this.exportScope = 'doc';
    // 目标走模块级传递（见 model/ExportTarget），页面 prop 时序不再影响
    setExportTarget({ docId: docId, dossierId: '', scope: 'doc' });
    this.pushPage('export');
  }""")

rep("""  private onExportDossier(dossierId: string): void {
    hilog.info(DOMAIN, TAG, 'onExportDossier id=%{public}s', dossierId);
    this.exportDocId = '';
    this.exportDossierId = dossierId;
    this.exportScope = 'dossier';
    setTimeout(() => { this.pushPage('export'); }, 60);
  }""",
"""  private onExportDossier(dossierId: string): void {
    hilog.info(DOMAIN, TAG, 'onExportDossier id=%{public}s', dossierId);
    this.exportDocId = '';
    this.exportDossierId = dossierId;
    this.exportScope = 'dossier';
    setExportTarget({ docId: '', dossierId: dossierId, scope: 'dossier' });
    this.pushPage('export');
  }""")

# 恢复 openDossier / openDoc 同步压栈
rep("""          onOpenDossier: (id: string): void => {
            this.openDossierId = id;
            hilog.info(DOMAIN, TAG, 'onOpenDossier id=%{public}s', id);
            // 与压栈同 tick 时 @Prop 会拿到旧值（实测卷宗内页 dossierId 为空），下一帧再压
            setTimeout(() => { this.pushPage('detail'); }, 60);
          },""",
"""          onOpenDossier: (id: string): void => {
            this.openDossierId = id;
            hilog.info(DOMAIN, TAG, 'onOpenDossier id=%{public}s', id);
            this.pushPage('detail');
          },""")

rep("""          onOpenDoc: (id: string): void => {
            this.openDocId = id;
            setTimeout(() => { this.pushPage('docview'); }, 60);
          },""",
"""          onOpenDoc: (id: string): void => {
            this.openDocId = id;
            this.pushPage('docview');
          },""")

io.open(p, 'w', encoding='utf-8', newline='\r\n').write(s)
print('index target module ok')

# ---------------- ExportPage：aboutToAppear 读模块目标 ----------------
p2 = 'entry/src/main/ets/components/ExportPage.ets'
s2 = io.open(p2, encoding='utf-8', newline=None).read()

def rep2(old, new):
    global s2
    if old not in s2:
        raise SystemExit('MISS in page: %r' % old[:80])
    s2 = s2.replace(old, new, 1)

rep2("import { CustomizeStore } from '../services/CustomizeStore';",
     "import { CustomizeStore } from '../services/CustomizeStore';\nimport { ExportTargetData, getExportTarget } from '../model/ExportTarget';")

rep2("""  /** 第 13 批 ⑥：范围 'paper' | 'doc' | 'dossier'，初值取 scope（'' → 'doc' 整篇）。 */
  @State range: string = '';""",
"""  /** 第 13 批 ⑥：范围 'paper' | 'doc' | 'dossier'，初值取 scope（'' → 'doc' 整篇）。 */
  @State range: string = '';
  /** 第 13 批 ⑥：生效的导出目标（优先模块级传递，兜底用挂载 props）。 */
  @State targetScope: string = '';
  @State targetDossierId: string = '';
  @State targetDocId: string = '';""")

rep2("""    this.disposed = false;
    this.phase = PHASE_IDLE;""",
"""    this.disposed = false;
    this.phase = PHASE_IDLE;
    // 第 13 批 ⑥：导出目标以模块级传递为准（@Prop 在「置状态＋立即压栈」时会拿到旧值）
    const tg: ExportTargetData = getExportTarget();
    this.targetScope = tg.scope.length > 0 ? tg.scope : this.scope;
    this.targetDossierId = tg.dossierId.length > 0 ? tg.dossierId : this.dossierId;
    this.targetDocId = tg.docId.length > 0 ? tg.docId : this.docId;""")

# 用 target* 替换关键读取点
rep2("    this.range = this.scope.length === 0 ? 'doc' : this.scope;",
     "    this.range = this.targetScope.length === 0 ? 'doc' : this.targetScope;")
rep2("      this.scope, this.dossierId, this.docId);",
     "      this.targetScope, this.targetDossierId, this.targetDocId);")
rep2("      if (this.range === 'dossier' && this.dossierId.length > 0) {\n        const docs: DocSummary[] = docStore.listByDossier(this.dossierId);",
     "      if (this.range === 'dossier' && this.targetDossierId.length > 0) {\n        const docs: DocSummary[] = docStore.listByDossier(this.targetDossierId);")
rep2("    if (this.dossierId.length === 0) {\n      return '';\n    }\n    const list = dossierStore.list();\n    for (const ds of list) {\n      if (ds.id === this.dossierId) {",
     "    if (this.targetDossierId.length === 0) {\n      return '';\n    }\n    const list = dossierStore.list();\n    for (const ds of list) {\n      if (ds.id === this.targetDossierId) {")
rep2("      if (this.range === 'dossier' && this.dossierId.length > 0) {\n        const docs: DocSummary[] = docStore.listByDossier(this.dossierId);\n        const texts: string[] = [];",
     "      if (this.range === 'dossier' && this.targetDossierId.length > 0) {\n        const docs: DocSummary[] = docStore.listByDossier(this.targetDossierId);\n        const texts: string[] = [];")
rep2("    if (this.range === 'dossier' && this.dossierId.length > 0) {\n      const docs: DocSummary[] = docStore.listByDossier(this.dossierId);\n      const dn: string = this.dossierNameOf();",
     "    if (this.range === 'dossier' && this.targetDossierId.length > 0) {\n      const docs: DocSummary[] = docStore.listByDossier(this.targetDossierId);\n      const dn: string = this.dossierNameOf();")
rep2("        const dni = null;\n", "        const dni = null;\n") if False else None

# onBeforeExport 调用也换成 target 值
s2 = s2.replace("this.onBeforeExport(this.range, this.dossierId)", "this.onBeforeExport(this.range, this.targetDossierId)")
# docId 读取：目标文档优先
s2 = s2.replace("const d: DocData | null = this.docId.length > 0 ? docStore.load(this.docId) : null;",
                "const d: DocData | null = this.targetDocId.length > 0 ? docStore.load(this.targetDocId) : null;")

io.open(p2, 'w', encoding='utf-8', newline='\r\n').write(s2)
print('export page target ok')
