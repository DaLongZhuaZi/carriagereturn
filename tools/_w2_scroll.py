"""核查⑤ W2：平板文档视图滚动读全文（Q-1 / D-1 A）双机取证小工具，2026-11-28。

设备：平板 MLR-AL10 192.168.5.133:42355（TCP）；手机 ADA-AL00U 2UCUT24724009680（USB）。
用法：python tools/_w2_scroll.py <step>
截图存 docs/shots/<name>.png；dump 存 docs/evidence/.dump_<tag>.json。
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _audit05 as A  # noqa: E402

A.HDC = r'F:\HarmonyOS\SDK\26.0.0\toolchains\hdc.exe'
BUNDLE = A.BUNDLE


def start_app(tag='boot'):
    A.sh('aa force-stop ' + BUNDLE)
    time.sleep(1.5)
    A.sh('aa start -a EntryAbility -b ' + BUNDLE)
    time.sleep(7.0)
    A.app_running_text(tag)


def dump_texts(tag='x'):
    wins = A.dump_all(tag)
    out = []
    for n in A.walk_all(wins):
        a = n.get('attributes', {})
        out.append((a.get('id') or '', a.get('text') or '', a.get('accessibilityText') or '',
                    A.bbox(n)))
    return out


def key_centers(tag='keys'):
    """键床（p25_key_grid）内 label → 帽中心 px。避开字杆篮里的同名小字。"""
    rows = dump_texts(tag)
    grid = None
    for i, t, acc, b in rows:
        if i == 'p25_key_grid':
            grid = b
    out = {}
    if grid is None:
        return out
    for i, t, acc, b in rows:
        if not t or not b or len(t) != 1:
            continue
        if b[1] >= grid[1] and b[3] <= grid[3] and b[2] > b[0]:
            # Text 图例节点在帽内，点它的中心即可命中帽的 onTouch
            if t not in out:
                out[t] = ((b[0] + b[2]) // 2, (b[1] + b[3]) // 2)
    return out


def tap_center(xy, wait=0.35):
    A.tap(xy[0], xy[1], wait=wait)


def fn_center(label, tag='fn'):
    """功能行（p26_function_caps）内 label → 中心 px。"""
    rows = dump_texts(tag)
    box = None
    for i, t, acc, b in rows:
        if i == 'p26_function_caps':
            box = b
    if box is None:
        return None
    for i, t, acc, b in rows:
        if t == label and b and b[1] >= box[1] and b[3] <= box[3]:
            return ((b[0] + b[2]) // 2, (b[1] + b[3]) // 2)
    return None


if __name__ == '__main__':
    step = sys.argv[1] if len(sys.argv) > 1 else 'probe'
    if step == 'probe':
        A.device(A.TABLET)
        A.awake()
        start_app('probe')
        for row in dump_texts('probe'):
            print(row)
    elif step == 'build':
        # 在新建的空纸上：sheet1 打 12 行 x（含 1 行空行）→ ↻ 换纸 → sheet2 打 12 行 x ＋ END
        A.device(A.TABLET)
        keys = key_centers('build_keys')
        nl = fn_center('⏎', 'build_fn')
        paper = fn_center('↻', 'build_fn')
        print('[keys]', len(keys), 'x=', keys.get('X'), 'nl=', nl, 'paper=', paper)
        if keys.get('X') is None or nl is None or paper is None:
            raise SystemExit('key locate failed')
        for i in range(12):
            tap_center(keys['X'])
            tap_center(nl, wait=0.6)
        print('[sheet1 done]')
        tap_center(paper, wait=2.0)
        print('[paper changed]')
        for i in range(12):
            tap_center(keys['X'])
            tap_center(nl, wait=0.6)
        for ch in ('E', 'N', 'D'):
            tap_center(keys[ch])
        time.sleep(1.5)
        print('[sheet2 done]')
