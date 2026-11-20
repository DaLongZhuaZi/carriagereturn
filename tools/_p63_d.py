import sys, time, json
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H
H.start_app(8)
H.tap(1112,2428); time.sleep(1.8)
print(H.shot('2256_p63_R4_settings'))
H.tap(60,127); time.sleep(1.2)
H.tap(1425,2428); time.sleep(1.8)
print(H.shot('2257_p63_R4_export'))
H.tap(60,127); time.sleep(1.2)
H.tap(800,2428); time.sleep(1.8)
print(H.shot('2258_p63_R4_customize'))
for i in range(6):
    H.swipe(800,2000,800,600,700); time.sleep(0.9)
t = H.dump(local=r'D:\HarmonyAPP\carriagereturn\docs\evidence\.d63c.json')
rows=[]
for n in H.walk(t):
    a=n.get('attributes',{}); b=H.bbox(n); tx=(a.get('text') or '').strip()
    if b and tx and len(tx)<26 and 150<b[1]<2500:
        rows.append((b[1], tx, b))
rows.sort()
print('has 字号:', any('字号' in r[1] for r in rows))
for r in rows[-8:]: print(r)
