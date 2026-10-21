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

    // EX -> M1
    reg         ex_valid;
    reg  [31:0] ex_pc, ex_inst, ex_value, ex_addr, ex_sdata, ex_tval, ex_pred, ex_next;
    reg  [31:0] ex_csr_old, ex_csr_src;
    reg  [4:0]  ex_rd, ex_cause;
    reg         ex_we, ex_load, ex_store, ex_trap, ex_ctrl, ex_uncond, ex_taken;
    reg         ex_uns, ex_csr, ex_mret, ex_serial;
    reg  [1:0]  ex_size, ex_csr_op;
    reg  [11:0] ex_csr_addr;

    // M1 -> M2
    reg         m_valid;
    reg  [31:0] m_pc, m_inst, m_value, m_tval, m_pred, m_next;
    reg  [31:0] m_csr_old, m_csr_src;
    reg  [4:0]  m_rd, m_cause;
    reg         m_we, m_trap, m_ctrl, m_uncond, m_taken, m_csr, m_mret, m_serial;
    reg  [1:0]  m_csr_op;
    reg  [11:0] m_csr_addr;

    // M2 -> WB
    reg         w_valid;
    reg  [31:0] w_pc, w_inst, w_value, w_tval, w_pred, w_next;
    reg  [31:0] w_csr_old, w_csr_src;
    reg  [4:0]  w_rd, w_cause;
    reg         w_we, w_trap, w_ctrl, w_uncond, w_taken, w_csr, w_mret, w_serial;
    reg  [1:0]  w_csr_op;
    reg  [11:0] w_csr_addr;

    // ========================================================= fetch / PC
    reg  [31:0] pc_q;
    wire        fetch_fire = fetch_valid && fetch_ready;
    assign      request_pc = pc_q;

    reg         halted_q, halt_pending_q, serial_q, mem_issued_q, div_issued_q;
    reg  [31:0] arch_next_q;
    reg  [63:0] retire_cnt_q;

    // Declared early: the hazard block needs the memory handshake.
    wire issue_mem;
    wire mem_accept = issue_mem && op_ready;

    // ========================================================= hazards
    wire m_is_mem   = ex_valid && (ex_load || ex_store) && !ex_trap;
    wire load_use   = ex_valid && ex_load && ex_we &&
                      ((ex_rd == rr_rs1) || (ex_rd == rr_rs2));
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

    rv32_regfile u_regs(
        .clk(clk),
        // Addresses come from the instruction currently in EX, not from the
        // one being decoded: the array read is asynchronous, so the operand
        // belongs to whoever is asking right now and a frozen stage freezes
        // its own operand for free (rev 2.0 of rv32_regfile).
        .ra0(rr_rs1), .ra1(rr_rs2), .ra2(5'd0), .ra3(5'd0),
        .rd0(rf_d0), .rd1(rf_d1), .rd2(), .rd3(),
        .we(wb_we), .wa(w_rd), .wd(wb_value)
    );

    // ========================================================= bypass
    wire [31:0] fwd1 =
        (ex_valid && ex_we && !ex_load && !ex_trap && (ex_rd == rr_rs1) && (ex_rd != 5'd0)) ? ex_value :
        (m_valid  && m_we  && !m_trap  && (m_rd  == rr_rs1) && (m_rd  != 5'd0)) ? m_value :
        (wb_we    && (w_rd == rr_rs1)) ? w_value : rf_d0;
    wire [31:0] fwd2 =
        (ex_valid && ex_we && !ex_load && !ex_trap && (ex_rd == rr_rs2) && (ex_rd != 5'd0)) ? ex_value :
        (m_valid  && m_we  && !m_trap  && (m_rd  == rr_rs2) && (m_rd  != 5'd0)) ? m_value :
        (wb_we    && (w_rd == rr_rs2)) ? w_value : rf_d1;

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
    wire [31:0] ex_value_w  = rr_mul ? mul_y : rr_div ? div_result : alu_y;

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

    // mepc: a synchronous trap returns to the faulting instruction, an
    // interrupt returns to the instruction that would have run next.
    wire [31:0] trap_tgt_pc = irq_trap ? w_next : w_pc;
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
        .retire(w_commit), .retire_count(2'd1),
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
    wire        br_miss  = rr_valid && is_ctrl && !ex_trap_w && (ctrl_next != rr_pred);
    wire        resume   = halted_q && !halt_req;
    wire        redirect_any = trap_go || mret_go || br_miss || resume;
    wire [31:0] redirect_target = trap_go ? csr_vector :
                                  mret_go ? csr_mepc :
                                  br_miss ? ctrl_next : arch_next_q;

    // Kill masks: a trap/MRET in WB is older than every other stage.
    wire kill_all   = trap_go || mret_go;
    wire kill_young = br_miss;

    assign redirect_valid = redirect_any;
    assign redirect_pc    = redirect_target;
    assign pred_miss      = br_miss;

    always @(posedge clk) begin
        if (!rst_n) pc_q <= RESET_PC;
        else if (redirect_any) pc_q <= redirect_target;
        else if (fetch_fire) pc_q <= fetch_predicted_next_pc;
    end

    // ========================================================= predictor
    wire        pred_take, ct_take, ct_take2;
    wire [31:0] pred_target, ct_target, ct_target2;
    branch_predictor u_bp(
        .clk(clk), .rst_n(rst_n),
        .fetch_pc(pc_q), .predict_taken(pred_take), .predict_target(pred_target),
        .fetch_pc2(chain_c), .predict_taken2(ct_take), .predict_target2(ct_target),
        .fetch_pc3(chain_c2), .predict_taken3(ct_take2), .predict_target3(ct_target2),
        .train_valid(w_commit), .train_pc(w_pc), .train_control(w_ctrl),
        .train_uncond(w_uncond), .train_taken(w_taken), .train_target(w_next)
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
            if (w_commit && !irq_trap) arch_next_q <= w_next;
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
    assign rd_valid_h  = 1'b0;
    assign rd_h        = 5'd0;
    assign wdata_h     = 32'd0;
    assign trap_fire   = trap_go;
    assign trap_pc     = trap_tgt_pc;
    assign trap_cause  = trap_code;
    assign trap_tval   = trap_tval_i;
    assign debug_data  = 32'd0;

    always @(posedge clk) begin
        if (!rst_n) retire_cnt_q <= 64'd0;
        else if (retire_fire) retire_cnt_q <= retire_cnt_q + 64'd1;
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
    wire id_accept = fetch_valid && fetch_ready;
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
        end else if (!hold_ex) begin
            id_valid <= id_accept && !kill_all && !kill_young;
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
        end else if (!hold_ex) begin
            rr_valid <= id_valid && !kill_all && !kill_young;
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
        end else if (!hold_m1) begin
            ex_valid <= hold_ex ? 1'b0 : (rr_valid && !kill_all);
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
        end else if (!hold_wb) begin
            m_valid <= hold_m1 ? 1'b0 : (ex_valid && !kill_all);
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
        end else if (!hold_wb) begin
            w_valid <= m_valid && !trap_go && !mret_go;
            w_done_q <= 1'b0;
            if (m_valid) begin
                w_pc <= m_pc; w_inst <= m_inst; w_rd <= m_rd; w_we <= m_we;
                w_value <= m_value; w_trap <= m_trap; w_cause <= m_cause;
                w_tval <= m_tval; w_ctrl <= m_ctrl; w_uncond <= m_uncond;
                w_taken <= m_taken; w_pred <= m_pred; w_next <= m_next;
                w_csr <= m_csr; w_mret <= m_mret; w_serial <= m_serial;
                w_csr_op <= m_csr_op; w_csr_addr <= m_csr_addr;
                w_csr_old <= m_csr_old; w_csr_src <= m_csr_src;
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
    assign fetch_ready2 = 1'b0;

    // ========================================================= TB compatibility
    // tb_isa_e2e reports dual-issue coverage statistics by name.  The P1 core is
    // single issue, so every one of those probes reads false; keeping the names
    // means one testbench covers both cores instead of forking it.
    wire        ex_valid_h    = 1'b0;
    wire        older_control = 1'b0;
    wire        retire1       = 1'b0;
    wire        retire0       = retire_fire;
    wire [31:0] ep_h          = 32'd0;
    wire [31:0] ep            = w_pc;
    wire        young_path_ok = 1'b1;
    wire        mem_sel_h     = 1'b0;
    wire        trap1         = 1'b0;
    wire        x_valid       = 1'b0;
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
