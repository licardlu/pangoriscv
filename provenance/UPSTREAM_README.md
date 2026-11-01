# 独立 PDS 源码版：完整参考逻辑仿照基线

**2026-10-30 已验收独立构建与两次新位流上板。** 可直接打开 `build/standalone-001/implementation.pds`；本次位流发布副本在 `bitstream/current/pango_replica_core_120.sbit`，SHA256 为 `2e38db1c26bd6a1bcb9a3fe1d09ca6d70bf430d5ac50001f450664a50c81f9cb`。两次均为 1309328358 ticks、五 CRC 全对，5.346252494 CoreMark/MHz @ PLL 120.461538 MHz。实测归档 `evidence/implementation-standalone-001/measurement.json`；源码隔离记录 `evidence/isolation/result.json`。最终 STA 仍未闭合，不宣称为 STA 合规终版。

本目录可以整目录复制到别处，独立综合、实现和生成位流。入口为 `tools/build.py`；硬件顶层 `rtl/board/pango_vexii_top.sv`，CPU 顶层 `rtl/core/pango_replica_core.v`。本目录之外的 `upstream/`、`rtl/generated/`、`reference_exact/`、旧 build、旧 Python 工具与 Java/Scala/SBT 均不是本版本构建输入。

**完成范围**：完整 CPU/SoC 逻辑已在本目录就地存放；原寄存器、流水级、双发射、前递、预测器、Cache、LSU、Store Buffer、RPT、CSR/trap 继续使用冻结参考原式。四个 early/late 移位器已经独立成模块；其余核心以 53 个源码段组织。因此“可脱离来源目录构建”与“所有功能块已经重新编写为独立语义模块”不同，后者尚未完成。不能把移植称为自主原创架构。

## 目录

- `rtl/core/`：核心顶层、53 个源码段、执行移位器与 RF/除法/FIFO/仲裁模块。
- `rtl/soc/`、`rtl/board/`：SoC、RAM、总线、UART/CLINT/PLIC、PLL、复位与板级顶层。
- `sources.f`：43 个设计输入文件；全部路径相对本目录。
- `constraints/`：冻结的 FDC/PCF；PG2L100H-6、FBG676，27 MHz 输入，PLL 120.461538 MHz。
- `firmware/image/`：冻结 7000 迭代 ELF 与八 lane 初值。构建先核对 ELF/RAM，再检查 PDS 恰好加载八 lane。
- `firmware/source/`：对应 CoreMark 与软件移植源码；默认直接用冻结镜像，避免重新编译改变性能对照条件。
- `flow/`、`tools/`：本地构建、校验、下载和板测检查；不读取外部仓库配置。
- `provenance/`：历史来源映射、原式提取清单和许可证，仅供审计，不是外部依赖。
- `evidence/baseline/`、`bitstream/baseline/`：先前实际两次板测的原始证据和原位流，明确属于历史基线。
- `build/<新名字>/`：本目录源码独立重建的 PDS 工程、源快照、报告和新位流。

## 如何独立构建

要求：Python 3.10 或更新版本（仅标准库）、已安装并授权的 PDS 2022.2-SP6.1。以下命令在本目录执行；`python` 替换为本机有效的 Python 路径。

```powershell
python tools/build.py verify
python tools/build.py build --name run-001 --pds 'D:/FPGA_Project/zi_guang_tong_chuang/pds/PDS_2022.2-SP6.1/bin/pds_shell.exe'
```

也可以将 PDS 可执行文件路径放入 `PDS_SHELL`，无需修改源码。每次换一个新 run 名，禁止覆盖既有实现。完成后打开 `build/run-001/implementation.pds`。移动本目录之后用新名字重新构建，以生成当前位置的 PDS 工程；不要仅拷贝单个 `.pds`。

源码有意修改后，核对变更，再显式执行 `python tools/build.py manifest` 更新本地哈希，随后 `verify` 和新 run 构建。正常构建不会自动刷新哈希或重新生成 RTL。

## 下载和成绩

使用 `tools/program.ps1`，明确指定 PDS shell、串口和 JTAG server 端口。下载为 SRAM 配置，不改板载 Flash。先打开串口，再下载，保留独立 evidence 目录。命令示例：

```powershell
powershell -ExecutionPolicy Bypass -File tools/program.ps1 -BuildName run-001 -EvidenceTag board-run-001 -PdsShell 'D:/FPGA_Project/zi_guang_tong_chuang/pds/PDS_2022.2-SP6.1/bin/pds_shell.exe' -SerialPort COM34 -JtagPort 65420
python tools/check_board.py evidence/board-run-001
```

第二次独立下载使用新 EvidenceTag。完成两次后执行 `python tools/collect.py --name run-001 --board board-run-001 --board board-run-002`，归档本次位流对应的最终 STA、资源、固件校验和两次板测。迁移隔离检查入口是 `python tools/test_isolation.py --forbid-root <旧仓库绝对路径>`，它在临时副本中禁止读取旧仓库；不会删除原目录。

需先按 PDS 原流程启动并连接 `cdt_js` JTAG server。脚本只关闭本次启动的交互下载客户端，不关闭其他软件。

冻结基线：7000 迭代，1309328358 ticks，五项 CRC 全通过，5.346252494 CoreMark/MHz，PLL 120.461538 MHz，真实耗时 10.869264827 s。以完整 ticks 计算，不使用 UART 的整数秒/整数 Iterations/Sec 反推。独立重建的新位流必须单独核对，不能将旧板测自动当作新位流实测。

**已知边界**：基线最终 setup WNS -1.426 ns，120 MHz 最终 STA 未闭合；LUT 8875，较参考 8841 增加 34，面积中性门禁未过；ILA 与其余语义模块提取未完成。这些事实不会因打包独立而消失。

## 删除来源的边界

仅就本独立版本构建而言，外部旧参考树可以不在场。旧工程中的提取审计、参考双 DUT 回归、Scala 重新生成仍会需要旧来源；删除会失去这些历史工作流，但不影响本目录的已冻结 PDS 构建。不要删除本目录 `rtl/core/support/`、`rtl/core/sections/`、`rtl/soc/` 或八 lane 镜像，它们都是实际实现。来源记录与许可证应继续保留。打包过程没有删除任何旧文件。

本目录当前位于 pangoriscv 仓库内部。若要删除整个旧仓库，必须先把本目录完整复制到仓库外；移动后用新的 run 名重新构建当前位置的 PDS 工程。删除外部 upstream / reference_exact / generated 时，不要误删本独立包。
