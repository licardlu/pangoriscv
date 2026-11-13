# 2026-11-13 main 分支交接

## 接手先确认

当前板上是**092手部过滤实验版**，实际下载和模型加载证据是093。最后本次检查没有再写板。不是062原四桶、不是旧六类，也不是尚未适配的独立128手模型。

- 位流SHA256：`3371974415ac4f0c75cd12201def994d6c6b8584df29e90a8dc579d6091c7f7a`。
- 模型SHA256：`fee8eb8c9055f44d89e263711bf6f8ea1011a48172f8a0afa35171883f20879f`；CRC32 `0x60de2ae5`。
- 浮点权重：`project/trash_sorting/training/candidates/hand_trial_045/best.pt`，SHA256 `8b2fb8f4832382eaad64ce2b4ea2b71f0cf2e63a79ccdbcd9a14f1ea302bc31c`。
- CPU/AI54MHz，外设27MHz，YOLOv5n320，85算子，局部O2开、packed ADD关。
- 五内部类0厨余/1可回收/2有害/3其他/4hand；只输出四桶，桶码/答案键映射`[1,4,2,3]`。
- 配套固件44432字节，SHA256 `f81e9720b64262e057aeec56fc2ed513cbf1c55643f360cc35ec8ff7c3a97101`。
- 最终十项快慢角STA通过，Slow Setup/Hold最低+.108/+.228ns，Fast +2.712/+.167ns。资源28569LUT、22141FF、290LUTRAM、132.5DRM、123APM。
- 093实际JTAG即时/5秒配置均`081ffca0`；UART、模型CRC、输入一致性及23/38固定输入通过。38真实输出hand .72884965，证明手类部署可运行。
- 已收到自动识别首帧，恢复自动游戏。十帧预热后诊断平均1.742488秒、最大1.752200秒，全部空输出；这不是手部准确率，也不含语音/答题/舵机。
- SRAM掉电丢失，未写Flash。当前可试用，**空手和电池准确性未现场验收**。

## 代码位置与修改顺序

`project/trash_sorting/releases/hand_trial_092/source/`是完整可重建的当前版本。`project/trash_sorting/source/`是之前默认27MHz四类开发入口，不能只运行默认构建命令就声称复制当前板。重编/重新实现使用发布源码README中的显式`--source-dir`命令；不要改冻结版本后覆盖原证据，新工作复制到新目录。

| 文件/目录 | 职责 |
| --- | --- |
| `.../source/yolo/software/platform_main.c` | UART协议、实时取图/推理、相机目标筛选及OSD提交 |
| `.../source/yolo/software/yolo_contact_policy.h` | 手关联、同帧手平均面积、小物ROI、大物全框、无手最大物体 |
| `.../source/yolo/software/yolo_decode.c` | 单anchor单类，NMS .45/conf .25、每类Top-K |
| `.../source/yolo/software/yolo_runtime.c` | CPU线性算子及头，O2可选 |
| `.../source/yolo/sources/044_conv_engine_axil.v` | RTL卷积加速 |
| `.../source/yolo/portable/052_yolo_camera_top.v` | 完整应用、54MHz选择、四桶模式、舵机方向 |
| `.../source/extensions/business/application/rtl/` | 问答/目标锁、48行状态区、桶色、语音和舵机 |
| `project/trash_sorting/tools/` | 冻结构建、固件、模型准备、实际恢复、测速、C策略回放和测试 |
| `project/trash_sorting/training/` | 数据审查/清洗、训练、独立/联合手模型和量化评测 |

头部48行状态不可覆盖图像；摄像头720行完整视野映射到下方672行，框坐标跟随。舵机已由FPGA直驱，STM32目录只保留迁移参考，**运行不需STM32**。四路已由用户验收：默认关、开到位后保持5秒关闭；方向mask `1111`，不能擅改。正常问答中按键是答案，不是强制打开按键颜色桶；无论答对错均开识别桶。待答题状态不继续识别属于整轮锁定，不是CPU死机。

## 手部逻辑与缺陷

当前`hand_size_adaptive_contact_v2`：有手时过滤远处背景；小于同帧有效手平均面积的物体要求主要处于扩展手ROI内，大物体只要求接触并保留完整框；高度与手重叠的垃圾框被拒绝。检测到手却无合格物品时不给题；无手时选裁剪后有效面积最大的物体。画面只交给游戏一个对象。

手漏检、把物体框成整个人/背景、物体类别判错均可能使筛选失败。没有手输出时回退最大物体，因此不能保证“空手永远不出题”。不能简单抬高阈值掩盖电池漏检，也不能在物体本身漏检时仅靠手框恢复。

045/054小开发组量化+C主体且桶35/50、空手误选3/29，无手误手0/31；只有少数实物、主要绿蓝桶，不能代表四桶现场准确率。选用本版是用户明确要求先看过滤效果；原先因旧电池退步没有选为稳定默认。原四桶在068最终清晰电池测试主体+红桶1/15，手持0/11，主体本身常漏检；不能说旧模型电池可靠。

独立128手模型082/083、两类交互模型085/087、裁剪/遮背景079/080、重训081及051/052/058/063等都有结果，但均未安装。不要把“所有实验都存在”当作“所有模型都已上板”。失败原因和结果见`docs/verification/trash-hand-subject-crop-20261113.md`、`trash-night-optimization-plan-20261113.md`，原始记录位于evidence。

## 下一步优先级

1. 让用户对当前092测试空手/小电池纸巾/大瓶盒及杂背景；记录误出题、主体框和桶色，区分手检测、主体漏检、类别错误及关联错选。
2. 补板载摄像头照片，覆盖不同实物：空手、红灰桶手持、小电池、杂背景、不同距离/光照。训练/val/test按实物和场次分组，同角度序列不能随机串split。
3. 红灰手持覆盖不足是关键限制，不能继续复制同一纸箱/罐子虚增数量。已使用068最终电池test，禁止拿它调参后又称独立测试。
4. 保持320兼容图；任何双模型/128输入方案须先适配张量/预处理/运行时/协议、数值门禁及速度，不能直接把未量化权重加载到板。
5. 浮点、Q15+C、FPGA数值、真实场景准确率、阶段测速分别报告；变更固件需从头综合，不复用旧程序mapped DB。最后统一布线，并通过最终STA再下载。

## 数据与训练环境

公共四桶源为CodingBearHsun trash-sort v1（CC BY-NC-SA4.0）与Sumn2u bbox384 v1（CC BY4.0），YOLOv5 v7.0 commit `915bbf294bb74c859f0b41f1c23bc395014ea679`。获取入口`training/download_four_bins.py`会固定URL/归档SHA并安全解压；四桶映射与分组见`prepare_four_bins.py`及署名文档。

当前045使用043审阅数据；052是在其基础上补充审阅后的照片，不是045训练用数据。两者原始manifest、YOLO labels、固定image SHA清单均保存于`training/handoff_metadata/`。绝对路径是历史来源记录，不能照抄作新电脑目录；原始图片未随本次代码交接，公共图按下载器重新获取，自采图在原电脑`D:/Huawei Share/Huawei Share`（当前555个文件，包含后续新增照片，并非都参与训练）。重建数据须对image_inventory逐项SHA和split核对，不能将手工排除的歧义train图重新纳入。不要把当前最新照片数量当成训练数量。

训练原环境Python3.9.23，torch1.12.0+cpu/torchvision.13.0+cpu（最终以每轮provenance为准）；普通下载恢复只需Python3.10+和pyserial3.5。训练脚本还用numpy、Pillow、OpenCV、PyYAML、scipy等YOLOv5 v7依赖。使用原版本环境；升级PyTorch加载旧pickle时须处理trusted checkpoint兼容及yolov5.models别名，不能无验证升级。Windows训练脚本使用Arial字体与本地CSV logger补丁。

## 获取和运行

已在main分支整理，远端origin为`https://github.com/licardlu/pangoriscv.git`。本轮整理**不代表已commit/push**，上传前先核对`git status`，新文件仍需纳入提交。clone后先`python tools/check_handoff.py`与`python tools/check_package.py`；下载、固件、重新实现命令见根README和发布快照README。可回退`bitstream/full_54mhz_20261113`（062原四桶，无hand）。

所有构建产物留在忽略的build，不上传PDS/许可证/编译器/venv/安装包。仓库外原有技术docx、赛题PDF与tmp中的辅助源码已复制到`docs/reference/external-project-notes/`；历史脚本未执行，硬编码路径不保证可用，更不能据其文件名声称有本轮ILA证据。开发板全套安装资料无需入库。

## 常见现场问题

- JTAG显示成功但模型没加载：必须另传配套model.bin并验证CRC，DONE不能证明模型可用。
- COM34零回复但画面/心跳正常：既往Windows CP210x曾需电脑端拔插USB串口恢复；不是一律改RTL或要求重接舵机。本机重启PnP被拒绝过，勿反复无效重试。
- 已锁一道题没有新检测帧：先完成答案/开盖/到位5秒/关闭，自动循环才继续。
- 无程序/语音：检查综合日志所有68项ROM加载，任何Cannot open specified data均作废，不得把只出画面当CPU成功。
- 时序：只看最终多角报告，不能用中间after_hold_fix或历史版本代替当前实现。

详细教训先读`docs/lessons/mistakes-log.md`；模块修改先更新`docs/architecture/module-area-plan.md`。CPU CoreMark历史主线仍存在，其120MHz时序未闭合等边界见归档README，不能用垃圾分类54MHz STA替CPU120MHz背书。
