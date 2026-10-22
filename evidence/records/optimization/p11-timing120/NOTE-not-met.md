# p11timing120 —— 120 MHz（核时钟 8.333 ns）全流程：**未收敛**

RTL：`297b768`（4.786 CM/MHz）。约束：`pango_native_120mhz.fdc`
（`create_clock -period 8.333333 [get_pins {u_core_pll/CLKOUT0}]`，无 multicycle、
无 false path、无 clock group 例外）。

## 读数（`run.log` / `flow.log`）

| 阶段 | 最差 slack |
|---|---:|
| global placement | **−11929 ps（−11.93 ns）** |
| post global placement | −10408 ps（−10.41 ns） |
| detailed placement | **−5038 ps（−5.04 ns）**，TNS −48,631,175 ps |

布线：第 345 轮迭代仍在 `Unrouted nets 2`，不再收敛（100 轮时 3 个，200 轮时 3 个，
345 轮时 2 个），终止。

## 结论（两个都记下来，别只看一个）

1. **布不通**：8.333 ns 下布线器留 2~3 根网线走不通，这是拥塞 + 时序双压的结果。
2. **就算布通也过不了时序**：detailed placement 的估计 slack 已是 −5.04 ns，
   即逻辑关键路径 ≈ 8.33 + 5.04 = **13.4 ns ≈ 74 MHz**。布线后的真实值通常比
   摆放估计更差，不会更好。

所以 120 MHz 的缺口不是"布线器没尽力"，是**逻辑路径本身还长 5 ns**。
下一步不是换个 seed 重跑，而是拿一张**真实布线后的路径表**（用 50 MHz 约束跑完整
流程，物理优化不会被人为压榨，延迟数字是真的），按表做 R9。

## 反面对照（为什么这次能走到"2 根没布"，以前的 126 跑不动）

`p5_126` / `p7_impl126b` 都是 10,000+ 根未布线。差别不在 RTL，在约束：
`pango_native_100mhz.fdc` 把周期加在**板级端口**上，PLL 再 ×56/12，
等于要求核时钟 467 MHz。那种跑法连"有没有希望"都问不出来。
**判据：约束必须加在 PLL 输出 pin 上，否则读数无意义。**
