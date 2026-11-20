# 批 64 验收（确定性）：清空 → 17 字满行 → N1 → 回车到纸封顶 → 10/9/8 行
import os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _p64_dev as D
import _p38_hdc as H


def key_center(label, min_y=1800):
    wins = D.dump_all()
    hits = [h for h in D.by_text(label, wins) if h[1][1] > min_y and h[0] == label]
    if not hits:
        hits = [h for h in D.by_text(label, wins) if h[1][1] > min_y and label in h[0]]
    return H.center(hits[0][1]) if hits else None


def tap_n(label, n, gap=0.9, min_y=1800):
    c = key_center(label, min_y)
    if c is None:
        print('KEY MISSING', label)
        return 0
    for _ in range(n):
        H.tap(*c)
        time.sleep(gap)
    return n


def parts():
    out = D.logs('parts stageW', 2)
    m = re.findall(r'paperTop=([\d.]+) paperBox=([\d.]+)', out)
    return m[-1] if m else None


def paper_texts():
    wins = D.dump_all()
    return [(h[0], h[1]) for h in D.by_text('', wins) if 150 < h[1][1] < 1120 and h[0].strip()]


if __name__ == '__main__':
    D.install()
    D.hilog_clear()
    H.start_app(9)
    time.sleep(0.8)
    D.goto_typing()
    time.sleep(1.4)
    tap_n('BACK SPACE', 40, 0.45, 1900)
    time.sleep(0.8)
    print('clear:', paper_texts()[:2], parts())
    tap_n('Q', 18, 0.55, 1900)
    time.sleep(1.0)
    print('full line:', paper_texts()[:3], parts())
    D.shot('2282_p64_full_line')
    print('N1:', D.logs('recalcOffset|strike clamped', 3))
    D.shot('2284_p64_N1_full_line')
    tap_n('RETURN', 20, 0.9, 1900)
    time.sleep(1.2)
    print('after returns:', parts(), 'lines=', len(paper_texts()))
    D.shot('2283_p64_paper_cap')
    for n in (4, 1, 1):
        tap_n('BACK SPACE', n, 0.8, 1900)
        time.sleep(0.8)
        print('state:', parts())
    D.shot('2286_p64_paper_boxes')
