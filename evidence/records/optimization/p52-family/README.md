# 52 MHz 家族原始时序证据（9 次满流程）

**为什么单独归档这一组**：项目里有一条被反复引用的结论 ——
**"同一棵网表换不同布线配方，结果逐位相同；所以重跑不会产生新抽样"**。
这条结论此前只有文档里的表格（`docs/plan-v23-area-and-freq.md` §7、§9），
**没有原始 `report_timing`**。评审或接手的人无法自行核对，因此把 9 次满流程的
`multiseed_summary.csv` + `report_timing/pangoriscv_top.rtr` 全部入库（合计 1.2 MB）。

## 汇总（数字全部取自各目录的 `multiseed_summary.csv` 的 `single` / `Used` 行）

| tag | RTL 树 | 声明周期 | pnr 配方 | setup **WNS** | hold WHS | LUT | 布线轮数 | 判定 |
|---|---|---|---:|---|---:|---:|---:|---|
| `p48r50` | 交付树前身 | 19.231 ns | 默认 | **−2.555** | +0.013 | 17,103 | 707 | ✗ 鞭子时钟 |
| `p48r50b` | 交付树前身 | 19.231 ns | 默认 | **−3.188** | +0.027 | 17,103 | 207 | ✗ |
| `p50cut2` | cut-2 | 20.000 ns | 默认 | **−1.717** | **−0.060** | 17,021 | 673 | ✗（hold 也破）|
| `p50r52` | cut-2 + P57 | 19.231 ns | 默认 | **−0.991** | +0.021 | 17,152 | 206 | ✗ |
| `p59r52` | cut-2 + P57 | 19.231 ns | 四选项 | **−0.991** | +0.021 | 17,152 | 206 | ✗ **与 `p50r52` 逐位相同** |
| `p61r51` | cut-2 | 19.608 ns | 四选项 | **−0.170** | +0.004 | 17,235 | 143 | ✗ 放松约束反而更差 |
| `p62r52` | cut-2 | 19.231 ns | 三选项 | **−0.195** | +0.025 | 17,027 | 186 | ✗ 全族最好，仍差 0.195 ns |
| `p63r52` | cut-2 | 19.231 ns | 三选项 + 去拥塞 | **−0.195** | +0.025 | 17,027 | 186 | ✗ **与 `p62r52` 逐位相同** |
| `p64r50` | cut-2 | 20.000 ns | 三选项 | **−1.717** | **−0.060** | 17,021 | 673 | ✗ **与 `p50cut2` 逐位相同** |

## 三组"逐位相同"的对照（这才是这一组证据的价值）

| 对照 | 差异 | 结果 |
|---|---|---|
| `p50r52` vs `p59r52` | 只加 `-dc_duplication/-slack_prior_in_global_router/-refineplacement_cluster/-optimize_routing_recovery` | WNS、WHS、LUT、布线轮数 **完全相同** |
| `p62r52` vs `p63r52` | 只加 `-plc_decongestion 1 -share_router_control_signal TRUE` | **完全相同** |
| `p50cut2` vs `p64r50` | 只换布线配方 | **完全相同** |

⇒ 三次独立对照都指向同一件事：**在这些选项不改变逻辑与摆放的前提下，布线是确定性的**。
"再跑一次"、"换个 seed"、"多等一会"都不会产生新的抽样 —— 想换抽样只能**扰动网表**。

`p62r52` 的 −0.195 ns 就是全族离 52 MHz 最近的一次，同一配方已归档在
`../p58r52/`（WNS −0.195、失败端点 12）。四个文件（`p58r52`、`p62r52`、`p63r52`）
互相印证：**52 MHz 在这套微架构上的地板是 19.426 ns，差 0.195 ns**。

## 复现

```bash
python firmware/code/tools/run_pds_flow.py --tag <tag> --freq 52 --mode full \
    --image build/native_software/coremark/performance/hw_i2900_52b \
    --pnr-extra "-dc_duplication TRUE -slack_prior_in_global_router TRUE -refineplacement_cluster TRUE"
```

判定用 `firmware/code/tools/check_delivery.py --build build/<tag> --freq 52 --ticks 3810700`
（九门，已双向验证：交付 PASS / `p58r52` FAIL）。
