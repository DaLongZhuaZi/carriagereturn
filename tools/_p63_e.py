import sys, time, json
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H
from PIL import Image, ImageChops
H.start_app(8)
H.tap(800,2428); time.sleep(2.0)
print(H.shot('2258_p63_R4_customize'))
t = H.dump(local=r'D:\HarmonyAPP\carriagereturn\docs\evidence\.d63e.json')
def has(txt):
    return any(txt in (n.get('attributes',{}).get('text') or '') for n in H.walk(t))
print('字号 before scroll:', has('字号'))
for i in range(6):
    H.swipe(800,2000,800,600,700); time.sleep(0.9)
t2 = H.dump(local=r'D:\HarmonyAPP\carriagereturn\docs\evidence\.d63f.json')
print('字号 after scroll:', has('字号'))
print(H.shot('2259_p63_F6_scrolled_bottom'))
