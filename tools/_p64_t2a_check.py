# 批 64（T2 第一步）平板验证：装包 → 进打字页 → 打点 → 截图 → 与 2285 逐像素比对
import os, re, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _p38_hdc as H

HAP = os.path.join(H.ROOT, 'entry', 'build', 'default', 'outputs', 'default', 'entry-default-signed.hap')


def install():
    out, err = H.run('install', '-r', HAP, timeout=180)
    print('install:', out.replace('\n', ' ')[-200:], err[-200:])
    return out


def main():
    install()
    H.sh('hilog -r')
    time.sleep(1.0)
    H.start_app(8)
    time.sleep(2.0)
    out, _ = H.sh('hilog -x | grep -E "stage26|Stage26|layout dev|parts stageW|KeyGrid" | tail -n 40', timeout=60)
    print('--- hilog ---')
    print(out)
    t = H.dump()
    print('--- dump ids ---')
    for needle in ['p26_stage', 'p26_top_zone', 'p35_carriage', 'p25_key_grid', 'p33_key_well']:
        hits = []
        for n in H.walk(t):
            if n.get('attributes', {}).get('id') == needle:
                hits.append(H.bbox(n))
        print(needle, hits)
    p = H.shot('tmp-t2a')
    print('shot:', p)


if __name__ == '__main__':
    main()
