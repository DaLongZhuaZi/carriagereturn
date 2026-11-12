import numpy as np
from PIL import Image
a=np.asarray(Image.open('docs/evidence/.tmp-a1920.png').convert('RGB'),dtype=np.int16)
b=np.asarray(Image.open('docs/evidence/.tmp-b1920.png').convert('RGB'),dtype=np.int16)
d=np.abs(a-b).max(axis=2)
ys,xs=np.where(d>30)
print('diff px',len(xs),'bbox',(int(xs.min()),int(ys.min()),int(xs.max()),int(ys.max())))
import collections
print('y bands',sorted(collections.Counter((y//100)*100 for y in ys).items(),key=lambda t:-t[1])[:8])
print('x bands',sorted(collections.Counter((x//100)*100 for x in xs).items(),key=lambda t:-t[1])[:8])
