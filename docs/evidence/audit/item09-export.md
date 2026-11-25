# 核查①-9：导出页双机逐项核查（A181–A199）

- 核查日期：2026-11-25
- 分支：`audit09-export`（base `main` HEAD `1a76455`）
- 范围：`docs/evidence/audit/item01-inventory.md` §17 导出页（A181–A199，19 项）；关联风险 **R16**（8 开关只影响图片/PDF）、**R7**（主页导出沿用上次目标，A13 一并定性）、**R6**（PDF 抬头机名回落 1920s）。
- 设备与构建：
  - 平板 MLR-AL10（HUAWEI MatePad Mini），1600×2560，`192.168.5.133:42355`（TCP）
  - 手机 ADA-AL00U（nova 12 Ultra），1224×2776，`2UCUT24724009680`（USB）
  - 两台沿用 audit①-8 同一安装包；本批未重新构建/安装，分支相对 base 无代码改动。

## 0. 起始状态与测试数据

1. **平板**：App 在前台、停在主页，今日 **50/500**、已写 7 字——`3287`；`machine=1920s-upright`、`delete_mode=trash`。
2. **手机**：App 在前台、停在主页，今日 **49/500**、已写 7 字——`3288`；`machine=1920s-upright`、`delete_mode` 未写（缺省即 `trash`）。
3. 两机均未 `bm clean`（audit①-8 残留）：
   - 平板：卷宗「测试卷宗二号」2 张纸、未归档 3 张、回收站 1 张；手机：卷宗 2 张纸、未归档 2 张、回收站 0 张。
   - 两机 `cn_engine=builtin`；字号 20、手机 `marginH=40`、纸纹 prefs 指向沙箱截图副本（audit①-7 残留，本批未改）。
   - 引导：A159 重播后 14 页 `guide.*.seen=false`；本批此前只关了 settings/pinyin_settings。进入导出页按引导流程正常走完（平板 `3294–3297`，手机 `3389–3392`）；卷宗内页/文档视图/主题页的首次引导也按流程关闭（`3291`、`3293`、`3384`、`3456` 跳过）。
   - 手机在 19:19 因一次导航跑飞（见 §4.2 第 7 步）执行过 `aa force-stop`＋`aa start` 冷启动；只重置内存态（页面栈/导出目标/保存格式），prefs 与文档未变。
4. **测试数据（本批新建/准备）**：
   - 复用既有测试文档，不新建文档：
     - 平板 `doc-1795556080764-99292`「啊!尼」（未归档，4 纸：归档纸 1=`a`、2=符号行、3=`哈`，当前纸第 16 行=`啊!尼`）——多纸范围/当前纸取错验证。
     - 平板 `doc-1795573326512-40843`「ni」（未归档，1 纸 1 行）——8 开关逐项对照。
     - 平板卷宗「测试卷宗二号」`d1795568897351500`（2 篇，各 1 纸）——整卷宗范围。
     - 手机 `doc-1795557874844-82066`「a」（未归档，4 纸，结构同平板多纸文档）——多纸范围/当前纸取错验证。
     - 手机 `doc-1795570194624-61663`「ni」（未归档，1 纸 1 行）——8 开关逐项对照。
     - 手机卷宗「测试卷宗二号」`d1795568968003158`（2 篇，各 1 纸）——整卷宗入口核验（结果：手机无入口，见 O8）。
   - 为让「当前纸」导出通过空文档判定，平板/手机均先在卷宗内页点「打开」载入目标文档（日志 `loadDocument id=…`），再从纸缩略图进文档视图导出；未改任何文档内容。
   - 导出产物：两机均通过「分享」把文件写入应用沙箱 `files/export-tmp/` 后拉取比对；两机另各做一次「保存到本地」落盘 Download（见 §4、§8）。
5. 起始/收工 prefs：`docs/evidence/item09-prefs-{tablet,phone}-{start,end}.xml`。

## 1. 结论摘要

- **A181–A199 共 19 项、双机逐项操作：15 项双机完全通过；A183 双机不通过（O1/O2）；A185 手机不可达（O8，平板通过）；A188 双机部分通过（O2）；A196 平板无效果（O3，手机通过）**。无崩溃、无卡死；三种范围、三种格式、8 开关、文件名、保存、分享均实际操作。
- **R16 双机确认**：8 个开关对「纯文本」导出无影响（9 种开关状态的 txt 字节完全相同：两机均 `ni\n`（3 字节））；7 个开关会改变图片/PDF 产物；「书写字体」在 **prefs `custom.font.<机>.family` 为空时（平板）**对图片/PDF 也无影响（ON/OFF 字节相同），手机该 prefs 为 `CourierPrime` 时正常生效（O3）。
- **范围语义存在两处偏差（O1/O2，双机）**：
  - 「当前纸」+ 图片：导出的是**整篇第 1 纸（归档纸）**，不是当前纸；页面预览显示当前纸，产物与预览不一致。
  - 「当前纸」/「整篇」+ PDF/纯文本：PDF 忽略范围（两机均仍 4 页，字节与整篇 PDF 相同）；纯文本始终导出整篇（两机「当前纸」与「整篇」txt 逐字节相同）。
- **R7/A13 双机确认**：主页「导出」不设置也不清除导出目标；先导出整篇再回主页导出，目标仍是上次文档（平板 `3321`、手机 `3454`）；先导出整卷宗再回主页导出，导出页直接以「整卷宗」范围打开并显示上次卷宗预览（平板 `3332`）。
- **R6（PDF 抬头机名）**：可达的模板 PDF 用当前机 2020s 的机器照片（两机均 `kind=2020s-modern`，`tablet_2020s_page.png`、`phone_2020s_page.png`），模板里没有机名文字；唯一含“机名抬头”的是模板失败后的纯文本 PDF 回退，`machineTitleKey('2020s-modern')` 回 1920s（`ExportCore.ets:271-282`）。本批未能通过 UI 触发模板失败，R6 该分支仅代码确认，见 O6。
- **O8（手机，A185）**：手机宽度下卷宗内页页眉不渲染「导出」按钮（`widthVp<600` 时隐藏），⋯菜单只有改名/新建纸张/删除卷宗；**手机无法进入整卷宗范围的导出页**。
- **O4（平板，A183 边界）**：目标文档未载入打字机模型时（冷启动后直接 卷宗→内页→纸缩略图→导出），「当前纸」导出被空文档判定拦下（“这张纸还没有字”），而预览明明有内容；点过一次「打开」（`loadDocument`）后恢复正常。
- **A189 双机通过**：文件名留空自动名（平板 `回车-ni-20261125-181228.pdf`，手机 `回车-ni-20261125-191351.pdf`）；非法字符 `/ :` 被 `safeFileName` 清掉（平板 `回车-abd，没，没，没，，-…pdf`；手机输入 `ab/c:d` → `回车-abcd-…txt`）。
- **A198/A199 双机通过**：保存进系统选择器并落盘 Download（平板 1621709 字节、手机 2926600 字节，与构建字节一致）；分享面板正常拉起（三种格式各验，每次导出均确认）。
- **A181 双机通过（busy 返回忽略）**：4 页 PDF building 中点返回，两机均 `export busy, back ignored phase=building`，页面停留、随后分享面板正常拉起。

## 2. 逐项结果

> 结果口径：**通过**＝控件在双机真机完成预期操作且画面/产物可证；判定以截图为准，hilog/产物比对只作辅助。A190–A197 的“通过”指开关可拨动且**对图片/PDF 产物产生影响**（平板字体开关例外，见 O3）；纯文本不受影响即 R16 口径。

| 编号 | 控件 | 平板 | 手机 | 关键证据（截图号） | 实际操作与结论 |
|---|---|---|---|---|---|
| A181 | 返回 | 通过 | 通过 | 3316/3317、3430/3431、3320、3432 | busy（4 页 PDF building）时点返回，两机均 hilog `export busy, back ignored phase=building`，页面停留、随后分享面板正常拉起；非 busy 时返回弹栈回文档视图。 |
| A182 | 引导“?” | 通过 | 通过 | 3294–3297、3389–3392、3318/3319、3420/3421 | 进入导出页自动弹 3 步引导（格式→按钮→分享），逐页截图后关闭；两机另点页眉“?”重拉并关闭。 |
| A183 | 范围“当前纸” | **不通过（O1/O2/O4）** | **不通过（O1/O2）** | 3298/3300、3393/3405/3406 | 选「当前纸」后图片行可用；但导出的 PNG 是整篇第 1 纸（归档纸）：平板 `tablet_baseline_paper_image.png` 页脚 `1 / 4`、正文 `a`；手机 `phone_paper_a.png` 页脚 `1 / 4`、正文 `a`（当前纸是第 4 纸）。PDF/纯文本忽略“当前纸”（O2）。平板另遇空文档误判（O4，3338）。 |
| A184 | 范围“整篇” | 通过（O2 备注） | 通过（O2 备注） | 3302/3303、3408/3409 | 选「整篇」后预览显示第 1 纸 + “共 4 纸”；PDF 逐纸 4 页（hilog `pages=4`，PDF 4 页），标题/页码正确（`tablet_doc_4page_p1/p4.png`）。 |
| A185 | 范围“整卷宗” | 通过 | **不通过（O8）** | 3323/3324/3330、3445/3448 | 平板：仅从卷宗内页入口显示第三 chip；预览“测试 · 1 纸 / 未命名 · 1 纸 / 共 2 篇”；PDF 2 页（标题下带卷宗名）、TXT 组装含两篇。手机：卷宗内页页眉无「导出」，⋯菜单无「导出」，整卷宗范围不可达。 |
| A186 | 格式“图片 PNG” | 通过 | 通过 | 3297 vs 3298；3389 vs 3393 | 整篇/整卷宗范围图片行置灰并显示“多页请用 PDF”；切「当前纸」后恢复可点（提示消失）。 |
| A187 | 格式“PDF” | 通过 | 通过 | 3302/3303、3408/3409 | 模板逐页渲染后合成 PDF；多页合并正常（两机各 4 页示例）。模板失败回退纯文本 PDF 的路径未能触发（见 O6）。 |
| A188 | 格式“纯文本” | 部分（O2） | 部分（O2） | 3309/3310、3411 | txt 导出成功；但范围不影响 txt：两机「当前纸」与「整篇」产物逐字节相同，均为整篇（含归档纸分隔行）：平板 170 字节、手机 152 字节。 |
| A189 | 文件名输入 | 通过 | 通过 | 3368、3371、3423、3426 | 留空时选择器自动名（平板 `回车-ni-20261125-181228.pdf`、手机 `回车-ni-20261125-191351.pdf`）；输入含 `/ :` 的名字后选择器显示清理后的名字（平板 `回车-abd，没…pdf`、手机 `回车-abcd-…txt`）。 |
| A190 | 开关“标题” | 通过 | 通过 | 3355、`*_title_off.*` | 关：图片/PDF 标题块消失、后续块上移（平板 PNG 1,870,859 px / PDF 18,155；手机 3,774,176 / 11,535）；txt 不变。 |
| A191 | 开关“机器框” | 通过 | 通过 | `*_machine_off.*` | 关：机器照片块消失、日期/正文上移（平板 1,661,537 / 16,359；手机 3,350,606 / 10,367）；txt 不变。 |
| A192 | 开关“日期” | 通过 | 通过 | 3353（误标后改档）、`*_date_off.*` | 关：日期行消失（平板 7,146 / 155；手机 9,986 / 73）；txt 不变。 |
| A193 | 开关“正文” | 通过 | 通过 | `*_body_off.*` | 关：纸面底板与正文消失（平板 540 / 21；手机 987 / 18；底板与模板底色接近，差异集中在文字/边缘）；txt 不变。 |
| A194 | 开关“页码” | 通过 | 通过 | `*_pageno_off.*` | 关：右下 `1 / 1` 消失（平板 883 / 27；手机 1,443 / 17）；txt 不变。 |
| A195 | 开关“纸张底色” | 通过 | 通过 | `*_paper_off.*` | 关：纸面底板变白（平板 2,764,840 / 26,241；手机 5,581,136 / 16,923）；txt 不变。 |
| A196 | 开关“书写字体” | **不通过（O3）** | 通过 | `tablet_ni_font_off.*`、`phone_ni_font_off.*` | 平板：关后图片/PDF 与开**逐字节相同**（PNG md5 相同、PDF 1621709 字节相同），因 prefs `custom.font.1920s-upright.family` 为空，ON/OFF 均回落系统默认；手机该 prefs=`CourierPrime`，关后产物变化（PNG 28,091 px / PDF 166 px）。 |
| A197 | 开关“墨色” | 通过 | 通过 | `*_ink_off.*` | 关：正文/标题变纯黑（平板 6,256 / 77；手机 10,636 / 35）；txt 不变。 |
| A198 | “保存到本地” | 通过 | 通过 | 3368/3369、3426/3427 | 构建→系统保存选择器→确认→结果态“已保存”；日志 `FileHelper saveBytes ok uri=…/Download/…pdf`、`export save ok`；平板落盘 1621709 字节、手机 2926600 字节；取消选择器回 idle（平板 3372、手机 3424）。 |
| A199 | “分享” | 通过 | 通过 | 3300/3310/3324、3406/3411/3459 | 三种格式均拉起系统分享面板并显示“已调起分享”；临时文件写入 `files/export-tmp/`，离开导出页后清理（日志 `tmp cleaned`，目录空）。 |

## 3. 问题清单

| 编号 | 对应 | 类型 | 问题 | 证据 | 复现（双机通用） |
|---|---|---|---|---|---|
| O1 | A183 | 产物错误（中高） | 「当前纸」范围导出的 PNG 取整篇第 1 纸（归档纸），不是当前纸；页面预览显示当前纸，产物与预览不一致。代码：`buildFor` 图片分支用 `pagePlans()[0]`（ExportPage.ets:736-749，`pagePlans` 见 359-393，groups=归档纸在前）。 | 平板 3298（预览当前纸）→`tablet_baseline_paper_image.png`（页脚 1/4、正文 a）；手机 3405→`phone_paper_a.png`（1/4、正文 a）；PDF 页 1 PNG 与图片导出字节相同。 | 任一含归档纸的文档→文档视图→导出→当前纸→图片→分享/保存，对比预览与产物。 |
| O2 | A183/A184/A188 | 范围语义偏差（中） | PDF 与纯文本不按「当前纸/整篇」区分：PDF 在「当前纸」仍逐纸全导（4 页，与整篇 PDF 字节相同）；纯文本始终整篇（含归档纸分隔行），两范围产物逐字节相同。仅「整卷宗」有独立分支。代码：`buildFor` 的 pdf/text 分支不判 range（ExportPage.ets:651-735）。 | 平板 3304/3305（`pages=4`，PDF 6530749 字节与整篇 3303 相同）；手机 3396（`pages=4`）；txt：平板 170 字节相同、手机 152 字节相同。 | 4 纸文档→导出→当前纸→PDF/纯文本，与整篇对照页数/字节。 |
| O3 | A196 | 开关效果依赖隐藏状态（中） | 「书写字体」ON 时取 `CustomizeStore.fontFamily(机)`（prefs `custom.font.<机>.family`），OFF 传空串。该 prefs 为空时 ON=OFF（平板），开关无可观察效果；ON 也不回落到机型默认字体（如 CourierPrime）。手机该 prefs=`CourierPrime`，开关正常。 | 平板 `tablet_ni_all_on.png` 与 `tablet_ni_font_off.png` md5 相同（1476148 字节）；手机 `phone_ni_font_off.png` 与基线差 28,091 px。代码 ExportPage.ets:317-321、CustomizeStore.ets:76-78。 | 平板（`family` 空）导出图片/PDF，开关「书写字体」前后对比；手机同操作可见差异。 |
| O4 | A183 | 空文档误判（中） | 目标文档未载入打字机模型时（冷启动后直接 卷宗→内页→纸缩略图→文档视图→导出），「当前纸」导出被 `prepareExport` 判为空（“这张纸还没有字”），预览却有内容；点「打开」载入模型后恢复正常。代码：Index.ets:2347-2354 用 live docModel 判空。 | 平板 3336–3339（预览 ni、点分享后 empty）；卷宗内页点「打开」（hilog `loadDocument id=…40843 rows=1`）后重进导出即可导出（3348–3350）。 | 冷启动 App→卷宗→未归档→纸缩略图→文档视图→导出→当前纸→分享。 |
| O5 | R7/A13 | 目标残留（已确认） | 主页「导出」不设/不清导出目标：上次从卷宗导出后，主页导出直接以「整卷宗」范围打开并显示上次卷宗预览；上次从文档导出则沿用该文档。 | 平板 3321（doc）、3332（dossier+3 chip+卷宗预览）；手机 3454（doc，hilog docId=…96374）。代码 Index.ets:5094-5100、ExportTarget 无 clear 调用。 | 文档/卷宗内页→导出→返回主页→底部「导出」。 |
| O6 | R6 | 代码确认（低，未触发） | 模板 PDF 使用当前机 2020s 照片且无“机名”文字；唯一含机名抬头的是模板失败回退的纯文本 PDF，`machineTitleKey('2020s-modern')` 回落 1920s。模板成功路径无法通过 UI 触发回退，R6 该分支仅代码确认。 | 平板 3377–3379（`kind=2020s-modern`，`tablet_2020s_page.png`）；手机 3457–3459（`phone_2020s_page.png`）；代码 ExportCore.ets:271-282、ExportPage.ets:729-734。 | 主题切 2020s→导出 PDF；如需验证回退需构造模板失败（本批未做）。 |
| O7 | A189（观察） | 交互观察（低） | 文件名输入框聚焦后系统键盘持续弹出：点格式行/保存按钮时键盘仍在，保存按钮被遮挡；需按系统返回键收起键盘后才能保存。属输入法焦点行为，未确认是否产品缺陷。 | 平板 3356/3357/3359/3366（键盘反复弹出）→3367（返回键收起）→3368 保存选择器。 | 导出→文件名输入→点保存到本地。 |
| O8 | A185 | 入口缺失（中） | 手机（widthVp<600）卷宗内页页眉不渲染「导出」按钮，⋯菜单也没有导出项，导致「整卷宗」范围在手机上不可达。代码 DossierDetailPage.ets:497-504（`if (this.widthVp >= 600)` 才渲染导出），738-750（⋯菜单仅改名/新建纸张/删除卷宗）。 | 手机 3445（页眉无导出）、3448（⋯菜单三项）、3437/3441 同；平板 3322/3323 有导出入口。 | 手机→卷宗→测试卷宗二号→查看页眉与⋯菜单。 |

## 4. 操作过程

### 4.1 平板 MLR-AL10

1. `3287` 起始主页 → 卷宗 `3289` → 未归档 `3290b`（关闭卷宗内页引导 `3291`）→「啊!尼」纸缩略图进文档视图 `3292/3293`。
2. 导出页：自动引导 3 步 `3294–3296` → 关闭 `3297`（整篇范围，图片置灰＋“多页请用 PDF”）。
3. 当前纸＋图片＋分享：`3298`（切范围）、`3299`（选图片）、`3300`（分享面板）；拉取 PNG 发现正文 `a`、页码 `1 / 4`，与预览当前纸不一致（O1）。
4. 整篇＋PDF＋分享：`3302/3303`，hilog `pages=4`，PDF 4 页；拉取 `tablet_doc_4page.pdf` 与逐页 PNG，页 1/4 与纸张对应。
5. 当前纸＋PDF：`3304/3305`，hilog 仍 `pages=4`、字节与整篇 PDF 相同（O2）；当前纸＋纯文本：`3308/3309/3310`，产物 170 字节整篇；整篇＋纯文本：`3311/3312`，逐字节相同。
6. busy 返回：整篇＋PDF 分享后立即点页内返回，hilog `export busy, back ignored phase=building`（`3316/3317`；`3314` 为首次坐标偏差的过程图）；非 busy 返回弹栈 `3320`。
7. 页眉“?”重拉引导 `3318`，关闭 `3319`。
8. R7：文档导出目标下回主页点导出 `3321`（hilog scope=doc docId=…99292）；卷宗内页导出 `3322/3323`（3 chip、整卷宗预览）→ 整卷宗 PDF `3324`（2 页，标题下卷宗名）、整卷宗 TXT `3325–3330`；回主页再点导出 `3331/3332`（hilog scope=dossier，3 chip＋上次卷宗预览）。
9. 「ni」单纸文档：未载入模型时当前纸导出被空文档拦下 `3336–3339`（O4）；点「打开」载入（日志 `loadDocument …40843 rows=1`，`3343`）→ 重进文档视图/导出 `3347/3348`，当前纸＋图片成功 `3349/3350`。
10. 8 开关：先全开基线（图片/PDF/TXT）`tablet_ni_all_on.*`；逐个关闭并各出三份产物：标题 `3355`、机器框、日期（`3353`，误标后改档 `tablet_ni_date_off.*`）、正文、页码、纸张底色、书写字体、墨色，再逐个恢复全开（最终 8 项全 true）。产物差异见 §5。
11. 文件名/保存：输入非法名 `3356`（键盘遮挡问题见 O7）→ 系统返回收起键盘 `3367` → 保存选择器显示清理后的名字 `3368` → 确认保存 `3369`（日志 `saveBytes ok`、`export save ok`）→ 重进导出页留空名 `3370` → 选择器自动名 `3371` → 取消 `3372`。
12. R6：主题页切 2020s `3373/3374`（首次未命中，`3377` 选中，日志 `customize machine -> 2020s-modern`）→ 主页导出 `3378` → 当前纸 PDF `3379`（hilog `kind=2020s-modern`，页面照片为 2020s）；切回 1920s `3380`（日志 `customize machine -> 1920s-upright`）→ 主页 `3381`。

### 4.2 手机 ADA-AL00U

1. `3288` 起始主页 → 卷宗 `3382` → 未归档 `3384`（关闭卷宗内页引导）→ 缩略图进「a」文档视图 `3386/3387`。
2. 导出页自动引导 3 步 `3389–3391` → 关闭 `3392`（整篇，图片置灰＋提示）。
3. 当前纸＋图片：`3393`；首次点图片行未命中（`3394`，仍 PDF）→ 关闭分享面板后页面回顶，重滚格式 `3402`、选中图片 `3405` → 分享 `3406`，PNG 页脚 `1 / 4`、正文 `a`（O1）。
4. 当前纸＋PDF：`3395/3396`，hilog `pages=4`（O2）；整篇＋PDF `3408/3409`，4 页；整篇＋TXT `3411`，152 字节；当前纸＋TXT（回顶切范围）产物同为 152 字节（O2）。
5. 「ni」单纸文档：回内页点「打开」载入 → 文档视图 `3414` → 导出 `3415`（hilog docId=…61663）→ 当前纸 `3416`。
6. 8 开关：全开基线 `3417`；逐项关闭并各出三份产物（标题、机器框、日期、正文、页码、纸张底色、书写字体、墨色），产物差异见 §5；另补页眉“?”`3420/3421`。
7. 中途一次 `close_panel` 在分享面板未及时出现时按了系统返回，页面被弹栈并继续后退，App 退到后台（前台变为漫匣）；于 19:19 `aa force-stop`＋`aa start` 冷启动恢复（`3443`），只重置内存态。此前已拿到 baseline/标题/机器框/日期/正文(图/PDF) 产物，随后补跑正文 TXT、页码、纸张底色、书写字体、墨色，最终 8 项全 true。
8. 文件名/保存：输入非法名 `3422` → 系统返回收起键盘 → 保存选择器 `3423`（`回车-abcd-…txt`，非法字符已清）→ 取消 `3424`；重进导出页留空名 `3425` → 选择器自动名 `3426`（`回车-ni-…pdf`）→ 确认保存 `3427`（落盘 2926600 字节）。
9. busy 返回：从「a」文档视图导出整篇 PDF（`3429`），building 中点返回 `3430`，hilog `export busy, back ignored phase=building`，分享面板 `3431`；关闭后正常返回文档视图 `3432`（A181）。
10. R7：文档导出（`3450`，hilog docId=…96374）后回主页点导出 `3453/3454`（hilog 仍为该文档）；整卷宗手机入口缺失（`3445`/`3448`，O8），dossier 目标的手机侧残留无法构造。
11. R6：主题切 2020s `3456/3457`（日志 `customize machine -> 2020s-modern`）→ 主页导出 `3458` → PDF 分享 `3459`（hilog `kind=2020s-modern`，`phone_2020s_page.png`）；切回 1920s `3460`（日志 `customize machine -> 1920s-upright`）→ 主页 `3462`。

## 5. 实证产物与量化

- 产物目录（未入库，留存于工作区）：`docs/evidence/.item09-artifacts/`
  - 平板基线/8 开关：`tablet_ni_all_on.{png,pdf,txt}`、`tablet_ni_{title,date,machine,body,pageno,paper,font,ink}_off.{png,pdf,txt}`
  - 平板多纸/卷宗：`tablet_doc_4page.pdf`（4 页）、`tablet_dossier.pdf`（2 页）、`tablet_baseline_paper_image.png`、`tablet_2020s_page.png`
  - 手机基线/8 开关、多纸：`phone_ni_all_on.*`、`phone_ni_*_off.*`、`phone_doc_4page.pdf`、`phone_paper_a.png`、`phone_doc.txt` / `phone_paper.txt`、`phone_2020s_page.png`
- 8 开关产物对照（vs 全开；PNG 为原尺寸逐像素差，PDF 为首页 0.4–0.5× 渲染差）：
  - 平板：标题 1,870,859 / 18,155；机器框 1,661,537 / 16,359；日期 7,146 / 155；正文 540 / 21；页码 883 / 27；纸张底色 2,764,840 / 26,241；**书写字体 0 / 0（字节相同）**；墨色 6,256 / 77。
  - 手机：标题 3,774,176 / 11,535；机器框 3,350,606 / 10,367；日期 9,986 / 73；正文 987 / 18；页码 1,443 / 17；纸张底色 5,581,136 / 16,923；书写字体 28,091 / 166；墨色 10,636 / 35。
- 纯文本：两机 9 种开关状态均为 `ni\n`（3 字节）；平板多纸文档当前纸/整篇均 170 字节且逐字节相同，手机 152 字节相同。
- 产物尺寸：平板模板 PNG 2565×3420、PDF A4 595×842；手机模板 PNG 3645×4860、PDF A4。

## 6. 缺口与未验项

- **A187 模板失败回退纯文本 PDF**：无法通过 UI 构造模板失败，未触发；仅验证模板成功路径。
- **R6 PDF 抬头机名**：仅代码确认（回退路径不可达），未取得 2020s 机名回落 1920s 的真机产物；可达的模板 PDF 无“机名”文字。
- **A185 手机**：入口缺失（O8），整卷宗范围手机不可达；手机侧 R7 的 dossier 目标残留无法构造（入口不存在）。
- **A196 平板**：因 `custom.font.1920s-upright.family` 为空，ON/OFF 无差异；未在平板导入自定义字体后复测（手机因残留 `CourierPrime` 已验证有效）。
- **手机 3404**：一次 `snapshot_display` 失败未存档（该步已由 3403/3405 覆盖），无缺项。
- **R16 的“0 差异”判定**：正文/页码等小开关的 PNG 像素差较小（数百 px），已用 PDF 首页差异与产物字节数交叉确认；未做逐字形人工目检。

## 7. 清单状态建议（仅建议，未修改清单文件）

- A181–A182、A184、A186–A187、A189–A195、A197–A199：建议改「已验证（2026-11-25 双机）」。
- A183：建议改「待修」——当前纸 PNG 取第 1 纸（O1）；范围对 PDF/TXT 无效（O2）；空文档误判（O4）。
- A185：平板通过、手机入口缺失（O8），建议「部分通过（手机待补入口）」。
- A188：建议「部分通过」——txt 导出成功，但不按范围（O2）。
- A196：平板「不通过（O3，默认配置无效果）」、手机「通过」；建议整体「部分通过（依赖自定义字体 prefs）」。
- A13：建议由「待确认」改「已验证（行为如注释；R7 复现）」。
- 新增风险建议：O1 记 R29（当前纸 PNG 取第 1 纸）；O2 记 R30（PDF/TXT 不按范围）；O3 记 R31（字体开关依赖隐藏 prefs）；O4 记 R32（未载入模型时空文档误判）；O8 记 R33（手机卷宗内页无导出入口）。

## 8. 测试残留

- 两机均未 `bm clean`；未新建/删除文档，文档数量与内容保持起始值（手机中途冷启动不影响磁盘数据）。
- 两机机器已恢复 `1920s-upright`（end prefs 核对）；字号/纸纹/删除方式等 audit①-7/⑧ 残留未动。
- 引导 seen 变化：两机 `guide.export.seen=true`；手机 `guide.dossier_detail.seen=true`、`guide.document_view.seen=true`、`guide.customize.seen=true`（平板这些页此前已看过或本次看过）。
- 落盘文件：
  - 平板 Download：`回车-abd，没，没，没，，-20261125-181112.pdf`（1621709 字节）。
  - 手机 Download：`回车-ni-20261125-191351.pdf`（2926600 字节）。
- 应用沙箱 `files/export-tmp/` 两机均空（离开导出页自动清理，日志 `tmp cleaned`）。
- `docs/evidence/.item09-artifacts/` 保留本批产物供复核，未入库；`docs/evidence/item09-prefs-*-{start,end}.xml` 已落盘。
- 手机在 19:19 冷启动过一次（原因见 §4.2 第 7 步），无数据副作用。

## 9. 截图索引

（176 张，编号 3287–3462；`3404` 因截屏失败未生成，由 3403/3405 覆盖。完整文件见 `docs/shots/<编号>_audit09_*.png`。）

| 编号 | 文件 | 内容 |
|---|---|---|
| 3287 | `3287_audit09_tablet_home_start.png` | 平板 起始主页 |
| 3288 | `3288_audit09_phone_home_start.png` | 手机 起始主页 |
| 3289 | `3289_audit09_tablet_dossier_page.png` | 平板 卷宗页 |
| 3290 | `3290_audit09_tablet_unfiled_page.png` | 平板 未归档内页 |
| 3290b | `3290b_audit09_tablet_unfiled_page.png` | 平板 未归档内页（再次进入） |
| 3291 | `3291_audit09_tablet_unfiled_guide_closed.png` | 平板 关闭卷宗内页引导 |
| 3292 | `3292_audit09_tablet_docview_ani.png` | 平板 文档视图「啊!尼」 |
| 3293 | `3293_audit09_tablet_docview_ani_clean.png` | 平板 文档视图（引导关闭） |
| 3294 | `3294_audit09_tablet_export_enter_guide.png` | 平板 导出页自动引导第1步 |
| 3295 | `3295_audit09_tablet_export_guide_step2.png` | 平板 导出页引导第2步 |
| 3296 | `3296_audit09_tablet_export_guide_step3.png` | 平板 导出页引导第3步 |
| 3297 | `3297_audit09_tablet_export_clean.png` | 平板 导出页（引导关闭，整篇） |
| 3298 | `3298_audit09_tablet_export_range_paper.png` | 平板 范围切「当前纸」 |
| 3299 | `3299_audit09_tablet_export_image_selected.png` | 平板 选中「图片」 |
| 3300 | `3300_audit09_tablet_export_share_png_panel.png` | 平板 图片分享面板 |
| 3301 | `3301_audit09_tablet_export_share_png_result.png` | 平板 分享后结果态 |
| 3302 | `3302_audit09_tablet_export_doc_pdf_selected.png` | 平板 整篇＋PDF 选中 |
| 3303 | `3303_audit09_tablet_export_doc_pdf_share_panel.png` | 平板 整篇 PDF 分享面板 |
| 3304 | `3304_audit09_tablet_export_paper_pdf_preview.png` | 平板 当前纸＋PDF 预览 |
| 3305 | `3305_audit09_tablet_export_paper_pdf_share_panel.png` | 平板 当前纸 PDF 分享面板 |
| 3306 | `3306_audit09_tablet_export_text_selected_paper.png` | 平板 纯文本（当前纸，未选中） |
| 3307 | `3307_audit09_tablet_export_paper_txt_share_panel.png` | 平板 当前纸 TXT 面板 |
| 3308 | `3308_audit09_tablet_export_scrolled.png` | 平板 导出页滚动 |
| 3309 | `3309_audit09_tablet_export_text_selected.png` | 平板 选中纯文本 |
| 3310 | `3310_audit09_tablet_export_text_share_panel.png` | 平板 纯文本分享面板 |
| 3311 | `3311_audit09_tablet_export_doc_text_selected.png` | 平板 整篇＋纯文本 选中 |
| 3312 | `3312_audit09_tablet_export_doc_text_share_panel.png` | 平板 整篇 TXT 面板 |
| 3313 | `3313_audit09_tablet_export_doc_pdf_before_busyback.png` | 平板 busy 返回前 |
| 3314 | `3314_audit09_tablet_export_busy_back_ignored.png` | 平板 busy 返回（进度浮层） |
| 3315 | `3315_audit09_tablet_export_busy_back_share_panel.png` | 平板 busy 后分享面板 |
| 3316 | `3316_audit09_tablet_export_busy_back_ignored2.png` | 平板 busy 返回（正确坐标） |
| 3317 | `3317_audit09_tablet_export_busy_back_panel2.png` | 平板 busy 后分享面板2 |
| 3318 | `3318_audit09_tablet_export_help_guide.png` | 平板 页眉“?”引导 |
| 3319 | `3319_audit09_tablet_export_help_closed.png` | 平板 “?”引导关闭 |
| 3320 | `3320_audit09_tablet_export_back_to_docview.png` | 平板 返回文档视图 |
| 3321 | `3321_audit09_tablet_home_export_after_doc.png` | 平板 主页导出（沿用文档目标） |
| 3322 | `3322_audit09_tablet_dossier_detail_test2.png` | 平板 测试卷宗二号内页 |
| 3323 | `3323_audit09_tablet_export_dossier_entry.png` | 平板 整卷宗导出入口 |
| 3324 | `3324_audit09_tablet_export_dossier_pdf_panel.png` | 平板 整卷宗 PDF 面板 |
| 3325 | `3325_audit09_tablet_export_dossier_scrolled.png` | 平板 卷宗导出页滚动 |
| 3326 | `3326_audit09_tablet_export_dossier_text_panel.png` | 平板 卷宗 TXT 面板（误触 PDF） |
| 3327 | `3327_audit09_tablet_export_dossier_text_selected.png` | 平板 卷宗纯文本选中（未命中） |
| 3328 | `3328_audit09_tablet_export_dossier_text_panel.png` | 平板 卷宗 TXT 面板（误触 PDF） |
| 3329 | `3329_audit09_tablet_export_dossier_text_selected2.png` | 平板 卷宗纯文本选中 |
| 3330 | `3330_audit09_tablet_export_dossier_text_panel2.png` | 平板 卷宗 TXT 面板 |
| 3331 | `3331_audit09_tablet_back_dossier_detail.png` | 平板 返回卷宗内页 |
| 3332 | `3332_audit09_tablet_home_export_after_dossier.png` | 平板 主页导出（沿用整卷宗目标） |
| 3333 | `3333_audit09_tablet_unfiled_again.png` | 平板 未归档内页 |
| 3334 | `3334_audit09_tablet_docview_ni.png` | 平板 文档视图「ni」 |
| 3335 | `3335_audit09_tablet_docview_ni2.png` | 平板 文档视图 ni（过程） |
| 3336 | `3336_audit09_tablet_export_ni_entry.png` | 平板 「ni」导出页 |
| 3337 | `3337_audit09_tablet_export_ni_paper.png` | 平板 「ni」当前纸 |
| 3338 | `3338_audit09_tablet_export_ni_all_on_done.png` | 平板 空文档误判（O4） |
| 3339 | `3339_audit09_tablet_export_ni_share2.png` | 平板 空文档下点分享无效 |
| 3340 | `3340_audit09_tablet_back_unfiled.png` | 平板 返回未归档 |
| 3341 | `3341_audit09_tablet_open_ni.png` | 平板 点「打开」载入 ni |
| 3342 | `3342_audit09_tablet_docview_ni_after_open.png` | 平板 载入后文档视图 |
| 3343 | `3343_audit09_tablet_open_ni_footer.png` | 平板 「打开」日志取证 |
| 3344 | `3344_audit09_tablet_export_ni_entry2.png` | 平板 重进导出页 |
| 3345 | `3345_audit09_tablet_export_ni_paper2.png` | 平板 当前纸 |
| 3346 | `3346_audit09_tablet_export_ni_image_selected.png` | 平板 选中图片 |
| 3347 | `3347_audit09_tablet_docview_ni3.png` | 平板 文档视图 ni |
| 3348 | `3348_audit09_tablet_export_ni_entry3.png` | 平板 重进导出页（载入模型后） |
| 3349 | `3349_audit09_tablet_export_ni_image_selected2.png` | 平板 选中图片 |
| 3350 | `3350_audit09_tablet_export_ni_image_share.png` | 平板 图片分享 |
| 3351 | `3351_audit09_tablet_export_ni_all_on_done2.png` | 平板 全开基线完成 |
| 3352 | `3352_audit09_tablet_export_custom_section.png` | 平板 自定义区 |
| 3353 | `3353_audit09_tablet_sw_title_off.png` | 平板 标题关（实际为日期关，见报告） |
| 3354 | `3354_audit09_tablet_sw_title_on_again.png` | 平板 恢复操作（状态混用） |
| 3355 | `3355_audit09_tablet_sw_title_off_correct.png` | 平板 标题关 |
| 3356 | `3356_audit09_tablet_export_filename_illegal.png` | 平板 文件名输入 |
| 3357 | `3357_audit09_tablet_export_save_picker_illegal.png` | 平板 保存选择器（键盘遮挡） |
| 3358 | `3358_audit09_tablet_export_filename_after_kb.png` | 平板 收起键盘后文件名 |
| 3359 | `3359_audit09_tablet_export_save_picker_illegal2.png` | 平板 保存选择器（键盘又弹） |
| 3360 | `3360_audit09_tablet_export_keyboard_closed.png` | 平板 键盘关闭 |
| 3361 | `3361_audit09_tablet_export_pdf_selected_for_save.png` | 平板 PDF 选中待保存 |
| 3362 | `3362_audit09_tablet_export_save_picker.png` | 平板 保存选择器（键盘弹） |
| 3363 | `3363_audit09_tablet_export_kb_hide_caret.png` | 平板 键盘收起尝试 |
| 3364 | `3364_audit09_tablet_export_after_kb_hidden.png` | 平板 键盘仍在 |
| 3365 | `3365_audit09_tablet_export_pdf_after_kb.png` | 平板 PDF 选中（键盘仍在） |
| 3366 | `3366_audit09_tablet_export_save_picker_final.png` | 平板 保存选择器（键盘仍在） |
| 3367 | `3367_audit09_tablet_after_keyevent2.png` | 平板 系统返回收起键盘 |
| 3368 | `3368_audit09_tablet_export_save_picker_illegal3.png` | 平板 保存选择器（非法名已清理） |
| 3369 | `3369_audit09_tablet_export_save_result.png` | 平板 保存成功结果态 |
| 3370 | `3370_audit09_tablet_export_fresh_blank_name.png` | 平板 重进导出页（留空名） |
| 3371 | `3371_audit09_tablet_export_save_picker_blankname.png` | 平板 选择器自动名 |
| 3372 | `3372_audit09_tablet_export_save_cancelled.png` | 平板 取消保存回 idle |
| 3373 | `3373_audit09_tablet_theme_page.png` | 平板 主题页 |
| 3374 | `3374_audit09_tablet_theme_2020s.png` | 平板 主题页（首次点 2020s 未命中） |
| 3375 | `3375_audit09_tablet_export_target_2020s.png` | 平板 导出页（机器仍 1920s） |
| 3376 | `3376_audit09_tablet_export_pdf_2020s_panel.png` | 平板 PDF 面板（机器仍 1920s） |
| 3377 | `3377_audit09_tablet_theme_2020s_selected.png` | 平板 主题页 2020s 选中 |
| 3378 | `3378_audit09_tablet_export_2020s_page.png` | 平板 2020s 导出页 |
| 3379 | `3379_audit09_tablet_export_2020s_share_panel.png` | 平板 2020s PDF 分享面板 |
| 3380 | `3380_audit09_tablet_theme_back_1920s.png` | 平板 主题页恢复 1920s |
| 3381 | `3381_audit09_tablet_home_after_export_tests.png` | 平板 主页（平板收工） |
| 3382 | `3382_audit09_phone_dossier_page.png` | 手机 卷宗页 |
| 3383 | `3383_audit09_phone_unfiled_page.png` | 手机 未归档（未进入） |
| 3384 | `3384_audit09_phone_unfiled_detail.png` | 手机 未归档内页（含引导） |
| 3385 | `3385_audit09_phone_open_a.png` | 手机 点「打开」a |
| 3386 | `3386_audit09_phone_docview_a.png` | 手机 文档视图 a（搜索框聚焦） |
| 3387 | `3387_audit09_phone_docview_a2.png` | 手机 文档视图 a |
| 3388 | `3388_audit09_phone_export_entry_guide1.png` | 手机 导出页（未进入） |
| 3389 | `3389_audit09_phone_export_entry2.png` | 手机 导出页自动引导第1步 |
| 3390 | `3390_audit09_phone_export_guide_step2.png` | 手机 导出页引导第2步 |
| 3391 | `3391_audit09_phone_export_guide_step3.png` | 手机 导出页引导第3步 |
| 3392 | `3392_audit09_phone_export_clean.png` | 手机 导出页（引导关闭，整篇） |
| 3393 | `3393_audit09_phone_export_range_paper.png` | 手机 范围切当前纸 |
| 3394 | `3394_audit09_phone_export_image_selected.png` | 手机 选图片（未命中） |
| 3395 | `3395_audit09_phone_export_image_share_panel.png` | 手机 PDF 生成中 |
| 3396 | `3396_audit09_phone_export_paper_pdf_panel.png` | 手机 当前纸 PDF 分享面板 |
| 3397 | `3397_audit09_phone_export_panel_closed.png` | 手机 面板关闭 |
| 3398 | `3398_audit09_phone_export_image_selected2.png` | 手机 格式滚动后 |
| 3399 | `3399_audit09_phone_export_image_share2.png` | 手机 仍 PDF 构建 |
| 3400 | `3400_audit09_phone_export_pdf2_panel.png` | 手机 当前纸 PDF 分享面板2 |
| 3401 | `3401_audit09_phone_panel_closed2.png` | 手机 面板关闭2 |
| 3402 | `3402_audit09_phone_export_formats_scrolled.png` | 手机 格式区滚动 |
| 3403 | `3403_audit09_phone_export_image_selected3.png` | 手机 图片行可见 |
| 3405 | `3405_audit09_phone_export_image_selected4.png` | 手机 选中图片 |
| 3406 | `3406_audit09_phone_export_image_share4.png` | 手机 图片分享面板 |
| 3407 | `3407_audit09_phone_panel_closed3.png` | 手机 面板关闭3 |
| 3408 | `3408_audit09_phone_export_doc_pdf_selected.png` | 手机 整篇＋PDF 选中 |
| 3409 | `3409_audit09_phone_export_doc_pdf_panel.png` | 手机 整篇 PDF 分享面板 |
| 3410 | `3410_audit09_phone_after_back_panel.png` | 手机 返回关闭面板 |
| 3411 | `3411_audit09_phone_export_text_panel.png` | 手机 纯文本分享面板 |
| 3412 | `3412_audit09_phone_detail_back.png` | 手机 返回内页 |
| 3413 | `3413_audit09_phone_open_ni.png` | 手机 点「打开」ni |
| 3414 | `3414_audit09_phone_docview_ni.png` | 手机 文档视图 ni |
| 3415 | `3415_audit09_phone_export_ni.png` | 手机 「ni」导出页 |
| 3416 | `3416_audit09_phone_export_ni_paper.png` | 手机 「ni」当前纸 |
| 3417 | `3417_audit09_phone_export_ni_all_on_done.png` | 手机 全开基线完成 |
| 3418 | `3418_audit09_phone_recover_app.png` | 手机 冷启动恢复 |
| 3419 | `3419_audit09_phone_export_reentry.png` | 手机 重进导出页 |
| 3420 | `3420_audit09_phone_export_help_guide.png` | 手机 页眉“?”引导 |
| 3421 | `3421_audit09_phone_export_help_closed.png` | 手机 “?”关闭 |
| 3422 | `3422_audit09_phone_export_filename_typed.png` | 手机 文件名输入 |
| 3423 | `3423_audit09_phone_export_save_picker_illegal.png` | 手机 保存选择器（非法名清理） |
| 3424 | `3424_audit09_phone_save_cancelled.png` | 手机 取消保存 |
| 3425 | `3425_audit09_phone_export_fresh_blank_name.png` | 手机 重进导出页（留空名） |
| 3426 | `3426_audit09_phone_save_picker_blankname.png` | 手机 选择器自动名 |
| 3427 | `3427_audit09_phone_save_result.png` | 手机 保存成功结果态 |
| 3428 | `3428_audit09_phone_detail_for_busy.png` | 手机 内页（busy 前） |
| 3429 | `3429_audit09_phone_export_a_for_busy.png` | 手机 「a」导出页 |
| 3430 | `3430_audit09_phone_export_busy_back.png` | 手机 busy 返回（进度浮层） |
| 3431 | `3431_audit09_phone_export_busy_panel.png` | 手机 busy 后分享面板 |
| 3432 | `3432_audit09_phone_export_back_docview.png` | 手机 返回文档视图 |
| 3433 | `3433_audit09_phone_dossier_page2.png` | 手机 卷宗页2 |
| 3434 | `3434_audit09_phone_dossier_detail_header.png` | 手机 未归档内页 |
| 3435 | `3435_audit09_phone_dossier_menu.png` | 手机 未归档菜单 |
| 3436 | `3436_audit09_phone_dossier_page3.png` | 手机 卷宗页3 |
| 3437 | `3437_audit09_phone_dossier_test2_detail.png` | 手机 卷宗页（未进入内页） |
| 3438 | `3438_audit09_phone_dossier_test2_menu.png` | 手机 卷宗页菜单（未开） |
| 3439 | `3439_audit09_phone_test2_detail2.png` | 手机 文档视图（导航跑飞） |
| 3440 | `3440_audit09_phone_dossier_page4.png` | 手机 卷宗页4 |
| 3441 | `3441_audit09_phone_test2_detail3.png` | 手机 文档视图（导航跑飞2） |
| 3442 | `3442_audit09_phone_test2_menu.png` | 手机 文档视图（菜单未开） |
| 3443 | `3443_audit09_phone_coldstart_home.png` | 手机 冷启动主页 |
| 3444 | `3444_audit09_phone_dossier_page5.png` | 手机 卷宗页5 |
| 3445 | `3445_audit09_phone_test2_detail4.png` | 手机 测试卷宗二号内页（无导出） |
| 3446 | `3446_audit09_phone_test2_menu2.png` | 手机 测试卷宗二号⋯菜单（无导出） |
| 3447 | `3447_audit09_phone_test2_menu3.png` | 手机 测试卷宗二号（⋯未开） |
| 3448 | `3448_audit09_phone_test2_menu4.png` | 手机 测试卷宗二号⋯菜单（无导出） |
| 3449 | `3449_audit09_phone_docview_nini.png` | 手机 文档视图「呢呢测试」 |
| 3450 | `3450_audit09_phone_export_from_doc.png` | 手机 文档导出入口 |
| 3451 | `3451_audit09_phone_home_before_export.png` | 手机 主页 |
| 3452 | `3452_audit09_phone_home_export_after_doc.png` | 手机 主页导出（目标残留） |
| 3453 | `3453_audit09_phone_home2.png` | 手机 主页2 |
| 3454 | `3454_audit09_phone_home_export_after_doc2.png` | 手机 主页导出（doc 目标，R7） |
| 3455 | `3455_audit09_phone_home3.png` | 手机 主页3 |
| 3456 | `3456_audit09_phone_theme_page.png` | 手机 主题页 |
| 3457 | `3457_audit09_phone_theme_2020s.png` | 手机 主题页 2020s 选中 |
| 3458 | `3458_audit09_phone_export_2020s.png` | 手机 2020s 导出页 |
| 3459 | `3459_audit09_phone_export_2020s_panel.png` | 手机 2020s PDF 分享面板 |
| 3460 | `3460_audit09_phone_theme_back_1920s.png` | 手机 恢复 1920s |
| 3461 | `3461_audit09_tablet_home_end.png` | 平板 收工主页 |
| 3462 | `3462_audit09_phone_home_end.png` | 手机 收工主页 |
