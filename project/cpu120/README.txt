project/cpu120：120 MHz CPU 独立源码包
=====================================

来源：咨询方提供的 YOLO_AI_core 与 CPU_120MHz_latest 两个压缩包；本目录是从中抽出的 CPU 部分，CPU 时序按 120 MHz 验证，YOLO 整机另行处理。

内容
- rtl/board、rtl/core、rtl/soc：板级顶层、处理器核心与 SoC。
- constraints/：PG2L100H-6 / FBG676 的 FDC/PCF，27 MHz 输入，PLL 120.461538 MHz。
- firmware/：冻结的 7000 次 CoreMark 镜像与对应源码。
- provenance/：来源映射、原式提取清单与许可证，仅供审计。
- sources.f：43 个设计输入；release_manifest.json：本包文件清单与 SHA-256。
- tools/：构建、校验、下载与板测脚本；入口 tools/build.py。

边界
- ZIP 中现存文件的哈希全部匹配；ZIP 缺少原发布清单列出的部分历史文档、参考测试与构建文件，因此不能标为完整发布包验收。
- 位流副本为 pds_native_120/bitstream/current/pango_replica_core_120.sbit，SHA256 2e38db1c26bd6a1bcb9a3fe1d09ca6d70bf430d5ac50001f450664a50c81f9cb；两次上板均为 7000 次、1309328358 ticks、5.346252494 CoreMark/MHz。
- 该位流最终 Setup WNS 为 -1.426 ns、619 个失败端点，STA 未闭合，不是时序合规终版。
- 本目录只含 CPU，不含 YOLO 整机；YOLO 集成入口见 project/yolo120。
