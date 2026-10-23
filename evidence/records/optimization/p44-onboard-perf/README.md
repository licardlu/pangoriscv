# P44 —— 真机性能计数器采集（分析构建）

## 目的

赛题把"ILA 波形 + 性能分析文档"列为**评分项**。本目录用于把此前的**仿真结论**
用片上计数器在**真机**上复核一遍。计数器硬件早已存在
（`rtl/perips/perf_regs.v`，`PERF_ENABLE` 已打开，基址 `0x60002000`），
固件也早已实现 `portable_fini()` 里的 `P` 行打印，只是**需要 `-DPERF_DUMP` 编译**，
而交付镜像没有带这个宏。

## 已完成的准备

1. 镜像：`build/native_software/coremark/performance/hw_i2700_48_prof`
   （2700 迭代、`CPU_FREQ_MHZ=48`、`-O2`、额外 `-DPERF_DUMP`）。
2. 位流：`build/P44a/generate_bitstream/pangoriscv_top.sbit`（48 MHz，PLL 27×64/36）。

## 两个必须记住的实测事实

| 项 | 结果 | 含义 |
|---|---|---|
| `-DPERF_DUMP` 对计时区间的影响 | 20 迭代仿真：**3,805,377**（基线 3,810,700，反而 −5,323）| 打印发生在 `stop_time()` 之后，不改计时；差异来自代码布局 |
| `-DPERF_DUMP` 对时序的影响 | 48 MHz 下布线 **21.633 ns，WNS −0.800**（失败）| 镜像内容改变 ⇒ BRAM 初始化值改变 ⇒ 综合/摆放结果改变 ⇒ **这份是分析构建，不作为交付** |

## `P` 行格式（来自 `core_portme.c`，勿改顺序）

```
P <cycle> <instret> <if_wait> <lsu_wait> <i_miss> <d_miss> <ret_cf> <mispred>
```

- 只打印低 32 位（高位未打印，因为 16 KiB flash 余量紧张）；2700 迭代下 cycle 会超过 2^32，
  需要用 `Total ticks` 校正总量。
- `if_wait` 与 `lsu_wait` 是**重叠**视图，**不能相加**。

## 取数步骤（板子恢复供电后一步即可）

1. 在同一 PowerShell 会话内清掉代理变量（否则 `Start-Process` 报
   "字典中的关键字 HTTPS_PROXY 与 https_proxy 冲突"，见 mistakes-log §13.4）：

   ```
   foreach ($n in 'https_proxy','http_proxy','all_proxy','no_proxy') {
       Remove-Item -Path "Env:$n" -ErrorAction SilentlyContinue
   }
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
   ```

2. 进入 `evidence/records/bottleneck_audit/board`，执行 `flash_and_capture.ps1`，
   `-Sbit` 指向 `firmware/code/build/P44a/generate_bitstream/pangoriscv_top.sbit`，
   `-Port COM34`，**`-Seconds 130`**（≥120 s，因为 `P` 行在 `Correct operation validated`
   之后，60 s 窗口会截掉），`-Out` 指向本目录。

## 2026-10-23 14:20~14:23 两次尝试：**被硬件阻断**

```
E: JtagServer-0306: No devices detected while scanning the JTAG chain
E: Configuration-0008: The command 'Open config cable' execute fail.
串口抓包：全空（FPGA 未配置）
```

JTAG 下载线枚举正常（`USB\VID_3277&PID_00A0`，状态 OK），CP210x 串口也正常，
但**扫描不到器件**且串口无任何输出 ⇒ 目标板当前未上电 / 未释放复位。
这不是脚本或位流的问题：同一脚本在 11:24 曾成功烧录 `board48` 并抓到完整 CoreMark 输出
（`board_p35a.txt`）。

⇒ **交付状态不受影响**：`bitstream/pangoriscv_board48_i2700_5p245.sbit` 已在 11:24
完成上板实测（5.2447 @ 48 MHz，五项 CRC 全对）。
