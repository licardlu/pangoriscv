# 用户上板步骤

本交付不操作JTAG，不下载SRAM，不烧写Flash，不自动打开串口。
最终上板验证由用户完成。以下均为待执行步骤，不是已经获得的板测证据。

1. 确认板卡/器件/输入时钟/引脚与 `docs/architecture.md` 一致。
2. 用PDS 2022.2-SP6.1或兼容版本打开 `project/VexiiRiscv_improved.pds`。
   本项目包含已生成的Verilog与8个RAM初始化文件，不依赖本机Scala环境即可综合。
3. 完成综合、映射、布局布线。检查120.461538 MHz核心时钟setup、hold与所有约束。
   只设置120 MHz约束不等于通过时序。未通过时序的位流不要作为达标版。
4. 逐一确认8个 `MicroSoc.v_*_symbol*.bin` 被编译器读入，不能出现
   `Cannot open specified data file`。检查固件为7000迭代正式镜像。
5. 按板卡电压设置SCBV/下载配置；使用PDS的SRAM下载功能装载本次生成的sbit。
   初次测试优先SRAM下载；本包不提供自动Flash烧写脚本。
6. UART接3.3V USB-TTL：板上C24 TX接接收端，GND共地，115200/8N1。
   先启动串口接收，再按KEY0复位。PLL方案的实际波特率约114944，误差约-0.22%。
7. 应依次看到 `VEXII_PANGO_BOOT`、`CPU_HZ=120461538`、`ITERATIONS=7000`、
   CoreMark原始结果、`TICKS_HI/LO`、`BENCH_DONE`，LED最终写入0xA5。
   如出现TRAP或LED为0xEE，保留完整串口日志并排查，不报告成绩。
8. 保存串口原始输出为 `uart.txt`，运行：

   ```powershell
   python scripts/assess_result.py uart.txt --source board
   ```

   `--source board`只标注输入来源，不独立证明板测。需由用户确认日志确由板卡产生。
   正式成绩要求官方 `Correct operation validated.`、无Error、运行至少10秒、
   同一实现最终STA通过，分数用 `7000 * 1e6 / ticks`。
9. 保存该次位流SHA256、资源、时序、固件清单及串口日志。
   赛题要求的ILA波形须由用户在真实板卡抓取，不包含在本交付的已测结果内。

若UART全无输出，先查RAM初始化、输入时钟和复位，再查管脚及串口接线。
`platform/tool-probe.tcl`是隔离PDS工具故障的最小模块，不参与CPU工程。
