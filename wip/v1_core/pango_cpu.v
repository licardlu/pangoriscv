// -----------------------------------------------------------------------------
// pango_cpu.v -- 复现核顶层 (V1: 单通道 RV32IMC + Zicsr + Zifencei)
//
// 流水级 (与参考 lane0 的 ctrl 节点对应关系见 docs/architecture/reference-pipeline.md):
//   IF   : pc -> 64 位取指块 -> 对齐器切出指令
//   ID   : 译码 + 同步读寄存器堆
//   EX   : 前递选择 + early ALU / 移位 / 分支 / 乘除启动 + 例外检测 + 发载入地址
//   MEM  : 数据存储器收回数据 + 精确例外落点 + store 提交
//   WB   : 寄存器写回 + CSR 写
//
// 两条不同的停顿路径 (不能合并, 合并会死锁):
//   freeze     : 乘除多周期 / 存储器未 ready。所有流水寄存器一起冻结, 写回被门控,
//                不会重复提交。
//   hold_front : load-use 相关。只挡住 pc 与 IF/ID, 让 Load 正常进入 MEM,
//                同时把 ID/EX 清成气泡, 避免同一条 Load 被复制进 MEM。
//
// 重定向优先级 (年龄越老越优先): MEM 例外 > EX 分支/mret > IF 中断。
// -----------------------------------------------------------------------------
`include "core_config.vh"
`include "core_defs.vh"

module pango_cpu (
    input  wire        clk,
    input  wire        rst,

    // ------------------------------ 取指侧 -----------------------------------
    output wire [31:0] imem_addr,
    output wire        imem_req,
    input  wire        imem_ready,
    input  wire        imem_rvalid,
    input  wire [31:0] imem_rdata,

    // ------------------------------ 数据侧 -----------------------------------
    output wire [31:0] dmem_raddr,
    output wire        dmem_ren,
    input  wire [31:0] dmem_rdata,
    output wire [31:0] dmem_waddr,
    output wire        dmem_wen,
    output wire [3:0]  dmem_be,
    output wire [31:0] dmem_wdata,
    input  wire        dmem_ready,
    input  wire        dmem_err,

    // ------------------------------ 中断 -------------------------------------
    input  wire        irq_timer,
    input  wire        irq_ext,
    input  wire        irq_soft,

    // ------------------------------ 退休追踪 ---------------------------------
    output wire        commit_valid,
    output wire [31:0] commit_pc,
    output wire [31:0] commit_instr
);
    // =========================================================================
    // 取指 / 对齐
    // =========================================================================
    reg  [31:0] pc;

    // 流水线全局控制 (提前声明: 对齐器要用)
    wire freeze;
    wire hold_front;

    wire [31:0] al_instr, al_instr_raw;
    wire        al_rvc, al_illegal, al_valid;

    wire        any_redirect;
    wire [31:0] redirect_pc;

    wire [31:0] pc_plus_len = pc + (al_rvc ? 32'd2 : 32'd4);

    core_instruction_aligner u_aligner (
        .clk          (clk),
        .rst          (rst),
        .pc           (pc),
        .consume      (al_valid & ~freeze & ~hold_front),
        .pc_next      (pc_plus_len),
        .redirect     (any_redirect),
        .redirect_pc  (redirect_pc),
        .instr32      (al_instr),
        .instr_raw    (al_instr_raw),
        .instr_rvc    (al_rvc),
        .instr_illegal(al_illegal),
        .valid        (al_valid),
        .mem_addr     (imem_addr),
        .mem_req      (imem_req),
        .mem_ready    (imem_ready),
        .mem_rvalid   (imem_rvalid),
        .mem_rdata    (imem_rdata)
    );

    // =========================================================================
    // IF/ID
    // =========================================================================
    reg        if_id_valid;
    reg [31:0] if_id_pc;
    reg [31:0] if_id_instr;
    reg [31:0] if_id_instr_raw;
    reg        if_id_rvc;
    reg        if_id_illegal;

    // =========================================================================
    // 译码 (作用在 IF/ID 上的组合逻辑)
    // =========================================================================
    wire [4:0]  d_rd, d_rs1, d_rs2;
    wire        d_rd_we, d_rs1_use, d_rs2_use;
    wire [31:0] d_imm;
    wire [1:0]  d_src1_sel, d_src2_sel, d_alu_bitwise;
    wire        d_alu_addsub, d_alu_revert, d_alu_sltx, d_alu_unsigned, d_alu_zero_src2;
    wire        d_is_shift;
    wire [1:0]  d_shift_mode, d_wb_sel;
    wire        d_mem_read, d_mem_write, d_mem_unsigned;
    wire [1:0]  d_mem_size;
    wire        d_is_branch, d_is_jal, d_is_jalr;
    wire [2:0]  d_funct3;
    wire        d_is_mdu;
    wire [2:0]  d_mdu_op;
    wire [1:0]  d_csr_op;
    wire [11:0] d_csr_addr;
    wire        d_csr_use_imm;
    wire        d_is_ecall, d_is_ebreak, d_is_mret, d_is_fence, d_is_fence_i;
    wire        d_illegal;

    core_decoder u_decoder (
        .instr        (if_id_instr),
        .rvc_illegal  (if_id_illegal),
        .illegal      (d_illegal),
        .rd           (d_rd),
        .rs1          (d_rs1),
        .rs2          (d_rs2),
        .rd_we        (d_rd_we),
        .rs1_use      (d_rs1_use),
        .rs2_use      (d_rs2_use),
        .imm          (d_imm),
        .src1_sel     (d_src1_sel),
        .src2_sel     (d_src2_sel),
        .alu_bitwise  (d_alu_bitwise),
        .alu_addsub   (d_alu_addsub),
        .alu_revert   (d_alu_revert),
        .alu_sltx     (d_alu_sltx),
        .alu_unsigned (d_alu_unsigned),
        .alu_zero_src2(d_alu_zero_src2),
        .is_shift     (d_is_shift),
        .shift_mode   (d_shift_mode),
        .wb_sel       (d_wb_sel),
        .mem_read     (d_mem_read),
        .mem_write    (d_mem_write),
        .mem_size     (d_mem_size),
        .mem_unsigned (d_mem_unsigned),
        .is_branch    (d_is_branch),
        .is_jal       (d_is_jal),
        .is_jalr      (d_is_jalr),
        .funct3       (d_funct3),
        .is_mdu       (d_is_mdu),
        .mdu_op       (d_mdu_op),
        .csr_op       (d_csr_op),
        .csr_addr     (d_csr_addr),
        .csr_use_imm  (d_csr_use_imm),
        .is_ecall     (d_is_ecall),
        .is_ebreak    (d_is_ebreak),
        .is_mret      (d_is_mret),
        .is_fence     (d_is_fence),
        .is_fence_i   (d_is_fence_i)
    );

    // =========================================================================
    // ID/EX
    // =========================================================================
    reg        idex_valid;
    reg [31:0] idex_pc;
    reg [31:0] idex_instr_raw;
    reg [4:0]  idex_rs1, idex_rs2, idex_rd;
    reg        idex_rd_we;
    reg [31:0] idex_imm;
    reg [1:0]  idex_src1_sel, idex_src2_sel, idex_alu_bitwise;
    reg        idex_alu_addsub, idex_alu_revert, idex_alu_sltx;
    reg        idex_alu_unsigned, idex_alu_zero_src2;
    reg        idex_is_shift;
    reg [1:0]  idex_shift_mode, idex_wb_sel;
    reg        idex_mem_read, idex_mem_write, idex_mem_unsigned;
    reg [1:0]  idex_mem_size;
    reg        idex_is_branch, idex_is_jal, idex_is_jalr;
    reg [2:0]  idex_funct3;
    reg        idex_is_mdu;
    reg [2:0]  idex_mdu_op;
    reg [1:0]  idex_csr_op;
    reg [11:0] idex_csr_addr;
    reg        idex_csr_use_imm;
    reg [4:0]  idex_csr_zimm;
    reg        idex_is_ecall, idex_is_ebreak, idex_is_mret;
    reg        idex_illegal;
    reg        idex_rvc;

    // =========================================================================
    // EX/MEM
    // =========================================================================
    reg        exmem_valid;
    reg [31:0] exmem_pc;
    reg [31:0] exmem_instr_raw;
    reg [31:0] exmem_result;
    reg [31:0] exmem_wb_data;      // EX 级就能确定的写回值 (CSR/PC4/ALU)
    reg [31:0] exmem_store_data;
    reg [4:0]  exmem_rd;
    reg        exmem_rd_we;
    reg [1:0]  exmem_wb_sel;
    reg        exmem_mem_read, exmem_mem_write, exmem_mem_unsigned;
    reg [1:0]  exmem_mem_size;
    reg        exmem_exc_valid;
    reg [31:0] exmem_exc_cause, exmem_exc_tval;
    reg [31:0] exmem_csr_rdata;
    reg        exmem_csr_we;
    reg [11:0] exmem_csr_addr;
    reg [31:0] exmem_csr_wdata;
    reg        exmem_rvc;

    // =========================================================================
    // MEM/WB
    // =========================================================================
    reg        memwb_valid;
    reg [31:0] memwb_pc;
    reg [31:0] memwb_instr_raw;
    reg [31:0] memwb_data;
    reg [4:0]  memwb_rd;
    reg        memwb_rd_we;
    reg        memwb_csr_we;

    // 载入数据必须在进入 MEM 的第一拍无条件锁存。
    // 原因: 同步 RAM 的 dmem_rdata 只在"地址发出后的那一拍"有效。若这一拍之后
    // 流水线被多周期单元冻结 (除法 34 拍), dmem_raddr 会被 EX 级的新操作数覆盖,
    // dmem_rdata 就不再属于这条 Load, 数据永久丢失 —— 表现为 printf 的数字变成
    // 0 或乱码 (实测 `sb a5` 存进了 0)。
    reg [11:0] memwb_csr_addr;
    reg [31:0] memwb_csr_wdata;
    reg        exmem_aged;       // 1 = 当前 EX/MEM 里的指令已在 MEM 停过不止一拍
    reg [31:0] load_q;           // 载入数据锁存

    // =========================================================================
    // 寄存器堆
    // =========================================================================
    wire [31:0] rf_rd1, rf_rd2;
    wire        wb_commit = memwb_valid & ~freeze;

    core_regfile u_regfile (
        .clk (clk), .rst (rst),
        .ra1 (d_rs1), .ra2 (d_rs2),
        .rd1 (rf_rd1), .rd2 (rf_rd2),
        .we0 (wb_commit & memwb_rd_we), .wa0 (memwb_rd), .wd0 (memwb_data),
        .we1 (1'b0), .wa1 (5'd0), .wd1 (32'd0)
    );

    // =========================================================================
    // 前递选择
    // =========================================================================
    // 前递使能只看"写回数据有效", 不能看 wb_commit:
    // 多周期单元冻结流水线时 WB 也被冻结, 若前递跟着关掉, 紧接的指令会拿到旧值。
    wire        memwb_fwd_en = memwb_valid & memwb_rd_we;
    wire        exmem_fwd_en = exmem_valid & exmem_rd_we & ~exmem_mem_read & ~exmem_exc_valid;
    wire [31:0] ex_rs1, ex_rs2;

    core_operand_select u_sel1 (
        .rf_data  (rf_rd1), .rf_addr (idex_rs1),
        .exmem_we (exmem_fwd_en), .exmem_rd (exmem_rd), .exmem_data (exmem_wb_data),
        .memwb_we (memwb_fwd_en), .memwb_rd (memwb_rd), .memwb_data (memwb_data),
        .data     (ex_rs1)
    );
    core_operand_select u_sel2 (
        .rf_data  (rf_rd2), .rf_addr (idex_rs2),
        .exmem_we (exmem_fwd_en), .exmem_rd (exmem_rd), .exmem_data (exmem_wb_data),
        .memwb_we (memwb_fwd_en), .memwb_rd (memwb_rd), .memwb_data (memwb_data),
        .data     (ex_rs2)
    );

    // =========================================================================
    // 执行单元
    // =========================================================================
    // SRC1: RF 或 imm.u ; SRC2: RF / imm(i,s) / PC
    wire [31:0] ex_src1 = (idex_src1_sel == `SRC1_U) ? idex_imm : ex_rs1;
    wire [31:0] ex_src2 = (idex_src2_sel == `SRC2_RF) ? ex_rs2
                        : (idex_src2_sel == `SRC2_PC) ? idex_pc
                        :                               idex_imm;

    wire [31:0] alu_result;
    wire        alu_less, alu_equal;

    core_alu u_alu (
        .src1        (ex_src1),
        .src2        (ex_src2),
        .bitwise     (idex_alu_bitwise),
        .addsub_en   (idex_alu_addsub),
        .revert      (idex_alu_revert),
        .sltx_en     (idex_alu_sltx),
        .slt_unsigned(idex_alu_unsigned),
        .zero_src2   (idex_alu_zero_src2),
        .result      (alu_result),
        .less        (alu_less),
        .equal       (alu_equal)
    );

    wire [31:0] shift_result;
    core_shifter u_shifter (
        .data (ex_src1), .shamt(ex_src2[4:0]), .mode(idex_shift_mode), .result(shift_result)
    );

    wire        br_taken;
    wire [31:0] br_target;
    core_branch_unit u_branch (
        .pc          (idex_pc),
        .imm         (idex_imm),
        .src1        (ex_rs1),
        .src2        (ex_rs2),
        .funct3      (idex_funct3),
        .is_branch   (idex_is_branch),
        .is_jal      (idex_is_jal),
        .is_jalr     (idex_is_jalr),
        .pc_plus_len (idex_pc + (idex_rvc ? 32'd2 : 32'd4)),
        .taken       (br_taken),
        .target      (br_target)
    );

    // ------------------------------ 乘除 -------------------------------------
    wire        mul_done, mul_busy, div_done, div_busy;
    wire [31:0] mul_result, div_result;

    wire mdu_is_div = idex_mdu_op[2];
    // 乘法现在是 4 拍流水, 必须用 busy 挡住重复启动 (否则冻结期间每拍重发一次)
    wire mul_start  = idex_valid & idex_is_mdu & ~mdu_is_div & ~mul_busy & ~mul_done;
    wire div_start  = idex_valid & idex_is_mdu &  mdu_is_div & ~div_busy & ~div_done;

    core_multiplier u_mul (
        .clk(clk), .rst(rst), .start(mul_start),
        .a(ex_rs1), .b(ex_rs2), .op(idex_mdu_op),
        .busy(mul_busy), .done(mul_done), .result(mul_result)
    );

    core_divider u_div (
        .clk(clk), .rst(rst), .start(div_start),
        .a(ex_rs1), .b(ex_rs2), .op(idex_mdu_op),
        .busy(div_busy), .done(div_done), .result(div_result)
    );

    wire        mdu_done  = mdu_is_div ? div_done : mul_done;
    wire        mdu_stall = idex_valid & idex_is_mdu & ~mdu_done;
    wire [31:0] mdu_result = mdu_is_div ? div_result : mul_result;

    // =========================================================================
    // LSU
    // =========================================================================
    wire [3:0]  ls_be;
    wire [31:0] ls_wdata;
    wire [31:0] ls_rdata;
    wire        ls_misaligned;

    reg        stf_valid;
    reg [29:0] stf_word;
    reg [3:0]  stf_be;
    reg [31:0] stf_data;

    core_lsu u_lsu (
        .addr       (exmem_result),
        .wdata      (exmem_store_data),
        .size       (exmem_mem_size),
        .uns        (exmem_mem_unsigned),
        .rdata      (dmem_rdata),
        .fwd_valid  (stf_valid),
        .fwd_word   (stf_word),
        .fwd_be     (stf_be),
        .fwd_data   (stf_data),
        .be         (ls_be),
        .wdata_sh   (ls_wdata),
        .rdata_ext  (ls_rdata),
        .misaligned (ls_misaligned)
    );

    // =========================================================================
    // CSR
    // =========================================================================
    wire [31:0] csr_rdata;
    wire        csr_valid, csr_ro;
    wire [31:0] csr_trap_vector, csr_mepc;
    wire        csr_mstatus_mie;
    wire [31:0] csr_mie;

    reg         csr_trap_en;
    reg  [31:0] csr_trap_cause, csr_trap_tval, csr_trap_epc;
    reg         csr_mret_en;

    core_csr_file u_csr (
        .clk         (clk), .rst(rst),
        .raddr       (idex_csr_addr),
        .rdata       (csr_rdata),
        .csr_valid   (csr_valid),
        .csr_ro      (csr_ro),
        .wr_en       (wb_commit & memwb_csr_we),
        .waddr       (memwb_csr_addr),
        .wdata       (memwb_csr_wdata),
        .fwd0_we     (exmem_valid & exmem_csr_we),
        .fwd0_addr   (exmem_csr_addr),
        .fwd0_data   (exmem_csr_wdata),
        .fwd1_we     (memwb_valid & memwb_csr_we),
        .fwd1_addr   (memwb_csr_addr),
        .fwd1_data   (memwb_csr_wdata),
        .trap_en     (csr_trap_en),
        .trap_cause  (csr_trap_cause),
        .trap_tval   (csr_trap_tval),
        .trap_epc    (csr_trap_epc),
        .mret_en     (csr_mret_en),
        .trap_vector (csr_trap_vector),
        .mepc_out    (csr_mepc),
        .irq_timer   (irq_timer),
        .irq_ext     (irq_ext),
        .irq_soft    (irq_soft),
        .mstatus_mie (csr_mstatus_mie),
        .mie_out     (csr_mie),
        .instret_en  (wb_commit)
    );

    wire [31:0] csr_src = idex_csr_use_imm ? {27'd0, idex_csr_zimm} : ex_rs1;
    wire        csr_we  = (idex_csr_op == `CSR_RW) ||
                          (((idex_csr_op == `CSR_RS) || (idex_csr_op == `CSR_RC)) &&
                           (csr_src != 32'd0));
    reg  [31:0] csr_wdata;
    always @(*) begin
        case (idex_csr_op)
            `CSR_RW: csr_wdata = csr_src;
            `CSR_RS: csr_wdata = csr_rdata | csr_src;
            `CSR_RC: csr_wdata = csr_rdata & ~csr_src;
            default: csr_wdata = 32'd0;
        endcase
    end

    // =========================================================================
    // EX 级例外检测
    // =========================================================================
    wire ex_illegal     = idex_illegal ||
                          ((idex_csr_op != `CSR_NONE) && (!csr_valid || (csr_ro && csr_we)));
    wire ex_ecall       = idex_is_ecall;
    wire ex_ebreak      = idex_is_ebreak;
    wire ex_ls_misalign = (idex_mem_read | idex_mem_write) &&
                          ((idex_mem_size == `MSIZE_H) ? alu_result[0] :
                           (idex_mem_size == `MSIZE_W) ? (alu_result[1:0] != 2'b00) : 1'b0);
    wire ex_br_misalign = (idex_is_branch | idex_is_jal | idex_is_jalr) &&
                          br_taken && br_target[0];

    wire ex_exc = ex_illegal | ex_ecall | ex_ebreak | ex_ls_misalign | ex_br_misalign;

    reg [31:0] ex_cause, ex_tval;
    always @(*) begin
        if (ex_illegal)          begin ex_cause = `EXC_ILLEGAL;    ex_tval = idex_instr_raw; end
        else if (ex_ecall)       begin ex_cause = `EXC_ECALL_M;    ex_tval = 32'd0; end
        else if (ex_ebreak)      begin ex_cause = `EXC_BREAKPOINT; ex_tval = idex_pc; end
        else if (ex_ls_misalign) begin
            ex_cause = idex_mem_read ? `EXC_LOAD_MISALIGN : `EXC_STORE_MISALIGN;
            ex_tval  = alu_result;
        end
        else                     begin ex_cause = `EXC_INSTR_MISALIGN; ex_tval = br_target; end
    end

    wire [31:0] ex_result = idex_is_mdu   ? mdu_result
                          : idex_is_shift ? shift_result
                          :                 alu_result;

    // -----------------------------------------------------------------------
    // 写回值必须在 EX 级就拼好, 并随 EX/MEM 一起前递。
    // 不能拿 exmem_result (那是 ALU 结果) 当前递源: CSR 指令的写回值在
    // exmem_csr_rdata 里, PC4 类指令在 pc+len 上, 二者用 ALU 结果都是错的。
    // -----------------------------------------------------------------------
    wire [31:0] ex_pc4    = idex_pc + (idex_rvc ? 32'd2 : 32'd4);
    wire [31:0] ex_wb_data = (idex_wb_sel == `WB_CSR) ? csr_rdata
                           : (idex_wb_sel == `WB_PC4) ? ex_pc4
                           :                            ex_result;

    // =========================================================================
    // 控制: 重定向 / 陷入 / 停顿
    // =========================================================================
    wire redirect_ex = idex_valid & (br_taken | idex_is_mret) & ~mdu_stall;

    wire mem_err_eff = exmem_valid & (exmem_mem_read | exmem_mem_write) & dmem_err;
    wire mem_trap    = exmem_valid & (exmem_exc_valid | mem_err_eff);

    wire [31:0] irq_pending = ({20'd0, irq_soft, 3'd0, irq_ext, 3'd0, irq_timer, 3'd0}) & csr_mie;
    wire irq_take = (irq_pending != 32'd0) && csr_mstatus_mie && ~mem_trap && ~redirect_ex;

    // --- 两条停顿路径 ---------------------------------------------------------
    wire dmem_stall = (dmem_ren | dmem_wen) & ~dmem_ready;
    assign freeze   = mdu_stall | dmem_stall;

    // load-use: Load 在 EX, 消费者在 ID 且用到同一个 rd
    wire load_use = idex_valid & idex_mem_read & idex_rd_we & if_id_valid &
                    (idex_rd != 5'd0) &
                    ((d_rs1_use & (d_rs1 == idex_rd)) |
                     (d_rs2_use & (d_rs2 == idex_rd)));

    assign hold_front = load_use;

    // --- 重定向 ---------------------------------------------------------------
    assign any_redirect = mem_trap | redirect_ex | irq_take;
    assign redirect_pc  = (mem_trap | irq_take) ? csr_trap_vector
                        : idex_is_mret          ? csr_mepc
                        :                         br_target;

    // =========================================================================
    // 存储器接口
    // =========================================================================
    assign dmem_raddr = alu_result;                                   // EX 发读
    assign dmem_ren   = idex_valid & idex_mem_read & ~ex_exc;
    assign dmem_waddr = exmem_result;                                 // MEM 提交写
    assign dmem_wen   = exmem_valid & exmem_mem_write & ~exmem_exc_valid;
    assign dmem_be    = ls_be;
    assign dmem_wdata = ls_wdata;

    // =========================================================================
    // CSR 陷入 / mret 激励
    // =========================================================================
    wire [31:0] irq_cause = irq_pending[11] ? `IRQ_M_EXTERNAL :
                            irq_pending[3]  ? `IRQ_M_SOFTWARE :
                                              `IRQ_M_TIMER;

    always @(*) begin
        if (mem_trap) begin
            csr_trap_en    = 1'b1;
            csr_trap_cause = mem_err_eff ? (exmem_mem_read ? `EXC_LOAD_ACCESS : `EXC_STORE_ACCESS)
                                         : exmem_exc_cause;
            csr_trap_tval  = mem_err_eff ? exmem_result : exmem_exc_tval;
            csr_trap_epc   = exmem_pc;
        end else if (irq_take) begin
            csr_trap_en    = 1'b1;
            csr_trap_cause = {1'b1, irq_cause};
            csr_trap_tval  = 32'd0;
            csr_trap_epc   = pc;
        end else begin
            csr_trap_en    = 1'b0;
            csr_trap_cause = 32'd0;
            csr_trap_tval  = 32'd0;
            csr_trap_epc   = 32'd0;
        end
        csr_mret_en = redirect_ex & idex_is_mret & ~mem_trap;
    end

    // =========================================================================
    // 时序
    // =========================================================================
    wire [31:0] next_pc = (mem_trap | irq_take) ? csr_trap_vector
                        : redirect_ex           ? redirect_pc
                        :                         pc_plus_len;
    wire pc_advance = any_redirect | (al_valid & ~freeze & ~hold_front);

    always @(posedge clk) begin
        if (rst) begin
            pc              <= `CFG_RESET_VECTOR;
            if_id_valid     <= 1'b0;
            if_id_pc        <= 32'd0;
            if_id_instr     <= 32'd0;
            if_id_instr_raw <= 32'd0;
            if_id_rvc       <= 1'b0;
            if_id_illegal   <= 1'b0;

            idex_valid      <= 1'b0;
            idex_pc         <= 32'd0;
            idex_instr_raw  <= 32'd0;
            idex_rs1        <= 5'd0;
            idex_rs2        <= 5'd0;
            idex_rd         <= 5'd0;
            idex_rd_we      <= 1'b0;
            idex_imm        <= 32'd0;
            idex_src1_sel   <= `SRC1_RF;
            idex_src2_sel   <= `SRC2_RF;
            idex_alu_bitwise<= `ALU_BW_ZERO;
            idex_alu_addsub <= 1'b0;
            idex_alu_revert <= 1'b0;
            idex_alu_sltx   <= 1'b0;
            idex_alu_unsigned <= 1'b0;
            idex_alu_zero_src2 <= 1'b0;
            idex_is_shift   <= 1'b0;
            idex_shift_mode <= 2'd0;
            idex_wb_sel     <= `WB_ALU;
            idex_mem_read   <= 1'b0;
            idex_mem_write  <= 1'b0;
            idex_mem_size   <= `MSIZE_W;
            idex_mem_unsigned <= 1'b0;
            idex_is_branch  <= 1'b0;
            idex_is_jal     <= 1'b0;
            idex_is_jalr    <= 1'b0;
            idex_funct3     <= 3'd0;
            idex_is_mdu     <= 1'b0;
            idex_mdu_op     <= 3'd0;
            idex_csr_op     <= `CSR_NONE;
            idex_csr_addr   <= 12'd0;
            idex_csr_use_imm<= 1'b0;
            idex_csr_zimm   <= 5'd0;
            idex_is_ecall   <= 1'b0;
            idex_is_ebreak  <= 1'b0;
            idex_is_mret    <= 1'b0;
            idex_illegal    <= 1'b0;
            idex_rvc        <= 1'b0;

            exmem_valid     <= 1'b0;
            exmem_exc_valid <= 1'b0;
            exmem_rd_we     <= 1'b0;
            exmem_csr_we    <= 1'b0;
            exmem_mem_read  <= 1'b0;
            exmem_mem_write <= 1'b0;

            memwb_valid     <= 1'b0;
            memwb_rd_we     <= 1'b0;
            memwb_csr_we    <= 1'b0;

            stf_valid       <= 1'b0;
        end else if (!freeze) begin
            // ---------------------------- PC ---------------------------------
            if (pc_advance) pc <= next_pc;

            // ---------------------------- IF/ID ------------------------------
            if (any_redirect) begin
                if_id_valid <= 1'b0;
            end else if (hold_front) begin
                if_id_valid <= if_id_valid;          // 保持
            end else if (al_valid) begin
                if_id_valid     <= 1'b1;
                if_id_pc        <= pc;
                if_id_instr     <= al_instr;
                if_id_instr_raw <= al_instr_raw;
                if_id_rvc       <= al_rvc;
                if_id_illegal   <= al_illegal;
            end else begin
                if_id_valid <= 1'b0;                 // 取指未就绪 -> 气泡
            end

            // ---------------------------- 载入数据锁存 ----------------------
            // 注意: 这一段不能放进 !freeze 里, 否则冻结期间数据就丢了。
            // ---------------------------- WB ---------------------------------
            memwb_valid     <= exmem_valid & ~mem_trap;
            memwb_pc        <= exmem_pc;
            memwb_instr_raw <= exmem_instr_raw;
            // 正常推进时 ls_rdata 就是本拍的数据; 若这条已经在 MEM 停过 (aged),
            // 说明中间被冻结过, 只能取第一拍锁存下来的 load_q。
            memwb_data      <= (exmem_wb_sel == `WB_MEM)
                             ? (exmem_aged ? load_q : ls_rdata)
                             : exmem_wb_data;
            memwb_rd        <= exmem_rd;
            memwb_rd_we     <= exmem_rd_we & ~exmem_exc_valid & ~mem_err_eff;
            memwb_csr_we    <= exmem_csr_we & ~exmem_exc_valid & ~mem_err_eff;
            memwb_csr_addr  <= exmem_csr_addr;
            memwb_csr_wdata <= exmem_csr_wdata;

            // ---------------------------- EX/MEM ----------------------------
            exmem_valid      <= idex_valid;
            exmem_pc         <= idex_pc;
            exmem_instr_raw  <= idex_instr_raw;
            exmem_result     <= ex_result;
            exmem_wb_data    <= ex_wb_data;
            exmem_store_data <= ex_rs2;
            exmem_rd         <= idex_rd;
            exmem_rd_we      <= idex_rd_we;
            exmem_wb_sel     <= idex_wb_sel;
            exmem_mem_read   <= idex_mem_read;
            exmem_mem_write  <= idex_mem_write;
            exmem_mem_size   <= idex_mem_size;
            exmem_mem_unsigned <= idex_mem_unsigned;
            exmem_exc_valid  <= ex_exc;
            exmem_exc_cause  <= ex_cause;
            exmem_exc_tval   <= ex_tval;
            exmem_csr_rdata  <= csr_rdata;
            exmem_csr_we     <= csr_we & (idex_csr_op != `CSR_NONE);
            exmem_csr_addr   <= idex_csr_addr;
            exmem_csr_wdata  <= csr_wdata;
            exmem_rvc        <= idex_rvc;

            // store 前递记录 (下一拍给紧跟的 load 用)
            stf_valid <= exmem_valid & exmem_mem_write & ~exmem_exc_valid;
            stf_word  <= exmem_result[31:2];
            stf_be    <= ls_be;
            stf_data  <= ls_wdata;

            // ---------------------------- ID/EX -----------------------------
            if (mem_trap | redirect_ex) begin
                idex_valid <= 1'b0;                  // 冲刷 ID 级及其后
            end else if (hold_front) begin
                idex_valid <= 1'b0;                  // 已让出给 Load, 不能复制进 MEM
            end else begin
                idex_valid      <= if_id_valid;
                idex_pc         <= if_id_pc;
                idex_instr_raw  <= if_id_instr_raw;
                idex_rs1        <= d_rs1;
                idex_rs2        <= d_rs2;
                idex_rd         <= d_rd;
                idex_rd_we      <= d_rd_we;
                idex_imm        <= d_imm;
                idex_src1_sel   <= d_src1_sel;
                idex_src2_sel   <= d_src2_sel;
                idex_alu_bitwise<= d_alu_bitwise;
                idex_alu_addsub <= d_alu_addsub;
                idex_alu_revert <= d_alu_revert;
                idex_alu_sltx   <= d_alu_sltx;
                idex_alu_unsigned <= d_alu_unsigned;
                idex_alu_zero_src2<= d_alu_zero_src2;
                idex_is_shift   <= d_is_shift;
                idex_shift_mode <= d_shift_mode;
                idex_wb_sel     <= d_wb_sel;
                idex_mem_read   <= d_mem_read;
                idex_mem_write  <= d_mem_write;
                idex_mem_size   <= d_mem_size;
                idex_mem_unsigned <= d_mem_unsigned;
                idex_is_branch  <= d_is_branch;
                idex_is_jal     <= d_is_jal;
                idex_is_jalr    <= d_is_jalr;
                idex_funct3     <= d_funct3;
                idex_is_mdu     <= d_is_mdu;
                idex_mdu_op     <= d_mdu_op;
                idex_csr_op     <= d_csr_op;
                idex_csr_addr   <= d_csr_addr;
                idex_csr_use_imm<= d_csr_use_imm;
                idex_csr_zimm   <= if_id_instr[19:15];
                idex_is_ecall   <= d_is_ecall;
                idex_is_ebreak  <= d_is_ebreak;
                idex_is_mret    <= d_is_mret;
                idex_illegal    <= d_illegal;
                idex_rvc        <= if_id_rvc;
            end
        end
    end

    // 载入数据锁存 (独立于 freeze)
    always @(posedge clk) begin
        if (rst) begin
            exmem_aged <= 1'b0;
            load_q     <= 32'd0;
        end else begin
            exmem_aged <= freeze;           // 冻结说明这条已在 MEM 待过
            if (exmem_valid & exmem_mem_read & ~exmem_aged & ~exmem_exc_valid)
                load_q <= ls_rdata;
        end
    end

    assign commit_valid = wb_commit;
    assign commit_pc    = memwb_pc;
    assign commit_instr = memwb_instr_raw;
endmodule
