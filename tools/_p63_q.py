# 批 63 N6：装新包 → dump 找 p26_export_slot → 有则点它验证导出页
import sys, time, json
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H
from PIL import Image, ImageChops

H.sh('hilog -r')
H.run('install', '-r', r'D:\HarmonyAPP\carriagereturn\entry\build\default\outputs\default\entry-default-signed.hap', timeout=150)
H.start_app(9)
H.tap(800, 1610)
time.sleep(2.4)
before = H.shot('2263_p63_N6_slot_after_fix')
t = H.dump(local=r'D:\HarmonyAPP\carriagereturn\docs\evidence\.d63q.json')
slot = None
for n in H.walk(t):
    if (n.get('attributes', {}).get('id') or '') == 'p26_export_slot':
        slot = H.bbox(n)
        break
print('slot node:', slot)
if slot:
    c = ((slot[0] + slot[2]) // 2, (slot[1] + slot[3]) // 2)
    print('tap', c)
    H.tap(*c)
    time.sleep(2.0)
    after = H.shot('2264_p63_N6_slot_tap')
    a = Image.open(before).convert('RGB')
    b = Image.open(after).convert('RGB')
    print('diff after tap', round(sum(ImageChops.difference(a, b).convert('L').getdata()) / (1600 * 2560), 2))
    print(H.sh('hilog -x | grep -E "export|Export|page" | tail -n 5'))
