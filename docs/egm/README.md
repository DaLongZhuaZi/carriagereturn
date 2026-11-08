# EGM 流程资产（本机等价件）

## 结论先行

本机（桌面会话 2026-11-09）**没有**官方 EGM 资产：

- `~/workspace/egm/elephant-goldfish-model/`（总纲引用的 e9e1f06／0.1.1 持久副本）不存在：`ls` 返回 `No such file or directory`。
- `~/workspace/egm-work/`（concepts_brief／consolidated_review_report／zoom_out_report／implementation_readiness_report）不存在。
- 全盘 `find /d /c/Users/13359 -maxdepth 4 -iname "*elephant-goldfish*" -o -iname "egm" -o -iname "egm-work"` 零结果。

命令原文与输出见 `docs/evidence/探针结论.md` 的"环境实测"节。

## 因此

1. 评审走**仓内等价 persona**：`docs/egm/reviewer-persona.md`（frontmatter `name: goldfish-reviewer`）。派 fresh 子 agent 做评审员，评审前先读该文件并在报告开头引用 name 字段。
2. 委托方仍按总纲：父 agent（Elephant）；评审结论由桌面端执行 resolve；委托关系写进批报告。
3. 这是**流程偏离**，不冒充"使用了官方 persona"。官方资产恢复后（用户补 `~/workspace/egm/` 与 `~/workspace/egm-work/`），按原文件对每批设计补一次复核，缺口记录在第 0 批批报告。

## 目录

| 文件 | 用途 |
|---|---|
| `reviewer-persona.md` | 本批评审员人设（只读、先核清单、带证据、编号发现） |
| `../designs/<批>-*评审报告.md` | 每批评审发现＋resolve 记录（随批提交） |