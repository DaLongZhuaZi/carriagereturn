#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""探针 6：验证能力（hdc 驱动 PanGesture／screenCap 连拍／时间类测试缝／ShareKit 完成回调）。

判定标准（总纲）：逐项给出“能／不能＋替代手段”。
失败处理：不能的项进豁免表；hdc 能驱动 PanGesture 时真实输入重放为主证据。
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import (ProbeMeta, UNVERIFIED, TABLET, grep_repo, have_hdc, hdc,
                    hdc_targets, print_meta, read_text, run_probe)

META = ProbeMeta(
    name="probe_verification_capabilities",
    device=f"{TABLET}",
    purpose="逐项判定自动化取证能力，决定每类证据走真实输入还是注入/豁免",
    pass_criterion="四项各给出“能／不能＋替代手段”，且能项有可复现命令",
    fallback="不能的项进豁免表（写明识别层未验证）；不许把不能写成能",
    alternative="仓库既有真机记录（§19.3 uitest drag 触发 lever pan）＋AGENTS 屏幕采样实测（400–500ms）",
    steps=[
        "uitest uiInput drag 驱动总成层 PanGesture，hilog 断言 lever pan start/update/end",
        "screenCap 连拍测单帧耗时，判断能否抓 350ms 动画中间态",
        "时间类：Date.now 注入点/纯函数单测覆盖情况",
        "ShareKit：ShareController.show 的 promise 是“面板显示”还是“分享完成”",
    ],
)


def dry_run():
    ev = []
    # 1) hdc 驱动 PanGesture：仓库既有真机记录
    log = read_text("docs/自检记录.md")
    has_drag_evidence = "uitest uiInput drag" in log and "lever pan" in log
    ev.append("hdc 驱动 PanGesture：仓库既有真机记录 " +
              ("已证（§19.3：uitest uiInput drag 触发 lever pan start/end pull=1.000）" if has_drag_evidence
               else "未见记录"))
    ev.append("本会话 hdc 可用=" + str(have_hdc()) + "；targets=" + str(hdc_targets() or "（空）") +
              "（本轮未复现，证据来自既有提交记录）")
    # 2) screenCap 单帧耗时
    ev.append("screenCap 连拍：AGENTS.md 实测单帧约 400–500ms，> 350ms 动画窗——"
              "“抓动画首帧”不可靠；替代：hilog 关键帧＋用户录屏")
    # 3) 时间类测试缝
    now_hits = grep_repo(r"Date\.now\(\)")
    seam_hits = grep_repo(r"nowMs|clock|Clock|DateProvider|tzOffset")
    ev.append(f"Date.now() 调用点 {len(now_hits)} 处；已有时间注入缝 {len(seam_hits)} 处")
    ev.append("替代：判定逻辑抽纯函数（StatsCore / LeverAngleCore）＋Node 单测，日期作参数传入")
    # 4) ShareKit 完成回调
    share = grep_repo(r"ShareController|controller\.show")
    ev.append("ShareKit 回调现状: " + "; ".join(
        f"{h['file']}:{h['line']}" for h in share[:4]) or "（无）")
    ev.append("结论：ShareController.show().then 只证“面板已调起”，证不了“对方已接收/完成分享”——"
              "分享完成不可观测，文案不得写“已分享成功”")
    return UNVERIFIED, ev, "四项中“能”的两项来自仓库既有真机记录；本轮无设备，未复现，不记 PASS"


def device_run():
    ev = []
    targets = hdc_targets()
    ev.append("targets=" + ", ".join(targets))
    # screenCap 单帧耗时（真机实测）
    import time
    t0 = time.time()
    shot = hdc(["shell", "screencap", "/data/local/tmp/probe_latency.jpeg"])
    dt = (time.time() - t0) * 1000
    ev.append(f"screencap 往返 {dt:.0f}ms（ok={shot.get('ok')}）")
    drag = hdc(["shell", "uitest", "uiInput", "drag", "1450", "1050", "1450", "1450"])
    ev.append("uitest drag 退出码=" + str(drag.get("code")) + " stderr=" + str(drag.get("stderr")))
    # 需要 App 前台与 hilog 断言才能判 PASS；脚本不伪造
    return UNVERIFIED, ev, "命令可执行但需 App 前台＋hilog 断言＋截图对比；本脚本只采能力证据"


if __name__ == "__main__":
    print_meta(META)
    sys.exit(run_probe(META, dry_run, device_run))