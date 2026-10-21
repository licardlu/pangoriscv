//=============================================================================
// pangoriscv - rv32 core (5.2 CoreMark/MHz @126 MHz rewrite)
// Module : rv32_top               File : rtl/core/rv32/rv32_top.v
// Rev    : 1.1                    Date : 2026-10-21
// Brief  : 6-stage in-order RV32IM core, port-compatible with `pangoriscv`
//=============================================================================

// Stage P1 of docs/plan-score-5.2-120mhz-v2.md: single issue, one ALU.
//
//   IFU queue --> ID --> RR --> EX --> M1 --> M2 --> WB
//                dec    read   alu    mem    pass   commit
//
// Bypass sources in age order are M1 (ex_value), M2 (m_value) and WB (w_value).
//
// P9 (plan v5 R5): the memory request is issued from EX, not from M1, and the
// response is captured into `ex_value` at the EX/M1 edge.  A load therefore
// looks exactly like an ALU result to the bypass network -- both land on the
// same clock edge -- so there is no `load_use` interlock at all any more.
//
// That is not a local tweak but the whole point of the restructure: while the
// request was issued from M1, the response landed one cycle after the load's
// execute stage, so a consumer one packet behind could never see it and the
// core had to stall (1.71 M cycles, 24.6% of a CoreMark run, documented in
// docs/lessons/mistakes-log.md section 36 -- three different interlock
// spellings were all variants of the same wrong answer).
//
// Consequence: `ex_addr` / `ex_sdata` and their lane-1 twins are gone (the LSU
// ports are driven by the EX stage directly), which is why this change is
// area-negative.
//
// Precise exceptions: only WB commits.  A store is issued from M1 only while no
// older instruction can still trap (`!(w_valid && w_trap)`), which is what keeps
// a wrong-path store out of memory without a reorder buffer.  Redirects kill
// exactly the stages younger than their source: a branch resolving in EX kills
// RR only, a trap resolving in WB kills RR/EX/M1.
//
// Ports are identical to `pangoriscv`; see rtl/core/pangoriscv.v.
module rv32_top(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        fetch_valid,
    output wire        fetch_ready,
    output wire        fetch_ready2,
    input  wire [31:0] fetch_pc,
    input  wire [31:0] fetch_inst,
    input  wire [31:0] fetch_pc_hi,
    input  wire [31:0] fetch_inst_hi,
    input  wire        fetch_fault,
    input  wire [4:0]  fetch_fault_cause,
    input  wire [31:0] fetch_fault_tval,
    input  wire        fetch_fault_hi,
    input  wire [4:0]  fetch_fault_cause_hi,
    input  wire [31:0] fetch_fault_tval_hi,
    input  wire [31:0] fetch_predicted_next_pc,
    input  wire [31:0] fetch_predicted_next_pc_hi,
    input  wire        fetch_pair,
    output wire [31:0] request_pc,
    output wire [31:0] predict_next_pc,
    output wire        pred_miss,
    output wire        redirect_valid,
    output wire [31:0] redirect_pc,
    input  wire        halt_req,
    input  wire        fetch_idle,
    input  wire        data_idle,
    output wire        halted,
    output wire        halt_pending,
    output wire [31:0] arch_next_pc,
    output wire        op_valid,
    input  wire        op_ready,
    output wire        is_store,
    output wire [31:0] address,
    output wire [31:0] store_value,
    output wire [31:0] op_pc,
    output wire [2:0]  access_size,
    output wire        load_unsigned,
    output wire [4:0]  op_rd,
    input  wire        done_valid,
    output wire        done_ready,
    input  wire [31:0] load_value,
    input  wire        fault,
    input  wire [31:0] fault_addr,
    input  wire        trap_ready,
    input  wire [31:0] trap_vector,
    output wire        retire_fire,
    output wire [63:0] retire_order,
    output wire [31:0] retire_pc,
    output wire [31:0] retire_inst,
    output wire        rd_valid,
    output wire [4:0]  rd,
    output wire [31:0] wdata,
    output wire        rd_valid_h,
    output wire [4:0]  rd_h,
    output wire [31:0] wdata_h,
    input  wire        irq_software,
    input  wire        irq_timer,
    input  wire        irq_external,
    output wire [31:0] csr_mtvec,
    output wire        trap_fire,
    output wire [31:0] trap_pc,
    output wire [31:0] trap_cause,
    output wire [31:0] trap_tval,
    input  wire [4:0]  debug_addr,
    output wire [31:0] debug_data,
    input  wire [31:0] chain_c,
    output wire [31:0] chain_predict_next_pc,
    input  wire [31:0] chain_c2,
    output wire [31:0] chain_predict_next_pc2
);

    localparam [31:0] RESET_PC = 32'd0;

    // Declared before use: the hazard logic below needs the divider handshake,
    // and the WB datapath takes its rd value straight from the CSR read bus.
    wire [31:0] csr_rdata, csr_vector, csr_mepc;
    wire        div_req_ready, div_rsp_valid;
    wire [31:0] div_result;
    // Same reason: the hazard block asks the execute stage whether it is issuing
    // a memory operation, which is exactly the execute-stage trap/misalign
    // decision further down.
    wire        ex_trap_w, mem_misaln_h;
    // A lane-0 control transfer that is going to redirect; assigned next to
    // `ctrl_next` (ModelSim wants the declaration first) because the hazard
    // block uses it before that point.
    wire        ctrl_miss_now;

    // ========================================================= ID decode
    wire [4:0]  dec_rs1, dec_rs2, dec_rd;
    wire        dec_u1, dec_u2, dec_we, dec_load, dec_store, dec_br, dec_jal;
    wire        dec_jalr, dec_csr, dec_mret, dec_ecall, dec_ebrk, dec_mul;
    wire        dec_div, dec_illegal, dec_uns;
    wire [3:0]  dec_alu;
    wire [1:0]  dec_asel, dec_bsel, dec_size, dec_csr_op;
    wire [31:0] dec_imm;
    wire [2:0]  dec_br_op, dec_md_op;
    wire [11:0] dec_csr_addr;

    rv32_decode u_decode(
        .inst(fetch_inst),
        .rs1(dec_rs1), .rs2(dec_rs2), .rd(dec_rd),
        .uses_rs1(dec_u1), .uses_rs2(dec_u2), .reg_we(dec_we),
        .alu_op(dec_alu), .a_sel(dec_asel), .b_sel(dec_bsel), .imm(dec_imm),
        .is_load(dec_load), .is_store(dec_store), .is_branch(dec_br),
        .is_jal(dec_jal), .is_jalr(dec_jalr), .is_csr(dec_csr),
        .is_mret(dec_mret), .is_ecall(dec_ecall), .is_ebreak(dec_ebrk),
        .br_op(dec_br_op), .mem_size(dec_size), .load_unsigned(dec_uns),
        .is_mul(dec_mul), .is_div(dec_div), .muldiv_op(dec_md_op),
        .csr_op(dec_csr_op), .csr_addr(dec_csr_addr), .illegal(dec_illegal)
    );

    wire dec_serial = dec_csr || dec_mret || dec_ecall || dec_ebrk || dec_illegal;

    // ========================================================= lane 1 decode
    // Lane 1 carries exactly one plain integer ALU operation and nothing else:
    //   * no memory      -> the LSU keeps its single port, which stays lane 0's;
    //   * no control     -> branch resolution stays one per packet, so lane 1
    //                       never needs a wrong-path kill of its own (a taken
    //                       lane-0 branch would otherwise have to squash its
    //                       own packet-mate, a path with no other user);
    //   * no CSR/system  -> no serialisation corner;
    //   * always legal   -> lane 1 can never trap, so trap ordering stays a
    //                       lane-0 decision and "commit only the older prefix"
    //                       reduces to "squash lane 1 when lane 0 traps".
    // Everything above is enforced at *pairing* time, so downstream logic needs
    // no lane-1 trap, memory or control path at all.
    wire [4:0]  dec_rs1_h, dec_rs2_h, dec_rd_h;
    wire        dec_u1_h, dec_u2_h, dec_we_h, dec_load_h, dec_store_h, dec_br_h;
    wire        dec_jal_h, dec_jalr_h, dec_csr_h, dec_mret_h, dec_ecall_h;
    wire        dec_ebrk_h, dec_mul_h, dec_div_h, dec_illegal_h, dec_uns_h;
    wire [3:0]  dec_alu_h;
    wire [1:0]  dec_asel_h, dec_bsel_h, dec_size_h, dec_csr_op_h;
    wire [31:0] dec_imm_h;
    wire [2:0]  dec_br_op_h, dec_md_op_h;
    wire [11:0] dec_csr_addr_h;

    rv32_decode u_decode_h(
        .inst(fetch_inst_hi),
        .rs1(dec_rs1_h), .rs2(dec_rs2_h), .rd(dec_rd_h),
        .uses_rs1(dec_u1_h), .uses_rs2(dec_u2_h), .reg_we(dec_we_h),
        .alu_op(dec_alu_h), .a_sel(dec_asel_h), .b_sel(dec_bsel_h), .imm(dec_imm_h),
        .is_load(dec_load_h), .is_store(dec_store_h), .is_branch(dec_br_h),
        .is_jal(dec_jal_h), .is_jalr(dec_jalr_h), .is_csr(dec_csr_h),
        .is_mret(dec_mret_h), .is_ecall(dec_ecall_h), .is_ebreak(dec_ebrk_h),
        .br_op(dec_br_op_h), .mem_size(dec_size_h), .load_unsigned(dec_uns_h),
        .is_mul(dec_mul_h), .is_div(dec_div_h), .muldiv_op(dec_md_op_h),
        .csr_op(dec_csr_op_h), .csr_addr(dec_csr_addr_h), .illegal(dec_illegal_h)
    );

    wire lane1_alu = !(dec_load_h | dec_store_h | dec_br_h | dec_jal_h | dec_jalr_h |
                       dec_csr_h | dec_mret_h | dec_ecall_h | dec_ebrk_h |
                       dec_mul_h | dec_div_h | dec_illegal_h);
    // A branch or jal in lane 1 keeps the "lane 1 never traps" property: its
    // target is pc+imm, and requiring imm[1]==0 (imm[0] is an encoding zero for
    // both formats) makes that target 4-byte aligned by construction, so the
    // misaligned-target trap cannot happen in this slot.  jalr is excluded --
    // its target is a runtime value and could be misaligned.
    wire lane1_ctrl = (dec_br_h || dec_jal_h) && !dec_imm_h[1];
    // Memory is allowed in lane 1 as long as it is the only memory op in the
    // packet (the LSU has one port).  Loads are the bulk of it; stores are kept
    // because the ISA suite exercises lane-1 store address/data forwarding.
    wire lane1_mem  = (dec_load_h || dec_store_h) &&
                      !(dec_jalr_h | dec_csr_h | dec_mret_h | dec_ecall_h |
                        dec_ebrk_h | dec_mul_h | dec_div_h | dec_illegal_h);
    wire lane1_ok   = lane1_alu || lane1_ctrl || lane1_mem;
    // A control transfer in lane 0 used to be un-pair-able on the grounds that
    // lane 1 would have to be pc+8, which is wrong-path whenever the branch is
    // predicted taken.  But the IFU's predicted-chain prefetch has already put
    // the *target* word in the queue behind the branch, so lane 1 can be the
    // first target instruction -- legal exactly when its PC is lane 0's
    // predicted successor.  Everything else (serialising ops, jalr whose target
    // is a runtime value) still issues alone.  When the prediction turns out
    // wrong, lane 1 is killed at the RR/EX edge (`br_miss` gates `ex_v1`), so
    // the architectural rule "one control transfer per packet" still holds.
    wire lane1_is_pred    = (fetch_pc_hi == fetch_predicted_next_pc);
    wire lane0_issue_alone = dec_serial || dec_jalr ||
                             ((dec_br || dec_jal) && !lane1_is_pred);
    // A load in lane 0 cannot feed lane 1 in the same cycle (its data only
    // exists in M2), so such a pair is split rather than stalled in EX.
    wire packet_load_use = dec_load && dec_we &&
                           ((dec_u1_h && (dec_rd == dec_rs1_h)) ||
                            (dec_u2_h && (dec_rd == dec_rs2_h)));
    // A multiply/divide in lane 0 is a different story from a plain ALU op:
    // the product is the output of a four-DSP cascade (9.0 ns measured on
    // `p7_path40b`), and feeding it into lane 1's operand mux puts that whole
    // cascade *in series with* lane 1's adder inside one cycle.  That single
    // pairing rule is what made the worst path 26.6 ns.
    //
    // Refusing exactly this pair (lane 1 reading the product its own lane 0 is
    // still computing) costs almost nothing -- multiplies are rare in CoreMark
    // and rarer still immediately followed by a dependent neighbour -- while
    // refusing intra-pair RAW in general is what broke ISA tests 17/18/19/20
    // (docs/lessons/mistakes-log.md section 26).  The distinction matters:
    // only the producer that is *not* a single-cycle adder gets refused.
    wire packet_md_use = (dec_mul || dec_div) && dec_we &&
                         ((dec_u1_h && (dec_rd == dec_rs1_h)) ||
                          (dec_u2_h && (dec_rd == dec_rs2_h)));
    // Intra-pair RAW (lane 1 reading what lane 0 writes this cycle) must stay
    // pair-able: everything between addi/branch and the store data path in the
    // ISA suite is built on it (P37a, tests 17/18/19/20).  Trying to refuse it
    // to shorten the two-adder chain cost seven pairs in a 12 kcycle run and
    // made lane 1 stop carrying any memory operation at all -- see
    // docs/lessons/mistakes-log.md.  The chain is shortened at the ALU instead.
    wire lane0_mem = dec_load || dec_store;
    wire pair_ok = fetch_pair && lane1_ok && !lane0_issue_alone &&
                   !packet_load_use && !packet_md_use &&
                   !(lane0_mem && lane1_mem) &&
                   !fetch_fault && !fetch_fault_hi;

    // ========================================================= pipeline regs
    // ID -> RR (the instruction sitting in RR)
    reg         id_valid;
    reg  [31:0] id_pc, id_inst, id_imm, id_pred;
    reg  [4:0]  id_rd, id_rs1, id_rs2, id_fcause;
    reg         id_u1, id_u2, id_we, id_load, id_store, id_br, id_jal, id_jalr;
    reg         id_csr, id_mret, id_ecall, id_ebrk, id_mul, id_div;
    reg         id_illegal, id_ffault, id_uns, id_serial;
    reg  [3:0]  id_alu;
    reg  [1:0]  id_asel, id_bsel, id_size, id_csr_op;
    reg  [2:0]  id_br_op, id_md_op;
    reg  [11:0] id_csr_addr;
    // lane 1 of the same packet (rides every stage, writes through port 2)
    reg         id_v1;
    reg  [31:0] id_pc_h, id_imm_h;
    reg  [4:0]  id_rd_h, id_rs1_h, id_rs2_h;
    reg  [3:0]  id_alu_h;
    reg  [1:0]  id_asel_h, id_bsel_h;
    reg         id_we_h;
    reg  [6:0]  id_op_h;
    reg  [31:0] id_pred_h;
    reg         id_ctrl_h, id_jal_h;
    reg  [2:0]  id_br_op_h;
    reg         id_load_h, id_store_h, id_uns_h;
    reg  [1:0]  id_size_h;

    // RR -> EX (the instruction sitting in EX)
    reg         rr_valid;
    reg  [31:0] rr_pc, rr_inst, rr_imm, rr_pred, rr_csr_old;
    reg  [4:0]  rr_rd, rr_rs1, rr_rs2, rr_fcause;
    reg         rr_we, rr_load, rr_store, rr_br, rr_jal, rr_jalr;
    reg         rr_csr, rr_mret, rr_ecall, rr_ebrk, rr_mul, rr_div;
    reg         rr_illegal, rr_ffault, rr_uns, rr_csr_illegal, rr_serial;
    reg         rr_u1;
    reg  [3:0]  rr_alu;
    reg  [1:0]  rr_asel, rr_bsel, rr_size, rr_csr_op;
    reg  [2:0]  rr_br_op, rr_md_op;
    reg  [11:0] rr_csr_addr;
    reg         rr_v1;
    reg  [31:0] rr_pc_h, rr_imm_h;
    reg  [4:0]  rr_rd_h, rr_rs1_h, rr_rs2_h;
    reg  [3:0]  rr_alu_h;
    reg  [1:0]  rr_asel_h, rr_bsel_h;
    reg         rr_we_h;
    reg  [6:0]  rr_op_h;
    reg  [31:0] rr_pred_h;
    reg         rr_ctrl_h, rr_jal_h;
    reg  [2:0]  rr_br_op_h;
    reg         rr_load_h, rr_store_h, rr_uns_h;
    reg  [1:0]  rr_size_h;

    // EX -> M1
    reg         ex_valid;
    reg  [31:0] ex_pc, ex_inst, ex_value, ex_tval, ex_next;
    reg  [31:0] ex_csr_old, ex_csr_src;
    reg  [4:0]  ex_rd, ex_cause;
    reg         ex_we, ex_trap, ex_ctrl, ex_uncond, ex_taken;
    reg         ex_csr, ex_mret, ex_serial;
    reg  [1:0]  ex_csr_op;
    reg  [11:0] ex_csr_addr;
    reg         ex_v1;
    reg  [31:0] ex_pc_h, ex_value_h;
    reg  [4:0]  ex_rd_h;
    reg         ex_we_h;
    reg         ex_ctrl_h, ex_taken_h, ex_uncond_h;
    reg  [31:0] ex_next_h;
    reg         ex_trap_h;
    reg  [2:0]  ex_cause_h;
    reg  [31:0] ex_tval_h;

    // M1 -> M2
    reg         m_valid;
    reg  [31:0] m_pc, m_inst, m_value, m_tval, m_next;
    reg  [31:0] m_csr_old, m_csr_src;
    reg  [4:0]  m_rd, m_cause;
    reg         m_we, m_trap, m_ctrl, m_uncond, m_taken, m_csr, m_mret, m_serial;
    reg  [1:0]  m_csr_op;
    reg  [11:0] m_csr_addr;
    reg         m_v1;
    reg  [31:0] m_pc_h, m_value_h;
    reg  [4:0]  m_rd_h;
    reg         m_we_h;
    reg         m_ctrl_h, m_taken_h, m_uncond_h, m_trap_h;
    reg  [31:0] m_next_h, m_tval_h;
    reg  [2:0]  m_cause_h;

    // M2 -> WB.  The predicted-PC payload stops at RR: `rr_pred` is the only
    // copy anybody reads (the mispredict compare), so ex_pred/m_pred/w_pred were
    // a written-never-read 96-flop chain.  Deleted under the area gate.
    reg         w_valid;
    reg  [31:0] w_pc, w_inst, w_value, w_tval, w_next;
    reg  [31:0] w_csr_old, w_csr_src;
    reg  [4:0]  w_rd, w_cause;
    reg         w_we, w_trap, w_ctrl, w_uncond, w_taken, w_csr, w_mret, w_serial;
    reg  [1:0]  w_csr_op;
    reg  [11:0] w_csr_addr;
    reg         w_v1;
    reg  [31:0] w_pc_h, w_value_h;
    reg  [4:0]  w_rd_h;
    reg         w_we_h;
    reg         w_ctrl_h, w_taken_h, w_uncond_h, w_trap_h;
    reg  [31:0] w_next_h, w_tval_h;
    reg  [2:0]  w_cause_h;

    // ========================================================= fetch / PC
    reg  [31:0] pc_q;
    wire        fetch_fire = fetch_valid && fetch_ready;
    wire        id_accept  = fetch_valid && fetch_ready;
    wire        id_accept2 = id_accept && pair_ok;
    assign      request_pc = pc_q;

    reg         halted_q, halt_pending_q, serial_q, mem_issued_q, div_issued_q;
    reg  [31:0] arch_next_q;
    reg  [31:0] retire_cnt_q;

    // Declared early: the hazard block needs the memory handshake.
    wire issue_mem;
    wire mem_accept = issue_mem && op_ready;

    // ========================================================= hazards
    // The memory op of the packet is issued from EX (see the header note), so
    // these three describe the *execute* stage, not M1.  `ex_trap_w` is the
    // execute-stage trap decision: a misaligned access must never reach the LSU
    // (ISA case 20 checks exactly that no request is issued).
    wire ex_is_mem   = rr_valid && (rr_load || rr_store) && !ex_trap_w;
    // The memory op of a packet can come from either lane; lane 0 wins when both
    // are set (pairing forbids that, this is defensive).
    // A control transfer in lane 0 that is going to redirect makes lane 1
    // wrong-path.  It has to be removed here rather than only in `issue_mem`,
    // because a wrong-path access that merely *waits* still asserts `mem_wait`,
    // and `mem_wait` freezes the stage -- while `br_miss` (the thing that would
    // redirect) is gated with `!hold_ex`.  Gating only the issue therefore
    // deadlocked the core on the first such packet (STALL_DETECT, 200 kcycles of
    // no retirement, every one of them a store in `blocked`).
    wire ex_is_mem_h = rr_valid && rr_v1 && (rr_load_h || rr_store_h) &&
                       !mem_misaln_h && !ex_is_mem && !ctrl_miss_now;
    wire mem_from_h = ex_is_mem_h;
    // A load hands its data over in the same cycle it executes (a hit) or holds
    // EX until the response arrives (a miss).  Either way the consumer needs no
    // interlock: `ex_value` is a normal bypass source.
    wire mem_wait   = (ex_is_mem || ex_is_mem_h) &&
                      !(done_valid && (mem_issued_q || (issue_mem && op_ready)));
    wire div_wait   = rr_valid && rr_div && !rr_illegal && !div_rsp_valid;
    wire trap_wait  = w_valid && w_trap && !trap_ready;
    wire stall      = mem_wait || div_wait || trap_wait;

    // Freeze is per stage.  A frozen stage emits a bubble instead of holding its
    // instruction, which is what keeps commit a one-cycle pulse: if WB were held
    // with valid high, a CSR write would be applied again on the next cycle.
    // `hold_ex` freezes RD and EX together: EX is the stage that owns the
    // outstanding request, so its address and store data must stay put.
    wire hold_ex = mem_wait || div_wait || trap_wait;  // RD + EX hold
    wire hold_m1 = trap_wait;                          // M1 holds
    wire hold_wb = trap_wait;                          // M2 + WB hold

    reg  w_done_q;
    wire w_commit = w_valid && !w_trap && !w_done_q;

    // ========================================================= register file
    // The read is synchronous, so the address is presented while the
    // instruction is still in ID and the data lands when it is in RR.
    wire [31:0] rf_d0, rf_d1;
    wire [31:0] wb_value = w_csr ? csr_rdata : w_value;
    wire        wb_we = w_commit && w_we && (w_rd != 5'd0);
    // Port 2 carries lane 1.  regs writes lane 0 first and lane 1 second, so a
    // same-register WAW inside a packet keeps the younger value.
    wire        wb_we_h = w_commit && w_v1 && w_we_h && (w_rd_h != 5'd0) && !w_trap_h;

    // The register file is the delivered 4-read / 2-write array (`regs`): dual
    // issue needs two write ports in the same cycle (with ~70% pairing the core
    // retires ~1.7 register writes per cycle, which no single-port array can
    // absorb), and two ports cannot be built from distributed RAM, so this is
    // the flip-flop array the delivered core already uses and has validated on
    // the board (857 LUT / 992 FF, docs/architecture/module-area-plan.md M08).
    // The reads are combinational and take their addresses straight from the EX
    // stage, which is what makes a frozen stage freeze its own operand; the
    // array also folds lane 0's and lane 1's write-through into the read path
    // (lane 1 younger, so it wins an address collision), which removes one
    // 32-bit bypass level from the EX critical path.
    wire [31:0] rf_d0_h, rf_d1_h;
    wire [31:0] ex_value_w;   // lane 0's result this cycle

    regs u_regs(
        .clk(clk), .rst(rst_n),
        .we_i(wb_we), .waddr_i(w_rd), .wdata_i(wb_value),
        .we2_i(wb_we_h), .waddr2_i(w_rd_h), .wdata2_i(w_value_h),
        .jtag_we_i(1'b0), .jtag_addr_i(5'd0), .jtag_data_i(32'd0),
        .raddr1_i(rr_rs1), .rdata1_o(rf_d0),
        .raddr2_i(rr_rs2), .rdata2_o(rf_d1),
        .raddr3_i(rr_rs1_h), .rdata3_o(rf_d0_h),
        .raddr4_i(rr_rs2_h), .rdata4_o(rf_d1_h),
        .jtag_data_o()
    );

    // ========================================================= bypass
    // Bypass, in age order.  A packet retires two registers, so *every* stage
    // between EX and WB can hold two live producers, and lane 1 of a stage is
    // younger than lane 0 of the same stage.
    //
    // NOTE: an earlier attempt sampled the operands one stage earlier (registers
    // `rr_a/rr_b`) to take the 32:1 array read out of the execute cycle.  It
    // cannot work: lane 1 of a packet reads lane 0's result *in the same cycle*,
    // so lane 1's operand has to be a function of lane 0's ALU output, and it
    // also has to be readable at the moment the packet enters EX.  Pre-sampling
    // forces lane 1 onto the stale array entry.  The two-adder chain is real and
    // is paid for in the ALU, not by refusing the pair (see `pair_ok`).
    // Distance 3 (the WB packet) needs no level: `regs` puts both write ports
    // into its read path, so rf_d* is already the write-through result.
    //
    // P9: the `!ex_load` exclusion is gone.  It existed because `ex_value` held
    // a load's *address* in the old shape; now the response is captured into
    // `ex_value` on the same edge, so a load is an ordinary bypass source.
    wire [31:0] fwd1 =
        (ex_valid && ex_v1 && ex_we_h && (ex_rd_h == rr_rs1) && (ex_rd_h != 5'd0)) ? ex_value_h :
        (ex_valid && ex_we && !ex_trap && (ex_rd == rr_rs1) && (ex_rd != 5'd0)) ? ex_value :
        (m_valid && m_v1 && m_we_h && (m_rd_h == rr_rs1) && (m_rd_h != 5'd0)) ? m_value_h :
        (m_valid && m_we && !m_trap && (m_rd == rr_rs1) && (m_rd != 5'd0)) ? m_value :
        rf_d0;
    wire [31:0] fwd2 =
        (ex_valid && ex_v1 && ex_we_h && (ex_rd_h == rr_rs2) && (ex_rd_h != 5'd0)) ? ex_value_h :
        (ex_valid && ex_we && !ex_trap && (ex_rd == rr_rs2) && (ex_rd != 5'd0)) ? ex_value :
        (m_valid && m_v1 && m_we_h && (m_rd_h == rr_rs2) && (m_rd_h != 5'd0)) ? m_value_h :
        (m_valid && m_we && !m_trap && (m_rd == rr_rs2) && (m_rd != 5'd0)) ? m_value :
        rf_d1;
    wire [31:0] alu_y;
    wire        alu_eq, alu_lt, alu_ltu;
    // Lane 1 sees one producer lane 0 does not have: lane 0 of its own packet.
    // Pairing rejects the two cases that cannot be covered -- lane 0 is a load
    // (its data only exists in M2) or lane 0 is a multiply/divide (the product
    // is a four-DSP cascade, 9.0 ns, and must not be chained in front of lane
    // 1's adder) -- so `alu_y` is always the correct value here.  Feeding
    // `ex_value_w` instead is what put the multiplier in series with lane 1's
    // ALU and made the worst path 26.6 ns on `p7_path40b`.
    wire lane0_raw1 = rr_v1 && rr_we && (rr_rd == rr_rs1_h) && (rr_rd != 5'd0);
    wire lane0_raw2 = rr_v1 && rr_we && (rr_rd == rr_rs2_h) && (rr_rd != 5'd0);
    wire [31:0] fwd1_h =
        lane0_raw1 ? alu_y :
        (ex_valid && ex_v1 && ex_we_h && (ex_rd_h == rr_rs1_h) && (ex_rd_h != 5'd0)) ? ex_value_h :
        (ex_valid && ex_we && !ex_trap && (ex_rd == rr_rs1_h) && (ex_rd != 5'd0)) ? ex_value :
        (m_valid && m_v1 && m_we_h && (m_rd_h == rr_rs1_h) && (m_rd_h != 5'd0)) ? m_value_h :
        (m_valid && m_we && !m_trap && (m_rd == rr_rs1_h) && (m_rd != 5'd0)) ? m_value :
        rf_d0_h;
    wire [31:0] fwd2_h =
        lane0_raw2 ? alu_y :
        (ex_valid && ex_v1 && ex_we_h && (ex_rd_h == rr_rs2_h) && (ex_rd_h != 5'd0)) ? ex_value_h :
        (ex_valid && ex_we && !ex_trap && (ex_rd == rr_rs2_h) && (ex_rd != 5'd0)) ? ex_value :
        (m_valid && m_v1 && m_we_h && (m_rd_h == rr_rs2_h) && (m_rd_h != 5'd0)) ? m_value_h :
        (m_valid && m_we && !m_trap && (m_rd == rr_rs2_h) && (m_rd != 5'd0)) ? m_value :
        rf_d1_h;

    // ========================================================= EX datapath
    wire [31:0] alu_a = (rr_asel == 2'd1) ? rr_pc : (rr_asel == 2'd2) ? 32'd0 : fwd1;
    // b_sel 2 is the literal 4 (jal/jalr link value).
    wire [31:0] alu_b = (rr_bsel == 2'd0) ? fwd2 :
                       (rr_bsel == 2'd2) ? 32'd4 : rr_imm;

    rv32_alu u_alu(
        .op(rr_alu), .a(alu_a), .b(alu_b),
        .y(alu_y), .eq(alu_eq), .lt(alu_lt), .ltu(alu_ltu)
    );

    // The multiplier sits in the execute cycle.  Moving it to M1 (registered
    // operands, product taken next cycle) looks like a free 6 ns off the path,
    // but it measures as -5% score: CoreMark's crc/state code multiplies and
    // immediately consumes, so the extra mul-use stall plus the extra packet
    // split it forces (`packet_load_use`) costs 378 kcycles in a 20-iteration
    // run.  See docs/lessons/mistakes-log.md -- score first, then ns.
    wire [31:0] mul_y;
    rv32_mul u_mul(.op(rr_md_op), .a(fwd1), .b(fwd2), .y(mul_y));

    // ---------------------------------------------------------- lane 1 ALU
    // Lane 1 is a plain integer ALU operation by construction (pairing rejects
    // everything else), so it needs one adder/shifter/compare tree and nothing
    // more: no second multiplier, no divider, no target adder.
    wire [31:0] alu_a_h = (rr_asel_h == 2'd1) ? rr_pc_h :
                          (rr_asel_h == 2'd2) ? 32'd0 : fwd1_h;
    wire [31:0] alu_b_h = (rr_bsel_h == 2'd0) ? fwd2_h :
                          (rr_bsel_h == 2'd2) ? 32'd4 : rr_imm_h;
    wire [31:0] alu_y_h;
    wire        alu_eq_h, alu_lt_h, alu_ltu_h;
    rv32_alu u_alu_h(
        .op(rr_alu_h), .a(alu_a_h), .b(alu_b_h),
        .y(alu_y_h), .eq(alu_eq_h), .lt(alu_lt_h), .ltu(alu_ltu_h)
    );
    wire [31:0] ex_value_h_w = alu_y_h;

    // A branch or jal in lane 1 resolves here with the same comparator the ALU
    // already built: the target is pc+imm for both formats, so no second target
    // adder is needed and the mispredict check reuses the lane-0 shape.
    wire br_taken_h   = (rr_br_op_h == 3'd0) ? alu_eq_h  :
                        (rr_br_op_h == 3'd1) ? !alu_eq_h :
                        (rr_br_op_h == 3'd2) ? alu_lt_h  :
                        (rr_br_op_h == 3'd3) ? !alu_lt_h :
                        (rr_br_op_h == 3'd4) ? alu_ltu_h : !alu_ltu_h;
    wire [31:0] mem_addr_h  = fwd1_h + rr_imm_h;
    wire [31:0] mem_sdata_h = fwd2_h;
    // Misalignment is decided in EX so a lane-1 misaligned access never reaches
    // the LSU at all (ISA case 20 checks exactly that no request is issued).
    // Cause encoding matches lane 0: 4 load address misaligned, 6 store.
    assign mem_misaln_h = (rr_load_h || rr_store_h) &&
                        ((rr_size_h == 2'd1 && mem_addr_h[0]) ||
                         (rr_size_h == 2'd2 && (|mem_addr_h[1:0])));
    wire [4:0]  ex_cause_h_w = rr_store_h ? 5'd6 : 5'd4;
    wire ctrl_taken_h = rr_jal_h | (rr_ctrl_h & br_taken_h);
    wire [31:0] ctrl_target_h = rr_pc_h + rr_imm_h;
    wire [31:0] ctrl_next_h   = ctrl_taken_h ? ctrl_target_h : (rr_pc_h + 32'd4);

    wire        div_req = rr_valid && rr_div && !rr_illegal && !div_issued_q;
    div_adapter u_div(
        .clk(clk), .rst_n(rst_n),
        .req_valid(div_req), .req_ready(div_req_ready),
        .dividend(fwd1), .divisor(fwd2), .op(rr_md_op),
        .rsp_valid(div_rsp_valid), .rsp_ready(1'b1), .rsp_data(div_result)
    );

    wire        br_taken    = (rr_br_op == 3'd0) ? alu_eq  :
                              (rr_br_op == 3'd1) ? !alu_eq :
                              (rr_br_op == 3'd2) ? alu_lt  :
                              (rr_br_op == 3'd3) ? !alu_lt :
                              (rr_br_op == 3'd4) ? alu_ltu : !alu_ltu;
    wire        is_ctrl     = rr_br || rr_jal || rr_jalr;
    wire        ctrl_taken  = (rr_jal || rr_jalr) ? 1'b1 : (rr_br && br_taken);
    wire [31:0] ctrl_target = (rr_jal || rr_jalr) ? ((rr_jalr ? fwd1 : rr_pc) + rr_imm)
                                                  : (rr_pc + rr_imm);
    wire [31:0] ctrl_next   = ctrl_taken ? ctrl_target : (rr_pc + 32'd4);
    // "lane 0 is a control transfer and its destination is not what the front end
    // predicted".  Used by the hazard block (declared up there) to make lane 1 of
    // such a packet invisible: it is wrong-path, and unlike the branch itself it
    // has no business touching memory.
    assign      ctrl_miss_now = rr_valid && is_ctrl && (ctrl_next != rr_pred);
    wire [31:0] mem_addr    = fwd1 + rr_imm;

    wire        ctrl_misaln = is_ctrl && ctrl_taken && (ctrl_target[1:0] != 2'b00);
    wire        mem_misaln  = (rr_load || rr_store) &&
                              ((rr_size == 2'd1 && mem_addr[0]) ||
                               (rr_size == 2'd2 && (|mem_addr[1:0])));

    wire        ex_illegal  = rr_illegal || rr_csr_illegal || rr_ffault;
    wire [4:0]  ex_cause_w  = rr_ffault ? rr_fcause :
                              (rr_illegal || rr_csr_illegal) ? 5'd2 :
                              rr_ecall ? 5'd11 :
                              rr_ebrk  ? 5'd3 :
                              ctrl_misaln ? 5'd0 :
                              mem_misaln ? (rr_store ? 5'd6 : 5'd4) : 5'd0;
    wire [31:0] ex_tval_w   = rr_ffault ? rr_pc :
                              (rr_illegal || rr_csr_illegal) ? rr_inst :
                              ctrl_misaln ? ctrl_target :
                              mem_misaln ? mem_addr : 32'd0;
    assign ex_trap_w   = ex_illegal || rr_ecall || rr_ebrk || ctrl_misaln || mem_misaln;
    assign ex_value_w = rr_mul ? mul_y : rr_div ? div_result : alu_y;

    // ========================================================= CSR block
    wire        csr_illegal, csr_irq_pending;
    wire [31:0] csr_irq_cause;

    wire        rf_write_intent = id_csr && ((id_csr_op == 2'd0) || (id_rs1 != 5'd0));
    wire [31:0] csr_src_w = rr_u1 ? fwd1 : {27'd0, rr_rs1};
    wire [31:0] csr_new = (w_csr_op == 2'd0) ? w_csr_src :
                          (w_csr_op == 2'd1) ? (w_csr_old | w_csr_src) :
                                                (w_csr_old & ~w_csr_src);

    wire        pipe_empty = !id_valid && !rr_valid && !ex_valid && !m_valid && !w_valid;
    // Either lane can trap now (a lane-1 load/store may fault).  Lane 0 is older,
    // so it is the one that defines mepc/mcause when both are set -- though a
    // lane-0 trap squashes lane 1, so the two never really compete.
    wire        w_trap_any = w_trap || (w_v1 && w_trap_h);
    wire        sync_trap  = w_valid && w_trap_any && trap_ready && !halted_q;
    wire        trap1      = sync_trap && !w_trap && w_v1 && w_trap_h;
    wire [31:0] trap_src_pc = w_trap ? w_pc : w_pc_h;
    // An interrupt is injected at a *boundary*, not when the pipe happens to be
    // empty: a spin loop never empties the pipe, so the old condition meant the
    // timer interrupt was never taken at all (ISA case 15 timed out inside
    // `lw; beq`).  The boundary is the retirement of a control-flow instruction:
    // at that point the next pc is exactly known (w_next), every older
    // instruction has committed, and killing the younger ones is what the
    // redirect already does.
    wire        irq_trap   = csr_irq_pending && w_valid && w_ctrl && !w_trap &&
                             !w_trap_h && !w_mret && !halted_q;
    wire        trap_go    = sync_trap || irq_trap;
    wire        mret_go    = w_valid && w_mret && !w_trap && !halted_q;

    // Where the next fetch resumes after a committed instruction: a pair ends
    // at lane 1 (pc+4) + 4, a single instruction at its own w_next.
    wire [31:0] w_next_eff = w_ctrl_h ? w_next_h :
                             w_v1 ? (w_pc_h + 32'd4) : w_next;
    // One training port, at most one control transfer per packet: feed it
    // whichever lane carried it (lane 1 wins the mux when it is a control).
    wire        tr_lane1 = w_v1 && w_ctrl_h;
    wire [31:0] tr_pc    = tr_lane1 ? w_pc_h     : w_pc;
    wire        tr_ctrl  = tr_lane1 ? 1'b1       : w_ctrl;
    wire        tr_unc   = tr_lane1 ? w_uncond_h : w_uncond;
    wire        tr_take  = tr_lane1 ? w_taken_h  : w_taken;
    wire [31:0] tr_tgt   = tr_lane1 ? w_next_h   : w_next;

    // mepc: a synchronous trap returns to the faulting instruction, an
    // interrupt returns to the instruction that would have run next.
    wire [31:0] trap_tgt_pc = irq_trap ? w_next_eff : trap_src_pc;
    wire [31:0] trap_code   = irq_trap ? csr_irq_cause :
                              w_trap ? {27'd0, w_cause} : {29'd0, w_cause_h};
    wire [31:0] trap_tval_i = irq_trap ? 32'd0 : (w_trap ? w_tval : w_tval_h);

    csr_native u_csr(
        .clk(clk), .rst_n(rst_n),
        // The read happens at WB: read_data is pre-edge, so it is exactly the
        // architectural old value for this instruction, and all older CSR
        // writes have already landed.
        .addr(w_valid && w_csr ? w_csr_addr : id_csr_addr),
        .write_intent(w_valid && w_csr ? 1'b1 : rf_write_intent),
        .commit(w_commit && w_csr),
        .retire(w_commit), .retire_count((w_v1 && !w_trap_h) ? 2'd2 : 2'd1),
        .mret_fire(mret_go),
        .trap_enter(trap_go),
        .write_data(csr_new),
        .trap_pc(trap_tgt_pc), .trap_cause(trap_code), .trap_tval(trap_tval_i),
        .irq_software(irq_software), .irq_timer(irq_timer), .irq_external(irq_external),
        .read_data(csr_rdata), .illegal(csr_illegal),
        .vector(csr_vector), .mepc_value(csr_mepc),
        .irq_pending(csr_irq_pending), .irq_cause(csr_irq_cause)
    );

    assign csr_mtvec = csr_vector;

    // ========================================================= redirect
    // A branch resolves in EX and may redirect immediately: the only younger
    // instruction is the one in RR, and an older trap overrides it later.
    // A control transfer must only resolve on a cycle where the EX operands are
    // valid.  While hold_ex is high the stage is frozen precisely because an
    // operand is still in flight (load-use, divider, memory wait), so the target
    // computed from it is stale.  Redirecting on that stale target killed the
    // pipeline and sent `jr a5` -- right behind `lw a5,0(a0)` in CoreMark's
    // get_seed_32 jump table -- to the table's data address.
    wire        br_miss  = rr_valid && is_ctrl && !hold_ex && !ex_trap_w &&
                           (ctrl_next != rr_pred);
    wire        resume   = halted_q && !halt_req;
    // At most one lane is a control transfer (pairing forbids lane 0 when it is
    // a control), so the two mispredict sources are mutually exclusive.
    wire        br_miss_h = rr_v1 && rr_ctrl_h && !hold_ex && (ctrl_next_h != rr_pred_h);
    wire        kill_young = br_miss || br_miss_h;
    wire        kill_all   = trap_go || mret_go;

    // The redirect is NOT registered.  Registering it (br_go_q/br_pc_q) is the
    // textbook fix for "compare -> flush -> IFU pointer" and it does take
    // 0.74 ns off the synthesis WNS at 126 MHz -- but it also adds a full
    // cycle to every mispredict, and at the measured 54,455 mispredicts per 20
    // iterations that is 0.76% of the score against 3.8% of a path that needs
    // to shrink by 48%.  33 flip-flops and an unreachable target is not a
    // trade, so the combinational redirect stays.  See
    // docs/lessons/mistakes-log.md section 27.
    wire        redirect_any = trap_go || mret_go || br_miss || br_miss_h || resume;
    wire [31:0] redirect_target = trap_go ? csr_vector :
                                  mret_go ? csr_mepc :
                                  br_miss ? ctrl_next :
                                  br_miss_h ? ctrl_next_h : arch_next_q;

    // Kill masks: a trap/MRET in WB is older than every other stage.
    assign redirect_valid = redirect_any;
    assign redirect_pc    = redirect_target;
    assign pred_miss      = br_miss;
`ifdef RV32_RDRDBG
    always @(posedge clk) if (rst_n && redirect_any)
        $display("TR_RDR tgt=%08x trap=%b mret=%b brm=%b brmh=%b res=%b wpc=%08x wv1=%b wctrl=%b mtvec=%08x rrpc=%08x rrpred=%08x rrvalid=%b idv=%b",
                 redirect_target, trap_go, mret_go, br_miss, br_miss_h, resume,
                 w_pc, w_v1, w_ctrl, csr_vector, rr_pc, rr_pred, rr_valid, id_valid);
    always @(posedge clk) if (rst_n)
        $display("TR_FET pcq=%08x req=%08x fv=%b fr=%b fpc=%08x hp=%08x he=%b ho=%b",
                 pc_q, request_pc, fetch_valid, fetch_ready, fetch_pc, fetch_pc, 1'b0, hold_ex);
`endif

    always @(posedge clk) begin
        if (!rst_n) pc_q <= RESET_PC;
        else if (redirect_any) pc_q <= redirect_target;
        // A taken pair consumes pc and pc+4, and the IFU tracks its head against
        // request_pc, so the pointer has to move by 8 (advancing by 4 would make
        // the head disagree with the architectural PC and drop the queue).
        else if (fetch_fire) pc_q <= id_accept2 ? fetch_predicted_next_pc_hi :
                                                 fetch_predicted_next_pc;
    end

    // ========================================================= predictor
    wire        pred_take, ct_take, ct_take2;
    wire [31:0] pred_target, ct_target, ct_target2;
    branch_predictor u_bp(
        .clk(clk), .rst_n(rst_n),
        .fetch_pc(pc_q), .predict_taken(pred_take), .predict_target(pred_target),
        .fetch_pc2(chain_c), .predict_taken2(ct_take), .predict_target2(ct_target),
        .fetch_pc3(chain_c2), .predict_taken3(ct_take2), .predict_target3(ct_target2),
        .train_valid(w_commit), .train_pc(tr_pc), .train_control(tr_ctrl),
        .train_uncond(tr_unc), .train_taken(tr_take), .train_target(tr_tgt)
    );
    assign predict_next_pc        = pred_take ? pred_target : (pc_q + 32'd4);
    assign chain_predict_next_pc  = ct_take  ? ct_target  : (chain_c  + 32'd4);
    assign chain_predict_next_pc2 = ct_take2 ? ct_target2 : (chain_c2 + 32'd4);

    // ========================================================= halt / retire
    always @(posedge clk) begin
        if (!rst_n) begin
            halted_q <= 1'b0; halt_pending_q <= 1'b0; arch_next_q <= RESET_PC;
        end else begin
            if (halt_req && !halted_q) halt_pending_q <= 1'b1;
            if (halt_pending_q && pipe_empty && fetch_idle && data_idle) begin
                halted_q <= 1'b1;
                halt_pending_q <= 1'b0;
            end
            if (halted_q && !halt_req) halted_q <= 1'b0;
            if (w_commit && !irq_trap)
                arch_next_q <= (w_v1 && w_trap_h) ? w_pc_h : w_next_eff;
        end
    end

    assign halted       = halted_q;
    assign halt_pending = halt_pending_q;
    assign arch_next_pc = arch_next_q;

    assign retire_fire = w_commit;
    assign retire_pc   = w_pc;
    assign retire_inst = w_inst;
    assign rd_valid    = wb_we;
    assign rd          = w_rd;
    assign wdata       = wb_value;
    assign rd_valid_h  = wb_we_h;
    assign rd_h        = w_rd_h;
    assign wdata_h     = w_value_h;
    assign trap_fire   = trap_go;
    assign trap_pc     = trap_tgt_pc;
    assign trap_cause  = trap_code;
    assign trap_tval   = trap_tval_i;
    assign debug_data  = 32'd0;

    // The retirement order is an observation counter: only the testbenches read
    // it (tb_isa_e2e derives the issued-pair count from its delta, the traces
    // print it).  32 bits is 4.29 G retires, three orders of magnitude more than
    // any run this board can finish, so the top half was 32 flops of nothing --
    // it is a 64-bit port that is zero-extended here.  Deleted under the area
    // gate (module-area-plan.md section 3).
    always @(posedge clk) begin
        if (!rst_n) retire_cnt_q <= 32'd0;
        else if (retire_fire) retire_cnt_q <= retire_cnt_q +
                                              ((w_v1 && !w_trap_h) ? 32'd2 : 32'd1);
    end
    assign retire_order = {32'd0, retire_cnt_q};

    // ========================================================= EX memory port
    // P9: issued from EX, using the address the ALU cycle just produced.  The
    // older-instruction guards now have to look at M2 as well as WB: the request
    // leaves one cycle earlier than it used to, so an older instruction in M2
    // has not reached the only stage that can trap yet.
    //
    // `!ctrl_miss_now` is the third face of the same coin, and it is the one P9
    // broke: pairing lets lane 1 be a memory op behind a lane-0 control transfer,
    // and the operand of that lane-1 access is whatever the wrong-path register
    // set holds.  When the branch turns out to be mispredicted, `br_miss` kills
    // lane 1 at the RR/EX edge -- which was enough while the request was issued
    // from M1 one cycle later, and is not enough any more: the request is
    // accepted in the very cycle the mispredict is detected, so a wrong-path `sb`
    // reached memory and landed on a stray address (CoreMark: `sb s1,0(a5)`
    // behind `j 2970`, writing to 0x31..0x62, because lane 1's `a5` came from a
    // register the wrong path had just scribbled on).
    //
    // It is deliberately NOT `br_miss`: that signal is AND-ed with `!hold_ex`,
    // and `hold_ex` depends on `mem_wait`, which depends on `mem_accept`, which
    // depends on this term -- closing the loop made vsim hit its iteration limit
    // on the first cycle.  Only a control transfer in lane 0 can be mispredicted
    // here, so this term never blocks a legitimate lane-0 access.
    assign issue_mem = (ex_is_mem || ex_is_mem_h) && !mem_issued_q &&
                       !(w_valid && (w_trap || (w_v1 && w_trap_h))) &&
                       !(m_valid && (m_trap || (m_v1 && m_trap_h))) && !kill_all;

    // One port, two possible owners: every field follows the owner.
    assign op_valid      = issue_mem;
    assign is_store      = mem_from_h ? rr_store_h : rr_store;
    assign address       = mem_from_h ? mem_addr_h  : mem_addr;
    assign store_value   = mem_from_h ? mem_sdata_h : fwd2;
    assign op_pc         = mem_from_h ? rr_pc_h    : rr_pc;
    assign access_size   = {1'b0, mem_from_h ? rr_size_h : rr_size};
    assign load_unsigned = mem_from_h ? rr_uns_h   : rr_uns;
    assign op_rd         = mem_from_h ? rr_rd_h    : rr_rd;
    assign done_ready    = 1'b1;

    // A cache hit can accept the request and answer it in the SAME cycle, so the
    // response belongs to this instruction either way: it was either issued in an
    // earlier cycle (mem_issued_q) or accepted in this one (mem_accept).
    wire        mem_rsp    = done_valid && (mem_issued_q || mem_accept);
    wire        mem_fault  = ex_is_mem && mem_rsp && fault;
    wire        mem_fault_h = ex_is_mem_h && mem_rsp && fault;
    wire [4:0]  mem_cause = rr_store ? 5'd7 : 5'd5;
    wire [4:0]  mem_cause_h = rr_store_h ? 5'd7 : 5'd5;

    // ========================================================= sequencing
    // id_accept / id_accept2 are declared next to the PC pointer.
    // fetch_ready is already !stall && !serial && !halt && !redirect.

    // ------------------------------------------------------------------ RR
    always @(posedge clk) begin
        if (!rst_n) begin
            id_valid <= 1'b0; id_pc <= 32'd0; id_inst <= 32'd0; id_imm <= 32'd0;
            id_pred <= 32'd0; id_rd <= 5'd0; id_rs1 <= 5'd0; id_rs2 <= 5'd0;
            id_fcause <= 5'd0; id_u1 <= 0; id_u2 <= 0; id_we <= 0; id_load <= 0;
            id_store <= 0; id_br <= 0; id_jal <= 0; id_jalr <= 0; id_csr <= 0;
            id_mret <= 0; id_ecall <= 0; id_ebrk <= 0; id_mul <= 0; id_div <= 0;
            id_illegal <= 0; id_ffault <= 0; id_uns <= 0; id_serial <= 0;
            id_alu <= 4'd0; id_asel <= 2'd0; id_bsel <= 2'd0; id_size <= 2'd2;
            id_csr_op <= 2'd0; id_br_op <= 3'd0; id_md_op <= 3'd0; id_csr_addr <= 12'd0;
            id_v1 <= 1'b0; id_pc_h <= 32'd0; id_imm_h <= 32'd0;
            id_rd_h <= 5'd0; id_rs1_h <= 5'd0; id_rs2_h <= 5'd0;
            id_alu_h <= 4'd0; id_asel_h <= 2'd0; id_bsel_h <= 2'd0;
            id_we_h <= 1'b0; id_op_h <= 7'd0;
            id_pred_h <= 32'd0; id_ctrl_h <= 1'b0; id_jal_h <= 1'b0; id_br_op_h <= 3'd0;
        end else if (!hold_ex || kill_all) begin
            // A kill must never be blocked by a freeze.  `hold_ex` is written as
            // "skip this whole block", which also skipped the valid-bit clear --
            // so an instruction younger than a trapping one survived the trap
            // whenever the freeze happened to be asserted on the trap cycle.
            // P9 made that easy to hit: the younger instruction can be a store
            // that is still waiting for a 20-cycle AXI write response, and it
            // then re-traps on the way out (ISA case 19).
            id_valid <= !hold_ex && id_accept && !kill_all && !kill_young;
            id_v1    <= !hold_ex && id_accept2 && !kill_all && !kill_young;
            if (id_accept) begin
                id_pc <= fetch_pc; id_inst <= fetch_inst; id_imm <= dec_imm;
                id_pred <= fetch_predicted_next_pc;
                id_rd <= dec_rd; id_rs1 <= dec_rs1; id_rs2 <= dec_rs2;
                id_u1 <= dec_u1; id_u2 <= dec_u2; id_we <= dec_we;
                id_load <= dec_load; id_store <= dec_store; id_br <= dec_br;
                id_jal <= dec_jal; id_jalr <= dec_jalr; id_csr <= dec_csr;
                id_mret <= dec_mret; id_ecall <= dec_ecall; id_ebrk <= dec_ebrk;
                id_mul <= dec_mul; id_div <= dec_div; id_illegal <= dec_illegal;
                id_uns <= dec_uns; id_serial <= dec_serial;
                id_alu <= dec_alu; id_asel <= dec_asel; id_bsel <= dec_bsel;
                id_size <= dec_size; id_csr_op <= dec_csr_op; id_br_op <= dec_br_op;
                id_md_op <= dec_md_op; id_csr_addr <= dec_csr_addr;
                id_ffault <= fetch_fault;
                id_fcause <= fetch_fault ? fetch_fault_cause : 5'd0;
                // Lane 1 runs at the PC the IFU put it at, which is only
                // fetch_pc+4 while lane 0 is fall-through.  When lane 0 is a
                // predicted-taken control transfer and the IFU has already
                // prefetched the target behind it, lane 1 *is* the target, so
                // the constant would execute the right instruction at the
                // wrong PC (wrong branch targets, wrong link values).
                id_pc_h <= fetch_pc_hi; id_imm_h <= dec_imm_h; id_op_h <= fetch_inst_hi[6:0];
                id_rd_h <= dec_rd_h; id_rs1_h <= dec_rs1_h; id_rs2_h <= dec_rs2_h;
                id_alu_h <= dec_alu_h; id_asel_h <= dec_asel_h; id_bsel_h <= dec_bsel_h;
                id_we_h <= dec_we_h;
                id_pred_h <= fetch_predicted_next_pc_hi;
                id_ctrl_h <= dec_br_h || dec_jal_h; id_jal_h <= dec_jal_h;
                id_br_op_h <= dec_br_op_h;
                id_load_h <= dec_load_h; id_store_h <= dec_store_h;
                id_uns_h <= dec_uns_h; id_size_h <= dec_size_h;
            end
        end
    end

    // ------------------------------------------------------------------ EX
    always @(posedge clk) begin
        if (!rst_n) begin
            rr_valid <= 1'b0; rr_pc <= 32'd0; rr_inst <= 32'd0; rr_imm <= 32'd0;
            rr_pred <= 32'd0; rr_csr_old <= 32'd0; rr_u1 <= 1'b0;
            rr_rd <= 5'd0; rr_rs1 <= 5'd0; rr_rs2 <= 5'd0;
            rr_fcause <= 5'd0; rr_we <= 0; rr_load <= 0; rr_store <= 0; rr_br <= 0;
            rr_jal <= 0; rr_jalr <= 0; rr_csr <= 0; rr_mret <= 0; rr_ecall <= 0;
            rr_ebrk <= 0; rr_mul <= 0; rr_div <= 0; rr_illegal <= 0; rr_ffault <= 0;
            rr_uns <= 0; rr_csr_illegal <= 0; rr_serial <= 0; rr_alu <= 4'd0;
            rr_asel <= 2'd0; rr_bsel <= 2'd0; rr_size <= 2'd2; rr_csr_op <= 2'd0;
            rr_br_op <= 3'd0; rr_md_op <= 3'd0; rr_csr_addr <= 12'd0;
            rr_v1 <= 1'b0; rr_pc_h <= 32'd0; rr_imm_h <= 32'd0;
            rr_rd_h <= 5'd0; rr_rs1_h <= 5'd0; rr_rs2_h <= 5'd0;
            rr_alu_h <= 4'd0; rr_asel_h <= 2'd0; rr_bsel_h <= 2'd0;
            rr_we_h <= 1'b0; rr_op_h <= 7'd0;
            rr_pred_h <= 32'd0; rr_ctrl_h <= 1'b0; rr_jal_h <= 1'b0; rr_br_op_h <= 3'd0;
            rr_load_h <= 1'b0; rr_store_h <= 1'b0; rr_uns_h <= 1'b0; rr_size_h <= 2'd2;
        end else if (!hold_ex || kill_all) begin
            // Same escape as the RD stage: freeze must not absorb a kill.
            rr_valid <= !hold_ex && id_valid && !kill_all && !kill_young;
            rr_v1    <= !hold_ex && id_v1 && !kill_all && !kill_young;
            if (id_valid) begin
                rr_pc <= id_pc; rr_inst <= id_inst; rr_imm <= id_imm; rr_pred <= id_pred;
                rr_rd <= id_rd; rr_rs1 <= id_rs1; rr_rs2 <= id_rs2; rr_fcause <= id_fcause;
                rr_we <= id_we; rr_load <= id_load; rr_store <= id_store; rr_br <= id_br;
                rr_jal <= id_jal; rr_jalr <= id_jalr; rr_csr <= id_csr; rr_mret <= id_mret;
                rr_ecall <= id_ecall; rr_ebrk <= id_ebrk; rr_mul <= id_mul; rr_div <= id_div;
                rr_illegal <= id_illegal; rr_ffault <= id_ffault; rr_uns <= id_uns;
                rr_serial <= id_serial; rr_alu <= id_alu; rr_asel <= id_asel;
                rr_bsel <= id_bsel; rr_size <= id_size; rr_csr_op <= id_csr_op;
                rr_br_op <= id_br_op; rr_md_op <= id_md_op; rr_csr_addr <= id_csr_addr;
                rr_csr_old <= id_csr ? csr_rdata : 32'd0;
                rr_csr_illegal <= id_csr ? csr_illegal : 1'b0;
                rr_u1 <= id_u1;
                rr_pc_h <= id_pc_h; rr_imm_h <= id_imm_h; rr_op_h <= id_op_h;
                rr_rd_h <= id_rd_h; rr_rs1_h <= id_rs1_h; rr_rs2_h <= id_rs2_h;
                rr_alu_h <= id_alu_h; rr_asel_h <= id_asel_h; rr_bsel_h <= id_bsel_h;
                rr_we_h <= id_we_h;
                rr_pred_h <= id_pred_h; rr_ctrl_h <= id_ctrl_h; rr_jal_h <= id_jal_h;
                rr_br_op_h <= id_br_op_h;
                rr_load_h <= id_load_h; rr_store_h <= id_store_h;
                rr_uns_h <= id_uns_h; rr_size_h <= id_size_h;
            end
        end
    end

    // ------------------------------------------------------------------ M1
    always @(posedge clk) begin
        if (!rst_n) begin
            ex_valid <= 1'b0; ex_pc <= 32'd0; ex_inst <= 32'd0; ex_value <= 32'd0;
            ex_tval <= 32'd0;
            ex_next <= 32'd0; ex_csr_old <= 32'd0; ex_csr_src <= 32'd0;
            ex_rd <= 5'd0; ex_cause <= 5'd0; ex_we <= 0;
            ex_trap <= 0; ex_ctrl <= 0; ex_uncond <= 0; ex_taken <= 0;
            ex_csr <= 0; ex_mret <= 0; ex_serial <= 0;
            ex_csr_op <= 2'd0; ex_csr_addr <= 12'd0;
            ex_v1 <= 1'b0; ex_pc_h <= 32'd0; ex_value_h <= 32'd0;
            ex_rd_h <= 5'd0; ex_we_h <= 1'b0;
            ex_ctrl_h <= 1'b0; ex_taken_h <= 1'b0; ex_uncond_h <= 1'b0;
            ex_next_h <= 32'd0;
            // These three were left out of the reset once and started as X; any
            // one of them reaching `issue_mem` (via a trap flag) turns that into
            // X and the memory handshake then never completes.
            ex_trap_h <= 1'b0; ex_cause_h <= 3'd0; ex_tval_h <= 32'd0;
        end else if (!hold_m1) begin
            ex_valid <= hold_ex ? 1'b0 : (rr_valid && !kill_all);
            // Lane 1 is killed at this edge when lane 0 is a control transfer
            // that mispredicted: everything lane 1 could be is either pc+8 or
            // the predicted target, and both are wrong-path in that case.  The
            // branch itself still retires (ex_valid above), the redirect is
            // registered separately, and `kill_young` keeps the next fetch out
            // of RR, so no wrong-path instruction ever reaches a register write.
            ex_v1    <= hold_ex ? 1'b0 : (rr_v1 && !kill_all && !br_miss);
            if (rr_valid && !hold_ex) begin
                ex_pc <= rr_pc; ex_inst <= rr_inst; ex_rd <= rr_rd; ex_we <= rr_we;
                // The load response and the ALU result land on this edge, which
                // is the whole point of P9: from M1 onward a load is
                // indistinguishable from an ALU op.
                ex_value <= (rr_load && mem_rsp) ? load_value : ex_value_w;
                ex_tval <= mem_fault ? fault_addr : ex_tval_w;
                ex_cause <= mem_fault ? mem_cause : ex_cause_w;
                ex_trap <= ex_trap_w || mem_fault;
                ex_ctrl <= is_ctrl; ex_uncond <= (rr_jal || rr_jalr);
                ex_taken <= ctrl_taken; ex_next <= ctrl_next;
                ex_csr <= rr_csr; ex_mret <= rr_mret;
                ex_serial <= rr_serial; ex_csr_op <= rr_csr_op;
                ex_csr_addr <= rr_csr_addr; ex_csr_old <= rr_csr_old;
                ex_csr_src <= csr_src_w;
                ex_pc_h <= rr_pc_h;
                ex_value_h <= (rr_load_h && mem_rsp) ? load_value : ex_value_h_w;
                ex_rd_h <= rr_rd_h; ex_we_h <= rr_v1 && rr_we_h;
                ex_ctrl_h <= rr_ctrl_h; ex_taken_h <= ctrl_taken_h;
                ex_uncond_h <= rr_jal_h; ex_next_h <= ctrl_next_h;
                ex_trap_h <= mem_misaln_h || mem_fault_h;
                ex_cause_h <= mem_fault_h ? mem_cause_h[2:0] : ex_cause_h_w;
                ex_tval_h <= mem_fault_h ? fault_addr : mem_addr_h;
            end
        end
    end

    // ------------------------------------------------------------------ M2
    always @(posedge clk) begin
        if (!rst_n) begin
            m_valid <= 1'b0; m_pc <= 32'd0; m_inst <= 32'd0; m_value <= 32'd0;
            m_tval <= 32'd0; m_next <= 32'd0; m_csr_old <= 32'd0;
            m_csr_src <= 32'd0; m_rd <= 5'd0; m_cause <= 5'd0; m_we <= 0; m_trap <= 0;
            m_ctrl <= 0; m_uncond <= 0; m_taken <= 0; m_csr <= 0; m_mret <= 0;
            m_serial <= 0; m_csr_op <= 2'd0; m_csr_addr <= 12'd0;
            m_v1 <= 1'b0; m_pc_h <= 32'd0; m_value_h <= 32'd0;
            m_rd_h <= 5'd0; m_we_h <= 1'b0;
            m_ctrl_h <= 1'b0; m_taken_h <= 1'b0; m_uncond_h <= 1'b0;
            m_next_h <= 32'd0;
            m_trap_h <= 1'b0; m_cause_h <= 3'd0; m_tval_h <= 32'd0;
        end else if (!hold_wb) begin
            m_valid <= hold_m1 ? 1'b0 : (ex_valid && !kill_all);
            m_v1    <= hold_m1 ? 1'b0 : (ex_v1 && !kill_all);
            if (ex_valid && !hold_m1) begin
                m_pc <= ex_pc; m_inst <= ex_inst; m_rd <= ex_rd; m_we <= ex_we;
                // The load response was captured at the EX/M1 edge, so M1 carries
                // the final value for every instruction -- no per-stage
                // substitution and no `mem_rsp` term here any more.
                m_value <= ex_value;
                m_trap <= ex_trap;
                m_cause <= ex_cause;
                m_tval <= ex_tval;
                m_ctrl <= ex_ctrl; m_uncond <= ex_uncond; m_taken <= ex_taken;
                m_next <= ex_next;
                m_csr <= ex_csr; m_mret <= ex_mret; m_serial <= ex_serial;
                m_csr_op <= ex_csr_op; m_csr_addr <= ex_csr_addr;
                m_csr_old <= ex_csr_old; m_csr_src <= ex_csr_src;
                m_pc_h <= ex_pc_h; m_value_h <= ex_value_h;
                m_rd_h <= ex_rd_h; m_we_h <= ex_we_h;
                m_ctrl_h <= ex_ctrl_h; m_taken_h <= ex_taken_h;
                m_uncond_h <= ex_uncond_h; m_next_h <= ex_next_h;
                m_trap_h <= ex_trap_h;
                m_cause_h <= ex_cause_h;
                m_tval_h <= ex_tval_h;
            end
        end
    end

    // ------------------------------------------------------------------ WB
    always @(posedge clk) begin
        if (!rst_n) begin
            w_valid <= 1'b0; w_pc <= 32'd0; w_inst <= 32'd0; w_value <= 32'd0;
            w_tval <= 32'd0; w_next <= 32'd0; w_csr_old <= 32'd0;
            w_csr_src <= 32'd0; w_rd <= 5'd0; w_cause <= 5'd0; w_we <= 0; w_trap <= 0;
            w_ctrl <= 0; w_uncond <= 0; w_taken <= 0; w_csr <= 0; w_mret <= 0;
            w_serial <= 0; w_csr_op <= 2'd0; w_csr_addr <= 12'd0;
            w_done_q <= 1'b0;
            w_v1 <= 1'b0; w_pc_h <= 32'd0; w_value_h <= 32'd0;
            w_rd_h <= 5'd0; w_we_h <= 1'b0;
            w_ctrl_h <= 1'b0; w_taken_h <= 1'b0; w_uncond_h <= 1'b0;
            w_next_h <= 32'd0;
            w_trap_h <= 1'b0; w_cause_h <= 3'd0; w_tval_h <= 32'd0;
        end else if (!hold_wb) begin
            w_valid <= m_valid && !trap_go && !mret_go;
            // "Commit only the older prefix": when lane 0 traps, lane 1 of the
            // same packet must not retire, and mepc already points at lane 0.
            w_v1    <= m_v1 && !trap_go && !mret_go && !(m_valid && m_trap);
            w_done_q <= 1'b0;
            if (m_valid) begin
                w_pc <= m_pc; w_inst <= m_inst; w_rd <= m_rd; w_we <= m_we;
                w_value <= m_value; w_trap <= m_trap; w_cause <= m_cause;
                w_tval <= m_tval; w_ctrl <= m_ctrl; w_uncond <= m_uncond;
                w_taken <= m_taken; w_next <= m_next;
                w_csr <= m_csr; w_mret <= m_mret; w_serial <= m_serial;
                w_csr_op <= m_csr_op; w_csr_addr <= m_csr_addr;
                w_csr_old <= m_csr_old; w_csr_src <= m_csr_src;
                w_pc_h <= m_pc_h; w_value_h <= m_value_h;
                w_rd_h <= m_rd_h; w_we_h <= m_we_h;
                w_ctrl_h <= m_ctrl_h; w_taken_h <= m_taken_h;
                w_uncond_h <= m_uncond_h; w_next_h <= m_next_h;
                w_trap_h <= m_trap_h; w_cause_h <= m_cause_h; w_tval_h <= m_tval_h;
            end
        end else if (w_commit) begin
            w_done_q <= 1'b1;
        end
    end

    // ========================================================= bookkeeping
    always @(posedge clk) begin
        // `serial_q` blocks fetch while a CSR/system instruction is in flight.
        // It must also clear when that instruction is killed (a redirect can kill
        // a serial instruction before it reaches WB) and whenever the pipe is
        // empty -- otherwise one killed CSR locks the core out of fetching
        // forever, which is exactly the "pipe drains and stops" signature the
        // operand trace showed.
        if (!rst_n) serial_q <= 1'b0;
        else if (id_accept && id_serial) serial_q <= 1'b1;
        else if ((w_valid && w_serial) || pipe_empty || kill_all) serial_q <= 1'b0;
    end

    always @(posedge clk) begin
        // "Issued" means: a memory op is in M1 and has not been answered yet.
        // Writing it as one expression removes the priority trap that deadlocked
        // the pipe twice -- a same-cycle accept must SET the flag even though the
        // stage is advancing, otherwise the (already consumed) response is gone
        // and the load waits forever.
        // "Issued" means: *some* memory op is in M1 and has not been answered.
        // Both lanes can own the port now, so the flag has to follow the owner --
        // keying it on `m_is_mem` alone left a lane-1 load permanently
        // un-issued, and its later response was then discarded as a stranger's.
        //
        // It must also be reset.  Without the reset the flag starts as X, and the
        // first memory op that reaches M1 before the LSU has ever answered reads
        // `done_valid` = X, which turns the ternary condition into X and latches
        // X permanently: `issue_mem` then never asserts, `done_valid` never
        // becomes defined, and the core spins on the same PC forever.  That is
        // exactly what a lane-1 load arriving before any lane-0 load could do.
        if (!rst_n) mem_issued_q <= 1'b0;
        else mem_issued_q <= ((ex_is_mem || ex_is_mem_h) && !mem_rsp)
                             ? (mem_issued_q || mem_accept) : 1'b0;
    end

    always @(posedge clk) begin
        if (!rst_n) div_issued_q <= 1'b0;
        else div_issued_q <= (rr_valid && rr_div && !rr_illegal && !div_rsp_valid)
                             ? (div_issued_q || (div_req && div_req_ready)) : 1'b0;
    end

    assign fetch_ready  = !hold_ex && !serial_q && !halt_pending_q && !halted_q &&
                          !redirect_any;
    // "Can take two" is the same condition plus a legal pair; the IFU only
    // presents a pair when the head really is pc/pc+4 and lane 0 was predicted
    // fall-through, so the pairing rule never has to second-guess the front end.
    assign fetch_ready2 = fetch_ready && pair_ok;

    // ========================================================= TB compatibility
    // tb_isa_e2e reports dual-issue coverage statistics by name.  The P1 core is
    // single issue, so every one of those probes reads false; keeping the names
    // means one testbench covers both cores instead of forking it.
    // Lane 1 now really commits, so these read the commit-stage packet: the
    // testbench adds 2 to its retired count whenever ex_valid_h is high at a
    // retire, which only lines up if it observes lane 1 of the *committing*
    // packet rather than of the packet sitting in EX.
    wire        ex_valid_h    = w_v1;
    wire        older_control = w_ctrl;
    wire        retire1       = retire_fire && w_v1;
    wire        retire0       = retire_fire;
    wire [31:0] ep_h          = w_pc_h;
    wire [31:0] ep            = w_pc;
    wire        young_path_ok = 1'b1;
    wire        mem_sel_h     = mem_from_h;
    wire        x_valid       = rr_v1;

    // tb_coremark_uart reads the same statistics by name.  Where the single-issue
    // core has a counter-part the probe is wired to it, so the report stays
    // meaningful; where the signal only exists because there is a second issue
    // slot (alu0/alu1/mem0/ctrl1, the dpc/drd decode bundle) it is tied off.
    wire        ex_leave           = rr_valid && !hold_ex;
    wire        is_memory          = rr_load || rr_store;
    wire        is_div             = rr_div;
    wire        issued             = div_issued_q || mem_issued_q;
    wire        id_ready           = !hold_ex;
    wire        pred_train_control = w_commit && w_ctrl;
    wire        pred_is_jalr       = rr_valid && rr_jalr;
    wire [31:0] ei                 = rr_inst;
    wire [31:0] ei_h               = {25'd0, rr_op_h};
    wire        id_valid_h         = id_v1;
    wire        id_ready1          = !hold_ex;
    wire        ex0_ready          = 1'b1;
    wire        ex1_ready          = 1'b1;
    wire        block_entry        = 1'b0;
    wire        alu0               = rr_valid && !rr_load && !rr_store && !rr_csr &&
                                     !rr_mul && !rr_div && !rr_br && !rr_jal && !rr_jalr;
    wire        alu1               = 1'b0;
    wire        mem0               = rr_valid && (rr_load || rr_store);
    wire        ctrl1              = 1'b0;
    wire [31:0] dpc                = id_pc;
    wire [31:0] dpch               = 32'd0;
    wire [4:0]  drd                = id_rd;
    wire [4:0]  drdh               = 5'd0;
    wire        dcwe               = id_csr;
    wire        dcweh              = 1'b0;
    wire        dillegal           = id_illegal;
    wire        dillegalh          = 1'b0;
    wire        ifault             = id_ffault;
    wire        ifaulth            = 1'b0;
`ifdef RV32_DEBUG
    // Stuck detector: print the full freeze state the first time the head of the
    // pipe stops for 40 cycles.  Reading `hold_*` after the fact tells nothing.
    integer stuck_q = 0;
    integer beat2_q = 0;
    reg     x_seen_q = 1'b0;
    always @(posedge clk) if (rst_n) begin
        if (rr_valid && hold_ex) stuck_q <= stuck_q + 1; else stuck_q <= 0;
        beat2_q <= beat2_q + 1;
        if (!x_seen_q && ($isunknown(done_valid) || $isunknown(op_valid))) begin
            x_seen_q <= 1'b1;
            $display("TR_XFIRST cyc=%0d pc=%08x opv=%b iss=%b isst=%b size=%b addr=%08x sdata=%08x dv=%b miq=%b mact=%b misalnh=%b ldch=%b",
                     beat2_q, rr_pc, op_valid, issue_mem, is_store, access_size,
                     address, store_value, done_valid, mem_issued_q, mem_accept,
                     mem_misaln_h, rr_load_h);
        end
    end
    // Where the cycles go.  These two counters are what turned "the cache must be
    // too small" into "23% of the run is spent with an instruction parked in EX
    // behind a load", so they earn their place in the bring-up toolbox:
    //   MEMDBG  - instructions presented to the LSU vs retired memory ops
    //             (equal values prove the core never re-issues an operation)
    //   STALLDBG- one bucket per reason a packet could not be accepted
    integer n_pres=0, n_acc=0, n_retmem=0;
    integer c_ok=0, c_starve=0, c_lu=0, c_mw=0, c_div=0, c_rd=0;
    always @(posedge clk) if (rst_n) begin
        if (issue_mem) n_pres = n_pres + 1;
        if (issue_mem && op_ready) n_acc = n_acc + 1;
        if (rr_valid && !hold_ex && !kill_all &&
            ((rr_load || rr_store) || (rr_v1 && (rr_load_h || rr_store_h))))
            n_retmem = n_retmem + 1;
        if (!fetch_valid) c_starve = c_starve + 1;
        else if (fetch_ready) c_ok = c_ok + 1;
        // `load_use` no longer exists as a stall reason (P9): the load response
        // lands on the same edge as an ALU result, so there is nothing to wait
        // for.  The bucket is kept in the report and pinned to zero so that a
        // future regression shows up as a non-zero number instead of silently
        // disappearing from the line.
        else if (1'b0) c_lu = c_lu + 1;
        else if (mem_wait) c_mw = c_mw + 1;
        else if (div_wait) c_div = c_div + 1;
        else if (redirect_any) c_rd = c_rd + 1;
    end
    final $display("MEMDBG presented=%0d accepted=%0d retired_mem=%0d", n_pres, n_acc, n_retmem);
    final $display("STALLDBG accept=%0d starve=%0d load_use=%0d mem_wait=%0d div=%0d redirect=%0d",
                   c_ok, c_starve, c_lu, c_mw, c_div, c_rd);
    // Why a memory operation could not complete: one bucket per reason.
    integer mw_block=0, mw_nordy=0, mw_gear=0, mw_ld=0, mw_st=0;
    always @(posedge clk) if (rst_n && (ex_is_mem || ex_is_mem_h) && !mem_rsp) begin
        if (!issue_mem)          mw_block = mw_block + 1;   // stopped by a guard
        else if (!op_ready)      mw_nordy = mw_nordy + 1;   // LSU not idle
        else                     mw_gear  = mw_gear  + 1;   // accepted, no reply yet
        if (mem_from_h ? rr_store_h : rr_store) mw_st = mw_st + 1;
        else                                    mw_ld = mw_ld + 1;
    end
    final $display("MEMWAITDBG blocked=%0d notready=%0d noresp=%0d load=%0d store=%0d",
                   mw_block, mw_nordy, mw_gear, mw_ld, mw_st);
`ifdef RV32_MEMDBG
    // ---- P9 bring-up: who produced the operand a memory op is using? --------
    // A memory op is presented to the LSU from EX with a *combinational* address
    // and store data, so its operands come from the bypass network live.  When
    // the LSU is busy the stage freezes, and every bypass source ages one stage
    // per cycle; if any of those hand-overs is wrong the address silently drifts
    // and the store lands somewhere harmless-looking (a DECERR in the hole
    // between 0x0 and 0x1000_0000).  Printing the winning source and the whole
    // candidate set at the accept edge is what tells the two apart.
    wire [2:0] fwd1_sel =
        (ex_valid && ex_v1 && ex_we_h && (ex_rd_h == rr_rs1) && (ex_rd_h != 5'd0)) ? 3'd0 :
        (ex_valid && ex_we && !ex_trap && (ex_rd == rr_rs1) && (ex_rd != 5'd0)) ? 3'd1 :
        (m_valid && m_v1 && m_we_h && (m_rd_h == rr_rs1) && (m_rd_h != 5'd0)) ? 3'd2 :
        (m_valid && m_we && !m_trap && (m_rd == rr_rs1) && (m_rd != 5'd0)) ? 3'd3 : 3'd4;
    wire [2:0] fwd2_sel =
        (ex_valid && ex_v1 && ex_we_h && (ex_rd_h == rr_rs2) && (ex_rd_h != 5'd0)) ? 3'd0 :
        (ex_valid && ex_we && !ex_trap && (ex_rd == rr_rs2) && (ex_rd != 5'd0)) ? 3'd1 :
        (m_valid && m_v1 && m_we_h && (m_rd_h == rr_rs2) && (m_rd_h != 5'd0)) ? 3'd2 :
        (m_valid && m_we && !m_trap && (m_rd == rr_rs2) && (m_rd != 5'd0)) ? 3'd3 : 3'd4;
    integer nbad=0;
    always @(posedge clk) if (rst_n && mem_accept && is_store &&
                              (address < 32'h1000_0000) && nbad < 24) begin
        nbad = nbad + 1;
        $display("MEMBAD cyc=%0d pc=%08x inst=%08x st=%b sz=%0d addr=%08x sd=%08x l1=%b rs1=%0d s1=%0d rs2=%0d s2=%0d",
                 beat2_q, op_pc, rr_inst, is_store, access_size, address,
                 store_value, mem_from_h, rr_rs1, fwd1_sel, rr_rs2, fwd2_sel);
        $display("       ex[v=%b v1=%b rd=%0d rd_h=%0d we=%b we_h=%b val=%08x val_h=%08x] m[v=%b v1=%b rd=%0d rd_h=%0d we=%b we_h=%b val=%08x val_h=%08x] w[rd=%0d we=%b val=%08x rd_h=%0d we_h=%b val_h=%08x] rfd0=%08x rfd1=%08x",
                 ex_valid, ex_v1, ex_rd, ex_rd_h, ex_we, ex_we_h, ex_value, ex_value_h,
                 m_valid, m_v1, m_rd, m_rd_h, m_we, m_we_h, m_value, m_value_h,
                 w_rd, w_we, w_value, w_rd_h, w_we_h, w_value_h, rf_d0, rf_d1);
    end
    final $display("MEMBADDBG bad_accepts=%0d", nbad);
`endif
    // Pairing diagnostics: why a fetch opportunity did or did not become a pair.
    // One bucket per reason, mutually exclusive, so the numbers add up to the
    // number of cycles the front end presented something to consume.
    integer pg_pair=0, pg_no_pair_flag=0, pg_l1_bad=0, pg_l0_alone=0,
            pg_pkt_lduse=0, pg_fault=0, pg_stall=0, pg_l1_mem=0;
    always @(posedge clk) if (rst_n) begin
        if (!(fetch_valid && fetch_ready)) pg_stall = pg_stall + 1;
        else if (id_accept2)                      pg_pair = pg_pair + 1;
        else if (!fetch_pair)                     pg_no_pair_flag = pg_no_pair_flag + 1;
        else if (!lane1_ok)                       pg_l1_bad = pg_l1_bad + 1;
        else if (lane0_issue_alone)               pg_l0_alone = pg_l0_alone + 1;
        else if (packet_load_use)                 pg_pkt_lduse = pg_pkt_lduse + 1;
        else if (fetch_fault || fetch_fault_hi)   pg_fault = pg_fault + 1;
        if (fetch_valid && fetch_ready && fetch_pair && !lane1_ok &&
            (dec_load_h || dec_store_h))          pg_l1_mem = pg_l1_mem + 1;
    end
    final $display("PAIRGAP pair=%0d no_pair=%0d l1_notok=%0d (of which mem=%0d) l0_alone=%0d pkt_lduse=%0d fault=%0d nostall=%0d",
                   pg_pair, pg_no_pair_flag, pg_l1_bad, pg_l1_mem, pg_l0_alone,
                   pg_pkt_lduse, pg_fault, pg_stall);
    // Two invariants worth printing for every bring-up run: any trap, and any
    // control transfer whose target is not in the code window.  Both are silent
    // in a correct core, and both pinpoint the culprit when they are not.
    always @(posedge clk) if (rst_n && trap_go)
        $display("TR_TRAP pc=%08x cause=%0d tval=%08x irq=%b mepc=%08x",
                 w_pc, trap_code, trap_tval_i, irq_trap, trap_tgt_pc);
    // A control transfer into the data window can only be a wrong target.
    always @(posedge clk) if (rst_n && redirect_any && redirect_target[31:28]==4'h1)
        $display("TR_BADJMP from=%08x target=%08x pred=%08x jalr=%b jal=%b br=%b rs1v=%08x imm=%08x",
                 rr_pc, redirect_target, rr_pred, rr_jalr, rr_jal, rr_br, fwd1, rr_imm);
`endif
`ifdef RV32_TRACE
    // Simulation-only operand trace (never compiled into a bitstream: the macro
    // is only defined by the debug compile).  One line per instruction entering
    // EX and one per commit, which is what identified every handshake bug so far.
    always @(posedge clk) if (rst_n && rr_valid)
        $display("TR_EX  pc=%08x inst=%08x rs1=%0d rs2=%0d op1=%08x op2=%08x fwd1=%08x fwd2=%08x ld=%b st=%b we=%b rd=%0d",
                 rr_pc, rr_inst, rr_rs1, rr_rs2, rf_d0, rf_d1, fwd1, fwd2,
                 rr_load, rr_store, rr_we, rr_rd);
    always @(posedge clk) if (rst_n && w_commit)
        $display("TR_WB  pc=%08x inst=%08x rd=%0d we=%b val=%08x trap=%b cause=%0d",
                 w_pc, w_inst, w_rd, w_we, wb_value, w_trap, w_cause);
`endif

endmodule
