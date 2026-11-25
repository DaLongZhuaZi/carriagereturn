# 核查①-3：打字机页双机逐项核查（A14–A36）

- 核查日期：2026-11-25
- 分支：`audit03-typewriter`（base `main` HEAD `e3ab5b8`）
- 范围：`docs/evidence/audit/item01-inventory.md` §5 打字机页（A14–A36），重点风险 R1／R9／R10／R12
- 设备与构建：
  - 平板 MLR-AL10（HUAWEI MatePad Mini），1600×2560，`192.168.5.133:42355`（TCP）
  - 手机 ADA-AL00U（nova 12 Ultra），1224×2776，`2UCUT24724009680`（USB）
  - 两台设备沿用现有安装包（audit①-2 同一构建，versionName 0.1.0）；本批未重新构建/安装，分支相对 base 无代码改动。

## 0. 起始状态（任务要求先记录）

1. 核查①-2 收工态：两台设备主页均显示“继续写作”，各留 1 篇含 `a` 的测试文档——平板 2453、手机 2454。
2. 进入打字机：纸面显示残留文档 `a`，光标在 `a` 后——平板 2455、手机 2456。
3. **正式起始状态**：各点一次“换纸 ↻”，旧纸归档、纸面清空，等待纸动画结束——平板 2457、手机 2458。此后 A14–A36 均从“空纸 + 内置拼音 + 1920s + 信纸”开始。
4. 平板在打字过程中弹出成就“卷帙初成（累计保存 10 次）”，已关闭（2459 带弹窗、2461 干净）；手机也弹出同一成就（2529），已关闭（2530）。属测试副作用，非缺陷。

## 1. 结论摘要

- A14–A36 共 23 项，双机逐项操作：**平板 23/23 项完成预期操作（A16 功能通过、附带 O5 语言键文案不刷新）；手机 22/23 项完整通过，A34 为部分（PanGesture 已识别，但手机版面上限内纸高未超视口，`max=0`，无可见位移）**。没有功能性崩溃、卡死或按钮完全无响应。
- **R1 已确认（双机）**：候选数量设置到最大（界面 15）后，输入 `ni` 的 hilog `candCur` 有 14 项，但候选条仍只显示 5 项，无翻页入口；候选字号设置到 20 后，候选条文字高度与默认 15 完全相同（手机实测均为 63px，平板候选文字高度 45px），字号设置无消费者。
- **R9 已确认（双机）**：拼音组词中（候选条有 `ha`）按“换纸 ↻”，新纸为空但候选条与拼音串仍在；点候选仍能把字落到**新纸**上。代码只清 `cnPreview`，未 `pinyinSession.cancel()`。
- **R10 已确认（双机）**：重播页面引导后首次进打字机，引导为居中气泡、整屏均匀压暗，没有高亮洞；`uitest dumpLayout` 中不存在 `typewriter__lever／typewriter__function_row／typewriter__paper` 任何节点。
- **R12 已确认（双机）**：先在导出页保存一次 PNG（`lastExportFormat='image'`），再回打字机点出纸槽：hilog 只有 `export slot tap -> direct export format=image` 与 `direct export image unsupported ... (no fallback)`，`exports/` 不新增文件，界面无任何提示。
- 新发现（详见 §2）：
  - **O5 语言键标签不更新**：切入中文后候选条已工作、hilog `applyChineseMode on=true`，但功能行语言键仍显示“EN”，也没有激活态红框；内置拼音与系统输入法两种引擎都复现（双机）。
  - **O6 切换中文引擎不清内置候选**：手机在内置拼音有 `ni` 候选时切到“系统输入法”，再进打字机开中文，系统键盘已弹出，候选条仍显示上一轮内置拼音的 `ni` 候选（2578）。
  - **O7 字体牌首次点按无视觉变化**：当前机型未存字体偏好时，`cycleFont()` 的 `idx=-1 → next=0`，第一次点按落回 Courier Prime，与当前显示相同；第二次点按才切到 Special Elite。属交互观感问题，非失效。

## 2. 逐项结果

> 结果口径：**通过**＝该控件在双机真机上完成预期操作且画面/落盘可证；**部分**＝动作被识别但客观条件使预期效果不可见；**不通过/缺陷**＝与清单预期不符且可复现。所有“通过”均以截图为准，hilog 只作辅助。逐键全量未做，字母/数字/符号按行取代表键（见 §7 缺口）。

| 编号 | 控件 | 平板 | 手机 | 关键证据（截图号） | 实际操作与结论 |
|---|---|---|---|---|---|
| A14 | 返回拨杆 | **通过** | **通过** | 平板 2496；手机 2554 | 点杠杆后约 1.4s 内回主页。600ms 卸纸动画时长未逐帧测量（本机 screenCap 400–500ms，见 AGENTS 工具边界）。 |
| A15 | 出纸槽（直出） | **通过（text）** | **通过（text）** | 平板 2487＋`exports/carriage-1795562962424.txt`；手机 2549＋`exports/carriage-1795565400075.txt` | 默认 `text` 时点槽，`exports/` 新增 txt；内容含归档纸页（“第 1/3 纸”等）。300ms 纸片滑出未捕获单帧（同上工具边界）。image 格式见 R12。 |
| A16 | 语言键 EN/中 | **通过（功能）＋O5** | **通过（功能）＋O5** | 平板 2475→2476→2479；手机 2540→2541；系统模式平板 2518、手机 2578 | 点语言键后候选条出现、`ni` 出候选，hilog `applyChineseMode on=true engine=builtin`；再点回英文正常。**但语言键标签始终显示“EN”**（中文模式下也是），激活态红框也不出现——O5。 |
| A17 | 退格 ⌫ | **通过** | **通过** | 平板 2466（英文）、2483（拼音缓冲）；手机 2532、2545 | 英文 `Z,./ m` 两连退删成 `Z,./`；拼音 `hau` 退成 `ha` 且候选重算。 |
| A18 | 换行 ⏎ | **通过** | **通过** | 平板 2463（Return 键）、2467（功能 ⏎）；手机 2528、2533 | 光标下移/插入新行，纸增高。手机另观察到与“超行自动换纸”一致的现象：hilog `newlineDone rows=11` 后紧接新纸 `rows=2`（08:11，见 §7）；未截到自动换纸瞬间，也未抓到 `newlineAtLastRow -> paperChange` 原文。 |
| A19 | 换纸 ↻ | **通过（功能）＋R9** | **通过（功能）＋R9** | 平板 2484→2486；手机 2546→2547 | 有内容换纸：旧纸归档、纸面清空、页码进位（导出 txt 中可见多纸）。**R9 复现**：组词中换纸后候选仍在，点候选可落到新纸。600ms 内“禁打字”未在窗口内实测（代码 `paperChanging` 守旗）。 |
| A20 | 退行 BL | **通过** | **通过** | 平板 2468；手机 2534 | 从第 3 行退到第 2 行行尾，随后输入的 `b` 接在上一行末尾。 |
| A21 | 符号 Aa | **通过** | **通过** | 平板 2472、2475；手机 2537、2540 | 面板下沉/升入切换，符号面板可见；再按回字母面板。 |
| A22 | 字体牌 | **通过＋O7** | **通过＋O7** | 平板 2469/2470（首点无变化）→2471（Special Elite）→2521（还原）；手机 2535→2536→2586 | 第二次点按起字体牌与纸面字体同步改变并持久化（离开再进仍生效）。首次点按因 `idx=-1→0` 落回默认，无视觉变化——O7。 |
| A23 | 候选词格（最多 5） | **通过＋R1** | **通过＋R1** | 平板 2479、2507；手机 2541、2561 | 点候选上屏；学习重排可见（先选“尼”后 `ni` 首候选变为“尼”）。**R1**：候选条恒定最多 5 个，无翻页。 |
| A24 | 数字行 13 键 | **通过** | **通过** | 平板 2459/2461、2493；手机 2525、2526 | `1 2 3 - =` 落字；双指注入 Shift+1 得 `!`（hilog `committed ch=[!] shift=on`）；符号面板 Backspace 生效（2474／2539）。数字行原生 Backspace 未单点（与符号行同 `onCapDown` 路径）。 |
| A25 | Q 行 12 键 | **通过** | **通过** | 平板 2462；手机 2527 | `q w [` 落字；Tab 使光标前移 4 个空格位。 |
| A26 | A 行 15 键 | **通过** | **通过** | 平板 2463；手机 2528 | Caps Lock 后 `A` 大写；`;` 落字；Return 换行。 |
| A27 | Z 行 12 键 | **通过** | **通过** | 平板 2464；手机 2529/2530 | Caps 下 `Z` 大写；`,` `.` `/` 落字。Shift 按住/松开由 A24 的 Shift+1 双指用例覆盖；未逐键验证 Shift+字母。 |
| A28 | 空格 | **通过** | **通过** | 平板 2465、2481；手机 2531、2543 | 英文空格落字（`Z,./ m` 可见间隔）；中文组词中空格选首选并上屏。 |
| A29 | 符号行 1（13 键） | **通过（代表键）** | **通过（代表键）** | 平板 2473/2474；手机 2538/2539 | `~ !` 落字；Backspace 删字。 |
| A30 | 符号行 2（13 键） | **通过（代表键）** | **通过（代表键）** | 同上 | `{`、Tab 路径生效（Tab 已由 A25 验证）。 |
| A31 | 符号行 3（15 键） | **通过（代表键）** | **通过（代表键）** | 同上 | `;` 落字；Return 路径已由 A26 验证。 |
| A32 | 符号行 4（12 键） | **通过（代表键）** | **通过（代表键）** | 平板 2473；手机 2538 | `§ ± × ÷ ≠ ≤ ≥ ∞ ¥ €` 全部上屏。 |
| A33 | 符号空格 | **通过** | **通过** | 平板 2474；手机 2539 | 符号面板空格生效（`¥ €` 之间可见间隔）。 |
| A34 | 纸面上下拖动 | **通过** | **部分（手势识别，max=0）** | 平板 2489→2490→2491→2492；手机 2550/2552→2551/2553 | 平板 16 行纸：拖动后 `paperPan off=80.8 max=174.8`，画面可见纸位上移；落字提交时 `paperOffset settle from=80.8 -> 0`。手机：10 行上限内 `paperPan` 有事件但 `max=0.0`，纸高未超视口，故无可见位移（设计上可拖范围为 0，非手势失效）。 |
| A35 | 悬浮“A”键 | **通过** | **通过** | 平板 2517→2518→2519；手机 2577→2578→2579 | 切“系统输入法”后进打字机开中文，系统键盘弹出且右上出现金色 A；点 A 后键盘收起、`applyChineseMode on=false engine=system`、A 消失。 |
| A36 | 数字键选候选 | **通过** | **通过** | 平板 2479→2480；手机 2541→2542 | `ni` 候选条下按 `2`，第二个候选“尼”上屏；候选条清空。 |

## 3. 问题清单

| 编号 | 对应风险 | 类型 | 问题 | 证据 | 复现（双机通用） |
|---|---|---|---|---|---|
| O1 | R1 | 设置无效／功能缺口 | 候选数量设置 5–15 只改内部 `candCurrent` 长度，候选条 `shown()` 固定截 5，`candPages` 从未渲染，无翻页；候选字号设置无消费者。 | 平板 2506（滑杆最大）→2507（仍 5 个）；hilog `cn pinyin buf=ni candAll=42 candCur=尼,你,溺爱,昵爱,年,念,娘,酿,蔫儿,黏儿,年底,年度,黏度,念佛`（14 项）；dump 候选文字高度 45px（平板）。手机 2557→2561（仍 5 个）；dump 高度 63px（字号设 20）与默认 15 时 63px 相同（2585 后 dump）。代码：Parts26:822-829、Index:5529-5539。 | 设置→拼音设置→候选数量拉到最大、候选字号拉到最大→回打字机打 `ni`；条上始终 5 个，无翻页，字号不变。 |
| O2 | R9 | 状态未清理 | 换纸只清 `cnPreview`，不清 `pinyinSession`/`candAll`/`candCurrent`；新纸上仍可按候选并落字。 | 平板 2484（新纸空、候选 `ha` 仍在）→2486（点“哈”落新纸）；手机 2546→2547；代码 Index:4109-4115 只 `this.cnPreview = ''`。 | 中文打 `ha` 出候选→点 ↻→等纸动画结束→候选仍在→点“哈”。 |
| O3 | R10 | 引导锚点缺失 | 打字机页引导锚点 `typewriter__lever/function_row/paper` 没有对应节点，聚光灯退化为居中气泡，无高亮洞。 | 平板 2500（居中气泡、整屏均匀压暗）；手机 2565；两机 `uitest dumpLayout` 均无 `typewriter__` 前缀节点；代码 Index:1073-1079。 | 设置→重播页面引导→回主页→进打字机（首次自动弹）。 |
| O4 | R12 | 静默失败 | 出纸槽直出 `image` 格式只记错误、不回落、无任何 UI 提示。 | 平板 2516；手机 2576；hilog 原文见 `item03-hilog.txt`（手机 08:41:57 两行）；`exports/` 无新增。 | 导出页保存一次 PNG（`lastExportFormat='image'`）→回打字机点出纸槽。 |
| O5 | 新 | UI 状态不刷新 | 切到中文后语言键仍显示“EN”，无激活态红框；内置拼音与系统输入法都复现。功能本身正常（候选/系统键盘均工作）。 | 平板 2476/2477/2478（中文模式、候选条工作、键仍 EN）→2479；手机 2541；系统模式平板 2518、手机 2578；hilog 均 `applyChineseMode on=true`。代码 Index:4858-4862 传 `langLabel: this.langZh ? zh : en`、Parts26:761 渲染。 | 打字机点“EN”→观察语言键标签与边框；候选条已出现但标签不变。 |
| O6 | 新（R9 同源） | 跨引擎状态未清理 | 内置拼音组词未结束时切“系统输入法”，再进打字机开中文，系统键盘已弹出，候选条仍显示上一轮内置拼音候选。 | 手机 2578（系统 IME 候选栏 + 条上 `ni 你 尼 溺爱 昵爱 年`）。 | 中文打 `ni`→设置切“系统输入法”→回打字机点 EN。 |
| O7 | 新 | 交互观感 | 字体偏好未设置时首次点字体牌，`idx=-1→0`，落回同一个 Courier Prime，无视觉变化；第二次点才切换。 | 平板 2469→2470（无变化）→2471；手机 2535→2536；hilog `font cycle -> CourierPrime (idx 0/17)`。代码 Index:3389-3400。 | 新装/未改字体时点字体牌一次。 |
| O8 | — | 行为说明（非缺陷） | 手机在 10 行上限内纸高不超过视口，`clampPaperOffsetVp` 的 `max=0`，拖动有手势事件但纸不动。 | 手机 2550/2552、2551/2553；hilog `paperPan dy=... max=0.0`（08:12/08:13）。 | 手机建 9–10 行纸→在纸面拖动。 |
| O9 | — | 工具副作用（非产品） | `uinput -T -m` 双指长按（Shift+1）会触发平板系统“智慧识屏”浮层；按 Back 可退出。 | 平板 2494（系统浮层）、2495（退回打字机）。 | 双指注入约 1s 长按。 |

## 4. 清单状态建议（仅建议，未修改清单文件）

| 条目 | 清单现状态 | 建议 |
|---|---|---|
| A14 | 已接线 | 保持“已接线”；备注“2026-11-25 双机真机通过（杠杆回主页）”。 |
| A15 | 已接线 | 保持“已接线”；备注“text 直出双机通过；image 路径 R12 已确认缺陷”。 |
| A16 | 已接线 | 保持“已接线”；备注“功能双机通过；O5 语言键标签不刷新待修”。 |
| A17 | 已接线 | 保持“已接线”；备注“英文与拼音缓冲退格双机通过”。 |
| A18 | 已接线 | 保持“已接线”；备注“Return/⏎ 双机通过；手机超行自动换纸已由 hilog 观察”。 |
| A19 | 待确认 | 建议**保持“待确认”直到 R9 修复**；功能（归档/清空/页码）本身双机通过。 |
| A20 | 已接线 | 保持“已接线”；双机通过。 |
| A21 | 已接线 | 保持“已接线”；双机通过。 |
| A22 | 已接线 | 保持“已接线”；备注“第二次点按起生效；首次点按见 O7”。 |
| A23 | 待确认 | 建议**保持“待确认”直到 R1 修复**；候选上屏与学习本身通过。 |
| A24–A33 | 已接线 | 保持“已接线”；备注“双机代表键通过；Shift 按住用双指注入验证 Shift+1”。 |
| A34 | 已接线 | 保持“已接线”；备注“平板可见位移通过；手机版面上限内 max=0（预期）”。 |
| A35 | 条件可用 | 保持“条件可用”；备注“双机系统模式通过（出现/点按退出）”。 |
| A36 | 已接线 | 保持“已接线”；双机通过。 |
| R1 | 待确认 | **改“已确认”**（候选数量/字号设置无效，条固定 5、无翻页）。 |
| R9 | 待确认 | **改“已确认”**（换纸不取消拼音会话，候选可落新纸）。 |
| R10 | 待确认 | **改“已确认”**（打字机引导锚点无节点，聚光灯无高亮洞）。 |
| R12 | 待确认 | **改“已确认”**（image 直出静默失败，无提示）。 |

## 5. 操作流水（可复核）

### 5.1 平板 MLR-AL10

1. 起始：主页（2453）→“继续写作”进打字机，残留 `a`（2455）→“换纸”清空（2457）。
2. 数字行 `1 2 3 - =`（2459 带成就弹窗→2461 干净）；Q 行 `q w [`＋Tab（2462）；A 行 Caps＋`A`＋`;`＋Return（2463）；Z 行 `Z , . /`（2464）；空格＋`m`（2465）；⌫×2（2466）。
3. 功能 ⏎＋`x`（2467）；BL＋`b`（2468）。
4. 字体牌首点无变化（2469/2470）→再点 Special Elite（2471）。
5. Aa 切符号面板（2472）→按 `~ ! { ; § ± × ÷ ≠ ≤ ≥ ∞ ¥ €`（2473）→符号 Backspace＋空格＋€（2474）→Aa 回字母（2475）。
6. 语言键→中文（2476/2477/2478，标签仍 EN）→`ni` 出 5 候选（2479）→数字 `2` 选“尼”（2480）→`ni`＋空格选首选（2481）→`hau` 候选（2482）→⌫ 回 `ha`（2483）。
7. 组词中换纸（2484）→点“哈”落到新纸（2486）。
8. 出纸槽直出 text（2487，落盘 `carriage-1795562962424.txt`）。
9. 连打 16 行（中间操作节奏见 §7 工具注）→拖纸前（2489）→拖动后（2490）→落字前未回位（2491）→空格提交后 `paperOffset settle`（2492）。
10. 双指 Shift+1 得 `!`（2493）；双指长按触发系统智慧识屏（2494）→Back 退出（2495）→杠杆回主页（2496）。
11. 设置页（2497）→重播页面引导第一次未命中（2498）→第二次点准（2500）→进打字机弹居中引导（2500）；dump 无 `typewriter__` 节点。
12. 拼音设置：滑杆拉最大（2506）→回打字机 `ni` 仍 5 个（2507，hilog candCur 14 项）；dump 候选高度 45px。
13. 导出页：当前纸＋图片（2510/2513）→系统保存选择器 `回车-啊尼-20261125-075056.png`（2514）→已保存（2515）→回打字机点出纸槽无文件无提示（2516，hilog 错误）。
14. 系统输入法：设置切系统（2517）→打字机开中文，系统键盘＋金色 A（2518）→点 A 退出（2519，`applyChineseMode on=false engine=system`）→设置切回内置（2520）→字体牌循环 16 次还原 Courier Prime（2521）→候选设置还原 9/15（2522）→回主页（2523）。

### 5.2 手机 ADA-AL00U

1. 起始：主页（2454）→进打字机残留 `a`（2456）→换纸清空（2458）；随后本批在打字机页测试。
2. 数字行 `1 2 3 - =`（2525）→双指 Shift+1 得 `!`（2526）；Q 行＋Tab（2527）；A 行 Caps＋`A`＋`;`＋Return（2528）；Z 行 `Z , . /`（2529 带成就→2530）；空格＋`m`（2531）；⌫×2（2532）。
3. 功能 ⏎＋`x`（2533）；BL＋`b`（2534）。
4. 字体牌首点无变化（2535）→再点 Special Elite（2536）。
5. Aa 符号面板（2537）→`~ { ; § ± × ÷ ≠ ≤ ≥ ∞ ¥ €`（2538）→符号 Backspace＋空格＋€（2539）→Aa 回字母（2540）。
6. 语言键→中文，候选条 `ni` 5 个但键仍 EN（2541）→数字 `2` 选“尼”（2542）→`ni`＋空格（2543）→`hao` 候选（2544）→⌫ 回 `ha`（2545）。
7. 组词中换纸（2546）→点“哈”落新纸（2547）。
8. 出纸槽：第一次坐标偏（2548）→按 dump 中心重点（2549，落盘 `carriage-1795565400075.txt`）。
9. 连打 9 行（2550）→10 行（2552）；拖动只收到 `paperPan max=0.0`（2551/2553）。
10. 杠杆回主页（2554）→设置（2555）→拼音设置（2556）→滑杆拉最大（2557）→回主页（2558）→进打字机（2559）→中文（2560）→`ni` 仍 5 个（2561）。
11. 设置滚动到底（2563）→重播页面引导（2564）→进打字机弹居中引导（2565）；dump 无 `typewriter__` 节点。
12. 导出页：当前纸（2567）→滚到格式（2568）→图片（2573）→保存选择器 `回车-a-20261125-082826.png`（2574）→已保存（2575）→回打字机点出纸槽无文件无提示（2576，hilog 错误）。
13. 系统输入法：设置切系统（2577）→打字机开中文，系统键盘＋金色 A，候选条仍残留内置 `ni` 候选（2578）→点 A 退出（2579）→设置切回内置（2580）→候选设置还原（2581）→字体牌循环 16 次还原 Courier Prime（2586）→回主页（2587）。

## 6. 证据文件

- `docs/evidence/audit/item03-hilog.txt`：本批从设备 `hilog -x` 实时读取的摘录（含手机 08:38 字体循环、手机 08:41:57 出纸槽 image 两行）。设备 hilog 环形缓冲滚动很快，部分早期行（平板 A24/R1/A34、手机 A35 等）在收尾补录时已被覆盖；这些行在操作当刻已读取并已写入本报告引述，原始截图仍是主证据。
- 本报告所有“通过/不通过”以截图为准（AGENTS 识屏验收铁律），hilog 与代码位置只作辅助。

## 7. 缺口与未验项

1. **A19 600ms 禁打字窗口未实测**：代码 `paperChanging` 守旗（Index:4133、3932、4221），本批未在动画窗口内强行按键取证。
2. **A34 手机无可见位移**：手机 10 行上限内 `paperGrow` 未超过视口高，`max=0`；只证明了 PanGesture 识别与 `paperPan` 事件，未证明可见拖动。平板已证明可见位移与回位。
3. **动画时长/中间帧未验**：A14 600ms 卸纸、A15 300ms 纸片、A18 换行三段编排都未逐帧；`snapshot_display` 单帧 400–500ms，按 AGENTS 工具边界不用连拍冒充。
4. **逐键全量未做**：字母/数字/符号按行取代表键；A32 的 10 个特殊符号全部按过，其余行未逐键。Shift 按住只验证了 Shift+1（双指注入），未逐字母验证按住 Shift 的每个键。
5. **系统输入法只验 attach/退出**：系统键盘弹出、浮动 A 出现与退出已验证；未通过系统 IME 实际输入中文上屏（本批范围与既有“只测系统输入法”口径一致）。
6. **R10 引导第 2/3 步未逐页截图**：第 1 步气泡＋双机 dump 已足证“无锚点节点”；引导按钮点按在自动化下偶尔未命中，未强求。
7. **A18 手机超行自动换纸无截图**：只有 hilog `rows=11` 后新纸 `rows=2` 的观察记录（08:11）。
8. **音效耳听、拨杆手感、动画主观流畅**不在本批范围，未代判。

## 8. 工具与方法注记

- `hdc` 不在 PATH，实际路径 `F:\HarmonyOS\SDK\26.0.0\toolchains\hdc.exe`。
- 截图：`snapshot_display -f /data/local/tmp/shot.jpeg` → `hdc file recv` → PIL 转 PNG；每张记录平均亮度（开工平板 51.3／手机 66.4，收工平板 51.3／手机 66.5，均 >20）。
- 点按/滑动：`uitest uiInput click/drag/swipe/keyEvent`；本机无 `input` 命令（AGENTS）。
- 屏幕常亮：两台均执行 `power-shell timeout -o 2147483647`＋`wakeup`＋`setmode 602`。
- **点击丢失**：本批多次遇到 `uitest uiInput click` 未命中（同一条命令重发即成功；连续快速发送时更明显），已用 1.2–1.6s 间隔、点后截图复核、按 dump 中心重点缓解；产品判定只以截图变化为准，未把工具丢失当产品失败。
- **双指注入**：`uinput -T -m x y x y x2 y2 x2 y2` 可同时按住 Shift 与数字键（A24 Shift+1），但约 1s 的双指长按会触发系统智慧识屏浮层（平板 2494），需 Back 退出。
- 手机 `dumpLayout` 的 y 与截图偶有偏移（audit①-2 O4 同源）；本批点按以 dump 中心为准，命中率高于截图目测。
- 设备：平板 `192.168.5.133:42355`（TCP）、手机 `2UCUT24724009680`（USB），收工时均 `Connected`。

## 9. 测试残留与收工状态

- 两台设备均**未** `bm clean`；应用数据沿用 audit①-2。
- 平板：主页（2523），当前文档纸面 `啊!尼`，统计“今日 45 字”左右；成就新增“卷帙初成”“换过字体 1 次”（audit①-2 已有“纸尽其用”）；字体已还原 Courier Prime；候选数量/字号已还原 9/15；中文引擎内置；`exports/carriage-1795562962424.txt` 留存；`lastExportFormat` 模块内仍为 `image`（重启即回 `text`）。
- 手机：主页（2587）；当前文档纸面含 `a` 及随后拼音提交的字（非空纸）；字体已还原 Courier Prime；候选数量/字号已还原 9/15；中文引擎内置；`exports/carriage-1795565400075.txt` 留存；`lastExportFormat` 模块内仍为 `image`。
- 屏幕常亮已设置，收工两机均亮屏（亮度 51.3／66.5）。
- **后续门图/验收前置**：当前纸面非空、统计与成就已被本批改写；跑 1920s 门图前须 `bm clean` 或换纸清空，并按 §5 仪式重拍/比对。

## 10. 截图索引（2453–2587，共 126 张）

> 编号规则：`<编号>_audit03_<设备>_<主题>.png`，均存 `docs/shots/`。手机号段 2524–2587；平板 2453–2523。个别编号因重拍覆盖或删除不连续（2460、2485、2488、2499、2501、2502、2513 旧名、2558 旧名、2570、2582、2583 已清理/更名，见下）。

### 10.1 平板（2453–2523，62 张）

| 编号 | 文件 | 内容 |
|---|---|---|
| 2453 | `2453_audit03_tablet_start_state.png` | 起始：主页“继续写作”，残留文档 |
| 2455 | `2455_audit03_tablet_typing_residual_doc.png` | 打字机残留 `a` |
| 2457 | `2457_audit03_tablet_empty_paper.png` | 换纸后空纸（正式起始） |
| 2459 | `2459_audit03_tablet_keys_number_row.png` | 数字行落字，带成就弹窗 |
| 2461 | `2461_audit03_tablet_keys_number_row_clean.png` | 数字行 `123-=` 干净 |
| 2462 | `2462_audit03_tablet_keys_qrow_tab.png` | Q 行＋Tab |
| 2463 | `2463_audit03_tablet_keys_arow_caps_return.png` | Caps＋A＋`;`＋Return |
| 2464 | `2464_audit03_tablet_keys_zrow.png` | Z 行 `Z,./` |
| 2465 | `2465_audit03_tablet_space_m.png` | 空格＋m |
| 2466 | `2466_audit03_tablet_backspace_x2.png` | ⌫×2 |
| 2467 | `2467_audit03_tablet_newline_function_x.png` | 功能 ⏎＋x |
| 2468 | `2468_audit03_tablet_backline_then_b.png` | BL＋b |
| 2469 | `2469_audit03_tablet_font_cycle1.png` | 字体牌首点（成就弹窗） |
| 2470 | `2470_audit03_tablet_font_cycle1_clean.png` | 首点后仍 Courier Prime |
| 2471 | `2471_audit03_tablet_font_cycle2.png` | 再点切 Special Elite |
| 2472 | `2472_audit03_tablet_symbol_panel.png` | 符号面板 |
| 2473 | `2473_audit03_tablet_symbols_typed.png` | 代表符号上屏 |
| 2474 | `2474_audit03_tablet_symbol_backspace_space.png` | 符号 Backspace＋空格＋€ |
| 2475 | `2475_audit03_tablet_letters_restored.png` | Aa 回字母 |
| 2476 | `2476_audit03_tablet_lang_zh_builtin.png` | 切中文（键仍 EN） |
| 2477 | `2477_audit03_tablet_lang_zh_retry.png` | 再次切中文（键仍 EN） |
| 2478 | `2478_audit03_tablet_lang_zh_again.png` | 第三次切换后状态 |
| 2479 | `2479_audit03_tablet_ni_candidates.png` | `ni` 5 候选 |
| 2480 | `2480_audit03_tablet_candidate_num2.png` | 数字 2 选“尼” |
| 2481 | `2481_audit03_tablet_cn_space_pick.png` | 中文空格选首选 |
| 2482 | `2482_audit03_tablet_cn_hao_candidates.png` | `hau` 候选 |
| 2483 | `2483_audit03_tablet_cn_backspace_buffer.png` | ⌫ 回 `ha` |
| 2484 | `2484_audit03_tablet_paperchange_with_pinyin.png` | 组词中换纸，候选仍在 |
| 2486 | `2486_audit03_tablet_stale_cand_commit.png` | 点“哈”落新纸 |
| 2487 | `2487_audit03_tablet_export_slot.png` | 出纸槽 text 直出 |
| 2489 | `2489_audit03_tablet_paper_drag_before.png` | 16 行纸拖动前 |
| 2490 | `2490_audit03_tablet_paper_drag_after.png` | 拖动后纸位上移 |
| 2491 | `2491_audit03_tablet_paper_drag_settled.png` | 拼音字母未触发回位 |
| 2492 | `2492_audit03_tablet_paper_drag_settled_commit.png` | 空格提交后回位 |
| 2493 | `2493_audit03_tablet_shift1_multitouch.png` | 双指 Shift+1 得 `!` |
| 2494 | `2494_audit03_tablet_system_smartscreen_overlay.png` | 双指长按触发系统识屏（工具副作用） |
| 2495 | `2495_audit03_tablet_after_system_overlay.png` | Back 退出系统浮层 |
| 2496 | `2496_audit03_tablet_lever_home.png` | 杠杆回主页（A14） |
| 2497 | `2497_audit03_tablet_settings.png` | 设置页 |
| 2498 | `2498_audit03_tablet_replay_page_guide_tap.png` | 第一次点重播（未命中） |
| 2500 | `2500_audit03_tablet_typewriter_guide_retry.png` | 打字机居中引导（无高亮洞） |
| 2503 | `2503_audit03_tablet_pinyin_settings2.png` | 拼音设置（带引导） |
| 2504 | `2504_audit03_tablet_pinyin_settings_clean.png` | 拼音设置（仍带引导） |
| 2505 | `2505_audit03_tablet_pinyin_settings_after_back.png` | Back 关引导 |
| 2506 | `2506_audit03_tablet_cand_sliders_max.png` | 候选数量/字号最大 |
| 2507 | `2507_audit03_tablet_ni_after_settings.png` | 设置后 `ni` 仍 5 个 |
| 2508 | `2508_audit03_tablet_export_page.png` | 导出页（带引导） |
| 2509 | `2509_audit03_tablet_export_image_selected.png` | 尝试选图片 |
| 2510 | `2510_audit03_tablet_export_current_image.png` | 当前纸＋图片 |
| 2511 | `2511_audit03_tablet_export_image_chosen.png` | 图片行尝试选中 |
| 2512 | `2512_audit03_tablet_export_image_chosen2.png` | 图片行再点 |
| 2513 | `2513_audit03_tablet_export_image_confirmed.png` | 图片已选中（当前纸预览） |
| 2514 | `2514_audit03_tablet_export_save_picker2.png` | 系统保存选择器（.png） |
| 2515 | `2515_audit03_tablet_export_saved_image.png` | 已保存（onSaved image） |
| 2516 | `2516_audit03_tablet_slot_image_no_effect.png` | 出纸槽 image 无文件无提示 |
| 2517 | `2517_audit03_tablet_settings_system_engine.png` | 中文输入＝系统输入法 |
| 2518 | `2518_audit03_tablet_system_ime.png` | 系统键盘＋金色 A |
| 2519 | `2519_audit03_tablet_floating_a_dismissed.png` | 点 A 退出中文 |
| 2520 | `2520_audit03_tablet_settings_builtin_restored.png` | 还原内置拼音 |
| 2521 | `2521_audit03_tablet_font_restored.png` | 还原 Courier Prime |
| 2522 | `2522_audit03_tablet_cand_settings_restored.png` | 还原候选 9/15 |
| 2523 | `2523_audit03_tablet_final_home.png` | 收工主页 |

### 10.2 手机（2524–2587，64 张）

| 编号 | 文件 | 内容 |
|---|---|---|
| 2454 | `2454_audit03_phone_start_state.png` | 起始：主页“继续写作” |
| 2456 | `2456_audit03_phone_typing_residual_doc.png` | 打字机残留 `a` |
| 2458 | `2458_audit03_phone_empty_paper.png` | 换纸后空纸（正式起始） |
| 2524 | `2524_audit03_phone_state_before.png` | 开始手机测试前的打字机态 |
| 2525 | `2525_audit03_phone_keys_number_row.png` | 数字行 `123-=` |
| 2526 | `2526_audit03_phone_shift1.png` | 双指 Shift+1 得 `!` |
| 2527 | `2527_audit03_phone_keys_qrow_tab.png` | Q 行＋Tab |
| 2528 | `2528_audit03_phone_keys_arow_caps_return.png` | Caps＋A＋`;`＋Return |
| 2529 | `2529_audit03_phone_keys_zrow.png` | Z 行（带成就弹窗） |
| 2530 | `2530_audit03_phone_keys_zrow_clean.png` | 关弹窗后 Z 行 |
| 2531 | `2531_audit03_phone_space_m.png` | 空格＋m |
| 2532 | `2532_audit03_phone_backspace_x2.png` | ⌫×2 |
| 2533 | `2533_audit03_phone_newline_x.png` | 功能 ⏎＋x |
| 2534 | `2534_audit03_phone_backline_b.png` | BL＋b |
| 2535 | `2535_audit03_phone_font_cycle.png` | 字体牌首点无变化 |
| 2536 | `2536_audit03_phone_font_cycle2.png` | 再点切 Special Elite |
| 2537 | `2537_audit03_phone_symbol_panel.png` | 符号面板 |
| 2538 | `2538_audit03_phone_symbols_typed.png` | 代表符号上屏 |
| 2539 | `2539_audit03_phone_symbol_backspace_space.png` | 符号 Backspace＋空格＋€ |
| 2540 | `2540_audit03_phone_letters_restored.png` | Aa 回字母 |
| 2541 | `2541_audit03_phone_ni_candidates.png` | 中文 `ni` 5 候选（键仍 EN） |
| 2542 | `2542_audit03_phone_candidate_num2.png` | 数字 2 选“尼” |
| 2543 | `2543_audit03_phone_cn_space_pick.png` | 中文空格选首选 |
| 2544 | `2544_audit03_phone_cn_hao_candidates.png` | `hao` 候选 |
| 2545 | `2545_audit03_phone_cn_backspace_buffer.png` | ⌫ 回 `ha` |
| 2546 | `2546_audit03_phone_paperchange_with_pinyin.png` | 组词中换纸，候选仍在 |
| 2547 | `2547_audit03_phone_stale_cand_commit.png` | 点“哈”落新纸 |
| 2548 | `2548_audit03_phone_export_slot.png` | 出纸槽首点坐标偏（未落盘） |
| 2549 | `2549_audit03_phone_export_slot2.png` | 出纸槽 text 直出成功 |
| 2550 | `2550_audit03_phone_tall_paper.png` | 9 行纸 |
| 2551 | `2551_audit03_phone_paper_drag_after.png` | 拖动后（max=0，无位移） |
| 2552 | `2552_audit03_phone_paper_10rows.png` | 10 行纸 |
| 2553 | `2553_audit03_phone_paper_drag_after2.png` | 10 行纸拖动后（max=0） |
| 2554 | `2554_audit03_phone_lever_home.png` | 杠杆回主页（A14） |
| 2555 | `2555_audit03_phone_settings.png` | 设置页 |
| 2556 | `2556_audit03_phone_pinyin_settings.png` | 拼音设置（带引导） |
| 2557 | `2557_audit03_phone_cand_sliders_max.png` | 候选数量/字号最大 |
| 2558 | `2558_audit03_phone_home_after_settings.png` | 设置后回主页 |
| 2559 | `2559_audit03_phone_typing_after_settings.png` | 回打字机 |
| 2560 | `2560_audit03_phone_cn_mode_after_settings.png` | 开中文（键仍 EN） |
| 2561 | `2561_audit03_phone_ni_after_settings.png` | 设置后 `ni` 仍 5 个 |
| 2562 | `2562_audit03_phone_home2.png` | 回主页 |
| 2563 | `2563_audit03_phone_settings_scrolled.png` | 设置滚到底 |
| 2564 | `2564_audit03_phone_home_after_replay.png` | 重播引导后回主页 |
| 2565 | `2565_audit03_phone_typewriter_guide.png` | 打字机居中引导（无高亮洞） |
| 2566 | `2566_audit03_phone_export_page.png` | 导出页（带引导） |
| 2567 | `2567_audit03_phone_export_current.png` | 当前纸（空纸，保存禁用） |
| 2568 | `2568_audit03_phone_export_formats.png` | 格式行 |
| 2569 | `2569_audit03_phone_export_save_picker.png` | 空纸导致保存禁用 |
| 2571 | `2571_audit03_phone_home3.png` | 回主页 |
| 2572 | `2572_audit03_phone_export_page2.png` | 重新导出（纸面有 `a`） |
| 2573 | `2573_audit03_phone_export_formats2.png` | 当前纸＋图片可选 |
| 2574 | `2574_audit03_phone_export_save_picker2.png` | 系统选择器（.png） |
| 2575 | `2575_audit03_phone_export_saved_image.png` | 已保存（onSaved image） |
| 2576 | `2576_audit03_phone_slot_image_no_effect.png` | 出纸槽 image 无文件无提示 |
| 2577 | `2577_audit03_phone_settings_system_engine.png` | 中文输入＝系统输入法 |
| 2578 | `2578_audit03_phone_system_ime.png` | 系统键盘＋金色 A＋残留内置候选 |
| 2579 | `2579_audit03_phone_floating_a_dismissed.png` | 点 A 退出中文 |
| 2580 | `2580_audit03_phone_settings_builtin_restored.png` | 还原内置拼音 |
| 2581 | `2581_audit03_phone_cand_settings_restored.png` | 还原候选 9/15 |
| 2584 | `2584_audit03_phone_home4.png` | 回主页 |
| 2585 | `2585_audit03_phone_ni_default_state.png` | 默认设置下 `nini` 仍 5 个 |
| 2586 | `2586_audit03_phone_font_restored.png` | 还原 Courier Prime |
| 2587 | `2587_audit03_phone_final_home.png` | 收工主页 |

## 11. 代码位置索引

| 条目 | 代码位置 |
|---|---|
| A14 | `Parts26.ets:243-258`（杠杆 onClick）→ `Index.ets:4778` `leaveTyping`（Index:1237） |
| A15 | `Parts26.ets:262-276`（出纸槽）→ `Index.ets:4780` `onExportSlot`→`directExport`（3372-3487） |
| A16 | `Parts26.ets:761`（语言键）→ `Index.ets:4863-4869` `onLang`；`applyChineseMode`（881-949） |
| A17 | `Parts26.ets:762`；`Index.ets:4870-4880`（组词退格分支）＋`onDelete`（3923） |
| A18 | `Parts26.ets:763`；`Index.ets:4881-4894`＋`onNewline`（4217-4339） |
| A19 | `Parts26.ets:764`；`Index.ets:4895`→`onPaperChange`（4109-4215） |
| A20 | `Parts26.ets:765`；`Index.ets:4896`→`onBackLine`（4020 起） |
| A21 | `Parts26.ets:766`；`Index.ets:4897-4916` |
| A22 | `Parts26.ets:776-805`；`Index.ets:4929`→`cycleFont`（3389-3407）、`applyMachineFont`（2230-2252） |
| A23 | `Parts26.ets:812-878`（`shown()` 822-829）；`Index.ets:4944`、`pinyinPick`（3212-3254） |
| A24–A28 | `KeyGrid.ets:174-210`；`Index.ets:3489` 起 `onCapDown` |
| A29–A33 | `KeyGrid.ets:110-149` |
| A34 | `Carriage26.ets:217-219`；`Index.ets:1626-1646` |
| A35 | `Index.ets:5575-5586` |
| A36 | `Index.ets:3340-3349` |
| R1 | `Parts26.ets:822-829`（`shown()` 截 5）；`Index.ets:5529-5539`（数量/字号设置只落 prefs） |
| R9 | `Index.ets:4109-4115`（换纸只清 `cnPreview`） |
| R10 | `Index.ets:1073-1079`（锚点 id）；type26 无对应 id（`p26_top_zone`/`p26_function_caps`/`p35_carriage`） |
| R12 | `Index.ets:3429-3435`（image 只 error，不回落） |
| O5 | `Index.ets:4858-4862`（langLabel/langActive）＋`Parts26.ets:761` |
