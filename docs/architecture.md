# VexiiRiscv改进版：板级参数与模块合同

目标板为 MES2L676-100HP V1.2，器件 PG2L100H-6IFBG676。
参数来自 `licardlu/pangoriscv` 固定提交
`77141338dc9e3f3a3391ae3d19e95d195e64b37b` 的本地快照。
2026-10-27 尝试核对远端 HEAD 时 Git HTTPS 凭据接口失败；不声称这是远端最新版本。

CPU采用 VexiiRiscv `ae9060aca523e406fc6f3ba2a502414956ac495b`，
SpinalHDL `de72faf6062206a89b445e5cc07e32ed982712c8`。
参考已有独立移植工程 `pango_vexii_20261026`，在单独目录修改，未改动其原件。
不使用 pangoriscv CPU RTL，也不把它的历史跑分或位流算作本工程结果。

| 信号 | 管脚 | 电气/意义 |
|---|---|---|
| clk | D18 | 27 MHz，LVCMOS33 |
| rst_n | C22 | KEY0，低有效 |
| key | C23 | KEY1，低有效 |
| uart_rx / uart_tx | B24 / C24 | 3.3 V，约115200 baud，8N1 |
| led[0..7] | A20,C18,C19,E18,A17,A18,C17,B17 | LVCMOS33 |

CPU 时钟为 27 MHz × 58 / 13 = 120.461538 MHz，PLL VCO为1566 MHz。
约束周期8.301404853 ns，固件计时频率使用取整后的120461538 Hz。
GPIO 按键由 MicroSoc 内的同步器处理；外部复位和PLL失锁异步置位、同步释放。

## 本版相对移植基线的改动

1. 保留顺序双发射、early/late ALU、完整旁路和动态预测框架。
2. 显式使用 `--stressed-branch --stressed-src`，缩短分支与操作数准备延迟。
   这是一项IPC/时序权衡，必须重新布局布线，不能沿用旧版时序结论。
3. 使用两路组相联16 KiB I-cache、8 KiB D-cache、64位存储总线与64 KiB片内RAM。
   保留store buffer和非阻塞refill配置。容量按64-byte line × sets × ways计算。
4. 保持RV32IMC + Zicsr/Zifencei；C/M可作为包含RV32I的扩展。
   不强制压缩成四/五级，不以更改CoreMark算法换取分数。
5. 固件启动设置gp/sp、mtvec、清零BSS，使用64位mcycle读数和完整UART结果。
6. 新增固件、生成、仿真、构建与打包清单，严格区分短仿真、时序证据和板测。

## 模块合同

| 字段 | VexiiRiscv / MicroSoc | Pango板级封装 | CoreMark移植与测评 |
|---|---|---|---|
| 名称/文件/流水级 | upstream/VexiiRiscv与rtl/generated/MicroSoc.v，可配置多级双发射 | rtl/pango_*.sv，时钟/复位层 | firmware/port与scripts/measurement.py |
| 职责 | RV32IMC、预测、缓存、总线、外设 | PLL、复位、引脚 | 启动、计时、串口、结果判定 |
| 时钟复位 | 120.461538 MHz，同步运行 | 27 MHz输入，异步置位同步释放 | mcycle与CPU同源 |
| 接口 | TileLink，UART，GPIO，CLINT/PLIC | clk/rst_n/key/uart/led | 原版CoreMark API |
| 内部状态 | RF、流水寄存器、预测表、缓存状态 | reset release_pipe[3:0] | begin/end_ticks，种子volatile |
| 存储资源 | RAM64KiB，I$16KiB，D$8KiB | 不新增程序存储 | 单上下文、2000 bytes工作数据，8KiB以上栈余量 |
| 面积预算 | 器件66,600 LUT/155 DRM内；本版实测待PDS完成 | 1 PPLL与少量FF | 固件text约36KiB；算法不改 |
| 物理区域 | 由PDS布局，不复用旧CPU区域约束 | 使用固定IO与PLL | 无独立物理区域 |
| 关键路径 | stressed branch/src须重新STA | PLL输出与复位释放 | cycle64跨低字进位读数需重读hi |
| 测试 | 实际RTL跑CoreMark，主要CRC和UART完成检查 | tb_reset/tb_pll厂商模型 | 19项日志/计算/固件镜像测试，短跑与正式跑区分 |
| 变更记录 | 2026-10-27基于上游参数生成 | 保留移植基线封装 | 新增错误/范围/迭代数一致性检查 |

高阶任务中的缓存、预测、异常/中断具有实现基础；AI应用与ILA实板波形未完成。
不能仅凭CoreMark通过宣称完整ISA回归、全部中断场景或赛题全部高阶任务通过。
