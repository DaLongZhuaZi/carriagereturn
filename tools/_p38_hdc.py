# 批 38（平板竖屏第一次真机验）用的 hdc 小工具库（平板 MLR-AL10 192.168.5.133:42355）
import json, os, subprocess, time, re

HDC = r'G:\DevEco Studio 26\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
T = '192.168.5.133:42355'
BUNDLE = 'com.dlzz.carriagereturn'
ROOT = r'D:\HarmonyAPP\carriagereturn'


def run(*args, timeout=30):
    cmd = [HDC, '-t', T] + list(args)
    p = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=timeout)
    return p.stdout.strip(), p.stderr.strip()


def sh(cmd, timeout=30):
    return run('shell', cmd, timeout=timeout)


def shot(name):
    """name = 不带扩展名，存 docs/shots/<name>.png"""
    sh('snapshot_display -f /data/local/tmp/_cap.jpeg')
    tmp = os.path.join(ROOT, 'docs', 'evidence', '.cap.jpeg')
    run('file', 'recv', '/data/local/tmp/_cap.jpeg', tmp)
    from PIL import Image
    im = Image.open(tmp)
    out = os.path.join(ROOT, 'docs', 'shots', name + '.png')
    im.save(out)
    print('shot', out, im.size)
    return out


def tap(x, y):
    sh('uitest uiInput click %d %d' % (int(x), int(y)))
    return (x, y)


def swipe(x1, y1, x2, y2, ms=300):
    sh('uitest uiInput swipe %d %d %d %d %d' % (int(x1), int(y1), int(x2), int(y2), int(ms)))


def key(code):
    sh('uitest uiInput keyEvent %s' % code)


def dump(local=None):
    sh('uitest dumpLayout -p /data/local/tmp/_dump.json')
    local = local or os.path.join(ROOT, 'docs', 'evidence', '.dump.json')
    run('file', 'recv', '/data/local/tmp/_dump.json', local)
    with open(local, encoding='utf-8') as f:
        return json.load(f)


def walk(node, out=None):
    out = out if out is not None else []
    a = node.get('attributes', {})
    out.append(node)
    for c in node.get('children', []) or []:
        walk(c, out)
    return out


def bbox(node):
    a = node.get('attributes', {})
    box = a.get('bounds') or ''
    # forms: "[[x1,y1],[x2,y2]]" or "[x1,y1][x2,y2]"
    nums = [int(float(v)) for v in re.findall(r'-?\d+(?:\.\d+)?', box)]
    if len(nums) >= 4:
        return nums[0], nums[1], nums[2], nums[3]
    return None


def find_text(tree, needle, exact=False):
    hits = []
    for n in walk(tree):
        a = n.get('attributes', {})
        t = a.get('text') or ''
        d = a.get('accessibilityText') or ''
        if (t == needle) if exact else (needle in t or needle in d):
            b = bbox(n)
            if b:
                hits.append((t or d, b, n))
    return hits


def center(b):
    return ((b[0] + b[2]) // 2, (b[1] + b[3]) // 2)


def log(pattern, n=20):
    out, _ = sh('hilog -x | grep -E "%s" | tail -n %d' % (pattern, n), timeout=60)
    return out


def start_app(wait=7):
    sh('aa force-stop %s' % BUNDLE)
    sh('input keyevent 3')
    time.sleep(0.8)
    sh('aa start -a EntryAbility -b %s' % BUNDLE)
    time.sleep(wait)


def awake():
    sh('power-shell timeout -o 3600000')
    sh('power-shell wakeup')
    sh('input keyevent 0')
