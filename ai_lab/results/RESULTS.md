# AI 可行性验证结果表（唯一结果表）

更新：2026-10-18 19:35。所有“实测”有原始日志/文件；“估计”为推算，未验证。目录：`ai_lab/`。

## T1/T2 现成预训练垃圾检测模型（PC 对照）

| 项 | 结果 | 证据 |
|---|---|---|
| 模型 | `avgsoyam/yolo-garbage-detector-onnx`（Ultralytics YOLOv8 导出） | `data/models/garbage-detector.onnx`，12,254,287 B，SHA256 `DEECB3F48CE9265AEF58883A6A2A55A8EB2275AE6189D425B7707DBB4BC0CB5C` |
| 类别（实测元数据） | 5 类：0 garbage_pile / 1 plastic / 2 paper / 3 metal / 4 biodegradable | onnxruntime `custom_metadata_map.names` |
| 输入/输出（实测） | 1×3×640×640 float；输出 [1,9,8400]（4 框 + 5 类，无 NMS） | onnxruntime session |
| 许可（实测元数据） | AGPL-3.0（Ultralytics 导出元数据；模型卡本身无许可证声明） | metadata `license` |
| PC 运行 | 40 张图平均 37.1 ms/张（CPU，onnxruntime，含预处理/解码） | `results/t2_pc_results.csv`，脚本 `scripts/t2_final.py` |
| 独立来源测试（TrashNet，12 张） | conf≥0.25：0 张有检出；conf≥0.05：1/12 有检出 | `results/t2_pc_results.csv` |
| 同分布测试（keremberke test 抽 8 张） | conf≥0.25：0/8；conf≥0.05：2/8；最高类分数 0.2013 | 同上 |
| 结论 | 模型能加载/运行、类别与许可可核对；但对“垃圾识别”场景检测置信度很低，**不训练/不微调时不可用**。未找到可访问且可直接用的零训练垃圾检测 YOLO（`keremberke/yolov5n-garbage` 权重已有 3,912,765 B、模型卡称 6 类 mAP@0.5≈0.3199，但需 PyTorch 才能加载，且 1.87M 参数超出片上存储，未验证运行） | — |

## T3 YOLO-Fastest 1.1 逐层预算（自动解析 cfg+weights）

- 文件：`data/models/yolo-fastest-1.1.cfg`（9,685 B）+ `yolo-fastest-1.1.weights`（1,384,268 B，SHA256 `1C445C42BBD6DF63EDEA2CC69F99667B5650D663CA11E34B116240740CD42890`）；逐层表 `results/yolo_fastest_layers.csv`（132 层，84 个卷积）。
- 权重解析：cfg 推算 319,024 个卷积权重；weights 文件头后共 346,063 个 float，与“4×BN通道 + 非BN偏置 + 权重”预期 346,062 差 1 个 float（未定位，可能是尾部/版本字段；首层 216 权重解析值合理，BN 参数 var>0）。**全文件逐层对齐尚未完成**。
- 预算（估计，未用综合验证）：

| 输入 | MAC/帧 | 权重 INT8 | 激活峰值(不含输入) | 输入张量 | 三项合计 | 折算块数(4.5KiB/块，估计) |
|---|---|---|---|---|---|---|
| 160×128 | 25.09 M | 311.5 KiB | 150.0 KiB | 60.0 KiB | 521.5 KiB | ~116 |
| 160×160 | 31.36 M | 311.5 KiB | 187.5 KiB | 75.0 KiB | 574.0 KiB | ~128 |
| 192×160 | 37.63 M | 311.5 KiB | 225.0 KiB | 90.0 KiB | 626.5 KiB | ~139 |
| 224×160 | 43.90 M | 311.5 KiB | 262.5 KiB | 105.0 KiB | 679.0 KiB | ~151 |
| 320×320 | 125.44 M | 311.5 KiB | 750.0 KiB | 300.0 KiB | 1361.5 KiB | ~303 |

- 额外存储（估计）：每通道量化参数（M int32 + S uint8，7,142 个输出通道）≈35.7 KiB；层描述符 ≈1 KiB；检测头输出 ≈3.3 KiB；摄像头帧 160×120 RGB565 = 38.4 KiB；line buffer/双缓冲 ≈8 KiB。按 160×128 合计约 609 KiB ≈ **136 块（估计，未综合验证）**；可用约 151 块（155 − CPU 程序 RAM 4 块）。
- 存储读写（估计）：每帧权重读 311.5 KiB；激活写入合计 1.56 MB（Σ 各层输出），读写流量约 3.12 MB/帧（按每层读+写一次估算，未计行缓存复用）。
- 未验证：真实 BRAM 推断（T4 小 ROM 推断成分布式存储，DRM=0）、层间缓冲复用、实际带宽/瓶颈。

## T4 最小计算电路（实测）

- 电路：`rtl/conv3x3_tile.v`，8 路 INT8 MAC，实现 YOLO-Fastest 第 1 层（3 入通道→8 出通道、3×3、stride2、pad1、BN 折叠、M>>15 requant、LeakyReLU），2×2 输出像素块；输入/权重/bias/M 用 `$readmemh` 初始化。
- 功能（实测）：ModelSim 仿真 32/32 输出与 Python INT8 golden 完全一致（0 错）、145 周期完成 864 MAC（4 像素×8 通道×27 tap，8 MAC/周期，平均 5.96 MAC/周期）；日志 `sim/t4_run`。
- PDS 实测（`pds/t4_run`，器件 PG2L100H-6FBG676，27 MHz 约束 37.037 ns）：
  - LUT 565 / 66,600（0.85%）；FF 286 / 133,200（0.21%）；APM 11 / 240（4.58%）；DRM 0 / 155。
  - `Design Summary : All Constraints Met.`；Slow Setup WNS +23.542 ns、Hold WHS +0.293 ns（0 失败端点/1138）。
  - 4 个 `$readmemh` 文件在 compile 日志中均 `Loading memory data from file`（权重初始化路径可用）。
  - 说明：小数组被推成分布式 ROM/LUTRAM（DRM=0），**不能据此证明 311.5 KiB 权重能按预期推断为 BRAM**。
- 外推到 64 MAC（估计，未实现/未综合）：APM 约 75–90（31%–38%），LUT 与控制逻辑约 2–4k（估计）；此推算未验证。

## T5/T6 边界与约定

- T5：本轮仅固定图片/离线数据；摄像头（OV5640 DVP）与 HDMI 未接线、未验证，不得视为完成赛题“传感器/显示集成”。
- T6：`ai_lab/README.md` 定义开始/完成/错误与数据存放约定；未改 CPU/公共连接文件。

## 关键结论

1. 现成模型：能跑，但独立图片上基本检不出垃圾；零训练不可用。若继续该应用，**训练/微调是必要的**（或找到更合适的权重）。
2. 关键计算：最小 3×3 INT8 卷积与 Python 逐项一致（32/32），说明量化/requant/LeakyReLU 的算法约定可落到 RTL。
3. 实际资源：8 MAC + 控制 = 565 LUT / 286 FF / 11 APM，27 MHz 时序余量很大；但整模型存储仍是估计，BRAM 推断未验证。
4. 整模型困难：总存储估计 ~136 块（可用 ~151）偏紧；全文件权重解析差 1 float；层调度/line buffer/带宽未实现；CPU 后处理与摄像头链路未开始。
5. 路线：建议先把模块从“一个 2×2 像素块”扩到“一整层卷积（含 line buffer + 真实 BRAM 权重）”，同时解决训练问题；在整层实测前，不承诺“全片上放得下/25–45 ms”。
