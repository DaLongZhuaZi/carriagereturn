import subprocess, time, json, re
HDC=r'G:\DevEco Studio 26\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
T='2UCUT24724009680'
def run(*a,t=40):
    return subprocess.run([HDC,'-t',T]+list(a),capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=t)
def sh(c,t=40): return run('shell',c,t=t).stdout.strip()
run('shell','uitest dumpLayout -p /data/local/tmp/_d.json')
run('file','recv','/data/local/tmp/_d.json', r'D:\HarmonyAPP\carriagereturn\docs\evidence\.dphone.json')
t=json.load(open(r'D:\HarmonyAPP\carriagereturn\docs\evidence\.dphone.json',encoding='utf-8'))
def bbox(n):
    b=n.get('attributes',{}).get('bounds') or ''
    nums=[int(float(v)) for v in re.findall(r'-?\d+',b)]
    return nums[:4] if len(nums)>=4 else None
def walk(n,out):
    out.append(n)
    for c in n.get('children',[]) or []: walk(c,out)
    return out
pt=None
for n in walk(t,[]):
    tx=(n.get('attributes',{}).get('text') or '')
    if '继续写作' in tx:
        b=bbox(n)
        if b: pt=((b[0]+b[2])//2,(b[1]+b[3])//2)
print('continue btn', pt)
if pt:
    sh(f'uitest uiInput click {pt[0]} {pt[1]}'); time.sleep(2.2)
sh('hilog -r') if False else None
print('parts:', sh('hilog -x | grep -E "parts stageW|layout dev" | tail -n 2')[-260:])
run('shell','snapshot_display -f /data/local/tmp/_p.jpeg')
run('file','recv','/data/local/tmp/_p.jpeg', r'D:\HarmonyAPP\carriagereturn\docs\evidence\.p63phone.jpeg')
print('shot ok')
