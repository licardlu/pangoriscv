# E2 测量记录 —— 分数不变、面积 −10.9%、时序余量 +3.3 ns

日期：2026-10-21　位流：`bitstream/pangoriscv_i1152_e2.sbit`（SHA256 `D7BF5E41…5D3137`）
镜像：`score1152`（与 P37 交付同一份，SHA 未变）　构建：`build/e2d_deliver`（交付 profile）

## 1. 板上实测（与交付版逐位相同）

```
Total ticks      : 298,780,717      <-- 与 P37 交付完全一致
Total time (secs): 11
Iterations       : 1152
seedcrc 0xe9f5  crclist 0xe714  crcmatrix 0x1fd7  crcstate 0x8e3a  crcfinal 0x4cb6
Correct operation validated.
```

**分数 3.8557 不变**（同一份位流三项指标：① 3.8557 ② 27 MHz 全过 ③ 0.2199 kLUT）。

## 2. 时序（27 MHz）

```
single,OK,OK,7.816,17.720,0.025,0.014,...,0.000,0,0.000,0
Setup(Slow) +7.816 (P37: +4.484)   Hold(Slow) +0.025 (P37: +0.032)
失败端点 0，Convergence 100%
```

## 3. 资源

```
Used,17534,7153,4,6,3684   (LUT, FF, DRM, APM, LUTRAM)
```

| 项 | P37 交付 | **E2** | Δ |
|---|---:|---:|---:|
| LUT | 18,333 | **17,534** | −799（−4.4%） |
| FF | 9,836 | **7,153** | **−2,683（−27.3%）** |
| LUTRAM | 3,664 | 3,684 | +20 |
| 站点合计 | 31,833 | **28,371** | **−10.9%** |
| CoreMark/kLUT | 0.2103 | **0.2199** | **+4.6%** |
| setup / hold | +4.484 / +0.032 | **+7.816 / +0.025** | 余量 +3.3 ns |

## 4. 三处改动（全部行为等价）

1. **`icache_axi`**：复位段不再逐项清零 `tag_mem`（128×21）。分布式 RAM 不能按项复位，
   原来那行把整块 tag 逼成 2,688 个触发器，连带 128:1 读 mux 变 LUT。
   安全性：命中要求 `valid_mem` 置位，valid 只在写 tag 的**同一拍**置位。
2. **`dcache_axi`**：tag 数组按路拆成 `tag_mem`/`tag_mem_1`（每个数组 1 读口 1 写口），
   一次填充只驱动 21 个 RAM 数据脚（原来一份数据要写两个副本 = 42 脚）；
   并新增 `set_di_q`（写地址的延后一拍副本，只喂 RAM）。这两条直接消掉了
   `tag_di_q→tag_mem/DI` 与 `set_q→WADDR` 这对连续多版的老 hold 紧点。
3. **`pangoriscv_top`**：`led[i]` 去掉冗余的 `soc_rst_n` 项（GPIO 寄存器复位即 0，
   该门只把复位同步器拉进 IO 路径）。

## 5. 等价性证据（四重）

- A/B 20 迭代**逐位相同**：窗口 5,212,477 / retires 5,782,437 / 全部探针计数 / `crcfinal 0x4983`；
- 板上 ticks **298,780,717**，与交付版一字节不差；五项 CRC 全对；
- ISA 17/17、icache 单测、dcache 单测、engine 64/64；
- 27 MHz `single,OK,OK`，失败端点 0。

## 6. 复核命令

```bash
python sim/run_icache_tests.py --modelsim <vsim>
python sim/run_dcache_tests.py --modelsim <vsim>
python tools/run_coremark_ab.py --switch CACHE --sides on \
    --image-dir build/native_software/coremark/performance/area20 \
    --out build/ab_e2d --modelsim <vsim>
```
