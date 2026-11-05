# 应用侧已上板位流（v3，27 MHz）

| 文件 | 说明 |
| --- | --- |
| `yolo_camera_top.sbit` | **v3 完整外设版位流**，SHA256 `2b98f90fbd0b4fd2de4074e74cb2c4aa8886d6009aa12bba4dfaf5d071bc4657`，3,791,112 B |
| `052_yolo_camera_top_camera_servo.v` | 这份位流对应的板级顶层（含按键、舵机、I2S 端口，`SERVO_REVERSED_MASK = 4'b0101`） |
| `049_video_ai_frontend_camera_repair.v` | 对应的视频前端 |
| `timing_summary_after_hold_fix.txt` | 最终时序：`Design Summary : All Constraints Met`，`sys_clk` WNS **+16.822 ns** |
| `multiseed_summary.csv` | 同一次实现的 P&R 汇总 |
| `direct_pnr_seed3.stdout.log` | P&R 原始日志 |
| `historical_build_camera_servo_v3.pds` | 历史 PDS 工程文件 |

## 它能证明什么

- 27 MHz 时钟，所有约束满足（不是 120 MHz 那套，两套指标不能混算）。
- 摄像头 → 卷积推理 → HDMI 显示 → 按键 → 语音 → 四路舵机 整条链路跑通。
- 18 张验证子集上的 AP@0.5 = 32.78%（`evidence/records/validation_20261104/dataset_metrics/metrics.json`），**这个数字绑的就是这份位流的 SHA**。

## 它不能证明什么

- **不能由包内源码逐位重建**。这份位流的 P&R 是从包外的 `yolo_camera_top_map.adf` 直接起跑的（`direct_pnr_seed3.stdout.log` 第一行有原路径），源码侧只有综合前的输入。想验证"源码是对的"，用 `source/yolo/build_pre_pnr.tcl` 跑到 `dev_map` 为止。
- `historical_build_camera_servo_v3.pds` 里的 `../sources/…`、`../../extensions/…` 是相对**原构建目录**的路径，搬到这个目录后 87 条引用里有 85 条找不到。**不要直接双击打开**，它只是留档。

## 怎么用它

SRAM 下载，不改板载 Flash。步骤见包根 `README.md` §3（那条是 CPU 位流，方法相同，把 `-Bitstream` 换成这里的路径即可）。

> 与 STM32 中继配套时注意：这份位流的 `SERVO_REVERSED_MASK` 是 `4'b0101`，所以 `main.c` 的 `SERVO_IN_MASK` 要写 `0x5`，不是 `0x0`。详见 `../../stm32_reference/四路舵机中继说明.md`。
