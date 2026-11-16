# UI-件清单（批 1 建立；每件的路径／变体／契约参数／色板采样点）

> 单一真源：`entry/src/main/ets/model/PartContract.ets`。本表是**贴片档案**，登记仓内实际用到的图片、
> 变体维度、契约参数与色板采样点（给 `tools/check-part-colors.py`／`check-part-grain.py` 提供口径）。
>
> 素材位置：`entry/src/main/resources/rawfile/ui-parts/`（平铺，不分子目录）。入库提交 `7357685`（28 件）／`9c74510`（机身颗粒 4 张），
> 共 32 个 PNG。**本批不重生成、不转存。**非缺省变体 17 件见 §5（2026-11-17 沙箱生成入库，待用户目视确认；入库后共 49 个 PNG）。

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
| `check-part-grain.py` | 批 1 质检集 16 件（纸 4＋帽面 4＋按下态 4＋空格条 4） | **16/16 PASS**（颗粒＝高频残差 ≤0.15；产物 `docs/evidence/p24-grain-run.txt`） |
| 做旧等级 | 纸面板＋键帽（18 号稿 §2.1 分级） | **0 级**（目视：无划痕／锈／灰尘／水渍；贴片本身干净，未做旧） |
| 纸面受光均匀 | 纸面板（截图 1703） | **0.55%**（判据 ≤5%） |

> 口径说明：颗粒判定用**高频残差**（3×3 低通后的 |原图−低通| 分位差），同时打印 21 号稿的 `maxmin` 作对照。
> 二者不一致的件（纸有横线、帽有倒角）会在输出里标 `*`——原因是 `maxmin` 把**结构**当成了颗粒。

## 3.2 批 2 新挂载的七件（2026-11-17）

| 件 | 贴片 | 运行时尺寸 | 证据 |
|---|---|---|---|
| 横尺与页边标记 | `ruler.png` | Pw×8vp，贴纸面板底缘 | 1714–1717 |
| 落字导件 | —（矢量：虚线＋倒三角） | 12vp 虚线／6×4v 三角，x=archFixX | 1714–1717 |
| 字篮图形 | `basket-fan-<slug>.png`（metal 变体只登记不挂载） | stageW×0.8×130vp，底缘贴功能行顶 | 1714–1717 |
| 色带条 | `ribbon-strip.png` | Pw×35vp，批 2 画在纸面板之下（藏） | 1714–1717 |
| 拨杆控件 | `lever.png` | 10×（H_paperZone×0.6）vp，右缘 | 1714–1717 |
| 旋钮控件 | `knob-metal.png`（哑光黑变体只登记不挂载） | knobD＝54.4vp，跨骑纸下沿两角 | 1714–1717 |
| 机身面板 | `bodypanel-<slug>-grain.png`＋机型底色（颗粒 0.15 叠加） | 全屏 cover | 1714–1717 |

> 非缺省变体（round 帽面/按下态/空格条、金属字篮、哑光黑旋钮，共 17 件）已入库、**待用户目视确认**；
> 批 2 只登记、不挂载（§3.2.2 缺省仍是 rounded-rect／flat-line／metal-knurl）。

## 3.1 批 1 试点实际用到的贴片（挂载后实测）

| 件 | 贴片 | 运行时尺寸 | 证据 |
|---|---|---|---|
| 纸面板 | `paper-manuscript.png`（当前纸种＝稿纸） | 330.7×467.6vp，可见容器 126.0vp，直角无圆角 | `PaperPanel: mount …`／截图 1703 |
| 键盘网格·帽面 | `keycap-face-1920s.png` | 43 帽，帽宽 0.0601×362.7＝21.8vp | `KeyGrid: mount … slug=1920s` |
| 键盘网格·按下态 | `keycap-pressed-1920s.png` | 按下帽下沉 2.07vp（实测） | 截图 1706（长按帧）＋相邻帽对照 |
| 键盘网格·空格条 | `spacebar-face-1920s.png` | 宽 215.0vp | `KeyGrid: mount … spaceW=215.0` |

> 键区过渡态：`KeyGrid.showBacking` 用机身色（1920s `#312b24`）铺满键区矩形，遮住 Canvas 旧键带照片
> （照片里 baked 的 "hift" 随之一并消失）。批 2 机身面板挂载后删 `showBacking`。

## 4. 未入库（按设计口径）

- 功能行六项文字按钮、顶栏三图标：**不生成图片**（文字按钮＋系统 Symbol，仓 AGENTS.md 图标铁律）。
- 落字导件：矢量例外，代码画，不入库图片。

## 5. 非缺省变体（2026-11-17 沙箱生成入库，待用户目视确认）

> 全部抠图透明底 PNG（绿底色键抠，满幅贴片除外——本节无满幅贴片）。沙箱目视已过（圆帽／胶囊空格条／金属字篮／哑光黑旋钮各 1 张抽查＋红底透明显真），**用户目视未确认**：批 4 换装页可用，批报告须注明"待用户目视确认"；用户否决某变体时先屏蔽该选项、不删图。
> 命名：缺省 `keycap-face-<machine>.png` 是 rounded-rect 档；round 档在 `face` 后加 `round`（`keycap-face-round-<machine>.png`）；字篮金属渐变档在 `fan` 后加 `metal`（`basket-fan-metal-<machine>.png`）；旋钮哑光黑是通用 1 张（`knob-matteblack.png`，与 `knob-metal.png` 对应）。

| 件 | 贴片 | 变体维度 | 全透明占比 |
|---|---|---|---|
| 键盘网格（round 帽面） | `keycap-face-round-1920s.png`／`-1930s`／`-1950s`／`-1960s` | `capShape`＝round | 23.1–23.4%（圆帽占满画面，只四角透明） |
| 键盘网格（round 按下态） | `keycap-pressed-round-1920s.png`／`-1930s`／`-1950s`／`-1960s` | 同上（PIL 从 round 帽面派生：整体 ×0.85、左上高光区净 ×0.70） | 同上 |
| 键盘网格（round 空格条） | `spacebar-face-round-1920s.png`／`-1930s`／`-1950s`／`-1960s` | 同上（胶囊形宽幅条） | 7.4–9.3% |
| 字篮图形（金属渐变档） | `basket-fan-metal-1920s.png`／`-1930s`／`-1950s`／`-1960s` | `basketStyle`＝金属渐变（Q12(b)：两段线性渐变金属高光 #beb4a8 → 机身中调 #574d43、刻线 1vp 深色 70%、下缘 2vp 底边阴影） | 50.5–60.5% |
| 旋钮控件（哑光黑） | `knob-matteblack.png`（通用 1 张） | `knobFace`＝哑光黑 | 23.6% |

