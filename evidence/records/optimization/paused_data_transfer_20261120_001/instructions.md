# 给接手AI：实际训练图片从哪里来

你的工作区是 `E:/file/gitdesktop/pangoriscv`。提交 `b0e0f494` 中有模型和标注，但没有照片；扫描旧图片只匹配3张并非路径修改能解决。照片需要从原电脑取得下述实际数据包，不必重新搜索下载公共数据集。

## 原电脑已准备的数据包

原电脑：`D:/FPGA_Project/zi_guang_tong_chuang/训练数据交接_20261120/实际训练图片和标注_11278.zip`。

同目录还有 `.zip.sha256`、`.zip.json` 和 `transfer_training_data.py`。把这些文件通过移动硬盘、局域网或网盘私下传到新电脑，例如 `E:/file/训练数据交接_20261120/`。这个约3.5GiB的照片包不进Git，保留照片原来源信息。

本次成品：3,784,183,375字节；整包SHA256为 `0dfc2e2aff749531a653d9d4eb28dcbcbe31c88a747f643ccf2efb5b4f5ceb31`。已在原电脑新目录实际导入完整包，11,278张图、21,189份标签及160张校准映射检查通过。每条原始图片与标签SHA均核对，训练未启动。

**之前说直接复制dataset_001不够准确：验证列表中的实际图片仍指向原电脑旧tmp目录。** 本数据包逐条读取训练时真正消费的 `prepared_image` 路径，收集这些分散图片及对应的五类标签，按SHA校验；不需要在新电脑猜旧tmp路径。不要从原始来源标签重新映射类别，来源标签可能还处于旧类别体系。

包内应有：

- 9,349个训练图文件身份、1,929个验证图文件身份，合计11,278张去重图片。
- 每轮19,260条训练路径、1,929条验证路径对应的21,189份原始YOLO标签，顺序与原manifest一致。训练重复路径是采样别名，不是新照片。
- 原manifest的压缩原件、导入索引、原固定160张train量化校准身份清单、导入工具。

不包含最终test图片。9,349训练身份中含派生视图，不能宣传为新增独立原图，也没有达到2万张独立照片目标。

## 新电脑：先导入并核验，不启动训练

先更新仓库以取得本说明和导入工具。工具只使用Python标准库，不需要先安装Torch。若不能更新Git，用数据包旁边或包内的同名工具。

PowerShell执行（按实际收到包的位置修改archive）：

```powershell
Set-Location 'E:/file/gitdesktop/pangoriscv'
git pull --ff-only
$archive = 'E:/file/训练数据交接_20261120/实际训练图片和标注_11278.zip'
$expectedSha = ((Get-Content -LiteralPath ($archive + '.sha256') -Raw).Trim() -split '\s+')[0]
py -3 project/trash_sorting/tools/overnight/transfer_training_data.py import --archive $archive --sha256 $expectedSha --out 'E:/file/gitdesktop/pangoriscv/build/transferred_training_20261120/dataset_001'
```

若`py -3`不可用，将其替换为本机`python`或完整Python路径。`--out`必须是不存在的新目录；工具不会覆盖旧数据。空间至少预留图片展开所需约4GB；NTFS会用硬链接恢复回放，不能创建硬链接时会回退复制并需要更多空间。

成功输出必须包含 `PASS_IMPORTED`，并生成 `transfer_result.json`，应满足：

```text
status = PASS_IMPORTED_HASH_VERIFIED
unique_train = 9349
unique_val = 1929
train_draws = 19260
val_draws = 1929
calibration_images = 160
training_started = false
```

工具验证整包SHA（传入`--sha256`）、每张图片SHA、每份实际标签SHA，重建`images/train`、`images/val`和`labels`，生成新电脑绝对路径的`train.txt`、`val.txt`、`data.yaml`、`manifest.json`、`calibration_reference.json`。160张校准照片保持原身份、类别和顺序，只迁移路径。

原manifest的解压SHA固定为 `86ea104719d0694bb52c1ab5b4576b7db3f4ef216fffc214755802fec4c38cba`。新manifest因为路径迁移，SHA必然改变，不能用删除断言的方式绕过；保留原manifest作为身份依据，明确记录旧→新路径和新SHA，再生成新实验plan。新数据目录的 `manifest.original.json.gz` 和每条 `original_transfer_prepared_image` 保留原始证据。

## 图片齐了以后交接哪些训练参数

先读仓库 `00_暂停交接_20261120.md`，当前用户已要求暂停，取得数据本身不代表自动重启授权。当前检查点完成1轮、目标20轮，学生/EMA/optimizer都在；第2轮未保存部分已丢弃。

权重在仓库 `project/trash_sorting/training/candidates/allnetwork_background_20epoch_20261120_001/`：`resume_last.pt`是暂停检查点，`original_teacher.pt`是原始冻结教师。不要把学生当教师。现有训练脚本没有完整optimizer-resume入口，直接`--weights resume_last.pt`属于warm start；如果接到继续训练要求，先实现并验证optimizer、EMA/updates、start_epoch=1及原20轮调度恢复，再建新实验。不得直接重跑原20轮或覆盖旧证据。

当前数据包解决训练/基础val/固定160图校准。原完整评估还依赖712张公开dev、77张手持、27张复杂背景及基线数值结果，它们不在本包。下一位可以先将训练数据准备好；后续要复现全部验收时，另行从原电脑迁移这些固定评估资源，不能省略后声称全部通过。
