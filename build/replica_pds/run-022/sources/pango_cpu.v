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
    // 只是探针: 喂给 TB 做「指令级架构对账」, 不参与任何控制。
    // 带 rd/we/wdata 才能和"同一程序的另一遍"逐条比对 —— 只比 pc/instr
    // 看不出"指令都对但算错了数"(P10 的现状就是这样)。
    output wire        commit_valid,
    output wire [31:0] commit_pc,
    output wire [31:0] commit_instr,
    output wire [4:0]  commit_rd,
    output wire        commit_we,
    output wire [31:0] commit_wdata,
    output wire        commit_valid1,
    output wire [31:0] commit_pc1,
    output wire [31:0] commit_instr1,
    output wire [4:0]  commit_rd1,
    output wire        commit_we1,
    output wire [31:0] commit_wdata1
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

    // ---- 分支预测 (P10 第一版: BTB + 2 位计数器 + RAS) ----
    // CFG_BTB 关掉时 pred_taken_raw/pred_target_raw 被钉成常量 (见下面的例化处),
    // 这两个别名也就恒为 0 —— 不用再套一层 ifdef。
    wire        pred_taken_raw;
    wire [31:0] pred_target_raw;
    wire        pred_taken  = pred_taken_raw;
    wire [31:0] pred_target = pred_target_raw;
    // 训练侧信号先在这里声明 (Verilog: 先用后声明会产生隐式网)
    wire        bupd_en, bupd_taken, bupd_call, bupd_ret, bupd_sel;
    wire [31:0] bupd_pc, bupd_target, bupd_link;
    wire [31:0] perf_bpred;

`ifdef CFG_BTB
    core_branch_predictor u_bpred (
        .clk        (clk),
        .rst        (rst),
        .lookup_pc  (al_cur_pc),
        .pred_taken (pred_taken_raw),
        .pred_target(pred_target_raw),
        .upd_en     (bupd_en),
        .upd_pc     (bupd_pc),
        .upd_taken  (bupd_taken),
        .upd_target (bupd_target),
        .upd_is_call(bupd_call),
        .upd_is_ret (bupd_ret),
        .upd_link   (bupd_link),
        .perf_pred  (perf_bpred)
    );

`else
    // 关闭时不例化预测器: 让综合器连表带逻辑一起省掉 (实测不省会多 ~360 LUT
    // 且 120 MHz 的 WNS 从 −1.712 掉到 −2.081, 见 pds-status.md run-011)。
    assign pred_taken_raw  = 1'b0;
    assign pred_target_raw = 32'd0;
`endif

    core_instruction_aligner u_aligner (
        .clk          (clk),
        .rst          (rst),
        .redirect     (any_redirect),
        .redirect_pc  (redirect_pc),
        .pred_taken   (pred_taken),
        .pred_target  (pred_target),
        .space        (db_space),
        .consume      (1'b1),
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
    wire        db_q0_pred, db_q1_pred;
    wire [15:0] db_q0_predtgt, db_q1_predtgt;

    core_dispatch_buffer u_dbuf (
        .clk      (clk),
        .rst      (rst),
        .flush    (any_redirect),
        .push_n   (al_out_n),
        .p0_pc    (al_pc0), .p0_instr (al_i0), .p0_raw (al_r0),
        .p0_rvc   (al_rvc0), .p0_ill  (al_ill0),
        .p0_pred  (al_out_n != 2'd0 && pred_taken), .p0_predtgt (pred_target[15:0]),
        .p1_pc    (al_pc1), .p1_instr (al_i1), .p1_raw (al_r1),
        .p1_rvc   (al_rvc1), .p1_ill  (al_ill1),
        .space    (db_space),
        .pop_n    (pop_n),
        .count    (db_count),
        .q0_v     (db_q0_v), .q0_pc (db_q0_pc), .q0_instr (db_q0_instr),
        .q0_raw   (db_q0_raw), .q0_rvc (db_q0_rvc), .q0_ill (db_q0_ill),
        .q0_pred  (db_q0_pred), .q0_predtgt (db_q0_predtgt),
        .q1_pred  (db_q1_pred), .q1_predtgt (db_q1_predtgt),
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
    reg         idex_predq [0:1];       // 这条在取指时被预测为"跳"
    reg  [15:0] idex_predtgt[0:1];      // 预测目标 (低 16 位, 高位恒 0x8000)

    // =========================================================================
    // Load 的符号/字节扩展结果 (LSU 组合输出)。前递要用到它,
    // 所以声明放在这里而不是 LSU 那一段 —— 它在这之前就被 operand_select 引用了。
    wire [31:0] ls_rdata;

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

    // ★ Load-use 停顿: ALU 消费者已经完全不用停 (数据在 EX/MEM 那拍就前递到)。
    //   只有一种情况必须停: 消费者是 Load, 而地址要等上一条 Load 的数据 ——
    //   地址走的是"早期地址"通路, 故意不接 Load 旁路 (否则 RAM 地址脚成为
    //   最长路径), 所以这一拍要等值走到 MEM/WB。
    //   Store 不用停: 它的地址取的是已寄存的 exmem_res, 数据走 ALU 的旁路。
`ifdef CFG_LD_BYPASS
    wire stall_addr = ld_ex & db_q0_v & d_mrd[0] & use0;
    wire stall_all  = stall_addr;
    wire stall_pair = 1'b0;
`else
    wire stall_all  = ld_ex & db_q0_v & use0;
    wire stall_pair = ld_ex & use1 & ~use0;
`endif

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
    // ★ Load 也要能当 EX/MEM 旁的旁路源 (P09 的核心)。
    //   时序: ID/EX 在 T 拍把地址交给 RAM, RAM 在 T 拍末尾就把数据打了回来,
    //   所以 T+1 拍 (Load 在 EX/MEM、消费者在 EX) `ls_rdata` 已经有效 ——
    //   消费者直接用, 不必停一拍等它走到 MEM/WB。
    //   原来 `~exmem_mrdq[0]` 把 Load 排除在外, 那一拍停顿纯属白停。
`ifdef CFG_LD_BYPASS
    wire        m0_fw   = exmem_v[0] & exmem_rdweq[0] & ~exmem_excq[0];
    wire [31:0] m0_data = exmem_mrdq[0] ? (exmem_aged ? load_q : ls_rdata)
                                        : exmem_wbd[0];
`else
    // 关闭时退回原语义: Load 的数据只从 MEM/WB 前递
    wire        m0_fw   = exmem_v[0] & exmem_rdweq[0] & ~exmem_mrdq[0] & ~exmem_excq[0];
    wire [31:0] m0_data = exmem_wbd[0];
`endif
    wire w1_fw = memwb_v[1] & memwb_rdweq[1];
    wire w0_fw = memwb_v[0] & memwb_rdweq[0];

    // ★ 早期地址通路 (参考设计的 "early address" 分工)。
    //   访存地址不走带 Load 旁路的那个 mux: 如果把刚回来的 Load 数据也接进
    //   地址选择, `RAM 输出 -> mux -> 加法器 -> RAM 地址脚` 会连成一条长路径
    //   (实测 17.233 ns, 布线占 85%), 频率从 86 掉到 67 MHz —— 赚的 6% 拍数
    //   还不够赔的。
    //   所以地址单独一条: 4 个源 (EX/MEM 非 Load、MEM/WB x2、寄存器堆) + 专用加法器。
    //   Load 结果紧跟 Load 地址这种极罕见的情况靠 stall_addr 停一拍, 此时值已经
    //   走到 MEM/WB, 这条较短的 mux 也能取到。
    wire [31:0] a_rs1_0;
    wire        m0a_fw = exmem_v[0] & exmem_rdweq[0] & ~exmem_mrdq[0] & ~exmem_excq[0];

    core_operand_select u_sel10_addr (
        .rf_data (rf_rd1), .rf_addr (idex_rs1q[0]),
        .s0_we (m1_fw),  .s0_rd (exmem_rdq[1]), .s0_data (exmem_wbd[1]),
        .s1_we (m0a_fw), .s1_rd (exmem_rdq[0]), .s1_data (exmem_wbd[0]),
        .s2_we (w1_fw),  .s2_rd (memwb_rdq[1]), .s2_data (memwb_data[1]),
        .s3_we (w0_fw),  .s3_rd (memwb_rdq[0]), .s3_data (memwb_data[0]),
        .data   (a_rs1_0)
    );

    // 访存指令的 ALU 运算恒为 rs1 + imm, 所以地址 = a_rs1_0 + imm
    wire [31:0] addr_alu = a_rs1_0 + x_src2[0];

    core_operand_select u_sel10 (
        .rf_data (rf_rd1), .rf_addr (idex_rs1q[0]),
        .s0_we (m1_fw), .s0_rd (exmem_rdq[1]), .s0_data (exmem_wbd[1]),
        .s1_we (m0_fw), .s1_rd (exmem_rdq[0]), .s1_data (m0_data),
        .s2_we (w1_fw), .s2_rd (memwb_rdq[1]), .s2_data (memwb_data[1]),
        .s3_we (w0_fw), .s3_rd (memwb_rdq[0]), .s3_data (memwb_data[0]),
        .data   (x_rs1[0])
    );
    core_operand_select u_sel20 (
        .rf_data (rf_rd2), .rf_addr (idex_rs2q[0]),
        .s0_we (m1_fw), .s0_rd (exmem_rdq[1]), .s0_data (exmem_wbd[1]),
        .s1_we (m0_fw), .s1_rd (exmem_rdq[0]), .s1_data (m0_data),
        .s2_we (w1_fw), .s2_rd (memwb_rdq[1]), .s2_data (memwb_data[1]),
        .s3_we (w0_fw), .s3_rd (memwb_rdq[0]), .s3_data (memwb_data[0]),
        .data   (x_rs2[0])
    );
    core_operand_select u_sel11 (
        .rf_data (rf_rd3), .rf_addr (idex_rs1q[1]),
        .s0_we (m1_fw), .s0_rd (exmem_rdq[1]), .s0_data (exmem_wbd[1]),
        .s1_we (m0_fw), .s1_rd (exmem_rdq[0]), .s1_data (m0_data),
        .s2_we (w1_fw), .s2_rd (memwb_rdq[1]), .s2_data (memwb_data[1]),
        .s3_we (w0_fw), .s3_rd (memwb_rdq[0]), .s3_data (memwb_data[0]),
        .data   (x_rs1[1])
    );
    core_operand_select u_sel21 (
        .rf_data (rf_rd4), .rf_addr (idex_rs2q[1]),
        .s0_we (m1_fw), .s0_rd (exmem_rdq[1]), .s0_data (exmem_wbd[1]),
        .s1_we (m0_fw), .s1_rd (exmem_rdq[0]), .s1_data (m0_data),
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

    // =========================================================================
    // 分支预测训练 (EX 定案那一拍)
    // =========================================================================
    // lane0 是分支时用 lane0 (配对规则保证同拍不会两条都是分支)
    wire x0_iscf = idex_v[0] & (idex_brq[0] | idex_jalq[0] | idex_jalrq[0]);
    wire x1_iscf = idex_v[1] & (idex_brq[1] | idex_jalq[1] | idex_jalrq[1]);
    assign bupd_sel    = x0_iscf | ~x1_iscf;      // 1 = lane0
    assign bupd_en     = (x0_iscf | x1_iscf) & ~mdu_stall;
    assign bupd_pc     = bupd_sel ? idex_pc[0] : idex_pc[1];
    assign bupd_target = bupd_sel ? br_tgt[0]  : br_tgt[1];
    assign bupd_taken  = bupd_sel ? br_tk[0]   : br_tk[1];
    assign bupd_link   = bupd_sel ? x0_pc4     : x1_pc4;

    // call: jal / jalr 且 rd ∈ {x1, x5};  ret: jalr 且 rd==x0 且 rs1 ∈ {x1, x5}
    // ★ 不能用 rd_we 判 "是不是 call": 译码器对 jal/jalr 无条件置 rd_we=1
    //   (写 x0 由寄存器堆自己忽略), 于是 `c.j` / `j` 也会被当成 call,
    //   RAS 被无意义地压栈, 之后所有 ret 的预测目标全错。
    //   必须看目的寄存器号本身。
    wire b0_call = (idex_jalq[0]  & (idex_rdq[0] != 5'd0)) |
                   (idex_jalrq[0] & (idex_rdq[0] != 5'd0) &
                    ((idex_rdq[0] == 5'd1) | (idex_rdq[0] == 5'd5)));
    wire b1_call = (idex_jalq[1]  & (idex_rdq[1] != 5'd0)) |
                   (idex_jalrq[1] & (idex_rdq[1] != 5'd0) &
                    ((idex_rdq[1] == 5'd1) | (idex_rdq[1] == 5'd5)));
    wire b0_ret  = idex_jalrq[0] & (idex_rdq[0] == 5'd0) &
                   ((idex_rs1q[0] == 5'd1) | (idex_rs1q[0] == 5'd5));
    wire b1_ret  = idex_jalrq[1] & (idex_rdq[1] == 5'd0) &
                   ((idex_rs1q[1] == 5'd1) | (idex_rs1q[1] == 5'd5));
    assign bupd_call   = bupd_sel ? b0_call : b1_call;
    assign bupd_ret    = bupd_sel ? b0_ret  : b1_ret;


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

    // ★ 取 Load 地址不能走 x0_result: 那是 {mdu, 移位, alu} 三选一,
    //   对 Load 来说 mdu/移位恒为 0, 结果就是 alu_r。少一级 32 位 mux 直接
    //   落在最差路径上 (PDS run-005: idex_rs1q[0][4] -> RAM ADA0, 12.773 ns)。
`ifdef CFG_LD_BYPASS
    assign dmem_raddr = addr_alu;      // 早期地址: 不含 Load 数据的那条旁路
`else
    assign dmem_raddr = alu_r[0];
`endif
    assign dmem_ren   = idex_v[0] & idex_mrdq[0] & ~x0_exc;
    assign dmem_waddr = exmem_res[0];
    assign dmem_be    = ls_be;
    assign dmem_wdata = ls_wdata;

    // ★ Store 必须"只写一次"。
    //   freeze 会把 MEM 级一起冻住 (乘除 34 拍、访存未 ready), 而 dmem_wen 是
    //   组合的, 冻结期间一直是 1 —— 对 RAM 无害 (同址同数据幂等), 对 MMIO 就是
    //   灾难: 一个 UART 字节被写 34 次, 输出变成 "SSMMOOKE"。
    //   V1 有同一个隐患, 只是实测负载里"紧跟 div 前一条是 store"没出现, 没炸。
    //   判据: 同一个 MEM 槽里、同一条 store (用 pc 认身份) 已经写过就不再写。
    //   两条不同的 store 指令 pc 一定不同; 同一条 store 不可能连续两拍占 MEM
    //   槽 (中间至少隔一条指令), 所以 pc 足以区分。
    reg        st_written;
    reg [31:0] st_pc_q;
    wire       st_in_mem  = exmem_v[0] & exmem_mwrq[0];
    wire       st_repeat  = st_in_mem & st_written & (exmem_pc[0] == st_pc_q);
    wire       dmem_wen_i = st_in_mem & ~exmem_excq[0] & ~st_repeat;

    assign dmem_wen = dmem_wen_i;

    always @(posedge clk) begin
        if (rst) begin
            st_written <= 1'b0;
            st_pc_q    <= 32'hFFFF_FFFF;
        end else if (!st_in_mem) begin
            st_written <= 1'b0;
            st_pc_q    <= 32'hFFFF_FFFF;
        end else if (dmem_wen_i) begin
            st_written <= 1'b1;
            st_pc_q    <= exmem_pc[0];
        end
    end

    assign dmem_stall = (dmem_ren | dmem_wen) & ~dmem_ready;

    // =========================================================================
    // 重定向 / 中断 (必须先算出来, trap 段要用)
    // =========================================================================
    // ---- 预测核对 (P10) ----
    // 预测"跳"且真跳到同一目标 -> 前端早已在目标上, 不要再重定向 (这就是收益);
    // 预测"跳"但实际不跳 -> 必须把前端拉回顺序路径 (pc+len)。
    wire        x0_iscf0  = idex_brq[0] | idex_jalq[0] | idex_jalrq[0];
    wire [31:0] x0_ptgt   = {16'h8000, idex_predtgt[0]};
    wire        x0_pred_ok  = idex_predq[0] & x0_iscf0 & br_tk[0] & (br_tgt[0] == x0_ptgt);

    wire        x1_iscf0  = idex_brq[1] | idex_jalq[1] | idex_jalrq[1];
    wire [31:0] x1_ptgt   = {16'h8000, idex_predtgt[1]};
    wire        x1_pred_ok  = idex_predq[1] & x1_iscf0 & br_tk[1] & (br_tgt[1] == x1_ptgt);

    // ---- 预测纠错 (完备形式) ------------------------------------------------
    //   pred_fix: 这条被预测过, 但实际结果与预测不一致 —— 包含三类:
    //     1) 预测跳, 实际不跳                -> 回 pc+len
    //     2) 预测跳, 实际跳但目标不同        -> 去实际目标 (JALR 尤其常见)
    //     3) 预测跳, 但这条根本不是控制流    -> BTB 误命中, 必须回 pc+len
    //   第 3 类以前没人管: pred_ok/pred_bad 都要求 iscf, 于是误命中之后
    //   前端一路留在假目标上, 直到下一次分支才被发现。
    //   没被预测过就退回老语义: 只有 br_tk 才重定向。
    wire        x0_pred_fix = idex_predq[0] & ~x0_pred_ok;
    wire        x1_pred_fix = idex_predq[1] & ~x1_pred_ok;

    wire        x0_need = x0_pred_fix | (~idex_predq[0] & x0_iscf0 & br_tk[0]);
    wire        x1_need = x1_pred_fix | (~idex_predq[1] & x1_iscf0 & br_tk[1]);

    wire redirect_ex0 = idex_v[0] & (x0_need | idex_mretq[0]) & ~mdu_stall;
    // lane0 有例外时不接受 lane1 的分支重定向: 老指令的例外优先定案
    wire redirect_ex1 = idex_v[1] & x1_need & ~redirect_ex0 & ~x0_exc;

    // 目标: 真跳了就去实际目标, 没跳就回顺序下一条
    wire [31:0] x0_rpc = br_tk[0] ? br_tgt[0] : x0_pc4;
    wire [31:0] x1_rpc = br_tk[1] ? br_tgt[1] : x1_pc4;


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
                       : redirect_ex0    ? x0_rpc
                       :                   x1_rpc;

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
        // ★ 冻结时必须连读输出一起冻住: 读地址是分发缓冲头部 (下一条),
        //   不是 ID/EX 里那条指令。见 integer_regfile.v 顶部注释。
        .hold (freeze),
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
                idex_predq[l]  <= 1'b0;
                idex_predtgt[l]<= 16'd0;

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
            // exmem_aged / load_q 不在这里复位: 它们由下面独立的 always 块驱动。
            // 同一个变量被两个 always 块赋值, PDS 综合会直接报
            // Verilog-4086 (ModelSim 容忍, 但这不是合法写法)。
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
            idex_predq[0]   <= db_q0_pred;
            idex_predtgt[0] <= db_q0_predtgt;

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
            idex_predq[1]   <= db_q1_pred;
            idex_predtgt[1] <= db_q1_predtgt;

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
    // P10 之前先把"空转拍是谁造成的"分开数清楚, 否则没法判断预测器值不值。
    reg  [31:0] perf_bhit;         // 其中预测正确的次数
    reg [31:0] perf_redirect;      // 重定向发生的拍数 (跳转/例外/中断)
    reg [31:0] perf_nofeed;        // 没冻结、没停顿、也没重定向, 但缓冲空 -> 前端饿死
    reg [31:0] perf_taken;         // 实际成立的分支/跳转次数

    always @(posedge clk) begin
        if (rst) begin
            perf_issue      <= 32'd0;
            perf_pair       <= 32'd0;
            perf_stall_load <= 32'd0;
            perf_redirect   <= 32'd0;
            perf_nofeed     <= 32'd0;
            perf_taken      <= 32'd0;
            perf_bhit       <= 32'd0;
        end else if (!freeze) begin
            perf_issue      <= perf_issue + {30'd0, pop_n};
            perf_pair       <= perf_pair + ((pop_n == 2'd2) ? 32'd1 : 32'd0);
            perf_stall_load <= perf_stall_load + (stall_all ? 32'd1 : 32'd0);
            perf_redirect   <= perf_redirect + (any_redirect ? 32'd1 : 32'd0);
            perf_nofeed     <= perf_nofeed +
                               ((pop_n == 2'd0) && !stall_all && !any_redirect
                                ? 32'd1 : 32'd0);
            perf_taken      <= perf_taken + ((redirect_ex0 | redirect_ex1) ? 32'd1 : 32'd0);
            perf_bhit       <= perf_bhit + ((x0_pred_ok | x1_pred_ok) ? 32'd1 : 32'd0);
        end
    end

    assign commit_valid  = memwb_v[0] & ~freeze;
    assign commit_pc     = memwb_pc[0];
    assign commit_instr  = memwb_raw[0];
    // 实际发生的写回 (x0 由寄存器堆忽略, 这里也按"没写"记, 便于对账)
    assign commit_rd     = memwb_rdq[0];
    assign commit_we     = wb0_ok & memwb_rdweq[0] & (memwb_rdq[0] != 5'd0);
    assign commit_wdata  = memwb_data[0];
    assign commit_valid1 = memwb_v[1] & ~freeze;
    assign commit_pc1    = memwb_pc[1];
    assign commit_instr1 = memwb_raw[1];
    assign commit_rd1    = memwb_rdq[1];
    assign commit_we1    = wb1_ok & memwb_rdweq[1] & (memwb_rdq[1] != 5'd0);
    assign commit_wdata1 = memwb_data[1];
endmodule
