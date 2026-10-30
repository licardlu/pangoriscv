  always @(posedge socCtrl_systemClk) begin
    if(PrefetcherRptPlugin_logic_pip2_node_0_isReady) begin
      PrefetcherRptPlugin_logic_pip2_node_1_CMD_address <= PrefetcherRptPlugin_logic_pip2_node_0_CMD_address;
      PrefetcherRptPlugin_logic_pip2_node_1_CMD_unique <= PrefetcherRptPlugin_logic_pip2_node_0_CMD_unique;
      PrefetcherRptPlugin_logic_pip2_node_1_CMD_from <= PrefetcherRptPlugin_logic_pip2_node_0_CMD_from;
      PrefetcherRptPlugin_logic_pip2_node_1_CMD_to <= PrefetcherRptPlugin_logic_pip2_node_0_CMD_to;
      PrefetcherRptPlugin_logic_pip2_node_1_CMD_stride <= PrefetcherRptPlugin_logic_pip2_node_0_CMD_stride;
      PrefetcherRptPlugin_logic_pip2_node_1_MUL <= PrefetcherRptPlugin_logic_pip2_node_0_MUL;
    end
    early0_DivPlugin_logic_processing_divRevertResult <= ((execute_ctrl2_down_RsUnsignedPlugin_RS1_REVERT_lane0 ^ (execute_ctrl2_down_RsUnsignedPlugin_RS2_REVERT_lane0 && (! execute_ctrl2_down_DivPlugin_REM_lane0))) && (! (((execute_ctrl2_down_RsUnsignedPlugin_RS2_FORMATED_lane0 == 32'h0) && execute_ctrl2_down_RsUnsignedPlugin_RS2_SIGNED_lane0) && (! execute_ctrl2_down_DivPlugin_REM_lane0))));
    if(when_FetchL1Plugin_l253) begin
      FetchL1Plugin_logic_refill_slots_0_priority[1] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_1) begin
      FetchL1Plugin_logic_refill_slots_0_priority[2] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_2) begin
      FetchL1Plugin_logic_refill_slots_0_priority[3] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_3) begin
      FetchL1Plugin_logic_refill_slots_0_priority[4] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_4) begin
      FetchL1Plugin_logic_refill_slots_0_priority[5] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_5) begin
      FetchL1Plugin_logic_refill_slots_0_priority[6] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_6) begin
      FetchL1Plugin_logic_refill_slots_0_priority[7] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_7) begin
      FetchL1Plugin_logic_refill_slots_1_priority[0] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_8) begin
      FetchL1Plugin_logic_refill_slots_1_priority[2] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_9) begin
      FetchL1Plugin_logic_refill_slots_1_priority[3] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_10) begin
      FetchL1Plugin_logic_refill_slots_1_priority[4] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_11) begin
      FetchL1Plugin_logic_refill_slots_1_priority[5] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_12) begin
      FetchL1Plugin_logic_refill_slots_1_priority[6] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_13) begin
      FetchL1Plugin_logic_refill_slots_1_priority[7] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_14) begin
      FetchL1Plugin_logic_refill_slots_2_priority[0] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_15) begin
      FetchL1Plugin_logic_refill_slots_2_priority[1] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_16) begin
      FetchL1Plugin_logic_refill_slots_2_priority[3] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_17) begin
      FetchL1Plugin_logic_refill_slots_2_priority[4] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_18) begin
      FetchL1Plugin_logic_refill_slots_2_priority[5] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_19) begin
      FetchL1Plugin_logic_refill_slots_2_priority[6] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_20) begin
      FetchL1Plugin_logic_refill_slots_2_priority[7] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_21) begin
      FetchL1Plugin_logic_refill_slots_3_priority[0] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_22) begin
      FetchL1Plugin_logic_refill_slots_3_priority[1] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_23) begin
      FetchL1Plugin_logic_refill_slots_3_priority[2] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_24) begin
      FetchL1Plugin_logic_refill_slots_3_priority[4] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_25) begin
      FetchL1Plugin_logic_refill_slots_3_priority[5] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_26) begin
      FetchL1Plugin_logic_refill_slots_3_priority[6] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_27) begin
      FetchL1Plugin_logic_refill_slots_3_priority[7] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_28) begin
      FetchL1Plugin_logic_refill_slots_4_priority[0] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_29) begin
      FetchL1Plugin_logic_refill_slots_4_priority[1] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_30) begin
      FetchL1Plugin_logic_refill_slots_4_priority[2] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_31) begin
      FetchL1Plugin_logic_refill_slots_4_priority[3] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_32) begin
      FetchL1Plugin_logic_refill_slots_4_priority[5] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_33) begin
      FetchL1Plugin_logic_refill_slots_4_priority[6] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_34) begin
      FetchL1Plugin_logic_refill_slots_4_priority[7] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_35) begin
      FetchL1Plugin_logic_refill_slots_5_priority[0] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_36) begin
      FetchL1Plugin_logic_refill_slots_5_priority[1] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_37) begin
      FetchL1Plugin_logic_refill_slots_5_priority[2] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_38) begin
      FetchL1Plugin_logic_refill_slots_5_priority[3] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_39) begin
      FetchL1Plugin_logic_refill_slots_5_priority[4] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_40) begin
      FetchL1Plugin_logic_refill_slots_5_priority[6] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_41) begin
      FetchL1Plugin_logic_refill_slots_5_priority[7] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_42) begin
      FetchL1Plugin_logic_refill_slots_6_priority[0] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_43) begin
      FetchL1Plugin_logic_refill_slots_6_priority[1] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_44) begin
      FetchL1Plugin_logic_refill_slots_6_priority[2] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_45) begin
      FetchL1Plugin_logic_refill_slots_6_priority[3] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_46) begin
      FetchL1Plugin_logic_refill_slots_6_priority[4] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_47) begin
      FetchL1Plugin_logic_refill_slots_6_priority[5] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_48) begin
      FetchL1Plugin_logic_refill_slots_6_priority[7] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_49) begin
      FetchL1Plugin_logic_refill_slots_7_priority[0] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_50) begin
      FetchL1Plugin_logic_refill_slots_7_priority[1] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_51) begin
      FetchL1Plugin_logic_refill_slots_7_priority[2] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_52) begin
      FetchL1Plugin_logic_refill_slots_7_priority[3] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_53) begin
      FetchL1Plugin_logic_refill_slots_7_priority[4] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_54) begin
      FetchL1Plugin_logic_refill_slots_7_priority[5] <= 1'b0;
    end
    if(when_FetchL1Plugin_l253_55) begin
      FetchL1Plugin_logic_refill_slots_7_priority[6] <= 1'b0;
    end
    if(when_FetchL1Plugin_l262) begin
      if(_zz_24) begin
        FetchL1Plugin_logic_refill_slots_0_address <= FetchL1Plugin_logic_refill_start_address;
        FetchL1Plugin_logic_refill_slots_0_isIo <= FetchL1Plugin_logic_refill_start_isIo;
        FetchL1Plugin_logic_refill_slots_0_wayToAllocate <= FetchL1Plugin_logic_refill_start_wayToAllocate;
        FetchL1Plugin_logic_refill_slots_0_priority <= {FetchL1Plugin_logic_refill_slots_7_valid,FetchL1Plugin_logic_refill_slots_6_valid,FetchL1Plugin_logic_refill_slots_5_valid,FetchL1Plugin_logic_refill_slots_4_valid,FetchL1Plugin_logic_refill_slots_3_valid,FetchL1Plugin_logic_refill_slots_2_valid,FetchL1Plugin_logic_refill_slots_1_valid,FetchL1Plugin_logic_refill_slots_0_valid};
      end
      if(_zz_when) begin
        FetchL1Plugin_logic_refill_slots_1_address <= FetchL1Plugin_logic_refill_start_address;
        FetchL1Plugin_logic_refill_slots_1_isIo <= FetchL1Plugin_logic_refill_start_isIo;
        FetchL1Plugin_logic_refill_slots_1_wayToAllocate <= FetchL1Plugin_logic_refill_start_wayToAllocate;
        FetchL1Plugin_logic_refill_slots_1_priority <= {FetchL1Plugin_logic_refill_slots_7_valid,FetchL1Plugin_logic_refill_slots_6_valid,FetchL1Plugin_logic_refill_slots_5_valid,FetchL1Plugin_logic_refill_slots_4_valid,FetchL1Plugin_logic_refill_slots_3_valid,FetchL1Plugin_logic_refill_slots_2_valid,FetchL1Plugin_logic_refill_slots_1_valid,FetchL1Plugin_logic_refill_slots_0_valid};
      end
      if(_zz_when_1) begin
        FetchL1Plugin_logic_refill_slots_2_address <= FetchL1Plugin_logic_refill_start_address;
        FetchL1Plugin_logic_refill_slots_2_isIo <= FetchL1Plugin_logic_refill_start_isIo;
        FetchL1Plugin_logic_refill_slots_2_wayToAllocate <= FetchL1Plugin_logic_refill_start_wayToAllocate;
        FetchL1Plugin_logic_refill_slots_2_priority <= {FetchL1Plugin_logic_refill_slots_7_valid,FetchL1Plugin_logic_refill_slots_6_valid,FetchL1Plugin_logic_refill_slots_5_valid,FetchL1Plugin_logic_refill_slots_4_valid,FetchL1Plugin_logic_refill_slots_3_valid,FetchL1Plugin_logic_refill_slots_2_valid,FetchL1Plugin_logic_refill_slots_1_valid,FetchL1Plugin_logic_refill_slots_0_valid};
      end
      if(_zz_when_2) begin
        FetchL1Plugin_logic_refill_slots_3_address <= FetchL1Plugin_logic_refill_start_address;
        FetchL1Plugin_logic_refill_slots_3_isIo <= FetchL1Plugin_logic_refill_start_isIo;
        FetchL1Plugin_logic_refill_slots_3_wayToAllocate <= FetchL1Plugin_logic_refill_start_wayToAllocate;
        FetchL1Plugin_logic_refill_slots_3_priority <= {FetchL1Plugin_logic_refill_slots_7_valid,FetchL1Plugin_logic_refill_slots_6_valid,FetchL1Plugin_logic_refill_slots_5_valid,FetchL1Plugin_logic_refill_slots_4_valid,FetchL1Plugin_logic_refill_slots_3_valid,FetchL1Plugin_logic_refill_slots_2_valid,FetchL1Plugin_logic_refill_slots_1_valid,FetchL1Plugin_logic_refill_slots_0_valid};
      end
      if(_zz_when_3) begin
        FetchL1Plugin_logic_refill_slots_4_address <= FetchL1Plugin_logic_refill_start_address;
        FetchL1Plugin_logic_refill_slots_4_isIo <= FetchL1Plugin_logic_refill_start_isIo;
        FetchL1Plugin_logic_refill_slots_4_wayToAllocate <= FetchL1Plugin_logic_refill_start_wayToAllocate;
        FetchL1Plugin_logic_refill_slots_4_priority <= {FetchL1Plugin_logic_refill_slots_7_valid,FetchL1Plugin_logic_refill_slots_6_valid,FetchL1Plugin_logic_refill_slots_5_valid,FetchL1Plugin_logic_refill_slots_4_valid,FetchL1Plugin_logic_refill_slots_3_valid,FetchL1Plugin_logic_refill_slots_2_valid,FetchL1Plugin_logic_refill_slots_1_valid,FetchL1Plugin_logic_refill_slots_0_valid};
      end
      if(_zz_when_4) begin
        FetchL1Plugin_logic_refill_slots_5_address <= FetchL1Plugin_logic_refill_start_address;
        FetchL1Plugin_logic_refill_slots_5_isIo <= FetchL1Plugin_logic_refill_start_isIo;
        FetchL1Plugin_logic_refill_slots_5_wayToAllocate <= FetchL1Plugin_logic_refill_start_wayToAllocate;
        FetchL1Plugin_logic_refill_slots_5_priority <= {FetchL1Plugin_logic_refill_slots_7_valid,FetchL1Plugin_logic_refill_slots_6_valid,FetchL1Plugin_logic_refill_slots_5_valid,FetchL1Plugin_logic_refill_slots_4_valid,FetchL1Plugin_logic_refill_slots_3_valid,FetchL1Plugin_logic_refill_slots_2_valid,FetchL1Plugin_logic_refill_slots_1_valid,FetchL1Plugin_logic_refill_slots_0_valid};
      end
      if(_zz_when_5) begin
        FetchL1Plugin_logic_refill_slots_6_address <= FetchL1Plugin_logic_refill_start_address;
        FetchL1Plugin_logic_refill_slots_6_isIo <= FetchL1Plugin_logic_refill_start_isIo;
        FetchL1Plugin_logic_refill_slots_6_wayToAllocate <= FetchL1Plugin_logic_refill_start_wayToAllocate;
        FetchL1Plugin_logic_refill_slots_6_priority <= {FetchL1Plugin_logic_refill_slots_7_valid,FetchL1Plugin_logic_refill_slots_6_valid,FetchL1Plugin_logic_refill_slots_5_valid,FetchL1Plugin_logic_refill_slots_4_valid,FetchL1Plugin_logic_refill_slots_3_valid,FetchL1Plugin_logic_refill_slots_2_valid,FetchL1Plugin_logic_refill_slots_1_valid,FetchL1Plugin_logic_refill_slots_0_valid};
      end
      if(_zz_when_6) begin
        FetchL1Plugin_logic_refill_slots_7_address <= FetchL1Plugin_logic_refill_start_address;
        FetchL1Plugin_logic_refill_slots_7_isIo <= FetchL1Plugin_logic_refill_start_isIo;
        FetchL1Plugin_logic_refill_slots_7_wayToAllocate <= FetchL1Plugin_logic_refill_start_wayToAllocate;
        FetchL1Plugin_logic_refill_slots_7_priority <= {FetchL1Plugin_logic_refill_slots_7_valid,FetchL1Plugin_logic_refill_slots_6_valid,FetchL1Plugin_logic_refill_slots_5_valid,FetchL1Plugin_logic_refill_slots_4_valid,FetchL1Plugin_logic_refill_slots_3_valid,FetchL1Plugin_logic_refill_slots_2_valid,FetchL1Plugin_logic_refill_slots_1_valid,FetchL1Plugin_logic_refill_slots_0_valid};
      end
    end
    if(when_FetchL1Plugin_l283) begin
      FetchL1Plugin_logic_refill_onCmd_lockedOh <= FetchL1Plugin_logic_refill_onCmd_propoedOh;
    end
    if(FetchL1Plugin_logic_bus_rsp_valid) begin
      FetchL1Plugin_logic_refill_onRsp_rspIdReg <= FetchL1Plugin_logic_bus_rsp_payload_id;
    end
    FetchL1Plugin_logic_ctrl_plruLogic_buffer_regNext_payload_address <= FetchL1Plugin_logic_ctrl_plruLogic_buffer_payload_address;
    FetchL1Plugin_logic_ctrl_plruLogic_buffer_regNext_payload_data_0 <= FetchL1Plugin_logic_ctrl_plruLogic_buffer_payload_data_0;
    if(BtbPlugin_logic_ras_readIt) begin
      BtbPlugin_logic_ras_read <= BtbPlugin_logic_ras_mem_stack_spinal_port0;
    end
    if(when_AlignerPlugin_l256) begin
      AlignerPlugin_logic_buffer_data <= fetch_logic_ctrls_2_down_Fetch_WORD;
      AlignerPlugin_logic_buffer_pc <= fetch_logic_ctrls_2_down_Fetch_WORD_PC;
      AlignerPlugin_logic_buffer_hm_Fetch_ID <= fetch_logic_ctrls_2_down_Fetch_ID;
      AlignerPlugin_logic_buffer_hm_GSharePlugin_GSHARE_COUNTER_0 <= fetch_logic_ctrls_2_down_GSharePlugin_GSHARE_COUNTER_0;
      AlignerPlugin_logic_buffer_hm_GSharePlugin_GSHARE_COUNTER_1 <= fetch_logic_ctrls_2_down_GSharePlugin_GSHARE_COUNTER_1;
      AlignerPlugin_logic_buffer_hm_GSharePlugin_GSHARE_COUNTER_2 <= fetch_logic_ctrls_2_down_GSharePlugin_GSHARE_COUNTER_2;
      AlignerPlugin_logic_buffer_hm_GSharePlugin_GSHARE_COUNTER_3 <= fetch_logic_ctrls_2_down_GSharePlugin_GSHARE_COUNTER_3;
      AlignerPlugin_logic_buffer_hm_Prediction_BRANCH_HISTORY <= fetch_logic_ctrls_2_down_Prediction_BRANCH_HISTORY;
      AlignerPlugin_logic_buffer_hm_Prediction_WORD_SLICES_BRANCH <= fetch_logic_ctrls_2_down_Prediction_WORD_SLICES_BRANCH;
      AlignerPlugin_logic_buffer_hm_Prediction_WORD_SLICES_TAKEN <= fetch_logic_ctrls_2_down_Prediction_WORD_SLICES_TAKEN;
      AlignerPlugin_logic_buffer_hm_Prediction_WORD_JUMP_PC <= fetch_logic_ctrls_2_down_Prediction_WORD_JUMP_PC;
      AlignerPlugin_logic_buffer_hm_Prediction_WORD_JUMPED <= fetch_logic_ctrls_2_down_Prediction_WORD_JUMPED;
      AlignerPlugin_logic_buffer_hm_Prediction_WORD_JUMP_SLICE <= fetch_logic_ctrls_2_down_Prediction_WORD_JUMP_SLICE;
    end
    if(LsuPlugin_logic_storeBuffer_push_valid) begin
      if(_zz_when_7) begin
        LsuPlugin_logic_storeBuffer_slots_0_ptr <= LsuPlugin_logic_storeBuffer_ops_pushPtr;
        LsuPlugin_logic_storeBuffer_slots_0_tag <= LsuPlugin_logic_storeBuffer_push_payload_tag;
      end
      if(_zz_when_8) begin
        LsuPlugin_logic_storeBuffer_slots_1_ptr <= LsuPlugin_logic_storeBuffer_ops_pushPtr;
        LsuPlugin_logic_storeBuffer_slots_1_tag <= LsuPlugin_logic_storeBuffer_push_payload_tag;
      end
      if(_zz_when_9) begin
        LsuPlugin_logic_storeBuffer_slots_2_ptr <= LsuPlugin_logic_storeBuffer_ops_pushPtr;
        LsuPlugin_logic_storeBuffer_slots_2_tag <= LsuPlugin_logic_storeBuffer_push_payload_tag;
      end
      if(_zz_when_10) begin
        LsuPlugin_logic_storeBuffer_slots_3_ptr <= LsuPlugin_logic_storeBuffer_ops_pushPtr;
        LsuPlugin_logic_storeBuffer_slots_3_tag <= LsuPlugin_logic_storeBuffer_push_payload_tag;
      end
    end
    if(late0_BranchPlugin_logic_jumpLogic_learn_ready) begin
      late0_BranchPlugin_logic_jumpLogic_learn_rData_pcOnLastSlice <= late0_BranchPlugin_logic_jumpLogic_learn_payload_pcOnLastSlice;
      late0_BranchPlugin_logic_jumpLogic_learn_rData_pcTarget <= late0_BranchPlugin_logic_jumpLogic_learn_payload_pcTarget;
      late0_BranchPlugin_logic_jumpLogic_learn_rData_taken <= late0_BranchPlugin_logic_jumpLogic_learn_payload_taken;
      late0_BranchPlugin_logic_jumpLogic_learn_rData_isBranch <= late0_BranchPlugin_logic_jumpLogic_learn_payload_isBranch;
      late0_BranchPlugin_logic_jumpLogic_learn_rData_isPush <= late0_BranchPlugin_logic_jumpLogic_learn_payload_isPush;
      late0_BranchPlugin_logic_jumpLogic_learn_rData_isPop <= late0_BranchPlugin_logic_jumpLogic_learn_payload_isPop;
      late0_BranchPlugin_logic_jumpLogic_learn_rData_wasWrong <= late0_BranchPlugin_logic_jumpLogic_learn_payload_wasWrong;
      late0_BranchPlugin_logic_jumpLogic_learn_rData_badPredictedTarget <= late0_BranchPlugin_logic_jumpLogic_learn_payload_badPredictedTarget;
      late0_BranchPlugin_logic_jumpLogic_learn_rData_history <= late0_BranchPlugin_logic_jumpLogic_learn_payload_history;
      late0_BranchPlugin_logic_jumpLogic_learn_rData_uopId <= late0_BranchPlugin_logic_jumpLogic_learn_payload_uopId;
      late0_BranchPlugin_logic_jumpLogic_learn_rData_ctx_GSharePlugin_GSHARE_COUNTER_0 <= late0_BranchPlugin_logic_jumpLogic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_0;
      late0_BranchPlugin_logic_jumpLogic_learn_rData_ctx_GSharePlugin_GSHARE_COUNTER_1 <= late0_BranchPlugin_logic_jumpLogic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_1;
      late0_BranchPlugin_logic_jumpLogic_learn_rData_ctx_GSharePlugin_GSHARE_COUNTER_2 <= late0_BranchPlugin_logic_jumpLogic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_2;
      late0_BranchPlugin_logic_jumpLogic_learn_rData_ctx_GSharePlugin_GSHARE_COUNTER_3 <= late0_BranchPlugin_logic_jumpLogic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_3;
    end
    if(late1_BranchPlugin_logic_jumpLogic_learn_ready) begin
      late1_BranchPlugin_logic_jumpLogic_learn_rData_pcOnLastSlice <= late1_BranchPlugin_logic_jumpLogic_learn_payload_pcOnLastSlice;
      late1_BranchPlugin_logic_jumpLogic_learn_rData_pcTarget <= late1_BranchPlugin_logic_jumpLogic_learn_payload_pcTarget;
      late1_BranchPlugin_logic_jumpLogic_learn_rData_taken <= late1_BranchPlugin_logic_jumpLogic_learn_payload_taken;
      late1_BranchPlugin_logic_jumpLogic_learn_rData_isBranch <= late1_BranchPlugin_logic_jumpLogic_learn_payload_isBranch;
      late1_BranchPlugin_logic_jumpLogic_learn_rData_isPush <= late1_BranchPlugin_logic_jumpLogic_learn_payload_isPush;
      late1_BranchPlugin_logic_jumpLogic_learn_rData_isPop <= late1_BranchPlugin_logic_jumpLogic_learn_payload_isPop;
      late1_BranchPlugin_logic_jumpLogic_learn_rData_wasWrong <= late1_BranchPlugin_logic_jumpLogic_learn_payload_wasWrong;
      late1_BranchPlugin_logic_jumpLogic_learn_rData_badPredictedTarget <= late1_BranchPlugin_logic_jumpLogic_learn_payload_badPredictedTarget;
      late1_BranchPlugin_logic_jumpLogic_learn_rData_history <= late1_BranchPlugin_logic_jumpLogic_learn_payload_history;
      late1_BranchPlugin_logic_jumpLogic_learn_rData_uopId <= late1_BranchPlugin_logic_jumpLogic_learn_payload_uopId;
      late1_BranchPlugin_logic_jumpLogic_learn_rData_ctx_GSharePlugin_GSHARE_COUNTER_0 <= late1_BranchPlugin_logic_jumpLogic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_0;
      late1_BranchPlugin_logic_jumpLogic_learn_rData_ctx_GSharePlugin_GSHARE_COUNTER_1 <= late1_BranchPlugin_logic_jumpLogic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_1;
      late1_BranchPlugin_logic_jumpLogic_learn_rData_ctx_GSharePlugin_GSHARE_COUNTER_2 <= late1_BranchPlugin_logic_jumpLogic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_2;
      late1_BranchPlugin_logic_jumpLogic_learn_rData_ctx_GSharePlugin_GSHARE_COUNTER_3 <= late1_BranchPlugin_logic_jumpLogic_learn_payload_ctx_GSharePlugin_GSHARE_COUNTER_3;
    end
    if(DispatchPlugin_logic_slotsFeeds_doIt) begin
      DispatchPlugin_logic_slots_0_ctx_laneLayerHits <= _zz_DispatchPlugin_logic_slots_0_ctx_valid_4[4 : 1];
      DispatchPlugin_logic_slots_0_ctx_uop <= _zz_DispatchPlugin_logic_slots_0_ctx_valid_4[36 : 5];
      DispatchPlugin_logic_slots_0_ctx_uopIsCompressed <= _zz_DispatchPlugin_logic_slots_0_ctx_valid_4[37];
      DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[0];
      DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED_PC <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[32 : 1];
      DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_SLICES_TAKEN <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[36 : 33];
      DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_SLICES_BRANCH <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[40 : 37];
      DispatchPlugin_logic_slots_0_ctx_hm_GSharePlugin_GSHARE_COUNTER_0 <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_GSharePlugin_GSHARE_COUNTER_0[1 : 0];
      DispatchPlugin_logic_slots_0_ctx_hm_GSharePlugin_GSHARE_COUNTER_1 <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_GSharePlugin_GSHARE_COUNTER_0[3 : 2];
      DispatchPlugin_logic_slots_0_ctx_hm_GSharePlugin_GSHARE_COUNTER_2 <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_GSharePlugin_GSHARE_COUNTER_0[5 : 4];
      DispatchPlugin_logic_slots_0_ctx_hm_GSharePlugin_GSHARE_COUNTER_3 <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_GSharePlugin_GSHARE_COUNTER_0[7 : 6];
      DispatchPlugin_logic_slots_0_ctx_hm_Prediction_BRANCH_HISTORY <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[60 : 49];
      DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_FENCE_OLDER <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[61];
      DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_MAY_FLUSH <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[62];
      DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_DONT_FLUSH <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[63];
      DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_DONT_FLUSH_FROM_LANES <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[64];
      DispatchPlugin_logic_slots_0_ctx_hm_Decode_INSTRUCTION_SLICE_COUNT <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[65 : 65];
      DispatchPlugin_logic_slots_0_ctx_hm_DONT_FLUSH_PRECISE_3 <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[66];
      DispatchPlugin_logic_slots_0_ctx_hm_DONT_FLUSH_PRECISE_4 <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[67];
      DispatchPlugin_logic_slots_0_ctx_hm_PC <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[99 : 68];
      DispatchPlugin_logic_slots_0_ctx_hm_TRAP <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[100];
      DispatchPlugin_logic_slots_0_ctx_hm_Decode_UOP_ID <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[116 : 101];
      DispatchPlugin_logic_slots_0_ctx_hm_RS1_ENABLE <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[117];
      DispatchPlugin_logic_slots_0_ctx_hm_RS1_PHYS <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[122 : 118];
      DispatchPlugin_logic_slots_0_ctx_hm_RS2_ENABLE <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[123];
      DispatchPlugin_logic_slots_0_ctx_hm_RS2_PHYS <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[128 : 124];
      DispatchPlugin_logic_slots_0_ctx_hm_RD_ENABLE <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[129];
      DispatchPlugin_logic_slots_0_ctx_hm_RD_PHYS <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[134 : 130];
      DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_logic_hcs_0_onRs_0_ENABLES_0 <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[135];
      DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_logic_hcs_0_onRs_1_ENABLES_0 <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[136];
      DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_0_ENABLES_0 <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[137];
      DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_0 <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[138];
      DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_logic_hcs_1_onRs_1_ENABLES_1 <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[139];
      DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_logic_hcs_2_onRs_0_ENABLES_0 <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[140];
      DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_logic_hcs_2_onRs_1_ENABLES_0 <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[141];
      DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_logic_hcs_3_onRs_0_ENABLES_0 <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[142];
      DispatchPlugin_logic_slots_0_ctx_hm_DispatchPlugin_logic_hcs_3_onRs_1_ENABLES_0 <= _zz_DispatchPlugin_logic_slots_0_ctx_hm_Prediction_ALIGNED_JUMPED[143];
    end
    _zz_PerformanceCounterPlugin_logic_events_sums_0 <= {late1_BranchPlugin_logic_events_branchMiss,late0_BranchPlugin_logic_events_branchMiss};
    _zz_PerformanceCounterPlugin_logic_events_sums_1 <= {late1_BranchPlugin_logic_events_branchCount,late0_BranchPlugin_logic_events_branchCount};
    _zz_PerformanceCounterPlugin_logic_events_sums_2 <= LsuPlugin_logic_events_waiting;
    _zz_PerformanceCounterPlugin_logic_events_sums_3 <= LsuL1Plugin_logic_events_loadAccess;
    _zz_PerformanceCounterPlugin_logic_events_sums_4 <= LsuL1Plugin_logic_events_loadMiss;
    _zz_PerformanceCounterPlugin_logic_events_sums_5 <= FetchL1Plugin_logic_events_access;
    _zz_PerformanceCounterPlugin_logic_events_sums_6 <= FetchL1Plugin_logic_events_miss;
    _zz_PerformanceCounterPlugin_logic_events_sums_7 <= FetchL1Plugin_logic_events_waiting;
    _zz_PerformanceCounterPlugin_logic_events_sums_8 <= PerformanceCounterPlugin_logic_eventCycles;
    _zz_PerformanceCounterPlugin_logic_events_sums_9 <= {PerformanceCounterPlugin_logic_eventInstructions_1,PerformanceCounterPlugin_logic_eventInstructions_0};
    _zz_PerformanceCounterPlugin_logic_events_sums_10 <= DispatchPlugin_logic_events_frontendStall;
    _zz_PerformanceCounterPlugin_logic_events_sums_11 <= DispatchPlugin_logic_events_backendStall;
    TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_id <= (_zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_id_2 ? (_zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_id ? TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_0_id : TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_1_id) : (_zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_id_1 ? TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_2_id : TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_3_id));
    TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_priority <= (_zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_id_2 ? _zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_priority : _zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_priority_1);
    TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_privilege <= (_zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_id_2 ? _zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_privilege : _zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_privilege_1);
    TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_valid <= (_zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_id_2 ? _zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_valid : _zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_valid_1);
    if(TrapPlugin_logic_harts_0_trap_pending_arbiter_down_valid) begin
      TrapPlugin_logic_harts_0_trap_pending_state_exception <= TrapPlugin_logic_harts_0_trap_pending_arbiter_down_payload_exception;
      TrapPlugin_logic_harts_0_trap_pending_state_tval <= TrapPlugin_logic_harts_0_trap_pending_arbiter_down_payload_tval;
      TrapPlugin_logic_harts_0_trap_pending_state_tval2 <= TrapPlugin_logic_harts_0_trap_pending_arbiter_down_payload_tval2;
      TrapPlugin_logic_harts_0_trap_pending_state_code <= TrapPlugin_logic_harts_0_trap_pending_arbiter_down_payload_code;
      TrapPlugin_logic_harts_0_trap_pending_state_arg <= TrapPlugin_logic_harts_0_trap_pending_arbiter_down_payload_arg;
    end
    if(TrapPlugin_logic_harts_0_trap_trigger_valid) begin
      TrapPlugin_logic_harts_0_trap_pending_pc <= ((_zz_TrapPlugin_logic_harts_0_trap_pending_pc ? execute_ctrl4_down_PC_lane0 : 32'h0) | (_zz_TrapPlugin_logic_harts_0_trap_pending_pc_1 ? execute_ctrl4_down_PC_lane1 : 32'h0));
      TrapPlugin_logic_harts_0_trap_pending_history <= ((_zz_TrapPlugin_logic_harts_0_trap_pending_pc ? execute_ctrl4_down_Prediction_BRANCH_HISTORY_lane0 : 12'h0) | (_zz_TrapPlugin_logic_harts_0_trap_pending_pc_1 ? execute_ctrl4_down_Prediction_BRANCH_HISTORY_lane1 : 12'h0));
      TrapPlugin_logic_harts_0_trap_pending_slices <= (_zz_TrapPlugin_logic_harts_0_trap_pending_slices + 2'b01);
    end
    if(TrapPlugin_logic_harts_0_trap_fsm_buffer_sampleIt) begin
      TrapPlugin_logic_harts_0_trap_fsm_buffer_i_valid <= TrapPlugin_logic_harts_0_interrupt_valid;
    end
    if(TrapPlugin_logic_harts_0_trap_fsm_buffer_sampleIt) begin
      TrapPlugin_logic_harts_0_trap_fsm_buffer_i_code <= TrapPlugin_logic_harts_0_interrupt_code;
    end
    if(TrapPlugin_logic_harts_0_trap_fsm_buffer_sampleIt) begin
      TrapPlugin_logic_harts_0_trap_fsm_buffer_i_targetPrivilege <= TrapPlugin_logic_harts_0_interrupt_targetPrivilege;
    end
    TrapPlugin_logic_harts_0_trap_fsm_jumpTarget <= (TrapPlugin_logic_harts_0_trap_pending_pc + _zz_TrapPlugin_logic_harts_0_trap_fsm_jumpTarget);
    if(when_TrapPlugin_l940) begin
      TrapPlugin_logic_harts_0_trap_fsm_readed <= TrapPlugin_logic_harts_0_crsPorts_read_data;
    end
    LsuL1Plugin_logic_refill_slots_0_loadedCounter <= (LsuL1Plugin_logic_refill_slots_0_loadedCounter + ((LsuL1Plugin_logic_refill_slots_0_loaded && (! LsuL1Plugin_logic_refill_slots_0_loadedDone)) && (! LsuL1Plugin_logic_slotsFreeze)));
    LsuL1Plugin_logic_refill_slots_1_loadedCounter <= (LsuL1Plugin_logic_refill_slots_1_loadedCounter + ((LsuL1Plugin_logic_refill_slots_1_loaded && (! LsuL1Plugin_logic_refill_slots_1_loadedDone)) && (! LsuL1Plugin_logic_slotsFreeze)));
    LsuL1Plugin_logic_refill_slots_2_loadedCounter <= (LsuL1Plugin_logic_refill_slots_2_loadedCounter + ((LsuL1Plugin_logic_refill_slots_2_loaded && (! LsuL1Plugin_logic_refill_slots_2_loadedDone)) && (! LsuL1Plugin_logic_slotsFreeze)));
    LsuL1Plugin_logic_refill_slots_3_loadedCounter <= (LsuL1Plugin_logic_refill_slots_3_loadedCounter + ((LsuL1Plugin_logic_refill_slots_3_loaded && (! LsuL1Plugin_logic_refill_slots_3_loadedDone)) && (! LsuL1Plugin_logic_slotsFreeze)));
    LsuL1Plugin_logic_refill_slots_4_loadedCounter <= (LsuL1Plugin_logic_refill_slots_4_loadedCounter + ((LsuL1Plugin_logic_refill_slots_4_loaded && (! LsuL1Plugin_logic_refill_slots_4_loadedDone)) && (! LsuL1Plugin_logic_slotsFreeze)));
    LsuL1Plugin_logic_refill_slots_5_loadedCounter <= (LsuL1Plugin_logic_refill_slots_5_loadedCounter + ((LsuL1Plugin_logic_refill_slots_5_loaded && (! LsuL1Plugin_logic_refill_slots_5_loadedDone)) && (! LsuL1Plugin_logic_slotsFreeze)));
    LsuL1Plugin_logic_refill_slots_6_loadedCounter <= (LsuL1Plugin_logic_refill_slots_6_loadedCounter + ((LsuL1Plugin_logic_refill_slots_6_loaded && (! LsuL1Plugin_logic_refill_slots_6_loadedDone)) && (! LsuL1Plugin_logic_slotsFreeze)));
    LsuL1Plugin_logic_refill_slots_7_loadedCounter <= (LsuL1Plugin_logic_refill_slots_7_loadedCounter + ((LsuL1Plugin_logic_refill_slots_7_loaded && (! LsuL1Plugin_logic_refill_slots_7_loadedDone)) && (! LsuL1Plugin_logic_slotsFreeze)));
    if(LsuL1Plugin_logic_refill_slots_1_free) begin
      LsuL1Plugin_logic_refill_slots_0_priority[0] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_2_free) begin
      LsuL1Plugin_logic_refill_slots_0_priority[1] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_3_free) begin
      LsuL1Plugin_logic_refill_slots_0_priority[2] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_4_free) begin
      LsuL1Plugin_logic_refill_slots_0_priority[3] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_5_free) begin
      LsuL1Plugin_logic_refill_slots_0_priority[4] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_6_free) begin
      LsuL1Plugin_logic_refill_slots_0_priority[5] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_7_free) begin
      LsuL1Plugin_logic_refill_slots_0_priority[6] <= 1'b0;
    end
    if(when_LsuL1Plugin_l388) begin
      LsuL1Plugin_logic_refill_slots_0_address <= LsuL1Plugin_logic_refill_push_payload_address;
      LsuL1Plugin_logic_refill_slots_0_way <= LsuL1Plugin_logic_refill_push_payload_way;
      LsuL1Plugin_logic_refill_slots_0_cmdSent <= 1'b0;
      LsuL1Plugin_logic_refill_slots_0_priority <= 7'h7f;
      LsuL1Plugin_logic_refill_slots_0_loadedCounter <= 1'b0;
      LsuL1Plugin_logic_refill_slots_0_victim <= LsuL1Plugin_logic_refill_push_payload_victim;
    end
    if(LsuL1Plugin_logic_refill_slots_0_free) begin
      LsuL1Plugin_logic_refill_slots_1_priority[0] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_2_free) begin
      LsuL1Plugin_logic_refill_slots_1_priority[1] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_3_free) begin
      LsuL1Plugin_logic_refill_slots_1_priority[2] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_4_free) begin
      LsuL1Plugin_logic_refill_slots_1_priority[3] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_5_free) begin
      LsuL1Plugin_logic_refill_slots_1_priority[4] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_6_free) begin
      LsuL1Plugin_logic_refill_slots_1_priority[5] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_7_free) begin
      LsuL1Plugin_logic_refill_slots_1_priority[6] <= 1'b0;
    end
    if(when_LsuL1Plugin_l388_1) begin
      LsuL1Plugin_logic_refill_slots_1_address <= LsuL1Plugin_logic_refill_push_payload_address;
      LsuL1Plugin_logic_refill_slots_1_way <= LsuL1Plugin_logic_refill_push_payload_way;
      LsuL1Plugin_logic_refill_slots_1_cmdSent <= 1'b0;
      LsuL1Plugin_logic_refill_slots_1_priority <= 7'h7f;
      LsuL1Plugin_logic_refill_slots_1_loadedCounter <= 1'b0;
      LsuL1Plugin_logic_refill_slots_1_victim <= LsuL1Plugin_logic_refill_push_payload_victim;
    end
    if(LsuL1Plugin_logic_refill_slots_0_free) begin
      LsuL1Plugin_logic_refill_slots_2_priority[0] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_1_free) begin
      LsuL1Plugin_logic_refill_slots_2_priority[1] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_3_free) begin
      LsuL1Plugin_logic_refill_slots_2_priority[2] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_4_free) begin
      LsuL1Plugin_logic_refill_slots_2_priority[3] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_5_free) begin
      LsuL1Plugin_logic_refill_slots_2_priority[4] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_6_free) begin
      LsuL1Plugin_logic_refill_slots_2_priority[5] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_7_free) begin
      LsuL1Plugin_logic_refill_slots_2_priority[6] <= 1'b0;
    end
    if(when_LsuL1Plugin_l388_2) begin
      LsuL1Plugin_logic_refill_slots_2_address <= LsuL1Plugin_logic_refill_push_payload_address;
      LsuL1Plugin_logic_refill_slots_2_way <= LsuL1Plugin_logic_refill_push_payload_way;
      LsuL1Plugin_logic_refill_slots_2_cmdSent <= 1'b0;
      LsuL1Plugin_logic_refill_slots_2_priority <= 7'h7f;
      LsuL1Plugin_logic_refill_slots_2_loadedCounter <= 1'b0;
      LsuL1Plugin_logic_refill_slots_2_victim <= LsuL1Plugin_logic_refill_push_payload_victim;
    end
    if(LsuL1Plugin_logic_refill_slots_0_free) begin
      LsuL1Plugin_logic_refill_slots_3_priority[0] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_1_free) begin
      LsuL1Plugin_logic_refill_slots_3_priority[1] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_2_free) begin
      LsuL1Plugin_logic_refill_slots_3_priority[2] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_4_free) begin
      LsuL1Plugin_logic_refill_slots_3_priority[3] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_5_free) begin
      LsuL1Plugin_logic_refill_slots_3_priority[4] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_6_free) begin
      LsuL1Plugin_logic_refill_slots_3_priority[5] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_7_free) begin
      LsuL1Plugin_logic_refill_slots_3_priority[6] <= 1'b0;
    end
    if(when_LsuL1Plugin_l388_3) begin
      LsuL1Plugin_logic_refill_slots_3_address <= LsuL1Plugin_logic_refill_push_payload_address;
      LsuL1Plugin_logic_refill_slots_3_way <= LsuL1Plugin_logic_refill_push_payload_way;
      LsuL1Plugin_logic_refill_slots_3_cmdSent <= 1'b0;
      LsuL1Plugin_logic_refill_slots_3_priority <= 7'h7f;
      LsuL1Plugin_logic_refill_slots_3_loadedCounter <= 1'b0;
      LsuL1Plugin_logic_refill_slots_3_victim <= LsuL1Plugin_logic_refill_push_payload_victim;
    end
    if(LsuL1Plugin_logic_refill_slots_0_free) begin
      LsuL1Plugin_logic_refill_slots_4_priority[0] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_1_free) begin
      LsuL1Plugin_logic_refill_slots_4_priority[1] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_2_free) begin
      LsuL1Plugin_logic_refill_slots_4_priority[2] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_3_free) begin
      LsuL1Plugin_logic_refill_slots_4_priority[3] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_5_free) begin
      LsuL1Plugin_logic_refill_slots_4_priority[4] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_6_free) begin
      LsuL1Plugin_logic_refill_slots_4_priority[5] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_7_free) begin
      LsuL1Plugin_logic_refill_slots_4_priority[6] <= 1'b0;
    end
    if(when_LsuL1Plugin_l388_4) begin
      LsuL1Plugin_logic_refill_slots_4_address <= LsuL1Plugin_logic_refill_push_payload_address;
      LsuL1Plugin_logic_refill_slots_4_way <= LsuL1Plugin_logic_refill_push_payload_way;
      LsuL1Plugin_logic_refill_slots_4_cmdSent <= 1'b0;
      LsuL1Plugin_logic_refill_slots_4_priority <= 7'h7f;
      LsuL1Plugin_logic_refill_slots_4_loadedCounter <= 1'b0;
      LsuL1Plugin_logic_refill_slots_4_victim <= LsuL1Plugin_logic_refill_push_payload_victim;
    end
    if(LsuL1Plugin_logic_refill_slots_0_free) begin
      LsuL1Plugin_logic_refill_slots_5_priority[0] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_1_free) begin
      LsuL1Plugin_logic_refill_slots_5_priority[1] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_2_free) begin
      LsuL1Plugin_logic_refill_slots_5_priority[2] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_3_free) begin
      LsuL1Plugin_logic_refill_slots_5_priority[3] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_4_free) begin
      LsuL1Plugin_logic_refill_slots_5_priority[4] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_6_free) begin
      LsuL1Plugin_logic_refill_slots_5_priority[5] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_7_free) begin
      LsuL1Plugin_logic_refill_slots_5_priority[6] <= 1'b0;
    end
    if(when_LsuL1Plugin_l388_5) begin
      LsuL1Plugin_logic_refill_slots_5_address <= LsuL1Plugin_logic_refill_push_payload_address;
      LsuL1Plugin_logic_refill_slots_5_way <= LsuL1Plugin_logic_refill_push_payload_way;
      LsuL1Plugin_logic_refill_slots_5_cmdSent <= 1'b0;
      LsuL1Plugin_logic_refill_slots_5_priority <= 7'h7f;
      LsuL1Plugin_logic_refill_slots_5_loadedCounter <= 1'b0;
      LsuL1Plugin_logic_refill_slots_5_victim <= LsuL1Plugin_logic_refill_push_payload_victim;
    end
    if(LsuL1Plugin_logic_refill_slots_0_free) begin
      LsuL1Plugin_logic_refill_slots_6_priority[0] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_1_free) begin
      LsuL1Plugin_logic_refill_slots_6_priority[1] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_2_free) begin
      LsuL1Plugin_logic_refill_slots_6_priority[2] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_3_free) begin
      LsuL1Plugin_logic_refill_slots_6_priority[3] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_4_free) begin
      LsuL1Plugin_logic_refill_slots_6_priority[4] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_5_free) begin
      LsuL1Plugin_logic_refill_slots_6_priority[5] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_7_free) begin
      LsuL1Plugin_logic_refill_slots_6_priority[6] <= 1'b0;
    end
    if(when_LsuL1Plugin_l388_6) begin
      LsuL1Plugin_logic_refill_slots_6_address <= LsuL1Plugin_logic_refill_push_payload_address;
      LsuL1Plugin_logic_refill_slots_6_way <= LsuL1Plugin_logic_refill_push_payload_way;
      LsuL1Plugin_logic_refill_slots_6_cmdSent <= 1'b0;
      LsuL1Plugin_logic_refill_slots_6_priority <= 7'h7f;
      LsuL1Plugin_logic_refill_slots_6_loadedCounter <= 1'b0;
      LsuL1Plugin_logic_refill_slots_6_victim <= LsuL1Plugin_logic_refill_push_payload_victim;
    end
    if(LsuL1Plugin_logic_refill_slots_0_free) begin
      LsuL1Plugin_logic_refill_slots_7_priority[0] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_1_free) begin
      LsuL1Plugin_logic_refill_slots_7_priority[1] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_2_free) begin
      LsuL1Plugin_logic_refill_slots_7_priority[2] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_3_free) begin
      LsuL1Plugin_logic_refill_slots_7_priority[3] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_4_free) begin
      LsuL1Plugin_logic_refill_slots_7_priority[4] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_5_free) begin
      LsuL1Plugin_logic_refill_slots_7_priority[5] <= 1'b0;
    end
    if(LsuL1Plugin_logic_refill_slots_6_free) begin
      LsuL1Plugin_logic_refill_slots_7_priority[6] <= 1'b0;
    end
    if(when_LsuL1Plugin_l388_7) begin
      LsuL1Plugin_logic_refill_slots_7_address <= LsuL1Plugin_logic_refill_push_payload_address;
      LsuL1Plugin_logic_refill_slots_7_way <= LsuL1Plugin_logic_refill_push_payload_way;
      LsuL1Plugin_logic_refill_slots_7_cmdSent <= 1'b0;
      LsuL1Plugin_logic_refill_slots_7_priority <= 7'h7f;
      LsuL1Plugin_logic_refill_slots_7_loadedCounter <= 1'b0;
      LsuL1Plugin_logic_refill_slots_7_victim <= LsuL1Plugin_logic_refill_push_payload_victim;
    end
    if(LsuL1Plugin_logic_refill_read_arbiter_oh[0]) begin
      if(LsuL1Plugin_logic_bus_read_cmd_ready) begin
        LsuL1Plugin_logic_refill_slots_0_cmdSent <= 1'b1;
      end
    end
    if(_zz_LsuL1Plugin_logic_refill_read_arbiter_sel) begin
      if(LsuL1Plugin_logic_bus_read_cmd_ready) begin
        LsuL1Plugin_logic_refill_slots_1_cmdSent <= 1'b1;
      end
    end
    if(_zz_LsuL1Plugin_logic_refill_read_arbiter_sel_1) begin
      if(LsuL1Plugin_logic_bus_read_cmd_ready) begin
        LsuL1Plugin_logic_refill_slots_2_cmdSent <= 1'b1;
      end
    end
    if(_zz_LsuL1Plugin_logic_refill_read_arbiter_sel_2) begin
      if(LsuL1Plugin_logic_bus_read_cmd_ready) begin
        LsuL1Plugin_logic_refill_slots_3_cmdSent <= 1'b1;
      end
    end
    if(_zz_LsuL1Plugin_logic_refill_read_arbiter_sel_3) begin
      if(LsuL1Plugin_logic_bus_read_cmd_ready) begin
        LsuL1Plugin_logic_refill_slots_4_cmdSent <= 1'b1;
      end
    end
    if(_zz_LsuL1Plugin_logic_refill_read_arbiter_sel_4) begin
      if(LsuL1Plugin_logic_bus_read_cmd_ready) begin
        LsuL1Plugin_logic_refill_slots_5_cmdSent <= 1'b1;
      end
    end
    if(_zz_LsuL1Plugin_logic_refill_read_arbiter_sel_5) begin
      if(LsuL1Plugin_logic_bus_read_cmd_ready) begin
        LsuL1Plugin_logic_refill_slots_6_cmdSent <= 1'b1;
      end
    end
    if(_zz_LsuL1Plugin_logic_refill_read_arbiter_sel_6) begin
      if(LsuL1Plugin_logic_bus_read_cmd_ready) begin
        LsuL1Plugin_logic_refill_slots_7_cmdSent <= 1'b1;
      end
    end
    LsuL1Plugin_logic_writeback_slots_0_timer_counter <= (LsuL1Plugin_logic_writeback_slots_0_timer_counter + ((! LsuL1Plugin_logic_writeback_slots_0_timer_done) && (! LsuL1Plugin_logic_slotsFreeze)));
    LsuL1Plugin_logic_writeback_slots_1_timer_counter <= (LsuL1Plugin_logic_writeback_slots_1_timer_counter + ((! LsuL1Plugin_logic_writeback_slots_1_timer_done) && (! LsuL1Plugin_logic_slotsFreeze)));
    LsuL1Plugin_logic_writeback_slots_2_timer_counter <= (LsuL1Plugin_logic_writeback_slots_2_timer_counter + ((! LsuL1Plugin_logic_writeback_slots_2_timer_done) && (! LsuL1Plugin_logic_slotsFreeze)));
    LsuL1Plugin_logic_writeback_slots_3_timer_counter <= (LsuL1Plugin_logic_writeback_slots_3_timer_counter + ((! LsuL1Plugin_logic_writeback_slots_3_timer_done) && (! LsuL1Plugin_logic_slotsFreeze)));
    LsuL1Plugin_logic_writeback_slots_4_timer_counter <= (LsuL1Plugin_logic_writeback_slots_4_timer_counter + ((! LsuL1Plugin_logic_writeback_slots_4_timer_done) && (! LsuL1Plugin_logic_slotsFreeze)));
    LsuL1Plugin_logic_writeback_slots_5_timer_counter <= (LsuL1Plugin_logic_writeback_slots_5_timer_counter + ((! LsuL1Plugin_logic_writeback_slots_5_timer_done) && (! LsuL1Plugin_logic_slotsFreeze)));
    LsuL1Plugin_logic_writeback_slots_6_timer_counter <= (LsuL1Plugin_logic_writeback_slots_6_timer_counter + ((! LsuL1Plugin_logic_writeback_slots_6_timer_done) && (! LsuL1Plugin_logic_slotsFreeze)));
    LsuL1Plugin_logic_writeback_slots_7_timer_counter <= (LsuL1Plugin_logic_writeback_slots_7_timer_counter + ((! LsuL1Plugin_logic_writeback_slots_7_timer_done) && (! LsuL1Plugin_logic_slotsFreeze)));
    if(LsuL1Plugin_logic_writeback_slots_1_free) begin
      LsuL1Plugin_logic_writeback_slots_0_priority[0] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_2_free) begin
      LsuL1Plugin_logic_writeback_slots_0_priority[1] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_3_free) begin
      LsuL1Plugin_logic_writeback_slots_0_priority[2] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_4_free) begin
      LsuL1Plugin_logic_writeback_slots_0_priority[3] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_5_free) begin
      LsuL1Plugin_logic_writeback_slots_0_priority[4] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_6_free) begin
      LsuL1Plugin_logic_writeback_slots_0_priority[5] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_7_free) begin
      LsuL1Plugin_logic_writeback_slots_0_priority[6] <= 1'b0;
    end
    if(when_LsuL1Plugin_l566) begin
      LsuL1Plugin_logic_writeback_slots_0_address <= LsuL1Plugin_logic_writeback_push_payload_address;
      LsuL1Plugin_logic_writeback_slots_0_way <= LsuL1Plugin_logic_writeback_push_payload_way;
      LsuL1Plugin_logic_writeback_slots_0_timer_counter <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_0_writeCmdDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_0_priority <= 7'h7f;
      LsuL1Plugin_logic_writeback_slots_0_readCmdDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_0_readRspDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_0_victimBufferReady <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_0_free) begin
      LsuL1Plugin_logic_writeback_slots_1_priority[0] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_2_free) begin
      LsuL1Plugin_logic_writeback_slots_1_priority[1] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_3_free) begin
      LsuL1Plugin_logic_writeback_slots_1_priority[2] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_4_free) begin
      LsuL1Plugin_logic_writeback_slots_1_priority[3] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_5_free) begin
      LsuL1Plugin_logic_writeback_slots_1_priority[4] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_6_free) begin
      LsuL1Plugin_logic_writeback_slots_1_priority[5] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_7_free) begin
      LsuL1Plugin_logic_writeback_slots_1_priority[6] <= 1'b0;
    end
    if(when_LsuL1Plugin_l566_1) begin
      LsuL1Plugin_logic_writeback_slots_1_address <= LsuL1Plugin_logic_writeback_push_payload_address;
      LsuL1Plugin_logic_writeback_slots_1_way <= LsuL1Plugin_logic_writeback_push_payload_way;
      LsuL1Plugin_logic_writeback_slots_1_timer_counter <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_1_writeCmdDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_1_priority <= 7'h7f;
      LsuL1Plugin_logic_writeback_slots_1_readCmdDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_1_readRspDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_1_victimBufferReady <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_0_free) begin
      LsuL1Plugin_logic_writeback_slots_2_priority[0] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_1_free) begin
      LsuL1Plugin_logic_writeback_slots_2_priority[1] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_3_free) begin
      LsuL1Plugin_logic_writeback_slots_2_priority[2] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_4_free) begin
      LsuL1Plugin_logic_writeback_slots_2_priority[3] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_5_free) begin
      LsuL1Plugin_logic_writeback_slots_2_priority[4] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_6_free) begin
      LsuL1Plugin_logic_writeback_slots_2_priority[5] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_7_free) begin
      LsuL1Plugin_logic_writeback_slots_2_priority[6] <= 1'b0;
    end
    if(when_LsuL1Plugin_l566_2) begin
      LsuL1Plugin_logic_writeback_slots_2_address <= LsuL1Plugin_logic_writeback_push_payload_address;
      LsuL1Plugin_logic_writeback_slots_2_way <= LsuL1Plugin_logic_writeback_push_payload_way;
      LsuL1Plugin_logic_writeback_slots_2_timer_counter <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_2_writeCmdDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_2_priority <= 7'h7f;
      LsuL1Plugin_logic_writeback_slots_2_readCmdDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_2_readRspDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_2_victimBufferReady <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_0_free) begin
      LsuL1Plugin_logic_writeback_slots_3_priority[0] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_1_free) begin
      LsuL1Plugin_logic_writeback_slots_3_priority[1] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_2_free) begin
      LsuL1Plugin_logic_writeback_slots_3_priority[2] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_4_free) begin
      LsuL1Plugin_logic_writeback_slots_3_priority[3] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_5_free) begin
      LsuL1Plugin_logic_writeback_slots_3_priority[4] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_6_free) begin
      LsuL1Plugin_logic_writeback_slots_3_priority[5] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_7_free) begin
      LsuL1Plugin_logic_writeback_slots_3_priority[6] <= 1'b0;
    end
    if(when_LsuL1Plugin_l566_3) begin
      LsuL1Plugin_logic_writeback_slots_3_address <= LsuL1Plugin_logic_writeback_push_payload_address;
      LsuL1Plugin_logic_writeback_slots_3_way <= LsuL1Plugin_logic_writeback_push_payload_way;
      LsuL1Plugin_logic_writeback_slots_3_timer_counter <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_3_writeCmdDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_3_priority <= 7'h7f;
      LsuL1Plugin_logic_writeback_slots_3_readCmdDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_3_readRspDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_3_victimBufferReady <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_0_free) begin
      LsuL1Plugin_logic_writeback_slots_4_priority[0] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_1_free) begin
      LsuL1Plugin_logic_writeback_slots_4_priority[1] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_2_free) begin
      LsuL1Plugin_logic_writeback_slots_4_priority[2] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_3_free) begin
      LsuL1Plugin_logic_writeback_slots_4_priority[3] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_5_free) begin
      LsuL1Plugin_logic_writeback_slots_4_priority[4] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_6_free) begin
      LsuL1Plugin_logic_writeback_slots_4_priority[5] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_7_free) begin
      LsuL1Plugin_logic_writeback_slots_4_priority[6] <= 1'b0;
    end
    if(when_LsuL1Plugin_l566_4) begin
      LsuL1Plugin_logic_writeback_slots_4_address <= LsuL1Plugin_logic_writeback_push_payload_address;
      LsuL1Plugin_logic_writeback_slots_4_way <= LsuL1Plugin_logic_writeback_push_payload_way;
      LsuL1Plugin_logic_writeback_slots_4_timer_counter <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_4_writeCmdDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_4_priority <= 7'h7f;
      LsuL1Plugin_logic_writeback_slots_4_readCmdDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_4_readRspDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_4_victimBufferReady <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_0_free) begin
      LsuL1Plugin_logic_writeback_slots_5_priority[0] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_1_free) begin
      LsuL1Plugin_logic_writeback_slots_5_priority[1] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_2_free) begin
      LsuL1Plugin_logic_writeback_slots_5_priority[2] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_3_free) begin
      LsuL1Plugin_logic_writeback_slots_5_priority[3] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_4_free) begin
      LsuL1Plugin_logic_writeback_slots_5_priority[4] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_6_free) begin
      LsuL1Plugin_logic_writeback_slots_5_priority[5] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_7_free) begin
      LsuL1Plugin_logic_writeback_slots_5_priority[6] <= 1'b0;
    end
    if(when_LsuL1Plugin_l566_5) begin
      LsuL1Plugin_logic_writeback_slots_5_address <= LsuL1Plugin_logic_writeback_push_payload_address;
      LsuL1Plugin_logic_writeback_slots_5_way <= LsuL1Plugin_logic_writeback_push_payload_way;
      LsuL1Plugin_logic_writeback_slots_5_timer_counter <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_5_writeCmdDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_5_priority <= 7'h7f;
      LsuL1Plugin_logic_writeback_slots_5_readCmdDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_5_readRspDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_5_victimBufferReady <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_0_free) begin
      LsuL1Plugin_logic_writeback_slots_6_priority[0] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_1_free) begin
      LsuL1Plugin_logic_writeback_slots_6_priority[1] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_2_free) begin
      LsuL1Plugin_logic_writeback_slots_6_priority[2] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_3_free) begin
      LsuL1Plugin_logic_writeback_slots_6_priority[3] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_4_free) begin
      LsuL1Plugin_logic_writeback_slots_6_priority[4] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_5_free) begin
      LsuL1Plugin_logic_writeback_slots_6_priority[5] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_7_free) begin
      LsuL1Plugin_logic_writeback_slots_6_priority[6] <= 1'b0;
    end
    if(when_LsuL1Plugin_l566_6) begin
      LsuL1Plugin_logic_writeback_slots_6_address <= LsuL1Plugin_logic_writeback_push_payload_address;
      LsuL1Plugin_logic_writeback_slots_6_way <= LsuL1Plugin_logic_writeback_push_payload_way;
      LsuL1Plugin_logic_writeback_slots_6_timer_counter <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_6_writeCmdDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_6_priority <= 7'h7f;
      LsuL1Plugin_logic_writeback_slots_6_readCmdDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_6_readRspDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_6_victimBufferReady <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_0_free) begin
      LsuL1Plugin_logic_writeback_slots_7_priority[0] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_1_free) begin
      LsuL1Plugin_logic_writeback_slots_7_priority[1] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_2_free) begin
      LsuL1Plugin_logic_writeback_slots_7_priority[2] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_3_free) begin
      LsuL1Plugin_logic_writeback_slots_7_priority[3] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_4_free) begin
      LsuL1Plugin_logic_writeback_slots_7_priority[4] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_5_free) begin
      LsuL1Plugin_logic_writeback_slots_7_priority[5] <= 1'b0;
    end
    if(LsuL1Plugin_logic_writeback_slots_6_free) begin
      LsuL1Plugin_logic_writeback_slots_7_priority[6] <= 1'b0;
    end
    if(when_LsuL1Plugin_l566_7) begin
      LsuL1Plugin_logic_writeback_slots_7_address <= LsuL1Plugin_logic_writeback_push_payload_address;
      LsuL1Plugin_logic_writeback_slots_7_way <= LsuL1Plugin_logic_writeback_push_payload_way;
      LsuL1Plugin_logic_writeback_slots_7_timer_counter <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_7_writeCmdDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_7_priority <= 7'h7f;
      LsuL1Plugin_logic_writeback_slots_7_readCmdDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_7_readRspDone <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_7_victimBufferReady <= 1'b0;
    end
    if(when_LsuL1Plugin_l610) begin
      if(LsuL1Plugin_logic_writeback_read_arbiter_oh[0]) begin
        LsuL1Plugin_logic_writeback_slots_0_readCmdDone <= 1'b1;
      end
      if(_zz_LsuL1Plugin_logic_writeback_read_arbiter_sel) begin
        LsuL1Plugin_logic_writeback_slots_1_readCmdDone <= 1'b1;
      end
      if(_zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_1) begin
        LsuL1Plugin_logic_writeback_slots_2_readCmdDone <= 1'b1;
      end
      if(_zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_2) begin
        LsuL1Plugin_logic_writeback_slots_3_readCmdDone <= 1'b1;
      end
      if(_zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_3) begin
        LsuL1Plugin_logic_writeback_slots_4_readCmdDone <= 1'b1;
      end
      if(_zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_4) begin
        LsuL1Plugin_logic_writeback_slots_5_readCmdDone <= 1'b1;
      end
      if(_zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_5) begin
        LsuL1Plugin_logic_writeback_slots_6_readCmdDone <= 1'b1;
      end
      if(_zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_6) begin
        LsuL1Plugin_logic_writeback_slots_7_readCmdDone <= 1'b1;
      end
    end
    if(LsuL1Plugin_logic_writeback_read_slotRead_valid) begin
      LsuL1Plugin_logic_refill_slots_0_victim[LsuL1Plugin_logic_writeback_read_slotRead_payload_id] <= 1'b0;
      LsuL1Plugin_logic_refill_slots_1_victim[LsuL1Plugin_logic_writeback_read_slotRead_payload_id] <= 1'b0;
      LsuL1Plugin_logic_refill_slots_2_victim[LsuL1Plugin_logic_writeback_read_slotRead_payload_id] <= 1'b0;
      LsuL1Plugin_logic_refill_slots_3_victim[LsuL1Plugin_logic_writeback_read_slotRead_payload_id] <= 1'b0;
      LsuL1Plugin_logic_refill_slots_4_victim[LsuL1Plugin_logic_writeback_read_slotRead_payload_id] <= 1'b0;
      LsuL1Plugin_logic_refill_slots_5_victim[LsuL1Plugin_logic_writeback_read_slotRead_payload_id] <= 1'b0;
      LsuL1Plugin_logic_refill_slots_6_victim[LsuL1Plugin_logic_writeback_read_slotRead_payload_id] <= 1'b0;
      LsuL1Plugin_logic_refill_slots_7_victim[LsuL1Plugin_logic_writeback_read_slotRead_payload_id] <= 1'b0;
    end
    LsuL1Plugin_logic_writeback_read_slotReadLast_payload_id <= LsuL1Plugin_logic_writeback_read_slotRead_payload_id;
    LsuL1Plugin_logic_writeback_read_slotReadLast_payload_last <= LsuL1Plugin_logic_writeback_read_slotRead_payload_last;
    LsuL1Plugin_logic_writeback_read_slotReadLast_payload_wordIndex <= LsuL1Plugin_logic_writeback_read_slotRead_payload_wordIndex;
    LsuL1Plugin_logic_writeback_read_slotReadLast_payload_way <= LsuL1Plugin_logic_writeback_read_slotRead_payload_way;
    if(LsuL1Plugin_logic_writeback_read_slotReadLast_valid) begin
      case(LsuL1Plugin_logic_writeback_read_slotReadLast_payload_id)
        3'b000 : begin
          LsuL1Plugin_logic_writeback_slots_0_victimBufferReady <= 1'b1;
        end
        3'b001 : begin
          LsuL1Plugin_logic_writeback_slots_1_victimBufferReady <= 1'b1;
        end
        3'b010 : begin
          LsuL1Plugin_logic_writeback_slots_2_victimBufferReady <= 1'b1;
        end
        3'b011 : begin
          LsuL1Plugin_logic_writeback_slots_3_victimBufferReady <= 1'b1;
        end
        3'b100 : begin
          LsuL1Plugin_logic_writeback_slots_4_victimBufferReady <= 1'b1;
        end
        3'b101 : begin
          LsuL1Plugin_logic_writeback_slots_5_victimBufferReady <= 1'b1;
        end
        3'b110 : begin
          LsuL1Plugin_logic_writeback_slots_6_victimBufferReady <= 1'b1;
        end
        default : begin
          LsuL1Plugin_logic_writeback_slots_7_victimBufferReady <= 1'b1;
        end
      endcase
      if(LsuL1Plugin_logic_writeback_read_slotReadLast_payload_last) begin
        case(LsuL1Plugin_logic_writeback_read_slotReadLast_payload_id)
          3'b000 : begin
            LsuL1Plugin_logic_writeback_slots_0_readRspDone <= 1'b1;
          end
          3'b001 : begin
            LsuL1Plugin_logic_writeback_slots_1_readRspDone <= 1'b1;
          end
          3'b010 : begin
            LsuL1Plugin_logic_writeback_slots_2_readRspDone <= 1'b1;
          end
          3'b011 : begin
            LsuL1Plugin_logic_writeback_slots_3_readRspDone <= 1'b1;
          end
          3'b100 : begin
            LsuL1Plugin_logic_writeback_slots_4_readRspDone <= 1'b1;
          end
          3'b101 : begin
            LsuL1Plugin_logic_writeback_slots_5_readRspDone <= 1'b1;
          end
          3'b110 : begin
            LsuL1Plugin_logic_writeback_slots_6_readRspDone <= 1'b1;
          end
          default : begin
            LsuL1Plugin_logic_writeback_slots_7_readRspDone <= 1'b1;
          end
        endcase
      end
    end
    if(when_LsuL1Plugin_l681) begin
      if(LsuL1Plugin_logic_writeback_write_arbiter_oh[0]) begin
        LsuL1Plugin_logic_writeback_slots_0_writeCmdDone <= 1'b1;
      end
      if(_zz_LsuL1Plugin_logic_writeback_write_arbiter_sel) begin
        LsuL1Plugin_logic_writeback_slots_1_writeCmdDone <= 1'b1;
      end
      if(_zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_1) begin
        LsuL1Plugin_logic_writeback_slots_2_writeCmdDone <= 1'b1;
      end
      if(_zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_2) begin
        LsuL1Plugin_logic_writeback_slots_3_writeCmdDone <= 1'b1;
      end
      if(_zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_3) begin
        LsuL1Plugin_logic_writeback_slots_4_writeCmdDone <= 1'b1;
      end
      if(_zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_4) begin
        LsuL1Plugin_logic_writeback_slots_5_writeCmdDone <= 1'b1;
      end
      if(_zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_5) begin
        LsuL1Plugin_logic_writeback_slots_6_writeCmdDone <= 1'b1;
      end
      if(_zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_6) begin
        LsuL1Plugin_logic_writeback_slots_7_writeCmdDone <= 1'b1;
      end
    end
    if(LsuL1Plugin_logic_writeback_write_bufferRead_ready) begin
      LsuL1Plugin_logic_writeback_write_bufferRead_rData_id <= LsuL1Plugin_logic_writeback_write_bufferRead_payload_id;
      LsuL1Plugin_logic_writeback_write_bufferRead_rData_address <= LsuL1Plugin_logic_writeback_write_bufferRead_payload_address;
      LsuL1Plugin_logic_writeback_write_bufferRead_rData_last <= LsuL1Plugin_logic_writeback_write_bufferRead_payload_last;
    end
    CsrAccessPlugin_logic_fsm_interface_read <= ((execute_ctrl2_down_CsrAccessPlugin_SEL_lane0 && (! CsrAccessPlugin_logic_fsm_inject_trap)) && CsrAccessPlugin_logic_fsm_inject_csrRead);
    CsrAccessPlugin_logic_fsm_interface_write <= ((execute_ctrl2_down_CsrAccessPlugin_SEL_lane0 && (! CsrAccessPlugin_logic_fsm_inject_trap)) && CsrAccessPlugin_logic_fsm_inject_csrWrite);
    CsrAccessPlugin_logic_fsm_interface_csrId <= CsrAccessPlugin_logic_fsm_inject_csrAddress;
    CsrAccessPlugin_logic_fsm_inject_trapReg <= CsrAccessPlugin_logic_fsm_inject_trap;
    CsrAccessPlugin_logic_fsm_inject_busTrapReg <= CsrAccessPlugin_bus_decode_trap;
    CsrAccessPlugin_logic_fsm_inject_busTrapCodeReg <= CsrAccessPlugin_bus_decode_trapCode;
    CsrAccessPlugin_logic_fsm_interface_onWriteBits <= CsrAccessPlugin_logic_fsm_writeLogic_alu_result;
    if(LsuPlugin_logic_onAddress0_flush_port_fire) begin
      LsuPlugin_logic_flusher_cmdCounter <= (LsuPlugin_logic_flusher_cmdCounter + 7'h01);
    end
    if(LsuPlugin_logic_bus_rsp_toStream_ready) begin
      LsuPlugin_logic_bus_rsp_toStream_rData_error <= LsuPlugin_logic_bus_rsp_toStream_payload_error;
      LsuPlugin_logic_bus_rsp_toStream_rData_data <= LsuPlugin_logic_bus_rsp_toStream_payload_data;
    end
    if(when_LsuPlugin_l1077) begin
      LsuPlugin_logic_flusher_cmdCounter <= {1'd0, _zz_LsuPlugin_logic_flusher_cmdCounter};
    end
    if(when_LsuPlugin_l1082) begin
      if(LsuPlugin_logic_onCtrl_traps_l1Failed) begin
        if(when_LsuPlugin_l1085) begin
          if(when_LsuPlugin_l311) begin
            LsuPlugin_logic_storeBuffer_waitL1_refill <= execute_ctrl4_down_LsuL1_WAIT_REFILL_lane0;
          end
        end
      end
    end
    if(when_LsuPlugin_l1121) begin
      if(when_LsuPlugin_l311_1) begin
        LsuPlugin_logic_onCtrl_hartRegulation_refill <= execute_ctrl4_down_LsuL1_WAIT_REFILL_lane0;
      end
    end
    if(LsuPlugin_logic_storeBuffer_ops_pip_node_0_isReady) begin
      LsuPlugin_logic_storeBuffer_ops_pip_node_1_SB_PTR <= LsuPlugin_logic_storeBuffer_ops_pip_node_0_SB_PTR;
    end
    if(LsuPlugin_logic_storeBuffer_ops_pip_node_1_isReady) begin
      LsuPlugin_logic_storeBuffer_ops_pip_node_2_SB_PTR <= LsuPlugin_logic_storeBuffer_ops_pip_node_1_SB_PTR;
      LsuPlugin_logic_storeBuffer_ops_pip_node_2_read_OPS_address <= LsuPlugin_logic_storeBuffer_ops_pip_node_1_read_OPS_address;
      LsuPlugin_logic_storeBuffer_ops_pip_node_2_read_OPS_data <= LsuPlugin_logic_storeBuffer_ops_pip_node_1_read_OPS_data;
      LsuPlugin_logic_storeBuffer_ops_pip_node_2_read_OPS_size <= LsuPlugin_logic_storeBuffer_ops_pip_node_1_read_OPS_size;
      LsuPlugin_logic_storeBuffer_ops_pip_node_2_read_OPS_storeId <= LsuPlugin_logic_storeBuffer_ops_pip_node_1_read_OPS_storeId;
    end
    LsuL1Plugin_logic_bus_toTilelink_nonCoherent_onA_selReg <= LsuL1Plugin_logic_bus_toTilelink_nonCoherent_onA_sel;
    if(PrefetcherRptPlugin_logic_order_toFlowFire_valid) begin
      PrefetcherRptPlugin_logic_onCtrl_lastOrder_address <= PrefetcherRptPlugin_logic_order_toFlowFire_payload_address;
      PrefetcherRptPlugin_logic_onCtrl_lastOrder_unique <= PrefetcherRptPlugin_logic_order_toFlowFire_payload_unique;
      PrefetcherRptPlugin_logic_onCtrl_lastOrder_from <= PrefetcherRptPlugin_logic_order_toFlowFire_payload_from;
      PrefetcherRptPlugin_logic_onCtrl_lastOrder_to <= PrefetcherRptPlugin_logic_order_toFlowFire_payload_to;
      PrefetcherRptPlugin_logic_onCtrl_lastOrder_stride <= PrefetcherRptPlugin_logic_order_toFlowFire_payload_stride;
    end
    PrefetcherRptPlugin_logic_pip_node_1_PROBE_pc <= PrefetcherRptPlugin_logic_pip_node_0_PROBE_pc;
    PrefetcherRptPlugin_logic_pip_node_1_PROBE_address <= PrefetcherRptPlugin_logic_pip_node_0_PROBE_address;
    PrefetcherRptPlugin_logic_pip_node_1_PROBE_load <= PrefetcherRptPlugin_logic_pip_node_0_PROBE_load;
    PrefetcherRptPlugin_logic_pip_node_1_PROBE_store <= PrefetcherRptPlugin_logic_pip_node_0_PROBE_store;
    PrefetcherRptPlugin_logic_pip_node_1_PROBE_trap <= PrefetcherRptPlugin_logic_pip_node_0_PROBE_trap;
    PrefetcherRptPlugin_logic_pip_node_1_PROBE_io <= PrefetcherRptPlugin_logic_pip_node_0_PROBE_io;
    PrefetcherRptPlugin_logic_pip_node_1_PROBE_prefetchFailed <= PrefetcherRptPlugin_logic_pip_node_0_PROBE_prefetchFailed;
    PrefetcherRptPlugin_logic_pip_node_1_PROBE_miss <= PrefetcherRptPlugin_logic_pip_node_0_PROBE_miss;
    PrefetcherRptPlugin_logic_pip_node_1_onRead0_WRITTEN_valid <= PrefetcherRptPlugin_logic_pip_node_0_onRead0_WRITTEN_valid;
    PrefetcherRptPlugin_logic_pip_node_1_onRead0_WRITTEN_payload_address <= PrefetcherRptPlugin_logic_pip_node_0_onRead0_WRITTEN_payload_address;
    PrefetcherRptPlugin_logic_pip_node_1_onRead0_WRITTEN_payload_data_tag <= PrefetcherRptPlugin_logic_pip_node_0_onRead0_WRITTEN_payload_data_tag;
    PrefetcherRptPlugin_logic_pip_node_1_onRead0_WRITTEN_payload_data_address <= PrefetcherRptPlugin_logic_pip_node_0_onRead0_WRITTEN_payload_data_address;
    PrefetcherRptPlugin_logic_pip_node_1_onRead0_WRITTEN_payload_data_stride <= PrefetcherRptPlugin_logic_pip_node_0_onRead0_WRITTEN_payload_data_stride;
    PrefetcherRptPlugin_logic_pip_node_1_onRead0_WRITTEN_payload_data_score <= PrefetcherRptPlugin_logic_pip_node_0_onRead0_WRITTEN_payload_data_score;
    PrefetcherRptPlugin_logic_pip_node_1_onRead0_WRITTEN_payload_data_advance <= PrefetcherRptPlugin_logic_pip_node_0_onRead0_WRITTEN_payload_data_advance;
    PrefetcherRptPlugin_logic_pip_node_1_onRead0_WRITTEN_payload_data_missed <= PrefetcherRptPlugin_logic_pip_node_0_onRead0_WRITTEN_payload_data_missed;
    PrefetcherRptPlugin_logic_pip_node_2_PROBE_pc <= PrefetcherRptPlugin_logic_pip_node_1_PROBE_pc;
    PrefetcherRptPlugin_logic_pip_node_2_PROBE_address <= PrefetcherRptPlugin_logic_pip_node_1_PROBE_address;
    PrefetcherRptPlugin_logic_pip_node_2_PROBE_load <= PrefetcherRptPlugin_logic_pip_node_1_PROBE_load;
    PrefetcherRptPlugin_logic_pip_node_2_PROBE_store <= PrefetcherRptPlugin_logic_pip_node_1_PROBE_store;
    PrefetcherRptPlugin_logic_pip_node_2_PROBE_trap <= PrefetcherRptPlugin_logic_pip_node_1_PROBE_trap;
    PrefetcherRptPlugin_logic_pip_node_2_PROBE_io <= PrefetcherRptPlugin_logic_pip_node_1_PROBE_io;
    PrefetcherRptPlugin_logic_pip_node_2_PROBE_prefetchFailed <= PrefetcherRptPlugin_logic_pip_node_1_PROBE_prefetchFailed;
    PrefetcherRptPlugin_logic_pip_node_2_PROBE_miss <= PrefetcherRptPlugin_logic_pip_node_1_PROBE_miss;
    PrefetcherRptPlugin_logic_pip_node_2_ENTRY_tag <= PrefetcherRptPlugin_logic_pip_node_1_ENTRY_tag;
    PrefetcherRptPlugin_logic_pip_node_2_ENTRY_address <= PrefetcherRptPlugin_logic_pip_node_1_ENTRY_address;
    PrefetcherRptPlugin_logic_pip_node_2_ENTRY_stride <= PrefetcherRptPlugin_logic_pip_node_1_ENTRY_stride;
    PrefetcherRptPlugin_logic_pip_node_2_ENTRY_score <= PrefetcherRptPlugin_logic_pip_node_1_ENTRY_score;
    PrefetcherRptPlugin_logic_pip_node_2_ENTRY_advance <= PrefetcherRptPlugin_logic_pip_node_1_ENTRY_advance;
    PrefetcherRptPlugin_logic_pip_node_2_ENTRY_missed <= PrefetcherRptPlugin_logic_pip_node_1_ENTRY_missed;
    PrefetcherRptPlugin_logic_pip_node_2_TAG_HIT <= PrefetcherRptPlugin_logic_pip_node_1_TAG_HIT;
    PrefetcherRptPlugin_logic_pip_node_2_STRIDE_EXTENDED <= PrefetcherRptPlugin_logic_pip_node_1_STRIDE_EXTENDED;
    PrefetcherRptPlugin_logic_pip_node_2_NEW_BLOCK <= PrefetcherRptPlugin_logic_pip_node_1_NEW_BLOCK;
    if(fetch_logic_ctrls_0_down_isReady) begin
      fetch_logic_ctrls_1_up_Fetch_WORD_PC <= fetch_logic_ctrls_0_down_Fetch_WORD_PC;
      fetch_logic_ctrls_1_up_Fetch_PC_FAULT <= fetch_logic_ctrls_0_down_Fetch_PC_FAULT;
      fetch_logic_ctrls_1_up_Fetch_ID <= fetch_logic_ctrls_0_down_Fetch_ID;
      fetch_logic_ctrls_1_up_FetchL1Plugin_logic_cmd_PLRU_BYPASS_VALID <= fetch_logic_ctrls_0_down_FetchL1Plugin_logic_cmd_PLRU_BYPASS_VALID;
      fetch_logic_ctrls_1_up_FetchL1Plugin_logic_cmd_PLRU_BYPASS_DATA_0 <= fetch_logic_ctrls_0_down_FetchL1Plugin_logic_cmd_PLRU_BYPASS_DATA_0;
      fetch_logic_ctrls_1_up_FetchL1Plugin_logic_cmd_TAGS_UPDATE <= fetch_logic_ctrls_0_down_FetchL1Plugin_logic_cmd_TAGS_UPDATE;
      fetch_logic_ctrls_1_up_FetchL1Plugin_logic_cmd_TAGS_UPDATE_ADDRESS <= fetch_logic_ctrls_0_down_FetchL1Plugin_logic_cmd_TAGS_UPDATE_ADDRESS;
      fetch_logic_ctrls_1_up_GSharePlugin_logic_HASH <= fetch_logic_ctrls_0_down_GSharePlugin_logic_HASH;
      fetch_logic_ctrls_1_up_Prediction_BRANCH_HISTORY <= fetch_logic_ctrls_0_down_Prediction_BRANCH_HISTORY;
      fetch_logic_ctrls_1_up_GSharePlugin_logic_BYPASS_valid <= fetch_logic_ctrls_0_down_GSharePlugin_logic_BYPASS_valid;
      fetch_logic_ctrls_1_up_GSharePlugin_logic_BYPASS_payload_address <= fetch_logic_ctrls_0_down_GSharePlugin_logic_BYPASS_payload_address;
      fetch_logic_ctrls_1_up_GSharePlugin_logic_BYPASS_payload_data_0 <= fetch_logic_ctrls_0_down_GSharePlugin_logic_BYPASS_payload_data_0;
      fetch_logic_ctrls_1_up_GSharePlugin_logic_BYPASS_payload_data_1 <= fetch_logic_ctrls_0_down_GSharePlugin_logic_BYPASS_payload_data_1;
      fetch_logic_ctrls_1_up_GSharePlugin_logic_BYPASS_payload_data_2 <= fetch_logic_ctrls_0_down_GSharePlugin_logic_BYPASS_payload_data_2;
      fetch_logic_ctrls_1_up_GSharePlugin_logic_BYPASS_payload_data_3 <= fetch_logic_ctrls_0_down_GSharePlugin_logic_BYPASS_payload_data_3;
      fetch_logic_ctrls_1_up_BtbPlugin_logic_readCmd_HAZARDS <= fetch_logic_ctrls_0_down_BtbPlugin_logic_readCmd_HAZARDS;
    end
    if(fetch_logic_ctrls_1_down_isReady) begin
      fetch_logic_ctrls_2_up_Fetch_WORD_PC <= fetch_logic_ctrls_1_down_Fetch_WORD_PC;
      fetch_logic_ctrls_2_up_Fetch_PC_FAULT <= fetch_logic_ctrls_1_down_Fetch_PC_FAULT;
      fetch_logic_ctrls_2_up_Fetch_ID <= fetch_logic_ctrls_1_down_Fetch_ID;
      fetch_logic_ctrls_2_up_Prediction_BRANCH_HISTORY <= fetch_logic_ctrls_1_down_Prediction_BRANCH_HISTORY;
      fetch_logic_ctrls_2_up_FetchL1Plugin_logic_WAYS_TAGS_0_loaded <= fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_TAGS_0_loaded;
      fetch_logic_ctrls_2_up_FetchL1Plugin_logic_WAYS_TAGS_0_error <= fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_TAGS_0_error;
      fetch_logic_ctrls_2_up_FetchL1Plugin_logic_WAYS_TAGS_0_address <= fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_TAGS_0_address;
      fetch_logic_ctrls_2_up_FetchL1Plugin_logic_WAYS_TAGS_1_loaded <= fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_TAGS_1_loaded;
      fetch_logic_ctrls_2_up_FetchL1Plugin_logic_WAYS_TAGS_1_error <= fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_TAGS_1_error;
      fetch_logic_ctrls_2_up_FetchL1Plugin_logic_WAYS_TAGS_1_address <= fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_TAGS_1_address;
      fetch_logic_ctrls_2_up_FetchL1Plugin_logic_onAddress0_translationPort_keys_TRANSLATED <= fetch_logic_ctrls_1_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_TRANSLATED;
      _zz_fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress1_translationPort_keys_TRANSLATED <= fetch_logic_ctrls_1_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_TRANSLATED;
      fetch_logic_ctrls_2_up_FetchL1Plugin_logic_PLRU_BYPASSED_0 <= fetch_logic_ctrls_1_down_FetchL1Plugin_logic_PLRU_BYPASSED_0;
      fetch_logic_ctrls_2_up_FetchL1Plugin_logic_BANKS_MUXES_0 <= fetch_logic_ctrls_1_down_FetchL1Plugin_logic_BANKS_MUXES_0;
      fetch_logic_ctrls_2_up_FetchL1Plugin_logic_BANKS_MUXES_1 <= fetch_logic_ctrls_1_down_FetchL1Plugin_logic_BANKS_MUXES_1;
      fetch_logic_ctrls_2_up_FetchL1Plugin_logic_HAZARD <= fetch_logic_ctrls_1_down_FetchL1Plugin_logic_HAZARD;
      fetch_logic_ctrls_2_up_FetchL1Plugin_logic_WAYS_HITS_0 <= fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_HITS_0;
      fetch_logic_ctrls_2_up_FetchL1Plugin_logic_WAYS_HITS_1 <= fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_HITS_1;
      fetch_logic_ctrls_2_up_FetchL1Plugin_logic_WAYS_HIT <= fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_HIT;
      fetch_logic_ctrls_2_up_GSharePlugin_GSHARE_COUNTER_0 <= fetch_logic_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_0;
      fetch_logic_ctrls_2_up_GSharePlugin_GSHARE_COUNTER_1 <= fetch_logic_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_1;
      fetch_logic_ctrls_2_up_GSharePlugin_GSHARE_COUNTER_2 <= fetch_logic_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_2;
      fetch_logic_ctrls_2_up_GSharePlugin_GSHARE_COUNTER_3 <= fetch_logic_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_3;
      fetch_logic_ctrls_2_up_Prediction_WORD_JUMPED <= fetch_logic_ctrls_1_down_Prediction_WORD_JUMPED;
      fetch_logic_ctrls_2_up_Prediction_WORD_JUMP_SLICE <= fetch_logic_ctrls_1_down_Prediction_WORD_JUMP_SLICE;
      fetch_logic_ctrls_2_up_Prediction_WORD_JUMP_PC <= fetch_logic_ctrls_1_down_Prediction_WORD_JUMP_PC;
      fetch_logic_ctrls_2_up_Prediction_WORD_SLICES_BRANCH <= fetch_logic_ctrls_1_down_Prediction_WORD_SLICES_BRANCH;
      fetch_logic_ctrls_2_up_Prediction_WORD_SLICES_TAKEN <= fetch_logic_ctrls_1_down_Prediction_WORD_SLICES_TAKEN;
      fetch_logic_ctrls_2_up_FetchL1Plugin_logic_onAddress0_translationPort_keys_REFILL <= fetch_logic_ctrls_1_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_REFILL;
      fetch_logic_ctrls_2_up_FetchL1Plugin_logic_onAddress0_translationPort_keys_HAZARD <= fetch_logic_ctrls_1_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_HAZARD;
      fetch_logic_ctrls_2_up_FetchL1Plugin_logic_onAddress0_translationPort_keys_PAGE_FAULT <= fetch_logic_ctrls_1_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_PAGE_FAULT;
      fetch_logic_ctrls_2_up_FetchL1Plugin_logic_onAddress0_translationPort_keys_ACCESS_FAULT <= fetch_logic_ctrls_1_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_ACCESS_FAULT;
      fetch_logic_ctrls_2_up_FetchL1Plugin_logic_onAddress0_translationPort_keys_BYPASS_TRANSLATION <= fetch_logic_ctrls_1_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_BYPASS_TRANSLATION;
    end
    if(decode_ctrls_0_down_isReady) begin
      decode_ctrls_1_up_Decode_INSTRUCTION_0 <= decode_ctrls_0_down_Decode_INSTRUCTION_0;
      decode_ctrls_1_up_Decode_DECOMPRESSION_FAULT_0 <= decode_ctrls_0_down_Decode_DECOMPRESSION_FAULT_0;
      decode_ctrls_1_up_Decode_INSTRUCTION_RAW_0 <= decode_ctrls_0_down_Decode_INSTRUCTION_RAW_0;
      decode_ctrls_1_up_Decode_INSTRUCTION_SLICE_COUNT_0 <= decode_ctrls_0_down_Decode_INSTRUCTION_SLICE_COUNT_0;
      decode_ctrls_1_up_PC_0 <= decode_ctrls_0_down_PC_0;
      decode_ctrls_1_up_Decode_DOP_ID_0 <= decode_ctrls_0_down_Decode_DOP_ID_0;
      decode_ctrls_1_up_Fetch_ID_0 <= decode_ctrls_0_down_Fetch_ID_0;
      decode_ctrls_1_up_GSharePlugin_GSHARE_COUNTER_0_0 <= decode_ctrls_0_down_GSharePlugin_GSHARE_COUNTER_0_0;
      decode_ctrls_1_up_GSharePlugin_GSHARE_COUNTER_0_1 <= decode_ctrls_0_down_GSharePlugin_GSHARE_COUNTER_0_1;
      decode_ctrls_1_up_GSharePlugin_GSHARE_COUNTER_0_2 <= decode_ctrls_0_down_GSharePlugin_GSHARE_COUNTER_0_2;
      decode_ctrls_1_up_GSharePlugin_GSHARE_COUNTER_0_3 <= decode_ctrls_0_down_GSharePlugin_GSHARE_COUNTER_0_3;
      decode_ctrls_1_up_Prediction_BRANCH_HISTORY_0 <= decode_ctrls_0_down_Prediction_BRANCH_HISTORY_0;
      decode_ctrls_1_up_TRAP_0 <= decode_ctrls_0_down_TRAP_0;
      decode_ctrls_1_up_Prediction_ALIGNED_JUMPED_0 <= decode_ctrls_0_down_Prediction_ALIGNED_JUMPED_0;
      decode_ctrls_1_up_Prediction_ALIGNED_JUMPED_PC_0 <= decode_ctrls_0_down_Prediction_ALIGNED_JUMPED_PC_0;
      decode_ctrls_1_up_Prediction_ALIGNED_SLICES_BRANCH_0 <= decode_ctrls_0_down_Prediction_ALIGNED_SLICES_BRANCH_0;
      decode_ctrls_1_up_Prediction_ALIGNED_SLICES_TAKEN_0 <= decode_ctrls_0_down_Prediction_ALIGNED_SLICES_TAKEN_0;
      decode_ctrls_1_up_Prediction_ALIGN_REDO_0 <= decode_ctrls_0_down_Prediction_ALIGN_REDO_0;
      decode_ctrls_1_up_Decode_INSTRUCTION_1 <= decode_ctrls_0_down_Decode_INSTRUCTION_1;
      decode_ctrls_1_up_Decode_DECOMPRESSION_FAULT_1 <= decode_ctrls_0_down_Decode_DECOMPRESSION_FAULT_1;
      decode_ctrls_1_up_Decode_INSTRUCTION_RAW_1 <= decode_ctrls_0_down_Decode_INSTRUCTION_RAW_1;
      decode_ctrls_1_up_Decode_INSTRUCTION_SLICE_COUNT_1 <= decode_ctrls_0_down_Decode_INSTRUCTION_SLICE_COUNT_1;
      decode_ctrls_1_up_PC_1 <= decode_ctrls_0_down_PC_1;
      decode_ctrls_1_up_Decode_DOP_ID_1 <= decode_ctrls_0_down_Decode_DOP_ID_1;
      decode_ctrls_1_up_Fetch_ID_1 <= decode_ctrls_0_down_Fetch_ID_1;
      decode_ctrls_1_up_GSharePlugin_GSHARE_COUNTER_1_0 <= decode_ctrls_0_down_GSharePlugin_GSHARE_COUNTER_1_0;
      decode_ctrls_1_up_GSharePlugin_GSHARE_COUNTER_1_1 <= decode_ctrls_0_down_GSharePlugin_GSHARE_COUNTER_1_1;
      decode_ctrls_1_up_GSharePlugin_GSHARE_COUNTER_1_2 <= decode_ctrls_0_down_GSharePlugin_GSHARE_COUNTER_1_2;
      decode_ctrls_1_up_GSharePlugin_GSHARE_COUNTER_1_3 <= decode_ctrls_0_down_GSharePlugin_GSHARE_COUNTER_1_3;
      decode_ctrls_1_up_Prediction_BRANCH_HISTORY_1 <= decode_ctrls_0_down_Prediction_BRANCH_HISTORY_1;
      decode_ctrls_1_up_TRAP_1 <= decode_ctrls_0_down_TRAP_1;
      decode_ctrls_1_up_Prediction_ALIGNED_JUMPED_1 <= decode_ctrls_0_down_Prediction_ALIGNED_JUMPED_1;
      decode_ctrls_1_up_Prediction_ALIGNED_JUMPED_PC_1 <= decode_ctrls_0_down_Prediction_ALIGNED_JUMPED_PC_1;
      decode_ctrls_1_up_Prediction_ALIGNED_SLICES_BRANCH_1 <= decode_ctrls_0_down_Prediction_ALIGNED_SLICES_BRANCH_1;
      decode_ctrls_1_up_Prediction_ALIGNED_SLICES_TAKEN_1 <= decode_ctrls_0_down_Prediction_ALIGNED_SLICES_TAKEN_1;
      decode_ctrls_1_up_Prediction_ALIGN_REDO_1 <= decode_ctrls_0_down_Prediction_ALIGN_REDO_1;
    end
    if(execute_ctrl0_down_isReady) begin
      execute_ctrl1_up_Decode_UOP_lane0 <= execute_ctrl0_down_Decode_UOP_lane0;
      execute_ctrl1_up_Prediction_ALIGNED_JUMPED_lane0 <= execute_ctrl0_down_Prediction_ALIGNED_JUMPED_lane0;
      execute_ctrl1_up_Prediction_ALIGNED_JUMPED_PC_lane0 <= execute_ctrl0_down_Prediction_ALIGNED_JUMPED_PC_lane0;
      execute_ctrl1_up_Prediction_ALIGNED_SLICES_TAKEN_lane0 <= execute_ctrl0_down_Prediction_ALIGNED_SLICES_TAKEN_lane0;
      execute_ctrl1_up_Prediction_ALIGNED_SLICES_BRANCH_lane0 <= execute_ctrl0_down_Prediction_ALIGNED_SLICES_BRANCH_lane0;
      execute_ctrl1_up_GSharePlugin_GSHARE_COUNTER_lane0_0 <= execute_ctrl0_down_GSharePlugin_GSHARE_COUNTER_lane0_0;
      execute_ctrl1_up_GSharePlugin_GSHARE_COUNTER_lane0_1 <= execute_ctrl0_down_GSharePlugin_GSHARE_COUNTER_lane0_1;
      execute_ctrl1_up_GSharePlugin_GSHARE_COUNTER_lane0_2 <= execute_ctrl0_down_GSharePlugin_GSHARE_COUNTER_lane0_2;
      execute_ctrl1_up_GSharePlugin_GSHARE_COUNTER_lane0_3 <= execute_ctrl0_down_GSharePlugin_GSHARE_COUNTER_lane0_3;
      execute_ctrl1_up_Prediction_BRANCH_HISTORY_lane0 <= execute_ctrl0_down_Prediction_BRANCH_HISTORY_lane0;
      execute_ctrl1_up_Decode_INSTRUCTION_SLICE_COUNT_lane0 <= execute_ctrl0_down_Decode_INSTRUCTION_SLICE_COUNT_lane0;
      execute_ctrl1_up_PC_lane0 <= execute_ctrl0_down_PC_lane0;
      execute_ctrl1_up_TRAP_lane0 <= execute_ctrl0_down_TRAP_lane0;
      execute_ctrl1_up_Decode_UOP_ID_lane0 <= execute_ctrl0_down_Decode_UOP_ID_lane0;
      execute_ctrl1_up_RS1_PHYS_lane0 <= execute_ctrl0_down_RS1_PHYS_lane0;
      execute_ctrl1_up_RS2_PHYS_lane0 <= execute_ctrl0_down_RS2_PHYS_lane0;
      execute_ctrl1_up_RD_ENABLE_lane0 <= execute_ctrl0_down_RD_ENABLE_lane0;
      execute_ctrl1_up_RD_PHYS_lane0 <= execute_ctrl0_down_RD_PHYS_lane0;
      execute_ctrl1_up_LANE_AGE_lane0 <= execute_ctrl0_down_LANE_AGE_lane0;
      execute_ctrl1_up_COMPLETED_lane0 <= execute_ctrl0_down_COMPLETED_lane0;
      execute_ctrl1_up_lane0_LAYER_SEL_lane0 <= execute_ctrl0_down_lane0_LAYER_SEL_lane0;
      execute_ctrl1_up_Decode_UOP_lane1 <= execute_ctrl0_down_Decode_UOP_lane1;
      execute_ctrl1_up_Prediction_ALIGNED_JUMPED_lane1 <= execute_ctrl0_down_Prediction_ALIGNED_JUMPED_lane1;
      execute_ctrl1_up_Prediction_ALIGNED_JUMPED_PC_lane1 <= execute_ctrl0_down_Prediction_ALIGNED_JUMPED_PC_lane1;
      execute_ctrl1_up_Prediction_ALIGNED_SLICES_TAKEN_lane1 <= execute_ctrl0_down_Prediction_ALIGNED_SLICES_TAKEN_lane1;
      execute_ctrl1_up_Prediction_ALIGNED_SLICES_BRANCH_lane1 <= execute_ctrl0_down_Prediction_ALIGNED_SLICES_BRANCH_lane1;
      execute_ctrl1_up_GSharePlugin_GSHARE_COUNTER_lane1_0 <= execute_ctrl0_down_GSharePlugin_GSHARE_COUNTER_lane1_0;
      execute_ctrl1_up_GSharePlugin_GSHARE_COUNTER_lane1_1 <= execute_ctrl0_down_GSharePlugin_GSHARE_COUNTER_lane1_1;
      execute_ctrl1_up_GSharePlugin_GSHARE_COUNTER_lane1_2 <= execute_ctrl0_down_GSharePlugin_GSHARE_COUNTER_lane1_2;
      execute_ctrl1_up_GSharePlugin_GSHARE_COUNTER_lane1_3 <= execute_ctrl0_down_GSharePlugin_GSHARE_COUNTER_lane1_3;
      execute_ctrl1_up_Prediction_BRANCH_HISTORY_lane1 <= execute_ctrl0_down_Prediction_BRANCH_HISTORY_lane1;
      execute_ctrl1_up_Decode_INSTRUCTION_SLICE_COUNT_lane1 <= execute_ctrl0_down_Decode_INSTRUCTION_SLICE_COUNT_lane1;
      execute_ctrl1_up_PC_lane1 <= execute_ctrl0_down_PC_lane1;
      execute_ctrl1_up_TRAP_lane1 <= execute_ctrl0_down_TRAP_lane1;
      execute_ctrl1_up_Decode_UOP_ID_lane1 <= execute_ctrl0_down_Decode_UOP_ID_lane1;
      execute_ctrl1_up_RS1_PHYS_lane1 <= execute_ctrl0_down_RS1_PHYS_lane1;
      execute_ctrl1_up_RS2_PHYS_lane1 <= execute_ctrl0_down_RS2_PHYS_lane1;
      execute_ctrl1_up_RD_ENABLE_lane1 <= execute_ctrl0_down_RD_ENABLE_lane1;
      execute_ctrl1_up_RD_PHYS_lane1 <= execute_ctrl0_down_RD_PHYS_lane1;
      execute_ctrl1_up_LANE_AGE_lane1 <= execute_ctrl0_down_LANE_AGE_lane1;
      execute_ctrl1_up_COMPLETED_lane1 <= execute_ctrl0_down_COMPLETED_lane1;
      execute_ctrl1_up_lane1_LAYER_SEL_lane1 <= execute_ctrl0_down_lane1_LAYER_SEL_lane1;
      execute_ctrl1_up_AguPlugin_SIZE_lane0 <= execute_ctrl0_down_AguPlugin_SIZE_lane0;
    end
    if(execute_ctrl1_down_isReady) begin
      execute_ctrl2_up_Decode_UOP_lane0 <= execute_ctrl1_down_Decode_UOP_lane0;
      execute_ctrl2_up_Prediction_ALIGNED_JUMPED_lane0 <= execute_ctrl1_down_Prediction_ALIGNED_JUMPED_lane0;
      execute_ctrl2_up_Prediction_ALIGNED_JUMPED_PC_lane0 <= execute_ctrl1_down_Prediction_ALIGNED_JUMPED_PC_lane0;
      execute_ctrl2_up_Prediction_ALIGNED_SLICES_TAKEN_lane0 <= execute_ctrl1_down_Prediction_ALIGNED_SLICES_TAKEN_lane0;
      execute_ctrl2_up_Prediction_ALIGNED_SLICES_BRANCH_lane0 <= execute_ctrl1_down_Prediction_ALIGNED_SLICES_BRANCH_lane0;
      execute_ctrl2_up_GSharePlugin_GSHARE_COUNTER_lane0_0 <= execute_ctrl1_down_GSharePlugin_GSHARE_COUNTER_lane0_0;
      execute_ctrl2_up_GSharePlugin_GSHARE_COUNTER_lane0_1 <= execute_ctrl1_down_GSharePlugin_GSHARE_COUNTER_lane0_1;
      execute_ctrl2_up_GSharePlugin_GSHARE_COUNTER_lane0_2 <= execute_ctrl1_down_GSharePlugin_GSHARE_COUNTER_lane0_2;
      execute_ctrl2_up_GSharePlugin_GSHARE_COUNTER_lane0_3 <= execute_ctrl1_down_GSharePlugin_GSHARE_COUNTER_lane0_3;
      execute_ctrl2_up_Prediction_BRANCH_HISTORY_lane0 <= execute_ctrl1_down_Prediction_BRANCH_HISTORY_lane0;
      execute_ctrl2_up_Decode_INSTRUCTION_SLICE_COUNT_lane0 <= execute_ctrl1_down_Decode_INSTRUCTION_SLICE_COUNT_lane0;
      execute_ctrl2_up_PC_lane0 <= execute_ctrl1_down_PC_lane0;
      execute_ctrl2_up_TRAP_lane0 <= execute_ctrl1_down_TRAP_lane0;
      execute_ctrl2_up_Decode_UOP_ID_lane0 <= execute_ctrl1_down_Decode_UOP_ID_lane0;
      execute_ctrl2_up_RS1_PHYS_lane0 <= execute_ctrl1_down_RS1_PHYS_lane0;
      execute_ctrl2_up_RS2_PHYS_lane0 <= execute_ctrl1_down_RS2_PHYS_lane0;
      execute_ctrl2_up_RD_ENABLE_lane0 <= execute_ctrl1_down_RD_ENABLE_lane0;
      execute_ctrl2_up_RD_PHYS_lane0 <= execute_ctrl1_down_RD_PHYS_lane0;
      execute_ctrl2_up_LANE_AGE_lane0 <= execute_ctrl1_down_LANE_AGE_lane0;
      execute_ctrl2_up_COMPLETED_lane0 <= execute_ctrl1_down_COMPLETED_lane0;
      execute_ctrl2_up_Decode_UOP_lane1 <= execute_ctrl1_down_Decode_UOP_lane1;
      execute_ctrl2_up_Prediction_ALIGNED_JUMPED_lane1 <= execute_ctrl1_down_Prediction_ALIGNED_JUMPED_lane1;
      execute_ctrl2_up_Prediction_ALIGNED_JUMPED_PC_lane1 <= execute_ctrl1_down_Prediction_ALIGNED_JUMPED_PC_lane1;
      execute_ctrl2_up_Prediction_ALIGNED_SLICES_TAKEN_lane1 <= execute_ctrl1_down_Prediction_ALIGNED_SLICES_TAKEN_lane1;
      execute_ctrl2_up_Prediction_ALIGNED_SLICES_BRANCH_lane1 <= execute_ctrl1_down_Prediction_ALIGNED_SLICES_BRANCH_lane1;
      execute_ctrl2_up_GSharePlugin_GSHARE_COUNTER_lane1_0 <= execute_ctrl1_down_GSharePlugin_GSHARE_COUNTER_lane1_0;
      execute_ctrl2_up_GSharePlugin_GSHARE_COUNTER_lane1_1 <= execute_ctrl1_down_GSharePlugin_GSHARE_COUNTER_lane1_1;
      execute_ctrl2_up_GSharePlugin_GSHARE_COUNTER_lane1_2 <= execute_ctrl1_down_GSharePlugin_GSHARE_COUNTER_lane1_2;
      execute_ctrl2_up_GSharePlugin_GSHARE_COUNTER_lane1_3 <= execute_ctrl1_down_GSharePlugin_GSHARE_COUNTER_lane1_3;
      execute_ctrl2_up_Prediction_BRANCH_HISTORY_lane1 <= execute_ctrl1_down_Prediction_BRANCH_HISTORY_lane1;
      execute_ctrl2_up_Decode_INSTRUCTION_SLICE_COUNT_lane1 <= execute_ctrl1_down_Decode_INSTRUCTION_SLICE_COUNT_lane1;
      execute_ctrl2_up_PC_lane1 <= execute_ctrl1_down_PC_lane1;
      execute_ctrl2_up_TRAP_lane1 <= execute_ctrl1_down_TRAP_lane1;
      execute_ctrl2_up_Decode_UOP_ID_lane1 <= execute_ctrl1_down_Decode_UOP_ID_lane1;
      execute_ctrl2_up_RS1_PHYS_lane1 <= execute_ctrl1_down_RS1_PHYS_lane1;
      execute_ctrl2_up_RS2_PHYS_lane1 <= execute_ctrl1_down_RS2_PHYS_lane1;
      execute_ctrl2_up_RD_ENABLE_lane1 <= execute_ctrl1_down_RD_ENABLE_lane1;
      execute_ctrl2_up_RD_PHYS_lane1 <= execute_ctrl1_down_RD_PHYS_lane1;
      execute_ctrl2_up_LANE_AGE_lane1 <= execute_ctrl1_down_LANE_AGE_lane1;
      execute_ctrl2_up_COMPLETED_lane1 <= execute_ctrl1_down_COMPLETED_lane1;
      execute_ctrl2_up_AguPlugin_SIZE_lane0 <= execute_ctrl1_down_AguPlugin_SIZE_lane0;
      execute_ctrl2_up_MAY_FLUSH_PRECISE_3_lane0 <= execute_ctrl1_down_MAY_FLUSH_PRECISE_3_lane0;
      execute_ctrl2_up_MAY_FLUSH_PRECISE_3_lane1 <= execute_ctrl1_down_MAY_FLUSH_PRECISE_3_lane1;
      execute_ctrl2_up_integer_RS1_lane0 <= execute_ctrl1_down_integer_RS1_lane0;
      execute_ctrl2_up_integer_RS2_lane0 <= execute_ctrl1_down_integer_RS2_lane0;
      execute_ctrl2_up_early0_IntAluPlugin_SEL_lane0 <= execute_ctrl1_down_early0_IntAluPlugin_SEL_lane0;
      execute_ctrl2_up_early0_BarrelShifterPlugin_SEL_lane0 <= execute_ctrl1_down_early0_BarrelShifterPlugin_SEL_lane0;
      execute_ctrl2_up_early0_BranchPlugin_SEL_lane0 <= execute_ctrl1_down_early0_BranchPlugin_SEL_lane0;
      execute_ctrl2_up_early0_MulPlugin_SEL_lane0 <= execute_ctrl1_down_early0_MulPlugin_SEL_lane0;
      execute_ctrl2_up_early0_DivPlugin_SEL_lane0 <= execute_ctrl1_down_early0_DivPlugin_SEL_lane0;
      execute_ctrl2_up_early0_EnvPlugin_SEL_lane0 <= execute_ctrl1_down_early0_EnvPlugin_SEL_lane0;
      execute_ctrl2_up_late0_IntAluPlugin_SEL_lane0 <= execute_ctrl1_down_late0_IntAluPlugin_SEL_lane0;
      execute_ctrl2_up_late0_BarrelShifterPlugin_SEL_lane0 <= execute_ctrl1_down_late0_BarrelShifterPlugin_SEL_lane0;
      execute_ctrl2_up_late0_BranchPlugin_SEL_lane0 <= execute_ctrl1_down_late0_BranchPlugin_SEL_lane0;
      execute_ctrl2_up_CsrAccessPlugin_SEL_lane0 <= execute_ctrl1_down_CsrAccessPlugin_SEL_lane0;
      execute_ctrl2_up_AguPlugin_SEL_lane0 <= execute_ctrl1_down_AguPlugin_SEL_lane0;
      execute_ctrl2_up_LsuPlugin_logic_FENCE_lane0 <= execute_ctrl1_down_LsuPlugin_logic_FENCE_lane0;
      execute_ctrl2_up_lane0_integer_WriteBackPlugin_SEL_lane0 <= execute_ctrl1_down_lane0_integer_WriteBackPlugin_SEL_lane0;
      execute_ctrl2_up_COMPLETION_AT_2_lane0 <= execute_ctrl1_down_COMPLETION_AT_2_lane0;
      execute_ctrl2_up_COMPLETION_AT_4_lane0 <= execute_ctrl1_down_COMPLETION_AT_4_lane0;
      execute_ctrl2_up_COMPLETION_AT_3_lane0 <= execute_ctrl1_down_COMPLETION_AT_3_lane0;
      execute_ctrl2_up_lane0_logic_completions_onCtrl_0_ENABLE_lane0 <= execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0;
      execute_ctrl2_up_lane0_logic_completions_onCtrl_1_ENABLE_lane0 <= execute_ctrl1_down_lane0_logic_completions_onCtrl_1_ENABLE_lane0;
      execute_ctrl2_up_lane0_logic_completions_onCtrl_2_ENABLE_lane0 <= execute_ctrl1_down_lane0_logic_completions_onCtrl_2_ENABLE_lane0;
      execute_ctrl2_up_early0_IntAluPlugin_ALU_ADD_SUB_lane0 <= execute_ctrl1_down_early0_IntAluPlugin_ALU_ADD_SUB_lane0;
      execute_ctrl2_up_early0_IntAluPlugin_ALU_SLTX_lane0 <= execute_ctrl1_down_early0_IntAluPlugin_ALU_SLTX_lane0;
      execute_ctrl2_up_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0 <= execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0;
      execute_ctrl2_up_SrcStageables_REVERT_lane0 <= execute_ctrl1_down_SrcStageables_REVERT_lane0;
      execute_ctrl2_up_SrcStageables_ZERO_lane0 <= execute_ctrl1_down_SrcStageables_ZERO_lane0;
      execute_ctrl2_up_early0_SrcPlugin_logic_SRC1_CTRL_lane0 <= execute_ctrl1_down_early0_SrcPlugin_logic_SRC1_CTRL_lane0;
      execute_ctrl2_up_early0_SrcPlugin_logic_SRC2_CTRL_lane0 <= execute_ctrl1_down_early0_SrcPlugin_logic_SRC2_CTRL_lane0;
      execute_ctrl2_up_lane0_IntFormatPlugin_logic_SIGNED_lane0 <= execute_ctrl1_down_lane0_IntFormatPlugin_logic_SIGNED_lane0;
      execute_ctrl2_up_lane0_IntFormatPlugin_logic_WIDTH_ID_lane0 <= execute_ctrl1_down_lane0_IntFormatPlugin_logic_WIDTH_ID_lane0;
      execute_ctrl2_up_BYPASSED_AT_3_lane0 <= execute_ctrl1_down_BYPASSED_AT_3_lane0;
      execute_ctrl2_up_SrcStageables_UNSIGNED_lane0 <= execute_ctrl1_down_SrcStageables_UNSIGNED_lane0;
      execute_ctrl2_up_BarrelShifterPlugin_LEFT_lane0 <= execute_ctrl1_down_BarrelShifterPlugin_LEFT_lane0;
      execute_ctrl2_up_BarrelShifterPlugin_SIGNED_lane0 <= execute_ctrl1_down_BarrelShifterPlugin_SIGNED_lane0;
      execute_ctrl2_up_BranchPlugin_BRANCH_CTRL_lane0 <= execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0;
      execute_ctrl2_up_MulPlugin_HIGH_lane0 <= execute_ctrl1_down_MulPlugin_HIGH_lane0;
      execute_ctrl2_up_RsUnsignedPlugin_RS1_SIGNED_lane0 <= execute_ctrl1_down_RsUnsignedPlugin_RS1_SIGNED_lane0;
      execute_ctrl2_up_RsUnsignedPlugin_RS2_SIGNED_lane0 <= execute_ctrl1_down_RsUnsignedPlugin_RS2_SIGNED_lane0;
      execute_ctrl2_up_DivPlugin_REM_lane0 <= execute_ctrl1_down_DivPlugin_REM_lane0;
      execute_ctrl2_up_CsrAccessPlugin_CSR_IMM_lane0 <= execute_ctrl1_down_CsrAccessPlugin_CSR_IMM_lane0;
      execute_ctrl2_up_CsrAccessPlugin_CSR_MASK_lane0 <= execute_ctrl1_down_CsrAccessPlugin_CSR_MASK_lane0;
      execute_ctrl2_up_CsrAccessPlugin_CSR_CLEAR_lane0 <= execute_ctrl1_down_CsrAccessPlugin_CSR_CLEAR_lane0;
      execute_ctrl2_up_AguPlugin_LOAD_lane0 <= execute_ctrl1_down_AguPlugin_LOAD_lane0;
      execute_ctrl2_up_AguPlugin_STORE_lane0 <= execute_ctrl1_down_AguPlugin_STORE_lane0;
      execute_ctrl2_up_AguPlugin_EXECUTE_lane0 <= execute_ctrl1_down_AguPlugin_EXECUTE_lane0;
      execute_ctrl2_up_AguPlugin_ATOMIC_lane0 <= execute_ctrl1_down_AguPlugin_ATOMIC_lane0;
      execute_ctrl2_up_AguPlugin_FLOAT_lane0 <= execute_ctrl1_down_AguPlugin_FLOAT_lane0;
      execute_ctrl2_up_AguPlugin_CLEAN_lane0 <= execute_ctrl1_down_AguPlugin_CLEAN_lane0;
      execute_ctrl2_up_AguPlugin_INVALIDATE_lane0 <= execute_ctrl1_down_AguPlugin_INVALIDATE_lane0;
      execute_ctrl2_up_AguPlugin_GUEST_lane0 <= execute_ctrl1_down_AguPlugin_GUEST_lane0;
      execute_ctrl2_up_LsuPlugin_logic_LSU_PREFETCH_lane0 <= execute_ctrl1_down_LsuPlugin_logic_LSU_PREFETCH_lane0;
      execute_ctrl2_up_early0_EnvPlugin_OP_lane0 <= execute_ctrl1_down_early0_EnvPlugin_OP_lane0;
      execute_ctrl2_up_late0_IntAluPlugin_ALU_ADD_SUB_lane0 <= execute_ctrl1_down_late0_IntAluPlugin_ALU_ADD_SUB_lane0;
      execute_ctrl2_up_late0_IntAluPlugin_ALU_SLTX_lane0 <= execute_ctrl1_down_late0_IntAluPlugin_ALU_SLTX_lane0;
      execute_ctrl2_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0 <= execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0;
      execute_ctrl2_up_late0_SrcPlugin_logic_SRC1_CTRL_lane0 <= execute_ctrl1_down_late0_SrcPlugin_logic_SRC1_CTRL_lane0;
      execute_ctrl2_up_late0_SrcPlugin_logic_SRC2_CTRL_lane0 <= execute_ctrl1_down_late0_SrcPlugin_logic_SRC2_CTRL_lane0;
      execute_ctrl2_up_integer_RS1_lane1 <= execute_ctrl1_down_integer_RS1_lane1;
      execute_ctrl2_up_integer_RS2_lane1 <= execute_ctrl1_down_integer_RS2_lane1;
      execute_ctrl2_up_early1_IntAluPlugin_SEL_lane1 <= execute_ctrl1_down_early1_IntAluPlugin_SEL_lane1;
      execute_ctrl2_up_early1_BarrelShifterPlugin_SEL_lane1 <= execute_ctrl1_down_early1_BarrelShifterPlugin_SEL_lane1;
      execute_ctrl2_up_early1_BranchPlugin_SEL_lane1 <= execute_ctrl1_down_early1_BranchPlugin_SEL_lane1;
      execute_ctrl2_up_late1_IntAluPlugin_SEL_lane1 <= execute_ctrl1_down_late1_IntAluPlugin_SEL_lane1;
      execute_ctrl2_up_late1_BarrelShifterPlugin_SEL_lane1 <= execute_ctrl1_down_late1_BarrelShifterPlugin_SEL_lane1;
      execute_ctrl2_up_late1_BranchPlugin_SEL_lane1 <= execute_ctrl1_down_late1_BranchPlugin_SEL_lane1;
      execute_ctrl2_up_lane1_integer_WriteBackPlugin_SEL_lane1 <= execute_ctrl1_down_lane1_integer_WriteBackPlugin_SEL_lane1;
      execute_ctrl2_up_COMPLETION_AT_2_lane1 <= execute_ctrl1_down_COMPLETION_AT_2_lane1;
      execute_ctrl2_up_COMPLETION_AT_4_lane1 <= execute_ctrl1_down_COMPLETION_AT_4_lane1;
      execute_ctrl2_up_lane1_logic_completions_onCtrl_0_ENABLE_lane1 <= execute_ctrl1_down_lane1_logic_completions_onCtrl_0_ENABLE_lane1;
      execute_ctrl2_up_lane1_logic_completions_onCtrl_1_ENABLE_lane1 <= execute_ctrl1_down_lane1_logic_completions_onCtrl_1_ENABLE_lane1;
      execute_ctrl2_up_early1_IntAluPlugin_ALU_ADD_SUB_lane1 <= execute_ctrl1_down_early1_IntAluPlugin_ALU_ADD_SUB_lane1;
      execute_ctrl2_up_early1_IntAluPlugin_ALU_SLTX_lane1 <= execute_ctrl1_down_early1_IntAluPlugin_ALU_SLTX_lane1;
      execute_ctrl2_up_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1 <= execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1;
      execute_ctrl2_up_SrcStageables_REVERT_lane1 <= execute_ctrl1_down_SrcStageables_REVERT_lane1;
      execute_ctrl2_up_SrcStageables_ZERO_lane1 <= execute_ctrl1_down_SrcStageables_ZERO_lane1;
      execute_ctrl2_up_early1_SrcPlugin_logic_SRC1_CTRL_lane1 <= execute_ctrl1_down_early1_SrcPlugin_logic_SRC1_CTRL_lane1;
      execute_ctrl2_up_early1_SrcPlugin_logic_SRC2_CTRL_lane1 <= execute_ctrl1_down_early1_SrcPlugin_logic_SRC2_CTRL_lane1;
      execute_ctrl2_up_BYPASSED_AT_3_lane1 <= execute_ctrl1_down_BYPASSED_AT_3_lane1;
      execute_ctrl2_up_SrcStageables_UNSIGNED_lane1 <= execute_ctrl1_down_SrcStageables_UNSIGNED_lane1;
      execute_ctrl2_up_BarrelShifterPlugin_LEFT_lane1 <= execute_ctrl1_down_BarrelShifterPlugin_LEFT_lane1;
      execute_ctrl2_up_BarrelShifterPlugin_SIGNED_lane1 <= execute_ctrl1_down_BarrelShifterPlugin_SIGNED_lane1;
      execute_ctrl2_up_BranchPlugin_BRANCH_CTRL_lane1 <= execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1;
      execute_ctrl2_up_late1_IntAluPlugin_ALU_ADD_SUB_lane1 <= execute_ctrl1_down_late1_IntAluPlugin_ALU_ADD_SUB_lane1;
      execute_ctrl2_up_late1_IntAluPlugin_ALU_SLTX_lane1 <= execute_ctrl1_down_late1_IntAluPlugin_ALU_SLTX_lane1;
      execute_ctrl2_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1 <= execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1;
      execute_ctrl2_up_late1_SrcPlugin_logic_SRC1_CTRL_lane1 <= execute_ctrl1_down_late1_SrcPlugin_logic_SRC1_CTRL_lane1;
      execute_ctrl2_up_late1_SrcPlugin_logic_SRC2_CTRL_lane1 <= execute_ctrl1_down_late1_SrcPlugin_logic_SRC2_CTRL_lane1;
    end
    if(execute_ctrl2_down_isReady) begin
      execute_ctrl3_up_Decode_UOP_lane0 <= execute_ctrl2_down_Decode_UOP_lane0;
      execute_ctrl3_up_Prediction_ALIGNED_JUMPED_lane0 <= execute_ctrl2_down_Prediction_ALIGNED_JUMPED_lane0;
      execute_ctrl3_up_Prediction_ALIGNED_JUMPED_PC_lane0 <= execute_ctrl2_down_Prediction_ALIGNED_JUMPED_PC_lane0;
      execute_ctrl3_up_Prediction_ALIGNED_SLICES_TAKEN_lane0 <= execute_ctrl2_down_Prediction_ALIGNED_SLICES_TAKEN_lane0;
      execute_ctrl3_up_Prediction_ALIGNED_SLICES_BRANCH_lane0 <= execute_ctrl2_down_Prediction_ALIGNED_SLICES_BRANCH_lane0;
      execute_ctrl3_up_GSharePlugin_GSHARE_COUNTER_lane0_0 <= execute_ctrl2_down_GSharePlugin_GSHARE_COUNTER_lane0_0;
      execute_ctrl3_up_GSharePlugin_GSHARE_COUNTER_lane0_1 <= execute_ctrl2_down_GSharePlugin_GSHARE_COUNTER_lane0_1;
      execute_ctrl3_up_GSharePlugin_GSHARE_COUNTER_lane0_2 <= execute_ctrl2_down_GSharePlugin_GSHARE_COUNTER_lane0_2;
      execute_ctrl3_up_GSharePlugin_GSHARE_COUNTER_lane0_3 <= execute_ctrl2_down_GSharePlugin_GSHARE_COUNTER_lane0_3;
      execute_ctrl3_up_Prediction_BRANCH_HISTORY_lane0 <= execute_ctrl2_down_Prediction_BRANCH_HISTORY_lane0;
      execute_ctrl3_up_Decode_INSTRUCTION_SLICE_COUNT_lane0 <= execute_ctrl2_down_Decode_INSTRUCTION_SLICE_COUNT_lane0;
      execute_ctrl3_up_PC_lane0 <= execute_ctrl2_down_PC_lane0;
      execute_ctrl3_up_TRAP_lane0 <= execute_ctrl2_down_TRAP_lane0;
      execute_ctrl3_up_Decode_UOP_ID_lane0 <= execute_ctrl2_down_Decode_UOP_ID_lane0;
      execute_ctrl3_up_RS1_PHYS_lane0 <= execute_ctrl2_down_RS1_PHYS_lane0;
      execute_ctrl3_up_RS2_PHYS_lane0 <= execute_ctrl2_down_RS2_PHYS_lane0;
      execute_ctrl3_up_RD_ENABLE_lane0 <= execute_ctrl2_down_RD_ENABLE_lane0;
      execute_ctrl3_up_RD_PHYS_lane0 <= execute_ctrl2_down_RD_PHYS_lane0;
      execute_ctrl3_up_LANE_AGE_lane0 <= execute_ctrl2_down_LANE_AGE_lane0;
      execute_ctrl3_up_COMPLETED_lane0 <= execute_ctrl2_down_COMPLETED_lane0;
      execute_ctrl3_up_Decode_UOP_lane1 <= execute_ctrl2_down_Decode_UOP_lane1;
      execute_ctrl3_up_Prediction_ALIGNED_JUMPED_lane1 <= execute_ctrl2_down_Prediction_ALIGNED_JUMPED_lane1;
      execute_ctrl3_up_Prediction_ALIGNED_JUMPED_PC_lane1 <= execute_ctrl2_down_Prediction_ALIGNED_JUMPED_PC_lane1;
      execute_ctrl3_up_Prediction_ALIGNED_SLICES_TAKEN_lane1 <= execute_ctrl2_down_Prediction_ALIGNED_SLICES_TAKEN_lane1;
      execute_ctrl3_up_Prediction_ALIGNED_SLICES_BRANCH_lane1 <= execute_ctrl2_down_Prediction_ALIGNED_SLICES_BRANCH_lane1;
      execute_ctrl3_up_GSharePlugin_GSHARE_COUNTER_lane1_0 <= execute_ctrl2_down_GSharePlugin_GSHARE_COUNTER_lane1_0;
      execute_ctrl3_up_GSharePlugin_GSHARE_COUNTER_lane1_1 <= execute_ctrl2_down_GSharePlugin_GSHARE_COUNTER_lane1_1;
      execute_ctrl3_up_GSharePlugin_GSHARE_COUNTER_lane1_2 <= execute_ctrl2_down_GSharePlugin_GSHARE_COUNTER_lane1_2;
      execute_ctrl3_up_GSharePlugin_GSHARE_COUNTER_lane1_3 <= execute_ctrl2_down_GSharePlugin_GSHARE_COUNTER_lane1_3;
      execute_ctrl3_up_Prediction_BRANCH_HISTORY_lane1 <= execute_ctrl2_down_Prediction_BRANCH_HISTORY_lane1;
      execute_ctrl3_up_Decode_INSTRUCTION_SLICE_COUNT_lane1 <= execute_ctrl2_down_Decode_INSTRUCTION_SLICE_COUNT_lane1;
      execute_ctrl3_up_PC_lane1 <= execute_ctrl2_down_PC_lane1;
      execute_ctrl3_up_TRAP_lane1 <= execute_ctrl2_down_TRAP_lane1;
      execute_ctrl3_up_Decode_UOP_ID_lane1 <= execute_ctrl2_down_Decode_UOP_ID_lane1;
      execute_ctrl3_up_RS1_PHYS_lane1 <= execute_ctrl2_down_RS1_PHYS_lane1;
      execute_ctrl3_up_RS2_PHYS_lane1 <= execute_ctrl2_down_RS2_PHYS_lane1;
      execute_ctrl3_up_RD_ENABLE_lane1 <= execute_ctrl2_down_RD_ENABLE_lane1;
      execute_ctrl3_up_RD_PHYS_lane1 <= execute_ctrl2_down_RD_PHYS_lane1;
      execute_ctrl3_up_LANE_AGE_lane1 <= execute_ctrl2_down_LANE_AGE_lane1;
      execute_ctrl3_up_COMPLETED_lane1 <= execute_ctrl2_down_COMPLETED_lane1;
      execute_ctrl3_up_AguPlugin_SIZE_lane0 <= execute_ctrl2_down_AguPlugin_SIZE_lane0;
      execute_ctrl3_up_integer_RS1_lane0 <= execute_ctrl2_down_integer_RS1_lane0;
      execute_ctrl3_up_integer_RS2_lane0 <= execute_ctrl2_down_integer_RS2_lane0;
      execute_ctrl3_up_early0_BranchPlugin_SEL_lane0 <= execute_ctrl2_down_early0_BranchPlugin_SEL_lane0;
      execute_ctrl3_up_early0_MulPlugin_SEL_lane0 <= execute_ctrl2_down_early0_MulPlugin_SEL_lane0;
      execute_ctrl3_up_early0_DivPlugin_SEL_lane0 <= execute_ctrl2_down_early0_DivPlugin_SEL_lane0;
      execute_ctrl3_up_late0_IntAluPlugin_SEL_lane0 <= execute_ctrl2_down_late0_IntAluPlugin_SEL_lane0;
      execute_ctrl3_up_late0_BarrelShifterPlugin_SEL_lane0 <= execute_ctrl2_down_late0_BarrelShifterPlugin_SEL_lane0;
      execute_ctrl3_up_late0_BranchPlugin_SEL_lane0 <= execute_ctrl2_down_late0_BranchPlugin_SEL_lane0;
      execute_ctrl3_up_CsrAccessPlugin_SEL_lane0 <= execute_ctrl2_down_CsrAccessPlugin_SEL_lane0;
      execute_ctrl3_up_AguPlugin_SEL_lane0 <= execute_ctrl2_down_AguPlugin_SEL_lane0;
      execute_ctrl3_up_LsuPlugin_logic_FENCE_lane0 <= execute_ctrl2_down_LsuPlugin_logic_FENCE_lane0;
      execute_ctrl3_up_lane0_integer_WriteBackPlugin_SEL_lane0 <= execute_ctrl2_down_lane0_integer_WriteBackPlugin_SEL_lane0;
      execute_ctrl3_up_COMPLETION_AT_4_lane0 <= execute_ctrl2_down_COMPLETION_AT_4_lane0;
      execute_ctrl3_up_COMPLETION_AT_3_lane0 <= execute_ctrl2_down_COMPLETION_AT_3_lane0;
      execute_ctrl3_up_lane0_logic_completions_onCtrl_1_ENABLE_lane0 <= execute_ctrl2_down_lane0_logic_completions_onCtrl_1_ENABLE_lane0;
      execute_ctrl3_up_lane0_logic_completions_onCtrl_2_ENABLE_lane0 <= execute_ctrl2_down_lane0_logic_completions_onCtrl_2_ENABLE_lane0;
      execute_ctrl3_up_SrcStageables_REVERT_lane0 <= execute_ctrl2_down_SrcStageables_REVERT_lane0;
      execute_ctrl3_up_SrcStageables_ZERO_lane0 <= execute_ctrl2_down_SrcStageables_ZERO_lane0;
      execute_ctrl3_up_lane0_IntFormatPlugin_logic_SIGNED_lane0 <= execute_ctrl2_down_lane0_IntFormatPlugin_logic_SIGNED_lane0;
      execute_ctrl3_up_lane0_IntFormatPlugin_logic_WIDTH_ID_lane0 <= execute_ctrl2_down_lane0_IntFormatPlugin_logic_WIDTH_ID_lane0;
      execute_ctrl3_up_SrcStageables_UNSIGNED_lane0 <= execute_ctrl2_down_SrcStageables_UNSIGNED_lane0;
      execute_ctrl3_up_BarrelShifterPlugin_LEFT_lane0 <= execute_ctrl2_down_BarrelShifterPlugin_LEFT_lane0;
      execute_ctrl3_up_BarrelShifterPlugin_SIGNED_lane0 <= execute_ctrl2_down_BarrelShifterPlugin_SIGNED_lane0;
      execute_ctrl3_up_BranchPlugin_BRANCH_CTRL_lane0 <= execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane0;
      execute_ctrl3_up_MulPlugin_HIGH_lane0 <= execute_ctrl2_down_MulPlugin_HIGH_lane0;
      execute_ctrl3_up_AguPlugin_LOAD_lane0 <= execute_ctrl2_down_AguPlugin_LOAD_lane0;
      execute_ctrl3_up_AguPlugin_STORE_lane0 <= execute_ctrl2_down_AguPlugin_STORE_lane0;
      execute_ctrl3_up_AguPlugin_EXECUTE_lane0 <= execute_ctrl2_down_AguPlugin_EXECUTE_lane0;
      execute_ctrl3_up_AguPlugin_ATOMIC_lane0 <= execute_ctrl2_down_AguPlugin_ATOMIC_lane0;
      execute_ctrl3_up_AguPlugin_FLOAT_lane0 <= execute_ctrl2_down_AguPlugin_FLOAT_lane0;
      execute_ctrl3_up_AguPlugin_CLEAN_lane0 <= execute_ctrl2_down_AguPlugin_CLEAN_lane0;
      execute_ctrl3_up_AguPlugin_INVALIDATE_lane0 <= execute_ctrl2_down_AguPlugin_INVALIDATE_lane0;
      execute_ctrl3_up_LsuPlugin_logic_LSU_PREFETCH_lane0 <= execute_ctrl2_down_LsuPlugin_logic_LSU_PREFETCH_lane0;
      execute_ctrl3_up_late0_IntAluPlugin_ALU_ADD_SUB_lane0 <= execute_ctrl2_down_late0_IntAluPlugin_ALU_ADD_SUB_lane0;
      execute_ctrl3_up_late0_IntAluPlugin_ALU_SLTX_lane0 <= execute_ctrl2_down_late0_IntAluPlugin_ALU_SLTX_lane0;
      execute_ctrl3_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0 <= execute_ctrl2_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0;
      execute_ctrl3_up_late0_SrcPlugin_logic_SRC1_CTRL_lane0 <= execute_ctrl2_down_late0_SrcPlugin_logic_SRC1_CTRL_lane0;
      execute_ctrl3_up_late0_SrcPlugin_logic_SRC2_CTRL_lane0 <= execute_ctrl2_down_late0_SrcPlugin_logic_SRC2_CTRL_lane0;
      execute_ctrl3_up_integer_RS1_lane1 <= execute_ctrl2_down_integer_RS1_lane1;
      execute_ctrl3_up_integer_RS2_lane1 <= execute_ctrl2_down_integer_RS2_lane1;
      execute_ctrl3_up_early1_BranchPlugin_SEL_lane1 <= execute_ctrl2_down_early1_BranchPlugin_SEL_lane1;
      execute_ctrl3_up_late1_IntAluPlugin_SEL_lane1 <= execute_ctrl2_down_late1_IntAluPlugin_SEL_lane1;
      execute_ctrl3_up_late1_BarrelShifterPlugin_SEL_lane1 <= execute_ctrl2_down_late1_BarrelShifterPlugin_SEL_lane1;
      execute_ctrl3_up_late1_BranchPlugin_SEL_lane1 <= execute_ctrl2_down_late1_BranchPlugin_SEL_lane1;
      execute_ctrl3_up_lane1_integer_WriteBackPlugin_SEL_lane1 <= execute_ctrl2_down_lane1_integer_WriteBackPlugin_SEL_lane1;
      execute_ctrl3_up_COMPLETION_AT_4_lane1 <= execute_ctrl2_down_COMPLETION_AT_4_lane1;
      execute_ctrl3_up_lane1_logic_completions_onCtrl_1_ENABLE_lane1 <= execute_ctrl2_down_lane1_logic_completions_onCtrl_1_ENABLE_lane1;
      execute_ctrl3_up_SrcStageables_REVERT_lane1 <= execute_ctrl2_down_SrcStageables_REVERT_lane1;
      execute_ctrl3_up_SrcStageables_ZERO_lane1 <= execute_ctrl2_down_SrcStageables_ZERO_lane1;
      execute_ctrl3_up_SrcStageables_UNSIGNED_lane1 <= execute_ctrl2_down_SrcStageables_UNSIGNED_lane1;
      execute_ctrl3_up_BarrelShifterPlugin_LEFT_lane1 <= execute_ctrl2_down_BarrelShifterPlugin_LEFT_lane1;
      execute_ctrl3_up_BarrelShifterPlugin_SIGNED_lane1 <= execute_ctrl2_down_BarrelShifterPlugin_SIGNED_lane1;
      execute_ctrl3_up_BranchPlugin_BRANCH_CTRL_lane1 <= execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane1;
      execute_ctrl3_up_late1_IntAluPlugin_ALU_ADD_SUB_lane1 <= execute_ctrl2_down_late1_IntAluPlugin_ALU_ADD_SUB_lane1;
      execute_ctrl3_up_late1_IntAluPlugin_ALU_SLTX_lane1 <= execute_ctrl2_down_late1_IntAluPlugin_ALU_SLTX_lane1;
      execute_ctrl3_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1 <= execute_ctrl2_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1;
      execute_ctrl3_up_late1_SrcPlugin_logic_SRC1_CTRL_lane1 <= execute_ctrl2_down_late1_SrcPlugin_logic_SRC1_CTRL_lane1;
      execute_ctrl3_up_late1_SrcPlugin_logic_SRC2_CTRL_lane1 <= execute_ctrl2_down_late1_SrcPlugin_logic_SRC2_CTRL_lane1;
      execute_ctrl3_up_COMMIT_lane0 <= execute_ctrl2_down_COMMIT_lane0;
      execute_ctrl3_up_LsuL1Plugin_logic_FREEZE_HAZARD_lane0 <= execute_ctrl2_down_LsuL1Plugin_logic_FREEZE_HAZARD_lane0;
      execute_ctrl3_up_COMMIT_lane1 <= execute_ctrl2_down_COMMIT_lane1;
      execute_ctrl3_up_early0_SrcPlugin_ADD_SUB_lane0 <= execute_ctrl2_down_early0_SrcPlugin_ADD_SUB_lane0;
      execute_ctrl3_up_early0_MulPlugin_logic_mul_VALUES_0_lane0 <= execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_0_lane0;
      execute_ctrl3_up_early0_MulPlugin_logic_mul_VALUES_1_lane0 <= execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_1_lane0;
      execute_ctrl3_up_early0_MulPlugin_logic_mul_VALUES_2_lane0 <= execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_2_lane0;
      execute_ctrl3_up_early0_MulPlugin_logic_mul_VALUES_3_lane0 <= execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_3_lane0;
      execute_ctrl3_up_DivPlugin_DIV_RESULT_lane0 <= execute_ctrl2_down_DivPlugin_DIV_RESULT_lane0;
      execute_ctrl3_up_early0_BranchPlugin_pcCalc_PC_TRUE_lane0 <= execute_ctrl2_down_early0_BranchPlugin_pcCalc_PC_TRUE_lane0;
      execute_ctrl3_up_early0_BranchPlugin_pcCalc_PC_FALSE_lane0 <= execute_ctrl2_down_early0_BranchPlugin_pcCalc_PC_FALSE_lane0;
      execute_ctrl3_up_early0_BranchPlugin_pcCalc_PC_LAST_SLICE_lane0 <= execute_ctrl2_down_early0_BranchPlugin_pcCalc_PC_LAST_SLICE_lane0;
      execute_ctrl3_up_early1_BranchPlugin_pcCalc_PC_TRUE_lane1 <= execute_ctrl2_down_early1_BranchPlugin_pcCalc_PC_TRUE_lane1;
      execute_ctrl3_up_early1_BranchPlugin_pcCalc_PC_FALSE_lane1 <= execute_ctrl2_down_early1_BranchPlugin_pcCalc_PC_FALSE_lane1;
      execute_ctrl3_up_early1_BranchPlugin_pcCalc_PC_LAST_SLICE_lane1 <= execute_ctrl2_down_early1_BranchPlugin_pcCalc_PC_LAST_SLICE_lane1;
      execute_ctrl3_up_lane0_integer_WriteBackPlugin_logic_DATA_lane0 <= execute_ctrl2_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0;
      execute_ctrl3_up_lane1_integer_WriteBackPlugin_logic_DATA_lane1 <= execute_ctrl2_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1;
      execute_ctrl3_up_LsuL1_MIXED_ADDRESS_lane0 <= execute_ctrl2_down_LsuL1_MIXED_ADDRESS_lane0;
      execute_ctrl3_up_LsuL1Plugin_logic_BANK_BUSY_lane0 <= execute_ctrl2_down_LsuL1Plugin_logic_BANK_BUSY_lane0;
      execute_ctrl3_up_LsuL1Plugin_logic_EVENT_WRITE_VALID_lane0 <= execute_ctrl2_down_LsuL1Plugin_logic_EVENT_WRITE_VALID_lane0;
      execute_ctrl3_up_LsuL1Plugin_logic_EVENT_WRITE_ADDRESS_lane0 <= execute_ctrl2_down_LsuL1Plugin_logic_EVENT_WRITE_ADDRESS_lane0;
      execute_ctrl3_up_LsuL1Plugin_logic_lsu_rt0_SHARED_BYPASS_VALID_lane0 <= execute_ctrl2_down_LsuL1Plugin_logic_lsu_rt0_SHARED_BYPASS_VALID_lane0;
      execute_ctrl3_up_LsuL1Plugin_logic_lsu_rt0_SHARED_BYPASS_VALUE_lane0_plru_0 <= execute_ctrl2_down_LsuL1Plugin_logic_lsu_rt0_SHARED_BYPASS_VALUE_lane0_plru_0;
      execute_ctrl3_up_LsuL1Plugin_logic_lsu_rt0_SHARED_BYPASS_VALUE_lane0_dirty <= execute_ctrl2_down_LsuL1Plugin_logic_lsu_rt0_SHARED_BYPASS_VALUE_lane0_dirty;
      execute_ctrl3_up_LsuL1Plugin_logic_EVENT_WRITE_DATA_lane0 <= execute_ctrl2_down_LsuL1Plugin_logic_EVENT_WRITE_DATA_lane0;
      execute_ctrl3_up_LsuL1Plugin_logic_EVENT_WRITE_MASK_lane0 <= execute_ctrl2_down_LsuL1Plugin_logic_EVENT_WRITE_MASK_lane0;
      execute_ctrl3_up_LsuPlugin_logic_FROM_ACCESS_lane0 <= execute_ctrl2_down_LsuPlugin_logic_FROM_ACCESS_lane0;
      execute_ctrl3_up_LsuPlugin_logic_FROM_WB_lane0 <= execute_ctrl2_down_LsuPlugin_logic_FROM_WB_lane0;
      execute_ctrl3_up_LsuL1_MASK_lane0 <= execute_ctrl2_down_LsuL1_MASK_lane0;
      execute_ctrl3_up_LsuL1_SIZE_lane0 <= execute_ctrl2_down_LsuL1_SIZE_lane0;
      execute_ctrl3_up_LsuL1_LOAD_lane0 <= execute_ctrl2_down_LsuL1_LOAD_lane0;
      execute_ctrl3_up_LsuL1_EXECUTE_lane0 <= execute_ctrl2_down_LsuL1_EXECUTE_lane0;
      execute_ctrl3_up_LsuL1_ATOMIC_lane0 <= execute_ctrl2_down_LsuL1_ATOMIC_lane0;
      execute_ctrl3_up_LsuL1_STORE_lane0 <= execute_ctrl2_down_LsuL1_STORE_lane0;
      execute_ctrl3_up_LsuL1_CLEAN_lane0 <= execute_ctrl2_down_LsuL1_CLEAN_lane0;
      execute_ctrl3_up_LsuL1_INVALID_lane0 <= execute_ctrl2_down_LsuL1_INVALID_lane0;
      execute_ctrl3_up_LsuL1_GUEST_lane0 <= execute_ctrl2_down_LsuL1_GUEST_lane0;
      execute_ctrl3_up_LsuL1_PREFETCH_lane0 <= execute_ctrl2_down_LsuL1_PREFETCH_lane0;
      execute_ctrl3_up_LsuL1_FLUSH_lane0 <= execute_ctrl2_down_LsuL1_FLUSH_lane0;
      execute_ctrl3_up_Decode_STORE_ID_lane0 <= execute_ctrl2_down_Decode_STORE_ID_lane0;
      execute_ctrl3_up_LsuPlugin_logic_FROM_LSU_lane0 <= execute_ctrl2_down_LsuPlugin_logic_FROM_LSU_lane0;
      execute_ctrl3_up_LsuPlugin_logic_FROM_PREFETCH_lane0 <= execute_ctrl2_down_LsuPlugin_logic_FROM_PREFETCH_lane0;
      execute_ctrl3_up_LsuPlugin_SB_PTR_lane0 <= execute_ctrl2_down_LsuPlugin_SB_PTR_lane0;
      execute_ctrl3_up_LsuPlugin_logic_onAddress0_SB_DATA_lane0 <= execute_ctrl2_down_LsuPlugin_logic_onAddress0_SB_DATA_lane0;
      execute_ctrl3_up_LsuPlugin_logic_onAddress0_STORE_BUFFER_EMPTY_lane0 <= execute_ctrl2_down_LsuPlugin_logic_onAddress0_STORE_BUFFER_EMPTY_lane0;
    end
    if(execute_ctrl3_down_isReady) begin
      execute_ctrl4_up_Decode_UOP_lane0 <= execute_ctrl3_down_Decode_UOP_lane0;
      execute_ctrl4_up_Prediction_ALIGNED_JUMPED_lane0 <= execute_ctrl3_down_Prediction_ALIGNED_JUMPED_lane0;
      execute_ctrl4_up_Prediction_ALIGNED_JUMPED_PC_lane0 <= execute_ctrl3_down_Prediction_ALIGNED_JUMPED_PC_lane0;
      execute_ctrl4_up_Prediction_ALIGNED_SLICES_TAKEN_lane0 <= execute_ctrl3_down_Prediction_ALIGNED_SLICES_TAKEN_lane0;
      execute_ctrl4_up_Prediction_ALIGNED_SLICES_BRANCH_lane0 <= execute_ctrl3_down_Prediction_ALIGNED_SLICES_BRANCH_lane0;
      execute_ctrl4_up_GSharePlugin_GSHARE_COUNTER_lane0_0 <= execute_ctrl3_down_GSharePlugin_GSHARE_COUNTER_lane0_0;
      execute_ctrl4_up_GSharePlugin_GSHARE_COUNTER_lane0_1 <= execute_ctrl3_down_GSharePlugin_GSHARE_COUNTER_lane0_1;
      execute_ctrl4_up_GSharePlugin_GSHARE_COUNTER_lane0_2 <= execute_ctrl3_down_GSharePlugin_GSHARE_COUNTER_lane0_2;
      execute_ctrl4_up_GSharePlugin_GSHARE_COUNTER_lane0_3 <= execute_ctrl3_down_GSharePlugin_GSHARE_COUNTER_lane0_3;
      execute_ctrl4_up_Prediction_BRANCH_HISTORY_lane0 <= execute_ctrl3_down_Prediction_BRANCH_HISTORY_lane0;
      execute_ctrl4_up_Decode_INSTRUCTION_SLICE_COUNT_lane0 <= execute_ctrl3_down_Decode_INSTRUCTION_SLICE_COUNT_lane0;
      execute_ctrl4_up_PC_lane0 <= execute_ctrl3_down_PC_lane0;
      execute_ctrl4_up_TRAP_lane0 <= execute_ctrl3_down_TRAP_lane0;
      execute_ctrl4_up_Decode_UOP_ID_lane0 <= execute_ctrl3_down_Decode_UOP_ID_lane0;
      execute_ctrl4_up_RD_ENABLE_lane0 <= execute_ctrl3_down_RD_ENABLE_lane0;
      execute_ctrl4_up_RD_PHYS_lane0 <= execute_ctrl3_down_RD_PHYS_lane0;
      execute_ctrl4_up_LANE_AGE_lane0 <= execute_ctrl3_down_LANE_AGE_lane0;
      execute_ctrl4_up_COMPLETED_lane0 <= execute_ctrl3_down_COMPLETED_lane0;
      execute_ctrl4_up_Decode_UOP_lane1 <= execute_ctrl3_down_Decode_UOP_lane1;
      execute_ctrl4_up_Prediction_ALIGNED_JUMPED_lane1 <= execute_ctrl3_down_Prediction_ALIGNED_JUMPED_lane1;
      execute_ctrl4_up_Prediction_ALIGNED_JUMPED_PC_lane1 <= execute_ctrl3_down_Prediction_ALIGNED_JUMPED_PC_lane1;
      execute_ctrl4_up_Prediction_ALIGNED_SLICES_TAKEN_lane1 <= execute_ctrl3_down_Prediction_ALIGNED_SLICES_TAKEN_lane1;
      execute_ctrl4_up_Prediction_ALIGNED_SLICES_BRANCH_lane1 <= execute_ctrl3_down_Prediction_ALIGNED_SLICES_BRANCH_lane1;
      execute_ctrl4_up_GSharePlugin_GSHARE_COUNTER_lane1_0 <= execute_ctrl3_down_GSharePlugin_GSHARE_COUNTER_lane1_0;
      execute_ctrl4_up_GSharePlugin_GSHARE_COUNTER_lane1_1 <= execute_ctrl3_down_GSharePlugin_GSHARE_COUNTER_lane1_1;
      execute_ctrl4_up_GSharePlugin_GSHARE_COUNTER_lane1_2 <= execute_ctrl3_down_GSharePlugin_GSHARE_COUNTER_lane1_2;
      execute_ctrl4_up_GSharePlugin_GSHARE_COUNTER_lane1_3 <= execute_ctrl3_down_GSharePlugin_GSHARE_COUNTER_lane1_3;
      execute_ctrl4_up_Prediction_BRANCH_HISTORY_lane1 <= execute_ctrl3_down_Prediction_BRANCH_HISTORY_lane1;
      execute_ctrl4_up_Decode_INSTRUCTION_SLICE_COUNT_lane1 <= execute_ctrl3_down_Decode_INSTRUCTION_SLICE_COUNT_lane1;
      execute_ctrl4_up_PC_lane1 <= execute_ctrl3_down_PC_lane1;
      execute_ctrl4_up_TRAP_lane1 <= execute_ctrl3_down_TRAP_lane1;
      execute_ctrl4_up_Decode_UOP_ID_lane1 <= execute_ctrl3_down_Decode_UOP_ID_lane1;
      execute_ctrl4_up_RD_ENABLE_lane1 <= execute_ctrl3_down_RD_ENABLE_lane1;
      execute_ctrl4_up_RD_PHYS_lane1 <= execute_ctrl3_down_RD_PHYS_lane1;
      execute_ctrl4_up_LANE_AGE_lane1 <= execute_ctrl3_down_LANE_AGE_lane1;
      execute_ctrl4_up_COMPLETED_lane1 <= execute_ctrl3_down_COMPLETED_lane1;
      execute_ctrl4_up_AguPlugin_SIZE_lane0 <= execute_ctrl3_down_AguPlugin_SIZE_lane0;
      execute_ctrl4_up_integer_RS1_lane0 <= execute_ctrl3_down_integer_RS1_lane0;
      execute_ctrl4_up_integer_RS2_lane0 <= execute_ctrl3_down_integer_RS2_lane0;
      execute_ctrl4_up_early0_BranchPlugin_SEL_lane0 <= execute_ctrl3_down_early0_BranchPlugin_SEL_lane0;
      execute_ctrl4_up_early0_MulPlugin_SEL_lane0 <= execute_ctrl3_down_early0_MulPlugin_SEL_lane0;
      execute_ctrl4_up_late0_IntAluPlugin_SEL_lane0 <= execute_ctrl3_down_late0_IntAluPlugin_SEL_lane0;
      execute_ctrl4_up_late0_BarrelShifterPlugin_SEL_lane0 <= execute_ctrl3_down_late0_BarrelShifterPlugin_SEL_lane0;
      execute_ctrl4_up_late0_BranchPlugin_SEL_lane0 <= execute_ctrl3_down_late0_BranchPlugin_SEL_lane0;
      execute_ctrl4_up_AguPlugin_SEL_lane0 <= execute_ctrl3_down_AguPlugin_SEL_lane0;
      execute_ctrl4_up_LsuPlugin_logic_FENCE_lane0 <= execute_ctrl3_down_LsuPlugin_logic_FENCE_lane0;
      execute_ctrl4_up_lane0_integer_WriteBackPlugin_SEL_lane0 <= execute_ctrl3_down_lane0_integer_WriteBackPlugin_SEL_lane0;
      execute_ctrl4_up_COMPLETION_AT_4_lane0 <= execute_ctrl3_down_COMPLETION_AT_4_lane0;
      execute_ctrl4_up_lane0_logic_completions_onCtrl_1_ENABLE_lane0 <= execute_ctrl3_down_lane0_logic_completions_onCtrl_1_ENABLE_lane0;
      execute_ctrl4_up_SrcStageables_REVERT_lane0 <= execute_ctrl3_down_SrcStageables_REVERT_lane0;
      execute_ctrl4_up_SrcStageables_ZERO_lane0 <= execute_ctrl3_down_SrcStageables_ZERO_lane0;
      execute_ctrl4_up_lane0_IntFormatPlugin_logic_SIGNED_lane0 <= execute_ctrl3_down_lane0_IntFormatPlugin_logic_SIGNED_lane0;
      execute_ctrl4_up_lane0_IntFormatPlugin_logic_WIDTH_ID_lane0 <= execute_ctrl3_down_lane0_IntFormatPlugin_logic_WIDTH_ID_lane0;
      execute_ctrl4_up_SrcStageables_UNSIGNED_lane0 <= execute_ctrl3_down_SrcStageables_UNSIGNED_lane0;
      execute_ctrl4_up_BarrelShifterPlugin_LEFT_lane0 <= execute_ctrl3_down_BarrelShifterPlugin_LEFT_lane0;
      execute_ctrl4_up_BarrelShifterPlugin_SIGNED_lane0 <= execute_ctrl3_down_BarrelShifterPlugin_SIGNED_lane0;
      execute_ctrl4_up_BranchPlugin_BRANCH_CTRL_lane0 <= execute_ctrl3_down_BranchPlugin_BRANCH_CTRL_lane0;
      execute_ctrl4_up_MulPlugin_HIGH_lane0 <= execute_ctrl3_down_MulPlugin_HIGH_lane0;
      execute_ctrl4_up_AguPlugin_LOAD_lane0 <= execute_ctrl3_down_AguPlugin_LOAD_lane0;
      execute_ctrl4_up_AguPlugin_STORE_lane0 <= execute_ctrl3_down_AguPlugin_STORE_lane0;
      execute_ctrl4_up_AguPlugin_EXECUTE_lane0 <= execute_ctrl3_down_AguPlugin_EXECUTE_lane0;
      execute_ctrl4_up_AguPlugin_ATOMIC_lane0 <= execute_ctrl3_down_AguPlugin_ATOMIC_lane0;
      execute_ctrl4_up_AguPlugin_FLOAT_lane0 <= execute_ctrl3_down_AguPlugin_FLOAT_lane0;
      execute_ctrl4_up_LsuPlugin_logic_LSU_PREFETCH_lane0 <= execute_ctrl3_down_LsuPlugin_logic_LSU_PREFETCH_lane0;
      execute_ctrl4_up_late0_IntAluPlugin_ALU_ADD_SUB_lane0 <= execute_ctrl3_down_late0_IntAluPlugin_ALU_ADD_SUB_lane0;
      execute_ctrl4_up_late0_IntAluPlugin_ALU_SLTX_lane0 <= execute_ctrl3_down_late0_IntAluPlugin_ALU_SLTX_lane0;
      execute_ctrl4_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0 <= execute_ctrl3_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0;
      execute_ctrl4_up_late0_SrcPlugin_logic_SRC1_CTRL_lane0 <= execute_ctrl3_down_late0_SrcPlugin_logic_SRC1_CTRL_lane0;
      execute_ctrl4_up_late0_SrcPlugin_logic_SRC2_CTRL_lane0 <= execute_ctrl3_down_late0_SrcPlugin_logic_SRC2_CTRL_lane0;
      execute_ctrl4_up_integer_RS1_lane1 <= execute_ctrl3_down_integer_RS1_lane1;
      execute_ctrl4_up_integer_RS2_lane1 <= execute_ctrl3_down_integer_RS2_lane1;
      execute_ctrl4_up_early1_BranchPlugin_SEL_lane1 <= execute_ctrl3_down_early1_BranchPlugin_SEL_lane1;
      execute_ctrl4_up_late1_IntAluPlugin_SEL_lane1 <= execute_ctrl3_down_late1_IntAluPlugin_SEL_lane1;
      execute_ctrl4_up_late1_BarrelShifterPlugin_SEL_lane1 <= execute_ctrl3_down_late1_BarrelShifterPlugin_SEL_lane1;
      execute_ctrl4_up_late1_BranchPlugin_SEL_lane1 <= execute_ctrl3_down_late1_BranchPlugin_SEL_lane1;
      execute_ctrl4_up_lane1_integer_WriteBackPlugin_SEL_lane1 <= execute_ctrl3_down_lane1_integer_WriteBackPlugin_SEL_lane1;
      execute_ctrl4_up_COMPLETION_AT_4_lane1 <= execute_ctrl3_down_COMPLETION_AT_4_lane1;
      execute_ctrl4_up_lane1_logic_completions_onCtrl_1_ENABLE_lane1 <= execute_ctrl3_down_lane1_logic_completions_onCtrl_1_ENABLE_lane1;
      execute_ctrl4_up_SrcStageables_REVERT_lane1 <= execute_ctrl3_down_SrcStageables_REVERT_lane1;
      execute_ctrl4_up_SrcStageables_ZERO_lane1 <= execute_ctrl3_down_SrcStageables_ZERO_lane1;
      execute_ctrl4_up_SrcStageables_UNSIGNED_lane1 <= execute_ctrl3_down_SrcStageables_UNSIGNED_lane1;
      execute_ctrl4_up_BarrelShifterPlugin_LEFT_lane1 <= execute_ctrl3_down_BarrelShifterPlugin_LEFT_lane1;
      execute_ctrl4_up_BarrelShifterPlugin_SIGNED_lane1 <= execute_ctrl3_down_BarrelShifterPlugin_SIGNED_lane1;
      execute_ctrl4_up_BranchPlugin_BRANCH_CTRL_lane1 <= execute_ctrl3_down_BranchPlugin_BRANCH_CTRL_lane1;
      execute_ctrl4_up_late1_IntAluPlugin_ALU_ADD_SUB_lane1 <= execute_ctrl3_down_late1_IntAluPlugin_ALU_ADD_SUB_lane1;
      execute_ctrl4_up_late1_IntAluPlugin_ALU_SLTX_lane1 <= execute_ctrl3_down_late1_IntAluPlugin_ALU_SLTX_lane1;
      execute_ctrl4_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1 <= execute_ctrl3_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1;
      execute_ctrl4_up_late1_SrcPlugin_logic_SRC1_CTRL_lane1 <= execute_ctrl3_down_late1_SrcPlugin_logic_SRC1_CTRL_lane1;
      execute_ctrl4_up_late1_SrcPlugin_logic_SRC2_CTRL_lane1 <= execute_ctrl3_down_late1_SrcPlugin_logic_SRC2_CTRL_lane1;
      execute_ctrl4_up_COMMIT_lane0 <= execute_ctrl3_down_COMMIT_lane0;
      execute_ctrl4_up_LsuL1Plugin_logic_FREEZE_HAZARD_lane0 <= execute_ctrl3_down_LsuL1Plugin_logic_FREEZE_HAZARD_lane0;
      execute_ctrl4_up_COMMIT_lane1 <= execute_ctrl3_down_COMMIT_lane1;
      execute_ctrl4_up_early0_MulPlugin_logic_mul_VALUES_0_lane0 <= execute_ctrl3_down_early0_MulPlugin_logic_mul_VALUES_0_lane0;
      execute_ctrl4_up_early0_MulPlugin_logic_mul_VALUES_1_lane0 <= execute_ctrl3_down_early0_MulPlugin_logic_mul_VALUES_1_lane0;
      execute_ctrl4_up_early0_MulPlugin_logic_mul_VALUES_2_lane0 <= execute_ctrl3_down_early0_MulPlugin_logic_mul_VALUES_2_lane0;
      execute_ctrl4_up_early0_MulPlugin_logic_mul_VALUES_3_lane0 <= execute_ctrl3_down_early0_MulPlugin_logic_mul_VALUES_3_lane0;
      execute_ctrl4_up_early0_BranchPlugin_pcCalc_PC_TRUE_lane0 <= execute_ctrl3_down_early0_BranchPlugin_pcCalc_PC_TRUE_lane0;
      execute_ctrl4_up_early0_BranchPlugin_pcCalc_PC_FALSE_lane0 <= execute_ctrl3_down_early0_BranchPlugin_pcCalc_PC_FALSE_lane0;
      execute_ctrl4_up_early0_BranchPlugin_pcCalc_PC_LAST_SLICE_lane0 <= execute_ctrl3_down_early0_BranchPlugin_pcCalc_PC_LAST_SLICE_lane0;
      execute_ctrl4_up_early1_BranchPlugin_pcCalc_PC_TRUE_lane1 <= execute_ctrl3_down_early1_BranchPlugin_pcCalc_PC_TRUE_lane1;
      execute_ctrl4_up_early1_BranchPlugin_pcCalc_PC_FALSE_lane1 <= execute_ctrl3_down_early1_BranchPlugin_pcCalc_PC_FALSE_lane1;
      execute_ctrl4_up_early1_BranchPlugin_pcCalc_PC_LAST_SLICE_lane1 <= execute_ctrl3_down_early1_BranchPlugin_pcCalc_PC_LAST_SLICE_lane1;
      execute_ctrl4_up_lane0_integer_WriteBackPlugin_logic_DATA_lane0 <= execute_ctrl3_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0;
      execute_ctrl4_up_lane1_integer_WriteBackPlugin_logic_DATA_lane1 <= execute_ctrl3_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1;
      execute_ctrl4_up_LsuL1_MIXED_ADDRESS_lane0 <= execute_ctrl3_down_LsuL1_MIXED_ADDRESS_lane0;
      execute_ctrl4_up_LsuL1Plugin_logic_EVENT_WRITE_DATA_lane0 <= execute_ctrl3_down_LsuL1Plugin_logic_EVENT_WRITE_DATA_lane0;
      execute_ctrl4_up_LsuL1Plugin_logic_EVENT_WRITE_MASK_lane0 <= execute_ctrl3_down_LsuL1Plugin_logic_EVENT_WRITE_MASK_lane0;
      execute_ctrl4_up_LsuPlugin_logic_FROM_WB_lane0 <= execute_ctrl3_down_LsuPlugin_logic_FROM_WB_lane0;
      execute_ctrl4_up_LsuL1_MASK_lane0 <= execute_ctrl3_down_LsuL1_MASK_lane0;
      execute_ctrl4_up_LsuL1_SIZE_lane0 <= execute_ctrl3_down_LsuL1_SIZE_lane0;
      execute_ctrl4_up_LsuL1_LOAD_lane0 <= execute_ctrl3_down_LsuL1_LOAD_lane0;
      execute_ctrl4_up_LsuL1_EXECUTE_lane0 <= execute_ctrl3_down_LsuL1_EXECUTE_lane0;
      execute_ctrl4_up_LsuL1_ATOMIC_lane0 <= execute_ctrl3_down_LsuL1_ATOMIC_lane0;
      execute_ctrl4_up_LsuL1_STORE_lane0 <= execute_ctrl3_down_LsuL1_STORE_lane0;
      execute_ctrl4_up_LsuL1_CLEAN_lane0 <= execute_ctrl3_down_LsuL1_CLEAN_lane0;
      execute_ctrl4_up_LsuL1_INVALID_lane0 <= execute_ctrl3_down_LsuL1_INVALID_lane0;
      execute_ctrl4_up_LsuL1_GUEST_lane0 <= execute_ctrl3_down_LsuL1_GUEST_lane0;
      execute_ctrl4_up_LsuL1_PREFETCH_lane0 <= execute_ctrl3_down_LsuL1_PREFETCH_lane0;
      execute_ctrl4_up_LsuL1_FLUSH_lane0 <= execute_ctrl3_down_LsuL1_FLUSH_lane0;
      execute_ctrl4_up_Decode_STORE_ID_lane0 <= execute_ctrl3_down_Decode_STORE_ID_lane0;
      execute_ctrl4_up_LsuPlugin_logic_FROM_LSU_lane0 <= execute_ctrl3_down_LsuPlugin_logic_FROM_LSU_lane0;
      execute_ctrl4_up_LsuPlugin_logic_FROM_PREFETCH_lane0 <= execute_ctrl3_down_LsuPlugin_logic_FROM_PREFETCH_lane0;
      execute_ctrl4_up_LsuPlugin_SB_PTR_lane0 <= execute_ctrl3_down_LsuPlugin_SB_PTR_lane0;
      execute_ctrl4_up_LsuPlugin_logic_onAddress0_SB_DATA_lane0 <= execute_ctrl3_down_LsuPlugin_logic_onAddress0_SB_DATA_lane0;
      execute_ctrl4_up_LsuPlugin_logic_onAddress0_STORE_BUFFER_EMPTY_lane0 <= execute_ctrl3_down_LsuPlugin_logic_onAddress0_STORE_BUFFER_EMPTY_lane0;
      execute_ctrl4_up_LsuL1Plugin_logic_SHARED_lane0_plru_0 <= execute_ctrl3_down_LsuL1Plugin_logic_SHARED_lane0_plru_0;
      execute_ctrl4_up_LsuL1Plugin_logic_SHARED_lane0_dirty <= execute_ctrl3_down_LsuL1Plugin_logic_SHARED_lane0_dirty;
      execute_ctrl4_up_early0_MulPlugin_logic_steps_0_adders_0_lane0 <= execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_0_lane0;
      execute_ctrl4_up_early0_MulPlugin_logic_steps_0_adders_1_lane0 <= execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_1_lane0;
      execute_ctrl4_up_LsuL1Plugin_logic_BANK_BUSY_REMAPPED_lane0 <= execute_ctrl3_down_LsuL1Plugin_logic_BANK_BUSY_REMAPPED_lane0;
      execute_ctrl4_up_LsuL1Plugin_logic_BANKS_MUXES_lane0_0 <= execute_ctrl3_down_LsuL1Plugin_logic_BANKS_MUXES_lane0_0;
      execute_ctrl4_up_LsuL1Plugin_logic_BANKS_MUXES_lane0_1 <= execute_ctrl3_down_LsuL1Plugin_logic_BANKS_MUXES_lane0_1;
      execute_ctrl4_up_LsuL1Plugin_logic_WRITE_TO_READ_HAZARDS_lane0 <= execute_ctrl3_down_LsuL1Plugin_logic_WRITE_TO_READ_HAZARDS_lane0;
      execute_ctrl4_up_LsuL1_PHYSICAL_ADDRESS_lane0 <= execute_ctrl3_down_LsuL1_PHYSICAL_ADDRESS_lane0;
      execute_ctrl4_up_LsuL1Plugin_logic_WAYS_TAGS_lane0_0_loaded <= execute_ctrl3_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_0_loaded;
      execute_ctrl4_up_LsuL1Plugin_logic_WAYS_TAGS_lane0_0_address <= execute_ctrl3_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_0_address;
      execute_ctrl4_up_LsuL1Plugin_logic_WAYS_TAGS_lane0_0_fault <= execute_ctrl3_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_0_fault;
      execute_ctrl4_up_LsuL1Plugin_logic_WAYS_TAGS_lane0_1_loaded <= execute_ctrl3_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_1_loaded;
      execute_ctrl4_up_LsuL1Plugin_logic_WAYS_TAGS_lane0_1_address <= execute_ctrl3_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_1_address;
      execute_ctrl4_up_LsuL1Plugin_logic_WAYS_TAGS_lane0_1_fault <= execute_ctrl3_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_1_fault;
      execute_ctrl4_up_LsuL1Plugin_logic_WAYS_HITS_lane0 <= execute_ctrl3_down_LsuL1Plugin_logic_WAYS_HITS_lane0;
      execute_ctrl4_up_LsuPlugin_logic_onTrigger_HIT_lane0 <= execute_ctrl3_down_LsuPlugin_logic_onTrigger_HIT_lane0;
      execute_ctrl4_up_LsuPlugin_logic_onAddress0_translationPort_keys_TRANSLATED_lane0 <= execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_TRANSLATED_lane0;
      _zz_execute_ctrl4_down_LsuPlugin_logic_onAddress1_translationPort_keys_TRANSLATED_lane0 <= execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_TRANSLATED_lane0;
      execute_ctrl4_up_LsuPlugin_logic_preCtrl_MISS_ALIGNED_lane0 <= execute_ctrl3_down_LsuPlugin_logic_preCtrl_MISS_ALIGNED_lane0;
      execute_ctrl4_up_LsuPlugin_logic_onPma_CACHED_RSP_lane0_fault <= execute_ctrl3_down_LsuPlugin_logic_onPma_CACHED_RSP_lane0_fault;
      execute_ctrl4_up_LsuPlugin_logic_onPma_CACHED_RSP_lane0_io <= execute_ctrl3_down_LsuPlugin_logic_onPma_CACHED_RSP_lane0_io;
      execute_ctrl4_up_LsuPlugin_logic_onPma_IO_RSP_lane0_fault <= execute_ctrl3_down_LsuPlugin_logic_onPma_IO_RSP_lane0_fault;
      execute_ctrl4_up_LsuPlugin_logic_onPma_IO_RSP_lane0_io <= execute_ctrl3_down_LsuPlugin_logic_onPma_IO_RSP_lane0_io;
      execute_ctrl4_up_LsuPlugin_logic_onPma_IO_lane0 <= execute_ctrl3_down_LsuPlugin_logic_onPma_IO_lane0;
      execute_ctrl4_up_LsuPlugin_logic_onPma_FROM_LSU_MSB_FAILED_lane0 <= execute_ctrl3_down_LsuPlugin_logic_onPma_FROM_LSU_MSB_FAILED_lane0;
      execute_ctrl4_up_LsuPlugin_logic_MMU_PAGE_FAULT_lane0 <= execute_ctrl3_down_LsuPlugin_logic_MMU_PAGE_FAULT_lane0;
      execute_ctrl4_up_LsuPlugin_logic_MMU_FAILURE_lane0 <= execute_ctrl3_down_LsuPlugin_logic_MMU_FAILURE_lane0;
      execute_ctrl4_up_LsuPlugin_logic_onAddress0_translationPort_keys_ACCESS_FAULT_lane0 <= execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_ACCESS_FAULT_lane0;
      execute_ctrl4_up_LsuPlugin_logic_onAddress0_translationPort_keys_REFILL_lane0 <= execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_REFILL_lane0;
      execute_ctrl4_up_LsuPlugin_logic_onAddress0_translationPort_keys_HAZARD_lane0 <= execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_HAZARD_lane0;
      execute_ctrl4_up_LsuPlugin_logic_GUEST_MMU_FAILURE_lane0 <= execute_ctrl3_down_LsuPlugin_logic_GUEST_MMU_FAILURE_lane0;
      execute_ctrl4_up_LsuPlugin_logic_onAddress0_translationPort_keys_BYPASS_TRANSLATION_lane0 <= execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_BYPASS_TRANSLATION_lane0;
    end
    if(execute_ctrl4_down_isReady) begin
      execute_ctrl5_up_Decode_UOP_ID_lane0 <= execute_ctrl4_down_Decode_UOP_ID_lane0;
      execute_ctrl5_up_RD_ENABLE_lane0 <= execute_ctrl4_down_RD_ENABLE_lane0;
      execute_ctrl5_up_RD_PHYS_lane0 <= execute_ctrl4_down_RD_PHYS_lane0;
      execute_ctrl5_up_LANE_AGE_lane0 <= execute_ctrl4_down_LANE_AGE_lane0;
      execute_ctrl5_up_Decode_UOP_ID_lane1 <= execute_ctrl4_down_Decode_UOP_ID_lane1;
      execute_ctrl5_up_RD_ENABLE_lane1 <= execute_ctrl4_down_RD_ENABLE_lane1;
      execute_ctrl5_up_RD_PHYS_lane1 <= execute_ctrl4_down_RD_PHYS_lane1;
      execute_ctrl5_up_LANE_AGE_lane1 <= execute_ctrl4_down_LANE_AGE_lane1;
      execute_ctrl5_up_COMMIT_lane0 <= execute_ctrl4_down_COMMIT_lane0;
      execute_ctrl5_up_COMMIT_lane1 <= execute_ctrl4_down_COMMIT_lane1;
      execute_ctrl5_up_lane0_integer_WriteBackPlugin_logic_DATA_lane0 <= execute_ctrl4_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0;
      execute_ctrl5_up_lane1_integer_WriteBackPlugin_logic_DATA_lane1 <= execute_ctrl4_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1;
    end
    case(PerformanceCounterPlugin_logic_fsm_stateReg)
      PerformanceCounterPlugin_logic_fsm_IDLE : begin
        PerformanceCounterPlugin_logic_fsm_cmd_oh <= {(PerformanceCounterPlugin_logic_fsm_idleCsrAddress == 2'b10),(PerformanceCounterPlugin_logic_fsm_idleCsrAddress == 2'b00)};
        if(!PerformanceCounterPlugin_logic_fsm_csrWriteCmd_valid) begin
          if(PerformanceCounterPlugin_logic_fsm_flusherCmd_valid) begin
            PerformanceCounterPlugin_logic_fsm_cmd_flusher <= 1'b1;
            PerformanceCounterPlugin_logic_fsm_cmd_oh <= PerformanceCounterPlugin_logic_fsm_flusherCmd_payload_oh;
          end else begin
            if(PerformanceCounterPlugin_logic_fsm_csrReadCmd_valid) begin
              PerformanceCounterPlugin_logic_fsm_cmd_flusher <= 1'b0;
            end
          end
        end
        PerformanceCounterPlugin_logic_fsm_carry <= 1'b0;
      end
      PerformanceCounterPlugin_logic_fsm_READ_LOW : begin
        PerformanceCounterPlugin_logic_fsm_ramReaded <= PerformanceCounterPlugin_logic_readPort_data;
        PerformanceCounterPlugin_logic_fsm_counterReaded <= ((_zz_PerformanceCounterPlugin_logic_fsm_cmd_address ? PerformanceCounterPlugin_logic_counters_cycle_value : 8'h0) | (_zz_PerformanceCounterPlugin_logic_fsm_cmd_address_1 ? PerformanceCounterPlugin_logic_counters_instret_value : 8'h0));
      end
      PerformanceCounterPlugin_logic_fsm_CALC_LOW : begin
        if(PerformanceCounterPlugin_logic_writePort_ready) begin
          if(when_PerformanceCounterPlugin_l345) begin
            PerformanceCounterPlugin_logic_fsm_carry <= 1'b1;
          end
        end
      end
      PerformanceCounterPlugin_logic_fsm_READ_HIGH : begin
        PerformanceCounterPlugin_logic_fsm_ramReaded <= PerformanceCounterPlugin_logic_readPort_data;
      end
      PerformanceCounterPlugin_logic_fsm_CALC_HIGH : begin
      end
      PerformanceCounterPlugin_logic_fsm_CSR_WRITE : begin
      end
      default : begin
      end
    endcase
    case(TrapPlugin_logic_harts_0_trap_fsm_stateReg)
      TrapPlugin_logic_harts_0_trap_fsm_RUNNING : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_COMPUTE : begin
        TrapPlugin_logic_harts_0_trap_fsm_triggerEbreakReg <= TrapPlugin_logic_harts_0_trap_fsm_triggerEbreak;
      end
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_EPC : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_TVAL : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_HTVAL : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_HTINST : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_TVEC : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_WAIT : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_APPLY : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_XRET_EPC : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_XRET_APPLY : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_JUMP : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_LSU_FLUSH : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_FETCH_FLUSH : begin
      end
      default : begin
      end
    endcase
    case(CsrAccessPlugin_logic_fsm_stateReg)
      CsrAccessPlugin_logic_fsm_READ : begin
        CsrAccessPlugin_logic_fsm_interface_aluInput <= CsrAccessPlugin_bus_read_toWriteBits;
        CsrAccessPlugin_logic_fsm_interface_csrValue <= CsrAccessPlugin_logic_fsm_readLogic_csrValue;
      end
      CsrAccessPlugin_logic_fsm_WRITE : begin
      end
      CsrAccessPlugin_logic_fsm_COMPLETION : begin
      end
      default : begin
        REG_CSR_2047 <= COMB_CSR_2047;
        REG_CSR_3857 <= COMB_CSR_3857;
        REG_CSR_3858 <= COMB_CSR_3858;
        REG_CSR_3859 <= COMB_CSR_3859;
        REG_CSR_3860 <= COMB_CSR_3860;
        REG_CSR_769 <= COMB_CSR_769;
        REG_CSR_768 <= COMB_CSR_768;
        REG_CSR_834 <= COMB_CSR_834;
        REG_CSR_836 <= COMB_CSR_836;
        REG_CSR_772 <= COMB_CSR_772;
        REG_CSR_UNAMED_0 <= COMB_CSR_UNAMED_2;
        REG_CSR_4016 <= COMB_CSR_4016;
        REG_CSR_794 <= COMB_CSR_794;
        REG_CSR_778 <= COMB_CSR_778;
        REG_CSR_774 <= COMB_CSR_774;
        REG_CSR_3073 <= COMB_CSR_3073;
        REG_CSR_3201 <= COMB_CSR_3201;
        REG_CSR_PrivilegedPlugin_logic_readAnyWriteLegal_tvecFilter <= COMB_CSR_PrivilegedPlugin_logic_readAnyWriteLegal_tvecFilter;
        REG_CSR_PrivilegedPlugin_logic_readAnyWriteLegal_epcFilter <= COMB_CSR_PrivilegedPlugin_logic_readAnyWriteLegal_epcFilter;
        REG_CSR_800 <= COMB_CSR_800;
        REG_CSR_UNAMED_1 <= COMB_CSR_UNAMED_3;
        REG_CSR_CsrRamPlugin_csrMapper_selFilter <= COMB_CSR_CsrRamPlugin_csrMapper_selFilter;
        REG_CSR_PerformanceCounterPlugin_logic_csrFilter <= COMB_CSR_PerformanceCounterPlugin_logic_csrFilter;
        REG_CSR_CsrAccessPlugin_logic_trapNextOnWriteFilter <= COMB_CSR_CsrAccessPlugin_logic_trapNextOnWriteFilter;
      end
    endcase
    case(LsuPlugin_logic_flusher_stateReg)
      LsuPlugin_logic_flusher_SB_DRAIN : begin
      end
      LsuPlugin_logic_flusher_CMD : begin
        if(when_LsuPlugin_l411) begin
          LsuPlugin_logic_flusher_waiter <= LsuL1_WRITEBACK_BUSY;
        end
      end
      LsuPlugin_logic_flusher_COMPLETION : begin
        LsuPlugin_logic_flusher_waiter <= (LsuPlugin_logic_flusher_waiter & LsuL1_WRITEBACK_BUSY);
      end
      default : begin
        LsuPlugin_logic_flusher_cmdCounter <= 7'h0;
      end
    endcase
  end


  replica_early0_shifter u_early0_shifter(
    .execute_ctrl2_down_BarrelShifterPlugin_LEFT_lane0(execute_ctrl2_down_BarrelShifterPlugin_LEFT_lane0),
    .execute_ctrl2_down_BarrelShifterPlugin_SIGNED_lane0(execute_ctrl2_down_BarrelShifterPlugin_SIGNED_lane0),
    .execute_ctrl2_down_early0_SrcPlugin_SRC1_lane0(execute_ctrl2_down_early0_SrcPlugin_SRC1_lane0),
    .execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0(execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0),
    .execute_ctrl2_down_early0_BarrelShifterPlugin_SHIFT_RESULT_lane0(execute_ctrl2_down_early0_BarrelShifterPlugin_SHIFT_RESULT_lane0)
  );
  replica_late0_shifter u_late0_shifter(
    .execute_ctrl4_down_BarrelShifterPlugin_LEFT_lane0(execute_ctrl4_down_BarrelShifterPlugin_LEFT_lane0),
    .execute_ctrl4_down_BarrelShifterPlugin_SIGNED_lane0(execute_ctrl4_down_BarrelShifterPlugin_SIGNED_lane0),
    .execute_ctrl4_down_late0_SrcPlugin_SRC1_lane0(execute_ctrl4_down_late0_SrcPlugin_SRC1_lane0),
    .execute_ctrl4_down_late0_SrcPlugin_SRC2_lane0(execute_ctrl4_down_late0_SrcPlugin_SRC2_lane0),
    .execute_ctrl4_down_late0_BarrelShifterPlugin_SHIFT_RESULT_lane0(execute_ctrl4_down_late0_BarrelShifterPlugin_SHIFT_RESULT_lane0)
  );
  replica_early1_shifter u_early1_shifter(
    .execute_ctrl2_down_BarrelShifterPlugin_LEFT_lane1(execute_ctrl2_down_BarrelShifterPlugin_LEFT_lane1),
    .execute_ctrl2_down_BarrelShifterPlugin_SIGNED_lane1(execute_ctrl2_down_BarrelShifterPlugin_SIGNED_lane1),
    .execute_ctrl2_down_early1_SrcPlugin_SRC1_lane1(execute_ctrl2_down_early1_SrcPlugin_SRC1_lane1),
    .execute_ctrl2_down_early1_SrcPlugin_SRC2_lane1(execute_ctrl2_down_early1_SrcPlugin_SRC2_lane1),
    .execute_ctrl2_down_early1_BarrelShifterPlugin_SHIFT_RESULT_lane1(execute_ctrl2_down_early1_BarrelShifterPlugin_SHIFT_RESULT_lane1)
  );
  replica_late1_shifter u_late1_shifter(
    .execute_ctrl4_down_BarrelShifterPlugin_LEFT_lane1(execute_ctrl4_down_BarrelShifterPlugin_LEFT_lane1),
    .execute_ctrl4_down_BarrelShifterPlugin_SIGNED_lane1(execute_ctrl4_down_BarrelShifterPlugin_SIGNED_lane1),
    // RV32I shifts always use rs1; bypass the generic RS1/U-immediate mux on this critical path.
    .execute_ctrl4_down_late1_SrcPlugin_SRC1_lane1(execute_ctrl4_up_integer_RS1_lane1),
    .execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1(execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1),
    .execute_ctrl4_down_late1_BarrelShifterPlugin_SHIFT_RESULT_lane1(execute_ctrl4_down_late1_BarrelShifterPlugin_SHIFT_RESULT_lane1)
  );
endmodule
