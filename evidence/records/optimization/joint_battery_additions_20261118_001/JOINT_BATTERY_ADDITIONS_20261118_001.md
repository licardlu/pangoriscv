# joint_battery_additions_20261118_001 固定方案QAT结果

仅离线软件训练/数学核对/开发验证，未综合、布局布线、访问串口或更新板卡；不是现场摄像头识别率。最终测试图片与标签文件未读取。

## 事前方案

Extend the predeclared joint battery replay and frozen original Q15 teacher experiment with178 newly reviewed product battery pictures/239completeboxes. Keep original deployment initialization, same five-class supervision, exact scales, optimizer, fixed3epochs, teacherstrength5 and existingdraws. Add2draws per newfile. This is a new data experiment, not continuation from a failedcandidate. More productpictures do not establish better realhandheld generalization.

初始化权重SHA `a4a0b1b04f83af1d114813e0512dd2c2fa5e7306fae16759824f136b3133021a`；量化profile SHA `b9e5fb6cc44aa9b681c0d6efd25cfe129304e3b5ac212544000bc9c6de517154`。
固定3轮最终权重、batch16；8775个缓存训练文件，每轮16874次draw。文件数不能当独立实物数，重复draw不计新图片。
8775trainingfileidentities include existing derivatives;16874draws are repeated sampling, not newphotos.178newfiles are mainly productpictures/renderings; physicalidentity and cameraindependence unknown. Not20000qualifiedindependentphotos.

激活/预激活尺度和LUT冻结；训练Q15卷积 [65, 73, 81] 和三个检测头，BN、anchors及其他参数保持不变。没有用验证集选阈值、校准或轮次。

## 同一C选择器的定点结果

| 指标 | 原部署 | 本次Q15 |
|---|---:|---:|
| 主体类别与IoU正确 /1793 | 1455 | 1452 |
| 无垃圾/空手误选 /136，低为好 | 8 | 7 |
| 个人电池 /60 | 55 | 54 |
| 公开玻璃 /242 | 232 | 231 |

本实验额外使用冻结原部署Q15教师；只保留与GT同类、conf≥.25且IoU≥.5的锚点，五类均衡约束系数固定5。教师不生成新框/空背景标签，不导出教师；每轮匹配数量和无梯度检查见training/history.json。


| 类别 | TP原→本次 | Precision原→本次 | 无退化通过 |
|---|---:|---:|---|
| kitchen | 221→221 | 0.626→0.637 | True |
| recyclable | 1376→1366 | 0.800→0.801 | False |
| hazardous | 150→151 | 0.652→0.706 | True |
| other | 169→173 | 0.413→0.438 | True |
| hand | 234→238 | 0.720→0.728 | True |

712张公开dev主体正确：271→284。该集合缺有害/其他/手及无物GT，不能证明这些场景改善。

额外77张预留手持开发场景：56→56；同图新增正确2、新增错误2。该额外诊断不修改门槛。

## 验收与边界

浮点主体分项：`{'correct_positive': 1468, 'false_background': 6, 'correct_personal_battery': 54, 'correct_public_glass': 231, 'denominators': {'positive': 1793, 'background': 136, 'personal_battery': 60, 'public_glass': 242}}`。

固定门槛：`{'float': True, 'q15_primary': False, 'q15_all_waste_classes': False, 'q15_all_detection_classes': False, 'q15_publicdev': True}`。

未通过全部无退化门槛，拒绝替换当前部署。不能用玻璃、手部或公开dev的增益掩盖电池/其他类退步。

训练用时3812.1秒；最终checkpoint SHA `288f5a3f0ee81ac855d392249dbfabe81df7d5856cb574a29504a5f11c1187e1`。

评估中保留的元数据兼容失败记录：[]。复用已完成浮点预测须核对权重、manifest和策略哈希；没有因元数据修复重训或改权重。

旧val与公开dev都属于已用于开发的集合；文件去重不证明实物独立。空手误选指标不代表无人复杂背景。训练新增图、背景裁剪或旋转图不能作为验证准确率证据。
