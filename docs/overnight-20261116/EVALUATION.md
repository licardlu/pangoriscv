> 最新上板状态（恢复执行后）：新版实验位流已经通过JTAG下载；stage4新模型已加载并通过板端CRC、四组FPGA数值推理、摄像头输入一致性及自主识别验证，相机探针均值1.757秒。当前仍有Slow hold -0.012ns/1端点，属于功能实验版，TF未写、物理屏幕/音箱/机械动作未远程验收。
> 最新交付：project/trash_sorting/candidates/overnight_020/release_experimental_006/README.md；板测：evidence/records/overnight-20261116/experimental-board-006/result.json。
> 下文保留原截止阶段的记录；其中“未上板”描述只适用于恢复执行前，不代表当前板状态。

# 夜间续训评估（06:17中间检查点，非最终交付）

## 数据身份与隔离

865张待核对图已逐图人工视觉复核，685张加入train，新增框为厨余86、回收337、有害127、其他176、手555。另保护101张历史val/test拍摄组，保留77张新开发val、排除2张歧义图。最终训练快照4444 train/1929 val/1634 test。

`build/overnight_20261116/dataset_final_audit_002/result.json`核验8007张全部图片/标签SHA、原7322张图片/标签/split不变；无精确SHA跨split泄漏，无清单组跨split泄漏。20张分层抽取的实际导出标签叠图已目视核对。组隔离仍只代表已知拍摄组，不声称物理实物全面独立。

77张新val在训练前预留，已按复核ledger单独导出为`reserved_newval_001`，与train图片SHA及已知拍摄组不重合；未读取1634张test作本轮调参。

## 同口径浮点与实际C选物回放

固定320方形letterbox、conf .25、single-label、NMS .45、max32，使用候选真实`yolo_contact_policy.h`编译DLL选物。下列“正确主体”要求桶码正确且与一个垃圾真值框IoU≥.5；手仅作内部定位，不当第五桶。以下均为CPU验证，未上板。

| 口径 | 006 | 阶段3best |
|---|---:|---:|
| 原1929 val五类mAP50 | 0.68685 | 0.71609 |
| 原val垃圾主体正确（1793张有垃圾图） | 1458 | 1490 |
| 原val个人纸团主体正确/146 | 64 | 75 |
| 原val个人电池主体正确/60 | 55 | 54 |
| 原val个人塑料片主体正确/28 | 23 | 22 |
| 原val公共源主体正确（含29张纯手图的1588张） | 1316 | 1339 |
| 原val无垃圾误选/136 | 16 | 17 |
| 新77 val mAP50（仅3种垃圾+手有GT，无厨余） | 0.59004 | 0.66591 |
| 新val主体正确/77 | 52 | 56 |
| 新val手持瓶主体正确/8 | 3 | 7 |
| 新val手持电池主体正确/29 | 24 | 24 |
| 新val泡沫包装主体正确/12 | 0 | 0 |

原val固定阈值下手召回约0.378→0.624，厨余召回约0.764→0.752。阶段3整体和瓶子进步，但空手误选、个人电池/塑料片及泡沫包装仍有局限；不能仅凭总mAP称全类别都提高。77张中场景名no_pickup的照片实际含桌面/地面垃圾，不能把该场景名当作无垃圾真值。

原val证据：`evaluation/baseline006_original_val`、`evaluation/stage3_original_val`、`policy_replay_001`。新val证据：`evaluation/baseline006_newval_002`、`evaluation/stage3_newval_002`、`policy_newval_001`。第一次新val评估仅因汇总未处理缺失厨余类别而失败，修复为明确列出缺失类别并只平均有GT类别，结果独立重跑为002。

## 量化与部署数值

阶段3 `quant_stage3_002`：85算子浮点图与checkpoint逐项bit exact；160张train-only校准，无zero multiplier。packed模型1858168字节，SHA256 `c69595b5fc1f2c5e8e3273951fe3bb0fd240bd5f1f61be13e26361e3a4daab30`。

`numeric_stage3_002`：6次固定val输入（5张唯一图片，额外公共图与其他桶重复一次）覆盖四桶/手，真实C的25个非卷积非head算子精确相同，18次head检查最大绝对误差0.000257492。卷积使用精确整数软件oracle，尚非FPGA数值验收。后续fixture生成器已避免该重复，旧证据不改写。Host编译器为Zig Clang，明确忽略其不支持的GCC optimize属性；生产固件仍使用RISC-V GCC，最终以板上四个固定输入核对。

## 下一步

### 06:58阶段4完成与保守分支

阶段4八轮完成，best checkpoint SHA256 `a4a0b1b04f83af1d114813e0512dd2c2fa5e7306fae16759824f136b3133021a`，原val同部署解码mAP50=0.72108，新77 val mAP50=0.81944。实际C选物：原val有垃圾主体1456/1793（0061458、stage31490），个人纸团60/146（00664、stage375）、电池50/60（00655、stage354），无垃圾误选9/136（00616、stage317）；新val主体58/77（00652、stage356）、泡沫2/12、瓶6/8、电池25/29。它提高新场景与空手拒识，但牺牲旧个人主体表现，暂不因总mAP高直接冻结。

阶段4量化与6次实际C/Q16精确检查通过。packed SHA256 `7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728`，CRC32十进制3689371381；全1929 val Q15+实际C回放正在运行`numeric_stage4_allval_exact_001`。

阶段3全1929 val新数值门禁通过，5787次head检查精确匹配独立Q16 oracle，浮点head最大偏差0.00038624在逐输入系数误差界内。量化固定阈值C选物主体1460/1793，无垃圾误选15/136。每类TP/FP/GT见`quantized_stage3_val_score_001`，不从只保留conf≥.25的输出伪算AP。

为检验旧纸团回退能否避免，启动固定6轮保守stage5分支：从stage3best、最终685新增训练快照、freeze10+BN，lr0与bias warmup均0.00001，保留其余训练增强。stage4默认bias warmup=.01，对低学习率续训较激进；保守分支同时显式限制偏置热身并冻结前十块。仍只使用训练真值，val按同口径选型，不触test；09点前停止探索、10点PNR不变。若stage5仍退化，选择已验证候选的可解释取舍并报告，不能称全面改进。

### 07:11同部署量化口径对照

006、stage3、stage4均用160张各自train-only校准、相同Q15软件卷积oracle和实际候选C的Q16 head/decoder/选物，完整1929张val。三个模型均通过5787次head逐元素精确核对及每输入浮点误差界，25个非head算子在首图核对，其余图片的非head由oracle供给；这不等于完整FPGA网络测试。

| 固定conf .25、主体IoU≥.5 | 006量化 | stage3量化 | stage4量化 |
|---|---:|---:|---:|
| 有垃圾主体正确/1793 | 1398 | 1460 | 1452 |
| 无垃圾误选/136（越低越好） | 26 | 15 | 11 |
| 个人纸团主体正确/146 | 47 | 71 | 54 |
| 个人电池主体正确/60 | 53 | 47 | 50 |
| 个人塑料片主体正确/28 | 23 | 20 | 19 |
| codingbear主体正确/287 | 226 | 245 | 242 |
| sumn2u主体正确/1221 | 1028 | 1054 | 1061 |
| 手类召回（TP/370） | 110/370 | 240/370 | 234/370 |

量化后相对006总体主体和空手误选均改善，但旧电池/塑料片有损失，stage3纸团更好、stage4空手更好。最终须结合stage5及新val量化结果选择，不能只用浮点mAP决定。证据`quantized_baseline006_val_score_001`、`quantized_stage3_val_score_001`、`quantized_stage4_val_score_001`。

新77 val相同量化C回放也已完成（各231次head exact）：006主体51/77，stage3为55/77，stage4为55/77；手TP48/72→64/72→64/72。此集实际全部有垃圾，场景名no_pickup不是无垃圾标注，因此不报该集空手误报率。证据`quantized_baseline006_newval_score_001`、`quantized_stage3_newval_score_001`、`quantized_stage4_newval_score_001`。stage5完整量化验证已排入依赖队列，训练未完成前不读取动态best。

06:44补充：扩大到全val后，旧固定FP容差门禁在第1586张的head82发现一个元素误差0.00036216超限，旧`numeric_stage3_allval_001`失败，不能用其部分预测报整集通过。已冻结失败单例，并采用独立Q16整数点积+逐步float32的bit-exact C核对，再按每行真实权重舍入误差和每像素输入推导浮点偏差上界。失败单例和6次smoke均精确通过，模型及C实现没有修改，旧FP误差保留；全val新门禁`numeric_stage3_allval_exact_001`尚在运行。这个证据不等同于FPGA数值验收。

阶段4八轮仍在训练（正式002）。完成后独立评估原val、新val，按相同C选物口径核对分项，量化及数值门禁后决定部署模型。09～10点冻结，再用最终通过版本独立完整PNR和上板，原019保留回退。最终模型选定后可一次性运行原test只作最终报告，不能据其结果继续调参。

### 07:41阶段5保守分支已完成

本节替代前面“仍在训练”的运行状态。stage5六轮完成，checkpoint SHA256 `e289012ceb771eda1cd6d5f081486d8007a0ef174f179fe5aa664d1a4dc22062`。同部署浮点原val mAP50 .7151367284、新val .6929673294；实际C原val主体1468/1793、无垃圾误选11/136，纸团70/146、电池52/60、塑料片22/28，codingbear250/287、sumn2u1050/1221；新val主体56/77，其中手持电池25/29、瓶7/8、泡沫0/12、桌面场景24/28。证据`policy_stage5_original_001`、`policy_stage5_new_001`、`evaluation/stage5_original_val`、`evaluation/stage5_newval`。

量化`quant_stage5_001`已完成，packed SHA256 `4e2166f7e680c08f5fce1afb0a7291aacc4fbfdb1239d217a6808b07da527d19`、CRC32十进制1905477747。`numeric_stage5_exact_001`六次smoke的25非head/18head精确通过，最大浮点head偏差 .00017409。完整1929原val及77新val的Q15+真实C队列仍运行，完整量化分项尚未得到；不将本节浮点数字当作部署量化成绩。

### 07:50阶段5完整部署量化对照

stage5完整原1929 val及新77 val全部通过。与上述006/stage3/stage4固定同口径：

| 指标 | 006量化 | stage3量化 | stage4量化 | stage5量化 |
|---|---:|---:|---:|---:|
| 有垃圾主体正确/1793 | 1398 | 1460 | 1452 | 1454 |
| 无垃圾误选/136（越低越好） | 26 | 15 | 11 | 15 |
| 个人纸团主体正确/146 | 47 | 71 | 54 | 68 |
| 个人电池主体正确/60 | 53 | 47 | 50 | 46 |
| 个人塑料片主体正确/28 | 23 | 20 | 19 | 21 |
| 手TP/370 | 110 | 240 | 234 | 249 |
| 手FP（越低越好） | 64 | 106 | 91 | 117 |
| 新77 val主体正确 | 51 | 55 | 55 | 55 |
| 新val泡沫主体正确/12 | 0 | 0 | 3 | 0 |

stage5原val5787次head精确通过、最大浮点偏差.000225067；新val231次head精确通过、最大浮点偏差.000185609。25非head仍仅首图检查，完整卷积为软件oracle，非FPGA准确率。新val手TP66/72、FP11，瓶7/8、电池25/29、桌面场景23/28。证据`numeric_stage5_allval_exact_001`、`numeric_stage5_newval_exact_001`、`quantized_stage5_val_score_001`、`quantized_stage5_newval_score_001`。完整score与`stage5_full_numeric_queue_001`均PASS/completed。

stage5提高了手TP，却没有在主体、空手或电池上整体超过stage3，保守冻结过多的收益未得到支持。剩余窗口只新增一组stage6受控对照：相同stage3起点/全685新增train/6轮/低lr与bias warmup，单独将freeze10改为freeze2并继续冻结对应BN；不改数据/损失/阈值。09点前停止新探索，完整验证后在已通过候选中选择，10点正式布局布线不变。未读取test调参。

### 08:40最后训练分支stage6已完成

stage6六轮训练结束，best checkpoint SHA256 `f30a06ecab731a0dcf5eefff29dc7aa35cd02bd9427ccad04244a11e4476015e`。独立同部署浮点原val mAP50 .7168092428、新val .7515869725；实际C原val主体1449/1793、无垃圾误选9/136，纸团49/146、电池54/60、塑料片20/28；新val主体56/77（瓶7/8、电池24/29、泡沫1/12、桌面24/28）。证据`evaluation/stage6_original_val`、`evaluation/stage6_newval`、`policy_stage6_original_001`、`policy_stage6_new_001`。纸团回退，不能只引用训练入口最佳mAP或电池单项称整体更好。

stage6正在160张train-only校准，完整Q15+C原val/新val检查由既有依赖队列等待。当前没有stage6量化分数，不把浮点数字混入部署量化表。全部训练分支至此结束，不再新增训练，余下时间用于选型验证、配套固件、10点物理实现与板测。

### 08:57最终量化结果与选择冻结

stage6量化完成：原1929 val主体1431/1793、误选17/136、纸团45/146、电池46/60、塑料片22/28、手TP234/370；新77 val主体56/77、泡沫1/12。原5787及新231次head精确通过，最大浮点偏差分别.000301361与.000246197，在逐输入误差界内。量化blobSHA `5155f3dd60e186184876d337872e54cef2ccbdb31ba04f60d1d10e1fdfb41f15`。证据`quantized_stage6_val_score_001`、`quantized_stage6_newval_score_001`及对应exact目录，未超过已有候选，不因轮次最新而采用。

**最终选择stage4**，在读取test前于`final_selection_001.json`和独立`candidates/overnight_020/frozen_20261116`冻结（801输入SHA）。它已学全部685新增训练图；用户最关心的无垃圾误选相对006为26→11/136，主体1398→1452/1793、新场景51→55/77。相对stage3，牺牲8个总体主体及17个个人纸团正确，换取少4个空手误选、多3个个人电池正确、多3个新泡沫正确。相对006仍有个人电池53→50/60、塑料片23→19/28回退。此选择强调背景拒识和全新增训练覆盖，不能称每类全面提升。

部署模型SHA `7a0765a6f275f3c06d838f924d73542783ca55e131509aa1b546efc98bd65728`，配套固件SHA `061e46fb5218520185bba5128b664609e4c051325026319a432aef3d6d54c85d`，静态源码/模型/固件/各ROM lane身份核验通过。最终完整预检运行中，尚无正式PNR/最终STA或本轮板测结论。冻结后一次性test A/B已启动，只作报告，后续不据test重选或调参。

### 08:59冻结后一次性原test报告（浮点）

两模型都在相同原1634 test、相同320方形输入/conf .25/single-label/NMS .45/max32上完成独立浮点评估，再通过冻结版本真实C选物回放。选择于08:54:50冻结，test启动于之后；结果不用于再次调参或重选。

| 指标 | 006 | 最终stage4 |
|---|---:|---:|
| 五类mAP50 | .81876271 | .81996922 |
| 五类mAP50-95 | .53224165 | .54928877 |
| 有垃圾主体正确/1613 | 1412 | 1424 |
| 无垃圾误选/21 | 1 | 1 |
| codingbear主体正确/340 | 306 | 305 |
| sumn2u主体正确/1232 | 1077 | 1089 |

此test全部为公共来源，无本轮个人纸团/手持瓶/电池场景，空手仅21张，不能据它声称覆盖本轮新增实物或证明背景误识显著下降。以上为浮点+实际C选物，**不是量化test、不是板上相机准确率**；量化改善依照前述固定val同口径表。证据`evaluation/final_baseline006_test_001`、`evaluation/final_stage4_test_001`、`policy_final_test_001`（split=test、held_out_test_used=true、TEST_PASS）。两训练入口provenance.completed，实际C定向测试和完整1634身份匹配通过；未修改原test标签/图片/split。

## 最终物理验收结论（UTC03:50）

配套预检003及整机面积门禁通过，但正式full001/002/004/005的最终多角STA均未全通过。最后full005已满足所有Setup，仍有Slow DDR内部Hold -0.012ns/1端点；没有生成新位流、没有执行本轮新版本上板。板上新模型准确率、相机延迟、新界面和扬声器物理效果均未验证。各轮完整失败时序与输入SHA已独立保存并放入候选交付包evidence/；不能以软件数值通过代替该物理验收，也不能忽略12ps超限。原019仍保留，后续必须继续修复时序才能完成用户要求的新版本上板。
