#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
回车 · CC-CEDICT 交叉校验（构建期，不进仓、不分发）

用途：拿 CC-CEDICT 的单字注音与我们的字表（pinyin-data/Unihan 主读音）比对，
输出「主读音不一致」的差异报告，供多读音补读表（§13 第 5 步）取值。
CC-CEDICT 采用 CC BY-SA 4.0；本脚本只在构建期临时下载，**仓库里不存数据、不分发**。

用法：python tools/cedict-check.py
"""

import gzip
import io
import json
import os
import re
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHARS = os.path.join(ROOT, 'entry', 'src', 'main', 'resources', 'rawfile', 'dict', 'pinyin-chars.json')
URL = 'https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.txt.gz'

TONE = str.maketrans({
    'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a',
    'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
    'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i',
    'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
    'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u',
    'ǖ': 'v', 'ǘ': 'v', 'ǚ': 'v', 'ǜ': 'v', 'ü': 'v',
    'ń': 'n', 'ň': 'n', 'ǹ': 'n', 'ḿ': 'm',
})


def fetch():
    req = urllib.request.Request(URL, headers={'User-Agent': 'carriagereturn-cedict/1.0'})
    with urllib.request.urlopen(req, timeout=120) as r:
        raw = r.read()
    return gzip.decompress(raw).decode('utf-8', 'ignore')


def norm(syl):
    s = syl.strip().lower().translate(TONE)
    return ''.join(c for c in s if c.isalpha())


def main():
    print('下载 CC-CEDICT …')
    txt = fetch()
    print('  行数', len(txt.splitlines()))
    head_re = re.compile(r'^(\S+) (\S+) \[([^\]]+)\]')
    single = {}
    for line in txt.splitlines():
        if line.startswith('#'):
            continue
        m = head_re.match(line)
        if not m:
            continue
        trad, simp, py = m.group(1), m.group(2), m.group(3)
        if len(simp) != 1:
            continue
        first = py.split(' ')[0]
        syl = norm(first)
        if not syl:
            continue
        single.setdefault(simp, syl)
    print('  CC-CEDICT 单字注音', len(single), '字')

    chars = json.load(io.open(CHARS, encoding='utf-8'))
    ours = {}
    for syll, arr in chars.items():
        for ch in arr:
            if ch not in ours:
                ours[ch] = syll
    print('  我们的字表', len(ours), '字')

    diffs = [(ch, ours[ch], single[ch]) for ch in ours.keys() if ch in single and ours[ch] != single[ch]]
    diffs.sort()
    print()
    print('=== 主读音差异（前 20）===')
    print('| 字 | 我们的读音 | CC-CEDICT | 处理 |')
    print('|---|---|---|---|')
    for ch, a, b in diffs[:20]:
        act = '补读（两读并存）' if ch in ('爪',) else '待定（保留原读音）'
        print('| %s | %s | %s | %s |' % (ch, a, b, act))
    print()
    print('差异总数 %d / 共同覆盖 %d 字' % (len(diffs), len([c for c in ours if c in single])))
    print('爪 在差异里：', any(d[0] == '爪' for d in diffs))
    for d in diffs:
        if d[0] == '爪':
            print('  爪 ours=%s cedict=%s -> 已按 §13 第 5 步补读 zhua（两读并存）' % (d[1], d[2]))


if __name__ == '__main__':
    main()
