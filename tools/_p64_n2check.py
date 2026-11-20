# 批 64（N2）：装包后 dump 三容器右缘＋截图 2285
import sys, time, json
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H

H.run('install', '-r', r'D:\HarmonyAPP\carriagereturn\entry\build\default\outputs\default\entry-default-signed.hap', timeout=150)
H.start_app(9)
H.tap(800, 1610)
time.sleep(2.4)
p = H.shot('2285_p64_N2_containers')
t = H.dump(local=r'D:\HarmonyAPP\carriagereturn\docs\evidence\.d64n2.json')
want = ('p35_carriage', 'p26_top_zone', 'p25_key_grid', 'p26_lid', 'p33_key_well', 'p26_basket')
for n in H.walk(t):
    nid = n.get('attributes', {}).get('id') or ''
    if nid in want:
        print(nid, H.bbox(n))
print('machine right edge expected: 236 + 1129 = 1365px ; screen 1600px')
