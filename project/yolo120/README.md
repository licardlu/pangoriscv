# YOLO120 构建入口

目标器件：PG2L100H-6IFBG676。CPU/加速器使用独立 PPLL：27 MHz × 58 / 13 =
120.461538 MHz；视频与 DDR 保持各自时钟，通过既有 CDC 通道交换数据。
完整 85 个模型算子、六类模型、320×320 输入保持不变。

当前验收结论和限制见 [统一状态记录](../../docs/verification/yolo120-status.md)。
原始压缩包来源见 [导入清单](../../docs/verification/imports.json)。

## 构建与检查

以下命令从仓库根目录执行，`python` 指 Python 3.11+。需要 RV32 bare-metal GCC、
PDS 2022.2-SP6.1，以及用于仿真的 ModelSim。无需重新导出/训练模型。
可用 `--gcc-prefix`、`--pds`、`--modelsim` 指定安装路径，也可以使用本机
`tools/local-tools.json` 中的 `gcc_prefix`、`pds`、`modelsim`。

```powershell
python project/yolo120/tools/build.py --name yolo120-new --run
python project/yolo120/tools/check.py --build project/yolo120/build/yolo120-new
python -m unittest discover -s project/yolo120/tests -v
python project/yolo120/tools/check_native.py --cc C:/toolchains/mingw64/bin/gcc.exe --out project/yolo120/build/native-001
```

每次实现必须换新的 `--name`，脚本拒绝覆盖已有目录。去掉 `--run` 仅生成固件、
源文件快照与 flow.tcl；`--synthesis-only` 不做布局布线，不能作为时序通过依据。
`check.py` 各用例也拒绝覆盖旧输出，重复回归需使用新的构建快照。

布局/布线 A/B 可显式使用 `--gplace-seed`、`--groute-seed`（均默认 2），
种子写入 `inputs.json` 和 `flow.tcl`。例如下一版 009 保持 008 的区域、
RTL、固件与时钟，仅将布局种子改为 20，布线种子保持 2：

```powershell
python project/yolo120/tools/build.py --name yolo120-009 --cpu-region 50 105 20 100 --gplace-seed 20 --groute-seed 2 --run
```

种子变化只是物理实现候选，不能保证收敛；最终仍按全角时序、区域实际生效与
匹配的程序镜像验收。不要在已经创建的构建目录重跑该命令。

固件 ELF 与八路 64 KiB RAM 镜像逐字节核对；PDS compile 必须加载全部八路镜像。
发布门禁检查构建目录内最终的 `report_timing/yolo_camera_top.rtr` 的快慢角 setup/hold，
以及其他约束，不用布局布线中间的 hold-fix 快照冒充最终结果。
`build.py` 仅构建，不会下载或烧写开发板。

## 摄像头预处理提速

`rtl/video_ai_frontend.v` 新增快照顺序读取，`sw/platform_main.c` 默认启用。
每个像素由“写地址 + fence + 读 RGB565 + 三通道软件缩放”改成一次寄存器读取。
硬件查表严格实现原有 RGB565 扩展及 `(channel*127+127)/255`，不改模型输入含义。
没有新增一份帧缓存。

| 加速器偏移 | 语义 |
|---|---|
| `0x78` 写 | 设置快照像素地址；与同拍自增冲突时写优先 |
| `0x7c` 读 | 原有 RGB565 静态读取，地址不变 |
| `0xbc` 读 | 返回 `0x00BBGGRR` int8 输入；每个 AXI-Lite AR 握手只自增一次 |

有效像素 0..57599，读完后地址饱和在 57600，越界返回零。
AXI-Lite 保留单个未完成读事务，在返回背压期间不会重复推进地址。
UART 命令 10 的 address=0/1 选择旧预处理/顺序读取，回复 4 字节小端值。
命令 9 的既有运行时选项仍为 0..63；命令 8 保留阶段与每个算子的周期剖析。

## 上板验收

先完成匹配位流的最终时序与镜像检查，再下载候选。下列工具要求显式串口，
不自动寻找或占用开发板。需要 `pip install pyserial`。

```powershell
python project/yolo120/tools/program.py --implementation project/yolo120/build/yolo120-new --out evidence/records/optimization/yolo120/program-new
python project/yolo120/tools/benchmark.py --implementation project/yolo120/build/yolo120-new --port COM34 --upload-model --baseline --frames 10 --out evidence/records/optimization/yolo120/board-new
python project/yolo120/tools/camera_preview.py --implementation project/yolo120/build/yolo120-new --port COM34 --out evidence/records/optimization/yolo120/camera-new
```

`COM34` 为用户确认的当前 UART。`program.py` 检查最终 STA 和位流哈希后仅下载 SRAM，
不写 Flash；`--scan-only` 可只读扫描 JTAG。模型在 DDR 中，板卡/DDR 复位后需重新上传。
`--implementation` 必须指向已通过最终时序、位流哈希一致的构建；先下载该份位流。
记录会绑定主机候选哈希，但现有协议不能自动证明板上正在运行的位流身份。
已经上传时可省略 `--upload-model`，设备仍会独立校验模型 CRC。
测速保存每帧检测结果、原始回复、阶段和 85 个算子的周期数据。
旧/新预处理各预热一次，之后每帧都测；默认检查新模式全部测量帧 ≤1.2 秒，
对应用户接受的约一秒刷新，可用 `--target-seconds` 改阈值。时间包含取图、推理、解码、提交显示和请求/回复开销；
不包含一次性的串口模型上传与 CRC 校验。软件回归和仿真不能替代这项实测。
每帧必须有全部 85 个算子的非零计时，阶段与算子计时相互核对。
`camera_preview.py` 通过现有 DDR 读命令保存冻结输入的 80×45 抽样图和检测框，
用于检查实际模型所见画面；它是归一化输入的重建，不能当作 HDMI 屏幕截图。

用 `tools/collect_evidence.py --build <实现目录> --out <新证据目录>` 归档输入哈希、
固件、日志、最终报告和验证记录。失败实现须给 `--failure-reason`，不会被归档工具标成通过。

这里只复用 UI 包中的摄像头、HDMI、DDR 源文件/IP 与边框坐标修正，
尚未启用白色分屏 UI、舵机或音频业务。
