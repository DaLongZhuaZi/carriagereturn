# 批 63 N6：列出所有覆盖 (1248,168) 的节点（按树序，越靠后越在上层），找出吃点击的那层
import sys, json
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H

t = H.dump(local=r'D:\HarmonyAPP\carriagereturn\docs\evidence\.d63y.json')
PX, PY = 1248, 168
hits = []
order = 0


def walk(n):
    global order
    order += 1
    a = n.get('attributes', {})
    b = H.bbox(n)
    if b and b[0] <= PX <= b[2] and b[1] <= PY <= b[3]:
        hits.append((order, (a.get('id') or ''), (a.get('type') or ''), b, H.center(b), a.get('clickable')))
    for c in n.get('children', []) or []:
        walk(c)


walk(t)
for h in hits[-14:]:
    print(h)
print('total hits', len(hits))
