# 代码阅读导引

外围完整应用位于 `project/trash_sorting/source`，120 MHz 优化位于 `project/yolo120`。二者是不同版本，不能混用验收数字。

| 技术文档章节 | 主要代码 |
| --- | --- |
| CPU 内核与总线 | `project/cpu120/rtl`；`project/trash_sorting/source/yolo/sources/015_pango_replica_core.v`、`040_vexii_ai_soc.v` |
| 卷积加速器与 MAC | 同 sources 目录的 `042_conv_band_rt.v`、`043_mac_array.v`、`044_conv_engine_axil.v` |
| DDR 与 CDC | 同 sources 目录的 `045_ddr_axi_bridge.v`、`046_bridge_to_cdc.v`、`047_axi_cdc.v` |
| 摄像头采集 | 同 sources 目录的 `048_camera_snapshot.v`、编号 054~070 的视频/缓存/配置模块 |
| 推理与解码 | `project/trash_sorting/source/yolo/software/platform_main.c`、`yolo_runtime.c`、`yolo_decode.c` |
| 系统连接与识别框 | `project/trash_sorting/variants/v3_programmed_reference/052_yolo_camera_top_camera_servo.v`、`049_video_ai_frontend_camera_repair.v` |
| 后续中文标签与图层 | `project/trash_sorting/variants/v4_source_only/` 下的 049/052 文件 |
| 分类映射 | `project/trash_sorting/source/extensions/business/application/rtl/yolo_class_to_bin.v` |
| 按键和答题 | 同 rtl 目录的 `key_debounce4.sv`、`trash_quiz_controller.sv`、`trash_peripherals.sv` |
| 舵机 PWM | 同 rtl 目录的 `servo_pwm4.sv`；反向掩码由顶层实例决定 |
| 音频 ROM / I2S / HDMI | 同 rtl 目录的 `trash_voice_rom_player.v`、`trash_i2s_tx.v`、`ms7210_audio_init.v` |
| 外围测试 | `project/trash_sorting/source/extensions/business/application/tests/` |
| STM32 中继参考 | `project/trash_sorting/stm32_reference/Core/Src/main.c`、`project/trash_sorting/stm32_reference/MDK-ARM/test.uvprojx` |
| 120 MHz 顺序读取 | `project/yolo120/rtl/video_ai_frontend.v`、`project/yolo120/sw/platform_main.c` |
| 测速方法与原始记录 | `project/yolo120/tools/benchmark.py`；`evidence/records/optimization/yolo120/experiment-yolo120-006/` |
| 模型量化与打包 | `extensions/yolo/scripts/quant_yolov5n.py`、`pack_deployment.py`、`pack_model.py` |
| 标注数据评测方法 | `extensions/yolo/scripts/eval_yolov5n_labeled.py`；当前未收录可核验结果 |

原始导入和第三方来源以 `provenance`、`source_manifest.json`、`release_manifest.json` 为准。部分历史脚本含旧电脑绝对路径，需要按工具环境配置。
