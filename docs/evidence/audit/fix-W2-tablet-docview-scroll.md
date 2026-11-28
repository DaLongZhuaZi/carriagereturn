# W2 修复批报告：平板文档视图滚动读全文（Q-1）

- 日期：2026-11-28
- 分支：`fix/w2-tablet-docview-scroll`（base `main` @ `9cf4220`，W1 已合 main）
- 工作树：`D:\HarmonyAPP\carriagereturn\.worktrees\audit05-w2`
- 依据：`docs/evidence/audit/item05-triage.md` §3 W2（Q-1，D-1 裁决 **A**：平板改 `Scroll`，与手机一致，同步改设计稿 §5.3）
- 构建：DevEco 26 hvigorw `assembleHap`（debug signed）→ **BUILD SUCCESSFUL in 26 s 510 ms**，43 tasks，0 ERROR；产物 `entry-default-signed.hap` 250,557,001 B（2026-11-28 17:23）
- 验证设备：平板 MLR-AL10 `192.168.5.133:42355`（1600×2560）；手机 ADA-AL00U `2UCUT24724009680`（1224×2776）
- 取证摘录：`docs/evidence/audit/w2_tablet_docview_verify.txt`

## 1. 改动

| 文件 | 改动 |
|---|---|
| `entry/src/main/ets/components/DocumentViewPage.ets` | ① `paperBodyTablet()`：删掉 `height('100%')` 的纸纹 `Image` 与正文 `maxLines(20)＋Clip`，改为 `backgroundImage` 纸纹＋正文按内容撑高，`constraintSize({ minHeight: '100%' })` 保证短内容仍撑满可视高度（与手机 F1 同一做法）；② `body()` 平板分支：正文列外包 `Scroll`（宽 = `(widthVp−56)/2`、高 100%、`scrollBar Off`、`edgeEffect None`、`align TopStart`），标题页仍固定左列、不参与滚动；③ 点正文 `onEdit` 保留。 |
| `docs/界面重设计稿.md` §5.3 | 「超出页底裁掉不许滚动出页；翻页走底栏加页」改为「按内容撑高、超出可视高度时在正文列内上下滚动读全文（平板与手机一致，2026-11-28 核查⑤ W2 / D-1 A 定，原裁切口径作废）；平板标题页固定左列、正文列独立滚动；加页仍是追加空行，不是翻页」。 |
| `docs/evidence/audit/item05-triage.md` | §3 W2 增加实施记录；D-1 标注已定 A。 |

- 改动统计：1 个源文件 +18/−9 行（净 +9）；设计稿 1 行替换；triage 同步记录。
- 未动：手机分支 `paperBodyPhone()`、`displayLinesOf()`（W1）、`DocStore`、导出/搜索路径。

## 2. 构建与安装

- 依赖：本树无 `oh_modules`，先 `ohpm install --all`（`ngf_framework` 为 `file:../ngf_framework` 依赖），依赖目录未入库。
- 构建命令：`hvigorw --mode module -p module=entry@default -p product=default -p buildMode=debug assembleHap`（`DEVECO_SDK_HOME=G:\DevEco Studio 26\DevEco Studio\sdk`）。
- WARN 均为既有（AudioService 能力、2in1 API、`document_view__body` 平板/手机两分支同 id）。
- 双机 `hdc install -r` 均返回 `install bundle successfully`。

## 3. 测试文档（平板，App 自身 UI 创建）

- 路径：卷宗 → 未归档 → 新建纸张 → 编辑；在打字机内用键帽（`uitest uiInput click` 点 dump 到的帽心）打 `x`＋RETURN，手动点 `↻` 换纸一次，之后 App 在纸满行时自动换纸。
- 文档：`doc-1795858049601-56401`（未归档，1920s-upright / letter / Special Elite）。
- 落盘结构：`sheets` 3 张归档纸（14 / 17 / 17 行）＋ 当前纸 3 行 = **51 显示行、4 纸**；最后一纸最后一行为 `end`。满足「大于 20 行、至少 2 纸」。
- 说明：文档视图显示行 = 归档纸（按换纸顺序）＋当前纸（W1 `displayLinesOf()`），与落盘结构一致。

## 4. 验真（自验）

| # | 验项 | 方法 | 结果 | 证据 |
|---|---|---|---|---|
| 1 | 平板 >20 行、≥2 纸 | 落盘 JSON + dump | 51 显示行 / 4 纸（3 归档 + 当前），末行 `end` | `w2_tablet_docview_verify.txt` |
| 2 | 文档视图可滚动 | dump 几何 | `document_view__body` = (819,284,1553,**3267**)，内容高 2983px > 视口 2077px（超出 906px） | 同上 |
| 3 | 顶部截图 | 打开即拍（未滚动） | 正文从第 1 行开始，纸底在屏外；标题页在左列 | `3980_w2_tablet_docview_top.png` |
| 4 | 滚到最后一纸最后一行 | 在正文列上滑两次后拍 | 末纸末行 `end` 出现在纸底；标题页位置像素不变（正文列独立滚动） | `3981_w2_tablet_docview_bottom.png` |
| 5 | 点正文仍进打字机 | 在已滚动态点正文 → dump + 截图 | `document_view__body` 消失，`p26_lid`/`p35_paper`/`p25_key_grid` 出现；纸面显示末纸三行 `x/x/end`（光标在 end 后） | `3982_w2_tablet_body_to_typewriter.png` |
| 6 | 短文档不塌（minHeight 100%） | 打开 aaa/bbb 两行文档 | `document_view__body` = (819,284,1553,**2361**)＝满视口，纸纹铺满右列 | `3984_w2_tablet_docview_short.png` |
| 7 | 手机回归 | 打开同一份 aaa/bbb 文档，与 W1 基线 3975 逐像素比对（排除顶部 120px 状态栏） | mean diff 1.18、max 48、>30 差 186/3,250,944 px（主要在状态栏与零星纹理）；布局一致 | `3983_w2_phone_docview_regression.png` |

- 滚动交互：`Scroll` 用 `scrollBar Off` + `edgeEffect None`（与手机一致）；拖拽滚动、轻点仍触发 `onClick`（第 5 项证明），二者不冲突。
- 截图编号 3980–3984，均在本批当前构建、平板/手机真机前台拍摄。

## 5. 缺口与说明

1. **未录屏**验证滚动惯性/回弹：`edgeEffect None` 本就无回弹，产品未要求录屏；滚动位移由 3980/3981 两图正文整体位移直接可见。
2. **纸纹观感变化**：纸纹由 `Image(Cover)` 改为 `backgroundImage(FILL)`（D-1 A 要求、与手机一致）。短文档对比 3973（旧）与 3984（新）：版式、文字位置不变，纹理缩放/明暗略有差异；若后续要求纸纹像素级一致，需另立基线仪式（本批未改纸纹素材）。
3. **手机只做布局回归**：手机分支本批未改（原本就是 `Scroll`），未在手机造长文复测滚动；如需双端长文对照可另排。
4. **自动换纸的 hilog 未留存**（缓冲轮转）：4 纸结构以落盘 JSON 为准；`newlineAtLastRow -> paperChange` 代码路径见 `Index.ets:4376-4381`。
5. 测试文档 `doc-1795858049601-56401` 留在平板设备，便于复核；未注入损坏 JSON 验证 `load()===null`（W1 同缺口，与本批无关）。

## 6. 复现命令

```bash
# 构建（本树）
ohpm install --all
DEVECO_SDK_HOME="G:\DevEco Studio 26\DevEco Studio\sdk" \
  hvigorw --mode module -p module=entry@default -p product=default -p buildMode=debug assembleHap
# 安装
hdc -t 192.168.5.133:42355 install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc -t 2UCUT24724009680 install -r entry/build/default/outputs/default/entry-default-signed.hap
# 取证辅助脚本（本批新增）
python tools/_w2_scroll.py build   # 在已打开的新纸上打 2 纸以上长文（键帽坐标来自 dump）
```
