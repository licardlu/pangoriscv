# 识别覆盖与逐来源开发验证

这里只分析固定开发验证集已有预测，不增加验证图片、不调阈值，不读取最终测试图片或标签。文件SHA数量不是实物数量；来源文件夹不能证明现场识别质量。

训练文件身份：8597。按已标注框，纯空场景 24；仅手无垃圾 287；手与垃圾同时出现 1306。

| 训练类别 | 有该类的独立文件 | 框数 |
|---|---:|---:|
| kitchen | 450 | 692 |
| recyclable | 5589 | 6591 |
| hazardous | 1758 | 2369 |
| other | 563 | 709 |
| hand | 1593 | 1601 |

| 验证来源/场景 | 有物/无物 | 原部署正确/误选 | QAT正确/误选 | QAT新增正确/新增错误 |
|---|---:|---:|---:|---:|
| all | 1793/136 | 1455/8 | 1459/8 | 24/20 |
| hand_without_waste | 0/136 | 0/8 | 0/8 | 0/0 |
| has_waste | 1793/0 | 1455/0 | 1459/0 | 24/20 |
| no_waste | 0/136 | 0/8 | 0/8 | 0/0 |
| source/codingbear | 287/0 | 244/0 | 249/0 | 7/2 |
| source/hagrid_hand_localisation | 0/29 | 0/1 | 0/1 | 0/0 |
| source/mark_battery | 51/0 | 27/0 | 27/0 | 1/1 |
| source/personal_塑料片 | 28/0 | 19/0 | 18/0 | 0/1 |
| source/personal_电池 | 60/0 | 55/0 | 54/0 | 0/1 |
| source/personal_空手 | 0/107 | 0/7 | 0/7 | 0/0 |
| source/personal_纸团 | 146/0 | 54/0 | 56/0 | 5/3 |
| source/sumn2u | 1221/0 | 1056/0 | 1055/0 | 11/12 |
| source_folder/sumn2u/biological | 105/0 | 81/0 | 82/0 | 1/0 |
| source_folder/sumn2u/cardboard | 203/0 | 179/0 | 179/0 | 2/2 |
| source_folder/sumn2u/glass | 242/0 | 232/0 | 232/0 | 1/1 |
| source_folder/sumn2u/metal | 144/0 | 133/0 | 133/0 | 0/0 |
| source_folder/sumn2u/paper | 231/0 | 183/0 | 180/0 | 3/6 |
| source_folder/sumn2u/plastic | 228/0 | 210/0 | 210/0 | 1/1 |
| source_folder/sumn2u/trash | 68/0 | 38/0 | 39/0 | 3/2 |
| waste_with_hand | 234/0 | 128/0 | 128/0 | 5/5 |

正确指主体类别与标注匹配且IoU≥0.5；误选仅统计无垃圾图片。增益和退步是同图配对，不能用净增益掩盖具体退步。空手集没有证明复杂无人背景覆盖；不存在的现场验证类别也不能由同桶其他物品代替。
