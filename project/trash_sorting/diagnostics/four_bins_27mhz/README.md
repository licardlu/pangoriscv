# 四桶27 MHz自动验证候选

已实际SRAM下载，板端模型CRC、四桶固定输入数值、10帧计时和自动首帧均通过，10帧均值3.598400秒。物理四类识别、答题、语音和舵机的新版本现场确认尚未记录。

类别0绿厨余、1蓝回收、2红有害、3灰其他；按键1绿、2红、3灰、4蓝。采用独立状态栏和原已验收的舵机校准。

此目录配套model可在未来清理build后恢复。下载使用tools/restore_full_board.py并显式传入--release-dir指向本目录。SRAM/DDR掉电丢失，未烧Flash。完整证据与精度限制见docs/verification/trash-four-bin-deployment-20261112.md。
