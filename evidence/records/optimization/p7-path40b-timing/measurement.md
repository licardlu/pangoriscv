# p7_path40b — 已布通的 40 MHz 实现，用来看"关键路径长什么样"

`pangoriscv_top.rtr` 是 `report_timing` 对 `p7_path40b/place_route/pnr.db` 的完整输出
（38 秒，不重新布线）。约束 25 ns，RTL 是 `0842e48` 之前的一版（计数器还没拆）。

## Performance Summary

```
core_clk   Requested 40.0002 MHz   Estimated 37.5278 MHz   Period 24.9999 -> 26.6469   Slack -1.647
Setup(slow): WNS -1.647  TNS -12.927  Failing endpoints 43 / 69,277
Hold (slow): WHS +0.019  Failing 0
```

**43 / 69,277 个端点不满足** —— 不是全局慢，是有少数几条病态路径。

## 最差路径（39 级）

```
w_rd_h[4]  ->  rd_valid_h / u_regs/N41 (fanout 65, route 1.370 ns)
           ->  fwd2[15]
           ->  u_mul  APM/PO -> APM/P  x2      (~9.0 ns, 两跳 APM 级联)
           ->  u_alu_h N1.slt_* COUT 链        (32 b 进位链, 分支比较)
           ->  br_taken_h (fanout 33)
           ->  ex_next_h COUT 链               (32 b 下一 PC 加法器)
           ->  N665.eq_* COUT 链               (32 b 相等比较, 预测校验)
           ->  br_miss_h (fanout 133, route 1.715 ns)
           ->  perf_if_wait
           ->  cnt[2][0..60]/CECO x16          (16 x 0.136 = 2.18 ns)
           ->  cnt[2][63]/CE
```

`Logic 11.345 ns (43.477%) / Route 14.749 ns (56.523%)`。

## 可复用判据

1. 终点是 `perf_*/cnt[*]` 的路径不是 CPU 的路径：事件抽头（`perf_if_wait`）前面挂着
   一整坨组合逻辑，计数器 CE 后面还有 16 级 CECO 链。**把事件抽头打一拍**就能把
   这一整段从关键路径上切掉，代价 1 个 FF/抽头。
2. 三个 32 位加法器串在一拍里（ALU 比较、下一 PC、预测校验）。下一 PC 的加法
   其实不依赖 ALU 结果（`pc + imm`），可以并行算，只让最后一拍 mux 依赖 `br_taken`。
3. 高 fanout 控制信号（`br_miss` 133、`rd_valid_h` 65、`fwd2` 48）的 route 单项
   就 1.0~1.7 ns，占整条路径的 5~8%。
