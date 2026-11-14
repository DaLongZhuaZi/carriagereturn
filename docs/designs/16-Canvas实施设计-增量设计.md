# 16-Canvas 实施设计：整页自定义绘制迁移（增量设计）

- 状态：**已批准（用户 2026-11-14 批准，按缺省执行；§12 Q1–Q7 全缺省；15 号稿 §6 同款误标一句同步修正）**
- 日期：2026-11-14
- 依据：`docs/designs/15-Canvas渲染-可行性方案.md` v2（已批准，`5d89d41`）；探针报告 `docs/evidence/canvas-probe-20261113.md`（Phase 0，17 节）；Phase 1 裁定：**有条件可行**（探针报告结论节；桌面端自检记录 `c3d74ea`）
- 基准：**行号引用以 `f51d1ad` 为准**（除非注明"当前"）；关键锚点按 2026-11-14 当前代码亲核（HEAD `c3d74ea`，`Index.ets` 5060 行），对照见附录 A
- 性质：**实施设计，不是可行性论证**。本稿回答"Canvas 主屏怎么拆、按什么顺序迁、每步做到什么算过"；"C 能不能做"已由 15 号稿＋探针回答，不在本稿重论证
- 范围：打字机主屏进 Canvas；desk 态另立处理（15 号稿 §12 Q5 已定缺省）；横屏不在范围

## §0 本批新证据改了上一批哪条结论、为什么改

上一批＝15 号稿 v2。本批新证据（Phase 0 探针全量结果，2026-11-13–14）改了四条判断，另有两条新增口径：

1. **"自定义字体能否进 Canvas 未知"——改了，已证实可用**。P1 双机通过：平板 `wC=345.38、wS=287.64、diff=57.74vp（≥2）、ref=345.68、refDelta=0.31vp（≤1）`；手机 `wC=345.38、wS=282.02、diff=63.35vp、ref=345.48、refDelta=0.11vp`。测试串固定 `"Hello, World! 0123456789"`。官方 SDK 文档侧补：Canvas `font` 文档注明「Starting from API 20, this API is used to set registered custom fonts」，与实测一致。**用户 2026-11-14 亲验 P1 内容逐项试过、无问题**（用户原话），与探针结论互相印证。后果：纸面文字直接走 Canvas `fillText`＋注册字体，不走 15 号稿 §3.3 的混合方案；混合方案降为兜底（字体回归时才启用，见 §9）。
2. **"60fps 级全屏重绘未知"——改了，实测 120fps 级达标**。P2 双机通过：平板换行 `121.3fps`（frames=89、totalMs=709）、落字 `120.3fps`（frames=314、typed=20/20）、单帧 draw `avg 0.78/0.90ms、p95 2.00ms、max 2.00ms`；手机换行 `122.0fps`（frames=91）、落字 `120.5fps`（frames=314、typed=20/20）、`p95Draw 1.00ms`。§7.3 内部一致性数值对上：平板 `paperTop=281.84（d 0.04）、carriageTop=403.19（d 0.01）、strikeLine=347.01`；手机 `paperTop=123.05（d 0.05）、carriageTop=217.05（d 0.05)、strikeLine=182.05`，与 §7.3 验算值（平板 281.8/403.2/347.0、手机 123.0/217.0/182.0）误差均 ≤1vp。后果：绘制分层按探针形态定稿（静态层离屏缓存、纸层离屏位图平移合成、动层每帧重画），见 §3.1；Q1 口径（b）由"暂定缺省"转为缺省（15 号稿 §8.2 的暂定条件已满足）。
3. **"$rawfile 只接受编译期字符串常量"——改了，不是编译器硬约束，降为约定**。P6 实测 SDK 26：`$rawfile(this.rawfileDynPath())`（方法返回字符串）**编译通过且运行时正确渲染**（截图 `1113_probe_dynamic_rawfile.png`，机身图完整显示；构建日志 `p6_rawfile_negative_build.log` BUILD SUCCESSFUL，无 rawfile 报错）。P6 要求的"反例"在本 SDK 上**无法产生**。后果：Phase 2 **缺省仍用静态分支**，理由三条：① 仓内现行实现全部为静态字面量，12 处动态用法是历史遗留、第 13 批已定"静态分支优先"口径，一致性优先；② 静态分支让资源引用在编译期可审计，与机型蓝图零引用原则配套；③ 动态传参的运行时行为只在 SDK 26 单点验证过，未覆盖全部机型×纸种×字体路径，Phase 2 不扩大验证面。是否保留该约定由用户在 §12 Q3 定夺。
4. **P3/P4/P5 的遗留项——改了，由"探针未验"转为 Phase 2 条件**。不是失败、不是通过，是 Phase 2 必须承接并验收的清单，见 §1（C1–C4）。其中 P5 读屏判定在探针报告 §十七由"不通过"改为"按无障碍树文本判为通过"——这是桌面端自改的判定口径变化（从"朗读文本正确须人工听"改为"树文本即朗读文本"），本稿不替用户放行，仍按"实际听感待用户抽测"列为条件 C4。
5. **新增口径（用户 2026-11-14 定）**：之后尽量只在手机（ADA-AL00U）一台设备上测试，有需要时才到其他设备。本稿验证口径一律缺省手机，平板只在 §5 逐项注明处补验。
6. **新增事实（第 13 批实施落地）**：15 号稿基准 `f51d1ad` 之后，第 13 批 ⑥ 导出等提交已落地，`Index.ets` 由 4911 行涨到 5060 行（2026-11-14 核），行号漂移见附录 A；基线候选 1083（平板）／1087（手机）已拍、待批准人确认，旧 1026／1027 作废（AGENTS.md 基线标定表）；探针截图用到 1132。15 号稿的行号引用仍以 `f51d1ad` 为准，实施时以当前代码为准。

## §1 Phase 1 条件清单（承接方式与验收标准）

Phase 1 裁定是"有条件可行"，条件即下表。**每项都写清由哪个子批承接、在哪验收、做到什么算过**；条件未清不等于子批失败——单项证据抓不到时用替代证据继续做，并在批报告里写明不符点、原因、替代证据（见 §8）。

| # | 条件（来源） | 承接子批 | 承接方式 | 验收标准（做到什么算过） |
|---|---|---|---|---|
| C1 | P3 左边缘返回未验（探针报告 §十五／§十七） | 2B | 设计上先不做边缘窄条（`onTouch` 机理上不参与手势竞争、不应拦截系统手势）；验收时用户真机手动左边缘右滑验证 | 用户在手机真机上手势左边缘右滑，系统返回正常触发、App 回到上一页（或退出到主页，视栈顶而定）；连续 3 次均成功。若被拦截，fallback＝左边缘窄条（宽度不预设，2B 从 4vp 起逐档试，实测最小有效宽度写进批报告）划为不响应区，重验 3 次 |
| C2 | 拨杆过半触发／不到半 150ms 回弹语义未验（探针报告 §十五） | 2B | 探针只验了角度映射（`dAngle=0.00`）与绘制跟手；产品语义（`pulledEnough` ≥0.5 换行、不到半 150ms 弹回静止角）由 2B 实现并验收 | 过半拖拽松手触发换行（拨杆摆动＋纸上滑＋字车回位＋叮声完整编排）；不到半松手 150ms 内弹回静止角、无换行、无落字；各 3 次。阈值 `LEVER_COMMIT_RATIO=0.5`（`model/LeverAngleCore.ets`，2026-11-14 亲核） |
| C3 | P4 三项未验：候选窗跟随光标／离页键盘不悬留／真实纸面底部与键盘顶部间距 ≤2vp（探针报告 P4 节／§十三） | 2B（候选跟随、离页）、2A＋2B（纸面间距） | 探针页不承载候选栏与真实纸面，Phase 2 版式验证：候选栏进 Canvas 后实测跟随；离页流程（进覆盖层页再回）实测键盘收起；纸面几何在 2A 静态版式＋2B 键盘弹起两种状态下实测；纸面间距的预期值由 2A 静态版式时实测并记录（纸面底边与键盘顶边的参考机坐标差值） | 候选窗跟随光标（候选窗左缘 x 与光标矩形左缘 x 之差，同为参考机坐标换算后，≤2vp；候选栏 44vp 常驻槽内）；离页后系统键盘不悬留（回到打字机页时键盘已收起、纸面位置复原）；键盘弹起后纸面底部与键盘顶部间距与 2A 实测预期值偏差 ≤2vp（无 44px 间距坑；纸底屏坐标 = (paperTop + Ph) × s + ty，与键盘顶实测值比对）。RESIZE 与 OFFSET 两种模式各测一遍 |
| C4 | P5 读屏实际听感待用户抽测（探针报告 §九／§十六／§十七） | 2C | 无障碍树 49 节点文本已验（`a11y_cap_0..42`、`a11y_fn_0..5`，`text` 为 `keycap <label>`／`function <label>`，dump `p5_a11y_nodes_attr_dump.json`）；实际听感属用户参与项，不由 dump 冒充 | 用户开一次系统读屏，抽测不少于 10 帽＋功能行六键，逐键朗读文本与帽面／键名一致；不一致的逐项记入批报告并修文本，不降级、不放行 |
| C5 | 三机按机重验（15 号稿 §8.1：探针只验 1920s，1930s 58／1950s 49／1960s 52 帽结论不自动迁移） | 2B（命中）、2A（静态像素） | 每机在手机上切机后跑：静态像素门图＋逐帽命中抽测（每机不少于 20 帽×1 次，误触 0；抽样依据：命中数学 `KeymapModel.parse`／`hitTest` 是机型无关的纯函数，逐机差异只在 keymap 数据，故三机抽测而非全量；1920s 全量 43 帽×3＝129/129 是基准）＋拨杆拖拽 1 次 | 三机静态像素与各自基线比对（平板基线待确认时，先用同机型手机基线（1920s 用 1087，三机用 1017／1018／1019，见 R-S2 的 fallback）＋连拍静止性，见 §5）；命中抽测 0 误触；拨杆角偏差 ≤5° |
| C6 | 手机无线 hdc 批量注入不稳定（探针报告 §十二／§十四：长会话批量命令报 `[Fail]Not match target founded, check connect-key please`，单发稳定；USB 稳定，129/129） | 2A–2C（验证方法） | Phase 2 手机批量注入（逐帽点按、连续落字）**缺省走 USB hdc**；无线只作单发／少量操作。用户 2026-11-14 已接 USB（`2UCUT24724009680 USB Connected`，探针 §十五） | 批量注入连续 129 点无 `Not match target` 报错；若无线通道恢复稳定，批报告里写明并可改回无线，不写死 |
| C7 | 手机探针页曾整屏空暗（截图 `1126_phone_probe_blank.png`：节点在、像素空，原因未查明；重启／重连后恢复） | 2A（回归检查项） | 列为未解释渲染异常，不许掩盖：2A 静态渲染验收时加一项"连续 3 次冷启动＋切机，每次截图与同机型连拍前一帧四区 0.00% 且整图平均亮度 ≥10（/255）"；复现即报（附 dump＋截图＋hilog），由桌面端查因，不判为"偶发"放行 | 3 次冷启动每次截图与同机型连拍前一帧四区 0.00% 且整图平均亮度 ≥10（/255，避免全黑空暗）；若复现空暗，批报告如实记并停下查因（只停 2A 的挂载切换，不停 2B/2C 的离线工作）。亮度阈值 10 为初值，2A 首轮实测后若误报／漏报，在批报告里校准并写明实测值 |

## §2 迁移范围与分批

### 2.1 范围表（与 15 号稿 §5.1 的关系逐行注明）

| 层／组件 | 归属 | 与 15 号稿 §5.1 的关系 | 理由（能力边界／规则边界／难度／范围） |
|---|---|---|---|
| 打字机主屏 Canvas 本体：PaperStage 纸面、CarriageLayers 滚筒／金属件／篮、TypebarLayer 字杆（视觉缺省不画字杆摆动，见 §3.4）、LeverLayer 拨杆、PhotoKeybed 键带、FunctionRow 功能行、FontBar 字体条、PaperSheet 格线（格线在 L1 新画，`components/PaperSheet.ets` 未挂载，只作绘制参考） | **进 Canvas** | 一致 | 全部是绘制＋命中＋动画，无原生输入依赖 |
| CandidateBar 候选栏 | **进 Canvas** | 一致（§5.1 已定） | chip 绘制＋手写横向滚动＋手写长按；只服务内置拼音，不依赖 IME Kit，无原生依赖 |
| GuideOverlay 启动引导底部卡片 | **不迁移（未挂载）** | 与 §5.1 不同：§5.1 写的是旧底部卡片；现行代码里 `GuideOverlay` 只剩 import（`Index.ets` 当前 L61）与注释，**无挂载**——第 13 批 ④ 已把启动引导换成全屏 5 页 `OnboardingGuide.ets`，旧卡片只留作回滚对照（死代码，不计入工作量） | — |
| OnboardingGuide 启动引导（全屏 5 页，第 13 批 ④） | **保留 ArkUI（另议，见 §12 Q5）** | 与 §5.1 不同：§5.1 写的是旧底部卡片 GuideOverlay，第 13 批 ④ 已把它换成全屏 5 页新组件（`Index.ets` 当前 L5013–5014 挂载，`GuideOverlay.ets` 只留作回滚对照） | 5 页含 SymbolGlyph 图标（P1–P4 已证实符号，P5 待选），Canvas 里画图标等于手搓图标，图标铁律不许；引导页只在首次出现，不参与打字机主屏布局，与 R1–R11 无关。本稿建议保留 ArkUI，由用户在 §12 Q5 定夺 |
| HomePage 主页 | **保留 ArkUI（另议，见 §12 Q5）** | 与 §5.1 不同：§5.1 把 HomePage 列进"打字机主屏进 Canvas"一行；本稿建议保留 | HomePage 是独立页面（常驻挂载、栈顶非 typewriter 时才可见），不参与打字机主屏布局；C 方案范围是打字机主屏，HomePage 的错位不在 R1–R11 之内；无探针覆盖（探针只画打字机主屏）。若用户坚持进 Canvas，须另加探针，不在本批 |
| TopBar | **保留 ArkUI 叠加** | 一致（§5.2） | 规则边界：三图标全是 SymbolGlyph，Canvas 里画图标等于手搓图标，不许；整条保留 ArkUI 叠在 Canvas 上，位置由变换矩阵同步（x=tx、y=ty、宽=673.7×s，15 号稿 §1.4 第 6 项），高 56vp 不变 |
| 覆盖层页：ExportPage、DossierDetailPage、DocumentViewPage、PinyinSettingsPage（＋DossierPage、PaperCustomPage、CustomizePage、TrashPage、SettingsPage、FontManagerPage、CollectionPage、CollectionDetailPage） | **保留 ArkUI** | 一致 | 能力边界（仅 TextInput 控件本身）＋范围决定（C 方案范围是打字机主屏，覆盖层页不在本方案范围）；"多 List、文件操作与分享"是难度，不构成保留理由 |
| 中文系统输入通道（IME Kit） | **透明覆盖层保留** | 一致 | 能力边界：锚点 TextInput（当前 `Index.ets` L3843 一带，f51d1ad L3713）不显示、只做 IME 绑定；通道耦合点是矩形＋事件，不是渲染；矩形换算见 §3.6 |
| AppMenu 下拉菜单、AppDialog 弹窗壳 | 进 Canvas（2C，壳）；内含 TextInput 的弹窗（新建卷宗／改名）保留原生输入层 | 与调查报告 §8 一致（"中"，160ms 淡入可 Canvas 画） | 菜单锚定触发按钮下方的位置由变换矩阵算出，不读 ArkUI 布局坐标；遮罩与卡片分开绘制、分开命中：点遮罩关、点卡片不关（AGENTS.md 弹窗教训的 Canvas 等价写法） |
| SpotlightOverlay 页面引导 | **进 Canvas，锚点体系重做**（2C） | 一致（§5.1 最小方案四点） | 难度，不是保留理由；实现见 §3.8 |
| 无障碍逐键读屏 | **透明原生按钮覆盖层全量补**（2C，缺省不降级） | 一致（§5.1 全量清单） | 能力边界：Canvas 内容不生成无障碍节点；清单见 §3.9 |

### 2.2 子批切分（3 个子批，顺序 2A → 2B → 2C）

**切法原则**：先立"画得对"（静态像素可门图验收，不动交互），再立"动得对"（交互＋动画，最难、条件 C1–C3 在此验收），最后立"用得对"（引导＋无障碍＋基线，收尾可独立回滚）。每子批可独立编译、独立装机、独立验收、独立回滚；前一子批失败不阻塞后一子批的离线编写与单测（代码可先行写出），但后一子批的**验收** gated 于前一子批验收通过：2B 的触摸／版式验收须在 2A-3（变换矩阵）通过后才有效；2C 的锚点验收须在 2B 版式定稿后才有效。挂载切换只阻塞于本子批验收。

| 子批 | 内容 | 挂载状态 | 回滚粒度 |
|---|---|---|---|
| **2A 骨架＋静态层** | 新组件 `CanvasTypewriter.ets`（Canvas 盒子＋变换矩阵＋动画时钟骨架）；`model/CanvasGeometry.ets`（纯函数模块，见 §3.2）；绘制分层 L0–L3（§3.1）；静态整机四机（滚筒／金属件／篮、纸纹、纸面静态文字、键带图、功能行、字体条）＋纸面静态文字（`fillText`＋注册字体，P1 已验）；TopBar 位置同步（.position() 由变换矩阵算出）；IME 锚点透明层挂载（矩形换算先行，不接事件）；探针残留文件处置（删 `CanvasProbePage.ets`，见 §2.3）；回滚开关 `canvas.enabled`（缺省 false，见 §6） | 不切主屏：Canvas 组件挂在 Index 覆盖层栈临时分支＋HomePage 调试入口（与探针页同款写法，2B 切换时删除）；主屏仍走 ArkUI | 只删 2A 新增文件＋分支，ArkUI 主屏零改动 |
| **2B 交互＋动画＋挂载切换** | 触摸单一路（§3.5：键帽命中、多点、拨杆拖拽＋C2 语义、功能行六键、FontBar、候选栏 chip 命中）；动画时钟全量编排（§3.3：落字／换行／退行／换纸／字杆 landHead／拱／拨杆摆动）；CandidateBar 进 Canvas（§3.7）；IME 事件接线（attach／updateCursorRect／detach，矩形换算 §3.6）；挂载切换：`canvas.enabled` 缺省 true，主屏走 Canvas；旧 ArkUI 主屏代码保留作回滚（至少保留一批，删除另立项）；条件 C1／C2／C3／C5／C6 在此验收 | 主屏走 Canvas（flag 开）；ArkUI 主屏保留 | flag 关回 ArkUI；2B 代码整体 revert 不影响 2A 静态层 |
| **2C 引导＋无障碍＋基线收尾** | SpotlightOverlay 锚点体系重做（§3.8，最小方案四点）；OnboardingGuide 按 §12 Q5 结果办（GuideOverlay 旧卡片未挂载、不迁移）；AppMenu／AppDialog 壳进 Canvas；无障碍透明原生按钮覆盖层全量（§3.9，条件 C4 在此验收）；门图基线重拍（1083／1087 确认，见 §5）；清理：删 2A 临时调试入口；回滚开关缺省 true 保持；旧 ArkUI 主屏删除与否另立项（本批不删） | 主屏走 Canvas；引导与无障碍全量 | 任一项失败只回滚该项（锚点／无障碍可独立关），不回滚 2B |

**为什么这样切（不是按组件切）**：按组件切（先纸面、再键带、再滚筒）会在很长一段时间内"半个 Canvas＋半个 ArkUI"同屏，像素与触摸分属两套坐标，门图无法判定、触摸路由无法验收。按"静态→交互→收尾"切，每子批结束时都是一个完整可验收的状态：2A 结束时静态整机可门图比对；2B 结束时打字全流程可用；2C 结束时引导与读屏全量。2A 的工作量最小、风险最低，先拿到"画得对"的证据再投最难的交互部分，符合探针先行的同一逻辑。

### 2.3 探针残留文件处置

`entry/src/main/ets/components/CanvasProbePage.ets`（48KB，2026-11-14 06:05）在探针 revert 时只删了挂载分支与入口，文件本身仍在仓内、当前零引用（2026-11-14 核：`grep -rln CanvasProbePage` 只剩自身）。2A 缺省：**删除该文件**，正式实现另起新文件 `entry/src/main/ets/components/CanvasTypewriter.ets`。理由：探针页是抛弃式验证件（含探针面板、P1–P6 开关、取证适配等临时逻辑），不是产品代码；把它当脚手架改容易把探针开关与取证适配带进产品。删除前由桌面端确认其内无可复用的绘制函数值得保留——候选：P2 分层绘制、animator 骨架、`drawImage` 取图三处；有则先抽成 `CanvasGeometry`／绘制 helper 再删，确认后在 2A 批报告写明"复用／不复用"结论与抽取清单。

## §3 关键机制实现要点

### 3.1 绘制分层（L0–L3；分层粒度以 P2 实测为依据）

探针 P2 的形态即定稿形态：静态层离屏缓存、纸层离屏位图每帧平移合成、动层每帧重画。P2 实测（平板换行 121.3fps／落字 120.3fps、单帧 draw p95 2.00ms；手机 122.0／120.5fps、p95 1.00ms）是分层粒度的证据——该形态在两台真机上都有 4 倍以上的帧率余量（55fps 底线）与 4–8 倍的单帧耗时余量（P95 ≤8ms）。

| 层 | 内容 | 何时重画 | 缓存粒度 |
|---|---|---|---|
| L0 底色／余量 | 整屏深底纯色（色值沿用 `#241c16` 一带，2A 定具体值并截图确认）；余量区（scale<1 时机器外的屏区域）同色铺满 | 尺寸变化时 | 无缓存，每帧填底色 |
| L1 静态层（离屏缓存 `ImageBitmap`） | 机身图、键带图、底座／沟槽／铭牌、纸纹底色、纸面装饰（页眉双细线、稿纸竖格、红格边距线） | 只在换机／换纸／换字体时重建；平时不动 | 按机型一张（1920s／1930s／1950s／1960s 各一）＋按纸种一张纸纹层；**缺省只缓存当前机型＋当前纸种**，切换时重建（换机／换纸本就是低频操作）。内存口径（API 调查社区文章，非官方）：2048×975 约 8MB、1536×1147 约 7MB 解码内存；四机全量常驻约数十 MB，缺省不全量常驻 |
| L2 纸层（离屏位图，每帧平移合成） | 整张纸（含行文字、页码 `n / m`、引导文案、光标三角）画到离屏 Canvas／`OffscreenCanvas`，合成时按纸顶偏移平移 | 落字（新字出现）、换行（纸上滑）、退行（纸下移）、换纸（卷出／卷入）时重画并平移；静止时不动 | 一张纸层位图（参考机坐标，Pw×Ph）；行数 ≤13；`fillText` 重画粒度：**只重画变化行**（P2 只打了 20 字约 1.5 行，未测 13 行满纸，"成本已由 P2 覆盖"不成立；若实现为整张重画，须在 2B-1 补测满纸用例：纸面写满 13 行后敲一字，draw P95 ≤8.3ms，否则改只重画变化行） |
| L3 动层（每帧重画） | 字车（滚筒纹理纵向滚动＋旋钮旋转）、拨杆、哥特拱、按下高亮（键帽黑圆＋叠字下沉 2vp）、空格条按下矩形、候选栏 chip 高亮、换装淡入透明度 | 帧时钟每帧按插值重画 | 无缓存 |

**合成顺序**：L0 → L1 → L2 → L3；每帧只重画 L2（有纸动时）与 L3。**滚筒纹理滚动与纸上滑同速同帧**：`texOffsetVp` 与 `paperTopVp` 由同一换行插值驱动（同一帧内同值），不许两处各算一次（15 号稿 §6 换行行注：`recalcPaperHeight` 内"纸上滑 200ms"注释已过期，实际 300ms，以代码为准）。

**底色铺满（探针教训）**：P1 手机截图 `1121_probe_phone_p1.png` 暴露探针页画布只覆盖参考机高度、页面其余部分透明露出主页背景——探针件外观问题。Phase 2 的 L0 必须铺满整屏（含余量区），2A 验收时截图确认余量区无主页背景透出。

**尺寸变化**：根 Stack `onAreaChange`（当前 L5047，f51d1ad L4898–4908）触发 → 重算变换矩阵（§3.2）→ 重绘；静态层位图按参考机坐标画，与屏尺寸无关，尺寸变化时不重建静态层。

### 3.2 变换矩阵与状态抽取（新模块 `model/CanvasGeometry.ets`）

**新建纯函数模块**（不读写 @State，全部输入由参数给）：

- `computeTransform(viewW, viewH, topInset)` → `{ scale, tx, ty }`：`scale = min(屏宽/673.7, 屏高/1006.3)`，上限 1.0；`tx = (屏宽 − 673.7×s)/2`，`ty = topInset`（15 号稿 §1.4）。参考机原点 (0,0)，变换矩阵 ＝ `translate(tx, ty) ∘ scale(s)`。
- 字号链（15 号稿 §7.3 口径（b），Q1 已由 P2 内部一致性检查通过而转正）：字号保底 17vp、上限 24vp；`lineHeightVp = fs × (30/17)` 中英共用；`charsPerLine = floor((Pw − 2×marginH) / charWidthVp)`（marginH 缺省 48，下限 6）；`travelPerChar = maxTravel / charsPerLine`（平板 14 字→4.571vp；手机 9 字→7.11vp 参考机坐标、屏上约 3.83vp）；`paperTop = carriageTop − (marginB + lh + 44 + bandShift) − cursorLine × lh`（空纸时末项为 0）；`maxRows = floor((Ph − 44 − 20) / lineHeight)`；`strikeLine = carriageTop − 20 − lh/2 − strikeShift`（平板 strikeShift=15、手机 0）。
- **可原样复用的纯几何函数（点名，f51d1ad 行号）**：`rollX`／`texOff`／`plateLeft`／`baseLeft`／`baseW`／`knobD`（`components/CarriageLayers.ets` 自算式，L57–128：`hc() = Pw × 0.17` L57、`knobD() = Hc × 0.92` L61、`baseW() = Pw + 2 × knobD` L72、`rollW() = Pw / 0.9528` L124、`rollX()` L128）；`dragRatioFor`／`pulledEnough`／`angleFor`／`restDegFor`／`swingDegFor`（`model/LeverAngleCore.ets`，2026-11-14 亲核：`LEVER_COMMIT_RATIO = 0.5`，平板静止 30°／摆幅 35°、手机 15°／20°，支点 0.500／0.952，`LEVER_ASPECT_1920 = 536/2522`）；`KeymapModel.parse`／`hitTest`（static，`model/KeymapModel.ets`：`xRatio` L129、`yRatio` L130、`hitRadius = 最小行距 × 0.42` L143、空格绝对 vp 换算 L147–150、`hitTest` L161 起）。`knobAngle` 不在清单内——它是 Index 的 @State 累加量（见下条），不是纯函数。
- **必须重写的入口（不进 Canvas）**：`measureStage`（f51d1ad L1344–1516；当前 L1362）／`recalcPaperHeight`（f51d1ad L1925–2030；当前 L2003）的分支派生由单一变换矩阵＋ §7.3 新字号链取代；`frozenHVp`、isTablet 分支、`57/vp2px` 字号链一律不进 Canvas。`measureStage`／`recalcPaperHeight`／`recalcTravel`／`leverPanStart/Update/End` 都不是纯函数（读写十余处 @State），须随 Index 状态抽取，不能无代价搬走（15 号稿 §6，R-S8）。
- **Index 侧状态安排**：DocModel 与事件分发（`onCapDown`、`queueChar`、`onNewline`、`onDelete` 等）保留在 Index，不动数据层；渲染插值量（字车偏移 O、拱 x、`texOffsetVp`、旋钮角 `knobAngle`（累加态：每行 `+= lineHeight / (π × Hc) × 360`，换行另 ＋180，不回零）、拨杆角、字杆角）改为 Canvas 组件内部普通字段，由帧时钟驱动，不再是 @State（Canvas 不靠 ArkUI 状态驱动重绘）；`canvasTransform`（只存 scale／tx／ty 三个数）保留为 Index 的 @State，尺寸变化时更新，供 TopBar `.position()` 与无障碍覆盖层位置同步读取。TopBar 位置由变换矩阵算出（x=tx、y=ty、宽=673.7×s），不是"读"Canvas 的矩阵（15 号稿 §1.4 第 6 项）。
- **参考机数值（§7.3 验算值，2B 验收时复测）**：平板 carriageTop 403.2、paperTop 281.8、strikeLine 347.0、纸 281.8–910.5、maxRows 13、rollX(0)=103.5、rollX(O=−64)=52.3、baseLeft 45.0；手机 carriageTop 217.0、paperTop 123.0、strikeLine 182.0、纸 123.0–461.2、maxRows 9、rollX(0)=55.7、rollX(O=−64)=28.1、baseLeft 24.2。

### 3.3 动画时钟与时序常量全表（`@ohos.animator` 长动画，插值与完成回调手写）

帧时钟：`@ohos.animator` 长动画（duration 1,000,000ms、easing 线性，探针 P2 同款）当帧时钟，每帧 `onframe` 里重绘。约束（15 号稿 §4.1）：animator 须组件实例创建后使用，不能在 UIAbility 生命周期调用。`animateTo` 立即赋终值的语义不再存在：Canvas 化后观测值就是插值本身，动画取证改靠 hilog 打点（帧率采样＋关键帧打点）与 screenCap 中途截图，不再靠 @State 值推断。

**时序常量全表（复用现行值，f51d1ad 行号；代码注释已过期处以代码为准，见 15 号稿 §6 注）**：

| 动画 | 时序 | 曲线／要点 |
|---|---|---|
| 落字字车左移 | 30ms | Linear；每字 −travelPerChar，钳制 [−maxTravelVp, 0]；总成竖向 jolt 1vp（20ms 下沉＋20ms delay 20 回弹） |
| 删除字车右退 | 70ms | 弹簧 `springCurve(0, 1, 260, 20)` |
| 换行三段编排 | 150／300／250／700ms | t=0 拨杆摆 150ms；t=150 纸上滑一行＋滚筒转 300ms EaseInOut；t=450 字车回位 250ms FastOutSlowIn；t=700 叮声（`playCarriageReset()`＋震动，与回位结束同帧）。注：`onNewline` 头注释（f51d1ad L3189–3191）仍写"600ms／t=350／t=600 叮声"，已过期，以代码为准（t0=450、叮声 700ms） |
| 换行回位 | 150ms＋40ms | EaseInOut 回 0＋jolt 2vp，40ms delay 150 FastOutSlowIn 回弹；旋钮 `knobAngle += lineHeight / (π × Hc) × 360`（150ms EaseInOut，不回零）；调用链：`onNewline → t0=450 → resetCarriageAndGuide() → resetCarriage()`（150ms EaseInOut 回 0＋jolt 2vp，40ms delay 150 回弹）＋ guide 250ms spring（`resetCarriageAndGuide()` L3425 内另有 250ms springMotion） |
| 退行 | 250ms／270ms | 纸下移一行＋O 滑到上一行末尾 250ms FastOutSlowIn；270ms 释放 backBusy；拱 200ms 跟随；t=0 播 `playCarriageReset()`（第 13 批 ②） |
| 换纸 | 300＋300ms | 旧纸卷出 300ms FastOutSlowIn＋新纸卷入 300ms FastOutSlowIn；`paperChanging` 守卫；`PAPER_CHANGE_TRACE` 打点保留；实测 end dt 633–646ms |
| 拨杆摆动／回弹 | 去程 150ms／回程 200ms／拖拽回 0 时 150ms | 去程 FastOutSlowIn，回程 delay 150 FastOutSlowIn；拖拽 `dragRatio` 跟手控角 |
| 哥特拱移动 | 90／200／300ms | 目标 `clampedStrikeXVp()`；落字 90ms、退行 200ms、换行释放 200ms、换纸 300ms |
| 字杆击打 | 90／20／120ms | 去程 90ms FastOutSlowIn → 去程结束帧调 `landHead()`（见 §3.4）→ 有队列 20ms Linear 小回退再下一击，无队列 120ms Linear 回 55°；队列上限 20 |
| 落字起搏器 | 120ms／200ms | 现行＝strikeTick→90ms 去程→`onArrive`→`landHead`（约 110ms／字）；120ms 起搏器分支不可达（`hasLayers()` 四机全 true、`leverEnabled` 缺省 true，故 `queueChar` 恒走 strikeTick 分支）；200ms `armFallback` 只作最后防线（200ms 内无 `onArrive` 才触发）。`queueChar` L2792 的条件是 `leverEnabled && hasLayers()`，无 `useLayers` |
| 换装淡入淡出 | 200ms | 只动透明度，不重建编辑器、不丢光标 |
| 页面切换 | 250ms | 右进左出滑动过渡 EaseOut；Canvas 盒子整体参与转场，盒内各元素不单独转场（转场证据见 P5：14 点采样 range=1600.0、mid 快照 1600×2390） |
| 下拉菜单 | 160ms | opacity EaseOut |

**编排驱动方式**：单一"编排时钟"——每次换行／退行／换纸启动时记 `t0 = 帧时钟当前毫秒`，各段插值按 `(now − t0)` 查表驱动；叮声、忙窗释放（270ms）、`paperChanging` 清除（320ms）均为到时回调，不另起 `setTimeout` 链（`setTimeout` 只保留 200ms 兜底 `armFallback`；120ms 起搏器 `setInterval` 所在分支现行已不可达，Canvas 不复刻；其余编排一律帧时钟驱动，避免两套时钟打架）。

**生命周期**：导航栈顶不是 typewriter 时（HomePage 在栈顶或覆盖层页打开），Canvas 动画时钟暂停（不再每帧重绘）；回到打字机页时恢复。验收见 2B-8。

### 3.4 字杆击打与 `landHead()`（去程结束帧回调；视觉缺省不恢复）

现行机制（f51d1ad 设计值 vs 现行实际）：设计上 TypebarLayer `runNext()` 去程 `STRIKE_MS = 90` FastOutSlowIn → `onFinish` 回调 `onArrive()`（落字同帧）→ 有队列 20ms Linear 小回退再下一击，无队列 120ms Linear 回 55°；`onStrikeArrive()`（Index f51d1ad L2794）→ `landHead()`（播音＋`flushPending()` → `commitChar()`）。**现行实际就是这条链**（沙箱 2026-11-14 亲核 HEAD `c3d74ea` 的 Index.ets，三路评审独立复核一致）：字杆层由 `if (this.hasLayers())` 活分支挂载（L3909），四机均传 `strikeTick` 与 `onArrive: () => this.onStrikeArrive()`；`hasLayers()`（L2319–2325）是机型静态判断（四机全 true），`leverEnabled` 缺省 true 且全仓无改写处，故 `queueChar`（L2792，条件 `leverEnabled && hasLayers()`，无 `useLayers`）恒走 strikeTick 分支；每字由 90ms 去程结束的 `onArrive` 驱动落字，节律约 110ms／字（90ms 去程＋20ms 小回退），与 AGENTS.md 落字铁律一致。L4053 的 `if (false && ...)` 藏的是字杆篮（`CarriageLayers({ part: 'basket' })`），不是字杆层；L2790–2791 与 L305 两处注释已过期（与 §14 重新启用字杆层的代码矛盾，建议另立一笔修注释，不属本批）。`armFallback()`（L2825）是真兜底：200ms 内无 `onArrive` 才触发，正常落字不打 `typebar fallback` hilog。

Canvas 化后的定案（与现行体验一致，不改落字节律）：**帧时钟驱动 90ms 去程插值，去程结束帧调 `landHead()`**——落字、播音、清高亮都在同一帧内完成，与现行 `onFinish → onArrive` 同帧语义一致；200ms `armFallback` 在 Canvas 侧保留作真兜底（每键重武装，200ms 内无去程结束则落字并打 `typebar fallback` hilog）；**不复刻 120ms 起搏器 `setInterval`**（该分支现行已不可达）。若 §12 Q6 恢复字杆击打视觉，去程 90ms 动画只负责画、不驱动落字（画与落字解耦）。

**视觉缺省不画字杆摆动**：字杆层现正常挂载、每击摆动一次（静止角 55°→去程 0°→回程 55°）。Phase 2 缺省**保持不画字杆摆动画面**（不改动基线像素，门图比对不受影响）；`landHead()` 的触发机制仍按上段实现（声音＋落字逻辑与视觉无关）。字杆击打视觉是否恢复，见 §12 Q6（恢复则门图基线须重拍，另立项；恢复与否以截图确认字杆摆动是否可见为准）。

**D1 已纠正（原 200ms 兜底定案作废，见 §3.4）**：字杆层由活分支挂载，`onArrive` 链正常工作，现行节律约 110ms／字；200ms `armFallback` 只是最后防线。15 号稿 §6 的同款误标（"字杆层被死分支隐藏"一句）见 resolve R-S1 附注，由用户定夺是否修正已批准稿；2B 实施时在批报告里写明 hilog 实证（连续落字 20 字，`typebar fallback` 行数为 0、落字间隔约 110ms）。

### 3.5 触摸单一路（Canvas 层内只用一个 `onTouch`＋区域分发）

**D4（15 号稿 §6.1）**：Canvas 层内只用一个 `onTouch`（点按＋拖拽都在一个回调里按区域分发），不混用 `PanGesture`，从根本上避开手势竞争。触摸路由规则：覆盖层组件（TopBar／IME 锚点）在 Stack 上层，各自接自己的触摸；Canvas 的 `onTouch` 只接落到 Canvas 区域的触摸；IME 锚点透明层置 `HitTestMode.None`，不吃触摸；TopBar 区域在 Canvas 触摸分发中划为不响应区。

**区域分发表（参考机坐标；屏坐标由变换矩阵换算，命中判定一律在参考机坐标里算）**：

| 区域（参考机坐标） | 分发 | 状态机 |
|---|---|---|
| 键带区（PhotoKeybed 盒子内） | `KeymapModel.hitTest`（空格矩形优先、再最近帽心，阈值 hitRadius） | `Map<触点 id, 帽 id>` 多点状态（`heldIds`）；Down → 高亮＋震动＋`onCapDown`；Move 滑入只发声不上屏；Up／Cancel → 120ms 后清高亮（`scheduleRelease`）；`commitSeq` 变化清空 `heldIds`。落字分发与现行 `onCapDown`（f51d1ad L2638）一致：内置中文 → `onBuiltinCnCap`；空格 → `queueChar(' ')`；Backspace → `onDelete()`；Return → `onNewline()`；Shift → 按住态（松开在 Up 清）；其余按 Shift 大小写／符号模式 → `queueChar(ch)` |
| 拨杆区（`x > 673.7 × 0.78`，即参考机 x > 525.5） | 点按 → `onNewline()`；纵向拖拽 → `leverPanStart/Update/End`（写 Canvas 内部字段，不写 @State） | `dragRatioFor(dyRaw, leverHForDrag())` 换算比例（纯函数复用）；`pulledEnough`（≥0.5）换行，否则 150ms 弹回静止角（条件 C2）；`leverHForDrag() = leverW() / leverAspect`（机型蓝图值：0.2125／0.3264／0.09／0.12） |
| 功能行区（52vp 高，六键等宽） | 按 x 分六键；Down → pressed＋`onPress()`，Up／Cancel → 释放；按下态＝底色变深＋文字下沉 1vp（第 13 批 ③ 扁平 HUD 口径） | 退行键 t=0 播 `playCarriageReset()`（第 13 批 ②）；换行键金字；EN／字符键选中态金描边 |
| 候选栏区（44vp 常驻槽） | chip 点按 → `pinyinPick(idx)`；长按 → 同一 handler（触摸时间戳判断，600ms 内抑制本次 click 防双提交，见 §3.7）；翻页 → `onPrev`／`onNext` | 横向滚动手写（见 §3.7） |
| 字体条区（38vp） | 点按 → 换装页 | 与现行 `FontBar.onClick` 一致 |
| TopBar 区（56vp） | **不响应区**（TopBar 自己接 `.onClick`） | — |
| 左边缘窄条 | 缺省不设（见 C1）；若 C1 验收发现系统返回被拦截，fallback 设为不响应区 | 宽度不预设，2B 从 4vp 起逐档试，实测最小有效宽度写进批报告 |

**多点语义（探针已验事件层）**：双指同时按下两帽，一次 Down 事件 `pointers=2` 同时命中两帽（探针日志 `hit=1@0 x=79.6 y=728.8 pointers=2`、`hit=2@0 x=131.8 y=728.8 pointers=2`，证据 `p3_multitouch_tablet.log`）；两帽均高亮、两字依次入队（与现行 `heldIds` 语义一致）。高亮与入队是产品层语义，探针只验证输入分发；2B 验收时双指场景须真机复测（用户手指定两帽，不依赖注入工具）。

### 3.6 IME 锚点矩形换算（§1.4 第 5 项；`ChineseInput.ets` 不动）

`services/ChineseInput.ets`（171 行）不动：`attach` 先订阅（`setPreviewText`／`finishTextPreview` 须先订阅再 attach）后接管、`updateCursorRect` 推新矩形、`detach` 先 off 后 detach 的顺序不变。变的只是矩形来源：

- 光标矩形换算链（15 号稿 §1.4 第 5 项）：参考机坐标 (x, y) → 屏坐标 `(x×s + tx, y×s + ty)` → px（×vp2px）；经 `updateCursorRect` 推出去。vp2px 取值来源与现行 `pushCnCursor`（f51d1ad L750；当前 L753）同源（当前设备 window 的 vp2px）。探针 P4 已验公式一致：平板 `ref=336.9,303.8 → px=800.0,825.6`；手机 `ref=336.9,145.1 → px=612.0,411.5`。
- 锚点 TextInput 本身不显示，只做 IME 绑定；以透明覆盖层保留在 Canvas 之上，置 `HitTestMode.None`，不吃触摸；Canvas 只负责画纸面与光标位置。
- 键盘避让：RESIZE 模式下页面压缩 → Canvas 尺寸变化 → 根 `onAreaChange` 触发重绘（重算变换矩阵）；OFFSET 模式下页面整体上抬键盘高，Canvas 尺寸不变，盒子顶部（ty 段）被顶出可视区，纸面与键盘的相对位置按 P4 容差判定（打击行必须可见、纸顶与预期值偏差 ≤2vp）。两种模式各测一遍（条件 C3）。
- 光标恒行尾：`moveCursor` 只记日志、不做光标移动（2026-11-07 定），Canvas 不必实现光标左右移动。离页须先退中文（`langZh=false`＋detach），否则系统键盘悬在新页上（条件 C3 离页项）。

### 3.7 CandidateBar 进 Canvas（chip 绘制＋手写横向滚动＋手写长按）

- 绘制：chip（序号＋词，首选金边）按候选列表画；拼音提示 12vp；44vp 常驻槽几何约定不变（英文／系统态同高空占位，词库未就绪只显示加载态，高度同为 44vp，不许 38／44 两档）。
- 横向滚动：手写（Scroll 位置由触摸 Move 驱动，翻页 `onPrev`／`onNext` 保留；页数 `pages > 1` 时才有翻页）。
- 长按：`LongPressGesture`＋600ms 抑制的等价物是**触摸时间戳判断**（`CandidateBar.ets` f51d1ad L40–51 已亲核：长按与点按同一 handler `pinyinPick`）：Down 时记时间戳，Up 时若按下时长 ≥600ms 走长按 handler，否则走点按；600ms 内抑制本次 click 防双提交。
- 引擎解耦不变：`PinyinEngine` 只产候选词列表（`pinyin-words.json` 251,364 词／177,615 键／5.23MB；运行时绝不 sort），`PinyinSession` 组词会话、`pinyinPick`／`pinyinRefresh`／`pinyinCommitTop` 接线不变；组词中按删除只删拼音字母、按换行把拼音串按原样上屏、按字符键／中 EN 切换／换纸／换机统一先提交首选。
- 候选窗跟随光标（条件 C3）：候选窗位置由光标矩形换算链（§3.6）驱动，横向偏差 ≤2vp。

### 3.8 SpotlightOverlay 锚点体系重做（最小方案四点，15 号稿 §5.1）

现行锚点定位完全依赖 `getRectangleById` 量 ArkUI 节点矩形（`SpotlightOverlay.ets` f51d1ad：`rectOf(anchorId)` L93 起，`measureCurrent()` 两次量测复核），Canvas 页里没有 ArkUI 节点可量。按 15 号稿 §5.1 最小方案四点实现：

1. **登记表持有方**：新建 `model/GuideAnchorMap.ets`（锚点来源为各页 `guideStepsForXxx` 定义），绘制方在绘制时登记各锚点元素的参考机坐标，不再实测节点。映射表由 2C 实施时按现行 `GuideCore.allPages()`（14 页、每页固定 3 步，第 10 批记录 42 步中 41 步命中）逐项登记。**不进 GuideCore**：它是纯数据模块（无 anchor 字段，文件头自述"与渲染器解耦"），把渲染几何塞进去会破坏其契约与 Node 单测定位。
2. **换算链**：登记的参考机坐标经 §3.2 变换矩阵到屏坐标（与 TopBar／无障碍覆盖层同一份定义）。
3. **缺失 fallback（缺省）**：锚点缺失时洞口落到纸面中央固定矩形，并在批报告里记一笔，不许静默跳步。
4. **绘制责任方**：Canvas 内画（四块遮罩＋金边洞口＋气泡＋步骤点＋上一步／下一步／跳过按钮均由 Canvas 绘制并命中）。
- **验证（2C 必含项）**：全部 42 步逐项走一遍，每步洞口位置截图核对（洞口须框住目标元素，偏差 ≤2vp）；缺失 fallback 的步数在批报告里逐项列出；**fallback 步数 ≤1 步（≥41 步框住），超过即失败**；无 fallback 定义的步未框住＝失败。`getRectangleById` 在 Canvas 覆盖层下的行为探针随之作废（作废的是"对一个不再用的 API 的测试"，不是锚点功能本身）。步数依据：`model/GuideCore.ets` `allPages()` 14 页、`stepsExpected()` 每页 3 步（2026-11-14 亲核）。
- GuideOverlay 旧卡片不迁移：现行代码里无挂载（只剩 import 与注释），是死代码留作回滚对照；2C 的引导工作只含 SpotlightOverlay（＋OnboardingGuide 按 §12 Q5 结果办）。附带：`Index.ets` 当前 L5020 注释"启动引导仍是 GuideOverlay 底部卡片"已过期（与 L5013"启动引导改为新全屏组件"矛盾），2C 顺手改掉，不单独立项。

### 3.9 无障碍透明原生按钮覆盖层全量（缺省不降级，2C）

- **全量清单**（15 号稿 §5.1）：四机全部键帽（1920s 43／1930s 58／1950s 49／1960s 52，另有空格条）＋功能行六键＋TopBar 三图标＋候选栏 chip。探针 P5 已验证 49 节点形态（43 帽＋6 功能键，`a11y_cap_0..42`、`a11y_fn_0..5`，`text` 为 `keycap <label>`／`function <label>`，dump `p5_a11y_nodes_attr_dump.json`）；2C 按四机全量补齐（1930s／1950s／1960s 帽数不同，按钮数随 keymap 走，不写死 43）。
- **位置同步**：按钮位置随变换矩阵同步（与 §3.2 同一份定义）；按钮透明（像素影响低于门图阈值，探针做法：字色全透明、opacity 0.02，须门图验证），只作无障碍节点。
- **触摸隔离**：覆盖层按钮默认不渲染（避免吃 P3 触摸）；只在读屏开启时渲染（探针 P5 做法：开关键控制，P5 后自动恢复浮层）。触发方式缺省为**设置项**（`AppPreferences` 新增 `a11y.overlay.enabled`，缺省 false）——全仓无运行时查询读屏开启状态的公开 API 用例，监听方案可行性未经证实；2C 若找到公开 API 可改走监听，须在批报告写明 API 名与所用方式。但"平时不渲染、读屏时全量"是缺省口径。
- **分批口径**：缺省 Phase 2 一次全量；若 2C 时间不够，分批做时先补功能行＋TopBar、键帽后补——分批不降级，只是排期（15 号稿 §12 Q3 已定夺，用户 2026-11-13 定不降级）。
- **验收**：条件 C4（用户抽测听感）＋ dump 节点数核对（dump 时状态定为"候选栏空、中文输入关闭、英文态"，每机切机后 dump，节点数＝该机帽数＋1 空格条＋6 功能键＋3 TopBar 图标，逐项对；另在 3 候选态下 dump 一次，节点数须为上式＋3）。

### 3.10 数据层不动

DocModel／DocStore 与 ArkUI 无关，Canvas 化不碰数据层。渲染读模型只有 `getLines()`／`getCursor()`／`getMeta()` 三个只读口，写口 `insertText`／`newline`／`clear`／`setCursor`（`DocModelCore.ets` f51d1ad：构造函数 L53–64、`getLines()` L70、`getCursor()` L81、`getMeta()` L85、`insertText` L125、`newline()` L198、`toDocData()` L218–220）。纸面几何（paperTop／Ph／maxRows）由 `CanvasGeometry` 从模型派生，不由组件自算。统计／成就边界不变：`statsService.recordChar()` 落字后内存自增；`AchievementService.evaluate()` 只在保存／导出边界、flush 完成之后跑；`PAPER_CHANGE_TRACE` 打点保留。

## §4 逐组件迁移清单

行号以 `f51d1ad` 为准（调查报告亲核）；当前行号见附录 A（2026-11-14 核）。

| 组件 | 子批 | 迁移要点 | 验收（子批内） |
|---|---|---|---|
| `CanvasTypewriter.ets`（新建） | 2A | Canvas 盒子＋变换矩阵＋动画时钟骨架＋分层合成；`onAreaChange` 触发重算＋重绘 | 盒子落位与变换矩阵计算值误差 ≤2vp（P5 方法复测，手机） |
| `model/CanvasGeometry.ets`（新建） | 2A | 纯函数模块（§3.2）；复用函数点名搬入，不复制机型分支常量（`leverAspect` 等仍由 MachineCatalog 提供） | 单元数值比对：§7.3 验算值逐项对上（手机 paperTop 123.0／carriageTop 217.0，误差 ≤1vp） |
| PaperStage 纸面 | 2A（静态文字）＋2B（纸动） | L1 纸纹＋装饰进静态层；行文字进 L2 纸层（`fillText`＋注册字体）；页码 `n / m`、引导文案、光标三角进 L2 | 静态纸面像素与基线比对（§5）；落字／换行后纸顶偏差 ≤1vp（P2 方法复测） |
| PaperSheet 格线 | 2A | `components/PaperSheet.ets`（`gridCtx` L198、`drawPaperLayer()` L360）**全仓零挂载**，只作绘制参考；格线装饰（页眉双细线／稿纸竖格／红格边距线）在 L1 **新画**；行文字 List 不保留，随 PaperStage 进 L2（§3.1）。Index 内无 `PaperSheet({` 挂载，只在 L27 `import { PaperRow } from '../ui/PaperSheet'` | 格线像素与现行一致（截图比对） |
| CarriageLayers 滚筒／金属件／篮 | 2A（静态）＋2B（纹理滚动） | 三层拼合手写；滚筒纹理 v7 两份拼接纵向滚动（`texOff` 归一化到 `[−Hc, 0)`）；柱面明暗罩 9 档渐变（底缘 0.72）；旋钮旋转（`knobAngle` 累计，不回零；一行 ≈ lineHeight／(π×Hc)×360°）；压纸卷、铭牌 Text（110×26，黄铜渐变） | 静态滚筒像素与基线比对；换行时纹理滚动与纸上滑同速同帧（hilog 打点：同帧 `texOffset` 与 `paperTop` 变化量一致） |
| CarriageStrip | 2A（删除） | 只在 `useLayers = false` 的 else 分支（Index L4429）渲染；Canvas 化拆掉 `detectLayers`／`useLayers` 整套机制后随旧分层机制一并删除；删除前确认 `detectLayers` 的四文件在包内齐备（写进 2A 批报告） | 删除后编译通过、静态整机无缺件 |
| TypebarLayer 字杆 | 2B（机制） | 击打时序与 `landHead()` 去程结束帧回调（§3.4）；**视觉缺省不画字杆摆动**（字杆层现正常挂载、每击摆动；缺省不画，只为不改动基线像素） | 落字同帧（`landHead` 在去程结束帧触发，hilog 打点：单字 85–95ms、连打间隔均值 ≈110ms、20/20 无丢失、正常连打无 `typebar fallback`）；无落字丢失（连续 20 字 20/20） |
| LeverLayer 拨杆 | 2A（静态＋旋转绘制）＋2B（拖拽语义） | 单图绕支点旋转（支点 0.500／0.952，`LEVER_ASPECT_1920 = 536/2522`）；静止角／摆幅常量复用（平板 30°／35°、手机 15°／20°）；拖拽跟手＋C2 语义 | 静态拨杆角度与基线一致；拖拽角偏差 ≤5°、跟手延迟 ≤1 帧；C2 过半／回弹各 3 次 |
| PhotoKeybed 键带 | 2A（静态图＋叠字）＋2B（命中＋多点） | 键带图 `ImageFit.Contain` 等价绘制（盒子宽高比须等于图片宽高比，否则 letterbox 错位——R6 四公式问题由变换矩阵一次性解决，不再四处维持）；叠字按 `xRatio × widthVp`／`yRatio × heightVp` 定位；按下黑圆（直径 2×hitRadius、黑 0.30）＋叠字下沉 2vp；空格条圆角矩形叠加层 | 静态键带像素与基线比对；命中 43 帽×3＝129/129、误触 0（手机 USB 注入，C6）；双指 `pointers=2` 同时命中两帽（用户手动复测） |
| FunctionRow 功能行 | 2A（静态）＋2B（按下态） | 六键金属渐变＋顶部高光线＋文字下沉 1vp（第 13 批 ③ 扁平 HUD 口径：键底 `#2e2823`、描边 `#6b6055`、文字 `#dbccb3`、按下底色 `#1f1a15`）；选中态金描边（EN 金 ⟺ langZh、字符金 ⟺ symbolMode）、换行金字 | 静态功能行像素与基线比对；六键逐键点按均触发对应动作（截图前后对比） |
| FontBar 字体条 | 2A（静态）＋2B（点按） | 38vp；上下各 1vp 细线（`#3a332b`）；中间 Text 13vp（`#beb4a8`，用当前字体本身渲染）；点按 → 换装页 | 静态像素比对；点按进换装页（截图前后对比） |
| CandidateBar 候选栏 | 2B | 见 §3.7 | chip 点按／长按／翻页各 3 次；候选窗跟随光标（C3） |
| TopBar | 2A（位置同步） | 保留 ArkUI；`.position()` 由变换矩阵算出；高 56vp 不变 | 三图标点按均有效（文件夹／"?"／汉堡）；位置与 Canvas 盒子对齐（偏差 ≤1vp） |
| GuideOverlay 旧卡片 | 不迁移 | 未挂载（只剩 import 与注释），死代码留作回滚对照；2C 不碰 | — |
| SpotlightOverlay | 2C | 见 §3.8（锚点体系重做） | 42 步逐项走一遍，洞口框住目标元素（偏差 ≤2vp）；fallback 步数逐项列出 |
| AppMenu／AppDialog | 2C | 壳进 Canvas；菜单 160ms 淡入；遮罩与卡片分开绘制、分开命中：点遮罩关、点卡片不关；内含 TextInput 的弹窗保留原生输入层 | 菜单锚定位置正确（触发按钮下方，不全局压暗）；弹窗点遮罩关、点卡片不关 |
| TrashPage／SettingsPage／FontManagerPage／CollectionPage／CollectionDetailPage | 保留 ArkUI | 覆盖层页，与 §2.1 同款（TextInput 能力边界＋范围决定）；不在本批迁移范围 | 各页按现行流程可用（截图前后对比） |
| HomePage／OnboardingGuide | 另议（§12 Q5） | 缺省保留 ArkUI（见 §2.1）；若用户定进 Canvas，另立小项、不进本批 | 按 Q5 结果办 |

**死代码不计入工作量**：`machines/1920s/CarriageLayers.ets`（303 行，零引用）、字杆篮 `if (false && ...)` 死分支、CarriageStrip（只在 `useLayers = false` 的 else 分支渲染，随旧分层机制一并删除，见 §4）——2A 盘点范围时不把这三处算进工作量；字杆层正常挂载，不属死代码；字杆视觉恢复见 §12 Q6。

## §5 验证口径

### 5.1 设备口径（用户 2026-11-14 定）

**缺省只在手机（ADA-AL00U）一台设备上验证**。手机：`192.168.5.124:44879`（1224×2776，vp2px=3.375；DHCP 可能变，报告以实测为准；批量注入缺省走 USB，见 C6）。平板（MLR-AL10，`192.168.5.133:42355`，2560×1600，vp2px≈2.375）只在以下逐项注明处补验：

| 须平板补验的项 | 为什么手机不够 | 平板验收标准 |
|---|---|---|
| 2A 静态整机像素（参考机本身） | 参考机就是平板构图（scale=1.0）；手机只能验缩放后构图，不能验参考机定义值（paperTop 281.8／carriageTop 403.2／rollX(0)=103.5） | 静态整机门图 vs 1083（见 §5.3）：keyboard 区 0.00%＋连拍两帧四区 0.00%（静止性）＋frame 区差异逐项定位（frame 区任一区 >1% 即失败） |
| 2C Spotlight 锚点换算 | 锚点矩形是参考机坐标；同一变换矩阵在手机 scale=0.538 下同样可验，判据与 scale 无关 | 手机先验（42 步洞口逐项截图核对，偏差 ≤2vp）；平板只在手机发现偏差时补验 |
| 2A–2C 回归门 | 当批测了哪台设备，就跑哪台设备的门（平板门只在平板被测时才需要；手机门为 1087） | 见 §5.3 |
| 其余三机静态像素（1930s／1950s／1960s 平板基线 1084／1085／1086） | 三机平板基线只存在于平板池 | Q7 若选"2A 先拍手机三机基线"，三机静态走手机（见 2A-7），平板三机只在手机发现偏差时补验；Q7 若选"三机静态只走平板"，每机切机后门图 vs 各自基线（keyboard 区 0.00%＋连拍静止性，见 R-S10）；若基线亦待确认，按 §5.3 fallback 办 |
| P4 遗留平板补验（候选窗跟随／离页不悬留／纸面间距） | P4 双机均为部分通过，平板遗留未验 | 候选窗跟随 1 次＋离页 1 次（RESIZE 模式），判据同 2B-5 |

其余项（命中、动画、输入、帧率、取证、读屏节点）一律缺省手机；平板数据已有探针双机结果，不重复跑（探针 P1/P2/P3/P5/P6 双机主项均通过，数值见 §0；**P4 双机均为部分通过，遗留见 C3／2B-5，手机验收，平板补验项见 §5.1 表**）。

### 5.2 截图号段

探针用了 **1100–1132**（29 个文件落盘，最大号 1132）。Phase 2 提议用新池 **1200 起**（见 §12 Q1 定夺；1200 池与 1037 池、1100 池均无冲突）。每子批截图从该子批的起始号连续编号，批报告附号段清单。

### 5.3 回归门（以 1083／1087 候选基线为准）

- **门图工具**：`tools/gate-compare.py`（阈值 30，max 通道差；区域：keyboard y 0.62–0.98、frame_left／mid／right x 三分、y 0.40–0.62；纸面整体排除，状态栏顶部 5% 除外）；**Canvas 门图**：keyboard 区 0.00%＋连拍两帧四区 0.00%（静止性）＋frame 区差异逐项定位（frame 区任一区 >1% 即失败）；**ArkUI 主屏回归门**：四区全部 0.00% 才算过（同路径，拍摄路径与基线相同）。探针实测：vs 1083 frame 三区 0.52／0.17／0.04%（拨杆／哥特拱静止相位差），keyboard 0.00%。
- **基线**：平板 1920s 以 `1083_1920s_baseline30_tablet_v13b.png` 为准，手机 1920s 以 `1087_1920s_baseline30_phone_v13b.png` 为准（AGENTS.md 基线标定表：两文件均为"第 13 批重拍（待批准人确认）"；旧 1026／1027 作废）。空纸 parts：平板 281.8／123.4、手机 206.0／96.0。
- **基线拍摄前置**：空纸状态＋交互后等 ≥1 秒确认拨杆回静止位＋连拍两张逐像素相同；基线更新仪式＝批报告写差异定位与原因、批准人确认后重拍。
- **Fallback（若用户未确认 1083／1087）**：1026／1027 不能作 fallback——第 13 批已把键盘重排（Shift／Caps／Tab 等）与功能行 HUD 落地，1026 早于这些确定性视觉改动（探针报告 §七：vs 1026 keyboard **1.77% FAIL**，不是探针引入）。确认前各子批用"候选基线（1083／1087）＋连拍两帧四区 0.00%"作回归证据，并记录不符点（探针 §七先例：vs 1083 keyboard 0.00% PASS，frame 三区 0.52／0.17／0.04% 为拨杆／哥特拱静止相位差，属会话状态差）。三机平板基线同理以 1084／1085／1086 为准，确认前用候选基线＋连拍静止性。基线确认口径由用户在 §12 Q2 定夺。
- **门图失败即 revert**（AGENTS.md 基线更新仪式：未经仪式，门失败即 revert）。

### 5.4 动画取证边界（AGENTS.md，Phase 2 同样适用）

- screenCap 单帧约 400–500ms，大于 350ms 级动画窗口，动画第 0 帧类指标连拍不可靠；替代靠 hilog 打点／连通域／用户录屏。
- 帧率类结论以 hilog 采样为准（逐帧时间戳，算平均／P95／最大帧耗时），screenCap 只作中途状态佐证；动画精确验证靠用户录屏。
- `animateTo` 立即赋终值：观测 @State 值只能证明方向与目标，不能证明渲染插值——Canvas 化后观测值就是插值本身，取证改靠 hilog 打点与 screenCap 中途截图。

## §6 回滚开关

- **新开关 `canvas.enabled`**（`services/AppPreferences.ets`，STORE_NAME `carriagereturn_prefs`；现行回滚开关共 3 个：`guide.enabled`／`custom.enabled`／`custom.knob.enabled`）。接线四步：① `PrefKeys` 增加 `CANVAS_ENABLED = 'canvas.enabled'` 常量；② `PrefRegistry.specs` 增加 `{ key: PrefKeys.CANVAS_ENABLED, type: 'boolean', defaultValue: 'false', owner: 'Phase2', removeAfter: 'Phase 2 完成后' }`；③ `tools/audit-switches.py` 的 `SWITCH_KEYS` 增加 `'canvas.enabled'`（该集合是硬编码，`switches=` 计数即其长度，不改脚本本身 switches 不会增加）；④ 2B 切换时把同一 specs 条目的 `defaultValue` 改为 `'true'`（只改缺省值，不删键；回滚时只改回 `'false'`）。验收：`--check` 报 `keys=原值+1、switches=4、problems=0`。消费点：Index `build()` 分支读开关——为真挂 `CanvasTypewriter`、为假走 ArkUI 主屏。
- 缺省值：2A／2B 实施期间 `false`（主屏仍走 ArkUI；2A 的 Canvas 组件只在调试入口可见）；2B 验收通过后改为 `true`（主屏走 Canvas）；2C 期间保持 `true`。
- 开关只控制主屏渲染链切换（Canvas 主屏 ⟷ ArkUI 主屏），不控制覆盖层页（覆盖层页始终 ArkUI）、不控制数据层、不控制音频。
- **旧 ArkUI 主屏代码保留至少一批**（2B 切换后不删，删除另立项）；开关关回即回 ArkUI 主屏，不丢文档、不丢光标（DocModel 与渲染无关，状态由模型持有）。
- 开关清理签字：Canvas 稳定运行一批后，由用户签字清理（现行开关清理惯例，见 §11）。

## §7 每子批验收标准

验收标准是"做到什么算过"；每子批附操作前／操作后截图对比（识屏验收铁律）；点按后两张截图完全相同＝无响应＝失败。数值阈值引用探针实测数（低于探针实测即不通过，不得把探针已达的数值写松）。

### 7.1 子批 2A 验收

| # | 验收项 | 做到什么算过 |
|---|---|---|
| 2A-1 | 静态整机像素（手机） | 手机切 1920s 空纸，静态整机截图与 1087 候选基线门图：keyboard 区 0.00%＋连拍两帧四区 0.00%（静止性）＋frame 区差异逐项定位并记入批报告（frame 区任一区 >1% 或 keyboard 区 ≠0.00% 即失败）；余量区深底铺满、无主页背景透出（P1 手机 1121 教训） |
| 2A-2 | 静态整机像素（平板补验） | 平板切 1920s 空纸，静态整机截图与 1083 候选基线门图：keyboard 区 0.00%＋连拍两帧四区 0.00%（静止性）＋frame 区差异逐项定位并记入批报告（frame 区任一区 >1% 或 keyboard 区 ≠0.00% 即失败） |
| 2A-3 | 变换矩阵数值 | 手机 scale=0.5383、paperTop=123.05／carriageTop=217.05（与 §7.3 验算值 123.0／217.0 误差 ≤1vp，探针 P2 手机 dPaper 0.05／dCarr 0.05）；平板 scale=1.0000、paperTop=281.84／carriageTop=403.19（探针 P2 平板 dPaper 0.04／dCarr 0.01） |
| 2A-4 | 静态层缓存 | 换机／换纸时静态层重建一次、平时不动（hilog 打点：固定格式 tag `CanvasTypewriter`，消息 `static layer rebuilt: <layer> count=<n>`；验收：换机／换纸各 1 次后 grep 该格式日志条数＝切换次数（每层各 1 次），其余操作 0 条）；切机后首帧静态整机完整、无缺图 |
| 2A-5 | TopBar 同步 | TopBar 位置与 Canvas 盒子对齐（`getRectangleById` 实测 TopBar 矩形 vs 变换矩阵计算值，偏差 ≤1vp）；三图标点按均有效（截图前后对比） |
| 2A-6 | 冷启动出像素（C7） | 连续 3 次冷启动＋切机，每次截图与同机型连拍前一帧四区 0.00% 且整图平均亮度 ≥10（/255，避免全黑空暗）；任一次不满足即按 C7 流程报（附 dump＋截图＋hilog），停 2A 挂载切换。亮度阈值 10 为初值，2A 首轮实测后若误报／漏报，在批报告里校准并写明实测值 |
| 2A-7 | 三机静态像素（C5） | 1930s／1950s／1960s 手机切机后静态截图：keyboard 区 vs 1017／1018／1019 须 0.00%（若 keyboard 区因第 13 批键盘重排对不上，改判为"keyboard 区差异须定位为第 13 批键盘重排所致（与 vs 1026 的 1.77% 同因），并记不符点"，不得直接判失败）＋连拍两帧四区 0.00%（静止性） |
| 2A-8 | 编译与回归 | hvigor 编译通过；ArkUI 主屏回归门（1083／1087）四区 0.00%（2A 未切主屏，ArkUI 主屏须零像素回归；同路径才要求四区，见 §5.3） |

### 7.2 子批 2B 验收

| # | 验收项 | 做到什么算过 |
|---|---|---|
| 2B-1 | 帧率（P2 复测） | 换行编排全程帧率 ≥55fps、每键落字帧率 ≥55fps、单帧 draw 耗时 P95 ≤8ms、连续落字 20 字无输入丢失（探针实测 120fps 级、p95 1–2ms 为参照，不得低于阈值）；满纸用例（仅当 L2 实现为整张重画时）：纸面写满 13 行后敲一字，draw P95 ≤8.3ms |
| 2B-2 | 键帽命中（C5） | 1920s 43 帽×3＝129/129、误触 0（手机 USB 注入）；1930s／1950s／1960s 每机不少于 20 帽×1 次抽测、误触 0；双指同时按下两帽（用户手动，两帽均高亮、两字依次入队） |
| 2B-3 | 拨杆语义（C2） | 过半拖拽松手触发换行（完整编排）；不到半松手 150ms 内弹回静止角、无换行、无落字；各 3 次；拖拽角偏差 ≤5°、跟手延迟 ≤1 帧（探针实测 dAngle 0.00、8ms） |
| 2B-4 | 左边缘返回（C1） | 用户真机手动左边缘右滑 3 次均触发系统返回；若被拦截，左边缘窄条 fallback（宽度不预设，2B 从 4vp 起逐档试，实测最小有效宽度写进批报告）后重验 3 次 |
| 2B-5 | 输入避让（C3） | RESIZE 与 OFFSET 各测一遍：打击行必须可见、纸顶与预期值偏差 ≤2vp、键盘与纸面重叠 0vp、候选窗跟随光标（候选窗左缘 x 与光标矩形左缘 x 之差，同为参考机坐标换算后，≤2vp）、离页键盘不悬留；纸面底部与键盘顶部间距与 2A 实测预期值偏差 ≤2vp（纸底屏坐标 = (paperTop + Ph) × s + ty，与键盘顶实测值比对；探针实测：手机 RESIZE 压缩 314.1vp、无重叠、纸顶 d 0.05 为参照） |
| 2B-6 | 字杆 landHead 同帧 | 去程结束帧调 `landHead()`（hilog 时间戳验收，不截图：单字 `landHead` 时戳 − 去程起时 ∈ [85, 95]ms；连打 20 字相邻落字间隔均值 ≈110ms，20/20 无丢失；正常连打全程 `droppedTicks=0`、hilog 无 `typebar fallback`；兜底用例（人工阻塞去程或等效故障注入）：200ms 内落字且 hilog 出现 `typebar fallback`——若无法注入，删该条并在批报告写明原因，其余三条仍须过） |
| 2B-7 | 换行／退行／换纸编排 | 换行 150／300／250／700ms 编排完整（纸上滑＋滚筒转＋字车回位＋t=700 叮声）；退行 250ms＋270ms 释放；换纸 600ms（end dt 633–646ms 量级）；各 3 次，截图前后对比 |
| 2B-8 | 挂载切换与回滚 | `canvas.enabled` 开后主屏走 Canvas、打字全流程可用；关后回 ArkUI 主屏、文档与光标不丢；开关切换各 3 次；时钟暂停／恢复 hilog 打点各一次（栈顶非 typewriter 时暂停、回打字机页时恢复；所用暂停机制写进 2B 批报告，须与现行 ArkUI 动画的暂停行为一致，若 ArkUI 侧无暂停则写明 Canvas 同样不暂停并给出理由） |

### 7.3 子批 2C 验收

| # | 验收项 | 做到什么算过 |
|---|---|---|
| 2C-1 | Spotlight 锚点 | 42 步逐项走一遍，洞口框住目标元素（偏差 ≤2vp）；允许 fallback 的步须满足：在 `GuideCore.allPages()` 里有 fallback 定义且批报告逐项列出；**fallback 步数 ≤1 步（即 ≥41 步框住，现行水平），超过即失败**；无 fallback 定义的步未框住＝失败 |
| 2C-2 | 无障碍全量 | dump 时状态定为"候选栏空（无候选 chip，chip 数＝0）、中文输入关闭、英文态"，每机切机后 dump 节点数＝该机帽数＋1 空格条＋6 功能键＋3 TopBar 图标，逐项对；另在 3 候选态下 dump 一次，节点数须为上式＋3；条件 C4 用户抽测听感（不少于 10 帽＋功能行六键，朗读文本与帽面／键名一致） |
| 2C-3 | 引导与菜单／弹窗 | AppMenu 锚定位置正确、不全局压暗；AppDialog 点遮罩关、点卡片不关；内含 TextInput 的弹窗可正常输入；`Index.ets` L5020 过期注释已改 |
| 2C-4 | 门图基线重拍 | 1083／1087 经用户确认后成为正式基线（或按 §12 Q2 结果办）；重拍后以新基线为准，后续门图四区 0.00%（重拍当次以新旧基线差异定位为准，见 R-S10 的区分） |
| 2C-5 | 清理 | 2A 临时调试入口已删；`CanvasProbePage.ets` 已删（§2.3）；`git diff --stat -- entry/src/main/ets/pages/ entry/src/main/ets/model/DocModelCore.ets` 须为空（路径以实际覆盖层页与数据层文件为准）；`tools/run-checks.py` 全套件（现行 178 项＋本批新增，基数以实施时 `node --test` 摘要为准）独立重跑报出口码＋摘要（沙箱侧重跑产物复核后还原不提交） |

## §8 批报告格式要求

- 报告开头第一行写"本批新证据改了上一批哪条结论、为什么改"（本批上一批＝15 号稿 v2；2B 上一批＝2A，2C 上一批＝2B）。
- 每项验收写：规格是否按稿执行、通过标准数值结果、截图号、不符点及原因、替代证据（如果有）。
- 证据抓不到时，用替代证据继续做，并在报告里写明缺了什么、为什么缺、替代证据是什么；只有编译不过、设备离线、包装不上才可报阻塞，报时附试过的方法、每种方法的原文错误、还差什么。**不要写"缺一项不许点""缺某项不许开工"式硬门槛。**
- 验收标准是"做到什么算过"，不是"缺什么就不许做"。
- 每批 push origin main＋验真：`git log --oneline -2 origin/main` 看到提交号、且 `git status` 干净，才算提交完成。**"提交到 main"不等于推送，必须显式 push＋验真。** 与沙箱并发推 main 时 non-fast-forward，用 `pull --rebase` 后重试；先 commit 再 pull --rebase 再 push。
- 桌面端提示词铁律适用：提示词里几何、坐标和根因须先读当前代码、当前截图、当前日志再定；改几何先分 isTablet 分支（本批内 isTablet 分支只用于 LeverAngleCore 的静止角／摆幅——拨杆角是 Canvas 内唯一的设备相关量；其余几何一律走变换矩阵，不进 isTablet 分支）；提示词里禁用沙箱路径，一律仓内相对路径。

## §9 风险

| 风险 | 触发 | 兜底 | 兜底走完仍不通过 |
|---|---|---|---|
| R2 之谜（盒子落位） | P5 复测发现 Canvas 盒子落位错误 | R2 须重新立项调查，C 方案不自动成立（15 号稿 §9 回退句） | 回報用户重定路线 |
| 字体回归 | 某机／某纸种下注册字体进 Canvas 失效 | 混合方案（纸面文字原生 `Text` 叠加，15 号稿 §3.3 第 1 条）；§7.3 检查仍适用，纸顶比对口径改为"Canvas 算出的纸顶与 `Text` 实测纸顶偏差 ≤2vp" | 回報用户重定路线 |
| 帧率回归（三机／满行） | 某机帧率持续低于 55fps 或单帧 draw P95 >8ms | 加粗分层粒度（静态层离屏缓存、只重画动层）→ `RenderNode + DrawContext`（API 11+）→ Native Drawing／OpenGL（第二、三级须另立调研，本稿未覆盖，15 号稿 §9） | 回報用户重定路线 |
| 1126 空暗复现（C7） | Canvas 节点在、像素空 | 复现即报（附 dump＋截图＋hilog），停下查因；只停挂载切换，不停离线工作 | 回報用户定夺 |
| 字杆驱动源（D1，已纠正） | 原 200ms 兜底定案作废：字杆层由活分支挂载（L3909），`onArrive` 链正常工作，现行节律约 110ms／字；200ms `armFallback` 只是最后防线 | Canvas 版 `landHead()` 在去程 90ms 结束帧由帧时钟回调触发（见 §3.4）；2B 批报告写明 hilog 实证（连续落字 20 字，`typebar fallback` 行数为 0、落字间隔约 110ms） | —（设计纠正，不属失败） |
| 第 13 批继续落地 | 桌面端实施回报后组件清单／行号变化 | 本稿组件清单按新提交重核；探针页独立于第 13 批，互不阻塞；行号以当前代码为准（附录 A 只到 2026-11-14） | — |
| 三机差异未覆盖 | 某机静态像素／命中与 1920s 结论不一致 | 按机重验（C5）；差异逐项记入批报告，不拿 1920s 结论冒充三机结论 | 回報用户定夺 |
| 无障碍覆盖层做不到全量 | 2C 某机帽数／chip 数对不上 | 透明原生按钮覆盖层全量补；分批做时先补功能行＋TopBar、键帽后补 | 回報用户定夺覆盖范围分几批做，不降级口径不变 |

**D1 已纠正（沙箱 2026-11-14 亲核 HEAD `c3d74ea`，见 §3.4）**：字杆层由活分支挂载，`onArrive` 链正常工作，现行节律约 110ms／字；200ms `armFallback` 只是最后防线，正常落字不打 `typebar fallback` hilog。原"现行走 200ms 兜底、onArrive 永不触发"的说法是误读（死分支藏的是字杆篮，不是字杆层），作废。

## §10 自查清单

- Phase 1 条件 C1–C7 逐项有承接子批、承接方式、验收标准（已满足：§1）。
- 绘制分层粒度有 P2 实测为依据（已满足：§3.1，120fps 级、p95 1–2ms）。
- 状态抽取：可复用纯函数逐个点名、须重写入口逐个点名、`frozenHVp`／isTablet／`57/vp2px` 不进 Canvas（已满足：§3.2）。
- 动画时钟与时序常量全表复用（已满足：§3.3；过期注释已注"以代码为准"）。
- 触摸单一路＋路由规则＋区域分发表（已满足：§3.5）。
- IME 锚点矩形换算按 §1.4 第 5 项（已满足：§3.6；P4 公式一致性已验）。
- Spotlight 锚点最小方案四点＋42 步逐项验证（已满足：§3.8）。
- 无障碍全量清单＋分批不降级（已满足：§3.9）。
- 验证口径缺省手机、平板补验项逐项注明（已满足：§5.1）。
- 截图号段 1200 起与 1037／1100 池协调（已满足：§5.2，待 §12 Q1 确认）。
- 回归门以 1083／1087 为准、fallback 写明（已满足：§5.3，待 §12 Q2 确认）。
- 回滚开关 `canvas.enabled`＋旧 ArkUI 主屏保留一批（已满足：§6）。
- 验收标准写"做到什么算过"，无"缺一项不许点"式硬门槛（已满足：§7、§8）。
- `$rawfile` 静态分支约定写明理由＋入 §12 Q3（已满足：§0 第 3 条、§12 Q3）。
- 行号引用以 `f51d1ad` 为准，关键锚点按 2026-11-14 当前代码核对（已满足：附录 A；本次核对：registerBundled L1223、ExportPage 挂载 L4917、pushCnCursor L753、TopBar L3899、PaperStage L4279、PhotoKeybed L4488、FunctionRow L4515、HomePage L4596、根 onAreaChange L5047、leverPanStart L2284、measureStage L1362、recalcPaperHeight L2003、onNewline L3309）。

## §11 证据索引

- 可行性方案：`docs/designs/15-Canvas渲染-可行性方案.md` v2（已批准，`5d89d41`）
- 探针报告：`docs/evidence/canvas-probe-20261113.md`（17 节；截图 1100–1132，29 个文件落盘，最大号 1132；读屏 dump `p5_a11y_nodes_dump.json`／`p5_a11y_nodes_attr_dump.json`；多指日志 `p3_multitouch_tablet.log`；手机 USB 命中日志 `p3_hits_phone_usb.log`）
- Resolve：`~/workspace/egm-work/canvas-resolve.md`（R-S1–R-S34，6 Blocker／31 Major／12 Nit 全修）
- 代码面调查：`~/workspace/egm-work/canvas-invest-codebase.md`（54KB，基准 `f51d1ad`）
- API 面调查：`~/workspace/egm-work/canvas-invest-api.md`（约 33KB）
- 概念 brief：`~/workspace/egm-work/canvas-concepts-brief.md`
- 根因调查：第 14 批 `~/workspace/egm-work/layout-root-cause.md`（R1–R11）
- 仓内 AGENTS.md：基线标定表（1083／1087 待确认，1026／1027 作废）、图标铁律、识屏验收铁律、动画取证边界、基线更新仪式
- 探针页残留文件：`entry/src/main/ets/components/CanvasProbePage.ets`（48KB，零引用，2A 删除，见 §2.3）
- 现行基线：平板 1083（待确认）／手机 1087（待确认）；三机平板基线 1084／1085／1086（待确认，第 13 批已重拍）；三机手机基线 1017／1018／1019（第 11 批旧基线，第 13 批键盘重排后同样过期；手机三机重拍见 §12 Q7）

## §12 待用户定夺

- **Q1（截图号段）**：Phase 2 截图用 1200 池（探针 1100–1132 已用，最大号 1132），是否同意？备选：沿用 1100 池续号（1133 起）。
- **Q2（基线确认口径）**：回归门以 1083（平板）／1087（手机）候选基线为准，是否同意先由用户确认这两张（确认后成为正式基线，1026／1027 正式作废）？若暂不确认，是否同意确认前各子批用"候选基线＋连拍两帧四区 0.00%"作回归证据并记不符点（§5.3 fallback）？
- **Q3（`$rawfile` 静态分支约定是否保留）**：P6 已证实动态 `$rawfile` 在 SDK 26 上编译通过且渲染正常，"静态分支"不是编译器硬约束。本稿缺省仍用静态分支（理由见 §0 第 3 条）。是否同意保留该约定？备选：允许动态传参，但须逐处留档＋回归（验证面扩大，2A 另加取图回归项）。
- **Q4（分批方式）**：是否同意 2A（骨架＋静态层）→ 2B（交互＋动画＋挂载切换）→ 2C（引导＋无障碍＋基线收尾）的三子批切法？备选：两子批（2A＋2B 合并，静态与交互一次做；风险：半 Canvas 半 ArkUI 同屏期拉长，门图无法判定）或按组件切（不建议，理由见 §2.2）。
- **Q5（HomePage／OnboardingGuide 是否进 Canvas）**：本稿建议两者保留 ArkUI（理由见 §2.1：独立页、与 R1–R11 无关、图标铁律、无探针覆盖），与 15 号稿 §5.1 的"HomePage 进 Canvas／GuideOverlay 进 Canvas"不同（§5.1 写的是旧底部卡片，第 13 批 ④ 已换成全屏 5 页新组件）。是否同意保留？若要求进 Canvas，须另加探针、不进本批。
- **Q6（字杆击打视觉是否恢复）**：字杆层现正常挂载、每击摆动一次（静止角 55°→去程 0°→回程 55°）。本稿缺省保持不画摆动画面（不改动基线像素）。是否同意？若要求恢复视觉，门图基线须重拍，另立项；恢复与否以截图确认字杆摆动是否可见为准（`landHead` 触发机制与视觉解耦，见 §3.4）。
- **Q7（手机三机基线拍摄责任＋C4 读屏抽测参与确认）**：手机三机（1930s／1950s／1960s）基线现为第 11 批旧图 1017／1018／1019，第 13 批键盘重排后已过期。是否同意 2A 先在手机上重拍三机基线（与 2A-7 同批），平板三机只在手机发现偏差时补验（见 §5.1）？备选：三机静态只走平板（2A 在平板上按 1084／1085／1086 门图）。另请确认：C4 读屏实际听感抽测（2C，≥10 帽＋功能行六键）由用户亲自做，是否同意（不由 dump 冒充）？

## 附录 A：行号漂移对照表（`f51d1ad` → 2026-11-14 当前，HEAD `c3d74ea`）

第 13 批实施落地导致 `Index.ets` 由 4911 行涨到 5060 行。本稿正文行号引用以 `f51d1ad` 为准；实施时一切行号以当前代码为准。

| 锚点 | `f51d1ad` | 2026-11-14 当前 | 漂移 |
|---|---|---|---|
| `FontService.registerBundled` 调用 | L1205 | L1223 | ＋18 |
| `pushCnCursor()` | L750 | L753 | ＋3 |
| `measureStage()` | L1344 | L1362 | ＋18 |
| `recalcTravel()` | L1521 | L1539 | ＋18 |
| `stepCarriageLeft()` | L1543 | L1561 | ＋18 |
| `recalcPaperHeight()` | L1925 | L2003 | ＋78 |
| `animateArch()` | L2287 | L2365 | ＋78 |
| `leverPanStart()` | L2206 | L2284 | ＋78 |
| `commitChar()` | L2808 | L2916 | ＋108 |
| `onBackLine()` | L3016 | L3124 | ＋108 |
| `onPaperChange()` | L3084 | L3204 | ＋120 |
| `onNewline()` | L3180 | L3309 | ＋129 |
| TopBar 挂载 | L3770 | L3899 | ＋129 |
| PaperStage 挂载 | L4150 | L4279 | ＋129 |
| PhotoKeybed 挂载 | L4359 | L4488 | ＋129 |
| FunctionRow 挂载 | L4385 | L4515 | ＋130 |
| HomePage 挂载 | L4463 | L4596 | ＋133 |
| ExportPage 挂载 | L4708 | L4917 | ＋209 |
| OnboardingGuide 挂载 | （第 13 批 ④ 新增） | L5013–5014 | — |
| `cn_anchor` 锚点 TextInput | L3713 | L3843 | ＋130 |
| 根 Stack `onAreaChange` | L4898–4908 | L5047 | ＋149 |

附录 A 只覆盖 `Index.ets`；其他文件行号以函数名／符号为准（实施时以当前代码为准）。
