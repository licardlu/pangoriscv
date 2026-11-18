# joint_expanded_tail_20261118_001 固定方案QAT结果

仅离线软件训练/数学核对/开发验证，未综合、布局布线、访问串口或更新板卡；不是现场摄像头识别率。最终测试图片与标签文件未读取。

## 事前方案

Original three-output-convolution QAT repeatedly leaves handheld battery and glass errors; fixed early feature cuts and only three trainable output convolutions restrict adaptation. On exactly the same8975-file reviewed fiveclass data and17274draws as joint_balanced_sources, unfreeze13 existing Q15 tail convolutions instead of3 while preserving original deployment initialization, all BN, all earlier graphops0..64, scales/LUTs, losses, GT-gated deployedteacherstrength5, optimizer, fixed3epochs and gates. This isolates trainable capacity, not morephotos or an epoch/threshold sweep. Preflight verifies all new gradients, frozen state, and bitexact integer export on train-only inputs.

初始化权重SHA `a4a0b1b04f83af1d114813e0512dd2c2fa5e7306fae16759824f136b3133021a`；量化profile SHA `b9e5fb6cc44aa9b681c0d6efd25cfe129304e3b5ac212544000bc9c6de517154`。
固定3轮最终权重、batch16；8975个缓存训练文件，每轮17274次draw。文件数不能当独立实物数，重复draw不计新图片。
Same8975 training file identities and17274samplingdraws as preceding frozen dataset; includes existing derived views. Zero added photos and no new field validation in this experiment.

激活/预激活尺度和LUT冻结；训练Q15卷积 [65, 66, 68, 69, 70, 71, 73, 74, 76, 77, 78, 79, 81] 和三个检测头，BN、anchors及其他参数保持不变。没有用验证集选阈值、校准或轮次。

## 同一C选择器的定点结果

| 指标 | 原部署 | 本次Q15 |
|---|---:|---:|
| 主体类别与IoU正确 /1793 | 1455 | 1461 |
| 无垃圾/空手误选 /136，低为好 | 8 | 9 |
| 个人电池 /60 | 55 | 54 |
| 公开玻璃 /242 | 232 | 228 |

本实验额外使用冻结原部署Q15教师；只保留与GT同类、conf≥.25且IoU≥.5的锚点，五类均衡约束系数固定5。教师不生成新框/空背景标签，不导出教师；每轮匹配数量和无梯度检查见training/history.json。


| 类别 | TP原→本次 | Precision原→本次 | 无退化通过 |
|---|---:|---:|---|
| kitchen | 221→220 | 0.626→0.643 | False |
| recyclable | 1376→1367 | 0.800→0.805 | False |
| hazardous | 150→151 | 0.652→0.693 | True |
| other | 169→174 | 0.413→0.446 | True |
| hand | 234→237 | 0.720→0.734 | True |

712张公开dev主体正确：271→316。该集合缺有害/其他/手及无物GT，不能证明这些场景改善。

额外77张预留手持开发场景：56→57；同图新增正确2、新增错误1。该额外诊断不修改门槛。

## 验收与边界

浮点主体分项：`{'correct_positive': 1474, 'false_background': 8, 'correct_personal_battery': 53, 'correct_public_glass': 231, 'denominators': {'positive': 1793, 'background': 136, 'personal_battery': 60, 'public_glass': 242}}`。

固定门槛：`{'float': False, 'q15_primary': False, 'q15_all_waste_classes': False, 'q15_all_detection_classes': False, 'q15_publicdev': True}`。

未通过全部无退化门槛，拒绝替换当前部署。不能用玻璃、手部或公开dev的增益掩盖电池/其他类退步。

训练用时3887.4秒；最终checkpoint SHA `922bb24bb380d0ef9df950aef9ded0ae59d58974852b359e5abd88cc2112d1a6`。

评估中保留的元数据兼容失败记录：[]。复用已完成浮点预测须核对权重、manifest和策略哈希；没有因元数据修复重训或改权重。

旧val与公开dev都属于已用于开发的集合；文件去重不证明实物独立。空手误选指标不代表无人复杂背景。训练新增图、背景裁剪或旋转图不能作为验证准确率证据。
