# 批 63 N6 修复验证：槽在 y=48·sy → 找节点、看像素、点按
import sys, time
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H
from PIL import Image, ImageChops

H.run('install', '-r', r'D:\HarmonyAPP\carriagereturn\entry\build\default\outputs\default\entry-default-signed.hap', timeout=150)
H.start_app(9)
H.tap(800, 1610)
time.sleep(2.4)
p1 = H.shot('2266_p63_N6_slot_fixed')
t = H.dump(local=r'D:\HarmonyAPP\carriagereturn\docs\evidence\.d63t.json')
slot = None
for n in H.walk(t):
    if (n.get('attributes', {}).get('id') or '') == 'p26_export_slot':
        slot = H.bbox(n)
print('slot node:', slot)
im = Image.open(p1).convert('RGB')
px = im.load()
dark = [(x, y) for y in range(120, 220) for x in range(1080, 1300) if sum(px[x, y]) < 120]
print('dark px (x1080-1300,y120-220):', len(dark),
      'bbox:', (min(p[0] for p in dark), min(p[1] for p in dark), max(p[0] for p in dark), max(p[1] for p in dark)) if dark else None)
if slot:
    c = ((slot[0] + slot[2]) // 2, (slot[1] + slot[3]) // 2)
    H.tap(*c)
    time.sleep(2.0)
    p2 = H.shot('2267_p63_N6_slot_tapped')
    d = round(sum(ImageChops.difference(Image.open(p1).convert('RGB'), Image.open(p2).convert('RGB')).convert('L').getdata()) / (1600 * 2560), 2)
    print('tap diff', d)
