import io
p = 'entry/src/main/ets/components/ExportPage.ets'
s = io.open(p, encoding='utf-8', newline=None).read()

def rep(old, new, count=1):
    global s
    if old not in s:
        raise SystemExit('MISS: %r' % old[:90])
    s = s.replace(old, new, count)

# imports + 状态 + aboutToAppear 读取目标
rep("import { CustomizeStore } from '../services/CustomizeStore';",
    "import { CustomizeStore } from '../services/CustomizeStore';\nimport { ExportTargetData, getExportTarget } from '../model/ExportTarget';")

rep("""  /** 第 13 批 ⑥：范围 'paper' | 'doc' | 'dossier'，初值取 scope（'' → 'doc' 整篇）。 */
  @State range: string = '';""",
"""  /** 第 13 批 ⑥：范围 'paper' | 'doc' | 'dossier'，初值取 scope（'' → 'doc' 整篇）。 */
  @State range: string = '';
  /** 第 13 批 ⑥：生效的导出目标（优先模块级传递，兜底用挂载 props）。 */
  @State targetScope: string = '';
  @State targetDossierId: string = '';
  @State targetDocId: string = '';""")

rep("""    this.disposed = false;
    this.phase = PHASE_IDLE;""",
"""    this.disposed = false;
    this.phase = PHASE_IDLE;
    // 第 13 批 ⑥：导出目标以模块级传递为准（@Prop 在「置状态＋立即压栈」时会拿到旧值）
    const tg: ExportTargetData = getExportTarget();
    this.targetScope = tg.scope.length > 0 ? tg.scope : this.scope;
    this.targetDossierId = tg.dossierId.length > 0 ? tg.dossierId : this.dossierId;
    this.targetDocId = tg.docId.length > 0 ? tg.docId : this.docId;""")

# 全局替换 dossier 目标与文档目标读取
s = s.replace("this.range === 'dossier' && this.dossierId.length > 0", "this.range === 'dossier' && this.targetDossierId.length > 0")
s = s.replace("docStore.listByDossier(this.dossierId)", "docStore.listByDossier(this.targetDossierId)")
s = s.replace("    if (this.dossierId.length === 0) {", "    if (this.targetDossierId.length === 0) {")
s = s.replace("      if (ds.id === this.dossierId) {", "      if (ds.id === this.targetDossierId) {")
s = s.replace("this.onBeforeExport(this.range, this.dossierId)", "this.onBeforeExport(this.range, this.targetDossierId)")
s = s.replace("      this.scope, this.dossierId, this.docId);", "      this.targetScope, this.targetDossierId, this.targetDocId);")
s = s.replace("this.range = this.scope.length === 0 ? 'doc' : this.scope;",
              "this.range = this.targetScope.length === 0 ? 'doc' : this.targetScope;")
s = s.replace("      if (this.dossierId.length > 0) {", "      if (this.targetDossierId.length > 0) {")
# 文档加载：目标文档优先
s = s.replace("const d: DocData | null = this.docId.length > 0 ? docStore.load(this.docId) : null;",
              "const d: DocData | null = this.targetDocId.length > 0 ? docStore.load(this.targetDocId) : null;")

io.open(p, 'w', encoding='utf-8', newline='\r\n').write(s)
print('export page target ok2')
