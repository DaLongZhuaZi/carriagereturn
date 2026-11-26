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
## 9. B2 落地记录（2026-11-26）

按裁决 D-A 与任务书：四个组件与 16 张专属资产**同批删除**。

**删除的代码（4 文件）**
- `components/MachineStage.ets`（63 行）
- `components/CarriageStrip.ets`
- `components/Cheek.ets`
- `components/SteelPlate.ets`（84 行）
- `pages/Index.ets`：删三个对应 import；`MachineCatalog.ets`：删仅被 SteelPlate 使用的 `plateRawfile()`
  合计 6 文件 +1/−241 行（纯删除为主）。

**删除的资产（16 张，按 D-A 与任务书口径）**
`machine/1920s-upright-hero-3q.jpg`、`machine/{1930s-portable,1950s-streamlined,1960s-electric}-hero.jpg`、
`carriage/{1920s-upright,1930s-portable,1950s-streamlined,1960s-electric}-carriage-strip.png`、
`ui-parts/plate-{1920s,1930s,1950s,1960s}.png`、`ui-parts/tile-{1920s,1930s,1950s,1960s}-paperwell.png`
——删组件前逐项 grep 过：它们只被这四个组件引用；组件删除后全仓 0 活引用，故与组件同批 git rm。

**验真**：signed hap 构建通过，双机装入后四页齐全：

| 页面 | 手机 | 平板 |
|---|---|---|
| 主页 | 3671 | 3675 |
| 打字机页 | 3672 | 3676 |
| 收藏页 | 3673 | 3677 |
| 导出页 | 3674 | 3678 |

四页画面与删前一致（四组件本来就没有实例化）。
## 10. B3a 落地记录：CarriageLayers 分层（2026-11-26）

按 D-A/D-F 只做分层的一半，并因删除量（代码 1653 行）按你的口径拆批：本批 = CarriageLayers 家族；LeverLayer 家族留 B3b。

**删除的代码（7 文件，1653 行）**
- `components/CarriageLayers.ets`（350 行，含 1920/1950/1960 三个 struct）
- `machines/1920s/CarriageLayers.ets`、`machines/1930s/CarriageLayers1930.ets`、`machines/1950s/CarriageLayers.ets`、`machines/1960s/CarriageLayers.ets`（各 303 行）
- 依赖它们、同样无实例化的汇编件：`machines/1920s/MetalAssembly1920.ets`（44）、`RollerAssembly1920.ets`（40）
- `Index.ets`：删对应 6 条 import

**删除的资产（21 张，孤儿）**
`layers/{1920s-upright,1930s-portable,1950s-streamlined,1960s-electric}/` 下
`roller-texture-v7.jpg`、`typebar-basket-strip.png`、`carriage-base-rail.png`、`paper-bail-v2.png`、`central-guide.png`（5×4），加 `1920s-upright/master-reference.jpg`（全仓 0 引用）。
**保留**：`layers/*/lever.png`（LeverLayer 还在，B3b 处理）、`layers/*/lever-pivot-bracket.png`（Blueprint/BracketAssembly 仍引用）。

**验真**：signed hap 构建通过；双机装入后四页正常——
手机 3679 主页／3680 打字机／3681 收藏／3682 导出；平板 3683／3684／3685／3686。

## 11. B3b 落地记录：LeverLayer／装配（2026-11-26）

按 D-A/D-F，本批删除量 584 行（略超「约 500」），因此把任务书里的 Parts26 两个未调用 builder 拆到 B3c，未在本批删。

**删除的代码（5 文件，584 行）**
- `components/LeverLayer.ets`（156）、`machines/1930s/LeverLayer1930.ets`（122）、`machines/1950s/LeverLayer.ets`（122）、`machines/1960s/LeverLayer.ets`（122）
- `machines/1920s/BracketAssembly1920.ets`（53）
- `Index.ets`：删 5 条 import；三处提到已删层的陈旧注释改为中性表述（换行计数、杆长派生、Hc 同源）

**Blueprint 系列：保留（有活引用）**
`Index.bp()` 被 8 处几何方法调用（bracketAspect／pivot／leverAspect／leverSizeRatio）；`bracketSrc()` 仍引用 `bp().bracketRawfile()`。故 Blueprint 四份与 BlueprintTypes 不动，对应 `layers/*/lever-pivot-bracket.png` 保留。

**删除的孤儿资产（5 张）**
`layers/{1920s-upright,1930s-portable,1950s-streamlined,1960s-electric}/lever.png`（仅 LeverLayer 引用）＋ `layers/1920s-upright/typebar.png`（全仓 0 引用）。

**验真**：signed hap 构建通过；双机四页正常——手机 3687 主页／3688 打字机／3689 收藏／3690 导出；平板 3691／3692／3693／3694。

## 12. B3c 落地记录：Parts26 两个未调用 builder（2026-11-26）

**删前核对**：全仓 grep `lidTileImage`／`basketFanImage`，除定义处外 0 个引用点，确认无调用。

**删除**：`components/type26/Parts26.ets` 里 `@Builder lidTileImage` 与 `@Builder basketFanImage`（含注释，共 −46 行）。`lidColor` 等其余函数未动。

**验真**：signed hap 构建通过；双机四页正常——手机 3695 主页／3696 打字机／3697 收藏／3698 导出；平板 3699／3700／3701／3702。
（平板 3701／3702 首拍时点击未生效，重拍并以 dump 确认在收藏／导出页后入库。）
