# 批 63 N6：干净复测——进打字页后只点出纸槽
import sys, time
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H
from PIL import Image, ImageChops

H.start_app(9)
H.tap(800, 1610)
time.sleep(2.4)
p0 = H.shot('2272_p63_n6_clean_before')
t = H.dump(local=r'D:\HarmonyAPP\carriagereturn\docs\evidence\.d63z.json')
slot = None
for n in H.walk(t):
    if (n.get('attributes', {}).get('id') or '') == 'p26_export_slot':
        slot = H.bbox(n)
print('slot', slot)
if slot:
    H.tap(*H.center(slot))
    time.sleep(2.2)
    p1 = H.shot('2273_p63_n6_clean_after')
    d = round(sum(ImageChops.difference(Image.open(p0).convert('RGB'), Image.open(p1).convert('RGB')).convert('L').getdata()) / (1600 * 2560), 2)
    print('clean tap diff', d)
    t2 = H.dump(local=r'D:\HarmonyAPP\carriagereturn\docs\evidence\.d63aa.json')
    tx = [(n.get('attributes', {}).get('text') or '').strip() for n in H.walk(t2)]
    tx = [x for x in tx if x][:10]
    print('page:', tx)
