# 核查①-10：聚光灯引导＋成就弹窗双机逐项核查（A200–A211）

- 核查日期：2026-11-25
- 分支：`audit10-spotlight-achievements`（base `main` HEAD `33a8673`）
- 范围：`docs/evidence/audit/item01-inventory.md` §18 聚光灯引导（A200–A204）、§19 成就弹窗（A205–A207）、§20 全局下拉菜单（A208–A211），共 12 项。重点复核风险 **R10**（打字机页引导锚点缺失）、**R25**（文档视图引导第 2 步锚点缺失/文案指向不存在的“编辑”）、**R11**（卷宗内页无“?”引导入口），以及核查①-7 遗留 **O4**（平板冷启动自动弹主页引导与 `guide.home.seen=true` 冲突）。
- 设备与构建：
  - 平板 MLR-AL10（HUAWEI MatePad Mini），1600×2560，`192.168.5.133:42355`（TCP）
  - 手机 ADA-AL00U（nova 12 Ultra），1224×2776，`2UCUT24724009680`（USB）
  - 两机沿用 audit①-9 同一安装包；本批未重新构建/安装，分支相对 base 无代码改动。
- **环境说明（重要）**：核查期间两台设备被其它 App 反复切到前台（平板：漫画/阅读；手机：漫画/备份与恢复/反馈中心），多次导致自动化点击落到别家 App、截图不是本 App。凡此 26 张已按 `void_` 前缀作废（清单见 §6.2）；所有结论只采用本 App 前台、且经 dump/截图双向确认的样本。App 进程全程未崩溃、未 freeze（平板 pid 58185、手机 pid 61719 均存活）。

## 0. 起始状态与测试数据

### 0.1 起始 prefs（两机实测，`carriagereturn_prefs`）

| 项 | 平板 | 手机 |
|---|---|---|
| `machine` | 1920s-upright | 1920s-upright |
| `delete_mode` | trash | trash |
| `stats.daily_goal` | 500 | 500 |
| `stats.day.key`／`stats.day.chars` | 2026-11-25／50 | 2026-11-25／49 |
| `stats.total.chars` | 50 | 49 |
| 已解锁成就 | font_1、docs_10、paper_2、paper_4、ribbon_1、share_1、share_10（`achieve.migrated=true`） | 同平板 |
| `guide.home.seen` | true | true |
| `guide.typewriter.seen` | true | true |
| `guide.dossier.seen` | true | true |
| `guide.dossier_detail.seen` | true | true |
| `guide.document_view.seen` | true | true |
| `guide.settings.seen` | true | true |
| `guide.export.seen` | true | true |
| `guide.pinyin_settings.seen` | true | true |
| `guide.customize.seen` | true | true |
| `guide.collection.seen` | false | false |
| `guide.collection_detail.seen` | false | false |
| `guide.font_manager.seen` | false | false |
| `guide.paper_custom.seen` | false | false |
| `guide.trash.seen` | false | false |
| 其它（①-7/①-9 残留） | 字号 20、`custom.font.1920s-upright.family` 为空、纸纹指向沙箱截图副本 | 字号 20、`marginH=40`、`family=CourierPrime`、纸纹指向沙箱截图副本 |

起始 prefs 数值已摘录本表；pull 出的原件未入库（本批临时工作目录已在收工前清理，避免污染工作树）。

### 0.2 本批测试数据与状态构造

- **手机（未清数据）**：
  - 设置→每日目标从 500 拖到 **100**，随后在打字机页累计落字到 1000+，真实解锁 `goal_1`（首达每日目标）与 `words_1000`（初试锋芒）——用于 A206（关闭）与 A207（遮罩关闭）。
  - 收工已把每日目标恢复 **500**（`stats.daily_goal=500` 实测）。
- **平板（收尾时清数据重建）**：
  - 其它 10 项验证完成后执行 `bm clean -n com.dlzz.carriagereturn -d`，从新装态验证启动引导、设置、打字机引导。
  - 新装态下设置每日目标 100，真实解锁 `goal_1`（A206）与 `words_1000`（A207）。
  - 收工已把每日目标恢复 **500**。
- **A205 汇总弹窗**：需要 `achieve.migrated=false` 且首次评估时已有成就达成（迁移态专属）。尝试改写 prefs 构造：两机 `hdc shell cp` 写入应用沙箱均失败（`cp: dir at '...'`、RC=1；无 root/`su`/`run-as`，shell uid 2000 无沙箱写权限），无法构造；改为在新装平板上验证“首次评估”真实行为（见 §2 A205）。

## 1. 结论摘要

- **A200–A204（聚光灯按钮/遮罩）双机全部通过**：主页“?”拉起 3 步引导，逐项验证上一步、下一步、知道了、跳过、点暗区关闭、点洞内关闭；每步均以 dump 断言按钮/文案/步骤点状态，截图见索引。
- **A206／A207 双机通过（真实成就解锁）**：
  - 手机：`goal_1` 弹窗（3512）→ 点“知道了”关闭（3513）；`words_1000` 弹窗（3538）→ 点卡外遮罩关闭（3539）。
  - 平板：新装态 `goal_1` 弹窗（3545）→ 关闭（3546）；`words_1000` 弹窗（3547）→ 遮罩关闭（3548）。
  - 关后 dump 无弹窗残留，prefs `achieve.goal_1=true`／`achieve.words_1000=true`。
- **A205 “查看成就”不可达（迁移态专属）**：该按钮只在 `achieveNoticeKind==='summary'` 时渲染；汇总条只在“首次评估且已有成就达成”的迁移路径出现。两机早已 `migrated=true`；新装平板清数据后，首次评估发生在任何成就达成之前（`migrated` 先被置 true），随后 `goal_1` 以**单项弹窗**出现（3545，非 summary），证明当前版本在真机上无法再进入 summary 态。代码接线本身正确（`Index.ets:4428-4438`）。
- **A208–A211 不可达（确认）**：`Index.menuOpen` 全仓只有置 false 的语句（`Index.ets:1323,5563`），没有置 true 的入口；`AppMenu` 实例只在 `if (this.menuOpen)` 分支（`Index.ets:5559-5572`），因此菜单项“收藏/设置/导出”与菜单的点空白关闭在真机上不可能出现。主页/打字机页也没有任何菜单入口（打字机顶区只有返回拨杆与出纸槽，`Parts26.ets:235-288`）。
- **R10 双机确认**：重播引导后进打字机，3 步全部 `guide anchor miss typewriter/1..3`，dump 无任何 `typewriter__*` 节点；聚光灯退化为居中气泡＋整屏均匀压暗，无高亮洞（3500–3502、3525–3527）。
- **R25 双机确认**：文档视图引导第 2 步 `guide anchor miss document_view/2 document_view__edit_btn`，气泡居中、整屏压暗无洞；页面无“编辑”按钮/文字（dump 中仅引导文案含“编辑”）；第 1/3 步有洞（3507–3509、3531–3533）。
- **R11 双机确认**：卷宗内页页眉只有返回/小封面/标题/⋯（手机另有隐藏项），无“?”（3505、3530）；`PageShell` 的 `customHeader` 分支跳过默认页眉的 help 按钮。
- **O4 本批未复现**：两机冷启动（`aa force-stop`＋`aa start`，等 8s）均在 `guide.home.seen=true` 下停在主页、无自动引导；启动期无 Spotlight 日志（3464、3465、3466）。建议 O4 保持“待确认/未复现”，若再现需抓启动期 prefs 读取时序。
- **新观察 O1（双机）**：聚光灯遮罩不压暗主页 hero 图片（Image 节点疑似叠在遮罩之上）；详见 §3。属视觉问题，不影响点击与引导流程。

## 2. 逐项结果

> 结果口径：**通过**＝控件在真机完成预期操作且画面/dump 可证；判定以截图为准，hilog/dump 只作辅助。A200–A207 编号按清单 §18/§19 原文（任务描述把 A208–A211 称作“成就弹窗菜单项”，与清单不符；本报告按清单：A205–A207 是成就弹窗，A208–A211 是 Index 全局 AppMenu）。

| 编号 | 控件 | 平板 | 手机 | 关键证据（截图号） | 实际操作与结论 |
|---|---|---|---|---|---|
| A200 | “上一步” | 通过 | 通过 | 平板 dump 序列 A/B/C＋3477/3478；手机 dump＋3491 | 主页“?”拉起引导：第 1 步只有“下一步/跳过”；点“下一步”进第 2 步后 dump 同时出现“上一步/下一步/跳过”；点“上一步”dump 回到第 1 步（文案回到 `guide_home_1`）。按钮按 `index>0` 条件显示，符合预期。 |
| A201 | “下一步” | 通过 | 通过 | 3468、3486；dump 步骤点/文案 | 第 1→2 步：文案变为“点金色按钮开始写作”，步骤点第 2 个高亮；第 2→3 步：文案“底部一行是卷宗…”，第 3 个高亮。 |
| A202 | “知道了” | 通过 | 通过 | 平板 3469（第 3 步）/3474（关闭后）；手机 3492/3493 | 末步按钮为“知道了”；点后引导关闭（dump 无任何引导按钮，主页可点），`guide.home.seen` 保持 true。 |
| A203 | “跳过” | 通过 | 通过 | 平板 3481（前/后 dump：`[下一步,跳过]`→`[]`）；手机 3494 | 任意步显示；第 1 步点“跳过”后引导立即关闭，页面无残留暗层。 |
| A204 | 点遮罩/洞内 | 通过 | 通过 | 平板 3523/3524；手机 3495/3496 | 两种点法分别验证：①点洞外暗区（平板 800,2050；手机 600,2200）→ 关闭；②重新拉起后点洞内目标（平板 hero 800,1000；手机 hero 600,900）→ 关闭。dump 前后 `[下一步,跳过]`→`[]`。 |
| A205 | “查看成就” | **不可达** | **不可达** | 平板新装态 3541–3545；代码 `Index.ets:4428-4438`、`AchievementService.ets:126-176` | 仅 summary 弹窗渲染。汇总条只在迁移路径（`migrated=false` 且 fresh>0）出现；两机均已 migrated；新装平板清数据后首次评估早于任何成就达成（未出现 summary），`goal_1` 以单项弹窗出现（3545），故真机不可构造 summary 态。按钮代码接线正确，但无用户可达路径。 |
| A206 | “关闭” | 通过 | 通过 | 手机 3512→3513；平板 3545→3546 | 真实解锁弹窗上点“知道了”（即 `ach_dialog_close`）：弹窗消失、dump 无残留；prefs `achieve.goal_1=true`。若队列中还有下一条会继续弹（本批两次均为单条，未构造多队列）。 |
| A207 | 点遮罩关闭 | 通过 | 通过 | 手机 3538→3539；平板 3547→3548 | `words_1000` 单项弹窗上点卡外暗区（手机 600,600；平板 200,600）：弹窗关闭、dump 无残留；prefs `achieve.words_1000=true`。与 A206 的“关闭”按钮行为一致。 |
| A208 | 菜单项“收藏” | **不可达** | **不可达** | 代码 `Index.ets:1329,1322-1325,5559-5572`；设备 3535（打字机顶区无菜单）、3543（主页无菜单） | `menuOpen` 无置 true 入口，AppMenu 实例不可能出现；真机主页/打字机页也没有汉堡菜单入口。 |
| A209 | 菜单项“设置” | **不可达** | **不可达** | 同上 | 同上；设置只能从主页底部“设置”进入（正常路径）。 |
| A210 | 菜单项“导出” | **不可达** | **不可达** | 同上 | 同上；导出入口在文档视图/卷宗内页/出纸槽（正常路径）。 |
| A211 | 菜单点空白关闭 | **不可达** | **不可达** | 同上；`AppMenu.ets:52-55` | 菜单本身不可达，其关闭层一并不可达。DossierDetail 内另有活的 AppMenu（A61 已验），不属本项。 |

### 2.1 R10／R25／R11／O4 复核

| 风险 | 结论 | 证据 |
|---|---|---|
| R10 打字机页引导锚点无节点 | **双机确认** | 平板 hilog `21:14:27 guide anchor miss typewriter/1 typewriter__lever`、`21:15:12 … /2 typewriter__function_row`、`21:16:09 … /3 typewriter__paper`；手机 `20:23:39 /1`、`20:24:17 /2`、`20:24:22 /3`。两机 dump 全文 grep `typewriter__` 均为 0；三张截图为居中气泡＋整屏均匀压暗，无金边洞。 |
| R25 文档视图引导第 2 步锚点缺失 | **双机确认** | 平板 `21:18:10 guide anchor miss document_view/2 document_view__edit_btn`；手机 `20:29:19` 同。第 2 步气泡居中、无洞；step2 截图上页面无“编辑”（dump 中“编辑”仅出现 1 次，即引导文案）。第 3 步恢复有洞（`anchor document_view/3 id=document_view__delete_btn`）。 |
| R11 卷宗内页无“?” | **双机确认** | 平板 3530、手机 3505：页眉为 返回/封面/标题/（平板：导出、新建纸张）/⋯，无“?”。代码 `DossierDetailPage.ets:725-735` 用 `customHeader:true`，`PageShell` 只在默认页眉渲染 help（`PageShell.ets:77-86`）。 |
| O4 冷启动自动弹主页引导 | **未复现** | 起始 `guide.home.seen=true`；两机 `aa force-stop`→`aa start` 后 3s/8s 截图均为主页无引导（3464/3465/3466）；启动窗口无 `Spotlight` 日志。 |

R10/R25 的 hilog 原文摘录见 `docs/evidence/audit/item10-hilog-spotlight.txt`（两机 `guide anchor miss` 行）。

## 3. 问题清单

| 编号 | 对应 | 类型 | 问题 | 证据 | 复现/建议 |
|---|---|---|---|---|---|
| O1 | 聚光灯（新，双机） | 视觉（中低） | 聚光灯遮罩不压暗主页 hero **图片**：目标之外本应整块压暗，但 hero Image 在遮罩之上，保持原亮度，画面上同时出现“洞”和“hero”两块亮区；Text/按钮区域压暗正常。疑似 `Image(...).opacity(0.98)`（HomePage.ets:122/125）产生合成层，绘制顺序高于同层遮罩。 | 像素均值（PIL 区域均值，RGB）：平板 3464 无引导 hero=(133.2,121.8,108.0)，step2（hero 在洞外）3468=(130.8,119.6,105.8)，仅降 ~2%；同帧标题区 53.7→33.3、按钮区 194.8→65.1（约 55% 遮罩生效）。手机 3484 hero=143.0 → 3486=137.3（~4%），标题 48.4→36.3、按钮 81.2→32.6。 | 主页“?”→下一步（洞在按钮上），观察 hero 是否变暗。建议：去掉 Image 的 opacity 或把压暗层放到图片之上（如给 Image 容器加半透明遮罩/统一 zIndex），并回归主页/其它含 Image 的引导页。 |
| O2 | A205 | 可达性（中） | “查看成就”只在汇总弹窗出现，而汇总弹窗是迁移态专属；新装/已迁移用户永远看不到。 | `Index.ets:4429-4437` 仅在 `achNoticeKind==='summary'`；`AchievementService.evaluate` 迁移分支只在 `migrated=false` 且 fresh>0 时置 `summaryCount`。两机已 migrated；新装平板清数据后 `goal_1` 仍以单项弹窗出现（3545），说明首次评估早于成就达成。 | 无需修复可用性本身（收藏页可看成就），但清单/验收应把 A205 标为“不可达（迁移态专属）”，或给设计上补一个入口（若产品需要）。 |
| O3 | A208–A211 | 不可达（确认） | Index 全局菜单代码为死代码：`menuOpen` 无置 true 入口，菜单项与点空白关闭不可达。 | `Index.ets:1329` 初值 false；1322-1325、5563 只置 false；5559 起 `if (menuOpen)` 才挂 AppMenu。设备侧无任何菜单入口（3535、3543）。 | 建议清单保持“不可达”，并删除或接线该菜单（属清理项，不在本批修）。 |
| O4 | 测试环境 | 观察 | 核查期间设备被其它 App 反复抢占前台（漫画/阅读/备份与恢复/反馈中心），导致 26 张截图作废、部分点击落到别家 App。 | `void_*` 清单见 §6.2。 | 非产品问题；后续批次建议在设备无人占用时执行长时输入/连续点击。 |
| O5 | 观察 | 交互（低） | 引导“?”在引导已打开时点按会被当作点遮罩直接关闭（“?”位于顶栏，被整屏遮罩/顶块覆盖）。用户想“重看”时若已在引导中，会先关闭而非重开。 | 平板：引导打开时点 (1522,161) 后 dump 按钮消失；代码 `SpotlightOverlay` 的 maskRect/fallback 全屏 onClick 覆盖该区域。 | 非缺陷（引导内本就不应重开）；仅记录，避免验收误判为“? 无响应”。 |

## 4. 执行记录（摘要）

### 4.1 平板
1. 冷启动（`aa force-stop`/`aa start`）：3s/8s 均主页无引导（O4 未复现）；`guide.home.seen=true`。
2. 主页“?”(1522,161)→引导 step1/2/3：A201（1→2）、A200（2→1）、A202（末步“知道了”关闭）；每步 dump 断言。
3. 重新拉起：A203“跳过”关闭；A204 两种点法（暗区/洞内）各验证一次。
4. 设置→重播页面引导（重置 14 页 seen）→ 打字机：R10 三步截图＋`anchor miss` 日志＋dump 无锚点。
5. 卷宗→内页：R11 页眉无“?”；进文档视图：R25 第 1/2/3 步（第 2 步居中无洞、日志 `miss document_view__edit_btn`）。
6. 收尾：`bm clean -d`（数据清空）→ 启动引导（跳过）→ 设置每日目标 100 → 打字机：新装 `goal_1` 弹窗（3545）→ A206 关闭（3546）；补字到 1003 → `words_1000` 弹窗（3547）→ A207 遮罩关闭（3548）→ 恢复目标 500 → 回主页（3549）。

### 4.2 手机
1. 冷启动：3s/8s 主页无引导（O4 未复现）。
2. 主页“?”→A201/A200/A202/A203/A204 五项，均 dump 前后断言（3485–3496）。
3. 设置→重播页面引导（3499，prefs 实测 14 页全 false）→ 打字机 R10（3500–3502）→ 卷宗/内页 R11（3503–3505）→ 文档视图 R25（3507–3509）。
4. 设置每日目标 100（3510）→ 打字机输入：`goal_1` 弹窗（3512）→ A206 关闭（3513）；继续累计到 1000+ → `words_1000` 弹窗（3538）→ A207 遮罩关闭（3539）。
5. 恢复每日目标 500 → 回主页（3550）。

## 5. 测试残留

- **手机未 bm clean；平板本批主动 bm clean（为构造 A205/A206/A207 的新装态）**：
  - 平板：应用数据已清空重建（`bm clean -d`）。当前为新装数据：1 篇自动保存的测试文档（纸面为输入的大量 `q`，约 1003 字）、`stats.total.chars=1003`、`stats.day.chars=1003`、每日目标已恢复 500；`onboarding_seen=true`，`guide.home/settings/typewriter.seen=true`，其余 11 页 seen=false；成就新增 `goal_1`、`words_1000`。机器/删除方式为默认（1920s-upright／trash）。
  - 手机：未清数据。`stats.total.chars=1688`、`stats.day.chars=1688`、每日目标已恢复 500；成就新增 `goal_1`、`words_1000`；`guide.dossier/dossier_detail/document_view/home/settings/typewriter.seen=true`，其余 8 页（collection、collection_detail、customize、export、font_manager、paper_custom、pinyin_settings、trash）**被本批“重播页面引导”重置为 false**（其中 export／customize／pinyin_settings 在①-9 时为 true，状态已变化）；手机当前文档纸面被追加大量 `q` 字符（统计累计 1688 字），未新建文档。
  - 两机均停在主页（3549/3550）；App 进程存活，无崩溃。
- 作废截图 26 张（`void_*`，§6.2）；不删档、不参与索引。

## 6. 截图索引

全部位于 `docs/shots/`。编号 3463 未生成（冷启动 3s 帧与同名文件冲突被覆盖，由 3464 的 8s 帧覆盖 O4 判定）。

### 6.1 有效截图

| 编号 | 文件 | 说明 |
|---|---|---|
| 3464 | `3464_audit10_tablet_coldstart_home_8s.png` | 平板 冷启动 8s：主页、无自动引导（O4） |
| 3465 | `3465_audit10_phone_coldstart_home_3s.png` | 手机 冷启动 3s：主页、无引导（O4） |
| 3466 | `3466_audit10_phone_coldstart_home_8s.png` | 手机 冷启动 8s：主页、无引导（O4） |
| 3467 | `3467_audit10_tablet_home_guide_s1.png` | 平板 主页引导第 1 步（hero 有洞） |
| 3468 | `3468_audit10_tablet_home_guide_s2.png` | 平板 第 2 步（按钮有洞；hero 未压暗＝O1） |
| 3469 | `3469_audit10_tablet_home_guide_s3.png` | 平板 第 3 步（底部导航有洞，“知道了”） |
| 3474 | `3474_audit10_tablet_guide_ok_closed.png` | 平板 点“知道了”后关闭 |
| 3477 | `3477_audit10_tablet_a200_prev_back_s1.png` | 平板 下一步→上一步回到第 1 步 |
| 3478 | `3478_audit10_tablet_a200_accepted_s1.png` | 平板 同上（dump 验证后的确认帧） |
| 3481 | `3481_audit10_tablet_a203_skip_closed2.png` | 平板 点“跳过”后关闭 |
| 3484 | `3484_audit10_phone_home_front.png` | 手机 主页（起始） |
| 3485 | `3485_audit10_phone_home_guide_s1.png` | 手机 引导第 1 步 |
| 3486 | `3486_audit10_phone_a201_next_s2.png` | 手机 第 2 步（A201） |
| 3491 | `3491_audit10_phone_a200_prev_verified_s1.png` | 手机 上一步回到第 1 步（A200，dump 前后验证） |
| 3492 | `3492_audit10_phone_a202_step3.png` | 手机 第 3 步（“知道了”） |
| 3493 | `3493_audit10_phone_a202_ok_closed.png` | 手机 点“知道了”关闭（A202） |
| 3494 | `3494_audit10_phone_a203_skip_closed.png` | 手机 点“跳过”关闭（A203） |
| 3495 | `3495_audit10_phone_a204_mask_closed.png` | 手机 点暗区关闭（A204） |
| 3496 | `3496_audit10_phone_a204_hole_closed.png` | 手机 点洞内关闭（A204） |
| 3497 | `3497_audit10_phone_typewriter_page.png` | 手机 打字机页（顶区无“?”/菜单） |
| 3498 | `3498_audit10_phone_home_for_settings.png` | 手机 主页（进设置前） |
| 3499 | `3499_audit10_phone_settings_replay_guide.png` | 手机 设置页“重播页面引导”已点（无可见提示，R5） |
| 3500 | `3500_audit10_phone_r10_typewriter_guide_s1.png` | 手机 R10 第 1 步：居中气泡、无洞 |
| 3501 | `3501_audit10_phone_r10_typewriter_guide_s2.png` | 手机 R10 第 2 步：居中气泡、无洞 |
| 3502 | `3502_audit10_phone_r10_typewriter_guide_s3.png` | 手机 R10 第 3 步：居中气泡、无洞 |
| 3503 | `3503_audit10_phone_dossier_guide_auto.png` | 手机 卷宗页首次引导自动弹出（上下文） |
| 3504 | `3504_audit10_phone_detail_guide_auto.png` | 手机 卷宗内页首次引导自动弹出（上下文） |
| 3505 | `3505_audit10_phone_r11_detail_header_no_help.png` | 手机 内页页眉无“?”（R11） |
| 3507 | `3507_audit10_phone_r25_docview_guide_s1.png` | 手机 R25 第 1 步：内容区有洞 |
| 3508 | `3508_audit10_phone_r25_docview_guide_s2.png` | 手机 R25 第 2 步：居中气泡、无洞；文案指向不存在的“编辑” |
| 3509 | `3509_audit10_phone_r25_docview_guide_s3.png` | 手机 R25 第 3 步：删除按钮有洞 |
| 3510 | `3510_audit10_phone_goal_slider_drag.png` | 手机 每日目标拖到 100（测试准备） |
| 3511 | `3511_audit10_phone_type_one_q.png` | 手机 打一个 q（纸面 niq） |
| 3512 | `3512_audit10_phone_type_60q.png` | 手机 真实解锁 `goal_1`（首达每日目标）弹窗 |
| 3513 | `3513_audit10_phone_a206_close_ok.png` | 手机 点“知道了”关闭，弹窗消失（A206） |
| 3522 | `3522_audit10_tablet_state_now.png` | 平板 重新拉回前台（主页） |
| 3523 | `3523_audit10_tablet_a204_mask_closed.png` | 平板 点暗区关闭（A204） |
| 3524 | `3524_audit10_tablet_a204_hole_closed.png` | 平板 点洞内关闭（A204） |
| 3525 | `3525_audit10_tablet_r10_typewriter_guide_s1.png` | 平板 R10 第 1 步：居中气泡、无洞 |
| 3526 | `3526_audit10_tablet_r10_typewriter_guide_s2.png` | 平板 R10 第 2 步 |
| 3527 | `3527_audit10_tablet_r10_typewriter_guide_s3.png` | 平板 R10 第 3 步 |
| 3528 | `3528_audit10_tablet_dossier_guide_auto.png` | 平板 卷宗页首次引导自动弹出（上下文） |
| 3529 | `3529_audit10_tablet_detail_guide_auto.png` | 平板 内页首次引导自动弹出（上下文） |
| 3530 | `3530_audit10_tablet_r11_detail_header_no_help.png` | 平板 内页页眉无“?”（R11） |
| 3531 | `3531_audit10_tablet_r25_docview_guide_s1.png` | 平板 R25 第 1 步：内容区有洞 |
| 3532 | `3532_audit10_tablet_r25_docview_guide_s2.png` | 平板 R25 第 2 步：居中无洞、文案指向“编辑” |
| 3533 | `3533_audit10_tablet_r25_docview_guide_s3.png` | 平板 R25 第 3 步：删除按钮有洞 |
| 3534 | `3534_audit10_tablet_settings_guide_auto.png` | 平板 设置页自动引导（重置后，上下文） |
| 3535 | `3535_audit10_tablet_typewriter_for_typing.png` | 平板 打字机页（顶区无“?”/菜单） |
| 3538 | `3538_audit10_phone_words1000_try.png` | 手机 真实解锁 `words_1000`（初试锋芒）弹窗 |
| 3539 | `3539_audit10_phone_a207_mask_closed.png` | 手机 点遮罩关闭，弹窗消失（A207） |
| 3541 | `3541_audit10_tablet_fresh_onboarding.png` | 平板 bm clean 后 启动引导 |
| 3542 | `3542_audit10_tablet_fresh_settings_guide.png` | 平板 新装 设置页引导 |
| 3543 | `3543_audit10_tablet_home_fresh.png` | 平板 新装 主页（0/目标 100） |
| 3544 | `3544_audit10_tablet_fresh_typewriter_guide.png` | 平板 新装 打字机引导 |
| 3545 | `3545_audit10_tablet_a205_summary_dialog.png` | 平板 新装 `goal_1` 单项弹窗（非 summary，证明 A205 不可达） |
| 3546 | `3546_audit10_tablet_a206_close_ok.png` | 平板 关闭后弹窗消失（A206） |
| 3547 | `3547_audit10_tablet_words1000_dialog.png` | 平板 `words_1000` 弹窗（A207 前置） |
| 3548 | `3548_audit10_tablet_a207_mask_closed.png` | 平板 点遮罩关闭（A207） |
| 3549 | `3549_audit10_tablet_home_end.png` | 平板 收工主页 |
| 3550 | `3550_audit10_phone_home_end.png` | 手机 收工主页 |

### 6.2 作废截图（`void_` 前缀，26 张）

`void_3470`（步骤状态滞后）、`void_3471`（旧帧）、`void_3472`／`void_3475`／`void_3482`／`void_3489`／`void_3514`／`void_3516`／`void_3521`（其它 App 抢占前台）、`void_3473`／`void_3476`／`void_3479`／`void_3480`／`void_3483`／`void_3487`／`void_3488`／`void_3490`／`void_3506`／`void_3515`／`void_3517`／`void_3518`／`void_3519`／`void_3520`／`void_3536`／`void_3537`／`void_3540`（未构成目标状态/点击未命中）。

## 7. 清单状态建议（不改清单文件，供 Kit 统一维护）

- A200–A204：改“已验证（2026-11-25 双机）”。
- A205：改“不可达（迁移态专属；代码接线正确，真机无路径）”。
- A206、A207：改“已验证（2026-11-25 双机，真实成就解锁）”。
- A208–A211：保持“不可达”，并注明本批已用代码＋设备双向确认（`menuOpen` 无 true 入口）。
- R10／R25／R11：保持“已确认”，证据补本批截图/日志。
- O4（①-7 遗留）：本批双机未复现，建议保持“待确认”，不计为已关闭。
- 新增建议风险：O1（聚光灯遮罩不压暗 Image，双机；视觉，中低）；O2（A205 汇总态不可达，建议并入清单 A205 备注）；O3（A208–A211 死代码，已有 R3 覆盖，可并入 R3）；O5（引导中“?”被遮罩吞掉，观察，不单列风险）。
