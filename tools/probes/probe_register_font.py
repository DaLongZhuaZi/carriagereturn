#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""探针 2：registerFont 私有路径（应用私有目录字体能否注册、冷启动是否保留、坏文件报错）。

判定标准（总纲）：注册成功且重启后仍有效；坏文件报错不崩、不污染已有字体。
失败处理：改方案（第 2 批增量设计）。
"""
from __future__ import annotations

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import (ProbeMeta, UNVERIFIED, TABLET, PHONE, grep_repo, hdc, hdc_targets,
                    print_meta, read_text, run_probe)

META = ProbeMeta(
    name="probe_register_font",
    device=f"{TABLET}／{PHONE}",
    purpose="确认运行时从应用私有目录注册 .ttf/.otf 的可行性（F3 字体导入的地基）",
    pass_criterion="私有目录字体注册成功；冷启动后 familyName 仍有效；坏文件报错不崩溃、不污染已注册字体",
    fallback="改方案（第 2 批增量设计）：例如导入后转 rawfile 不可行，则降级为“只管理不即时生效”并记录",
    alternative="启动注册循环现状（$rawfile）＋ UI 截图（17 款字体试写分不出差别＝失败）；坏文件路径用单测/静态守卫",
    steps=[
        "测试构建写入 /data/app/.../files/fonts/probe.ttf（一个正常字体）",
        "调用 UIContext.getFont().registerFont({familyName:'Probe', familySrc: 私有路径})",
        "hilog 断言 registerFont ok；切到该 family 打字并截图（前后各一张）",
        "重启 App 后再切该 family 打字并截图；再试一个截断的坏 ttf，断言报错且原有字体仍可用",
    ],
)


def count_fonts() -> int:
    text = read_text("entry/src/main/ets/model/MachineCatalog.ets")
    m = re.search(r"export const FONTS: FontSpec\[\] = \[(.*?)\];", text, re.S)
    if not m:
        return -1
    return len(re.findall(r"font:\s*PaperFont\.", m.group(1)))


def dry_run():
    ev = []
    reg = grep_repo(r"registerFont")
    ev.append(f"registerFont 调用点 {len(reg)} 处：" + "; ".join(
        f"{h['file']}:{h['line']}" for h in reg[:5]))
    raw = grep_repo(r"familySrc")
    ev.append("familySrc 现状: " + "; ".join(f"{h['file']}:{h['line']} {h['text']}" for h in raw[:3]))
    ev.append(f"MachineCatalog.FONTS 条数: {count_fonts()}")
    ev.append("私有路径注册: 仓库尚无实现（FontService.registerFromFile 为第 0 批签名占位，未接 UI）")
    ev.append("是否出现 file:// 或 filesDir 拼 fontSrc: " +
              str(bool(re.search(r"filesDir.*font|font.*filesDir", read_text("entry/src/main/ets/pages/Index.ets")))))
    return UNVERIFIED, ev, "判定标准需真机＋测试构建；本机无设备，静态部分已记录"


def device_run():
    ev = []
    ev.append("targets=" + ", ".join(hdc_targets()))
    # 私有目录路径无法在未装测试构建时验证；只做设备侧文件系统能力检查
    perm = hdc(["shell", "ls", "-l", "/data/app/el2/100/base"])
    ev.append("应用沙箱根可列: " + ("yes" if perm.get("ok") else "no（权限或路径不同）"))
    return UNVERIFIED, ev, "需测试构建与人工/uitest 驱动；未虚构注册成功"


if __name__ == "__main__":
    print_meta(META)
    sys.exit(run_probe(META, dry_run, device_run))