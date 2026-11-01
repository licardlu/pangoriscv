`timescale 1ns/1ps
module tb_soc;
  reg clk=0, reset=1;
  always #4.1507024265 clk=~clk;
  wire tx; wire [7:0] leds;
  MicroSoc dut(.socCtrl_systemClk(clk),.socCtrl_asyncReset(reset),
    .system_peripheral_uart_logic_uart_txd(tx),.system_peripheral_uart_logic_uart_rxd(1'b1),
    .system_peripheral_demo_logic_leds(leds),.system_peripheral_demo_logic_buttons(1'b0));
  initial begin repeat(20) @(posedge clk); reset<=0; end
  integer bits_seen=0, chars_seen=0, i;
  reg [7:0] ch;
  string line="";
  bit boot_seen=0, crc_seen=0, matrix_seen=0, state_seen=0, core_run_seen=0;
  // The firmware divider is 130: 131*8=1048 CPU cycles per UART bit.
  initial forever begin
    @(negedge tx);
    repeat(524) @(posedge clk);
    if(tx!==0) $fatal(1,"UART false start");
    for(i=0;i<8;i=i+1) begin repeat(1048) @(posedge clk); ch[i]=tx; end
    repeat(1048) @(posedge clk);
    if(tx!==1) $fatal(1,"UART bad stop");
    chars_seen++;
    if(ch==10) begin
      $display("UART: %s",line);
      if(line=="VEXII_PANGO_BOOT") boot_seen=1;
      if(line=="[0]crclist       : 0xe714") crc_seen=1;
      if(line=="[0]crcmatrix     : 0x1fd7") matrix_seen=1;
      if(line=="[0]crcstate      : 0x8e3a") state_seen=1;
      if(line=="2K performance run parameters for coremark.") core_run_seen=1;
      if(line=="BENCH_DONE") begin
        if(!boot_seen || !core_run_seen || !crc_seen || !matrix_seen || !state_seen) $fatal(1,"Missing boot/run/known CRC");
        $display("TEST_PASS soc_coremark"); $finish;
      end
      line="";
    end else if(ch!=13) line={line,ch};
  end
  initial begin
    longint max_cycles;
    max_cycles=40000000;
    if($value$plusargs("MAX_CYCLES=%d",max_cycles)) begin end
    repeat(max_cycles) @(posedge clk);
    $fatal(1,"No completed benchmark, chars=%0d leds=%h",chars_seen,leds);
  end
endmodule

