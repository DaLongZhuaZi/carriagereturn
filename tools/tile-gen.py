#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第 28 批（24 号稿 §2.2／R5(a)）：机身三档颗粒贴片生成器（PIL/numpy，不走图片生成器）。

口径：
  - 每档一张 256×256 贴片；底色＝本档 token 色值；亮度调制 ±15%（单值），灰度噪声（RGB 同乘），
    「与色值解耦」：噪声是标量场，乘到 token 上，不携带任何几何。
  - **周期性**：噪声由整数格点频率的正弦叠加而成（fx/fy 为整数 → 在 256 上严格周期），
    因此平铺时不会在 256px 接缝出现 1px 不连续；「不含任何几何」成立。
  - 输出：entry/src/main/resources/rawfile/ui-parts/tile-<machine>-<tier>.png（4×3＝12 张）。

用法：python tools/tile-gen.py [--check]
"""
from __future__ import annotations
import os
import sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "entry", "src", "main", "resources", "rawfile", "ui-parts")
SIZE = 256
MOD = 0.15  # 亮度调制 ±15%（单值）

# 24 号稿 §2.1 三档 token（顺序 paperwell / base / keybed）
TOKENS = {
    "1920s": ["#25201b", "#312b24", "#3b342b"],
    "1930s": ["#342f2b", "#3d3732", "#453e38"],
    "1950s": ["#c6b7a4", "#c8b9a6", "#cabba7"],
    "1960s": ["#8e8880", "#928b82", "#96908a"],
}
TIERS = ["paperwell", "base", "keybed"]
# 第 32 批（25 号稿 §2.1）：钢板 token（4 张，暖灰 1950s/1960s）
STEEL_TOKENS = {"1920s": "#5e5e5e", "1930s": "#636363", "1950s": "#d0c9b9", "1960s": "#a59f96"}


def hex_rgb(h: str):
    h = h.lstrip("#")
    return np.array([int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)], dtype=np.float64)


def periodic_noise(seed: int) -> np.ndarray:
    """FFT 低通白噪声：严格周期（频域处理后再反变换），各向同性、无可读几何。

    v1 的「整数格点正弦叠加」虽然严格周期，但会形成方向性波纹（读作木纹/几何），
    改频域低通：白噪声 → 高斯低通 → 逆 FFT，结果在 256 边界上天然连续。
    """
    rng = np.random.default_rng(seed)
    white = rng.normal(size=(SIZE, SIZE))
    spec = np.fft.fft2(white)
    fy = np.fft.fftfreq(SIZE)[:, None]
    fx = np.fft.fftfreq(SIZE)[None, :]
    sigma = 0.07  # 相关长度 ≈ 1/σ ≈ 14px（细颗粒）
    filt = np.exp(-(fx * fx + fy * fy) / (2.0 * sigma * sigma))
    field = np.real(np.fft.ifft2(spec * filt))
    field -= field.mean()
    m = float(np.max(np.abs(field)))
    return field / (m if m > 0 else 1.0)


def make_tile(color_hex: str, seed: int) -> np.ndarray:
    rgb = hex_rgb(color_hex)
    n = periodic_noise(seed) * MOD
    out = rgb[None, None, :] * (1.0 + n[:, :, None])
    return np.clip(np.round(out), 0, 255).astype(np.uint8)


def make_plate(color_hex: str, seed: int) -> np.ndarray:
    """钢板拉丝贴片：各向异性周期噪声（沿 x 相关 ≈32px、沿 y ≈2px），亮度调制 ±8%。

    频域高斯滤波：σx = 1/32、σy = 1/2（写死）；FFT 处理后再反变换 → 256 边界严格周期。
    """
    rng = np.random.default_rng(seed)
    white = rng.normal(size=(SIZE, SIZE))
    spec = np.fft.fft2(white)
    fy = np.fft.fftfreq(SIZE)[:, None]
    fx = np.fft.fftfreq(SIZE)[None, :]
    sx, sy = 1.0 / 32.0, 1.0 / 2.0
    filt = np.exp(-(fx * fx) / (2.0 * sx * sx) - (fy * fy) / (2.0 * sy * sy))
    field = np.real(np.fft.ifft2(spec * filt))
    field -= field.mean()
    m = float(np.max(np.abs(field)))
    field = field / (m if m > 0 else 1.0)
    rgb = hex_rgb(color_hex)
    out = rgb[None, None, :] * (1.0 + field[:, :, None] * 0.08)
    return np.clip(np.round(out), 0, 255).astype(np.uint8)


def wrap_residual(arr: np.ndarray) -> float:
    """接缝残差：首末列/行的环向差 vs 内部相邻差的最大值之比（越接近 1 越无接缝）。"""
    a = arr.astype(np.float64)
    interior = np.abs(np.diff(a, axis=1)).mean()
    seam = np.abs(a[:, 0] - a[:, -1]).mean()
    interior_v = np.abs(np.diff(a, axis=0)).mean()
    seam_v = np.abs(a[0, :] - a[-1, :]).mean()
    return max(seam / interior if interior > 0 else 0.0,
               seam_v / interior_v if interior_v > 0 else 0.0)


def main() -> int:
    check = "--check" in sys.argv
    os.makedirs(OUT, exist_ok=True)
    seed = 2800
    for machine, toks in TOKENS.items():
        for ti, tier in enumerate(TIERS):
            arr = make_tile(toks[ti], seed)
            seed += 1
            path = os.path.join(OUT, f"tile-{machine}-{tier}.png")
            if not check:
                Image.fromarray(arr, "RGB").save(path)
            r = wrap_residual(arr)
            ok = r <= 1.35  # 接缝差与内部差同量级（周期噪声理论值≈1.0）
            print(f"{os.path.basename(path):<28} token={toks[ti]} wrap={r:.3f} {'PASS' if ok else 'FAIL'}")
    # 第 32 批：钢板拉丝贴片（不进 TIERS 主循环，避免产出 12 张闲置 tile-*-steel.png）
    for machine, tok in STEEL_TOKENS.items():
        arr = make_plate(tok, seed)
        seed += 1
        path = os.path.join(OUT, f"plate-{machine}.png")
        if not check:
            Image.fromarray(arr, "RGB").save(path)
        r = wrap_residual(arr)
        print(f"{os.path.basename(path):<28} token={tok} wrap={r:.3f} {'PASS' if r <= 1.35 else 'FAIL'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
