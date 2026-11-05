`timescale 1ns/1ps
module tb_requant_q15;
    reg clk=0;
    always #5 clk=~clk;
    reg signed [63:0] product=0;
    wire [7:0] value;
    requant_q15 dut(.clk(clk),.product(product),.value(value));
    reg [7:0] expected[0:2];
    integer count=0, checked=0, i;
    reg [63:0] random_word;
    function [7:0] reference;
        input signed [63:0] p;
        reg [63:0] mag,q;
        begin
            mag=p[63] ? (~p+64'd1) : p;
            q=(mag+64'd16384)>>15;
            reference=p[63] ? (q>=128 ? 8'h80 : 8'd0-q[7:0]) :
                                  (q>127 ? 8'h7f : q[7:0]);
        end
    endfunction
    always @(posedge clk) begin
        expected[2]<=expected[1];
        expected[1]<=expected[0];
        expected[0]<=reference(product);
        count=count+1;
        #1;
        if(count>=3) begin
            if(value!==expected[2]) $fatal(1,"Q15 mismatch value=%h expected=%h",value,expected[2]);
            checked=checked+1;
        end
    end
    task feed(input signed [63:0] p);
        begin @(negedge clk); product=p; end
    endtask
    initial begin
        feed(64'h8000000000000000);
        feed(64'h7fffffffffffffff);
        for(i=-132;i<=132;i=i+1) begin
            feed(i*64'sd32768-16385);feed(i*64'sd32768-16384);
            feed(i*64'sd32768-16383);feed(i*64'sd32768);
        end
        for(i=0;i<20000;i=i+1) begin
            random_word={$random,$random};
            feed($signed(random_word));
            feed($signed(random_word)%64'sd4500000);
        end
        repeat(4) feed(0);
        if(checked<41000) $fatal(1,"Not enough vectors");
        $display("REQUANT_Q15_PASS checked=%0d",checked);
        $finish;
    end
endmodule
