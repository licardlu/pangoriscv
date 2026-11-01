# 交接文档 —— FPGA YOLO 垃圾分类加速器

> 2026-10-30 接手更新：本文以下是历史快照。当前入口为
> `OFFLINE_HANDOFF.md`；使用 `gen/integration/`，不要使用旧 `gen/` 根目录的模型镜像和层表。
> 当前采用 CPU 软件算子及检测头 + RTL 卷积，不要求全网 RTL，也不做机械分拣。

> 写给接手的人。**先读这一页，再决定从哪下手。**
> 详细的过程记录在 `STATUS.md`（T1–T46），但那份很长，是流水账；
> 这一份是结论和待办。

最后更新：2026-10-30

---

## 一、项目目标

在盘古 PG2L100H（PG2L100H-6IFBG676）开发板上：

- 自研 RV32IM CPU（已有，`pangoriscv` 工程）作为主控
- 自研 FPGA 加速器跑 YOLOv5n-garbage 做垃圾分类
- 摄像头输入，显示器输出检测框和类别
- 识别全部在板上完成

模型已定：`yolov5n-garbage`（320×320 输入，6 类），权重在
`data/models/yolov5n-garbage.pt`。

---

## 二、现在到哪一步了（一句话版）

**核心计算引擎已完成并验证；整张网络还串不起来；一次都没上过板。**

按"板上能看到检测框"这个标准，大约 **55~60%**。

### 已经证实能用的（有证据，不是"应该能"）

| 项 | 状态 | 证据在哪 |
|---|---|---|
| 模型量化精度 | INT8 mAP **0.3395**，保留 FP32 的 **96.8%** | `results/yolov5n_labeled320_int8c256/` |
| 卷积引擎功能 | 三个真实形状**逐字节**正确 | `sim/run_rt.sh` |
| 引擎时序 | **All Constraints Met，Fmax 79 MHz** | `pds/rt_66m/report_timing/conv_rt_top.rtr` |
| CPU 控制引擎 | 走 AXI 全通过，写回次数 == 输出字数 | `sim/run_axil.sh` |
| 模型打包 | 9.43 MiB DDR 镜像 + 60 层寄存器表 | `gen/ddr_model.bin`、`gen/layer_table.h` |
| 整图算子序列 | **85 个算子**，conv 顺序与 layers.csv 逐条一致 | `gen/graph.json` |
| 64→256 位 DDR 宽度桥 | 单测通过 | `tb/tb_ddr_bridge.v` |
| 跨时钟域 AXI 桥 | 单测通过（10 ns / 7 ns 无关时钟） | `tb/tb_axi_cdc.v` |
| SoC 顶层（CPU+加速器+DDR3） | **综合+映射 0 错误**，LUT 33,070（49.7%） | `pds/soc_run/console.log` |

### 跑不起来的（这就是剩下的全部工作）

1. **25 个非卷积算子接不进寄存器映射** —— 最关键的缺口
2. 摄像头 / HDMI 没接进 SoC 顶层
3. NMS / 检测框解码 / 画框没写
4. 主机把模型灌进 DDR 的物理通道没通（卡在串口 RX 引脚未知）
5. SoC 全系统布线未收敛（有退路，见第五节）
6. **从未上板**

---

## 三、架构和数据流

```
                    ┌──────────────────────────────────────┐
   摄像头(未接) ────►│  DDR3 (512 MB, 模型 9.43 MiB + 张量)  │
                    └──────────────┬───────────────────────┘
                                   │ 256 位 AXI (core_clk)
                          ┌────────▼────────┐
                          │   axi_cdc       │  跨时钟域
                          └────────┬────────┘
                          ┌────────▼────────┐
                          │ bridge_to_cdc   │
                          └────────┬────────┘
                          ┌────────▼────────┐
                          │ ddr_axi_bridge  │  64 位 ↔ 256 位 + 地址换算
                          └────────┬────────┘
                          ┌────────▼────────┐        ┌──────────────┐
       RV32IM CPU ───────►│conv_engine_axil │───────►│ 显示器(未接)  │
       (AXI-Lite 控制)    │  + conv_band_rt │        └──────────────┘
                          └─────────────────┘
                           clk_sys = 74.33 MHz
```

- **CPU 的作用**：逐层写 17 个寄存器 → 启动 → 轮询完成。没有硬件序列器（曾经写过
  `acc_seq.v`，多驱动 + 逻辑重复，已删除；一层几十万周期，20 次寄存器写是免费的）
- **张量布局**：通道后置 `[y][x][c]`，C 补齐到 8 的倍数，一个 64 位字 = 8 个通道
- **数值规则**（已冻结，RTL 必须逐位复现）：per-tensor 激活、per-channel 权重、
  `(acc*M)>>15`、round-half-**away-from-zero**、clip、SiLU 用 256 项查表

---

## 四、关键文件和入口

### 必须知道的几个文件

| 文件 | 是什么 |
|---|---|
| `rtl/conv_band_rt.v` | **核心**。运行时可配的分块卷积引擎，574 行 |
| `rtl/conv_engine_axil.v` | 引擎的 AXI 外壳：17 个写寄存器 + AXI 主口 + 模型加载窗口 |
| `rtl/yolo_soc_top.v` | 板级顶层。**目前只接了 DDR 路径，没接摄像头/HDMI** |
| `rtl/pangoriscv_ai_soc.v` | CPU SoC 的副本，多一个 `0x70000000` 从窗口给加速器 |
| `sw/acc_regs.h` | **CPU↔加速器的唯一契约**，寄存器映射都在这 |
| `scripts/pack_model.py` | 模型 → DDR 镜像 + 寄存器表 |
| `scripts/export_graph.py` | 导出 85 个算子的执行序列 |
| `STATUS.md` | 流水账，T29–T46 是本轮的工作记录 |

### 复现命令

```bash
# 引擎功能（裸接口），三个真实形状逐字节
cd ai_lab/sim && bash run_rt.sh          # 约 1.5 分钟

# 同一批形状，走 AXI（CPU 的视角）
cd ai_lab/sim && bash run_axil.sh        # 约 1.5 分钟

# 引擎单独的综合→布局→布线→时序（已验证 All Constraints Met）
cd ai_lab/pds && pds_shell -file flow_66m.tcl

# 全 SoC 综合+映射（0 错误）
cd ai_lab/pds && pds_shell -file flow_soc.tcl

# 模型打包（需要带 torch 的解释器）
cd ai_lab/scripts && "C:/Users/lenovo/AppData/Local/Programs/Python/Python311/python.exe" pack_model.py

# 整图算子序列
cd ai_lab/scripts && "C:/Users/lenovo/AppData/Local/Programs/Python/Python311/python.exe" export_graph.py
```

工具链：PDS 2022.2-SP6.1 在 `E:\donwload\PDS_2022.2-SP6.4\PDS_2022.2-SP6.1\bin\pds_shell.exe`，
ModelSim 在 `E:\donwload\win64\`。

---

## 五、接下来做什么（按阻塞顺序）

### 1. 把 25 个非卷积算子接进寄存器映射 ★最优先

**问题**：`rtl/postop_engine.v` 里 maxpool/upsample/concat/add 四个算子**已经验证过**
（`tb/tb_postop.v`），但它是**编译期定形状**的（和当年的卷积引擎一样），而
`conv_band_rt.v` 是运行时可配的。所以现在只能算 conv，C3/SPPF 里的拼接和残差做不了。

**85 个算子里有 25 个是这类**：13 CONCAT + 7 ADD + 3 MAXPOOL + 2 UPSAMPLE。

**要做的**：仿照 `conv_band_rt.v` 的做法写一个 `postop_rt.v`：
- 形状参数改成输入端口（`p_op`、`p_c`、`p_in_w`、`p_in_h`、`p_k`、`p_stride`）
- **地址全部改成增量推进**，不要在内层算乘法（这是 `conv_band_rt` 花了 6.7 ns 才学会的教训）
- add 一个 `s2_base` 寄存器给第二路输入（concat/add 需要）
- 包一层 AXI-Lite 外壳，寄存器映射接着 `acc_regs.h` 往后排

**验证**：`scripts/gen_postop.py` + `tb/tb_postop.v` 已有四算子的向量，
把 `postop_rt` 的端口对上就能复用。

### 2. UART 加载器

**问题**：CPU 的两个 AXI 主口只连片上 RAM 和外设，**它没有到 DDR 的通路**。
已经用"加载窗口"绕过（加速器空闲时借它的 DDR 写口）：
```
0x54 ACC_LOAD_ADDR   下一个 64 位字的地址
0x58 ACC_LOAD_LO     低 32 位
0x5C ACC_LOAD_HI     高 32 位；写这个即提交，地址自动 +8
```

**缺的**：主机 → CPU 的物理通道。**卡在串口 RX 引脚未知**。
- 视频工程只约束了 `uart_txd = C24`，没有 RX
- CPU 工程的 FDC 里也没有
- DDR3 IP 自带示例里有两个候选：`H14`（ddr3_100h）和 `L8`（ddr3_test），
  但它们的 txd 分别是 K14 和 J8，**和 C24 都对不上**，不能盲用

**要做**：查开发板原理图确认 RX 引脚，然后写一个简单的逐字节协议
（地址 + 长度 + 数据，每 8 字节写一次 LO/HI）。

### 3. 摄像头 / HDMI 接进 SoC 顶层

视频工程（OV5640 → DDR → HDMI 720p60）**是独立且能跑的**，在
`hdmi1080p/` 目录，位流、约束、时序报告都是全的。

**要做的**：
- 把 `hdmi_ddr_ov5640_top.v` 里的摄像头/HDMI 部分搬进 `yolo_soc_top.v`
- 视频路径和加速器路径**共享 DDR3**，需要加一个 2 选 1 的 AXI 仲裁
  （`axi_cdc` 现在是单请求队列，扩展成能接两个源即可）
- 720p 帧 → 320×320 输入张量：缩放或中心裁剪，写进 `layers[0].a_base`
- 检测框叠加：在 HDMI 像素流里插一层，从 CPU 写的框缓存里查表

### 4. 检测框解码 + NMS + 画框（纯软件，CPU 侧）

三个检测头的输出是 `[1, 3, 5+6, H, W]`，需要：
- 解码：`(x,y,w,h)` 从 grid 偏移还原到像素坐标
- 置信度阈值 + NMS（IoU 0.45 左右）
- 类别名（6 类：biodegradable / cardboard / glass / metal / paper / plastic）
- 结果写进一块 CPU 可写、画框逻辑可读的小缓存

**注意**：检测头的最后三个 conv 在 `layers.csv` 里 `act=None`，
CPU 侧按 FP32 解码，精度口径按之前测过的来。

### 5. SoC 全系统布线

现在 33k LUT + DDR3 PHY，跑了 11 轮还有 29,244 根未布通。**有退路**：

1. **换 placement seed**：`pnr -gplace_seed N -plc_decongestion 1 -share_router_control_signal TRUE`，
   多开几个并行（`pangoriscv/docs/HANDOFF-2026-10-22.md` §5 明确写了
   "详细布线收不收敛主要由 placement seed 决定"）
2. **降频**：引擎 66.7 MHz 版本 7 分钟就布完了
3. 减面积：`conv_band_rt` 已经是 LUT 10,117 / DRM 32（引擎单独）

### 6. 上板（唯一不能离线做的）

**顺序一定要这样，不要跳**：
1. 先确认**下载器能不能枚举**（`pangoriscv/README.md` 里有一条"下载线未枚举"的记录）
2. 烧 **DDR3 IP 自带的示例工程**（`hdmi1080p/ipcore/ddr3_test/pnr/ddr3_test.pds`，顶层
   `test_ddr`，带 UART BIST），用串口做 DDR 读写测试
   —— **这一步是为了确认 DDR 的 AXI 地址语义**，见第六节第一条
3. 烧 SoC 位流，先做**最小验证**：用加载窗口写几个字、读回比对
4. 再跑 `layers[0]`（320→160，最能暴露地址错位）
5. 最后才跑整网

---

## 六、踩过的坑（重要，别重犯）

### 6.1 DDR3 的 AXI 地址是"32 位字地址"，不是字节地址

这是我从两份**能工作**的代码交叉验证出来的，控制器源码是加密的：
- IP 示例：`awlen=15` 配 `awaddr += 128` → 每拍推进 8 个单位
- 视频工程 `wr_buf`：`DDR_ADDR_OFFSET = 拍数 × (DDR_DATA_WIDTH/DQ_WIDTH) = 拍数 × 8`
- 一拍数据 32 字节 ÷ 8 个单位 → **1 个单位 = 4 字节**

换算：字节地址 `W` → 突发地址 `(W>>5)*8`，拍内 lane = `(W>>3)&3`，
`WSTRB = 8'hFF << (lane*8)`。搞错了整块数据会整体错位 4~8 倍。

> **这个假设只有板子能最终确认**，用 ILA 抓前几个 burst 即可。只影响一个常量。

### 6.2 运行时定形状 → 地址里不能有乘法

`conv_band_rt` 第一版把"尺寸来自寄存器"直译成地址乘法，时序 **−6.8 ns**、LUT 27,446、
布线不收敛。改成"每个 band / 每个 tile 算一次增量，之后只做加法"之后：
**−0.104 ns → +403 ps → +572 ps，TNS 0**。

**这一项值 6.7 ns。** 写 `postop_rt` 时照做。

### 6.3 两张 512×32 的 q 表 = 32,768 个触发器

`bias_r`/`mval` 按 cout 存全表，综合成 32,768 个 FF（FF 总数 36,504，几乎全是它们），
还各带一棵 512:1 读 mux。改成一个 tile 现取 8 个（`S_TQ`/`S_TQW`，8 个 64 位字），
**LUT 27,446 → 14,392，FF 36,504 → 4,061**，代价每层 +0.07% 周期。

### 6.4 一堆"静默错"的 bug（编译器不报、综合不报、上板才错）

| 现象 | 根因 |
|---|---|
| 除第一个 64 位字外全没写进去 | `wire [7:0] wr_stb = s_wstrb << (lane<<3)` —— 8 位左移后全截断成 0 |
| 全落在 lane 0 | `wr_lane << 3` 的移位量只有 2 位，`2'd1<<3` 截断成 0 |
| 模型"加载完了"但全是旧数据 | `ld_kick` 在同一 always 块里先置 1、又被后面的"默认清零"覆盖（NBA 后写者胜） |
| 每次写都发两遍 | FIFO 消费后读指针下一拍才更新，`B_IDLE` 复用旧表项 |
| 读回的是上一条 | FIFO 的 rdata 在读使能后才寄存，改成 show-ahead 组合读 |
| 多写一整行 8 个字 | `rows_done` 在测试之后才更新 → 多跑一个 band |
| 输出全 X | `src_row` 改有符号后"负行"不再被当成填充，填充循环拿负地址读 DDR |
| C3 少了 8 个卷积 | C3 是**双分支**（cv1 喂 bottleneck，cv2 直接进 concat） |
| 320 变成 161 | 用 `pad=k//2` 推形状，但首层是 k=6 autopad pad=2，**只能用 layers.csv 的真实几何** |
| `ACC_CIN` 写成真实 cin 就整层读不到东西 | 引擎 `csl = cin>>3`，必须写**补齐后**的通道数（cin=3 → cpad=8） |

### 6.5 PDS 工具链的坑

| 坑 | 正确做法 |
|---|---|
| 往 `impl.tcl` 里加 `pnr` 参数不生效 | `impl.tcl` 只是导出文件，实际流程由 `.pds` 内部定义驱动，要用 `pds_shell -file xxx.tcl` |
| `set_incdir` 不是命令 | 用 `compile -top_module X -include_path "..."`，**而且只能给一个**（给两个只保留最后一个） |
| 生成时钟约束全失效 | 约束里的生成时钟按**实例路径**写（`u_ddr3_test_h.u_ddrphy_top...`），DDR3 实例必须叫 `u_ddr3_test_h` |
| `Object can not be found` | 删端口要同时删约束 |
| 综合报 0 错误但流程中断 | 检查 FDC 里所有 `define_attribute` 的端口是否都还在 |

### 6.6 仿真环境的坑

- `sim/engine/` 底下曾经放过一份 `tb_band_rt.v` / `conv_band_rt.v` 的**副本**，
  跑仿真用的是副本，改正本不生效——已删除，现在只编译 `tb/` 和 `rtl/` 下的正本
- ModelSim 的 `$fopen` 失败返回 `0x80000000|ch`，不是 0
- `$fscanf` 不支持 `%h`，只能用 `%x`
- 全零向量会让"零 vs 零"比对假 PASS，必须显式检查非零

---

## 七、性能口径（不要用旧数字）

| 口径 | 数值 |
|---|---|
| 总 MAC | 518,732,800 |
| 理论计算下限（64 MAC/拍） | 121.5 ms |
| 串行总周期（tr≤8、96 KiB 带缓冲） | 9,677,823 拍 |
| 66.7 MHz | 145 ms ≈ 6.9 fps |
| **74.33 MHz（SoC 实际用的时钟）** | **130 ms ≈ 7.7 fps** |
| DDR 流量 | 12.58 MB/帧 |

> **旧的 84.4 ms 作废**：那是 tr≤40 规划的口径，引擎跑不了（TRM=8）。

---

## 八、需要外部信息才能推进的事

1. **串口 RX 引脚** —— 查原理图。没有它，模型进不了 DDR
2. **下载器现在能不能枚举** —— 决定上板能不能开始
3. **板子在谁手里** —— 目前不在提问的人手里

---

## 九、一句话给接手的人

**别从零开始看。** 先跑 `sim/run_axil.sh` 确认引擎和 CPU 接口是活的（1.5 分钟），
再读 `sw/acc_regs.h` 理解契约，然后直接从第五节第 1 条（后处理算子）下手。
过程细节查 `STATUS.md`，但别整份读，按 T 号索引查。
