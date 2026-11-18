module clock_probe(input cmos1_pclk,cmos2_pclk, input sel,output reg [2:0] q);
wire l,r,lg,rg,m;
GTP_IOCLKDIV_E2 #(.DIV_FACTOR("2")) ld(.CLKIN(cmos1_pclk),.CE(1'b1),.RST_N(1'b1),.CLKDIVOUT(l));
GTP_IOCLKDIV_E2 #(.DIV_FACTOR("2")) rd(.CLKIN(cmos2_pclk),.CE(1'b1),.RST_N(1'b1),.CLKDIVOUT(r));
GTP_CLKBUFG lb(.CLKIN(l),.CLKOUT(lg));
assign rg=r;
GTP_CLKBUFGMUX #(.TRIGGER_MODE("NEGEDGE"),.SIM_DEVICE("LOGOS2")) mb(.CLKIN0(lg),.CLKIN1(rg),.SEL(sel),.CLKOUT(m));
always @(posedge lg) q[0]<=!q[0];
always @(posedge rg) q[1]<=!q[1];
always @(posedge m) q[2]<=!q[2];
endmodule
