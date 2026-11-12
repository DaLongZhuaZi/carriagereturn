import numpy as np
from PIL import Image
def paper_left(path):
    im=Image.open(path).convert('RGB'); px=im.load(); w,h=im.size
    best=None
    for y in range(700,1300,4):
        xs=[x for x in range(0,w,2) if sum(px[x,y])/3>180]
        if len(xs)>400:
            if best is None or len(xs)>best[1]: best=(y,len(xs),min(xs))
    return best
def shift(pa,pb,band=(1600,1760)):
    a=np.asarray(Image.open(pa).convert('L'),dtype=np.float32)[band[0]:band[1],:]
    b=np.asarray(Image.open(pb).convert('L'),dtype=np.float32)[band[0]:band[1],:]
    a=a-a.mean(); b=b-b.mean(); best=(0,-2)
    for s in range(-260,261):
        if s>=0: a1=a[:, :a.shape[1]-s]; b1=b[:, s:]
        else: a1=a[:,-s:]; b1=b[:, :b.shape[1]+s]
        if a1.shape!=b1.shape or a1.size==0: continue
        v=float((a1*b1).sum()/np.sqrt((a1*a1).sum()*(b1*b1).sum()))
        if v>best[1]: best=(s,v)
    return best
import sys
tag=sys.argv[1] if len(sys.argv)>1 else '1920'
for t in ['a','b','c']:
    print(t,'paper',paper_left(f'docs/evidence/.tmp-{t}{tag}.png'))
print('roll shift a->b', shift(f'docs/evidence/.tmp-a{tag}.png',f'docs/evidence/.tmp-b{tag}.png'))
print('roll shift a->c', shift(f'docs/evidence/.tmp-a{tag}.png',f'docs/evidence/.tmp-c{tag}.png'))
