# 当前092试用的浮点权重：045 best

`best.pt` SHA256 `8b2fb8f4832382eaad64ce2b4ea2b71f0cf2e63a79ccdbcd9a14f1ea302bc31c`。Ultralytics YOLOv5n v7.0/320、四桶加hand。不是当前目录中历史008或004权重。对应054量化blob SHA256 `fee8eb8c9055f44d89e263711bf6f8ea1011a48172f8a0afa35171883f20879f`，已在092/093上板。

原始训练12轮、freeze6、freeze_bn、lr0 .00005、teacher强度5；细节见provenance、opt、hyp及results.csv。原始绝对路径留作来源，不是另一电脑的运行依赖。原数据划分/标签在`../../handoff_metadata/selected_045_dataset/`，量化校准图来源见quantization_provenance.json，只有train，不含val/test。

这是用户指定现场试用的手过滤候选，旧电池效果下降，空手仍可能误报；35/50主体且桶、3/29空手误选仅是小开发集成绩，不能称独立现场准确率。模型使用条件与公共数据署名沿用`../four_bins_20261111/ATTRIBUTION.md`，另含用户自采手持照片和公开手标注，详细来源保留在数据manifest。未附训练照片，需单独取得。
