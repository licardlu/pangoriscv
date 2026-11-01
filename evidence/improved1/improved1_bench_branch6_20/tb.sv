`timescale 1ns/1ps
module tb_benchmark;
  reg clk=0, reset=1;
  always #4.1507024265 clk=~clk;
  wire tx; wire [7:0] leds;
  MicroSoc dut(.socCtrl_systemClk(clk),.socCtrl_asyncReset(reset),
    .system_peripheral_uart_logic_uart_txd(tx),.system_peripheral_uart_logic_uart_rxd(1'b1),
    .system_peripheral_demo_logic_leds(leds),.system_peripheral_demo_logic_buttons(1'b0));
  initial begin repeat(20) @(negedge clk); reset=0; end
  integer i, bit_cycles=1040;
  reg [7:0] ch;
  string line="";
  initial begin
    if($value$plusargs("UART_CYCLES=%d",bit_cycles)) begin end
    forever begin
      @(negedge tx);
      repeat(bit_cycles/2) @(posedge clk);
      if(tx!==0) $fatal(1,"UART false start");
      for(i=0;i<8;i=i+1) begin repeat(bit_cycles) @(posedge clk); ch[i]=tx; end
      repeat(bit_cycles) @(posedge clk);
      if(tx!==1) $fatal(1,"UART bad stop");
      if(ch==10) begin
        $display("UART: %s",line);
        if(line=="BENCH_DONE") begin
          $display("TEST_PASS benchmark_completed; CRC/ticks assessed separately"); $finish;
        end
        line="";
      end else if(ch!=13) line={line,ch};
    end
  end
  initial begin
    longint max_cycles;
    max_cycles=40000000;
    if($value$plusargs("MAX_CYCLES=%d",max_cycles)) begin end
    repeat(max_cycles) @(posedge clk);
    $fatal(1,"TIMEOUT benchmark");
  end
endmodule
