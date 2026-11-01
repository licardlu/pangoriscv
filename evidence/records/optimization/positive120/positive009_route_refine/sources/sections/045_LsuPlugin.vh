  assign LsuPlugin_logic_onCtrl_traps_pmaFault = (execute_ctrl4_down_LsuPlugin_logic_onPma_CACHED_RSP_lane0_fault && execute_ctrl4_down_LsuPlugin_logic_onPma_IO_RSP_lane0_fault);
  assign switch_Misc_l245_4 = {execute_ctrl4_down_LsuL1_EXECUTE_lane0,execute_ctrl4_down_LsuL1_STORE_lane0};
  always @(*) begin
    case(switch_Misc_l245_4)
      2'b00 : begin
        _zz_LsuPlugin_logic_trapPort_payload_arg = 2'b00;
      end
      2'b01 : begin
        _zz_LsuPlugin_logic_trapPort_payload_arg = 2'b01;
      end
      default : begin
        _zz_LsuPlugin_logic_trapPort_payload_arg = 2'b11;
      end
    endcase
  end

  assign when_LsuPlugin_l923 = (! execute_ctrl4_down_LsuPlugin_logic_onAddress0_translationPort_keys_BYPASS_TRANSLATION_lane0);
  always @(*) begin
    LsuPlugin_logic_storeBuffer_push_valid = 1'b0;
    if(when_LsuPlugin_l1036) begin
      if(!LsuPlugin_logic_onCtrl_lsuTrap) begin
        if(when_LsuPlugin_l1044) begin
          LsuPlugin_logic_storeBuffer_push_valid = 1'b1;
        end
      end
    end
  end

  assign LsuPlugin_logic_storeBuffer_push_payload_slotOh = LsuPlugin_logic_onCtrl_wb_slotOh;
  assign LsuPlugin_logic_storeBuffer_push_payload_tag = LsuPlugin_logic_onCtrl_wb_tag;
  assign LsuPlugin_logic_storeBuffer_push_payload_op_address = execute_ctrl4_down_LsuL1_PHYSICAL_ADDRESS_lane0;
  assign LsuPlugin_logic_storeBuffer_push_payload_op_data = execute_ctrl4_down_LsuL1_WRITE_DATA_lane0;
  assign LsuPlugin_logic_storeBuffer_push_payload_op_size = execute_ctrl4_down_LsuL1_SIZE_lane0;
  assign LsuPlugin_logic_storeBuffer_push_payload_op_storeId = execute_ctrl4_down_Decode_STORE_ID_lane0;
  assign when_LsuPlugin_l975 = (execute_ctrl4_down_LsuPlugin_logic_FENCE_lane0 || execute_ctrl4_down_LsuPlugin_logic_FROM_PREFETCH_lane0);
  always @(*) begin
    LsuPlugin_logic_onCtrl_fenceTrap_enable = 1'b0;
    if(when_LsuPlugin_l991) begin
      LsuPlugin_logic_onCtrl_fenceTrap_enable = 1'b1;
    end
  end

  assign LsuPlugin_logic_onCtrl_fenceTrap_doIt = ((execute_ctrl4_down_LsuL1_ATOMIC_lane0 || execute_ctrl4_down_LsuPlugin_logic_FENCE_lane0) && LsuPlugin_logic_onCtrl_fenceTrap_enable);
  assign when_LsuPlugin_l983 = (! execute_freeze_valid);
  assign when_LsuPlugin_l985 = (LsuPlugin_logic_onCtrl_fenceTrap_doIt || LsuPlugin_logic_onCtrl_fenceTrap_doItReg);
  assign when_LsuPlugin_l991 = ((! LsuPlugin_logic_storeBuffer_empty) || (! execute_ctrl4_down_LsuPlugin_logic_onAddress0_STORE_BUFFER_EMPTY_lane0));
  assign when_LsuPlugin_l1036 = (execute_ctrl4_up_LANE_SEL_lane0 && execute_ctrl4_down_AguPlugin_SEL_lane0);
  assign when_LsuPlugin_l1044 = (((LsuPlugin_logic_onCtrl_traps_l1Failed || LsuPlugin_logic_onCtrl_wb_hit) && LsuPlugin_logic_onCtrl_wb_allowed) && ((execute_ctrl4_down_LANE_SEL_lane0 && execute_ctrl4_down_isReady) && (! execute_lane0_ctrls_4_downIsCancel)));
  assign when_LsuPlugin_l1047 = (LsuPlugin_logic_onCtrl_wb_compatibleOp && (! LsuPlugin_logic_onCtrl_wb_notFull));
  assign LsuPlugin_logic_onCtrl_mmuNeeded = (execute_ctrl4_down_LsuPlugin_logic_FROM_LSU_lane0 || execute_ctrl4_down_LsuPlugin_logic_FROM_PREFETCH_lane0);
  assign execute_ctrl4_down_LsuL1_ABORD_lane0 = (|{(LsuPlugin_logic_onCtrl_wb_loadHazard || LsuPlugin_logic_onCtrl_wb_selfHazard),(execute_ctrl4_down_LsuPlugin_logic_FROM_LSU_lane0 && (LsuPlugin_logic_onCtrl_fenceTrap_doIt || LsuPlugin_logic_onCtrl_fenceTrap_doItReg)),(LsuPlugin_logic_onCtrl_mmuNeeded && (execute_ctrl4_down_LsuPlugin_logic_MMU_FAILURE_lane0 || execute_ctrl4_down_LsuPlugin_logic_GUEST_MMU_FAILURE_lane0)),(execute_ctrl4_down_LsuPlugin_logic_FROM_LSU_lane0 && (_zz_execute_ctrl4_down_LsuL1_ABORD_lane0 || execute_ctrl4_down_LsuPlugin_logic_FENCE_lane0)),(_zz_execute_ctrl4_down_LsuL1_ABORD_lane0_1 && execute_ctrl4_down_LsuPlugin_logic_onPma_CACHED_RSP_lane0_fault),execute_ctrl4_down_LsuL1_FLUSH_HAZARD_lane0,execute_ctrl4_down_LsuL1_HAZARD_lane0});
  assign execute_ctrl4_down_LsuL1_SKIP_WRITE_lane0 = (|{(LsuPlugin_logic_onCtrl_wb_selfHazard || ((! execute_ctrl4_down_LsuPlugin_logic_FROM_WB_lane0) && LsuPlugin_logic_onCtrl_wb_hit)),execute_ctrl4_down_LsuPlugin_logic_FROM_PREFETCH_lane0,(execute_ctrl4_down_LsuPlugin_logic_FROM_LSU_lane0 && (execute_ctrl4_down_LsuPlugin_logic_onTrigger_HIT_lane0 || execute_ctrl4_down_LsuPlugin_logic_pmpPort_ACCESS_FAULT_lane0)),execute_ctrl4_down_LsuPlugin_logic_preCtrl_MISS_ALIGNED_lane0,execute_ctrl4_down_LsuL1_FAULT_lane0,(execute_ctrl4_down_LsuL1_MISS_lane0 || execute_ctrl4_down_LsuL1_MISS_UNIQUE_lane0)});
  assign when_LsuPlugin_l1077 = ((execute_ctrl4_down_LsuL1_SEL_lane0 && execute_ctrl4_down_LsuL1_FLUSH_lane0) && ((execute_ctrl4_down_LsuL1_FLUSH_HIT_lane0 || execute_ctrl4_down_LsuL1_HAZARD_lane0) || execute_ctrl4_down_LsuL1_FLUSH_HAZARD_lane0));
  assign when_LsuPlugin_l1082 = (((execute_ctrl4_down_LsuL1_SEL_lane0 && execute_ctrl4_down_LsuPlugin_logic_FROM_WB_lane0) && (! execute_freeze_valid)) && (! LsuPlugin_logic_onCtrl_wb_selfHazard));
  assign when_LsuPlugin_l1085 = (! execute_ctrl4_down_LsuL1_HAZARD_lane0);
  assign when_LsuPlugin_l311 = (|execute_ctrl4_down_LsuL1_WAIT_REFILL_lane0);
  assign when_LsuPlugin_l1090 = (LsuPlugin_logic_storeBuffer_slots_0_ptr == LsuPlugin_logic_storeBuffer_ops_freePtr);
  assign when_LsuPlugin_l1090_1 = (LsuPlugin_logic_storeBuffer_slots_1_ptr == LsuPlugin_logic_storeBuffer_ops_freePtr);
  assign when_LsuPlugin_l1090_2 = (LsuPlugin_logic_storeBuffer_slots_2_ptr == LsuPlugin_logic_storeBuffer_ops_freePtr);
  assign when_LsuPlugin_l1090_3 = (LsuPlugin_logic_storeBuffer_slots_3_ptr == LsuPlugin_logic_storeBuffer_ops_freePtr);
  assign when_LsuPlugin_l307_1 = (|(LsuPlugin_logic_onCtrl_hartRegulation_refill & (~ LsuL1_REFILL_BUSY)));
  assign when_LsuPlugin_l1121 = ((((((execute_ctrl4_up_LANE_SEL_lane0 && execute_ctrl4_down_AguPlugin_SEL_lane0) && (! execute_ctrl4_down_LsuPlugin_logic_FROM_PREFETCH_lane0)) && (! execute_ctrl4_down_LsuPlugin_logic_onPma_IO_lane0)) && (! execute_ctrl4_down_LsuPlugin_logic_FENCE_lane0)) && (execute_ctrl4_down_LsuL1_LOAD_lane0 || execute_ctrl4_down_LsuL1_EXECUTE_lane0)) && ((execute_ctrl4_down_LsuL1_HAZARD_lane0 || execute_ctrl4_down_LsuL1_MISS_lane0) || execute_ctrl4_down_LsuL1_MISS_UNIQUE_lane0));
  assign when_LsuPlugin_l311_1 = (|execute_ctrl4_down_LsuL1_WAIT_REFILL_lane0);
  assign LsuPlugin_logic_onCtrl_commitProbeReq = ((((((((((execute_ctrl4_down_LANE_SEL_lane0 && execute_ctrl4_down_isReady) && (! execute_lane0_ctrls_4_downIsCancel)) && execute_ctrl4_down_AguPlugin_SEL_lane0) && execute_ctrl4_down_LsuPlugin_logic_FROM_LSU_lane0) && ((execute_ctrl4_down_LsuL1_LOAD_lane0 || execute_ctrl4_down_LsuL1_EXECUTE_lane0) || execute_ctrl4_down_LsuL1_STORE_lane0)) && (! execute_ctrl4_down_LsuL1_PREFETCH_lane0)) && (! execute_ctrl4_down_LsuL1_ATOMIC_lane0)) && (! execute_ctrl4_down_LsuL1_FLUSH_lane0)) && (! execute_ctrl4_down_LsuL1_CLEAN_lane0)) && (! execute_ctrl4_down_LsuL1_INVALID_lane0));
  assign LsuPlugin_logic_commitProbe_valid = (LsuPlugin_logic_onCtrl_commitProbeReq && (! LsuPlugin_logic_onCtrl_commitProbeToken));
  assign LsuPlugin_logic_commitProbe_payload_address = execute_ctrl4_down_LsuL1_MIXED_ADDRESS_lane0;
  assign LsuPlugin_logic_commitProbe_payload_load = (execute_ctrl4_down_LsuL1_LOAD_lane0 || execute_ctrl4_down_LsuL1_EXECUTE_lane0);
  assign LsuPlugin_logic_commitProbe_payload_store = execute_ctrl4_down_LsuL1_STORE_lane0;
  assign LsuPlugin_logic_commitProbe_payload_trap = LsuPlugin_logic_onCtrl_lsuTrap;
  assign LsuPlugin_logic_commitProbe_payload_miss = (((((execute_ctrl4_down_LsuL1_MISS_lane0 || execute_ctrl4_down_LsuL1_MISS_UNIQUE_lane0) || execute_ctrl4_down_LsuL1_HAZARD_lane0) && (! execute_ctrl4_down_LsuPlugin_logic_MMU_FAILURE_lane0)) && (! execute_ctrl4_down_LsuPlugin_logic_GUEST_MMU_FAILURE_lane0)) && (! (execute_ctrl4_down_LsuL1_STORE_lane0 && LsuPlugin_logic_onCtrl_wb_hit)));
  assign LsuPlugin_logic_commitProbe_payload_io = execute_ctrl4_down_LsuPlugin_logic_onPma_IO_lane0;
  assign LsuPlugin_logic_commitProbe_payload_prefetchFailed = execute_ctrl4_down_LsuPlugin_logic_FROM_PREFETCH_lane0;
  assign LsuPlugin_logic_commitProbe_payload_pc = execute_ctrl4_down_PC_lane0;
  assign LsuPlugin_logic_iwb_valid = (execute_ctrl4_down_AguPlugin_SEL_lane0 && (! execute_ctrl4_down_AguPlugin_FLOAT_lane0));
  assign LsuPlugin_logic_iwb_payload = execute_ctrl4_down_LsuPlugin_logic_onCtrl_loadData_RESULT_lane0;
  assign LsuPlugin_logic_onWb_storeFire = ((((((execute_ctrl4_down_LANE_SEL_lane0 && execute_ctrl4_down_isReady) && (! execute_lane0_ctrls_4_downIsCancel)) && execute_ctrl4_down_AguPlugin_SEL_lane0) && execute_ctrl4_down_LsuL1_STORE_lane0) && (! execute_ctrl4_down_LsuPlugin_logic_onPma_IO_lane0)) && (! execute_ctrl4_down_LsuPlugin_logic_FROM_PREFETCH_lane0));
  assign LsuPlugin_logic_onWb_storeBroadcast = (((((((execute_ctrl4_down_isReady && execute_ctrl4_down_LsuL1_SEL_lane0) && execute_ctrl4_down_LsuL1_STORE_lane0) && (! execute_ctrl4_down_LsuL1_ABORD_lane0)) && (! execute_ctrl4_down_LsuL1_SKIP_WRITE_lane0)) && (! execute_ctrl4_down_LsuL1_MISS_lane0)) && (! execute_ctrl4_down_LsuL1_MISS_UNIQUE_lane0)) && (! execute_ctrl4_down_LsuL1_HAZARD_lane0));
  always @(*) begin
    LsuPlugin_logic_storeBuffer_ops_pip_node_0_ready = LsuPlugin_logic_storeBuffer_ops_pip_node_1_ready;
    if(when_StageLink_l71_1) begin
      LsuPlugin_logic_storeBuffer_ops_pip_node_0_ready = 1'b1;
    end
  end

  assign when_StageLink_l71_1 = (! LsuPlugin_logic_storeBuffer_ops_pip_node_1_isValid);
  always @(*) begin
    LsuPlugin_logic_storeBuffer_ops_pip_node_1_ready = LsuPlugin_logic_storeBuffer_ops_pip_node_2_ready;
    if(when_StageLink_l71_2) begin
      LsuPlugin_logic_storeBuffer_ops_pip_node_1_ready = 1'b1;
    end
  end

  assign when_StageLink_l71_2 = (! LsuPlugin_logic_storeBuffer_ops_pip_node_2_isValid);
  assign LsuPlugin_logic_storeBuffer_ops_pip_node_0_isFiring = (LsuPlugin_logic_storeBuffer_ops_pip_node_0_isValid && LsuPlugin_logic_storeBuffer_ops_pip_node_0_isReady);
  assign LsuPlugin_logic_storeBuffer_ops_pip_node_0_isValid = LsuPlugin_logic_storeBuffer_ops_pip_node_0_valid;
  assign LsuPlugin_logic_storeBuffer_ops_pip_node_0_isReady = LsuPlugin_logic_storeBuffer_ops_pip_node_0_ready;
  assign LsuPlugin_logic_storeBuffer_ops_pip_node_1_isValid = LsuPlugin_logic_storeBuffer_ops_pip_node_1_valid;
  assign LsuPlugin_logic_storeBuffer_ops_pip_node_1_isReady = LsuPlugin_logic_storeBuffer_ops_pip_node_1_ready;
  assign LsuPlugin_logic_storeBuffer_ops_pip_node_2_isValid = LsuPlugin_logic_storeBuffer_ops_pip_node_2_valid;
  assign LsuL1TileLinkPlugin_logic_down_a_fire = (LsuL1TileLinkPlugin_logic_down_a_valid && LsuL1TileLinkPlugin_logic_down_a_ready);
  assign LsuL1TileLinkPlugin_logic_down_a_tracker_last = ((! (|{(LsuL1TileLinkPlugin_logic_down_a_payload_opcode == A_LOGICAL_DATA),(LsuL1TileLinkPlugin_logic_down_a_payload_opcode == A_ARITHMETIC_DATA),(LsuL1TileLinkPlugin_logic_down_a_payload_opcode == A_PUT_PARTIAL_DATA),(LsuL1TileLinkPlugin_logic_down_a_payload_opcode == A_PUT_FULL_DATA)})) || (LsuL1TileLinkPlugin_logic_down_a_tracker_beat == _zz_LsuL1TileLinkPlugin_logic_down_a_tracker_last));
  assign when_LsuL1Bus_l151 = (LsuL1TileLinkPlugin_logic_down_a_fire && LsuL1TileLinkPlugin_logic_down_a_tracker_last);
  assign LsuL1Plugin_logic_bus_toTilelink_nonCoherent_onA_sel = (LsuL1Plugin_logic_bus_toTilelink_nonCoherent_onA_lock ? LsuL1Plugin_logic_bus_toTilelink_nonCoherent_onA_selReg : LsuL1Plugin_logic_bus_read_cmd_valid);
  assign LsuL1TileLinkPlugin_logic_down_a_payload_param = 3'b000;
  assign LsuL1TileLinkPlugin_logic_down_a_payload_size = 3'b110;
  assign LsuL1TileLinkPlugin_logic_down_a_payload_mask = 8'hff;
  assign LsuL1TileLinkPlugin_logic_down_a_payload_data = LsuL1Plugin_logic_bus_write_cmd_payload_fragment_data;
  assign LsuL1TileLinkPlugin_logic_down_a_payload_corrupt = 1'b0;
  always @(*) begin
    if(LsuL1Plugin_logic_bus_toTilelink_nonCoherent_onA_sel) begin
      LsuL1TileLinkPlugin_logic_down_a_valid = LsuL1Plugin_logic_bus_read_cmd_valid;
    end else begin
      LsuL1TileLinkPlugin_logic_down_a_valid = LsuL1Plugin_logic_bus_write_cmd_valid;
    end
  end

  always @(*) begin
    if(LsuL1Plugin_logic_bus_toTilelink_nonCoherent_onA_sel) begin
      LsuL1TileLinkPlugin_logic_down_a_payload_opcode = A_GET;
    end else begin
      LsuL1TileLinkPlugin_logic_down_a_payload_opcode = A_PUT_FULL_DATA;
    end
  end

  always @(*) begin
    if(LsuL1Plugin_logic_bus_toTilelink_nonCoherent_onA_sel) begin
      LsuL1TileLinkPlugin_logic_down_a_payload_source = {1'd0, LsuL1Plugin_logic_bus_read_cmd_payload_id};
    end else begin
      LsuL1TileLinkPlugin_logic_down_a_payload_source = {1'd0, LsuL1Plugin_logic_bus_write_cmd_payload_fragment_id};
    end
    LsuL1TileLinkPlugin_logic_down_a_payload_source[3] = LsuL1Plugin_logic_bus_toTilelink_nonCoherent_onA_sel;
  end

  always @(*) begin
    if(LsuL1Plugin_logic_bus_toTilelink_nonCoherent_onA_sel) begin
      LsuL1TileLinkPlugin_logic_down_a_payload_address = LsuL1Plugin_logic_bus_read_cmd_payload_address;
    end else begin
      LsuL1TileLinkPlugin_logic_down_a_payload_address = LsuL1Plugin_logic_bus_write_cmd_payload_fragment_address;
    end
  end

  assign LsuL1Plugin_logic_bus_write_cmd_ready = ((! LsuL1Plugin_logic_bus_toTilelink_nonCoherent_onA_sel) && LsuL1TileLinkPlugin_logic_down_a_ready);
  assign LsuL1Plugin_logic_bus_read_cmd_ready = (LsuL1Plugin_logic_bus_toTilelink_nonCoherent_onA_sel && LsuL1TileLinkPlugin_logic_down_a_ready);
  assign LsuL1Plugin_logic_bus_toTilelink_nonCoherent_onD_sel = LsuL1TileLinkPlugin_logic_down_d_payload_source[3];
  assign LsuL1Plugin_logic_bus_read_rsp_valid = (LsuL1TileLinkPlugin_logic_down_d_valid && LsuL1Plugin_logic_bus_toTilelink_nonCoherent_onD_sel);
  assign LsuL1Plugin_logic_bus_read_rsp_payload_data = LsuL1TileLinkPlugin_logic_down_d_payload_data;
  assign LsuL1Plugin_logic_bus_read_rsp_payload_error = (LsuL1TileLinkPlugin_logic_down_d_payload_denied || LsuL1TileLinkPlugin_logic_down_d_payload_corrupt);
  assign LsuL1Plugin_logic_bus_read_rsp_payload_id = LsuL1TileLinkPlugin_logic_down_d_payload_source[2:0];
  assign LsuL1Plugin_logic_bus_write_rsp_valid = (LsuL1TileLinkPlugin_logic_down_d_valid && (! LsuL1Plugin_logic_bus_toTilelink_nonCoherent_onD_sel));
  assign LsuL1Plugin_logic_bus_write_rsp_payload_error = (LsuL1TileLinkPlugin_logic_down_d_payload_denied || LsuL1TileLinkPlugin_logic_down_d_payload_corrupt);
  assign LsuL1Plugin_logic_bus_write_rsp_payload_id = LsuL1TileLinkPlugin_logic_down_d_payload_source[2:0];
  assign LsuL1TileLinkPlugin_logic_down_d_ready = (LsuL1Plugin_logic_bus_toTilelink_nonCoherent_onD_sel ? LsuL1Plugin_logic_bus_read_rsp_ready : 1'b1);
  assign CsrRamPlugin_logic_writeLogic_hits = {CsrRamPlugin_setup_initPort_valid,CsrRamPlugin_csrMapper_write_valid,TrapPlugin_logic_harts_0_crsPorts_write_valid,PerformanceCounterPlugin_logic_writePort_valid};
  assign CsrRamPlugin_logic_writeLogic_hit = (|CsrRamPlugin_logic_writeLogic_hits);
  assign CsrRamPlugin_logic_writeLogic_hits_ohFirst_input = CsrRamPlugin_logic_writeLogic_hits;
  assign CsrRamPlugin_logic_writeLogic_hits_ohFirst_masked = (CsrRamPlugin_logic_writeLogic_hits_ohFirst_input & (~ _zz_CsrRamPlugin_logic_writeLogic_hits_ohFirst_masked));
  assign CsrRamPlugin_logic_writeLogic_oh = CsrRamPlugin_logic_writeLogic_hits_ohFirst_masked;
  assign _zz_PerformanceCounterPlugin_logic_writePort_ready = CsrRamPlugin_logic_writeLogic_oh[0];
  assign _zz_TrapPlugin_logic_harts_0_crsPorts_write_ready = CsrRamPlugin_logic_writeLogic_oh[1];
  assign _zz_CsrRamPlugin_csrMapper_write_ready = CsrRamPlugin_logic_writeLogic_oh[2];
  assign _zz_CsrRamPlugin_setup_initPort_ready = CsrRamPlugin_logic_writeLogic_oh[3];
  assign CsrRamPlugin_logic_writeLogic_port_valid = CsrRamPlugin_logic_writeLogic_hit;
  assign CsrRamPlugin_logic_writeLogic_port_payload_address = (((_zz_PerformanceCounterPlugin_logic_writePort_ready ? PerformanceCounterPlugin_logic_writePort_address : 3'b000) | (_zz_TrapPlugin_logic_harts_0_crsPorts_write_ready ? TrapPlugin_logic_harts_0_crsPorts_write_address : 3'b000)) | ((_zz_CsrRamPlugin_csrMapper_write_ready ? CsrRamPlugin_csrMapper_write_address : 3'b000) | (_zz_CsrRamPlugin_setup_initPort_ready ? CsrRamPlugin_setup_initPort_address : 3'b000)));
  assign CsrRamPlugin_logic_writeLogic_port_payload_data = (((_zz_PerformanceCounterPlugin_logic_writePort_ready ? PerformanceCounterPlugin_logic_writePort_data : 32'h0) | (_zz_TrapPlugin_logic_harts_0_crsPorts_write_ready ? TrapPlugin_logic_harts_0_crsPorts_write_data : 32'h0)) | ((_zz_CsrRamPlugin_csrMapper_write_ready ? CsrRamPlugin_csrMapper_write_data : 32'h0) | (_zz_CsrRamPlugin_setup_initPort_ready ? CsrRamPlugin_setup_initPort_data : 32'h0)));
  assign PerformanceCounterPlugin_logic_writePort_ready = _zz_PerformanceCounterPlugin_logic_writePort_ready;
  assign TrapPlugin_logic_harts_0_crsPorts_write_ready = _zz_TrapPlugin_logic_harts_0_crsPorts_write_ready;
  assign CsrRamPlugin_csrMapper_write_ready = _zz_CsrRamPlugin_csrMapper_write_ready;
  assign CsrRamPlugin_setup_initPort_ready = _zz_CsrRamPlugin_setup_initPort_ready;
  assign CsrRamPlugin_logic_readLogic_hits = {CsrRamPlugin_csrMapper_read_valid,TrapPlugin_logic_harts_0_crsPorts_read_valid,PerformanceCounterPlugin_logic_readPort_valid};
  assign CsrRamPlugin_logic_readLogic_hit = (|CsrRamPlugin_logic_readLogic_hits);
  assign CsrRamPlugin_logic_readLogic_hits_ohFirst_input = CsrRamPlugin_logic_readLogic_hits;
  assign CsrRamPlugin_logic_readLogic_hits_ohFirst_masked = (CsrRamPlugin_logic_readLogic_hits_ohFirst_input & (~ _zz_CsrRamPlugin_logic_readLogic_hits_ohFirst_masked));
  assign CsrRamPlugin_logic_readLogic_oh = CsrRamPlugin_logic_readLogic_hits_ohFirst_masked;
  assign _zz_CsrRamPlugin_logic_readLogic_sel = CsrRamPlugin_logic_readLogic_oh[1];
  assign _zz_CsrRamPlugin_logic_readLogic_sel_1 = CsrRamPlugin_logic_readLogic_oh[2];
  assign CsrRamPlugin_logic_readLogic_sel = {_zz_CsrRamPlugin_logic_readLogic_sel_1,_zz_CsrRamPlugin_logic_readLogic_sel};
  assign CsrRamPlugin_logic_readLogic_port_rsp = CsrRamPlugin_logic_mem_spinal_port1;
  assign CsrRamPlugin_logic_readLogic_port_cmd_valid = (((|CsrRamPlugin_logic_readLogic_oh) && (! CsrRamPlugin_logic_writeLogic_port_valid)) && (! CsrRamPlugin_logic_readLogic_busy));
  assign CsrRamPlugin_logic_readLogic_port_cmd_payload = _zz_CsrRamPlugin_logic_readLogic_port_cmd_payload;
  assign PerformanceCounterPlugin_logic_readPort_ready = CsrRamPlugin_logic_readLogic_ohReg[0];
  assign TrapPlugin_logic_harts_0_crsPorts_read_ready = CsrRamPlugin_logic_readLogic_ohReg[1];
  assign CsrRamPlugin_csrMapper_read_ready = CsrRamPlugin_logic_readLogic_ohReg[2];
  assign PerformanceCounterPlugin_logic_readPort_data = CsrRamPlugin_logic_readLogic_port_rsp;
  assign TrapPlugin_logic_harts_0_crsPorts_read_data = CsrRamPlugin_logic_readLogic_port_rsp;
  assign CsrRamPlugin_csrMapper_read_data = CsrRamPlugin_logic_readLogic_port_rsp;
  assign CsrRamPlugin_logic_flush_done = CsrRamPlugin_logic_flush_counter[3];
  assign CsrRamPlugin_setup_initPort_valid = (! CsrRamPlugin_logic_flush_done);
  assign CsrRamPlugin_setup_initPort_address = CsrRamPlugin_logic_flush_counter[2:0];
  assign CsrRamPlugin_setup_initPort_data = 32'h0;
  assign fetch_logic_flushes_0_doIt = (|{(DecoderPlugin_logic_laneLogic_1_flushPort_valid && 1'b1),(DecoderPlugin_logic_laneLogic_0_flushPort_valid && 1'b1),(late1_BranchPlugin_logic_flushPort_valid && 1'b1),(early1_BranchPlugin_logic_flushPort_valid && 1'b1),(late0_BranchPlugin_logic_flushPort_valid && 1'b1),(early0_EnvPlugin_logic_flushPort_valid && _zz_fetch_logic_flushes_0_doIt),_zz_fetch_logic_flushes_0_doIt_1,_zz_fetch_logic_flushes_0_doIt_2,(LsuPlugin_logic_flushPort_valid && 1'b1),((BtbPlugin_logic_flushPort_valid && 1'b1) && (1'b0 || (1'b1 && BtbPlugin_logic_flushPort_payload_self)))});
  assign fetch_logic_ctrls_1_throwWhen_FetchPipelinePlugin_l49 = fetch_logic_flushes_0_doIt;
  assign fetch_logic_flushes_1_doIt = (|{(DecoderPlugin_logic_laneLogic_1_flushPort_valid && 1'b1),(DecoderPlugin_logic_laneLogic_0_flushPort_valid && 1'b1),(late1_BranchPlugin_logic_flushPort_valid && 1'b1),(early1_BranchPlugin_logic_flushPort_valid && 1'b1),(late0_BranchPlugin_logic_flushPort_valid && 1'b1),(early0_EnvPlugin_logic_flushPort_valid && _zz_fetch_logic_flushes_1_doIt),_zz_fetch_logic_flushes_1_doIt_1,_zz_fetch_logic_flushes_1_doIt_2,_zz_fetch_logic_flushes_1_doIt_3});
  assign fetch_logic_ctrls_2_forgetsSingleRequest_FetchPipelinePlugin_l51 = fetch_logic_flushes_1_doIt;
  assign execute_lane0_bypasser_integer_RS1_port_valid = (! execute_freeze_valid);
  assign execute_lane0_bypasser_integer_RS1_port_address = execute_ctrl0_down_RS1_PHYS_lane0[4 : 0];
  always @(*) begin
    execute_lane0_bypasser_integer_RS1_bypassEnables[0] = (((execute_ctrl2_up_LANE_SEL_lane0 && execute_ctrl2_up_RD_ENABLE_lane0) && (execute_ctrl2_down_RD_PHYS_lane0 == execute_ctrl1_down_RS1_PHYS_lane0)) && 1'b1);
    execute_lane0_bypasser_integer_RS1_bypassEnables[1] = (((execute_ctrl2_up_LANE_SEL_lane1 && execute_ctrl2_up_RD_ENABLE_lane1) && (execute_ctrl2_down_RD_PHYS_lane1 == execute_ctrl1_down_RS1_PHYS_lane0)) && 1'b1);
    execute_lane0_bypasser_integer_RS1_bypassEnables[2] = (((execute_ctrl3_up_LANE_SEL_lane0 && execute_ctrl3_up_RD_ENABLE_lane0) && (execute_ctrl3_down_RD_PHYS_lane0 == execute_ctrl1_down_RS1_PHYS_lane0)) && 1'b1);
    execute_lane0_bypasser_integer_RS1_bypassEnables[3] = (((execute_ctrl3_up_LANE_SEL_lane1 && execute_ctrl3_up_RD_ENABLE_lane1) && (execute_ctrl3_down_RD_PHYS_lane1 == execute_ctrl1_down_RS1_PHYS_lane0)) && 1'b1);
    execute_lane0_bypasser_integer_RS1_bypassEnables[4] = (((execute_ctrl4_up_LANE_SEL_lane0 && execute_ctrl4_up_RD_ENABLE_lane0) && (execute_ctrl4_down_RD_PHYS_lane0 == execute_ctrl1_down_RS1_PHYS_lane0)) && 1'b1);
    execute_lane0_bypasser_integer_RS1_bypassEnables[5] = (((execute_ctrl4_up_LANE_SEL_lane1 && execute_ctrl4_up_RD_ENABLE_lane1) && (execute_ctrl4_down_RD_PHYS_lane1 == execute_ctrl1_down_RS1_PHYS_lane0)) && 1'b1);
    execute_lane0_bypasser_integer_RS1_bypassEnables[6] = (((execute_ctrl5_up_LANE_SEL_lane0 && execute_ctrl5_up_RD_ENABLE_lane0) && (execute_ctrl5_down_RD_PHYS_lane0 == execute_ctrl1_down_RS1_PHYS_lane0)) && 1'b1);
    execute_lane0_bypasser_integer_RS1_bypassEnables[7] = (((execute_ctrl5_up_LANE_SEL_lane1 && execute_ctrl5_up_RD_ENABLE_lane1) && (execute_ctrl5_down_RD_PHYS_lane1 == execute_ctrl1_down_RS1_PHYS_lane0)) && 1'b1);
    execute_lane0_bypasser_integer_RS1_bypassEnables[8] = 1'b1;
  end

  assign _zz_execute_lane0_bypasser_integer_RS1_bypassEnables_bools_0 = execute_lane0_bypasser_integer_RS1_bypassEnables;
  assign execute_lane0_bypasser_integer_RS1_bypassEnables_bools_0 = _zz_execute_lane0_bypasser_integer_RS1_bypassEnables_bools_0[0];
  assign execute_lane0_bypasser_integer_RS1_bypassEnables_bools_1 = _zz_execute_lane0_bypasser_integer_RS1_bypassEnables_bools_0[1];
  assign execute_lane0_bypasser_integer_RS1_bypassEnables_bools_2 = _zz_execute_lane0_bypasser_integer_RS1_bypassEnables_bools_0[2];
  assign execute_lane0_bypasser_integer_RS1_bypassEnables_bools_3 = _zz_execute_lane0_bypasser_integer_RS1_bypassEnables_bools_0[3];
  assign execute_lane0_bypasser_integer_RS1_bypassEnables_bools_4 = _zz_execute_lane0_bypasser_integer_RS1_bypassEnables_bools_0[4];
  assign execute_lane0_bypasser_integer_RS1_bypassEnables_bools_5 = _zz_execute_lane0_bypasser_integer_RS1_bypassEnables_bools_0[5];
  assign execute_lane0_bypasser_integer_RS1_bypassEnables_bools_6 = _zz_execute_lane0_bypasser_integer_RS1_bypassEnables_bools_0[6];
  assign execute_lane0_bypasser_integer_RS1_bypassEnables_bools_7 = _zz_execute_lane0_bypasser_integer_RS1_bypassEnables_bools_0[7];
  assign execute_lane0_bypasser_integer_RS1_bypassEnables_bools_8 = _zz_execute_lane0_bypasser_integer_RS1_bypassEnables_bools_0[8];
  always @(*) begin
    _zz_execute_lane0_bypasser_integer_RS1_sel[0] = (execute_lane0_bypasser_integer_RS1_bypassEnables_bools_0 && (! 1'b0));
    _zz_execute_lane0_bypasser_integer_RS1_sel[1] = (execute_lane0_bypasser_integer_RS1_bypassEnables_bools_1 && (! execute_lane0_bypasser_integer_RS1_bypassEnables_bools_0));
    _zz_execute_lane0_bypasser_integer_RS1_sel[2] = (execute_lane0_bypasser_integer_RS1_bypassEnables_bools_2 && (! execute_lane0_bypasser_integer_RS1_bypassEnables_range_0_to_1));
    _zz_execute_lane0_bypasser_integer_RS1_sel[3] = (execute_lane0_bypasser_integer_RS1_bypassEnables_bools_3 && (! execute_lane0_bypasser_integer_RS1_bypassEnables_range_0_to_2));
    _zz_execute_lane0_bypasser_integer_RS1_sel[4] = (execute_lane0_bypasser_integer_RS1_bypassEnables_bools_4 && (! execute_lane0_bypasser_integer_RS1_bypassEnables_range_0_to_3));
    _zz_execute_lane0_bypasser_integer_RS1_sel[5] = (execute_lane0_bypasser_integer_RS1_bypassEnables_bools_5 && (! (execute_lane0_bypasser_integer_RS1_bypassEnables_bools_4 || execute_lane0_bypasser_integer_RS1_bypassEnables_range_0_to_3)));
    _zz_execute_lane0_bypasser_integer_RS1_sel[6] = (execute_lane0_bypasser_integer_RS1_bypassEnables_bools_6 && (! (execute_lane0_bypasser_integer_RS1_bypassEnables_range_4_to_5 || execute_lane0_bypasser_integer_RS1_bypassEnables_range_0_to_3)));
    _zz_execute_lane0_bypasser_integer_RS1_sel[7] = (execute_lane0_bypasser_integer_RS1_bypassEnables_bools_7 && (! (execute_lane0_bypasser_integer_RS1_bypassEnables_range_4_to_6 || execute_lane0_bypasser_integer_RS1_bypassEnables_range_0_to_3)));
    _zz_execute_lane0_bypasser_integer_RS1_sel[8] = (execute_lane0_bypasser_integer_RS1_bypassEnables_bools_8 && (! (execute_lane0_bypasser_integer_RS1_bypassEnables_range_4_to_7 || execute_lane0_bypasser_integer_RS1_bypassEnables_range_0_to_3)));
  end

  assign execute_lane0_bypasser_integer_RS1_bypassEnables_range_0_to_1 = (|{execute_lane0_bypasser_integer_RS1_bypassEnables_bools_1,execute_lane0_bypasser_integer_RS1_bypassEnables_bools_0});
  assign execute_lane0_bypasser_integer_RS1_bypassEnables_range_0_to_2 = (|{execute_lane0_bypasser_integer_RS1_bypassEnables_bools_2,execute_lane0_bypasser_integer_RS1_bypassEnables_bools_1,execute_lane0_bypasser_integer_RS1_bypassEnables_bools_0});
  assign execute_lane0_bypasser_integer_RS1_bypassEnables_range_0_to_3 = (|{execute_lane0_bypasser_integer_RS1_bypassEnables_bools_3,execute_lane0_bypasser_integer_RS1_bypassEnables_bools_2,execute_lane0_bypasser_integer_RS1_bypassEnables_bools_1,execute_lane0_bypasser_integer_RS1_bypassEnables_bools_0});
  assign execute_lane0_bypasser_integer_RS1_bypassEnables_range_4_to_5 = (|{execute_lane0_bypasser_integer_RS1_bypassEnables_bools_5,execute_lane0_bypasser_integer_RS1_bypassEnables_bools_4});
  assign execute_lane0_bypasser_integer_RS1_bypassEnables_range_4_to_6 = (|{execute_lane0_bypasser_integer_RS1_bypassEnables_bools_6,execute_lane0_bypasser_integer_RS1_bypassEnables_bools_5,execute_lane0_bypasser_integer_RS1_bypassEnables_bools_4});
  assign execute_lane0_bypasser_integer_RS1_bypassEnables_range_4_to_7 = (|{execute_lane0_bypasser_integer_RS1_bypassEnables_bools_7,execute_lane0_bypasser_integer_RS1_bypassEnables_bools_6,execute_lane0_bypasser_integer_RS1_bypassEnables_bools_5,execute_lane0_bypasser_integer_RS1_bypassEnables_bools_4});
  assign execute_lane0_bypasser_integer_RS1_sel = _zz_execute_lane0_bypasser_integer_RS1_sel;
  assign _zz_execute_ctrl1_down_integer_RS1_lane0 = execute_lane0_bypasser_integer_RS1_sel[8 : 1];
  always @(*) begin
    _zz_execute_ctrl1_down_integer_RS1_lane0_1 = ((((_zz__zz_execute_ctrl1_down_integer_RS1_lane0_1 ? execute_ctrl2_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : _zz__zz_execute_ctrl1_down_integer_RS1_lane0_1_1) | (_zz__zz_execute_ctrl1_down_integer_RS1_lane0_1_2 ? execute_ctrl3_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : _zz__zz_execute_ctrl1_down_integer_RS1_lane0_1_3)) | ((_zz__zz_execute_ctrl1_down_integer_RS1_lane0_1_4 ? execute_ctrl3_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : _zz__zz_execute_ctrl1_down_integer_RS1_lane0_1_5) | (_zz__zz_execute_ctrl1_down_integer_RS1_lane0_1_6 ? execute_ctrl4_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : _zz__zz_execute_ctrl1_down_integer_RS1_lane0_1_7))) | (((_zz__zz_execute_ctrl1_down_integer_RS1_lane0_1_8 ? execute_ctrl4_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : _zz__zz_execute_ctrl1_down_integer_RS1_lane0_1_9) | (_zz__zz_execute_ctrl1_down_integer_RS1_lane0_1_10 ? execute_ctrl5_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : _zz__zz_execute_ctrl1_down_integer_RS1_lane0_1_11)) | ((_zz__zz_execute_ctrl1_down_integer_RS1_lane0_1_12 ? execute_ctrl5_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : _zz__zz_execute_ctrl1_down_integer_RS1_lane0_1_13) | (_zz__zz_execute_ctrl1_down_integer_RS1_lane0_1_14 ? execute_lane0_bypasser_integer_RS1_port_data : _zz__zz_execute_ctrl1_down_integer_RS1_lane0_1_15))));
    if(when_ExecuteLanePlugin_l196) begin
      _zz_execute_ctrl1_down_integer_RS1_lane0_1 = execute_ctrl2_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0;
    end
  end

  assign execute_ctrl1_down_integer_RS1_lane0 = _zz_execute_ctrl1_down_integer_RS1_lane0_1;
  assign when_ExecuteLanePlugin_l196 = execute_lane0_bypasser_integer_RS1_sel[0];
  assign execute_lane0_bypasser_integer_RS1_along_bypasses_0_checks_0_selfHit = (((execute_ctrl4_up_LANE_SEL_lane0 && execute_ctrl4_up_RD_ENABLE_lane0) && (execute_ctrl4_down_RD_PHYS_lane0 == execute_ctrl2_down_RS1_PHYS_lane0)) && 1'b1);
  assign execute_lane0_bypasser_integer_RS1_along_bypasses_0_checks_0_youngerHits_0 = (((execute_ctrl3_up_LANE_SEL_lane0 && execute_ctrl3_up_RD_ENABLE_lane0) && (execute_ctrl3_down_RD_PHYS_lane0 == execute_ctrl2_down_RS1_PHYS_lane0)) && 1'b1);
  assign execute_lane0_bypasser_integer_RS1_along_bypasses_0_checks_0_youngerHits_1 = (((execute_ctrl3_up_LANE_SEL_lane1 && execute_ctrl3_up_RD_ENABLE_lane1) && (execute_ctrl3_down_RD_PHYS_lane1 == execute_ctrl2_down_RS1_PHYS_lane0)) && 1'b1);
  assign execute_lane0_bypasser_integer_RS1_along_bypasses_0_checks_0_hit = (execute_lane0_bypasser_integer_RS1_along_bypasses_0_checks_0_selfHit && (! (|{execute_lane0_bypasser_integer_RS1_along_bypasses_0_checks_0_youngerHits_1,execute_lane0_bypasser_integer_RS1_along_bypasses_0_checks_0_youngerHits_0})));
  assign execute_lane0_bypasser_integer_RS1_along_bypasses_0_checks_1_selfHit = (((execute_ctrl3_up_LANE_SEL_lane0 && execute_ctrl3_up_RD_ENABLE_lane0) && (execute_ctrl3_down_RD_PHYS_lane0 == execute_ctrl2_down_RS1_PHYS_lane0)) && 1'b1);
  assign execute_lane0_bypasser_integer_RS1_along_bypasses_0_checks_1_hit = (execute_lane0_bypasser_integer_RS1_along_bypasses_0_checks_1_selfHit && (! 1'b0));
  assign execute_lane0_bypasser_integer_RS1_along_bypasses_0_checks_2_selfHit = (((execute_ctrl4_up_LANE_SEL_lane1 && execute_ctrl4_up_RD_ENABLE_lane1) && (execute_ctrl4_down_RD_PHYS_lane1 == execute_ctrl2_down_RS1_PHYS_lane0)) && 1'b1);
  assign execute_lane0_bypasser_integer_RS1_along_bypasses_0_checks_2_youngerHits_0 = (((execute_ctrl3_up_LANE_SEL_lane0 && execute_ctrl3_up_RD_ENABLE_lane0) && (execute_ctrl3_down_RD_PHYS_lane0 == execute_ctrl2_down_RS1_PHYS_lane0)) && 1'b1);
  assign execute_lane0_bypasser_integer_RS1_along_bypasses_0_checks_2_youngerHits_1 = (((execute_ctrl3_up_LANE_SEL_lane1 && execute_ctrl3_up_RD_ENABLE_lane1) && (execute_ctrl3_down_RD_PHYS_lane1 == execute_ctrl2_down_RS1_PHYS_lane0)) && 1'b1);
  assign execute_lane0_bypasser_integer_RS1_along_bypasses_0_checks_2_hit = (execute_lane0_bypasser_integer_RS1_along_bypasses_0_checks_2_selfHit && (! (|{execute_lane0_bypasser_integer_RS1_along_bypasses_0_checks_2_youngerHits_1,execute_lane0_bypasser_integer_RS1_along_bypasses_0_checks_2_youngerHits_0})));
  assign execute_lane0_bypasser_integer_RS1_along_bypasses_0_hits = {execute_lane0_bypasser_integer_RS1_along_bypasses_0_checks_2_hit,execute_lane0_bypasser_integer_RS1_along_bypasses_0_checks_1_hit,execute_lane0_bypasser_integer_RS1_along_bypasses_0_checks_0_hit};
  assign _zz_execute_ctrl2_integer_RS1_lane0_bypass = {execute_lane0_bypasser_integer_RS1_along_bypasses_0_hits,(! (|execute_lane0_bypasser_integer_RS1_along_bypasses_0_hits))};
  assign execute_ctrl2_integer_RS1_lane0_bypass = (((_zz_execute_ctrl2_integer_RS1_lane0_bypass[0] ? execute_ctrl2_up_integer_RS1_lane0 : 32'h0) | (_zz_execute_ctrl2_integer_RS1_lane0_bypass[1] ? execute_ctrl4_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : 32'h0)) | ((_zz_execute_ctrl2_integer_RS1_lane0_bypass[2] ? execute_ctrl3_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : 32'h0) | (_zz_execute_ctrl2_integer_RS1_lane0_bypass[3] ? execute_ctrl4_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : 32'h0)));
  assign execute_lane0_bypasser_integer_RS1_along_bypasses_1_checks_0_selfHit = (((execute_ctrl4_up_LANE_SEL_lane0 && execute_ctrl4_up_RD_ENABLE_lane0) && (execute_ctrl4_down_RD_PHYS_lane0 == execute_ctrl3_down_RS1_PHYS_lane0)) && 1'b1);
  assign execute_lane0_bypasser_integer_RS1_along_bypasses_1_checks_0_hit = (execute_lane0_bypasser_integer_RS1_along_bypasses_1_checks_0_selfHit && (! 1'b0));
  assign execute_lane0_bypasser_integer_RS1_along_bypasses_1_checks_1_selfHit = (((execute_ctrl4_up_LANE_SEL_lane1 && execute_ctrl4_up_RD_ENABLE_lane1) && (execute_ctrl4_down_RD_PHYS_lane1 == execute_ctrl3_down_RS1_PHYS_lane0)) && 1'b1);
  assign execute_lane0_bypasser_integer_RS1_along_bypasses_1_checks_1_hit = (execute_lane0_bypasser_integer_RS1_along_bypasses_1_checks_1_selfHit && (! 1'b0));
  assign execute_lane0_bypasser_integer_RS1_along_bypasses_1_hits = {execute_lane0_bypasser_integer_RS1_along_bypasses_1_checks_1_hit,execute_lane0_bypasser_integer_RS1_along_bypasses_1_checks_0_hit};
  assign _zz_execute_ctrl3_integer_RS1_lane0_bypass = {execute_lane0_bypasser_integer_RS1_along_bypasses_1_hits,(! (|execute_lane0_bypasser_integer_RS1_along_bypasses_1_hits))};
  assign execute_ctrl3_integer_RS1_lane0_bypass = (((_zz_execute_ctrl3_integer_RS1_lane0_bypass[0] ? execute_ctrl3_up_integer_RS1_lane0 : 32'h0) | (_zz_execute_ctrl3_integer_RS1_lane0_bypass[1] ? execute_ctrl4_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : 32'h0)) | (_zz_execute_ctrl3_integer_RS1_lane0_bypass[2] ? execute_ctrl4_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : 32'h0));
  assign execute_lane0_bypasser_integer_RS2_port_valid = (! execute_freeze_valid);
  assign execute_lane0_bypasser_integer_RS2_port_address = execute_ctrl0_down_RS2_PHYS_lane0[4 : 0];
  always @(*) begin
    execute_lane0_bypasser_integer_RS2_bypassEnables[0] = (((execute_ctrl2_up_LANE_SEL_lane0 && execute_ctrl2_up_RD_ENABLE_lane0) && (execute_ctrl2_down_RD_PHYS_lane0 == execute_ctrl1_down_RS2_PHYS_lane0)) && 1'b1);
    execute_lane0_bypasser_integer_RS2_bypassEnables[1] = (((execute_ctrl2_up_LANE_SEL_lane1 && execute_ctrl2_up_RD_ENABLE_lane1) && (execute_ctrl2_down_RD_PHYS_lane1 == execute_ctrl1_down_RS2_PHYS_lane0)) && 1'b1);
    execute_lane0_bypasser_integer_RS2_bypassEnables[2] = (((execute_ctrl3_up_LANE_SEL_lane0 && execute_ctrl3_up_RD_ENABLE_lane0) && (execute_ctrl3_down_RD_PHYS_lane0 == execute_ctrl1_down_RS2_PHYS_lane0)) && 1'b1);
    execute_lane0_bypasser_integer_RS2_bypassEnables[3] = (((execute_ctrl3_up_LANE_SEL_lane1 && execute_ctrl3_up_RD_ENABLE_lane1) && (execute_ctrl3_down_RD_PHYS_lane1 == execute_ctrl1_down_RS2_PHYS_lane0)) && 1'b1);
    execute_lane0_bypasser_integer_RS2_bypassEnables[4] = (((execute_ctrl4_up_LANE_SEL_lane0 && execute_ctrl4_up_RD_ENABLE_lane0) && (execute_ctrl4_down_RD_PHYS_lane0 == execute_ctrl1_down_RS2_PHYS_lane0)) && 1'b1);
    execute_lane0_bypasser_integer_RS2_bypassEnables[5] = (((execute_ctrl4_up_LANE_SEL_lane1 && execute_ctrl4_up_RD_ENABLE_lane1) && (execute_ctrl4_down_RD_PHYS_lane1 == execute_ctrl1_down_RS2_PHYS_lane0)) && 1'b1);
    execute_lane0_bypasser_integer_RS2_bypassEnables[6] = (((execute_ctrl5_up_LANE_SEL_lane0 && execute_ctrl5_up_RD_ENABLE_lane0) && (execute_ctrl5_down_RD_PHYS_lane0 == execute_ctrl1_down_RS2_PHYS_lane0)) && 1'b1);
    execute_lane0_bypasser_integer_RS2_bypassEnables[7] = (((execute_ctrl5_up_LANE_SEL_lane1 && execute_ctrl5_up_RD_ENABLE_lane1) && (execute_ctrl5_down_RD_PHYS_lane1 == execute_ctrl1_down_RS2_PHYS_lane0)) && 1'b1);
    execute_lane0_bypasser_integer_RS2_bypassEnables[8] = 1'b1;
  end

  assign _zz_execute_lane0_bypasser_integer_RS2_bypassEnables_bools_0 = execute_lane0_bypasser_integer_RS2_bypassEnables;
  assign execute_lane0_bypasser_integer_RS2_bypassEnables_bools_0 = _zz_execute_lane0_bypasser_integer_RS2_bypassEnables_bools_0[0];
  assign execute_lane0_bypasser_integer_RS2_bypassEnables_bools_1 = _zz_execute_lane0_bypasser_integer_RS2_bypassEnables_bools_0[1];
  assign execute_lane0_bypasser_integer_RS2_bypassEnables_bools_2 = _zz_execute_lane0_bypasser_integer_RS2_bypassEnables_bools_0[2];
  assign execute_lane0_bypasser_integer_RS2_bypassEnables_bools_3 = _zz_execute_lane0_bypasser_integer_RS2_bypassEnables_bools_0[3];
  assign execute_lane0_bypasser_integer_RS2_bypassEnables_bools_4 = _zz_execute_lane0_bypasser_integer_RS2_bypassEnables_bools_0[4];
  assign execute_lane0_bypasser_integer_RS2_bypassEnables_bools_5 = _zz_execute_lane0_bypasser_integer_RS2_bypassEnables_bools_0[5];
  assign execute_lane0_bypasser_integer_RS2_bypassEnables_bools_6 = _zz_execute_lane0_bypasser_integer_RS2_bypassEnables_bools_0[6];
  assign execute_lane0_bypasser_integer_RS2_bypassEnables_bools_7 = _zz_execute_lane0_bypasser_integer_RS2_bypassEnables_bools_0[7];
  assign execute_lane0_bypasser_integer_RS2_bypassEnables_bools_8 = _zz_execute_lane0_bypasser_integer_RS2_bypassEnables_bools_0[8];
  always @(*) begin
    _zz_execute_lane0_bypasser_integer_RS2_sel[0] = (execute_lane0_bypasser_integer_RS2_bypassEnables_bools_0 && (! 1'b0));
    _zz_execute_lane0_bypasser_integer_RS2_sel[1] = (execute_lane0_bypasser_integer_RS2_bypassEnables_bools_1 && (! execute_lane0_bypasser_integer_RS2_bypassEnables_bools_0));
    _zz_execute_lane0_bypasser_integer_RS2_sel[2] = (execute_lane0_bypasser_integer_RS2_bypassEnables_bools_2 && (! execute_lane0_bypasser_integer_RS2_bypassEnables_range_0_to_1));
    _zz_execute_lane0_bypasser_integer_RS2_sel[3] = (execute_lane0_bypasser_integer_RS2_bypassEnables_bools_3 && (! execute_lane0_bypasser_integer_RS2_bypassEnables_range_0_to_2));
    _zz_execute_lane0_bypasser_integer_RS2_sel[4] = (execute_lane0_bypasser_integer_RS2_bypassEnables_bools_4 && (! execute_lane0_bypasser_integer_RS2_bypassEnables_range_0_to_3));
    _zz_execute_lane0_bypasser_integer_RS2_sel[5] = (execute_lane0_bypasser_integer_RS2_bypassEnables_bools_5 && (! (execute_lane0_bypasser_integer_RS2_bypassEnables_bools_4 || execute_lane0_bypasser_integer_RS2_bypassEnables_range_0_to_3)));
    _zz_execute_lane0_bypasser_integer_RS2_sel[6] = (execute_lane0_bypasser_integer_RS2_bypassEnables_bools_6 && (! (execute_lane0_bypasser_integer_RS2_bypassEnables_range_4_to_5 || execute_lane0_bypasser_integer_RS2_bypassEnables_range_0_to_3)));
    _zz_execute_lane0_bypasser_integer_RS2_sel[7] = (execute_lane0_bypasser_integer_RS2_bypassEnables_bools_7 && (! (execute_lane0_bypasser_integer_RS2_bypassEnables_range_4_to_6 || execute_lane0_bypasser_integer_RS2_bypassEnables_range_0_to_3)));
    _zz_execute_lane0_bypasser_integer_RS2_sel[8] = (execute_lane0_bypasser_integer_RS2_bypassEnables_bools_8 && (! (execute_lane0_bypasser_integer_RS2_bypassEnables_range_4_to_7 || execute_lane0_bypasser_integer_RS2_bypassEnables_range_0_to_3)));
  end

  assign execute_lane0_bypasser_integer_RS2_bypassEnables_range_0_to_1 = (|{execute_lane0_bypasser_integer_RS2_bypassEnables_bools_1,execute_lane0_bypasser_integer_RS2_bypassEnables_bools_0});
  assign execute_lane0_bypasser_integer_RS2_bypassEnables_range_0_to_2 = (|{execute_lane0_bypasser_integer_RS2_bypassEnables_bools_2,execute_lane0_bypasser_integer_RS2_bypassEnables_bools_1,execute_lane0_bypasser_integer_RS2_bypassEnables_bools_0});
  assign execute_lane0_bypasser_integer_RS2_bypassEnables_range_0_to_3 = (|{execute_lane0_bypasser_integer_RS2_bypassEnables_bools_3,execute_lane0_bypasser_integer_RS2_bypassEnables_bools_2,execute_lane0_bypasser_integer_RS2_bypassEnables_bools_1,execute_lane0_bypasser_integer_RS2_bypassEnables_bools_0});
  assign execute_lane0_bypasser_integer_RS2_bypassEnables_range_4_to_5 = (|{execute_lane0_bypasser_integer_RS2_bypassEnables_bools_5,execute_lane0_bypasser_integer_RS2_bypassEnables_bools_4});
  assign execute_lane0_bypasser_integer_RS2_bypassEnables_range_4_to_6 = (|{execute_lane0_bypasser_integer_RS2_bypassEnables_bools_6,execute_lane0_bypasser_integer_RS2_bypassEnables_bools_5,execute_lane0_bypasser_integer_RS2_bypassEnables_bools_4});
  assign execute_lane0_bypasser_integer_RS2_bypassEnables_range_4_to_7 = (|{execute_lane0_bypasser_integer_RS2_bypassEnables_bools_7,execute_lane0_bypasser_integer_RS2_bypassEnables_bools_6,execute_lane0_bypasser_integer_RS2_bypassEnables_bools_5,execute_lane0_bypasser_integer_RS2_bypassEnables_bools_4});
  assign execute_lane0_bypasser_integer_RS2_sel = _zz_execute_lane0_bypasser_integer_RS2_sel;
  assign _zz_execute_ctrl1_down_integer_RS2_lane0 = execute_lane0_bypasser_integer_RS2_sel[8 : 1];
  always @(*) begin
    _zz_execute_ctrl1_down_integer_RS2_lane0_1 = ((((_zz__zz_execute_ctrl1_down_integer_RS2_lane0_1 ? execute_ctrl2_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : _zz__zz_execute_ctrl1_down_integer_RS2_lane0_1_1) | (_zz__zz_execute_ctrl1_down_integer_RS2_lane0_1_2 ? execute_ctrl3_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : _zz__zz_execute_ctrl1_down_integer_RS2_lane0_1_3)) | ((_zz__zz_execute_ctrl1_down_integer_RS2_lane0_1_4 ? execute_ctrl3_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : _zz__zz_execute_ctrl1_down_integer_RS2_lane0_1_5) | (_zz__zz_execute_ctrl1_down_integer_RS2_lane0_1_6 ? execute_ctrl4_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : _zz__zz_execute_ctrl1_down_integer_RS2_lane0_1_7))) | (((_zz__zz_execute_ctrl1_down_integer_RS2_lane0_1_8 ? execute_ctrl4_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : _zz__zz_execute_ctrl1_down_integer_RS2_lane0_1_9) | (_zz__zz_execute_ctrl1_down_integer_RS2_lane0_1_10 ? execute_ctrl5_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : _zz__zz_execute_ctrl1_down_integer_RS2_lane0_1_11)) | ((_zz__zz_execute_ctrl1_down_integer_RS2_lane0_1_12 ? execute_ctrl5_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : _zz__zz_execute_ctrl1_down_integer_RS2_lane0_1_13) | (_zz__zz_execute_ctrl1_down_integer_RS2_lane0_1_14 ? execute_lane0_bypasser_integer_RS2_port_data : _zz__zz_execute_ctrl1_down_integer_RS2_lane0_1_15))));
    if(when_ExecuteLanePlugin_l196_1) begin
      _zz_execute_ctrl1_down_integer_RS2_lane0_1 = execute_ctrl2_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0;
    end
  end

  assign execute_ctrl1_down_integer_RS2_lane0 = _zz_execute_ctrl1_down_integer_RS2_lane0_1;
  assign when_ExecuteLanePlugin_l196_1 = execute_lane0_bypasser_integer_RS2_sel[0];
  assign execute_lane0_bypasser_integer_RS2_along_bypasses_0_checks_0_selfHit = (((execute_ctrl4_up_LANE_SEL_lane0 && execute_ctrl4_up_RD_ENABLE_lane0) && (execute_ctrl4_down_RD_PHYS_lane0 == execute_ctrl2_down_RS2_PHYS_lane0)) && 1'b1);
  assign execute_lane0_bypasser_integer_RS2_along_bypasses_0_checks_0_youngerHits_0 = (((execute_ctrl3_up_LANE_SEL_lane0 && execute_ctrl3_up_RD_ENABLE_lane0) && (execute_ctrl3_down_RD_PHYS_lane0 == execute_ctrl2_down_RS2_PHYS_lane0)) && 1'b1);
  assign execute_lane0_bypasser_integer_RS2_along_bypasses_0_checks_0_youngerHits_1 = (((execute_ctrl3_up_LANE_SEL_lane1 && execute_ctrl3_up_RD_ENABLE_lane1) && (execute_ctrl3_down_RD_PHYS_lane1 == execute_ctrl2_down_RS2_PHYS_lane0)) && 1'b1);
  assign execute_lane0_bypasser_integer_RS2_along_bypasses_0_checks_0_hit = (execute_lane0_bypasser_integer_RS2_along_bypasses_0_checks_0_selfHit && (! (|{execute_lane0_bypasser_integer_RS2_along_bypasses_0_checks_0_youngerHits_1,execute_lane0_bypasser_integer_RS2_along_bypasses_0_checks_0_youngerHits_0})));
  assign execute_lane0_bypasser_integer_RS2_along_bypasses_0_checks_1_selfHit = (((execute_ctrl3_up_LANE_SEL_lane0 && execute_ctrl3_up_RD_ENABLE_lane0) && (execute_ctrl3_down_RD_PHYS_lane0 == execute_ctrl2_down_RS2_PHYS_lane0)) && 1'b1);
  assign execute_lane0_bypasser_integer_RS2_along_bypasses_0_checks_1_hit = (execute_lane0_bypasser_integer_RS2_along_bypasses_0_checks_1_selfHit && (! 1'b0));
  assign execute_lane0_bypasser_integer_RS2_along_bypasses_0_checks_2_selfHit = (((execute_ctrl4_up_LANE_SEL_lane1 && execute_ctrl4_up_RD_ENABLE_lane1) && (execute_ctrl4_down_RD_PHYS_lane1 == execute_ctrl2_down_RS2_PHYS_lane0)) && 1'b1);
  assign execute_lane0_bypasser_integer_RS2_along_bypasses_0_checks_2_youngerHits_0 = (((execute_ctrl3_up_LANE_SEL_lane0 && execute_ctrl3_up_RD_ENABLE_lane0) && (execute_ctrl3_down_RD_PHYS_lane0 == execute_ctrl2_down_RS2_PHYS_lane0)) && 1'b1);
  assign execute_lane0_bypasser_integer_RS2_along_bypasses_0_checks_2_youngerHits_1 = (((execute_ctrl3_up_LANE_SEL_lane1 && execute_ctrl3_up_RD_ENABLE_lane1) && (execute_ctrl3_down_RD_PHYS_lane1 == execute_ctrl2_down_RS2_PHYS_lane0)) && 1'b1);
  assign execute_lane0_bypasser_integer_RS2_along_bypasses_0_checks_2_hit = (execute_lane0_bypasser_integer_RS2_along_bypasses_0_checks_2_selfHit && (! (|{execute_lane0_bypasser_integer_RS2_along_bypasses_0_checks_2_youngerHits_1,execute_lane0_bypasser_integer_RS2_along_bypasses_0_checks_2_youngerHits_0})));
  assign execute_lane0_bypasser_integer_RS2_along_bypasses_0_hits = {execute_lane0_bypasser_integer_RS2_along_bypasses_0_checks_2_hit,execute_lane0_bypasser_integer_RS2_along_bypasses_0_checks_1_hit,execute_lane0_bypasser_integer_RS2_along_bypasses_0_checks_0_hit};
  assign _zz_execute_ctrl2_integer_RS2_lane0_bypass = {execute_lane0_bypasser_integer_RS2_along_bypasses_0_hits,(! (|execute_lane0_bypasser_integer_RS2_along_bypasses_0_hits))};
  assign execute_ctrl2_integer_RS2_lane0_bypass = (((_zz_execute_ctrl2_integer_RS2_lane0_bypass[0] ? execute_ctrl2_up_integer_RS2_lane0 : 32'h0) | (_zz_execute_ctrl2_integer_RS2_lane0_bypass[1] ? execute_ctrl4_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : 32'h0)) | ((_zz_execute_ctrl2_integer_RS2_lane0_bypass[2] ? execute_ctrl3_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : 32'h0) | (_zz_execute_ctrl2_integer_RS2_lane0_bypass[3] ? execute_ctrl4_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : 32'h0)));
  assign execute_lane0_bypasser_integer_RS2_along_bypasses_1_checks_0_selfHit = (((execute_ctrl4_up_LANE_SEL_lane0 && execute_ctrl4_up_RD_ENABLE_lane0) && (execute_ctrl4_down_RD_PHYS_lane0 == execute_ctrl3_down_RS2_PHYS_lane0)) && 1'b1);
  assign execute_lane0_bypasser_integer_RS2_along_bypasses_1_checks_0_hit = (execute_lane0_bypasser_integer_RS2_along_bypasses_1_checks_0_selfHit && (! 1'b0));
  assign execute_lane0_bypasser_integer_RS2_along_bypasses_1_checks_1_selfHit = (((execute_ctrl4_up_LANE_SEL_lane1 && execute_ctrl4_up_RD_ENABLE_lane1) && (execute_ctrl4_down_RD_PHYS_lane1 == execute_ctrl3_down_RS2_PHYS_lane0)) && 1'b1);
  assign execute_lane0_bypasser_integer_RS2_along_bypasses_1_checks_1_hit = (execute_lane0_bypasser_integer_RS2_along_bypasses_1_checks_1_selfHit && (! 1'b0));
  assign execute_lane0_bypasser_integer_RS2_along_bypasses_1_hits = {execute_lane0_bypasser_integer_RS2_along_bypasses_1_checks_1_hit,execute_lane0_bypasser_integer_RS2_along_bypasses_1_checks_0_hit};
  assign _zz_execute_ctrl3_integer_RS2_lane0_bypass = {execute_lane0_bypasser_integer_RS2_along_bypasses_1_hits,(! (|execute_lane0_bypasser_integer_RS2_along_bypasses_1_hits))};
  assign execute_ctrl3_integer_RS2_lane0_bypass = (((_zz_execute_ctrl3_integer_RS2_lane0_bypass[0] ? execute_ctrl3_up_integer_RS2_lane0 : 32'h0) | (_zz_execute_ctrl3_integer_RS2_lane0_bypass[1] ? execute_ctrl4_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : 32'h0)) | (_zz_execute_ctrl3_integer_RS2_lane0_bypass[2] ? execute_ctrl4_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : 32'h0));
  assign execute_lane0_logic_completions_onCtrl_0_port_valid = (((execute_ctrl2_down_LANE_SEL_lane0 && execute_ctrl2_down_isReady) && (! execute_lane0_ctrls_2_downIsCancel)) && execute_ctrl2_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0);
  assign execute_lane0_logic_completions_onCtrl_0_port_payload_uopId = execute_ctrl2_down_Decode_UOP_ID_lane0;
  assign execute_lane0_logic_completions_onCtrl_0_port_payload_trap = execute_ctrl2_down_TRAP_lane0;
  assign execute_lane0_logic_completions_onCtrl_0_port_payload_commit = execute_ctrl2_down_COMMIT_lane0;
  assign execute_lane0_logic_completions_onCtrl_1_port_valid = (((execute_ctrl4_down_LANE_SEL_lane0 && execute_ctrl4_down_isReady) && (! execute_lane0_ctrls_4_downIsCancel)) && execute_ctrl4_down_lane0_logic_completions_onCtrl_1_ENABLE_lane0);
  assign execute_lane0_logic_completions_onCtrl_1_port_payload_uopId = execute_ctrl4_down_Decode_UOP_ID_lane0;
  assign execute_lane0_logic_completions_onCtrl_1_port_payload_trap = execute_ctrl4_down_TRAP_lane0;
  assign execute_lane0_logic_completions_onCtrl_1_port_payload_commit = execute_ctrl4_down_COMMIT_lane0;
  assign execute_lane0_logic_completions_onCtrl_2_port_valid = (((execute_ctrl3_down_LANE_SEL_lane0 && execute_ctrl3_down_isReady) && (! execute_lane0_ctrls_3_downIsCancel)) && execute_ctrl3_down_lane0_logic_completions_onCtrl_2_ENABLE_lane0);
  assign execute_lane0_logic_completions_onCtrl_2_port_payload_uopId = execute_ctrl3_down_Decode_UOP_ID_lane0;
  assign execute_lane0_logic_completions_onCtrl_2_port_payload_trap = execute_ctrl3_down_TRAP_lane0;
  assign execute_lane0_logic_completions_onCtrl_2_port_payload_commit = execute_ctrl3_down_COMMIT_lane0;
  assign execute_lane0_logic_decoding_decodingBits = {execute_ctrl1_down_lane0_LAYER_SEL_lane0,execute_ctrl1_down_Decode_UOP_lane0};
  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0 = ((execute_lane0_logic_decoding_decodingBits & 33'h100106020) == 33'h100006000);
  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0_1 = ((execute_lane0_logic_decoding_decodingBits & 33'h100006820) == 33'h100006800);
  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0_2 = ((execute_lane0_logic_decoding_decodingBits & 33'h100006420) == 33'h100006400);
  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0_3 = ((execute_lane0_logic_decoding_decodingBits & 33'h100006120) == 33'h100006100);
  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0_4 = ((execute_lane0_logic_decoding_decodingBits & 33'h100806020) == 33'h100806000);
  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0_5 = ((execute_lane0_logic_decoding_decodingBits & 33'h101006020) == 33'h101006000);
  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0_6 = ((execute_lane0_logic_decoding_decodingBits & 33'h1000060a0) == 33'h100006080);
  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0_7 = ((execute_lane0_logic_decoding_decodingBits & 33'h100006220) == 33'h100006200);
  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0_8 = ((execute_lane0_logic_decoding_decodingBits & 33'h100406020) == 33'h100406000);
  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0_9 = ((execute_lane0_logic_decoding_decodingBits & 33'h100003020) == 33'h100003000);
  always @(*) begin
    execute_ctrl1_down_early0_IntAluPlugin_SEL_lane0 = _zz_execute_ctrl1_down_early0_IntAluPlugin_SEL_lane0[0];
    if(execute_ctrl1_down_TRAP_lane0) begin
      execute_ctrl1_down_early0_IntAluPlugin_SEL_lane0 = 1'b0;
    end
  end

  always @(*) begin
    execute_ctrl1_down_early0_BarrelShifterPlugin_SEL_lane0 = _zz_execute_ctrl1_down_early0_BarrelShifterPlugin_SEL_lane0[0];
    if(execute_ctrl1_down_TRAP_lane0) begin
      execute_ctrl1_down_early0_BarrelShifterPlugin_SEL_lane0 = 1'b0;
    end
  end

  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0_10 = ((execute_lane0_logic_decoding_decodingBits & 33'h100000050) == 33'h100000040);
  always @(*) begin
    execute_ctrl1_down_early0_BranchPlugin_SEL_lane0 = _zz_execute_ctrl1_down_early0_BranchPlugin_SEL_lane0[0];
    if(execute_ctrl1_down_TRAP_lane0) begin
      execute_ctrl1_down_early0_BranchPlugin_SEL_lane0 = 1'b0;
    end
  end

  always @(*) begin
    execute_ctrl1_down_early0_MulPlugin_SEL_lane0 = _zz_execute_ctrl1_down_early0_MulPlugin_SEL_lane0[0];
    if(execute_ctrl1_down_TRAP_lane0) begin
      execute_ctrl1_down_early0_MulPlugin_SEL_lane0 = 1'b0;
    end
  end

  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_2_ENABLE_lane0 = ((execute_lane0_logic_decoding_decodingBits & 33'h002004064) == 33'h002004020);
  always @(*) begin
    execute_ctrl1_down_early0_DivPlugin_SEL_lane0 = _zz_execute_ctrl1_down_early0_DivPlugin_SEL_lane0[0];
    if(execute_ctrl1_down_TRAP_lane0) begin
      execute_ctrl1_down_early0_DivPlugin_SEL_lane0 = 1'b0;
    end
  end

  assign _zz_execute_ctrl1_down_lane0_logic_completions_onCtrl_0_ENABLE_lane0_11 = ((execute_lane0_logic_decoding_decodingBits & 33'h000001048) == 33'h000001008);
  always @(*) begin
    execute_ctrl1_down_early0_EnvPlugin_SEL_lane0 = _zz_execute_ctrl1_down_early0_EnvPlugin_SEL_lane0[0];
    if(execute_ctrl1_down_TRAP_lane0) begin
      execute_ctrl1_down_early0_EnvPlugin_SEL_lane0 = 1'b0;
    end
  end

  always @(*) begin
    execute_ctrl1_down_late0_IntAluPlugin_SEL_lane0 = _zz_execute_ctrl1_down_late0_IntAluPlugin_SEL_lane0[0];
    if(execute_ctrl1_down_TRAP_lane0) begin
      execute_ctrl1_down_late0_IntAluPlugin_SEL_lane0 = 1'b0;
    end
  end

  always @(*) begin
    execute_ctrl1_down_late0_BarrelShifterPlugin_SEL_lane0 = _zz_execute_ctrl1_down_late0_BarrelShifterPlugin_SEL_lane0[0];
    if(execute_ctrl1_down_TRAP_lane0) begin
      execute_ctrl1_down_late0_BarrelShifterPlugin_SEL_lane0 = 1'b0;
    end
  end

