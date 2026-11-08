#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""探针 5：测试时钟可行性（animateTo 能否帧步进；动画曲线能否抽成纯函数单测）。

判定标准（总纲）：给出可行的帧步进机制（或可替代的关键帧快照机制）或动画曲线纯函数单测方案。
失败处理：G8 改写、动画类验证退回 AGENTS.md 既有口径（hilog 打点＋用户录屏）并进豁免表。
"""
from __future__ import annotations

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import (ProbeMeta, UNVERIFIED, TABLET, grep_repo, print_meta, read_text,
                    run_probe)

META = ProbeMeta(
    name="probe_test_clock",
    device=f"{TABLET}",
    purpose="判定 ArkUI animateTo 能否被测试时钟帧步进；动画曲线能否抽成纯函数单测",
    pass_criterion="给出可行帧步进机制（可复现实验）或可替代的关键帧快照机制；或曲线纯函数单测方案可行且有样例",
    fallback="不建测试时钟；动画类验证退回 AGENTS.md 口径（hilog 打点＋用户录屏），进豁免表",
    alternative="曲线纯函数单测（本仓已有杠杆角驱动器纯函数与 Node 单测同型）；hilog 关键帧打点；用户录屏",
    steps=[
        "测试页：animateTo 200ms 改一个可见属性，测试时钟每次 step(16ms) 采一次 @State 值",
        "若 @State 立即为终值（已知结论），再试 getUIContext().animateTo 是否有 step/clock API（查 SDK d.ts）",
        "曲线方案：把 easing 抽成纯函数，用 Node 断言 t=0 → 0、t=1 → 1、单调、关键点",
    ],
)


def _animations() -> list:
    hits = grep_repo(r"animateTo\(|\.animation\(")
    return hits


def dry_run():
    ev = []
    anims = _animations()
    ev.append(f"animateTo/.animation 调用点共 {len(anims)} 处")
    durations = {}
    for h in anims:
        for m in re.finditer(r"duration:\s*(\d+)", h["text"]):
            d = m.group(1)
            durations[d] = durations.get(d, 0) + 1
    ev.append("出现过的 duration 值（次数）: " + ", ".join(
        f"{k}ms×{v}" for k, v in sorted(durations.items(), key=lambda kv: -kv[1])))
    ev.append("已知实测定论（AGENTS.md）：animateTo 立即赋终值，观测 @State 只能证明方向与目标；"
              "screenCap 单帧 400–500ms > 350ms 动画窗，采不到首帧")
    # 查是否已有任何帧步进/时钟 API 痕迹
    step_hits = grep_repo(r"frameStep|manualClock|testClock|stepAnimation|AnimationClock")
    ev.append(f"仓库内帧步进/测试时钟痕迹: {len(step_hits)} 处")
    # 曲线单测可行性：已有纯函数样例
    driver = os.path.isfile(os.path.join(os.path.dirname(__file__), "..", "..",
                                         "entry/src/main/ets/model/LeverAngleCore.ets"))
    ev.append("曲线/驱动器纯函数化样例（LeverAngleCore）: " + ("已建，可行" if driver else "未建"))
    ev.append("SDK 是否存在公开手动步进 API：本机无 SDK 目录，无法核对 d.ts；结论不能写成“支持”")
    return UNVERIFIED, ev, "无设备与 SDK：帧步进无法实验；按 fallback 先走曲线纯函数单测＋AGENTS 口径"


def device_run():
    ev = ["targets=需真机"]
    return UNVERIFIED, ev, "帧步进实验需测试页与设备；无 SDK d.ts 无法先验 API 名——按 fallback 分支"


if __name__ == "__main__":
    print_meta(META)
    sys.exit(run_probe(META, dry_run, device_run))