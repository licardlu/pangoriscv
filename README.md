# 青禾智能视觉垃圾分类系统 · 源码与验证包

紫光同创 Logos2 **PG2L100H-6IFBG676** ｜ PDS 2022.2-SP6.1 ｜ RISC-V **RV32IMC** 软核 + YOLOv5n 卷积加速

本包提供两件可独立验收的东西：

1. **一颗能跑 CoreMark 的 RISC-V CPU**（120.461538 MHz、7000 迭代、五项 CRC 全对），带完整 RTL、约束、冻结固件镜像、PDS 构建入口和二次上板记录。
2. **完整的视觉垃圾分类应用**：摄像头采集 → FPGA 内卷积推理 → HDMI 显示 → 按键答题 → 语音 → 四路舵机，带已上板的 27 MHz 位流和源码。

本包不包含：Git 历史、PDS 构建数据库、本机工具路径、许可证、编译器与 Keil 设备包（需自行安装，见 §7）。所有"已完成 / 未完成"的表述以 §6「已知边界」为准，那是唯一口径。

---

## 1. 三分钟验收（不需要开发板、不需要许可证）

先做这一步。它只读文件、只算哈希，任何一台装了 Python 3.10+ 的电脑都能跑。

```powershell
cd project/pds_native_120
python tools/build.py verify
```

期望 `"status": "PASS"`，其中 `memory_lanes: 8`、`ram_sha256: c0166c5cf861...6a3ef31d`。这一步核对的是：43 个设计源文件的哈希、`include` 闭包、8 路 ROM 初值与 ELF 的自洽、`$readmem*` 指向的镜像文件是否都在包内。**跑不过就说明包被改动过，后面的分数都不用看。**

紧接着复核两次真实上板的 UART 原始记录：

```powershell
python tools/check_board.py evidence/standalone-board-001
python tools/check_board.py evidence/standalone-board-002
```

期望两次都 `"status": "PASS"`、`"coremark_per_mhz": 5.346252494441123`、`"board_verified": true`。注意 `"sta_closed": null` 是**故意**的：`build/` 目录没随包发布，脚本不会替不存在的时序报告背书，只在包内按 SHA256 找到同一位流（`project/pds_native_120/bitstream/current/pango_replica_core_120.sbit`）并如实写明 `bitstream_relocated_to`。

---

## 2. 分数与口径（同一份位流的三个数）

| 指标 | 数值 | 出处 |
| --- | --- | --- |
| CoreMark 1.0 | **5.346252494 CoreMark/MHz** | `project/pds_native_120/evidence/implementation-standalone-001/measurement.json` |
| 迭代数 / 总周期 | 7000 / **1,309,328,358 ticks** | 同上，与串口原始日志 `uart.log` 逐字段核对 |
| 实际耗时 | **10.869264827 s**（≥ 10 s 达标） | `1309328358 ÷ 120461538` |
| 原始吞吐 | 644.02 iterations/s | `7000 ÷ 10.869264827` |
| 时钟（PLL 实际值） | **120.461538 MHz** = 27 MHz × 58/13 | `project/pds_native_120/rtl/board/pango_pll.sv`；FDC 周期 8.301404853 ns |
| 资源 | LUT **8875** / FF **6658** / DRM 34 / APM 5 / Dist RAM 72 | 同一位流的 `synthesize` + `device_map` 报告 |
| CoreMark/LUTs | 5.346252494 ÷ 8875 ≈ **0.6024 /kLUT** | 由上两行相除；口径为 LUT 总数 |

**算分只用 `Total ticks`，不要用串口日志里的 `Total time (secs)` 和 `Iterations/Sec`。** 本固件 `HAS_FLOAT=0`，这两个字段是整数截断值：打印出来是 `10` 和 `700`，拿 `700 ÷ 120.461538` 会算出 **5.81**，比真值虚高 8.7%。正确算法只有一条：

```
CoreMark/MHz = 迭代数 × 1e6 / 总周期数 = 7000 × 1e6 / 1309328358 = 5.346252494
```

串口日志末尾额外打印了 `TICKS_HI` / `TICKS_LO`，就是给判分用的 64 位原始计数。

**频率口径分两层，不能混说**：PLL 实际输出就是 120.461538 MHz，板上真实跑完 10.87 s、同一份网表下载两次的串口记录逐字节相同；而最终 STA 在慢角下 `Setup(Slow) = −1.426 ns`（619 个失败端点），**没有闭合**。所以"120 MHz 能跑"是实测事实，"120 MHz 通过时序约束"不成立——见 §6。

---

## 3. 上板复现（需要开发板 + PDS + 许可证）

**只在 SRAM 里跑，不改板载 Flash。** 位流里的 8 路 BRAM 初值就是 7000 迭代固件，下载完复位即开始跑，不需要另外烧程序。

```powershell
# 1) 起 JTAG 服务（另开一个窗口，保持不关）
cdt_js.exe -port 65420 -work_dir <本包任意目录>

# 2) 下载 + 抓串口（脚本会自己开 COM 口、收 UART、校验设备 ID 和 CRC）
cd project/pds_native_120
powershell -ExecutionPolicy Bypass -File tools/program.ps1 `
  -Bitstream project/pds_native_120/bitstream/current/pango_replica_core_120.sbit `
  -BitstreamSha256 2e38db1c26bd6a1bcb9a3fe1d09ca6d70bf430d5ac50001f450664a50c81f9cb `
  -EvidenceTag board-run-mine `
  -PdsShell <PDS>/bin/pds_shell.exe -SerialPort COM34 -JtagPort 65420

# 3) 判读
python tools/check_board.py evidence/board-run-mine
```

串口 115200 8N1，复位后应依次看到（节选，共约 21 行）：

```
VEXII_PANGO_BOOT
CPU_HZ=120461538
ITERATIONS=7000
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 1309328358
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x25b5
Correct operation validated. ...
TICKS_HI=0
TICKS_LO=1309328358
BENCH_DONE
```

⚠️ `crcfinal = 0x25b5` 是 **7000 迭代**对应的值，官方 README 示例里的 `0x33ff` 是别的迭代数。`crcfinal` 随迭代数累积变化，**不是错误**。四个定值 `seedcrc/crclist/crcmatrix/crcstate` 才是硬判据。

---

## 4. 自己重建一份位流

`project/pds_native_120` 是**自包含**的：43 个设计文件、FDC/PCF 约束、8 路 ROM 初值、冻结 ELF、构建脚本全在里面，路径全部相对本目录，不读包外任何东西。

```powershell
cd project/pds_native_120
python tools/build.py build --name run-001 --pds <PDS>/bin/pds_shell.exe
# 约 15–18 分钟；产物 build/run-001/generate_bitstream/pango_vexii_top.sbit
```

脚本自带三道门禁，跑完会写 `build_result.json`：流程必须打印 `EXACT_BUILD_FLOW_COMPLETE`；综合日志必须出现 **8 次** `Loading memory data from file` 且没有 `Cannot open specified data`；必须有时序报告。缺任一即失败退出。

**每次换一个新 `--name`，不要覆盖已有实现目录**——同一个目录跑两次会覆盖证据，三项指标就无法互校。重建出的位流**不保证与交付位流逐字节相同**（布局布线对种子敏感），但加载同一份固件、跑出的 ticks 应当一致。这一步只验证"能从源码造出可用位流"，不是"复制交付位流"。

---

## 5. 目录地图

| 路径 | 是什么 | 入口 |
| --- | --- | --- |
| `project/pds_native_120/` | **CPU 交付主线**：可独立构建的 120 MHz CoreMark 工程 | `tools/build.py`、`sources.f`、`flow/build.tcl` |
| `project/trash_sorting/` | **完整视觉应用**：摄像头/推理/显示/按键/语音/舵机 + 已上板 v3 位流 | `README.md`、`prebuilt/full_v3_27mhz/` |
| `project/yolo120/` | 120 MHz CPU + AI 集成实验（速度实测，STA 未闭合） | `tools/build.py`（需要 GCC） |
| `project/cpu120/` | 同上流程的 CPU 侧导入快照 | `release_manifest.json` |
| `rtl/core/` | 自研双发射核 V1/V2 的 RTL（**不是** 5.2 分的交付路径） | `pango_cpu.v` |
| `rtl/generated/` | 参考工程生成物与 8 路 ROM 初值 | `MicroSoc.v_toplevel_*.bin` |
| `firmware/` | CoreMark 源码 + 移植层（UART、mcycle 计时、启动汇编） | `port/`、`scripts/build.py` |
| `tb/` | 基础 SoC / PLL / 复位 / 除法器测试台 | `tb_soc.sv` |
| `platform/` | 参考基线留下的约束与 profile（构建入口已迁到 `project/pds_native_120/`） | `pango_vexii.fdc`、`profile.json` |
| `evidence/records/` | 每次实现的板测、时序、资源与原始串口记录 | 一个实现一个目录 |
| `docs/` | 架构模块合同、面积预算、错误汇总、验证说明 | `docs/source-guide.md` 先读 |
| `extensions/yolo/` | YOLO 权重、部署模型、AI RTL 与运行时 | `OFFLINE_HANDOFF.md` |

### 5.1 关键件都在这（评委可以逐项点名核对）

| 东西 | 在哪 | 数量 / 大小 | 缺了会怎样 |
| --- | --- | --- | --- |
| CPU RTL | `project/pds_native_120/rtl/` + `sources.f` | 43 个文件（96 个含 include） | 综合直接失败 |
| CPU 约束 | `project/pds_native_120/constraints/` | `pango_vexii.fdc` + `.pcf` | 引脚/时钟全丢，位流无意义 |
| 固件镜像 | `project/pds_native_120/firmware/image/` | `coremark.elf` + 8 个 lane（每个 73728 B） | 综合"成功"但板上零输出 |
| 应用 IP | `project/trash_sorting/source/yolo/ipcore/` | 4 个 `.idf`：`ddr3_test`、`pll`、`rd_fram_buf`、`wr_fram_buf` | 缺一个就综合失败 |
| DDR3 PHY | 同上 `ddr3_test/rtl/` | **71 个 `.vp` 加密网表** | 需要 PDS 许可证才能解密；不是可读源码 |
| 摄像头 / HDMI / 时钟 | `source/yolo/sources/053..070` + `portable/052` | 19 个 RTL | 没有画面 |
| AI 卷积加速 RTL | `source/yolo/sources/040..051` | 12 个 RTL | 推理跑不起来 |
| 部署模型 | `source/yolo/model/model.bin` | 1,863,560 B，SHA256 `895909cf…c18a` | 卷积权重全 0 |
| 语音 ROM | `.../assets/audio_rom/` | 59 个文件（1 个索引 + 57 分片 + 清单） | 语音静音（不报错） |
| 界面素材 | `.../assets/*.hex` | 6 个 RGB 表 | 屏幕花屏 |
| STM32 中继 | `project/trash_sorting/stm32_reference/` | 68 个 `.c/.h/.s`，Keil `MDK-ARM/test.uvprojx` | 舵机不动作 |
| 位流 | `bitstream/replica_native_120/`（CPU 120 MHz）、`project/trash_sorting/prebuilt/full_v3_27mhz/`（应用 27 MHz） | 2 个不同实现，3 个副本 | 不能现场演示 |
| 证据 | `evidence/records/` | 800 多个文件，46 个目录含 `measurement.json` / `uart.log` / `.rtr` | 数字无法追溯 |

---

## 6. 已知边界（评委请按这一节理解，不要按别处的旧说法）

| 项 | 状态 | 说明 |
| --- | --- | --- |
| CPU 最终 STA | ❌ **未闭合** | `Setup(Slow) −1.426 ns`、619 失败端点、TNS −189.497 ns。120 MHz 是**实际跑得动**，不是**约束通过** |
| 面积门禁 | ❌ 未通过 | LUT 8875，比参考 8841 多 34（+0.38%），`area_gate_passed: false` |
| 语义模块化 | ❌ 未完成 | 核心由 53 个源码段组织，四个 early/late 移位器已独立成模块，其余仍是参考原式的整体段。**不宣称这是独立原创架构** |
| ILA 波形 | ❌ **未抓取** | 本包没有任何 ILA 波形，不提供"示意"数据。此项属文档交付，不在本包代码范围内 |
| 自研核 V2 | ⚠️ 低于交付线 | `rtl/core/` 双发射核上板 3.2583 CoreMark/MHz @ 84.375 MHz，与交付主线**不是同一份实现**，指标不可合并 |
| v4 应用 | ⚠️ 仅源码 | 有中文标签/叠加/舵机方向改动，**没有可用位流**；`variants/v4_source_only/pds_*.log` 记录的是许可证失败 |
| STM32 中继 | ⚠️ 未联调 | 工程与源码齐全（17 源文件 + 5 include 目录全部在包内），但颜色顺序与方向掩码需按实际接线确认；FPGA 空闲仍输出 PWM，不能只按"有无波形"解码 |
| 识别率 | ⚠️ 小样本 | 18 张同源验证集、127 个 GT、AP50 **32.78%**、P 42.31%、R 17.32%（`evidence/records/validation_20261104/dataset_metrics/metrics.json`）。**不能外推成整机识别准确率**，paper/plastic 两类在该子集上 AP50 为 0 |
| AI 侧 RTL 仿真 | ⚠️ 不可复跑 | `extensions/yolo/tb/` 的 29 个 tb 里有 13 个缺 `tb_params.vh`、`frame.hex`、`cpu_oracle.*` 等生成物，只保留了历史结论，**别照着跑** |

---

## 7. 依赖与安装

| 依赖 | 版本 | 用途 | 是否随包 |
| --- | --- | --- | --- |
| PDS | 2022.2-SP6.1（含 PG2L100H 器件库） | 综合 / 布局布线 / 下载 | ❌ |
| PDS 许可证 | fabric + fabric_shell | 综合；DDR3 PHY 的 `.vp` 是加密网表，需许可证解密 | ❌ |
| xpack RISC-V GCC | `riscv-none-elf-gcc` 15.2.0-1（自带 `riscv32-unknown-elf-*` 别名） | 重编固件 | ❌ |
| Python | 3.10+（仅标准库） | 构建/校验脚本 | — |
| GNU make | 可选 | 只有想用官方 Makefile 编 CoreMark 时才需要 | ❌ |
| ModelSim | 10.6e 或更新 | 跑 `tb/` 下的仿真 | ❌ |
| Keil MDK + STM32F1 设备包 | — | 编 STM32 中继 | ❌ |

---

## 8. 重编固件

固件里已经烧进交付位流了，**只有想改迭代数或改移植层时才需要重编**。

```powershell
# 权威路径：与冻结镜像逐字节对齐（含编译器选项、链接脚本、启动汇编）
$env:PATH = "<xpack>/bin;" + $env:PATH
python scripts/build.py firmware --iterations 7000
# → build/firmware_7000/coremark.elf

# 校验：ELF 里的程序段与 8 路 ROM 初值必须完全一致
python scripts/verify_image.py build/firmware_7000/coremark.elf project/pds_native_120/firmware/image
# 期望 ram_sha256 = c0166c5cf86143cacd3b50c46b1c7f9ba28796e5b8f4c9d5dcc5507d6a3ef31d
```

`ram_sha256` 一致即证明"源码 → 镜像"这条链是通的。**如果只改了注释或无关代码，这个值不会变；一旦不一致，说明你动了会改变指令流的代码。**

改完 ELF 之后要重新生成 8 路 lane 并替换，才能进综合：

```powershell
python -c "import sys; sys.path.insert(0,'scripts'); import verify_image"   # 看 verify_image.py 的 lane 拼装规则
```

拼装规则：`ram[i] = lanes[i % 8][i // 8]`，即 **按字节交错**，每 lane 8192 字节、8 lane 合成 64 KiB。每个 `*.bin` 是 `$readmemb` 用的文本位图（8192 行 × 8 字符），不是二进制文件——改的时候别当二进制处理。

想用 GNU make 的话，`firmware/port/core_portme.mak` 已经补齐，与 `scripts/build.py` 用同一组优化选项：

```powershell
cd firmware/coremark
make PORT_DIR=../port ITERATIONS=7000 CC=riscv-none-elf-gcc
```

> `scripts/build.py` 是**记录在 `release_manifest.json` 里的权威路径**；Makefile 是等价的手工入口，两者产物应当是同一份 RAM 镜像。

---

## 9. 校验与自检

**第一件事**：确认包在传输过程中没坏。包根 `SUBMISSION_SHA256.json` 是逐文件清单（相对路径 + 字节数 + SHA256），一条命令核对全部 6200 多个文件：

```powershell
python tools/check_package.py
# 期望：PASS package contents match SUBMISSION_SHA256.json
```

有三个文件对不上就说明包被改过或解压不全，先别往下看分数。

应用侧还有两个独立的自检入口：

```powershell
# 应用 RTL 依赖闭包（89 个设计文件 = 85 RTL + 4 IP、53 处 include、65 个生效的 $readmem 目标）
python project/trash_sorting/tools/check_app_sources.py

# 应用侧离线仿真冒烟（需要 ModelSim；不接硬件，不需要摄像头）
powershell -ExecutionPolicy Bypass -File project/trash_sorting/source/extensions/business/application/run_smoke.ps1 -ModelSim <你的 ModelSim win64 目录>
```

> 子目录里还有几份 `SHA256SUMS.txt` / `manifest.json`（`project/trash_sorting/source/`、`extensions/ui_reference/`），那是**上游资料包导入时**的快照，不是本次交付清单。其中少量条目因为导入后有记录的修复（MS7210 AVI 校验、PLL duty 等）而对不上，属已知情况。**判包只用根目录的 `SUBMISSION_SHA256.json`。**

`PACKAGING_CHECK.json` 记录了本次打包时**实际跑过**的 8 项检查：命令、期望输出、真实输出。不是"应该能过"，是"跑过了，结果在这里"。

---

## 10. 代码来源与声明

- CPU 内核逻辑复现自 VexiiRiscv 生成物（SpinalHDL 生成），本仓库做的是**移植、约束冻结、板级集成与验证**，不宣称原创微架构。逐文件来源与许可证见 `docs/source-license-origin-audit.md`、`project/pds_native_120/provenance/`。
- `extensions/ui_reference/` 与 `project/trash_sorting/source/extensions/` 是**分叉的两份**，分别被 `project/yolo120` 和 `project/trash_sorting` 使用，不能互相替换。
- 视频链路、DDR3 与摄像头 IP 为导入工程；DDR3 PHY 以加密 `.vp` 形式提供，不是可重建源码。
- 所有引用的数字都能在 `evidence/` 与 `docs/verification/` 找到原始文件。**没有抓过的波形、没有测过的识别率，本包一律不填。**

---

## 11. 出问题先看这里

| 现象 | 先查 |
| --- | --- |
| 板上零输出、串口没东西 | 位流是不是没有程序：综合日志里有没有 8 次 `Loading memory data from file` |
| 综合成功但 CPU 不启动、语音静音 | `$readmemh` 的相对路径按**进程当前目录**解析，必须在 `source/yolo/sources` 下启动 PDS |
| 分数和 5.346 差一点点 | 是不是用了整数截断的 `Total time`／`Iterations/Sec` 反推 |
| 重建位流时序差 1 ns | PDS 摆放在这个规模上就是 ±1 ns 抽样，判优劣看 ticks，不看单次 WNS |
| 板测脚本报 `Bitstream missing` | 用 `-Bitstream` 直接指 `project/pds_native_120/bitstream/current/*.sbit`，不要用 `-BuildName` |
| 更多历史坑 | `docs/lessons/mistakes-log.md`（按"现象 → 查什么 → 原因 → 怎么办"组织） |
