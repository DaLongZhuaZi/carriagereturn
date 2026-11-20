# 批 63 N6：出纸槽包一层 ≥44vp 的透明热区，onClick 挪到外层热区
import io

P = r'entry/src/main/ets/components/type26/Parts26.ets'
s = io.open(P, encoding='utf-8').read()

OLD = """      Stack({ alignContent: Alignment.TopStart }) {
        Column().width(50 * this.sx).height(10 * this.sy)
          .backgroundColor('#0b0a09')
          .border({ width: 1, color: '#6d6d70' })
          .borderRadius(2)
        Column().width(44 * this.sx).height(3 * this.sy)
          .linearGradient({ direction: GradientDirection.Right, colors: [['#f2ead8', 0.0], ['#cfc4ad', 1.0]] })
          .position({ x: 3 * this.sx, y: 1 * this.sy })
      }
      .width(50 * this.sx).height(12 * this.sy)
      // 批 63 修复（N6）：原来 y=14·sy 会被画到状态栏底下（诊断实测节点落在 y≈76px），
      // 对齐到与返回拨杆同一行（48·sy）后落回可见区 y≈149px。
      .position({ x: 300 * this.sx, y: 48 * this.sy })
      // 批 63 阶段 0（任务 2／N6）修复：该件此前不在渲染树里（同层的返回拨杆在、它不在），
      // 先给它固定 id 便于 dump 取证，并抬到最上层避开任何同层覆盖。
      .id('p26_export_slot')
      // 批 62 收尾：无障碍文本（读屏朗读名与元素一致）
    .accessibilityText('出纸槽')
    .accessibilityLevel('yes')
    .onClick(() => { this.onExportSlot(); })
"""

NEW = """      // 批 63 修复（N6）：出纸槽原来两处口径打架——① 局部 y=14·sy 会被画到状态栏底下
      // （诊断实测节点落在 y≈76px，屏上不可见）；② 热区只有 65×16vp，点按不触发。
      // 现在：包一层 ≥44vp 的透明热区（onClick 挂外层），视觉件对齐到与返回拨杆同一行（48·sy）。
      Stack({ alignContent: Alignment.TopStart }) {
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
        .position({ x: 3 * this.sx, y: 16 * this.sy })
        .hitTestBehavior(HitTestMode.None)
      }
      .width(56 * this.sx).height(44 * this.sy)
      .position({ x: 297 * this.sx, y: 34 * this.sy })
      .id('p26_export_slot')
      // 批 62 收尾：无障碍文本（读屏朗读名与元素一致）
    .accessibilityText('出纸槽')
    .accessibilityLevel('yes')
    .onClick(() => { this.onExportSlot(); })
"""

if OLD not in s:
    raise SystemExit('slot block anchor missing')
s = s.replace(OLD, NEW, 1)
io.open(P, 'w', encoding='utf-8').write(s)
print('slot wrapped in 44vp hit area')
