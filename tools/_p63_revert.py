# 批 63 N6：回退到最简结构（视觉件本体挂 onClick），x 回到 300·sx
import io

P = r'entry/src/main/ets/components/type26/Parts26.ets'
s = io.open(P, encoding='utf-8').read()

start = s.find('      // 批 63 修复（N6）：出纸槽原来两处口径打架')
end = s.find("    .eligibilityPlaceholder", start)
if end < 0:
    end = s.find(".onClick(() => { this.onExportSlot(); })", start)
    end = end + len(".onClick(() => { this.onExportSlot(); })\n") if end > 0 else -1
if start < 0 or end < 0:
    raise SystemExit('block bounds not found')

NEW = """      // 批 63 修复（N6）：槽原来局部 y=14·sy 会被画到状态栏底下（实测节点 y≈76px，屏上不可见）；
      // 对齐到与返回拨杆同一行（48·sy）后落在可见区 y≈149px。点击问题仍在（见自检 N6 诊断），
      // 这里保持最简结构：视觉件本体挂 onClick，不再套热区壳。
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
      .position({ x: 300 * this.sx, y: 48 * this.sy })
      .id('p26_export_slot')
      // 批 62 收尾：无障碍文本（读屏朗读名与元素一致）
    .accessibilityText('出纸槽')
    .accessibilityLevel('yes')
    .onClick(() => { this.onExportSlot(); })
"""

s = s[:start] + NEW + s[end:]
io.open(P, 'w', encoding='utf-8').write(s)
print('slot block restored (simple, x=300*sx, y=48*sy)')
