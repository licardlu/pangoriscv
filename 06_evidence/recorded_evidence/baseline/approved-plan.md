# tinyriscv 原生 AXI4 改造与紫光赛题一实施计划书（合并版）

> For agentic workers: use $superpower-executing-plans to implement approved tasks one at a time. 本文是设计与实施计划，不是已完成或已测试的 RTL。执行时逐项打勾；没有通过验收，不进入依赖它的下一项。

**Goal：** 以现有 tinyriscv 为基础，直接重构取指、访存和 SoC 总线为原生 AXI4，不保留 RIB，不使用 RIB-to-AXI 桥；先完成基础任务及性能证据，再按G0确认的范围逐项开展高阶任务，不预先承诺全部高阶可完成。

**Architecture：** 保留三级流水线和已有算术/译码基础；重新设计有效位、暂停、提交和异常边界，加入 CPU 内部原生 AXI4 取指与访存单元。片上存储与外设成为原生 AXI4 从设备，互连只路由 AXI4，不转换 RIB。Cache、预测器、DDR、摄像头、AI 分阶段接入。

**Tech Stack：** 可综合 Verilog/SystemVerilog、ModelSim、RISC-V 裸机 GCC、PDS、板载逻辑分析工具。Icarus 可作为另一条回归路线，但本机当前 PATH 未找到它。

**日期：** 2026-10-09。**状态：** 第三轮“小白实施方法”扩充稿。保留原生AXI4总体方向；本轮只修改计划文档，没有改动现有CPU工程。独立文档模板的检查结果与真实CPU验证分开记录，见第36章“扩充计划复核报告”。

**阅读入口：** 第0-24节解释总体方案；第25-34节给出本轮新增的语法、逐文件修改方法、代码模板、测试任务卡和可选功能。先读25，再按26的顺序做，不能把所有代码块一次性粘进原工程。DDR引脚/IP、具体YOLO模型仍须通过资料关卡，不会凭空编造可上板代码。



**本轮结论：** 可作为开发基础，不宜按原顺序直接全量执行。优先修正总线前进性、CPU/Cache边界、异常软件配套与阶段依赖；先取得基础上板和CoreMark证据，再决定高阶投入。赛题没有强制AXI4、禁用桥、指定OV5640、垃圾检测或HDMI；这些属于队伍方案选择。

---

**唯一维护文档：** 本文件已合并总体方案、小白实施方法、历次评审意见与实际复核记录。第0-24章为总体方案，第25-34章为实施方法，第35章为历史评审依据，第36章为模板复核结果。原独立评审文件和旧备份已移除；第35-36章中的历史行号、哈希与过程记录仅用于追溯，不代表当前仍存在独立原稿。执行时以当前正文及明确验收门槛为准。

## 0. 先看懂这份计划

### 0.1 我们究竟修改什么

CPU 的指令含义不因总线变化而改变。例如 `lw x5, 0(x6)` 仍然是“从 x6 给出的地址读取一个字，写进 x5”。变化在于：

```text
原来：给出地址 -> 原有组合读数据路径 -> 执行级使用数据
改后：保存请求 -> AXI地址握手 -> 等待数据 -> 检查响应 -> 写回一次
```

“原生 AXI4”不要求把所有状态机塞进 `tinyriscv.v`。在 CPU 内部拆分 `ifu_axi.v` 和 `lsu_axi.v` 是合理的，它们分别属于取指单元和访存单元，不是保留旧 RIB 的协议桥。

最终结构：

```text
                         tinyriscv CPU
         +-------------------------------------------+
         | PC -> 取指单元 -> IF/ID -> ID -> ID/EX -> EX |
         |        |                              |   |
         |     两路I-Cache                 两路D-Cache |
         |        |                              |   |
         |     原生AXI读主接口              原生AXI读写主接口 |
         | 寄存器 / CSR / trap / 分支预测 / retire     |
         +--------|------------------------------|---+
                  +---------------+--------------+
                                  |
                             AXI4互连
                  +---------------+------------------+
                  |               |                  |
            程序RAM/数据RAM   UART/GPIO/Timer     AI控制寄存器
                  |                                  |
           DDR目标端口(须核验) <--- AXI4数据主接口 --- AI计算与DMA
                  ^
                  |
           摄像头DMA <- 异步FIFO <- OV5640 DVP采集
```

没有 Cache 的第一版，取指/访存单元直接访问 AXI4；加 Cache 后，缺失请求由 Cache 的补行逻辑发起。内部信号可以是 `valid/ready/address`，但不能保留 RIB 仲裁及其时序假设来伪装“原生改造”。CPU内部层次按第3.5节固定，避免T03/T04与T09分别实现互不兼容的请求入口。

### 0.2 本文四种状态

| 标记 | 意思 |
|---|---|
| 已查源码 | 本次在本地文件里确认有这段逻辑，不代表正确运行 |
| 赛题要求 | 来自用户提供的 PDF，而非网上二手总结 |
| 本方案选择 | 为降低开发难度做出的架构决定，不是官方强制 |
| 核验关卡 | 没有足够证据，完成指定核验后才能开展依赖工作 |

### 0.3 不做的事情

- 不把 AXI4-Lite 当作 AXI4，也不先做 Lite 再整体推翻。
- 不实现 RIB-to-AXI 桥。
- 不为了总线改造重写全部 ALU 和译码。
- 第一版不做多笔乱序 outstanding、不做多核一致性、不做操作系统移植。
- 不把“有 AXI4 接口”当成“已经实现 Cache/DDR/AI”，这些分别验收。
- 不承诺 YOLO 的帧率、准确率或时序收敛；这些必须测量。

## 1. 赛题逐项对齐

### 1.1 核对依据

已读取：

`C:\Users\lenovo\Desktop\全国大学生嵌入式芯片与系统设计竞赛'2026FPGA赛道选题指南-紫光同创.pdf`

PDF 第 10 页 = 页脚第 8 页：选题一核心设计任务。

PDF 第 11 页 = 页脚第 9 页：工具链、性能、应用、文档、运行时间要求。

下表是摘要，不代替原文。本文不假定高阶项全部为强制，也不臆造分值；最终评分权重、旧作品使用边界和提交期限须以赛事通知为准。

| 编号 | 赛题内容摘要 | 当前工程状态 | 本计划交付/证据 |
|---|---|---|---|
| B1 | RV32I 基础整数处理器 | 有译码、执行、32寄存器源码；未本机验证 | 指令回归、随机等待访存回归、签名/提交轨迹 |
| B2 | 不少于三级流水线，处理数据冲突与分支 | 有 IF/ID/EX 和控制源码；暂停语义要改 | 阶段有效位、相关指令测试、分支清除波形 |
| B3 | UART、GPIO 等基础外设 | 有外设源码 | 原生AXI4外设，CPU串口输出及LED/按键演示 |
| H1 | 两路组相联指令与数据 Cache，优化突发 | 未见对应实现 | 两路I-Cache + 两路D-Cache + AXI补行突发、命中率/周期对比 |
| H2a | 动态分支预测，如 BTB | 未见对应实现 | BTB + 两位方向计数器，预测对错计数及纠错测试 |
| H2b | 完整 RISC-V 异常/中断机制 | 有CSR/CLINT基础；不能认定完整 | 明确M模式边界、异常矩阵、精确mepc、屏蔽/返回测试 |
| H3 | 基于CPU构建边缘AI，移植YOLO或轻量大模型，融合传感/显示 | 当前CPU工程未见该系统 | YOLO软硬件协同，OV5640输入，CPU配置加速器并输出结果 |
| E1 | 紫光同创FPGA平台 | 示例为Xilinx流程 | 盘古100Pro+ PDS工程、引脚/时序约束、资源与时序报告 |
| E2 | riscv32-unknown-elf-gcc | 原脚本指向旧工具链 | 指定工具链或取得兼容工具链确认，记录版本/编译参数 |
| E3 | CoreMark v1.0，运行至少10秒 | 有源码与旧平台截图 | 本板CRC正确、实际时钟、时间、迭代数、完整UART日志 |
| E4 | CoreMark/MHz、最高时序合格频率、CoreMark/LUTs | 没有本板测量 | 同配置、同编译参数的基线/改造/优化对照 |
| E5 | 应用延迟、识别率、资源、时序、主频 | 未实现 | 独立测试集、端到端延迟及硬件资源报告 |
| E6 | 模块化、合理约束、注释、性能文档及ILA波形分析 | 尚无本项目提交包 | 原理图、模块说明、波形、测试复现脚本、贡献说明 |

**赛题解释边界：**

1. 原文没有把“必须 AXI4”列为基础任务。AXI4 是你们主动选择的架构，服务 H1/H3；不能替代 RV32I 与性能验证。
2. 高阶 AI 原文明示 YOLO 或轻量版大模型。小分类 CNN、加法器或单个卷积核可以当学习里程碑，但不能自行宣布已经满足该高阶任务。若最终只做 CNN 分类，需先向主办方确认是否接受。

3. 第10页使用“传感器或者显示设备”，不是要求摄像头和HDMI同时具备。OV5640输入配CPU输出检测结果可作为方案，仍需完成整套真实AI应用；HDMI可后置。第11页还单列应用场景构建，不能把只有跑分的系统称为全部测评内容已覆盖。

### 1.2 来源与参赛范围关卡 G0

- [ ] 保存本地PDF的SHA256和第10-11页；只适用选题一，不混入选题二的1080P帧率或选题三的95%车牌准确率等要求。
- [ ] 当前目录README明确介绍开源tinyriscv，RTL含Blue Liang署名，根目录含Apache-2.0 LICENSE。这只能确认有开源基础，不能据此判断队友没有修改，也不能把全部现有代码写成队伍原创。
- [ ] 队长提供所用上游版本/取得日期和队友改动记录，形成`docs/provenance.md`：上游已有、队友已有、本项目拟新增三列；无Git历史时以文件哈希和可取得的上游快照逐文件比对。
- [ ] 向赛事组织方确认开源CPU复用、已有作品与新增贡献的参赛边界，并保存书面答复。本PDF没有足够信息判定这方面允许或禁止；开源许可与比赛原创性要求分别核对。
- [ ] 确认板卡实际型号、可用开发周数、成员分工、CPU高阶/AI目标档位；未确认前，不把全功能路线当作已承诺交付范围。

源码基线和学习验证可以先做；G0没有完成，不提交“全自主设计/参赛资格已确认”等表述。

## 2. 源码核对与必须改的原因

原工程根目录：

`E:\donwload\tinyriscv-master\tinyriscv-master`

本次发现不是 Git 工作树。保留此目录作为参考，实施前建立独立版本管理副本；不删除旧版本。

| 已核对位置（相对上述根目录） | 当前行为 | 原生AXI改造必须处理 |
|---|---|---|
| `rtl/core/tinyriscv.v:25` | 对外RIB取指/数据接口，无逐笔完成反馈 | 替换成AXI通道，加入事务生命周期 |
| `rtl/core/tinyriscv.v:216` | 当前PC和取指数据直接交IF/ID | 返回指令必须配对保存的请求PC |
| `rtl/core/rib.v:114` | 4主6从固定优先级组合选择 | 用保存事务归属的AXI互连替换 |
| `rtl/utils/gen_dff.v:37` | `hold_en`为1时写默认值 | 此处是清空，不是保持；不可直接用于等待DDR |
| `rtl/core/pc_reg.v:43` | 没暂停就PC+4 | 只在相应取指结果被接纳后推进 |
| `rtl/core/ex.v:640` | SB/SH读取旧字并拼接 | 改成WSTRB字节使能，不先读MMIO |
| `rtl/core/regs.v:67` | 同周期写回到读端旁路 | 只旁路已有效完成的结果，不能旁路未返回的load |
| `rtl/core/ex.v:185`附近 | 除法启动配合原有清空/跳转模式 | 改成单次启动、等待、单次提交，不能直接冻结旧逻辑 |
| `rtl/core/clint.v` | 在译码相关信息上触发中断/异常处理 | 改为按指令年龄和提交边界处理，不打断已发出的AXI写 |
| `rtl/soc/tinyriscv_soc_top.v:326` | UART下载、JTAG也是总线主设备 | 同样要改或明确暂禁，不可只改CPU而漏掉下载链路 |
| `rtl/perips/rom.v`、`ram.v` | 4096个32位字，组合读 | 16KiB各一块；改同步RAM与AXI响应时序 |
| `rtl/core/defines.v` | `INST_NOP=32'h00000001` | 无C扩展时不能当标准32位NOP；改用valid气泡及0x00000013显示值 |
| `tests/example/link.lds` | 程序0x0/16KiB，RAM 0x10000000/16KiB | 尽量保留地址，扩容后同步改链接脚本 |

以上是改造影响分析，不是完整的原CPU缺陷审计。旧实现可能依赖自己的组合总线约定；本计划不能假定替换总线后其他逻辑自然正确。

## 3. 先冻结接口规格，再写代码

### 3.1 最小原生 AXI4 配置

本方案从第一版就使用 AXI4 通道字段，先运行单拍，后启用突发，不走 AXI4-Lite 过渡。

| 项目 | 本方案选择 |
|---|---|
| 地址/数据宽度 | 32位/32位，小端 |
| ID宽度 | 4位；取指=0、数据=1、UART下载=2、JTAG=3、摄像头DMA=4、AI DMA=5 |
| 第一版并发 | 互连全局只接受1笔未完成事务，事务结束后再仲裁 |
| 单拍访问 | AxLEN=0；不是AXI4-Lite |
| Cache补行 | INCR，8拍，每拍4字节，即32字节一行 |
| DMA突发 | INCR，1至16拍，避开4KiB边界 |
| CPU子字访问 | ARSIZE/AWSIZE按1/2/4字节，字节lane按地址低2位 |
| 首版不发出 | FIXED、WRAP、独占、乱序、多笔同ID挂起 |
| 首版响应 | 正常OKAY；地址未映射DECERR；目标访问错误SLVERR |
| 时钟域 | CPU、互连、BRAM、基础外设同域；DDR/相机独立处理 |
| 回压 | AR/AW/W/R/B都允许等待；保持VALID与负载直至握手 |

说明：不使用某些可选能力，不等于必须假装“支持AXI4全部可选特性”。交付时公开该 profile。外来主设备要满足它；不能把仅能接本系统流量的从设备宣传为任意AXI4流量全兼容。

### 3.2 五个通道，CPU数据主接口方向

| 通道 | CPU输出 | CPU输入 | 通俗含义 |
|---|---|---|---|
| AR | ARID[3:0], ARADDR[31:0], ARLEN[7:0], ARSIZE[2:0], ARBURST[1:0], ARLOCK, ARCACHE[3:0], ARPROT[2:0], ARQOS[3:0], ARVALID | ARREADY | 我要读哪里、读多少 |
| R | RREADY | RID[3:0], RDATA[31:0], RRESP[1:0], RLAST, RVALID | 对方返回读数据 |
| AW | AWID[3:0], AWADDR[31:0], AWLEN[7:0], AWSIZE[2:0], AWBURST[1:0], AWLOCK, AWCACHE[3:0], AWPROT[2:0], AWQOS[3:0], AWVALID | AWREADY | 我要写哪里、写多少 |
| W | WDATA[31:0], WSTRB[3:0], WLAST, WVALID | WREADY | 具体写入内容 |
| B | BREADY | BID[3:0], BRESP[1:0], BVALID | 整笔写事务是否成功 |

取指接口只需AR/R读通道；若顶层统一打包读写接口，明确禁用并固定写输出。AXI4没有WID。REGION/USER本系统不使用，若实际IP暴露则按其文档固定，不随意删必需信号。

固定值建议：AxLOCK=0，AxQOS=0，AxBURST=2'b01，AxCACHE首版=4'b0000。M模式非安全指令ARPROT=3'b111，数据AxPROT=3'b011；目标IP是否解释这些属性仍需核验。Cache内部可缓存区域由地址表单独控制，不能把AxCACHE直接当成本地cache开关。

### 3.3 看一个8拍读例子

读地址从0x10000000起连续32字节：

```verilog
ARADDR  = 32'h10000000;
ARLEN   = 8'd7;       // 拍数减1
ARSIZE  = 3'd2;       // 每拍字节数=2**2=4
ARBURST = 2'b01;      // INCR，地址递增
```

成功接收数据地址依次为0x10000000、04、08、0C、10、14、18、1C。只有 `RVALID && RREADY` 才算收到一拍；不是每过一个时钟就加计数。第8拍必须看到RLAST。

### 3.4 全工程必须遵守的规则

- VALID一旦置1，未握手时不得撤销；对应地址、长度、数据等必须保持。
- 发送方不能等READY变1才决定是否置VALID，否则可能互相等待。
- AW和W分别记录完成，不能要求两者同一拍握手。
- 写响应在AW及全部W拍被接收后才能完成；CPU不能仅因WREADY=1就认定store退休。
- 总线事务已经发出后，分支不能“取消”它；错误路径取指响应要接完再丢弃。
- 突发不能跨4KiB边界。按实际字节地址计算，不能按错误的字地址计算。
- 未握手时不要改变读写计数，RLAST/WLAST按拍数生成与检查。
- RRESP/BRESP错误不能当成0数据或正常完成。
- reset/halt不能把已接受事务遗留给仍在运行的另一端。
- 外设读可能有副作用，禁止把MMIO当普通RAM进行投机读、预取或Cache补行。

### 3.5 CPU内部接口与Cache插入位置

统一选择“CPU操作接口 -> 可选Cache/旁路 -> AXI事务引擎”，CPU顶层对外仍是原生AXI4。CPU内部操作接口不是RIB桥，不复用旧RIB仲裁和组合读完成语义。

| 模块 | 独占职责 | 不允许重复实现的职责 |
|---|---|---|
| `ifu_axi.v` | PC/redirect、请求身份、预留响应槽、正确路径结果交付；容纳可选I-Cache及读引擎 | 不让I-Cache另建一套架构PC或向流水线重复送指令 |
| `lsu_axi.v` | 锁存EX操作、对齐检查、一次完成/异常、load扩展；容纳可选D-Cache及数据引擎 | 不让D-Cache重复退休、再次移位字节或另发同一笔store |
| `icache_2way.v` / `dcache_2way.v` | tag/data/LRU、命中、缺失与补行控制；向下提交传输描述符 | 不直接改变GPR、CSR、架构PC或trap状态 |
| `axi_read_engine.v` / `axi_data_engine.v` | 保存AXI字段、VALID稳定、计拍、响应与错误；数据引擎含AW/W/B | 不解释RISC-V指令，不生成第二个CPU完成事件 |

无Cache时旁路控制器提交单拍描述符；有Cache时向同一引擎提交补行或直达描述符。引擎描述符使用`valid/ready, addr, size, len, id`，写数据单独`valid/ready, data, strb, last`；读返回逐拍`valid/ready, data, resp, last`，写结果保持至消费。

I侧操作请求保存`pc`及预测下一PC，返回原`pc/inst/fault`；D侧操作接口沿用第10.1节。D-Cache与旁路向LSU返回未扩展的对齐32位字，LSU只做一次lane选择及符号扩展。T02前把这些端口、位宽和生命周期写入`docs/cpu_memory_contract.md`；T09只能扩展Cache内部，不推翻EX/IF-ID合同。

### 3.6 必须能继续前进的约束

全局单事务只限制互连已经接纳/呈现到下游的事务，不意味着其他主机不得保持待处理VALID。每个主设备必须在发请求前保证最终能独立接收返回，不能依赖另一笔还在等待仲裁的事务完成。

- IFU发AR前预留一个完整响应槽；AR发出后，只要该槽空，就接R，即使EX因load暂停。否则会形成“IF占总线 -> IF等EX解除stall -> EX等LSU获得总线”的循环等待。Cache补行同理预留一行或可独立消化的逐拍存储。
- 写owner在首次呈现AWVALID时锁定。向目标发送WVALID不能依赖目标AWREADY或AW已握手；两者可以独立握手。需要缓存时分别记录上游AW/W接收与下游AW/W发送。
- 首版不从MMIO区域取指：在地址属性检查阶段生成instruction access fault，不发AR；不能因错路预测读取UART并弹出FIFO。DDR未就绪时也不提前发出会长期占住全局互连的请求。
- 轮询在完整事务结束后推进；持续竞争时按最大事务拍数、目标响应上界、仲裁者数量记录最坏等待。AI/视频接入后重新测吞吐和FIFO占用，首版单事务仅是正确性基线。

## 4. 地址地图：尽量不破坏已有软件

| 区域 | 基地址 | 第一版实际范围 | 可缓存 | 访问策略 |
|---|---|---|---|---|
| 程序RAM，保留模块名rom | 0x00000000 | 16KiB，至0x00003FFF | I可缓存；D首版不缓存 | 调试停机后可写，运行时禁止误写代码 |
| 数据RAM | 0x10000000 | 16KiB，至0x10003FFF | D可缓存 | 支持1/2/4字节与补行 |
| Timer | 0x20000000 | 沿用原寄存器偏移 | 否 | 单拍 |
| UART | 0x30000000 | 沿用原寄存器偏移 | 否 | 单拍 |
| GPIO | 0x40000000 | 沿用原寄存器偏移 | 否 | 单拍 |
| SPI | 0x50000000 | 沿用原寄存器偏移 | 否 | 单拍 |
| AI控制，拟新增 | 0x60000000 | 4KiB地址窗口 | 否 | 单拍，未实现偏移报错 |
| 图像DMA控制，拟新增 | 0x60001000 | 4KiB地址窗口 | 否 | 单拍 |
| 性能计数器，拟新增 | 0x60002000 | 4KiB地址窗口 | 否 | 单拍，只读或显式清零 |
| IRQ控制，拟新增 | 0x60003000 | 4KiB地址窗口 | 否 | 单拍，软件pending/外部pending与mask，见13.2 |
| DDR，拟新增 | 0x80000000 | 容量由板卡/IP核验后冻结 | 程序/普通数据可缓存 | 图像共享缓冲设不可缓存区 |

原RIB按高4位选择设备，不代表设备真的有256MiB。新互连必须检查实际容量与有效寄存器偏移，越界返回错误，不允许数组索引越界或地址镜像。

本计划不沿用之前聊天中随口举的UART=0x10000000示例，它与当前工程真实地址分配不符。

## 5. 文件改造地图

所有相对文件名仅是目录图；打开文件时以这里的绝对根目录拼接。

实施副本拟定：`E:\file\pango\tinyriscv_axi4`。尚未创建，不把它当已存在的工程。

| 处理 | 原文件或拟建文件 | 职责/边界 |
|---|---|---|
| 修改 | rtl/core/tinyriscv.v | 删除RIB外部端口，连接原生取指/LSU、retire |
| 修改 | rtl/core/pc_reg.v | 基于取指消费与redirect更新PC |
| 修改 | rtl/core/if_id.v、id_ex.v | valid、ready、flush，保留未消费指令 |
| 修改 | rtl/core/ctrl.v | 分离stall、flush、redirect、halt |
| 修改 | rtl/core/ex.v | 生成访存意图，等待LSU；运算结果只有完成时有效 |
| 修改 | rtl/core/id.v | 保留译码主线，加入非法编码检测、源寄存器使用信息 |
| 修改 | rtl/core/regs.v、csr_reg.v | 提交写使能、旁路、CSR合法性、性能计数 |
| 修改 | rtl/core/clint.v | 指令年龄/提交边界上的异常中断控制 |
| 保留算法/增加控制层 | rtl/core/div.v、新增div_adapter.v | 原div运算中要求start持续为1；adapter将一次请求转换为保持电平并保存结果，不能直接打一拍start |
| 新建 | rtl/core/ifu_axi.v | 保存取指PC、发AR、收R、缓存响应、错路丢弃 |
| 新建 | rtl/core/lsu_axi.v | load/store状态机、WSTRB、响应错误与完成 |
| 新建 | rtl/core/axi_read_engine.v、axi_data_engine.v | CPU内部AXI传输引擎，旁路与Cache复用，详见3.5 |
| 新建 | rtl/core/retire_ctrl.v | 单次提交、同步异常、退休后异步中断 |
| 新建 | rtl/core/pipe_slot.v | 专用于新流水线的保持/清空槽，不全局改旧gen_dff |
| 新建 | rtl/core/axi_defs.vh | AXI参数和response常量，不覆盖ISA宏 |
| 替换 | rtl/core/rib.v -> rtl/bus/axi_interconnect.v | AXI仲裁、地址译码、保存owner、路由响应 |
| 新建 | rtl/bus/axi_error_slave.v | 未映射访问有界响应，不死等 |
| 修改 | rtl/perips/rom.v、ram.v | 原生AXI4，同步读，WSTRB，突发 |
| 修改 | rtl/perips/uart.v、gpio.v、timer.v、spi.v | 外设本体内实现AXI接收/响应，不保留RIB外部接口 |
| 修改 | rtl/debug/uart_debug.v、jtag_dm.v、jtag_top.v | 原生AXI调试内存访问，握手完成后才确认 |
| 修改 | rtl/soc/tinyriscv_soc_top.v | 删除RIB连接，暴露真实GPIO引脚，连接AXI网络 |
| 新建 | rtl/cache/icache_2way.v、dcache_2way.v | 两路Cache |
| 新建 | rtl/core/branch_predictor.v | BTB与方向计数器 |
| 新建 | rtl/perips/perf_regs.v | 计数器快照与读出 |
| 新建 | rtl/perips/irq_ctrl.v | T07b软件/外部中断来源、pending/mask、单拍MMIO |
| 新建 | rtl/ai/ai_control.v、mac_array.v、conv_engine.v、tensor_dma.v | 模型控制、计算、搬运 |
| 新建 | rtl/video/ov5640_capture.v、frame_dma.v | 相机接入，帧所有权 |
| 新建 | fpga/pango/pango_top.v | 板级时钟/复位、引脚、IP连接 |
| 修改/新增 | sim/、tb/、tests/ | 可变延迟、协议检查、程序测试和报告 |
| 修改 | tests/example/init.c、trap_entry.S、trap_handler.c、include/utils.h、lib/utils.c | 标准中断使能/分发、异常返回、CSR访问与64位计时 |
| 修改 | tests/example/common.mk、coremark/Makefile、link.lds、start.S | 工具链、ISA/ABI、内存容量、初始化镜像 |

ROM/外设把AXI请求解码成内部寄存器写使能是正常从设备实现，不是RIB桥。禁止在其外面留下旧RIB模块再套协议转换器。

## 6. 工具和基线：任务 T00

**目的：** 留下“修改之前能运行什么”的证据，后续坏了才知道是哪里引入。

### 操作

- [ ] 确认源目录没有未保存编辑；复制到上面的实施副本，原目录保持不动。
- [ ] 在副本初始化Git，提交原始源码；若队伍已有Git仓库，则在其约定分支工作，不另建冲突仓库。
- [ ] 保存赛题PDF摘要、本计划、源文件SHA256、工具版本到`docs/evidence/baseline/`。
- [ ] 在副本运行`Get-Command vsim,vlog,vlib,python`。本次发现ModelSim位于`E:\donwload\win64`，存在不等于许可证可用。
- [ ] 检查编译器：`riscv32-unknown-elf-gcc --version`；如果不存在，先配置工具链，不用宿主机GCC替代。
- [ ] 先运行原`add`测试，再运行原指令集套件；逐项保存PASS/FAIL，不仅看“全部通过”一句话。

原Icarus路径的运行命令（仅在iverilog/vvp已可用时）：

```powershell
Set-Location 'E:\file\pango\tinyriscv_axi4\sim'
python .\sim_new_nowave.py ..\tests\isa\generated\rv32ui-p-add.bin inst.data
python .\test_all_isa.py
```

现有脚本写死Icarus，不能因为已装ModelSim就直接认为能运行。**第三轮统一采用第27.2-27.3节的根目录相对文件清单与runner**。下面仅解释Tcl批处理含义，不再作为另一套基线入口；实际命令与工作目录以第27节为准：

```tcl
onerror {quit -code 1}
if {![file isdirectory work]} {vlib work}
vlog -sv +incdir+../rtl/core -f baseline_sources.f
vsim work.tinyriscv_soc_tb
run -all
quit -code 0
```

`baseline_sources.f`完整内容见27.2，仅含原设计，不夹入未来AXI模块。旧工具链的`$readmemh`输入可由`tools/BinToMem_CLI.py`生成；以下是原流程参考，新runner已集成尾字节填充和镜像生成，不必重复执行：

```powershell
python ..\tools\BinToMem_CLI.py ..\tests\isa\generated\rv32ui-p-add.bin inst.data
vsim -c -do modelsim_baseline.do -l baseline_add.log
```

基线测试台原先的`$finish`不保证进程退出码代表通过。因此外层运行脚本必须同时检查：进程结束、无fatal、日志含`TEST_PASS`、没有失败标记、确实执行了至少一个用例。若超时，终止本次子进程并失败，不留下后台仿真。

**通过标准：** 可复现的基线报告；失败项目明确记录，不能把已有失败算成改造成功。至少通过add及全套基线结果登记后才开始CPU替换；全套基线失败须先定位。独立T01平台不依赖CPU，可并行。

T01独立AXI测试平台可与T00并行；T02开始替换CPU前，必须完成全套原始基线结果登记与失败归因，而不只看add。源码目录现有`sim/out.vvp`和VCD不是本轮执行结果，不能拿来替代新编译日志。

### T00-P：尽早核验板卡和PDS，不等待总线重构

- [ ] 核对器件、PDS许可证、下载器、引脚和时钟；先复现板卡最小LED/UART或同步BRAM例程，保存实现及下载结果。
- [ ] 若需要原RIB上板C0参考，在独立参考工程进行，保留源目录不动；它不进入最终原生AXI文件清单，也不宣传为新增成果。
- [ ] 提前编译CoreMark移植层并生成map/size报告：检查程序镜像、`.data/.bss`、栈及堆是否落在实际16KiB窗口。超限先定BRAM扩容及地址译码，不把DDR当基础跑分必需条件。
- [ ] `BinToMem_CLI.py`当前只输出完整四字节组；若输入长度不是4的倍数，计划在副本的镜像工具中明确填充并验证，不能默默丢尾字节。PDS程序初始化需包含`.data`的装载镜像。

这是平台风险排查，不等于原生AXI CPU已上板。失败应尽早影响排期，而不是等T07结束才发现工具或板卡不可用。

## 7. 先做测试环境：任务 T01

**新建路径（均位于实施副本）：**

- `tb/axi/axi_memory_model.sv`
- `tb/axi/axi_monitor.sv`
- `tb/axi/tb_axi_memory.sv`
- `sim/run_axi_tests.ps1`
- `sim/axi_sources.f`

### 操作

- [ ] 写一个同步时钟测试台，复位低有效至少5拍，然后在非采样边沿释放。
- [ ] memory model独立保存AR、AW、W状态，不要求AW/W同周期；地址/写数据各设1项缓存。
- [ ] 添加字节数组scoreboard：写操作只更新WSTRB对应字节，读操作逐字节比较。
- [ ] 分别控制ARREADY、AWREADY、WREADY延迟，以及RVALID/BVALID延迟；主端也随机压低RREADY/BREADY。
- [ ] 添加固定seed参数，记录失败seed、地址、期望值、实际值。
- [ ] 加总周期watchdog，例如每个小测试100000周期；超时用`$fatal(1,"TIMEOUT")`。
- [ ] 结束时检查事务计数与队列全部清空，再打印唯一`TEST_PASS <case>`。

最小握手理解：

```verilog
wire ar_fire = arvalid && arready;
wire r_fire  = rvalid  && rready;
wire aw_fire = awvalid && awready;
wire w_fire  = wvalid  && wready;
wire b_fire  = bvalid  && bready;
```

监视器应检查的性质（用SVA或等价逐拍寄存器检查；老ModelSim不支持某些SVA时用后者）：

```systemverilog
assert property (@(posedge clk) disable iff (!rst_n)
    arvalid && !arready |=> arvalid &&
    $stable({araddr,arid,arlen,arsize,arburst,arlock,arcache,arprot,arqos}));
assert property (@(posedge clk) disable iff (!rst_n)
    wvalid && !wready |=> wvalid && $stable({wdata,wstrb,wlast}));
```

对AW/R/B也做同类稳定性检查。再检查无孤立响应、ID一致、拍数一致、最后拍正确。测试台不能只用永远READY=1的内存。

**具体首批用例：** 写0x12345678再读回；AW先到5拍、W先到5拍、同拍到；R阻塞7拍；B阻塞7拍；8拍突发每拍间隔不同；未映射地址返回错误。

**通过标准：** 先故意破坏一个稳定性/拍数规则，确认monitor能报错，再恢复测试模型使全部通过。一个“永远通过”的测试环境不能用来验收CPU。

## 8. 流水线语义：任务 T02

**修改文件：** `pc_reg.v`、`if_id.v`、`id_ex.v`、`ctrl.v`、`ex.v`、`tinyriscv.v`。同步定义`retire_ctrl.v`的正常提交/异常接纳合同，T07再完善异常矩阵，不能到T04才第一次决定retire接口。

### 8.1 三个词必须分开

| 词 | 意思 | 寄存器行为 |
|---|---|---|
| stall | 这条指令还没完成，等一下 | 保持内容与valid |
| flush | 这条指令走错路/被异常清除 | valid清零 |
| bubble | 没有真实指令 | valid=0，不产生任何副作用 |

不能用当前`gen_pipe_dff`的hold来代替stall，因为它写默认值。

### 8.2 冻结的流水线协议

- IF/ID保存`valid, pc, inst, fault, predicted_next_pc`。
- ID/EX保存同样身份字段及译码控制、操作数、rd、CSR信息。
- EX保持占有当前指令，直到运算/访存完成或产生同步异常。
- 初版采取保守策略：EX等待load/store/div时，冻结年轻阶段，不允许后续指令越过。
- EX完成且允许提交时形成一次`retire_fire`；寄存器、CSR和分支训练只在规定的提交事件更新。
- 已发出store不能因中断到来撤销；收完B并提交后才接纳异步中断。
- 同步异常不退休，不写rd；保存该指令PC进入trap。

年龄顺序固定为EX老于ID、ID老于IF。EX跳转/异常清除年轻槽，不清除已被接受的AXI事务；年轻取指错误先作为fault字段排队，不越过更老EX立即进入trap。维护独立`arch_next_pc`，表示下一条尚未执行的架构指令地址。异步中断在一条指令提交后可接纳，也必须在EX已空、只有年轻取指等待时检查；不能只用`retire_fire`作为检查触发。接纳时保存`arch_next_pc`，禁止同拍年轻指令进入EX。分支提交同拍中断返回PC为实际分支目标；MRET/CSR修改后用更新后的中断使能状态重新检查。详见13.2。

ID必须在真正进入ID/EX的那一拍读取并锁存操作数；若EX此拍提交相同rd，使用已完成写回结果旁路。不能在等待load的第一拍就冻结年轻指令的旧操作数，再在load完成后不重新取值。CSR相关也需提交时旁路或额外阻塞一拍。

槽位控制示意，`payload_i`指包含PC/指令等字段的打包数据：

```verilog
assign in_ready = rst_n && !flush && (!valid_q || out_ready);
assign out_valid = rst_n && !flush && valid_q;
always @(posedge clk) begin
    if (!rst_n) begin
        valid_q <= 1'b0;
    end else if (flush) begin
        valid_q <= 1'b0;
    end else if (in_ready) begin
        valid_q <= in_valid;
        if (in_valid) payload_q <= payload_i;
    end
end
```

这些是设计模板，不是把未声明变量直接复制进原工程即可编译的补丁。先在`pipe_slot.v`声明数据宽度参数与对应端口，再通过独立测试后替换两个流水线寄存器。

内部消费统一用`in_fire=in_valid && in_ready`、`out_fire=out_valid && out_ready`，flush周期均不能产生年轻槽位的握手或副作用。产生redirect的老EX指令仍可正常提交，只清其年轻槽位。外部AXI不使用此取消规则，仍须保持VALID并排空。增加flush与输入/输出原本可握手同拍的测试。

### 操作与测试

- [ ] `pipe_slot`测试：装入A、下游阻塞10拍、输出始终A，解除后只消费一次。
- [ ] flush与stall同时出现时，错误路径指令清除；复位最高优先。
- [ ] 保留纯算术译码，给普通ALU指令`ex_done=1`，load/store由LSU完成，div由除法完成。
- [ ] 删除旧除法“启动时跳转/清空”的控制用法；每条EX除法向`div_adapter`握手一次并保存rd。原`div.v`在START/CALC/END检查start电平，adapter须保持start直到ready，并在ready出现时阻止下一次意外启动；不是向原div打一拍脉冲。方法见28.4。
- [ ] 暂停期间不得反复写CSR、发store、训练预测器或重复启动除法。
- [ ] 执行`addi x1,x0,5; addi x2,x1,3; add x3,x1,x2`，期待5、8、13。
- [ ] 测试`lw x1,0(x10); add x2,x1,x1`，将读返回延后20拍，x2必须使用返回值。

**通过标准：** 用单调递增`retire_order`核对提交事件，按`PC/指令/rd/写值/内存效果`与参考轨迹比较；PC本身不充当唯一身份，因为循环会合法重复PC。

**依赖分层：** T02先用测试台注入指令和可控延迟LSU/div完成模型验槽位、旁路与单次提交；它不是完整SoC通过。T03/T04分别用AXI模型验单元，T05用测试主机验互连/从设备；上述单元都完成后，进行T05-I CPU集成回归，再宣称真实load-use/分支/AXI共同通过。不能要求T02先在尚不存在的T04/T05硬件上通过完整程序。

## 9. 原生取指：任务 T03

**新建：** `rtl/core/ifu_axi.v`及其内部`axi_read_engine.v`。**修改：** `pc_reg.v`、`tinyriscv.v`、`if_id.v`。以下状态表表示组合后的行为，AXI握手寄存器归引擎独占，不能在两层重复驱动。

### 保存的状态

`request_pc[31:0]`、`req_live`、`inst_buf[31:0]`、`response_pc[31:0]`、`response_valid`、`discard_pending`、`redirect_target[31:0]`、响应错误字段。`req_live`从IFU与读引擎的内部`req_fire`开始置位，直到该请求结果被交付或丢弃后才清零。

初版最多1笔取指事务，一个返回缓冲。

| 状态 | 行为 | 离开条件 |
|---|---|---|
| IDLE | 缓冲空且允许取指时，保存PC和AR字段 | 进入SEND_AR |
| SEND_AR | ARVALID保持1 | AR握手后进入WAIT_R |
| WAIT_R | 使用发AR前已预留的响应槽，接收不依赖EX stall | 收到唯一R拍并检查RLAST/RESP |
| HAVE_INST | 保存指令及请求PC，送IF/ID | IF/ID握手后清缓冲 |
| DRAIN | redirect后旧请求仍要完成 | 收完旧返回，丢弃后取新目标 |

### 必须覆盖的分支时序

- redirect与内部`req_fire`同拍：redirect优先；可以组合阻止旧请求接单，也可以接单后立即标记丢弃，但不能把旧PC当成新路径请求。
- 读引擎已内部接单、尚未向AXI完成AR握手：旧请求已经属于IFU，必须保持地址稳定、继续收尾并丢弃。不能等到观察到外部ARVALID或AR握手后才开始跟踪。
- 在ARVALID=1但ARREADY=0时跳转：不能撤销ARVALID或修改ARADDR；标为丢弃，握手并收完旧响应。
- AR已握手、R未返回时跳转：保存新目标；旧响应接收但不送译码。
- R返回与redirect同拍：redirect决定该年轻取指失效。
- R结果已停在读引擎/IFU返回槽、下游尚未接纳时跳转：清交付资格并丢弃，不能因为AXI事务已经结束就让旧指令进入IF/ID。
- 多次redirect发生在同一旧请求等待期间：保留最新架构有效目标；discard不能被第二次redirect清零。
- 旧路径取指报错：丢弃，不对新路径产生伪异常。

取指PC推进以返回指令被IF/ID接受为准；redirect优先。请求PC和当前PC必须是两个寄存器概念，禁止把新PC贴到旧返回指令上。

### 操作

- [ ] 先用ROM内容0x00500093等已知指令测试AR地址与返回配对。
- [ ] 仅AR/R单拍：ARLEN=0，ARSIZE=2，ARBURST=INCR，ARID=0。
- [ ] 测RRESP错误，正确路径产生取指访问异常；错误路径只排空。
- [ ] 测内部`req_fire`同拍、内部已接单但AR未握手、AR已握手等待R、R同拍及结果槽等待交付等redirect时刻和10次随机延迟seed。
- [ ] 单元探索阶段可先跑10次seed，阶段验收按第20节统一补齐固定seed 1至20。
- [ ] 将结果接IF/ID，运行无访存算术/跳转小程序。
- [ ] 取指已经占用全局互连时，令EX发load并暂停：旧R必须先进入预留槽释放互连，随后LSU获得服务，不形成相互等待。
- [ ] 分支目标/预测目标落入UART等MMIO时，IFU不发AR；正确路径报访问异常，错误路径丢弃fault且外设读副作用为零。

**通过标准：** 每个交给译码的指令和PC正确配对，redirect后没有错误路径退休。

## 10. 原生访存：任务 T04

**新建：** `rtl/core/lsu_axi.v`及其内部`axi_data_engine.v`。**修改：** `ex.v`、`tinyriscv.v`、`retire_ctrl.v`。以下状态表为整体事务流程；AXI通道寄存器在数据引擎内实现，LSU独占CPU操作的完成/异常状态。

### 10.1 EX与LSU内部接口

EX输出一次操作：`op_valid, is_store, address, store_value, access_size, load_unsigned, pc, rd`。

LSU用`op_ready`接收；收到后自行保存。输出`done_valid, load_value, fault, fault_addr`，EX返回`done_ready`。`done_fire=done_valid && done_ready`才释放LSU结果。接口不再有RIB的外部仲裁/组合读假设。

EX每条指令带`issued`位：新指令进入EX清零；`op_fire=op_valid && op_ready`时置1；`op_valid=ex_valid && is_memory && !issued && !precheck_fault`，防止等待期间重复发起。成功完成且提交控制允许时`retire_fire`发生一次；同步异常由`trap_fire`接纳，异常指令不计退休。`ex_leave=retire_fire || trap_fire`，正常离开才允许年轻指令进入EX，trap/redirect则禁止年轻指令同拍进入并执行清除。LSU结果在相应retire/trap接纳时由done_ready消费；前置未对齐异常没有LSU请求，直接由trap路径处理。issued仅在旧指令离开并装入新指令时清零。

### 10.2 读状态机

```text
IDLE -> 捕获一次load -> SEND_AR -> WAIT_R -> DONE -> IDLE
```

- ARID=1，ARLEN=0，ARSIZE=0/1/2分别对应byte/half/word。
- 保存有效地址低2位与有无符号，不能从已经变化的EX输入重新计算。
- R握手成功且响应OKAY后，移位选字节、符号扩展，再发done。
- R错误产生load access fault，不写rd。
- DONE必须保持结果直到EX消费，不能给一个可能被暂停吃掉的脉冲。

### 10.3 写状态机

```text
IDLE -> 捕获一次store -> SEND_AW_AND_W -> WAIT_B -> DONE -> IDLE
```

AW和W分别用`aw_pending`、`w_pending`记录；两者从保存字段独立产生VALID。某通道握手就只清该pending。单拍WLAST=1。两者都被接收后等待B；先返回B的从设备属于错误实现。

写完且收到OKAY才正常退休。BRESP错误产生store access fault；不得自动重试，因为外设可能已发生副作用。

### 10.4 SB/SH/SW：直接改写旧拼接逻辑

设`offset = address[1:0]`：

```verilog
// 下列值在接受操作时算好并保存。
// SB:
wdata = store_value << (8 * offset);
wstrb = 4'b0001 << offset;
// SH，只允许offset=0或2:
wdata = store_value << (8 * offset);
wstrb = 4'b0011 << offset;
// SW，只允许offset=0:
wdata = store_value;
wstrb = 4'b1111;
```

例如原字0x11223344，在base+1执行SB写0xAA：发送WDATA=0x0000AA00、WSTRB=0010，内存变成0x1122AA44。不能先读UART寄存器来保留其他字节。

load先把RDATA逻辑右移`8*offset`，LB/LH对选出的8/16位符号扩展，LBU/LHU补零。窄传输有效字节在哪个lane按AXI地址规则确定；测试模型必须同样按lane处理。

本方案选择对未对齐LH/SH/LW/SW产生同步异常，在发AXI请求前检查，不静默取错字节，也不首版实现跨字拆分。

### 验收

- [ ] 全部LB/LBU/LH/LHU/LW/SB/SH/SW，四个字节lane及合法halfword位置。
- [ ] AW先/W先/同拍，写响应推迟30拍，store只发生一次。
- [ ] load-use、store后load、连续store、存入x0对应数据、load目标x0仍需访问及处理错误。
- [ ] load后紧接ALU、分支、store数据依赖，提交同拍使用新结果旁路；load fault时下一条绝不能进入EX。
- [ ] 未对齐访问不产生任何总线事务；读写错误不错误写回。
- [ ] store等待中请求中断：先处理已发出事务，再在合法边界进入中断。

**通过标准：** 字节scoreboard与CPU寄存器结果一致，AW/W/B计数无多发漏发。

## 11. AXI存储、外设及互连：任务 T05

### 11.1 先做程序RAM/数据RAM

修改`rtl/perips/rom.v`、`ram.v`：

- [ ] 接收AR时保存地址、size、len、id；每拍生成同步存储读地址。
- [ ] 用输出寄存器保持RDATA/RID/RRESP/RLAST，R未消费不能覆盖。
- [ ] AW与第一拍W可以不同时间到达；AW缓存与W缓存分别设计。
- [ ] W握手只表示接收到缓存，不一定此刻写RAM。仅在AW描述符有效、对应W数据已缓存且地址检查通过后，才按WSTRB写一次；缓存占满时拉低WREADY。
- [ ] AW已接受且全部预期W拍已实际处理后才给一次B，检查WLAST与AWLEN一致；不能仅凭W先到或看到WLAST就响应。
- [ ] 支持单拍窄访问及32位INCR补行突发；检查容量、4KiB、拍数、WLAST。
- [ ] 不将整个RAM逐字复位，采用PDS支持的初始化方式，保持BRAM推断机会。
- [ ] 程序加载后恢复CPU运行前，清除I-Cache及预取内容。

### 11.2 外设直接实现AXI4

UART/GPIO/Timer/SPI保留内部功能逻辑，替换总线入口：

- [ ] 捕获AW和W后，只产生一次寄存器写事件；保留旧寄存器偏移。
- [ ] 根据WSTRB更新对应byte，不无条件全字覆盖。
- [ ] AR接受后只读取一次；若寄存器读有清除/FIFO弹出副作用，只执行一次并缓存返回。
- [ ] 单拍服务正常；不允许MMIO预取/突发。错误突发要消费到约定末拍并返回错误，不能随意丢通道造成死锁。
- [ ] 未实现寄存器/权限不符返回SLVERR；UART发送忙的处理沿用软件可见状态，不静默丢字。
- [ ] 写寄存器只读字段不生效；明确是忽略还是SLVERR，并与驱动一致。

原生AXI4从设备不等于所有外设都要实现“图像突发写寄存器”；主端对MMIO使用单拍即可。

### 11.3 第一版互连：简单但正确

新建`rtl/bus/axi_interconnect.v`：

- [ ] 空闲时在所有主设备的AR/AW请求中轮询，保存owner、读写类型、target、ID。
- [ ] 在首次向目标端呈现ARVALID/AWVALID时即锁定grant，不等地址握手才锁；目标READY低期间不得重新轮询或换地址。也可使用一级请求寄存缓冲，但上游接收与下游发送必须各自独立记录。
- [ ] 只对选中的请求拉READY；锁定owner直至读RLAST握手或写B握手。
- [ ] 写owner由AW请求grant锁定，不依赖AW握手完成；选定owner的AW/W独立向下游呈现，不能用`aw_done`门控下游WVALID。主端W可先保持VALID，尚未选定owner时互连可以暂不接收W，但选定后不得等待AWREADY才转发W。
- [ ] AXI4没有WID，不能中途把另一个主机的W数据混进本事务。
- [ ] R/B按保存的owner返回，不按当前地址重新选人。
- [ ] 未映射目标走error slave；读错误仍返回正确拍数与末拍，写错误收完W再返B。
- [ ] 正常或错误响应都必须等完整事务结束才释放owner：读到预期末拍握手，写到B握手；不能首拍RRESP报错就换owner。硬复位按T06协调所有端点，默认值不能制造虚假READY握手。

全局一笔未完成事务会限制吞吐，但逻辑容易验证。后续可以分目标、读写独立仲裁；这属于性能优化，不能在初版同时做多ID乱序。

**验收：** CPU取指与load/store竞争、2个测试主机交错读写、两个主机同时请求且目标AR/AW阻塞20拍、未映射访问、全部通道随机等待，无串包/死锁；UART只输出一次字符。

**新增必测：** 从设备只有看到WVALID才拉AWREADY，互连仍应完成写事务；读burst第2拍SLVERR但其余6拍仍返回时，owner必须保持到第8拍；CPU IF与LSU循环等待用例见T03。无映射读和协议正常的错误burst有界收尾；缺W拍、永不RLAST等违规主/从设备不能承诺“无限流量也恢复”，monitor报协议失败，硬件按协调故障处理。

**T05-I集成门槛：** T02控制单元、T03 IFU、T04 LSU、T05互连/存储各自通过后，再连接CPU并运行真实指令回归、随机等待和错误路径测试；新文件清单不得混入旧RIB。

## 12. 调试下载、错误与复位：任务 T06

不能只改CPU而留下调试主设备的旧总线。

- [ ] `uart_debug.v`：收完一个下载字形成原生AXI写，等BRESP成功才确认/推进地址；若串口不能回压，增加FIFO或软件分块确认。
- [ ] `jtag_dm.v/jtag_top.v`：DMI内存命令转为原生AXI状态机，等待完成再更新结果/状态；不保留RIB端口。
- [ ] 直接访问GPR/CSR只允许CPU已经安全halt；debug写不与CPU提交争抢。
- [ ] halt请求先锁存为`halt_pending`。它立即停止**新取指和年轻指令进入EX**，但“停止新请求”只指尚未属于当前架构指令的新工作，不能禁止当前EX老指令为完成自己而首次发出的load/store/div请求。
- [ ] 当前EX指令若尚未`op_fire`，仍允许它恰好发起一次必要的LSU/除法请求；若已经发出则继续等待完成或报错。halt与`op_fire`同拍时，该请求归当前老指令所有，必须完成，不能因halt把`issued`或AXI状态清零。
- [ ] 已发出的年轻取指继续排空并丢弃，不能送入IF/ID，也不能因错误路径RRESP产生架构异常。只有当前EX完成一次退休或同步异常处理、IFU/LSU/AXI在途事务均收尾、年轻槽位已清空后，才拉`halted`。
- [ ] 恢复PC取最终架构边界的`arch_next_pc`，不能取可能已经超前的`fetch_pc`。当前EX成功退休后保存其下一PC；EX为空时保存最老尚未执行的架构PC。恢复后第一条指令只执行一次，不跳过也不重复。
- [ ] halt时不仅总线空闲，还要使EX在可解释的指令边界完成/报错；无Cache时清年轻预取，有Cache后还需维护debug写数据命中的D-Cache以及I-Cache/BTB。写直达仍可能有陈旧读副本，不能只失效I侧。
- [ ] soft reset同样先排空；硬reset必须协调互连/目标一起复位。DDR继续运行时不能只清主设备。
- [ ] 首版允许编译开关暂禁JTAG/串口下载，用程序RAM初始化代替；禁用状态明确记录，最终恢复后才宣布全SoC改造完成。
- [ ] AXI无通用超时取消。仿真watchdog可以判失败，硬件watchdog只能进入受控故障/协调复位，不能清busy后继续发请求混淆旧响应。

### 12.1 redirect、异常、维护与halt的统一优先级

不要把这些事件分别散落成多个`if`。控制器每拍先确定“当前EX老指令发生什么”，再处理年轻取指。建议优先级与语义如下：

| 优先级 | 事件 | 必须执行的动作 | 不能做的事 |
|---:|---|---|---|
| 1 | 硬复位 | 按系统复位合同同时复位CPU、互连和从设备 | 只清CPU而遗留旧AXI响应 |
| 2 | 当前EX同步异常 | 不退休该指令，原子写trap CSR，`arch_next_pc=mtvec` | 被halt或年轻redirect抹掉异常 |
| 3 | 当前EX的FENCE.I维护完成 | FENCE.I只退休一次，清年轻状态，从自身PC+4重取 | 执行已预取的旧PC+4指令 |
| 4 | 当前EX正常退休及其真实redirect | 完成一次写回/访存效果，更新`arch_next_pc` | 因halt提前撤销当前指令必要请求 |
| 5 | 指令边界接纳异步中断 | 在更老指令完成后写trap CSR并转`mtvec` | 截断不可取消的AXI事务 |
| 6 | `halt_pending` | 阻止下一条年轻指令进入，排空年轻取指；在上述架构事件完成后进入halt | 清除当前EX的`issued`/busy |
| 7 | IFU返回/顺序推进 | 仅在没有更高优先事件且请求仍有效时交付 | 把错误路径fault或旧指令送入流水线 |

halt与当前EX同步异常同拍时，先完成异常CSR更新并把恢复边界设为`mtvec`，随后在执行异常处理程序第一条之前进入halt；恢复后从trap入口开始。halt与当前EX真实分支redirect同拍时，保存真实目标为`arch_next_pc`后停机；恢复后从目标执行。这样debug看到的是明确架构边界，而不是猜测中的fetch PC。

**验收：** 对load和store分别在内部请求握手前、`op_fire`同拍、AXI等待地址/数据响应期间请求halt；检查当前EX操作仍只完成一次，年轻取指不执行，最终能进入halt，恢复后不重复/不漏执行。另测EX为空但旧取指在途的halt、下载程序并读回校验、加载代码后执行新指令、soft reset期间没有遗留响应污染新程序。

## 13. 异常中断与ISA对齐：任务 T07

“完整”必须先限定执行环境：本方案为单核RV32、M模式裸机，无S/U模式、无MMU；是否足够满足赛题“完整”措辞需要队伍向主办方确认。不能宣传支持没有实现的特权模式。

### 13.1 异常矩阵

| 事件 | mcause | mepc | mtval建议值 |
|---|---:|---|---|
| 指令地址未对齐 | 0 | 导致错误目标的跳转/分支指令PC | 错误目标地址 |
| 指令访问错误 | 1 | 实际故障取指PC | 取指地址 |
| 非法指令/非法CSR访问 | 2 | 当前指令PC | 指令编码 |
| EBREAK | 3 | 当前指令PC | 按所选特权规范固定 |
| load地址未对齐 | 4 | load PC | 有效地址 |
| load访问错误 | 5 | load PC | 有效地址 |
| store地址未对齐 | 6 | store PC | 有效地址 |
| store访问错误 | 7 | store PC | 有效地址 |
| M模式ECALL | 11 | 当前指令PC | 0 |
| 软件中断 | 0x80000003 | 下一条尚未执行指令PC | 0 |
| 定时器中断 | 0x80000007 | 下一条尚未执行指令PC | 0 |
| 外部中断/AI完成 | 0x8000000B | 下一条尚未执行指令PC | 0 |

当前`clint.v`实际代码写入cause=0x80000004，不能原样当标准M定时器中断；同时核验mie/mip、MIE/MPIE/MPP、mtvec、mret和CSR只读约束。代码模块名`clint`不代表已经实现标准平台定时器寄存器布局。

### 13.2 中断/CSR与软件共同修改的合同

**拆分任务：** T07a为基础正确性，含RV32I合法译码、同步异常、CSR访问合法性、FENCE及明确的停机/错误处理；T07b为高阶M模式中断与返回完善。T08a基础上板依赖T07a，不能因为T07b尚未全做完就无限延后上板；但未做完时不得宣称完整异常/中断。

- 中断需同时满足`mstatus.MIE`、相应`mie`位与`mip`挂起位。首版明确三个来源：软件pending寄存器、原timer事件锁存、外设聚合pending；分别映射MSIP(3)、MTIP(7)、MEIP(11)。首版同时有效时选外部 > 软件 > 定时器；每类来源/清除由地址表明确，不从旧8位`int_flag`随意取一个cause。
- 新增单拍MMIO窗口`IRQ_CTRL=0x60003000`：0x00 `SW_PENDING` bit0读写，0x04 `EXT_PENDING`读/W1C，0x08 `EXT_ENABLE`读写；仅已实现bit有效，新增外设分配需与C头文件同源。同步并锁存跨域/脉冲事件，W1C与新事件同拍以新事件优先。Timer仍用原寄存器清源；硬件pending由来源决定，不让软件随意写掉仍有效的电平。
- trap入口保存原MIE到MPIE、清MIE、设置MPP=M；MRET按MPIE恢复MIE并设置MPIE=1，M-only的MPP保持合法M值。`mtvec`首版只支持Direct并对不支持MODE执行合法化；`mepc`无C时保持4字节对齐，CSR保留位/read-only/WARL行为列成表。
- CSR写`mie/mstatus`及MRET后立即使用新状态检查pending。EX空且年轻取指被阻塞时，也在有限控制周期内检查；已发出的不可取消store需先收尾，不能靠清AXI FSM抢入中断。同步异常指令不退休，trap CSR更新必须原子可见。
- CSRRS/CSRRC的rs1=x0、立即数版本zimm=0不写CSR；不能用“寄存器读出来为0”代替“编码rs1为x0”。CSRRW rd=x0不读取旧CSR值但仍写CSR；只读CSR的非法写必须异常。
- 当前`init.c`只写mstatus，没有设置mie；标准化后必须显式设置所用mie位并先配置/清中断源，否则旧timer例程会不进中断。当前`trap_handler.c`把全部异步中断送timer函数；改按mcause分发，未注册源进入可诊断停机，不调用空弱符号。
- 当前`trap_entry.S`已区分异步返回，但对所有同步异常直接mepc+4。修订为仅经测试明确允许的ECALL等跳过；访问故障/非法指令记录并停止或交给明确恢复策略，不能静默跳过错误。
- 工具链冻结ISA profile：默认保留已有M算术，裸机CSR另明确Zicsr，FENCE.I若实现则明确Zifencei；I与IM性能分别编译和反汇编核验。不能仅把所有Makefile写成`rv32i`却仍假定CSR汇编和libgcc二进制自动匹配。Zicsr的存在不等同于具备完整特权架构。

**必测：** `mie=0`屏蔽、分别使能三类源、多个源同时挂起、MRET时pending仍在、CSR写使能同拍pending、EX空且取指延迟、中断与分支提交同拍、CSR只读零掩码、trap内再次发生异常的可诊断处理。每例核对cause/mepc/mstatus、源清除和返回后只执行一次。

### 操作

- [ ] 增加/核验`mtval`、`mip`以及已实现CSR；非法访问产生异常，不返回任意零值假装成功。
- [ ] 检查opcode之外的funct3/funct7合法性；禁用的扩展编码必须异常。
- [ ] 用valid=0表示气泡，合法NOP使用`addi x0,x0,0`即0x00000013。
- [ ] 同步异常优先于同条正常提交；先完成更老指令，再处理年轻取指/译码异常。
- [ ] 异步中断在明确架构指令边界接纳，包括EX空时；有load/store/div挂起时按13.2处理，不强行丢弃事务。
- [ ] 修改软件trap入口：不能一律mepc+=4。ECALL测试可以明确跳过；异步中断返回必须恢复原下一PC。
- [ ] 队伍在G0冻结是否支持Zifencei。若支持，FENCE.I必须按下述独立维护指令完整实现；若本阶段不支持，则该编码必须产生非法指令异常，工具链`-march`不得声明/生成Zifencei。禁止“识别了FENCE.I但只跳转或只清一部分缓冲”的半支持状态。FENCE仍等待此前访存完成。
- [ ] 支持Zifencei时，译码区分MISC-MEM的`funct3=000`(FENCE)和`funct3=001`(FENCE.I)，由EX锁存`fence_i_pending`直到维护确认，不能只当普通跳转或只清I-Cache。
- [ ] 选择支持Zifencei时，FENCE.I进入EX后立即阻止年轻`id_to_ex_fire`和新取指；等待此前store的B响应及数据引擎真正空闲；排空并丢弃已内部接单或已发到AXI的旧取指；清IFU返回槽、IF/ID年轻槽、预取/I-Cache及BTB；有在途I-Cache refill时等待其收尾且禁止旧行重新置valid。
- [ ] 选择支持Zifencei时，维护完成后以FENCE.I自身PC+4产生一次架构redirect并重新取指；FENCE.I本身在维护ack后只退休一次，不能被自己发出的flush清掉，也不能让原先已预取的PC+4旧指令执行。首版store等B才退休，因此通常不存在旧写缓冲；以后若增加写缓冲，FENCE.I必须同时等待其可见性。
- [ ] 选择支持Zifencei时，定向测试必须使用明确允许D侧写且允许I侧取指的测试RAM区域，不能在只读ROM或MMIO上伪造。先让旧版目标指令进入预取/IF槽，再由前序store把FENCE.I之后的目标指令从`addi x1,x0,1`改为`addi x1,x0,9`；执行FENCE.I后最终x1只能为9，并检查旧版指令退休次数为0、FENCE.I退休次数为1。
- [ ] 对CSR立即数指令、x31、JALR最低位清零、无C扩展的4字节目标对齐分别写测试。

**验收：** 每种事件都有触发程序、期望cause/epc/tval、返回后校验；中断与AXI响应同拍时仍只执行一次store。

## 14. 原生AXI首次上板与基础交付：任务 T08a/T08b

前置：T00-P平台核验、T01、T05-I集成及T07a通过；T06最小安全halt/reset通过即可，JTAG/在线下载允许关闭。T08a先验算术/RAM/UART/GPIO及基础CoreMark；T07b与软件配套通过后做T08b中断上板。无需先有DDR、Cache、摄像头。

T08a若尚无T07b，启动软件显式保持`mie=0`、`mstatus.MIE=0`且外部源关闭；同步异常仍走T07a的可诊断路径。不能照搬原`init.c`默认开全局中断后声称使用“关闭中断的基础配置”。

- [ ] 新建`fpga/pango/pango_top.v`，精确芯片型号以板卡标识/工程资料核对，不凭系列名选择。
- [ ] 只加入当前使用源码；原`rib.v`不在综合文件清单。
- [ ] 按板卡原理图约束时钟、复位、UART、GPIO；GPIO要真正作为顶层引脚引出。
- [ ] CPU/AXI初版同钟；PLL锁定后同步释放复位。不要直接照搬Xilinx PLL/BRAM原语。
- [ ] 确认片上RAM被映射到预期存储资源，初始化文件进入综合/配置流程。
- [ ] T08a用自检程序：算术 -> RAM读写 -> UART打印 -> GPIO翻转；T08b再验定时器/软件/外部中断。
- [ ] 建立真实`create_clock`周期、生成时钟和必要I/O约束；不能通过把所有路径设false path来“过时序”。
- [ ] 保存综合报告、布局布线后setup/hold报告和未约束路径检查。
- [ ] 使用PDS/板卡支持的片上逻辑分析工具抓PC、valid、retire、stall、AR/R/AW/W/B；按赛题ILA波形要求整理等价硬件观测证据。
- [ ] T13a在此执行第一份有效CoreMark：实际计时>=10秒、规定种子CRC正确，并抓取CoreMark算法区间的流水线波形，不用LED或任意程序波形替代。记录分析工具、插桩资源以及插桩前后时序变化。

**通过标准：** 原生AXI4 CPU在紫光板上可重复运行，B1/B2/B3及首次有效CoreMark有证据。基础应用先做串口配置的GPIO采集/控制演示，报告实际控制/采样延迟；不把它冒充AI加速。尚不能宣称高阶项或全赛题已完成。

## 15. 两路I/D Cache及突发：任务 T09

若申报完成赛题H1，两路指令Cache和两路数据Cache都要有；仅添加AXI接口或仅实现I-Cache不能声称满足H1。H1本身不是基础B1-B3的先决条件。

### 15.1 参数选择

每个Cache：2路 × 32组 × 32字节/行 = 2048字节。I+D数据部分共4KiB，另有tag/valid/替换状态资源。

32位地址拆分：

```text
tag        = address[31:10]   共22位
set_index  = address[9:5]     共5位，32组
byte_offset= address[4:0]     共5位，32字节/行
word_index = address[4:2]     共3位，每行8个字
```

每组2个tag和valid；1位LRU足够表示两路中优先替换谁。先用无效路，再替换LRU路。

### 15.2 I-Cache

- [ ] CPU给PC后同步查两路tag/data，命中返回对应字与原PC。
- [ ] 缺失保存地址/组号/替换路，行首`address & 32'hFFFFFFE0`。
- [ ] 发8拍INCR读，ARLEN=7、ARSIZE=2；每次R握手写一个word。
- [ ] 全行响应正确才设置valid并交付请求；中途错误清该行valid并传播取指故障。
- [ ] refill中redirect：继续接完总线，可以保留成功cache行，但不给错路指令提交。
- [ ] FENCE.I/代码下载后失效；在途refill也不得把刚失效的旧代码重新标有效。
- [ ] 代码更新同时失效相关BTB项及预取；debug写可缓存数据时，在安全halt下失效D侧对应行或全Cache。

### 15.3 D-Cache：首版选写直达、不写分配

这是降低复杂度的明确方案：读缺失8拍补行；写命中更新已有行，写缺失不补行；所有store都发单拍AXI并等B。无dirty位，无写回缓冲。

- [ ] 只缓存正常内存，MMIO与共享DMA缓冲绕过。
- [ ] store先保留待写数据；B成功后才更新命中cache行，失败则失效该行并异常。
- [ ] MMIO load/store不做cache填充，不能把UART读8次当一次补行。
- [ ] Cache失效操作只在无未完成数据事务时执行。
- [ ] CPU与DMA的第一版共享缓冲采用不可缓存区，避免读到旧数据。
- [ ] 不可缓存范围在T11确定DDR容量后写成具体base/limit，与链接脚本、内存分配器及DMA范围检查同源；按Cache行对齐，禁止同一物理缓冲另有可缓存别名。运行中不随意切换属性。

写直达并不意味着不满足“两路D-Cache”；但单拍store没有写回突发效率，优化报告应如实说明。需要更高性能时再设计写回Cache，不能混用两套一致性规则。

### 测试

- [ ] 读A、读B、再读A：A和B落同组不同tag，都应命中保留。
- [ ] 再读第三个同组地址C：验证LRU替换正确。
- [ ] 32字节行边界前后、4KiB边界附近访问。
- [ ] refill每拍随机延迟、R错误、redirect/失效与最后拍重合。
- [ ] store失败不在Cache内留下“成功值”。
- [ ] Cache开/关执行同程序得到相同结果，记录miss次数与周期。

**通过标准：** 两路冲突测试、随机读写scoreboard、CPU指令回归全部通过；板上能抓到ARLEN=7及8次R握手。

## 16. 动态预测：任务 T10

新建`rtl/core/branch_predictor.v`；选32项直接映射BTB，每项保存valid、完整tag、target、类型、2位饱和计数器。

- [ ] BTB索引PC[6:2]，tag=PC[31:7]；禁止只比索引不比tag。
- [ ] 条件分支计数器00/01预测不跳，10/11预测跳；取决于实际分支结果加减并饱和。
- [ ] BTB命中且预测跳，取target；否则PC+4。已学习无条件跳转使用其target。
- [ ] 保存每条指令的predicted_next_pc到EX，比较真实next_pc决定是否清年轻阶段。
- [ ] 在指令真实完成的边界更新一次，不训练被flush的指令。
- [ ] 错路在途AXI取指按T03排空，不能撤销握手。
- [ ] 测全跳、全不跳、交替、循环退出、同索引不同tag、目标变化JALR。

**通过标准：** 预测开/关架构结果完全相同；报告预测命中率、错预测代价、CoreMark变化，不能仅宣称“加入BTB所以更快”。

## 17. DDR接入前置核验：任务 T11（硬关卡）

### 17.1 已查到的真实限制

本地板卡示例：

`E:\daiduwangpan\盘古100Pro+开发板（MES2L676-100HP）配套资料\7_FMC扩展子卡及Demo\2_Demo\HDMI_DDR3_OV5640_100H\source\rtl\DDR3_50H\DDR3_50H.v`

该生成文件标注IP Generator 2022.1，实际接口有4位AxLEN和256位数据（默认MEM_DQ_WIDTH=32），但没有标准AXI4的WVALID输入、RREADY输入和完整BVALID/BREADY/BRESP通道；还有`axi_wusero_last`等专用信号。

**因此不能把这个示例直接当标准AXI4 Slave。名称中有axi不等于完整标准接口。**

### 17.2 必须完成的核验表

- [ ] 在已安装PDS中找到该型号支持的DDR IP文档和生成界面。
- [ ] 向厂商核对是否有该器件可用、带完整AXI4通道的控制器版本。
- [ ] 导出真实端口表：地址单位是byte还是word、数据宽度、最大burst、响应与回压规则、ID、时钟、校准完成、字节mask极性。
- [ ] 确认支持窄访问/非全字节写，或必须在存储子系统内部处理宽度。
- [ ] 明确写完成的定义；不能用AW握手、WREADY或`wusero_last`猜测标准B响应语义。
- [ ] 保存厂商答复或对应手册页到`docs/evidence/ddr-interface/`。

### 17.3 三种结果

1. **存在合适的原生AXI4 DDR控制器：** 使用它，处理总线宽度/CDC，继续下一项。
2. **只有非标准用户口，但允许在DDR子系统内设计原生AXI4前端：** 需要队伍明确同意该边界。它不是RIB桥，但确实包含DDR接口适配，不能偷偷叫“完全无协议适配”。
3. **要求整个系统连DDR边界也绝不适配，且无原生IP：** DDR路线阻塞。继续用AXI4 BRAM完成CPU/Cache/基础比赛证据，不能承诺按该限制完成DDR+YOLO。

当前设计明确禁止RIB桥；本计划不擅自批准第2种结果。若选择第2种，必须另写基于实际DDR手册的前端详细计划，不能凭当前信号名生成RTL。

“禁止RIB桥”与“禁止一切DDR适配”是两项不同选择，不要合并。以降低返工为目标，建议队长允许经验证的DDR前端/位宽/CDC适配，同时保留CPU与系统主干原生AXI4。此建议需队伍确认，不把建议写成已获批准，也不把自定义外设直接AXI化推广成相机必须讲AXI。

### 17.4 通过关卡后的接入步骤

- [ ] 先独立跑厂商DDR校准及数据读写例程，确认板卡、DDR时钟、复位。
- [ ] 用AXI测试主机写/读地址自增、全0/全1、walking-bit、固定seed随机图样，覆盖实际容量边界。
- [ ] 解决32位CPU与实际DDR端口宽度，不截断高位。优先使用厂商已验证同协议宽度转换/互连组件；它不是RIB协议桥，但需如实记录。
- [ ] 不同域通过经验证的AXI CDC组件或事务FIFO，不能对宽总线每bit打两拍。
- [ ] `ddr_init_done`之前不接受访问，或由系统启动流程明确等待；不把未校准数据返给CPU。
- [ ] CPU先测试不可缓存DDR读写，再打开Cache；写程序到DDR后刷新I侧再跳转执行。

**通过标准：** 数据校验、字节mask、突发、回压、CDC、校准等待均通过，并有本板实测日志。

## 18. OV5640与YOLO软硬件协同：任务 T12

这部分分小项目完成，不在CPU总线还没稳定时同时调试。

### 18.1 摄像头

- [ ] 参考现有`HDMI_DDR3_OV5640_100H`采集例程，只复用已读懂且验证过的相机配置/采集部分，不照搬其非标准DDR事务。
- [ ] 先采集彩条/固定测试图，验证像素格式、宽高、行有效、帧有效、字节顺序。
- [ ] OV5640的DVP不是AXI；采集模块通过异步FIFO进入系统域，再由原生AXI4 frame DMA写内存。
- [ ] FIFO满时明确丢弃整帧并计数，不能静默丢几个像素后仍标帧有效。
- [ ] 双缓冲状态FREE -> FILLING -> READY -> PROCESSING -> FREE，CPU不得把DMA正在写的帧给AI读。
- [ ] 帧READY只能在最后一笔内存写响应成功后发布。
- [ ] 先串口输出校验和/抽样像素，再增加HDMI显示；显示不是完成B1-B3的前置条件。

### 18.2 YOLO模型冻结关卡

不能现在凭模型名字保证适合。第一轮实验由CPU/软件与AI负责人完成：

- [ ] 固定一个YOLO变体、输入分辨率、类别表、算子清单和权重校验值。
- [ ] 使用有目标框标注的垃圾数据；只有整图类别标签的数据不能直接当目标检测标注。
- [ ] 划分训练/验证/独立测试集，避免同场景近重复图片泄漏。
- [ ] 先电脑运行浮点结果，再INT8量化模拟，记录精度损失。
- [ ] 导出每层输入/输出、scale、zero point、饱和/舍入规则，作为RTL黄金数据。
- [ ] 计算权重总字节、峰值中间张量、帧缓冲和代码所需空间，以及每帧MAC数量。
- [ ] 根据实际DDR/BRAM/DSP资源判断是否放得下；资源不够则缩小输入/模型或分层复用，不强行宣称实时。
- [ ] “垃圾检测”只是应用候选，不是选题一硬性类别；队伍明确场景后再冻结类别/数据集。另记录CPU软件回退算子的时间预算、相机写流量、权重/特征图流量及DDR实测持续带宽，不仅检查容量。
- [ ] 32位系统总线每秒有效数据上限按实际数据握手拍数计算，不能用DDR芯片标称带宽代替。单事务互连下CPU控制寄存器写、DMA读和DMA写也互相竞争；先做离线单帧，再决定是否增加并发。

模型版本、算子及DDR接口未冻结前，本节是工作分解与验收要求，不是可直接复制的完整YOLO RTL实现。最终模型不确定时编造每层硬件代码会误导实施。

### 18.3 加速器最小实现

首个计算核从INT8乘加开始：有符号INT8输入/权重、INT32累加；根据模型量化规则再缩放、舍入、饱和。不要先加自定义CPU指令。

建议复用少量MAC做分块卷积，由CPU配置每层参数；普通运算仍由CPU执行。原生AXI4数据主接口负责读权重/特征图和写结果。

AI控制寄存器方案：

| 偏移 | 含义 | 规则 |
|---|---|---|
| 0x00 CTRL | bit0启动 | 写1产生一次启动；BUSY时拒绝重复启动 |
| 0x04 STATUS | bit0 busy，bit1 done，bit2 error | done/error写1清除，不能读即清除 |
| 0x08 INPUT_ADDR | 输入张量地址 | 启动时锁存 |
| 0x0C WEIGHT_ADDR | 权重地址 | 启动时锁存 |
| 0x10 OUTPUT_ADDR | 输出地址 | 启动时锁存 |
| 0x14 DESC_ADDR | 层参数描述符地址 | 启动时锁存，CPU已完成描述符写入 |
| 0x18 IRQ_ENABLE | 完成中断使能 | 可读写 |
| 0x1C ERROR_CODE | 总线/参数/计算错误 | 只读 |

描述符字段需随冻结模型确定：宽高、输入输出通道、kernel、stride、padding、量化参数；对应C结构与RTL偏移生成同一份定义，不能手工维护两套不一致版本。

CPU流程：

```text
等完整帧 -> 配置张量/层参数 -> FENCE -> 启动AI
-> 等完成/中断 -> 检查错误 -> 读结果 -> 后处理/NMS -> 输出类别和框
```

DMA必须支持1至16拍INCR，按4KiB切块；不足整字的尾部用WSTRB，读端多读出的无效byte不参与计算，且不得跨分配边界/设备窗口。共享帧、输入/输出张量和描述符首版全部不可缓存，范围按T11冻结；非共享权重可只读缓存，但更新时遵守维护协议。B未完成之前不发AI DONE。启动MMIO需在锁存参数或报告BUSY错误后及时返回B，不能等整个计算完成才返回，否则全局单事务互连会阻塞加速器自己的DMA。

CPU启动前使用编译器内存屏障及明确的`fence iorw,iorw`，观察完成后再次执行相应顺序屏障再读结果；FENCE不是Cache失效指令。CPU/AI/相机/可选显示不能同时写同一缓冲，显示若仍在读该帧，不得将其提前标FREE。发生帧丢弃或AXI错误时，排空在途写并将该帧标无效，不发布半帧READY。

### 验收顺序

- [ ] 一个MAC的正负数、极值、累加边界。
- [ ] 一个小矩阵/卷积与软件逐元素一致。
- [ ] 一层量化卷积与电脑黄金输出一致。
- [ ] 单张预置图片完整YOLO路径，包括未加速算子的软件回退。
- [ ] 相机帧输入；记录精度、单帧总延迟和加速部分延迟。
- [ ] CPU-only基线与CPU+加速器使用相同模型、输入、精度设置；报告端到端加速比，不用单层MAC吞吐代替它。

## 19. CoreMark、性能和交付：任务 T13

拆为T13a基础跑分（紧接T08a）、T13b每次Cache/预测器改造后的同条件复测、T13c最终性能/应用报告。不再等T10完成才第一次运行CoreMark。

- [ ] 使用CoreMark v1.0；核心算法不因“提分”修改，仅调整允许的移植层/迭代次数。
- [ ] 保存所用CoreMark源码版本与哈希；按EEMBC Run Rules核验性能种子`0,0,0x66`及验证种子`0x3415,0x3415,0x66`、总数据区2000字节与全部CRC。只跑一次PERFORMANCE_RUN并看到一个CRC不足以完成规则核验；调试短跑不列为有效成绩。
- [ ] 使用指定工具链，记录`-march/-mabi/-O`、链接脚本、代码执行在BRAM还是DDR、Cache与预测器状态。
- [ ] RV32I基线和启用M扩展配置分开报告；不要把M扩展带来的收益混称RV32I流水线收益。
- [ ] 用板上实际运行频率填写`CPU_FREQ_HZ`；计时计数器在CPU暂停时仍正常增长。
- [ ] 测试有效运行时长>=10秒且校验CRC通过；总循环周期和计数器溢出正确处理。
- [ ] 32位cycle在高频长运行时可能回绕；采用64位计时或明确验证差分上限。读64位counter采用高-低-高一致性读取。
- [ ] 当前`lib/utils.c:get_cycle_value()`是低后高各读一次，跨回绕会读出不一致值；在实施副本改为高-低-高重试，并用计数器接近0xFFFFFFFF的定向测试验收。`include/utils.h`当前写死50MHz，必须与本板运行配置同源。
- [ ] `core_portme.c:time_in_secs()`当前把`ticks/256`截到32位，不能仅因为硬件cycle是64位就认定任意长测试正确；记录可测上界或改移植层为不会溢出的换算，并用合成tick值验证。
- [ ] 同配置重复测量，保留完整UART日志，不只截最后一个分数。

统一公式，Frequency以MHz计：

```text
CoreMark       = iterations / seconds
CoreMark/MHz   = iterations / seconds / frequency_MHz
CoreMark/LUTs  = iterations / seconds / LUT_count
```

报告最高频率以布局布线后满足约束的结果为准，不把PLL设置值或仿真时钟当Fmax。

资源统计分别报告CPU核、CPU+总线/Cache/BRAM接口、完整应用系统，并明确片上分析仪开关。主比较使用同一资源边界、同一频率及编译配置；另列各配置实际通过时序的最高频点。AI/DMA/相机是否运行必须记录，不能用空闲C3与满负载C4直接归因于CPU优化。

建议比较配置：

| 配置 | AXI | Cache | 预测 | 用途 |
|---|---|---|---|---|
| C0 | 原RIB基线 | 无 | 无 | 原代码参考，不混入最终原生AXI源码清单 |
| C1 | 原生AXI4 | 无 | 无 | 正确性及性能代价 |
| C2 | 原生AXI4 | 两路I/D | 无 | Cache收益 |
| C3 | 原生AXI4 | 两路I/D | 动态 | 预测收益 |
| C4 | C3系统 | 同C3 | 同C3 | 加AI后的资源与应用结果 |

性能计数器：cycle、instret、load/store等待周期、取指等待周期、I/D hit/miss、预测次数/错误次数、AXI有效数据拍数。计数条件必须有定义，不能把stall气泡当退休指令。

交付目录建议：

```text
docs/
  requirements.md           赛题编号与证据映射
  architecture.md           CPU/AXI/Cache/AI结构
  address_map.md            寄存器地图和驱动约定
  axi_profile.md            支持的AXI能力与限制
  test_report.md            用例/seed/工具版本/结果
  performance_report.md     CoreMark、时序、资源、AI对比
  evidence/                 UART日志、波形、板上抓取、工具报告
rtl/ sim/ tb/ tests/ fpga/   可重建源码与工程
```

## 20. 每阶段测试清单

| ID | 刺激 | 必须看到的结果 |
|---|---|---|
| AX01 | ARREADY低10拍 | ARVALID和全部AR字段不变 |
| AX02 | AW先、W先、同拍 | 一次写入、一次B |
| AX03 | RREADY/BREADY低7拍 | 响应负载保持，无丢失 |
| AX04 | 8/16拍突发随机间隔 | 只在握手计数，末拍准确 |
| AX05 | 请求接近4KiB边界 | DMA拆分，不产生跨界burst |
| AX06 | 无效地址/越界 | DECERR/SLVERR，不死锁 |
| AX07 | 从设备等WVALID才给AWREADY | AW/W独立前进，不相互等待 |
| AX08 | burst中途RRESP错误 | 收完剩余拍后释放owner，不串到下一事务 |
| CP01 | load返回晚20拍 | 后续相关指令不使用旧值 |
| CP02 | store响应晚30拍 | 内存/外设副作用一次 |
| CP03 | 分支时取指未完成 | 旧响应排空，错路不退休 |
| CP04 | div等待同时中断 | 不重复启动、不丢rd、合法边界trap |
| CP05 | 非法指令/未对齐/总线错误 | cause/epc/tval正确 |
| CP06 | IF占总线且EX等待LSU | IF返回可进入预留槽，随后LSU得到服务 |
| CP07 | 错路/正确路径PC指向MMIO | 均无外设AR副作用；只正确路径进入trap |
| CP08 | MRET/CSR更新使能且中断pending | 按新CSR状态重判，返回PC与使能状态正确 |
| CA01 | 同组A/B/C反复访问 | 两路及LRU可解释 |
| CA02 | refill中错误/flush | 无半行有效、无错路异常 |
| CA03 | DMA写共享区CPU读取 | 不读取陈旧Cache副本 |
| DB01 | busy时halt/reset | 已接受事务不遗失 |
| DB02 | halt后debug写已缓存数据/代码 | D/I/BTB维护后重启可见新内容 |
| HW01 | PDS综合布局布线 | 资源合理、时序与约束核验通过 |
| PF01 | CoreMark>=10秒 | CRC正确，频率/时间/迭代可复核 |
| PF02 | cycle低位回绕时读取时间 | 高-低-高重试，时间差无伪跳变 |
| AI01 | 同一图片软硬件推理 | 数值/精度达预先冻结标准 |
| AI02 | 启动寄存器写与AI请求DMA | 启动B及时返回，DMA不被自己阻塞 |

每个用例至少一次确定性测试，再用固定seed 1至20做随机回压。回压随机测试需要最终公平性约束，例如每通道最多连续阻塞31拍，否则测试可能制造永远不响应而不是找设计bug。

## 21. 新手每天怎样按这份计划做

不要一次打开二十个文件。每天只做一张任务卡：

```text
任务编号：T03-AR稳定性
今天只改：ifu_axi.v 和 tb_ifu_axi.sv
先看懂：ARVALID表示地址已准备好；ARREADY表示对方接收
先写测试：READY低10拍，检查VALID与地址不变
先看失败：旧逻辑不能通过
再修改：保存请求地址，握手后才清VALID
再运行：同一用例通过，随后跑已有回归
记录：改了什么、哪张波形、测试seed、是否通过
提交：只提交相关文件
```

遇到错误按层查：

1. 编译不过：先看端口/位宽/文件清单，不上板。
2. 总线卡住：查五个通道哪个握手没完成、owner是谁。
3. 指令错：查请求PC、返回PC、valid、retire，再查译码。
4. 仿真过但上板错：查复位、BRAM读延迟、时序、CDC、管脚。
5. AI结果错：用单层黄金输出定位，不先跑整套相机系统。

## 22. 依赖顺序、分工和停止条件

```text
G0来源/范围确认 + T00基线 + T00-P早期PDS核验
T01独立AXI平台可并行 -> T02槽位/提交单元测试
-> T03取指 / T04访存 / T05互连与存储分别测试
-> T05-I完整CPU集成 -> T06最小halt/reset + T07a ISA/同步异常
-> T08a基础上板 -> T13a有效CoreMark与基础应用
-> T07b中断及软件 -> T08b中断上板
-> T09两路Cache -> T13b复测 -> T10预测器 -> T13b复测

T06完整JTAG/在线下载可后置；若不交付则明确裁剪，不冒充全SoC改造

T11 DDR接口核验应尽早并行做；DDR实际接入在总线稳定后进行
T12模型离线冻结可并行；摄像头/AI系统集成依赖T11与AXI回归
-> T13c最终报告/应用测量
```

建议分工（不是强制）：

- 你：PC/握手学习、IFU测试、AXI RAM/GPIO、PDS基础上板，之后做摄像头控制。
- 队友：流水线提交/LSU/异常边界/互连审查，随后Cache与性能。
- 一起：每周复盘波形、模型资源预算、CoreMark日志；互相能解释对方的端口和状态机。

不承诺几天必成。每个任务以测试通过为结束标准，DDR IP不兼容、许可证不可用或模型放不下都可能改变日程。

停止进入下一阶段的情况：

- 原始CPU基线没有可复现结果。
- AXI随机等待会重复写外设。
- 已接受事务被flush/halt直接清状态、不排空协议，或其结果仍被错误提交；正确做法是事务继续收尾，按所有者决定交付或丢弃。
- DDR接口尚未核验，却开始按“标准AXI4”硬连。
- 基础RV32I/中断没通过，却开始凭CoreMark截图宣布符合比赛。
- 只有单层卷积成功，却宣布YOLO移植成功。

**裁剪规则：** 板卡/许可证/基线不通，先停止CPU大改；T08a/T13a未闭环，不把相机+YOLO设为当前集成任务；DDR或模型关卡不通过，保留已验收CPU成果并如实标AI未完成，不用CNN学习样例顶替。详细排期由队长在G0填写，不虚构完成天数。

## 23. 开工前确认单

- [ ] 同意CPU/外设原生AXI4，不保留RIB，不建RIB桥。
- [ ] 同意32位数据、4位ID、首版全局单事务、后续8/16拍INCR。
- [ ] 同意先完成基础赛题证据，再加两路I/D Cache、预测器和AI。
- [ ] 确认DDR边界“不使用桥”是否也禁止厂商IP用户口适配；在T11事实核验前不承诺。
- [ ] 确认本次只交付计划，后续从T00逐步修改，不一次性覆盖原工程。
- [ ] 确认G0开源来源与队友贡献核对、T00-P平台前置，以及T13a在Cache/预测器之前验收。
- [ ] 确认3.5 CPU/Cache合同、3.6前进性约束、13.2中断软硬件合同；它们是本轮提出的修订，尚不等于团队已签核。

## 24. 资料与证据边界

1. 赛题：本地PDF第10-11页，已提取核对；本计划是与这份文件对齐，不声称在线核验了之后的新通知。
2. 原代码：上述源码目录，已读取接口、控制、访存、存储、调试、编译脚本；未实际运行。
3. DDR：上述`DDR3_50H.v`真实端口已读取；PDS其他版本/IP可用性未核验。
4. 协议实施须以Arm AMBA AXI/ACE Protocol Specification（IHI 0022中AXI4章节）作规范依据；接口profile需要在编码前逐项签核。
5. ISA与异常实施须以RISC-V Unprivileged及Privileged Architecture的冻结版本为依据，并在报告记录版本。
6. 本轮内置网页检索未返回可用结果；随后直接读取了RISC-V官方仓库`src/priv/machine.adoc`的中断检查条款及EEMBC/CoreMark官方README的Run Rules，仅用于技术交叉核对，不替代赛题。Arm在线规范请求未成功，AXI细节仍需在实施前用冻结的IHI 0022版本复核；没有声称已核验最新赛事通知。
7. 本计划给出决策、文件边界、状态机、关键代码模板、测试刺激与验收标准；它不是数千行完整可编译补丁。CPU改造任务可逐步展开；DDR与具体YOLO层级实现必须先通过各自资料/模型冻结关卡。

**当前停在计划评审：队伍先确认本轮修订和G0范围。获准进入实施后，首先执行T00/T00-P，建立不破坏原工程的基线与平台证据；本轮不执行任何RTL改造。下列新增章节将前面的任务展开为具体方法。**

## 25. 小白阅读法、术语与修改纪律

### 25.1 先分清四类东西

| 名称 | 人话 | 本项目例子 |
|---|---|---|
| ISA | 软件说什么话、每句是什么意思 | `addi x1,x0,5`令x1变成5；与使用何种总线无关 |
| 流水线 | 多条指令分阶段工作 | 本项目IF取指、ID译码、EX执行；EX也负责等待内存/除法，不强改五级 |
| AXI | 不同模块如何发请求、等待及收结果 | 发读地址AR，然后收到读数据R；两者不要求同一拍 |
| Cache | 保存近期用过的内存副本 | 命中不用外部读，缺失才用AXI补32字节一行 |
| retire | 一条指令已经成功完成、正式记账 | 成功load写寄存器一次；错误load不退休而进入异常 |
| trap | CPU转去处理错误或中断 | 保存故障PC/原因，跳到软件处理入口 |
| BFM/scoreboard | 测试台里的模拟设备/对账本 | BFM故意晚20拍返回；scoreboard检查没有多写字节 |

学习次序固定：**先解释语法 -> 再看原代码 -> 再看改后人话 -> 最后用一条具体指令验证**。遇到还不懂的下一模块先暂停，不靠一次改完全部文件碰运气。

### 25.2 最小Verilog语法

```verilog
wire fire = valid && ready; // 两边同一上升沿为1才接受一次
always @(posedge clk) begin
    if (!rst_n) valid_q <= 1'b0;
    else if (flush) valid_q <= 1'b0;
    else if (load_en) begin
        valid_q <= in_valid;
        if (in_valid) data_q <= in_data;
    end
end
```

这是语法片段，不是独立文件。`wire`是连接/组合结果，`reg`是过程赋值变量；`[31:0]`是32位；`<=`在时钟沿描述寄存器更新，不能按软件逐行立即生效理解。`always @(*)`组合逻辑先给所有输出默认值，避免意外锁存器。`4'b0010`只有第二个字节通道有效；`32'h10000000`是32位十六进制地址。

原工程`rst`实际上低有效，`defines.v`明确`RstEnable=0`。新模块统一叫`rst_n`，连接`.rst_n(rst)`，绝不能因为旧名字没n就再取反。先保持同一个时钟；异步传感器/DDR另做CDC，不把多位总线每bit打两拍当协议转换。

### 25.3 文件角色与禁止事项

- 原始只读参考：`E:/donwload/tinyriscv-master/tinyriscv-master`。
- 经批准后才创建实施副本：`E:/file/pango/tinyriscv_axi4`。本轮没有创建它。
- 本文所有`rtl/...`、`tests/...`、`sim/...`新建/修改路径均以实施副本为根；不是去另一个YSYX目录修改。
- **完整模板**可保存成所标文件再单元测试；**集成片段**只替换标出的连接或分支，不能整段覆盖已有模块；**状态表**必须落实为寄存器/FSM并按指定用例验证，不是“已经写好的RTL”。修改原文件保留其已有版权和来源说明，新文件记录真实贡献，不把本计划模板标为既有上游代码。
- 不全局替换gen_dff，不一次删掉旧代码，保留独立基线编译清单；新SoC文件清单排除RIB，旧基线清单仍保留RIB。
- 每张卡完成时记录：改过的文件、编译日志、PASS/FAIL、seed、关键波形和尚未解决的问题。未通过不打勾，不把旧VCD当本次结果。

## 26. 建议新增功能与实际执行顺序

### 26.1 我的建议：先做看得见原因的CPU，再追求更多功能

| 建议 | 为什么值得做 | 实施位置 | 取舍 |
|---|---|---|---|
| 退休事件轨迹 | 比“最后寄存器错了”更快定位第一条错误指令 | 28.3；仿真记录PC/rd/值/异常 | 必做验证设施，不宣称ISA认证 |
| 性能快照寄存器 | 解释CoreMark为何快/慢，直接支撑分析报告 | 32.1；先cycle/instret，再等待与命中计数 | 推荐，先不加复杂可编程事件 |
| 小型GPIO边沿采集/控制应用 | 不依赖DDR和AI也能演示CPU真实控制外设 | 32.2；先轮询再中断 | 推荐基础应用，不代替高阶AI |
| 配置对照开关 | 同一软件比较Cache/预测开关的正确性和性能 | 31与32；综合时固定开关 | 推荐，先不实现危险的运行时切换 |
| 调试错误状态 | 访问错地址时给出PC/地址/cause，不直接死机无信息 | 30；CSR及串口错误日志 | 基础路径必须可诊断 |
| 更宽DMA/更多并发 | 带宽测量确认瓶颈后才投入 | 33 | 后置，先验证单事务路径 |
| 自定义指令/操作系统/五级改造 | 与当前问题关系较弱、会扩大验证范围 | 本轮不安排 | 不建议为“看起来高级”而加 |

这些建议来自项目目标与现有结构，不是额外赛事硬性要求；队长可以裁剪可选应用，但不能裁掉正确性验证。

### 26.2 任务卡执行图

```text
N00 基线工具与副本 -> N01 原CPU新编译回归
N02 pipe_slot独立模块 -> N03 退休门控/译码/除法adapter
N04 单拍AXI读引擎 / N05 单拍AXI写引擎 / N06 RAM+GPIO从设备
N07 IFU与LSU / N08 互连 -> N09 全CPU集成与错误路径
N10 ISA/同步异常+基础软件 -> N11 基础上板+CoreMark
N12 中断软硬件 -> N13 I/D Cache -> N14 动态预测
N15 性能快照及GPIO应用
N16 DDR和模型事实冻结 -> N17 DMA/完整单帧AI
```

映射：N00-01=T00，N02-03=T02，N04-08=T01/T03/T04/T05，N09=T05-I，N10=T07a，N11=T08a/T13a，N12=T07b/T08b，N13=T09，N14=T10，N15=T13及推荐应用，N16-17=T11/T12。T06安全halt/reset穿插于N09-11，完整调试下载可以后置。每张卡先看相应原章节约束，下面是操作说明，不是第二套架构。

### 26.3 每张卡的完成单

1. 在Git副本建独立提交点，写出本卡唯一目标及旧行为。
2. 先写会失败的最小测试；模块未创建导致编译失败是第一步，但之后还要证明测试能发现故意植入的行为错误。
3. 只改本卡列出的文件；若需要新接口，同一次提交修改模块、实例和测试台。
4. 跑单元定向测试，再固定seed 1-20；CPU集成阶段再跑已有47个`.bin`及新增异常/时序用例。
5. 保存证据；检查新增warning中的多驱动、截断、锁存器、未连接端口，不用“warning很多但能跑”跳过。

## 27. N00/N01：第一份可复现基线怎么做

### 27.1 准备副本，不覆盖任何已有目录

以下是未来执行命令，不是本轮已经执行的操作：

```powershell
$src = 'E:\donwload\tinyriscv-master\tinyriscv-master'
$dst = 'E:\file\pango\tinyriscv_axi4'
if (!(Test-Path -LiteralPath $src)) { throw 'Source missing' }
if (Test-Path -LiteralPath $dst) { throw 'Destination exists; inspect it first' }
Copy-Item -LiteralPath $src -Destination $dst -Recurse
Set-Location -LiteralPath $dst
git init
git add .
git commit -m "chore: preserve original tinyriscv baseline"
if ($LASTEXITCODE -ne 0) { throw 'Baseline commit failed' }
Get-Command vsim,vlog,vlib,python
```

首次Git若提示身份未配置，按队伍真实身份配置后重试，不随便写其他人的姓名邮箱。已存在团队仓库就沿用它，不再次初始化。已复查本机`vlog -version`输出ModelSim SE-64 10.6e；这只证明编译器可启动，不代表仿真许可证、CPU测试或PDS已通过。当前PATH仍未发现iverilog/vvp，默认先走ModelSim，不假装两者已安装。

### 27.2 原脚本的风险，先修测试入口再改CPU

源码`sim/test_all_isa.py`只查TEST_PASS，零个bin也可能报告All PASS；`compile_rtl.py`未检查编译返回码，`sim_new_nowave.py`超时不杀仿真。**不删除这些原脚本**，新增独立runner，用全新work库，避免误跑旧`out.vvp`。

新建`sim/baseline_sources.f`，完整内容如下（相对实施副本根目录）：

```text
tb/tinyriscv_soc_tb.v
rtl/core/clint.v
rtl/core/csr_reg.v
rtl/core/ctrl.v
rtl/core/div.v
rtl/core/ex.v
rtl/core/id.v
rtl/core/id_ex.v
rtl/core/if_id.v
rtl/core/pc_reg.v
rtl/core/regs.v
rtl/core/rib.v
rtl/core/tinyriscv.v
rtl/perips/ram.v
rtl/perips/rom.v
rtl/perips/timer.v
rtl/perips/uart.v
rtl/perips/gpio.v
rtl/perips/spi.v
rtl/debug/jtag_dm.v
rtl/debug/jtag_driver.v
rtl/debug/jtag_top.v
rtl/debug/uart_debug.v
rtl/soc/tinyriscv_soc_top.v
rtl/utils/full_handshake_rx.v
rtl/utils/full_handshake_tx.v
rtl/utils/gen_buf.v
rtl/utils/gen_dff.v
```

`defines.v`通过include引入，不作为独立module；这是普通ISA testbench清单，不是另一个compliance_test testbench。两者同名，不能同时编译。

### 27.3 完整模板：新的ModelSim基线runner

保存为实施副本`sim/run_baseline.py`，只用Python标准库。它不改RTL，在副本的`.sim_runs`建唯一运行目录，保存每次编译/仿真输出；发现任何失败立即非零退出。

```python
from pathlib import Path
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile

def run(cmd, cwd, log, timeout):
    with log.open('w', encoding='utf-8') as out:
        p = subprocess.Popen(cmd, cwd=cwd, stdout=out,
                             stderr=subprocess.STDOUT)
        try:
            rc = p.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            if os.name == 'nt':
                subprocess.run(['taskkill', '/PID', str(p.pid), '/T', '/F'],
                               stdout=out, stderr=subprocess.STDOUT)
            else:
                p.kill()
            p.wait()
            raise RuntimeError('TIMEOUT: ' + str(log))
    text = log.read_text(encoding='utf-8', errors='replace')
    if rc != 0 or re.search(r'\*\*\s*(Error|Fatal)', text, re.I):
        raise RuntimeError('COMMAND_FAIL: ' + str(log))
    return text

def main():
    a = argparse.ArgumentParser()
    a.add_argument('--case', default='rv32ui-p-add')
    a.add_argument('--all', action='store_true')
    args = a.parse_args()
    root = Path(__file__).resolve().parents[1]
    tools = {x: shutil.which(x) for x in ('vlib', 'vlog', 'vsim')}
    if not all(tools.values()):
        raise RuntimeError('ModelSim tools not in PATH: ' + str(tools))
    manifest = root / 'sim/baseline_sources.f'
    sources = [root / x.strip() for x in manifest.read_text().splitlines()
               if x.strip() and not x.lstrip().startswith('#')]
    if not sources or not all(x.is_file() for x in sources):
        raise RuntimeError('Source manifest missing or invalid')
    bindir = root / 'tests/isa/generated'
    bins = sorted(bindir.glob('*.bin')) if args.all else [bindir / (args.case + '.bin')]
    if not bins or not all(x.is_file() for x in bins):
        raise RuntimeError('No valid input binaries')
    parent = root / '.sim_runs'
    parent.mkdir(exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix='baseline-', dir=parent))
    print('RUN_DIR', work, flush=True)
    run([tools['vlib'], 'work'], work, work/'vlib.log', 30)
    cmd = [tools['vlog'], '-sv', '-work', 'work',
           '+incdir+' + str(root/'rtl/core'),
           '+incdir+' + str(root/'rtl/perips')] + [str(x) for x in sources]
    run(cmd, work, work/'compile.log', 120)
    script = work/'run.do'
    script.write_text('onerror {quit -f -code 1}\nrun -all\nquit -f -code 0\n',
                      encoding='ascii')
    passed = 0
    for binary in bins:
        data = binary.read_bytes()
        if not data or len(data) > 16384:
            raise RuntimeError('Binary empty or exceeds original program RAM')
        data += bytes((-len(data)) % 4)
        words = [data[i:i+4][::-1].hex() for i in range(0, len(data), 4)]
        (work/'inst.data').write_text('\n'.join(words)+'\n', encoding='ascii')
        log = work/(binary.stem+'.log')
        text = run([tools['vsim'], '-c', '-onfinish', 'stop',
                    'work.tinyriscv_soc_tb', '-do', 'run.do'], work, log, 120)
        if text.count('TEST_PASS') != 1 or re.search(r'TEST_FAIL|Time\s*Out|TIMEOUT', text, re.I):
            raise RuntimeError('TEST_FAIL_OR_NO_PASS: '+str(log))
        passed += 1
        print('PASS', binary.name, flush=True)
    print('SUMMARY', passed, '/', len(bins), 'PASS', flush=True)

if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print('RUN_FAILED:', e, file=sys.stderr)
        sys.exit(1)
```

未来运行命令：

```powershell
Set-Location 'E:\file\pango\tinyriscv_axi4'
python .\sim\run_baseline.py --case rv32ui-p-add
if ($LASTEXITCODE -ne 0) { throw 'Baseline add failed' }
python .\sim\run_baseline.py --all
if ($LASTEXITCODE -ne 0) { throw 'Baseline suite failed' }
```

当前源码目录有47个bin；目录没有变化时应显示`SUMMARY 47 / 47 PASS`。这是期望值，不是本轮实跑结果。runner语法通过也不能代替这47例。负向验证：把测试台成功条件暂改为固定false，必须报错；恢复后再跑。`.sim_runs`仅做本地证据，提交精简日志清单，不把全部大VCD加进Git。

### 27.4 新模块统一怎么跑

以N02为例，在实施副本`sim`工作目录执行；每个任务使用不同work库名，不污染原CPU基线：

```powershell
vlib work_n02
if ($LASTEXITCODE -ne 0) { throw 'vlib failed' }
vlog -sv -work work_n02 +incdir+../rtl/core ../rtl/core/pipe_slot.v ../tb/unit/tb_pipe_slot.sv
if ($LASTEXITCODE -ne 0) { throw 'compile failed' }
vsim -c -onfinish stop work_n02.tb_pipe_slot -do 'run -all; quit -f -code 0' -l n02.log
if ($LASTEXITCODE -ne 0) { throw 'simulation failed' }
$log = Get-Content -Raw .\n02.log
if ($log -notmatch 'TEST_PASS N02' -or $log -match 'TEST_FAIL|TIMEOUT|\*\*\s*(Error|Fatal)') { throw 'N02 not passed' }
```

已有库则直接重编译，不无条件递归删除。命令等仿真结束后才继续；测试台自带总周期watchdog，进程层仍需120秒超时保护，正式自动回归用27.3的`run()`逻辑包裹同样命令。

日志中`Errors: 0`是成功摘要，不应因含单词Error就判失败。ModelSim 10.6e中onerror应放`.do`宏文件内；在一串命令中直接调用可能只给出“for use within macro”警告。正式runner使用上面的run.do，并同时检查日志与退出码，不能只靠其中一项。

## 28. N02/N03：流水线、提交、译码和除法怎样改

### 28.1 完整模板：pipe_slot.v

**新建：** `rtl/core/pipe_slot.v`。原`gen_pipe_dff`在hold时装默认值；此模块阻塞时保持原数据。用它替换新流水线槽，不改旧通用触发器。

```verilog
module pipe_slot #(parameter WIDTH = 32)(
    input wire clk, input wire rst_n, input wire flush,
    input wire in_valid, output wire in_ready,
    input wire [WIDTH-1:0] in_data,
    output wire out_valid, input wire out_ready,
    output wire [WIDTH-1:0] out_data
);
    reg valid_q;
    reg [WIDTH-1:0] data_q;
    assign in_ready = rst_n && !flush && (!valid_q || out_ready);
    assign out_valid = rst_n && !flush && valid_q;
    assign out_data = data_q;
    always @(posedge clk) begin
        if (!rst_n) begin
            valid_q <= 1'b0;
            data_q <= {WIDTH{1'b0}};
        end else if (flush) begin
            valid_q <= 1'b0;
        end else if (in_ready) begin
            valid_q <= in_valid;
            if (in_valid) data_q <= in_data;
        end
    end
endmodule
```

逐行理解：`valid_q`表示槽里有没有真指令；`!valid_q || out_ready`表示“空着，或者旧指令本拍会出去”，因此能接新指令；flush优先，不同时接入年轻指令；`data_q`在stall时不更新。**不能把当前EX自己的redirect接到当前EX槽的out_valid门控上**，否则redirect依赖retire、retire又依赖out_valid，可能形成组合环。redirect清IF/ID和送入EX的年轻输入；当前EX由retire/trap离开。

### 28.2 完整模板：tb_pipe_slot.sv

**新建：** `tb/unit/tb_pipe_slot.sv`。先写这个测试，缺少模块时编译失败，再添加28.1并按27.4运行。

```systemverilog
`timescale 1ns/1ps
module tb_pipe_slot;
    reg clk=0, rst_n=0, flush=0, iv=0, ordy=0;
    reg [31:0] idata=0;
    wire ir, ov;
    wire [31:0] od;
    always #5 clk=~clk;
    pipe_slot #(.WIDTH(32)) dut(.clk(clk),.rst_n(rst_n),.flush(flush),
        .in_valid(iv),.in_ready(ir),.in_data(idata),
        .out_valid(ov),.out_ready(ordy),.out_data(od));
    task tick; begin @(posedge clk); #1; end endtask
    initial begin
        #10000; $fatal(1,"TIMEOUT N02");
    end
    initial begin
        repeat(5) tick();
        @(negedge clk); rst_n=1;
        @(negedge clk); iv=1; idata=32'hA;
        tick();
        if (ov!==1 || od!==32'hA) $fatal(1,"load A");
        @(negedge clk); idata=32'hB;
        repeat(10) begin
            tick();
            if(ir!==0 || ov!==1 || od!==32'hA) $fatal(1,"stall lost A");
        end
        @(negedge clk); ordy=1;
        tick();
        if(ov!==1 || od!==32'hB) $fatal(1,"replace A with B");
        @(negedge clk); flush=1; idata=32'hC;
        #1;
        if(ir!==0 || ov!==0) $fatal(1,"flush handshake");
        tick();
        @(negedge clk); flush=0; iv=0;
        tick();
        if(ov!==0) $fatal(1,"flush did not clear");
        $display("TEST_PASS N02"); $finish;
    end
endmodule
```

验收负向：临时把stall分支改成清valid，应报`stall lost A`；恢复后重新通过。时钟沿前在negedge施加输入，posedge后`#1`检查，避免测试台和非阻塞赋值竞态。

### 28.3 逐文件修改卡：让ALU先通过，再接真实访存

**文件：** `if_id.v, id_ex.v, pc_reg.v, ctrl.v, id.v, ex.v, regs.v, tinyriscv.v`；新增`retire_ctrl.v`、`tb/unit/tb_retire_ctrl.sv`。一次改一个接口链，但每次更新相应实例和测试台。

1. **IF/ID：** 原文件分别例化inst/pc/int三个gen_pipe_dff。新槽打包`{pc[31:0],inst[31:0],fault[0],fault_cause[4:0],fault_tval[31:0],predicted_next_pc[31:0]}`，总宽134位，按同一顺序解包。外设中断不再随每条IF指令的`int_flag`流动，改独立pending路径至retire_ctrl。
2. **ID/EX：** 把现有inst、PC、reg_we、rd、reg1/reg2值、CSR控制、四个op字段一次锁存；新加fault元数据和预测下一PC，宽度用每个字段位宽相加的localparam，不手猜。先保留现有ALU字段名称，避免连线全改。只在ID实际被EX接收时读操作数。
3. **寄存器堆：** 保留32寄存器和x0逻辑。将`tinyriscv.v:u_regs.we_i`从旧EX组合写使能接到`retire_fire && ex_writes_rd && rd!=0`；旁路同样只用该有效写使能与最终完成值。不能用尚未返回的load输出做旁路。
4. **EX：** 保留算术/比较/乘法计算；将结果当候选值，不直接写回。删除`reg_wdata | div_wdata`及rd按位OR的选择方式，改为明确mux：load结果 / div结果 / ALU结果。每条EX槽只拥有一个最终结果来源。
5. **PC：** `pc_reg.v`保留唯一fetch_pc寄存器；IFU只保存请求副本，不再额外维护第二个自由递增PC。更新优先级`reset > 架构redirect > if_to_id_fire推进到预测next_pc > 保持`。`arch_next_pc`在retire_ctrl记录提交边界，不能代替fetch_pc。
6. **ctrl：** 不再用一个hold向量同时表达flush/stall/halt。输出年轻阶段flush、装入禁止及redirect；AXI RREADY由返回缓冲决定，不接全局流水线stall。
7. **先验纯ALU：** 用测试台注入`addi x1,x0,5; addi x2,x1,3; add x3,x1,x2`，分别期待5、8、13，恰好3次retire。没有LSU前，load使用受控结果模型而非假数据0。

**集成片段的信号定义：** `ex_valid`来自EX槽，`ex_done`是本指令结果已齐，`ex_fault`是本条确定的同步异常，`trap_ready`是异常控制器可以接纳，`cpu_running`表示不在reset/安全halt完成态，`ex_writes_rd`来自译码，`result_mux`是上述最终值。

```verilog
wire trap_fire = cpu_running && ex_valid && ex_done && ex_fault && trap_ready;
wire retire_fire = cpu_running && ex_valid && ex_done && !ex_fault;
wire ex_leave = retire_fire || trap_fire;
wire rf_we = retire_fire && ex_writes_rd && (ex_rd != 5'd0);
wire [31:0] rf_wdata = result_mux;
```

同步fault不退休。中断若接在成功退休之后，该条可以写回，之后禁止年轻指令进入；不能用旧`int_assert`把已经成功的老指令写回一起抹掉。halt请求也先完成老指令，再置halted，不把`cpu_running`提前清零卡死老store。无backpressure的ALU本拍离开，下一条可同拍接入；但分支错预测/trap/接纳中断/halt时禁止年轻装入。

这里的“halt先完成老指令”必须按12.1执行：`halt_pending`可以阻止年轻装入，但不能参与当前EX的`op_fire`、`ex_done`、`trap_fire`门控。当前EX若发生同步异常或真实redirect，先形成正确`arch_next_pc`，再进入halt。

`retire_order`复位为0，每个retire加1。仿真每次打印`order,pc,inst,rd_valid,rd,wdata,mem_addr,mem_mask,trap`；同步异常另有trap事件，不增加instret。以顺序号识别重复，不用PC唯一性判断循环。

**N03验收刺激：** 三条ALU；ALU写x0；load延迟20拍后立即add；store数据来自上一条load；rd相同连续写；除法中暂停；同拍EX完成与分支flush。逐项检查次数，不只看最后值。

### 28.4 完整模板：保留旧div算法的adapter

**源码事实：** `div.v`的START/CALC/END在`start_i=0`时退出运算。一次CPU请求不等于一次旧start电平脉冲。本方案在CPU内部新增adapter，不修改除法算法。

**新建：** `rtl/core/div_adapter.v`；CPU不再同时实例化第二个原div，原`u_div`移到adapter内。输入请求字段在握手时锁存；结果保存到EX消费，rd仍由EX槽持有。

```verilog
module div_adapter(
    input wire clk, input wire rst_n,
    input wire req_valid, output wire req_ready,
    input wire [31:0] dividend, divisor,
    input wire [2:0] op,
    output wire rsp_valid, input wire rsp_ready,
    output wire [31:0] rsp_data
);
    reg active_q, result_valid_q;
    reg [31:0] dividend_q, divisor_q, result_q;
    reg [2:0] op_q;
    wire raw_ready, raw_busy;
    wire [31:0] raw_result;
    wire [4:0] unused_rd;
    wire raw_start = active_q && !raw_ready;
    assign req_ready = rst_n && !active_q && !result_valid_q;
    assign rsp_valid = rst_n && result_valid_q;
    assign rsp_data = result_q;
    div u_div(.clk(clk),.rst(rst_n),.dividend_i(dividend_q),
        .divisor_i(divisor_q),.start_i(raw_start),.op_i(op_q),
        .reg_waddr_i(5'd0),.result_o(raw_result),.ready_o(raw_ready),
        .busy_o(raw_busy),.reg_waddr_o(unused_rd));
    always @(posedge clk) begin
        if(!rst_n) begin
            active_q<=0; result_valid_q<=0;
            dividend_q<=0; divisor_q<=0; op_q<=0; result_q<=0;
        end else begin
            if(req_valid && req_ready) begin
                dividend_q<=dividend; divisor_q<=divisor; op_q<=op;
                active_q<=1;
            end
            if(active_q && raw_ready) begin
                result_q<=raw_result; result_valid_q<=1; active_q<=0;
            end
            if(rsp_valid && rsp_ready) result_valid_q<=0;
        end
    end
endmodule
```

`raw_ready`来自原div寄存器；完成后马上让raw_start变0，防止旧div回到IDLE时把仍为1的start当第二次启动。完成值同时保存，不受原div下一拍清结果影响。EX只在`req_valid&&req_ready`置issued，只消费一次rsp。除法本身无外部写副作用，但本方案仍等待结果在指令边界接中断，避免中途取消协议增加难度。

**完整测试模板：** 新建`tb/unit/tb_div_adapter.sv`，vlog清单为`div.v div_adapter.v tb_div_adapter.sv`，include仍是`rtl/core`，top=`tb_div_adapter`。

```systemverilog
`timescale 1ns/1ps
module tb_div_adapter;
    reg clk=0,rst_n=0,qv=0,rr=0;
    reg [31:0] a=0,b=0;
    reg [2:0] op=0;
    wire qr,rv; wire [31:0] data;
    always #5 clk=~clk;
    div_adapter dut(.clk(clk),.rst_n(rst_n),.req_valid(qv),.req_ready(qr),
        .dividend(a),.divisor(b),.op(op),.rsp_valid(rv),.rsp_ready(rr),.rsp_data(data));
    task check_div(input [31:0] x,y,input [2:0] fn,input [31:0] expected);
        integer n;
        begin
            @(negedge clk); a=x;b=y;op=fn;qv=1;
            if(qr!==1) $fatal(1,"request not ready");
            @(posedge clk); #1;
            @(negedge clk); qv=0;
            n=0;
            while(rv!==1 && n<100) begin @(posedge clk);#1;n=n+1;end
            if(rv!==1 || data!==expected) $fatal(1,"bad division");
            repeat(7) begin
                @(posedge clk);#1;
                if(rv!==1 || data!==expected || qr!==0) $fatal(1,"lost result");
            end
            @(negedge clk);rr=1;
            @(posedge clk);#1;
            @(negedge clk);rr=0;
            repeat(3) begin @(posedge clk);#1;if(rv!==0) $fatal(1,"duplicate result");end
        end
    endtask
    initial begin #200000;$fatal(1,"TIMEOUT DIV");end
    initial begin
        repeat(5) @(posedge clk);
        @(negedge clk);rst_n=1;
        check_div(20,3,3'b100,6);
        check_div(32'hFFFFFFEC,3,3'b100,32'hFFFFFFFA);
        check_div(32'hFFFFFFEC,3,3'b110,32'hFFFFFFFE);
        check_div(32'hFFFFFFFF,2,3'b101,32'h7FFFFFFF);
        check_div(32'hFFFFFFFF,2,3'b111,1);
        check_div(9,0,3'b100,32'hFFFFFFFF);
        check_div(9,0,3'b110,9);
        check_div(32'h80000000,32'hFFFFFFFF,3'b100,32'h80000000);
        check_div(32'h80000000,32'hFFFFFFFF,3'b110,0);
        $display("TEST_PASS N03_DIV");$finish;
    end
endmodule
```

### 28.5 译码合法性与JALR的最小改法

**修改：** `id.v`加入`illegal,uses_rs1,uses_rs2`输出并进入EX槽；`ex.v`只计算合法操作。不是把所有default从零改成NOP。按opcode进一步验证funct3/funct7：LOAD仅000/001/010/100/101；STORE仅000/001/010；BRANCH仅000/001/100/101/110/111；JALR要求funct3=000；SLLI要求高7位0000000；SRLI/SRAI要求0000000/0100000；OP的减法/算术右移与M扩展分别检查完整编码。

**替换定位：** 搜索`ex.v`的`INST_JAL, INST_JALR`，拆开目标计算。下列为集成片段，`sum`是rs1+符号扩展I立即数，`taken`由合法分支比较得出。

```verilog
wire [31:0] jalr_target = sum & 32'hFFFF_FFFE;
wire target_misaligned = actual_taken && (actual_target[1:0] != 2'b00);
```

先清JALR bit0，再检查无C配置4字节对齐；未采取的条件分支不得因为候选目标不对齐而异常。只有跳转成功才提交link rd。`0x00000001`不再是合法32位NOP，作为真实取到的指令应非法，气泡由valid=0处理。

**必测程序：** rs1=0x101、imm=0，JALR实际到0x100；rs1=0x102则cause0且link寄存器不变；beq不成立且候选目标+2，不应异常；非法SLLI高位与正常SLLI分别测试。保留原M乘法结果但增加极值回归，不把“算法保留”当做“无需再测”。

## 29. N04-N09：AXI、取指、访存、存储和互连的具体修改方法

### 29.1 先做单拍，但一开始保留AXI4字段

**文件：** 新建`axi_read_engine.v, axi_data_engine.v`以及`tb/axi/tb_axi_read_engine.sv, tb_axi_data_engine.sv`。外部位宽沿用3.2，不删LEN/LAST/ID。N04/05仅接受len=0，N13加8拍，N17加1-16拍，未启用长度在内部描述符入口报告配置错误，不能静默截短。

每个字段只由一个always块或assign驱动。先在纸上标明“CPU内部请求握手”和“外部AXI握手”是两个事件，前者锁存参数，后者不再读取变化的EX输入。

**固定内部描述符：** `req_valid/req_ready, req_addr[31:0], req_size[2:0], req_len[7:0], req_id[3:0]`；数据引擎额外`req_write`。写数据流`w_valid/w_ready,w_data[31:0],w_strb[3:0],w_last`。读结果`rsp_valid/rsp_ready,rsp_data[31:0],rsp_resp[1:0],rsp_last,rsp_id[3:0]`；写结果`b_valid/b_ready,b_resp[1:0],b_id[3:0]`。以上是内部信号，不与顶层AXI同名混接；统一加`eng_`前缀。

**读引擎状态卡：**

| 状态 | 本拍输出/动作 | 转移 |
|---|---|---|
| RD_IDLE | req_ready=1，其他VALID=0；接受req时锁存全部AR字段 | req_fire后RD_ADDR |
| RD_ADDR | ARVALID=1，AR负载固定，RREADY=0 | AR握手后RD_DATA |
| RD_DATA | RREADY在内部返回槽空或将被消费时为1；R握手锁存数据/RESP/ID/LAST | len=0时收到一拍进入RD_HOLD |
| RD_HOLD | rsp_valid=1，结果保持；不得发第二笔AR | rsp_fire后RD_IDLE |

返回延迟最短可紧随AR握手的下一拍；从设备RVALID出现后会保持到RREADY，不要求引擎在AR握手同拍就接收R。RRESP!=OKAY是总线错误；RID不匹配或len=0却RLAST=0属于协议违例，在测试中fatal、硬件协调故障，不自造一个“正常完成”掩盖失步。

**写引擎状态卡：**

| 状态 | 本拍输出/动作 | 转移 |
|---|---|---|
| WR_IDLE | req_ready=1；锁存地址及单拍写数据，或进入等待内部写数据的准备态 | 描述符和首拍数据都保存后WR_SEND |
| WR_SEND | aw_pending产生AWVALID，w_pending产生WVALID；各自握手各自清除 | 两者都完成后WR_RESP |
| WR_RESP | BREADY在写结果槽有空间时为1，B握手锁存BRESP/BID | WR_HOLD |
| WR_HOLD | b_valid=1保持，成功/失败都只交付一次 | b_fire后WR_IDLE |

N05单拍可在接受描述符后等待内部w流到齐再同时发外部AW/W，这不要求外部READY先高。N17突发再加逐拍数据缓存。任何阶段不得用BRESP失败自动重试store。

**集成片段：** `aw_pending_q/w_pending_q`属于WR_SEND，握手事件是当前输出VALID与READY，不用READY单独计数。

```verilog
wire aw_fire = m_awvalid && m_awready;
wire w_fire  = m_wvalid  && m_wready;
wire aw_complete_now = !aw_pending_q || aw_fire;
wire w_complete_now  = !w_pending_q  || w_fire;
// WR_SEND时，aw_fire清aw_pending_q，w_fire清w_pending_q。
// 两个complete_now同时为1才进入WR_RESP。
```

### 29.2 从第一天就加逐拍协议检查

**新建：** `tb/axi/axi_monitor.sv`。以下完整小模块可作为AR/AW/W/R/B五类稳定性检查共用单元，payload必须包含该通道全部字段，不能漏ID/LAST。

```systemverilog
module stable_channel_check #(parameter W=32)(
    input wire clk,rst_n,valid,ready,
    input wire [W-1:0] payload
);
    reg blocked_q;
    reg [W-1:0] payload_q;
    always @(posedge clk) begin
        if(!rst_n) begin blocked_q<=0;payload_q<=0;end
        else begin
            if(blocked_q && (valid!==1'b1 || payload!==payload_q))
                $fatal(1,"CHANNEL_CHANGED_WHILE_BLOCKED");
            blocked_q <= valid && !ready;
            payload_q <= payload;
        end
    end
endmodule
```

文件名是`axi_monitor.sv`，模块名是`stable_channel_check`，例化时不要写错。另用整数计数器记录AR数量、R拍数、AW数量、W拍数、B数量；单拍结束要求AR=R、AW=W=B，突发按每笔len+1检查。错误响应也计入完成，不把error当作没有事务。

**具体刺激而非一句“随机测试”：**

| 用例 | 测试台动作 | 必查结果 |
|---|---|---|
| AR阻塞 | 发送地址0x10000000，ARREADY低10拍，期间改变CPU原始地址输入 | 总线ARADDR仍为旧地址，最后只一笔AR |
| AW先到 | AWREADY=1，WREADY低5拍 | AW一次，WDATA/WSTRB稳定，B一次 |
| W先到 | WREADY=1，AWREADY低5拍 | W一次，AW稳定，不能提前提交 |
| 从设备依赖 | AWREADY只有看到WVALID才置1 | 写仍完成，无相互等待 |
| 返回被堵 | 上层rsp_ready或b_ready低7拍 | 返回数据/错误码保持 |
| 错误 | 注入RRESP=SLVERR或BRESP=SLVERR | fault一次，load不写rd、store不重发 |

随机只改变等待长度0-31拍，每次用`+SEED=1`至20固定种子，driver必须保证最终会响应；切换ready在negedge，比较在posedge采样，避免竞争。随机等待不替代上述确定性反例。

### 29.3 IFU修改卡：PC和指令必须成对

**修改/新增：** `pc_reg.v, ifu_axi.v, if_id.v, tinyriscv.v`；测试`tb/unit/tb_ifu_axi.sv`。

1. `pc_reg.pc_o`作为fetch_pc输入；IFU空闲时保存`req_pc_q=fetch_pc`及预测下一PC，预留1个返回槽，然后发引擎请求。
2. 所有返回使用`req_pc_q`标记，不用此时可能已跳转的fetch_pc。
3. 返回槽按28.1方法与IF/ID握手；IF/ID接纳时才推进fetch_pc到保存的预测next_pc。redirect优先于该推进。
4. IFU从内部`req_fire=eng_req_valid&&eng_req_ready`起就拥有一笔在途请求，不能等看到外部ARVALID或AR握手后才算在途。保存`req_pc_q`的同一拍同时保存`req_live_q=1`；从RD_ADDR、RD_DATA到返回槽被消费/丢弃前都保持该身份。
5. redirect优先于顺序取指推进。若redirect到来时尚未内部接单，组合门控使旧`req_valid=0`；若redirect与旧`req_fire`同拍，允许引擎接单但必须把该请求标成`discard_pending=1`，不得依赖非阻塞赋值后的旧`req_live_q`漏标。若已经内部接单但尚在RD_ADDR、已经AR握手、等待R或结果停在返回槽，均继续排空并丢弃。
6. `discard_pending`只由“该请求最终被丢弃并释放”清零，第二次redirect只更新最新`redirect_target`，不能把discard清掉。旧请求的RRESP错误和协议fault不得进入架构trap；正确路径fault才带PC与地址送入流水线。
7. 完成旧请求后，只能用pc_reg已接纳的最新redirect目标重新发请求。新目标请求不得覆盖旧`req_pc_q`，直到旧请求的引擎结果与IFU返回槽都释放。
8. IFU只允许在程序RAM或已启用且标可执行的普通内存取指。数据RAM是否可执行在地址属性表显式规定；首版只设程序RAM可执行，不默认所有地址可执行。

**逐拍样例：** 请求PC=0x20 -> AR握手 -> EX跳转0x80 -> 旧R返回0x20内容 -> R被接收但IF/ID不装入 -> 新AR=0x80。观察req_pc/discard/AR/R/IFvalid，而不是只看PC最后等于0x80。无Cache首版的请求槽从内部req握手到返回消费只占一条指令，不能消费前又发第二笔覆盖req_pc。

**必须新增的redirect相位测试：** 固定旧PC=0x20、新目标=0x80，分别让redirect出现在：(a)内部`req_fire`同拍；(b)内部已接单、读引擎处于RD_ADDR且ARREADY=0；(c)AR已握手等待R；(d)R已进入RD_HOLD/IFU返回槽但IF/ID未接纳。四例都要求旧指令退休次数为0、旧fault次数为0、最终只交付0x80指令。再增加连续两次redirect，最终目标取第二次值且旧请求仍被排空。

### 29.4 LSU修改卡：把旧的读改写变成字节使能

**修改/新增：** `ex.v, lsu_axi.v, axi_data_engine.v, tinyriscv.v`；测试`tb/unit/tb_lsu_axi.sv`。

1. EX计算有效地址，但不读旧内存拼SB/SH；保存地址、rs2、size、unsigned、PC/rd到LSU请求。
2. op握手置EX的issued；等done或fault前不再发op。离开EX后才清issued用于下一条。
3. 在请求AXI之前检查LH/SH地址bit0，LW/SW低2位；未对齐立即fault，AR/AW/W计数保持零。
4. 外部ARADDR/AWADDR保留原字节地址，size编码byte=0/half=1/word=2；发送数据左移8*offset，strb为1/3/15相应移位。**不能把byte地址对齐后仍沿用原lane规则而不修改AXI size语义。**
5. 返回的32位RDATA只有该次窄访问涉及的lane保证有效，LSU提取所需字节后扩展；Cache命中也返回对应32位字且沿用一次提取。
6. B成功才使store完成，load R成功才使最终数据有效；done在EX消费前保持。x0目的load也要执行内存读及错误检查。

**完整小函数模板，可放在lsu_axi模块内：**

```verilog
function [31:0] extend_load;
    input [31:0] raw;
    input [1:0] offset;
    input [2:0] size;
    input is_unsigned;
    reg [31:0] shifted;
    begin
        shifted = raw >> (8*offset);
        case(size)
            3'd0: extend_load = is_unsigned ? {24'b0,shifted[7:0]} :
                                                   {{24{shifted[7]}},shifted[7:0]};
            3'd1: extend_load = is_unsigned ? {16'b0,shifted[15:0]} :
                                                   {{16{shifted[15]}},shifted[15:0]};
            3'd2: extend_load = shifted;
            default: extend_load = 32'b0;
        endcase
    end
endfunction
```

default不是非法size访问的成功结果：译码/前置检查必须先拒绝size>2。测试`raw=0x807FFF01`：LB(base+2)=0x7F，LB(base+3)=0xFFFFFF80，LBU(base+3)=0x80，LH(base)=0xFFFFFF01，LHU(base)=0x0000FF01。

**短汇编测试输入：** 程序从0开始，无C扩展；EX退休监视器检查x3/x4和数据RAM四字节，testbench在完成标志退休时停，不使用无限等待。

```asm
.option norvc
.section .text
.globl _start
_start:
    lui  x10, 0x10000
    addi x1, x0, 5
    sw   x1, 0(x10)
    lw   x2, 0(x10)
    add  x3, x2, x2
    addi x4, x0, -1
    sb   x4, 1(x10)
    lbu  x4, 1(x10)
    addi x27, x0, 1
    addi x26, x0, 1
1:  jal x0, 1b
```

预期x3=10、x4=255，RAM[0x10000000]整字=0x0000FF05。分别让load R延迟20拍、store B延迟30拍；每笔store内存事件仍一次。单独的对齐/总线错误测试不能复用“只等x26”的无限结束条件，错误路径由trap日志核对。

### 29.5 RAM与GPIO从设备：先一个目标，再扩整套

**修改：** `rtl/perips/rom.v, ram.v, gpio.v`；新建`tb/axi/tb_axi_ram.sv, tb_axi_gpio.sv`。

程序RAM/数据RAM保留数组容量与初始化路径；数组不逐字复位。先用同步读口，读地址第k拍锁存、第k+1拍得到数据、第k+2拍装入R槽也可以，宁可先多一拍明确正确，不用组合读假装BRAM。

1. 各设AR描述符槽、AW描述符槽、W数据槽；N06单事务策略下READY只在对应槽空且可预留结果时拉高。
2. W先到先存`data/strb/last`，不知道AW地址时绝不写RAM；AW到齐、长度/size/范围合法再一次写入。
3. word索引使用`(addr-base)>>2`，先验证整个请求范围在物理容量内，再索引，不能仅丢弃高位形成镜像。
4. 按strb分四个byte写；R槽满且未消费时不得覆盖。先不实现同周期同地址双端口读写，事务串行确定顺序。
5. GPIO保留CTRL=0、DATA=4偏移；2bit/引脚的模式不改成另一套不兼容布局。原仅两个输入，真实顶层引脚数量按板卡确认；按键需同步，消抖是软件/独立模块功能，不把抖动当CPU错。

**集成片段，变量归属：** `write_event`只在保存的AW/W被内部执行一次时为1；`word_idx`是已检查索引；`wdata_q/wstrb_q`来自W槽。

```verilog
integer lane;
always @(posedge clk) begin
    if(write_event) begin
        for(lane=0;lane<4;lane=lane+1)
            if(wstrb_q[lane])
                mem[word_idx][8*lane +: 8] <= wdata_q[8*lane +: 8];
    end
end
```

GPIO控制/数据普通RW字段可用相同byte mask；Timer pending的W1C不适用普通“写数据覆盖”。Timer到期与清pending同拍应按已公布优先级处理，UART状态硬件事件与软件写也不能因一个大if/else丢事件。

**UART具体取舍：** 保留CTRL/STATUS/BAUD/TXDATA/RXDATA偏移0/4/8/C/10与STATUS bit定义。首版TX忙时写TXDATA返回SLVERR且不发送，驱动先轮询busy=0；不得默默返回OKAY却丢字。RX-over沿用旧可写bit语义，若改W1C须同时改驱动，不能只改硬件。每次AXI接受只产生一次`tx_data_valid`脉冲，连续其他寄存器写不应把该脉冲延长。

**N06验收地址：** 0x10000000读写、0x10003FFC最后字、0x10004000越界；GPIO写CTRL=1、DATA=1后读回；WSTRB=0010只改目标第二字节；无效寄存器报SLVERR无副作用。

### 29.6 互连：先2主2从，再扩大端口数量

**新建：** `rtl/bus/axi_interconnect.v, axi_error_slave.v`；测试`tb/axi/tb_axi_interconnect.sv`。

先连接IF读主与LSU读写主、程序RAM与数据RAM，保留固定ID 0/1；调试和AI端口未实现时绑无效。不要一次写6主十几个从设备再查串包。地址译码函数在唯一位置，以完整窗口范围判断；外设低偏移是否合法由目标判断。

| 状态 | 保存/路由 | 退出 |
|---|---|---|
| FREE | 轮询AR/AW候选；选中时保存owner、type、target | 一旦向下呈现地址即进入R_LOCK/W_LOCK |
| R_LOCK | 只转发owner的AR，握手后收目标R；响应只返回owner | 预期末拍R握手，错误也要排空 |
| W_LOCK | 同一owner的AW和W独立转发，分别记录完成；不接其他owner的W | 目标B握手 |

组合路由必须保持锁定的owner/target，不能每拍用“当前谁优先”重选。若加输入寄存切片，上游握手与下游握手分别记录，不能用一个fire代替两端。目标AWREADY可依赖WVALID，W路径不得再依赖目标AWREADY；自定义从设备输出VALID也不能组合依赖输入READY。

**错误slave：** 合法格式未映射读回len+1拍DECERR、原ID、末拍LAST；写保存AW，消费len+1拍后B=DECERR且不写任何目标。WLAST不一致/少拍是协议错误，用watchdog判错，不能承诺对永不结束的非法输入自动恢复。

**N09接回CPU的顺序：** 纯算术 -> 分支 -> 数据RAM -> UART/GPIO -> 可变延迟 -> 错误响应 -> 原47例 -> 新ISA/中断例。原47例通过不覆盖协议与非法指令，所以后两类不能省。每步新编译清单只含一个SoC top，不与原RIB同名实现混编。

## 30. N10-N12：异常、中断与软件逐项修改

### 30.1 同步异常先做好，不等待全部外设中断

**文件：** `id.v, ex.v, retire_ctrl.v, csr_reg.v, clint.v`及`tests/axi/trap_cases.S`。先实现主文13.1中同步原因0/1/2/3/4/5/6/7/11。对同一条指令先做译码和对齐检查，失败就不发访存；后到的总线错误只属于真正发出的那一条。取指错误带身份走至EX，不能越过老store。

**单点CSR更新方法：** csr_reg新增`trap_enter, trap_pc, trap_cause, trap_tval, mret_fire`输入。由同一时钟过程更新mepc/mcause/mtval/mstatus；不再让旧clint连续几拍串行改多个CSR期间允许CPU继续提交。正常CSR写与trap入口同拍时，先形成正常指令提交后的候选CSR值，再按trap规则更新，尤其“写mstatus后立即接中断”不能保存旧MIE。

**集成算法而非覆盖原文件：**

```text
csr_next = csr_current
若 csr_commit：按只读/WARL/位掩码处理正常CSR写
若 mret_fire：MIE <- 当前MPIE；MPIE <- 1；MPP <- M
若 trap_enter：
    mepc <- trap_pc按IALIGN规则合法化
    mcause <- trap_cause；mtval <- trap_tval
    MPIE <- 此时csr_next.MIE；MIE <- 0；MPP <- M
时钟沿一次写入csr_next
```

正常异常指令没有csr_commit。一次MRET后立即接新中断时，trap_pc是MRET恢复的目标，不是MRET+4。只支持M模式时，不实现的权限位读合法固定值，不能允许软件写出假S/U状态。未实现CSR非法访问；只读计数器的读与有零掩码CSRRS/CSRRC合法，非零写非法。

### 30.2 中断来源和软件更新，不要只改mcause

**硬件文件：** `irq_ctrl.v, timer.v, csr_reg.v, retire_ctrl.v, tinyriscv_soc_top.v`。Timer事件接MTIP；IRQ_CTRL软件bit接MSIP；AI或GPIO来源先同步/锁存到EXT_PENDING，再经EXT_ENABLE聚合为MEIP，最后还要受mie.MEIE与mstatus.MIE控制。

**基础启动修改：** `tests/example/init.c`在T08a先明确关闭中断。T08b timer例程先写mtvec、关闭/清除Timer旧pending、配置Timer计数、设置mie.MTIE，最后开MIE。以下为集成片段，`trap_entry`沿用原汇编入口，Timer寄存器操作沿用原驱动。

```c
extern void trap_entry(void);
static inline void enable_timer_irq(void) {
    unsigned long vector = (unsigned long)&trap_entry;
    unsigned long mask = 1UL << 7;
    __asm__ volatile ("csrw mtvec, %0" :: "r"(vector) : "memory");
    __asm__ volatile ("csrs mie, %0" :: "r"(mask) : "memory");
    __asm__ volatile ("csrsi mstatus, 8" ::: "memory");
}
```

首版固定RV32裸机，`unsigned long`应为32位；编译时检查`-mabi=ilp32`及ELF属性，不用宿主机编译器验证可执行性。启动环境先建立SP、初始化.data/.bss再开中断，不能栈尚未准备就跳C handler。

**trap_entry.S改法：** 保留保存/恢复x1-x31的框架和16字节栈对齐；旧SIMULATION跳过保存x26/x27仅用于旧测试哨兵，新中断回归应保存全部架构寄存器，完成状态由专用测试监视器/提交事件判断。去掉“全部同步异常直接+4”的通用分支，统一调用C分发函数，C返回下一mepc。

```asm
    # 在保存寄存器之后，替换旧同步/异步分叉段
    csrr a0, mcause
    csrr a1, mepc
    csrr a2, mtval
    call trap_dispatch
    csrw mepc, a0
    # 接原寄存器恢复段，最后mret
```

`trap_dispatch`原型明确为`uint32_t trap_dispatch(uint32_t cause,uint32_t epc,uint32_t tval)`，返回恢复PC。异步分支按最高位和原因码3/7/11清相应源后返回原epc。只有**测试专用**ECALL cause11允许return epc+4；未知同步异常先保存cause/epc/tval到RAM诊断结构并禁止中断、停在死循环，不读写可能再次故障的外设。没有完整串口可用前，不强行在异常内printf。

**必须测试：** 定时中断前后x1-x31哨兵不变；mie屏蔽期间pending保留；enable后恰好处理；pending未清MRET后重新进入是预期，不是“CPU重复中断bug”；只读CSR写报cause2；MRET返回低位合法化；陷阱期间新事件不丢失。

### 30.3 64位计时的完整替换函数

**修改：** `tests/example/lib/utils.c:get_cycle_value()`，替换原低后高各一次读取，保留其他函数。

```c
#include <stdint.h>
uint64_t get_cycle_value(void) {
    uint32_t hi0, lo, hi1;
    do {
        __asm__ volatile ("csrr %0, cycleh" : "=r"(hi0));
        __asm__ volatile ("csrr %0, cycle"  : "=r"(lo));
        __asm__ volatile ("csrr %0, cycleh" : "=r"(hi1));
    } while (hi0 != hi1);
    return ((uint64_t)hi1 << 32) | lo;
}
```

时间读取函数不等于DMA排序屏障，需要前后内存顺序时另用`asm volatile(... ::: "memory")`。测试计数器从`0x00000000FFFFFFFE`附近开始跨回绕，函数必须重试而非跳增一个高32位周期。`time_in_secs`另核验换算上界；CPU频率宏由一个构建参数生成，UART分频也按实际频率计算，不一直写死50MHz。

### 30.4 基础上板的通过顺序

只导入新CPU文件清单与板级top，保留器件/引脚/电压来自真实板卡资料，不提供虚构引脚号。先低风险频率设置并通过布局布线时序，按算术签名、RAM测试、UART一串固定字符、GPIO变化、CoreMark两套种子与>=10秒记录逐项验收。T08b再加入中断；若加中断后失败，回退功能开关定位，不重写所有模块。

CoreMark需检查算法源没有被修改、`.map`中程序与栈不重叠、软乘除libgcc与声明ISA匹配、实际运行频率与计时一致。原47例不包含CoreMark，不把两者混成同一测试覆盖。

## 31. N13/N14：两路Cache和预测器的详细任务卡

### 31.1 第一张卡只做tag/LRU，不马上连CPU

**文件：** `rtl/cache/icache_2way.v, dcache_2way.v`；测试`tb/cache/tb_cache_tags.sv`。参数沿用2路、32组、32字节行，不改变主文容量。

数组逻辑：每路32个22bit tag、32个valid；每组1bit victim；每路data=32组×8个32bit word。复位只清valid和victim，不遍历清data。同步data读分`LOOKUP_REQ -> LOOKUP_RESP`，不要把异步数组读当作将来一定推断BRAM。首次综合查看实际BRAM/LUT映射。

**集成片段：** `set=request_addr[9:5]`，`tag=request_addr[31:10]`；hit条件含valid。优先选无效路，否则选victim；访问way0后victim=1，访问way1后victim=0。

```verilog
wire hit0 = valid0[set] && tag0[set] == tag;
wire hit1 = valid1[set] && tag1[set] == tag;
wire choose_way = !valid0[set] ? 1'b0 :
                  !valid1[set] ? 1'b1 : victim[set];
```

期望两路不同时hit同一地址；双hit在仿真报错。用A=0x10000000、B=0x10000400、C=0x10000800，同组不同tag，顺序A、B、A、C、A、B：前2次miss，第3次hit，C淘汰B，A仍hit，最后B miss。不要错误用相差0x20的地址测试同组，它们是相邻组。

### 31.2 第二张卡实现补行，再接I侧

**测试：** `tb/cache/tb_icache_2way.sv`，使用29章AXI模型。状态`IDLE -> LOOKUP -> MISS_REQ -> REFILL -> REPLAY -> RESP`。

1. miss时保存原始请求PC、行地址、组、way；立即清受害way.valid，不允许旧tag配新写入的数据。
2. 发ARADDR=addr&~31、LEN=7、SIZE=2、INCR，beat计数0至7仅在R握手增加；每拍写word[beat]。
3. 错误累计`refill_error |= RRESP!=OKAY`；第8拍确认RLAST、ID正确、无错误且未发生失效，才写tag并置valid；否则保持invalid。
4. 首版不early restart，整行到齐后用保存的word_index取请求字交付。把refill第3拍返回错码，后5拍仍须排空，最终只一次fault。
5. 普通分支redirect只取消本次交付，可保留成功cache行；FENCE.I/debug代码修改属于失效，禁止在途旧行重新置valid。首版用`invalidate_pending`停新请求、排空refill、扫描清valid后才ack，不用会回绕的1bit epoch草率判断多次失效。

**引擎扩充：** N04的RD_DATA/RD_HOLD在burst下改为可反复流出的逐拍返回槽，`rsp_last`消费后才回IDLE；不得第1拍R后就释放全笔busy。对RREADY回压和同拍消费/下一拍装入逐一测试。

### 31.3 第三张卡接D侧：先写直达、不写分配

**测试：** `tb/cache/tb_dcache_2way.sv`。读命中返回word；读miss补8拍；store无论命中与否都下发单拍，等待B成功再修改命中行。size/strb由LSU生成一次，不在Cache内二次移位。B失败使匹配行失效并报store fault，不回写“猜测成功”的数据。

首版每个D-Cache一次只处理一个CPU操作。MMIO完全旁路，程序RAM的D访问按主文不缓存；IFU与LSU不是一致性多核系统，debug/DMA修改可缓存内存必须按维护协议。对共享缓冲，地址匹配器先判断不可缓存，再考虑普通DDR可缓存，优先级不可反转。

**CPU集成验收：** Cache关/开跑同一个已编译程序，其架构提交结果一致；单测A/B/C冲突序列、SB/SH命中、写miss不分配、B错误、行尾与边界、debug修改后可见。性能可变，但错误不能用“缓存时序不同”解释。

### 31.4 动态预测先预测，再统计真实收益

**文件：** `branch_predictor.v`及`tb/unit/tb_branch_predictor.sv`。32项BTB，index=PC[6:2]、tag=PC[31:7]；valid复位0，方向2bit初值01（弱不跳）。命中且conditional计数器最高位1才取目标；已学习无条件跳转直接取目标。

完整饱和计数器函数，放模块内部：

```verilog
function [1:0] update_counter;
    input [1:0] old_value;
    input taken;
    begin
        if(taken) update_counter = old_value==2'b11 ? 2'b11 : old_value+2'b01;
        else update_counter = old_value==2'b00 ? 2'b00 : old_value-2'b01;
    end
endfunction
```

预测值随着PC/指令传到EX；实际next_pc与预测next_pc不等才redirect。训练只在合法控制流指令retire，异常/flush不训练；taken目标计算和JALR bit0处理沿用真实执行逻辑。对于条件分支not-taken，更新方向但BTB target仍保存分支跳转目标，不能保存PC+4冒充分支目标。

测试计数器上下饱和、同index不同tag、循环退出、JALR目标改变、普通ALU处BTB残留（代码更新应失效）、错路不能训练。核心验收是预测开/关程序结果相同；报告mispredict/branch与周期，不保证加入预测器一定提分。

## 32. N15：推荐增加的性能观测与基础应用

### 32.1 性能快照寄存器：可解释、可测量，不靠截图猜测

**新建：** `rtl/perips/perf_regs.v`，`tests/example/include/perf.h`，`tests/example/perf_demo/main.c`，测试`tb/unit/tb_perf_regs.sv`。地址沿用0x60002000，不另占与AI冲突的窗口。

| 偏移 | 内容 | 写规则 |
|---|---|---|
| 0x00 CTRL | bit0 SNAP命令、bit1 CLEAR命令，读为0 | 两bit同时写1返回SLVERR，无副作用 |
| 0x04 STATUS | bit0 snapshot_valid | 只读 |
| 0x10/14 | cycle低/高 | 只读快照 |
| 0x18/1C | instret低/高 | 只读快照 |
| 0x20/24 | IF等待周期低/高 | 只读快照 |
| 0x28/2C | LSU等待周期低/高 | 只读快照 |
| 0x30/34 | I miss操作数低/高 | 只读快照 |
| 0x38/3C | D miss操作数低/高 | 只读快照 |
| 0x40/44 | 退休控制流指令数低/高 | 只读快照 |
| 0x48/4C | 错预测数低/高 | 只读快照 |

冻结事件定义：cycle每个非reset系统时钟加1，含CPU暂停；instret仅retire_fire；IF等待=CPU运行、IF/ID可接且没有可交付取指结果；LSU等待=EX有效且内存操作已发但结果未齐；miss只计一次lookup miss，不每个refill拍都加。等待周期可以重叠，不能把它们相加声称等于总周期。原有CSR cycle保持独立，CLEAR只清本perf块计数器，不篡改架构时钟计数。

SNAP在内部write_event一次性复制全部计数器，随后CPU读的都是快照；定义快照捕获该时钟沿之前的counter值，报告窗口一致即可。CLEAR优先于本块该拍increment，并清snapshot_valid；多寄存器读期间不能自动刷新快照。

**测试：** 注入10拍，其中retire=4、LSU等待=3，SNAP后计数继续增长但读回仍10/4/3；再SNAP后更新；CLEAR后快照无效；未实现偏移SLVERR；WSTRB不含byte0时CTRL命令不触发。C端输出`CPI=delta_cycle/delta_instret`，instret=0时报告无有效样本，不除零。

### 32.2 小应用：GPIO边沿记录与CPU控制响应

先复用已有GPIO，不再立刻新增高吞吐采集硬件。输入按钮或外部方波，CPU轮询输入位，检测变化后记录cycle时间、输入值并翻转另一输出位，通过UART输出记录。它说明CPU确实执行采集/控制程序；不是“只有LED闪了一下”的展示，也不是高阶AI。

**文件：** `tests/example/gpio_trace/main.c`，复用gpio/uart/utils头文件；记录缓冲固定64项放数据RAM，每项`uint64_t ticks + uint32_t pins`，按实际C对齐用`sizeof`核验容量，不假设12字节。先在仿真注入8次相隔100周期输入变化，输出8条单调时间戳，UART输出放采集结束后，避免发送耗时污染采样。

后续可选升级：GPIO边沿pending接IRQ_CTRL中的一个EXT来源，ISR只存记录不printf；记录满后置overflow并停止存入，不覆盖旧数据却不提示。高频信号可能轮询漏边沿，明确频率边界，不能宣传实时逻辑分析仪精度。若要精确硬件采集，另立FIFO/采样时钟任务，不混入CPU主线。

### 32.3 对比配置怎么组织

在`rtl/core/soc_config.vh`集中定义CACHE_ENABLE/PREDICT_ENABLE/PERF_ENABLE以及实际内存大小；每种配置独立生成综合文件清单及bitstream名。第一次仅允许编译时开关；运行中更改cache属性/开关容易造成旧数据和在途事务问题，不给小白增加这一层风险。

每份报告记录配置、源码提交、ELF哈希、工具版本、频率、BRAM或DDR运行位置、CoreMark两套种子、UART原始日志、资源边界。比较C1/C2/C3优先同一个ELF、同频率；再单列各配置最高时序合格频点，不把频率升高当CPI改进。

## 33. N16/N17：DDR、DMA与AI怎样细化而不虚构硬件

### 33.1 明确哪些现在能做，哪些必须先拿到资料

现在能做：AXI内存模型上的DMA、INT8乘加与一层卷积黄金数据比较；不能直接做：假设厂商DDR就是标准AXI4、猜引脚/校准参数、只凭YOLO名字写固定层数RTL。后者需要主文T11/T12的实际IP端口、模型图与权重。

通过关卡的交付物固定为`docs/ddr_contract.md`和`docs/model_contract.md`：DDR文档列字节/字地址、位宽、burst单位、写完成、回压、mask极性、校准/reset/时钟；模型文档列版本/权重哈希、输入大小、全部算子/张量尺寸、量化/舍入/饱和规则、CPU回退算子、独立测试数据与目标精度。缺一项就不写依赖该项的板级RTL，不用“参考常见设计”填入猜测。

### 33.2 先做DMA复制，不先做摄像头加卷积

**新建：** `rtl/ai/tensor_dma.v`、`tb/ai/tb_tensor_dma.sv`、`tests/example/dma_copy/main.c`。首版只支持4字节对齐src/dst、字节数为4的倍数、src/dst不重叠；不支持条件直接参数错误，不偷偷扩大到任意memmove。

DMA与CPU共用全局单事务时，**不得先发读取描述符然后依赖另一笔写事务才腾出读接收空间**。先用16-word本地FIFO：读完整块 -> 释放读事务 -> 发写块 -> 等B -> 下一块。每次最多64字节，并同时考虑源与目标4KiB边界。

```text
chunk_bytes = min(remaining_bytes, 64,
                  4096 - (src_addr & 4095),
                  4096 - (dst_addr & 4095))
beats = chunk_bytes / 4
ARLEN/AWLEN = beats - 1
```

参数已保证word对齐与长度倍数，因此chunk非零且为4倍数。后续AI张量需要尾字节时单独扩展：分配边界内读取，写最后拍WSTRB精确生成；完成该测试后再放宽第一版限制。

测试src偏移0xFF0、dst偏移0xFF8、长度128字节：第一块最多8字节，不能只按src切块。检查所有读写地址、FIFO顺序与B完成；注入第二块读错误，停止发布新事务并排空在途，status=error，不能同时done=success。写START的B在锁存参数后返回，DONE等最后数据B成功才置位。

### 33.3 从一个MAC到一层，不从模型名字跳到整个系统

**新建：** `rtl/ai/mac_array.v`、`tb/ai/tb_mac_int8.sv`。首张卡只做signed INT8×INT8→INT16积、INT32累加。无浮点、无自定义ISA，CPU通过MMIO发任务。

```verilog
wire signed [7:0] a_s = input_byte;
wire signed [7:0] b_s = weight_byte;
wire signed [15:0] product = a_s * b_s;
wire signed [31:0] extended_product = {{16{product[15]}},product};
// mac_fire有效且非clear时：acc_q <= acc_q + extended_product;
// clear优先时本拍不同时累加；driver不得把首项与clear重合。
```

测试向量`[-128,-1,2,127]`与`[-128,3,-4,127]`点积=32502。测试clear、插入valid气泡、最后结果被下游阻塞；只有输入握手才累加。乘加次数K与bias决定溢出上界，不能因为用了INT32就认为任意卷积安全；冻结模型后检查`K*max_abs_product + abs(bias)`是否在界内或使用更宽内部累加。

下一卡先限定3×3、stride1、padding0、单输入单输出通道；生成明确小图逐元素对比。之后再按冻结模型逐项加stride/padding、多通道、bias、requant、activation；每加一项都保留前一项回归。INT8非对称量化需要减zero point，不能把原始INT8相乘当最终模型正确。

### 33.4 整机接入顺序和停止标准

1. 厂商DDR独立例程通过，保存实际板上日志；再接经验证的AXI前端/宽度转换/CDC，CPU不可缓存读写通过。
2. DMA仅在BRAM模型中通过后到DDR自检；先单主再与CPU争用，记录吞吐与最长等待，不以DDR芯片标称速率代替。
3. 预置单层输入/权重运行CPU+加速器，与电脑黄金数据逐元素比较；失败先查最早错误元素。
4. 预置一张图片完成全部模型，包括CPU回退算子与NMS；成功前不接实时相机。
5. OV5640彩条/固定帧校验后接双缓冲DMA，写响应结束才READY；整帧满/错时作废该帧；AI完成才释放PROCESSING帧。
6. 独立测试集报告检测精度和端到端时间；CPU-only基线使用同模型与量化。只做出卷积核不算完整YOLO移植，慢但正确的系统不谎称实时。

相机曝光、数据集、输入分辨率与帧丢弃都会影响演示结果，保存配置。HDMI是可选后续工作；选择只有摄像头与串口结果也要说明实际应用怎么使用检测结果，不能只有串口打印固定类别。

## 34. 写完后的复核、风险与使用边界

### 34.1 第二次检查清单

| 检查维度 | 本轮检查方法 | 不通过时怎么办 |
|---|---|---|
| 赛题覆盖 | 将B1-B3/H1-H3/E1-E6映射原任务和N任务，不把自选项写成强制 | 调整范围说明/补验收，不虚构分值 |
| 原代码锚点 | 对pc/slot/regs/ex/div/CSR/外设/runner查真实实现 | 修改方法必须服从当前源码，不套另一CPU |
| 接口一致性 | 核对复位极性、PC拥有者、字节lane、size/len、fault/retire、done保持 | 先改合同和两端任务，再开工 |
| 依赖可执行性 | 单元用替身模型，完整CPU另有T05-I门槛 | 不让前置任务依赖尚未创建的下游实现 |
| 文档代码 | Python语法解析、独立RTL模板编译/仿真（工具许可允许时） | 报出具体失败，不能把静态通过写成CPU通过 |
| 负向测试 | 临时样本故意破坏stall/握手规则，确认测试报错 | 检查测试有效性，恢复文档正确模板 |
| 未修改工程 | 对原目录所有文件排序聚合哈希，前后比较 | 若不同停止宣称未改并定位差异 |
| 决策边界 | DDR/YOLO/板卡/主办方信息仍需真实资料 | 在门槛前停，不能靠代码模板假装解决 |

### 34.2 本轮新增发现和修正

- 原div是持续start电平协议，已用adapter明确转换，避免直接一拍启动导致算法中止。
- 原EX用ALU/div结果按位OR合并；暂停重构后该假设不再成立，改为明确单一来源mux。
- 原`pc_reg`与新IFU都可能被理解为PC拥有者；现在规定pc_reg持有fetch_pc，IFU仅保存请求PC副本，retire_ctrl持有arch_next_pc。
- 原UART写寄存器路径可能延长tx_data_valid且软件写与硬件事件互斥；AXI化时明确一次发送事件，并测试同时发生的状态更新。
- 原测试脚本可能漏报编译失败/零用例；新增runner明确新编译、有效用例数、退出码和超时。
- 原程序默认开全局中断；基础T08a关闭中断配置必须同步修改启动程序，不能只口头说关闭。
- 加Cache后必须先清受害行valid再补行；代码失效须排空旧refill，防止旧内容重新标有效。

### 34.3 如何理解“详细且可跟做”

本计划提供可独立运行的小模块模板、逐文件修改卡、明确状态表、测试输入/期望值与命令。**不等于已有一份完整CPU替换补丁**：AXI整套互连、完整CSR环境、Cache及模型加速器仍按任务卡逐步实现，每步必须仿真；DDR/YOLO部分在事实冻结后还要针对真实端口/算子展开专属实现卡。遇到这些门槛时先补资料，不让小白猜参数继续写。

本轮复核结果已合并在第36章，以实际工具输出为准。没有运行的测试继续标为未运行；没有上板的设计绝不标为赛题已经达标。

**实际完成的文档模板复核：** Python runner语法解析通过；pipe_slot、div_adapter、稳定性检查器及两个测试台在ModelSim 10.6e编译通过；流水线槽测试与9例除法测试通过。临时副本植入stall清空错误后测试报Fatal，恢复后再次通过。并非完整CPU仿真或AXI/Cache认证；详细日志和边界见复核报告。

---

## 35. 历次评审意见与修订依据

评审日期：2026-10-09。范围：赛题选题一、本地tinyriscv源码、队长原计划。只修改计划，不改RTL、软件、测试脚本、工程约束或原始PDF。

### 35.1 结论

**原计划总体方向合理，基础要求映射基本正确，但不能按原稿直接当成已经闭合的实施合同。** 主要问题不是“用了错误的CPU”或“AXI不符合比赛”，而是若干协议条件未写清、软硬件配套缺项、验收顺序太靠后，以及项目规模尚未按队伍资源裁剪。

建议保留原生AXI4、有效位流水线、精确提交、两路I/D Cache、DDR先核验、逐步完成AI的主线。当时已修改原计划正文并保留原稿备份；本次合并后仅保留当前文档，历史备份不再单独保留。修订是供队伍确认的方案，不是批准开工，也不是硬件正确性认证。

### 35.2 本轮依据

- 赛题：`C:/Users/lenovo/Desktop/全国大学生嵌入式芯片与系统设计竞赛'2026FPGA赛道选题指南-紫光同创.pdf`，共17页；已提取并渲染目视核对PDF第10-11页（印刷页8-9）。
- PDF SHA256：`D4D7D389E22F88AC0D362072FC0C73711959816D374168692E102D25453D2CE6`。
- 评审对象为本文件的早期版本；下文“原稿行号”仅是当时评审定位，不对应当前正文行号。相关修改已整合到正文，保留这些位置用于解释问题来源。
- 历史原稿SHA256：`32D5D0B69CAB16CBA5542ED037B26EAAE197A8C7623556A4218A52AE7775C7B2`。原备份文件已在本次合并后移除。
- CPU根目录：`E:/donwload/tinyriscv-master/tinyriscv-master`。重点检查core、总线、存储、CSR、中断、仿真入口、启动/异常软件、CoreMark移植与链接脚本，并非穷尽所有RTL路径。
- DDR：重新读取原计划第17节指定的本地`DDR3_50H.v`生成文件，确认其端口不是可直接连接的完整AXI4从接口。
- 旧上下文是另一个YSYX工程；本轮没有把它的16寄存器问题套到tinyriscv。当前`rtl/core/defines.v:159-164`是5位地址、32个寄存器。

### 35.3 必须修改的问题

#### P1-01：写通道owner的描述可能导向死锁

**原稿位置：** 11.3节，原稿541-545行。前面要求呈现AWVALID时锁定grant，后面又说“写owner由AW接收确定”。二者若都指同一个owner而没有区分，实现者可能等AW握手后才放行W。

**反例：** 目标等待WVALID才拉AWREADY；互连等待AWREADY才转发WVALID，则两边永远等对方。CPU自身AW/W独立并不能修复互连内新增的依赖。

**修订：** grant/owner在选择AW请求并开始呈现时锁定；下游AW/W独立前进，不能用AW已完成门控WVALID。增加“目标等WVALID才给AWREADY”测试。错误读burst也必须排空至末拍，不能看见第一拍错误即释放owner。

这是原稿表达歧义及潜在实施风险，不是宣称现有tinyriscv的RIB发生该AXI死锁。

#### P1-02：全局单事务与流水线冻结缺少联合前进性条件

**原稿位置：** 3.1节全局单事务；8.2节EX等待时冻结年轻阶段；9节IFU等待返回；11.3节owner占用到响应结束。

**反例：** IF已经占住互连；EX执行load要申请总线；如果“冻结年轻阶段”也让IF的RREADY变低，那么IF等EX、EX等LSU、LSU等IF释放互连。

**修订：** 发AR前预留返回槽，接收R独立于流水线stall；Cache补行独立消化返回。增加IF占总线且EX等待LSU的交叉测试。禁止向MMIO发取指AR，避免错路取指带来UART读副作用。

#### P1-03：标准中断不能只改RTL与cause数字

**原稿位置：** T07，原稿568-602行，以及文件改造表。

**源码证据：** `rtl/core/clint.v:142`实际写入`0x80000004`；`tests/example/init.c:12-15`只设mtvec/mstatus，没有设mie；`trap_handler.c:4-10`将中断无条件交timer弱函数；`trap_entry.S:56-58`对所有同步异常直接加4。

**影响：** 修正硬件为标准mie/mip门控后，旧timer程序可能不再进中断；新增软件/外部中断若共用旧handler会错误分发；访问错误可能被静默跳过。

**修订：** 增加启动/异常软件文件清单、源映射与清除规则、mie设置、mcause分发、MRET/mstatus/mtvec合法化及回归。限定M模式并保留“赛事是否认可完整措辞需确认”，不擅自扩大为S/U/MMU要求。

#### P1-04：只在retire_fire检查异步中断不够明确

**原稿位置：** 8.2节和T07的“退休后/直到明确退休边界”。

**影响：** EX已经空闲、只有取指等待时可能长时间没有retire_fire；MRET或CSR写更新使能后如果使用旧值，则中断响应会错位。

**修订：** 独立维护arch_next_pc，在架构指令边界检查，包括EX空闲；MRET及相关CSR写后用更新状态检查。已发不可取消事务仍需安全收尾，不能以抢中断为由丢AXI事务。增补定向用例。

**交叉依据：** 本轮直接读取RISC-V官方源码`src/priv/machine.adoc`，其中`intr_mip_mie_bounded_time`与`intr_mip_mie_xret_csrwr`条款要求有界检查及xRET/相关CSR写后的立即重判；实施需冻结具体规范版本。

#### P1-05：CPU、Cache和AXI引擎的归属没有冻结

**原稿位置：** 0.1节、T03/T04的直接AXI FSM、T09的Cache补行。

**影响：** 后期加Cache时不清楚它接在操作接口还是AXI接口；容易重复发store、重复扩展load或重写IFU/LSU端口。

**修订：** 固定“CPU操作接口 -> Cache/旁路 -> 事务引擎”，明确每层职责与原PC/故障/结果返回合同。IFU/LSU是CPU内部原生AXI单元，不使用RIB桥。Cache前后复用事务引擎，T09不推翻EX与流水线接口。

#### P1-06：T02验收依赖尚未完成的T04/T05

**原稿位置：** T02要求真实延迟load-use与完整提交轨迹，但依赖顺序要求T02通过后才能开始T03/T04/T05。

**影响：** 严格照“未通过不得进入下一项”执行会卡在没有真实LSU/总线的阶段；放宽执行又容易把替身模型测试当成SoC已经通过。

**修订：** T02先用受控完成模型验流水线单元，IFU/LSU/互连分别测试，增加T05-I真实CPU集成门槛。明确哪些是单元通过、哪些是完整系统通过。

#### P1-07：来源/贡献和比赛允许范围尚无证据闭环

**原稿位置：** 1.1节仅一句“使用边界以通知为准”，T00未把来源核对作为显式关卡。

**源码证据：** 根目录README介绍开源tinyriscv，LICENSE及多份RTL含上游署名；没有可供本轮使用的Git历史来识别队友全部改动。

**修订：** 增加G0：上游版本/哈希、队友已有改动、本次新增、来源及许可材料、组织方关于复用边界的答复分别保存。

**边界：** 不能凭目录名判断队友没设计，也不能凭该选题PDF断言开源CPU禁止参赛。这里是需要确认的参赛风险，不是违规结论。

### 35.4 应修改的安排与验收

#### P2-01：首次PDS与CoreMark太靠后

原稿T08要求T00-T07全部通过；T13排在Cache和预测器之后。这样会很晚才暴露PDS/板卡、镜像容量或软件移植问题。

已加T00-P早期平台核验；T07拆基础ISA/同步异常与高阶中断；T08拆基础与中断上板；T13拆首次有效跑分、每次优化复测、最终报告。完整JTAG/在线下载可以后置且明确裁剪，不阻塞基础赛题。

保持原生AXI路线无需先实现RIB桥；原RIB仅作为独立参考基线可选，不混入最终工程。

#### P2-02：CoreMark已提规则，但软件落点和证据口径不够

- `lib/utils.c:11-12`是低后高各读一次，回绕时可能读出不一致64位时间。
- `include/utils.h:4-5`写死50MHz；`core_portme.c`还将缩放tick截成32位。
- 当前CoreMark Makefile仅配置PERFORMANCE_RUN；验证种子也需纳入计划。
- 原稿虽要求ILA波形，但未在前期明确必须抓CoreMark算法区间，而非任意测试程序。

已补具体文件、回绕测试、两套种子与CRC、内存map/size检查、真实频率与统计资源边界；不把源代码有64位cycle等同于计时移植自动正确。

#### P2-03：调试和DMA的Cache维护范围不完整

只失效I侧不足以保证debug改数据后CPU读到新内容。共享不可缓存缓冲也需覆盖描述符/张量并冻结具体范围，不只是口头称“图像缓冲不可缓存”。

已补halt后的D/I/BTB维护、无别名共享区、FENCE与编译器屏障、帧所有权。AI启动控制写必须及时返回B，不能等计算结束才返回，否则全局单事务互连会阻塞该AI自己发起的DMA。

#### P2-04：AI范围、吞吐预算和裁剪条件需更清楚

垃圾检测、OV5640、HDMI是队伍选择，不是选题一硬性指定。首版全局单事务可用于验证正确性，但不能因此承诺视频实时性能。

已补CPU回退算子时间、实际持续带宽、相机/特征图/权重流量及单帧优先验收；AI关卡失败不推翻已有CPU成果，也不能把单卷积/CNN样例当作YOLO系统完成。

### 35.5 原计划正确且保留的部分

1. RV32I、不少于三级、冲突与分支、UART/GPIO的基础要求映射正确。
2. 两路I-Cache和两路D-Cache均需实现才能声称完成H1；写直达D-Cache不因没有写回就自动不符合“两路”要求。
3. 原计划已经知道AXI4并非赛题强制，也区分原生AXI与RIB桥；本轮没有把这点误报为原稿缺失。
4. 以valid区分气泡与指令，stall不能套用旧gen_pipe_dff清空语义，这个判断有源码支撑。
5. store等B、错误路径取指排空、窄写WSTRB、不可缓存MMIO、DDR接口先核验，均值得保留。
6. 当前tinyriscv是32寄存器，不需要套用另一个YSYX项目的16改32任务。
7. `tb/tinyriscv_soc_tb.v:57`已有TEST_PASS；原稿这一条件没有错。仍需同时检查TEST_FAIL、Time Out、编译失败及用例数。
8. 本地DDR示例确实缺少标准完整写响应/读回压端口；不能仅因信号名含axi直接接入。
9. 没有证据证明“必须五级”“必须写回Cache”“必须HDMI”或“必须实现S/U/MMU”；不把这些个人偏好写成赛题要求。

### 35.6 队伍需确认的决策

- 比赛实际允许的开源复用/已有成果范围，以及你们可说明的新贡献。
- 原生AXI作为最终目标是否仍坚持；本轮保留，没有擅自改成桥接路线。
- “不要RIB桥”是否允许DDR用户口前端、位宽转换与CDC。建议允许后者，但未代替队伍批准。
- 开发人力、真实可用周数与高阶目标档位。建议先基础闭环，再CPU高阶，再完整AI。
- M-only异常/中断范围是否满足主办方“完整”措辞；是否采用OV5640垃圾检测这项应用选择。

这些未确认项不妨碍阅读和原工程基线核验，但阻止承诺最终全高阶交付。

### 35.7 本轮验证边界

- 已完成：原计划全文审阅、选题一PDF文本与页面目视核对、关键RTL/软件静态核对、本地DDR端口复核、修订计划并保留备份。
- 未完成且未声称：CPU仿真、ISA符合性认证、综合/时序、实际CoreMark成绩、板卡连通性、完整上游差异核对、主办方答复。
- 内置网页搜索没有返回可用结果。通过直接HTTPS读取EEMBC官方CoreMark README及RISC-V官方规范源码作技术交叉核验；Arm在线页面请求失败。正式实施仍需保存冻结规范版本及协议检查证据。
- EEMBC引用定位：官方`eembc/coremark`仓库`README.md`的Run Rules/Required；RISC-V引用定位：官方`riscv/riscv-isa-manual`仓库`src/priv/machine.adoc`的上述norm标签。没有用这些资料代替赛事新通知。
- 源码修改前对243个RTL/软件/脚本/约束及Makefile文件计算聚合SHA256：`36c585d202a440d0f3639b56929953e7bbac1557de2773b16ca5f78dea90edec`。按相对路径排序，每个文件纳入UTF-8路径及内容SHA256；交付前重新核对。

**最终定位：** 这是一份经过第二轮审阅的可讨论、可分阶段细化计划，不是“照抄即可编译”的完整补丁。正文保留T00、T01至T13任务编号以方便对照；细分任务用后缀表示，未执行项继续保持未勾选。

---

## 36. 扩充计划复核报告

日期：2026-10-09。对象：本文件第三轮扩充稿。以下是当时实际复核结果，现归入本合并文档；本次合并没有重新运行CPU仿真或硬件验证。

### 36.1 结论

**已在原计划上新增第25-34章，并完成文档一致性复核和部分独立模板的实际编译/仿真。** 计划可以作为分阶段学习与实施指南；不是完整CPU替换补丁，不代表全部总线/Cache/异常/AI方案已经通过测试，也不保证初学者无需任何调试即可完成。

保留原生AXI4、三级流水线与队友现有算术/译码基础，未擅自改为五级、桥接或全新CPU。没有改动原CPU工程；独立模板检查在临时目录完成，旧div.v只作为只读仿真输入。

### 36.2 本轮新增内容

| 章节 | 内容 | 新手可执行的交付 |
|---|---|---|
| 25 | ISA/流水线/AXI/Cache/retire/trap术语和语法 | 先语法、再原代码、再人话、再指令验证 |
| 26 | 功能建议与N00-N17任务卡映射 | 分清必做、推荐与后置，不混成赛事强制 |
| 27 | 副本与基线、源文件清单、ModelSim runner | 完整28文件清单、Python入口、退出码/日志/超时检查 |
| 28 | 流水线、退休门控、译码、除法 | pipe_slot和div_adapter完整模板及完整单元测试台 |
| 29 | 读写引擎、IFU/LSU、RAM/GPIO/UART、互连 | 明确状态表、信号位宽、逐文件修改卡、反例与期望值 |
| 30 | 异常、中断、启动软件、64位计时 | CSR更新次序、C/汇编衔接、具体软件替换函数 |
| 31 | 两路Cache和预测器 | 同组A/B/C地址、LRU、补行错误、BTB训练与测试 |
| 32 | 性能快照和GPIO采集/控制 | 固定寄存器表、事件定义、采样边界和公平性能对比 |
| 33 | DDR/DMA/AI分阶段方法 | DMA切块、双边4KiB边界、MAC黄金值、模型/IP资料关卡 |
| 34 | 写后复核与使用边界 | 不能把模板通过、软件模拟或文档完成当成上板达标 |

新增功能建议优先级：退休轨迹/错误诊断优先；性能快照和简单GPIO应用推荐；Cache/预测器按高阶目标开展；更多AXI并发、宽DMA、HDMI后置；不建议此阶段增加操作系统、自定义指令或同时五级重构。

### 36.3 写后发现并修正的问题

#### R1：原除法器不能用单周期start直接驱动

源码`rtl/core/div.v`在START、CALC、END反复检查start_i，为0时回到IDLE。原计划的“一次启动”容易被误读为打一拍脉冲。

修订为CPU请求仅握手一次，adapter持续拉start直到旧div输出ready；ready出现后组合压低start防止回到IDLE再启动；结果在独立槽保持到EX消费。已用实际旧div进行9例验证。

#### R2：ModelSim日志检查会误杀正常结果

初稿27.4使用`Fatal|Error`泛匹配，`Errors: 0`也会匹配，导致全部正常测试失败。

改为检测`TEST_FAIL|TIMEOUT|\*\*\s*(Error|Fatal)`，同时必须出现预期TEST_PASS。已验证正常摘要、有Fatal、无PASS、Time Out四种文本。

#### R3：ModelSim onerror的调用位置不对

首次独立仿真发现内联`-do`命令中的onerror/onbreak提示仅供macro使用。调整正式Python runner为先生成run.do再调用；移除会误处理正常finish的多余onbreak。最终独立仿真用run.do执行成功。

负向测试还证实：仿真出现Fatal后显式quit 0可能仍返回进程码0，因此必须检查日志，不能只看退出码。

#### R4：旧第6节和新增第27节的文件清单路径可能冲突

旧说明以sim目录为工作目录，新完整manifest以工程根目录为基准。已将第27节指定为唯一正式入口，第6节Tcl/旧镜像命令标为解释性参考，避免小白混用路径。

#### R5：多处结构归属容易重复驱动

明确pc_reg持有fetch_pc，IFU只保存请求副本，retire_ctrl持有arch_next_pc；EX候选结果由mux选择，不再用旧ALU/div输出按位OR。redirect只清年轻槽，当前EX不因自己的redirect组合失去valid。

#### R6：Cache/DMA/外设边界补充

明确Cache受害way先invalid、错误补行排空、代码失效不允许旧refill重标valid；DMA同时按源和目标4KiB边界切块；UART TX忙写返回错误且驱动先轮询，不能响应成功却静默丢字。

这些是静态设计方法与验证要求，不应解释为上述全部模块已实现并通过仿真。

### 36.4 实际执行的验证

验证目录：

`C:/Users/lenovo/.codex/visualizations/2026/10/09/01a120d3-e77d-7f41-8276-50b3f6de10ec/plan-template-check-xqumv49l`

从计划中提取完整模板到该目录，没有写入CPU源码目录。

| 检查 | 实际结果 | 证据/限制 |
|---|---|---|
| ModelSim版本 | vlog 10.6e可运行 | 非PDS验证 |
| 模板编译 | 0 Errors / 0 Warnings | pipe_slot、div_adapter、checker、两个TB及只读原div |
| 流水线槽 | TEST_PASS N02，196ns | final_pipe.log |
| 除法适配 | TEST_PASS N03_DIV，3716ns | final_div.log，9例 |
| stall错误注入 | Fatal: stall lost A，76ns | negative_stall.log，无PASS；证明该测试能抓此缺陷 |
| 恢复正确模板 | 流水线和除法再次通过 | 临时样本与文档模块逐字比较一致 |
| Python runner | AST语法解析通过 | 未对整套CPU实际执行；不能声称47例已过 |
| 日志判断 | 四种文本判定通过 | 通过摘要、Fatal、无PASS、Time Out |
| manifest | 28个路径均存在 | include清单不等同于完整SoC实际编译结果 |
| 文档结构 | 代码围栏配对，25-34章节齐全，无替换字符 | 文档静态检查 |
| 文件保护 | 原工程全部790文件聚合哈希一致 | 见36.5节 |

除法9例：20/3、-20/3、-20%3、无符号0xFFFFFFFF/2、无符号余数、除0、除0取余、有符号最小值/-1及相应余数；每例额外保持rsp_ready低7拍检查结果保持并检查无重复完成。这不是对所有2^64输入穷尽验证。

稳定性检查器只完成编译，没有独立运行完整AXI通道测试；AXI、Cache、CSR、完整CPU、CoreMark均仍需按任务卡实现和验证。

### 36.5 文件变更与保护证据

- 第三轮扩充前快照曾单独备份；本次按只保留一份文档的要求移除，保留下列历史哈希记录。
- 历史快照SHA256：`3845B8E50861FE0D2BA8C7EA0D199022E9CDBF132FFDE91F80B78205439227A4`，交付前已复核。
- 原工程范围：`E:/donwload/tinyriscv-master/tinyriscv-master`全部790个文件，按相对路径排序，聚合UTF-8路径及各文件内容SHA256。
- 修改前后聚合SHA256相同：`3637ff3566893e3c653c6828375b68388a4b61b624e2ae8743f8d295b4ea798b`。
- 新实现副本`E:/file/pango/tinyriscv_axi4`没有由本轮创建；项目实际实施任务未被勾选为完成。

### 36.6 仍需确认或实测的内容

1. 开源复用与队伍贡献边界、板卡实际型号、PDS实现与主办方认可范围。
2. 完整基线47例、软件工具链/ISA/ABI、CoreMark两个种子及真实>=10秒运行。
3. AXI读写/互连/从设备实现、随机回压、CPU集成、CSR/异常精确性与Cache/预测器回归。
4. DDR IP用户口真实契约、数据宽度/CDC/写完成、板上校准；不能凭模板确认可连。
5. 具体YOLO图/权重/量化、资源/带宽预算、独立数据集精度和完整单帧软硬协同。

本轮内置网络检索未返回可用结果，未据此宣称获得新的赛事规则或最新协议版本。赛题依据沿用本聊天已核对的用户PDF第10-11页；技术细节实施时仍需冻结规范版本。复核是本轮自查和工具检查，没有声称另一个独立审查代理已经审批。

### 36.7 第四轮并发控制复核

本轮针对“取指内部接单窗口、FENCE.I年轻指令、halt当前EX请求”重新反向审查。结论不是因为提出者身份而采纳，而是逐项按握手所有权、精确架构状态和可终止性判断：

1. **取指建议成立，按P1处理。** 原规则若只从ARVALID/AR握手开始标旧请求，会漏掉内部`req_fire`到外部AR之间的窗口；redirect与`req_fire`同拍也可能因寄存器旧值漏标。计划现规定所有权从内部握手开始，并补四个相位及连续redirect测试。
2. **FENCE.I建议成立，但带ISA边界。** 若声明Zifencei，只清I-Cache而不清IF/ID、预取和在途补行，旧代码仍可能执行；因此采用独立维护流程并从FENCE.I PC+4重取。若不准备完整实现，则必须非法指令并从工具链移除Zifencei，不能半支持。自修改代码测试只在明确可写且可执行RAM中有效。
3. **halt建议成立，项目优先级可记P2，但T06内部是阻断项。** 若halt禁止当前EX尚未发出的必要load/store/div请求，会形成halt等待完成、操作等待许可的死锁。计划现用`halt_pending`只封锁年轻工作，让当前EX恰好启动一次并完成；异常和真实redirect先形成正确`arch_next_pc`再停。
4. **一致性复核结果。** 前文T03、T06、T07、N02/N04任务卡和停止条件已经统一为“已接受事务必须协议收尾，结果按有效性提交或丢弃”；未再发现与这三条规则直接矛盾的旧描述。

本节仍是静态设计复核，不代表故障已在真实CPU复现，也不代表修订后的RTL已经仿真通过。实施时必须用本节列出的定向测试证明规则落地。

**交付状态：** 文档扩充与上述验证完成；仍停在计划阶段。下一步先由队伍确认G0与功能范围，获准后按N00/N01开始真实工程基线，不直接把所有模板一次性并入CPU。
