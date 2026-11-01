# PDS CPU 原创优化与上板验收计划

## 目标与边界

- 以现有独立 PDS 版本作为可复现基线，逐步写出并验证原创微架构优化；不通过删除来源标记来声称原创。保留第三方来源、许可证与改动记录。
- 基线：7,000 次 CoreMark v1.0，1,309,328,358 ticks，5.346252494 CoreMark/MHz，PLL 120.461538 MHz，实测 10.869264827 s；两次同位流板测五项 CRC 全过。
- 目标：不降低 120.461538 MHz，在同一 CoreMark v1.0 工作负载下先超过基线、最终争取达到 6.00 CoreMark/MHz；所有发布成绩必须来自新位流的板测。
- 6.00 分对应约 1,166,666,667 ticks / 7,000 次，较当前少约 10.9%。若单次运行不足 10 秒，按官方规则提高迭代数，不改基准算法、输入或 CRC 规则。
- 必须同时消除 Setup 违例（当前 WNS −1.426 ns、619 个失败端点），至少不增加现有 LUT（8,875；参考 8,841），功能测试、五 CRC、上板成绩全通过。

## 已核对的工程事实与执行约束

- 当前仓库提交为 `5408ea0`；优化计划和首个 RTL 候选均为本轮工作区改动，尚未提交。
- PDS 发布包 `tools/build.py verify` 已使用工作区 Python 运行时复核通过：43 个直接源、96 个含 include 的 HDL 文件、8 个 RAM lane，固件镜像哈希一致。该检查不代表形式等价或时序通过。
- 已有最终时序报告要求周期 8.301 ns（120.4674 MHz），估算周期 9.727 ns，Setup WNS −1.426 ns、619 个失败端点；慢角 Hold 无失败端点。关键路径从 lane1 late SRC1 控制寄存器经过 late1 shifter、写回选择和寄存器文件写数据反馈，逻辑 1.207 ns、布线 8.160 ns。故不能把瓶颈简单归因于移位器，也不能声称当前设计已完成 120 MHz 时序收敛。
- 当前板测的 PLL 频率为 120.461538 MHz，但这与 PDS 的 setup 估算不是同一口径；优化验收须同时报告实测 PLL 和实现后多角 STA。
- 仓库缺少模块合同、面积预算和错误汇总文件。本计划将补齐首个候选的模块合同/面积基线；获得模块分解报告前，不填写臆测的单模块 LUT 数。
- 板卡端口可见：COM34 为 Silicon Labs CP210x，JTAG 服务端口 65420 正在监听。仍须在最终候选下载时验证连接、器件 ID 与串口结果。

## 阶段 0：锁定基线与每轮可比性

1. 保留 `project/pds_native_120/bitstream/current/`、`evidence/implementation-standalone-001/` 和两份 `standalone-board-*` 记录，不覆盖 `standalone-001`。
2. 每个候选使用新的 build 名和 evidence 目录；固定 PDS 版本、器件、约束、时钟、CoreMark 镜像及工具参数。
3. 每轮记录 RTL diff、输入 SHA256、综合资源、最终多角时序、CoreMark ticks/CRC/耗时/分数和新位流 SHA256。仅允许一次只改变一个因素。
4. 先运行 `python tools/build.py verify`；源码有意变化后，人工审查 diff，再更新 release manifest 并重新 verify。禁止只刷新哈希掩盖未审查变化。

## 阶段 1：先修最明显的关键路径，不改变微架构周期

1. 以 `evidence/implementation-standalone-001/final-timing.rtr` 的完整路径为依据，分别记录路径起终点、逻辑级数、每段布线/单元延迟、扇出和级间反馈。当前最差路径跨越 late1 shifter、写回和寄存器文件写数据，不能只针对 shifter 做局部假设。
2. 为首个候选补全模块合同，先在同一器件、相同约束和构建选项下取得模块或层级 LUT/FF/LUTRAM 报告；若 PDS 无法给出模块资源分解，则明确以整个设计资源作为唯一 gate，不伪造局部数字。
3. 只对被完整路径证据支持的一个模块做原创组合逻辑候选；保持端口、周期、提交顺序、异常语义不变。四个 early/late、lane0/lane1 shifter 的比较测试覆盖 shift amount 0–31、左右移、逻辑/算术右移及边界/随机数据。
4. 先跑差分仿真，再跑 PDS 综合和最终 STA。候选必须功能一致、Setup/hold 无失败端点、PLL≥120.461538 MHz、LUT 不超过 8,875 且总面积不高于冻结基线；任一不满足即回退。时序单独改善不计作 CoreMark 提分。

## 阶段 2：测量 CoreMark 周期损失后再选提分点

1. 当前没有 ILA 波形，也没有停顿来源的量化分解；先为分析构建补充可观察信号/计数，不改变交付构建的功能和默认参数。
2. 分类统计双发射占用率、lane1 发行率、取指供给不足、RAW/load-use 停顿、分支冲刷、I/D cache refill 等候选原因；用同一冻结镜像测量。
3. 结合 CoreMark 热路径，只选择贡献最大的一个瓶颈，形成一个局部原创 RTL 改动和明确假设。优先评估：lane1 操作数/旁路路径、分支重定向恢复、取指/数据 cache refill 与 store-to-load forwarding。
4. 每个候选先跑差分仿真和定向测试，再跑 CoreMark 仿真/板测前的 PDS 资源及时序；周期数不降或超出时序/面积门槛即回退。

## 阶段 3：逐轮提分与回退规则

1. 每轮与冻结基线比较 ticks、CoreMark/MHz、LUT/FF/DRM、WNS/TNS、关键路径、CRC；不以 UART 整数秒或截断 Iterations/Sec 算分。
2. 接受条件：功能等价、五 CRC 正确、CoreMark/MHz 实际提高、频率不低于 120.461538 MHz、Setup/hold 均通过、资源不超过门槛。
3. 若某轮只改善时序但未提分，可作为后续候选的时序余量；不得把时序提升冒充性能分提升。
4. 分数目标采用逐级门槛：高于 5.346252 → 达到 5.6 → 争取 6.0。每次只保留有完整报告且优于上一轮的版本。

## 阶段 4：最终 PDS、板测与提交证据

1. 在全新 run 名执行完整独立 PDS build，确认八个 RAM lane 全部载入；记录新位流、资源和最终多角 STA。
2. 用最终同一 SHA256 位流下载板卡，至少独立运行两次；每次确认迭代数、ticks、实际耗时≥10 s、五项 CRC，并按完整 ticks 算分。
3. 抓取实际 ILA 波形并说明流水线发射、停顿、冲刷或 refill；形成一份性能分析报告，注明硬件、软件、工具版本、频率、资源、分数公式、瓶颈和前后对比。
4. 只有全部门槛通过，才把该版本标为有效最终成绩；若 WNS<0、频率下降、CRC 失败或成绩未提升，则保留上一份已验证位流并标注候选失败。

## 本次执行顺序

1. 基线 verify 与旧成绩核对（已完成：verify PASS；5.346252494 CoreMark/MHz @ 120.461538 MHz）。
2. 补齐模块合同/面积基线；分析完整关键路径并区分逻辑、扇出与布线贡献。
3. 做单模块、周期不变的 A/B RTL 候选；跑 33,792 向量移位器测试及核心 lockstep/已有定向测试。
4. 候选通过功能后做 PDS 实现、多角 setup/hold 与资源 gate；不通过立即回退。
5. 对性能而非仅时序建立停顿/双发射剖析，确定 CoreMark 的主要周期损失后一次只改一个瓶颈。
6. 取得通过全部 gate 的候选后，重新 PDS 实现并以相同位流上板独立测两次，核验有效成绩。

## 候选 001 执行记录（late1 shifter RS1 直连）

- 改动：`project/pds_native_120/rtl/core/sections/052_LsuL1Plugin.vh` 将 late1 shifter 的 SRC1 从通用 RS1/U-immediate 选择结果改接到 RS1；RV32I shift 运算的 SRC1 固定来自 rs1。保留独立 PDS 生成文件及其来源记录。
- 功能验证：ModelSim 对 PDS 发布包编译通过；reference/replica 锁步运行 1,000,000 周期通过，覆盖 52,210 个有效 late1 移位周期，检查状态、输出、内存和 SRC1 选择均通过；既有 shifter 定向测试 33,792 向量通过；发布包完整性 verify 通过。
- PDS 构建：`project/pds_native_120/build/late1_rs1_bypass_001/` 完成器件 PG2L100H、-6、FBG676 的布局布线；最终资源报告为 6,221 + 2,576 = 8,797 LUT、6,662 FF、34 DRM、72 Distributed RAM。综合报告为 8,866 LUT、6,658 FF、34 DRM；报告阶段口径不同，后续比较统一使用同一份最终 P&R 资源报告。
- 时序结果：完整布线后慢角 setup 仍失败。`place_route/pango_vexii_top_timing_summary_after_hold_fix.txt` 报 WNS −1.237 ns、TNS −172.839 ns、628 个失败端点；`report_timing/pango_vexii_top.rtr` 报 WNS −1.313 ns、TNS −230.673 ns、769 个失败端点，预估频率 104.015 MHz。工具的 hold-fix summary 与独立 timing report 数值不完全一致，二者均未通过 gate；慢角 hold 无失败端点，快角 setup/hold 均无失败端点。
- 新关键路径：lane1 `execute_ctrl2_up_Decode_UOP[25]` 经 `u_early1_shifter` 的 shift-reverse/shift-stage、lane1 写回选择及 lane0 RS1 反馈，最终到 `N20/gopapm/X[3]`；逻辑 1.545 ns、布线 7.225 ns，共 9 个逻辑级。路径已从 late1 shifter 转移到 early1 shifter，说明单独移除 late1 SRC1 mux 有改善但不足以收敛全设计时序。
- 判定：候选 001 未达到时序 gate，不下载板卡、不将其成绩作为有效成绩；本轮没有新 CoreMark 分数。原基线仍是唯一有效板测成绩 5.346252494 CoreMark/MHz @ 120.461538 MHz。
- 下一候选（002）规划：只把 early1 shifter 的 SRC1 接到同一流水级已寄存的 `execute_ctrl2_up_integer_RS1_lane1`，保留早期通用 SRC1 给 ALU/分支等消费者。依据：STA 起点在 `execute_ctrl2_up_Decode_UOP_lane1[25]` 并穿过 early1 shifter 的 SRC1/移位网络；RV32I SLL/SRL/SRA 的数据操作数都来自 rs1。执行前检查 stage-2 RS1 与 shifter/shift amount/LEFT/SIGNED 的更新与 stall 条件一致；再跑所有移位量、三种 RV32I shift、边界值和随机数据的定向比较及 1,000,000 周期 lockstep。PDS 若慢角 setup/hold 未闭合或最终 LUT 超 8,875，不上板；通过后在保持 120.461538 MHz 的同一板卡环境运行相同 7,000 次 CoreMark 两次。
- 之后在不影响交付 RTL 的性能剖析构建中量化 CoreMark 双发射率、停顿与 cache refill，选择能降低 ticks 的独立优化；候选 002 的时序改善本身不作为提分。

## 候选 002 执行记录（early1 shifter RS1 直连）

- 改动：在同一发布 RTL 文件 `project/pds_native_120/rtl/core/sections/052_LsuL1Plugin.vh`，将 early1 shifter SRC1 接到同级已寄存的 `execute_ctrl2_up_integer_RS1_lane1`；其他 early1 通用 SRC1 消费者保持不变。该改动与候选 001 同时存在，因此 002 的整体 A/B 结果相对原始基线包含两处操作数旁路。
- 功能验证：PDS 发布包 `verify` 通过；reference/replica 锁步 1,000,000 周期通过，断言覆盖 25,293 个有效 early1 移位周期；33,792 项 shifter 定向向量通过。以上证明当前测试覆盖下功能等价，不构成板测或时序通过证明。
- 发布包复核：本轮再次运行 `python tools/build.py verify`，结果 PASS：43 个直接源、96 个 include 闭包 HDL 文件、43 个模块、0 个外部源码依赖、8 个 RAM lane；固件 ELF/RAM 哈希与构建记录相同。该检查范围是哈希、include 闭包和固件镜像，不等于形式等价。
- 镜像与位流：`build/early1_bypass_002/image_verification.json` 确认检查 36,444 字节 ELF、RAM 镜像 65,536 字节，镜像哈希分别为 `5c4ecd094efd2fea33f08d9f5ac8e79118584e85588a7bf18189bf37da0c270b` 和 `c0166c5cf86143cacd3b50c46b1c7f9ba28796e5b8f4c9d5dcc5507d6a3ef31d`；构建结果确认 8 个 RAM lane 已载入。位流 SHA256：`9ae1877f413b5287fc5ffbe5cd998d8fe84fc39c99979facc7dd75064bcebda9`。
- 资源：PDS Device Map 为 8,871 LUT、6,658 FF、34 DRM、72 Distributed RAM。相对门槛 8,875 LUT 少 4 LUT，FF/DRM/Distributed RAM 未增加；面积门槛通过。此数值来自 Device Map，不冒充独立 post-route 资源口径。
- 最终时序：`build/early1_bypass_002/report_timing/pango_vexii_top.rtr` 慢角 Setup WNS −0.687 ns、TNS −83.136 ns、455 个失败端点；慢角 Hold 0.027 ns、0 个失败端点；快角 Setup WNS 2.648 ns。目标约束周期 8.301 ns，报告估算周期 8.988 ns / 111.2595 MHz。Setup 未收敛，未达到 120.461538 MHz 门槛。
- 当前最差路径：`execute_ctrl4_up_LsuL1_MIXED_ADDRESS_lane0[8]` → LSU refill hazard 比较/组合控制 → Trap pending → lane1 选择 → register-file write merge → RAM 写端。报告为 9 级，逻辑 1.458 ns、布线 6.969 ns；布线占 82.7%。RTL 映射集中在 `sections/023_CsrAccessPlugin.vh` 的 refill slot 地址比较，以及 `sections/042_LsuL1Plugin.vh` 的 refill hazard 聚合、LSU hazard 和 side-effect 控制；后续必须沿 trap/lane/merge 的扇出链逐网映射，不能只改 comparator 后就推断改善。
- 次关键路径：`execute_ctrl2_up_integer_RS1_lane1[17]` → early1 branch condition → PC target/选择 → PC state，WNS −0.680 ns；13 级，逻辑 2.293 ns、布线 6.201 ns。它说明单独优化 shifter 不能关闭全局 setup。
- 判定：候选 002 功能和面积门槛通过，但慢角 Setup 未过；不下载上板、不作为有效成绩，也没有新 CoreMark 分数。唯一有效板测成绩仍为 5.346252494 CoreMark/MHz @ 120.461538 MHz。

## 候选 003 执行记录（LSU refill compare 拆分）

1. 冻结候选 002 当前输入、PDS 报告与位流哈希；不得在 `early1_bypass_002` 原目录重跑覆盖证据。补齐该候选对应的独立 evidence 记录后，原构建目录保留为可复核证据，不清理。
2. 对 LSU 主路径逐网核查：`sections/042_LsuL1Plugin.vh` 第 220–235 行定义 8 个 refill slot 的 `[11:6]` 地址匹配、OR 聚合和 LSU HAZARD；`sections/038_TrapPlugin.vh` 第 382–386 行接收 LSU trap valid；`sections/048_WhiteboxerPlugin.vh` 第 21–23 行将 LSU flush 与 lane age 条件汇入 lane1 cancel；`sections/027_PcPlugin.vh` 第 14–19 行用该条件屏蔽 lane1 select；`sections/048_WhiteboxerPlugin.vh` 第 32 行由 lane1 write-port valid 汇成 register-file write merge valid。P&R 报告中可直接看到 refill hazard、Trap pending、lane select 与写合并信号依次出现在路径，但综合网表可能折叠/共享逻辑；需进一步核实它们是否同一逻辑锥，查明真值条件、扇出、跨层级扇出和物理分布，不把相邻报告网名当作已证明的直接逻辑依赖。
3. 单独复核次关键路径的 branch 条件计算、预测纠正与 PC 聚合语义。将 LSU 和 branch 两条路径作为不同候选，禁止一轮同时修改两个模块。
4. 已在 PDS 综合网表确认该路径的 `sections/042_LsuL1Plugin.vh:220` 6 位地址相等比较落成串接的 3 级 `GTP_LUT6CARRY`（分别处理地址位 6–7、8–9、10–11），最差端点穿过第三级。候选 003 因此只重排每个 refill slot 的比较为两个并行 3 位相等比较（`[11:9]` 与 `[8:6]`），再与 valid 合并；逐 slot 输出仍是 `valid && (stored_address[11:6] == request_address[11:6])`，不改状态、流水周期或提交语义。综合后必须检查 PDS 是否保留并行结构、资源是否过门槛；若被重新串接或面积/时序变差，则回退，不尝试同时改写 trap/lane/branch 控制。
5. 功能检查：独立 PDS 编译时确认八个 RAM lane 均加载；release `verify` PASS。对 6 位地址相等比较的原式与拆分式穷举 8,192 个 valid/request/slot 组合，输出一致。该检查仅覆盖比较器语义，没有跑候选 003 整核锁步或 LSU 定向回归。
6. PDS 构建：独立目录 `project/pds_native_120/build/refill_compare_003/`；器件 PG2L100H-6 FBG676；综合、Device Map、布局布线、最终时序和位流生成均完成。Device Map 为 8,866 LUT、6,658 FF、34 DRM、72 Distributed RAM；LUT 低于 8,875 上限，但该数字来自 Device Map，不代表 post-route 层级面积。
7. 时序结果：`multiseed_summary.csv` 最终慢角 Setup WNS −1.043 ns、TNS −213.843 ns、617 个失败端点；慢角 Hold WHS +0.031 ns、0 个失败端点；快角 Setup WNS +2.433 ns、Hold WHS +0.023 ns。`.rtr` 估算周期 9.344 ns / 107.0205 MHz。`place_route/pango_vexii_top_timing_summary_after_hold_fix.txt` 报 WNS −0.981 ns、542 个失败端点；收尾 summary 与独立 `.rtr` 有差异，按最终 `multiseed_summary.csv` 与 `.rtr` 保守判定均未通过。
8. 最差路径已转移到 late0 lane：`execute_ctrl3_up_late0_SrcPlugin_logic_SRC1_CTRL_lane0[0]` → 通用 SRC1 选择 → `u_late0_shifter` → late0 格式化/写回 → register-file RAM 写端。7 个逻辑级，逻辑 1.101 ns、布线 7.436 ns（布线 87.1%）。候选 003 未达到无 setup 失败端点及 ≥120.461538 MHz 门槛，位流 SHA256 为 `07f4baa73a23a42aba70bfcadfc778f9d20160d719f0b1fe1e9980d5b20e23ff`，不得下载；没有新 CoreMark 成绩，唯一有效板测结果仍为 5.346252494 CoreMark/MHz @ 120.461538 MHz。

## 下一步计划（候选 004，late0 shifter 操作数直连）

1. 保留 003 的构建、位流和报告，不在原目录重跑；新候选建独立 build 名，继承相同 release 镜像、器件、约束、PDS 参数与实现种子策略。
2. 仅改 `sections/052_LsuL1Plugin.vh` 的 `u_late0_shifter` SRC1 输入，将通用 RS1/U-immediate 选择信号改接为 `execute_ctrl4_up_integer_RS1_lane0`。保持 shift amount、LEFT、SIGNED、输出、时序周期和其他 SRC1 消费者不变；理由是候选 003 的新最差路径穿过 late0 通用 SRC1 选择与 shifter。
3. 检查 stage-4 RS1、late0 shifter 控制、stall/flush 的更新条件一致；跑有效 late0 SLL/SRL/SRA 操作数断言、33,792 项 shifter 向量、1,000,000-cycle reference/replica lockstep 和 LSU refill/load/store/fault 定向回归。任一不一致先回退，不做 PDS。
4. 更新发布 manifest 并重新 verify，再运行全新独立 PDS。验收要求 Device Map LUT ≤8,875、总面积不高于冻结基线、慢角 setup/hold 零失败端点，且时序估算与板测 PLL 均不低于 120.461538 MHz；不达标不上板。
5. 只有 PDS 门槛通过后才烧录同一 SHA 位流；按冻结 CoreMark v1.0 镜像实测两次，确认运行 ≥10 s、五项 CRC 正确并按完整 ticks 计算分数。时序优化不等于 CoreMark/MHz 提分，仍需实测。

## 当前已知问题

- 现有有效板测基线对应的 PDS Setup 未闭合：WNS −1.426 ns，619 个失败端点；其板测 PLL 120.461538 MHz 不能替代 PDS STA 收敛证明。
- 候选 002 比旧实现改善到 WNS −0.687 ns、455 个失败端点，仍不满足 Setup gate；Device Map LUT 为 8,871，低于 8,875 门槛 4 LUT。
- 候选 003 拆分 refill 比较后 WNS −1.043 ns、617 个失败端点；虽然 Device Map 降至 8,866 LUT，Setup 仍失败且瓶颈转移到 late0 shifter。候选 003 未上板，没有新成绩。
- 当前缺 ILA 波形与书面性能瓶颈分析。
- 本文的 6.0 是目标，不是保证；只有最终新位流上板测得才可宣称达成。
