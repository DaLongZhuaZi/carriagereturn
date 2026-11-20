# 批 64（T8）：TopZone26 改 flex 行（返回拨杆在左、出纸槽在右、Blank 撑开；顶边仍 48·sy）。
import io

P = 'entry/src/main/ets/components/type26/Parts26.ets'
s = io.open(P, encoding='utf-8').read()

NEW = '''  build() {
    // 批 64（T8）：顶栏改 flex 行——返回拨杆在左、出纸槽在右（Blank 撑开），两者顶边都落在 48·sy
    // （批 63 实测：y=14·sy 会被画到状态栏底下，节点 y≈76px、屏上不可见）。
    // 右内距 = 机器宽 − 350·sx，使槽口左缘仍落在 300·sx（N6 的 (1170,149) 不变）。
    Column() {
      Row() {
        // 这里保持最简结构：视觉件本体挂 onClick，不再套热区壳。
        // 返回拨杆（竖钢拨杆＋球头，与边铃横向错开）
        Stack({ alignContent: Alignment.TopStart }) {
          Column().width(4 * this.sx).height(24 * this.sy)
            .linearGradient({ direction: GradientDirection.Right, colors: [[STEEL_HI, 0.0], [STEEL, 0.5], ['#4a4a4d', 1.0]] })
            .borderRadius(2)
            .rotate({ angle: 16 })
            .position({ x: 8 * this.sx, y: 5 * this.sy })
          Column().width(9 * this.sx).height(9 * this.sx)
            .backgroundColor(BRASS_HI)
            .border({ width: 1, color: '#5a4520' })
            .borderRadius(5 * this.sx)
            .position({ x: 4 * this.sx, y: 0 })
        }
        .width(16 * this.sx).height(32 * this.sy)
        .accessibilityText('返回')
        .accessibilityLevel('yes')
        .onClick(() => { this.onBack(); })

        Blank()

        // 出纸槽（行内右侧子项；点按行为＝导出 txt ＋ 300ms 纸片滑出，hilog 三连可证）
        Stack({ alignContent: Alignment.TopStart }) {
          Column().width(50 * this.sx).height(10 * this.sy)
            .backgroundColor('#0b0a09')
            .border({ width: 1, color: '#6d6d70' })
            .borderRadius(2)
          Column().width(44 * this.sx).height(3 * this.sy)
            .linearGradient({ direction: GradientDirection.Right, colors: [['#f2ead8', 0.0], ['#cfc4ad', 1.0]] })
            .position({ x: 3 * this.sx, y: 1 * this.sy })
        }
        .width(50 * this.sx).height(12 * this.sy)
        .id('p26_export_slot')
        .accessibilityText('出纸槽')
        .accessibilityLevel('yes')
        .onClick(() => { this.onExportSlot(); })
      }
      .width('100%')
      .padding({ left: 8 * this.sx, right: this.padRightSlot() })
      .alignItems(VerticalAlign.Top)
    }
    .width(this.widthVp).height(this.heightVp)
    .padding({ top: 48 * this.sy })
    .alignItems(HorizontalAlign.Start)
    .clip(true)
    // 空白处不挡下面字车拨杆的拖拽（子件仍各自可点）
    .hitTestBehavior(HitTestMode.Transparent)
  }

  /** 出纸槽右内距：让槽口左缘落在 300·sx（机器宽不足时保底 4vp）。 */
  private padRightSlot(): number {
    const p: number = this.widthVp - 350 * this.sx;
    return p > 4 ? p : 4;
  }
'''

i = s.index('export struct TopZone26')
j = s.index('  build() {', i)
k = s.index('// ---------------------------------------------------------------------------\n// 盖子', j)
s = s[:j] + NEW + '\n' + s[k:]
io.open(P, 'w', encoding='utf-8').write(s)
print('TopZone26 flex row written')
