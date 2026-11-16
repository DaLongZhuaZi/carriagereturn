#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第 24 批（23 号稿 §10.4／§10.1）：UI 件**几何主权**校验。

做两件事：
  1. **公式自洽**：从 `model/PartContract.ets` 读 `STAGE_1920S_PHONE`，按附录 A 的 D1／D2／D5／D7／D8／D24
     重新算一遍，与契约里登记的常量比对（偏差 ≤1vp 才算自洽）。
  2. **对真机量测**：可选 `--measured <json>`，文件形如
     `{"stageW":362.7,"paperLeftLineEnd":-119.05,"paperRightLineEnd":211.65,"funcRowH":40}`
     （实测值由截图量测填），逐项与公式值比对。

用法：
  python tools/check-part-geometry.py
  python tools/check-part-geometry.py --measured docs/evidence/p24-geometry.json
退出码：0=全过；1=有不一致；2=用法/环境错误。
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTRACT = os.path.join(ROOT, "entry", "src", "main", "ets", "model", "PartContract.ets")
TOL = 1.0


def parse_stage() -> dict:
    with open(CONTRACT, encoding="utf-8") as fh:
        src = fh.read()
    m = re.search(r"export const STAGE_1920S_PHONE[^{]*\{(.*?)\n\};", src, re.S)
    if not m:
        raise SystemExit("STAGE_1920S_PHONE not found in PartContract.ets")
    out = {}
    for k, v in re.findall(r"(\w+):\s*(-?[0-9.]+),", m.group(1)):
        out[k] = float(v)
    return out


def main() -> int:
    s = parse_stage()
    stageW, marginH, panelMargin, fs = s["stageW"], s["marginH"], s["panelMargin"], s["fontSizeVp"]
    adv = s["advanceEn"]
    # 附录 A 重算（D1/D2/D5/D7/D8/D24）
    arch = stageW / 2.0                      # D1
    base = arch - marginH                    # D2
    Pw = stageW - 2 * panelMargin            # Q16(a)
    Ph = Pw * 1.414                          # D7
    lh = fs * 30.0 / 17.0                    # D7
    chars = int((Pw - 2 * marginH) // adv)   # D5
    lineW = chars * adv                      # D5
    maxRows = int((Ph - 44 - 20) // lh)      # D7
    leftEnd = base - lineW                   # D4/D8
    rightEnd = base + Pw - lineW             # D4
    rightClip0 = max(0.0, base + Pw - stageW)  # D24
    checks = [
        ("D1 archFixX", s["archFixX"], arch),
        ("D2 paperBaseX", s["paperBaseX"], base),
        ("Q16a Pw", s["Pw"], Pw),
        ("D7 Ph", s["Ph"], Ph),
        ("D7 lineHeight", s["lineHeightVp"], lh),
        ("D5 charsPerLine", s["charsPerLine"], chars),
        ("D5 lineWidth", s["lineWidth"], lineW),
        ("D7 maxRows", s["maxRows"], maxRows),
    ]
    bad = 0
    print(f"{'item':<20}{'contract':>12}{'derived':>12}{'dev':>8}  verdict")
    for name, got, want in checks:
        dev = abs(got - want)
        ok = dev <= TOL
        bad += 0 if ok else 1
        print(f"{name:<20}{got:>12.2f}{want:>12.2f}{dev:>8.2f}  {'PASS' if ok else 'FAIL'}")
    print(f"\n[D8] 行末 paperLeft(推导) = {leftEnd:.2f}vp（左裁剪 {max(0.0, -leftEnd):.2f}vp）")
    print(f"[D4] 行末 paperRight(推导) = {rightEnd:.2f}vp")
    print(f"[D9] 行末右裁剪 = {max(0.0, rightEnd - stageW):.2f}vp")
    print(f"[D24] 行首右裁剪 = {rightClip0:.2f}vp")

    if "--measured" in sys.argv:
        path = sys.argv[sys.argv.index("--measured") + 1]
        if not os.path.exists(path):
            print(f"measured file not found: {path}")
            return 2
        with open(path, encoding="utf-8") as fh:
            meas = json.load(fh)
        print("\n[真机量测比对]")
        pairs = [
            ("stageW", stageW), ("paperLeftLineEnd", leftEnd), ("paperRightLineEnd", rightEnd),
            ("funcRowH", s["H_funcRow"]),
        ]
        for key, want in pairs:
            if key in meas:
                dev = abs(float(meas[key]) - want)
                ok = dev <= TOL
                bad += 0 if ok else 1
                print(f"  {key:<20} meas={float(meas[key]):>9.2f}  derived={want:>9.2f}  dev={dev:>5.2f}  {'PASS' if ok else 'FAIL'}")

    # ---- §10.2(a) 逐帽抽查：契约（keymap CapDef）vs 真机 dump 的帽心 ----
    if "--caps-dump" in sys.argv:
        km_name = "1920s-upright-keymap.json"
        if "--keymap" in sys.argv:
            km_name = sys.argv[sys.argv.index("--keymap") + 1]
        origin_y = s.get("keyGridOriginY", 570.0)
        if "--origin-y" in sys.argv:
            origin_y = float(sys.argv[sys.argv.index("--origin-y") + 1])
        cap_bad = check_caps(sys.argv[sys.argv.index("--caps-dump") + 1],
                             s["stageW"], s["H_keyGrid"], km_name, origin_y)
        bad += cap_bad

    print(f"\n[RESULT] inconsistencies={bad} (tol {TOL}vp；帽心 tol 2%)")
    return 0 if bad == 0 else 1


def check_caps(dump_path: str, grid_w: float, grid_h: float,
               keymap_name: str = "1920s-upright-keymap.json",
               origin_y_vp: float = 570.0) -> int:
    """读 uitest dumpLayout 的 JSON：取键区单字符标签节点中心，与 keymap CapDef 帽心（比例×网格尺寸）比对。

    判据：|devX|/gridW ≤ 0.02 且 |devY|/gridH ≤ 0.02（§3.3 硬契约 ≤2%）。
    键区原点＝键盘网格挂载点（批 1 实测 originYVp＝570.0vp、originX＝0），px→vp 用 3.375（1224/362.7）。
    """
    import json
    keymap = os.path.join(ROOT, "entry", "src", "main", "resources", "rawfile", "keymap", keymap_name)
    with open(dump_path, encoding="utf-8") as fh:
        dump = json.load(fh)
    with open(keymap, encoding="utf-8") as fh:
        km = json.load(fh)
    band = km["bands"]["phone"]
    caps = {}
    for row in km["rows"]:
        for c in row["caps"]:
            # 同一 label 可能有多帽（1960s 左右两个 Shift）：保留候选列表，取最近者比对
            caps.setdefault(c["label"], []).append(
                ((c["x"] - band["x0"]) / float(band["w"]),
                 (row["y"] - band["y0"]) / float(band["h"])))
    px_per_vp = 3.375
    origin_x_vp = 0.0
    found = []

    def walk(n):
        a = n.get("attributes", {}) or {}
        txt = (a.get("text") or "").strip()
        b = a.get("bounds") or ""
        m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", b)
        if m and txt in caps:
            cx = (int(m.group(1)) + int(m.group(3))) / 2.0 / px_per_vp - origin_x_vp
            cy = (int(m.group(2)) + int(m.group(4))) / 2.0 / px_per_vp - origin_y_vp
            # 只取键区带内的节点：dump 含常驻主页等其它层，单字符文本（'0'/'A' 等）会误命中
            if -6.0 <= cy <= grid_h + 6.0:
                found.append((txt, cx, cy))
        for ch in n.get("children", []) or []:
            walk(ch)

    walk(dump)
    print(f"\n[逐帽抽查 dump] {dump_path}  实测帽心数={len(found)}/{len(caps)}")
    worst = 0.0
    bad = 0
    for txt, cx, cy in found:
        best = None
        for (rx, ry) in caps[txt]:
            wx, wy = rx * grid_w, ry * grid_h
            dd = max(abs(cx - wx) / grid_w, abs(cy - wy) / grid_h)
            if best is None or dd < best[0]:
                best = (dd, wx, wy)
        dd, want_x, want_y = best
        dx = abs(cx - want_x) / grid_w
        dy = abs(cy - want_y) / grid_h
        worst = max(worst, dd)
        if dd > 0.02:
            bad += 1
            print(f"  FAIL {txt:<12} meas=({cx:.2f},{cy:.2f}) want=({want_x:.2f},{want_y:.2f}) "
                  f"dx%={dx * 100:.2f} dy%={dy * 100:.2f}")
    print(f"  帽心最大偏差 = {worst * 100:.2f}%（判据 ≤2%）  {'PASS' if bad == 0 else 'FAIL'}")
    return bad


if __name__ == "__main__":
    sys.exit(main())
