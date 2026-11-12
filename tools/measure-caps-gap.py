"""第 13 批 ① v9：按「行带列剖面谷值」切分每行键帽边界（聚合整行，避开叠字墨色）。

对 keymap 每行：
- 行带 y ∈ [cy − 0.30×py, cy + 0.30×py] 取列剖面 median；
- 谷（暗）位置 = 键与键之间的缝；用局部极小 + 全局阈值（< 0.55×行带最大值）筛缝；
- 以缝为边界，按 keymap 该行帽心 x 顺序切出每帽 bbox（宽 + 该行统一高：由行带上下沿雅测高）。
输出 widths 供人工核对；--apply 时写 keymap。
"""
import json, io, statistics, sys
import numpy as np
from PIL import Image

ROOT = 'entry/src/main/resources/rawfile'
BAND_W = 2048.0
SCREEN_W, SCREEN_H_KB = 1600.0, 762.0

def row_edges(prof, k):
    n = len(prof)
    thr = prof.max() * 0.62
    gaps = []
    i = 1
    while i < n - 1:
        if prof[i] < thr:
            j = i
            while j < n - 1 and prof[j] < thr:
                j += 1
            gaps.append((i, j - 1))
            i = j
        else:
            i += 1
    return [ (a + b) // 2 for a, b in gaps ]

def run(machine, shot, keybed_top):
    km = json.load(io.open(f'{ROOT}/keymap/{machine}-keymap.json', encoding='utf-8'))
    y0 = km['bands']['phone']['y0']
    a = np.asarray(Image.open(shot).convert('L'), dtype=np.float32)
    ys = sorted(set(int(r['y']) for r in km['rows']))
    vys = [ys[i+1]-ys[i] for i in range(len(ys)-1)]
    py = statistics.median(vys) * SCREEN_H_KB / 975.0
    out = {}
    for ri, row in enumerate(km['rows']):
        cy = int(round(keybed_top + (row['y'] - y0) * SCREEN_H_KB / 975.0))
        y0b = max(0, int(cy - 0.30 * py)); y1b = min(a.shape[0], int(cy + 0.30 * py))
        band = a[y0b:y1b, :]
        prof = np.median(band, axis=0)
        gaps = row_edges(prof, ri)
        caps = sorted(row['caps'], key=lambda c: int(c['x']))
        edges = [0] + gaps + [a.shape[1] - 1]
        for cap in caps:
            cx = int(cap['x']) * SCREEN_W / BAND_W
            # 找 cx 所处的两相邻边界
            k = 0
            while k < len(edges) - 1 and edges[k + 1] < cx:
                k += 1
            l = edges[k]; r = edges[k + 1]
            out[(ri, cap['label'])] = (r - l + 1, cy)
    return out, py

if __name__ == '__main__':
    machine, shot, keybed_top = sys.argv[1], sys.argv[2], float(sys.argv[3])
    out, py = run(machine, shot, keybed_top)
    ws = [v[0] for v in out.values()]
    print('rowpitch px', round(py, 1), 'caps', len(ws))
    for k, v in list(out.items())[:20]:
        print('  ', k, v[0])
