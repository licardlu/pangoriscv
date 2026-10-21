# 5.2 CoreMark/MHz + 120 MHz 执行计划 v6（访存为主，一步一测）

> 起点 = R5 已落地（`cb9b281`，tag `p9i`）。v5 的结论不再重复，本文件只回答两件事：
> **剩下 672,200 个 tick 从哪来**、**16.09 ns 的路径怎么砍到 8.33 ns**。
> 每条改动仍然只碰一个模块，改完立刻量，量不过就回退。

## 1. 起点实测（同一份 RTL、同一镜像 `sim20_o2`、20 迭代）

| 项 | 值 | 来源 |
|---|---:|---|
| `Total ticks` | 4,518,354 | `p9i` 仿真 |
| CoreMark/MHz | **4.427** | `20 / ticks × 1e6` |
| `cycles` / `retires` / IPC | 6,403,281 / 7,027,447 / 1.0975 | 同上 |
| 计分窗 | `cycles=4,539,252` `retires=5,782,458` `no_retire=871,904` | `SCORE_WINDOW` |
| 计分窗 IPC | 1.2739（上限 2.0） | 5,782,458 / 4,539,252 |
| `mem_wait` | 1,268,139 | `STALLDBG` |
| 五项 CRC | 全对（`0x4983`） | 同上 |
| LUT / FF / LUTRAM / DRM / APM | 17,369 / 7,576 / 3,684 / 8 / 6 | `build/p9synth126` |

## 2. 两个缺口，都换算成同一把尺子

```
分数：ticks 4,518,354 → 3,846,154（5.2）      ⇒ −672,200 tick
      相当于把 no_retire 从 871,904 压到 199,704（−77%）
频率：路径 16.09 ns（126 MHz 综合 WNS −8.156）→ 8.33 ns（120 MHz）  ⇒ −7.76 ns
```

**先做分数，再做频率**，理由和 v5 一样：分数是主指标，且访存改动会改变时序。
频率阶段只用 100 MHz 约束取路径表（教训 §37：126 MHz 约束跑不完布线）。

## 3. 已经量到的 mem_wait 三分（`p9i`，已扣掉"本来就该等的"）

| 项 | 周期 | 每次 | 含义 |
|---|---:|---:|---|
| `rdwait` | 584,037 | 4.60 | 自己那次 refill 在等 AXI（126,908 次 refill） |
| `request_load` | 499,707 | 3.94 | load 被 cache 拒收（`req_ready=0`） |
| `request_store` | 185,526 | — | store 被拒收（队列满） |
| 合计 | 1,268,139 | | 与 `STALLDBG mem_wait` 相符 |

配套：`DCACHE_PATH drain=2,079,603`（全程序 32%）、`refills=126,908`、
`axi_d_aw=410,588`（一次 store 一次 AXI 写，写通）、`axi_d_ar=126,937`。
`ST_WR_DRAIN` 每 store 5.06 拍 ⇒ **写路径吞吐 410,588 × 5 = 2.05 M 拍**，
这是 `dcache_axi` 读写共用 `state_q` 的直接后果。

## 4. 先量后改：D1 诊断（不改 RTL，只加测试台探针）

上面三分还不够决定"改哪一刀"，因为 `request_load` 的 500 k 到底是
"被 drain 挡住"还是"被另一个 miss 挡住"，读数一样。所以先跑一次纯探针仿真：

| 探针 | 回答的问题 |
|---|---|
| 拒收时的 `data_cache.state_q` 直方图（load / store 分开） | 500 k 里有多少是 drain 造成 |
| store 命中/未命中计数 | 写回（write-back）值不值得做 |
| 一次 miss 的 CPU 侧代价直方图（accept→rsp） | early-restart 能省几拍 |
| refill 期间同 line 再访问的次数 | in-flight 转发值不值得做 |

判据（写死在计划里，避免"改完再想为什么"）：
- 若 `request_load` 中 ≥ 60% 落在 `ST_WR_DRAIN/ST_WR_POST` ⇒ 打写路径（R6 走 4.2a）；
- 若 refill 平均 CPU 代价 ≥ 8 拍且同 line 追赶 ≥ 20% ⇒ early-restart + 转发（4.2b）；
- 若 store 命中率 ≥ 60% ⇒ write-back 有明确收益（4.2c）。

## 5. 模块清单（一次提交只动一个模块）

| 序 | 模块 | 改动 | 目标 | 预计 | 面积 |
|---|---|---|---|---|---|
| **R6** | `dcache_axi` | **写路径吞吐**：读状态机与写 drain 分离，且一拍接纳一个 store（写引擎改为 AW/W 流水 + 按 id 收 B），把 5.06 拍/store 压到 1–2 拍 | 分数 | −0.5 ~ −1.0 M 周期 | FF +~60，LUT 中性 |
| **R7** | `dcache_axi` | **早响应 refill**：AR 从被请求的那个字开始（线内旋转），第一个 beat 到达就回 CPU，其余 7 拍后台填；fill 期间同 line 的访问从已到的 beat 转发 | 分数 | −0.3 ~ −0.6 M 周期 | FF +~40 |
| **R8** | `perips/axi_ram` | 数据 RAM 从"IDLE→WAIT→DRAIN→RESP"四态改成写后可连续接纳，去掉每写的固定 2 拍气泡（仅在 R6 之后仍是瓶颈才做） | 分数 | −0.2 M 周期 | 0 |
| **R9** | `rv32_top` | 时序：寄存器堆读搬到 RD 级 / 误预测比较寄存一拍 / lane1 ALU 挪到 M1（按 100 MHz 路径表选，不按顺序全做） | 频率 | 每条 −1.5 ~ −3 ns | +~260 FF |

顺序硬性：**R6 → R7 →（R8）→ 分数验收 → R9**。
R6/R7 都是 `dcache_axi`，但**分两次提交、两次测量**，否则分不清谁起作用。

## 6. 面积纪律

- 起点 17,369 / 7,576 / 3,684，门禁 `Δ(LUT+FF+LUTRAM) ≤ 0`，
  收尾跑 `check_area_budget.py`。
- 缓存阵列已经是 LUTRAM 映射（2 KB = 3,684 LUTRAM 的大头），
  **不许靠扩大 cache 换命中率**——`SETS 32→128` 会加约 11 k LUTRAM，直接破门禁。
  这条写进"不做什么"。
- DRM 8 / APM 6 不动。

## 7. 验收顺序（每步都跑，不许跳）

1. `run_coremark_sim.py --image sim20_o2 --define RV32_DEBUG` →
   `Total ticks` 折分、五项 CRC、`STALLDBG`/`MEMWAITDBG`。
2. `run_isa_e2e.py` 全 21 例（基线 20/21，新红即回退）。
3. `run_pds_flow.py --freq 126 --mode synth` → 面积（时序要 `--mode full`）。
4. 频率：`--freq 100 --mode full` 取路径表，改完复测；收敛判据见 §37
   （`All Constraints Met` 且 WNS 接近 0，Route < 70%）。
5. 结论写 `evidence/records/optimization/<阶段>/measurement.md`；教训回写 `mistakes-log.md`。

## 8. 不做什么（明确排除）

- **不**扩大 cache 容量换命中率（LUTRAM 门禁）。
- **不**做 MSHR/多 outstanding refill：AXI 从设备（`axi_ram`）单 outstanding，
  多 MSHR 只会把等待搬个地方。
- **不**为 ns 牺牲配对（`PAIRGAP` 的 pair 数不许掉）。
- **不**用"满足式宽约束"证明频率（§37）。
- **不**在没有 `Total ticks` 读数的情况下声称分数变化。

## 9. 执行记录

（随执行追加，见文末"执行结果"一节。）
