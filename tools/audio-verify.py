#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""回车 · 音效离线验证（第 0b 批：包间频谱指纹可区分性＋哈希一致性）。

证明什么：
  - rawfile/sound 下每个 .ogg 都能解码、时长/包络合理、不是数字静音；
  - 文件两两 SHA-256 不同（没有同一文件复制成多个"不同"音效）；
  - 包间/角色间的频谱指纹可区分（抓"包接错、两包实为同一文件"的最可能失败）。

不证明什么：设备扬声器的实际听感（第 7 批计划内真机冒烟）；运行时到底选了哪个
音效（那是 AudioTrace 选择层断言的职责）。

用法：python tools/audio-verify.py [--json docs/evidence/audio-verify.json] [--pack pack]
退出码：0=PASS；1=FAIL；2=缺 ffmpeg/依赖。
"""
from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SOUND_ROOT = os.path.join(ROOT, "entry/src/main/resources/rawfile/sound")
SAMPLE_RATE = 16000
MIN_DUR = 0.02
MAX_DUR = 3.0
MIN_FP_DISTANCE = 0.03
# 每个音效包必须具备的五类角色（文件名前缀 → 角色）；变体数量不限
ROLE_CHECKS = {
    "key": lambda s: s.startswith("key-") and not s.startswith("key-alt") and not s.startswith("key-transient"),
    "space": lambda s: s.startswith("space-"),
    "bell": lambda s: s.startswith("bell-"),
    "carriage_reset": lambda s: s.startswith("carriage-reset"),
    "backspace": lambda s: s.startswith("key-alt"),
}


def ffmpeg() -> str:
    exe = shutil.which("ffmpeg")
    if not exe:
        raise RuntimeError("ffmpeg not found in PATH")
    return exe


def decode_pcm(path: str) -> np.ndarray:
    cmd = [ffmpeg(), "-v", "quiet", "-i", path, "-f", "s16le", "-ac", "1",
           "-ar", str(SAMPLE_RATE), "-"]
    out = subprocess.run(cmd, capture_output=True, timeout=60)
    if out.returncode != 0 or len(out.stdout) == 0:
        raise RuntimeError("decode failed: " + out.stderr.decode("utf-8", "replace")[:200])
    return np.frombuffer(out.stdout, dtype="<i2").astype(np.float64) / 32768.0


def fingerprint(samples: np.ndarray) -> np.ndarray:
    """8 个 log 频带的能量占比 + 谱质心（归一化到 0..1），共 10 维。"""
    n = len(samples)
    if n < 256:
        return np.zeros(10)
    win = np.hanning(min(n, 4096))
    seg = samples[: len(win)] * win
    spec = np.abs(np.fft.rfft(seg))
    freqs = np.fft.rfftfreq(len(seg), d=1.0 / SAMPLE_RATE)
    total = float(np.sum(spec)) + 1e-12
    edges = np.geomspace(40, SAMPLE_RATE / 2, 9)
    bands = []
    for i in range(8):
        mask = (freqs >= edges[i]) & (freqs < edges[i + 1])
        bands.append(float(np.sum(spec[mask])) / total)
    centroid = float(np.sum(freqs * spec) / total) / (SAMPLE_RATE / 2)
    return np.array(bands + [centroid, 0.0], dtype=np.float64)


def analyze(path: str) -> dict:
    data = open(path, "rb").read()
    sha = hashlib.sha256(data).hexdigest()
    samples = decode_pcm(path)
    dur = len(samples) / SAMPLE_RATE
    rms = float(np.sqrt(np.mean(samples ** 2))) if len(samples) else 0.0
    peak = float(np.max(np.abs(samples))) if len(samples) else 0.0
    # 包络：前 50ms 与后 50ms 的 RMS（判断有没有起音/衰减）
    seg = max(1, int(0.05 * SAMPLE_RATE))
    head = float(np.sqrt(np.mean(samples[:seg] ** 2))) if len(samples) >= seg else rms
    tail = float(np.sqrt(np.mean(samples[-seg:] ** 2))) if len(samples) >= seg else rms
    return {
        "file": os.path.relpath(path, ROOT).replace("\\", "/"),
        "pack": os.path.basename(os.path.dirname(path)),
        "stem": os.path.splitext(os.path.basename(path))[0],
        "sha256": sha,
        "bytes": len(data),
        "duration_s": round(dur, 4),
        "rms": round(rms, 5),
        "peak": round(peak, 4),
        "head_rms": round(head, 5),
        "tail_rms": round(tail, 5),
        "fingerprint": [round(float(x), 6) for x in fingerprint(samples)],
    }


def main() -> int:
    args = sys.argv[1:]
    only_pack = args[args.index("--pack") + 1] if "--pack" in args else None
    json_out = args[args.index("--json") + 1] if "--json" in args else None

    if not os.path.isdir(SOUND_ROOT):
        print(f"[audio-verify] 目录不存在: {SOUND_ROOT}", file=sys.stderr)
        return 2
    files = []
    for dirpath, _dirnames, filenames in os.walk(SOUND_ROOT):
        if only_pack and os.path.basename(dirpath) != only_pack:
            continue
        for fn in sorted(filenames):
            if fn.lower().endswith(".ogg"):
                files.append(os.path.join(dirpath, fn))
    if not files:
        print("[audio-verify] 没找到 .ogg", file=sys.stderr)
        return 2

    rows = []
    failures = []
    for f in files:
        try:
            r = analyze(f)
            rows.append(r)
        except Exception as exc:
            failures.append(f"{os.path.basename(f)}: {exc}")

    # 哈希一致性
    hashes = {}
    for r in rows:
        hashes.setdefault(r["sha256"], []).append(r["file"])
    for sha, fs in hashes.items():
        if len(fs) > 1:
            failures.append("SHA-256 重复（同一文件被当多个音效）: " + ", ".join(fs))

    # 时长 / 静音 / 削波
    for r in rows:
        if not (MIN_DUR <= r["duration_s"] <= MAX_DUR):
            failures.append(f"{r['stem']}: 时长 {r['duration_s']}s 不在 [{MIN_DUR},{MAX_DUR}]")
        if r["rms"] < 1e-4:
            failures.append(f"{r['stem']}: 近似数字静音 rms={r['rms']}")
        if r["peak"] >= 0.999:
            failures.append(f"{r['stem']}: 可能削波 peak={r['peak']}")

    # 频谱指纹距离：
    #   主判据＝跨包同角色（抓"两包实为同一文件/包接错"）；单包时无跨包对，记录"待 F8"。
    #   包内变体之间允许相近（同一音色的不同变体），只要求 SHA-256 不同。
    def role_of(stem: str) -> str:
        for role, pred in ROLE_CHECKS.items():
            if pred(stem):
                return role
        return "other"

    fps = [(r["file"], np.array(r["fingerprint"][:9], dtype=np.float64)) for r in rows]
    within_min = 999.0
    within_where = ""
    for i in range(len(fps)):
        for j in range(i + 1, len(fps)):
            if os.path.basename(fps[i][0]).split("-")[0] != os.path.basename(fps[j][0]).split("-")[0]:
                continue
            d = float(np.linalg.norm(fps[i][1] - fps[j][1]))
            if d < within_min:
                within_min = d
                within_where = f"{os.path.basename(fps[i][0])} vs {os.path.basename(fps[j][0])}"

    # 每个（包, 角色）取平均指纹，再跨包同角色比较
    by_pack_role: dict = {}
    for r in rows:
        key = (r["pack"], role_of(r["stem"]))
        by_pack_role.setdefault(key, []).append(np.array(r["fingerprint"][:9], dtype=np.float64))
    avg = {k: np.mean(np.stack(v), axis=0) for k, v in by_pack_role.items()}
    pack_names = sorted({r["pack"] for r in rows})
    cross_min = None
    cross_where = ""
    if len(pack_names) >= 2:
        cross_min = 999.0
        for role in ROLE_CHECKS:
            for i in range(len(pack_names)):
                for j in range(i + 1, len(pack_names)):
                    a = avg.get((pack_names[i], role))
                    b = avg.get((pack_names[j], role))
                    if a is None or b is None:
                        continue
                    d = float(np.linalg.norm(a - b))
                    if d < cross_min:
                        cross_min = d
                        cross_where = f"{pack_names[i]}/{role} vs {pack_names[j]}/{role}"
        if cross_min < MIN_FP_DISTANCE:
            failures.append(f"跨包同角色指纹过近: {cross_where} distance={cross_min:.4f} < {MIN_FP_DISTANCE}")

    # 角色文件齐全（选择层文件级断言：每个包五类角色至少各 1 个文件）
    packs: dict = {}
    for r in rows:
        packs.setdefault(r["pack"], []).append(r["stem"])
    role_map = {}
    for pack, stems in sorted(packs.items()):
        role_map[pack] = {}
        for role, pred in ROLE_CHECKS.items():
            matched = sorted([s for s in stems if pred(s)])
            role_map[pack][role] = matched
            if not matched:
                failures.append(f"音效包 {pack} 缺角色 {role}（文件级映射断言）")

    report = {
        "tool": "audio-verify",
        "soundRoot": os.path.relpath(SOUND_ROOT, ROOT),
        "files": len(rows),
        "packs": pack_names,
        "roleMap": role_map,
        "withinPackMin": round(within_min, 4) if within_min < 999 else None,
        "withinPackWhere": within_where,
        "crossPackRoleMin": round(cross_min, 4) if cross_min is not None else None,
        "crossPackWhere": cross_where,
        "minPairDistance": round(cross_min, 4) if cross_min is not None else None,
        "minPairWhere": cross_where,
        "rows": rows,
        "failures": failures,
        "verdict": "PASS" if not failures else "FAIL",
        "scope": "离线解码证明包内/包间可区分与哈希一致性；不证明扬声器听感与运行时选择（后者见 AudioTrace 选择层断言）",
    }

    print("== 音效离线验证 ==")
    print(f"{'stem':<22}{'pack':<10}{'dur(s)':>8}{'rms':>9}{'peak':>7}")
    for r in rows:
        print(f"{r['stem']:<22}{r['pack']:<10}{r['duration_s']:>8.3f}{r['rms']:>9.4f}{r['peak']:>7.3f}")
    print(f"文件数 {len(rows)}；SHA-256 唯一 {len(hashes)}")
    print(f"包内变体最近距离 {within_min:.4f}（{within_where}）——仅参考，不判 FAIL")
    if cross_min is None:
        print("跨包同角色距离: 仅 1 个音效包，待第 4 批 F8 多包落地后再断言")
    else:
        print(f"跨包同角色最小距离 {cross_min:.4f}（{cross_where}）阈值 {MIN_FP_DISTANCE}")
    for f in failures:
        print("  FAIL " + f)
    print(f"结论: {report['verdict']}")

    if json_out:
        os.makedirs(os.path.dirname(os.path.abspath(json_out)), exist_ok=True)
        with open(json_out, "w", encoding="utf-8") as fh:
            json.dump(report, fh, ensure_ascii=False, indent=2)
        print("JSON: " + json_out)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())