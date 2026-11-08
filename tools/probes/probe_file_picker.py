#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""探针 3：FilePicker 两路（选字体／选图片；系统选择器能否被 uitest 驱动；保存路径可见）。

判定标准（总纲）：两路可选、保存位置用户可见（图片走 MediaLibrary、PDF 走保存选择器）。
失败处理：改方案（第 2／3 批增量设计）。
"""
from __future__ import annotations

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import (ProbeMeta, UNVERIFIED, TABLET, PHONE, grep_repo, hdc, hdc_targets,
                    print_meta, run_probe)

META = ProbeMeta(
    name="probe_file_picker",
    device=f"{TABLET}／{PHONE}",
    purpose="确认 FilePicker 选字体／选图片两路可用、可被 uitest 驱动、保存位置用户可见",
    pass_criterion="DocumentViewPicker 选文件成功；PhotoViewPicker 选图成功；uitest 能驱动系统选择器；保存后用户可在文件管理器看到",
    fallback="改方案（第 2／3 批增量设计）：例如 PhotoViewPicker 不可驱动则改为应用内相册代理，并在报告中记缺口",
    alternative="系统选择器截图（打开前／后）＋返回 uri 的 hilog＋文件管理器截图；不可驱动时记录“需人工点一次”的豁免",
    steps=[
        "测试构建页面放两个按钮：选字体（DocumentViewPicker.select, fileSuffixFilters=[.ttf,.otf]）",
        "选图片（PhotoViewPicker.select, maxSelectNumber=1）",
        "保存（DocumentViewPicker.save → fs.openSync(uri) 写入）",
        "uitest uiInput click 每个按钮，截前后图；记录返回 uri 与文件大小",
    ],
)


def dry_run():
    ev = []
    hits = grep_repo(r"DocumentViewPicker|PhotoViewPicker|DocumentSelectOptions|DocumentSaveOptions")
    ev.append(f"仓库 FilePicker 引用 {len(hits)} 处（总纲：现状零处）")
    ev.append("FileHelper 现状: " + ("存在" if os.path.isfile(
        os.path.join(os.path.dirname(__file__), "..", "..",
                     "entry/src/main/ets/services/FileHelper.ets")) else "尚未创建"))
    media = grep_repo(r"MediaLibrary|photoAccessHelper")
    ev.append(f"媒体库/相册 API 引用 {len(media)} 处")
    ev.append("uitest 是否可驱动系统选择器：需真机；系统选择器是独立进程 UI，历史经验只能截图判存在")
    return UNVERIFIED, ev, "无设备：两路选择与保存可见性无法取证"


def device_run():
    ev = ["targets=" + ", ".join(hdc_targets())]
    helpout = hdc(["shell", "uitest", "uiInput", "help"])
    ev.append("uitest uiInput help 有输出: " + ("yes" if helpout.get("ok") else "no"))
    return UNVERIFIED, ev, "需测试构建页面与人工确认系统选择器；未虚构两路可选"


if __name__ == "__main__":
    print_meta(META)
    sys.exit(run_probe(META, dry_run, device_run))