# 前端优化契约（I-Cache 连续命中吞吐 + IFU 同拍收旧发新）

> 阶段二的前置文件。**先写契约、先写契约级测试，再改独立副本里的 RTL**；生产源码
> `firmware/code/rtl/**` 本轮一行不动。外部接口信号保持不变，**不实现**“旧响应长期未返回时
> 继续发请求”的多在途机制（单槽同拍替换）。

## 1. 契约条文（对应需求 1–7）

| # | 条文 | 落地判据（可测） |
|---|---|---|
| C1 | I-Cache 旧响应被接收的**同拍**可以接收新请求 | `req_ready` 在 `IC_RESP && rsp_valid && rsp_ready` 时可为 1；连续命中时每拍接受一条 |
| C2 | IFU 旧响应被接收的**同拍**可以发送下一请求 | `eng_req_valid` 在 `S_WAIT && rsp && rsp_ok` 时可为 1；连续命中且下游可接收时每拍一条 |
| C3 | 旧响应必须用**旧 PC / 旧预测信息**；新请求元数据在时钟沿更新，不得串配 | 每个返回指令的 payload 必须等于其**请求地址**的函数；每次 `result_pc` 与 `result_inst` 严格配对；`req_pc_q/req_pred_q` 只在该请求自身被接受的那一拍更新 |
| C4 | miss 仍走原有阻塞补行路径；正确处理连续 hit、hit→miss、miss→hit | miss 时 `state` 进入 `IC_AR/IC_FILL/IC_MISS_RD`，期间不再接受请求；命中计数与 miss 计数与实际地址序列一致 |
| C5 | 响应背压时 `rsp_valid`/数据保持稳定，不覆盖未消费响应 | `rsp_ready=0` 期间 `rsp_valid` 持续为 1、`rsp_data/rsp_resp` 不变；此时**禁止**接受新请求（`req_ready=0`） |
| C6 | 为新请求**预留队列槽**，同拍入队/出队/占槽的计算要写清 | `eng_req_valid` 需要 `!full`（单在途前提下，一个请求从发出到响应之间不可能有第二次 push，故 `!full` 即保证响应到达时仍有槽）；`count_q <= count + push - deq` 不变 |
| C7 | redirect / 取指错误 / invalidate / halt·reset 的优先级明确；**旧响应报错时不得继续推进年轻请求** | 优先级：`!rst_n` > `redirect_valid｜!enable` > `head_lost` > 正常；同拍发新请求要求 `rsp && !stale_q && eng_rsp_resp==0`；`invalidate` 期间不清在途响应（miss 补行由 `fill_kill` 处理） |

## 2. 组合路径审查（不引入组合环、不加跨 Cache 到 CPU 的长组合路）

**信号依赖链**（必须保持无环）：

```
icache.req_ready  <- icache.state, icache.rsp_valid(reg), icache.rsp_ready
icache.rsp_ready  = ifu.eng_rsp_ready <- ifu.state(reg)
ifu.eng_req_valid <- ifu.state(reg), ifu.rsp_ok(=eng_rsp_valid & eng_rsp_resp & !stale_q(reg)), full(reg)
icache.req_valid  = ifu.eng_req_valid   （组合，单向）
ifu.eng_req_ready = icache.req_ready    （组合，单向：req_ready → eng_req_ready）
```

`req_ready` 依赖 `rsp_ready`（输入），而 `rsp_ready` 只依赖 IFU 的状态寄存器 ⇒ 不存在
`req_ready → req_valid → rsp_ready → req_ready` 的环。**禁止**把 `icache.rsp_data` 组合穿到
CPU 的 `fetch_valid` 路径上：本方案里 `rsp_data` 只进 IFU 的队列寄存器，`fetch_valid` 仍由
`head_match` 决定。

## 3. 测试分层

1. **契约级（新增）**：`tb/unit/tb_icache_contract.sv`、`tb/unit/tb_ifu_contract.sv`，
   逐条覆盖 C1–C7（含背压保持、错误响应、hit→miss→hit、队列边界、halt/reset）。
2. **旧单元测试**：允许修改**固定延迟假设**（例如 `tb_ifu_axi.sv` 的 engine 模型必须支持
   “同拍收旧发新”），**不得删除或弱化**：顺序正确、无重复、无丢失、背压稳定、错误响应、
   重定向、队列边界、halt/reset 检查。
3. **整机**：`tb_isa_e2e`（15 用例）、`tb_pipeline`、`tb_halt_reset_drain`、`tb_dcache_axi`、
   `tb_lsu_axi`、`tb_axi_*` 全回归 + CoreMark 五 CRC。

## 4. 验收（括号内为本轮实测，详见 `T4_frontend_results.md`）

- 连续预热命中 + 下游可接收：**每拍接受一条请求**（实测 `ICACHE_CONTRACT accepts=20/20`）。
- ALU 微程序（直线、无分支、无访存）：`cycles/指令` 从 **2.03** 向 **≈1.0** 靠（实测 **1.01**）。
- CoreMark 同镜像 A/B（performance 1 次迭代，803,230 拍为基线）+ 五 CRC 全同（实测 701,500 拍 = **−12.66%**，五 CRC 全同；validation 镜像 804,633 → 702,231 = **−12.73%**）。
- 仿真先通过，再做 PDS 时序/资源与上板（两套独立干净 work 库各一）：
  PDS **All Constraints Met**（Setup slow 17.131 ns、Hold slow 0.103 ns；LUT 12,406 / FF 7,268）；
  板上 400 次迭代 **1.4288 CoreMark/MHz**（基线 1.2472，**+14.56 %**，`Total ticks` 320,725,708 → 279,957,350），五 CRC 逐项相同。
- **不预先承诺收益百分比**；若单槽同拍替换达不到目标，先报告阻碍，再讨论是否升级为两笔在途（未发生，单槽同拍替换已达标）。

## 5. 改动清单（仅副本 `frontend_opt/src/`）

| 文件 | 改动 |
|---|---|
| `rtl/core/icache_axi.v` | ① `req_ready` 增加 `IC_RESP && rsp_valid && rsp_ready` 分支；② 把 accept 逻辑从 `IC_IDLE` 分支提出为公共块，供 `IC_IDLE` 与 `IC_RESP` 同拍使用 |
| `rtl/core/ifu_axi.v` | ① 新增 `slot_free = (state==S_IDLE) || (state==S_WAIT && rsp_ok)`；② `eng_req_valid` 用 `slot_free`；③ `issue` 分支在 `S_WAIT` 时保持状态并更新 `req_pc_q/req_pred_q/next_pc_q` |
| 其余 RTL | 不动 |
