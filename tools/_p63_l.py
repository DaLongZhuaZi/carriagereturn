import subprocess, time, json, re
HDC=r'G:\DevEco Studio 26\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
T='2UCUT24724009680'
def run(*a,t=40):
    return subprocess.run([HDC,'-t',T]+list(a),capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=t)
def sh(c,t=40): return run('shell',c,t=t).stdout.strip()
run('shell','snapshot_display -f /data/local/tmp/_p2.jpeg')
run('file','recv','/data/local/tmp/_p2.jpeg', r'D:\HarmonyAPP\carriagereturn\docs\evidence\.pphone2.jpeg')
run('shell','uitest dumpLayout -p /data/local/tmp/_d2.json')
run('file','recv','/data/local/tmp/_d2.json', r'D:\HarmonyAPP\carriagereturn\docs\evidence\.dphone2.json')
t=json.load(open(r'D:\HarmonyAPP\carriagereturn\docs\evidence\.dphone2.json',encoding='utf-8'))
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
    if s: tx.append((s,bbox(n)))
print('texts:', tx[:14])
print('pkg:', sh('shell aa dump -a 2>/dev/null | head -3')[:80])
