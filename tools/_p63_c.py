import sys, time
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H
H.sh('hilog -r')
H.run('install','-r', r'D:\HarmonyAPP\carriagereturn\entry\build\default\outputs\default\entry-default-signed.hap', timeout=120)
H.start_app(8)
H.tap(800,1610); time.sleep(2.0)
H.tap(856,1651); time.sleep(2.2)
H.sh('hilog -r')
for i in range(7):
    H.tap(1255,2192); time.sleep(0.8)
time.sleep(1.2)
print(H.shot('2260_p63_paper_8rows'))
print(H.sh('hilog -x | grep -E "newlineDone|newline paperGrow" | tail -n 3'))
H.tap(1255,2192); time.sleep(1.5)
print(H.shot('2261_p63_paper_9rows'))
print(H.sh('hilog -x | grep -E "newlineDone|newline paperGrow" | tail -n 3'))
H.tap(1255,2192); time.sleep(1.5)
print(H.sh('hilog -x | grep -E "newlineDone|newline paperGrow" | tail -n 2'))
