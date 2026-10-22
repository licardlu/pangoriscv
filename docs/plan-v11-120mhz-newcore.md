
---

## 7. G1 进展（2026-10-22 23:30，可仿真里程碑）

新核 `rtl/core/rv32i6/` 已经能编译、能跑真实固件镜像，前 13 条指令与
旧核黄金轨迹**逐条一致**（PC 与指令字都对），随后在一个 load-use 停顿处失步。
**尚未通过 G1 闸门。**

### 7.1 已经踩过并修掉的三个 bug（都会让核"看起来在跑"但算错）

| # | 现象 | 根因 | 修法 |
|---|---|---|---|
| 1 | `.bss` 清零循环永不死循环，a1 指针不前进 | **取指数据与 PC 差一拍**：`imem_data` 是上一拍地址的数据，却用当拍 `pc_f` 配对 | 加 `pc_q`（存上一拍 PC），PC 与数据用同一个 `pc_q` 配对 |
| 2 | 重定向后执行"错路指令" | 重定向只清了 ID 的 valid，没拦住下一拍的错路数据 | 加 2 深度 `fill` 移位寄存器 + `capture` 门控 |
| 3 | load-use 后流水线排空、彻底挂死 | 停顿语义写反：应该**冻结 ID、给 E 插气泡、让 load 继续进 M**；原先冻结 E 又清 id_valid，结果既丢 load 结果又丢消费者 | 拆成 `stall_lu`（load-use）与 `stall_div`（除法）两种停顿 |

### 7.2 还差的一个结构（下一轮第一件事）

**剩余失步在 load-use 停顿期间的取指**：停顿时 `pc_f/pc_q/fill` 一起冻结，
但 BRAM 仍在按老地址出数据，恢复后 ID 拿到的那一拍与 `pc_q` 不再对应，
于是跳过 0x38 的 store、并在 0x3c 拿到 0x44 的内容。

根治办法不是再打补丁，而是**在取指和 ID 之间加一个小 FIFO（4~8 项）**：
取指永远不停，ID 从队列取，停顿只作用在队列出口。这也是交付核
（`ifu_axi` 的 `q_pc/q_inst`）已经在用的结构——它把"取指"和"消费"解耦，
这一类错位就不会再出现。

### 7.3 G1 验收脚本（已就位，可复用）

```
vlog -sv +incdir+rtl/core rtl/core/rv32i6/*.v rtl/core/rv32/*.v \
     rtl/core/csr_native.v rtl/core/div*.v tb/unit/tb_rv32i6.sv
vsim -c tb_rv32i6            # 写 rv32i6_trace.txt（每条退休一行）
python tools/diff_trace.py   # 与 .sim_runs/coremark_sim/<tag>/retire_trace.txt 按序比对
```
比对比的是**同镜像**的黄金轨迹：镜像不同（`sim20_O2` vs `hw_i2700_45`）代码布局
会变，第一次比对就因为拿错镜像而误判过，记在这里。

## 8. 电脑性能监控（用户要求）

见 `evidence/records/optimization/p16-redirect-and-routing/measurement.md` §7 与
`firmware/code/tools/watch_pnr.ps1`：
- **PDS 只用 1.2~1.5 个核**（18 逻辑核），整机 20~30%；
- GPU（Intel Arc 集显）10~75% 的波动来自桌面合成，与 PDS 无关；
- NPU（Intel AI Boost）**没有性能计数器**，且 PDS 不使用它；
- ⇒ **"布线不行"与算力无关**，只与网表拓扑 + 约束 + seed 有关。
