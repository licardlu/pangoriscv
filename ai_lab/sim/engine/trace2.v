`timescale 1ns/1ps
module trace2;
  reg [4:0] p = 5'h1f;
  integer n = 0;
  always @(posedge tb_band_rt.clk) begin
    if (tb_band_rt.dbg_st !== p) begin
      p = tb_band_rt.dbg_st;
      if (tb_band_rt.dbg_st >= 5'd4 && n < 24) begin
        n = n + 1;
        $display("st=%0d fr=%0d fx=%0d fcs=%0d band=%0d ti=%0d row=%0d col=%0d wld=%0d/%0d iss=%0d nsl=%0d nt=%0d outw=%0d wtot=%0d",
          tb_band_rt.dbg_st, tb_band_rt.dut.fr, tb_band_rt.dut.fx, tb_band_rt.dut.fcs,
          tb_band_rt.dut.band_i, tb_band_rt.dut.ti, tb_band_rt.dut.row, tb_band_rt.dut.col,
          tb_band_rt.dut.wld_o, tb_band_rt.dut.wld_w, tb_band_rt.dut.issue,
          tb_band_rt.dut.nsl, tb_band_rt.dut.nt, tb_band_rt.dut.r_outw, tb_band_rt.dut.wtot);
      end
    end
  end
endmodule
