# 批 38 阶段2：F-1 打字 20 字 / F-2 换行 / F-14 纸高上限
import sys, time, json
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H

# 键位（平板竖屏实测，px）
KEYS = {
    'Q': (422, 2085), 'W': (501, 2085), 'E': (580, 2085), 'R': (659, 2085), 'T': (738, 2085),
    'Y': (818, 2085), 'U': (897, 2085), 'I': (976, 2085), 'O': (1055, 2085), 'P': (1134, 2085),
    'A': (406, 2192), 'S': (469, 2192), 'D': (532, 2192), 'F': (595, 2192), 'G': (658, 2192),
    'H': (721, 2192), 'J': (784, 2192), 'K': (847, 2192), 'L': (910, 2192),
    'Z': (462, 2300), 'X': (537, 2300), 'C': (612, 2300), 'V': (687, 2300), 'B': (762, 2300),
    'N': (837, 2300), 'M': (912, 2300),
}


def key_of(ch):
    return KEYS[ch.upper()]


def type_word(word, gap=0.45):
    for ch in word:
        if ch == ' ':
            H.tap(700, 2465)   # 空格键中心（下方长条）
        else:
            H.tap(*key_of(ch))
        time.sleep(gap)


def dump_text(local=r'D:\HarmonyAPP\carriagereturn\docs\evidence\.dump_t.json'):
    H.sh('uitest dumpLayout -p /data/local/tmp/_dump.json')
    H.run('file', 'recv', '/data/local/tmp/_dump.json', local)
    t = json.load(open(local, encoding='utf-8'))
    out = []
    for n in H.walk(t):
        a = n.get('attributes', {})
        b = H.bbox(n)
        tx = (a.get('text') or '')
        if b and tx.strip() and b[1] < 1600 and b[1] > 250:
            out.append((tx, b))
    return out


if __name__ == '__main__':
    step = sys.argv[1] if len(sys.argv) > 1 else 'all'
    if step in ('all', 'fresh'):
        H.sh('hilog -r')
        H.tap(856, 1651)          # ↻ 换纸
        time.sleep(2.0)
        print(H.shot('2190_p38_F2_fresh_paper'))
    if step in ('all', 'type'):
        type_word('the quick brown fox jum')
        time.sleep(1.2)
        print(H.shot('2191_p38_F1_F2_23chars'))
        rows = dump_text()
        print('TEXT NODES:', rows[:8])
        print(H.sh('hilog -x | grep -E "charTrace|landTrace|newline|choreo" | tail -n 8'))
