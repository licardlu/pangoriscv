# 比赛收口工作汇报（2026-10-18，给队友）

工作区：`E:\file\pango\project`；证据根：`evidence/records/bottleneck_audit`（下称 `$A`）。
执行依据：`docs/verification/2026-10-18-contest-closure-execution-prompt.md`。
仓库：分支 `main`，HEAD `e60a1f4`（`firmware/code` 仍是旧版，未合并本轮候选）。

## 0. 一句话状态

正式回归与 600 迭代 A/B 板测已完成且有效；ILA 调试位流、上板、采集、ASCII 导出已完成，**只差触发条件的人工设置**；生产树合并、五类最小记录、最终短报告尚未做。

## 1. 完成的交付（按收口提示词逐节）

| 项 | 状态 | 关键证据 |
|---|---|---|
| 可重建候选树（T4+LSU） | 完成 | `$A/contest_final/src`（168 源文件）；宏 ON `rtl/core/soc_config.vh` SHA256=`BD9A2677B58A093AB5BEE6027193BE34B9174C8464FEFBCF2E6957C22585AE2D`；B0 基线树 `$A/baseline_build/src`（159 文件） |
| 宏全关配置独立树 | 完成 | `$A/contest_final/clean/src`（185 文件）；`soc_config.vh` 2121 B，SHA256=`5EAB5871276C134F1EA085FB2C2577E637C7C622BB2EB96992DF52B3D7F44547` |
| 完整回归（宏 ON） | 13/13 PASS | `$A/contest_final/logs/regression_on/summary.txt`、`regression_on_console.log` |
| 完整回归（宏全关） | 13/13 PASS | `$A/contest_final/logs/regression_off/summary.txt`、`regression_off_console.log` |
| case 7 计数器时序修复与验证 | 完成 | `regression_on/isa_e2e.log`：case 15/16 PASS，isa_e2e 16/16 |
| 内部写握手契约 + 负向测试 | 完成 | `regression_on/unit.log`：w_contract 6/6 PASS |
| 正式 CoreMark 600 迭代 A/B（两套种子） | 完成（每配置 2 次采集） | `$A/board/phase2/*.txt`、`$A/results/contest_final_600iter_ab.csv` |
| ILA 调试版构建 + 上板 + 采集/导出 | 采集完成，触发条件未闭环 | 见第 3 节 |
| 生产树合并 | **未开始**（侦察已完成） | 差异清单 `$A/contest_final/logs/merge_recon_20261018_211344.csv` |
| 五类最小记录 | 1/5 完成（只有结果表） | 见第 5 节 |
| 最终短报告 | 未做 | 本文件为过程汇报，不是最终交付物 |

回归分项（宏 ON；OFF 同样全过）：unit 6/6、engine 64/64、ifu_engine 20/20、dcache 1/1、icache 1/1、interconnect 20/20、predictor 1/1、pipeline 1/1、ram 40/40、gpio_trace 1/1、perf 1/1、isa_e2e 16/16、halt_reset 5/5。

## 2. 正式跑分（27 MHz，600 iterations，2000B data）

| 配置 | 种子 | 位流 SHA256（前 16） | ticks | 时间 | CoreMark/MHz | CoreMark | crcfinal | 结论 |
|---|---|---|---|---|---|---|---|---|
| cand perf run1/2 | 0,0,0x66 | `B3ACA53A7F1F5E8A` | 339,639,071 | 12 s | 1.7666 | 47.698 | 0xbd59 | VALID（两次字节一致） |
| B0 perf run1/2 | 0,0,0x66 | `81C3D28272C34462` | 481,086,155 | 17 s | 1.2472 | 33.674 | 0xbd59 | VALID |
| cand val run1/2 | 0x3415,0x3415,0x66 | `0397080AFD1177D8` | 340,038,594 | 12 s | 1.7645 | 47.642 | 0xb8a0 | VALID |
| B0 val run1/2 | 0x3415,0x3415,0x66 | `26E915CE32260273` | 481,756,431 | 17 s | 1.2454 | 33.627 | 0xb8a0 | VALID |

- B0→候选：吞吐 481,086,155/339,639,071 = **1.416463（+41.6463%）**，运行时间 −29.4%（17→12 s）；val 模式 1.41677（+41.677%）。
- 指标公式按提示词：`CoreMark/MHz = iterations×1e6/ticks`；`CoreMark = iterations×27e6/ticks`；`CoreMark/LUT = CoreMark/LUT`（cand 0.003773，B0 0.002678）。
- 同模式镜像同源：perf `program.hex`=`BD8BDFE5…`、`data.hex`=`ED1BAFD7…`；val `program.hex`=`E305533B…`、`data.hex`=`FFFB01DC…`，两版逐字节一致。
- 时序/资源（PDS 后布线）：cand **All Constraints Met**（Setup slow 17.130 / fast 24.375 ns；Hold slow 0.099 / fast 0.071 ns），LUT 12,641（18.98%）/FF 7,358/DRM 4.5/APM 6.0；B0 All Constraints Met（Setup slow 16.440；Hold slow 0.018），LUT 12,572/FF 7,398。
- 原始构建日志：`$A/contest_final/logs/pds_cand_perf600.log`、`pds_cand_val600_v2.log`、`pds_b0_perf600.log`、`pds_b0_val600_v2.log`；时序摘要在各 `build/pango_native-*/place_route/pangoriscv_top_timing_summary_after_hold_fix.txt`。

## 3. ILA（赛题必做项）

**已完成**
- 探针/触发配置：`$A/contest_final/ila/pangoriscv_coremark.fic`（14,773 B，SHA256=`93115486462E8033…`），224 通道：fetch_pc[31:0]、fetch_valid、fetch_inst[31:0]、redirect_pc[31:2]、ls_req_addr[31:0]、obs_retire_count[31:0]、obs_trap_count[15:0]、m_rdata[31:0]、fetch_fault、ls_req_write、dcache hit_any、icache hit0、perf_i_miss/perf_d_miss、if_id/id_ex valid、m_arvalid[0]、m_awvalid[1]、m_rvalid[0/1]、m_rlast[0]、m_bvalid[1]、m_wready[1]；时钟 `nt_clk`，depth 512。
- 调试位流：`$A/contest_final/ila_debug/src/build/pango_native/generate_bitstream/pangoriscv_top.sbit`，3,791,112 B，SHA256=`CC351A11C90FC3F13836C66D1C4F4CF7F25F66843F099AFE0F3F008C3B46868D`；PDS 日志 `$A/contest_final/logs/pds_ila_debug2.log`（EXIT 0，`Core Insertion Complete.`）。
- 调试位流时序：`Some Constraints Violated`，唯一违例为 DebugCore_JCLK→DebugCore_JCLK hold，WHS −0.326 ns（slow）/−0.135 ns（fast），仅 1 个端点；**用户 clk 域全部通过**（Setup slow 15.648/fast 23.259，Hold slow 0.040/fast 0.024）。该位流只作 ILA 证据，不用于计分。
- 上板采集：Fabric Debugger 连接、program（易失性 SRAM）、import FIC、触发采集、导出 ASCII 全部成功。
- 原始数据：`$A/contest_final/logs/ila_capture_export3/ila_samples_ascii.prn`（239,345 B，SHA256=`63F3AEC25A308AA8…`，512 采样×224 信号）、`ila_capture.wdf`（287,454 B，SHA256=`B068E09099326EB2…`）、`ila_capture.dprj`（31,662 B）。
- 数据有效性（已核）：fetch_valid=1 506/512；PC 只有 17 个值且全在 0x10a8–0x12c8；逐条指令与 `firmware.dump` 完全一致 → `core_list_find`（0x10a8 ret、0x10c4–0x10d8 遍历循环）与 `core_bench_list`（0x12a4–0x12c0 链表反转循环），证明 CPU 在跑 CoreMark 链表基准算法，不是启动/LED/UART。
- 停顿可解释性（统计自 PRN，可写入状态记录）：fetch_valid 低 6/512（1.2%）；PC 连续重复 292/511（57%，前端等下游）；PC 非 +4 跳变 48 次（分支/重定向）；I-Cache hit0 252/512（49%）、D-Cache hit_any 479/512（94%）；ls_req_write 133/512、ls_req_addr 100 个不同值；AXI 写通道 awvalid/bvalid/wready 各 19，窗口内 arvalid/rvalid 为 0；retire_fire 214/512、trap 0；if_id valid 506、id_ex valid 504。

**未闭环（唯一阻塞点）**
- 触发条件：dprj 里 `MatchUnitValue` 仍是全 X、GUI 状态列 `disabled` → 实际是自由运行窗口（事后验证落在算法内）。TCL `dbg_set_unit` 对该 224 位值报 `E: Debugger-0019: value is illegal`（裸 224 位与 4 位分组都试过），GUI 自动化不稳定。
- 需要人工在 GUI 做 5 步（当前调试器进程已退出；板子仍保持 ILA 位流，重启调试器即可，不用重新综合/烧录）：
  1) 启动 `cdt_js.exe -work_dir <目录>`，再启动 `cdt_dbg.exe -file $A/contest_final/logs/ila_gui_trigger/gui_session2.tcl`；
  2) 左树 Trigger Setup，TU0 行最右列若 `disabled` → 双击启用为 `enabled`；
  3) 双击 Value 格，Ctrl+A、Ctrl+V 粘贴 `$A/contest_final/logs/ila_gui_manual/trigger_values_paste.txt` 里 **A** 整串（279 字符，PC=0x1078 & fetch_valid=1），回车；
  4) 点 ▶ Run：Console 出现 `Core 0 trigger successful` 即成功；若 >10 s 仍 `Waiting for trigger`，点 ■ 停止，改用 **B** 串再 Run；
  5) File→Export Sample Data→ASCII→OK，保存到 `$A/contest_final/logs/ila_gui_manual/ila_samples.ascii.prn`。
- 完成后把导出文件路径告诉我，我做校验并写进状态记录。

## 4. 失败与修复证据（保留，不删除）

- val600 首轮 4 个位流无效：PDS 启动 CWD 错误（`platform/pango_native` 而非 `build/pango_native`）→ 修正后重建 v2；证据 `$A/contest_final/logs/val600_bad_cwd/`。
- 宏全关回归首轮 9/13：`rtl/core/soc_config.vh` 带 UTF-8 BOM（`vlog-13067`）→ 去 BOM 后 13/13；证据 `regression_off/summary_bom_fail_attempt.txt`。
- ILA 首轮 PDS dev_map 失败：`redirect_pc[0]/[1]` 被优化掉 → 去掉 2 通道（226→224）后成功；证据 `logs/pds_ila_debug.log`、`ila_debug/src/build/pango_native_ila_fail1/`。
- `dbg_set_unit` 触发值被拒（Debugger-0019 value is illegal）；`catch` 在该 Tcl 环境不可靠（失败也返回 0）。
- 已知环境坑：TCL 路径不能带单引号、`dbg_delay` 用 `-time`、Fabric Debugger 启动有 license「Expiration Reminder」模态框需回车关闭、cdt_js 在本机曾有蓝屏史（谨慎反复启动）。

## 5. 待办（按优先级）

1. **P0** 人工完成 ILA 触发设置 + 导出（第 3 节 5 步），我接手校验并补 ILA 分析记录。
2. **P1** 生产树合并：把候选源文件（排除 `build/`、`.sim_runs/`、`__pycache__`、`transcript`、`*.gitasis`、`*.baseline_hold0`）拷入 `firmware/code`，保留生产独有 `platform/pango_native/base_project.pds`、`build.pds`，保持宏 ON；在合并树重跑回归；`git commit`（main）。
   - 侦察：候选 168 文件 vs 生产 146 文件 → 80 个不同、22 个仅候选（含 coremark 测试源、契约 TB、run_regression.ps1 等）、2 个仅生产。清单：`$A/contest_final/logs/merge_recon_20261018_211344.csv`。
3. **P2** 五类最小记录：
   - 状态记录：追加到 `docs/verification/native-basic-final-status.md`（含赛题对账表、本轮 commit/宏配置、ILA 一段分析、case7/W 契约更正、下一步）；
   - 结果表：已有 `$A/results/contest_final_600iter_ab.csv` ✅；
   - REBUILD：补最短说明（工具版本、基础树/候选树、构建/仿真/PDS/下载命令、CWD 坑、必要路径）；
   - 身份清单：机器生成（候选/固件/镜像/4+1 个位流 SHA256 + 对应输入/运行编号；baseline 已有 `provenance/baseline_src_sha256.tsv`）；
   - 原始证据索引：把本文件第 6 节整理入库。
4. **P3** 最终短报告（1 张表 + 几句话，按提示词第 10 节格式）。

## 6. 证据索引（关键路径）

- 正式结果表：`evidence/records/bottleneck_audit/results/contest_final_600iter_ab.csv`
- 板测原始 UART：`evidence/records/bottleneck_audit/board/phase2/{cand,b0}_{perf600,val600}_run{1,2}.txt`（及同目录 flash/configuration/jtagserver 日志）
- 候选构建日志：`evidence/records/bottleneck_audit/contest_final/logs/pds_*.log`
- 候选位流：`.../contest_final/src/build/pango_native-perf600/.../pangoriscv_top.sbit`（`B3ACA53A…`）、`...-val600/...`（`0397080A…`）
- B0 位流：`.../baseline_build/src/build/pango_native-perf600/...`（`81C3D282…`）、`...-val600/...`（`26E915CE…`）
- ILA 位流：`.../contest_final/ila_debug/src/build/pango_native/generate_bitstream/pangoriscv_top.sbit`（`CC351A11…`）
- ILA 采集：`.../contest_final/logs/ila_capture_export3/ila_samples_ascii.prn`、`ila_capture.wdf`、`ila_capture.dprj`、`export_dialog.png`
- ILA 触发值粘贴文件：`.../contest_final/logs/ila_gui_manual/trigger_values_paste.txt`
- 回归：`.../contest_final/logs/regression_on/`、`regression_off/`（各 13 个 log + summary.txt）
- 合并差异清单：`.../contest_final/logs/merge_recon_20261018_211344.csv`
- 基线身份：`.../baseline_build/provenance/{baseline_src_sha256.tsv,firmware_sha256.tsv}`

## 7. 红线（务必遵守）

- 不重新综合/烧录来“找按钮”；IN 调试器按钮操作前先确认板子仍保持 ILA 位流（易失性，断电即丢）。
- ILA 调试位流有 1 个 DebugCore_JCLK hold 违例（−0.326 ns），**只能作 ILA 证据，不能用于正式成绩/交付位流**。
- 只使用已验证的易失性 JTAG 配置流程；不动外部 Flash、不换驱动、不改电气配置。
- cdt_js 在本机曾有蓝屏历史；反复启动前先确认串口/板卡/供电状态，异常立即停并保留证据。
- 许可证 16 天后到期（提示框），批处理弹窗需回车关闭。
