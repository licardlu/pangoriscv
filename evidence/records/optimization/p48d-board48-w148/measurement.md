# P48d —— 48 MHz 重出（WNS +1.478 ns，取代交付版 +0.252）

**为什么重出**：交付版 `pangoriscv_board48_i2700_5p245.sbit` 的 setup 只剩 **+0.252 ns**，
是所有历史实现里最薄的一版。本轮把树里加了一条中断边界修复（行为逐位不变）后重新实现，
**摆放 +1,683 ps（对照：同一棵树不加修复是 +1,068 ps）**，布线只用了 **115 轮**。

---

## 实现

| 项 | 值 |
|---|---|
| tag | `build/p48r48d` |
| PLL | 27×64/36 = **48.000 MHz**，VCO 1728 |
| 约束 | `core_clk` 48 MHz（20.8333 ns）＋ `core_clk_pnr` 50 MHz（20.0 ns，`-add`）|
| 镜像 | `hw_i2700_48`（2700 迭代 / `CPU_FREQ_MHZ=48`）|
| 配方 | seed 7 + `-plc_decongestion 2 -dispose_dram_prior TRUE -share_router_control_signal TRUE` |
| 面积 | **LUT 17,174 / FF 8,693 / DRAM 2,274 / DRM 12 / APM 10**（交付版 17,105，+69 来自中断边界修复）|
| 详细布线 | **0 未布通 @ 115 轮** |
| 位流 | `bitstream/pangoriscv_board48_i2700_w148.sbit`，sha256 `71f64023b8f70ce6…f5168e4d` |

## 时序

```
Design Summary : All Constraints Met.

             clock        WNS      TNS   failing/total
  core_clk      48 MHz    +1.478   0.000     0 / 58,628
  core_clk_pnr  50 MHz    +0.645   0.000     0 / 58,628
  hold (both)            WHS +0.010  0.000     0 / 58,628
```

⇒ 布线后最差路径 **19.355 ns**（= 20.833 − 1.478）。
**它也比 50 MHz 的 20.000 ns 短 0.645 ns**，但本版 PLL 实配 48 MHz，
所以按项目口径**只声明 48 MHz**（`core_clk` 行）；50 MHz 那一行只当"还有多少余量"看。
50 MHz 的正式尝试见 `p48r50b`。

## 与交付版对比

| | `board48`（P30/P35a，已上板） | **`board48_w148`（本轮）** |
|---|---|---|
| 约束频率 | 48 MHz | 48 MHz |
| 布线后路径 | 20.581 ns | **19.355 ns** |
| setup WNS | +0.252 | **+1.478** |
| hold WHS | +0.021 | +0.010（同样 0 失败端点）|
| LUT | 17,105 | 17,174 |
| `Total ticks`（20 it 仿真）| 3,810,700 | 3,810,700（**逐位一致**）|
| 分数 | 5.2484（仿真）/ **5.2447（板测）** | 5.2484（仿真）/ **未板测** |
| 板测 | 有（`board_p35a.txt`）| **无**（JTAG 链扫不到器件，见 plan v17 §8）|

**口径声明**：本轮位流**没有上板实测**，它的分数只能作为"同 RTL、同镜像、仿真 ticks 逐位一致"
的推断值，**不得报成板测**。板测值仍然是 `board48` 的 5.2447。
