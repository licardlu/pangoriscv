# 问题总表（2026-10-18 独立复核）

> 本文件是项目的**唯一问题登记处**。新发现问题先在这里加一行，再改代码/文档；修好后把状态改为 `FIXED`，附 commit 或证据路径。不要在多个文档里各写一份问题清单。
>
> - 详细审计与复现命令：`docs/verification/audit-2026-10-18.md`
> - 证据目录：`evidence/`（只放证据，不放结论）
> - 验证文档索引：`docs/verification/README.md`

## 0. 严重度与状态

| 级别 | 含义 |
|---|---|
| **P0 阻断** | 按赛题不能报分或不能提交 |
| **P1 高** | 影响成绩可比性、证据链、署名/许可 |
| **P2 中** | 影响功能/性能/可维护性，但不改变本次 CoreMark 数值 |
| **P3 低** | 文档、路径、工程卫生 |

状态：`OPEN` / `FIXED` / `NEED-BOARD`（缺物理板）/ `NEED-TOOLCHAIN`（缺赛题工具链）/ `WONTFIX`（须写理由）。

## 1. 当前权威数值（2026-10-18）

| 项 | 值 | 口径 |
|---|---|---|
| 迭代数 | 768 | `ITERATIONS=768`，`PERFORMANCE_RUN=1` |
| Total ticks | 287,211,317 | `mcycle`，1 tick = 1 个 27 MHz 周期 |
| 运行时间 | 10.6375 s | ticks / 27e6，满足 ≥10 s |
| CoreMark/MHz | **2.6740** | 768 × 1e6 / 287,211,317 |
| IPC | 0.7688 | 222,179,042 / 288,997,740 |
| 五项 CRC | `e9f5 / e714 / 1fd7 / 8e3a / 3c53` | `Correct operation validated` |
| 27 MHz 时序 | **+15.267 / +0.030 ns，0 / 54,345** | 独立 PDS 重跑；仓库文档另写 +15.404 / +0.025（未复现） |
| 50 MHz 过约束 | +0.862 / +0.087 ns，0 / 54,685 | 归档结果，本轮未重跑 |
| LUT | 13,574（synthesis）/ 13,444（device_map）/ **13,389（post-PnR）** | 三个阶段三个数，引用时必须写阶段 |
| 交付位流 | `F7B135AE…42F8D` | `bitstream/pangoriscv_i768.sbit`，实测 SHA 与登记一致 |
| 板上实测 | 仅 i400：400 迭代、320,541,251 ticks、GCC 7.1.1、crcfinal 0x25b5 | **不是**本表的 768/2.6740 |
| 优化链编译器 | xPack GCC **15.2.0** | 板上基线是 GCC **7.1.1** |

---

## 2. P0 · 阻断项（不做完不能按赛题报分）

| ID | 严重度 | 位置 | 问题与影响 | 修复/下一步 | 状态 |
|---|---|---|---|---|---|
| **C01** | P0 | `bitstream/README.md:95-98`、`docs/verification/handoff-2026-10-18-ifu-done.md:16`、`evidence/records/bottleneck_audit/results/board_uart_baseline.txt` | **没有 i768 位流的上板实测**。唯一真实上板记录是 i400 基线（400 迭代、GCC 7.1.1、ticks 320,541,251），不能代表 2.6740 这份 | 用 `pangoriscv_i768.sbit`（或重新生成）下载；串口抓完整 768 迭代；确认五项 CRC、`Correct operation validated`、≥10 s；保存原始串口日志与位流 SHA | **NEED-BOARD** |
| **C02** | P0 | `docs/verification/native-basic-final-status.md:38,77`、`docs/contest/README.md:24` | **ILA 波形 0 份**；赛题文档评分项明确要求抓 CoreMark 关键算法波形并分析流水线效率 | 用 PDS ILA 抓 list/matrix/state 任一窗口；保存波形图 + 触发条件/时间轴 + 流水线效率解读；写入性能分析文档 | **NEED-BOARD** |
| **C03** | P0 | 全仓库 | **应用场景 0 处**；赛题 §四.2 要求说明场景、整体资源/时序/主频；AI 类还要延迟与识别率 | 至少补一个真实场景（工控/采集/游戏机/图像加速等），写资源、时序、主频；若做 AI，补延迟与识别率 | **OPEN** |

---

## 3. P1 · 成绩可比性与证据链

| ID | 严重度 | 位置 | 问题与影响 | 修复/下一步 | 状态 |
|---|---|---|---|---|---|
| **C04** | P1 | `build/.../score768/manifest.json`、`toolchains/prefix-shim/`、板上 `GCC 7.1.1` | **工具链不是赛题工具链**。优化链全部 xPack GCC 15.2.0；`riscv32-unknown-elf-gcc.exe` 与 `riscv-none-elf-gcc.exe` 同 SHA256，只是改名。CoreMark 对 codegen 敏感，绝对分不能与板上 GCC 7.1.1 直接横比 | 用赛题 `riscv32-unknown-elf-gcc`（板上是 7.1.1）重编 768、重跑仿真/上板，重算分数；在文档披露 GCC 版本与 flags | **NEED-TOOLCHAIN** |
| **C05** | P1 | `bitstream/pangoriscv_i768.sbit`、`build/pango_native/` | **三项指标同源证据不足**。27 MHz 位流在本机没有对应 PDS 目录；`build/pango_native` 里是 50 MHz 的 `112E2AE4…`；找不到 27 MHz 的 `flow.log`/`report_timing/*.rtr` | 归档 27 MHz 那一份 PDS 的 `flow.log`、`report_timing/*.rtr`、`device_map` 资源表、`compile/run.log`，与 `F7B135AE…` 放同一目录 | **OPEN** |
| **C06** | P1 | `evidence/records/optimization/P16/timing_summary_27mhz.txt:8,16`、`P16/pds_27mhz_multiseed_summary.csv:19`、独立 `pds_my27.log` | **27 MHz 时序两套数**：文档 `+15.404/+0.025`，PDS 摘要 `+15.267/+0.030`，我独立重跑也是 `+15.267/+0.030`。两者都通过，但引用的 slack 不可复现 | 统一引用同一份 `report_timing` 的 `+15.267/+0.030`，或重新生成一份并归档；删掉不可复现的 `+15.404/+0.025` | **OPEN** |
| **C07** | P1 | `build/res_p16_work/synthesize/run.log:1523`、`P16/pds_27mhz_multiseed_summary.csv:19`、PDS 利用率表 | **LUT 阶段标错**：13,574 是 synthesis `Mapping Summary`，不是 device_map；device_map 13,444、后布线 13,389。`bitstream/README.md:57` 写“取自 device_map”不准确 | ③ 三选一并写清阶段；建议用后布线 13,389，或保守用 13,574 但注明“synthesis”，并统一 `0.1970 / 0.1997` 的换算 | **OPEN** |
| **C08** | P1 | `README.md:3`、`firmware/code/README.md:3`、`LICENSE:3`、`docs/design/change-notes/provenance.md:5,20-21` | **署名/许可证冲突**。README/LICENSE 声明“全部代码自主实现、MIT、作者 pango_lpenghan”；provenance 记录这是 tinyriscv 开发副本，并要求“不得声称完整 CPU 由本队新写、不得替换上游署名”。当前 9 个 core 模块确有 tinyriscv 基线路径 | 恢复上游 NOTICE/许可证，或取得书面授权；把“全部自主实现”改为“基于 tinyriscv 的重写/扩展”，列清自研模块；提交前做一次许可合规确认 | **OPEN** |
| **C09** | P1 | `.gitignore`、`build/native_software/.../manifest.json` | **manifest 未入库**（`build/` 被 ignore），交付镜像的编译命令/flags 不在提交物里 | 把 `manifest.json`、`program.hex`、`data.hex` 与位流一起归档到 `evidence/` 或 `bitstream/` | **OPEN** |
| **C10** | P1 | `platform/pango_native/*.fdc`、P16 文档 | **最高频率未测**。只证明 27 MHz 与 50 MHz 约束可过；50 MHz 是下界，不是“达到的最高频率” | 做 60/70/80 MHz 扫描并归档；报告里分开写“约束值 / 收敛实验值 / 实测值” | **OPEN** |
| **C11** | P1 | `tests/example/coremark/core_portme.h`（`HAS_FLOAT 0`）、串口输出 | **整数秒导致 `Iterations/Sec` 虚高**：打印 `Total time 10`、`Iterations/Sec 76`；真值是 10.6375 s、72.20 iter/s。用打印值算得 2.8444，比 2.6740 高 6.4% | 固件改为打印毫秒/定点秒，或加一行固件计算的 `CoreMark/MHz`；文档保留“必须用 ticks”的警告 | **OPEN** |
| **C12** | P1 | `evidence/records/bottleneck_audit/results/baseline_build.md:75` | 记录的 `board_uart_baseline.txt` SHA 为 `78B7D08D…`，实测文件是 `4F89E5D9…`，板上证据身份链断裂 | 重算并更正记录；今后板上日志生成后立即登记 SHA | **OPEN** |
| **C13** | P1 | `README.md:4`、`firmware/code/README.md:39-49` | 把 i400 的“板上实测”放在当前交付位置，读者会误以为 2.6740 已上板；且该表数字是旧版（1.35/12,694/F8254） | 在旧表前加“历史版本（i400，2026-10-13）”并链接到当前仿真结果；当前结果单列“RTL 仿真、未上板” | **OPEN** |
| **C14** | P1 | `P16/measurement.md:114`、`build/pango_native/run.log` | 50 MHz 的 `13,764 LUT` 只存在于本机 build 日志，`evidence/` 里没有对应资源报告 | 把 50 MHz 的 `device_map`/synthesis 资源表归档；或删除该数字 | **OPEN** |

### 3.1 口径说明（不是 bug，但必须写清）

- `crcfinal` **没有官方黄金表**：官方只强制比对 `crclist/crcmatrix/crcstate`；`seedcrc` 决定 `known_id`，`crcfinal` 是跨迭代累积值。说“五项全对”应写“五项数值与官方已知链/确定性链一致”。
- CoreMark 官方 `CoreMark 1.0 : <score>` 行因 `HAS_FLOAT 0` 不打印；分数必须由 ticks 换算，文档已提醒。
- `under-10s-rule=False` 不是“不满足 10 s”，是“没有打印 under-10s 错误”；建议改标签（见 D09）。

---

## 4. P2 · RTL 功能/性能缺陷

> 这些缺陷**不改变**本次 CoreMark 的 ticks（CoreMark 不访问越界数据区、不用 MMIO byte load），但影响 RV32I 精确异常、MMIO 语义、“2 路 LRU / 饱和计数器”的声称。修好后成绩可能略升。

| ID | 严重度 | 位置 | 问题与影响 | 修复/下一步 | 状态 |
|---|---|---|---|---|---|
| **R01** | P2-高 | `rtl/core/dcache_axi.v:39,369,448-464,496-501` | `early_q` 覆盖 `0x1000_0000..0x1FFF_FFFF`，但数据 RAM 只有 `0x1000_0000..0x1000_3FFF` 16 KiB。对该空洞的 store 在 W beat 回 OKAY，`ST_WR_DRAIN` 只失效行、不报 fault → **store access fault 丢失** | 把 `early_q` 限定到数据 RAM 窗口；或让 `ST_WR_DRAIN` 的 B 错误上报 fault；补 `store 0x1000_4000` 定向测试 | **OPEN** |
| **R02** | P2-高 | `rtl/core/dcache_axi.v:256,400-402`、`rtl/perips/axi_reg_slave.v:37-42` | MMIO 读固定 `ARSIZE=2` 且保留 byte/halfword 偏移；`legal_address` 要求 `size==2` 时 `addr[1:0]==0` → 对 MMIO 的 `lbu/lhu` 返回 SLVERR → **load access fault**。基线 `axi_data_engine` 用 `req_size` 是正常的 | 非缓存读改用 `req_size`；补 `lbu 0x30000001` 定向测试 | **OPEN** |
| **R03** | P2-中 | `rtl/core/dcache_axi.v:381-387,409-414` | 快命中（`rsp_ready=1`）直接回 `ST_IDLE`，LRU 只在 `ST_HIT` 更新；LSU 在 accept 拍通常 ready → 2 路 LRU 多数命中不更新，替换退化 | 在 `state<=IDLE` 分支也更新 `lru_mem`；补 fast-path 命中测试 | **OPEN** |
| **R04** | P2-中 | `rtl/core/branch_predictor.v:110-118` | `count==11` 且 taken 时被写成 `10`，不是饱和保持 `11`；长期 taken 的分支一次 not-taken 就掉到 01，多一次 misprediction | 改为“`count==11 && taken` 保持 11”；补 3 taken + 1 not-taken 的饱和测试 | **OPEN** |
| **R05** | P2-中 | `rtl/core/id.v:160-162` | `FENCE` 实现，`FENCE.I` 故意非法。若评委跑 `rv32ui-p-fence_i` 会 trap；自修改代码不支持 | 实现为 I-Cache invalidate + nop；或在文档明确“不支持 Zifencei”，不要静默 trap | **OPEN（已声明）** |
| **R06** | P3 | `rtl/core/dcache_axi.v:20-22,395` | 注释称“invalid ways are filled first”，实际 `fill_way_q<=lru_mem`，不优先填 invalid 路 | 按 I-Cache 的 `!valid0?0:!valid1?1:lru` 实现 | **OPEN** |
| **R07** | P3 | `rtl/core/dcache_axi.v:409-414,429-433` | `ST_HIT` 每拍无条件 `resp_q<=0`；refill 错误先置 `2'b10` 再进 `ST_HIT`，背压下错误码可能被清成 OKAY | 错误码保持到消费端 ready | **OPEN** |
| **R08** | P3 | `rtl/perips/axi_uart.v:57,107-110` | RX 无 overrun 标志，上一字节未读走时新字节覆盖 | 加 overrun 位与测试 | **OPEN** |
| **R09** | P3 | `rtl/core/ifu_axi.v:108-111` | 用 `=== 1'bx` 做 X 检测，综合可移植性风险；当前两端口都连，死分支 | 用常量/参数化条件替代 | **OPEN** |
| **R10** | P3 | `rtl/perips/axi_ram.v:99-101,160-166` | `write_good` 要求 `aw_len==0`，`WRITE_DRAIN` 不写内存 → burst write 路径实际不可用 | 实现 burst write 或显式拒绝并断言 | **OPEN** |
| **R11** | P3 | `rtl/perips/axi_uart.v:120-129` | UART TX 复位为低，上电到第一个 idle 拍可能被外部当 start bit | 复位为高 | **OPEN** |
| **R12** | P3 | `rtl/core/pangoriscv.v:144-145` | `trap_vector` 端口被忽略，实际用 CSR `mtvec` | 删除端口或显式接 `mtvec` | **OPEN** |
| **R13** | P3 | `rtl/core/ex.v:462-494` 与 `pangoriscv.v:57-60`/`div_adapter` | CSR 写/除法存在两套“事实来源” | 合并到单一模块 | **OPEN** |
| **R14** | P3 | `rtl/perips/perf_regs.v:218-243` | SNAP 复制同拍递增前的 `cnt`，可能少计 1 个事件 | 快照取下一拍值或加 1 | **OPEN** |
| **R15** | P3 | `rtl/perips/axi_timer.v:38-44` | `expire` 覆盖同拍 W1C | 明确 W1C 优先 | **OPEN** |
| **R16** | P2-中 | `rtl/core/soc_config.vh:34-36`、`platform/pango_native/build.tcl:99-122` | 仓库默认三开关**全关**；`build.tcl` 不会自动调用 `set_switches.py`。直接重建得到 baseline，不是交付 all-on；若镜像带 `PERF_DUMP`，baseline 未映射 `0x60002000`，读 perf 会 load fault | 在 `build.tcl` 里显式检查/切换三开关，或在 README 写死“先 `set_switches.py on`”；构建日志打印三开关状态 | **OPEN** |

---

## 5. P2/P3 · 文档与证据错误

| ID | 严重度 | 位置 | 问题 | 修复 | 状态 |
|---|---|---|---|---|---|
| **D01** | P2-高 | `README.md:4,13,15` | 根 README 仍写 400 次迭代、1.35/1.25、四级流水线；资源/时序/位流旧数（12,694 LUT、16.262 ns、`F8254F66…`）见 D02 | 刷新到 768/2.6740/三级，并注明“RTL 仿真、未上板”；资源/时序/位流统一引用当前交付值 | **OPEN** |
| **D02** | P2-高 | `firmware/code/README.md:18,43-49,95` | 仍写 1.35/1.25、400 迭代、12,694 LUT、16.262 ns、`F8254F66…` | 同 D01 | **OPEN** |
| **D03** | P2-高 | `platform/pango_native/README.md:114-135` | 仍写 200 迭代、0.305 CM/MHz、`CPM_TICKS` 输出 | 标“历史（audit round）”或刷新到当前 | **OPEN** |
| **D04** | P2-中 | `docs/verification/handoff-2026-10-18-ifu-done.md:96-112,162` | §3 仍写“交付跑分为什么是 512 迭代”、ticks 304,495,134、`pangoriscv_i512.sbit`，与 §1 的 768 矛盾 | 统一到 768，删 i512 残留 | **OPEN** |
| **D05** | P2-中 | 同文件 `:27` vs `P16/measurement.md:119-122` | 把 27 MHz 的种子尝试（11 通过、41 不收敛、23 三端点 −0.012）写成 50 MHz 的，且 `seed 11→−0.001` 与 P16 记录相反 | 按 P16 测量记录更正 | **OPEN** |
| **D06** | P2-中 | `evidence/records/bottleneck_audit/results/baseline_build.md:75` | UART 文本 SHA `78B7D08D…` 与实测 `4F89E5D9…` 不符 | 重算并更正 | **OPEN** |
| **D07** | P2-中 | `evidence/records/optimization/P16/VERIFICATION.md:57` | 声称“全仓复扫控制字符数为 0”，该行本身残留 2 个 U+0007（BEL） | 清控制字符并重跑扫描 | **OPEN** |
| **D08** | P2-中 | `bitstream/README.md:56-57`、`P16/measurement.md:113-118` | 27 MHz slack 15.404/0.025 与 PDS 摘要 15.267/0.030 不一致；LUT 13,574 标成 device_map | 统一引用同一份 `report_timing` + `device_map` | **OPEN** |
| **D09** | P2-中 | `evidence/records/optimization/P16/verify_rerun_768.txt`、`tools/run_fetch_ab.py:229` | `under-10s-rule=False` 容易被读成“不满足 10 s”；实际是“没有打印 under-10s 错误” | 改标签为 `over_10s=True` 或 `under_10s_error=False` | **OPEN** |
| **D10** | P3 | `P16/verify_rerun_768.txt` | UTF-16LE 编码，文本工具直接读会乱码 | 转 UTF-8 | **OPEN** |
| **D11** | P3 | `evidence/records/bottleneck_audit/board/*.tcl.out.txt` | 2 个 GBK 文件 | 转 UTF-8 或注明编码 | **OPEN** |
| **D12** | P3 | `docs/repo/LAYOUT.md:9-16` | 文件数/体积过期（实际约 12.5 MB、160+973 文件） | 更新 | **OPEN** |
| **D13** | P3 | `.githooks/pre-push` | 引用不存在的 `SCORE-STATUS.txt` | 补文件或改引用 | **OPEN** |
| **D14** | P3 | `evidence/records/optimization/ab-log.csv:2` | 引用被 gitignore 的 `evidence/records/coremark-sim-*` | 改引用到实际归档或注明“本地” | **OPEN** |
| **D15** | P3 | `README.md:61` | 说仓库约 5 MB，实际约 12.5 MB | 更新 | **OPEN** |
| **D16** | P3 | `docs/contest/intro-2026-10-18.md:32` | “768 次迭代、实测 10.64 秒”是仿真，不是实测 | 改为“仿真 10.64 s” | **OPEN** |
| **D17** | P3 | `rtl/core/soc_config.vh:30-32` | 注释说“build wrapper 传 -Defines”，实际是 `set_switches.py` 人工切换 | 改注释，指向脚本 | **OPEN** |
| **D18** | P3 | `platform/pango_native/README.md:158` | PDS 路径 `E:\donwload\...` 过期 | 改本机路径或环境变量 | **OPEN** |

---

## 6. P2/P3 · 工程与环境

| ID | 严重度 | 位置 | 问题 | 修复 | 状态 |
|---|---|---|---|---|---|
| **E01** | P2-中 | `firmware/code/.sim_runs/` | 本机该目录下若干 `isa-e2e-*` 子目录 ACL 不可读；`run_isa_e2e.py`/`run_unit_tests.py` 默认 `--out .sim_runs` 会 `PermissionError` | 清理/重建 `.sim_runs`；runner 默认改为可写 `build/` 或 `--out` 必填 | **OPEN** |
| **E02** | P2-中 | `sim/run_ram_tests.py`、`tools/run_isa_e2e.py`、`sim/run_unit_tests.py` | `tempfile.mkdtemp()` 在本机 Windows 沙箱下创建的子目录后续不可读 | 用显式 `mkdir` + 唯一后缀替代 `mkdtemp`（验证副本已这样跑通） | **OPEN** |
| **E03** | P2-中 | `tools/build_native_software.py:17-18` | `DEFAULT_TOOLS` 指向不存在的 `toolchains/openisa-1.0.0/...`，不传 `--toolchain-bin` 直接失败 | 默认改为 xPack 或先探测再报清晰错误 | **OPEN** |
| **E04** | P3 | `tools/run_coremark_ab.py:30`（`E:\donwload\win64`）vs `run_fetch_ab.py:31`（`D:\FPGA_Project\Modelism\win64`） | 两个 runner 的 ModelSim 默认路径不一致且一个过期 | 统一为环境变量/自动探测 | **OPEN** |
| **E05** | P3 | `tools/run_isa_e2e.py:19-22` | 工具链/ModelSim 默认路径过期（`E:\file\pango\...`） | 统一默认/要求显式传参 | **OPEN** |
| **E06** | P3 | `build/pango_27mhz/` | 留有“Cannot open program.hex”的空存储器失败构建与 sbit，容易被误当交付 | 删除或移到 `build/rejected/` 并加 README | **OPEN** |
| **E07** | P3 | `platform/pango_native/pds.log` | 旧 tinyriscv 路径日志，与当前工程无关 | 删除/归档 | **OPEN** |
| **E08** | P3 | `tools/run_isa_e2e.py` | `-f sim/native_axi_sources.f` 是相对路径，必须在 `firmware/code` 下运行，否则 `vlog` 找不到 `rtl/core/div.v` | 文档写清 cwd，或把 `-f` 展开为绝对路径 | **OPEN** |

---

## 7. 修复顺序与完成标准

### P0（先做，做完才能报①）
1. **C01 上板**：用 i768 位流跑 768 迭代；串口保存完整输出；确认 5 项 CRC、`Correct operation validated`、实际 ≥10 s；记录位流 SHA、板卡、串口参数、抓包时间。
2. **C02 ILA**：抓 CoreMark 关键算法窗口；保存波形图 + 触发条件 + 时间轴；写流水线效率分析（停顿、冲刷、退休节奏）。
3. **C03 场景**：选一个真实场景，写整体资源/时序/主频；AI 类补延迟与识别率。

**P0 完成判据**：`docs/verification/` 里出现“板上串口原始日志 + ILA 波形图 + 场景章节”，且串口 ticks/CRC 与 `C01` 登记值一致。

### P1（成绩可比性与证据链）
4. **C04** 用赛题 GCC 7.1.1 重编 768，重跑仿真/上板，重算分数与迭代数。
5. **C05/C06/C07** 归档 27 MHz PDS 全套；统一时序/LUT 引用；把 `F7B135AE…`、`+15.267/+0.030`、`13,389`（或 13,574，注明阶段）写进同一张表。
6. **C08** 处理署名/许可证；**C09** 归档 manifest；**C11** 修串口时间打印；**C12/C13/C14** 修证据链。

**P1 完成判据**：三项指标能从同一份 PDS 目录 + 同一份位流 + 同一份串口日志互相校对；文档不再出现 1.35/400/12,694/F8254 等旧数。

### P2（代码与文档）
7. **R01/R02** 修 D-Cache 两处功能缺陷，补定向测试；**R03/R04** 修 LRU/预测器；**R05** 决定 FENCE.I；**R16** 修构建开关。
8. **D01-D18** 刷新文档、修 SHA/编码/标签；**E01-E08** 修 runner 默认路径与 mkdtemp。

**P2 完成判据**：ISA 15/15 + RAM 40/40 + CoreMark 768 全过；`git grep` 不再命中 `1.35`/`F8254F66`/`i512` 等旧值（历史文档除外，需标注）。

---

## 8. 维护规则

1. 新问题先加 ID（`C` 合规 / `R` RTL / `D` 文档 / `E` 工程），写清位置、影响、修复、证据，再动代码。
2. 修好后状态改 `FIXED`，附 commit 或证据路径；不要删行，保留历史。
3. 每次跑分/位流/时序更新，同步改 §1 的权威数值，并在 `C05/C06/C07` 里更新出处。
4. 本表与 `docs/verification/audit-2026-10-18.md` 冲突时，以本表的“状态”为准；详细证据看 audit。
