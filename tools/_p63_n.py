import subprocess, time, json, re
HDC=r'G:\DevEco Studio 26\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
T='2UCUT24724009680'
def run(*a,t=40):
    return subprocess.run([HDC,'-t',T]+list(a),capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=t)
def sh(c,t=40): return run('shell',c,t=t).stdout.strip()
sh('power-shell wakeup'); time.sleep(0.6)
sh('uitest uiInput swipe 612 2450 612 700 800'); time.sleep(1.4)
run('shell','uitest dumpLayout -p /data/local/tmp/_d4.json')
run('file','recv','/data/local/tmp/_d4.json', r'D:\HarmonyAPP\carriagereturn\docs\evidence\.dphone4.json')
t=json.load(open(r'D:\HarmonyAPP\carriagereturn\docs\evidence\.dphone4.json',encoding='utf-8'))
def walk(n,out):
    out.append(n)
    for c in n.get('children',[]) or []: walk(c,out)
    return out
tx=[(n.get('attributes',{}).get('text') or '').strip() for n in walk(t,[])]
tx=[x for x in tx if x][:10]
print('lock texts:', tx)
print('has app:', any('回车' in x or '继续写作' in x for x in tx))
