# 批 63 N6：顶部横带网格点按，找哪些位置吃点击（判断吞点层范围）
import sys, time
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H
from PIL import Image, ImageChops


def diff(p1, p2):
    a = Image.open(p1).convert('RGB')
    b = Image.open(p2).convert('RGB')
    return round(sum(ImageChops.difference(a, b).convert('L').getdata()) / (1600 * 2560), 2)


def on_typewriter():
    t = H.dump()
    tx = [(n.get('attributes', {}).get('text') or '') for n in H.walk(t)]
    return any('Courier Prime' in x for x in tx)


H.start_app(9)
H.tap(800, 1610)
time.sleep(2.4)
base = H.shot('2274_p63_grid_base')
pts = [(400, 168), (600, 168), (800, 168), (1000, 168), (1150, 168), (1248, 168), (1400, 168), (1550, 168)]
for x, y in pts:
    H.tap(x, y)
    time.sleep(1.0)
    p = H.shot('2275_p63_grid_%d_%d' % (x, y))
    d = diff(base, p)
    still = on_typewriter()
    print('tap', x, y, 'diff', d, 'still typewriter', still)
    if not still:
        H.tap(800, 1610)
        time.sleep(2.0)
        base = H.shot('2274_p63_grid_base')
