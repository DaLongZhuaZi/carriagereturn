"""批 77：手机/平板扇面修复取证（截图 2356 手机、2357 平板）。"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _p38_hdc as H
import _p64_dev as D

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

PHONE = '2UCUT24724009680'
TABLET = '192.168.5.133:42355'


def device(t):
    H.T = t


def launch():
    H.run('shell', 'aa force-stop com.dlzz.carriagereturn', timeout=25)
    time.sleep(1.0)
    H.run('shell', 'aa start -a EntryAbility -b com.dlzz.carriagereturn', timeout=25)
    time.sleep(7.0)


def goto_typing():
    w = D.dump_all()
    if D.by_id('p26_stage', w) or D.by_id('p25_key_grid', w):
        print('[typing] already')
        return True
    for label in ('继续写作', '开始打字'):
        hits = D.by_text(label, w)
        if hits:
            x, y = H.center(hits[0][1])
            H.tap(x, y)
            print('[typing] tap', label, (x, y))
            time.sleep(2.5)
            w = D.dump_all()
            if D.by_id('p26_stage', w) or D.by_id('p25_key_grid', w):
                return True
    print('[typing] FAIL')
    return False


def main():
    which = sys.argv[1] if len(sys.argv) > 1 else 'both'
    if which in ('phone', 'both'):
        device(PHONE)
        launch()
        goto_typing()
        time.sleep(1.5)
        D.shot('2356_p77_phone_fan_fix')
    if which in ('tablet', 'both'):
        device(TABLET)
        launch()
        goto_typing()
        time.sleep(1.5)
        D.shot('2357_p77_tablet_fan_fix')


main()
