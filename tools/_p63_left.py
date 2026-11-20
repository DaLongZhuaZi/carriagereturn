# 批 63 N6 诊断：槽挪到左侧（x=100·sx）测点击，验证「右侧区域吃点击」假设
import sys, time
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H
from PIL import Image, ImageChops

H.run('install', '-r', r'D:\HarmonyAPP\carriagereturn\entry\build\default\outputs\default\entry-default-signed.hap', timeout=150)
H.start_app(9)
H.tap(800, 1610)
time.sleep(2.4)
p0 = H.shot('2278_p63_left_diag_before')
t = H.dump(local=r'D:\HarmonyAPP\carriagereturn\docs\evidence\.d63ab.json')
slot = None
for n in H.walk(t):
    if (n.get('attributes', {}).get('id') or '') == 'p26_export_slot':
        slot = H.bbox(n)
print('slot (left diag)', slot)
if slot:
    H.tap(*H.center(slot))
    time.sleep(2.0)
    p1 = H.shot('2279_p63_left_diag_after')
    d = round(sum(ImageChops.difference(Image.open(p0).convert('RGB'), Image.open(p1).convert('RGB')).convert('L').getdata()) / (1600 * 2560), 2)
    print('left tap diff', d)
    t2 = H.dump(local=r'D:\HarmonyAPP\carriagereturn\docs\evidence\.d63ac.json')
    tx = [(n.get('attributes', {}).get('text') or '').strip() for n in H.walk(t2)]
    tx = [x for x in tx if x][:8]
    print('page:', tx)
