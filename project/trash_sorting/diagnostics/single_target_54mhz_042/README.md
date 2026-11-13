# 单目标四桶54 MHz恢复包

042已于北京时间2026-11-13凌晨完成SRAM下载。`manifest.json`绑定同一位流、最终多角时序、整机资源与配套`model/`。全部数值/串口证据位于仓库`evidence/records/trash-single-target-program-20261113-042/`。

本包是原四桶模型加新单目标/整轮锁定代码，无hand类，不包含新增038照片重训。每题只框一个最大有效物体，锁定到答题、打开对应桶、到位5秒、关闭结束。按键1绿厨余、2红有害、3灰其他、4蓝可回收；答错仍开识别对应桶。状态栏与舵机1111校准保留。

恢复使用`tools/restore_full_board.py --release-dir project/trash_sorting/diagnostics/single_target_54mhz_042 --port COM34 --pds <PDS bin> --out <新的证据目录>`。它依次JTAG下载、即时/5秒状态核验、配套模型上传/CRC和相机启动；可追加`--fixtures build/trash_four_bin_numeric_20261112_003/fixtures --verify-input --collect-profile`做数值核验。不要把未完成手部候选覆盖进本包。

本次板上单次空输出相机请求1.781秒，未测本版多帧平均或实物准确率。SRAM与模型均需在掉电后重新加载；本包不烧Flash。
