`timescale 1ns/1ps
// Black-box UART acceptance: actual exception causes, PC recovery and MRET.
module tb_traps;
  reg clk=0, reset=1;
  always #4.1507024265 clk=~clk;
  wire tx; wire [7:0] leds;
  MicroSoc dut(.socCtrl_systemClk(clk),.socCtrl_asyncReset(reset),
    .system_peripheral_uart_logic_uart_txd(tx),.system_peripheral_uart_logic_uart_rxd(1'b1),
    .system_peripheral_demo_logic_leds(leds),.system_peripheral_demo_logic_buttons(1'b0));
  initial begin repeat(20) @(negedge clk); reset=0; end
  integer i, seen=0, bit_cycles=1040;
  reg [7:0] ch;
  string line="";
  initial forever begin
    @(negedge tx);
    repeat(bit_cycles/2) @(posedge clk);
    if(tx!==0) $fatal(1,"UART false start");
    for(i=0;i<8;i=i+1) begin repeat(bit_cycles) @(posedge clk); ch[i]=tx; end
    repeat(bit_cycles) @(posedge clk);
    if(tx!==1) $fatal(1,"UART bad stop");
    if(ch==10) begin
      $display("UART: %s",line);
      if(line=="ILLEGAL_PASS") seen=seen|1;
      if(line=="ECALL_PASS") seen=seen|2;
      if(line=="TIMER_PASS") seen=seen|4;
      if(line=="DIAG_FAIL") $fatal(1,"exception firmware failed");
      if(line=="DIAG_DONE") begin
        if(seen!=7) $fatal(1,"Missing exception case");
        $display("TEST_PASS trap_return_and_timer"); $finish;
      end
      line="";
    end else if(ch!=13) line={line,ch};
  end
  initial begin
    longint max_cycles;
    max_cycles=5000000;
    if($value$plusargs("MAX_CYCLES=%d",max_cycles)) begin end
    repeat(max_cycles) @(posedge clk);
    $fatal(1,"TIMEOUT trap diagnosis");
  end
endmodule
