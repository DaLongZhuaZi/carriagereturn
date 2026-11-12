import numpy as np, sys
from PIL import Image
tag=sys.argv[1]
a=np.asarray(Image.open(f'docs/evidence/.tmp-a{tag}.png').convert('L'),dtype=np.float32)
b=np.asarray(Image.open(f'docs/evidence/.tmp-b{tag}.png').convert('L'),dtype=np.float32)
h,w=a.shape
def shift(band,y=(0,0)):
    A=a[band[0]:band[1],150:1450]; B=b[band[0]:band[1],150:1450]
    A=A-A.mean(); B=B-B.mean(); best=(0,-2)
    for s in range(-200,201):
        if s>=0: a1=A[:, :A.shape[1]-s]; b1=B[:, s:]
        else: a1=A[:,-s:]; b1=B[:, :B.shape[1]+s]
        if a1.shape!=b1.shape or a1.size==0: continue
        v=float((a1*b1).sum()/np.sqrt((a1*a1).sum()*(b1*b1).sum()))
        if v>best[1]: best=(s,v)
    return best
for y0 in range(700,1600,60):
    y1=min(y0+60,h)
    print((y0,y1), shift((y0,y1)))
