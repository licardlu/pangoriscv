# P7-baseline：先把基线定准（2026-10-22）

这一轮**没有改 RTL**。目录里两份构建的唯一用途，是把"我在优化哪个核、它现在多快、
路径长什么样"这三件事钉死；v2 的结论建立在错误的基线上。

## 构建清单

| 目录 | tag | 约束 | 用途 | 结论 |
|---|---|---|---|---|
| `path40b/` | `p7_path40b` | 40 MHz（25.0 ns，分析专用） | 满足式测量真实最长路径 | **26.647 ns ⇒ 37.5 MHz**，39 级，LUT 18,583 / FF 9,478 |
| `impl126b/` | `p7_impl126b` | 126 MHz（7.937 ns，交付约束） | 按交付约束尝试收敛 | **未收敛**：`pnr` 跑 30 分钟仍有 10,638 条未布线网络，无 `report_timing` |

`p7_impl126b` 目录里**没有** `.rtr`：它只到 `place_route` 阶段就被终止（原因见
`docs/lessons/mistakes-log.md` §34——那轮是脚本写错命令，修正后重跑则是布不通）。
**没有 `.rtr` 就不报布线时序，只能报综合 WNS。**

## 为什么用 40 MHz 而不是 126 MHz 去测路径

126 MHz 对一条 21~26 ns 的路径是不可能布通的，跑到最后得到的是一份"大量未布线"的
时序报告，读不出真实路径。40 MHz 版本保持 PPLL 14/3 不变、只把参考时钟放慢，
布通之后 `report_timing` 的 `Estimated Period` 就是真实最长路径。

约束文件：`firmware/code/platform/pango_native/pango_native_40mhz.fdc`（分析专用，
交付约束仍是 `pango_native_126mhz.fdc`）。

## 路径构成（`path40b/pangoriscv_top.rtr`）

```
soc/core/cpu/w_rd_h[4] → 操作数选择网络(7 级) → u_mul 4×DSP → u_alu_h 比较
  → ex_next_h 目标加法 → N665 预测校验 → soc/N226_3 → perf_inst/cnt[*]/CE
```

| 段 | 延迟 |
|---|---:|
| 操作数选择网络（N190 / N296 / u_regs / u_div） | ≈ 9.4 ns |
| `u_mul` 4 级 DSP 级联 | ≈ 6.1 ns |
| lane1 比较链 → `br_taken_h` | ≈ 1.5 ns |
| 目标加法器 → 预测校验比较 | ≈ 3.1 ns |
| `N226_3` → `perf_inst` CE 级联（16 个 CECO） | ≈ 4.6 ns |

## 同一次构建的三项指标（可互校）

| 指标 | 值 |
|---|---|
| 分数 | `Total ticks 5,073,274 / 20 = 253,664 周期/迭代` ⇒ **3.942 CoreMark/MHz**（仿真，未上板） |
| 频率 | `Estimated Period 26.647 ns` ⇒ **37.5 MHz** |
| 资源 | LUT **18,583** / FF 9,478 / DRM 8 / APM 6 / LUTRAM 3,684 |

> 分数来自 `sim20_o2`（板测镜像同为 `-O2`），不是这份位流跑出来的；
> skill §3 要求"三项出自同一实现"，所以**这一行只能作为同 RTL 的折算值**，
> 板上分数必须等这版位流烧上去重测。
