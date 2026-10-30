# 完整参考逻辑仿照验证版（2026-10-30）

板卡：PG2L100H-6 / FBG676。位流：pango_replica_core_120.sbit。

已真实上板两次：PLL 120.461538 MHz；7000 迭代；两次均为 1309328358 ticks；5.346252494 CoreMark/MHz；10.869264827 s；五项 CRC 全对，与冻结参考相同。两次原始 UART 的 SHA256 也相同。

这是功能与性能对照验证版，**不是最终 STA 闭合交付版**。最终 setup WNS −1.426 ns（619 个失败端点），LUT 8875（参考 8841，增加 34）；完整模块化与 ILA 尚未完成。没有降频、修改约束或改动基准来掩盖这些事项。

自己的核心入口：rtl/core/replica_native/pango_replica_core.v，显式清单：rtl/core/replica_native/sources.f。四个 early/late 移位器已真正独立成模块；其余参考逻辑保持原式 sections，仍待继续提取语义模块。保留上游来源，不宣称这部分为独立原创架构。

可直接打开的 PDS 工程：build/core_exact/native-pds-001/implementation.pds。此工程连同 sources、constraints 和八 lane 初值已保留在该实现目录，不能把 .pds 单文件移走后假定其相对路径仍有效。

下载复现脚本：tools/core_replica/program_exact.ps1。原始证据：evidence/records/replica/P14-native/native-pds-001/。完整报告：docs/verification/v8-exact-extraction.md。SHA256SUMS 核验本目录各文件；measurement.json 指向真正生成并上板的同一份位流。
