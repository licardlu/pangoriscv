# 已回退的方向表局部写试验

此目录的 `024_LsuL1Plugin.vh` 是试验源，不参加 `sources.f`、综合或当前交付。原试验脚本与测试台只作过程记录；其 ROOT 仍假定脚本位于工程 tests 目录，不应在此路径直接执行。

先写 bank0、再以旧全字 payload 写 bank1 的定向检查，在原写法失败（counter_write_red_001），局部写法通过 4096 次更新（counter_write_green_001）。这说明局部写语义改变有效，不表示 CoreMark 一定更快。

独立整核试验使用原 12-bit GShare hash，20 次 CoreMark 为 3,801,279 ticks，慢于同固件基线 3,799,461；分支 miss 从 61,776 增为 62,121。五 CRC 正确，退休 PC/UOP 摘要相同。故该写法已经回退，没有叠加到候选021。

复核提取写端的测试可在任意新的临时目录复制 `../counter_write_green_001/write_extracted.sv` 与 `../counter_write_green_001/tb.sv` 后，使用本机 ModelSim 的 vlib/vlog/vsim 编译运行。厂商仿真器不随包分发。原 RTL 冲突覆盖行为及其旁路是否值得整体重构，仍需另行研究。
