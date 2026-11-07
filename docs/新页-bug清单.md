# 新页 bug 清单（2026-11-07）

分析范围：`0db0e69..1c3c28f` 共 43 笔提交，新页 7 页（§2.10 清单）＋数据层＋Index 接线。
方法：逐文件读码（7 个新组件＋`Immersive`／`DossierStore`／`DocStore`／`DocModel`／`Index` diff），
对照设计稿 §2.10／§3／§4／§5／§6 与各提交自述，另看两张证据截图
（`imm-customize-phone.jpeg`、`imm-detail-phone.jpeg`）。

结论先说：沉浸式本身基本是对的（5 个已建页都走了 `applyImmersive()`，截图里顶栏/底距没穿帮），
bug 集中在导航、数据归属、飞出动画、换装联动四处。P0 共 4 个，P1 共 11 个，P2 共 15 个。
另有 5 项“看着像 bug、核实后不是”，列在末尾，免得返工。

---

## P0：功能坏掉／数据丢，必须先修

### P0-1 卷宗页没有返回入口，进去了回不去主屏

- 位置：`components/DossierPage.ets`
- 事实：顶栏只有“卷宗”＋“新建卷宗”，没有返回箭头；`onBack` 声明了（第 36 行）但全组件一次都没调用；
  全仓没有任何系统返回键处理（`onBackPressed`／`onKeyEvent` 零命中）。
- 后果：从主屏点“库”进卷宗页后，应用内无路回主屏，只能杀 App 重进。
  桌面端没发现是因为验证流程一直是 `input keyevent 3`＋`aa start` 重拉起 App（重进后 `dossierOpen` 归 false，
  自然回到主屏），绕过了这条路。
- 根因一半在设计稿：§5.1 只写了“顶部左‘卷宗’标题，右‘新建卷宗’按钮”，没写返回；其余 5 页（内页／文档视图／收藏／换装／详情）
  都有返回箭头，唯独卷宗页漏了。
- 修法：卷宗页顶栏加返回箭头（44×44，与其他页一致），点后调 `onBack`；设计稿 §5.1 补一句返回入口。
  验收：进卷宗页 → 点返回 → 回主屏，纸面与键盘状态不变；再进一次仍能回。

### P0-2 卷宗里第 5 张及以后的纸永久不可见

- 位置：`components/DossierDetailPage.ets`（`initFly`／`launch`／`build` 的 `.opacity`）
- 事实：`initFly()` 把全部纸的 `flyOp` 置 0，`launch` 只对前 4 张执行
  （`const anim = n > 4 ? 4 : n`）；渲染用 `.opacity(idx < flyOp.length ? flyOp[idx] : 1)`，
  `flyOp.length = n`，所以第 5 张起 `flyOp` 永远是 0 → 透明度永远 0。
  全仓没有第二处写 `flyOp`。
- 后果：卷宗里纸超过 4 张，第 5 张起“丢了”——格子占位还在、标题／字数都看不见，
  点也点不到（透明但还在布局里）；页眉“N 张纸”却照常计数，对不上。
- 为什么测试没发现：飞出动画取证一直用的 4 张纸（`flyStart 2×2`），正好卡在阈值内。
- 修法：首屏纸做飞出动画，屏外纸初始 `flyOp = 1`（不参与动画、直接可见）；
  “首屏”按实测首屏格数算，不许写死 4。
  验收：卷宗里放 8 张纸，进内页后 8 张全可见，前 4 张飞入、后 4 张直接在位；滚动后屏外纸正常出现。

### P0-3 打开卷宗里的纸编辑，打一个字、800ms 后自动保存就把纸移出卷宗

- 位置：`model/DocModelCore.ets`（`toDocData`）、`pages/Index.ets`（`flushSave`／`loadDocument`）
- 事实：`DocModelCore` 全文件没有 `dossierId` 字段；构造函数只抄 `lines`／`cursor`／`meta`，
  `toDocData()` 返回 `{ lines, cursor, meta }`，没有 `dossierId`。
  `loadDocument` 用 `new DocModel(data)` 接住含 `dossierId` 的 `DocData`，当场就丢了；
  用户打字后 `flushSave`（800ms 防抖）调 `docStore.save(id, toDocData())`，
  `save` 里 `data.dossierId === undefined ? null : …` → 索引里 `dossierId` 被写回 null。
- 后果：卷宗里的纸一点开编辑、打一个字，800ms 后它就悄悄变“未归档”；
  卷宗页计数掉一张，用户以为纸丢了。`restoreLastDocument` 同样中招（启动恢复的文档同理丢归属）。
- 修法：`DocModelCore` 加 `dossierId` 字段，构造函数接住、`toDocData()` 带上；
  `loadDocument` 与 `restoreLastDocument` 之后各补一次断言（保存后索引里 `dossierId` 还在）。
  验收：卷宗里建纸 → 打开 → 打字 → 等 2 秒 → 回卷宗页，纸还在原卷宗里，计数不变；
  再杀 App 重进，归属仍在。

### P0-4 换机器后键盘键位表不重载，键盘仍是旧机器的

- 位置：`pages/Index.ets`（`applyMachine`／`loadDocument`）、`model/KeymapModel` 调用链
- 事实：`keymapLayout` 只在两处被赋值——`aboutToAppear` 与 `measureStage`（且 `measureStage` 里
  只有舞台／键区尺寸变 ≥1vp 才调 `reloadKeymap()`）。
  `applyMachine` 只做 `machineKind`＋`docModel.setMachine`＋`fadeSwitch`，不调 `reloadKeymap`；
  `loadDocument` 改了 `machineKind` 同样不调。切机器不改窗口尺寸，`measureStage` 不会因此重算。
- 后果：换装页切到 1930s（5 排键）／1950s／1960s 后，`PhotoKeybed` 的 `displayLayout()` 仍用 1920s 的键位表解析——
  键帽位置与标签全按旧表走；从卷宗打开一张 1950s 的纸同理，键盘与机器对不上。
  （机器舞台图会换，因为它读 `@State machineKind`；只有键盘键位表是 stale 的。）
- 修法：`applyMachine` 与 `loadDocument` 末尾调 `reloadKeymap()`（机器变了就重解析，不管尺寸变没变）。
  验收：切 1930s 后键盘变 5 排、键帽与照片对齐；切回 1920s 恢复 4 排；从卷宗打开一张 1950s 的纸，键盘是 1950s 的表。

---

## P1：核心功能缺失／错误

### P1-1 删纸无确认，点一下直接删

- 位置：`components/DossierDetailPage.ets`（“删除”文字链）、`components/DocumentViewPage.ets`（底栏“删除”）
- 事实：§5.2 明文“点‘删除’先弹确认再删”；代码里 `onDeletePaper` 直接 `docStore.remove(id)`，
  文档视图的删除同样直删。删卷宗有确认框（`confirmDel`），删纸没有。
- 修法：删纸先弹确认（与删卷宗同款式样），确认后才删；文档视图的删除同理。
  验收：点删除 → 弹确认 → 点取消，纸还在；点确认，纸没了。

### P1-2 卷宗改名未实现

- 位置：`components/DossierDetailPage.ets`（页眉）、`services/DossierStore.ets`（`rename`）
- 事实：§5.1“卷宗名可随时在卷宗内页页眉点名字改名”；页眉的卷宗名是纯 `Text`，无 `onClick`；
  `DossierStore.rename()` 存在，但全仓没有调用方。
- 修法：点页眉卷宗名 → 弹出改名框（复用新建卷宗的输入框式样）→ 保存后页眉与卷宗页列表同步更新。
  验收：内页点名改名 → 回卷宗页，新名字已更新；杀 App 重进仍是新名字。

### P1-3 删卷宗后回卷宗页，列表不刷新，已删卷宗仍显示

- 位置：`components/DossierPage.ets`（`dossiers` 的刷新时机）、`pages/Index.ets`（`deleteDossier`）
- 事实：`DossierPage.dossiers` 只在 `aboutToAppear` 与新建后 `reload()`；`docs` prop 上没有 `@Watch`。
  删卷宗时 `detailOpen=false` 回到卷宗页，但卷宗页组件一直挂在树上（`if (dossierOpen)` 未变），
  `aboutToAppear` 不重跑，`docsRev+1` 只刷新了 `docs` prop，不刷新 `dossiers`。
- 后果：已删卷宗继续显示（纸数按新 `docs` 算成 0 张），点进去是空的“未归档”内页。
- 修法：`DossierPage` 给 `docs` 加 `@Watch`，或删卷宗后显式调一次 `reload()`；两种都行，取其一。
  验收：删卷宗 → 回卷宗页，已删的格子当场消失；再进一次仍不在。

### P1-4 17 款字体只有 Courier Prime 注册了，其余 16 款选了也看不出区别

- 位置：`entryability/EntryAbility.ets`（第 57–62 行）、`pages/Index.ets`（第 236 行）、`components/CustomizePage.ets`（字体行）
- 事实：全仓 `registerFont` 只有两处，都只注册 `CourierPrime`。其余 16 款（SpecialElite／IMFellEnglish／
  AnonymousPro／SpaceMono／XanhMono／NotoSerifSC／LXGWWenKai／朱雀仿宋／马善政／致芒星／LongCang／
  Caveat／Kalam／PatrickHand／ShadowsIntoLight／HomemadeApple）都没注册；
  字体行 `fontFamily(f.familyName)` 全部回落系统字体。
- 证据：`imm-customize-phone.jpeg` 里 5 款英文试写“Ag”长得一模一样（都是系统回落字体）；
  选 SpecialElite 后 `fontFamily` 字符串改了，纸面渲染仍回落，等于没换。
- 修法：启动（或 `Index.aboutToAppear`）时把 17 款按 `FONTS` 表逐一 `registerFont`（`familySrc` 用各款 `rawfile` 字段）；
  注册失败要记 hilog 并在字体行上标“未加载”，不许静默回落。
  验收：换装页 17 行试写肉眼可区分；选一款后主屏纸面字体真变；杀 App 重进仍是所选字体。

### P1-5 文档视图“加页”“分享”两个按钮是死的

- 位置：`components/DocumentViewPage.ets`（底栏 Row）
- 事实：底栏三钮只有“删除”有 `onClick`；“加页”“分享”是纯 `Text`，组件连 `onAddPage`／`onShare` 回调 prop 都没定义。
- 修法：补两个回调——加页（文档末尾加一页／加一行，落盘）、分享（走系统分享面板，复用导出页的分享路径）；
  分享未实现前，按钮先置灰＋标注“待实现”，不许留可点但无反应的按钮。
  验收：点加页，文档多一页且落盘；点分享，拉起系统分享面板。

### P1-6 设置页、导出页根本不存在（§6.1／§6.2）

- 事实：§2.10 列了 7 页，只建了 5 页；`SettingsPage`／`ExportPage` 无文件，`Index.ets` 无引用，
  全仓无入口（顶栏只有“库”与“收藏”两个按钮）。`9653db3` 自述“两台五页”就是实锤——本批只做了五页。
- 修法：按 §6.1／§6.2＋§2.10 新建两页并接入口（顶栏菜单或主屏设置入口，用户定位置）；
  导出页的分享走系统分享面板，图片／PDF／纯文本三格式按 §6.2 钉死的路径做。
  验收：两页都能进，沉浸式按 §2.10（设置页底部声明、导出页分享按钮底距＝bottomInset），两台截图。

### P1-7 飞出动画起点是写死常量 (150,96)，与真实开口不符；“起点＝开口”的取证是循环论证

- 位置：`components/DossierDetailPage.ets`（`openingX()`／`openingY()`／`launch` 的 `flyStart` 日志）
- 事实：开口的真实位置可由页眉布局算出来——返回箭头 44vp＋左 20vp 边距，小封面 110×74，封面顶在
  `topInset + 11` 处，中心 x≈119；开口应在封面顶部中央，约 `(119, topInset+11)`（平板 topInset≈28 时约 `(119, 39)`）。
  代码写死 `(150, 96)`：x 偏右约 31vp，y 偏下约 57vp（96 是页眉行的底边，不是封面顶），且不随 `topInset` 变。
  `flyStart` 日志打印的正是这个常量——`a4286c1`“flyStart 三行证明起点＝开口”证明的只是“我打印了我写死的值”，
  AGENTS.md 还把它当作“用 hilog 打点证明参数”的范例。
- 修法：开口点从页眉小封面的实测矩形取（`getRectangleById`，与卡片中心同一套方法），
  或按布局公式现算（封面左缘＋55，封面顶）；`flyStart` 日志改打实测开口坐标。
  验收：录屏逐帧核起点落在小封面顶部中央（误差 ≤10vp，两台）；hilog 里 `from` 不再是常量。

### P1-8 字数显示 0 字的根因没修；`list()` 每次调用全量重读所有 txt

- 位置：`services/DocStore.ets`（`list`／`countChars`）、`pages/Index.ets`（`docs: docStore.list()`）
- 事实：桌面三笔提交（`ddfd652`／`770b42f`／`1a39d5a`）只把字数计算从渲染期挪到 `list()`，
  没修根因。`1a39d5a` 已证实：库里所有 txt 的 `rawLen` 都是 1（只有一个换行），有字的卡片也显示 0 字。
  字数以 txt 快照为准，但 txt 只在 `flushSave`（打字后 800ms）时写盘；标题来自索引／JSON——两者可能来自不同时间点的快照，
  于是出现“标题有字、字数 0”的自相矛盾显示。`'fff'` 那张卡的脱节机制仍未定位（哪次 save 没写 txt／txt 被谁覆盖），
  本清单不臆测，桌面端须沿 save 调用链定位。
- 另一半：`list()` 每调一次就对每个文档读一次 txt＋打一行 hilog；`Index` 在 build 里写 `docs: docStore.list()`，
  卷宗页打开期间每次重渲染都全量重读——渲染期读文件的问题换了个地方，没消除。
- 修法：① 字数改从 JSON 的 `lines` 现算（`DocSummary.charCount` 在 `list()` 里用已读的索引＋JSON 行算，不读 txt；
  或 `countChars` 读 JSON 不读 txt）；② `list()` 的结果在 `Index` 侧缓存，只在 `docsRev` 变时重算，不许放 build 里每次调；
  ③ 定位 `'fff'` 脱节：从 hilog 里找那次 save 的 txt 写入记录。
  验收：卷宗里建纸 → 打开 → 打字 → 不用等保存，卡片字数当场是对的；连续打字不卡；hilog 里不再每文档一行。

### P1-9 锁定卡片／锁定机器胶囊点按无任何提示

- 位置：`components/CollectionPage.ets`（`card` 的 `onClick`）、`components/CustomizePage.ets`（机器胶囊 `onClick`）
- 事实：§3“点卡片不进详情，只提示解锁条件”、§4“未解锁机器的胶囊置灰、点后提示解锁条件，不许直接切”；
  两处代码在锁定态都是 `onClick` 里空转——点下去什么都不发生，用户分不清“坏了”还是“没解锁”。
- 修法：锁定态点按弹提示（条件文案就用卡片上那行字，如“连续 7 天 + 分享 3 次”），样式与解锁提示条一致。
  验收：点未解锁卡片／胶囊，出现条件提示；点已解锁的照常进详情／切换。

### P1-10 换装切换不立即落盘，不打字就杀 App，切换丢失

- 位置：`pages/Index.ets`（`applyMachine`／`applyPaper`／`applyRibbon`／`onPickFont`、`aboutToDisappear`）
- 事实：切机器／纸／色带／字体只改内存状态；落盘只靠打字触发的 `scheduleSave`（800ms 防抖）；
  `aboutToDisappear` 只 `release()` 音频，不保存。切完不打字就杀 App，下次启动 `restoreLastDocument`
  读到的是旧 meta，切换全丢。
- 修法：四处切换回调末尾各调一次 `flushSave()`（有内容才存，空纸不存的既有规则不动）。
  验收：切 1950s → 不打字 → 杀 App 重进，主屏仍是 1950s；换字体／纸／色带同理。

### P1-11 飞出动画在每次 docs 变化时重播

- 位置：`components/DossierDetailPage.ets`（`@Watch('onDocsChanged')` → `reload()` → `initFly()`）
- 事实：`reload()` 里调 `initFly()`，而 `reload()` 在 `aboutToAppear` 与每次 `docs` 变化时都跑。
  删一张纸／新建一张纸 → `docsRev+1` → 全部卡片重新飞一遍（还顺带把第 5 张起再次藏起来，见 P0-2）。
  规格只要求“进内页时”飞一次。
- 修法：`initFly` 只在 `aboutToAppear` 跑一次；`onDocsChanged` 只重算列表不重播动画（新纸直接在位）。
  验收：内页删一张纸，余下卡片原地不动、不重飞；新建一张纸，新纸直接出现在首位。

---

## P2：偏差／体验／隐患

### P2-1 `Index` 里一段 `if (false && …)` 的死代码

- 位置：`pages/Index.ets`（文档视图“占位块”）
- 事实：一个 `DocumentViewPage` 包在 `if (false && …)` 里，注释说“真正的渲染已移到卷宗内页之后”。
  死代码留仓，下次有人改文档视图极易改错地方。
- 修法：删掉这段（真正的渲染在后面那段）。

### P2-2 收藏页解锁条件文案 1930s／1960s 互换，1950s 缺一半

- 位置：`components/CollectionPage.ets`（`M_COND`）
- 事实：按成就体系（定义稿 §8 已定顺序：1950s 累计 5000 字＋用过 2 种纸 → 1960s 连续 7 天＋导出分享 3 次 →
  1930s 换过字体与色带＋半开折叠打字 1 次），代码写的是 1930s＝“连续 7 天 + 分享 3 次”（那是 1960s 的）、
  1960s＝“换过字体与色带”（那是 1930s 的）、1950s＝“累计 5,000 字”（缺“＋用过 2 种纸”）。
  注：`docs/成就体系设计.md` 头上写着“全文为提案，待用户点头”——阈值数字本身待用户点头，
  但 1930s／1960s 的对应关系在定义稿 §8 的顺序里是定的，代码与它对不上。
- 修法：按定义稿 §8 的顺序改三行文案；若用户要改顺序，以用户新定的为准。

### P2-3 成就系统根本不存在，1930s／1950s／1960s 永远解不了锁

- 事实：全仓搜 `achievement`／`unlock`，只有 `CollectionPage` 与 `CustomizePage` 里写死的
  `unlocked() === '1920s-upright'`。没有成就计数、没有解锁判定、没有解锁提示条（§3 的解锁提示、§10 第 6 步“成就解锁提示”都没做）。
  用户打满 5000 字也不会解锁 1950s。
- 修法：这不是本批的修补范围，单独立项——按 `docs/成就体系设计.md`（待用户点头）做成就计数＋解锁判定＋提示条；
  在此之前，收藏页锁定态至少要把“条件”文案写对（见 P2-2），不许让用户对着永远解不了的锁打字。

### P2-4 收藏页剪影不用 `*-front.jpg` 裁切，拿纯色矩形画

- 位置：`components/CollectionPage.ets`（`card` 的剪影区）
- 事实：§3 明文“四台机器剪影用现有 `*-front.jpg` 的裁切版（只露纸＋底座轮廓，不露整机细节）”；
  代码用两个纯色矩形（96×70 纸片＋132×14 底座）画，四台长得一样，只是颜色不同。
  素材是现成的（`rawfile/machine/*-front.jpg` 四台齐全），没用上。
- 修法：剪影区改用 `*-front.jpg` 裁切（只露纸＋底座轮廓），未解锁态加深色罩＋线形锁。

### P2-5 文案硬编码在 .ets 里（AGENTS.md：文案走资源文件）

- 位置：`components/CollectionDetailPage.ets`（`M_INFO` 四段史实文字）、`components/CollectionPage.ets`（`M_NAME`／`M_COND`）、
  `components/CustomizePage.ets`（`GROUP_LABEL`）
- 修法：挪到 `resources/base/element/string.json`，代码只读资源。

### P2-6 文档视图手机上双栏过挤，无小屏适配

- 位置：`components/DocumentViewPage.ets`（两纸并排 `(widthVp-56)/2`）
- 事实：手机 362.7vp 宽时每张纸只有约 153vp，标题页里 120vp 照片占满纸宽，正文每行约 8 个字；
  代码无 `isTablet` 分支，手机与平板同一套并排。
- 修法：手机改上下排（标题页在上、正文页在下）或单页翻页；平板保持并排。规格待用户定一版，桌面端先按“手机上下排”做。

### P2-7 `DocumentViewPage.paperKey` 默认值 `'LETTER'` 大写，查表失败

- 位置：`components/DocumentViewPage.ets`（`@State paperKey: string = 'LETTER'`，`PAPER_RAW` 是小写键）
- 事实：`findSummary()` 返回 null 时 `paperKey` 保持 `'LETTER'`，`PAPER_RAW['LETTER']` 是 `undefined`，
  正文页背景图 `$rawfile(undefined)`。正常路径下 `load()` 会覆盖，但默认值本身是错的。
- 修法：默认值改 `'letter'`。

### P2-8 文档视图题注是写死占位“题注”，照片位点不了

- 位置：`components/DocumentViewPage.ets`（`titleSheet`）
- 事实：§5.3 要求题注在照片下方、照片“点后可从相册选一张贴上”；代码里题注就是写死的“题注”二字，
  照片位无 `onClick`。另：日期用绝对坐标 `y: 470`，矮窗口会被裁。
- 修法：题注先留空（无题注不显示“题注”二字）；照片位点后调系统相册选图（做不了先置灰标注，不许留假按钮）；
  日期改相对布局，不用绝对 y。

### P2-9 `previewText` 在渲染期读文件，飞行动画每步都重读；`charCount` 是死方法

- 位置：`components/DossierDetailPage.ets`（`previewText`／`charCount`）
- 事实：`770b42f` 的目标是“消除渲染期读文件”，但 `previewText` 仍在 `build` 里对每张卡调
  `docStore.readPlainText(id)`；飞行动画每 87ms 改一次 `@State` 触发重渲染，等于动画期间反复读全部 txt。
  `charCount(id)` 全仓无人调用（卡片用的是 `DocSummary.charCount`）。
- 修法：缩略图正文随 `DocSummary` 一起在 `list()` 里算好（或进内页时一次读好缓存）；删 `charCount` 死方法。

### P2-10 `DocStore.save` 新 id 无随机后缀，同毫秒建两纸会互相覆盖

- 位置：`services/DocStore.ets`（`'doc-' + Date.now()`）
- 事实：`DossierStore.create` 有 `+ random 0–999`，`DocStore.save` 没有；快速连点“新建纸张”可能同毫秒，
  后一张覆盖前一张的 JSON＋txt＋索引（前一张直接丢）。
- 修法：同 `DossierStore`，id 后缀加随机数。

### P2-11 `DossierStore` 索引损坏静默丢库

- 位置：`services/DossierStore.ets`（`readIndex` 的 `catch`）
- 事实：JSON 损坏 → `catch` 返回空表，卷宗页直接变空状态，全库“消失”，无任何恢复路径与提示。
  注释写“不抛、不带崩列表页”是对的，但静默丢数据不对。
- 修法：读失败时把损坏文件改名备份（如 `dossiers-index.json.corrupt-<时间>`），记 hilog，列表页空状态加一句“索引损坏，已备份”。

### P2-12 飞出动画细节与规格不符

- 位置：`components/DossierDetailPage.ets`
- 事实：① 飞行 5 步 ×87ms＝435ms，规格约 350ms；② 只飞前 4 张，规格是“首屏纸”（平板首屏不止 4 张）；
  ③ 旋转起步就是 −14°（规格是飞行中按切线微旋转、落地回正，起步应从 0° 起）；
  ④ 淡入第一步就到 0.48（`0.35 + 0.65t`），规格是 0→1 与缩放同帧。
  另：`FLY_DELAY_SCALE`／`FLY_DUR_SCALE` 两个取证旋钮留在了发货代码里，AGENTS.md 已写明 screenCap 取不到首帧、
  不要再试延迟倍率——旋钮可以留，但不许再为取证调它。
- 修法：飞行改 350ms（5 步 ×70ms 或 `animateTo` 350ms EaseOut 一次到位）；起步旋转 0°→ 飞行中按切线 → 落地 0°；
  淡入从 0 起。

### P2-13 三页重进时淡入闪烁（`revealN` 没重置）

- 位置：`components/CollectionPage.ets`、`components/CustomizePage.ets`（`aboutToAppear` 的 `setTimeout` 循环）
- 事实：`DossierPage.runReveal()` 先把 `revealN` 置 0 再排队，这两页没置 0；重进时 `revealN` 已是满值，
  第 0ms 的定时器把它改回 1 → 后几张卡片先消失再一张张重现，闪一下。
- 修法：与 `DossierPage` 一致，`aboutToAppear` 先 `revealN = 0`。

### P2-14 换装页／收藏页点选项无缩放反馈

- 事实：§4“点选项时该项缩放 0.95（100ms）再回弹；选中态切换时金色描边／底色 150ms 淡入”、
  §3“点卡片缩放 0.97（120ms）”——都没做。点按只有状态变，没有触感反馈。
- 修法：按规格补；做不了动画先保证状态切换本身正确，动画单列。

### P2-15 未归档 0 张时仍显示一格

- 位置：`components/DossierPage.ets`（未归档 GridItem 无条件渲染）
- 事实：有卷宗但 0 张未归档时，“未归档”格仍显示“0 张纸”，点进去是空内页。
- 修法：`unfiledCount() === 0` 且有卷宗时不渲染该格。

### P2-16 列数除数三页不一致，`DossierPage` 的 `winW`／`winH` 是死状态

- 事实：`DossierPage.colsTemplate` 用 236，`DossierDetailPage` 与 `CollectionPage` 用 260——同一套“列数随可用宽走”，
  三页三个数，宽窗口下分列结果会打架。`DossierPage` 的 `onAreaChange` 写了 `winW`／`winH`，但 `colsTemplate` 用的是
  `widthVp` prop，`winW`／`winH` 全仓无人读（注释还写着“供列数按可用宽算”）。
- 修法：三页统一一个除数（按卡片最小宽 236 还是 260，用户定一个数）；删 `winW`／`winH` 或真用它算列数。

---

## 核实后不是 bug 的 5 项（免得返工）

1. **删卷宗选“移出卷宗”不会改标题**：`Index.deleteDossier` 里 `docStore.save(id, data, '未命名')` 看着像会改名，
   但 `DocStore.titleOf` 优先取正文首行非空文本，只有全空才用 fallback——有标题的纸不受影响。
2. **收藏详情页三张图路径是对的**：`rawfile/machine/` 里 `*-side.jpg`／`*-keyboard.jpg`／`*-carriage.jpg` 四台齐全，
   `CollectionDetailPage` 的拼接路径能取到图。
3. **PaperKind 大小写已统一**：`1097b6d` 之后 `PaperKind` 值是小写（`'letter'`），三处映射表（换装页 `PAPER_LABEL`、
   内页／文档视图 `PAPER_RAW`）都是小写键，能对上；只有 `DocumentViewPage` 的 `paperKey` 默认值 `'LETTER'` 漏了（见 P2-7）。
4. **01:42 那张内页截图里没有“⋯”不是 bug**：截图时 HEAD 还在 `b7c2695` 一带，“⋯”删除入口是 `e78846b` 才加的，截图早于它。
5. **`winWidthVp` 虽是普通字段不是 `@State`，但窗口变化能传导**：根 `onAreaChange` 里改完它会调 `measureStage()`，
   `measureStage` 改 `@State stageWidth` 触发重渲染，各页拿到的 `widthVp` prop 会更新。真正的问题是 P2-16 的死状态与除数不统一。

---

## 建议修的顺序

1. P0-1（卷宗页返回）、P0-2（第 5 张纸不可见）、P0-3（dossierId 丢失）、P0-4（键位表不重载）——四件并行，各自独立。
2. P1-4（字体注册）与 P1-8（字数根因定位）——前者是换装页可用的前提，后者要桌面端沿 save 链定位 `'fff'` 脱节，别再挪计算点了。
3. P1-1／P1-2／P1-3／P1-5／P1-9／P1-10／P1-11——按页收：内页（删纸确认、改名、列表刷新、动画重播），
   文档视图（加页／分享），换装（落盘），收藏（锁定提示）。
4. P1-6（设置／导出两页新建）与 P1-7（飞出起点实测化）——前者是缺页，后者要录屏逐帧验。
5. P2 按页顺带清；P2-3 成就系统单独立项，不混进本批。

## 验收总则（沿用本仓铁律）

- 每项分开报，不许一句话带过；两台（MatePad Mini MLR-AL10、Nova 12 Ultra ADA-AL00U）各一套截图＋hilog，
  只看截图不看日志的不算数。
- 某项证据抓不到时用替代证据继续做，并在提交里写明不符点、原因、替代证据；不许以“未判读”“量测不可用”交差。
- 只有编译不过、设备离线、包装不上才可报阻塞，报时附试过的方法、每种方法的原文错误、还差什么。
- 本清单里的“根因”都是读码结论；桌面端落实后若实测推翻某条，以实测为准，回来改本清单，不要硬撑。

---

## 验证记录（2026-11-07，平板 MLR-AL10 + 手机 Nova ADA-AL00U）

| 项 | 实测证据 | 结论 |
|---|---|---|
| P0-1 卷宗页返回 | 点 ‹(99,180) → LIST→MAIN，Courier Prime 仍在 | 通过 |
| P0-2 第 5 张不可见 | 建 8 张纸 → CARDS=8（改前 4） | 通过 |
| P0-3 dossierId 丢失 | dossierAssert load id=doc-… dossierId=d1794…（改前必为 null） | 通过 |
| P0-4 键位表重载 | 切 1930s → reloadKeymap called: path=keymap/1930s-portable-keymap.json | 通过（临时解锁验证后已撤回） |
| P1-1 删纸确认 | paperDeleted id=… rev=4 + CARDS 3→2；取消后不变 | 通过 |
| P1-3 删卷宗刷新 | ⋯ → 移出卷宗 → 返回列表 tiles 1→0 | 通过 |
| P1-4 字体注册 | registerFont total=17 failed=0 | 通过 |
| P1-5 加页 | addPage enter → addPage ok lines=2 | 通过（根因：onAddPage 曾加在死代码块里） |
| P1-6 纯文本导出 | export txt ok path=…/export-<ts>.txt | 通过（图片/PDF 未实现） |
| P1-7 起点实测化 | flyStart from=(119,55)（改前恒为写死 150,96） | 通过 |
| P1-8 字数 | 卡片 METAS=['3 字 · 11 月 7 日']；DocStore list 日志 0 条 | 通过 |
| P1-9 锁定提示 | LOCK_HINT=(48,2314,634,2406) 且 STATE=COLLECTION | 通过 |
| P1-10 换装落盘 | 切色带 → saved doc id=… | 通过 |
| P2-15 未归档格 | UNFILED_RENDERED=False | 通过 |

未通过/未验：P1-2（改名输入注入失败，代码路径有日志）、P1-6 图片/PDF、手机端多数页。

## 手机回归与收尾（2026-11-07 15:2x）

| 页面 | 平板 insets | 手机 insets |
|---|---|---|
| 卷宗页 | 43.8 / 27.8 | 43.9 / 27.9 |
| 卷宗内页 | 43.8 / 27.8 | 43.9 / 27.9 |
| 文档视图 | 43.8 / 27.8 | 43.9 / 27.9 |
| 收藏页 | 43.8 / 27.8 | 未取到（设备中途离线） |
| 收藏详情 | 43.8 / 27.8 | 43.9 / 27.9 |
| 换装页 | 43.8 / 27.8 | 43.9 / 27.9 |
| 设置页 | 43.8 / 27.8 | 未取到（设备中途离线） |
| 导出页 | 43.8 / 27.8 | 未取到（设备中途离线） |

注：收藏页的日志 tag 是 `Collection`（不是 `CollectionPage`）。早前「收藏页无 insets 日志」是我的 grep 用错 tag，
平板上复核得到 `Collection: insets top=43.8 bottom=27.8`。

## 仍未达标的项

- P1-2 任意名字输入：`uitest uiInput inputText` 与 `hdc shell input text` 都无法写入 TextInput（两种都试过）；
  改名链路本身已用临时预填「名字+2」验通（页眉同步、持久化、列表刷新）；
- 手机端 收藏/设置/导出 三页：设备掉线，未取到 insets；
- 动画类（P2-12 350ms、P2-14 按压、§4 200ms 淡化）：只有确定性代码证据，无逐帧视觉；
- P2-11 索引损坏备份路径：未构造坏文件实测。
