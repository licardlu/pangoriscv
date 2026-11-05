# CoreMark 固件

跑在 `project/pds_native_120` 里的裸机固件：CoreMark v1.0 官方源码 + 一层很薄的移植（UART 输出、`mcycle` 计时、启动汇编、链接脚本）。

```
firmware/
  coremark/       官方 CoreMark v1.0 源码，未改造
  port/           移植层：core_portme.c/.h、core_portme.mak、ee_printf.c、start.S、link.ld
```

## 迭代数与 10 秒规则

交付档 **7000 次迭代**，PLL 120.461538 MHz 下实测 **1,309,328,358 ticks = 10.869 s**，满足"单次运行 ≥ 10 s"的要求，余量 8.7%。

反推公式：`迭代数 × 每迭代拍数 ÷ 频率`。本设计每迭代 **187,046.91 拍**，所以 10 s 的临界点约在 **6441 次迭代**。别把迭代数改到 6400 以下，会掉出规则。

改迭代数后必须重新生成固件并回填 8 路 ROM 初值，否则位流里还是旧程序。

## 构建（权威路径）

```powershell
$env:PATH = "<xpack-riscv-none-elf-gcc>/bin;" + $env:PATH
python scripts/build.py firmware --iterations 7000
```

脚本在仓库根执行，产物在 `build/firmware_7000/`：

| 文件 | 内容 |
| --- | --- |
| `coremark.elf` | 可执行文件 |
| `coremark.dis` | 反汇编（查地址用） |
| `coremark.map` | 链接映射 |
| `size.log` | 段大小 |
| `compiler_flags.h` | 参与编译的完整选项列表，同时被编进二进制的 `COMPILER_FLAGS` 字符串 |

优化选项是刻意堆出来的（`-funroll-all-loops`、`-falign-*=8`、`-finline-limit=1000`、`-mtune=sifive-7-series` 等），**改一个字符就可能改变拍数**。想复现交付成绩就用原样，不要"顺手优化一下"。

## 构建（GNU make，可选）

```powershell
cd firmware/coremark
make PORT_DIR=../port ITERATIONS=7000 CC=riscv-none-elf-gcc
```

`firmware/port/core_portme.mak` 用的是与 `scripts/build.py` 同一组选项。xpack 工具链不带 `make`，需要自己装。两条路径的产物应当具有相同的 RAM 镜像。

## 源码与冻结镜像的关系

`project/pds_native_120/firmware/image/` 里的 `coremark.elf` 和 8 个 `*.bin` 是**冻结镜像**，位流就是用它生成的。它与本目录源码的关系已经被验证过：

```powershell
python scripts/verify_image.py build/firmware_7000/coremark.elf project/pds_native_120/firmware/image
# checked_bytes 36444
# ram_sha256 = c0166c5cf86143cacd3b50c46b1c7f9ba28796e5b8f4c9d5dcc5507d6a3ef31d
```

`ram_sha256` 一致即"源码 → 镜像"闭合。**注意比较的是 RAM 镜像，不是 ELF 文件的 SHA256**：ELF 里含调试段和构建路径，换台机器重编就会变，那不说明任何问题。

## 8 路 lane 是什么

SoC 的程序 ROM 被拆成 8 个独立字节宽度的存储器（`Ram.v` 里 `mem_symbol0..7`，各 8192×8 bit），读出时按字节拼成 64 位。PDS 的 `$readmemb` 只能吃文本位图，所以每个 `*.bin` 其实是 **ASCII 位图**：8192 行、每行 8 个 `0/1` 字符，共 73728 字节。**别当二进制文件处理。**

拼装规则：

```
ram[i] = lanes[i % 8][i // 8]        # 按字节交错，不是按字
```

`scripts/verify_image.py` 就是按这条规则把 ELF 的 `.text/.rodata/.data` 铺成 64 KiB 再比 SHA。改完固件要重新生成这 8 个文件时，照抄它的实现，别自己发明顺序。

## 计时与判分

`core_portme.c` 用 `mcycle/mcycleh` 读 64 位周期计数，`stop_time - start_time` 就是 `Total ticks`。计时窗口只包住 CoreMark 的迭代主体，UART 打印在窗口外。

⚠️ `HAS_FLOAT=0`，`time_in_secs()` 返回 `ee_u32`，所以串口上的 `Total time (secs): 10` 和 `Iterations/Sec: 700` 都是**整数截断**值。用它们反推会得到 5.81（虚高 8.7%）。正确做法：

```
CoreMark/MHz = 迭代数 × 1e6 / Total ticks = 7000e6 / 1309328358 = 5.346252494
```

固件末尾额外打印 `TICKS_HI` / `TICKS_LO` 就是为这个准备的。

## CRC 怎么判

| 字段 | 期望值 | 说明 |
| --- | --- | --- |
| `seedcrc` | `0xe9f5` | 定值 |
| `[0]crclist` | `0xe714` | 定值 |
| `[0]crcmatrix` | `0x1fd7` | 定值 |
| `[0]crcstate` | `0x8e3a` | 定值 |
| `[0]crcfinal` | `0x25b5` | **随迭代数变化**，不是定值 |

官方 CoreMark README 的示例日志里 `crcfinal` 是 `0x33ff`，那是别的迭代数。拿 `0x33ff` 对 `0x25b5` 会误判成失败。四个定值对上了就是正确。

## 频率怎么改

`CPU_HZ` 是**编译期常量**（`core_portme.c` 开头，默认 `120461538`），同时决定 UART 分频和秒换算：

- 换 PLL 不重编固件 → 波特率同比漂移，115200 的串口可能收不到；分数换算也会错。
- 重编时加 `-DCPU_HZ=<新频率>` 可以正确换算，但 ELF 就不再等于冻结镜像。

UART 分频按四舍五入算：`(CPU_HZ + 460800) / 921600 - 1`。120.461538 MHz 下是 `131 - 1 = 130`，与冻结镜像一致。**直接整除会得到 129，镜像差一个字节**——这个坑踩过一次，见 `docs/lessons/mistakes-log.md`。

## 改动前的检查清单

1. 改完先 `python scripts/build.py firmware --iterations 7000`，确认能编过。
2. `python scripts/verify_image.py ...` 看 `ram_sha256`。只改注释/无关代码时它应该**不变**。
3. 若 `ram_sha256` 变了：确认是有意改指令流，然后同步 8 个 lane，再重建位流。
4. 重建后必看综合日志有没有 **8 次** `Loading memory data from file`。少一次，位流里就没有程序，板上零输出。
