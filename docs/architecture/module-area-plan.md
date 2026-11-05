# CPU RTL 模块合同与面积计划

## YOLO120 应用集成范围（2026-11-03）

用户授权把 YOLO 接入新 CPU 并提速。应用增加的加速器、摄像头和 DDR 不套用
CPU 单独的 8,875 LUT 上限；CPU 内核保持 `project/cpu120` 提供版本。
整机仍必须满足 PG2L100H 的实际容量与最终多角 STA，未测资源不填写成实测值。
按用户最新顺序先完成 YOLO 整合和测速，再做识别改进、实时白色界面、四路舵机和音频。
物理垃圾桶索引固定为 0 可回收（蓝）、1 其他（灰）、2 有害（红）、3 厨余（绿）。
新增界面与外设属于用户授权应用范围，实施前仍须添加模块合同、预算与验证项。

### 模块合同：YOLO120 快照顺序归一化读取

1. 名称：video_ai_frontend 的顺序 RGB565 → RGB int8 读取口。
2. 文件/流水级：`project/yolo120/rtl/video_ai_frontend.v`；快照 RAM 同步读一级，AXI-Lite 响应寄存一级。
3. 职责：增加 0xBC 只读流式数据口；每次有效 AR 握手恰好消耗一个像素，返回 `0x00BBGGRR`。
4. 时钟/复位：CPU 与加速器 120461538 Hz，低有效同步复位；摄像头与像素域仍使用原握手 CDC。
5. 接口：增加 rd_en（来自 conv_engine_axil 的 ARVALID && ARREADY）；0x78 设置地址，0x7C 原始读不推进，0xBC 归一化读推进；越界返回零，不回绕。
6. 内部状态：复用 16 位 snapshot_address；仅 0xBC 握手且地址 < 57600 时加一；0x78 写地址优先。
7. 存储资源：复用现有 320×180×16 快照 RAM；常数映射组合逻辑，无新增帧缓存。
8. 面积预算：应用资源增量待 PDS 报告；预计小于一张新帧 RAM，不能替代实测；总量须低于器件容量。
9. 物理区域：沿用 CPU 快照 RAM 读端所在时钟域，不增加跨域数据路径。
10. 关键路径：同步像素数据经过 5/6 位查表进入 AXI RDATA；最终需在 8.30 ns 约束下重新 STA。
11. 测试/变更：全部 65,536 个 RGB565 值与旧整数公式逐位比较；AR/R 背压、地址设置、连续读、末尾越界、原始读兼容；CPU+MMIO 固件启动另测。0xBC 优化可用 UART cmd10 关闭作 A/B。

### 模块合同：YOLO120 顶层与 SoC 适配

009 物理实现试验：保持 CPU/AI 120.461538 MHz、RTL、固件和模型不变；
沿用 008 的 CPU 逻辑区域 x=50..105、y=20..100，仅将 gplace_seed 从 2
改为 20，groute_seed 仍为 2。原因是 008 主失败路径布线占主导；007 更小
区域因容量不足被 PDS 拒绝，不继续压缩全 CPU 区域。该试验没有 RTL 面积
增量，实际映射资源仍须比对；不承诺 seed 20 会通过或复现独立 CPU 的裕量。
种子、全部源快照与最终多角 STA 绑定；保留现有 setup/hold、DDR 与区域验收门禁。

1. 名称：YOLO120 CPU/加速器/摄像头/DDR 集成。
2. 文件/流水级：`project/yolo120/rtl/yolo_camera_top.v` 与构建时生成的 vexii_ai_soc；沿用 CPU 流水线。
3. 职责：以新 CPU 替换旧快照，保留六分类完整 85 算子图与原摄像头/OSD。
4. 时钟/复位：CPU/加速器使用新 CPU 的 27×58/13 PPLL；锁定且 DDR ready 后各域同步释放复位。
5. 接口：加速器窗口 0x10003100，UART 0x10001000；DDR 通过原异步 FIFO 桥接。
6. 内部状态：外设 TL 请求至 D 返回期间独占所有权；不改 CPU 执行单元状态。
7. 存储资源：CPU 64 KiB RAM 八字节通道初始化；模型由 UART 写入 DDR 并做 CRC。
8. 面积预算：CPU 与应用分别说明；整机须满足器件资源，未实现前不宣称通过。
9. 物理区域：优先保证 DDR IP 固定位置。003 的 CPU 反馈布线过长；试验 CPU core 逻辑区域 x=50..105、y=20..100（PDS 逻辑坐标），不改 RTL、时钟或时序例外。004 的区域输入被映射覆盖，005 证明该层级已展开；后续从同次映射 DB 导出叶单元名称并逐个绑定，映射完成后写入 PCF。区域必须实际匹配，最终仍以多角 STA 验收；未经通过不作发布约束。
10. 关键路径：CPU、加速器、快照归一化均需重新布局布线；原 CPU STA 不能证明整机。
11. 测试/变更：冻结 CPU 输入哈希、ELF/八通道一致性、完整编译、启动/MMIO 与已有加速器回归、最终 STA；真实一秒目标由板上重复计时验收。配置 PLL 的 24.75 MHz 输出与两个 SCCB 时钟显式约束；物理 SCCB 为 /2500，PDS 不接受 ≥100000 ns 周期，故分析用更严格的整数 /2400（约 96873 ns），保留源边沿对齐；不改变 RTL。最终 setup/hold 必须包含这些时钟。

### 模块合同：独立 HDMI 启动诊断

1. 名称：HDMI 彩条与串口启动诊断；仅作黑屏定位，不是 YOLO 交付版本。
2. 文件/流水级：`project/yolo120/diagnostics/hdmi/hdmi_startup_top.v`；沿用现有视频 PLL、同步发生器、MS7210 初始化序列，RGB 与同步信号等长一级输出。
3. 职责：不依赖 CPU、DDR 或摄像头，持续输出 1280×720 彩条；COM34 每秒报告 PLL 锁定、HDMI 复位和初始化状态以及 I²C 原始读值。
4. 时钟/复位：27 MHz 板载时钟；视频 PLL 生成 74.25 MHz 像素时钟（ratio0=16、duty0=16，对应50%）与约 9.983 MHz 配置时钟；锁定后延迟释放 HDMI 复位，UART 独立运行。002 修正原 duty0=8 导致的25%占空比；同步维护 Verilog 与 IDF 参数。
5. 接口：只用已核对的 sys_clk、HDMI RGB/同步/复位/I²C 与 C24 UART TX 引脚；其余引脚保持未使用，不连接舵机或音频。
6. 内部状态：像素计数、初始化控制、UART 状态快照与串行移位；无推理状态，诊断值不等于显示器实际出图。
7. 存储资源：无 DDR/帧缓存/程序 RAM，仅固定 ASCII 状态文本与少量寄存器。
8. 面积预算：独立诊断，不并入 YOLO 或 CPU 面积口径；`hdmi-startup-001` Device Map 实测 LUT 436、FF 526、LUTRAM 0、DRM 0.5、IO 33、GPLL 1，总计 LUT+FF+LUTRAM=962。
9. 物理区域：沿用配套板 HDMI 和时钟引脚；不添加物理区域约束。
10. 关键路径：74.25 MHz 像素计数与 RGB 输出；27 MHz UART 与配置域状态使用双级同步。最终多角时序检查后才能下载新诊断位流。
11. 测试/变更：仿真核对完整帧行数、有效像素、HS/VS、八段彩条和 UART 帧；另以厂商 GTP_GPLL 模型测量实际 PLL 周期及高电平宽度，检查 IDF/Verilog 参数一致；PDS 最终 STA、JTAG done、COM34 实际日志分别记录。外接 HDMI 无电脑采集设备时保留目视待验，不能用串口成功替代屏幕已亮。

## 执行规则

- 一次只改一个 RTL 模块；先差分验证，再综合和实现。
- 面积验收以同一 PDS 器件、约束、优化选项和冻结基线比较。`LUT + FF + LUTRAM` 不得高于基线；总 LUT 不得超过 8,875。目标优于原参考 8,841 LUT。
- 现有证据没有模块级资源分解，禁止推测各 shifter 的 LUT/FF 数。首轮候选需保留 PDS 层级资源报告；无法取得层级分解时只用整设计面积作 gate。
- 当前时序门槛是 Setup、Hold 均无失败端点，PLL 实测不得低于 120.461538 MHz。

## 模块合同：late1 shifter operand path

1. 名称：late1 shifter operand path。
2. 文件：`project/pds_native_120/rtl/core/sections/052_LsuL1Plugin.vh` 中 `u_late1_shifter` 例化；被调用的纯组合单元为 `project/pds_native_120/rtl/core/execute/replica_late1_shifter.v`。
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
2. 文件：`project/pds_native_120/rtl/core/sections/052_LsuL1Plugin.vh` 中 `u_early1_shifter` 例化；组合移位器为 `project/pds_native_120/rtl/core/execute/replica_early1_shifter.v`。
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
2. 文件：`project/pds_native_120/rtl/core/sections/052_LsuL1Plugin.vh` 中 `u_late0_shifter` 例化；组合移位器为 `project/pds_native_120/rtl/core/execute/replica_late0_shifter.v`。
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
