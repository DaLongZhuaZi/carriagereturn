import subprocess, time
HDC=r'G:\DevEco Studio 26\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
T='2UCUT24724009680'
def sh(c, t=30):
    p=subprocess.run([HDC,'-t',T,'shell',c],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=t)
    return p.stdout.strip()
print('targets:', subprocess.run([HDC,'list','targets'],capture_output=True,text=True,encoding='utf-8',errors='replace').stdout.replace(chr(10),' | ')[:120])
print(sh('hilog -r'))
r=subprocess.run([HDC,'-t',T,'install','-r',r'D:\HarmonyAPP\carriagereturn\entry\build\default\outputs\default\entry-default-signed.hap'],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=120)
print('install:', r.stdout.strip()[-60:])
sh('aa force-stop com.dlzz.carriagereturn'); time.sleep(0.8)
sh('aa start -a EntryAbility -b com.dlzz.carriagereturn'); time.sleep(7)
print('parts:', sh('hilog -x | grep -E "parts stageW" | tail -n 2')[-200:])
