#!/usr/bin/env python3
"""回车 CarriageReturn 音效包 v1 构建脚本（本地素材 → App 内 OGG 包）。

输入：assets/sounds/bigsoundbank/ 与 assets/sounds/freesound/ 的原始素材。
输出：assets/sounds/pack/（OGG Vorbis 单声道 44.1kHz，峰值归一化 -1dB）。
方法：能量包络检出单次按键（静音间隙 ≥60ms 后能量跃升），切变体并淡出；
单音文件只做首尾静音修剪 + 归一化。YleArkisto 的手动回车/卷纸段需人工听辨
时间戳，本轮不自动切，只保留 knufds 的铃+回车复位一体作回车声。
"""
import os
import subprocess
import sys
import wave

import numpy as np

ROOT = os.path.expanduser("~/workspace/carriagereturn/assets/sounds")
PACK = os.path.join(ROOT, "pack")
TMP = "/tmp/soundpack"
os.makedirs(PACK, exist_ok=True)
os.makedirs(TMP, exist_ok=True)


def to_mono16(src, dst, rate=44100):
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", src,
                    "-ac", "1", "-ar", str(rate), "-c:a", "pcm_s16le", dst],
                   check=True)


def load_wav(path):
    with wave.open(path) as w:
        n = w.getnframes()
        raw = w.readframes(n)
        sr = w.getframerate()
    return np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0, sr


def envelope(x, sr, win_ms=5):
    win = max(1, int(sr * win_ms / 1000))
    n = len(x) // win
    rms = np.sqrt(np.mean(x[: n * win].reshape(n, win) ** 2, axis=1))
    return rms, win


def find_presses(x, sr, tail_cap_ms=450, refractory_ms=80):
    """返回 [(start_sample, end_sample, peak)]，每段一次按键。

    打字床是连续击键，键与键之间静音间隙常不足 60ms，因此不用“静音间隙”
    判定，改用能量跃升检出 onset：窗口 RMS 超过峰值 15% 且 ≥ 前 30ms
    中位数的 2 倍；段尾取 min（onset+350ms，下一起点-15ms）。
    """
    rms, win = envelope(x, sr)
    peak_rms = rms.max()
    onsets = []
    last = -10 ** 9
    refractory = max(1, int(refractory_ms / 5))  # 不应期
    for i in range(1, len(rms)):
        if i - last < refractory:
            continue
        prev = np.median(rms[max(0, i - 6):i])
        if rms[i] > 0.15 * peak_rms and rms[i] > 2.0 * max(prev, 1e-6):
            onsets.append(i)
            last = i
    segs = []
    for n, oi in enumerate(onsets):
        start = max(0, (oi * win) - int(sr * 0.010))
        cap = oi + int(tail_cap_ms / 5)
        if n + 1 < len(onsets):
            cap = min(cap, onsets[n + 1] - int(0.015 * sr / win))
        end = min(len(x), (cap + 1) * win)
        if (end - start) >= int(sr * 100 / 1000):
            seg = x[start:end]
            segs.append((start, end, float(np.abs(seg).max())))
    return segs


def normalize(seg, target=0.841):  # -1.5dB：给 Vorbis 重建过冲留 headroom
    peak = np.abs(seg).max()
    if peak <= 0:
        return seg
    return seg * (target / peak)


def fade_out(seg, sr, ms=15):
    n = min(len(seg), int(sr * ms / 1000))
    if n > 0:
        seg = seg.copy()
        seg[-n:] *= np.linspace(1.0, 0.0, n)
    return seg


def write_wav(path, seg, sr):
    pcm = np.clip(seg, -1.0, 1.0)
    pcm = (pcm * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def to_ogg(wav_path, ogg_path):
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", wav_path,
                    "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "4",
                    ogg_path], check=True)


def cut_variants(src_wav, out_prefix, count, tail_cap_ms=450, refractory_ms=80):
    x, sr = load_wav(src_wav)
    segs = find_presses(x, sr, tail_cap_ms, refractory_ms)
    # 过滤弱按压，保留峰值 ≥ 全局峰值 25% 的段
    gpeak = max(s[2] for s in segs) if segs else 0
    segs = [s for s in segs if s[2] >= 0.25 * gpeak]
    if len(segs) < count:
        print(f"  警告：{src_wav} 仅检出 {len(segs)} 段，少于目标 {count} 段")
        count = len(segs)
    # 时间上均匀取段，保证不同按键音色
    idx = np.linspace(0, len(segs) - 1, count).round().astype(int)
    idx = sorted(set(idx.tolist()))
    made = []
    for n, si in enumerate(idx, 1):
        s, e, _ = segs[si]
        seg = fade_out(normalize(x[s:e]), sr)
        name = f"{out_prefix}-{n:02d}"
        wav = os.path.join(TMP, name + ".wav")
        ogg = os.path.join(PACK, name + ".ogg")
        write_wav(wav, seg, sr)
        to_ogg(wav, ogg)
        made.append((name, s / sr, (e - s) / sr, os.path.getsize(ogg)))
    return made


def trim_single(src, out_name, bell=False, extra_gain=1.0):
    """单音文件：首尾静音修剪 + 归一化 + OGG。

    按键类：尾阈 5%（100ms 持续）保留机械尾音与回弹 click（短于 100ms 的
    能量低谷不截断）；铃类：尾阈 3%（150ms 持续）保留可听衰减。
    """
    tmp = os.path.join(TMP, "single.wav")
    to_mono16(src, tmp)
    x, sr = load_wav(tmp)
    rms, win = envelope(x, sr)
    hi = rms.max() * 0.10
    above = np.where(rms > hi)[0]
    if len(above) == 0:
        print(f"  警告：{src} 未检出有效信号")
        return None
    s = max(0, above[0] * win - int(sr * 0.010))
    thr = rms.max() * (0.03 if bell else 0.05)
    run_needed = int(150 / 5) if bell else int(100 / 5)
    e_win = above[-1]
    run = 0
    for k in range(above[-1] + 1, len(rms)):
        if rms[k] < thr:
            run += 1
            if run >= run_needed:
                e_win = k - run
                break
        else:
            run = 0
            e_win = k
    e = min(len(x), (e_win + 1) * win + int(sr * 0.020))
    seg = fade_out(normalize(x[s:e]) * extra_gain, sr)
    wav = os.path.join(TMP, out_name + ".wav")
    ogg = os.path.join(PACK, out_name + ".ogg")
    write_wav(wav, seg, sr)
    to_ogg(wav, ogg)
    return (out_name, s / sr, (e - s) / sr, os.path.getsize(ogg))


def main():
    report = []
    # 1. 主床 → 12 按键变体
    bed16 = os.path.join(TMP, "bed16.wav")
    to_mono16(os.path.join(ROOT, "bigsoundbank/typewriter-bed-01.wav"), bed16)
    print("主床变体：")
    for row in cut_variants(bed16, "key", 12):
        print(f"  {row[0]}.ogg 源偏移 {row[1]:.2f}s 长 {row[2]:.3f}s {row[3]}B")
        report.append(row)
    # 2. 第二台机床 → 4 变体（回声较大，尾放宽到 600ms）
    lyr16 = os.path.join(TMP, "lyr16.wav")
    to_mono16(os.path.join(ROOT, "freesound/bed-second-lyricalgirl-788956.mp3"), lyr16)
    print("第二台机变体：")
    for row in cut_variants(lyr16, "pack2-key", 4, tail_cap_ms=600, refractory_ms=150):
        print(f"  {row[0]}.ogg 源偏移 {row[1]:.2f}s 长 {row[2]:.3f}s {row[3]}B")
        report.append(row)
    # 3. 单音
    singles = [
        (os.path.join(ROOT, "bigsoundbank/space-key-01.wav"), "space-01", False, 1.0),
        (os.path.join(ROOT, "freesound/bell-01-ramsamba-318687.wav"), "bell-01", True, 1.0),
        (os.path.join(ROOT, "bigsoundbank/margin-bell-01.wav"), "bell-02", True, 1.0),
        (os.path.join(ROOT, "freesound/bell-02-masternavigator-444813.wav"), "bell-03", True, 0.75),
        (os.path.join(ROOT, "freesound/bell-carriage-reset-knufds-345955.wav"), "carriage-reset-01", False, 1.0),
        (os.path.join(ROOT, "freesound/key-transient-bmaczero-160678.wav"), "key-transient", False, 1.0),
        (os.path.join(ROOT, "freesound/key-01-ddohler-9098.wav"), "key-alt-01", False, 1.0),
    ]
    print("单音：")
    for src, name, is_bell, gain in singles:
        row = trim_single(src, name, bell=is_bell, extra_gain=gain)
        if row:
            print(f"  {row[0]}.ogg 源偏移 {row[1]:.2f}s 长 {row[2]:.3f}s {row[3]}B")
            report.append(row)
    total = sum(os.path.getsize(os.path.join(PACK, f)) for f in os.listdir(PACK)
                if f.endswith(".ogg"))
    print(f"总计 {len(report)} 个文件，{total} 字节（预算 <2MB = 2097152B）")
    with open(os.path.join(PACK, "BUILD-REPORT.txt"), "w", encoding="utf-8") as f:
        f.write("回车音效包 v1 构建记录\n")
        for name, off, dur, size in report:
            f.write(f"{name}.ogg 源偏移 {off:.2f}s 长 {dur:.3f}s {size}B\n")
        f.write(f"总计 {len(report)} 个文件，{total} 字节\n")


if __name__ == "__main__":
    main()
