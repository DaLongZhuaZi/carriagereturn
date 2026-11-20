# 批 63 N6：在槽内三点试按，看是否整块都不吃点击
import sys, time
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H
from PIL import Image, ImageChops

p0 = H.shot('2268_p63_N6_probe_a')
for i, (x, y) in enumerate([(1185, 168), (1248, 160), (1310, 180)]):
    H.tap(x, y)
    time.sleep(1.4)
    p = H.shot('2269_p63_N6_probe_%d' % i)
    d = round(sum(ImageChops.difference(Image.open(p0).convert('RGB'), Image.open(p).convert('RGB')).convert('L').getdata()) / (1600 * 2560), 2)
    print(x, y, 'diff', d)
