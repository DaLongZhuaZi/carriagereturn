# 批 63 N6 收口：先关引导气泡（它把点击吞了），再点出纸槽，确认进导出页
import sys, time, json
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H
from PIL import Image, ImageChops

t = H.dump(local=r'D:\HarmonyAPP\carriagereturn\docs\evidence\.d63v.json')


def find(txt):
    for n in H.walk(t):
        a = n.get('attributes', {})
        b = H.bbox(n)
        if b and txt in (a.get('text') or ''):
            return H.center(b)
    return None


skip = find('跳过')
print('skip btn', skip)
if skip:
    H.tap(*skip)
    time.sleep(1.4)
p0 = H.shot('2266_p63_N6_slot_fixed')
t2 = H.dump(local=r'D:\HarmonyAPP\carriagereturn\docs\evidence\.d63w.json')
slot = None
for n in H.walk(t2):
    if (n.get('attributes', {}).get('id') or '') == 'p26_export_slot':
        slot = H.bbox(n)
print('slot', slot)
if slot:
    H.tap(*H.center(slot))
    time.sleep(2.2)
    p1 = H.shot('2267_p63_N6_slot_tapped')
    d = round(sum(ImageChops.difference(Image.open(p0).convert('RGB'), Image.open(p1).convert('RGB')).convert('L').getdata()) / (1600 * 2560), 2)
    print('tap diff', d)
    t3 = H.dump(local=r'D:\HarmonyAPP\carriagereturn\docs\evidence\.d63x.json')
    tx = [(n.get('attributes', {}).get('text') or '').strip() for n in H.walk(t3)]
    tx = [x for x in tx if x][:12]
    print('page after tap:', tx)
