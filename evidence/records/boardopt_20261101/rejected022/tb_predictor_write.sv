`timescale 1ns/1ps
module tb_predictor_write;
  reg clk=0,enable=0,init_busy=0;
  always #5 clk=~clk;
  reg [11:0] address=0;
  reg [1:0] bank=0;
  reg [7:0] data=0;
  wire [7:0] value;
  extracted_write dut(clk,enable,init_busy,address,bank,data,value);
  task write_word(input bit init_value,input [1:0] selected,input [7:0] word_value);
    begin
      @(negedge clk);enable=1;init_busy=init_value;bank=selected;data=word_value;
      @(posedge clk);#1;
      @(negedge clk);enable=0;
    end
  endtask
  reg [7:0] expected;
  integer i,j;
  initial begin
    write_word(1,0,0);
    write_word(0,0,8'h03);
    write_word(0,1,8'h0c); // Payload deliberately has stale zeros in bank0.
    if(value!==8'h0f) $fatal(1,"Unselected counter overwritten: got %02x expected 0f",value);
    for(i=0;i<128;i=i+1) begin
      address=i;expected=(i*19)&255;write_word(1,0,expected);
      for(j=0;j<32;j=j+1) begin
        bank=j&3;data=$random;
        expected[bank*2+:2]=data[bank*2+:2];
        write_word(0,bank,data);
        if(value!==expected) $fatal(1,"Counter bank mismatch addr=%03x",address);
      end
    end
    $display("TEST_PASS counter_bank_write 4096 updates");$finish;
  end
endmodule
