//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : pipe_slot              File : rtl/core/pipe_slot.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Pipeline slot handshake (valid/ready back-pressure, flush semantics)
//=============================================================================

module pipe_slot #(parameter WIDTH = 32)(
    input wire clk, input wire rst_n, input wire flush,
    input wire in_valid, output wire in_ready,
    input wire [WIDTH-1:0] in_data,
    output wire out_valid, input wire out_ready,
    output wire [WIDTH-1:0] out_data
);
    reg valid_q;
    reg [WIDTH-1:0] data_q;
    assign in_ready = rst_n && !flush && (!valid_q || out_ready);
    assign out_valid = rst_n && !flush && valid_q;
    assign out_data = data_q;
    // P33: asynchronous reset on purpose.  A LUTRAM primitive has no asynchronous
    // reset, so this forces the synthesizer to implement data_q as flip-flops instead
    // of packing the wide enabled register into 32x2 LUTRAM cells.  Those cells were
    // the worst hold paths in the delivered build (FF -> LUTRAM WADDR/DI pins with
    // 0.55 ns of clock skew, slack +0.024 ns), and hold is the binding constraint at
    // 27 MHz.  rst_n comes from the reset synchroniser, so the deassertion is still
    // synchronous in practice.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_q <= 1'b0;
            data_q <= {WIDTH{1'b0}};
        end else if (flush) begin
            valid_q <= 1'b0;
        end else if (in_ready) begin
            valid_q <= in_valid;
            if (in_valid) data_q <= in_data;
        end
    end
endmodule
