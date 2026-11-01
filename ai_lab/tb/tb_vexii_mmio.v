`timescale 1ns/1ps
module tb_vexii_mmio;
  reg clk=0,reset=1;always #5 clk=~clk;
  wire [31:0] awaddr,wdata,araddr;
  wire [3:0] wstrb;
  wire awvalid,wvalid,arvalid,bready,rready;
  reg bvalid=0,rvalid=0;
  integer reads=0,writes=0;
  reg av=0,dr=0;
  reg [2:0] op=4;
  reg [28:0] addr=29'h1000310c;
  vexii_ai_soc dut(
    .socCtrl_systemClk(clk),.socCtrl_asyncReset(reset),
    .system_peripheral_uart_logic_uart_rxd(1'b1),
    .system_peripheral_demo_logic_buttons(1'b0),
    .ai_awaddr(awaddr),.ai_wdata(wdata),.ai_araddr(araddr),
    .ai_wstrb(wstrb),.ai_awvalid(awvalid),.ai_wvalid(wvalid),
    .ai_arvalid(arvalid),.ai_bready(bready),.ai_rready(rready),
    .ai_awready(1'b1),.ai_wready(1'b1),.ai_arready(1'b1),
    .ai_bvalid(bvalid),.ai_rvalid(rvalid),.ai_bresp(2'b0),
    .ai_rresp(2'b0),.ai_rdata(32'h00010000));
  always @(posedge clk) begin
    if(arvalid) begin reads<=reads+1;rvalid<=1;end
    if(rvalid&&rready) rvalid<=0;
    if(awvalid&&wvalid) begin
      if(awaddr!=32'h10003110||wdata!=32'h28) $fatal(1,"MMIO write routing");
      writes<=writes+1;bvalid<=1;
    end
    if(bvalid&&bready) bvalid<=0;
  end
  task transact(input [2:0] operation,input [28:0] address);
    begin
      @(negedge clk);op=operation;addr=address;av=1;
      @(posedge clk);while(!dut.system_peripheral_bus32_bus_a_ready) @(posedge clk);
      @(negedge clk);av=0;
      wait(dut.system_peripheral_bus32_bus_d_valid);
      if(dut.system_peripheral_bus32_bus_d_payload_denied) $fatal(1,"Unexpected denial");
      if(dut.system_peripheral_bus32_bus_d_payload_source!==6'd19) $fatal(1,"Source lost");
      if(operation==4 && address==29'h1000310c &&
         dut.system_peripheral_bus32_bus_d_payload_data!==32'h00010000)
        $fatal(1,"Accelerator read failed");
      repeat(3) @(negedge clk);
      dr=1;@(negedge clk);dr=0;
    end
  endtask
  initial begin
    force dut.system_peripheral_bus32_bus_a_valid=av;
    force dut.system_peripheral_bus32_bus_a_payload_opcode=op;
    force dut.system_peripheral_bus32_bus_a_payload_param=0;
    force dut.system_peripheral_bus32_bus_a_payload_address=addr;
    force dut.system_peripheral_bus32_bus_a_payload_source=19;
    force dut.system_peripheral_bus32_bus_a_payload_size=2;
    force dut.system_peripheral_bus32_bus_a_payload_mask=15;
    force dut.system_peripheral_bus32_bus_a_payload_data=32'h28;
    force dut.system_peripheral_bus32_bus_a_payload_corrupt=0;
    force dut.system_peripheral_bus32_bus_d_ready=dr;
    repeat(5) @(negedge clk);reset=0;
    repeat(10) @(negedge clk);
    transact(4,29'h1000310c);
    transact(0,29'h10003110);
    transact(4,29'h10001004);
    transact(4,29'h1000310c);
    if(reads!=2||writes!=1) $fatal(1,"Peripheral/accelerator dispatch failed");
    $display("VEXII_MMIO_PASS injected peripheral requests; not CPU execution");
    $finish;
  end
  initial begin #100000;$fatal(1,"Timeout");end
endmodule
