# CPU RTL 模块合同与面积计划

## 执行规则

- 一次只改一个 RTL 模块；先差分验证，再综合和实现。
- 面积验收以同一 PDS 器件、约束、优化选项和冻结基线比较。`LUT + FF + LUTRAM` 不得高于基线；总 LUT 不得超过 8,875。目标优于原参考 8,841 LUT。
- 现有证据没有模块级资源分解，禁止推测各 shifter 的 LUT/FF 数。首轮候选需保留 PDS 层级资源报告；无法取得层级分解时只用整设计面积作 gate。
- 当前时序门槛是 Setup、Hold 均无失败端点，PLL 实测不得低于 120.461538 MHz。

## 模块合同：late1 shifter operand path

1. 名称：late1 shifter operand path。
2. 文件：`project/pds_native_120/rtl/core/sections/052_LsuL1Plugin.vh` 中 `u_late1_shifter` 例化；被调用的纯组合单元为 `rtl/core/execute/replica_late1_shifter.v`。
3. 流水级：execute control stage 4 / late1 lane。
4. 职责：给 late1 RV32I SLL、SRL、SRA 提供 SRC1 操作数并完成组合移位，送入整数写回通路。
5. 时钟与复位：shifter 本身无时钟/复位/状态；本次优化只改源操作数接线，不增加延迟或寄存器。
6. 接口：LEFT、SIGNED、SRC1、SRC2[4:0] 和 32 位结果端口均不变；移位的有效 SRC1 是 `execute_ctrl4_up_integer_RS1_lane1`。
7. 内部状态：无。改动将 late1 shifter 输入由通用 RS1/U-immediate 选择结果改接已选定的 RS1；ALU、分支和其他通用 SRC1 消费者维持原信号。
8. 存储资源：无 RAM/ROM；当前模块级 LUT/FF/LUTRAM 数无报告，待取得 PDS 层级资源证据。
9. 面积预算：整设计候选上限 8,875 LUT，且 `LUT+FF+LUTRAM` 不得超过冻结基线；目标至少回到 8,841 LUT。不得伪造单模块预算值。
10. 物理区域与关键路径：无独立区域约束。原慢角最差路径从 late1 SRC1 控制寄存器经过通用输入选择、shifter、写回选择和寄存器文件反馈；延迟 11.964 ns，其中逻辑 1.207 ns、布线 8.160 ns。此次假设是从 shifter 路径移除不必要的 U-immediate mux 与高扇出选择控制。
11. 测试与变更记录：必须证明每条有效 late1 shift 的 `SRC1_CTRL==0`，并以 reference/replica lockstep 跑完现有 1,000,000-cycle 测试；另跑 33,792 个 shifter 向量。候选 001 的功能测试已通过，但 STA 未闭合（WNS −1.313 ns），没有上板成绩；后续综合与 P&R 结果记在 `docs/original-performance-optimization-plan.md`。

## 模块合同：early1 shifter operand path

1. 名称：early1 shifter operand path。
2. 文件：`project/pds_native_120/rtl/core/sections/052_LsuL1Plugin.vh` 中 `u_early1_shifter` 例化；组合移位器为 `rtl/core/execute/replica_early1_shifter.v`。
3. 流水级：execute control stage 2 / early1 lane。
4. 职责：给 early1 RV32I SLL、SRL、SRA 提供 SRC1 并输出移位结果。
5. 时钟与复位：移位器无时钟、复位或内部状态；接线优化不增加周期或寄存器。
6. 接口：LEFT、SIGNED、SRC1、SRC2[4:0] 与 32 位移位结果端口不变；移位数据操作数为该级寄存的 `execute_ctrl2_up_integer_RS1_lane1`。
7. 内部状态：无。候选 002 仅把 early1 shifter SRC1 绕过通用 RS1/U-immediate mux 直连同级 RS1；ALU、分支和其他 SRC1 消费者仍使用原通用信号。
8. 存储资源：无 RAM/ROM；无可用的独立模块级 LUT/FF/LUTRAM 报告。
9. 面积预算：以整设计资源作唯一 gate；LUT 不高于 8,875，且 `LUT+FF+LUTRAM` 不高于冻结基线。候选 002 Device Map 为 8,871 LUT、6,658 FF、72 Distributed RAM，LUT 数满足门槛；完整面积比较及口径见优化计划。
10. 物理区域与关键路径：无独立区域约束。候选 001 后 early1 shifter 成为新瓶颈；候选 002 已消除该 shifter 在所报最差路径中的位置，但全局路径仍未闭合。候选 002 新最差路径是 LSU refill hazard 控制到寄存器文件写端，另一条接近路径为 early1 branch condition 到 PC state。
11. 测试与变更记录：候选 002 已通过 1,000,000-cycle reference/replica lockstep（断言覆盖 25,293 个有效 early1 移位周期）、33,792 项 shifter 定向向量及发布包 verify；最终慢角 Setup WNS −0.687 ns / 455 个失败端点，未上板、无新分数。详细记录见 `docs/original-performance-optimization-plan.md`。

## 模块合同：late0 shifter operand path

1. 名称：late0 shifter operand path。
2. 文件：`project/pds_native_120/rtl/core/sections/052_LsuL1Plugin.vh` 中 `u_late0_shifter` 例化；组合移位器为 `rtl/core/execute/replica_late0_shifter.v`。
3. 流水级：execute control stage 4 / late0 lane。
4. 职责：给 late0 RV32I SLL、SRL、SRA 提供 SRC1 并完成组合移位，结果送入整数写回通路。
5. 时钟与复位：shifter 本身无时钟/复位/状态；候选只改变数据操作数接线，不增加延迟或寄存器。
6. 接口：LEFT、SIGNED、SRC1、SRC2[4:0] 与 32 位移位结果端口均不变；late0 shifter 的同级寄存 RS1 为 `execute_ctrl4_up_integer_RS1_lane0`。
7. 内部状态：无。候选 004 仅将 late0 shifter 的 SRC1 从通用 RS1/U-immediate 选择改接到同级寄存 RS1；其他 SRC1 消费者维持原信号。
8. 存储资源：无 RAM/ROM；无可用的独立模块级 LUT/FF/LUTRAM 报告。
9. 面积预算：整设计 Device Map LUT 不高于 8,875，且 LUT+FF+LUTRAM 不高于冻结基线；目标不高于 8,841 LUT。不得推测单模块资源值。
10. 物理区域与关键路径：无独立区域约束。候选 003 新最差路径从 stage-3 late0 SRC1 控制寄存器，经通用 SRC1 选择、late0 shifter、格式化/写回逻辑到寄存器文件 RAM 写端；7 个逻辑级、逻辑 1.101 ns、布线 7.436 ns。候选 004 假设是移除该路径上不必要的通用 RS1/U-immediate 选择。
11. 测试与变更记录：候选 004 必须覆盖有效 late0 shift 时 SRC1 等于 stage-4 RS1，跑 1,000,000-cycle reference/replica lockstep、33,792 项 shifter 向量及 LSU/异常定向测试，再做独立 PDS 综合和慢角 setup/hold。功能差异、面积超限或 setup/hold 未通过即不下载；候选 003 的 PDS 数据见 `docs/original-performance-optimization-plan.md`。

## 模块合同：LSU refill slot address compare

1. 名称：LSU refill slot address compare tree。
2. 文件：`project/pds_native_120/rtl/core/sections/042_LsuL1Plugin.vh` 中 `LsuL1Plugin_logic_lsu_ctrl_refillHazards` 组合赋值；比较对象是 8 个 refill slot 与当前 LSU physical address。
3. 流水级：execute control stage 4 / lane0 LSU hazard check。
4. 职责：对每个 refill slot 输出 `slot_valid && (slot_address[11:6] == request_address[11:6])`，供 refill hazard、wait mask 和 LSU hazard 控制使用。
5. 时钟与复位：组合逻辑，无状态、无时钟/复位；候选只重排比较树，不增加流水级。
6. 接口：8 位 `refillHazards` 向量语义和既有信号名不变；地址窗口仍为 `[11:6]`。
7. 内部状态：无。候选将每个 6 位 equality 切成 `[11:9]`、`[8:6]` 两个并行 3 位 equality，最后与 slot valid 合并。
8. 存储资源：无 RAM/ROM/寄存器。
9. 面积预算：整体候选不得超过 8,875 LUT，`LUT+FF+LUTRAM` 不得超过冻结基线；比较树不得引入状态。暂不指定模块级资源数。
10. 物理区域与关键路径：无独立 region 约束。候选 002 慢角关键路径经过 slot7 的 6 位地址 equality 第三级 `GTP_LUT6CARRY`；PDS 原网表把该 equality 映射为 3 级 carry-chain LUT。目标是缩短比较深度且不扩大整设计面积。
11. 测试与变更记录：需穷举比较器输入真值、对照 1,000,000-cycle reference/replica lockstep、运行 LSU refill/load/store/fault 定向测试，再做独立完整 PDS 实现。任一功能差异、面积超限或 setup/hold 失败即回退；候选尚未实施。
