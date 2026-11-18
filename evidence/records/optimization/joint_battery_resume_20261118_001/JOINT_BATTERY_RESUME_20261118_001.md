# joint_battery_resume_20261118_001 固定方案QAT结果

仅离线软件训练/数学核对/开发验证，未综合、布局布线、访问串口或更新板卡；不是现场摄像头识别率。最终测试图片与标签文件未读取。

## 事前方案

Joint supervised exact-Q15 training on every reviewed class, including latest 11 AA photos and 8 hand-held crops. Add two draws per real battery-containing file, excluding extra replay for rotated derivatives; retain original complete hand/object labels. Add the previously tested GT-gated frozen original deployed teacher (strength5) to preserve reliable predictions. Fixed3epochs and final checkpoint, not validation selection. This tests replay plus preservation jointly; gains cannot be attributed solely to more unique data.

初始化权重SHA `a4a0b1b04f83af1d114813e0512dd2c2fa5e7306fae16759824f136b3133021a`；量化profile SHA `b9e5fb6cc44aa9b681c0d6efd25cfe129304e3b5ac212544000bc9c6de517154`。
固定3轮最终权重、batch16；8597个缓存训练文件，每轮16518次draw。文件数不能当独立实物数，重复draw不计新图片。
8597 files includes existing derivatives; battery replay adds sampling draws, not new photos. Additional reviewed new sources will be frozen in a later distinct experiment.

激活/预激活尺度和LUT冻结；仅三个尾部骨干输出卷积和三个检测头训练，BN、anchors及其他参数保持不变。没有用验证集选阈值、校准或轮次。

## 同一C选择器的定点结果

| 指标 | 原部署 | 本次Q15 |
|---|---:|---:|
| 主体类别与IoU正确 /1793 | 1455 | 1459 |
| 无垃圾/空手误选 /136，低为好 | 8 | 8 |
| 个人电池 /60 | 55 | 54 |
| 公开玻璃 /242 | 232 | 232 |

本实验额外使用冻结原部署Q15教师；只保留与GT同类、conf≥.25且IoU≥.5的锚点，五类均衡约束系数固定5。教师不生成新框/空背景标签，不导出教师；每轮匹配数量和无梯度检查见training/history.json。


| 类别 | TP原→本次 | Precision原→本次 | 无退化通过 |
|---|---:|---:|---|
| kitchen | 221→221 | 0.626→0.641 | True |
| recyclable | 1376→1379 | 0.800→0.804 | True |
| hazardous | 150→150 | 0.652→0.708 | True |
| other | 169→172 | 0.413→0.431 | True |
| hand | 234→239 | 0.720→0.733 | True |

712张公开dev主体正确：271→289。该集合缺有害/其他/手及无物GT，不能证明这些场景改善。

额外77张预留手持开发场景：56→57；同图新增正确2、新增错误1。该额外诊断不修改门槛。

## 验收与边界

浮点主体分项：`{'correct_positive': 1466, 'false_background': 6, 'correct_personal_battery': 54, 'correct_public_glass': 231, 'denominators': {'positive': 1793, 'background': 136, 'personal_battery': 60, 'public_glass': 242}}`。

固定门槛：`{'float': True, 'q15_primary': False, 'q15_all_waste_classes': False, 'q15_all_detection_classes': True, 'q15_publicdev': True}`。

未通过全部无退化门槛，拒绝替换当前部署。不能用玻璃、手部或公开dev的增益掩盖电池/其他类退步。

训练用时3857.8秒；最终checkpoint SHA `f7b9ecd255bd13904b26d8f64cc1479f2be4bce2f9ab64dca9c6239c5715b604`。

评估中保留的元数据兼容失败记录：[]。复用已完成浮点预测须核对权重、manifest和策略哈希；没有因元数据修复重训或改权重。

旧val与公开dev都属于已用于开发的集合；文件去重不证明实物独立。空手误选指标不代表无人复杂背景。训练新增图、背景裁剪或旋转图不能作为验证准确率证据。
