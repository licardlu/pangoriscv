# 第三方评审答复与收口行动方案

- 被评审文档：`docs/verification/2026-10-18-cpu-problem-analysis-and-action-plan.md`（18,622 B，346 行）
- 本文性质：逐条核对评审的**正确性 / 错误 / 遗漏**，并给出可执行方案与验收门槛。供队长审阅。
- 本轮执行边界：**只读代码与文档、只做隔离实验；未改生产 RTL、未合并、未烧录、未重跑 PDS**。唯一临时改动（`isa_e2e.S` test7 改轮询）已恢复原文件，实验证据另行归档。
- 数据前提：T4 与 LSU 两轮优化的仿真/板测数据均来自 `evidence/records/bottleneck_audit/` 下对应实验结果树，生产交付树 `firmware/code` 与基线位流未动。

---

## 0. 结论摘要（先看这五句）

1. **评审大方向成立**：T4 与 LSU 两轮优化"数值有效，但验收/正式成绩/交付复现未闭环，应先收口"——这个判断是对的。
2. **评审最关键的一处修正也是对的**：我方原报告把 isa case 7 归因为"ID 级 CSR RAW 冒险"**是错的**（CSR 读实际在 EX 级），评审指出的接线事实全部与代码一致。但据此应得出的结论不是"RTL 有冒险、要加气泡/旁路"，而是**该测试用例本身写错了**——它要求 `mcycleh` 在紧邻下一条指令就读到进位值，这不是 RISC-V 架构保证的时序。已用隔离实验证明：只把该用例改成轮询，同一份候选 RTL 立即 PASS。
3. **10 秒规则与 ILA 是赛题硬性条款，必须补**。候选 400 迭代板测只有 8 s，当前 `1.766570 CoreMark/MHz` 只能算实验归一化吞吐。按实测每迭代周期，被测位流最少需要 **477 迭代**；建议正式跑分用 **600 迭代**。ILA 方面项目已有 18 个 `obs_*` 探针和触发配方，但**从未真正采集过波形**，需重新布线出带 ILA 位流。
4. **内部写握手是真实的契约缺口，不是当前已知故障**：静态上 W 先于请求确实会被握手掉，但当前集成路径（LSU launch 同拍发 req+W；dcache 等 inner ready 才接受并转发）不可能出现 W 先到。应补"契约文档 + 断言 + 负向测试"，而不是紧急改 RTL。
5. **交付复现链必须补**：`lsu_opt/src` 只有 5 个文件进 git，改后的 3 个 RTL 在 git 里**没有 patch 基线**（父提交中不存在这些实验文件）。需要生成 vs `frontend_opt/src` 的 patch + 重建脚本 + sha 身份链，并在干净树上验证重建结果。

---

## 1. 逐条核对：评审说了什么、对不对、证据是什么

判定图例：✅ 成立 ｜ 🟡 方向对但结论需修正 ｜ ❌ 不成立 ｜ ⚠️ 成立但被夸大/低估。

| # | 评审观点 | 判定 | 我方证据 | 最终结论 |
|---|---|---|---|---|
| 1.1 | 三版数据：B0 1.247172 / T4 1.428789 / LSU 1.766570；LSU 比 T4 吞吐 +23.64%、周期 −19.12% | ✅（数据本身） | `results/phase2_implementation.md` §6/§8 | 数据对，但 **+23.64% 是 1 迭代仿真归一化值**，不是板上成绩；板上 400 迭代 A/B 是吞吐 +41.65%、周期 −29.40%（见 §1.2） |
| 1.2 | 板上 400 迭代：基线 320,725,708 ticks / 11 s / 1.247172；候选 226,427,447 ticks / 8 s / 1.766570，且候选触发 10 s 规则 | ✅ | `results/phase2_implementation.md` §8；UART 原文 `evidence/records/bottleneck_audit/lsu_opt/board/cand_run{1,2}.txt` | 全部属实。候选板上确实打印 `ERROR! Must execute for at least 10 secs ...` 与 `Errors detected` |
| 1.3 | case 7 归因与代码不符：CSR 地址来自 EX `ei[31:20]`，ID 级 `csr_rdata_i` 接 0 | ✅ | `rtl/core/pangoriscv.v:141-148`（`.addr(ei[31:20])`、`.read_data(csr_old)`）、`:168-174`（`id u_id ... .csr_rdata_i(32'd0)`）、`:175-184`（`id_ex` 把 `dcr` 送入 EX `ecr`）、`:124`（`wdata=is_csr?csr_old:...`） | 评审对，我方原归因错；但"有冒险"不成立（见 §2.1） |
| 1.4 | 根因未定位，测试可能依赖旧版较慢时序；必须先逐拍波形与参考模型区分"测试错误 vs RTL 错误" | 🟡 | 隔离实验：`lsu_opt/g1_fix/isa_e2e.S.g1_poll_fix` + `lsu_opt/logs/g1fix_case7_run1.log` | 方向对；结论可更进一步：**测试错误**。轮询版 `case 7 PASS`、`SUMMARY 1 / 1 PASS`，未改任何 RTL |
| 1.5 | 不能无条件加气泡/旁路 | ✅ | 同上 | 同意；本方案不加任何气泡/旁路，只修测试与文档 |
| 1.6 | `axi_data_engine.v:100` 的 `w_ready` 在 WR_IDLE/WR_PREP 拉高，但 W 捕获在请求分支内；W 先到可能丢数据 | ✅（静态） | `rtl/core/axi_data_engine.v:100-101,148-172`；`rtl/core/dcache_axi.v:238-239,306-314,382-386` | 静态风险成立；当前集成不可达（见 §2.2）。定性为**契约/测试缺口**，非现场 bug |
| 1.7 | 正式跑分需 ≥10 s、建议 600/800 迭代、同镜像 A/B、保存 ELF/hex/位流/sha、≥2 次采集 | ✅ | 赛题 `docs/contest/contest-pages-10-11.txt:52-56`；`core_main.c:298-301` | 同意；补精确阈值（§4.2）与"位流内嵌镜像须重建"这一执行细节 |
| 1.8 | 交付复现链不闭合：生产树与实验树不同版；`git ls-files lsu_opt/src` 只有 5 个跟踪文件 | ✅ | `git ls-files evidence/records/bottleneck_audit/lsu_opt/src` = 5 个：`rtl/core/{axi_data_engine,dcache_axi,lsu_axi}.v`、`tb/phase2/tb_lsu_trace.sv`、`tb/unit/tb_lsu_axi.sv` | 属实，且比评审说的更严重：**改后 RTL 在父提交不存在，没有 patch 基线**，必须新生成 |
| 1.9 | 49.71 MHz 是工具估算非板测；不得只改 `CPU_FREQ_MHZ` 声称升频 | ✅ | `lsu_opt/pds/run4_seed2_hold200/report_timing/pangoriscv_top.rtr`（estimate）、`pango_native.fdc` 27 MHz | 同意；正式成绩固定 27 MHz，估算频率只作时序裕量指标 |
| 1.10 | 补 ILA：抓 PC/retire/redirect/队列/Cache 命中/LSU 状态/AXI 握手；带 ILA 需重跑后端、口径分开 | ✅ | `rtl/soc/pangoriscv_top.v:40-108`（18 个 `obs_*` 探针）；`platform/pango_native/README.md:228-276`（探针表+触发配方，明确 no capture yet） | 同意；已有探针但无波形，需插桩后重新布线，成绩口径单列 |
| 1.11 | 下一轮诊断清单、候选方案表、论文与阶段 A–G 门槛 | 🟡 | 见 §2.3、§6 | 清单可用；但优先级排序依据不足，且部分论文与"本轮改动"的相关性需要降级表述 |

---

## 2. 评审的错误 / 不准确之处（需要指出来，避免误导决策）

### 2.1 把 case 7 说成"可能依赖旧版慢时序"会掩盖真正的定性：这是测试缺陷

- 测试要求（`tests/isa_e2e/isa_e2e.S:186-196`）：`li x1,-1; csrw 0xb00,x1; csrrs x2,0xb80,x0; ...`，注释与判据都硬编码 `x2=1`（`tools/run_isa_e2e.py:335-344`）。
- RISC-V 架构**不保证**"写 `mcycle` 后紧邻的下一条 `csrrs` 就能读到对应进位"。计数器的更新/可见时序是实现定义的，依赖流水线级数与 CSR 读采样时刻。
- 反过来验证：同一份候选 RTL、同一个测试套件，case 6（背靠背 CSR 读写）PASS，说明 CSR 读通路本身没有 RAW 冒险；只有 case 7 这种"要求下一拍进位可见"的写法会 FAIL。
- 因此：**测试必须改**（不是可选项）。任何提高前端吞吐的优化都会把这条隐含时序依赖暴露出来，不改它，后续每一轮优化都会假 FAIL。
- 我方原报告"ID 级 CSR RAW 冒险"的措辞必须公开更正（见 §4.1 文档更正项）。

### 2.2 "W 先到可能丢数据"的风险等级被高估

- 静态通路成立（W 先到会被 `WR_IDLE` 的 `w_ready` 握手掉，没有请求可挂）。
- 但当前三个生产者都不可能让 W 先到：
  - LSU：候选 A 在 `launch` 同拍发 `req+w`（`lsu_axi.v` Rev1.1）；
  - legacy 路径：`REQUEST → WRITE_DATA`，请求先行；
  - dcache：`req_ready` 要求 `i_req_ready && i_w_ready` 才接受写，接受拍锁 W 并转发（`dcache_axi.v:238-239,306-314`），W 晚到走 inner `WR_PREP` + `ST_WR_RESP` 兜底捕获（`:382-386`）。
- 结论：**不存在现场丢数据故障**；真实问题是接口契约没写、没有断言、没有负向测试。处理方式见 §4.4。

### 2.3 两套口径不能混用，评审自己也有混用倾向

- 1 迭代仿真的 `−29.32%` / `+41.65%`（板上 400 迭代）是两种工作负载长度与位置（含启动/打印/长尾）的测量，不能相互校验。
- "LSU 相对 T4 +23.64%"（仿真）与"板上 +41.65%"（板测）不得放在同一张收益表里做结论；正式成绩只认板上 ≥10 s 的那一次。
- 建议所有对外表格强制两列：`证据类型（仿真/综合/布线/板测）` 与 `工作负载（1-iter/400-iter/600-iter）`。

### 2.4 迭代数建议缺少阈值推导

- 评审说"600/800 迭代"，方向对但没给下界。按实测：候选 566,069 拍/iter（226,427,447/400）、基线 801,814 拍/iter（320,725,708/400）；`time_in_secs` 是 `ticks/CPU_FREQ_HZ` 整数截断（`core_portme.c:53-57`），10 s 需要 **ticks ≥ 270,000,000**。
- 于是：候选位流 ≥477 迭代、基线位流 ≥337 迭代。600 迭代给安全余量（候选预测 ≈3.40 亿拍 ≈12.6 s，基线 ≈4.81 亿拍 ≈17.8 s）。
- 另有一个评审未提的关键执行细节：**位流内嵌 CoreMark 镜像**（PDS 编译日志必须出现两条 `Loading memory data from file`）。换成 600 迭代镜像就必须**重新综合布线两套位流**，不能用现有 400 迭代位流跑 600 迭代。

### 2.5 "git 里只有 5 个文件"要补上下文

- 5 个是 `lsu_opt/src` 的跟踪文件；`lsu_opt` 下另有 57 项证据/脚本/日志已跟踪。真正的问题不是"没提交源码"而是：**实验树 RTL 没有以 patch 形式相对基线提交**，父提交里没有这些文件，所以无法从 git 复原改动。
- 此外 `lsu_opt` 目录 281 MB（csv/adf/vm）未跟踪，需要归档策略。

---

## 3. 评审遗漏、但会影响验收的事项

1. **`sim/run_pipeline_tests.py:10` 的 13 源固定列表不含 `branch_predictor`**：宏全开时任何干净重建都会 `Module 'branch_predictor' is not defined` 假 FAIL。必须修 runner（或按宏动态追加源），否则"回归全绿"不可复现。
2. **板测环境风险**：本机 `cdt_js.exe` 有 ftdibus.sys 内核 bugcheck（0x139）前科；`cdt_cfg.exe` file-only Tcl 后不退出需超时杀进程；`run_flash.ps1 -Script` 只能传文件名（传绝对路径会被 `$PSScriptRoot` 二次拼接）；必须先开串口再下载（镜像只打印一次）。
3. **10 s 规则的双重含义**：不仅"跑够 10 s"，`Total time (secs)` 是 floor，9.999 s 也会 FAIL；UART 输出必须给 `CPM_TICKS hi/lo` 64 位行（已在 `core_portme.c:36-46` 实现）作为时长原始证据。
4. **换迭代数后 CRC 口径**：`crcfinal` 与迭代数相关；同镜像同迭代 A/B 必须五 CRC 逐项相同，跨迭代只作功能性对照，不能拿 CRC 当性能证据。
5. **带 ILA 位流是有代价的**：插桩会改资源/时序/布线，必须与"成绩位流"分开报告，且 ILA 深度不足以覆盖 10 s 全窗口，只能触发/分段采"关键算法区间"。
6. **历史文档已有错误待更正**（我方责任）：`results/phase1_test_acceptance.md`、`results/T4_frontend_results.md` §5、`results/phase2_implementation.md` §9 中 G1 的归因措辞。
7. **实验树与生产树版本漂移**：`lsu_opt/src` 的 `soc_config.vh` 是宏全开状态（BD9A…），生产树是宏注释态；交付时必须明确"哪棵树、哪些宏、哪个 commit"。

---

## 4. 行动方案

### 4.1 P0-1 修 G1（测试缺陷）并更正文档 —— 约 1 小时

**改动**
1. `tests/isa_e2e/isa_e2e.S` test7（`:186-196`）：保留"写 mcycle=0xffffffff → 观察回绕"的意图，改为轮询高半：
   ```
   li   x1, -1
   csrw 0xb00, x1          /* mcycle = 0xffffffff */
   1: csrrs x2, 0xb80, x0  /* mcycleh */
      beqz x2, 1b         /* 等待回绕进位可见 */
   csrrc x0, 0xb00, x1
   csrrs x3, 0xb00, x0
   ...
   ```
2. `tools/run_isa_e2e.py`：`Ref` 模型不建模计数器（`:281-293`），把 case 7 的检查明确成"轮询后最终值语义"，不要硬编码"下一条指令"；`special_checks`（`:335-344`）注释写清这是**最终值检查**，不是时序检查。
3. 文档更正：`results/phase1_test_acceptance.md`（G1 行）、`results/T4_frontend_results.md` §5、`results/phase2_implementation.md` §9，把"ID 级 CSR RAW 冒险"改为"原测试依赖 mcycle 写后下一指令可见的非架构时序；已改轮询，RTL 无需改动"。

**验收**
- 宏全开：`isa_e2e` 15/15；宏注释：15/15；`lsu_opt_verify` 第二棵树同样 15/15。
- 回归不受影响（只动测试与文档）。
- 证据：修复前后日志、hex/elf、sha。

### 4.2 P0-2 正式成绩（≥10 s）+ 两套位流重建 —— 约 1 天

1. 构建 600 迭代镜像：`tools/build_native_software.py coremark --mode performance --iterations 600`、`--mode validation --iterations 600`，记录 manifest、ELF/hex sha。
2. **重建两套位流**（基线树 `baseline_build`、候选实验树 `lsu_opt`）：PDS 流程不变（`+define+` 无效，必须在副本 `soc_config.vh` 开宏）；候选保持 hold 阈值 200 ps / 迭代 300 / `-gplace_seed 2 -groute_seed 2`；基线用原参数。校验每条编译日志 **两条** `Loading memory data from file`，记录 sbit sha 与资源/时序。
3. 仿真 A/B（1 迭代与 600 迭代各一组，同镜像）：记录 `AUDIT_INT`、`AUDIT_INT_CLASS`、`AUDIT_INT_LSU_PHASE`、五 CRC。
4. 板测：先开串口再下载，每种位流 ≥2 次采集；确认 `Correct operation validated`、无 `ERROR! Must execute for at least 10 secs`、五 CRC 一致、`CPM_TICKS hi/lo` 完整、两次输出逐字节相同。
5. 正式指标：`Score = iterations/(total_time_secs × 27e6)`；同时给 CoreMark/MHz、CoreMark/LUT（用各版 LUT）。

**验收**：两套位流 `All Constraints Met`；板上 ≥10 s 且无错误行；A/B 同镜像同迭代；五 CRC 逐项一致；每次采集有原始 UART 文件 + sha。

### 4.3 P0-3 交付复现链 —— 约 2 小时

1. 生成 patch：`git diff --no-index frontend_opt/src/rtl/core/<f>.v lsu_opt/src/rtl/core/<f>.v` → 3 个统一 diff 文件，落到 `results/patches/`。
2. 写 `REBUILD.md`：基础 commit（`80e39ce` 或 `f01c6ff`）、patch 顺序、宏状态、源列表（`sim/native_axi_sources.f`）、编译命令、镜像构建命令（含工具链路径）、PDS 环境变量/工作目录/hold 参数/种子、板测脚本与前置条件、工具版本（Fabric Compiler 2022.2-SP6.1 build 138931、ModelSim 10.6e、GCC 7.1.1）。
3. 身份链：每个产物（ELF/hex/bitstream/仿真日志/板测抓取）sha256 + 生成命令 + 输入 sha，一张表。
4. 干净重建验证：干净目录按 `REBUILD.md` 走一遍，至少 unit 套件 + CoreMark 仿真 A/B 与记录一致。
5. 归档策略：`lsu_opt` 281 MB 大文件（csv/adf/vm）打包压缩到外部/evidence 归档，git 只留小文本与 sha 清单。

### 4.4 P0-4 写握手契约（二选一，推荐 A） —— 约半天

- **方案 A（推荐，零 RTL 风险）**：把契约写清楚——"`w_valid` 必须与 `req_valid` 同拍或之后；请求被接受前 W 不被消费"。加断言（`w_valid && !req_pending` 时报错）与负向测试；数据保持寄存器不做。
- **方案 B（若要支持 W 先行）**：`axi_data_engine` 增加单深度 W 保持寄存器（最多 2 个 FF 控制 + 1 个数据寄存器），`w_ready` 只在能存储时拉高；需补 PDS 时序。
- 测试矩阵（engine 级）：W 与 req 同拍（当前仅被集成覆盖，必须补）、W 晚 1/3 随机拍（已有部分覆盖）、W 先行（负向：断言不消费/不丢）、W 单拍与多拍、B 延迟/SLVERR、load/store 混排、MMIO 路径、halt/reset。
- 验收：engine 64/64 全 PASS + 新增用例通过；dcache/LSU 集成套件 PASS。

### 4.5 P1 ILA 证据（赛题硬性）—— 2～3 天

1. 从 18 个 `obs_*` 探针选核心子集：PC/inst/retire、LSU 状态、icache/dcache 命中与 miss、AR/R/AW/W/B 握手、redirect/flush。
2. PDS 插桩（按 `platform/pango_native/README.md:228-276` 配方）+ 重新布线；输出带 ILA 位流并记录资源增量。
3. 采集策略：10 s 窗口远超 ILA 深度 → 用触发（如"进入 CoreMark 核心循环"）+ 分段/多次采集，拼"关键算法区间"。
4. 交付：波形截图 + VCD（或 csv 导出）+ 分析文字（流水线效率、停顿分布）；**成绩口径与带 ILA 位流分列**，不得混用。

### 4.6 P2 下一轮优化（需先重测，不在本方案内承诺）

优先级由新瓶颈实测决定，候选方向：AW/W 去气泡、分支恢复路径、Cache 参数（容量/相联/预取）、总线仲裁并发、关键路径/升频、写缓冲/非阻塞 Cache。每项都必须：契约测试 → 全回归 → 同镜像 A/B → PDS → 板测。**不做**：store buffer 提前退休、双发射、流水级重构（除非重新立项）。

### 4.7 P3 文档清理

更正历史报告 G1 措辞；`commands.md` 保持可复现；`results/` 表格统一"证据类型/负载"两列；归档 281 MB 实验目录。

---

## 5. 验收门槛（队长可否决/调整）

| 门槛 | 要求 |
|---|---|
| 仿真回归 | 11 套件 0 fail（宏注释态）；宏全开额外跑全源 pipeline、isa_e2e |
| isa_e2e | 宏全开 15/15、宏注释 15/15、两棵独立树一致 |
| 同镜像 A/B | 同一 program.hex/data.hex、同种子、同迭代；两棵树各自完整跑通 |
| CRC | 同镜像 A/B 五 CRC 逐项相同；`Correct operation validated`（板级） |
| 正式成绩 | 板上运行 ≥10 s（ticks ≥270,000,000），无 `ERROR!` 行，≥2 次采集逐字节一致 |
| PDS | `All Constraints Met`，记录 Setup/Hold（slow/fast）、资源四件套、sbit sha、两条 memory load |
| ILA | 至少 1 组关键区间波形 + 分析文字，位流与成绩位流分列 |
| 复现 | 干净目录按 `REBUILD.md` 重建，产物 sha 与记录一致 |

---

## 6. 与评审的"同意 / 不同意"清单（供队长快速裁决）

**同意并纳入 P0**：10 s 正式跑分、保存 ELF/hex/位流/sha、≥2 次采集、同镜像 A/B、交付复现链、时序口径、case 7 归因更正、写握手契约补强。

**同意但降级为 P1**：ILA 波形（赛题硬性，但需要重新布线与排期；不阻塞 P0 收口）。

**不同意/需修正**：
1. 不认为 case 7 是 RTL 冒险，**不因此改 RTL**（只改测试与文档）。
2. 不认为 W 先到是当前故障，**不做紧急 RTL 修复**（先契约+断言+负向测试）。
3. 不把仿真 1-iter 百分比（−29.32%/+23.64%）与板上 400-iter 百分比（−29.40%/+41.65%）混为一张收益表。
4. 不把 49.71 MHz 工具估算当板测频率，**不升频声称**。
5. 评审"下一轮诊断候选表"的方向可用，但优先级需由新一轮实测决定，**不在本轮承诺任何下一轮收益**。

---

## 7. 需要队长决策的三件事

1. **是否批准 P0 四件事按 4.1→4.4 顺序执行**（预计 2 天，无 RTL 风险，4.1/4.3 当天可完成）。
2. **正式成绩迭代数用 600 还是 800**（600 已满足 10 s 且板测时间可控；800 更稳但每次多约 4 s 板测时间与 RAM 余量，需确认镜像大小不超 BRAM 初始化上限）。
3. **ILA 是否本轮做**：若交期紧，P0 先收口，ILA 排 P1；若赛题评审必须看到波形，需尽早排布线资源。

---

## 附录 A：本次核对的关键证据文件

| 内容 | 路径 |
|---|---|
| 测试源码（case 7） | `evidence/records/bottleneck_audit/lsu_opt/src/tests/isa_e2e/isa_e2e.S:186-196`（sha256 `9DBFADFFD9EF6C7D347FB12C580211E438B160B4E969FC6BB614ABBB5256A9E8`） |
| 轮询修复实验版 | `evidence/records/bottleneck_audit/lsu_opt/g1_fix/isa_e2e.S.g1_poll_fix` |
| 修复实验日志 | `evidence/records/bottleneck_audit/lsu_opt/logs/g1fix_case7_run1.log`（`SUMMARY 1 / 1 PASS`） |
| 判据代码 | `evidence/records/bottleneck_audit/lsu_opt/src/tools/run_isa_e2e.py:281-293,335-344` |
| CSR 接线 | `evidence/records/bottleneck_audit/lsu_opt/src/rtl/core/pangoriscv.v:124,141-148,168-184` |
| 写握手 | `.../rtl/core/axi_data_engine.v:100-101,148-172`；`.../rtl/core/dcache_axi.v:238-239,306-314,382-386` |
| engine TB | `.../tb/axi/tb_axi_read_engine.sv:146-157`（request）、`:196`（write_one） |
| 10 s 规则 | `.../tests/example/coremark/core_main.c:298-301`；`.../core_portme.c:36-46,53-57` |
| 赛题条款 | `docs/contest/contest-pages-10-11.txt:36-44,52-56`（GBK 转码件） |
| ILA 探针 | `frontend_opt/src/rtl/soc/pangoriscv_top.v:40-108`；`frontend_opt/src/platform/pango_native/README.md:228-276` |
| 板上原始输出 | `.../lsu_opt/board/base_run{1,2}.txt`、`cand_run{1,2}.txt` |
| PDS 证据 | `.../lsu_opt/pds/run4_seed2_hold200/`（sbit sha256 `9B6742902FFF86A921FF8DF8585DA1C21F177D546D294970A84C74E4349C7CC0`） |
| 基线位流 | `baseline_build/artifacts/pangoriscv_i400_baseline_fullfeature.sbit`（sha256 `747C18CA32DEFD118E2237863FD7BDAC9C6DB1E110EE734F6CC485FAF68E6D77`） |
| 流水线 runner 缺陷 | `.../lsu_opt/src/sim/run_pipeline_tests.py:10` |

## 附录 B：复现命令（P0 用）

```powershell
# 0) 环境
$env:PATH = 'E:\donwload\win64;' + $env:PATH   # vlog/vsim
$AUDIT = 'E:\file\pango\project\evidence\records\bottleneck_audit'

# 1) 600 迭代镜像（两棵树各一份或共用同一份，镜像内容必须相同）
python tools/build_native_software.py coremark --mode performance --iterations 600 `
  --toolchain-bin E:\file\pango\toolchains\openisa-1.0.0\gcc\riscv32-unknown-elf-gcc\bin

# 2) isa_e2e（修复后，宏全开）
python tools/run_isa_e2e.py

# 3) PDS（示例：候选树；基线树同流程）
$env:PANGO_NATIVE_REPO  = "$AUDIT\lsu_opt\src"
$env:PANGO_NATIVE_BOARD_DIR = "$AUDIT\lsu_opt\src\platform"
$env:NATIVE_IMAGE_DIR   = "<600 迭代 performance 镜像目录>"
pds_shell -file build.tcl -work_dir "$AUDIT\lsu_opt\build\pango_native_600"

# 4) 上板（先开串口，再下载；-Script 只能传文件名）
pwsh -File board\capture_uart.ps1 -Port COM13 -Seconds 90 -Out board\base_600_run1.txt
pwsh -File board\run_flash.ps1 -Script 01b_program_only.tcl -Sbit <sbit> -TimeoutSec 180
```

---

*本文由实验数据与源码逐行核对得出；未做的项目均已标注"未做/待批准"。不预先承诺最终 CoreMark 数值。*
