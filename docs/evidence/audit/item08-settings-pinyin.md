# 核查①-8：设置页＋拼音设置双机逐项核查（A146–A174）

- 核查日期：2026-11-25
- 分支：`audit08-settings-pinyin`（base `main` HEAD `bf39936`）
- 范围：`docs/evidence/audit/item01-inventory.md` §14 设置页（A146–A160，15 项）＋ §15 拼音设置（A161–A174，14 项），共 **29 项**；关联风险 **R2**（无障碍覆盖层无消费者/不落盘）、**R6**（2020s 覆盖不全，本批只验 `cycleMachine` 循环）、**R8**（删除方式 `ask` 与 `trash` 同效）。
- 设备与构建：
  - 平板 MLR-AL10（HUAWEI MatePad Mini），1600×2560，`192.168.5.133:42355`（TCP）
  - 手机 ADA-AL00U（nova 12 Ultra），1224×2776，`2UCUT24724009680`（USB）
  - 两台沿用 audit①-7 同一安装包；本批未重新构建/安装，分支相对 base 无代码改动。

## 0. 起始状态（先记录，再操作）

1. **平板**：App 在前台、停在主页，今日 **48/500**、已写 5 字——`3071`；`machine=1920s-upright`、`paper` 未写（按 `letter`）、`delete_mode=trash`。
2. **手机**：App 在前台、停在主页，今日 **47/500**、已写 5 字——`3072`；`machine=1920s-upright`、`delete_mode` 未写（缺省即 `trash`，设置页回显“进回收站”）。
3. 两机均未 `bm clean`（audit①-7 残留）：
   - 平板：卷宗「测试卷宗二号」2 张纸、未归档 3 张、回收站 1 张（`doc-1795568999139-89987`）。
   - 手机：卷宗「测试卷宗二号」2 张纸、未归档 2 张、回收站 0 张。
   - 两机均 `cn_engine=builtin`、`cn_fuzzy` 未写（关）、候选数量 9、候选字号 15。
   - 两机 `guide.settings.seen=true`、`guide.pinyin_settings.seen=true`（本批进入这两页不自动弹引导，A147/A162 用页眉“?”）。
   - 我的词库为空（`cn_userwords` 未写）；学习记录平板 4 条、手机 2 条；`onboarding_seen=true`。
   - 平板 `custom.font.1920s-upright.size=20`、手机 `marginH=40`、纸纹 prefs 指向沙箱截图副本——均为 audit①-7 已知残留，本批未动。
4. 起始 prefs 原文件：`docs/evidence/item08-prefs-tablet-start.xml`、`docs/evidence/item08-prefs-phone-start.xml`。
5. **本批新建/准备的测试数据**：
   - 两机各在「测试卷宗二号」新建 **3 张空白测试纸**（平板 `doc-1795593497505-61972`／`-3495033-10894`／`-3492772-87511`；手机 `doc-1795595458764-62009`／`-5454115-57633`／`-5449373-93700`），仅用于 R8 三档删除对照；三张随后分别按 `ask`／`trash`／`direct` 删除，前两张再从回收站彻底删除、direct 那张已直接删档。**两机文档净数量已回到起始值**（平板 active 5／trash 1；手机 active 4／trash 0）。
   - 未推送字体/图片/外部文件；未联网。

## 1. 结论摘要

- **A146–A174 共 29 项、双机逐项操作：29 项双机通过**（A163/A164 的“通过”指滑杆本身落盘、显示与边界正确；候选条效果受已确认的 R1 限制，见下）。无崩溃、无卡死、无页面卡死；设置页 6 组、拼音设置 4 组、两个弹窗均完成预期操作。
- **R2 已真机确认（双机，A151）**：无障碍覆盖层开关只翻转 Index 内存 `@State`；拨到“开”后 `carriagereturn_prefs` 中无任何 a11y/overlay 键，冷启动后回到“关”，且拨动前后画面无任何变化（全仓仅 `Index.ets:989/5368` 与 `SettingsPage.ets:55` 两处引用，无消费者）。证据：平板 `3087`（开）／`3089`（重启后关），手机 `3194`（开）／`3197`（重启后关），prefs 快照 `item08-prefs-*-a11y.xml`。
- **R6 已真机确认（双机，A156）**：设置页“默认机器”只在 **4 台**间循环（1920s→1930s→1950s→1960s→1920s），无法选到 2020s；当前机为 2020s 时，行回显回落“1920s 直立式”，点一次直接把当前机写成 1920s（`cycleMachine` 的 `indexOf=-1 → 数组[0]`）。证据：平板 `3121–3124`、`3126–3129`；手机 `3219–3222`、`3227–3231`。
- **R8 已真机确认（双机，A152）**：`ask` 与 `trash` 三处完全一致——确认弹窗文案均为“删除后进回收站，可恢复。”、索引均置 `state=trashed` 并写 `trashedAt`/`origDossierId`、原文件保留、回收站可见；`direct` 弹窗文案为“删除后不可恢复。”、索引条目与文档 JSON 均消失。证据：平板 `3098–3100`／`3108–3110`／`3112–3114`；手机 `3210–3212`／`3213–3215`／`3216–3218`；删除前后索引比对见 §4。
- **R1 已双机复测（A163/A164）**：候选数量拉到 15 后，拼音设置落盘 `custom.candidate.count=15`、hilog `candAll=46`（`candCur` 15 项），候选条仍只显示 **5** 个、无翻页；候选字号 20 与 12 时候选文字高度完全相同（平板 **45px**、手机 **63px**），字号设置无消费者。证据：平板 `3152`／`3159`／`3153`／`3164`；手机 `3260`／`3266`／`3261`／`3269`。
- **R5 再次到场（A159/A168）**：重播页面引导后的 `hintText='已重置，下次进入页面生效'`、清除学习后的 `hintText='学习记录已清除'` 均不出现在画面与 dump 中（`Index.hintText` 仍无渲染器）。
- **新发现 O1（低，双机）**：设置页“每日目标”滑杆拖动时右侧数值文本不刷新（仍显示进页时的 500 字），而滑杆位置、prefs 与主页“今日/目标”均正确；离开设置页再进才显示新值（800 字）。与 R27（换装页字号滑杆数值不刷新）同族。建议新增 **R28**。
- **O2（观察，低，双机）**：我的词库删到空后，prefs 仍保留 `cn_userwords={"shenjici":[],"shenjici2":[]}`（起始为无此键）；无用户可见影响，属清理不彻底。

## 2. 逐项结果

> 结果口径：**通过**＝该控件在双机真机上完成预期操作且画面/落盘可证；判定以截图为准（AGENTS 识屏验收铁律），hilog/prefs/dump 只作辅助。A163/A164 的“通过”指控件本身，R1 限制另列。截图号见 §9。

| 编号 | 控件 | 平板 | 手机 | 关键证据（截图号） | 实际操作与结论 |
|---|---|---|---|---|---|
| A146 | 返回 | **通过** | **通过** | 3094 / 3285 | 设置页左上返回 → 弹栈回主页（主页 hero、统计、底部入口可见）。两机均从页内返回按钮进入主页，未用系统返回替代。 |
| A147 | 引导“?” | **通过** | **通过** | 3077–3080 / 3184–3187 | 点页眉“?”弹出 3 步引导（声音/触感/修正方式 → 默认机纸 → 重播引导），每步按钮坐标随气泡变化，末步“知道了”关闭。两机均完整走完 3 步。 |
| A148 | “音效”开关 | **通过** | **通过** | 3081/3082 / 3188/3189 | 关→`sound_enabled=false`、开→`true`；开关视觉同步。最终恢复开。 |
| A149 | “音量”滑杆 | **通过** | **通过** | 3085、3086d / 3192 | 平板 70%→**15%**（prefs `volume=0.15`）→拖回 **70%**（0.70）；手机 70%→**18%**（0.18），回拖只到 **68%**（0.68，见 §8）。滑杆数值文本实时刷新。 |
| A150 | “按键震动”开关 | **通过** | **通过** | 3083/3084 / 3190/3191 | 关→`vibration_enabled=false`、开→`true`；最终恢复开。 |
| A151 | “无障碍覆盖层”开关 | **通过（R2 确认）** | **通过（R2 确认）** | 3087/3089 / 3194/3197 | 拨开：开关变亮、prefs **无 a11y/overlay 键**、画面无任何变化；force-stop/重启后开关回关。代码全仓无消费者。 |
| A152 | “删除方式”行 | **通过（R8 确认）** | **通过（R8 确认）** | 3090–3092、3093、3098–3100、3108–3110、3112–3114 / 3198–3200、3210–3212、3213–3215、3216–3218 | 点击循环“进回收站→先问→直接删除→进回收站”，prefs 同步 `trash/ask/direct`。R8 实测见 §1：ask/trash 同效，direct 永久删。最终两机均回 `trash`。 |
| A153 | “中文输入”行 | **通过** | **通过** | 3115/3116 / 3201/3202、3253 | 内置拼音↔系统输入法切换，prefs `cn_engine` 同步；切换时不处于中文模式，无 attach/IME 弹出。手机测试中曾被误切到 system，已切回 `builtin`（3253）。 |
| A154 | “拼音设置”行 | **通过** | **通过** | 3146 / 3254 | 压栈拼音设置页；页眉“拼音设置”、候选栏/模糊拼音/我的词库/学习记录/词库信息齐全。 |
| A155 | “每日目标”滑杆 | **通过（O1）** | **通过（O1）** | 3117/3118/3119/3120 / 3203/3204/3273b | 平板 500→800：prefs `stats.daily_goal=800`，主页“目标 800 字”即时刷新（3118）；**设置页行文本仍显示 500 字**（3117），重进设置显示 800（3119）。手机同样：滑杆已到 800、行文本仍 500（3203），主页 800（3204）。最终均恢复 500。 |
| A156 | “默认机型”行 | **通过（R6 确认）** | **通过（R6 确认）** | 3121–3124、3126–3129 / 3219–3222、3227–3231 | 4 次点击依次 1930s→1950s→1960s→1920s，prefs 同步，**无 2020s**。从主题页切到 2020s 后回设置：行显示“1920s 直立式”（3128/3230），点一次机器变 `1920s-upright`（3129/3231）。最终 1920s。 |
| A157 | “默认纸张”行 | **通过** | **通过** | 3130–3133 / 3223–3226 | 信纸→稿纸→明信片→便签→信纸，prefs `paper` 同步；最终 letter。 |
| A158 | “回收站”行 | **通过** | **通过** | 3134 / 3232 | 压栈回收站页；平板 3 条（含本批两条测试纸）、手机 2 条（本批两条）。本批在该页彻底删除测试纸：平板 3135/3136、3135b/3136b；手机 3233/3234、3233b/3234b。最终平板回收站回 1 条、手机 0 条。 |
| A159 | “重播页面引导”行 | **通过（R5）** | **通过（R5）** | 3137/3138/3139/3140 / 3243/3244/3246/3247 | 点击后 14 个 `guide.*.seen` 全变 false（prefs 对比）；画面不出现任何提示（R5）。离开再进设置页，3 步引导自动弹出；关闭后 settings.seen 回 true。其余 10 页保持 false（见 §8）。 |
| A160 | “重播启动引导”行 | **通过** | **通过** | 3142/3143/3144/3145 / 3248/3249/3250/3251 | 点击立即全屏弹出启动引导；`onboarding_seen` 由 true→false；走一页后“跳过”，`onboarding_seen` 回 true、`guide.home.seen` 同步 true。 |
| A161 | 返回 | **通过** | **通过** | 3171 / 3284 | 拼音设置页左上返回 → 弹栈回设置页（6 组设置仍在）。 |
| A162 | 引导“?” | **通过** | **通过** | 3146–3151 / 3254–3259 | 进入时因 seen=false 自动弹 3 步（引擎/候选栏/我的词库）；关闭后点“?”可重拉。两机均完整走完 3 步并重拉一次。 |
| A163 | “候选数量”滑杆 | **通过（R1）** | **通过（R1）** | 3152、3159 / 3260、3266 | 9→15：prefs `custom.candidate.count=15`；回打字机中文打 `ni`，hilog `candAll=46 candCur=尼,你,溺爱,…`（15 项），候选条仍 **5** 个、无翻页。最终恢复 9（3170/3274）。 |
| A164 | “候选字号”滑杆 | **通过（R1）** | **通过（R1）** | 3153、3164 / 3261、3269 | 15→20 与 12：prefs `custom.candidate.size` 同步；候选文字高度 20 与 12 完全相同（平板 45px、手机 63px）。最终恢复 15（3170/3274）。 |
| A165 | “模糊拼音”行 | **通过** | **通过** | 3154/3162、3160、3167b / 3262/3268、3267、3271 | 行“关↔开”、`cn_fuzzy` 同步。开：打 `nin` 候选含“宁”（3159/3160、3266/3267）；关：打完整音节 `si` 候选为“死,四,四安…”无“是”（3167b、3271）。最终恢复关。注：3165 在 fuzzy 关时 `nin` 仍含“宁”，因 `nin` 是 `ning` 的不完整前缀，属正常前缀匹配，非模糊音泄漏。 |
| A166 | “添加词组”行 | **通过** | **通过** | 3173 / 3275 | 弹出添加词组弹窗（词组输入、拼音输入、取消、添加）。 |
| A167 | “管理我的词库”行 | **通过** | **通过** | 3178 / 3280 | 弹出词库管理弹窗，显示词条行与“完成”；加词后行数/词库信息同步（2 条）。 |
| A168 | “清除学习与联想记录”行 | **通过（R5）** | **通过（R5）** | 3181 / 3283 | 点击前平板 4 条/手机 2 条；点击后 `cn_learn={}`、`cn_bigram={}`、行显示 0 条；**无“学习记录已清除”提示**（R5）。 |
| A169 | 添加弹窗-词组输入 | **通过** | **通过** | 3175 / 3277 | 聚焦词组输入，注入“审计词”，自动推导拼音 `shenjici` 并填入第二输入框。 |
| A170 | 添加弹窗-拼音输入 | **通过** | **通过** | 3176 / 3278 | 聚焦拼音框末尾注入 `2`，值变为 `shenjici2`，可手改。 |
| A171 | 添加弹窗-取消 | **通过** | **通过** | 3174 / 3276 | 点取消关闭弹窗；词库仍 0 条、prefs 无新增。 |
| A172 | 添加弹窗-添加 | **通过** | **通过** | 3177 / 3279 | 点添加：弹窗关闭；`cn_userwords={"shenjici":["审计词"],"shenjici2":["审计词"]}`（自动推导＋手改拼音各一条，符合多音变体口径）；行“2 条”、词库信息“含我的词库 2 条”；hilog `userwords saved keys=2`。 |
| A173 | 词库弹窗-删除某词 | **通过** | **通过** | 3179 / 3281 | 点词条行删除：两个拼音键下的“审计词”均移除，`cn_userwords={"shenjici":[],"shenjici2":[]}`，行 0 条、词库信息 0 条；弹窗显示“还没有自定义词组”。 |
| A174 | 词库弹窗-完成 | **通过** | **通过** | 3180 / 3282 | 点完成关闭弹窗，回到拼音设置页。 |

## 3. 问题清单

| 编号 | 对应 | 类型 | 问题 | 证据 | 复现（双机通用） |
|---|---|---|---|---|---|
| O1 | A155；新（建议 R28） | UI 状态不刷新（低） | 设置页“每日目标”滑杆拖动时，右侧数值文本仍显示进页时的值（500 字），而滑杆位置、prefs `stats.daily_goal` 与主页目标都已更新；离开重进设置页显示新值。 | 平板 3117（滑杆到 800、行仍 500）→3118（主页 800）→3119（重进行 800）→3120（恢复 500）；手机 3203（滑杆到 800、行仍 500）→3204（主页 800）→3273b（恢复 500）。 | 设置→拖“每日目标”滑杆→观察右侧文本；回主页看目标。 |
| O2 | A173；观察 | 数据清理（低） | 我的词库删空后，prefs 仍保留两个空数组键（`{"shenjici":[],"shenjici2":[]}`），起始为无此键；无用户可见影响。 | 平板 3179、手机 3281；end prefs 见 §8。 | 加一个词再删掉，读 `cn_userwords`。 |
| R1 | A163/A164 | 已确认（复测） | 候选数量 15 时条仍 5 个、无翻页；候选字号 20 与 12 的文字高度相同。 | 平板 3152/3159、3153/3164；手机 3260/3266、3261/3269；hilog `candAll=46`。 | 拼音设置拉满数量/字号→回打字机打 `ni`。 |
| R2 | A151 | 已确认（双机） | 无障碍覆盖层开关无消费者、不落盘、重启回关、画面无变化。 | 平板 3087/3089、手机 3194/3197；prefs 无 a11y 键；代码 `Index.ets:989,5368`。 | 拨开开关→看画面→重启 App→再看。 |
| R5 | A159/A168 | 已确认（再次） | `hintText` 不渲染：重播页面引导、清除学习记录均无可见提示。 | 平板 3138、3181；手机 3244、3283；dump 无对应文本。 | 点两行，观察画面。 |
| R6 | A156 | 已确认（循环部分） | `cycleMachine` 只循环 4 台；当前 2020s 时设置行回落 1920s，点按跳回 1920s。 | 平板 3121–3124、3128/3129；手机 3219–3222、3230/3231。 | 设置→默认机器连点；主题页切 2020s 后再看设置行。 |
| R8 | A152 | 已确认（双机） | `ask` 与 `trash` 行为/文案/落盘完全相同，三档实际只有两档效果；`direct` 永久删除。 | 平板 3099/3109/3113；手机 3211/3214/3217；索引比对见 §4。 | 分别在 ask/trash 档删一张测试纸，对照回收站与索引；direct 档再删一张。 |

## 4. 操作过程

### 4.1 平板 MLR-AL10

1. `3071` 起始主页 → 底部“设置”进设置页 `3073`；页眉“?”走 3 步引导 `3077–3079`，关闭 `3080`。
2. 音效关/开 `3081/3082`；音量 70%→15% `3085`→回 70% `3086d`；震动关/开 `3083/3084`。
3. 无障碍开 `3087` → force-stop/`aa start` 冷启动 `3088` → 设置页开关回关 `3089`。
4. 删除方式循环 `3090–3092`；页眉返回主页 `3094` → 卷宗 `3095` → 「测试卷宗二号」内页 `3096` → 新建 3 张测试纸 `3097`。
5. 当前为 `ask`：卡片⋯→删除→确认（“删除后进回收站，可恢复。”）`3098/3099` → 删除后 `3100`；索引 `doc-…61972` 变 `trashed`、文件保留。
6. 回设置把档位切到 `trash`（`3106`）→ 回内页删除 `doc-…87511`：菜单 `3108`、确认 `3109`（文案与 ask 相同）、删除后 `3110`；索引同为 `trashed`、`origDossierId` 保留。
7. 回设置切到 `direct`（`3111`）→ 回内页删除 `doc-…10894`：菜单 `3112`、确认 `3113`（“删除后不可恢复。”）、删除后 `3114`；索引条目与 `documents/doc-…10894.json` 均消失。
8. 回设置切回 `trash`；中文输入内置/系统/内置 `3115/3116`；每日目标 800 `3117` → 主页 `3118` → 重进设置行 800 `3119` → 恢复 500 `3120`。
9. 默认机器四档循环 `3121–3124`；主题页切 2020s `3125/3126` → 主页 `3127` → 设置行回落 1920s `3128` → 点按后机器变 1920s `3129`。
10. 默认纸张四档 `3130–3133`；回收站 `3134`；彻底删除两张测试纸 `3135/3136`、`3135b/3136b`，回收站回 1 条。
11. 重播页面引导：重置前 `3137`、重置后（画面无提示）`3138`、重进自动引导 `3139`、关闭 `3140`；重播启动引导：滚动到关于 `3142`、启动引导第 1/2 页 `3143/3144`、跳过后 `3145`。
12. 拼音设置：进入并自动引导 `3146` → 3 步 `3147/3148` → 关闭 `3149` → 手动“?”重拉 `3150` → 关闭 `3151`。
13. 候选数量 15 `3152`、字号 20 `3153`、模糊开 `3154`；回主页 `3155` 进打字机 `3156` 开中文 `3158`，打 `ni` 得 5 个候选（字号 20，45px）`3159`，打 `nin` 有“宁”`3160`。
14. 回设置改模糊关 `3162`、字号 12 `3163`；再进打字机打 `ni` 仍 45px `3164`、`nin` `3165`、`si` 无“是”`3167b`；清空纸面 `3168`，回主页 `3169`。
15. 回拼音设置恢复 9/15 `3170`；返回设置 `3171`、再进拼音 `3172`；添加词组弹窗 `3173` → 取消 `3174` → 重开输入“审计词” `3175` → 手改拼音 `3176` → 添加 `3177`；管理词库 `3178` → 删词 `3179` → 完成 `3180`；清除学习 `3181`；回主页 `3286`。

### 4.2 手机 ADA-AL00U

1. `3072` 起始主页 → 设置 `3183`；“?”3 步引导 `3184–3186` → 关闭 `3187`。
2. 音效 `3188/3189`、震动 `3190/3191`、音量 70%→18% `3192`（回拖最终 68%，见 §8）。
3. 无障碍开 `3194` → 冷启动 `3195` → 设置页开关回关 `3197`。
4. 删除方式循环 `3198–3200`；中文输入系统/内置 `3201/3202`；每日目标 800（行文本仍 500）`3203` → 主页 800 `3204`。
5. 卷宗 `3206` → 「测试卷宗二号」`3207` → ⋯→新建纸张 `3208` ×3 → 5 张纸 `3209`。
6. `ask` 档：菜单 `3210`、确认（进回收站）`3211`、删除后 `3212`；`doc-…62009` 变 trashed。回设置切 `trash`，删除 `doc-…57633`：确认 `3214`、删除后 `3215`；同为 trashed。回设置切 `direct`（`3216`），删除 `doc-…93700`：确认 `3217`（“不可恢复”）、删除后 `3218`；索引与文件均消失。回设置切回 `trash`。
7. 默认机器循环 `3219–3222`；主题切 2020s `3227/3228` → 主页 `3229` → 设置行回落 `3230` → 点按回 1920s `3231`。默认纸张四档 `3223–3226`。
8. 回收站 `3232`；彻底删除两张测试纸 `3233/3234`、`3233b/3234b`，回 0 条。
9. 重播页面引导：滚动到底 `3243` → 点按后画面无变化 `3244`（prefs 已全 false）→ 重进自动引导 `3246` → 关闭 `3247`；重播启动引导：`3248` → 启动引导第 1/2 页 `3249/3250` → 跳过 `3251`。
10. 回设置恢复内置拼音 `3253`；拼音设置进入并自动引导 `3254` → 3 步 `3255/3256` → 关闭 `3257` → 手动“?”`3258` → 关闭 `3259`。
11. 候选数量 15 `3260`、字号 20 `3261`、模糊开 `3262`；打字机 `3263` 开中文 `3265`，打 `ni` 得 5 个候选（63px）`3266`，`nin` 有“宁”`3267`。
12. 回设置模糊关、字号 12 `3268`；再打 `ni` 仍 63px `3269`、`si` 无“是”`3271`；清空纸面 `3272`。
13. 回设置恢复目标 500 `3273b`、候选 9/15 `3274`；拼音设置添加词组 `3275` → 取消 `3276` → 输入“审计词” `3277` → 手改拼音 `3278` → 添加 `3279`；管理词库 `3280` → 删词 `3281` → 完成 `3282`；清除学习 `3283`。
14. 拼音设置返回 `3284`；设置返回主页 `3285`。

### 4.3 R8 索引落盘对照（原文摘要）

- 平板 ask：`doc-1795593497505-61972` → `state: "trashed"`, `trashedAt: 1795593560786`, `origDossierId: "d1795568897351500"`，`documents/…61972.json` 仍在。
- 平板 trash：`doc-1795593492772-87511` → `state: "trashed"`, `trashedAt: 1795593790614`, `origDossierId` 同上，文件仍在。
- 平板 direct：`doc-1795593495033-10894` → 索引无此条，`documents/…10894.json` 不存在。
- 手机 ask：`doc-1795595458764-62009` → `trashed`，`trashedAt: 1795595524439`，`origDossierId: "d1795568968003158"`。
- 手机 trash：`doc-1795595454115-57633` → `trashed`，`trashedAt: 1795595575236`，`origDossierId` 同上。
- 手机 direct：`doc-1795595449373-93700` → 索引无此条，文件不存在。

## 5. 证据文件

- 逐项截图：`docs/shots/3071–3286`（含 `b` 后缀与 `void_` 前缀），完整索引见 §9。
- 起始/收工 prefs：
  - `docs/evidence/item08-prefs-tablet-start.xml` / `item08-prefs-tablet-end.xml`
  - `docs/evidence/item08-prefs-phone-start.xml` / `item08-prefs-phone-end.xml`
- 无障碍开关 prefs 快照（拨开后仍无 a11y 键）：
  - `docs/evidence/item08-prefs-tablet-a11y.xml`
  - `docs/evidence/item08-prefs-phone-a11y.xml`
- 文档索引抽查：本批临时拉取 `documents-index.json` 比对 ask/trash/direct 三态，结论已写入 §4.3；临时 JSON 未入库。

## 6. 缺口与未验项

- **A149 手机音量未能精确回 70%**：多次拖动只到 68%（下拖 18% 成功、回拖 68%），见 §8；功能本身（落盘、显示、AudioService 调用路径）已验证。
- **A164 候选字号“无效果”的量化**：用候选文字节点高度比较（45/63px），未逐帧比对实际字形位图；与 audit①-3 的测量口径一致。
- **A151 “无消费者”**：本批以全仓 grep（仅 `Index.ets` 两处 + `SettingsPage.ets` prop）＋拨动前后截图＋重启回关三重证据判定；未做系统级无障碍树抓取。
- **A159 重播后其余 10 页的自动引导**：只对 settings 页做了“重进自动弹”抽验，未逐页重进 10 页；prefs 已证明全部置 false。
- **PDF 抬头 2020s 回落**（R6 另一处）不在本批页面，留导出批。

## 7. 工具与方法注记

- `hdc` 路径 `F:\HarmonyOS\SDK\26.0.0\toolchains\hdc.exe`；截图 `snapshot_display -f /data/local/tmp/_cap.jpeg` → `hdc file recv` → PIL 转 PNG。
- 点击仍会丢：本批平板丢击约 4 次（A147 第 3 步前、A156 前、音量回拖、si 的 S 键等），手机丢击约 6 次（A159 重播行两次、A163 前 EN 键、S 键两次等）；均以“同命令重发 + 前后截图 + hilog/prefs”判别，作废图 `void_` 前缀留档。**不要用一次点击无反应判定产品缺陷。**
- **多层返回优先用系统返回键** `uitest uiInput keyEvent 2`（本批实测可逐层弹栈，含 detail/docview/拼音设置），比固定页眉坐标稳；页内返回按钮仍按条目单独验证。
- **滚动页坐标陷阱**：手机设置页滚动后，`uitest dumpLayout` 给出的关于组 y≈3445，但屏幕可见位置约 y≈1900（内容坐标系未随 Scroll 偏移）；按 dump 坐标点击会落到屏外。应以截图定位可见坐标再点。
- 手机底部手势区/系统键盘会吞点击；A160 重播启动引导行需先滚动到可见区再点。
- prefs 读取：`hdc file recv /data/app/el2/100/base/com.dlzz.carriagereturn/haps/entry/preferences/carriagereturn_prefs`；XML 字符串是节点文本、bool/double 是 `value` 属性。控制台打印非 ASCII 可能乱码，文件本身 UTF-8。
- 候选条测量：dump 候选文字节点 bounds 高度；平板 45px、手机 63px（字号 12/15/20 同高）。
- 拼音注入：`uitest uiInput text 审计词` 可整串注入中文；拼音框末尾注入数字 `2` 可验证手改。

## 8. 测试残留与收工状态

- **两台均未 `bm clean`**。收工 prefs：`item08-prefs-*-end.xml`。
- **恢复为起始值的项**：`machine=1920s-upright`、`paper=letter`、`delete_mode=trash`、`sound_enabled=true`、`vibration_enabled=true`、`cn_engine=builtin`、`cn_fuzzy=false`、`custom.candidate.count=9`、`custom.candidate.size=15`、`stats.daily_goal=500`、`onboarding_seen=true`。
- **未精确恢复**：手机 `volume=0.68`（起始未写、默认 70%；多次回拖只到 68%）；平板 `volume=0.70` 已恢复。
- **测试数据**：本批两机各新建 3 张测试纸，均已按 ask/trash/direct 删除并清理；文档净数量回到起始（平板 active 5/trash 1，手机 active 4/trash 0）。
- **学习记录已按 A168 清空**：两机 `cn_learn={}`、`cn_bigram={}`（起始平板 4 条/手机 2 条），不可通过 UI 恢复；属 A168 功能验证的必然副作用。
- **我的词库**：两机 `cn_userwords={"shenjici":[],"shenjici2":[]}`（起始无此键），O2。
- **星数/字数副作用**：两机 `stats.day.chars` +2（平板 48→50、手机 47→49），`stats.total.chars` 同步 +2，`stats.event.doc_saved` +2（101→103 / 78→80），`stats.event.paper_changed` +4（6→10 / 5→9，A157 纸种循环）。均为真实用户行为触发，属测试副作用。
- **页面引导 seen**：A159 重播把 14 页全部置 false；本批关闭了 settings、pinyin_settings 两页引导（回 true），其余 **10 页仍为 false**：collection、collection_detail、customize、document_view、dossier、dossier_detail、export、font_manager、paper_custom、trash。下次进入这些页会自动弹引导；如需恢复，逐页进入关闭即可。
- **收工画面**：平板主页 `3286`；手机主页 `3285`。
- `void_` 前缀 27 张为点击丢失/时序错位/中间态作废图，保留作过程证据。

## 9. 截图索引（3071–3286）

> 命名 `<编号>_audit08_<设备>_<内容>.png`；同号 `b` 后缀为同一步骤的第二张（如两次彻底删除）；`void_` 前缀＝作废图（点击未命中、坐标错误、中间态），列在 §9.3。完整 203 张有效图如下。

### 9.1 平板（1600×2560）

| 截图 | 文件 | 内容 |
|---|---|---|
| 3071 | `3071_audit08_tablet_start.png` | 起始主页 |
| 3073 | `3073_audit08_tablet_settings.png` | 设置页 |
| 3074 | `3074_audit08_tablet_settings_guide1.png` | 设置引导第1步 |
| 3075 | `3075_audit08_tablet_settings_guide2.png` | 设置引导第2步 |
| 3077 | `3077_audit08_tablet_settings_guide_step1.png` | 设置引导复拍第1步 |
| 3078 | `3078_audit08_tablet_settings_guide_step2.png` | 设置引导复拍第2步 |
| 3079 | `3079_audit08_tablet_settings_guide_step3.png` | 设置引导复拍第3步 |
| 3080 | `3080_audit08_tablet_settings_guide_closed.png` | 设置引导关闭 |
| 3081 | `3081_audit08_tablet_sound_off.png` | 音效关 |
| 3082 | `3082_audit08_tablet_sound_on.png` | 音效开 |
| 3083 | `3083_audit08_tablet_vibrate_off.png` | 按键震动关 |
| 3084 | `3084_audit08_tablet_vibrate_on.png` | 按键震动开 |
| 3085 | `3085_audit08_tablet_volume_low.png` | 音量拉低 |
| 3086d | `3086d_audit08_tablet_volume_restore.png` | 音量恢复70%（有效） |
| 3087 | `3087_audit08_tablet_a11y_on.png` | 无障碍覆盖层开 |
| 3088 | `3088_audit08_tablet_restart_home.png` | 冷启动主页 |
| 3089 | `3089_audit08_tablet_a11y_after_restart.png` | 重启后设置页(开关回关) |
| 3090 | `3090_audit08_tablet_deletemode_ask.png` | 删除方式=先问 |
| 3091 | `3091_audit08_tablet_deletemode_direct.png` | 删除方式=直接删除 |
| 3092 | `3092_audit08_tablet_deletemode_trash.png` | 删除方式=进回收站 |
| 3093 | `3093_audit08_tablet_deletemode_ask_confirm.png` | 删除方式=先问(复现) |
| 3094 | `3094_audit08_tablet_settings_back_home.png` | 设置返回主页 |
| 3095 | `3095_audit08_tablet_dossier.png` | 卷宗页 |
| 3096 | `3096_audit08_tablet_dossier_detail.png` | 卷宗内页 |
| 3097 | `3097_audit08_tablet_detail_three_test_papers.png` | 内页三张测试纸 |
| 3098 | `3098_audit08_tablet_paper_menu_ask.png` | 纸卡菜单(ask) |
| 3099 | `3099_audit08_tablet_delete_confirm_ask.png` | 删除确认(ask) |
| 3100 | `3100_audit08_tablet_after_delete_ask.png` | ask删除后 |
| 3104 | `3104_audit08_tablet_after_backkey.png` | 系统返回后(卷宗页) |
| 3105 | `3105_audit08_tablet_home.png` | 主页 |
| 3106 | `3106_audit08_tablet_deletemode_trash_final.png` | 删除方式回进回收站 |
| 3107 | `3107_audit08_tablet_detail_for_trash_delete.png` | trash删除前内页 |
| 3108 | `3108_audit08_tablet_paper_menu_trash.png` | 纸卡菜单(trash) |
| 3109 | `3109_audit08_tablet_delete_confirm_trash.png` | 删除确认(trash) |
| 3110 | `3110_audit08_tablet_after_delete_trash.png` | trash删除后 |
| 3111 | `3111_audit08_tablet_deletemode_direct.png` | 删除方式=直接删除 |
| 3112 | `3112_audit08_tablet_paper_menu_direct.png` | 纸卡菜单(direct) |
| 3113 | `3113_audit08_tablet_delete_confirm_direct.png` | 删除确认(direct) |
| 3114 | `3114_audit08_tablet_after_delete_direct.png` | direct删除后 |
| 3115 | `3115_audit08_tablet_cn_system.png` | 中文输入=系统输入法 |
| 3116 | `3116_audit08_tablet_cn_builtin.png` | 中文输入=内置拼音 |
| 3117 | `3117_audit08_tablet_goal_800.png` | 每日目标800(行文本仍500) |
| 3118 | `3118_audit08_tablet_home_goal_refresh.png` | 主页目标刷新800 |
| 3119 | `3119_audit08_tablet_goal_row_800.png` | 重进设置行800 |
| 3120 | `3120_audit08_tablet_goal_row_500.png` | 恢复500 |
| 3121 | `3121_audit08_tablet_machine_1930s.png` | 默认机器1930s |
| 3122 | `3122_audit08_tablet_machine_1950s.png` | 默认机器1950s |
| 3123 | `3123_audit08_tablet_machine_1960s.png` | 默认机器1960s |
| 3124 | `3124_audit08_tablet_machine_1920s.png` | 默认机器1920s |
| 3125 | `3125_audit08_tablet_theme.png` | 主题页 |
| 3126 | `3126_audit08_tablet_theme_2020s.png` | 主题页切2020s |
| 3127 | `3127_audit08_tablet_home_2020s.png` | 主页2020s |
| 3128 | `3128_audit08_tablet_settings_machine_2020s_fallback.png` | 设置机名回落1920s |
| 3129 | `3129_audit08_tablet_settings_machine_after_2020s_tap.png` | 点按后机器变1920s |
| 3130 | `3130_audit08_tablet_paper_manuscript.png` | 默认纸张稿纸 |
| 3131 | `3131_audit08_tablet_paper_postcard.png` | 默认纸张明信片 |
| 3132 | `3132_audit08_tablet_paper_memo.png` | 默认纸张便签 |
| 3133 | `3133_audit08_tablet_paper_letter.png` | 默认纸张信纸 |
| 3134 | `3134_audit08_tablet_trash_from_settings.png` | 设置进回收站 |
| 3135 | `3135_audit08_tablet_purge_confirm_1972.png` | 彻底删除确认(1972) |
| 3135b | `3135b_audit08_tablet_purge_confirm_7511.png` | 彻底删除确认(7511) |
| 3136 | `3136_audit08_tablet_after_purge_1972.png` | 彻底删除测试纸后 |
| 3136b | `3136b_audit08_tablet_after_purge_7511.png` | 彻底删除第二张后 |
| 3137 | `3137_audit08_tablet_settings_before_replay.png` | 重播页面引导前 |
| 3138 | `3138_audit08_tablet_settings_after_replay_novisible.png` | 重播后画面无提示 |
| 3139 | `3139_audit08_tablet_settings_guide_auto_after_replay.png` | 重进设置自动引导 |
| 3140 | `3140_audit08_tablet_settings_guide_closed_again.png` | 自动引导关闭 |
| 3142 | `3142_audit08_tablet_settings_scrolled.png` | 设置滚动到关于组 |
| 3143 | `3143_audit08_tablet_onboarding_replay_page1.png` | 重播启动引导第1页 |
| 3144 | `3144_audit08_tablet_onboarding_replay_page2.png` | 启动引导第2页 |
| 3145 | `3145_audit08_tablet_after_onboarding_skip.png` | 跳过启动引导后 |
| 3146 | `3146_audit08_tablet_pinyin_settings_entry_guide.png` | 拼音设置进入(自动引导) |
| 3147 | `3147_audit08_tablet_pinyin_guide2.png` | 拼音引导第2步 |
| 3148 | `3148_audit08_tablet_pinyin_guide3.png` | 拼音引导第3步 |
| 3149 | `3149_audit08_tablet_pinyin_guide_closed.png` | 拼音引导关闭 |
| 3150 | `3150_audit08_tablet_pinyin_guide_manual.png` | 拼音引导手动重拉 |
| 3151 | `3151_audit08_tablet_pinyin_clean.png` | 拼音设置页(无引导) |
| 3152 | `3152_audit08_tablet_cand_count_15.png` | 候选数量15 |
| 3153 | `3153_audit08_tablet_cand_size_20.png` | 候选字号20 |
| 3154 | `3154_audit08_tablet_fuzzy_on.png` | 模糊拼音开 |
| 3155 | `3155_audit08_tablet_home_before_typing.png` | 进入打字机前主页 |
| 3156 | `3156_audit08_tablet_typewriter.png` | 打字机页 |
| 3157 | `3157_audit08_tablet_cand_ni_count15_size20_fuzzy.png` | 候选ni(数量15字号20模糊开) |
| 3158 | `3158_audit08_tablet_chinese_mode.png` | 切中文模式 |
| 3159 | `3159_audit08_tablet_cand_ni.png` | 候选ni(5个) |
| 3160 | `3160_audit08_tablet_cand_nin_fuzzy.png` | 候选nin(模糊开，含宁) |
| 3161 | `3161_audit08_tablet_home_after_typing.png` | 打字后主页 |
| 3162 | `3162_audit08_tablet_fuzzy_off.png` | 模糊拼音关 |
| 3163 | `3163_audit08_tablet_cand_size_12.png` | 候选字号12 |
| 3164 | `3164_audit08_tablet_cand_ni_size12.png` | 候选ni(字号12) |
| 3165 | `3165_audit08_tablet_cand_nin_fuzzy_off.png` | 候选nin(模糊关) |
| 3167b | `3167b_audit08_tablet_cand_si_fuzzy_off.png` | 候选si(模糊关，无是) |
| 3168 | `3168_audit08_tablet_paper_clean.png` | 纸面已清空 |
| 3169 | `3169_audit08_tablet_home_after_clean.png` | 清空纸面后主页 |
| 3170 | `3170_audit08_tablet_cand_settings_restored.png` | 候选设置恢复9/15 |
| 3171 | `3171_audit08_tablet_pinyin_back_to_settings.png` | 拼音设置返回设置页 |
| 3172 | `3172_audit08_tablet_pinyin_reenter.png` | 重进拼音设置 |
| 3173 | `3173_audit08_tablet_addword_dialog.png` | 添加词组弹窗 |
| 3174 | `3174_audit08_tablet_addword_cancel.png` | 取消添加 |
| 3175 | `3175_audit08_tablet_addword_typed.png` | 输入审计词(自动拼音) |
| 3176 | `3176_audit08_tablet_addword_pinyin_edited.png` | 手改拼音shenjici2 |
| 3177 | `3177_audit08_tablet_addword_added.png` | 添加后2条 |
| 3178 | `3178_audit08_tablet_manage_words.png` | 我的词库弹窗 |
| 3179 | `3179_audit08_tablet_manage_after_delete.png` | 删词后0条 |
| 3180 | `3180_audit08_tablet_manage_closed.png` | 完成关闭词库弹窗 |
| 3181 | `3181_audit08_tablet_clear_learn.png` | 清除学习记录 |
| 3286 | `3286_audit08_tablet_final_home.png` | 收工主页 |

### 9.2 手机（1224×2776）

| 截图 | 文件 | 内容 |
|---|---|---|
| 3072 | `3072_audit08_phone_start.png` | 起始主页 |
| 3182 | `3182_audit08_phone_home.png` | 主页 |
| 3183 | `3183_audit08_phone_settings.png` | 设置页 |
| 3184 | `3184_audit08_phone_settings_guide1.png` | 设置引导第1步 |
| 3185 | `3185_audit08_phone_settings_guide2.png` | 设置引导第2步 |
| 3186 | `3186_audit08_phone_settings_guide3.png` | 设置引导第3步 |
| 3187 | `3187_audit08_phone_settings_guide_closed.png` | 设置引导关闭 |
| 3188 | `3188_audit08_phone_sound_off.png` | 音效关 |
| 3189 | `3189_audit08_phone_sound_on.png` | 音效开 |
| 3190 | `3190_audit08_phone_vibrate_off.png` | 按键震动关 |
| 3191 | `3191_audit08_phone_vibrate_on.png` | 按键震动开 |
| 3192 | `3192_audit08_phone_volume_low.png` | 音量拉低 |
| 3194 | `3194_audit08_phone_a11y_on.png` | 无障碍覆盖层开 |
| 3195 | `3195_audit08_phone_restart_home.png` | 冷启动主页 |
| 3197 | `3197_audit08_phone_a11y_after_restart.png` | 重启后设置页(开关回关) |
| 3198 | `3198_audit08_phone_deletemode_ask.png` | 删除方式=先问 |
| 3199 | `3199_audit08_phone_deletemode_direct.png` | 删除方式=直接删除 |
| 3200 | `3200_audit08_phone_deletemode_trash.png` | 删除方式=进回收站 |
| 3201 | `3201_audit08_phone_cn_system.png` | 中文输入=系统输入法 |
| 3202 | `3202_audit08_phone_cn_builtin.png` | 中文输入=内置拼音 |
| 3203 | `3203_audit08_phone_goal_800.png` | 每日目标800(行文本仍500) |
| 3204 | `3204_audit08_phone_home_goal_800.png` | 主页目标刷新800 |
| 3205 | `3205_audit08_phone_goal_500.png` | 恢复500 |
| 3206 | `3206_audit08_phone_dossier.png` | 卷宗页 |
| 3207 | `3207_audit08_phone_dossier_detail.png` | 卷宗内页 |
| 3208 | `3208_audit08_phone_detail_menu.png` | 卷宗内页⋯菜单 |
| 3209 | `3209_audit08_phone_detail_three_papers.png` | 内页三张测试纸 |
| 3210 | `3210_audit08_phone_paper_menu_ask.png` | 纸卡菜单(ask) |
| 3211 | `3211_audit08_phone_delete_confirm_ask.png` | 删除确认(ask) |
| 3212 | `3212_audit08_phone_after_delete_ask.png` | ask删除后 |
| 3213 | `3213_audit08_phone_detail_before_trash_delete.png` | trash删除前内页 |
| 3214 | `3214_audit08_phone_delete_confirm_trash.png` | 删除确认(trash) |
| 3215 | `3215_audit08_phone_after_delete_trash.png` | trash删除后 |
| 3216 | `3216_audit08_phone_deletemode_direct_again.png` | 删除方式=直接删除(复测) |
| 3217 | `3217_audit08_phone_delete_confirm_direct.png` | 删除确认(direct) |
| 3218 | `3218_audit08_phone_after_delete_direct.png` | direct删除后 |
| 3219 | `3219_audit08_phone_machine_1930s.png` | 默认机器1930s |
| 3220 | `3220_audit08_phone_machine_1950s.png` | 默认机器1950s |
| 3221 | `3221_audit08_phone_machine_1960s.png` | 默认机器1960s |
| 3222 | `3222_audit08_phone_machine_1920s.png` | 默认机器1920s |
| 3223 | `3223_audit08_phone_paper_manuscript.png` | 默认纸张稿纸 |
| 3224 | `3224_audit08_phone_paper_postcard.png` | 默认纸张明信片 |
| 3225 | `3225_audit08_phone_paper_memo.png` | 默认纸张便签 |
| 3226 | `3226_audit08_phone_paper_letter.png` | 默认纸张信纸 |
| 3227 | `3227_audit08_phone_theme.png` | 主题页 |
| 3228 | `3228_audit08_phone_theme_2020s.png` | 主题页切2020s |
| 3229 | `3229_audit08_phone_home_2020s.png` | 主页2020s |
| 3230 | `3230_audit08_phone_settings_machine_2020s_fallback.png` | 设置机名回落1920s |
| 3231 | `3231_audit08_phone_settings_machine_after_2020s_tap.png` | 点按后机器变1920s |
| 3232 | `3232_audit08_phone_trash_from_settings.png` | 设置进回收站 |
| 3233 | `3233_audit08_phone_purge_confirm_2009.png` | 彻底删除确认(2009) |
| 3233b | `3233b_audit08_phone_purge_confirm_7633.png` | 彻底删除确认(7633) |
| 3234 | `3234_audit08_phone_after_purge_2009.png` | 彻底删除测试纸后 |
| 3234b | `3234b_audit08_phone_after_purge_7633.png` | 彻底删除第二张后 |
| 3237 | `3237_audit08_phone_settings_guide_auto_after_replay.png` | 重进设置自动引导 |
| 3238 | `3238_audit08_phone_settings_guide_closed_again.png` | 自动引导关闭 |
| 3243 | `3243_audit08_phone_settings_bottom.png` | 设置滚到底 |
| 3244 | `3244_audit08_phone_after_tap_replay.png` | 重播重置后画面无提示 |
| 3246 | `3246_audit08_phone_settings_guide_auto_after_replay.png` | 重进设置自动引导 |
| 3247 | `3247_audit08_phone_settings_guide_closed_again.png` | 自动引导关闭 |
| 3248 | `3248_audit08_phone_settings_bottom_again.png` | 设置再次滚到底 |
| 3249 | `3249_audit08_phone_onboarding_replay_page1.png` | 重播启动引导第1页 |
| 3250 | `3250_audit08_phone_onboarding_replay_page2.png` | 启动引导第2页 |
| 3251 | `3251_audit08_phone_after_onboarding_skip.png` | 跳过启动引导后 |
| 3252 | `3252_audit08_phone_settings_top_again.png` | 设置回顶部 |
| 3253 | `3253_audit08_phone_cn_builtin_restored.png` | 中文输入恢复内置拼音 |
| 3254 | `3254_audit08_phone_pinyin_settings_entry_guide.png` | 拼音设置进入(自动引导) |
| 3255 | `3255_audit08_phone_pinyin_guide2.png` | 拼音引导第2步 |
| 3256 | `3256_audit08_phone_pinyin_guide3.png` | 拼音引导第3步 |
| 3257 | `3257_audit08_phone_pinyin_guide_closed.png` | 拼音引导关闭 |
| 3258 | `3258_audit08_phone_pinyin_guide_manual.png` | 拼音引导手动重拉 |
| 3259 | `3259_audit08_phone_pinyin_clean.png` | 拼音设置页(无引导) |
| 3260 | `3260_audit08_phone_cand_count_15.png` | 候选数量15 |
| 3261 | `3261_audit08_phone_cand_size_20.png` | 候选字号20 |
| 3262 | `3262_audit08_phone_fuzzy_on.png` | 模糊拼音开 |
| 3263 | `3263_audit08_phone_typewriter.png` | 打字机页 |
| 3265 | `3265_audit08_phone_chinese_mode.png` | 切中文模式 |
| 3266 | `3266_audit08_phone_cand_ni.png` | 候选ni(5个) |
| 3267 | `3267_audit08_phone_cand_nin_fuzzy.png` | 候选nin(模糊开，含宁) |
| 3268 | `3268_audit08_phone_size12_fuzzy_off.png` | 字号12+模糊关 |
| 3269 | `3269_audit08_phone_cand_ni_size12.png` | 候选ni(字号12) |
| 3271 | `3271_audit08_phone_cand_si_fuzzy_off.png` | 候选si(模糊关，无是) |
| 3272 | `3272_audit08_phone_paper_clean.png` | 纸面已清空 |
| 3273b | `3273b_audit08_phone_goal_500.png` | 恢复500 |
| 3274 | `3274_audit08_phone_cand_settings_restored.png` | 候选设置恢复9/15 |
| 3275 | `3275_audit08_phone_addword_dialog.png` | 添加词组弹窗 |
| 3276 | `3276_audit08_phone_addword_cancel.png` | 取消添加 |
| 3277 | `3277_audit08_phone_addword_typed.png` | 输入审计词(自动拼音) |
| 3278 | `3278_audit08_phone_addword_pinyin_edited.png` | 手改拼音shenjici2 |
| 3279 | `3279_audit08_phone_addword_added.png` | 添加后2条 |
| 3280 | `3280_audit08_phone_manage_words.png` | 我的词库弹窗 |
| 3281 | `3281_audit08_phone_manage_after_delete.png` | 删词后0条 |
| 3282 | `3282_audit08_phone_manage_closed.png` | 完成关闭词库弹窗 |
| 3283 | `3283_audit08_phone_clear_learn.png` | 清除学习记录 |
| 3284 | `3284_audit08_phone_pinyin_back_to_settings.png` | 拼音设置返回设置页 |
| 3285 | `3285_audit08_phone_settings_back_home.png` | 设置返回主页 |

### 9.3 作废图（`void_` 前缀）

| 文件 | 作废原因 |
|---|---|
| `void_3076_audit08_tablet_settings_guide3.png` | 第二次点按落在引导气泡外，引导被关闭（非第3步） |
| `void_3086_audit08_tablet_volume_70.png` | 音量回拖到71%，非目标70% |
| `void_3086b_audit08_tablet_volume_restore.png` | 音量回拖未到70% |
| `void_3086c_audit08_tablet_volume_restore.png` | 音量回拖未到70% |
| `void_3101_audit08_tablet_deletemode_trash_again.png` | 导航坐标错位，实际仍在卷宗内页 |
| `void_3102_audit08_tablet_detail_before_trash_delete.png` | 导航错位后进入文档视图 |
| `void_3103_audit08_tablet_home_again.png` | 按错层后的中间页 |
| `void_3141_audit08_tablet_onboarding_replay_page1.png` | 重播启动引导行在屏外，点击未命中 |
| `void_3166_audit08_tablet_cand_si_fuzzy_off.png` | S键坐标错误，仅输入i |
| `void_3166b_audit08_tablet_cand_si_fuzzy_off.png` | S键坐标错误，未产生新拼音 |
| `void_3166c_audit08_tablet_cand_si_fuzzy_off.png` | S键坐标错误，缓冲为ii |
| `void_3166d_audit08_tablet_cand_si_fuzzy_off.png` | S键未命中，缓冲为ii |
| `void_3167_audit08_tablet_cand_si_fuzzy_off.png` | S键命中错误，缓冲为isi |
| `void_3193_audit08_phone_volume_restore.png` | 手机音量回拖到69% |
| `void_3193b_audit08_phone_volume_70.png` | 手机音量回拖到68% |
| `void_3193c_audit08_phone_volume_final.png` | 手机音量最终68%（未达70%） |
| `void_3196_audit08_phone_a11y_after_restart.png` | 冷启动后首次点击设置未命中，仍在主页 |
| `void_3235_audit08_phone_settings_before_replay.png` | 滚动后重播引导行点击未命中 |
| `void_3236_audit08_phone_settings_after_replay_novisible.png` | 未重置，仍为旧页 |
| `void_3239_audit08_phone_settings_after_replay_novisible.png` | 按 dump 坐标点击落屏外 |
| `void_3240_audit08_phone_settings_guide_auto_after_replay.png` | 未重置后的自动引导(无) |
| `void_3241_audit08_phone_settings_guide_closed_again.png` | 未重置后的关闭(无) |
| `void_3242_audit08_phone_settings_after_replay_novisible.png` | 点击未命中，页面回顶 |
| `void_3245_audit08_phone_after_tap_replay2.png` | 重置成功后的重复点击 |
| `void_3264_audit08_phone_cand_ni.png` | EN 键首次未命中，英文 ni 落纸 |
| `void_3270_audit08_phone_cand_si_fuzzy_off.png` | S键坐标错误，得到di |
| `void_3273_audit08_phone_goal_restore.png` | 目标恢复中间态400（最终500见3273b） |

## 10. 清单状态建议（供 Kit 统一维护）

- **A146–A150、A153–A155、A157–A158、A160–A162、A165–A174**：改「已验证（2026-11-25 双机）」。
- **A151**：保持「未接线」；备注“2026-11-25 双机确认 R2：开关仅内存、无消费者、无落盘，重启回 false（平板 3087/3089、手机 3194/3197；拨开后 prefs 无 a11y 键）”。
- **A152**：保持「已接线」；备注“2026-11-25 双机确认 R8：ask 与 trash 确认文案/落盘/回收站行为一致；direct 永久删除（平板 3098–3114、手机 3210–3218）”。
- **A156**：改「已验证（2026-11-25 双机）」；备注“R6 双机确认：只循环 1920s/1930s/1950s/1960s 四台；当前 2020s 时行回显回落 1920s，点按跳回 1920s（平板 3121–3129、手机 3219–3231）”。
- **A159**：改「已验证（2026-11-25 双机）」；备注“14 页 seen 全重置；重进设置自动弹引导；`hintText` 不可见（R5）”。
- **A163/A164**：改「已验证（设置生效，2026-11-25 双机）」；备注“数量 15/字号 20 均落盘；候选条仍 5 个、无翻页；字号 12 与 20 候选文字同高（平板 45px、手机 63px）——R1 已确认”。
- **R1**：备注“2026-11-25 核查①-8 双机复测：候选数量 15 时 hilog candCur 15 项、条仍 5；字号 20 与 12 文字高度相同（平板 45px、手机 63px）”。
- **R2**：改「已确认（双机，2026-11-25）」；备注 A151 证据号与“prefs 无键、重启回关”。
- **R5**：备注“A159 重播页面引导、A168 清除学习记录均无可见提示（双机截图/dump）”。
- **R6**：备注“A156 双机确认：cycleMachine 只四台 + 2020s 回显/点按回落 1920s；PDF 抬头仍待导出批”。
- **R8**：改「已确认（双机，2026-11-25）」；备注“ask==trash（文案/落盘/回收站一致），direct 永久删；证据平板 3098–3114、手机 3210–3218”。
- **新增 R28（建议）**：设置页“每日目标”滑杆拖动时右侧数值文本不刷新（O1，双机；prefs 与主页正确，离开重进才更新）。
- 清单文件 `item01-inventory.md` 本批未改动，以上仅为建议。
