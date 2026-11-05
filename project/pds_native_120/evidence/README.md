# 证据目录说明

一个实现一个目录，每个目录里放的是**当时**的原始产物，不是整理后的摘要。

| 目录 | 是什么 |
| --- | --- |
| `standalone-board-001` / `-002` | 交付位流（`2e38db1c…`）的两次真实上板：`uart.log` 原始串口、`program_trace.txt` JTAG 流程、`board_capture.json` 下载元数据、`measurement.json` 判读结果 |
| `implementation-standalone-001` | 上面那份位流对应的构建记录：资源、最终时序、8 路镜像核对 |
| `baseline/` | 更早一次独立构建（`6a7eb74c…`）的同类记录，作为对照 |
| `isolation/` | 把本目录搬到仓库外单独构建时的隔离检查结果 |
| `indep-rebuild-001/` | 2026-11-04 又做的一次搬家式重建，记录资源与时序的复现程度 |
| `release/` | 与发布相关的清单快照 |

## 两条使用注意

1. **`program.tcl` 是归档原件，不能直接执行。** 里面写的是当时那台机器上的绝对路径（`D:/FPGA_Project/...`）。要重新下载，用 `tools/program.ps1`，它会按当前目录生成新的 tcl。
2. **`uart.log` 是字节流原件**，用文本编辑器打开可能看到 `\r\n` 混排，那是正常的——判读请用 `tools/check_board.py`，它按正则逐字段取值并与冻结基线比对。

## 想看"分数是怎么来的"

```
python tools/check_board.py evidence/standalone-board-001
```

它会重新解析 `uart.log`，把 `CPU_HZ` / `ITERATIONS` / `Total ticks` / 五项 CRC 全部提出来重算 `CoreMark/MHz`，再按 SHA256 在包内找到对应位流。任何一项对不上就报错。
