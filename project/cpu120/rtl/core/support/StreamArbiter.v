// Source-extraction compilation-unit preamble (not reference payload).
`timescale 1ns/1ps

module StreamArbiter (
  input  wire          io_inputs_0_valid,
  output wire          io_inputs_0_ready,
  input  wire [31:0]   io_inputs_0_payload_pcOnLastSlice,
  input  wire [31:0]   io_inputs_0_payload_pcTarget,
  input  wire          io_inputs_0_payload_taken,
  input  wire          io_inputs_0_payload_isBranch,
  input  wire          io_inputs_0_payload_isPush,
  input  wire          io_inputs_0_payload_isPop,
  input  wire          io_inputs_0_payload_wasWrong,
  input  wire          io_inputs_0_payload_badPredictedTarget,
  input  wire [11:0]   io_inputs_0_payload_history,
  input  wire [15:0]   io_inputs_0_payload_uopId,
  input  wire [1:0]    io_inputs_0_payload_ctx_GSharePlugin_GSHARE_COUNTER_0,
  input  wire [1:0]    io_inputs_0_payload_ctx_GSharePlugin_GSHARE_COUNTER_1,
  input  wire [1:0]    io_inputs_0_payload_ctx_GSharePlugin_GSHARE_COUNTER_2,
  input  wire [1:0]    io_inputs_0_payload_ctx_GSharePlugin_GSHARE_COUNTER_3,
  input  wire          io_inputs_1_valid,
  output wire          io_inputs_1_ready,
  input  wire [31:0]   io_inputs_1_payload_pcOnLastSlice,
  input  wire [31:0]   io_inputs_1_payload_pcTarget,
  input  wire          io_inputs_1_payload_taken,
  input  wire          io_inputs_1_payload_isBranch,
  input  wire          io_inputs_1_payload_isPush,
  input  wire          io_inputs_1_payload_isPop,
  input  wire          io_inputs_1_payload_wasWrong,
  input  wire          io_inputs_1_payload_badPredictedTarget,
  input  wire [11:0]   io_inputs_1_payload_history,
  input  wire [15:0]   io_inputs_1_payload_uopId,
  input  wire [1:0]    io_inputs_1_payload_ctx_GSharePlugin_GSHARE_COUNTER_0,
  input  wire [1:0]    io_inputs_1_payload_ctx_GSharePlugin_GSHARE_COUNTER_1,
  input  wire [1:0]    io_inputs_1_payload_ctx_GSharePlugin_GSHARE_COUNTER_2,
  input  wire [1:0]    io_inputs_1_payload_ctx_GSharePlugin_GSHARE_COUNTER_3,
  output wire          io_output_valid,
  input  wire          io_output_ready,
  output wire [31:0]   io_output_payload_pcOnLastSlice,
  output wire [31:0]   io_output_payload_pcTarget,
  output wire          io_output_payload_taken,
  output wire          io_output_payload_isBranch,
  output wire          io_output_payload_isPush,
  output wire          io_output_payload_isPop,
  output wire          io_output_payload_wasWrong,
  output wire          io_output_payload_badPredictedTarget,
  output wire [11:0]   io_output_payload_history,
  output wire [15:0]   io_output_payload_uopId,
  output wire [1:0]    io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_0,
  output wire [1:0]    io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_1,
  output wire [1:0]    io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_2,
  output wire [1:0]    io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_3,
  output wire [0:0]    io_chosen,
  output wire [1:0]    io_chosenOH,
  input  wire          socCtrl_systemClk,
  input  wire          socCtrl_system_reset
);

  wire       [3:0]    _zz__zz_maskProposal_0_2;
  wire       [3:0]    _zz__zz_maskProposal_0_2_1;
  wire       [1:0]    _zz__zz_maskProposal_0_2_2;
  wire                maskProposal_0;
  wire                maskProposal_1;
  reg                 maskLocked_0;
  reg                 maskLocked_1;
  wire       [1:0]    _zz_maskProposal_0;
  wire       [3:0]    _zz_maskProposal_0_1;
  wire       [3:0]    _zz_maskProposal_0_2;
  wire       [1:0]    _zz_maskProposal_0_3;
  wire                _zz_io_chosen;

  assign _zz__zz_maskProposal_0_2 = (_zz_maskProposal_0_1 - _zz__zz_maskProposal_0_2_1);
  assign _zz__zz_maskProposal_0_2_2 = {maskLocked_0,maskLocked_1};
  assign _zz__zz_maskProposal_0_2_1 = {2'd0, _zz__zz_maskProposal_0_2_2};
  assign _zz_maskProposal_0 = {io_inputs_1_valid,io_inputs_0_valid};
  assign _zz_maskProposal_0_1 = {_zz_maskProposal_0,_zz_maskProposal_0};
  assign _zz_maskProposal_0_2 = (_zz_maskProposal_0_1 & (~ _zz__zz_maskProposal_0_2));
  assign _zz_maskProposal_0_3 = (_zz_maskProposal_0_2[3 : 2] | _zz_maskProposal_0_2[1 : 0]);
  assign maskProposal_0 = _zz_maskProposal_0_3[0];
  assign maskProposal_1 = _zz_maskProposal_0_3[1];
  assign io_output_valid = ((io_inputs_0_valid && maskProposal_0) || (io_inputs_1_valid && maskProposal_1));
  assign io_output_payload_pcOnLastSlice = (maskProposal_0 ? io_inputs_0_payload_pcOnLastSlice : io_inputs_1_payload_pcOnLastSlice);
  assign io_output_payload_pcTarget = (maskProposal_0 ? io_inputs_0_payload_pcTarget : io_inputs_1_payload_pcTarget);
  assign io_output_payload_taken = (maskProposal_0 ? io_inputs_0_payload_taken : io_inputs_1_payload_taken);
  assign io_output_payload_isBranch = (maskProposal_0 ? io_inputs_0_payload_isBranch : io_inputs_1_payload_isBranch);
  assign io_output_payload_isPush = (maskProposal_0 ? io_inputs_0_payload_isPush : io_inputs_1_payload_isPush);
  assign io_output_payload_isPop = (maskProposal_0 ? io_inputs_0_payload_isPop : io_inputs_1_payload_isPop);
  assign io_output_payload_wasWrong = (maskProposal_0 ? io_inputs_0_payload_wasWrong : io_inputs_1_payload_wasWrong);
  assign io_output_payload_badPredictedTarget = (maskProposal_0 ? io_inputs_0_payload_badPredictedTarget : io_inputs_1_payload_badPredictedTarget);
  assign io_output_payload_history = (maskProposal_0 ? io_inputs_0_payload_history : io_inputs_1_payload_history);
  assign io_output_payload_uopId = (maskProposal_0 ? io_inputs_0_payload_uopId : io_inputs_1_payload_uopId);
  assign io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_0 = (maskProposal_0 ? io_inputs_0_payload_ctx_GSharePlugin_GSHARE_COUNTER_0 : io_inputs_1_payload_ctx_GSharePlugin_GSHARE_COUNTER_0);
  assign io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_1 = (maskProposal_0 ? io_inputs_0_payload_ctx_GSharePlugin_GSHARE_COUNTER_1 : io_inputs_1_payload_ctx_GSharePlugin_GSHARE_COUNTER_1);
  assign io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_2 = (maskProposal_0 ? io_inputs_0_payload_ctx_GSharePlugin_GSHARE_COUNTER_2 : io_inputs_1_payload_ctx_GSharePlugin_GSHARE_COUNTER_2);
  assign io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_3 = (maskProposal_0 ? io_inputs_0_payload_ctx_GSharePlugin_GSHARE_COUNTER_3 : io_inputs_1_payload_ctx_GSharePlugin_GSHARE_COUNTER_3);
  assign io_inputs_0_ready = (maskProposal_0 && io_output_ready);
  assign io_inputs_1_ready = (maskProposal_1 && io_output_ready);
  assign io_chosenOH = {maskProposal_1,maskProposal_0};
  assign _zz_io_chosen = io_chosenOH[1];
  assign io_chosen = _zz_io_chosen;
  always @(posedge socCtrl_systemClk or posedge socCtrl_system_reset) begin
    if(socCtrl_system_reset) begin
      maskLocked_0 <= 1'b0;
      maskLocked_1 <= 1'b1;
    end else begin
      if(io_output_valid) begin
        maskLocked_0 <= maskProposal_0;
        maskLocked_1 <= maskProposal_1;
      end
    end
  end


endmodule
