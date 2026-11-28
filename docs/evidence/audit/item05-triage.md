# 核查⑤-2：性能与质量分流与裁决（只读）

- 日期：2026-11-28
- 分支：`audit05-triage`（base `main` @ `564a87c`，⑤-1 清单已合 main）
- 工作树：`D:\HarmonyAPP\carriagereturn\.worktrees\audit05-triage`
- 输入：`docs/evidence/audit/item05-inventory.md` 的 Q-1～Q-4、P-6、P-7
- 只读声明：未改代码、未重拍截图、未操作设备数据。截图一律引用 ⑤-1 已有编号；代码核对基于本树 `564a87c`；未做新的真机量测。

## 0. 结论摘要

- **Q-1～Q-4 四项观察全部核实成立，无事实性误判（撤 0 项）**。其中 Q-1 需修正一处口径：平板裁切本身符合设计稿 §5.3，但 `maxLines(20)` 比「页底」更早截断，且设计稿给的「翻页走加页」并未实现为翻页（加页只是追加空行），长文不可读仍是真实问题。
- **裁决：修 3 项＋1 项优化批**——Q-2（分隔行泄漏，W1）、Q-1（平板阅读全文，W2，D-1=A 已实施）、Q-3（拨杆死代码清理，W3）、Q-4 体积部分（W4）；Q-4 内存部分记（先量后定）。
- **P-6 soak：留（做）**，降级为独立验证项 S1（双机 30 分钟起步，异常再延到 60 分钟），不并入修复批。
- **P-7 体积优化：做（保留该优化项）**，但第一阶段不是压字体，而是清理零引用资源：静态扫描 rawfile 230.3MiB 中约 **102.5MiB 零引用**（ui-parts 93.8、typebar 8.0、machine 0.7），HAP 250.5MB 可望降到约 143MB（−43%）；字体子集化/纹理压缩/词表压缩留档，需单独裁决。
- **附带发现（与 Q-3 同源）**：`tools/tests/lever-angle.test.mjs` 在 main 上有 **2 项失败**——一项引用批39 已删除的 `LeverLayer.ets`，一项四机断言未纳入第五台 2020s。清理批应一并处理。

## 1. 核对：四项观察是否成立

| 编号 | ⑤-1 原描述 | 本批核对 | 结论 |
|---|---|---|---|
| Q-1 | 平板文档视图正文 `maxLines(20)`＋`Clip`，不可滚动 | 属实。`DocumentViewPage.ets:126-151` `paperBodyTablet`：`Text(...).maxLines(20).textOverflow({overflow: Clip})`，外层 `Stack.clip(true)`，无 `Scroll`；手机分支 `DocumentViewPage.ets:185-196` 已是 `Scroll`＋`layoutWeight(1)`。设计稿 `docs/界面重设计稿.md:491` 确写「超出页底裁掉不许滚动出页；翻页走底栏“加页”」，但「加页」实际只往文档末尾追加空行（`item05-docview-trash.md` A79/O4），不是翻页。 | 成立（需修正“纯缺陷”口径：平板符合设计稿裁切口径，但与手机不一致且长文不可读） |
| Q-2 | 手机正文内直接显示 `--- 第 1 / 2 纸 ---` 分纸标记 | 属实，根因已定位：`DocStore.plainTextOf`（`DocStore.ets:374-389`）在写 `.txt` 孪生时对每张归档纸后插入 `sheetSeparatorText`（`ExportCore.ets:57-60`）；`DocumentViewPage.load()`（`DocumentViewPage.ets:57-59`）直接 `docStore.readPlainText()` 再按 `\n` 拆行，于是把导出/存储格式当正文显示。截图 3965/3966 可见该行。 | 成立 |
| Q-3 | 拨杆拖拽链路 `leverPanStart/Update/End` 在 type26 主屏无调用点 | 属实。全仓 grep 仅 `Index.ets:2900/2909/2918` 三处定义，零调用；`canvasEnabled` 为 `private readonly = false`（`Index.ets:975`），canvas 分支恒死；`leverAngleVp`（`:256`）只在 `tickFrame` 写（`:3752`）从不读，`leverEpoch`/`leverRatio1920..1960`/`canvasLeverReleaseTick/Commit` 同样写而不读。根因：批39 已按用户定夺删除拨杆、旋钮、滚筒与「拖拽回车」入口（`docs/designs/26-增补-5-批39.md:13-30`），Index 这段是退役残留。 | 成立（性质是死代码，不是功能缺失） |
| Q-4 | HAP 250.5MB、冷启 PSS 249–277MB、ArkTS 堆 81–83MB | 数字沿用 ⑤-1（debug signed HAP 250,549,898B；平板 PSS 277,295kB、手机 249,264kB；ArkTS 堆 83,074/81,694kB）。本批补做体积构成静态核对：rawfile 合计 230.3MiB，其中字体 73.1、ui-parts 125.6、typebar 10.7、词表 7.5、machine 5.2、layers 4.8、其余约 3.4MiB；`ui-parts`＋`typebar`＋`machine` 中静态零引用约 102.5MiB。内存侧 `ensurePinyinEngine()` 在 `aboutToAppear` 后 380ms 无条件预加载（`Index.ets:1386-1393`、`:591-643`），与 ArkTS 堆量级一致。 | 成立（体积有明确可清理项；内存属设计取舍） |

### 1.1 附带发现

1. **拨杆退役残留导致单测红**：`node --experimental-strip-types --test tools/tests/lever-angle.test.mjs` → 7 pass / 2 fail。失败 1：`lever-angle.test.mjs:74-89` 仍要求 `components/LeverLayer.ets` 等四份渲染件存在并 import `LeverAngleCore`，这些文件批39 已删；失败 2：`:91-99` 的 `leverAspect/pivot` 断言仍是四机，实际 `MachineCatalog` 已有第五台 2020s（`leverAspect` 实际 `[0.2125,0.3264,0.09,0.12,0.2125]`）。与 Q-3 同源，清理批一并处理。
2. **文档视图标题取行口径**：`DocumentViewPage.load()` 用整篇 `.txt` 的 `arr[0]` 当标题；多纸文档的 `.txt` 先拼归档纸，故标题可能取到归档纸首行，而列表标题走 `DocSummary.title`（当前纸首行）。Q-2 改读结构化数据时一并改为 `DocSummary.title`。
3. **预加载注释与代码不一致**：`Index.ets:1386` 注释写「延迟 3s」，实际 `setTimeout(..., 380)`；不影响功能，P-7 内存优化时顺带校正。

## 2. 逐项裁决

| 编号 | 严重度 | 裁决 | 批次 | 理由 | 修复方向 |
|---|---|---|---|---|---|
| Q-1 | 低 | **修** | W2（已实施） | `maxLines(20)` 是固定行数上限，不是「页底」裁切：正文区尚有余量时就会截断；当前正文源是整篇（归档纸＋当前纸），20 行封顶会静默藏掉后续纸；手机已 `Scroll`，双端行为不一致；设计稿的「加页翻页」并不存在。 | 首选按手机 F1 方案：平板正文改 `Scroll`＋纸纹 `backgroundImage`，去掉 `maxLines(20)`；或按纸分页＋页码（D-1）。同步更新设计稿 §5.3。 |
| Q-2 | 低 | **修** | W1 | 分隔行是 `.txt` 孪生/导出的存储格式，不是阅读内容；阅读视图直接读同一 `.txt` 造成泄漏，3965/3966 可见。 | `DocumentViewPage` 改读 `DocStore.load()`（`DocStore.ets:104-122`），展平 `sheets`＋`lines` 并跳过分隔行；标题用 `DocSummary.title`；`readPlainText` 保留给导出/搜索。 |
| Q-3 | 低（维护性） | **修（清理）** | W3（最低优先） | 观察成立且清理收益明确：约 100 行死代码、8 个写而不读的 `@State`（`leverRatio×4`、`leverEpoch`、`canvasLeverReleaseTick/Commit`、`leverAngleVp`）、2 条红测；无用户可见影响，故不排功能批。若 Kit 认为本轮不动主屏，可降为「记」。 | 删 `leverPanStart/Update/End`、`leverDragActive`、`leverRatioLogical`、`leverRatio1920..1960`、`leverRatio()`/`setLeverRatio()`、`resetLeverStates()` 中拨杆段、`leverHForDrag()`、`leverAngleVp`、`leverEpoch`、`canvasLeverReleaseTick/Commit` 及未用 import；`canvasEnabled` 历史分支按注释保留，不在本批扩大清理。同步修/删 `lever-angle.test.mjs` 两条失效断言。 |
| Q-4 | 低 | **修（体积，W4）＋记（内存）** | W4 | 体积不是缺陷，但静态扫描发现约 102.5MiB 运行时零引用资源，清理风险低、收益可量化；内存 249–277MB 主要来自启动即预加载词表（ArkTS 堆 81–83MB），属 §17.3 设计取舍，先量后定。 | 体积：W4 先删/移出零引用资源并重测 HAP；内存：先做「system 引擎不预加载 / 延迟预加载」的 PSS 对比，再决定是否改预加载策略。 |

**为什么 Q-3 不判「撤」**：撤要求观察不成立或无需处理。Q-3 的「无调用点」事实成立；死代码虽无运行时影响，但已实际导致单测红与审计误读（本次即由它引出），清理有维护收益，故按清理批处理，而不是撤回。

## 3. 后续修复批清单

### W1 文档视图去分隔行（Q-2，可立即做）— **已实施（2026-11-28）**

- 文件：`entry/src/main/ets/components/DocumentViewPage.ets`（主改）；如需 helper，`entry/src/main/ets/services/DocStore.ets` 增加只读的「显示行」接口（或页面内直接用已有 `load()`）。
- 做法：`load()` 不再 `readPlainText()`；用 `docStore.load(this.docId)` 取 `DocData`，按 `data.sheets`（归档纸，顺序）＋`data.lines`（当前纸）展平为显示行。结构化数据本身不含分隔行；若实现上仍走文本接口，才需按 `sheetSeparatorText` 同格式精确匹配过滤（不要用宽泛正则误伤用户正文）。标题取 `DocSummary.title`，找不到摘要再回落首行。
- 预估：±25 行。
- 验真：双机打开同一份 2 纸文档的文档视图——正文无 `--- 第 n / N 纸 ---`；归档纸＋当前纸文字齐全且顺序正确；标题与列表一致；点正文仍进打字机（A78/F1 回归）；导出 TXT 仍含分隔行（读设备落盘文件核对）。
- 风险：低。`readPlainText` 不动，导出/搜索口径不变。

**实施记录（2026-11-28，分支 `fix/w1-docview-separator`，base `a92b02b`）**

- 代码：`DocumentViewPage.ets` `load()` 改 `docStore.load(docId)` 取 `DocData`；新增 `displayLinesOf()` 按 `sheets`（归档纸，顺序）＋`lines`（当前纸）展平，不插分隔行；标题取 `DocSummary.title`，摘要缺失回落首行。`readPlainText`／`plainTextOf`／`sheetSeparatorText` 未改，导出与搜索口径不变。+30/−5 行；未新增 `DocStore` 接口。
- 构建：DevEco 26 hvigorw `assembleHap`（debug signed）**BUILD SUCCESSFUL in 23 s 201 ms**，43 tasks，0 ERROR；WARN 均为既有（AudioService 能力、2in1 API、`document_view__body` 重复 id）。HAP 250,557,085 B；双机 `install -r` 成功。
- 验真（双机各建同一份 2 纸文档：归档纸 `aaa`＋当前纸 `bbb`；平板 `doc-1795856442723-73990`、手机 `doc-1795856550822-78825`，`sheetNo/sheetCount=2`）：① 文档视图 `document_view__body` dump 原文 `aaa\nbbb`，无分隔行；② 归档纸在前、当前纸在后；③ 列表与文档视图标题均为 `bbb`（旧实现取 `.txt` 首行会显示 `aaa`）；④ 点正文 `nav depth=4 top=docview → depth=5 top=typewriter`，纸面 `bbb`；⑤ 真实导出 TXT（整篇→纯文本→保存到 Download）双机均 30 B，内容 `aaa`／`--- 第 1 / 2 纸 ---`／`bbb`，落盘文件回收为 `docs/evidence/audit/w1_export_{tablet,phone}_bbb.txt`；⑥ 单纸旧文档（`q`）回归正常。
- 证据：截图 3973–3979；报告 `docs/evidence/audit/fix-W1-docview-separator.md`。单测 `export-multipage`＋`docstore-state`＋`docstore-trash` 17 pass / 0 fail。
- 缺口：平板 >20 行阅读属 W2，本批未动；未注入损坏 JSON 验证 `load()===null` 分支；测试文档与导出 TXT 留在设备便于复核。

### W2 平板阅读全文（Q-1，D-1=A）— **已实施（2026-11-28）**

- 文件：`entry/src/main/ets/components/DocumentViewPage.ets`（`paperBodyTablet` 与 `body()` 平板分支）；若选分页方案另加页码状态。
- 做法（推荐 A）：照手机 `paperBodyPhone` 的 F1 实现，正文纸改 `backgroundImage` 纸纹＋`Scroll` 包裹，去掉 `maxLines(20)`；标题页仍固定左列，正文列独立滚动。保留点正文进打字机。
- 预估：±30 行（A）；分页方案 ±120 行以上（B）。
- 验真：平板造 >20 行、≥2 纸文档，文档视图能滚到最后一纸最后一行；顶部/底部各一张截图；点正文仍进打字机；手机回归一张。
- 风险：中低。设计稿 §5.3 明写「不许滚动出页」，选 A 必须同步改设计稿（D-1），否则实现与设计稿冲突。

**实施记录（2026-11-28，分支 `fix/w2-tablet-docview-scroll`，base `9cf4220`）**

- 代码：`paperBodyTablet()` 删掉 `height('100%')` 的纸纹 `Image` 与 `maxLines(20)＋Clip`，改 `backgroundImage` 纸纹＋正文按内容撑高，`constraintSize({ minHeight: '100%' })` 保短内容满高（与手机 F1 同法）；`body()` 平板分支正文列外包 `Scroll`（宽 `(widthVp−56)/2`、高 100%、`scrollBar Off`、`edgeEffect None`、`align TopStart`），标题页仍固定左列；点正文 `onEdit` 保留。手机分支未动。+18/−9 行。
- 设计稿：`docs/界面重设计稿.md` §5.3 已同步（可滚动读全文，原「裁掉不许滚动出页」作废）。
- 构建：DevEco 26 hvigorw `assembleHap`（debug signed）**BUILD SUCCESSFUL in 26 s 510 ms**，43 tasks，0 ERROR；HAP 250,557,001 B；双机 `install -r` 成功。
- 验真（平板 `doc-1795858049601-56401`，App UI 创建：3 张归档纸 14/17/17 行＋当前纸 3 行＝**51 显示行、4 纸**，末行 `end`）：① `document_view__body` 内容高 2983px > 视口 2077px（超出 906px），可滚；② 顶部 3980、滚到底 3981 显示末纸末行 `end`，标题页位置不变（正文列独立滚动）；③ 已滚动态点正文仍进打字机（dump 出现 `p26_lid`/`p35_paper`/`p25_key_grid`，纸面显示末纸 `x/x/end`，截图 3982）；④ 短文档（aaa/bbb）正文纸满视口（3984），`minHeight 100%` 生效；⑤ 手机回归 3983 vs W1 基线 3975 像素差 mean 1.18、>30 差 186/3,250,944 px（布局一致，手机分支未改）。
- 证据：截图 3980–3984；报告 `docs/evidence/audit/fix-W2-tablet-docview-scroll.md`；取证摘录 `docs/evidence/audit/w2_tablet_docview_verify.txt`。
- 缺口：未录屏滚动惯性（`edgeEffect None` 无回弹）；纸纹由 `Image(Cover)` 改 `backgroundImage(FILL)`，短文档纹理观感与旧实现略有差异（3973 vs 3984），版式/文字位置不变；手机未造长文复测（分支未改）。

### W3 拨杆死代码清理（Q-3，最低优先）

- 文件：`entry/src/main/ets/pages/Index.ets`；`tools/tests/lever-angle.test.mjs`。
- 做法：按 §2 表列清单删除；保留 `newlineTick1920..1960`/`newlineTick()`/`bumpNewlineTick()`（换行代际守卫仍在用，`Index.ets:4351/4392/4445`）与 `slotOf`；`canvasEnabled` 只读常量及其历史分支按原注释保留。`LeverAngleCore.ets`/`LeverStateCore.ets` 模型文件可保留（纯函数、体量小），只清理 Index 消费端与失效测试。
- 预估：Index −90～−110 行；测试 −30/＋10 行。
- 验真：全仓 grep `leverPan|leverDragActive|leverRatioLogical|leverAngleVp|leverEpoch|canvasLeverRelease` 零命中；构建通过；`node --test tools/tests/*.mjs` 无新增红（`lever-angle` 两项转绿或按五机更新）；双机 smoke：打字、RETURN 换行、↻ 换纸、切机、返回，截图与清理前一致（该批不应有任何像素变化）。
- 风险：低。删的都是零调用代码；唯一注意是按上面清单保留 `newlineTick` 链。

### W4 HAP 零引用资源清理（Q-4 体积 / P-7，第一阶段）

- 范围：`entry/src/main/resources/rawfile/`。静态扫描结果（本树 `564a87c`）：

| 目录 | 总量 | 静态零引用 | 典型零引用项 |
|---|---:|---:|---|
| `ui-parts/` | 125.6MiB | **93.8MiB（72 文件）** | `paper-cream-v1..v4`（各 2.6–3.9MiB）、`basket-fan-3d-v3/v4` 与 `basket-fan-3d-v5-wide-*` 各代、`basket-fan-metal-*`、`tile-*-base-v2`、`paper-*.png` 旧版、`knob-*`/`platen-roller-v1`/`bell-brass-v1`/`plate-brass-blank-v1`/`carriage-lever*` 等批39 作废件 |
| `typebar/` | 10.7MiB | **8.0MiB（9 文件）** | 四机 `*-carriage-layer.png`、`*-lever-single.png`、`1920s-typebar-single.png`（在用的只有四张 `*-typebar-vertical.png`） |
| `machine/` | 5.2MiB | **0.7MiB（2 文件）** | `2020s-modern-hero.jpg`、`2020s-modern-keyarea.jpg` |
| 合计 | 230.3MiB | **约 102.5MiB** | HAP 250.5MB → 约 143MB（−43%，按 PNG 已压缩、近似 1:1 估算） |

- 方法：遍历 rawfile 每个文件，检查 basename/相对路径是否在 `entry/src/main/ets/**/*.ets|ts` 与 `entry/src/main/resources/base/**/*.json` 中出现；并显式计入两类动态拼串：`machine/<kind>-{front,side,keyboard,carriage}.jpg`（5 机）与 `ui-parts/tile-<slug>-<tier>.png`（4 slug×3 tier）。**未执行删除**，以上为静态估算。
- 做法：① 先补一次全量引用复核（含 `tools/check-part-colors.py`、`entry/src/main/resources/rawfile/ASSET-MANIFEST.md` 等契约/文档引用）；仅被工具或文档引用的样张移出 HAP（如放 `tools/contract-assets/`），不改契约语义；② 确认无引用后删除；③ 更新 `ASSET-MANIFEST.md`；④ 重构建 debug signed HAP 记录前后字节；⑤ 双机装包，按 14 页清单逐页截图（重点：五机机身、四种纸纹＋自定义纸纹、字体列表、音效、键位、导出、文档视图）。
- 预估：纯资源删除，代码 0～±10 行（manifest/工具路径）。
- 风险：中低。主要风险是漏掉动态拼串或契约样张；用「先复核、后删除、整页截图回归」控制。删除前留 `backup/` 分支或单独提交，便于回滚。
- **实施结果（2026-11-28，W4 完成，分支 `fix/w4-rawfile-cleanup`）**：
  - 出包 90 文件 / 108.02MiB：**删除**运行时零引用 52 文件 / 70.82MiB；**移出 HAP** 契约样张 38 文件 / 37.20MiB 至 `tools/contract-assets/`（不删、不改像素；`check-part-colors.py` 改「rawfile → contract-assets」双路径查找，`check-part-grain.py` 两处取并集，契约语义不变）。
  - 与静态估算的差异：ui-parts 实测零运行时引用 78 件（估算 72 件）。多出的 6 件是原扫描把 `PartContract.ets` 取样字段／`PartVariants` 件 id 字符串误当运行时引用——`paper-letter`／`keycap-face-1920s`／`basket-fan-1920s`／`lever`／`ruler`（契约样张，移出）与 `ribbon-strip`（件 id 字符串，删除）；均已逐项复核，确认不参与渲染。typebar 9 件、machine 2 件按原判删除；字体协议原文按 OFL 要求保留。
  - 实测体积：rawfile 297 文件 / 230.28MiB → **207 文件 / 122.25MiB**；debug signed HAP **250,557,000 B → 137,273,392 B（−45.2%）**，优于预估约 143MB。
  - 验真：双机装包，14 页逐页截图（平板 3985–3998、手机 4004–4017；重点项另附平板 3999–4003b、手机 4018–4020b），覆盖五机机身（收藏页／收藏详情／2020s 打字机）、四种纸纹（主题页纸卡）、自定义纸纹页、字体列表、键位落字与退格、拼音词库加载（409 音节／251,364 词条）、导出、文档视图。契约工具：`check-part-grain.py` 40 件 PASS；`check-part-colors.py` 4 件金属件 FAIL 为清理前既有偏差（`docs/自检记录.md` 4202／4225 行已记录），非本次引入。
  - 回滚：`backup/w4-pre-cleanup`（指向清理前 HEAD `6977994`）。

### W5（可选，留档，不在本轮）

- 纹理压缩（PNG→WebP/降采样）、字体子集化、词表压缩。三者都能再降体积，但分别涉及：纸纹像素变化需按 AGENTS §5 重拍/重批基线；CJK 字体子集化会牺牲生僻字覆盖（与「可打任意汉字」冲突）；词表压缩增加启动解压成本（§17.3 卡死史）。建议 W4 落地并量到 release 包后再单独立项，不在本修复批内做。

## 4. P-6 soak 与 P-7 体积优化的去留意见

### 4.1 P-6 30–60 分钟 soak：**留（做）**，独立验证项 S1

- 理由：⑤-1 压力序列仅 1–2 分钟，ArkTS 堆 +7.6MB（平板）/+10.1MB（手机）但 Total PSS 反降，无法区分「缓存回收」与「缓慢泄漏」；App 有帧时钟、自动保存、拼音学习落盘、音频预加载等长生命周期服务，值得一次 30 分钟观察。成本可控（双机各 30 分钟，采样可脚本化）。
- 口径建议：双机、屏幕常亮；冷启后先静置 5 分钟 warmup；此后每 5 分钟采 `hidumper --mem <pid>`（Total PSS/ArkTS/Native/Graph）与 `hidumper -s RenderService -a 'hitchs carriagereturn0'`；每 5 分钟插一轮活动（页面往返 20 次＋打字 100 字＋换纸 1 次＋换机 1 次），其余静置；记录进程号。
- 通过标准：① 无崩溃/卡死/ANR；② warmup 后 ArkTS 堆无单调上升（末次 ≤ 第 2 次采样 +10MB，且斜率 <2MB/10min）；③ Total PSS 无持续上升；④ hitchs 仍 0/0/0；⑤ 结束后冷启动耗时在 ⑤-1 基线 ±20% 内。
- 升级条件：30 分钟末段仍上升 → 延到 60 分钟并定位（对象/监听/定时器/词表学习持久化）。不做数小时 soak：离线单机、无网络/后台同步，30–60 分钟足以覆盖主要泄漏路径。

### 4.2 P-7 体积优化：**做（保留）**，W4 先行

- 理由：约 102.5MiB 零引用资源是「删除即收益」的低风险项，且与视觉/交互无关；先做这一步，再谈压缩与字体子集化。
- 顺序：W4（零引用清理）→ 重测 HAP（debug 与 release 各一次，release 另算 ets 符号收益）→ 若仍偏大，再评估 W5。
- 不建议现在动字体：清理后 CJK 字体 73.1MiB 将是最主要的剩余体积，但子集化会影响生僻字覆盖，且换字体文件会改导出/纸面渲染，需产品与基线双重批准。
- 内存侧（Q-4 记）：先做对照量测——把 `cnEngine` 设为 `system`（或临时跳过 `ensurePinyinEngine`）测冷启 PSS，量化词表常驻成本；若差值显著，再考虑「system 引擎不预加载」或「延迟到首次切中文」；后者会引入加载态，需产品确认。

## 5. 需要 Kit 裁决

| 编号 | 问题 | 选项 | 建议 |
|---|---|---|---|
| D-1 | Q-1 阅读交互 | A 平板改 `Scroll`，与手机一致，同步改设计稿 §5.3；B 双端改按纸分页＋页码（更贴纸页隐喻，工作量大）；C 不修（撤回 Q-1） | **A（已定，2026-11-28 W2 实施）**：改动小、双端一致；B 可作为后续体验升级 |
| D-2 | Q-3 是否本轮清理 | A 清理（W3）；B 只留档不修 | **A**：死代码已导致红测与误读，清理成本低 |
| D-3 | W4 资源清理边界 | A 只删运行时零引用；B 连契约样张一起移出 HAP（放 `tools/contract-assets/`）；C 暂不动 | **B**（A 为底线）：契约样张不参与运行，移出可再省；需同步改 `check-part-colors.py` 路径 |
| D-4 | S1 soak 时长 | A 30 分钟双机；B 60 分钟双机；C 不做 | **A**：足够覆盖主要路径，异常再延长 |

## 6. 汇总

| 编号 | 裁决 | 批次 | 是否阻塞其它批 |
|---|---|---|---|
| Q-1 | 修 | W2（已实施） | 否 |
| Q-2 | 修 | W1 | 否 |
| Q-3 | 修（清理） | W3（最低优先） | 否 |
| Q-4 体积 | 修（优化） | W4 | 否 |
| Q-4 内存 | 记（先量后定） | 对照量测，暂不排批 | 否 |
| P-6 soak | 留（做） | S1 独立验证 | 否 |
| P-7 体积 | 做（保留） | W4 先行；W5 留档 | 否 |

- 计数：修 3（Q-1/Q-2/Q-3）＋优化 1（Q-4 体积）＋记 1（Q-4 内存）；撤 0；P-6 留（做）、P-7 做（保留）。
- 建议顺序：W1（无产品决策，先做）→ W2（D-1 定了就做）→ W4（可与 W1/W2 并行准备）→ W3（清理，最后）→ S1（独立跑）。
- 所有批次都不改数据模型、不删用户数据；W4 只动 rawfile 与 manifest。

## 7. 证据索引与缺口

### 7.1 引用证据（均为 ⑤-1 已有截图/量测，本批未重拍）

| 用途 | 证据 |
|---|---|
| Q-1 平板文档视图正文（文字止于页面上部、下方空白、无滚动条） | 3950、3951 |
| Q-2 手机正文分隔行与滚动到底 | 3965、3966 |
| P-5/P-6 换行/压力后状态 | 3958、3971、3959、3972 |
| 冷启动基线 | 3929、3930 |
| HAP/PSS 数字 | `item05-inventory.md` P-7、P-6 表 |

### 7.2 代码证据

- `entry/src/main/ets/components/DocumentViewPage.ets:57-70`（load/readPlainText）、`:126-151`（平板 `maxLines(20)`＋`Clip`）、`:153-177`（手机正文）、`:185-196`（手机 `Scroll`）。
- `entry/src/main/ets/services/DocStore.ets:374-389`（`.txt` 分隔行）、`:104-122`（`load()`）、`:391-399`（`titleOf`）。
- `entry/src/main/ets/model/ExportCore.ets:57-60`（`sheetSeparatorText`）。
- `entry/src/main/ets/pages/Index.ets:2895-2939`（拨杆链）、`:975`（`canvasEnabled=false`）、`:217-228`/`:256`/`:3752`（拨杆状态写而不读）、`:2475-2479`（换机重置）、`:1386-1393`/`:591-643`（词表预加载）。
- `docs/界面重设计稿.md:491`（「超出页底裁掉不许滚动出页」）。
- `docs/designs/26-增补-5-批39.md:13-30`（批39 删除拨杆/旋钮/滚筒与拖拽回车入口）。
- `tools/tests/lever-angle.test.mjs:74-99`（两条失效断言）。

### 7.3 缺口与说明

1. **Q-1 未用 >20 行实文在平板触发**：⑤-1 缺口 5 已说明；本批为只读，不重造数据。结论由代码（`maxLines(20)`）＋页面结构＋3950 的「文字止于上部、下方空白」共同支撑，不是截图直证裁切瞬间。
2. **Q-2 平板截图 3950 未见分隔行**：可能该次打开时正文只有一张纸，或分隔行落在可视区外/被 20 行封顶截掉；手机 3965/3966 已直证。代码路径双端同一 `readPlainText`，结论可外推。
3. **Q-3 只做静态走查**：拨杆在 type26 已不存在，无法做交互验证；以 grep 零调用＋批39 设计文档＋红测为证。
4. **Q-4 体积为 debug signed HAP**：release 包未构建；零引用资源为静态扫描估算，未执行删除；动态拼串只覆盖已知两类，W4 动手前须再复核。
5. **内存对照未做**：`system` 引擎/跳过预加载的 PSS 差值需真机量测，本批不代判。
6. **单测状态**：`lever-angle.test.mjs` 2 项红为 main 既有状态（非本批引入）；其余测试未全量跑，W3 验真时再跑。

## 8. 工具与方法注记

- 代码检索：`grep`/`rg` 全仓；资源扫描：Python 遍历 rawfile，按 basename/relpath 在 ets/ts/json 中查引用，并计入 `machine/<kind>-*`、`ui-parts/tile-<slug>-<tier>` 两类动态拼串。
- 单测：`node --experimental-strip-types --test tools/tests/lever-angle.test.mjs`（Node v26.13.1）。
- 本批无设备操作；设备量测、截图与 hilog 均沿用 `item05-inventory.md` 及其 3929–3972 截图。
