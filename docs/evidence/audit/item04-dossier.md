# 核查①-4：卷宗页＋卷宗内页双机逐项核查（A37–A75）

- 核查日期：2026-11-25
- 分支：`audit04-dossier`（base `main` HEAD `e9e5355`）
- 范围：`docs/evidence/audit/item01-inventory.md` §6 卷宗页（A37–A48，12 项）＋ §7 卷宗内页（A49–A75，27 项），共 **39 项**；重点风险 R14（卷宗页没有搜索入口）。
- 设备与构建：
  - 平板 MLR-AL10（HUAWEI MatePad Mini），1600×2560，`192.168.5.133:42355`（TCP）
  - 手机 ADA-AL00U（nova 12 Ultra），1224×2776，`2UCUT24724009680`（USB）
  - 两台设备沿用 audit①-3 同一安装包（versionName 0.1.0）；本批未重新构建/安装，分支相对 base 无代码改动。

## 0. 起始状态（任务要求先记录）

1. **平板**：App 已在前台，停在主页，显示“继续写作”与今日 45 字——`2588`。纸面非空（audit①-3 残留 `啊!尼`）。
2. **手机**：App 已在前台，停在打字机页，纸面残留 `a`——`2589`；系统 Back 键对 App 无效（`uitest uiInput keyEvent Back` 无反应），用左上返回拨杆回主页——`2591`。纸面非空。
3. 两机首次进入卷宗页均自动弹出聚光灯引导（`2592`/`2593`），点“跳过”关闭（`2594`/`2595`）；随后点页眉“?”可再次拉起（`2596`/`2597`）。
4. 本批未清空纸面（卷宗/内页核查不需要空纸）；本批开头**未冷启动 App**，沿用 audit①-3 的同一进程（这一点在后文 O6 的拼音缓冲残留上有影响）。
5. **本批新建的测试数据**（两台各自独立建立）：
   - 卷宗 `测试卷宗`（后改名为 `测试卷宗二号`），封面 kraft，纸 3 张；后续删除 1 张、追加 1 张又删 1 张，收工时 2 张。
   - 卷宗 `移出卷`（1 张纸，用于 A62）。
   - 卷宗 `未命名卷宗`（空名创建，1 张纸，用于 A63）。
   - 在 `测试卷宗` 的一张纸上用内置拼音打入“测试”（手机因缓冲残留打入“呢呢”，再补“测试”），用于 A54 正文搜索。

## 1. 结论摘要

- A37–A75 共 39 项，双机逐项操作：**36 项通过（A52/A53 为条件项；A62/A63 功能正确但附带列表刷新缺陷 O1）、2 项部分（A50、A75）、1 项不通过（A56）**。无崩溃、无卡死、无按钮完全无响应。
- **R14 已确认**：卷宗页只有标题/新建/列表，没有搜索框（`2594`/`2595`/`2715`/`2718`）；搜索只存在于卷宗内页（`DossierDetailPage.searchRow`，A54 通过）。
- **R11 已确认**：卷宗内页用 `customHeader`，页眉只有返回/小封面/名字/⋯/导出/新建纸张，没有“?”引导入口（`2686`/`2742`）。
- **A56 不通过（双机，高优先级）**：内页点“打开”只执行 `loadDocument`，页面仍停在卷宗内页，没有回到打字机。根因定位：`onOpenPaper` 后调 `popTo('typewriter')`，而 `popTo` 在 `navStack` 中找不到 `typewriter` 时直接 `return`（Index.ets:1264-1270、5428-5432）。从主页底部“卷宗”进入时栈是 `home→dossier→detail`，打字机不在栈内；打字机页菜单又没有“卷宗”入口，因此现实路径下必现。
- **新发现（O1–O6，详见 §2/§3）**：
  - **O1 卷宗页列表不即时刷新**：改卷宗名或删卷宗（移出/连删）后返回卷宗页，卡片仍显示旧名字／已删卷宗的“0 张纸”卡片，未归档计数也不更新；重新进入卷宗页才正确。数据落盘正确（索引文件核对见 §3）。
  - **O2 A56 打开不回打字机**（上条，单列为 O2）。
  - **O3 重命名卷宗弹窗不预填当前名**：A50 预期“预填当前名”，实际输入框为空（`2686`/`2688`）。
  - **O4 手机空状态文案与布局不符**：手机内页空态写“点右上角「新建纸张」”，但手机页眉按宽度条件没有该按钮（在 ⋯ 菜单里）——`2620`。
  - **O5 拼音空格上屏后候选条不消失**：`ceshi` 选“测试”后候选条仍显示上一串候选（`2672`/`2676`）；再按空格落的是一个空格（日志 `committed ch=[ ]`，`2678`），不是重复上屏。属打字机页 UI 残留，与 R1/R17/R18 同族，建议并入后续修复批次。
  - **O6 长会话内置拼音缓冲残留**（手机）：进打字机开中文后拼音缓冲为 `niniceshi`（先残留 `nini`），空格首选上屏“呢呢”而不是“测试”（`2673`/`2675` 与 hilog `cn pinyin buf=niniceshi`）。与 R9/R18 跨页/跨引擎残留同源；本批未做受控复现，仅记录。

## 2. 逐项结果

> 结果口径：**通过**＝该控件在双机真机上完成预期操作且画面/落盘可证；**部分**＝动作被识别但预期的一部分缺失；**不通过**＝与清单预期不符且可复现。所有判定以截图为准，hilog/索引文件只作辅助。

| 编号 | 控件 | 平板 | 手机 | 关键证据（截图号） | 实际操作与结论 |
|---|---|---|---|---|---|
| A37 | 返回 | **通过** | **通过** | 2666 / 2667 | 卷宗页左上返回 → 主页（“继续写作”可见）。 |
| A38 | 引导“?” | **通过** | **通过** | 2596 / 2597 | 点“?”拉起卷宗页聚光灯（三步），点“跳过”关闭（2598/2599）。 |
| A39 | 新建卷宗 | **通过** | **通过** | 2600 / 2601 | 打开弹窗：名称输入、四封面、取消/创建。 |
| A40 | “未归档”卡片 | **通过** | **通过** | 2733 / 2734（返回 2735/2736） | 进内页，页眉“未归档”，封面为空占位，2 张未归档纸。 |
| A41 | 卷宗卡片（每个） | **通过** | **通过** | 2725 / 2726；2682 / 2683 | 从列表点“测试卷宗二号”进入对应内页；列表计数与内页一致。 |
| A42 | 弹窗-名称输入 | **通过** | **通过** | 2608 / 2616 | 聚焦输入框注入“测试卷宗”，TextInput 回显；非受控输入不重建弹窗。 |
| A43 | 弹窗-封面 kraft | **通过** | **通过** | 2605 / 2615 | 4 封面中第 1 张（牛皮纸）金框选中。 |
| A44 | 弹窗-封面 leather | **通过** | **通过** | 2602 / 2612 | 第 2 张（皮革）金框选中。 |
| A45 | 弹窗-封面 manila | **通过** | **通过** | 2603 / 2613 | 第 3 张（马尼拉）金框选中。 |
| A46 | 弹窗-封面 cloth | **通过** | **通过** | 2604 / 2614 | 第 4 张（布面）金框选中。 |
| A47 | 弹窗-取消 | **通过** | **通过** | 2607 / 2617 | 关闭弹窗，卷宗页无新增卡片。 |
| A48 | 弹窗-创建 | **通过** | **通过** | 2609 / 2619；2721 / 2722 | 创建后立即进入新卷宗内页；空名创建得到“未命名卷宗”（2721/2722）。 |
| A49 | 返回 | **通过** | **通过** | 2664 / 2665 | 内页返回 → 卷宗页（列表可见）。 |
| A50 | 卷宗名（点击改名） | **部分** | **部分** | 2686 / 2688 | 点名字打开“重命名卷宗”弹窗；但**输入框为空，未预填当前名**（O3）。 |
| A51 | 页眉“⋯” | **通过** | **通过** | 2624 / 2622；2737 / 2738 | 菜单三项“改名／新建纸张／删除卷宗”；“改名”项实测打开重命名弹窗。 |
| A52 | 页眉“导出” | **通过（条件）** | **通过（条件不满足，按设计隐藏）** | 2626 / 2744；日志 | 平板（width≥600）进导出页，界面“整卷宗”，hilog `export target scope=dossier`（09:45:14）；手机无此按钮、整卷宗导出无入口（代码仅 widthVp≥600 显示）。 |
| A53 | 页眉“新建纸张” | **通过（条件）** | **通过（条件不满足，按设计隐藏）** | 2621 / 2623 | 平板页眉按钮连建 3 张，页眉“3 张纸”；手机页眉无按钮，改由 ⋯ 菜单“新建纸张”（A59）建立 3 张。 |
| A54 | 搜索框 | **通过** | **通过** | 2652–2657、2682/2683、2684/2685 | 标题搜“标题甲”命中 1 张；正文搜“测试”命中 1 张（该纸标题不含“测试”，证明正文命中）；无结果文案“没有匹配的纸”；清空恢复全部。hilog `search q=测试 hits=1`（09:45:00/09:45:09）。 |
| A55 | 纸缩略图 | **通过** | **通过** | 2658 / 2628（引导 2629） | 点缩略图进文档视图（只读阅读页；首次自动引导可关）。 |
| A56 | “打开” | **不通过** | **不通过** | 2742 / 2743；hilog | 点“打开”后只 `loadDocument id=... rows=1`，画面仍停内页；无 nav 变化。`popTo('typewriter')` 因栈内无 `typewriter` 直接 return（O2）。 |
| A57 | 纸卡片“⋯” | **通过** | **通过** | 2633 / 2634 | 打开纸操作弹窗：重命名纸／删除／取消。 |
| A58 | 菜单-改名 | **通过** | **通过** | 2635 / 2636 | 关菜单并打开重命名纸弹窗（预填当前标题，见 A70）。 |
| A59 | 菜单-新建纸张 | **通过** | **通过** | 2740（平板）；2623（手机） | 菜单项新建成功：平板页眉 2→3 张，hilog `newPaper in dossier=...`（09:40:27）；手机用该菜单建了初始 3 张。 |
| A60 | 菜单-删除卷宗 | **通过** | **通过** | 2704 / 2705 | 打开删除卷宗弹窗：移出卷宗（纸变未归档）／连纸一起删／取消。 |
| A61 | 菜单-点空白关闭 | **通过** | **通过** | 2624→2625；2631→2632 | 点透明层关闭菜单；前后画面平均亮度 67.0→66.8、76.1→75.6，无压暗/重排。 |
| A62 | 删卷宗-移出卷宗 | **通过（功能）＋ O1** | **通过（功能）＋ O1** | 2708 / 2709；2715 / 2718；索引文件 | 卷宗内 1 张纸变未归档（documents-index `dossierId:null`）、卷宗索引删除；但返回列表仍显示“移出卷 0 张纸”、未归档仍 1，重进卷宗页才显示 2 张、卡片消失（O1）。hilog `deleteDossier mode=unfile papers=1`。 |
| A63 | 删卷宗-连纸一起删 | **通过（功能）＋ O1** | **通过（功能）＋ O1** | 2723 / 2724；索引文件 | hilog `deleteDossier mode=purge papers=1`；dossiers-index 仅剩“测试卷宗二号”；该纸从 documents-index/文档目录彻底移除；列表即时仍留“未命名卷宗 0 张纸”陈旧卡片（O1），重进消失。 |
| A64 | 删卷宗-取消 | **通过** | **通过** | 2706 / 2707 | 关闭弹窗，卷宗仍在内页可继续操作。 |
| A65 | 纸菜单-重命名纸 | **通过** | **通过** | 2635/2636；2641/2647 | 与 A58 同一实现；预填当前标题（“未命名”、“未命名标题甲”）。 |
| A66 | 纸菜单-删除 | **通过** | **通过** | 2727 / 2728 | 打开删除纸确认弹窗（文案按删除档位）。 |
| A67 | 纸菜单-取消 | **通过** | **通过** | 2646 / 2651 | 关闭菜单，未进入删除流程。 |
| A68 | 删纸确认-删除 | **通过** | **通过** | 2731 / 2732；hilog | 当前删除方式=回收站：卡片消失、页眉 3→2 张，hilog `paper trashed id=...`（09:37:08/09:37:39）。direct 档未测（见 §7）。 |
| A69 | 删纸确认-取消 | **通过** | **通过** | 2729 / 2730 | 弹窗关闭，纸仍在列表。 |
| A70 | 重命名纸-输入 | **通过** | **通过** | 2641 / 2647 | 弹窗预填当前标题，可继续编辑（平板“未命名标题甲”；手机同）。 |
| A71 | 重命名纸-取消 | **通过** | **通过** | 2642 / 2648 | 关闭弹窗，标题不变。 |
| A72 | 重命名纸-保存 | **通过** | **通过** | 2639 / 2640；2644 / 2650 | 保存后列表标题更新；空标题点保存不提交、弹窗保持打开（`2644`/`2650`），取消后仍为原名。 |
| A73 | 重命名卷宗-输入 | **通过** | **通过** | 2694/2695；2696/2697 | 输入“测试卷宗二号”，页眉即时更新。 |
| A74 | 重命名卷宗-取消 | **通过** | **通过** | 2687 / 2689 | 关闭弹窗，页眉保持“测试卷宗”。 |
| A75 | 重命名卷宗-保存 | **部分** | **部分** | 2691/2693；2696/2697；2698/2699 | 空名保存保留原名（hilog `renamed to 测试卷宗`）；改名后页眉与落盘正确（`renamed to 测试卷宗二号`）；**但返回卷宗页后卡片仍显示旧名**（2698/2699），需重进才更新（O1）——“通知外层刷新”未即时生效。 |

## 3. 问题清单

| 编号 | 对应 | 类型 | 问题 | 证据 | 复现（双机通用） |
|---|---|---|---|---|---|
| O1 | A50/A62/A63/A75 关联；新增 | 列表刷新缺陷 | 卷宗页的卷宗列表只在重新挂载/下一次文档变更后刷新：改卷宗名后卡片仍旧名；删除卷宗（移出或连删）后卡片仍在（显示 0 张纸），未归档计数不更新。数据本身已正确落盘。 | 平板 2698（改名后仍“测试卷宗”）、2708（移出卷 0 张纸、未归档 1）、2723（未命名卷宗 0 张纸）；手机 2699/2709/2724；重进后 2715/2718 正确。索引：`dossiers-index.json` 已无被删卷宗、`documents-index.json` 的 `dossierId` 已置 null。代码：`DossierPage` 仅在 `aboutToAppear`/`docs` 变更时 `reload()`；`onRenamed` 只增 `docsRev`，文档内容未变，列表不重载。 | 新建卷宗并改名 → 返回卷宗页看卡片名；或卷宗内删除卷宗 → 返回列表看卡片/未归档计数。 |
| O2 | A56 | 导航缺陷（高） | 内页“打开”只载入文档，不跳到打字机。“打开”期望“载入该纸并回打字机编辑”。`popTo('typewriter')` 在 `navStack` 不含 `typewriter` 时直接 return；从主页进卷宗时栈为 `home→dossier→detail`，打字机页菜单又没有“卷宗”入口，现实路径必现。 | 平板 2742、手机 2743（点后仍在内页）；hilog 仅 `loadDocument id=... rows=1`（09:44:18/09:44:26），无 `nav depth` 变化；首轮复测（09:20:39/09:20:50）同样。代码：Index.ets:1264-1270、5428-5432。 | 主页→底部“卷宗”→任一卷宗→任一张纸“打开”。 |
| O3 | A50 | 交互/规格不符 | 点卷宗名打开的“重命名卷宗”弹窗输入框为空，未预填当前卷宗名（清单预期“预填当前名”）。用户需自行完整重输。 | 平板 2686、手机 2688（显示占位“给卷宗起个名字”）。代码：`renameBody()` 的 TextInput 只有 placeholder，没有 `text: this.dName`。 | 内页点页眉卷宗名。 |
| O4 | A53（手机）/空态文案 | 文案与布局不符 | 手机内页空态提示“点右上角「新建纸张」放一张进来”，但手机页眉按 `widthVp<600` 隐藏了“新建纸张”，入口实际在 ⋯ 菜单。 | 手机 2620（0 张纸时的空态）。代码：DossierDetailPage.ets:525、506-513。 | 手机上新卷宗 0 张纸时观察空态。 |
| O5 | 新（R1/R17/R18 同族） | UI 状态残留 | 内置拼音按空格整词上屏后，候选条不消失，仍显示上一串候选；此时再按空格落的是空格（不会重复上屏）。 | 平板 2672（ceshi 候选）→2676（上屏“测试”后候选条仍在）→2678（再按空格得“测试 ”）；hilog 09:25:01 `committed ch=[ ]`。 | 打字机开中文→打 `ceshi`→空格上屏→观察候选条。 |
| O6 | 新（R9/R18 同源） | 状态残留（长会话） | 手机在未重启 App 的长会话中进打字机开中文，拼音缓冲残留上次的 `nini`：打 `ceshi` 得到 `niniceshi`，空格首选上屏“呢呢”而非“测试”。 | 手机 2673/2675；hilog `cn pinyin buf=niniceshi ...`（09:23:59）。本批未做受控复现（与 R9/R18 同源，建议并入专项）。 | 同一 App 进程内此前用过内置拼音后，再进打字机开中文输入。 |

> 说明：O5/O6 属打字机页（①-3 范围）的附带观察，本批只记录、不改变 A37–A75 判定；建议 Kit 归入 R 系列统一处理。

## 4. 清单状态建议（仅建议，未修改清单文件）

| 条目 | 清单现状态 | 建议 |
|---|---|---|
| A37–A49 | 已接线 | 保持“已接线”；备注“2026-11-25 双机真机通过”。 |
| A50 | 已接线 | 保持“已接线”，**备注 O3：弹窗未预填当前名**（是否改“部分/待修”由 Kit 定）。 |
| A51–A55 | 已接线 | 保持；A52/A53 备注“平板通过；手机按 width<600 条件隐藏（整卷宗导出在手机无入口）”。 |
| A56 | 已接线 | **建议改“待修/不通过”**：点“打开”只载入文档，不跳打字机（O2，高优先级）。 |
| A57–A61 | 已接线 | 保持；A59/A61 双机通过。 |
| A62 | 已接线 | 保持“已接线”，**备注 O1 列表刷新缺陷**。 |
| A63 | 已接线 | 保持“已接线”，**备注 O1 列表刷新缺陷**。 |
| A64–A74 | 已接线 | 保持；双机通过。 |
| A75 | 已接线 | 保持“已接线”，**备注 O1：页眉正确但外层列表不即时刷新**（是否改“部分”由 Kit 定）。 |
| R14 | 待确认 | **改“已确认”**：卷宗页无搜索入口，搜索仅在内页。 |
| R11 | 待确认 | **改“已确认”**：卷宗内页 customHeader 无“?”入口（本批双机到场确认）。 |
| 新增 R | — | 建议新增：R20 卷宗页列表刷新滞后（O1）；R21 A56 打开不回打字机（O2）；O3–O6 可按 Kit 口径并入现有 R1/R9/R17/R18 或另立条目。 |

## 5. 操作流水（可复核）

### 5.1 平板 MLR-AL10

1. 起始主页（2588）→ 卷宗页自动引导（2592）→ 跳过（2594）→ “?” 重拉引导（2596）→ 跳过（2598）。
2. 新建卷宗：弹窗（2600）→ 四封面 leather/manila/cloth/kraft（2602–2605）→ 取消（2607）→ 重开并注入“测试卷宗”（2608）→ 创建，进内页（2609）→ 跳过内页自动引导（2610）。
3. 页眉“新建纸张”×3（2621，3 张纸）；页眉⋯菜单（2624）→ 点空白关闭（2625，无压暗）→ 导出（2626，整卷宗）→ 返回（2627）。
4. 纸卡片⋯（2633）→ 重命名纸：空输入弹窗（2635）→ 注入“标题甲”（2637）→ 保存（2639）→ 重开预填（2641）→ 取消（2642）→ 第二张纸清空后保存被拒（2644）→ 取消（2645）→ 纸菜单取消（2646）。
5. 搜索：标题“标题甲”命中 1（2652）→ 无结果（2653）→ 清空恢复 3 张（2654）。
6. 缩略图→文档视图（2658）→ 返回（2659）→ 点“打开”（2660，仍停内页，首轮记录）→ 再次点“打开”（2742，仍停内页；hilog 仅 loadDocument）。
7. 返回卷宗页（2664）→ 返回主页（2666）→ “继续写作”进打字机（2668）→ 切中文（2670）→ 打 `ceshi` 出候选（2672）→ 空格上屏“测试”（2674）→ 候选条未消失（2676）→ 再按空格得空格（2678）→ 拨杆回主页（2680）。
8. 卷宗→测试卷宗卡片（2682 搜索正文“测试”命中 1）→ 清空（2684）→ 点卷宗名打开重命名弹窗（2686，空输入，O3）→ 取消（2687）→ 空名保存保留原名（2690/2691）→ 输入“测试卷宗二号”保存（2694/2696）→ 返回列表仍显示旧名（2698，O1）。
9. 新建“移出卷”（2700）→ 加 1 张纸（2702）→ ⋯→删除卷宗（2704）→ 取消（2706）→ 再删→“移出卷宗”（2708：列表陈旧）→ 返回二次+重进（2713/2714/2715：正确，未归档 2）。
10. 空名新建“未命名卷宗”（2719/2721）→ 加 1 张纸（2747）→ ⋯→删除卷宗→连纸一起删（2723：列表陈旧卡片）→ 索引核对。
11. 重进测试卷宗二号：纸 3→⋯删除（2727）→ 取消（2729）→ 再删→删除（2731，2 张纸，日志 paper trashed）。
12. 返回列表→未归档卡片（2733）→ 返回（2735）→ 重进测试卷宗二号：⋯→改名（2737）→ 取消；⋯→新建纸张（2740，3 张）→ 删除新增纸（2741，2 张）。
13. A56 干净复现：清 hilog → 点“打开”（2742 + loadDocument 日志，无导航）→ 导出复测（2744，scope=dossier）→ 返回→主页（2745）。

### 5.2 手机 ADA-AL00U

1. 起始打字机纸面 `a`（2589）→ 返回拨杆回主页（2591）→ 卷宗页自动引导（2593）→ 跳过（2595）→ “?” 重拉（2597）→ 跳过（2599）。
2. 新建卷宗：弹窗（2601）→ 四封面 leather/manila/cloth/kraft（2612–2615）→ 注入“测试卷宗”（2616）→ 取消（2617）→ 重开注入并创建，进内页（2618/2619）→ 跳过引导（2620）。
3. ⋯菜单（2622）→ 新建纸张×3（2623，3 张纸）→ ⋯→点空白关闭（2631/2632，无压暗）。
4. 纸卡片⋯（2634）→ 重命名纸：空输入（2636）→ 注入“标题甲”（2638）→ 保存（2640）→ 重开预填（2647）→ 取消（2648）→ 第二张纸清空后保存被拒（2649/2650）→ 纸菜单取消（2651）。
5. 搜索：标题命中 1（2655）→ 无结果（2656）→ 清空（2657）。
6. 点缩略图意外打开文档视图（2628，A55 证据）→ “?” 拉引导（2629）→ 返回（2630）。
7. 返回卷宗页（2665）→ 主页（2667）→ “继续写作”（2669）→ 切中文（2671）→ 打 `ceshi` 出现 `niniceshi` 候选（2673）→ 空格上屏“呢呢”（2675）→ 再按空格补上“测试”（2679）→ 拨杆回主页（2681）。
8. 卷宗→测试卷宗卡片→正文搜“测试”命中 1（2683）→ 清空（2685）→ 点卷宗名改名弹窗（2688，空输入，O3）→ 取消（2689）→ 空名保存（2692/2693）→ 改名“测试卷宗二号”（2695/2697）→ 返回列表仍旧名（2699，O1）。
9. 新建“移出卷”（2701）→ 加纸（2703）→ ⋯→删除卷宗（2705）→ 取消（2707）→ 再删→移出卷宗（2709 陈旧）→ 两次返回+重进（2716/2717/2718 正确）。
10. 空名新建“未命名卷宗”（2720/2722）→ 加纸（2748）→ 连纸一起删（2724 陈旧卡片）→ 索引核对。
11. 重进测试卷宗二号：删纸确认（2728）→ 取消（2730）→ 再删（2732，2 张纸）。
12. 未归档卡片（2734）→ 返回（2736）→ ⋯→改名（2738）→ 取消。
13. A56 干净复现：清 hilog → 点“打开”（2743 + loadDocument 日志，无导航）→ 返回→主页（2746）。

## 6. 证据文件

- `docs/evidence/audit/item04-hilog.txt`：本批从两台设备 `hilog -x` 读取的摘录与补充摘录（含 deleteDossier、paper trashed、newPaper、search q=、onExportDossier、nav depth；A56 干净复现的 loadDocument 行另在本报告 §3 O2 引用）。hilog 环形缓冲滚动快，部分早期行（平板 renamePaper/renamed to/search/export 首轮、手机 deleteDossier/newPaper 等）在收尾补录时已被覆盖；这些行在操作当刻已读取并写入本报告，原始截图仍是主证据。
- 索引核对：两机 `files/dossiers-index.json`、`files/documents-index.json`（2026-11-25 09:47 读取）——A62/A63 的落盘结果正确。
- 本报告所有“通过/不通过”以截图为准（AGENTS 识屏验收铁律），hilog/索引只作辅助。

## 7. 缺口与未验项

1. **A68 direct 档未测**：当前删除方式为回收站档（日志 `paper trashed`）；`direct` 路径未改设置验证（R8：ask 与 trash 同效的背景仍在）。
2. **A52 整卷宗导出的内容未逐篇核对**：只验证了入口、界面“整卷宗”、`export target scope=dossier` 落点；导出文件内容范围归 ①-7（A181–A199）。另观察日志中 scope=dossier 仍带 `docId`（当前载入纸），是否被导出层忽略未验。
3. **A54 150ms 防抖未计时**：只验证结果与 `search q=... hits=` 日志，未测输入过程中的中间态节流。
4. **动画未逐帧**：纸飞出（350ms/120ms 弹簧）、AppDialog 200ms、AppMenu 160ms 均未逐帧；`snapshot_display` 单帧 400–500ms，按 AGENTS 工具边界不用连拍冒充。
5. **标题搜索的样本被自动改名**：重命名纸为“未命名标题甲”后，用“继续写作”加载该纸并输入“测试”，保存时标题自动变为“测试”（首行自动命名）；因此 A54 标题搜索证据以当时截图（2652/2655）为准，后续截图该纸名为“测试”。
6. **A55 文档视图深层功能（A76–A84）不在本批**：仅验证缩略图能进入阅读页。
7. **O5/O6 未做受控复现**：候选条残留与长会话拼音缓冲残留为观测，只记录、不代判根因。
8. **音效/手感/主观流畅**不在本批范围，未代判。

## 8. 工具与方法注记

- `hdc` 不在 PATH，实际路径 `F:\HarmonyOS\SDK\26.0.0\toolchains\hdc.exe`。
- 截图：`snapshot_display -f /data/local/tmp/_cap.jpeg` → `hdc file recv` → PIL 转 PNG；每张记录平均亮度。开工 49.8/87.9，收工 49.8/64.4，均 >20。
- 点按/滑动：`uitest uiInput click/swipe`；本机无 `input` 命令（AGENTS）。**系统 Back 键对 App 无效**（`keyEvent Back` 无反应），打字机返回用左上拨杆（平板约 (63,180)、手机 (51,190)）。
- 文本注入：`uitest uiInput text <串>` 只对**已聚焦**输入框生效；中文整串可注入（“测试卷宗”“标题甲”）。聚焦后系统 IME 会吞拉丁字母（“Audit04” 只落 “04”），因此测试名一律用中文或数字；退格用 `uitest uiInput keyEvent 2055`（实测可清空输入框）。
- **点击丢失**：`uitest uiInput click` 仍偶发未命中（同一条命令重发即成功；连续快速发送时更明显），已用 1.0–1.5s 间隔、点后 dump/截图复核缓解；产品判定只以画面变化为准。
- 手机 `dumpLayout` 的 y 与截图偶有偏移（audit①-2 O4 同源）；本批点按以 dump 中心为准，命中率高于截图目测。
- 屏幕常亮：两台均执行 `power-shell timeout -o 2147483647`＋`wakeup`＋`setmode 602`；收工两机均亮屏。
- 设备：平板 `192.168.5.133:42355`（TCP）、手机 `2UCUT24724009680`（USB），收工时均 `Connected`。

## 9. 测试残留与收工状态

- 两台设备均**未** `bm clean`；应用数据在 audit①-3 基础上增补了本批测试数据。
- **平板**：主页（2745）。卷宗 1 个：`测试卷宗二号`（2 张纸：`测试`——正文“测试”；`未命名`）。未归档 2 张（`移出卷` 移出的纸 + audit①-3 的 `啊!尼`）。回收站 2 张（A68 删的纸 + A59 追加后又删的纸）。`未命名卷宗` 的 1 张纸已被 A63 彻底删除。导出目录仍为 audit①-3 的 `carriage-1795562962424.txt`（本批未落新文件）。
- **手机**：主页（2746）。卷宗 1 个：`测试卷宗二号`（2 张纸：`呢呢测试`、`未命名`）。未归档 2 张（`移出卷` 移出的纸 + audit①-3 的 `a`）。回收站 1 张（A68 删的纸）。`未命名卷宗` 的纸已被 A63 彻底删除。导出目录仍为 audit①-3 的 `carriage-1795565400075.txt`。
- 删除方式仍为回收站档（未改设置）；中文引擎/字体/候选设置未在本批改动。
- **后续门图/验收前置**：两机纸面与文档集合已被本批改写（新增卷宗/纸张、标题自动改名、回收站内容），统计与“继续写作”目标也受影响；跑 1920s 门图或其它验收前须 `bm clean` 或换纸清空并按 §5 仪式重拍/比对。
- O6 的内置拼音缓冲残留只存在于当前 App 进程内，重启即清；不影响落盘数据。

## 10. 截图索引（2588–2748，共 158 张）

> 编号规则：`<编号>_audit04_<设备>_<主题>.png`，均存 `docs/shots/`。文件名即内容摘要；逐项证据见 §2。个别编号因重拍/更名/删除不连续（2590、2611、2739 已清理；2721/2722 原重号文件已改为 2747/2748）。

### 10.1 平板（80 张）

| 编号 | 文件 | 内容 |
|---|---|---|
| 2588 | `2588_audit04_tablet_start_state_home.png` | 起始：主页（继续写作） |
| 2592 | `2592_audit04_tablet_dossier_page_initial.png` | 卷宗页首次进入（自动引导） |
| 2594 | `2594_audit04_tablet_dossier_page_clean.png` | 卷宗页（关闭引导） |
| 2596 | `2596_audit04_tablet_guide_from_help.png` | 点“?”重拉聚光灯引导 |
| 2598 | `2598_audit04_tablet_after_guide_dismissed.png` | 关闭引导后 |
| 2600 | `2600_audit04_tablet_new_dossier_dialog.png` | 新建卷宗弹窗 |
| 2602 | `2602_audit04_tablet_dialog_cover_leather.png` | 封面选 leather（金框） |
| 2603 | `2603_audit04_tablet_dialog_cover_manila.png` | 封面选 manila（金框） |
| 2604 | `2604_audit04_tablet_dialog_cover_cloth.png` | 封面选 cloth（金框） |
| 2605 | `2605_audit04_tablet_dialog_cover_kraft.png` | 封面选 kraft（金框） |
| 2606 | `2606_audit04_tablet_dialog_name_typed.png` | 名称输入首次尝试（系统 IME 吞拉丁字母，仅落“04”） |
| 2607 | `2607_audit04_tablet_dialog_cancelled_no_new.png` | 取消新建，无新增 |
| 2608 | `2608_audit04_tablet_dialog_cn_name_typed.png` | 中文名“测试卷宗”已输入 |
| 2609 | `2609_audit04_tablet_detail_created_cn_name.png` | 创建后进内页（自动引导） |
| 2610 | `2610_audit04_tablet_detail_clean_empty.png` | 内页空态（0 张纸） |
| 2621 | `2621_audit04_tablet_detail_three_papers.png` | 内页 3 张纸 |
| 2624 | `2624_audit04_tablet_more_menu_open.png` | 页眉⋯菜单 |
| 2625 | `2625_audit04_tablet_more_menu_blank_closed.png` | 点空白关闭菜单（无压暗） |
| 2626 | `2626_audit04_tablet_export_page_scope_dossier.png` | 导出页，范围“整卷宗” |
| 2627 | `2627_audit04_tablet_back_to_detail.png` | 从导出页返回内页 |
| 2633 | `2633_audit04_tablet_paper_menu_open.png` | 纸卡片⋯菜单 |
| 2635 | `2635_audit04_tablet_paper_rename_dialog_empty.png` | 重命名纸弹窗（空标题） |
| 2637 | `2637_audit04_tablet_paper_rename_typed.png` | 重命名纸输入“标题甲” |
| 2639 | `2639_audit04_tablet_paper_renamed.png` | 保存后标题更新 |
| 2641 | `2641_audit04_tablet_paper_rename_prefilled.png` | 重开重命名纸（预填当前标题） |
| 2642 | `2642_audit04_tablet_paper_rename_cancelled.png` | 取消重命名纸 |
| 2643 | `2643_audit04_tablet_paper_rename_cleared.png` | 清空重命名输入 |
| 2644 | `2644_audit04_tablet_paper_rename_empty_save_guard.png` | 空标题保存被拒（弹窗不关） |
| 2645 | `2645_audit04_tablet_after_empty_save_cancel.png` | 取消空标题保存 |
| 2646 | `2646_audit04_tablet_paper_menu_cancelled.png` | 纸菜单取消 |
| 2652 | `2652_audit04_tablet_search_title_hit.png` | 标题搜索命中 1 |
| 2653 | `2653_audit04_tablet_search_no_result.png` | 搜索无结果 |
| 2654 | `2654_audit04_tablet_search_cleared_all.png` | 清空搜索恢复全部 |
| 2658 | `2658_audit04_tablet_docview_from_thumbnail.png` | 缩略图进文档视图 |
| 2659 | `2659_audit04_tablet_back_to_detail_from_docview.png` | 从文档视图返回内页 |
| 2660 | `2660_audit04_tablet_open_paper_first_attempt.png` | 点“打开”第一次（仍停内页） |
| 2664 | `2664_audit04_tablet_detail_back_to_dossier_list.png` | 内页返回卷宗页 |
| 2666 | `2666_audit04_tablet_dossier_back_home.png` | 卷宗页返回主页 |
| 2668 | `2668_audit04_tablet_typewriter_continue.png` | 继续写作进打字机 |
| 2670 | `2670_audit04_tablet_lang_zh.png` | 切中文 |
| 2672 | `2672_audit04_tablet_ceshi_candidates.png` | ceshi 候选条 |
| 2674 | `2674_audit04_tablet_typed_ceshi.png` | 上屏“测试”/“呢呢” |
| 2676 | `2676_audit04_tablet_after_commit_stable.png` | 上屏后候选条仍在 |
| 2678 | `2678_audit04_tablet_space_again_probe.png` | 再按空格落空格 |
| 2680 | `2680_audit04_tablet_home_after_lever.png` | 拨杆回主页 |
| 2682 | `2682_audit04_tablet_search_body_hit.png` | 正文搜索“测试”命中 1 |
| 2684 | `2684_audit04_tablet_search_cleared_again.png` | 清空搜索 |
| 2686 | `2686_audit04_tablet_rename_dossier_dialog.png` | 重命名卷宗弹窗（空输入） |
| 2687 | `2687_audit04_tablet_rename_dossier_cancelled.png` | 取消重命名卷宗 |
| 2690 | `2690_audit04_tablet_rename_dossier_reopen.png` | 重开重命名卷宗弹窗 |
| 2691 | `2691_audit04_tablet_rename_empty_save_kept.png` | 空名保存保留原名 |
| 2694 | `2694_audit04_tablet_rename_dossier_reopen.png` | 重开重命名卷宗弹窗 |
| 2696 | `2696_audit04_tablet_renamed_header.png` | 改名后页眉 |
| 2698 | `2698_audit04_tablet_list_after_rename.png` | 返回列表（卡片仍旧名） |
| 2700 | `2700_audit04_tablet_new_dossier_unfile_created.png` | 新建“移出卷”进内页 |
| 2702 | `2702_audit04_tablet_unfile_dossier_one_paper.png` | “移出卷”1 张纸 |
| 2704 | `2704_audit04_tablet_delete_dossier_dialog.png` | 删除卷宗弹窗 |
| 2706 | `2706_audit04_tablet_delete_dossier_cancelled.png` | 取消删除卷宗 |
| 2708 | `2708_audit04_tablet_after_unfile_list.png` | 移出卷宗后列表（陈旧） |
| 2710 | `2710_audit04_tablet_unfile_list_stable.png` | 列表仍陈旧（卡片/计数） |
| 2712 | `2712_audit04_tablet_list_before_back_test.png` | 删除后列表（返回测试前） |
| 2713 | `2713_audit04_tablet_after_back1.png` | 第一次返回后 |
| 2714 | `2714_audit04_tablet_after_back2.png` | 第二次返回后（主页） |
| 2715 | `2715_audit04_tablet_dossier_reentered.png` | 重进卷宗页（刷新正确） |
| 2719 | `2719_audit04_tablet_new_dossier_empty_name_dialog.png` | 空名新建卷宗弹窗 |
| 2721 | `2721_audit04_tablet_detail_default_name.png` | 空名创建得“未命名卷宗” |
| 2723 | `2723_audit04_tablet_after_purge_list.png` | 连纸删后列表（陈旧卡片） |
| 2725 | `2725_audit04_tablet_detail_before_paper_delete.png` | 删纸前内页 |
| 2727 | `2727_audit04_tablet_delete_paper_dialog.png` | 删除纸确认弹窗 |
| 2729 | `2729_audit04_tablet_delete_paper_cancelled.png` | 取消删纸 |
| 2731 | `2731_audit04_tablet_after_paper_deleted.png` | 删纸后 2 张纸 |
| 2733 | `2733_audit04_tablet_unfiled_detail.png` | 未归档内页 |
| 2735 | `2735_audit04_tablet_back_from_unfiled.png` | 从未归档返回列表 |
| 2737 | `2737_audit04_tablet_rename_from_menu_dialog.png` | ⋯菜单“改名”打开弹窗 |
| 2740 | `2740_audit04_tablet_menu_new_paper_added.png` | ⋯菜单新建纸张（3 张） |
| 2741 | `2741_audit04_tablet_extra_paper_deleted_final_detail.png` | 删除新增纸后 2 张 |
| 2742 | `2742_audit04_tablet_open_paper_stays_detail.png` | A56 复现：点“打开”仍停内页 |
| 2744 | `2744_audit04_tablet_export_page_second.png` | 导出页复测（整卷宗） |
| 2745 | `2745_audit04_tablet_end_state_home.png` | 收工主页 |
| 2747 | `2747_audit04_tablet_purge_dossier_one_paper.png` | “未命名卷宗”1 张纸 |

### 10.2 手机（78 张）

| 编号 | 文件 | 内容 |
|---|---|---|
| 2589 | `2589_audit04_phone_start_state_typewriter.png` | 起始：打字机页，纸面残留 a |
| 2591 | `2591_audit04_phone_home_after_lever.png` | 拨杆回主页 |
| 2593 | `2593_audit04_phone_dossier_page_initial.png` | 卷宗页首次进入（自动引导） |
| 2595 | `2595_audit04_phone_dossier_page_clean.png` | 卷宗页（关闭引导） |
| 2597 | `2597_audit04_phone_guide_from_help.png` | 点“?”重拉聚光灯引导 |
| 2599 | `2599_audit04_phone_after_guide_dismissed.png` | 关闭引导后 |
| 2601 | `2601_audit04_phone_new_dossier_dialog.png` | 新建卷宗弹窗 |
| 2612 | `2612_audit04_phone_dialog_cover_leather.png` | 封面选 leather（金框） |
| 2613 | `2613_audit04_phone_dialog_cover_manila.png` | 封面选 manila（金框） |
| 2614 | `2614_audit04_phone_dialog_cover_cloth.png` | 封面选 cloth（金框） |
| 2615 | `2615_audit04_phone_dialog_cover_kraft.png` | 封面选 kraft（金框） |
| 2616 | `2616_audit04_phone_dialog_name_typed.png` | 名称输入“测试卷宗” |
| 2617 | `2617_audit04_phone_dialog_cancelled_no_new.png` | 取消新建，无新增 |
| 2618 | `2618_audit04_phone_dialog_name_typed_again.png` | dialog name typed again |
| 2619 | `2619_audit04_phone_detail_with_guide.png` | detail with guide |
| 2620 | `2620_audit04_phone_detail_clean_empty.png` | 内页空态（0 张纸） |
| 2622 | `2622_audit04_phone_more_menu_open.png` | 页眉⋯菜单 |
| 2623 | `2623_audit04_phone_detail_three_papers.png` | 内页 3 张纸 |
| 2628 | `2628_audit04_phone_docview_from_thumbnail.png` | 缩略图进文档视图 |
| 2629 | `2629_audit04_phone_docview_guide.png` | 文档视图引导 |
| 2630 | `2630_audit04_phone_back_to_detail.png` | 从导出页返回内页 |
| 2631 | `2631_audit04_phone_more_menu_open3.png` | more menu open3 |
| 2632 | `2632_audit04_phone_more_menu_blank_closed.png` | 点空白关闭菜单（无压暗） |
| 2634 | `2634_audit04_phone_paper_menu_open.png` | 纸卡片⋯菜单 |
| 2636 | `2636_audit04_phone_paper_rename_dialog_empty.png` | 重命名纸弹窗（空标题） |
| 2638 | `2638_audit04_phone_paper_rename_typed.png` | 重命名纸输入“标题甲” |
| 2640 | `2640_audit04_phone_paper_renamed.png` | 保存后标题更新 |
| 2647 | `2647_audit04_phone_paper_rename_prefilled.png` | 重开重命名纸（预填当前标题） |
| 2648 | `2648_audit04_phone_paper_rename_cancelled.png` | 取消重命名纸 |
| 2649 | `2649_audit04_phone_paper_rename_cleared.png` | 清空重命名输入 |
| 2650 | `2650_audit04_phone_paper_rename_empty_save_guard.png` | 空标题保存被拒（弹窗不关） |
| 2651 | `2651_audit04_phone_paper_menu_cancelled.png` | 纸菜单取消 |
| 2655 | `2655_audit04_phone_search_title_hit.png` | 标题搜索命中 1 |
| 2656 | `2656_audit04_phone_search_no_result.png` | 搜索无结果 |
| 2657 | `2657_audit04_phone_search_cleared_all.png` | 清空搜索恢复全部 |
| 2661 | `2661_audit04_phone_open_paper_first_attempt.png` | 点“打开”第一次（仍停内页） |
| 2662 | `2662_audit04_phone_keyboard_dismissed.png` | 收起系统键盘 |
| 2663 | `2663_audit04_phone_open_paper_second_attempt.png` | 点“打开”第二次（仍停内页） |
| 2665 | `2665_audit04_phone_detail_back_to_dossier_list.png` | 内页返回卷宗页 |
| 2667 | `2667_audit04_phone_dossier_back_home.png` | 卷宗页返回主页 |
| 2669 | `2669_audit04_phone_typewriter_continue.png` | 继续写作进打字机 |
| 2671 | `2671_audit04_phone_lang_zh.png` | 切中文 |
| 2673 | `2673_audit04_phone_ceshi_candidates.png` | ceshi 候选条 |
| 2675 | `2675_audit04_phone_typed_ceshi.png` | 上屏“测试”/“呢呢” |
| 2677 | `2677_audit04_phone_after_commit_stable.png` | 上屏后候选条仍在 |
| 2679 | `2679_audit04_phone_commit_ceshi.png` | 补上屏“测试” |
| 2681 | `2681_audit04_phone_home_after_lever.png` | 拨杆回主页 |
| 2683 | `2683_audit04_phone_search_body_hit.png` | 正文搜索“测试”命中 1 |
| 2685 | `2685_audit04_phone_search_cleared_again.png` | 清空搜索 |
| 2688 | `2688_audit04_phone_rename_dossier_dialog.png` | 重命名卷宗弹窗（空输入） |
| 2689 | `2689_audit04_phone_rename_dossier_cancelled.png` | 取消重命名卷宗 |
| 2692 | `2692_audit04_phone_rename_dossier_reopen.png` | 重开重命名卷宗弹窗 |
| 2693 | `2693_audit04_phone_rename_empty_save_kept.png` | 空名保存保留原名 |
| 2695 | `2695_audit04_phone_rename_dossier_reopen.png` | 重开重命名卷宗弹窗 |
| 2697 | `2697_audit04_phone_renamed_header.png` | 改名后页眉 |
| 2699 | `2699_audit04_phone_list_after_rename.png` | 返回列表（卡片仍旧名） |
| 2701 | `2701_audit04_phone_new_dossier_unfile_created.png` | 新建“移出卷”进内页 |
| 2703 | `2703_audit04_phone_unfile_dossier_one_paper.png` | “移出卷”1 张纸 |
| 2705 | `2705_audit04_phone_delete_dossier_dialog.png` | 删除卷宗弹窗 |
| 2707 | `2707_audit04_phone_delete_dossier_cancelled.png` | 取消删除卷宗 |
| 2709 | `2709_audit04_phone_after_unfile_list.png` | 移出卷宗后列表（陈旧） |
| 2711 | `2711_audit04_phone_unfile_list_stable.png` | 列表仍陈旧（卡片/计数） |
| 2716 | `2716_audit04_phone_after_back1.png` | 第一次返回后 |
| 2717 | `2717_audit04_phone_after_back2.png` | 第二次返回后（主页） |
| 2718 | `2718_audit04_phone_dossier_reentered.png` | 重进卷宗页（刷新正确） |
| 2720 | `2720_audit04_phone_new_dossier_empty_name_dialog.png` | 空名新建卷宗弹窗 |
| 2722 | `2722_audit04_phone_detail_default_name.png` | 空名创建得“未命名卷宗” |
| 2724 | `2724_audit04_phone_after_purge_list.png` | 连纸删后列表（陈旧卡片） |
| 2726 | `2726_audit04_phone_detail_before_paper_delete.png` | 删纸前内页 |
| 2728 | `2728_audit04_phone_delete_paper_dialog.png` | 删除纸确认弹窗 |
| 2730 | `2730_audit04_phone_delete_paper_cancelled.png` | 取消删纸 |
| 2732 | `2732_audit04_phone_after_paper_deleted.png` | 删纸后 2 张纸 |
| 2734 | `2734_audit04_phone_unfiled_detail.png` | 未归档内页 |
| 2736 | `2736_audit04_phone_back_from_unfiled.png` | 从未归档返回列表 |
| 2738 | `2738_audit04_phone_rename_from_menu_dialog.png` | ⋯菜单“改名”打开弹窗 |
| 2743 | `2743_audit04_phone_open_paper_stays_detail.png` | A56 复现：点“打开”仍停内页 |
| 2746 | `2746_audit04_phone_end_state_home.png` | 收工主页 |
| 2748 | `2748_audit04_phone_purge_dossier_one_paper.png` | “未命名卷宗”1 张纸 |

## 11. 复核说明

- 本报告只做核查与记录，**未修改任何产品代码，也未修改清单文件** `item01-inventory.md`；条目状态是否变更由 Kit 统一维护。
- 唯一阻塞类问题无：两机在线、安装包可启动、39 项证据均可采集；A56 为产品缺陷，不是取证阻塞。
