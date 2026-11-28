# 回车 CarriageReturn · rawfile 资源清单（ASSET-MANIFEST）

> 生成日期：2026-11-03 ｜ 维护：资源管线（asset-pipeline）
> 落位根：`entry/src/main/resources/rawfile/`
> 实测工具：vips 8.18.7（`vipsheader` 读尺寸、`vips thumbnail` / `vips jpegsave` 处理）；字节数为 `stat -c %s` 实测。
> 说明：本清单只记录实际进包的文件；未落位素材与排除理由见 §5。所有"目标字节 / 目标尺寸"均为落位后文件的实测值，未照抄任何文档中的预估数字。
>
> **2026-11-28（W4 零引用清理）**：§0–§7 是 2026-11-03 的初始落位记录，早于五机化与后续批次，部分文件（如 `machine/*-hero*.jpg`）已不在当前树。**当前实际进包清单与本次清理记录见 §8。**

## 0. 总览

| 目录 | 文件数 | 合计字节 | 说明 |
|---|---:|---:|---|
| `machine/` | 20 | 4,020,022 | 4 台机器 × hero + front + side + keyboard + carriage |
| `paper/` | 4 | 1,752,634 | 主用纸纹 4 张（信纸 / 稿纸 / 明信片 / 便签） |
| `font/` | 8 | 51,268,468 | 4 款字体 + 4 份协议原文 |
| `sound/pack/` | 24 | 205,675 | 23 个 .ogg + SOURCE.txt（9,031 B） |
| **素材合计** | **56** | **57,246,799** | 不含本清单与 `SOUND-ATTRIBUTION.md` |

## 1. `machine/` — 机器身体图

- 来源目录：`assets/images/machines/`
- 处理：`vips thumbnail` 等比缩放至长边 ≤ **1536px**，再 `vips jpegsave --Q 86`；保持宽高比、不裁切（仅整数像素舍入，最长边严格 ≤1536）。
- 源图合计 56,723,290 B → 目标合计 4,020,022 B（下降约 92.9%）。
- 命名契约：1920s 默认机 hero 保持 `1920s-upright-hero-3q.jpg`；其余三台 hero 为 `1930s-portable-hero.jpg` / `1950s-streamlined-hero.jpg` / `1960s-electric-hero.jpg`（与 `MachineCatalog.ets` 的 `heroRawfile` 一致）。

| 源路径（仓库） | 目标路径（rawfile 内） | 源尺寸 | 源字节 | 目标尺寸 | 目标字节 | 协议 | 需署名 |
|---|---|---|---:|---|---:|---|---|
| assets/images/machines/1920s-upright-carriage.jpg | machine/1920s-upright-carriage.jpg | 2400×1792 | 2,211,548 | 1536×1147 | 201,130 | 项目自有（AI 生成） | 否 |
| assets/images/machines/1920s-upright-front.jpg | machine/1920s-upright-front.jpg | 2400×1792 | 2,638,480 | 1536×1147 | 221,237 | 项目自有（AI 生成） | 否 |
| assets/images/machines/1920s-upright-hero-3q.jpg | machine/1920s-upright-hero-3q.jpg | 2048×2048 | 2,658,760 | 1536×1536 | 316,454 | 项目自有（AI 生成） | 否 |
| assets/images/machines/1920s-upright-keyboard.jpg | machine/1920s-upright-keyboard.jpg | 2400×1792 | 3,152,658 | 1536×1147 | 347,902 | 项目自有（AI 生成） | 否 |
| assets/images/machines/1920s-upright-side.jpg | machine/1920s-upright-side.jpg | 2400×1792 | 2,401,251 | 1536×1147 | 170,948 | 项目自有（AI 生成） | 否 |
| assets/images/machines/1930s-portable-carriage.jpg | machine/1930s-portable-carriage.jpg | 2752×1536 | 2,507,558 | 1536×857 | 170,802 | 项目自有（AI 生成） | 否 |
| assets/images/machines/1930s-portable-front.jpg | machine/1930s-portable-front.jpg | 2752×1536 | 3,026,832 | 1536×857 | 211,578 | 项目自有（AI 生成） | 否 |
| assets/images/machines/1930s-portable-hero.jpg | machine/1930s-portable-hero.jpg | 2752×1536 | 3,115,212 | 1536×857 | 224,232 | 项目自有（AI 生成） | 否 |
| assets/images/machines/1930s-portable-keyboard.jpg | machine/1930s-portable-keyboard.jpg | 2752×1536 | 3,699,019 | 1536×857 | 348,107 | 项目自有（AI 生成） | 否 |
| assets/images/machines/1930s-portable-side.jpg | machine/1930s-portable-side.jpg | 2752×1536 | 3,023,792 | 1536×857 | 207,793 | 项目自有（AI 生成） | 否 |
| assets/images/machines/1950s-streamlined-carriage.jpg | machine/1950s-streamlined-carriage.jpg | 2752×1536 | 2,625,118 | 1536×857 | 126,178 | 项目自有（AI 生成） | 否 |
| assets/images/machines/1950s-streamlined-front.jpg | machine/1950s-streamlined-front.jpg | 2752×1536 | 2,607,461 | 1536×857 | 126,573 | 项目自有（AI 生成） | 否 |
| assets/images/machines/1950s-streamlined-hero.jpg | machine/1950s-streamlined-hero.jpg | 2752×1536 | 2,818,861 | 1536×857 | 146,830 | 项目自有（AI 生成） | 否 |
| assets/images/machines/1950s-streamlined-keyboard.jpg | machine/1950s-streamlined-keyboard.jpg | 2752×1536 | 2,783,936 | 1536×857 | 170,555 | 项目自有（AI 生成） | 否 |
| assets/images/machines/1950s-streamlined-side.jpg | machine/1950s-streamlined-side.jpg | 2752×1536 | 2,638,318 | 1536×857 | 102,772 | 项目自有（AI 生成） | 否 |
| assets/images/machines/1960s-electric-carriage.jpg | machine/1960s-electric-carriage.jpg | 2752×1536 | 2,023,452 | 1536×857 | 124,394 | 项目自有（AI 生成） | 否 |
| assets/images/machines/1960s-electric-front.jpg | machine/1960s-electric-front.jpg | 2752×1536 | 3,139,427 | 1536×857 | 190,022 | 项目自有（AI 生成） | 否 |
| assets/images/machines/1960s-electric-hero.jpg | machine/1960s-electric-hero.jpg | 2752×1536 | 3,174,060 | 1536×857 | 187,071 | 项目自有（AI 生成） | 否 |
| assets/images/machines/1960s-electric-keyboard.jpg | machine/1960s-electric-keyboard.jpg | 2752×1536 | 3,476,032 | 1536×857 | 274,133 | 项目自有（AI 生成） | 否 |
| assets/images/machines/1960s-electric-side.jpg | machine/1960s-electric-side.jpg | 2752×1536 | 3,001,515 | 1536×857 | 151,311 | 项目自有（AI 生成） | 否 |

- 未落位：`assets/images/machines/1920s-upright-views-2x2.jpg`（拼版图，任务书明确排除）。

## 2. `paper/` — 纸面底纹

- 来源目录：`assets/images/papers/`（**只取主用 4 张**，见 `PAPERS-README.md`）
- 处理：长边 ≤ **2048px**（四张原图均未超过，**未缩放**）；统一 `vips jpegsave --Q 88` 重编码优化体积。保持宽高比、不裁切。
- 源图合计 4,080,005 B → 目标合计 1,752,634 B（下降约 57.0%）。
- 格线、边距、红格、页眉一律不 baked 进纹理，由代码层绘制（`docs/风格板设计稿.md` §4）。

| 源路径（仓库） | 目标路径（rawfile 内） | 源尺寸 | 源字节 | 目标尺寸 | 目标字节 | 协议 | 需署名 |
|---|---|---|---:|---|---:|---|---|
| assets/images/papers/paper-letter.jpg | paper/paper-letter.jpg | 2048×2048 | 2,636,283 | 2048×2048 | 555,126 | 项目自有（AI 生成） | 否 |
| assets/images/papers/paper-manuscript.jpg | paper/paper-manuscript.jpg | 1600×1600 | 417,078 | 1600×1600 | 361,458 | 项目自有（AI 生成） | 否 |
| assets/images/papers/paper-postcard.jpg | paper/paper-postcard.jpg | 1920×1280 | 626,527 | 1920×1280 | 520,236 | 项目自有（AI 生成） | 否 |
| assets/images/papers/paper-memo.jpg | paper/paper-memo.jpg | 1600×1600 | 400,117 | 1600×1600 | 315,814 | 项目自有（AI 生成） | 否 |

## 3. `font/` — 纸面字体与协议原文

- 来源目录：`assets/fonts/app/`。四款源文件名与目标名**完全一致**（已逐字节复制，未改名）：
  - `courier-prime/CourierPrime-Regular.ttf` → `font/CourierPrime-Regular.ttf`
  - `special-elite/SpecialElite-Regular.ttf` → `font/SpecialElite-Regular.ttf`
  - `noto-serif-sc/NotoSerifSC-wght.ttf` → `font/NotoSerifSC-wght.ttf`
  - `lxgw-wenkai/LXGWWenKai-Regular.ttf` → `font/LXGWWenKai-Regular.ttf`
- 协议：四款均为 **SIL Open Font License 1.1**，允许嵌入 App；须随附协议原文、不得单独售卖字体文件、修改版须沿用 OFL 且不得使用保留字（Noto / 霞鹜 / LXGW 等）。
- 阶段：阶段 1 只注册 Courier Prime；Special Elite 为阶段 2/3 备料；Noto Serif SC 与 LXGW WenKai 为中文通道（阶段 2/3）备料。

| 源路径（仓库） | 目标路径（rawfile 内） | 源尺寸 | 源字节 | 目标尺寸 | 目标字节 | 协议 | 需署名 |
|---|---|---|---:|---|---:|---|---|
| assets/fonts/app/courier-prime/CourierPrime-Regular.ttf | font/CourierPrime-Regular.ttf | — | 71,188 | — | 71,188 | SIL OFL 1.1 | 否（须随附协议原文） |
| assets/fonts/app/lxgw-wenkai/LXGWWenKai-Regular.ttf | font/LXGWWenKai-Regular.ttf | — | 25,928,940 | — | 25,928,940 | SIL OFL 1.1 | 否（须随附协议原文） |
| assets/fonts/app/noto-serif-sc/NotoSerifSC-wght.ttf | font/NotoSerifSC-wght.ttf | — | 25,125,512 | — | 25,125,512 | SIL OFL 1.1 | 否（须随附协议原文） |
| assets/fonts/app/special-elite/SpecialElite-Regular.ttf | font/SpecialElite-Regular.ttf | — | 117,064 | — | 117,064 | SIL OFL 1.1 | 否（须随附协议原文） |
| assets/fonts/app/courier-prime/OFL.txt | font/CourierPrime-LICENSE.txt | — | 4,495 | — | 4,495 | 协议原文（SIL OFL 1.1） | 否 |
| assets/fonts/app/lxgw-wenkai/OFL.txt | font/LXGWWenKai-LICENSE.txt | — | 5,265 | — | 5,265 | 协议原文（SIL OFL 1.1） | 否 |
| assets/fonts/app/noto-serif-sc/OFL.txt | font/NotoSerifSC-LICENSE.txt | — | 4,444 | — | 4,444 | 协议原文（SIL OFL 1.1） | 否 |
| assets/fonts/app/special-elite/LICENSE.txt | font/SpecialElite-LICENSE.txt | — | 11,560 | — | 11,560 | 协议原文（SIL OFL 1.1） | 否 |

### 3.1 包体代价核算（字体）

| 文件 | 字节 | MiB | 阶段 | 备注 |
|---|---:|---:|---|---|
| `CourierPrime-Regular.ttf` | 71,188 | 0.07 | 阶段 1 | 英文默认打字机体，体积极小 |
| `SpecialElite-Regular.ttf` | 117,064 | 0.11 | 阶段 2/3 | 英文做旧打字机体，仅 Regular |
| `NotoSerifSC-wght.ttf` | 25,125,512 | 23.96 | 阶段 2/3 | 中文宋体全量，**单文件约 24MB** |
| `LXGWWenKai-Regular.ttf` | 25,928,940 | 24.73 | 阶段 2/3 | 中文楷体全量，**单文件约 24.7MB** |
| 4 份协议原文 | 25,764 | 0.02 | 随字体 | 4 份 OFL/LICENSE 原文 |
| **合计** | **51,268,468** | **48.89** | — | 占 rawfile 素材总量（57,246,799 B）的 89.6% |

- **结论：中文字体全量两件合计 51,054,452 B（48.69 MiB），占 rawfile 素材总量 89.2%；阶段 1 只需 Courier Prime（71,188 B）。** 阶段 2/3 上中文字体前，须评估包体预算；若超标，按 `docs/风格板设计稿.md` §3 走子集化 fallback（OFL 允许子集化）。

## 4. `sound/pack/` — 音效包

- 来源目录：`assets/sounds/pack/`（23 个 .ogg，文件名不变，逐字节复制）
- 来源与协议：见同目录 `SOURCE.txt`（BigSoundBank 3 件 CC0 + Freesound 8 件：5 件 CC0 / 2 件 CC BY / 1 件作者声明 public domain）；逐件署名见根目录 `SOUND-ATTRIBUTION.md`。
- 合计 196,644 B（v1 预算 <2MB，用量约 9%）；全部为单声道 44.1kHz OGG Vorbis。

| 目标路径（rawfile 内） | 字节 | 时长 | 来源（作者 / 标题） | 协议 |
|---|---:|---:|---|---|
| sound/pack/bell-01.ogg | 11,208 | 0.890s | ramsamba / Typewriter Bell.wav | CC0 |
| sound/pack/bell-02.ogg | 11,924 | 1.232s | Joseph SARDIN / Typewriter, Bell #1 | CC0 |
| sound/pack/bell-03.ogg | 9,488 | 1.013s | MasterNavigator / typewriter bell | CC0 |
| sound/pack/carriage-reset-01.ogg | 27,933 | 2.679s | knufds / Typewriter bell & carriage reset | CC0 |
| sound/pack/key-01.ogg | 8,185 | 0.464s | Joseph SARDIN / Typewriter #5 | CC0 |
| sound/pack/key-02.ogg | 6,104 | 0.210s | Joseph SARDIN / Typewriter #5 | CC0 |
| sound/pack/key-03.ogg | 6,696 | 0.249s | Joseph SARDIN / Typewriter #5 | CC0 |
| sound/pack/key-04.ogg | 6,529 | 0.254s | Joseph SARDIN / Typewriter #5 | CC0 |
| sound/pack/key-05.ogg | 7,539 | 0.384s | Joseph SARDIN / Typewriter #5 | CC0 |
| sound/pack/key-06.ogg | 7,767 | 0.464s | Joseph SARDIN / Typewriter #5 | CC0 |
| sound/pack/key-07.ogg | 7,678 | 0.464s | Joseph SARDIN / Typewriter #5 | CC0 |
| sound/pack/key-08.ogg | 6,542 | 0.254s | Joseph SARDIN / Typewriter #5 | CC0 |
| sound/pack/key-09.ogg | 8,489 | 0.464s | Joseph SARDIN / Typewriter #5 | CC0 |
| sound/pack/key-10.ogg | 8,422 | 0.464s | Joseph SARDIN / Typewriter #5 | CC0 |
| sound/pack/key-11.ogg | 5,862 | 0.180s | Joseph SARDIN / Typewriter #5 | CC0 |
| sound/pack/key-12.ogg | 8,276 | 0.464s | Joseph SARDIN / Typewriter #5 | CC0 |
| sound/pack/key-alt-01.ogg | 4,729 | 0.090s | ddohler / Typewriter.wav | CC BY（需署名） |
| sound/pack/key-transient.ogg | 4,980 | 0.117s | BMacZero / typewriter.wav | CC0 |
| sound/pack/pack2-key-01.ogg | 5,782 | 0.190s | lyricalgirl / Old typewriter | CC0 |
| sound/pack/pack2-key-02.ogg | 9,482 | 0.614s | lyricalgirl / Old typewriter | CC0 |
| sound/pack/pack2-key-03.ogg | 5,856 | 0.210s | lyricalgirl / Old typewriter | CC0 |
| sound/pack/pack2-key-04.ogg | 9,770 | 0.614s | lyricalgirl / Old typewriter | CC0 |
| sound/pack/space-01.ogg | 7,403 | 0.344s | Joseph SARDIN / Typewriter, space | CC0 |

> `SOURCE.txt` 另在包内，含来源链接、协议快照日期（2026-11-03）与 23 个文件的 SHA-256 实测值。

## 5. 未落位清单（明确排除）

| 源路径 | 原因 |
|---|---|
| `assets/images/machines/1920s-upright-views-2x2.jpg` | 拼版图，任务书明确排除（单视图已齐） |
| `assets/images/papers/paper-letter-procedural.jpg` 等 4 张 `*-procedural.jpg` | `PAPERS-README.md`：已降级为备用底色，非主用 |
| `assets/images/papers/cc0-paper001-color.jpg` | CC0 备用纹理，非本批主用 |
| `assets/images/papers/paper001-2k.zip` | 原始下载压缩包，不进包 |
| `assets/images/papers/gen-paper-textures.py` | 生成脚本，不进包 |
| `assets/images/papers/media-generation-*.json` 3 个 | 生图元数据，不进包 |
| `assets/images/animation/**`（含 2 张 `typebar-hero-edit-layer-*-draft.png`） | 阶段 1 不做动画层；两张 draft 明确禁用，全部不落位 |
| `assets/sounds/bigsoundbank/*.wav` | 原始 WAV（12.6MB 等），不进包；已切分并转码为 OGG 进包 |
| `assets/sounds/freesound/*.wav` 与 `*.mp3` | 原始素材，不进包；切分后的 OGG 在 `sound/pack/` |
| `assets/fonts/app/` 其余 13 款字体 | 非首发契约字体，不落位 |
| `assets/fonts/downloaded/**` | 下载副本/中间物，不落位 |

## 6. 协议与署名汇总

| 类别 | 协议 | 是否需署名 | 依据 |
|---|---|---|---|
| `machine/` | 项目自有 AI 生成图（开发期产出） | 否 | `docs/素材调研报告.md` §一；机器为虚构时代机，文件名/路径无品牌名 |
| `paper/` | 项目自有 AI 生成图（Gemini / 自有生图工具） | 否 | `assets/images/papers/PAPERS-README.md` |
| `font/` | SIL OFL 1.1（4 款） | 否（须随附协议原文；不得单卖；改版守保留字） | 各字体目录内 OFL.txt / LICENSE.txt 原文已随包 |
| `sound/pack/` | CC0（22 个 .ogg）+ CC BY（1 个 .ogg，ddohler） | **CC BY 件需署名**；CC0 件否 | `assets/sounds/*/SOURCE.txt`；详见 `SOUND-ATTRIBUTION.md` |

## 7. 验收记录（本机实测，2026-11-03）

1. 目录与文件数：`find entry/src/main/resources/rawfile -type f` 实测 `machine/ 20`、`paper/ 4`、`font/ 8`、`sound/pack/ 24`（23 ogg + SOURCE.txt）。
2. 文件名集合：`machine/` + `paper/` 的 24 个文件名与 `MachineCatalog.ets` 契约逐一 diff —— **IMAGE NAME SET: OK (24/24)**。
3. 尺寸复读（`vipsheader`，全部通过）：
   - 1920s 五张：hero `1536×1536`；front/side/keyboard/carriage `1536×1147`。
   - 1930s / 1950s / 1960s 各五张：`1536×857`。
   - paper-letter `2048×2048`；paper-manuscript `1600×1600`；paper-postcard `1920×1280`；paper-memo `1600×1600`。
   - 全部机器图与纸纹长边 ≤1536 / ≤2048，符合压缩约束。
4. 禁止项扫描：`find rawfile -iname '*draft*' -o -iname '*procedural*' -o -iname '*placeholder*' -o -iname 'views-2x2*' -o -iname '*.zip' -o -iname '*.py'` **无输出**（无占位、无草稿、无 procedural 纸纹）。
5. 文件类型抽检：机器图为 `JPEG image data ... 1536x1536`；字体为 `TrueType Font data`；音效为 `Ogg data, Vorbis audio, mono, 44100 Hz`。
6. 逐字节一致性：4 个字体文件、4 份协议原文、23 个 .ogg 与 `assets/` 源文件 `cmp` 全部相同（23/23 SAME）。
7. `.gitignore`：`git check-ignore -v entry/src/main/resources/rawfile/machine/1920s-upright-hero-3q.jpg` 退出码 1（**未被忽略，会被 git 跟踪**）；本任务不修改 .gitignore，进仓方式待用户定（见交付回报）。

## 8. 当前进包清单与 W4 零引用清理（2026-11-28）

### 8.1 当前 `rawfile/` 实际进包（W4 后，`find`＋`stat` 实测）

| 目录 | 文件数 | 字节 | MiB |
|---|---:|---:|---:|
| `（根：本清单＋2 份署名文件）` | 3 | 27,439 | 0.03 |
| `dict/` | 3 | 7,893,399 | 7.53 |
| `dossiers/` | 4 | 950,520 | 0.91 |
| `font/` | 38 | 76,624,294 | 73.07 |
| `keyboard/` | 1 | 1,085 | 0.00 |
| `keymap/` | 5 | 51,923 | 0.05 |
| `layers/` | 4 | 5,063,251 | 4.83 |
| `machine/` | 20 | 4,735,607 | 4.52 |
| `paper/` | 4 | 1,752,634 | 1.67 |
| `sound/` | 87 | 712,849 | 0.68 |
| `typebar/` | 4 | 2,766,494 | 2.64 |
| `ui-parts/` | 34 | 27,613,481 | 26.33 |
| **合计** | **207** | **128,192,976** | **122.25** |

- 清理前：297 文件 / 241,462,526 B（230.28 MiB）；本次出包 90 文件 / 113,269,550 B（108.02 MiB）。
- debug signed HAP：**250,557,000 B → 137,273,392 B**（−113,283,608 B，−45.2%）。
- 口径：按 `entry/src/main/ets/**/*.ets|ts`、`entry/src/main/resources/base/**`、`tools/**`、`docs/**` 全量复核 basename／相对路径；并计入动态拼串 `machine/<kind>-{front,side,keyboard,carriage}.jpg`（5 机）与 `ui-parts/tile-<slug>-{paperwell,base,keybed}.png`，以及 `sound/` 运行时目录列举。字体协议原文按 OFL 要求继续随包，不在清理范围。

### 8.2 移出 HAP：契约样张 → `tools/contract-assets/`（38 文件，39,012,230 B / 37.20 MiB）

只被 `tools/check-part-colors.py`／`check-part-grain.py` 与 `PartContract.ets` 取样引用、不参与 App 渲染。**文件未删除、未改像素**，仅换位置；`check-part-colors.py` 改为「rawfile → `tools/contract-assets/`」顺序查找，`check-part-grain.py` 两处取并集，检查范围不变。

| 文件 | 字节 | MiB |
|---|---:|---:|
| `ui-parts/basket-fan-1920s.png` | 1,664,285 | 1.59 |
| `ui-parts/keycap-face-1920s.png` | 248,408 | 0.24 |
| `ui-parts/keycap-face-1930s.png` | 259,803 | 0.25 |
| `ui-parts/keycap-face-1950s.png` | 288,405 | 0.28 |
| `ui-parts/keycap-face-1960s.png` | 204,703 | 0.20 |
| `ui-parts/keycap-face-round-1920s.png` | 804,573 | 0.77 |
| `ui-parts/keycap-face-round-1930s.png` | 1,384,363 | 1.32 |
| `ui-parts/keycap-face-round-1950s.png` | 717,430 | 0.68 |
| `ui-parts/keycap-face-round-1960s.png` | 462,020 | 0.44 |
| `ui-parts/keycap-pressed-1920s.png` | 261,989 | 0.25 |
| `ui-parts/keycap-pressed-1930s.png` | 268,655 | 0.26 |
| `ui-parts/keycap-pressed-1950s.png` | 301,321 | 0.29 |
| `ui-parts/keycap-pressed-1960s.png` | 224,578 | 0.21 |
| `ui-parts/keycap-pressed-round-1920s.png` | 776,168 | 0.74 |
| `ui-parts/keycap-pressed-round-1930s.png` | 1,347,581 | 1.29 |
| `ui-parts/keycap-pressed-round-1950s.png` | 687,582 | 0.66 |
| `ui-parts/keycap-pressed-round-1960s.png` | 453,204 | 0.43 |
| `ui-parts/lever.png` | 250,661 | 0.24 |
| `ui-parts/paper-cream-v1.png` | 2,690,566 | 2.57 |
| `ui-parts/paper-cream-v2.png` | 3,080,358 | 2.94 |
| `ui-parts/paper-cream-v3.png` | 4,033,288 | 3.85 |
| `ui-parts/paper-cream-v4.png` | 4,073,371 | 3.88 |
| `ui-parts/paper-curl-v2.png` | 420,711 | 0.40 |
| `ui-parts/paper-curl-v3.png` | 418,862 | 0.40 |
| `ui-parts/paper-curl.png` | 623,117 | 0.59 |
| `ui-parts/paper-letter.png` | 3,127,182 | 2.98 |
| `ui-parts/paper-manuscript.png` | 2,134,195 | 2.04 |
| `ui-parts/paper-memo.png` | 2,339,175 | 2.23 |
| `ui-parts/paper-postcard.png` | 3,158,570 | 3.01 |
| `ui-parts/ruler.png` | 220,522 | 0.21 |
| `ui-parts/spacebar-face-1920s.png` | 164,192 | 0.16 |
| `ui-parts/spacebar-face-1930s.png` | 120,523 | 0.11 |
| `ui-parts/spacebar-face-1950s.png` | 200,643 | 0.19 |
| `ui-parts/spacebar-face-1960s.png` | 315,401 | 0.30 |
| `ui-parts/spacebar-face-round-1920s.png` | 229,083 | 0.22 |
| `ui-parts/spacebar-face-round-1930s.png` | 357,384 | 0.34 |
| `ui-parts/spacebar-face-round-1950s.png` | 398,584 | 0.38 |
| `ui-parts/spacebar-face-round-1960s.png` | 300,774 | 0.29 |

### 8.3 运行时零引用、已删除（52 文件，74,257,320 B / 70.82 MiB）

历史批次作废件／死组件素材；全量复核后无代码、工具或动态拼串引用。文件可从 `backup/w4-pre-cleanup` 分支或 git 历史恢复。

| 文件 | 字节 | MiB |
|---|---:|---:|
| `machine/2020s-modern-hero.jpg` | 296,337 | 0.28 |
| `machine/2020s-modern-keyarea.jpg` | 452,227 | 0.43 |
| `typebar/1920s-carriage-layer.png` | 1,772,070 | 1.69 |
| `typebar/1920s-lever-single.png` | 689,741 | 0.66 |
| `typebar/1920s-typebar-single.png` | 533,567 | 0.51 |
| `typebar/1930s-portable-carriage-layer.png` | 1,706,192 | 1.63 |
| `typebar/1930s-portable-lever-single.png` | 504,088 | 0.48 |
| `typebar/1950s-streamlined-carriage-layer.png` | 1,523,631 | 1.45 |
| `typebar/1950s-streamlined-lever-single.png` | 350,701 | 0.33 |
| `typebar/1960s-electric-carriage-layer.png` | 824,515 | 0.79 |
| `typebar/1960s-electric-lever-single.png` | 494,163 | 0.47 |
| `ui-parts/basket-fan-1930s.png` | 2,201,393 | 2.10 |
| `ui-parts/basket-fan-1950s.png` | 2,682,093 | 2.56 |
| `ui-parts/basket-fan-1960s.png` | 2,527,634 | 2.41 |
| `ui-parts/basket-fan-3d-v2.png` | 849,879 | 0.81 |
| `ui-parts/basket-fan-3d-v3.png` | 2,556,574 | 2.44 |
| `ui-parts/basket-fan-3d-v4.png` | 2,693,464 | 2.57 |
| `ui-parts/basket-fan-3d-v5-wide-1920s.png` | 2,528,271 | 2.41 |
| `ui-parts/basket-fan-3d-v5-wide-1930s.png` | 2,665,263 | 2.54 |
| `ui-parts/basket-fan-3d-v5-wide-1950s.png` | 2,567,197 | 2.45 |
| `ui-parts/basket-fan-3d-v5-wide-1960s.png` | 2,572,561 | 2.45 |
| `ui-parts/basket-fan-3d-v5-wide-20.png` | 2,569,349 | 2.45 |
| `ui-parts/basket-fan-3d-v5-wide-23.png` | 2,302,449 | 2.20 |
| `ui-parts/basket-fan-3d-v5-wide-26.png` | 2,418,652 | 2.31 |
| `ui-parts/basket-fan-3d.png` | 864,396 | 0.82 |
| `ui-parts/basket-fan-metal-1920s.png` | 2,500,518 | 2.38 |
| `ui-parts/basket-fan-metal-1930s.png` | 2,290,589 | 2.18 |
| `ui-parts/basket-fan-metal-1950s.png` | 2,587,508 | 2.47 |
| `ui-parts/basket-fan-metal-1960s.png` | 2,329,345 | 2.22 |
| `ui-parts/bell-brass-v1.png` | 1,118,549 | 1.07 |
| `ui-parts/cap3d-return.png` | 200,975 | 0.19 |
| `ui-parts/carriage-lever-v2.png` | 777,418 | 0.74 |
| `ui-parts/carriage-lever.png` | 29,337 | 0.03 |
| `ui-parts/fanwell-back-v1.png` | 33,291 | 0.03 |
| `ui-parts/fanwell-back-v2.png` | 31,155 | 0.03 |
| `ui-parts/keywell-floor-v1.png` | 50,910 | 0.05 |
| `ui-parts/keywell-floor-v2.png` | 59,726 | 0.06 |
| `ui-parts/knob-disc-v2.png` | 1,699,967 | 1.62 |
| `ui-parts/knob-metal-v2.png` | 2,227,687 | 2.12 |
| `ui-parts/knob-side-v1.png` | 889,221 | 0.85 |
| `ui-parts/lid-sheen-v1.png` | 62,631 | 0.06 |
| `ui-parts/plate-brass-blank-v1.png` | 997,783 | 0.95 |
| `ui-parts/platen-roller-v1.png` | 1,189,989 | 1.13 |
| `ui-parts/ribbon-strip.png` | 1,172,617 | 1.12 |
| `ui-parts/tile-1920s-base-v2.png` | 2,383,815 | 2.27 |
| `ui-parts/tile-1930s-base-v2.png` | 2,499,890 | 2.38 |
| `ui-parts/tile-1950s-base-v2.png` | 3,367,163 | 3.21 |
| `ui-parts/tile-1960s-base-v2.png` | 3,182,090 | 3.03 |
| `ui-parts/typebar-1920s.png` | 285,977 | 0.27 |
| `ui-parts/typebar-1930s.png` | 395,253 | 0.38 |
| `ui-parts/typebar-1950s.png` | 295,742 | 0.28 |
| `ui-parts/typebar-1960s.png` | 451,767 | 0.43 |

### 8.4 验真（本机实测，2026-11-28）

1. 构建：`hvigorw --mode module -p module=entry@default -p product=default -p buildMode=debug assembleHap` → **BUILD SUCCESSFUL**（清理前后各一次）。
2. HAP 内容核对：清理后 signed HAP 内 `resources/rawfile/` 无上表删除项（抽检 `knob-metal-v2`／`tile-1920s-base-v2`／`1920s-carriage-layer`／`2020s-modern-hero` 均 0 命中）；保留项（`paper-cream-v5`／`cap3d-1920s-matte`／`1920s-typebar-vertical`／`2020s-modern-front`／`tile-1920s-keybed`）均在包内。
3. 契约工具：`check-part-grain.py` 40 件 PASS；`check-part-colors.py` 的 4 件金属件 FAIL（横尺 30.4%／字篮 34.2%／拨杆 62.1%／旋钮 25.0%）为清理前既有偏差（`docs/自检记录.md` 第 4202／4225 行已记录），非本次引入；查找路径已覆盖 `tools/contract-assets/`。
4. 静态守卫：字体协议原文全部保留（OFL 要求随包）。
