#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第 24 批（23 号稿 §10.3）：UI 标准件**色板**质检（±10%）。

口径（设计稿 §2.1／§10.3，定案）：
  - 每件 3 个采样点（相对坐标，登记在 `model/PartContract.ets` 的 `colorSamples`）；
  - 实测该点像素与该件契约 `color` 比，任一通道偏差 > 10%（相对值）即 FAIL；
  - 采样对象就是仓内 `rawfile/ui-parts/` 的 PNG，不另取图。

契约来源：直接解析 `entry/src/main/ets/model/PartContract.ets`（单一真源，不在这里另抄一份表）。

用法：
  python tools/check-part-colors.py [--json out.json]
退出码：0=全过；1=有件不过；2=用法/环境错误。
"""
from __future__ import annotations

import json
import os
import re
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    print("需要 Pillow：pip install pillow")
    sys.exit(2)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PARTS_DIR = os.path.join(ROOT, "entry", "src", "main", "resources", "rawfile")
CONTRACT = os.path.join(ROOT, "entry", "src", "main", "ets", "model", "PartContract.ets")
TOL = 0.10


def parse_contract() -> list[dict]:
    """从 PartContract.ets 里抽出 (id, color, rawfile, colorSamples)。"""
    with open(CONTRACT, encoding="utf-8") as fh:
        src = fh.read()
    out = []
    for block in re.split(r"\n  \{\n", src):
        m_id = re.search(r"id: '([a-z0-9-]+)'", block)
        m_col = re.search(r"color: '#([0-9a-fA-F]{6})'", block)
        m_raw = re.search(r"rawfile: '([^']*)'", block)
        m_smp = re.search(r"colorSamples: \[(.*?)\],\n", block, re.S)
        if not (m_id and m_col):
            continue
        samples = []
        if m_smp:
            for pair in re.findall(r"\[([0-9.]+),\s*([0-9.]+)\]", m_smp.group(1)):
                samples.append((float(pair[0]), float(pair[1])))
        out.append({
            "id": m_id.group(1),
            "hex": m_col.group(1).lower(),
            "rawfile": m_raw.group(1) if m_raw else "",
            "samples": samples,
        })
    return out


def hex_rgb(h: str) -> tuple[int, int, int]:
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def main() -> int:
    parts = parse_contract()
    if not parts:
        print("未能从 PartContract.ets 解析出契约")
        return 2
    rows, failed = [], 0
    for p in parts:
        if not p["rawfile"] or not p["samples"]:
            rows.append({"id": p["id"], "verdict": "SKIP", "note": "无贴片或未登记采样点（本批只登记公式）"})
            continue
        path = os.path.join(PARTS_DIR, p["rawfile"])
        if not os.path.exists(path):
            rows.append({"id": p["id"], "verdict": "MISS", "note": path})
            failed += 1
            continue
        want = hex_rgb(p["hex"])
        worst = 0.0
        detail = []
        with Image.open(path) as im:
            im = im.convert("RGBA")
            w, h = im.size
            for (rx, ry) in p["samples"]:
                x = min(w - 1, max(0, int(rx * w)))
                y = min(h - 1, max(0, int(ry * h)))
                r, g, b, a = im.getpixel((x, y))
                if a < 8:  # 透明点不计（贴片有透明边）
                    detail.append("transparent")
                    continue
                dev = max(abs(r - want[0]) / max(1, want[0]),
                          abs(g - want[1]) / max(1, want[1]),
                          abs(b - want[2]) / max(1, want[2]))
                worst = max(worst, dev)
                detail.append(f"({r},{g},{b}) dev={dev:.3f}")
        ok = worst <= TOL
        if not ok:
            failed += 1
        rows.append({"id": p["id"], "want": p["hex"], "worst": round(worst, 4),
                     "detail": detail, "verdict": "PASS" if ok else "FAIL"})
    width = max(len(r["id"]) for r in rows)
    for r in rows:
        if r["verdict"] in ("SKIP", "MISS"):
            print(f"{r['id'].ljust(width)}  {r['verdict']:<5} {r.get('note','')}")
        else:
            print(f"{r['id'].ljust(width)}  want #{r['want']}  worst={r['worst']:.3f}  "
                  f"{'PASS' if r['verdict'] == 'PASS' else 'FAIL'}  {'; '.join(r['detail'])}")
    print(f"\n口径：每件 3 点（PartContract.ets 的 colorSamples），任一通道偏差 ≤ {int(TOL*100)}%；FAIL {failed} 件")
    if "--json" in sys.argv:
        out = sys.argv[sys.argv.index("--json") + 1]
        with open(out, "w", encoding="utf-8") as fh:
            json.dump({"tol": TOL, "rows": rows}, fh, ensure_ascii=False, indent=2)
        print(f"已写 {out}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
