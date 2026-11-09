#!/usr/bin/env python3
"""F8 回 Freesound 采制 · 切包脚本（2026-11-09，draft v2）。

把用户下载的 Freesound 实录切成三包（pack-1930／pack-1950／pack-1960），每包 19 个 OGG，
角色结构与 AudioService.buildBanks 的消费一致。算法复用 v1 assets/sounds/build-pack.py
（能量包络 onset 检出／trim_single），参数化后按包出菜，不直接跑 build-pack.py
（它硬编码 v1 输入与输出 assets/sounds/pack/，直接跑会覆盖基线包）。

用户选型（2026-11-09，听感）：
  1930s：megashroom 最好（monotraum 太糊不用）；铃 fastson
  1950s：escritor1 最好（另两条太糊不用）；铃／换行 spring_tide
  1960s：三条都好（secretmojo 主床＋adamj 结构化＋magedu 回车）

不同场景（用户要求）：12 按键变体沿床全程均匀取段（快／慢段落都覆盖）；
空格取床内质心最低的强段（宽条空格键的闷响）；铃取床内行末大声事件（带衰减尾）；
回车复位取行末空隙的滑架声；1960s 退格单键取 adamj 的孤立单键段。

用法：
  python3 tools/cut-sound-packs.py --pack 1930   # 只切 1930s 包
  python3 tools/cut-sound-packs.py --pack all    # 三包全切
输出：entry/src/main/resources/rawfile/sound/pack-<1930|1950|1960>/ 下 19 个 .ogg
      ＋各包 SOURCE.txt（两半：原始素材记录＋逐文件切分映射）
      ＋各包 BUILD-REPORT.txt（切分报告）
任一角色断言失败即 exit 1（见 assert_*），由执行者按 draft v2 的 fallback 处理，
不得静默出包。
"""
import argparse
import hashlib
import os
import subprocess
import sys
import wave

import numpy as np

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FREESOUND = os.path.join(REPO, "assets", "sounds", "freesound")
SOUND = os.path.join(REPO, "entry", "src", "main", "resources", "rawfile", "sound")
TMP = "/tmp/f8-cut"

# ---------------------------------------------------------------- v1 算法（复用）
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
    """返回 [(start_sample, end_sample, peak)]，每段一次按键。v1 原样。"""
    rms, win = envelope(x, sr)
    peak_rms = rms.max()
    onsets = []
    last = -10 ** 9
    refractory = max(1, int(refractory_ms / 5))
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


def normalize(seg, target=0.841):  # -1.5dB
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


def to_mono16(src, dst):
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", src,
                    "-ac", "1", "-ar", "44100", "-c:a", "pcm_s16le", dst],
                   check=True)


def trim_single(src, out_name, out_dir, bell=False, extra_gain=1.0, tail_pct=None):
    """单音文件：首尾静音修剪 + 归一化 + OGG。v1 原样。
    tail_pct：尾阈（默认铃 3%／按键 5%）；fastson 铃衰减快，须用 1% 才留得住可听余音。"""
    tmp = os.path.join(TMP, "single.wav")
    to_mono16(src, tmp)
    x, sr = load_wav(tmp)
    rms, win = envelope(x, sr)
    hi = rms.max() * 0.10
    above = np.where(rms > hi)[0]
    if len(above) == 0:
        raise RuntimeError(f"{src} 未检出有效信号")
    s = max(0, above[0] * win - int(sr * 0.010))
    thr = rms.max() * (tail_pct if tail_pct is not None else (0.03 if bell else 0.05))
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
    ogg = os.path.join(out_dir, out_name + ".ogg")
    write_wav(wav, seg, sr)
    to_ogg(wav, ogg)
    return (out_name, s / sr, (e - s) / sr, os.path.getsize(ogg))


# ---------------------------------------------------------------- 本脚本新增
def hp_filter(x, sr, cutoff=400):
    """FFT 高通（仅供 onset 检出用，1960s 电动床电机嗡鸣约 200Hz）。
    检出在滤波信号上做，切片一律取自原始信号。"""
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / sr)
    spec[freqs < cutoff] = 0
    return np.fft.irfft(spec, n=len(x)).astype(np.float32)


def centroid(seg, sr):
    spec = np.abs(np.fft.rfft(seg * np.hanning(len(seg))))
    freqs = np.fft.rfftfreq(len(seg), 1 / sr)
    tot = spec.sum()
    return float((freqs * spec).sum() / tot) if tot > 0 else 0.0


def band_ratio(seg, sr, lo=2000, hi=5000):
    spec = np.abs(np.fft.rfft(seg * np.hanning(len(seg))))
    freqs = np.fft.rfftfreq(len(seg), 1 / sr)
    tot = spec.sum()
    if tot <= 0:
        return 0.0
    return float(spec[(freqs >= lo) & (freqs <= hi)].sum() / tot)


def decay_ratio(seg, sr):
    """尾 200ms RMS / 头 200ms RMS。铃约 0.01-0.5（衰减音），按键 <0.01（瞬发）。"""
    n = int(sr * 0.2)
    if len(seg) < 2 * n:
        return 0.0
    head = float(np.sqrt(np.mean(seg[:n] ** 2)))
    tail = float(np.sqrt(np.mean(seg[-n:] ** 2)))
    return tail / max(head, 1e-6)


def strong_segs(x, sr, hp=False):
    det = hp_filter(x, sr) if hp else x
    segs = find_presses(det, sr)
    if not segs:
        return []
    gpeak = max(s[2] for s in segs)
    return [s for s in segs if s[2] >= 0.25 * gpeak]


def clean_segs(segs, sr, loud_times):
    """剔掉与大声事件（铃／滑架）重叠的段：事件起音前 0.5s 至起音后 2.0s 内的段一律不用
    （铃的衰减与滑架声会污染按键／空格／退格／瞬态）。大声事件时间来自切包前分析
    （/tmp/f8-analyze6.py：床内最响且带衰减尾的窗口），写在各包配方里。"""
    out = []
    for s, e, pk in segs:
        t0, t1 = s / sr, e / sr
        if any(t0 < lt + 2.0 and t1 > lt - 0.5 for lt in loud_times):
            continue
        out.append((s, e, pk))
    return out


def cut_variants(x, sr, segs, out_dir, count=12):
    """12 按键变体：沿床全程均匀取段（快／慢段落都覆盖）。segs 须已剔铃。
    返回（切分记录， 已用段列表），已用段须从空格／退格／瞬态池里排除。"""
    if len(segs) < count:
        raise RuntimeError(f"强段仅 {len(segs)} 段，少于目标 {count} 段")
    idx = np.linspace(0, len(segs) - 1, count).round().astype(int)
    idx = sorted(set(idx.tolist()))
    made = []
    used = []
    for n, si in enumerate(idx, 1):
        s, e, _ = segs[si]
        used.append((s, e))
        seg = fade_out(normalize(x[s:e]), sr)
        name = f"key-{n:02d}"
        wav = os.path.join(TMP, name + ".wav")
        ogg = os.path.join(out_dir, name + ".ogg")
        write_wav(wav, seg, sr)
        to_ogg(wav, ogg)
        made.append((name, s / sr, (e - s) / sr, os.path.getsize(ogg),
                     centroid(seg, sr)))
        assert 0.08 <= (e - s) / sr <= 0.6, f"{name} 时长 {(e-s)/sr:.2f}s 出窗"
    return made, used


def cut_event(src_wav, t_start, t_end, out_name, out_dir, kind):
    """从源录音的固定窗口切一个事件（铃／回车复位），跑角色断言。"""
    x, sr = load_wav(src_wav)
    s0, s1 = int(t_start * sr), int(t_end * sr)
    seg = x[s0:s1]
    # 先找真实起音（窗口起点可能含前置静音），再按铃／复位口径修剪
    rms, win = envelope(seg, sr)
    hi = rms.max() * 0.10
    above = np.where(rms > hi)[0]
    if len(above) == 0:
        raise RuntimeError(f"{out_name} 窗口 {t_start}-{t_end}s 无有效信号")
    s = max(0, above[0] * win - int(sr * 0.010))
    thr = rms.max() * (0.03 if kind == "bell" else 0.05)
    run_needed = int(150 / 5) if kind == "bell" else int(100 / 5)
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
    e = min(len(seg), (e_win + 1) * win + int(sr * 0.020))
    cut = fade_out(normalize(seg[s:e]), sr)
    dur = (e - s) / sr
    if kind == "bell":
        dr = decay_ratio(cut, sr)
        br = band_ratio(cut, sr)
        assert 0.4 <= dur <= 1.6, f"{out_name} 铃时长 {dur:.2f}s 出窗（0.4-1.6）"
        assert dr >= 0.01, f"{out_name} 铃衰减比 {dr:.3f} 过低（疑似按键非铃）"
        # 2-5kHz 占比阈值 0.15：knufds 第二记铃实测 0.199，属同一只铃的第二次敲击，
        # 非“非铃”；阈值只防明显非铃（如纯低频机械声），不作精细区分。
        assert br >= 0.15, f"{out_name} 铃 2-5kHz 占比 {br:.2f} 过低（疑似非铃）"
    else:  # reset
        br = band_ratio(cut, sr)
        mean_rms = float(np.sqrt(np.mean(cut ** 2)))
        assert 1.0 <= dur <= 3.5, f"{out_name} 复位时长 {dur:.2f}s 出窗（1.0-3.5）"
        assert br < 0.40, f"{out_name} 复位 2-5kHz 占比 {br:.2f} 过高（疑似铃非滑架声）"
        assert mean_rms >= 0.003, f"{out_name} 复位平均 RMS {mean_rms:.4f} 过低（疑似静音）"
    wav = os.path.join(TMP, out_name + ".wav")
    ogg = os.path.join(out_dir, out_name + ".ogg")
    write_wav(wav, cut, sr)
    to_ogg(wav, ogg)
    return (out_name, t_start + s / sr, dur, os.path.getsize(ogg),
            centroid(cut, sr))


def low_share(seg, sr, cutoff=400):
    """<cutoff Hz 能量占比。电动床电机嗡鸣约 200Hz，弱击段会被嗡鸣主导（>0.4），
    须与真正的空格闷响区分。"""
    spec = np.abs(np.fft.rfft(seg * np.hanning(len(seg))))
    freqs = np.fft.rfftfreq(len(seg), 1 / sr)
    tot = spec.sum()
    if tot <= 0:
        return 0.0
    return float(spec[freqs < cutoff].sum() / tot)


def pick_by_centroid(x, sr, segs, lowest=True, exclude=(), hp=False):
    """按谱质心挑一段：lowest=True 取质心最低（空格键闷响），反之取最高。
    exclude：已用作按键的段，不许重复。hp=True 时先高通 400Hz 再算质心
    （电动床电机嗡鸣会把弱击段的质心拉低，须排除嗡鸣干扰）。"""
    scored = []
    for s, e, _ in segs:
        if (s, e) in exclude:
            continue
        seg = x[s:e]
        if hp:
            seg = hp_filter(seg, sr)
        scored.append((centroid(seg, sr), s, e))
    scored.sort()
    c, s, e = scored[0] if lowest else scored[-1]
    return s, e, c


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


# ---------------------------------------------------------------- 每包配方
# 事件时间来自切包前分析（/tmp/f8-analyze*.py，方法见 draft v2）：
# 铃候选＝床内最响且带衰减尾（500ms 后 RMS／头 200ms RMS ≥0.25）的大声事件；
# 回车复位＝行末长空隙内的滑架声。
RECIPES = {
    "1930": {
        "label": "1930s portable",
        "bed": "bed-megashroom-390343.wav",
        "bed_hp": False,
        # 床内大声事件（铃／滑架，f8-analyze6：最响且带衰减尾的窗口；按键池须避开）
        "loud_events": [14.6, 20.6, 34.2, 35.4, 65.4, 79.6],
        "bells": [
            ("file", "bell-fastson-99695.wav", True, 1.0, 0.01),  # fastson 实测铃，尾阈 1% 留余音
            ("event", "bed-megashroom-390343.wav", 34.2, 35.7),
            ("event", "bed-megashroom-390343.wav", 20.6, 22.1),
        ],
        "reset": ("event", "bed-megashroom-390343.wav", 49.0, 51.0),
        "alt_from": "bed",          # 退格：床内最强段
        "space_from": "bed",        # 空格：床内质心最低强段
        "transient_from": "bed",    # 瞬态：床内最短强段
    },
    "1950": {
        "label": "1950s streamlined",
        "bed": "bed-escritor1-455043.wav",
        "bed_hp": False,
        # 床内大声事件（铃／滑架，f8-analyze6；按键池须避开）
        "loud_events": [34.4, 45.2, 48.4, 140.2, 165.4, 174.8],
        "bells": [
            ("event", "bed-springtide-259498.wav", 6.4, 7.9),
            ("event", "bed-springtide-259498.wav", 27.8, 29.3),
            ("event", "bed-escritor1-455043.wav", 140.2, 141.7),
        ],
        "reset": ("event", "bed-springtide-259498.wav", 28.2, 29.4),
        "alt_from": "bed",
        "space_from": "bed",
        "transient_from": "bed",
    },
    "1960": {
        "label": "1960s electric",
        "bed": "bed-secretmojo-224012.flac",
        "bed_hp": True,  # 电机嗡鸣约 200Hz，检出前高通 400Hz（切片仍取原始信号）
        # 本床无铃（铃已坏）；大声事件皆为按键，无须剔除
        "loud_events": [],
        # 打字 16-110s，110s 后为电机停转区，末段质心异常（4116Hz vs 按键 8.5kHz），排除
        "bed_end": 108.0,
        # 铃：v1 三件（ramsamba／margin-bell／MasterNavigator）与基线包完全相同，
        # audio-verify 跨包同角色 ≥0.03 门会报 0.0000 FAIL，故改用仓内已有通用铃录音：
        # knufds 文件内两记铃（0.09s／2.37s，中间 1.50s 为滑架声）＋evsecrets 床内行末叮
        # （46.4s）。属 documented fallback，非本机实录。
        "bells": [
            ("event", "bell-carriage-reset-knufds-345955.wav", 0.05, 0.65),
            ("event", "bell-carriage-reset-knufds-345955.wav", 2.33, 2.92),
            ("event", "bed-evsecrets-334458.wav", 46.4, 47.9),
        ],
        "reset": ("file", "return-magedu-319945.wav", False, 1.0),
        "alt_from": "adamj",        # 退格：adamj 孤立单键段
        "space_from": "bed",
        "transient_from": "bed",
    },
}

# 原始素材记录（SOURCE.txt 前半；SHA-256 实测填入）
SOURCES = {
    "bed-megashroom-390343.wav": ("megashroom", "Portable typewriter sounds",
        "CC0", "https://freesound.org/people/megashroom/sounds/390343/"),
    "bell-fastson-99695.wav": ("fastson", "Typewriter bell.wav",
        "CC BY", "https://freesound.org/people/fastson/sounds/99695/"),
    "bed-escritor1-455043.wav": ("escritor1", "Loading Paper and Typewriter Typing.wav",
        "CC0", "https://freesound.org/people/escritor1/sounds/455043/"),
    "bed-springtide-259498.wav": ("Spring_Tide", "OLD_Typewriter_ALL.wav",
        "CC0", "https://freesound.org/people/Spring_Tide/sounds/259498/"),
    "bed-secretmojo-224012.flac": ("secretmojo", "IBM Selectric II",
        "CC0", "https://freesound.org/people/secretmojo/sounds/224012/"),
    "bed-adamj-538796.wav": ("AdamJ", "Olympia Typewriter",
        "CC BY", "https://freesound.org/people/AdamJ/sounds/538796/"),
    "return-magedu-319945.wav": ("magedu", "typewriter_electric_return.wav",
        "CC BY", "https://freesound.org/people/magedu/sounds/319945/"),
    "bell-01-ramsamba-318687.wav": ("ramsamba", "Typewriter Bell",
        "CC0", "https://freesound.org/people/ramsamba/sounds/318687/（v1 复用）"),
    "margin-bell-01.wav": ("BigSoundBank", "margin-bell-01",
        "CC0", "BigSoundBank（v1 复用）"),
    "bell-02-masternavigator-444813.wav": ("MasterNavigator", "Typewriter Bell",
        "CC0", "https://freesound.org/people/masternavigator/sounds/444813/（v1 复用）"),
    "bell-carriage-reset-knufds-345955.wav": ("knufds", "Typewriter bell & carriage reset",
        "CC0", "https://freesound.org/people/knufds/sounds/345955/（v1 复用，文件内两记铃）"),
    "bed-evsecrets-334458.wav": ("evsecrets", "Typing on a typewriter with ding every time the line ends",
        "作者声明 public domain", "https://freesound.org/s/334458/（v1 备料复用）"),
}


def cut_pack(slug):
    r = RECIPES[slug]
    out_dir = os.path.join(SOUND, f"pack-{slug}")
    os.makedirs(TMP, exist_ok=True)
    os.makedirs(out_dir, exist_ok=True)
    print(f"\n===== pack-{slug}（{r['label']}）=====")
    report = []  # (name, 源, 偏移, 时长, 字节, 质心)
    used_sources = []

    # 1. 床 → 12 按键变体（沿全程均匀取段；先剔大声事件，避免按键沾上铃的衰减尾）
    bed16 = os.path.join(TMP, f"bed-{slug}.wav")
    to_mono16(os.path.join(FREESOUND, r["bed"]), bed16)
    x, sr = load_wav(bed16)
    segs_all = strong_segs(x, sr, hp=r["bed_hp"])
    loud_times = r.get("loud_events", [])
    segs = clean_segs(segs_all, sr, loud_times)
    if r.get("bed_end") is not None:
        segs = [s for s in segs if s[0] / sr < r["bed_end"]]
        print(f"床尾 {r['bed_end']}s 之后（电机停转区）的段已排除")
    print(f"床内大声事件 {len(loud_times)} 处："
          f"{[f'{t:.1f}s' for t in loud_times]}（已从按键池剔除）")
    print(f"可用强段 {len(segs)}（原 {len(segs_all)}）")
    print("主床变体：")
    key_rows, used = cut_variants(x, sr, segs, out_dir, 12)
    used_set = set(used)
    for name, off, dur, size, cent in key_rows:
        print(f"  {name}.ogg 源偏移 {off:.2f}s 长 {dur:.3f}s {size}B 质心 {cent:.0f}Hz")
        report.append((name, r["bed"], off, dur, size, cent))
    used_sources.append(r["bed"])

    key_cents = [c for _, _, _, _, _, c in report]
    med_key_cent = float(np.median(key_cents))

    # 2. 空格：床内质心最低的实击段（已用作按键的段排除，不得与 key-01~12 重复）。
    # 只取峰值 ≥ 按键中位峰值 70% 的实击段——弱击段会被电动床嗡鸣主导（低频占比
    # 0.42），质心虽低却不是空格闷响。电动床先高通再算质心，并断言低频占比
    # <0.20；手动床无嗡鸣，不做此断言（闷响本身低频就多）。
    key_peaks = sorted(s[2] for s in segs)
    med_peak = key_peaks[len(key_peaks) // 2]
    pool = [t for t in segs if (t[0], t[1]) not in used_set and t[2] >= 0.7 * med_peak]
    if r["bed_hp"]:
        pool = [t for t in pool if low_share(x[t[0]:t[1]], sr) < 0.15]
    if not pool:
        pool = [t for t in segs if (t[0], t[1]) not in used_set]
    s, e, c = pick_by_centroid(x, sr, pool, lowest=True, exclude=(), hp=r["bed_hp"])
    if r["bed_hp"]:
        ls = low_share(x[s:e], sr)
        assert ls < 0.20, f"space 低频占比 {ls:.2f} 过高（疑似嗡鸣主导的弱击段）"
    # 空格取床内质心最低的实击段（宽条空格键的闷响）；只要求低于按键中位质心——
    # 电动床按键亮度极均一（8.1-9.4kHz），最闷的实击段也只比中位低 3%，这在
    # Selectric 上是真实的（空格与按键是同一机构，只差字球位置）。
    assert c < med_key_cent, f"space 质心 {c:.0f}Hz 未低于按键中位 {med_key_cent:.0f}Hz"
    seg = fade_out(normalize(x[s:e]), sr)
    wav = os.path.join(TMP, "space-01.wav")
    write_wav(wav, seg, sr)
    to_ogg(wav, os.path.join(out_dir, "space-01.ogg"))
    print(f"  space-01.ogg 源偏移 {s/sr:.2f}s 长 {(e-s)/sr:.3f}s "
          f"{os.path.getsize(os.path.join(out_dir,'space-01.ogg'))}B 质心 {c:.0f}Hz"
          f"（按键中位 {med_key_cent:.0f}Hz）")
    report.append(("space-01", r["bed"], s / sr, (e - s) / sr,
                   os.path.getsize(os.path.join(out_dir, "space-01.ogg")), c))
    used_set.add((s, e))

    # 3. 铃 ×3
    print("铃：")
    for i, bell in enumerate(r["bells"], 1):
        name = f"bell-{i:02d}"
        if bell[0] == "file":
            src = bell[1]
            path = (os.path.join(FREESOUND, src) if src in SOURCES and "margin" not in src
                    else os.path.join(REPO, "assets", "sounds", "bigsoundbank", src))
            if not os.path.exists(path):
                path = os.path.join(FREESOUND, src)
            tail_pct = bell[4] if len(bell) > 4 else None
            row = trim_single(path, name, out_dir, bell=True, extra_gain=bell[3],
                              tail_pct=tail_pct)
            print(f"  {name}.ogg 来源 {src} 偏移 {row[1]:.2f}s 长 {row[2]:.3f}s {row[3]}B")
            report.append((name, src, row[1], row[2], row[3], None))
            if src not in used_sources:
                used_sources.append(src)
        else:
            _, src, t0, t1 = bell
            row = cut_event(_mono(src), t0, t1, name, out_dir, "bell")
            print(f"  {name}.ogg 来源 {src}@{t0:.1f}s 长 {row[2]:.3f}s {row[3]}B 质心 {row[4]:.0f}Hz")
            report.append((name, src, row[1], row[2], row[3], row[4]))
            if src not in used_sources:
                used_sources.append(src)

    # 4. 回车复位
    print("回车复位：")
    rst = r["reset"]
    if rst[0] == "file":
        src = rst[1]
        path = os.path.join(FREESOUND, src)
        row = trim_single(path, "carriage-reset-01", out_dir, bell=False, extra_gain=rst[3])
        print(f"  carriage-reset-01.ogg 来源 {src} 偏移 {row[1]:.2f}s 长 {row[2]:.3f}s {row[3]}B")
        report.append(("carriage-reset-01", src, row[1], row[2], row[3], None))
        if src not in used_sources:
            used_sources.append(src)
    else:
        _, src, t0, t1 = rst
        row = cut_event(_mono(src), t0, t1, "carriage-reset-01", out_dir, "reset")
        print(f"  carriage-reset-01.ogg 来源 {src}@{t0:.1f}s 长 {row[2]:.3f}s {row[3]}B 质心 {row[4]:.0f}Hz")
        report.append(("carriage-reset-01", src, row[1], row[2], row[3], row[4]))
        if src not in used_sources:
            used_sources.append(src)

    # 5. 退格（key-alt-01）：床内最强段，或 adamj 孤立单键
    if r["alt_from"] == "adamj":
        a16 = os.path.join(TMP, "adamj16.wav")
        to_mono16(os.path.join(FREESOUND, "bed-adamj-538796.wav"), a16)
        ax, asr = load_wav(a16)
        asegs = [s for s in strong_segs(ax, asr) if 48.0 <= s[0] / asr <= 54.0]
        if not asegs:
            asegs = strong_segs(ax, asr)
        s, e, _ = max(asegs, key=lambda t: t[2])
        seg = fade_out(normalize(ax[s:e]), asr)
        wav = os.path.join(TMP, "key-alt-01.wav")
        write_wav(wav, seg, asr)
        to_ogg(wav, os.path.join(out_dir, "key-alt-01.ogg"))
        print(f"  key-alt-01.ogg 来源 bed-adamj-538796.wav@{s/asr:.2f}s（孤立单键段）"
              f" 长 {(e-s)/asr:.3f}s")
        report.append(("key-alt-01", "bed-adamj-538796.wav", s / asr, (e - s) / asr,
                       os.path.getsize(os.path.join(out_dir, "key-alt-01.ogg")), None))
        used_sources.append("bed-adamj-538796.wav")
    else:
        pool = [t for t in segs if (t[0], t[1]) not in used_set]
        s, e, _ = max(pool, key=lambda t: t[2])
        seg = fade_out(normalize(x[s:e]), sr)
        wav = os.path.join(TMP, "key-alt-01.wav")
        write_wav(wav, seg, sr)
        to_ogg(wav, os.path.join(out_dir, "key-alt-01.ogg"))
        print(f"  key-alt-01.ogg 来源 {r['bed']}@{s/sr:.2f}s（床内最强段）长 {(e-s)/sr:.3f}s")
        report.append(("key-alt-01", r["bed"], s / sr, (e - s) / sr,
                       os.path.getsize(os.path.join(out_dir, "key-alt-01.ogg")), None))

    # 6. 瞬态层：床内最短强段（已用段排除）
    pool = [t for t in segs if (t[0], t[1]) not in used_set]
    s, e, _ = min(pool, key=lambda t: t[1] - t[0])
    seg = fade_out(normalize(x[s:e]), sr)
    wav = os.path.join(TMP, "key-transient.wav")
    write_wav(wav, seg, sr)
    to_ogg(wav, os.path.join(out_dir, "key-transient.ogg"))
    print(f"  key-transient.ogg 来源 {r['bed']}@{s/sr:.2f}s（床内最短强段）长 {(e-s)/sr:.3f}s")
    report.append(("key-transient", r["bed"], s / sr, (e - s) / sr,
                   os.path.getsize(os.path.join(out_dir, "key-transient.ogg")), None))

    # 7. 写 SOURCE.txt（两半）与 BUILD-REPORT.txt
    total = sum(os.path.getsize(os.path.join(out_dir, f)) for f in os.listdir(out_dir)
                if f.endswith(".ogg"))
    print(f"总计 {len(report)} 个文件，{total} 字节")
    assert len(report) == 19, f"文件数 {len(report)} ≠ 19"
    assert len([f for f in os.listdir(out_dir) if f.endswith('.ogg')]) == 19
    write_source_txt(out_dir, slug, r, report, used_sources)
    with open(os.path.join(out_dir, "BUILD-REPORT.txt"), "w", encoding="utf-8") as f:
        f.write(f"回车音效包 pack-{slug}（Freesound 实录）构建记录\n")
        for name, src, off, dur, size, _ in report:
            f.write(f"{name}.ogg 来源 {src} 偏移 {off:.2f}s 长 {dur:.3f}s {size}B\n")
        f.write(f"总计 {len(report)} 个文件，{total} 字节\n")
    return report


_mono_cache = {}


def _mono(fname):
    """把 freesound/ 或 bigsoundbank/ 的源文件转 mono16（缓存）。"""
    if fname in _mono_cache:
        return _mono_cache[fname]
    path = os.path.join(FREESOUND, fname)
    if not os.path.exists(path):
        path = os.path.join(REPO, "assets", "sounds", "bigsoundbank", fname)
    dst = os.path.join(TMP, "mono-" + fname.replace(".flac", ".wav"))
    to_mono16(path, dst)
    _mono_cache[fname] = dst
    return dst


def write_source_txt(out_dir, slug, recipe, report, used_sources):
    lines = []
    lines.append(f"回车音效包 pack-{slug}（{recipe['label']}）来源记录")
    lines.append("采制：Freesound 实录（用户人工下载，2026-11-09）")
    lines.append("切包：tools/cut-sound-packs.py（OGG Vorbis 单声道 44.1kHz，峰值归一化 -1.5dB）")
    lines.append("")
    lines.append("§1 原始素材")
    for src in used_sources:
        author, title, lic, url = SOURCES[src]
        path = os.path.join(FREESOUND, src)
        if not os.path.exists(path):
            path = os.path.join(REPO, "assets", "sounds", "bigsoundbank", src)
        lines.append(f"- {src}")
        lines.append(f"  作者：{author}｜标题：{title}｜协议：{lic}")
        lines.append(f"  来源页：{url}")
        lines.append(f"  下载日期：2026-11-09｜SHA-256：{sha256(path)}")
    lines.append("")
    lines.append("§2 逐文件切分映射（包内文件 → 源素材／源偏移／时长／字节／SHA-256）")
    for name, src, off, dur, size, _ in report:
        ogg = os.path.join(out_dir, name + ".ogg")
        lines.append(f"- {name}.ogg ← {src} @ {off:.2f}s，长 {dur:.3f}s，{size}B，"
                     f"SHA-256：{sha256(ogg)}")
    lines.append("")
    lines.append("§3 备注")
    if slug == "1960":
        lines.append("- 铃三件取自仓内已有通用铃录音：knufds 文件内两记铃（0.09s／2.37s）"
                     "＋evsecrets 床内行末叮（46.4s）。secretmojo 的铃已坏，AdamJ 内无铃；"
                     "属 documented fallback，非本机实录。v1 三件铃（ramsamba／margin-bell／"
                     "MasterNavigator）与基线包完全相同，用之则 audio-verify 跨包 ≥0.03 门"
                     "报 0.0000 FAIL，故不用。")
    if slug == "1930":
        lines.append("- 铃一件为 fastson 单音，两件取自 megashroom 床内行末大声事件（带衰减尾）；"
                     "回车复位取自床内行末长空隙的滑架声。")
    if slug == "1950":
        lines.append("- 铃两件取自 spring_tide 全流程录音的行末事件，一件取自 escritor1 床内"
                     "行末事件；回车复位取自 spring_tide 末段滑架声。")
    with open(os.path.join(out_dir, "SOURCE.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pack", required=True, choices=["1930", "1950", "1960", "all"])
    args = ap.parse_args()
    os.makedirs(TMP, exist_ok=True)
    slugs = ["1930", "1950", "1960"] if args.pack == "all" else [args.pack]
    for slug in slugs:
        cut_pack(slug)
    print("\n全部完成。")


if __name__ == "__main__":
    main()
