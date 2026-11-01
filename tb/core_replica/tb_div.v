`timescale 1ns/1ps
module tb_div;
    reg clk = 0, rst = 1, start = 0;
    reg [31:0] a = 0, b = 0;
    reg [2:0]  op = 0;
    wire busy, done;
    wire [31:0] result;

    core_divider dut (.clk(clk), .rst(rst), .start(start), .a(a), .b(b), .op(op),
                      .busy(busy), .done(done), .result(result));

    always #5 clk = ~clk;

    task run1(input [2:0] o, input [31:0] x, input [31:0] y);
        begin
            @(negedge clk);
            op = o; a = x; b = y; start = 1;
            @(negedge clk);
            start = 0;
            while (!done) @(negedge clk);
            $display("op=%0d a=%h b=%h -> %h (busy=%b)", o, x, y, result, busy);
            @(negedge clk);
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        rst = 0;
        run1(3'd4, 32'hFFFFFFFD, 32'd7);   // div -3/7 = 0
        run1(3'd6, 32'hFFFFFFFD, 32'd7);   // rem -3%7 = -3
        run1(3'd4, 32'd100, 32'd7);        // 14
        run1(3'd6, 32'd100, 32'd7);        // 2
        run1(3'd4, 32'd7, 32'd0);          // -1
        run1(3'd6, 32'd7, 32'd0);          // 7
        run1(3'd4, 32'h80000000, 32'hFFFFFFFF);  // 80000000
        run1(3'd6, 32'h80000000, 32'hFFFFFFFF);  // 0
        run1(3'd5, 32'hFFFFFFFF, 32'd2);   // 7FFFFFFF
        run1(3'd7, 32'hFFFFFFFF, 32'd16);  // 15
        $finish;
    end
endmodule
