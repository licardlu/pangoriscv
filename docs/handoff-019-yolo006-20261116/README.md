# FPGA019、YOLO006和完整数据交付（2026-11-16上传）

本交付对应2026-11-15完成的019代码整理与006模型训练。所有下载见 [GitHub Release](https://github.com/licardlu/pangoriscv/releases/tag/fpga019-yolo006-handoff-20261116)。

## 下载选择

- 只需要完整代码及019运行文件：下载`fpga019-code-and-runtime-20261115.zip`（约268 MiB），已包括006候选权重与验证结果。
- 只需要006权重/训练成果：下载`yolo006-weights-and-validation-20261115.zip`（约6.9 MiB）。
- 需要总代码、全部训练图片/标签、原始自采照片、公开来源原包、训练日志及交接文档：下载全部5个`fpga019-yolo006-complete-20261115.zip.part001`至`part005`，以及`bundle-parts-sha256.json`、`merge_and_verify.py`。这5卷合起来就是原始总包，不能只下载其中一卷。

## 合并总包

将5卷、JSON清单和Python脚本放在同一文件夹，运行：

```powershell
python merge_and_verify.py
```

脚本先验证每卷SHA256，再合并并验证总包；总包大小4,830,889,904字节，SHA256为`b6830111fdb421132c19c0d33ee44d37c0014a5c324dc5a3a30e66b1108275e7`。输出`FPGA019_YOLO006_complete_20261115.zip`，使用支持ZIP64的软件解压。存放位置需要支持大于4GiB单文件（不能用FAT32存放总包），下载5卷和合并输出合计约9.0GiB，解压另需空间。

## 文档入口

- [总交接说明](HANDOFF.md)：交付内容、代码状态、训练成果、限制和继续训练步骤。
- [019代码详细交接](CODE_019.md)：当前版本身份、固件/FPGA重建及脱机启动。
- [代码结构和修改入口](CODE_MAP.md)。
- [YOLO训练结果](YOLO_RESULTS.md)和[详细比较数据](training-comparison.json)。

## 当前结论

推荐板端仍为019位流＋固件011＋005模型；006已完成24轮训练并选中第23轮，但尚未量化或上板，不能直接替换TF卡MODEL.BIN。

同口径混合验证mAP50从57.9%提升至68.7%，自采手部召回率1.8%→32.6%，电池召回率93.3%→95.0%。107张空手经019 C主体规则误选垃圾仍为15张。因此006是改进后的浮点候选，不能宣称已稳定识别所有手持垃圾。

019精确冻结源码位于代码ZIP内`fpga_019/project/trash_sorting/releases/standalone_019/source/`。本次上传把已核验的完整工作快照放在Release；仓库其他路径中的较早开发代码/README不自动等同于019快照，使用本页和交付目录为准。
