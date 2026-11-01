# positive020_route20 续验记录

## 身份

- 工程：`pangoriscv_improved1_20261030/project/pds_native_120`
- 器件：PG2L100H-6IFBG676
- PDS：2022.2-SP6.1
- 输入 PLL：27 MHz × 58 / 13 = 120.461538 MHz
- CoreMark 镜像：与上板基线相同；ELF SHA256 `5c4ecd094efd2fea33f08d9f5ac8e79118584e85588a7bf18189bf37da0c270b`

## 物理实现结果

`build_result.json` 为 `sta_pass`，八个程序 RAM lane 均加载。最终位流 SHA256：

```text
dc63a61637bb9e5183c016d2f8dba9240d3edf22f16458fe06c9bfe557040174  pango_vexii_top.sbit
```

最终多角时序：

| 检查 | WNS（ns） | 失败端点 |
|---|---:|---:|
| Slow setup | +0.145 | 0 |
| Slow hold | +0.020 | 0 |
| Fast setup | +3.102 | 0 |
| Fast hold | +0.012 | 0 |

Recovery、removal、最小脉宽也均为正。Device Map 为 LUT 8907、FF 7237、DRM 34、Distributed RAM 72；相对旧面积门槛 8875 LUT 超出 32 LUT，不能称面积门禁通过。

## 性能候选筛选

- PC-only GShare 索引：20 次短跑 `3,899,726 ticks`，慢于当前短跑基线 `3,799,461 ticks`，已回退。
- GShare 初始化 `8'hAA`：20 次短跑 `3,779,968 ticks`，但严格 reference/replica lockstep 在 cycle 256 的寄存器快照失败，已回退。
- 短跑运行时间不足 10 秒，不得作为正式成绩。

## 结论

该目录只证明一次独立 PDS 物理实现的时序余量改善；`board_verified=false`，不能用于宣称新的实板频率、CoreMark/MHz 或 5.6 分达标。当前唯一有效实板成绩仍为 7000 次、1,309,328,358 ticks、10.869264827 s、5.346252494 CoreMark/MHz、120.461538 MHz。
