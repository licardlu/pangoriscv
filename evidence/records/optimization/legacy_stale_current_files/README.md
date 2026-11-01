# 本独立源码包重新构建并两次上板的位流

构建：build/standalone-001；设备 PG2L100H-6 / FBG676；PLL 120.461538 MHz。

文件 pango_replica_core_120.sbit 的 SHA256：2e38db1c26bd6a1bcb9a3fe1d09ca6d70bf430d5ac50001f450664a50c81f9cb。

两次独立 SRAM 下载均：7000 迭代、1309328358 ticks、10.869264827 s、5.346252494 CoreMark/MHz、五项 CRC 全对。原始 UART 与下载记录在 evidence/standalone-board-001、standalone-board-002；本次最终资源、STA 与成绩在本目录 measurement.json，归档原件 evidence/implementation-standalone-001/。

最终 setup WNS -1.426 ns，STA 未闭合；LUT +34，面积中性门禁未过。该位流是等性能上板验证版，不是 STA 合规终版。源码独立交付不等于整核自主语义重写完成。源码、固件、约束与构建工具全部在本独立包内，构建不读取外部参考目录。
