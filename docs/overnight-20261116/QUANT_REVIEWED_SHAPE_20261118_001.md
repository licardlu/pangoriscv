# quant_reviewed_shape_20261118_001 固定方案QAT结果

仅离线软件训练/数学核对/开发验证，未综合、布局布线、访问串口或更新板卡；不是现场摄像头识别率。最终测试图片与标签文件未读取。

## 事前方案

Product-only single batteries do not add transparent glass contours, handles or multi-instance layouts. Add exactly58 individually reviewed glass source files (70 complete glass boxes and8 hand boxes) and21 multi-battery source files (73 complete battery boxes). Keep deployed initialization, frozen Q15 activation profile, selected tail layers, loss and fixed3-epoch schedule identical. This is a predeclared data change, not a threshold, calibration, epoch or validation-based optimizer search.

初始化权重SHA `a4a0b1b04f83af1d114813e0512dd2c2fa5e7306fae16759824f136b3133021a`；量化profile SHA `b9e5fb6cc44aa9b681c0d6efd25cfe129304e3b5ac212544000bc9c6de517154`。
固定3轮最终权重、batch16；8451个缓存训练文件，每轮13940次draw。文件数不能当独立实物数，重复draw不计新图片。
8451 training file identities includes earlier376 rotations and14 background crops. 13940 draws is not 13940 independent photos. Added79 source files include product/rendered images and correlated same-object views; no new station or validation captures.

激活/预激活尺度和LUT冻结；仅三个尾部骨干输出卷积和三个检测头训练，BN、anchors及其他参数保持不变。没有用验证集选阈值、校准或轮次。

## 同一C选择器的定点结果

| 指标 | 原部署 | 本次Q15 |
|---|---:|---:|
| 主体类别与IoU正确 /1793 | 1455 | 1454 |
| 无垃圾/空手误选 /136，低为好 | 8 | 5 |
| 个人电池 /60 | 55 | 45 |
| 公开玻璃 /242 | 232 | 228 |

| 类别 | TP原→本次 | Precision原→本次 | 无退化通过 |
|---|---:|---:|---|
| kitchen | 221→214 | 0.626→0.682 | False |
| recyclable | 1376→1396 | 0.800→0.781 | False |
| hazardous | 150→139 | 0.652→0.760 | False |
| other | 169→152 | 0.413→0.545 | False |
| hand | 234→240 | 0.720→0.734 | True |

712张公开dev主体正确：271→478。该集合缺有害/其他/手及无物GT，不能证明这些场景改善。

额外77张预留手持开发场景：56→47；同图新增正确1、新增错误10。该额外诊断不修改门槛。

## 验收与边界

浮点主体分项：`{'correct_positive': 1483, 'false_background': 2, 'correct_personal_battery': 52, 'correct_public_glass': 227, 'denominators': {'positive': 1793, 'background': 136, 'personal_battery': 60, 'public_glass': 242}}`。

固定门槛：`{'float': False, 'q15_primary': False, 'q15_all_waste_classes': False, 'q15_all_detection_classes': False, 'q15_publicdev': True}`。

未通过全部无退化门槛，拒绝替换当前部署。不能用玻璃、手部或公开dev的增益掩盖电池/其他类退步。

训练用时1698.4秒；最终checkpoint SHA `89a6b41968b22057854f6dc53417abbaafd054d261d2d0433d2320550a962d7d`。

评估中保留的元数据兼容失败记录：[]。复用已完成浮点预测须核对权重、manifest和策略哈希；没有因元数据修复重训或改权重。

旧val与公开dev都属于已用于开发的集合；文件去重不证明实物独立。空手误选指标不代表无人复杂背景。训练新增图、背景裁剪或旋转图不能作为验证准确率证据。
