#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
回车 CarriageReturn —— 内置拼音词库构建脚本（v1）

三源（钉版本，SHA-256 记入 DICT-ATTRIBUTION.md）：
  1) jieba dict.txt（MIT）—— 词表 + 词频，排序燃料
  2) pypinyin（MIT，pip 安装）—— 词组读音覆盖层（纠多音字：重庆/音乐/银行）
  3) pinyin-data 的 Unihan kMandarin（Unicode License v3）—— 单字读音表

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
PINYIN_DATA_URL = 'https://raw.githubusercontent.com/mozillazg/pinyin-data/master/pinyin.txt'

MAX_WORDS = 80000
WORD_BUDGET = 2500 * 1024
CHAR_BUDGET = 400 * 1024


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

    char_map = {}
    for ch, readings in chars.items():
        syl = readings[0].lower().replace('ü', 'v')
        char_map.setdefault(syl, []).append(ch)
    chars_json = json.dumps(char_map, ensure_ascii=False, separators=(',', ':'))
    chars_bytes = chars_json.encode('utf-8')

    with open(os.path.join(DICT_DIR, 'pinyin-words.json'), 'wb') as f:
        f.write(words_bytes)
    with open(os.path.join(DICT_DIR, 'pinyin-chars.json'), 'wb') as f:
        f.write(chars_bytes)

    jieba_sha = sha256(jieba_data)
    pd_sha = sha256(pd_data)
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
        '',
        '生成口径：',
        '- 每词读音 = pypinyin 词组读音优先；取不到则用 pinyin-data 单字主读音拼接。',
        '- 只保留 1–4 字、全为汉字的词；按 jieba 词频降序截前 ' + str(MAX_WORDS) + ' 词。',
        '- 输出：dict/pinyin-words.json（' + str(len(trimmed)) + ' 键 / ' + str(n_words) + ' 词 / ' + ('%.2f' % (len(words_bytes) / 1048576.0)) + ' MB）与 dict/pinyin-chars.json（' + str(len(char_map)) + ' 音节 / ' + str(n_chars) + ' 字 / ' + ('%.1f' % (len(chars_bytes) / 1024.0)) + ' KB）。',
        '- 未使用：rime-ice（GPL）、搜狗细胞词库、THUOCL／八股文、CC-CEDICT（v1.5 再说）。',
    ]
    with open(os.path.join(RAW, 'DICT-ATTRIBUTION.md'), 'w', encoding='utf-8') as f:
        f.write(chr(10).join(attr) + chr(10))
    print('完成')


if __name__ == '__main__':
    main()
