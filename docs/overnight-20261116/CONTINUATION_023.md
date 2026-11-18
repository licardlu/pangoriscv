# 023 实时跑分与识别反馈

## 状态

023 是独立候选快照，尚未安装到板上。按用户最新要求，本阶段只改代码、训练和验证，不做布局布线、不下载位流、不写 TF/Flash。板上继续运行此前的 022；候选源位于 `project/trash_sorting/candidates/continuation_023/source`。

当前完整冻结版为 `evidence/records/optimization/continuation_023_night_review_003`（804文件）。其 `benchmark_page.sv` 已限制仅在跑分页接收KEY1跨域边沿，退出后的迟到边沿不再为重入页面保留请求。最新联合控制路径证据为 `evidence/records/optimization/continuation_023_session_review_001`：真实按键消抖、页面路由、问答、PWM舵机反馈、语音解码/发送及像素切页共同仿真，三组时钟比例/相位均通过；冻结源SHA一致。测试加速了按键时间与帧周期，没有执行CPU工作负载，不代替现场声音、显示、物理时序及跑分验收。

## 跑分与页面

- 双击 KEY0 的页面导航带约 18 帧淡入过渡；单击 KEY0 开关识别，KEY0 双击进入跑分页/动画页。跑分页不自动启动。
- KEY1 仅提交请求。固件等跑分页实际显示、语音提示播放完后，在主循环安全点暂停媒体服务并运行官方 CoreMark v1.0，结束后恢复原媒体状态。
- 配置 5000 次迭代，54 MHz，显示实测周期与 CoreMark/MHz；只在五项 CRC 全通过且运行不少于 10 秒时显示有效结果，不把动画或随机数冒充实测成绩。
- 去掉页首“性能跑分”，模式标为 CoreMark。1280×720 实际 RTL 画布渲染完整。实时 C UI 主机测试验证 KEY1 手动启动、页面/语音等待、媒体暂停恢复、结果不钳位至旧演示值及 CRC 失败隐藏分数。
- 验证：`build/continuation_023_dashboard_verified_004`；131 个 RTL 文件顶层展开无警告见 `build/continuation_023_interfaces_002/result.json`；导航/动画仿真见 `build/continuation_023_rtl_003/checks.log`。CoreMark 官方 workload 与五个 CRC 的主机测试见 `build/continuation_023_native_002/coremark_run.log`，它不是 FPGA 成绩。

## 识别反馈训练

根据用户报告的电池、玻璃、手和杂乱背景错误，整理已审核框标注的训练续训快照 `build/continuation_023_dataset_001`（3275 train、1929 val；保留集不参加训练）。当前来源含公开垃圾照片、个人采集、手部与空背景样本。第二轮保守续训以 stage4 原权重为起点，冻结前 10 层与 BN，3 epoch、320 输入、CPU、低学习率；checkpoint SHA256 `8a0aa1607048c02499b9a426655e788e50f4c81f51779cd081a9b51287248fa2`。

第一轮激进续训已拒绝：量化 Q15/C 回放在原 1929 张从 1452 降为 1442 张分类与 IoU 同时正确，空背景误选从 11/136 增至 17/136，电池子集没有改善。第二轮浮点验证 mAP50 为 0.72813；该单项指标不足以批准换模。第二轮模型已完成 85 个算子图一致检查、160 张 train-only 校准和打包（blob SHA256 `9150bd0dee1f7c3b294ad13307faa53c5e4fdd73a9183a4f641666f0a591bc61`），但定点全量回放为 1429/1929、空背景误选 26/136，仍拒绝替换 stage4。玻璃分组为 229/242，手部检测 TP/FP 为 247/100。

所有上述识别统计均是软件定点卷积 oracle + C 检测头/解码器/候选选择策略的回放，不是摄像头现场准确率，也不是板载推理成绩。第一轮实测细节见 `build/continuation_023_numeric_score_original_002/result.json` 与 `build/continuation_023_numeric_score_new_001/result.json`；第二轮见 `build/continuation_023_numeric_score_conservative_original_001/result.json`。

## 策略对照

对保存的 stage4 检测输出做了独立策略回放。未检测到手时，垃圾候选最低置信度从 0.25 调到 0.30，空背景误选为 8/136（原策略 11/136），全量正确为 1449/1929（原策略 1452/1929）；0.40 及以上继续损失目标。因此源码候选仅在无手场景使用 0.30，手持接触策略保持原阈值。实际源码复测见 `build/continuation_023_numeric_score_threshold_007/result.json`；新增验证集为 55/77，见 `build/continuation_023_numeric_score_threshold_new_007/result.json`，与原策略一致。目标选择与手部接触回归均通过。该策略只过滤低置信度候选，不能代替双目标定、距离门控或现场验收。

## 暂未验收

- 实体屏幕上的动画手感、KEY 操作及声音尚需用户现场确认；仿真不能代替面板观感。
- 真实 CoreMark 分值尚未在板上采集；源码与主机测试通过不能代替板测。
- 新识别模型只有完成定点对照后才可能替换；即使软件回放改善，也需用户批准后布局布线和下载，再用现场电池/玻璃/手/杂乱背景样本验收。
- 双目距离门控仍需相机几何/曝光同步、实拍标定和距离误差验证；单目背景误触发不能仅以“20 cm”阈值保证解决。

## 2026-11-17 后续检查

- 保持stage4模型：与保守微调权重做统一原/新校准四格对照后，stage4×原校准为1455/1929，空背景误选8/136；保守微调最优1443/1929。原/新两校准图只交集11/160，说明校准本身会改变空背景结果。stage4固定160张校准重建的model.bin SHA与原部署逐字节一致。
- 接触关联只对score≥0.60、长短边≥2、距手框每轴边界≤手框边长10%的细长物豁免ROI/最小交叠；开发val全量正确1455/1929，玻璃232/242，个人电池55/60，空背景误选8/136。新增77张56/77，新增手持电池23/29；仍有较多空背景误选与battery recall损失，板上是否改善必须重测。
- 相机游戏识别需要两帧同类且IoU≥0.25才触发；触发后两次成功无目标推理才重置。导航、推理错误及测距未知不会作为目标离开；OSD超时不会发布尝试态。`native_feedback_003`8项主机回归通过，新增门控多一轮推理延迟；稳定误检依然可能触发。
- `firmware_transactional_gate_002` 66060字节，`stack_transactional_gate_001`静态保守调用链6128字节、余量2336字节。训练子集身份/标签SHA及声明分组隔离通过；pHash近邻清单见`build/tonight_20261117/subset_audit_005`，无需据相似背景自动移动数据。
- 用户尚未批准布局布线或本候选上板，本轮仍未做PDS实现、未下载、未写TF/Flash。跑分数字只有等获准上板并实际通过五项官方CRC及≥10秒计时才成立。

最新电脑候选为 `build/tonight_20261117/firmware_final_003`：66060 bytes，firmware SHA256 `d41aee044e21d5970c9493b98527a19bac32fd6493b28b7adc48423ebb888bca`。已把配套八lane ROM及manifest更新到023源树，逐源SHA、模型、RAM反交织校验通过；这里构建器的`installed=true`只表示电脑候选ROM已更新，`board_programmed=false`，没有下载到硬件。

`native_final_005`八项主机回归通过，包含第二次命中/第二次空结果时OSD超时不发布门控状态、CoreMark五CRC、已知ticks单位与频率归一化、无效输入隐藏分数；`interfaces_final_001`完成顶层接口展开。`stack_final_001`可用8464 bytes、保守调用链6128 bytes、余量2336 bytes；不等于运行时栈水位实测。旧64736-byte记录只属历史候选。

默认双目标定仍未验证，完整标定路径不会启用；此前强制保留全部双目路径的尺寸实验未通过栈门禁，不能据默认构建通过声称完整双目已可部署。本轮没有布局布线和下载。

完整冻结源及证据在`evidence/records/optimization/continuation_023_night_review_001`，804个文件，含当前电脑ROM，便于后续批准后复现；当前不提供新位流。原有语音清单已补充当前14段ROM及六条新增反馈，`audio_final_001`解码/路由复测通过，现场听感仍未验收。

最新提交占用边界修订已另外冻结到`evidence/records/optimization/continuation_023_night_review_002`，后续以002为准。固件66104 bytes、SHA `81af6783504698d8d4bd6bd42ddd4f69f7a2c53de6fc34c5de1fcee23c9c7ca4`，源码/ROM一致。`native_ownership_006`八项主机回归通过；`stack_ownership_002`可用8424、保守调用链6128、余量2296 bytes。提交前后检查既有RTL占用状态，发生导航/题目占用或清理时取消，不消耗门控；没有增加RTL和硬件ack，最后读取与实际写提交之间的异步窗口仍需后续评估。

开发集近邻敏感性：剔除全部46张pHash标记val后，剩1883图中有物品1747、背景136。stage4原校准正确主体1413/1747、背景误选8/136；保守原校准1401/1747、背景误选9/136。保持旧权重结论没有改变。这仍是反复开发使用过的val软件回放，不能叫独立测试或现场准确率。完整标定尺寸实验`allpaths_final_001`再次被8KiB栈门禁拦住，未纳入可部署快照。

05:04修复实际RTL的迟到按键请求边界：`benchmark_page.sv`仅在已同步跑分页有效时接收物理KEY1启动边沿；退出后到达的边沿仍被消费，但不能留下请求在重新进入时自动执行。新增`tb_benchmark_navigation_boundary`在旧源复现失败，在修改后验证迟到键丢弃、重新进入需新键、运行中键不排队。`rtl_benchmark_boundary_002`七项仿真、`interfaces_benchmark_boundary_002`顶层接口展开及`dashboard_boundary_005`实际画布渲染通过；渲染PNG与之前逐字节一致。仅改1个RTL组合使能条件，无CPU/模型/ROM变化，因此66104字节固件及已有栈/native证据继续适用，未重复编译CPU。最新完整源冻结为`evidence/records/optimization/continuation_023_night_review_003`，后续以003为准，002保留。仍没有实现面积/时序或板测，面积中性目标需未来实测。
