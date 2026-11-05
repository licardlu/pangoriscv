# 完整参考逻辑仿照验证版（2026-10-30）

板卡：PG2L100H-6 / FBG676。位流：`pango_replica_core_120.sbit`。

已真实上板两次：PLL 120.461538 MHz；7000 迭代；两次均为 1309328358 ticks；5.346252494 CoreMark/MHz；10.869264827 s；五项 CRC 全对，与冻结参考相同。两次原始 UART 的 SHA256 也相同。

这是功能与性能对照验证版，**不是最终 STA 闭合交付版**。最终 setup WNS −1.426 ns（619 个失败端点），LUT 8875（参考 8841，增加 34）；完整模块化与 ILA 尚未完成。没有降频、修改约束或改动基准来掩盖这些事项。

## 源码在哪

本次实现的可构建版本已经独立成包，**不在 `rtl/core/replica_native/`**：

| 用途 | 路径（相对本包根） |
| --- | --- |
| 核心顶层 | `project/pds_native_120/rtl/core/pango_replica_core.v` |
| 显式源文件清单 | `project/pds_native_120/sources.f`（43 个文件，全部相对该目录） |
| 四个 early/late 移位器 | `project/pds_native_120/rtl/core/execute/replica_{early,late}{0,1}_shifter.v` |
| 约束 | `project/pds_native_120/constraints/{pango_vexii.fdc,pango_vexii.pcf}` |
| 八 lane 初值 + 冻结 ELF | `project/pds_native_120/firmware/image/` |

四个 early/late 移位器已真正独立成模块；其余参考逻辑保持原式 sections，仍待继续提取语义模块。保留上游来源，**不宣称这部分为独立原创架构**。

## 怎么复现

`build/` 目录不随包发布（构建数据库太大，也会让"位流 ↔ 时序报告"的对应关系失真）。要打开 PDS 工程，先按 `project/pds_native_120/README.md` 的说明重新构建一次，脚本会在 `build/<新名字>/` 下生成 `implementation.pds` 和全部源快照：

```powershell
cd project/pds_native_120
python tools/build.py build --name run-001 --pds <PDS>/bin/pds_shell.exe
```

同目录的 `tools/program.ps1` 负责下载 + 抓串口，`tools/check_board.py` 负责判读。原始证据：`evidence/records/replica/P14-native/native-pds-001/`。`SHA256SUMS` 核验本目录各文件；`measurement.json` 指向真正生成并上板的同一份位流。

> 本目录在 2026-10-30 之前引用过 `rtl/core/replica_native/`、`build/core_exact/native-pds-001/`、`tools/core_replica/program_exact.ps1` 和 `docs/verification/v8-exact-extraction.md`，这些路径在后续整理中已被 `project/pds_native_120/` 取代，上面已改为现存路径。
