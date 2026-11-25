# F1 修复批：回打字机＋手机文档视图（A56、A78、R21、R24、R23）

- 日期：2026-11-26
- 分支：`fix/nav-docview`（base `main` @ `38a63f8`）
- 工作树：`D:\HarmonyAPP\carriagereturn\.worktrees\fix-nav-docview`
- 构建：DevEco 26 hvigorw `assembleHap`（debug，signed hap），产物 `entry/build/default/outputs/default/entry-default-signed.hap`（2026-11-26 00:34，284 MB，含调试符号）
- 验证设备：手机 ADA-AL00U `2UCUT24724009680`（USB）；平板 MLR-AL10 `192.168.5.133:42355`（TCP，2026-11-26 01:10–01:15 复验，见 §7）。

## 1. 改动

| 文件 | 改动 |
|---|---|
| `Index.ets` `popTo()` | 栈内没有目标页时改为**压栈一层**（不再直接 return）；`typewriter` 压栈后触发 `playPaperLoad()`；调用方仍先 load 再切页 |
| `Index.ets` 新增 `typingOnTop()` ＋ 3 处渲染守卫 | 打字机在栈顶时，卷宗页／卷宗内页／文档视图不再叠在它上面；返回后自动恢复 |
| `DocumentViewPage.ets` | 手机分支重写：标题页固定 240vp、正文页 `layoutWeight` 占剩余并套 `Scroll`；正文纸改用 `backgroundImage` 以免 `height('100%')` 的 Image 在自适应高度里把正文压成 0；正文区新增 id `document_view__body`；平板 Row 分支原样保留（拆成 `paperBodyTablet`） |
| `DossierDetailPage.ets` | 空态文案按机型分流：手机指向「⋯ → 新建纸张」 |

改动统计：3 个源文件，+103/−33 行。

## 2. 验收结果（手机）

| 验收项 | 结果 | 证据 |
|---|---|---|
| 主页→卷宗→未归档内页→点「打开」落到打字机 | **通过** | hilog `nav depth=4 top=typewriter`（00:40:12.598）；dump 纸面文本 `[a] b=[335,912][807,1031]`，与所点纸（`a`，1 字）一致；截图 3554 |
| 纸上内容等于所点那张纸 | **通过** | 同上；另一张纸是「未命名」0 字，未误载 |
| 返回键回内页 | **通过** | hilog `nav depth=3 top=detail`（00:40:19.002）；dump 仍有 `dossier_detail__list` 与两个 `open_doc-*`；截图 3555 |
| 反复进出 3 次栈不错乱 | **通过** | 三轮全部 `depth 4 typewriter → depth 3 detail`（00:40:57/00:41:01、00:41:03/00:41:07 等），无深度漂移 |
| 文档视图点正文进打字机 | **通过** | 点正文后 `nav depth=5 top=typewriter`（00:42:48.848）；返回 `depth=4 top=docview`（00:42:55.258）；截图 3557 |
| 手机能同时看到标题页与正文页 | **通过** | 截图 3556：标题页在上（含标题 `a`、未归档、照片位），正文页在下，纸纹与正文可见 |
| 正文高度 > 0 且可点 | **通过** | dump：`document_view__body` bounds `[68,1255][1157,2494]`，高 1239px，`clickable=true` |
| 平板并排布局不变 | **通过** | 见 §7：标题页左、正文页右，正文占满右列；截图 3568 |
| 主页「继续写作」进打字机、返回主页 | **通过** | `depth=2 top=typewriter`（00:43:19.253）→ `depth=1 top=home`（00:43:22.812） |
| 文档视图返回、内页返回、卷宗返回 | **通过** | 连按三次：`depth=3 detail → depth=2 dossier → depth=1 home`（00:42:59–00:43:02）；截图 3558 |
| R23 手机空态文案 | **通过** | 手机未命名卷宗空态：「这里还没有纸。点右上角「⋯」→「新建纸张」放一张进来。」（3567）；平板同页仍为原文案（3566） |

## 3. 截图索引（`docs/shots/`）

| 编号 | 文件 | 内容 |
|---|---|---|
| 3551 | `3551_f1_phone_home.png` | 手机主页（起始） |
| 3552 | `3552_f1_phone_dossier.png` | 卷宗页（未归档 2 张纸、测试卷宗二号 2 张纸） |
| 3553 | `3553_f1_phone_detail.png` | 未归档内页（两张纸、两个「打开」） |
| 3554 | `3554_f1_phone_a56_open_typewriter.png` | 点「打开」后打字机页，纸面 `a` |
| 3555 | `3555_f1_phone_a56_back_to_detail.png` | 返回键回到内页 |
| 3556 | `3556_f1_phone_a78_docview_body.png` | 手机文档视图：标题页＋正文页同屏 |
| 3557 | `3557_f1_phone_a78_body_to_typewriter.png` | 点正文后进打字机（纸面 `a`） |
| 3558 | `3558_f1_phone_back_home.png` | 逐级返回到主页 |
| 3562 | `3562_f1_tablet_a56_detail.png` | 平板·卷宗内页（未归档，1 张纸） |
| 3563 | `3563_f1_tablet_a56_open_typewriter.png` | 平板·点「打开」进打字机，上层页面已隐藏 |
| 3565 | `3565_f1_tablet_a78_body_to_typewriter.png` | 平板·点正文进打字机 |
| 3566 | `3566_f1_tablet_r23_empty_dossier.png` | 平板·空卷宗文案（仍指「新建纸张」） |
| 3567 | `3567_f1_phone_r23_empty_dossier.png` | 手机·空卷宗文案（指「⋯」） |
| 3568 | `3568_f1_tablet_after_idle_awake.png` | 平板·静置 11 分 38 秒后仍亮屏 |
| 3569 | `3569_f1_tablet_a78_docview_clean.png` | 平板·文档视图并排布局（无引导） |

## 4. 关键 hilog 原文

```
11-26 00:40:02.892 MainScreen: nav depth=2 top=dossier
11-26 00:40:07.705 MainScreen: nav depth=3 top=detail
11-26 00:40:12.598 MainScreen: nav depth=4 top=typewriter   ← 打开（压栈）
11-26 00:40:19.002 MainScreen: nav depth=3 top=detail       ← 返回回内页
11-26 00:41:09.730 MainScreen: nav depth=4 top=docview
11-26 00:42:48.848 MainScreen: nav depth=5 top=typewriter   ← 点正文
11-26 00:42:55.258 MainScreen: nav depth=4 top=docview
11-26 00:43:02.411 MainScreen: nav depth=1 top=home
```

## 5. 观察与残留

1. **标题页日期文字对比度低**：标题页底色 `#eee4ce`，日期文字 `rgba(232,221,201,0.6)`（浅米色），截图 3556 里几乎看不见。这是既有设计（平板同样存在），不是本批引入；已记下，未改。
2. **标题页占屏比例**：手机标题页固定 240vp（约 810px，占内容区约 38%），下方正文区可滚动。若设计希望标题页更矮，只需调 `titleSheet(..., 240)` 的数值。
3. **平板已复验**（见 §7）：Row 分支并排布局、三处守卫、A56/A78、R23 平板文案均通过。
4. 构建产物与 `oh_modules` 均在 worktree 内，未入库；`ngf_framework/BuildProfile.ets` 只有换行符差异（内容未变），未提交。

## 6. 提交

- 分支 `fix/nav-docview`，只含 3 个源文件、本报告与 8 张截图。不合 main、不推 main。

## 7. 平板复验（2026-11-26 01:10–01:15）

设备：MLR-AL10 `192.168.5.133:42355`（TCP），1600×2560；数据：未归档 1 张纸（458 字，内容为 q）。

| 项 | 结果 | 证据 |
|---|---|---|
| 打开→打字机 | **通过** | `nav depth=4 top=typewriter`（01:11:33.590）；dump 纸面为 q 串（14 个文本节点） |
| typingOnTop 三处守卫 | **通过** | 打字机在栈顶时 dump 中 `dossier__list`=0、`dossier_detail__list`=0、`document_view__*`=0（修复前这三层都会渲染在打字机之上） |
| 返回回内页 | **通过** | `depth=3 top=detail`（01:12:26.854）；dump 恢复 `dossier_detail__list`=2、`dossier__list`=1 |
| 文档视图打开 | **通过** | `depth=4 top=docview`（01:12:32.073）；dump：`document_view__content [0,284][1600,2361]`、`document_view__delete_btn [0,2361][1600,2494]` |
| 平板并排布局 | **通过** | 截图 3569（无引导）：标题页左列、正文页右列；正文文本节点 `[819,284][1554,1500]`（宽 735、高 1216），纸纹与正文完整（注：原稿引用的 3564 未入库、3568 实为静置后卷宗页，Kit 验真时已纠正为 3569） |
| 点正文进打字机 | **通过** | `depth=5 top=typewriter`（01:14:19.622）；返回 `depth=4 top=docview`（01:14:25.317） |
| R23 平板文案 | **通过** | 新建空卷宗「未命名卷宗」0 张纸，空态仍为「点右上角「新建纸张」」（3566） |

补充：平板首次进入文档视图会自动弹引导，点正文的第一下先关闭引导（与 A204 同一行为），第二下才进打字机——01:13 那次没跳转是这个原因，不是缺陷。

测试数据清理：验证用的「未命名卷宗」已删除（0 张纸，选「连纸一起删」无损失）；删后卷宗页仍显示陈旧卡片（R20 已记录），重进卷宗页后消失。两台设备均恢复为验证前数据（平板 未归档 1 张；手机 未归档 2 张、测试卷宗二号 2 张）。

## 8. 平板常亮（2026-11-26 设置并验证）

- **系统设置（持久）**：设置 → 显示和亮度 → 屏幕 → 休眠 → 永不（原值「10 分钟后」）。重启后仍生效。
- **命令行兜底（会话级，重启失效）**：`power-shell timeout -o 86400000`；还原用 `power-shell timeout -r`。
- **验证**：撤销命令行覆盖（`timeout -r`）后，平板静置 **11 分 38 秒**（01:23:55 → 01:35:33），期间零操作；`hidumper -s RenderService -a screen` 仍报 `powerStatus=POWER_STATUS_ON`，已超过原「10 分钟后」阈值，证明「永不」生效。截图 3568。
- 方法已写进我的 SOUL.md：每批动手前先 `hdc tconn 192.168.5.133:42355`，确认 `hdc list targets` 有平板、`powerStatus=ON`；息屏先 `power-shell wakeup`；长批前可再补 `power-shell timeout -o 86400000`。

## 9. 本轮补验的提交

- 平板复验与本条常亮记录追加于同一分支 `fix/nav-docview`，未动源码（源码改动与 §1 相同）。
