import io

# ---------- DossierDetailPage：导出按钮 ----------
p = 'entry/src/main/ets/components/DossierDetailPage.ets'
s = io.open(p, encoding='utf-8', newline=None).read()

def rep(old, new):
    global s
    if old not in s:
        raise SystemExit('MISS in dossier page: %r' % old[:80])
    s = s.replace(old, new, 1)

rep("""  @Prop onRenamePaper""", """  /** 第 13 批 ⑥：卷宗导出入口（Index 置 exportTarget 后压导出页）。 */
  @Prop onExport: (dossierId: string) => void = (): void => {};
  @Prop onRenamePaper""")

# 页眉右侧：导出 + 新建纸张（导出放前面，与「新建纸张」并列）
rep("""          // D13：手机端「新建纸张」收进 ⋯ 菜单，不再挤页眉
          if (this.widthVp >= 600) {
            Text('新建纸张').fontSize(12).fontColor('#e8ddc9')""",
"""          // 第 13 批 ⑥：导出按钮（与「新建纸张」并列）
          if (this.widthVp >= 600) {
            Text($r('app.string.page_export')).fontSize(12).fontColor('#e8ddc9')
              .id('dossier_detail__export_btn')
              .padding({ left: 14, right: 14, top: 7, bottom: 7 })
              .borderRadius(28).backgroundColor('#2e2620')
              .margin({ left: 8 })
              .onClick(() => { this.onExport(this.dossierId); })
          }
          // D13：手机端「新建纸张」收进 ⋯ 菜单，不再挤页眉
          if (this.widthVp >= 600) {
            Text('新建纸张').fontSize(12).fontColor('#e8ddc9')""")

io.open(p, 'w', encoding='utf-8', newline='\r\n').write(s)
print('dossier detail export btn ok')

# ---------- Index：传 onExport ----------
p2 = 'entry/src/main/ets/pages/Index.ets'
s2 = io.open(p2, encoding='utf-8', newline=None).read()
rep2_old = """          onDeleteDossier: (mode: string): void => { this.deleteDossier(this.openDossierId, mode); },"""
rep2_new = """          onDeleteDossier: (mode: string): void => { this.deleteDossier(this.openDossierId, mode); },
          onExport: (dossierId: string): void => { this.onExportDossier(dossierId); },"""
assert rep2_old in s2
s2 = s2.replace(rep2_old, rep2_new, 1)
io.open(p2, 'w', encoding='utf-8', newline='\r\n').write(s2)
print('index dossier export wiring ok')
