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
| [MJU-Waste](https://github.com/realwecan/mju-waste) | 实验室手持物品的Kinect RGB-D数据，2,475对影像，单一垃圾类别，提供检测/分割标注。 | 需要补四桶语义类别和完整手框；不能直接按五类检测监督导入。 |
| [TrashBox](https://github.com/nikhilvenkatkumsetty/TrashBox) | README 宣称 17,785 张，混合 classification/detection 描述。 | 没有可复核的逐图检测框和分组证据前不纳入。名称/总量不能代替训练有效图统计。 |
| [WasteSense](https://www.kaggle.com/datasets/sumn2u/wastesense) | 实查 662 张图，标注为 polygon；README/摘要里“7500”是顶点/条目数量，不是图片数。 | 当前解析器尚未转换多边形，类别数序和纸/塑料政策也待复核；保留研究下载，不混进本轮训练。 |

## 后续定点适配期间补充核查（2026-11-18）

- [MatsB2002/battery-detection-yolov8](https://github.com/MatsB2002/battery-detection-yolov8) 的 README 指向 [public-ws/batteries](https://universe.roboflow.com/public-ws/batteries)，自述约1,000图、CC BY 4.0。原六个名称混有大小写和电池形态，作者合并为一个battery类，共2,697个实例。这些是项目自述，尚未实下载或标注审核，不能计入本项目训练数量。本机公开页面请求返回403；未尝试绕过，未获取导出包。
- [valken24/Battery-Detection-Yolov3](https://github.com/valken24/Battery-Detection-Yolov3) README自述约1,000自采图，Git完整文件树未见该电池图像及标签包，因此仅作方法参考，不能视为已取得数据。
- [boss4848/waste-detection](https://github.com/boss4848/waste-detection) 提供另一Roboflow垃圾数据引用，含battery与危险化学品等类；尚未审计原图、完整框和许可，不入训。
- [TrashMonkey](https://github.com/tr4m0ryp/TrashMonkey) 的公开来源融合方案包括Drinking、Garbage Detection、Household等，与本项目已调查源高度重叠。它将RealWaste留作跨来源测试，支持单独看跨域表现的做法；其README成绩不是本模型成绩，不作本模型验收证据。
- **修正上文MJU描述**：依据 [waste-datasets-review](https://github.com/AgaMiko/waste-datasets-review) 当前README，MJU-Waste是实验室中**人手持物品**的Kinect RGB-D数据，2,475对影像、所有垃圾为单一语义类别；不能称为传送带数据。原框/掩码可帮助物品定位，但本项目仍需要四桶类别和手的完整框，不能直接合并成五类训练集。
- 本次GitHub README及版本SHA、检索响应保存在 `build/quant_head_adapt_20261118_001/research`。Hugging Face公开API连接超时，未获得可核验候选。以上调查没有改变本轮冻结训练白名单。

### Q15尾部训练期间新增候选的文件核查

2026-11-18又通过Kaggle公开API检索电池、玻璃检测数据，元数据和实际ZIP中央目录保存在 `build/quant_tail_20261118_001/research`。没有将新来源加入已冻结的QAT训练，也没有打开上游test图片或逐图test标签。

| 候选 | 实际可复核结果 | 决定 |
|---|---|---|
| [Glass Clean/Dirty](https://www.kaggle.com/datasets/siddharthmagesh/glass-cleandirty-object-detection-dataset) | 元数据声称MIT、Clean/Dirty两类；实际ZIP有4,062个图片路径，data.yaml只有 `nc: 1`、`glass-VX4N`，Roboflow字段却写 `license: Private`。中央目录下载检查量约1.83MB，未下载完整263.5MB。 | 类别与许可来源均不一致，暂不入训，4,062不是本项目新增合格图片数。 |
| [Android phone battery](https://www.kaggle.com/datasets/lluckymun/android-phone-battery-dataset) | 元数据称124张CVAT电池框图，ZIP实际123个图片路径，三个job的data.yaml均只有battery一类。主要是手机内部电池，域与手持AA不同，元数据许可Unknown。 | 可作未来形态扩充候选，尚未做完整框/漏手、序列独立性和来源授权核查，不计入训练。仅检查ZIP目录与配置，约0.52MB。 |
| [Garbage Classification 12 classes](https://www.kaggle.com/datasets/mostafaabla/garbage-classification) | 元数据称15,150张12类图像分类，包含电池；作者明确说明大量网络搜图、与旧Garbage Classification部分重合，没有检测框证明。 | 不能直接作为目标检测GT，也不能与现有源简单累计为新增图片。 |

## 本轮数据实绩与限制

### 11:25新增真实AA电池小源与手持补框

- [Fetan-Love/AI-battery-detection-with-yolo](https://github.com/Fetan-Love/AI-battery-detection-with-yolo)固定Git树`7679a920e4dc919c50fdcc437a5ec63b82205cbc`。18张上游train原图/标签逐文件按GitblobSHA1、size与本地SHA256核验；没有请求val图片或标签。raw下载2对成功，16对网络失败，单次公开Gitblob接口恢复16对，原失败证据保留。
- 不是18张合格检测图：10张原标签为空，多个多电池图只有部分实例框。18原图和放大图都已目视审查，排除接触堆叠、边缘截断与近重，11张照片完全重标41电池框，两张最终叠框全看过。没有可见手，仍不是手持电池源。同一批次重复拍摄几节GP电池，独立实物数未知；根Unlicense已核验，未发现单独照片许可声明，manifest保留这一限制。
- [B11200044/YOLO-Battery-Detection](https://github.com/B11200044/YOLO-Battery-Detection)固定Git树`2f3e291772dbcf6a8c69a09e22a2c11dbf10d945`，248图片路径、303文本/XML等标签相关路径；data.yaml为round/box两类。未找到根LICENSE，没有下载图片/逐图标签，不计新训练数量。
- [Wissem-Sahli-Engineer/Recycling_Sorting_Computer_Vision_YOLO](https://github.com/Wissem-Sahli-Engineer/Recycling_Sorting_Computer_Vision_YOLO)固定Git树`eaf7d4ee0fa538654e2d11b0a5419ceeb7a07be6`，虽然仓库图片路径总数20847且README提及battery，实际检测data.yaml是Roboflow TACO派生18类，无battery；另有分类/结果资源，不能按20847张电池检测图理解。仅看元数据与配置，没有请求test图片/逐图标签，不下载重复TACO来凑数。
- MJU额外96候选视图审查后，增加4个明确的手持物体crop、4可回收框5手框；此前已有4crop，合计8派生训练视图。所有crop均完整标物体与可见手，按整源train组保留，和历史/旧crop核对SHA/pixel/pHash。它们不是8张新独立实拍。
- 11电池照片+8派生crop在11:24单独冻结最后一个固定1轮实验，等待前序全部完成，最晚11:35启动；运行与评估是否完成以实时state为准。没有改在途旧manifest，也没有用未训练图宣称准确率提升。

### 北京时间2026-11-18约08:00新增MJU可核验镜像

- 在GitHub查到`thanhlongqax/mju-waste-dataset`，固定Git tree/commit `b2c5ae89cc4f5f5ba6c5b61e47df873799ffc6fd`，非截断树包括2475RGB、2475分割mask及split清单。只取`ImageSets/Segmentation/train.txt`列出的1485项RGB与mask，未请求valid/test图片或mask内容。
- 镜像README与官方来源一致；另查到`dataset-ninja/mju-waste`的LICENSE.md和DOWNLOAD.md。原作者`realwecan/mju-waste/master/LICENSE`实际请求成功，为2020TaoWang的MIT许可；原文保存`licence_check_LICENSE.json`，使用时保留归属和论文引用。
- 每个文件按镜像Git树的字节数与Git blobSHA1核验，另存SHA256；下载不等于五类训练准入。样例是实际实验室多人手持垃圾，具有更匹配的手/物场景；源mask只有单一waste类别，仍须逐图补四桶语义、所有可见手与完整物体框。
- 上游随机split含同物多视角，1485文件不能当1485个独立实物。只用上游train、整源保留train组；需要对本项目既有train/dev/test身份元数据去重，不能随机抽相邻帧作为独立新dev。
- 来源获取及后续审查在`build/noon_continuation_20261118_001/research/handheld_mirrors_001`。此前Drive链接连接失败记录保留；本次找到公开镜像，没有重试或绕过原失败服务。

### 后续电池项目原文件核查

证据位于 `build/quant_tail_20261118_001/research/battery_references_002`，未增加训练图片。

- [zzmice/yolov3_battery](https://github.com/zzmice/yolov3_battery)：README实际在嵌套目录，明确说“不提供训练数据集与训练文件”；不能把已训练权重和示例当新GT。
- [share2code99/battery_detection_yolov8](https://github.com/share2code99/battery_detection_yolov8)：README声称超过10,000图，但公开Git树仅21张图片路径、0个txt/xml/json标注路径，并指向外部文档领取数据；尚无可审计训练包，不计数量。
- [prabindh/ctsoc-ewaste](https://github.com/prabindh/ctsoc-ewaste)：README声称990张原始图、增强后2376，包含battery等7类，来源混合Kaggle与Google搜图，外链Google Drive；公开仓库57张图片路径是说明/结果等资源，0个txt/xml/json标注路径。本机Drive连接超时，未取得包。根README的693:198:99和dataset/README的636:128:91也不一致，后者总和不等于其声称990；若以后取得包，需重建原图身份、完整框和split，不能按文档比例或增强总量直接接入。

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
