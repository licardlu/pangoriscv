# YOLO续训结果（2026-11-15）

已从005完成24轮新微调，训练3759图、验证1929图；按框架验证fitness选中第23轮best.pt。以下005和006均在同一1929图上按固定320/单标签/NMS0.45评估，阈值0.25与匹配IoU0.50用于固定指标；不是独立新测试或FPGA现场成绩。

| 指标 | 原005 | 新006 |
|---|---:|---:|
| 混合验证mAP50（五类） | 57.9% | 68.7% |
| 自采电池精确率 | 68.3% | 66.3% |
| 自采电池召回率 | 93.3% | 95.0% |
| 自采可回收召回率 | 31.6% | 56.3% |
| 自采手部召回率 | 1.8% | 32.6% |
| 107张空手经019 C规则选出垃圾 | 15 | 15 |
| 60张电池经019 C规则选对类别且IoU≥0.5 | 55 | 55 |
| 公共回放四桶平均F1（阈值0.25） | 61.7% | 65.3% |

新权重SHA256：`12a41d754f3917ce3a88be11aaf6309bc548c9df701b844fc0a3ec8cadd1f468`。

后验验证对比门槛：{"personal_hand_recall_improves": true, "personal_battery_recall_within_5pp": true, "personal_battery_precision_within_5pp": true, "personal_recyclable_recall_within_5pp": true, "public_four_bin_mean_f1_within_2pp": true, "empty_hand_C_selections_not_increased": true}。全部满足：True。这些门槛用于说明模型间取舍，没有用独立test调参；详尽分类别指标、来源分组和逐图预测在本包validation/及训练结果对比.json。

C规则回放使用019冻结的yolo_contact_policy.h与真实C编译器，但输入仍是电脑浮点预测。空手选出垃圾数不等于现场错误开桶次数，不能声称上板后完全解决手部误报。自采val没有独立no_pickup场景，未拿起误触发仍需新场景验收。

推荐板端版本继续使用019配套005；新006作为本次已完成浮点验证的训练候选交付，尚未量化、重新编译绑定模型CRC或上板。下一步必须完成这些配套验证，再替换TF模型。现有板卡本次未改写。
