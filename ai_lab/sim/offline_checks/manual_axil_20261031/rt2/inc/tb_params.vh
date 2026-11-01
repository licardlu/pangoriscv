localparam integer P_IN_H=40, P_IN_W=40, P_CINPAD=32, P_COUT=32, P_K=3, P_STRIDE=1, P_ACT=2, P_TR=8, P_PAD=1;
localparam integer P_OH=40, P_OW=40, P_MEMW=17160, P_NOUT=6400;
`define DDR_FILE "E:/file/pango/project/ai_lab/gen/ddr_rt2.hex"
`define EXP_FILE "E:/file/pango/project/ai_lab/gen/expected_rt2.hex"
localparam [31:0] P_A_BASE=32'h00000000, P_W_BASE=32'h00010000, P_Q_BASE=32'h00013000, P_Y_BASE=32'h00015000, P_T_BASE=32'h00014000;
