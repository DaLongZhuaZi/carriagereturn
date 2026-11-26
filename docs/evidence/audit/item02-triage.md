# 核查②-2：24 项缺口处置方案（只读）

- 日期：2026-11-26
- 分支：`audit02-triage`（base `main` @ `f464b4d`）
- 依据：`docs/evidence/audit/item02-inventory.md` §4
- 只读：本批不改代码、不改资产、不动设备。

## 1. 总览

| 处置方向 | 条目 | 数量 |
|---|---|---|
| **删死字段**（代码收口） | 21 | 6 字段 |
| **删死组件＋其资产**（需 Kit 裁决） | 24 | 7 类组件／约 70 张资产 |
| **2020s 独立素材：补 or 不补**（需 Kit 裁决） | 9–16 | 8 类 |
| **16 张图重做旧**（美术排产） | 17–20 | 16 张 |
| **亮面键帽：接入 or 删**（需 Kit 裁决） | 22 | 5 张＋1 helper |
| **键面家族声明：删 or 留作契约**（需 Kit 裁决） | 23 | 3 族声明 |

修复批合计 **5 个代码批＋2 个资产批**；其中 4 个批被裁决阻塞。

## 2. 逐项处置

| 条目 | 处置 | 理由 / 落点 |
|---|---|---|
| 1–8 keyband phone/fold ×4 | **删字段**（资产不补） | 字段无消费者；旧键带方案已被 KeyGrid 的生成件键帽取代。删 `MachineSpec.keybandPhoneRawfile/keybandFoldRawfile` 与条目赋值，两条历史注释同步。 |
| 9 `ui-parts/typebar-2020s.png` | **删私有 helper** | `Index.typebarRawfile()`／`basketFanRawfile()` 均无调用点；若将来重启整机照片路线，再按需补 2020s 图。本批建议直接删 helper，不补图。 |
| 10 `plate-2020s.png` | **随死组件处置** | `SteelPlate` 未实例化；若 D-A 裁决删组件，则 plate 一并归档删除，不补 2020s。 |
| 11–13 `tile-2020s-*` | **随死组件处置** | 同上（`Cheek`／`lidTileImage` 死）。 |
| 14 2020s 键面家族 | **不补**（当前渲染不用） | `keycap-face*` 只被 PartContract 声明；若 D-E 删除声明，此缺口自然消失。 |
| 15 `layers/2020s-modern/` | **不补**（组件死） | `CarriageLayers` 及其装配件未实例化；D-A 删组件则不需要 2020s 图层。 |
| 16 `carriage/2020s-modern-carriage-strip.png` | **删字段赋值** | `carriageStripRawfile` 无消费者；2020s 条目里"照抄 1920s"的赋值可去掉，等组件复活再补。 |
| 17–20 16 张做旧图 | **重做旧（资产批 A1）** | 唯一真正"用户看得见"的缺口：hero/keyboard/carriage/side ×4 台（1930s/1950s/1960s/2020s）。1920s 已在批74 更新。需要做旧风格基准（见 D-D）。 |
| 21 六字段无消费者 | **删字段（代码批 B1）** | `MachineCatalog.ets` 一处；同时删 `Index` 两个私有 helper（item 9）。2 个文件、约 40 行。 |
| 22 亮面键帽 5 张 | **需裁决 D-C**：接入 or 删 | 接入＝KeyGrid 增加"亮面/哑光"选择（新选项，属功能变更，需设计确认在哪个入口切）；删除＝`git rm` 5 张＋删 `cap3dRawfile` 未用 helper。 |
| 23 键面家族声明 | **需裁决 D-E**：删声明 or 留作画稿契约 | 只影响 `PartContract.ets` 一张表。 |
| 24 七类死组件 | **需裁决 D-A**：删 or 留 | 删除带来两批代码清理（B2/B3）＋约 70 张资产删除；保留则这些资产继续躺仓、且 2020s 缺图问题保留。 |

## 3. 修复批建议

> 约束：每批 ≤3 个文件族、≤200 行 diff、≤8 条目；**纯文件删除的 diff 按"删除行数"计**，容易超 200，故 B2/B3 需要 Kit 对"删除批允许超行数"放行（D-F）。

### 代码批 B1：素材字段收口（不被裁决阻塞）
- 条目：21、9
- 文件：`model/MachineCatalog.ets`、`pages/Index.ets`（2 个文件族）
- 内容：删 `keybandPhoneRawfile/keybandFoldRawfile/carriageStripRawfile/typebarRawfile/leverRawfile/carriageLayerRawfile` 六个字段与五台机赋值；删 Index 两个无调用私有 helper；同步相关注释
- 预估：+5/−45 行
- 验证：构建通过；打字机页与收藏/导出页面截图不回归（画面无关改动）

### 代码批 B2：死组件删除（一）——照片类
- 条目：24（部分）
- 文件：`components/MachineStage.ets`、`components/CarriageStrip.ets`、`components/Cheek.ets`、`components/SteelPlate.ets`
- 内容：`git rm` 四个未实例化组件；随后其专属资产（hero 4、carriage-strip 4、plate 4、tile paperwell 4）可随批删除或留档（D-A）
- 预估：删除约 400 行（**超 200，需 D-F**）
- 验证：构建通过；页面无引用错误

### 代码批 B3：死组件删除（二）——分层与装配
- 条目：24（其余）
- 文件：`components/CarriageLayers.ets`、`CarriageLayers1930.ets`、`LeverLayer.ets`、`LeverLayer1930.ets`、`machines/*/LeverLayer*.ets`、`Blueprint.ets`、`BracketAssembly1920.ets`、`MetalAssembly1920.ets`、`RollerAssembly1920.ets`、`components/type26/Parts26.ets`（删 `lidTileImage`／`basketFanImage` 两个未调用 builder）
- 预估：删除约 900＋ 行（**远超 200，需 D-F**，或拆成 3 个更小删除批）
- 验证：构建通过；`layers/` 四套资产随之成为孤儿（归档或删除）

### 代码批 B4：键面家族声明（裁决后）
- 条目：23
- 文件：`PartContract.ets`（1 文件）
- 内容：按 D-E 删除声明或改为画稿契约说明
- 预估：±30 行

### 代码批 B5：亮面键帽接入（仅当 D-C 选"接入"）
- 条目：22
- 文件：`components/KeyGrid.ets`、`SettingsPage.ets`（或换装页）＋ 1 条字符串（3 文件族）
- 内容：新增"键帽表面：哑光／亮面"选项（默认哑光，保持现有像素）；KeyGrid 渲染按选项选 `cap3d-<slug>.png`
- 预估：＋60/−8 行
- 验证：默认档截图与现基线一致；亮面档肉眼可见差异

### 资产批 A1：16 张做旧（设计/美术）
- 条目：17–20
- 产出：`machine/<kind>-hero|keyboard|carriage|side` 四类 × 4 台（1930s/1950s/1960s/2020s）做旧版，同名替换
- 前置：D-D（做旧风格基准与是否 2020s 一起做旧——现代机是否该"做旧"本身是设计问题）
- 验证：五台机主页/收藏详情/导出 PDF 抽帧目视；若只换图，页面布局不变

### 资产批 A2：2020s 独立素材（仅当 D-B 选"补"）
- 条目：10–16（plate/tile/typebar/layers/carriage-strip/keycap-face）
- 前置：需先定这些素材的消费者（当前全是死路径）——若 D-A 删组件，则本批不存在；若保留组件，则先在代码里接线，再做资产
- 结论：**建议不单独立批**，随 D-A/D-B 结果并入对应代码批

## 4. 需要 Kit 裁决（不要我替用户拍板）

| 编号 | 裁决点 | 选项 | 我的建议（仅建议） |
|---|---|---|---|
| D-A | 七类死组件与其资产：删还是留 | 删（代码+资产一起）／保留 | **删**：无实例化、无调用，留着会让"2020s 缺图"永远算缺口 |
| D-B | 2020s 独立素材：补一套，还是接受"与 1920s 共用 + 薄荷 base" | 补／接受共用 | **接受共用**：现有设计稿写明沿用 1920s 几何，补全套成本高、收益低；若将来换新机再补 |
| D-C | 亮面键帽：接入切换，还是删除 | 接入（加选项）／删除 | **删除**：当前无入口、需求未提；留着只是 5 张死图 |
| D-D | 16 张做旧：是否排产，2020s 现代机是否一起做旧 | 排产（含/不含 2020s）／暂不做 | **排产但不含 2020s**：现代机"做旧"与设计语义冲突，需产品确认 |
| D-E | `keycap-face` 家族声明：删 or 留作画稿契约 | 删／留 | **留但在注释里标明"仅画稿契约，不参与渲染"** |
| D-F | 删除批的 diff 行数豁免 | 允许删除批超 200／拆细 | **允许 B2/B3 超限**（纯删除，风险低），或拆成 3 个删除批 |

## 5. 结论摘要

- 24 项里：**只有 16 张做旧图是真正影响画面的缺口**；其余大多可归为"删死代码/删死资产"（15 项）与"要不要补 2020s 素材"（8 项，其中多数随死组件处置）。
- 代码侧可立刻动的只有 **B1（字段收口，约 45 行）**；B2/B3 删除批与 B4/B5 需 D-A/D-C/D-E/D-F 裁决。
- 资产侧 A1（16 张做旧）是唯一建议排产的美术批；A2 不建议单独立批。

## 6. 提交

- 分支 `audit02-triage`：本报告（无代码与资产改动）。

## 7. 裁决 D-A–D-F（Kit 2026-11-26 18:2x，全权自主）

| 编号 | 裁决 |
|---|---|
| D-A | 七类死组件删，专属资产一起删（git rm；git 历史可恢复）。B2/B3 执行。 |
| D-B | 2020s 独立素材不补，接受与 1920s 共用＋薄荷 base。A2 不立批。 |
| D-C | 亮面键帽删（git rm 5 张＋删 KeyGrid 未用 helper `cap3dRawfile`），不加切换选项。单独小批 B6 执行。 |
| D-D | 16 张排产：1930s/1950s/1960s 按批 74 做旧基准；2020s 的 4 张不做旧痕、按现代机干净风格统一。资产批 A1 执行。 |
| D-E | `keycap-face` 家族声明保留，注释标明仅画稿契约、不参与渲染。B4 执行。 |
| D-F | 允许删除批超 200 行，但单批删除不超过约 500 行；B3 拆成两批（分层一批、装配一批）。 |

## 8. B1 落地记录（2026-11-26）

按裁决 D-A 先做 B1：删死字段与无调用 helper，不动组件与资产。

| 文件 | 改动 |
|---|---|
| `model/MachineCatalog.ets` | 删 `MachineSpec` 六个字段（keybandPhone／keybandFold／carriageStrip／typebar／lever／carriageLayer）及五台机对应赋值；连带清掉它们各自的注释（含 1930s fold 说明、2020s「照抄 1920s」说明） |
| `pages/Index.ets` | 删 `typebarRawfile()`、`basketFanRawfile()` 两个无调用私有 helper（19 行） |

合计 2 文件 +1/−64 行。构建通过（signed hap），双机装入后：

| 页面 | 手机 | 平板 |
|---|---|---|
| 打字机页 | 3665 | 3668 |
| 收藏页 | 3666 | 3669 |
| 导出页 | 3667 | 3670 |
| 结果 | 三页均正常（5 键功能行／五卡齐全／预览与保存分享都在） | 同左 |

画面与删字段前一致（这些字段本就无消费者，删除不影响渲染）。

**双机截图**：手机 3665/3666/3667，平板 3668/3669/3670（均装本分支 signed hap）。