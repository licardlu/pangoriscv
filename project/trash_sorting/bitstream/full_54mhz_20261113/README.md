# 四桶完整应用：2026-11-13实板交付

062局部O2，原四桶模型，CPU/AI54MHz，外围27MHz。已实际SRAM下载，通过最终多角STA、资源、即时/5秒JTAG、模型CRC、取图一致性、四固定输入数值、100帧相机诊断和自动识别启动；未烧Flash。位流SHA `3fdc4bd34db37cfa78d972dbf32afbc6b5021d1cecbb70ac91ae3a5dd8415051`，模型SHA `ea70896cec65e802cd063525ba8a09814b10c52b65a36822abbc0d7854ac447e`、CRC `0x209305e5`。

预热后100帧平均1.705371秒、最慢1.719000秒，当前相机场景为空输出；不含显示提交/语音/答题/舵机，不保证所有实物或完整游戏两秒。此模型没有hand内部类，手持小电池测试仍差，不能称手部优化完成。保留单目标最大有效面积、整轮锁定、状态栏、四桶色、舵机1111方向和到位停5秒。

下载并加载本包模型：从仓库根目录运行 `project/trash_sorting/tools/restore_full_board.py`，显式指定 `--release-dir project/trash_sorting/bitstream/full_54mhz_20261113 --port COM34 --pds D:/FPGA_Project/zi_guang_tong_chuang/pds/PDS_2022.2-SP6.1/bin --out evidence/records/<新的目录>`。加入 `--fixtures build/trash_four_bin_numeric_20261112_003/fixtures --verify-input --collect-profile --probe-frames 10` 可重做数值和测速。Python须安装pyserial，本机可用Codex bundled Python。SRAM掉电失效，需要重载本包，不能混用历史六类模型。

按键/桶码1绿厨余、2红有害、3灰其他、4蓝回收。模型类0/1/2/3映射桶码1/4/2/3；纸板纸张均蓝桶。答对/错只影响语音，均打开识别对应桶。

最终证据 `evidence/records/trash-final-program-20261113-076/`；报告 `docs/verification/trash-night-final-20261113.md`。现场画面/实物识别/机械动作待用户验收，manifest未冒充物理验收通过。
