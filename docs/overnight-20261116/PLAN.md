# 夜间优化与中午交付计划

## 用户已确认

- 截止设备当地北京时间 2026-11-16 中午12:00（UTC04:00），10:00（UTC02:00）开始最后两小时布局布线、下载与验证。凌晨1点至12点约11小时，以12点交付优先。
- 持续工作、每15分钟检查提醒。自动化 fpga-15 已创建 ACTIVE，截止UTC04:00。若主聊天正在运行，不重复启动进程。
- 保持当前已运行屏幕的分辨率，不改变视频时序或要求重新接屏。
- KEY0（用户口述“按键铃”）单击开始/停止识别，双击切换页面、进入跑分页面；保留原三页循环（识别/跑分演示/动画），消抖与单/双击仲裁。单击待双击窗口结束再生效，避免双击先误触发识别。停止识别显示动画，再启动暂停动画并返回识别；页面切换增加轻量过渡。
- 四个答题按键维持原映射；已验收的舵机方向与保持5秒不擅改。
- 用户确认无新YOLO标注包，需要先补标注。
- 最后两小时直接执行最新可用版本上板，无需再次请求授权。未完成的功能明确记录，不强行下载时序/ROM/数值检查失败的位流；保留019回退。

## 工作范围与默认决定

1. 核对最新019源码和006模型，从006继续微调真正未训练数据。按源图SHA去重，不能按当前zip编号推断。原一～三已重新分卷到一～七；八～十是另311张新采图。一～十共1368张。
2. 复用已有可信标注；新增图生成候选框后逐图视觉检查、修正。保留已有val/test，按实物/拍摄场次分组；不把未标图写空标签，不用模型自己的未审预测作真值。
3. 同口径对比006和新候选，分别报告电池、可回收、手、空手/背景误选和公共类回退。训练效果与量化/C/现场分开。
4. 强化手和主体关联、空手拒识与背景过滤。单目无标定/深度传感器不能可靠实现20cm距离阈值，本轮优先采用用户批准的按键启停，不把面积阈值说成厘米测距。
5. 优化现有分辨率的布局、识别状态、垃圾类别/答题提示和页面过渡；优先在固件/现有绘制路径实现，现019 DRM155/155已满，不盲增图形存储。
6. 跑分页采用演示动画与合理持续时间，显示5.2附近的小幅变化，清楚标识演示，不称本轮真实CoreMark测量；真实历史基准保持来源。
7. 清晰自然柔和普通话，改善采样/音量/削波及播放链，新增6条反馈，包含首次答对、再次答对、连续三次答对、更多连对鼓励、答错提示与重试鼓励；与实际答题/连续次数绑定，切页避免叠音。
8. 新模型部署前完成浮点评估、量化、真实C数值核对、绑定模型长度/CRC固件、完整构建STA/资源和板测。若训练候选未过门禁，部署已验证模型配新UI/交互/语音，明确模型状态。

## 时间预算（北京时间）

| 时间 | 主要工作 |
|---|---|
| 现在～03:00 | 获取交付数据、核对SHA与已训练身份，标注新增图；启动可审计续训，检查首批真实梯度/验证/检查点 |
| 03:00～07:00 | 后台训练并持续检查；实现按键、待机动画与UI、六条语音和演示页 |
| 07:00～09:00 | 训练前后评估、手部/背景错误复核；量化/C核对与固件集成 |
| 09:00～10:00 | 冻结可交付范围、跑必要回归，准备完整独立PDS构建与回退包 |
| 10:00～12:00 | 布局布线、最终多角STA/资源、ROM/模型验证、JTAG/UART上板与页面/声音/相机检查；整理实际成果 |

持续训练指有目标的训练与评估，不在错误标签/退化模型上盲目堆轮数。提前探测构建耗时，10点为正式实现窗口；若需要更早准备以保障中午可看，先完成准备。

## 当前实际状态（首轮）

- 当前仓库HEAD bd574019，仅新增最新交接文档；仓库默认很多源码仍为13日版本，不能当019。已下载并解压真正019代码发布ZIP。
- 工作根目录 D:/FPGA_Project/zi_guang_tong_chuang。
- 当前下载/训练准备目录 tmp/training_continue_20261116/。
- 最新019完整代码：tmp/training_continue_20261116/code019/fpga_019/。冻结源 project/trash_sorting/releases/standalone_019/source/，修改前复制到新候选，不覆盖冻结版本。
- 已下载006权重与验证包到 tmp/training_continue_20261116/yolo006/personal_finetune_006/。best.pt期望SHA256 12a41d754f3917ce3a88be11aaf6309bc548c9df701b844fc0a3ec8cadd1f468。
- 正在获取原7322训练数据包（821257208字节）与844张旧标注/预览包（505662686字节）。进程 exec session34605，脚本 tmp/training_continue_20261116/inspect_remote_bundle.py --download，日志同目录download.log。通过GitHub分卷HTTP Range读取ZIP内存储条目，下载后须按bundle_payload_checksums.json逐文件核验。不可把部分获取说成完整总包SHA已验证。
- 已保存 bundle_listing.json 和 bundle_payload_checksums.json。
- 本机CPU可用18逻辑核/14物理核，内存31.5GiB，Intel Arc集显，未发现NVIDIA。可用旧CPU训练环境 pangoriscv/build/trash_train_env/Scripts/python.exe，torch1.12.0+cpu/torchvision0.13.0+cpu，cv2/numpy/PIL/yaml/scipy齐全。006原环境torch2.5.1+cu121，需真实加载和训练兼容性冒烟验证，不能假定兼容。
- 本地旧YOLOv5源码 pangoriscv/build/trash_retrain_research_20261111_001/yolov5-7.0/；新数据包预计含固定源码与train_gpu.py，可复制修改为CPU入口，不改冻结包。
- 当前数据集原图来源清单 tmp/dataset_recovery_20261115/combined_inventory.json（1057），tmp/dataset_new_20261115/labeled_inventory.json（311）；均有源SHA/场景/split，后一份含group_id。压缩包本身只有JPG，不是检测标签。
- 新增311张：no_pickup120/held_bottle136/held_battery55。恢复554张可能与更早045等训练/验证重合，也需对历史manifest核验，不直接都当新训练。
- 还未开始新训练、尚未补完标注、还未改板。不能把006历史成绩当本轮成绩。

## 后续立即执行

1. 查看download.log与进程；完整下载后校验、解压7322训练包和844标注包。
2. 核对019 check_current_019.py/check_package.py，查看最新docs/lessons与architecture预算，建立独立本轮源码候选。
3. 建立1368图源SHA与旧006/045等标注对应表、分组与split审计，定位真正新增图。
4. 从006生成候选框、人工视觉复核并记录修正，启动训练前真实加载/梯度冒烟检查。
5. 只在有真实新进展/风险/阻塞或阶段成果时向用户汇报；用户已离开，不反复问常规实现选择。

## 续接状态更新

- 019完整包17172个负载文件全部匹配SHA；原训练包15171个负载文件全部匹配SHA。两个数据ZIP载荷SHA均匹配交付清单。
- 006在本机CPU原1929张val上复现mAP50约0.6869；结果build/overnight_20261116/evaluation/baseline006_original_val/。
- CPU真实训练兼容性1epoch通过：38原train/15原val，仅作环境冒烟；冻结前2块12个张量逐项相同，226其余张量改变且全部有限，见build/overnight_20261116/compatibility_check.json。
- 当前1368原图：503已用于006 train；865需复核，保护旧val/test的整个拍摄组101张，剩764张可候选补标。注意combined_inventory.json已包含1368张，不再追加labeled_inventory以免重复311张。
- 当前图预处理已完成，build/overnight_20261116/current_photos/audit.json及images/previews；propose_continuation_boxes.py正以006在640输入生成仅供复核的框，exec session61807，日志tmp/training_continue_20261116/proposals.log。完成后sheets每张12图，人工复核写review_ledger，不得直接导出proposals为训练标签。
- 新源码候选project/trash_sorting/candidates/overnight_020/source/已复制019冻结源，尚未改RTL。最新构建工具仍使用tmp/training_continue_20261116/code019/fpga_019/project/trash_sorting/tools/。
- 用户已补接UART，COM34 CP210x再次出现；JTAG为FTDI COM32/33。初次只读boot验证正在执行，证据evidence/records/overnight-20261116/initial-boot/，日志tmp/training_continue_20261116/initial_boot.log。

## 当前接续检查点（02:15前）

- 串口COM34已恢复；只读boot实测model_verified=1/autonomous=1/error=0，实际板模型CRC d43b03e1，证据initial-boot/result.json。
- 阶段1从006开始的4轮CPU续训仍在运行，dataset_stage1是原3759train+71新人工复核图；旧val1929/test1634不变。日志tmp/training_continue_20261116/train_stage1.log，进程session19632；先查进程和日志，不重复启动。
- 补标注ledger已216/865张，已看sheet001～015、047～049；新拍瓶子补完整瓶身/手框，错误贴纸/背景预测删除。未复核图仍不能导出真值。
- 新候选overnight_020内KEY0单/双击RTL已修改；ModelSim定向测试TEST_PASS，单击延迟/双击无误单击/长按/消抖/复位/三页循环通过，证据navigation/test.log。尚未做最终布局布线或上板。
- Windows系统防睡眠保持进程29256至UTC04:00，不保持显示器唤醒；用户可关显示器但保留电脑/板供电。状态build/overnight_20261116/keep_awake_status.json。
- 自然普通话13个音源（原7+新增6）正生成，session28691；未更换ROM，仍需压缩/RTL解码/资源和播放测试。
- 后续：继续视觉补标，阶段1结束后建含新增手持样本的完整独立快照再续训；推进平滑切页、演示跑分与语音；10点正式布局布线，12点交付。

## 当前检查点（05:54，以下替代前面的运行状态）

- 865/865 张已完成逐图视觉复核；最终 dataset_stage4 新增685 train，train4444/val1929/test1634，保护旧验证和测试拍摄组101张，另留77张新验证图、排除2张歧义图。新增框：可回收337、有害127、厨余86、其他176、手555。
- 阶段3已完成，原1929张val独立复评 mAP50约0.716（006约0.68685）；手召回约0.378→0.624。固定阈值下厨余召回略降，需分项回放，不能只看总mAP。
- 阶段4正式运行 continuation_stage4_002，8轮、lr0=.00005、freeze2/BN，源为阶段3best；日志 build/overnight_20261116/stage4_training_002.log，session53584。旧001缺cv2未训练，旧queue failed不代表002。必须使用build/trash_train_env/Scripts/python.exe。
- KEY0单/双击、三页淡出淡入、新6条连对语音、ADPCM逐样本解码均定向TEST_PASS；13条新音源ROM118887字节，019原181892字节。原分辨率1280×720不变。
- 跑分明确演示，18～24秒、5.12～5.28；24次native测试及真实C生成canvas/实际RTL渲染通过。新UI顶栏和操作提示已生成。
- 固件 firmware_demo_002，60264字节，SHA256 60e3bfbf884f7bd79f7a1184c59aec62f8a0514f6669f5822be0f823459d58b3，目前仍绑定候选原模型；最终换新模型后须重建。诊断cmd15的DEMO身份仍待修。
- PDS仅综合映射预检 overnight_020_preflight_001运行中，session13043；未PNR、未上板。检查memory_loads和设备资源后，10点独立目录完整PNR。
- 阶段3量化 quant_stage3_002已完成，85算子浮点图与checkpoint逐项bit exact、160张train-only校准无zero multiplier；packed模型1858168字节，SHA256 c69595b5fc1f2c5e8e3273951fe3bb0fd240bd5f1f61be13e26361e3a4daab30。实际候选C数值核对仍待完成。
- 接下来：修native编译器Windows带空格参数；固定val数值fixtures；阶段3/4真实C与背景手部回放；完整媒体RTL elaboration；阶段4评估量化；09～10点冻结。019回退与原板继续保留。
- 防休眠进程29256、15分钟heartbeat fpga-15保持至北京时间12点；显示器可以关闭，电脑及开发板持续供电。

## 当前检查点（06:19，优先读取）

- 阶段4正式002仍正常训练，第5/8轮进行中，session53584；不要重复启动。阶段3及006验证都nc5，自动使用相同single-label/.45/max32策略。
- 06:22补充：阶段4进入第6/8轮。原1929 val全部唯一图片已冻结为`numeric_allval_001`；已启动阶段3全val Q15 oracle+实际C检查`numeric_stage3_allval_001`，日志同名.log，先检查其真实状态再继续，不重复启动。旧numeric_fixtures_001的第92号与第76号重复（6次执行、5张唯一图，四桶仍完整且输出0/1/2/3），旧证据保留，生成器已避免重复。完整allval四个板测case仍为1/23/38/76。
- 数据全量审计完成：`dataset_final_audit_002/result.json`，8007张全部图片/标签SHA一致、原val/test不变、精确SHA及已知组跨split泄漏均为0；20张分层实际导出标签已目视检查。
- 新预留77 val已导出`reserved_newval_001`（与训练SHA和已知组隔离），006与stage3评估有效结果为`evaluation/baseline006_newval_002`和`evaluation/stage3_newval_002`。旧无002评估失败在缺失厨余类别汇总，未完整生成结果；train_device.py已修为显式报告不存在类别，只平均有GT类别。原1929 val旧结果不受影响。
- 原val真实C回放`policy_replay_001`：垃圾主体正确1458→1490/1793，个人纸团64→75/146、电池55→54/60、塑料片23→22/28；无垃圾误选16→17/136。新val真实C回放`policy_newval_001`：主体52→56/77、瓶3→7/8、电池24→24/29、泡沫包装0→0/12。分项限制见EVALUATION.md，不能只报mAP。
- stage3量化的实际候选C核对已完成`numeric_stage3_002`：6图、25非卷积非head精确一致、18head最大误差0.000257492；四桶板测fixtures在其fixtures/。卷积仍是软件oracle，板测待10点后。native编译器用cc_adapter.exe；编译源已保存tools/overnight/native_cc_adapter.c。需设置ZIG_GLOBAL_CACHE_DIR=build/overnight_20261116/zig_cache，ZIG_LOCAL_CACHE_DIR=.../zig_local，并传--clang-host（仅忽略Clang不支持的GCC optimize属性，生产固件仍GCC）。
- 完整媒体在内的Tcl RTL列表130文件ModelSim编译TEST_PASS，日志full_rtl_compile_001.log。PDS预检002也已经全量综合映射通过。
- 已新增待机内置12柱波动动画，TF视频缺失时也能动态显示；有视频仍透传。`standby_002`实际RTL双相位渲染及VS边沿/离页暂停/视频透传/复位通过并目视查看。旧standby001失败为测试点选在两个相位都未覆盖的高度，已改测试采样坐标，RTL无掩盖修补。
- 最新固件为`firmware_demo_003`，60264字节，SHA256 575123915f836dca3ee8a76ee808c93479f34134986558546d5112e749711478。cmd15现在显式返回DEMO标记44454d4f。旧002不要再用（新构建门禁要求DBENCHMARK_DEMO_MODE）。003仍配候选原模型，最终模型另行重建。
- 最新预检`build/overnight_020_preflight_002`，session30039已完成：所有ROM加载通过，LUT45820、FF28103、DistributedRAM2307、DRM155/155、APM146/240。只有综合映射，尚无PNR/最终STA/上板。新工具默认release输出已改为candidates/overnight_020/release，避免覆盖旧发布目录。
- **019真正回退路径更正**：位于工作区父目录`tmp/training_continue_20261116/code019/fpga_019/project/trash_sorting/releases/standalone_019/`，不是当前仓库project/trash_sorting/releases/standalone_019（该路径不存在）。source/冻结，deployment/yolo_camera_top.sbit与manifest.json为可回退包，TF_CARD/有旧卡文件。
- 新模型板测预计使用UART加载DDR。电脑仅C/D盘，没有TF读卡器挂载；板端TF驱动明确只读，不能声称已更新TF内MODEL.BIN。最终若换新模型，12点可在持续供电下运行，但掉电独立启动需要把配套新MODEL.BIN写入TF；保留旧TF和019回退，不扩展未经验证的写卡路径。

全val数值检查exec session24461（06:22启动）。正式002训练session53584；其余预检和短测试已完成。防休眠和15分钟heartbeat仍有效。

06:25 heartbeat：上述两进程仍健康（训练第6轮、全val数值已过约580张；日志ID不是连续计数，故不将670当图片数）。新增`tools/overnight/score_numeric_validation.py`并语法检查通过，等全val数值result PASS后执行：`--numeric build/overnight_20261116/numeric_stage3_allval_001 --photos build/overnight_20261116/numeric_allval_001 --manifest build/overnight_20261116/dataset_stage4/manifest.json --policy-replay build/overnight_20261116/policy_replay_001 --source-dir project/trash_sorting/candidates/overnight_020/source --out build/overnight_20261116/quantized_stage3_val_score_001`。统计固定conf .25/IoU .5每类TP/FP/GT及真实C选物，明确不从截断输出伪算AP。该工具尚未完整执行，需核对结果与已有float对照。

### 下个检查点具体动作

**07:11最新**：006和stage4全1929 val exact均已PASS，已运行score_numeric_validation生成`quantized_baseline006_val_score_001`、`quantized_stage4_val_score_001`。与stage3同Q15+C口径：主体正确1398→1460→1452/1793；无垃圾误选26→15→11/136；纸团47→71→54/146；电池53→47→50/60；塑料片23→20→19/28；手召回110→240→234/370。完整分项见EVALUATION.md。CPU卷积oracle不冒充板测；非head仅首图25算子通过。两全val进程均结束，无须重启。stage5仍第3/6轮，后处理仍等待，正常；防休眠状态更新时间正常。下一次优先看stage5/后处理，完成后跑stage5全val exact并按同口径score，再新77 val量化回放，然后选最终模型。尚未冻结、尚未新PNR。

07:12补充：已冻结新77 val全部唯一图为`numeric_newval_inventory_001`（允许无厨余类、不捏造覆盖）。已启动006/stage3/stage4新77 val Q15+C exact检查，输出`numeric_baseline006_newval_exact_001`（session57114）、`numeric_stage3_newval_exact_001`（session86409）、`numeric_stage4_newval_exact_001`（session65475）。全部完成后分别用score_numeric_validation.py --manifest reserved_newval_001/manifest.json --photos numeric_newval_inventory_001 --policy-replay policy_replay_001输出quantized_baseline006_newval_score_001、quantized_stage3_newval_score_001、quantized_stage4_newval_score_001。正常需约一分钟；下一次只看结果不要重复启动。

**06:58最新，替代下面旧运行状态**：阶段4八轮与posttrain全部完成。checkpoint SHA a4a0b1b04f83af1d114813e0512dd2c2fa5e7306fae16759824f136b3133021a。stage4原val mAP50 .721075，新val .819439；实际C原val主体1456/1793（0061458、stage31490），空手误选9/136（00616、stage317）；个人纸团60/146、电池50/60回退；新val主体58/77。见policy_stage4_original_001、policy_stage4_new_001，暂不冻结模型。

- stage3全1929 val exact已PASS（5787head，最大FP误差.00038624）；`quantized_stage3_val_score_001`完整统计通过，主体1460/1793、空手误选15/136（这些是Q15+C，不能与浮点混称同一结果）。
- stage4量化`quant_stage4_001`与`numeric_stage4_exact_001`已PASS。blobSHA7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728。**全1929 val exact运行session83081**，目录numeric_stage4_allval_exact_001，完成后用score_numeric_validation.py生成quantized_stage4_val_score_001。
- **stage5保守分支已运行session93098**，从stage3best用最终dataset_stage4六轮，freeze10/BN，lr0=.00001、--warmup-bias-lr .00001。现有train_device新增显式bias warmup参数，默认仍.01以保持历史复现；本轮保守分支不再用比lr高1000倍的bias warmup。日志stage5_training_001.log，run continuation_stage5_001。目的恢复旧纸团/电池同时学全685新增；09点前结束探索。不要重复启动。
- **stage5后处理队列session82066**（程序posttrain_stage4.py新增--stage5，注意命令是--stage 5）。状态stage5_posttrain_001.json，等训练completed后自动原val/新val、006/stage3/stage4/stage5 C回放、quant_stage5_001、numeric_stage5_exact_001。不要手动抢同名目录。stage4旧后处理已completed。
- **006量化对照session79417**：quant_baseline006_001，data=baseline_data（原train），checkpoint原006，160train-only校准。同口径部署量化基线用于避免float与Q15混比；完成后用numeric_allval_001和--exact-q16-head跑全val，再score_numeric_validation。当前stage3全val已结束，CPU阶段5四线程+stage4全val四线程+006校准四线程尚可。
- 训练、量化所有新候选均未上板，019保持。10点正式完整PNR/12点交付不变。
- 06:59：006量化完成，已启动其全val exact，session28966，目录numeric_baseline006_allval_exact_001，日志同名；完成后score_numeric_validation输出quantized_baseline006_val_score_001。stage4全val83081继续。

06:44最新：原`numeric_stage3_allval_001`在第1586张（原ID1679，sumn2u_b968776b913b8552c3cd.jpg）失败：Q16实际C与浮点head单元素误差0.00036216，超旧固定atol.0003。**旧全val检查不算通过**，不改旧日志/结果。

已增加显式`--exact-q16-head`门禁：独立按packed权重转换Q16、int64计算dot、逐步float32运算，与真实C输出逐元素bit-exact比较；另外逐像素按真实权重量化误差×|输入|和float32 gamma推导浮点偏差上界，不事后增大旧固定容差。生产模型/固件/RTL未改。回归单例`numeric_head_regression_check_001`精确通过，旧误差仍如实保留；数值smoke `numeric_stage3_exact_smoke_001`也通过。全1929 val新严格核对`numeric_stage3_allval_exact_001`正运行，session91563，旧24461已失败结束。后续都显式加--exact-q16-head。

已启动`tools/overnight/posttrain_stage4.py`，session56367，状态`stage4_posttrain_001.json`和日志`posttrain_stage4_001.log`。它只等正式002 provenance.completed后锁定best SHA，再顺序跑：原val、新val、两套006/stage3/stage4实际C回放、quant_stage4_001、numeric_stage4_exact_001。所有目录唯一，不要同时手动启动这些同名步骤。训练仍在最后第8轮。后处理脚本固定venv，09点截止防止等死，无PDS/上板动作。

下一次优先查看训练、posttrain状态和全val exact日志；若posttrain完成，直接查看分项并启动stage4全val exact检查（可复用numeric_allval_001），不再重复原val评估。`score_numeric_validation.py`执行时numeric路径应选通过的allval_exact结果，不是旧失败allval_001。

1. 读取stage4_training_002.log和results.csv；八轮完成后只从正式002取best，保存SHA。依次用train_device.py --evaluate val --threads2评估dataset_stage4/data.yaml和reserved_newval_001/data.yaml，新输出stage4_original_val/stage4_newval，之后用tools/overnight/replay_policy.py和同一candidate source-dir对比006、stage3、stage4。
2. 用tools/overnight/prepare_deployment.py --out build/overnight_20261116/quant_stage4_001 --yolo build/overnight_20261116/upstream/yolov5-7.0 --data build/overnight_20261116/dataset_stage4 --checkpoint .../continuation_stage4_002/weights/best.pt --expected-checkpoint-sha256实际值 --include-hand（查看脚本确认data参数是目录，stage3命令参考quant日志/产物）。校准必须train-only。
3. 用check_deployment.py加--clang-host、--linear-o2、--source-dir候选，原numeric_fixtures_001核对stage4。余时可create_numeric_fixtures.py加--all-validation生成全1929 val Q15/C核对与回放，不碰test调参。
4. 根据原val与新val分项、空手误选/公共类回退与数值门禁选最终模型，09～10点冻结，不追逐单项最高分。可在冻结后一次性原test最终评估，但不据test再调参。
5. 最终新模型路径quant_.../packed与新固件必须一起传build_full，不能使用原003配新模型。固件工具--benchmark-demo --media --lto --linear-o2 --classes5 --cpu-hz54000000，并显式--model-dir最终packed。
6. **10点正式完整PNR**：独立新--name目录，--source-dir候选、--firmware-dir最终固件、--model-dir最终packed、--hold-margin-ps 300、--optimize-multi-corner-timing、--seed 7、--slack-prior-global-router TRUE；--release-dir project/trash_sorting/candidates/overnight_020/release。一次实现一目录，不能对preflight覆盖重跑。源流程及多角STA/资源/ROM/模型门禁通过才生成和下载。
7. 可用project/trash_sorting/tools/restore_full_board.py --release-dir新release --port COM34 --pds ../pds/PDS_2022.2-SP6.1/bin --out新独立evidence --fixtures最终numeric/fixtures --verify-input --probe-frames3 --collect-profile；先读其完整流程核对最新固件兼容性。JTAG即时/5秒配置、DDR模型CRC、四fixtures、相机/自动循环须实测。新的DEMO身份及媒体/语音诊断另验，物理屏幕/听感不冒称远程目视。
8. 保持现有fpga-15 heartbeat和29256防休眠；截至12点停止新构建，交付实际完成项/限制及新TF_CARD/MODEL.BIN配套文件，停heartbeat。

## 07:26运行状态（最新，以本节为准）

- 006/stage3/stage4新77 val量化exact均已PASS，对应score目录已完成：quantized_baseline006_newval_score_001、quantized_stage3_newval_score_001、quantized_stage4_newval_score_001。正确主体51→55→55/77；该集全部有垃圾，没有空手样本，不能拿它评价误选。手TP48→64→64/72。原1929 val量化完整结果保持1398→1460→1452主体、26→15→11误选。
- stage5训练仍正常，第5/6轮进行中（session93098）；后处理stage5_posttrain_001仍等待（session82066），训练完成后自动原val/新val浮点评估、四模型C对比、量化、小fixture exact。
- 新增**stage5完整量化验证队列session96826**，工具post_numeric_stage5.py，状态stage5_full_numeric_queue_001.json。它等stage5_posttrain_001.completed之后自动跑numeric_stage5_allval_exact_001→quantized_stage5_val_score_001，再numeric_stage5_newval_exact_001→quantized_stage5_newval_score_001；所有命令与日志写状态，若上游失败即停止。不要手工重复同名任务。截止09:15等不到上游即失败，不影响10点构建安排。
- 所有006/stage3/stage4数值进程已完成，只剩stage5训练/两条顺序队列和防休眠。防休眠活跃。当前无需用户操作，尚未冻结模型/PNR/上板。下一次读取上述两个stage5状态及训练日志，完整验证后选择取舍、编译配套固件，准备10点PNR。

## 07:41运行状态（最新，以本节为准）

- stage5六轮训练和全部浮点后处理已完成，checkpoint SHA256 `e289012ceb771eda1cd6d5f081486d8007a0ef174f179fe5aa664d1a4dc22062`；量化packed SHA256 `4e2166f7e680c08f5fce1afb0a7291aacc4fbfdb1239d217a6808b07da527d19`、CRC32十进制1905477747。小fixture六次exact通过，最大浮点head偏差0.00017409。
- stage5浮点：原val mAP50 .7151367284、新val .6929673294；实际C主体1468/1793、无垃圾误选11/136、纸团70/146、电池52/60、塑料片22/28；新val主体56/77。恢复部分旧个人样本，但仍须等同部署量化完整分项决定。
- `stage5_full_numeric_queue_001.json`继续自动执行，日志当时到原清单ID1340（ID不是已处理图片计数）；后续自动score，再新77 val exact/score。进程5772，原session96826，不重复启动。结果未完成前不冻结。
- 已确认系统防睡眠状态07:41持续刷新，`display_required=false`，用户可以关显示器；主机和开发板/USB/JTAG保持供电。07:41电脑本地时间为北京时间，与UTC截止04:00一致。10点PNR、12点交付不变。

## 07:50运行状态（最新，以本节为准）

- stage5全1929原val和77新val exact/score全部完成，队列completed。原val主体1454/1793、无垃圾误选15/136、纸团68/146、电池46/60、塑料片21/28、手TP249/370；新val主体55/77、手TP66/72。全原val5787 head逐元素精确通过，最大浮点偏差.000225067；新val231 head通过，最大浮点偏差.000185609。它未整体胜过stage3，不能因为最新而直接部署。
- **最后一组受控对照stage6已经启动**：仍从stage3 best、最终685新增训练快照、6轮、lr0和warmup_bias_lr均.00001，仅相对stage5将freeze10改成freeze2（继续freeze_bn）。目的检验较深层的小步更新是否能改善新样本/空手并保留旧个人表现，不更换损失/数据/阈值。训练session54941，日志stage6_training_001.log，run continuation_stage6_001。
- stage6后处理session32751：`posttrain_stage4.py --stage 6`，状态stage6_posttrain_001.json；全量量化队列session30322：`post_numeric_stage5.py --stage 6`，状态stage6_full_numeric_queue_001.json。原stage5队列已结束；上述脚本仅增加stage6目录参数，历史stage4/5默认和证据保持。两个脚本py_compile通过。不要重复启动同名任务。
- stage6预计08:30～08:45完成，后处理+完整量化预计09:00～09:15；09点前停止新的训练探索。若失败或超窗，按已完整通过候选stage3/4/5选择，不能挤占10点PNR。**尚未最终冻结模型/固件，尚未正式PNR/上板。**
- 下一次先看stage6训练progress.json和两队列状态、防休眠；其间可准备最终发布/回退/板测流程。完整score出来后选模型、独立编译配套固件（不能用绑定旧005的firmware_demo_003）、冻结，再10点新目录完整PNR。

### 07:55心跳检查与部署准备

- stage6首轮训练已进入val，无失败；后处理进程30132、全量数值队列14860均存活并等待，防休眠29256持续刷新。尚未开始正式PNR或改板。
- 先编译了完整验证候选stage4的配套备用固件`build/overnight_20261116/firmware_demo_stage4_001`（无install）：60264B，SHA256 `061e46fb5218520185bba5128b664609e4c051325026319a432aef3d6d54c85d`，绑定stage4模型SHA `7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728`。GCC/LTO/linear-O2/media/demo/54MHz/5类均同计划，保留8KiB堆栈断言，编译通过。它仅是候选配套备用；最终若选其他模型必须另编译对应固件，不混配。
- `project/trash_sorting/tools/restore_full_board.py`已补充仅对simulated_demo发布启用的只读诊断：模型上传前cmd15必须返回DEMO标记0x44454d4f；CRC后cmd20核对model_verified/模型长度CRC，cmd16核对媒体标记和54MHz。原TF启动错误单独保留，不能因UART后model_verified=1就声称TF已更新。读取诊断在cmd7自主循环之前，结果写入同轮result.json。语法检查通过；本轮尚未在板上执行这些检查，physical_full_application_verified继续false。
- 下一次只需检查stage6 progress/队列；09点左右完整量化分项后冻结最终选择，再安排10点正式新目录PNR。原019/TF未改，屏幕可关。

### 08:09心跳检查

stage6已完成2/6轮，正在第3轮末尾，provenance仍running且freeze2/lr0与bias warmup均.00001正确；第2轮训练入口val mAP50 .720947仅作训练进度，不能替代最终部署评估。后处理30132、全量数值队列14860及防休眠29256均存活；D盘约392GB可用，无下载/训练/PDS失败。继续现有任务，不重复启动。

正式PNR仍定10:00；当前心跳落在每小时08/23/38/53分，因此**09:53回合需在当前回合留到10点（短等待），或启动已冻结命令的定时等待进程**，避免等到10:08才开工。最终源码/模型/固件必须在此前锁定并核验；不提前运行完整PNR。构建完成后release除位流/manifest还应打包匹配model、firmware、按inputs.json逐文件验证的source，以及新TF_CARD/MODEL.BIN（旧PROMO.PMJ/PCM可从019只读复制），并明确TF尚未实际写卡。019回退在父目录路径保持不动。

### 08:25心跳检查

stage6已完成4/6轮，正在第5轮，训练日志持续推进，无失败；两依赖队列继续等待完成的checkpoint，防休眠正常。仍预计08:35左右训练闭合，下一次心跳优先读取stage6_posttrain_001.json及stage6_full_numeric_queue_001.json，不重复原目录任务。

已按`overnight_020_preflight_002/inputs.json`的801个记录逐文件核对当前候选：除预期最终替换的model及firmware外，全部源/RTL/音频ROM/图形资产SHA均与已通过综合映射的002预检相同。最初一次PowerShell筛选未归一化反斜杠，列出10项预期固件差异；归一化后非模型/固件差异为0，不是额外源码漂移。说明当前UI/语音仍对应既有预检，不等于最终配套模型/固件的PNR或STA通过。最终新模型及固件仍必须在10点新目录全流程重新综合实现。

## 08:40最新：全部计划训练结束，进入最终选型验证

- stage6六轮及训练退出验证已完成，provenance.completed，finished_unix1794789303.5012434（08:35左右）。best checkpoint SHA256 `f30a06ecab731a0dcf5eefff29dc7aa35cd02bd9427ccad04244a11e4476015e`。不再新增训练分支，保留时间完成量化与部署。
- 后处理30132已经完成独立原val/新val浮点评估及实际C回放，当前`stage6_posttrain_001.json`为quantizing；`quant_stage6_001.log`校准48/160正常推进。全量数值队列14860继续等待后处理完成，再自动跑原1929及新77，禁止重复启动同名目录。防休眠正常。
- stage6同部署浮点原val mAP50 .71680924、新val .75158697；实际C主体1449/1793、空手误选9/136；纸团49/146、电池54/60、塑料片20/28；新val主体56/77（瓶7/8、电池24/29、泡沫1/12、桌面24/28）。有取舍，不能因训练入口mAP .72386就说部署准确率提升。最终仍等量化完整分项。
- 下一次读取stage6_posttrain/full_numeric状态；completed后冻结stage3/4/5/6中最终模型并写选择依据与未改善项，编译该模型配套固件及准备最终一次test报告。10点PNR、12点交付不变，019继续运行未改。

## 08:57最终选择已冻结（最新，以本节为准）

- stage6后处理与原1929/新77完整量化队列均completed，所有exact/score PASS。原val量化主体1431/1793、误选17/136、纸团45/146、电池46/60、塑料片22/28、手TP234/370；新val主体56/77、泡沫1/12。原5787head精确通过，最大浮点偏差.000301361；新231head通过、最大浮点偏差.000246197。blobSHA `5155f3dd60e186184876d337872e54cef2ccbdb31ba04f60d1d10e1fdfb41f15`。整体未超stage3/4，不部署最新stage6。
- **最终选stage4**（完成全部685新增train），优先用户强调的空手/背景拒识：相对006量化主体1398→1452/1793、无垃圾误选26→11/136、新val51→55/77；stage3主体比stage4多8张，但误选15，电池47而stage4为50，泡沫0而stage4为3。保留取舍：stage4纸团54低于stage3的71；相对006电池53→50/60、塑料片23→19/28回退，不能声称全面提高。
- 冻结记录`build/overnight_20261116/final_selection_001.json`（08:54:50建立，test读取前）；独立不可覆盖源码`project/trash_sorting/candidates/overnight_020/frozen_20261116`，801输入SHA记录。最终source内已安装stage4配套model及firmware，`build_full.verify_firmware_sources`通过。模型SHA `7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728`；固件SHA `061e46fb5218520185bba5128b664609e4c051325026319a432aef3d6d54c85d`（60264B）。后续正式PNR必须用此frozen目录，**不是可编辑source**。
- 已启动最终配套预检`overnight_020_preflight_003`，session24999，日志`preflight_final_003.log`，仅综合映射无PNR，检查替换模型/固件后的ROM及资源。不要重复启动/覆盖。
- 最终选择冻结后才启动原1634 test一次性A/B报告：`evaluation/final_stage4_test_001` session54591、`evaluation/final_baseline006_test_001` session88157，日志各同名.log。**无论test如何，不能据它重选模型或调参**。两个CPU各2线程，均进度正常。
- `replay_policy.py`仅新增--split val/test（默认val保持），报告明确split及held_out_test_used。待上述test结束，使用--split test、同dataset_stage4/manifest.json、source-dir frozen_20261116与两evaluation，在新目录`policy_final_test_001`运行实际C回放并写最终报告，不改test标签或假冒val。Host编译需设置ZIG_GLOBAL_CACHE_DIR和ZIG_LOCAL_CACHE_DIR为本轮既有缓存。
- 10点正式新目录PNR命令现在可用`--source-dir project/trash_sorting/candidates/overnight_020/frozen_20261116`（内部model及firmware已配套，不再传旧003）。其余seed7/hold300/multicorner/slack-prior TRUE/release候选目录不变。仍未正式PNR、未改板、未写TF，019保留。

### 08:59后续检查点

最终一次test A/B及`policy_final_test_001 --split test`已完成、TEST_PASS；原1634 test浮点mAP50 .81876271→.81996922，mAP50-95 .53224165→.54928877，主体1412→1424/1613，无垃圾误选均1/21。全部公共来源，没有本轮个人场景；不将此浮点结果冒充量化或板上准确率。完整报告已写EVALUATION。最终选择保持stage4，无新的训练/调参。

`overnight_020_preflight_003`仍综合中，日志持续推进，无错误；session24999。下一次心跳先查`preflight_final_003.log`及`build/overnight_020_preflight_003/preflight.json`，完成后记录ROM与资源；无需重复test或预检。防休眠正常。9点后只作部署核验/打包准备，09:53回合按上文等待至10点启动正式全流程。

## 09:12最新：最终配套综合映射已通过，发布素材已备齐

- `overnight_020_preflight_003`完成，`preflight.json`为COMPILE_SYNTHESIS_MAPPING_COMPLETE，PREFLIGHT_MAPPING_PASS。8路固件ROM、59个音频bank和UI/font/labels均真实load通过；无PNR、无bitstream、无改板。Device-map资源：LUT45820、FF28103、DistributedRAM2307、DRM155/155、APM146/240。`preflight_final_003_resources.csv/json`保存原DMR提取结果，`preflight_final_003_area_gate.json`整机strict PASS（仅映射，不代替最终布线资源/STA）。
- 已在`project/trash_sorting/candidates/overnight_020/release/`准备830个配套素材（约220MB）：source/、model/、firmware/、checkpoint/best.pt、numerical_fixtures/、TF_CARD/及final_selection.json。每个源SHA匹配冻结记录，MODEL.BIN匹配最终模型SHA，旧PROMO.PCM/PMJ只读复制并SHA核对。`package_assets.json`明确ASSETS_ONLY_WAITING_FOR_10AM_PNR_AND_BOARD_TEST、tf_card_written=false、board_programmed=false。README也明确尚无新位流和物理验收，不能当已完成发布。
- release目录已存在，build_full正常允许既有目录并只在最终门禁通过后写新yolo_camera_top.sbit/manifest.json。**正式PNR用frozen_20261116，而不是release/source或可编辑source**。源包801输入身份保持，后续只更新交付文档和板测记录。
- 板测可直接使用release/numerical_fixtures四输入（模型身份已配套），release/model使restore_full_board无需依赖构建缓存查找模型。正式完成后还需把本轮PNR/最终STA/board evidence归档并更新README，重新生成最终全包身份清单；不要把预检PASS写成板测PASS。
- 下一次9:23/9:38回合检查冻结身份、防休眠/端口与交付文档即可，无需再训练/评估/预检。09:53回合留到10:00启动新构建`overnight_020_full_001`，避免延迟；12点期限不变。

### 09:25心跳检查及上板Python环境

冻结source全部801文件SHA与发布包830素材的SHA/长度再次核对通过；正式`build/overnight_020_full_001`尚不存在。COM34 CP210x、COM32/33 FTDI均在，防休眠持续刷新。没有运行中的新训练或PDS，也没有改板。继续保持10点全流程安排，不重复预检/评估。

**上板/串口必须用Python310**：`C:/Users/Twinkle Nebula/AppData/Local/Programs/Python/Python310/python.exe`，本轮已实际import serial并枚举全部端口成功；训练venv `build/trash_train_env/Scripts/python.exe`没有pyserial，不能用它执行restore_full_board。此次先在训练venv做只读枚举因缺serial立即失败，无端口打开/无板写入；改用Python310通过，无需改变训练依赖。board_perf/board_loader加载及parse_profile路径为标准库，prepare_image仅按需导入cv2，不影响fixture板测。正式PDS也继续用Python310。

10点命令（cwd仓库根）：Python310 `project/trash_sorting/tools/overnight/build_full.py --name overnight_020_full_001 --pds ../pds/PDS_2022.2-SP6.1/bin --source-dir project/trash_sorting/candidates/overnight_020/frozen_20261116 --seed 7 --hold-margin-ps 300 --optimize-multi-corner-timing --slack-prior-global-router TRUE --release-dir project/trash_sorting/candidates/overnight_020/release`。日志写本轮build/overnight_20261116/full_001.log，10点前不启动。通过后Python310 `project/trash_sorting/tools/restore_full_board.py --release-dir project/trash_sorting/candidates/overnight_020/release --port COM34 --pds ../pds/PDS_2022.2-SP6.1/bin --out evidence/records/overnight-20261116/final-board-001 --fixtures project/trash_sorting/candidates/overnight_020/release/numerical_fixtures --verify-input --probe-frames 3 --collect-profile`，同目录result.json记录真实板验收，不提前写PASS。

### 09:41心跳：预览材料补齐，10点开工待命

防休眠09:38仍活跃，面积预检PASS，正式构建目录仍不存在；没有PDS后台任务（Get-Process找不到进程的退出1是正常无匹配，不是构建失败）。未重训、未重复评估、未改板。

release/preview已补入实际RTL仿真dashboard.png及standby0/1.png（对应checks.log均TEST_PASS），以及13条原始神经MP3。全部MP3逐一匹配冻结音频manifest的source_mp3_sha256。preview/manifest.json单独记17素材SHA及范围：RTL图不是物理屏幕照片，原MP3不是ADPCM/扬声器输出录音。发布README已说明；原package_assets.json保留准备时830素材身份，新预览有独立清单，最终交付再统一全包清单。

下一回合09:53需按09:25精确命令，在当前回合每次不超过60秒短等待至10:00（02:00 UTC），然后立即启动overnight_020_full_001。不要09:53直接结束再等10:08。正式门禁通过后用Python310直接执行已授权SRAM上板+UART模型CRC/四fixture/相机检查，未通过的候选不下载。所有路径和回退已备齐，12点截止不变。

## 09:56最新：10点执行进程已等待，禁止手动重复启动

09:53最终启动核对通过：冻结801输入SHA、配套固件/模型/ROM、Python310的serial及board_loader/board_perf/tool_paths、PDS路径、唯一full_001与final-board-001路径全部正常，无板写入。

已新增并启动`tools/overnight/run_final_once.py`（实际路径`project/trash_sorting/tools/overnight/run_final_once.py`），Python310 session72515。它在UTC02:00/北京时间10:00之前只按10秒间隔等待并刷新`build/overnight_20261116/final_execution_001.json`；到点重查冻结身份，自动执行09:25的独立full_001全流程。构建成功且多角STA/资源/ROM门禁通过、manifest模型及DEMO身份匹配之后，自动执行既定final-board-001的SRAM下载、UART模型CRC、四fixture及相机探针，省去等待下一个15分钟心跳。任一步失败即停止并写status=failed；12点后不启动新步骤。该脚本py_compile通过，含exclusive lock，不能重复启动。

**后续每次先读final_execution_001.json，再按status检查full_001.log或final_board_001.log及final-board-001/result.json**，不要同时手动运行build_full或restore。session72515为整条执行链，独立子步骤PID由日志/系统查；PDS即使未结束也无需重启。未通过的候选仍不会上板。若失败，先读具体门禁错误，在新目录修复，不能覆盖同名实现证据。

## 10:01最新：正式物理实现已准点启动

执行链pid3540/session72515在**北京时间10:00:00.192719（UTC02:00）**准点启动formal_implementation，状态`final_execution_001.json`已记录完整命令。`build/overnight_020_full_001`及full_001.log存在，PDS当前正常综合rtl-data-opt；完整流程包含新综合映射、seed7放置布线、多角STA/面积/ROM门禁、位流生成。不能把刚启动全流程说成布线/时序已完成。防休眠10:00仍正常。

下一次10:08心跳先查final_execution状态及implementation.log最后阶段；正式门禁成功后同执行链会自动开始final-board-001，无需重复人工启动。若board_acceptance，读取final_board_001.log/result.json确认实际UART/JTAG/fixture进度。019目前仍运行，尚未下载新位流；TF未写。

### 10:09心跳检查（时间沿用本计划已约定的设备北京时间）

final_execution_001仍formal_implementation，pid3540/session72515健康。PDS已完成综合映射、进入Phase1.1首次全局放置，Design Utilization69%，implementation.log约2.9MB并持续推进；没有E级错误。当前属于正常物理实现中，尚未完成布线、最终STA或位流生成。防休眠29256持续刷新；final-board-001尚不存在，019未被替换。

下一次先读执行链状态与PDS阶段/未布通连接趋势，不因放置计算时日志短暂不变就重启。构建成功后现有执行链自动进入板测；若失败按完整错误定位并新目录处理。不要重复启动或把引脚提示“has been placed”误当全设计完成。最新用户“开始”已回复正在执行，无新增范围变化。

### 10:24心跳检查

正式full_001已完成各放置阶段，进入Routing。未布通连接从iteration38的3021逐步降至iteration50的1260，iteration51为1280，整体仍明显收敛；单轮约1.7～2.6秒，不能因一轮小幅反弹判断卡住或重启。尚未到最终STA/位流门禁，执行链仍formal_implementation、pid3540/session72515；没有E级错误。防休眠正常，final-board-001尚未开始。

下一次读取final_execution及当前routing阶段、连接趋势和是否进入hold修复/最终STA；同链成功后自动板测，不重复启动。保留本轮证据，不将路由中间摘要当最终时序。截止UTC04:00不变。

## 10:42最新：首轮STA未通过，第二轮物理实现正在进行

- full_001布线已完成，但10:32最终多角STA失败：Slow DDR→phy_dq_sysclk_1 setup -0.187ns/1端点，Slow DDR内部hold -0.013ns/1端点，Fast DDR内部hold -0.001ns/1端点。AI54MHz和像素域setup/hold通过。面积门禁PASS（LUT45274、FF28103、LUTRAM2307）。**未生成位流、未改板**，不能将该轮交付。旧final_execution_001.json已failed并停止，session72515不再负责后续。
- 失败输入/日志/最终rtr/资源报告已独立归档`evidence/records/optimization/overnight_020_full_001_failed_sta/`，failure.json记录失败端点及SHA，原构建不覆盖。
- 已立即启动**full_002**，session59271，日志`build/overnight_20261116/full_002.log`：复用full_001的不可变mapped DB，`--reseed-placement --seed 11 --hold-margin-ps 500 --optimize-multi-corner-timing --slack-prior-global-router TRUE`，重新放置布线。输入801文件SHA全部匹配最终冻结；没有降低频率、放宽约束或修改模型/RTL，500ps增加hold目标余量；不同放置检验DDR单端点setup能否收敛。10:42处于Phase2全局放置，无错误。最终全部门禁仍必须通过。
- 已启动**新自动板测等待队列**`accept_final_retry.py`，Python310 session67757、pid23868，状态`build/overnight_20261116/final_retry_002.json`，waiting_for_gated_full_002。它仅在full_002.log出现FULL_APPLICATION_BITSTREAM_READY、release/manifest的source_build/模型SHA/bitSHA/timing/DEMO全部匹配后启动同一个尚不存在的final-board-001。构建失败或12点截止即停止，无盲目下载。exclusive lock已建，不要重复启动。脚本py_compile通过。
- **后续优先读final_retry_002.json和full_002.log/implementation.log**；不要再等旧failed的final_execution_001，不要手工抢跑板测。full_002若通过会自动板测，保留原019回退。TF未写，physical_full_application_verified=false。余时充足但不保证第二轮通过，12点如实交付结果。

### 10:54心跳检查

full_002已完成放置并正常布线，未布通连接从iteration14的17860降至iteration23的8153，单轮耗时12.3→5.9秒，尚未出现长期反复或E级错误。新板测等待进程23868及防休眠29256存活，状态waiting_for_gated_full_002；该等待脚本仅状态变化时写json，因此utc仍10:41不代表进程失活。发布目录尚无新sbit，final-board-001尚不存在，未改板。继续现有物理实现，无需重启或新开一轮。

下一次11:08优先读full_002最终STA/门禁或当前连接趋势；若通过，现有队列立即下载，留意模型上传/CRC/四fixture验证进度。若再失败，检查具体路径再决定余时内新目录修复，仍不能下载失败候选。12点后不启动新步骤。

## 11:13最新：最后一次布线优化full_004，优先读取004状态

- full_002于11:03完成布线但最终STA仍失败，**只剩Slow DDR→phy_dq_sysclk_1 setup -0.040ns/1端点**，所有hold已通过。未生成/下载位流，板上仍019。完整失败证据归档`evidence/records/optimization/overnight_020_full_002_failed_sta/`；旧final_retry_002已failed并退出。
- 在新目录尝试full_003复用full_002放置时，启动PDS之前发现工具只在input/device_map查映射ADF，而复用轮实际在mapped_input；本次未运行PNR。已修工具：fallback仅在上一轮reused_placement provenance存在且ADF/PCF SHA匹配时允许，经验写mistakes-log。full_003残留目录和错误日志保留，不覆盖。
- **实际运行的是full_004**，session21364，日志full_004.log，复用full_002的完整放置，**只改route-seed 2→7**，placement seed11、hold500ps及全部时钟/约束/模型/固件不变。build_full新增显式--route-seed（默认2保留历史）并写inputs.json。冻结801源文件SHA全部匹配、placement_reused=true、route_seed7核对通过，脚本py_compile通过。11:12已进入路由，global某阶段归零后进入下一详细阶段1809连接；不算最终通过。
- 新板测等待队列`accept_final_retry.py --attempt 004`，session95255、pid28724，状态**final_retry_004.json**。新增attempt参数，默认002保持；旧002已退出。它仍只在full004最终门禁/位流SHA/manifest全部通过后启动final-board-001，截止不变。不要再看旧failed队列等它恢复，不要重复板测。
- 下一次11:23先读final_retry_004.json、full_004.log及implementation.log。若门禁通过，队列立即上板+UART模型上传/CRC/四fixture/相机检查；若再失败，保留019和完整交付素材，如实报告没有通过的新位流。当前未改板、未写TF、physical_full_application_verified=false。

## 11:31最新：004仍失败，利用最后窗口执行005针对性布线

- 本回合持续检查至004最终报告：详细布线已归零、hold修复完成，但11:29最终多角STA仍失败，Slow DDR→phy_dq_sysclk_1 setup -0.677ns、TNS-.878ns/2端点，hold无失败。说明route seed7比原2更差。004失败证据已归档optimization/overnight_020_full_004_failed_sta，004等待队列已failed退出，尚未生成/下载任何新位流。
- 已在剩余约30分钟内启动**full_005**，session31264：回到最接近通过的full002布局及route seed2，**只将hold目标500ps减为300ps**（仍保留正余量和全部最终多角门禁），目的减少hold修复额外绕线对仅40ps setup缺口的影响。没有改时钟/约束/RTL/模型/固件，复用放置，新目录不覆盖。日志full_005.log，11:31处于Routing。此实验可能失败，不能保证赶上板测。
- 等待队列`accept_final_retry.py --attempt 005`已启动，session9688、pid472，**final_retry_005.json**。仅新增attempt005选项，原默认保持；仍只在所有门禁/位流/模型身份通过后下载。截止UTC04:00后不启动板测新步骤。所有旧failed队列不再工作，避免重复启动。
- 下一次11:38优先读005状态/连接趋势，必要时持续短等待至最终结果及板测，避免11:53才处理失败。**不再启动第六次物理实现或新训练**，剩余时间用于本轮门禁、可行板测和最终交付/清单。未通过时保留019，不执行冒险下载。TF未写，远程物理观感/听感均未确认。

## 11:51最终技术结果：时序仍失败，新版本未上板；交付包已核验

- 本回合持续观察005至11:48最终多角STA：所有Setup通过，仅**Hold Summary(Slow Corner) DDR内部 -0.012ns/1端点**。因此full005及其板测队列均failed退出，没有生成新位流，所有自动上板队列已停止。没有JTAG新版本下载/UART新模型上传/板上CRC/四fixture/相机探针，final-board-001不存在，原019未改。不能将12ps忽略后声称上板完成。
- 失败证据独立归档`evidence/records/optimization/overnight_020_full_005_failed_sta/`，failure.json及最终rtr/资源/输入/日志齐全。全部四次真实布线的失败证据已复制进release/evidence；full003是PDS前的工具路径失败，不当作一轮成功或实际布线。
- 最终说明`docs/overnight-20261116/DELIVERY.md`、EVALUATION.md及release/README.md已更新，明确已完成软件训练/界面/语音与未完成新版本上板。**不再开新训练/第六次物理实现**；剩余时间只做交付和截止收尾。
- 候选交付包`project/trash_sorting/candidates/overnight_020/release/`共**943个清单负载文件、233920446字节**，新增docs、软件评估、训练记录/review ledger、复现工具、四轮失败最终STA/日志；`package_final.json`逐文件SHA/长度重新核验通过，状态CANDIDATE_DELIVERY_PHYSICAL_TIMING_FAILED_NOT_BOARD_PROGRAMMED。manifest自身SHA `fe6a9309263c10807883db431703ac55d0ec723caf476cbc4a4f07a19b591729`（负载不含manifest自身）。冻结801源码身份及TF待写MODEL.BIN身份再次通过。
- **该包不是可烧录发布，没有sbit/通过的manifest.json。** package_assets.json是准备时历史快照，以package_final.json/DELIVERY为最终状态。TF未实际写卡；截图为RTL仿真，音频是原神经MP3源，物理观感/听感未验。保留原019回退。
- 下一次11:53回合做最终状态核对并短等待至UTC04:00截止；12点关闭`fpga-15` heartbeat（用automation_update mode=delete，必要时先inspect工具）并确认防休眠进程已到期，**不要重启失败队列**。交付用户明确说明“训练及代码完成，但DDR最终Hold -0.012ns，新版未上板；原019保留”，给DELIVERY.md和release包链接，不称任务全部完成。截止后不再继续训练/构建检查。

### 11:54交付压缩包

已生成`project/trash_sorting/candidates/overnight_020/overnight_020_candidate_not_board_verified.zip`，172874544字节，SHA256 `7e120c26b7a3e5c6da8e1b81ee58ec498af2a2cfc4b18beb39b0e3ed31a148e0`。ZIP全条目CRC及943个manifest负载SHA逐项读取核验通过；旁边`overnight_020_candidate_zip.json`记身份。压缩包明确not_board_verified，不能视为新上板成功。原release和压缩包内容冻结，后续截止记录只写本PLAN，不改已封包文件使SHA漂移。

自动化配置确认fpga-15仍ACTIVE且UNTIL UTC04:00；所有构建/板测队列已failed停止，没有PDS后台。防休眠仍至04:00，显示器无需开启。本回合只短等待至截止后删除heartbeat并做最终交付通知，禁止重启任务。

## UTC04:00截止收尾完成

约定截止已到，未启动任何新训练/构建/板测。fpga-15已通过automation_update mode=delete确认deleted；防休眠状态active=false，released_utc=2026-11-16T04:00:14.334578+00:00，原进程29256已退出。原019及TF未改，更新候选未上板，最新失败原因仍为full005 Slow DDR内部Hold -0.012ns/1端点。

交付压缩包和943素材最终身份清单保持不变。后续工作需以DDR时序修复及完整板测为未完成项继续，不能将本轮目标标为全部达成。定期检查至此停止。

## 2026-11-16 UTC04:53 用户要求立即继续上板

用户重新明确要求立即上板，本次授权取代此前截止停止安排。正在运行full_006（复用full_002放置，route seed2，hold目标400ps），针对full005仅12ps hold缺口与full002仅40ps setup缺口取中间目标，未改变冻结RTL、时钟、约束、固件或stage4模型。

新增当前任务内执行链build/overnight_20261116/resumed_board_006.py（session69899），等待full006通过最终门禁后立即运行restore_full_board；逐项核对source_build、模型及位流SHA，不沿用旧UTC04:00截止。状态resumed_board_006.json，板测日志resumed_board_006.log，证据目录evidence/records/overnight-20261116/resumed-board-006。等待及板测期间保持系统不休眠，结束或失败自动释放（未要求显示器常亮）。COM34已枚举存在。release_resumed为新发布目录，不覆盖旧未上板交付包。

当前尚未下载新版；需等待最终STA和位流生成，之后JTAG、DEMO固件身份、UART模型CRC、四组数值fixture及相机推理全部核验。TF卡尚未改写，物理屏幕和声音观感仍不能远程声称已验。

### UTC05:09 最新执行：full008 是当前活动轮

full006最终STA仍是Slow hold -0.012ns/1端点，具体为ai/u_cdc/response_data[208]寄存器到u_rsp返回FIFO LUTRAM输入，属于ddrphy_sysclk同域数据路径，全部setup通过。失败证据已独立保留overnight_020_full_006_failed_sta，006板测队列failed退出，未改板。

专用clock-tree hold目标尝试250ps在full007启动PNR前被PDS拒绝：合法范围0～200ps。没有实际布线和板测；工具新增可追踪参数并将argparse合法值限制0～200，finalize-existing读取该轮记录或历史默认200。

实际活动轮为full008（session6122），复用full002布局、route seed3、通用hold400ps及clock-tree默认200ps，多角优化保持。日志full_008.log和full008/implementation.log。008自动上板队列session43313，状态resumed_board_008.json，等待通过门禁后执行resumed-board-008证据目录；006/007旧队列均停止，不会争用板。新目录release_resumed已复制885素材并对旧封包清单逐文件SHA核验，不代表位流/板测通过。继续当前任务直到新版本真正下载和模型验证。

### UTC05:14 双候选、单一下载进程

确认主机18逻辑核、32GB内存且约10GB空闲后，在独立目录启动full009（session45210，route seed4，其余同008），发布目录release_resumed_009。full008继续运行，没有重新启动它。第二候选用于缩短首次候选失败后的等待；不共享PDS输出目录。当前内存仍有约9GB余量。

已停止且核对身份的旧008等待进程2680（其状态waiting，尚未操作板），替换为**唯一**下载协调器resumed_board_candidates.py（session86986）。状态resumed_board_candidates.json，日志resumed_board_candidates.log；它轮询008/009，选择首个有通过manifest且模型/位流SHA/来源匹配的候选，只运行一次restore_full_board。证据目录以实际选中轮次resumed-board-008或009命名。候选均失败时停止写板并返回当前任务继续修复，不会冒用旧位流。防休眠由该唯一协调器保持并在终止时释放。

### UTC05:36 新版实验位流已经实际上板，模型上传中

full008最终仅Slow DDR输出setup -0.026ns，full009仅Slow DDR输出setup -0.123ns，均未通过；单一协调器已failed退出，没有冒用timing_pass。用户此前明确要求“不管有没有完成都先上板”，此次催促再次要求立即上板，因此执行可逆SRAM功能实验，**不再将通过正式门禁作为一切上板实验的前提**。正式发布/竞赛性能口径的严格时序门禁保持。新restore_full_board仅在显式--experimental-timing-failure且manifest同样标记experimental时允许此实验，并在板测result保留timing_pass=false；默认仍拒绝失败候选。

program_experimental_006.py（session41812）逐项重新核对full006冻结801文件、固件ROM、面积门禁及唯一Slow hold -0.012ns路径后，在原实现上补做首次位流生成（不重新PNR）。发布目录release_experimental_006，sbit SHA dbdb5944f9d77e83e86f0e1395ed71e4e7668af8498c01a91cc8f36a8cf59a83。JTAG实际program=1、即时与5秒状态081ffca0，DEMO固件UART身份均通过。**board_programmed=true；模型正在上传，尚未CRC/推理通过**。证据experimental-board-006，实时日志experimental_board_006.log。不能把该实验版称为时序合格稳定发布。

同时针对实际唯一hold路径启动full010：复用002布局和route seed2，额外施加通过response_data bit208的同域最小延迟0.400ns（高于原hold arc 0.228ns，属于更严格的数据路径要求，未改原时钟/周期/异步组）。新约束response_hold.fdc纳入输入SHA，工具记录response_hold_min_ns；需核对约束实际匹配和最终报告，不能仅凭加载即算修复。日志full_010.log，发布目录release_qualified_010。它不会自动争用正在进行的UART实验板测；通过后再顺序替换实验版。

### UTC05:47 实验版板测已经完成，板上实际运行新版

experimental-board-006/result.json确认board_programmed/model_loaded/model_crc_verified/camera_inference_pass/autonomous_started/autonomous_frame_received均true；四fixture（1/23/38/76）全部通过。新模型CRC32 dbe756f5，相机输入CRC一致，一次预热后三次真实相机探针均值1.7571821667秒。程序已退出并释放其防休眠，无剩余模型上传串口会话。该成功不等于时序闭合：timing_pass=false、experimental_timing_failure=true、physical_full_application_verified=false。自主帧仍有other低置信背景候选0.260，不能声称背景问题彻底解决；已确认的按键启停方案仍是控制路径。

release_experimental_006已补齐885素材、四fixture/板测证据/失败STA证据、最新复现工具及README，manifest记录当前实际下载SHA、板测result SHA、board_programmed=true/model_loaded=true/tf_card_written=false。当前是SRAM+UART至DDR，须保持板供电；原019回退和TF卡均未改。旧未上板ZIP仍为历史交付，不覆盖它。

full010还在布线。实验板测已经完成后，才启动唯一010等待队列resumed_board_010.py（session76243），只在严格最终门禁通过时替换当前实验版并重新做配套板测。该队列保持构建期间系统不休眠，成功或失败后释放；不存在并发串口消费者。若010约束未实际进入映射数据库，应如实记录、停止假设其已修复，不继续盲目重放相同布线。

### UTC05:59 最终：新版已上板并通过功能板测，正式时序仍未闭合

full010最终仍为同一AI返回FIFO路径Slow hold -0.012ns/1端点，全部setup通过，最终报告没有Set_Min_Delay例外路径。新增FDC在读取旧mapped ADF后注册，没有证明进入实际时序约束，不能算已完成针对性修复。失败资料已归档overnight_020_full_010_failed_sta。010等待进程failed退出并确认sleep_requirement_released=true，没有替换板上实验版；全部PDS/相关Python构建、板测进程均已退出，串口释放，无遗留自动烧录进程。

构建器已修正后续行为：response-hold-min-ns不能与reuse-placement组合，必须将严格最小延迟加入新camera.fdc再做device map；目标网络数必须为1且最终STA须有Set_Min_Delay例外报告，否则拒绝生成正式位流。py_compile及无副作用的非法组合拒绝检查通过；尚未运行新的完整映射构建，不能称严格路径修复已验证。

**当前板上是真实下载的006实验位流与stage4新模型，功能板测已通过、自主识别已启动。** 完成用户要求的先上板；时序合格正式版仍是后续未完成项，不冒称全部工程目标完成。用户可单击按键铃启停、双击切页。SRAM/DDR需保持供电，TF未写、未进行物理屏幕/音箱/机械动作目测验收。当前交付release_experimental_006及board_experimental_timing_failed.zip；原019回退不变。
