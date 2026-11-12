import numpy as np
from PIL import Image
a=np.asarray(Image.open('docs/evidence/.tmp-a1920.png').convert('L'),dtype=np.float32)
b=np.asarray(Image.open('docs/evidence/.tmp-b1920.png').convert('L'),dtype=np.float32)
def shift(band,xr=(150,1450)):
    A=a[band[0]:band[1],xr[0]:xr[1]]; B=b[band[0]:band[1],xr[0]:xr[1]]
    A=A-A.mean(); B=B-B.mean(); best=(0,-2)
    for s in range(-200,201):
        if s>=0: a1=A[:, :A.shape[1]-s]; b1=B[:, s:]
        else: a1=A[:,-s:]; b1=B[:, :B.shape[1]+s]
        if a1.shape!=b1.shape or a1.size==0: continue
        v=float((a1*b1).sum()/np.sqrt((a1*a1).sum()*(b1*b1).sum()))
        if v>best[1]: best=(s,v)
    return best
for band in [(1100,1160),(1160,1220),(1220,1280),(1240,1340),(1280,1360),(1360,1420),(1440,1520),(1600,1760)]:
    print(band, shift(band))
