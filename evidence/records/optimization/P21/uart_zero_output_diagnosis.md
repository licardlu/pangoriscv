# P21「板上零输出」根因：抓串口的顺序错了，不是 RTL / 固件问题

日期：2026-10-20（复核于 2026-10-20 晚）
结论一句话：**位流、镜像、`axi_uart`、`uart_putc` 都没有问题；是"先烧完再开串口"导致
整份报告在串口打开之前就已经发完并且不再重发。**

---

## 1. 现象与已排除项

| 项 | 事实 | 判据来源 |
|---|---|---|
| 串口/引脚/时钟/复位 | 正常 | `uart_free.sbit`（纯比特翻转发送，`clk=D18`、`uart_tx=C24`、115200）连续输出 `P21UART`，250 B |
| 交付位流本身 | **与 10-19 打出成绩的那一份逐字节相同** | `bitstream/pangoriscv_i768.sbit`、`evidence/.../P21/pds_27mhz_full/pangoriscv_top.sbit` 的 SHA256 均为 `1FAC6F43…B41F23` |
| 该位流的板上成绩 | 10-19 19:30 抓到 `Total ticks 288,558,769` / 832 迭代 / 五项 CRC 全对 / 2.8833 | `P21/board_uart_score.txt` |
| 位流里有程序 | 是 | `code_p21/build/pango_native` 综合日志有两条 `Loading memory data from file`（program.hex / data.hex） |
| `axi_uart` 与固件寄存器 | 一致 | CTRL 0x00 / STATUS 0x04 / BAUD 0x08 / TXDATA 0x0C / RXDATA 0x10，`lib/uart.h` 与 `perips/axi_uart.v` 逐项相同 |
| P21 RTL 是否被实验分支污染 | 没有 | `build/code_p21/rtl/**` 与 `git HEAD` 逐文件 `git hash-object` 全部相同；资源 16,782 LUT / 12,509 FF 与 P21 一致 |

**同一份位流 10-19 能打、10-20 打不出**，而位流哈希没变、串口链路又被 `uart_free` 证明正常，
所以变量只能是"测量方式"，不是设计。

## 2. 关键事实一：这份固件只在最后打印一次

`tests/example/coremark/core_main.c` 的顺序是

```
portable_init() … start_time(); iterate(); stop_time();
… 之后才是全部 ee_printf（"2K performance run parameters …" 到最后一行 CRC）
```

`tests/example/start.S` 结尾是

```
call _init
call main
loop:
    j loop
```

也就是说：**整份 691 B 报告在配置完成后约 10.7 s 一次性发完，之后永远不再发。**
832 迭代 × 346,825 ticks/迭代 ÷ 27 MHz ≈ 10.7 s。

## 3. 关键事实二：抓串口是在报告发完之后才打开的

10-20 的每一次尝试都是同一条命令（`run_flash.ps1` **同步**跑完，然后才 `capture_uart.ps1`）：

```powershell
& powershell -File .\run_flash.ps1 -Script 01b_program_only.tcl -Sbit ... -TimeoutSec 120
& powershell -File .\capture_uart.ps1 -Port COM34 -Seconds 20 -Out ...
```

而 `run_flash.ps1` **会阻塞满 `-TimeoutSec`**：`cdt_cfg.exe` 在 file-only Tcl 结束后不退出，
脚本按设计等满超时再杀进程。于是每次"烧写+抓取"的总耗时恒为

```
144 s = 120 s（阻塞） + 20 s（抓取） + 约 4 s（起停开销）
```

实测对照（前一会话工具返回时刻）：

| 时刻 | 动作 | 总耗时 |
|---|---|---|
| 14:24:12→14:26:36 | 烧 `code_p21` 重建版 + 抓 20 s | 144 s |
| 14:27:56→14:30:20 | 烧**交付位流** + 抓 20 s | 144 s |
| 14:34:12→14:36:21 | 烧 `uart_free` + 抓 5 s | 129 s |

按 120 s 阻塞推算：`cfg_program` 在 T+12 s 左右成功、设计随即开始跑、报告在 T+23 s 左右发完，
而串口在 **T+126 s** 才打开 —— 报告早已发完。**所以每次都是 0 字节，与设计无关。**

反过来看 10-19 那次成功：抓取是**先用后台 job 开**（`-Seconds 90`），`Start-Sleep 8` 之后才
跑 `run_flash.ps1`，再 `Start-Sleep 40` 读文件 —— 串口在复位前就已在听，自然抓到。

这也解释了为什么 `uart_free` "看起来好的"：它每 ~20 ms 重发一次，晚 2 分钟去抓照样能抓到。

## 4. 因此产生的无效证据（不得当成"板上无输出"）

以下 2 字节文件（`Set-Content` 写入空串时只留下 CRLF）都是"抓晚了"的产物，**不代表设计没发**：

```
evidence/records/optimization/4kb_3.423/uart_*.txt      （除 uart_free_capture.txt）
evidence/records/optimization/P21/uart_p21_uartfix.txt
evidence/records/optimization/P21/uart_known_good_check.txt
```

`uart_known_good_check.txt` 尤其危险：它被用来支持"连交付位流也不发了"的结论，
实际只是抓取窗口错位。

## 5. 正确做法（已落地为脚本）

`evidence/records/bottleneck_audit/board/flash_and_capture.ps1`：

1. 先检查 COM34 可打开（被占用就立刻报错，不烧）；
2. **后台启动 `capture_uart.ps1`**（`-Seconds` 取运行时间的 3 倍以上，如 90 s）；
3. `Start-Sleep 6` 后调 `run_flash.ps1`（`-TimeoutSec 30` 足够，`cfg_program` 只要 3.8 s）；
4. 等抓取窗口结束，打印原文，并校验 `Correct operation validated`、五项 CRC，
   按 `iterations / ticks × 1e6` 算 CoreMark/MHz，同时校验 `ticks / 27e6 ≥ 10 s`。

```powershell
cd pangoriscv\evidence\records\bottleneck_audit\board
powershell -ExecutionPolicy Bypass -File .\flash_and_capture.ps1 `
  -Sbit D:\FPGA_Project\zi_guang_tong_chuang\pangoriscv\bitstream\pangoriscv_i768.sbit `
  -Out .\p21_score_recheck.txt -Seconds 90
```

预期：691 B 原文 + `Total ticks 288558769` + 2.8833。

## 6. 顺带查出的一个真实缺陷：22:23 那次重建的位流 hold 不过

`firmware/code/build/code_p21/build/pango_native/multiseed_summary.csv`：

```
single,OK,Fail,8.810,19.682,-0.069,-0.067,…,3
        ^^^^                 ^^^^^^  ^^^^^^   hold 失败端点=3
```

即 **Convergence=Fail，Hold(Slow) −0.069 ns / Hold(Fast) −0.067 ns，3 个 hold 失败端点**；
而交付位流是 `All Constraints Met`，**+0.061 / +0.047**。

RTL 与镜像和交付版一致，差别只在布线（种子/选项），说明"同一份 RTL 重跑一次"并不自动等价，
**这个重建位流不能拿去交付或报分**（也违反赛题"report_timing 无失败端点"的硬性要求）。
既然 `uart_putc` 的"死锁"假设已被证伪，这次重建本身没有必要保留。

## 7. 复核清单

- [x] 交付位流 SHA 与 10-19 成功那一次一致（`1FAC6F43…B41F23`）
- [x] 串口链路（uart_free）独立验证通过
- [x] 固件只在 `iterate()` 之后打印一次、`start.S` 之后死循环
- [x] 每次失败尝试的"烧写+抓取"总耗时 = 144 s，抓取起点晚于报告 ~100 s
- [x] 10-19 成功那一次是"先开抓取、后烧写"
- [x] **2026-10-20 22:50 用 `flash_and_capture.ps1` 重抓一次：2.8833 复现**

## 8. 复现结果（2026-10-20 22:50，板上实测）

命令：

```powershell
cd pangoriscv\evidence\records\bottleneck_audit\board
powershell -ExecutionPolicy Bypass -File .\flash_and_capture.ps1 `
  -Sbit D:\FPGA_Project\zi_guang_tong_chuang\pangoriscv\bitstream\pangoriscv_i768.sbit `
  -Out .\p21_score_recheck.txt -Seconds 90
```

结果（`board_uart_score_recheck_2026-10-20.txt`，1,515 B）：

```
Total ticks      : 288558769
Total time (secs): 10
Iterations       : 832
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0xf745
Correct operation validated.
```

- `cfg_program succeed` 时间 22:50:26（`board_program_tcl_recheck_2026-10-20.log`）
- 运行时间 `288,558,769 / 27e6 = 10.687 s ≥ 10 s` ✔
- `CoreMark/MHz = 832 / 288,558,769 × 1e6 = **2.8833**` ✔（与 10-19 完全一致，逐字节同 ticks）
- 位流 SHA256 `1FAC6F43…B41F23`（同一个交付位流）

**报告前面那 91 行 `P21UART` 是证据而不是噪声**：抓取窗口在 `cfg_program` 之前就已打开，
那时 FPGA 里还是上一次烧进去的 `uart_free` 测试位流，它每 ~20 ms 发一次；
`cfg_program` 把它换成交付位流后，`P21UART` 停止，约 10.7 s 后一次性冒出 CoreMark 报告。
这正好证明"抓取确实盖住了启动与打印窗口"——而之前那 14 次 0 字节，缺的就是这一点。

