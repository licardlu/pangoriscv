# 4kb_3.423 实验目录：其中 all-zero 串口文件**不是**"板上无输出"的证据

本目录里的 `uart_p21_*.txt`、`uart_4kb_1024.txt` 等 2 字节文件
（`Set-Content` 写空串时只留 CRLF）全部是 **2026-10-20 抓取窗口错位**的产物：
它们都在 `run_flash.ps1` 同步返回之后才打开 COM34，
而 CoreMark 固件只在 `iterate()` 结束（约 10.7 s）时**一次性**打印报告、
`start.S` 之后死循环不再重发 —— 串口打开时报告已经发完。

判据：每次"烧写+抓取"总耗时恒为 **144 s = 120 s（`run_flash.ps1` 阻塞）
+ 20 s（抓取） + 开销**，抓取起点晚于报告约 100 s。

- 详见 `docs/lessons/mistakes-log.md` §7.6
- 完整根因与复核清单：`evidence/records/optimization/P21/uart_zero_output_diagnosis.md`
- 正确姿势：`evidence/records/bottleneck_audit/board/flash_and_capture.ps1`（先开串口，后烧写）

**这些文件不得作为"设计不发数据"或"4KB 版跑不起来"的依据。**
唯一有效的一行是 `uart_free_capture.txt`（250 B `P21UART`），它只证明串口链路正常。
