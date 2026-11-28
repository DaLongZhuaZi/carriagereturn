# W3 修复批报告：拨杆死代码清理（Q-3，D-2=A）

- 日期：2026-11-28
- 分支：`fix/w3-lever-deadcode`（base `main` @ `0c1ea6d`，W4 已合 main）
- 工作树：`D:\HarmonyAPP\carriagereturn\.worktrees\audit05-w3`
- 依据：`docs/evidence/audit/item05-triage.md` §3 W3（Q-3；D-2=A）
- 提交：见分支 HEAD（本报告与截图随后续提交入库）

## 1. 改动

### 1.1 `entry/src/main/ets/pages/Index.ets`（+2 / −113 行）

按 triage §2 Q-3 清单删除批39 退役后残留的拨杆消费端：

| 删除项 | 原位置（base `0c1ea6d`） |
|---|---|
| `import { dragRatioFor, pulledEnough, restDegFor, swingDegFor } from '../model/LeverAngleCore'` | L98（删后四个符号在 Index 均无消费者） |
| `nextEpoch, shouldResetOnSwitch`（保留 `slotOf`） | L103 |
| `@State leverRatio1920/1930/1950/1960`、`leverEpoch`、`canvasLeverReleaseTick`、`canvasLeverReleaseCommit`、`private leverDragActive`、`private leverRatioLogical` | L215–228 |
| `@State leverAngleVp`（只写不读） | L256 |
| `applyMachine()` 里 `prevKind` 与 `shouldResetOnSwitch(...)` 重置块 | L2443、L2475–2479 |
| `leverRatio()` / `setLeverRatio()` | L2831–2856 |
| `resetLeverStates()`、`leverPanStart()`、`leverPanUpdate()`、`leverPanEnd()`、`leverHForDrag()` | L2863–2922 |
| `tickFrame()` 里 `leverAngleVp = restDegFor(false) + swingDegFor(false) * leverRatioLogical` | L3752 |

保留（按任务书）：

- `newlineTick1920/1930/1950/1960`、`newlineTick()`、`bumpNewlineTick()` 与 `slotOf`——换行代际守卫仍在用（`Index.ets` 清理后读取点 L4240/L4281/L4323/L4334/L4336）。
- `canvasEnabled`（`private readonly = false`）及其 3 处历史分支（`resetCarriage`/`onBackLine`/换行编排）原样保留，注释未改。
- 模型文件 `model/LeverAngleCore.ets`、`model/LeverStateCore.ets` 未改（纯函数；`lever-state.test.mjs` 9 项仍绿）。
- `leverW()`/`pinXRel()`/`pinYRel()` 未在删除清单内，保留（仍在 `parts`/`assembly` hilog 中作为几何打点使用）。

### 1.2 测试同步

| 文件 | 改动 |
|---|---|
| `tools/tests/lever-angle.test.mjs` | ① 原 L74–89「四份渲染件都从 LeverAngleCore 取常量」的四个 `LeverLayer*.ets` 已于批39 删除，断言改为**四份渲染件不得复活**（`!existsSync`）；② 原 L91–99 的四机 `leverAspect/pivot` 断言按 `MachineCatalog` 当前五机实际值更新：aspect `[0.2125, 0.3264, 0.09, 0.12, 0.2125]`、pivotX `[0.5, 0.538, 0.496, 0.502, 0.5]`、pivotY `[0.952, 0.96, 0.942, 0.948, 0.952]`。其余纯函数断言未动（9/9 PASS）。 |
| `tools/tests/lever-direct-p17.test.mjs` | **删除**。文件顶部 `read('entry/src/main/ets/components/CanvasTypewriter.ets')` 读的是批64 已删除文件，基线即整文件红（5 项全失败）；其余断言对象为本次删除的 `leverPan*`/`leverRatioLogical`/`canvasLeverRelease*`/`leverHForDrag`。仓内 `docs/自检记录.md:4295/4323` 已登记该文件「断言已删除符号，需改断言」。 |
| `tools/tests/lever-gate.test.mjs` | **删除**。5 项中 4 项断言批39 已删除的四份 `LeverLayer*.ets` 与 Index 的 `dragRatio: this.leverRatio()` 接线（基线 4 红），仅剩的 1 项是「1920s/LeverLayer.ets 不存在」阴性断言；整文件属同一退役链路。 |

- 未削弱任何仍成立的行为断言；删除的两个文件全部断言对象在基线已不存在（详见 §3 基线对照）。

## 2. 构建

- 依赖：本树无 `oh_modules`，先 `ohpm install --all`（`ngf_framework` 为 `file:../ngf_framework`），依赖目录未入库。
- 命令：`hvigorw --mode module -p module=entry@default -p product=default -p buildMode=debug assembleHap`（`DEVECO_SDK_HOME=G:\DevEco Studio 26\DevEco Studio\sdk`）
- 结果：**BUILD SUCCESSFUL in 1 min 5 s 202 ms**，43 tasks，0 ERROR；WARN 均为既有（AudioService 能力、2in1 API、`document_view__body` 重复 id）。
- HAP（debug signed）：
  - 清理前（`0c1ea6d` 本树重建）：**137,281,583 B**
  - 清理后（`99d9a14`）：**137,254,173 B**（−27,410 B，纯 ABC 代码量减少）
- 双机 `hdc install -r` 均返回 `install bundle successfully`。

## 3. 单测

命令：`node --experimental-strip-types --test tools/tests/*.mjs`（Node v26.13.1，TAP reporter）。

| 时点 | pass | fail | 失败集合 |
|---|---:|---:|---|
| 基线（`0c1ea6d`，改动前） | 169 | 16 | `lever-angle` 2 项、`lever-gate` 4 项、`lever-direct-p17` 整文件、`arch-single-drive-p20`/`frame-clock-p17`/`gpu-crash-fix`/`knob-static` 整文件、`customize`/`stats-static`/`anchorId` 等既有红 |
| 清理后（`99d9a14`） | 170 | 9 | 基线失败集合减去本批修/删的 7 项；**新增红 0**（`comm -13` 基线 vs 终态失败清单为空） |

- `lever-angle.test.mjs` 单跑：**9 tests / 9 pass / 0 fail**。
- 剩余 9 项红均为基线既有（Canvas 时代静态测试与 customize/stats 断言），不在本批范围。

## 4. 验真：双机 A/B smoke（像素一致）

### 4.1 方法

为排除「清理前状态」不可复现的问题，做真 A/B：

1. 用 `0c1ea6d` 重建 HAP（`before.hap`），装双机；
2. 用 `99d9a14` 构建 HAP（`after.hap`），装双机；
3. 每个 run 先 `bm clean -n com.dlzz.carriagereturn -d` 清 App 数据，保证同一初态；冷启动、跳过引导；
4. 同一脚本、同一序列、全部点击由 `uitest dumpLayout` 按 id／无障碍文本定位（不写死坐标）：
   首页 → 开始打字 → 空纸 → 点 `Q` → 点 `⏎` → 点 `↻` → 返回首页 → 设置「默认机器」（1920s→1930s）→ 返回 → 再进打字机 → 打字机左上返回拨杆 → 首页；
5. 每步 `snapshot_display` 截图，双机各 8 态。

截图编号（`docs/shots/`）：

| 设备 | before | after |
|---|---|---|
| 平板 MLR-AL10 | 4021–4028 | 4037–4044 |
| 手机 ADA-AL00U | 4029–4036 | 4045–4052 |

### 4.2 结果

逐像素比对（max 通道差；统计 >30 的像素数，全图与「排除顶部状态栏 5%」的正文区）：

| 设备 | 状态 | 尺寸 | mean | max | >30 全图 | >30 正文区 |
|---|---|---|---:|---:|---:|---:|
| 平板 | home | 1600×2560 | 0.0334 | 240 | 803 | **0** |
| 平板 | typewriter_empty | 1600×2560 | 0.0075 | 43 | 309 | **0** |
| 平板 | typed_q | 1600×2560 | 0.0065 | 44 | 258 | **0** |
| 平板 | after_return | 1600×2560 | 0.0064 | 42 | 245 | **0** |
| 平板 | after_paper | 1600×2560 | 0.0059 | 43 | 215 | **0** |
| 平板 | machine_switch_settings | 1600×2560 | 0.0441 | 225 | 1132 | **0** |
| 平板 | machine_switch_typewriter | 1600×2560 | 0.0015 | 6 | 0 | **0** |
| 平板 | after_back_home | 1600×2560 | 0.0474 | 226 | 1204 | **0** |
| 手机 | home | 1224×2776 | 0.1126 | 226 | 2330 | **0** |
| 手机 | typewriter_empty | 1224×2776 | 0.0122 | 41 | 213 | **0** |
| 手机 | typed_q | 1224×2776 | 0.0138 | 41 | 283 | **0** |
| 手机 | after_return | 1224×2776 | 0.0168 | 41 | 162 | **0** |
| 手机 | after_paper | 1224×2776 | 0.0141 | 41 | 262 | **0** |
| 手机 | machine_switch_settings | 1224×2776 | 0.0785 | 221 | 1670 | **0** |
| 手机 | machine_switch_typewriter | 1224×2776 | 0.0054 | 26 | 0 | **0** |
| 手机 | after_back_home | 1224×2776 | 0.0822 | 225 | 1690 | **0** |

- **16/16 对截图在正文区（状态栏以下）>30 像素数均为 0**；全部 >30 差异的 y 范围：平板 56–86（状态栏，5% 线=128）、手机 67–113（状态栏，5% 线=138），即差异只在状态栏时钟/网速/通知图标，**产品画面零像素变化**。
- 功能确认（截图＋hilog）：两轮均出现 `committed ch=[q]`、`paperChange start`；设置页「默认机器」由 1920s 循环为 `1930s 便携式`，再进打字机的机身配色随之为 1930s（4027/4043 一致，max diff 6）。
- 附带观察（非回归，双版本一致）：换纸后从首页再进打字机，纸面会恢复上一次已落盘内容（`q`），这是既有「换纸清空不落盘」行为（`Index.ets` `flushSave` 空文档守卫），A/B 两轮表现相同。

### 4.3 代码检索验真

清理后在本树对代码文件（`*.ets/*.ts/*.mjs/*.js`，排除 `build/`、`node_modules/`）执行：

```
grep -rn 'leverPan|leverDragActive|leverRatioLogical|leverAngleVp|leverEpoch|canvasLeverRelease' → 0 命中
grep -rn 'leverRatio|setLeverRatio|resetLeverStates|leverHForDrag'                              → 0 命中
```

（文档中的历史记录仍会提到这些符号名，属留档文字，不是代码引用。）

## 5. 缺口与说明

1. **A/B 使用 `bm clean`**：两轮都清空了 App 数据，W1/W2 留在设备上的测试文档一并清除；这是为取得同一初态，特此披露。
2. **状态栏像素不复现**：A/B 之间时钟、网速、通知图标必然不同，比对口径为「排除顶部 5% 状态栏」；这与 AGENTS §5 门图的「状态栏除外」一致。
3. **死代码无交互可测**：被删链路在 type26 主屏无调用点（批39 起），无法也无需做「拖拽拨杆」交互验证；本批以静态 grep＋单测＋双机画面 A/B 为证。
4. **剩余 9 项既有红未处理**：`arch-single-drive-p20`／`frame-clock-p17`／`gpu-crash-fix`／`knob-static`（Canvas 时代静态测试）与 customize/stats 断言，均与本批无关，属后续清理项。
5. 未改数据模型、未删用户数据路径；仅删除 App 测试数据（见缺口 1）。

## 6. 复现命令

```bash
# 构建（本树）
ohpm install --all
DEVECO_SDK_HOME="G:\DevEco Studio 26\DevEco Studio\sdk" \
  hvigorw --mode module -p module=entry@default -p product=default -p buildMode=debug assembleHap
# A/B smoke（脚本不在仓内，逻辑见 §4.1）
python smoke.py before tablet 4021
python smoke.py before phone  4029
hdc -t 192.168.5.133:42355 install -r after.hap
hdc -t 2UCUT24724009680  install -r after.hap
python smoke.py after  tablet 4037
python smoke.py after  phone  4045
```
