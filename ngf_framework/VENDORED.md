# ngf_framework vendored snapshot

本目录是 NGF (Neon Genesis Framework) 的完整 vendored 副本, 随样板应用一起分发,
保证 clone 即可构建, 不依赖外部模块仓库。

- 来源仓库: DaLongZhuaZi/airwavefootprints (框架长期维护仓)
- 来源提交: 456594996b65961196a763b6d0865d5a96d99821 (2026-10-11)
- 拷入日期: 2026-10-16
- 框架版本: ngf_framework oh-package.json5 version = 1.0.0, MIT
- 框架现状: 见来源仓 docs/NGF_FRAMEWORK_STATUS.md (2026-10-16 全量重扫版)

同步纪律: 框架的修改应在来源仓完成并验证后再同步进本目录, 不要只改本目录的副本;
确需在本仓先行试验的框架改动, 必须在本文件追记一行 (日期/改动/回同步状态)。

- 二级同步 (2026-11-03, 回车仓): 本目录由 ngf-toolbox 的 vendored 副本原样拷入 carriagereturn (entry 脚手架 + AppScope 一并适配, 框架代码本身未改)。框架改动仍回来源仓 (airwavefootprints) 修改验证后再同步, 不要只改本目录的副本。
