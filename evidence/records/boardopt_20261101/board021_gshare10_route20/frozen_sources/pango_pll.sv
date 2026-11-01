// 27 MHz * 58 / 13 = 120.461538 MHz, VCO = 1566 MHz.
// GTP_PPLL's feedback multiplier is STATIC_RATIOM * STATIC_RATIOF.
module pango_pll(input wire clk, input wire rst_n, output wire core_clk, output wire locked);
  GTP_PPLL #(
    .CLKIN_FREQ(27.0), .STATIC_RATIOI(1), .STATIC_RATIOM(1),
    .STATIC_RATIOF(58), .STATIC_DUTYF(58),
    .STATIC_RATIO0(13), .STATIC_DUTY0(13),
    .INTERNAL_FB("CLKOUTF"), .EXTERNAL_FB("DISABLE"),
    .BANDWIDTH("OPTIMIZED")
  ) u_ppll (
    .CLKIN1(clk), .CLKIN2(1'b0), .CLKIN_SEL(1'b0), .CLKFB(1'b0),
    .CLKOUT0(core_clk), .LOCK(locked), .RST(!rst_n), .PLL_PWD(1'b0),
    .CLKOUT0_SYN(1'b0), .CLKOUT1_SYN(1'b0), .CLKOUT2_SYN(1'b0),
    .CLKOUT3_SYN(1'b0), .CLKOUT4_SYN(1'b0), .CLKOUTF_SYN(1'b0), .CLKOUTPHY_SYN(1'b0),
    .APB_CLK(1'b0), .APB_RST_N(1'b0), .APB_ADDR(5'b0), .APB_SEL(1'b0),
    .APB_EN(1'b0), .APB_WRITE(1'b0), .APB_WDATA(16'b0)
  );
endmodule
