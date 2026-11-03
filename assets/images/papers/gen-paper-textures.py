#!/usr/bin/env python3
"""回车 CarriageReturn 纸纹程序化生成（4 种首发纸张）。

底色贴风格板已锁定色板；纹理由三层构成：细颗粒噪点 + 低频斑驳 +
稀疏纤维短线。格线/边距/红格/页眉一律不 baked 进纹理，由 App 代码层绘制
（素材调研报告定稿）。输出 2048×2560 JPG q92，可直接作整页纸面背景；
如需平铺，取中心 1024×1024 裁切亦可（噪点非严格无缝，接缝处需 App 侧
做羽化或整页使用）。
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.expanduser("~/workspace/carriagereturn/assets/images/papers")
W, H = 2048, 2560


def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def make_paper(name, base_hex, grain=5.0, mottle=4.0, fibers=1500, seed=0):
    rng = np.random.default_rng(seed)
    base = np.array(hex2rgb(base_hex), dtype=np.float32)
    # 细颗粒
    img = np.ones((H, W, 3), dtype=np.float32) * base
    img += rng.normal(0, grain, (H, W, 1))
    # 低频斑驳：小尺寸噪点放大 + 高斯模糊
    small = rng.normal(0, 1, (H // 32, W // 32)).astype(np.float32)
    mot = np.array(Image.fromarray(((small - small.min()) /
                                    (small.max() - small.min()) * 255).astype(np.uint8))
                       .resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(24)),
                     dtype=np.float32)
    mot = (mot - mot.mean()) / (mot.std() + 1e-6) * mottle
    img += mot[..., None]
    out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    # 纤维短线层（低透明度叠加）
    layer = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(layer)
    for _ in range(fibers):
        x = rng.integers(0, W)
        y = rng.integers(0, H)
        ang = rng.normal(0, 0.6)  # 偏水平
        ln = rng.integers(10, 45)
        x2 = int(x + ln * np.cos(ang))
        y2 = int(y + ln * np.sin(ang) * 0.4)
        alpha = int(rng.integers(8, 26))
        d.line([x, y, x2, y2], fill=alpha, width=1)
    dark = Image.new("RGB", (W, H), (60, 50, 40))
    light = Image.new("RGB", (W, H), (255, 252, 245))
    out = Image.composite(dark, out, layer.point(lambda v: v // 2))
    out = Image.composite(light, out, layer.point(lambda v: v // 3))
    path = os.path.join(OUT, name)
    out.save(path, "JPEG", quality=92)
    print(name, out.size, os.path.getsize(path))


if __name__ == "__main__":
    make_paper("paper-letter.jpg", "#eee4ce", seed=11)      # 信纸：风格板纸主色
    make_paper("paper-manuscript.jpg", "#f2ede0", seed=22)  # 稿纸：稍亮稍白
    make_paper("paper-postcard.jpg", "#e8dcc2", seed=33, grain=6.0, fibers=2200)  # 明信片：卡纸感更强
    make_paper("paper-memo.jpg", "#f2e6bd", seed=44)        # 便签：淡暖黄
