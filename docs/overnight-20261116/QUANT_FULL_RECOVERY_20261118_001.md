# quant_full_recovery_20261118_001 固定方案QAT结果

仅离线软件训练/数学核对/开发验证，未综合、布局布线、访问串口或更新板卡；不是现场摄像头识别率。最终测试图片与标签文件未读取。

## 事前方案

The fixed10-epoch feature continuation improved held-scene dev56to66 and glass232to235 but lost battery55to49 inQ15; its float battery56toQ15 49 identifies a quantization gap. Continue this single final checkpoint with its own predeclared160-train calibration scales through exactQ15 tail training, on the identical8508-file reviewed context dataset. Only initialization/matching fixed profile changes relative to the already frozen contextQAT. Keep3epochs, optimizer/loss/trainable layers and unchanged gates. No calibration, threshold or epoch sweep; rejection of the parent remains in effect until every offline gate passes.

初始化权重SHA `64e8bcd12b3adc53b2f051b15b6cd091a0f6f8b685d19aac573ae46eaf26ae75`；量化profile SHA `899f4fcb11962835255888349838dd59b14ddc7d72b27d5d71159fab2c48b713`。
固定3轮最终权重、batch16；8508个缓存训练文件，每轮14054次draw。文件数不能当独立实物数，重复draw不计新图片。
8508 train file identities includes earlier376 rotations,24 background crops and47 new upstream augmented fruit views. 14054draws is not independent photos. Fruits include correlated same-object captures, injected noise and grayscale source augmentation. New physical objects and unaugmented-original count are unknown; not a20000-independent-photo dataset.

激活/预激活尺度和LUT冻结；仅三个尾部骨干输出卷积和三个检测头训练，BN、anchors及其他参数保持不变。没有用验证集选阈值、校准或轮次。

## 同一C选择器的定点结果

| 指标 | 原部署 | 本次Q15 |
|---|---:|---:|
| 主体类别与IoU正确 /1793 | 1455 | 1422 |
| 无垃圾/空手误选 /136，低为好 | 8 | 1 |
| 个人电池 /60 | 55 | 48 |
| 公开玻璃 /242 | 232 | 233 |

| 类别 | TP原→本次 | Precision原→本次 | 无退化通过 |
|---|---:|---:|---|
| kitchen | 221→210 | 0.626→0.705 | False |
| recyclable | 1376→1311 | 0.800→0.845 | False |
| hazardous | 150→145 | 0.652→0.681 | False |
| other | 169→159 | 0.413→0.430 | False |
| hand | 234→287 | 0.720→0.709 | False |

712张公开dev主体正确：271→697。该集合缺有害/其他/手及无物GT，不能证明这些场景改善。

额外77张预留手持开发场景：56→66；同图新增正确11、新增错误1。该额外诊断不修改门槛。

## 验收与边界

浮点主体分项：`{'correct_positive': 1426, 'false_background': 2, 'correct_personal_battery': 58, 'correct_public_glass': 235, 'denominators': {'positive': 1793, 'background': 136, 'personal_battery': 60, 'public_glass': 242}}`。

固定门槛：`{'float': False, 'q15_primary': False, 'q15_all_waste_classes': False, 'q15_all_detection_classes': False, 'q15_publicdev': True}`。

未通过全部无退化门槛，拒绝替换当前部署。不能用玻璃、手部或公开dev的增益掩盖电池/其他类退步。

训练用时1700.4秒；最终checkpoint SHA `6363f94825c942d29a37b4c0f011412e5a2eaf04f63c6f48f4f9ff00b4a4c95d`。

评估中保留的元数据兼容失败记录：[]。复用已完成浮点预测须核对权重、manifest和策略哈希；没有因元数据修复重训或改权重。

旧val与公开dev都属于已用于开发的集合；文件去重不证明实物独立。空手误选指标不代表无人复杂背景。训练新增图、背景裁剪或旋转图不能作为验证准确率证据。
