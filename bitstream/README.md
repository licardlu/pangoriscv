# 发布版位流

| 文件 | 大小 | SHA256 |
|---|---|---|
| `pangoriscv_i400.sbit` | 3,791,112 B | `F8254F66EF9C78B53E3DD4E6516BA55BAA2F00C7C76EB2379D78FEC8962CE77C` |

**板卡**：Pango PG2L100H，27 MHz 时钟。

**配置**：Cache 开启、性能计数器开启、动态分支预测开启（即全功能配置）。

**固件**：CoreMark 400 次迭代，performance 种子。板上串口输出：

```
Total ticks      : 320541251
Total time (secs): 11
Iterations/Sec   : 36
Iterations       : 400
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x25b5
Correct operation validated
```

即 **1.35 CoreMark/MHz**（官方整数秒口径；按 tick 精确为 1.25）。

**实现结果**：0 个 setup 失败 / 0 个 hold 失败，共 48,214 个时序端点；27 MHz 下 setup 余量
+16.262 ns（周期 37.037 ns），等效关键路径约 20.8 ns。

自行重新构建位流的流程见 `firmware/code/platform/pango_native/README.md`。
