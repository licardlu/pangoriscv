# YOLO120 集成验收状态

本文件是当前集成结果与待验收事项的唯一状态入口。按用户指定顺序推进：
120 MHz 整合及约一秒刷新实测 → 识别能力检查与改进 → 白色界面合并实时摄像头 →
四按钮答题、四舵机及音频。缺少外设时记录待测项并继续，不用模拟结果替代上板结果。

## 当前实现

### 2026-11-03 实时板测更新

- 候选 `yolo120-006` 在新版 CPU 上已完成一次完整实验：CPU/AI 时钟为
  `120461538 Hz`，快预处理的 10 个测量帧为约 `1.016–1.031 s/帧`，包含取图、
  85 算子推理、解码、显示提交和 UART 往返。该数字是实验观察值，不是正式验收，
  因为候选最终 STA 的 `ai_clk` setup WNS 为 `-1.540 ns`（1530 个失败端点），
  DDR setup WNS 为 `-0.088 ns`，因此不能作为可靠发布位流。
- 连续摄像头实验已经实际读到非全黑的相机输入；保存于
  `evidence/records/optimization/yolo120/experiment-camera-006`。图像亮度很低，
  目前没有可靠目标框，不能把“固件响应”当成识别准确率或 HDMI 亮屏证明。
- 连续运行约 189 帧后 UART 请求超时，说明该 setup 未闭合候选不能长期稳定运行；
  实验输出已保留，正式 `project/yolo120/tools/program.py`、`project/yolo120/tools/live.py` 仍拒绝时序未通过候选。
- 用户报告屏幕未亮。HDMI VIC4 彩条诊断的寄存器状态和内部时序都通过，但没有外接屏
  的目视或采集证据；因此当前 HDMI 仍标记为“未确认亮屏”，不声称已经解决。

- `project/cpu120`：来自提供的新版 CPU 包，当前存在的冻结文件哈希全部匹配。
  ZIP 缺少原发布清单中列出的部分历史文档、参考测试与构建文件，
  因此不能把原完整发布包验证标为通过。新入口独立校验实际使用的 RTL/配置/约束。
- `project/yolo120`：独立、可重定位的整机入口，实际使用新版 CPU 和 64 KiB RAM。
  模型参数与 85 个算子未裁剪，保留六类模型。顺序读取优化默认开启，支持 UART A/B 切换。
- 实现 `yolo120-001`：已完成到 Device Map，但缺少 SCCB 时钟分析，不作交付候选。
  Device Map 为 LUT 25,680 / 66,600、FF 21,653 / 133,200、
  Distributed RAM 290 / 19,900、DRM 107.5 / 155、APM 124 / 240。
  这是整机应用资源，不能与独立 CPU 的面积预算或 CoreMark/LUT 直接混算。
- `yolo120-002`：补充 SCCB 时钟后，被 PDS 的周期必须小于 100000 ns 限制拒绝；
  失败日志及输入已归档于 `evidence/records/optimization/yolo120/yolo120-002`。
- `yolo120-003`：最终多角 STA 失败，禁止下载。物理 SCCB /2500 不变，使用更严格的
  /2400 分频作分析模型。Device Map 为 LUT 25,683、FF 21,654、LUTRAM 290、
  DRM 107.5、APM 124；比 001 多 3 LUT 和 1 FF，未声称严格面积不增。
  CPU/加速器 ai_clk 慢角 setup −2.474 ns、1662 个失败端点；DDR 跨钟 setup
  −0.020 ns、1 个失败端点。完整失败证据已保存至
  `evidence/records/optimization/yolo120/yolo120-003`。位流生成不能替代时序验收。
- `yolo120-004`：已中止，不能作为区域布局试验结论。`dev_map` 重写了注册的
  `cpu_region.pcf`，PNR 实际没有执行 `def_region` / `def_inst_region`。
  输入与失败原因已归档至 `evidence/records/optimization/yolo120/yolo120-004`。
  构建流程改为保留独立只读区域输入，在映射后追加到 PCF；验收同时核对输入哈希、
  活动 PCF 和 PNR 命令执行成功记录，防止约束静默丢失。
- `yolo120-005`：包含 HDMI PLL 50% 占空比修正，综合/映射完成。区域命令已进入
  PNR，但映射后不存在 CPU 层级实例，报 `PhysicalConstraintEditor-0023` 后停止。
  失败证据在 `evidence/records/optimization/yolo120/yolo120-005`，没有可下载位流。
  后续从同次映射导出实际叶单元，逐个约束；门禁也拒绝“报错后仍打印 successfully”的工具日志。
- `yolo120-006`：映射后生成 9,476 条 CPU 叶单元区域约束，并完成布局布线。
  最终慢角 Setup WNS 为 `-1.540 ns`、1,533 个失败端点（其中 ai_clk 1,530、
  DDR 3），`timing_pass=false`，未通过时序门禁。该次构建的 `acceptance.json`
  仍写 `routed: false`、`bitstream: null`，与已生成位流的实验记录不一致；
  位流身份以实验记录的 `1d57861e…` 为准。
  中间布局中 9,407 个实际 CPU 单元均在指定区域；这不是最终物理布局或时序验收。
  对该次冻结源码运行的八项 RTL 检查全部通过，包括实际固件 CPU 启动和 UART 协议。
- `yolo120-008`：在 006 基础上替换 `059_ms7210_ctl.v`（MS7210 AVI 元数据修正）并重新生成固件后的实现。
  最终时序与资源数值与 006 相同（LUT 25,683、FF 21,654、DRM 107.5、APM 124、
  Distributed RAM 290；WNS `-1.540 ns`、1,533 个失败端点，TNS `-668.634 ns`），
  `acceptance.json` 记录 `routed: true`、`timing_pass: false`、`board_verified: false`。
  保留的汇总在 `evidence/records/cleanup_20261103/build_reports/project/yolo120/build/yolo120-008/`。

## 已验证

- 新固件 RV32IM 编译成功；text 40,322、data 448、bss 14,912 字节，
  链接器的至少 8 KiB 栈余量检查通过。
- ELF 与八路 RAM 初始化镜像一致；PDS compile 日志确认八路镜像全部加载。
- ModelSim 八项通过：顺序读取、bulk、MMIO、快照、CDC、DDR 桥、TL/AXI-Lite、
  实际新固件的 CPU 启动与 UART 命令 10 的 CRC 请求/回复。
- 顺序读取覆盖全部 65,536 种 RGB565 颜色、地址推进、背压、静态读取与越界。
- 原生 C 四项通过：性能优化数值对照、运行时后处理、解码/NMS、边框坐标。
- 十三项 Python 门禁测试通过：延迟三项、最终时序五项、面积五项。
- 白色分屏合成仿真 `video-002` 通过：完整 1280×720 帧、右侧全部
  640×720 像素与实际前端 OSD 流一致，额外核对绿色边框与白色文字；
  图片与日志在 `evidence/records/optimization/yolo120/video-002`。
  这是合成输入验证，尚未证明业务顶层、真实摄像头或外接屏幕出图。
- JTAG 只读扫描成功，器件 ID `00602899`，证据为
  `evidence/records/optimization/yolo120/jtag-scan-001`。用户确认 COM34 为 UART，
  COM37/38 为 JTAG；JTAG 使用 PDS 工具协议，不按普通串口发送下载命令。
- 独立 HDMI 彩条诊断 `hdmi-startup-001` 已通过完整帧与 UART 仿真、PDS 最终
  多角时序，并实际下载到 SRAM。COM34 连续六次返回
  `HDMI720 L=1 R=1 I=1 RD=81 A=0502`，确认 PLL 锁定、HDMI 复位释放与初始化结束。
  位流 SHA256 为 `1ba63b6c0ac4014df8af03c7aa4867b27779f60ee8cbf35a6fae91f4fed93218`。
  构建证据为 `evidence/records/optimization/yolo120/hdmi-startup-001`，实际下载与串口
  证据为 `evidence/records/optimization/yolo120/hdmi-startup-program-001`。
  这是持续运行的 720p 彩条诊断，不是摄像头或 YOLO；没有 HDMI 采集设备，屏幕实际出图仍待目视确认。
  用户提醒启动后，已再次实际下载同一已验收诊断位流，JTAG scan/program/after
  均为 1，COM34 再次连续六行确认初始化结束。证据在
  `evidence/records/optimization/yolo120/hdmi-startup-program-002`；当前板上仍运行此诊断。
- 调查发现原 HDMI PLL 输出 74.25 MHz，但 `STATIC_RATIO0=16`、`STATIC_DUTY0=8`，
  最终 STA 波形确认为 `{0.000 3.363}`，即约 25% 高电平。已同步修正 PLL Verilog
  与 IP IDF 的 duty0 为 16，并增加源参数一致性检查。`hdmi-startup-002` 的最终
  多角 STA 通过，Clock Summary 为 period 13.468 ns、waveform `{0.000 6.734}`；
  完整帧/UART仿真通过。候选已 SRAM 下载，JTAG scan/program/after 均为 1，COM34
  下载后连续八行报告 `HDMI720 L=1 R=1 I=1 RD=81 A=0502`。PDS 位流 SHA256 为
  `161d5586e6c5d0069a8b4837b876cebabecd01ba7b1bb4e26a5efae0392325db`。
  构建证据和板上证据分别在
  `evidence/records/cleanup_20261103/build_reports/project/yolo120/build/hdmi-startup-002` 与
  `evidence/records/optimization/yolo120/hdmi-startup-program-004`。屏幕实际出图仍待目视确认。
  再次读取 COM34 得到连续七行正常状态，确认诊断仍在运行；记录为
  `evidence/records/optimization/yolo120/hdmi-running-001`，仍不代表实际亮屏已确认。
- 状态扫描诊断 `hdmi-scan-001` 持续输出 720p 彩条并只读扫描 16 个
  HDMI 状态寄存器。完整帧、真实 UART 波形和状态扫描仿真均通过，最终多角 STA 通过。
  位流 SHA256 为 `4f4aaa4e7ee3093e13ab2061598100a5fc3cf9c30082fa673bada86a2805f953`。
  实际 SRAM 下载证据在 `evidence/records/optimization/yolo120/hdmi-scan-program-001`，
  JTAG scan/program/after 均为 1。连接寄存器 0502=81、时序稳定 051D=50、
  视频静音 0507=00、数据驱动 091F=07、PHY/时钟驱动 0920=5E。
  状态含义参考公开 MS7210 Linux 驱动，不能代替外接屏幕出图验收。
  2026-11-03 15:02 再读 COM34，1.2 秒获得 121 行初始化正常状态，确认程序仍在运行，
  证据为 `evidence/records/optimization/yolo120/hdmi-running-002`。用户报告黑屏，仍作为未解决问题。
- 已修正原 MS7210 初始化表中的 AVI 元数据：原 4:3 / VIC 0 改为实际输出的
  RGB、BT.709、16:9、720p60 / VIC 4，校验和从 06 改为 B3。
  `hdmi-vic4-sim-002` 检查真实初始化控制器发出的完整 AVI 字节及校验和通过，
  完整彩条帧、UART 波形和状态扫描也通过。失败的首轮测试记录保留：测试最初假设
  49 次写，真实 vendor FSM 在 WAIT 边界会重复一次幂等的 000B=00 写，实际为 50 次，
  AVI 仍为准确的 14 字节；测试已按实际事务修正。
  `hdmi-vic4-001` 最终内部多角 STA 通过，外部显示接口未进行电气测量。
  位流 SHA256 为 `985cefc8588f7cba537065a001c704d011c061dcff45e1364b58c77ed129118e`。
  已实际下载并启动此位流，JTAG scan/program/after 均为 1，随后 COM34 三秒读取
  299 行初始化正常状态。当前板上运行这份诊断；屏幕出图仍未确认。
  实现与下载证据分别在 `evidence/records/optimization/yolo120/hdmi-vic4-001` 和
  `evidence/records/optimization/yolo120/hdmi-vic4-program-001`。
  本次修正没有改变已冻结并在布线的 `yolo120-006` 源快照。

## 尚未验收

- 整机 120.461538 MHz 的最终多角 setup/hold；独立 CPU 历史时序不能替代整机结果。
- 新版硬件上的完整 85 算子推理与检测正确性。连续帧已有 `yolo120-006` 的 10 帧
  实验观测（快速预处理 `1.016–1.031 s/帧`，中位数 `1.016 s`，见本文件开头与
  `evidence/records/optimization/yolo120/experiment-yolo120-006/`）；自动检查默认
  允许至 1.2 秒，这是约一秒的工程容差，非用户硬性指标。该候选时序未闭合且在
  连续运行中曾超时，因此只能作为实验观察值，不作验收。120 MHz 整机尚无带标注
  样本的精度评测；`docs/verification/yolo-technical-data.md` 记录的 18 张子集评测
  是在 27 MHz v3 位流上做的。
- 实际新固件的完整模型端到端仿真尚未运行；当前 CPU 仿真验证启动与控制协议，
  数值测试验证单元及后处理。原 ZIP 不包含完整 CPU oracle 输入，不能宣称完成该对照。
- HDMI 输出实测。导入 YOLO README 记录旧显示器黑屏，当前集成尚未证明解决。
- 当前六类模型为 biodegradable/cardboard/glass/metal/paper/plastic，未覆盖有害与其他垃圾。
  不能仅通过改标签宣称四类识别完整；准确率需要有标注样本验证。
- 舵机位置顺序固定为 0 蓝色可回收、1 灰色其他、2 红色有害、3 绿色厨余；
  对应四按钮，答对后对应盖子 0→90° 再关上。外设未连接，最后进行接线实测。

## 历史口径

导入 `extensions/yolo/README.md` 记录旧版 CPU/加速器均为 **27 MHz**、
摄像头请求 **4.953 秒**。这属于原作者记录，ZIP 没有带上其声称的全部发布目录，
不能冒充本次复测。单纯按频率缩放到 120.461538 MHz 约为 1.11 秒，
只用于解释为什么还需要优化预处理，不是性能承诺。

已实际执行配套摄像头诊断、独立彩条诊断与 `yolo120-006` 实验候选的 JTAG SRAM 临时下载。
006 为 `release_accepted=false` 的实验位流，不是正式发布版本。未执行 Flash 烧写、
Git 提交或 GitHub 推送。
