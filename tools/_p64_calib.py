# 批 64：点按可靠性标定——不同间隔下 RETURN / Q 的生效率
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


def parts():
    out = D.logs('parts stageW', 2)
    m = re.findall(r'paperTop=([\d.]+) paperBox=([\d.]+)', out)
    return m[-1] if m else None


def lines_of(box):
    return None if box is None else round((float(box) - 37) / 27.5, 1)


if __name__ == '__main__':
    H.start_app(9)
    time.sleep(0.8)
    D.goto_typing()
    time.sleep(1.3)
    p0 = parts()
    print('start parts', p0, 'lines', lines_of(p0[1] if p0 else None))
    c = center('RETURN')
    print('return center', c)
    for gap in (1.2, 1.0):
        n = 5
        for _ in range(n):
            H.tap(*c)
            time.sleep(gap)
        time.sleep(1.0)
        p = parts()
        print('gap=%.1f after %d taps: parts=%s lines=%s' % (gap, n, p, lines_of(p[1] if p else None)))
