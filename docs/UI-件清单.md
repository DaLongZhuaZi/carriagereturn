# UI-件清单（批 1 建立；每件的路径／变体／契约参数／色板采样点）

> 单一真源：`entry/src/main/ets/model/PartContract.ets`。本表是**贴片档案**，登记仓内实际用到的图片、
> 变体维度、契约参数与色板采样点（给 `tools/check-part-colors.py`／`check-part-grain.py` 提供口径）。
>
> 素材位置：`entry/src/main/resources/rawfile/ui-parts/`（平铺，不分子目录）。入库提交 `7357685`（28 件）／`9c74510`（机身颗粒 4 张），
> 共 32 个 PNG。**本批不重生成、不转存。**

## 1. 贴片 → 件 对应表

| 件 | 贴片 | 变体维度 | 状态 |
|---|---|---|---|
| 纸面板 | `paper-letter.png`／`paper-manuscript.png`／`paper-postcard.png`／`paper-memo.png` | `texture`（无 machine 维，v3 F1 修正） | **批 1 用** |
| 键盘网格（帽面） | `keycap-face-1920s.png`／`-1930s`／`-1950s`／`-1960s` | `capShape`／`capColor`（按机型） | **批 1 用 1920s** |
| 键盘网格（按下态） | `keycap-pressed-1920s.png`／`-1930s`／`-1950s`／`-1960s` | 同上（PIL 从帽面派生，高光暗 30%） | **批 1 用 1920s** |
| 键盘网格（空格条） | `spacebar-face-1920s.png`／`-1930s`／`-1950s`／`-1960s` | 同上 | **批 1 用 1920s** |
| 功能行 | —（真文字按钮，不入库图片） | `iconStyle` | **批 1 用**（纯 ArkUI） |
| 横尺与页边标记 | `ruler.png` | — | 批 2 |
| 落字导件 | —（矢量例外，代码画） | — | 批 2 |
| 字篮图形 | `basket-fan-1920s.png`／`-1930s`／`-1950s`／`-1960s` ＋ 字杆 `typebar-1920s.png` 等 | `basketStyle` | 批 2 |
| 拨杆控件 | `lever.png` | `leverShape` | 批 2 |
| 旋钮控件 | `knob-metal.png` | `knobFace` | 批 2 |
| 机身面板 | `bodypanel-1920s-grain.png`／`-1930s-grain`／`-1950s-grain`／`-1960s-grain` | `colorway` | 批 2 |
| （不入 9 件）色带条 | `ribbon-strip.png` | `inkColor` | 批 2 随其余件登记 |

## 2. 契约参数（批 1 已填的三件）

| 件 | 锚点 | 尺寸 | z | 材质 token | 契约色 | 色板采样点（相对坐标） |
|---|---|---|---|---|---|---|
| `paper-panel` | paperBaseX＝156.35vp | Pw 330.7×Ph 467.61 | 1 | `cream-paper-fiber` | `#eee4ce` | (0.5,0.5) (0.2,0.3) (0.8,0.7) |
| `key-grid` | 功能行底缘 | stageW−24 × H_keyGrid | 6 | `keycap-ivory` | `#f2ead6` | (0.5,0.5) (0.35,0.4) (0.65,0.6) |
| `function-row` | 全宽 | stageW × 40vp | 5 | `flat-hud-gold` | `#c9a45c` | —（无贴片，按代码常量校验） |

## 3. 质检结果（批 1 实跑，`tools/check-part-*.py`）

| 脚本 | 范围 | 结果 |
|---|---|---|
| `check-part-colors.py` | 三件（纸面板／键盘网格／功能行） | **FAIL 0**：纸面板 worst 0.087、键盘网格 worst 0.037（阈值 0.10） |
| `check-part-grain.py` | 批 1 质检集 16 件（纸 4＋帽面 4＋按下态 4＋空格条 4） | **16/16 PASS**（颗粒＝高频残差 ≤0.15；详见批报告） |

> 口径说明：颗粒判定用**高频残差**（3×3 低通后的 |原图−低通| 分位差），同时打印 21 号稿的 `maxmin` 作对照。
> 二者不一致的件（纸有横线、帽有倒角）会在输出里标 `*`——原因是 `maxmin` 把**结构**当成了颗粒。

## 4. 未入库（按设计口径）

- 功能行六项文字按钮、顶栏三图标：**不生成图片**（文字按钮＋系统 Symbol，仓 AGENTS.md 图标铁律）。
- 落字导件：矢量例外，代码画，不入库图片。
