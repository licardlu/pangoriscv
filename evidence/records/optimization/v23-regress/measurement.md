# v23 回归证据（2026-10-24）

全部在主干 `main` 上重跑，工具链 `xpack-riscv-none-elf-gcc-15.2.0-1`
（`--prefix riscv-none-elf- --extra-flag=-march=rv32im_zicsr`），ModelSim `D:/FPGA_Project/Modelism/win64`。

## 1. CoreMark 20 迭代（cut-2 树，无 P57）

`coremark_20it_cut2_transcript.txt`

```
Total ticks      : 3810700
Iterations       : 20
seedcrc          : 0x54414c55
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x4983
```

⇒ **190,535 拍/迭代 ⇒ CoreMark/MHz = 20e6/3,810,700 = 5.2484**，与交付位流逐位相同。

## 2. CoreMark 20 迭代（cut-2 + P57）

`coremark_20it_p57_transcript.txt`

```
Total ticks      : 3810540      (比交付少 160 拍)
seedcrc 0x54414c55 / crclist 0xe714 / crcmatrix 0x1fd7 / crcstate 0x8e3a / crcfinal 0x4983
```

⇒ 5.24862。P57 在**拍数**上是免费的（甚至略好），但在 52 MHz 的**布线后路径**上是负收益
（20.252 vs 19.426），见 `../p58r52/measurement.md`。

## 3. ISA e2e（cut-2 树）

`isa_e2e_cut2.log` —— `SUMMARY 20 / 21 PASS`，唯一失败是 case 21 的覆盖率断言
（`E2E_TARGET_PAIR target=0 wrong=0`，而 `TEST_PASS case=21` / 寄存器值 / `Errors: 0` 全对）。

**A/B**：换回交付树（commit `232dfa3`）重跑，同样 `target=0 wrong=0`、同样 20/21
⇒ 与 cut-2 无关，是 TB 覆盖探针在这套镜像下取不到数。判据应为
`TEST_PASS` + `E2E_REG` 值 + `Errors: 0`（见 `docs/lessons/mistakes-log.md` §98）。

## 4. ILP 定标（现场复算）

```
python tools/ilp_bound.py build/native_software/coremark/performance/sim20_O2/firmware.dump
blocks=310  instructions=3347  mem=696 (20.8%)  ctrl=272 (8.1%)

width memports  model IPC  calibrated  ticks/iter   score
    2        1      1.598       1.752      191534   5.221   <- 实测 5.2484
    3        2      2.060       2.259      154523   6.472
    4        4      2.283       2.504      142002   7.042   <- 天花板
```
