`timescale 1ns/1ps
module trace;
  reg [4:0] p = 5'h1f;
  integer np = 0, cyc = 0;
  always @(posedge tb_band_engine.clk) begin
    cyc = cyc + 1;
    if (tb_band_engine.dut.st !== p) begin
      p = tb_band_engine.dut.st;
      if (cyc > 300 && np < 20) begin
        np = np + 1;
        $display("cyc=%0d st %b band=%0d ti=%0d row=%0d col=%0d iss=%0d wld=%0d/%0d wack=%b",
          cyc, p, tb_band_engine.dut.band_i, tb_band_engine.dut.ti,
          tb_band_engine.dut.row, tb_band_engine.dut.col, tb_band_engine.dut.issue,
          tb_band_engine.dut.wld_o, tb_band_engine.dut.wld_w, tb_band_engine.wr_ack_w);
      end
    end
  end
endmodule
