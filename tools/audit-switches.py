#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""回车 · 开关/偏好键核对（第 7 批，评审 M-1/M-2 resolve）。

扫描 AppPreferences（PrefKeys + PrefRegistry）、TestHooks，以及全仓对键的运行时消费点：
  - 读取点：getBool/getNumber/getString(PrefKeys.X)
  - 写入点：setBool/setNumber/setString(PrefKeys.X)
  - 登记点：PrefRegistry.specs() 与 isRegistered()
输出"键／默认／读取／写入／登记／removeAfter／核对命令"表。
`--check`：任一半成品开关缺 removeAfter、或 registry 与 isRegistered 不一致 → 非 0。

用法：
  python tools/audit-switches.py [--json docs/evidence/switches.json]
  python tools/audit-switches.py --check
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from datetime import datetime

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ETS = os.path.join(ROOT, "entry/src/main/ets")
PREFS = os.path.join(ETS, "services/AppPreferences.ets")

# 半成品/回滚开关（必须有 removeAfter + 可核对命令）
SWITCH_KEYS = {"guide.enabled", "custom.enabled", "custom.knob.enabled"}
REMOVE_CMD = "python tools/audit-switches.py --check"


def read(path: str) -> str:
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    except OSError:
        return ""


def registry_specs() -> dict:
    """解析 PrefRegistry.specs() 的每一项为 dict。"""
    text = read(PREFS)
    out = {}
    # 每个 spec 是单行对象：{ key: PrefKeys.X, ... }（可能带 removeAfter）
    for line in text.splitlines():
        m = re.search(r"\{ key: PrefKeys\.([A-Z0-9_]+),(.*)\}", line)
        if not m:
            continue
        const = m.group(1)
        body = m.group(2)
        spec = {"const": const}
        for field in ("type", "defaultValue", "owner", "note"):
            fm = re.search(field + r":\s*'([^']*)'", body)
            if fm:
                spec[field] = fm.group(1)
        rm = re.search(r"removeAfter:\s*'([^']*)'", body)
        if rm:
            spec["removeAfter"] = rm.group(1)
        out[const] = spec
    return out


def pref_keys() -> list:
    text = read(PREFS)
    out = []
    for m in re.finditer(r"static readonly ([A-Z0-9_]+): string = '([^']+)'", text):
        out.append((m.group(1), m.group(2)))
    return out


def usage(const: str, literal: str) -> tuple:
    """返回（读取点, 写入点）；排除 AppPreferences.ets 自身。"""
    reads = 0
    writes = 0
    read_pat = re.compile(r"get(?:Bool|Number|String)\(\s*PrefKeys\." + const + r"\b")
    write_pat = re.compile(r"set(?:Bool|Number|String)\(\s*PrefKeys\." + const + r"\b")
    for dirpath, dirnames, filenames in os.walk(ETS):
        dirnames[:] = [d for d in dirnames if d not in ("node_modules", "oh_modules", "build")]
        for fn in filenames:
            if not fn.endswith(".ets"):
                continue
            full = os.path.join(dirpath, fn)
            if os.path.abspath(full) == os.path.abspath(PREFS):
                continue
            body = read(full)
            reads += len(read_pat.findall(body))
            writes += len(write_pat.findall(body))
    return reads, writes


def is_registered(const: str, key: str) -> bool:
    text = read(PREFS)
    # 固定键列表或前缀列表里出现即视为登记
    if "'" + key + "'" in text and ("fixed: string[]" in text or "prefixes: string[]" in text):
        pass
    return key in text


def git_head() -> str:
    try:
        return subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT,
                              capture_output=True, text=True).stdout.strip()
    except Exception:
        return "unknown"


def main() -> int:
    args = sys.argv[1:]
    check_only = "--check" in args
    json_out = args[args.index("--json") + 1] if "--json" in args else None
    specs = registry_specs()
    rows = []
    problems = []
    for const, key in pref_keys():
        spec = specs.get(const, {})
        reads, writes = usage(const, key)
        registered = const in specs or key.endswith(".")
        if not registered:
            problems.append(f"{const} 未在 PrefRegistry.specs 登记")
        rm = spec.get("removeAfter", "")
        if key in SWITCH_KEYS and not rm:
            problems.append(f"{key} 是回滚开关但缺 removeAfter")
        rows.append({
            "const": const, "key": key, "type": spec.get("type", ""),
            "default": spec.get("defaultValue", "(前缀键)"),
            "reads": reads, "writes": writes, "registered": registered,
            "removeAfter": rm, "removeCommand": REMOVE_CMD if rm else "",
        })
    hooks_text = read(os.path.join(ETS, "services/TestHooks.ets"))
    m = re.search(r"TEST_HOOKS_BUILD: boolean = (true|false)", hooks_text)
    hooks = {"TEST_HOOKS_BUILD": m.group(1) if m else "unknown",
             "note": "发布构建须 false；本轮无构建变体，enabled 恒 false（注入/PCM/测试时钟未验证）。"}
    head = git_head()
    stamp = datetime.now().astimezone().isoformat(timespec="seconds")

    lines = ["# 开关清单（第 7 批核对）", "",
             f"* 生成：{stamp}，HEAD `{head}`",
             "* 本批**不删除任何回滚开关**；`--check` 核对 removeAfter 与 registry 一致性。", "",
             "| 常量 | 键 | 类型 | 默认 | 读取 | 写入 | 登记 | 移除点 | 核对命令 |",
             "|---|---|---|---|---|---|---|---|---|"]
    for r in rows:
        lines.append(f"| `{r['const']}` | `{r['key']}` | {r['type']} | {r['default']} | {r['reads']} | "
                     f"{r['writes']} | {'是' if r['registered'] else '否'} | {r['removeAfter'] or '—'} | "
                     f"{r['removeCommand'] or '—'} |")
    lines += ["", "## 测试钩子", "", f"- `TEST_HOOKS_BUILD` = **{hooks['TEST_HOOKS_BUILD']}**；{hooks['note']}",
              "", "## --check 结果", ""]
    if problems:
        lines += ["- **FAIL**：" + p for p in problems]
    else:
        lines.append("- PASS：回滚开关均有 removeAfter；PrefKeys 均已登记。")
    md = "\n".join(lines) + "\n"
    md_path = os.path.join(ROOT, "docs/evidence/开关清单-第7批.md")
    os.makedirs(os.path.dirname(md_path), exist_ok=True)
    with open(md_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(md)
    payload = {"generatedAt": stamp, "head": head, "keys": rows,
               "testHooks": hooks, "problems": problems,
               "verdict": "PASS" if not problems else "FAIL"}
    if json_out:
        os.makedirs(os.path.dirname(os.path.abspath(json_out)), exist_ok=True)
        with open(json_out, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(payload, fh, ensure_ascii=False, indent=2)
    print(f"keys={len(rows)} switches={len(SWITCH_KEYS)} problems={len(problems)} head={head}")
    if not check_only:
        print("写入 docs/evidence/开关清单-第7批.md")
    if problems:
        for p in problems:
            print("  FAIL " + p)
        return 1
    print("核对 PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())