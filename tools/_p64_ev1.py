# 批 64 验收截图（平板）：2280 全貌 / 2282 满行 / 2283 纸到顶 / 2287 键盘
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _p64_dev as D
import _p38_hdc as H


def tap_key_center(label, n, min_y=1800):
    for _ in range(n):
        wins = D.dump_all()
        hits = [h for h in D.by_text(label, wins) if h[1][1] > min_y and h[0] == label]
        if not hits:
            hits = [h for h in D.by_text(label, wins) if h[1][1] > min_y]
        if not hits:
            print('missing key', label)
            return False
        H.tap(*H.center(hits[0][1]))
        time.sleep(0.32)
    return True


if __name__ == '__main__':
    H.start_app(9)
    time.sleep(0.6)
    D.goto_typing()
    time.sleep(1.2)
    wins = D.dump_all()
    for i in ['p26_stage', 'p26_top_zone', 'p35_carriage', 'p26_basket', 'p26_function_caps',
              'p26_font_plate', 'p26_cand_strip', 'p33_key_well', 'p25_key_grid']:
        print('Z', i, D.by_id(i, wins))
    D.shot('2280_p64_batch_full')
    print('--- parts before ---')
    print(D.logs('parts stageW', 4))
    # 2282：打满一行（cpl 23 → 打 24 字必然换行）
    tap_key_center('Q', 24)
    time.sleep(0.9)
    D.shot('2282_p64_full_line')
    print('--- parts after 24 chars ---')
    print(D.logs('parts stageW', 4))
    # 2283：回车到纸到顶
    tap_key_center('RETURN', 3)
    time.sleep(1.2)
    D.shot('2283_p64_paper_cap')
    print('--- parts after returns ---')
    print(D.logs('parts stageW', 4))
    print('--- n1/clamp ---')
    print(D.logs('strike clamped|recalcOffset', 6))
    D.shot('2287_p64_keyboard')
