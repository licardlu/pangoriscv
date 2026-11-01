# CPU RTL 模块合同与面积计划

## 板卡资料续验候选021：GShare 历史长度筛选

1. 名称：GShare lookup/learn hash，现有逻辑的索引函数。
2. 文件与流水级：030_FetchL1Plugin.vh 的 fetch0 HASH 与 036_BtbPlugin.vh 的 learn HASH；同一预测器两个使用点，不能只改一侧。
3. 职责：相同 PC/history 在读取与学习时必须产生相同地址；候选仅使用历史低10位参与异或。
4. 时钟复位：无新增时钟、复位；初始化值仍0，4096行初始化周期不改。
5. 接口：PC[31:0]、history[11:0]，原12位地址；预测/学习/旁路接口和时延均不变。
6. 内部状态：2-bit饱和计数、4个半字bank、学习覆盖行为均不改；不以内部逐周期锁步判断有意变化的预测状态。
7. 存储：仍4096x8bit；没有增容、没有新增RAM/FF。
8. 面积预算：减少两位历史XOR输入，预期不增加；最终需独立PDS验证，旧总量15605仍为门槛，当前基线已超限不得隐瞒。
9. 物理区域：保持既有RAM/逻辑映射，由PDS新实现；板卡27MHz D18、120.461538MHz PPLL均不改变。
10. 关键路径：fetch0地址到方向表；新地址组合深度不应增加，仍须检查最终全部十项STA，不能沿用020报告给021。
11. 测试与变更：先用现有分支trace离线筛选（仅假设）；提取实际两侧RTL表达式跑地址一致/预期函数测试，旧RTL应失败；20次完整UART五CRC、相同固件退休PC/UOP摘要对照、异常程序、独立PDS。10位候选若不提速或失败就回退，不能称5.6已实现。

## 已回退独立候选022：方向计数器局部写使能

1. 名称：GShare counter-bank write mask；独立于021，不叠加索引变化。
2. 文件/流水：024_LsuL1Plugin.vh 的方向表同步写端，原learn时刻。
3. 职责：仅更新命中的2-bit计数器，避免整字写回把同地址其余三个计数器覆盖成旧快照。
4. 时钟复位：原时钟、原初始化轮数与原写使能不变；初始化仍写所有bank。
5. 接口：原12位地址、8位写数据、learn PC[2:1]与initializer_busy；读口与旁路不改。
6. 状态：4096个8-bit word，保留各bank之前最新状态；饱和算法本身不改。
7. 存储：总位数不变；分bank写使能可能改变DRM推断，必须报告资源映射；不预设面积中性。
8. 预算：旧15605总量约束仍有效，若超限仅列实验，不冒称完成面积目标。
9. 区域：不新增物理约束，由新PDS实现检查读写端位置。
10. 关键路径：同步写使能多一个低位译码；确认综合未变成组合RAM及最终十项STA。
11. 测试：从当前RTL提取写端跑先写bank0再用旧全字写bank1的回归（旧RTL应失败），初始化/四bank随机向量；原20次CoreMark CRC、退休指令摘要与异常测试；无收益回退。

## 执行规则

- 一次只改一个 RTL 模块；先差分验证，再综合和实现。
- 面积验收以同一 PDS 器件、约束、优化选项和冻结基线比较。`LUT + FF + LUTRAM` 不得高于基线；总 LUT 不得超过 8,875。目标优于原参考 8,841 LUT。
- 现有证据没有模块级资源分解，禁止推测各 shifter 的 LUT/FF 数。首轮候选需保留 PDS 层级资源报告；无法取得层级分解时只用整设计面积作 gate。
- 当前时序门槛是Slow/Fast十项检查全部严格正裕量、无失败端点；PLL配置120.461538 MHz，实际频率与稳定性待实板核实。

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

## 改进版1候选：early0 shifter 数据操作数旁路

1. 名称：early0 shifter SRC1 bypass。
2. 文件：`project/pds_native_120/rtl/core/sections/052_LsuL1Plugin.vh` 的 `u_early0_shifter`。
3. 流水级：execute control 2，lane0 early ALU。
4. 职责：有效 RV32I SLL/SRL/SRA 数据操作数直接使用该级 rs1，去掉无关 U-immediate 选择。
5. 时钟/复位：组合接线；不改原时钟、复位、使能或流水延迟。
6. 接口：控制、SRC2、结果端口不变；仅改 SRC1 实参。
7. 状态：无新增状态；通用 SRC1 继续供 ALU 等消费者使用。
8. 存储：无新增 RAM/ROM。
9. 面积：仅用同轮完整 PDS 总量验收，不臆测模块面积；候选总量不得超过冻结门槛。
10. 物理/关键路径：与其余三个已做旁路的 lane 对称；测试其能否消除最后一个通用选择器并降低扇出；未出 STA 前不宣称改善。
11. 测试/记录：冻结下载源码为 golden；先确认上游负 WNS，再做 1,000,000 周期 lockstep 与四移位器 33,792 向量。候选单独目录，结果见改进版1报告。

## 改进版1候选：四移位器 shift amount 选择

1. 名称：RV32 shift amount direct select。
2. 文件：`project/pds_native_120/rtl/core/sections/052_LsuL1Plugin.vh` 的四个 shifter SRC2 实参。
3. 流水级：early lane0/1 为 ctrl2，late lane0/1 为 ctrl4。
4. 职责：SLL/SRL/SRA 的有效移位量仅需低5位；RV32 OP 的 UOP bit5 为1，使用 rs2[4:0]；OP-IMM bit5为0，使用 UOP[24:20]。RVC 已由 aligner 解压。
5. 时钟复位：组合，无新流水级/寄存器。
6. 接口：四个 shifter 模块端口和输出均不变，SRC2 高27位归零，内部只消费[4:0]。
7. 状态：无；一般 SrcPlugin 的32位 SRC2 仍保留给其他消费者。
8. 存储：无新增 RAM。
9. 面积：同一 PDS 实现资源 gate；不得超过冻结总量。
10. 物理关键路径：候选002最差路径由 late1 SRC2 控制经过 shifter 和前递到操作数寄存器，fanout与布线占86.4%；用 opcode bit5 的小选择器移除此通用选择控制。
11. 测试：先穷举 OP/OP-IMM funct7/funct3/5位操作数，比较合法shift的低5位结果；四shifter向量和整核1,000,000周期lockstep；独立PDS。禁止将无效指令操作数变化当作程序性能提升。

## 改进版1架构复核：32x32 RF 的存储资源映射

前三组局部/工具候选均未达120MHz STA，停止继续调整同一组合逻辑。报告把新最差端点定位在32x32 RF 被映射的 DRM 地址端；这属于存储资源选择与物理布局问题，不能靠改时钟周期掩盖。按用户120MHz优先的目标单独评估局部存储映射；若面积不符合旧预算，仅列实验结果，不称已通过面积门禁。

1. 名称：register-file local LUT RAM mapping。
2. 文件：`project/pds_native_120/rtl/soc/RamSyncMwMux.v` 的 ram_0 与 ram_1。
3. 流水级：原单周期同步读取端口不变。
4. 职责：双写银行和四读端口的32x32整数寄存器文件。
5. 时钟复位：沿用原写/读使能、时钟、复位；不改读写碰撞定义。
6. 接口：所有端口逐字保留。
7. 状态：不新增架构状态，仅综合属性指定 LUT RAM；禁止 no_rw_check。
8. 存储：由全局 DRM 资源改为就近 distributed RAM；预期释放部分 DRM，但增加 LUTRAM/FF 的数量须综合实测，不能估值当结果。
9. 预算：旧面积门槛不自动取消，分别报告性能与旧预算是否通过；超限则实验版。
10. 物理/关键路径：减少调度指令地址到远端 DRM ADB 的布线，并给旁路/移位器寄存器选择更近位置。属性依据本机 ADS Synthesis User Guide §5.16：syn_ramstyle=lut_ram；不使用会改变仿真语义的no_rw_check。
11. 测试：现有100万周期90观察量+1795寄存器/32数组lockstep及独立移位程序，PDS最终多角STA和资源。该候选保留early0旁路，回退shift amount003。


## 正裕量候选007：晚级分支相等比较重定时

1. 名称：branch_eq_pipeline。
2. 文件：rtl/core/execute/branch_eq_pipeline.v；034_BranchPlugin.vh 内 late0/late1 例化。
3. 流水级：ctrl3 组合计算、ctrl3→ctrl4 原有边界寄存，ctrl4 使用；不新增架构级。
4. 职责：精确重现原 SRC1/SRC2 选择及相等比较，提前从 PC 重定向路径移除比较。
5. 时钟复位：socCtrl_systemClk；enable=execute_ctrl3_down_isReady，与对应操作数流水寄存器相同；无复位，同原数据寄存器。
6. 接口：rs1/rs2/uop/pc 各32位、src1_upper 1位、src2_ctrl 2位、enable、clk、eq。
7. 状态：每 lane 一位 eq，两 lane 共2 FF；停顿保持。
8. 存储：无 RAM，保持原 RF 实现。
9. 预算：先评估整设计 LUT+FF+LUTRAM <=15605；若额外2 FF不能被逻辑节省抵消，记实验超限，不冒称面积通过。
10. 物理关键路径：保留版 late1 SRC1 CTRL→SRC mux→EQ→COND→PC；计算前移只保留 eq FF→COND→PC。另须检查 ctrl3 forwarding→eq FF 新路径，防止仅转移瓶颈。
11. 测试：单模块12000随机/相等/立即数/PC/无效控制/停顿检查，完整原内部寄存器百万周期lockstep，不忽略 unused 观察量，完整PDS多角STA与资源门禁。


候选008只对候选007启用 ADS 官方 `synthesize -retiming`（手册 Retiming 节）：在保持输入输出周期关系的前提下让综合器移动既有寄存器。没有放宽约束或改变算法；需单独报告最终资源与多角STA。最终报告扩展40条以追踪新关键路径。007冻结输入不受后续编辑影响。


008最终结果：WNS -0.258 ns、11个setup失败端点，其他九项无失败。总量 LUT8907/FF7237/LUTRAM72，较旧预算增加611，面积门禁失败；按本轮120MHz优先目标仅作实验候选。009在008基础启用关键路径重布线5轮，010则回到008选项只改placement seed=3，避免把不同参数收益混算。RTL周期语义保持007不变。


候选011：与008同RTL/retiming/seed，仅对core_clk采用8.000ns(125MHz)实现过约束，PLL物理输出仍120.461538MHz。只接受该更严格约束下最终全部检查为正，不将约束频率冒充PLL实际频率，不以修改报告时钟掩盖负数。目的是促使综合和物理实现为真实120MHz留出额外余量。


候选011最终WNS -0.990ns（125MHz过约束），没有改善，约束已恢复120.46MHz。候选012只在008基础关闭综合Advanced LUT Combining（enable_prepacking FALSE），以免共享LUT/FF打包将前递选择与APM输入放远；按手册对比时序与资源，RTL不改。


候选013：008基础只开启全局路由Slack Prior（手册布线模块），针对剩余路径89%布线延迟；与早期002组合启用多项选项不同，此轮仅测试一个布线策略。必须看最终布线而非placement估计。


009完整最终报告选择最佳迭代：WNS -0.057ns，6个失败端点，仍严格判失败。014保留相同输入、相同关键路由策略，将最多迭代数从5增加到12，观察能否继续优化最后不足60ps的路径。每轮优劣以工具最终选中的位流/报告对应，不截取中间数替代最终验收。

## 正裕量候选015：late1移位方向控制的物理扇出

1. 名称：late1 LEFT fanout guidance。
2. 文件：rtl/core/sections/005_PerformanceCounterPlugin.vh 的 execute_ctrl3_up_BarrelShifterPlugin_LEFT_lane1 声明。
3. 流水级：原ctrl3/ctrl4控制寄存器边界，不新增架构周期。
4. 职责：向late1移位器提供左右移选择。
5. 时钟复位：保持原时钟、使能、复位语义；仅加官方综合属性。
6. 接口：原1-bit控制与全部消费者不变。
7. 状态：RTL无新增状态；syn_maxfan=16允许综合器复制等价驱动，最终FF数量由报告确认。
8. 存储：不改变RAM或固件。
9. 预算：继承008/009的面积门禁失败状态；120MHz优先实验，逐项公开资源代价，不宣称面积中性。
10. 物理关键路径：009最差路径由该寄存器发起，fanout=58，移位结果经写回、前递到early1输入；布线占75.2%。只测试限制此控制扇出的假设，不同时改其他旁路选择。
11. 测试记录：属性本身不改变仿真语义；沿用已通过007功能测试并检查源差异仅为属性。对新的综合网表单独跑数字门级对照，最终以完整多角STA判断属性是否有效。实现选项采用009的5轮关键路径布线。

012最终setup WNS=-0.618ns，关闭prepacking未改善；013=-0.258ns，slack-prior与008结果相同，均不采用。

候选016按PDS User Guide布线自动迭代模块建议，加载009最佳迭代保留的RCF，从已有有效优先布线结果开始下一次完整实现。015属性回退以保持与009完全相同RTL；仅增加用户RCF。所选RCF中有一个load实例名包含冒号，PDS把它误读为实例/引脚分隔符并报RouteConstraintEditor-2001，故仅注释该条无效物理提示，原始RCF和排除清单保留在build。没有删减时序检查、没有设置false path或multicycle path。去掉日期/路径注释后的网表逻辑文本与009相同，原始哈希因生成日期和约束绝对路径不同，分别记录；最终十项STA单独验收。

## 正裕量候选017：late1双向并行移位

1. 名称：late1 parallel direction shifter。
2. 文件：rtl/core/execute/replica_late1_shifter.v。
3. 流水级：ctrl4组合单元；保持原周期、端口。
4. 职责：两个方向同时计算，在输出端根据LEFT选择，移除LEFT到输入反转mux再穿过整条移位链的路径。
5. 时钟复位：组合，无时钟/复位变化。
6. 接口：原五个端口逐字不变；移位量仅SRC2[4:0]。
7. 状态：无；SIGNED&&SRC1[31]作为两个方向的填充位，包含非架构组合LEFT=SIGNED=1时的原语义。
8. 存储：无RAM、FF，不改固件。
9. 预算：预期增加组合逻辑换取方向控制更短的逻辑深度，单独按120MHz优先实验评估，实测报告代价。
10. 物理关键路径：009的LEFT控制扇出58，数据经过输入方向选择、移位、输出方向选择、写回、前递。此变更仅重构late1移位器，其余三个移位器不变。单纯物理策略是否有效仍分别保留各组结果，不混用。
11. 测试：基线009负STA是性能失败证据；实现前已存在四模块33792组全移位量/四种控制测试。重构后运行该测试、百万周期全内部lockstep、20次完整UART/五CRC，再做独立完整STA；内部对照失败即回退。合法输入的功能一致和未知态差异不能混淆。

## 本轮最终选择与实验结论

- 014：最终setup WNS=+0.036ns，setup失败0；Slow/Fast十项全部>0，最小hold=+0.016ns。LUT8907/FF7237/LUTRAM72/DRM34/APM5，旧面积预算增加611，面积门禁失败。本轮按用户120MHz优先目标选用此实现，保留成本披露。
- 016：最终setup WNS=+0.023ns，十项全部>0，作为正裕量备选；资源与014相同。
- 015：最终-0.057ns，与009相同；属性未改善实现，回退。
- 017：33792组移位测试、百万周期整核对照、20次完整UART/五CRC均通过，20次仍3799461ticks。最终setup=-0.621ns，24个失败端点；LUT9026/FF7060/LUTRAM72，回退。没有将功能通过等同于时序改善。
- 当前交付恢复014的完整RTL与Tcl，未保留015属性或017双向并行移位器。所选综合网表20万周期数字输出对照通过；PLL stub、无SDF，证据scope如实保留。
- CoreMark/MHz 5.6未达到，7000次原固件保持不变；没有新的实板结果。原5.346252494为历史位流成绩，不能附到本次位流。


## 板卡续验最终记录（021与022）

021已独立完整实现：setup +0.148ns，最小hold +0.028ns，十项正裕量；LUT9016/FF6799/LUTRAM72/DRM34/APM5，总量15887。比020少329，但仍超旧预算282，面积门禁失败，不声称面积目标达成。选作实验候选，不声称已上板稳定。

20次CRC/相同退休摘要通过，周期少0.575%；100次CRC通过，仅少0.09368%，长期提分没有证明。异常与定时中断返回、匹配综合输入的20万周期数字网表对照通过，后者PLL被替换且无SDF。正式7000次镜像保持不变。

022局部计数器写端定向4096次通过，但20次CoreMark反而更慢，已回退；源与测试见 evidence/records/boardopt_20261101/rejected022。关闭展开及O3也更慢，不采用。BTB折叠索引仅离线模型，未进入RTL；测试名称已澄清，数学模型通过不代表实际硬件采用。
