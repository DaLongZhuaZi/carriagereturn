# 核查①-1：全 App 页面/菜单/按钮/选项清单（代码枚举）

- 生成日期：2026-11-25
- 代码基线：分支 `audit01-inventory`（base `main` HEAD `2cdcaed`，批 79 已合）
- 范围：`entry/src/main/ets` 全部当前挂载 UI；单 @Entry（`pages/Index.ets`），其余页面为 Index 内的覆盖层。
- 方法：静态代码走查。逐页读 `build()` 与事件 handler，按“页面上真实可见/可点的控件”枚举；只 `import` 但未实例化的旧件集中列在附录 D，不混入编号。
- 本批**不构建、不上真机、不截图**；表中“预期行为”全部来自代码路径，真机行为留待后续批次逐项验证。
- 状态口径：
  - `已接线`：控件 → handler → 服务/状态/落盘的链路在代码中完整。
  - `条件可用`：已接线，但只在特定宽度、导出范围或输入模式下出现/可用。
  - `未接线`：控件存在，但没有有效 handler，或下游没有消费者。
  - `不可达`：控件代码存在，但当前没有任何入口能把它显示出来。
  - `待确认`：代码显示该控件的可见效果可能与文案/设置不一致，需真机或后续批次确认。
  - `待修`：真机核查已确认与清单预期不符，待修复（核查①-4 起用）。

## 0. 文件缩写

| 缩写 | 路径 |
|---|---|
| Index | `entry/src/main/ets/pages/Index.ets` |
| Parts26 | `entry/src/main/ets/components/type26/Parts26.ets` |
| Carriage26 | `entry/src/main/ets/components/type26/Carriage26.ets` |
| Stage26 | `entry/src/main/ets/components/type26/Stage26.ets` |
| KeyGrid | `entry/src/main/ets/components/KeyGrid.ets` |
| PageShell | `entry/src/main/ets/components/PageShell.ets` |
| AppMenu | `entry/src/main/ets/components/AppMenu.ets` |
| AppDialog | `entry/src/main/ets/components/AppDialog.ets` |
| HomePage | `entry/src/main/ets/components/HomePage.ets` |
| DossierPage | `entry/src/main/ets/components/DossierPage.ets` |
| DossierDetail | `entry/src/main/ets/components/DossierDetailPage.ets` |
| DocumentView | `entry/src/main/ets/components/DocumentViewPage.ets` |
| CollectionPage | `entry/src/main/ets/components/CollectionPage.ets` |
| CollectionDetail | `entry/src/main/ets/components/CollectionDetailPage.ets` |
| CustomizePage | `entry/src/main/ets/components/CustomizePage.ets` |
| FontManager | `entry/src/main/ets/components/FontManagerPage.ets` |
| PaperCustom | `entry/src/main/ets/components/PaperCustomPage.ets` |
| SettingsPage | `entry/src/main/ets/components/SettingsPage.ets` |
| PinyinSettings | `entry/src/main/ets/components/PinyinSettingsPage.ets` |
| TrashPage | `entry/src/main/ets/components/TrashPage.ets` |
| ExportPage | `entry/src/main/ets/components/ExportPage.ets` |
| OnboardingGuide | `entry/src/main/ets/components/OnboardingGuide.ets` |
| SpotlightOverlay | `entry/src/main/ets/components/SpotlightOverlay.ets` |
| HintBar | `entry/src/main/ets/components/HintBar.ets` |

## 1. 页面与导航模型（代码事实）

- 唯一 @Entry：`Index`（`main_pages.json` 仅 `pages/Index`）。
- 导航栈：`Index.navStack` 初值 `['home']`（Index:1022），`pushPage/popPage/popTo`（Index:1246-1294）维护；页面不是路由页，而是 Index `build()` 中按布尔量挂载的覆盖层。
- 栈语义：主页是栈底；打字机压在其上；从打字机进的页压在打字机之上；卷宗内页压在卷宗页之上；文档视图压在内页之上。系统返回由 `Index.onBackPress`（Index:1297-1327）统一拦截。
- 页面清单（14 个页面）：
  1. 主页 HomePage（Index:5056-5106）
  2. 打字机页（Index:5262-5353，type26 五区）
  3. 卷宗页 DossierPage（Index:5108-5121）
  4. 卷宗内页 DossierDetail（Index:5420-5451）
  5. 文档视图 DocumentView（Index:5454-5487）
  6. 收藏页 CollectionPage（Index:5216-5228）
  7. 收藏详情 CollectionDetail（Index:5231-5250）
  8. 换装页 CustomizePage（Index:5125-5179）
  9. 字体管理 FontManager（Index:5182-5200）
  10. 纸张自定义 PaperCustom（Index:5201-5213）
  11. 设置页 SettingsPage（Index:5355-5404）
  12. 拼音设置 PinyinSettings（Index:5521-5557）
  13. 回收站 TrashPage（Index:5407-5417）
  14. 导出页 ExportPage（Index:5490-5519）
- 全局浮层/弹窗（4 个）：启动引导 OnboardingGuide（Index:5589-5594）、聚光灯引导 SpotlightOverlay（Index:5596-5606）、成就弹窗（Index:5608-5617 + `achDialogBody`）、全局下拉菜单 AppMenu（Index:5559-5572，当前不可达）。
- 页面引导入口：除卷宗内页（自定义页眉，无“?”）和打字机页（无“?”）外，其余页由 `PageShell` 右上“?”触发；打字机页只有首次进入的自动引导。

---

## 2. 全局

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A01 | 系统返回键/手势 | Index:1297-1327 | `onBackPress()` | 依次处理：中文键盘→退中文；启动引导→上一页/首页跳过；页面引导→关闭；导出 busy→忽略；菜单→关闭；否则弹栈；栈底主页返回 false 交系统退出 | 已接线 |

---

## 3. 启动引导 OnboardingGuide（5 页全屏）

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A02 | 跳过 | OnboardingGuide:110-117 | `onSkip()` → Index:1164-1170 `closeOnboarding` | 第 1–4 页显示；关闭引导并落 seen（含主页 seen） | 已接线 |
| A03 | 下一步 | OnboardingGuide:118-124 | `go(page+1)` | 第 1–4 页显示；150ms 淡出→换页→淡入 | 已接线 |
| A04 | 上一步 | OnboardingGuide:126-132 | `go(page-1)` | 仅第 5 页显示；回第 4 页 | 已接线 |
| A05 | 开始写作 | OnboardingGuide:133-140 | `onStart()` → `closeOnboarding` | 仅第 5 页显示；关闭引导并落 seen | 已接线 |
| A06 | 系统返回 | Index:1305-1312 | `onBackPress()` | 引导中：非首页→上一页；首页→关闭（等同跳过） | 已接线 |

> 圆点指示（OnboardingGuide:98-106）为纯展示，不计数。

---

## 4. 主页 HomePage

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A07 | 右上引导“?” | HomePage:93-100 | `GuideBridge.request('home')` → Index:1137 | 打开主页聚光灯引导；引导总开关关闭时不渲染 | 已接线 |
| A08 | 主按钮（继续写作/开始打字） | HomePage:143-156 | `onContinue` / `onStartTyping`（Index:5065-5093） | 有文档→载入 `docStore.list()[0]` 并进打字机；无文档→新建空白纸并进打字机 | 已接线 |
| A09 | 底部“卷宗” | HomePage:82-87, 204-210 | `onOpen('dossier')` → Index:5095 | 压栈卷宗页 | 已接线 |
| A10 | 底部“收藏” | 同上 | `onOpen('collection')` | 压栈收藏页 | 已接线 |
| A11 | 底部“主题” | 同上 | `onOpen('customize')` | 压栈换装页 | 已接线 |
| A12 | 底部“设置” | 同上 | `onOpen('settings')` | 压栈设置页 | 已接线 |
| A13 | 底部“导出” | 同上 | `onOpen('export')` → Index:5099 | 压栈导出页；未显式设置导出目标，ExportPage 会读模块级旧目标（见 R7） | 待确认 |

> 机器图区、统计行、目标进度、目标达成文案为纯展示。

---

## 5. 打字机页（Index + type26）

### 5.1 顶区与功能件

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A14 | 返回拨杆 | Parts26:243-258；Index:4778 | `onBack` → `leaveTyping`（Index:1237） | 播放卸纸 600ms 后弹栈回上一页 | 已接线 |
| A15 | 出纸槽 | Parts26:262-276；Index:4780 | `onExportSlot` → `directExport`（Index:3372-3470） | 按 `lastExportFormat`（默认 `text`）直接导出到应用 `exports/`，并播放纸片滑出 300ms；`image` 格式当前只记错误、不回落 | 已接线 |
| A16 | 语言键 EN/中 | Parts26:761；Index:4863-4869 | `onLang` | 切换 `langZh`；builtin 显示候选栏，system 聚焦隐藏锚点并弹系统输入法；重算行宽/纸高 | 已接线 |
| A17 | 退格 ⌫ | Parts26:762；Index:4870-4880, 3923 | `onDelete` | builtin 组词中→删拼音缓冲；否则删文档一字（先同步落队）；播音效/震动 | 已接线 |
| A18 | 换行 ⏎ | Parts26:763；Index:4881-4894, 4217 | `onNewline` | builtin 组词中→先提交首选并清缓冲；否则换行：下行有内容则光标下移，末行插入新行，超行数自动换纸 | 已接线 |
| A19 | 换纸 ↻ | Parts26:764；Index:4895, 4109 | `onPaperChange` | 600ms 旧纸飞出＋新纸卷入；有内容则归档并页码+1；清空纸面；期间禁打字；不取消拼音组词会话（见 R9） | 待确认 |
| A20 | 退行 BL | Parts26:765；Index:4896, 4020 | `onBackLine` | 光标回上一行行尾；纸上移/字车回位；busy 时忽略 | 已接线 |
| A21 | 符号 Aa | Parts26:766；Index:4897-4916 | `onSymbols` | 旧键下沉淡出→切 `symbolMode`→新键从井下方升入 | 已接线 |
| A22 | 字体牌 | Parts26:776-805；Index:4929, 3389 | `cycleFont` | 循环切换当前机器字体（17 款），立即改纸面渲染并保存 | 已接线 |
| A23 | 候选词格（最多 5 个） | Parts26:812-878；Index:4944, 3212 | `pinyinPick(i)` | 点候选上屏；学习词频；显示当前页最多 5 个；候选数量可设 5–15 但条只显示 5 且无翻页（见 R1） | 待确认 |

### 5.2 键盘（字母面板 5 行，共 53 键）

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A24 | 数字行 13 键 | KeyGrid:174-180, 468-475；Index:3489 | `onCapDown/onCapUp` | 1–0、-、= 落字；Shift/Caps 上档 ! @ # $ % ^ & * ( ) _ +；Backspace 删字 | 已接线 |
| A25 | Q 行 12 键 | KeyGrid:181-187 | 同上 | Tab 插 4 个空格；q–p、[ ] 落字（Shift 上档 { }） | 已接线 |
| A26 | A 行 15 键 | KeyGrid:188-197 | 同上 | Caps Lock 切换大写锁；a–l、; : ' " 落字；Return 换行 | 已接线 |
| A27 | Z 行 12 键 | KeyGrid:198-206 | 同上 | Shift 按住大写、松开复位；z–m、, . / 落字（Shift 上档 < > ?） | 已接线 |
| A28 | 空格 | KeyGrid:207, 210 | 同上 | 空格进落字队列（落地播音）；builtin 组词中→选首选 | 已接线 |

### 5.3 符号面板（Aa 后 5 行，共 54 键）

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A29 | 符号行 1（13 键） | KeyGrid:110-114 | 同上 | ~ ! @ # $ % ^ & * ( ) +、Backspace | 已接线 |
| A30 | 符号行 2（13 键） | KeyGrid:115-120 | 同上 | Tab、{ } [ ]、竖线、反斜杠、: " < > ? / | 已接线 |
| A31 | 符号行 3（15 键） | KeyGrid:121-136 | 同上 | Caps Lock、; ' , . - / = + * & ^ % $、Return | 已接线 |
| A32 | 符号行 4（12 键） | KeyGrid:137-145 | 同上 | Shift、§ ± × ÷ ≠ ≤ ≥ ∞ ¥ €、Shift | 已接线 |
| A33 | 符号空格 | KeyGrid:146, 149 | 同上 | 落空格 | 已接线 |

### 5.4 纸面与其他

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A34 | 纸面上下拖动 | Carriage26:217-219；Index:1626-1636 | `PanGesture` → `onPaperPanStart/Update` | 纸在 [0, 纸高−视口高] 内上下拖；下一次落字/换行/退格 250ms 回位 | 已接线 |
| A35 | 悬浮“A”键 | Index:5575-5586 | `onClick` | 仅 system 中文模式显示；点按退中文并 detach | 条件可用 |
| A36 | 数字键选候选（1–9） | Index:3340-3349 | `onBuiltinCnCap` | builtin 组词中按 1–9 选当前页第 N 个候选；0 无效 | 已接线 |

> 打字机页无“?”引导入口；首次进入由 `maybeShowPageGuide` 自动弹（Index:1121-1134）。引导锚点 `typewriter__lever/function_row/paper` 当前没有对应节点（见 R10）。

---

## 6. 卷宗页 DossierPage

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A37 | 返回 | PageShell:63-70；DossierPage:224 | `onBack` → `leaveTyping` | 弹栈回主页 | 已接线 |
| A38 | 引导“?” | PageShell:78-84 | `GuideBridge.request('dossier')` | 打开卷宗页聚光灯引导 | 已接线 |
| A39 | 新建卷宗 | DossierPage:95-107 | `creating=true` | 打开新建卷宗弹窗 | 已接线 |
| A40 | “未归档”卡片 | DossierPage:124-141 | `onOpenDossier('')` | 进卷宗内页，`dossierId=''`，显示未归档纸 | 已接线 |
| A41 | 卷宗卡片（每个） | DossierPage:143-169 | `onOpenDossier(d.id)` | 进该卷宗内页 | 已接线 |
| A42 | 弹窗-名称输入 | DossierPage:186-189 | `draftName` | 输入卷宗名（非受控，打字不重建弹窗） | 已接线 |
| A43 | 弹窗-封面 kraft | DossierPage:191-197 | `draftCover='kraft'` | 选中牛皮纸封面，金框标识 | 已接线 |
| A44 | 弹窗-封面 leather | 同上 | `draftCover='leather'` | 选中皮革封面 | 已接线 |
| A45 | 弹窗-封面 manila | 同上 | `draftCover='manila'` | 选中马尼拉封面 | 已接线 |
| A46 | 弹窗-封面 cloth | 同上 | `draftCover='cloth'` | 选中布面封面 | 已接线 |
| A47 | 弹窗-取消 | DossierPage:200-201 | `creating=false` | 关闭弹窗，不创建 | 已接线 |
| A48 | 弹窗-创建 | DossierPage:203-210 | `dossierStore.create` → `reload` → `onOpenDossier` | 空名→“未命名卷宗”；创建后立即进内页 | 已接线 |

> 空状态文案（DossierPage:112-121）为纯展示。本页没有搜索入口（见 R14）。【2026-11-25 核查①-4：A37–A48 双机真机通过，见 item04-dossier.md】

---

## 7. 卷宗内页 DossierDetail

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A49 | 返回 | DossierDetail:458-464 | `onBack` → `leaveTyping` | 弹栈回卷宗页 | 已接线 |
| A50 | 卷宗名 | DossierDetail:478-485 | `renaming=true` | 点名字打开重命名卷宗弹窗（预填当前名）【2026-11-25 核查①-4：弹窗未预填当前名（O3），判部分】 | 已接线 |
| A51 | 页眉“⋯” | DossierDetail:491-495 | `moreOpen=true` | 打开下拉菜单：改名 / 新建纸张 / 删除卷宗 | 已接线 |
| A52 | 页眉“导出” | DossierDetail:497-504 | `onExport` → `onExportDossier` | 仅 `widthVp>=600` 显示；进导出页，范围为整卷宗【2026-11-25 核查①-4：平板通过；手机按 width<600 条件隐藏，整卷宗导出在手机无入口】 | 条件可用 |
| A53 | 页眉“新建纸张” | DossierDetail:506-513 | `onNewPaper` | 仅 `widthVp>=600` 显示；在该卷宗新建空白纸【2026-11-25 核查①-4：平板通过；手机按 width<600 条件隐藏，改由 ⋯ 菜单新建（A59）】 | 条件可用 |
| A54 | 搜索框 | DossierDetail:437-453 | `onSearchChange`（150ms 防抖） | 按标题＋正文搜索，并只保留本卷宗命中的纸；空查询显示全部 | 已接线 |
| A55 | 纸缩略图 | DossierDetail:543-554 | `onOpenDoc(p.id)` | 进文档视图（阅读） | 已接线 |
| A56 | “打开” | DossierDetail:562-566 | `onOpenPaper(p.id)` | 载入该纸并回打字机编辑【2026-11-25 核查①-4 不通过：点“打开”只载入文档，不回打字机（O2，高优先级）；`popTo('typewriter')` 在栈内无 `typewriter` 时直接 return】 | 待修 |
| A57 | 纸卡片“⋯” | DossierDetail:567-575 | `paperMenuId=p.id` | 打开纸操作弹窗：重命名纸 / 删除 / 取消 | 已接线 |
| A58 | 菜单-改名 | DossierDetail:657-660 | `openPaperRename` | 关闭菜单并打开重命名纸弹窗（预填标题） | 已接线 |
| A59 | 菜单-新建纸张 | DossierDetail:743-748 | `onNewPaper` | 在该卷宗新建空白纸 | 已接线 |
| A60 | 菜单-删除卷宗 | DossierDetail:749 | `confirmDel=true` | 打开删除卷宗弹窗 | 已接线 |
| A61 | 菜单-点空白关闭 | AppMenu:52-55 | `onClose` | 点透明层关闭菜单；不压暗底层 | 已接线 |
| A62 | 删卷宗-移出卷宗 | DossierDetail:619-621 | `onDeleteDossier('unfile')` | 卷宗内纸变未归档，删除卷宗索引【2026-11-25 核查①-4：功能通过，但返回列表不即时刷新（O1）】 | 已接线 |
| A63 | 删卷宗-连纸一起删 | DossierDetail:622-624 | `onDeleteDossier('purge')` | 卷宗内纸彻底删除，删除卷宗索引【2026-11-25 核查①-4：功能通过，但返回列表不即时刷新（O1）】 | 已接线 |
| A64 | 删卷宗-取消 | DossierDetail:625-627 | `confirmDel=false` | 关闭弹窗 | 已接线 |
| A65 | 纸菜单-重命名纸 | DossierDetail:657-660 | `openPaperRename` | 打开重命名纸弹窗 | 已接线 |
| A66 | 纸菜单-删除 | DossierDetail:661-670 | `pendingDelPaper=id` | 打开删除纸确认弹窗 | 已接线 |
| A67 | 纸菜单-取消 | DossierDetail:671-674 | `paperMenuId=''` | 关闭纸菜单 | 已接线 |
| A68 | 删纸确认-删除 | DossierDetail:632-645 | `onDeletePaper` | 按删除方式：`direct` 彻底删，否则入回收站 | 已接线 |
| A69 | 删纸确认-取消 | DossierDetail:646-649 | `pendingDelPaper=''` | 关闭弹窗 | 已接线 |
| A70 | 重命名纸-输入 | DossierDetail:679-687 | `paperDraftName` | 预填当前标题，可编辑 | 已接线 |
| A71 | 重命名纸-取消 | DossierDetail:689-690 | `renamingPaper=''` | 关闭弹窗 | 已接线 |
| A72 | 重命名纸-保存 | DossierDetail:692-693 | `commitPaperRename` | 空标题不提交；否则 rename 并刷新列表 | 已接线 |
| A73 | 重命名卷宗-输入 | DossierDetail:702-705 | `draftName` | 输入新卷宗名 | 已接线 |
| A74 | 重命名卷宗-取消 | DossierDetail:707-708 | `renaming=false` | 关闭弹窗 | 已接线 |
| A75 | 重命名卷宗-保存 | DossierDetail:710-718 | `dossierStore.rename` | 空名保留原名；更新页眉并通知外层刷新【2026-11-25 核查①-4：页眉与落盘正确，但返回列表卡片仍旧名（O1），判部分】 | 已接线 |

> 本页用 `customHeader`（DossierDetail:729-735），绕过 PageShell 默认返回/标题/“?”，因此**没有“?”引导入口**（见 R11）；自动引导仍可在首次进入时弹。【2026-11-25 核查①-4：A49–A75 双机验证，36 项通过/2 部分（A50、A75）/1 不通过（A56），见 item04-dossier.md】

---

## 8. 文档视图 DocumentView

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A76 | 返回 | PageShell:63-70；DocumentView:233 | `onBack` → `leaveTyping` | 弹栈回卷宗内页【2026-11-25 核查①-5 双机通过】 | 已接线 |
| A77 | 引导“?” | PageShell:78-84 | `GuideBridge.request('document_view')` | 打开文档视图引导【2026-11-25 核查①-5 双机通过；引导第 2 步锚点缺失/文案指向不存在的“编辑”，见 O3/R25】 | 已接线 |
| A78 | 正文纸面 | DocumentView:142-162 | `onEdit(docId)` | 载入该文档并 `popTo('typewriter')` 进编辑【2026-11-25 核查①-5 不通过：平板点正文只 `loadDocument` 不回打字机（R21 同源）；手机正文页 0 高不可操作（O1/R24）】 | 待修 |
| A79 | 底栏“加页” | DocumentView:172-177 | `onAddPage` → Index:5473-5484 | 在文档末尾追加一行并落盘，刷新列表【2026-11-25 核查①-5 双机通过（落盘行数 +1）；`meta.updatedAt` 未更新（O4，低优先级观察）】 | 已接线 |
| A80 | 底栏“导出” | DocumentView:178-183 | `onExport` → `onExportDoc` | 进导出页，范围为整篇【2026-11-25 核查①-5 双机通过，scope=doc 且 docId 正确】 | 已接线 |
| A81 | 底栏“分享·待实现” | DocumentView:184-187 | 无 `onClick` | 灰色占位，不可点【2026-11-25 核查①-5 双机确认 R13：点按无响应，死占位】 | 未接线 |
| A82 | 底栏“删除” | DocumentView:188-193 | `confirmDel=true` | 打开删除确认弹窗【2026-11-25 核查①-5 双机通过（trash 档文案“删除后进回收站，可恢复。”）】 | 已接线 |
| A83 | 确认弹窗-删除 | DocumentView:210-217 | `onDelete(docId)` | 按删除方式删除；清空 `openDocId` 并回卷宗内页【2026-11-25 核查①-5 双机通过（纸入回收站，计数 2→1）】 | 已接线 |
| A84 | 确认弹窗-取消 | DocumentView:218-221 | `confirmDel=false` | 关闭弹窗【2026-11-25 核查①-5 双机通过】 | 已接线 |

> 标题页的“照片/待实现”为纯展示占位（DocumentView:109-117），不计数。
>
> 【2026-11-25 核查①-5：A76–A84 双机验证，8 项通过、1 不通过（A78），见 item05-docview-trash.md】

---

## 9. 收藏页 CollectionPage

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A85 | 返回 | PageShell:63-70；CollectionPage:318 | `onBack` → `leaveTyping` | 弹栈回上一页 | 已接线 |
| A86 | 引导“?” | PageShell:78-84 | `GuideBridge.request('collection')` | 打开收藏页引导 | 已接线 |
| A87 | 1920s 机器卡 | CollectionPage:116-173 | `onPick('1920s-upright')` | 进收藏详情；机器永久解锁 | 已接线 |
| A88 | 1930s 机器卡 | 同上 | `onPick('1930s-portable')` | 进收藏详情 | 已接线 |
| A89 | 1950s 机器卡 | 同上 | `onPick('1950s-streamlined')` | 进收藏详情 | 已接线 |
| A90 | 1960s 机器卡 | 同上 | `onPick('1960s-electric')` | 进收藏详情 | 已接线 |
| A91 | 2020s 机器卡 | 同上 | `onPick('2020s-modern')` | 进收藏详情；该机详情文案缺资源（见 R6）【2026-11-25 核查①-6 双机通过；详情史实段落空白（O1）、卡片条件行截断（O6）】 | 已接线 |
| A92 | 顶部提示条点按关闭 | HintBar:60-65；CollectionPage:324-329 | `onDismiss` | 关闭提示条；但 `hintText` 在当前代码中从不置值，实际不可达【2026-11-25 核查①-6 双机确认：收藏页无提示条，符合预期】 | 未接线 |

> 成就列表（CollectionPage:293-306）为纯展示。

---

## 10. 收藏详情 CollectionDetail

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A93 | 返回 | PageShell:63-70；CollectionDetail:135 | `onBack` → `leaveTyping` | 弹栈回收藏页 | 已接线 |
| A94 | 引导“?” | PageShell:78-84 | `GuideBridge.request('collection_detail')` | 打开收藏详情引导 | 已接线 |
| A95 | “设为当前机器” | CollectionDetail:118-124 | `onSetCurrent` → Index:5240-5247 | 切换全局机型并 `popTo('home')` 回主页【2026-11-25 核查①-6 五台机逐台双机通过；2020s 的机名/主页图回落见 R6】 | 已接线 |

> 大图、特写、史实、进度三行为纯展示。

---

## 11. 换装页 CustomizePage

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A96 | 返回 | PageShell:63-70；CustomizePage:403 | `onBack` → `leaveTyping` | 弹栈回打字机 | 已接线 |
| A97 | 引导“?” | PageShell:78-84 | `GuideBridge.request('customize')` | 打开换装页引导 | 已接线 |
| A98 | 字号滑杆 | CustomizePage:135-145 | `onFontSize` → Index:2297 | 12–26，实时改当前机器字号并保存 | 已接线 |
| A99 | “字体管理”行 | CustomizePage:157-163 | `onOpenFontManager` | 压栈字体管理页 | 已接线 |
| A100 | “纸张自定义”行 | CustomizePage:165-171 | `onOpenPaperCustom` | 压栈纸张自定义页 | 已接线 |
| A101 | 机器胶囊 1920s | CustomizePage:182-211 | `onPickMachine('1920s-upright')` | 立即换机并落盘 | 已接线 |
| A102 | 机器胶囊 1930s | 同上 | `onPickMachine('1930s-portable')` | 立即换机并落盘 | 已接线 |
| A103 | 机器胶囊 1950s | 同上 | `onPickMachine('1950s-streamlined')` | 立即换机并落盘 | 已接线 |
| A104 | 机器胶囊 1960s | 同上 | `onPickMachine('1960s-electric')` | 立即换机并落盘 | 已接线 |
| A105 | 机器胶囊 2020s | 同上 | `onPickMachine('2020s-modern')` | 立即换机并落盘 | 已接线 |
| A106 | 1920s 动画-写实 | CustomizePage:236 | `onPickAnimMode('1920s-upright','realistic')` | 设置该机写实动画并落盘 | 已接线 |
| A107 | 1920s 动画-模拟 | CustomizePage:242 | `onPickAnimMode(...,'simulated')` | 设置该机模拟动画并落盘 | 已接线 |
| A108 | 1930s 动画-写实 | 同上 | `onPickAnimMode('1930s-portable','realistic')` | 设置写实 | 已接线 |
| A109 | 1930s 动画-模拟 | 同上 | `onPickAnimMode(...,'simulated')` | 设置模拟 | 已接线 |
| A110 | 1950s 动画-写实 | 同上 | `onPickAnimMode('1950s-streamlined','realistic')` | 设置写实 | 已接线 |
| A111 | 1950s 动画-模拟 | 同上 | `onPickAnimMode(...,'simulated')` | 设置模拟 | 已接线 |
| A112 | 标准件-键盘帽形 rounded-rect | CustomizePage:258-278 | `onPickPart('key-grid','rounded-rect')` | 只换 token，立即生效 | 已接线 |
| A113 | 标准件-键盘帽形 round | 同上 | `onPickPart('key-grid','round')` | 只换 token | 已接线 |
| A114 | 标准件-字篮 flat-line | 同上 | `onPickPart('basket','flat-line')` | 只换 token | 已接线 |
| A115 | 标准件-字篮 metal-gradient | 同上 | `onPickPart('basket','metal-gradient')` | 只换 token | 已接线 |
| A116 | 标准件-旋钮 metal-knurl | 同上 | `onPickPart('knob','metal-knurl')` | 只换 token | 已接线 |
| A117 | 标准件-旋钮 matte-black | 同上 | `onPickPart('knob','matte-black')` | 只换 token | 已接线 |
| A118 | 标准件-机身 1920s-black | 同上 | `onPickPart('body-panel','1920s-black')` | 只换 token | 已接线 |
| A119 | 标准件-机身 1930s-grey | 同上 | `onPickPart('body-panel','1930s-grey')` | 只换 token | 已接线 |
| A120 | 标准件-机身 1950s-cream | 同上 | `onPickPart('body-panel','1950s-cream')` | 只换 token | 已接线 |
| A121 | 标准件-机身 1960s-lightgrey | 同上 | `onPickPart('body-panel','1960s-lightgrey')` | 只换 token | 已接线 |
| A122 | 纸张-信纸 | CustomizePage:287-302 | `onPickPaper('letter')` | 立即换纸型并落盘 | 已接线 |
| A123 | 纸张-稿纸 | 同上 | `onPickPaper('manuscript')` | 立即换纸型并落盘 | 已接线 |
| A124 | 纸张-明信片 | 同上 | `onPickPaper('postcard')` | 立即换纸型并落盘 | 已接线 |
| A125 | 纸张-便签 | 同上 | `onPickPaper('memo')` | 立即换纸型并落盘 | 已接线 |
| A126 | 色带-黑 | CustomizePage:313-322 | `onPickRibbon('black')` | 立即换墨色并落盘 | 已接线 |
| A127 | 色带-蓝 | 同上 | `onPickRibbon('blue')` | 立即换墨色并落盘 | 已接线 |
| A128 | 色带-红 | 同上 | `onPickRibbon('red')` | 立即换墨色并落盘 | 已接线 |
| A129 | 字体列表（17 款，每行） | CustomizePage:335-354 | `onPickFont(f.font)` → Index:5162-5176 | 立即改当前文档字体并保存；注册失败字体标“未加载” | 已接线 |

> 1960s 动画行固定显示“电动单套”（CustomizePage:227-229），不是可点选项。“每机字体”区（CustomizePage:362-384）为只读展示。

---

## 12. 字体管理 FontManager

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A130 | 返回 | PageShell:63-70；FontManager:280 | `onBack` → `leaveTyping` | 弹栈回换装页 | 已接线 |
| A131 | 引导“?” | PageShell:78-84 | `GuideBridge.request('font_manager')` | 打开字体管理引导 | 已接线 |
| A132 | “导入字体” | FontManager:192-212 | `importFont` → `FileHelper.pickFont` | 选 .ttf/.otf、≤20MB、拷入沙箱并注册；失败在页内显示错误行 | 已接线 |
| A133 | 每行“应用” | FontManager:246-250 | `onApplyFamily` → Index:5187-5195 | 写入当前机字体并立即应用 | 已接线 |
| A134 | 每行“删除” | FontManager:251-255 | `removeFont` | 删 prefs 与沙箱文件；引用该字体的 4 台老机回退默认（2020s 不在回退循环，见 R6） | 已接线 |

> 字体注册、文件选择器为真机 API，代码走查不能判定成功与否（见 R15）。

---

## 13. 纸张自定义 PaperCustom

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A135 | 返回 | PageShell:63-70；PaperCustom:422 | `onBack` → Index:5206-5210 | 刷新自定义值、重算纸高后弹栈 | 已接线 |
| A136 | 引导“?” | PageShell:78-84 | `GuideBridge.request('paper_custom')` | 打开纸张自定义引导 | 已接线 |
| A137 | 色板（5 色，每格） | PaperCustom:246-258 | `CustomizeStore.setPaperColor` | 选纸色，预览与主屏即时生效 | 已接线 |
| A138 | “横线”开关 | PaperCustom:264-274 | `setPaperRuled` | 开/关横线 | 已接线 |
| A139 | 左边距滑杆 | PaperCustom:282-294 | `setPaperMarginH` | 手机 24–40 / 平板 40–56，实时改版心 | 已接线 |
| A140 | 上边距滑杆 | PaperCustom:298-310 | `setPaperMarginT` | 手机 16–32 / 平板 24–40 | 已接线 |
| A141 | 下边距滑杆 | PaperCustom:314-326 | `setPaperMarginB` | 手机 16–28 / 平板 20–32 | 已接线 |
| A142 | “导入纸纹” | PaperCustom:331-357 | `importTexture` → `FileHelper.pickImage` | 选图片拷入沙箱并设为当前纸纹理 | 已接线 |
| A143 | 预设名输入 | PaperCustom:362-369 | `presetDraft` | 输入预设名 | 已接线 |
| A144 | “保存”预设 | PaperCustom:370-374 | `savePreset` | 空名不存；保存当前 6 项为预设 | 已接线 |
| A145 | 预设行“删除” | PaperCustom:380-395 | `deletePreset` | 删除该预设 | 已接线 |

> 顶部小样预览（PaperCustom:210-241）为纯展示。

---

## 14. 设置页 SettingsPage

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A146 | 返回 | PageShell:63-70；SettingsPage:318 | `onBack` → `leaveTyping` | 弹栈回上一页 | 已接线 |
| A147 | 引导“?” | PageShell:78-84 | `GuideBridge.request('settings')` | 打开设置页引导 | 已接线 |
| A148 | “音效”开关 | SettingsPage:130-135 | `onToggleSound` → Index:4636 | 开关全部音效并落盘 | 已接线 |
| A149 | “音量”滑杆 | SettingsPage:137-146 | `onVolume` → Index:4648 | 0–100，落盘并设 AudioService | 已接线 |
| A150 | “按键震动”开关 | SettingsPage:156-161 | `onToggleVibrate` → Index:4642 | 开关震动并落盘 | 已接线 |
| A151 | “无障碍覆盖层”开关 | SettingsPage:171-176 | `onToggleA11y` → Index:5368 | 仅翻转内存 `@State`，无消费者、不落盘 | 未接线 |
| A152 | “删除方式”行 | SettingsPage:185-190 | `nextMode` → Index:4631 | `trash→ask→direct` 循环并落盘；`ask` 与 `trash` 当前行为相同（见 R8） | 已接线 |
| A153 | “中文输入”行 | SettingsPage:193-198 | `onPickCnEngine` → Index:5390-5400 | `builtin↔system` 切换并落盘；若在中文模式先退出 | 已接线 |
| A154 | “拼音设置”行 | SettingsPage:201-206 | `onOpenPinyinSettings` → Index:5380-5387 | 压栈拼音设置页并预载引擎 | 已接线 |
| A155 | “每日目标”滑杆 | SettingsPage:215-227 | `onGoal` → `statsService.setDailyGoal` | 100–2000 步进 100，落盘并刷新主页 | 已接线 |
| A156 | “默认机型”行 | SettingsPage:236-241 | `onPickMachine` → `cycleMachine`（Index:4671） | 只在 4 台老机间循环；当前为 2020s 时回显落到 1920s，且无法从本行选到 2020s（见 R6） | 待确认 |
| A157 | “默认纸张”行 | SettingsPage:243-248 | `onPickPaper` → `cyclePaper` | 信纸→稿纸→明信片→便签循环并落盘 | 已接线 |
| A158 | “回收站”行 | SettingsPage:250-255 | `onOpenTrash` → Index:4596 | 压栈回收站页 | 已接线 |
| A159 | “重播页面引导”行 | SettingsPage:265-270 | `replayPageGuide` → Index:1172 | 重置各页 seen；写 `hintText='已重置，下次进入页面生效'`（该提示当前不渲染，见 R5） | 已接线 |
| A160 | “重播启动引导”行 | SettingsPage:272-277 | `replayOnboarding` → Index:1194 | 重置并立即显示启动引导 | 已接线 |

> “音效致谢”“版本 1.0.0”“完全离线声明”为纯展示。

---

## 15. 拼音设置 PinyinSettings

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A161 | 返回 | PageShell:63-70；PinyinSettings:146 | `onBack` → `leaveTyping` | 弹栈回设置页 | 已接线 |
| A162 | 引导“?” | PageShell:78-84 | `GuideBridge.request('pinyin_settings')` | 打开拼音设置引导 | 已接线 |
| A163 | “候选数量”滑杆 | PinyinSettings:54-62 | `onCandidateCount` → Index:5531-5535 | 5–15，落盘并刷新候选；候选条最多只显示 5 个且无翻页（见 R1） | 待确认 |
| A164 | “候选字号”滑杆 | PinyinSettings:64-72 | `onCandidateSize` → Index:5536-5539 | 12–20，落盘；CandStrip26 未接收该值，字号可能不变（见 R1） | 待确认 |
| A165 | “模糊拼音”行 | PinyinSettings:77-89 | `onToggleFuzzy` → Index:478 | 开/关并落盘，立即重建候选 | 已接线 |
| A166 | “添加词组”行 | PinyinSettings:97-103 | `adding=true` | 打开添加词组弹窗 | 已接线 |
| A167 | “管理我的词库”行 | PinyinSettings:104-112 | `managing=true` | 打开词库管理弹窗 | 已接线 |
| A168 | “清除学习与联想记录”行 | PinyinSettings:117-123 | `onClearLearn` → Index:550 | 清空学习与 bigram 并落盘 | 已接线 |
| A169 | 添加弹窗-词组输入 | PinyinSettings:171-177 | `onWordChanged` | 输入中文词组；自动推导拼音 | 已接线 |
| A170 | 添加弹窗-拼音输入 | PinyinSettings:180-182 | `onPinyinEdited` | 可手改拼音 | 已接线 |
| A171 | 添加弹窗-取消 | PinyinSettings:184-185 | `adding=false` | 关闭弹窗 | 已接线 |
| A172 | 添加弹窗-添加 | PinyinSettings:187-192 | `onAddWord` → Index:488-509 | 空词不提交；加词与多音变体入库并落盘；失败只写 `hintText`（当前不可见，见 R5） | 已接线 |
| A173 | 词库弹窗-删除某词 | PinyinSettings:207-215 | `onDeleteWord` → Index:522 | 从词库删除该词并落盘 | 已接线 |
| A174 | 词库弹窗-完成 | PinyinSettings:222-226 | `managing=false` | 关闭弹窗 | 已接线 |

> “词库信息”为纯展示。

---

## 16. 回收站 TrashPage

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A175 | 返回 | PageShell:63-70；TrashPage:201 | `onBack` → `leaveTyping` | 弹栈回设置页【2026-11-25 核查①-5 双机通过】 | 已接线 |
| A176 | 引导“?” | PageShell:78-84 | `GuideBridge.request('trash')` | 打开回收站引导【2026-11-25 核查①-5 双机通过（首次进入自动引导，点“?”可重拉）】 | 已接线 |
| A177 | 每行“恢复” | TrashPage:104-110 | `onRestore` → Index:4607 | 恢复文档；原卷宗不存在则落未归档【2026-11-25 核查①-5 双机通过；平板另验原卷宗已删→未归档分支】 | 已接线 |
| A178 | 每行“彻底删除” | TrashPage:111-114 | `pendingPurge=id` | 打开彻底删除确认弹窗【2026-11-25 核查①-5 双机通过】 | 已接线 |
| A179 | 确认弹窗-删除 | TrashPage:177-186 | `onPurge` → Index:4624 | 永久删除该文档【2026-11-25 核查①-5 双机通过（文件与索引核对已删）】 | 已接线 |
| A180 | 确认弹窗-取消 | TrashPage:187-190 | `pendingPurge=''` | 关闭弹窗【2026-11-25 核查①-5 双机通过】 | 已接线 |

> 空状态与保留期说明为纯展示。
>
> 【2026-11-25 核查①-5：A175–A180 双机 6/6 通过，见 item05-docview-trash.md】

---

## 17. 导出页 ExportPage

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A181 | 返回 | ExportPage:847-853, 1151 | `handleBack` | busy（building/saving/sharing）时忽略；否则弹栈 | 已接线 |
| A182 | 引导“?” | PageShell:78-84 | `GuideBridge.request('export')` | 打开导出页引导 | 已接线 |
| A183 | 范围“当前纸” | ExportPage:946-962 | `range='paper'` | 只导出当前纸；PNG 格式可用 | 已接线 |
| A184 | 范围“整篇” | ExportPage:937 | `range='doc'` | 归档纸＋当前纸逐页导出 | 已接线 |
| A185 | 范围“整卷宗” | ExportPage:938-940 | `range='dossier'` | 仅从卷宗入口进入时显示；逐篇逐纸导出 | 条件可用 |
| A186 | 格式“图片 PNG” | ExportPage:66-73, 965-1005 | `picked=0` | 仅“当前纸”范围可用；其它范围置灰并显示提示 | 条件可用 |
| A187 | 格式“PDF” | ExportPage:74-80 | `picked=1` | 逐页模板渲染后合成 PDF；模板失败回退纯文本 PDF | 已接线 |
| A188 | 格式“纯文本” | ExportPage:81-87 | `picked=2` | 导出 txt | 已接线 |
| A189 | 文件名输入 | ExportPage:897-905 | `nameDraft` | 留空用自动名；非法字符由 `safeFileName` 清理 | 已接线 |
| A190 | 开关“标题” | ExportPage:907 | `optTitle` | 仅影响图片/PDF 模板渲染 | 已接线 |
| A191 | 开关“机型” | ExportPage:908 | `optMachine` | 仅影响模板 | 已接线 |
| A192 | 开关“日期” | ExportPage:909 | `optDate` | 仅影响模板 | 已接线 |
| A193 | 开关“正文” | ExportPage:910 | `optBody` | 仅影响模板 | 已接线 |
| A194 | 开关“页码” | ExportPage:911 | `optPageNo` | 仅影响模板 | 已接线 |
| A195 | 开关“纸张底色” | ExportPage:913 | `optPaper` | 仅影响模板；关＝白纸 | 已接线 |
| A196 | 开关“字体” | ExportPage:914 | `optFont` | 仅影响模板；关＝系统默认 | 已接线 |
| A197 | 开关“墨色” | ExportPage:915 | `optInk` | 仅影响模板；关＝纯黑 | 已接线 |
| A198 | “保存到本地” | ExportPage:1031-1049 | `runSave` | 构建→系统保存选择器→结果态；空文档进 empty | 已接线 |
| A199 | “分享” | ExportPage:1053-1070 | `runShare` | 构建→写临时文件→系统分享面板；已调起即成功 | 已接线 |

> 纸面预览、状态行、进度浮层为纯展示；8 个开关只对图片/PDF 模板生效，纯文本导出不使用（设计口径，见 R16）。

---

## 18. 聚光灯引导 SpotlightOverlay

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A200 | “上一步” | SpotlightOverlay:209-214 | `goPrev` | 非首步显示；回上一步并重新量锚点 | 已接线 |
| A201 | “下一步” | SpotlightOverlay:215-219 | `goNext` | 非末步显示；进下一步 | 已接线 |
| A202 | “知道了” | SpotlightOverlay:220-224 | `onClose(page)` → Index:1157 | 末步显示；关闭并 markSeen | 已接线 |
| A203 | “跳过” | SpotlightOverlay:226-229 | `onClose(page)` | 任意步显示；关闭并 markSeen | 已接线 |
| A204 | 点遮罩/洞内 | SpotlightOverlay:153-159, 190-194, 197-200 | `onClose(page)` | 点暗区或洞内目标关闭引导 | 已接线 |

> 步骤圆点为纯展示。

---

## 19. 成就弹窗（Index.achDialogBody）

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A205 | “查看成就” | Index:4428-4438 | `pushPage('collection')` | 仅 summary 弹窗显示；关弹窗并进收藏页 | 已接线 |
| A206 | “关闭” | Index:4439-4445 | `AchievementService.dismiss` + 刷新 | 关闭当前提示，若有下一条继续弹 | 已接线 |
| A207 | 点遮罩关闭 | AppDialog:34-37 | `onClose` | 关闭弹窗，等同“关闭” | 已接线 |

---

## 20. 全局下拉菜单 AppMenu（Index 实例）

| 编号 | 位置/控件 | 代码位置 | 绑定/处理器 | 预期行为 | 状态 |
|---|---|---|---|---|---|
| A208 | 菜单项“收藏” | Index:5559-5568 | `onPick('collection')` | 进收藏页 | 不可达 |
| A209 | 菜单项“设置” | 同上 | `onPick('settings')` | 进设置页 | 不可达 |
| A210 | 菜单项“导出” | 同上 | `onPick('export')` | 进导出页 | 不可达 |
| A211 | 点空白关闭 | AppMenu:52-55 | `onClose` | 关闭菜单，不压暗底层 | 不可达 |

> `Index.menuOpen` 全仓只有置 false 的语句（Index:1323, 5563），没有任何置 true 的入口，因此 Index 这套菜单当前不可能出现。DossierDetail 内的 AppMenu 是活的，其菜单项已计入 A58–A60，关闭层计入 A61。

---

## 21. 统计

| 指标 | 数值 |
|---|---|
| 页面（含主页/打字机） | 14 |
| 全局浮层/弹窗/菜单 | 4（启动引导、聚光灯、成就弹窗、全局菜单） |
| 控件条目总数 | 211 |
| 已接线 | 192 |
| 条件可用 | 5（A35、A52、A53、A185、A186） |
| 待确认 | 6（A13、A19、A23、A156、A163、A164） |
| 未接线 | 3（A81、A92、A151） |
| 不可达 | 4（A208–A211） |
| 待修 | 2（A56，核查①-4 不通过；A78，核查①-5 不通过） |
| 未确认合计（待确认＋未接线＋不可达） | 13 |
| 真机已验证（累计） | 99（A02–A12 共 11、A14–A36 共 23、A37–A75 共 39、A76–A84 与 A175–A180 共 15、A85–A95 共 11，2026-11-25 双机通过，见 item02/item03/item04/item05/item06 报告；A34 手机为预期内的部分；A50、A75 为部分，A56、A78 不通过；A13、A19、A23 仍待确认，R7/R9/R1 未闭环） |

---

## 22. 风险与未确认项（代码走查发现，供后续批次定夺）

| 编号 | 问题 | 证据 | 影响 |
|---|---|---|---|
| R1 | 候选条最多显示 5 个；候选数量设置 5–15 无翻页；候选字号未传入候选条 | Parts26:822-829（`shown()` 截 5）；Index:5529-5539（数量/字号）；Parts26:812-820（无字号 prop） | 候选数量/字号两项设置可能“看得见但无效果”。【2026-11-25 核查①-3 双机确认】数量拉满后 hilog candCur 14 项、条仍 5 个无翻页；字号 20 与默认 15 的候选文字高度相同（手机 63px）。【2026-11-25 核查①-4 O5 同族观测】空格上屏后候选条不消失，仍显示上一串候选 |
| R2 | “无障碍覆盖层”开关无消费者、不落盘 | Index:989, 5368；全仓无其他读取 | 开关只改内存，重启即回 false |
| R3 | Index 全局菜单不可达；旧顶栏/功能行等组件未挂载 | Index:1329, 5559-5572；TopBar/FunctionRow/FontBar/CandidateBar/PaperPanel/GuideOverlay 均无实例化 | 菜单代码为死代码；相关旧组件不应再作为行为依据 |
| R4 | 顶区 `onBell`/`onPlate` 未接线；铃铛/铭牌点按不可达 | Parts26:230-233（声明但 build 未用）；Index:4779-4781 传了回调但组件不调用 | 打字机页没有铃铛开关与铭牌标题提示 |
| R5 | `Index.hintText` 从不渲染 | Index:329 及多处赋值（492/497/558/889/942/1174/1480），build 无 HintBar | 加词失败、学习清除、词库加载失败、IME 失败等反馈不可见 |
| R6 | 2020s 现代机覆盖不全 | HomePage:114-126（else→1960s 图）；Index:4656-4661（机名回落 1920s）；ExportCore:271-282（PDF 抬头回落 1920s）；CollectionDetail:15-20（M_INFO 缺 2020s）；Index:4672（设置循环 4 台） | 第 5 台机的部分页面显示错误/空白；2026-11-25 核查①-2 另发现：引导第 2 页写“四台时代机”，主题页实际 5 机型（截图 2381/2415 vs 2403/2436）。【2026-11-25 核查①-6 部分确认】收藏详情 2020s 史实段落空白（截图 2845/2878）、设置页机名回落 1920s（2847/2881）、主页 hero 回落 1960s（2846/2879）；收藏页仍写“四台”（O4）；PDF 抬头与 cycleMachine 循环仍待导出/设置批次 |
| R7 | 主页“导出”未设置导出目标 | Index:5099 直接 pushPage；ExportTarget 模块级目标无 clear 调用 | 可能沿用上一次卷宗/文档导出目标 |
| R8 | 删除方式 `ask` 与 `trash` 行为相同 | Index:4574-4582（只判 direct）；SettingsCore:20-32 | 三档实际只有两档效果。【2026-11-25 核查①-5 未复测：本批删除均在 trash 档完成，ask 与 trash 同效仍为代码走查结论】 |
| R9 | 换纸/换机只清 `cnPreview`，不 cancel 拼音会话/候选 | Index:4111, 2437；无 `pinyinSession.cancel()` | 组词中换纸/换机可能残留候选状态。【2026-11-25 核查①-3 双机确认】组词中换纸后候选仍在，点候选可落到新纸 |
| R10 | 打字机页引导锚点无节点 | Index:1073-1079；GuideAnchorMap 未被引用；type26 无对应 id | 聚光灯退化为居中气泡，无高亮洞。【2026-11-25 核查①-3 双机确认】重播引导后首次进打字机为居中气泡、整屏均匀压暗；dump 无 typewriter__ 节点 |
| R11 | 卷宗内页无“?”引导入口 | DossierDetail:729-735 `customHeader`；PageShell:60-86 自定义页眉跳过 help | 只能等首次自动引导，无法手动重看。【2026-11-25 核查①-4 双机确认】内页页眉只有返回/小封面/名字/⋯/导出/新建纸张，无“?”（截图 2742/2743） |
| R12 | 出纸槽直出 `image` 不支持且无提示 | Index:3429-3435（只 error 日志）；默认 `text` | 用户点出纸槽不会得到图片，也无反馈。【2026-11-25 核查①-3 双机确认】image 格式直出只记错误、exports/ 无新增、界面无提示 |
| R13 | 文档视图“分享·待实现”是死占位（已确认） | DocumentView:184-187 | 阅读页没有分享能力。【2026-11-25 核查①-5 双机确认：灰色死占位，点按无任何 App 侧响应、无 hilog，截图 2761/2762、2799/2800 前后差异仅状态栏】 |
| R14 | 卷宗页没有搜索入口 | DossierPage 全文无搜索；搜索只在 DossierDetail:437-453 | 与 O4 清单记录的缺口一致。【2026-11-25 核查①-4 双机确认】卷宗页只有标题/新建/列表，无搜索框（截图 2594/2718）；搜索仅在内页 |
| R15 | 字体/纸纹导入、分享、系统输入法 attach 依赖真机 API | FontManager:94-149；PaperCustom:139-170；ExportPage:584-643；Index:881-950 | 代码走查不能判定成功，必须真机验证 |
| R16 | 导出 8 个开关只影响图片/PDF 模板，纯文本导出不读取 | ExportPage:650-757 | 选 txt 时开关无效果，需在验收口径中写明 |
| R17 | 语言键标签不刷新（新，核查①-3 O5） | Index:4858-4862；Parts26:761 | 切中文后键仍显示“EN”，无激活红框；功能正常 |
| R18 | 跨引擎候选残留（新，核查①-3 O6，R9 同源） | 手机 2578 | 内置拼音组词未结束切系统输入法，候选条仍显示上一轮内置候选。【2026-11-25 核查①-4 O6 同源观测】长会话内置拼音缓冲残留 `niniceshi`，空格首选上屏“呢呢”而非“测试”（手机 2673/2675）；本批未做受控复现 |
| R19 | 字体牌首次点按无视觉变化（新，核查①-3 O7） | Index:3389-3400 | 未存字体偏好时首次点按 idx=-1→0 落回同一字体；第二次才切换 |
| R20 | 卷宗页列表刷新滞后（新，核查①-4 O1） | DossierPage 仅 `aboutToAppear`/`docs` 变更时 `reload()`；`onRenamed` 只增 `docsRev` | 改卷宗名/删卷宗（移出或连删）后返回卷宗页，卡片仍显示旧名或已删卷宗的“0 张纸”卡片，未归档计数也不更新；重进卷宗页才正确。数据本身已正确落盘。【2026-11-25 核查①-5 再次到场：平板删 `孤儿卷` 后卷宗页仍显示陈旧卡片（截图 2786），重进后正确】 |
| R21 | 内页“打开”不回打字机（新，核查①-4 O2，A56，高优先级） | Index.ets:1264-1270、5428-5432；`popTo('typewriter')` 在 `navStack` 不含 `typewriter` 时直接 return | 从主页进卷宗时栈为 `home→dossier→detail`，打字机不在栈内；打字机页菜单又没有“卷宗”入口，现实路径下必现。点“打开”只 `loadDocument`，画面仍停内页。【2026-11-25 核查①-5 A78 同源证据：文档视图点正文纸面同样只 `loadDocument`、不回打字机（平板截图 2757/2758 逐像素相同；Index.ets:5462-5466）】 |
| R22 | 重命名卷宗弹窗未预填当前名（新，核查①-4 O3，A50） | DossierDetail `renameBody()` 的 TextInput 只有 placeholder，无 `text: this.dName` | 点卷宗名打开的弹窗输入框为空，只显示占位“给卷宗起个名字”；用户需自行完整重输 |
| R23 | 手机内页空态文案与布局不符（新，核查①-4 O4） | DossierDetailPage.ets:525、506-513 | 手机内页空态写“点右上角「新建纸张」”，但手机页眉按 `widthVp<600` 隐藏了该按钮，入口实际在 ⋯ 菜单 |
| R24 | 手机文档视图正文页高度为 0（新，核查①-5 O1，A78，高优先级） | DocumentViewPage.ets:134-163（`Flex({direction: Column})` 内标题页 `height('100%')` 与正文页顺序排列，无滚动/压缩策略） | 手机（widthVp<600）文档视图只有标题页，正文页零高、落在容器外被裁掉，不可见也不可点；手机无法阅读正文。平板并排布局正常 | 
| R25 | 文档视图引导第 2 步锚点缺失、文案指向不存在的“编辑”（新，核查①-5 O3，A77） | DocumentViewPage.ets:254（`anchorId: 'document_view__edit_btn'` 不存在）；string.json:316-318 | 引导第 2 步文案“点「编辑」回打字机继续写。”，但页面上没有“编辑”按钮/文字；聚光灯退化为居中气泡、整屏压暗无高亮洞（第 1、3 步有洞，对比明显） |
| R26 | 收藏页无当前机标识，1920s 卡“默认机器”静态（新，核查①-6 O5，A87） | CollectionPage.ets:62-69（M_COND 为常量资源） | 收藏页没有“当前机器”标识；1920s 卡的“默认机器”是静态条件行，设为 2020s 后仍显示；2020s 卡条件行是整句描述，maxLines(1) 截断且无省略号（O6） |

---

## 23. 后续真机核查建议顺序

1. 启动引导 5 页（A02–A06）→ 主页 7 项（A07–A13）。
2. 打字机页：打字/退格/换行/换纸/退行/符号/中英/候选/字体牌/出纸槽/纸拖动（A14–A36），重点验证 R1、R9、R10、R12。
3. 卷宗页 → 内页 → 文档视图 → 回收站（A37–A84、A175–A180）。
4. 收藏页 → 收藏详情 → 设为当前（A85–A95），重点验证 R6。
5. 换装页 → 字体管理 → 纸张自定义（A96–A145），重点验证 R15。
6. 设置页 → 拼音设置（A146–A174），重点验证 R2、R6、R8。
7. 导出页三种范围/三种格式/8 开关/保存/分享（A181–A199），重点验证 R16。
8. 聚光灯引导与成就弹窗（A200–A207）。

---

## 24. 真机验证记录

| 批次 | 条目 | 结果 | 报告 | 截图 | 日期 |
|---|---|---|---|---|---|
| 核查①-2 | A02–A12 | 双机 12/12 通过 | item02-onboarding-home.md | 2380–2452（73 张） | 2026-11-25 |
| 核查①-2 | A13 | 保持待确认（R7 跨范围目标复用未验） | 同上 | 同上 | 2026-11-25 |
| 核查①-3 | A14–A36 | 平板 23/23，手机 22/23（A34 手机预期内部分） | item03-typewriter.md | 2453–2587（126 张） | 2026-11-25 |
| 核查①-3 | A19、A23 | 保持待确认（R9、R1 未修复） | 同上 | 同上 | 2026-11-25 |
| 核查①-4 | A37–A75 | 双机 36/39 通过，2 部分（A50、A75），1 不通过（A56） | item04-dossier.md | 2588–2748（158 张） | 2026-11-25 |
| 核查①-4 | A56 | 改待修（O2，高优先级：点“打开”只载入文档，不回打字机） | 同上 | 同上 | 2026-11-25 |
| 核查①-5 | A76–A84、A175–A180 | 双机 14/15 通过，1 不通过（A78） | item05-docview-trash.md | 2749–2820（71 张） | 2026-11-25 |
| 核查①-5 | A78 | 改待修（O1/O2：手机正文页 0 高；平板点正文不回打字机，R21 同源） | 同上 | 同上 | 2026-11-25 |
| 核查①-6 | A85–A95 | 双机 11/11 通过（A92 符合预期不可达） | item06-collection.md | 2821–2891（71 张，4 张作废） | 2026-11-25 |

- 发现问题 O1–O5 见 item02 报告 §2（O1＝R7 未闭环；O2＝引导“四台”与主题页五机型不一致，R6 同源；O3＝“开始写作”只关引导，符合预期；O4＝dumpLayout 方法注意；O5＝测试副作用，平板成就“纸尽其用”已解锁）。
- 测试残留：两台设备应用数据已清空、各留 1 篇含 `a` 的测试文档、各留 1 个导出文件；后续门图/验收前须再 `bm clean` 或换纸清空纸面。
- 核查①-3 新问题 O5–O7 记为 R17–R19（O5 语言键标签不刷新；O6 跨引擎候选残留，R9 同源；O7 字体牌首次点按无变化）；O1–O4 即 R1/R9/R10/R12 的双机确认；O8（手机纸拖 max=0）为预期行为、O9（双指长按触发系统识屏）为工具副作用，均非产品缺陷。
- 核查①-3 测试残留：两机均未 bm clean；平板纸面 `啊!尼`、统计约 45 字、新增成就“卷帙初成”“换过字体 1 次”；手机纸面非空；两机各留 1 个导出 txt；`lastExportFormat` 内存仍为 `image`（重启回 `text`）。后续门图/验收前须 `bm clean` 或换纸清空。
- 核查①-4 新问题 O1–O6：O1 列表刷新滞后记为 R20；O2（A56 打开不回打字机）记为 R21，A56 改待修；O3 改名弹窗未预填记为 R22；O4 手机空态文案错位记为 R23；O5 候选条残留并入 R1（同族观测）；O6 长会话拼音缓冲残留并入 R18（R9/R18 同源，未做受控复现）。
- 核查①-5 新问题 O1–O4：O1 手机文档视图正文页 0 高记为 R24（高优先级），A78 改待修；O2（A78 平板点正文不回打字机）并入 R21（同源）；O3 文档视图引导第 2 步锚点缺失/文案指向不存在的“编辑”记为 R25；O4 加页不更新 `meta.updatedAt` 为低优先级观察，记入 A79 备注。R13 双机确认（分享死占位）；R8 未复测（本批删除均在 trash 档）；R20 再次到场（删孤儿卷后陈旧卡片）。
- 核查①-4 测试残留：两机均未 bm clean；平板主页收工，卷宗 `测试卷宗二号`（2 张纸）、未归档 2 张、回收站 2 张；手机主页收工，卷宗 `测试卷宗二号`（2 张纸，含 `呢呢测试`）、未归档 2 张、回收站 1 张；删除方式仍为回收站档。后续门图/验收前须 `bm clean` 或换纸清空并按 item04 §5 仪式重拍/比对。
- 核查①-5 测试残留：两机均未 bm clean；平板主页收工，卷宗 `未归档 3 张纸`、`测试卷宗二号 2 张纸`（`测试`含 A79 追加的空行）、回收站 1 张；手机主页收工，卷宗 `未归档 2 张纸`、`测试卷宗二号 2 张纸`（`呢呢测试`含 A79 追加的空行）、回收站 0 张（空态）；删除方式仍为回收站档。后续门图/验收前须 `bm clean` 或换纸清空，并按 item05 §5 仪式重拍/比对。
- 核查①-6 新问题 O1–O6：O1 2020s 详情史实段落空白、O2 设置页机名回落 1920s、O3 主页 hero 回落 1960s（R6 三处已双机确认，PDF 抬头与 cycleMachine 仍待后续批次）；O4 收藏页仍写“四台”（R6 同族）；O5 无当前机标识、1920s 卡“默认机器”静态记为 R26；O6 2020s 卡条件行整句描述、截断无省略号（并入 R26）。
- 核查①-6 测试残留：两机均未 bm clean，本批未新建/删除文档；两机已恢复 1920s；收藏引导 seen 已变 true（后续进收藏页不再自动弹引导）。**平板处于锁屏（2891：“重启后需要输入密码”），需人工解锁后才能继续平板侧工作；下一批 audit07 被此阻塞**。手机正常停在主页。后续门图/验收前仍须 `bm clean` 或换纸清空。

---

## 附录 A：页面入口矩阵（从哪进哪）

| 目标页 | 入口 |
|---|---|
| 打字机 | 主页主按钮（继续/开始）；卷宗内页“打开”；文档视图正文；收藏详情“设为当前机器”后回主页再进 |
| 卷宗页 | 主页底部“卷宗” |
| 卷宗内页 | 卷宗页“未归档”/卷宗卡片；新建卷宗成功后自动进入 |
| 文档视图 | 卷宗内页纸缩略图 |
| 收藏页 | 主页底部“收藏”；成就 summary 弹窗“查看成就” |
| 收藏详情 | 收藏页任一机器卡 |
| 换装页 | 主页底部“主题” |
| 字体管理 | 换装页“字体管理” |
| 纸张自定义 | 换装页“纸张自定义” |
| 设置页 | 主页底部“设置” |
| 拼音设置 | 设置页“拼音设置” |
| 回收站 | 设置页“回收站” |
| 导出页 | 主页底部“导出”；卷宗内页“导出”；文档视图“导出”；出纸槽为直出，不进导出页 |

## 附录 B：页面引导与“?”入口

| 页面 | 自动引导 | 手动“?” |
|---|---|---|
| 主页 | 冷启动补跑一次 | 有（A07） |
| 打字机 | 首次进入自动弹 | 无 |
| 卷宗 | 首次进入自动弹 | 有（A38） |
| 卷宗内页 | 首次进入自动弹 | 无（R11） |
| 文档视图 | 首次进入自动弹 | 有（A77） |
| 收藏 | 首次进入自动弹 | 有（A86） |
| 收藏详情 | 首次进入自动弹 | 有（A94） |
| 换装 | 首次进入自动弹 | 有（A97） |
| 字体管理 | 首次进入自动弹 | 有（A131） |
| 纸张自定义 | 首次进入自动弹 | 有（A136） |
| 设置 | 首次进入自动弹 | 有（A147） |
| 拼音设置 | 首次进入自动弹 | 有（A162） |
| 回收站 | 首次进入自动弹 | 有（A176） |
| 导出 | 首次进入自动弹 | 有（A182） |

## 附录 C：下拉菜单/弹窗清单

| 菜单/弹窗 | 触发 | 选项 | 代码 |
|---|---|---|---|
| 卷宗页新建卷宗弹窗 | A39 | 名称、4 封面、取消、创建 | DossierPage:182-214 |
| 卷宗内页页眉菜单 | A51 | 改名、新建纸张、删除卷宗 | DossierDetail:738-751 |
| 删除卷宗弹窗 | A60 | 移出卷宗、连纸一起删、取消 | DossierDetail:612-629 |
| 纸卡片菜单 | A57 | 重命名纸、删除、取消 | DossierDetail:654-676 |
| 删除纸确认弹窗 | A66 | 删除、取消 | DossierDetail:631-651 |
| 重命名纸弹窗 | A65 | 输入、取消、保存 | DossierDetail:679-696 |
| 重命名卷宗弹窗 | A50 | 输入、取消、保存 | DossierDetail:698-721 |
| 文档删除确认 | A82 | 删除、取消 | DocumentView:203-223 |
| 拼音加词弹窗 | A166 | 词组、拼音、取消、添加 | PinyinSettings:167-195 |
| 我的词库弹窗 | A167 | 每词删除、完成 | PinyinSettings:197-228 |
| 回收站彻底删除确认 | A178 | 删除、取消 | TrashPage:171-192 |
| 成就弹窗 | 成就解锁 | 查看成就（summary）、关闭 | Index:4410-4450 |
| 全局下拉菜单 | 无入口（不可达） | 收藏、设置、导出 | Index:5559-5572 |

## 附录 D：import 但未实例化的旧件（不作为行为依据）

以下组件仍被部分文件 import，但当前 `build()` 中没有实例化；本清单不把它们计入控件：

- `TopBar`、`FunctionRow`、`FontBar`、`CandidateBar`、`PaperPanel`、`GuideOverlay`、`KeyboardPanel`（仅注释示例）、`PaperSheet`、`CarriageStrip`、`Cheek`、`SteelPlate`、`StrikeGuide`、`MachineStage`、`LeverLayer`、`LeverLayer1930/1950/1960`、`CarriageLayers`（仅 1920s 旧装配内部）、`TypebarLayer`（仅 1920s 旧装配内部）、`MetalAssembly1920`、`RollerAssembly1920`、`TypebarAssembly1920`、`BracketAssembly1920`、`CarriageLayers1930/1950/1960`、`TypebarLayer1930/1950/1960`。
- 当前打字机页实际挂载的是 type26：`Lid26`、`TopDeck26`、`Stage26`（含 `TopZone26`、`Carriage26`、`Basket26`、`FunctionCaps26`、`FontPlate26`、`CandStrip26`、`KeyWell`、`KeyGrid`）。
- 旧的 Canvas 页面键 `canvasDebug` 在 `syncFromStack` 中仍有布尔量（Index:1042），但 `build()` 无对应分支，属于遗留键。

---

*本文件只做枚举与代码走查，不改代码、不构建、不上真机。*
