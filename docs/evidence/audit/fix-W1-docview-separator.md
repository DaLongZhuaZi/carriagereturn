# W1 修复批报告：文档视图去分隔行（Q-2）

- 日期：2026-11-28
- 分支：`fix/w1-docview-separator`（base `main` @ `a92b02b`，核查⑤-2 分流裁决已合 main）
- 工作树：`D:\HarmonyAPP\carriagereturn\.worktrees\audit05-w1`
- 依据：`docs/evidence/audit/item05-triage.md` §3 W1（Q-2）
- 构建：DevEco 26 hvigorw `assembleHap`（debug，signed hap），产物 `entry/build/default/outputs/default/entry-default-signed.hap`（250,557,085 B，2026-11-28 16:57）
- 验证设备：平板 MLR-AL10 `192.168.5.133:42355`（1600×2560）；手机 ADA-AL00U `2UCUT24724009680`（1224×2776）

## 1. 改动

| 文件 | 改动 |
|---|---|
| `entry/src/main/ets/components/DocumentViewPage.ets` | `load()` 不再 `readPlainText()`；改 `docStore.load(this.docId)` 取 `DocData`，新增 `displayLinesOf()` 按 `data.sheets`（归档纸，换纸顺序）＋`data.lines`（当前纸）展平为显示行，不插入任何分隔行；标题取 `DocSummary.title`，找不到摘要再回落首行。`readPlainText` 保留给导出与搜索，未改。 |

- 改动统计：1 个源文件，+30/−5 行。
- 未新增 `DocStore` 接口（页内直接用已有 `load()`）；`readPlainText`／`plainTextOf`／`sheetSeparatorText`／导出与搜索路径均未触碰，因此 `.txt` 孪生与 TXT 导出仍含分隔行。
- 结构化数据本身不含分隔行，故未使用任何正则过滤，不存在误伤用户正文的风险。

## 2. 构建与安装

- 依赖：本树无 `oh_modules`，先跑 `ohpm install --all`（`ngf_framework` 为 `file:../ngf_framework` 依赖），依赖目录未入库。
- 构建命令：`hvigorw --mode module -p module=entry@default -p product=default -p buildMode=debug assembleHap`（`DEVECO_SDK_HOME=G:\DevEco Studio 26\DevEco Studio\sdk`）→ **BUILD SUCCESSFUL in 23 s 201 ms**，43 tasks 全部执行，0 ERROR。
- WARN 均为既有：`AudioService` 的 media/audio 能力告警、2in1 API 告警、`document_view__body` 重复 id（平板/手机两个分支同 id，同一时刻只渲染一个）。
- 双机 `hdc install -r` 均返回 `install bundle successfully`。

## 3. 测试数据（双机同一份 2 纸文档）

双机均从「卷宗 → 未归档 → 新建纸张 → 编辑」创建空白文档，打字机内输入 `aaa` → 点功能行「↻ 换纸」→ 输入 `bbb`，由 App 自身保存链路落盘：

| 设备 | 文档 id | 归档纸（sheets） | 当前纸（lines） | sheetNo/sheetCount | 列表标题 |
|---|---|---|---|---|---|
| 平板 | `doc-1795856442723-73990` | `[["aaa"]]` | `["bbb"]` | 2 / 2 | `bbb` |
| 手机 | `doc-1795856550822-78825` | `[["aaa"]]` | `["bbb"]` | 2 / 2 | `bbb` |

设备落盘 JSON（`hdc shell cat .../files/documents/<id>.json`）确认结构与上表一致；两机的 `.txt` 孪生（`files/documents-text/<id>.txt`）均为：

```
aaa
--- 第 1 / 2 纸 ---
bbb
```

即存储/导出格式仍带分隔行，而阅读视图读的是结构化 JSON。

## 4. 验真结果（双机）

| 验收项 | 结果 | 证据 |
|---|---|---|
| 文档视图正文无 `--- 第 n / N 纸 ---` 分隔行 | **通过** | 平板 3973、手机 3975；双机 `dumpLayout` 中 `document_view__body` 的 text 原文为 `aaa\nbbb`，dump 内无任何「第 … 纸」分隔行节点 |
| 归档纸＋当前纸文字齐全且顺序正确 | **通过** | 同上：先 `aaa`（归档纸）后 `bbb`（当前纸），两行都在，无缺失 |
| 标题与列表一致 | **通过** | 列表卡片标题 `bbb`（平板 3977、手机 3978）；文档视图标题页同为 `bbb`（3973/3975）。旧实现取 `.txt` 首行会显示 `aaa`，本批已改为 `DocSummary.title`，与列表同源 |
| 点正文仍进打字机（A78/F1 回归） | **通过** | 平板 `nav depth=4 top=docview` → 点正文 → `nav depth=5 top=typewriter`（17:03:27 → 17:04:02），截图 3974 纸面为 `bbb`；手机同样 `depth=4 → depth=5`（17:04:25 → 17:04:35），截图 3976 |
| 导出 TXT 仍含分隔行（真实导出＋读设备落盘文件） | **通过** | 双机走完整 UI：文档视图「导出」→ 范围「整篇」→ 格式「纯文本」→「保存到本地」→ 系统「选择路径」保存到 Download。导出文件各 30 B，内容逐字节为 `aaa\n--- 第 1 / 2 纸 ---\nbbb\n`；已回收到 `docs/evidence/audit/w1_export_tablet_bbb.txt` / `w1_export_phone_bbb.txt` |
| 单纸旧文档回归（无 `sheets` 字段） | **通过** | 平板 `doc-1795690491736-69450`（标题 `q`，1 纸）文档视图正文仅 `q`、标题 `q`，截图 3979 |

导出文件名与 hilog：

- 平板：`/storage/media/100/local/files/Docs/Download/回车-bbb-20261128-170821.txt`（30 B）
- 手机：`/storage/media/100/local/files/Docs/Download/回车-bbb-20261128-170716.txt`（30 B）
- `ExportPage: export save start format=text`（平板 17:08:21.720／手机 17:07:16.101）
- `MainScreen: export saved format=text`（平板 17:08:48.841／手机 17:07:43.294）

## 5. 截图索引（`docs/shots/`）

| 编号 | 文件 | 内容 |
|---|---|---|
| 3973 | `3973_w1_tablet_docview_2sheets.png` | 平板·2 纸文档视图：标题页 `bbb`，正文 `aaa`/`bbb`，无分隔行 |
| 3974 | `3974_w1_tablet_body_to_typewriter.png` | 平板·点正文后进打字机，纸面 `bbb` |
| 3975 | `3975_w1_phone_docview_2sheets.png` | 手机·同一份 2 纸文档视图（标题 `bbb`、正文 `aaa`/`bbb`、无分隔行） |
| 3976 | `3976_w1_phone_body_to_typewriter.png` | 手机·点正文后进打字机，纸面 `bbb` |
| 3977 | `3977_w1_tablet_list_title_bbb.png` | 平板·未归档列表：卡片标题 `bbb`（3 字） |
| 3978 | `3978_w1_phone_list_title_bbb.png` | 手机·未归档列表：卡片标题 `bbb`（3 字） |
| 3979 | `3979_w1_tablet_docview_1sheet.png` | 平板·单纸旧文档（`q`）文档视图回归 |

## 6. 单元测试

- `node --experimental-strip-types --test tools/tests/export-multipage.test.mjs tools/tests/docstore-state.test.mjs tools/tests/docstore-trash.test.mjs` → **17 pass / 0 fail**（含 `assembleSheetText` 分隔行断言、`sheetSeparatorText` 字面断言，证明导出格式未变）。
- 未新增页面级单测：本仓 ArkTS UI 无测试桩，本批验收口径为构建＋双机 dump/截图＋设备落盘文件。

## 7. 观察与缺口（如实说明）

1. **导出验证走了真实 UI 与系统 picker**：保存位置为双机 Download，文件从设备 `hdc file recv` 回收后逐字节核对（30 B，分隔行在）。未额外验证「分享」通道，但其与保存共用 `readPlainText` 同一文本源，口径不变。
2. **未做平板 >20 行长文阅读**：属 W2（Q-1，`maxLines(20)`＋不滚动）范围，本批按任务书不动；3973/3979 仍可见平板正文 20 行封顶行为。
3. **测试数据留在设备**：双机「未归档」各新增 1 份 `bbb` 文档（2 纸），Download 各留 1 个导出 TXT（30 B）。未删除，便于复核；如需恢复验证前数据可删这两份文档。
4. **未构造损坏 JSON 场景**：`docStore.load()` 返回 null 时页面显示空正文并回落标题（`未命名`/摘要标题），该分支仅代码走查，未真机注入坏文件。
5. 双机打字机顶栏状态栏区域存在既有的浅色残影（与 ⑤-1 截图 3963 同款，非本批引入，与本改动无关）。

## 8. 提交

- 分支 `fix/w1-docview-separator`：源码 1 文件＋本报告＋`item05-triage.md` W1 实施记录＋截图 3973–3979＋两个导出 TXT 证据文件。
- 只推分支，不合 main。
