import sys, time
sys.path.insert(0, r'D:\HarmonyAPP\carriagereturn\tools')
import _p38_hdc as H
from PIL import Image, ImageChops
H.start_app(8)
H.tap(800,1610); time.sleep(2.2)
p = H.shot('2262_p63_N6_top')
im = Image.open(p).convert('RGB'); px=im.load()
# 在 y 110..260 找深色横条（出纸槽 #0b0a09）
best=[]
for y in range(110,260,2):
    xs=[x for x in range(300,1500) if sum(px[x,y])<90]
    if len(xs)>30: best.append((y, xs[0], xs[-1], len(xs)))
print('dark bands:', best[:6])
if best:
    y = best[0][0]; x0=best[0][1]; x1=best[0][2]
    print('slot approx', x0, x1, y, 'center', ((x0+x1)//2, y))
