#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""回车 · 1920s 回归门比对工具（第 0 批固化口径，2026-11-09）。

口径（总纲写死，不许在本工具外另立一套）：
  基线：docs/shots/332_metal3.jpeg（1920s 冻结基准）
  阈值：30（max 通道差 |dR|/|dG|/|dB| 的最大值 > 30 即该像素算"不同"）
  区域（按整图归一化坐标，左闭右开）：
    键盘区     y 0.62–0.98，x 全宽
    车架左区   x 0–0.33，  y 0.40–0.62
    车架中区   x 0.33–0.67，y 0.40–0.62
    车架右区   x 0.67–1.0， y 0.40–0.62
  纸面整体排除；状态栏（顶部 5%）在区域之外，天然排除。
  通过判据：四区"超阈值像素占比"全部为 0.00%。

用法：
  python tools/gate-compare.py <基线图> <当前图> [--scale 400x640] [--json out.json]
  python tools/gate-compare.py --self-test

退出码：0=通过；1=门未过；2=用法/文件错误。
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Dict, List, Tuple

try:
    from PIL import Image
    import numpy as np
except Exception as exc:  # pragma: no cover
    print(f"[gate-compare] 缺少依赖 Pillow/numpy: {exc}", file=sys.stderr)
    sys.exit(2)

THRESHOLD = 30
# (name, x0, x1, y0, y1) —— 归一化，y 向下
REGIONS: List[Tuple[str, float, float, float, float]] = [
    ("keyboard", 0.00, 1.00, 0.62, 0.98),
    ("frame_left", 0.00, 0.33, 0.40, 0.62),
    ("frame_mid", 0.33, 0.67, 0.40, 0.62),
    ("frame_right", 0.67, 1.00, 0.40, 0.62),
]
REGION_ORDER = [r[0] for r in REGIONS]


def load_rgb(path: str) -> Image.Image:
    if not os.path.isfile(path):
        raise FileNotFoundError(path)
    return Image.open(path).convert("RGB")


def resize_to(img: Image.Image, size: Tuple[int, int]) -> Image.Image:
    if img.size == size:
        return img
    return img.resize(size, Image.LANCZOS)


def region_box(size: Tuple[int, int], region: Tuple[str, float, float, float, float]) -> Tuple[int, int, int, int]:
    w, h = size
    _, x0, x1, y0, y1 = region
    left = int(round(x0 * w))
    right = int(round(x1 * w))
    top = int(round(y0 * h))
    bottom = int(round(y1 * h))
    # 至少 1 像素，避免极小图裁成空区
    right = max(right, left + 1)
    bottom = max(bottom, top + 1)
    return left, top, right, bottom


def compare_arrays(base: np.ndarray, cur: np.ndarray, threshold: int = THRESHOLD) -> Dict[str, dict]:
    if base.shape != cur.shape:
        raise ValueError(f"shape mismatch: {base.shape} vs {cur.shape}")
    # max 通道差
    diff = np.abs(base.astype(np.int16) - cur.astype(np.int16))
    maxdiff = diff.max(axis=2)
    h, w = maxdiff.shape
    out: Dict[str, dict] = {}
    for region in REGIONS:
        name = region[0]
        left, top, right, bottom = region_box((w, h), region)
        block = maxdiff[top:bottom, left:right]
        total = int(block.size)
        bad = int((block > threshold).sum())
        pct = (bad / total * 100.0) if total else 0.0
        out[name] = {
            "region": name,
            "box_px": [left, top, right, bottom],
            "pixels": total,
            "over_threshold": bad,
            "percent": round(pct, 2),
            "max_channel_diff": int(block.max()) if total else 0,
            "passed": bad == 0,
            "box": [round(v, 3) for v in region[1:]],
        }
    return out


def run(baseline: str, current: str, scale: str | None, threshold: int = THRESHOLD) -> dict:
    base_img = load_rgb(baseline)
    cur_img = load_rgb(current)
    if scale:
        try:
            sw, sh = [int(v) for v in scale.lower().split("x")]
        except Exception:
            raise ValueError("--scale 需要 WxH，例如 400x640")
        size = (sw, sh)
        base_img = resize_to(base_img, size)
        cur_img = resize_to(cur_img, size)
    else:
        cur_img = resize_to(cur_img, base_img.size)
    base = np.asarray(base_img)
    cur = np.asarray(cur_img)
    regions = compare_arrays(base, cur, threshold)
    passed = all(v["passed"] for v in regions.values())
    return {
        "baseline": os.path.abspath(baseline),
        "current": os.path.abspath(current),
        "size": [base_img.size[0], base_img.size[1]],
        "scale": scale,
        "threshold": threshold,
        "regions": regions,
        "verdict": "PASS" if passed else "FAIL",
        "criterion": "四区超阈值像素占比全部为 0.00% 才通过",
    }


def print_table(result: dict) -> None:
    print(f"基线: {result['baseline']}")
    print(f"当前: {result['current']}")
    print(f"尺寸: {result['size'][0]}x{result['size'][1]}  阈值: {result['threshold']}  "
          f"判据: {result['criterion']}")
    print(f"{'区域':<12}{'像素数':>10}{'超阈像素':>10}{'占比':>8}{'最大通道差':>10}  结果")
    for name in REGION_ORDER:
        r = result["regions"][name]
        print(f"{name:<12}{r['pixels']:>10}{r['over_threshold']:>10}{r['percent']:>7.2f}%"
              f"{r['max_channel_diff']:>10}  {'PASS' if r['passed'] else 'FAIL'}")
    print(f"结论: {result['verdict']}")


def self_test() -> int:
    """合成图自测：验证口径本身（不依赖设备）。"""
    w, h = 400, 640
    rng = np.random.default_rng(20261109)
    base = rng.integers(0, 40, size=(h, w, 3), dtype=np.uint8)
    # 纸面区（y 0.10–0.35）画白，键盘/车架区另有纹理
    base[int(h * 0.10):int(h * 0.35), int(w * 0.10):int(w * 0.90)] = 240
    failures: List[str] = []

    def check(name: str, cond: bool, detail: str = "") -> None:
        print(f"[self-test] {name}: {'ok' if cond else 'FAIL'} {detail}")
        if not cond:
            failures.append(name)

    # 1 同图 → 四区 0.00%
    regions = compare_arrays(base, base)
    check("identical", all(v["percent"] == 0.0 for v in regions.values()))

    # 2 +20 差（≤30）在键盘区 → 仍 0.00%
    cur = base.copy()
    cur[int(h * 0.70):int(h * 0.90), :] = np.clip(
        cur[int(h * 0.70):int(h * 0.90), :].astype(np.int16) + 20, 0, 255).astype(np.uint8)
    regions = compare_arrays(base, cur)
    check("below-threshold-ignored", regions["keyboard"]["percent"] == 0.0,
          f"maxdiff={regions['keyboard']['max_channel_diff']}")

    # 3 +60 差只在车架左区 → 左区 FAIL，其余 PASS
    cur = base.copy()
    y0, y1 = int(h * 0.45), int(h * 0.55)
    x0, x1 = int(w * 0.05), int(w * 0.25)
    cur[y0:y1, x0:x1] = np.clip(cur[y0:y1, x0:x1].astype(np.int16) + 60, 0, 255).astype(np.uint8)
    regions = compare_arrays(base, cur)
    check("left-region-detected", regions["frame_left"]["over_threshold"] > 0)
    check("region-isolation", regions["frame_right"]["percent"] == 0.0 and
          regions["keyboard"]["percent"] == 0.0 and regions["frame_mid"]["percent"] == 0.0)

    # 4 纸面区改动 → 四区不受影响（纸面整体排除）
    cur = base.copy()
    py0, py1 = int(h * 0.12), int(h * 0.30)
    px0, px1 = int(w * 0.2), int(w * 0.8)
    cur[py0:py1, px0:px1] = 0
    regions = compare_arrays(base, cur)
    check("paper-excluded", all(v["percent"] == 0.0 for v in regions.values()))

    # 5 状态栏（顶部 5%）改动 → 四区不受影响
    cur = base.copy()
    cur[0:int(h * 0.04), :] = 255
    regions = compare_arrays(base, cur)
    check("status-bar-excluded", all(v["percent"] == 0.0 for v in regions.values()))

    # 6 键盘 +60 → 键盘区 FAIL
    cur = base.copy()
    ky0, ky1 = int(h * 0.70), int(h * 0.80)
    cur[ky0:ky1, :] = np.clip(cur[ky0:ky1, :].astype(np.int16) + 60, 0, 255).astype(np.uint8)
    regions = compare_arrays(base, cur)
    check("keyboard-detected", regions["keyboard"]["over_threshold"] > 0)

    # 7 区域边界在整图内、四区互不重叠（车架三区拼接覆盖 y 0.40–0.62 的 x 全宽）
    boxes = {r[0]: region_box((w, h), r) for r in REGIONS}
    check("boxes-non-empty", all(b[2] > b[0] and b[3] > b[1] for b in boxes.values()))
    check("frame-tiles-full-width",
          boxes["frame_left"][0] == 0 and boxes["frame_right"][2] == w and
          boxes["frame_left"][2] == boxes["frame_mid"][0] and
          boxes["frame_mid"][2] == boxes["frame_right"][0])

    print(f"[self-test] {'PASS' if not failures else 'FAIL'} ({len(failures)} 项失败)")
    return 0 if not failures else 1


def main(argv: List[str]) -> int:
    ap = argparse.ArgumentParser(description="1920s 回归门比对（阈值 30、四区、纸面排除）")
    ap.add_argument("baseline", nargs="?", help="基线图（docs/shots/332_metal3.jpeg）")
    ap.add_argument("current", nargs="?", help="当前截图")
    ap.add_argument("--scale", default=None, help="统一缩放，例如 400x640（历史口径）")
    ap.add_argument("--threshold", type=int, default=THRESHOLD)
    ap.add_argument("--json", default=None, help="结果写入 JSON 路径")
    ap.add_argument("--self-test", action="store_true", help="合成图自测")
    ap.add_argument("--list-regions", action="store_true", help="打印四区归一化坐标")
    args = ap.parse_args(argv)
    if args.list_regions:
        for r in REGIONS:
            print(f"{r[0]:<12} x {r[1]:.2f}-{r[2]:.2f}  y {r[3]:.2f}-{r[4]:.2f}")
        return 0
    if args.self_test:
        return self_test()
    if not args.baseline or not args.current:
        ap.print_help()
        return 2
    try:
        result = run(args.baseline, args.current, args.scale, args.threshold)
    except Exception as exc:
        print(f"[gate-compare] 失败: {exc}", file=sys.stderr)
        return 2
    print_table(result)
    if args.json:
        os.makedirs(os.path.dirname(os.path.abspath(args.json)), exist_ok=True)
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump(result, fh, ensure_ascii=False, indent=2)
        print(f"JSON 已写入: {args.json}")
    return 0 if result["verdict"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))