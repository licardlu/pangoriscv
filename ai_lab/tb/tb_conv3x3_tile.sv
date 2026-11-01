`timescale 1ns/1ps
module tb_conv3x3_tile;
    reg clk, rst_n, start;
    wire done, out_valid;
    wire [5:0] out_idx;
    wire signed [7:0] out_data;
    reg signed [7:0] expected [0:31];
    reg signed [7:0] captured [0:31];
    integer i, got, errors, cycles;
    conv3x3_tile dut(.clk(clk), .rst_n(rst_n), .start(start), .done(done),
                     .out_valid(out_valid), .out_idx(out_idx), .out_data(out_data));
    initial clk = 1'b0;
    always #5 clk = ~clk; // 100 MHz simulation clock (cycle count independent of period)
    always @(posedge clk) if (rst_n) begin
        if (!done) cycles <= cycles + 1;
        if (out_valid) begin captured[out_idx] <= out_data; got <= got + 1; end
    end
    initial begin
        $readmemh("expected.hex", expected);
        got=0; errors=0; cycles=0; rst_n=1'b0; start=1'b0;
        repeat(3) @(posedge clk);
        rst_n=1'b1; repeat(2) @(posedge clk);
        start<=1'b1; @(posedge clk); start<=1'b0;
        wait(done); repeat(3) @(posedge clk);
        for (i=0; i<32; i=i+1) begin
            if (captured[i] !== expected[i]) begin
                errors=errors+1;
                $display("MISMATCH idx=%0d got=%0d expected=%0d", i, captured[i], expected[i]);
            end
        end
        $display("T4_RESULT got=%0d errors=%0d cycles=%0d", got, errors, cycles);
        if (got==32 && errors==0) $display("T4_PASS");
        else $display("T4_FAIL");
        $finish;
    end
endmodule
