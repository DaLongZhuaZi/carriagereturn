# 批 63 N6 诊断：槽临时移到 120·sx，看是否出现（判断“位置被裁” vs “没构建”）
import sys, time
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H
from PIL import Image

H.run('install', '-r', r'D:\HarmonyAPP\carriagereturn\entry\build\default\outputs\default\entry-default-signed.hap', timeout=150)
H.start_app(9)
H.tap(800, 1610)
time.sleep(2.4)
p = H.shot('2265_p63_N6_diag_x120')
im = Image.open(p).convert('RGB')
px = im.load()
# 120·sx＝157vp＝374px（+machineOffset 236 → 610px），y 149..164
dark = [(x, y) for y in range(140, 180) for x in range(560, 700) if sum(px[x, y]) < 130]
print('dark px near x610:', len(dark), 'bbox:', (min(p[0] for p in dark), min(p[1] for p in dark),
      max(p[0] for p in dark), max(p[1] for p in dark)) if dark else None)
t = H.dump(local=r'D:\HarmonyAPP\carriagereturn\docs\evidence\.d63s.json')
slot = None
for n in H.walk(t):
    if (n.get('attributes', {}).get('id') or '') == 'p26_export_slot':
        slot = H.bbox(n)
print('slot node (x120 diag):', slot)
