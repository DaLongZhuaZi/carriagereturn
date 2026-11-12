from PIL import Image
import sys
tag=sys.argv[1]
def edges(path):
    im=Image.open(path).convert('L'); px=im.load(); w,h=im.size
    out={}
    for y in range(1200,1330,20):
        # first x from left where brightness > 70 (metal) after dark background
        e=None
        run=0
        for x in range(40,800):
            v=px[x,y]
            if v>70: run+=1
            else: run=0
            if run>=12: e=x-11; break
        out[y]=e
    return out
for p in [f'docs/evidence/.tmp-a{tag}.png', f'docs/evidence/.tmp-b{tag}.png']:
    print(p, edges(p))
