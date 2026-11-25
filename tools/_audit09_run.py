# -*- coding: utf-8 -*-
"""核查①-9 导出页取证：单机流程助手（2026-11-25）。"""
import os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _audit09 as A
from PIL import Image

ART = os.path.join(A.EVID, '.item09-artifacts')
os.makedirs(ART, exist_ok=True)
APP_TMP = '/data/app/el2/100/base/com.dlzz.carriagereturn/haps/entry/files/export-tmp'
DEV_TMP = '/data/storage/el2/base/haps/entry/files/export-tmp'

def top():
    A.swipe(800, 1450, 800, 2150, wait=0.6)

def custom():
    A.swipe(800, 2150, 800, 1400, wait=0.6)

def find_label(label, wins=None, below=0):
    wins = wins if wins is not None else A.dump_all('q')
    hits = [b for t, b in A.by_text(label, wins) if b[1] >= below]
    return hits[0] if hits else None

def tap_row(label):
    b = find_label(label)
    if not b:
        print('!! row not found', label); return False
    A.tap((b[0]+b[2])//2, (b[1]+b[3])//2, wait=0.7)
    return True

def select_fmt(label):
    # formats are inside the scroll; ensure top then tap
    top(); wins = A.dump_all('q')
    b = find_label(label, wins)
    if not b:
        print('!! fmt not found', label); return False
    A.tap((b[0]+b[2])//2, (b[1]+b[3])//2, wait=0.7)
    return True

def toggles_now():
    wins = A.dump_all('q')
    toggles = []
    for n in A.walk_all(wins):
        a = n.get('attributes', {})
        b = A.bbox(n)
        if b and a.get('checked') in ('true','false') and b[0] > 1400 and b[1] > 800 and (b[2]-b[0]) < 120 and (b[3]-b[1]) < 120:
            toggles.append((b, a.get('checked')))
    toggles.sort(key=lambda x: x[0][1])
    return wins, toggles

LABELS = ['标题','机器框','日期','正文','页码','纸张底色','书写字体','墨色']

def state_of(label):
    """读某行开关当前状态：标签行中心附近的 Toggle 节点。"""
    wins, tg = toggles_now()
    labs = []
    for lb in LABELS:
        b = find_label(lb, wins)
        if b: labs.append((lb, b))
    lb = dict(labs).get(label)
    if not lb:
        return None
    cy = (lb[1]+lb[3])//2
    best = min(tg, key=lambda t: abs((t[0][1]+t[0][3])//2 - cy))
    if abs((best[0][1]+best[0][3])//2 - cy) > 40:
        return None
    return best[1]

def ensure_visible(label):
    for i in range(8):
        wins = A.dump_all('q')
        b = find_label(label, wins)
        cy = (b[1]+b[3])//2 if b else 9999
        if b and 320 <= cy <= 2150:
            return b
        if cy > 2150:
            A.swipe(800, 2050, 800, 1450, wait=0.6)
        else:
            A.swipe(800, 1450, 800, 2050, wait=0.6)
    return find_label(label, A.dump_all('q'))

def toggle(label):
    custom()
    b = ensure_visible(label)
    if not b:
        print('!! label not found', label); return None
    cy = (b[1]+b[3])//2
    st = state_of(label)
    print('[toggle]', label, 'state', st, 'at', (1505, cy))
    A.tap(1505, cy, wait=0.8)
    return st

def share_and_pull(fmt_label, outname, wait=2.5):
    if not select_fmt(fmt_label):
        return None
    A.hilog_clear()
    A.tap(1180, 2385, wait=wait)
    logs = A.logs('ExportPage', 12)
    m = re.findall(r'panel shown format=(\S+) path=(\S+)', logs)
    path = m[-1][1] if m else ''
    print('[share]', fmt_label, '->', path)
    local = os.path.join(ART, outname)
    if path:
        dev = path.replace(DEV_TMP, APP_TMP)
        o, e = A.run('file', 'recv', dev, local)
        print('[recv]', o[:80], e[:80])
    A.tap(1288, 760, wait=0.9)   # close share panel
    A.tap(800, 700, wait=0.5)    # dummy: absorb focus-return
    return local if path else None

def export_triplet(tag, wait=2.5):
    out = {}
    out['png'] = share_and_pull('图片', tag + '.png', wait)
    out['pdf'] = share_and_pull('PDF', tag + '.pdf', wait + 1.5)
    out['txt'] = share_and_pull('纯文本', tag + '.txt', wait)
    return out
