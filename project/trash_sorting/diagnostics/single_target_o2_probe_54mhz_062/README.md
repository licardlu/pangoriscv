# 原四桶54 MHz局部O2与连续测速候选062

已通过最终十项多角STA、镜像加载、ai_clk54端点及整机面积，尚未上板。位流SHA `3fdc4bd34db37cfa78d972dbf32afbc6b5021d1cecbb70ac91ae3a5dd8415051`。模型与042相同，无hand内部类，不能声称手定位已改善。

cmd12只取图、推理、解码和同一单目标选择，不提交题目或显示。正常cmd6/7及状态栏、四桶色、舵机1111与到位停5秒保持。08:00后可用restore_full_board.py，release-dir指定本目录；相同原模型数值fixtures为build/trash_four_bin_numeric_20261112_003/fixtures，追加--verify-input --collect-profile --probe-frames 10。板上平均范围不含显示/语音/答题/舵机，必须读取实际下载证据后才能声称已完成。042恢复包继续保留，SRAM掉电需重新加载。
