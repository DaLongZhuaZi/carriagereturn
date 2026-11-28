#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第 24 批（23 号稿 §10.3）：UI 标准件**颗粒对比度**质检。

判定口径（两个指标都出，避免用一个指标把"结构"误判成"颗粒"）：
  - `maxmin` = 区亮度 (max-min)/255 —— 21 号稿口径，对**平坦纸面**有效；对带花纹/倒角/金属硬边的件会偏大。
  - `hf`     = 高频残差 (p95-p5)/255 —— 用 3x3 盒式模糊作低通，取 |原图-低通| 的分位差：
               低频结构（纸的横线、帽的倒角、金属边）被滤掉，只剩颗粒/噪点，更贴近 §2.1 说的"颗粒"。
  判定：默认按 `hf ≤ 15%` 判 PASS/FAIL，同时打印 `maxmin` 供对照；两指标不一致的件在输出里标 `*`。
  采样：每件 5 个 64×64 区（中心 1＋四角各 1，内缩 10%）；任一区超阈值即整件 FAIL。

用法：
  python tools/check-part-grain.py            # 批 1 质检集：paper-* + *-1920s.png
  python tools/check-part-grain.py --all      # 全部 32 件
  python tools/check-part-grain.py --json out.json
退出码：0=按 hf 全过；1=有件不过；2=用法/环境错误。
"""
from __future__ import annotations

import glob
import json
import os
import sys

try:
    from PIL import Image, ImageFilter
except ImportError:  # pragma: no cover
    print("need Pillow: pip install pillow")
    sys.exit(2)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# W4（item05-triage §3，D-3=B）：不参与运行的契约样张已移出 HAP 到 tools/contract-assets/。
# 两处取并集，保持本工具的检查范围（batch-1 的 paper-*／keycap-*／spacebar-*）不变。
PARTS_DIRS = [
    os.path.join(ROOT, "entry", "src", "main", "resources", "rawfile", "ui-parts"),
    os.path.join(ROOT, "tools", "contract-assets", "ui-parts"),
]
LIMIT = 0.15
BOX = 64


def sample_boxes(w: int, h: int) -> list[tuple[int, int]]:
    inset_x, inset_y = int(w * 0.10), int(h * 0.10)
    xs = [w // 2 - BOX // 2, inset_x, w - inset_x - BOX]
    ys = [h // 2 - BOX // 2, inset_y, h - inset_y - BOX]
    boxes = [(max(0, xs[0]), max(0, ys[0]))]
    for x in (xs[1], xs[2]):
        for y in (ys[1], ys[2]):
            boxes.append((max(0, x), max(0, y)))
    return boxes


def region_metrics(img: Image.Image, x: int, y: int) -> tuple[float, float]:
    crop = img.crop((x, y, x + BOX, y + BOX)).convert("L")
    if crop.size[0] <= 1 or crop.size[1] <= 1:
        return 0.0, 0.0
    px = list(crop.getdata())
    maxmin = (max(px) - min(px)) / 255.0
    blur = crop.filter(ImageFilter.BoxBlur(1))
    diff = sorted(abs(a - b) for a, b in zip(px, list(blur.getdata())))
    hf = (diff[int(len(diff) * 0.95)] - diff[int(len(diff) * 0.05)]) / 255.0
    return maxmin, hf


def main() -> int:
    all_files, seen = [], set()
    for parts_dir in PARTS_DIRS:
        for p in sorted(glob.glob(os.path.join(parts_dir, "*.png"))):
            name = os.path.basename(p)
            if name in seen:  # 同名时以 HAP rawfile 优先（PARTS_DIRS 顺序）
                continue
            seen.add(name)
            all_files.append(p)
    all_files.sort(key=lambda p: os.path.basename(p))
    if not all_files:
        print(f"no PNG under {PARTS_DIRS}")
        return 2
    if "--all" in sys.argv:
        files = all_files
    else:
        # 批 1 质检范围＝§10.3 点名的两件：纸面板（paper-*）＋键帽（帽面/按下态/空格条）；
        # 字篮/字杆/横尺/拨杆/旋钮/机身属批 2 的件，用 --all 扫。
        KEYSETS = ("keycap-face-", "keycap-pressed-", "spacebar-face-")
        files = [p for p in all_files
                 if os.path.basename(p).startswith("paper-")
                 or os.path.basename(p).startswith(KEYSETS)]
    rows, failed = [], 0
    for path in files:
        name = os.path.basename(path)
        with Image.open(path) as im0:
            im = im0.convert("RGBA")
            bg = Image.new("RGBA", im.size, (238, 228, 206, 255))
            flat = Image.alpha_composite(bg, im)
            pairs = [region_metrics(flat, x, y) for (x, y) in sample_boxes(*im.size)]
        mm = max(p[0] for p in pairs)
        hf = max(p[1] for p in pairs)
        ok = hf <= LIMIT
        if not ok:
            failed += 1
        star = "*" if (ok != (mm <= LIMIT)) else " "
        rows.append({"part": name, "maxmin": round(mm, 4), "hf": round(hf, 4), "ok": ok,
                     "regions_hf": [round(p[1], 4) for p in pairs]})
        print(f"{name:<28}{star} maxmin={mm:.3f}  hf={hf:.3f}  {'PASS' if ok else 'FAIL'}")
    scope = f"ALL {len(all_files)}" if "--all" in sys.argv else "batch-1 set (paper-* + keycap-*/spacebar-*)"
    print(f"\n[SCOPE] {scope}")
    print(f"[RULE] PASS if hf <= {LIMIT:.2f} (grain); maxmin printed for reference; '*' = the two disagree")
    print(f"[RESULT] parts={len(rows)} PASS={len(rows) - failed} FAIL={failed}")
    if "--json" in sys.argv:
        out = sys.argv[sys.argv.index("--json") + 1]
        with open(out, "w", encoding="utf-8") as fh:
            json.dump({"limit": LIMIT, "rows": rows}, fh, ensure_ascii=False, indent=2)
        print(f"wrote {out}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())

