# 事实清单（竞赛技术文档可直接引用）

口径约定：

- 证据路径若无特殊说明，均相对 `D:/FPGA_Project/zi_guang_tong_chuang/`。
- "数值"一栏只填证据文件里出现的数字；由两个已记录数字相除得到的值，在"口径"里写明算式。
- 本文不含推断、外推与估算；无法核实的条目统一列在最后一节。

---

## 1. 独立 CPU 基准（project/pds_native_120，build/standalone-001）

两次上板为同一份位流的两次独立 SRAM 下载，逐字段结果相同。

| 指标 | 数值 | 口径/条件 | 证据路径 |
|---|---|---|---|
| CPU_HZ | 120,461,538 Hz | 串口打印 `CPU_HZ=`，两次运行相同 | pangoriscv/project/pds_native_120/evidence/standalone-board-001/uart.log；pangoriscv/project/pds_native_120/evidence/standalone-board-002/uart.log |
| 迭代数 | 7,000 | 串口 `ITERATIONS=7000` | 同上 |
| Total ticks | 1,309,328,358 | 串口 `Total ticks` 与 `TICKS_LO=1309328358`（`TICKS_HI=0`） | 同上 |
| 运行秒数 | 10.869264827 s | 1,309,328,358 ÷ 120,461,538；串口 `Total time (secs): 10` 是整数截断值，不可用于算分 | 同上；pangoriscv/evidence/records/validation_20261104/coremark_fresh_results.json |
| CoreMark 分数 | 644.017798017 | 7,000 ÷ 10.869264827（每秒迭代数）；不是 MIPS | pangoriscv/evidence/records/validation_20261104/coremark_fresh_results.json |
| CoreMark/MHz | 5.346252494441 | 644.017798017 ÷ 120.461538 | 同上 |
| 五项 CRC | seedcrc 0xE9F5(59893) / crclist 0xE714(59156) / crcmatrix 0x1FD7(8151) / crcstate 0x8E3A(36410) / crcfinal 0x25B5(9653) | `Correct operation validated`；crcfinal 随迭代数变化，不是定值判据 | pangoriscv/project/pds_native_120/evidence/standalone-board-001/uart.log |
| 两次运行一致性 | 逐字段相同 | 两次独立下载、两个证据目录 | 同上两目录 |
| 位流 SHA256 | 2e38db1c26bd6a1bcb9a3fe1d09ca6d70bf430d5ac50001f450664a50c81f9cb | 两次上板即此位流 | pangoriscv/project/pds_native_120/bitstream/current/SHA256SUMS |
| 资源 | LUT 8,875 / FF 6,658 / DRM 34 / APM 5 / Distributed RAM 72 | 交付位流的 device map + 综合报告 | pangoriscv/project/pds_native_120/bitstream/current/measurement.json |
| 面积门禁 | 未通过 | 参考 8,841 LUT，本版 +34（+0.38%），`area_gate_passed: false` | 同上；pangoriscv/README.md §6 |
| Setup(Slow) | −1.426 ns | TNS −189.497 ns，失败端点 619 / 总计 24,066 | pangoriscv/project/pds_native_120/evidence/implementation-standalone-001/final-timing.rtr（第 42–48 行） |
| Setup(Fast) | +2.262 ns | 失败端点 0 / 24,066 | 同上（第 82–88 行） |
| Hold(Slow) | +0.015 ns | 失败端点 0 / 24,066 | 同上（第 50–56 行） |
| Hold(Fast) | +0.014 ns | 失败端点 0 / 24,066 | 同上（第 90–96 行） |
| 多角总判定 | `Design Summary : Some Constraints Violated.`，`sta_closed: false` | 120 MHz 是实测跑得动，不是时序约束通过 | 同上（第 40 行）；pangoriscv/project/pds_native_120/bitstream/current/measurement.json |
| STA 报告估算频率 | 102.8066 MHz（请求 120.4674 MHz） | 静态估算，不是实测最高频率 | final-timing.rtr（第 37 行） |
| 约束时钟 | core_clk 周期 8.3010 ns；board_clk 37.0370 ns | 多角 STA 时钟表 | final-timing.rtr（第 22–23 行） |
| PLL 周期（仿真实测） | 8.301621 ns | 厂商 PPLL 模型 tb_pll 仿真，非板上测频 | pangoriscv/evidence/board-rtl/pll.log |
| CoreMark/LUT | 0.072565386 | 644.017798017 ÷ 8,875 | pangoriscv/evidence/records/validation_20261104/coremark_fresh_results.json（`coremark_per_lut`） |
| UART 记录 SHA256 | 1d6d31cd8ec011b330c327fb1e116cbff3fb3ecbd538ce2daa75a3e832a522cf | 两次捕获同一哈希 | 同上 |
| 独立"搬家"复验构建 | LUT 8,867 / FF 6,658 / DRM 34 / APM 5；Setup(Slow) −1.532 ns，失败端点 1,171，TNS −531.982 ns；位流 SHA256 f544b61e…83b61d | 2026-11-04 在仓库外复制目录重建，**未上板**；不能代替交付位流数据 | pangoriscv/project/pds_native_120/evidence/indep-rebuild-001/result.json |
| 源码隔离检查 | 43 个设计源文件、8 路 RAM 镜像、`ram_sha256 = c0166c5c…6a3ef31d` | 只证明可脱离仓库构建，不证明语义原创 | pangoriscv/project/pds_native_120/evidence/isolation/result.json |

## 2. CPU 微架构事实

| 指标 | 数值 | 口径/条件 | 证据路径 |
|---|---|---|---|
| ISA | RV32IMC（含 M、C 扩展） | 生成参数 `--with-rvm`、`--with-rvc`；固件 `-march=rv32imc_zicsr_zifencei` | pangoriscv/project/pds_native_120/configuration/profile.json；pangoriscv/project/pds_native_120/evidence/standalone-board-001/uart.log |
| 双发射 | 是（2 lane / 2 decoder） | 生成参数含 `--dual-issue`、`--max-ipc` | profile.json |
| 流水组织 | 存在 execute_ctrl0 ~ execute_ctrl5 共 6 个执行控制寄存器级 | RTL 信号命名（总级数含取指/译码未在任何文件写明） | pangoriscv/project/pds_native_120/rtl/core/sections/ |
| BTB | 启用 | 生成参数 `--with-btb` | profile.json |
| GShare 方向预测 | 启用 | 生成参数 `--with-gshare` | profile.json |
| RAS（返回地址栈） | 启用，深度 4 | `--with-ras`；RTL 中 `ras_ptr` 为 2 bit（4 项） | profile.json；rtl/core/sections/001_FetchL1Plugin.vh |
| I-Cache（fetch L1） | 启用，128 组 × 2 路，refill 8 拍 | `--with-fetch-l1 --fetch-l1-sets=128 --fetch-l1-ways=2 --fetch-l1-refill-count=8` | profile.json |
| I-Cache 取指数据宽度 | 最小 64 bit | `--fetch-l1-mem-data-width-min=64` | profile.json |
| D-Cache（LSU L1） | 启用，64 组 × 2 路，refill 8、writeback 8 | `--with-lsu-l1 --lsu-l1-sets=64 --lsu-l1-ways=2 --lsu-l1-refill-count=8 --lsu-l1-writeback-count=8` | profile.json |
| Store Buffer | 4 槽 | RTL 中 `LsuPlugin_logic_storeBuffer_slots_0..3` | pangoriscv/project/pds_native_120/rtl/core/sections/012_AlignerPlugin.vh |
| 寄存器堆 | 同步读 + 全前递 | `CFG_REGFILE_SYNC=1`、`CFG_REGFILE_BYPASS=1`（该配置头属 V1/V2 变体，见末节说明） | pangoriscv/rtl/core/core_config.vh |
| 片上 RAM | 64 KiB（8 路字节交错） | `--ram-bytes=65536`；固件镜像 8 lane | profile.json；pangoriscv/README.md §8 |
| 语义模块化 | 未完成：53 个源码段 + 4 个已独立移位器 | 不宣称自主原创架构 | pangoriscv/project/pds_native_120/README.md；pangoriscv/rtl/core/README.md |

## 3. 仿真验证事实

| 指标 | 数值 | 口径/条件 | 证据路径 |
|---|---|---|---|
| 参考/目标锁步周期数 | 1,000,000 | `# TEST_PASS exact_lockstep cycles=1000000` | pangoriscv/evidence/records/replica/P14-native/native-pds-001/simulation_sim_result.json |
| 寄存器快照数 | 1,795 | 每 256 周期采样一次（`sample_interval=256`） | 同上 |
| 周期观测数 | 90 | `cycle_observations=90` | 同上 |
| 状态数组数 | 32 | `arrays=32`，运行结束时比较 | 同上 |
| UART TX 边沿数 | 170 | `uart_edges=170` | 同上 |
| 比对范围 | 逐周期核心接口 / 寄存器写 / PC 锁步 | 原文声明 `not formal equivalence`（非形式等价） | 同上（`scope` 字段） |
| 仿真结论 | PASS | 同上；同一结果的 exact 变体记录一致 | pangoriscv/evidence/records/replica/P14-exact/pds-002/simulation_sim_result.json |
| 轨迹 SHA256 | d231b538e1f609976738ed230e29f1af6ec738e7867356d88bf07375d07d1d9a | 仿真 trace 文件哈希 | P14-native/native-pds-001/simulation_sim_result.json |
| 移位器向量测试 | 33,792 个向量，4 个模块，32 种移位量 × 4 种控制组合 | `TEST_PASS reference_shifters modules=4 vectors=33792 all_amplitudes=32 all_controls=4` | P14-native/native-pds-001/simulation_shifters.log |
| 冒烟仿真 | PASS | `SMOKE PASS`（UART 输出） | pangoriscv/evidence/records/replica/P07/sim-smoke/uart_smoke.txt |
| ISA 指令测试通过数 | **无证据** | 见末节 | — |

## 4. YOLO 部分（experiment-yolo120-006）

条件：同一 yolo120-006 位流、同一模型、同一次上板会话；UART 命令 10 切换旧/新预处理；每种模式预热 1 帧后统计 10 帧。"端到端"取逐帧 `max(主机请求到回复墙钟, 板端周期/频率)`，含取图与显示提交，不含一次性模型上传。

| 指标 | 数值 | 口径/条件 | 证据路径 |
|---|---|---|---|
| CPU/AI 时钟 | 120,461,538 Hz | 实验候选时钟，不是已收敛最高频率 | pangoriscv/evidence/records/optimization/yolo120/experiment-yolo120-006/result.json（`candidate.cpu_hz`） |
| 端到端平均 | 旧 1.057596 s/帧；快速 1.017300 s/帧 | 各 10 帧均值 | pangoriscv/evidence/records/cleanup_20261103/yolo_metrics_recalculated.json |
| 端到端中位数 | 旧 1.058628 s；快速 1.016000 s | 同上 | 同上 |
| 端到端最小~最大 | 旧 1.050516~1.063000 s；快速 1.015000~1.031000 s | 逐帧极值 | 同上 |
| 吞吐率 | 旧 0.945541 FPS；快速 0.982994 FPS | 平均延迟倒数 | 同上 |
| 端到端加速比 | 1.0396×（耗时降低 3.81%） | 旧均值 ÷ 新均值 | 同上 |
| 板端取图/预处理平均 | 旧 151.572 ms；快速 109.818 ms | 阶段均值；加速比 1.3802×（降低 27.55%） | 同上 |
| 完整网络前向平均 | 旧 887.912 ms；快速 887.598 ms | 阶段均值 | 同上 |
| 解码平均 | 旧 13.855 ms；快速 13.839 ms | 阶段均值 | 同上 |
| 显示提交平均 | 旧 2.687 µs；快速 2.676 µs | 不等于屏幕完整刷新延迟 | 同上 |
| 位流 SHA256 | 1d57861ef477b1a08d7d57fdb8247388699337c88955a39914c5d4f5abd68c91 | 实验候选位流 | result.json（`candidate.bitstream_sha256`） |
| 时序状态 | `timing_pass=false`，`release_accepted=false` | 板上观测仅作诊断 | result.json（`candidate`） |
| 最终 STA（Setup Slow） | WNS −1.540 ns，失败端点 1,533（ai_clk 1,530 + DDR 3），TNS −668.462 ns（ai_clk） | ai_clk WNS −1.540；ddrphy_sysclk→phy_dq_sysclk_1 为 −0.088 ns / 3 端点 | pangoriscv/evidence/records/optimization/yolo120/experiment-yolo120-006/final_timing.rtr |
| Hold(Slow) | ai_clk +0.008 ns，0 失败端点（55,432 端点） | 同上 | 同上 |
| Device Map 资源 | LUT 25,683 / 66,600；FF 21,654 / 133,200；DRM 107.5 / 155；APM 124 / 240；Distributed RAM 290 / 19,900 | 整个 AI 应用映射资源，非单 CPU 或单卷积模块 | pangoriscv/evidence/records/cleanup_20261103/build_reports/project/yolo120/build/yolo120-006/multiseed_summary.csv |
| 模型 SHA256 | 895909cff31974f11e0a6639f7f6a7cdcce55aacc3a673196fb0d1d9c85cb18a | 实验绑定模型 | result.json（`model_sha256`） |
| 模型上传字节数 | 1,863,560 B（约 1.777 MiB） | 部署 blob 长度 `blob_length`；与模型 SHA256 同一份 | pangoriscv/extensions/yolo/gen/integration/packed/memory_map.json |
| 模型 CRC32 | 977,952,093（0x3A4A5D5D） | 同上 blob 的 `blob_crc32` | 同上 |
| 连续运行帧数 | 353 帧 | `frames=353`，状态快照计数；不等于稳定性验收 | result.json（`frames`） |
| 不提供的指标 | 纯 CPU→FPGA 加速倍数、mAP、识别准确率 | 无同模型同输入纯 CPU 基线；实验会话无标注评测 | yolo_metrics_recalculated.json（`map50: null`、`pure_cpu_vs_fpga_speedup: null`） |

## 5. 27 MHz 完整整机 v3

实现目录：`D:/FPGA_Project/trash_white_split_voice_source_v1/yolo/build_camera_servo_v3_seed3_20261103`（下称 `V3/`）。

| 指标 | 数值 | 口径/条件 | 证据路径 |
|---|---|---|---|
| 系统时钟 | 27 MHz（约束周期 37.000 ns，即 27.027027 MHz） | 板载 27 MHz；约束值见审计记录（原始约束在 PDS 数据库内） | validation_20261104/cpu_evidence_audit.md；V3/place_route/yolo_camera_top_timing_summary_after_hold_fix.txt |
| 时序结论 | `Design Summary : All Constraints Met.` | hold-fix 后最终 STA 摘要，失败端点 0 | V3/place_route/yolo_camera_top_timing_summary_after_hold_fix.txt |
| sys_clk Setup(Slow/Fast) | +16.822 / +24.483 ns | 56,001 端点，0 失败 | 同上 |
| sys_clk Hold(Slow/Fast) | +0.016 / +0.009 ns | 0 失败 | 同上 |
| 全局最差 setup | +1.327 ns | CLKOUT0 推断时钟域 | 同上 |
| 全局最差 hold | +0.008 ns | dvp1→dvp1_pixel（Fast 角） | 同上 |
| 资源（布线后实计） | LUT 28,545（CLMA 20,744 + CLMS 7,801）/ FF 21,911（15,792 + 6,119）/ DRM 138.5 / APM 124 / Dist RAM 290 / IO 141 | 真实布线资源汇总，不取映射阶段估计 | V3/direct_pnr_seed3.stdout.log（Device Utilization Summary） |
| 资源（Device Map 阶段） | LUT 29,012 / 66,600；FF 21,911；DRM 138.5 / 155；Dist RAM 290；IO 141 | 映射阶段值，与布线后 LUT 不同，引用时须注明阶段 | V3/device_map/yolo_camera_top.dmr |
| 位流 SHA256 | 2b98f90fbd0b4fd2de4074e74cb2c4aa8886d6009aa12bba4dfaf5d071bc4657 | 本地重算与板测记录一致 | V3/generate_bitstream/yolo_camera_top.sbit；pangoriscv/evidence/records/validation_20261104/board_result.json |
| 模型上传字节数 | 1,863,560 B | `MODEL_FILE_VERIFIED bytes=1863560`、`MODEL_UPLOAD n/1863560` | V3/board_reprogram_20261104_015418/model_camera.log |
| 模型板端 CRC | 通过 | `MODEL_BOARD_CRC_PASS`；`model_crc_verified: true` | 同上；V3/board_reprogram_20261104_015418/model_camera_result.json |
| 模型 SHA256 | 895909cff31974f11e0a6639f7f6a7cdcce55aacc3a673196fb0d1d9c85cb18a | 与 120 MHz 实验同一模型 | pangoriscv/evidence/records/validation_20261104/board_result.json（`model_sha256`） |
| 摄像头回包日志 1 | 10 帧 `CAMERA 0..9`，3.79~3.85 s/帧，检出 `paper` 0.4385~0.5289 | 每帧一条 JSON，含类别/分数/框 | pangoriscv/evidence/records/validation_20261104/board_validation.log |
| 摄像头回包日志 2 | `RESTORE_CAMERA_FRAME 0..2`、`AUTONOMOUS_FRAME 1..30`，3.787~3.832 s/帧 | 恢复后连续 30 帧 | pangoriscv/evidence/records/validation_20261104/restore_camera.log |
| 摄像头回包日志 3 | 3 帧 `CAMERA_FRAME`，3.813~3.859 s/帧；含 `cardboard` 0.2672 | 逐帧 JSON，附 `camera_frames` 数组 | V3/board_reprogram_20261104_015418/model_camera.log；V3/board_reprogram_20261104_015418/model_camera_result.json |
| 其他同版重下记录 | 另有 02:38:02、02:41:49（recovery）、11-03 retry1 三份 `model_camera.log` | 同目录并列，未逐一比对数值 | V3/board_reprogram_20261104_023802/、V3/board_reprogram_recovery_20261104_024149/、V3/board_reprogram_requested_20261103_retry1/ |
| 不可归属项 | 本整机无 CoreMark 板测；不可把 120.461538 MHz 的 5.346 归到此实现 | 两种频率/两种实现 | validation_20261104/cpu_evidence_audit.md（数据边界） |

## 6. 部署图算子统计

来源：`pangoriscv/extensions/yolo/gen/integration/packed/memory_map.json`（`ops` 数组逐条计数，共 85 条）。

| 指标 | 数值 | 口径/条件 | 证据路径 |
|---|---|---|---|
| 总算子数 | 85 | `len(ops) = 85`，与 README"完整 85 个模型算子"一致 | pangoriscv/extensions/yolo/gen/integration/packed/memory_map.json；pangoriscv/project/yolo120/README.md |
| CONV | 57 | 类型名 `YOLO_CONV` | memory_map.json |
| ADD | 7 | `YOLO_ADD` | 同上 |
| CONCAT | 13 | `YOLO_CONCAT` | 同上 |
| MAXPOOL | 3 | 部署图类型名 `YOLO_POOL`，核 5×5、步长 1 | 同上 |
| UPSAMPLE | 2 | `YOLO_UPSAMPLE` | 同上 |
| 检测头 | 3 | `YOLO_HEAD`（三个输出头） | 同上 |
| 输入分辨率 | 320×320×3 | 第 0 号张量 c=3、h=320、w=320 | 同上 |
| 输出张量 | 索引 83、84、85 | `outputs: [83,84,85]` | 同上 |
| 类别名 | biodegradable / cardboard / glass / metal / paper / plastic | 六类物体标签，非四类垃圾标签；业务映射 0→厨余、1~5→可回收 | pangoriscv/docs/verification/yolo-technical-data.md；pangoriscv/evidence/records/validation_20261104/dataset/dataset_audit.json（`class_order`） |
| 模型 blob 长度 | 1,863,560 B | `blob_length` | memory_map.json |
| 模型 blob CRC32 | 977,952,093（0x3A4A5D5D） | `blob_crc32` | 同上 |
| 模型 blob SHA256 | 895909cff31974f11e0a6639f7f6a7cdcce55aacc3a673196fb0d1d9c85cb18a | `blob_sha256`，与上板实验一致 | 同上 |

## 7. 查不到证据的项目（不要写进文档）

| 项目 | 状态 | 说明 |
|---|---|---|
| ISA 指令测试通过数（20/21 或 21/21） | 无 evidence 原始日志 | 该口径只出现在 `pangoriscv/.workbuddy/memory/2026-10-21.md` 工作日志，指的是 `rtl/core` 下 V2 自研双发射核的实验门禁（单发射 21/21、双发射默认 20/21、case 21 需 lane0 控制转移时 lane1 也能提交），不是 `project/pds_native_120` 交付核的测试结果。交付核没有任何 ISA 逐条测试记录 |
| 流水线总级数 | 无 | 没有任何文件写"五级/六级流水"。只能核到 RTL 存在 `execute_ctrl0`~`execute_ctrl5` 六级执行控制寄存器，以及 `docs/architecture/module-area-plan.md` 提到 "execute control stage 2 / stage 4"。含取指、译码在内的总级数不要写 |
| I-Cache / D-Cache 容量（KB） | 无 | `profile.json` 只给了组数与路数（128×2 / 64×2），没有行宽。`rtl/core/core_config.vh` 里 `CFG_ICACHE_LINE_BYTES=64`、`CFG_DCACHE_LINE_BYTES=64`，按此可算出 16 KiB / 8 KiB，但该文件是 V1/V2 配置头，交付副本 `project/pds_native_120` 中不存在这些常量、也未引用，不能当作交付核证据 |
| BTB / GShare 容量 | 不确认 | `core_config.vh` 写 BTB 256 组 × 51 bit × 2 chunk、GShare 4096×8、history 12 bit，但同上原因只属 V1/V2 配置头。可写的只有"BTB、GShare、RAS 均启用"（`profile.json`）与 RAS 深度 4（RTL `ras_ptr` 2 bit） |
| 乘法器延迟 | 不确认 | 只有 `rtl/core/core_config.vh` 的 `CFG_MUL_LATENCY=2`（注释"输入寄存 1 拍 + 结果 1 拍"），交付核未引用该常量，交付包内无乘法器延迟的其它记录 |
| 板载 ILA 波形 / 99,976 个时钟上升沿 / 约 830 µs | 无 | `pangoriscv/README.md` §6 明确"ILA 波形未抓取"，包内无波形文件。`tmp/ila/` 下是 2026-11-04 的探测中间产物（`_selftest.csv` 为自造激励），不是上板采集证据。不要引用 ILA 边沿数、采集时长、`execute_ctrl0…4` 在线观测等说法 |
| STA "+0.036 ns" | 不存在 | 全仓证据文件中无此数值；不要引用。可引用的最小正裕量见第 1、4、5 节原始报告 |
| 实测最高时钟频率 | 无 | 未做时钟扫描。102.8066 MHz 是 STA 静态估算（`final_timing.rtr` 第 37 行），不是实测 |
| 各模块 LUT/FF 分解 | 无 | 无层级资源报告；`docs/architecture/module-area-plan.md` 明确禁止推测单模块面积 |
| CoreMark 区间指令退休数 / 双发射率 / 停顿原因分布 / Cache 命中率 / 分支预测准确率 | 无 | 交付固件 `--performance-counters=0`，无此类计数证据 |
| 四类垃圾识别准确率 / mAP / 纯 CPU 推理基线 | 无 | 模型是六类物体标签；实验会话无标注评测结果（`map50: null`）。18 张小样本 AP@0.5 32.78% 属另一组限定实验，不可外推为整机准确率 |
| v3 整机 FPS / 整机 CoreMark | 无 | v3 只有逐帧耗时（约 3.79~3.86 s/帧，含摄像头出图与模型前向），没有等价的"FPS 测试"原始记录；整机也未跑 CoreMark |
