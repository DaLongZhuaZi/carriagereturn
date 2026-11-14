# 后续项：Canvas OFFSET 输入避让模式

- 状态：**待立项 / open**
- 来源：第 16 批视频验证 V6 无法录制（用户 2026-11-15 决定单独新增）
- 现象：系统键盘弹起时只有 RESIZE 表现；`module.json5` 增加 `"windowSoftInputMode": "adjustPan"` 会触发 hvigor `Schema validate failed`；SDK 未找到可调用的 softInputMode/OFFSET API。
- 目标：为 Canvas/ArkUI 输入提供可切换的 OFFSET（不压缩纸面、整体上移）模式，并复用 V5 的判据：
  - 打击行可见；
  - 纸顶与预期值偏差 ≤2vp；
  - 键盘与纸面重叠 0vp；
  - 候选窗跟随光标；
  - 离页键盘不悬留。
- 建议工作项：
  1. 查清 HarmonyOS 6 窗口软键盘避让 API（window/WindowStage/IME Kit 三处）；
  2. 增加 `offset` 开关（设置项或调试入口），不改默认 RESIZE；
  3. 用 V6 同样的动作录制 `docs/videos/v_2b6_ime_offset.mp4`；
  4. 回归 V5，确保 RESIZE 不退化。
- 验收：V6 视频 + 截图 1322 起；ffprobe 与 V5 同口径。
