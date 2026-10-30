// 27 MHz * 50 / 16 = 84.375 MHz, VCO = 1350 MHz.
// 选这一档的理由: VCO 和已验证过的 50 MHz 方案 (27*50/27) 完全一样, 都是 1350,
// 距下限 1330 只有 1.5% 但那条路已经上过板; 而 85.7 MHz 附近再往上要 VCO > 1600。
// 频率是精确值 (27*50/16), 没有余数。
// GTP_PPLL's feedback multiplier is STATIC_RATIOM * STATIC_RATIOF.
module pango_pll(input wire clk, input wire rst_n, output wire core_clk, output wire locked);
  GTP_PPLL #(
    .CLKIN_FREQ(27.0), .STATIC_RATIOI(1), .STATIC_RATIOM(1),
    .STATIC_RATIOF(50), .STATIC_DUTYF(50),
    .STATIC_RATIO0(16), .STATIC_DUTY0(16),
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
