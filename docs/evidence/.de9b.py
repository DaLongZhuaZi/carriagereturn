import io

p = 'entry/src/main/ets/components/DossierDetailPage.ets'
s = io.open(p, encoding='utf-8', newline=None).read()

def rep(old, new):
    global s
    if old not in s:
        raise SystemExit('MISS: %r' % old[:90])
    s = s.replace(old, new, 1)

rep("""  /** 删卷宗：mode='unfile' 纸移出（变未归档）｜'purge' 连纸一起删。 */
  onDeleteDossier: (mode: string) => void = (): void => {};""",
"""  /** 删卷宗：mode='unfile' 纸移出（变未归档）｜'purge' 连纸一起删。 */
  onDeleteDossier: (mode: string) => void = (): void => {};
  /** 第 13 批 ⑥：卷宗导出入口（Index 置 exportTarget 后压导出页）。 */
  onExport: (dossierId: string) => void = (): void => {};""")

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
print('dossier detail ok')

# Index 挂载传 onExport
p2 = 'entry/src/main/ets/pages/Index.ets'
s2 = io.open(p2, encoding='utf-8', newline=None).read()
old = """          onDeleteDossier: (mode: string): void => { this.deleteDossier(this.openDossierId, mode); },"""
new = """          onDeleteDossier: (mode: string): void => { this.deleteDossier(this.openDossierId, mode); },
          onExport: (dossierId: string): void => { this.onExportDossier(dossierId); },"""
assert old in s2, 'index mount miss'
s2 = s2.replace(old, new, 1)
io.open(p2, 'w', encoding='utf-8', newline='\r\n').write(s2)
print('index ok')
