# Canvas Phase 0 探针报告（2026-11-13）

> 本批新证据改了上一批哪条结论、为什么改（本批上一批＝`docs/designs/15-Canvas渲染-可行性方案.md` v2）：
>
> 1. **§2.1 第 1 行「$rawfile 只接受编译期字符串常量」被推翻**。实测 SDK 26：`$rawfile(this.rawfileDynPath())`（方法返回字符串）**编译通过且运行时正确渲染**（截图 `1113_probe_dynamic_rawfile.png`，机身图完整显示）。因此「取图必须静态分支」不是编译器硬约束；P6 要求的「反例」在本 SDK 上**无法产生**。替代证据：仓内实现全部为静态字面量、两条静态取图路径均通过。
> 2. **§2.1 第 3 行「自定义字体能否进 Canvas 未知」由未知改判为可用**。P1 实测：`ctx.font='24vp CourierPrime'` 的 `measureText` 345.38 与隐藏 `Text` 参照 345.68 一致（refDelta 0.31vp ≤1），与 sans-serif 差 57.74vp ≥2 → 通过。官方 SDK 文档侧补：Canvas `font` 文档注明「Starting from API 20, this API is used to set registered custom fonts」，与实测一致。
> 3. **§4「60fps 级全屏重绘」风险由未知降为实测达标**。P2 实测换行 121.3fps／落字 120.3fps，单帧 draw p95 2ms（≤8ms），20 字无丢失。

## 执行摘要

- 探针页：`entry/src/main/ets/components/CanvasProbePage.ets`（临时件），Index 覆盖层栈新增 `probe` 分支、HomePage 临时调试入口（`home__canvas_probe`）；探针结束已删除分支与入口（见 §七 回归门）。
- 坐标与变换按 §1.4：参考机 673.7×1006.3vp，`scale=min(屏宽/673.7, 可用高/1006.3, 1.0)`；平板实测 scale=1.0000、canvas=673.7×1006.3vp（1600×2389.9px），`tx=0、ty=topInset=43.8vp(104px)`。
- 设备：平板 MLR-AL10 192.168.5.133:42355 全程完成 P1/P6/P2/P3/P4/P5 主项；**手机 ADA-AL00U 192.168.5.124:44879 被系统锁屏（指纹界面）挡住，无法自动解锁，手机侧六项均未跑**（截图 `1114_phone_locked_blocker.png`）。按「设备离线」口径记阻塞，需用户解锁手机后补跑。

## P1 字体（PASS，平板）

- 规格：测试串固定 `"Hello, World! 0123456789"`；`'24vp CourierPrime'` vs `'24vp sans-serif'` 同 Canvas `measureText`；隐藏 `Text`（同串/同字体/24vp/maxLines 1）＋`onAreaChange` 参照。
- 结果：`wC=345.38`、`wS=287.64`、`diff=57.74vp`（≥2 通过）；`ref=345.68`、`refDelta=0.31vp`（≤1 通过，且量法自证成立——Canvas 与 Text 同量级同单位 vp）。
- 截图：`1104_probe_p1_tablet.png`（上行等宽衬线 CourierPrime、下行比例 sans-serif，字形差异肉眼可辨）。
- 不符点：设计要求两台真机各跑一遍，手机锁屏未跑。

## P6 图片取图（PASS，平板，2/2）

- 取法 1：rawfile → 沙箱文件 → `new ImageBitmap(src)`：成功（`P6 ImageBitmap ok`）。
- 取法 2：rawfile → `getRawFileContentSync` → `image.createImageSource` → `createPixelMap` → `drawImage(PixelMap)`：成功（`PixelMap 2048x975`）。
- 截图：`1105_probe_p6_tablet.png`（上=ImageBitmap 机身图、下=PixelMap 键带图，均入画无拉伸）。日志：`PROBE P6 ok=2/2`。
- 反例：**未复现**（见 §0 第 1 条）；证据 `1113_probe_dynamic_rawfile.png` + 构建日志 `p6_rawfile_negative_build.log`（BUILD SUCCESSFUL，无 rawfile 报错）。
- 偏离说明：设计稿写「resourceManager.getMediaContent→…」，实际素材为 rawfile 不是 media 资源，改用 `getRawFileContentSync` + `ImageSource`（同一条解码链的下半段），记录为不符点。

## P2 帧率（PASS，平板）

- 规格：`@ohos.animator`（Animator，duration 1,000,000ms、easing linear）当帧时钟；静态层（真机身图＋真键带图）离屏缓存；纸层为离屏位图每帧平移合成；拨杆走 Canvas `rotate`；700ms 换行编排＋连续落字 20；逐帧时间戳 + draw 打点。
- 结果：
  - 换行：`frames=89 fps=121.3 avgDraw=0.78ms p95Draw=2.00ms maxDraw=2.00ms totalMs=709`（≥55fps、p95≤8ms 通过）。
  - 落字 20 字：`frames=314 fps=120.3 avgDraw=0.90ms p95Draw=2.00ms typed=20/20`（无丢失通过）。
  - §7.3 内部一致性：`scale=1.0000 fs=24 lh=42.35 paperTop=281.84 carriageTop=403.19 strikeLine=347.01 dPaper=0.04 dCarr=0.01 inPaper=1 crosses=1 rollOk=1`（两项偏差 ≤1vp 通过）。
- 截图：`1106_probe_p2_newline_mid.png`、`1107_probe_p2_typing_mid.png`（screenCap 单帧 400–500ms 大于 250–700ms 窗口，两张「尽力取」只作佐证；帧率结论以 hilog 采样为准，按 §8.1 口径不判 P2 失败）。

## P3 触摸（主项 PASS，平板 1920s；两项受自动化能力限制未验）

- 43 帽逐帽点按 3 次：129 次点击 → `hits=129、miss=0`；与期望序列比对 3 处「不一致」均为**日志分隔符解析伪差**（键帽标签 `;` 与坐标分隔符 `;` 冲突，日志解析把该帽标签拆错；实际命中日志为 `hit=;@2` 正确），非真实误触。误触率 0。
- 截图：`1103_probe_p3_caps_tablet.png`（43 金圈帽心覆盖在键带上）。
- 拨杆拖拽跟手：`swipe` 500ms 产生 `moves=91`；结束 `angle=19.1 drawnAngle=19.1 dAngle=0.00`（≤5° 通过）；`touchToFrameMs=1`（≤1 帧 8.3ms 通过）；每 Move 都重画（`P3 frame angle=… drawMs=0..1`）。
- 截图：`1108_probe_p3_lever_drag.png`。
- **未验 1：双指同时按下两帽**——`uitest` 无多点触控注入能力；替代证据：代码按 `e.touches` 全量分发并记录 `pointers`，但无法产生真实双指，故该项记「未验」。
- **未验 2：左边缘右滑系统返回**——`uitest swipe` 从 x=4 起，未触发系统返回（日志无 nav 变化），无法判定「被 Canvas 拦截」还是「uitest 不模拟系统边缘手势」；记未验。

## P4 输入（部分通过，平板；RESIZE/OFFSET 各一次）

- RESIZE（键盘空→弹起）：`before=673.7x1077.9` → `areaNow=677.1`（压缩 400.8vp，等于键盘高 952px/2.375=400.8vp）；`canvasBottomPx=1542.0 < kbTopPx=1608.0`，`overlapPx=-66.0`（无重叠，间隙 27.8vp）；`paperTopRef=281.84`（dPaperRef 0.04 ≤2vp）；光标矩形换算 `ref=336.9,303.8 → px=800.0,825.6`（= rectX0 + 336.85*1*2.375，rectY104 + 303.84*1*2.375，公式一致）。
- OFFSET（干净一次）：`before/after area=673.7x1077.9`（页面不被压缩）；键盘 `kbHpx=952`；焦点请求成功；`paperTopRef=281.84`（d 0.04）；光标 px 同上（用 RESIZE 前刷新的 rect 计算）。OFFSET 模式页面整体上移：另一次运行中 canvasBottom 随之上移为 1541.9px < kbTop 1608px（无重叠）。截图 `1111_probe_p4_resize_kb.png`、`1112_probe_p4_offset_kb.png`。
- 未验项：候选窗跟随光标（探针页无候选栏/内置拼音链路）、离页键盘不悬留（探针页未做离页流程）、「纸面底部与键盘顶部间距与预期值 ≤2vp」——本探针页不绘制真实纸面，只能给出 canvas 底与键盘顶的间隙（−27.8vp 表示 canvas 底在键盘上方 27.8vp），纸面几何需 Phase 2 版式承载；记不符点。

## P5 取证（主项 PASS，平板；转场截图与读屏项未验）

- `getComponentSnapshot`：第 1 次即成功，`1600×2390`，PNG `102225 bytes`；重试机制 3 次未用满（规格允许）。
- 两路截图比对：`screenCap` 裁剪 Canvas 区域（0,104,1600,2494）与组件快照**逐像素 mean abs diff = 0.00（max=0）**（≤5 通过）。为使比对成立，P5 运行时隐藏页内浮层（返回/标题/面板按钮/面板）——这是探针页的取证适配，记录为偏差。
- 盒子落位：变换矩阵 `tx=0.00 ty=43.79vp`、`w=1600.00 h=2389.91px` vs `getRectangleById` 实测 `x=0.00 y=104.00 w=1600.00 h=2389.91`，`dW=dH=0.00`（≤2vp 通过）。
- 转场：**未取得中途截图**（screenCap 单帧 400–500ms > 250ms 转场窗口；按 AGENTS 动画取证边界，该指标 screenCap 不可靠）；替代证据：转场实现只改 Canvas 盒子的 `position.x`（animateTo），而 P5 快照=盒内像素、与 screenCap diff=0，证明「内容跟随盒子」；精确转场需用户录屏。
- **读屏判定项未验**：探针页 Canvas 无无障碍覆盖层（按 §5.1 属 Phase 2 必做项），`uitest dump` 无 43 帽节点，无法抽测「10 帽＋功能行六键」朗读；若按设计稿「达不到即 P5 不通过」，则 P5 **不通过**（本报告不把它写成通过），补做条件：Phase 2 加透明原生按钮覆盖层后再测。

## P5 之外：手机侧

- 手机锁屏（指纹解锁界面，截图 `1114_phone_locked_blocker.png`），`keyevent 224/3/4`、上滑、启动 App 均无法越过锁屏；六项手机数据全缺。阻塞原因为「设备锁屏需人工解锁」，非编译/离线/包装问题，如实记；解除条件：用户解锁手机后补跑同一探针页。

## 截图号段（1100 起，均入 `docs/shots/`）

1100 探针页打开；1101/1104 P1（旧/新全屏版）；1102/1105 P6；1103 P3 帽图；1106/1107 P2 换行/落字中途；1108 P3 拨杆；1109 P5 screenCap；1110 P5 转场（未取到有效内容）；1111/1112 P4 RESIZE/OFFSET；1113 动态 $rawfile 反例（实际通过）；1114 手机锁屏。

## 结论（Phase 0 六项）

| 探针 | 平板 | 手机 | 结论 |
|---|---|---|---|
| P1 字体 | 通过（diff 57.74vp、refDelta 0.31vp） | 未跑（锁屏） | **有条件通过**（手机待补） |
| P6 取图 | 通过 2/2；反例未复现（动态 $rawfile 可用） | 未跑 | **通过**（设计稿「静态分支约束」结论被推翻） |
| P2 帧率 | 通过（121.3/120.3fps、p95 2ms、20/20、dPaper 0.04） | 未跑 | **有条件通过**（手机待补） |
| P3 触摸 | 43 帽 129/129 命中；拖拽 dAngle 0、1ms | 未跑 | **部分通过**（双指、边缘返回未验） |
| P4 输入 | RESIZE/OFFSET 几何与避让通过；候选跟随/离页/纸面几何未验 | 未跑 | **部分通过** |
| P5 取证 | 两路 diff 0.00、盒子 dW/dH 0；转场与读屏未验 | 未跑 | **不通过**（读屏判定项未达，按稿不得放行） |

Phase 1 裁定建议：**有条件可行（待补）**——P1/P2/P6 主项通过，P3/P4 主项通过但各缺 1–2 个自动化不可达项，P5 读屏项须 Phase 2 覆盖层；补跑手机侧后按设计稿 §8.2 三选一。

## 附：探针页改动清单（revert 前）

- 新增 `entry/src/main/ets/components/CanvasProbePage.ets`。
- `Index.ets`：`import CanvasProbePage`、`@State probeOpen`、`syncFromStack` 一行 `probeOpen = has('probe')`、覆盖层分支 `if (this.probeOpen) { CanvasProbePage(...) }`、HomePage 挂载传 `onOpenProbe`。
- `HomePage.ets`：`onOpenProbe` 字段＋临时入口 `home__canvas_probe`。
- 以上除 `CanvasProbePage.ets` 外，探针结束后已全部删除并经回归门（见自检记录第 15 批 §七）。

## 七、revert 与回归门（2026-11-13 18:51–19:05）

- 已删除：`Index.ets` 的 `CanvasProbePage` import、`probeOpen` 状态、`syncFromStack` 一行、覆盖层分支、HomePage 挂载传参；`HomePage.ets` 的 `onOpenProbe` 字段与临时入口 `home__canvas_probe`。`git diff` 对打字机渲染链无改动（仅 HomePage 行尾归一化差异，随后提交不含语义改动）。
- 回归门（平板 1920s，空纸 parts=281.8／123.4 已核对，连拍两帧四区 0.00%）：
  - 与设计稿指定旧基线 `1026_1920s_baseline30_tablet_v12.png`：keyboard **1.77% FAIL**、frame_left 0.52%、frame_mid 0.17%、frame_right 0.04%——**不是探针引入**：第 13 批已把键盘重排（Shift/Caps/Tab 等）与功能行 HUD 落地，1026 早于这些确定性视觉改动（第 13 批报告 §21 已记其重拍候选 1083）。
  - 与第 13 批当前候选 `1083_1920s_baseline30_tablet_v13b.png`：**keyboard 0.00% PASS**；frame_left/mid/right 仍 0.52/0.17/0.04%——diff 定位在**拨杆/哥特拱装配件**区域（见 diff 图），原因是本次机器切换走「设置→默认机器」路径造成的拨杆静止相位与 1083 拍摄路径（换装页切机）不同，属会话状态差，不是探针页代码（探针页全部代码已删，typewriter 渲染链 git diff 为空）。
  - 替代证据：同一状态下连拍两帧四区 **0.00%**；探针改动仅 HomePage 临时入口（文字行）与 Index 挂载分支，不触碰打字机组件，删除后无像素影响。**结论：探针未引入打字机像素回归；门图 1026 口径因第 13 批基线漂移无法在本批直接满足，按设计与第 13 批报告口径改用当前候选 1083 的 keyboard 区 + 连拍静止性作为回归证据，并记录不符点。**
- 截图：`1115_probe_revert_gate_1920s.png`。

## 八、手机侧补跑（2026-11-13 19:13–20:00，部分完成）

- 手机已解锁（此前锁屏阻塞解除），重新挂载探针页补跑：`P1`/`P6`/`P2` 完成，数值与平板同量级：
  - **P1（PASS）**：`wC=345.38、wS=282.02、diff=63.35vp ≥2`；`ref=345.48、refDelta=0.11vp ≤1`。截图 `1121_probe_phone_p1.png`（等宽衬线 vs 比例字形差异可见；该图同时暴露探针页画布只覆盖参考机高度、页面其余部分透明露出主页背景——探针页壳未铺满底色，属探针件外观问题，已记录）。
  - **P6（PASS）**：ImageBitmap＋PixelMap 两条路径 `ok=2/2`（PixelMap 2048×975）。截图 `1122_probe_phone_p6.png`。
  - **P2（PASS）**：换行 `frames=91 fps=122.0 p95Draw=1.00ms`；落字 `frames=314 fps=120.5 p95Draw=1.00ms typed=20/20`；一致性 `scale=0.5383 paperTop=123.05(dPaper 0.05) carriageTop=217.05(dCarr 0.05) strikeLine=182.05`，与 §7.3 手机验算值 123.0/217.0 误差 0.05vp ≤1vp。截图 `1123_probe_phone_p2.png`。
- **P3/P5/P4 手机侧未完成**：`hdc -t 192.168.5.124:44879 shell "uitest uiInput click …"` 在连续调用时反复返回 `[Fail]Not match target founded, check connect-key please`（同一会话内 `echo` 正常、`hdc list targets` 显示 Connected），已试：单发重试（命中 3/3 可用）、每 5 帽分块、每 3 帽分块、把点击串成设备侧单条 shell 命令（连 compound 也报同一错）、每次调用前 `hdc tconn` 重连。结论：**手机侧 hdc→uitest 的点击通道不稳定**，无法完成 129 次逐帽点按与 P5/P4 的多步交互；P3 手机侧已有部分命中日志（`p3_hits_phone.log`），不足以判定通过。
- 手机侧替代证据：P3 的命中数学与事件分发已在平板 129/129 验证；手机侧 P1/P6/P2 已证明 Canvas 尺寸变化下的渲染与帧率可用。P3/P5/P4 手机数据待 hdc 通道稳定后补跑。
