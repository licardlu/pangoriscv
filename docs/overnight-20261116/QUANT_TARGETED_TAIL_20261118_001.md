# quant_targeted_tail_20261118_001 固定方案QAT结果

仅离线软件训练/数学核对/开发验证，未综合、布局布线、访问串口或更新板卡；不是现场摄像头识别率。最终测试图片与标签文件未读取。

## 事前方案

The current whitelist has no pure empty background. Add 40 newly reviewed TACO source images (mostly foam, paper/tissue and two food instances) plus 14 explicitly reviewed empty train-scene crops, with complete mapped boxes and two added hand boxes. Keep deployed initialization, frozen scale profile and identical fixed 3-epoch optimizer/loss/layer schedule; test the data change only.

初始化权重SHA `a4a0b1b04f83af1d114813e0512dd2c2fa5e7306fae16759824f136b3133021a`；量化profile SHA `b9e5fb6cc44aa9b681c0d6efd25cfe129304e3b5ac212544000bc9c6de517154`。
固定3轮最终权重、batch16；7958个缓存训练文件，每轮12878次draw。文件数不能当独立实物数，重复draw不计新图片。
7958 cached train files includes 14 derived background crops; those crops are not new source photos or physical objects.

激活/预激活尺度和LUT冻结；仅三个尾部骨干输出卷积和三个检测头训练，BN、anchors及其他参数保持不变。没有用验证集选阈值、校准或轮次。

## 同一C选择器的定点结果

| 指标 | 原部署 | 本次Q15 |
|---|---:|---:|
| 主体类别与IoU正确 /1793 | 1455 | 1463 |
| 无垃圾/空手误选 /136，低为好 | 8 | 4 |
| 个人电池 /60 | 55 | 39 |
| 公开玻璃 /242 | 232 | 227 |

| 类别 | TP原→本次 | Precision原→本次 | 无退化通过 |
|---|---:|---:|---|
| kitchen | 221→215 | 0.626→0.672 | False |
| recyclable | 1376→1415 | 0.800→0.771 | False |
| hazardous | 150→131 | 0.652→0.829 | False |
| other | 169→155 | 0.413→0.538 | False |
| hand | 234→239 | 0.720→0.740 | True |

712张公开dev主体正确：271→521。该集合缺有害/其他/手及无物GT，不能证明这些场景改善。

额外77张预留手持开发场景：56→40；同图新增正确1、新增错误17。该额外诊断不修改门槛。

## 验收与边界

浮点主体分项：`{'correct_positive': 1488, 'false_background': 3, 'correct_personal_battery': 48, 'correct_public_glass': 227, 'denominators': {'positive': 1793, 'background': 136, 'personal_battery': 60, 'public_glass': 242}}`。

固定门槛：`{'float': False, 'q15_primary': False, 'q15_all_waste_classes': False, 'q15_all_detection_classes': False, 'q15_publicdev': True}`。

未通过全部无退化门槛，拒绝替换当前部署。不能用玻璃、手部或公开dev的增益掩盖电池/其他类退步。

训练用时1747.8秒；最终checkpoint SHA `918adb118917ef4aa4bf21736bb654daa7c72b5ff3b458b11bc2e73a420adf77`。

评估中保留的元数据兼容失败记录：[]。复用已完成浮点预测须核对权重、manifest和策略哈希；没有因元数据修复重训或改权重。

旧val与公开dev都属于已用于开发的集合；文件去重不证明实物独立。空手误选指标不代表无人复杂背景。训练新增图、背景裁剪或旋转图不能作为验证准确率证据。
