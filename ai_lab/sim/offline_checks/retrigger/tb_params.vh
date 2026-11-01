localparam integer P_IN_H=320, P_IN_W=320, P_CINPAD=8, P_COUT=16, P_K=6, P_STRIDE=2, P_ACT=2, P_TR=4, P_PAD=2;
localparam integer P_OH=160, P_OW=160, P_MEMW=159752, P_NOUT=51200;
`define DDR_FILE "E:/file/pango/project/ai_lab/gen/ddr_rt3.hex"
`define EXP_FILE "E:/file/pango/project/ai_lab/gen/expected_rt3.hex"
localparam [31:0] P_A_BASE=32'h00000000, P_W_BASE=32'h000d0000, P_Q_BASE=32'h000d2000, P_Y_BASE=32'h000d4000, P_T_BASE=32'h000d3000;
