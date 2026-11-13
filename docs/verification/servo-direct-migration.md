# FPGA 直接驱动四路舵机

2026-11-11：按用户要求，将 `project/trash_sorting/stm32_reference/Core/Src/main.c` 中的渐变动作迁到 FPGA。用户确认保留答题流程；要求四路统一默认关闭、打开、停 5 秒、关闭。用户现场确认旧 mask0000 位流的四个桶均上电打开、按键关闭，因此当前四路统一校准为 mask1111（关闭 1500 us、打开 500 us），现场观察优先于旧 STM32 的颜色方向表。

## 最终行为

- 保留摄像头分类 → 提问 → 按键判对错。答对和答错只选择不同语音，均只打开**识别结果对应的正确桶**。
- 配置并释放复位后，四路持续输出 50 Hz、1500 us 高电平，即按现场观察校准的关盖位置；两处实际构建顶层均使用 `SERVO_REVERSED_MASK=1111`。
- 每 20 ms 将输出脉宽减少 20 us，50 步约 1 秒到达 500 us（校准的开盖位置）。端点处保持整整 250 帧，即 5 秒。
- 每帧增加 20 us，50 步回到 1500 us。完整动作反馈约 7 秒；回到关闭位置后输出一整帧才撤销 `open_state`，避免答题流程提前重启。
- 动作期间的重复请求不延长保持、不另排一轮。持续高电平不会反复开合；闭合后低电平 5 帧（100 ms）重新使能，重装期间收到的新答题单周期请求会锁存等待，避免漏动作。

0°关闭/90°打开表示用户要求的桶盖位置，不能把 PWM 名义轴角度直接当作机构角度。仿真证明校准后的脉宽、顺序和时长；新版实际机械开合仍由用户观察验收。

## 与 STM32 原码的对应

| 项目 | STM32 原码 | FPGA 本次实现 |
| --- | --- | --- |
| 帧周期 | `SERVO_FRAME_US=20000` | 27 MHz / 50 = 540000 个时钟 |
| 关 / 开端点 | 内部逻辑 `500 / 1500 us`，写 CCR 前按方向校准 | 四路实际输出关40500 / 开13500 个时钟，内部位置计数仍从0到50 |
| 渐变 | `SERVO_STEP_US=20` | 50 步，每步 540 个时钟 |
| 到位停留 | `SERVO_HOLD_MS=5000` | 250 帧，从到达 90°开始计时 |
| 状态 | CLOSED / OPENING / HOLDING / CLOSING | 四路分别实现相同四态 |
| 输入 | 测量 FPGA PWM、滤波后得到持续命令 | 直接接 FPGA 答题控制器的同步触发，无需中继解码 |
| 输出校准 | 旧蓝/灰/红/绿顺序为0xD，重排后1011 | 用户实测当前四路均反向，使用1111；1011候选未下载，不作为当前硬件依据 |

原 C 代码在保持计数达到 5 秒后，下一帧才执行首次关盖步进，端点脉宽会多保持一帧。本次以实际 PWM 端点连续 250 帧为准，消除这 20 ms 差异；开关步长及约 1 秒的速度保持一致。

## 活动源码与接线

活动入口为 `project/trash_sorting/source/yolo/portable/052_yolo_camera_top.v`，外设代码在 `source/extensions/business/application/rtl/servo_pwm4.sv`、`trash_peripherals.sv`。旧 `variants/v3_programmed_reference/`、`prebuilt/` 和 STM32 快照保留历史内容；它们不包含此次更新。

移除 STM32 信号中继后，舵机信号线按**当前 FPGA 顶层**接入下表，原舵机独立电源与 FPGA 共地。STM32 旧注释的 PA0..3 顺序是蓝/灰/红/绿，不能把这四根信号线按索引直接照搬。

| 桶 / 按键及分类码 | FPGA 输出 | 既有约束球位 | 标准子卡历史标记 |
| --- | --- | --- | --- |
| 绿 / 1 | servo_pwm[0] | U16 | J3.27 |
| 红 / 2 | servo_pwm[1] | U15 | J3.28 |
| 灰 / 3 | servo_pwm[2] | AC26 | J3.29 |
| 蓝 / 4 | servo_pwm[3] | AB26 | J3.30 |

J3 标记对应标准子卡；无编号转接板仍应按实际连通关系确认。信号仅连接舵机控制端，电源继续使用原舵机供电。

## 验证与复现

RTL 回归：

```powershell
python project/trash_sorting/source/extensions/business/application/tools/test_servo_repair_top.py --modelsim D:/FPGA_Project/Modelism/win64
& project/trash_sorting/source/extensions/business/application/tools/test_answer_voice_loop.ps1
```

回归覆盖逐帧 PWM、全部 16 种通道组合、50 步开关、250 帧端点保持、复位、长高/忙时请求、关闭后快速新请求、通道独立动作，以及四类×四按键 16 种答题组合。语音闭环使用实际 27 MHz、真实 ROM 和 I2S 解码；仅将该测试的移动缩为 1 帧、保持缩为 1 帧，完整速度与 5 秒由单独 PWM 回归验证。

独立舵机模块 PDS 综合/映射为 **301 LUT、108 FF、0 LUTRAM**，面积门禁通过（规划上限 512 LUT + 256 FF）；这是独立模块数据，不能当作整机面积或相对旧模块的面积降幅。

早期控制时序测试在 `evidence/records/servo-direct-20261111-tests/`，不能证明旧mask0000的实际开关方向。当前1111四路校准的实现、逐路仿真及完整应用16种答题组合回归在 `evidence/records/optimization/servo-keys-20261111-003/`。独立模块历史综合证据在 `evidence/records/optimization/servo-direct-20261111-unit-map/`，完整工程历史编译记录在 `evidence/records/optimization/servo-direct-20261111-full-compile/`。

完整摄像头应用已在 `trash_full_restored_20261111_011` 完成布线及最终多角STA，并生成新版位流（SHA256 `dbe3c1e879c2ccf08a8d8d4dd5c295226302186212ad2da0296be67d127091cb`）。冻结源码及综合映射来自004，放置来自010，011复用相同放置并将布线代价恢复300后收敛；未改模型或AI逻辑。八路程序镜像、57个语音ROM分块及三个UI资源实际加载均通过检查。最终慢角Setup最差0.360 ns、快角Hold最差0.053 ns，所有10项多角摘要无失败端点。映射面积29229 LUT / 21935 FF / 290 LUTRAM；最终布线资源28765 LUT / 21935 FF / 290 LUTRAM，二者不能混为同阶段。

新版已通过JTAG下载，即时及5秒后配置均081ffca0，正常断开；COM34新固件应答、模型CRC `0x3a4a5d5d`、摄像头单次及自动模式首帧推理均成功，当前已启动自动识别。下载证据在 `evidence/records/trash-full-20261111-program-001/`，同轮实现证据在 `evidence/records/optimization/trash_full_restored_20261111_011/`。用户随后针对画面、语音和完整答题开关盖验收问题回复“可以的，就这样先”，本次完整版现场验收通过，保留当前版本、暂不扩类；串口返回glass仅证明成功推理，未用标注图验证识别准确性。本次只写SRAM；掉电后需重新下载位流和模型。

用户随后要求只测试按键对应桶：新增 `project/trash_sorting/diagnostics/servo_keys/` 独立纯 RTL 诊断，复用此次舵机逻辑，按键 1/2/3/4 直接映射绿/红/灰/蓝；已生成位流并通过 27 MHz 最终多角 STA。交付、接线与下载记录见该目录 README，不等于完整视觉应用已重新上板。

本次现场收尾：无动作时读到00180c80（DONE=0、gouten=0），回读与003位流不一致；配置失效触发原因未确定。重新下载003同一SHA256后，立即及5秒后状态均为081ffca0，正常断开JTAG；用户已逐项确认“已能正常打开并自动关闭”和“四路都正常”。最终成功证据在 `evidence/records/servo-keys-20261111-program-006/`，当前位流SHA256为 `a298cd4bb56beefde92648f0146f38c4483ae2e55681f2dcd90a07919b7a45ee`。该现场验收只覆盖按键独立版本的四路开/停/关，未实测掉电冷启动，也未验收新的摄像头整机位流。下载脚本新增即时/延时配置状态检查及正常断开，5项Tcl行为测试通过；003综合后网表另以厂商单元模型确认启动PWM及KEY1初始渐变，详细范围见同轮 `gate_sim/result.json`。
