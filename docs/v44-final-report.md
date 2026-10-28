# v40 收尾报告（本版最终交付）

日期：2026-10-28 12:23
结论：**CoreMark/MHz 5.2599 @ 50 MHz，五项 CRC 全对，运行 15.21 s（≥10 s 合规）。**
这是本项目目前最好的一次真机成绩，也是本版的交付位流。

---

## 1. 交付物

| 项 | 内容 |
|---|---|
| 位流 | `pangoriscv-verify/bitstreams/pangoriscv_v40_o3_4000_5p26.sbit` |
| SHA256 | `286e3815cb8523e3a94b32f92369db0c7f76d37fc8ab79404d91aceb3842d548` |
| 源码 | `pangoriscv` 主干 `d7cbd6c` + 工作树改动（唯一 RTL 改动是 P33，见 §4） |
| 镜像 | `build/native_software/coremark/performance/g15o3_4000`（GCC 15.2.0，`-O3`，4000 迭代）|
| 串口原文 | `pangoriscv-verify/runs/uart_pangoriscv_v40_o3_4000_5p26_20261028_122306.txt` |
| 结果 JSON | `pangoriscv-verify/runs/result_pangoriscv_v40_o3_4000_5p26_20261028_122306.json` |

## 2. 真机原始输出（2026-10-28 12:23，COM13 @115200 8N1）

```
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 760474020
Total time (secs): 15
Iterations       : 4000
Compiler version : GCC15.2.0
Compiler flags   : -march=rv32im -mabi=ilp32 -mcmodel=medlow -O3 -ffreestanding -fno-builtin
                   -fno-common -ffunction-sections -fdata-sections -falign-functions=4
                   -falign-jumps=4 -falign-loops=4 -DCPU_FREQ_MHZ=50 -march=rv32im_zicsr
                   -DITERATIONS=4000 -DPERFORMANCE_RUN=1
Memory location  : STATIC
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x65c5
Correct operation validated.
```

## 3. 三项指标（出自同一份位流）

| 指标 | 值 | 口径 |
|---|---:|---|
| **执行效率 CoreMark/MHz** | **5.2599** | 4000 × 10⁶ ÷ 760,474,020 = 190,118.5 拍/迭代 |
| **最高主频** | **50 MHz** | 约束 50 MHz、PLL 27×50/27；布线后 setup +0.199（0 失败端点）|
| **资源效率 CoreMark/kLUT** | **0.3090** | LUT 17,020（device_map）|
| 面积 | LUT 17,020 / FF 8,645 / DRM 12 / APM 10 / LUTRAM 2,274 | `build/v40_g15o3/multiseed_summary.csv` |
| 运行时间 | 15.21 s | ≥10 s 合规 |

## 4. 相对原版（交付树 232dfa3，即“同学那版”）的改动

**唯一 RTL 改动 P33**（`rv32_top.v`，36 行）：CSR 的编译器可见结果直接取 `w_csr_old`，
不再在 WB 再读一次 CSR 阵列；`csr_native` 的读地址固定为 `id_csr_addr`。

| 项 | 原版 p48e-board50 | 本版 v40 | 判定 |
|---|---|---|---|
| 综合 WNS @50 MHz | +0.395（19.605 ns）| **+1.139（18.861 ns）** | 关键路径短 0.744 ns |
| LUT | 17,174 | **17,020（−154）** | 更小 |
| FF | 8,693 | **8,645（−48）** | 更小 |
| 布线后 setup | +0.437，0 失败端点 | +0.199，0 失败端点 | 都过 |
| 布线后 hold | +0.013，0 失败端点 | **−0.158，2 失败端点** | **未过（见 §6）** |
| 时序结论 | All Constraints Met | Some Constraints Violated | **未过** |
| 上板 ticks（-O2/2800 迭代）| 533,875,894 | 533,875,894 | **逐位相同** |
| 五项 CRC | e9f5/e714/1fd7/8e3a/bd59 | 完全相同 | **逐位相同** |
| CoreMark/MHz | 5.2447 | **5.2599** | +0.29% |

功能等价性判据：**同一份镜像 + 两棵网表 + 串口输出逐字符相同**（`mistakes-log` §119）。

`-O3` 只换 BRAM 初值、不改网表：v39 与 v40 的综合 WNS（1.139）、LUT（17,020）、
FF（8,645）、DRM（12）、APM（10）、布线弧长（393,503）完全相同。

## 5. 为什么停在 50 MHz（证据，不是没试）

| 约束 | 布线后最差路径 | 结论 |
|---|---|---|
| 50 MHz | 19.80 ns（本版） / 19.355 ns（交付树） | ✓ |
| 52 MHz | 19.426 ns（9 次满流程最好一次，`p52-family`）| ✗ 差 0.195 ns |
| 55 MHz | 19.324 ~ 19.776 ns | ✗ |
| 60 MHz | 布不通 | ✗ |

同一网表换 seed / `-dc_duplication` / `-refineplacement_cluster` / `-slack_prior_in_global_router`
三组独立对照**逐位相同**，重跑不产生新抽样；同一棵网表两次布线可差 **2.4 ns**。

本版最差路径（`build/v40_g15o3/report_timing/pangoriscv_top.rtr`）：

```
rr_inst[21] (fanout=136, 1.747 ns) → 3×LUT → alu_b[0] (fanout=80, 1.080)
  → u_alu 4 级 → alu_y[14] (1.248) → mem_sdata_h[14] (0.861)
  → u_mul_h 4 个 APM 级联 (1.806+1.362+1.608+1.362 = 6.138)
  → prod[49] (1.146) → ex_value_h[17]
Logic 7.685 ns (39.5%) / Route 11.752 ns (60.5%)
```

一拍里塞了：读寄存器 + 旁路 mux + ALU + AGU + 4 级 DSP 级联 + 阵列写使能。
**5.26 这个分数正是“长时钟周期”换来的。**

## 6. 未完成项（如实记录，两条）

1. **hold 违例 −0.158 ns，2 个失败端点。**
   路径：`soc/core/data_cache/tag_di_q[1] → tag_mem_2/ram64x1d/DI`，
   **0 级逻辑、数据 0.264 ns**，成因是时钟插入延迟差（launch 2.209 / capture 2.597）。
   这条路径 P33 没有触碰过；原版能过 hold 是因为那次布线的时钟树更平衡。
   已启动 `v43_holdfix`（`-fix_hold_violation_iterations 200`）取一个 setup/hold 都过的样本，
   出流后可直接替换本报告 §1 的位流，无需改 RTL、无需重测分数（ticks 与 CRC 不变）。
2. **120 MHz 未达成。** 需要把 EX 一拍拆成三拍，方案见 `docs/plan-v28-ex-split.md`。
   代价预算：重定向 +2 拍（+7.2%）、load-use 停顿（+5~9%），CoreMark/MHz 会掉到 4.5~4.7，
   需要再补一轮 IPC 才能回到 5.0。**不是调优，是改结构。**

## 7. 复现

```powershell
# 上板测量（约 70 s）
cd pangoriscv-verify
. .\measure.ps1 -Sbit bitstreams\pangoriscv_v40_o3_4000_5p26.sbit -ComPort COM13 -FreqMhz 50

# 重新出流（约 35 min，单 license，不要并发）
cd pangoriscv\firmware\code
python tools/build_native_software.py coremark --mode performance --tag myimg `
    --toolchain-bin <workspace>/toolchain/xpack-riscv-none-elf-gcc-15.2.0-1/bin `
    --prefix riscv-none-elf- --opt=-O3 --extra-flag=-march=rv32im_zicsr `
    --iterations 4000 --cpu-mhz 50
python tools/run_pds_flow.py --tag mybuild --freq 50 --mode full `
    --image build/native_software/coremark/performance/myimg
```

**必须遵守的三条**：镜像用 GCC 15.2.0（13.2.0 会让 ticks 差 4.6%）；不要并发跑两个 PDS 流程
（单 seat license 静默死锁）；不要用“布线后 ns”比较单次改动（同树重布差 2.4 ns）。
