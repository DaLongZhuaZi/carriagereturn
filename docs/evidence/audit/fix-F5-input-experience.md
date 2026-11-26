# F5 修复批：输入体验（R1、R9、R18、R17、R19、R12）

- 日期：2026-11-26
- 分支：`fix/input-experience`（base `main` @ `0838f2d`）
- 工作树：`D:\HarmonyAPP\carriagereturn\.worktrees\fix-input-experience`
- 构建：DevEco 26 hvigorw `assembleHap`（debug，signed hap）
- 设备：手机 ADA-AL00U `2UCUT24724009680`、平板 MLR-AL10 `192.168.5.133:42355`

## 1. 改动（2 个文件，+190/−45）

| 文件 | 改动 |
|---|---|
| `Parts26.ets` | `CandStrip26`：去掉写死 5 个；一页容量按字号/条宽折算；字号取自 `candFont`；左右翻页箭头（`‹`/`›`）；候选行内缩 18vp 并裁剪，避免压住拼音串；多页时按 `candPage`/`candPages` 显示。`FunctionCaps26`：`cap` 改为单对象参数（按引用传递），语言键标签由 `langLabel`（AppStorage）决定 |
| `Index.ets` | ① 候选一页容量 `candPageCap/candPerPage`（设置值是上限，超出按页翻）；设置改数量/字号后重算页码；② `cancelCompose()`：换纸、换机、切引擎时取消拼音会话并清候选；③ 出纸槽 image 直出改为「明确提示＋回落 txt」（`slotHint` 浮条 2.2s）；④ 字体牌首次点按（idx=-1）从下一款开始，避免落回同款；⑤ 语言状态/候选页码/候选字号写入 AppStorage，供槽位内子组件订阅 |

## 2. 根因（本批新查明的两件事）

1. **R17 的根子不在字符串拼接，而在 `@Builder` 传参**：`cap(label, idx, cb, active)` 是值传参，ArkUI 不会因参数变化刷新 UI，所以切中文后键面一直停在首次渲染的 `EN`。改为单对象参数（按引用）后标签随状态刷新。
2. **Stage26 槽位里的 `@Prop` 不可靠**：语言键/候选条都在 `Stage26` 的 `@BuilderParam` 槽位里，普通 `@Prop` 变化不保证传进去（实测标签不刷新）。改用 `@StorageLink`（`langLabel`／`candPage`／`candPages`／`candFont`）后稳定刷新。

## 3. 验收

| 条目 | 结果 | 证据 |
|---|---|---|
| R1 候选数量跟设置 | **通过** | 设置 15、字号 20 时 `ni` 有 42 个候选：每页 8 个（宽度上限），左右箭头翻页；第 2 页为「蔫儿 黏儿 年底 年度 黏度 念佛 黏附」（3613/3614），可翻到第 15 个以上 |
| R1 字号跟设置 | **通过** | 候选文字高度随字号设置变化（20 号时明显大于默认 15），见 3613 |
| R9 换纸清候选 | **通过** | 候选显示中点「换纸」：`paperChange start` 后 dump 无拼音、无候选（3615） |
| R18 切引擎清候选 | **通过** | `ni` 候选存在时点语言键：`你` 由 1 → 0、标签由「中」→「EN」，纸面不再残留候选（3617） |
| R17 语言键标签 | **通过** | 首次中文：「中」+ 红框；再按回「EN」（3613/3617 前后） |
| R19 首次点字体牌 | **通过** | 平板切 1930s（该机未设字体）后首次点字体牌：`font cycle -> SpecialElite (idx 1/17)`，牌面由 Courier Prime 变 Special Elite（3620） |
| R12 出纸槽 image 直出 | **通过** | 上次格式为 image 时点出纸槽：提示「图片直出暂不支持，已改为导出纯文本」（3619）；hilog `direct export image unsupported -> fallback text`、`direct export ok format=text path=…/exports/carriage-1795649360734.txt` |
| 回归 A14–A36 | **通过（抽验）** | 打字/退格/换行/换纸/退行/符号面板/中英切换/候选选择/字体牌/出纸槽/纸拖动：本轮均实际操作，hilog 见 `newlineDone rows=2`、`paperChange start`、`font cycle` 等（3621） |

## 4. 需要知道

1. **候选一页放几个由宽度决定**：设置值只是上限。字号 20 时一页 8 个（`ni`），15 号时 9–10 个；超出的用箭头翻页，能翻完全部候选。
2. **换纸/换机不再提交组词中的拼音**：按 D3/验收要求直接取消会话与候选；如果用户期望「换纸前自动上屏首选」，要另裁。
3. 两台设备留了测试痕迹：手机一页纸内容 `bbb`＋若干换纸、平板切在 1930s 且字体为 Special Elite（未清）。
4. 本批不改 1920s 静止像素，未跑门图（按任务要求）。

## 5. 截图（`docs/shots/`，3609 起）

| 编号 | 文件 | 内容 |
|---|---|---|
| 3609 | `3609_f5_phone_pinyin_settings.png` | 拼音设置（候选数量/字号滑杆） |
| 3613 | `3613_f5_phone_cand_page1_9_arrows.png` | 候选第 1 页 8 个＋右箭头、字号 20、语言键「中」 |
| 3614 | `3614_f5_phone_cand_page2.png` | 翻到第 2 页（不同候选，左箭头出现） |
| 3615 | `3615_f5_phone_paper_change_clears_cand.png` | 换纸后候选清空 |
| 3617 | `3617_f5_phone_engine_switch_clean.png` | 切英文后候选清空、标签 EN |
| 3619 | `3619_f5_phone_slot_image_fallback_hint.png` | 出纸槽 image 回落提示 |
| 3620 | `3620_f5_tablet_first_font_tap.png` | 平板首次点字体牌生效 |
| 3621 | `3621_f5_phone_regression_keys.png` | 回归：换行/换纸/符号面板 |

## 6. 提交

- 分支 `fix/input-experience`：2 个源文件 + 本报告 + 截图。不合 main、不推 main、不改清单。

## 7. 返工：候选翻页按实际宽度分页（R1，2026-11-26）

**原因**：上一版按「每个候选只占 字号＋8vp」估算，双字词实际占两倍宽。字号 20 时算出每页 8 个，第 2 页 7 个双字词约 328vp > 行宽 264vp，最后一个被右箭头裁掉一半、第 8 个完全看不见（3614 的问题帧）。

**改法**：
- `Index.candRanges()`：逐个累加「字数×字号＋8vp」，超过 264vp 或达到设置数量（`candPageSize`，仍为上限）即断页，返回各页起始下标；`pinyinShown`/`pinyinPick`/页码重算全部改用它。
- `Parts26.CandStrip26.shown()`：同一口径的兜底（260 宽内按实际宽度截断），与 Index 保持一致。
- 顺手清掉 `FunctionCaps26` 已不用的 `langZhLabel`／`langEnLabel` 两个 @Prop 及 Index 的传参（标签现走 AppStorage）。

**验收（双机重装）**：
| 场景 | 结果 | 证据 |
|---|---|---|
| 字号 20：第 1 页 | 8 个全可见，第八个「酿」完整，右箭头在（3622） | 与上一版相同，未回退 |
| 字号 20：第 2 页 | 蔫儿/黏儿/年底/年度/黏度 全部完整，无裁切，左右箭头都在（3623） | 上一版此处裁切 |
| 字号 15：第 1 页 | 蔫儿/你/尼/溺爱/昵爱/年/念 全部完整（3624） | — |
| 字号 15：第 2 页 | 娘/酿/黏儿/年底/年度/黏度 全部完整（3625） | 双字词满页不裁 |
| 平板默认 15 | 第 1 页 9 个、第 2 页 7 个全部完整，双箭头（3626/3627） | 双机一致 |
