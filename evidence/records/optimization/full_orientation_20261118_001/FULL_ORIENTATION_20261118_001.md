# full_orientation_20261118_001 固定最终轮监督微调结果

仅离线训练、导出和开发评估；未综合、布局布线、串口访问或上板，最终test图片和标签未读取。

## 事前冻结方案

Tail-only QAT improves some public/negative examples but loses hand-held battery and glass. Allow the supervised feature hierarchy above block4 to adapt to the already reviewed orientation/background training data, instead of relying on static cached features. This is one fixed final-epoch continuation, not a learning-rate/threshold/epoch search.

初始化SHA `a4a0b1b04f83af1d114813e0512dd2c2fa5e7306fae16759824f136b3133021a`；冻结前4个模块与其BN，其余特征层进行监督微调。AdamW、初始学习率0.0001，固定10轮最终last.pt，没有中途验证选轮次或早停。
7904 previous train identities +40 new source photos +14 derived empty crops +376 derived rotations. 8334 includes derived views; 13630 includes replay draws. Neither is a count of independent objects.

训练后只用事前冻结的160张当前train图片校准一次。此实验改变特征和量化参数，不能表述为骨干或激活尺度全冻结的尾部QAT。

## 同一C选择器与相同阈值的Q15结果

| 指标 | 原部署 | 本次Q15 |
|---|---:|---:|
| 主体类别与IoU正确 /1793 | 1455 | 1457 |
| 无垃圾/空手误选 /136，越低越好 | 8 | 4 |
| 个人电池 /60 | 55 | 49 |
| 公开玻璃 /242 | 232 | 235 |

| 类别 | TP原→本次 | Precision原→本次 | 无退化通过 |
|---|---:|---:|---|
| kitchen | 221→213 | 0.626→0.674 | False |
| recyclable | 1376→1382 | 0.800→0.821 | True |
| hazardous | 150→145 | 0.652→0.755 | False |
| other | 169→163 | 0.413→0.414 | False |
| hand | 234→292 | 0.720→0.702 | False |

712张公开dev主体正确：271→700。
77张手持开发图主体正确：56→66；新增正确11，新增错误1。

## 结论与适用范围

未通过全部预定无退化门槛，拒绝替换现用模型。
固定门槛：`{'float': True, 'q15_primary': False, 'q15_all_waste_classes': False, 'q15_all_detection_classes': False, 'q15_publicdev': True}`。
浮点分项：`{'correct_positive': 1461, 'false_background': 3, 'correct_personal_battery': 56, 'correct_public_glass': 237, 'denominators': {'positive': 1793, 'background': 136, 'personal_battery': 60, 'public_glass': 242}}`。
训练7683.9秒，最终权重SHA `64e8bcd12b3adc53b2f051b15b6cd091a0f6f8b685d19aac573ae46eaf26ae75`。

旧val和公开dev已用于开发，均不代表独立最终测试或现场效果。公开dev缺有害/其他/手和空场GT；77图缺厨余。空手指标不能证明无人复杂背景无误报。旋转图和重复draw不能计作独立新照片。
