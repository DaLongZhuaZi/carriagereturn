# 核查②-1：五台机涂装素材清单（只读）

- 日期：2026-11-26
- 分支：`audit02-inventory`（base `main` @ `00a0c99`）
- 工作树：`D:\HarmonyAPP\carriagereturn\.worktrees\audit02-inventory`
- 只读：未改代码；本批只做代码与 rawfile 资产清点。

## 0. 结论摘要

- 五台机（1920s／1930s／1950s／1960s／2020s）的**主屏可用素材**（正视图、收藏卡正视图、收藏详情三图、键位表、键帽、键井地板）齐全且被正确应用。
- 老机（四台年代机）的**机身材质贴片、字车条、字杆层、扇形图**等一批素材只存在于旧组件里，而那些组件已不再实例化 → 资产在仓但**不被任何活代码引用**。
- 2020s 现代机在若干"按机拼串"的路径上**没有独立素材**（plate、tile、typebar、keycap-face、layers、carriage-strip），代码用 1920s 素材或直接跳过（MachineCatalog 自注"照抄 1920s"）。
- 已知线索核对：批 74 只把五台机的 **front** 换成了做旧版；`hero`、`keyboard`、`carriage`、`side` 四类 × 四台老机 = **16 张仍是旧版本**（批 74 提交信息"四台老机宽扇＋现代机键帽／照片＋老机正视图去做旧"未涉及这四类）。批 75 的"亮面键帽"在仓有 `cap3d-<slug>.png`，但代码一律用 `-matte`，**亮面从未被引用**。
- 缺口合计：**24 项**（见 §4）；其中 8 项为"被引用但文件不存在"的硬缺口，其余为"资产存在但无活代码使用 / 2020s 缺独立版本 / 版本待更新"。

## 1. 代码事实（哪些路径真正渲染）

| 渲染位置 | 素材来源 | 五台机覆盖 |
|---|---|---|
| 主页 hero、收藏页卡片剪影 | `machine/<kind>-front.jpg`（HomePage 分支 / CollectionPage 拼串） | 5/5 |
| 收藏详情三图、导出模板机器框 | `machine/<kind>-side.jpg`、`-keyboard.jpg`、`-carriage.jpg` | 5/5 |
| 打字机键位表 | `keymap/<kind>-keymap.json`（`Index.reloadKeymap`） | 5/5 |
| 键帽帽身、空格条 | `ui-parts/cap3d-<slug>-matte.png`、`ui-parts/cap3d-space-<slug>.png`（KeyGrid 分支） | 5/5 |
| 键井地板 | `ui-parts/keywell-floor-<slug>.png`（KeyWell 分支） | 5/5 |
| 机身分档颜色 | `MachineCatalog.TIER_TOKENS[machine]`（纯色 token，非图片） | 5/5（2020s 为 1920s 色系＋薄荷 base，按设计稿） |
| 字体、纸张 | `font/*.ttf` 17 款、`paper/*.jpg` 4 种（跨机共享，非按机素材） | 不适用"每机一套" |
| 声音 | 未测（按任务要求） | — |

**已定义为"每机素材"但没有任何活代码消费的字段**（`MachineCatalog.MachineSpec`）：`keybandPhoneRawfile`、`keybandFoldRawfile`、`carriageStripRawfile`、`typebarRawfile`、`leverRawfile`、`carriageLayerRawfile`、`frontRawfile`（只有 HomePage/CollectionPage 用自己的拼串，不读该字段）。`typebarRawfile` 另有一份 Index 私有实现，但**无调用点**。

**定义了但从未实例化的旧组件**（其素材因此全部成为死资产）：`MachineStage`（hero 四图）、`CarriageStrip`（carriage 四图）、`CarriageLayers`/`LeverLayer*`/`BracketAssembly1920`/`MetalAssembly1920`/`RollerAssembly1920`（`layers/<kind>/` 四套）、`Cheek`（tile paperwell）、`SteelPlate`（plate）、`lidTileImage`／`basketFanImage`（tile／basket-fan）。`KeyGrid.cap3dRawfile()` 也定义未用（渲染走显式分支）。

## 2. 每台机素材表

图例：✓ 存在且被活代码应用；△ 存在但只被死组件引用；○ 存在但无引用；✗ 被引用但文件缺失；— 该机不需要。

### 1920s 直立式
| 素材 | 文件 | 状态 |
|---|---|---|
| 正视 | `machine/1920s-upright-front.jpg` | ✓（批74 做旧版） |
| hero | `machine/1920s-upright-hero-3q.jpg` | △（仅 MachineStage） |
| 键盘照 | `machine/1920s-upright-keyboard.jpg` | ✓（收藏详情/导出） |
| 字车照 | `machine/1920s-upright-carriage.jpg` | ✓ |
| 侧面照 | `machine/1920s-upright-side.jpg` | ✓ |
| keyband phone | `machine/1920s-upright-keyband-phone.jpg` | ✗ 缺失（字段无消费） |
| keyband fold | `machine/1920s-upright-keyband-fold.jpg` | ✗ 缺失（字段无消费） |
| 字车条 | `carriage/1920s-upright-carriage-strip.png` | △（CarriageStrip 死组件） |
| 字杆层 | `typebar/1920s-typebar-vertical.png`、`1920s-lever-single.png`、`1920s-carriage-layer.png` | △（字段无消费） |
| 键位 | `keymap/1920s-upright-keymap.json` | ✓ |
| 键帽 | `cap3d-1920s-matte.png`、`cap3d-space-1920s.png` | ✓ |
| 亮面键帽 | `cap3d-1920s.png` | ○ 未引用 |
| 键面/空格面/按下态 | `keycap-face-*`、`spacebar-face-*`、`keycap-pressed-*` | ○（仅 PartContract 声明） |
| 键井地板 | `keywell-floor-1920s.png` | ✓ |
| 钢板/贴片 | `plate-1920s.png`、`tile-1920s-{base,base-v2,keybed,paperwell}.png` | △（SteelPlate/Cheek/lidTile 死） |
| 扇形 | `basket-fan-3d-v5-wide-1920s.png` 等 | △（basketFanImage 死） |

### 1930s / 1950s / 1960s（结构同 1920s）
| 素材类 | 状态（1930s／1950s／1960s） |
|---|---|
| front / hero / keyboard / carriage / side | ✓ front；hero △（死组件）；keyboard/carriage/side ✓ |
| keyband phone/fold | ✗ 缺失×2（每机） |
| carriage-strip | △ 死组件 |
| typebar/lever/layer | △ 字段无消费 |
| keymap、cap3d matte、space、keywell-floor | ✓ |
| cap3d 亮面 | ○ 未引用 |
| keycap-face 家族 | ○ 未引用（且布局仅 4 机，2020s 无） |
| plate／tile | △ 死组件 |
| basket-fan | △ 死组件 |

### 2020s 现代机
| 素材 | 文件 | 状态 |
|---|---|---|
| 正视 | `machine/2020s-modern-front.jpg` | ✓ |
| hero | `machine/2020s-modern-hero.jpg` | ○ 无引用；若 MachineStage 复活会**错用 1960s hero**（无 2020s 分支） |
| 键盘照 | `machine/2020s-modern-keyboard.jpg`（作 keybandPhone 字段） | ✓（收藏详情）；字段本身无消费 |
| keyarea | `machine/2020s-modern-keyarea.jpg`（作 keybandFold 字段） | ○ 字段无消费 |
| 字车照 / 侧面照 | `2020s-modern-carriage.jpg`、`-side.jpg` | ✓ |
| 字车条 | 无独立文件，`MachineCatalog` 照抄 1920s strip | ✗ 无 2020s 版本（字段无消费） |
| 字杆/拨杆/字车层 | 无 2020s 文件；`ui-parts/typebar-2020s.png` 缺失 | ✗（若 Index 私有拼串被调用会缺图） |
| 键位 | `keymap/2020s-modern-keymap.json` | ✓ |
| 键帽 | `cap3d-2020s-matte.png`、`cap3d-space-2020s.png` | ✓ |
| 亮面键帽 | `cap3d-2020s.png` | ○ 未引用 |
| 键面家族 | 无 2020s `keycap-face` / `spacebar-face` / `keycap-pressed` | ✗ 缺失（当前不被引用） |
| 键井地板 | `keywell-floor-2020s.png` | ✓ |
| 钢板/贴片 | `plate-2020s.png`、`tile-2020s-*` 全部缺失 | ✗ |
| 分层图层 | `layers/2020s-modern/` 整目录缺失 | ✗ |
| 扇形 | 复用 `basket-fan-3d-v5-wide-26.png`／`v4`（代码画扇后不再引用） | △ |

## 3. 正确版本核对（已知线索）

| 线索 | 核对结果 |
|---|---|
| 批74 只换了 front 做旧 | 成立：五台机 front 的最后提交都是 `9e13d66`（2026-11-22 批74 素材）；hero／keyboard／carriage／side 未在该提交内 |
| 16 张待处理 | 成立：hero（1920s hero-3q／1930s／1950s／1960s hero）、keyboard（4）、carriage（4）、side（4）仍是做旧前的版本；2020s 同四类亦未被做旧（另计） |
| 批75 亮面键帽只有哑光 | 半成立：仓内**有** `cap3d-<slug>.png`（亮面），但 KeyGrid 一律引用 `-matte`，亮面从未上屏；若批75 计划"亮面版"新素材，则**未见新文件**，现状是旧亮面躺在仓里没人用 |

## 4. 缺口清单（24 项）

**硬缺口（被代码引用但文件不存在）**
1. `machine/1920s-upright-keyband-phone.jpg`
2. `machine/1920s-upright-keyband-fold.jpg`
3. `machine/1930s-portable-keyband-phone.jpg`
4. `machine/1930s-portable-keyband-fold.jpg`
5. `machine/1950s-streamlined-keyband-phone.jpg`
6. `machine/1950s-streamlined-keyband-fold.jpg`
7. `machine/1960s-electric-keyband-phone.jpg`
8. `machine/1960s-electric-keyband-fold.jpg`
9. `ui-parts/typebar-2020s.png`（Index 私有拼串 `ui-parts/typebar-<slug>.png` 对 2020s 会缺图；当前该方法无调用点，属潜在缺口）
10. `ui-parts/plate-2020s.png`
11. `ui-parts/tile-2020s-base.png`／`tile-2020s-base-v2.png`
12. `ui-parts/tile-2020s-paperwell.png`
13. `ui-parts/tile-2020s-keybed.png`
14. 2020s 键面家族 `keycap-face-2020s*`／`keycap-pressed-2020s*`／`spacebar-face-2020s*`
15. `layers/2020s-modern/`（roller／rail／bail／guide／lever／bracket／typebar-strip 全缺）
16. `carriage/2020s-modern-carriage-strip.png`（字段照抄 1920s）

**版本待更新（资产在但版本旧）**

17. hero ×4（1930s／1950s／1960s／2020s；1920s 用 hero-3q）
18. keyboard ×4（1930s／1950s／1960s／2020s）
19. carriage ×4（同上）
20. side ×4（同上）
（合计 16 张，对应批74 遗留线索；1920s 四类已在该批更新）

**存在但无引用（死资产/死字段）**

21. `keybandPhoneRawfile`／`keybandFoldRawfile`／`carriageStripRawfile`／`typebarRawfile`／`leverRawfile`／`carriageLayerRawfile` 六个字段无消费者（MachineCatalog 内部自说自话）
22. `cap3d-<slug>.png` 亮面 ×5 未被引用（KeyGrid 只用 `-matte`）
23. `keycap-face`／`spacebar-face`／`keycap-pressed` 家族只在 `PartContract` 声明，渲染不用
24. `MachineStage`、`CarriageStrip`、`CarriageLayers`/`LeverLayer*`/装配件、`Cheek`、`SteelPlate`、`lidTileImage`、`basketFanImage` 全未实例化；其素材（hero、carriage-strip、layers 四套、tile 四套、plate 四张、扇形图）随之为死资产

## 5. 真机截图

本批未取得有效截图：取数过程中平板被 **HiSmartPerf（游戏性能调优工具，17:42）** 抢占前台，五台机主页/打字机页的连拍全部落在别家 App 上，按纪律作废、不入库。素材正确性以代码与文件清点为准；如需视觉佐证，建议在设备空闲时单独补拍五台机主页与打字机页各一张。

## 6. 提交

- 分支 `audit02-inventory`：本报告（本批只读，无代码与截图改动）。不合 main、不碰核查①清单。
