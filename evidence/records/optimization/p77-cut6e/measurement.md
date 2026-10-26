# P77 —— cut 6 变体 E：关键路径上 4.77 ns 的写路径，零拍摘除并**综合成功**

**日期**：2026-10-24 18:50–19:05
**树**：交付树（`232dfa3`）+ `dcache_axi.v` 的 cut-6E 改动（commit `ec4320c`）
**结论**：**RTL 逐位通过（零拍）**；56 MHz 满流程在综合 `rtl-data-opt` 阶段被手动中止，
**没有时序结论，也没有位流，更没上板**。这份 RTL 现在是 `main` 的 HEAD，但**不是**交付位流的源码。

---

## 1. 改了什么

`dcache_axi.v` 里 store 的"合并进 D\$ 阵列"动作，原本发生在**接受沿**、用的是
`didx(hit_way, req_set, req_word)` —— 也就是说写地址等在 tag 比较（`hit_any`）和 5 级 FSM 之后，
再扇出到 **1,024 个 `ram64x1d/WADDR` 引脚**。在 50 MHz 网表的时序报告里，
这一段就是关键路径的第 9–11 段，共 **4.77 ns（占 22.076 ns 的 22%）**，最后一跳
`N4033[0]` 单根线 **2.500 ns（fanout 256）**。读路径完全不需要它。

改法（三条约束同时满足，前两次失败的原因见 `docs/lessons/mistakes-log.md` §102/§103/§104）：

| 约束 | 做法 |
|---|---|
| 写地址必须是**寄存器** | `dwr_idx` 用 `reg`，与 `dwr_data/dwr_strb` 一起在三个接受点锁存 |
| 读路径只能有**一个** `didx()` 表达式 | 抽成命名 wire `rd_idx_acc`，阵列读与旁路比较**共用** |
| 不能碰 `req_ready` | 一拍窗口用**读侧字节合并旁路**（`dwr_same`）补，不拉低握手 |

三处 `ST_WR_REQ/RESP/HOLD` 的重复合并**保留**：它们用的是已寄存地址
（`hit_way_q/set_wr_q/word_q`），不在关键路径上，且防的是"store 接受后、B 回来之前该行被换出又填回"的竞态。

## 2. 功能判定（全部通过）

```
# Total ticks      : 3810700      <- 与交付版逐位相同
# Iterations       : 20
# seedcrc          : 0x54414c55
# [0]crclist       : 0xe714
# [0]crcmatrix     : 0x1fd7
# [0]crcstate      : 0x8e3a
# [0]crcfinal      : 0x4983
# CORE_SUMMARY cycles=5693904 retires=7025918 traps=0 faults=0 uart_chars=684
                txd_writes=683 ctrl=1159899 mispred=46285 pair=2856592
```

* `Total ticks 3,810,700` ⇒ **190,535 拍/迭代 ⇒ CoreMark/MHz 5.2484**，与交付**逐位相同**。
* `cycles 5,693,904`、`mispred 46,285`、`ctrl 1,159,899` 与交付完全相同 ⇒ **零拍成本**。
* ISA e2e：**20 / 21**，唯一失败是 case 21 的覆盖率断言
  `E2E_TARGET_PAIR target=0 wrong=0` —— **交付树同样 0/0、同样 20/21**（lesson 98 的 A/B），
  与本次改动无关。功能判据只认 `TEST_PASS case=<n>` + `E2E_REG` 值 + `Errors: 0`。

证据：`coremark_20it_transcript.txt`、`isa_e2e.log`。

## 3. 实现判定（**未完成**）

| 项 | 状态 |
|---|---|
| 56 MHz 满流程（`build/p77r56cut6E`） | 中止在综合 `rtl-data-opt`，**无 `multiseed_summary.csv`、无 `report_timing`、无位流** |
| LUTRAM 是否回到 2,274 | 未验证（这是"阵列没丢推断"的判据） |
| 上板 | 未做 |

⇒ **这份 RTL 现在只能算"功能已验证、时序未验证"**。它留在 `main`（commit `ec4320c`），
但**交付位流 `board50_i2800_5p248` 的源码是 `232dfa3`，不是 HEAD**（见 `bitstream/README.md` 的溯源表）。

## 4. 下一轮恢复时照这个顺序

1. `run_pds_flow.py --tag <t> --freq 56 --mode full --image .../hw_i3200_56`，
   **先看 `Used` 行的 LUTRAM 是否 2,274**；若掉到 1,250 说明又丢了推断，立刻停。
2. LUTRAM 对了再看摆放 slack；`< +2.5 ns` 基本可以判死（布线还要吃 1.0~2.85 ns）。
3. 布线后 `report_timing` ≥ 0 才谈 56/58 MHz；否则退回 50 MHz 并保留交付位流不动。
4. **上板**：`board_verify.ps1`，需要 `USB Cable II`（FTDI D2XX）在线。
