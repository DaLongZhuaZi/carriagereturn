# F3 修复批：导出范围与入口（A183、R29、R30、R32、R7、R33、R31；R16 验收）

- 日期：2026-11-26
- 分支：`fix/export-scope`（base `main` @ `9277a00`）
- 工作树：`D:\HarmonyAPP\carriagereturn\.worktrees\fix-export-scope`
- 构建：DevEco 26 hvigorw `assembleHap`（debug，signed hap）
- 设备：手机 ADA-AL00U `2UCUT24724009680`、平板 MLR-AL10 `192.168.5.133:42355`（常亮已确认）

## 1. 改动（6 个文件，+121/−25）

| 文件 | 改动 |
|---|---|
| `ExportPage.ets` | ① `pagePlans()` 新增 `paper` 分支（当前纸＝最后一组，单页 1/1）；② text 分支按 `paper` 只导当前纸；③ 图片分支按范围取页（`paper` 取最后一组、页码 1/1），整篇/整卷宗仍取首纸；④ `fontFamilyOf()` 在 prefs 为空时回落 `CourierPrime`（R31）；⑤ 新增 `hasCustomFont()` 与开关下方说明；⑥ 新增 `logOut()` 与图片页日志（产物字节数/页码，验收取证，不改产物） |
| `Index.ets` | ① `prepareExport` 优先用有内容的模型，live 为空时读盘（R32）；新增 `docHasText()`；② 主页「导出」入口显式 `setExportTarget({docId: this.docId, scope:'doc'})`，不再沿用上次卷宗/文档（R7） |
| `DossierDetailPage.ets` | 手机端 ⋯ 菜单增加「导出」项并接到 `onExport(dossierId)`（R33）；平板页眉已有导出，不重复 |
| `string.json`（base／zh_CN／en_US） | 新增 `export_opt_font_hint` |

## 2. 验收结果

> 取证口径：导出时 app 自身 hilog 记录产物字节数/页码（`export out fmt=… range=… bytes=…`、`export out fmt=image page=n/m … first=…`、`export pdf pages=n`）。测试文档：两纸文档（归档纸 `aaa`、当前纸 `bbb`）。

| 验收项 | 结果 | 证据 |
|---|---|---|
| 当前纸 PNG＝当前纸内容 | **通过** | `export image page=1/1 lines=1 first=bbb`；`export out fmt=image range=paper bytes=2551355` |
| 当前纸 PDF 单页、页码 1/1 | **通过** | 手机 `export pdf pages=1`、平板 `export pdf pages=1`；`export out fmt=pdf range=paper bytes=2931530` |
| 当前纸纯文本＝当前纸 | **通过** | 手机 `export out fmt=text range=paper bytes=4`（`bbb\n`）；整篇 `bytes=30`（`aaa`＋分隔＋`bbb`） |
| 平板范围生效 | **通过** | 平板 paper `bytes=4`、doc `bytes=30`；paper PDF `pages=1` |
| 整篇 PDF 多页 | **通过** | 手机 `export pdf pages=2` |
| R32 冷启动未载入模型 | **通过** | 冷启动 → 卷宗→内页→文档视图→导出→当前纸→纯文本：`bytes=4`，无「这张纸还没有字」空态 |
| R7 主页导出目标 | **通过** | 先做整卷宗导出，再回主页进导出：`export target scope=doc dossier= docId=doc-1795631171340-96652`（不再沿用卷宗） |
| R33 手机内页菜单导出 | **通过** | ⋯ 菜单含「改名／新建纸张／导出／删除卷宗」（截图 3590）；点「导出」进导出页（`scope=dossier`，未归档无 dossierId 时回落按当前文档出） |
| R31 书写字体开关 | **通过** | 界面显示说明「未设置书写字体：开＝默认 Courier Prime，关＝系统字体」（截图）；实测 正文开时 PNG：字体开 `331516` vs 字体关 `330292`（不同） |
| R16 纯文本对 8 开关零影响 | **通过** | 8 开关全关 vs 默认全开：整篇 TXT 均 `bytes=30` |
| R16 图片受开关影响（逐项） | **通过** | 基线（正文开、字体关、其余关）PNG `330292`；单项开启后：标题 `337666`、机器框 `2529303`、日期 `343709`、页码 `332176`、纸张底色 `329387`、墨色 `330370`；另：正文开 `330292` vs 正文关（全关）`322266` |
| R16 PDF 受开关影响 | **通过** | 默认（全开）paper PDF `bytes=2931530`；标题关后 `bytes=2923389`（不同） |

## 3. 观察与未覆盖

1. **未归档没有 dossierId**：手机内页 ⋯「导出」在未归档上会以空 dossierId 打开导出页，实际回落按当前文档导出（只能选当前纸/整篇，无整卷宗）。具名卷宗不受影响。若要给未归档补整卷宗语义，需另裁。
2. **PNG 产物未做肉眼比对**：设备文件区不可被 shell 读取（`/storage/User/...` Permission denied），产物只以字节数＋页码＋首行内容取证；PNG 的可见内容由模板日志 `first=bbb` 与页码 `1/1` 佐证。
3. **R16 图片逐项**是在「正文开、字体关」基线上单开各项测得的字节数；PDF 侧只测了默认 vs 标题关（PDF 由同一模板合成）。
4. 两台设备各留一篇两纸测试文档（`aaa`/`bbb`），未清理。

## 4. 截图（`docs/shots/`，3586 起）

| 编号 | 文件 | 内容 |
|---|---|---|
| 3586 | `3586_f3_phone_export_page.png` | 手机导出页（范围/格式/保存） |
| 3588 | `3588_f3_phone_menu_export_page.png` | 从内页 ⋯「导出」进入的导出页 |
| 3589 | `3589_f3_phone_home_export_target.png` | 主页导出（目标为当前文档） |
| 3590 | `3590_f3_phone_detail_menu.png` | 手机内页 ⋯ 菜单含「导出」 |
| 3591 | `3591_f3_tablet_export_page.png` | 平板导出页 |

## 5. 提交

- 分支 `fix/export-scope`：6 个文件 + 本报告 + 截图。不合 main、不推 main、不改清单。
