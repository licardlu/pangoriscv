`timescale 1ns/1ps
module tb_branch_eq_pipeline;
  reg clk=0,enable=0,src1_upper=0;
  reg [1:0] src2_ctrl=0;
  reg [31:0] rs1=0,rs2=0,uop=0,pc=0;
  wire eq;
  reg [31:0] a,b;
  reg expected;
  integer i,seed=32'h31415926;
  always #5 clk=~clk;
  branch_eq_pipeline dut(.*);
  always @* begin
    a=32'hxxxxxxxx;
    case(src1_upper)
      1'b0:a=rs1;
      default:a={uop[31:12],12'b0};
    endcase
    b=32'hxxxxxxxx;
    case(src2_ctrl)
      2'd0:b=rs2;
      2'd1:b={{20{uop[31]}},uop[31:20]};
      2'd2:b=pc;
      default:begin end
    endcase
  end
  initial begin
    for(i=0;i<12000;i=i+1) begin
      @(negedge clk);
      enable=($random(seed)&3)!=0;
      src1_upper=$random(seed);src2_ctrl=$random(seed);
      rs1=$random(seed);rs2=$random(seed);uop=$random(seed);pc=$random(seed);
      if(i%5==0)rs2=rs1;
      if(i%7==0)rs1={uop[31:12],12'b0};
      if(i%11==0)pc=rs1;
      #1;
      if(enable) expected=(a==b);
      @(posedge clk);#1;
      if(eq !== expected)$fatal(1,"EQ/stall mismatch vector=%d expected=%b got=%b",i,expected,eq);
    end
    $display("TEST_PASS branch_eq_pipeline vectors=12000 includes_stalls_and_invalid_selectors");
    $finish;
  end
endmodule
