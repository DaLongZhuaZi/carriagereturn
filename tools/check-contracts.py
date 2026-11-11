#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第 0 批共享契约静态断言（A1／A2／A5／A6 的证据）。

检查：
  1) 契约文件存在；
  2) 关键导出符号存在（按正则）；
  3) prefs 命名空间与登记表存在，新键 builder 存在；
  4) Index 不再直接 import systemShare，分享走 ShareService；
  5) 字体注册循环在 FontService，Index 调 registerBundled；
  6) DocStore 有 trash/restore/rename/search/listTrashed；第 6 批起 remove() 已翻转为移入回收站；
  7) SpotlightOverlay／SpotlightStep 契约存在；GuideOverlay 只保留启动引导用的 GuideStep（无锚）。

退出码：0=全过；1=有失败。
"""
from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

CHECKS = [
    ("entry/src/main/ets/services/StatsService.ets", [
        r"export class StatsService", r"totalWords\(\): number", r"consecutiveDays\(\): number",
        r"todayChars\(\): number", r"dailyGoal\(\): number", r"recordEvent\(",
        r"export class StatsEvents", r"doc_saved", r"fold_typed",
    ]),
    ("entry/src/main/ets/model/StatsCore.ets", [
        r"export function dayKey", r"export function consecutiveDays", r"export function sumCounts",
        r"export function progressRatio",
    ]),
    ("entry/src/main/ets/services/FileHelper.ets", [
        r"export interface PickedFile", r"static async pickFont", r"static async pickImage",
        r"static async saveBytes", r"copyToSandbox",
    ]),
    ("entry/src/main/ets/services/ShareService.ets", [
        r"export interface ShareResult", r"static shareFile", r"ShareController",
    ]),
    ("entry/src/main/ets/services/FontService.ets", [
        r"export interface FontRegisterResult", r"static registerBundled", r"registerFromFile",
    ]),
    ("entry/src/main/ets/services/TestHooks.ets", [
        r"TEST_HOOKS_BUILD", r"static enabled", r"static audioTraceEnabled", r"static leverInjectEnabled",
    ]),
    ("entry/src/main/ets/services/AudioTrace.ets", [
        r"export interface AudioEmitTrace", r"static onEmit", r"static emitTrace",
    ]),
    ("entry/src/main/ets/components/SettingsRow.ets", [
        r"export struct SettingsRow", r"@Prop label", r"@Prop mode", r"onToggle", r"onSlide",
    ]),
    ("entry/src/main/ets/components/SpotlightOverlay.ets", [
        r"export interface SpotlightStep", r"export struct SpotlightOverlay",
    ]),
    ("entry/src/main/ets/components/GuideOverlay.ets", [
        r"export interface GuideStep", r"export struct GuideOverlay",
        r"@Prop visible", r"@Prop title: ResourceStr", r"text: ResourceStr",
        r"guide_btn_skip", r"guide_btn_ok", r"onNext", r"onSkip", r"onClose",
    ]),
    ("entry/src/main/ets/model/DocStoreStateCore.ets", [
        r"export interface DocIndexRecord", r"export function trashRecord", r"export function restoreRecord",
        r"export function renameRecord", r"export function searchRecords", r"export function trashedRecords",
    ]),
    ("entry/src/main/ets/model/LeverAngleCore.ets", [
        r"LEVER_REST_DEG_TABLET", r"LEVER_SWING_DEG_TABLET", r"export function angleFor",
        r"export function dragRatioFor", r"export function pulledEnough", r"export function restDegFor",
    ]),
    ("entry/src/main/ets/services/AppPreferences.ets", [
        r"GUIDE_PREFIX", r"CUSTOM_FONT_PREFIX", r"CUSTOM_PAPER_PREFIX", r"STATS_EVENT_PREFIX",
        r"ACHIEVE_PREFIX", r"static guideSeen", r"static customFont", r"static statsEvent",
        r"export class PrefRegistry", r"static isRegistered",
    ]),
    ("entry/src/main/ets/services/DocStore.ets", [
        r"export interface DocIndexEntry", r"trash\(id: string, nowMs: number\): boolean",
        r"restore\(id: string\): boolean", r"rename\(id: string, title: string\): boolean",
        r"search\(query: string, opts: DocSearchOptions\): DocSearchHit\[\]",
        r"listTrashed\(\): DocSummary\[\]",
    ]),
]

FAILS = []
PASSES = []


def read(rel: str) -> str:
    path = os.path.join(ROOT, rel)
    if not os.path.isfile(path):
        return ""
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return fh.read()


def main() -> int:
    for rel, patterns in CHECKS:
        text = read(rel)
        if not text:
            FAILS.append(f"缺文件: {rel}")
            continue
        missing = [p for p in patterns if not re.search(p, text)]
        if missing:
            FAILS.append(f"{rel} 缺符号: {', '.join(missing)}")
        else:
            PASSES.append(f"{rel}: {len(patterns)} 项")

    index = read("entry/src/main/ets/pages/Index.ets")
    if re.search(r"systemShare\s*\.", index) or "from '@kit.ShareKit'" in index:
        FAILS.append("Index.ets 仍直接使用 systemShare（分享未唯一入口化）")
    elif "ShareService.shareFile" not in index:
        FAILS.append("Index.ets 未调用 ShareService.shareFile")
    else:
        PASSES.append("Index.ets: 分享走 ShareService")

    if "FontService.registerBundled" not in index:
        FAILS.append("Index.ets 未调用 FontService.registerBundled")
    else:
        PASSES.append("Index.ets: 字体注册走 FontService")

    docstore = read("entry/src/main/ets/services/DocStore.ets")
    # 第 6 批起 remove()＝trash（语义已翻转）；removePermanently 才是硬删
    m = re.search(r"remove\(id: string\): boolean \{(.*?)\n  \}", docstore, re.S)
    if not m:
        FAILS.append("DocStore.remove() 未找到")
    elif "this.trash(" not in m.group(1) or "unlinkIfPresent" in m.group(1):
        FAILS.append("DocStore.remove() 未按第 6 批翻转为 trash")
    else:
        PASSES.append("DocStore.remove(): 已翻转为 trash（第 6 批）")
    if "removePermanently(id: string): boolean" not in docstore:
        FAILS.append("DocStore.removePermanently() 未找到")

    print("== 共享契约静态断言 ==")
    for p in PASSES:
        print("  PASS " + p)
    for f in FAILS:
        print("  FAIL " + f)
    print(f"结论: {'PASS' if not FAILS else 'FAIL'}（{len(PASSES)} 过 / {len(FAILS)} 败）")
    return 0 if not FAILS else 1


if __name__ == "__main__":
    sys.exit(main())