  assign LearnPlugin_logic_arbitrated_toFlow_payload_ctx_GSharePlugin_GSHARE_COUNTER_1 = LearnPlugin_logic_arbitrated_payload_ctx_GSharePlugin_GSHARE_COUNTER_1;
  assign LearnPlugin_logic_arbitrated_toFlow_payload_ctx_GSharePlugin_GSHARE_COUNTER_2 = LearnPlugin_logic_arbitrated_payload_ctx_GSharePlugin_GSHARE_COUNTER_2;
  assign LearnPlugin_logic_arbitrated_toFlow_payload_ctx_GSharePlugin_GSHARE_COUNTER_3 = LearnPlugin_logic_arbitrated_payload_ctx_GSharePlugin_GSHARE_COUNTER_3;
  assign LearnPlugin_logic_learn_valid = LearnPlugin_logic_arbitrated_toFlow_valid;
  assign LearnPlugin_logic_learn_payload_pcOnLastSlice = LearnPlugin_logic_arbitrated_toFlow_payload_pcOnLastSlice;
  assign LearnPlugin_logic_learn_payload_pcTarget = LearnPlugin_logic_arbitrated_toFlow_payload_pcTarget;
  assign LearnPlugin_logic_learn_payload_taken = LearnPlugin_logic_arbitrated_toFlow_payload_taken;
  assign LearnPlugin_logic_learn_payload_isBranch = LearnPlugin_logic_arbitrated_toFlow_payload_isBranch;
  assign LearnPlugin_logic_learn_payload_isPush = LearnPlugin_logic_arbitrated_toFlow_payload_isPush;
  assign LearnPlugin_logic_learn_payload_isPop = LearnPlugin_logic_arbitrated_toFlow_payload_isPop;
  assign LearnPlugin_logic_learn_payload_wasWrong = LearnPlugin_logic_arbitrated_toFlow_payload_wasWrong;
  assign LearnPlugin_logic_learn_payload_badPredictedTarget = LearnPlugin_logic_arbitrated_toFlow_payload_badPredictedTarget;
  assign LearnPlugin_logic_learn_payload_history = LearnPlugin_logic_arbitrated_toFlow_payload_history;
  assign LearnPlugin_logic_learn_payload_uopId = LearnPlugin_logic_arbitrated_toFlow_payload_uopId;
  assign LearnPlugin_logic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_0 = LearnPlugin_logic_arbitrated_toFlow_payload_ctx_GSharePlugin_GSHARE_COUNTER_0;
  assign LearnPlugin_logic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_1 = LearnPlugin_logic_arbitrated_toFlow_payload_ctx_GSharePlugin_GSHARE_COUNTER_1;
  assign LearnPlugin_logic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_2 = LearnPlugin_logic_arbitrated_toFlow_payload_ctx_GSharePlugin_GSHARE_COUNTER_2;
  assign LearnPlugin_logic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_3 = LearnPlugin_logic_arbitrated_toFlow_payload_ctx_GSharePlugin_GSHARE_COUNTER_3;
  assign lane0_integer_WriteBackPlugin_logic_stages_0_hits = {lane0_IntFormatPlugin_logic_stages_0_wb_valid,early0_BranchPlugin_logic_wb_valid};
  assign lane0_integer_WriteBackPlugin_logic_stages_0_muxed = ((lane0_integer_WriteBackPlugin_logic_stages_0_hits[0] ? early0_BranchPlugin_logic_wb_payload : 32'h0) | (lane0_integer_WriteBackPlugin_logic_stages_0_hits[1] ? lane0_IntFormatPlugin_logic_stages_0_wb_payload : 32'h0));
  assign execute_ctrl2_lane0_integer_WriteBackPlugin_logic_DATA_lane0_bypass = lane0_integer_WriteBackPlugin_logic_stages_0_muxed;
  assign lane0_integer_WriteBackPlugin_logic_stages_0_write_valid = (((((execute_ctrl2_down_LANE_SEL_lane0 && execute_ctrl2_down_isReady) && (! execute_lane0_ctrls_2_downIsCancel)) && (|lane0_integer_WriteBackPlugin_logic_stages_0_hits)) && execute_ctrl2_up_RD_ENABLE_lane0) && execute_ctrl2_down_COMMIT_lane0);
  assign lane0_integer_WriteBackPlugin_logic_stages_0_write_payload_uopId = execute_ctrl2_down_Decode_UOP_ID_lane0;
  assign lane0_integer_WriteBackPlugin_logic_stages_0_write_payload_data = lane0_integer_WriteBackPlugin_logic_stages_0_muxed;
  assign lane0_integer_WriteBackPlugin_logic_stages_1_hits = lane0_IntFormatPlugin_logic_stages_2_wb_valid;
  assign lane0_integer_WriteBackPlugin_logic_stages_1_muxed = (lane0_integer_WriteBackPlugin_logic_stages_1_hits[0] ? lane0_IntFormatPlugin_logic_stages_2_wb_payload : 32'h0);
  assign lane0_integer_WriteBackPlugin_logic_stages_1_merged = (execute_ctrl3_up_lane0_integer_WriteBackPlugin_logic_DATA_lane0 | lane0_integer_WriteBackPlugin_logic_stages_1_muxed);
  assign execute_ctrl3_lane0_integer_WriteBackPlugin_logic_DATA_lane0_bypass = lane0_integer_WriteBackPlugin_logic_stages_1_merged;
  assign lane0_integer_WriteBackPlugin_logic_stages_1_write_valid = (((((execute_ctrl3_down_LANE_SEL_lane0 && execute_ctrl3_down_isReady) && (! execute_lane0_ctrls_3_downIsCancel)) && (|lane0_integer_WriteBackPlugin_logic_stages_1_hits)) && execute_ctrl3_up_RD_ENABLE_lane0) && execute_ctrl3_down_COMMIT_lane0);
  assign lane0_integer_WriteBackPlugin_logic_stages_1_write_payload_uopId = execute_ctrl3_down_Decode_UOP_ID_lane0;
  assign lane0_integer_WriteBackPlugin_logic_stages_1_write_payload_data = lane0_integer_WriteBackPlugin_logic_stages_1_muxed;
  assign lane0_integer_WriteBackPlugin_logic_stages_2_hits = {lane0_IntFormatPlugin_logic_stages_1_wb_valid,late0_BranchPlugin_logic_wb_valid};
  assign lane0_integer_WriteBackPlugin_logic_stages_2_muxed = ((lane0_integer_WriteBackPlugin_logic_stages_2_hits[0] ? late0_BranchPlugin_logic_wb_payload : 32'h0) | (lane0_integer_WriteBackPlugin_logic_stages_2_hits[1] ? lane0_IntFormatPlugin_logic_stages_1_wb_payload : 32'h0));
  assign lane0_integer_WriteBackPlugin_logic_stages_2_merged = (execute_ctrl4_up_lane0_integer_WriteBackPlugin_logic_DATA_lane0 | lane0_integer_WriteBackPlugin_logic_stages_2_muxed);
  assign execute_ctrl4_lane0_integer_WriteBackPlugin_logic_DATA_lane0_bypass = lane0_integer_WriteBackPlugin_logic_stages_2_merged;
  assign lane0_integer_WriteBackPlugin_logic_stages_2_write_valid = (((((execute_ctrl4_down_LANE_SEL_lane0 && execute_ctrl4_down_isReady) && (! execute_lane0_ctrls_4_downIsCancel)) && (|lane0_integer_WriteBackPlugin_logic_stages_2_hits)) && execute_ctrl4_up_RD_ENABLE_lane0) && execute_ctrl4_down_COMMIT_lane0);
  assign lane0_integer_WriteBackPlugin_logic_stages_2_write_payload_uopId = execute_ctrl4_down_Decode_UOP_ID_lane0;
  assign lane0_integer_WriteBackPlugin_logic_stages_2_write_payload_data = lane0_integer_WriteBackPlugin_logic_stages_2_muxed;
  assign lane0_integer_WriteBackPlugin_logic_write_port_valid = (((((execute_ctrl4_up_LANE_SEL_lane0 && execute_ctrl4_down_isReady) && (! execute_lane0_ctrls_4_upIsCancel)) && execute_ctrl4_up_RD_ENABLE_lane0) && execute_ctrl4_down_lane0_integer_WriteBackPlugin_SEL_lane0) && execute_ctrl4_down_COMMIT_lane0);
  assign lane0_integer_WriteBackPlugin_logic_write_port_address = execute_ctrl4_down_RD_PHYS_lane0[4 : 0];
  assign lane0_integer_WriteBackPlugin_logic_write_port_data = execute_ctrl4_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0;
  assign lane0_integer_WriteBackPlugin_logic_write_port_uopId = execute_ctrl4_down_Decode_UOP_ID_lane0;
  assign lane1_integer_WriteBackPlugin_logic_stages_0_hits = {lane1_IntFormatPlugin_logic_stages_0_wb_valid,early1_BranchPlugin_logic_wb_valid};
  assign lane1_integer_WriteBackPlugin_logic_stages_0_muxed = ((lane1_integer_WriteBackPlugin_logic_stages_0_hits[0] ? early1_BranchPlugin_logic_wb_payload : 32'h0) | (lane1_integer_WriteBackPlugin_logic_stages_0_hits[1] ? lane1_IntFormatPlugin_logic_stages_0_wb_payload : 32'h0));
  assign execute_ctrl2_lane1_integer_WriteBackPlugin_logic_DATA_lane1_bypass = lane1_integer_WriteBackPlugin_logic_stages_0_muxed;
  assign lane1_integer_WriteBackPlugin_logic_stages_0_write_valid = (((((execute_ctrl2_down_LANE_SEL_lane1 && execute_ctrl2_down_isReady) && (! execute_lane1_ctrls_2_downIsCancel)) && (|lane1_integer_WriteBackPlugin_logic_stages_0_hits)) && execute_ctrl2_up_RD_ENABLE_lane1) && execute_ctrl2_down_COMMIT_lane1);
  assign lane1_integer_WriteBackPlugin_logic_stages_0_write_payload_uopId = execute_ctrl2_down_Decode_UOP_ID_lane1;
  assign lane1_integer_WriteBackPlugin_logic_stages_0_write_payload_data = lane1_integer_WriteBackPlugin_logic_stages_0_muxed;
  assign lane1_integer_WriteBackPlugin_logic_stages_1_hits = {lane1_IntFormatPlugin_logic_stages_1_wb_valid,late1_BranchPlugin_logic_wb_valid};
  assign lane1_integer_WriteBackPlugin_logic_stages_1_muxed = ((lane1_integer_WriteBackPlugin_logic_stages_1_hits[0] ? late1_BranchPlugin_logic_wb_payload : 32'h0) | (lane1_integer_WriteBackPlugin_logic_stages_1_hits[1] ? lane1_IntFormatPlugin_logic_stages_1_wb_payload : 32'h0));
  assign lane1_integer_WriteBackPlugin_logic_stages_1_merged = (execute_ctrl4_up_lane1_integer_WriteBackPlugin_logic_DATA_lane1 | lane1_integer_WriteBackPlugin_logic_stages_1_muxed);
  assign execute_ctrl4_lane1_integer_WriteBackPlugin_logic_DATA_lane1_bypass = lane1_integer_WriteBackPlugin_logic_stages_1_merged;
  assign lane1_integer_WriteBackPlugin_logic_stages_1_write_valid = (((((execute_ctrl4_down_LANE_SEL_lane1 && execute_ctrl4_down_isReady) && (! execute_lane1_ctrls_4_downIsCancel)) && (|lane1_integer_WriteBackPlugin_logic_stages_1_hits)) && execute_ctrl4_up_RD_ENABLE_lane1) && execute_ctrl4_down_COMMIT_lane1);
  assign lane1_integer_WriteBackPlugin_logic_stages_1_write_payload_uopId = execute_ctrl4_down_Decode_UOP_ID_lane1;
  assign lane1_integer_WriteBackPlugin_logic_stages_1_write_payload_data = lane1_integer_WriteBackPlugin_logic_stages_1_muxed;
  assign lane1_integer_WriteBackPlugin_logic_write_port_valid = (((((execute_ctrl4_up_LANE_SEL_lane1 && execute_ctrl4_down_isReady) && (! execute_lane1_ctrls_4_upIsCancel)) && execute_ctrl4_up_RD_ENABLE_lane1) && execute_ctrl4_down_lane1_integer_WriteBackPlugin_SEL_lane1) && execute_ctrl4_down_COMMIT_lane1);
  assign lane1_integer_WriteBackPlugin_logic_write_port_address = execute_ctrl4_down_RD_PHYS_lane1[4 : 0];
  assign lane1_integer_WriteBackPlugin_logic_write_port_data = execute_ctrl4_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1;
  assign lane1_integer_WriteBackPlugin_logic_write_port_uopId = execute_ctrl4_down_Decode_UOP_ID_lane1;
  assign decode_ctrls_1_down_DecoderPlugin_logic_NEED_FPU_0 = _zz_decode_ctrls_1_down_DecoderPlugin_logic_NEED_FPU_0[0];
  assign decode_ctrls_1_down_DecoderPlugin_logic_NEED_RM_0 = _zz_decode_ctrls_1_down_DecoderPlugin_logic_NEED_RM_0[0];
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_0_1 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h00106020) == 32'h00006000);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_0_2 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h02000070) == 32'h00000030);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_0_3 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h000060a0) == 32'h00006080);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_0_4 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h00006220) == 32'h00006200);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_0_5 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h00006420) == 32'h00006400);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_0_6 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h00006820) == 32'h00006800);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_0_7 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h01006020) == 32'h01006000);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_0_8 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h00806020) == 32'h00806000);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_0_9 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h00406020) == 32'h00406000);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_0_10 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h00006120) == 32'h00006100);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_0_11 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h00002030) == 32'h00000010);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_0_12 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h00004030) == 32'h00000010);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_0_13 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h00003020) == 32'h00003000);
  assign decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_0_0 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_0_0_2[0];
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_3_onRs_1_ENABLES_0_0 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h0) == 32'h0);
  assign decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_1_0 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_1_0[0];
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_0_14 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h00000054) == 32'h00000040);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_0_15 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h0000004c) == 32'h00000004);
  assign decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_2_0 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_2_0[0];
  assign decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_0 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_0_16[0];
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_0_0 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h00000040) == 32'h00000040);
  assign decode_ctrls_1_down_DispatchPlugin_MAY_FLUSH_0 = _zz_decode_ctrls_1_down_DispatchPlugin_MAY_FLUSH_0[0];
  assign _zz_decode_ctrls_1_down_DONT_FLUSH_PRECISE_4_0_1 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h00001050) == 32'h00001050);
  assign decode_ctrls_1_down_DispatchPlugin_DONT_FLUSH_0 = _zz_decode_ctrls_1_down_DispatchPlugin_DONT_FLUSH_0[0];
  assign decode_ctrls_1_down_DispatchPlugin_DONT_FLUSH_FROM_LANES_0 = _zz_decode_ctrls_1_down_DispatchPlugin_DONT_FLUSH_FROM_LANES_0[0];
  assign decode_ctrls_1_down_DispatchPlugin_FENCE_OLDER_0 = _zz_decode_ctrls_1_down_DispatchPlugin_FENCE_OLDER_0[0];
  assign decode_ctrls_1_down_DONT_FLUSH_PRECISE_3_0 = _zz_decode_ctrls_1_down_DONT_FLUSH_PRECISE_3_0[0];
  assign decode_ctrls_1_down_DONT_FLUSH_PRECISE_4_0 = _zz_decode_ctrls_1_down_DONT_FLUSH_PRECISE_4_0_2[0];
  assign decode_ctrls_1_down_DispatchPlugin_logic_hcs_0_onRs_0_ENABLES_0_0 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_0_onRs_0_ENABLES_0_0[0];
  assign decode_ctrls_1_down_DispatchPlugin_logic_hcs_0_onRs_1_ENABLES_0_0 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_0_onRs_1_ENABLES_0_0[0];
  assign decode_ctrls_1_down_DispatchPlugin_logic_hcs_1_onRs_0_ENABLES_0_0 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_1_onRs_0_ENABLES_0_0[0];
  assign decode_ctrls_1_down_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_0_0 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_0_0_1[0];
  assign decode_ctrls_1_down_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_1_0 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_1_0[0];
  assign decode_ctrls_1_down_DispatchPlugin_logic_hcs_2_onRs_0_ENABLES_0_0 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_2_onRs_0_ENABLES_0_0[0];
  assign decode_ctrls_1_down_DispatchPlugin_logic_hcs_2_onRs_1_ENABLES_0_0 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_2_onRs_1_ENABLES_0_0[0];
  assign decode_ctrls_1_down_DispatchPlugin_logic_hcs_3_onRs_0_ENABLES_0_0 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_3_onRs_0_ENABLES_0_0[0];
  assign decode_ctrls_1_down_DispatchPlugin_logic_hcs_3_onRs_1_ENABLES_0_0 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_3_onRs_1_ENABLES_0_0_1[0];
  assign decode_ctrls_1_down_DecoderPlugin_logic_NEED_FPU_1 = _zz_decode_ctrls_1_down_DecoderPlugin_logic_NEED_FPU_1[0];
  assign decode_ctrls_1_down_DecoderPlugin_logic_NEED_RM_1 = _zz_decode_ctrls_1_down_DecoderPlugin_logic_NEED_RM_1[0];
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_1_1 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h00106020) == 32'h00006000);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_1_2 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h02000070) == 32'h00000030);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_1_3 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h000060a0) == 32'h00006080);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_1_4 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h00006220) == 32'h00006200);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_1_5 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h00006420) == 32'h00006400);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_1_6 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h00006820) == 32'h00006800);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_1_7 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h01006020) == 32'h01006000);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_1_8 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h00806020) == 32'h00806000);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_1_9 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h00406020) == 32'h00406000);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_1_10 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h00006120) == 32'h00006100);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_1_11 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h00002030) == 32'h00000010);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_1_12 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h00004030) == 32'h00000010);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_1_13 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h00003020) == 32'h00003000);
  assign decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_0_1 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_0_1_2[0];
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_3_onRs_1_ENABLES_0_1 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h0) == 32'h0);
  assign decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_1_1 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_1_1[0];
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_1_14 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h00000054) == 32'h00000040);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_1_15 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h0000004c) == 32'h00000004);
  assign decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_2_1 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_2_1[0];
  assign decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_1 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_1_16[0];
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_0_1 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h00000040) == 32'h00000040);
  assign decode_ctrls_1_down_DispatchPlugin_MAY_FLUSH_1 = _zz_decode_ctrls_1_down_DispatchPlugin_MAY_FLUSH_1[0];
  assign _zz_decode_ctrls_1_down_DONT_FLUSH_PRECISE_4_1_1 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h00001050) == 32'h00001050);
  assign decode_ctrls_1_down_DispatchPlugin_DONT_FLUSH_1 = _zz_decode_ctrls_1_down_DispatchPlugin_DONT_FLUSH_1[0];
  assign decode_ctrls_1_down_DispatchPlugin_DONT_FLUSH_FROM_LANES_1 = _zz_decode_ctrls_1_down_DispatchPlugin_DONT_FLUSH_FROM_LANES_1[0];
  assign decode_ctrls_1_down_DispatchPlugin_FENCE_OLDER_1 = _zz_decode_ctrls_1_down_DispatchPlugin_FENCE_OLDER_1[0];
  assign decode_ctrls_1_down_DONT_FLUSH_PRECISE_3_1 = _zz_decode_ctrls_1_down_DONT_FLUSH_PRECISE_3_1[0];
  assign decode_ctrls_1_down_DONT_FLUSH_PRECISE_4_1 = _zz_decode_ctrls_1_down_DONT_FLUSH_PRECISE_4_1_2[0];
  assign decode_ctrls_1_down_DispatchPlugin_logic_hcs_0_onRs_0_ENABLES_0_1 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_0_onRs_0_ENABLES_0_1[0];
  assign decode_ctrls_1_down_DispatchPlugin_logic_hcs_0_onRs_1_ENABLES_0_1 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_0_onRs_1_ENABLES_0_1[0];
  assign decode_ctrls_1_down_DispatchPlugin_logic_hcs_1_onRs_0_ENABLES_0_1 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_1_onRs_0_ENABLES_0_1[0];
  assign decode_ctrls_1_down_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_0_1 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_0_1_1[0];
  assign decode_ctrls_1_down_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_1_1 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_1_1[0];
  assign decode_ctrls_1_down_DispatchPlugin_logic_hcs_2_onRs_0_ENABLES_0_1 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_2_onRs_0_ENABLES_0_1[0];
  assign decode_ctrls_1_down_DispatchPlugin_logic_hcs_2_onRs_1_ENABLES_0_1 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_2_onRs_1_ENABLES_0_1[0];
  assign decode_ctrls_1_down_DispatchPlugin_logic_hcs_3_onRs_0_ENABLES_0_1 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_3_onRs_0_ENABLES_0_1[0];
  assign decode_ctrls_1_down_DispatchPlugin_logic_hcs_3_onRs_1_ENABLES_0_1 = _zz_decode_ctrls_1_down_DispatchPlugin_logic_hcs_3_onRs_1_ENABLES_0_1_1[0];
  assign _zz_CsrRamPlugin_csrMapper_ramAddress = CsrAccessPlugin_bus_decode_address;
  assign CsrRamPlugin_csrMapper_ramAddress = {(|((_zz_CsrRamPlugin_csrMapper_ramAddress & 12'h800) == 12'h0)),(|{(_zz_CsrRamPlugin_csrMapper_ramAddress_1 == _zz_CsrRamPlugin_csrMapper_ramAddress_2),(_zz_CsrRamPlugin_csrMapper_ramAddress_3 == _zz_CsrRamPlugin_csrMapper_ramAddress_4)}),(|{(_zz_CsrRamPlugin_csrMapper_ramAddress_5 == _zz_CsrRamPlugin_csrMapper_ramAddress_6),(_zz_CsrRamPlugin_csrMapper_ramAddress_7 == _zz_CsrRamPlugin_csrMapper_ramAddress_8)})};
  always @(*) begin
    CsrRamPlugin_csrMapper_withRead = 1'b0;
    if(when_CsrAccessPlugin_l281) begin
      CsrRamPlugin_csrMapper_withRead = 1'b1;
    end
  end

  assign CsrRamPlugin_csrMapper_read_valid = (CsrRamPlugin_csrMapper_withRead && (! CsrRamPlugin_api_holdRead));
  assign CsrRamPlugin_csrMapper_read_address = CsrRamPlugin_csrMapper_ramAddress;
  assign when_CsrRamPlugin_l85 = (CsrRamPlugin_csrMapper_withRead && (! CsrRamPlugin_csrMapper_read_ready));
  always @(*) begin
    CsrRamPlugin_csrMapper_doWrite = 1'b0;
    if(when_CsrAccessPlugin_l375_2) begin
      CsrRamPlugin_csrMapper_doWrite = 1'b1;
    end
  end

  assign when_CsrRamPlugin_l92 = (CsrRamPlugin_csrMapper_write_valid && CsrRamPlugin_csrMapper_write_ready);
  assign CsrRamPlugin_csrMapper_write_valid = ((CsrRamPlugin_csrMapper_doWrite && (! CsrRamPlugin_csrMapper_fired)) && (! CsrRamPlugin_api_holdWrite));
  assign CsrRamPlugin_csrMapper_write_address = CsrRamPlugin_csrMapper_ramAddress;
  assign CsrRamPlugin_csrMapper_write_data = CsrAccessPlugin_bus_write_bits;
  assign when_CsrRamPlugin_l96 = ((CsrRamPlugin_csrMapper_doWrite && (! CsrRamPlugin_csrMapper_fired)) && (! CsrRamPlugin_csrMapper_write_ready));
  assign _zz_GSharePlugin_logic_onLearn_hash = LearnPlugin_logic_learn_payload_pcOnLastSlice[14 : 3];
  assign GSharePlugin_logic_onLearn_hash = ({_zz_GSharePlugin_logic_onLearn_hash[0],_zz_GSharePlugin_logic_onLearn_hash[1],_zz_GSharePlugin_logic_onLearn_hash[2],_zz_GSharePlugin_logic_onLearn_hash[3],_zz_GSharePlugin_logic_onLearn_hash[4],_zz_GSharePlugin_logic_onLearn_hash[5],_zz_GSharePlugin_logic_onLearn_hash_1,_zz_GSharePlugin_logic_onLearn_hash_2,_zz_GSharePlugin_logic_onLearn_hash[8],_zz_GSharePlugin_logic_onLearn_hash[9],_zz_GSharePlugin_logic_onLearn_hash[10],_zz_GSharePlugin_logic_onLearn_hash[11]} ^ LearnPlugin_logic_learn_payload_history);
  assign GSharePlugin_logic_onLearn_incrValue = (LearnPlugin_logic_learn_payload_taken ? 2'b01 : 2'b11);
  always @(*) begin
    GSharePlugin_logic_onLearn_overflow = 1'b0;
    if(when_GSharePlugin_l119) begin
      GSharePlugin_logic_onLearn_overflow = 1'b1;
    end
    if(when_GSharePlugin_l119_1) begin
      GSharePlugin_logic_onLearn_overflow = 1'b1;
    end
    if(when_GSharePlugin_l119_2) begin
      GSharePlugin_logic_onLearn_overflow = 1'b1;
    end
    if(when_GSharePlugin_l119_3) begin
      GSharePlugin_logic_onLearn_overflow = 1'b1;
    end
  end

  assign GSharePlugin_logic_onLearn_updated_0 = (LearnPlugin_logic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_0 + ((LearnPlugin_logic_learn_payload_pcOnLastSlice[2 : 1] == 2'b00) ? GSharePlugin_logic_onLearn_incrValue : 2'b00));
  assign when_GSharePlugin_l119 = (((LearnPlugin_logic_learn_payload_taken && LearnPlugin_logic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_0[1]) && (! GSharePlugin_logic_onLearn_updated_0[1])) || (((! LearnPlugin_logic_learn_payload_taken) && (! LearnPlugin_logic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_0[1])) && GSharePlugin_logic_onLearn_updated_0[1]));
  assign GSharePlugin_logic_onLearn_updated_1 = (LearnPlugin_logic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_1 + ((LearnPlugin_logic_learn_payload_pcOnLastSlice[2 : 1] == 2'b01) ? GSharePlugin_logic_onLearn_incrValue : 2'b00));
  assign when_GSharePlugin_l119_1 = (((LearnPlugin_logic_learn_payload_taken && LearnPlugin_logic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_1[1]) && (! GSharePlugin_logic_onLearn_updated_1[1])) || (((! LearnPlugin_logic_learn_payload_taken) && (! LearnPlugin_logic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_1[1])) && GSharePlugin_logic_onLearn_updated_1[1]));
  assign GSharePlugin_logic_onLearn_updated_2 = (LearnPlugin_logic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_2 + ((LearnPlugin_logic_learn_payload_pcOnLastSlice[2 : 1] == 2'b10) ? GSharePlugin_logic_onLearn_incrValue : 2'b00));
  assign when_GSharePlugin_l119_2 = (((LearnPlugin_logic_learn_payload_taken && LearnPlugin_logic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_2[1]) && (! GSharePlugin_logic_onLearn_updated_2[1])) || (((! LearnPlugin_logic_learn_payload_taken) && (! LearnPlugin_logic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_2[1])) && GSharePlugin_logic_onLearn_updated_2[1]));
  assign GSharePlugin_logic_onLearn_updated_3 = (LearnPlugin_logic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_3 + ((LearnPlugin_logic_learn_payload_pcOnLastSlice[2 : 1] == 2'b11) ? GSharePlugin_logic_onLearn_incrValue : 2'b00));
  assign when_GSharePlugin_l119_3 = (((LearnPlugin_logic_learn_payload_taken && LearnPlugin_logic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_3[1]) && (! GSharePlugin_logic_onLearn_updated_3[1])) || (((! LearnPlugin_logic_learn_payload_taken) && (! LearnPlugin_logic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_3[1])) && GSharePlugin_logic_onLearn_updated_3[1]));
  always @(*) begin
    GSharePlugin_logic_mem_write_valid = ((LearnPlugin_logic_learn_valid && LearnPlugin_logic_learn_payload_isBranch) && (! GSharePlugin_logic_onLearn_overflow));
    if(GSharePlugin_logic_initializer_busy) begin
      GSharePlugin_logic_mem_write_valid = 1'b1;
    end
  end

  always @(*) begin
    GSharePlugin_logic_mem_write_payload_address = GSharePlugin_logic_onLearn_hash;
    if(GSharePlugin_logic_initializer_busy) begin
      GSharePlugin_logic_mem_write_payload_address = GSharePlugin_logic_initializer_counter[11:0];
    end
  end

  always @(*) begin
    GSharePlugin_logic_mem_write_payload_data_0 = GSharePlugin_logic_onLearn_updated_0;
    if(GSharePlugin_logic_initializer_busy) begin
      GSharePlugin_logic_mem_write_payload_data_0 = _zz_GSharePlugin_logic_mem_write_payload_data_0[1 : 0];
    end
  end

  always @(*) begin
    GSharePlugin_logic_mem_write_payload_data_1 = GSharePlugin_logic_onLearn_updated_1;
    if(GSharePlugin_logic_initializer_busy) begin
      GSharePlugin_logic_mem_write_payload_data_1 = _zz_GSharePlugin_logic_mem_write_payload_data_0[3 : 2];
    end
  end

  always @(*) begin
    GSharePlugin_logic_mem_write_payload_data_2 = GSharePlugin_logic_onLearn_updated_2;
    if(GSharePlugin_logic_initializer_busy) begin
      GSharePlugin_logic_mem_write_payload_data_2 = _zz_GSharePlugin_logic_mem_write_payload_data_0[5 : 4];
    end
  end

  always @(*) begin
    GSharePlugin_logic_mem_write_payload_data_3 = GSharePlugin_logic_onLearn_updated_3;
    if(GSharePlugin_logic_initializer_busy) begin
      GSharePlugin_logic_mem_write_payload_data_3 = _zz_GSharePlugin_logic_mem_write_payload_data_0[7 : 6];
    end
  end

  assign GSharePlugin_logic_initializer_busy = (! GSharePlugin_logic_initializer_counter[12]);
  assign _zz_GSharePlugin_logic_mem_write_payload_data_0 = 8'h0;
  assign BtbPlugin_logic_onLearn_hash = LearnPlugin_logic_learn_payload_pcOnLastSlice[26 : 11];
  always @(*) begin
    BtbPlugin_logic_memWrite_valid = (LearnPlugin_logic_learn_valid && (LearnPlugin_logic_learn_payload_badPredictedTarget && LearnPlugin_logic_learn_payload_taken));
    if(DecoderPlugin_logic_forgetPort_valid) begin
      BtbPlugin_logic_memWrite_valid = DecoderPlugin_logic_forgetPort_valid;
    end
    if(BtbPlugin_logic_initializer_busy) begin
      BtbPlugin_logic_memWrite_valid = 1'b1;
    end
  end

  always @(*) begin
    BtbPlugin_logic_memWrite_payload_address = _zz_BtbPlugin_logic_memWrite_payload_address[7:0];
    if(DecoderPlugin_logic_forgetPort_valid) begin
      BtbPlugin_logic_memWrite_payload_address = _zz_BtbPlugin_logic_memWrite_payload_address_1[7:0];
    end
    if(BtbPlugin_logic_initializer_busy) begin
      BtbPlugin_logic_memWrite_payload_address = BtbPlugin_logic_initializer_counter[7:0];
    end
  end

  always @(*) begin
    BtbPlugin_logic_memWrite_payload_mask = (2'b01 <<< LearnPlugin_logic_learn_payload_pcOnLastSlice[2 : 2]);
    if(DecoderPlugin_logic_forgetPort_valid) begin
      BtbPlugin_logic_memWrite_payload_mask = (2'b01 <<< DecoderPlugin_logic_forgetPort_payload_pcOnLastSlice[2 : 2]);
    end
    if(BtbPlugin_logic_initializer_busy) begin
      BtbPlugin_logic_memWrite_payload_mask = 2'b11;
    end
  end

  always @(*) begin
    BtbPlugin_logic_memWrite_payload_data_0_hash = BtbPlugin_logic_onLearn_hash;
    if(DecoderPlugin_logic_forgetPort_valid) begin
      BtbPlugin_logic_memWrite_payload_data_0_hash = (~ BtbPlugin_logic_onForget_hash);
    end
    if(BtbPlugin_logic_initializer_busy) begin
      BtbPlugin_logic_memWrite_payload_data_0_hash = 16'hffff;
    end
  end

  always @(*) begin
    BtbPlugin_logic_memWrite_payload_data_0_sliceLow = LearnPlugin_logic_learn_payload_pcOnLastSlice[1 : 1];
    if(DecoderPlugin_logic_forgetPort_valid) begin
      BtbPlugin_logic_memWrite_payload_data_0_sliceLow = DecoderPlugin_logic_forgetPort_payload_pcOnLastSlice[1 : 1];
    end
    if(BtbPlugin_logic_initializer_busy) begin
      BtbPlugin_logic_memWrite_payload_data_0_sliceLow = 1'b0;
    end
  end

  assign BtbPlugin_logic_memWrite_payload_data_0_pcTarget = (LearnPlugin_logic_learn_payload_pcTarget >>> 1'd1);
  always @(*) begin
    BtbPlugin_logic_memWrite_payload_data_0_isBranch = LearnPlugin_logic_learn_payload_isBranch;
    if(DecoderPlugin_logic_forgetPort_valid) begin
      BtbPlugin_logic_memWrite_payload_data_0_isBranch = 1'b0;
    end
    if(BtbPlugin_logic_initializer_busy) begin
      BtbPlugin_logic_memWrite_payload_data_0_isBranch = 1'b0;
    end
  end

  always @(*) begin
    BtbPlugin_logic_memWrite_payload_data_0_isPush = LearnPlugin_logic_learn_payload_isPush;
    if(DecoderPlugin_logic_forgetPort_valid) begin
      BtbPlugin_logic_memWrite_payload_data_0_isPush = 1'b0;
    end
    if(BtbPlugin_logic_initializer_busy) begin
      BtbPlugin_logic_memWrite_payload_data_0_isPush = 1'b0;
    end
  end

  always @(*) begin
    BtbPlugin_logic_memWrite_payload_data_0_isPop = LearnPlugin_logic_learn_payload_isPop;
    if(DecoderPlugin_logic_forgetPort_valid) begin
      BtbPlugin_logic_memWrite_payload_data_0_isPop = 1'b0;
    end
    if(BtbPlugin_logic_initializer_busy) begin
      BtbPlugin_logic_memWrite_payload_data_0_isPop = 1'b0;
    end
  end

  always @(*) begin
    BtbPlugin_logic_memWrite_payload_data_1_hash = BtbPlugin_logic_onLearn_hash;
    if(DecoderPlugin_logic_forgetPort_valid) begin
      BtbPlugin_logic_memWrite_payload_data_1_hash = (~ BtbPlugin_logic_onForget_hash);
    end
    if(BtbPlugin_logic_initializer_busy) begin
      BtbPlugin_logic_memWrite_payload_data_1_hash = 16'hffff;
    end
  end

  always @(*) begin
    BtbPlugin_logic_memWrite_payload_data_1_sliceLow = LearnPlugin_logic_learn_payload_pcOnLastSlice[1 : 1];
    if(DecoderPlugin_logic_forgetPort_valid) begin
      BtbPlugin_logic_memWrite_payload_data_1_sliceLow = DecoderPlugin_logic_forgetPort_payload_pcOnLastSlice[1 : 1];
    end
    if(BtbPlugin_logic_initializer_busy) begin
      BtbPlugin_logic_memWrite_payload_data_1_sliceLow = 1'b0;
    end
  end

  assign BtbPlugin_logic_memWrite_payload_data_1_pcTarget = (LearnPlugin_logic_learn_payload_pcTarget >>> 1'd1);
  always @(*) begin
    BtbPlugin_logic_memWrite_payload_data_1_isBranch = LearnPlugin_logic_learn_payload_isBranch;
    if(DecoderPlugin_logic_forgetPort_valid) begin
      BtbPlugin_logic_memWrite_payload_data_1_isBranch = 1'b0;
    end
    if(BtbPlugin_logic_initializer_busy) begin
      BtbPlugin_logic_memWrite_payload_data_1_isBranch = 1'b0;
    end
  end

  always @(*) begin
    BtbPlugin_logic_memWrite_payload_data_1_isPush = LearnPlugin_logic_learn_payload_isPush;
    if(DecoderPlugin_logic_forgetPort_valid) begin
      BtbPlugin_logic_memWrite_payload_data_1_isPush = 1'b0;
    end
    if(BtbPlugin_logic_initializer_busy) begin
      BtbPlugin_logic_memWrite_payload_data_1_isPush = 1'b0;
    end
  end

  always @(*) begin
    BtbPlugin_logic_memWrite_payload_data_1_isPop = LearnPlugin_logic_learn_payload_isPop;
    if(DecoderPlugin_logic_forgetPort_valid) begin
      BtbPlugin_logic_memWrite_payload_data_1_isPop = 1'b0;
    end
    if(BtbPlugin_logic_initializer_busy) begin
      BtbPlugin_logic_memWrite_payload_data_1_isPop = 1'b0;
    end
  end

  assign BtbPlugin_logic_onForget_hash = DecoderPlugin_logic_forgetPort_payload_pcOnLastSlice[26 : 11];
  assign BtbPlugin_logic_memRead_cmd_valid = fetch_logic_ctrls_0_down_isReady;
  assign BtbPlugin_logic_memRead_cmd_payload = _zz_BtbPlugin_logic_memRead_cmd_payload[7:0];
  assign fetch_logic_ctrls_0_down_BtbPlugin_logic_readCmd_HAZARDS = ((BtbPlugin_logic_memWrite_valid && (BtbPlugin_logic_memWrite_payload_address == BtbPlugin_logic_memRead_cmd_payload)) ? BtbPlugin_logic_memWrite_payload_mask : 2'b00);
  assign fetch_logic_ctrls_0_haltRequest_BtbPlugin_l200 = BtbPlugin_logic_memWrite_valid;
  assign BtbPlugin_logic_predictions = {fetch_logic_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_3[1],fetch_logic_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_2[1],fetch_logic_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_1[1],fetch_logic_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_0[1]};
  assign fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_readRsp_ENTRY_hash = BtbPlugin_logic_memRead_rsp_0_hash;
  assign fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_readRsp_ENTRY_sliceLow = BtbPlugin_logic_memRead_rsp_0_sliceLow;
  assign fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_readRsp_ENTRY_pcTarget = BtbPlugin_logic_memRead_rsp_0_pcTarget;
  assign fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_readRsp_ENTRY_isBranch = BtbPlugin_logic_memRead_rsp_0_isBranch;
  assign fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_readRsp_ENTRY_isPush = BtbPlugin_logic_memRead_rsp_0_isPush;
  assign fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_readRsp_ENTRY_isPop = BtbPlugin_logic_memRead_rsp_0_isPop;
  assign fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_hitCalc_HIT = ((fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_readRsp_ENTRY_hash == fetch_logic_ctrls_1_down_Fetch_WORD_PC[26 : 11]) && (fetch_logic_ctrls_1_down_Fetch_WORD_PC[2 : 1] <= {1'b0,fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_readRsp_ENTRY_sliceLow}));
  assign fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_predict_TAKEN = ((! fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_readRsp_ENTRY_isBranch) || BtbPlugin_logic_predictions[{1'b0,fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_readRsp_ENTRY_sliceLow}]);
  assign fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_1_readRsp_ENTRY_hash = BtbPlugin_logic_memRead_rsp_1_hash;
  assign fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_1_readRsp_ENTRY_sliceLow = BtbPlugin_logic_memRead_rsp_1_sliceLow;
  assign fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_1_readRsp_ENTRY_pcTarget = BtbPlugin_logic_memRead_rsp_1_pcTarget;
  assign fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_1_readRsp_ENTRY_isBranch = BtbPlugin_logic_memRead_rsp_1_isBranch;
  assign fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_1_readRsp_ENTRY_isPush = BtbPlugin_logic_memRead_rsp_1_isPush;
  assign fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_1_readRsp_ENTRY_isPop = BtbPlugin_logic_memRead_rsp_1_isPop;
  assign fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_1_hitCalc_HIT = ((fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_1_readRsp_ENTRY_hash == fetch_logic_ctrls_1_down_Fetch_WORD_PC[26 : 11]) && (fetch_logic_ctrls_1_down_Fetch_WORD_PC[2 : 1] <= {1'b1,fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_1_readRsp_ENTRY_sliceLow}));
  assign fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_1_predict_TAKEN = ((! fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_1_readRsp_ENTRY_isBranch) || BtbPlugin_logic_predictions[{1'b1,fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_1_readRsp_ENTRY_sliceLow}]);
  assign BtbPlugin_logic_ras_readIt = fetch_logic_ctrls_0_down_isReady;
  assign BtbPlugin_logic_applyIt_chunksMask = {(fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_1_hitCalc_HIT && ((fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_hitCalc_HIT && fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_predict_TAKEN) == 1'b0)),(fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_hitCalc_HIT && 1'b1)};
  assign BtbPlugin_logic_applyIt_chunksTakenOh = ({fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_1_predict_TAKEN,fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_predict_TAKEN} & BtbPlugin_logic_applyIt_chunksMask);
  assign BtbPlugin_logic_applyIt_needIt = (fetch_logic_ctrls_1_up_isValid && (|BtbPlugin_logic_applyIt_chunksTakenOh));
  assign when_BtbPlugin_l233 = (fetch_logic_ctrls_1_up_isReady || fetch_logic_ctrls_1_up_isCancel);
  assign BtbPlugin_logic_applyIt_doIt = (BtbPlugin_logic_applyIt_needIt && (! BtbPlugin_logic_applyIt_correctionSent));
  assign _zz_BtbPlugin_logic_applyIt_doItSlice = BtbPlugin_logic_applyIt_chunksTakenOh[1];
  assign _zz_BtbPlugin_logic_applyIt_entry_hash = ((BtbPlugin_logic_applyIt_chunksTakenOh[0] ? {fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_readRsp_ENTRY_isPop,fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_readRsp_ENTRY_isPush,fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_readRsp_ENTRY_isBranch,_zz__zz_BtbPlugin_logic_applyIt_entry_hash,fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_readRsp_ENTRY_sliceLow,fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_0_readRsp_ENTRY_hash} : 51'h0) | (_zz_BtbPlugin_logic_applyIt_doItSlice ? {fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_1_readRsp_ENTRY_isPop,fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_1_readRsp_ENTRY_isPush,fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_1_readRsp_ENTRY_isBranch,_zz__zz_BtbPlugin_logic_applyIt_entry_hash_2,fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_1_readRsp_ENTRY_sliceLow,fetch_logic_ctrls_1_down_BtbPlugin_logic_chunksLogic_1_readRsp_ENTRY_hash} : 51'h0));
  assign BtbPlugin_logic_applyIt_entry_hash = _zz_BtbPlugin_logic_applyIt_entry_hash[15 : 0];
  assign BtbPlugin_logic_applyIt_entry_sliceLow = _zz_BtbPlugin_logic_applyIt_entry_hash[16 : 16];
  assign BtbPlugin_logic_applyIt_entry_pcTarget = _zz_BtbPlugin_logic_applyIt_entry_hash[47 : 17];
  assign BtbPlugin_logic_applyIt_entry_isBranch = _zz_BtbPlugin_logic_applyIt_entry_hash[48];
  assign BtbPlugin_logic_applyIt_entry_isPush = _zz_BtbPlugin_logic_applyIt_entry_hash[49];
  assign BtbPlugin_logic_applyIt_entry_isPop = _zz_BtbPlugin_logic_applyIt_entry_hash[50];
  always @(*) begin
    BtbPlugin_logic_applyIt_pcTarget = BtbPlugin_logic_applyIt_entry_pcTarget;
    if(BtbPlugin_logic_applyIt_entry_isPop) begin
      BtbPlugin_logic_applyIt_pcTarget = BtbPlugin_logic_ras_read;
    end
  end

  assign BtbPlugin_logic_applyIt_doItSlice = {_zz_BtbPlugin_logic_applyIt_doItSlice,BtbPlugin_logic_applyIt_entry_sliceLow};
  assign BtbPlugin_logic_applyIt_rasLogic_pushValid = (BtbPlugin_logic_applyIt_doIt && BtbPlugin_logic_applyIt_entry_isPush);
  always @(*) begin
    BtbPlugin_logic_applyIt_rasLogic_pushPc = fetch_logic_ctrls_1_down_Fetch_WORD_PC;
    BtbPlugin_logic_applyIt_rasLogic_pushPc[2 : 1] = BtbPlugin_logic_applyIt_doItSlice;
  end

  assign when_BtbPlugin_l246 = (BtbPlugin_logic_applyIt_doIt && BtbPlugin_logic_applyIt_entry_isPop);
  assign BtbPlugin_logic_flushPort_valid = BtbPlugin_logic_applyIt_doIt;
  assign BtbPlugin_logic_flushPort_payload_self = 1'b0;
  assign BtbPlugin_logic_pcPort_valid = BtbPlugin_logic_applyIt_doIt;
  assign BtbPlugin_logic_pcPort_payload_fault = 1'b0;
