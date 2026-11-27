"""R35（自定义纸纹移除）双机取证小工具，2026-11-28。

设备：平板 MLR-AL10 192.168.5.133:42355（TCP）；手机 ADA-AL00U 2UCUT24724009680（USB）。
截图存 docs/shots/<name>.png；dump 存 docs/evidence/.dump_<tag>.json。
用法：python tools/_r35.py <cmd> [args]，cmd 见文件末尾 main()。
"""
import json
import os
import re
import subprocess
import sys
import time

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HDC = r'G:\DevEco Studio 26\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
BUNDLE = 'com.dlzz.carriagereturn'
TABLET = '192.168.5.133:42355'
PHONE = '2UCUT24724009680'
T = TABLET
SHOTS = os.path.join(ROOT, 'docs', 'shots')
EVID = os.path.join(ROOT, 'docs', 'evidence')


def device(t):
    global T
    T = t
    print('[device]', t)


def run(*args, timeout=60):
    cmd = [HDC, '-t', T] + list(args)
    p = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8',
                       errors='replace', timeout=timeout)
    return p.stdout.strip(), p.stderr.strip()


def sh(cmd, timeout=60):
    return run('shell', cmd, timeout=timeout)


def shot(name):
    sh('snapshot_display -f /data/local/tmp/_cap.jpeg')
    tmp = os.path.join(EVID, '.cap.jpeg')
    run('file', 'recv', '/data/local/tmp/_cap.jpeg', tmp)
    from PIL import Image
    im = Image.open(tmp)
    out = os.path.join(SHOTS, name + '.png')
    im.save(out)
    print('[shot]', name, im.size, 'brightness=%.1f' % brightness(out))
    return out


def brightness(path):
    from PIL import Image
    im = Image.open(path).convert('L').resize((64, 102))
    px = list(im.getdata())
    return sum(px) / len(px)


def tap(x, y, wait=1.2):
    sh('uitest uiInput click %d %d' % (int(x), int(y)))
    time.sleep(wait)
    return (x, y)


def swipe(x1, y1, x2, y2, ms=300, wait=1.0):
    sh('uitest uiInput swipe %d %d %d %d %d' % (int(x1), int(y1), int(x2), int(y2), int(ms)))
    time.sleep(wait)


def key(code, wait=1.0):
    sh('uitest uiInput keyEvent %s' % code)
    time.sleep(wait)


def dump_all(tag='x'):
    sh('uitest dumpLayout -i -p /data/local/tmp/_dump.json')
    local = os.path.join(EVID, '.dump_%s.json' % tag)
    run('file', 'recv', '/data/local/tmp/_dump.json', local)
    with open(local, encoding='utf-8') as f:
        d = json.load(f)
    return d if isinstance(d, list) else [d]


def walk(node, out=None):
    out = out if out is not None else []
    out.append(node)
    for c in node.get('children', []) or []:
        walk(c, out)
    return out


def walk_all(windows):
    out = []
    for w in windows:
        out.extend(walk(w))
    return out


def bbox(node):
    a = node.get('attributes', {})
    box = a.get('bounds') or ''
    nums = [int(float(v)) for v in re.findall(r'-?\d+(?:\.\d+)?', box)]
    if len(nums) >= 4:
        return nums[0], nums[1], nums[2], nums[3]
    return None


def by_id(name, windows=None, prefix=False):
    wins = windows if windows is not None else dump_all()
    hits = []
    for n in walk_all(wins):
        a = n.get('attributes', {})
        i = a.get('id') or ''
        if (i == name) if not prefix else i.startswith(name):
            hits.append(n)
    return hits


def center(node):
    b = bbox(node)
    if b is None:
        return None
    return ((b[0] + b[2]) // 2, (b[1] + b[3]) // 2)


def find_text(s, windows=None):
    wins = windows if windows is not None else dump_all()
    hits = []
    for n in walk_all(wins):
        a = n.get('attributes', {})
        t = a.get('text') or ''
        if s in t:
            hits.append(n)
    return hits


def texts(windows=None, limit=80):
    wins = windows if windows is not None else dump_all()
    out = []
    for n in walk_all(wins):
        a = n.get('attributes', {})
        t = (a.get('text') or '').strip()
        if t and t not in out:
            out.append(t)
    return out[:limit]


def start_app(cold=True):
    if cold:
        sh('aa force-stop %s' % BUNDLE)
        time.sleep(0.5)
    sh('aa start -a EntryAbility -b %s' % BUNDLE)
    time.sleep(8)


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ''
    if cmd == 'probe':
        print('targets:', run.__globals__['subprocess'].run(
            [HDC, 'list', 'targets'], capture_output=True, text=True).stdout.strip())
    elif cmd == 'shot':
        device(sys.argv[2])
        shot(sys.argv[3])
    elif cmd == 'bright':
        device(sys.argv[2])
        p = shot(sys.argv[3])
        print('brightness=%.1f' % brightness(p))
    elif cmd == 'start':
        device(sys.argv[2])
        start_app()
        print(texts()[:30])
    elif cmd == 'dump':
        device(sys.argv[2])
        print('\n'.join(texts()))
    elif cmd == 'tap':
        device(sys.argv[2])
        tap(int(sys.argv[3]), int(sys.argv[4]))
    elif cmd == 'tapid':
        device(sys.argv[2])
        hits = by_id(sys.argv[3], prefix=True)
        print('hits=', [bbox(h) for h in hits])
        if hits:
            c = center(hits[0])
            print('tap', c)
            tap(c[0], c[1])
    else:
        print(__doc__)


if __name__ == '__main__':
    main()
