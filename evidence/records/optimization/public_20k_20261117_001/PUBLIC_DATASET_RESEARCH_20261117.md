# 垃圾检测公开数据集调查（2026-11-17）

## 任务口径

当前 FPGA 模型运行目标检测：每个框只输出五类之一 `[kitchen, recyclable, hazardous, other, hand]`。因此图像分类集不能当检测标注使用；把整张图框成一个物体会制造错误框。公开源还必须核对物品政策、同图多物是否完整标注、split/原物体隔离、与旧图重合和许可证。

本轮研究目录为 `build/public_20k_20261117_001`。来源检索包含 Kaggle metadata/文件树与 GitHub 项目 README，实下载、哈希校验与标注抽检的数据源均保留了归档和索引。

## 参考项目与本次决定

| 来源 | 项目自述 / 实查 | 对当前任务的适配 |
|---|---|---|
| [Detect Waste](https://github.com/wimlds-trojmiasto/detect-waste) | README 明确列出 9 个上游项目，包括 Drinking Waste Classification、TACO、TrashNet、MJU-Waste、UAVVaste、TrashCan 和街景数据。它说明多数据源检测融合是一种已有路线，不等于这些源同分布或标签可直接互换。 | Drinking 是检测格式、域偏近白/清洁单物体；适合补瓶罐外观，不能代表摄像头分类现场。 |
| [Drinking Waste Classification](https://www.kaggle.com/datasets/arkadiyhacks/drinking-waste-classification) | Kaggle v2 自述用 YOLO 标注；原 `YOLO_imgs` 实际有 4,821 张图片，清理坏图后 4,724。该作品组合并感谢 TrashNet；大量 raw 图与框图重复，因此 rawimgs 没有另算新图。数据源许可自述 CC0，需保留来源归属说明。 | 已纳入 3,626 train + 609 分组 dev；物件类别统一至 recyclable。白底和同件多视角相邻，无法用普通随机分图证明实物级独立。 |
| [WaRP](https://github.com/AIRI-Institute/WaRP) / [Kaggle](https://www.kaggle.com/datasets/parohod/warp-waste-recycling-plant-dataset) | 论文数据来自真实回收线；综述列 2,974 检测图、10,406 个分类 crop、112 分割图。检测标签框质量较好，但传送带上很多共现垃圾没有同时框全。 | 已下载审查；不把漏标共现物当背景或无目标监督，故未纳入。可按完整标注子集逐图人工补标后再考虑。 |
| [TrashNet](https://github.com/garythung/trashnet) | 2,527 张单物体白底照片、6 类图像分类。 | 适合分类预训练或按项目规则框图，但对现场检测增益有限；本轮还通过 Drinking 导入了部分其上游影像，不能重复计数。 |
| [Garbage Classification v2](https://www.kaggle.com/datasets/sumn2u/garbage-classification-v2) 和 bbox 派生版 | 原版 10 类图像分类；bbox 派生版 8,162 张左右、七类 YOLO 框。Kaggle 元数据列出的类名次序与文件标签数字顺序不一致，已按实际文件夹和框审计纠正。玻璃、金属、生物垃圾部分框可用；paper/cardboard 类含政策冲突的纸杯。 | 最终纳入 1,106 train + 103 dev，只用金属、玻璃、生物垃圾类，并排除纸杯歧义、重复、手与明显错标。该整理源声明 CC BY 4.0；原分类源声明 MIT。 |
| [SWiM3](https://github.com/Burhan-Ahmed/SWiM3-Dataset) | README 声称 6,429 张手机实拍检测图；实查公开 split 目录有 6,363 个路径，其中 3,253 个文件名含 `_augN`。按 stem 移除增强编号和 Roboflow `.rf` 哈希后，得 3,847 个 canonical stem，其中 704 组出现在多个 train/valid/test split。还发现 `classes.txt` 有 10 类，而 `data.yaml` 的 `nc` 与 `names` 只有 3 类。目录层面的 `Dataset/Images` 另有 6,363 张，不能再与 split 文件重复相加。 | 暂不纳入本轮。标签数序和 split manifest 均有直接矛盾；另有研究/教育用途限制。需按原图重建 canonical 实例、修正每框类别、逐实例整体隔离，并重新核查许可后再考虑。数字来自 Git tree、`classes.txt` 与 `data.yaml`，测试图片和标签内容没有读取。 |
| [codingBearHsun/trash-sort](https://www.kaggle.com/datasets/codingbearhsun/trash-sort) | 2,221 张宣称带 YOLO 框，中国垃圾桶/箱体场景。标签含砖、陶瓷、纸杯、药丸、食品、石块等，须按本项目四桶政策逐类决定。许可 CC BY-NC-SA 4.0。 | 与旧项目曾用的 codingbear 来源重合；严排旧 source identity 后留下 335 张；标注检查又排除两张石块被同时标为 hazardous 和 other 的冲突图，最终增加 333 train。按整次拍摄组分区；不能把剩余源标签称为逐图人工 gold。 |
| [Battery/dice/toy-car detection](https://www.kaggle.com/datasets/markcsizmadia/object-detection-batteries-dices-and-toy-cars) | 1,425 左右 KITTI 目标框图片；不等同于只含电池的数据。 | 与旧电池来源高度重叠，历史 SHA/source 与手筛后只留下 5 张，几乎不能改善用户指出的电池漏识。 |
| [HaGRID](https://github.com/hukenovs/hagrid) | 大规模手势/手掌检测集，按用户/参与者提供分组；其专用协议优先于代码仓库许可说明。 | 适合作 hand 类正样本，并可按 subject 隔离；但仅手势类不能代表“手持电池时手与电池同时检测”，且背景空标签需审核。 |
| [TACO](https://github.com/pedropro/TACO) | 约 1,500 张街景垃圾图，COCO 框/分割类别丰富。 | 可帮助包装垃圾和自然背景；图像规模有限，类别映射与未标注共现物必须逐图处理，不保证近摄透明玻璃/电池。 |
| [MJU-Waste](https://github.com/realwecan/mju-waste) | 传送带单物前景图，有助于物料外观；分类/分割定义与本项目不完全一样。 | 需要按当前四桶策略映射及检查多个物体完整标注；域差异显著。 |
| [TrashBox](https://github.com/nikhilvenkatkumsetty/TrashBox) | README 宣称 17,785 张，混合 classification/detection 描述。 | 没有可复核的逐图检测框和分组证据前不纳入。名称/总量不能代替训练有效图统计。 |
| [WasteSense](https://www.kaggle.com/datasets/sumn2u/wastesense) | 实查 662 张图，标注为 polygon；README/摘要里“7500”是顶点/条目数量，不是图片数。 | 当前解析器尚未转换多边形，类别数序和纸/塑料政策也待复核；保留研究下载，不混进本轮训练。 |

## 本轮数据实绩与限制

- 筛查多个 Kaggle 项目：下载约 10 个来源并记录 ZIP SHA/ETag/CRC、文件树、标签映射和抽样可视化。广告/网络图、分类专用、弱框、漏标、同源近重复、手部嫌疑及物品政策冲突源均不为了凑数而硬加。
- 原最新清洗白名单完整保留：3,275 条 train row，2,834 个文件 SHA 身份。最终添加 5,070 张来源新训练图及 712 张组隔离公开 dev。按文件 SHA 总计 7,904 个 train 身份；不将 alias、重复采样或增强计作新图。
- 新数据每轮 12,662 个采样 draw；其中 4,317 个是用 hardlink 的显式回放别名，目的是绕开 YOLOv5 标签 cache 按路径去重。这是采样比例，不是 12,662 张独立图。
- Drinking、bbox 派生集、箱体实拍、少数电池目标框进入冻结集。大量 drinking 是瓶罐，因此全量 replay 厨余、other、hazardous、hand 以防遗忘；即使如此，电池的新独立候选只有 5 张。需要更多真实电池、玻璃、手持物和摄像头空场背景。
- 训练标注来自来源标签、格式/坐标校验、分层人工抽检、旧模型未标手筛查和冲突框审计，不是对所有 5,070 张逐一人工验真。palm detector 与当前 teacher 都可能漏手。
- 公开 dev 仅作为本轮调研域的开发诊断，不参与训练；旧 test split 既不打开也不调参。
- 用户的 20,000 张目标按独立、可用图口径未达到。找到的“大数据分类集”大多不带目标框或与当前手持/投放分布相差很大。重复增强、瓦片裁剪、raw 同源图不得包装成新增独立图片。

## 数据来源和标签局限如何继续解决

高价值补充不是再抓大量白底瓶图，而是按同一台摄像头和实际投放工位采集分组数据：多个电池形态/极性/遮挡，透明空玻璃与不同瓶色，空场景和反光背景，手持物品同时对物品与手框标注。每个实物、视频连续帧或同一次拍摄需作为一个 group 隔离 train/dev。背景帧用独立 reviewed-empty 清单和固定哈希，防止误把有遗漏物品的照片变成 hard negative。这样补齐数据定义比把瓦片/增强图扩到 20,000 更能解释目标摄像头的实际结果。

论文和代码项目多不代表图片许可自动开放。训练档案保留 Kaggle 元数据的 license 声明、README 与 URL；在对外发布权重、图像或商业使用前，还需逐源确认上游许可和数据集条款。
