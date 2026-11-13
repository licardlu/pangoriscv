# 用户要求重载最佳已验收版

## 最新结论：091已完整恢复

用户确认重插电脑端USB串口后，只读cmd8收到372字节有效回复。091重新下载同一062发布位流，program1、器件00602899、配置即时/5秒均081ffca0、disconnect1。配套模型上传184.344秒，板端CRC0x209305e5通过；取图两路径CRC同为0xf22f9b90，四固定输入1/23/38/76真实板载推理均与数值oracle核对通过。

摄像头实时推理返回可回收目标（score0.7246201，框125.718/261.879/538.166/667.212），cmd7已确认进入自动模式。由于此时已经发起一道可回收题，正常等待用户答案/开盖/停留/关闭后再开始下一帧；`autonomous_frame_received=false`与`first_question_pending=true`是该等待状态，不是下载失败。未发送答案键、不远程假定机械验收通过。

当前板上明确为062局部O2四桶完整版，CPU/AI54MHz、外围27MHz，原四桶模型，无新手定位候选。保留状态栏、绿蓝红灰框、最大面积单目标/整轮锁定、舵机1111及到位5秒关盖。答案键/桶码1绿厨余、2红有害、3灰其他、4蓝回收；答对/错只影响语音、均开识别桶。没有重新布线或写Flash，掉电需重载SRAM和模型。当前实际模型/位流身份与本次通过证据统一在 `evidence/records/trash-user-reload-20261113-091/acceptance_summary.json`，详细UART、JTAG、四输入数值和profile均保留同轮目录。

## 前期失败与恢复过程

选择062 full_54mhz_20261113发布包与原四桶模型，不采用离线退化的手定位/主体线索候选。发布包10项SHA全部复核通过；位流3fdc4bd34db37cfa78d972dbf32afbc6b5021d1cecbb70ac91ae3a5dd8415051，配套模型ea70896cec65e802cd063525ba8a09814b10c52b65a36822abbc0d7854ac447e、预期CRC0x209305e5。

088和089两次实际JTAG SRAM program均返回1，器件00602899，配置即时与5秒后均081ffca0，disconnect1。没有重新综合/布线，没有写Flash。

088/089时COM34固件状态命令均零字节无回复：088初始等待期间终止host loader，后续3次只读cmd8各4秒均无回复；089重新配置同SHA后增加1秒串口打开等待、10秒读超时，仍零字节。两轮都在模型写入前失败：model_loaded=false、model_crc_verified=false、autonomous_started=false；这两轮不能沿用076历史成功当完整验收。

用户重启后090同样配置成功、串口零回复，用户确认实时画面和心跳正常。尝试仅重启指定CP210x PnP设备被Windows拒绝访问；用户随后重插USB串口，状态命令恢复，091完成以上全部验收。没有覆盖088/089/090；当前没有下载器/串口进程继续占用端口。

原始证据 `evidence/records/trash-user-reload-20261113-088/` 和 `evidence/records/trash-user-reload-20261113-089/`，后者 `recovery_status.json` 汇总当前状态。画面和机械动作尚未现场复验。
