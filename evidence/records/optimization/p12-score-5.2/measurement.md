# p12 — 5.217 CoreMark/MHz（跨行成对 + ID 寄存器旁路）

RTL：`2b64728`（S1）+ `b528d84`（S2/T1b）+ `1fba07d`（T1a）
仿真镜像：`build/native_software/coremark/performance/sim20_o2`（20 迭代，O2，`RV32_DEBUG`）

## 分数

| 项 | 值 |
|---|---:|
| `Total ticks` | **3,833,976** |
| `Iterations` | 20 |
| **CoreMark/MHz** | **5.217**（= 20e6 / 3,833,976） |
| 上个基线 `01ba45e` | 4,070,391 → 4.914 |
| 本轮净收益 | **−236,415 tick（−5.81%）** |

分数只由 `Total ticks` 反推（`Iterations × 1e6 / Total ticks`），
不用 `Iterations/Sec` 或 `Total time`（整数截断会虚高 6.4%，见 mistakes-log）。

## 五项 CRC（全部正确）

```
seedcrc    : 0x54414c55
[0]crclist : 0xe714
[0]crcmatrix: 0x1fd7
[0]crcstate : 0x8e3a
[0]crcfinal : 0x4983
```

`crcfinal = 0x4983` 与 `01ba45e` 及更早的通过运行一致。

## 两处改动的归因

| 提交 | 改动 | `Total ticks` |
|---|---|---:|
| `01ba45e` | 起点 | 4,070,391 |
| `2b64728` | I-Cache 跨行成对（word7 + 下一行 word0） | 3,971,170 |
| `b528d84` | ID 寄存器旁路（+ 并行的下一 PC/预测校验） | **3,833,976** |

S1 的探针证据：`WIN_NOPAIR off[7]` 192,555 → 25,608（−167k），
但 `Total ticks` 只掉 99k ⇒ 约 40% 的 off=7 请求在那一拍后继行不在 Cache 里，
第一次经过时本来就该 miss，这一部分成对不成立。

S2 的收益 −137,194 tick，来自消除"ID 空 + 指令已到 ⇒ 仍要等一拍"的结构气泡
（改前 `WIN_NOISSUE other` = 145,951）。

## 面积（`p14timing120` 综合，PERF on / 120 MHz 约束）

见同目录 `area.md`（构建完成后填）。

## 复现

```
python tools/run_coremark_sim.py \
  --image build/native_software/coremark/performance/sim20_o2 \
  --tag p12 --define RV32_DEBUG
```

## 正确性回归

```
python tools/run_isa_e2e.py \
  --toolchain-bin D:/FPGA_Project/zi_guang_tong_chuang/toolchains/xpack-riscv-none-elf-gcc-15.2.0-1/bin \
  --prefix riscv-none-elf- --extra-flag=-march=rv32im_zicsr \
  --modelsim D:/FPGA_Project/Modelism/win64
```

结果 **20 / 21 PASS**，与 `01ba45e` 基线一致（case 21「predicted branch target
pairing」在基线上也不通过，属于探针口径问题，不是本轮引入）。
本轮直接命中 case 2（load-use）、16/17（同拍 WAW/RAW）、18（lane1 访存）、
19/20（lane1 总线故障 / 非对齐）——即旁路改动最可能破坏的那几类。
