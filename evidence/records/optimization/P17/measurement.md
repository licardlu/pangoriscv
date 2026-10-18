# P17 · 修 LRU 漏更新 + 证据链重建（2026-10-18 下午）

> ## ⚠️ 成绩有效性声明
> 本文件的 CoreMark 分数来自 **RTL 周期精确仿真**，不是 FPGA 板上实测。
> 按仓库策略（`.githooks/pre-push`、`.gitignore`）与赛题 §4/§7：
> **仿真跑分不是有效成绩，不得作为提交成绩使用。**

> **这一轮不是新的性能优化，而是两件事**：
> 1. 修掉独立复核提出的 **R03**——我在 P10 引入的 LRU 漏更新回归；
> 2. 按复核意见重建证据链：27/50 MHz 各自独立目录、slack 改引
>    `multiseed_summary.csv` 收尾值、LUT 标明 device_map 阶段。

---

## 1. R03：P10 的快命中路径跳过了 LRU 更新（我的回归）

**根因**：P10 把"响应被当拍接走"的分支从 `ST_HIT` 改成直接回 `ST_IDLE`，
而 LRU 更新写在 `ST_HIT` 里：

```verilog
ST_HIT: begin
    resp_q <= 2'b00;
    lru_mem[set_wr_q] <= hit_q ? ~hit_way_q : ~fill_way_q;   // ← 快路径再也到不了这里
    if (rsp_valid && rsp_ready) state_q <= ST_IDLE;
end
```

LSU 在受理拍几乎总是 ready，所以**绝大多数命中都不更新替换信息**，
文档里声称的"2 路 LRU"实际退化。

**修法**（`rtl/core/dcache_axi.v`，4 行）：在 `ST_IDLE` 的受理分支里补同值更新：

```verilog
lru_mem[req_set] <= hit_way ? 1'b0 : 1'b1;
```

`ST_HIT` 保留原更新（重复写同值无害，覆盖被反压的那条路径）。

**效果**：`d_miss` **4,655 → 4,270（−8.3%）**；`ticks` 7,478,647 → 7,471,073（−0.10%）。
`d_miss` 降幅远大于 ticks 降幅是对的——D-Cache 缺失本来只占 ~1.4%。

## 2. 重新出分（768 迭代）

| 项 | P16（修前） | **P17（修后）** |
|---|---|---|
| ticks | 287,211,317 | **287,030,751** |
| cycles / retires | 288,997,740 / 222,179,042 | 288,817,154 / 222,179,042 |
| IPC | 0.7688 | **0.7693** |
| 每迭代 ticks | 373,973 | **373,738** |
| 运行时间（27 MHz） | 10.637 s | **10.631 s** |
| **CoreMark/MHz** | 2.6740 | **2.6757** |
| 五项 CRC | e9f5/e714/1fd7/8e3a/3c53 | **完全相同** |
| validated / traps / faults | True / 0 / 0 | **True / 0 / 0** |

迭代下限 = `ceil(10.5 × 27e6 / 373,738) = 759`，实取 768 → 10.631 s，满足 ≥10 s。

## 3. 证据链重建（对应复核 C05 / C06 / C07 / C14）

复核指出的问题：我把同一个 `build/pango_native` 先后用于 27 MHz 和 50 MHz，
第二次覆盖第一次，导致交付位流没有对应的实现目录；而且我引用的 slack 来自
`place_route/*_after_hold_fix.txt`（**中间快照**），不是官方收尾值。

这一轮改为：**一个实现 = 一个独立目录 + 全套原始产物**。

| 目录 | 内容 |
|---|---|
| `pds_27mhz_full/` | 位流 + `multiseed_summary.csv` + `report_timing.rtr` + `device_map`/`synthesize`/`place_route`/`compile` 日志 + 中间快照（留作对照） |
| `pds_50mhz_full/` | 同上（50 MHz 过约束） |
| `pds_50mhz_full_p16/`（见 P16 目录） | 上一版实现的 50 MHz 全套 |

**权威值（取自各自 `multiseed_summary.csv` 的 `single` / `Used` 行）**：

| 约束 | All Constraints Met | Setup(Slow) | Hold(Slow) | 失败端点 | LUT（device_map） |
|---|---|---|---|---|---|
| 27 MHz | ✔ | **+14.578 ns** | **+0.115 ns** | 0 | **13,481** |
| 50 MHz 过约束 | ✔ | **+1.262 ns** | **+0.121 ns** | 0 | 13,637 |

**LUT 三个阶段（同一实现）**：synthesis **13,574** / device_map **13,481** / 后布线更小。
③ 采用 device_map：**2.6757 / 13.481 = 0.1985 CoreMark/kLUT**。

> **中间快照 vs 收尾值**：本版 27 MHz 的 `*_after_hold_fix.txt` 写 setup 17.390，
> 而收尾 `multiseed_summary` 是 +14.578 —— 最后一道优化用 setup 换了 hold。
> **引 slack 只能用 multiseed。** 这条已写进 `docs/lessons/evidence-rules.md`。

**交付位流**：`bitstream/pangoriscv_i768.sbit`，3,791,112 B，
SHA256 `0878A35D1D1371209C4E6987F43DB535A54300DDAC15E21A9D9F69A77B3E7B0F`
（= `pds_27mhz_full/pangoriscv_top.sbit`，逐字节相同）。

## 4. 回归

| 门 | 结果 |
|---|---|
| `run_unit_tests.py --case all` | 5/5（含 `lsu_axi` 与 `dcache_axi`） |
| `run_dcache_tests.py` | PASS |
| 768 迭代 CoreMark | PASS，五项 CRC 与修前逐项相同 |
| `run_isa_e2e.py --cases all` | 15/15 |
| `run_ram_tests.py --seeds 20` | 40/40 |
| `run_halt_reset_tests.py` | 5/5 |

## 5. 仍然 OPEN 的（不在本轮范围，见问题总表）

- **C01 上板实测**：没有 i768 的板载串口输出 —— ① 因此仍不能按赛题报分
- **C02 ILA 波形**：0 份，文档评分项缺失
- **C03 应用场景**：0 处
- **C04 赛题工具链**：全部镜像用 xPack GCC 15.2.0，板上基线是 GCC 7.1.1
- **C08 署名/许可证**：README/LICENSE 与 provenance 记录冲突（历史遗留）
- **R01/R02**：D-Cache 两处功能缺陷（store 空洞吞 fault、MMIO byte 读 SLVERR）
- **D01/D02/D03 等**：旧数值文档刷新

完整清单：`docs/verification/issue-register-2026-10-18.md`。
方法论教训：`docs/lessons/`。
