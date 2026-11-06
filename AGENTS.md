# AGENTS.md

本仓库的工作约定（桌面端与 Muse 都须守）。

## 提交
- 只对 main 提交；新工作直接在 main 上做。
- 备份分支统一 `backup/*`，不合入、不作工作分支。
- 提交前清理 `.bak` 文件，不把备份文件带进仓库。

## 页面与沉浸式
- **所有新页面一律按 §2.10 沉浸式通则实现**（用户 2026-11-07 定，长期有效）：照 `Index.ets` 的现成实现抄，
  统一走 `services/Immersive.ets` 的 `applyImmersive()`；每页自取 `topInset/bottomInset`，
  根 Stack 加 `expandSafeArea([SYSTEM],[TOP,BOTTOM])`，顶栏/页眉顶距 = topInset、底部内容底距 = bottomInset。
  不许写死固定顶距，不许 `aboutToDisappear` 恢复非沉浸。

## 语言与编码
- 文档用中文，文件 UTF-8。
- ArkTS 代码：显式类型，禁 any/unknown；文案走资源文件，不硬编码在渲染逻辑里。

## 构建
- 默认不自动构建、打包、安装；用户明确要求时例外。
- 真机数值、截图、单测运行结果无法在沙箱独立验证的，汇报时明说。

## 隐私
- 全离线是产品特性：用户文档与按键数据只存本地，不收集、不上传、不做遥测。

## 工程结构
- entry/ 是应用（回车），ngf_framework/ 是 vendored 的 NGF 框架副本（见其 VENDORED.md）；框架改动回来源仓修改验证后再同步，不要只改本仓副本。
