# 独立语音 ROM / I²S 接口（尚未板上验收）

## 实现

`trash_voice_i2s.v` 接收一周期语音请求；模块默认 `CLK_HZ=50000000`，当前实际 `yolo/portable/052_yolo_camera_top.v` 明确使用 27 MHz：

| 信号 | 方向 | 约定 |
| --- | --- | --- |
| `clk` | 输入 | 默认 50 MHz，使用 `CLK_HZ` 参数匹配实际时钟 |
| `rst` | 输入 | 同步高有效复位 |
| `request_valid` | 输入 | 高一个 clk 周期，1/2/3 有效，其他 ID 忽略 |
| `request_asset_id[2:0]` | 输入 | 1=提示，2=回答正确，3=回答错误 |
| `audio_busy` | 输出 | ROM 正在供数或最后一帧仍在发送 |
| `playback_done` | 输出 | 最后一帧发送完毕时高一个 clk 周期 |
| `i2s_bclk` | 输出 | 平均 3.072 MHz 串行位时钟 |
| `i2s_lrclk` | 输出 | 48 kHz，低=左声道，高=右声道 |
| `i2s_data` | 输出 | 标准 I²S 延迟一位，16 位有符号，32 位声道槽，双声道复制 |

`trash_audio_select` 的 `voice_valid/voice_asset_id` 可直接接请求端；暂设答案为第 1 键可回收类。新的有效请求在下一可用帧切换到新语音，不排队；已经送出的旧帧会正常结束。

ROM 从已有 `PROMPT.WAV`、`CORRECT.WAV`、`WRONG.WAV` 生成，未合成虚假的音效。为减小 FPGA 存储，先低通再降采样到 16 kHz PCM8；发送时重复三次形成 48 kHz PCM16。三段共 115576 字节（924608 位），不含第四段超时音和背景音乐。音质是语音验证级，不能称为原 WAV 无损播放。ROM 使用同步读；当前改为 2048×8 的独立存储银行，共 57 个，银行输出由普通逻辑选择，避免深 ROM 自动级联后被去重导致的专用级联引脚冲突。独立 PDS 真实数据 probe 已完成综合及 `dev_map`，57 个银行成功加载，报告 Total DRM 为 15.0，未出现原 CINA/COUTA 级联 DRC；全工程资源和布线结果仍以全量构建日志为准。

生成：`py -3 extensions/business/application/tools/make_voice_rom.py`。同时生成完整 ROM 和 `voice_pcm8.hex.bank00.hex` 至 `.bank56.hex`；每个银行恰好 2048 字节，最后一个补零。只重新拆分已有 ROM 可运行 `py -3 extensions/business/application/tools/make_voice_banks.py`，测试夹具也可作为该脚本的路径参数。部署时必须保留全部银行文件，不能只复制完整 ROM。

每个银行直接 `$readmemh` 读取对应文件。当前 ADS 将文件名字符串拼接解析为空，且中间数组复制会丢失初始化数据，因此 `SYNTHESIS` 分支用静态 generate-case 中的完整字面量相对路径。综合必须从工程的 `yolo/sources/` 工作目录执行；若调整工程目录层级，须同步修改这组字面量路径。仿真分支允许 `ROM_FILE` 指定基本路径并附加 `.bankNN.hex`，以支持不同工作目录和小型夹具。两分支使用同一组银行数据，不依赖运行时 SD 卡或 C 编译器。

独立数据检查确认：57 个银行前 115576 字节与原 ROM 完全一致，补齐部分全零；原 PCM 中 47249 字节非零，PCM 字节 SHA256 为 `e14abcbef0caf43a8bde1ba962340648bf8d6956e18844410eac3395e3e9b4ed`。

## HDMI 实体连线和未完成边界

本地《教程1_硬件实验指导手册_盘古676系列100Pro+开发板》100HP 对应 HDMI 表格，文本摘录在 `docs/pin_evidence/教程1_硬件实验指导手册_盘古676系列100Pro+开发板.pdf.txt`：

| 信号 | PG2L100H-676 球位 | 建议对应播放器输出 |
| --- | --- | --- |
| HD_TX_SC_MC | T23 | `i2s_bclk` |
| HD_TX_I2S1 | R26 | 未用第二路数据，保持 0 |
| HD_TX_I2S0 | P26 | `i2s_data` |
| HD_TX_WS | B25 | `i2s_lrclk` |

这些是 FPGA 球位而非用户外接排针号。活动 `yolo/sources/camera.fdc` 已加入四路音频约束；最新全工程构建、烧录及用户授权状态见工程根 `docs/外围测试闭环完成记录.md`。

MS7210 本地数据手册第 2、10 页确认芯片支持 IIS 音频输入，SCLK_MCLK、WS、I2SDATA0 分别为芯片 7、6、5 脚。现已从固定提交的原作者驱动 C/header 独立核对寄存器，并新增 `ms7210_audio_init.v`：视频初始化完成后配置 PCM/I²S、48 kHz 采样率族、16 位双声道、Audio InfoFrame 和解除音频静音。`060_ms72xx_ctl.v` 已串接两段初始化，实际 portable 顶层已连接音频请求和输出；具体来源与测试见《MS7210音频初始化与来源.md》。这些代码与 RTL 波形通过仍不等于显示器已实际出声；引脚约束现已启用，实际声音等待统一实现后的板测。

当前顶层使用 27 MHz 相位累加器产生平均准确的 BCLK，每个边沿存在最多一个系统时钟周期（约 37.04 ns）的量化。该抖动与 MS7210 接收容差尚未板测；若芯片需要低抖动音频参考时钟，应改用经确认的精确音频 PLL。未擅自修改现有共享 PLL。

## 仿真证据

运行 `powershell -ExecutionPolicy Bypass -File extensions/business/application/tools/test_voice_i2s.ps1`：

1. `trash_voice_i2s_tb`：真实 50 MHz 下检查平均 BCLK 频率、I²S 位延迟、符号位、左右声道、零填充、三倍样本重复、结束信号和无效请求。
2. `trash_voice_rom_full_tb`：检查三个真实语音 ROM 的每个样本、完整长度和最后一帧标记，包含跨银行边界。

另运行 `powershell -NoProfile -ExecutionPolicy Bypass -File extensions/business/application/tools/test_answer_voice_loop.ps1`，验证真实 27 MHz、完整真实 ROM 与 I²S 串行解码的答题闭环：启动提示、按键 1 正确并开蓝桶、按键 2 错误并开蓝桶、关盖后重播提示、初始化就绪门控和长按保护。该项仿真仅将开盖时间缩为 20 ms 加速，正式模块默认仍为 5 秒。

另运行 `tools/test_voice_synthesis_rom.ps1`，显式定义 `SYNTHESIS`，从 `yolo/sources/` 执行；已将完整字面量路径分支的三个语音每个 PCM 样本及结束标记与原完整 ROM 比对通过。该脚本复用全量 PCM 测试，不是只检查文件存在。

日志写入 `extensions/business/application/evidence/trash_voice_*_tb.log`，其中 `trash_voice_synthesis_rom_tb.log` 是字面量分支证据。以上 ModelSim 脚本没有进行布局布线或烧写；PDS 映射 probe 入口是 `yolo/build_voice_probe_20261103/voice_map_probe.tcl`。
