# 自采数据与重训入口

> **2026-11-13当前状态更新：板上已安装092手部过滤实验版，实际下载证据093。** 配套五类模型CRC/手类数值/自动识别通过，手部和电池准确性仍待现场验证。当前入口见[仓库交接说明](../../../docs/HANDOFF.md)；以下原文保留历史阶段说明，其中“当前062、手模型未下载”等描述已被本次092替代。


2026-11-13最新状态以`docs/verification/trash-night-final-20261113.md`为准：单目标/锁题与局部O2已配套54MHz位流实际下载，恢复包`../bitstream/full_54mhz_20261113/`，100空输出帧平均1.705371秒。所有新手定位模型未通过效果门禁，保留原四桶权重；手持电池最终留出0/11、清晰全角度主体且红桶1/15，不能称手部优化成功。下文2026-11-12的“未下载”描述为历史阶段。`evaluate_final_battery.py`是绑定冻结身份/时间的一次最终测试入口；`evaluate_quantized_hand_policy.py evaluate --classes 4`可显式按无手四类评分开发val，不再把五类编号套进原模型。

2026-11-11完成四桶模型24轮重训：公开带框数据已下载、抽查并审计，保留1795张训练、1508张验证、1572张测试。直接输出厨余/可回收/有害/其他，纸板和纸张同归可回收。同条件公共测试mAP50为77.0%（旧21.1%），仍有误框。权重与署名在`candidates/four_bins_20261111/`；来源、许可和限制见仓库`docs/verification/trash-retraining-20261111.md`。下载、清洗分组、训练和评测脚本为`download_four_bins.py`、`prepare_four_bins.py`、`train_four_bins.py`，固定类别映射见`classes_4_retrain.yaml`。

上述四桶checkpoint已量化并部署到54 MHz版本，板载位流SHA `d1658824…`、模型blob SHA `ea70896c…`。启动/数值与空场10帧平均1.790597秒已测，现场实物准确性与整轮问答需分开验收。部署证据以仓库`docs/verification/trash-four-bin-deployment-20261112.md`为准，恢复包在`diagnostics/four_bins_54mhz/`。当前用户要求先改代码、最后统一布线，本轮单目标/手部定位代码没有下载。

- `classes_4_retrain.yaml`：活动四桶模型定义，0厨余、1可回收、2有害、3其他。
- 内部手部定位候选由`prepare_hand_game.py`生成data.yaml，在四桶后追加ID4 hand；**不是第五个桶**。008已离线训练、量化与C算术核对，但个人电池指标下降，标记为未选作部署，见`candidates/four_bins_hand_game_008/`。
- 新增手持实拍由`prepare_real_hand_game.py`按实物分组准备；重复`--reviewed-public-hands`可合并不同公开来源的人工手框审查，保留原垃圾框并校验图像身份/尺寸/划分。`evaluate_hand_branch.py --joint-model --target-policy contact`评估当前候选相机C接触关联；默认`roi`仅供历史可比实验。公共四桶同口径回放对nc=4也需`--deployment-decode`。训练完成不等于允许替换板载模型，状态见仓库`docs/verification/trash-single-target-hand-game-20261112.md`。
- `prepare_real_hand_game.py --reviewed-train-exclusions`只接收逐图审查的公开train歧义排除表，必须匹配SHA、来源、实物组，禁止排除val/test。031清理三张battery/stone同框矛盾标注，未重标为其他类别，原val/test字节和标签完整保留。
- `train_four_bins.py --preserve-teacher ... --expected-teacher-sha256 ... --preservation-strength 5`启用训练专用四桶约束；只用真实垃圾标签中教师正确的匹配锚点，保留普通五类监督，不蒸馏手/背景误报。教师不进入验证、checkpoint或部署图；每轮记录各桶匹配数及实际训练batch调用，计数0报错。029从原四桶公共参数初始化未学会真实手持手部，已拒绝，不能以电池恢复8/9宣称完整候选通过。
- 当前相机`contact`规则按有效手框的同帧平均面积区分大小：小物品要求主要在扩展手ROI内，大物品不要求ROI包含，输出完整物品框，仍需接触关联。无手保持最大物体。版本及源码SHA必须随回放/固件一起记录，不用历史同名策略的成绩替代当前版本。
- `prepare_backbone_hand.py`准备034早期特征实验：冻结原四桶0～23，手支读取4/6/9，对照035读取17/20/23；评估器支持并逐图核对两种共享路径，必须与独立hand前向和原垃圾输出一致。两组虽保持原输出，手定位未达标，均拒绝部署。`replay_contact_policy.py --hand-confidence`只允许对独立手分支保存预测作不低于原推理阈值的过滤，禁止对joint候选或比已存底线更低阈值“补出”框。阈值回放与独立.05/.25端点逐图核对；结果不用于声称新test或FPGA速度。
- `classes_5.yaml`与`classes_7_proposed.yaml`保留旧物品类别提案，不适用于四桶或四桶加hand模型。
- 现有模型/数据集来源、候选数据比较和拍摄计划见仓库 `docs/verification/trash-training-plan.md`。

建议用CVAT矩形框标注并导出YOLO检测格式，每行 `class_id x_center y_center width height`，坐标归一化至0～1。分类文件夹标签不能代替目标框。纸箱/干净纸张标1，可见电池/应判有害的药品标2，用过的纸巾标3，果皮等厨余标0。四桶训练只框垃圾；若训练内部hand模型，还必须框出所有可见手并标4，空手图也有hand标签。空桌面等确定没有任何目标的图片才用空标签。不要把人和物品合成一个大框；手持场景须同时标手、主体物品，单独保留接触关系用于关联规则验证。

按物品实例和拍摄场次分组后划分train/val/test，建议70/15/15；同一实物换角度的照片、同一视频的相邻帧及其增强图放同一分组。验证和测试不做重复增强。保留独立的板载摄像头测试集，按类统计Precision/Recall/AP及错误开桶次数。

先用各类200～500张有变化的实拍图作起点，每类尽量覆盖10～20个不同实物；这只是采集建议，不保证准确率。再按实际混淆补拍，而不是无限复制同一物品。增加空场景及容易混淆的非目标物。训练/验证/测试要覆盖每个目标类。

训练在电脑/GPU上微调YOLOv5n，保持320输入。固定上游版本、类别顺序、数据划分和预处理。导出/量化、CPU头、解码、编译与冻结门禁现已支持四桶27通道及四桶加hand30通道，两者填充32通道；不能仅修改类别数。`propose_training_hands.py`只提出候选，须逐张检查，不自动生成标签。`train_four_bins.py --evaluate`支持四桶及内部hand的固定320评估；五类按部署单anchor一类/NMS .45/max32验证。分别评测浮点、量化+C和FPGA；未通过实测不报告2秒或识别准确率达标。当前只进行代码和离线验证。
