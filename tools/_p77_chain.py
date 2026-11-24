"""批 77 主链回归（平板）：落字 / 回车 / 换纸。"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _p38_hdc as H
import _p64_dev as D

sys.stdout.reconfigure(encoding='utf-8', errors='replace')
H.T = '192.168.5.133:42355'


def center(label, min_y=0, exact=False):
    wins = D.dump_all()
    hits = D.by_text(label, wins)
    hits = [h for h in hits if h[1][1] >= min_y]
    if exact:
        hits = [h for h in hits if h[0] == label]
    return H.center(hits[0][1]) if hits else None


def tap_at(x, y):
    H.tap(x, y)
    time.sleep(1.15)


def main():
    H.start_app(9)
    time.sleep(1.0)
    if not D.goto_typing():
        print('[abort] no typewriter')
        return
    time.sleep(1.5)
    D.hilog_clear()
    time.sleep(0.3)
    print('[boot]', D.logs('parts stageW', 1).split('MainScreen: ')[-1][:160])

    c = center('Q', 1700, exact=True)
    print('[Q at]', c)
    if c:
        tap_at(*c)
        time.sleep(1.0)
        print('[commit]', D.logs('committed ch', 2).split('MainScreen: ')[-1][:120])

    before = D.logs('parts stageW', 1).split('MainScreen: ')[-1][:160]
    c = center('RETURN', 1700, exact=True)
    print('[RETURN at]', c)
    if c:
        tap_at(*c)
        time.sleep(1.2)
        after = D.logs('parts stageW', 1).split('MainScreen: ')[-1][:160]
        print('[before]', before)
        print('[after ]', after)

    rects = D.by_id('p26_function_caps')
    print('[func rect]', rects[:1])
    if rects:
        x0, y0, x1, y1 = rects[0]
        cw = (x1 - x0) / 6.0
        px = int(x0 + cw * 3.5)
        py = int((y0 + y1) / 2)
        print('[paper tap]', (px, py))
        tap_at(px, py)
        time.sleep(1.6)
        print('[paperChange]', D.logs('paperChange', 6))
        D.shot('.p77_chain_paper', kind='evidence')

    # 退格回收：换纸后再按一次退格确认无异常
    print('[final parts]', D.logs('parts stageW', 1).split('MainScreen: ')[-1][:160])


main()
