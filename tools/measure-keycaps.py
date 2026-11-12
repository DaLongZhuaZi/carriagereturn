"""第 13 批 ①：键帽几何分层量测 v3（每机阈值/各向搜索半径按曝光单独定）。

1930s 的键帽之间有细亮竖杆（打字机连杆），二维各向等半径洪泛会沿竖杆漏到相邻行，
故限 dx/dy 各自上限。
"""
import json, io, statistics
from PIL import Image
import numpy as np

MACHINES = {
    '1920s-upright': ('circle', 150.0, 90, 90),
    '1930s-portable': ('rounded-rect', 40.0, 60, 52),
    '1950s-streamlined': ('rounded-rect', 150.0, 90, 90),
    '1960s-electric': ('rounded-rect', 160.0, 100, 100),
}
ROOT = 'entry/src/main/resources/rawfile'

def flood_bbox(bright, x, y, maxdx, maxdy):
    h, w = bright.shape
    if not (0 <= x < w and 0 <= y < h) or not bright[y, x]:
        return None
    visited = np.zeros_like(bright, dtype=bool)
    stack = [(x, y)]
    visited[y, x] = True
    minx = maxx = x; miny = maxy = y; n = 0
    while stack:
        cx, cy = stack.pop()
        n += 1
        minx = min(minx, cx); maxx = max(maxx, cx)
        miny = min(miny, cy); maxy = max(maxy, cy)
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
            nx, ny = cx+dx, cy+dy
            if 0 <= nx < w and 0 <= ny < h and not visited[ny, nx] and bright[ny, nx]:
                if abs(nx-x) <= maxdx and abs(ny-y) <= maxdy:
                    visited[ny, nx] = True
                    stack.append((nx, ny))
    if n < 40:
        return None
    return (maxx-minx+1, maxy-miny+1, minx, miny, n)

def measure(kind, shape, thr, maxdx, maxdy):
    km = json.load(io.open(f'{ROOT}/keymap/{kind}-keymap.json', encoding='utf-8'))
    a = np.asarray(Image.open(f'{ROOT}/machine/{kind}-keyband-phone.jpg').convert('L'), dtype=np.float32)
    y0 = km['bands']['phone']['y0']
    bright = a > thr
    per_cap = []
    for row in km['rows']:
        for cap in row['caps']:
            x = int(cap['x']); y = int(row['y'] - y0)
            bb = flood_bbox(bright, x, y, maxdx, maxdy)
            per_cap.append({'label': cap['label'], 'x': x, 'y': y, 'bb': (bb[0], bb[1]) if bb else None})
    ws = [c['bb'][0] for c in per_cap if c['bb']]
    hs = [c['bb'][1] for c in per_cap if c['bb']]
    base_w = statistics.median(ws) if ws else 0
    base_h = statistics.median(hs) if hs else 0
    rowgap = []
    for row in km['rows']:
        xs = sorted(int(c['x']) for c in row['caps'])
        d = [xs[i+1]-xs[i] for i in range(len(xs)-1)]
        d = [v for v in d if 10 < v < 400]
        if d:
            rowgap.append(statistics.median(d))
    ys = sorted(set(int(r['y']) for r in km['rows']))
    vgaps = [ys[i+1]-ys[i] for i in range(len(ys)-1)]
    hgap = (statistics.median(rowgap) - base_w) if rowgap else 0
    vgap = (statistics.median(vgaps) - base_h) if vgaps else 0
    wide = [{'label': c['label'], 'x': c['x'], 'w': c['bb'][0], 'h': c['bb'][1]}
            for c in per_cap if c['bb'] and c['bb'][0] > base_w * 1.30]
    return {
        'kind': kind, 'shape': shape, 'band': km['bands']['phone'],
        'detected': len(ws), 'total': len(per_cap),
        'base_w_px': round(base_w, 2), 'base_h_px': round(base_h, 2),
        'row_center_px': round(statistics.median(rowgap), 2) if rowgap else None,
        'col_center_px': round(statistics.median(vgaps), 2) if vgaps else None,
        'h_gap_px': round(hgap, 2), 'v_gap_px': round(vgap, 2),
        'wide_caps': wide,
        'no_bbox': [c['label'] for c in per_cap if not c['bb']],
    }

res = []
for kind, cfg in MACHINES.items():
    try:
        res.append(measure(kind, *cfg))
    except Exception as e:
        res.append({'kind': kind, 'error': str(e)})
io.open('docs/evidence/keycap_measure.json', 'w', encoding='utf-8').write(
    json.dumps(res, ensure_ascii=False, indent=1))
for r in res:
    print({k: r.get(k) for k in ('kind', 'detected', 'total', 'base_w_px', 'base_h_px', 'h_gap_px', 'v_gap_px', 'wide_caps', 'no_bbox')})
