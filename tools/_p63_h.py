import sys, time, json
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H
H.sh('hilog -r')
H.run('install','-r', r'D:\HarmonyAPP\carriagereturn\entry\build\default\outputs\default\entry-default-signed.hap', timeout=120)
H.start_app(8)
H.tap(800,2428); time.sleep(2.0)
print(H.shot('2258_p63_R4_customize'))
t = H.dump(local=r'D:\HarmonyAPP\carriagereturn\docs\evidence\.d63h.json')
row=None
for n in H.walk(t):
    a=n.get('attributes',{}); b=H.bbox(n); tx=(a.get('text') or '').strip()
    if b and tx=='字号': row=b
print('字号 row bbox:', row)
if row:
    x = row[0] + int((row[2]-row[0])*0.85)
    y = (row[1]+row[3])//2
    H.tap(x, y); time.sleep(1.4)
    print(H.shot('2259_p63_F6_slider_set'))
    print(H.sh('hilog -x | grep -E "fontSize apply|slider" | tail -n 4'))
