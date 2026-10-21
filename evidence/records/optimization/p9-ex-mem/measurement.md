# P9 / R5 —— 访存请求从 M1 挪到 EX

日期：2026-10-22
计划：`docs/plan-score-5.2-120mhz-v5.md` §3 的 R5
RTL 改动：只动 `rtl/core/rv32/rv32_top.v` 一个模块（模块化布线纪律）

## 1. 结论先说

| | 基线 `p8base` | P9 `p9i` | Δ |
|---|---|---|---|
| `Total ticks`（20 迭代） | 5,073,264 | **4,518,354** | **−554,910（−10.9%）** |
| CoreMark/MHz（仿真，`20/ticks×1e6`） | 3.942 | **4.427** | **+0.485（+12.3%）** |
| `cycles`（整程序） | 6,960,617 | 6,403,281 | −557,336 |
| `retires`（整程序） | 6,897,460 | 7,027,447 | +129,987（都在计时窗之外） |
| IPC | 0.9909 | 1.0975 | +10.8% |
| `crclist` | 0xe714 | 0xe714 | ✔ |
| `crcmatrix` | 0x1fd7 | 0x1fd7 | ✔ |
| `crcstate` | 0x8e3a | 0x8e3a | ✔ |
| `crcfinal` | 0x4983 | **0x4983** | ✔ |
| `load_use` 停拍 | 1,714,576 | **0** | −1,714,576 |
| `mem_wait` 停拍 | 233,091 | 1,268,139 | +1,035,048 |
| LSU 非空闲 | 1,025,847 | 1,273,392 | +247,545 |
| 计时窗内不退休周期 | 1,468,641 | 871,904 | −596,737 |

`load_use` 归零是 R5 的结构目标，**达成了**（§33 判据：不是换了个名字，
而是同一笔时间真的变成了 LSU 忙时间：净收益 −557 k 周期）。

ISA 全量：**20 / 21 PASS**（唯一红的 case 21 是"预测目标配对"探针口径问题，
`E2E_TARGET_PAIR target=0 wrong=0`，R5 之前就是同一个结果，与本次改动无关）。

## 2. 改了什么（一句话版）

请求在 EX 拍就用 `rr_*` 发起，响应在 EX/M1 边沿落进 `ex_value`，
于是 load 对旁路网络来说和 ALU 结果完全一样，`load_use` 互锁整块删除。

顺带删掉 `ex_addr / ex_sdata / ex_load / ex_store / ex_uns / ex_size` 及其 lane1 孪生
（面积负数），并把 `issue_mem` 的老指令守卫从只看 WB 扩到 M1+M2。

### 面积（`build/p9synth126`，`--freq 126 --mode synth`）

| | P8 | P9 | Δ |
|---|---:|---:|---:|
| LUT | 17,323 | 17,369 | +46 |
| FF | 7,680 | 7,576 | **−104** |
| Distributed RAM | 3,684 | 3,684 | 0 |
| 合计 | 28,687 | 28,629 | **−58** ✔ 门禁（≤0）通过 |

+46 LUT 全部来自 `ctrl_miss_now`（一个 32 位比较 + 一个与门），
−104 FF 来自六个寄存器的删除（其中四个 32 位）。
DRM 8 / APM 6 不变。

**时序没有测到**：PDS 2022.2-SP6.1 的 `report_timing` 只接受 PnR 后的数据库
（`Flow-0044: Place & Route hasn't been run`），`--mode synth` 因此返回 exit 1。
本记录不声称任何 WNS，也不声称 120 MHz 收敛。

## 3. 两个必须记住的正确性坑（详见 `docs/lessons/mistakes-log.md` §38/§39）

1. **§38**：发射点前移一拍 ⇒ `br_miss` 与 `issue_mem` 同拍 ⇒ 边沿上的
   `ex_v1 <= … && !br_miss` 拦不住已经进 LSU 的错路 store。
   实测 10 条 `LSU_FAULT … pc=00002b10 addr=00000031`。
   修法：`ex_is_mem_h && !ctrl_miss_now`，让错路访存根本不进 `mem_wait`。
   **只在 `issue_mem` 上加守卫会死锁**（`br_miss` 带 `!hold_ex`，而 `hold_ex` 来自 `mem_wait`）。
2. **§39**：`else if (!hold_ex)` 这种"跳过整块"的冻结写法会吞掉 `kill_all` 的清零，
   ISA case 19 红。修法：进入块的条件 `|| kill_all`，块内 valid 赋值各自 `&& !hold_ex`。

## 4. 剩下的时间花在哪（下一次优化的靶子）

`mem_wait = 1,268,139` 的分解（`MEMWAITDBG` + `LSU_PATH` + `LSU_REQ_SPLIT`）：

| 项 | 周期 | 每次访存 | 含义 |
|---|---|---|---|
| `rdwait` | 584,037 | 4.60 | 自己那次 refill 在等 AXI（126,908 次 refill） |
| `request_load` | 499,707 | 3.94 | load miss 被"cache 不空闲"挡在门外 |
| `request_store` | 185,526 | — | store 被挡在门外（`ST_REFUSE` 94,652，几乎全是队列满） |
| `wrwait` | 4,122 | — | store 等 B |

挡住 load miss 的那 500 k 几乎全来自 **写通 + posted store queue 的排序约束**：
`dcache_axi` 的读写共用同一个 `state_q`，处在 `ST_WR_DRAIN`（全程序 2,079,603 拍，
占 32%）时读 miss 一律不收。而每次 store 都要走一次 AXI 写（`axi_d_aw=410,588`），
单 outstanding 的写引擎约 5 拍一个，于是 drain 一直挂在那里。

**下一刀（R6）**：把"读状态机"和"写 drain"解耦（B 响应与队列释放移到与状态无关的尾部），
读 miss 在 drain 期间只要有**行地址不冲突**就放行。预估 −500 k ≈ +0.4 分（→ 4.8）。
再往后的 5.2 需要真正的非阻塞 D$（MSHR），本轮预算不够，不硬冲。

## 5. 复现命令

```bash
python tools/run_coremark_sim.py --image build/native_software/coremark/performance/sim20_o2 \
       --tag p9i --define RV32_DEBUG
python tools/run_isa_e2e.py \
       --toolchain-bin D:/FPGA_Project/zi_guang_tong_chuang/toolchains/xpack-riscv-none-elf-gcc-15.2.0-1/bin \
       --prefix riscv-none-elf- "--extra-flag=-march=rv32im_zicsr" \
       --modelsim D:/FPGA_Project/Modelism/win64
```

产物：`firmware/code/.sim_runs/coremark_sim/p9i/{transcript.txt,retire_trace.txt}`
