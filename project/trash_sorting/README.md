# 青禾视觉垃圾分类应用源码

该目录补充本仓库此前缺少的完整外围应用资料，来源于本聊天整理的技术代码快照。实际代码位于 `source/yolo` 和 `source/extensions/business/application`，包含摄像头、HDMI、CPU/AI、界面、按键答题、四路 PWM 及语音 ROM。

| 路径 | 内容与边界 |
| --- | --- |
| `source/yolo/sources/` | 编号 000~070 的 CPU、卷积、摄像头、DDR、视频 RTL 和引脚约束 |
| `source/yolo/software/` | CPU 上运行的 AI 调度、解码、通信 C 固件 |
| `source/yolo/model/` | 六类模型描述、内存表与模型权重 |
| `source/yolo/ipcore/` | DDR3、PLL、读写帧缓存 IP 的 IDF 与源文件 |
| `source/yolo/portable/` | 去掉机器绝对路径的 `009_Ram.v`、`052_yolo_camera_top.v`，是构建实际选用的版本 |
| `source/yolo/tb/` | 检测框 OSD 与结果提交的 testbench |
| `source/extensions/business/application/rtl/` | 消抖、答题状态机、舵机、I2S/语音、界面 |
| `source/extensions/business/application/tests/` | 外围 RTL 验证用例 |
| `variants/v3_programmed_reference/` | 当前实际下载的 v3 局部顶层/前端、时序摘要及下载记录；不是全部输入冻结包 |
| `variants/v4_source_only/` | 后续中文标签、叠加顺序、舵机方向等修改；没有可下载 v4 位流 |
| `stm32_reference/` | 原有 Keil 工程快照，PB12~15 输入，PA0~3 输出；未与 v3 完成配套联调 |

此处的 v3 是 27 MHz 系统，不等于 `project/yolo120` 的 120.461538 MHz 速度实验。`source/yolo/build_pre_pnr.tcl` 和 `source/yolo/portable/` 是历史构建入口，不能把它们的默认诊断模式或可变依赖当作 v3 位流的完整冻结来源；本次未改写 RTL、未重新实现。

STM32 当前代码仍有旧颜色顺序与方向掩码：输入 0x0、输出 0xD（`SERVO_REV_BLUE/RED/GREEN = 1`，`SERVO_REV_GRAY = 0`）；v3 为绿/红/灰/蓝物理顺序、FPGA 反向掩码 0101。该参考工程不能直接称为已验收的统一 0°→90°→0° 中继。详情见 `资料包原始_00_请先阅读.md`。这些“资料包原始”文件保留原文件名，定位文件时按该文件的目录对照表换成当前位置。

最新性能数据统一引用仓库 `docs/verification/yolo-technical-data.md`，不要从历史 README 拼接数字。

## 重建（仅 PDS）

- 入口：`source/yolo/build_pre_pnr.tcl`。脚本用 `[info script]` 或环境变量 `TRASH_YOLO_ROOT` 定位包目录，随后 `cd` 到 `sources/`，再执行 `compile`、`synthesize -ads`、`dev_map`，最后打印 `PRE_PNR_SOURCE_FLOW_COMPLETE`。
- **综合时的工作目录必须是 `source/yolo/sources`**：设计里有两处按进程当前目录解析 `$readmemh/$readmemb`——`source/yolo/portable/009_Ram.v` 读裸文件名 `firmware_lane0..7.bin`，`trash_voice_rom_player.v` 读相对 `sources/` 往上两级的 `extensions/business/application/assets/audio_rom/*.hex`。脚本开头已经 `cd` 到 `sources`；如果改成手工逐条敲命令，必须自己先切过去。否则会出现“综合成功但 ROM 全 0”：CPU 不启动、语音静音，而且工具不报错。
- 命令示例（先切到 `sources/`，脚本在上一级）：

  ```
  cd project/trash_sorting/source/yolo/sources
  pds_shell.exe -f ../build_pre_pnr.tcl
  ```

  从 `source/yolo` 启动时写成 `pds_shell.exe -f build_pre_pnr.tcl` 也可以，脚本会自己切目录。

- 该流程只到 `dev_map`（综合 + 映射），不执行布局布线、不生成时序报告和位流。它**不能**重建与预置 v3 位流逐位一致的实现：v3 的 P&R 是从包外的映射后 ADF（`build_camera_servo_v3_seed3_20261103/mapped_input/yolo_camera_top_map.adf`，seed 3）起跑的，该 ADF 与激励不在本仓库内，见 `variants/v3_programmed_reference/direct_pnr_seed3.tcl`。

## 哪些能重建 / 哪些只能看证据

| 项目 | 现有物 | 能否重建 | 只能看证据的部分 |
| --- | --- | --- | --- |
| v3 位流（27 MHz 整机） | SHA256 `2b98f90f…`；`variants/v3_programmed_reference/` 的 049/052 顶层、`routed_timing_summary.txt`、`impl.tcl`、`direct_pnr_seed3.tcl`、`board_program_plan.json`，以及 `variants/v3_programmed_reference/最近重新烧录记录/` | 不能。包内没有 v3 的完整输入集与映射后 ADF，P&R 从包外 ADF 起跑 | 位流本身、烧录与推理记录、屏幕实际出图 |
| v4 源码（中文标签等） | `variants/v4_source_only/` 的 049/052、`build_camera_servo_v4.tcl`、构建日志 | 不完整。`pds_camera_servo_v4.log` 显示 PDS 在许可证检查阶段失败（`license ... date is already expired`），未进入综合与布局布线 | 源码改动内容；无 v4 位流、无上板记录 |
| AI 仿真 | `source/yolo/tb/`、`source/yolo/software/`、`source/extensions/business/application/tests/`、`source/extensions/business/application/tools/` | 具备重建条件，需要 ModelSim 与 RV32 工具链；本次交付未重跑 | 既有仿真结论以 `evidence/` 内日志为准，不能由源码存在推出仿真已通过 |
| STM32 工程 | `stm32_reference/` Keil 工程与两篇说明 | 可以，需要 Keil 与 STM32F103 板；本次未编译、未下载 | 实板接线与联调结论：未做 |

CPU 侧（`project/pds_native_120/`）是独立条目，位流 SHA256 `2e38db1c…`，不属于本目录。该位流上板成绩 5.346252494 CoreMark/MHz，但 Setup WNS 为 −1.426 ns，详见 `docs/original-performance-optimization-plan.md`。
