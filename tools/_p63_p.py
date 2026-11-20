# 批 63：查 TopZone26 子树——出纸槽节点到底在不在渲染树里
import sys, time
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H

H.start_app(9)
H.tap(800, 1610)
time.sleep(2.2)
t = H.dump(local=r'D:\HarmonyAPP\carriagereturn\docs\evidence\.d63p.json')


def walk(n, path, out):
    out.append((path, n))
    for c in n.get('children', []) or []:
        walk(c, path + [n], out)
    return out


nodes = walk(t, [], [])
idx = None
for i, (path, n) in enumerate(nodes):
    if (n.get('attributes', {}).get('id') or '') == 'p26_top_zone':
        idx = i
        break
if idx is None:
    print('p26_top_zone not found; top-level ids:',
          [(n.get('attributes', {}).get('id') or '') for _, n in nodes[:40]])
else:
    print('top_zone bounds', H.bbox(nodes[idx][1]))
    for j in range(idx + 1, min(idx + 26, len(nodes))):
        a = nodes[j][1].get('attributes', {})
        print(j - idx, (a.get('id') or ''), repr((a.get('text') or '').strip()[:10]), H.bbox(nodes[j][1]))
