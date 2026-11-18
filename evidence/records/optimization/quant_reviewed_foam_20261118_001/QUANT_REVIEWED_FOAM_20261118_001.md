# quant_reviewed_foam_20261118_001 固定方案QAT结果

仅离线软件训练/数学核对/开发验证，未综合、布局布线、访问串口或更新板卡；不是现场摄像头识别率。最终测试图片与标签文件未读取。

## 事前方案

Foam containers remain underrepresented in the reviewed kitchen/background increment. Add70 explicitly reviewed foam source scenes with duplicated source polygon/bbox labels merged per physical instance. Exclude ambiguous plate/bowl material and secondary unlabelled waste. Keep deployed initialization, matching frozenQ15 profile, same selected tail layers/loss/optimizer and fixed3final epochs as contextQAT. No threshold, calibration or epoch sweep; no prior candidate weights inherited.

初始化权重SHA `a4a0b1b04f83af1d114813e0512dd2c2fa5e7306fae16759824f136b3133021a`；量化profile SHA `b9e5fb6cc44aa9b681c0d6efd25cfe129304e3b5ac212544000bc9c6de517154`。
固定3轮最终权重、batch16；8578个缓存训练文件，每轮14194次draw。文件数不能当独立实物数，重复draw不计新图片。
8578 train file identities includes376 rotations,24 background crops and47 upstream augmented fruit views.14194 draws are not independent photos. Added70 foam source files include correlated same-object/background captures. No new station validation and not20000 independently qualified photos.

激活/预激活尺度和LUT冻结；仅三个尾部骨干输出卷积和三个检测头训练，BN、anchors及其他参数保持不变。没有用验证集选阈值、校准或轮次。

## 同一C选择器的定点结果

| 指标 | 原部署 | 本次Q15 |
|---|---:|---:|
| 主体类别与IoU正确 /1793 | 1455 | 1441 |
| 无垃圾/空手误选 /136，低为好 | 8 | 5 |
| 个人电池 /60 | 55 | 44 |
| 公开玻璃 /242 | 232 | 229 |

| 类别 | TP原→本次 | Precision原→本次 | 无退化通过 |
|---|---:|---:|---|
| kitchen | 221→213 | 0.626→0.657 | False |
| recyclable | 1376→1379 | 0.800→0.788 | False |
| hazardous | 150→138 | 0.652→0.775 | False |
| other | 169→159 | 0.413→0.506 | False |
| hand | 234→242 | 0.720→0.742 | True |

712张公开dev主体正确：271→481。该集合缺有害/其他/手及无物GT，不能证明这些场景改善。

额外77张预留手持开发场景：56→46；同图新增正确1、新增错误11。该额外诊断不修改门槛。

## 验收与边界

浮点主体分项：`{'correct_positive': 1464, 'false_background': 2, 'correct_personal_battery': 53, 'correct_public_glass': 226, 'denominators': {'positive': 1793, 'background': 136, 'personal_battery': 60, 'public_glass': 242}}`。

固定门槛：`{'float': False, 'q15_primary': False, 'q15_all_waste_classes': False, 'q15_all_detection_classes': False, 'q15_publicdev': True}`。

未通过全部无退化门槛，拒绝替换当前部署。不能用玻璃、手部或公开dev的增益掩盖电池/其他类退步。

训练用时1727.9秒；最终checkpoint SHA `e24cc2d157a648872f11a2718f5e0d9f6b9bd3fb5842e275f946a75d7c47f2d0`。

评估中保留的元数据兼容失败记录：[]。复用已完成浮点预测须核对权重、manifest和策略哈希；没有因元数据修复重训或改权重。

旧val与公开dev都属于已用于开发的集合；文件去重不证明实物独立。空手误选指标不代表无人复杂背景。训练新增图、背景裁剪或旋转图不能作为验证准确率证据。
