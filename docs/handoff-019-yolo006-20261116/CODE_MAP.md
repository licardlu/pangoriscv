# 代码结构与修改入口

以下路径均相对`project/trash_sorting/releases/standalone_019/source/`，对应本次019冻结源码。

| 层次 | 入口 | 负责什么 |
|---|---|---|
| FPGA顶层 | yolo/portable/052_yolo_camera_top.v | 摄像头、DDR、CPU/AI、识别画框、按键、舵机、媒体和HDMI总装配；当前CMOS_2、AI_FAST_CLOCK=2 |
| FPGA工程 | yolo/sources/ | PDS工程、引脚/时序约束、CPU及接口RTL、ROM初始化内容 |
| CPU启动/循环 | yolo/software/platform_start.S、platform_main.c | 栈与固件启动、MMIO、模型启动、相机推理和显示提交、UART维护 |
| 模型启动安全门 | yolo/software/model_boot.c | 先检查卡中文件再检查DDR；失败时不启用自动识别 |
| 图执行 | yolo/software/yolo_forward.c、yolo_runtime.c | 85算子编排、加速器接口与CPU线性算子/检测头 |
| 解码与主体选择 | yolo/software/yolo_decode.c、yolo_contact_policy.h、yolo_target_policy.h | 检测解码、NMS、手与物体关联、单主体选择 |
| 权重与内存布局 | yolo/model/ | MODEL.BIN对应的量化参数、张量地址、输出结构、固件模型头文件 |
| 媒体固件 | yolo/software/media_sdmmc.c、media_fat32.c、media_pmj.c、media_player.c、media_board.c | TF块读、FAT链、媒体解析、音视频调度和页面控制 |
| 媒体硬件 | extensions/media/ | JPEG、DDR仲裁/写入/扫描、媒体路由、音频FIFO和音频接口 |
| 答题及外设 | extensions/business/application/ | 语音、答题、舵机、界面资源及对应RTL/辅助代码 |
| 参考成绩页 | yolo/software/benchmark_reference.c、benchmark_ui.c | 展示已记录的历史CPU参考结果，当前编译模式不现场跑CoreMark |

## 识别数据流

摄像头采集 → 缩放/输入缓冲 → YOLO图推理 → 五类检测解码 → hand关联/最大主体规则 → 一个垃圾框 → 答题/语音/开对应桶。

hand只服务主体过滤，最终输出仍为四桶。手框过大或未检出会改变主体选择；改善空手误识别需要同时检查模型、解码阈值和主体规则。

## 上电数据流

Flash配置FPGA/固件ROM → 初始化外设 → TF根目录读取MODEL.BIN → 校验文件长度和CRC → 写DDR并独立校验 → 开自动识别。

只复制新模型会被固定CRC拒绝。更换权重必须连同deployment_model.h、模型内存图、固件及最终位流成套处理。

## 常见修改应该去哪里

- 提高电池/手的检出能力：训练数据与YOLO微调；先看验证图和分类别TP/FP/GT。
- 检测框正确但总选到背景：检查contact策略；用保存预测回放同一份C源码再改。
- 上电无框：先查模型启动诊断BOT1与autonomous，再查相机/DDR/推理；不能直接假定画框模块错误。
- 宣传片音画不同步：看媒体PTS、采样计数、FIFO欠载/循环和DDR争用；不要把视频封装25fps当板上实际fps。
- 改界面/舵机/按键：相应业务RTL和顶层约束；要验证映射、极性和实际机械动作。
- 改时钟/算子：固件编译CPU_HZ、顶层AI时钟和PLL一致；重新跑完整时序，不复用旧成绩。

构建/烧录/核验脚本位于代码包的`project/trash_sorting/tools/`及`extensions/yolo/scripts/`；训练/评估脚本位于`project/trash_sorting/training/`。具体可复制命令见`docs/HANDOFF.md`。
