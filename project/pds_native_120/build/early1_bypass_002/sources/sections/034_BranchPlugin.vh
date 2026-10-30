  always @(*) begin
    early0_EnvPlugin_logic_trapPort_payload_arg = 3'b000;
    case(execute_ctrl2_down_early0_EnvPlugin_OP_lane0)
      EnvPluginOp_PRIV_RET : begin
        if(when_EnvPlugin_l132) begin
          early0_EnvPlugin_logic_trapPort_payload_arg[2 : 0] = early0_EnvPlugin_logic_exe_xretPriv;
        end
      end
      default : begin
      end
    endcase
  end

  assign early0_EnvPlugin_logic_trapPort_payload_laneAge = execute_ctrl2_down_LANE_AGE_lane0;
  assign early0_EnvPlugin_logic_exe_privilege = PrivilegedPlugin_logic_harts_0_privilege;
  assign early0_EnvPlugin_logic_exe_isGuest = early0_EnvPlugin_logic_exe_privilege[2];
  assign _zz_early0_EnvPlugin_logic_exe_xretPriv = execute_ctrl2_down_Decode_UOP_lane0[29 : 28];
  always @(*) begin
    early0_EnvPlugin_logic_exe_xretPriv[2] = _zz_early0_EnvPlugin_logic_exe_xretPriv_1[0];
    early0_EnvPlugin_logic_exe_xretPriv[1 : 0] = _zz_early0_EnvPlugin_logic_exe_xretPriv;
  end

  always @(*) begin
    early0_EnvPlugin_logic_exe_commit = 1'b0;
    case(execute_ctrl2_down_early0_EnvPlugin_OP_lane0)
      EnvPluginOp_PRIV_RET : begin
        if(when_EnvPlugin_l132) begin
          early0_EnvPlugin_logic_exe_commit = 1'b1;
        end
      end
      EnvPluginOp_WFI : begin
        if(when_EnvPlugin_l146) begin
          early0_EnvPlugin_logic_exe_commit = 1'b1;
        end
      end
      EnvPluginOp_FENCE_I : begin
        early0_EnvPlugin_logic_exe_commit = 1'b1;
      end
      default : begin
      end
    endcase
  end

  assign early0_EnvPlugin_logic_exe_retKo = 1'b0;
  assign early0_EnvPlugin_logic_exe_wfiMapping_0 = 1'b1;
  assign early0_EnvPlugin_logic_exe_wfiMapping_1 = 1'b1;
  assign early0_EnvPlugin_logic_exe_vmaKoMapping_0 = 1'b1;
  assign early0_EnvPlugin_logic_exe_vmaKo = 1'b0;
  assign early0_EnvPlugin_logic_exe_gvmaKo = 1'b1;
  assign early0_EnvPlugin_logic_exe_vvmaKo = 1'b1;
  assign when_EnvPlugin_l132 = (($signed(early0_EnvPlugin_logic_exe_xretPriv) <= $signed(PrivilegedPlugin_logic_harts_0_privilege)) && (! early0_EnvPlugin_logic_exe_retKo));
  assign when_EnvPlugin_l146 = (($signed(early0_EnvPlugin_logic_exe_privilege) == $signed(3'b011)) || ((! PrivilegedPlugin_logic_harts_0_m_status_tw) && (|{(($signed(early0_EnvPlugin_logic_exe_privilege) == $signed(3'b000)) && early0_EnvPlugin_logic_exe_wfiMapping_1),(($signed(early0_EnvPlugin_logic_exe_privilege) == $signed(3'b001)) && early0_EnvPlugin_logic_exe_wfiMapping_0)})));
  assign when_EnvPlugin_l214 = (execute_ctrl2_up_LANE_SEL_lane0 && execute_ctrl2_down_early0_EnvPlugin_SEL_lane0);
  assign when_EnvPlugin_l218 = (! early0_EnvPlugin_logic_exe_commit);
  assign execute_ctrl2_down_early0_BranchPlugin_logic_alu_EQ_lane0 = ($signed(execute_ctrl2_down_early0_SrcPlugin_SRC1_lane0) == $signed(execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0));
  assign execute_ctrl2_down_early0_BranchPlugin_logic_alu_btb_BAD_TARGET_lane0 = (execute_ctrl2_down_Prediction_ALIGNED_JUMPED_PC_lane0 != execute_ctrl2_down_early0_BranchPlugin_pcCalc_PC_TRUE_lane0);
  assign early0_BranchPlugin_logic_alu_expectedMsb = 1'b0;
  assign execute_ctrl2_down_early0_BranchPlugin_logic_alu_MSB_FAILED_lane0 = ((execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane0 == BranchPlugin_BranchCtrlEnum_JALR) && 1'b0);
  assign switch_Misc_l245 = execute_ctrl2_down_Decode_UOP_lane0[14 : 12];
  always @(*) begin
    casez(switch_Misc_l245)
      3'b000 : begin
        _zz_execute_ctrl2_down_early0_BranchPlugin_logic_jumpLogic_COND_lane0 = execute_ctrl2_down_early0_BranchPlugin_logic_alu_EQ_lane0;
      end
      3'b001 : begin
        _zz_execute_ctrl2_down_early0_BranchPlugin_logic_jumpLogic_COND_lane0 = (! execute_ctrl2_down_early0_BranchPlugin_logic_alu_EQ_lane0);
      end
      3'b1?1 : begin
        _zz_execute_ctrl2_down_early0_BranchPlugin_logic_jumpLogic_COND_lane0 = (! execute_ctrl2_down_early0_SrcPlugin_LESS_lane0);
      end
      default : begin
        _zz_execute_ctrl2_down_early0_BranchPlugin_logic_jumpLogic_COND_lane0 = execute_ctrl2_down_early0_SrcPlugin_LESS_lane0;
      end
    endcase
  end

  always @(*) begin
    case(execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane0)
      BranchPlugin_BranchCtrlEnum_JALR : begin
        _zz_execute_ctrl2_down_early0_BranchPlugin_logic_jumpLogic_COND_lane0_1 = 1'b1;
      end
      BranchPlugin_BranchCtrlEnum_JAL : begin
        _zz_execute_ctrl2_down_early0_BranchPlugin_logic_jumpLogic_COND_lane0_1 = 1'b1;
      end
      default : begin
        _zz_execute_ctrl2_down_early0_BranchPlugin_logic_jumpLogic_COND_lane0_1 = _zz_execute_ctrl2_down_early0_BranchPlugin_logic_jumpLogic_COND_lane0;
      end
    endcase
  end

  assign execute_ctrl2_down_early0_BranchPlugin_logic_jumpLogic_COND_lane0 = _zz_execute_ctrl2_down_early0_BranchPlugin_logic_jumpLogic_COND_lane0_1;
  assign execute_ctrl2_down_early0_BranchPlugin_logic_jumpLogic_btb_REAL_TARGET_lane0 = (execute_ctrl2_down_early0_BranchPlugin_logic_jumpLogic_COND_lane0 ? execute_ctrl2_down_early0_BranchPlugin_pcCalc_PC_TRUE_lane0 : execute_ctrl2_down_early0_BranchPlugin_pcCalc_PC_FALSE_lane0);
  assign early0_BranchPlugin_logic_jumpLogic_wrongCond = (execute_ctrl2_down_Prediction_ALIGNED_JUMPED_lane0 != execute_ctrl2_down_early0_BranchPlugin_logic_jumpLogic_COND_lane0);
  assign early0_BranchPlugin_logic_jumpLogic_needFix = ((early0_BranchPlugin_logic_jumpLogic_wrongCond || (execute_ctrl2_down_early0_BranchPlugin_logic_jumpLogic_COND_lane0 && execute_ctrl2_down_early0_BranchPlugin_logic_alu_btb_BAD_TARGET_lane0)) || execute_ctrl2_down_early0_BranchPlugin_logic_alu_MSB_FAILED_lane0);
  assign early0_BranchPlugin_logic_jumpLogic_doIt = ((execute_ctrl2_up_LANE_SEL_lane0 && execute_ctrl2_down_early0_BranchPlugin_SEL_lane0) && early0_BranchPlugin_logic_jumpLogic_needFix);
  assign early0_BranchPlugin_logic_jumpLogic_history_slice = execute_ctrl2_down_PC_lane0[2 : 1];
  assign early0_BranchPlugin_logic_jumpLogic_history_shifter = execute_ctrl2_down_Prediction_BRANCH_HISTORY_lane0;
  assign when_BranchPlugin_l213 = ((early0_BranchPlugin_logic_jumpLogic_history_slice < 2'b00) && execute_ctrl2_down_Prediction_ALIGNED_SLICES_BRANCH_lane0[0]);
  assign when_BranchPlugin_l213_1 = ((early0_BranchPlugin_logic_jumpLogic_history_slice < 2'b01) && execute_ctrl2_down_Prediction_ALIGNED_SLICES_BRANCH_lane0[1]);
  assign when_BranchPlugin_l213_2 = ((early0_BranchPlugin_logic_jumpLogic_history_slice < 2'b10) && execute_ctrl2_down_Prediction_ALIGNED_SLICES_BRANCH_lane0[2]);
  assign when_BranchPlugin_l218 = (execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane0 == BranchPlugin_BranchCtrlEnum_B);
  assign early0_BranchPlugin_logic_jumpLogic_history_next = early0_BranchPlugin_logic_jumpLogic_history_shifter_4;
  assign early0_BranchPlugin_logic_jumpLogic_history_fetched = execute_ctrl2_down_Prediction_BRANCH_HISTORY_lane0;
  assign early0_BranchPlugin_logic_pcPort_valid = early0_BranchPlugin_logic_jumpLogic_doIt;
  assign early0_BranchPlugin_logic_pcPort_payload_fault = execute_ctrl2_down_early0_BranchPlugin_logic_alu_MSB_FAILED_lane0;
  assign early0_BranchPlugin_logic_pcPort_payload_pc = execute_ctrl2_down_early0_BranchPlugin_logic_jumpLogic_btb_REAL_TARGET_lane0;
  assign early0_BranchPlugin_logic_pcPort_payload_laneAge = execute_ctrl2_down_LANE_AGE_lane0;
  assign early0_BranchPlugin_logic_historyPort_valid = early0_BranchPlugin_logic_jumpLogic_doIt;
  assign early0_BranchPlugin_logic_historyPort_payload_history = early0_BranchPlugin_logic_jumpLogic_history_next;
  assign early0_BranchPlugin_logic_historyPort_payload_age = execute_ctrl2_down_LANE_AGE_lane0;
  assign early0_BranchPlugin_logic_flushPort_valid = early0_BranchPlugin_logic_jumpLogic_doIt;
  assign early0_BranchPlugin_logic_flushPort_payload_uopId = execute_ctrl2_down_Decode_UOP_ID_lane0;
  assign early0_BranchPlugin_logic_flushPort_payload_laneAge = execute_ctrl2_down_LANE_AGE_lane0;
  assign early0_BranchPlugin_logic_flushPort_payload_self = 1'b0;
  assign execute_ctrl2_down_early0_BranchPlugin_logic_jumpLogic_MISSALIGNED_lane0 = ((execute_ctrl2_down_early0_BranchPlugin_pcCalc_PC_TRUE_lane0[0 : 0] != 1'b0) && execute_ctrl2_down_early0_BranchPlugin_logic_jumpLogic_COND_lane0);
  assign execute_ctrl2_down_early0_BranchPlugin_logic_jumpLogic_IS_JAL_lane0 = (execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane0 == BranchPlugin_BranchCtrlEnum_JAL);
  assign execute_ctrl2_down_early0_BranchPlugin_logic_jumpLogic_IS_JALR_lane0 = (execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane0 == BranchPlugin_BranchCtrlEnum_JALR);
  assign early0_BranchPlugin_logic_jumpLogic_rdLink = (|{(execute_ctrl2_down_Decode_UOP_lane0[11 : 7] == 5'h05),(execute_ctrl2_down_Decode_UOP_lane0[11 : 7] == 5'h01)});
  assign early0_BranchPlugin_logic_jumpLogic_rs1Link = (|{(execute_ctrl2_down_Decode_UOP_lane0[19 : 15] == 5'h05),(execute_ctrl2_down_Decode_UOP_lane0[19 : 15] == 5'h01)});
  assign early0_BranchPlugin_logic_jumpLogic_rdEquRs1 = (execute_ctrl2_down_Decode_UOP_lane0[11 : 7] == execute_ctrl2_down_Decode_UOP_lane0[19 : 15]);
  assign early0_BranchPlugin_logic_wb_valid = execute_ctrl2_down_early0_BranchPlugin_SEL_lane0;
  assign early0_BranchPlugin_logic_wb_payload = execute_ctrl2_down_early0_BranchPlugin_pcCalc_PC_FALSE_lane0;
  assign execute_ctrl2_down_early1_BranchPlugin_logic_alu_EQ_lane1 = ($signed(execute_ctrl2_down_early1_SrcPlugin_SRC1_lane1) == $signed(execute_ctrl2_down_early1_SrcPlugin_SRC2_lane1));
  assign execute_ctrl2_down_early1_BranchPlugin_logic_alu_btb_BAD_TARGET_lane1 = (execute_ctrl2_down_Prediction_ALIGNED_JUMPED_PC_lane1 != execute_ctrl2_down_early1_BranchPlugin_pcCalc_PC_TRUE_lane1);
  assign early1_BranchPlugin_logic_alu_expectedMsb = 1'b0;
  assign execute_ctrl2_down_early1_BranchPlugin_logic_alu_MSB_FAILED_lane1 = ((execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane1 == BranchPlugin_BranchCtrlEnum_JALR) && 1'b0);
  assign switch_Misc_l245_1 = execute_ctrl2_down_Decode_UOP_lane1[14 : 12];
  always @(*) begin
    casez(switch_Misc_l245_1)
      3'b000 : begin
        _zz_execute_ctrl2_down_early1_BranchPlugin_logic_jumpLogic_COND_lane1 = execute_ctrl2_down_early1_BranchPlugin_logic_alu_EQ_lane1;
      end
      3'b001 : begin
        _zz_execute_ctrl2_down_early1_BranchPlugin_logic_jumpLogic_COND_lane1 = (! execute_ctrl2_down_early1_BranchPlugin_logic_alu_EQ_lane1);
      end
      3'b1?1 : begin
        _zz_execute_ctrl2_down_early1_BranchPlugin_logic_jumpLogic_COND_lane1 = (! execute_ctrl2_down_early1_SrcPlugin_LESS_lane1);
      end
      default : begin
        _zz_execute_ctrl2_down_early1_BranchPlugin_logic_jumpLogic_COND_lane1 = execute_ctrl2_down_early1_SrcPlugin_LESS_lane1;
      end
    endcase
  end

  always @(*) begin
    case(execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane1)
      BranchPlugin_BranchCtrlEnum_JALR : begin
        _zz_execute_ctrl2_down_early1_BranchPlugin_logic_jumpLogic_COND_lane1_1 = 1'b1;
      end
      BranchPlugin_BranchCtrlEnum_JAL : begin
        _zz_execute_ctrl2_down_early1_BranchPlugin_logic_jumpLogic_COND_lane1_1 = 1'b1;
      end
      default : begin
        _zz_execute_ctrl2_down_early1_BranchPlugin_logic_jumpLogic_COND_lane1_1 = _zz_execute_ctrl2_down_early1_BranchPlugin_logic_jumpLogic_COND_lane1;
      end
    endcase
  end

  assign execute_ctrl2_down_early1_BranchPlugin_logic_jumpLogic_COND_lane1 = _zz_execute_ctrl2_down_early1_BranchPlugin_logic_jumpLogic_COND_lane1_1;
  assign execute_ctrl2_down_early1_BranchPlugin_logic_jumpLogic_btb_REAL_TARGET_lane1 = (execute_ctrl2_down_early1_BranchPlugin_logic_jumpLogic_COND_lane1 ? execute_ctrl2_down_early1_BranchPlugin_pcCalc_PC_TRUE_lane1 : execute_ctrl2_down_early1_BranchPlugin_pcCalc_PC_FALSE_lane1);
  assign early1_BranchPlugin_logic_jumpLogic_wrongCond = (execute_ctrl2_down_Prediction_ALIGNED_JUMPED_lane1 != execute_ctrl2_down_early1_BranchPlugin_logic_jumpLogic_COND_lane1);
  assign early1_BranchPlugin_logic_jumpLogic_needFix = ((early1_BranchPlugin_logic_jumpLogic_wrongCond || (execute_ctrl2_down_early1_BranchPlugin_logic_jumpLogic_COND_lane1 && execute_ctrl2_down_early1_BranchPlugin_logic_alu_btb_BAD_TARGET_lane1)) || execute_ctrl2_down_early1_BranchPlugin_logic_alu_MSB_FAILED_lane1);
  assign early1_BranchPlugin_logic_jumpLogic_doIt = ((execute_ctrl2_up_LANE_SEL_lane1 && execute_ctrl2_down_early1_BranchPlugin_SEL_lane1) && early1_BranchPlugin_logic_jumpLogic_needFix);
  assign early1_BranchPlugin_logic_jumpLogic_history_slice = execute_ctrl2_down_PC_lane1[2 : 1];
  assign early1_BranchPlugin_logic_jumpLogic_history_shifter = execute_ctrl2_down_Prediction_BRANCH_HISTORY_lane1;
  assign when_BranchPlugin_l213_3 = ((early1_BranchPlugin_logic_jumpLogic_history_slice < 2'b00) && execute_ctrl2_down_Prediction_ALIGNED_SLICES_BRANCH_lane1[0]);
  assign when_BranchPlugin_l213_4 = ((early1_BranchPlugin_logic_jumpLogic_history_slice < 2'b01) && execute_ctrl2_down_Prediction_ALIGNED_SLICES_BRANCH_lane1[1]);
  assign when_BranchPlugin_l213_5 = ((early1_BranchPlugin_logic_jumpLogic_history_slice < 2'b10) && execute_ctrl2_down_Prediction_ALIGNED_SLICES_BRANCH_lane1[2]);
  assign when_BranchPlugin_l218_1 = (execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane1 == BranchPlugin_BranchCtrlEnum_B);
  assign early1_BranchPlugin_logic_jumpLogic_history_next = early1_BranchPlugin_logic_jumpLogic_history_shifter_4;
  assign early1_BranchPlugin_logic_jumpLogic_history_fetched = execute_ctrl2_down_Prediction_BRANCH_HISTORY_lane1;
  assign early1_BranchPlugin_logic_pcPort_valid = early1_BranchPlugin_logic_jumpLogic_doIt;
  assign early1_BranchPlugin_logic_pcPort_payload_fault = execute_ctrl2_down_early1_BranchPlugin_logic_alu_MSB_FAILED_lane1;
  assign early1_BranchPlugin_logic_pcPort_payload_pc = execute_ctrl2_down_early1_BranchPlugin_logic_jumpLogic_btb_REAL_TARGET_lane1;
  assign early1_BranchPlugin_logic_pcPort_payload_laneAge = execute_ctrl2_down_LANE_AGE_lane1;
  assign early1_BranchPlugin_logic_historyPort_valid = early1_BranchPlugin_logic_jumpLogic_doIt;
  assign early1_BranchPlugin_logic_historyPort_payload_history = early1_BranchPlugin_logic_jumpLogic_history_next;
  assign early1_BranchPlugin_logic_historyPort_payload_age = execute_ctrl2_down_LANE_AGE_lane1;
  assign early1_BranchPlugin_logic_flushPort_valid = early1_BranchPlugin_logic_jumpLogic_doIt;
  assign early1_BranchPlugin_logic_flushPort_payload_uopId = execute_ctrl2_down_Decode_UOP_ID_lane1;
  assign early1_BranchPlugin_logic_flushPort_payload_laneAge = execute_ctrl2_down_LANE_AGE_lane1;
  assign early1_BranchPlugin_logic_flushPort_payload_self = 1'b0;
  assign execute_ctrl2_down_early1_BranchPlugin_logic_jumpLogic_MISSALIGNED_lane1 = ((execute_ctrl2_down_early1_BranchPlugin_pcCalc_PC_TRUE_lane1[0 : 0] != 1'b0) && execute_ctrl2_down_early1_BranchPlugin_logic_jumpLogic_COND_lane1);
  assign execute_ctrl2_down_early1_BranchPlugin_logic_jumpLogic_IS_JAL_lane1 = (execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane1 == BranchPlugin_BranchCtrlEnum_JAL);
  assign execute_ctrl2_down_early1_BranchPlugin_logic_jumpLogic_IS_JALR_lane1 = (execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane1 == BranchPlugin_BranchCtrlEnum_JALR);
  assign early1_BranchPlugin_logic_jumpLogic_rdLink = (|{(execute_ctrl2_down_Decode_UOP_lane1[11 : 7] == 5'h05),(execute_ctrl2_down_Decode_UOP_lane1[11 : 7] == 5'h01)});
  assign early1_BranchPlugin_logic_jumpLogic_rs1Link = (|{(execute_ctrl2_down_Decode_UOP_lane1[19 : 15] == 5'h05),(execute_ctrl2_down_Decode_UOP_lane1[19 : 15] == 5'h01)});
  assign early1_BranchPlugin_logic_jumpLogic_rdEquRs1 = (execute_ctrl2_down_Decode_UOP_lane1[11 : 7] == execute_ctrl2_down_Decode_UOP_lane1[19 : 15]);
  assign early1_BranchPlugin_logic_wb_valid = execute_ctrl2_down_early1_BranchPlugin_SEL_lane1;
  assign early1_BranchPlugin_logic_wb_payload = execute_ctrl2_down_early1_BranchPlugin_pcCalc_PC_FALSE_lane1;
  assign execute_ctrl2_COMPLETED_lane0_bypass = (execute_ctrl2_up_COMPLETED_lane0 || execute_ctrl2_down_COMPLETION_AT_2_lane0);
  assign execute_ctrl4_COMPLETED_lane0_bypass = (execute_ctrl4_up_COMPLETED_lane0 || execute_ctrl4_down_COMPLETION_AT_4_lane0);
  assign execute_ctrl3_COMPLETED_lane0_bypass = (execute_ctrl3_up_COMPLETED_lane0 || execute_ctrl3_down_COMPLETION_AT_3_lane0);
  assign execute_lane0_api_hartsInflight[0] = (|{(execute_ctrl4_up_LANE_SEL_lane0 && 1'b1),(execute_ctrl3_up_LANE_SEL_lane0 && 1'b1),(execute_ctrl2_up_LANE_SEL_lane0 && 1'b1),(execute_ctrl1_up_LANE_SEL_lane0 && 1'b1)});
  assign execute_ctrl2_COMPLETED_lane1_bypass = (execute_ctrl2_up_COMPLETED_lane1 || execute_ctrl2_down_COMPLETION_AT_2_lane1);
  assign execute_ctrl4_COMPLETED_lane1_bypass = (execute_ctrl4_up_COMPLETED_lane1 || execute_ctrl4_down_COMPLETION_AT_4_lane1);
  assign execute_lane1_api_hartsInflight[0] = (|{(execute_ctrl4_up_LANE_SEL_lane1 && 1'b1),(execute_ctrl3_up_LANE_SEL_lane1 && 1'b1),(execute_ctrl2_up_LANE_SEL_lane1 && 1'b1),(execute_ctrl1_up_LANE_SEL_lane1 && 1'b1)});
  assign execute_ctrl4_down_late0_BranchPlugin_logic_alu_EQ_lane0 = ($signed(execute_ctrl4_down_late0_SrcPlugin_SRC1_lane0) == $signed(execute_ctrl4_down_late0_SrcPlugin_SRC2_lane0));
  assign execute_ctrl4_down_late0_BranchPlugin_logic_alu_btb_BAD_TARGET_lane0 = (execute_ctrl4_down_Prediction_ALIGNED_JUMPED_PC_lane0 != execute_ctrl4_down_early0_BranchPlugin_pcCalc_PC_TRUE_lane0);
  assign late0_BranchPlugin_logic_alu_expectedMsb = 1'b0;
  assign execute_ctrl4_down_late0_BranchPlugin_logic_alu_MSB_FAILED_lane0 = ((execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane0 == BranchPlugin_BranchCtrlEnum_JALR) && 1'b0);
  assign switch_Misc_l245_2 = execute_ctrl4_down_Decode_UOP_lane0[14 : 12];
  always @(*) begin
    casez(switch_Misc_l245_2)
      3'b000 : begin
        _zz_execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_COND_lane0 = execute_ctrl4_down_late0_BranchPlugin_logic_alu_EQ_lane0;
      end
      3'b001 : begin
        _zz_execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_COND_lane0 = (! execute_ctrl4_down_late0_BranchPlugin_logic_alu_EQ_lane0);
      end
      3'b1?1 : begin
        _zz_execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_COND_lane0 = (! execute_ctrl4_down_late0_SrcPlugin_LESS_lane0);
      end
      default : begin
        _zz_execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_COND_lane0 = execute_ctrl4_down_late0_SrcPlugin_LESS_lane0;
      end
    endcase
  end

  always @(*) begin
    case(execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane0)
      BranchPlugin_BranchCtrlEnum_JALR : begin
        _zz_execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_COND_lane0_1 = 1'b1;
      end
      BranchPlugin_BranchCtrlEnum_JAL : begin
        _zz_execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_COND_lane0_1 = 1'b1;
      end
      default : begin
        _zz_execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_COND_lane0_1 = _zz_execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_COND_lane0;
      end
    endcase
  end

  assign execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_COND_lane0 = _zz_execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_COND_lane0_1;
  assign execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_btb_REAL_TARGET_lane0 = (execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_COND_lane0 ? execute_ctrl4_down_early0_BranchPlugin_pcCalc_PC_TRUE_lane0 : execute_ctrl4_down_early0_BranchPlugin_pcCalc_PC_FALSE_lane0);
  assign late0_BranchPlugin_logic_jumpLogic_wrongCond = (execute_ctrl4_down_Prediction_ALIGNED_JUMPED_lane0 != execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_COND_lane0);
  assign late0_BranchPlugin_logic_jumpLogic_needFix = ((late0_BranchPlugin_logic_jumpLogic_wrongCond || (execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_COND_lane0 && execute_ctrl4_down_late0_BranchPlugin_logic_alu_btb_BAD_TARGET_lane0)) || execute_ctrl4_down_late0_BranchPlugin_logic_alu_MSB_FAILED_lane0);
  assign late0_BranchPlugin_logic_jumpLogic_doIt = ((execute_ctrl4_up_LANE_SEL_lane0 && execute_ctrl4_down_late0_BranchPlugin_SEL_lane0) && late0_BranchPlugin_logic_jumpLogic_needFix);
  assign late0_BranchPlugin_logic_jumpLogic_history_slice = execute_ctrl4_down_PC_lane0[2 : 1];
  assign late0_BranchPlugin_logic_jumpLogic_history_shifter = execute_ctrl4_down_Prediction_BRANCH_HISTORY_lane0;
  assign when_BranchPlugin_l213_6 = ((late0_BranchPlugin_logic_jumpLogic_history_slice < 2'b00) && execute_ctrl4_down_Prediction_ALIGNED_SLICES_BRANCH_lane0[0]);
  assign when_BranchPlugin_l213_7 = ((late0_BranchPlugin_logic_jumpLogic_history_slice < 2'b01) && execute_ctrl4_down_Prediction_ALIGNED_SLICES_BRANCH_lane0[1]);
  assign when_BranchPlugin_l213_8 = ((late0_BranchPlugin_logic_jumpLogic_history_slice < 2'b10) && execute_ctrl4_down_Prediction_ALIGNED_SLICES_BRANCH_lane0[2]);
  assign when_BranchPlugin_l218_2 = (execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane0 == BranchPlugin_BranchCtrlEnum_B);
  assign late0_BranchPlugin_logic_jumpLogic_history_next = late0_BranchPlugin_logic_jumpLogic_history_shifter_4;
  assign late0_BranchPlugin_logic_jumpLogic_history_fetched = execute_ctrl4_down_Prediction_BRANCH_HISTORY_lane0;
  assign late0_BranchPlugin_logic_pcPort_valid = late0_BranchPlugin_logic_jumpLogic_doIt;
  assign late0_BranchPlugin_logic_pcPort_payload_fault = execute_ctrl4_down_late0_BranchPlugin_logic_alu_MSB_FAILED_lane0;
  assign late0_BranchPlugin_logic_pcPort_payload_pc = execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_btb_REAL_TARGET_lane0;
  assign late0_BranchPlugin_logic_pcPort_payload_laneAge = execute_ctrl4_down_LANE_AGE_lane0;
  assign late0_BranchPlugin_logic_historyPort_valid = late0_BranchPlugin_logic_jumpLogic_doIt;
  assign late0_BranchPlugin_logic_historyPort_payload_history = late0_BranchPlugin_logic_jumpLogic_history_next;
  assign late0_BranchPlugin_logic_historyPort_payload_age = execute_ctrl4_down_LANE_AGE_lane0;
  assign late0_BranchPlugin_logic_flushPort_valid = late0_BranchPlugin_logic_jumpLogic_doIt;
  assign late0_BranchPlugin_logic_flushPort_payload_uopId = execute_ctrl4_down_Decode_UOP_ID_lane0;
  assign late0_BranchPlugin_logic_flushPort_payload_laneAge = execute_ctrl4_down_LANE_AGE_lane0;
  assign late0_BranchPlugin_logic_flushPort_payload_self = 1'b0;
  assign execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_MISSALIGNED_lane0 = ((execute_ctrl4_down_early0_BranchPlugin_pcCalc_PC_TRUE_lane0[0 : 0] != 1'b0) && execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_COND_lane0);
  assign execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_IS_JAL_lane0 = (execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane0 == BranchPlugin_BranchCtrlEnum_JAL);
  assign execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_IS_JALR_lane0 = (execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane0 == BranchPlugin_BranchCtrlEnum_JALR);
  assign late0_BranchPlugin_logic_jumpLogic_rdLink = (|{(execute_ctrl4_down_Decode_UOP_lane0[11 : 7] == 5'h05),(execute_ctrl4_down_Decode_UOP_lane0[11 : 7] == 5'h01)});
  assign late0_BranchPlugin_logic_jumpLogic_rs1Link = (|{(execute_ctrl4_down_Decode_UOP_lane0[19 : 15] == 5'h05),(execute_ctrl4_down_Decode_UOP_lane0[19 : 15] == 5'h01)});
  assign late0_BranchPlugin_logic_jumpLogic_rdEquRs1 = (execute_ctrl4_down_Decode_UOP_lane0[11 : 7] == execute_ctrl4_down_Decode_UOP_lane0[19 : 15]);
  assign late0_BranchPlugin_logic_jumpLogic_learn_valid = (((execute_ctrl4_up_LANE_SEL_lane0 && execute_ctrl4_down_isReady) && (! execute_lane0_ctrls_4_upIsCancel)) && (|{execute_ctrl4_down_late0_BranchPlugin_SEL_lane0,execute_ctrl4_down_early0_BranchPlugin_SEL_lane0}));
  assign late0_BranchPlugin_logic_jumpLogic_learn_payload_taken = execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_COND_lane0;
  assign late0_BranchPlugin_logic_jumpLogic_learn_payload_pcTarget = execute_ctrl4_down_early0_BranchPlugin_pcCalc_PC_TRUE_lane0;
  assign late0_BranchPlugin_logic_jumpLogic_learn_payload_pcOnLastSlice = execute_ctrl4_down_early0_BranchPlugin_pcCalc_PC_LAST_SLICE_lane0;
  assign late0_BranchPlugin_logic_jumpLogic_learn_payload_isBranch = (execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane0 == BranchPlugin_BranchCtrlEnum_B);
  assign late0_BranchPlugin_logic_jumpLogic_learn_payload_isPush = ((execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_IS_JAL_lane0 || execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_IS_JALR_lane0) && late0_BranchPlugin_logic_jumpLogic_rdLink);
  assign late0_BranchPlugin_logic_jumpLogic_learn_payload_isPop = (execute_ctrl4_down_late0_BranchPlugin_logic_jumpLogic_IS_JALR_lane0 && (((! late0_BranchPlugin_logic_jumpLogic_rdLink) && late0_BranchPlugin_logic_jumpLogic_rs1Link) || ((late0_BranchPlugin_logic_jumpLogic_rdLink && late0_BranchPlugin_logic_jumpLogic_rs1Link) && (! late0_BranchPlugin_logic_jumpLogic_rdEquRs1))));
  assign late0_BranchPlugin_logic_jumpLogic_learn_payload_wasWrong = late0_BranchPlugin_logic_jumpLogic_needFix;
  assign late0_BranchPlugin_logic_jumpLogic_learn_payload_badPredictedTarget = execute_ctrl4_down_late0_BranchPlugin_logic_alu_btb_BAD_TARGET_lane0;
  assign late0_BranchPlugin_logic_jumpLogic_learn_payload_history = late0_BranchPlugin_logic_jumpLogic_history_fetched;
  assign late0_BranchPlugin_logic_jumpLogic_learn_payload_uopId = execute_ctrl4_down_Decode_UOP_ID_lane0;
  assign late0_BranchPlugin_logic_jumpLogic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_0 = execute_ctrl4_down_GSharePlugin_GSHARE_COUNTER_lane0_0;
  assign late0_BranchPlugin_logic_jumpLogic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_1 = execute_ctrl4_down_GSharePlugin_GSHARE_COUNTER_lane0_1;
  assign late0_BranchPlugin_logic_jumpLogic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_2 = execute_ctrl4_down_GSharePlugin_GSHARE_COUNTER_lane0_2;
  assign late0_BranchPlugin_logic_jumpLogic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_3 = execute_ctrl4_down_GSharePlugin_GSHARE_COUNTER_lane0_3;
  assign late0_BranchPlugin_logic_events_branchMiss = ((late0_BranchPlugin_logic_jumpLogic_learn_valid && late0_BranchPlugin_logic_jumpLogic_learn_payload_isBranch) && late0_BranchPlugin_logic_jumpLogic_learn_payload_wasWrong);
  assign late0_BranchPlugin_logic_events_branchCount = (late0_BranchPlugin_logic_jumpLogic_learn_valid && late0_BranchPlugin_logic_jumpLogic_learn_payload_isBranch);
  assign late0_BranchPlugin_logic_wb_valid = execute_ctrl4_down_late0_BranchPlugin_SEL_lane0;
  assign late0_BranchPlugin_logic_wb_payload = execute_ctrl4_down_early0_BranchPlugin_pcCalc_PC_FALSE_lane0;
  assign execute_ctrl4_down_late1_BranchPlugin_logic_alu_EQ_lane1 = ($signed(execute_ctrl4_down_late1_SrcPlugin_SRC1_lane1) == $signed(execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1));
  assign execute_ctrl4_down_late1_BranchPlugin_logic_alu_btb_BAD_TARGET_lane1 = (execute_ctrl4_down_Prediction_ALIGNED_JUMPED_PC_lane1 != execute_ctrl4_down_early1_BranchPlugin_pcCalc_PC_TRUE_lane1);
  assign late1_BranchPlugin_logic_alu_expectedMsb = 1'b0;
  assign execute_ctrl4_down_late1_BranchPlugin_logic_alu_MSB_FAILED_lane1 = ((execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane1 == BranchPlugin_BranchCtrlEnum_JALR) && 1'b0);
  assign switch_Misc_l245_3 = execute_ctrl4_down_Decode_UOP_lane1[14 : 12];
  always @(*) begin
    casez(switch_Misc_l245_3)
      3'b000 : begin
        _zz_execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_COND_lane1 = execute_ctrl4_down_late1_BranchPlugin_logic_alu_EQ_lane1;
      end
      3'b001 : begin
        _zz_execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_COND_lane1 = (! execute_ctrl4_down_late1_BranchPlugin_logic_alu_EQ_lane1);
      end
      3'b1?1 : begin
        _zz_execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_COND_lane1 = (! execute_ctrl4_down_late1_SrcPlugin_LESS_lane1);
      end
      default : begin
        _zz_execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_COND_lane1 = execute_ctrl4_down_late1_SrcPlugin_LESS_lane1;
      end
    endcase
  end

  always @(*) begin
    case(execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane1)
      BranchPlugin_BranchCtrlEnum_JALR : begin
        _zz_execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_COND_lane1_1 = 1'b1;
      end
      BranchPlugin_BranchCtrlEnum_JAL : begin
        _zz_execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_COND_lane1_1 = 1'b1;
      end
      default : begin
        _zz_execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_COND_lane1_1 = _zz_execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_COND_lane1;
      end
    endcase
  end

  assign execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_COND_lane1 = _zz_execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_COND_lane1_1;
  assign execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_btb_REAL_TARGET_lane1 = (execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_COND_lane1 ? execute_ctrl4_down_early1_BranchPlugin_pcCalc_PC_TRUE_lane1 : execute_ctrl4_down_early1_BranchPlugin_pcCalc_PC_FALSE_lane1);
  assign late1_BranchPlugin_logic_jumpLogic_wrongCond = (execute_ctrl4_down_Prediction_ALIGNED_JUMPED_lane1 != execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_COND_lane1);
  assign late1_BranchPlugin_logic_jumpLogic_needFix = ((late1_BranchPlugin_logic_jumpLogic_wrongCond || (execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_COND_lane1 && execute_ctrl4_down_late1_BranchPlugin_logic_alu_btb_BAD_TARGET_lane1)) || execute_ctrl4_down_late1_BranchPlugin_logic_alu_MSB_FAILED_lane1);
  assign late1_BranchPlugin_logic_jumpLogic_doIt = ((execute_ctrl4_up_LANE_SEL_lane1 && execute_ctrl4_down_late1_BranchPlugin_SEL_lane1) && late1_BranchPlugin_logic_jumpLogic_needFix);
  assign late1_BranchPlugin_logic_jumpLogic_history_slice = execute_ctrl4_down_PC_lane1[2 : 1];
  assign late1_BranchPlugin_logic_jumpLogic_history_shifter = execute_ctrl4_down_Prediction_BRANCH_HISTORY_lane1;
  assign when_BranchPlugin_l213_9 = ((late1_BranchPlugin_logic_jumpLogic_history_slice < 2'b00) && execute_ctrl4_down_Prediction_ALIGNED_SLICES_BRANCH_lane1[0]);
  assign when_BranchPlugin_l213_10 = ((late1_BranchPlugin_logic_jumpLogic_history_slice < 2'b01) && execute_ctrl4_down_Prediction_ALIGNED_SLICES_BRANCH_lane1[1]);
  assign when_BranchPlugin_l213_11 = ((late1_BranchPlugin_logic_jumpLogic_history_slice < 2'b10) && execute_ctrl4_down_Prediction_ALIGNED_SLICES_BRANCH_lane1[2]);
  assign when_BranchPlugin_l218_3 = (execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane1 == BranchPlugin_BranchCtrlEnum_B);
  assign late1_BranchPlugin_logic_jumpLogic_history_next = late1_BranchPlugin_logic_jumpLogic_history_shifter_4;
  assign late1_BranchPlugin_logic_jumpLogic_history_fetched = execute_ctrl4_down_Prediction_BRANCH_HISTORY_lane1;
  assign late1_BranchPlugin_logic_pcPort_valid = late1_BranchPlugin_logic_jumpLogic_doIt;
  assign late1_BranchPlugin_logic_pcPort_payload_fault = execute_ctrl4_down_late1_BranchPlugin_logic_alu_MSB_FAILED_lane1;
  assign late1_BranchPlugin_logic_pcPort_payload_pc = execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_btb_REAL_TARGET_lane1;
  assign late1_BranchPlugin_logic_pcPort_payload_laneAge = execute_ctrl4_down_LANE_AGE_lane1;
  assign late1_BranchPlugin_logic_historyPort_valid = late1_BranchPlugin_logic_jumpLogic_doIt;
  assign late1_BranchPlugin_logic_historyPort_payload_history = late1_BranchPlugin_logic_jumpLogic_history_next;
  assign late1_BranchPlugin_logic_historyPort_payload_age = execute_ctrl4_down_LANE_AGE_lane1;
  assign late1_BranchPlugin_logic_flushPort_valid = late1_BranchPlugin_logic_jumpLogic_doIt;
  assign late1_BranchPlugin_logic_flushPort_payload_uopId = execute_ctrl4_down_Decode_UOP_ID_lane1;
  assign late1_BranchPlugin_logic_flushPort_payload_laneAge = execute_ctrl4_down_LANE_AGE_lane1;
  assign late1_BranchPlugin_logic_flushPort_payload_self = 1'b0;
  assign execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_MISSALIGNED_lane1 = ((execute_ctrl4_down_early1_BranchPlugin_pcCalc_PC_TRUE_lane1[0 : 0] != 1'b0) && execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_COND_lane1);
  assign execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_IS_JAL_lane1 = (execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane1 == BranchPlugin_BranchCtrlEnum_JAL);
  assign execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_IS_JALR_lane1 = (execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane1 == BranchPlugin_BranchCtrlEnum_JALR);
  assign late1_BranchPlugin_logic_jumpLogic_rdLink = (|{(execute_ctrl4_down_Decode_UOP_lane1[11 : 7] == 5'h05),(execute_ctrl4_down_Decode_UOP_lane1[11 : 7] == 5'h01)});
  assign late1_BranchPlugin_logic_jumpLogic_rs1Link = (|{(execute_ctrl4_down_Decode_UOP_lane1[19 : 15] == 5'h05),(execute_ctrl4_down_Decode_UOP_lane1[19 : 15] == 5'h01)});
  assign late1_BranchPlugin_logic_jumpLogic_rdEquRs1 = (execute_ctrl4_down_Decode_UOP_lane1[11 : 7] == execute_ctrl4_down_Decode_UOP_lane1[19 : 15]);
  assign late1_BranchPlugin_logic_jumpLogic_learn_valid = (((execute_ctrl4_up_LANE_SEL_lane1 && execute_ctrl4_down_isReady) && (! execute_lane1_ctrls_4_upIsCancel)) && (|{execute_ctrl4_down_late1_BranchPlugin_SEL_lane1,execute_ctrl4_down_early1_BranchPlugin_SEL_lane1}));
  assign late1_BranchPlugin_logic_jumpLogic_learn_payload_taken = execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_COND_lane1;
  assign late1_BranchPlugin_logic_jumpLogic_learn_payload_pcTarget = execute_ctrl4_down_early1_BranchPlugin_pcCalc_PC_TRUE_lane1;
  assign late1_BranchPlugin_logic_jumpLogic_learn_payload_pcOnLastSlice = execute_ctrl4_down_early1_BranchPlugin_pcCalc_PC_LAST_SLICE_lane1;
  assign late1_BranchPlugin_logic_jumpLogic_learn_payload_isBranch = (execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane1 == BranchPlugin_BranchCtrlEnum_B);
  assign late1_BranchPlugin_logic_jumpLogic_learn_payload_isPush = ((execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_IS_JAL_lane1 || execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_IS_JALR_lane1) && late1_BranchPlugin_logic_jumpLogic_rdLink);
  assign late1_BranchPlugin_logic_jumpLogic_learn_payload_isPop = (execute_ctrl4_down_late1_BranchPlugin_logic_jumpLogic_IS_JALR_lane1 && (((! late1_BranchPlugin_logic_jumpLogic_rdLink) && late1_BranchPlugin_logic_jumpLogic_rs1Link) || ((late1_BranchPlugin_logic_jumpLogic_rdLink && late1_BranchPlugin_logic_jumpLogic_rs1Link) && (! late1_BranchPlugin_logic_jumpLogic_rdEquRs1))));
  assign late1_BranchPlugin_logic_jumpLogic_learn_payload_wasWrong = late1_BranchPlugin_logic_jumpLogic_needFix;
  assign late1_BranchPlugin_logic_jumpLogic_learn_payload_badPredictedTarget = execute_ctrl4_down_late1_BranchPlugin_logic_alu_btb_BAD_TARGET_lane1;
  assign late1_BranchPlugin_logic_jumpLogic_learn_payload_history = late1_BranchPlugin_logic_jumpLogic_history_fetched;
  assign late1_BranchPlugin_logic_jumpLogic_learn_payload_uopId = execute_ctrl4_down_Decode_UOP_ID_lane1;
  assign late1_BranchPlugin_logic_jumpLogic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_0 = execute_ctrl4_down_GSharePlugin_GSHARE_COUNTER_lane1_0;
  assign late1_BranchPlugin_logic_jumpLogic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_1 = execute_ctrl4_down_GSharePlugin_GSHARE_COUNTER_lane1_1;
  assign late1_BranchPlugin_logic_jumpLogic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_2 = execute_ctrl4_down_GSharePlugin_GSHARE_COUNTER_lane1_2;
  assign late1_BranchPlugin_logic_jumpLogic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_3 = execute_ctrl4_down_GSharePlugin_GSHARE_COUNTER_lane1_3;
  assign late1_BranchPlugin_logic_events_branchMiss = ((late1_BranchPlugin_logic_jumpLogic_learn_valid && late1_BranchPlugin_logic_jumpLogic_learn_payload_isBranch) && late1_BranchPlugin_logic_jumpLogic_learn_payload_wasWrong);
  assign late1_BranchPlugin_logic_events_branchCount = (late1_BranchPlugin_logic_jumpLogic_learn_valid && late1_BranchPlugin_logic_jumpLogic_learn_payload_isBranch);
  assign late1_BranchPlugin_logic_wb_valid = execute_ctrl4_down_late1_BranchPlugin_SEL_lane1;
  assign late1_BranchPlugin_logic_wb_payload = execute_ctrl4_down_early1_BranchPlugin_pcCalc_PC_FALSE_lane1;
  assign when_DecoderPlugin_l148 = (decode_ctrls_1_up_isMoving && 1'b1);
  assign DecoderPlugin_logic_interrupt_async = PrivilegedPlugin_logic_harts_0_int_pending;
  assign when_DecoderPlugin_l156 = (((! decode_ctrls_1_up_valid) || decode_ctrls_1_up_ready) || decode_ctrls_1_up_isCanceling);
  assign decode_ctrls_1_down_RS1_ENABLE_0 = _zz_decode_ctrls_1_down_RS1_ENABLE_0[0];
  assign decode_ctrls_1_down_RS1_PHYS_0 = _zz_decode_ctrls_1_down_RS1_PHYS_0[4 : 0];
  assign decode_ctrls_1_down_RS2_ENABLE_0 = _zz_decode_ctrls_1_down_RS2_ENABLE_0[0];
  assign decode_ctrls_1_down_RS2_PHYS_0 = _zz_decode_ctrls_1_down_RS2_PHYS_0[4 : 0];
  assign _zz_decode_ctrls_1_down_DONT_FLUSH_PRECISE_4_0 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h00002050) == 32'h00002050);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_0_0 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h0000000c) == 32'h00000004);
  assign _zz_decode_ctrls_1_down_DispatchPlugin_logic_LANES_LAYER_HIT_3_0 = ((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h00000048) == 32'h00000048);
  always @(*) begin
    decode_ctrls_1_down_RD_ENABLE_0 = _zz_decode_ctrls_1_down_RD_ENABLE_0[0];
    if(when_DecoderPlugin_l263) begin
      decode_ctrls_1_down_RD_ENABLE_0 = 1'b0;
    end
  end

  assign decode_ctrls_1_down_RD_PHYS_0 = _zz_decode_ctrls_1_down_RD_PHYS_0[4 : 0];
  assign decode_ctrls_1_down_Decode_LEGAL_0 = ((|{((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h0000005f) == 32'h00000017),((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h0000007f) == 32'h0000006f),((decode_ctrls_1_down_Decode_INSTRUCTION_0 & _zz_decode_ctrls_1_down_Decode_LEGAL_0) == 32'h00001073),(_zz_decode_ctrls_1_down_Decode_LEGAL_0_1 == _zz_decode_ctrls_1_down_Decode_LEGAL_0_2),_zz_decode_ctrls_1_down_Decode_LEGAL_0_3,_zz_decode_ctrls_1_down_Decode_LEGAL_0_4,((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h0000207f) == 32'h00000003),((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h0000506f) == 32'h00000003),((decode_ctrls_1_down_Decode_INSTRUCTION_0 & _zz_decode_ctrls_1_down_Decode_LEGAL_0_6) == 32'h00000003),(_zz_decode_ctrls_1_down_Decode_LEGAL_0_7 == _zz_decode_ctrls_1_down_Decode_LEGAL_0_8),_zz_decode_ctrls_1_down_Decode_LEGAL_0_9,_zz_decode_ctrls_1_down_Decode_LEGAL_0_10,((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h0000607f) == 32'h0000000f),((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h0000717f) == 32'h00006113),((decode_ctrls_1_down_Decode_INSTRUCTION_0 & _zz_decode_ctrls_1_down_Decode_LEGAL_0_12) == 32'h00006813),(_zz_decode_ctrls_1_down_Decode_LEGAL_0_13 == _zz_decode_ctrls_1_down_Decode_LEGAL_0_14),_zz_decode_ctrls_1_down_Decode_LEGAL_0_15,_zz_decode_ctrls_1_down_Decode_LEGAL_0_16,((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'hfc00007f) == 32'h00000033),((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'hfc00305f) == 32'h00001013),((decode_ctrls_1_down_Decode_INSTRUCTION_0 & _zz_decode_ctrls_1_down_Decode_LEGAL_0_18) == 32'h00005013),(_zz_decode_ctrls_1_down_Decode_LEGAL_0_19 == _zz_decode_ctrls_1_down_Decode_LEGAL_0_20),_zz_decode_ctrls_1_down_Decode_LEGAL_0_21,_zz_decode_ctrls_1_down_Decode_LEGAL_0_22,((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'h01007fff) == 32'h01006013),((decode_ctrls_1_down_Decode_INSTRUCTION_0 & 32'hbe00707f) == 32'h00000033),((decode_ctrls_1_down_Decode_INSTRUCTION_0 & _zz_decode_ctrls_1_down_Decode_LEGAL_0_24) == 32'h00006013),(_zz_decode_ctrls_1_down_Decode_LEGAL_0_25 == _zz_decode_ctrls_1_down_Decode_LEGAL_0_26),_zz_decode_ctrls_1_down_Decode_LEGAL_0_27,_zz_decode_ctrls_1_down_Decode_LEGAL_0_28}) && (! decode_ctrls_1_down_Decode_DECOMPRESSION_FAULT_0));
  assign decode_ctrls_1_down_Decode_VIRTUAL_0 = 1'b0;
  assign DecoderPlugin_logic_laneLogic_0_interruptPending = DecoderPlugin_logic_interrupt_buffered[0];
  always @(*) begin
    DecoderPlugin_logic_laneLogic_0_trapPort_valid = 1'b0;
    if(when_DecoderPlugin_l245) begin
      DecoderPlugin_logic_laneLogic_0_trapPort_valid = ((! decode_ctrls_1_up_TRAP_0) || DecoderPlugin_logic_laneLogic_0_interruptPending);
      if(DecoderPlugin_logic_laneLogic_0_fixer_doIt) begin
        DecoderPlugin_logic_laneLogic_0_trapPort_valid = 1'b1;
      end
    end
  end

  always @(*) begin
    DecoderPlugin_logic_laneLogic_0_trapPort_payload_exception = 1'b1;
    if(DecoderPlugin_logic_laneLogic_0_fixer_doIt) begin
      DecoderPlugin_logic_laneLogic_0_trapPort_payload_exception = 1'b0;
    end
    if(DecoderPlugin_logic_laneLogic_0_interruptPending) begin
      DecoderPlugin_logic_laneLogic_0_trapPort_payload_exception = 1'b0;
    end
  end

  assign DecoderPlugin_logic_laneLogic_0_trapPort_payload_tval = decode_ctrls_1_down_Decode_INSTRUCTION_RAW_0;
  assign DecoderPlugin_logic_laneLogic_0_trapPort_payload_tval2 = 32'h0;
  always @(*) begin
    DecoderPlugin_logic_laneLogic_0_trapPort_payload_code = 5'h02;
    if(decode_ctrls_1_down_Decode_VIRTUAL_0) begin
      DecoderPlugin_logic_laneLogic_0_trapPort_payload_code = 5'h16;
    end
    if(DecoderPlugin_logic_laneLogic_0_fixer_doIt) begin
      DecoderPlugin_logic_laneLogic_0_trapPort_payload_code = 5'h04;
    end
    if(DecoderPlugin_logic_laneLogic_0_interruptPending) begin
      DecoderPlugin_logic_laneLogic_0_trapPort_payload_code = 5'h0;
    end
  end

