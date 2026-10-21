# rv32 核模块合同（D1）——重写版，5.2 @126 MHz

依据：`docs/plan-score-5.2-120mhz-v2.md` §3/§4。
**规则**：本文件的 11 个字段缺一项，该模块不得进 RTL；改完必须回写本文与
`area-budget.csv`。一次提交只改一个模块。

## 0. 共同约定

| 项 | 约定 |
|---|---|
| 时钟/复位 | 单 `clk`（core_clk，126 MHz）/ 同步低有效 `rst_n`；无跨域总线 |
| 编码 | Verilog-2001 可综合子集；`always @(posedge clk)` + 同步复位，不用异步复位（`mistakes-log` §10.5：异步复位在宽流水上压垮 hold） |
| 冲刷 | **epoch**：全局 2 bit 递增，各级 `valid = valid_q && (epoch_q == epoch)`；禁止全局 flush 扇出到所有 FF |
| 复位值 | 只复位 `valid`/`epoch`/控制小状态；**数据阵列不复位**（§16：逐项复位会把 RAM 逼成触发器） |
| 面积预算 | 相对 E2（17,534 LUT / 7,153 FF / 3,684 LUTRAM / 4 DRM）的**增量**，未测量前一律标"预算" |
| 物理区域 | `R_CORE`（控制/ALU/寄存器堆）、`R_FETCH`（IFU/I-Cache）、`R_MEM`（LSU/D-Cache）、`R_IO`（AXI/外设） |

## 1. `rv32_top`

| 字段 | 内容 |
|---|---|
| 名称/文件 | `rv32_top` / `rtl/core/rv32/rv32_top.v` |
| 流水级 | 全核顶层，S1–S7 |
| 职责 | 与 `pangoriscv` **端口完全一致**的替换核：接 `ifu_axi`、`lsu_axi`/`dcache_axi`、CSR、halt/trap |
| 时钟复位 | `clk` / `rst_n` |
| 接口 | 同 `pangoriscv`（fetch 侧、LSU 侧、retire 探针、trap、debug、predict chain） |
| 内部状态 | `epoch`、`halted`/`halt_pending`、`retire_order` |
| 存储资源 | 无阵列（阵列在各子模块） |
| 面积预算 | 1,200 LUT / 700 FF（顶层胶合 + 级间 payload） |
| 关键路径 | 只做级间寄存，不允许出现"跨两级"的组合逻辑 |
| 测试 | `tb_isa_e2e` 21 例、`tb_coremark_uart` 五项 CRC |
| 变更记录 | 新建 |

## 2. `rv32_decode`

| 字段 | 内容 |
|---|---|
| 名称/文件 | `rv32_decode` / `rtl/core/rv32/rv32_decode.v`（例化两次：slot0/slot1） |
| 流水级 | S1 组合，输出在 S1→S2 寄存 |
| 职责 | RV32IM 全译码：ALU op、分支类型、访存 size/sign、写回源、CSR 意图、非法指令、真实源寄存器使用位 |
| 时钟复位 | 纯组合（无状态） |
| 接口 | in：`inst[31:0]`；out：控制 bundle（op/alu_op/imm/rs1/rs2/rd/we/mem/csr/branch/jump/illegal/uses_rs1/uses_rs2） |
| 内部状态 | 无 |
| 存储资源 | 无 |
| 面积预算 | 2×250 LUT |
| 关键路径 | ≤8 级（opcode/funct 分组 → 控制位） |
| 测试 | `tb_unit_decode`（全指令编码扫描，对照黄金表） |
| 变更记录 | 新建；`uses_rs*` 必须按真实源（`lui/auipc` 不读 rs1；`addi` 的立即数不得当 rs2） |

## 3. `rv32_regfile`

| 字段 | 内容 |
|---|---|
| 名称/文件 | `rv32_regfile` / `rtl/core/rv32/rv32_regfile.v` |
| 流水级 | S2 读、S7 写 |
| 职责 | 4 读口（两槽各 rs1/rs2）1 写口 + **1 项写队列**（两槽同拍写不同寄存器时年轻槽入队下一拍） |
| 时钟复位 | `clk`/`rst_n`；x0 恒 0 |
| 接口 | `ra0..ra3`/`rd0..rd3`；`we0/wa0/wd0`、`we1/wa1/wd1`（写队列出口） |
| 内部状态 | 写队列 1 项（addr/data/valid） |
| 存储资源 | 4 份 32×32 LUTRAM（每读口一份）+ 32 FF 队列 |
| 面积预算 | 64 LUTRAM / 40 FF |
| 关键路径 | 读口 ≤2 级（LUTRAM 同步读 + 输出寄存） |
| 测试 | `tb_unit_regfile`：4 口并发、x0、同址双写优先级、队列溢出 |
| 变更记录 | 新建（替换 `regs.v` 的 2R2W 结构） |

## 4. `rv32_alu`

| 字段 | 内容 |
|---|---|
| 名称/文件 | `rv32_alu` / `rtl/core/rv32/rv32_alu.v`（例化两次，两槽并行） |
| 流水级 | S3 组合 |
| 职责 | add/sub/logic/shift/比较/lui/auipc；**不含乘法** |
| 时钟复位 | 纯组合 |
| 接口 | `op`、`a`、`b` → `y`、`cmp_lt/cmp_ltu`、`eq` |
| 内部状态 | 无 |
| 存储资源 | 无 |
| 面积预算 | 2×180 LUT |
| 关键路径 | ≤8 级；桶形移位单独一路，不与加法串联 |
| 测试 | `tb_unit_alu`（全 op 与边界值） |
| 变更记录 | 新建（旧 `ex_alu` 把 ID 选择塞进 ALU，路径过长） |

## 5. `rv32_mul`

| 字段 | 内容 |
|---|---|
| 名称/文件 | `rv32_mul` / `rtl/core/rv32/rv32_mul.v` |
| 流水级 | S3 输入寄存 → S4/S5（DSP 两级）→ 结果在 M2 可用 |
| 职责 | MUL/MULH/MULHSU/MULHU；符号扩展在输入侧一次完成 |
| 时钟复位 | `clk`/`rst_n` |
| 接口 | `req/ack`、`a/b/op` → `valid/result` |
| 内部状态 | 2 级有效位 |
| 存储资源 | 无（APM 由工具推断，目标 ≤4 个） |
| 面积预算 | 0 LUT / 70 FF |
| 关键路径 | 输入寄存 → APM → 输出寄存，禁止组合出乘法器 |
| 测试 | `tb_unit_mul`（含 ±1、INT_MIN 边界） |
| 变更记录 | 新建；旧路径 6.3 ns/4 个 APM 串接是 27 MHz 的关键路径首因 |

## 6. `rv32_hazard`

| 字段 | 内容 |
|---|---|
| 名称/文件 | `rv32_hazard` / `rtl/core/rv32/rv32_hazard.v` |
| 流水级 | S1 组合 |
| 职责 | 配对合法性（两槽可同发）、RAW/load-use 判定、CSR/系统指令串行化、停顿与冲刷请求 |
| 时钟复位 | 纯组合 |
| 接口 | 两槽控制 bundle + 在途目的寄存器/就绪位 → `stall_id`、`pair_ok`、`serial_wait` |
| 内部状态 | 无（在途状态由各级 valid+控制寄存器提供） |
| 存储资源 | 无 |
| 面积预算 | 250 LUT |
| 关键路径 | ≤6 级；**不得**把 LSU 完成信号串进来（§M 系列教训：会形成"地址→fault→前递→地址"反馈） |
| 测试 | 定向：同包 RAW、跨包 RAW、load-use、CSR、两槽同写 |
| 变更记录 | 新建；规则：lane1 不得依赖 lane0 结果（否则一拍串两个 ALU） |

## 7. `rv32_csr`

| 字段 | 内容 |
|---|---|
| 名称/文件 | `rv32_csr` / `rtl/core/rv32/rv32_csr.v` |
| 流水级 | 读在 S1（组合），写在 S7 提交 |
| 职责 | mstatus/mepc/mcause/mtval/mtvec/mie/mip/mcycle/minstret/mhpmcounter*；trap 进入、MRET、计数器 |
| 时钟复位 | `clk`/`rst_n` |
| 接口 | `addr/rdata/wdata/we/commit`、`trap_enter/trap_pc/cause/tval`、`mret`、`retire/retire_count` |
| 内部状态 | 约 12 个 32 bit 寄存器 |
| 存储资源 | 384 FF |
| 面积预算 | 120 LUT / 400 FF |
| 关键路径 | 读口 ≤4 级（地址译码 → 32:1 mux） |
| 测试 | ISA case 6/7/8/9/15 + 计数器不回绕 |
| 变更记录 | 新建（旧 `csr_native` 与 `ex.v` 存在两套事实来源，§R13） |

## 8. `rv32_commit`

| 字段 | 内容 |
|---|---|
| 名称/文件 | `rv32_commit` / `rtl/core/rv32/rv32_commit.v` |
| 流水级 | S7 |
| 职责 | 按序架构提交：寄存器写、CSR 写、重定向、预测训练、trap/MRET；异常只在这里生效 |
| 时钟复位 | `clk`/`rst_n` |
| 接口 | 来自 S6 的整包 payload → 写回/重定向/训练/trap 请求 |
| 内部状态 | `retire_order`、`arch_next_pc`、`epoch` 递增 |
| 存储资源 | 无 |
| 面积预算 | 300 LUT / 250 FF |
| 关键路径 | ≤6 级；**不得**把"完成判定"放在这里（W 级只提交，不判断完成 —— `exp/w-boundary-gpt6` 的教训：让 W 参与完成会慢 52.6%） |
| 测试 | 精确异常（读/写 fault、非对齐、非法）、trap 后 `mepc` 正确、错误路径不退休 |
| 变更记录 | 新建 |

## 9. 面积预算汇总（相对 E2，全部为预算不是测量）

| 模块 | ΔLUT | ΔFF | ΔLUTRAM | 备注 |
|---|---:|---:|---:|---|
| `rv32_top` | +1,200 | +700 | 0 | 级间 payload |
| `rv32_decode` ×2 | +500 | 0 | 0 | |
| `rv32_regfile` | +100 | +40 | +64 | 替换 `regs` |
| `rv32_alu` ×2 | +360 | 0 | 0 | 替换 `ex_alu` |
| `rv32_mul` | 0 | +70 | 0 | |
| `rv32_hazard` | +250 | 0 | 0 | |
| `rv32_csr` | +120 | +400 | 0 | |
| `rv32_commit` | +300 | +250 | 0 | |
| **合计** | **+2,830** | **+1,460** | **+64** | |

同时预期**回收**：旧 `pangoriscv` 控制层（约 2,894 LUT）、`ex_alu`/`id_alu`/`id_ex`/`pipe_slot`
（约 1,500 LUT）、数据 RAM 从 LUTRAM 转 BRAM（−2,048 LUTRAM 站点）。
净面积目标：**LUT 不增、LUTRAM 明显下降**，以满足 `Δ(LUT+FF+LUTRAM) ≤ 0` 的门禁。
若净增为正，必须先在本文件与 `area-budget.csv` 登记理由再动 RTL。
