# F4 修复批：聚光灯与锚点（R34、R10、R25、R11）

- 日期：2026-11-26
- 分支：`fix/spotlight-anchors`（base `main` @ `a30529c`）
- 工作树：`D:\HarmonyAPP\carriagereturn\.worktrees\fix-spotlight-anchors`
- 构建：DevEco 26 hvigorw `assembleHap`（debug，signed hap）
- 设备：手机 ADA-AL00U `2UCUT24724009680`、平板 MLR-AL10 `192.168.5.133:42355`（常亮在线）

## 1. 改动（7 个文件，+40/−8）

| 文件 | 改动 |
|---|---|
| `HomePage.ets` | ① 按 D2 去掉 hero 图的 `.opacity(0.98)`（四处机型分支）；② 新增 `@Prop heroDim`：聚光灯需要压暗 hero 带时，在 hero Stack 内叠一层 `rgba(0,0,0,0.55)` 遮罩 |
| `SpotlightOverlay.ets` | 新增 `onStepChange(index)` 回调（每步量锚点时上报），供 Index 判断洞口是否落在 hero 上 |
| `Index.ets` | ① 打字机引导锚点改指真实节点：`p26_function_caps`（功能行）、`p35_paper`（纸）；② 新增 `@State guideStepIndex`，向 HomePage 传 `heroDim = 引导可见 && 非启动引导 && !(主页第 1 步)` |
| `Parts26.ets` | 顶部返回拨杆补 `.id('typewriter__lever')` |
| `DocumentViewPage.ets` | 平板正文页补 `.id('document_view__body')`；引导第 2 步锚点由不存在的 `document_view__edit_btn` 改为 `document_view__body`（D11） |
| `DossierDetailPage.ets` | 自定义页眉在 ⋯ 左侧加「?」帮助按钮（`dossier_detail__help_btn`），点击 `GuideBridge.request('dossier_detail')`（D12） |
| `string.json`（base） | `guide_document_view_2` 文案改为「点正文纸面，回打字机继续写。」 |

## 2. 根因与做法说明

### R34 聚光灯压不住主页 hero
- 实测（改前）：第 2 步 hero 带压暗 1.9–5.4%，而标题带 23%、按钮带 51%。
- 按 D2 去掉 hero `opacity(0.98)` 后仍只有 1.9–5.4%，说明不是 `opacity` 造成的合成层。
- 再试给 hero 加 `zIndex(-1)`：截图逐像素与改前一致（仅状态栏差异 1589 px，全在顶部 5% 区域外），说明 hero 与遮罩的绘制顺序并不由 zIndex 决定。
- 结论：在这个页面结构下，遮罩层压不住 hero 带（大图＋渐变的独立成像）。**最终做法**：保留去掉 `opacity(0.98)`，另由 HomePage 在需要时自行叠加同 alpha（0.55）的压暗层，效果与整屏遮罩一致，且洞口在 hero 上时（第 1 步）不加。

### R10 打字机引导锚点
- 原三个锚点 id（`typewriter__lever`／`typewriter__function_row`／`typewriter__paper`）在打字机页没有任何节点。现改为：拨杆补 `typewriter__lever`；功能行与纸改用页面已有 id `p26_function_caps`、`p35_paper`。

### R25 文档视图第 2 步
- 页面没有「编辑」按钮，`document_view__edit_btn` 只有 anchorId。改为指向正文区 `document_view__body`，文案同步改为「点正文纸面」。

### R11 内页「?」
- `PageShell` 的 help 只在默认页眉渲染，内页用 `customHeader`。现由内页自己在 ⋯ 左侧渲染「?」，`GuideBridge.enabled` 为假时不显示。

## 3. 验收

| 验收项 | 结果 | 证据 |
|---|---|---|
| 主页引导第 1 步：洞口在 hero 上，hero 不压暗 | **通过** | 手机 hero 带 −0.6%～0.0%（即不变），标题 5.6%、按钮 68.7% |
| 主页引导第 2 步：hero 压暗与整屏一致 | **通过** | 手机 hero 带 53.5–56.6%、按钮 51.2%；平板 hero 带 55.0%、按钮 52.0% |
| 主页引导第 3 步：hero 仍压暗 | **通过** | 手机 hero 带 54.9%、按钮 81.5% |
| 打字机引导第 1 步锚点＝拨杆 | **通过** | 手机 `guide anchor typewriter/1 id=typewriter__lever rect=7.7,47.7,16.0,32.0`；平板 `14.7,62.7,29.7,41.9` |
| 打字机引导第 2 步锚点＝功能行 | **通过** | 手机 `typewriter/2 id=p26_function_caps rect=0.0,455.7,362.7,67.0`；平板 `136.3,539.8,401.0,67.0` |
| 打字机引导第 3 步锚点＝纸 | **通过** | 手机 `typewriter/3 id=p35_paper rect=71.4,260.8,219.8,58.0`；平板 `132.6,311.8,408.3,65.6` |
| 文档视图第 2 步锚点＝正文 | **通过** | 手机 `document_view/2 id=document_view__body rect=20.0,375.4,322.7,360.0`；平板 `344.6,119.6,309.3,874.5`；文案「点正文纸面，回打字机继续写。」 |
| 内页「?」可用 | **通过** | 手机帮助按钮 `b=[914,249][1036,371]`，点击后 `guide anchor dossier_detail/1 id=dossier_detail__list`；平板 `b=[1039,175][1125,261]`，同样拉开引导 |
| 门图（1920s） | **通过** | 手机 vs `3579`：四区 0.00%/0/0/0（maxdiff 0）；平板 vs `3578`：0.00%/0.00%/0.00%/0.00%（maxdiff 1，< 阈值 30） |

门图前置：两机冷启动、引导关闭、空纸（点一次换纸清空当前纸）、默认字体。

## 4. 观察

1. **hero 遮罩的取舍**：做法是「页面自己再压一层」，而不是修好遮罩合成。优点是效果与整屏一致、可控；代价是遮罩与页面各压 0.55 时，若将来把遮罩改深，两处需一起改（已在此记录）。
2. **打字机第 2/3 步锚点用的是既有 id**（`p26_function_caps`／`p35_paper`），没有新增节点；若这两处 id 改名，引导会退化为居中气泡。
3. 平板门图 maxdiff 1（frame 三区）来自状态栏以外不到 1 个通道级的抖动，远低于阈值 30，四区超阈像素均为 0。
4. 测试后两台设备停在主页（引导已关），未清理文档数据（手机与平板各 1 篇 `bbb`/`aaa` 测试纸）。

## 5. 截图（`docs/shots/`，3592 起）

| 编号 | 文件 | 内容 |
|---|---|---|
| 3592 | `3592_f4_phone_home_before.png` | 手机主页（引导前基线） |
| 3593 | `3593_f4_phone_home_guide_s1_hero.png` | 手机第 1 步：洞在 hero，hero 不压暗 |
| 3594 | `3594_f4_phone_home_guide_s2_hero_dim.png` | 手机第 2 步：hero 与整屏一起压暗 |
| 3596 | `3596_f4_phone_typewriter_guide_s1_lever.png` | 手机打字机第 1 步：拨杆有洞 |
| 3597 | `3597_f4_phone_typewriter_guide_s2_function_row.png` | 手机打字机第 2 步：功能行有洞 |
| 3598 | `3598_f4_phone_typewriter_guide_s3_paper.png` | 手机打字机第 3 步：纸有洞 |
| 3599 | `3599_f4_phone_docview_guide_s2_body.png` | 手机文档视图第 2 步：正文有洞、新文案 |
| 3600 | `3600_f4_phone_detail_help_guide.png` | 手机内页点「?」拉起引导 |
| 3601–3603 | `360*_f4_tablet_typewriter_guide_s1/s2/s3.png` | 平板打字机三步 |
| 3604 | `3604_f4_tablet_detail_help_btn.png` | 平板内页页眉：问号在 ⋯ 左侧 |
| 3605 | `3605_f4_tablet_detail_help_guide.png` | 平板内页引导 |
| 3606 | `3606_f4_tablet_docview_guide_s2.png` | 平板文档视图第 2 步 |
| 3607 | `3607_f4_tablet_home_before.png` | 平板主页基线 |
| 3608 | `3608_f4_tablet_home_guide_s2_hero_dim.png` | 平板第 2 步 hero 压暗 |

## 6. 提交

- 分支 `fix/spotlight-anchors`：7 个文件 + 本报告 + 截图。不合 main、不推 main、不改清单。
