# 新增字体下载清单（2026-11-03，用户令“都下载一遍”后实采）

落点：`assets/fonts/downloaded/`（字体文件）与 `assets/fonts/samples/`（效果样张）。
样张统一渲染在真实稿纸纹理上（OPPO Sans 为界面字体，用白底）。
注意：本目录尚未进仓库同步记录，开工建项目时再定进仓方式（与 assets/ 素材目录同例）。

## 已留（2026-11-03 19:58 用户定）

- Xanh Mono、IM Fell English、Homemade Apple 三款留下，进入项目字体集候选。

## 手写体取舍（2026-11-03 20:05 用户定：除仓耳小丸子外全留）

- 留下：Caveat、Kalam、Patrick Hand、Shadows Into Light、志莽行书、
  马善政毛笔体、龙藏体（7 款，进入项目字体集候选）。
- 未留：仓耳小丸子（文件保留作比对档案，不进项目字体集）。
- 至此项目字体集候选共 10 款：上述 3 款 + 手写体 7 款；首发 4 款
  （Courier Prime、Special Elite、宋体、LXGW WenKai）仍待宋体二选一后下载。

## App 字体集（2026-11-03 20:08 用户令“确认好版权、允许的都先放进”）

- 落点：`assets/fonts/app/`，共 18 款、83.1 MB，每款随附协议原文，
  全部 PIL 加载验真。索引见 `assets/fonts/app/FONTS-APP.md`。
- 两处版权纠正（此前记录有误）：① Homemade Apple 不是 OFL——它在
  google/fonts 的 apache/ 目录下，协议是 Apache 2.0（这正是此前 OFL.txt
  始终取不到的原因）；已改用官方 apache/ 文件（110,004B）+ LICENSE.txt
  入集。② Special Elite 也不是 OFL——同样在 apache/ 目录下，协议是
  Apache 2.0（作者 Brian J. Bonislawsky / Astigmatic，2010）；此前素材调研
  报告里“次级页面误标 Apache、以随包 OFL.txt 为准”写反了，正确的是
  Apache 标法，OFL 说法作废；该报告的这一行待后续推送时一并修正。
- OPPO Sans 已入集但带注：官方四条（不改编、不售卖、不提供下载渠道、
  不违法）未明文写“嵌入 App”；嵌入 HAP 不触四条中的任何一条，按条款
  字面可进；注记已写进 `app/oppo-sans/TERMS.txt`，求最稳可在上线前再向
  OPPO 确认嵌入口径。
- 宋体已定 Noto Serif SC（2026-11-03 20:23 用户定）；思源宋体同源同协议，
  正式定稿时换文件即可，App 侧无需改动。
- 未入集：仓耳小丸子（虽也允许，但用户 20:05 明确排除；若“都”包括它，
  一句话即可补进）；OPPO Sans（虽也允许，但用户 20:19 以不好看为由排除，
  已从 app/ 集移除，文件留下载存档）。app/ 集现为 17 款、74.3 MB。

## 中文字体重查（2026-11-03 19:58 用户令重查来源与声明，逐包核对原文）

- 朱雀仿宋：来源疑点已闭合——官方仓（TrionesType/zhuque，2026-11-03 克隆）的
  LICENSE.txt 与镜像文件随附的 LICENSE.txt 逐字一致，均为
  “Copyright (c) 2023, Zhejiang JadeFoci Techonology Co. LTD” + OFL 1.1；
  官方 README 明文允许免费商用、包括软件嵌入。残余说明：官方 Releases
  页仍为空，TTF 无法与官方发布二进制做哈希比对，但协议出处已实锤；
  另官方恳请正式版前不要大量传播非朱雀团队修改的版本——我们原样使用，
  不触此条。
- Noto Serif SC：Google Fonts 官方仓 OFL.txt，Copyright 2012 Google Inc.，
  OFL 1.1，无保留字名条款，打包无额外限制。
- 思源宋体 Source Han Serif SC：Adobe 官方仓 release 分支 LICENSE.txt，
  Copyright 2017-2022 Adobe，OFL 1.1，保留字名 'Source'（仅约束改版改名，
  原样打包不受影响）。
- 霞鹜文楷 LXGW WenKai：官方仓 OFL.txt，Copyright 2021-2026 LXGW，
  OFL 1.1，保留字名 '霞鹜'/'霞鶩'/'落霞孤鹜'/'落霞孤鶩'/'LXGW'，另有
  附加许可允许为网络投递做子集化/转格式（仅限网络字体投递，不作可安装
  桌面字体）；原样全量打包不受保留字名限制。
- 结论：Noto Serif SC 与思源宋体同源同协议，选哪个都不影响合规，纯看取用
  方便；四款中文字体至此来源与声明全部闭合。

## 手写体（2026-11-03 19:58 用户令多找，样张渲在便签纸纹理上）

- 拉丁手写（Google Fonts OFL 1.1，随包 OFL.txt 已验）：Caveat（113KB，
  经 Fontsource 取文件）、Kalam（427KB）、Patrick Hand（215KB）、
  Shadows Into Light（29KB，经 Fontsource 取文件）。
- 中文毛笔手写（Google Fonts OFL 1.1，随包 OFL.txt 已验）：志莽行书
  （4.1MB）、马善政毛笔体（5.9MB）、龙藏体（5.2MB）。
- 中文圆润手写感（仓耳免费商用，官网直链下载）：仓耳小丸子（1.3MB，
  圆润可爱风，非连笔手写）。
- 排除：站酷小薇LOGO体——作者声明禁嵌入式用途（软件、APP），且本身是
  LOGO 展示体而非手写正文体；日系手写体（Yuji 系列）与繁体手写体
  （芫荽、辰宇落雁體）因简体覆盖缺口未列入样张。

## 纸面英文（SIL OFL 1.1，随包 OFL.txt 已验真，Google Fonts 官方仓库）

| 字体 | 文件 | 大小 | 字重/样式 |
|---|---|---|---|
| Xanh Mono | xanhmono/XanhMono-Regular.ttf、XanhMono-Italic.ttf | 60KB、64KB | Regular、Italic |
| Anonymous Pro | anonymouspro/AnonymousPro-{Regular,Bold,Italic,BoldItalic}.ttf | 约 142–158KB | 4 款 |
| IM Fell English | imfellenglish/IMFeENrm28P.ttf、IMFeENit28P.ttf | 195KB、202KB | Roman、Italic |
| Space Mono | spacemono/SpaceMono-{Regular,Bold,Italic,BoldItalic}.ttf | 约 98–121KB | 4 款 |

## 纸面英文（OFL 家族，但随包 OFL.txt 未能从 google/fonts 取到，装包前再核）

| 字体 | 文件 | 大小 | 备注 |
|---|---|---|---|
| Homemade Apple | homemadeapple/HomemadeApple-Regular.ttf | 103KB | 经 Fontsource 取到并验真可加载；实为手写体非打字机体，只适合便签类手写感用途 |

## 纸面中文（SIL OFL 1.1，随包 LICENSE.txt 已验真）

| 字体 | 文件 | 大小 | 备注 |
|---|---|---|---|
| 朱雀仿宋 | zhuque/ZhuqueFangsong-Regular.ttf | 8.8MB | 官方仓只有源码、Releases 页为空，本文件取自第三方镜像 our-dialogues 的 fonts/zhuque-fangsong/；预览版，覆盖一、二级 6512 字 |

## 界面黑体备选（OPPO 官方免费商用声明）

| 字体 | 文件 | 大小 | 备注 |
|---|---|---|---|
| OPPO Sans 3.0 | opposans/OPPOSans-{Regular,Medium,Bold}.ttf | 各约 9.1–9.2MB | 官方 ColorOS 文章页直链 zip（需 Referer 才能下载）；页面提及 4.0，但本包为 3.0；三款全打包约 27.5MB，界面字体已定系统默认，本款仅备选 |

## 排除项（本轮已核实，不下载）

- 仓耳今楷：个人非商用免费，商用须向仓耳买授权，且官方页称暂不支持手机端直接应用。
- 阿里巴巴普惠体：免费商用实锤，但打包进 App 一项不明，不建议打包。
