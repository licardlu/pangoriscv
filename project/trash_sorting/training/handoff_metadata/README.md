# 训练数据划分和标签交接

`selected_045_dataset`是045实际使用的043数据，`latest_reviewed_052_dataset`是后续增加审阅照片的数据。两者不混称。每份保留原始manifest/data.yaml、完整YOLO labels、精确图片字节SHA清单；图片未随代码提交。

原路径只作来源证据，换电脑不能照抄。重新下载公共图、取得自采图并按原处理复原后，对image_inventory逐项核对，再生成新本地data.yaml。保持组/split和既有歧义排除决策，不能随机重分或把val/test拿去量化校准。

原电脑个人照片在`D:/Huawei Share/Huawei Share`，公共数据获取入口为`../download_four_bins.py`。这些元数据足以核对既有划分，不承诺只靠原图目录能一条命令复原所有历史清洗阶段。后续训练需先验证数据完整性，详见仓库`docs/HANDOFF.md`。
