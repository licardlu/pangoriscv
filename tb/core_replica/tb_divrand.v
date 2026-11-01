`timescale 1ns/1ps
module tb_divrand;
    reg clk=0, rst=1, start=0;
    reg [31:0] a=0,b=0; reg [2:0] op=0;
    wire busy,done; wire [31:0] result;
    core_divider dut(.clk(clk),.rst(rst),.start(start),.a(a),.b(b),.op(op),
                     .busy(busy),.done(done),.result(result));
    always #5 clk=~clk;

    integer errors=0, n=0;
    reg [31:0] ea, eb; reg [2:0] eop;
    reg [63:0] sa, sb, q, r;

    task t(input [2:0] o, input [31:0] x, input [31:0] y);
        reg [31:0] exp;
        begin
            @(negedge clk); op=o; a=x; b=y; start=1;
            @(negedge clk); start=0;
            while(!done) @(negedge clk);
            // 参考值用 ModelSim 的 32/64 位整数运算算
            case(o)
              3'd4: begin // DIV signed
                  if (y==0) exp = 32'hFFFFFFFF;
                  else if (x==32'h80000000 && y==32'hFFFFFFFF) exp = 32'h80000000;
                  else begin
                      q = $signed(x) / $signed(y);
                      exp = q[31:0];
                  end
              end
              3'd5: exp = (y==0) ? 32'hFFFFFFFF : (x / y);
              3'd6: begin
                  if (y==0) exp = x;
                  else if (x==32'h80000000 && y==32'hFFFFFFFF) exp = 32'd0;
                  else begin
                      r = $signed(x) % $signed(y);
                      exp = r[31:0];
                  end
              end
              default: exp = (y==0) ? x : (x % y);
            endcase
            n = n + 1;
            if (result !== exp) begin
                errors = errors + 1;
                if (errors < 8)
                  $display("MISMATCH op=%0d a=%h b=%h got=%h exp=%h", o, x, y, result, exp);
            end
            @(negedge clk);
        end
    endtask

    integer i;
    initial begin
        repeat(3) @(posedge clk); rst=0;
        // 固定边界
        t(3'd4,32'h80000000,32'hFFFFFFFF); t(3'd6,32'h80000000,32'hFFFFFFFF);
        t(3'd5,32'hFFFFFFFF,32'd10);       t(3'd7,32'hFFFFFFFF,32'd10);
        t(3'd4,32'hFFFFFFF9,32'd10);       t(3'd6,32'hFFFFFFF9,32'd10);
        // 随机
        for (i=0;i<300;i=i+1) begin
            t(3'd4 + (i % 4), $random, $random);
        end
        $display("DIVRAND done=%0d errors=%0d", n, errors);
        $finish;
    end
endmodule
