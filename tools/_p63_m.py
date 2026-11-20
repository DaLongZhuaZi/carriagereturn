import subprocess, time, json, re
HDC=r'G:\DevEco Studio 26\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
T='2UCUT24724009680'
def run(*a,t=40):
    return subprocess.run([HDC,'-t',T]+list(a),capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=t)
def sh(c,t=40): return run('shell',c,t=t).stdout.strip()
sh('power-shell timeout -o 3600000'); sh('power-shell wakeup'); sh('input keyevent 0')
time.sleep(1)
sh('uitest uiInput swipe 612 2200 612 1100 400'); time.sleep(1.2)
sh('aa start -a EntryAbility -b com.dlzz.carriagereturn'); time.sleep(7)
run('shell','uitest dumpLayout -p /data/local/tmp/_d3.json')
run('file','recv','/data/local/tmp/_d3.json', r'D:\HarmonyAPP\carriagereturn\docs\evidence\.dphone3.json')
t=json.load(open(r'D:\HarmonyAPP\carriagereturn\docs\evidence\.dphone3.json',encoding='utf-8'))
def bbox(n):
    b=n.get('attributes',{}).get('bounds') or ''
    nums=[int(float(v)) for v in re.findall(r'-?\d+',b)]
    return nums[:4] if len(nums)>=4 else None
def walk(n,out):
    out.append(n)
    for c in n.get('children',[]) or []: walk(c,out)
    return out
tx=[]
for n in walk(t,[]):
    s=(n.get('attributes',{}).get('text') or '').strip()
    if s and len(s)<20: tx.append((s,bbox(n)))
print('texts:', tx[:16])
