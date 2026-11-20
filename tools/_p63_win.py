# 批 63 N6：-i 未合并 dump（多窗口）里找覆盖 (1248,168) 的上层窗口
import sys, json
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H

t = json.load(open(r'D:\HarmonyAPP\carriagereturn\docs\evidence\.d63i.json', encoding='utf-8'))
roots = t if isinstance(t, list) else [t]
print('windows:', len(roots))
PX, PY = 1248, 168
for wi, root in enumerate(roots):
    nodes = []

    def walk(n):
        nodes.append(n)
        for c in n.get('children', []) or []:
            if isinstance(c, dict):
                walk(c)
            else:
                nodes.append(c)

    walk(root)
    name = ''
    for n in nodes[:6]:
        a = n.get('attributes', {}) if isinstance(n, dict) else {}
        name += (a.get('bundleName') or a.get('windowName') or a.get('id') or '')[:16] + '|'
    hit = None
    for n in nodes:
        if not isinstance(n, dict):
            continue
        a = n.get('attributes', {})
        b = H.bbox(n)
        if b and b[0] <= PX <= b[2] and b[1] <= PY <= b[3]:
            hit = ((a.get('id') or '')[:18], (a.get('type') or ''), b)
    print(wi, name, 'top-hit:', hit)
