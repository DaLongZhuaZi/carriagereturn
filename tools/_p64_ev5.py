# 批 64 验收（第五段）：11 行 → 14 行（纸封顶，2283）→ 10/9/8 行（2286）
import os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _p64_dev as D
import _p38_hdc as H


def center(label, min_y=1800):
    wins = D.dump_all()
    hits = [h for h in D.by_text(label, wins) if h[1][1] > min_y and h[0] == label]
    if not hits:
        hits = [h for h in D.by_text(label, wins) if h[1][1] > min_y and label in h[0]]
    return H.center(hits[0][1]) if hits else None


def tap(label, n, gap=1.0):
    c = center(label)
    if c is None:
        print('KEY MISSING', label)
        return False
    for _ in range(n):
        H.tap(*c)
        time.sleep(gap)
    return True


def parts():
    out = D.logs('parts stageW', 2)
    m = re.findall(r'paperTop=([\d.]+) paperBox=([\d.]+) Hc=([\d.]+)', out)
    return m[-1] if m else None


if __name__ == '__main__':
    print('now:', parts())
    tap('RETURN', 3, 1.0)
    time.sleep(1.2)
    print('cap:', parts())
    wins = D.dump_all()
    print('zones@cap: carriage', D.by_id('p35_carriage', wins), 'keywell', D.by_id('p33_key_well', wins))
    D.shot('2283_p64_paper_cap')
    tap('RETURN', 1, 1.0)
    time.sleep(1.0)
    print('15 lines (仍封顶):', parts())
    tap('BACK SPACE', 5, 1.0)
    time.sleep(1.2)
    print('10 lines:', parts())
    D.shot('2286_p64_paper_boxes')
    tap('BACK SPACE', 1, 1.0)
    time.sleep(1.0)
    print('9 lines:', parts())
    tap('BACK SPACE', 1, 1.0)
    time.sleep(1.0)
    print('8 lines:', parts())
