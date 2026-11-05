# 位流目录

本目录只有一份 CPU 位流，**没有**完整视觉应用的位流（那个在 `project/trash_sorting/prebuilt/full_v3_27mhz/`）。

| 文件 | 说明 |
| --- | --- |
| `replica_native_120/pango_replica_core_120.sbit` | 120.461538 MHz CPU + CoreMark 7000 迭代，**已两次真实上板**：1309328358 ticks、五项 CRC 全对、5.346252494 CoreMark/MHz。SHA256 `6a7eb74c43e7f42ea8c1ff73693348726bbf7c66c14221bd65ec1ac1afba9198` |

## 这份位流的身份

它是**功能与性能对照验证版**，用来证明"复现的 CPU 逻辑与参考实现跑出同样的拍数"。它**不是 STA 闭合版**：最终 setup WNS `−1.426 ns`、619 个失败端点。

如果要用"可独立重建、能逐文件核对"的那一份，请用：

```
project/pds_native_120/bitstream/current/pango_replica_core_120.sbit
SHA256 2e38db1c26bd6a1bcb9a3fe1d09ca6d70bf430d5ac50001f450664a50c81f9cb
```

两者烧进去的是同一份 8 lane 固件、跑出的 ticks 完全相同，只是产生于不同构建目录，所以位流字节不同。分数与它们绑定的板测原始记录在 `project/pds_native_120/evidence/standalone-board-00{1,2}/`。

## 为什么这里不放更多位流

每次实现的位流副本都归档在对应证据目录（`evidence/records/**`），一个实现一个目录，免得"位流和时序报告对不上号"。本目录只留一份方便直接下载的副本。
