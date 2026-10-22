# P19/P20 —— 面积优化打通布线：5.2941 @ 39 MHz（**上板实测**）

日期：2026-10-23
位流：`bitstream/pangoriscv_board39_i2300_5p294.sbit`
SHA256：`771477ce099cb9afae0c99eadf905d87dd7c41e3e25fd06b046cd73567932612`
构建：`build/P20b`（39 MHz 约束，seed 7，`-plc_decongestion 2 -dispose_dram_prior TRUE
-share_router_control_signal TRUE`）
镜像：`hw_i2300_39`（2300 迭代，`CPU_FREQ_MHZ=39`）

---

## 1. 上板实测（原始串口输出）

```
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 434442833
Total time (secs): 11
Iterations/Sec   : 209
Iterations       : 2300
Memory location  : STATIC
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x988c
Correct operation validated. See readme.txt for run and reporting rules.
```

**CoreMark/MHz = 2300 × 1e6 / 434,442,833 = 5.2941**

### 1.1 `crcfinal = 0x988c` 不是错，是迭代数决定的

`tests/example/coremark/core_main.c` 的 `iterate()`：

```c
res->crc=0;
for (i=0; i<iterations; i++) {
    crc=core_bench_list(res,1);
    res->crc=crcu16(crc,res->crc);      // 跨迭代累积
    crc=core_bench_list(res,-1);
    res->crc=crcu16(crc,res->crc);
    if (i==0) res->crclist=res->crc;
}
```

`crcfinal` 是 `res->crc`，**随 `iterations` 变化**：

| 迭代数 | crcfinal |
|---|---|
| 20（仿真 `sim20_O2`） | 0x4983 |
| 2300（上板 `hw_i2300_39`） | **0x988c** |

`seedcrc 0xe9f5` 是 CoreMark performance run 的官方标准值，`crclist/crcmatrix/crcstate`
三项与 `list_known_crc[3]/matrix_known_crc[3]/state_known_crc[3]` 逐位相同，
`total_errors==0` 由 CoreMark 自己判定并打印 `Correct operation validated`。

> **旧口径的错误**：P17 及以前的交接文档把"五项 CRC = 0x4983 / 0xe714 / 0x1fd7 /
> 0x8e3a / 0x54414c55"当作**上板**判据。0x4983 是 20 迭代仿真的值，上板用 2000~2700
> 迭代永远不可能是它。这条判据此前从未真正用于上板核对。

---

## 2. 时序（布线后 `.rtr`，同一份实现）

```
core_clk   Requested 39.0000 MHz  Estimated 39.3252 MHz
           Requested 25.6410 ns   Estimated 25.4290 ns   Slack +0.212
Setup(Slow) WNS +0.212 ns  TNS 0.000   Failing endpoints 0 / 52540
Hold (Slow) WHS -0.007 ns  THS -0.014  Failing endpoints 2 / 52540
Hold (Fast) WHS -0.013 ns
Minimum pulse width 11.860 ns, 0 failing
```

**Setup 全过（0 失败端点），39 MHz 达标。** 剩 2 个端点的 hold 差 7~13 ps——
这是交付前必须修掉的，正在用 `-fix_hold_violation_threshold 50` 重跑（见 §6）。

---

## 3. 面积（`device_map` `Used` 行，同一位流）

| 项 | P17 交付基线 | **P20b** | 变化 |
|---|---|---|---|
| LUT | 18,181 | **15,992** | **−2,189（−12.0%）** |
| LUTRAM | 3,790 | **1,742** | **−2,048（−54%）** |
| DRM（块 RAM） | 8 | 12 | +4 |
| LUT 利用率 | 27.30% | **24.01%** | |
| LUTRAM 利用率 | 19.05% | **8.75%** | |

---

## 4. 三项改动（每项都有独立实测）

### 4.1 `data_ram` 进块 RAM —— 本轮最关键的一项

**现象**：`soc/data_ram/mem` 被拆成 4 × (4096×8)，每片映射成 512 个
`GTP_RAM64X1DP`（分布式 RAM），合计 **2,048 个 LUTRAM**，占全设计的 **54%**。
而同模块的 `program_ram` 是 `GTP_DRM36K_E1`（块 RAM）。

**根因**：两个实例唯一的差别是 `WRITE_ENABLE`。`program_ram` 传 `WRITE_ENABLE(0)`，
写路径被综合整个删掉，剩下纯 ROM，映射器认；`data_ram` 的写路径留在**响应状态机的
`case` 分支里**，读又是 `read_data<=mem[read_index]` 在另一个 always 块里，
映射器认不出简单双口结构，退回分布式 RAM。

**改法**（`rtl/perips/axi_ram.v`）：
1. 把读、写放进**同一个** always 块，两个地址都来自寄存器：
   ```verilog
   always @(posedge clk) begin
       if(write_event) begin
           if(w_strb[0]) mem[write_index][7:0]  <=w_data[7:0];
           ... 4 个字节使能，展开写（不用 for 循环）
       end
       mem_rdata<=mem[read_index];      // 无条件、每拍读
   end
   ```
2. 数组声明加 `/* synthesis syn_ramstyle = "block_ram" */`。
3. `s_rdata` 直接取 `read_good?mem_rdata:0`，`READ_MEM` 状态不再采样阵列。
   `read_index` 是在 IDLE→READ_MEM 边沿锁存的，所以 `mem_rdata` 在 READ_RESP 拍
   正好持有该字——**与原 `read_data` 寄存器同一拍，零额外延迟、少一个寄存器**。

**结果**：`data_ram` → `GTP_DRM36K_E1` × 4（`SIMPLE_DUAL_PORT`），
LUTRAM −2,048、LUT −2,797（首次综合）。
**`Total ticks` 3,833,976 逐位不变，五项 CRC 全对，ISA 20/21。**

### 4.2 BTB 32 → 64 —— 用腾出来的面积换分数

面积腾出后 BTB 翻倍不再是禁区：LUT 15,992（含 BTB64），仍远低于
18,000 的可布线性拐点。

| 配置 | Total ticks (20 it) | 分数 | mispred (20 it) |
|---|---|---|---|
| BTB 32 | 3,833,976 | 5.2165 | 68,827 |
| **BTB 64** | **3,776,288** | **5.2963** | **47,109（−31.6%）** |

### 4.3 `local_push` 寄存化（零代价重定时）

切断 `redirect_pc → local_fault → 指令队列写使能` 的 2.9 ns 尾巴。
`Total ticks` 不变、CRC 全对。补丁 `docs/patches/local-push-retime.patch`。
**注意**：它没有缩短布线后关键路径（摆放估计 20.76 → 20.90 ns），因为路径是张网，
切掉一条分支会露出另一条同等长度的分支。保留它是因为零代价，但**不要把它当成提升
频率的手段**。

---

## 5. 布线：面积是唯一真正的杠杆

| 构建 | LUT | 约束 | 详细布线 |
|---|---|---|---|
| p18r39 | 18,181 | 39 MHz | 停 3,618@119，斜率归零 |
| P19c | 15,971 | 45 MHz | 853@190 → 405@538 → 340~385 震荡（400 轮无突破）|
| **P20b** | **15,992** | **39 MHz** | **9,214@16 → 853@190 → 0@212，收敛** |

同面积下 39 MHz 收敛、45 MHz 卡在 340 条，说明：
1. **LUT 从 18.2k 降到 16.0k 是决定性的**（越过拐点）；
2. 约束越紧，时序驱动摆放越激进，局部拥塞越容易卡死；
3. `-dispose_dram_prior TRUE` 有用（优先摆放剩下的 1,742 个分布式 RAM，
   避开 LUTRAM 走廊），`-plc_decongestion 2` 在 39 MHz 下起点更好。

---

## 6. 待办（按优先级）

1. **修掉 2 个 hold 端点**：`-fix_hold_violation_threshold 50`（构建 P21a 在跑）。
   合规要求是 setup/hold 都无失败端点。
2. **提高频率**：布线后路径 25.43 ns，39 MHz 只剩 0.21 ns 余量。要往上走必须
   **用寄存器把重定向环路切断**（+1 拍/误预测）。预算：
   BTB64 下误预测 2,355/迭代，`188,888 + 2,355 = 191,243 → 5.228`，
   仍在 5.2 以上，而路径可望降到 ~14 ns（约 70 MHz）。
3. 之后再谈 120 MHz：需要双端口 D$（−12,256 拍）+ 2~3 刀。

## 7. 仿真原始数据（.sim_runs 已删前抄录）

```
--- p19bram
# Total ticks      : 3833976
# Iterations       : 20
# seedcrc          : 0x54414c55
# [0]crclist       : 0xe714
# [0]crcmatrix     : 0x1fd7
# [0]crcstate      : 0x8e3a
# [0]crcfinal      : 0x4983

--- p19btb64
# Total ticks      : 3776288
# Iterations       : 20
# seedcrc          : 0x54414c55
# [0]crclist       : 0xe714
# [0]crcmatrix     : 0x1fd7
# [0]crcstate      : 0x8e3a
# [0]crcfinal      : 0x4983

--- p20cut
# Total ticks      : 3872252
# Iterations       : 20
# seedcrc          : 0x54414c55
# [0]crclist       : 0xe714
# [0]crcmatrix     : 0x1fd7
# [0]crcstate      : 0x8e3a
# [0]crcfinal      : 0x4983

```

| 配置 | Total ticks (20 it) | 分数 | 备注 |
|---|---|---|---|
| BRAM + BTB32 | 3,833,976 | 5.2165 | 基线 |
| BRAM + BTB64（交付） | 3,776,288 | **5.2963** | |
| BRAM + BTB64 + 重定向切断 | 3,872,252 | 5.1650 | **不达标，未交付** |

### 7.1 关于仿真 transcript 里的 `seedcrc 0x54414c55`

仿真 transcript 打印 `# seedcrc : 0x54414c55`，而固件里 `seedcrc` 是 `ee_u16`、
按 `%04x` 打印——**u16 不可能输出 8 位十六进制**，所以这一行在仿真通道里不可信
（UART/xprintf 的变参宽度问题）。上板的 `seedcrc 0xe9f5` 才是 CoreMark
performance run 的标准值，且上板三项子 CRC 与 `*_known_crc[3]` 逐位相同、
`Correct operation validated` 由 CoreMark 自己判定。

**结论：上板数据的判据只用上板输出自身**（seedcrc + 三个子 CRC + validated），
不与仿真 transcript 的 `seedcrc` / `crcfinal` 交叉比对（两者的 `crcfinal` 本来就
因迭代数不同而不同，见 §1.1）。
