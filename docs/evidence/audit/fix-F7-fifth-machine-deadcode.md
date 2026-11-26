# F7 修复批：第五台机覆盖＋死代码清理（R6、R26、R3、R4、R13、R14）

- 日期：2026-11-26
- 分支：`fix/fifth-machine-deadcode`（base `main` @ `e6580db`）
- 工作树：`D:\HarmonyAPP\carriagereturn\.worktrees\fix-fifth-machine-deadcode`

## 1. 改动（8 个文件，+31/−37）

| 条目 | 改动 |
|---|---|
| R6（D4） | ① `HomePage` hero 增加 2020s 分支（`machine/2020s-modern-front.jpg`），不再回落 1960s；② `Index.machineLabelText()` 增加 2020s →「现代薄荷」；③ `Index.cycleMachine()` 循环 5 台（加入 `2020s-modern`）；④ `ExportCore.machineTitleKey()` 增加 `2020s-modern → machine_name_modern`；⑤ `CollectionDetailPage.M_INFO` 增加 `2020s-modern → machine_info_modern`；⑥ 新增字符串 `machine_info_modern`（史实段落）；⑦ 文案「四台」改「五台」：`guide_collection_hint`、`guide_collection_1`、`guide_onboarding_3`、`guide_onboarding2_p2_body`（并补 2020s） |
| R26 | `CollectionPage`：当前机器卡加「当前机器」徽标；1920s 卡的「默认机器」行只在当前机是 1920s 时显示；2020s 条件行允许两行＋省略号（修截断） |
| R3 | 删除 `Index` 全局菜单死代码：`menuOpen` 状态、返回键里的菜单分支、`AppMenu` 挂载块（原先 `menuOpen` 全仓无置 true 入口） |
| R4（D13） | 删除 `Parts26.TopZone26` 的 `onBell`／`onPlate` 两个未使用回调，以及 `Index` 传参两行 |
| R13（D8） | 删除 `DocumentViewPage` 底栏「分享·待实现」死占位（分享走导出页） |
| R14（D9） | 不写代码：卷宗页暂无搜索入口，维持现状（搜索仅在内页），按裁决记录 |

## 2. 验收

| 条目 | 结果 | 证据 |
|---|---|---|
| 2020s hero | **通过** | 手机切 2020s 后主页 hero 为薄荷绿现代机（3644），不再回落 1960s 黑机 |
| 2020s 机名 | **通过** | 设置页默认机器行显示「现代薄荷」（3645；dump 计数 2） |
| 每日目标 500 | **通过** | 3644 主页统计行「今日 12 / 目标 500 字」 |
| 2020s 详情史实 | **代码已补** | `CollectionDetailPage` M_INFO 补 `machine_info_modern` 并在 base 新增该字符串；真机截图本次未取到（见 §3） |
| cycleMachine 五台 | **代码已改** | 列表加入 `2020s-modern`；真机逐台循环截图本次未取 |
| PDF 抬头 2020s | **代码已改** | `machineTitleKey('2020s-modern')` 返回 `machine_name_modern`；仅回退路径可见，本次未构造 |
| 当前机器徽标 / 默认机器动态 / 2020s 条件两行 | **代码已改**，真机截图未取 | 见 §3 |
| R3 菜单死代码删除 | **通过（编译）** | 代码已删、构建通过；菜单原先就不可达，删除后无行为变化 |
| R4 铃铛/铭牌回调删除 | **通过（编译）** | 属性与传参已删，构建通过 |
| R13 分享占位删除 | **代码已删** | 底栏现为 加页/导出/删除；真机截图未取 |
| 1920s 门图 | **通过** | 手机 vs 3579：四区 0.00%（3646）；平板 vs 3578：四区 0.00%（3647，frame 三区 maxdiff 1 < 阈值 30）。平板首次因字体是 IM Fell 导致 frame_mid 0.24% FAIL，切回 Courier Prime 后复测通过 |

## 3. 未完成（需补）

本次运行到后段设备前台被其他 App 反复抢占、导航点击多次落空，以下真机截图未取到，代码已改但**未做真机确认**：

1. 收藏页当前机器徽标、1920s「默认机器」隐藏、2020s 条件两行不截断。
2. 收藏详情 2020s 史实段落渲染。
3. 默认机器行连点循环到第 5 台（2020s）。
4. 文档视图底栏删除分享占位后的实际画面。
5. 候选字号 15/20 成对截图与字高对比（本批未做；3644/3645 只覆盖 hero 与机名）。

门图两张已补（3646/3647）。建议在设备空闲时补一次上述截图，不改代码。

## 4. 截图（`docs/shots/`，3644 起）

| 编号 | 文件 | 内容 |
|---|---|---|
| 3644 | `3644_f7_home_2020s_hero_goal500.png` | 主页：2020s 薄荷机 hero；统计行目标 500 字 |
| 3645 | `3645_f7_settings_machine_2020s.png` | 设置页默认机器「现代薄荷」 |
| 3646 | `3646_f7_gate_phone_1920s.png` | 手机 1920s 门图（四区 0.00%） |
| 3647 | `3647_f7_gate_tablet_1920s.png` | 平板 1920s 门图（四区 0.00%） |

## 5. 提交

- 分支 `fix/fifth-machine-deadcode`：8 个源文件 + 本报告 + 截图。不合 main、不推 main、不改清单。
