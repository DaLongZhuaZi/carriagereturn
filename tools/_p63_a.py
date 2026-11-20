import sys, time
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H
H.sh('hilog -r')
H.run('install','-r', r'D:\HarmonyAPP\carriagereturn\entry\build\default\outputs\default\entry-default-signed.hap', timeout=120)
H.start_app(8)
print(H.shot('2254_p63_N1_load'))
print(H.sh('hilog -x | grep -E "recalcOffset|newlineDone|parts stageW|overlayWidth" | tail -n 8'))
