# 核查①-6：收藏页＋收藏详情双机逐项核查（A85–A95）

- 核查日期：2026-11-25
- 分支：`audit06-collection`（base `main` HEAD `f357b0e`）
- 范围：`docs/evidence/audit/item01-inventory.md` §9 收藏页（A85–A92，8 项）＋ §10 收藏详情（A93–A95，3 项），共 **11 项**；关联风险 **R6**（2020s 现代机覆盖不全）。
- 设备与构建：
  - 平板 MLR-AL10（HUAWEI MatePad Mini），1600×2560，`192.168.5.133:42355`（TCP）
  - 手机 ADA-AL00U（nova 12 Ultra），1224×2776，`2UCUT24724009680`（USB）
  - 两台沿用 audit①-5 同一安装包；本批未重新构建/安装，分支相对 base 无代码改动。

## 0. 起始状态（先记录，再操作）

1. **平板**：App 在前台、停在主页，今日 48/500、已写 5 字——`2821`；`machine` 偏好 = `1920s-upright`，`guide.collection.seen=false`、`guide.collection_detail.seen=false`（首次进入会自动弹引导）。
2. **手机**：App 在前台、停在主页，今日 47/500、已写 5 字——`2822`；`machine` 同样 = `1920s-upright`，两个收藏引导 seen 均为 false。
3. 与任务描述一致：两机均未 `bm clean`（audit①-5 残留）；卷宗/纸/回收站数据本批**未改动**（见 §9）。
4. **本批新建/改动的测试数据**：没有新建文档、纸、卷宗或导出文件。唯一持久改动是「设为当前机器」：两机按 1920s→1930s→1950s→1960s→2020s→1920s 各切 6 次，最终已恢复 `1920s-upright`；两个收藏引导的 seen 标记由 false 变 true（页面引导已看过的正常副作用）。

## 1. 结论摘要

- A85–A95 共 11 项、双机逐项操作：**11 项双机通过**（A92 为“符合预期的不可达”）。无崩溃、无卡死；收藏页/详情页的返回、引导、五张机器卡、设为当前机器均可用。
- **R6 已真机确认（收藏相关部分）**：
  - **收藏详情 2020s 史实段落为空**（O1）：`CollectionDetailPage.ets:15-20` 的 `M_INFO` 只有四台机；2020s 详情页大图/两张特写/进度区都在，唯独机器史实段落不渲染、版面直接接到“总字数”行（平板 `2845`、手机 `2878`）。
  - **设置页机名回落 1920s**（O2）：设为当前 2020s 后，`prefs=2020s-modern`、hilog `collection setCurrent -> 2020s-modern`，但设置页“默认机器”仍显示“1920s 直立式”（平板 `2847`、手机 `2881`）。代码 `Index.ets:4656-4661` 只判三台，其余一律回落 1920s。
  - **主页 hero 图回落 1960s**（O3）：当前机 2020s 时主页机器图仍是 1960s 机体（平板 `2846` vs `2844`、手机 `2879` vs `2876` 为同一张 1960s 图）；代码 `HomePage.ets:114-126` 的 `else` 分支固定 1960s。打字机页本身正确换成 2020s 主题（平板 `2848`、手机 `2882`；hilog `reloadKeymap path=keymap/2020s-modern-keymap.json`），说明换机已生效，只是主页/设置页的回显没跟上。
  - **收藏页仍写“四台”**（O4）：副标题“四台机共享同一批纸与文档。”、引导第 1 步“收藏里是四台不同年代的原型机。”，实际网格是五张卡（平板 `2823/2851`、手机 `2854`）。与核查①-2 O2（引导“四台时代机”）同族。
- **新发现 O5（低/中）**：收藏页没有“当前机器”标识；1920s 卡的“默认机器”是静态资源 `machine_cond_1920s`，设为 2020s 后仍显示（平板 `2849`、手机 `2884`）。清单 A87 的“默认机器”条件行在五台全开的现状下已不具备状态含义。
- **O6（低）**：2020s 卡的条件行是整句描述 `machine_cond_modern`（“保养良好、日常使用，键帽象牙白、机身薄荷绿，功能一切正常。”），与其余四台的“待定（阈值待批准）/默认机器”语义不同，且 `maxLines(1)` 截断（平板截到“功能一”、手机截到“键帽”，无可见省略号）；`2828`/`2877`。
- **A92 符合预期**：收藏页无提示条；`CollectionPage.hintText` 全仓只有置 null（`CollectionPage.ets:84,328`），HintBar 渲染空串；双机截图均无提示条（`2826`/`2857`）。

## 2. 逐项结果

> 结果口径：**通过**＝该控件在双机真机上完成预期操作且画面/落盘可证；**通过（符合预期）**用于清单本身预期即“不可达/占位”的控件。判定以截图为准，hilog/落盘文件只作辅助。

| 编号 | 控件 | 平板 | 手机 | 关键证据（截图号） | 实际操作与结论 |
|---|---|---|---|---|---|
| A85 | 返回 | **通过** | **通过** | 2829 / 2858；2830 / 2859 | 收藏页左上返回 → 弹栈回主页（主页 hero、统计、底部入口可见）；再点主页“收藏”可重新进入（卡片恢复）。 |
| A86 | 引导“?” | **通过** | **通过** | 2823（首次自动）、2824/2825（第 2/3 步）、2851（手动“?”）、2854–2856（手机） | 首次进收藏页自动弹 3 步引导；完成后点页眉“?”可再次拉起。**引导文案“四台”见 O4**，但“打开引导”本身达成。 |
| A87 | 1920s 机器卡 | **通过** | **通过** | 2830/2831 / 2857/2860 | 卡片“1920s 直立式 / 已拥有 / 默认机器”；点按进详情；详情大图、键盘/滚筒特写、史实段落、进度三行、底部按钮齐全。 |
| A88 | 1930s 机器卡 | **通过** | **通过** | 2839 / 2869 | 卡片“1930s 便携式 / 已拥有 / 待定（阈值待批准）”；详情四块内容齐全，史实段落正确。 |
| A89 | 1950s 机器卡 | **通过** | **通过** | 2841 / 2873 | 同上；1950s 史实段落正确。 |
| A90 | 1960s 机器卡 | **通过** | **通过** | 2843 / 2875 | 同上；1960s 史实段落正确。 |
| A91 | 2020s 机器卡 | **通过** | **通过** | 2827/2828、2872/2877、2845 / 2878 | 卡片“现代薄荷 / 已拥有 / 保养良好…（截断）”，可进详情；**详情史实段落空白（O1/R6）**；卡片条件行见 O6。 |
| A92 | 顶部提示条点按关闭 | **通过（符合预期：不可达）** | **通过（符合预期：不可达）** | 2826 / 2857；代码 CollectionPage:84,325,328 | 收藏页顶部无提示条；`hintText` 从无赋值，HintBar 只渲染空串。与清单“未接线”一致，本批不把它当缺陷。 |
| A93 | 返回（详情） | **通过** | **通过** | 2837 / 2865；2888 回主页 | 详情页左上返回 → 弹栈回收藏页（五张卡仍在）；再返回可回主页。 |
| A94 | 引导“?”（详情） | **通过** | **通过** | 2831–2833、2835/2836 / 2860–2862、2886/2887 | 首次进详情自动弹 3 步（intro→进度→底部按钮，洞里均能看到对应区域）；关闭后点“?”可重拉（平板 `2835`、手机 `2887`）。 |
| A95 | “设为当前机器” | **通过** | **通过** | 平板 2838/2840/2842/2844/2846、手机 2868/2870/2874/2876/2879；hilog 见 §6；prefs 见 §6 | **五台机逐台双机验证**：点按后均 `popTo('home')` 回主页；hilog `collection setCurrent -> <kind>`；`prefs.machine` 同步为对应 kind。1930s/1950s/1960s 主页 hero 与机型一致；2020s 的显示回落见 O2/O3。最后恢复 1920s（`2850`/`2885`，prefs 回到 `1920s-upright`）。 |

> 五张卡的“已拥有”状态在两机均可见（无锁定罩/锁图标），与清单“机器永久解锁”一致。

## 3. 问题清单

| 编号 | 对应 | 类型 | 问题 | 证据 | 复现（双机通用） |
|---|---|---|---|---|---|
| O1 | A91；R6 | 内容缺失（中） | **2020s 收藏详情缺机器史实段落**：大图、键盘/滚筒特写、进度三行都在，唯 `M_INFO['2020s-modern']` 未定义，`Text(undefined)` 不渲染；版面直接由特写接到“总字数”。代码：`CollectionDetailPage.ets:15-20`（仅 1920s/1930s/1950s/1960s），`string.json` 也无 `machine_info_modern`。 | 平板 2845、手机 2878（与 2839/2869 等四台详情对比：四台在特写和进度之间有 4 行史实文字，2020s 没有）。 | 收藏页 → 滚到“现代薄荷”卡 → 进详情，观察特写与“总字数”之间。 |
| O2 | A95；R6 | 文案/回显缺陷（中） | **设为当前 2020s 后，设置页“默认机器”仍显示“1920s 直立式”**，与 prefs/hilog 冲突。代码 `Index.machineLabelText()` 只判 1930s/1950s/1960s，其余回落 `machine_name_1920s`。 | 平板 2847、手机 2881；同一时刻 `prefs.machine=2020s-modern`、hilog `setCurrent -> 2020s-modern`。 | 收藏 → 现代薄荷详情 → 设为当前机器 → 主页 → 设置 → 下滑到“默认”组看“默认机器”行。 |
| O3 | A95；R6 | 视觉回退（中） | **当前机 2020s 时主页 hero 仍显示 1960s 机体图**；2020s 有 `machine/2020s-modern-front.jpg`，但 `HomePage.ets:114-126` 的 else 固定 1960s。 | 平板 2846 与 2844（1960s 时主页）为同一张图；手机 2879 与 2876 同理；打字机页 2848/2882 才是 2020s 主题。 | 按 O2 路径设为 2020s 后回主页看机器图。 |
| O4 | A86；R6 同族 | 文案不一致（低） | 收藏页副标题与引导第 1 步仍称“四台机/四台不同年代的原型机”，实际五张卡、五台机型。 | 平板 2823/2851、手机 2854；资源 `string.json` 的 `guide_collection_hint`、`guide_collection_1`。 | 进收藏页看副标题；点“?”看第 1 步。 |
| O5 | A87（观察，新） | 状态标识缺失（低/中） | 收藏页没有“当前机器”标识；1920s 卡的“默认机器”是静态条件行，切到 2020s 后仍显示“默认机器”，用户无法从收藏页判断哪台是当前机。 | 平板 2849、手机 2884（当前机已是 2020s，1920s 卡仍写“默认机器”）；代码 `CollectionPage.ets:62-69` 的 `M_COND` 为常量资源。 | 设为 2020s → 回收藏页看 1920s 卡底行。 |
| O6 | A91（观察，低） | 文案/截断 | 2020s 卡条件行是整句描述（`machine_cond_modern`），与其它四台的“默认机器/待定（阈值待批准）”语义不一致；`maxLines(1)` 截断后看不到完整句（平板截到“功能一”，手机截到“键帽”），且截断处未见省略号。 | 平板 2828、手机 2877（缩放页 2827）。 | 收藏页滚到“现代薄荷”卡看底部条件行。 |

> R6 的另外两处代码线索本批未测：`ExportCore.ets:265-281`（PDF 抬头机名回落 1920s，属导出批次）、`Index.ets:4671-4675`（`cycleMachine` 只循环四台，属设置批次）。本批只对“收藏详情 / 设置机名 / 主页 hero”三处给了真机证据。

## 4. 清单状态建议（仅建议，未修改清单文件）

| 条目 | 清单现状态 | 建议 |
|---|---|---|
| A85–A90 | 已接线 | 保持；备注“2026-11-25 双机真机通过”。 |
| A91 | 已接线 | 保持；备注“双机通过（卡片/详情入口）；详情史实空白、卡片条件行截断见 R6/O1/O6”。 |
| A92 | 未接线 | 保持“未接线”（预期状态）；备注“2026-11-25 双机确认：收藏页无提示条，hintText 从不置值”。 |
| A93、A94 | 已接线 | 保持；备注“双机通过”。 |
| A95 | 已接线 | 保持；备注“五台机逐台双机通过；prefs/hilog 一致；2020s 的机名/主页图回落见 R6”。 |
| R6 | 待确认（风险） | **建议改“部分确认（2026-11-25）”**：收藏详情史实缺、设置页机名回落、主页 hero 回落已双机截图确认；PDF 抬头与 `cycleMachine` 循环仍待导出/设置批次。建议在 R6 备注补 O4（收藏页“四台”文案）与 O1/O2/O3 的截图号。 |
| 新增 R | — | 建议新增 **R26：收藏页无当前机标识，1920s 卡“默认机器”静态、切机后不更新**（O5）；O6 可作为 A91 备注或并入 R26。 |

## 5. 操作流水（可复核）

### 5.1 平板 MLR-AL10

1. 起始主页（2821）→ 底部“收藏”进收藏页，首次自动引导（2823）→ 第 2/3 步（2824/2825）→ 知道了（2826，无提示条）。
2. 收藏网格内上滑看第五张 2020s 卡（2827/2828，条件行截断见 O6）。
3. A85：左上返回主页（2829）→ 再进收藏（2830）。
4. A87：点 1920s 卡进详情，首次自动引导（2831）→ 第 2/3 步（2832/2833）→ 知道了（2834）→ A94 点“?”重拉（2835）→ 跳过（2836）→ A93 返回收藏（2837）。
5. A95：再进 1920s 详情 → 设为当前（2838，hilog 10:59:59）。
6. A88 1930s 详情（2839）→ 设为当前（2840，11:00:25）。
7. A89 1950s 详情（2841）→ 设为当前（2842，11:00:55）。
8. A90 1960s 详情（2843）→ 设为当前（2844，11:01:24）。
9. A91：滚到 2020s 详情（2845，史实空白）→ 设为当前（2846，11:02:36）→ 主页 hero 仍是 1960s 图（O3）→ 设置页“默认机器=1920s 直立式”（2847，O2）→ 进打字机确认 2020s 主题（2848，hilog reloadKeymap 2020s-modern；返回主页）。
10. 回收藏页：1920s 卡仍“默认机器”（2849，O5）→ 恢复 1920s 为当前（2850，11:04:26，prefs=1920s-upright）。
11. A86 手动“?”重拉引导（2851）→ 跳过（2852）。
12. 收尾异常：11:18 从收藏页返回主页时，界面变成窄窗/letterbox（2889）；冷启动仍窄窗（2890）；随后重启设备，平板进入“重启后需要输入密码”锁屏（2891），无法由 hdc 自动解锁（见 §7/§9）。

### 5.2 手机 ADA-AL00U

1. 起始主页（2822/2853）→ 底部“收藏”进收藏页，首次自动引导（2854）→ 第 2/3 步（2855/2856）→ 知道了（2857，无提示条）。
2. A85：左上返回主页（2858）→ 再进收藏（2859）。
3. A87：点 1920s 卡进详情，首次自动引导（2860）→ 第 2/3 步（2861/2862）。
4. A94/A93 首次尝试受点击时序影响（2863/2864、2866/2867 已作废，见 §10）；用更长等待受控复测：关闭态详情（2886）→ 点“?”重拉引导（2887）→ 跳过 → 返回收藏。
5. A95：1920s 设为当前（2868，11:09:46）。
6. A88 1930s 详情（2869）→ 设为当前（2870，11:10:08）。
7. 滚动到第二行（2871/2872）→ A89 1950s 详情（2873）→ 设为当前（2874，11:11:44）。
8. A90 1960s 详情（2875）→ 设为当前（2876，11:12:27）。
9. A91：滚到 2020s 详情（2877/2878，史实空白）→ 设为当前（2879，11:14:04）→ 主页 hero 仍是 1960s 图（O3）→ 设置页下滑看“默认机器=1920s 直立式”（2880/2881，O2）→ 打字机确认 2020s 主题（2882，hilog reloadKeymap 2020s-modern）→ 返回主页（2883）。
10. 回收藏页：1920s 卡仍“默认机器”（2884，O5）→ 恢复 1920s 为当前（2885，11:16:18，prefs=1920s-upright）→ 收尾主页（2888）。

## 6. 证据文件

- `docs/evidence/audit/item06-hilog.txt`：本批两台设备的 `collection setCurrent`／`reloadKeymap` 摘录（操作当刻读取；环形缓冲滚动快，早期行已被覆盖，原样抄录）。
- `docs/evidence/audit/item06-prefs-tablet.xml`、`item06-prefs-phone.xml`：收工时的 `carriagereturn_prefs`（两机 `machine=1920s-upright`；`guide.collection.seen=true`、`guide.collection_detail.seen=true`）。逐台 set-current 过程中每次点击后取该文件，machine 值与 hilog 一一对应。
- 本报告所有“通过/不通过”以截图为准（AGENTS 识屏验收铁律），hilog/落盘文件只作辅助。

## 7. 缺口与未验项

1. **R6 未闭环部分**：`ExportCore` 的 PDF 抬头机名回落（`ExportCore.ets:265-281`）须在导出批次验；`cycleMachine` 只循环四台（`Index.ets:4671-4675`）须在设置批次验。本批不能据此宣称 R6 全部修复/全部确认。
2. **A92 无操作路径**：`hintText` 无赋值，只能验证“不出现”；本批未构造注入（属内部状态，无 UI 入口）。
3. **动画未逐帧**：页面滑动 250ms、AppDialog/聚光灯步骤切换均未逐帧；`snapshot_display` 单帧 400–500ms，按 AGENTS 工具边界不连拍冒充。
4. **手机 4 张重复截图作废**：2863/2864、2866/2867 因点击/截图时序与预期错位，统一用受控复测的 2886/2887 取代（见 §10）。这不是产品问题，保留作过程证据。
5. **平板收尾异常未能复验**：11:18 起平板出现系统级窄窗/letterbox（2889/2890），随后重启进入锁屏（2891）。异常出现前 A85–A95 的全部平板证据（2821–2852）均为正常全屏；异常画面里 App 侧无相关日志，未观察到 App 代码改窗路径，暂记系统/窗口模式异常，待解锁后复核。**平板当前不可用（需人工输入锁屏密码），是下一批次的阻塞项。**
6. **2020s 史实空白的渲染行为**：`Text(M_INFO[...])` 传入 undefined，真机表现为整段不渲染、无占位、无崩溃；未再往 SDK 层追。

## 8. 工具与方法注记

- `hdc` 不在 PATH，实际路径 `F:\HarmonyOS\SDK\26.0.0\toolchains\hdc.exe`。
- 截图：`snapshot_display -f /data/local/tmp/_cap.jpeg` → `hdc file recv` → PIL 转 PNG；开工亮度平板 51.3 / 手机 66.5。
- 点按/滑动：`uitest uiInput click/swipe`；本机无 `input` 命令（AGENTS）。页内返回统一点页眉左上角：平板标准页眉 `(60,164)`、手机标准页眉 `(89,210)`；页眉“?”平板 `(1530,170)`、手机 `(1112,218)`。
- **dump 会包含已挂载但不可见的页面**（主页常驻、收藏页在详情之下）：本批坐标用 dump 取、状态一律补截图确认；例如手机 dump 里同时存在收藏卡文本与详情文本，不能只看节点存在。
- 点击仍偶发丢失（同一条命令重发即成功）；手机详情引导的 2863/2864、2866/2867 即受此影响，改用 3 秒级等待＋每步 dump 后复测（2886/2887）。
- 平板收尾异常：11:18 返回主页时出现约 1000px 宽的居中窄窗/黑边（2889），冷启动（2890）仍旧；尝试重启设备后进入“重启后需要输入密码”锁屏（2891）。`aa start` 报错原文：`Error Code:10106102 Error Message:The device screen is locked during the application launch, unlock screen failed. Error cause: The current mode is developer mode, and the screen cannot be unlocked automatically`。本机无 `input` 命令，`power-shell wakeup`/`uitest keyEvent 18` 只能亮屏，不能过密码锁（与 docs/自检记录.md:2433 的既有结论一致）。
- 屏幕常亮：手机 `power-shell timeout -o 2147483647`＋`wakeup`＋`setmode 602`；平板重启后同组命令已执行，但停在锁屏。

## 9. 测试残留与收工状态

- 两台均**未** `bm clean`；本批**没有**新建/删除文档、纸、卷宗或导出文件，卷宗计数应保持 audit①-5 收工值（平板未归档 3 / 测试卷宗二号 2；手机未归档 2 / 测试卷宗二号 2）。平板无法在收工前复核（锁屏），手机主页统计仍为 47/500、已写 5 字（2888）。
- **当前机型**：两机均已恢复 `1920s-upright`（prefs 与 hilog 双证）；本批中途五台机各切换一次并落盘，最终回到默认。
- **收藏引导 seen**：两机 `guide.collection.seen` 与 `guide.collection_detail.seen` 已由 false 变 true；后续批次进收藏页/详情不会再自动弹引导，需要看引导请走页眉“?”或设置“重播页面引导”。
- **平板处于锁屏**（2891：“重启后需要输入密码”），需人工解锁后才能继续平板侧工作；这是本批唯一阻塞残留。手机正常停在主页。
- 门图影响：本批未改纸面与文档集合，但两机纸面仍为 audit①-3 以来的测试内容；跑 1920s 门图或其它验收前仍须 `bm clean` 或换纸清空，并按 AGENTS §5 仪式重拍/比对。
- 本批临时 dump/截图（`.dump_*.json`、`_probe_*`、`_prefs/`）未入库；`_probe_*` 已清理。

## 10. 截图索引（2821–2891，共 71 张，其中 4 张作废）

> 编号规则：`<编号>_audit06_<设备>_<主题>.png`，均存 `docs/shots/`。文件名即内容摘要；逐项证据见 §2。

### 10.1 平板（2821–2852 正常操作 31 张 + 2889–2891 异常记录 3 张，共 34 张）

| 编号 | 文件 | 内容 |
|---|---|---|
| 2821 | `2821_audit06_tablet_start_state.png` | 起始：主页 48/500 |
| 2823 | `2823_audit06_tablet_collection_first_entry_guide.png` | 收藏页首次进入自动引导（第 1 步，文案“四台”） |
| 2824 | `2824_audit06_tablet_collection_guide_step2.png` | 收藏引导第 2 步 |
| 2825 | `2825_audit06_tablet_collection_guide_step3.png` | 收藏引导第 3 步 |
| 2826 | `2826_audit06_tablet_collection_clean_no_hintbar.png` | 关闭引导后的收藏页（无提示条，A92） |
| 2827 | `2827_audit06_tablet_collection_scroll_2020s.png` | 网格上滑露出 2020s 卡上半 |
| 2828 | `2828_audit06_tablet_collection_scroll_end_2020s.png` | 2020s 卡完整（条件行截断，O6） |
| 2829 | `2829_audit06_tablet_collection_back_home.png` | A85 返回主页 |
| 2830 | `2830_audit06_tablet_collection_reenter.png` | 再次进入收藏页 |
| 2831 | `2831_audit06_tablet_detail_1920s_first_entry_guide.png` | 1920s 详情首次自动引导 |
| 2832 | `2832_audit06_tablet_detail_guide_step2.png` | 详情引导第 2 步（进度区） |
| 2833 | `2833_audit06_tablet_detail_guide_step3.png` | 详情引导第 3 步（底部按钮） |
| 2834 | `2834_audit06_tablet_detail_1920s_clean.png` | 关闭引导后的 1920s 详情 |
| 2835 | `2835_audit06_tablet_detail_guide_from_help.png` | A94 点“?”重拉引导 |
| 2836 | `2836_audit06_tablet_detail_guide_dismissed.png` | 跳过引导后的详情 |
| 2837 | `2837_audit06_tablet_detail_back_to_collection.png` | A93 返回收藏页 |
| 2838 | `2838_audit06_tablet_setcurrent_1920s_home.png` | A95 1920s 设为当前 → 主页 |
| 2839 | `2839_audit06_tablet_detail_1930s.png` | 1930s 详情（史实段落正确） |
| 2840 | `2840_audit06_tablet_setcurrent_1930s_home.png` | A95 1930s → 主页 hero 为 1930s |
| 2841 | `2841_audit06_tablet_detail_1950s.png` | 1950s 详情 |
| 2842 | `2842_audit06_tablet_setcurrent_1950s_home.png` | A95 1950s → 主页 hero 为 1950s |
| 2843 | `2843_audit06_tablet_detail_1960s.png` | 1960s 详情 |
| 2844 | `2844_audit06_tablet_setcurrent_1960s_home.png` | A95 1960s → 主页 hero 为 1960s |
| 2845 | `2845_audit06_tablet_detail_2020s.png` | 2020s 详情：史实段落空白（O1/R6） |
| 2846 | `2846_audit06_tablet_setcurrent_2020s_home.png` | A95 2020s → 主页 hero 仍是 1960s 图（O3） |
| 2847 | `2847_audit06_tablet_settings_machine_label_2020s.png` | 设置“默认机器=1920s 直立式”（O2） |
| 2848 | `2848_audit06_tablet_typewriter_2020s.png` | 打字机 2020s 主题（换机已生效） |
| 2849 | `2849_audit06_tablet_collection_default_label_while_2020s_current.png` | 当前 2020s 时 1920s 卡仍“默认机器”（O5） |
| 2850 | `2850_audit06_tablet_setcurrent_1920s_restore_home.png` | 恢复 1920s → 主页 |
| 2851 | `2851_audit06_tablet_collection_guide_from_help.png` | A86 点“?”重拉收藏引导 |
| 2852 | `2852_audit06_tablet_collection_after_help_skip.png` | 跳过后的收藏页（平板最后一张正常全屏） |
| 2889 | `2889_audit06_tablet_window_mode_anomaly_home.png` | 11:18 收尾时系统窄窗/letterbox 异常（见 §7.5） |
| 2890 | `2890_audit06_tablet_window_mode_anomaly_after_restart.png` | 冷启动后仍窄窗 |
| 2891 | `2891_audit06_tablet_locked_after_reboot.png` | 重启后落到“重启后需要输入密码”锁屏 |

### 10.2 手机（2822、2853–2888，共 37 张；含 4 张作废）

| 编号 | 文件 | 内容 |
|---|---|---|
| 2822 | `2822_audit06_phone_start_state.png` | 起始：主页 47/500 |
| 2853 | `2853_audit06_phone_home_before_collection.png` | 进收藏前的主页 |
| 2854 | `2854_audit06_phone_collection_entry_guide.png` | 收藏页首次进入自动引导（文案“四台”） |
| 2855 | `2855_audit06_phone_collection_guide_step2.png` | 收藏引导第 2 步 |
| 2856 | `2856_audit06_phone_collection_guide_step3.png` | 收藏引导第 3 步 |
| 2857 | `2857_audit06_phone_collection_clean_no_hintbar.png` | 关闭引导后的收藏页（无提示条） |
| 2858 | `2858_audit06_phone_collection_back_home.png` | A85 返回主页 |
| 2859 | `2859_audit06_phone_collection_reenter.png` | 再次进入收藏页 |
| 2860 | `2860_audit06_phone_detail_1920s_first_entry_guide.png` | 1920s 详情首次自动引导 |
| 2861 | `2861_audit06_phone_detail_guide_step2.png` | 详情引导第 2 步 |
| 2862 | `2862_audit06_phone_detail_guide_step3.png` | 详情引导第 3 步 |
| void | `void_2863_audit06_phone_detail_guide_step1_dup.png` | 作废：时序错位的重复尝试（实际内容为引导第 1 步） |
| void | `void_2864_audit06_phone_detail_clean_dup.png` | 作废：同上（实际内容为关闭态详情） |
| 2865 | `2865_audit06_phone_detail_back_to_collection.png` | A93 返回收藏页 |
| void | `void_2866_audit06_phone_detail_guide_step1_dup2.png` | 作废：第二次重复尝试（内容为引导第 1 步） |
| void | `void_2867_audit06_phone_detail_clean_dup2.png` | 作废：同上（内容为关闭态详情） |
| 2868 | `2868_audit06_phone_setcurrent_1920s_home.png` | A95 1920s → 主页 |
| 2869 | `2869_audit06_phone_detail_1930s.png` | 1930s 详情 |
| 2870 | `2870_audit06_phone_setcurrent_1930s_home.png` | A95 1930s → 主页 hero 为 1930s |
| 2871 | `2871_audit06_phone_collection_scroll_row2.png` | 网格上滑（第二行露出） |
| 2872 | `2872_audit06_phone_collection_scroll_row2b.png` | 第二行完整（1950s/1960s 卡） |
| 2873 | `2873_audit06_phone_detail_1950s.png` | 1950s 详情 |
| 2874 | `2874_audit06_phone_setcurrent_1950s_home.png` | A95 1950s → 主页 hero 为 1950s |
| 2875 | `2875_audit06_phone_detail_1960s.png` | 1960s 详情 |
| 2876 | `2876_audit06_phone_setcurrent_1960s_home.png` | A95 1960s → 主页 hero 为 1960s |
| 2877 | `2877_audit06_phone_collection_scroll_2020s.png` | 2020s 卡（条件行截断，O6） |
| 2878 | `2878_audit06_phone_detail_2020s.png` | 2020s 详情：史实段落空白（O1/R6） |
| 2879 | `2879_audit06_phone_setcurrent_2020s_home.png` | A95 2020s → 主页 hero 仍是 1960s 图（O3） |
| 2880 | `2880_audit06_phone_settings_page.png` | 设置页（默认组在下方） |
| 2881 | `2881_audit06_phone_settings_machine_label_2020s.png` | 设置“默认机器=1920s 直立式”（O2） |
| 2882 | `2882_audit06_phone_typewriter_2020s.png` | 打字机 2020s 主题（换机已生效） |
| 2883 | `2883_audit06_phone_typewriter_back_home.png` | 从打字机返回主页 |
| 2884 | `2884_audit06_phone_collection_default_label_while_2020s_current.png` | 当前 2020s 时 1920s 卡仍“默认机器”（O5） |
| 2885 | `2885_audit06_phone_setcurrent_1920s_restore_home.png` | 恢复 1920s → 主页 |
| 2886 | `2886_audit06_phone_detail_1920s_clean_check.png` | 受控复测：关闭态详情 |
| 2887 | `2887_audit06_phone_detail_guide_from_help_check.png` | 受控复测：点“?”重拉引导（A94） |
| 2888 | `2888_audit06_phone_end_state_home.png` | 收工：主页 |
