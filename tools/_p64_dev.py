"""批 64 阶段 1 的平板开发/取证小工具（在 _p38_hdc 上包一层）。"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _p38_hdc as H

HAP = os.path.join(H.ROOT, 'entry', 'build', 'default', 'outputs', 'default', 'entry-default-signed.hap')
SHOTS = os.path.join(H.ROOT, 'docs', 'shots')
EVID = os.path.join(H.ROOT, 'docs', 'evidence')


def install(timeout=240):
    out, err = H.run('install', '-r', HAP, timeout=timeout)
    ok = 'successfully' in (out + err)
    print('[install]', 'ok' if ok else 'FAIL', (out + ' ' + err).strip()[:160])
    return ok


def hilog_clear():
    H.sh('hilog -r')
    time.sleep(0.6)


def logs(pattern, n=60):
    out, _ = H.sh('hilog -x | grep -E "%s" | tail -n %d' % (pattern, n), timeout=90)
    return out


def dump_all(local='.d_i.json'):
    H.sh('uitest dumpLayout -i -p /data/local/tmp/_dump.json')
    local = os.path.join(EVID, local)
    H.run('file', 'recv', '/data/local/tmp/_dump.json', local)
    with open(local, encoding='utf-8') as f:
        d = json.load(f)
    return d if isinstance(d, list) else [d]


def walk_all(windows):
    out = []
    for w in windows:
        out.extend(H.walk(w))
    return out


def by_id(name, windows=None):
    wins = windows if windows is not None else dump_all()
    hits = []
    for n in walk_all(wins):
        a = n.get('attributes', {})
        if a.get('id') == name:
            b = H.bbox(n)
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
            b = H.bbox(n)
            if b:
                hits.append((t or d, b))
    return hits


def tap_text(needle, windows=None):
    hits = by_text(needle, windows)
    if not hits:
        print('[tap_text] NOT FOUND', needle)
        return False
    x, y = H.center(hits[0][1])
    H.tap(x, y)
    print('[tap_text]', needle, '->', (x, y))
    return True


def tap_id(name, windows=None):
    hits = by_id(name, windows)
    if not hits:
        print('[tap_id] NOT FOUND', name)
        return False
    x, y = H.center(hits[0])
    H.tap(x, y)
    print('[tap_id]', name, '->', (x, y))
    return True


def goto_typing():
    H.start_app(8)
    wins = dump_all()
    if by_id('p26_stage', wins):
        print('[goto_typing] already on typewriter')
        return True
    if not tap_text('继续写作', wins):
        return False
    time.sleep(2.2)
    wins = dump_all()
    ok = bool(by_id('p26_stage', wins) or by_id('p25_key_grid', wins))
    print('[goto_typing]', ok)
    return ok


def shot(name, kind='shots'):
    path = os.path.join(SHOTS if kind == 'shots' else EVID, name + '.png')
    H.sh('snapshot_display -f /data/local/tmp/_cap.jpeg')
    tmp = os.path.join(EVID, '.cap.jpeg')
    H.run('file', 'recv', '/data/local/tmp/_cap.jpeg', tmp)
    from PIL import Image
    im = Image.open(tmp)
    im.save(path)
    print('[shot]', path, im.size)
    return path


def brightness(path):
    from PIL import Image
    im = Image.open(path).convert('L').resize((64, 102))
    px = list(im.getdata())
    return sum(px) / len(px)


def diff(a, b, skip_top_frac=0.05, tol=0):
    from PIL import Image, ImageChops
    ia = Image.open(a).convert('RGB')
    ib = Image.open(b).convert('RGB')
    if ia.size != ib.size:
        return 100.0, None
    w, h = ia.size
    top = int(h * skip_top_frac)
    ca = ia.crop((0, top, w, h))
    cb = ib.crop((0, top, w, h))
    d = ImageChops.difference(ca, cb).convert('L')
    hist = d.histogram()
    non_zero = sum(hist[tol + 1:])
    total = ca.size[0] * ca.size[1]
    bbox = d.point(lambda v: 255 if v > tol else 0).getbbox()
    return non_zero * 100.0 / total, bbox


if __name__ == '__main__':
    print('helpers ready')
