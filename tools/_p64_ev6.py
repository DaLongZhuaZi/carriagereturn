# 批 64 验收（第六段）：8/9/10 行数值（2286）＋ 12 行满纸与自动换纸（2283 的正确口径）
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
    m = re.findall(r'paperTop=([\d.]+) paperBox=([\d.]+)', out)
    return m[-1] if m else None


def lines_of(box):
    return round((float(box) - 37) / 27.5, 1)


if __name__ == '__main__':
    H.start_app(9)
    time.sleep(0.8)
    D.goto_typing()
    time.sleep(1.3)
    p = parts()
    print('start:', p, 'lines', lines_of(p[1]))
    # 清到 1 行
    tap('BACK SPACE', 20, 1.0)
    time.sleep(1.0)
    print('cleared:', parts())
    # 建到 8 行
    tap('RETURN', 7, 1.0)
    time.sleep(1.0)
    print('8 lines:', parts())
    tap('RETURN', 1, 1.0)
    time.sleep(1.0)
    print('9 lines:', parts())
    tap('RETURN', 1, 1.0)
    time.sleep(1.0)
    print('10 lines:', parts())
    D.shot('2286_p64_paper_boxes')
    # 到 12 行（满纸）
    tap('RETURN', 2, 1.0)
    time.sleep(1.2)
    print('12 lines:', parts())
    wins = D.dump_all()
    print('zones@12:', D.by_id('p35_carriage', wins), D.by_id('p33_key_well', wins), D.by_id('p26_basket', wins))
    D.shot('2283_p64_paper_cap')
    # 第 13 次回车 → 自动换纸
    tap('RETURN', 1, 1.2)
    time.sleep(1.4)
    print('after 13th return:', parts())
    print(D.logs('newlineAtLastRow|paperChange start|paperChange done', 4))
