# 验证记录与交付边界

目标是 CoreMark/MHz ≥5.2、CPU ≥120 MHz。目标不等于已经达到的成绩。
交付为 VexiiRiscv 双发射移植工程，正式初始化镜像为7000次迭代。
用户自行完成最终板卡下载和验收；本次没有连接板卡。

## 已有证据

| 检查 | 结果与范围 | 原始证据 |
|---|---|---|
| Python回归 | 19项通过，涵盖周期换算、错误日志拒绝、计数范围、迭代一致性、镜像与指令字节一致性；不是ISA全覆盖 | evidence/unit-tests.log |
| 正式固件与初始化RAM | ELF的36444个已初始化装载字节逐字节匹配64KiB RAM的8条字节lane；project目录副本也必须匹配 | evidence/release-image.json |
| 固件布局一致性 | 100次与7000次的.text完全相同，仅迭代数据不同；短跑仍不等于7000次完整执行 | tb/test_firmware_text.py |
| 板级顶层编译 | 含生成CPU、封装与厂商PLL仿真模型；0编译错误 | evidence/board-rtl/compile.log |
| 复位仿真 | 异步置位、同步释放、PLL失锁重置，TEST_PASS reset | evidence/board-rtl/reset.log |
| PLL厂商模型 | 输出周期8.301621ns，TEST_PASS pll；15条未用PLL输出端口连接警告；不是器件STA或实测频率 | evidence/board-rtl/pll.log |
| PDS工程创建 | 相对路径工程，PG2L100H/-6/FBG676，已预设顶层及ADS综合器；创建不等于编译完成 | evidence/project-create.log |

正式ELF SHA256：
`5c4ecd094efd2fea33f08d9f5ac8e79118584e85588a7bf18189bf37da0c270b`。
重组64KiB RAM SHA256：
`c0166c5cf86143cacd3b50c46b1c7f9ba28796e5b8f4c9d5dcc5507d6a3ef31d`。

## RTL性能诊断

最终100次仿真已完成，0仿真错误、0仿真警告，完整UART输出与
`TEST_PASS soc_coremark`均已获得。总周期18,776,958，
`100 × 1,000,000 / 18,776,958 = 5.325676288992072 CoreMark/MHz`。
按设计频率换算的基准时间仅0.1558751309秒。

输出为 seedcrc=e9f5、crclist=e714、crcmatrix=1fd7、crcstate=8e3a，
四项与官方2K性能工作负载已知值相符；迭代相关的crcfinal原始输出为988c。
官方结果包含不足10秒的ERROR和`Errors detected`，所以解析器有意保留
`crc_valid=false`、`meets_target=false`、`board_verified=false`。
这里的`crc_valid`是完整官方结果是否有效的门禁，不应解读成这四项CRC不相符。
尚未对7000次的迭代相关最终CRC作独立验证。

最终100次运行的记录由 `evidence/final100-assessment.json` 与
`evidence/simulation-final100.log` 给出。仅当日志具有完整UART结果及
`TEST_PASS soc_coremark` 时才视为完成启动/主要CRC/串口完成检查。
短仿真运行不足10秒，CoreMark应打印官方时长错误；此错误不能过滤掉后报为正式成绩。
`coremark_per_mhz` 只作周期效率诊断，`meets_target` 必须为false。

## PDS阻塞

新配置的两次实现均在Compile入口报 `Flow-0189: Internal error occurred.`，
尚未进入可核查的RTL编译、综合、映射和布局布线阶段。
用 `assign y=a;` 的单线最小模块隔离后同样失败。
原始日志位于 `evidence/pds/`，探针源码为 `tb/tool_probe.v`，
复现入口为 `platform/tool-probe.tcl`。

这说明当前失败不以CPU规模为必要条件，但现有证据无法确定内部错误根因。
没有据此断言许可证、沙盒或代码一定是原因，也没有改用旧版位流。
可在正常PDS终端先运行最小模块，确认工具能够启动Compile后再运行完整工程。
若最小模块仍失败，应保留PDS日志并排查工具安装/运行环境。

## 尚未完成的验收

- 本次新配置的综合、资源报告、布局布线、setup/hold报告和位流。
- 正式7000次的完整RTL运行以及实际板卡运行≥10秒。
- ≥5.2 CoreMark/MHz与≥120MHz同时满足的同一份板载实现。
- 全指令集/异常/中断定向回归、ILA实板波形和AI应用。

PLL配置为27MHz×58/13=120.461538MHz，约束周期为8.301404853ns；
这只是时钟设计与约束，不能代替新配置的STA通过结果。
运行时间必须用实得64位ticks除以实际CPU频率核实。
7000次在目标效率附近预计约11秒，此估算仅用于选迭代次数，不用于报分。

解压后可先执行 `python -m unittest discover -s tb -p 'test_*.py' -v`，
再执行 `python scripts/verify_image.py build/firmware_7000/coremark.elf rtl/generated`。
所有交付文件（清单自身除外）的SHA256位于根目录 `SHA256SUMS.txt`。
