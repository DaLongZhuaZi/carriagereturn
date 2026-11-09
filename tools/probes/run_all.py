#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第 0 批探针总入口：逐个跑，汇总 JSON 与 Markdown。

用法：
  python tools/probes/run_all.py --dry-run     # 无设备：静态可判定部分
  python tools/probes/run_all.py --device      # 有设备：真实执行（各探针内实现）
  python tools/probes/run_all.py               # 自动：有 hdc 走 device，否则 dry-run

落点：
  docs/evidence/probe-results-<YYYY-MM-DD>.json        # --device
  docs/evidence/probe-results-<YYYY-MM-DD>-dryrun.json # --dry-run（门控忽略）
  docs/evidence/探针结论.md（仅生成"运行记录"节，供人工补环境事实）
退出码：0=全部跑完（含 UNVERIFIED）；1=有 FAIL。
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
EVIDENCE = os.path.join(REPO, "docs", "evidence")

PROBES = [
    "probe_touch_share.py",
    "probe_register_font.py",
    "probe_file_picker.py",
    "probe_fold_angle.py",
    "probe_test_clock.py",
    "probe_verification_capabilities.py",
]


def run_one(name: str, mode_flag: str) -> dict:
    path = os.path.join(HERE, name)
    out_json = os.path.join(EVIDENCE, ".tmp-" + name + ".json")
    cmd = [sys.executable, path, mode_flag, "--json", out_json]
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace",
                          cwd=REPO, timeout=180)
    data = {}
    try:
        with open(out_json, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except Exception:
        data = {
            "probe": name.replace(".py", ""),
            "status": "ERROR",
            "reason": (proc.stderr or proc.stdout or "no output")[-800:],
            "evidence": [f"exit={proc.returncode}"],
        }
    finally:
        try:
            os.remove(out_json)
        except OSError:
            pass
    return data


def main(argv) -> int:
    mode = "--device" if "--device" in argv else ("--dry-run" if "--dry-run" in argv else "")
    if not mode:
        from shutil import which
        mode = "--device" if which("hdc") else "--dry-run"
    results = [run_one(p, mode) for p in PROBES]
    stamp = datetime.now().astimezone().strftime("%Y-%m-%d")
    os.makedirs(EVIDENCE, exist_ok=True)
    # 干跑与 device 写不同文件名：同日干跑不得覆盖 device 结论（门控只读 device 文件）。
    json_name = f"probe-results-{stamp}-dryrun.json" if mode == "--dry-run" else f"probe-results-{stamp}.json"
    json_path = os.path.join(EVIDENCE, json_name)
    payload = {"date": stamp, "mode": mode, "results": results}
    with open(json_path, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)

    # 控制台表格
    print(f"\n模式: {mode}")
    print(f"{'探针':<34}{'状态':<24}{'原因（截断）'}")
    for r in results:
        print(f"{r.get('probe',''):<34}{r.get('status',''):<24}{str(r.get('reason',''))[:60]}")

    # 生成/更新 探针结论.md 的运行记录节
    md_path = os.path.join(EVIDENCE, "探针结论.md")
    old = ""
    if os.path.isfile(md_path):
        with open(md_path, "r", encoding="utf-8") as fh:
            old = fh.read()
    marker = "<!-- probe-run:begin -->"
    end = "<!-- probe-run:end -->"
    if marker in old and end in old:
        head = old.split(marker)[0]
        tail = old.split(end)[1]
    else:
        head = old + "\n\n## 运行记录（run_all.py 生成）\n\n" if old else "# 探针结论\n\n## 运行记录（run_all.py 生成）\n\n"
        tail = ""
    lines = [marker, f"* 运行时间：{datetime.now().astimezone().isoformat(timespec='seconds')}",
             f"* 模式：`{mode}`",
             f"* 原始 JSON：`docs/evidence/{json_name}`", "",
             "| 探针 | 状态 | 判定标准 | 失败 fallback | 原因 / 替代证据 |",
             "|---|---|---|---|---|"]
    for r in results:
        reason = str(r.get("reason", "")).replace("|", "/")
        crit = str(r.get("pass_criterion", "")).replace("|", "/")
        fb = str(r.get("fallback", "")).replace("|", "/")
        lines.append(f"| `{r.get('probe','')}` | **{r.get('status','')}** | {crit} | {fb} | {reason} |")
    lines.append(end)
    with open(md_path, "w", encoding="utf-8") as fh:
        fh.write(head + "\n".join(lines) + tail)
    print(f"\nJSON: {json_path}\nMarkdown: {md_path}")
    fails = [r for r in results if r.get("status") == "FAIL"]
    if fails:
        print(f"FAIL {len(fails)} 项：需按 fallback 处置")
        return 1
    print("全部跑完（无 FAIL；UNVERIFIED 项按设计声明的 fallback／替代证据处理）")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))