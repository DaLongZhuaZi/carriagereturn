# 批 64：打印当前页面所有可见文本与 rect（决定点按哪一项）
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _p64_dev as D
import _p38_hdc as H

if __name__ == '__main__':
    wins = D.dump_all()
    seen = []
    for n in D.walk_all(wins):
        a = n.get('attributes', {})
        t = (a.get('text') or '').strip()
        aid = a.get('id') or ''
        if t:
            b = H.bbox(n)
            if b:
                seen.append((t[:24], b, aid))
    for s in seen:
        print(s)
