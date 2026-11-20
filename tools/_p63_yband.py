# 批 63 N6：沿 y 逐点点按（同 x=1248），量出“死带下界”，并看槽何时能吃到点击
import sys, time
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H
from PIL import Image, ImageChops


def diff(p1, p2):
    a = Image.open(p1).convert('RGB')
    b = Image.open(p2).convert('RGB')
    return round(sum(ImageChops.difference(a, b).convert('L').getdata()) / (1600 * 2560), 2)


H.start_app(9)
H.tap(800, 1610)
time.sleep(2.4)
base = H.shot('2276_p63_ybase')
for y in [190, 210, 230, 245, 260]:
    H.tap(1248, y)
    time.sleep(1.4)
    p = H.shot('2277_p63_y%d' % y)
    print('y', y, 'diff', diff(base, p))
