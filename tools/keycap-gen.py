#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""【已作废·DEPRECATED 2026-11-18／第 34 批】第 33 批的三矩形扁平帽身生成器。

26 号稿 v2 修正 3：PIL 三矩形帽身是扁平 tile，门四目视硬标准不通过。
第 34 批起帽身一律用 503×512 真 3D 生成件 `cap3d-<slug>.png`（仓内已入库），
本脚本只留档，**不得再运行、不得再用它生成帽身**（运行会直接退出）。

原口径（留档）：帽身一次成型；四机按 §10 键帽 token；图例不 baked（ArkUI Text 叠加）。
"""
import os
import sys

if __name__ == "__main__":
    print("DEPRECATED: 三矩形帽身已作废（26 号稿修正 3）。请使用仓内 cap3d-<slug>.png（503×512）。")
    sys.exit(1)

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
