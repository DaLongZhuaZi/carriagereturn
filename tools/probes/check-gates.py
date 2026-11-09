#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""探针门控检查：把第 0 批 §2 的文字规则 mechanize 成工具。

判定（总纲“探针门控”规则）：
  PASS → 开
  UNVERIFIED＋（已批缺省｜已登记的本批自定 fallback）→ 开（注记）
  FAIL＋（已批缺省｜已登记的本批自定 fallback）→ 开（注记，走 fallback）
  UNVERIFIED／FAIL 且无任何 fallback → 拦住
  ERROR（探针脚本崩溃／无输出／JSON 不可读）→ 拦住，须修探针重跑
  （门控比 runner 更严：runner 对 ERROR 退出 0。）

文件选择：只读 device 模式的最新结论（run_all.py --device 写
probe-results-<date>.json；--dry-run 写 probe-results-<date>-dryrun.json，
门控忽略后者）。无 device 文件 → 明确报错退出 1，绝不静默通过。
探针 JSON 一律保留不删；门控输出同时列当前结论与已 supersede 的旧文件。

用法：
  python tools/probes/check-gates.py                # 报告模式：评估全部
  python tools/probes/check-gates.py --for-batch 2  # 开工前模式：只查第 2 批
  python tools/probes/check-gates.py --self-test     # 内置 6 组夹具
  python tools/probes/check-gates.py --json <path>   # 另写机器可读 JSON
退出码：0=全部开；1=任一拦住，或无 device 结论，或总纲缺改写标记。
"""
from __future__ import annotations

import glob
import json
import os
import re
import sys
from datetime import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
EVIDENCE = os.path.join(REPO, "docs", "evidence")
TOTAL_DOC = os.path.join(REPO, "docs", "designs", "功能新增与体验优化总纲.md")
FALLBACKS_JSON = os.path.join(HERE, "fallbacks.json")
REWRITE_MARKER = "测试时钟不建"
DELIVERED = {0, 1, 2, 3, 4, 5, 6, 7}

CAP_NOTE = ("四项归属：hdc 驱动→豁免表 F9 行；screenCap 连拍→F14／F12／F4 行；"
            "时间类测试缝→时间类条件行；ShareKit 回调→碰一碰行")

# 探针 → 消费批 → 已批缺省（None＝无缺省，须靠本批自定 fallback 登记）。
GATES = {
    "probe_touch_share": {"batches": [3], "default": "Q5：ShareKit＋指引", "note": ""},
    "probe_register_font": {"batches": [2], "default": None, "note": ""},
    "probe_file_picker": {"batches": [2, 3], "default": None, "note": ""},
    "probe_fold_angle": {"batches": [5], "default": "Q3：模拟器验证＋真机延期", "note": ""},
    "probe_test_clock": {"batches": "all", "default": "G8 改写已执行（工具断言总纲含改写标记）",
                         "note": ""},
    "probe_verification_capabilities": {"batches": "all", "default": "豁免表",
                                        "note": CAP_NOTE},
}


class NoDeviceResults(Exception):
    """无 device 模式探针结论文件。"""


def load_fallbacks(path: str = FALLBACKS_JSON) -> list:
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        return data.get("entries", [])
    except (OSError, ValueError):
        return []


def _device_files(evidence_dir: str) -> list:
    """全部 device 模式结论文件，按（文件名日期，mtime）升序。"""
    out = []
    for path in glob.glob(os.path.join(evidence_dir, "probe-results-*.json")):
        if path.endswith("-dryrun.json"):
            continue
        m = re.search(r"probe-results-(\d{4}-\d{2}-\d{2})\.json$", path)
        if not m:
            continue
        try:
            with open(path, "r", encoding="utf-8") as fh:
                payload = json.load(fh)
        except (OSError, ValueError):
            continue
        if payload.get("mode") != "--device":
            continue
        out.append((m.group(1), os.path.getmtime(path), path, payload))
    out.sort(key=lambda t: (t[0], t[1]))
    return out


def select_device_file(evidence_dir: str = EVIDENCE):
    """取最新 device 结论；返回（路径，payload，旧文件列表）。无则抛错。"""
    files = _device_files(evidence_dir)
    if not files:
        raise NoDeviceResults(
            "无 device 模式探针结论：请桌面端用已恢复的 hdc／设备跑 "
            "`python tools/probes/run_all.py --device` 后再查门控；"
            "干跑（--dry-run）结论不计入，绝不静默通过。")
    *superseded, latest = files
    return latest[2], latest[3], [(os.path.basename(p), d, "device") for d, _, p, _ in superseded]


def _batches_of(spec) -> list:
    if spec == "all":
        return sorted(DELIVERED)
    return list(spec)


def evaluate(results: list, fallbacks: list, doc_text: str) -> list:
    """纯函数：探针结论 → 逐探针门控行。"""
    by_probe = {r.get("probe"): r.get("status", "MISSING") for r in results}
    rows = []
    for probe, spec in GATES.items():
        status = by_probe.get(probe, "MISSING")
        batches = _batches_of(spec["batches"])
        verdicts = {}
        notes = {}
        for batch in batches:
            fb = [e for e in fallbacks if e.get("probe") == probe and e.get("batch") == batch]
            has_fb = spec["default"] is not None or bool(fb)
            if probe == "probe_test_clock" and REWRITE_MARKER not in doc_text:
                verdicts[batch] = "拦住"
                notes[batch] = "G8 改写标记缺失（总纲无“测试时钟不建”）"
            elif status == "PASS":
                verdicts[batch] = "开"
                notes[batch] = "PASS"
            elif status == "ERROR" or status == "MISSING":
                verdicts[batch] = "拦住"
                notes[batch] = ("探针脚本崩溃／无输出" if status == "ERROR"
                                else "结论缺失（JSON 里无此探针）") + "，须修探针重跑"
            elif (status.startswith("UNVERIFIED") or status == "FAIL") and has_fb:
                verdicts[batch] = "开（注记）"
                notes[batch] = (spec["default"] or f"本批自定 fallback（{fb[0].get('source', '')}）")
            elif status.startswith("UNVERIFIED") or status == "FAIL":
                verdicts[batch] = "拦住"
                notes[batch] = f"{status} 且无缺省／登记 fallback"
            else:
                verdicts[batch] = "拦住"
                notes[batch] = f"未知状态 {status}"
        blocked = [b for b, v in verdicts.items() if v == "拦住"]
        rows.append({
            "probe": probe,
            "status": status,
            "batches": batches,
            "verdict": "拦住" if blocked else ("开（注记）" if any(
                v == "开（注记）" for v in verdicts.values()) else "开"),
            "blocked_batches": blocked,
            "notes": notes,
            "gate_note": spec["note"],
        })
    return rows


def _fmt_batches(batches: list) -> str:
    if batches == sorted(DELIVERED):
        return "全部（0–7）"
    return "、".join(f"第{b}批" for b in batches)


def render(rows: list, device_file: str, superseded: list, for_batch=None) -> list:
    lines = [f"门控结论文件：{os.path.basename(device_file) if device_file else '（无）'}"]
    if for_batch is not None:
        lines.append(f"模式：开工前检查（第 {for_batch} 批）")
    else:
        lines.append("模式：报告（全部）")
    lines.append("")
    lines.append("| 探针 | 状态 | 消费批 | 结论 | 备注 |")
    lines.append("|---|---|---|---|---|")
    for r in rows:
        batches = [b for b in r["batches"] if for_batch is None or b == for_batch]
        if not batches:
            continue
        note = "; ".join(f"第{b}批：{r['notes'][b]}" for b in batches)
        if r["gate_note"]:
            note += f"（{r['gate_note']}）"
        lines.append(f"| `{r['probe']}` | {r['status']} | {_fmt_batches(batches)} | "
                     f"**{r['verdict']}** | {note} |")
    lines.append("")
    if superseded:
        lines.append("已 supersede 的旧结论文件（保留不删；历史结论见各批批报告与 docs/evidence/探针结论.md）：")
        for name, date, mode in superseded:
            lines.append(f"- {name}（{date}，{mode}）")
    else:
        lines.append("已 supersede 的旧结论文件：无")
    return lines


def _self_test() -> int:
    """内置 6 组夹具；失败即退出 1 并打印期望与实际。"""
    fails = []

    def check(name, cond, detail=""):
        print(("PASS " if cond else "FAIL ") + name + (f" —— {detail}" if detail and not cond else ""))
        if not cond:
            fails.append(name)

    fallbacks = load_fallbacks()
    doc_ok = "……测试时钟不建……"

    def results_for(status_map):
        return [{"probe": p, "status": s} for p, s in status_map.items()]

    all_probes = list(GATES)
    # ① 当前 2026-11-09 干跑数据＋已登记 fallback → 全部开（注记）
    r1 = evaluate(results_for({p: "UNVERIFIED_NO_DEVICE" for p in all_probes}),
                  fallbacks, doc_ok)
    check("① 干跑数据＋已登记 fallback：全部开（注记）",
          all(r["verdict"] in ("开", "开（注记）") for r in r1),
          str([(r["probe"], r["verdict"]) for r in r1 if r["verdict"] == "拦住"]))
    # ② 全 PASS → 全部开
    r2 = evaluate(results_for({p: "PASS" for p in all_probes}), fallbacks, doc_ok)
    check("② 全 PASS：全部开", all(r["verdict"] == "开" for r in r2))
    # ③ 仅有缺省的 UNVERIFIED → 全部开（注记）
    r3 = evaluate(results_for({p: "UNVERIFIED" for p in all_probes}), [], doc_ok)
    check("③ 无登记 fallback 时有缺省的探针开、无缺省的拦住",
          all((r["verdict"] == "拦住") == (r["probe"] in ("probe_register_font", "probe_file_picker"))
              for r in r3),
          str([(r["probe"], r["verdict"]) for r in r3]))
    # ④ 去掉 fallback 登记 → 拦住（分两步：先只去第 2 批登记，验按批粒度；
    #   再全去，验 file_picker 第 2／3 批都拦住）
    fb4a = [e for e in fallbacks if e["batch"] != 2]
    r4a = evaluate(results_for({p: "UNVERIFIED" for p in all_probes}), fb4a, doc_ok)
    by_probe4a = {r["probe"]: r for r in r4a}
    check("④a 只去第 2 批登记：第 2 批拦住（registerFont、file_picker），第 3 批仍开（自有登记）",
          by_probe4a["probe_register_font"]["blocked_batches"] == [2]
          and by_probe4a["probe_file_picker"]["blocked_batches"] == [2],
          str({p: r["blocked_batches"] for p, r in by_probe4a.items() if r["blocked_batches"]}))
    fb4b = [e for e in fallbacks if e["probe"] not in ("probe_register_font", "probe_file_picker")]
    r4b = evaluate(results_for({p: "UNVERIFIED" for p in all_probes}), fb4b, doc_ok)
    by_probe4b = {r["probe"]: r for r in r4b}
    check("④b 全去两探针登记：第 2 批拦住、第 3 批拦住（file_picker）",
          by_probe4b["probe_register_font"]["blocked_batches"] == [2]
          and by_probe4b["probe_file_picker"]["blocked_batches"] == [2, 3],
          str({p: r["blocked_batches"] for p, r in by_probe4b.items() if r["blocked_batches"]}))
    # ⑤ device 重跑后又跑一次 dry-run（同日）→ 门控仍读 device 文件
    import tempfile
    tmp = tempfile.mkdtemp(prefix="gates-")
    dev = {"date": "2026-11-09", "mode": "--device",
           "results": results_for({p: "PASS" for p in all_probes})}
    dry = {"date": "2026-11-09", "mode": "--dry-run",
           "results": results_for({p: "UNVERIFIED_NO_DEVICE" for p in all_probes})}
    with open(os.path.join(tmp, "probe-results-2026-11-09.json"), "w", encoding="utf-8") as fh:
        json.dump(dev, fh, ensure_ascii=False)
    with open(os.path.join(tmp, "probe-results-2026-11-09-dryrun.json"), "w", encoding="utf-8") as fh:
        json.dump(dry, fh, ensure_ascii=False)
    try:
        path, payload, _sup = select_device_file(tmp)
        check("⑤ 同日 dry-run 后仍读 device 文件",
              os.path.basename(path) == "probe-results-2026-11-09.json"
              and payload.get("mode") == "--device", path)
    except NoDeviceResults as exc:
        check("⑤ 同日 dry-run 后仍读 device 文件", False, str(exc))
    # ⑥ 总纲缺改写标记 → test_clock 拦住
    r6 = evaluate(results_for({p: "UNVERIFIED" for p in all_probes}), fallbacks, "无标记的文档")
    by_probe6 = {r["probe"]: r for r in r6}
    check("⑥ 总纲缺“测试时钟不建”标记：test_clock 拦住",
          by_probe6["probe_test_clock"]["verdict"] == "拦住",
          str(by_probe6["probe_test_clock"]["verdict"]))
    total = 7  # ①②③④a④b⑤⑥
    print(f"self-test：{total - len(fails)}/{total} 通过" if not fails else f"self-test：{len(fails)} 组失败")
    return 1 if fails else 0


def main(argv) -> int:
    args = list(argv)
    if "--self-test" in args:
        return _self_test()
    for_batch = None
    if "--for-batch" in args:
        try:
            for_batch = int(args[args.index("--for-batch") + 1])
        except (ValueError, IndexError):
            print("--for-batch 后须跟批号")
            return 2
    json_out = args[args.index("--json") + 1] if "--json" in args else None
    fallbacks = load_fallbacks()
    try:
        doc_text = open(TOTAL_DOC, "r", encoding="utf-8").read()
    except OSError:
        doc_text = ""
    try:
        device_file, payload, superseded = select_device_file()
    except NoDeviceResults as exc:
        print(f"门控无法判定：{exc}")
        return 1
    rows = evaluate(payload.get("results", []), fallbacks, doc_text)
    lines = render(rows, device_file, superseded, for_batch)
    text = "\n".join(lines)
    print(text)
    blocked = [r for r in rows if r["blocked_batches"]
               and (for_batch is None or for_batch in r["blocked_batches"])]
    verdict = "FAIL" if blocked else "PASS"
    if json_out:
        with open(json_out, "w", encoding="utf-8") as fh:
            json.dump({"generatedAt": datetime.now().astimezone().isoformat(timespec="seconds"),
                       "device_file": os.path.basename(device_file),
                       "for_batch": for_batch, "rows": rows, "verdict": verdict},
                      fh, ensure_ascii=False, indent=2)
    if blocked:
        print("FAIL：" + "、".join(f"{r['probe']}（拦住：{r['blocked_batches']}）" for r in blocked))
        return 1
    print("门控全部开")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
