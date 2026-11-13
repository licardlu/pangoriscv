# 青禾视觉垃圾分类应用源码

> **2026-11-13当前状态更新：板上已安装092手部过滤实验版，实际下载证据093。** 配套五类模型CRC/手类数值/自动识别通过，手部和电池准确性仍待现场验证。当前入口见[仓库交接说明](../../docs/HANDOFF.md)；以下原文保留历史阶段说明，其中“当前062、手模型未下载”等描述已被本次092替代。


该目录补充本仓库此前缺少的完整外围应用资料，来源于本聊天整理的技术代码快照。实际代码位于 `source/yolo` 和 `source/extensions/business/application`，包含摄像头、HDMI、CPU/AI、界面、按键答题、四路 PWM 及语音 ROM。

**2026-11-13最新实板交付**：[full_54mhz_20261113](bitstream/full_54mhz_20261113/README.md)已实际下载062局部O2固件，原四桶模型，状态栏/四桶色/整轮单目标锁/舵机校准保留。最终预热后100帧相机诊断平均1.705371秒、最慢1.719秒，当前空输出场景，非完整游戏耗时或所有实物保证。手部训练候选未通过，留出手持小电池仍漏检，不能声称手部问题解决。[本轮身份、速度和效果限制](../../docs/verification/trash-night-final-20261113.md)优先于下列历史版本说明。源码默认重建仍27MHz，最终54MHz恢复须显式指定上述release-dir。

**当前四桶模型已上板**：checkpoint `8014832f…`、模型blob `ea70896c…`，直接输出绿厨余、蓝回收、红有害、灰其他。54 MHz配套实现通过最终STA、板端CRC、四桶固定输入数值核对和10帧测速，空场平均1.790597秒；自动识别已恢复。可恢复包在`diagnostics/four_bins_54mhz/`；27 MHz回退包在`diagnostics/four_bins_27mhz/`。实物垃圾识别和新版本开桶仍需现场确认。[部署与限制](../../docs/verification/trash-four-bin-deployment-20261112.md)。

**四桶颜色/独立状态栏已验收显示**：保留48行动态状态及按键图例，摄像头完整720行视野缩采样到下方672行，框同步对齐，关闭物品名称。用户随后授权布线和下载，已回复“正常，文字不挡画面”。四桶新模型配套顶层模式为1；保留旧六类模式0用于历史恢复。[界面验证记录](../../docs/verification/trash-display-four-bins.md)。

## FPGA 直接控制舵机（2026-11-11 更新）

**历史完整版现场验收**：[full_27mhz](bitstream/full_27mhz/README.md)中的历史六类发布保持，SHA256 `3283acac…`曾通过完整物理业务确认。它与当前四桶候选是不同身份，不能误用旧模型恢复新四桶位流。

**四桶重训已部署**：重新下载并审计10383张带框图片，准备1795图训练、1508图验证、1572图测试，完成24轮YOLOv5n训练。模型直接检测厨余/可回收/有害/其他，纸板纸张同归可回收；固定320浮点测试mAP50为77.0%，旧模型按桶合并21.1%。这些是公共浮点指标，不能作为FPGA实物准确率。已完成量化及上板，手部负样本微调另做比较，尚未替换当前权重。[训练来源与限制](../../docs/verification/trash-retraining-20261111.md)、[手部实验](../../docs/verification/trash-hand-negative-optimization-20261112.md)。

顺序预处理后平均3.726462秒/帧；相对旧已验收交付3.797656秒，耗时降低1.87%；同位流切换旧/新预处理，耗时降低2.94%。当前冻结构建`trash_speed_stream_20261111_001`，最终布线28822 LUT、21935 FF、290 LUTRAM、138.5 DRM、124 APM。旧交付`dbe3c1e8…`仅作历史基线。源码、固件及ROM已同步；数据来源和采集建议见[训练方案](../../docs/verification/trash-training-plan.md)，详细测速见[速度优化记录](../../docs/verification/trash-speed-optimization.md)。

本次用户仅测试按键对应桶：已增加 [四按键独立测试版本](diagnostics/servo_keys/README.md)，无需摄像头/模型/HDMI/STM32，按键 1/2/3/4 直接对应绿/红/灰/蓝。它是独立诊断位流；下述完整应用继续保留识别与答题流程。

当前可编辑源码已将 STM32 的渐变动作迁入 FPGA：按现场四路实测统一校准上电关闭（1500 us），答题后无论对错都打开识别结果对应桶，以每 20 ms 改变 20 us 的速度约 1 秒开到位（500 us），保持 5 秒，再约 1 秒关回。0°关闭/90°打开是桶盖目标位置，不等于 PWM 的名义轴角度。活动构建顶层 `source/yolo/portable/052_yolo_camera_top.v` 与独立测试顶层的方向掩码均为 1111，旧0000版的实际开关方向错误。`open_state` 覆盖完整开、停、关过程。

接线、STM32 迁移差异、验证结果和构建状态统一见 [迁移与验证记录](../../docs/verification/servo-direct-migration.md)。以下 v3 / v4 / STM32 快照说明用于追溯原交付；预置 v3 位流不包含此次改动，不能用旧位流验收新动作。

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
| `bitstream/full_27mhz/` | 当前恢复的完整应用位流、实现身份与下载说明 |
| `variants/v3_programmed_reference/` | 历史下载的 v3 局部顶层/前端、时序摘要及下载记录；不是全部输入冻结包 |
| `variants/v4_source_only/` | 后续中文标签、叠加顺序、舵机方向等修改；没有可下载 v4 位流 |
| `stm32_reference/` | 原有 Keil 工程快照，PB12~15 输入，PA0~3 输出；未与 v3 完成配套联调 |

此处的 v3 是 27 MHz 系统，不等于 `project/yolo120` 的 120.461538 MHz 速度实验。`source/yolo/build_pre_pnr.tcl` 和 `source/yolo/portable/` 源于历史构建入口，目前包含上面的舵机更新，不能当作 v3 位流的完整冻结来源。

STM32 当前代码仍有旧颜色顺序与方向掩码：输入 0x0、输出 0xD（`SERVO_REV_BLUE/RED/GREEN = 1`，`SERVO_REV_GRAY = 0`）；v3 为绿/红/灰/蓝物理顺序、FPGA 反向掩码 0101。该参考工程不能直接称为已验收的统一 0°→90°→0° 中继。详情见 `资料包原始_00_请先阅读.md`。这些“资料包原始”文件保留原文件名，定位文件时按该文件的目录对照表换成当前位置。

最新性能数据统一引用仓库 `docs/verification/yolo-technical-data.md`，不要从历史 README 拼接数字。

## 重建（仅 PDS）

完整流程入口为 `tools/build_full.py --name <新构建目录名> --pds <PDS bin目录>`：冻结输入，验证程序/语音/UI加载，综合映射，执行P&R和最终多角STA，通过后才生成并发布位流。默认使用本次收敛的宏块距离优先、扩散系数4及布线代价300策略。构建目录不能复用；当前交付的实际冻结来源、放置复用和布线参数见发布manifest及证据目录。重新下载并加载配套模型使用 `tools/restore_full_board.py --port COM34 --pds <PDS bin目录> --out <新的证据目录>`；它使用SRAM，不写Flash。

- 入口：`source/yolo/build_pre_pnr.tcl`。脚本用 `[info script]` 或环境变量 `TRASH_YOLO_ROOT` 定位包目录，核对启动目录为 `sources/` 后执行 `compile`、`synthesize -ads`、`dev_map`，最后打印 `PRE_PNR_SOURCE_FLOW_COMPLETE`。
- **启动 pds_shell 之前的进程工作目录必须是 `source/yolo/sources`**：设计里有两处按项目/子进程当前目录解析 `$readmemh/$readmemb`——`source/yolo/portable/009_Ram.v` 读裸文件名 `firmware_lane0..7.bin`，`trash_voice_rom_player.v` 读相对 `sources/` 往上两级的 `extensions/business/application/assets/audio_rom/*.hex`。仅在 Tcl 内 `cd` 不能保证综合子进程跟随；现在脚本会拒绝错误启动目录。构建日志必须确认镜像实际加载，任何 `Cannot open specified data file` 均判失败。
- 命令示例（先切到 `sources/`，脚本在上一级）：

  ```
  cd project/trash_sorting/source/yolo/sources
  pds_shell.exe -f ../build_pre_pnr.tcl
  ```

  不要从 `source/yolo` 或仓库根目录启动后依赖 Tcl 内 `cd`；建议按同样目录布局先冻结到仓库 `build/` 的新目录再运行，以隔离构建产物。

- 该流程只到 `dev_map`（综合 + 映射），不执行布局布线、不生成时序报告和位流。它**不能**重建与预置 v3 位流逐位一致的实现：v3 的 P&R 是从包外的映射后 ADF（`build_camera_servo_v3_seed3_20261103/mapped_input/yolo_camera_top_map.adf`，seed 3）起跑的，该 ADF 与激励不在本仓库内，见 `variants/v3_programmed_reference/direct_pnr_seed3.tcl`。

## 哪些能重建 / 哪些只能看证据

| 项目 | 现有物 | 能否重建 | 只能看证据的部分 |
| --- | --- | --- | --- |
| v3 位流（27 MHz 整机） | SHA256 `2b98f90f…`；`variants/v3_programmed_reference/` 的 049/052 顶层、`routed_timing_summary.txt`、`impl.tcl`、`direct_pnr_seed3.tcl`、`board_program_plan.json`，以及 `variants/v3_programmed_reference/最近重新烧录记录/` | 不能。包内没有 v3 的完整输入集与映射后 ADF，P&R 从包外 ADF 起跑 | 位流本身、烧录与推理记录、屏幕实际出图 |
| v4 源码（中文标签等） | `variants/v4_source_only/` 的 049/052、`build_camera_servo_v4.tcl`、构建日志 | 不完整。`pds_camera_servo_v4.log` 显示 PDS 在许可证检查阶段失败（`license ... date is already expired`），未进入综合与布局布线 | 源码改动内容；无 v4 位流、无上板记录 |
| AI 仿真 | `source/yolo/tb/`、`source/yolo/software/`、`source/extensions/business/application/tests/`、`source/extensions/business/application/tools/` | 具备重建条件，需要 ModelSim 与 RV32 工具链；本次交付未重跑 | 既有仿真结论以 `evidence/` 内日志为准，不能由源码存在推出仿真已通过 |
| STM32 工程 | `stm32_reference/` Keil 工程与两篇说明 | 可以，需要 Keil 与 STM32F103 板；本次未编译、未下载 | 实板接线与联调结论：未做 |

CPU 侧（`project/pds_native_120/`）是独立条目，位流 SHA256 `2e38db1c…`，不属于本目录。该位流上板成绩 5.346252494 CoreMark/MHz，但 Setup WNS 为 −1.426 ns，详见 `docs/original-performance-optimization-plan.md`。
