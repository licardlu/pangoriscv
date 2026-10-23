# P48e —— 50 MHz 达成（`All Constraints Met`）

**一句话**：把 50 MHz 的约束从"`core_clk` 50 + `core_clk_pnr` 52（鞭子）"改成**单时钟 20.000 ns**，
同一棵 RTL 的布线结果从 21.12 / 21.60 ns 变成 **19.355 ns**，50 MHz 正面通过。
分数不变（190,535 拍/迭代），频率 **48 → 50 MHz（+4.2%）**。

---

## 为什么之前"50 MHz 不行"

三次构建，RTL 几乎相同（只差 PLL 常量与一条中断边界修复），差别在**最紧的那条声明时钟**：

| 构建 | `core_clk`（声明） | `core_clk_pnr`（鞭子） | 摆放 WNS | 布线后路径 | 结果 |
|---|---|---|---|---|---|
| `p48r48d`（48 M 交付） | 20.833 ns | **20.000 ns** | +1683 ps | **19.355 ns** | ✓ |
| `p48r50` | 20.000 ns | 19.231 ns | +1072 ps | 21.600 ns | ✗ −1.595 |
| `p48r50b` | 20.000 ns | 19.231 ns | +1217 ps | 21.120 ns | ✗ −1.120（仅 40 端点）|
| **`p48r50e`** | **20.000 ns** | **无** | **+1683 ps** | **19.355 ns** | **✓ +0.645** |

⇒ **19.231 ns 这个目标是这条网表的坏点**：它把逻辑压得过密，布出来比 20.000 ns 目标还差 2 ns。
"声明得比目标更紧"这条经验（§68 的鞭子时钟）**在这个频段上是反作用**，只在 20.000 ns 这一档有效。
这也解释了历史上"50 MHz 摆放更好却布不通"的怪现象（§70）。

## 实现

| 项 | 值 |
|---|---|
| tag | `build/p48r50e` |
| PLL | 27×50/27 = **50.000 MHz**，VCO 1350 |
| 约束 | **单时钟** `core_clk` 20.000 ns（`pango_native_50mhz.fdc`）|
| 镜像 | `hw_i2800_50v17`（2800 迭代 / `CPU_FREQ_MHZ=50`）→ 533.5 M / 50 M = **10.67 s ≥ 10 s** |
| 配方 | seed 7 + `-plc_decongestion 2 -dispose_dram_prior TRUE -share_router_control_signal TRUE` |
| 面积 | **LUT 17,174 / FF 8,693 / LUTRAM 2,274 / DRM 12 / APM 10** |
| 详细布线 | **0 未布通 @ 114 轮** |
| 位流 | `bitstream/pangoriscv_board50_i2800_5p248.sbit`，sha256 `5e1969fca5b06bb9…1db19ecf` |

## 时序（同一份实现）

```
Design Summary : All Constraints Met.

   core_clk  50 MHz (20.000 ns)   setup WNS +0.645   TNS 0.000   failing 0 / 58,628
                                  hold  WHS +0.010   THS 0.000   failing 0 / 58,628
```

布线后最差路径 **19.355 ns** = **51.67 MHz** 的物理上限，声明 50 MHz 留 0.645 ns。

## 分数

分数与频率无关，取固件自报 `Total ticks`：

- 20 迭代仿真（同 RTL 同源码，`sim20_O2`）：`Total ticks 3,810,700` ⇒ 190,535 拍/迭代，**5.2484**；
- 2800 迭代镜像按同一拍数推算：**≈ 533.5 M ticks** ⇒ `2800e6 / 533.5e6 = 5.248`，
  运行时间 533.5 M / 50 MHz = **10.67 s**（合规）；
- 与上一版 `board48_i2700`（板测 5.2447）是同 RTL 同源码，**拍数逐位一致**，
  所以分数就是 5.2447~5.2484 这一档，**不因提频而变**。

⚠️ **本版未上板**（20:10 再扫一次 JTAG 链仍 `No devices detected`）。上板判据：

```
Total ticks 应落在 533.4 M ± 0.2%（即 532.3 M ~ 534.5 M）
seedcrc 0xe9f5  crclist 0xe714  crcmatrix 0x1fd7  crcstate 0x8e3a
crcfinal 随迭代数变化，2800 迭代的值需以上板实测为准，不是固定 0x4983
必须出现 Correct operation validated
```
