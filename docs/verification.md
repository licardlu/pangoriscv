# 验证、问题与交接

> 本文件由 `docs/verification/` 下 9 份文档合并而成（2026-10-18），内容按原样保留。
> **要查未修的问题直接看 §2 问题台账**；要看独立复核发现了什么看 §3。

## 目录

1. §1 怎么读这一份
2. §2 问题台账（唯一登记处）
3. §3 独立复核报告（2026-10-18）
4. §4 交接：取指访存优化完成（2026-10-18）
5. §5 交接：优化阶段（2026-10-17）
6. §6 原生版基础状态
7. §7 原生软件构建
8. §8 外部验证计划
9. §9 参赛验证提示词

---

## §1 怎么读这一份

*原文件：`docs/verification.md`*

### 验证文档索引

> `docs/verification/` 是项目**验证状态、问题、交接**的唯一归档区。
> 证据（日志/报告/截图/位流）放 `evidence/`，结论和状态放这里；不要把结论散落在多个 README 里。

## 先看哪一篇

| 顺序 | 文档 | 内容 | 状态 |
|---|---|---|---|
| 1 | **[issue-register-2026-10-18.md](issue-register-2026-10-18.md)** | **问题总表**：P0 阻断、P1 成绩/证据、RTL 缺陷、文档错误、修复顺序 | **当前，唯一问题登记处** |
| 2 | [audit-2026-10-18.md](audit-2026-10-18.md) | 独立复核详细报告：复现命令、768 迭代结果、三项评分核对、逐条证据 | **当前** |
| 3 | [external-verification-plan.md](external-verification-plan.md) | 外部验证计划（历史） | 历史 |
| 4 | [native-basic-final-status.md](native-basic-final-status.md) | 基础版状态台账（2026-10-13），含板上/ILA `NOT RUN` | 历史，数值已过时 |
| 5 | [competition-verification-prompt.md](competition-verification-prompt.md) | 给验证 AI 的提示词 | 历史 |
| 6 | [handoff-2026-10-18-ifu-done.md](handoff-2026-10-18-ifu-done.md) | 2026-10-18 交接（P16 状态） | 历史，§3 仍有 512 残留 |
| 7 | [handoff-2026-10-17-optimization.md](handoff-2026-10-17-optimization.md) | 2026-10-17 交接 | 历史 |
| 8 | [NATIVE_SOFTWARE.md](NATIVE_SOFTWARE.md) | 原生固件构建说明 | 现行 |

## 当前一句话状态（2026-10-18）

- **跑分**：768 迭代、ticks 287,211,317、10.6375 s、**2.6740 CoreMark/MHz**、IPC 0.7688；已独立逐字段复现。
- **证据等级**：**RTL 周期精确仿真**；**未上板、无 ILA、无应用场景**。按赛题，① 还不能作为有效成绩。
- **时序/资源**：27 MHz 约束 `All Constraints Met`（PDS 摘要/独立重跑 +15.267/+0.030，0/54,345；文档另写 +15.404/+0.025）；后布线 LUT 13,389、FF 8,507。
- **工具链**：优化链是 xPack GCC 15.2.0；板上基线是 GCC 7.1.1，尚未统一。

## 写文档的约定

1. **新问题先写进 `issue-register`**，再改代码/文档；不要新建第二份问题清单。
2. 状态只用 `OPEN / FIXED / NEED-BOARD / NEED-TOOLCHAIN / WONTFIX`；`FIXED` 要附 commit 或证据路径。
3. 日期命名：`handoff-YYYY-MM-DD-*.md`、`audit-YYYY-MM-DD.md`；旧文档不要改历史结论，加“历史/已取代”标注。
4. 数字必须带口径：迭代数、ticks、秒、频率、LUT 阶段（synthesis/device_map/post-PnR）、是约束值还是实测值。
5. 板上证据必须同时记录：位流 SHA、板卡、串口参数、抓包时间、原始日志路径。

## 相关入口

- 赛题原文与要求：`docs/contest/`
- 计划书与优化路线：`docs/design/plans/`
- 实施记录：`docs/design/change-notes/`
- 证据：`evidence/logs/`、`evidence/records/`
- 位流：`bitstream/`
- 项目索引：`docs/repo/PROJECT_INDEX.md`

---

## §2 问题台账（唯一登记处）

*原文件：`docs/verification.md`*

### 问题总表（2026-10-18 独立复核）

> 本文件是项目的**唯一问题登记处**。新发现问题先在这里加一行，再改代码/文档；修好后把状态改为 `FIXED`，附 commit 或证据路径。不要在多个文档里各写一份问题清单。
>
> - 详细审计与复现命令：`docs/verification.md`
> - 证据目录：`evidence/`（只放证据，不放结论）
> - 验证文档索引：`docs/verification.md`

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
| **C01** | P0 | `bitstream/README.md:95-98`、`docs/verification.md:16`、`evidence/records/bottleneck_audit/results/board_uart_baseline.txt` | **没有 i768 位流的上板实测**。唯一真实上板记录是 i400 基线（400 迭代、GCC 7.1.1、ticks 320,541,251），不能代表 2.6740 这份 | 用 `pangoriscv_i768.sbit`（或重新生成）下载；串口抓完整 768 迭代；确认五项 CRC、`Correct operation validated`、≥10 s；保存原始串口日志与位流 SHA | **NEED-BOARD** |
| **C02** | P0 | `docs/verification.md:38,77`、`docs/contest/README.md:24` | **ILA 波形 0 份**；赛题文档评分项明确要求抓 CoreMark 关键算法波形并分析流水线效率 | 用 PDS ILA 抓 list/matrix/state 任一窗口；保存波形图 + 触发条件/时间轴 + 流水线效率解读；写入性能分析文档 | **NEED-BOARD** |
| **C03** | P0 | 全仓库 | **应用场景 0 处**；赛题 §四.2 要求说明场景、整体资源/时序/主频；AI 类还要延迟与识别率 | 至少补一个真实场景（工控/采集/游戏机/图像加速等），写资源、时序、主频；若做 AI，补延迟与识别率 | **OPEN** |

---

## 3. P1 · 成绩可比性与证据链

| ID | 严重度 | 位置 | 问题与影响 | 修复/下一步 | 状态 |
|---|---|---|---|---|---|
| **C04** | P1 | `build/.../score768/manifest.json`、`toolchains/prefix-shim/`、板上 `GCC 7.1.1` | **工具链不是赛题工具链**。优化链全部 xPack GCC 15.2.0；`riscv32-unknown-elf-gcc.exe` 与 `riscv-none-elf-gcc.exe` 同 SHA256，只是改名。CoreMark 对 codegen 敏感，绝对分不能与板上 GCC 7.1.1 直接横比 | 用赛题 `riscv32-unknown-elf-gcc`（板上是 7.1.1）重编 768、重跑仿真/上板，重算分数；在文档披露 GCC 版本与 flags | **NEED-TOOLCHAIN** |
| **C05** | P1 | `bitstream/pangoriscv_i768.sbit`、`build/pango_native/` | **三项指标同源证据不足**。27 MHz 位流在本机没有对应 PDS 目录；`build/pango_native` 里是 50 MHz 的 `112E2AE4…`；找不到 27 MHz 的 `flow.log`/`report_timing/*.rtr` | 归档 27 MHz 那一份 PDS 的 `flow.log`、`report_timing/*.rtr`、`device_map` 资源表、`compile/run.log`，与 `F7B135AE…` 放同一目录 | **OPEN** |
| **C06** | P1 | `evidence/records/optimization/P16/timing_summary_27mhz.txt:8,16`、`P16/pds_27mhz_multiseed_summary.csv:19`、独立 `pds_my27.log` | **27 MHz 时序两套数**：文档 `+15.404/+0.025`，PDS 摘要 `+15.267/+0.030`，我独立重跑也是 `+15.267/+0.030`。两者都通过，但引用的 slack 不可复现 | 统一引用同一份 `report_timing` 的 `+15.267/+0.030`，或重新生成一份并归档；删掉不可复现的 `+15.404/+0.025` | **OPEN** |
| **C07** | P1 | `build/res_p16_work/synthesize/run.log:1523`、`P16/pds_27mhz_multiseed_summary.csv:19`、PDS 利用率表 | **LUT 阶段标错**：13,574 是 synthesis `Mapping Summary`，不是 device_map；device_map 13,444、后布线 13,389。`bitstream/README.md:57` 写“取自 device_map”不准确 | ③ 三选一并写清阶段；建议用后布线 13,389，或保守用 13,574 但注明“synthesis”，并统一 `0.1970 / 0.1997` 的换算 | **OPEN** |
| **C08** | P1 | `README.md:3`、`firmware/code/README.md:3`、`LICENSE:3`、`docs/design.md:5,20-21` | **署名/许可证冲突**。README/LICENSE 声明“全部代码自主实现、MIT、作者 pango_lpenghan”；provenance 记录这是 tinyriscv 开发副本，并要求“不得声称完整 CPU 由本队新写、不得替换上游署名”。当前 9 个 core 模块确有 tinyriscv 基线路径 | 恢复上游 NOTICE/许可证，或取得书面授权；把“全部自主实现”改为“基于 tinyriscv 的重写/扩展”，列清自研模块；提交前做一次许可合规确认 | **OPEN** |
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
| **D04** | P2-中 | `docs/verification.md:96-112,162` | §3 仍写“交付跑分为什么是 512 迭代”、ticks 304,495,134、`pangoriscv_i512.sbit`，与 §1 的 768 矛盾 | 统一到 768，删 i512 残留 | **OPEN** |
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
4. 本表与 `docs/verification.md` 冲突时，以本表的“状态”为准；详细证据看 audit。

---

## §3 独立复核报告（2026-10-18）

*原文件：`docs/verification.md`*

### pangoriscv 独立复核报告

- 日期：2026-10-18
- 对象：`D:\FPGA_Project\zi_guang_tong_chuang\pangoriscv`（HEAD `b1541f7`，工作树干净）
- 方法：从源码独立重建固件 → 独立编译 RTL → 独立跑 768 迭代 CoreMark → 独立跑 ISA/RAM 回归 → 独立跑 PDS 27 MHz 实现；再逐条对照赛题硬性要求与评分口径。
- 本报告只写可复核的事实；所有路径均相对 `pangoriscv/`，独立复现产物在 `D:\FPGA_Project\zi_guang_tong_chuang\_verify_indep\`。

---

## 0. 结论（先看这一段）

**仿真跑分是真的、可复现的；但按赛题口径它不是有效成绩。**

1. **2.6740 CoreMark/MHz 复现成功，且是逐字段复现。** 我独立重建的 768 迭代固件与归档镜像 `program.hex`/`data.hex`/`coremark.elf` **SHA256 完全相同**；独立重跑 768 迭代仿真得到：
   - `Total ticks 287,211,317`、`cycles 288,997,740`、`retires 222,179,042`、IPC **0.7688**
   - `seedcrc 0xe9f5`、`crclist 0xe714`、`crcmatrix 0x1fd7`、`crcstate 0x8e3a`、`crcfinal 0x3c53`
   - `Correct operation validated`、`traps=0 faults=0`、`Errors: 0 Warnings: 0`
   - 换算：`768 / 287,211,317 × 1e6 = 2.6740 CoreMark/MHz`；`287,211,317 / 27e6 = 10.6375 s`
2. **但它不是赛题要求的“板上实测”。** 仓库里没有 768 迭代位流的串口实物输出，没有 ILA 波形，也没有应用场景章节；`bitstream/README.md` 与交接文档自己都写明“来自 RTL 仿真，不是板上实测，不得作为提交成绩”。
3. **三项指标同源证据不完整。** 交付位流 `F7B135AE…` 在其 27 MHz PDS 运行目录里不存在（`build/pango_native` 里是 50 MHz 那份 `112E2AE4…`）；27 MHz 时序只有一份 76 行摘要，且摘要里的 `+15.404/+0.025` 与同目录 PDS 摘要 `+15.267/+0.030` 不一致。我独立重跑 27 MHz PDS 得到 `+15.267/+0.030`，与后者一致。
4. **工具链不是赛题工具链。** 所有优化后镜像都由 xPack `riscv-none-elf-gcc 15.2.0` 生成（`riscv32-unknown-elf-gcc.exe` 只是同哈希改名）；板上基线用的是 `GCC 7.1.1 20170509`。绝对分数没有在赛题工具链上复测。
5. **代码署名/许可证存在硬冲突。** `README.md`/`LICENSE` 声明“全部代码自主实现、MIT、作者 pango_lpenghan”，但 `docs/design.md:5,20-21` 明确记录这是 tinyriscv 的开发副本，并要求“不得声称完整 CPU 由本队新写、不得替换上游署名”。当前 9 个 core 模块确有 tinyriscv 基线路径（`ctrl/defines/div/ex/id/id_ex/if_id/pc_reg/regs`），全部文件头却已换成 pango_lpenghan。
6. **另有 2 个真实 RTL 功能缺陷、2 个性能缺陷**（不影响本次 CoreMark 的 ticks，但影响 RV32I 精确异常/本地总线语义）：D-Cache 对 `0x1000_4000..0x1FFF_FFFF` 的 store 提前返回 OKAY 并吞掉 DECERR；MMIO 的 byte/halfword 读固定 `ARSIZE=2` 会触发 SLVERR。详见 §5。

**最短补齐顺序**：上板跑 i768 + 抓 ILA + 补应用场景 →（用赛题 GCC 7.1.1）复测分数并重算迭代数 → 归档同一份 PDS 的 log/时序/资源 → 修文档与 RTL 缺陷。

---

## 1. 独立复现：我实际做了什么

### 1.1 环境

| 项 | 本机实际 | 赛题要求 | 判定 |
|---|---|---|---|
| 仿真器 | ModelSim SE-64 10.6e（`D:\FPGA_Project\Modelism\win64`） | 未指定 | 可用 |
| 实现工具 | PDS 2022.2-SP6.1（`pds\PDS_2022.2-SP6.1\bin\pds_shell.exe`） | 紫光同创 PDS | 可用 |
| 编译器 | xPack `riscv-none-elf-gcc 15.2.0`；`toolchains/xpack-.../bin/riscv32-unknown-elf-gcc.exe` 与 `riscv-none-elf-gcc.exe` **同 SHA256**（`9FD3AECD…`） | `riscv32-unknown-elf-gcc` | **名义满足、实质不是赛题分发的工具链** |
| 板上基线编译器 | `GCC 7.1.1 20170509`（OpenISA 工具链） | 同上 | 与优化后镜像不是同一编译器 |

`toolchains/prefix-shim/` 下 9 个 `riscv32-unknown-elf-*` 与 xPack 同名文件逐字节相同，是改名/副本，不是另一套工具链。

### 1.2 固件：从源码重建，与归档逐字节一致

```powershell
python tools/build_native_software.py coremark --mode performance --iterations 768 `
  --cpu-mhz 27 `
  --toolchain-bin "D:\FPGA_Project\zi_guang_tong_chuang\toolchains\xpack-riscv-none-elf-gcc-15.2.0-1\bin" `
  --extra-flag=-march=rv32im_zicsr --tag indep_verify
```

| 文件 | 与归档 `build/native_software/coremark/performance/score768` |
|---|---|
| `program.hex` | **IDENTICAL**（`B7F3A3B3…`） |
| `data.hex` | **IDENTICAL**（`BD65652F…`） |
| `program.bin` | **IDENTICAL**（`A59BDDEC…`） |
| `coremark.elf` | **IDENTICAL**（`01F6887F…`） |

ELF 属性（`readelf -h/-A`）：

- `Class: ELF32`、`Machine: RISC-V`、`Entry: 0x0`、`Flags: 0x0`（**无压缩指令**）
- `Tag_RISCV_arch: "rv32i2p1_m2p0_zicsr2p0_zmmul1p0"`
- `text 13,324 + data 2,680`（16 KiB 镜像仅余约 380 B）
- 迭代数 `ITERATIONS=768`，`-O2`，`PERFORMANCE_RUN=1`

CoreMark 本体合规：`tests/example/coremark/` 下 `core_list_join.c`、`core_main.c`、`core_matrix.c`、`core_state.c`、`core_util.c`、`coremark.h`、`LICENSE.md` 与官方 `coremark-1.01` **逐字节相同**；只有 `core_portme.c/.h`、`ee_printf.c` 是移植层。

### 1.3 RTL：独立目录、全功能开关、0 error / 0 warning

把 `rtl/tb/sim/tests/tools/platform` 复制到 `_verify_indep/code`，执行 `tools/set_switches.py on`（`CACHE_ENABLE`/`PREDICT_ENABLE`/`PERF_ENABLE` 全开），再用 ModelSim 编译：

```
vlog -sv -work work +incdir+rtl/core +incdir+rtl/bus +incdir+rtl/perips +incdir+rtl/soc \
     +incdir+tb +incdir+tb/integration -f sim/native_axi_sources.f tb/integration/tb_coremark_uart.sv
```

结果：**Errors: 0, Warnings: 0**。

### 1.4 768 迭代独立仿真：逐字段与归档一致

```
vsim -c -do "run -all; quit -f" work.tb_coremark_uart \
  +PROG=<indep_verify>\program.hex +DATA=<indep_verify>\data.hex +MAX_CYCLES=600000000
```

| 项 | 归档 `score768` | 本次独立重跑 | 一致 |
|---|---|---|---|
| `Total ticks` | 287,211,317 | **287,211,317** | ✔ |
| `cycles` | 288,997,740 | **288,997,740** | ✔ |
| `retires` | 222,179,042 | **222,179,042** | ✔ |
| IPC | 0.7688 | **0.7688** | ✔ |
| `seedcrc` | 0xe9f5 | **0xe9f5** | ✔ |
| `[0]crclist` | 0xe714 | **0xe714** | ✔ |
| `[0]crcmatrix` | 0x1fd7 | **0x1fd7** | ✔ |
| `[0]crcstate` | 0x8e3a | **0x8e3a** | ✔ |
| `[0]crcfinal` | 0x3c53 | **0x3c53** | ✔ |
| `Correct operation validated` | 是 | **是** | ✔ |
| traps / faults | 0 / 0 | **0 / 0** | ✔ |
| 仿真错误/警告 | 0 / 0 | **0 / 0** | ✔ |

仿真耗时 34 分 45 秒（与仓库归档的 33.4 分钟同量级）。产物：`_verify_indep/run768/transcript.txt`。

### 1.5 交叉验证

| 检查 | 结果 | 位置 |
|---|---|---|
| 20 迭代独立镜像 | ticks `7,481,200` → **2.6733 CM/MHz**，CRC 链正确 | `_verify_indep/run20/transcript.txt` |
| ISA 端到端（15 项，含 ALU/load-use/M 扩展/分支/CSR/mcycle/ECALL/MRET/非法指令/load-store fault/UART/GPIO/timer/中断） | **15/15 PASS** | `_verify_indep/isa_runs3/` |
| RAM/LSU 随机回归（20 seeds × 2） | **40/40 PASS** | `_verify_indep/code/.sim_runs/` |
| 独立 PDS 27 MHz 全流程 | **All Constraints Met**；setup **+15.267 ns**、hold **+0.030 ns**、**0 / 54,345** 失败端点；后布线 LUT **13,389**、FF **8,507**；时钟 37.037 ns；工具按余量推算 **45.93 MHz** | `_verify_indep/code/build/pango_native/pds_my27.log`、`report_timing/pangoriscv_top.rtr` |

> 说明：20 迭代的 `7,481,200` 与文档里的 `7,478,647` 差 0.03%，因为归档 A/B 用的是带 `-DPERF_DUMP` 的 `perf_on` 镜像；交付 768 镜像逐字节相同，所以 768 结果是精确复现。

> PDS 的 hold fixer 日志出现 `Hold violation fix failed`，是指“没有把余量修到 500 ps 目标”，不是时序失败：最终 WHS 仍为 **+0.030 ns**、0 失败端点，`report_timing` 为 `All Constraints Met`。

---

## 2. 跑分计算与口径

赛题公式：`Score = Iterations / (Total_Time × Frequency)`，即 CoreMark/MHz。

```
Iterations = 768
Total ticks = 287,211,317（mcycle，1 tick = 1 个 27 MHz 周期）
Total_Time = 287,211,317 / 27,000,000 = 10.6375 s
CoreMark/MHz = 768 / (10.6375 × 27) = 2.6740
等价的整数算法 = 768 × 1e6 / 287,211,317 = 2.6740
IPC = 222,179,042 / 288,997,740 = 0.7688
27 MHz 下绝对分 = 768 / 10.6375 = 72.20 iterations/s
```

### 2.1 必须注意的两个口径坑

1. **固件打印的 `Total time (secs): 10` 与 `Iterations/Sec: 76` 是整数截断，不能用来反推分数。**
   `core_portme.h` 里 `HAS_FLOAT 0`，`time_in_secs()` 做整数除法：`10.6375 → 10`，`768/10 = 76`。
   若用打印值算：`768/(10×27) = 2.8444`，比真值高 **6.4%**。
   仓库文档已多次提醒“必须用 ticks”，但**串口原始输出本身仍然会误导评委**（见 §6）。建议固件直接打印毫秒/定点秒，或打印一行 `CoreMark/MHz = 2.6740`。
2. **`crcfinal` 没有官方黄金表。** 官方只强制比对 `crclist/crcmatrix/crcstate` 三项；`seedcrc` 决定 `known_id`（0xe9f5 → 2K performance），`crcfinal` 是跨迭代累积值，随迭代数变化（20→0x4983、768→0x3c53）。说“五项全部正确”应理解为“五项数值与官方已知链/确定性链一致”，而不是五项都有独立黄金值。

### 2.2 运行时间 ≥10 s

`287,211,317 / 27e6 = 10.6375 s`，满足 ≥10 s；迭代下限 `ceil(10.5×27e6/373,932) = 759`，取 768，留 6.4% 余量。**若改用赛题 GCC 7.1.1 后每迭代 ticks 变化，必须重算**。

---

## 3. 三项评分指标核对

| 指标 | 仓库声称 | 我的独立核对 | 判定 |
|---|---|---|---|
| ① 执行效率 | **2.6740 CoreMark/MHz**（768 迭代，10.64 s） | 完全复现：ticks 287,211,317、CRC 全对、10.6375 s、2.6740 | **数值真实；但只是仿真，按赛题不能作为①报分** |
| ② 时钟频率 | 27 MHz 约束 All Constraints Met（+15.404/+0.025，0/54,345）；50 MHz 过约束也 Met（+0.862/+0.087，0/54,685） | 独立 27 MHz PDS：All Constraints Met，**+15.267/+0.030，0/54,345**；50 MHz 未重跑，引用归档 | **27 MHz 约束确实收敛；但引用的 +15.404/+0.025 与同目录 PDS 摘要 +15.267/+0.030 不一致，且没有“最高频率”扫描** |
| ③ 资源效率 | 0.1970 CoreMark/kLUT（LUT 13,574，取自 device_map） | 独立 PDS 后布线 LUT **13,389**；归档 multiseed device_map **13,444**；13,574 是 synthesis Mapping Summary | **13,574 不是 device_map 数；口径标错。用 13,574 算是保守值（0.1970），用后布线 13,389 是 0.1997** |

### 3.1 “同一份实现”核对

- `bitstream/pangoriscv_i768.sbit` 实测 SHA256 = `F7B135AE975CCDE775D5B046AFC06BF7BE0EC5D3309996B0E36EEF471BA42F8D`，与 `bitstream/README.md:17`、`P16/measurement.md:118` 登记值**一致**。
- 但该 27 MHz 位流在本机**没有任何对应构建目录**：
  - `build/pango_native` 里的 sbit 是 `112E2AE4…`（= P16 的 50 MHz 那份）；
  - `build/pango_27mhz` 里的 sbit 是 `65BC9C07…`，且该次日志有 `Cannot open specified data file "program.hex"`（空存储器失败构建，已作废）；
  - 全仓库找不到 27 MHz 的 `report_timing/*.rtr` 或 PDS `flow.log`，只有 76 行摘要 `P16/timing_summary_27mhz.txt`。
- 因此“位流 + 13,574 LUT + 27 MHz 时序”三者同源**无法从仓库自证**；只能依赖作者的声明。评分要求“互相对上”，这是实质缺口。

### 3.2 频率口径

- 27 MHz = 板载晶振约束（`pango_native.fdc` 的 `create_clock -period 37.037`），**不是实测最高频率**；文档对此标注正确。
- 50 MHz = `pango_native_50mhz_overconstraint.fdc` 的过约束实验，文档明确写“不是板上实测最高频率”，这点没混称。
- 但赛题②问的是“能达到的最高工作频率”。目前只证明 50 MHz 约束可过（下界），**没有 60/70/80 MHz 扫描**，也没有板上实测。写法上应明确“50 MHz 为约束收敛下界，最高频率未测”。
- 我独立的 27 MHz 实现按 setup 余量推算 fmax ≈ **45.93 MHz**；归档 50 MHz 实现按余量推算 ≈ **50.9 MHz**。两个数都是工具推算，不是实测，不能当选“最高频率”。

---

## 4. 赛题合规缺口（按严重度）

### P0 · 会直接导致①作废

| # | 缺口 | 证据 | 赛题条款 |
|---|---|---|---|
| 1 | **没有 i768 位流的上板实测**。仓库里唯一真实上板记录是 i400 基线（400 迭代、ticks 320,541,251、GCC 7.1.1、crcfinal 0x25b5），不是 2.6740 这份 | `evidence/records/bottleneck_audit/results/board_uart_baseline.txt`、`board_uart_delivered_bitstream.txt`；`bitstream/README.md:95-98`；`docs/verification.md:16` | §二/§三.1/§五.1；“分数必须来自 FPGA 上真实运行，仿真数据不能替代实测” |
| 2 | **ILA 波形 0 份**。全仓库无 `.vcd/.wlf/.fsdb` 或波形图；`native-basic-final-status.md:38,77` 与 `docs/contest/README.md:24` 均 NOT RUN | 同上 | §四.3(2)：用 ILA 抓 CoreMark 关键算法波形分析流水线效率 |
| 3 | **应用场景 0 处**。只有计划书里的 YOLO/DDR 任务卡，没有实现、没有资源/时序/主频、没有延迟/识别率 | `docs/design/plans/...:103,114-116`；全仓库无场景章节 | §四.2 |

### P1 · 影响成绩可比性/证据可信度

| # | 缺口 | 证据 | 影响 |
|---|---|---|---|
| 4 | **工具链不是赛题工具链**：优化链全部用 xPack GCC 15.2.0；板上基线用 GCC 7.1.1。`riscv32-unknown-elf-gcc` 只是同哈希改名 | `toolchains/xpack-.../bin`、`toolchains/prefix-shim`；`build/.../score768/manifest.json` 的 `compiler` 写的是 `riscv-none-elf-gcc.exe … 15.2.0` | CoreMark 对 codegen 敏感；绝对分不能与板上 GCC 7.1.1 基线直接横比。需用赛题工具链复测 |
| 5 | **三项指标同源证据不完整**（见 §3.1） | 27 MHz sbit 无 PDS 目录/原始报告 | ②③ 的“同一份实现”无法自证 |
| 6 | **27 MHz 时序两套数**：文档 `+15.404/+0.025`，同目录 PDS 摘要 `+15.267/+0.030`，我独立重跑 `+15.267/+0.030` | `P16/timing_summary_27mhz.txt:8,16`；`P16/pds_27mhz_multiseed_summary.csv`；我的 `pds_my27.log` | 引用的 slack 不可复现（虽然两者都通过） |
| 7 | **LUT 出处误标**：13,574 是 synthesis `Mapping Summary`，不是 device_map；device_map 13,444、后布线 13,389 | `build/res_p16_work/synthesize/run.log:1523`；`P16/pds_27mhz_multiseed_summary.csv:19`；我的 PDS 利用率表 | ③ 的 LUT 口径不清；13,574 偏保守 1.4% |
| 8 | **署名/许可证冲突**：README/LICENSE 声明全部自主 MIT；provenance.md 记录是 tinyriscv 开发副本、不得声称新写/替换上游署名；9 个 core 模块来自基线路径 | `README.md:3`、`LICENSE:3`、`firmware/code/README.md:3`；`docs/design.md:5,20-21`；基线 CSV 的 `rtl/core/*.v` | 诚信与许可证风险；Apache-2.0 基线被替换成 MIT，需法律/赛规确认 |
| 9 | **`manifest.json` 未入库**（`build/` 被 ignore），交付镜像的编译命令/flags 不在提交物里 | `.gitignore`；`build/native_software/.../manifest.json` | 评委无法直接核对编译选项；虽然我重建证明可复现 |

### P2 · 文档/口径/工程卫生

见 §6。

---

## 5. RTL 功能缺陷（独立静态审查 + 我的复核）

> 这些缺陷**不会**让本次 CoreMark 跑错或让 2.6740 变高；相反，修好后成绩可能略升。它们影响 RV32I 精确异常、MMIO 语义和“2 路 LRU / 饱和计数器”的声称。

| 严重度 | 文件:行 | 问题 | 影响 | 复核 |
|---|---|---|---|---|
| **高** | `rtl/core/dcache_axi.v:369`（`CACHED_LIMIT` 在 `:39`） | `early_q` 覆盖 `0x1000_0000..0x1FFF_FFFF`，但数据 RAM 只有 `0x1000_0000..0x1000_3FFF` 16 KiB；对 `0x1000_4000..0x1FFF_FFFF` 的 store 在 W beat 就回 OKAY，B 通道的 DECERR 在 `ST_WR_DRAIN`（`:496-501`）只失效行、不报 fault | 该范围 store **静默成功，不产生 store access fault（cause 7）**；精确异常模型被破坏。CoreMark 不访问该空洞，所以不影响本次分数 | 已读 `dcache_axi.v:369,448-464,496-501`；`pangoriscv_axi_soc.v:85-90` 数据 RAM 16 KiB；interconnect 把越界送 error slave 返回 DECERR |
| **高** | `rtl/core/dcache_axi.v:256`（`:400-402`） | MMIO/非缓存读固定 `m_arsize = 3'd2`，同时 `ar_addr_q <= req_addr` 保留 byte/halfword 偏移；`axi_reg_slave.v:37-42` 要求 `size==2` 时 `addr[1:0]==0` | 对 MMIO 的 `lbu/lhu` 在 offset 1..3/2 会返回 SLVERR → **load access fault**；基线 `axi_data_engine` 用 `req_size=access_size` 是正常的。当前固件用 32 位字访问，未触发 | 已读 `dcache_axi.v:256,400-402`、`axi_reg_slave.v:37-42,79-82` |
| 中 | `rtl/core/dcache_axi.v:381-387,409-414` | 快命中（`rsp_ready=1`）直接回 `ST_IDLE`，而 LRU 只在 `ST_HIT` 更新；LSU 在 accept 拍通常 `rsp_ready=1` | 2 路 LRU 在多数 read hit 上**不更新**，替换退化为固定受害者；影响命中率/跑分，不影响正确性 | `lsu_axi.v:76`；`tb_dcache_axi.sv:263,266` 只测慢路径 |
| 中 | `rtl/core/branch_predictor.v:110-118` | `count_q <= (train_hit && count!=2'b11) ? count+1 : 2'b10;`：`count==11` 且 taken 时被写成 `10`，**不是饱和保持 11** | 长期 taken 的分支被一次 not-taken 打回 01（预测 not-taken）；多一次 misprediction。声称“2 位饱和计数器”不成立 | 已读 `branch_predictor.v:110-118`；`tb_branch_predictor.sv:153-160` 用 4 次 taken 恰好掩盖 |
| 中 | `rtl/core/soc_config.vh:34-36` | 仓库默认三开关**全关**；`build.tcl` 不会自动调用 `set_switches.py` | 直接 `build.tcl` 得到的是 baseline，不是交付 all-on 位流；若镜像带 `PERF_DUMP`，baseline 未映射 `0x60002000`，读 perf 会 load fault | `bitstream/README.md:21` 声称全开；`tools/set_switches.py:22` 需人工执行 |
| 中 | `rtl/core/id.v:160-162` | `FENCE` 实现，`FENCE.I` 故意非法 | 若评委用 riscv-tests `rv32ui-p-fence_i`，会 trap；自修改代码不支持。RV32I 2019 把 FENCE.I 划到 Zifencei，所以“RV32I 基础”可辩解，但应明确写“不支持 Zifencei” | 已读 `id.v:160-162`；旧基线日志里 `rv32ui-p-fence_i` 是 PASS，当前设计会不同 |
| 低 | `rtl/core/dcache_axi.v:395` vs 注释 `:20-22` | 注释称“invalid ways are filled first”，实际 `fill_way_q <= lru_mem`，不优先填 invalid 路 | 轻微命中率损失 | 已读 |
| 低 | `rtl/core/dcache_axi.v:409-414,429-433` | `ST_HIT` 每拍无条件 `resp_q<=0`；refill 错误先置 `2'b10` 再进 `ST_HIT`，背压下错误码可能被清成 OKAY | 潜伏；当前 LSU 恒 ready，未触发 | 已读 |
| 低 | `rtl/perips/axi_uart.v:57,107-110` | RX 无 overrun 标志，新字节覆盖旧字节 | RX 溢出静默丢字节；CoreMark 不用 RX | 已读 |
| 低 | `rtl/core/ifu_axi.v:108-111` | 用 `=== 1'bx` 做 X 检测 | 综合可移植性风险；当前两端口都连接，死分支 | 已读 |
| 低 | `rtl/perips/axi_ram.v:99-101,160-166` | burst write 路径实际不可用（`write_good` 要求 `aw_len==0`） | 当前 LSU 只发单 beat，不暴露；未来接 burst write 会丢数据 | 已读 |
| 低 | `rtl/perips/axi_uart.v:120-129` | UART TX 复位为低 | 上电到第一个 idle 拍可能被外部当 start bit | 静态 |
| 低 | `rtl/core/pangoriscv.v:144-145` | `trap_vector` 端口被忽略，实际用 CSR `mtvec` | 顶层接 0 也不影响；可维护性 | 静态 |
| 低 | `rtl/core/ex.v:462-494` 与 `pangoriscv.v:57-60`/`div_adapter` | CSR 写/除法存在重复“事实来源” | 维护风险 | 静态 |

**已确认正确的关键点**（独立审查）：3 级流水线无独立 EX/MEM 前递，但靠 `regs.v` 写穿 + 全停顿覆盖唯一在途生产者（load-use、ALU→ALU、load→ALU 均正确）；redirect/冲刷/退休、RV32IM 算术/分支/移位/乘除边界、CSR/MRET/trap 优先级、AXI4 握手/ID/LAST/错误响应、I-Cache 2-way LRU/fill 校验、UART/timer/irq/GPIO/RAM 基本路径均通过静态核对与 15/15 ISA、40/40 RAM 回归。

---

## 6. 文档与证据错误清单

| 严重度 | 位置 | 问题 | 建议 |
|---|---|---|---|
| **高** | `README.md:4,13,15` | 根 README 仍写“400 次迭代、1.35 CoreMark/MHz、四级流水线”；当前交付是 768 迭代、2.6740、三级流水线 | 改成 768/2.6740/三级，并注明“仿真、未上板” |
| **高** | `firmware/code/README.md:18,43-49,95` | 仍写 1.35/1.25、400 迭代、12,694 LUT、16.262 ns、位流 `F8254F66…`（该 sbit 已不在仓库） | 全表刷新到 2.6740/768/13,574（或 13,389）/+15.267/`F7B135AE…` |
| **高** | `platform/pango_native/README.md:114-135` | 仍写 200 迭代、0.305 CoreMark/MHz、`CPM_TICKS` 输出；与当前固件/分数完全脱节 | 标注历史或删除 |
| 中 | `docs/verification.md:96-112,162` | §3 仍写“交付跑分为什么是 512 迭代”“ticks 304,495,134”，并让下载 `pangoriscv_i512.sbit`；与 §1 的 768 矛盾 | 统一到 768，删 i512 残留 |
| 中 | 同文件 `:27` | 把 27 MHz 的种子尝试（11 通过、41 不收敛、23 三端点 −0.012）写成“50 MHz 是种子敏感的：seed 11→−0.001、41→−0.155、23 才通过”，与 `P16/measurement.md:119-122` 相反 | 按 P16 测量记录更正 |
| 中 | `evidence/records/bottleneck_audit/results/baseline_build.md:75` | 记录 `board_uart_baseline.txt` 的 sha256 为 `78B7D08D…`，实测文件是 `4F89E5D9…` | 重算并更正；否则“板上身份链”断裂 |
| 中 | `evidence/records/optimization/P16/VERIFICATION.md:57` | 声称“全仓复扫控制字符数为 0”，但该行本身残留 2 个 U+0007（BEL） | 清掉控制字符并重跑扫描 |
| 中 | `evidence/records/optimization/P16/measurement.md:113-118`、`bitstream/README.md:56-57` | 27 MHz slack 15.404/0.025 与 PDS 摘要 15.267/0.030 不一致；LUT 13,574 标成 device_map | 统一引用同一份 `report_timing` + `device_map`，注明阶段 |
| 中 | 串口输出（`core_portme.h` `HAS_FLOAT 0`） | `Total time 10`、`Iterations/Sec 76` 是截断值；用它们算得 2.8444，比真值高 6.4% | 固件打印毫秒/定点秒，或加一行 `CoreMark/MHz` 计算值 |
| 中 | `evidence/records/optimization/P16/verify_rerun_768.txt`、`tools/run_fetch_ab.py:229` | 报告里的 `under-10s-rule=False` 标签容易被读成“不满足 10 s”；实际含义是“没有打印 under-10s 错误” | 改成 `over_10s=True` 或 `under_10s_error=False` |
| 低 | `docs/design.md` vs `README.md:3`/`LICENSE` | 上游署名/许可证与“全部自主、MIT”冲突（见 §4-8） | 恢复上游 NOTICE/许可证，或取得书面授权；改写“自主实现”措辞 |
| 低 | `firmware/code/README.md:3` | 文件本身是合法 UTF-8（此前“乱码”是用 GBK/ANSI 读 UTF-8 的假象） | 无需改编码；只需改内容 |
| 低 | `evidence/records/optimization/P16/verify_rerun_768.txt` | UTF-16LE 编码，文本工具直接读会乱码 | 转 UTF-8 |
| 低 | `evidence/records/bottleneck_audit/board/*.tcl.out.txt` | 2 个 GBK 文件 | 转 UTF-8 或注明 |
| 低 | `docs/repo/LAYOUT.md:9-16` | 文件数/体积过期（实际约 12.5 MB、160+973 文件） | 更新 |
| 低 | `.githooks/pre-push` | 引用不存在的 `SCORE-STATUS.txt`；`ab-log.csv:2` 引用的 `evidence/records/coremark-sim-*` 被 gitignore | 补文件或改引用 |
| 低 | `.sim_runs/` | 本机该目录下若干 `isa-e2e-*` 子目录 ACL 不可读，`run_isa_e2e.py`/`run_unit_tests.py` 默认 `--out .sim_runs` 会 `PermissionError` | 清理该目录；runner 用可写 `--out` |
| 低 | `README.md:61` | 说仓库约 5 MB，实际约 12.5 MB | 更新 |

### 6.1 数字一致性（权威值）

当前内部自洽的“交付值”是：

```
768 迭代 / ticks 287,211,317 / 10.6375 s / 2.6740 CM/MHz
LUT 13,574（synthesis）或 13,389（post-PnR）/ 0.1970 或 0.1997 CM/MHz/kLUT
27 MHz: +15.404/+0.025（文档） 或 +15.267/+0.030（PDS 摘要/我的重跑）
位流: F7B135AE975CCDE775D5B046AFC06BF7BE0EC5D3309996B0E36EEF471BA42F8D
```

`ab-log.csv:29`、`P16/measurement.md`、`bitstream/README.md` 三者对 768/287,211,317/2.6740/13,574 是自洽的；问题只在旧文档、时序摘要、LUT 阶段标签。

---

## 7. 修复优先级

### P0（不做就不能按赛题报分）
1. **上板**：用 `bitstream/pangoriscv_i768.sbit`（或重新生成）下载，串口抓完整 768 迭代输出，确认五项 CRC 与 `Correct operation validated`；确认实际运行 ≥10 s；若板上频率/时序与仿真不同，重算迭代数。
2. **ILA**：抓 CoreMark 关键算法窗口（list/matrix/state 三者之一），保存波形图 + 触发条件/时间轴 + 流水线效率解读，写入性能分析文档。
3. **应用场景**：至少给出一个真实场景（工控/采集/游戏机/图像加速等），写明整体资源、时序、主频；AI 类还需延迟与识别率。

### P1（成绩可比性与证据链）
4. 用赛题 `riscv32-unknown-elf-gcc`（板上基线是 GCC 7.1.1）重编 768 镜像、重跑仿真/上板，重算分数；在文档中披露 GCC 版本。
5. 归档 27 MHz 那一份 PDS 的完整 `flow.log`、`report_timing/*.rtr`、`device_map` 资源表、`compile/run.log`，与 `F7B135AE…` 位流放同一目录；统一引用 `+15.267/+0.030` 或重新生成一份可复现的报告。
6. 明确 LUT 口径：`synthesis 13,574` / `device_map 13,444` / `post-PnR 13,389` 三选一，并写清出处；③ 建议用后布线值并注明“CoreMark/MHz per kLUT”。
7. 把 `manifest.json`、`program.hex`、`data.hex` 与位流一起归档（或放进 `evidence/`），保证编译选项可核对。

### P2（代码与文档）
8. 修 D-Cache `early_q` 范围（改成数据 RAM 窗口 `0x1000_0000..0x1000_3FFF`，或让 DRAIN 的 B 错误上报 fault）。
9. 修 MMIO 读 `ARSIZE`（用 `req_size`，与基线 `axi_data_engine` 一致）。
10. 修 D-Cache 快命中 LRU 更新（在 `state<=IDLE` 分支也更新 `lru_mem`）。
11. 修 2-bit 计数器饱和（`count==11 && taken` 保持 11）。
12. 在 `build.tcl` 里显式检查/切换三开关，或在 README 写死“先 `set_switches.py on`”。
13. 刷新根 README、firmware README、platform README、handoff；修 UART sha、BEL、UTF-16、LAYOUT 体积。
14. 决定 FENCE.I：要么实现为 I-Cache invalidate + nop，要么在文档明确“不支持 Zifencei”，不要让它静默 trap。
15. 澄清 tinyriscv 署名/许可证；恢复上游 NOTICE 或取得授权。

---

## 8. 证据索引（本次独立复现）

| 内容 | 路径 |
|---|---|
| 独立固件（字节一致） | `pangoriscv/firmware/code/build/native_software/coremark/performance/indep_verify/` |
| 20 迭代镜像 | 同目录 `indep20/` |
| RTL 编译日志（0/0） | `_verify_indep/run768/compile.log` |
| 768 迭代 transcript | `_verify_indep/run768/transcript.txt` |
| 20 迭代 transcript | `_verify_indep/run20/transcript.txt` |
| ISA 15/15 | `_verify_indep/isa_runs3/isa-e2e-*/` |
| RAM 40/40 | `_verify_indep/code/.sim_runs/ram-*/` |
| PDS 27 MHz 日志 | `_verify_indep/code/build/pango_native/pds_my27.log` |
| PDS 时序报告 | `_verify_indep/code/build/pango_native/report_timing/pangoriscv_top.rtr` |
| PDS 新位流（哈希不同属正常） | `_verify_indep/code/build/pango_native/generate_bitstream/pangoriscv_top.sbit` |

### 复现命令（简版）

```powershell
# 1) 固件
python tools/build_native_software.py coremark --mode performance --iterations 768 --cpu-mhz 27 `
  --toolchain-bin "<xpack>\bin" --extra-flag=-march=rv32im_zicsr --tag indep_verify

# 2) RTL + 768 迭代
vlog -sv -work work +incdir+rtl/core +incdir+rtl/bus +incdir+rtl/perips +incdir+rtl/soc `
     +incdir+tb +incdir+tb/integration -f sim/native_axi_sources.f tb/integration/tb_coremark_uart.sv
vsim -c -do "run -all; quit -f" work.tb_coremark_uart `
  "+PROG=<image>\program.hex" "+DATA=<image>\data.hex" "+MAX_CYCLES=600000000"

# 3) ISA / RAM
python tools/run_isa_e2e.py --toolchain-bin "<xpack>\bin" --modelsim "<ModelSim>" `
  --extra-flag=-march=rv32im_zicsr --cases all --out <writable>
python sim/run_ram_tests.py --seeds 20

# 4) PDS 27 MHz（先 set_switches.py on；再 set NATIVE_IMAGE_DIR）
$env:PANGO_NATIVE_REPO="<code>"; $env:PANGO_NATIVE_BOARD_DIR="<code>\platform\pango_native"
$env:NATIVE_IMAGE_DIR="<image>"
$env:PANGO_NATIVE_PNR_EXTRA="-fix_hold_violation -fix_hold_violation_threshold 500 -fix_hold_violation_threshold_for_clk_tree 200 -fix_hold_violation_iterations 2000 -max_hold_violated_paths_num 40000 -gplace_seed 11 -groute_seed 11"
Set-Location "<code>\build\pango_native"
pds_shell.exe -file "<code>\platform\pango_native\build.tcl"
```

---

## 9. 一句话总结

**你的 2.6 是真的：我在完全独立的目录里，用逐字节相同的固件、相同的 RTL、相同的 768 迭代，复现出了完全相同的 287,211,317 ticks、五项 CRC 和 2.6740 CoreMark/MHz；27 MHz 时序也独立收敛（+15.267/+0.030，0 失败）。但按赛题它现在只能算“高质量仿真证据”，还不是可提交成绩——缺上板、缺 ILA、缺应用场景，且工具链、位流同源证据和代码署名需要补齐或澄清。**

---

## §4 交接：取指访存优化完成（2026-10-18）

*原文件：`docs/verification.md`*

### pangoriscv 交接报告（2026-10-18 · CoreMark/MHz 2.6757，累计 +105.0%）

> 用途：新会话直接从这里接手。所有结论都有实测数据与证据目录支撑，不依赖对话历史。
> 上一份交接：`handoff-2026-10-17-optimization.md`（其"下一步 IFU"一节已由本文取代）。
> **本文件在 P8/P9/P10/P13/P14/P16 完成后持续更新**：第一节与链条表给的是 P16 的最新数字，
> 细节分别见 `evidence/records/optimization/P8|P9|P10|P13|P14|P16/measurement.md`。

---

## 一、当前交付状态（一句话）

**取指吞吐（P7）+ 访存快发（P8）+ 完成提前报（P9）+ 零延迟命中（P10）
+ 读命中不阻塞（P13）+ store 当拍拿确认（P14）+ 突发气泡清除（P16）七步做完：
CoreMark/MHz 1.3054 → 2.6757（+105.0%），面积只 +7.2%，
27 MHz 与 50 MHz 约束均收敛。**
唯一没做的是上板（没有物理开发板）。

| 评分项 | 交付值 | 来源 |
|---|---|---|
| ① 执行效率 | **2.6757 CoreMark/MHz** | 768 迭代有效跑分，ticks 287,030,751，10.63 s（**RTL 仿真**） |
| ② 时钟频率 | **27 MHz 与 50 MHz 约束均 All Constraints Met** | 27 MHz：setup **+14.578 ns**、hold **+0.115 ns**，0 失败；50 MHz：setup **+1.262 ns**、hold **+0.121 ns**，0 失败（均取 `multiseed_summary.csv`） |
| ③ 资源 | **13,481 LUT（device_map）** / 0.1985 CoreMark/kLUT | synthesis 13,574、后布线更小，引用必须写阶段；触发器 8,507 |

**PDS 收敛经验（务必保留）**：27 MHz 的 hold 必须用
`-fix_hold_violation_threshold 500`（不是 300），否则会留下 1~5 个 −0.001~−0.027 ns 端点，
根因是 D-Cache LUTRAM 写口跨时钟树分支的偏斜。
**种子按频率分开，不要混**（实测记录）：27 MHz 用 `-gplace_seed 11 -groute_seed 11`；
50 MHz 用 `-gplace_seed 23 -groute_seed 23`。50 MHz 对种子敏感：
seed 41 曾出现 1096 条未布通网络（1042 次迭代后放弃），seed 23 才收敛。
27 MHz 未做多seed 扫描（只用 11 与 23 试过）。

> **ISA 限制（必须明说）**：本设计**不支持 Zifencei 扩展**，`FENCE.I` 按非法指令
> 处理（`id.v:160-161` 注释已写"FENCE is implemented, FENCE.I is not"）。
> 评委若跑 `rv32ui-p-fence_i` 会触发非法指令异常。要么在文档里写明不支持，
> 要么实现成"无效化 I-Cache + 当 nop"。

**三项数字的链条**（务必按这个口径说，别混）：

| 阶段 | 每迭代 ticks | CoreMark/MHz | LUT | CoreMark/kLUT |
|---|---|---|---|---|
| S0 基线（store 优化前） | 766,039 | 1.3054 | 12,572 | 0.1038 |
| P2' store 后台排空 B | 697,254 | 1.4342 | 12,622 | 0.1136 |
| P7 取指吞吐 | 594,717 | 1.6815 | 13,018 | 0.1292 |
| P8 访存快发 | 536,987 | 1.8622 | 13,059 | 0.1426 |
| P9 完成提前报 | 479,774 | 2.0843 | 13,099 | 0.1591 |
| P10 零延迟命中 | 421,798 | 2.3708 | 13,558 | 0.1749 |
| P13 读命中不阻塞 | 389,504 | 2.5674 | 13,558 | 0.1894 |
| P14 store 当拍确认 | 382,986 | 2.6109 | 13,576 | 0.1923 |
| P16 突发气泡清除 | 373,973 | 2.6740 | 13,574 | 0.1970 |
| **P17 LRU 修复（本版）** | **373,738** | **2.6757** | **13,481** | **0.1985** |

- 相对最初交付（S0）：**+104.84% CoreMark/MHz**、**+89.72% CoreMark/kLUT**，
  面积仅 +7.97%
- 相对上一版（P14）：**+2.42%**，面积 **−2 LUT / −2 FF（中性）**

位流：`bitstream/pangoriscv_i768.sbit`，3,791,112 B，
SHA256 `0878A35D1D1371209C4E6987F43DB535A54300DDAC15E21A9D9F69A77B3E7B0F`。
（`.sbit` 字节不可复现：同一组参数重跑 slack 完全一致但哈希不同，归档必须同时记录时序汇总。）

---

## 二、本轮做成的唯一性能改动（P7）

### 根因（上一轮推断，本轮数据闭环）

`ifu_axi` 假设"同时只有一笔取指在飞"，`icache_axi` 命中后又要停在 `IC_RESP` 一拍，
两者锁步 → **取指供给 0.5 IPC 天花板**。基线 `if_wait` = 3,269,814 拍 = 全周期的 20.6%。

### 改法（只动两个文件）

1. `ifu_axi.v`：2 深 PC FIFO（`pcf0/pcf1`、`pdf0/pdf1`）+ `ocnt_q`（0..2）；
   响应配槽 0 后前移；`count_q + ocnt_q < DEPTH` **预留队列表项**，
   所以 `eng_rsp_ready` 可以无条件为高（否则会出现"要了响应却塞不进队列"丢指令）；
   重定向改用 `stale_cnt_q` 按笔计数吞迟到响应。
2. `icache_axi.v`：`req_ready` 增加 `rsp_leaving` 条件，`IC_IDLE`/`IC_RESP` 合并受理分支
   → 连续命中 1 拍 1 条。

### 实测（同镜像同测试台 A/B，基线 `99e8bdb`）

| 指标 | 基线 | 本轮 | 变化 |
|---|---|---|---|
| ticks（20 迭代） | 13,940,928 | **11,887,687** | **−14.73%** |
| cycles | 15,866,750 | 13,809,115 | −12.97% |
| IPC | 0.4046 | **0.4686** | +15.8% |
| `if_wait` | 3,269,814 | **742,122** | **−77.30%** |
| `lsu_wait` | 1,560,772 | 1,560,816 | +0.00% |
| `d_miss` / `mispred` / `ret_cf` | 4,209 / 154,321 / 1,401,059 | 相同 | 0 |
| 五项 CRC | — | 逐项一致 | 架构等价 |

只有 `if_wait` 掉、其它停顿项不动 → 收益确实来自取指供给。

### 同镜像同迭代数的绝对 A/B（512 迭代，两侧都是有效跑分）

| 指标 | 基线 `99e8bdb` | 本轮 | 变化 |
|---|---|---|---|
| ticks | 356,993,719 | **304,495,134** | **−14.71%** |
| cycles | 358,802,946 | 306,299,998 | −14.63% |
| IPC | 0.4130 | **0.4840** | +17.2% |
| CoreMark/MHz | 1.4342 | **1.6815** | **+17.24%** |
| `Correct operation validated` | 是 | 是 | — |
| `crcfinal`（同迭代数） | 0xdfc8 | **0xdfc8** | 完全一致 |

---

## 三、历史：P7 那一版的跑分口径（512 迭代）——**已过期，仅留作方法参考**

> 下面这一整节是 **P7 那一版**（CoreMark/MHz 1.6815）的记录，当时交付镜像是
> `pangoriscv_i512.sbit`、512 迭代、`crcfinal 0xdfc8`。
> **当前交付是 P17：768 迭代、ticks 287,030,751、2.6757、`crcfinal 0x3c53`**，
> 见本文档 §1 与 `evidence/records/optimization/P17/measurement.md`。
> 保留这一节只为说明"迭代数必须随性能重算"这个方法论。

性能提上去后 400 迭代会掉到 8.8 s，违反赛题"≥10 s"硬性规则。

```
每迭代 ticks = 594,717
N ≥ ceil(10.5 × 27e6 / 594,717) = 477  → 取 512（11.28 s）
```

**以后任何性能或频率改动都必须重算这个数**，否则成绩作废。

跑分结果：ticks 304,495,134 / 11.28 s / 512 迭代 /
`seedcrc 0xe9f5`、`crclist 0xe714`、`crcmatrix 0x1fd7`、`crcstate 0x8e3a`、`crcfinal 0xdfc8` /
`Correct operation validated` / traps 0 / faults 0。

> `crcfinal` 随迭代数变化（跨迭代累积），官方只比对 list/matrix/state 三项。
> 赛题按整数秒口径读是 512/11/27 MHz ≈ 1.72；按 tick 精确是 **1.6815**，报告一律用后者。

---

## 四、27 MHz 交付实现与 hold 收敛的坑

第一轮全流程：setup WNS +16.521 ns、**0 失败**，但 **hold 4 个端点 −0.020 ns 不过**。
失败路径全是 I-Cache 分布式 RAM 写口，根因是**时钟树分支偏斜**
（launch `HCKBROUTE_2` 3.238 ns / capture `HCKBROUTE_1` 3.832 ns，跨列），
不是数据路径太长——数据侧 0.312 ns 的广播网络延迟反而在吃余量。

修法（**不放松任何约束**：无 false_path、无 multicycle、不降周期）：

```powershell
$env:PANGO_NATIVE_PNR_EXTRA = "-fix_hold_violation -fix_hold_violation_threshold 150 " +
  "-fix_hold_violation_threshold_for_clk_tree 150 " +
  "-fix_hold_violation_threshold_for_clock_path_cross_srb 150 " +
  "-fix_hold_violation_iterations 400 -max_hold_violated_paths_num 4000 " +
  "-groute_seed 23 -gplace_seed 23"
```

即"阈值从 0 提到 150 ps + 换布局/走线种子"，结果 hold **+0.154 / +0.113 ns，0 失败**。
`build.tcl` 为此新增 `PANGO_NATIVE_PNR_EXTRA` 钩子，默认参数不变。

---

## 五、资源口径（别再用旧的 12,572 直接比）

本轮新增 `platform/pango_native/resource_check.tcl`：与 `build.tcl` 相同前端
（同源清单、同 include 路径、同约束、同镜像、同"两幅存储器已载入"守卫），
**停在 device_map**，三分钟出与正式位流一致的 LUT/FF/DRAM。

| 项 | 基线 `99e8bdb` | 本轮 | 变化 |
|---|---|---|---|
| Total LUTs | 12,622 | **13,018** | **+396（+3.14%）** |
| ├ as logic | 9,937 | 10,333 | +396 |
| └ as DRAM | 2,685 | 2,685 | 0 |
| Total Registers | 7,402 | 8,639 | +1,237 |

基线侧与归档的 12,572 / 7,398 差 0.4% / 0.05%，口径一致。
**触发器增幅大于手写改动**（2 深 FIFO 实测约 +70，网表里也没有被复制），
属综合在共享/编码策略上的整体选择差异；它不进评分项③（按 LUT），也不影响时序
（27 MHz 下 setup 仍余 +14.127 ns）。

CoreMark/LUTs：`0.1034 → 0.1292 每 kLUT`（**+24.9%**）——性能涨 28.8%，面积只涨 3.14%。

---

## 六、还剩什么（只有上板）

1. 下载 `pangoriscv_i512.sbit`，串口抓完整 CoreMark 报告（**板上 ≥10 s 必须重新验证**）；
2. ILA 抓 CoreMark 关键算法波形（赛题文档评分项，目前 NOT RUN）；
3. 板上实测频率（约束值 vs 收敛实测值，两个口径分开写）；
4. 用板上数据替换仿真分数并重算迭代数；
5. `SCBV` 未设置（`C: Bitstream-2001`），需按板卡 PCB 确定，现有资料无权威来源，**不猜值**。

---

## 七、环境与工具链（现在共 9 条，前 7 条照旧）

| 坑 | 应对 |
|---|---|
| 工具链前缀是 `riscv-none-elf-`，赛题写的是 `riscv32-unknown-elf-` | 构建用 `--prefix riscv-none-elf-` |
| GCC 15 不再隐含 Zicsr | 必须 `--extra-flag=-march=rv32im_zicsr` |
| `soc_config.vh` 三个开关仓库默认**全关** | 只跑单元/回归时保持全关（`run_pipeline_tests.py` 固定源清单，开关一开就因缺 `branch_predictor` 精化失败）；CoreMark/PDS 才全开，结束无条件还原 |
| ModelSim 复用陈旧 `_opt` 缓存 | 每次编译前删 `work\@_opt*` |
| **PDS 的 `$readmemh` 用进程工作目录** | 从别处启动会得到**存储器全空**的位流且守卫放行；必须 `cd build/pango_native` 后启动，并确认日志有 `Board check: 2 memory images loaded` |
| 用脚本 `-replace` 批量改源码 | 禁止，一律精确编辑 |
| 测试台探针名与 RTL 信号不一致 | 会 vopt 精化失败（vopt-7063）；改 tb 不改 RTL |
| **不能在要删的目录里删自己** | 删目录的进程 `cwd` 放父目录，再另起作业进目标目录；否则 PDS 打开残留旧工程（`report_timing` 是旧网表） |
| `run_halt_reset_tests.py` 硬编码 `riscv32-unknown-elf-` | 已在工具链 bin 内补三个同目录副本（gcc 按自身路径找 libexec，改名可用） |

---

## 八、已经用数据否决的方向（别再做）

| 方向 | 实测 | 结论 |
|---|---|---|
| D-Cache 扩容 | 2→4→8 KB 只快 0.39% / 0.53%，面积 ×4 | 否决 |
| BTB 扩容 | 64/128 项只快 1.68% / 1.84%，LUT +15% / +32% | 否决，恢复 32 项 |
| 取指改造前的"只改 IFU"或"只改 I-Cache" | 单独改任一个与基线**逐位相同**，两个一起改才死锁 | 必须成对改，且要 2 深请求登记 |

---

## 九、纪律（继续守）

- 任何提速改动必须同时记 LUT/寄存器；只看 ticks 会做出亏本决策（BTB 那次就是）。
- 每条结论都要有 **A/B 数字 + 单元测试 + ISA 15/15 + CRC 一致** 四项证据。
- 性能变了就重算迭代数（§3 公式）。
- 不把仿真数据写成板上实测；不把工具按 slack 推算的频率写成实测最高频率。

---

## §5 交接：优化阶段（2026-10-17）

*原文件：`docs/verification.md`*

### pangoriscv 优化交接报告（2026-10-17 收尾）

> **已被 `handoff-2026-10-18-ifu-done.md` 取代（本文保留作历史记录）。**
> 本文"四、下一步：IFU 取指吞吐"已经在 2026-10-18 完成并验证：
> 两笔未完成请求 + I-Cache 背靠背命中，周期 −12.97%、`if_wait` −77.3%、
> 27 MHz 下 All Constraints Met。新的交付数字见新交接文档与
> `evidence/records/optimization/P7/measurement.md`。

> 用途：新会话直接从这里接手。所有结论都有实测数据和提交号支撑，不依赖对话历史。

---

## 一、当前交付状态（一句话）

**store 路径优化把 CoreMark 周期降了 8.98%（CoreMark/MHz ≈ 1.3054 → 1.43），
时钟频率验证到 50 MHz 收敛；IFU 取指通路的改造根因已定位但未动手。**
仓库工作区干净，全部回归绿灯。

| 评分项 | 交付值 | 说明 |
|---|---|---|
| ① CoreMark/MHz | 1.3054 → **约 1.43** | 由 20 迭代 A/B 折算；400 迭代整机实测待跑 |
| ② 时钟频率 | 27 MHz 交付约束（WNS +17.920 ns）；**50 MHz 收敛实验通过**（WNS +2.372 ns，0/66,247 失败） | 板载晶振固定 27 MHz，未上板跑过更高频率 |
| ③ 资源 | **12,572 LUT**（未变） | store 改动只 +3 触发器；BTB 保持 32 项 |

---

## 二、已完成：三项有数据的优化

### 1. 周期分诊（P1）— 一切优化的依据

| 来源 | 占周期 |
|---|---|
| 访存发出后等待 | **36.5%** |
| 取指饥饿 | 18.1% |
| 访存发出前等待 | 9.0% |
| 分支预测失败 | 1.8% |
| 除法 | 0.04% |

> 记录：`evidence/records/optimization/early/P1-measurement.md`
> 结论：**访存是主矛盾**，不是 Cache 容量，也不是分支预测。

### 2. store 路径优化（P2'）— 采纳，最大收益

- 先测：每次写内存平均 9.16 拍，其中 **6.16 拍在等 AXI 的 B 响应**，占全部周期 15.3%
- 做法：只对片上数据 RAM 窗口（`0x1000_0000~0x1FFF_FFFF`）的写**提前释放响应**，
  总线确认在后台排空；窗口外的写仍同步等 B，保住 store 故障精确性
- 结果：**ticks 15,316,450 → 13,940,928（−8.98%）**，等 B 从 1,775,055 → 3,808 拍
- 验证：D-Cache 单元 PASS、ISA **15/15**、5 项 CRC 与基线逐项一致
- 提交 `99e8bdb`；记录 `evidence/records/optimization/early/P2-store-measurement.md`

### 3. 时钟频率收敛实验（P5）— 完成

- 50 MHz 过约束（20 ns）跑完整流程：`All Constraints Met`，Setup WNS **+2.372 ns**，0 失败
- 位流 3,791,112 B，SHA256 `7321AB61…45A3E9`
- **口径**：这是约束收敛结果，不是板上实测最高频率；slack 推算的 56.7 MHz 只能写"推算"
- 提交 `7661e3e`；记录 `evidence/records/optimization/early/P5-measurement.md`

---

## 三、已否决：两个方向别再做

| 方向 | 实测 | 为什么否决 |
|---|---|---|
| D-Cache 扩容 | 2→4→8 KB 只快 0.39%/0.53% | 缺失是强制性/流式，不是冲突；面积 ×4 换 0.5% |
| BTB 扩容 | 64/128 项快 1.68%/1.84%，但 LUT +15%/+32% | 指标③掉 12%/23%，三项并列评分下净亏 |

记录：`evidence/records/optimization/early/P2-measurement.md`、`.../early/P4-measurement.md`

---

## 四、下一步：IFU 取指吞吐（唯一剩下的优化）

### 根因（已定位，不用再分析）

`ifu_axi.v` 用"**只有一笔未完成请求**"的假设给响应配 PC：

```verilog
reg [31:0] req_pc_q, req_pred_q;      // 单份
q_pc[tail_q] <= req_pc_q;             // 响应时用唯一的 PC 配对
```

而 I-Cache `icache_axi.v` 也要 2 拍才受理一次（`req_ready = state==IC_IDLE`），
IFU 也是 2 拍才发一次（`eng_req_valid` 仅在 `S_IDLE`）。两者锁步 → **0.5 IPC 上限**。

一旦让两边背靠背，就有 2 笔请求在飞，`req_pc_q` 被覆盖 → 响应配错 PC →
`head_lost`（`ifu_axi.v:95`）清空重取 → 死循环。这就是上次"只退休 17 条"的原因。

### 改法（4 步，只动 `ifu_axi.v` 的请求登记 + 已验证的 I-Cache 背靠背）

1. **登记改 2 深**：`pcf0_q/pcf1_q`、`pdf0_q/pdf1_q` + `ocnt_q`（0..2）；
2. **入队**：`ocnt_q==0` 写 slot0，否则写 slot1，`ocnt_q+1`；
3. **出队**：响应配对 `pcf0_q`，并 `pcf0_q<=pcf1_q` 前移、`ocnt_q-1`；
   **同拍既收又发**时：配对旧 slot0 → 前移 → 新请求进 slot1（`ocnt_q` 不变）；
4. **复位与 `redirect_valid`** 清 `ocnt_q`（配合已有 `stale_q` 抑制迟到响应）。

I-Cache 侧的背靠背改动已单独验证过安全（单元测试 PASS、整机 ticks 与基线一致）：
`req_ready = rst_n && (state==IC_IDLE || rsp_leaving)`，并把 `IC_IDLE, IC_RESP`
合并到同一个受理分支，`IC_RESP` 下无新请求时走 `else if` 回 `IC_IDLE`。

### 入口门槛（缺一不可）

```powershell
python sim\run_unit_tests.py --case ifu_axi          # 必须先绿
python sim\run_icache_tests.py --modelsim "<ModelSim>"
python tools\run_isa_e2e.py --cases all --toolchain-bin "<xpack>\bin" `
  --prefix riscv-none-elf- "--extra-flag=-march=rv32im_zicsr" --modelsim "<ModelSim>"
# 再跑 20 迭代整机：ticks 应低于 13,940,928，5 项 CRC 与基线一致
```

---

## 五、收尾：全部优化做完后要跑的

1. **400 迭代有效 CoreMark**（`--iterations 400`，镜像 `score400`，`+MAX_CYCLES=420000000`）
   - 必须看到 `Correct operation validated`（测试台收尾已从 12000 改到 250000 周期，
     之前截断的问题已修）
   - 记录 ticks、5 项 CRC、≥10 s
2. **PDS 正式流程**（27 MHz 交付约束）：时序 + 资源 + 位流，三数据同一份实现
3. **证据归档**：`evidence/records/optimization/` 一个新目录 + 路线图附录更新
4. **注意迭代数随性能变化**：性能提升后 400 迭代的实际时间会缩短，
   若低于 10 s 必须提高迭代数（公式 `N ≥ ceil(10.5 × f / 每迭代周期数)`）

---

## 六、环境与工具链（踩过的坑，别重复）

| 坑 | 应对 |
|---|---|
| 工具链前缀是 `riscv-none-elf-`，不是赛题写的 `riscv32-unknown-elf-` | 构建用 `--prefix riscv-none-elf-`；`run_isa_e2e.py` 已加该参数 |
| GCC 15 不再隐含 Zicsr | 必须加 `--extra-flag=-march=rv32im_zicsr` |
| `soc_config.vh` 三个开关仓库默认**全关** | 编译前显式打开并**无条件还原**；忘记会得到无 Cache 设计（IPC 0.10 而不是 0.37） |
| ModelSim 复用陈旧 `_opt` 缓存 | 每次编译前删 `work\@_opt*` |
| PDS 把产物写到**当前工作目录**，不是 `build.tcl` 里 `cd` 的目录 | 每次实验换全新空目录，否则读到上次的 `timing_summary` |
| 用脚本 `-replace` 批量改源码 | **禁止**：曾把 `dcache_axi.v` 写成 0 字节。一律用精确编辑 |
| 测试台探针名与 RTL 信号不一致 | 会 vopt 精化失败（vopt-7063）；改 tb 不改 RTL |

---

## 七、仓库与提交

```
7abb8c0  docs: 优化路线图补执行结果汇总
99e8bdb  perf: store 路径后台排空 B 响应，总周期 -8.98%   ← 唯一采纳的性能改动
40a0d16  perf: BTB 扩容实测后判定不采纳，恢复 32 项
7661e3e  perf: 时钟频率收敛实验（P5）50 MHz 收敛
cb7773c  perf: 分支预测 BTB 32 -> 128（后被 40a0d16 否决回 32）
0243470  perf: 取指吞吐与 store 路径的实测结论
57225b8  dcache: 地址切分参数化 + 实测否决扩容
a0d4995  perf: P0/P1 测量脚手架与周期分诊
65982a0  repo: 用 .gitignore + pre-push 钩子阻止仿真跑分数据上传
```

**纪律**：任何提速改动必须同时记 LUT/寄存器，只看 ticks 会做出亏本决策（BTB 那次就是）。
每条结论都要有 A/B 数字 + 单元测试 + ISA 15/15 + CRC 一致四项证据。

---

## §6 原生版基础状态

*原文件：`docs/verification.md`*

### tinyriscv native-AXI 基本版本 —— 落地状态与验证台账（2026-10-10，收尾轮 m02843 更新于 2026-10-11）

> **板级资料核对轮更新（m03415，2026-10-11，最新）—— 本文所有 "50 MHz" 一律作废。**
> 官方板卡资料证明本板（盘古100Pro+ / MES2L676-100HP / PG2L100H-6IFBG676）的**系统时钟是 27 MHz 单端晶振 → D18**，
> 板上没有 50 MHz 晶振（教程1 §2.1.2.2.3.2；教程2 §7.2「27MHZ…周期约为 37.037ns」；官方 `2_8_uart_test`
> 的 `uart_top.v BPS_NUM = 234`）。本轮据此改了 4 个频率相关常量（`create_clock` 37.037 ns、UART 分频 234、
> `CPU_FREQ_MHZ` 27、构建脚本默认 `--cpu-mhz 27`）并重跑了 PDS 与回归。
> **最新权威证据根**：`E:\file\pango\project\09_validation_results\board_material_audit`
> （`01_BOARD_MATERIAL_AUDIT.md` 资料核对、`02_PIN_AND_SCBV_COMPARISON.md` 引脚/SCBV、`03_CONSTRAINT_CHANGE_LOG.md` 改动记录、
> `04_PDS_REVALIDATION_REPORT.md` 修改后复验、`05_NEXT_BOARD_BRINGUP_STEPS.md` 上板步骤、`BOARD_MATERIAL_AUDIT_FINAL.md` 结论）。
> 本文下面 §3/§4 里的 20 ns / 50 MHz / WNS +5.219 / 比特流 `5ED76142…` 等数值，都属于**修改前（50 MHz 假设）**的历史版本；
> 修改后的最终数值以 `board_material_audit/04_PDS_REVALIDATION_REPORT.md` 为准。

> 本文是**实现轮**（任务 m01844）的台账，并由**收尾轮**（任务 m02843）更新：把基本版本做到"可交付"之后，逐项列清哪些真的跑过、哪些没跑。
> 收尾轮新增/更新的条目一律标 `V18` 或"收尾轮"字样；**最终交付数值以收尾轮为准**（时序/资源/比特流见 §4，源码清单见 `09_validation_results/basic_closure/03_SOURCE_SHA256.csv`）。
>
> **证据分级是硬要求**：编译 ≠ 仿真 ≠ 综合 ≠ 上板 ≠ 计分。本文任何一处结论都不跨级外推。
>
> - 工程根：`E:\file\pango\project\01_code\tinyriscv_axi4`（**所有** vlog/vsim/python 命令都在此目录下执行）
> - 证据根：`E:\file\pango\project\09_validation_results\basic_final`
> - **收尾轮证据根**：`E:\file\pango\project\09_validation_results\basic_closure`
> - 改动记录：`04_change_notes/basic-final-implementation.md`
> - 验证轮报告（历史，边界是"不改生产文件"）：`09_validation_results/BASIC_VERSION_VERIFICATION_REPORT.md`
>
> **路径简写**：表里的 `.../xxx` 一律指 `E:\file\pango\project\09_validation_results\basic_final\xxx`；`build/...` 指工程根下的 `build/...`。

---

## 1. 一句话状态

| 证据类别 | 状态 |
|---|---|
| 代码可综合 / 可精化 | **PASS**（29 源 Verilog-2001 + SV 混合，ModelSim 0 error 0 warning） |
| 功能验证（仿真） | **PASS**（9 组回归全绿：15/15、5/5、PASS、20/20、64/64、20/20、40/40、4/4） |
| 综合 / 布局布线 / 时序 / 比特流 | **PASS**（`All Constraints Met`，已产出 `.sbit`；**最终数值**：慢角 Setup WNS +5.219 ns / Hold WHS +0.124 ns，LUT 7761/66600 = 11.65%，比特流 SHA256 `5ED76142…`，见 §4） |
| 上板下载 | **NOT RUN**（无物理板） |
| CoreMark 实测 | **仿真 PASS / 板上 NOT RUN**（200 迭代 `Total ticks 655032761` → 仿真实测 **13.1007 s ≥ 10 s**，CRC 全对、无 `Errors detected`；**板上**与计分未取得） |
| ILA 波形 | **NOT RUN**（无板，未采集） |

**没有任何一项上板结论被写成本文的仿真或综合结果。**

---

## 2. 运行环境

| 项 | 值 |
|---|---|
| 工具链 | `E:\file\pango\toolchains\openisa-1.0.0\gcc\riscv32-unknown-elf-gcc\bin`，`riscv32-unknown-elf-gcc.exe (GCC) 7.1.1 20170509`，`-march=rv32im -mabi=ilp32` |
| 仿真器 | ModelSim SE-64 10.6e（`E:\donwload\win64`） |
| 综合/实现 | `E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\bin\pds_shell.exe`（2022.2-SP6.1 build 138931） |
| 目标器件 | Logos2 `PG2L100H-6FBG676`（50 MHz 晶振）。器件型号有独立来源：板厂参考工程的 PDS 日志 `07_board_references/.../run_2026-09-22-15-31-49.log:728` 报 `Current device : PG2L100H-6FBG676`。**板卡商品名 `MES2L676-100HP` 在 `07_board_references` 里找不到任何独立来源**（`07_board_references` 无 `.md`、无原理图、无用户手册），只能算待确认信息，**不得**当作已核实事实引用。 |
| Python | 3.11.9 |
| 缺失工具 | iverilog / vvp / yosys **不存在**；物理板 **不存在** |

> PDS license：`E:\donwload\PDS_2022.2-SP6.4\new_pds_F4A80DA47D72.lic`，运行时提示 `license will invalid in 24 days`。

---

## 3. 工程验证表

| # | 验证项 | 结果 | 精确命令（CWD = 工程根） | 日志 |
|---|---|---|---|---|
| V1 | 29 源整体编译 + 精化 | **PASS** | `vlog -sv -work sim/verify_work/compile_check/work "+incdir+rtl/core" "+incdir+rtl/soc" -f sim/native_axi_sources.f` | `sim/verify_work/compile_check/compile.log`（`Errors: 0, Warnings: 0`，exit 0） |
| V2 | 指令级端到端（真实工具链程序 × 完整原生 SoC × 参考模型） | **PASS 15/15** | `python tools/run_isa_e2e.py --cases all` | `09_validation_results/basic_final/regressions/isa_e2e.txt` |
| V3 | halt / reset 事务排空与恢复（5 场景） | **PASS 5/5** | `python tools/run_halt_reset_tests.py` | `.../regressions/halt_reset.txt`、`.../halt_reset/halt_reset_run.txt` |
| V4 | 流水线 N03（含架构 `mtvec` 陷入目标校验） | **PASS** | `python sim/run_pipeline_tests.py` | `.../regressions/pipeline.txt`（`RUN_DIR .sim_runs/pipeline-ydi0l7pu`） |
| V5 | AXI 互联随机回归（20 seed） | **PASS 20/20** | `python sim/run_interconnect_tests.py --seeds 20` | `.../regressions/interconnect.txt` |
| V6 | 读/写引擎 | **PASS 64/64** | `python sim/run_engine_tests.py` | `.../regressions/engine.txt` |
| V7 | IFU↔AXI 引擎 | **PASS 20/20** | `python sim/run_ifu_engine_tests.py` | `.../regressions/ifu_engine.txt` |
| V8 | RAM + LSU | **PASS 40/40** | `python sim/run_ram_tests.py` | `.../regressions/ram.txt` |
| V9 | 单元级（pipe_slot / div_adapter / ifu_axi / lsu_axi） | **PASS 4/4** | `python sim/run_unit_tests.py` | `.../regressions/unit.txt` |
| V10 | 综合 → 布局布线 → 时序 → 比特流 | **PASS** | 见 §4 | `09_validation_results/basic_final/pds/{flow.log,run.log,timing_summary_after_pnr.txt,clock_utilization.txt,pango_native_top.sbit}`（**修复前那一轮**；最终数值见 V18） |
| V11 | CoreMark 1 迭代性能镜像仿真（50 MHz） | **PASS（CRC 全对）** | `vsim -c ... tb_coremark_uart +PROG=... +MAX_CYCLES=40000000` | `.../coremark/coremark_perf_1iter_50MHz.log` |
| V12 | CoreMark 200 迭代仿真（≥10 s 用时取证） | **PASS** | 同上，`+MAX_CYCLES=800000000`，镜像 `--iterations 200` | `09_validation_results/basic_final/coremark/coremark_perf_200iter_50MHz.log`（原始：`sim/verify_work/cm200/coremark_200iter.log`） |
| V13 | 软件镜像构建（CoreMark 性能/校验） | **PASS** | `python tools/build_native_software.py coremark --mode performance --iterations 200 --cpu-mhz 50 --toolchain-bin <bin>` | `build/native_software/coremark/performance/manifest.json`（含全部编译命令与 flags） |
| V14 | 上板下载 / 串口实测 | **NOT RUN** | — | 无物理板 |
| V15 | ILA 波形采集 | **NOT RUN** | — | 无物理板 |
| V16 | 板上真实 CoreMark 计分 | **NOT RUN** | — | 无物理板 |
| V17 | riscv-compliance 官方套件全量跑 | **NOT RUN** | 套件源码/ELF 在树内，但本轮以自建 E2E + 定向用例覆盖 | — |
| V18 | **收尾轮**：观测点属性修复后 29 源重新精化 + 完整 PDS 重跑 | **PASS** | 见 §4.1 | `09_validation_results/basic_closure/pds_rerun/{pds_rerun_closure.log,elab.log,compile/run.log,synthesize/pango_native_top_syn.vm,place_route/...,generate_bitstream/pango_native_top.sbit}` |

---

## 4. 综合 / 时序 / 比特流（V10 详情）

**命令**（可复现）：
```powershell
$pds='E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\bin\pds_shell.exe'
$env:PANGO_NATIVE_REPO='E:\file\pango\project\01_code\tinyriscv_axi4'
$env:PANGO_NATIVE_BOARD_DIR='E:\file\pango\project\01_code\tinyriscv_axi4\platform\pango_native'
Set-Location 'E:\file\pango\project\01_code\tinyriscv_axi4\build\pango_native'
& $pds -file 'E:\file\pango\project\01_code\tinyriscv_axi4\platform\pango_native\build.tcl'
```

**结果（收尾轮最终重跑，V18）**：exit 0，六个阶段全部 `successfully`，
compile→gen_bit_stream 总 CPU `0h:4m:43s`，进程总 CPU `0h:5m:20s`（`pnr` 实测 `0h:2m:53s`，峰值内存 1,641 MB）。
日志：`09_validation_results/basic_closure/pds_rerun/pds_rerun_closure.log`。

> 上一轮（修复观测点属性之前，V10）同流程为 `0h:4m:28s`、`pnr 0h:2m:21s`，日志在 `09_validation_results/basic_final/pds/`。
> **两轮的时序/资源/比特流数值不同**，下表给出最终值并保留旧值作对比；引用时只能用最终值。

**时序（`pnr` 之后，最终）**：`Design Summary : All Constraints Met.`

| 角 | 项 | 最终值（V18） | 失败端点 | 修复前（V10，仅对比） |
|---|---|---|---|---|
| Slow | Setup WNS | **+5.219 ns** | 0 / 29018 | +3.258 ns / 29238 |
| Slow | Hold WHS | **+0.124 ns** | 0 / 29018 | +0.139 ns / 29238 |
| Fast | Setup WNS | **+10.156 ns** | 0 / 29018 | +8.368 ns / 29238 |
| Fast | Hold WHS | **+0.088 ns** | 0 / 29018 | +0.101 ns / 29238 |

Recovery / Removal / Minimum Pulse Width 三个汇总在**两个角上都是空的**（无违例）。

时钟周期 20 ns（`pango_native.fdc`：`create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]`）。
关键路径 = 20 − 5.219 = **14.781 ns** → **等效 Fmax ≈ 67.6 MHz**。
即：50 MHz 目标下余量 5.219 ns。
**口径（必须照此写）**：目标频率仍是 **50 MHz**，"约 59.7 MHz / 约 67.6 MHz"只是由 PnR 余量**推算**的时序余量估计，
**不是**实测最高频率、**不是**已把主频改成 67 MHz；板卡晶振是 50 MHz，本轮**没有**为了好看去降频或改频。

**资源（`pnr` 之后，最终）**：

| 项 | 用量（V18） | 可用 | 占比 | 修复前（V10） |
|---|---|---|---|---|
| Total LUTs | **7761** | 66600 | **11.65%** | 7622 / 11.44% |
| — 其中 LUTs as Logic | 5681 | — | — | 5542 |
| — 其中 LUTs as DRAM(distributed) | 2080 | 19900 | 10.45% | 2080 / 11% |
| Total Registers | **3114** | 133200 | **2.34%** | 2984 / 2.24% |
| DRM (36K block RAM) | 4 | 155 | 3% | 4 / 3% |
| APM | 6 | 240 | 2.50% | 6 / 3% |
| I/O | 13 | 300 | 4.33% | 13 / 5% |
| Latches | 0 | — | — | 0 |

**观测点属性修复的代价**：`+139 LUT`、`+130 寄存器`（LUT 11.44% → 11.65%，寄存器 2.24% → 2.34%），
换来的是 `platform/pango_native/README.md` 的 ILA 探针表在**实现后网表里确实存在**（详见 `04_change_notes/basic-final-implementation.md` §13）。

**比特流（最终）**：`build/pango_native/generate_bitstream/pango_native_top.sbit`（3,791,112 B，SHA256 **`5ED76142DF321F752F01E9637F8616B54AB7083DCE85C040E21B44BC1CE529F4`**），
已归档到 `09_validation_results/basic_closure/pds_rerun/generate_bitstream/pango_native_top.sbit`。
（修复前那一轮为 `A8D616B31B2E53B91A668F5883E82A423FBC8F3B6874EA32181B80454DC693B1`，同尺寸，归档在 `09_validation_results/basic_final/pds/pango_native_top.sbit`，**只作历史对比**。）

**必须一起叙述的告警/限制**：
1. `C: Bitstream-2001: SCBV has not been set. Please set SCBV value based on PCB board...`
   → 未设置 SCBV，**该比特流是否可直接烧录未经上板验证**（无板，无法确认）。
2. `Timing-4087/-4086` 报 `led[0..7]`、`uart_tx`、`key`、`rst_n`、`uart_rx` 为未约束组合路径 —— **预期行为**：FDC 只建时钟、故意不加 blanket false path（加了会把真实路径一并掩盖）。
3. `W: syn_maxfan of lutcarry ... is more than 10000`，未自动复制 —— 未做进一步处理。

**资源效率发现（记录，本轮不改，S3/优化项同属后置 OPEN）**：16 KiB 数据 RAM 因为 `axi_ram.v` 是**异步读**，被推成分布式 LUTRAM（`GTP_RAM64X1DP ×2048` + 寄存器堆 `GTP_RAM32X2DP ×32`），吃掉了 2080 个 LUT；只有只读的程序 RAM 正确推断成 `GTP_DRM36K_E1 ×4`。
若把数据 RAM 改成同步读、改推 block RAM，LUT 总数约可从 7761 降到 ~5681（11.65% → ~8.5%），直接改善赛题 `CoreMark/LUTs` 指标。
**本轮不动**：更激进的性能/资源优化按用户意图属于后续步骤，本轮只做基本版本落地。

---

## 5. 功能验证覆盖（V2 明细）

`run_isa_e2e.py` 在**完整原生 SoC**（CPU + IFU/LSU AXI 引擎 + 互联 + 程序 RAM + 数据 RAM + UART/GPIO/Timer/SPI/IRQ）上跑真实工具链汇编出的程序，并与独立参考模型逐寄存器比对。镜像检查：16,200 / 16,384 B，无压缩指令，编译 0 error。

| 用例 | 覆盖内容 |
|---|---|
| 1 | ALU 依赖链与立即数形式 |
| 2 | load-use 冒险与载入符号/零扩展 |
| 3 | M 扩展乘/除/余 |
| 4 | 分支 / jal / jalr 与错误路径抑制 |
| 5 | 字节/半字 lane 与 store→load |
| 6 | CSR 读改写规则（CSRRW 在 rd=x0 时仍写；CSRRS/CSRRC 写意图来自编码 rs1 索引） |
| 7 | `mcycle` / `minstret` 计数器 |
| 8 | ECALL 陷入与 MRET 返回 |
| 9 | 非法指令陷入 |
| 10 | 取数访问故障陷入 |
| 11 | 存数访问故障陷入 |
| 12 | UART TXDATA 发送 |
| 13 | GPIO 输出模式 |
| 14 | Timer 单次触发与 W1C |
| 15 | 机器定时器中断与 MRET |

陷阱处理链已被真实固件覆盖：`init.c` 写 `mtvec/mie/mstatus` → `start.S` 先调 `_init` 再进 `main` → `trap_entry.S` 保存 x1,x3..x31（x2 存到 sp+128 槽位，保留被中断的 sp）→ `trap_handler.c` 按 cause 3/7/11 分派，其余 cause **关闭 mie/MIE、记录 `trap_last_fault{cause,epc,tval,valid}` 并死循环**，绝不静默 `mepc+4`（仅 `TRAP_TEST_ALLOW_ECALL` 下 cause 11 例外）。

`get_cycle_value()` 已是 64 位安全（high-low-high 重读 + 回绕安全减法）；本轮未改软件。

---

## 6. CoreMark 状态（V11 / V12）—— 证据边界

### 6.1 已取得的（V11，1 迭代性能镜像，50 MHz 仿真）

串口解出的报告：
```
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 3274904          <- core_main.c:288 的 (ee_u32) 截断打印
Total time (secs): 0
ERROR! Must execute for at least 10 secs for a valid result!
Iterations       : 1
Compiler version : GCC7.1.1 20170509
Compiler flags   : -march=rv32im -mabi=ilp32 ... -DITERATIONS=1 -DPERFORMANCE_RUN=1
Memory location  : STATIC
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0xe714
Errors detected
```

四个 CRC 与 `core_main.c` 内建黄金表 index 3（PERFORMANCE_RUN）**逐项一致** → 功能正确性成立。

仿真侧计数：`cycles=40000000 retires=2554658 traps=0 faults=0 uart_chars=679`，程序最终停在 `loop: j loop`（pc 0x68）。

由此推算（**仅为推算，不是实测**）：
- ticks = 3,274,904；50 MHz → 0.0654990 s
- CoreMark/MHz = 1 / 3,274,904 × 1e6 = **0.305**
- 200 迭代 → 200 × 3,274,904 = 654,980,800 ticks → 50 MHz 下 **13.10 s**（实测为 655,032,761 ticks = 13.1007 s，偏差 0.008%）
- **口径提醒**：`CPU_FREQ_HZ` 与板振都是 **50 MHz**，所以 13.10 s 就是板上应得的时间量级（仿真实测值）；
  若按收尾轮推算的等效 Fmax 约 67.6 MHz 去算，同一份 200 迭代镜像只需约 **9.69 s**，
  即**一旦板上实际主频高于 50 MHz，必须按实际主频提高迭代数**才能满足赛题 ≥10 s 的要求；本条是提醒，不是要改频率。

### 6.2 已取得的（V12，200 迭代性能镜像，50 MHz 仿真）—— **≥10 s 已在仿真内实测成立**

镜像：`--iterations 200 --cpu-mhz 50`（`coremark.elf` `5EDB52BA…`、`program.bin` `B0A03D96…`，与 `manifest.json` 的 `artifact_sha256` 逐项一致），归档于 `09_validation_results/basic_final/coremark/performance_200_iter/`。

串口解出的报告（**日志中 `PROGRESS`/`LIVE` 行会插进固件输出中间，下面是去掉交错后的重建**）：
```
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 655032761
Total time (secs): 13          <- HAS_FLOAT=0，用 %d 打印，小数被截断
Iterations/Sec   : 15          <- 同上，整数截断
Iterations       : 200
Compiler version : GCC7.1.1 20170509
Compiler flags   : -march=rv32im -mabi=ilp32 -mcmodel=medlow -O2 -ffreestanding -fno-builtin -fno-common
                   -ffunction-sections -fdata-sections -falign-functions=4 -falign-jumps=4 -falign-loops=4
                   -DCPU_FREQ_MHZ=50 -DITERATIONS=200 -DPERFORMANCE_RUN=1
Memory location  : STATIC
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x382f
Correct operation validated. See readme.txt for run and reporting rules.
```
**没有 `Errors detected`** —— `total_errors == 0`。

> **必须如实说明的截断**：上面这块是"去掉交错后的**重建**"，日志本身**没有**收到完整的 `Correct operation validated.` 那一行。
> 日志里最后解到的字符是 `# Correct operation v`（第 2827 行），其后 12000 个周期 TB 就 `$finish` 了（`stop_cycle=658177948`，
> `$finish` 在 `tb/integration/tb_coremark_uart.sv(319)`），所以 `alidated. See readme.txt …` 这段没有传完。
> **这不影响结论**：`core_main.c:324` 的 `ee_printf("Correct operation validated. …")` **只在 `total_errors==0` 分支里**执行
>（`core_main.c:323` 是 `if (total_errors==0)`），而 `Errors detected` 只在 `total_errors>0` 分支（`core_main.c:341-342`）。
> 两个分支互斥，因此**只要收到该行的任意前缀，就等于 `total_errors==0`**；再加上 5 个 CRC 检查点全部等于黄金值，结论成立。
> TB 的缺点（收尾只等 12000 周期）已记入 §8 的遗留改进项。

原始 64 位 tick（`core_portme.c:44` 新增行，日志里 `CPM_TICKS` 前缀被交错吃掉）：
```
hi=0 lo=655213650      -> t1 = 655,213,650，无 32 位回绕；t0 = 180,889
```

仿真侧计数：`cycles=658177948 retires=61293205 traps=0 faults=0 uart_chars=652 txd_writes=652`，`TEST_PASS T_COREMARK_BOUNDED`，`Errors: 0, Warnings: 0`，vsim 墙钟 **38 分 01 秒**。

**换算（tick 数为仿真实测，秒数与分数为算术推导）**：
- `total_time = 655,032,761 ticks`；50,000,000 Hz → **13.1007 s ≥ 10 s** → 该镜像在仿真内**实测满足**赛题 ≥10 s
- 先前线性推算值 654,980,800 与实测差 **0.008%** → 推算方法被证实
- `Iterations/Sec = 200 / 13.10065522 = 15.2665` → CoreMark/MHz = 15.2665 / 50 = **0.3053**

### 6.3 未取得的（必须显式声明）

- `13.1007 s` 是**仿真实测**，**不是板上实测**。仿真只证明"功能、CRC 与 tick 数符合预期"，不能当作板上用时的证据。
- 板上真实 CoreMark 分数、板上 ≥10 s 判据：**NOT RUN**（V14/V15/V16）。
- `Total ticks` 打印被 32 位截断，长跑必须取 `core_portme.c` 新增的 `CPM_TICKS hi=... lo=...` 行或 ILA；本次 `hi=0` 已证实未回绕。
- **本固件永远打印不出标准 `CoreMark 1.0 : <分数>` 行**：`tests/example/coremark/core_portme.h:16` 是 `#define HAS_FLOAT 0`，而 `core_main.c:325-339` 把分数行整段包在 `#if HAS_FLOAT` 里；同时 `tests/example/lib/xprintf.c` 无浮点能力（`:66` 自带注释 `<xprintf lacks floating point support>`，`:122-123` 的 `default: xputc(c);` 对 `%f` 只回显一个 `f` 且不消耗 double）。因此 `Total time (secs): 13` / `Iterations/Sec : 15` 都是整数截断。分数只能由 `Total ticks` + 已知 50 MHz 算出。修正属**软件/port** 改动（换支持 `%f` 的 printf 并重建镜像），不在本轮 RTL+平台范围；且不改也能满足"≥10 s 有效结果"（判据是 `Total ticks`）。

### 6.4 性能瓶颈（已定位，本轮未改）

`rtl/core/axi_read_engine.v` 的 `req_ready` 只在 `RD_IDLE` 拉高，导致**每次取指 9 个周期**，IPC 仅约 0.093，CoreMark/MHz 约 0.305。
这属于取指通路改造（后续优化项），本轮不动。

---

## 7. 赛题符合性对照（基本版本 vs 高级/统一）

| 赛题要求（基本版本） | 状态 | 证据 / 说明 |
|---|---|---|
| 32×32-bit GPR | PASS | V2 用例 1–7；x0 恒零由 `regs.v` 强制 |
| RV32I 指令集 | PASS | V2 全 15 例；`-march=rv32im` |
| M 扩展 | PASS | V2 用例 3 |
| ≥3 级流水线 + 数据冒险处理 / 旁路 / 停顿 / 分支 | PASS（3 级 IF/ID/EX） | 1 深 skid `pipe_slot`；`retire_ctrl` 单退休契约；**唯一**冒险机制是 `regs.v` 内同周期读写旁路；`ex` 实例化时 `.csr_we_i(1'b0)`、`.mem_rdata_i(32'd0)`，实为 ALU+分支解析 |
| 原生 AXI + 互联 | PASS | V5 20/20、V6 64/64、V7 20/20；S1 修复后可综合 |
| 程序 RAM + 数据 RAM | PASS | 程序 RAM 4096 字 `WRITE_ENABLE(0)` @0x00000000；数据 RAM 4096 字 @0x10000000；V8 40/40 |
| UART / GPIO / Timer / SPI / IRQ 控制器 | PASS | 从设备映射 2=0x20000000 timer、3=0x30000000 uart、4=0x40000000 gpio、5=0x50000000 spi、6=0x60003000 irq_ctrl；V2 用例 12–15 |
| CSR / 同步异常 / MRET / 中断 | PASS | V2 用例 6–11、15；优先级 外部 > 软件 > 定时器；`trap_enter` 原子覆盖 status/mepc/mcause/mtval 且不增 `minstret` |
| 启动与陷阱处理 | PASS | `start.S` + `init.c` + `trap_entry.S` + `trap_handler.c` 全链路 |
| 时序与 CoreMark 用时 | PASS（仿真内） | V10 `All Constraints Met`；V13 镜像构建通过；V12 仿真实测 655,032,761 ticks = 13.1007 s ≥ 10 s，见 §6.2；**板上仍 NOT RUN** |
| 盘古板顶层、引脚约束、PDS 工程 | PASS | `pango_native_top.v` + `.fdc` + `.pcf` + `platform/pango_native/build.tcl`；V10 |
| 上板下载验证 | **NOT RUN** | 无物理板 |

| 高级 / 统一评估项 | 状态 |
|---|---|
| Cache | 未实现（**本轮范围外，不列为基本版本缺陷**） |
| 动态分支预测 | 未实现（同上） |
| DDR | 未实现（同上） |
| DMA | 未实现（同上） |
| 完整 AI 应用 | 未实现（同上） |
| 性能分析文档（赛题要求提交） | **未完成**（方法学与仿真/综合数据齐备，但赛题要求的是基于**板上实测**的分数与波形；缺板 → 不能写成已完成） |
| CoreMark 关键算法 ILA 波形（赛题要求提交） | **NOT RUN**（无板，未采集；探针清单与触发配方已在 `platform/pango_native/README.md` 写好） |

---

## 8. 已知限制与未验证项（不得被解读为通过）

1. **没有上板**：下载、串口实测、按键复位实测、ILA 采集、板上 CoreMark 全部 `NOT RUN`。
2. **比特流 SCBV 未设置**：`Bitstream-2001` 告警存在，是否可烧录未验证。
3. **`Total ticks` 32 位截断**：长跑用时只能取 `CPM_TICKS` 行或 ILA。
4. **CoreMark ≥10 s 只在仿真内实测**：`13.1007 s @50 MHz` 来自仿真 tick 数（`655032761`），**不是板上实测**；板上仍需复现。
5. **CoreMark 成功行在日志中被截断**：TB 匹配到 `Correct operation` 后只等 12000 周期就 `$finish`，日志只收到 `# Correct operation v`。结论仍成立（该前缀只可能来自 `total_errors==0` 分支），但**无法从日志引用完整原文**。
6. **本固件打印不出标准 `CoreMark 1.0 : <分数>` 行**：`HAS_FLOAT 0` 把该分支整段预处理剔除，见 §6.3。
7. **riscv-compliance 官方套件未全量执行**（V17）。
8. **性能瓶颈未改**：取指 9 周期/次，IPC ≈ 0.093，CoreMark/MHz ≈ 0.305。
9. **数据 RAM 走分布式 LUTRAM**：见 §4 资源效率发现。
10. `led[0..7]` / `uart_*` / `key` / `rst_n` 无 I/O 时序约束（`Timing-4087/-4086`），FDC 有意不加 blanket false path。
11. PDS license 24 天后失效。
12. **UART 引脚 B24/C24 没有权威来源**（收尾轮新增）：`platform/pango_native/pango_native.pcf` 的 clk/rst_n/led[0..7] 与板厂 LED 参考工程一致，`key` 也对得上 `_pin_check/key_led`，但 UART TX/RX 两个引脚在**所有**参考约束文件里都找不到，只出现在本工程自己的 `platform/pango_native/README.md`。上板前必须按官方板卡资料核对，见 `09_validation_results/basic_closure/01_PLAN_RECONCILIATION.md` §5 B1。
13. **板卡资料缺失**：`07_board_references` 只有板厂示例工程与引脚核对工程，**没有原理图、没有用户手册**；板卡商品名 `MES2L676-100HP` 无独立来源。SCBV 因此无法确定，**未猜值**（B2/B3）。
14. **收尾轮的历史属性写法已被修正**：第 5 项改动原先用的 `(* keep = "true" *)` 被 PDS 拒绝（`PAP_KEEP` 值非法、`ASYNC_REG` 非法），19 个观测点里 14 个 + 2 个计数器**没有进实现网表**；收尾轮改成 `syn_keep` / `syn_preserve` 并重跑验证（V18）。详见 `04_change_notes/basic-final-implementation.md` §13。

### 8.1 遗留改进项（小，非阻塞）

| 项 | 改法 | 收益 |
|---|---|---|
| `tb_coremark_uart.sv` 收尾太早 | `wait(report_seen)` 后的 `repeat(12000)` 加长到覆盖整条成功行（或改为等 `uart_chars` 稳定 / 等 `"rules."`） | 日志能留下完整 `Correct operation validated.` 原文 |
| 固件分数行缺失 | 让 `ee_printf` 支持 `%f`（或换支持浮点的 printf）、必要时置 `HAS_FLOAT 1`，再重建镜像 | 能打印标准 `CoreMark 1.0 : …` 行 |
| 数据 RAM 改同步读 | 见 §4 | LUT 7761 → ~5681 |

---

## 9. 归档位置

| 内容 | 路径 |
|---|---|
| 本台账 | `E:\file\pango\project\05_verification\native-basic-final-status.md` |
| 改动记录 | `E:\file\pango\project\04_change_notes\basic-final-implementation.md` |
| 交付总报告（问题清单 + 命令 + 日志） | `E:\file\pango\project\09_validation_results\basic_final\BASIC_FINAL_REPORT.md` |
| 回归日志 | `09_validation_results\basic_final\regressions/*.txt` |
| halt/reset 明细 | `09_validation_results\basic_final\halt_reset/` |
| PDS 日志与产物 | `09_validation_results\basic_final\pds/` |
| CoreMark 镜像与日志 | `09_validation_results\basic_final\coremark/` |
| 全部源文件 SHA256 | `09_validation_results\basic_final\FINAL_SOURCE_SHA256.csv`（**旧清单，999 行，对应修复前版本**） |

**收尾轮（任务 m02843）证据根 `E:\file\pango\project\09_validation_results\basic_closure\`**：

| 内容 | 文件 |
|---|---|
| 基础版计划任务对账表（交付物 1） | `01_PLAN_RECONCILIATION.md` |
| 本轮改动与遗留问题（交付物 2） | `02_CLOSURE_CHANGES_AND_OPEN_ISSUES.md` |
| **最终源码 SHA256 清单（961 行，对应最终代码）** | `03_SOURCE_SHA256.csv` |
| 固件/初始化镜像/比特流对应关系（交付物 4） | `04_FIRMWARE_IMAGE_BITSTREAM.md` |
| 精确命令（交付物 5） | `05_COMMANDS.md` |
| 上板准备步骤（交付物 6） | `06_BOARD_BRINGUP.md` |
| 最终交付说明（交付物 7） | `BASIC_CLOSURE_FINAL_DELIVERY.md` |
| 收尾轮 PDS 重跑全部日志与产物 | `pds_rerun/` |
| 备份前 SHA256 记录 | `E:\file\pango\backups\tinyriscv_before_closure_20261011_1452.sha256.csv`（1335 行，全树） |

---

## §7 原生软件构建

*原文件：`docs/verification.md`*

### Native software build

Run from the `tinyriscv_axi4` directory with Python 3.8 or newer:

```powershell
python tools/build_native_software.py coremark
python tools/build_native_software.py coremark --mode validation
python tools/build_native_software.py timer_int --simulation
```

The default compiler directory is the sibling
`toolchains/openisa-1.0.0/gcc/riscv32-unknown-elf-gcc/bin`. Override it with
`--toolchain-bin PATH`; `--prefix` defaults to `riscv32-unknown-elf-`.
The script invokes tools directly, so neither WSL nor make is required.
The target is RV32IM/ILP32 with machine CSRs, using the GCC 7.1.1-compatible
`-march=rv32im` spelling. An RV32I-only build is not supplied: it would also
need a separately audited software multiplication/division runtime.

Outputs are isolated under `build/native_software/APP/MODE/`:

- `program.hex`: 4096 little-endian 32-bit words for flash at address zero.
  It includes initialized data's flash load image; startup copies it into RAM.
- `data.hex`: 4096 words for RAM at `0x10000000`, with initialized data at its
  virtual address and the remaining bytes zero. Startup still performs its
  regular copy and BSS clear.
- `APP.elf`, `firmware.map`, `firmware.dump`, `program.bin`, and
  `manifest.json`: compiler identity, arguments, source/artifact SHA-256
  values, ELF segment addresses, and build evidence.

The linker reserves 8 KiB of the 16 KiB RAM for the stack and rejects
data/BSS overlap. The builder rejects overlapping load-image ranges,
out-of-memory segments, ELF RVC flags, non-32-bit disassembled instructions,
and unresolved non-weak symbols. It links no libc or precompiled libgcc.
The local unsigned 64-bit division/modulo routines use binary long division.
Original precompiled baseline images are not overwritten.

CoreMark algorithm sources and CRC tables remain unchanged. Default runs
use 10000 iterations, performance seeds, integer timing, and 50 MHz.
`--iterations`, `--mode`, and `--cpu-mhz` explicitly change those choices.
Integer seconds are truncated; the original CoreMark `Total ticks` line
also narrows ticks to 32 bits. Do not derive a precise long-run score from
that line alone: capture the 64-bit `get_time()` value or instrument the
verification environment. A build does not establish CRC success, runtime
duration, CoreMark/MHz, board frequency, or a measured performance result.

Startup leaves global interrupts and `mie` disabled. The timer example
clears/configures its source before enabling MTIE and global MIE.
Applications can define `software_irq_handler`, `timer0_irq_handler`, or
`external_irq_handler`; each must acknowledge its own source.
Unregistered interrupts and synchronous exceptions halt after recording
`trap_last_fault` in RAM. Only an explicit `TRAP_TEST_ALLOW_ECALL` build
permits an M-mode ECALL to advance the saved PC by four bytes.

The initial CoreMark performance build was compiled and linked locally.
No native software execution, simulation, hardware run, or benchmark
validation was performed as part of this software edit.

---

## §8 外部验证计划

*原文件：`docs/verification.md`*

### External Verification Handoff

Status: implementation in progress; this document is not a passing report.
User requested code-first work and delegated full verification to another AI.
Latest scope: BASIC VERSION ONLY. Cache, dynamic prediction, DDR, DMA and AI
are deferred. Items 13 and 15 below are future-plan references, not current
acceptance requirements; item 14 applies to the basic CPU.
Preserve the original backup and user changes. Do not modify RTL merely to
make a failing test pass without identifying the architectural cause.

## Environment

Workspace: `E:/file/pango/tinyriscv_axi4`.
Authoritative plan:
`E:/file/pango/docs/superpowers/plans/2026-10-09-tinyriscv-native-axi4-contest-plan.md`.
Results and implementation boundaries: `docs/implementation-status.md`.

```powershell
$python = 'C:\Users\lenovo\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$env:PATH = 'E:\donwload\win64;' + $env:PATH
& $python -m unittest discover -s sim -p test_baseline_runner.py -v
& $python sim/run_unit_tests.py --help
& $python sim/run_pipeline_tests.py --help
& $python sim/run_engine_tests.py --help
& $python sim/run_ifu_engine_tests.py --help
& $python sim/run_ram_tests.py --seeds 20
```

The CSR/interrupt integration changed the CPU trap ports. Older pipeline
benches must be updated to drive the three IRQ inputs and configure mtvec;
the legacy external `trap_vector` input no longer controls architectural
traps. Old unit pass logs predate this change and are not current CPU proof.

Use the documented command-line options from each runner. New runners must
be inspected before invocation; absence of a runner is an unmet deliverable,
not permission to invent a passing result. Use fresh simulation directories.
Require successful process exit, exactly one expected pass marker per case,
and no unexpected Error/Fatal/TIMEOUT. Expected-failure tests must fail for
their specific intended assertion, not an unrelated compile error.

## Verification Order

1. Compile only native sources in the native manifest. Reject legacy RIB,
   duplicate CPU/top definitions and reference modules in the native build.
   The isolated original 47-case baseline is a reference, not a native pass.
2. Pipeline: valid/ready holds, single retirement/writeback, x0, dependency
   bypass, divide stalls, branch/JALR redirects and young-fault flushing.
3. IFU: identity begins at internal request acceptance, redirects before AR
   and during R drain stale responses, held instruction/PC remain stable,
   latest redirected PC restarts autonomously in the full CPU.
4. LSU: every byte/halfword lane, signed/unsigned loads, WSTRB, alignment
   faults without bus traffic, delayed responses, store completion only at B,
   bus faults and trap backpressure without duplicate operations.
5. Engines: all five AXI channels, independent AW/W, stable VALID payloads,
   RID/BID/LAST checks, no retry after write error and fail-closed faults.
6. RAM: first/last/out-of-window addresses, high-bit aliases, synchronous
   reads, no reset clearing contents, independent AW/W, zero WSTRB,
   unsupported burst framing, malformed middle WLAST and LEN=255.
7. Interconnect: simultaneous IF/LSU requests, 20-cycle address stalls,
   round-robin progress, response ownership, W-first, AWREADY dependent on
   WVALID, unmapped DECERR bursts, second-beat SLVERR with ownership retained
   until the eighth beat, response stalls and coordinated reset.
8. Full CPU: actual arithmetic/branch/load-use/store programs, variable AXI
   latency, error paths, retirement trace against an architectural reference,
   halt with an unaccepted/accepted operation and correct resume PC.
9. Peripherals: exact register maps, byte masks, invalid offsets and read-only
   permissions; UART exactly one character and busy error; GPIO synchronized
   input; timer/IRQ new-event priority over simultaneous pending clear.
10. CSR/traps/interrupts: all required causes; encoded zero CSR masks;
    read-only writes; WARL mtvec/mepc/mstatus; atomic trap state; MRET;
    pending/mie/MIE priority; empty-EX interrupts and draining old stores.
11. Software: high-low-high cycle read, 64-bit wrap-safe delays, trap register
    preservation, correct interrupt source clearing, initialized stack/data,
    RV32I or RV32IM ELF with no compressed instructions anywhere.
12. CoreMark: unmodified benchmark algorithms, legitimate integer timing
    port, correct configuration/CRC, real clock and at least ten seconds.
    Compilation, simulation and board performance are separate evidence.
13. Cache/prediction only after their plan gates: both two-way caches,
    full refill/error draining, replacement/write policy, no MMIO caching,
    predictor commit/update/redirect tests and correct maintenance scope.
14. PDS: native CPU compile/synthesis/place-and-route, requested clock timing,
    resources and actual RAM mapping. LED example reports are not CPU proof.
15. Board/DDR/AI: actual hardware download, UART/GPIO/interrupt behavior,
    vendor DDR signal contract and CDC/reset, frozen model/weights/operators,
    DMA boundaries/errors and complete end-to-end output.

## Evidence Rules

Report each item as PASS, FAIL, NOT RUN or BLOCKED, with exact commands,
source revision, fresh log path, counts and failure details. Do not label
syntax checks as simulation, simulation as synthesis, or modeled
performance as board speedup. FENCE.I is currently intentionally illegal;
do not claim Zifencei support from the original reference test.

Full-plan completion requires physical-board and model/vendor inputs.
Missing inputs must be listed explicitly; placeholder RTL is not completion.

---

## §9 参赛验证提示词

*原文件：`docs/verification.md`*

### 给验证AI的提示词

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
