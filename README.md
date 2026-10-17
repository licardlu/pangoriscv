# 项目分类索引

整理日期：2026-10-10。当前交付范围为基础版；Cache、动态预测、
DDR、DMA、AI暂不实施。本目录是整理后的副本，源工程和原始备份保留。

## 更新（2026-10-13）：交付版本就位

上面「当前交付范围为基础版」的说明已被后续工作取代：`01_code/pangoriscv_axi4` 现已包含
两级组相联 I/D Cache（N13）、动态分支预测（N14），以及 T1 取指解耦、T3 I-Cache 命中路径流水化
两项优化，并完成四版同条件对照、PDS 实现与上板验证。全部证据与报告在
`09_validation_results/advanced_cpu/`（`REPORT_stageE.md`、`LOGBOOK.md`、`OPTIMIZATION_SURVEY.md`）。

- 交付工程根为 `01_code/pangoriscv_axi4`；该目录于 2026-10-13 由 `01_code/tinyriscv_axi4` 改名而来
  （同日计划书文件也改名为 `2026-10-09-pangoriscv-native-axi4-contest-plan.md`）。源码内已无上游命名：
  上游自带的参考流程与第三方套件移入 `legacy/`，许可与来源声明见 `THIRD_PARTY_NOTICES.md`，
  交付清单为 `sim/native_axi_sources.f` 的 33 个文件。
- 「源码 ↔ 位流 ↔ 板上」链路在改名、风格标准化、include guard 改名与默认配置复位后共复验四轮
  （stageG / stageH / stageK / stageL），四轮板上 UART 抓包逐字节一致（sha256 `B9561D0C…`）；
  TB 统一文件头另以一轮回归（stageM）复核，工程目录改名后再复验一轮（stageN）。
- 目录改名前的历史日志与记录按原路径留档，文中出现的 `01_code/tinyriscv_axi4` 均为改名前的历史路径。
- 仓库默认配置为 **B0**（三个开关全部关闭）；交付位流始终由
  `adv_build_config.ps1 -Defines CACHE,PERF,PREDICT` 显式构建（C3）。

| 目录 | 内容 |
| --- | --- |
| `01_code/pangoriscv_axi4` | 当前完整工程：RTL、软件、测试台、仿真脚本、板级工程、构建产物、许可证及工程文档 |
| `02_original_backups` | 原版及各阶段修改前备份、已有哈希清单 |
| `03_plans/superpowers/plans` | 唯一正式计划书，含赛题对应、任务卡和历史审查修改意见 |
| `04_change_notes` | 实施记录、基础版交付说明、接口合同、CSR说明及来源记录 |
| `05_verification` | 交给其他AI的验证方案及软件构建说明 |
| `06_evidence` | 赛题摘页、历史验证日志、LED平台证据及本次工程复制哈希清单 |
| `07_board_references` | LED参考工程和官方引脚核对材料 |
| `08_contest` | 用户提供的完整赛题PDF、选题一摘页、文本和比赛要求核对表 |
| `10_codex_chats` | 紫光分组下三段Codex聊天的JSONL导入快照及会话名称对应表 |

## 使用入口

后续编辑和验证以 `01_code/pangoriscv_axi4` 为工程根目录。
工程内部结构没有拆散，避免破坏脚本的相对路径。

先读 `08_contest/README.md` 和赛题原文，再读 `04_change_notes/basic-version-handoff.md`，最后读
`05_verification/external-verification-plan.md`。计划书位于：
`03_plans/superpowers/plans/2026-10-09-pangoriscv-native-axi4-contest-plan.md`。
计划书中的审查修改意见保留在原文对应章节，未改写成另一套计划。

历史文档中的 `E:/file/pango/tinyriscv_axi4` 指原始工作目录；
在本整理副本中对应 `E:/file/pango/project/01_code/pangoriscv_axi4`。
历史证据文件路径属于原运行位置，不是新位置的运行记录。

软件构建器默认查找工程上级目录的工具链。整理后的副本请显式传入：

```powershell
python tools/build_native_software.py coremark --toolchain-bin "E:\file\pango\toolchains\openisa-1.0.0\gcc\riscv32-unknown-elf-gcc\bin"
```

ModelSim安装仍位于 `E:\donwload\win64`，PDS安装位置见板级README。
工具链安装包没有复制到代码目录。没有复制Git内部数据库、仿真编译缓存
`work`、`.sim_runs`中的二进制库和Python缓存；源码、脚本及已有构建镜像保留。
历史仿真的文本日志单独放在 `06_evidence/simulation_logs`。

## 证据范围

本次只整理、复制和核对文件，不进行功能验证。历史单元通过记录不代表
当前整机通过；CoreMark编译不代表有效成绩，LED证据不代表CPU综合/上板。
部分历史仿真目录无法读取，具体路径记录于
`06_evidence/unreadable-log-paths.txt`。当前工程文件的逐文件SHA256核对见
`06_evidence/code-copy-sha256.csv`。

`organize-project.ps1`记录本次复制分类规则，仅复制，不删除源文件。
