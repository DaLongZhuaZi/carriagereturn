#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第 0 批验证总跑：一次跑完所有本机可执行证据，落 docs/evidence/batch0-checks.md。

每项记录：命令、退出码、结果（PASS/FAIL/EXPECTED-FAIL）、输出尾部。
EXPECTED-FAIL 用于记录"已知不应通过"的对照（540 vs 332 门图），不算本批失败。
"""
from __future__ import annotations

import glob
import os
import subprocess
import sys
from datetime import datetime

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "docs", "evidence", "final-checks.md")


def run(cmd, cwd=ROOT, timeout=300):
    try:
        p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=timeout)
        return p.returncode, (p.stdout or "") + (("\n[stderr]\n" + p.stderr) if p.stderr else "")
    except Exception as exc:
        return -1, repr(exc)


def main() -> int:
    tests = sorted(glob.glob(os.path.join(ROOT, "tools", "tests", "*.test.mjs")))
    checks = [
        ("arkts-self-test", ["node", "tools/check-arkts.mjs", "--self-test"], False),
        ("arkts-structural", ["node", "tools/check-arkts.mjs", "--quiet"], False),
        ("contracts", ["python", "tools/check-contracts.py"], False),
        ("unit-tests", ["node", "--experimental-strip-types", "--test"] + tests, False),
        ("model-tsc", ["python", "tools/check-model-types.py"], False),
        ("gate-self-test", ["python", "tools/gate-compare.py", "--self-test"], False),
        ("gate-500-vs-332", ["python", "tools/gate-compare.py",
                             "docs/shots/332_metal3.jpeg", "docs/shots/500_gate.jpeg",
                             "--scale", "400x640"], False),
        ("gate-540-vs-332", ["python", "tools/gate-compare.py",
                             "docs/shots/332_metal3.jpeg", "docs/shots/540_1920s_gate.jpeg",
                             "--scale", "400x640"], True),
        ("audio-verify", ["python", "tools/audio-verify.py", "--json",
                          "docs/evidence/audio-verify.json"], False),
        ("icon-audit", ["python", "tools/audit-icons.py", "--json",
                        "docs/evidence/icon-audit.json"], False),
        ("probes-dry-run", ["python", "tools/probes/run_all.py", "--dry-run"], False),
        ("switch-audit", ["python", "tools/audit-switches.py", "--json",
                          "docs/evidence/switches.json"], False),
        ("audio-verify-all-packs", ["python", "tools/audio-verify.py", "--json",
                                    "docs/evidence/audio-verify.json"], False),
    ]
    rows = []
    failed = []
    for name, cmd, expected_fail in checks:
        code, out = run(cmd)
        ok = (code == 0)
        if expected_fail:
            status = "EXPECTED-FAIL" if not ok else "UNEXPECTED-PASS"
            if ok:
                failed.append(name)
        else:
            status = "PASS" if ok else "FAIL"
            if not ok:
                failed.append(name)
        rows.append((name, " ".join(cmd), code, status, out.strip().splitlines()[-8:]))

    lines = [f"# 最终验证总跑（第 7 批，{datetime.now().astimezone().isoformat(timespec='seconds')}）", ""]
    lines.append("| 项 | 命令 | 退出码 | 结果 |")
    lines.append("|---|---|---|---|")
    for name, cmd, code, status, _ in rows:
        lines.append(f"| {name} | `{cmd}` | {code} | **{status}** |")
    lines.append("")
    for name, cmd, code, status, tail in rows:
        lines.append(f"## {name} — {status}")
        lines.append("```")
        lines.extend(tail if tail else ["(no output)"])
        lines.append("```")
        lines.append("")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print(f"写入 {OUT}")
    for name, _, code, status, _ in rows:
        print(f"{name:<22}{status:<15}exit={code}")
    if failed:
        print("FAIL: " + ", ".join(failed))
        return 1
    print("全部通过（含 1 项 EXPECTED-FAIL 对照）")
    return 0


if __name__ == "__main__":
    sys.exit(main())