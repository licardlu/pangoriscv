# 基础版交付入口

本次按用户最新要求只交付基础版代码。Cache、动态预测、DDR、
DMA、AI暂不做。原版及修改前备份保留在上级 `backups` 目录。

## 代码

- CPU：`rtl/core/tinyriscv.v`，三级流水线、32个32位寄存器、
  RV32IM译码/执行、单次退休、访存等待及分支重定向。
- 原生AXI封装：`rtl/core/tinyriscv_axi_top.v`。
- SoC：`rtl/soc/tinyriscv_axi_soc.v`，程序/数据RAM及
  UART、GPIO、Timer、SPI、IRQ控制器。
- CSR/异常：`rtl/core/csr_native.v`，同步异常与M模式中断，
  FENCE.I暂按非法指令处理。
- 板级顶层：`rtl/soc/pango_native_top.v`。
- 原生源码清单：`sim/native_axi_sources.f`；不要混编旧RIB顶层。
- 软件构建：`tools/build_native_software.py`。
- PDS工程脚本及引脚：`platform/pango_native/`。

## 当前证据

新增基础版源码做过语法编译和板级顶层加载，均0错误、0警告；
没有执行仿真run。日志为 `sim/native_release_compile.log`、
`sim/native_release_load.log`。CoreMark做过编译链接。
这些不代表完整CPU仿真、ISA符合性、CoreMark有效成绩、
PDS综合/时序合格或上板通过。早期单元测试结果只适用于
当时的代码，后续CSR和SoC改动需重新验证。

PDS运行前须按 `platform/pango_native/README.md`
启用SystemVerilog工程选项；尚未确认相应Tcl开关。

## 交给其他AI的验证任务

请在当前目录阅读 `docs/external-verification-plan.md`，
只执行基础版范围。先确认原生清单和顶层连接，再检查CPU退休、
AXI背压/错误、外设、CSR/异常、软件镜像，最后综合及上板。
遇到失败应报告最早错误位置和实际日志，不把编译成功当成功运行。
旧流水线测试需适配新增IRQ输入和内部mtvec，而不是继续依赖
已不控制异常入口的外部trap_vector。

完整验证由用户交给其他AI执行，本次没有启动完整回归。
