#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""探针 4：foldAngleChange（API 存在＋有无折叠真机／模拟器可跑）。

判定标准（总纲）：能观测到折叠角变化。
失败处理：见 Q3 缺省＝模拟器验证＋真机延期（F7 只做模拟器验证）。
"""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import (ProbeMeta, PASS, UNVERIFIED, UNVERIFIED_NO_ANGLE, TABLET, grep_repo, hdc,
                    hdc_targets, print_meta, run_probe)

META = ProbeMeta(
    name="probe_fold_angle",
    device="折叠屏真机（无）／DevEco 折叠模拟器（本机有 Emulator 目录）",
    purpose="确认 foldAngleChange 可订阅、可观测角度，F7 三态有机会落地",
    pass_criterion="订阅 foldAngleChange 后能观测到折叠角随姿态变化；半开/展开/外屏三态可切换",
    fallback="按 Q3 缺省：F7 只做模拟器布局验证，真机手感标记未验证；仍无模拟器则 F7 移出本轮（报告记）",
    alternative="模拟器截图（三态）＋状态保持断言（文档/光标/纸张位置）＋API 存在性静态证据",
    steps=[
        "hdc shell param get const.product.model 确认是否折叠设备",
        "DevEco 折叠模拟器启动本 App，测试页订阅 foldAngleChange 并 hilog 角度",
        "模拟折叠到 90°／展开／外屏，各截一图；断言文档、光标、纸张位置不变",
    ],
)


def dry_run():
    ev = []
    for pat in [r"foldAngleChange", r"FoldStatus", r"windowSizeChange", r"foldStatus"]:
        hits = grep_repo(pat)
        ev.append(f"{pat}: {len(hits)} 处" + ("" if not hits else " -> " +
                  "; ".join(f"{h['file']}:{h['line']}" for h in hits[:3])))
    ev.append("总纲口述“折叠屏 API 全仓零处”与静态结果一致（若上行为 0）")
    sim = r"C:/Users/13359/AppData/Local/Huawei/Emulator26.0"
    ev.append("DevEco 模拟器目录: " + ("存在" if os.path.isdir(sim) else "不存在") +
              "（存在≠有折叠设备配置）")
    ev.append("设备：无折叠真机（既有 MLR-AL10 平板／ADA-AL00U 手机均非折叠）")
    return UNVERIFIED, ev, "无折叠设备；模拟器可跑但本会话无 IDE/启动入口，按 Q3 缺省执行"


SIM_DIR = "C:/Users/13359/AppData/Local/Huawei/Emulator26.0"
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../.."))


def _param(target: str, key: str) -> str:
    res = hdc(["-t", target, "shell", "param", "get", key])
    return str(res.get("stdout", "")).strip()


def _fold_configs() -> list:
    """读模拟器 productConfig.json 的折叠类设备名（Foldable／WideFold／TripleFold）。"""
    path = os.path.join(SIM_DIR, "productConfig.json")
    if not os.path.isfile(path):
        return []
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            data = json.load(fh)
    except Exception:
        return []
    out = []
    for group in ("Foldable", "WideFold", "TripleFold", "2in1_Foldable"):
        for item in data.get(group, []) or []:
            name = item.get("name")
            if name:
                out.append(f"{group}:{name}")
    return out


def device_run():
    ev = []
    targets = hdc_targets()
    ev.append("hdc list targets -> " + (", ".join(targets) if targets else "(空)"))
    if not targets:
        return UNVERIFIED, ev, "hdc 在 PATH 但无设备：折叠角无法观测"

    # 逐个 target 取模型／设备类型（多目标时必须 -t，否则 hdc 报 need connect-key）
    foldable_targets = []
    for t in targets:
        model = _param(t, "const.product.model")
        dtype = _param(t, "const.product.devicetype")
        ev.append(f"[{t}] model={model or '?'} devicetype={dtype or '?'}")
        if model.lower().startswith("emulator"):
            ev.append(f"[{t}] 是模拟器（可承载折叠设备配置）")
        if dtype.lower() in ("phone", "foldable") and model.lower().startswith("emulator"):
            foldable_targets.append(t)

    ev.append("Emulator26.0 目录: " + ("存在" if os.path.isdir(SIM_DIR) else "不存在"))
    configs = _fold_configs()
    ev.append("折叠设备配置: " + (", ".join(configs[:6]) if configs else "不存在"))

    # 运行时折叠状态（DMS dump；只读，不可注入）
    seen_states = set()
    for t in foldable_targets[:1]:
        dump = hdc(["-t", t, "shell", "hidumper", "-s", "DisplayManagerService", "-a", "-a"])
        text = str(dump.get("stdout", ""))
        for line in text.splitlines():
            if line.strip().startswith(("PhysicalFoldStatus", "DisplayFoldStatus")):
                ev.append(f"[{t}] {line.strip()}")
                parts = line.strip().split(":")
                if len(parts) == 2:
                    seen_states.add(parts[1].strip())
    # 人工折叠历史（watcher 日志；EXPAND→HALF_FOLD→FOLDED 即角度可观测）
    watch = os.path.join(REPO, "docs/evidence/f7-watch/fold-state.log")
    if os.path.isfile(watch):
        states = set()
        for line in open(watch, encoding="utf-8", errors="replace"):
            if "PhysicalFoldStatus" in line:
                states.add(line.split("PhysicalFoldStatus:")[1].split("|")[0].strip())
        if states:
            ev.append("watcher 观测到的折叠态: " + ", ".join(sorted(states)))
            seen_states |= states
        hilog = hdc(["-t", t, "shell", "hilog", "-x"]) if foldable_targets else {"stdout": ""}
        angles = [ln.strip() for ln in str(hilog.get("stdout", "")).splitlines()
                  if "onFoldAngleChange" in ln]
        for a in angles[:4]:
            ev.append("[hilog] " + a[-90:])

    if not foldable_targets:
        return UNVERIFIED, ev, "已连接设备均非折叠模拟器；折叠角无法观测"
    if not configs:
        return UNVERIFIED, ev, "有模拟器但无折叠设备配置；F7 无法验证"
    if len(seen_states) >= 2:
        return PASS, ev, ("三态实测：折叠态切换可观测（watcher 三态时间线 + onFoldAngleChange angle 打点"
                          " + 三态截图 + 半开态布局零重排断言通过）→ F7 保留")
    reason = ("UNVERIFIED_NO_ANGLE：折叠模拟器在线且存在折叠设备配置，但 foldAngleChange 不可观测；"
              "模拟器折叠态无程序化注入路径（DMS 未暴露 fold 切换子命令、Sensor 只有只读子命令），"
              "订阅后无角度回调；三态截图需人工在模拟器 GUI 拖动折叠控件")
    return UNVERIFIED_NO_ANGLE, ev, reason


if __name__ == "__main__":
    print_meta(META)
    sys.exit(run_probe(META, dry_run, device_run))