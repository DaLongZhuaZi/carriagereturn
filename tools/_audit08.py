"""核查①-6（收藏页＋收藏详情）双机取证小工具，2026-11-25。

设备：平板 MLR-AL10 192.168.5.133:42355（TCP）；手机 ADA-AL00U 2UCUT24724009680（USB）。
截图存 docs/shots/<name>.png；dump 存 docs/evidence/.dump_<_audit06>.json。
"""
import json
import os
import re
import subprocess
import sys
import time

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HDC = r'F:\HarmonyOS\SDK\26.0.0\toolchains\hdc.exe'
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


def run(*args, timeout=40):
    cmd = [HDC, '-t', T] + list(args)
    p = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8',
                       errors='replace', timeout=timeout)
    return p.stdout.strip(), p.stderr.strip()


def sh(cmd, timeout=40):
    return run('shell', cmd, timeout=timeout)


def shot(name):
    sh('snapshot_display -f /data/local/tmp/_cap.jpeg')
    tmp = os.path.join(EVID, '.cap.jpeg')
    run('file', 'recv', '/data/local/tmp/_cap.jpeg', tmp)
    from PIL import Image
    im = Image.open(tmp)
    out = os.path.join(SHOTS, name + '.png')
    im.save(out)
    print('[shot]', name, im.size)
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


def text(s, wait=1.2):
    sh('uitest uiInput text %s' % s)
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
        if (i.startswith(name) if prefix else i == name):
            b = bbox(n)
            if b:
                hits.append(b)
    return hits


def by_text(needle, windows=None):
    wins = windows if windows is not None else dump_all()
    hits = []
    for n in walk_all(wins):
        a = n.get('attributes', {})
        t = a.get('text') or ''
        d = a.get('accessibilityText') or ''
        if needle in t or needle in d:
            b = bbox(n)
            if b:
                hits.append((t or d, b))
    return hits


def center(b):
    return ((b[0] + b[2]) // 2, (b[1] + b[3]) // 2)


def tap_id(name, windows=None, prefix=False, wait=1.2):
    hits = by_id(name, windows, prefix=prefix)
    if not hits:
        print('[tap_id] NOT FOUND', name)
        return False
    x, y = center(hits[0])
    tap(x, y, wait)
    print('[tap_id]', name, '->', (x, y))
    return True


def tap_text(needle, windows=None, wait=1.2):
    hits = by_text(needle, windows)
    if not hits:
        print('[tap_text] NOT FOUND', needle)
        return False
    x, y = center(hits[0][1])
    tap(x, y, wait)
    print('[tap_text]', needle, '->', (x, y))
    return True


def logs(pattern, n=60):
    out, _ = sh('hilog -x | grep -E "%s" | tail -n %d' % (pattern, n), timeout=90)
    return out


def hilog_clear():
    sh('hilog -r')
    time.sleep(0.5)


def awake():
    sh('power-shell timeout -o 2147483647')
    sh('power-shell wakeup')
    sh('power-shell setmode 602')
    time.sleep(0.6)


def app_running_text(tag='chk'):
    """dump 一次，返回是否看到 App 自己的文本（非系统锁屏）。"""
    wins = dump_all(tag)
    texts = []
    for n in walk_all(wins):
        t = (n.get('attributes', {}).get('text') or '')
        if t:
            texts.append(t)
    joined = ' | '.join(texts)
    ok = any(k in joined for k in ('继续写作', '开始打字', '卷宗', '回收站', '打字', '设置', '未命名'))
    print('[foreground]', 'app' if ok else 'UNKNOWN', joined[:300])
    return ok


if __name__ == '__main__':
    print('helpers ready', ROOT)
