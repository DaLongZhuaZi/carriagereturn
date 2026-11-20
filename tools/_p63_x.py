# 批 63 N6：对照试验——同层返回拨杆 / 右上帮助钮 / 出纸槽，谁吃点击
import sys, time
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H
from PIL import Image, ImageChops

p0 = H.shot('2270_p63_n6_ctrl_a')
for name, (x, y) in [('lever', (285, 200)), ('help', (1510, 120)), ('slot', (1248, 168))]:
    H.tap(x, y)
    time.sleep(1.6)
    p = H.shot('2271_p63_n6_ctrl_' + name)
    d = round(sum(ImageChops.difference(Image.open(p0).convert('RGB'), Image.open(p).convert('RGB')).convert('L').getdata()) / (1600 * 2560), 2)
    print(name, x, y, 'diff', d)
    p0 = p
