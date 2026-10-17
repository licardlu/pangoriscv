//=============================================================================
// pangoriscv - RV32IM processor core + native AXI4 SoC (Pango PG2L100H @ 27 MHz)
// Module : div_adapter            File : rtl/core/div_adapter.v
// Rev    : 1.0                    Date : 2026-10-13
// Author : pango_lpenghan
// Brief  : Divider handshake adapter: start/done sequencing and result capture
//=============================================================================

module div_adapter(
    input wire clk, input wire rst_n,
    input wire req_valid, output wire req_ready,
    input wire [31:0] dividend, divisor,
    input wire [2:0] op,
    output wire rsp_valid, input wire rsp_ready,
    output wire [31:0] rsp_data
);
    reg active_q, result_valid_q;
    reg [31:0] dividend_q, divisor_q, result_q;
    reg [2:0] op_q;
    wire raw_ready, raw_busy;
    wire [31:0] raw_result;
    wire [4:0] unused_rd;
    wire raw_start = active_q && !raw_ready;
    assign req_ready = rst_n && !active_q && !result_valid_q;
    assign rsp_valid = rst_n && result_valid_q;
    assign rsp_data = result_q;
    div u_div(.clk(clk),.rst(rst_n),.dividend_i(dividend_q),
        .divisor_i(divisor_q),.start_i(raw_start),.op_i(op_q),
        .reg_waddr_i(5'd0),.result_o(raw_result),.ready_o(raw_ready),
        .busy_o(raw_busy),.reg_waddr_o(unused_rd));
    always @(posedge clk) begin
        if(!rst_n) begin
            active_q<=0; result_valid_q<=0;
            dividend_q<=0; divisor_q<=0; op_q<=0; result_q<=0;
        end else begin
            if(req_valid && req_ready) begin
                dividend_q<=dividend; divisor_q<=divisor; op_q<=op;
                active_q<=1;
            end
            if(active_q && raw_ready) begin
                result_q<=raw_result; result_valid_q<=1; active_q<=0;
            end
            if(rsp_valid && rsp_ready) result_valid_q<=0;
        end
    end
endmodule
