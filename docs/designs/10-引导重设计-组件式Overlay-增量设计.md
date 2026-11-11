# 第 10 批增量设计：引导重设计（组件式 Overlay）

* **Author:** 沙箱 Kit（父 agent）
* **Date:** 2026-11-11
* **Status:** 已批准（用户 2026-11-11 14:00，原话"批准，按缺省执行"；v2.1 定稿）
* **总纲:** `docs/designs/功能新增与体验优化总纲.md`（F1 启动引导＋每页引导）
* **前置:** 第 1 批设计 `docs/designs/1-引导与拨杆跟手-增量设计.md`；现行实现 HEAD `911bf97`
* **触发策略（用户 2026-11-11 已定）:** 首次进页自动弹一次；每页固定 "?" 入口可随时重看
* **评审:** `~/workspace/egm-work/guide-redesign-review.md`（1 Blocker／16 Major／18 Nit，2026-11-11）；本稿 v2 逐项 resolve，见 §14

## 0. 现状与问题（读码坐实，非推测）

| # | 现象（用户原话） | 代码事实 |
|---|---|---|
| P1 | 引导"根本不是我要的那种精确的组件式 overlay 引导" | `GuideOverlay.ets` 只渲染底部卡片（标题＋编号文字＋"知道了"）＋45% 黑遮罩；`GuideStep.anchor` 与 `anchorText()` 全仓无任何调用点（除定义本身），没有任何一页传过 anchor——锚定系统只写了接口，从未实现 |
| P2 | "经常会莫名其妙的出现" | `maybeShowPageGuide()`（`Index.ets` L971）挂在 `syncFromStack()` 里，进页、返回都跑；首次进任何一页就弹，包括中途路过的页；启动引导关后 120ms 立即连弹主页引导；`currentGuidePage()`（L953）是布尔标志优先级链（trash > pinyin > settings > export > fontManager > paperCustom > collectionDetail > collection > customize > docView > dossierDetail > dossier > typewriter > home），栈顶不是唯一事实源 |
| P3 | "没有固定的触发按钮" | 唯一入口藏在设置页最下方两行"重播页面引导／重播启动引导"；顶栏（`TopBar.ets`）与各页页壳（`PageShell.ets`）没有任何引导入口；`replayPageGuide()` 是"全清＋下次进页才生效"，不是"现在就看这页的引导" |
| P4 | 每页引导只有"知道了"，没有跳过 | 页面引导挂载（`Index.ets` L4795）只传了 `onNext`／`onClose`，未传 `showSkip`（默认 false）与 `onSkip`；跳过按钮只在启动引导上存在 |
| P5 | 锚点量测无从谈起 | 现行实现完全不量组件几何；但量测机制本仓已有现成先例：`DossierDetailPage.ets` L169–173 用 `ui.getComponentUtils().getRectangleById('hdr_cover')` 取 screenOffset／size，px2vp 后换算——本批直接复用同一机制，不引入新 API。**注意（评审 B1）：该前例量的是已在屏上的静态页眉，本批量的是正在滑入的新页，时序前提不同，见 §8.1** |
| P6 | 文案本身不差 | 14 页各 3 条均为一句短话（如"敲键落字；拉下拨杆换行"），与 hint 行口径一致；乱的是形式与触发，不是文案——本批不改文案，只改形式与触发 |

**两处口径订正（评审 M15／N13，v2 改）：** ① 设置页"重播页面引导"（`resetPages` 清 14 页 seen）是**用户主动操作**，不是乱弹——§0 原稿把它列为乱弹机制之一是错的；本批保留其原语义，只修另外三处（进／返都触发、120ms 连弹无豁免、栈顶优先级链）。② `currentGuidePage` 的 settings＋export 优先级问题是**潜在误判源**，不是实发机制——已核实：导出只从主页底部导航（`Index.ets` L4425）与汉堡菜单（L4764）推入，两处在设置页打开时都被覆盖层盖住，栈里走不到 settings＋export 同时存在；§4.3 的修复（只认栈顶）仍然成立。

## 1. 目标与已定事项

1. **形态（缺省）：聚光灯＋气泡（spotlight coach mark）**——遮罩给目标组件开洞（洞外压暗、洞内正常显示），气泡指到组件上，一次只讲一个组件，一步一步走；不再是"三条编号文字一次全列出来"的底部卡片。
2. **触发（用户已定）：首次进页自动弹一次。** 保留现行 `GuideService.shouldShow` 语义（开关开 && 未看过 && 非回归模式），修掉 §0 的三处乱弹机制（只推不返、启动引导链路豁免、只认栈顶）。
3. **固定入口：每页一个 "?"。** 点它立即看本页引导，不经过 seen 判定；看完记 seen（见 §5）。
4. **复用已有的好结构：** Index 单挂载点不变；`GuideService`／`GuideCore` 的 seen 读写与键名不变；启动引导保持底部卡片形态（它没有页内锚点，不改）；各页 `guideStepsFor<Page>()` 继续与功能同处一源（实现方在各页文件内声明，见 §6）；现有 `guide_<page>_<n>` 文案 1:1 复用为气泡文字，不重写文案。
5. **开关不变：** `guide.enabled` 仍是产品总开关（默认 on）；关掉时 "?" 按钮一并隐藏，自动弹也不弹。

## 2. 锚定机制

1. **类型拆分（评审 M1）：** `GuideStep`（`GuideOverlay.ets`）的 `text` 字段与整体结构保持原样，仍专供启动引导；删的只是其 anchor 相关成员（见下）。页面引导另立新类型 `SpotlightStep { text: ResourceStr; anchorId: string }`（`anchorId` 必填）。各页 `guideStepsFor<Page>()` 返回值由 `GuideStep[]` 改为 `SpotlightStep[]`；Index 内联的打字机页三条（`Index.ets` L926–930）同样补 `anchorId`。**旧锚定机制删除（评审 N18）：** 删 `GuideAnchor`、`GuideStep.anchor`、`GuideOverlay` 的 `@Prop anchor` 与 `anchorText()`；`check-contracts.py` 同步更新。
2. **声明：** `anchorId` 是组件 id，全仓全局唯一，强制按页加前缀（`dossier_detail__new_btn` 式，评审 M2——`getRectangleById` 是窗口全局查找，无页作用域）。目标组件挂 `.id(anchorId)`；anchorId 只挂单例组件，列表项（`ForEach` 生成的卡片／行）不得锚单项，须锚列表容器或页眉（评审 N10）。
3. **量测：** 沿用 `DossierDetailPage.ets` 已验证的机制——目标组件挂 `.id(anchorId)`，浮层显示前 `ui.getComponentUtils().getRectangleById(anchorId)` 取 screenOffset／size，`getUIContext().px2vp()` 现算换算成 vp 矩形。**禁止**存换算常量、禁止跨设备复用换算值（评审 N1；v1 稿示例值 0.3636 是折叠模拟器侧数值，已删除）。量测时序见 §8.1（评审 B1）。
4. **量不到的 fallback（不许以此停工）：** 某步锚点在当前设备／布局下量不到（组件未挂载、id 拼错、折叠态布局不同），该步气泡居中显示＋记 hilog（`guide anchor miss <page>/<n> <anchorId>`），其余步照常走；批报告如实列出 miss 清单。**量不到不是阻塞，只是不符点。**
5. **锚点必须可见：** 锚点组件在浮层显示时必须处于可见状态（不在折叠带内、不在键盘遮挡区内）；打字机页的锚点避开候选栏与键盘区，只锚纸面／字车／拨杆等常驻件。
6. **单一事实源（评审 N17）：** anchorId 只在各页 `guideStepsFor` 里声明（与文案同处一源）；`GuideCore` 的声明表只存每页步数（§6 表）；anchorId 全仓唯一性与存在性（`.id()` 是否挂上）由 `guide-keys` 测试静态解析 14 页源码断言，不由运行时断言。

## 3. 渲染器（新组件 SpotlightOverlay，取代页面引导的 GuideOverlay 挂载）

1. **结构：** 全屏 Stack（zIndex 与现行引导同级，挂在根 Stack 最上层，单挂载点仍在 Index；与成就弹窗的相对顺序见 §4.5）。遮罩由目标矩形四周的四块压暗矩形拼成（上／下／左／右，`rgba(0,0,0,0.55)`），洞口处另盖一个透明底＋`#c9a45c` 2vp 边框的描边框（评审 N4：四块矩形拼不出描边），圆角缺省 8vp（评审 N3：`getRectangleById` 不给圆角，不许写"与目标矩形同圆角"）。**洞内不盖任何不透明东西**（评审 M6）：洞口上盖一层透明捕捉节点，目标组件保持原样可见、不可点。
2. **气泡位置算法（评审 M7，必做，抽纯函数见 §9）：** 气泡宽＝min(内容宽，屏宽−32vp)；上下判定以目标中心纵坐标 vs 屏高一半为准——目标中心在上半区 → 气泡放目标下方，在下半区 → 放目标上方；左右居中对齐目标中心，左右各留 ≥16vp 边距，超了就 clamp 到屏内；所选一侧放不下（剩余高度 < 气泡高＋8vp）→ 试另一侧；两侧都放不下 → 气泡居中在不盖目标的较大一侧空余区；若气泡高大于较大一侧空余区高（文案均为一句短话，理论分支）→ 气泡居中显示，仍以不盖目标为优先，实在避不开时居中并记 hilog（`guide bubble overlap <page>/<n>`）。**箭头位置独立跟目标中心走**（气泡被 clamp 移位后箭头仍指向目标中心横坐标，clamp 到气泡宽度内），不跟气泡中心走。**禁区：** desk 半开态下气泡禁入折痕带（用 `FoldService` 的 creaseTop／creaseBottom 比对，撞带则向最近一侧移出）；打字机页气泡禁入键盘区（PhotoKeybed＋FunctionRow 所在区域；键盘区矩形取当前布局值：纵向从 stage 底边向上 keybedHeightVp＋FUNCTION_ROW_HEIGHT_VP（＋候选栏可见时的 CANDIDATE_BAR_HEIGHT_VP），横向全宽）。文案均为一句短话，气泡高由内容定，不做滚动。
3. **按钮：** 第 1 步无"上一步"；中间步"上一步／下一步"；最后一步保留"上一步"＋"知道了"（评审 N5）；全程常驻"跳过"（文字链样式，放左下）。点遮罩任意处＝关闭：四块遮罩矩形与洞口透明捕捉层各自带 `onClick` → 关闭（评审 N16）；气泡卡片吞点击（沿用 `GuideOverlay` 的兄弟节点教训）。关闭与跳过都记 seen（§5）。
4. **步骤点（评审 M10）：** 不用 ●○○ 文字符号（AGENTS 图标铁律禁 Text 符号当 UI 图标），改用 `Circle()` 组件绘制的圆点（当前步实心金色、其余空心灰色），或细进度条。
5. **切换顺序（评审 N11）：** 点"下一步" → 先量下一步锚点（量到或 fallback）→ 再开 150ms 淡入淡出切洞口与气泡；不许先切后量。切换期间不许吞掉下一次点击（防连点丢步）。
6. **启动引导不动：** 启动引导（4 条）继续用现行 `GuideOverlay` 底部卡片挂载（`Index.ets` L4786），不改形态、不改文案；页面引导改挂 `SpotlightOverlay`。两个挂载点仍在 Index 根 Stack 最上层，互斥显示（启动引导优先）。
7. **新增资源键：** `guide_btn_prev`（"上一步"）、`guide_btn_next`（"下一步"）写入 `string.json`；现有 `guide_btn_skip`／`guide_btn_ok` 复用。

## 4. 触发策略（修 §0 的三处乱弹）

1. **只在前进时弹（评审 M4）：** depth 比较只发生在 `syncFromStack` 的调用点：Index 持一个普通 `private` 字段记上次栈深（`aboutToAppear` 时初始化为当前栈深，不许用 `@State`，否则每次更新触发重渲染——评审 N8），`syncFromStack` 内栈深变大才调 `maybeShowPageGuide()`，不变或变小直接跳过。`maybeShowPageGuide` 本身不做 depth 判定，也不设 `force` 参数（窄复核新 Nit-1：守卫不在该函数内，参数空转）。**冷启动例外（窄复核新 Major-1）：** 主页是栈底，永不被 push——回访用户（启动引导已看过，`closeOnboarding()` 不跑）冷启动时 depth 守卫会让主页引导永不弹，与"首次进页自动弹一次"直接冲突。补一条：冷启动首次布局稳定后（走 §8.1 冷启动时序，等一帧），若启动引导不弹（已看过）且 `GuideService.shouldShow('home')` 为真，对主页跑一次 `maybeShowPageGuide()`；此后不再补跑（只跑一次，不设定时器追弹）。
2. **启动引导后的连弹（评审 M4）：** `closeOnboarding()` 的 120ms 链路直接调 `maybeShowPageGuide()`（该调用点不经过 depth 守卫，无需 `force` 参数）；看过则不弹（`shouldShow` 仍把关）。**不许**在启动引导关闭后补弹其它页的引导。
3. **不与 Index 已知的浮层叠加（评审 M5 收窄）：** 启动引导可见（`onboardingVisible`）或成就弹窗可见（`achNoticeKind` 非空）时，页面引导不弹（等浮层关掉后也不补弹——下次进页再说，不许用定时器追弹）。**已知缺口：** 各页局部的 AppDialog（删卷宗、改名等确认框）Index 无法感知，不纳入本批检测——缺口成立的理由：确认框由用户点按打开，而引导自动弹只发生在 push 时，模态确认框打开期间无法点按触发 push，两者撞上的残余概率极低；批报告如实记为已知缺口。
4. **当前页只认栈顶：** `currentGuidePage()` 改为只读 `navStack` 栈顶映射，不再读 `trashOpen`／`settingsOpen` 等布尔标志。栈顶到 page id 的映射表仍在 Index 内，覆盖 14 页。
5. **挂载顺序与成就弹窗打断（评审 M14）：** `SpotlightOverlay` 仍挂在 `AppDialog` 之前（成就弹窗在上，与现行 `GuideOverlay` 的相对顺序一致，`Index.ets` L4786–4810）。成就弹窗弹出时若引导正开着：引导先关掉（记 seen）再弹成就弹窗——成就达成是单次奖励时刻，不许被引导盖住。
6. **手动 "?" 不受 seen 与回归模式限制，只受总开关限制：** `guide.enabled=false` 时 "?" 隐藏；回归模式（测试构建）下 "?" 仍可手动打开（便于验收），但自动弹仍关闭。**重入守卫（评审 M11）：** `showPageGuide(page, { manual: true })` 入口先判 `guideVisible`／`onboardingVisible`，已开则直接忽略（不重置步骤）；锚点取的是组件自身矩形，"?" 按钮本身永远不在任何洞口内（洞口只框目标组件，不框整行）。
7. **键盘显隐（评审 N15）：** 引导开着时键盘状态变化（`keyboardHeightChange`）同样先关掉引导（记 seen）；引导盖住屏幕时用户本就无法点按输入框触发键盘，此条是兜底守卫。

## 5. seen-state 语义

1. **看完即记：** 自动弹出的引导，点"知道了"／"跳过"／点遮罩关闭，都记 `guide.<page>.seen=true`（现行 `closePageGuide` 已是此语义，保留）。
2. **手动看也记：** 经 "?" 打开的引导，同样在关闭时记 seen——看过就是看过，之后首次进页不再自动弹。
3. **不记的情况：** 引导因 §4.3 被抑制（浮层正开着）时不记 seen，不弹也不记；下次进页仍会弹。
4. **重置不变：** 设置页两行重播入口保留原语义（`resetPages` 清 14 页 seen，`resetOnboarding` 清启动引导）；`ONBOARDING_SEEN` 仍不被 `resetPages` 改动。`resetPages()` 补一行 hilog（`guide reset pages`，评审 N6）并把注释"清 11 页"改为"清 14 页"。**迁移：** 已有 seen 全部保留，不清、不重置——老用户不会因为本批重弹一遍。
5. **口径（评审 M15）：** "重播页面引导"是用户主动点的操作，保留全清语义；§1.2 所称"修掉的乱弹"指 §4 的三处（只推不返、连弹豁免、只认栈顶），不含重播。

## 6. 每页锚点配对表（14 页，文案键＋anchorId＋目标组件；本批核心交付物）

* **配对规则（评审 M3）：** 每步明确写出用哪一条文案键、锚哪个组件；步数＝锚点数（1–3 步），允许跳过中间某条文案，不许只截尾。`GuideCore.stepsExpected()` 由"固定 3"改为按本表取数；`allResourceKeys()` 按本表生成（步数减少的页，多余的文案键保留在 string.json，不删键）。
* **anchorId 规则：** 全仓全局唯一，`<page>__<name>` 前缀；只挂单例组件；列表项不得锚单项，锚列表容器（评审 N10）；同一 anchorId 可在同页多步复用（列表类页面），复用须在表中明示。
* **表注：** 目标组件描述即实现方挂 `.id()` 的位置；某步描述的组件在该页不存在（实现方读布局后核实）→ 该步按 §2.4 fallback＋批报告列入 miss 清单，不许自行换锚。

| 页 | 步 | 文案键 | anchorId | 目标组件 |
|---|---|---|---|---|
| home | 1 | guide_home_1 | home__hero | 主页中央纸叠／主视觉区 |
| home | 2 | guide_home_2 | home__start_btn | 主页金色"开始写作"按钮 |
| home | 3 | guide_home_3 | home__bottom_nav | 主页底部导航栏 |
| dossier | 1 | guide_dossier_1 | dossier__list | 卷宗列表区 |
| dossier | 2 | guide_dossier_2 | dossier__new_btn | 右上角"新建卷宗"按钮 |
| dossier | 3 | guide_dossier_3 | dossier__list | 卷宗列表区（与第 1 步复用；卡片为 ForEach 生成） |
| dossier_detail | 1 | guide_dossier_detail_1 | dossier_detail__list | 卷宗内纸张列表区 |
| dossier_detail | 2 | guide_dossier_detail_2 | dossier_detail__new_btn | 右上角"新建纸张"按钮 |
| dossier_detail | 3 | guide_dossier_detail_3 | dossier_detail__list | 卷宗内纸张列表区（与第 1 步复用；"⋯"菜单为行内项） |
| document_view | 1 | guide_document_view_1 | document_view__content | 文档纸面内容区 |
| document_view | 2 | guide_document_view_2 | document_view__edit_btn | 「编辑」按钮 |
| document_view | 3 | guide_document_view_3 | document_view__delete_btn | 删除按钮（行内操作区） |
| collection | 1 | guide_collection_1 | collection__grid | 机器卡片区 |
| collection | 2 | guide_collection_2 | collection__grid | 机器卡片区（与第 1 步复用；卡片为 ForEach 生成） |
| collection | 3 | guide_collection_3 | collection__grid | 机器卡片区（与第 1、2 步复用；"设置当前机器"动作在详情页，本步锚动作起点） |
| collection_detail | 1 | guide_collection_detail_1 | collection_detail__intro | 机器来历与细节区 |
| collection_detail | 2 | guide_collection_detail_2 | collection_detail__progress | 解锁进度区 |
| collection_detail | 3 | guide_collection_detail_3 | collection_detail__set_btn | 底部"设为当前机器"按钮 |
| customize | 1 | guide_customize_1 | customize__machine | 机器选择区 |
| customize | 2 | guide_customize_2 | customize__options | 换装选项区（纸张／色带／字体） |
| customize | 3 | guide_customize_3 | customize__manage_entry | 右上角字体／纸张管理入口 |
| settings | 1 | guide_settings_1 | settings__sound_row | 声音行 |
| settings | 2 | guide_settings_2 | settings__defaults | 默认机器／默认纸张行 |
| settings | 3 | guide_settings_3 | settings__replay | 底部"重播页面引导"行 |
| export | 1 | guide_export_1 | export__formats | 格式选择行（图片／PDF／纯文本） |
| export | 2 | guide_export_2 | export__actions | 保存／分享按钮区 |
| export | 3 | guide_export_3 | export__share_btn | 分享按钮 |
| pinyin_settings | 1 | guide_pinyin_settings_1 | pinyin__engine | 输入法引擎选择区 |
| pinyin_settings | 2 | guide_pinyin_settings_2 | pinyin__candidate | 候选栏数量／字号行 |
| pinyin_settings | 3 | guide_pinyin_settings_3 | pinyin__userwords | 「我的词库」入口 |
| typewriter | 1 | guide_typewriter_1 | typewriter__lever | 拨杆（本步文案含两个动作：敲键落字＋拉拨杆换行；洞口只框拨杆，敲键落字由纸面区与键盘区的视觉上下文覆盖） |
| typewriter | 2 | guide_typewriter_2 | typewriter__paper_change_btn | 底部功能行"换纸"按钮 |
| typewriter | 3 | guide_typewriter_3 | typewriter__paper | 纸面区 |
| font_manager | 1 | guide_font_manager_1 | font_manager__import_btn | 导入字体按钮 |
| font_manager | 2 | guide_font_manager_2 | font_manager__list | 已导入字体列表 |
| font_manager | 3 | guide_font_manager_3 | font_manager__list | 已导入字体列表（与第 2 步复用；删除为行内操作） |
| paper_custom | 1 | guide_paper_custom_1 | paper_custom__controls | 颜色／横线／边距调节区 |
| paper_custom | 2 | guide_paper_custom_2 | paper_custom__texture_import | 纸纹导入入口 |
| paper_custom | 3 | guide_paper_custom_3 | paper_custom__preset | 预设行 |
| trash | 1 | guide_trash_1 | trash__list | 回收站列表（恢复为行内操作） |
| trash | 2 | guide_trash_2 | trash__list | 回收站列表（与第 1 步复用；彻底删除为行内操作） |
| trash | 3 | guide_trash_3 | trash__hint | 页首常驻说明行（该行文案即 30 天规则） |

## 7. "?" 固定入口

1. **位置（三处，同一样式）：** PageShell 页眉右侧（`trailing` 之后，44×44，`SymbolGlyph $r('sys.symbol.questionmark.circle')`，色值随所在栏取色——PageShell 页 `#e8ddc9`，评审 N7）——覆盖 12 个 PageShell 页；TopBar 右侧（汉堡菜单左侧，同尺寸同图标，色值 `#dbccb3`，与 TopBar 自身图标一致）——打字机页；HomePage 顶区右端（与 PageShell 同款）——主页。**三处外观与尺寸一致，固定位置，不随页面内容变。**
2. **行为：** 点 "?" 立即显示本页引导（`Index.showPageGuide(page, { manual: true })`），不读 seen；步骤从第 1 步开始；关闭时记 seen（§5.2）。**重入守卫（评审 M11）：** 入口先判 `guideVisible`／`onboardingVisible`，已开则直接忽略。
3. **总开关与数据流（评审 N14）：** `guide.enabled=false` 时三处 "?" 都不渲染。Index 持 `@State guideEnabled`（启动时读 `GuideService.enabled()`），透传给 PageShell／TopBar／HomePage 作 `@Prop`；开关变化只在冷启动生效（无运行时翻转入口）。
4. **customHeader 页：** 全仓只有 `DossierDetailPage` 用 `customHeader: true`，把 "?" 放进其自定义页眉右端，同尺寸同图标，不许漏掉。

## 8. 渲染时序与量测细节（评审 B1 重写本节）

1. **入场过渡完成后再量：** 新页从右滑入约 250ms（`TransitionEffect.move(TransitionEdge.END).animation({ duration: 250, curve: Curve.EaseOut })`，`AGENTS.md` L94；各覆盖层共用同一过渡）。触发后**先等过渡结束再量**：冷启动首帧无过渡（`navAnimated=false`）→ 等一帧后量；其余 push → 等 250ms＋一帧（约 270ms）后量。**不许**只等一帧就量——一帧时页面只滑入约三分之一，`getRectangleById` 返回过渡中途的矩形，洞口会系统性错位（v1 稿的错误正在于此）。
2. **量后复核：** 量到后、挂载前立即复量一次；两次矩形任一边差 >1vp → 以第二次为准并记 hilog（`guide remeasure <page>/<n>`），不再复量（"仍不稳定"的操作定义：第二次与第一次任一边差 >1vp 时即取第二次为准，不做第三次量测）；第二次量不到矩形 → 走 §2.4 fallback（气泡居中）。
3. **切步时序（评审 N11）：** 点"下一步" → 先量下一步锚点（量到或 fallback）→ 再开 150ms 淡入淡出切洞口与气泡。
4. **屏幕旋转／折叠态切换／键盘显隐：** 引导若正开着，先关掉（记 seen）再由下次进页触发；不许在尺寸变化中途重算洞口（布局未稳，必错位）。
5. **量测单位：** `getRectangleById` 返回 px，`getUIContext().px2vp()` 每次现算（评审 N1）。

## 9. 验证（截图为准，hilog 为辅）

* **逐页验收（14 页）：** 每页两项——① 首次进页自动弹一次，截图上洞口框住文案讲的组件、气泡箭头指向洞口；② 点 "?" 立即重开，同样核对。截图号段另起（接 967 之后）。**洞口位置稳定性：** 每步连拍两张，洞口位置须一致（过渡完成后量测的证据，评审 B1）。
* **触发验收：** ① 返回不弹（评审 M8 重写用例）：先让引导因 §4.3 被抑制——成就弹窗开着时进一个未看过的页（seen 未记）；关弹窗后进下一页再返回，返回的页必须不弹（该用例测的是 depth 守卫，不是 seen；前置条件须按此构造，否则用例是假阳性）。② 启动引导后只连弹主页一次。③ 成就弹窗开着时进页不弹。④ 设置页重播后 14 页 seen 全清（`guide reset pages` hilog＋逐页复核抽查）。⑤ 回访冷启动（窄复核新 Major-1 的回归用例）：启动引导已看过、主页未看过时冷启动，主页引导须自动弹一次（前置：先清主页 seen、保留启动引导 seen）。
* **锚点验收：** 批报告附 §6 的锚点表执行结果（每页 anchorId＋截图号）；量不到的步列入 miss 清单（§2.4），不许瞒报为 PASS；anchorId 全仓唯一性由 `guide-keys` 单测断言。
* **位置换算单测（评审 M16，必做）：** 气泡位置换算抽成纯函数（`model/SpotlightLayout.ets`，输入目标矩形＋屏尺寸＋折痕带＋键盘区，输出气泡矩形＋箭头位置），Node 单测覆盖边界用例（上下判定、clamp、desk 禁区、箭头独立位置、两侧都放不下）。
* **门图：** 本批不改打字机页几何，门图 vs 917 重跑一次（预期 0.00%）。前置：回归模式或 seed seen 全 true（引导须关闭，评审 N9）。TopBar 加 "?" 不在门图四区内（顶部不在键盘 y 0.62–0.98 与车架 y 0.40–0.62 内），不走基线仪式；另抽一张 PageShell 页截图核对页眉布局（"?" 不与 trailing 胶囊／标题重叠）。
* **单测：** `GuideCore` 声明表（每页步数按 §6 表）、`guide-keys` 按新声明表断言＋anchorId 全仓唯一性、`SpotlightLayout` 位置换算、`check-contracts.py` 更新（`SpotlightOverlay` 新契约＋`GuideOverlay`／`GuideStep` 契约更新，评审 N12）；全套 Node 单测全绿。
* **E3 开关验证路径（评审 M12）：** 测试构建以 `GuideService.setEnabled(false)`（测试入口临时调用，验后恢复）置 false，真机截图核对三处 "?" 消失且进页不弹；若测试入口不可行，退为代码级证据（Index `@State guideEnabled` 透传＋单测断言 enabled=false 时不渲染）＋批报告写明。
* **证据缺口处理（按给桌面端的提示词铁律）：** 某步锚点截图抓不到时，用 hilog 矩形值＋相邻步截图作替代证据继续做，批报告写明缺了什么、为什么缺、替代证据是什么；只有编译不过、设备离线、包装不上才报阻塞。

## 10. 出口表

* E1：14 页逐项有结论——自动弹一次（首次进页）＋"?" 手动重开＋洞口框对组件（截图＋hilog 矩形值＋连拍洞口位置一致），每步缺了写明原因，不得把"未做"写成 PASS；miss 清单如实列出。
* E2：触发四项全过——返回不弹（按 §9 的抑制构造用例）、启动引导后只连弹一次、浮层开着不弹、重播清 seen；`currentGuidePage` 只认栈顶（代码级＋行为级证据）。
* E3：Node 单测全绿（新增／改动的 guide 相关测试计入总数）；门图四区 0.00% 维持；`guide.enabled` 关时 "?" 隐藏且不自动弹（按 §9 路径验证）。
* E4：文档交付——批报告＋§6 锚点表执行结果＋逐页截图（号段接 967 之后）。

## 11. 不动项

* 不改核心几何（字车／纸／滚筒／拨杆／键盘公式一律不动）；不改 1920s 冻结基线与 917；不改 `guide.enabled` 默认 on；不改 seen 键名（`guide.<page>.seen`）与 `ONBOARDING_SEEN` 语义；不改回归模式／测试模式语义；不改启动引导流程与文案（`GuideStep` 只留 `text`）；不改 PageShell 常驻说明行（subtitle）；不改各页 `guide_<page>_<n>` 文案本身（只复用）；不删 string.json 里任何 guide 键（`guide_home_hint` 的删除属第 10 批小活收尾稿 D5，不在本稿）。

## 12. 实施文件清单

| 文件 | 改动 |
|---|---|
| `entry/src/main/ets/components/SpotlightOverlay.ets`（新建） | 聚光灯渲染器：四块遮罩＋描边框＋透明捕捉层＋气泡＋箭头＋`Circle()` 步骤点＋上一步／下一步／跳过／知道了 |
| `entry/src/main/ets/model/SpotlightLayout.ets`（新建，评审 M16） | 气泡位置换算纯函数（上下判定、clamp、desk 禁区、键盘禁区、箭头位置） |
| `entry/src/main/ets/components/GuideOverlay.ets`（改） | 只供启动引导用；删 `GuideAnchor`、`GuideStep.anchor`、`@Prop anchor`、`anchorText()` |
| `entry/src/main/ets/model/GuideCore.ets`（改） | `stepsExpected()` 按 §6 表取数；`allResourceKeys()` 按新表＋新增 `guide_btn_prev`／`guide_btn_next` |
| `entry/src/main/ets/services/GuideService.ets`（小改） | `resetPages()` 注释 11→14＋补 `guide reset pages` hilog |
| `entry/src/main/ets/pages/Index.ets`（改） | 单挂载点改挂 SpotlightOverlay（页面引导）；`syncFromStack` 栈深守卫（普通 private 字段，`aboutToAppear` 初始化）＋冷启动例外（启动引导已看过且主页未看过时跑一次）；`maybeShowPageGuide()`（无 force 参数）；`showPageGuide(page, {manual})`（重入守卫）；`currentGuidePage()` 只认栈顶；`closeOnboarding` 链路直接调 `maybeShowPageGuide()`；`guideStepsOf` 返回 `SpotlightStep[]`；`@State guideEnabled` 透传；成就弹窗打断规则（先关引导记 seen 再弹） |
| `entry/src/main/ets/components/PageShell.ets`（改） | 页眉右侧固定 "?"（44×44，SymbolGlyph，`#e8ddc9`），`onShowGuide` 回调 |
| `entry/src/main/ets/components/TopBar.ets`（改） | 汉堡左侧固定 "?"（`#dbccb3`），`onShowGuide` 回调 |
| `entry/src/main/ets/components/HomePage.ets`（改） | 顶区右端固定 "?"，`onShowGuide` 回调 |
| 12 个 PageShell 调用点（改） | `CollectionDetailPage`／`CollectionPage`／`CustomizePage`／`DocumentViewPage`／`DossierDetailPage`／`DossierPage`／`ExportPage`／`FontManagerPage`／`PaperCustomPage`／`PinyinSettingsPage`／`SettingsPage`／`TrashPage`：透传 `onShowGuide` |
| `entry/src/main/ets/components/DossierDetailPage.ets`（改） | 自定义页眉右端补 "?"（全仓唯一 customHeader 页） |
| 各页 `guideStepsFor<Page>()`（14 处，改） | 返回 `SpotlightStep[]`，每条加 `anchorId`（按 §6 表）；目标组件挂 `.id(anchorId)` |
| `entry/src/main/resources/base/element/string.json`（改） | 新增 `guide_btn_prev`／`guide_btn_next` |
| `tools/tests/guide-core.test.mjs`、`guide-keys.test.mjs`（改） | 按新声明表断言；新增 anchorId 全仓唯一性断言 |
| `tools/tests/spotlight-layout.test.mjs`（新建，评审 M16） | 位置换算边界用例 |
| `tools/check-contracts.py`（改） | `SpotlightOverlay` 新契约＋`GuideOverlay`／`GuideStep` 契约更新 |
| `docs/designs/功能新增与体验优化总纲.md`（改） | F1 节同步为聚光灯形态（或注明由本文档取代旧形态描述） |
| `docs/designs/第0-7批索引.md`、`docs/evidence/回归矩阵-第7批.md`、`docs/自检记录.md`（改） | 第 10 批条目＋批报告 |

## 13. 变更表

| 版本 | 日期 | 改动 |
|---|---|---|
| v1 | 2026-11-11 | 初稿：用户反馈（引导非组件式、乱弹、无固定入口）→ 聚光灯重设计；触发策略用户已定"首次进页自动弹一次"；锚定量测复用 `DossierDetailPage` 已验证模式 |
| v2 | 2026-11-11 | Goldfish 评审 resolve（1 Blocker／16 Major／18 Nit 全数落笔，见 §14）：§8.1 重写（过渡完成后再量＋复核）、类型拆分（`SpotlightStep`）、anchorId 全仓唯一、§6 补 42 行配对表、触发守卫落点写死、AppDialog 检测收窄为 Index 已知两项、洞口捕捉层、气泡位置算法、位置换算纯函数必做、重播口径订正、文件清单补齐 |
| v2.1 | 2026-11-11 | 窄复核后修新 Major-1＋7 项新 Nit（见 §14 末）：§4.1 补冷启动例外（回访用户主页引导）、删 `force` 参数、§8.2"仍不稳定"操作定义、§3.2 气泡超高分支＋键盘区矩形来源、§2.1 措辞、§6 两处表注、§9 补回访冷启动用例 |

## 14. 评审 resolve 记录（v1 → v2）

| 编号 | 结论 | 落笔位置 |
|---|---|---|
| B1 | 接受。v1"等一帧再量"量到过渡中途矩形，系统性错位 | §8.1 重写：250ms＋一帧后再量＋挂载前复量 |
| M1 | 接受。`anchorId` 必填与共享 `GuideStep` 冲突 | §2.1 类型拆分（`SpotlightStep`）；§11 更新 |
| M2 | 接受。`getRectangleById` 窗口全局查找，跨页不可重名 | §2.2 anchorId 全仓唯一＋页前缀；§6 表；§9 单测断言 |
| M3 | 接受。截尾会文案-锚点错配 | §6 改为逐页配对表（42 行），允许跳过中间文案 |
| M4 | 接受。depth 守卫落点歧义会断掉首启主页引导 | §4.1 守卫只在 `syncFromStack` 调用点；§4.2 链路 `force=true` |
| M5 | 接受，取收窄方案。Index 无法感知各页局部 AppDialog | §4.3 只守启动引导＋成就弹窗；其余列为已知缺口＋理由 |
| M6 | 接受。洞内透明捕捉层与"不盖任何东西"矛盾 | §3.1 改写：洞内不盖不透明东西＋透明捕捉层 |
| M7 | 接受。气泡位置规则缺尺寸／溢出／禁区／箭头 | §3.2 补完整算法；§9 纯函数必做 |
| M8 | 接受。原用例测的是 seen 不是 depth 守卫 | §9 触发验收①改写为抑制构造用例 |
| M9 | 接受。文件清单缺四类 | §12 补齐：string.json 新键、12 个调用点、customHeader 单页、位置函数测试、总纲 F1 |
| M10 | 接受。●○○ 与图标铁律冲突 | §3.4 改 `Circle()` 绘制圆点 |
| M11 | 接受。手动入口缺重入守卫 | §4.6／§7.2 入口先判 `guideVisible`／`onboardingVisible` |
| M12 | 接受。E3 开关验证无可执行路径 | §9 补 `GuideService.setEnabled(false)` 测试入口路径＋代码级退路 |
| M13 | 接受。锚点表推迟到实现方等于外包设计主体 | §6 补 42 行配对表进设计稿 |
| M14 | 接受。挂载顺序与成就弹窗打断未定 | §4.5 写死顺序（引导在 AppDialog 之前）＋打断规则（先关引导记 seen 再弹成就弹窗） |
| M15 | 接受，取口径订正方案。重播是用户主动操作 | §0／§1.2／§5.5 统一：修掉三处乱弹，重播保留原语义 |
| M16 | 接受。位置换算纯函数不应是可选的 | §9 改为必做（`SpotlightLayout`＋单测）；§12 补测试文件 |
| N1–N18 | 全部接受（N13 经核实：settings＋export 栈上不可达，改为"潜在误判源"；其余照评审建议落笔） | 分散见 §2–§9、§12 |

**窄复核新发现（v2 → v2.1，报告 `~/workspace/egm-work/guide-redesign-rereview.md`）：** B1、M1–M16、N1–N18 全部 PASS；但新发现 1 个 Major＋7 个 Nit，暂缓报批，v2.1 修后由父 agent 窄确认、无需再派完整 re-review。

| 编号 | 结论 | 落笔位置 |
|---|---|---|
| 新 Major-1 | 接受。回访用户冷启动主页引导无自动弹路径（主页是栈底永不被 push；depth 字段初始化后首个 syncFromStack 看不到增长；唯一豁免是启动引导链路，回访用户不跑） | §4.1 补冷启动例外；§9 补回访冷启动用例⑤ |
| 新 Nit-1 | 接受。`force` 参数与 §4.1 自相矛盾（守卫不在 maybeShowPageGuide 内，参数空转） | §4.1／§4.2 删 `force` 参数，链路直接调 maybeShowPageGuide() |
| 新 Nit-2 | 接受。"第二次仍不稳定"无操作定义 | §8.2 写死：取第二次为准，不做第三次量测；第二次量不到走 fallback |
| 新 Nit-3 | 已注。collection_3 文案讲详情页动作、锚点在收藏页 | §6 该行已有表注（"设置动作在详情页，本步锚动作起点"），无需再改 |
| 新 Nit-4 | 接受，补注。typewriter_1 一步讲键盘＋拨杆两个动作、洞口只框拨杆 | §6 该行补表注 |
| 新 Nit-5 | 接受。两侧都放不下且气泡高于较大一侧空余区时未定义 | §3.2 补分支（居中＋hilog） |
| 新 Nit-6 | 接受。键盘区矩形来源未写 | §3.2 补定义（当前布局值：keybedHeightVp＋FUNCTION_ROW_HEIGHT_VP＋候选栏高） |
| 新 Nit-7 | 接受。§2.1"GuideStep 保持原样"与同段删除清单措辞打架 | §2.1 改写（text 字段与结构保持原样，删的是 anchor 相关成员） |

**窄复核未核实项的闭合（父 agent 核实）：** ① "全仓只有 DossierDetailPage 用 customHeader: true"——已 grep 确认（`DossierDetailPage.ets:716` 唯一命中）；② 测试构建调用 `GuideService.setEnabled(false)` 的具体入口——测试入口细节由桌面端定，M12 的验证路径（测试入口临时调用＋代码级退路）不依赖此项。
