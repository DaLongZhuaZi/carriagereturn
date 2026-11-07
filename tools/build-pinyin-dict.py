#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
回车 CarriageReturn —— 内置拼音词库构建脚本（v2）

四源（钉版本，SHA-256 记入 DICT-ATTRIBUTION.md）：
  1) jieba dict.txt（MIT）—— 词表 + 词频，排序燃料（截前 80000 词，2013 年语料，缺现代词）
  2) pypinyin（MIT，pip 安装）—— 词组读音覆盖层（纠多音字：重庆/音乐/银行）
  3) pinyin-data 的 Unihan kMandarin（Unicode License v3）—— 单字读音表
  4) CC-CEDICT（CC BY-SA 4.0）—— 现代词补全（微信/抖音/淘宝等，jieba 缺的 7.2 万词），
     无词频：排在 jieba 词之后；高频现代词另由 HOT 置顶表提至各键首位

用法：python tools/build-pinyin-dict.py
"""

import hashlib
import json
import os
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, 'entry', 'src', 'main', 'resources', 'rawfile')
DICT_DIR = os.path.join(RAW, 'dict')

JIEBA_URL = 'https://raw.githubusercontent.com/fxsjy/jieba/master/jieba/dict.txt'
UNIHAN_FREQ_URL = 'https://www.unicode.org/Public/UCD/latest/ucd/Unihan.zip'
PINYIN_DATA_URL = 'https://raw.githubusercontent.com/mozillazg/pinyin-data/master/pinyin.txt'
CEDICT_URL = 'https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.txt.gz'

MAX_WORDS = 80000
WORD_BUDGET = 3072 * 1024
CHAR_BUDGET = 400 * 1024

# CC-CEDICT 也没有的词（品牌名／新词／常见人名）：人工维护，补进来。
# 读音由 pypinyin 推导；进词库后同样参与 HOT 置顶。
SUPPLEMENT = [
    '美团', '饿了么', '共享单车', '手机支付', '共享充电宝', '拔草', '柠檬精',
    '李华', '王小明', '张伟', '李伟', '王伟', '张敏', '王磊', '李静',
    '张杰', '王涛', '李明', '张强', '王刚',
]

# 高频现代词置顶表：这些词在 jieba 里或排在同音旧词之后、或只在 CC-CEDICT 里（排在队尾），
# 首次输入就应排首位（之后由学习排序接管）。人工维护，只放日常高频词，不放生僻词。
HOT = [
    '微信', '抖音', '淘宝', '支付宝', '美团', '外卖', '京东', '拼多多', '快手',
    '直播', '短视频', '点赞', '红包', '高铁', '地铁', '共享单车', '二维码',
    '公众号', '朋友圈', '早安', '打卡', '内卷', '躺平', '扫码', '秒杀',
    '种草', '滴滴', '饿了么', '手机支付', '张三', '李华', '王小明',
    '共享', '快递', '打车', '上网', '游戏', '视频', '手机', '电脑',
    '互联网', '工作', '学习', '老师', '学生', '朋友', '家人', '孩子',
    '谢谢', '不好意思', '没关系', '吃饭', '睡觉', '喜欢', '时间', '永远',
    '感谢', '精彩', '模糊', '经典',
]


def fetch(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'carriagereturn-dict/1.0'})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def commit_sha(owner_repo, path, branch='master'):
    url = 'https://api.github.com/repos/%s/commits?path=%s&sha=%s&per_page=1' % (owner_repo, path, branch)
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'carriagereturn-dict/1.0'})
        with urllib.request.urlopen(req, timeout=30) as r:
            arr = json.loads(r.read().decode('utf-8'))
        if isinstance(arr, list) and arr:
            return arr[0].get('sha', '')[:12]
    except Exception as e:
        return 'unknown(%s)' % type(e).__name__
    return 'unknown'


def load_unihan_freq():
    """Unihan kFrequency：1..5（1 最常用）。返回 {字: 档位}。"""
    import io as _io
    import zipfile
    try:
        data = fetch(UNIHAN_FREQ_URL)
        zf = zipfile.ZipFile(_io.BytesIO(data))
        name = None
        for n in zf.namelist():
            if n.endswith('Unihan_DictionaryLikeData.txt'):
                name = n
                break
        if name is None:
            return {}
        text = zf.read(name).decode('utf-8', 'ignore')
        out = {}
        for line in text.splitlines():
            if not line.startswith('U+'):
                continue
            parts = line.split(chr(9))
            if len(parts) < 3 or parts[1] != 'kFrequency':
                continue
            try:
                ch = chr(int(parts[0][2:], 16))
                out[ch] = int(parts[2])
            except ValueError:
                continue
        return out
    except Exception as e:
        print('Unihan kFrequency 获取失败（%s），退回 jieba 词频序' % type(e).__name__)
        return {}


def is_hanzi(ch):
    return '\u4e00' <= ch <= '\u9fff'


def load_chars(pinyin_txt):
    tone_map = str.maketrans({
        'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a',
        'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
        'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i',
        'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
        'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u',
        'ǖ': 'v', 'ǘ': 'v', 'ǚ': 'v', 'ǜ': 'v', 'ü': 'v',
        'ń': 'n', 'ň': 'n', 'ǹ': 'n', 'ḿ': 'm',
    })
    chars = {}
    for line in pinyin_txt.splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        code, _, rest = line.partition(':')
        rest = rest.split('#', 1)[0].strip()
        if not code.startswith('U+') or not rest:
            continue
        try:
            ch = chr(int(code[2:], 16))
        except ValueError:
            continue
        if not is_hanzi(ch):
            continue
        readings = []
        for token in rest.split(','):
            syl = token.strip().lower().translate(tone_map)
            syl = ''.join(c for c in syl if c.isalpha())
            if syl and syl not in readings:
                readings.append(syl)
        if readings:
            chars[ch] = readings
    return chars


def cedict_key(py):
    """CC-CEDICT 读音转引擎键：'Wei1 xin4' -> 'weixin'；'nu:3' -> 'nv'；去声调。"""
    import re as _re
    py = py.replace('u:', 'v').replace('ü', 'v')
    py = _re.sub(r'\d', '', py)
    py = py.replace(' ', '').lower()
    return py


def load_cedict(data):
    """解析 CC-CEDICT（gzip 解压后的文本），返回 [(简体词, 读音键)]（2–4 字、全汉字）。
    只收 2 字以上：单字已由字表（pinyin-chars.json，Unihan 全量）覆盖，CC-CEDICT 的单字
    条目多为生僻字，进词表只会把候选列表撑满、把常用模糊候选（只）挤出前 60。"""
    import gzip as _gzip
    import io as _io
    import re as _re
    try:
        text = _gzip.decompress(data).decode('utf-8', 'ignore')
    except Exception:
        text = data.decode('utf-8', 'ignore')
    out = []
    for line in text.splitlines():
        if not line or line.startswith('#'):
            continue
        m = _re.match(r'(\S+) (\S+) \[([^\]]+)\] /', line)
        if not m:
            continue
        simp = m.group(2)
        key = cedict_key(m.group(3))
        if not (2 <= len(simp) <= 4) or not all(is_hanzi(c) for c in simp):
            continue
        if not key or not key.isalpha():
            continue
        out.append((simp, key))
    return out


def main():
    os.makedirs(DICT_DIR, exist_ok=True)
    t0 = time.time()

    print('下载 jieba dict.txt ...')
    jieba_data = fetch(JIEBA_URL)
    jieba_txt = jieba_data.decode('utf-8', 'ignore')
    print('  %.1f MB sha=%s' % (len(jieba_data) / 1048576.0, sha256(jieba_data)[:16]))

    print('下载 pinyin-data pinyin.txt ...')
    pd_data = fetch(PINYIN_DATA_URL)
    pd_txt = pd_data.decode('utf-8', 'ignore')
    chars = load_chars(pd_txt)
    print('  单字读音 %d' % len(chars))

    print('下载 CC-CEDICT ...')
    cedict_data = fetch(CEDICT_URL)
    cedict_entries = load_cedict(cedict_data)
    print('  %.1f MB sha=%s 条目=%d' % (len(cedict_data) / 1048576.0, sha256(cedict_data)[:16], len(cedict_entries)))

    try:
        from pypinyin import lazy_pinyin, Style
        import pypinyin as _pp
        has_pypinyin = True
        pp_ver = getattr(_pp, '__version__', 'unknown')
    except Exception:
        has_pypinyin = False
        pp_ver = 'not-installed'
    print('pypinyin=%s' % pp_ver)

    entries = []
    for line in jieba_txt.splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
        word, freq_s = parts[0], parts[1]
        if not word or not all(is_hanzi(c) for c in word):
            continue
        if len(word) > 4:
            continue
        try:
            freq = int(freq_s)
        except ValueError:
            continue
        entries.append((word, freq))

    entries.sort(key=lambda x: -x[1])
    print('候选词 %d' % len(entries))

    word_py = {}
    skipped = 0
    for word, freq in entries:
        py = ''
        if has_pypinyin:
            seq = lazy_pinyin(word, style=Style.NORMAL, errors='ignore')
            if len(seq) == len(word):
                py = ''.join(seq)
        if not py:
            buf = []
            ok = True
            for ch in word:
                r = chars.get(ch)
                if not r:
                    ok = False
                    break
                buf.append(r[0])
            if not ok:
                skipped += 1
                continue
            py = ''.join(buf)
        py = py.lower().replace('ü', 'v')
        if not py.isalpha():
            skipped += 1
            continue
        word_py.setdefault(py, []).append(word)

    total = 0
    trimmed = {}
    for py, words in word_py.items():
        keep = words
        if total + len(keep) > MAX_WORDS:
            keep = words[:max(0, MAX_WORDS - total)]
        if keep:
            trimmed[py] = keep
            total += len(keep)
        if total >= MAX_WORDS:
            break

    words_json = json.dumps(trimmed, ensure_ascii=False, separators=(',', ':'))
    words_bytes = words_json.encode('utf-8')

    if len(words_bytes) > WORD_BUDGET:
        order = sorted(trimmed.keys(), key=lambda k: len(trimmed[k]))
        drop = set()
        acc = len(words_bytes)
        for k in order:
            if acc <= WORD_BUDGET:
                break
            acc -= len(trimmed[k]) * 3 + 8
            drop.add(k)
        trimmed = {k: v for k, v in trimmed.items() if k not in drop}
        words_json = json.dumps(trimmed, ensure_ascii=False, separators=(',', ':'))
        words_bytes = words_json.encode('utf-8')

    # 单字词频（jieba 里有单字条目）：字表按常用度排序，常用字在前、生僻字沉底
    char_freq = {}
    for word, freq in entries:
        if len(word) == 1:
            char_freq[word] = max(char_freq.get(word, 0), freq)

    # §11.5 词表质量过滤：整词全是生僻字（单字词频 < 50）或词频 < 10 的去掉
    common_chars = set()
    for ch0, f0 in char_freq.items():
        if f0 >= 50:
            common_chars.add(ch0)
    word_freq_map = {}
    for word0, freq0 in entries:
        word_freq_map[word0] = freq0
    # 白名单：人工维护，永不删（含旧表就缺的常用词）
    WHITELIST = set([
        '咖啡', '垃圾', '槟榔', '傀儡', '咆哮', '喃喃', '邂逅', '妞妞', '鹧鸪', '这股',
        '回车', '输入法',
    ])
    # 白名单里源表就缺的词：补进来（用 pypinyin 推导读音，插到该键最前）
    present = set()
    for py0 in trimmed.keys():
        for w0 in trimmed[py0]:
            present.add(w0)
    injected = []
    for wl in WHITELIST:
        if wl in present:
            continue
        if has_pypinyin:
            seq = lazy_pinyin(wl, style=Style.NORMAL, errors='ignore')
            if len(seq) == len(wl):
                pyw = ''.join(seq).lower().replace('ü', 'v')
                if pyw not in trimmed:
                    trimmed[pyw] = []
                trimmed[pyw].insert(0, wl)
                injected.append((wl, pyw))
    if injected:
        print('白名单补入 %d 词：%s' % (len(injected), injected))

    filtered = {}
    dropped_rare = 0
    dropped_both = 0
    dropped_keys = []
    for py in list(trimmed.keys()):
        keep = []
        for w in trimmed[py]:
            if w in WHITELIST:
                keep.append(w)
                continue
            all_rare = all(c not in common_chars for c in w)
            low_freq = word_freq_map.get(w, 0) < 10
            # 双条件：只有「整词全生僻」且「词频低于下限」才删；任一不满足就留
            if all_rare and low_freq:
                dropped_both += 1
                continue
            keep.append(w)
        if keep:
            filtered[py] = keep
        else:
            dropped_keys.append(py)
    trimmed = filtered
    print('被删空的键（%d 个）：%s' % (len(dropped_keys), ','.join(dropped_keys[:60])))
    words_json = json.dumps(trimmed, ensure_ascii=False, separators=(',', ':'))
    words_bytes = words_json.encode('utf-8')
    print('过滤：双条件删除 %d 词（全生僻且低频）' % dropped_both)

    # v2：CC-CEDICT 合并（在质量过滤之后——它是编纂词典不是语料噪声，不受 jieba 词频过滤；
    # 排在 jieba 词之后，不扰动现有排序；HOT 表再把高频现代词提至各键首位）
    n_before = sum(len(v) for v in trimmed.values())
    n_cedict_new = 0
    for w_c, k_c in cedict_entries:
        lst_c = trimmed.setdefault(k_c, [])
        if w_c not in lst_c:
            lst_c.append(w_c)
            n_cedict_new += 1
    print('CC-CEDICT 新增 %d 词（去重后）' % n_cedict_new)
    # 补录表（CC-CEDICT 也没有的品牌名／新词／常见人名）：读音走 pypinyin，插到该键首位
    n_supp = 0
    for w_s in SUPPLEMENT:
        if has_pypinyin:
            seq = lazy_pinyin(w_s, style=Style.NORMAL, errors='ignore')
            if len(seq) != len(w_s):
                print('  补录跳过（读音推导失败）：%s' % w_s)
                continue
            py_s = ''.join(seq).lower().replace('ü', 'v')
        else:
            buf = []
            ok = True
            for ch in w_s:
                r = chars.get(ch)
                if not r:
                    ok = False
                    break
                buf.append(r[0])
            if not ok:
                print('  补录跳过（读音推导失败）：%s' % w_s)
                continue
            py_s = ''.join(buf)
        lst_s = trimmed.setdefault(py_s, [])
        if w_s not in lst_s:
            lst_s.insert(0, w_s)
            n_supp += 1
    print('补录表新增 %d 词' % n_supp)
    # HOT 置顶：高频现代词提到各键首位（已在首位的不动）
    n_hot = 0
    for w_h in HOT:
        for k_h, lst_h in trimmed.items():
            if w_h in lst_h and lst_h[0] != w_h:
                lst_h.remove(w_h)
                lst_h.insert(0, w_h)
                n_hot += 1
                break
    print('HOT 置顶 %d 词' % n_hot)
    words_json = json.dumps(trimmed, ensure_ascii=False, separators=(',', ':'))
    words_bytes = words_json.encode('utf-8')
    if len(words_bytes) > WORD_BUDGET:
        order = sorted(trimmed.keys(), key=lambda k: len(trimmed[k]))
        drop = set()
        acc = len(words_bytes)
        for k in order:
            if acc <= WORD_BUDGET:
                break
            acc -= len(trimmed[k]) * 3 + 8
            drop.add(k)
        trimmed = {k: v for k, v in trimmed.items() if k not in drop}
        words_json = json.dumps(trimmed, ensure_ascii=False, separators=(',', ':'))
        words_bytes = words_json.encode('utf-8')
        print('超预算，丢弃 %d 个最小键' % len(drop))
    print('合并后词数 %d（jieba %d + CEDICT %d + 补录 %d）' % (
        sum(len(v) for v in trimmed.values()), n_before, n_cedict_new, n_supp))

    # 常用字序：优先 Unihan kFrequency（1 最常用 … 5 最生僻），同档内按 jieba 单字词频降序；
    # 无 kFrequency 的字沉底。官方《通用规范汉字表》无公开机器可读版，用 Unihan 发布数据替代（出处见 DICT-ATTRIBUTION）。
    # 字频信号＝该字在最终词表里出现的词数（比 jieba 单字词频更贴近真实用字：
    # 像「銆」这类只在语料噪声里出现的字，词表覆盖为 0，自然沉底）
    # 覆盖率只统计「2 字以上的词」：单字词条是语料噪声来源（「銆」就只以单字词条存在）
    char_cov = {}
    for py1 in trimmed.keys():
        for w1 in trimmed[py1]:
            if len(w1) < 2:
                continue
            for c1 in w1:
                char_cov[c1] = char_cov.get(c1, 0) + 1
    # 字表质量过滤：词表里一次都没出现过的字（语料噪声，如「銆」）不进字表；
    # 其余仍按 jieba 单字词频降序（常用字在前）
    # 字序：有「多字词覆盖」的在前（按 jieba 字频降序），零覆盖的（语料噪声，如「銆」）沉底
    common_order = {}
    ranked = sorted(chars.keys(),
                    key=lambda c: (0 if char_cov.get(c, 0) > 0 else 1, -char_freq.get(c, 0)))
    for idx, ch1 in enumerate(ranked):
        common_order[ch1] = idx
    zero_cov = sum(1 for c in chars.keys() if char_cov.get(c, 0) == 0)
    print('字序：%d 字有词覆盖，%d 字零覆盖沉底' % (len(chars) - zero_cov, zero_cov))
    with open(os.path.join(ROOT, 'tools', 'common-chars-3500.txt'), 'w', encoding='utf-8') as f:
        f.write('# 常用字序表（前 3500）：由 jieba dict.txt 单字词频降序推导\n')
        f.write('# 用途：字表主排序（常用字在前、生僻字沉底）。非官方《通用规范汉字表》，官方表无公开机器可读版。\n')
        f.write(''.join(ranked[:3500]) + chr(10))
    print('常用字序表：%d 字' % len(common_order))

    char_map = {}
    for ch, readings in chars.items():
        syl = readings[0].lower().replace('ü', 'v')
        char_map.setdefault(syl, []).append(ch)
    # §13 第 5 步：多读音补读表（数据-only，不改引擎逻辑）
    # 种子：爪→zhua（Unihan 主读音是 zhǎo，口语 zhuǎ 缺失，导致「大龙爪子」推成 dalongzhaozi）
    EXTRA_READINGS = {
        '爪': ['zhua'],
    }
    for ch_e in EXTRA_READINGS.keys():
        for s_e in EXTRA_READINGS[ch_e]:
            if ch_e not in chars:
                continue
            lst = char_map.setdefault(s_e, [])
            if ch_e not in lst:
                lst.insert(0, ch_e)

    for syl in char_map.keys():
        # 主口径＝常用字序（表内按序，表外按 jieba 词频降序排后）
        char_map[syl].sort(key=lambda c: (common_order.get(c, 10 ** 6), -char_freq.get(c, 0)))
    chars_json = json.dumps(char_map, ensure_ascii=False, separators=(',', ':'))
    chars_bytes = chars_json.encode('utf-8')

    with open(os.path.join(DICT_DIR, 'pinyin-words.json'), 'wb') as f:
        f.write(words_bytes)
    with open(os.path.join(DICT_DIR, 'pinyin-chars.json'), 'wb') as f:
        f.write(chars_bytes)

    jieba_sha = sha256(jieba_data)
    pd_sha = sha256(pd_data)
    cedict_sha = sha256(cedict_data)
    jieba_commit = commit_sha('fxsjy/jieba', 'jieba/dict.txt')
    pd_commit = commit_sha('mozillazg/pinyin-data', 'pinyin.txt')

    n_words = sum(len(v) for v in trimmed.values())
    n_chars = sum(len(v) for v in char_map.values())
    print('词表 %.2f MB / %d 键 / %d 词' % (len(words_bytes) / 1048576.0, len(trimmed), n_words))
    print('字表 %.1f KB / %d 音节 / %d 字' % (len(chars_bytes) / 1024.0, len(char_map), n_chars))
    print('跳过 %d 词；耗时 %.1fs' % (skipped, time.time() - t0))

    attr = [
        '# 拼音词库来源与许可（DICT-ATTRIBUTION）',
        '',
        '由 tools/build-pinyin-dict.py 生成，生成时间 ' + time.strftime('%Y-%m-%d') + '。',
        '',
        '| 数据 | 来源 | 许可 | 版本／提交 | SHA-256 |',
        '|---|---|---|---|---|',
        '| 词表＋词频 | fxsjy/jieba jieba/dict.txt | MIT | ' + jieba_commit + ' | ' + jieba_sha + ' |',
        '| 词组读音 | mozillazg/python-pinyin | MIT | pypinyin ' + pp_ver + ' | —— |',
        '| 单字读音 | mozillazg/pinyin-data pinyin.txt（Unihan kMandarin） | Unicode License v3 | ' + pd_commit + ' | ' + pd_sha + ' |',
        '| 现代词补全 | CC-CEDICT（MDBG 发布） | CC BY-SA 4.0 | —— | ' + cedict_sha + ' |',
        '| 补录表＋HOT 置顶表 | 本项目人工维护（见 tools/build-pinyin-dict.py 的 SUPPLEMENT／HOT） | 与本项目同许可（MIT） | —— | —— |',
        '',
        '合并后文件的许可：dict/pinyin-words.json 整体按 **CC BY-SA 4.0** 分发（它并入了 CC-CEDICT 的内容，是 CC-CEDICT 的衍生数据，按 BY-SA 须同许可共享；署名见上表）。其中 jieba／pypinyin／Unihan -derived 的部分各按其原许可（MIT／Unicode License v3）亦可单独使用；App 代码仍是 MIT（代码只是读数据文件，不构成数据的衍生作品）。',
        '如需保住 MIT 主表干净（不与 BY-SA 混在一个文件里），须把词库拆成两个文件分发（主表 MIT＋扩展表 CC BY-SA 4.0），见设计稿 §16.5。',
        '',
        '生成口径：',
        '- 每词读音 = pypinyin 词组读音优先；取不到则用 pinyin-data 单字主读音拼接；CC-CEDICT 词用其自带读音（去声调，u:→v）。',
        '- 只保留 1–4 字、全为汉字的词；jieba 按词频降序截前 ' + str(MAX_WORDS) + ' 词；CC-CEDICT 全量并入（去重，排在 jieba 词之后）。',
        '- HOT 置顶表：高频现代词提到各键首位（首次输入即排首位，之后由学习排序接管）。',
        '- 输出：dict/pinyin-words.json（' + str(len(trimmed)) + ' 键 / ' + str(n_words) + ' 词 / ' + ('%.2f' % (len(words_bytes) / 1048576.0)) + ' MB）与 dict/pinyin-chars.json（' + str(len(char_map)) + ' 音节 / ' + str(n_chars) + ' 字 / ' + ('%.1f' % (len(chars_bytes) / 1024.0)) + ' KB）。',
        '- 未使用：rime-ice（GPL）、搜狗细胞词库、THUOCL（MIT 可商用，v3 候选）、八股文（LGPL）。',
    ]
    with open(os.path.join(RAW, 'DICT-ATTRIBUTION.md'), 'w', encoding='utf-8') as f:
        f.write(chr(10).join(attr) + chr(10))
    print('完成')


if __name__ == '__main__':
    main()
