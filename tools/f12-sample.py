#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""F12 换纸打点采样驱动 v2（设备端节拍，减少主机往返延迟）。
用法: python tools/f12-sample.py            # 跑完整 15 次采样
      python tools/f12-sample.py one <kind> <label>
kind: manual-empty | manual-15 | auto-empty | auto-15
"""
import subprocess, sys, time, re, os

HDC = r"G:\DevEco Studio 26\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
H = [HDC, "-t", "192.168.5.133:42355"]
A = "181 1980"
PAPER = "931 2432"
NL = "668 2432"


def sh(cmd, timeout=120):
    return subprocess.run(H + ["shell", cmd], capture_output=True, text=True, timeout=timeout).stdout


def click(xy):
    sh("uitest uiInput click " + xy)


def last_rows():
    out = sh("hilog -x | grep -a 'newlineDone' | tail -1")
    mm = re.search(r"rows=(\d+)", out)
    return int(mm.group(1)) if mm else 0


def fill(target=13, with_text=False):
    """自适应补齐到 target 行：每按一次换行都回读 rows，直到达标（防 busy 丢击）。"""
    if with_text:
        click(A)
        time.sleep(0.4)
    rows = last_rows()
    guard = 0
    while rows < target and guard < 40:
        click(NL)
        time.sleep(0.95)
        rows = last_rows()
        guard += 1


def sample(kind, label):
    with_text = kind.endswith("-15")
    # 先手动换一次纸把文档清回 1 行（保证起点一致），随后清日志，不把这次复位记进样本
    sh("uitest uiInput click " + PAPER + "; sleep 1.6")
    sh("hilog -r")
    if kind != "manual-empty":
        fill(13, with_text)
    trig = PAPER if kind.startswith("manual") else NL
    # 触发后 0.7s 按第一键（模拟操作员换纸完成立刻打）
    sh("uitest uiInput click %s; sleep 0.45; uitest uiInput click %s" % (trig, A))
    time.sleep(1.2)
    raw = sh("hilog -x | grep -a 'paperChange trace'")
    # 只保留最后一段（本次换纸，从最后一个 stage=start 起）
    lines = raw.strip().splitlines()
    idx = max((i for i, l in enumerate(lines) if "stage=start" in l), default=0)
    block = "\n".join(lines[idx:])
    stages = {}
    for line in block.splitlines():
        m = re.search(r"stage=(\S+) dt=(\d+)", line)
        if m:
            stages[m.group(1)] = int(m.group(2))
        for k in ("clear", "sync", "total"):
            mm = re.search(k + r"=(\d+)", line)
            if mm:
                stages["work_" + k] = int(mm.group(1))
    entry = re.search(r"entry=(\S+)", block)
    lines_n = re.search(r"lines=(\d+)", block)
    return {"label": label, "kind": kind, "entry": entry.group(1) if entry else "?",
            "lines": int(lines_n.group(1)) if lines_n else -1,
            "stages": stages, "block": block}


def fmt(r):
    s = r["stages"]
    return ("%s %-13s entry=%-12s lines=%-3s start=%s step1=%s settled=%s work=%s(clear=%s sync=%s) "
            "hide=%s begin=%s end=%s resume=%s") % (
        r["label"], r["kind"], r["entry"], r["lines"], s.get("start", "-"), s.get("step1", "-"),
        s.get("step1-settled", "-"), s.get("step2-work", "-"), s.get("work_clear", "-"),
        s.get("work_sync", "-"), s.get("step2-hide", "-"), s.get("step2-begin", "-"),
        s.get("end", "-"), s.get("resume", "-"))


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "one":
        r = sample(sys.argv[2], sys.argv[3])
        print(fmt(r))
        print(r["block"])
        return
    plan = [("manual-empty", "R1-1"), ("manual-empty", "R1-2"), ("manual-15", "R1-3"),
            ("manual-15", "R1-4"), ("auto-empty", "R1-5"),
            ("manual-empty", "R2-1"), ("manual-15", "R2-2"), ("auto-empty", "R2-3"),
            ("auto-15", "R2-4"), ("auto-15", "R2-5"),
            ("manual-empty", "R3-1"), ("manual-15", "R3-2"), ("auto-empty", "R3-3"),
            ("auto-15", "R3-4"), ("auto-15", "R3-5")]
    out = []
    for kind, label in plan:
        r = sample(kind, label)
        out.append(fmt(r))
        print(out[-1], flush=True)
    os.makedirs("docs/evidence", exist_ok=True)
    with open("docs/evidence/f12-trace-raw.log", "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    print("saved docs/evidence/f12-trace-raw.log")


if __name__ == "__main__":
    main()
