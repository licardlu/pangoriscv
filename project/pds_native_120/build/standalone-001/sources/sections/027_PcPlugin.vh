  always @(*) begin
    BtbPlugin_logic_ras_ptr_pop_aheadValue = BtbPlugin_logic_ras_ptr_pop;
    BtbPlugin_logic_ras_ptr_pop_aheadValue = (_zz_BtbPlugin_logic_ras_ptr_pop_aheadValue - _zz_BtbPlugin_logic_ras_ptr_pop_aheadValue_3);
  end

  assign execute_ctrl4_down_RD_ENABLE_lane1 = execute_ctrl4_RD_ENABLE_lane1_bypass;
  always @(*) begin
    execute_ctrl4_RD_ENABLE_lane1_bypass = execute_ctrl4_up_RD_ENABLE_lane1;
    if(when_ExecuteLanePlugin_l306_9) begin
      execute_ctrl4_RD_ENABLE_lane1_bypass = 1'b0;
    end
  end

  assign execute_ctrl4_down_LANE_SEL_lane1 = execute_ctrl4_LANE_SEL_lane1_bypass;
  always @(*) begin
    execute_ctrl4_LANE_SEL_lane1_bypass = execute_ctrl4_up_LANE_SEL_lane1;
    if(when_ExecuteLanePlugin_l306_9) begin
      execute_ctrl4_LANE_SEL_lane1_bypass = 1'b0;
    end
  end

  assign execute_ctrl3_down_RD_ENABLE_lane1 = execute_ctrl3_RD_ENABLE_lane1_bypass;
  always @(*) begin
    execute_ctrl3_RD_ENABLE_lane1_bypass = execute_ctrl3_up_RD_ENABLE_lane1;
    if(when_ExecuteLanePlugin_l306_8) begin
      execute_ctrl3_RD_ENABLE_lane1_bypass = 1'b0;
    end
  end

  assign execute_ctrl3_down_LANE_SEL_lane1 = execute_ctrl3_LANE_SEL_lane1_bypass;
  always @(*) begin
    execute_ctrl3_LANE_SEL_lane1_bypass = execute_ctrl3_up_LANE_SEL_lane1;
    if(when_ExecuteLanePlugin_l306_8) begin
      execute_ctrl3_LANE_SEL_lane1_bypass = 1'b0;
    end
  end

  assign execute_ctrl2_down_RD_ENABLE_lane1 = execute_ctrl2_RD_ENABLE_lane1_bypass;
  always @(*) begin
    execute_ctrl2_RD_ENABLE_lane1_bypass = execute_ctrl2_up_RD_ENABLE_lane1;
    if(when_ExecuteLanePlugin_l306_7) begin
      execute_ctrl2_RD_ENABLE_lane1_bypass = 1'b0;
    end
  end

  assign execute_ctrl2_down_LANE_SEL_lane1 = execute_ctrl2_LANE_SEL_lane1_bypass;
  always @(*) begin
    execute_ctrl2_LANE_SEL_lane1_bypass = execute_ctrl2_up_LANE_SEL_lane1;
    if(when_ExecuteLanePlugin_l306_7) begin
      execute_ctrl2_LANE_SEL_lane1_bypass = 1'b0;
    end
  end

  assign execute_ctrl1_down_RD_ENABLE_lane1 = execute_ctrl1_RD_ENABLE_lane1_bypass;
  always @(*) begin
    execute_ctrl1_RD_ENABLE_lane1_bypass = execute_ctrl1_up_RD_ENABLE_lane1;
    if(when_ExecuteLanePlugin_l306_6) begin
      execute_ctrl1_RD_ENABLE_lane1_bypass = 1'b0;
    end
  end

  assign execute_ctrl1_down_LANE_SEL_lane1 = execute_ctrl1_LANE_SEL_lane1_bypass;
  always @(*) begin
    execute_ctrl1_LANE_SEL_lane1_bypass = execute_ctrl1_up_LANE_SEL_lane1;
    if(when_ExecuteLanePlugin_l306_6) begin
      execute_ctrl1_LANE_SEL_lane1_bypass = 1'b0;
    end
  end

  assign execute_ctrl0_down_RD_ENABLE_lane1 = execute_ctrl0_RD_ENABLE_lane1_bypass;
  always @(*) begin
    execute_ctrl0_RD_ENABLE_lane1_bypass = execute_ctrl0_up_RD_ENABLE_lane1;
    if(when_ExecuteLanePlugin_l306_5) begin
      execute_ctrl0_RD_ENABLE_lane1_bypass = 1'b0;
    end
  end

  assign execute_ctrl0_down_LANE_SEL_lane1 = execute_ctrl0_LANE_SEL_lane1_bypass;
  always @(*) begin
    execute_ctrl0_LANE_SEL_lane1_bypass = execute_ctrl0_up_LANE_SEL_lane1;
    if(when_ExecuteLanePlugin_l306_5) begin
      execute_ctrl0_LANE_SEL_lane1_bypass = 1'b0;
    end
  end

  assign execute_ctrl3_down_integer_RS2_lane1 = execute_ctrl3_integer_RS2_lane1_bypass;
  assign execute_ctrl2_down_integer_RS2_lane1 = execute_ctrl2_integer_RS2_lane1_bypass;
  assign execute_ctrl3_down_integer_RS1_lane1 = execute_ctrl3_integer_RS1_lane1_bypass;
  assign execute_ctrl2_down_integer_RS1_lane1 = execute_ctrl2_integer_RS1_lane1_bypass;
  assign execute_ctrl4_down_RD_ENABLE_lane0 = execute_ctrl4_RD_ENABLE_lane0_bypass;
  always @(*) begin
    execute_ctrl4_RD_ENABLE_lane0_bypass = execute_ctrl4_up_RD_ENABLE_lane0;
    if(when_ExecuteLanePlugin_l306_4) begin
      execute_ctrl4_RD_ENABLE_lane0_bypass = 1'b0;
    end
  end

  assign execute_ctrl4_down_LANE_SEL_lane0 = execute_ctrl4_LANE_SEL_lane0_bypass;
  always @(*) begin
    execute_ctrl4_LANE_SEL_lane0_bypass = execute_ctrl4_up_LANE_SEL_lane0;
    if(when_ExecuteLanePlugin_l306_4) begin
      execute_ctrl4_LANE_SEL_lane0_bypass = 1'b0;
    end
  end

  assign execute_ctrl3_down_RD_ENABLE_lane0 = execute_ctrl3_RD_ENABLE_lane0_bypass;
  always @(*) begin
    execute_ctrl3_RD_ENABLE_lane0_bypass = execute_ctrl3_up_RD_ENABLE_lane0;
    if(when_ExecuteLanePlugin_l306_3) begin
      execute_ctrl3_RD_ENABLE_lane0_bypass = 1'b0;
    end
  end

  assign execute_ctrl3_down_LANE_SEL_lane0 = execute_ctrl3_LANE_SEL_lane0_bypass;
  always @(*) begin
    execute_ctrl3_LANE_SEL_lane0_bypass = execute_ctrl3_up_LANE_SEL_lane0;
    if(when_ExecuteLanePlugin_l306_3) begin
      execute_ctrl3_LANE_SEL_lane0_bypass = 1'b0;
    end
  end

  assign execute_ctrl2_down_RD_ENABLE_lane0 = execute_ctrl2_RD_ENABLE_lane0_bypass;
  always @(*) begin
    execute_ctrl2_RD_ENABLE_lane0_bypass = execute_ctrl2_up_RD_ENABLE_lane0;
    if(when_ExecuteLanePlugin_l306_2) begin
      execute_ctrl2_RD_ENABLE_lane0_bypass = 1'b0;
    end
  end

  assign execute_ctrl2_down_LANE_SEL_lane0 = execute_ctrl2_LANE_SEL_lane0_bypass;
  always @(*) begin
    execute_ctrl2_LANE_SEL_lane0_bypass = execute_ctrl2_up_LANE_SEL_lane0;
    if(when_ExecuteLanePlugin_l306_2) begin
      execute_ctrl2_LANE_SEL_lane0_bypass = 1'b0;
    end
  end

  assign execute_ctrl1_down_RD_ENABLE_lane0 = execute_ctrl1_RD_ENABLE_lane0_bypass;
  always @(*) begin
    execute_ctrl1_RD_ENABLE_lane0_bypass = execute_ctrl1_up_RD_ENABLE_lane0;
    if(when_ExecuteLanePlugin_l306_1) begin
      execute_ctrl1_RD_ENABLE_lane0_bypass = 1'b0;
    end
  end

  assign execute_ctrl1_down_LANE_SEL_lane0 = execute_ctrl1_LANE_SEL_lane0_bypass;
  always @(*) begin
    execute_ctrl1_LANE_SEL_lane0_bypass = execute_ctrl1_up_LANE_SEL_lane0;
    if(when_ExecuteLanePlugin_l306_1) begin
      execute_ctrl1_LANE_SEL_lane0_bypass = 1'b0;
    end
  end

  assign execute_ctrl0_down_RD_ENABLE_lane0 = execute_ctrl0_RD_ENABLE_lane0_bypass;
  always @(*) begin
    execute_ctrl0_RD_ENABLE_lane0_bypass = execute_ctrl0_up_RD_ENABLE_lane0;
    if(when_ExecuteLanePlugin_l306) begin
      execute_ctrl0_RD_ENABLE_lane0_bypass = 1'b0;
    end
  end

  assign execute_ctrl0_down_LANE_SEL_lane0 = execute_ctrl0_LANE_SEL_lane0_bypass;
  always @(*) begin
    execute_ctrl0_LANE_SEL_lane0_bypass = execute_ctrl0_up_LANE_SEL_lane0;
    if(when_ExecuteLanePlugin_l306) begin
      execute_ctrl0_LANE_SEL_lane0_bypass = 1'b0;
    end
  end

  assign execute_ctrl3_down_integer_RS2_lane0 = execute_ctrl3_integer_RS2_lane0_bypass;
  assign execute_ctrl2_down_integer_RS2_lane0 = execute_ctrl2_integer_RS2_lane0_bypass;
  assign execute_ctrl3_down_integer_RS1_lane0 = execute_ctrl3_integer_RS1_lane0_bypass;
  assign execute_ctrl2_down_integer_RS1_lane0 = execute_ctrl2_integer_RS1_lane0_bypass;
  always @(*) begin
    _zz_1 = 1'b0;
    if(CsrRamPlugin_logic_writeLogic_port_valid) begin
      _zz_1 = 1'b1;
    end
  end

  assign execute_ctrl4_down_COMMIT_lane0 = execute_ctrl4_COMMIT_lane0_bypass;
  always @(*) begin
    execute_ctrl4_COMMIT_lane0_bypass = execute_ctrl4_up_COMMIT_lane0;
    if(when_LsuPlugin_l1036) begin
      if(LsuPlugin_logic_onCtrl_lsuTrap) begin
        execute_ctrl4_COMMIT_lane0_bypass = 1'b0;
      end
    end
  end

  assign execute_ctrl4_down_TRAP_lane0 = execute_ctrl4_TRAP_lane0_bypass;
  always @(*) begin
    execute_ctrl4_TRAP_lane0_bypass = execute_ctrl4_up_TRAP_lane0;
    if(when_LsuPlugin_l1036) begin
      if(LsuPlugin_logic_onCtrl_lsuTrap) begin
        execute_ctrl4_TRAP_lane0_bypass = 1'b1;
      end
    end
  end

  assign execute_ctrl4_down_LsuL1_SEL_lane0 = execute_ctrl4_LsuL1_SEL_lane0_bypass;
  always @(*) begin
    execute_ctrl4_LsuL1_SEL_lane0_bypass = execute_ctrl4_up_LsuL1_SEL_lane0;
    if(when_LsuPlugin_l647_1) begin
      execute_ctrl4_LsuL1_SEL_lane0_bypass = 1'b0;
    end
  end

  assign execute_ctrl3_down_LsuL1_SEL_lane0 = execute_ctrl3_LsuL1_SEL_lane0_bypass;
  always @(*) begin
    execute_ctrl3_LsuL1_SEL_lane0_bypass = execute_ctrl3_up_LsuL1_SEL_lane0;
    if(when_LsuPlugin_l647) begin
      execute_ctrl3_LsuL1_SEL_lane0_bypass = 1'b0;
    end
  end

  assign execute_ctrl2_down_LsuPlugin_logic_FENCE_lane0 = execute_ctrl2_LsuPlugin_logic_FENCE_lane0_bypass;
  always @(*) begin
    execute_ctrl2_LsuPlugin_logic_FENCE_lane0_bypass = execute_ctrl2_up_LsuPlugin_logic_FENCE_lane0;
    if(when_LsuPlugin_l596) begin
      execute_ctrl2_LsuPlugin_logic_FENCE_lane0_bypass = 1'b0;
    end
  end

  assign execute_ctrl2_down_AguPlugin_SIZE_lane0 = execute_ctrl2_AguPlugin_SIZE_lane0_bypass;
  always @(*) begin
    execute_ctrl2_AguPlugin_SIZE_lane0_bypass = execute_ctrl2_up_AguPlugin_SIZE_lane0;
    if(execute_ctrl2_down_AguPlugin_GUEST_lane0) begin
      execute_ctrl2_AguPlugin_SIZE_lane0_bypass = execute_ctrl2_down_Decode_UOP_lane0[27 : 26];
    end
  end

  always @(*) begin
    PcPlugin_logic_harts_0_aggregator_fault_1 = PcPlugin_logic_harts_0_aggregator_fault;
    if(when_PcPlugin_l80) begin
      PcPlugin_logic_harts_0_aggregator_fault_1 = _zz_PcPlugin_logic_harts_0_aggregator_fault_1_1[0];
    end
  end

  always @(*) begin
    PcPlugin_logic_harts_0_aggregator_target_1 = PcPlugin_logic_harts_0_aggregator_target;
    if(when_PcPlugin_l80) begin
      PcPlugin_logic_harts_0_aggregator_target_1 = (_zz_PcPlugin_logic_harts_0_aggregator_fault_1 ? BtbPlugin_logic_pcPort_payload_pc : 32'h0);
    end
  end

  assign execute_ctrl3_down_LsuL1Plugin_logic_SHARED_lane0_plru_0 = execute_ctrl3_LsuL1Plugin_logic_SHARED_lane0_bypass_plru_0;
  assign execute_ctrl3_down_LsuL1Plugin_logic_SHARED_lane0_dirty = execute_ctrl3_LsuL1Plugin_logic_SHARED_lane0_bypass_dirty;
  assign execute_ctrl4_down_LsuL1Plugin_logic_FREEZE_HAZARD_lane0 = execute_ctrl4_LsuL1Plugin_logic_FREEZE_HAZARD_lane0_bypass;
  assign execute_ctrl3_down_LsuL1Plugin_logic_FREEZE_HAZARD_lane0 = execute_ctrl3_LsuL1Plugin_logic_FREEZE_HAZARD_lane0_bypass;
  always @(*) begin
    _zz_2 = 1'b0;
    if(LsuL1Plugin_logic_writeback_read_slotReadLast_valid) begin
      _zz_2 = 1'b1;
    end
  end

  always @(*) begin
    _zz_3 = 1'b0;
    if(LsuL1Plugin_logic_shared_write_valid) begin
      _zz_3 = 1'b1;
    end
  end

  assign decode_ctrls_1_down_LANE_SEL_1 = decode_ctrls_1_LANE_SEL_1_bypass;
  always @(*) begin
    decode_ctrls_1_LANE_SEL_1_bypass = decode_ctrls_1_up_LANE_SEL_1;
    if(decode_logic_flushes_1_onLanes_1_doIt) begin
      decode_ctrls_1_LANE_SEL_1_bypass = 1'b0;
    end
  end

  assign decode_ctrls_1_down_LANE_SEL_0 = decode_ctrls_1_LANE_SEL_0_bypass;
  always @(*) begin
    decode_ctrls_1_LANE_SEL_0_bypass = decode_ctrls_1_up_LANE_SEL_0;
    if(decode_logic_flushes_1_onLanes_0_doIt) begin
      decode_ctrls_1_LANE_SEL_0_bypass = 1'b0;
    end
  end

  assign decode_ctrls_0_down_LANE_SEL_1 = decode_ctrls_0_LANE_SEL_1_bypass;
  always @(*) begin
    decode_ctrls_0_LANE_SEL_1_bypass = decode_ctrls_0_up_LANE_SEL_1;
    if(decode_logic_flushes_0_onLanes_1_doIt) begin
      decode_ctrls_0_LANE_SEL_1_bypass = 1'b0;
    end
  end

  assign decode_ctrls_0_down_LANE_SEL_0 = decode_ctrls_0_LANE_SEL_0_bypass;
  always @(*) begin
    decode_ctrls_0_LANE_SEL_0_bypass = decode_ctrls_0_up_LANE_SEL_0;
    if(decode_logic_flushes_0_onLanes_0_doIt) begin
      decode_ctrls_0_LANE_SEL_0_bypass = 1'b0;
    end
  end

  assign execute_ctrl4_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 = execute_ctrl4_lane1_integer_WriteBackPlugin_logic_DATA_lane1_bypass;
  assign execute_ctrl2_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 = execute_ctrl2_lane1_integer_WriteBackPlugin_logic_DATA_lane1_bypass;
  assign execute_ctrl4_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 = execute_ctrl4_lane0_integer_WriteBackPlugin_logic_DATA_lane0_bypass;
  assign execute_ctrl3_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 = execute_ctrl3_lane0_integer_WriteBackPlugin_logic_DATA_lane0_bypass;
  assign execute_ctrl2_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 = execute_ctrl2_lane0_integer_WriteBackPlugin_logic_DATA_lane0_bypass;
  assign decode_ctrls_1_down_TRAP_1 = decode_ctrls_1_TRAP_1_bypass;
  always @(*) begin
    decode_ctrls_1_TRAP_1_bypass = decode_ctrls_1_up_TRAP_1;
    if(when_DecoderPlugin_l245_1) begin
      decode_ctrls_1_TRAP_1_bypass = 1'b1;
    end
  end

  assign decode_ctrls_1_down_TRAP_0 = decode_ctrls_1_TRAP_0_bypass;
  always @(*) begin
    decode_ctrls_1_TRAP_0_bypass = decode_ctrls_1_up_TRAP_0;
    if(when_DecoderPlugin_l245) begin
      decode_ctrls_1_TRAP_0_bypass = 1'b1;
    end
  end

  always @(*) begin
    late1_BranchPlugin_logic_jumpLogic_history_shifter_4 = late1_BranchPlugin_logic_jumpLogic_history_shifter_3;
    if(when_BranchPlugin_l218_3) begin
      late1_BranchPlugin_logic_jumpLogic_history_shifter_4 = _zz_late1_BranchPlugin_logic_jumpLogic_history_shifter_4[11 : 0];
    end
  end

  always @(*) begin
    late1_BranchPlugin_logic_jumpLogic_history_shifter_3 = late1_BranchPlugin_logic_jumpLogic_history_shifter_2;
    if(when_BranchPlugin_l213_11) begin
      late1_BranchPlugin_logic_jumpLogic_history_shifter_3 = _zz_late1_BranchPlugin_logic_jumpLogic_history_shifter_3[11 : 0];
    end
  end

  always @(*) begin
    late1_BranchPlugin_logic_jumpLogic_history_shifter_2 = late1_BranchPlugin_logic_jumpLogic_history_shifter_1;
    if(when_BranchPlugin_l213_10) begin
      late1_BranchPlugin_logic_jumpLogic_history_shifter_2 = _zz_late1_BranchPlugin_logic_jumpLogic_history_shifter_2[11 : 0];
    end
  end

  always @(*) begin
    late1_BranchPlugin_logic_jumpLogic_history_shifter_1 = late1_BranchPlugin_logic_jumpLogic_history_shifter;
    if(when_BranchPlugin_l213_9) begin
      late1_BranchPlugin_logic_jumpLogic_history_shifter_1 = _zz_late1_BranchPlugin_logic_jumpLogic_history_shifter_1[11 : 0];
    end
  end

  always @(*) begin
    late0_BranchPlugin_logic_jumpLogic_history_shifter_4 = late0_BranchPlugin_logic_jumpLogic_history_shifter_3;
    if(when_BranchPlugin_l218_2) begin
      late0_BranchPlugin_logic_jumpLogic_history_shifter_4 = _zz_late0_BranchPlugin_logic_jumpLogic_history_shifter_4[11 : 0];
    end
  end

  always @(*) begin
    late0_BranchPlugin_logic_jumpLogic_history_shifter_3 = late0_BranchPlugin_logic_jumpLogic_history_shifter_2;
    if(when_BranchPlugin_l213_8) begin
      late0_BranchPlugin_logic_jumpLogic_history_shifter_3 = _zz_late0_BranchPlugin_logic_jumpLogic_history_shifter_3[11 : 0];
    end
  end

  always @(*) begin
    late0_BranchPlugin_logic_jumpLogic_history_shifter_2 = late0_BranchPlugin_logic_jumpLogic_history_shifter_1;
    if(when_BranchPlugin_l213_7) begin
      late0_BranchPlugin_logic_jumpLogic_history_shifter_2 = _zz_late0_BranchPlugin_logic_jumpLogic_history_shifter_2[11 : 0];
    end
  end

  always @(*) begin
    late0_BranchPlugin_logic_jumpLogic_history_shifter_1 = late0_BranchPlugin_logic_jumpLogic_history_shifter;
    if(when_BranchPlugin_l213_6) begin
      late0_BranchPlugin_logic_jumpLogic_history_shifter_1 = _zz_late0_BranchPlugin_logic_jumpLogic_history_shifter_1[11 : 0];
    end
  end

  assign execute_ctrl4_down_COMPLETED_lane1 = execute_ctrl4_COMPLETED_lane1_bypass;
  assign execute_ctrl2_down_COMPLETED_lane1 = execute_ctrl2_COMPLETED_lane1_bypass;
  assign execute_ctrl3_down_COMPLETED_lane0 = execute_ctrl3_COMPLETED_lane0_bypass;
  assign execute_ctrl4_down_COMPLETED_lane0 = execute_ctrl4_COMPLETED_lane0_bypass;
  assign execute_ctrl2_down_COMPLETED_lane0 = execute_ctrl2_COMPLETED_lane0_bypass;
  always @(*) begin
    early1_BranchPlugin_logic_jumpLogic_history_shifter_4 = early1_BranchPlugin_logic_jumpLogic_history_shifter_3;
    if(when_BranchPlugin_l218_1) begin
      early1_BranchPlugin_logic_jumpLogic_history_shifter_4 = _zz_early1_BranchPlugin_logic_jumpLogic_history_shifter_4[11 : 0];
    end
  end

  always @(*) begin
    early1_BranchPlugin_logic_jumpLogic_history_shifter_3 = early1_BranchPlugin_logic_jumpLogic_history_shifter_2;
    if(when_BranchPlugin_l213_5) begin
      early1_BranchPlugin_logic_jumpLogic_history_shifter_3 = _zz_early1_BranchPlugin_logic_jumpLogic_history_shifter_3[11 : 0];
    end
  end

  always @(*) begin
    early1_BranchPlugin_logic_jumpLogic_history_shifter_2 = early1_BranchPlugin_logic_jumpLogic_history_shifter_1;
    if(when_BranchPlugin_l213_4) begin
      early1_BranchPlugin_logic_jumpLogic_history_shifter_2 = _zz_early1_BranchPlugin_logic_jumpLogic_history_shifter_2[11 : 0];
    end
  end

  always @(*) begin
    early1_BranchPlugin_logic_jumpLogic_history_shifter_1 = early1_BranchPlugin_logic_jumpLogic_history_shifter;
    if(when_BranchPlugin_l213_3) begin
      early1_BranchPlugin_logic_jumpLogic_history_shifter_1 = _zz_early1_BranchPlugin_logic_jumpLogic_history_shifter_1[11 : 0];
    end
  end

  always @(*) begin
    early0_BranchPlugin_logic_jumpLogic_history_shifter_4 = early0_BranchPlugin_logic_jumpLogic_history_shifter_3;
    if(when_BranchPlugin_l218) begin
      early0_BranchPlugin_logic_jumpLogic_history_shifter_4 = _zz_early0_BranchPlugin_logic_jumpLogic_history_shifter_4[11 : 0];
    end
  end

  always @(*) begin
    early0_BranchPlugin_logic_jumpLogic_history_shifter_3 = early0_BranchPlugin_logic_jumpLogic_history_shifter_2;
    if(when_BranchPlugin_l213_2) begin
      early0_BranchPlugin_logic_jumpLogic_history_shifter_3 = _zz_early0_BranchPlugin_logic_jumpLogic_history_shifter_3[11 : 0];
    end
  end

