#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""探针 4：foldAngleChange（API 存在＋有无折叠真机／模拟器可跑）。

判定标准（总纲）：能观测到折叠角变化。
失败处理：见 Q3 缺省＝模拟器验证＋真机延期（F7 只做模拟器验证）。
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import (ProbeMeta, UNVERIFIED, TABLET, grep_repo, hdc, hdc_targets,
                    print_meta, run_probe)

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


def device_run():
    ev = ["targets=" + ", ".join(hdc_targets())]
    model = hdc(["shell", "param", "get", "const.product.model"])
    ev.append("product.model=" + str(model.get("stdout", "")))
    return UNVERIFIED, ev, "设备非折叠或未连接；折叠角无法观测"


if __name__ == "__main__":
    print_meta(META)
    sys.exit(run_probe(META, dry_run, device_run))