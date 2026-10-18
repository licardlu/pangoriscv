# 验证文档索引

> `docs/verification/` 是项目**验证状态、问题、交接**的唯一归档区。
> 证据（日志/报告/截图/位流）放 `evidence/`，结论和状态放这里；不要把结论散落在多个 README 里。

## 先看哪一篇

| 顺序 | 文档 | 内容 | 状态 |
|---|---|---|---|
| 1 | **[issue-register-2026-10-18.md](issue-register-2026-10-18.md)** | **问题总表**：P0 阻断、P1 成绩/证据、RTL 缺陷、文档错误、修复顺序 | **当前，唯一问题登记处** |
| 2 | [audit-2026-10-18.md](audit-2026-10-18.md) | 独立复核详细报告：复现命令、768 迭代结果、三项评分核对、逐条证据 | **当前** |
| 3 | [external-verification-plan.md](external-verification-plan.md) | 外部验证计划（历史） | 历史 |
| 4 | [native-basic-final-status.md](native-basic-final-status.md) | 基础版状态台账（2026-10-13），含板上/ILA `NOT RUN` | 历史，数值已过时 |
| 5 | [competition-verification-prompt.md](competition-verification-prompt.md) | 给验证 AI 的提示词 | 历史 |
| 6 | [handoff-2026-10-18-ifu-done.md](handoff-2026-10-18-ifu-done.md) | 2026-10-18 交接（P16 状态） | 历史，§3 仍有 512 残留 |
| 7 | [handoff-2026-10-17-optimization.md](handoff-2026-10-17-optimization.md) | 2026-10-17 交接 | 历史 |
| 8 | [NATIVE_SOFTWARE.md](NATIVE_SOFTWARE.md) | 原生固件构建说明 | 现行 |

## 当前一句话状态（2026-10-18）

- **跑分**：768 迭代、ticks 287,211,317、10.6375 s、**2.6740 CoreMark/MHz**、IPC 0.7688；已独立逐字段复现。
- **证据等级**：**RTL 周期精确仿真**；**未上板、无 ILA、无应用场景**。按赛题，① 还不能作为有效成绩。
- **时序/资源**：27 MHz 约束 `All Constraints Met`（PDS 摘要/独立重跑 +15.267/+0.030，0/54,345；文档另写 +15.404/+0.025）；后布线 LUT 13,389、FF 8,507。
- **工具链**：优化链是 xPack GCC 15.2.0；板上基线是 GCC 7.1.1，尚未统一。

## 写文档的约定

1. **新问题先写进 `issue-register`**，再改代码/文档；不要新建第二份问题清单。
2. 状态只用 `OPEN / FIXED / NEED-BOARD / NEED-TOOLCHAIN / WONTFIX`；`FIXED` 要附 commit 或证据路径。
3. 日期命名：`handoff-YYYY-MM-DD-*.md`、`audit-YYYY-MM-DD.md`；旧文档不要改历史结论，加“历史/已取代”标注。
4. 数字必须带口径：迭代数、ticks、秒、频率、LUT 阶段（synthesis/device_map/post-PnR）、是约束值还是实测值。
5. 板上证据必须同时记录：位流 SHA、板卡、串口参数、抓包时间、原始日志路径。

## 相关入口

- 赛题原文与要求：`docs/contest/`
- 计划书与优化路线：`docs/design/plans/`
- 实施记录：`docs/design/change-notes/`
- 证据：`evidence/logs/`、`evidence/records/`
- 位流：`bitstream/`
- 项目索引：`docs/repo/PROJECT_INDEX.md`
