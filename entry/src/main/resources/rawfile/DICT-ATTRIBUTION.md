# 拼音词库来源与许可（DICT-ATTRIBUTION）

由 tools/build-pinyin-dict.py 生成，生成时间 2026-11-07。

| 数据 | 来源 | 许可 | 版本／提交 | SHA-256 |
|---|---|---|---|---|
| 词表＋词频 | fxsjy/jieba jieba/dict.txt | MIT | dafc73425e61 | 7197c3211ddd98962b036cdf40324d1ea2bfaa12bd028e68faa70111a88e12a8 |
| 词组读音 | mozillazg/python-pinyin | MIT | pypinyin 0.55.0 | —— |
| 单字读音 | mozillazg/pinyin-data pinyin.txt（Unihan kMandarin） | Unicode License v3 | fe29ad32bdf3 | 2342a6f98c85dbc3c8d26aef31744876a36326c6466e51e9a0f16898c36c2011 |

生成口径：
- 每词读音 = pypinyin 词组读音优先；取不到则用 pinyin-data 单字主读音拼接。
- 只保留 1–4 字、全为汉字的词；按 jieba 词频降序截前 80000 词。
- 输出：dict/pinyin-words.json（27958 键 / 80000 词 / 1.02 MB）与 dict/pinyin-chars.json（409 音节 / 20924 字 / 125.9 KB）。
- 未使用：rime-ice（GPL）、搜狗细胞词库、THUOCL／八股文、CC-CEDICT（v1.5 再说）。
