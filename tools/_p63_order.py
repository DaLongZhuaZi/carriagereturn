# 批 63 N6：把出纸槽挪成 TopZone 的第一个子件（拨杆在后），测点击是否恢复
import io

P = r'entry/src/main/ets/components/type26/Parts26.ets'
s = io.open(P, encoding='utf-8').read()

LEVER_START = s.find('      // 返回拨杆（x 8–24，y 48–80）')
SLOT_START = s.find('      // 批 63 修复（N6）：槽原来局部 y=14·sy')
SLOT_END_MARK = ".onClick(() => { this.onExportSlot(); })\n"
SLOT_END = s.find(SLOT_END_MARK, SLOT_START) + len(SLOT_END_MARK)

if LEVER_START < 0 or SLOT_START < 0 or SLOT_END <= 0:
    raise SystemExit('anchors missing')

lever_block = s[LEVER_START:SLOT_START]
slot_block = s[SLOT_START:SLOT_END]
s = s[:LEVER_START] + slot_block + lever_block + s[SLOT_END:]
io.open(P, 'w', encoding='utf-8').write(s)
print('slot moved before lever in TopZone')
