// tb_postop -- exhaustive check of postop_engine against the numpy reference.
//
// Same DDR model as the convolution testbench: flat 64-bit words, one-cycle read
// latency, acked writes.  Vectors from scripts/gen_postop.py, which computes the
// expected output independently of the RTL.
`timescale 1ns/1ps

module tb_postop;

`include "post_params.vh"

    reg clk = 0, rstn = 0;
    always #5 clk = ~clk;

    reg         start = 0;
    wire        busy, done, err;
    wire [31:0] cycles;

    wire [31:0] rd_addr_w;
    wire        rd_req_w;
    wire [63:0] rd_data_w;
    wire        rd_valid_w;
    wire        rd_err_w = 1'b0;

    wire [31:0] wr_addr_w;
    wire [63:0] wr_data_w;
    wire        wr_req_w;
    reg         wr_ack_w;

    postop_engine #(
        .C(Q_C), .IN_W(Q_IN_W), .IN_H(Q_IN_H), .K(Q_K),
        .STRIDE(Q_STRIDE), .OP(Q_OP)
    ) dut (
        .clk(clk), .rstn(rstn), .start(start), .busy(busy), .done(done),
        .err(err), .cycles(cycles),
        .a_base(Q_A_BASE), .b_base(Q_B_BASE), .y_base(Q_Y_BASE), .ca(Q_CA),
        .rd_addr(rd_addr_w), .rd_req(rd_req_w), .rd_data(rd_data_w),
        .rd_valid(rd_valid_w), .rd_err(rd_err_w),
        .wr_addr(wr_addr_w), .wr_data(wr_data_w), .wr_req(wr_req_w),
        .wr_ack(wr_ack_w), .wr_err(1'b0)
    );

    reg [63:0] mem [0:Q_MEMW-1];
    reg [63:0] exp_mem [0:Q_NOUT-1];
    integer k, i, errors;
    reg [63:0] got;

    reg        rd_valid_r;
    reg [63:0] rd_data_r;
    always @(posedge clk) begin
        rd_valid_r <= rd_req_w;
        rd_data_r  <= mem[rd_addr_w];
    end
    assign rd_data_w  = rd_data_r;
    assign rd_valid_w = rd_valid_r;

    always @(posedge clk) begin
        if (!rstn) wr_ack_w <= 1'b0;
        else begin
            wr_ack_w <= 1'b0;
            if (wr_req_w && !wr_ack_w) begin
                mem[wr_addr_w] <= wr_data_w;
                wr_ack_w <= 1'b1;
            end
        end
    end

    initial begin
        for (k = 0; k < Q_MEMW; k = k + 1) mem[k] = 64'd0;
        $readmemh(`Q_DDR, mem);
        $readmemh(`Q_EXP, exp_mem);
        if (mem[0] === 64'd0 && exp_mem[0] === 64'd0)
            $fatal(1, "vector load failed: both arrays are zero");

        repeat (4) @(posedge clk);
        rstn = 1;
        repeat (2) @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        fork : wd
            begin
                wait (done === 1'b1);
                disable wd;
            end
            begin
                repeat (Q_OH * Q_OW * (Q_C / 8) * 40 + 200000) @(posedge clk);
                $display("TIMEOUT st=%0d row=%0d col=%0d cv=%0d sub=%0d",
                         dut.st, dut.row, dut.col, dut.cv, dut.sub);
                disable wd;
            end
        join

        errors = 0;
        if (err) begin
            $display("FAIL: engine asserted err");
            errors = errors + 1;
        end
        for (i = 0; i < Q_NOUT; i = i + 1) begin
            got = mem[(Q_Y_BASE >> 3) + i];
            if (got !== exp_mem[i]) begin
                errors = errors + 1;
                if (errors <= 6)
                    $display("MISMATCH word %0d: got %016x exp %016x", i, got, exp_mem[i]);
            end
        end
        if (errors == 0)
            $display("POSTOP-PASS  op=%0d  %0d words  cycles=%0d", Q_OP, Q_NOUT, cycles);
        else
            $display("POSTOP-FAIL  op=%0d  %0d errors of %0d", Q_OP, errors, Q_NOUT);
        $finish;
    end

endmodule
