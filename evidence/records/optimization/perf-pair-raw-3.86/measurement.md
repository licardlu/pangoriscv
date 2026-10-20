# P37a/P37b 测量记录 —— 3.8557 CoreMark/MHz（板上实测）

日期：2026-10-21　位流：`bitstream/pangoriscv_i1152_p37.sbit`（SHA256 `81C1D049…3B62`）
镜像：`build/native_software/coremark/performance/score1152`（ITERATIONS=1152，其余 flag 与 score1024 逐项相同）
构建：`build/perf_p37b`，交付 profile（PERF_ENABLE=off），工具 PDS 2022.2-SP6.1

## 1. 板上实测（COM34，115200）

```
Total ticks      : 298,780,717
Total time (secs): 11
Iterations/Sec   : 104
Iterations       : 1152
seedcrc 0xe9f5  crclist 0xe714  crcmatrix 0x1fd7  crcstate 0x8e3a  crcfinal 0x4cb6
Correct operation validated. See readme.txt for run and reporting rules.
```

| 项 | 值 |
|---|---:|
| ticks | **298,780,717** |
| ticks/iter | 259,358 |
| 运行时间 | **11.066 s ≥ 10 s**（CoreMark 有效性要求） |
| **CoreMark/MHz** | **3.8557**（3.6345 → +6.09%） |
| 五项 CRC | 全对，`Correct operation validated` |
| CoreMark/kLUT | **0.2103**（原 0.2008，+4.7%） |

> 用 1024 迭代镜像实测得 265,479,824 ticks / **9.83 s**，分数更高但**运行不足 10 s**，
> CoreMark 判为 `ERROR! Must execute for at least 10 secs` —— 因此交付镜像改为 **1152 迭代**。
> 这条不是可选项：迭代数不足即无效成绩。

## 2. 时序（同一份实现，27 MHz）

```
single,OK,OK,4.484,15.797,0.032,0.019,...
Pass Rate/Convergence Rate,100.00%,100.00%
Setup(Slow) +4.484 ns / Setup(Fast) +15.797 ns
Hold(Slow)  +0.032 ns / Hold(Fast)  +0.019 ns
Setup 失败端点 0 / Hold 失败端点 0
```

setup 由 +10.041 降到 +4.484（P37a 的 EX→EX 前递 mux 落在同一条 lane1 操作数路径上），
27 MHz 周期 37.04 ns，余量仍 >12%。若后续要提高 Fmax，这条 `er1/er2 → u_ex → fwd mux → u_ex_h` 是第一优先级。

## 3. 资源（交付 profile，`device_map`）

```
Used,18333,9836,4,6,3664   (LUT, FF, DRM, APM, LUTRAM)
```

| 项 | P36a 交付 | **P37** | Δ |
|---|---:|---:|---:|
| LUT | 18,099 | **18,333** | +234 (+1.29%) |
| FF | 9,931 | **9,836** | −95 |
| LUTRAM | 3,628 | **3,664** | +36 |
| 站点合计 | 31,658 | 31,833 | +0.55% |
| CoreMark/kLUT | 0.2008 | **0.2103** | +4.7% |

## 4. 20 迭代 A/B（analysis profile，逐步）

| 版本 | 评分窗口 | Δ vs 交付 | store EX 停顿 | `ST_REFUSE` |
|---|---:|---:|---:|---:|
| P36a（交付基线） | 5,498,599 | — | 244,753 | 128,335 |
| + P37a 配对内 RAW 前递 | 5,401,931 | −1.76% | 246,268 | 128,335 |
| + P37b B-in-RESP | 5,262,920 | −4.28% | 110,036 | 17,083 |
| + 满队列同拍弹出可入队 | 5,256,538 | −4.40% | 103,032 | 16,804 |
| + `STQ_DEPTH` 2→4 | **5,212,477** | **−5.20%** | **55,648** | **12,310** |

配对侧（全局计数）：`PAIR_BLOCK raw` 895,937 → **720,997**，`take` 1,346,942 → **1,446,289**（多 99,347 对）。
重定向：n=137,926、平均恢复 **3.5 拍**（新探针 `REDIRECT`，说明前端恢复已不是瓶颈）。

## 5. 复现命令

```bash
# 回归
python tools/run_isa_e2e.py --modelsim <vsim> --toolchain-bin <xpack>/bin \
    --prefix riscv-none-elf- --extra-flag=-march=rv32im_zicsr      # 17/17
python sim/run_dcache_tests.py --modelsim <vsim>                   # PASS
python sim/run_engine_tests.py                                     # 64/64
# A/B
python tools/run_coremark_ab.py --switch CACHE --sides on \
    --image-dir build/native_software/coremark/performance/area20 \
    --out build/ab_p37 --modelsim <vsim>
# 镜像 + 实现
python tools/build_native_software.py coremark --iterations 1152 --mode performance \
    --tag score1152 --toolchain-bin <xpack>/bin --prefix riscv-none-elf- --extra-flag=-march=rv32im_zicsr
```
