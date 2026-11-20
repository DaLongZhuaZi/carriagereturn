# 批 64（T4）：KeyGrid 逐键 .position → 纵向 flex（每行 Row + SpaceBetween，键帽固定尺寸）。
import io

P = 'entry/src/main/ets/components/KeyGrid.ets'
s = io.open(P, encoding='utf-8').read()

NEW = '''  /** 键帽（一个原生 Button；尺寸固定，不随 sx/sy 缩放——设计稿 §3.4）。 */
  @Builder
  capCell(p: K33Placed) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Stack() {
        this.capImage(p)
        // 批 42：帽底接触影＋顶面内凹
        Column().width('88%').height(1)
          .backgroundColor('#000000').opacity(0.08)
          .position({ x: '6%', y: '97%' })
          .hitTestBehavior(HitTestMode.None)
        Column().width('62%').height('52%')
          .backgroundColor('#000000').opacity(0.05)
          .borderRadius(6)
          .hitTestBehavior(HitTestMode.None)
        if (p.sub.length > 0 && p.kind === 'k') {
          Column() {
            Text(p.legend).fontSize(11).fontColor('#1a1a1a')
              .fontFamily(this.overlayFontFamily).maxLines(1)
            Text(p.sub).fontSize(8).fontColor('#3a3630')
              .fontFamily(this.overlayFontFamily).maxLines(1)
          }
          .justifyContent(FlexAlign.Center)
          .width('100%').height('100%')
          .translate({ y: -KB_LEGEND_UP })
          .hitTestBehavior(HitTestMode.None)
        } else if (p.kind === 'caps') {
          Column() {
            Text('SHIFT').fontSize(6.5).fontColor('#1a1a1a')
              .fontFamily(this.overlayFontFamily).maxLines(1)
            Text('LOCK').fontSize(6.5).fontColor('#1a1a1a')
              .fontFamily(this.overlayFontFamily).maxLines(1)
          }
          .justifyContent(FlexAlign.Center)
          .width('100%').height('100%')
          .translate({ y: -KB_LEGEND_UP })
          .hitTestBehavior(HitTestMode.None)
        } else {
          Text(p.legend)
            .fontSize(this.labelSize(p))
            .fontColor(p.kind === 'return' ? '#ffffff' : '#1a1a1a')
            .fontFamily(this.overlayFontFamily)
            .width('100%').textAlign(TextAlign.Center).maxLines(1)
            .translate({ y: -KB_LEGEND_UP })
            .hitTestBehavior(HitTestMode.None)
        }
      }
      .width('100%').height('100%')
    }
    .padding(0)
    .width(p.w)
    .height(KB_CAP_H)
    .backgroundColor(Color.Transparent)
    .borderRadius(0)
    .accessibilityText(p.legend.length > 0 ? p.legend : p.label)
    .accessibilityLevel('yes')
    .accessibilityDescription(p.sub.length > 0 ? p.sub : p.label)
    // 批 61 口径保留，幅度改绝对值（设计稿 §3.4：行程 2／空格 3vp，scaleY 0.94）
    .translate({ y: this.pressedId === p.id ? (p.kind === 'space' ? 3 : 2) : 0 })
    .scale({ y: this.pressedId === p.id ? 0.94 : 1 })
    .animation({ duration: 90, curve: curves.springMotion(0.34, 0.9) })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressedId = p.id;
        this.onCapDown(this.capFor(p));
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressedId = '';
        this.onCapUp(this.capFor(p));
      }
    })
  }

  /** 某一行的键（沿用 placed() 的 id／图例，供 CapDef 与无障碍用）。 */
  private placedRow(r: number): K33Placed[] {
    const rows: K33Row[] = this.rows();
    if (r < 0 || r >= rows.length) {
      return [];
    }
    const prefix: string = (this.symbolMode ? 'S' : 'L') + ':' + rows[r].y.toString() + ':';
    return this.placed().filter((p: K33Placed) => p.id.indexOf(prefix) === 0);
  }

  build() {
    // 批 64（T4）：键盘井内容改纵向 flex——每行 `Row(justifyContent: SpaceBetween)`；
    // 键帽固定尺寸（不随 sx/sy 缩放，手机／平板一致），多余宽度全部由行内间距吸收；
    // layoutWeight 不挂键帽（固定宽子项挂 layoutWeight 会被拉伸），只用于「间距」这一层。
    // 间距上限 1.5×键宽：平板实测间距≈9.4vp、键宽 21.6vp，不触发（触发时改 Center＋固定间距）。
    Column() {
      ForEach(this.rows(), (row: K33Row, r: number) => {
        Row() {
          ForEach(this.placedRow(r), (p: K33Placed) => {
            this.capCell(p)
          }, (p: K33Placed) => p.id)
        }
        .width('100%')
        .height(KB_ROW_H)
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: r < this.rows().length - 1 ? KB_VGAP : 0 })
      }, (row: K33Row, r: number) => 'row' + r.toString())
    }
    .width('100%')
    .height('100%')
    .padding({ left: KB_X0, right: KB_X0 })
    .justifyContent(FlexAlign.Center)
  }
}
'''

i = s.index('  build() {')
s = s[:i] + NEW
io.open(P, 'w', encoding='utf-8').write(s)
print('KeyGrid flex build written')
