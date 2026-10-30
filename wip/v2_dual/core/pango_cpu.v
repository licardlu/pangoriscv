// -----------------------------------------------------------------------------
// pango_cpu.v -- 复现核顶层 (V2: 双发射 RV32IMC + Zicsr + Zifencei)
//
// 结构 (与参考 lane / 流水级的对应见 docs/architecture/reference-pipeline.md):
//
//   取指   : 64 位块 -> 对齐器 (每拍可切 2 条) -> 分发缓冲 (4 项)
//   译码   : 两份 core_decoder 并行; 同步读寄存器堆 (4 读口)
//   配对   : lane0 = 全能通道 (ALU/移位/分支/LSU/MDU/CSR)
//            lane1 = 精简通道 (ALU/移位/分支), 只受 RAW / WAW / 资源限制
//   EX     : 两条通道各一套 ALU/移位/分支; LSU 与 MDU 只在 lane0
//   MEM    : 两个槽; 只有 lane0 能访存, 例外在这里定案
//   WB     : 两个写回口 + CSR 写
//
// 三条不能合并的停顿路径:
//   freeze     : 乘除多周期 / 存储器未 ready。整条流水冻结, 写回被门控。
//   stall_all  : Load 在 EX 且下一条要读它的结果。不发射新指令, 插气泡。
//   stall_pair : 只有 lane1 依赖该 Load, 那这拍只发 lane0, 不拖累整对。
//
// 重定向优先级 (年龄越老越优先):
//   MEM 例外 > 中断 > lane0 分支/mret > lane1 分支
// 一个关键规则: lane0 若已检出例外, 就不允许 lane1 的分支抢走重定向 ——
// 老指令的例外必须先定案, 否则例外会被静默丢弃。
//
// lane1 分支的重定向不能丢掉 lane0: 那一拍把 lane0 正常送进 EX/MEM, 只冲刷前端。
// -----------------------------------------------------------------------------
`include "core_config.vh"
`include "core_defs.vh"

module pango_cpu (
    input  wire        clk,
    input  wire        rst,

    // ------------------------------ 取指侧 (64 位块) --------------------------
    output wire [31:0] imem_addr,
    output wire        imem_req,
    input  wire        imem_ready,
    input  wire        imem_rvalid,
    input  wire [63:0] imem_rdata,

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
    output wire [31:0] commit_instr,
    output wire        commit_valid1,
    output wire [31:0] commit_pc1,
    output wire [31:0] commit_instr1
);
    integer l;

    // =========================================================================
    // 取指 + 对齐
    // =========================================================================
    wire [2:0]  db_space, db_count;
    wire [1:0]  al_out_n;

    wire [31:0] al_cur_pc;
    wire [31:0] al_pc0, al_i0, al_r0, al_pc1, al_i1, al_r1;
    wire        al_rvc0, al_ill0, al_rvc1, al_ill1;

    wire [1:0]  pop_n;

    wire        any_redirect;
    wire [31:0] redirect_pc;

    core_instruction_aligner u_aligner (
        .clk          (clk),
        .rst          (rst),
        .redirect     (any_redirect),
        .redirect_pc  (redirect_pc),
        .space        (db_space),
        .cur_pc       (al_cur_pc),
        .out_n        (al_out_n),
        .o0_pc        (al_pc0),
        .o0_instr     (al_i0),
        .o0_raw       (al_r0),
        .o0_rvc       (al_rvc0),
        .o0_ill       (al_ill0),
        .o1_pc        (al_pc1),
        .o1_instr     (al_i1),
        .o1_raw       (al_r1),
        .o1_rvc       (al_rvc1),
        .o1_ill       (al_ill1),
        .mem_addr     (imem_addr),
        .mem_req      (imem_req),
        .mem_ready    (imem_ready),
        .mem_rvalid   (imem_rvalid),
        .mem_rdata    (imem_rdata)
    );

    // =========================================================================
    // 分发缓冲
    // =========================================================================
    wire        db_q0_v, db_q1_v;
    wire [31:0] db_q0_pc, db_q0_instr, db_q0_raw;
    wire [31:0] db_q1_pc, db_q1_instr, db_q1_raw;
    wire        db_q0_rvc, db_q0_ill, db_q1_rvc, db_q1_ill;

    core_dispatch_buffer u_dbuf (
        .clk      (clk),
        .rst      (rst),
        .flush    (any_redirect),
        .push_n   (al_out_n),
        .p0_pc    (al_pc0), .p0_instr (al_i0), .p0_raw (al_r0),
        .p0_rvc   (al_rvc0), .p0_ill  (al_ill0),
        .p1_pc    (al_pc1), .p1_instr (al_i1), .p1_raw (al_r1),
        .p1_rvc   (al_rvc1), .p1_ill  (al_ill1),
        .space    (db_space),
        .pop_n    (pop_n),
        .count    (db_count),
        .q0_v     (db_q0_v), .q0_pc (db_q0_pc), .q0_instr (db_q0_instr),
        .q0_raw   (db_q0_raw), .q0_rvc (db_q0_rvc), .q0_ill (db_q0_ill),
        .q1_v     (db_q1_v), .q1_pc (db_q1_pc), .q1_instr (db_q1_instr),
        .q1_raw   (db_q1_raw), .q1_rvc (db_q1_rvc), .q1_ill (db_q1_ill)
    );

    // =========================================================================
    // 双译码 (组合, 作用在分发缓冲头部两项)
    // =========================================================================
    wire [4:0]  d_rd     [0:1];
    wire [4:0]  d_rs1    [0:1];
    wire [4:0]  d_rs2    [0:1];
    wire        d_rdwe   [0:1];
    wire        d_rs1u   [0:1];
    wire        d_rs2u   [0:1];
    wire [31:0] d_imm    [0:1];
    wire [1:0]  d_src1   [0:1];
    wire [1:0]  d_src2   [0:1];
    wire [1:0]  d_bw     [0:1];
    wire        d_addsub [0:1];
    wire        d_revert [0:1];
    wire        d_sltx   [0:1];
    wire        d_uns    [0:1];
    wire        d_z2     [0:1];
    wire        d_shift  [0:1];
    wire [1:0]  d_shmode [0:1];
    wire [1:0]  d_wbsel  [0:1];
    wire        d_mrd    [0:1];
    wire        d_mwr    [0:1];
    wire [1:0]  d_msize  [0:1];
    wire        d_muns   [0:1];
    wire        d_br     [0:1];
    wire        d_jal    [0:1];
    wire        d_jalr   [0:1];
    wire [2:0]  d_f3     [0:1];
    wire        d_mdu    [0:1];
    wire [2:0]  d_mduop  [0:1];
    wire [1:0]  d_csrop  [0:1];
    wire [11:0] d_csra   [0:1];
    wire        d_csrimm [0:1];
    wire        d_ecall  [0:1];
    wire        d_ebreak [0:1];
    wire        d_mret   [0:1];
    wire        d_fence  [0:1];
    wire        d_fencei [0:1];
    wire        d_ill    [0:1];

    core_decoder u_dec0 (
        .instr         (db_q0_instr),
        .rvc_illegal   (db_q0_ill),
        .illegal       (d_ill[0]),
        .rd            (d_rd[0]),
        .rs1           (d_rs1[0]),
        .rs2           (d_rs2[0]),
        .rd_we         (d_rdwe[0]),
        .rs1_use       (d_rs1u[0]),
        .rs2_use       (d_rs2u[0]),
        .imm           (d_imm[0]),
        .src1_sel      (d_src1[0]),
        .src2_sel      (d_src2[0]),
        .alu_bitwise   (d_bw[0]),
        .alu_addsub    (d_addsub[0]),
        .alu_revert    (d_revert[0]),
        .alu_sltx      (d_sltx[0]),
        .alu_unsigned  (d_uns[0]),
        .alu_zero_src2 (d_z2[0]),
        .is_shift      (d_shift[0]),
        .shift_mode    (d_shmode[0]),
        .wb_sel        (d_wbsel[0]),
        .mem_read      (d_mrd[0]),
        .mem_write     (d_mwr[0]),
        .mem_size      (d_msize[0]),
        .mem_unsigned  (d_muns[0]),
        .is_branch     (d_br[0]),
        .is_jal        (d_jal[0]),
        .is_jalr       (d_jalr[0]),
        .funct3        (d_f3[0]),
        .is_mdu        (d_mdu[0]),
        .mdu_op        (d_mduop[0]),
        .csr_op        (d_csrop[0]),
        .csr_addr      (d_csra[0]),
        .csr_use_imm   (d_csrimm[0]),
        .is_ecall      (d_ecall[0]),
        .is_ebreak     (d_ebreak[0]),
        .is_mret       (d_mret[0]),
        .is_fence      (d_fence[0]),
        .is_fence_i    (d_fencei[0])
    );

    core_decoder u_dec1 (
        .instr         (db_q1_instr),
        .rvc_illegal   (db_q1_ill),
        .illegal       (d_ill[1]),
        .rd            (d_rd[1]),
        .rs1           (d_rs1[1]),
        .rs2           (d_rs2[1]),
        .rd_we         (d_rdwe[1]),
        .rs1_use       (d_rs1u[1]),
        .rs2_use       (d_rs2u[1]),
        .imm           (d_imm[1]),
        .src1_sel      (d_src1[1]),
        .src2_sel      (d_src2[1]),
        .alu_bitwise   (d_bw[1]),
        .alu_addsub    (d_addsub[1]),
        .alu_revert    (d_revert[1]),
        .alu_sltx      (d_sltx[1]),
        .alu_unsigned  (d_uns[1]),
        .alu_zero_src2 (d_z2[1]),
        .is_shift      (d_shift[1]),
        .shift_mode    (d_shmode[1]),
        .wb_sel        (d_wbsel[1]),
        .mem_read      (d_mrd[1]),
        .mem_write     (d_mwr[1]),
        .mem_size      (d_msize[1]),
        .mem_unsigned  (d_muns[1]),
        .is_branch     (d_br[1]),
        .is_jal        (d_jal[1]),
        .is_jalr       (d_jalr[1]),
        .funct3        (d_f3[1]),
        .is_mdu        (d_mdu[1]),
        .mdu_op        (d_mduop[1]),
        .csr_op        (d_csrop[1]),
        .csr_addr      (d_csra[1]),
        .csr_use_imm   (d_csrimm[1]),
        .is_ecall      (d_ecall[1]),
        .is_ebreak     (d_ebreak[1]),
        .is_mret       (d_mret[1]),
        .is_fence      (d_fence[1]),
        .is_fence_i    (d_fencei[1])
    );

    // =========================================================================
    // 寄存器堆 (4 读 2 写)
    // =========================================================================
    wire [31:0] rf_rd1, rf_rd2, rf_rd3, rf_rd4;

    // =========================================================================
    // ID/EX (两个通道)
    // =========================================================================
    reg         idex_v     [0:1];
    reg  [31:0] idex_pc    [0:1];
    reg  [31:0] idex_raw   [0:1];
    reg         idex_rvcq  [0:1];
    reg  [4:0]  idex_rs1q  [0:1];
    reg  [4:0]  idex_rs2q  [0:1];
    reg  [4:0]  idex_rdq   [0:1];
    reg         idex_rdweq [0:1];
    reg  [31:0] idex_immq  [0:1];
    reg  [1:0]  idex_src1q [0:1];
    reg  [1:0]  idex_src2q [0:1];
    reg  [1:0]  idex_bwq   [0:1];
    reg         idex_addsubq[0:1];
    reg         idex_revertq[0:1];
    reg         idex_sltxq [0:1];
    reg         idex_unsq  [0:1];
    reg         idex_z2q   [0:1];
    reg         idex_shiftq[0:1];
    reg  [1:0]  idex_shmq  [0:1];
    reg  [1:0]  idex_wbsq  [0:1];
    reg         idex_mrdq  [0:1];
    reg         idex_mwrq  [0:1];
    reg  [1:0]  idex_mszq  [0:1];
    reg         idex_munsq [0:1];
    reg         idex_brq   [0:1];
    reg         idex_jalq  [0:1];
    reg         idex_jalrq [0:1];
    reg  [2:0]  idex_f3q   [0:1];
    reg         idex_mduq  [0:1];
    reg  [2:0]  idex_mduoq [0:1];
    reg  [1:0]  idex_csropq[0:1];
    reg  [11:0] idex_csraq [0:1];
    reg         idex_csrimmq[0:1];
    reg  [4:0]  idex_zimmq [0:1];
    reg         idex_ecallq[0:1];
    reg         idex_ebreakq[0:1];
    reg         idex_mretq [0:1];
    reg         idex_illq  [0:1];

    // =========================================================================
    // EX/MEM (两个槽) 与 MEM/WB (两个槽)
    // =========================================================================
    reg         exmem_v     [0:1];
    reg  [31:0] exmem_pc    [0:1];
    reg  [31:0] exmem_raw   [0:1];
    reg  [31:0] exmem_res   [0:1];
    reg  [31:0] exmem_wbd   [0:1];
    reg  [31:0] exmem_sdata [0:1];
    reg  [4:0]  exmem_rdq   [0:1];
    reg         exmem_rdweq [0:1];
    reg  [1:0]  exmem_wbsq  [0:1];
    reg         exmem_mrdq  [0:1];
    reg         exmem_mwrq  [0:1];
    reg  [1:0]  exmem_mszq  [0:1];
    reg         exmem_munsq [0:1];
    reg         exmem_excq  [0:1];
    reg  [31:0] exmem_cause [0:1];
    reg  [31:0] exmem_tval  [0:1];
    reg  [31:0] exmem_csrr  [0:1];
    reg         exmem_csrw  [0:1];
    reg  [11:0] exmem_csra  [0:1];
    reg  [31:0] exmem_csrd  [0:1];
    reg         exmem_rvcq  [0:1];

    reg         memwb_v     [0:1];
    reg  [31:0] memwb_pc    [0:1];
    reg  [31:0] memwb_raw   [0:1];
    reg  [31:0] memwb_data  [0:1];
    reg  [4:0]  memwb_rdq   [0:1];
    reg         memwb_rdweq [0:1];
    reg         memwb_csrw  [0:1];
    reg  [11:0] memwb_csra  [0:1];
    reg  [31:0] memwb_csrd  [0:1];

    reg         exmem_aged;
    reg  [31:0] load_q;

    // =========================================================================
    // 配对判断
    // =========================================================================
    // lane1 只接受"纯 ALU / 移位 / 分支"指令, 不碰存储器、CSR、乘除和系统指令。
    wire d1_simple = ~d_mrd[1] & ~d_mwr[1] & ~d_mdu[1] &
                     (d_csrop[1] == `CSR_NONE) &
                     ~d_ecall[1] & ~d_ebreak[1] & ~d_mret[1] &
                     ~d_fence[1] & ~d_fencei[1];

    wire d0_serial = d_br[0] | d_jal[0] | d_jalr[0] | d_mret[0] |
                     d_ecall[0] | d_ebreak[0] | d_fence[0] | d_fencei[0];

    // 组内 RAW: lane1 不能读 lane0 本轮要写的目的寄存器
    wire pair_raw  = (d_rdwe[0] && (d_rd[0] != 5'd0)) &&
                     ((d_rs1u[1] && (d_rs1[1] == d_rd[0])) ||
                      (d_rs2u[1] && (d_rs2[1] == d_rd[0])));

    // 组内 WAW: 同一拍两个写口写同一寄存器, 组内顺序无法表达
    wire pair_waw  = d_rdwe[0] && d_rdwe[1] &&
                     (d_rd[0] != 5'd0) && (d_rd[0] == d_rd[1]);

    wire pair_ok = db_q0_v && db_q1_v && d1_simple && !pair_raw && !pair_waw &&
                   !d0_serial && !d_ill[0];

    // =========================================================================
    // 相关停顿
    // =========================================================================
    wire mdu_stall, dmem_stall, freeze_out;
    assign freeze_out = mdu_stall | dmem_stall;
    wire freeze = freeze_out;

    // Load 在 EX (lane0 才会是 Load), 消费者还在分发缓冲里
    wire [4:0] ld_rd = idex_rdq[0];
    wire ld_ex = idex_v[0] & idex_mrdq[0] & idex_rdweq[0] & (ld_rd != 5'd0);

    wire use0 = (d_rs1u[0] && (d_rs1[0] == ld_rd)) ||
                (d_rs2u[0] && (d_rs2[0] == ld_rd));
    wire use1 = (d_rs1u[1] && (d_rs1[1] == ld_rd)) ||
                (d_rs2u[1] && (d_rs2[1] == ld_rd));

    wire stall_all  = ld_ex & db_q0_v & use0;
    wire stall_pair = ld_ex & use1 & ~use0;

    // =========================================================================
    // 发射条数
    // =========================================================================
    assign pop_n = (freeze | stall_all | any_redirect) ? 2'd0
                 : (pair_ok && !stall_pair && (db_count >= 3'd2)) ? 2'd2
                 : (db_count >= 3'd1) ? 2'd1
                 :                      2'd0;

    // =========================================================================
    // 执行单元 (每通道一套)
    // =========================================================================
    wire [31:0] x_src1 [0:1];
    wire [31:0] x_src2 [0:1];
    wire [31:0] x_rs1  [0:1];
    wire [31:0] x_rs2  [0:1];
    wire [31:0] alu_r  [0:1];
    wire        alu_less [0:1];
    wire        alu_eq   [0:1];
    wire [31:0] shf_r  [0:1];
    wire        br_tk  [0:1];
    wire [31:0] br_tgt [0:1];

    // 前递源
    wire m1_fw = exmem_v[1] & exmem_rdweq[1] & ~exmem_excq[1];
    wire m0_fw = exmem_v[0] & exmem_rdweq[0] & ~exmem_mrdq[0] & ~exmem_excq[0];
    wire w1_fw = memwb_v[1] & memwb_rdweq[1];
    wire w0_fw = memwb_v[0] & memwb_rdweq[0];

    core_operand_select u_sel10 (
        .rf_data (rf_rd1), .rf_addr (idex_rs1q[0]),
        .s0_we (m1_fw), .s0_rd (exmem_rdq[1]), .s0_data (exmem_wbd[1]),
        .s1_we (m0_fw), .s1_rd (exmem_rdq[0]), .s1_data (exmem_wbd[0]),
        .s2_we (w1_fw), .s2_rd (memwb_rdq[1]), .s2_data (memwb_data[1]),
        .s3_we (w0_fw), .s3_rd (memwb_rdq[0]), .s3_data (memwb_data[0]),
        .data   (x_rs1[0])
    );
    core_operand_select u_sel20 (
        .rf_data (rf_rd2), .rf_addr (idex_rs2q[0]),
        .s0_we (m1_fw), .s0_rd (exmem_rdq[1]), .s0_data (exmem_wbd[1]),
        .s1_we (m0_fw), .s1_rd (exmem_rdq[0]), .s1_data (exmem_wbd[0]),
        .s2_we (w1_fw), .s2_rd (memwb_rdq[1]), .s2_data (memwb_data[1]),
        .s3_we (w0_fw), .s3_rd (memwb_rdq[0]), .s3_data (memwb_data[0]),
        .data   (x_rs2[0])
    );
    core_operand_select u_sel11 (
        .rf_data (rf_rd3), .rf_addr (idex_rs1q[1]),
        .s0_we (m1_fw), .s0_rd (exmem_rdq[1]), .s0_data (exmem_wbd[1]),
        .s1_we (m0_fw), .s1_rd (exmem_rdq[0]), .s1_data (exmem_wbd[0]),
        .s2_we (w1_fw), .s2_rd (memwb_rdq[1]), .s2_data (memwb_data[1]),
        .s3_we (w0_fw), .s3_rd (memwb_rdq[0]), .s3_data (memwb_data[0]),
        .data   (x_rs1[1])
    );
    core_operand_select u_sel21 (
        .rf_data (rf_rd4), .rf_addr (idex_rs2q[1]),
        .s0_we (m1_fw), .s0_rd (exmem_rdq[1]), .s0_data (exmem_wbd[1]),
        .s1_we (m0_fw), .s1_rd (exmem_rdq[0]), .s1_data (exmem_wbd[0]),
        .s2_we (w1_fw), .s2_rd (memwb_rdq[1]), .s2_data (memwb_data[1]),
        .s3_we (w0_fw), .s3_rd (memwb_rdq[0]), .s3_data (memwb_data[0]),
        .data   (x_rs2[1])
    );

    genvar g;
    generate
        for (g = 0; g < 2; g = g + 1) begin : lane_ex
            assign x_src1[g] = (idex_src1q[g] == `SRC1_U) ? idex_immq[g] : x_rs1[g];
            assign x_src2[g] = (idex_src2q[g] == `SRC2_RF) ? x_rs2[g]
                             : (idex_src2q[g] == `SRC2_PC) ? idex_pc[g]
                             :                                idex_immq[g];

            core_alu u_alu (
                .src1        (x_src1[g]),
                .src2        (x_src2[g]),
                .bitwise     (idex_bwq[g]),
                .addsub_en   (idex_addsubq[g]),
                .revert      (idex_revertq[g]),
                .sltx_en     (idex_sltxq[g]),
                .slt_unsigned(idex_unsq[g]),
                .zero_src2   (idex_z2q[g]),
                .result      (alu_r[g]),
                .less        (alu_less[g]),
                .equal       (alu_eq[g])
            );

            core_shifter u_shf (
                .data  (x_src1[g]),
                .shamt (x_src2[g][4:0]),
                .mode  (idex_shmq[g]),
                .result(shf_r[g])
            );

            core_branch_unit u_bru (
                .pc          (idex_pc[g]),
                .imm         (idex_immq[g]),
                .src1        (x_rs1[g]),
                .src2        (x_rs2[g]),
                .funct3      (idex_f3q[g]),
                .is_branch   (idex_brq[g]),
                .is_jal      (idex_jalq[g]),
                .is_jalr     (idex_jalrq[g]),
                .pc_plus_len (idex_pc[g] + (idex_rvcq[g] ? 32'd2 : 32'd4)),
                .taken       (br_tk[g]),
                .target      (br_tgt[g])
            );
        end
    endgenerate

    // =========================================================================
    // 乘除 (只在 lane0)
    // =========================================================================
    wire        mul_done, mul_busy, div_done, div_busy;
    wire [31:0] mul_result, div_result;

    wire mdu_is_div = idex_mduoq[0][2];
    wire mul_start  = idex_v[0] & idex_mduq[0] & ~mdu_is_div & ~mul_busy & ~mul_done;
    wire div_start  = idex_v[0] & idex_mduq[0] &  mdu_is_div & ~div_busy & ~div_done;

    core_multiplier u_mul (
        .clk(clk), .rst(rst), .start(mul_start),
        .a(x_rs1[0]), .b(x_rs2[0]), .op(idex_mduoq[0]),
        .busy(mul_busy), .done(mul_done), .result(mul_result)
    );

    core_divider u_div (
        .clk(clk), .rst(rst), .start(div_start),
        .a(x_rs1[0]), .b(x_rs2[0]), .op(idex_mduoq[0]),
        .busy(div_busy), .done(div_done), .result(div_result)
    );

    wire        mdu_done  = mdu_is_div ? div_done : mul_done;
    assign      mdu_stall = idex_v[0] & idex_mduq[0] & ~mdu_done;
    wire [31:0] mdu_result = mdu_is_div ? div_result : mul_result;

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

    // =========================================================================
    // 例外检测
    // =========================================================================
    wire [31:0] csr_src = idex_csrimmq[0] ? {27'd0, idex_zimmq[0]} : x_rs1[0];
    wire        csr_we0 = (idex_csropq[0] == `CSR_RW) ||
                          (((idex_csropq[0] == `CSR_RS) || (idex_csropq[0] == `CSR_RC)) &&
                           (csr_src != 32'd0));

    reg [31:0] csr_wdata;
    always @(*) begin
        case (idex_csropq[0])
            `CSR_RW: csr_wdata = csr_src;
            `CSR_RS: csr_wdata = csr_rdata | csr_src;
            `CSR_RC: csr_wdata = csr_rdata & ~csr_src;
            default: csr_wdata = 32'd0;
        endcase
    end

    wire x0_illegal = idex_illq[0] ||
                      ((idex_csropq[0] != `CSR_NONE) &&
                       (!csr_valid || (csr_ro && csr_we0)));
    wire x0_lsmis = (idex_mrdq[0] | idex_mwrq[0]) &
                    ((idex_mszq[0] == `MSIZE_H) ? alu_r[0][0] :
                     (idex_mszq[0] == `MSIZE_W) ? (alu_r[0][1:0] != 2'b00) : 1'b0);
    wire x0_brmis = (idex_brq[0] | idex_jalq[0] | idex_jalrq[0]) & br_tk[0] & br_tgt[0][0];
    wire x0_exc   = x0_illegal | idex_ecallq[0] | idex_ebreakq[0] | x0_lsmis | x0_brmis;

    wire x1_illegal = idex_illq[1];
    wire x1_brmis   = (idex_brq[1] | idex_jalq[1] | idex_jalrq[1]) & br_tk[1] & br_tgt[1][0];
    wire x1_exc     = x1_illegal | x1_brmis;

    reg [31:0] x0_cause, x0_tval;
    always @(*) begin
        if (x0_illegal)      begin x0_cause = `EXC_ILLEGAL;    x0_tval = idex_raw[0]; end
        else if (idex_ecallq[0])  begin x0_cause = `EXC_ECALL_M;    x0_tval = 32'd0; end
        else if (idex_ebreakq[0]) begin x0_cause = `EXC_BREAKPOINT; x0_tval = idex_pc[0]; end
        else if (x0_lsmis)        begin
            x0_cause = idex_mrdq[0] ? `EXC_LOAD_MISALIGN : `EXC_STORE_MISALIGN;
            x0_tval  = alu_r[0];
        end
        else                      begin x0_cause = `EXC_INSTR_MISALIGN; x0_tval = br_tgt[0]; end
    end

    wire [31:0] x1_cause = x1_illegal ? `EXC_ILLEGAL : `EXC_INSTR_MISALIGN;
    wire [31:0] x1_tval  = x1_illegal ? idex_raw[1] : br_tgt[1];

    // =========================================================================
    // 写回值 (EX 级拼好, 随 EX/MEM 前递)
    // =========================================================================
    wire [31:0] x0_pc4 = idex_pc[0] + (idex_rvcq[0] ? 32'd2 : 32'd4);
    wire [31:0] x1_pc4 = idex_pc[1] + (idex_rvcq[1] ? 32'd2 : 32'd4);

    wire [31:0] x0_result = idex_mduq[0] ? mdu_result
                          : idex_shiftq[0] ? shf_r[0]
                          :                  alu_r[0];
    wire [31:0] x1_result = idex_shiftq[1] ? shf_r[1] : alu_r[1];

    wire [31:0] x0_wb = (idex_wbsq[0] == `WB_CSR) ? csr_rdata
                      : (idex_wbsq[0] == `WB_PC4) ? x0_pc4
                      :                             x0_result;
    wire [31:0] x1_wb = (idex_wbsq[1] == `WB_PC4) ? x1_pc4 : x1_result;

    // =========================================================================
    // LSU (只有 lane0)
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
        .addr       (exmem_res[0]),
        .wdata      (exmem_sdata[0]),
        .size       (exmem_mszq[0]),
        .uns        (exmem_munsq[0]),
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

    assign dmem_raddr = x0_result;
    assign dmem_ren   = idex_v[0] & idex_mrdq[0] & ~x0_exc;
    assign dmem_waddr = exmem_res[0];
    assign dmem_wen   = exmem_v[0] & exmem_mwrq[0] & ~exmem_excq[0];
    assign dmem_be    = ls_be;
    assign dmem_wdata = ls_wdata;

    assign dmem_stall = (dmem_ren | dmem_wen) & ~dmem_ready;

    // =========================================================================
    // 重定向 / 中断 (必须先算出来, trap 段要用)
    // =========================================================================
    wire redirect_ex0 = idex_v[0] & (br_tk[0] | idex_mretq[0]) & ~mdu_stall;
    // lane0 有例外时不接受 lane1 的分支重定向: 老指令的例外优先定案
    wire redirect_ex1 = idex_v[1] & br_tk[1] & ~redirect_ex0 & ~x0_exc;

    wire [31:0] irq_pending = ({20'd0, irq_soft, 3'd0, irq_ext, 3'd0, irq_timer, 3'd0}) & csr_mie;

    // =========================================================================
    // MEM 级例外定案
    // =========================================================================
    wire mem_err_eff = exmem_v[0] & (exmem_mrdq[0] | exmem_mwrq[0]) & dmem_err;
    wire trap0 = exmem_v[0] & (exmem_excq[0] | mem_err_eff);
    wire trap1 = exmem_v[1] & exmem_excq[1];

    wire irq_take = (irq_pending != 32'd0) && csr_mstatus_mie &&
                    ~trap0 && ~trap1 && ~redirect_ex0 && ~redirect_ex1;

    wire [31:0] trap_cause = trap0
        ? (mem_err_eff ? (exmem_mrdq[0] ? `EXC_LOAD_ACCESS : `EXC_STORE_ACCESS)
                       : exmem_cause[0])
        : exmem_cause[1];
    wire [31:0] trap_tval  = trap0
        ? (mem_err_eff ? exmem_res[0] : exmem_tval[0])
        : exmem_tval[1];
    wire [31:0] trap_epc   = trap0 ? exmem_pc[0] : exmem_pc[1];

    wire [31:0] irq_cause = irq_pending[11] ? `IRQ_M_EXTERNAL :
                            irq_pending[3]  ? `IRQ_M_SOFTWARE :
                                              `IRQ_M_TIMER;
    wire [31:0] irq_epc   = db_q0_v ? db_q0_pc : al_cur_pc;

    always @(*) begin
        if (trap0 || trap1) begin
            csr_trap_en    = 1'b1;
            csr_trap_cause = trap_cause;
            csr_trap_tval  = trap_tval;
            csr_trap_epc   = trap_epc;
        end else if (irq_take) begin
            csr_trap_en    = 1'b1;
            csr_trap_cause = {1'b1, irq_cause};
            csr_trap_tval  = 32'd0;
            csr_trap_epc   = irq_epc;
        end else begin
            csr_trap_en    = 1'b0;
            csr_trap_cause = 32'd0;
            csr_trap_tval  = 32'd0;
            csr_trap_epc   = 32'd0;
        end
        // mret 只在 lane0 且确实是 mret 指令时生效 (不能拿"有重定向"当条件)
        csr_mret_en = idex_v[0] & idex_mretq[0] & ~mdu_stall & ~(trap0 | trap1);
    end

    assign any_redirect = trap0 | trap1 | redirect_ex0 | redirect_ex1 | irq_take;

    assign redirect_pc = (trap0 | trap1) ? csr_trap_vector
                       : irq_take        ? csr_trap_vector
                       : idex_mretq[0]   ? csr_mepc
                       : br_tk[0]        ? br_tgt[0]
                       :                   br_tgt[1];

    // =========================================================================
    // 写回
    // =========================================================================
    // ★ 每个写口的使能必须用"该口自己的 valid"做门控。
    //   若用 (v0|v1) 这种合并信号, lane1 无效的那一拍仍会拿陈旧的
    //   memwb_data[1]/memwb_rdq[1] 去写寄存器 —— 实测会把循环变量 a5
    //   反复覆盖成上一条指令的残值, 造成死循环。
    wire wb0_ok = memwb_v[0] & ~freeze;
    wire wb1_ok = memwb_v[1] & ~freeze;
    wire wb_commit = wb0_ok | wb1_ok;
    wire [1:0] instret_num = {1'b0, wb1_ok} + {1'b0, wb0_ok};

    core_regfile u_regfile (
        .clk (clk), .rst (rst),
        .ra1 (d_rs1[0]), .ra2 (d_rs2[0]),
        .ra3 (d_rs1[1]), .ra4 (d_rs2[1]),
        .rd1 (rf_rd1), .rd2 (rf_rd2), .rd3 (rf_rd3), .rd4 (rf_rd4),
        .we0 (wb0_ok & memwb_rdweq[0]), .wa0 (memwb_rdq[0]), .wd0 (memwb_data[0]),
        .we1 (wb1_ok & memwb_rdweq[1]), .wa1 (memwb_rdq[1]), .wd1 (memwb_data[1])
    );

    core_csr_file u_csr (
        .clk         (clk), .rst(rst),
        .raddr       (idex_csraq[0]),
        .rdata       (csr_rdata),
        .csr_valid   (csr_valid),
        .csr_ro      (csr_ro),
        .wr_en       (wb0_ok & memwb_csrw[0]),
        .waddr       (memwb_csra[0]),
        .wdata       (memwb_csrd[0]),
        .fwd0_we     (exmem_v[0] & exmem_csrw[0]),
        .fwd0_addr   (exmem_csra[0]),
        .fwd0_data   (exmem_csrd[0]),
        .fwd1_we     (memwb_v[0] & memwb_csrw[0]),
        .fwd1_addr   (memwb_csra[0]),
        .fwd1_data   (memwb_csrd[0]),
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
        .instret_num (instret_num)
    );

    // =========================================================================
    // 时序
    // =========================================================================
    // 中断发生时, 若 EX/MEM 里还有更老的指令, 它们仍然提交; epc 已经指向
    // 分发缓冲头部, 因此不会重复执行。
    wire [1:0] issue_n = pop_n;

    always @(posedge clk) begin
        if (rst) begin
            for (l = 0; l < 2; l = l + 1) begin
                idex_v[l]      <= 1'b0;
                idex_pc[l]     <= 32'd0;
                idex_raw[l]    <= 32'd0;
                idex_rvcq[l]   <= 1'b0;
                idex_rs1q[l]   <= 5'd0;
                idex_rs2q[l]   <= 5'd0;
                idex_rdq[l]    <= 5'd0;
                idex_rdweq[l]  <= 1'b0;
                idex_immq[l]   <= 32'd0;
                idex_src1q[l]  <= `SRC1_RF;
                idex_src2q[l]  <= `SRC2_RF;
                idex_bwq[l]    <= `ALU_BW_ZERO;
                idex_addsubq[l]<= 1'b0;
                idex_revertq[l]<= 1'b0;
                idex_sltxq[l]  <= 1'b0;
                idex_unsq[l]   <= 1'b0;
                idex_z2q[l]    <= 1'b0;
                idex_shiftq[l] <= 1'b0;
                idex_shmq[l]   <= 2'd0;
                idex_wbsq[l]   <= `WB_ALU;
                idex_mrdq[l]   <= 1'b0;
                idex_mwrq[l]   <= 1'b0;
                idex_mszq[l]   <= `MSIZE_W;
                idex_munsq[l]  <= 1'b0;
                idex_brq[l]    <= 1'b0;
                idex_jalq[l]   <= 1'b0;
                idex_jalrq[l]  <= 1'b0;
                idex_f3q[l]    <= 3'd0;
                idex_mduq[l]   <= 1'b0;
                idex_mduoq[l]  <= 3'd0;
                idex_csropq[l] <= `CSR_NONE;
                idex_csraq[l]  <= 12'd0;
                idex_csrimmq[l]<= 1'b0;
                idex_zimmq[l]  <= 5'd0;
                idex_ecallq[l] <= 1'b0;
                idex_ebreakq[l]<= 1'b0;
                idex_mretq[l]  <= 1'b0;
                idex_illq[l]   <= 1'b0;

                exmem_v[l]     <= 1'b0;
                exmem_rdweq[l] <= 1'b0;
                exmem_mrdq[l]  <= 1'b0;
                exmem_mwrq[l]  <= 1'b0;
                exmem_excq[l]  <= 1'b0;
                exmem_csrw[l]  <= 1'b0;
                exmem_rvcq[l]  <= 1'b0;

                memwb_v[l]     <= 1'b0;
                memwb_rdweq[l] <= 1'b0;
                memwb_csrw[l]  <= 1'b0;
            end
            stf_valid  <= 1'b0;
            exmem_aged <= 1'b0;
            load_q     <= 32'd0;
        end else if (!freeze) begin
            // ---------------------------- ID/EX ------------------------------
            idex_v[0]       <= (issue_n >= 2'd1);
            idex_pc[0]      <= db_q0_pc;
            idex_raw[0]     <= db_q0_raw;
            idex_rvcq[0]    <= db_q0_rvc;
            idex_rs1q[0]    <= d_rs1[0];
            idex_rs2q[0]    <= d_rs2[0];
            idex_rdq[0]     <= d_rd[0];
            idex_rdweq[0]   <= d_rdwe[0];
            idex_immq[0]    <= d_imm[0];
            idex_src1q[0]   <= d_src1[0];
            idex_src2q[0]   <= d_src2[0];
            idex_bwq[0]     <= d_bw[0];
            idex_addsubq[0] <= d_addsub[0];
            idex_revertq[0] <= d_revert[0];
            idex_sltxq[0]   <= d_sltx[0];
            idex_unsq[0]    <= d_uns[0];
            idex_z2q[0]     <= d_z2[0];
            idex_shiftq[0]  <= d_shift[0];
            idex_shmq[0]    <= d_shmode[0];
            idex_wbsq[0]    <= d_wbsel[0];
            idex_mrdq[0]    <= d_mrd[0];
            idex_mwrq[0]    <= d_mwr[0];
            idex_mszq[0]    <= d_msize[0];
            idex_munsq[0]   <= d_muns[0];
            idex_brq[0]     <= d_br[0];
            idex_jalq[0]    <= d_jal[0];
            idex_jalrq[0]   <= d_jalr[0];
            idex_f3q[0]     <= d_f3[0];
            idex_mduq[0]    <= d_mdu[0];
            idex_mduoq[0]   <= d_mduop[0];
            idex_csropq[0]  <= d_csrop[0];
            idex_csraq[0]   <= d_csra[0];
            idex_csrimmq[0] <= d_csrimm[0];
            idex_zimmq[0]   <= db_q0_instr[19:15];
            idex_ecallq[0]  <= d_ecall[0];
            idex_ebreakq[0] <= d_ebreak[0];
            idex_mretq[0]   <= d_mret[0];
            idex_illq[0]    <= d_ill[0];

            idex_v[1]       <= (issue_n == 2'd2);
            idex_pc[1]      <= db_q1_pc;
            idex_raw[1]     <= db_q1_raw;
            idex_rvcq[1]    <= db_q1_rvc;
            idex_rs1q[1]    <= d_rs1[1];
            idex_rs2q[1]    <= d_rs2[1];
            idex_rdq[1]     <= d_rd[1];
            idex_rdweq[1]   <= d_rdwe[1];
            idex_immq[1]    <= d_imm[1];
            idex_src1q[1]   <= d_src1[1];
            idex_src2q[1]   <= d_src2[1];
            idex_bwq[1]     <= d_bw[1];
            idex_addsubq[1] <= d_addsub[1];
            idex_revertq[1] <= d_revert[1];
            idex_sltxq[1]   <= d_sltx[1];
            idex_unsq[1]    <= d_uns[1];
            idex_z2q[1]     <= d_z2[1];
            idex_shiftq[1]  <= d_shift[1];
            idex_shmq[1]    <= d_shmode[1];
            idex_wbsq[1]    <= d_wbsel[1];
            idex_mrdq[1]    <= d_mrd[1];
            idex_mwrq[1]    <= d_mwr[1];
            idex_mszq[1]    <= d_msize[1];
            idex_munsq[1]   <= d_muns[1];
            idex_brq[1]     <= d_br[1];
            idex_jalq[1]    <= d_jal[1];
            idex_jalrq[1]   <= d_jalr[1];
            idex_f3q[1]     <= d_f3[1];
            idex_mduq[1]    <= d_mdu[1];
            idex_mduoq[1]   <= d_mduop[1];
            idex_csropq[1]  <= d_csrop[1];
            idex_csraq[1]   <= d_csra[1];
            idex_csrimmq[1] <= d_csrimm[1];
            idex_zimmq[1]   <= db_q1_instr[19:15];
            idex_ecallq[1]  <= d_ecall[1];
            idex_ebreakq[1] <= d_ebreak[1];
            idex_mretq[1]   <= d_mret[1];
            idex_illq[1]    <= d_ill[1];

            // ---------------------------- EX/MEM -----------------------------
            // lane1 分支重定向时 lane0 仍要进入 EX/MEM (它更老, 不能丢)
            // 分支自己必须进 EX/MEM 并退休: 它要写 rd (jal/jalr 的返回地址),
            // 也要计入 minstret。被抹掉的话 `jal main` 不写 ra, 返回时跳到错地址。
            // 只有"更年轻的"指令才被重定向杀掉。
            exmem_v[0]      <= idex_v[0] & ~(trap0 | trap1);
            exmem_pc[0]     <= idex_pc[0];
            exmem_raw[0]    <= idex_raw[0];
            exmem_res[0]    <= x0_result;
            exmem_wbd[0]    <= x0_wb;
            exmem_sdata[0]  <= x_rs2[0];
            exmem_rdq[0]    <= idex_rdq[0];
            exmem_rdweq[0]  <= idex_rdweq[0];
            exmem_wbsq[0]   <= idex_wbsq[0];
            exmem_mrdq[0]   <= idex_mrdq[0];
            exmem_mwrq[0]   <= idex_mwrq[0];
            exmem_mszq[0]   <= idex_mszq[0];
            exmem_munsq[0]  <= idex_munsq[0];
            exmem_excq[0]   <= x0_exc;
            exmem_cause[0]  <= x0_cause;
            exmem_tval[0]   <= x0_tval;
            exmem_csrr[0]   <= csr_rdata;
            exmem_csrw[0]   <= csr_we0 & (idex_csropq[0] != `CSR_NONE);
            exmem_csra[0]   <= idex_csraq[0];
            exmem_csrd[0]   <= csr_wdata;
            exmem_rvcq[0]   <= idex_rvcq[0];

            // lane1 只在"lane0 是分支"时被杀 (lane0 更老, lane1 更年轻)。
            // lane1 自己是分支时不能被自己的 redirect_ex1 杀掉: 它要写 rd (jal 的 ra),
            // 否则 `jal puts_` 不写 ra, 函数 ret 时跳回 0x46 死循环。
            exmem_v[1]      <= idex_v[1] & ~(trap0 | trap1 | redirect_ex0);
            exmem_pc[1]     <= idex_pc[1];
            exmem_raw[1]    <= idex_raw[1];
            exmem_res[1]    <= x1_result;
            exmem_wbd[1]    <= x1_wb;
            exmem_sdata[1]  <= x_rs2[1];
            exmem_rdq[1]    <= idex_rdq[1];
            exmem_rdweq[1]  <= idex_rdweq[1];
            exmem_wbsq[1]   <= idex_wbsq[1];
            exmem_mrdq[1]   <= 1'b0;
            exmem_mwrq[1]   <= 1'b0;
            exmem_mszq[1]   <= `MSIZE_W;
            exmem_munsq[1]  <= 1'b0;
            exmem_excq[1]   <= x1_exc;
            exmem_cause[1]  <= x1_cause;
            exmem_tval[1]   <= x1_tval;
            exmem_csrr[1]   <= 32'd0;
            exmem_csrw[1]   <= 1'b0;
            exmem_csra[1]   <= 12'd0;
            exmem_csrd[1]   <= 32'd0;
            exmem_rvcq[1]   <= idex_rvcq[1];

            // ---------------------------- MEM/WB -----------------------------
            memwb_v[0]     <= exmem_v[0] & ~trap0;
            memwb_pc[0]    <= exmem_pc[0];
            memwb_raw[0]   <= exmem_raw[0];
            memwb_data[0]  <= (exmem_wbsq[0] == `WB_MEM)
                            ? (exmem_aged ? load_q : ls_rdata)
                            : exmem_wbd[0];
            memwb_rdq[0]   <= exmem_rdq[0];
            memwb_rdweq[0] <= exmem_rdweq[0] & ~exmem_excq[0] & ~mem_err_eff;
            memwb_csrw[0]  <= exmem_csrw[0] & ~exmem_excq[0] & ~mem_err_eff;
            memwb_csra[0]  <= exmem_csra[0];
            memwb_csrd[0]  <= exmem_csrd[0];

            memwb_v[1]     <= exmem_v[1] & ~trap0 & ~trap1;
            memwb_pc[1]    <= exmem_pc[1];
            memwb_raw[1]   <= exmem_raw[1];
            memwb_data[1]  <= exmem_wbd[1];
            memwb_rdq[1]   <= exmem_rdq[1];
            memwb_rdweq[1] <= exmem_rdweq[1] & ~exmem_excq[1];
            memwb_csrw[1]  <= 1'b0;
            memwb_csra[1]  <= 12'd0;
            memwb_csrd[1]  <= 32'd0;

            // store 前递记录
            stf_valid <= exmem_v[0] & exmem_mwrq[0] & ~exmem_excq[0];
            stf_word  <= exmem_res[0][31:2];
            stf_be    <= ls_be;
            stf_data  <= ls_wdata;
        end
    end

    // 载入数据锁存: 不能放进 !freeze, 否则冻结期间数据丢失
    always @(posedge clk) begin
        if (rst) begin
            exmem_aged <= 1'b0;
            load_q     <= 32'd0;
        end else begin
            exmem_aged <= freeze;
            if (exmem_v[0] & exmem_mrdq[0] & ~exmem_aged & ~exmem_excq[0])
                load_q <= ls_rdata;
        end
    end

    // =========================================================================
    // 统计 (只给仿真看, 综合会被裁掉)
    // =========================================================================
    reg [31:0] perf_issue, perf_pair, perf_stall_load;

    always @(posedge clk) begin
        if (rst) begin
            perf_issue      <= 32'd0;
            perf_pair       <= 32'd0;
            perf_stall_load <= 32'd0;
        end else if (!freeze) begin
            perf_issue      <= perf_issue + {30'd0, pop_n};
            perf_pair       <= perf_pair + ((pop_n == 2'd2) ? 32'd1 : 32'd0);
            perf_stall_load <= perf_stall_load + (stall_all ? 32'd1 : 32'd0);
        end
    end

    assign commit_valid  = memwb_v[0] & ~freeze;
    assign commit_pc     = memwb_pc[0];
    assign commit_instr  = memwb_raw[0];
    assign commit_valid1 = memwb_v[1] & ~freeze;
    assign commit_pc1    = memwb_pc[1];
    assign commit_instr1 = memwb_raw[1];
endmodule
