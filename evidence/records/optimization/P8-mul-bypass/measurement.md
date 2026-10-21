# P8 证据：把 4 级 DSP 级联摘出 lane1 的操作数通路

一个实现一个目录。三项指标（分数 / 频率 / 面积）必须能互相对上，
所以下面每一行都写清"哪个构建、哪个镜像、哪个约束"。

## 1. 改了什么

`packet_md_use`：lane 0 是 multiply/divide 且 lane 1 同拍读它的结果时，**不配这一包**；
`fwd1_h / fwd2_h` 的包内旁路输入由 `ex_value_w` 改为 `alu_y`。

原因（`p7_path40b/report_timing` 逐 cell 读出来的）：
最差路径 26.647 ns 里 9.0 ns 是 `u_mul` 的四级 DSP 级联，而它出现在路径上的唯一理由，
是"lane0 乘、lane1 读同包结果"这一种包把积接到了 lane1 的操作数 mux 上。
详见 `docs/lessons/mistakes-log.md` §35。

同时把交付配置的 `PERF_ENABLE` 关掉（教训 §9.7 要求；它自己也是原路径的终点，
`soc/perf_inst/cnt[*]/CE` 级联 4.6 ns，见 §4）。

## 2. 分数（镜像 `sim20_o2`，20 迭代，RV32_DEBUG）

| 构建 | 总周期 | `Total ticks`（计分窗口） | 周期/迭代 | CoreMark/MHz | 五项 CRC |
|---|---:|---:|---:|---:|---|
| P7（改前） | 6,960,622 | 5,073,274 | 253,664 | 3.942 | 全对 |
| **P8（改后）** | **6,960,617** | **5,073,264** | **253,663** | **3.942** | 全对 |

`crcfinal = 0x4983`，与交付版一致。**这条改动对分数是零代价**（−5 周期是噪声）。

## 3. 频率

| 构建 | 约束 | `Design Summary` | WNS | 布线后等效周期 |
|---|---|---:|---:|---:|
| `p7_path40b`（改前） | 40 MHz / 25 ns | 未全过 | **−1.647** | 26.647 ns |
| `p8_path40`（改后） | 40 MHz / 25 ns | **All Constraints Met** | **+1.053** | 23.947 ns |
| `p8_100`（改后） | 100 MHz / 10 ns | 布线不收敛（11,786 条未布线） | — | — |

同一约束下 WNS 改善 **2.70 ns**（26.647 → 23.947 ns）。

⚠️ **不要把这个数当"上限"**：`p8_path40` 的报告里 `Logic 4.038 ns (17%) / Route 19.447 ns (83%)`，
走线占八成说明工具在宽约束下提前收敛、不再为时序优化（教训 §37）。
100 MHz 不收敛说明真实上限在 40~100 MHz 之间，**本轮没有测出确切值**。

## 4. 面积（`device_map`，PG2L100H-6，同流程同阶段）

| 构建 | LUT | FF | DRM | APM |
|---|---:|---:|---:|---:|
| `p7_path40b`（PERF on） | 18,583 | 9,478 | 8 | 6 |
| **`p8_path40`（PERF off）** | **16,935** | **7,680** | 8 | 6 |

**与之前所有构建不可直接比**：它们都带 `PERF_ENABLE`，本轮关掉后
`perf_inst` 的 1,648 LUT / 1,798 FF 一起消失。这也是 skill §9.7 的交付要求，
所以交付基线应从 P8 重建。

## 5. 功能

ISA e2e **20/21**，与改前一致；只有 case 21 红，是探针口径问题
（`young_path_ok` 直接接 `1'b1`，违规计数恒为 0，任何实现都过不了；功能本身正确）。

## 6. 复现命令

```bash
cd firmware/code
python tools/run_isa_e2e.py --modelsim "D:\FPGA_Project\Modelism\win64" \
  --toolchain-bin "...\xpack-riscv-none-elf-gcc-15.2.0-1\bin" --extra-flag=-march=rv32im_zicsr
python tools/run_coremark_sim.py --image build/native_software/coremark/performance/sim20_o2 \
  --tag p8_md --define RV32_DEBUG
python tools/run_pds_flow.py --tag p8_path40 --freq 40 --mode full
```
