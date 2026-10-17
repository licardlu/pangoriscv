# T4 前端优化实测结果（I-Cache 连续命中吞吐 + IFU 同拍收旧发新）

> 对象：`frontend_opt/src/`（独立副本，**交付树 `firmware/code` 未改动**）。
> 对照：`baseline_build/src/`（= 交付版 RTL，commit `80e39ce` 展开）。
> 全部数字来自本轮同口径、同镜像、同 TB 的实测日志（`frontend_opt/ab/`）。

## 1. 范围与不变量

- 只改两个文件、三处逻辑：`rtl/core/icache_axi.v`（同拍「收旧发新」接受入口）、
  `rtl/core/ifu_axi.v`（同拍「收旧发新」发射 + 队列槽位预留）。
- 外部接口信号**一个都没加、没删、没改**；`icache_axi` / `ifu_axi` 模块端口与交付版逐字节相同。
- **不做**多笔在途：IFU 仍只保留一笔未完成请求（旧响应未返回前不再发第二条），
  I-Cache 仍一次只挂一笔响应。本轮不触碰 miss 的串行补行路径。
- 新增文件只有两个契约级 TB：`tb/unit/tb_icache_contract.sv`、`tb/unit/tb_ifu_contract.sv`；
  旧 TB `tb_ifu_axi.sv` 仅按契约更新引擎模型（见 §3 脚注），未删任何检查项。

## 2. RTL 改动（相对基线，逐段）

### 2.1 `rtl/core/icache_axi.v`

```diff
-    assign req_ready = rst_n && state==IC_IDLE;
+    wire rsp_consume = (state==IC_RESP) && rsp_valid && rsp_ready;
+    assign req_ready = rst_n && (state==IC_IDLE || rsp_consume);
+    wire accept = req_valid && req_ready;
```

- 接受逻辑（命中当拍应答 / miss 起补行）从 `case(state) IC_IDLE:` 分支内提出为公共块，
  `IC_IDLE` 与 `IC_RESP` 同拍替换共用；`case` 里 `IC_IDLE, IC_RESP: ;` 只留转移。
- 关键不变量：`rsp_ready` 低（响应被背压）时 `rsp_consume=0` ⇒ `req_ready=0`，**不存在覆盖未消费响应**；
  `req_ready` 依赖 `rsp_ready`（IFU 状态寄存器输出），不回环到 `req_valid`。

### 2.2 `rtl/core/ifu_axi.v`

```diff
-    assign eng_req_valid=rst_n&&enable&&!redirect_valid&&!stop_q&&!full&&
-                         (state==S_IDLE)&&!local_fault;
+    wire rsp_consume   = (state==S_WAIT) && eng_rsp_valid && eng_rsp_ready;
+    wire rsp_issue_ok  = rsp_consume && !stale_q && (eng_rsp_resp==2'b00);
+    wire rsp_push_now  = rsp_consume && !stale_q;
+    wire [AW:0] occupy = count_q + (rsp_push_now?1'b1:1'b0);
+    wire slot_ok       = (occupy<DEPTH);
+    wire slot_free     = (state==S_IDLE) || rsp_issue_ok;
+    assign eng_req_valid=rst_n&&enable&&!redirect_valid&&!stop_q&&slot_ok&&
+                         slot_free&&!local_fault;
```

- 同拍允许条件 `rsp_issue_ok` 显式排除两类响应：**fault**（`eng_rsp_resp!=2'b00`）与
  **redirect 后的 stale 响应**（`stale_q`）——这正是契约第 7 条「旧响应报错不得无控制推进年轻请求」。
- 队列槽位：同一拍「旧响应入队 + 新请求在途」必须按 `count + 本次 push` 判 `slot_ok`
  （原 `!full` 会把队列多塞一格：tail 回卷、`head_pc` 失配、`head_lost` 丢流）。
- `if(state!=S_WAIT) state<=S_WAIT;`：在 `S_WAIT` 中发射新请求时不改变状态，旧响应用**旧**
  `req_pc_q/req_pred_q` 入队（同一条 `always @(posedge)` 内先读后写，天然不串配）。

## 3. 契约条款 → 测点对应

| 条款 | 检查点 | 测试 |
|---|---|---|
| C1 I-Cache 收旧响应同拍可收新请求 | 预热后连续命中，20 拍内 20 次 `req_valid&&req_ready` | `tb_icache_contract` C1 |
| C2 IFU 收旧响应同拍可发新请求 | `same_cycle` 计数 ≥ 100，且 `delivered==reqs` | `tb_ifu_contract` C2 + `INFO A` |
| C3 旧响应用旧 PC/预测，不串配 | 引擎按地址回显 `encode(addr)={16'h0,a[15:2],2'b00}`，逐条比对 `result_inst===encode(result_pc)` 且 PC 按序递增 | 两个契约 TB 的配对检查 |
| C4 miss 走原阻塞补行；hit→miss→hit 正确 | 预热命中→miss→回行→再命中，数据全对 | `tb_icache_contract` C4 |
| C5 背压时 valid/data 稳定 | `fetch_ready=0` 保持 6 拍，`head/head_inst` 不变；I-Cache 侧 `rsp_ready` 拉低时 `rsp_valid/rsp_data` 不变 | 两 TB 的 C5 |
| C6 新请求预留槽位 | 填满到 `DEPTH=8` 不溢出（常开 `count_q>8` 即 fatal），同拍 push+issue 不越界 | `tb_ifu_contract` C6 |
| C7 redirect/错误/halt 优先级 | redirect 后 `count_q` 必须清零、从 `0x100` 恢复；fault 响应投递后 20 拍内不再发射；`flush_lost==0` | `tb_ifu_contract` C7 |

脚注：`tb_ifu_axi.sv` 的旧引擎模型原先要求「应答后隔拍才能再收请求」，与新契约相悖；
本轮改成 `assign eng_req_ready = !pv || eng_rsp_ready;`（同拍收旧发新），
其**顺序/无重复/无丢失/背压/错误/redirect/队列边界**断言一条未删。

## 4. 契约 TB 结果

```
TEST_PASS ICACHE_CONTRACT accepts=20 rsp=27 bursts=5     # C1 20/20 拍接受, C3 配对全对
TEST_PASS IFU_CONTRACT    delivered=187 same_cycle=192 max_count=8
INFO A delivered=120 same_cycle=125 reqs=127 max_count=8  # 连续命中流, 同拍率 125/127
INFO C resumed exp_pc=000001ec                            # redirect 后从新 PC 恢复
```

## 5. 整机回归（两轮独立干净 work 库，改动后 RTL）

| 套件 | 第 1 轮 | 第 2 轮 |
|---|---|---|
| `run_unit_tests.py` | 5 / 5 PASS | 5 / 5 PASS |
| `run_engine_tests.py` | 64 / 64 PASS | 64 / 64 PASS |
| `run_interconnect_tests.py` | 20 / 20 PASS | 20 / 20 PASS |
| `run_ram_tests.py` | 40 / 40 PASS | 40 / 40 PASS |
| `run_ifu_engine_tests.py` | 20 / 20 PASS | 20 / 20 PASS |
| `run_pipeline_tests.py` | PASS `N03_PIPELINE` | PASS `N03_PIPELINE` |
| icache / dcache / predictor / perf / gpio-trace | 各 1 / 1 | 各 1 / 1 |
| `tools/run_isa_e2e.py` | SUMMARY 15 / 15 PASS | — |
| `tools/run_halt_reset_tests.py` | SUMMARY 5 / 5 PASS | — |

合计：两轮各 **11 套件 0 fail**，RTL 编译 0 error / 0 warning。

## 6. CoreMark 同镜像 A/B（1 次迭代镜像，两棵树逐字节相同的 `program.hex`/`data.hex`）

审计 TB `scripts/tb_coremark_audit_v2.sv`（长窗口用 `tb_coremark_audit_v3.sv`），
`AUDIT_INT` 区间以 `Total ticks` 打印为界，两侧同一镜像、同一仿真参数。

| 镜像 | 基线拍数 | 候选拍数 | 变化 | retires 基线/候选 | IPC 基线 → 候选 |
|---|---|---|---|---|---|
| performance（1 iter） | 803,230 | 701,500 | **−12.66 %** | 305,069 / 305,069 | 0.3798 → 0.4349 |
| validation（1 iter）  | 804,633 | 702,231 | **−12.73 %** | 305,505 / 305,505 | 0.3797 → 0.4350 |

- **retires 完全相同** ⇒ 减少的是纯停顿周期，不是少算了工作。
- 分类分解（validation）：`frontend_idle` **152,997 → 51,340**（−66 %），
  `ifwait` **153,442 → 30,001**，而 `lsu_load/lsu_store/lsuwait`（171,489/173,398/71,510）
  两侧基本不变 ⇒ 收益来源就是「取指侧不再每 2 拍才发一条」。
- 五 CRC 两侧逐项一致：`seedcrc 0x18f2`、`crclist 0xe3c1`、`crcmatrix 0x0747`、
  `crcstate 0x8d84`、`crcfinal 0xe3c1`；两侧均打印 `Correct operation validated`。

## 7. ALU 微程序（同镜像，只探 `clk/rst_n/uart_tx` 的端口级 TB）

`cyc_per_insn_x100` 为单位 ×100（202 = 2.02 拍/条）：

| 阶段 | 基线 | 候选 | 说明 |
|---|---|---|---|
| `alu_independent` | 202 | **101** | 取指受限 → 达到 ≈1.0 拍/条（目标） |
| `alu_dependent`   | 201 | 102 | 同上 |
| `branch_taken`    | 205 | 104 | 同上 |
| `branch_alternating` | 243 | 173 | 仍受重定向影响 |
| `mul_dependent`   | 201 | 102 | 乘后依赖不增拍 |
| `load_independent` | 320 | 318 | LSU 受限，几乎不变 |
| `load_dependent`  | 379 | 379 | 不变 |
| `store`           | 901 | 901 | 不变（写穿路径未动） |
| `div_dependent`   | 2438 | 2438 | 不变（除法器未动） |

## 8. 后端：PDS 综合/布局布线（两棵树同一流程、同一 400 次迭代镜像）

流程与基线完全一致（`platform/pango_native/build.tcl`：`synthesize -ads` → `dev_map` →
`add_constraint pcf` → `pnr` → `report_timing` → `gen_bit_stream`），镜像用**基线树的
400 次迭代 performance 镜像**（`program.hex` sha256 `4AD7DE6B…`），因此两版位流跑的是
同一份 CoreMark 程序。

| 指标 | 基线 | 候选（T4） | 变化 |
|---|---|---|---|
| LUT | 12,441 | **12,406** | −35（−0.3 %） |
| FF | 7,268 | 7,268 | 0 |
| DRM | 4.5 | 4.5 | 0 |
| APM | 6 | 6 | 0 |
| Distributed RAM | 2,685 | 2,685 | 0 |
| IO | 13 | 13 | 0 |
| Setup WNS（slow） | 16.262 ns | **17.131 ns** | +0.87 ns |
| Hold WHS（slow） | 0.024 ns | **0.103 ns** | +0.079 ns |
| Setup WNS（fast） | 24.216 ns | 23.799 ns | −0.42 ns |
| Hold WHS（fast） | 0.014 ns | **0.069 ns** | +0.055 ns |
| 估计最高频率 | 48.15 MHz | **50.24 MHz** | — |
| 端点总数 | 48,478 | 48,478 | 0 |
| 约束结论 | All Constraints Met | **All Constraints Met** | — |

- 位流：基线 `747C18CA32DEFD118E2237863FD7BDAC9C6DB1E110EE734F6CC485FAF68E6D77`
  （`baseline_build/src/build/pango_native/generate_bitstream/pangoriscv_top.sbit`）；
  候选 `DE0F907466874E7113F4E7FC535FF101B416CB185E2686CC5F508FA0AA47B4F8`
  （`frontend_opt/pds/run2_hold100/pangoriscv_top.sbit`），两者均 3,791,112 B。
- 第一次候选布线（hold 修复阈值沿用基线的 0 ps）出现 **Hold slow −0.036 ns / Hold fast −0.020 ns**
  （3 个端点，`ifu/tail_q` → `if_id` 的 min 路径）。把**候选流程**的 pnr hold 修复阈值
  0 → 100 ps、迭代 50 → 100（只是要求修得更多，没有放松任何约束）后重跑，
  得到上表 `All Constraints Met`。证据：`frontend_opt/pds/run1_hold36ps/`、`run2_hold100/`。
- 资源与时序都满足 27 MHz（周期 37.037 ns，最差 setup 只用 19.906 ns），
  且逻辑改动未引入跨 Cache→CPU 的长组合路径：WNS 反而比基线宽松 0.87 ns。

### 8.1 上板实测（400 次迭代正式 CoreMark，27 MHz）

位流里烧的是 400 次迭代 performance 镜像（两版位流同镜像），板级流程与基线复采完全一样：
先开串口（COM13, 115200 8N1）再 `cfg_program` 下载，抓 `CPM_TICKS` 与完整 CoreMark 报告。

| 项 | 基线位流 | T4 候选位流 | 变化 |
|---|---|---|---|
| `CPM_TICKS` | hi=0 lo=320,599,074 | hi=0 lo=280,012,186 | — |
| `Total ticks`（400 iter） | 320,725,708 | **279,957,350** | **−12.71 %** |
| `Total time (secs)` | 11 | 10（精确 10.3688 s） | — |
| Iterations/Sec | 36（精确 33.6736） | 38（精确 38.5773） | — |
| **CoreMark/MHz** | **1.2472** | **1.4288** | **+14.56 %** |
| `seedcrc` / `crclist` / `crcmatrix` / `crcstate` / `crcfinal` | e9f5 / e714 / 1fd7 / 8e3a / 25b5 | e9f5 / e714 / 1fd7 / 8e3a / 25b5 | **逐项相同** |
| `Correct operation validated` | 有 | 有 | — |

- 板上周期降幅（−12.71 %）与仿真 1 迭代 A/B（−12.66 %/−12.73 %）一致，
  说明收益不是小镜像或 TB 假象。
- 板测捕获：`results/board_uart_baseline.txt` / `board_uart_baseline_run2.txt`（sha256 `78B7D08D…`，
  两次逐字节相同）、`results/board_uart_candidate.txt` / `board_uart_candidate_run2.txt`
  （sha256 `D4DC2B50…`，两次逐字节相同 ⇒ 板级结果可复现）；下载日志 `board/01b_program_only.tcl.out.txt`。
- 板级坑：串口必须先打开再下载（镜像只打印一次）；`cdt_cfg.exe` 跑完 file-only Tcl 不退出，
  `run_flash.ps1` 会按超时杀进程、以 `configuration_tcl.log` 判成功；本机启动 `cdt_js.exe`
  有 ftdibus.sys 内核 bugcheck 前科，本轮未复现。

## 9. 结果边界（不做过度承诺）

1. 上面的官方口径只有 §8.1：**400 次迭代、27 MHz、`Total ticks` 计分**，基线 1.2472 → 候选 1.4288
   CoreMark/MHz（+14.56 %）。§6 的 1 迭代 A/B 只用于定位机制，不与官方成绩混用。
2. 收益只来自取指侧：依赖 LSU、除法、写穿的阶段一律不变（§7 后三行），
   说明未意外改变流水语义；五 CRC 在仿真与板上都逐项相同。
3. 交付树 `firmware/code` 仍是原 RTL；板测已通过，是否合并、以什么版本合并仍待定（见 §11）。

## 10. 复现命令

见 `commands.md` §3.7（仿真/契约 TB/A-B/微程序）与 §3.8（PDS 构建、上板下载）；要点：

```powershell
$env:PATH='E:\donwload\win64;'+$env:PATH          # questasim 二进制
cd E:\file\pango\project\evidence\records\bottleneck_audit\frontend_opt\src   # 树根
vlib ab2_cand
vlog -sv -work ab2_cand +define+CACHE_ENABLE +define+PREDICT_ENABLE `
     +incdir+rtl/core +incdir+rtl/perips -f sim/native_axi_sources.f `
     tb/unit/tb_icache_contract.sv tb/unit/tb_ifu_contract.sv
vsim -c -work ab2_cand tb_icache_contract -do "run -all; quit -f"
vsim -c -work ab2_cand tb_ifu_contract    -do "run -all; quit -f"
```

## 11. 未做 / 下一步

- [x] 契约级 TB、旧 TB 适配、两轮完整回归、ISA E2E、halt/reset
- [x] CoreMark 同镜像 A/B（perf + validation）与微程序表
- [ ] 合并进交付树（待定）
- [x] PDS 综合/布局布线：时序与资源对比基线（见 §8；两版均 All Constraints Met）
- [x] 优化版位流上板：400 次迭代 CoreMark 正式成绩（1.4288 vs 基线 1.2472 CoreMark/MHz，见 §8.1）
