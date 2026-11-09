#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""回车 · 每机音效包生成（第 4 批 F8，Q6 缺省替代方案）——已退役。

已退役：DSP 包已由 Freesound 实录替换（2026-11-09，见 tools/cut-sound-packs.py），
本脚本仅供复现旧包（git 历史 8effa32 时的三包 DSP 变体）。

Q6 缺省是 Freesound 采制；本机无网络，改为**仓库既有 23 个 OGG 的确定性 DSP 变体**：
  pack      → 1920s 基线（不动）
  pack-1930 → 音高 +15%、高频 -2dB、时长保持（asetrate + atempo）
  pack-1950 → 音高 -15%、高频 +2dB、时长保持
  pack-1960 → 音高 +20%、高频 +6dB、时长保持
（注：头注释旧写 +3%/−3%/+5% 已过期，实为 ±15%/+20%，2026-11-09 退役时修正。）
每包写 SOURCE.txt：生成参数、日期、逐文件 SHA-256。脚本可重复执行（输出确定）。

用法：python tools/make-sound-packs.py [--force]
"""
from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import subprocess
import sys
from datetime import datetime

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SOUND = os.path.join(ROOT, "entry/src/main/resources/rawfile/sound")
SRC_PACK = os.path.join(SOUND, "pack")

PACKS = {
    "pack-1930": {"pitch": 1.15, "treble": -2.0, "label": "1930s portable（DSP: pitch +15%, treble -2dB）"},
    "pack-1950": {"pitch": 0.85, "treble": 2.0, "label": "1950s streamlined（DSP: pitch -15%, treble +2dB）"},
    "pack-1960": {"pitch": 1.20, "treble": 6.0, "label": "1960s electric（DSP: pitch +20%, treble +6dB）"},
}


def ffmpeg() -> str:
    exe = shutil.which("ffmpeg")
    if not exe:
        raise RuntimeError("ffmpeg not found")
    return exe


def convert(src: str, dst: str, pitch: float, treble: float) -> None:
    # asetrate 会同时改变时长；用 atempo=1/pitch 抵消，保持时长不变
    chain = f"volume=0.72,asetrate=44100*{pitch:.6f},aresample=44100,atempo={1.0/pitch:.6f}"
    if abs(treble) > 0.01:
        chain += f",treble=g={treble:.1f}"
    # 防削波：1960 的高频提升会把 key-alt 推到 1.0
    chain += ",alimiter=limit=0.95"
    cmd = [ffmpeg(), "-y", "-v", "error", "-i", src, "-af", chain,
           "-c:a", "libvorbis", "-q:a", "4", dst]
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if p.returncode != 0:
        raise RuntimeError(f"ffmpeg failed {os.path.basename(src)}: {p.stderr[:300]}")


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    if not os.path.isdir(SRC_PACK):
        print("缺基线包 sound/pack", file=sys.stderr)
        return 2
    # 排除 pack2-*（第二台机测试变体，不是独立包）；每包保留无前缀 19 个音
    files = sorted(f for f in os.listdir(SRC_PACK)
                   if f.lower().endswith('.ogg') and not f.startswith('pack2-'))
    if not files:
        print("基线包没有 .ogg", file=sys.stderr)
        return 2
    ver = subprocess.run([ffmpeg(), "-version"], capture_output=True, text=True).stdout.splitlines()
    ffmpeg_line = ver[0] if ver else "ffmpeg (unknown)"
    for pack, cfg in PACKS.items():
        out_dir = os.path.join(SOUND, pack)
        if os.path.isdir(out_dir) and not args.force:
            print(f"{pack}: 已存在（--force 重生成）")
            continue
        os.makedirs(out_dir, exist_ok=True)
        # 清掉旧的（可能含 pack2-*）以保持每包文件集一致
        for old in os.listdir(out_dir):
            if old.lower().endswith('.ogg'):
                os.remove(os.path.join(out_dir, old))
        for fn in files:
            convert(os.path.join(SRC_PACK, fn), os.path.join(out_dir, fn),
                    cfg["pitch"], cfg["treble"])
        lines = [
            f"# {pack} · 回车每机音效包",
            f"# 上游来源：sound/pack/SOURCE.txt（BigSoundBank CC0；Freesound CC0/CC BY）",
            f"# CC BY 署名：ddohler（Typewriter.wav, https://freesound.org/s/9098/）、",
            f"#              YleArkisto（Kirjoituskone, https://freesound.org/people/YleArkisto/sounds/271525/）",
            f"# 来源：sound/pack 19 个 .ogg 的确定性 DSP 变体（Q6 代决备选 B；非 Freesound 重新采制）",
            f"# 参数：pitch={cfg['pitch']:.2f} treble={cfg['treble']:.1f}dB 时长保持（atempo 补偿）",
            f"# 生成日期：{datetime.now().astimezone().strftime('%Y-%m-%d')}",
            f"# 生成器：tools/make-sound-packs.py（可复现）",
            f"# ffmpeg：{ffmpeg_line}",
            f"# 说明：{cfg['label']}",
            "",
            "SHA-256:",
        ]
        for fn in files:
            lines.append(f"{sha256(os.path.join(out_dir, fn))}  {fn}")
        with open(os.path.join(out_dir, "SOURCE.txt"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(lines) + "\n")
        print(f"{pack}: {len(files)} files + SOURCE.txt")
    return 0


if __name__ == "__main__":
    sys.exit(main())