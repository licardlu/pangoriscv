from pathlib import Path
import datetime
import hashlib
import json
import re
import shutil
import zipfile

ROOT = Path(r'D:\FPGA_Project\zi_guang_tong_chuang')
SRC = Path(r'D:\FPGA_Project\trash_white_split_voice_source_v1')
CANON = ROOT / 'pangoriscv/extensions/yolo'
STM = Path(r'D:\FPGA_Project\舵机测试\test')
NAME = '青禾垃圾分类_技术文档关键代码_20261103'
OUT = ROOT / NAME
ZIP = ROOT / (NAME + '.zip')
if OUT.exists() or ZIP.exists():
    raise RuntimeError('Refusing to overwrite an existing package')
OUT.mkdir()
records = []

def copy(src, dest):
    src = Path(src)
    if not src.is_file():
        raise FileNotFoundError(src)
    data = src.read_bytes()
    target = OUT / dest
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    records.append(dict(path=target.relative_to(OUT).as_posix(), original=str(src),
                        bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))

def tree(src, dest, extensions=None):
    src = Path(src)
    for p in sorted(src.rglob('*')):
        rel = p.relative_to(src)
        if not p.is_file() or any(x.lower() in {'build', 'work', 'objects', 'listings', '.git', '__pycache__', 'rte'} for x in rel.parts):
            continue
        if extensions is None or p.suffix.lower() in extensions:
            copy(p, Path(dest) / rel)

def write(name, data):
    target = OUT / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(data, encoding='utf-8-sig')

text_ext = {'.v', '.sv', '.vh', '.svh', '.c', '.h', '.s', '.ld', '.tcl', '.fdc', '.sdc', '.idf', '.vp', '.py', '.ps1', '.md', '.txt', '.json', '.hex', '.bin'}
for folder in ['sources', 'portable', 'software', 'model', 'ipcore', 'tb']:
    tree(SRC/'yolo'/folder, Path('01_FPGA当前源码/yolo')/folder, text_ext)
for filename in ['build_pre_pnr.tcl', 'source_manifest.json', 'checksums.json', 'README.pre_pnr.md']:
    copy(SRC/'yolo'/filename, Path('01_FPGA当前源码/yolo')/filename)
for folder in ['rtl', 'tools', 'tests', 'assets', 'firmware', 'docs']:
    tree(SRC/'extensions/business/application'/folder,
         Path('01_FPGA当前源码/extensions/business/application')/folder,
         text_ext | {'.wav', '.png'})
tree(SRC/'extensions/business/rtl', '01_FPGA当前源码/extensions/business/rtl', text_ext)
tree(SRC/'extensions/business', '07_历史参考/业务层补充源码', {'.c', '.h'})
tree(SRC/'docs', '07_历史参考/工程修复记录', {'.md', '.json'})

v3 = SRC/'yolo/build_camera_servo_v3_seed3_20261103'
v4 = SRC/'yolo/build_camera_servo_v4_full_20261103'
for p in sorted(v4.iterdir()):
    if p.is_file() and p.suffix in {'.v', '.tcl', '.json', '.log'}:
        copy(p, Path('02_v4后续修改_未生成可烧录位流')/p.name)
for filename in ['049_video_ai_frontend_camera_repair.v', '052_yolo_camera_top_camera_servo.v', 'direct_mapped_input_manifest.json', 'board_program_plan.json', 'impl.tcl', 'direct_pnr_seed3.tcl']:
    copy(v3/filename, Path('03_v3已烧录版本_局部源码与证据')/filename)
copy(v3/'place_route/yolo_camera_top_timing_summary_after_hold_fix.txt',
     '03_v3已烧录版本_局部源码与证据/routed_timing_summary.txt')
latest = v3/'board_reprogram_requested_20261103_retry1'
for filename in ['trace.txt', 'result.json', 'model_camera.log', 'model_camera_result.json']:
    copy(latest/filename, Path('03_v3已烧录版本_局部源码与证据/最近重新烧录记录')/filename)

scripts = ['board_loader.py', 'program_board.py', 'board_inference.py', 'board_perf.py',
           'pack_model.py', 'pack_deployment.py', 'quant_yolov5n.py', 'export_graph.py',
           'export_layer_table.py', 'deployment_bundle.py', 'tile_plan.py',
           'build_firmware.py', 'build_vexii_camera.py', 'generate_vexii_soc.py',
           'loader_requirements.txt']
for filename in scripts:
    copy(CANON/'scripts'/filename, Path('04_AI模型处理与板端通信/scripts')/filename)
tree(CANON/'sw', '04_AI模型处理与板端通信/sw', text_ext)
tree(CANON/'rtl', '04_AI模型处理与板端通信/rtl_参考实现', {'.v', '.sv', '.vh'})
copy(CANON/'README.md', '04_AI模型处理与板端通信/历史README.md')
tree(STM/'Core', '05_STM32舵机中继_当前工程快照/Core', {'.c', '.h'})
tree(STM/'Drivers', '05_STM32舵机中继_当前工程快照/Drivers', {'.c', '.h', '.s', '.txt'})
tree(STM/'MDK-ARM', '05_STM32舵机中继_当前工程快照/MDK-ARM', {'.uvprojx', '.s', '.sct'})
for filename in ['test.ioc', '四路舵机中继说明.md', '舵机四路测试说明.md']:
    copy(STM/filename, Path('05_STM32舵机中继_当前工程快照')/filename)
existing_doc = ROOT/'青禾智能视觉垃圾分类系统技术文档.docx'
if existing_doc.exists():
    copy(existing_doc, '07_历史参考/原有技术文档草稿.docx')

write('00_请先阅读.md', '''# 青禾智能视觉垃圾分类：技术文档代码资料包

本包用于阅读关键代码、整理技术文档。包含完整的核心 RTL、板端 AI C 固件、模型描述及权重、外围 RTL、音频素材、测试代码、STM32 工程，以及两份按功能查找的说明。没有包含 PDS 安装程序、许可证、全量布局布线数据库、训练数据集和已生成位流。

建议先读 `代码索引.md`，再读 `技术文档编写要点.md`；需要直接引用代码时看 `关键代码摘录.md`。所有文件的来源和 SHA-256 见 `文件来源清单.json`。

## 版本必须这样区分

| 目录 | 用途与状态 |
| --- | --- |
| 01_FPGA当前源码 | 打包时磁盘源码快照，保持 yolo / extensions 的相对目录结构；不是对当前板上全部源码的冻结复现 |
| 02_v4后续修改_未生成可烧录位流 | 中文大字号标签、显示叠加层级及舵机统一方向等后续修改；没有可烧录 v4 位流，不得写为已上板验证 |
| 03_v3已烧录版本_局部源码与证据 | 最近真正烧录的 v3 顶层、视频前端、路由后时序报告和本次下载/推理记录；其余依赖当时未全量冻结，本目录不是完整重建包 |
| 04_AI模型处理与板端通信 | 模型导出量化、打包、UART 协议与固件相关参考源码；实际 FPGA 编译输入优先看 01 的编号 RTL |
| 05_STM32舵机中继_当前工程快照 | 已有 Keil 工程的原样拷贝；本次只整理，未重新编译、未下载 STM32、未确认实板接线 |
| 07_历史参考 | 历史修复记录、原有文档草稿。部分是旧版描述，引用时应以本包版本说明和实际代码为准 |

最近 FPGA 下载证据：`program: 1`、`JTAG_SCRIPT_DONE`；模型上传后板端 CRC 通过，两次摄像头推理响应均为空检测，随后已启动自主识别。这证明下载和推理通信流程完成，不证明识别准确率或舵机全部验收通过。SRAM 下载掉电失效，不等于开机自启动。

## STM32 文档的冲突点，写技术文档时务必注意

STM32 当前文件仍标注蓝/灰/红/绿顺序，`SERVO_IN_MASK=0x0`、`SERVO_OUT_MASK=0x5`。而刚烧录的 v3 顶层明确为绿/红/灰/蓝物理顺序，`SERVO_REVERSED_MASK=4'b0101`。两者不能直接作为同一套已集成接线说明使用。这里保留原文件供解释中继原理，未擅自修改工程，也没有把它标为已经配套验收。

用户要求的后续目标是 STM32 各输出上电 0°，收到开盖命令后到 90°，保持 5 秒再到 0°，周期 20 ms。当前 STM32 源码还包含约 1 秒渐变以及输出反向掩码，不能将“目标”写成“当前四路已统一实现并验证”。

## 查看与发送

同目录 ZIP 为普通标准 ZIP，可作为微信文件发送；无需运行 PDS 或 Keil 才能查看源码。解压后用 VS Code、记事本或 Keil 阅读。包内 Tcl / Python 保留原始路径，有些指向作者电脑；这是技术文档资料包，没有在朋友电脑上验证一键构建。
''')

keys = [
('系统总连接与时钟复位', '03_v3已烧录版本_局部源码与证据/052_yolo_camera_top_camera_servo.v', r'module yolo_camera_top', '当前烧录版本的完整摄像头、AI、HDMI、按键、语音、舵机连接。'),
('后续完整版连接与显示叠加', '02_v4后续修改_未生成可烧录位流/052_yolo_camera_top_camera_servo.v', r'assign servo_pwm', '对照 v3 查看后续修改；尚未上板。'),
('RISC-V 处理器核心', '01_FPGA当前源码/yolo/sources/015_pango_replica_core.v', r'module ', '处理器 RTL；说明 CPU 如何执行推理控制与解码固件。'),
('CPU 与 AI 的 SoC 总线', '01_FPGA当前源码/yolo/sources/040_vexii_ai_soc.v', r'module ', 'CPU、总线、UART 及加速器寄存器连接。'),
('卷积加速计算', '01_FPGA当前源码/yolo/sources/042_conv_band_rt.v', r'module ', '卷积数据流、带状处理与计算调度。'),
('乘加阵列', '01_FPGA当前源码/yolo/sources/043_mac_array.v', r'module ', '并行乘法累加结构，是 FPGA AI 加速关键。'),
('加速器寄存器接口', '01_FPGA当前源码/yolo/sources/044_conv_engine_axil.v', r'module ', 'CPU 写参数、启动运算、读取状态。'),
('DDR 与时钟域桥接', '01_FPGA当前源码/yolo/sources/045_ddr_axi_bridge.v', r'module ', '推理数据与外部内存连接；046/047 是相关 CDC。'),
('摄像头帧捕获', '01_FPGA当前源码/yolo/sources/048_camera_snapshot.v', r'module ', '把摄像头画面送入推理链路。'),
('原生视频与检测框', '03_v3已烧录版本_局部源码与证据/049_video_ai_frontend_camera_repair.v', r'module ', '当前上板版本的 OSD、结果保存与显示。'),
('中文标签与顶层显示优先级修改', '02_v4后续修改_未生成可烧录位流/049_video_ai_frontend_camera_repair.v', r'localparam integer LABEL_SCALE', '24 像素中文类别标签、背景与边界处理；未生成位流。'),
('AI 客户端与外设结果通路', '01_FPGA当前源码/yolo/sources/051_yolo_ai_client.v', r'module ', '控制通信和 AI 结果访问；与固件协作。'),
('固件主流程与板端命令', '01_FPGA当前源码/yolo/software/platform_main.c', r'int main', '模型上传校验、摄像头推理和自主运行命令入口。'),
('网络算子运行时', '01_FPGA当前源码/yolo/software/yolo_runtime.c', r'void |int |static ', 'CPU 调度硬件算子、数据布局和后处理辅助。'),
('检测框解码', '01_FPGA当前源码/yolo/software/yolo_decode.c', r'void |int |static ', '检测头解码、置信度筛选及 NMS 等，具体实现以文件为准。'),
('六类物体到垃圾桶映射', '01_FPGA当前源码/extensions/business/application/rtl/yolo_class_to_bin.v', r'module yolo_class_to_bin', 'class0→厨余；class1~5→可回收，未训练有害/其他。'),
('按键消抖', '01_FPGA当前源码/extensions/business/application/rtl/key_debounce4.sv', r'module ', '机械按键同步、消抖与单次事件。'),
('答题流程状态机', '01_FPGA当前源码/extensions/business/application/rtl/trash_quiz_controller.sv', r'IDLE: if', '识别后提问，按键比对；答错仍开正确桶，播放对应语音。'),
('外围总装', '01_FPGA当前源码/extensions/business/application/rtl/trash_peripherals.sv', r'module ', '按键、答题、舵机触发与状态快照。'),
('四路舵机 PWM', '01_FPGA当前源码/extensions/business/application/rtl/servo_pwm4.sv', r'localparam integer PERIOD', '50 Hz，500/1500 us，250 帧保持；实例参数决定反向。'),
('提示/正确/错误语音 ROM', '01_FPGA当前源码/extensions/business/application/rtl/trash_voice_rom_player.v', r'module ', 'PCM ROM 读出、事件播放和状态。'),
('I2S 音频输出', '01_FPGA当前源码/extensions/business/application/rtl/trash_i2s_tx.v', r'module ', 'PCM 串行化成 BCLK/LRCLK/DATA。'),
('HDMI 音频芯片配置', '01_FPGA当前源码/extensions/business/application/rtl/ms7210_audio_init.v', r'module ', '通过寄存器初始化音频通道。'),
('白色标题栏与实时视频合成', '01_FPGA当前源码/extensions/business/application/rtl/light_split_video.sv', r'module ', '标题区域、视频以及叠加图层组合；配合 ui_light_panel。'),
('物理引脚约束', '01_FPGA当前源码/yolo/sources/camera.fdc', r'servo_pwm\[0\]', '板级 IO 球号和电平标准；J3 排针还需实际转接板对应。'),
('UART 模型上传与控制协议', '04_AI模型处理与板端通信/scripts/board_loader.py', r'def transact', 'YAI1 请求、YAR1 响应、CRC 和模型传输。'),
('模型打包', '04_AI模型处理与板端通信/scripts/pack_deployment.py', r'def ', '模型与内存地址信息生成，配合 memory_map.json。'),
('STM32 四路中继', '05_STM32舵机中继_当前工程快照/Core/Src/main.c', r'void TIM3_IRQHandler', '采样 FPGA PWM 并由 TIM2 四通道重生 PWM；现有掩码/颜色与 v3 有冲突，见总说明。'),
]
index = ['# 关键代码索引', '', '行号对应本次包内文件。按技术文档章节选择阅读；01 是磁盘源码快照，02 是 v4 后续修改，03 是实际烧录 v3 的局部源码。', '', '| 功能 | 文件与入口行号 | 用途 |', '| --- | --- | --- |']
excerpts = ['# 关键代码摘录', '', '以下为原文件片段，便于技术文档引用。代码未作改写；完整上下文见对应文件，实际验证边界见 `00_请先阅读.md`。', '']
for title, name, pattern, desc in keys:
    p = OUT/name
    lines = p.read_text(encoding='utf-8-sig', errors='replace').splitlines()
    found = next((i for i, line in enumerate(lines) if re.search(pattern, line)), 0)
    index.append(f'| {title} | [{p.name}]({name})：{found+1} 行 | {desc} |')
    low = max(0, found-2)
    high = min(len(lines), found+22)
    excerpts.extend([f'## {title}', '', f'文件：`{name}`，第 {low+1}–{high} 行。{desc}', '', '```'+('c' if p.suffix in {'.c','.h'} else 'python' if p.suffix=='.py' else 'verilog' if p.suffix in {'.v','.sv'} else 'text'), '\n'.join(lines[low:high]), '```', ''])
write('代码索引.md', '\n'.join(index)+'\n')
write('关键代码摘录.md', '\n'.join(excerpts)+'\n')

write('技术文档编写要点.md', '''# 技术文档编写要点

## 1. 系统结构

实现平台为紫光同创 Logos2 PG2L100H（FBG676）FPGA。FPGA 内包含 RV32IM RISC-V CPU、卷积加速器、DDR 数据通路、摄像头采集、HDMI 图像显示及音频输出、按键与四路舵机控制。程序不是纯 C，也不是只有 Verilog：CPU/加速器/显示和外围由 Verilog/SystemVerilog 构成，C 固件运行于 FPGA 内部 CPU，Python 用于 PC 端模型处理与串口上传。

```mermaid
flowchart LR
    CAM[摄像头] --> CAP[采集/帧缓存]
    CAP --> DDR[DDR 数据存储]
    DDR <--> ACC[FPGA 卷积加速器]
    CPU[RISC-V CPU + C 固件] <--> ACC
    CPU <--> DDR
    PC[PC 模型上传] --> UART[UART + CRC]
    UART --> CPU
    CPU --> RES[检测结果/类别/坐标]
    RES --> OSD[识别框/标签/界面叠加]
    CAP --> OSD
    OSD --> HDMI[HDMI 显示器]
    RES --> MAP[物体类别到垃圾桶映射]
    MAP --> QUIZ[答题状态机]
    KEY[板载按键] --> QUIZ
    QUIZ --> VOICE[语音 ROM + I2S]
    VOICE --> HDMI
    QUIZ --> PWM[四路 PWM]
    PWM --> SERVO[舵机或后续 STM32 中继]
```

## 2. AI 推理链路

查阅 `yolo/software/platform_main.c`、`yolo_runtime.c`、`yolo_decode.c`，以及编号 040~051 的 RTL。说明图像输入、内存布局、卷积加速、算子调度、检测头解码、筛选和检测结果提交。PC 端 `board_loader.py` 定义模型写入、板端 CRC 检查、单帧摄像头推理和自主运行命令。

`yolo/model/graph.json`、`memory_map.json`、`deployment_model.h` 和 `model.bin` 保留实际网络与部署描述。模型当前是 biodegradable / cardboard / glass / metal / paper / plastic 六类；业务映射将第 0 类作为厨余，将第 1~5 类作为可回收。四种 UI 桶色或四种标签不等于模型训练了四种垃圾大类，不能宣称有害和其他类已具备识别能力。

性能数值必须引用对应版本、时钟和测量记录。历史约 1 秒/帧的实验不应直接当作当前 v3 的稳定性能。最近烧录检查只做了两次摄像头推理，结果为空；不能据此给出准确率或长期稳定性结论。

## 3. 识别框与界面

查阅编号 049 视频前端及 052 顶层，比较 v3 与 v4。v4 后续源码加入中文类别标签，12×12 点阵按 2 倍显示为 24×24 像素，包含类别底色、屏幕边缘处理和显示叠加次序。识别框保存/清除逻辑应结合该文件的结果有效、超时及跨时钟域代码说明；不要把源码中的目标行为写成当前已烧录 v3 的显示验收结果。

白色标题栏在 `light_split_video.sv` 与 `ui_light_panel.sv`；显示层级由顶层视频信号接线共同决定，只看面板模块不足以说明框是否盖过标题。v4 尚未产出位流。

## 4. 答题、按键与舵机

业务桶码/按键定义为 1=绿色厨余、2=红色有害、3=灰色其他、4=蓝色可回收。正常模式中，识别结果锁存为本轮答案，播提问语音，等待按键；答对/答错播放相应语音，两种情况均打开正确答案对应桶。开盖保持由 PWM 状态反馈管理；5 秒后关闭，普通模式回到等识别状态。固定答案诊断模式有单独参数，不应写成正式流程。

FPGA `servo_pwm4.sv` 的周期是 20 ms，正常脉宽 0°=0.5 ms、90°=1.5 ms；默认保持 250 帧≈5 秒。实例的 `REVERSED_MASK` 对开关脉宽进行交换，不改变 50 Hz 周期。空闲也持续发脉冲，因此 STM32 不能仅以“有没有 PWM”判断开盖，必须解码脉宽。

实际烧录的 v3 局部顶层清楚写出：

| 物理通道 | FPGA 球号 | 标准子卡参考针位 | v3 桶色 | 空闲/打开高电平 |
| --- | --- | --- | --- | --- |
| 0 | U16 | J3.27 | 绿 | 1.5 ms / 0.5 ms |
| 1 | U15 | J3.28 | 红 | 0.5 ms / 1.5 ms |
| 2 | AC26 | J3.29 | 灰 | 1.5 ms / 0.5 ms |
| 3 | AB26 | J3.30 | 蓝 | 0.5 ms / 1.5 ms |

FPGA 约束为 LVCMOS33。排针位置是历史标准子卡标注，无编号转接板应以实际连通关系为准。外接 STM32 和舵机电源必须与 FPGA 共地。

STM32 快照为 STM32F103C8T6 工程：PB12~PB15 输入，PA0~PA3 / TIM2_CH1~4 输出，TIM3 采样输入。当前代码的颜色注释与掩码未和 v3 对齐，不得直接引用旧 STM32 接线表作为当前板上最终接线。技术文档可以解释中继思路，但不能写为已经完成联调。

## 5. 音频

语音源素材见 `assets/audio`，转换后的 PCM ROM 及分银行文件见 `assets/audio_rom`，转换工具见 `tools/make_voice_rom.py`、`make_voice_banks.py`。播放器读 ROM，I2S 模块产生 BCLK/LRCLK/DATA，MS7210 初始化使音频进入 HDMI，显示器再负责音频输出。USB 供电音箱不代表音频从 USB 传入 FPGA。答题状态机的素材编号需要与播放器映射一起说明。

## 6. 构建与验证证据

目标器件和约束见 Tcl、`camera.fdc`。本包提供路由后 timing summary；可说明该报告对应的具体 v3 构建，不得将其扩大为所有后续修改都时序通过。v4 PDS 日志表示尚未完成该版本构建，不存在 v4 下载成功证据。

`03/最近重新烧录记录` 提供 JTAG、模型 CRC 和推理命令结果。记录显示 SRAM 下载，不是 Flash 固化；模型也经串口装载。因此开机自启动是另一个需要实现并验证的项目，不能写为已具备。

本包中的 testbench 和测试脚本可以用于说明验证方法；此次整理只验证文件完整性，没有重新运行全部 RTL 仿真、Keil 构建或硬件验收。历史文档内的“全部完成”“默认测试模式”等结论均须重新对照当前版本。
''')

# Audit historical v4 manifest against the source files actually delivered.
old_manifest = json.loads((v4/'build_input_manifest.json').read_text(encoding='utf-8-sig'))
audit = []
for name, expected in old_manifest.get('inputs', {}).items():
    p = Path(name)
    actual = hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None
    audit.append(dict(original=name, expected=expected, actual=actual, matches=(actual==expected)))
write('06_文件校验/v4历史输入清单复核.json', json.dumps(audit, ensure_ascii=False, indent=2))

# Detect concurrent edits of copied files. Never present a moving source as frozen.
changed = []
for r in records:
    p = Path(r['original'])
    if hashlib.sha256(p.read_bytes()).hexdigest() != r['sha256']:
        changed.append(r['original'])
if changed:
    raise RuntimeError('Sources changed while packaging: ' + repr(changed))
write('文件来源清单.json', json.dumps(dict(created_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
     purpose='Technical documentation source reference; not a validated integrated release',
     copied_files=len(records), files=records), ensure_ascii=False, indent=2))
lines = []
for p in sorted(OUT.rglob('*')):
    if p.is_file():
        lines.append(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(OUT).as_posix())
write('SHA256SUMS.txt', '\n'.join(lines)+'\n')
with zipfile.ZipFile(ZIP, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for p in sorted(OUT.rglob('*')):
        if p.is_file():
            z.write(p, NAME+'/'+p.relative_to(OUT).as_posix())
with zipfile.ZipFile(ZIP) as z:
    bad = z.testzip()
    if bad:
        raise RuntimeError('ZIP CRC failure: '+bad)
    for item in z.infolist():
        relative = Path(item.filename).relative_to(NAME)
        if z.read(item) != (OUT/relative).read_bytes():
            raise RuntimeError('Archive mismatch: '+item.filename)
summary = dict(zip=str(ZIP), size_bytes=ZIP.stat().st_size,
               size_mib=round(ZIP.stat().st_size/1024/1024, 2),
               files=len(lines)+1, source_files=len(records),
               sha256=hashlib.sha256(ZIP.read_bytes()).hexdigest(),
               zip_crc='PASS', archived_bytes_match='PASS',
               source_snapshot_unchanged='PASS',
               v4_historical_manifest_mismatches=sum(not x['matches'] for x in audit))
(ROOT/(NAME+'_打包校验.json')).write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8-sig')
print(json.dumps(summary, ensure_ascii=False, indent=2))
