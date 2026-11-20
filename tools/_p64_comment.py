# 批 64（任务 8）：清掉 Parts26.ets 里过期的 N6 注释，按现状重写
import io

P = r'entry/src/main/ets/components/type26/Parts26.ets'
lines = io.open(P, encoding='utf-8').read().split('\n')

idx = None
for i, ln in enumerate(lines):
    if "p26_export_slot" in ln:
        idx = i
        break
if idx is None:
    raise SystemExit('id line not found')

# 往上收集紧邻的“批 63”注释行（含旧诊断文字）
start = idx
while start - 1 >= 0:
    prev = lines[start - 1].strip()
    if prev.startswith('//') and ('批 63' in prev):
        start -= 1
    else:
        break

NEW = [
    '      // 出纸槽（TopZone 行内右侧）：局部坐标 x=300·sx、y=48·sy，宽 50·sx、高 12·sy。',
    '      // 位置依据：批 63 实测 y=14·sy 会被画到状态栏底下（节点落在 y≈76px、屏上不可见），',
    '      // 对齐到返回拨杆同一行（48·sy）后落到可见区 y≈149px、点按生效；批 64 重建 TopZone 为 flex 行时，',
    '      // 槽改为行内右侧子项、不再按局部坐标算屏上位置。点按行为：导出 txt ＋ 300ms 纸片滑出（hilog 计时可证）。',
]
lines = lines[:start] + NEW + lines[idx:]
io.open(P, 'w', encoding='utf-8').write('\n'.join(lines))
print('replaced old N6 comments: removed', idx - start, 'lines ->', len(NEW))
