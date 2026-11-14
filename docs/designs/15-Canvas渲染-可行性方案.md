# 15-Canvas 渲染：整页自定义绘制可行性方案

- 状态：**已批准（2026-11-13，用户批准「按缺省执行」）**
- 日期：2026-11-13
- 基准提交：远端 main `f51d1ad`（第 13 批设计稿 v2.2 已批准时点）
- 证据：代码面调查 `~/workspace/egm-work/canvas-invest-codebase.md`（54KB）；API 面调查 `~/workspace/egm-work/canvas-invest-api.md`（约 33KB）；概念 brief `~/workspace/egm-work/canvas-concepts-brief.md`
- 性质：**可行性方案，不是实施设计**。本稿回答"C 能不能做、要先验什么、边界划在哪、分几步走"；Canvas 组件拆分、绘制分层细节、逐组件迁移顺序是 Phase 2 实施设计稿的事，须等 Phase 0 探针全部通过后另立稿。

## §0 本批新证据改了上一批哪条结论、为什么改

第 14 批「底层布局适配」v2 稿（范围适配路线）已被用户 2026-11-13 否决，作废，不再往前提。否决的直接原因是沙箱如实回答"可以实现任何设备都可以正确显示吗"时只能答不能：范围适配只能保证支持范围内（availW 320–1280vp、availH 560–1600vp、宽高比 1.2–2.6）按构造正确、范围外降级，且核心前提 R2 未验真、kTop 单值两台设备对不上、数值基于旧日志推算、模拟器改尺寸未证实、只覆盖竖屏。

本批新证据（两路调查，2026-11-13 完成）改了三条判断：

1. **"修好派生链"是唯一出路——改了**。C 方案不修派生链：整机画在固定坐标画布上，内部相对位置冻结，只剩一个缩放系数；ArkUI 的布局行为（R2 之谜）直接绕过去。R2 不是被解决了，是被绕过去了——本稿凡写"C 解决 R2"处一律按此口径纠正；保留 ArkUI 的覆盖层页仍活在 ArkUI 布局里，R2 对它们仍然 relevant。
2. **"Canvas 什么都能画"——改了**。API 面基本可行，但有两个必须先过的验证关：自定义字体能否进 Canvas（最大风险，未查到任何官方说法或社区实测）；60fps 级全屏重绘（次大风险，无 `requestAnimationFrame`、无脏矩形）。本稿不把这两项写成"已证实"，写成 Phase 0 探针，每项有可证伪的通过标准。
3. **"整页都能进 Canvas"——改了**。代码面逐组件难度分级表明：含原生 TextInput 的覆盖层页、IME 锚点、TopBar 图标是能力／规则边界（TextInput 嵌不进 Canvas、Canvas 不接 IME、SymbolGlyph 无 Canvas 等价物），保留 ArkUI；SpotlightOverlay 锚点体系、CandidateBar、PhotoKeybed 多点触摸、CarriageLayers、动画总体是"难"但要做的事，不构成保留理由。本稿定混合边界：打字机主屏（含 SpotlightOverlay、CandidateBar）进 Canvas，覆盖层页保留 ArkUI（范围决定，见 §5.1），锚点与输入以透明覆盖层保留。
4. **用户 2026-11-13 16:39 定（早期开发口径）**：不考虑难方面的问题，现在是早期开发阶段，要尽可能做到尽善尽美——难度不作为推迟或砍范围的理由，"难"的组件按"要做"评；只有真正的能力边界才构成保留 ArkUI 或走兜底链的理由；无障碍默认不降级（逐键读屏以透明原生按钮覆盖层全量补）。本稿 v2 已按此口径重划 §5.1 边界、重写 §12 Q3、并把无障碍覆盖层全量清单写进 §5.1。

## §1 问题重述与目标

### 1.1 问题

回车打字机主屏在未知设备上错位：零件错位、纸张错位、键盘错位。根因（第 14 批调查 R1–R11，`layout-root-cause.md`）：几何体系没有单一、连续、可闭合的派生链——位置由（窗口尺寸 × 设备类型 × 折叠态）× 多处重复写入共同决定；两台已知设备看着对，是因为分支常量是按这两台反向拟合出来的。最严重的几项：R1 平板纵向锚点 H 冻结在默认值 720（根本不是窗口高的函数）；R2 声明的高度不决定渲染位置、纵向预算在纸面上不闭合、机制未证实；R3 `isTablet` 悬崖式二值分级（门槛两侧 9 组常量切换，无回滞）；R6 键带叠字靠四个公式恰好一致；R7 字号是密度的函数不是尺寸的函数。

### 1.2 目标

给出一种底层方案，让打字机主屏在**任意非折叠竖屏设备**上正确显示——"正确"的定义是：机器硬件内部相对位置与参考机一致（刚性整体）；纸面文字网格不跟机器缩放，字号保底 17vp、每行字数随纸宽变（口径（b），见 §7，待 §12 Q1 定夺）；触摸命中、动画时序、输入通道的行为与现行一致。横屏不在本稿范围（用户原指令：仅以竖屏为例，横屏之后再另外考虑）。**Scope：C 只覆盖非折叠竖屏；desk 态（折叠半开桌台模式）另立处理（仍走现行分支，另立设计），不在本稿 scope 内**（见 §12 Q5）。

### 1.3 参考机

以平板现行布局为参考机：stageW 673.7vp、Pw 444.6vp、fs 24vp、lh 42.35vp、Hc 75.6vp、Ph ≈628.7vp（`Pw × 1.414`，Index L1955；685.9 是旧 0.72 口径 Pw=485.1 的遗留值，见 `docs/界面重设计稿.md:341`）、maxRows 13。**H（冻结）= 720vp（operative 值）**：`frozenHVp` 首次稳定测到时取值、永不更新，平板 H 取 `frozenHVp`，carriageTop = 0.56 × 720 = 403.2；availH ≈ 1006.3vp（2026-11-04 同次运行日志实测）为 live 窗口高，不直接进入几何。Canvas 画布坐标系即参考机坐标系，一个变换矩阵（缩放＋平移）落位到真实屏幕。

### 1.4 变换规则（缺省）

全稿的支点概念，定义如下（未定项标"待 Q1 一并定夺"，见 §12 Q1）：

1. **scale 公式**：`scale = min(屏宽/673.7, 屏高/1006.3)`，**上限 1.0**（不放大；超大屏机器定格参考机尺寸）；
2. **平移规则**：水平居中；垂直顶对齐并留 topInset（沉浸式顶距）。`tx = (屏宽 − 673.7×s)/2`，`ty = topInset`；
3. **余量填充**：深底纯色（与 A 方案"桌面深底"一致，色值沿用 `#241c16` 一带，Phase 2 定）；
4. **参考机原点**：画布左上角 (0,0) 对应参考机坐标原点；变换矩阵 ＝ `translate(tx, ty) ∘ scale(s)`；
5. **光标矩形换算**（P4 用）：参考机坐标 (x, y) → 屏坐标 `(x×s + tx, y×s + ty)` → px（×vp2px）；经 `updateCursorRect` 推出去。vp2px 取值来源与现行 `pushCnCursor`（Index L750）同源（当前设备 window 的 vp2px）；
6. **TopBar 同步**：TopBar 的 ArkUI `.position()` 坐标由同一变换矩阵算出（x = tx，y = ty，宽 = 673.7×s），不是"读"Canvas 的矩阵；
7. **目标 SDK**：App 目标 SDK 26.0.0（`targetSdkVersion = compatibleSdkVersion = 26.0.0`，根 `build-profile.json5`）；OffscreenCanvas（API 11+ 传 worker）、`RenderNode + DrawContext`（API 11+）、`LengthMetricsUnit`（API 12+）均在目标 SDK 范围内，可用。

## §2 可行性总判断

**总判断：API 层面与代码层面基本可行，但有两个验证关须探针先行定性；六项探针全部通过才算"可行"，任一不通过走兜底链，兜底链走完仍不通过则回報用户重定路线，不硬上。**本 verdict 是 API／代码层面的可实现性判断；目标口径以 §12 Q1 的答案为准，若用户选（a），§1.2 的"刚性整体"才按字面成立。

### 2.1 需求清单逐项打勾（API 面 × 代码面交叉）

| # | 需求 | API 面 | 代码面 | 结论 |
|---|---|---|---|---|
| 1 | 图片绘制 | 支持（`drawImage` 三重载；只接受 `ImageBitmap \| PixelMap`，不接受资源 ID/URL 直传；网络图须预下载解码） | 资产齐全（machine/ 28 张、layers/1920s 17 项、paper/ 4 张、keymap 4 份）；但 Canvas＋rawfile 图片的取图路径仓内无用例 | 支持，有条件（取图路径由 P6 探针验，见 §8.1） |
| 2 | 缩放／旋转文字 | 支持（`save/translate/scale/rotate + fillText`；`rotate` 绕原点，须先 `translate` 到旋转中心） | TypebarLayer／LeverLayer 单图绕支点旋转可平移；`rotate` 在 Canvas 上仓内无用例 | 支持（`rotate` 由 P2 验，见 §8.1） |
| 3 | 自定义字体 | **有条件**（`registerFont` 对 `Text` 已证实；对 Canvas 未查到官方说法；`font` 属性文档只列三族名） | 17 款 ttf 随包注册（FontService）；Canvas 上画注册字体仓内无用例 | **须探针（最大风险，P1）** |
| 4 | 命中判定 | 支持（`onTouch` 多点坐标＋JS 命中表） | KeymapModel 命中数学是纯函数（xRatio/yRatio、最近帽心、空格矩形优先），可原样搬 | 支持 |
| 5 | 手势拖拽 | 支持（`onTouch` Move 或 `PanGesture`；与系统边缘返回的竞争待真机验证） | 拨杆拖拽状态机可搬（`leverPanStart/Update/End` 写状态，须随 Index 状态抽取；`dragRatioFor` 是纯函数）；拨杆本身收不到触摸，现由总成 Stack＋覆盖层接 | 支持，有条件（边缘返回由 P3 验） |
| 6 | 60fps 级动画 | **有条件**（无 `requestAnimationFrame`；`@ohos.animator` 长动画当帧时钟；无脏矩形，须离屏分层） | 全仓动画是 `@State`＋`animateTo`＋`setTimeout`／`setInterval`，时序常量可复用，插值与完成回调须手写 | **须探针（次大风险，P2）** |
| 7 | 中文候选栏 | 支持（原生组件叠加） | CandidateBar 与引擎解耦，只产候选词列表；44vp 常驻槽几何约定不变 | 支持 |
| 8 | 系统输入法 | 支持（透明 `TextInput` 叠加＋标准键盘避让 API） | 锚点 TextInput（Index L3713）不显示、只做 IME 绑定；通道全部耦合点是矩形＋事件，不是渲染 | 支持，有条件（键盘避让模式由 P4 验） |
| 9 | 截图／hilog 取证 | 支持（`getComponentSnapshot().get(id, {waitUntilRenderFinished: true})` 有社区实证，追月项目 API 26 模拟器验证；hilog 不受影响） | 识屏验收铁律不变；screenCap 拍 Canvas 内容是机理推断，须真机验证 | 支持，有条件（P5 验：两路截图入画＋盒子落位＋转场跟随；快照失败重试 3 次） |
| 10 | 无障碍读屏 | 有条件（整页只有一个无障碍节点；逐键读屏须另做覆盖层；未查到官方说法） | 现行每个键帽／按钮都是独立 ArkUI 组件，读屏可逐项到达；改 Canvas 后该能力丢失，除非补覆盖层 | **缺省不降级**：透明原生按钮覆盖层全量补（全部键帽＋功能行六键＋TopBar 三图标＋候选栏 chip），P5 加读屏逐键可达判定项 |

### 2.2 代码面难度总览

- 易：FontBar、GuideOverlay、PaperStage 格线部分（已是 Canvas）。
- 中：HomePage、PaperStage、TypebarLayer、LeverLayer、FunctionRow、CandidateBar（进 Canvas，见 §5.1）、AppMenu、AppDialog、内置拼音、页面切换。（TopBar 已决议保留 ArkUI，见 §5.1；图标铁律，不参与难度排序。）
- 难（要做）：CarriageLayers、PhotoKeybed、SpotlightOverlay（进 Canvas，锚点体系重做，见 §5.1）、中文系统输入通道（锚点以透明覆盖层保留，能力边界）、动画总体。
- 保留 ArkUI 的只有能力边界与规则边界三处（TextInput 嵌不进 Canvas、Canvas 不接 IME、SymbolGlyph 无 Canvas 等价物）与范围决定（覆盖层页不在 C 方案范围，见 §5.1）；其余"难"的项一律按"要做、须验"评，不构成保留理由。
- 死代码不计入工作量：`machines/1920s/CarriageLayers.ets`（303 行，零引用）、字杆篮 `if (false && ...)` 死分支（字杆层正常挂载，见 16 号稿 §3.4；2026-11-14 修正，原"字杆层死分支"为误标）、CarriageStrip（四机全走分层件，实际不渲染）。
- 几何派生链与模型均与 ArkUI 渲染无关，但与 bug 有关（R1/R3/R7 在派生函数内）：`measureStage`／`recalcPaperHeight`／`recalcTravel` 不是纯函数（读写十余处 @State），复用清单见 §6——可原样复用的纯几何函数须逐个点名，分支派生入口必须重写（单一变换矩阵＋§7.3 新字号链；`frozenHVp`、isTablet 分支、`57/vp2px` 字号链一律不进 Canvas）。渲染读模型只有 `getLines`／`getCursor`／`getMeta` 三个只读口。Canvas 化不碰数据层。

## §3 验证关一：自定义字体能否进 Canvas（最大风险）

### 3.1 已知事实

- `font.registerFont({ familyName, familySrc })`（`@kit.ArkUI` 的 `font` 模块，API 9+），`familySrc` 可为 `$rawfile('font/xxx.ttf')` 或 `/font/xxx.ttf`；注册时机推荐在 `windowStage.loadContent` 回调中（`onCreate` 注册偶现失败）；重复注册同一字体安全，后续注册被忽略；注册完成后 `Text` 组件用 `.fontFamily(注册名)` 使用。出处：华为开发者论坛「基于Text的自定义字体」、官方字体 API 文档（V5）。
- Canvas 的 `font` 属性语法支持（`'font-style font-weight font-size font-family'`，字号须带单位 px/vp），但官方文档中 `font-family` 只列三种类型：`'sans-serif'`、`'serif'`、`'monospace'`。**没有一处写明注册的自定义字体名可写进 Canvas 的 `font` 字符串。**
- 本轮检索（官方文档、开发者论坛、社区文章）**未找到任何"Canvas + registerFont 成功/失败"的实测记录**。
- 风险是静默的：即使注册名不能被解析也不抛错，只回退到系统字体画出来；`measureText` 的宽度度量也会随字体回退而错——纸面排版（charsPerLine／travelPerChar 全依赖字宽）会整体错位。

### 3.2 探针规格（Phase 0 探针 1，第一个做）

注册 Courier Prime 后，在同一 Canvas 上用 `ctx.font = '24vp CourierPrime'` 与 `ctx.font = '24vp sans-serif'` 各画同一串英文并 `measureText` 比宽度；再截图比对字形（Courier Prime 是等宽衬线体，与系统 sans-serif 字形差异肉眼可辨）。测试串固定为 **`"Hello, World! 0123456789"`**（ASCII、英文、含大小写＋标点＋数字，等宽特征明显；24 字符）。

- **通过标准（做到什么算过）**：两串 `measureText` 宽度差 **≥2vp（绝对值）**；且 `measureText` 的 Courier Prime 宽度与隐藏 `Text` 参照宽度一致（误差 ≤1vp）。参照宽度量法：隐藏 `Text`（opacity 0，同串、同字体 CourierPrime、同字号 24vp、maxLines(1)）＋`onAreaChange` 取宽；该量法本身须先在 `Text`＋Courier Prime 上自证（量出的宽度与 Canvas `measureText` 的 Courier Prime 宽度在同一量级，误差 ≤1vp），否则量法本身不可信。注：仓内 `MeasureUtils.measureText` 看不到注册字体、会回落系统字体，只记录不回写，不可作参照量法。截图字形由用户目视确认（等宽衬线特征可见），不单独作为探针通过标准。
- **不通过的形态**：宽度差 <2vp（回退），或参照宽度对不上。出现任一即判不通过，走 §9 兜底链第一级（混合方案：纸面文字用原生 `Text` 叠加）。

### 3.3 备选路径（按成本递增）

1. 混合方案：纸面文字仍用原生 `Text` 组件叠加在 Canvas 上（字体能力保留在 `Text` 侧，已证实；Canvas 只画机器、键带、纸面底色与装饰）。代价：纸面文字的滚动／位移动画须由 `Text` 组件的位移动画同步，仍有两套坐标要对齐，但比现在全 ArkUI 布局少得多。
2. 离屏 Text 快照成 ImageBitmap 再 `drawImage`：`componentSnapshot` 可把 `Text` 渲染成 PixelMap；但每键落字都要重拍，成本高，只适合静态文本，不适合逐字打字。
3. `@ohos.graphics.drawing` 的 Typeface／Font：Native Drawing 模块另有字体能力，本轮未调研其是否支持自定义字体文件；若前两条都不满足，可另立调研。

## §4 验证关二：60fps 级全屏重绘（次大风险）

### 4.1 已知事实

- ArkTS 声明式范式下**没有 `requestAnimationFrame`**（华为开发者论坛专家回答；VChart 鸿蒙适配 `@visactor/harmony-vchart` 同样用 `@ohos.animator` 的 `animator.create()` 长 duration 1,000,000ms 替代 `requestAnimationFrame` 做动画时钟 `HarmonyTicker`）。个别博客称可直接用 `requestAnimationFrame`，与上述两处冲突，以官方论坛专家说法与 VChart 适配实证为准。
- 帧时钟替代路径：`@ohos.animator`（API 9+），`animator.create({ duration, easing, delay, fill, direction, iterations })` 返回 `AnimatorResult`，`onframe` 回调给进度值（0–1）；约束是须在组件实例创建后使用，不能在 UIAbility 生命周期中调用。`setInterval`／`setTimeout` 可用但不推荐作帧时钟（节律与 vsync 不对齐、受主线程繁忙影响漂移），只适合 700ms 编排这类"关键帧插值"。
- Canvas 没有主动重绘 API、无脏矩形：每次执行绘制命令即更新画面；改一处须重画整张——除非用离屏分层：静态层（机身、键带、纸面底色）预先画到 `OffscreenCanvas` 缓存为 `ImageBitmap`，每帧只重画动态层（纸上移、字车、拨杆、落字）再合成。`OffscreenCanvas` 支持，`transferToImageBitmap / transferFromImageBitmap` 齐全，API 11+ 可传 worker。
- 社区实证两面：正面——Canvas 替代复杂布局做心率图表渲染，帧率从 45FPS 提升至 60FPS，并推荐 `OffscreenCanvas` 预渲染；反面——51CTO 文章指出传统 Canvas 在频繁重绘、复杂动效、大数据量场景下极易帧率抖动、UI 卡顿、主线程阻塞，ArkUI 自 API 11 起开放 `RenderNode + DrawContext` 底层渲染 API 作为高性能替代；另有厂商实战（轻相机应用）为保 60fps 在 HarmonyOS 6 上舍弃 ArkTS Canvas 转 Native Drawing 与 OpenGL ES 纹理混合。官方未查到关于"Canvas 每帧重绘大图"的性能建议、上限或帧率承诺。
- 内存口径（社区文章，非官方）：一张图从加载到显示内存会被占用 3 次（原始数据＋解码后 PixelMap＋GPU 纹理）；一张未压缩 4K 纹理约 64MB。按 RGBA 8bit 估算：2048×975 约 8MB、1536×1147 约 7MB 解码内存；四机图片＋键带全量常驻约数十 MB，在可接受范围，但**不得每帧重建**；优化手段是只解码到显示尺寸（降采样）、缓存解码结果、用完 `PixelMap.release()` 释放。
- Canvas 绘制是主线程 JS 执行：耗时绘制会阻塞 UI 线程（与掉帧风险同一根因）。

### 4.2 探针规格（Phase 0 探针 2）

`@ohos.animator` 长动画驱动，每帧重画"纸上移＋字车＋拨杆"三层（静态层离屏缓存），真机跑 700ms 换行编排，测帧率与主线程占用；另测每键落字只重画动层时的帧率。纸层形态写定（缺省）：纸层为离屏缓存位图、每帧平移合成；若用逐行 `fillText` 重画，须另注明并单独测行数上限（行数越多越贵）。静态层用真机身图＋真键带图经 `drawImage` 绘制（取图路径由 P6 先验）；拨杆／字杆绘制须走 Canvas `rotate`（`rotate` 在 Canvas 上仓内无用例，由本探针验）。

- **通过标准（做到什么算过）**：700ms 换行编排全程帧率 ≥55fps；每键落字帧率 ≥55fps；单帧 draw 耗时 P95 ≤8ms（半帧预算，留输入处理余量）；连续落字 20 字无输入丢失。55fps 依据：60fps 为 vsync 目标，55fps 为底线（留约 9% 测量与单帧抖动余量；持续低于 55fps 即肉眼可感知的卡顿）。
- **采样方法**：逐帧时间戳（`onframe` 回调内记），从完整帧序列算平均／P95／最大帧耗时；draw 开始／结束 hilog 打点，"完成"定义为 draw 调用返回。screenCap 换行中途截图是"尽力取"，抓不到不判 P2 失败（screenCap 单帧约 400–500ms，大于 350ms 级动画窗口，见 §8.1 取证口径）；帧率结论以 hilog 采样为准。
- **不通过的形态**：帧率持续低于 55fps、单帧 draw 耗时 P95 >8ms、或落字间隔内重绘不完。出现即判不通过，走 §9 兜底链（先加粗分层粒度，再升 `RenderNode + DrawContext`，再升 Native Drawing）。

## §5 混合边界：哪些进 Canvas、哪些保留 ArkUI

### 5.1 缺省边界（D3）

| 层 | 归属 | 保留理由类别 | 理由 |
|---|---|---|---|
| 打字机主屏：PaperStage（纸面）、CarriageLayers（滚筒／金属件／篮）、TypebarLayer（字杆）、LeverLayer（拨杆）、PhotoKeybed（键带）、FunctionRow（功能行）、FontBar、HomePage | **进 Canvas** | — | 全部是绘制＋命中＋动画，无原生输入依赖 |
| TopBar | **保留 ArkUI 叠加** | 规则边界 | 三图标全是 SymbolGlyph 系统图标；图标铁律（仓内 AGENTS.md）规定所有图标一律 SymbolGlyph、禁止手搓 Path/SVG/文字符号，Canvas 里画图标等于手搓图标，不许；TopBar 整条保留 ArkUI 叠在 Canvas 上，位置由 Canvas 变换矩阵同步给出 |
| 覆盖层页：ExportPage、DossierDetailPage、DocumentViewPage、PinyinSettingsPage | **保留 ArkUI** | 能力边界（仅输入控件）＋范围决定 | 真正的能力边界只有 TextInput 控件本身（Canvas 无子组件插槽、不能内嵌 TextInput，须以透明覆盖层保留原生 TextInput）；"多 List、文件操作与分享"在 Canvas 里均可做，是难度，不构成保留理由。整页保留 ArkUI 明写为范围决定（"C 方案范围是打字机主屏，覆盖层页不在本方案范围"），不得写成难度结论 |
| GuideOverlay（启动引导底部卡片） | 进 Canvas（易） | — | 纯文字卡片＋遮罩，无动画、无手势之外的逻辑 |
| SpotlightOverlay（页面引导） | **进 Canvas，锚点体系重做** | —（难度，不是保留理由） | 锚点定位体系重做，最小方案四点：① 登记表持有方——GuideCore 的步骤表静态给出 `anchorId → 参考机坐标矩形` 映射，绘制方在绘制时登记各锚点元素的参考机坐标，不再实测节点；② 换算链——登记的参考机坐标经 §1.4 变换矩阵到屏坐标；③ 缺失 fallback（缺省）——锚点缺失时洞口落到纸面中央固定矩形，并在探针／批报告里记一笔，不许静默跳步；④ 绘制责任方——Canvas 内画（四块遮罩＋金边洞口＋气泡＋步骤点＋按钮均由 Canvas 绘制并命中）。锚点方案验证列为 Phase 2 实施设计的必含项。`getRectangleById` 在 Canvas 覆盖层下的行为探针随之作废（作废的是"对一个不再用的 API 的测试"，不是锚点功能本身） |
| 中文系统输入通道（IME Kit） | **透明覆盖层保留** | 能力边界 | 锚点 TextInput（Index L3713）不显示、只做 IME 绑定；通道全部耦合点是矩形＋事件，不是渲染；Canvas 只负责画纸面与光标位置，矩形换算（Canvas 光标 vp→px）按 §1.4 第 5 项另算 |
| 内置拼音 CandidateBar | **进 Canvas** | —（难度，不是保留理由） | chip 绘制＋手写横向滚动＋手写长按（`LongPressGesture`＋600ms 抑制的等价物是触摸时间戳判断，CandidateBar.ets L40–51 已亲核）；候选栏只服务内置拼音通道，不依赖 IME Kit，无原生依赖，无能力边界支撑保留原生叠加 |
| 无障碍逐键读屏 | **透明原生按钮覆盖层全量补（缺省不降级）** | 能力边界 | Canvas 内容不生成无障碍节点；全量可交互元素均须有无障碍节点——四机全部键帽（1920s 43／1930s 58／1950s 49／1960s 52，另有空格条）＋功能行六键＋TopBar 三图标＋候选栏 chip；按钮位置随变换矩阵同步（与 §1.4 同一份定义）。覆盖层做不到全量时，回報用户定夺覆盖范围分几批做，不降级口径不变 |

### 5.2 TopBar 图标问题（已按仓内图标铁律纠正）

TopBar 三图标（文件夹／"?"／汉堡）全部是 SymbolGlyph 系统图标，Canvas 里没有等价物。仓内 AGENTS.md 图标铁律：所有图标一律用系统 Symbol 图标（SymbolGlyph + `$r('sys.symbol.*')`），禁止 emoji、禁止手搓 Path/SVG 图标、禁止 Text 文字符号当图标。**Canvas 里画图标形状等于手搓图标，不许。** 因此 TopBar 整条保留 ArkUI，叠在 Canvas 上方，位置由 Canvas 变换矩阵同步给出（TopBar 高 56vp 不变）。探针阶段不验此项，Phase 2 实施设计时定叠加坐标的同步方式。

### 5.3 边界之外的约束

- **R2 口径（收窄）**：C 绕过的是盒内零件布局，不是 R2 本身——Canvas 盒子本身仍由 ArkUI 布局定位，盒子落位是否受 R2 机制影响是未验证的假设（P5 盒子落位检查验证，见 §8.1）。
- 页面切换"右进左出滑动过渡"在 C 方案下仍可实现（整个 Canvas 盒子整体参与转场，盒内各元素不单独转场）；"纸先动、字车后动"这类盒内编排须由重绘驱动，不能用 ArkUI 转场表达。盒子级转场本身由 P5 转场探针验证（Canvas 盒子右进左出滑动一次，截图确认盒内内容跟随盒子走）。
- Canvas 内容不参与 ArkUI 布局：Canvas 无子节点，高度由组件宽高决定；尺寸变化后内容不会自动缩放重画，须应用监听尺寸变化后重绘（`onAreaChange` 触发点保留，触发后重算变换矩阵并重绘）。
- 沉浸式布局与键盘避让：现行 App 是沉浸式布局（`applyImmersive`），沉浸式下键盘避让须自己处理底部距离；RESIZE 模式下页面压缩 → Canvas 尺寸变化 → 须 `onAreaChange` 触发重绘；OFFSET 模式下页面整体上抬键盘高，Canvas 尺寸不变，盒子顶部（ty 段）被顶出可视区，纸面与键盘的相对位置按 P4 容差判定（打击行必须可见、纸顶与预期值偏差 ≤2vp）。两种模式各测一遍（探针 4）。

## §6 关键机制映射（现行机制 → Canvas 等价物）

| 现行机制 | 现行实现 | Canvas 等价物 | 难度 |
|---|---|---|---|
| 落字字车左移 | `stepCarriageLeft()`：`animateTo` 30ms Linear 改 `carriageOffsetVp`，每字 −travelPerChar，钳制 [−maxTravelVp, 0] | 帧时钟插值改 O 值并重画字车层；时序常量复用 | 中 |
| 删除字车右退 | `stepCarriageRight()`：70ms 弹簧 | 同上，弹簧曲线手写插值 | 中 |
| 换行三段编排 | t=0 拨杆摆 150ms；t=150 纸上滑＋滚筒转 300ms EaseInOut；t=450 字车回位 250ms FastOutSlowIn；t=700 叮声（与回位结束同帧）（注：Index L3189 头注释仍写"三段编排 600ms…t=350…t=600 叮声"，已过期，以代码为准；`recalcPaperHeight` 内注释"纸上滑 200ms"与实际 300ms、`onBackLine` 注释"纸下移 200ms"与实际 300ms 亦不一致，同注） | 同一时序表，帧时钟驱动三层插值；叮声触发点改为帧时钟到 700ms 时的回调 | 中 |
| 退行 | 纸下移 300ms＋O 滑到上一行末尾 250ms；270ms 释放 backBusy；拱 200ms 跟随；无音效（第 13 批 ② 待修，t=0 播 `playCarriageReset()`） | 同上 | 中 |
| 换纸 600ms | 旧纸卷出 300ms＋新纸卷入 300ms；`paperChanging` 守卫；`PAPER_CHANGE_TRACE` 打点 | 同上；打点保留（hilog 不受影响） | 中 |
| 拨杆摆动／回弹 | LeverLayer `@Watch newlineTick`：去程 150ms、回程 200ms；拖拽 `dragRatio` 跟手控角，回 0 时 150ms 弹回 | 帧时钟插值＋`onTouch` Move 跟手；摆角常量复用（平板静止 30°／摆幅 35°，手机 15°／20°） | 中 |
| 哥特拱移动 | `animateArch(duration)` 改 `@State archXVp`（唯一渲染源），目标 `clampedStrikeXVp()` | 帧时钟插值改拱 x 并重画；目标公式复用 | 中 |
| 字杆击打 | 去程 90ms → `onFinish` 回调 `onArrive()`（落字同帧）→ 有队列 20ms 小回退再下一击，无队列 120ms 回 55°；队列上限 20 | **最难改的一处**：`onFinish` 落字同帧没有 Canvas 等价物，须改手写计时器在去程结束帧调 `landHead()`；90／20／120ms 常量复用 | 难 |
| 落字起搏器 | 1920s 由字杆 `onArrive` 驱动（约 110ms／字）；非 1920s `setInterval` 每 120ms 落一字；`armFallback()` 200ms 兜底 | 起搏器逻辑不变（与渲染无关）；`onArrive` 触发源改为帧时钟回调 | 中 |
| 键帽命中 | PhotoKeybed 容器级 `onTouch`＋`Map<触点 id, 帽 id>` 多点状态＋`hitAt`（空格矩形优先、最近帽心）＋120ms 延时清高亮 | **Canvas 层内只用一个 `onTouch`**（D4，见 §6.1）；命中数学纯函数原样搬；多点状态机手写 | 难 |
| 拨杆触摸 | 总成 Stack 手势组＋覆盖层（stageW×0.22）接点按与拖拽；拨杆本身收不到触摸 | 同一 `onTouch` 按区域分发（x > stageW × 0.78 判拨杆区）；拖拽状态机纯函数复用 | 中 |
| 功能行六键 | MetalKey `@State pressed`＋`onTouch` Down／Up 状态机 | 同一 `onTouch` 按区域分发＋手写按下态 | 中 |
| 候选栏点按／长按 | `LongPressGesture`＋`onClick`，600ms 内抑制本次 click 防双提交 | 原生组件叠加保留，不进 Canvas（见 §5.1） | — |
| 几何派生 | 分两列（不是"原样复用"四个字）：**可原样复用的纯几何函数（点名）**——`rollX`／`texOff`／`knobAngle`／`plateLeft`／`baseLeft`／`baseW`／`knobD` 等与分支无关的派生式；`dragRatioFor`／`pulledEnough`（纯函数，`model/LeverAngleCore.ets`）；`KeymapModel.parse`／`hitTest`（static）；时序常量全表。**必须重写的入口**——`measureStage`／`recalcPaperHeight` 的分支派生由单一变换矩阵（§1.4）＋ §7.3 新字号链取代；`frozenHVp`、isTablet 分支、`57/vp2px` 字号链一律不进 Canvas。`measureStage`／`recalcPaperHeight`／`recalcTravel`／`leverPanStart/Update/End` 都不是纯函数（读写十余处 @State，须随 Index 状态抽取，不能无代价搬走）。 | 触发点由 ArkUI `onAreaChange` 改为 Canvas 尺寸变化监听＋重算变换矩阵 | 易（纯函数部分）／中（重写入口） |
| 模型读写 | 渲染读 `getLines`／`getCursor`／`getMeta`；写 `insertText`／`newline`／`clear`／`setCursor` | 不变（模型与 ArkUI 无关） | 易 |

### 6.1 触摸单一路（D4）

**Canvas 层内只用一个 `onTouch`**（点按＋拖拽都在一个回调里按区域分发），**不混用 PanGesture**，可从根本上避开手势竞争（ArkUI 默认规则：父子组件绑定相同手势时竞争，最多一个响应；默认子组件优先，`.priorityGesture` 父优先，`.parallelGesture` 同时响应）。`onTouch` 是原始触摸监听，不参与手势竞争，不应拦截系统手势；但左边缘右滑系统返回是否仍可用，**须真机验证**（探针 3）：若被拦截，把屏幕边缘窄条划为不响应区，或拖拽手势限定纵向。

**触摸路由规则**：覆盖层组件（TopBar／IME 锚点）在 Stack 上层，各自接自己的触摸；Canvas 的 `onTouch` 只接落到 Canvas 区域的触摸。层级与 HitTestMode 保证这一点：IME 锚点透明层置 `HitTestMode.None`，不吃触摸；TopBar 区域在 Canvas 触摸分发中划为不响应区。

### 6.2 动画时钟（D5）

`@ohos.animator` 长动画（duration 1,000,000ms、easing 线性）当帧时钟，每帧 `onframe` 里重绘。时序常量全表复用（落字 30ms、换行 150/300/250/700ms、换纸 300+300ms、拨杆 150/200ms、字杆 90/120ms、拱 90/200/300ms、起搏器 120ms、兜底 200ms）。`animateTo` 立即赋终值的语义不再存在：Canvas 化后观测值就是插值本身，动画取证改靠 hilog 打点（帧率采样＋关键帧打点）与 screenCap 中途截图，不再靠 `@State` 值推断。

## §7 文字缩放口径（定夺项 D1）

这是 C 方案内最关键的未决口径，直接决定手机上的可读性。A 方案被用户否决的理由（手机字号约 13vp，低于现行手机 17vp）若不处理，会原样带进 Canvas。

### 7.1 两口径对照

| 口径 | 做法 | 手机效果 | 平板效果 | 代价 |
|---|---|---|---|---|
| （a）纯等比缩放 | 整机（含纸面文字）统一乘 scale | scale≈0.54，14 字行字号约 13vp（24 × 0.538 ≈ 12.9；现手机是 9 字行 17vp） | 与现行一致 | 可读性退步，用户已否决过同款（A 方案） |
| （b）Canvas 内混合（缺省） | 机器几何等比缩放；纸面文字不跟缩，字号保底 17vp、每行字数随纸宽变（手机 9 字、平板 14 字）；纸顶用现行公式 `paperTop = carriageTop − (marginB + lh + 44 + bandShift) − cursorLine × lh` 耦合（carriageTop 取缩放值、行高取字号值；空纸时末项为 0） | 文字网格与现行手机一致（9 字行 17vp），机器落位是新构图（纸顶约 123vp，整机占屏顶约 541vp、余约 281vp 深底），不等同现行手机 parts | 14 字行 24vp，与现行平板一致 | 纸面文字与机器不再是同一缩放系数，"刚性整体"只对机器几何成立，纸面文字是第二套缩放；两套坐标要对齐（但比现在全 ArkUI 布局少得多） |

### 7.2 缺省与定夺

**缺省走（b）Canvas 内混合**。理由：用户否决 A 的核心理由就是手机可读性，纯缩放把否决理由原样带进来没有意义；B 的数学（机器缩放、文字保底）是用户在 A/B 比较时未否决的备选，把它搬进 Canvas 是 C 方案内最自然的缺省。

**待用户定夺（§12 Q1）**：是否接受"刚性整体只对机器几何成立、纸面文字第二套缩放"这一取舍。若用户坚持整机（含文字）严格同一缩放系数，则走（a），手机可读性退步由用户明确认可；若用户接受（b），则（b）为缺省。评审阶段不替用户定夺，只核两种口径的推导是否自洽。

### 7.3 口径（b）的推导自洽性（评审核查点）

- 字号链：`fontSizeVp = 57 / vp2px` 现行公式是密度的函数（R7），Canvas 内改按纸宽派生：字号保底 17vp，上限 24vp（现行钳制 [17, 26] 的上沿收紧到 24，与平板现行 fs=24 对齐）；行高 `lineHeightVp = fs × (30/17)` 中英共用不变；charsPerLine 按 `floor((Pw − 2×marginH) / charWidthVp)` 重算（marginH 缺省 48；下限 6，`recalcTravel` L1528／`charsPerLine` L2421）；travelPerChar 按 `maxTravel / charsPerLine` 重算（平板 14 字→4.571vp；手机 9 字→7.11vp——以上是参考机坐标值，屏上值须 ×scale，手机屏上约 3.83vp）。
- 纸顶耦合：carriageTop 取缩放值（参考机 carriageTop × scale），行高取字号值，纸顶公式为 `paperTop = carriageTop − (marginB + lh + 44 + bandShift) − cursorLine × lh`（代码 Index L1959–1962，`paperBandBase = marginB + lh + 44 + bandShift`；空纸时末项为 0）。
- maxRows：`floor((Ph − 44 − 20) / lineHeight)`，44＝内容顶、20＝底边距，口径不变。
- **内部一致性检查（取代 v1 的"复现现行 parts ≤1vp"）**：现行手机 carriageTop=300 是 R8 下限的产物，口径（b）刻意去掉下限，复现现行值既不可能也不应作为通过标准。改查缩放后几何的内部一致性，判据三条：① 打击行落在纸面内（纸顶 < strikeLine < 纸底）；② 纸跨过滚筒截断区（纸顶 < carriageTop < 纸底）；③ 字车行程与滚筒钳制不冲突（rollX 全程 ≥ baseLeft）。验算过程如下（scale：平板 1.0、手机 0.538；paperBandBase 平板 121.35＝20+42.35+44+15、手机 94＝20+30+44+0；strikeLine = carriageTop − 20 − lh/2 − strikeShift，平板 strikeShift=15、手机 0）：
  - 平板：carriageTop 403.2、paperTop 281.8、strikeLine 347.0、纸 281.8–910.5、maxRows 13；strikeLine 在纸内（纸顶下 65.2vp）；rollX(0)=103.5、rollX(O=−64)=52.3，均 ≥ baseLeft 45.0。
  - 手机：carriageTop 217.0、paperTop 123.0、strikeLine 182.0、纸 123.0–461.2、maxRows 9；strikeLine 在纸内（纸顶下 59.0vp）；rollX(0)=55.7、rollX(O=−64)=28.1，均 ≥ baseLeft 24.2（均已 ×0.538）。
  - 本检查挂到 P2（探针页打出算出的 paperTop／carriageTop，两台设备上与上列验算值比对，误差 ≤1vp）；Q1 的定夺在该检查通过前一律是"暂定缺省"。

## §8 分阶段：Phase 0 探针 → Phase 1 裁定 → Phase 2 实施设计

### 8.1 Phase 0 探针页（单页、不进主流程）

先做一个最小探针页（单页、不进主流程、不动 Index 主屏、不动第 13 批实施），真机验证以下六项，全部通过再进 Phase 2。探针页是抛弃式验证件，临时进栈、探针结束 revert。

**探针页落点（缺省）**：文件 `entry/src/main/ets/components/CanvasProbePage.ets`（与 ExportPage 等覆盖层页同构的组件，不是新 @Entry 页）；挂载为 Index 覆盖层栈新增条件分支（与 ExportPage L4708 挂载同款写法），入口为 HomePage 临时调试入口（探针结束随分支一并删除）；不动 UIAbility、不动 `module.json5`、不新增路由（`main_pages.json` 只有 `pages/Index`，router 已禁）；"不动 Index 主屏"改写为"只动导航挂载一处（分支＋入口），不动打字机渲染链"，改动清单写进探针实施报告。字体注册：探针页走 Index 启动，已注册字体复用（`FontService.registerBundled` 由 Index 在 L1205 调用），P1 不须自己注册。探针页作为 Index 覆盖层分支，沉浸式走 Index 的 `applyImmersive()`，不另写。

**探针设备范围**：缺省两台真机（MLR-AL10 平板、ADA-AL00U 手机）各跑一遍；折叠模拟器不进 Phase 0（理由是证据层面的：模拟器改尺寸未证实，第 14 批评审已有此结论；模拟器结论只作参考、不作通过依据），不是工作量。

**探针依赖顺序**：P1 独立先行；P6 先于 P2（P6 不通过则 P2 阻塞待重跑，不是失败）；P3／P4／P5 相互独立，可并行；候选栏进 Canvas 后亦然——其渲染不依赖 P1 结论。

| # | 探针 | 规格 | 通过标准（做到什么算过） | 不通过走哪 |
|---|---|---|---|---|
| P1 | 字体 | 注册 Courier Prime，同一 Canvas 上 `'24vp CourierPrime'` 与 `'24vp sans-serif'` 各画测试串 `"Hello, World! 0123456789"` 并 `measureText` 比宽度；隐藏 `Text`（同串、同字体、同字号、maxLines(1)）＋`onAreaChange` 取参照宽度（量法先自证，见 §3.2） | 两串宽度差 ≥2vp（绝对值）；`measureText` 的 Courier Prime 宽度与参照宽度一致（误差 ≤1vp）；截图字形由用户目视确认 | 混合方案（§3.3 第 1 条）；仍不通过则离屏快照或另立 Native Drawing 字体调研 |
| P2 | 帧率 | `@ohos.animator` 长动画驱动，每帧重画"纸上移＋字车＋拨杆"三层（静态层离屏缓存，纸层为离屏缓存位图、每帧平移合成；若逐行 `fillText` 重画须另注明并单独测行数上限）；静态层用真机身图＋真键带图经 `drawImage` 绘制（取图路径由 P6 先验）；拨杆／字杆绘制走 Canvas `rotate`；真机跑 700ms 换行编排＋每键落字；逐帧时间戳采样（`onframe` 回调内记），draw 开始／结束 hilog 打点 | 换行编排全程帧率 ≥55fps；每键落字帧率 ≥55fps；单帧 draw 耗时 P95 ≤8ms；连续落字 20 字无输入丢失；§7.3 内部一致性检查数值对上（探针页打出算出的 paperTop／carriageTop，两台设备上与 §7.3 验算值比对，误差 ≤1vp） | 加粗分层粒度 → `RenderNode + DrawContext` → Native Drawing（§9，第二、三级须另立调研） |
| P3 | 触摸 | `onTouch` 命中 1920s 43 键帽（每帽点按 3 次，记录每次误触的帽与坐标）＋拨杆纵向拖拽＋双指同时按下两帽；左边缘右滑确认系统返回仍可用 | 1920s 43 帽逐帽命中正确（误触率 0）；双指同时按下两帽，两帽均高亮、两字依次入队（与现行 `heldIds` 语义一致）；拖拽跟手（拨杆角与指针位置偏差 ≤5°，延迟 ≤1 帧），过半触发／不到半 150ms 弹回；左边缘右滑仍能返回 | 边缘窄条划为不响应区，或拖拽限定纵向；仍不行则改 PanGesture 方案并重验竞争规则 |
| P4 | 输入 | 透明 `TextInput` 叠加＋系统输入法 attach＋候选栏，键盘弹起时 Canvas 不错位；OFFSET 与 RESIZE 两种模式各测一遍；光标矩形按 §1.4 第 5 项换算 | 两种模式下：打击行必须可见、纸顶与预期值偏差 ≤2vp、键盘与纸面重叠 0vp、候选窗跟随光标、离页键盘不悬留；键盘弹起后纸面底部与键盘顶部间距与预期值偏差 ≤2vp（无 44px 间距坑） | 固定一种避让模式（以 OFFSET 为缺省），另一种标为不支持并写明 |
| P5 | 取证 | `screenCap` 与 `getComponentSnapshot` 各截一次 Canvas 内容；Canvas 盒子右进左出滑动一次（转场探针）；盒子四边与屏边实测距离比对变换矩阵计算值；读屏扫一遍（抽测不少于 10 帽＋功能行六键） | 两路截图均含 Canvas 内容（二值：入画／未入画），两图逐像素比对 mean abs diff ≤5（报告数值）；盒子落位与声明尺寸一致（误差 ≤2vp）；转场时盒内内容跟随盒子走；读屏逐键可达且朗读文本正确 | 截图任一不入画即判取证关不通过，须另找取证路径（hilog 打点＋用户录屏），不许用静态证据冒充已验；快照失败重试 3 次仍失败才判不通过 |
| P6 | 图片取图 | 两条取法各画一张真图上屏：`new ImageBitmap(src)` 直接构造画一张机身图；`resourceManager.getMediaContent`→`ImageSource`→`PixelMap`→`ImageBitmap` 画一张键带图；另留档一条反例——`$rawfile` 动态传参被编译器拒绝的记录 | 两图均正常入画、无拉伸、无错位，hilog 无解码报错；静态分支约束留档 | P2 阻塞（不是失败），待取图路径修通后重跑 |

**探针取证口径**：每项探针附操作前／操作后截图对比（识屏验收铁律）；screenCap 单帧约 400–500ms，大于 350ms 级动画窗口，动画第 0 帧类指标连拍不可靠——帧率类结论以 hilog 采样为准，screenCap 只作中途状态佐证；动画精确验证靠用户录屏。探针截图号段：**1100 起**（第 14 批曾定 1100 池但该批已作废、该号段无截图落盘，Canvas 探针沿用；第 13 批实施仍用 1037 池，两池互不冲突）。其余三机（1930s 58／1950s 49／1960s 52 帽）不在本次探针内（行数与 hitRadius 不同，结论不自动迁移，Phase 2 稿里按机重验）。

**探针不做的事**：不写实施设计、不排工期、不动主屏代码、不碰第 13 批实施、不碰横屏。

### 8.2 Phase 1 可行性裁定

六项探针结果回填本稿 §2 打勾表，裁定三选一：

- **可行**：六项全过，进 Phase 2 实施设计（另立稿，须用户批准）。
- **有条件可行**：某项走兜底链后通过，兜底链的代价（混合文字叠加／RenderNode／Native Drawing／固定避让模式）写入 Phase 2 稿的约束条件。
- **不可行**：兜底链走完仍有项不通过，回報用户重定路线（不硬上，不许把不通过写成通过）。

Q1 的定夺在 §7.3 内部一致性检查（P2 承接）通过前一律是"暂定缺省"。

### 8.3 Phase 2 实施设计（另立稿，不在本稿）

内容：Canvas 组件拆分、绘制分层细节（静态层／动态层划分、离屏缓存粒度）、逐组件迁移顺序、SpotlightOverlay 锚点体系重做（方案验证为必含项，见 §5.1）、IME 矩形换算实施（按 §1.4 第 5 项公式）、无障碍覆盖层全量实施、R2 盒子落位假设的验证结论回填、回滚开关、门图基线重拍计划。须探针全部通过（或有条件通过且兜底链已定）后另立稿、另走 EGM 评审、另经用户批准。

## §9 风险与兜底链

| 风险 | 触发 | 兜底（按成本递增） | 兜底走完仍不通过 |
|---|---|---|---|
| 字体不进 Canvas | P1 不通过 | 混合方案（纸面文字原生 `Text` 叠加）→ 离屏 Text 快照 → Native Drawing 字体另立调研 | 回報用户重定路线 |
| 帧率不达标 | P2 不通过 | 加粗分层粒度（静态层离屏缓存、只重画动层）→ `RenderNode + DrawContext`（API 11+）→ Native Drawing／OpenGL（第二、三级须另立调研，本稿未覆盖） | 回報用户重定路线 |
| 手势冲突（边缘返回被拦） | P3 不通过 | 边缘窄条不响应区／拖拽限定纵向 → 改 PanGesture 方案并重验竞争规则 | 回報用户定夺（是否接受边缘返回受限） |
| 键盘避让错位 | P4 不通过 | 固定 OFFSET 模式，RESIZE 标不支持 | 回報用户定夺 |
| 截图取证不入画 | P5 不通过 | hilog 打点＋用户录屏取证，不许用静态证据冒充已验 | 回報用户定夺取证口径 |
| 无障碍覆盖层做不到全量 | P5 读屏判定项不通过 | 透明原生按钮覆盖层全量补；分批做时先补功能行＋TopBar、键帽后补 | 回報用户定夺覆盖范围分几批做，不降级口径不变 |
| 第 13 批先落地 | 桌面端实施回报后组件清单变化 | 可行性稿的组件清单按新提交重核；探针页独立于第 13 批，互不阻塞 | — |
| R2 之谜 | 不适用 | C 绕过的是盒内布局，不是 R2 本身；保留 ArkUI 的覆盖层页仍活在 ArkUI 布局里，R2 对它们仍然 relevant，不许写成"C 解决了 R2"；若 P5 发现盒子落位错误，R2 须重新立项调查，C 方案不自动成立 | — |

**P1 失败时口径（b）的适用性**：若纸面文字走原生 `Text` 叠加（混合方案），纸顶耦合公式与行宽推导的责任方变了（文字位置由 ArkUI 布局定，不再由 Canvas 坐标定），§7.3 的内部一致性检查仍适用（检查的是几何关系，不是文字由谁画），但纸顶数值的比对口径改为"Canvas 算出的纸顶与 `Text` 实测纸顶偏差 ≤2vp"；口径（b）本身仍成立（文字字号保底 17vp、每行字数随纸宽变），只是文字渲染层换了实现。

## §10 替代方案比较（A/B/C，含调查证据后重评）

| 方案 | 做法 | 调查后的重评 | 结论 |
|---|---|---|---|
| A 整机等比缩放（ArkUI 层） | 参考机 673.7×1006.3，`scale = min(屏宽/673.7, 屏高/1006.3)`，整机统一缩放、余量为深底 | 手机 scale≈0.54、14 字行字号约 13vp（24 × 0.538 ≈ 12.9），低于现行手机 17vp，可读性退步；且仍活在 ArkUI 布局里，R2 之谜不解决 | **用户已否决，不再提** |
| B 混合（ArkUI 层） | 机器几何走 A 的缩放，纸面文字不跟缩（字号保底 17vp、每行字数随纸宽变），纸顶公式耦合 | 数学上就是 §7 口径（b）；但仍活在 ArkUI 布局里，R2 之谜不解决，分支体系仍在 | 未被选中；其文字口径被 C 吸收为缺省（b） |
| Canvas 数学＋ArkUI 渲染（B 与 C 之间） | 派生链搬到固定画布坐标系上算（与 C 同一套缩放数学），渲染仍用 ArkUI 组件绝对定位（`.position()`／`.offset()`） | 同样得到"刚性整体"（位置由单一变换矩阵给出），却保留原生字体、原生触摸、多点手势、`animateTo` 动画、无障碍节点——C 要手写重做的几乎全部东西都不用重写。不选的理由（非难度）：ArkUI 布局的参与方仍是数十个组件盒子（每盒子一次布局机会，R6 四公式问题与 per-component 坐标映射仍在），"由构造保证正确"只对单一 Canvas 盒子成立；绝对定位的盒子仍受 R2 容器机制约束，而 Canvas 盒子的落位可由 P5 的盒子落位检查一次性验证，per-component 落位则须逐件验证——两者在 R2 面前不对称。若 P5 发现 Canvas 盒子同样落位错误，则本行理由失效，须与 R2 一并重议 | 未被选中；用户已拍板 C，比较只为论证完整，不为换路 |
| C Canvas 整页自定义绘制（用户拍板） | 同一套缩放数学搬到渲染层，一个变换矩阵落位；触摸、动画手写；像素级可控，绕过 ArkUI 布局行为 | API 面基本可行（两验证关）、代码面难度已分级；代价是重写渲染层，工作量最大；字体与帧率须探针先行 | **本稿方案** |
| 纯 flex／断点栅格 | 断点分桶 | 断点就是换种分桶，不算新办法 | 决策时已排除，不再比较 |
| RenderNode + DrawContext／Native Drawing | 底层渲染 API／原生绘图 | 不是 C 的替代，是 C 的兜底链（帧率不达标时逐级升级） | 按 §9 排列 |

## §11 验收口径（做到什么算过）

本稿是可行性方案，验收分两层：

**本稿验收（评审＋用户批准）**：

- 两路调查结论逐项有出处或明写"未查到官方说法"，无编造 API（已满足：API 报告每项附出处链接或明写未查到；行号引用均以 `f51d1ad` 为准，本次评审抽核关键项）。
- 字体与帧率两关写成探针而非已证实结论（已满足：§3、§4、§8.1 P1/P2）。
- 混合边界按能力边界／难度分级如实写明（已满足：§5、§6）。
- 文字缩放口径单列为定夺项，不默认纯缩放（已满足：§7）。
- R2 写成盒内布局绕过而非解决（已满足：§0、§5.3、§8.3、§9）。
- 截图号段 1100 起与第 13 批 1037 池协调（已满足：§8.1）。
- 变换规则（scale 公式／平移／上限／余量／光标矩形换算）已定义（已满足：§1.4）。
- 探针页落点与启动方式已定义（已满足：§8.1）。
- 图片取图路径有探针覆盖（P6 已加，见 §8.1）。
- 无障碍缺省不降级已定夺（已满足：§5.1、§8.1 P5、§9、§12 Q3）。
- 提示词铁律适用范围：本稿批准后不直接产生实施提示词；实施提示词待 Phase 2 实施设计稿批准后另写（遵守提示词铁律：显式 push＋验真、无硬门槛）。

**探针验收（Phase 0，另行报告）**：按 §8.1 六项探针的通过标准逐项判定，每项附操作前／操作后截图对比与 hilog 采样；六项全过（或有条件通过且兜底链已定）才进 Phase 2。探针报告格式沿用批报告铁律：开头写"本批新证据改了上一批哪条结论、为什么改"。

## §12 待用户定夺

- **Q1（几何缺省口径一并定夺，D1）**：文字缩放——接受（b）Canvas 内混合（机器几何缩放、纸面文字保底 17vp、每行字数随纸宽变；"刚性整体"只对机器几何成立）为缺省，还是坚持（a）纯等比缩放（整机含文字同一缩放系数，手机可读性退步由用户明确认可）？变换规则（§1.4 缺省：scale 上限 1.0、水平居中、垂直顶对齐留 topInset、余量深底纯色）是否一并接受？Q1 的定夺在 §7.3 内部一致性检查（P2 承接）通过前一律是"暂定缺省"。
- **Q2（探针页立项）**：是否同意先做 Phase 0 最小探针页（文件 `entry/src/main/ets/components/CanvasProbePage.ets`，Index 覆盖层栈新增条件分支挂载，HomePage 临时调试入口，探针结束随分支一并删除、经一次回归门；六项探针全部通过再立项 Phase 2）？探针页本身须桌面端在 TX_2 上建页、装机、真机跑，沙箱无法独立验证真机数值与截图。
- **Q3（无障碍覆盖层分几批做，已定夺不降级）**：无障碍默认不降级已由用户 2026-11-13 定夺。问的是实现排期：覆盖层一次全量（缺省：四机全部键帽＋功能行六键＋TopBar 三图标＋候选栏 chip），还是分批做（先补功能行＋TopBar、键帽后补——分批不降级，只是排期）？
- **Q4（截图号段）**：Canvas 探针截图用 1100 池（第 14 批曾定、未落盘），是否同意？
- **Q5（desk／折叠半开态 scope）**：接受缺省"C 只覆盖非折叠竖屏；desk 态另立处理（仍走现行分支，另立设计），不在本稿 scope 内"吗？还是要求 desk 态纳入 C（则 §1.3 须补 desk 参考几何与折痕约束，探针须加 desk 专项）？

## 附录 A：逐组件 Canvas 化难度表——结论引用＋差异说明

全文表留在代码面调查报告 §8，不复制。本附录只列与 §6 不同的 verdict（其余行与调查报告一致）：

| 组件 | verdict（本稿） | 与调查报告的差异 |
|---|---|---|
| TopBar | 保留 ArkUI（§5.2） | 调查报告 verdict"中"；本稿按图标铁律定案为保留 ArkUI |
| SpotlightOverlay | 难（要做，进 Canvas） | 调查报告 verdict"难"；本稿按用户早期开发口径改入 Canvas，锚点体系重做（最小方案见 §5.1） |
| CandidateBar | 中（进 Canvas） | 调查报告 verdict"中"、缺省保留原生叠加；本稿按能力边界标准改入 Canvas（无能力边界支撑保留） |
| ExportPage／DossierDetailPage／DocumentViewPage／PinyinSettingsPage | 保留 ArkUI（范围决定） | 调查报告 verdict"难，建议保留 ArkUI"；本稿理由重写为 TextInput 能力边界＋范围决定（见 §5.1） |
| 中文系统输入通道 | 难（锚点透明覆盖层保留） | 与调查报告一致；矩形换算按 §1.4 第 5 项公式 |
| 内置拼音（PinyinEngine＋候选栏） | 中（进 Canvas） | 调查报告 verdict"中"、缺省保留原生叠加；本稿改入 Canvas（见 §5.1） |

## 附录 B：API 能力打勾总表（API 面调查 §8）

| # | 需求 | 结论 | 条件／备注 |
|---|---|---|---|
| 1 | 图片绘制 | 支持 | `drawImage` 三重载；本地资源直接，网络图片须预下载解码；`ImageBitmap` 源默认 vp 坐标 |
| 2 | 缩放／旋转文字 | 支持 | `save/translate/scale/rotate + fillText`；`rotate` 绕原点，须先 `translate` 到旋转中心再转；字号单位 px/vp 须带单位 |
| 3 | 自定义字体 | 有条件 | `registerFont` 对 `Text` 已证实；对 Canvas 未查到官方说法，须探针实测；若不生效走混合方案 |
| 4 | 命中判定 | 支持 | `onTouch` 多点坐标＋JS 侧自有命中表；框架不提供"点中哪个绘制元素"的反查 |
| 5 | 手势拖拽 | 支持 | `onTouch` Move 跟手或 `PanGesture`；与系统边缘返回手势的竞争待真机验证 |
| 6 | 60fps 级动画 | 有条件 | 无 `requestAnimationFrame`，用 `@ohos.animator` 长动画当帧时钟；无脏矩形，须离屏分层、只重画动层；全屏全量重绘掉帧时兜底 `RenderNode + DrawContext`（API 11+）或 Native Drawing；须真机测帧 |
| 7 | 中文候选栏 | 支持 | CandidateBar 进 Canvas（chip 绘制＋手写横向滚动＋手写长按）；44vp 占位不变 |
| 8 | 系统输入法 | 支持 | 透明 `TextInput` 叠加＋attach，输入通道不变；键盘避让用 `setKeyboardAvoidMode`／`keyboardHeightChange` 监听等标准 API；RESIZE 模式下 Canvas 尺寸变化须重绘 |
| 9 | 图片取图路径 | 支持，有条件 | 两条取法（`new ImageBitmap(src)`；resourceManager→ImageSource→PixelMap→ImageBitmap）由 P6 探针验；`$rawfile` 只接受编译期字符串常量，须按 MachineKind 静态分支 |
| 10 | 目标 SDK 版本 | 已证实 | App 目标 SDK 26.0.0（`targetSdkVersion = compatibleSdkVersion = 26.0.0`，根 `build-profile.json5`）；API 11+（OffscreenCanvas 传 worker、`RenderNode + DrawContext`）与 API 12+（`LengthMetricsUnit`）均在目标 SDK 范围内，可用 |

## 附录 C：证据索引

- 代码面调查：`~/workspace/egm-work/canvas-invest-codebase.md`（54KB，8 节＋未证实项，105 处行号引用，基准 `f51d1ad`）
- API 面调查：`~/workspace/egm-work/canvas-invest-api.md`（约 33KB，10 节，适用版本 API 12 为主；官方自定义字体文档本次直接抓取超时未读到正文，相关内容由论坛专家回答佐证；华为云手势博客本次抓取失败，内容引用搜索结果摘要）
- 概念 brief：`~/workspace/egm-work/canvas-concepts-brief.md`
- 根因调查：第 14 批 `~/workspace/egm-work/layout-root-cause.md`（R1–R11）、评审 `layout-review-{zoomout,codebase,readiness}.md`、resolve `layout-resolve.md`
- 否决记录：第 14 批设计稿 `docs/designs/14-底层布局适配-增量设计.md`（v2 草稿，48,540 字节，本地未提交，已作废）
- 现行基线：平板 1026／1034／1035／1036、手机 1027／1017／1018／1019（均经用户 2026-11-12 目视确认）；第 13 批实施截图 1037 起；Canvas 探针截图 1100 起（本稿 §8.1）
- 仓内 AGENTS.md：已全文通读（图标铁律、识屏验收铁律、动画取证边界、页面切换、中文输入铁律、覆盖层层级均已纳入本稿）
