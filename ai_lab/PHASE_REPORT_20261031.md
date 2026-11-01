# Vexii CPU + AI 部署阶段报告（2026-10-31）

目标：OV5640 → 320×320 → CPU 调度 YOLO → 加速器卷积 → CPU 检测头/解码/NMS → HDMI。
本文件只记录**已执行**的动作和**实测**数字。没有板上测量的一律标注为未验证。

---

## 一、阶段一：全 SoC CPU 通路 —— 完成

### 1.1 现象（修复前）

`gen/integration/vexii_soc/firmware_boot/`（旧日志已覆盖，结论保留在此）：

```
FW_A  t=92455000 addr=10001008 data=0000006b        <- 写分频 107
FW_A  t=92555000 addr=1000100c data=00000007        <- 写 8N1
FW_D  t=92775000 data=000000xx                      <- 读数据寄存器 = X
UART_FIFO pushptr=0 popptr=0 occ=0 rdata=xx         <- 队列空的
...
FW_PROGRESS sent=24 received=0 ... rx_occupancy=24
** Fatal: Vexii accelerator timeout
```

CPU 在 93 µs 连读 3 次后**彻底停止总线活动**（fetch 停在 7 个 burst），
而 300 µs 之后 24 字节才到，队列里躺了 24 字节没人取。

### 1.2 根因（两处缺陷叠加）

**缺陷 A：固件先读数据寄存器、后判有效位。**
`sw/platform_main.c` 原第 43-45 行：

```c
do { value=UART[0]; } while(!(value & (1u<<16)));
```

数据寄存器读**同时就是 FIFO 出队**（`TilelinkUartCtrl.v:342`
`io_read_queueWithOccupancy_io_pop_ready = bridge_read_streamBroken_ready`，
而 `bridge_read_streamBroken_ready` 只在 `busCtrl_doRead` 时为 1）。
所以队列空时读一次 = 弹掉一个垃圾字节 + 推进写指针。
在板上这会**静默丢字节**，不只是 X 的问题。

**缺陷 B：空队列时读回的是 FIFO RAM 的未初始化内容。**
`TilelinkUartCtrl.v:445`（CPU 团队源码，未改动）：

```verilog
busCtrl_rspAsync_payload_data[7 : 0] = bridge_read_streamBroken_payload;
```

`bridge_read_streamBroken_payload` 恒接 FIFO 的 `pop_payload`，与 `pop_valid` 无关。
空队列 → 未初始化 RAM → 仿真 X。X 进入 CPU 通用寄存器后经分支进入 PC，
Pipeline 随即无总线请求、无响应，整机死锁——这解释了"读一次就停"。
（注：bit16 有效位本身是确定的 0，X 只出现在低 8 位。）

### 1.3 修复

| 位置 | 修复 |
|---|---|
| `sw/platform_main.c:42-49` | 先读状态寄存器队列占用 `UART[1] bits[29:24]`，非空才读数据寄存器，**每次只弹一个字节** |
| `scripts/generate_vexii_soc.py` | 生成 SoC 时同时输出打过补丁的 `gen/integration/vexii_soc/TilelinkUartCtrl.v:445`：`({8{pop_valid}} & pop_payload)`，空读返回确定值 0。CPU 团队源码**未修改** |
| `scripts/run_vexii_smoke.py` | 编译时用补丁副本替换 vendor 副本 |

修复是根因修复：既不改协议、不硬编码数据，也没有绕过 UART。

### 1.4 证据

```
# VEXII_FIRMWARE_BOOT_PASS full YOLO firmware UART CRC DDR write/read
```
`gen/integration/vexii_soc/firmware_boot/transcript`

- 线上真实收发 40 字节（`pushptr=40 popptr=40`），32 字节回包含 CRC 校验通过；
- 整个 D 通道 X 计数 = 0（`grep -c "data=000000xx" → 0`）；
- DDR 经加速器 LOAD 窗口写入 1 次、读回 1 次，TB 校验值 `0xfedcba9876543210` 一致。

```
# VEXII_CPU_ACC_PASS real CPU configures convolution and checks DDR result
```
`gen/integration/vexii_soc/cpu_acc/transcript`

- CPU 写 12 个卷积寄存器 → START → 轮询 DONE → 读回 DDR 结果并比对。
- 这一条覆盖了：写 AI 控制寄存器、轮询完成、读结果、加速器写 DDR。

**阶段一结论：CPU 读 UART / 写 AI 寄存器 / 读写 DDR / 轮询 DONE / 读结果，五项全部在真实 SoC 上通过。**

---

## 二、阶段二：固定图片整网 —— 台架建成，被仿真器吞吐阻断

### 2.1 已建成（可复跑）

| 文件 | 作用 |
|---|---|
| `tb/tb_vexii_yolo.v` | 全系统台架：`vexii_ai_soc` + 真实 `conv_engine_axil` + 64 位 DDR 行为模型 + `video_ai_frontend`/`camera_snapshot` + UART 主机（YAI1/YAR1 组帧、回包解析） |
| `scripts/gen_vexii_yolo_sim.py` | 生成 `ddr_model.hex`（232,945 个 64 位字 = 真实 `model.bin`）、`frame.hex`（320×180 RGB565 固定帧）、`cmd.hex`（cmd=5 校验 + cmd=6 相机推理）、`expected.json`（Python 参考框） |
| `scripts/run_vexii_yolo.py` | 编译 + 装载固件 8 lane 初始化文件 + 运行 |
| `scripts/check_vexii_yolo.py` | 解析回包（28 字节/框）并与参考框比对 |

DDR 里放的是 `gen/integration/packed/model.bin` 的原字节，TensorRT 式"假数据"没有出现；
相机是文件驱动的 1280×720 RGB565 帧，走真实的 `camera_snapshot` 4× 抽取 + 固件 letterbox。

参考结果（Python，`Deployment.execute` 全 85 算子 + 与 `sw/yolo_decode.c` 同构的 Top-32/NMS）：

```
expected boxes: 1
  plastic 0.591 (291.9,186.2)-(1091.2,516.6)
```

### 2.2 实测仿真吞吐（阻塞点）

`gen/integration/yolo_sim/vsim.log`：

```
SIM_PROGRESS t=5000005000  reads=827
SIM_PROGRESS t=10000015000 reads=2112
SIM_PROGRESS t=15000025000 reads=3397
SIM_PROGRESS t=20000035000 reads=4683
```

两个数：

1. **每读 8 字节 = 389 个周期**（(4683-2112)/1e6 周期）。
   路径：`acc_wait_idle` → 写 `READ_ADDR` → 写 `READ_CTRL` → 轮询 → 读 `LO`/`HI`，
   每次 MMIO 约 20 周期。
2. **ModelSim 5.9k 周期/秒**（20 ms 仿真 = 2M 周期，耗时约 340 s）。

据此推算：

| 步骤 | 周期 | 仿真耗时 | 板上 100 MHz |
|---|---|---|---|
| cmd=5 模型 CRC（232,945 次读） | 90.6M | **4.3 小时** | 0.91 s（上电一次） |
| cmd=6 输入构建（102,400 次 8B 写） | ≈25–40M | 1.2–1.9 小时 | 0.25–0.40 s **每帧** |
| 85 算子（60 卷积 + 25 CPU 算子） | ≥100M | ≥5 小时 | 待测 |

整网一次仿真 ≥10 小时，且任何一处失败要重跑。这不是"再等等"，是工具选型问题：
Verilator 同类设计 0.5–2M 周期/秒，同样的场景 1–3 分钟。
本机 WSL 被安全策略禁止（`wsl.exe` 在黑名单），Verilator 无法安装，所以此路当前不可用。

### 2.3 顺带得到的真实结论（对板上同样成立）

CPU 只有 8 字节 MMIO 窗口搬数据，**每 8 字节 389 拍**。
仅 `capture_input()` 构造一帧 320×320×8B 输入就要 102,400 次写 ≈ 0.25–0.4 s。
`STATUS.md` 里 122 ms/帧（8.2 fps）的预算**没有包含这段搬运**，
所以那个数字不能作为板上帧率承诺。这不是仿真慢，是架构瓶颈：
模型加载、输入构建、CPU 后处理都挤在同一个 8 字节串行窗口上。

---

## 三、阶段三 / 四：未开始，缺件清单

### 3.1 摄像头 → YOLO（阶段三）

| 缺件 | 现状 |
|---|---|
| Vexii SoC 顶层没有视频通路 | `yolo_soc_top.v` 用的是 `pangoriscv_ai_soc`，不是 `vexii_ai_soc`；两者没有合并 |
| OV5640 初始化 | 无 SCCB/I²C 配置代码，芯片型号未从原理图确认 |
| DVP 接收 + 帧写 DDR | `hdmi1080p` 里有 720p60 采集链，但没有接进 AI 顶层；跨时钟域未做约束 |
| 320×320 输入映射 | 固件里 `decode_cfg.ratio=.25,pad_y=70` 是硬编码常量，未与视频缩放绑定 |

### 3.2 HDMI 显示（阶段三）

`video_ai_frontend.v` 的 OSD 已实现（8 框 + 5×7 字模，类别色），但：
- 只在 ModelSim 里跑过 `tb_video_frontend`，没有并入 SoC；
- 像素域与 CPU 域的 mailbox 没有加时序约束；
- `hdmi1080p` 实际是 **1280×720**，不是 1080p60，报告里不得写成 1080p。

### 3.3 综合 / 布线 / 上板（阶段四）

- Vexii SoC（`vexii_ai_soc` + `conv_engine_axil` + 视频）**没有 PDS 工程、没有约束、没有综合报告**。
- 唯一完整的整机综合是 `pds/camera_offline_20261030_185538`（pangoriscv 版本）：
  36,880 LUT / 85 DRM / 135 APM，**时序未闭合**（sys_clk WNS −2.268 ns，
  最差路径 `cpu/w_csr → data_cache/.../WE`；像素域 −0.398 ns；另有跨域与复位恢复违例）。
  该构建的 sbit 已被判废，不可烧录。
- 板子当前不在手上；`smart_sorting_quicktest` 的旧位流与本方案无关，不能当证据。

---

## 四、能不能修

| 问题 | 可修 | 代价 |
|---|---|---|
| UART 空读 X / 丢字节 | **已修** | 已完成，见 1.3 |
| 整网仿真跑不完 | 可修 | 换 Verilator（需放开 WSL 或装 Linux 机器），1–3 分钟/次；或直接在板上跑 |
| 8 字节窗口太慢 | 可修 | 加速器加批量/突发读写寄存器（一次 64–256 字节），仿真和板上同时提速 8–30×；需改 RTL + 固件 + 重新综合 |
| 视频未并入 AI 顶层 | 可修 | 合并 `yolo_soc_top` 与 `vexii_ai_soc`，接 DVP→DDR→张量，工作量大 |
| 时序未闭合 | 可修 | 先修 `w_csr→data_cache WE` 这条 CPU 路径（属 CPU 团队），再重跑 pnr |
| 板上实测 | **不可做** | 板子不在手上，无 JTAG/串口访问 |

---

## 五、日志与产物索引

| 内容 | 路径 |
|---|---|
| 阶段一 UART/DDR 通过 | `gen/integration/vexii_soc/firmware_boot/transcript` |
| 阶段一 CPU+加速器通过 | `gen/integration/vexii_soc/cpu_acc/transcript` |
| 整网台架编译/运行日志 | `gen/integration/yolo_sim/{compile.log,vsim.log}` |
| 整网台架输入 | `gen/integration/yolo_sim/{ddr_model.hex,frame.hex,cmd.hex,expected.json}` |
| 生成 SoC（含 UART 补丁） | `gen/integration/vexii_soc/vexii_ai_soc.v`、`TilelinkUartCtrl.v` |
| 整机综合（未闭合，pangoriscv） | `pds/camera_offline_20261030_185538/` |

---

## 六、批量 DDR 窗口（第一步）—— 写通，读有缺陷

新增寄存器（`rtl/conv_engine_axil.v`，旧 0x54/0x58/0x5C 与 0x60/0x64/0x68/0x6C 完全保留）：

| 地址 | 方向 | 含义 |
|---|---|---|
| 0xA0 | W | BULK_ADDR：同时装写/读指针 |
| 0xA4 | W | BULK_LO：下一个 64 位字的低 32 位 |
| 0xA8 | W | BULK_HI：提交该字，地址自动 +8 |
| 0xAC | R | BULK_RLO：当前字低 32 位 |
| 0xB0 | R | BULK_RHI：当前字高 32 位，推进到下一字 |
| 0xB4 | R | 状态：{err, ready, busy, len[15:0]} |

写路径去掉了每字的 ADDR 写和 CPU 轮询：A 通道在上一笔 DDR 写未 ack 时拉低
`s_awready/s_wready`，由总线自然背压。

**验证（`tb/tb_acc_bulk.v`）**
- 32 个字先走单字窗口写到 0x100，同样 32 个字走批量窗口写到 0x300；
  两条写路径都完成，批量窗口 `len` 读回 = 32，无 SLVERR。
- **批量读未通过**：`BULK_READ_MISMATCH 0 got=000000005a000000 exp=a50000005a000000`
  即 RLO 读到 0、RHI 读到本该属于 RLO 的低半字——**响应比地址晚一拍**。
  32 个字全部同样错位。这是一处确定的时序缺陷，位置在
  `rtl/conv_engine_axil.v` 读case（6'd43/6'd44）与 `s_rdata_r` 的采样关系，尚未修好。
- 因此"批量接口与单字接口逐字节一致"**尚未成立**，固件也没有改用批量接口。

**回归（旧路径未受影响）**
```
# VEXII_CPU_ACC_PASS real CPU configures convolution and checks DDR result
# VEXII_FIRMWARE_BOOT_PASS full YOLO firmware UART CRC DDR write/read
```
