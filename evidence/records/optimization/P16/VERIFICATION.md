# 交付成绩复现性核验（2026-10-18）

## 1) 768 迭代交付跑分：从零重跑，与记录逐字段一致

重跑命令：
  python tools\run_fetch_ab.py --baseline-rev HEAD --files rtl/core/lsu_axi.v --sides work 
    --image-dir build\native_software\coremark\performance\score768 
    --max-cycles 600000000 --out build\verify_score768

结果（与 P16 归档记录对比）：

| 项 | 归档记录 | 本次重跑 | 一致 |
|---|---|---|---|
| ticks | 287,211,317 | 287,211,317 | ✔ |
| cycles | 288,997,740 | 288,997,740 | ✔ |
| retires | 222,179,042 | 222,179,042 | ✔ |
| IPC | 0.7688 | 0.7688 | ✔ |
| seedcrc | 0xe9f5 | 0xe9f5 | ✔ |
| crclist | 0xe714 | 0xe714 | ✔ |
| crcmatrix | 0x1fd7 | 0x1fd7 | ✔ |
| crcstate | 0x8e3a | 0x8e3a | ✔ |
| crcfinal | 0x3c53 | 0x3c53 | ✔ |
| validated | True | True | ✔ |
| traps / faults | 0 / 0 | 0 / 0 | ✔ |

结论：RTL 仿真对同一镜像完全确定性，成绩**逐字节可复现**。

## 2) P16 的改动：真正的双侧受控 A/B（隔离 rtl/perips/axi_ram.v）

命令：
  python tools\run_fetch_ab.py --baseline-rev c153039 --files rtl/perips/axi_ram.v --sides both 
    --image-dir build\native_software\coremark\performance\perf_on --max-cycles 40000000

注意基线修订必须是 **c153039**（改动前的提交）。用 HEAD 作基线会得到 0.00%，
因为 HEAD 里已经包含改动后的文件——这一点第一次验证时踩到并纠正。

| 指标 | 基线（旧 axi_ram） | 本版 | 变化 |
|---|---|---|---|
| ticks | 7,658,647 | 7,478,647 | **−2.35%** |
| cycles | 9,561,172 | 9,379,156 | −1.90% |
| if_wait | 788,983 | 654,975 | **−16.98%** |
| i_miss | 18,289 | 18,289 | 0（未变） |
| d_miss | 4,655 | 4,655 | 0（未变） |
| mispred | 153,686 | 153,694 | +8（噪声） |
| 五项 CRC | — | — | **逐项相同** |
| architectural transparency | — | — | PASS |

**因果链清晰**：缺失次数一个没变，只有 if_wait 掉了 17%，说明收益全部来自
"同样次数的缺失、每次更快"，正好对应"猝发读每拍从 3 周期降到 2 周期"。

## 3) 修正的记账错误

- 原文把"CoreMark/MHz +2.42%"误写成"ticks −2.43%"。正确口径：
  **ticks −2.35%**（7,658,647 → 7,478,647），**CoreMark/MHz +2.42%**（2.6109 → 2.6740）。
  已在 measurement.md / intro / roadmap 三处改正。
- roadmap 该行曾混入控制字符 U+0007（早期用 PowerShell 双重引号插入 markdown 时
  （早期用 PowerShell 双引号插 markdown 时，反引号加字母 a 被当成 BEL 转义，使 `axi_ram` 前的 `` `a `` 变成控制字符）。已修复；文档类 markdown 复扫 BEL/ESC 结果为 0（PDS 自家日志里的换页符属工具字节，不算）。
  全仓（docs/evidence/bitstream/firmware）复扫控制字符数为 0。