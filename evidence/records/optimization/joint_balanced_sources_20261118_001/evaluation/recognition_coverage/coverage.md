# 识别覆盖与逐来源开发验证

这里只分析固定开发验证集已有预测，不增加验证图片、不调阈值，不读取最终测试图片或标签。文件SHA数量不是实物数量；来源文件夹不能证明现场识别质量。

训练文件身份：8975。按已标注框，纯空场景 24；仅手无垃圾 287；手与垃圾同时出现 1306。

| 训练类别 | 有该类的独立文件 | 框数 |
|---|---:|---:|
| kitchen | 459 | 701 |
| recyclable | 5604 | 6606 |
| hazardous | 2094 | 2820 |
| other | 581 | 727 |
| hand | 1593 | 1601 |

| 验证来源/场景 | 有物/无物 | 原部署正确/误选 | QAT正确/误选 | QAT新增正确/新增错误 |
|---|---:|---:|---:|---:|
| all | 1793/136 | 1455/8 | 1460/8 | 29/24 |
| hand_without_waste | 0/136 | 0/8 | 0/8 | 0/0 |
| has_waste | 1793/0 | 1455/0 | 1460/0 | 29/24 |
| no_waste | 0/136 | 0/8 | 0/8 | 0/0 |
| source/codingbear | 287/0 | 244/0 | 252/0 | 10/2 |
| source/hagrid_hand_localisation | 0/29 | 0/1 | 0/1 | 0/0 |
| source/mark_battery | 51/0 | 27/0 | 28/0 | 2/1 |
| source/personal_塑料片 | 28/0 | 19/0 | 18/0 | 0/1 |
| source/personal_电池 | 60/0 | 55/0 | 54/0 | 0/1 |
| source/personal_空手 | 0/107 | 0/7 | 0/7 | 0/0 |
| source/personal_纸团 | 146/0 | 54/0 | 55/0 | 5/4 |
| source/sumn2u | 1221/0 | 1056/0 | 1053/0 | 12/15 |
| source_folder/sumn2u/biological | 105/0 | 81/0 | 83/0 | 2/0 |
| source_folder/sumn2u/cardboard | 203/0 | 179/0 | 181/0 | 4/2 |
| source_folder/sumn2u/glass | 242/0 | 232/0 | 231/0 | 2/3 |
| source_folder/sumn2u/metal | 144/0 | 133/0 | 132/0 | 0/1 |
| source_folder/sumn2u/paper | 231/0 | 183/0 | 178/0 | 2/7 |
| source_folder/sumn2u/plastic | 228/0 | 210/0 | 209/0 | 0/1 |
| source_folder/sumn2u/trash | 68/0 | 38/0 | 39/0 | 2/1 |
| waste_with_hand | 234/0 | 128/0 | 127/0 | 5/6 |

正确指主体类别与标注匹配且IoU≥0.5；误选仅统计无垃圾图片。增益和退步是同图配对，不能用净增益掩盖具体退步。空手集没有证明复杂无人背景覆盖；不存在的现场验证类别也不能由同桶其他物品代替。
