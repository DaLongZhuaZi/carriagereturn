# 拼音词库来源与许可（DICT-ATTRIBUTION）

由 tools/build-pinyin-dict.py 生成，生成时间 2026-11-08。

| 数据 | 来源 | 许可 | 版本／提交 | SHA-256 |
|---|---|---|---|---|
| 词表＋词频 | fxsjy/jieba jieba/dict.txt | MIT | dafc73425e61 | 7197c3211ddd98962b036cdf40324d1ea2bfaa12bd028e68faa70111a88e12a8 |
| 词组读音 | mozillazg/python-pinyin | MIT | pypinyin 0.55.0 | —— |
| 单字读音 | mozillazg/pinyin-data pinyin.txt（Unihan kMandarin） | Unicode License v3 | fe29ad32bdf3 | 2342a6f98c85dbc3c8d26aef31744876a36326c6466e51e9a0f16898c36c2011 |
| 现代词补全 | CC-CEDICT（MDBG 发布） | CC BY-SA 4.0 | —— | 8a506d01724a4f528db965bf3598efaf3be3ade121749f5c2730262996a80ad1 |
| 专名扩词 | thunlp/THUOCL（11 类，地名／人名／成语／医学／法律／诗词等） | MIT | f694ce779b2a | 533eba7b347d025cd08e3fcaac7172548e16e5c90439da5d2f1f4fe444ddfcfc |
| 官方地名 | modood/Administrative-divisions-of-China dist/pcas.json | WTFPL（非 OSI 认证，见其 LICENSE） | dc3a1d7acd85 | 7c5bf24d95056a78304ddb7e6261a260ddf29ec66daaea40c5297476c60baa20 |
| 全局词频（键排序） | wordfreq large_zh（334,609 词，仅构建期排序用，不进 App 数据） | CC BY-SA 4.0 | wordfreq（pip） | —— |
| 补录表＋HOT 置顶表 | 本项目人工维护（见 tools/build-pinyin-dict.py 的 SUPPLEMENT／HOT） | 与本项目同许可（MIT） | —— | —— |

合并后文件的许可：dict/pinyin-words.json 整体按 **CC BY-SA 4.0** 分发（它并入了 CC-CEDICT 的内容，是 CC-CEDICT 的衍生数据，按 BY-SA 须同许可共享；署名见上表）。其中 jieba／pypinyin／Unihan -derived 的部分各按其原许可（MIT／Unicode License v3）亦可单独使用；App 代码仍是 MIT（代码只是读数据文件，不构成数据的衍生作品）。
如需保住 MIT 主表干净（不与 BY-SA 混在一个文件里），须把词库拆成两个文件分发（主表 MIT＋扩展表 CC BY-SA 4.0），见设计稿 §16.5。

生成口径：
- 每词读音 = pypinyin 词组读音优先；取不到则用 pinyin-data 单字主读音拼接；CC-CEDICT 词用其自带读音（去声调，u:→v）。
- 只保留 1–4 字、全为汉字的词；jieba 按词频降序截前 80000 词；CC-CEDICT 全量并入（去重，排在 jieba 词之后）。
- THUOCL（157,172 条）与行政区划（29,560 条）全量并入（去重，依次排在 CC-CEDICT 之后）；多音字专名走白名单：人名源首字用姓氏读音（SURNAME_READINGS，单→shan 等 15 条），地名源整词覆写（PLACE_READINGS，六安→liuan 等 8 条）。
- 键排序：JSON 键按 wordfreq 全局词频（各键首词的频率）降序重排，键内词序不动——引擎的 wordRank 按键顺序生成，缩写候选按 wordRank 排，这样 nh 缩写里你好进前 9（v2 排第 14 的根因是 jieba 新闻语料偏）。wordfreq 不可用时跳过此步。
- HOT 置顶表：高频现代词提到各键首位（首次输入即排首位，之后由学习排序接管）。
- 输出：dict/pinyin-words.json（177615 键 / 251364 词 / 5.23 MB）与 dict/pinyin-chars.json（409 音节 / 20925 字 / 125.9 KB）。
- 未使用：rime-ice（GPL）、搜狗细胞词库、八股文（LGPL）。
