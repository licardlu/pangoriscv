//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : if_id                  File : rtl/core/if_id.v
// Rev    : 1.1                    Date : 2026-10-19
// Author : pango_lpenghan
// Brief  : IF to ID pipeline register, two instruction slots (superscalar)
//=============================================================================

// Two-slot IF/ID buffer.  The IFU can deliver an 8 B pair per cycle; the buffer
// accepts both when it is empty, otherwise it accepts one and the IFU keeps the
// second word in its own queue for the next cycle.  The ID/EX stage takes one
// instruction per slot; when the decode/issue logic can pair them it asserts
// out_ready1 as well and both leave together.
module if_id(
    input wire clk, rst_n, flush,
    input wire in_valid, input wire in_pair,
    output wire in_ready, output wire in_ready2,
    input wire [31:0] pc_i, inst_i,
    input wire [31:0] pc_hi_i, inst_hi_i,
    input wire fault_i, input wire [4:0] fault_cause_i,
    input wire [31:0] fault_tval_i, predicted_next_pc_i,
    input wire fault_hi_i, input wire [4:0] fault_cause_hi_i,
    input wire [31:0] fault_tval_hi_i, predicted_next_pc_hi_i,
    output wire out_valid0, output wire out_valid1,
    input wire out_ready0, input wire out_ready1,
    output wire [31:0] pc_o, inst_o,
    output wire fault_o, output wire [4:0] fault_cause_o,
    output wire [31:0] fault_tval_o, predicted_next_pc_o,
    output wire [31:0] pc_hi_o, inst_hi_o,
    output wire fault_hi_o, output wire [4:0] fault_cause_hi_o,
    output wire [31:0] fault_tval_hi_o, predicted_next_pc_hi_o
);
    localparam WIDTH = 32+32+1+5+32+32;

    reg valid0_q, valid1_q;
    reg [WIDTH-1:0] data0_q, data1_q;

    wire take2 = in_valid && in_pair && in_ready2;
    wire take1 = in_valid && in_ready && !take2;

    // Free slots after this edge's pop: out_ready1 empties both, out_ready0
    // empties slot0 (slot1 shifts down), otherwise count the invalid slots.
    wire pop_pair = out_ready1 && valid1_q;
    wire pop_one  = out_ready0 && valid0_q && !pop_pair;
    wire [1:0] free_after = pop_pair ? 2'd2 :
                            pop_one  ? (valid1_q ? 2'd1 : 2'd2) :
                            ({1'b0,!valid0_q} + {1'b0,!valid1_q});
    assign in_ready  = (free_after >= 2'd1);
    assign in_ready2 = (free_after >= 2'd2);

    assign out_valid0 = rst_n && !flush && valid0_q;
    assign out_valid1 = rst_n && !flush && valid1_q;

    wire [WIDTH-1:0] payload0 = {pc_i,inst_i,fault_i,fault_cause_i,fault_tval_i,predicted_next_pc_i};
    wire [WIDTH-1:0] payload1 = {pc_hi_i,inst_hi_i,fault_hi_i,fault_cause_hi_i,
                                 fault_tval_hi_i,predicted_next_pc_hi_i};

    assign {pc_o,inst_o,fault_o,fault_cause_o,fault_tval_o,predicted_next_pc_o} = data0_q;
    assign {pc_hi_o,inst_hi_o,fault_hi_o,fault_cause_hi_o,
            fault_tval_hi_o,predicted_next_pc_hi_o} = data1_q;

    // Accept a single instruction into the first free slot.  It goes to slot 1
    // whenever only one slot is free after this edge's pops (including the
    // case where slot 1 shifts down into slot 0 on pop_one).  Using
    // "valid0 && !out_ready0" here was wrong for pop_one+take1: the shifted
    // slot-1 instruction was overwritten by the new one.
    wire load_into1 = take1 && (free_after == 2'd1);

    always @(posedge clk) begin
        if (!rst_n) begin
            valid0_q <= 1'b0;
            valid1_q <= 1'b0;
            data0_q  <= {WIDTH{1'b0}};
            data1_q  <= {WIDTH{1'b0}};
        end else if (flush) begin
            valid0_q <= 1'b0;
            valid1_q <= 1'b0;
        end else begin
            // ---- pop ------------------------------------------------------
            if (pop_pair) begin
                valid0_q <= 1'b0;
                valid1_q <= 1'b0;
            end else if (pop_one) begin
                // slot1 (if any) shifts into slot0
                valid0_q <= valid1_q;
                if (valid1_q) data0_q <= data1_q;
                valid1_q <= 1'b0;
            end

            // ---- push (takes priority over the shift result) --------------
            if (take2) begin
                data0_q  <= payload0;
                data1_q  <= payload1;
                valid0_q <= 1'b1;
                valid1_q <= 1'b1;
            end else if (take1) begin
                if (load_into1) begin
                    data1_q  <= payload0;
                    valid1_q <= 1'b1;
                end else begin
                    data0_q  <= payload0;
                    valid0_q <= 1'b1;
                end
            end
        end
    end
endmodule
