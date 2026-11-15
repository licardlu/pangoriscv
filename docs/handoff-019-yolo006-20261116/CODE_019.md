# FPGA与YOLO交接说明（2026-11-15）

## 1. 本次接手的事实

已读取“fpga”对话中的用户要求、最新训练/标注结果和板端发布记录，并与本机文件交叉核对。上次后续训练、整理代码和打包交付因多次中断未完成。本次保留所有历史证据，重新整理当前完整板端版本，并启动个人实拍数据续训。

## 2. 应该选哪一版

推荐完整板端代码：019脱机启动版，完整名 `battery_voice_media_019_standalone_seed7_20261115`。它在017有声同步版基础上加入TF卡启动模型加载，已固化Flash并经独立读回及Flash重新配置验证。

| 内容 | 推荐文件或身份 |
|---|---|
| 冻结源码 | project/trash_sorting/releases/standalone_019/source/ |
| 位流 | 同目录deployment/yolo_camera_top.sbit |
| Flash配置 | 同目录deployment/standalone_019.sfc |
| 浮点权重 | 同目录checkpoint_005/best.pt |
| 配套固件 | 同目录source/yolo/sources/firmware.bin，60388字节 |
| 模型 | 同目录TF_CARD/MODEL.BIN，1858168字节 |
| 视频/声音 | 同目录TF_CARD/PROMO.PMJ、PROMO.PCM |

位流SHA256：`90b265bed134d87718ff1f60e343a40be4cee31ef4acb7eddd916fa78c9f7c4c`。
模型SHA256：`1e6616aead9a412b11a7bbdf5b68cff8b4845b98e7d7bf804a5f43f31ada223a`，CRC32 `d43b03e1`。
checkpoint005 SHA256：`97d4e50057cf64e3376b75f0207e18a8b884b18b8c4a8808ac823f74550b6c3a`。
固件SHA256：`3631d4c6777d111d2ff6bb8603d955c47ea0fdd82fefa6d05a78961060bcd039`。

019的`acceptance.json`及原始`manifest.json`中board_programmed/model_loaded=false是构建发布时的状态，不是后续板测结论；后续证据在deployment/flash_program_verification.json、flash_reset_verification.json、standalone_flash_verification.json、standalone_sram_verification.json。保留原始字段，以免改写历史。

## 3. 当前代码做了什么

- CPU/AI为54MHz，五内部类YOLOv5n，320输入，85算子。类0厨余、1可回收、2有害、3其他、4hand；hand仅用于手部定位与主体过滤，不是第五个垃圾桶。桶码/答案键映射为[1,4,2,3]。
- 相机识别后只锁定一个主体，进入答题/语音/舵机流程；接触关联和目标选择在source/yolo/software/yolo_target_policy.h及相关解码/应用文件中。检测框相交无法可靠证明物品已被拿起。
- KEY0短按循环识别页、成绩页、宣传动画页；成绩页是历史CPU参考展示，本包应用实际54MHz，不能将展示数据当成本应用的新CoreMark成绩。
- 媒体链路：TF只读块读→FAT32→PMJ/JPEG→DDR双缓冲→HDMI；PCM原声以音频采样时钟为基准同步，离开动画立即停声。相关源码位于source/extensions/media及source/yolo/software/media_*。
- 脱机启动：上电从TF根目录读取MODEL.BIN，验证长度、文件CRC和DDR中模型CRC，全部通过后开启自动识别；错误时保持推理关闭。逻辑在model_boot.c和platform_main.c。无需电脑通过UART上传模型/发启动命令。

## 4. 已验证与仍待现场确认

019最终多角时序通过，最差Slow Setup/Hold为+0.251/+0.066ns，Fast为+2.866/+0.050ns。资源41744 LUT、28024 FF、155 DRM、146 APM，DRM已用满。

历史实板证据确认：Flash program/verify/独立readback均通过；从Flash重新配置后，启动模型校验=1、自动识别=1、启动错误=0，加载约5.16秒，并实际执行相机推理。

017有声功能曾实板连续180秒、跨3次循环，0播放错误、0音频欠载；用户确认原声、同步、循环及离页停声。实际画面约10.75fps，低于25fps素材。该有声性能证据属于017；019包含此功能，但不能用它代替019全部功能重新板测。

本次新验证：冻结794个输入文件身份、固件/模型闭包、位流和TF文件SHA；在交付目录重新编译60388字节固件，与019固件逐字节一致；脱机启动3项、播放器14项测试通过。

仍待现场完成：拔掉串口/JTAG并物理断电重启、实际屏幕识别框、019有声视频回归；空手误报、小电池漏检、未拿起误触发仍是待改善问题。过去对话尚未收到物理脱线断电验收回复。本次未连接/改写开发板。

## 5. 如何运行现有019

如果板上仍是原019，无需重复烧录。保持TF卡插入，根目录三个文件齐全，接摄像头、HDMI和独立电源，上电等待约10秒。TF卡要求现有FAT32格式和8.3文件名，模型与固件必须成套。

如确需恢复位流，可使用PDS和包内program_board.py/board_benchmark_flash.py；Flash芯片为XT25F128B。重写前先对实际板上配置做有效备份并校验，不把本包中历史006备份误认为任意板卡当前备份。工具会要求--backup以及对应result.json。`deployment/standalone_019.sfc`是既有厂商生成文件。

只读启动检查入口（按实际串口修改COM20）：

```powershell
python project/trash_sorting/tools/verify_standalone_boot.py --port COM20 --model-dir project/trash_sorting/releases/standalone_019/source/yolo/model --out evidence/records/my-019-boot-check
```

此命令不会上传模型或发命令启动自动识别。

## 6. 如何重新编译019

Windows、PDS 2022.2-SP6.1及有效MES2L676许可证；RISC-V工具链为xPack riscv-none-elf GCC15.2.0-1。PDS/编译器/许可证需自行安装，本包不包含安装包。

先在代码包根目录重编固件：

```powershell
python project/trash_sorting/tools/rebuild_firmware.py --out build/my_019_firmware --gcc-prefix D:/pangowork/xpack-riscv-none-elf-gcc-15.2.0-1/bin/riscv-none-elf --source-dir project/trash_sorting/releases/standalone_019/source --model-dir project/trash_sorting/releases/standalone_019/source/yolo/model --classes 5 --cpu-hz 54000000 --linear-o2 --benchmark-reference --media --lto
```

`--gcc-prefix`末尾不带连字符，脚本会自行拼接`-gcc.exe/-objcopy.exe`。然后完整重建：

```powershell
python project/trash_sorting/tools/build_full.py --name my_019_rebuild --pds C:/Pango/PDS_2022.2-SP6.1/bin --source-dir project/trash_sorting/releases/standalone_019/source --firmware-dir build/my_019_firmware --seed 7 --hold-margin-ps 300 --optimize-multi-corner-timing --slack-prior-global-router TRUE --release-dir project/trash_sorting/diagnostics/my_019_rebuild
```

本次只重新编译固件并核验历史STA文件，没有再跑一遍数小时的PDS全布局布线。完整PDS重建命令供后续使用；新结果仍须通过全部时序、资源和板测。

## 7. YOLO数据与续训

自采844张、1460框，训练503、验证341。来自两批用户确认不同实物，整批隔离；纸团已确认普通干净废纸，归可回收。类顺序保持五类。自采训练没有纸张、厨余、其他，必须保留公共回放；自采纸张只在val，不能搬进train。

本次使用：公共回放训练3256+自采503=3759；公共val1588+自采val341=1929；公开test1634保持独立，不用test选轮次。按全部实际字节检查无跨split精确重复。没有第三批独立自采test；两批实物隔离来自用户确认，不意味着所有公开图片的物理实例都已严格核实。

训练从005/best.pt继续，24轮、batch32、320、AdamW、lr0=0.0001、冻结前2块及其BN统计，训练在RTX4060进行。不是恢复旧005优化器状态，而是从005权重进行新一轮微调。日志和运行身份在本交付目录training/；正式结果见后续训练结果说明，不将中途成绩当最终指标。

同级`yolo_training_data`/数据ZIP包含7322张实际图片、标签、来源/分组清单、固定YOLOv5 v7上游源码、本地训练入口、005起点和移目录配置脚本。原始844张标注预览完整包另有独立ZIP。查看数据包README中的环境、配置、训练命令。

新best.pt不能直接给FPGA用。后续顺序：同口径浮点比较→检查空手/电池/公共类回退→导出量化与新C运行时核对→重新编译绑定新长度/CRC的固件→完整时序与实板验证→更新TF卡模型。训练完成本身不代表手部问题已解决。

## 8. 追溯

原仓库及原始证据均未修改。本包排除了.git、仓库顶层临时build和普通Python缓存；019冻结清单登记的缓存文件保留，保留了源码、历史有效发布及证据。019额外加入构建时冻结输入和配套TF媒体，不依赖临时build目录。旧README/交接/哈希存于docs/archive/pre-handoff-20261115/。新增完整文件哈希在SUBMISSION_SHA256.json，`tools/check_package.py`用于校验。历史`check_handoff.py`只验证092/062，不能替代本次`check_current_019.py`。

补充历史归档核查：原始092快照清单中的55个临时仿真/工作库文件在原仓库已不存在，因此历史check_handoff.py目前会失败。本次未伪造或改写旧清单；019的794个冻结输入及配套运行文件已独立核验通过。缺失明细见本次检查记录historical_092_original_missing.json。

2026-11-15续训完成：006共完成24轮，已进行同口径浮点验证及019 C主体规则回放，权重和逐图结果在project/trash_sorting/training/candidates/personal_finetune_006/。详细结论见该目录YOLO训练结果与使用说明.md。019冻结板端模型仍为005；新006尚未量化或上板。

