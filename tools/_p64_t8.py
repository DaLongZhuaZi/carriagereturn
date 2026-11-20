# 批 64 T8：清注释后回归——槽可见性＋点按（2288）
import sys, time
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H
from PIL import Image

H.run('install', '-r', r'D:\HarmonyAPP\carriagereturn\entry\build\default\outputs\default\entry-default-signed.hap', timeout=150)
H.start_app(9)
H.tap(800, 1610)
time.sleep(2.4)
p = H.shot('2288_p64_N6_slot_closeup')
t = H.dump(local=r'D:\HarmonyAPP\carriagereturn\docs\evidence\.d64a.json')
slot = None
for n in H.walk(t):
    if (n.get('attributes', {}).get('id') or '') == 'p26_export_slot':
        slot = H.bbox(n)
print('slot dump rect:', slot)
im = Image.open(p).convert('RGB')
px = im.load()
dark = [(x, y) for y in range(120, 220) for x in range(1050, 1400) if sum(px[x, y]) < 120]
print('dark px:', len(dark), 'bbox:', (min(a for a, b in dark), min(b for a, b in dark),
      max(a for a, b in dark), max(b for a, b in dark)) if dark else None)
if slot:
    H.sh('hilog -r')
    H.tap(*H.center(slot))
    time.sleep(1.6)
    print(H.sh('hilog -x | grep MainScreen | grep -E "export slot tap|direct export ok|slot fly" | tail -n 3'))
