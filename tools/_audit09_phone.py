# -*- coding: utf-8 -*-
"""核查①-9 导出页取证：手机 ADA-AL00U 流程助手。"""
import os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _audit09 as A

ART = os.path.join(A.EVID, '.item09-artifacts')
APP_TMP = '/data/app/el2/100/base/com.dlzz.carriagereturn/haps/entry/files/export-tmp'
DEV_TMP = '/data/storage/el2/base/haps/entry/files/export-tmp'
SHARE_BTN = (894, 2560)
SAVE_BTN = (330, 2560)

LABELS = ['标题','机器框','日期','正文','页码','纸张底色','书写字体','墨色']

def top():
    A.swipe(600, 800, 600, 2200, wait=0.5)
    A.swipe(600, 800, 600, 2200, wait=0.6)

def formats():
    A.swipe(600, 2100, 600, 1250, wait=0.7)
    A.swipe(600, 2100, 600, 1500, wait=0.7)

def find_label(label, wins=None, below=400):
    wins = wins if wins is not None else A.dump_all('q')
    hits = [b for t, b in A.by_text(label, wins) if b[1] >= below]
    return hits[0] if hits else None

def select_fmt(label):
    top(); formats()
    wins = A.dump_all('q')
    b = find_label(label, wins)
    if not b:
        formats()
        wins = A.dump_all('q'); b = find_label(label, wins)
    if not b:
        top(); formats()
        wins = A.dump_all('q'); b = find_label(label, wins)
    if not b:
        print('!! fmt not found', label); return False
    A.tap(600, (b[1]+b[3])//2, wait=0.9)
    return True

def close_panel():
    A.key('2', wait=1.0)
    A.tap(600, 700, wait=0.5)

def on_export_page():
    return bool(A.by_id('export__share_btn'))

def wait_panel(sec=14):
    for i in range(sec):
        logs = A.logs('ExportPage', 12)
        m = re.findall(r'panel shown format=(\S+) path=(\S+)', logs)
        if m:
            return m[-1]
        time.sleep(1)
    return None

def share_and_pull(fmt_label, outname, wait=4.0):
    if not select_fmt(fmt_label):
        return None
    A.hilog_clear()
    A.tap(SHARE_BTN[0], SHARE_BTN[1], wait=1.5)
    m = wait_panel(16)
    if not m:
        print('!! panel not shown for', fmt_label)
        A.shot('_void_phone_panel_missing')
        return None
    path = m[1]
    print('[share]', fmt_label, '->', path)
    local = os.path.join(ART, outname)
    print(A.run('file', 'recv', path.replace(DEV_TMP, APP_TMP), local))
    A.key('2', wait=1.0)
    A.tap(600, 700, wait=0.5)
    if not on_export_page():
        print('!! export page lost after closing panel')
        A.shot('_void_phone_page_lost')
    return local

def export_triplet(tag, wait=4.0):
    out = {}
    out['png'] = share_and_pull('图片', tag + '.png', wait)
    out['pdf'] = share_and_pull('PDF', tag + '.pdf', wait)
    out['txt'] = share_and_pull('纯文本', tag + '.txt', 3.0)
    return out

def toggles_now():
    wins = A.dump_all('q')
    tg = []
    for n in A.walk_all(wins):
        a = n.get('attributes', {})
        b = A.bbox(n)
        if b and a.get('checked') in ('true','false') and b[0] > 900 and b[1] > 500 and (b[2]-b[0]) < 140 and (b[3]-b[1]) < 140:
            tg.append((b, a.get('checked')))
    tg.sort(key=lambda x: x[0][1])
    return wins, tg

def state_of(label):
    wins, tg = toggles_now()
    lb = find_label(label, wins)
    if not lb or not tg:
        return None
    cy = (lb[1]+lb[3])//2
    best = min(tg, key=lambda t: abs((t[0][1]+t[0][3])//2 - cy))
    if abs((best[0][1]+best[0][3])//2 - cy) > 45:
        return None
    return best[1]

def custom():
    for i in range(4):
        wins = A.dump_all('q')
        b = find_label('标题', wins)
        if b and 500 <= (b[1]+b[3])//2 <= 2200:
            return
        A.swipe(600, 2150, 600, 1150, wait=0.7)
    A.swipe(600, 2150, 600, 1150, wait=0.7)

def toggle(label):
    custom()
    wins = A.dump_all('q')
    b = find_label(label, wins)
    if not b:
        print('!! label not found', label); return None
    cy = (b[1]+b[3])//2
    if cy > 2150 or cy < 450:
        for i in range(4):
            A.swipe(600, 2100, 600, 1400, wait=0.6) if cy > 2150 else A.swipe(600, 1400, 600, 2100, wait=0.6)
            wins = A.dump_all('q'); b = find_label(label, wins)
            if not b: continue
            cy = (b[1]+b[3])//2
            if 450 <= cy <= 2150: break
    st = state_of(label)
    # switch x: rightmost toggle in the row
    wins, tg = toggles_now()
    best = min(tg, key=lambda t: abs((t[0][1]+t[0][3])//2 - cy))
    x = (best[0][0]+best[0][2])//2
    print('[toggle]', label, 'state', st, 'at', (x, cy))
    A.tap(x, cy, wait=0.9)
    return st
