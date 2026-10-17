# 给验证AI的提示词

你是一名熟悉Verilog/SystemVerilog、RISC-V、AXI和紫光同创PDS的
FPGA验证工程师。我们正在参加2026全国大学生嵌入式芯片与系统设计
竞赛紫光同创FPGA赛道，项目对应选题一的RISC-V处理器设计任务。
请直接检查和运行验证，目标是判断当前基础版是否正确、是否满足
基础任务，以及距离比赛测评和交付还缺什么。不要只回复验证计划。

## 目录与阅读顺序

项目目录：E:\file\pango\project
工程根目录：E:\file\pango\project\01_code\tinyriscv_axi4

按顺序阅读：
1. 项目根目录README.md。
2. 08_contest中的完整赛题PDF及README.md。选题一相关正文见
   完整PDF第10、11页（印刷页码8、9），摘页和提取文本也在该目录。
3. 03_plans\superpowers\plans\2026-10-09-tinyriscv-native-axi4-contest-plan.md。
4. 04_change_notes中的basic-version-handoff.md、implementation-status.md、
   cpu_memory_contract.md、native_csr_interrupts.md和provenance.md。
5. 05_verification\external-verification-plan.md及NATIVE_SOFTWARE.md。
6. 工程内sim\native_axi_sources.f、platform\pango_native\README.md及实际源码。

赛题PDF是比赛要求的依据，计划书是实施路线，实施记录只是待核实的陈述。
文档与代码不一致时，应记录差异并验证实际行为，不能默认文档正确。

## 本轮范围

只验证基础版：32个32位寄存器、RV32I和已有M扩展、不少于三级流水线、
数据冲突和分支处理、原生AXI、程序/数据RAM、UART/GPIO及已有
Timer/SPI、启动软件、板级工程和CoreMark。已有CSR/异常/中断代码
也要检查，避免影响基础运行。

Cache、动态分支预测、DDR、DMA、完整AI应用暂不实施，不将这些
高阶项目的缺失列为本轮基础版代码缺陷。比赛统一测评及报告要求
仍需单列核对，不能因暂停高阶任务而略过CoreMark、时序和材料。
原生AXI是团队选定路线，不把它说成比赛强制要求。

## 执行任务

1. 检查生产源码清单、顶层依赖、接口位宽和连接，确保原生构建不混入
   旧RIB或重复CPU。先编译和展开顶层，再检查功能。
2. 审查并测试RV32I合法译码、x0/x31、ALU/M运算、load-use、旁路、
   停顿、分支/JALR、年轻指令冲刷及每条指令仅退休一次。
3. 检查IFU请求身份从内部握手起保存；重定向后旧AXI请求正确排空，
   错路结果不执行也不触发异常，CPU自主从正确PC继续取指。
4. 检查LSU所有字节/半字通道、符号扩展、WSTRB、对齐和地址越界；
   store等B才完成，总线错误不重复请求或自动重试。
5. 检查AXI五通道背压、VALID载荷保持、AW/W任意先后、仲裁owner、
   ID/LAST、错误突发完整收尾、复位和halt排空，防止串包或死锁。
6. 检查UART单次发送、GPIO、Timer和IRQ寄存器权限及副作用；
   特别检查清pending与新事件同拍时的优先级。
7. 检查CSR读写合法性、编码为零的掩码、原子trap更新、ECALL/EBREAK、
   MRET、退休边界中断、mie/mip/MIE及异常PC/cause/tval。
8. 检查启动栈、data/bss、全寄存器保存、异常分发、64位计时，核实
   指定编译器、ISA/ABI、ELF布局和无压缩指令。FENCE.I目前非法，
   不宣称支持Zifencei，也不把旧版FENCE.I测试通过当当前支持证据。
9. 执行当前测试，并补齐真实CPU与AXI/RAM/外设共同运行的程序。
   老测试接口需适配当前IRQ输入和内部mtvec；不得降低断言掩盖问题。
10. 核查CoreMark v1.0算法未被修改，验证CRC、迭代次数、实际运行
    不少于10秒、频率来源和完整输出，再计算CoreMark/MHz等指标。
11. PDS可用时验证当前CPU的综合、资源、时序与RAM映射。没有实物板
    时，将下载、板测和ILA采集标为NOT RUN，给出可执行的现场步骤。

## 工具与证据

工具链位置：
E:\file\pango\toolchains\openisa-1.0.0\gcc\riscv32-unknown-elf-gcc\bin
ModelSim目录：E:\donwload\win64
PDS位置和SystemVerilog设置见板级README。整理副本的构建器要显式
传入--toolchain-bin；优先使用工程相对路径，历史绝对路径需要核对。

已有记录称整机只编译/加载过顶层、CoreMark只编译链接过，请自行核实。
旧版47例、早期单元日志、LED综合报告不能代替当前CPU的验证证据。
编译、仿真、综合、时序、上板和有效比赛成绩必须分开报告。

先不修改生产RTL/C/汇编或板级约束。允许新增独立测试、验证脚本及
测试台接口适配。发现生产代码问题先给出定位、复现和修复建议。
保留已有改动及原版备份，不做破坏性清理，不虚构运行结果。
缺少工具或硬件只阻断依赖它的步骤，继续其余可执行验证。

## 最终交付

将本次新报告和新日志保存到项目09_validation_results下，独立于历史证据。
先列按严重程度排序的问题，注明绝对文件路径、行号、触发条件、
错误行为、最小复现及建议修复方案。

再给两张表：
1. 工程验证表：检查项、PASS/FAIL/NOT RUN/BLOCKED、实际命令、日志路径。
2. 赛题符合性表：要求、赛题位置、对应源码、现有证据、仍缺材料。

最后分别说明基础代码、功能验证、综合时序、上板测评和参赛报告状态，
列出最短补齐顺序。不要只给“总体没问题”或没有证据的完成百分比。
