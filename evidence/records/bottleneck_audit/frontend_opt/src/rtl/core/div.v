//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : div                    File : rtl/core/div.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Iterative shift/subtract divider for RV32M DIV/DIVU/REM/REMU;
//          sign-magnitude preprocessing, 33-bit partial remainder, result is
//          returned as {remainder, quotient} with a ready/busy handshake.
//=============================================================================

`include "defines.v"

module div(
    input  wire               clk,
    input  wire               rst,
    input  wire [`RegBus]     dividend_i,
    input  wire [`RegBus]     divisor_i,
    input  wire               start_i,
    input  wire [2:0]         op_i,
    input  wire [`RegAddrBus] reg_waddr_i,
    output reg  [`RegBus]     result_o,
    output reg                ready_o,
    output reg                busy_o,
    output reg  [`RegAddrBus] reg_waddr_o
);

    //------------------------------------------------------------------ decode
    // op_i[1] selects the remainder, op_i[0] selects an unsigned operation.
    wire op_wants_rem = op_i[1];
    wire op_unsigned  = op_i[0];

    //-------------------------------------------------- operand conditioning
    wire [`RegBus] dvd_neg = ~dividend_i + 32'd1;
    wire [`RegBus] dvs_neg = ~divisor_i + 32'd1;
    wire [`RegBus] dvd_mag = op_unsigned ? dividend_i
                          : (dividend_i[31] ? dvd_neg : dividend_i);
    wire [`RegBus] dvs_mag = op_unsigned ? divisor_i
                          : (divisor_i[31] ? dvs_neg : divisor_i);
    wire zero_divisor = (dvs_mag == `ZeroWord);

    localparam ST_IDLE = 2'b00;
    localparam ST_RUN  = 2'b01;
    localparam ST_HOLD = 2'b10;

    reg [1:0]         st_q;
    reg [4:0]         it_q;        // remaining iterations below the current one
    reg [32:0]        rem_q;       // partial remainder, 33 bits keeps the carry
    reg [31:0]        quo_q;       // quotient built from the MSB downwards
    reg [31:0]        src_q;       // dividend bits still to be shifted in
    reg [31:0]        dvs_q;       // divisor magnitude
    reg [31:0]        dvd_q;       // dividend as supplied (divide-by-zero case)
    reg               rem_sel_q;
    reg               quo_neg_q;
    reg               rem_neg_q;
    reg               zero_div_q;
    reg [`RegAddrBus] waddr_q;

    //-------------------------------------------------------- iteration step
    wire [32:0] rem_shift = {rem_q[31:0], src_q[31]};
    wire [32:0] dvs_ext   = {1'b0, dvs_q};
    wire        ge        = (rem_shift >= dvs_ext);
    wire [32:0] rem_next  = ge ? (rem_shift - dvs_ext) : rem_shift;
    wire [31:0] quo_next  = {quo_q[30:0], ge};
    wire [31:0] src_next  = {src_q[30:0], 1'b0};
    wire        final_it  = (it_q == 5'd0);

    //---------------------------------------------------------- result fixup
    wire [31:0] quo_fix = quo_neg_q ? (~quo_q + 32'd1) : quo_q;
    wire [31:0] rem_fix = rem_neg_q ? (~rem_q[31:0] + 32'd1) : rem_q[31:0];
    wire [31:0] quo_all = zero_div_q ? 32'hFFFFFFFF : quo_fix;
    wire [31:0] rem_all = zero_div_q ? dvd_q : rem_fix;
    wire [31:0] res_all = rem_sel_q ? rem_all : quo_all;

    //------------------------------------------------------------ sequencer
    always @(posedge clk) begin
        if(!rst) begin
            st_q       <= ST_IDLE;
            it_q       <= 5'd0;
            rem_q      <= 33'd0;
            quo_q      <= 32'd0;
            src_q      <= 32'd0;
            dvs_q      <= 32'd0;
            dvd_q      <= 32'd0;
            rem_sel_q  <= 1'b0;
            quo_neg_q  <= 1'b0;
            rem_neg_q  <= 1'b0;
            zero_div_q <= 1'b0;
            waddr_q    <= `ZeroReg;
        end else begin
            case(st_q)
                ST_IDLE: begin
                    if(start_i) begin
                        src_q      <= dvd_mag;
                        dvs_q      <= dvs_mag;
                        dvd_q      <= dividend_i;
                        rem_q      <= 33'd0;
                        quo_q      <= 32'd0;
                        it_q       <= 5'd31;
                        rem_sel_q  <= op_wants_rem;
                        quo_neg_q  <= ~op_unsigned & (dividend_i[31] ^ divisor_i[31]);
                        rem_neg_q  <= ~op_unsigned & dividend_i[31];
                        zero_div_q <= zero_divisor;
                        waddr_q    <= reg_waddr_i;
                        st_q       <= ST_RUN;
                    end
                end
                ST_RUN: begin
                    rem_q <= rem_next;
                    quo_q <= quo_next;
                    src_q <= src_next;
                    if(final_it) begin
                        st_q <= ST_HOLD;
                    end else begin
                        it_q <= it_q - 5'd1;
                    end
                end
                ST_HOLD: begin
                    if(!start_i) st_q <= ST_IDLE;
                end
                default: st_q <= ST_IDLE;
            endcase
        end
    end

    //-------------------------------------------------------------- outputs
    always @(*) begin
        if(!rst) begin
            result_o    = `ZeroWord;
            ready_o     = 1'b0;
            busy_o      = 1'b0;
            reg_waddr_o = `ZeroReg;
        end else if(st_q == ST_HOLD) begin
            result_o    = res_all;
            ready_o     = 1'b1;
            busy_o      = 1'b0;
            reg_waddr_o = waddr_q;
        end else begin
            result_o    = `ZeroWord;
            ready_o     = 1'b0;
            busy_o      = (st_q == ST_RUN);
            reg_waddr_o = `ZeroReg;
        end
    end

endmodule
