  assign _zz_execute_ctrl1_down_late0_BranchPlugin_SEL_lane0 = ((execute_lane0_logic_decoding_decodingBits & 33'h100000010) == 33'h0);
  always @(*) begin
    execute_ctrl1_down_late0_BranchPlugin_SEL_lane0 = _zz_execute_ctrl1_down_late0_BranchPlugin_SEL_lane0_1[0];
    if(execute_ctrl1_down_TRAP_lane0) begin
      execute_ctrl1_down_late0_BranchPlugin_SEL_lane0 = 1'b0;
    end
  end

  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_2_ENABLE_lane0_1 = ((execute_lane0_logic_decoding_decodingBits & 33'h000002050) == 33'h000002050);
  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_2_ENABLE_lane0_2 = ((execute_lane0_logic_decoding_decodingBits & 33'h000001050) == 33'h000001050);
  always @(*) begin
    execute_ctrl1_down_CsrAccessPlugin_SEL_lane0 = _zz_execute_ctrl1_down_CsrAccessPlugin_SEL_lane0[0];
    if(execute_ctrl1_down_TRAP_lane0) begin
      execute_ctrl1_down_CsrAccessPlugin_SEL_lane0 = 1'b0;
    end
  end

  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_1_ENABLE_lane0 = ((execute_lane0_logic_decoding_decodingBits & 33'h001d07fa4) == 33'h000106000);
  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_1_ENABLE_lane0_1 = ((execute_lane0_logic_decoding_decodingBits & 33'h000000058) == 33'h0);
  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_1_ENABLE_lane0_2 = ((execute_lane0_logic_decoding_decodingBits & 33'h000001050) == 33'h0);
  always @(*) begin
    execute_ctrl1_down_AguPlugin_SEL_lane0 = _zz_execute_ctrl1_down_AguPlugin_SEL_lane0[0];
    if(execute_ctrl1_down_TRAP_lane0) begin
      execute_ctrl1_down_AguPlugin_SEL_lane0 = 1'b0;
    end
  end

  always @(*) begin
    execute_ctrl1_down_LsuPlugin_logic_FENCE_lane0 = _zz_execute_ctrl1_down_LsuPlugin_logic_FENCE_lane0[0];
    if(execute_ctrl1_down_TRAP_lane0) begin
      execute_ctrl1_down_LsuPlugin_logic_FENCE_lane0 = 1'b0;
    end
  end

  assign _zz_execute_ctrl1_down_lane0_integer_WriteBackPlugin_SEL_lane0 = ((execute_lane0_logic_decoding_decodingBits & 33'h00000000c) == 33'h000000004);
  always @(*) begin
    execute_ctrl1_down_lane0_integer_WriteBackPlugin_SEL_lane0 = _zz_execute_ctrl1_down_lane0_integer_WriteBackPlugin_SEL_lane0_1[0];
    if(execute_ctrl1_down_TRAP_lane0) begin
      execute_ctrl1_down_lane0_integer_WriteBackPlugin_SEL_lane0 = 1'b0;
    end
  end

  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0_12 = ((execute_lane0_logic_decoding_decodingBits & 33'h102000070) == 33'h100000030);
  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0_13 = ((execute_lane0_logic_decoding_decodingBits & 33'h100003040) == 33'h100000040);
  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0_14 = ((execute_lane0_logic_decoding_decodingBits & 33'h100002030) == 33'h100000010);
  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0_15 = ((execute_lane0_logic_decoding_decodingBits & 33'h100004030) == 33'h100000010);
  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0_16 = ((execute_lane0_logic_decoding_decodingBits & 33'h10000000c) == 33'h100000004);
  always @(*) begin
    execute_ctrl1_down_COMPLETION_AT_2_lane0 = _zz_execute_ctrl1_down_COMPLETION_AT_2_lane0[0];
    if(execute_ctrl1_down_TRAP_lane0) begin
      execute_ctrl1_down_COMPLETION_AT_2_lane0 = 1'b0;
    end
  end

  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_1_ENABLE_lane0_3 = ((execute_lane0_logic_decoding_decodingBits & 33'h002004064) == 33'h002000020);
  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_1_ENABLE_lane0_4 = ((execute_lane0_logic_decoding_decodingBits & 33'h100000000) == 33'h0);
  always @(*) begin
    execute_ctrl1_down_COMPLETION_AT_4_lane0 = _zz_execute_ctrl1_down_COMPLETION_AT_4_lane0[0];
    if(execute_ctrl1_down_TRAP_lane0) begin
      execute_ctrl1_down_COMPLETION_AT_4_lane0 = 1'b0;
    end
  end

  always @(*) begin
    execute_ctrl1_down_COMPLETION_AT_3_lane0 = _zz_execute_ctrl1_down_COMPLETION_AT_3_lane0[0];
    if(execute_ctrl1_down_TRAP_lane0) begin
      execute_ctrl1_down_COMPLETION_AT_3_lane0 = 1'b0;
    end
  end

  always @(*) begin
    execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0 = _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0_17[0];
    if(execute_ctrl1_down_TRAP_lane0) begin
      execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0 = 1'b0;
    end
  end

  always @(*) begin
    execute_ctrl1_down_lane0_logic_completions_onCtrl_1_ENABLE_lane0 = _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_1_ENABLE_lane0_5[0];
    if(execute_ctrl1_down_TRAP_lane0) begin
      execute_ctrl1_down_lane0_logic_completions_onCtrl_1_ENABLE_lane0 = 1'b0;
    end
  end

  always @(*) begin
    execute_ctrl1_down_lane0_logic_completions_onCtrl_2_ENABLE_lane0 = _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_2_ENABLE_lane0_3[0];
    if(execute_ctrl1_down_TRAP_lane0) begin
      execute_ctrl1_down_lane0_logic_completions_onCtrl_2_ENABLE_lane0 = 1'b0;
    end
  end

  assign _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_ADD_SUB_lane0 = ((execute_lane0_logic_decoding_decodingBits & 33'h000006000) == 33'h0);
  assign _zz_execute_ctrl1_down_late0_SrcPlugin_logic_SRC2_CTRL_lane0 = ((execute_lane0_logic_decoding_decodingBits & 33'h000000004) == 33'h000000004);
  assign execute_ctrl1_down_early0_IntAluPlugin_ALU_ADD_SUB_lane0 = _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_ADD_SUB_lane0[0];
  assign _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_SLTX_lane0 = ((execute_lane0_logic_decoding_decodingBits & 33'h000006004) == 33'h000002000);
  assign execute_ctrl1_down_early0_IntAluPlugin_ALU_SLTX_lane0 = _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_SLTX_lane0[0];
  assign _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0 = ((execute_lane0_logic_decoding_decodingBits & 33'h000003000) == 33'h000002000);
  assign _zz_execute_ctrl1_down_BarrelShifterPlugin_LEFT_lane0 = ((execute_lane0_logic_decoding_decodingBits & 33'h000004000) == 33'h0);
  assign _zz_execute_ctrl1_down_CsrAccessPlugin_CSR_CLEAR_lane0 = ((execute_lane0_logic_decoding_decodingBits & 33'h000001000) == 33'h000001000);
  assign _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_1 = {(|{_zz_execute_ctrl1_down_CsrAccessPlugin_CSR_CLEAR_lane0,_zz_execute_ctrl1_down_late0_SrcPlugin_logic_SRC2_CTRL_lane0,_zz_execute_ctrl1_down_BarrelShifterPlugin_LEFT_lane0}),(|{_zz_execute_ctrl1_down_late0_SrcPlugin_logic_SRC2_CTRL_lane0,_zz_execute_ctrl1_down_BarrelShifterPlugin_LEFT_lane0,_zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0})};
  assign _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0 = _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_1;
  assign _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_2 = _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0;
  assign execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0 = _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_2;
  assign execute_ctrl1_down_SrcStageables_REVERT_lane0 = _zz_execute_ctrl1_down_SrcStageables_REVERT_lane0[0];
  assign execute_ctrl1_down_SrcStageables_ZERO_lane0 = _zz_execute_ctrl1_down_SrcStageables_ZERO_lane0[0];
  assign execute_ctrl1_down_early0_SrcPlugin_logic_SRC1_CTRL_lane0 = (|((execute_lane0_logic_decoding_decodingBits & 33'h000000044) == 33'h000000004));
  assign _zz_execute_ctrl1_down_late0_SrcPlugin_logic_SRC2_CTRL_lane0_1 = ((execute_lane0_logic_decoding_decodingBits & 33'h000000024) == 33'h0);
  assign execute_ctrl1_down_early0_SrcPlugin_logic_SRC2_CTRL_lane0 = {(|{_zz_execute_ctrl1_down_late0_SrcPlugin_logic_SRC2_CTRL_lane0,((execute_lane0_logic_decoding_decodingBits & 33'h000000070) == 33'h000000020),((execute_lane0_logic_decoding_decodingBits & 33'h001d07fa0) == 33'h000106000)}),(|{((execute_lane0_logic_decoding_decodingBits & 33'h000000050) == 33'h0),_zz_execute_ctrl1_down_late0_SrcPlugin_logic_SRC2_CTRL_lane0_1})};
  assign execute_ctrl1_down_lane0_IntFormatPlugin_logic_SIGNED_lane0 = _zz_execute_ctrl1_down_lane0_IntFormatPlugin_logic_SIGNED_lane0[0];
  assign _zz_execute_ctrl1_down_CsrAccessPlugin_CSR_MASK_lane0 = ((execute_lane0_logic_decoding_decodingBits & 33'h000002000) == 33'h000002000);
  assign execute_ctrl1_down_lane0_IntFormatPlugin_logic_WIDTH_ID_lane0 = {(|{((execute_lane0_logic_decoding_decodingBits & 33'h000000010) == 33'h000000010),_zz_execute_ctrl1_down_CsrAccessPlugin_CSR_MASK_lane0}),(|((execute_lane0_logic_decoding_decodingBits & 33'h000001010) == 33'h000001000))};
  assign _zz_execute_ctrl1_down_BYPASSED_AT_3_lane0 = ((execute_lane0_logic_decoding_decodingBits & 33'h100000030) == 33'h100000010);
  assign _zz_execute_ctrl1_down_BYPASSED_AT_3_lane0_1 = ((execute_lane0_logic_decoding_decodingBits & 33'h100000004) == 33'h100000004);
  assign execute_ctrl1_down_BYPASSED_AT_2_lane0 = _zz_execute_ctrl1_down_BYPASSED_AT_2_lane0[0];
  assign execute_ctrl1_down_BYPASSED_AT_3_lane0 = _zz_execute_ctrl1_down_BYPASSED_AT_3_lane0_2[0];
  assign execute_ctrl1_down_MAY_FLUSH_PRECISE_3_lane0 = _zz_execute_ctrl1_down_MAY_FLUSH_PRECISE_3_lane0[0];
  assign execute_ctrl1_down_MAY_FLUSH_PRECISE_4_lane0 = _zz_execute_ctrl1_down_MAY_FLUSH_PRECISE_4_lane0[0];
  assign execute_ctrl1_down_SrcStageables_UNSIGNED_lane0 = _zz_execute_ctrl1_down_SrcStageables_UNSIGNED_lane0[0];
  assign execute_ctrl1_down_BarrelShifterPlugin_LEFT_lane0 = _zz_execute_ctrl1_down_BarrelShifterPlugin_LEFT_lane0_1[0];
  assign execute_ctrl1_down_BarrelShifterPlugin_SIGNED_lane0 = _zz_execute_ctrl1_down_BarrelShifterPlugin_SIGNED_lane0[0];
  assign _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_1 = {(|_zz_execute_ctrl1_down_lane0_integer_WriteBackPlugin_SEL_lane0),(|((execute_lane0_logic_decoding_decodingBits & 33'h000000008) == 33'h000000008))};
  assign _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0 = _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_1;
  assign _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_2 = _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0;
  assign execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0 = _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_2;
  assign execute_ctrl1_down_MulPlugin_HIGH_lane0 = _zz_execute_ctrl1_down_MulPlugin_HIGH_lane0[0];
  assign execute_ctrl1_down_RsUnsignedPlugin_RS1_SIGNED_lane0 = _zz_execute_ctrl1_down_RsUnsignedPlugin_RS1_SIGNED_lane0[0];
  assign execute_ctrl1_down_RsUnsignedPlugin_RS2_SIGNED_lane0 = _zz_execute_ctrl1_down_RsUnsignedPlugin_RS2_SIGNED_lane0[0];
  assign execute_ctrl1_down_DivPlugin_REM_lane0 = _zz_execute_ctrl1_down_DivPlugin_REM_lane0[0];
  assign execute_ctrl1_down_CsrAccessPlugin_CSR_IMM_lane0 = _zz_execute_ctrl1_down_CsrAccessPlugin_CSR_IMM_lane0[0];
  assign execute_ctrl1_down_CsrAccessPlugin_CSR_MASK_lane0 = _zz_execute_ctrl1_down_CsrAccessPlugin_CSR_MASK_lane0_1[0];
  assign execute_ctrl1_down_CsrAccessPlugin_CSR_CLEAR_lane0 = _zz_execute_ctrl1_down_CsrAccessPlugin_CSR_CLEAR_lane0_1[0];
  assign execute_ctrl1_down_AguPlugin_LOAD_lane0 = _zz_execute_ctrl1_down_AguPlugin_LOAD_lane0[0];
  assign execute_ctrl1_down_AguPlugin_STORE_lane0 = _zz_execute_ctrl1_down_AguPlugin_STORE_lane0[0];
  assign execute_ctrl1_down_AguPlugin_EXECUTE_lane0 = _zz_execute_ctrl1_down_AguPlugin_EXECUTE_lane0[0];
  assign execute_ctrl1_down_AguPlugin_ATOMIC_lane0 = _zz_execute_ctrl1_down_AguPlugin_ATOMIC_lane0[0];
  assign execute_ctrl1_down_AguPlugin_FLOAT_lane0 = _zz_execute_ctrl1_down_AguPlugin_FLOAT_lane0[0];
  assign execute_ctrl1_down_AguPlugin_CLEAN_lane0 = _zz_execute_ctrl1_down_AguPlugin_CLEAN_lane0[0];
  assign execute_ctrl1_down_AguPlugin_INVALIDATE_lane0 = _zz_execute_ctrl1_down_AguPlugin_INVALIDATE_lane0[0];
  assign execute_ctrl1_down_AguPlugin_GUEST_lane0 = _zz_execute_ctrl1_down_AguPlugin_GUEST_lane0[0];
  assign execute_ctrl1_down_LsuPlugin_logic_LSU_PREFETCH_lane0 = _zz_execute_ctrl1_down_LsuPlugin_logic_LSU_PREFETCH_lane0[0];
  assign _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0 = ((execute_lane0_logic_decoding_decodingBits & 33'h000000040) == 33'h0);
  assign _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_2 = {(|((execute_lane0_logic_decoding_decodingBits & 33'h030001000) == 33'h010000000)),(|{((execute_lane0_logic_decoding_decodingBits & 33'h020000000) == 33'h020000000),_zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0}),(|{((execute_lane0_logic_decoding_decodingBits & 33'h000100000) == 33'h000100000),_zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0})};
  assign _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_1 = _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_2;
  assign _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_3 = _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_1;
  assign execute_ctrl1_down_early0_EnvPlugin_OP_lane0 = _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_3;
  assign execute_ctrl1_down_late0_IntAluPlugin_ALU_ADD_SUB_lane0 = _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_ADD_SUB_lane0_1[0];
  assign execute_ctrl1_down_late0_IntAluPlugin_ALU_SLTX_lane0 = _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_SLTX_lane0_1[0];
  assign _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_2 = {(|{_zz_execute_ctrl1_down_CsrAccessPlugin_CSR_CLEAR_lane0,_zz_execute_ctrl1_down_late0_SrcPlugin_logic_SRC2_CTRL_lane0,_zz_execute_ctrl1_down_BarrelShifterPlugin_LEFT_lane0}),(|{_zz_execute_ctrl1_down_late0_SrcPlugin_logic_SRC2_CTRL_lane0,_zz_execute_ctrl1_down_BarrelShifterPlugin_LEFT_lane0,_zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0})};
  assign _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_1 = _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_2;
  assign _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_3 = _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_1;
  assign execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0 = _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_3;
  assign execute_ctrl1_down_late0_SrcPlugin_logic_SRC1_CTRL_lane0 = (|_zz_execute_ctrl1_down_late0_SrcPlugin_logic_SRC2_CTRL_lane0);
  assign execute_ctrl1_down_late0_SrcPlugin_logic_SRC2_CTRL_lane0 = {(|_zz_execute_ctrl1_down_late0_SrcPlugin_logic_SRC2_CTRL_lane0),(|_zz_execute_ctrl1_down_late0_SrcPlugin_logic_SRC2_CTRL_lane0_1)};
  assign when_ExecuteLanePlugin_l306 = (|{(late1_BranchPlugin_logic_flushPort_valid && 1'b1),(early1_BranchPlugin_logic_flushPort_valid && 1'b1),(late0_BranchPlugin_logic_flushPort_valid && 1'b1),(early0_EnvPlugin_logic_flushPort_valid && 1'b1),(CsrAccessPlugin_logic_flushPort_valid && 1'b1),(early0_BranchPlugin_logic_flushPort_valid && 1'b1),(LsuPlugin_logic_flushPort_valid && 1'b1)});
  assign execute_lane0_ctrls_0_downIsCancel = 1'b0;
  assign execute_lane0_ctrls_0_upIsCancel = when_ExecuteLanePlugin_l306;
  assign when_ExecuteLanePlugin_l306_1 = (|{(late1_BranchPlugin_logic_flushPort_valid && 1'b1),(early1_BranchPlugin_logic_flushPort_valid && 1'b1),(late0_BranchPlugin_logic_flushPort_valid && 1'b1),(early0_EnvPlugin_logic_flushPort_valid && 1'b1),(CsrAccessPlugin_logic_flushPort_valid && 1'b1),(early0_BranchPlugin_logic_flushPort_valid && 1'b1),(LsuPlugin_logic_flushPort_valid && 1'b1)});
  assign execute_lane0_ctrls_1_downIsCancel = 1'b0;
  assign execute_lane0_ctrls_1_upIsCancel = when_ExecuteLanePlugin_l306_1;
  assign when_ExecuteLanePlugin_l306_2 = (|{(late1_BranchPlugin_logic_flushPort_valid && 1'b1),((early1_BranchPlugin_logic_flushPort_valid && 1'b1) && ((early1_BranchPlugin_logic_flushPort_payload_laneAge < execute_ctrl2_down_LANE_AGE_lane0) || (_zz_when_ExecuteLanePlugin_l306_2 && early1_BranchPlugin_logic_flushPort_payload_self))),(late0_BranchPlugin_logic_flushPort_valid && 1'b1),(_zz_when_ExecuteLanePlugin_l306_2_1 && _zz_when_ExecuteLanePlugin_l306_2_2),_zz_when_ExecuteLanePlugin_l306_2_3,_zz_when_ExecuteLanePlugin_l306_2_4,_zz_when_ExecuteLanePlugin_l306_2_5});
  assign execute_lane0_ctrls_2_downIsCancel = 1'b0;
  assign execute_lane0_ctrls_2_upIsCancel = when_ExecuteLanePlugin_l306_2;
  assign when_ExecuteLanePlugin_l306_3 = (|{(late1_BranchPlugin_logic_flushPort_valid && 1'b1),(late0_BranchPlugin_logic_flushPort_valid && 1'b1),(LsuPlugin_logic_flushPort_valid && 1'b1)});
  assign execute_lane0_ctrls_3_downIsCancel = 1'b0;
  assign execute_lane0_ctrls_3_upIsCancel = when_ExecuteLanePlugin_l306_3;
  assign when_ExecuteLanePlugin_l306_4 = (|{((late1_BranchPlugin_logic_flushPort_valid && 1'b1) && ((late1_BranchPlugin_logic_flushPort_payload_laneAge < execute_ctrl4_down_LANE_AGE_lane0) || ((late1_BranchPlugin_logic_flushPort_payload_laneAge == execute_ctrl4_down_LANE_AGE_lane0) && late1_BranchPlugin_logic_flushPort_payload_self))),((late0_BranchPlugin_logic_flushPort_valid && 1'b1) && ((late0_BranchPlugin_logic_flushPort_payload_laneAge < execute_ctrl4_down_LANE_AGE_lane0) || (_zz_when_ExecuteLanePlugin_l306_4 && late0_BranchPlugin_logic_flushPort_payload_self))),((LsuPlugin_logic_flushPort_valid && 1'b1) && ((LsuPlugin_logic_flushPort_payload_laneAge < execute_ctrl4_down_LANE_AGE_lane0) || (_zz_when_ExecuteLanePlugin_l306_4_1 && LsuPlugin_logic_flushPort_payload_self)))});
  assign execute_lane0_ctrls_4_downIsCancel = 1'b0;
  assign execute_lane0_ctrls_4_upIsCancel = when_ExecuteLanePlugin_l306_4;
  assign execute_lane0_ctrls_5_downIsCancel = 1'b0;
  assign execute_lane0_ctrls_5_upIsCancel = 1'b0;
  assign execute_lane0_logic_trapPending[0] = (|{((execute_ctrl4_up_LANE_SEL_lane0 && 1'b1) && execute_ctrl4_down_TRAP_lane0),((execute_ctrl3_up_LANE_SEL_lane0 && 1'b1) && execute_ctrl3_down_TRAP_lane0),((execute_ctrl2_up_LANE_SEL_lane0 && 1'b1) && execute_ctrl2_down_TRAP_lane0),((execute_ctrl1_up_LANE_SEL_lane0 && 1'b1) && execute_ctrl1_down_TRAP_lane0)});
  assign execute_ctrl2_up_COMMIT_lane0 = (! execute_ctrl2_up_TRAP_lane0);
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_REFILL = 1'b0;
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_HAZARD = 1'b0;
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_TRANSLATED = fetch_logic_ctrls_1_down_Fetch_WORD_PC;
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_PAGE_FAULT = 1'b0;
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_ACCESS_FAULT = 1'b0;
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_ADDRESS_EXTENSION = 1'b0;
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_BYPASS_TRANSLATION = 1'b1;
  assign execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_REFILL_lane0 = 1'b0;
  assign execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_HAZARD_lane0 = 1'b0;
  assign execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_TRANSLATED_lane0 = execute_ctrl3_down_LsuL1_MIXED_ADDRESS_lane0;
  assign execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_PAGE_FAULT_lane0 = 1'b0;
  assign execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_ACCESS_FAULT_lane0 = 1'b0;
  assign execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_ADDRESS_EXTENSION_lane0 = 1'b0;
  assign execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_BYPASS_TRANSLATION_lane0 = 1'b1;
  assign fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress1_translationPort_keys_REFILL = 1'b0;
  assign fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress1_translationPort_keys_HAZARD = 1'b0;
  assign fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress1_translationPort_keys_TRANSLATED = _zz_fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress1_translationPort_keys_TRANSLATED;
  assign fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress1_translationPort_keys_PAGE_FAULT = 1'b0;
  assign fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress1_translationPort_keys_ACCESS_FAULT = 1'b0;
  assign fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress1_translationPort_keys_ADDRESS_EXTENSION = 1'b0;
  assign fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress1_translationPort_keys_BYPASS_TRANSLATION = 1'b1;
  assign execute_ctrl4_down_LsuPlugin_logic_onAddress1_translationPort_keys_REFILL_lane0 = 1'b0;
  assign execute_ctrl4_down_LsuPlugin_logic_onAddress1_translationPort_keys_HAZARD_lane0 = 1'b0;
  assign execute_ctrl4_down_LsuPlugin_logic_onAddress1_translationPort_keys_TRANSLATED_lane0 = _zz_execute_ctrl4_down_LsuPlugin_logic_onAddress1_translationPort_keys_TRANSLATED_lane0;
  assign execute_ctrl4_down_LsuPlugin_logic_onAddress1_translationPort_keys_PAGE_FAULT_lane0 = 1'b0;
  assign execute_ctrl4_down_LsuPlugin_logic_onAddress1_translationPort_keys_ACCESS_FAULT_lane0 = 1'b0;
  assign execute_ctrl4_down_LsuPlugin_logic_onAddress1_translationPort_keys_ADDRESS_EXTENSION_lane0 = 1'b0;
  assign execute_ctrl4_down_LsuPlugin_logic_onAddress1_translationPort_keys_BYPASS_TRANSLATION_lane0 = 1'b1;
  assign PmpPlugin_logic_isMachine = ($signed(PrivilegedPlugin_logic_harts_0_privilege) == $signed(3'b011));
  assign PmpPlugin_logic_instructionShouldHit = (! PmpPlugin_logic_isMachine);
  assign PmpPlugin_logic_dataShouldHit = ((! PmpPlugin_logic_isMachine) || (PrivilegedPlugin_logic_harts_0_m_status_mprv && (PrivilegedPlugin_logic_harts_0_m_status_mpp != 2'b11)));
  assign FetchL1Plugin_logic_pmpPort_logic_dataShouldHitPort = (PmpPlugin_logic_dataShouldHit || 1'b0);
  assign FetchL1Plugin_logic_pmpPort_logic_torCmpAddress = (fetch_logic_ctrls_1_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_TRANSLATED >>> 4'd12);
  assign fetch_logic_ctrls_0_down_FetchL1Plugin_logic_pmpPort_logic_NEED_HIT = ((PmpPlugin_logic_instructionShouldHit && 1'b1) || (FetchL1Plugin_logic_pmpPort_logic_dataShouldHitPort && (1'b0 || 1'b0)));
  assign fetch_logic_ctrls_2_down_FetchL1Plugin_logic_pmpPort_ACCESS_FAULT = 1'b0;
  assign LsuPlugin_logic_pmpPort_logic_dataShouldHitPort = (PmpPlugin_logic_dataShouldHit || execute_ctrl2_down_LsuPlugin_logic_FROM_ACCESS_lane0);
  assign LsuPlugin_logic_pmpPort_logic_torCmpAddress = (execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_TRANSLATED_lane0 >>> 4'd12);
  assign execute_ctrl2_down_LsuPlugin_logic_pmpPort_logic_NEED_HIT_lane0 = ((PmpPlugin_logic_instructionShouldHit && (execute_ctrl2_down_LsuL1_EXECUTE_lane0 && execute_ctrl2_down_LsuL1_GUEST_lane0)) || (LsuPlugin_logic_pmpPort_logic_dataShouldHitPort && ((execute_ctrl2_down_LsuL1_LOAD_lane0 || (execute_ctrl2_down_LsuL1_EXECUTE_lane0 && execute_ctrl2_down_LsuL1_GUEST_lane0)) || execute_ctrl2_down_LsuL1_STORE_lane0)));
  assign execute_ctrl4_down_LsuPlugin_logic_pmpPort_ACCESS_FAULT_lane0 = 1'b0;
  assign LsuPlugin_logic_commitProbe_takeWhen_valid = (LsuPlugin_logic_commitProbe_valid && (! LsuPlugin_logic_commitProbe_payload_io));
  assign LsuPlugin_logic_commitProbe_takeWhen_payload_pc = LsuPlugin_logic_commitProbe_payload_pc;
  assign LsuPlugin_logic_commitProbe_takeWhen_payload_address = LsuPlugin_logic_commitProbe_payload_address;
  assign LsuPlugin_logic_commitProbe_takeWhen_payload_load = LsuPlugin_logic_commitProbe_payload_load;
  assign LsuPlugin_logic_commitProbe_takeWhen_payload_store = LsuPlugin_logic_commitProbe_payload_store;
  assign LsuPlugin_logic_commitProbe_takeWhen_payload_trap = LsuPlugin_logic_commitProbe_payload_trap;
  assign LsuPlugin_logic_commitProbe_takeWhen_payload_io = LsuPlugin_logic_commitProbe_payload_io;
  assign LsuPlugin_logic_commitProbe_takeWhen_payload_prefetchFailed = LsuPlugin_logic_commitProbe_payload_prefetchFailed;
  assign LsuPlugin_logic_commitProbe_takeWhen_payload_miss = LsuPlugin_logic_commitProbe_payload_miss;
  assign PrefetcherRptPlugin_logic_pip_node_0_valid = LsuPlugin_logic_commitProbe_takeWhen_valid;
  assign PrefetcherRptPlugin_logic_pip_node_0_PROBE_pc = LsuPlugin_logic_commitProbe_payload_pc;
  assign PrefetcherRptPlugin_logic_pip_node_0_PROBE_address = LsuPlugin_logic_commitProbe_payload_address;
  assign PrefetcherRptPlugin_logic_pip_node_0_PROBE_load = LsuPlugin_logic_commitProbe_payload_load;
  assign PrefetcherRptPlugin_logic_pip_node_0_PROBE_store = LsuPlugin_logic_commitProbe_payload_store;
  assign PrefetcherRptPlugin_logic_pip_node_0_PROBE_trap = LsuPlugin_logic_commitProbe_payload_trap;
  assign PrefetcherRptPlugin_logic_pip_node_0_PROBE_io = LsuPlugin_logic_commitProbe_payload_io;
  assign PrefetcherRptPlugin_logic_pip_node_0_PROBE_prefetchFailed = LsuPlugin_logic_commitProbe_payload_prefetchFailed;
  assign PrefetcherRptPlugin_logic_pip_node_0_PROBE_miss = LsuPlugin_logic_commitProbe_payload_miss;
  assign PrefetcherRptPlugin_logic_storage_read_cmd_valid = PrefetcherRptPlugin_logic_pip_node_0_isFiring;
  assign PrefetcherRptPlugin_logic_storage_read_cmd_payload = PrefetcherRptPlugin_logic_pip_node_0_PROBE_pc[7 : 1];
  assign PrefetcherRptPlugin_logic_pip_node_0_onRead0_WRITTEN_valid = PrefetcherRptPlugin_logic_storage_write_valid;
  assign PrefetcherRptPlugin_logic_pip_node_0_onRead0_WRITTEN_payload_address = PrefetcherRptPlugin_logic_storage_write_payload_address;
  assign PrefetcherRptPlugin_logic_pip_node_0_onRead0_WRITTEN_payload_data_tag = PrefetcherRptPlugin_logic_storage_write_payload_data_tag;
  assign PrefetcherRptPlugin_logic_pip_node_0_onRead0_WRITTEN_payload_data_address = PrefetcherRptPlugin_logic_storage_write_payload_data_address;
  assign PrefetcherRptPlugin_logic_pip_node_0_onRead0_WRITTEN_payload_data_stride = PrefetcherRptPlugin_logic_storage_write_payload_data_stride;
  assign PrefetcherRptPlugin_logic_pip_node_0_onRead0_WRITTEN_payload_data_score = PrefetcherRptPlugin_logic_storage_write_payload_data_score;
  assign PrefetcherRptPlugin_logic_pip_node_0_onRead0_WRITTEN_payload_data_advance = PrefetcherRptPlugin_logic_storage_write_payload_data_advance;
  assign PrefetcherRptPlugin_logic_pip_node_0_onRead0_WRITTEN_payload_data_missed = PrefetcherRptPlugin_logic_storage_write_payload_data_missed;
  always @(*) begin
    PrefetcherRptPlugin_logic_pip_node_1_ENTRY_tag = PrefetcherRptPlugin_logic_storage_read_rsp_tag;
    if(when_Prefetcher_l160) begin
      PrefetcherRptPlugin_logic_pip_node_1_ENTRY_tag = PrefetcherRptPlugin_logic_pip_node_1_onRead0_WRITTEN_payload_data_tag;
    end
  end

  always @(*) begin
    PrefetcherRptPlugin_logic_pip_node_1_ENTRY_address = PrefetcherRptPlugin_logic_storage_read_rsp_address;
    if(when_Prefetcher_l160) begin
      PrefetcherRptPlugin_logic_pip_node_1_ENTRY_address = PrefetcherRptPlugin_logic_pip_node_1_onRead0_WRITTEN_payload_data_address;
    end
  end

  always @(*) begin
    PrefetcherRptPlugin_logic_pip_node_1_ENTRY_stride = PrefetcherRptPlugin_logic_storage_read_rsp_stride;
    if(when_Prefetcher_l160) begin
      PrefetcherRptPlugin_logic_pip_node_1_ENTRY_stride = PrefetcherRptPlugin_logic_pip_node_1_onRead0_WRITTEN_payload_data_stride;
    end
  end

  always @(*) begin
    PrefetcherRptPlugin_logic_pip_node_1_ENTRY_score = PrefetcherRptPlugin_logic_storage_read_rsp_score;
    if(when_Prefetcher_l160) begin
      PrefetcherRptPlugin_logic_pip_node_1_ENTRY_score = PrefetcherRptPlugin_logic_pip_node_1_onRead0_WRITTEN_payload_data_score;
    end
  end

  always @(*) begin
    PrefetcherRptPlugin_logic_pip_node_1_ENTRY_advance = PrefetcherRptPlugin_logic_storage_read_rsp_advance;
    if(when_Prefetcher_l160) begin
      PrefetcherRptPlugin_logic_pip_node_1_ENTRY_advance = PrefetcherRptPlugin_logic_pip_node_1_onRead0_WRITTEN_payload_data_advance;
    end
  end

  always @(*) begin
    PrefetcherRptPlugin_logic_pip_node_1_ENTRY_missed = PrefetcherRptPlugin_logic_storage_read_rsp_missed;
    if(when_Prefetcher_l160) begin
      PrefetcherRptPlugin_logic_pip_node_1_ENTRY_missed = PrefetcherRptPlugin_logic_pip_node_1_onRead0_WRITTEN_payload_data_missed;
    end
  end

  assign when_Prefetcher_l160 = (PrefetcherRptPlugin_logic_pip_node_1_onRead0_WRITTEN_valid && (PrefetcherRptPlugin_logic_pip_node_1_onRead0_WRITTEN_payload_address == PrefetcherRptPlugin_logic_pip_node_1_PROBE_pc[7 : 1]));
  assign PrefetcherRptPlugin_logic_pip_node_1_TAG_HIT = (PrefetcherRptPlugin_logic_pip_node_1_ENTRY_tag == PrefetcherRptPlugin_logic_pip_node_1_PROBE_pc[22 : 8]);
  assign PrefetcherRptPlugin_logic_pip_node_1_STRIDE_EXTENDED = _zz_PrefetcherRptPlugin_logic_pip_node_1_STRIDE_EXTENDED[15:0];
  assign PrefetcherRptPlugin_logic_pip_node_1_NEW_BLOCK = (_zz_PrefetcherRptPlugin_logic_pip_node_1_NEW_BLOCK != 10'h0);
  assign _zz_PrefetcherRptPlugin_logic_pip_node_2_STRIDE_HIT = _zz__zz_PrefetcherRptPlugin_logic_pip_node_2_STRIDE_HIT;
  assign PrefetcherRptPlugin_logic_pip_node_2_STRIDE_HIT = (($signed(_zz_PrefetcherRptPlugin_logic_pip_node_2_STRIDE_HIT_1) == $signed(PrefetcherRptPlugin_logic_pip_node_2_ENTRY_stride)) && (&{(_zz_PrefetcherRptPlugin_logic_pip_node_2_STRIDE_HIT[3] == PrefetcherRptPlugin_logic_pip_node_2_ENTRY_stride[11]),(_zz_PrefetcherRptPlugin_logic_pip_node_2_STRIDE_HIT[2] == PrefetcherRptPlugin_logic_pip_node_2_ENTRY_stride[11]),(_zz_PrefetcherRptPlugin_logic_pip_node_2_STRIDE_HIT[1] == PrefetcherRptPlugin_logic_pip_node_2_ENTRY_stride[11]),(_zz_PrefetcherRptPlugin_logic_pip_node_2_STRIDE_HIT[0] == PrefetcherRptPlugin_logic_pip_node_2_ENTRY_stride[11])}));
  assign PrefetcherRptPlugin_logic_pip_node_2_STRIDE = PrefetcherRptPlugin_logic_pip_node_2_STRIDE_EXTENDED[11:0];
  assign PrefetcherRptPlugin_logic_order_fire = (PrefetcherRptPlugin_logic_order_valid && PrefetcherRptPlugin_logic_order_ready);
  assign PrefetcherRptPlugin_logic_order_toFlowFire_valid = PrefetcherRptPlugin_logic_order_fire;
  assign PrefetcherRptPlugin_logic_order_toFlowFire_payload_address = PrefetcherRptPlugin_logic_order_payload_address;
  assign PrefetcherRptPlugin_logic_order_toFlowFire_payload_unique = PrefetcherRptPlugin_logic_order_payload_unique;
  assign PrefetcherRptPlugin_logic_order_toFlowFire_payload_from = PrefetcherRptPlugin_logic_order_payload_from;
  assign PrefetcherRptPlugin_logic_order_toFlowFire_payload_to = PrefetcherRptPlugin_logic_order_payload_to;
  assign PrefetcherRptPlugin_logic_order_toFlowFire_payload_stride = PrefetcherRptPlugin_logic_order_payload_stride;
  assign when_Stream_l581 = (((((PrefetcherRptPlugin_logic_onCtrl_lastOrder_address[31 : 6] == PrefetcherRptPlugin_logic_order_payload_address[31 : 6]) && PrefetcherRptPlugin_logic_onCtrl_lastOrder_unique) && PrefetcherRptPlugin_logic_order_payload_unique) && (PrefetcherRptPlugin_logic_onCtrl_lastOrder_from == PrefetcherRptPlugin_logic_order_payload_from)) && (PrefetcherRptPlugin_logic_onCtrl_lastOrder_to == PrefetcherRptPlugin_logic_order_payload_to));
  always @(*) begin
    PrefetcherRptPlugin_logic_onCtrl_unfiltred_throwWhen_valid = PrefetcherRptPlugin_logic_onCtrl_unfiltred_valid;
    if(when_Stream_l581) begin
      PrefetcherRptPlugin_logic_onCtrl_unfiltred_throwWhen_valid = 1'b0;
    end
  end

  always @(*) begin
    PrefetcherRptPlugin_logic_onCtrl_unfiltred_ready = PrefetcherRptPlugin_logic_onCtrl_unfiltred_throwWhen_ready;
    if(when_Stream_l581) begin
      PrefetcherRptPlugin_logic_onCtrl_unfiltred_ready = 1'b1;
    end
  end

  assign PrefetcherRptPlugin_logic_onCtrl_unfiltred_throwWhen_payload_address = PrefetcherRptPlugin_logic_onCtrl_unfiltred_payload_address;
  assign PrefetcherRptPlugin_logic_onCtrl_unfiltred_throwWhen_payload_unique = PrefetcherRptPlugin_logic_onCtrl_unfiltred_payload_unique;
  assign PrefetcherRptPlugin_logic_onCtrl_unfiltred_throwWhen_payload_from = PrefetcherRptPlugin_logic_onCtrl_unfiltred_payload_from;
  assign PrefetcherRptPlugin_logic_onCtrl_unfiltred_throwWhen_payload_to = PrefetcherRptPlugin_logic_onCtrl_unfiltred_payload_to;
  assign PrefetcherRptPlugin_logic_onCtrl_unfiltred_throwWhen_payload_stride = PrefetcherRptPlugin_logic_onCtrl_unfiltred_payload_stride;
  always @(*) begin
    PrefetcherRptPlugin_logic_order_valid = PrefetcherRptPlugin_logic_onCtrl_unfiltred_throwWhen_valid;
    if(PrefetcherRptPlugin_logic_csr_disable) begin
      PrefetcherRptPlugin_logic_order_valid = 1'b0;
    end
  end

  assign PrefetcherRptPlugin_logic_onCtrl_unfiltred_throwWhen_ready = PrefetcherRptPlugin_logic_order_ready;
  assign PrefetcherRptPlugin_logic_order_payload_address = PrefetcherRptPlugin_logic_onCtrl_unfiltred_throwWhen_payload_address;
  assign PrefetcherRptPlugin_logic_order_payload_unique = PrefetcherRptPlugin_logic_onCtrl_unfiltred_throwWhen_payload_unique;
  assign PrefetcherRptPlugin_logic_order_payload_from = PrefetcherRptPlugin_logic_onCtrl_unfiltred_throwWhen_payload_from;
  assign PrefetcherRptPlugin_logic_order_payload_to = PrefetcherRptPlugin_logic_onCtrl_unfiltred_throwWhen_payload_to;
  assign PrefetcherRptPlugin_logic_order_payload_stride = PrefetcherRptPlugin_logic_onCtrl_unfiltred_throwWhen_payload_stride;
  always @(*) begin
    PrefetcherRptPlugin_logic_onCtrl_add = 5'h0;
    if(!when_Prefetcher_l203) begin
      if(!when_Prefetcher_l215) begin
        if(PrefetcherRptPlugin_logic_pip_node_2_NEW_BLOCK) begin
          PrefetcherRptPlugin_logic_onCtrl_add = 5'h01;
        end
      end
    end
  end

  always @(*) begin
    PrefetcherRptPlugin_logic_onCtrl_sub = 5'h0;
    if(when_Prefetcher_l203) begin
      if(when_Prefetcher_l204) begin
        if(when_Prefetcher_l205) begin
          PrefetcherRptPlugin_logic_onCtrl_sub = 5'h02;
        end
      end
    end else begin
      if(when_Prefetcher_l215) begin
        PrefetcherRptPlugin_logic_onCtrl_sub = (PrefetcherRptPlugin_logic_pip_node_2_ENTRY_score >>> 1);
      end
    end
  end

  assign _zz_when_UInt_l128 = ({1'b0,PrefetcherRptPlugin_logic_pip_node_2_ENTRY_score} - {1'b0,PrefetcherRptPlugin_logic_onCtrl_sub});
  assign when_UInt_l128 = _zz_when_UInt_l128[5];
  always @(*) begin
    if(when_UInt_l128) begin
      _zz_PrefetcherRptPlugin_logic_onCtrl_score = 5'h0;
    end else begin
      _zz_PrefetcherRptPlugin_logic_onCtrl_score = _zz_when_UInt_l128[4 : 0];
    end
  end

  assign _zz_PrefetcherRptPlugin_logic_onCtrl_score_1 = ({1'b0,_zz_PrefetcherRptPlugin_logic_onCtrl_score} + {1'b0,PrefetcherRptPlugin_logic_onCtrl_add});
  assign when_UInt_l119 = (|_zz_PrefetcherRptPlugin_logic_onCtrl_score_1[5 : 5]);
  always @(*) begin
    if(when_UInt_l119) begin
      PrefetcherRptPlugin_logic_onCtrl_score = 5'h1f;
    end else begin
      PrefetcherRptPlugin_logic_onCtrl_score = _zz_PrefetcherRptPlugin_logic_onCtrl_score_1[4 : 0];
    end
  end

  assign _zz_PrefetcherRptPlugin_logic_onCtrl_advanceSubed = ({1'b0,((! PrefetcherRptPlugin_logic_pip_node_2_PROBE_miss) ? PrefetcherRptPlugin_logic_pip_node_2_ENTRY_advance : 3'b000)} - _zz__zz_PrefetcherRptPlugin_logic_onCtrl_advanceSubed);
  assign when_UInt_l128_1 = _zz_PrefetcherRptPlugin_logic_onCtrl_advanceSubed[3];
  always @(*) begin
    if(when_UInt_l128_1) begin
      PrefetcherRptPlugin_logic_onCtrl_advanceSubed = 3'b000;
    end else begin
      PrefetcherRptPlugin_logic_onCtrl_advanceSubed = _zz_PrefetcherRptPlugin_logic_onCtrl_advanceSubed[2 : 0];
    end
    if(!when_Prefetcher_l203) begin
      if(when_Prefetcher_l215) begin
        PrefetcherRptPlugin_logic_onCtrl_advanceSubed = 3'b000;
      end
    end
  end

  assign _zz_when_UInt_l128_1 = ({1'b0,PrefetcherRptPlugin_logic_pip_node_2_ENTRY_score} - _zz__zz_when_UInt_l128_1);
  assign when_UInt_l128_2 = _zz_when_UInt_l128_1[5];
  always @(*) begin
    if(when_UInt_l128_2) begin
      _zz_PrefetcherRptPlugin_logic_onCtrl_advanceAllowed = 5'h0;
    end else begin
      _zz_PrefetcherRptPlugin_logic_onCtrl_advanceAllowed = _zz_when_UInt_l128_1[4 : 0];
    end
  end

  assign PrefetcherRptPlugin_logic_onCtrl_advanceAllowed = _zz_PrefetcherRptPlugin_logic_onCtrl_advanceAllowed;
  always @(*) begin
    PrefetcherRptPlugin_logic_onCtrl_orderAsk = 1'b0;
    if(!when_Prefetcher_l203) begin
      if(when_Prefetcher_l223) begin
        PrefetcherRptPlugin_logic_onCtrl_orderAsk = 1'b1;
      end
    end
  end

  always @(*) begin
    PrefetcherRptPlugin_logic_storage_write_valid = (PrefetcherRptPlugin_logic_pip_node_2_isFiring && (! PrefetcherRptPlugin_logic_pip_node_2_PROBE_prefetchFailed));
    if(PrefetcherRptPlugin_logic_csr_disable) begin
      PrefetcherRptPlugin_logic_storage_write_valid = 1'b0;
    end
    if(PrefetcherRptPlugin_logic_initializer_busy) begin
      PrefetcherRptPlugin_logic_storage_write_valid = 1'b1;
    end
  end

  always @(*) begin
    PrefetcherRptPlugin_logic_storage_write_payload_address = PrefetcherRptPlugin_logic_pip_node_2_PROBE_pc[7 : 1];
    if(PrefetcherRptPlugin_logic_initializer_busy) begin
      PrefetcherRptPlugin_logic_storage_write_payload_address = PrefetcherRptPlugin_logic_initializer_counter[6:0];
    end
  end

