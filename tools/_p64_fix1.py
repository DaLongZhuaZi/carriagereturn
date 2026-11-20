# 批 64：键盘井用换算表精确高度（不用 layoutWeight(1)），保证列总高＝availH
import io

P = r'entry/src/main/ets/components/type26/Stage26.ets'
s = io.open(P, encoding='utf-8').read()
old = "        Column() { this.keyZone() }.width('100%').layoutWeight(1)"
new = "        Column() { this.keyZone() }.width('100%').height(this.layout.keyH)"
if old not in s:
    raise SystemExit('anchor missing')
io.open(P, 'w', encoding='utf-8').write(s.replace(old, new, 1))
print('key zone -> fixed height(layout.keyH)')
