#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""回车 · 第 0 批探针公共件。

探针铁律（总纲）：全部有名、有设备、有判定标准；失败触发 fallback 或砍功能，
不许把"没验过"写成"通过"。本机无 hdc 时一律输出 UNVERIFIED_NO_DEVICE，
并把静态可判定部分作为替代证据写进 evidence。

状态三值：
  PASS        —— 判定标准全部满足（只允许有设备且真实执行后给出）
  FAIL        —— 执行了且不满足（触发 fallback）
  UNVERIFIED  —— 未能执行（无设备／无 SDK／缺测试构建），附原因与替代证据
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from typing import Callable, Dict, List, Optional

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SHOTS_DIR = os.path.join(REPO_ROOT, "docs", "shots")
EVIDENCE_DIR = os.path.join(REPO_ROOT, "docs", "evidence")

PASS = "PASS"
FAIL = "FAIL"
UNVERIFIED = "UNVERIFIED_NO_DEVICE"

# 本仓回归设备（总纲验证计划）
TABLET = "MLR-AL10"
PHONE = "ADA-AL00U"


@dataclass
class ProbeMeta:
    name: str
    device: str
    purpose: str
    pass_criterion: str
    fallback: str
    alternative: str
    steps: List[str] = field(default_factory=list)


@dataclass
class ProbeResult:
    probe: str
    status: str
    device: str
    pass_criterion: str
    fallback: str
    alternative: str
    evidence: List[str]
    reason: str
    checked_at: str

    def to_dict(self) -> Dict[str, object]:
        return {
            "probe": self.probe,
            "status": self.status,
            "device": self.device,
            "pass_criterion": self.pass_criterion,
            "fallback": self.fallback,
            "alternative": self.alternative,
            "evidence": self.evidence,
            "reason": self.reason,
            "checked_at": self.checked_at,
        }


def repo_path(*parts: str) -> str:
    return os.path.join(REPO_ROOT, *parts)


def read_text(rel: str) -> str:
    path = repo_path(rel)
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return ""


def grep_repo(pattern: str, subdir: str = "entry/src/main/ets") -> List[Dict[str, object]]:
    """轻量 grep：返回 [{file, line, text}]，跳过 build/oh_modules 等。"""
    import re
    rx = re.compile(pattern)
    hits: List[Dict[str, object]] = []
    root = repo_path(subdir)
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in ("node_modules", "oh_modules", "build", ".git")]
        for fn in filenames:
            if not fn.endswith((".ets", ".ts", ".json", ".json5", ".md")):
                continue
            full = os.path.join(dirpath, fn)
            try:
                with open(full, "r", encoding="utf-8", errors="replace") as fh:
                    for i, line in enumerate(fh, 1):
                        if rx.search(line):
                            rel = os.path.relpath(full, REPO_ROOT).replace("\\", "/")
                            hits.append({"file": rel, "line": i, "text": line.strip()[:240]})
            except OSError:
                continue
    return hits


def have_hdc() -> bool:
    return shutil.which("hdc") is not None


def hdc(args: List[str], timeout: int = 20) -> Dict[str, object]:
    """执行 hdc；无 hdc 直接返回 unavailable。"""
    exe = shutil.which("hdc")
    if exe is None:
        return {"ok": False, "unavailable": True, "cmd": "hdc " + " ".join(args),
                "stdout": "", "stderr": "hdc not found in PATH", "code": -1}
    try:
        proc = subprocess.run([exe] + args, capture_output=True, text=True,
                              timeout=timeout, encoding="utf-8", errors="replace")
        return {"ok": proc.returncode == 0, "unavailable": False,
                "cmd": "hdc " + " ".join(args), "stdout": proc.stdout.strip(),
                "stderr": proc.stderr.strip(), "code": proc.returncode}
    except Exception as exc:  # pragma: no cover
        return {"ok": False, "unavailable": False, "cmd": "hdc " + " ".join(args),
                "stdout": "", "stderr": repr(exc), "code": -2}


def hdc_targets() -> List[str]:
    res = hdc(["list", "targets"])
    if res.get("unavailable") or not res.get("ok"):
        return []
    out: List[str] = []
    for line in str(res.get("stdout", "")).splitlines():
        s = line.strip()
        if s and not s.lower().startswith("[empty]"):
            out.append(s.split()[0])
    return out


def make_result(meta: ProbeMeta, status: str, evidence: List[str], reason: str) -> ProbeResult:
    from datetime import datetime
    return ProbeResult(
        probe=meta.name, status=status, device=meta.device,
        pass_criterion=meta.pass_criterion, fallback=meta.fallback,
        alternative=meta.alternative, evidence=evidence, reason=reason,
        checked_at=datetime.now().astimezone().isoformat(timespec="seconds"),
    )


def run_probe(meta: ProbeMeta,
              dry_run: Callable[[], tuple],
              device_run: Optional[Callable[[], tuple]] = None,
              argv: Optional[List[str]] = None) -> int:
    """统一入口：dry_run/device 都返回 (status, evidence:list, reason)。

    --json PATH 写结果；无参数时：有 hdc 走 device_run，否则 dry_run。
    """
    argv = list(sys.argv[1:] if argv is None else argv)
    json_path: Optional[str] = None
    mode = "auto"
    if "--json" in argv:
        i = argv.index("--json")
        if i + 1 < len(argv):
            json_path = argv[i + 1]
    if "--device" in argv:
        mode = "device"
    if "--dry-run" in argv:
        mode = "dry"
    explicit = "--dry-run" in argv or "--device" in argv

    evidence: List[str] = []
    if mode == "dry":
        status, ev, reason = dry_run()
        evidence = ev
        result = make_result(meta, status, evidence, reason)
        # dry-run 不允许报 PASS：判定标准必须真机执行
        if explicit and result.status == PASS:
            result = make_result(meta, UNVERIFIED, evidence,
                                 "dry-run：静态检查满足，但判定标准需真机执行，不能记 PASS")
    elif mode == "device" or (not explicit and have_hdc() and device_run is not None):
        targets = hdc_targets()
        if not targets:
            status, ev, reason = dry_run()
            evidence = ev
            result = make_result(meta, UNVERIFIED, evidence,
                                 "hdc 在 PATH 但 list targets 为空：设备未连接")
        else:
            evidence.append("hdc list targets -> " + ", ".join(targets))
            status, ev, reason = device_run() if device_run is not None else dry_run()
            evidence.extend(ev)
            result = make_result(meta, status, evidence, reason)
    else:
        status, ev, reason = dry_run()
        evidence = ev
        result = make_result(meta, UNVERIFIED, evidence, "无 hdc/设备；已跑 dry-run 静态部分")

    payload = result.to_dict()
    text = json.dumps(payload, ensure_ascii=False, indent=2)
    print(text)
    if json_path:
        os.makedirs(os.path.dirname(os.path.abspath(json_path)), exist_ok=True)
        with open(json_path, "w", encoding="utf-8") as fh:
            fh.write(text + "\n")
    return 0 if result.status != FAIL else 1


def print_meta(meta: ProbeMeta) -> None:
    print(f"=== {meta.name} ===")
    print(f"设备: {meta.device}")
    print(f"目的: {meta.purpose}")
    print(f"通过标准: {meta.pass_criterion}")
    print(f"失败处理: {meta.fallback}")
    print(f"替代证据: {meta.alternative}")
    if meta.steps:
        print("步骤:")
        for i, s in enumerate(meta.steps, 1):
            print(f"  {i}. {s}")
    print()