# 垃圾分类目标检测数据集 

## 目录结构

```text
new-trashcan/
├── images/
│   ├── train/
│   │   ├──00000x.jpg
│   └── val/
├── labels/
│   ├── train/
│   │   ├──00000x.txt
│   └── val/
├── dataset.py
└── README.md
```

## 数据集说明

- **标签格式**: 标准 YOLO 坐标格式 (`class_id x_center y_center width height`)
- **坐标归一化**: 坐标已被归一化，数值范围在 `0.0` 到 `1.0` 之间。

## 类别信息 (共12类)

| 类别ID | 标签名 | 中文名 | 总样本数 |
|---|---|---|---|
| 0 | bottle | 瓶子 | 294 |
| 1 | brick | 砖块 | 255 |
| 2 | battery | 电池 | 246 |
| 3 | can | 易拉罐 | 113 |
| 4 | carrot | 胡萝卜 | 183 |
| 5 | china | 陶瓷 | 252 |
| 6 | paperCup | 纸杯 | 143 |
| 7 | pill | 药丸 | 146 |
| 8 | potato | 土豆 | 158 |
| 9 | radish | 白萝卜 | 116 |
| 10 | stone | 石头 | 235 |
| 11 | potato_chip | 土豆片 | 113 |

## 快速使用

项目中提供了一个标准版的 `dataset.py`，可以直接作为 `torch.utils.data.Dataset` 的子类使用，便于挂载到 `DataLoader`。

```python
from dataset import TrashDataset
from torch.utils.data import DataLoader

# 初始化训练集与验证集
train_dataset = TrashDataset(root_dir='.', split='train')
val_dataset = TrashDataset(root_dir='.', split='val')

# 构建 DataLoader
train_loader = DataLoader(train_dataset, batch_size=16, shuffle=True)

# 获取一条数据
image, target = train_dataset[0]
print(target['boxes'])  # 目标检测框坐标
print(target['labels']) # 目标类别 ID
```

## 难样本 & 易混淆类别

在模型训练与推理过程中，请注意以下几组易混淆的类别（它们在视觉特征上具有较高的相似度）：
- **组 1**: 白萝卜 (radish) vs 碎瓷片 (china)
- **组 2**: 砖块 (brick) vs 石头 (stone) vs 土豆 (potato)

对于这些类别，如果模型容易出现混淆，建议尝试引入主动学习、难负样本挖掘或加大相关的 Focal Loss 权重。

## 进阶探索性数据分析 (EDA)

以下提供图片分辨率分布及各类别目标框尺寸的详尽统计

### 图片尺寸分布

| 分辨率 (宽x高) | 样本数量 |
|---|---|
| 640x640 | 1256 |
| 640x480 | 660 |
| 1280x960 | 305 |

### 目标框尺寸与比例分布

| 类别ID | 中文名 | 对角线长度(均值) | 对角线方差 | 宽高比例(均值) | 宽高比例方差 |
|---|---|---|---|---|---|
| 0 | 瓶子 | 390.05 | 30251.09 | 1.21 | 0.39 |
| 1 | 砖块 | 227.26 | 8985.53 | 1.14 | 0.14 |
| 2 | 电池 | 189.94 | 7269.92 | 1.12 | 0.43 |
| 3 | 易拉罐 | 447.56 | 17863.12 | 1.19 | 0.15 |
| 4 | 胡萝卜 | 140.57 | 828.49 | 1.04 | 0.07 |
| 5 | 陶瓷 | 213.49 | 26390.03 | 1.14 | 0.13 |
| 6 | 纸杯 | 379.63 | 24232.56 | 1.03 | 0.03 |
| 7 | 药丸 | 338.26 | 17688.94 | 1.11 | 0.09 |
| 8 | 土豆 | 188.47 | 1832.52 | 1.05 | 0.05 |
| 9 | 白萝卜 | 147.32 | 3278.39 | 1.05 | 0.07 |
| 10 | 石头 | 119.70 | 3730.38 | 1.06 | 0.07 |
| 11 | 土豆片 | 125.72 | 487.54 | 1.07 | 0.04 |

