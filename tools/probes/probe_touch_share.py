#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""探针 1：碰一碰分享 API（模块／类／函数名、双机 NFC 条件）。

判定标准（总纲）：命名出碰一碰分享 API 且单机可调通（不崩、有回调）。
失败处理：砍碰一碰传输，按 Q5 缺省走 ShareKit＋指引（碰一碰标记未验证）。
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import (ProbeMeta, UNVERIFIED, PASS, FAIL, TABLET, grep_repo, have_hdc,
                    hdc, hdc_targets, print_meta, run_probe)

META = ProbeMeta(
    name="probe_touch_share",
    device=f"{TABLET} + 第二台支持 NFC 的设备（双机对碰）",
    purpose="确认碰一碰分享的 API 形态与双机条件，决定 F4 走碰一碰还是 ShareKit＋指引",
    pass_criterion="命名出 API（模块／类／函数）且单机可调通：调用不崩、有可观测回调",
    fallback="砍碰一碰传输，F4 只做 ShareKit＋指引；碰一碰标记未验证（Q5 缺省）",
    alternative="单机 ShareKit 全链路（分享面板调起、回调 observable）＋UI 截图",
    steps=[
        "hdc list targets 确认两台设备在线（一台装本 App、一台可碰）",
        "在测试构建里调用候选 API（NearLink／Handover／Share Kit 碰一碰）",
        "记录返回码／回调／hilog；截图面板出现（操作前后各一张）",
    ],
)

CANDIDATES = [
    "nearlink", "NearLinkKit", "oneHop", "OneHop", "handover", "Handover",
    "tapShare", "TapShare", "nfc", "NFC", "systemShare", "ShareController",
]


def dry_run():
    ev = []
    for pattern in CANDIDATES:
        hits = grep_repo(pattern)
        if hits:
            ev.append(f"仓库命中 {pattern}: " + "; ".join(
                f"{h['file']}:{h['line']}" for h in hits[:3]))
    if not any(x.startswith("仓库命中") for x in ev):
        ev.append("仓库内未出现任何碰一碰／NearLink／Handover API 引用（现状：零处）")
    # 现有分享实现（唯一入口在 ShareService；本批前为 Index.shareFile）
    share_hits = grep_repo("ShareController|SharedData|shareFile")
    ev.append(f"现有分享实现命中 {len(share_hits)} 处：" + "; ".join(
        f"{h['file']}:{h['line']}" for h in share_hits[:5]))
    sdk = os.environ.get("OHOS_SDK_HOME", "")
    if sdk and os.path.isdir(sdk):
        ev.append(f"SDK 目录存在: {sdk}（可进一步在 d.ts 里查 nearlink/onehop 模块）")
    else:
        ev.append("OHOS_SDK_HOME 未设置或不存在：无法在 d.ts 里核对候选模块名")
    ev.append(f"hdc 可用: {have_hdc()}；targets: {hdc_targets() or '（空）'}")
    return UNVERIFIED, ev, "无 NFC 第二台设备且无 SDK：按 Q5 缺省走 ShareKit＋指引；API 命名待有设备时补"


def device_run():
    ev = []
    targets = hdc_targets()
    ev.append("targets=" + (", ".join(targets) if targets else "（空）"))
    model = hdc(["shell", "param", "get", "const.product.model"])
    ev.append("product.model=" + str(model.get("stdout", "")))
    nfc = hdc(["shell", "param", "get", "const.product.nfc"])
    ev.append("product.nfc=" + str(nfc.get("stdout", "")) + " stderr=" + str(nfc.get("stderr", "")))
    # 单机 API 调通需要测试构建页面；本脚本不内置被测页面
    return UNVERIFIED, ev, "需测试构建页面驱动候选 API；当前仅记录设备参数，不虚构调通"


if __name__ == "__main__":
    print_meta(META)
    sys.exit(run_probe(META, dry_run, device_run))