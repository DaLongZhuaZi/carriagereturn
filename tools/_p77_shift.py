"""批 77：Shift 抬扇抓拍尝试——设备端一条命令里「按住 SHIFT」+ 定时 snapshot，避开 hdc 往返延迟。"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _p38_hdc as H
import _p64_dev as D

sys.stdout.reconfigure(encoding='utf-8', errors='replace')
H.T = '192.168.5.133:42355'

SHIFT = (155, 2219)


def grab(name):
    local = os.path.join(H.ROOT, 'docs', 'evidence', name + '.jpeg')
    H.run('file', 'recv', '/data/local/tmp/_shift.jpeg', local)
    from PIL import Image
    im = Image.open(local)
    out = os.path.join(H.ROOT, 'docs', 'evidence', name + '.png')
    im.save(out)
    print('[grab]', out, im.size)
    return out


def main():
    x, y = SHIFT
    # 设备端：后台按住 SHIFT（longClick 约 1s），0.3s 后抓帧
    cmd = ("sh -c 'uitest uiInput longClick %d %d & sleep 0.30; "
           "snapshot_display -f /data/local/tmp/_shift.jpeg'") % (x, y)
    out, err = H.sh(cmd, timeout=20)
    print('[cmd out]', out[-200:], '|', err[-200:])
    time.sleep(0.3)
    grab('.p77_shift_held')

    # 对照组：正常态再抓一帧
    H.sh('snapshot_display -f /data/local/tmp/_shift.jpeg')
    local = os.path.join(H.ROOT, 'docs', 'evidence', '.p77_shift_rest.jpeg')
    H.run('file', 'recv', '/data/local/tmp/_shift.jpeg', local)
    from PIL import Image
    Image.open(local).save(os.path.join(H.ROOT, 'docs', 'evidence', '.p77_shift_rest.png'))
    print('[grab] rest done')


main()
