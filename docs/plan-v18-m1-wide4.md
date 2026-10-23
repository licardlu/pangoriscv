# v18 —— M1 实施计划（4 发射 + 16 B/拍取指），分支 `exp/wide4`

日期：2026-10-23
状态：**M1-S1 已落地并单测通过；M1-S1 本身会让分数降 1.8%，必须等 M1-S2/S3 一起才交付**
上游：`plan-v16-120mhz-spec.md`（ILP 定标：4 发射/2 存储口/4 条取指 = IPC 2.43 → 5.86 @120 MHz）
交付分支：`exp/pair45`（50 MHz / 5.248 / LUT 17,174）**冻结，不动**

---

## 0. 为什么从取指开始

v16 §3 的模型说得很硬：**4 发射若取指仍只有 2 条/拍，IPC 被钉在 2.000，分数只有 5.46**；
取指加到 4 条/拍才拿到 5.86。所以取指带宽是**闸门**，先做它，而且它单独可验证（有 I$ 单测）。

## 1. 拆分（每步都有独立判据，不合格就停）

| 步骤 | 内容 | 判据 | 状态 |
|---|---|---|---|
| **M1-S1** | `icache_axi` 两 bank（even/odd）→ **四 bank（word[1:0]）**，新增 128 bit `rsp_data_quad`/`rsp_quad` 输出 | `run_icache_tests.py` 1/1 PASS | ✅ 已做（`5176f90`）|
| **M1-S2** | `ifu_axi` 按 **16 B 对齐**发请求、**一次 push 4 条**、队头按 offset 对齐 | 20 迭代 `ticks ≤ 3.70 M`（要优于交付的 3.8107 M）、CRC 全对 | 待做 |
| **M1-S3** | `rv32_top` **4 槽发射/退休**（4 个译码槽、2 个存储槽、4 路旁路、4 槽 kill） | `ticks ≤ 2.90 M`（≥6.9 分）、ISA 20/21 | 待做 |
| M1-S4 | 面积与时序复核 | LUT ≤ 27k、50 MHz 约束下 WNS ≥0 | 待做 |

## 2. M1-S1 的实测结果（重要：中间态是负收益）

| 项 | 交付 RTL | **M1-S1** |
|---|---|---|
| I$ 单测 | 1/1 PASS | **1/1 PASS** |
| `Total ticks`（20 迭代）| 3,810,700 | **3,879,898（+69,198，−1.8% 分数）** |
| 分数 | 5.2484 | 5.155 |

**原因（已经算清，不是玄学）**：四 bank 让"一次读出 16 B"成为可能，
但**当前 IFU 仍然只取 2 个字**，而四 bank 换来一个代价：
`word[1:0]==3`（即 word 3→word 4）跨了两个 16 B 组，单端口 LUTRAM 一个周期读不出两个 entry，
这一档的配对没了。实测代价 5,200 拍/迭代。

⇒ **M1-S1 不可单独交付**，它必须和 M1-S2 一起上：M1-S2 把"16 B 对齐 + 一次 push 4 条"做完后，
word 3 与 word 4 **同时躺在队列里**，配对从"第二次读 I$"变成"队列内相邻项"，
不但补回这 1.8%，还会因为"每 4 个字只发一次请求"而净赚。

## 3. M1-S2 的具体设计（下一轮照此实现）

```
请求地址        aligned = {fetch_ptr[31:4], 4'b0}      // 16 B 组，不再是 8 B
响应            用 rsp_data_quad[127:0]，四条指令 = lane0..lane3
push            一次写 4 个队列项：pc = aligned+0/4/8/12
队头对齐        队列第一项不是 fetch_ptr 时，把 head_q 前移 (fetch_ptr[4:2]) 项，
                这 (offset) 项必须同时从 count_q 里扣掉（否则 head_lost 会误判成"队列丢了"）
push 计数       push_cnt = 4（不再是 2）；reserved 的预留量随之从 2 变成 4
prefetch 指针   packet_next = aligned + 16（除非四条里有被预测跳转的，取它的 target）
```

⚠️ **两个坑（先写在这里，省下一轮的时间）**：
1. `head_lost = !empty && !redirect && (ocnt==0) && (stale==0) && (head_pc != fetch_pc)`：
   一次 push 4 条再做 offset 前移，**必须让 count_q/head_q 在同一个 always 块里一次算对**，
   否则会命中 `head_lost` 分支，整队清掉，变成"每拍重新取指"的死循环（现象：ticks 爆到 1 M/迭代）。
2. `pair_adj` 判的是 `q_pc[head+1] == q_pred[head]`：push 4 条时第 2/3/4 项的 `q_pred`
   要用 `chain2_next/chain3_next/chain4_next`（预测器端口 4 目前没有），
   最省的办法是**先只支持"四条全顺序"**（q_pred = pc+4），把被预测跳转的那一条后面截断，
   跳转走原来的 redirect 路径 —— 这样不碰预测器，代价是很小的（跳转本来就靠预测链预取）。

## 4. 风险（沿用 v16 §8，按本轮认知更新）

| 风险 | 概率 | 对策 |
|---|---|---|
| S2 做完后 ticks 仍不如 3.8107 M | 中 | S2 单独就有判据（≤3.70 M），不达标就不进 S3 |
| S3（4 槽退休）引入死锁 | 中高 | ISA 21 用例 + CoreMark CRC 双判据；按 v16 建议复用 `hold_ex` 机制 |
| 4 槽旁路网络把 20 ns 通路拉长 | 高 | S1/S2 不动通路；S3 之后先跑 `place_only` 看摆放 WNS（7 min） |
| 26.6k LUT 在 120 MHz 布不通（v16 的头号风险）| 高 | 到 S4 再用真实实现回答；不行退 100 MHz |

## 5. 复现命令

```bash
# M1 分支
git checkout exp/wide4
cd firmware/code
python sim/run_icache_tests.py --modelsim "D:/FPGA_Project/Modelism/win64"   # 1/1 PASS
python tools/run_coremark_sim.py --image build/native_software/coremark/performance/sim20_O2 --tag m1
# 当前判据：ticks 3,879,898（S1 中间态，负收益 1.8%），CRC 必须 0x4983
```

---

## 6. M1-S2 第一次尝试（2026-10-23 21:20）：功能对了，性能不对

**做了什么**：ifu_axi 加 `QUAD` 参数（默认 0，单测台不受影响）：
`fetch_ptr` 落在 16 B 边界时一次 push 四条（`push4`），预留 4 个槽，队列深度 8→16，
prefetch 指针按 +16 B 前进；顶层 `ifu_axi #(.DEPTH(16),.QUAD(1))` 打开，I$ 的
`rsp_data_quad` 接进来。

**结果**：

| 项 | 交付 | S1（只改四 bank）| **S1+S2** |
|---|---|---|---|
| `Total ticks` | 3,810,700 | 3,879,898 | **4,545,765（+19%）** |
| `crcfinal` | 0x4983 | 0x4983 | **0x4983（功能对！）** |
| `mispred`（20 it）| 46,285 | 46,285 | **140,677（3×）** |
| IPC | 1.5095 | — | 1.0921 |

**原因（很清楚）**：push 的第 3、4 条只能给"顺序预测"（`q_pred = pc+4`），因为预测器
只被问了 `fetch_ptr` 与 `fetch_ptr+4` 两个点。于是**落在第 3/4 个字上的条件跳转全部变成误预测**，
误预测翻三倍，省下的取指周期被重定向吃光还倒亏。

⇒ **S2 必须先把预测器链从 2 个查询点扩到 4 个（`base+0/+4/+8/+12`）**，
否则 16 B 取指是净亏。这也解释了 `mispred` 为什么是这条路上最敏感的指标：
它是唯一一个"取指变宽后会被放大"的量。

### 6.1 顺带修掉的一个真实 bug（值得记住）

`tail_q<=tail_q+push_cnt[AW-1:0]`：`push_cnt` 是 3 bit，而 DEPTH=16 时 `AW=4`，
`push_cnt[3]` **越界取值 = X**，于是 `tail_q`/`count_q` 一路变 X、队列分发出 X、
`deq_cnt` 变 X，CoreMark 在第 2 条指令就 STALL 死掉（`retires=2`）。
**Verilog 对越界位选不报错**，只有跑仿真看波形才抓得到 —— 判据是 `%b` 打出 `0x`。

### 6.2 状态

**已回退到 S1**（分支 `exp/wide4` 干净、可编译、CRC 正确），S2 的代码没有留下，
避免分支上挂着跑不动的东西。下一轮按 §6.3 做。

### 6.3 S2 重做清单（按顺序）

1. `branch_predictor` 加**第 4、5 号查询端口**（`fetch_pc4/fetch_pc5`）。这块是触发器阵列，
   加端口只是多一组 index/tag 比较，不是多一个 RAM 口（模块头注释里已经这么写过）。
2. `ifu_axi` 加 `chain_c3/chain_c4` 输出与 `chain_predict_next_pc3/4` 输入，
   每个 outstanding 请求存 `pdf0_q3/pdf0_q4`（预测点 `base+8` / `base+12`）。
3. push4 的第 3/4 条用真预测值，并按"第一个被预测跳转"截断；
   prefetch 指针在截断时跟到那个 target，否则 +16。
4. 判据不变：`ticks ≤ 3.70 M`、CRC 0x4983、ISA 20/21。
