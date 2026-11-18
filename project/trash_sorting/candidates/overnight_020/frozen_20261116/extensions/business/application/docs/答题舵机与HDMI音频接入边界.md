# 答题、舵机与 HDMI 音频接入状态

## 已写入并单独验证的逻辑

- `firmware/app.c`：稳定识别到一个四分类标签后播放提问；答题按键编号映射到蓝/灰/红/绿四类；无论答对还是答错，舵机动作都选 YOLO 的正确分类，正确时加分并请求正确语音，错误时请求错误语音。
- `rtl/servo_pwm4.sv`：四路独立 50 Hz PWM；触发脉冲会被锁存到 PWM 周期边界，桶盖按参数时长打开后回到关闭位置。默认 `CLK_HZ=120461538`、`OPEN_FRAMES=250`，用于 50 Hz 下保持 5 秒。集成到当前 `sys_clk=27 MHz` 顶层时，必须实例化为 `CLK_HZ=27000000`。
- `rtl/key_debounce4.sv`、`rtl/trash_quiz_controller.sv`、`rtl/trash_peripherals.sv`：按键消抖，独立外设答题测试模式下正确答案固定为按键 1，任一按键都只打开正确蓝桶；摄像头模式下拿四类识别结果作为正确答案，答错也打开正确桶盖。舵机状态反馈闭合后再开始下一轮。
- `rtl/trash_voice_i2s.v`、`rtl/trash_voice_rom_player.v`、`rtl/trash_i2s_tx.v`：从语音 ROM 取样并串行输出 I²S；系统时钟为 27 MHz。`ms72xx_ctl` 音频初始化已在顶层启用。
- `portable/052_yolo_camera_top.v` 已接入这组模块和装饰界面；`yolo/build_pre_pnr.tcl` 已将 RTL 列入综合源。顶层参数 `PERIPHERAL_TEST_MODE=1` 默认用于先测按键、舵机和语音：固定正确答案为蓝色/按键 1，按键 1 播正确语音，按键 2..4 播错误语音，任一答案都只打开正确蓝桶；设为 `0` 后才由摄像头类别决定正确桶盖。
- 验证：`tools/test_peripheral_integration.py` 六项 RTL 仿真通过；`tools/test_answer_voice_loop.ps1` 的 27 MHz 外设闭环仿真通过，覆盖启动提示、正确/错误语音、按键舵机动作、实际舵机闭合反馈和长按防重触发。仿真缩短了开盖时间参数；板级参数仍是 5 秒。

## 当前包还没有板级闭环

当前 RTL 已接入逻辑顶层，但板级引脚约束和硬件验证还未完成。本次没有新增/猜测 FDC 引脚、没有 PnR、下载或烧写。MES2L676-BASE-V1.2 配套资料可找到点位图和原理图，但用户照片中的竖排转接板缺少可读的型号与连接器编号；底板球位不能直接当作转接板排针位置。舵机逻辑候选是标准 FMC 子卡 J3.27..30 对应 FPGA 球 U16/U15/AC26/AB26（BANK L6），但实物转接板的排针映射及 L6_VADJ 跳帽档位仍待核实，故不能作为最终接线编号。

## HDMI 音频

用户描述的音源路径按“FPGA HDMI 输出到显示器，再由显示器音频口输出”接入。顶层已有 PCM/I²S 语音 ROM 播放器、`hdmi_audio_bclk/lrclk/data` 输出，以及 `ms72xx_ctl(AUDIO_ENABLE=1)` 初始化；这与仅有裸 `i2s_tx.sv` 不同，RTL 声音数据链路已实现。板上到 MS7210 的物理连线、这些输出的 FDC 球位/电平，以及显示器音频口的实际输出仍未做板级核验，因此仿真通过不等于已听到声音。
