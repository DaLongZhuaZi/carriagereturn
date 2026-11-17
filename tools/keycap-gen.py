#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第 33 批（26 号稿 §7.8）：3D 键帽帽身生成（顶面＋侧壁＋底影，一张图，透明底）。

口径：帽身一次成型；四机按 §10 键帽 token；图例不 baked（ArkUI Text 叠加）。
输出：entry/src/main/resources/rawfile/ui-parts/cap3d-<slug>.png（4 张）。
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "entry", "src", "main", "resources", "rawfile", "ui-parts")
TOKENS = {"1920s": "#eae5d9", "1930s": "#d8cbb6", "1950s": "#d0c1ad", "1960s": "#bfb8ae"}
W, H = 300, 170

def shade(hex_color, k):
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return (max(0, min(255, int(r * k))), max(0, min(255, int(g * k))), max(0, min(255, int(b * k))))

for slug, tok in TOKENS.items():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # 底影
    d.rounded_rectangle([14, 128, W - 14, 156], radius=16, fill=(0, 0, 0, 70))
    # 侧壁（略暗）
    d.rounded_rectangle([10, 22, W - 10, 140], radius=18, fill=shade(tok, 0.62) + (255,))
    # 顶面（亮）
    d.rounded_rectangle([10, 8, W - 10, 120], radius=18, fill=shade(tok, 1.0) + (255,))
    # 顶面高光（顶部一条）
    d.rounded_rectangle([20, 14, W - 20, 34], radius=10, fill=shade(tok, 1.10) + (255,))
    img.save(os.path.join(OUT, f"cap3d-{slug}.png"))
    print("cap3d-" + slug)
