`timescale 1ns/1ps
module tb_tlul_axil;
  reg clk=0; always #5 clk=~clk;
  reg rstn=0, a_valid=0, d_ready=0;
  reg [2:0] a_opcode=4;
  reg [5:0] a_source=0;
  reg [31:0] a_address=0,a_data=0;
  reg [1:0] a_size=2;
  reg [3:0] a_mask=15;
  reg a_corrupt=0;
  wire a_ready,d_valid,d_denied,d_corrupt;
  wire [2:0] d_opcode;
  wire [5:0] d_source;
  wire [1:0] d_size;
  wire [31:0] d_data,awaddr,wdata,araddr;
  wire awvalid,wvalid,bready,arvalid,rready;
  wire [3:0] wstrb;
  reg awready=0,wready=0,bvalid=0,arready=0,rvalid=0;
  reg [1:0] bresp=0,rresp=0;
  reg [31:0] rdata=0;
  integer aws=0,ws=0,ars=0,checks=0;
  tlul_to_axil dut(.*);
  always @(posedge clk) begin
    if(awvalid&&awready) aws=aws+1;
    if(wvalid&&wready) ws=ws+1;
    if(arvalid&&arready) ars=ars+1;
  end
  task request(input [2:0] op,input [31:0] addr,input [5:0] source);
    begin
      @(negedge clk); a_opcode=op;a_address=addr;a_source=source;
      a_data=32'h12345678;a_valid=1;
      @(posedge clk); while(!a_ready) @(posedge clk);
      @(negedge clk);a_valid=0;
    end
  endtask
  task response(input integer denied,input [2:0] opcode,input [5:0] source);
    reg [31:0] saved;
    begin
      wait(d_valid); #1;
      if(d_denied!==denied[0]||d_opcode!==opcode||d_source!==source||d_size!==a_size)
        $fatal(1,"Bad TL response");
      if(d_corrupt!==(denied[0] && opcode==1)) $fatal(1,"Bad corrupt flag");
      saved=d_data;
      repeat(4) begin @(posedge clk);#1;
        if(!d_valid||a_ready||d_data!==saved) $fatal(1,"Response lost under backpressure");
      end
      @(negedge clk);d_ready=1;
      @(negedge clk);d_ready=0;
      checks=checks+1;
    end
  endtask
  initial begin
    repeat(4) @(negedge clk);rstn=1;
    request(0,32'h10040040,17);
    wait(awvalid&&wvalid);
    if(awaddr!==32'h10040040||wdata!==32'h12345678||wstrb!==15) $fatal(1,"Bad AXI payload");
    @(negedge clk);wready=1;
    @(negedge clk);wready=0;
    repeat(3) @(negedge clk);
    if(wvalid||!awvalid||d_valid) $fatal(1,"Independent AW/W failure");
    awready=1;@(negedge clk);awready=0;
    repeat(3) @(negedge clk);
    if(d_valid) $fatal(1,"Write completed before B");
    bvalid=1;wait(bready);@(negedge clk);bvalid=0;
    response(0,0,17);
    request(4,32'h1004000c,31);
    wait(arvalid); if(araddr!==32'h1004000c) $fatal(1,"Bad read address");
    @(negedge clk);arready=1;@(negedge clk);arready=0;
    repeat(3) @(negedge clk);
    rdata=32'h00010000;rvalid=1;wait(rready);@(negedge clk);rvalid=0;
    wait(d_valid);if(d_data!==32'h00010000) $fatal(1,"Read data lost");
    response(0,1,31);
    request(0,32'h10040010,6);
    @(negedge clk);awready=1;
    @(negedge clk);awready=0;
    repeat(3) @(negedge clk);
    if(!wvalid||awvalid) $fatal(1,"AW-before-W failure");
    wready=1;@(negedge clk);wready=0;
    bresp=2;bvalid=1;wait(bready);@(negedge clk);bvalid=0;
    response(1,0,6);bresp=0;
    request(4,32'h10040004,45);
    @(negedge clk);arready=1;@(negedge clk);arready=0;
    rresp=2;rvalid=1;wait(rready);@(negedge clk);rvalid=0;
    response(1,1,45);rresp=0;
    request(2,32'h10040004,2);response(1,1,2);
    a_mask=3;request(1,32'h10040004,3);response(1,0,3);a_mask=15;
    a_size=1;request(4,32'h10040004,4);response(1,1,4);a_size=2;
    request(4,32'h10040003,5);response(1,1,5);
    a_corrupt=1;request(0,32'h10040004,7);response(1,0,7);a_corrupt=0;
    if(aws!=2||ws!=2||ars!=2) $fatal(1,"Rejected request issued AXI");
    request(4,32'h10040004,8);
    wait(arvalid);@(negedge clk);rstn=0;
    @(negedge clk);
    if(arvalid||awvalid||wvalid||d_valid) $fatal(1,"Reset did not clear transaction");
    rstn=1;
    $display("TLUL_AXIL_PASS checks=%0d reset=1",checks);$finish;
  end
  initial begin #100000; $fatal(1,"Timeout");end
endmodule
