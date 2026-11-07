# 拼音词库来源与许可（DICT-ATTRIBUTION）

由 tools/build-pinyin-dict.py 生成，生成时间 2026-11-08。

| 数据 | 来源 | 许可 | 版本／提交 | SHA-256 |
|---|---|---|---|---|
| 词表＋词频 | fxsjy/jieba jieba/dict.txt | MIT | dafc73425e61 | 7197c3211ddd98962b036cdf40324d1ea2bfaa12bd028e68faa70111a88e12a8 |
| 词组读音 | mozillazg/python-pinyin | MIT | pypinyin 0.55.0 | —— |
| 单字读音 | mozillazg/pinyin-data pinyin.txt（Unihan kMandarin） | Unicode License v3 | fe29ad32bdf3 | 2342a6f98c85dbc3c8d26aef31744876a36326c6466e51e9a0f16898c36c2011 |
| 现代词补全 | CC-CEDICT（MDBG 发布） | CC BY-SA 4.0 | —— | 8a506d01724a4f528db965bf3598efaf3be3ade121749f5c2730262996a80ad1 |
| 补录表＋HOT 置顶表 | 本项目人工维护（见 tools/build-pinyin-dict.py 的 SUPPLEMENT／HOT） | 与本项目同许可（MIT） | —— | —— |

生成口径：
- 每词读音 = pypinyin 词组读音优先；取不到则用 pinyin-data 单字主读音拼接；CC-CEDICT 词用其自带读音（去声调，u:→v）。
- 只保留 1–4 字、全为汉字的词；jieba 按词频降序截前 80000 词；CC-CEDICT 全量并入（去重，排在 jieba 词之后）。
- HOT 置顶表：高频现代词提到各键首位（首次输入即排首位，之后由学习排序接管）。
- 输出：dict/pinyin-words.json（86035 键 / 145526 词 / 2.53 MB）与 dict/pinyin-chars.json（409 音节 / 20925 字 / 125.9 KB）。
- 未使用：rime-ice（GPL）、搜狗细胞词库、THUOCL／八股文。
