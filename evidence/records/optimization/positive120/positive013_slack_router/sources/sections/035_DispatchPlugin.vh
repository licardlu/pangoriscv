  assign DecoderPlugin_logic_laneLogic_0_trapPort_payload_laneAge = 2'b00;
  assign DecoderPlugin_logic_laneLogic_0_trapPort_payload_arg = 3'b000;
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_0_0_1 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h00000050) == 32'h00000040);
  assign DecoderPlugin_logic_laneLogic_0_fixer_isJb = _zz_DecoderPlugin_logic_laneLogic_0_fixer_isJb[0];
  assign DecoderPlugin_logic_laneLogic_0_fixer_doIt = (decode_ctrls_1_up_LANE_SEL_0 && ((decode_ctrls_1_down_Prediction_ALIGNED_JUMPED_0 && (! DecoderPlugin_logic_laneLogic_0_fixer_isJb)) || decode_ctrls_1_down_Prediction_ALIGN_REDO_0));
  assign when_CtrlLaneApi_l50 = (decode_ctrls_1_up_isReady || decode_ctrls_1_lane0_upIsCancel);
  assign DecoderPlugin_logic_laneLogic_0_completionPort_valid = ((decode_ctrls_1_up_LANE_SEL_0 && decode_ctrls_1_down_TRAP_0) && (decode_ctrls_1_up_LANE_SEL_0 && (! decode_ctrls_1_up_LANE_SEL_0_regNext)));
  assign DecoderPlugin_logic_laneLogic_0_completionPort_payload_uopId = decode_ctrls_1_down_Decode_UOP_ID_0;
  assign DecoderPlugin_logic_laneLogic_0_completionPort_payload_trap = 1'b1;
  assign DecoderPlugin_logic_laneLogic_0_completionPort_payload_commit = 1'b0;
  assign when_DecoderPlugin_l245 = (decode_ctrls_1_up_LANE_SEL_0 && (((! decode_ctrls_1_down_Decode_LEGAL_0) || DecoderPlugin_logic_laneLogic_0_interruptPending) || DecoderPlugin_logic_laneLogic_0_fixer_doIt));
  assign DecoderPlugin_logic_laneLogic_0_flushPort_valid = (decode_ctrls_1_up_LANE_SEL_0 && decode_ctrls_1_down_TRAP_0);
  assign DecoderPlugin_logic_laneLogic_0_flushPort_payload_uopId = decode_ctrls_1_down_Decode_UOP_ID_0;
  assign DecoderPlugin_logic_laneLogic_0_flushPort_payload_laneAge = 1'b0;
  assign DecoderPlugin_logic_laneLogic_0_flushPort_payload_self = 1'b0;
  assign when_DecoderPlugin_l263 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0[11 : 7] == 5'h0) && (|1'b1));
  assign decode_ctrls_1_down_Decode_UOP_0 = decode_ctrls_1_down_Decode_INSTRUCTION_0;
  assign DecoderPlugin_logic_laneLogic_0_uopIdBase = DecoderPlugin_logic_harts_0_uopId;
  assign decode_ctrls_1_down_Decode_UOP_ID_0 = (DecoderPlugin_logic_laneLogic_0_uopIdBase + 16'h0);
  assign decode_ctrls_1_down_RS1_ENABLE_1 = _zz_decode_ctrls_1_down_RS1_ENABLE_1[0];
  assign decode_ctrls_1_down_RS1_PHYS_1 = _zz_decode_ctrls_1_down_RS1_PHYS_1[4 : 0];
  assign decode_ctrls_1_down_RS2_ENABLE_1 = _zz_decode_ctrls_1_down_RS2_ENABLE_1[0];
  assign decode_ctrls_1_down_RS2_PHYS_1 = _zz_decode_ctrls_1_down_RS2_PHYS_1[4 : 0];
  assign _zz_decode_ctrls_1_down_DONT_FLUSH_PRECISE_4_1 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h00002050) == 32'h00002050);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_0_1 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h0000000c) == 32'h00000004);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_1 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h00000048) == 32'h00000048);
  always @(*) begin
    decode_ctrls_1_down_RD_ENABLE_1 = _zz_decode_ctrls_1_down_RD_ENABLE_1[0];
    if(when_DecoderPlugin_l263_1) begin
      decode_ctrls_1_down_RD_ENABLE_1 = 1'b0;
    end
  end

  assign decode_ctrls_1_down_RD_PHYS_1 = _zz_decode_ctrls_1_down_RD_PHYS_1[4 : 0];
  assign decode_ctrls_1_down_Decode_LEGAL_1 = ((|{((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h0000005f) == 32'h00000017),((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h0000007f) == 32'h0000006f),((decode_ctrls_1_down_Decode_INSTRUCTION_1 & _zz_decode_ctrls_1_down_Decode_LEGAL_1) == 32'h00001073),(_zz_decode_ctrls_1_down_Decode_LEGAL_1_1 == _zz_decode_ctrls_1_down_Decode_LEGAL_1_2),_zz_decode_ctrls_1_down_Decode_LEGAL_1_3,_zz_decode_ctrls_1_down_Decode_LEGAL_1_4,((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h0000207f) == 32'h00000003),((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h0000506f) == 32'h00000003),((decode_ctrls_1_down_Decode_INSTRUCTION_1 & _zz_decode_ctrls_1_down_Decode_LEGAL_1_6) == 32'h00000003),(_zz_decode_ctrls_1_down_Decode_LEGAL_1_7 == _zz_decode_ctrls_1_down_Decode_LEGAL_1_8),_zz_decode_ctrls_1_down_Decode_LEGAL_1_9,_zz_decode_ctrls_1_down_Decode_LEGAL_1_10,((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h0000607f) == 32'h0000000f),((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h0000717f) == 32'h00006113),((decode_ctrls_1_down_Decode_INSTRUCTION_1 & _zz_decode_ctrls_1_down_Decode_LEGAL_1_12) == 32'h00006813),(_zz_decode_ctrls_1_down_Decode_LEGAL_1_13 == _zz_decode_ctrls_1_down_Decode_LEGAL_1_14),_zz_decode_ctrls_1_down_Decode_LEGAL_1_15,_zz_decode_ctrls_1_down_Decode_LEGAL_1_16,((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'hfc00007f) == 32'h00000033),((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'hfc00305f) == 32'h00001013),((decode_ctrls_1_down_Decode_INSTRUCTION_1 & _zz_decode_ctrls_1_down_Decode_LEGAL_1_18) == 32'h00005013),(_zz_decode_ctrls_1_down_Decode_LEGAL_1_19 == _zz_decode_ctrls_1_down_Decode_LEGAL_1_20),_zz_decode_ctrls_1_down_Decode_LEGAL_1_21,_zz_decode_ctrls_1_down_Decode_LEGAL_1_22,((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h01007fff) == 32'h01006013),((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'hbe00707f) == 32'h00000033),((decode_ctrls_1_down_Decode_INSTRUCTION_1 & _zz_decode_ctrls_1_down_Decode_LEGAL_1_24) == 32'h00006013),(_zz_decode_ctrls_1_down_Decode_LEGAL_1_25 == _zz_decode_ctrls_1_down_Decode_LEGAL_1_26),_zz_decode_ctrls_1_down_Decode_LEGAL_1_27,_zz_decode_ctrls_1_down_Decode_LEGAL_1_28}) && (! decode_ctrls_1_down_Decode_DECOMPRESSION_FAULT_1));
  assign decode_ctrls_1_down_Decode_VIRTUAL_1 = 1'b0;
  assign DecoderPlugin_logic_laneLogic_1_interruptPending = DecoderPlugin_logic_interrupt_buffered[0];
  always @(*) begin
    DecoderPlugin_logic_laneLogic_1_trapPort_valid = 1'b0;
    if(when_DecoderPlugin_l245_1) begin
      DecoderPlugin_logic_laneLogic_1_trapPort_valid = ((! decode_ctrls_1_up_TRAP_1) || DecoderPlugin_logic_laneLogic_1_interruptPending);
      if(DecoderPlugin_logic_laneLogic_1_fixer_doIt) begin
        DecoderPlugin_logic_laneLogic_1_trapPort_valid = 1'b1;
      end
    end
  end

  always @(*) begin
    DecoderPlugin_logic_laneLogic_1_trapPort_payload_exception = 1'b1;
    if(DecoderPlugin_logic_laneLogic_1_fixer_doIt) begin
      DecoderPlugin_logic_laneLogic_1_trapPort_payload_exception = 1'b0;
    end
    if(DecoderPlugin_logic_laneLogic_1_interruptPending) begin
      DecoderPlugin_logic_laneLogic_1_trapPort_payload_exception = 1'b0;
    end
  end

  assign DecoderPlugin_logic_laneLogic_1_trapPort_payload_tval = decode_ctrls_1_down_Decode_INSTRUCTION_RAW_1;
  assign DecoderPlugin_logic_laneLogic_1_trapPort_payload_tval2 = 32'h0;
  always @(*) begin
    DecoderPlugin_logic_laneLogic_1_trapPort_payload_code = 5'h02;
    if(decode_ctrls_1_down_Decode_VIRTUAL_1) begin
      DecoderPlugin_logic_laneLogic_1_trapPort_payload_code = 5'h16;
    end
    if(DecoderPlugin_logic_laneLogic_1_fixer_doIt) begin
      DecoderPlugin_logic_laneLogic_1_trapPort_payload_code = 5'h04;
    end
    if(DecoderPlugin_logic_laneLogic_1_interruptPending) begin
      DecoderPlugin_logic_laneLogic_1_trapPort_payload_code = 5'h0;
    end
  end

  assign DecoderPlugin_logic_laneLogic_1_trapPort_payload_laneAge = 2'b01;
  assign DecoderPlugin_logic_laneLogic_1_trapPort_payload_arg = 3'b000;
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_0_1_1 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1 & 32'h00000050) == 32'h00000040);
  assign DecoderPlugin_logic_laneLogic_1_fixer_isJb = _zz_DecoderPlugin_logic_laneLogic_1_fixer_isJb[0];
  assign DecoderPlugin_logic_laneLogic_1_fixer_doIt = (decode_ctrls_1_up_LANE_SEL_1 && ((decode_ctrls_1_down_Prediction_ALIGNED_JUMPED_1 && (! DecoderPlugin_logic_laneLogic_1_fixer_isJb)) || decode_ctrls_1_down_Prediction_ALIGN_REDO_1));
  assign when_CtrlLaneApi_l50_1 = (decode_ctrls_1_up_isReady || decode_ctrls_1_lane1_upIsCancel);
  assign DecoderPlugin_logic_laneLogic_1_completionPort_valid = ((decode_ctrls_1_up_LANE_SEL_1 && decode_ctrls_1_down_TRAP_1) && (decode_ctrls_1_up_LANE_SEL_1 && (! decode_ctrls_1_up_LANE_SEL_1_regNext)));
  assign DecoderPlugin_logic_laneLogic_1_completionPort_payload_uopId = decode_ctrls_1_down_Decode_UOP_ID_1;
  assign DecoderPlugin_logic_laneLogic_1_completionPort_payload_trap = 1'b1;
  assign DecoderPlugin_logic_laneLogic_1_completionPort_payload_commit = 1'b0;
  assign when_DecoderPlugin_l245_1 = (decode_ctrls_1_up_LANE_SEL_1 && (((! decode_ctrls_1_down_Decode_LEGAL_1) || DecoderPlugin_logic_laneLogic_1_interruptPending) || DecoderPlugin_logic_laneLogic_1_fixer_doIt));
  assign DecoderPlugin_logic_laneLogic_1_flushPort_valid = (decode_ctrls_1_up_LANE_SEL_1 && decode_ctrls_1_down_TRAP_1);
  assign DecoderPlugin_logic_laneLogic_1_flushPort_payload_uopId = decode_ctrls_1_down_Decode_UOP_ID_1;
  assign DecoderPlugin_logic_laneLogic_1_flushPort_payload_laneAge = 1'b1;
  assign DecoderPlugin_logic_laneLogic_1_flushPort_payload_self = 1'b0;
  assign when_DecoderPlugin_l263_1 = ((decode_ctrls_1_down_Decode_INSTRUCTION_1[11 : 7] == 5'h0) && (|1'b1));
  assign decode_ctrls_1_down_Decode_UOP_1 = decode_ctrls_1_down_Decode_INSTRUCTION_1;
  assign DecoderPlugin_logic_laneLogic_1_uopIdBase = DecoderPlugin_logic_harts_0_uopId;
  assign decode_ctrls_1_down_Decode_UOP_ID_1 = (DecoderPlugin_logic_laneLogic_1_uopIdBase + 16'h0001);
  assign DispatchPlugin_logic_trapPendings[0] = (|(DispatchPlugin_logic_slots_0_ctx_valid && DispatchPlugin_logic_slots_0_ctx_hm_TRAP));
  assign DispatchPlugin_logic_candidates_0_moving = (((! DispatchPlugin_logic_candidates_0_ctx_valid) || DispatchPlugin_logic_candidates_0_fire) || DispatchPlugin_logic_candidates_0_cancel);
  assign DispatchPlugin_logic_candidates_1_moving = (((! DispatchPlugin_logic_candidates_1_ctx_valid) || DispatchPlugin_logic_candidates_1_fire) || DispatchPlugin_logic_candidates_1_cancel);
  assign DispatchPlugin_logic_candidates_2_moving = (((! DispatchPlugin_logic_candidates_2_ctx_valid) || DispatchPlugin_logic_candidates_2_fire) || DispatchPlugin_logic_candidates_2_cancel);
  assign DispatchPlugin_logic_candidates_0_age = 1'b0;
  assign DispatchPlugin_logic_candidates_1_age = _zz_DispatchPlugin_logic_candidates_1_age;
  assign DispatchPlugin_logic_candidates_2_age = _zz_DispatchPlugin_logic_candidates_2_age[0:0];
  assign DispatchPlugin_logic_rsHazardChecker_0_onLl_0_onRs_0_hazard = (DispatchPlugin_logic_candidates_0_ctx_hm_RS1_ENABLE && (|{((((DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_logic_hcs_0_onRs_0_ENABLES_0 && execute_ctrl2_up_RD_ENABLE_lane1) && (execute_ctrl2_up_RD_PHYS_lane1 == DispatchPlugin_logic_candidates_0_ctx_hm_RS1_PHYS)) && 1'b1) && (! execute_ctrl2_down_BYPASSED_AT_3_lane1)),(((_zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_0_onRs_0_hazard && _zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_0_onRs_0_hazard_1) && 1'b1) && (! execute_ctrl1_down_BYPASSED_AT_2_lane1)),((_zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_0_onRs_0_hazard_2 && _zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_0_onRs_0_hazard_3) && (! execute_ctrl2_down_BYPASSED_AT_3_lane0)),((_zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_0_onRs_0_hazard_4 && _zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_0_onRs_0_hazard_5) && (! execute_ctrl1_down_BYPASSED_AT_2_lane0))}));
  assign DispatchPlugin_logic_rsHazardChecker_0_onLl_0_onRs_1_hazard = (DispatchPlugin_logic_candidates_0_ctx_hm_RS2_ENABLE && (|{((((DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_logic_hcs_0_onRs_1_ENABLES_0 && execute_ctrl2_up_RD_ENABLE_lane1) && (execute_ctrl2_up_RD_PHYS_lane1 == DispatchPlugin_logic_candidates_0_ctx_hm_RS2_PHYS)) && 1'b1) && (! execute_ctrl2_down_BYPASSED_AT_3_lane1)),(((_zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_0_onRs_1_hazard && _zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_0_onRs_1_hazard_1) && 1'b1) && (! execute_ctrl1_down_BYPASSED_AT_2_lane1)),((_zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_0_onRs_1_hazard_2 && _zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_0_onRs_1_hazard_3) && (! execute_ctrl2_down_BYPASSED_AT_3_lane0)),((_zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_0_onRs_1_hazard_4 && _zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_0_onRs_1_hazard_5) && (! execute_ctrl1_down_BYPASSED_AT_2_lane0))}));
  always @(*) begin
    DispatchPlugin_logic_candidates_0_rsHazards[0] = (|{DispatchPlugin_logic_rsHazardChecker_0_onLl_0_onRs_1_hazard,DispatchPlugin_logic_rsHazardChecker_0_onLl_0_onRs_0_hazard});
    DispatchPlugin_logic_candidates_0_rsHazards[1] = (|{DispatchPlugin_logic_rsHazardChecker_0_onLl_1_onRs_1_hazard,DispatchPlugin_logic_rsHazardChecker_0_onLl_1_onRs_0_hazard});
    DispatchPlugin_logic_candidates_0_rsHazards[2] = (|{DispatchPlugin_logic_rsHazardChecker_0_onLl_2_onRs_1_hazard,DispatchPlugin_logic_rsHazardChecker_0_onLl_2_onRs_0_hazard});
    DispatchPlugin_logic_candidates_0_rsHazards[3] = (|{DispatchPlugin_logic_rsHazardChecker_0_onLl_3_onRs_1_hazard,DispatchPlugin_logic_rsHazardChecker_0_onLl_3_onRs_0_hazard});
  end

  assign DispatchPlugin_logic_rsHazardChecker_0_onLl_1_onRs_0_hazard = (DispatchPlugin_logic_candidates_0_ctx_hm_RS1_ENABLE && (|{((((DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_0_ENABLES_0 && execute_ctrl2_up_RD_ENABLE_lane1) && (execute_ctrl2_up_RD_PHYS_lane1 == DispatchPlugin_logic_candidates_0_ctx_hm_RS1_PHYS)) && 1'b1) && (! execute_ctrl2_down_BYPASSED_AT_3_lane1)),(((_zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_1_onRs_0_hazard && _zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_1_onRs_0_hazard_1) && 1'b1) && (! execute_ctrl1_down_BYPASSED_AT_2_lane1)),((_zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_1_onRs_0_hazard_2 && _zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_1_onRs_0_hazard_3) && (! execute_ctrl2_down_BYPASSED_AT_3_lane0)),((_zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_1_onRs_0_hazard_4 && _zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_1_onRs_0_hazard_5) && (! execute_ctrl1_down_BYPASSED_AT_2_lane0))}));
  assign DispatchPlugin_logic_rsHazardChecker_0_onLl_1_onRs_1_hazard = (DispatchPlugin_logic_candidates_0_ctx_hm_RS2_ENABLE && (|{((((DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_0 && execute_ctrl2_up_RD_ENABLE_lane1) && (execute_ctrl2_up_RD_PHYS_lane1 == DispatchPlugin_logic_candidates_0_ctx_hm_RS2_PHYS)) && 1'b1) && (! execute_ctrl2_down_BYPASSED_AT_3_lane1)),(((_zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_1_onRs_1_hazard && _zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_1_onRs_1_hazard_1) && 1'b1) && (! execute_ctrl1_down_BYPASSED_AT_2_lane1)),((_zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_1_onRs_1_hazard_2 && _zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_1_onRs_1_hazard_3) && (! execute_ctrl2_down_BYPASSED_AT_3_lane0)),((_zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_1_onRs_1_hazard_4 && _zz_DispatchPlugin_logic_rsHazardChecker_0_onLl_1_onRs_1_hazard_5) && (! execute_ctrl1_down_BYPASSED_AT_2_lane0))}));
  assign DispatchPlugin_logic_rsHazardChecker_0_onLl_2_onRs_0_hazard = (DispatchPlugin_logic_candidates_0_ctx_hm_RS1_ENABLE && 1'b0);
  assign DispatchPlugin_logic_rsHazardChecker_0_onLl_2_onRs_1_hazard = (DispatchPlugin_logic_candidates_0_ctx_hm_RS2_ENABLE && 1'b0);
  assign DispatchPlugin_logic_rsHazardChecker_0_onLl_3_onRs_0_hazard = (DispatchPlugin_logic_candidates_0_ctx_hm_RS1_ENABLE && 1'b0);
  assign DispatchPlugin_logic_rsHazardChecker_0_onLl_3_onRs_1_hazard = (DispatchPlugin_logic_candidates_0_ctx_hm_RS2_ENABLE && 1'b0);
  assign DispatchPlugin_logic_rsHazardChecker_1_onLl_0_onRs_0_hazard = (DispatchPlugin_logic_candidates_1_ctx_hm_RS1_ENABLE && (|{((((DispatchPlugin_logic_candidates_1_ctx_hm_DispatchPlugin_logic_hcs_0_onRs_0_ENABLES_0 && execute_ctrl2_up_RD_ENABLE_lane1) && (execute_ctrl2_up_RD_PHYS_lane1 == DispatchPlugin_logic_candidates_1_ctx_hm_RS1_PHYS)) && 1'b1) && (! execute_ctrl2_down_BYPASSED_AT_3_lane1)),(((_zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_0_onRs_0_hazard && _zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_0_onRs_0_hazard_1) && 1'b1) && (! execute_ctrl1_down_BYPASSED_AT_2_lane1)),((_zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_0_onRs_0_hazard_2 && _zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_0_onRs_0_hazard_3) && (! execute_ctrl2_down_BYPASSED_AT_3_lane0)),((_zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_0_onRs_0_hazard_4 && _zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_0_onRs_0_hazard_5) && (! execute_ctrl1_down_BYPASSED_AT_2_lane0))}));
  assign DispatchPlugin_logic_rsHazardChecker_1_onLl_0_onRs_1_hazard = (DispatchPlugin_logic_candidates_1_ctx_hm_RS2_ENABLE && (|{((((DispatchPlugin_logic_candidates_1_ctx_hm_DispatchPlugin_logic_hcs_0_onRs_1_ENABLES_0 && execute_ctrl2_up_RD_ENABLE_lane1) && (execute_ctrl2_up_RD_PHYS_lane1 == DispatchPlugin_logic_candidates_1_ctx_hm_RS2_PHYS)) && 1'b1) && (! execute_ctrl2_down_BYPASSED_AT_3_lane1)),(((_zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_0_onRs_1_hazard && _zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_0_onRs_1_hazard_1) && 1'b1) && (! execute_ctrl1_down_BYPASSED_AT_2_lane1)),((_zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_0_onRs_1_hazard_2 && _zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_0_onRs_1_hazard_3) && (! execute_ctrl2_down_BYPASSED_AT_3_lane0)),((_zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_0_onRs_1_hazard_4 && _zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_0_onRs_1_hazard_5) && (! execute_ctrl1_down_BYPASSED_AT_2_lane0))}));
  always @(*) begin
    DispatchPlugin_logic_candidates_1_rsHazards[0] = (|{DispatchPlugin_logic_rsHazardChecker_1_onLl_0_onRs_1_hazard,DispatchPlugin_logic_rsHazardChecker_1_onLl_0_onRs_0_hazard});
    DispatchPlugin_logic_candidates_1_rsHazards[1] = (|{DispatchPlugin_logic_rsHazardChecker_1_onLl_1_onRs_1_hazard,DispatchPlugin_logic_rsHazardChecker_1_onLl_1_onRs_0_hazard});
    DispatchPlugin_logic_candidates_1_rsHazards[2] = (|{DispatchPlugin_logic_rsHazardChecker_1_onLl_2_onRs_1_hazard,DispatchPlugin_logic_rsHazardChecker_1_onLl_2_onRs_0_hazard});
    DispatchPlugin_logic_candidates_1_rsHazards[3] = (|{DispatchPlugin_logic_rsHazardChecker_1_onLl_3_onRs_1_hazard,DispatchPlugin_logic_rsHazardChecker_1_onLl_3_onRs_0_hazard});
  end

  assign DispatchPlugin_logic_rsHazardChecker_1_onLl_1_onRs_0_hazard = (DispatchPlugin_logic_candidates_1_ctx_hm_RS1_ENABLE && (|{((((DispatchPlugin_logic_candidates_1_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_0_ENABLES_0 && execute_ctrl2_up_RD_ENABLE_lane1) && (execute_ctrl2_up_RD_PHYS_lane1 == DispatchPlugin_logic_candidates_1_ctx_hm_RS1_PHYS)) && 1'b1) && (! execute_ctrl2_down_BYPASSED_AT_3_lane1)),(((_zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_1_onRs_0_hazard && _zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_1_onRs_0_hazard_1) && 1'b1) && (! execute_ctrl1_down_BYPASSED_AT_2_lane1)),((_zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_1_onRs_0_hazard_2 && _zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_1_onRs_0_hazard_3) && (! execute_ctrl2_down_BYPASSED_AT_3_lane0)),((_zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_1_onRs_0_hazard_4 && _zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_1_onRs_0_hazard_5) && (! execute_ctrl1_down_BYPASSED_AT_2_lane0))}));
  assign DispatchPlugin_logic_rsHazardChecker_1_onLl_1_onRs_1_hazard = (DispatchPlugin_logic_candidates_1_ctx_hm_RS2_ENABLE && (|{((((DispatchPlugin_logic_candidates_1_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_0 && execute_ctrl2_up_RD_ENABLE_lane1) && (execute_ctrl2_up_RD_PHYS_lane1 == DispatchPlugin_logic_candidates_1_ctx_hm_RS2_PHYS)) && 1'b1) && (! execute_ctrl2_down_BYPASSED_AT_3_lane1)),(((_zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_1_onRs_1_hazard && _zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_1_onRs_1_hazard_1) && 1'b1) && (! execute_ctrl1_down_BYPASSED_AT_2_lane1)),((_zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_1_onRs_1_hazard_2 && _zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_1_onRs_1_hazard_3) && (! execute_ctrl2_down_BYPASSED_AT_3_lane0)),((_zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_1_onRs_1_hazard_4 && _zz_DispatchPlugin_logic_rsHazardChecker_1_onLl_1_onRs_1_hazard_5) && (! execute_ctrl1_down_BYPASSED_AT_2_lane0))}));
  assign DispatchPlugin_logic_rsHazardChecker_1_onLl_2_onRs_0_hazard = (DispatchPlugin_logic_candidates_1_ctx_hm_RS1_ENABLE && 1'b0);
  assign DispatchPlugin_logic_rsHazardChecker_1_onLl_2_onRs_1_hazard = (DispatchPlugin_logic_candidates_1_ctx_hm_RS2_ENABLE && 1'b0);
  assign DispatchPlugin_logic_rsHazardChecker_1_onLl_3_onRs_0_hazard = (DispatchPlugin_logic_candidates_1_ctx_hm_RS1_ENABLE && 1'b0);
  assign DispatchPlugin_logic_rsHazardChecker_1_onLl_3_onRs_1_hazard = (DispatchPlugin_logic_candidates_1_ctx_hm_RS2_ENABLE && 1'b0);
  assign DispatchPlugin_logic_rsHazardChecker_2_onLl_0_onRs_0_hazard = (DispatchPlugin_logic_candidates_2_ctx_hm_RS1_ENABLE && (|{((((DispatchPlugin_logic_candidates_2_ctx_hm_DispatchPlugin_logic_hcs_0_onRs_0_ENABLES_0 && execute_ctrl2_up_RD_ENABLE_lane1) && (execute_ctrl2_up_RD_PHYS_lane1 == DispatchPlugin_logic_candidates_2_ctx_hm_RS1_PHYS)) && 1'b1) && (! execute_ctrl2_down_BYPASSED_AT_3_lane1)),(((_zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_0_onRs_0_hazard && _zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_0_onRs_0_hazard_1) && 1'b1) && (! execute_ctrl1_down_BYPASSED_AT_2_lane1)),((_zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_0_onRs_0_hazard_2 && _zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_0_onRs_0_hazard_3) && (! execute_ctrl2_down_BYPASSED_AT_3_lane0)),((_zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_0_onRs_0_hazard_4 && _zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_0_onRs_0_hazard_5) && (! execute_ctrl1_down_BYPASSED_AT_2_lane0))}));
  assign DispatchPlugin_logic_rsHazardChecker_2_onLl_0_onRs_1_hazard = (DispatchPlugin_logic_candidates_2_ctx_hm_RS2_ENABLE && (|{((((DispatchPlugin_logic_candidates_2_ctx_hm_DispatchPlugin_logic_hcs_0_onRs_1_ENABLES_0 && execute_ctrl2_up_RD_ENABLE_lane1) && (execute_ctrl2_up_RD_PHYS_lane1 == DispatchPlugin_logic_candidates_2_ctx_hm_RS2_PHYS)) && 1'b1) && (! execute_ctrl2_down_BYPASSED_AT_3_lane1)),(((_zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_0_onRs_1_hazard && _zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_0_onRs_1_hazard_1) && 1'b1) && (! execute_ctrl1_down_BYPASSED_AT_2_lane1)),((_zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_0_onRs_1_hazard_2 && _zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_0_onRs_1_hazard_3) && (! execute_ctrl2_down_BYPASSED_AT_3_lane0)),((_zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_0_onRs_1_hazard_4 && _zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_0_onRs_1_hazard_5) && (! execute_ctrl1_down_BYPASSED_AT_2_lane0))}));
  always @(*) begin
    DispatchPlugin_logic_candidates_2_rsHazards[0] = (|{DispatchPlugin_logic_rsHazardChecker_2_onLl_0_onRs_1_hazard,DispatchPlugin_logic_rsHazardChecker_2_onLl_0_onRs_0_hazard});
    DispatchPlugin_logic_candidates_2_rsHazards[1] = (|{DispatchPlugin_logic_rsHazardChecker_2_onLl_1_onRs_1_hazard,DispatchPlugin_logic_rsHazardChecker_2_onLl_1_onRs_0_hazard});
    DispatchPlugin_logic_candidates_2_rsHazards[2] = (|{DispatchPlugin_logic_rsHazardChecker_2_onLl_2_onRs_1_hazard,DispatchPlugin_logic_rsHazardChecker_2_onLl_2_onRs_0_hazard});
    DispatchPlugin_logic_candidates_2_rsHazards[3] = (|{DispatchPlugin_logic_rsHazardChecker_2_onLl_3_onRs_1_hazard,DispatchPlugin_logic_rsHazardChecker_2_onLl_3_onRs_0_hazard});
  end

  assign DispatchPlugin_logic_rsHazardChecker_2_onLl_1_onRs_0_hazard = (DispatchPlugin_logic_candidates_2_ctx_hm_RS1_ENABLE && (|{((((DispatchPlugin_logic_candidates_2_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_0_ENABLES_0 && execute_ctrl2_up_RD_ENABLE_lane1) && (execute_ctrl2_up_RD_PHYS_lane1 == DispatchPlugin_logic_candidates_2_ctx_hm_RS1_PHYS)) && 1'b1) && (! execute_ctrl2_down_BYPASSED_AT_3_lane1)),(((_zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_1_onRs_0_hazard && _zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_1_onRs_0_hazard_1) && 1'b1) && (! execute_ctrl1_down_BYPASSED_AT_2_lane1)),((_zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_1_onRs_0_hazard_2 && _zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_1_onRs_0_hazard_3) && (! execute_ctrl2_down_BYPASSED_AT_3_lane0)),((_zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_1_onRs_0_hazard_4 && _zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_1_onRs_0_hazard_5) && (! execute_ctrl1_down_BYPASSED_AT_2_lane0))}));
  assign DispatchPlugin_logic_rsHazardChecker_2_onLl_1_onRs_1_hazard = (DispatchPlugin_logic_candidates_2_ctx_hm_RS2_ENABLE && (|{((((DispatchPlugin_logic_candidates_2_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_0 && execute_ctrl2_up_RD_ENABLE_lane1) && (execute_ctrl2_up_RD_PHYS_lane1 == DispatchPlugin_logic_candidates_2_ctx_hm_RS2_PHYS)) && 1'b1) && (! execute_ctrl2_down_BYPASSED_AT_3_lane1)),(((_zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_1_onRs_1_hazard && _zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_1_onRs_1_hazard_1) && 1'b1) && (! execute_ctrl1_down_BYPASSED_AT_2_lane1)),((_zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_1_onRs_1_hazard_2 && _zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_1_onRs_1_hazard_3) && (! execute_ctrl2_down_BYPASSED_AT_3_lane0)),((_zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_1_onRs_1_hazard_4 && _zz_DispatchPlugin_logic_rsHazardChecker_2_onLl_1_onRs_1_hazard_5) && (! execute_ctrl1_down_BYPASSED_AT_2_lane0))}));
  assign DispatchPlugin_logic_rsHazardChecker_2_onLl_2_onRs_0_hazard = (DispatchPlugin_logic_candidates_2_ctx_hm_RS1_ENABLE && 1'b0);
  assign DispatchPlugin_logic_rsHazardChecker_2_onLl_2_onRs_1_hazard = (DispatchPlugin_logic_candidates_2_ctx_hm_RS2_ENABLE && 1'b0);
  assign DispatchPlugin_logic_rsHazardChecker_2_onLl_3_onRs_0_hazard = (DispatchPlugin_logic_candidates_2_ctx_hm_RS1_ENABLE && 1'b0);
  assign DispatchPlugin_logic_rsHazardChecker_2_onLl_3_onRs_1_hazard = (DispatchPlugin_logic_candidates_2_ctx_hm_RS2_ENABLE && 1'b0);
  assign DispatchPlugin_logic_reservationChecker_0_onLl_0_hit = 1'b0;
  always @(*) begin
    DispatchPlugin_logic_candidates_0_reservationHazards[0] = DispatchPlugin_logic_reservationChecker_0_onLl_0_hit;
    DispatchPlugin_logic_candidates_0_reservationHazards[1] = DispatchPlugin_logic_reservationChecker_0_onLl_1_hit;
    DispatchPlugin_logic_candidates_0_reservationHazards[2] = DispatchPlugin_logic_reservationChecker_0_onLl_2_hit;
    DispatchPlugin_logic_candidates_0_reservationHazards[3] = DispatchPlugin_logic_reservationChecker_0_onLl_3_hit;
  end

  assign DispatchPlugin_logic_reservationChecker_0_onLl_1_hit = 1'b0;
  assign DispatchPlugin_logic_reservationChecker_0_onLl_2_hit = 1'b0;
  assign DispatchPlugin_logic_reservationChecker_0_onLl_3_hit = 1'b0;
  assign DispatchPlugin_logic_reservationChecker_1_onLl_0_hit = 1'b0;
  always @(*) begin
    DispatchPlugin_logic_candidates_1_reservationHazards[0] = DispatchPlugin_logic_reservationChecker_1_onLl_0_hit;
    DispatchPlugin_logic_candidates_1_reservationHazards[1] = DispatchPlugin_logic_reservationChecker_1_onLl_1_hit;
    DispatchPlugin_logic_candidates_1_reservationHazards[2] = DispatchPlugin_logic_reservationChecker_1_onLl_2_hit;
    DispatchPlugin_logic_candidates_1_reservationHazards[3] = DispatchPlugin_logic_reservationChecker_1_onLl_3_hit;
  end

  assign DispatchPlugin_logic_reservationChecker_1_onLl_1_hit = 1'b0;
  assign DispatchPlugin_logic_reservationChecker_1_onLl_2_hit = 1'b0;
  assign DispatchPlugin_logic_reservationChecker_1_onLl_3_hit = 1'b0;
  assign DispatchPlugin_logic_reservationChecker_2_onLl_0_hit = 1'b0;
  always @(*) begin
    DispatchPlugin_logic_candidates_2_reservationHazards[0] = DispatchPlugin_logic_reservationChecker_2_onLl_0_hit;
    DispatchPlugin_logic_candidates_2_reservationHazards[1] = DispatchPlugin_logic_reservationChecker_2_onLl_1_hit;
    DispatchPlugin_logic_candidates_2_reservationHazards[2] = DispatchPlugin_logic_reservationChecker_2_onLl_2_hit;
    DispatchPlugin_logic_candidates_2_reservationHazards[3] = DispatchPlugin_logic_reservationChecker_2_onLl_3_hit;
  end

  assign DispatchPlugin_logic_reservationChecker_2_onLl_1_hit = 1'b0;
  assign DispatchPlugin_logic_reservationChecker_2_onLl_2_hit = 1'b0;
  assign DispatchPlugin_logic_reservationChecker_2_onLl_3_hit = 1'b0;
  assign DispatchPlugin_logic_flushChecker_0_executeCheck_0_hits_0 = (|{(((DispatchPlugin_logic_candidates_0_ctx_hm_DONT_FLUSH_PRECISE_4 && execute_ctrl1_up_LANE_SEL_lane0) && 1'b1) && execute_ctrl1_down_MAY_FLUSH_PRECISE_4_lane0),(((DispatchPlugin_logic_candidates_0_ctx_hm_DONT_FLUSH_PRECISE_3 && execute_ctrl1_up_LANE_SEL_lane0) && 1'b1) && execute_ctrl1_down_MAY_FLUSH_PRECISE_3_lane0)});
  assign DispatchPlugin_logic_flushChecker_0_executeCheck_0_hits_1 = (|(((DispatchPlugin_logic_candidates_0_ctx_hm_DONT_FLUSH_PRECISE_3 && execute_ctrl2_up_LANE_SEL_lane0) && 1'b1) && execute_ctrl2_down_MAY_FLUSH_PRECISE_3_lane0));
  assign DispatchPlugin_logic_flushChecker_0_executeCheck_1_hits_0 = (|{(((DispatchPlugin_logic_candidates_0_ctx_hm_DONT_FLUSH_PRECISE_4 && execute_ctrl1_up_LANE_SEL_lane1) && 1'b1) && execute_ctrl1_down_MAY_FLUSH_PRECISE_4_lane1),(((DispatchPlugin_logic_candidates_0_ctx_hm_DONT_FLUSH_PRECISE_3 && execute_ctrl1_up_LANE_SEL_lane1) && 1'b1) && execute_ctrl1_down_MAY_FLUSH_PRECISE_3_lane1)});
  assign DispatchPlugin_logic_flushChecker_0_executeCheck_1_hits_1 = (|(((DispatchPlugin_logic_candidates_0_ctx_hm_DONT_FLUSH_PRECISE_3 && execute_ctrl2_up_LANE_SEL_lane1) && 1'b1) && execute_ctrl2_down_MAY_FLUSH_PRECISE_3_lane1));
  assign DispatchPlugin_logic_flushChecker_0_oldersHazard = 1'b0;
  assign DispatchPlugin_logic_candidates_0_flushHazards = ((|{DispatchPlugin_logic_flushChecker_0_executeCheck_1_hits_1,DispatchPlugin_logic_flushChecker_0_executeCheck_1_hits_0,DispatchPlugin_logic_flushChecker_0_executeCheck_0_hits_1,DispatchPlugin_logic_flushChecker_0_executeCheck_0_hits_0}) || (DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_DONT_FLUSH_FROM_LANES && DispatchPlugin_logic_flushChecker_0_oldersHazard));
  assign DispatchPlugin_logic_flushChecker_1_executeCheck_0_hits_0 = (|{(((DispatchPlugin_logic_candidates_1_ctx_hm_DONT_FLUSH_PRECISE_4 && execute_ctrl1_up_LANE_SEL_lane0) && 1'b1) && execute_ctrl1_down_MAY_FLUSH_PRECISE_4_lane0),(((DispatchPlugin_logic_candidates_1_ctx_hm_DONT_FLUSH_PRECISE_3 && execute_ctrl1_up_LANE_SEL_lane0) && 1'b1) && execute_ctrl1_down_MAY_FLUSH_PRECISE_3_lane0)});
  assign DispatchPlugin_logic_flushChecker_1_executeCheck_0_hits_1 = (|(((DispatchPlugin_logic_candidates_1_ctx_hm_DONT_FLUSH_PRECISE_3 && execute_ctrl2_up_LANE_SEL_lane0) && 1'b1) && execute_ctrl2_down_MAY_FLUSH_PRECISE_3_lane0));
  assign DispatchPlugin_logic_flushChecker_1_executeCheck_1_hits_0 = (|{(((DispatchPlugin_logic_candidates_1_ctx_hm_DONT_FLUSH_PRECISE_4 && execute_ctrl1_up_LANE_SEL_lane1) && 1'b1) && execute_ctrl1_down_MAY_FLUSH_PRECISE_4_lane1),(((DispatchPlugin_logic_candidates_1_ctx_hm_DONT_FLUSH_PRECISE_3 && execute_ctrl1_up_LANE_SEL_lane1) && 1'b1) && execute_ctrl1_down_MAY_FLUSH_PRECISE_3_lane1)});
  assign DispatchPlugin_logic_flushChecker_1_executeCheck_1_hits_1 = (|(((DispatchPlugin_logic_candidates_1_ctx_hm_DONT_FLUSH_PRECISE_3 && execute_ctrl2_up_LANE_SEL_lane1) && 1'b1) && execute_ctrl2_down_MAY_FLUSH_PRECISE_3_lane1));
  assign DispatchPlugin_logic_flushChecker_1_oldersHazard = (|(DispatchPlugin_logic_candidates_0_ctx_valid && DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_MAY_FLUSH));
  assign DispatchPlugin_logic_candidates_1_flushHazards = ((|{DispatchPlugin_logic_flushChecker_1_executeCheck_1_hits_1,DispatchPlugin_logic_flushChecker_1_executeCheck_1_hits_0,DispatchPlugin_logic_flushChecker_1_executeCheck_0_hits_1,DispatchPlugin_logic_flushChecker_1_executeCheck_0_hits_0}) || (DispatchPlugin_logic_candidates_1_ctx_hm_DispatchPlugin_DONT_FLUSH_FROM_LANES && DispatchPlugin_logic_flushChecker_1_oldersHazard));
  assign DispatchPlugin_logic_flushChecker_2_executeCheck_0_hits_0 = (|{(((DispatchPlugin_logic_candidates_2_ctx_hm_DONT_FLUSH_PRECISE_4 && execute_ctrl1_up_LANE_SEL_lane0) && 1'b1) && execute_ctrl1_down_MAY_FLUSH_PRECISE_4_lane0),(((DispatchPlugin_logic_candidates_2_ctx_hm_DONT_FLUSH_PRECISE_3 && execute_ctrl1_up_LANE_SEL_lane0) && 1'b1) && execute_ctrl1_down_MAY_FLUSH_PRECISE_3_lane0)});
  assign DispatchPlugin_logic_flushChecker_2_executeCheck_0_hits_1 = (|(((DispatchPlugin_logic_candidates_2_ctx_hm_DONT_FLUSH_PRECISE_3 && execute_ctrl2_up_LANE_SEL_lane0) && 1'b1) && execute_ctrl2_down_MAY_FLUSH_PRECISE_3_lane0));
  assign DispatchPlugin_logic_flushChecker_2_executeCheck_1_hits_0 = (|{(((DispatchPlugin_logic_candidates_2_ctx_hm_DONT_FLUSH_PRECISE_4 && execute_ctrl1_up_LANE_SEL_lane1) && 1'b1) && execute_ctrl1_down_MAY_FLUSH_PRECISE_4_lane1),(((DispatchPlugin_logic_candidates_2_ctx_hm_DONT_FLUSH_PRECISE_3 && execute_ctrl1_up_LANE_SEL_lane1) && 1'b1) && execute_ctrl1_down_MAY_FLUSH_PRECISE_3_lane1)});
  assign DispatchPlugin_logic_flushChecker_2_executeCheck_1_hits_1 = (|(((DispatchPlugin_logic_candidates_2_ctx_hm_DONT_FLUSH_PRECISE_3 && execute_ctrl2_up_LANE_SEL_lane1) && 1'b1) && execute_ctrl2_down_MAY_FLUSH_PRECISE_3_lane1));
  assign DispatchPlugin_logic_flushChecker_2_oldersHazard = (|{(DispatchPlugin_logic_candidates_1_ctx_valid && DispatchPlugin_logic_candidates_1_ctx_hm_DispatchPlugin_MAY_FLUSH),(DispatchPlugin_logic_candidates_0_ctx_valid && DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_MAY_FLUSH)});
  assign DispatchPlugin_logic_candidates_2_flushHazards = ((|{DispatchPlugin_logic_flushChecker_2_executeCheck_1_hits_1,DispatchPlugin_logic_flushChecker_2_executeCheck_1_hits_0,DispatchPlugin_logic_flushChecker_2_executeCheck_0_hits_1,DispatchPlugin_logic_flushChecker_2_executeCheck_0_hits_0}) || (DispatchPlugin_logic_candidates_2_ctx_hm_DispatchPlugin_DONT_FLUSH_FROM_LANES && DispatchPlugin_logic_flushChecker_2_oldersHazard));
  assign DispatchPlugin_logic_fenceChecker_olderInflights = (|{execute_lane1_api_hartsInflight[0],execute_lane0_api_hartsInflight[0]});
  assign DispatchPlugin_logic_candidates_0_fenceOlderHazards = (DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_FENCE_OLDER && (DispatchPlugin_logic_fenceChecker_olderInflights[0] || 1'b0));
  assign DispatchPlugin_logic_candidates_1_fenceOlderHazards = (DispatchPlugin_logic_candidates_1_ctx_hm_DispatchPlugin_FENCE_OLDER && (DispatchPlugin_logic_fenceChecker_olderInflights[0] || (|(DispatchPlugin_logic_candidates_0_ctx_valid && 1'b1))));
  assign DispatchPlugin_logic_candidates_2_fenceOlderHazards = (DispatchPlugin_logic_candidates_2_ctx_hm_DispatchPlugin_FENCE_OLDER && (DispatchPlugin_logic_fenceChecker_olderInflights[0] || (|{(DispatchPlugin_logic_candidates_1_ctx_valid && 1'b1),(DispatchPlugin_logic_candidates_0_ctx_valid && 1'b1)})));
  always @(*) begin
    decode_ctrls_1_down_ready = 1'b1;
    if(when_DispatchPlugin_l375) begin
      decode_ctrls_1_down_ready = 1'b0;
    end
    if(when_DispatchPlugin_l375_1) begin
      decode_ctrls_1_down_ready = 1'b0;
    end
    if(DispatchPlugin_logic_slotsFeeds_doIt) begin
      decode_ctrls_1_down_ready = 1'b1;
    end
  end

  assign DispatchPlugin_logic_feeds_0_sending = DispatchPlugin_logic_candidates_1_fire;
  assign DispatchPlugin_logic_candidates_1_cancel = decode_ctrls_1_lane0_upIsCancel;
  assign DispatchPlugin_logic_candidates_1_ctx_valid = ((decode_ctrls_1_up_isValid && decode_ctrls_1_up_LANE_SEL_0) && (! DispatchPlugin_logic_feeds_0_sent));
  always @(*) begin
    DispatchPlugin_logic_candidates_1_ctx_laneLayerHits = {decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_0,decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_2_0,decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_1_0,decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_0_0};
    if(decode_ctrls_1_down_TRAP_0) begin
      DispatchPlugin_logic_candidates_1_ctx_laneLayerHits = 4'b0010;
    end
  end

  assign DispatchPlugin_logic_candidates_1_ctx_uop = decode_ctrls_1_down_Decode_UOP_0;
  assign DispatchPlugin_logic_candidates_1_ctx_uopIsCompressed = (! (&decode_ctrls_1_down_Decode_INSTRUCTION_RAW_0[1 : 0]));
  assign DispatchPlugin_logic_candidates_1_ctx_hm_Prediction_ALIGNED_JUMPED = decode_ctrls_1_down_Prediction_ALIGNED_JUMPED_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_Prediction_ALIGNED_JUMPED_PC = decode_ctrls_1_down_Prediction_ALIGNED_JUMPED_PC_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_Prediction_ALIGNED_SLICES_TAKEN = decode_ctrls_1_down_Prediction_ALIGNED_SLICES_TAKEN_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_Prediction_ALIGNED_SLICES_BRANCH = decode_ctrls_1_down_Prediction_ALIGNED_SLICES_BRANCH_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_GSharePlugin_GSHARE_COUNTER_0 = decode_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_0_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_GSharePlugin_GSHARE_COUNTER_1 = decode_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_0_1;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_GSharePlugin_GSHARE_COUNTER_2 = decode_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_0_2;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_GSharePlugin_GSHARE_COUNTER_3 = decode_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_0_3;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_Prediction_BRANCH_HISTORY = decode_ctrls_1_down_Prediction_BRANCH_HISTORY_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_DispatchPlugin_FENCE_OLDER = decode_ctrls_1_down_DispatchPlugin_FENCE_OLDER_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_DispatchPlugin_MAY_FLUSH = decode_ctrls_1_down_DispatchPlugin_MAY_FLUSH_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_DispatchPlugin_DONT_FLUSH = decode_ctrls_1_down_DispatchPlugin_DONT_FLUSH_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_DispatchPlugin_DONT_FLUSH_FROM_LANES = decode_ctrls_1_down_DispatchPlugin_DONT_FLUSH_FROM_LANES_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_Decode_INSTRUCTION_SLICE_COUNT = decode_ctrls_1_down_Decode_INSTRUCTION_SLICE_COUNT_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_DONT_FLUSH_PRECISE_3 = decode_ctrls_1_down_DONT_FLUSH_PRECISE_3_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_DONT_FLUSH_PRECISE_4 = decode_ctrls_1_down_DONT_FLUSH_PRECISE_4_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_PC = decode_ctrls_1_down_PC_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_TRAP = decode_ctrls_1_down_TRAP_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_Decode_UOP_ID = decode_ctrls_1_down_Decode_UOP_ID_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_RS1_ENABLE = decode_ctrls_1_down_RS1_ENABLE_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_RS1_PHYS = decode_ctrls_1_down_RS1_PHYS_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_RS2_ENABLE = decode_ctrls_1_down_RS2_ENABLE_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_RS2_PHYS = decode_ctrls_1_down_RS2_PHYS_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_RD_ENABLE = decode_ctrls_1_down_RD_ENABLE_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_RD_PHYS = decode_ctrls_1_down_RD_PHYS_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_DispatchPlugin_logic_hcs_0_onRs_0_ENABLES_0 = decode_ctrls_1_down_DispatchPlugin_logic_hcs_0_onRs_0_ENABLES_0_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_DispatchPlugin_logic_hcs_0_onRs_1_ENABLES_0 = decode_ctrls_1_down_DispatchPlugin_logic_hcs_0_onRs_1_ENABLES_0_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_0_ENABLES_0 = decode_ctrls_1_down_DispatchPlugin_logic_hcs_1_onRs_0_ENABLES_0_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_0 = decode_ctrls_1_down_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_0_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_1 = decode_ctrls_1_down_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_1_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_DispatchPlugin_logic_hcs_2_onRs_0_ENABLES_0 = decode_ctrls_1_down_DispatchPlugin_logic_hcs_2_onRs_0_ENABLES_0_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_DispatchPlugin_logic_hcs_2_onRs_1_ENABLES_0 = decode_ctrls_1_down_DispatchPlugin_logic_hcs_2_onRs_1_ENABLES_0_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_DispatchPlugin_logic_hcs_3_onRs_0_ENABLES_0 = decode_ctrls_1_down_DispatchPlugin_logic_hcs_3_onRs_0_ENABLES_0_0;
  assign DispatchPlugin_logic_candidates_1_ctx_hm_DispatchPlugin_logic_hcs_3_onRs_1_ENABLES_0 = decode_ctrls_1_down_DispatchPlugin_logic_hcs_3_onRs_1_ENABLES_0_0;
  assign when_DispatchPlugin_l375 = ((decode_ctrls_1_up_LANE_SEL_0 && (! DispatchPlugin_logic_feeds_0_sent)) && (! DispatchPlugin_logic_candidates_1_fire));
  assign DispatchPlugin_logic_feeds_1_sending = DispatchPlugin_logic_candidates_2_fire;
  assign DispatchPlugin_logic_candidates_2_cancel = decode_ctrls_1_lane1_upIsCancel;
  assign DispatchPlugin_logic_candidates_2_ctx_valid = ((decode_ctrls_1_up_isValid && decode_ctrls_1_up_LANE_SEL_1) && (! DispatchPlugin_logic_feeds_1_sent));
  always @(*) begin
    DispatchPlugin_logic_candidates_2_ctx_laneLayerHits = {decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_1,decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_2_1,decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_1_1,decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_0_1};
    if(decode_ctrls_1_down_TRAP_1) begin
      DispatchPlugin_logic_candidates_2_ctx_laneLayerHits = 4'b0010;
    end
  end

  assign DispatchPlugin_logic_candidates_2_ctx_uop = decode_ctrls_1_down_Decode_UOP_1;
  assign DispatchPlugin_logic_candidates_2_ctx_uopIsCompressed = (! (&decode_ctrls_1_down_Decode_INSTRUCTION_RAW_1[1 : 0]));
  assign DispatchPlugin_logic_candidates_2_ctx_hm_Prediction_ALIGNED_JUMPED = decode_ctrls_1_down_Prediction_ALIGNED_JUMPED_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_Prediction_ALIGNED_JUMPED_PC = decode_ctrls_1_down_Prediction_ALIGNED_JUMPED_PC_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_Prediction_ALIGNED_SLICES_TAKEN = decode_ctrls_1_down_Prediction_ALIGNED_SLICES_TAKEN_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_Prediction_ALIGNED_SLICES_BRANCH = decode_ctrls_1_down_Prediction_ALIGNED_SLICES_BRANCH_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_GSharePlugin_GSHARE_COUNTER_0 = decode_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_1_0;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_GSharePlugin_GSHARE_COUNTER_1 = decode_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_1_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_GSharePlugin_GSHARE_COUNTER_2 = decode_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_1_2;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_GSharePlugin_GSHARE_COUNTER_3 = decode_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_1_3;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_Prediction_BRANCH_HISTORY = decode_ctrls_1_down_Prediction_BRANCH_HISTORY_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_DispatchPlugin_FENCE_OLDER = decode_ctrls_1_down_DispatchPlugin_FENCE_OLDER_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_DispatchPlugin_MAY_FLUSH = decode_ctrls_1_down_DispatchPlugin_MAY_FLUSH_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_DispatchPlugin_DONT_FLUSH = decode_ctrls_1_down_DispatchPlugin_DONT_FLUSH_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_DispatchPlugin_DONT_FLUSH_FROM_LANES = decode_ctrls_1_down_DispatchPlugin_DONT_FLUSH_FROM_LANES_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_Decode_INSTRUCTION_SLICE_COUNT = decode_ctrls_1_down_Decode_INSTRUCTION_SLICE_COUNT_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_DONT_FLUSH_PRECISE_3 = decode_ctrls_1_down_DONT_FLUSH_PRECISE_3_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_DONT_FLUSH_PRECISE_4 = decode_ctrls_1_down_DONT_FLUSH_PRECISE_4_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_PC = decode_ctrls_1_down_PC_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_TRAP = decode_ctrls_1_down_TRAP_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_Decode_UOP_ID = decode_ctrls_1_down_Decode_UOP_ID_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_RS1_ENABLE = decode_ctrls_1_down_RS1_ENABLE_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_RS1_PHYS = decode_ctrls_1_down_RS1_PHYS_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_RS2_ENABLE = decode_ctrls_1_down_RS2_ENABLE_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_RS2_PHYS = decode_ctrls_1_down_RS2_PHYS_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_RD_ENABLE = decode_ctrls_1_down_RD_ENABLE_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_RD_PHYS = decode_ctrls_1_down_RD_PHYS_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_DispatchPlugin_logic_hcs_0_onRs_0_ENABLES_0 = decode_ctrls_1_down_DispatchPlugin_logic_hcs_0_onRs_0_ENABLES_0_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_DispatchPlugin_logic_hcs_0_onRs_1_ENABLES_0 = decode_ctrls_1_down_DispatchPlugin_logic_hcs_0_onRs_1_ENABLES_0_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_0_ENABLES_0 = decode_ctrls_1_down_DispatchPlugin_logic_hcs_1_onRs_0_ENABLES_0_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_0 = decode_ctrls_1_down_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_0_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_1 = decode_ctrls_1_down_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_1_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_DispatchPlugin_logic_hcs_2_onRs_0_ENABLES_0 = decode_ctrls_1_down_DispatchPlugin_logic_hcs_2_onRs_0_ENABLES_0_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_DispatchPlugin_logic_hcs_2_onRs_1_ENABLES_0 = decode_ctrls_1_down_DispatchPlugin_logic_hcs_2_onRs_1_ENABLES_0_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_DispatchPlugin_logic_hcs_3_onRs_0_ENABLES_0 = decode_ctrls_1_down_DispatchPlugin_logic_hcs_3_onRs_0_ENABLES_0_1;
  assign DispatchPlugin_logic_candidates_2_ctx_hm_DispatchPlugin_logic_hcs_3_onRs_1_ENABLES_0 = decode_ctrls_1_down_DispatchPlugin_logic_hcs_3_onRs_1_ENABLES_0_1;
  assign when_DispatchPlugin_l375_1 = ((decode_ctrls_1_up_LANE_SEL_1 && (! DispatchPlugin_logic_feeds_1_sent)) && (! DispatchPlugin_logic_candidates_2_fire));
  assign DispatchPlugin_logic_candidates_0_ctx_valid = DispatchPlugin_logic_slots_0_ctx_valid;
  assign DispatchPlugin_logic_candidates_0_ctx_laneLayerHits = DispatchPlugin_logic_slots_0_ctx_laneLayerHits;
  assign DispatchPlugin_logic_candidates_0_ctx_uop = DispatchPlugin_logic_slots_0_ctx_uop;
  assign DispatchPlugin_logic_candidates_0_ctx_uopIsCompressed = DispatchPlugin_logic_slots_0_ctx_uopIsCompressed;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_Prediction_ALIGNED_JUMPED = DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_Prediction_ALIGNED_JUMPED_PC = DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED_PC;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_Prediction_ALIGNED_SLICES_TAKEN = DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_SLICES_TAKEN;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_Prediction_ALIGNED_SLICES_BRANCH = DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_SLICES_BRANCH;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_GSharePlugin_GSHARE_COUNTER_0 = DispatchPlugin_logic_slots_0_ctx_hm_GSharePlugin_GSHARE_COUNTER_0;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_GSharePlugin_GSHARE_COUNTER_1 = DispatchPlugin_logic_slots_0_ctx_hm_GSharePlugin_GSHARE_COUNTER_1;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_GSharePlugin_GSHARE_COUNTER_2 = DispatchPlugin_logic_slots_0_ctx_hm_GSharePlugin_GSHARE_COUNTER_2;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_GSharePlugin_GSHARE_COUNTER_3 = DispatchPlugin_logic_slots_0_ctx_hm_GSharePlugin_GSHARE_COUNTER_3;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_Prediction_BRANCH_HISTORY = DispatchPlugin_logic_slots_0_ctx_hm_Prediction_BRANCH_HISTORY;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_FENCE_OLDER = DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_FENCE_OLDER;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_MAY_FLUSH = DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_MAY_FLUSH;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_DONT_FLUSH = DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_DONT_FLUSH;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_DONT_FLUSH_FROM_LANES = DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_DONT_FLUSH_FROM_LANES;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_Decode_INSTRUCTION_SLICE_COUNT = DispatchPlugin_logic_slots_0_ctx_hm_Decode_INSTRUCTION_SLICE_COUNT;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_DONT_FLUSH_PRECISE_3 = DispatchPlugin_logic_slots_0_ctx_hm_DONT_FLUSH_PRECISE_3;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_DONT_FLUSH_PRECISE_4 = DispatchPlugin_logic_slots_0_ctx_hm_DONT_FLUSH_PRECISE_4;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_PC = DispatchPlugin_logic_slots_0_ctx_hm_PC;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_TRAP = DispatchPlugin_logic_slots_0_ctx_hm_TRAP;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_Decode_UOP_ID = DispatchPlugin_logic_slots_0_ctx_hm_Decode_UOP_ID;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_RS1_ENABLE = DispatchPlugin_logic_slots_0_ctx_hm_RS1_ENABLE;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_RS1_PHYS = DispatchPlugin_logic_slots_0_ctx_hm_RS1_PHYS;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_RS2_ENABLE = DispatchPlugin_logic_slots_0_ctx_hm_RS2_ENABLE;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_RS2_PHYS = DispatchPlugin_logic_slots_0_ctx_hm_RS2_PHYS;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_RD_ENABLE = DispatchPlugin_logic_slots_0_ctx_hm_RD_ENABLE;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_RD_PHYS = DispatchPlugin_logic_slots_0_ctx_hm_RD_PHYS;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_logic_hcs_0_onRs_0_ENABLES_0 = DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_logic_hcs_0_onRs_0_ENABLES_0;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_logic_hcs_0_onRs_1_ENABLES_0 = DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_logic_hcs_0_onRs_1_ENABLES_0;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_0_ENABLES_0 = DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_0_ENABLES_0;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_0 = DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_0;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_1 = DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_1;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_logic_hcs_2_onRs_0_ENABLES_0 = DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_logic_hcs_2_onRs_0_ENABLES_0;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_logic_hcs_2_onRs_1_ENABLES_0 = DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_logic_hcs_2_onRs_1_ENABLES_0;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_logic_hcs_3_onRs_0_ENABLES_0 = DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_logic_hcs_3_onRs_0_ENABLES_0;
  assign DispatchPlugin_logic_candidates_0_ctx_hm_DispatchPlugin_logic_hcs_3_onRs_1_ENABLES_0 = DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_logic_hcs_3_onRs_1_ENABLES_0;
  assign when_DispatchPlugin_l385 = (DispatchPlugin_logic_candidates_0_fire || DispatchPlugin_logic_candidates_0_cancel);
  always @(*) begin
    late0_BranchPlugin_logic_jumpLogic_learn_ready = LearnPlugin_logic_buffered_0_ready;
    if(when_Stream_l477) begin
      late0_BranchPlugin_logic_jumpLogic_learn_ready = 1'b1;
    end
  end

  assign when_Stream_l477 = (! LearnPlugin_logic_buffered_0_valid);
  assign LearnPlugin_logic_buffered_0_valid = late0_BranchPlugin_logic_jumpLogic_learn_rValid;
  assign LearnPlugin_logic_buffered_0_payload_pcOnLastSlice = late0_BranchPlugin_logic_jumpLogic_learn_rData_pcOnLastSlice;
  assign LearnPlugin_logic_buffered_0_payload_pcTarget = late0_BranchPlugin_logic_jumpLogic_learn_rData_pcTarget;
  assign LearnPlugin_logic_buffered_0_payload_taken = late0_BranchPlugin_logic_jumpLogic_learn_rData_taken;
  assign LearnPlugin_logic_buffered_0_payload_isBranch = late0_BranchPlugin_logic_jumpLogic_learn_rData_isBranch;
  assign LearnPlugin_logic_buffered_0_payload_isPush = late0_BranchPlugin_logic_jumpLogic_learn_rData_isPush;
  assign LearnPlugin_logic_buffered_0_payload_isPop = late0_BranchPlugin_logic_jumpLogic_learn_rData_isPop;
  assign LearnPlugin_logic_buffered_0_payload_wasWrong = late0_BranchPlugin_logic_jumpLogic_learn_rData_wasWrong;
  assign LearnPlugin_logic_buffered_0_payload_badPredictedTarget = late0_BranchPlugin_logic_jumpLogic_learn_rData_badPredictedTarget;
  assign LearnPlugin_logic_buffered_0_payload_history = late0_BranchPlugin_logic_jumpLogic_learn_rData_history;
  assign LearnPlugin_logic_buffered_0_payload_uopId = late0_BranchPlugin_logic_jumpLogic_learn_rData_uopId;
  assign LearnPlugin_logic_buffered_0_payload_ctx_GSharePlugin_GSHARE_COUNTER_0 = late0_BranchPlugin_logic_jumpLogic_learn_rData_ctx_GSharePlugin_GSHARE_COUNTER_0;
  assign LearnPlugin_logic_buffered_0_payload_ctx_GSharePlugin_GSHARE_COUNTER_1 = late0_BranchPlugin_logic_jumpLogic_learn_rData_ctx_GSharePlugin_GSHARE_COUNTER_1;
  assign LearnPlugin_logic_buffered_0_payload_ctx_GSharePlugin_GSHARE_COUNTER_2 = late0_BranchPlugin_logic_jumpLogic_learn_rData_ctx_GSharePlugin_GSHARE_COUNTER_2;
  assign LearnPlugin_logic_buffered_0_payload_ctx_GSharePlugin_GSHARE_COUNTER_3 = late0_BranchPlugin_logic_jumpLogic_learn_rData_ctx_GSharePlugin_GSHARE_COUNTER_3;
  always @(*) begin
    late1_BranchPlugin_logic_jumpLogic_learn_ready = LearnPlugin_logic_buffered_1_ready;
    if(when_Stream_l477_1) begin
      late1_BranchPlugin_logic_jumpLogic_learn_ready = 1'b1;
    end
  end

  assign when_Stream_l477_1 = (! LearnPlugin_logic_buffered_1_valid);
  assign LearnPlugin_logic_buffered_1_valid = late1_BranchPlugin_logic_jumpLogic_learn_rValid;
  assign LearnPlugin_logic_buffered_1_payload_pcOnLastSlice = late1_BranchPlugin_logic_jumpLogic_learn_rData_pcOnLastSlice;
  assign LearnPlugin_logic_buffered_1_payload_pcTarget = late1_BranchPlugin_logic_jumpLogic_learn_rData_pcTarget;
  assign LearnPlugin_logic_buffered_1_payload_taken = late1_BranchPlugin_logic_jumpLogic_learn_rData_taken;
  assign LearnPlugin_logic_buffered_1_payload_isBranch = late1_BranchPlugin_logic_jumpLogic_learn_rData_isBranch;
  assign LearnPlugin_logic_buffered_1_payload_isPush = late1_BranchPlugin_logic_jumpLogic_learn_rData_isPush;
  assign LearnPlugin_logic_buffered_1_payload_isPop = late1_BranchPlugin_logic_jumpLogic_learn_rData_isPop;
  assign LearnPlugin_logic_buffered_1_payload_wasWrong = late1_BranchPlugin_logic_jumpLogic_learn_rData_wasWrong;
  assign LearnPlugin_logic_buffered_1_payload_badPredictedTarget = late1_BranchPlugin_logic_jumpLogic_learn_rData_badPredictedTarget;
  assign LearnPlugin_logic_buffered_1_payload_history = late1_BranchPlugin_logic_jumpLogic_learn_rData_history;
  assign LearnPlugin_logic_buffered_1_payload_uopId = late1_BranchPlugin_logic_jumpLogic_learn_rData_uopId;
  assign LearnPlugin_logic_buffered_1_payload_ctx_GSharePlugin_GSHARE_COUNTER_0 = late1_BranchPlugin_logic_jumpLogic_learn_rData_ctx_GSharePlugin_GSHARE_COUNTER_0;
  assign LearnPlugin_logic_buffered_1_payload_ctx_GSharePlugin_GSHARE_COUNTER_1 = late1_BranchPlugin_logic_jumpLogic_learn_rData_ctx_GSharePlugin_GSHARE_COUNTER_1;
  assign LearnPlugin_logic_buffered_1_payload_ctx_GSharePlugin_GSHARE_COUNTER_2 = late1_BranchPlugin_logic_jumpLogic_learn_rData_ctx_GSharePlugin_GSHARE_COUNTER_2;
  assign LearnPlugin_logic_buffered_1_payload_ctx_GSharePlugin_GSHARE_COUNTER_3 = late1_BranchPlugin_logic_jumpLogic_learn_rData_ctx_GSharePlugin_GSHARE_COUNTER_3;
  assign LearnPlugin_logic_buffered_0_ready = streamArbiter_7_io_inputs_0_ready;
  assign LearnPlugin_logic_buffered_1_ready = streamArbiter_7_io_inputs_1_ready;
  assign LearnPlugin_logic_arbitrated_valid = streamArbiter_7_io_output_valid;
  assign LearnPlugin_logic_arbitrated_payload_pcOnLastSlice = streamArbiter_7_io_output_payload_pcOnLastSlice;
  assign LearnPlugin_logic_arbitrated_payload_pcTarget = streamArbiter_7_io_output_payload_pcTarget;
  assign LearnPlugin_logic_arbitrated_payload_taken = streamArbiter_7_io_output_payload_taken;
  assign LearnPlugin_logic_arbitrated_payload_isBranch = streamArbiter_7_io_output_payload_isBranch;
  assign LearnPlugin_logic_arbitrated_payload_isPush = streamArbiter_7_io_output_payload_isPush;
  assign LearnPlugin_logic_arbitrated_payload_isPop = streamArbiter_7_io_output_payload_isPop;
  assign LearnPlugin_logic_arbitrated_payload_wasWrong = streamArbiter_7_io_output_payload_wasWrong;
  assign LearnPlugin_logic_arbitrated_payload_badPredictedTarget = streamArbiter_7_io_output_payload_badPredictedTarget;
  assign LearnPlugin_logic_arbitrated_payload_history = streamArbiter_7_io_output_payload_history;
  assign LearnPlugin_logic_arbitrated_payload_uopId = streamArbiter_7_io_output_payload_uopId;
  assign LearnPlugin_logic_arbitrated_payload_ctx_GSharePlugin_GSHARE_COUNTER_0 = streamArbiter_7_io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_0;
  assign LearnPlugin_logic_arbitrated_payload_ctx_GSharePlugin_GSHARE_COUNTER_1 = streamArbiter_7_io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_1;
  assign LearnPlugin_logic_arbitrated_payload_ctx_GSharePlugin_GSHARE_COUNTER_2 = streamArbiter_7_io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_2;
  assign LearnPlugin_logic_arbitrated_payload_ctx_GSharePlugin_GSHARE_COUNTER_3 = streamArbiter_7_io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_3;
  assign LearnPlugin_logic_arbitrated_ready = 1'b1;
  assign LearnPlugin_logic_arbitrated_toFlow_valid = LearnPlugin_logic_arbitrated_valid;
  assign LearnPlugin_logic_arbitrated_toFlow_payload_pcOnLastSlice = LearnPlugin_logic_arbitrated_payload_pcOnLastSlice;
  assign LearnPlugin_logic_arbitrated_toFlow_payload_pcTarget = LearnPlugin_logic_arbitrated_payload_pcTarget;
  assign LearnPlugin_logic_arbitrated_toFlow_payload_taken = LearnPlugin_logic_arbitrated_payload_taken;
  assign LearnPlugin_logic_arbitrated_toFlow_payload_isBranch = LearnPlugin_logic_arbitrated_payload_isBranch;
  assign LearnPlugin_logic_arbitrated_toFlow_payload_isPush = LearnPlugin_logic_arbitrated_payload_isPush;
  assign LearnPlugin_logic_arbitrated_toFlow_payload_isPop = LearnPlugin_logic_arbitrated_payload_isPop;
  assign LearnPlugin_logic_arbitrated_toFlow_payload_wasWrong = LearnPlugin_logic_arbitrated_payload_wasWrong;
  assign LearnPlugin_logic_arbitrated_toFlow_payload_badPredictedTarget = LearnPlugin_logic_arbitrated_payload_badPredictedTarget;
  assign LearnPlugin_logic_arbitrated_toFlow_payload_history = LearnPlugin_logic_arbitrated_payload_history;
  assign LearnPlugin_logic_arbitrated_toFlow_payload_uopId = LearnPlugin_logic_arbitrated_payload_uopId;
  assign LearnPlugin_logic_arbitrated_toFlow_payload_ctx_GSharePlugin_GSHARE_COUNTER_0 = LearnPlugin_logic_arbitrated_payload_ctx_GSharePlugin_GSHARE_COUNTER_0;
