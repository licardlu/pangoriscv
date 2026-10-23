# 两步流程：在更紧的周期下摆放，再按交付周期布线（P60）

## 为什么需要它

摆放器的力度由 **SDC 周期** 驱动，不是由 `-place_worst_slack` 驱动。同一个网表
（`exp/split`，含切②+P57）实测：

| 约束周期 | 摆放后最差路径 | slack |
|---|---|---|
| 8.333 ns（120 MHz）| **14.09 / 14.12 ns** | −5.767 / −5.785 |
| 16.667 ns（60 MHz）| 15.58 ns | +1.084 |
| 18.181 ns（55 MHz）| 16.93 ns | +1.256 |
| 20.000 ns（50 MHz）| 18.35 ns | +1.646 |

`-place_worst_slack 8000`（要求 +8 ns）反而**更差**：17.18 ns（+1.001）。
⇒ 想让摆放器做到 14 ns 这一档，只能**真的给它 8.333 ns 的周期**。

于是：**第一步按 120 MHz 只做摆放**（不出位流、不报时序），
**第二步从那个摆放库出发、按交付周期（如 60 MHz）布线并出位流**。
第二步的 `report_timing` 用的是交付周期的 FDC，所以判据与常规流程完全一样。

## 关键约束（否则三项指标不能互校）

1. **两步必须用同一个镜像**（`program.hex`/`data.hex`）与同一棵 RTL。
   镜像内容会进综合（`Loading memory data from file`），换了镜像即换了网表，摆放库就不匹配。
2. **PLL 常数在第一步就要定好**（`--pll-freq`），第二步不再改。
3. 第二步是**一个独立构建目录**，位流、资源报告、时序报告都出自它 —— 满足
   "三项指标出自同一份实现"。
4. 摆放库文件：`<第一步 build>/place_route/pangoriscv_top_plc.adf`。
   **不是 `prr.db`** —— 传 `prr.db` 会报
   `Flow-0013: The input DB 'prr.db' should be of phase 'PLC'`。
   传 `pangoriscv_top_plc.adf` 则直接跳过摆放、进入 `Routing started`（验收过）。

## 命令

```bash
# 第一步：120 MHz 约束，只摆放（PLL 已是交付频率）
python tools/run_pds_flow.py --tag po120_p60 --freq 120 --pll-freq 60 \
    --mode full --place-only --image build/native_software/coremark/performance/hw_i3200_60

# 第二步：交付周期布线，从第一步的摆放库出发（用 .adf，不是 prr.db）
python tools/run_pds_flow.py --tag p60step2 --freq 60 \
    --mode full --image build/native_software/coremark/performance/hw_i3200_60 \
    --place-db build/po120_p60/place_route/pangoriscv_top_plc.adf
```

## 必查

- 第二步一进 pnr，先看 `Worst slack after placement` 是否**按交付周期**算的
  （60 MHz 下 14.12 ns 的路径应报 ≈ +2.5 ns，而不是 −5.785）。若仍报 −5.785，
  说明 FDC 没有重新生效，这个流程不成立，立刻停，别浪费 3 小时布线。
- 收敛后核对 `multiseed_summary.csv` 的 `slack value` ≥ 0、`Unrouted nets` 归零，
  再用 `report_timing.rtr` 复核 setup/hold 无失败端点。
