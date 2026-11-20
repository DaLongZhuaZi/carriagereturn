# 批 63 N6：点槽前后抓 App 自身日志，确认 onClick 有没有进
import sys, time
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H

H.sh('hilog -r')
t = H.dump(local=r'D:\HarmonyAPP\carriagereturn\docs\evidence\.d63ae.json')
slot = None
for n in H.walk(t):
    if (n.get('attributes', {}).get('id') or '') == 'p26_export_slot':
        slot = H.bbox(n)
print('slot', slot)
if slot:
    H.tap(*H.center(slot))
    time.sleep(1.8)
out = H.sh('hilog -x | grep MainScreen | tail -n 8')
print('--- app logs ---')
print(out)
