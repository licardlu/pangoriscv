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
// A load cannot be bypassed from M1 because that register still holds its
// address, so its consumer waits exactly one cycle (`load_use`) and picks the
// value up from M2.  Every ALU/multiply result is bypassable from M1, so an
// ordinary dependency chain needs no stall at all -- that is what makes the
// deeper pipeline affordable.
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
    wire lane1_ok   = lane1_alu || lane1_ctrl;
    wire lane0_issue_alone = dec_serial || dec_br || dec_jal || dec_jalr;
    // A load in lane 0 cannot feed lane 1 in the same cycle (its data only
    // exists in M2), so such a pair is split rather than stalled in EX.
    wire packet_load_use = dec_load && dec_we &&
                           ((dec_u1_h && (dec_rd == dec_rs1_h)) ||
                            (dec_u2_h && (dec_rd == dec_rs2_h)));
    wire pair_ok = fetch_pair && lane1_ok && !lane0_issue_alone &&
                   !packet_load_use && !fetch_fault && !fetch_fault_hi;

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

    // EX -> M1
    reg         ex_valid;
    reg  [31:0] ex_pc, ex_inst, ex_value, ex_addr, ex_sdata, ex_tval, ex_pred, ex_next;
    reg  [31:0] ex_csr_old, ex_csr_src;
    reg  [4:0]  ex_rd, ex_cause;
    reg         ex_we, ex_load, ex_store, ex_trap, ex_ctrl, ex_uncond, ex_taken;
    reg         ex_uns, ex_csr, ex_mret, ex_serial;
    reg  [1:0]  ex_size, ex_csr_op;
    reg  [11:0] ex_csr_addr;
    reg         ex_v1;
    reg  [31:0] ex_pc_h, ex_value_h;
    reg  [4:0]  ex_rd_h;
    reg         ex_we_h;
    reg         ex_ctrl_h, ex_taken_h, ex_uncond_h;
    reg  [31:0] ex_next_h;

    // M1 -> M2
    reg         m_valid;
    reg  [31:0] m_pc, m_inst, m_value, m_tval, m_pred, m_next;
    reg  [31:0] m_csr_old, m_csr_src;
    reg  [4:0]  m_rd, m_cause;
    reg         m_we, m_trap, m_ctrl, m_uncond, m_taken, m_csr, m_mret, m_serial;
    reg  [1:0]  m_csr_op;
    reg  [11:0] m_csr_addr;
    reg         m_v1;
    reg  [31:0] m_pc_h, m_value_h;
    reg  [4:0]  m_rd_h;
    reg         m_we_h;
    reg         m_ctrl_h, m_taken_h, m_uncond_h;
    reg  [31:0] m_next_h;

    // M2 -> WB
    reg         w_valid;
    reg  [31:0] w_pc, w_inst, w_value, w_tval, w_pred, w_next;
    reg  [31:0] w_csr_old, w_csr_src;
    reg  [4:0]  w_rd, w_cause;
    reg         w_we, w_trap, w_ctrl, w_uncond, w_taken, w_csr, w_mret, w_serial;
    reg  [1:0]  w_csr_op;
    reg  [11:0] w_csr_addr;
    reg         w_v1;
    reg  [31:0] w_pc_h, w_value_h;
    reg  [4:0]  w_rd_h;
    reg         w_we_h;
    reg         w_ctrl_h, w_taken_h, w_uncond_h;
    reg  [31:0] w_next_h;

    // ========================================================= fetch / PC
    reg  [31:0] pc_q;
    wire        fetch_fire = fetch_valid && fetch_ready;
    wire        id_accept  = fetch_valid && fetch_ready;
    wire        id_accept2 = id_accept && pair_ok;
    assign      request_pc = pc_q;

    reg         halted_q, halt_pending_q, serial_q, mem_issued_q, div_issued_q;
    reg  [31:0] arch_next_q;
    reg  [63:0] retire_cnt_q;

    // Declared early: the hazard block needs the memory handshake.
    wire issue_mem;
    wire mem_accept = issue_mem && op_ready;

    // ========================================================= hazards
    wire m_is_mem   = ex_valid && (ex_load || ex_store) && !ex_trap;
    // A load in M1 hands its data over in M2, so both lanes of the packet in EX
    // must wait when they read its destination.  Checking only lane 0 left lane 1
    // reading the stale entry, which is what corrupted CoreMark's printf
    // arguments (they are walked off the stack by load + ALU pairs).
    wire load_use   = ex_valid && ex_load && ex_we &&
                      ((ex_rd == rr_rs1) || (ex_rd == rr_rs2) ||
                       (rr_v1 && ((ex_rd == rr_rs1_h) || (ex_rd == rr_rs2_h))));
    wire mem_wait   = m_is_mem && !(done_valid && (mem_issued_q || (issue_mem && op_ready)));
    wire div_wait   = rr_valid && rr_div && !rr_illegal && !div_rsp_valid;
    wire trap_wait  = w_valid && w_trap && !trap_ready;
    wire stall      = load_use || mem_wait || div_wait || trap_wait;

    // Freeze is per stage.  A frozen stage emits a bubble instead of holding its
    // instruction, which is what keeps commit a one-cycle pulse: if WB were held
    // with valid high, a CSR write would be applied again on the next cycle.
    // Per-stage enables.  A load-use consumer holds EX, but the load itself must
    // still be allowed to drain into M2 -- freezing the whole pipe there is a
    // deadlock (the response is consumed by the LSU while M1 is held, and the
    // consumer then waits forever).  Each stage therefore has exactly one reason
    // to hold, and the stage that feeds a holding stage emits a bubble.
    wire hold_ex = load_use || div_wait || mem_wait || trap_wait;  // EX + RR hold
    wire hold_m1 = mem_wait || trap_wait;                          // M1 holds
    wire hold_wb = trap_wait;                                      // M2 + WB hold

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
    wire        wb_we_h = w_commit && w_v1 && w_we_h && (w_rd_h != 5'd0);

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
    // younger than lane 0 of the same stage.  Distance 3 (the WB packet) needs
    // no level: `regs` puts both write ports into its read path, so rf_d* is
    // already the write-through result.  Missing the lane-1 sources here is what
    // made `add x3,x2,x1` read x2 as X -- x2 had been written by lane 1 of the
    // previous packet and was still in M1.
    wire [31:0] fwd1 =
        (ex_valid && ex_v1 && ex_we_h && (ex_rd_h == rr_rs1) && (ex_rd_h != 5'd0)) ? ex_value_h :
        (ex_valid && ex_we && !ex_load && !ex_trap && (ex_rd == rr_rs1) && (ex_rd != 5'd0)) ? ex_value :
        (m_valid && m_v1 && m_we_h && (m_rd_h == rr_rs1) && (m_rd_h != 5'd0)) ? m_value_h :
        (m_valid && m_we && !m_trap && (m_rd == rr_rs1) && (m_rd != 5'd0)) ? m_value : rf_d0;
    wire [31:0] fwd2 =
        (ex_valid && ex_v1 && ex_we_h && (ex_rd_h == rr_rs2) && (ex_rd_h != 5'd0)) ? ex_value_h :
        (ex_valid && ex_we && !ex_load && !ex_trap && (ex_rd == rr_rs2) && (ex_rd != 5'd0)) ? ex_value :
        (m_valid && m_v1 && m_we_h && (m_rd_h == rr_rs2) && (m_rd_h != 5'd0)) ? m_value_h :
        (m_valid && m_we && !m_trap && (m_rd == rr_rs2) && (m_rd != 5'd0)) ? m_value : rf_d1;
    // Lane 1 sees one producer lane 0 does not have: lane 0 of its own packet.
    // The condition is "lane 0 writes a register lane 1 reads" -- pairing already
    // rejects the one case that cannot be covered (lane 0 is a load), so lane 0's
    // result is always available combinationally here.
    wire lane0_raw1 = rr_v1 && rr_we && (rr_rd == rr_rs1_h) && (rr_rd != 5'd0);
    wire lane0_raw2 = rr_v1 && rr_we && (rr_rd == rr_rs2_h) && (rr_rd != 5'd0);
    // The read base `rf_d*_h` already carries the write-through of both write
    // ports, so the WB stage needs no level of its own.
    wire [31:0] fwd1_h =
        lane0_raw1 ? ex_value_w :
        (ex_valid && ex_v1 && ex_we_h && (ex_rd_h == rr_rs1_h) && (ex_rd_h != 5'd0)) ? ex_value_h :
        (ex_valid && ex_we && !ex_load && !ex_trap && (ex_rd == rr_rs1_h) && (ex_rd != 5'd0)) ? ex_value :
        (m_valid && m_v1 && m_we_h && (m_rd_h == rr_rs1_h) && (m_rd_h != 5'd0)) ? m_value_h :
        (m_valid && m_we && !m_trap && (m_rd == rr_rs1_h) && (m_rd != 5'd0)) ? m_value : rf_d0_h;
    wire [31:0] fwd2_h =
        lane0_raw2 ? ex_value_w :
        (ex_valid && ex_v1 && ex_we_h && (ex_rd_h == rr_rs2_h) && (ex_rd_h != 5'd0)) ? ex_value_h :
        (ex_valid && ex_we && !ex_load && !ex_trap && (ex_rd == rr_rs2_h) && (ex_rd != 5'd0)) ? ex_value :
        (m_valid && m_v1 && m_we_h && (m_rd_h == rr_rs2_h) && (m_rd_h != 5'd0)) ? m_value_h :
        (m_valid && m_we && !m_trap && (m_rd == rr_rs2_h) && (m_rd != 5'd0)) ? m_value : rf_d1_h;

    // ========================================================= EX datapath
    wire [31:0] alu_a = (rr_asel == 2'd1) ? rr_pc : (rr_asel == 2'd2) ? 32'd0 : fwd1;
    // b_sel 2 is the literal 4 (jal/jalr link value).
    wire [31:0] alu_b = (rr_bsel == 2'd0) ? fwd2 :
                       (rr_bsel == 2'd2) ? 32'd4 : rr_imm;

    wire [31:0] alu_y;
    wire        alu_eq, alu_lt, alu_ltu;
    rv32_alu u_alu(
        .op(rr_alu), .a(alu_a), .b(alu_b),
        .y(alu_y), .eq(alu_eq), .lt(alu_lt), .ltu(alu_ltu)
    );

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
    wire        ex_trap_w   = ex_illegal || rr_ecall || rr_ebrk || ctrl_misaln || mem_misaln;
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
    wire        sync_trap  = w_valid && w_trap && trap_ready && !halted_q;
    // An interrupt is injected at a *boundary*, not when the pipe happens to be
    // empty: a spin loop never empties the pipe, so the old condition meant the
    // timer interrupt was never taken at all (ISA case 15 timed out inside
    // `lw; beq`).  The boundary is the retirement of a control-flow instruction:
    // at that point the next pc is exactly known (w_next), every older
    // instruction has committed, and killing the younger ones is what the
    // redirect already does.
    wire        irq_trap   = csr_irq_pending && w_valid && w_ctrl && !w_trap &&
                             !w_mret && !halted_q;
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
    wire [31:0] trap_tgt_pc = irq_trap ? w_next_eff : w_pc;
    wire [31:0] trap_code   = irq_trap ? csr_irq_cause : {27'd0, w_cause};
    wire [31:0] trap_tval_i = irq_trap ? 32'd0 : w_tval;

    csr_native u_csr(
        .clk(clk), .rst_n(rst_n),
        // The read happens at WB: read_data is pre-edge, so it is exactly the
        // architectural old value for this instruction, and all older CSR
        // writes have already landed.
        .addr(w_valid && w_csr ? w_csr_addr : id_csr_addr),
        .write_intent(w_valid && w_csr ? 1'b1 : rf_write_intent),
        .commit(w_commit && w_csr),
        .retire(w_commit), .retire_count(w_v1 ? 2'd2 : 2'd1),
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
    wire        redirect_any = trap_go || mret_go || br_miss || br_miss_h || resume;
    wire [31:0] redirect_target = trap_go ? csr_vector :
                                  mret_go ? csr_mepc :
                                  br_miss ? ctrl_next :
                                  br_miss_h ? ctrl_next_h : arch_next_q;

    // Kill masks: a trap/MRET in WB is older than every other stage.
    wire kill_all   = trap_go || mret_go;
    wire kill_young = br_miss || br_miss_h;

    assign redirect_valid = redirect_any;
    assign redirect_pc    = redirect_target;
    assign pred_miss      = br_miss;

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
            if (w_commit && !irq_trap) arch_next_q <= w_next_eff;
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

    always @(posedge clk) begin
        if (!rst_n) retire_cnt_q <= 64'd0;
        else if (retire_fire) retire_cnt_q <= retire_cnt_q + (w_v1 ? 64'd2 : 64'd1);
    end
    assign retire_order = retire_cnt_q;

    // ========================================================= M1 memory port
    assign issue_mem = m_is_mem && !mem_issued_q && !(w_valid && w_trap) && !kill_all;

    assign op_valid      = issue_mem;
    assign is_store      = ex_store;
    assign address       = ex_addr;
    assign store_value   = ex_sdata;
    assign op_pc         = ex_pc;
    assign access_size   = {1'b0, ex_size};
    assign load_unsigned = ex_uns;
    assign op_rd         = ex_rd;
    assign done_ready    = 1'b1;

    // A cache hit can accept the request and answer it in the SAME cycle, so the
    // response belongs to this instruction either way: it was either issued in an
    // earlier cycle (mem_issued_q) or accepted in this one (mem_accept).
    wire        mem_rsp    = done_valid && (mem_issued_q || mem_accept);
    wire        mem_fault  = m_is_mem && mem_rsp && fault;
    wire [4:0]  mem_cause = ex_store ? 5'd7 : 5'd5;

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
        end else if (!hold_ex) begin
            id_valid <= id_accept && !kill_all && !kill_young;
            id_v1    <= id_accept2 && !kill_all && !kill_young;
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
                id_pc_h <= fetch_pc + 32'd4; id_imm_h <= dec_imm_h; id_op_h <= fetch_inst_hi[6:0];
                id_rd_h <= dec_rd_h; id_rs1_h <= dec_rs1_h; id_rs2_h <= dec_rs2_h;
                id_alu_h <= dec_alu_h; id_asel_h <= dec_asel_h; id_bsel_h <= dec_bsel_h;
                id_we_h <= dec_we_h;
                id_pred_h <= fetch_predicted_next_pc_hi;
                id_ctrl_h <= dec_br_h || dec_jal_h; id_jal_h <= dec_jal_h;
                id_br_op_h <= dec_br_op_h;
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
        end else if (!hold_ex) begin
            rr_valid <= id_valid && !kill_all && !kill_young;
            rr_v1    <= id_v1 && !kill_all && !kill_young;
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
            end
        end
    end

    // ------------------------------------------------------------------ M1
    always @(posedge clk) begin
        if (!rst_n) begin
            ex_valid <= 1'b0; ex_pc <= 32'd0; ex_inst <= 32'd0; ex_value <= 32'd0;
            ex_addr <= 32'd0; ex_sdata <= 32'd0; ex_tval <= 32'd0; ex_pred <= 32'd0;
            ex_next <= 32'd0; ex_csr_old <= 32'd0; ex_csr_src <= 32'd0;
            ex_rd <= 5'd0; ex_cause <= 5'd0; ex_we <= 0; ex_load <= 0; ex_store <= 0;
            ex_trap <= 0; ex_ctrl <= 0; ex_uncond <= 0; ex_taken <= 0; ex_uns <= 0;
            ex_csr <= 0; ex_mret <= 0; ex_serial <= 0; ex_size <= 2'd2;
            ex_csr_op <= 2'd0; ex_csr_addr <= 12'd0;
            ex_v1 <= 1'b0; ex_pc_h <= 32'd0; ex_value_h <= 32'd0;
            ex_rd_h <= 5'd0; ex_we_h <= 1'b0;
            ex_ctrl_h <= 1'b0; ex_taken_h <= 1'b0; ex_uncond_h <= 1'b0;
            ex_next_h <= 32'd0;
        end else if (!hold_m1) begin
            ex_valid <= hold_ex ? 1'b0 : (rr_valid && !kill_all);
            ex_v1    <= hold_ex ? 1'b0 : (rr_v1 && !kill_all);
            if (rr_valid && !hold_ex) begin
                ex_pc <= rr_pc; ex_inst <= rr_inst; ex_rd <= rr_rd; ex_we <= rr_we;
                ex_value <= ex_value_w;
                ex_addr <= mem_addr; ex_sdata <= fwd2;
                ex_tval <= ex_tval_w; ex_cause <= ex_cause_w;
                ex_trap <= ex_trap_w;
                ex_ctrl <= is_ctrl; ex_uncond <= (rr_jal || rr_jalr);
                ex_taken <= ctrl_taken; ex_pred <= rr_pred; ex_next <= ctrl_next;
                ex_load <= rr_load; ex_store <= rr_store; ex_size <= rr_size;
                ex_uns <= rr_uns; ex_csr <= rr_csr; ex_mret <= rr_mret;
                ex_serial <= rr_serial; ex_csr_op <= rr_csr_op;
                ex_csr_addr <= rr_csr_addr; ex_csr_old <= rr_csr_old;
                ex_csr_src <= csr_src_w;
                ex_pc_h <= rr_pc_h; ex_value_h <= ex_value_h_w;
                ex_rd_h <= rr_rd_h; ex_we_h <= rr_v1 && rr_we_h;
                ex_ctrl_h <= rr_ctrl_h; ex_taken_h <= ctrl_taken_h;
                ex_uncond_h <= rr_jal_h; ex_next_h <= ctrl_next_h;
            end
        end
    end

    // ------------------------------------------------------------------ M2
    always @(posedge clk) begin
        if (!rst_n) begin
            m_valid <= 1'b0; m_pc <= 32'd0; m_inst <= 32'd0; m_value <= 32'd0;
            m_tval <= 32'd0; m_pred <= 32'd0; m_next <= 32'd0; m_csr_old <= 32'd0;
            m_csr_src <= 32'd0; m_rd <= 5'd0; m_cause <= 5'd0; m_we <= 0; m_trap <= 0;
            m_ctrl <= 0; m_uncond <= 0; m_taken <= 0; m_csr <= 0; m_mret <= 0;
            m_serial <= 0; m_csr_op <= 2'd0; m_csr_addr <= 12'd0;
            m_v1 <= 1'b0; m_pc_h <= 32'd0; m_value_h <= 32'd0;
            m_rd_h <= 5'd0; m_we_h <= 1'b0;
            m_ctrl_h <= 1'b0; m_taken_h <= 1'b0; m_uncond_h <= 1'b0;
            m_next_h <= 32'd0;
        end else if (!hold_wb) begin
            m_valid <= hold_m1 ? 1'b0 : (ex_valid && !kill_all);
            m_v1    <= hold_m1 ? 1'b0 : (ex_v1 && !kill_all);
            if (ex_valid && !hold_m1) begin
                m_pc <= ex_pc; m_inst <= ex_inst; m_rd <= ex_rd; m_we <= ex_we;
                m_value <= (ex_load && mem_rsp) ? load_value : ex_value;
                m_trap <= ex_trap || mem_fault;
                m_cause <= mem_fault ? mem_cause : ex_cause;
                m_tval <= mem_fault ? fault_addr : ex_tval;
                m_ctrl <= ex_ctrl; m_uncond <= ex_uncond; m_taken <= ex_taken;
                m_pred <= ex_pred; m_next <= ex_next;
                m_csr <= ex_csr; m_mret <= ex_mret; m_serial <= ex_serial;
                m_csr_op <= ex_csr_op; m_csr_addr <= ex_csr_addr;
                m_csr_old <= ex_csr_old; m_csr_src <= ex_csr_src;
                m_pc_h <= ex_pc_h; m_value_h <= ex_value_h;
                m_rd_h <= ex_rd_h; m_we_h <= ex_we_h;
                m_ctrl_h <= ex_ctrl_h; m_taken_h <= ex_taken_h;
                m_uncond_h <= ex_uncond_h; m_next_h <= ex_next_h;
            end
        end
    end

    // ------------------------------------------------------------------ WB
    always @(posedge clk) begin
        if (!rst_n) begin
            w_valid <= 1'b0; w_pc <= 32'd0; w_inst <= 32'd0; w_value <= 32'd0;
            w_tval <= 32'd0; w_pred <= 32'd0; w_next <= 32'd0; w_csr_old <= 32'd0;
            w_csr_src <= 32'd0; w_rd <= 5'd0; w_cause <= 5'd0; w_we <= 0; w_trap <= 0;
            w_ctrl <= 0; w_uncond <= 0; w_taken <= 0; w_csr <= 0; w_mret <= 0;
            w_serial <= 0; w_csr_op <= 2'd0; w_csr_addr <= 12'd0;
            w_done_q <= 1'b0;
            w_v1 <= 1'b0; w_pc_h <= 32'd0; w_value_h <= 32'd0;
            w_rd_h <= 5'd0; w_we_h <= 1'b0;
            w_ctrl_h <= 1'b0; w_taken_h <= 1'b0; w_uncond_h <= 1'b0;
            w_next_h <= 32'd0;
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
                w_taken <= m_taken; w_pred <= m_pred; w_next <= m_next;
                w_csr <= m_csr; w_mret <= m_mret; w_serial <= m_serial;
                w_csr_op <= m_csr_op; w_csr_addr <= m_csr_addr;
                w_csr_old <= m_csr_old; w_csr_src <= m_csr_src;
                w_pc_h <= m_pc_h; w_value_h <= m_value_h;
                w_rd_h <= m_rd_h; w_we_h <= m_we_h;
                w_ctrl_h <= m_ctrl_h; w_taken_h <= m_taken_h;
                w_uncond_h <= m_uncond_h; w_next_h <= m_next_h;
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
        mem_issued_q <= (m_is_mem && !mem_rsp) ? (mem_issued_q || mem_accept) : 1'b0;
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
    wire        mem_sel_h     = 1'b0;
    wire        trap1         = 1'b0;
    wire        x_valid       = 1'b0;

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
    always @(posedge clk) if (rst_n && w_commit)
        $display("TR_C pc=%08x v1=%b we=%b rd=%0d val=%08x | h v1=%b we=%b rd=%0d val=%08x | wbwe=%b wbweh=%b",
                 w_pc, w_valid, w_we, w_rd, wb_value, w_v1, w_we_h, w_rd_h, w_value_h,
                 wb_we, wb_we_h);
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
