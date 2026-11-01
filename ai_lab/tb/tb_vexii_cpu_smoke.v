`timescale 1ns/1ps
module tb_vexii_cpu_smoke;
  reg clk=0,reset=1;always #5 clk=~clk;
  wire [31:0] awaddr,wdata,araddr;
  wire [3:0] wstrb;
  wire awvalid,wvalid,arvalid,bready,rready;
  reg bvalid=0,rvalid=0,got_a=0,got_w=0;
  reg [31:0] saved_addr,saved_data;
  integer reads=0,writes=0;
  vexii_ai_soc dut(
    .socCtrl_systemClk(clk),.socCtrl_asyncReset(reset),
    .system_peripheral_uart_logic_uart_rxd(1'b1),
    .system_peripheral_uart_logic_uart_txd(),
    .system_peripheral_demo_logic_leds(),
    .system_peripheral_demo_logic_buttons(1'b0),
    .ai_awaddr(awaddr),.ai_wdata(wdata),.ai_araddr(araddr),
    .ai_wstrb(wstrb),.ai_awvalid(awvalid),.ai_wvalid(wvalid),
    .ai_arvalid(arvalid),.ai_bready(bready),.ai_rready(rready),
    .ai_awready(!got_a),.ai_wready(!got_w),.ai_arready(!rvalid),
    .ai_bvalid(bvalid),.ai_rvalid(rvalid),.ai_bresp(2'b0),
    .ai_rresp(2'b0),.ai_rdata(32'h00010000));
  always @(posedge clk) begin
    if(arvalid&&!rvalid) begin
      if(araddr!=32'h1000310c) $fatal(1,"CPU read address %h",araddr);
      reads<=reads+1;rvalid<=1;
    end
    if(rvalid&&rready) rvalid<=0;
    if(awvalid&&!got_a) begin saved_addr<=awaddr;got_a<=1;end
    if(wvalid&&!got_w) begin saved_data<=wdata;got_w<=1;end
    if(got_a&&got_w&&!bvalid) begin
      writes<=writes+1;bvalid<=1;
      if(saved_addr==32'h10003110 && saved_data!=40) $fatal(1,"CPU write value");
      if(saved_addr==32'h10003114) begin
        if(saved_data!=32'h600d||reads!=2||writes!=1)
          $fatal(1,"CPU smoke failed value=%h reads=%d writes=%d",saved_data,reads,writes);
        $display("VEXII_CPU_MMIO_PASS real CPU loads stores fence and UART access");
        $finish;
      end
    end
    if(bvalid&&bready) begin bvalid<=0;got_a<=0;got_w<=0;end
  end
  initial begin repeat(5) @(negedge clk);reset=0;end
  integer trace_count=0;
  always @(posedge clk) if(dut.system_peripheral_bus32_bus_a_valid && trace_count<12) begin
    $display("CPU_PERIPH addr=%h op=%d ready=%b",dut.system_peripheral_bus32_bus_a_payload_address,
      dut.system_peripheral_bus32_bus_a_payload_opcode,dut.system_peripheral_bus32_bus_a_ready);
    trace_count=trace_count+1;
  end
  initial begin #2000000;
    $display("RESET=%b pending=%b reads=%d writes=%d",dut.socCtrl_system_reset,
      dut.peripheral_pending,reads,writes);
    $fatal(1,"CPU smoke timeout");end
endmodule
