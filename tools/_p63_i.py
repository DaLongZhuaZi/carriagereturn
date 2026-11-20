import sys, time
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H
H.sh('hilog -r')
for x in [700, 1000, 1250]:
    H.tap(x, 346); time.sleep(1.2)
    out = H.sh('hilog -x | grep -E "fontSize apply" | tail -n 1')
    print(x, out[0][-110:] if out[0] else 'none')
print(H.shot('2259_p63_F6_slider_set'))
print(H.sh('hilog -x | grep -E "parts stageW" | tail -n 2'))
