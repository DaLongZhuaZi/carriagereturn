# F2 修复批：纸纹渲染（A142、R15 纸纹部分）

- 日期：2026-11-26
- 分支：`fix/paper-texture`（base `main` @ `3d5340f`）
- 工作树：`D:\HarmonyAPP\carriagereturn\.worktrees\fix-paper-texture`
- 构建：DevEco 26 hvigorw `assembleHap`（debug，signed hap），产物 `entry/build/default/outputs/default/entry-default-signed.hap`

## 1. 改动（1 个文件，约 15 行）

`entry/src/main/ets/components/type26/Parts26.ets` 的 `texture()`：

- 原来：`Image($rawfile(customTextureRawfile || textureRawfile || 默认))`。导入纸纹存的是**沙箱绝对路径**（`FileHelper.copyToSandbox` → `ctx.filesDir/import/paper/…`），`$rawfile` 只接受 HAP 内资源名，必然报 `AceResource 9001005`，主屏不渲染。
- 现在：`customTextureRawfile` 非空时走 `Image('file://' + path)`（与 `PaperStage` 的预览、字体导入同一口径），为空时仍走 `$rawfile(...)`，内置四种纸纹路径与参数完全不变。加载失败会打 `Paper26 custom texture load failed`。

## 2. 手机验证（ADA-AL00U）

| 步骤 | 结果 | 证据 |
|---|---|---|
| 全新导入一张纸纹 | **通过** | 相册选「新手入门包」图 → 完成；纸纹行显示 `1795629520048-新手入门…`；hilog `texture imported name=…` |
| 应用后主屏纸面换成该纹理 | **通过** | 截图 3571：打字机纸面即为该图；此前同一 prefs 下纸面是内置纸纹 |
| 内置纸纹仍正常 | **通过** | 切到「稿纸」纸种（内置 manuscript），纸面为内置稿纸纹理（3572） |
| 切回「信纸」 | **通过** | 3575：回到信纸＋已导入纹理（该纸种的自定义纸纹） |
| 无 AceResource 报错 | **通过** | 进入打字页后 `hilog -x | grep AceResource` 无输出 |

## 3. 平板验证（MLR-AL10）

| 步骤 | 结果 | 证据 |
|---|---|---|
| 导入纸纹 | **通过** | 相册选「Skill 是什么」图；纸纹行 `1795630499266-IMG_20261116_141758_1.jpg`；hilog `texture imported name=IMG_20261116_141758_1.jpg` |
| 主屏渲染 | **通过** | 截图 3577：打字机纸面为该图（纸上已有 458 字 q） |

## 4. 1920s 门图：**未能按要求通过**，原因是基线本身不是 1920s

按仪式跑 `tools/gate-compare.py`：

| 对比 | 结果 |
|---|---|
| 平板当前 vs `2376_1920s_gate_tablet.png` | FAIL：keyboard 50.35%、frame 45.88–84.39% |
| 手机当前 vs `2377_1920s_gate_phone.png` | FAIL：keyboard 59.69%、frame 48.18–96.27% |
| 手机**切到 2020s** 后 vs `2377` | 0.03–0.10%（keyboard 1262 px、frame 68–121 px） |
| 平板当前 vs ①-10 的 1920s 实拍 `3535` | 0.10% / 0.00% / 0.10% / 0.01% |
| 手机当前 vs ①-10 的 1920s 实拍 `3497` | 0.13% / 0.03% / 0.12% / 0.08% |

像素证据（frame_left 区域均值）：

| 图 | 均值 RGB |
|---|---|
| `2376`（名 1920s） | (171,190,178) |
| `2377`（名 1920s） | (162,183,171) |
| 当前 1920s 实拍 | (31,29,27) |
| 当前 **2020s** 实拍 | (162,183,172) |

结论：**2376/2377 拍的是 2020s 现代机（车架底色 `#adc4b8` 的浅鼠尾草绿），不是 1920s 直立式（`#1e1c1a` 深棕黑）**。批 81 提交说明写「设置页回显 1920s 直立式」，与图像不符。因此：

- 真正的 1920s 设备跑这两张基线必然 FAIL，这不是 F2 引入的回归；
- 门图自批 81 起很可能一直在拿 2020s 渲染与 2020s 基线比，1920s 实际没有被覆盖；
- 上表后两行说明 F2 改动前后 1920s 画面只有 0.00–0.13% 差异（来自纸种/纸面内容与状态栏等状态差），键盘与车架区没有可归因于本批的变化。

**需要裁决**：是否按 §5 仪式重拍 1920s 基线（平板 2376 位、手机 2377 位），或确认基线命名本意就是 2020s、另立 1920s 基线。未获批准前本批不重拍、不改基线。

## 5. 设备状态副作用（需知悉）

- 应用内没有「移除自定义纸纹」的入口（`CustomizeStore.setPaperTexture` 只有导入时会写），所以导入后的纸纹无法通过 UI 清除。
- 手机：原有自定义纸纹（`1795590756572-…`）被本次测试导入的「新手入门包」替换，旧文件仍在沙箱但已不被引用。
- 平板：原本无自定义纸纹，现为「Skill 是什么」图。
- 两台设备的纸种已分别恢复为「信纸」（手机）/「信纸」（平板默认），机器均为 1920s。
- 建议后续补一个「移除纸纹/恢复内置」入口（A142 同族，未在本批实现）。

## 6. 截图（`docs/shots/`，3570 起）

| 编号 | 文件 | 内容 |
|---|---|---|
| 3570 | `3570_f2_phone_before_fix_old_texture.png` | 手机：修复前已导入的旧纸纹在主屏渲染（旧构建） |
| 3571 | `3571_f2_phone_imported_texture_typing.png` | 手机：新导入纸纹在主屏渲染 |
| 3572 | `3572_f2_phone_builtin_manuscript.png` | 手机：切到内置「稿纸」纸纹正常 |
| 3575 | `3575_f2_phone_restored_letter.png` | 手机：切回信纸（自定义纸纹生效） |
| 3576 | `3576_f2_tablet_1920s_before_import.png` | 平板：导入前打字页（1920s，内置纸） |
| 3577 | `3577_f2_tablet_imported_texture_typing.png` | 平板：导入纸纹在主屏渲染 |

## 7. 提交

- 分支 `fix/paper-texture`：1 个源文件 + 本报告 + 6 张截图。不合 main、不推 main、不改清单。
