# 核心源码入口

用户当前要求：先完整仿照参考 VexiiRiscv 的逻辑与性能，再修改。当前执行以 `docs/verification/v8-exact-extraction.md` 和计划树 0A 为准。

| 路径 | 用途 | 入口 |
|---|---|---|
| `replica_native/` | 当前真正功能模块提取版；完整参考逻辑，四个 early/late 移位器已独立 | `pango_replica_core.v`、`sources.f` |
| `reference_exact/` | 不改变参考逻辑的原生模块拆分，对照与回退基线 | `VexiiRiscv.v`、`sources.f`、`manifest.json` |
| 本目录的 `pango_cpu.v` / `core_sources.f` | 保留其他 AI 的 V1/V2 简化架构实验 | 不作为“5.2 @120 MHz 完整仿照”的入口 |

当前模块版构建命令：

```powershell
py -3.10 tools/core_replica/extract_shifters.py verify
py -3.10 tools/core_replica/run_exact.py pds --variant native-shifters --name native-pds-001
```

命令在工程根运行；每次必须换新 run 名。首个已启动实现目录为 `build/core_exact/native-pds-001/`，PDS 工程为该目录 `implementation.pds`。不要误开旧 V2 工程来验证新源码。

完整参考逻辑保留不等于所有语义模块边界已经整理完。原式来源、模块提取、上板性能、最终 STA 分开验收；本轮不借重写基准或降低时钟来凑成绩。

本轮收尾：模块版两次独立上板均为 1309328358 ticks / 7000 迭代 / 5.346252494 CoreMark/MHz，五项 CRC 全对，与参考相同。位流验证副本在 `bitstream/replica_native_120/`；最终 setup WNS −1.426 ns，LUT +34，尚不标为全部交付门禁通过。
