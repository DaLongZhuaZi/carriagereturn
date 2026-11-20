# 批 64 验收（第三段）：打字到纸封顶（2283）→ 10/9/8 行数值（2286）→ 主链回归（2290）
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


def hold(label, n, gap=0.45, min_y=1800):
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


if __name__ == '__main__':
    H.start_app(9)
    time.sleep(0.8)
    D.goto_typing()
    time.sleep(1.4)
    hold('BACK SPACE', 60, 0.4, 1900)
    time.sleep(0.8)
    print('clear:', parts())
    # 14 行：238 字（cpl=17）
    hold('Q', 238, 0.42, 1900)
    time.sleep(1.5)
    print('cap state:', parts())
    D.shot('2283_p64_paper_cap')
    # 删 4 行 → 10 行
    hold('BACK SPACE', 68, 0.4, 1900)
    time.sleep(1.2)
    print('10 lines:', parts())
    D.shot('2286_p64_paper_boxes')
    hold('BACK SPACE', 17, 0.4, 1900)
    time.sleep(1.0)
    print('9 lines:', parts())
    hold('BACK SPACE', 17, 0.4, 1900)
    time.sleep(1.0)
    print('8 lines:', parts())
    # 2290 主链：落字 / 换行 / 退格 / 换字体
    hold('Q', 3, 0.6, 1900)
    time.sleep(0.6)
    print('typed:', parts(), D.logs('committed', 3).splitlines()[-1:])
    D.shot('2290_p64_chain_typed')
    hold('RETURN', 2, 1.0, 1900)
    time.sleep(0.8)
    print('n1:', D.logs('recalcOffset|strike clamped', 2))
    print('after return:', parts())
    hold('BACK SPACE', 2, 0.6, 1900)
    time.sleep(0.6)
    print('after del:', parts())
    # 换字体：点字体牌（Courier Prime 金属条）
    wins = D.dump_all()
    fp = D.by_id('p26_font_plate', wins)
    if fp:
        H.tap(*H.center(fp[0]))
        time.sleep(1.0)
    print('font:', D.logs('font|cycleFont', 3))
    D.shot('2290_p64_chain_font')
