# 批 64 验收截图（确定性流程）：清空 → 满行 → N1 → 纸到顶 → 10/9/8 行
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


def tap_n(label, n, gap=0.45, min_y=1800):
    c = key_center(label, min_y)
    if c is None:
        print('KEY MISSING', label)
        return 0
    for _ in range(n):
        H.tap(*c)
        time.sleep(gap)
    return n


def last_parts():
    out = D.logs('parts stageW', 3)
    m = re.findall(r'paperTop=([\d.]+) paperBox=([\d.]+)', out)
    return m[-1] if m else None


def paper_texts():
    wins = D.dump_all()
    return [(h[0], h[1]) for h in D.by_text('', wins)
            if 150 < h[1][1] < 1120 and h[0].strip()]


if __name__ == '__main__':
    H.start_app(9)
    time.sleep(0.6)
    D.goto_typing()
    time.sleep(1.2)
    tap_n('BACK SPACE', 60, 0.4, 1900)
    time.sleep(1.0)
    print('after clear:', paper_texts()[:3], 'parts=', last_parts())
    tap_n('Q', 24, 0.5, 1900)
    time.sleep(1.2)
    print('after 24Q:', paper_texts()[:4], 'parts=', last_parts())
    D.shot('2282_p64_full_line')
    print('N1:', D.logs('recalcOffset|strike clamped', 4))
    D.shot('2284_p64_N1_full_line')
    tap_n('RETURN', 14, 0.55, 1900)
    time.sleep(1.3)
    print('after 14 return: parts=', last_parts())
    D.shot('2283_p64_paper_cap')
    for n in (4, 1, 1):
        tap_n('BACK SPACE', n, 0.5, 1900)
        time.sleep(0.7)
        print('state parts=', last_parts())
    D.shot('2286_p64_paper_boxes')
