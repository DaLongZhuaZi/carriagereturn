import io

p = 'entry/src/main/ets/components/ExportTemplate.ets'
s = io.open(p, encoding='utf-8', newline=None).read()

def rep(old, new):
    global s
    if old not in s:
        raise SystemExit('MISS in template: %r' % old[:90])
    s = s.replace(old, new, 1)

# 标题 + 卷宗名
rep("""        Text(this.title)
        .fontSize(EXPORT_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(INK)
        .width(FRAME_W).height(EXPORT_TITLE_H).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .position({ x: EXPORT_MARGIN_X, y: this.layout().titleY })

      }""",
"""        Column() {
          Text(this.title)
            .fontSize(EXPORT_TITLE_SIZE).fontWeight(FontWeight.Bold)
            .fontColor(this.inkColor.length > 0 ? this.inkColor : INK)
            .fontFamily(this.fontFamily)
            .width('100%').maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.dossierName.length > 0) {
            Text(this.dossierName)
              .fontSize(22).fontColor(INK_SOFT).fontFamily(this.fontFamily)
              .width('100%').maxLines(1).margin({ top: 2 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width(FRAME_W).height(EXPORT_TITLE_H)
        .position({ x: EXPORT_MARGIN_X, y: this.layout().titleY })
      }""")

# 日期跟随字体
rep("""        Text(this.dateText)
        .fontSize(EXPORT_DATE_SIZE).fontColor(INK_SOFT)""",
"""        Text(this.dateText)
        .fontSize(EXPORT_DATE_SIZE).fontColor(INK_SOFT).fontFamily(this.fontFamily)""")

# 正文跟随墨色与字体
rep("""        Text(this.bodyText())
          .fontSize(EXPORT_BODY_SIZE).lineHeight(EXPORT_BODY_LINE).fontColor(INK)""",
"""        Text(this.bodyText())
          .fontSize(EXPORT_BODY_SIZE).lineHeight(EXPORT_BODY_LINE)
          .fontColor(this.inkColor.length > 0 ? this.inkColor : INK)
          .fontFamily(this.fontFamily)""")

io.open(p, 'w', encoding='utf-8', newline='\r\n').write(s)
print('template ok')

# ---------------- ExportPage：范围行 + PNG 置灰 ----------------
p2 = 'entry/src/main/ets/components/ExportPage.ets'
s2 = io.open(p2, encoding='utf-8', newline=None).read()

def rep2(old, new):
    global s2
    if old not in s2:
        raise SystemExit('MISS in page: %r' % old[:90])
    s2 = s2.replace(old, new, 1)

rep2("""  @Builder
  formatRows() {""",
"""  /** 第 13 批 ⑥：范围选择（当前纸／整篇／整卷宗；缺省整篇）。 */
  @Builder
  rangeRow() {
    Row() {
      this.rangeChip('paper', $r('app.string.export_range_paper'))
      this.rangeChip('doc', $r('app.string.export_range_doc'))
      if (this.dossierId.length > 0) {
        this.rangeChip('dossier', $r('app.string.export_range_dossier'))
      }
    }
    .width('100%')
    .margin({ top: 12, bottom: 4 })
  }

  @Builder
  rangeChip(key: string, label: ResourceStr) {
    Text(label)
      .fontSize(14)
      .fontColor(this.range === key ? '#e8ddc9' : 'rgba(232,221,201,0.55)')
      .layoutWeight(1).height(40).textAlign(TextAlign.Center)
      .borderRadius(20)
      .backgroundColor(this.range === key ? '#2e2620' : '#241c16')
      .border({ width: 1, color: this.range === key ? '#c9a45c' : 'rgba(232,221,201,0.12)' })
      .onClick(() => {
        if (this.isBusy() || this.range === key) {
          return;
        }
        this.range = key;
        this.refreshPreview();
      })
  }

  @Builder
  formatRows() {""")

rep2("""            Text(f.label).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#e8ddc9')
            Text(f.desc).fontSize(12).fontColor('rgba(232,221,201,0.6)').margin({ top: 4 })""",
"""            Text(f.label).fontSize(17).fontWeight(FontWeight.Bold)
              .fontColor(this.fmtDisabled(f.id) ? 'rgba(232,221,201,0.3)' : '#e8ddc9')
            Text(f.desc).fontSize(12).fontColor('rgba(232,221,201,0.6)').margin({ top: 4 })
            if (this.fmtDisabled(f.id)) {
              Text($r('app.string.export_range_png_hint')).fontSize(11)
                .fontColor('rgba(232,221,201,0.4)').margin({ top: 2 })
            }""")

rep2("""          if (this.isBusy()) {
            return;
          }
          this.picked = idx;
        })""",
"""          if (this.isBusy() || this.fmtDisabled(f.id)) {
            return;
          }
          this.picked = idx;
        })""")

rep2("""  /** 第 13 批 ⑥：范围切换后重算预览，并把 PNG 从「非当前纸」范围强制回 PDF。 */""",
"""  /** 第 13 批 ⑥：PNG 只在「当前纸」范围可用（整篇/整卷宗置灰）。 */
  private fmtDisabled(id: string): boolean {
    return id === 'image' && this.range !== 'paper';
  }

  /** 第 13 批 ⑥：范围切换后重算预览，并把 PNG 从「非当前纸」范围强制回 PDF。 */""")

io.open(p2, 'w', encoding='utf-8', newline='\r\n').write(s2)
print('page range ui ok (insert call separately)')
