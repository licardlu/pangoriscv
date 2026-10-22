//=============================================================================
// pangoriscv - rv32i6: RV32IM core, shallow stages, BRAM memories
// Module : rv32i6_top             File : rtl/core/rv32i6/rv32i6_top.v
// Rev    : 0.3 (G1)               Date : 2026-10-22
// Brief  : F1 / ID / E / M / W, forwarding, load-use interlock, CSR, mul, div
//=============================================================================
// See docs/plan-v11-120mhz-newcore.md for why this core exists.
//
// Flow control contract (this is the part that is easy to get wrong):
//   * A redirect is generated in E.  It flushes the two *younger* stages (the ID
//     register and F1) only.  The instruction in E keeps going into M, because a
//     JAL/JALR in E still has to write its link register.
//   * A load-use stall freezes F1, ID and E together and injects a bubble into
//     M, so the load is not duplicated.
//   * A divide stalls the same way until div_rsp_valid.
//=============================================================================
`include "defines.v"

module rv32i6_top(
    input  wire        clk,
    input  wire        rst_n,

    output wire [31:0] imem_addr,
    input  wire [63:0] imem_data,

    output wire [31:0] dmem_addr,
    output wire        dmem_we,
    output wire [2:0]  dmem_size,
    output wire [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata,

    output wire        retire_fire,
    output wire [31:0] retire_pc,
    output wire [31:0] retire_inst,

    input  wire [4:0]  debug_addr,
    output wire [31:0] debug_data
);
    localparam [31:0] RESET_PC = 32'h0000_0000;
    localparam [31:0] NOP      = 32'h0000_0013;   // addi x0,x0,0

    // ---------------------------------------------------------------------
    // F1 -- address generation with a 2-deep fetch-valid pipeline
    // ---------------------------------------------------------------------
    // The memory registers its data one cycle after the address is presented, so
    // the PC that belongs with `imem_data` is the PC of the PREVIOUS cycle
    // (pc_q), not the current one.  Pairing `imem_data` with the current pc_f was
    // the G1 bug that made the core execute the right instruction at the wrong
    // PC (it cleared .bss forever because the destination pointer never moved).
    // `fill` re-fills the two pipeline slots after a redirect; `capture` gates
    // the ID register so a wrong-path word can never enter it.
    reg  [31:0] pc_f, pc_q;
    reg  [1:0]  fill;
    reg         id_valid;
    wire        stall_lu, stall_div;
    wire        redirect;
    wire [31:0] redirect_pc;
    wire        stall;
    wire        capture = fill[0];

    always @(posedge clk) begin
        if (!rst_n) begin
            pc_f <= RESET_PC; pc_q <= RESET_PC; fill <= 2'b00; id_valid <= 1'b0;
        end else if (redirect) begin
            pc_f <= redirect_pc;
            pc_q <= pc_f;              // in-flight word is wrong-path: capture blocked
            fill <= 2'b00;
            id_valid <= 1'b0;
        end else if (!stall) begin
            pc_f <= pc_f + 32'd4;
            pc_q <= pc_f;
            fill <= {fill[0], 1'b1};
            id_valid <= capture;
        end else begin
            id_valid <= 1'b0;          // stall: hold the fetch, bubble the ID
        end
    end
    assign imem_addr = {pc_f[31:3], 3'b000};

    reg  [31:0] pc_id, inst_id;
    always @(posedge clk) begin
        if (!rst_n) begin
            pc_id <= RESET_PC; inst_id <= NOP;
        end else if (capture && !stall) begin
            pc_id   <= pc_q;
            inst_id <= pc_q[2] ? imem_data[63:32] : imem_data[31:0];
        end
    end

    // ---------------------------------------------------------------------
    // ID
    // ---------------------------------------------------------------------
    wire [4:0]  d_rs1, d_rs2, d_rd;
    wire        d_uses_rs1, d_uses_rs2, d_reg_we;
    wire [3:0]  d_alu_op;
    wire [1:0]  d_a_sel, d_b_sel;
    wire [31:0] d_imm;
    wire        d_load, d_store, d_branch, d_jal, d_jalr, d_csr;
    wire        d_mret, d_ecall, d_ebreak;
    wire [2:0]  d_br_op;
    wire [1:0]  d_mem_size;
    wire        d_load_uns;
    wire        d_mul, d_div;
    wire [2:0]  d_md_op;
    wire [1:0]  d_csr_op;
    wire [11:0] d_csr_addr;
    wire        d_illegal;

    rv32_decode u_dec(
        .inst(inst_id), .rs1(d_rs1), .rs2(d_rs2), .rd(d_rd),
        .uses_rs1(d_uses_rs1), .uses_rs2(d_uses_rs2), .reg_we(d_reg_we),
        .alu_op(d_alu_op), .a_sel(d_a_sel), .b_sel(d_b_sel), .imm(d_imm),
        .is_load(d_load), .is_store(d_store), .is_branch(d_branch),
        .is_jal(d_jal), .is_jalr(d_jalr), .is_csr(d_csr), .is_mret(d_mret),
        .is_ecall(d_ecall), .is_ebreak(d_ebreak), .br_op(d_br_op),
        .mem_size(d_mem_size), .load_unsigned(d_load_uns),
        .is_mul(d_mul), .is_div(d_div), .muldiv_op(d_md_op),
        .csr_op(d_csr_op), .csr_addr(d_csr_addr), .illegal(d_illegal)
    );

    wire        w_we;
    wire [4:0]  w_rd;
    wire [31:0] w_data;
    wire [31:0] rf_r1, rf_r2;

    rv32_regfile u_rf(
        .clk(clk),
        .ra0(d_rs1), .ra1(d_rs2), .ra2(5'd0), .ra3(5'd0),
        .rd0(rf_r1), .rd1(rf_r2), .rd2(), .rd3(),
        .we(w_we), .wa(w_rd), .wd(w_data)
    );
    assign debug_data = rf_r1;   // G1 has no JTAG read port; keep the port legal

    // ---------------------------------------------------------------------
    // ID -> E
    // ---------------------------------------------------------------------
    reg  [31:0] e_pc, e_inst, e_imm, e_r1, e_r2;
    reg  [4:0]  e_rs1, e_rs2, e_rd;
    reg         e_we, e_load, e_store, e_branch, e_jal, e_jalr, e_csr;
    reg         e_mret, e_ecall, e_ebreak, e_illegal, e_mul, e_div;
    reg  [3:0]  e_alu_op;
    reg  [1:0]  e_a_sel, e_b_sel, e_csr_op, e_mem_size;
    reg  [2:0]  e_br_op, e_md_op;
    reg         e_load_uns;
    reg  [11:0] e_csr_addr;

    reg         e_valid;

    always @(posedge clk) begin
        if (!rst_n || redirect) begin
            e_valid <= 1'b0;
        end else if (stall_div) begin
            e_valid <= e_valid;          // hold the divide in place
        end else if (stall_lu) begin
            e_valid <= 1'b0;             // load moves on into M; E takes a bubble
        end else begin
            e_valid <= id_valid;
            if (id_valid) begin
            e_pc <= pc_id; e_inst <= inst_id; e_imm <= d_imm;
            e_rs1 <= d_rs1; e_rs2 <= d_rs2; e_rd <= d_rd;
            e_r1 <= rf_r1; e_r2 <= rf_r2;
            e_we <= d_reg_we; e_load <= d_load; e_store <= d_store;
            e_branch <= d_branch; e_jal <= d_jal; e_jalr <= d_jalr;
            e_csr <= d_csr; e_mret <= d_mret; e_ecall <= d_ecall;
            e_ebreak <= d_ebreak; e_illegal <= d_illegal;
            e_mul <= d_mul; e_div <= d_div;
            e_alu_op <= d_alu_op; e_a_sel <= d_a_sel; e_b_sel <= d_b_sel;
            e_csr_op <= d_csr_op; e_mem_size <= d_mem_size;
            e_br_op <= d_br_op; e_md_op <= d_md_op;
            e_load_uns <= d_load_uns; e_csr_addr <= d_csr_addr;
            end
        end
    end

    // ---------------------------------------------------------------------
    // E
    // ---------------------------------------------------------------------
    wire [31:0] m_value;
    wire        m_we;
    wire [4:0]  m_rd;

    wire [31:0] fwd1 = (m_we && m_rd != 5'd0 && m_rd == e_rs1) ? m_value :
                       (w_we && w_rd != 5'd0 && w_rd == e_rs1) ? w_data : e_r1;
    wire [31:0] fwd2 = (m_we && m_rd != 5'd0 && m_rd == e_rs2) ? m_value :
                       (w_we && w_rd != 5'd0 && w_rd == e_rs2) ? w_data : e_r2;

    wire [31:0] alu_a = (e_a_sel == 2'd1) ? e_pc  :
                        (e_a_sel == 2'd2) ? 32'd0 : fwd1;
    wire [31:0] alu_b = (e_b_sel == 2'd1) ? e_imm : fwd2;

    wire [31:0] alu_y;
    wire        alu_eq, alu_lt, alu_ltu;
    rv32_alu u_alu(.op(e_alu_op), .a(alu_a), .b(alu_b),
                   .y(alu_y), .eq(alu_eq), .lt(alu_lt), .ltu(alu_ltu));

    wire br_taken = (e_br_op == 3'd0) ?  alu_eq  :
                    (e_br_op == 3'd1) ? !alu_eq  :
                    (e_br_op == 3'd2) ?  alu_lt  :
                    (e_br_op == 3'd3) ? !alu_lt  :
                    (e_br_op == 3'd4) ?  alu_ltu : !alu_ltu;

    wire [31:0] pc_plus4  = e_pc + 32'd4;
    wire [31:0] br_target = e_pc + e_imm;
    wire [31:0] jr_target = fwd1 + e_imm;
    wire        is_ctrl   = e_valid && (e_branch || e_jal || e_jalr);
    wire        ctrl_take = e_jal || e_jalr || (e_branch && br_taken);
    wire [31:0] ctrl_next = e_jalr ? jr_target : e_jal ? br_target :
                            (e_branch && br_taken) ? br_target : pc_plus4;
    // G1 predicts not-taken: every taken control transfer redirects.
    wire        ctrl_miss = is_ctrl && (ctrl_next != pc_plus4);

    wire [31:0] mem_addr_e = fwd1 + e_imm;
    wire        mem_misaln = e_valid && (e_load || e_store) &&
                             ((e_mem_size == 2'd1 && mem_addr_e[0]) ||
                              (e_mem_size == 2'd2 && (|mem_addr_e[1:0])));
    wire        ctrl_misaln = is_ctrl && ctrl_take && (br_target[1:0] != 2'b00);

    // CSR read (combinational) for the instruction in E.
    wire [31:0] csr_rdata;
    wire        csr_illegal;
    wire [31:0] csr_vector_w, csr_mepc_w;
    wire        e_csr_illegal = e_csr && csr_illegal;

    wire        e_trap = e_valid && (e_illegal || e_csr_illegal || e_ecall ||
                                     e_ebreak || mem_misaln || ctrl_misaln);
    wire [4:0]  e_cause = (e_illegal || e_csr_illegal) ? 5'd2 :
                          e_ecall   ? 5'd11 :
                          e_ebreak  ? 5'd3  :
                          mem_misaln ? (e_store ? 5'd6 : 5'd4) :
                          ctrl_misaln ? 5'd0 : 5'd0;

    wire        mret = e_valid && e_mret;
    assign redirect    = ctrl_miss || e_trap || mret;
    assign redirect_pc = e_trap  ? csr_vector_w :
                         mret    ? csr_mepc_w  : ctrl_next;

    // divide
    wire        div_req_valid, div_req_ready, div_rsp_valid, div_rsp_ready;
    wire [31:0] div_result;
    reg         div_issued_q;
    wire        div_busy = e_valid && e_div && !div_rsp_valid;
    always @(posedge clk) begin
        if (!rst_n)            div_issued_q <= 1'b0;
        else if (redirect)     div_issued_q <= 1'b0;
        else if (div_req_valid && div_req_ready) div_issued_q <= 1'b1;
    end

    // Two different stalls, because they freeze different stages:
    //   * load-use: the load must CONTINUE into M (that is where its data comes
    //     from) while ID is held and E takes a bubble.  Holding E instead -- the
    //     first version of this module -- dropped the load's result and then
    //     drained the pipeline, and holding `id_valid` low lost the consumer.
    //   * divide: the divide needs E held until the quotient is back, so E and M
    //     both stand still and M takes a bubble.
    wire id_reads_e  = ((d_uses_rs1 && d_rs1 == e_rd) ||
                        (d_uses_rs2 && d_rs2 == e_rd)) && e_we && e_rd != 5'd0;
    assign stall_lu  = e_valid && e_load && id_reads_e;
    assign stall_div = div_busy;
    assign stall     = stall_lu || stall_div;

    // ---------------------------------------------------------------------
    // E -> M
    // ---------------------------------------------------------------------
    reg  [31:0] m_pc, m_inst, m_result_r, m_store_data, m_addr, m_csr_old;
    reg  [4:0]  m_rd_r;
    reg         m_we_r, m_load_r, m_store_r, m_mul_r, m_div_r, m_csr_r;
    reg  [1:0]  m_mem_size_r, m_csr_op_r;
    reg         m_load_uns_r;
    reg  [31:0] m_csr_operand;
    reg         m_valid;

    wire [31:0] mul_y;
    rv32_mul u_mul(.op(e_md_op), .a(fwd1), .b(fwd2), .y(mul_y));

    always @(posedge clk) begin
        if (!rst_n) begin
            m_valid <= 1'b0; m_we_r <= 1'b0; m_load_r <= 1'b0;
            m_store_r <= 1'b0; m_mul_r <= 1'b0; m_div_r <= 1'b0; m_csr_r <= 1'b0;
        end else if (stall_div) begin
            // E is held this cycle, so M must not latch it a second time
            m_valid <= 1'b0; m_we_r <= 1'b0; m_load_r <= 1'b0;
            m_store_r <= 1'b0; m_mul_r <= 1'b0; m_div_r <= 1'b0; m_csr_r <= 1'b0;
        end else begin
            m_valid <= e_valid;
            m_pc <= e_pc; m_inst <= e_inst;
            m_we_r <= e_we && !e_trap && e_valid;
            m_rd_r <= e_rd;
            m_result_r <= e_csr ? csr_rdata : alu_y;
            m_load_r <= e_load && !e_trap && e_valid;
            m_store_r <= e_store && !e_trap && e_valid;
            m_mul_r <= e_mul && e_valid;
            m_div_r <= e_div && e_valid;
            m_mem_size_r <= e_mem_size; m_load_uns_r <= e_load_uns;
            m_store_data <= fwd2; m_addr <= mem_addr_e;
            m_csr_r <= e_csr && !e_trap && e_valid;
            m_csr_op_r <= e_csr_op;
            m_csr_old <= csr_rdata;
            m_csr_operand <= (e_csr_op == 2'd0) ? 32'd0 :
                             e_inst[14] ? {27'd0, e_inst[19:15]} : fwd1;
        end
    end

    assign dmem_addr  = m_addr;
    assign dmem_we    = m_store_r;
    assign dmem_size  = {1'b0, m_mem_size_r};
    assign dmem_wdata = m_store_data;

    wire [7:0]  ld_b = (m_addr[1:0] == 2'd0) ? dmem_rdata[7:0]   :
                       (m_addr[1:0] == 2'd1) ? dmem_rdata[15:8]  :
                       (m_addr[1:0] == 2'd2) ? dmem_rdata[23:16] : dmem_rdata[31:24];
    wire [15:0] ld_h = m_addr[1] ? dmem_rdata[31:16] : dmem_rdata[15:0];
    wire [31:0] ld_data = (m_mem_size_r == 2'd0) ?
                            (m_load_uns_r ? {24'd0, ld_b} : {{24{ld_b[7]}}, ld_b}) :
                          (m_mem_size_r == 2'd1) ?
                            (m_load_uns_r ? {16'd0, ld_h} : {{16{ld_h[15]}}, ld_h}) :
                            dmem_rdata;

    wire [31:0] csr_new = (m_csr_op_r == 2'd2) ? (m_csr_old | m_csr_operand) :
                          (m_csr_op_r == 2'd3) ? (m_csr_old & ~m_csr_operand) :
                                                 m_csr_operand;

    assign m_we     = m_we_r;
    assign m_rd     = m_rd_r;
    assign m_value  = m_mul_r ? mul_y : m_load_r ? ld_data : m_result_r;

    // ---------------------------------------------------------------------
    // CSR / trap
    // ---------------------------------------------------------------------
    csr_native u_csr(
        .clk(clk), .rst_n(rst_n),
        .addr(e_csr ? e_csr_addr : 12'h000),
        .write_intent(e_csr),
        .commit(m_csr_r),
        .retire(m_valid),
        .retire_count(2'd1),
        .mret_fire(mret),
        .trap_enter(e_trap),
        .write_data(csr_new),
        .trap_pc(e_pc), .trap_cause({27'd0, e_cause}), .trap_tval(e_inst),
        .irq_software(1'b0), .irq_timer(1'b0), .irq_external(1'b0),
        .read_data(csr_rdata), .illegal(csr_illegal),
        .vector(csr_vector_w), .mepc_value(csr_mepc_w),
        .irq_pending(), .irq_cause()
    );

    // divide adapter
    assign div_req_valid = e_valid && e_div && !e_trap && !div_issued_q;
    assign div_rsp_ready = 1'b1;
    div_adapter u_div(.clk(clk), .rst_n(rst_n), .req_valid(div_req_valid),
        .req_ready(div_req_ready), .dividend(fwd1), .divisor(fwd2),
        .op(e_md_op), .rsp_valid(div_rsp_valid), .rsp_ready(div_rsp_ready),
        .rsp_data(div_result));

    // ---------------------------------------------------------------------
    // W
    // ---------------------------------------------------------------------
    reg  [4:0]  w_rd_r;
    reg         w_we_r;
    reg  [31:0] w_data_r;
    always @(posedge clk) begin
        if (!rst_n) begin
            w_we_r <= 1'b0; w_rd_r <= 5'd0; w_data_r <= 32'd0;
        end else begin
            w_we_r <= m_we;
            w_rd_r <= m_rd;
            w_data_r <= m_value;
        end
    end
    // The architectural write happens in W; M->E and W->E forwarding cover the
    // two consumers that would otherwise read the old value.
    assign w_we   = w_we_r;
    assign w_rd   = w_rd_r;
    assign w_data = w_data_r;

    assign retire_fire  = m_valid;
    assign retire_pc    = m_pc;
    assign retire_inst  = m_inst;

endmodule
