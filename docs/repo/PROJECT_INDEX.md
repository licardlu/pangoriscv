# 项目索引（历史归档）

> 这份文件是 2026-10-10 整理时的项目分类索引，**仓库已按规范重排版**，
> 下面的路径都已按新目录更新，内容保留作为当时的交付说明。
>
> **当前问题与验收状态以 [`docs/verification/issue-register-2026-10-18.md`](../verification/issue-register-2026-10-18.md) 为准**；
> 本索引不代表最新成绩或最新结论。

## 交付版本

2026-10-13 交付版本就位：工程含两级组相联 I/D Cache、动态分支预测，以及取指解耦、
I-Cache 命中路径流水化两项优化，并完成四版同条件对照、PDS 实现与上板验证。
全部证据与报告在本地验证归档中（不入库）。

- 交付工程根为 `firmware/code`（原 `01_code/pangoriscv_axi4`）。
- 「源码 ↔ 位流 ↔ 板上」链路复核多轮，板上 UART 抓包逐字节一致。
- 仓库默认配置为三个开关全部关闭；交付位流由显式开启 Cache / 性能计数 / 分支预测的配置构建。

## 目录

| 目录 | 内容 |
| --- | --- |
| `firmware/code` | 当前完整工程：RTL、软件、测试台、仿真脚本、板级工程、许可证及工程文档 |
| `docs/design/plans` | 唯一正式计划书，含赛题对应、任务卡和历史审查修改意见 |
| `docs/design/change-notes` | 实施记录、交付说明、接口合同、CSR 说明及来源记录 |
| `docs/verification` | 验证方案、状态台账、问题总表；**问题登记处**见 `docs/verification/issue-register-2026-10-18.md` |
| `docs/contest` | 赛题 PDF、选题摘页、文本和比赛要求核对表 |
| `evidence/logs` | 历史仿真文本日志（按用例归档） |
| `evidence/records` | 赛题摘页副本、ISA 合规日志、LED 平台证据及工程复制哈希清单 |
| `bitstream/` | 交付位流 |

## 使用入口

后续编辑和验证以 `firmware/code` 为工程根目录。工程内部结构没有拆散，避免破坏脚本的相对路径。

建议阅读顺序：

1. `docs/contest/README.md` 与赛题原文
2. `docs/design/change-notes/basic-version-handoff.md`
3. **`docs/verification/issue-register-2026-10-18.md`（问题总表：先看这个）**
4. `docs/verification/audit-2026-10-18.md`（独立复核详细报告）
5. `docs/verification/external-verification-plan.md`
6. 计划书 `docs/design/plans/2026-10-09-pangoriscv-native-axi4-contest-plan.md`

计划书中的审查修改意见保留在原文对应章节，未改写成另一套计划。

历史文档中的旧路径属于原运行位置，不是当前位置的运行记录。

软件构建器默认查找工程上级目录的工具链，请显式传入本机工具链目录：

```powershell
python tools/build_native_software.py coremark --toolchain-bin "<toolchain>\riscv32-unknown-elf-gcc\bin"
```

## 证据范围

历史单元通过记录不代表当前整机通过；CoreMark 编译不代表有效成绩；LED 证据不代表 CPU 综合/上板。
部分历史仿真目录无法读取，具体路径记录于 `evidence/records/unreadable-log-paths.txt`；
工程文件的逐文件 SHA256 核对见 `evidence/records/code-copy-sha256.csv`。
