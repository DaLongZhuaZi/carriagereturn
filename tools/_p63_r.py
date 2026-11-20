# 批 63 N6：在 2263 截图上按像素找槽（dump 里没有就用像素判可见性）
from PIL import Image

im = Image.open(r'D:\HarmonyAPP\carriagereturn\docs\shots\2263_p63_N6_slot_after_fix.png').convert('RGB')
px = im.load()
W, H = im.size
# 代码声明的屏上位置：x 1170..1235、y 149..164（TopZone 局部 300*sx/14*sy + machineOffset 236）
x0, x1, y0, y1 = 1150, 1250, 130, 185
dark = [(x, y) for y in range(y0, y1) for x in range(x0, x1) if sum(px[x, y]) < 120]
print('dark px in declared rect:', len(dark), 'bbox:', (min(p[0] for p in dark), min(p[1] for p in dark),
      max(p[0] for p in dark), max(p[1] for p in dark)) if dark else None)
# 全顶区扫一遍，看有没有任何 60+px 宽的深色横条
bands = []
for y in range(110, 320, 2):
    xs = [x for x in range(200, 1580) if sum(px[x, y]) < 120]
    if len(xs) > 40:
        bands.append((y, xs[0], xs[-1], len(xs)))
print('dark bands in top zone:', bands[:5])
# 顺带看看 y 140..175 这一条带的平均色（判断有没有“深色但被盖住”的痕迹）
row = [px[x, 155] for x in range(1160, 1245, 8)]
print('row y=155 colors:', row[:8])
