# 27 MHz完整应用：独立状态栏版

当前发布SHA256：`25f22997ed94facc95b58f1759fc0fbe60b3ac5a8b9335871b203078d71b4fbb`，已实际SRAM下载。顶部48行保留动态操作状态；完整720行摄像头视野缩采样至下方1280×672，状态文字不覆盖视频。关闭物品细分类文字，只使用桶色框。

此次保持原六通道模型和此前顺序预处理提速固件，纸板/纸张统一输出paper，五个有效类别；`FOUR_BIN_CLASSES=0`。板上模型仍只有绿/蓝桶覆盖，红/灰新四桶浮点候选尚未部署。照片离线评估不能作为板上模型准确率，见`docs/verification/trash-personal-photos-20261112.md`。

摄像头、HDMI、CPU/AI、答题、语音和四路FPGA直驱舵机均包含在完整应用中。此前已实测校准：四路关1500 us / 开500 us，约1秒打开、到位停5秒、约1秒关闭；答对与答错只改变语音，均打开识别结果对应的正确桶。完整应用按键用于回答：1绿厨余、2红有害、3灰其他、4蓝回收。

本轮004最终多角时序10项全部通过，慢角Setup最差0.212 ns、快角Hold最差0.184 ns。最终布线资源28491 LUT、22071 FF、290 LUTRAM、132.5 DRM、123 APM；完整应用预算及器件容量通过。实现证据：`evidence/records/optimization/trash_status48_20261112_004/`。

下载证据：`evidence/records/trash-status48-20261112-program-002/`。JTAG返回program=1，即时及5秒状态均081ffca0，正常断开；原模型CRC 0x3a4a5d5d通过，摄像头单次推理及自动首帧返回成功，两次检测列表均为空。用户于2026-11-12回复“正常，文字不挡画面”，确认本版界面显示正常、不遮挡摄像头画面；语音及实物开关盖不计入此次显示验收，manifest分别记录显示验收与整机验收。旧发布manifest在该证据目录保留。

此前同模型提速版平均每帧3.726462秒，属于旧位流10帧预热后测量；本版仅记录单次请求3.750秒，不作为新的平均速度。详见`docs/verification/trash-speed-optimization.md`。当前实施和界面仿真见`docs/verification/trash-display-four-bins.md`。

重新下载及恢复原模型（仓库根目录，Python需安装pyserial；本机可用Python310）：

```powershell
& 'C:/Users/Twinkle Nebula/AppData/Local/Programs/Python/Python310/python.exe' project/trash_sorting/tools/restore_full_board.py --port COM34 --pds D:/FPGA_Project/zi_guang_tong_chuang/pds/PDS_2022.2-SP6.1/bin --out evidence/records/<新的唯一目录名>
```

SRAM位流及DDR模型掉电均丢失。本次未写Flash。
