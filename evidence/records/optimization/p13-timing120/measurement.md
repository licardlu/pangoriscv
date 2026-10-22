# p13timing120 — 120 MHz 核时钟，RTL `01ba45e`

构建：`tools/run_pds_flow.py --tag p13timing120 --freq 120 --mode full`
约束：`pango_native_120mhz.fdc`，`create_clock -name core_clk -period 8.333333 [get_pins {u_core_pll/CLKOUT0}]`

## 结果：不收敛

| 阶段 | 读数 |
|---|---|
| clock region global placement | **−20,040 ps** |
| global placement | −17,709 ps |
| post global placement | −21,083 ps |
| before detailed placement | −19,705 ps（TNS −158,759,266） |
| **after detailed placement** | **−12,425 ps**（TNS −111,873,269） |
| after placement（收敛值） | **−12,452 ps** |
| before global route | −12,452 ps |
| 布线 | 迭代 4 仍有 **20,474 根未布线**，已终止 |

8.333 ns 周期下 `worst slack −12,452 ps` ⇒ **最差路径 20.79 ns**，即摆放期估计
**48.1 MHz**。按 mistakes-log §43 的校准（布线后比摆放估计再差 ~4 ns），
真实 fmax 在 **37~40 MHz**，和 `p7_path40b` 实测的 26.65 ns / 37.5 MHz 吻合。

**120 / 40 = 3.0 倍**。这不是布线器没尽力（它把 slack 从 −20,040 拉到 −12,452 用了
40 多轮 swap/DP），是逻辑深度本身超出预算。

## 关键路径（见 `../p7-path40b-timing/`）

39 个逻辑级，`Logic 11.345 ns (43.5%) / Route 14.749 ns (56.5%)`，
三个 32 位宽加法器串在同一拍：ALU 比较 → 下一 PC → 预测校验，
末端还有 16 级计数器 CE 链。

## 资源

`p13-synthesize.log`：LUT 17,405 / 66,600（**26.1%**）、FF 7,776 / 133,200（5.8%）、
DRM 8 / 155、APM 10 / 240。**设计不是面积/拥塞受限，是逻辑深度受限。**

## 结论

想上 120 MHz 必须把单拍逻辑级从 39 压到 16~18，也就是改流水线深度：
EX 拆两级、乘法器单独一级、计数器事件抽头打一拍、旁路网络按来源分组选通。
四条都吃分数（多一级流水 = 多一拍分支惩罚），与 5.2 的目标直接冲突。
