# 批 64（T2 第一步）验收：进打字页 → 打点 → 截图 → 与 2285 逐像素比对
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _p64_dev as D

BASE = os.path.join(D.SHOTS, '2285_p64_N2_containers.png')

if __name__ == '__main__':
    D.hilog_clear()
    ok = D.goto_typing()
    print('on_typewriter =', ok)
    time.sleep(1.5)
    print('--- hilog(zone/stage26/parts) ---')
    print(D.logs('Stage26|stage26|parts stageW|layout dev'))
    wins = D.dump_all()
    for i in ['p26_stage', 'p26_top_zone', 'p26_export_slot', 'p35_carriage', 'p25_key_grid', 'p26_basket']:
        print(i, D.by_id(i, wins))
    p = D.shot('tmp-t2a')
    print('brightness =', round(D.brightness(p), 1))
    dp, bbox = D.diff(p, BASE)
    print('diff vs 2285: %.3f%%  bbox=%s' % (dp, bbox))
