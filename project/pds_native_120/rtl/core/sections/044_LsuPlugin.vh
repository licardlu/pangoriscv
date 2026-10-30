  assign LsuPlugin_logic_flusher_wantKill = 1'b0;
  assign TrapPlugin_logic_lsuL1Invalidate_0_cmd_ready = LsuPlugin_logic_flusher_arbiter_io_inputs_0_ready;
  assign LsuPlugin_logic_flusher_inflight = (|{(execute_ctrl4_down_LsuL1_SEL_lane0 && execute_ctrl4_down_LsuL1_FLUSH_lane0),(execute_ctrl3_down_LsuL1_SEL_lane0 && execute_ctrl3_down_LsuL1_FLUSH_lane0)});
  always @(*) begin
    LsuPlugin_logic_flusher_arbiter_io_output_ready = 1'b0;
    case(LsuPlugin_logic_flusher_stateReg)
      LsuPlugin_logic_flusher_SB_DRAIN : begin
      end
      LsuPlugin_logic_flusher_CMD : begin
      end
      LsuPlugin_logic_flusher_COMPLETION : begin
        if(when_LsuPlugin_l419) begin
          LsuPlugin_logic_flusher_arbiter_io_output_ready = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  assign PrivilegedPlugin_api_lsuTriggerBus_load = (execute_ctrl3_down_LsuL1_LOAD_lane0 || execute_ctrl3_down_LsuL1_EXECUTE_lane0);
  assign PrivilegedPlugin_api_lsuTriggerBus_store = execute_ctrl3_down_LsuL1_STORE_lane0;
  assign PrivilegedPlugin_api_lsuTriggerBus_virtual = execute_ctrl3_down_LsuL1_MIXED_ADDRESS_lane0;
  assign PrivilegedPlugin_api_lsuTriggerBus_size = execute_ctrl3_down_LsuL1_SIZE_lane0;
  assign execute_ctrl3_down_LsuPlugin_logic_onTrigger_HIT_lane0 = 1'b0;
  assign execute_ctrl2_down_LsuPlugin_logic_FORCE_PHYSICAL_lane0 = (execute_ctrl2_down_LsuPlugin_logic_FROM_ACCESS_lane0 || execute_ctrl2_down_LsuPlugin_logic_FROM_WB_lane0);
  assign execute_ctrl2_down_LsuPlugin_logic_onAddress0_LOAD_MMU_lane0 = ((execute_ctrl2_down_AguPlugin_LOAD_lane0 || execute_ctrl2_down_AguPlugin_CLEAN_lane0) || execute_ctrl2_down_AguPlugin_INVALIDATE_lane0);
  assign LsuPlugin_logic_onAddress0_ls_prefetchOp = execute_ctrl2_down_Decode_UOP_lane0[24 : 20];
  assign LsuPlugin_logic_onAddress0_ls_port_valid = (execute_ctrl2_up_LANE_SEL_lane0 && execute_ctrl2_down_AguPlugin_SEL_lane0);
  assign LsuPlugin_logic_onAddress0_ls_port_payload_address = execute_ctrl2_down_early0_SrcPlugin_ADD_SUB_lane0;
  assign LsuPlugin_logic_onAddress0_ls_port_payload_size = execute_ctrl2_down_AguPlugin_SIZE_lane0;
  assign LsuPlugin_logic_onAddress0_ls_port_payload_load = execute_ctrl2_down_AguPlugin_LOAD_lane0;
  assign LsuPlugin_logic_onAddress0_ls_port_payload_store = execute_ctrl2_down_AguPlugin_STORE_lane0;
  assign LsuPlugin_logic_onAddress0_ls_port_payload_execute = execute_ctrl2_down_AguPlugin_EXECUTE_lane0;
  assign LsuPlugin_logic_onAddress0_ls_port_payload_atomic = execute_ctrl2_down_AguPlugin_ATOMIC_lane0;
  assign LsuPlugin_logic_onAddress0_ls_port_payload_clean = 1'b0;
  assign LsuPlugin_logic_onAddress0_ls_port_payload_invalidate = 1'b0;
  assign LsuPlugin_logic_onAddress0_ls_port_payload_guest = execute_ctrl2_down_AguPlugin_GUEST_lane0;
  always @(*) begin
    LsuPlugin_logic_onAddress0_ls_port_payload_op = LsuL1CmdOpcode_LSU;
    if(execute_ctrl2_down_LsuPlugin_logic_LSU_PREFETCH_lane0) begin
      LsuPlugin_logic_onAddress0_ls_port_payload_op = LsuL1CmdOpcode_PREFETCH;
    end
  end

  assign LsuPlugin_logic_onAddress0_ls_port_fire = (LsuPlugin_logic_onAddress0_ls_port_valid && LsuPlugin_logic_onAddress0_ls_port_ready);
  assign LsuPlugin_logic_onAddress0_ls_port_payload_storeId = LsuPlugin_logic_onAddress0_ls_storeId;
  assign LsuPlugin_logic_onAddress0_flush_port_valid = ((LsuPlugin_logic_flusher_stateReg == LsuPlugin_logic_flusher_CMD) && (! LsuPlugin_logic_flusher_cmdCounter[6]));
  assign LsuPlugin_logic_onAddress0_flush_port_payload_address = {19'd0, _zz_LsuPlugin_logic_onAddress0_flush_port_payload_address};
  assign LsuPlugin_logic_onAddress0_flush_port_payload_size = 2'b00;
  assign LsuPlugin_logic_onAddress0_flush_port_payload_load = 1'b0;
  assign LsuPlugin_logic_onAddress0_flush_port_payload_store = 1'b0;
  assign LsuPlugin_logic_onAddress0_flush_port_payload_execute = 1'b0;
  assign LsuPlugin_logic_onAddress0_flush_port_payload_atomic = 1'b0;
  assign LsuPlugin_logic_onAddress0_flush_port_payload_clean = 1'b0;
  assign LsuPlugin_logic_onAddress0_flush_port_payload_invalidate = 1'b0;
  assign LsuPlugin_logic_onAddress0_flush_port_payload_guest = 1'b0;
  assign LsuPlugin_logic_onAddress0_flush_port_payload_op = LsuL1CmdOpcode_FLUSH;
  assign LsuPlugin_logic_onAddress0_flush_port_payload_storeId = 12'h0;
  assign LsuPlugin_logic_onAddress0_flush_port_fire = (LsuPlugin_logic_onAddress0_flush_port_valid && LsuPlugin_logic_onAddress0_flush_port_ready);
  assign LsuPlugin_logic_onAddress0_fromHp_port_valid = PrefetcherRptPlugin_io_valid;
  assign PrefetcherRptPlugin_io_ready = LsuPlugin_logic_onAddress0_fromHp_port_ready;
  assign LsuPlugin_logic_onAddress0_fromHp_port_payload_op = LsuL1CmdOpcode_PREFETCH;
  assign LsuPlugin_logic_onAddress0_fromHp_port_payload_address = PrefetcherRptPlugin_io_payload_address;
  assign LsuPlugin_logic_onAddress0_fromHp_port_payload_store = PrefetcherRptPlugin_io_payload_unique;
  assign LsuPlugin_logic_onAddress0_fromHp_port_payload_size = 2'b00;
  assign LsuPlugin_logic_onAddress0_fromHp_port_payload_load = 1'b0;
  assign LsuPlugin_logic_onAddress0_fromHp_port_payload_execute = 1'b0;
  assign LsuPlugin_logic_onAddress0_fromHp_port_payload_atomic = 1'b0;
  assign LsuPlugin_logic_onAddress0_fromHp_port_payload_clean = 1'b0;
  assign LsuPlugin_logic_onAddress0_fromHp_port_payload_invalidate = 1'b0;
  assign LsuPlugin_logic_onAddress0_fromHp_port_payload_guest = 1'b0;
  assign LsuPlugin_logic_onAddress0_fromHp_port_payload_storeId = 12'h0;
  assign LsuPlugin_logic_onAddress0_sb_isHead = (LsuPlugin_logic_storeBuffer_pop_payload_ptr == LsuPlugin_logic_storeBuffer_ops_freePtr);
  assign LsuPlugin_logic_onAddress0_sb_flush = (LsuPlugin_logic_storeBuffer_waitL1_valid && (! LsuPlugin_logic_onAddress0_sb_isHead));
  assign LsuPlugin_logic_onAddress0_sb_port_valid = ((LsuPlugin_logic_storeBuffer_pop_valid && (! LsuPlugin_logic_storeBuffer_waitL1_valid)) && (! LsuPlugin_logic_onAddress0_sb_flush));
  assign LsuPlugin_logic_onAddress0_sb_port_payload_address = LsuPlugin_logic_storeBuffer_pop_payload_op_address;
  assign LsuPlugin_logic_onAddress0_sb_port_payload_size = LsuPlugin_logic_storeBuffer_pop_payload_op_size;
  assign LsuPlugin_logic_onAddress0_sb_port_payload_load = 1'b0;
  assign LsuPlugin_logic_onAddress0_sb_port_payload_store = 1'b1;
  assign LsuPlugin_logic_onAddress0_sb_port_payload_execute = 1'b0;
  assign LsuPlugin_logic_onAddress0_sb_port_payload_atomic = 1'b0;
  assign LsuPlugin_logic_onAddress0_sb_port_payload_clean = 1'b0;
  assign LsuPlugin_logic_onAddress0_sb_port_payload_invalidate = 1'b0;
  assign LsuPlugin_logic_onAddress0_sb_port_payload_guest = 1'b0;
  assign LsuPlugin_logic_onAddress0_sb_port_payload_op = LsuL1CmdOpcode_STORE_BUFFER;
  assign LsuPlugin_logic_storeBuffer_pop_ready = (LsuPlugin_logic_onAddress0_sb_port_ready || LsuPlugin_logic_onAddress0_sb_flush);
  assign LsuPlugin_logic_onAddress0_sb_port_payload_storeId = LsuPlugin_logic_storeBuffer_pop_payload_op_storeId;
  assign LsuPlugin_logic_onAddress0_ls_port_ready = LsuPlugin_logic_onAddress0_arbiter_io_inputs_0_ready;
  assign LsuPlugin_logic_onAddress0_flush_port_ready = LsuPlugin_logic_onAddress0_arbiter_io_inputs_1_ready;
  assign LsuPlugin_logic_onAddress0_fromHp_port_ready = LsuPlugin_logic_onAddress0_arbiter_io_inputs_2_ready;
  assign LsuPlugin_logic_onAddress0_sb_port_ready = LsuPlugin_logic_onAddress0_arbiter_io_inputs_3_ready;
  assign LsuPlugin_logic_onAddress0_arbiter_io_output_ready = (! execute_freeze_valid);
  assign execute_ctrl2_down_LsuL1_SEL_lane0 = LsuPlugin_logic_onAddress0_arbiter_io_output_valid;
  assign execute_ctrl2_down_LsuL1_MIXED_ADDRESS_lane0 = LsuPlugin_logic_onAddress0_arbiter_io_output_payload_address;
  always @(*) begin
    _zz_execute_ctrl2_down_LsuL1_MASK_lane0 = 4'bxxxx;
    case(LsuPlugin_logic_onAddress0_arbiter_io_output_payload_size)
      2'b00 : begin
        _zz_execute_ctrl2_down_LsuL1_MASK_lane0 = 4'b0001;
      end
      2'b01 : begin
        _zz_execute_ctrl2_down_LsuL1_MASK_lane0 = 4'b0011;
      end
      2'b10 : begin
        _zz_execute_ctrl2_down_LsuL1_MASK_lane0 = 4'b1111;
      end
      default : begin
      end
    endcase
  end

  assign execute_ctrl2_down_LsuL1_MASK_lane0 = (_zz_execute_ctrl2_down_LsuL1_MASK_lane0 <<< LsuPlugin_logic_onAddress0_arbiter_io_output_payload_address[1 : 0]);
  assign execute_ctrl2_down_LsuL1_SIZE_lane0 = LsuPlugin_logic_onAddress0_arbiter_io_output_payload_size;
  assign execute_ctrl2_down_LsuL1_LOAD_lane0 = LsuPlugin_logic_onAddress0_arbiter_io_output_payload_load;
  assign execute_ctrl2_down_LsuL1_EXECUTE_lane0 = LsuPlugin_logic_onAddress0_arbiter_io_output_payload_execute;
  assign execute_ctrl2_down_LsuL1_ATOMIC_lane0 = LsuPlugin_logic_onAddress0_arbiter_io_output_payload_atomic;
  assign execute_ctrl2_down_LsuL1_STORE_lane0 = LsuPlugin_logic_onAddress0_arbiter_io_output_payload_store;
  assign execute_ctrl2_down_LsuL1_CLEAN_lane0 = LsuPlugin_logic_onAddress0_arbiter_io_output_payload_clean;
  assign execute_ctrl2_down_LsuL1_INVALID_lane0 = LsuPlugin_logic_onAddress0_arbiter_io_output_payload_invalidate;
  assign execute_ctrl2_down_LsuL1_GUEST_lane0 = LsuPlugin_logic_onAddress0_arbiter_io_output_payload_guest;
  assign execute_ctrl2_down_LsuL1_PREFETCH_lane0 = (LsuPlugin_logic_onAddress0_arbiter_io_output_payload_op == LsuL1CmdOpcode_PREFETCH);
  assign execute_ctrl2_down_LsuL1_FLUSH_lane0 = (LsuPlugin_logic_onAddress0_arbiter_io_output_payload_op == LsuL1CmdOpcode_FLUSH);
  assign execute_ctrl2_down_Decode_STORE_ID_lane0 = LsuPlugin_logic_onAddress0_arbiter_io_output_payload_storeId;
  assign execute_ctrl2_down_LsuPlugin_logic_FROM_ACCESS_lane0 = (LsuPlugin_logic_onAddress0_arbiter_io_output_payload_op == LsuL1CmdOpcode_ACCESS_1);
  assign execute_ctrl2_down_LsuPlugin_logic_FROM_WB_lane0 = (LsuPlugin_logic_onAddress0_arbiter_io_output_payload_op == LsuL1CmdOpcode_STORE_BUFFER);
  assign execute_ctrl2_down_LsuPlugin_logic_FROM_LSU_lane0 = (LsuPlugin_logic_onAddress0_arbiter_io_output_payload_op == LsuL1CmdOpcode_LSU);
  assign execute_ctrl2_down_LsuPlugin_logic_FROM_PREFETCH_lane0 = (LsuPlugin_logic_onAddress0_arbiter_io_output_payload_op == LsuL1CmdOpcode_PREFETCH);
  assign when_LsuPlugin_l596 = (! execute_ctrl2_down_LsuPlugin_logic_FROM_LSU_lane0);
  assign execute_ctrl2_down_LsuPlugin_SB_PTR_lane0 = LsuPlugin_logic_storeBuffer_pop_payload_ptr;
  assign execute_ctrl2_down_LsuPlugin_logic_onAddress0_SB_DATA_lane0 = LsuPlugin_logic_storeBuffer_pop_payload_op_data;
  assign execute_ctrl2_down_LsuPlugin_logic_onAddress0_STORE_BUFFER_EMPTY_lane0 = LsuPlugin_logic_storeBuffer_empty;
  assign execute_ctrl3_down_LsuL1_PHYSICAL_ADDRESS_lane0 = execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_TRANSLATED_lane0;
  assign execute_ctrl3_down_LsuPlugin_logic_onAddress1_LOAD_MMU_lane0 = ((execute_ctrl3_down_AguPlugin_LOAD_lane0 || execute_ctrl3_down_AguPlugin_CLEAN_lane0) || execute_ctrl3_down_AguPlugin_INVALIDATE_lane0);
  assign when_LsuPlugin_l647 = (execute_ctrl3_down_LsuPlugin_logic_FROM_LSU_lane0 && (! execute_ctrl3_up_LANE_SEL_lane0));
  assign when_LsuPlugin_l647_1 = (execute_ctrl4_down_LsuPlugin_logic_FROM_LSU_lane0 && (! execute_ctrl4_up_LANE_SEL_lane0));
  assign execute_ctrl3_down_LsuPlugin_logic_preCtrl_MISS_ALIGNED_lane0 = (|{((execute_ctrl3_down_LsuL1_SIZE_lane0 == 2'b10) && (execute_ctrl3_down_LsuL1_MIXED_ADDRESS_lane0[1 : 0] != 2'b00)),((execute_ctrl3_down_LsuL1_SIZE_lane0 == 2'b01) && (execute_ctrl3_down_LsuL1_MIXED_ADDRESS_lane0[0 : 0] != 1'b0))});
  assign execute_ctrl3_down_LsuPlugin_logic_preCtrl_IS_AMO_lane0 = (((execute_ctrl3_down_AguPlugin_SEL_lane0 && execute_ctrl3_down_LsuL1_ATOMIC_lane0) && execute_ctrl3_down_LsuL1_STORE_lane0) && execute_ctrl3_down_LsuL1_LOAD_lane0);
  assign LsuPlugin_logic_onPma_cached_cmd_address = execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_TRANSLATED_lane0;
  always @(*) begin
    LsuPlugin_logic_onPma_cached_cmd_op[0] = execute_ctrl3_down_LsuL1_STORE_lane0;
    LsuPlugin_logic_onPma_cached_cmd_op[1] = execute_ctrl3_down_LsuL1_EXECUTE_lane0;
  end

  assign LsuPlugin_logic_onPma_io_cmd_address = execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_TRANSLATED_lane0;
  assign LsuPlugin_logic_onPma_io_cmd_size = execute_ctrl3_down_LsuL1_SIZE_lane0;
  always @(*) begin
    LsuPlugin_logic_onPma_io_cmd_op[0] = execute_ctrl3_down_LsuL1_STORE_lane0;
    LsuPlugin_logic_onPma_io_cmd_op[1] = execute_ctrl3_down_LsuL1_EXECUTE_lane0;
  end

  assign execute_ctrl3_down_LsuPlugin_logic_onPma_CACHED_RSP_lane0_fault = LsuPlugin_logic_onPma_cached_rsp_fault;
  assign execute_ctrl3_down_LsuPlugin_logic_onPma_CACHED_RSP_lane0_io = LsuPlugin_logic_onPma_cached_rsp_io;
  always @(*) begin
    execute_ctrl3_down_LsuPlugin_logic_onPma_IO_RSP_lane0_fault = LsuPlugin_logic_onPma_io_rsp_fault;
    if(when_LsuPlugin_l672) begin
      execute_ctrl3_down_LsuPlugin_logic_onPma_IO_RSP_lane0_fault = 1'b1;
    end
  end

  assign execute_ctrl3_down_LsuPlugin_logic_onPma_IO_RSP_lane0_io = LsuPlugin_logic_onPma_io_rsp_io;
  assign when_LsuPlugin_l672 = (execute_ctrl3_down_LsuL1_ATOMIC_lane0 || execute_ctrl3_down_LsuPlugin_logic_FROM_ACCESS_lane0);
  assign execute_ctrl3_down_LsuPlugin_logic_onPma_IO_lane0 = (((execute_ctrl3_down_LsuPlugin_logic_onPma_CACHED_RSP_lane0_fault && (! execute_ctrl3_down_LsuPlugin_logic_onPma_IO_RSP_lane0_fault)) && (! execute_ctrl3_down_LsuPlugin_logic_FENCE_lane0)) && (! execute_ctrl3_down_LsuPlugin_logic_FROM_PREFETCH_lane0));
  assign execute_ctrl3_down_LsuPlugin_logic_onPma_FROM_LSU_MSB_FAILED_lane0 = (execute_ctrl3_down_LsuPlugin_logic_FROM_LSU_lane0 && 1'b0);
  assign execute_ctrl3_down_LsuPlugin_logic_MMU_PAGE_FAULT_lane0 = execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_PAGE_FAULT_lane0;
  assign execute_ctrl3_down_LsuPlugin_logic_MMU_FAILURE_lane0 = ((((execute_ctrl3_down_LsuPlugin_logic_MMU_PAGE_FAULT_lane0 || execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_ACCESS_FAULT_lane0) || execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_REFILL_lane0) || execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_HAZARD_lane0) || execute_ctrl3_down_LsuPlugin_logic_onPma_FROM_LSU_MSB_FAILED_lane0);
  assign execute_ctrl3_down_LsuPlugin_logic_GUEST_MMU_PAGE_FAULT_lane0 = execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_PAGE_FAULT_lane0;
  assign execute_ctrl3_down_LsuPlugin_logic_GUEST_MMU_FAILURE_lane0 = (((execute_ctrl3_down_LsuPlugin_logic_GUEST_MMU_PAGE_FAULT_lane0 || execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_ACCESS_FAULT_lane0) || execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_REFILL_lane0) || execute_ctrl3_down_LsuPlugin_logic_onAddress0_translationPort_keys_HAZARD_lane0);
  always @(*) begin
    LsuPlugin_logic_onCtrl_lsuTrap = 1'b0;
    if(LsuPlugin_logic_onCtrl_traps_accessFault) begin
      LsuPlugin_logic_onCtrl_lsuTrap = 1'b1;
    end
    if(when_LsuPlugin_l866) begin
      LsuPlugin_logic_onCtrl_lsuTrap = 1'b1;
    end
    if(LsuPlugin_logic_onCtrl_traps_pmaFault) begin
      LsuPlugin_logic_onCtrl_lsuTrap = 1'b1;
    end
    if(execute_ctrl4_down_LsuPlugin_logic_MMU_PAGE_FAULT_lane0) begin
      LsuPlugin_logic_onCtrl_lsuTrap = 1'b1;
    end
    if(execute_ctrl4_down_LsuPlugin_logic_onAddress0_translationPort_keys_ACCESS_FAULT_lane0) begin
      LsuPlugin_logic_onCtrl_lsuTrap = 1'b1;
    end
    if(execute_ctrl4_down_LsuPlugin_logic_onAddress0_translationPort_keys_REFILL_lane0) begin
      LsuPlugin_logic_onCtrl_lsuTrap = 1'b1;
    end
    if(execute_ctrl4_down_LsuPlugin_logic_onAddress0_translationPort_keys_HAZARD_lane0) begin
      LsuPlugin_logic_onCtrl_lsuTrap = 1'b1;
    end
    if(execute_ctrl4_down_LsuPlugin_logic_onPma_FROM_LSU_MSB_FAILED_lane0) begin
      LsuPlugin_logic_onCtrl_lsuTrap = 1'b1;
    end
    if(execute_ctrl4_down_LsuPlugin_logic_preCtrl_MISS_ALIGNED_lane0) begin
      LsuPlugin_logic_onCtrl_lsuTrap = 1'b1;
    end
    if(execute_ctrl4_down_LsuPlugin_logic_onTrigger_HIT_lane0) begin
      LsuPlugin_logic_onCtrl_lsuTrap = 1'b1;
    end
    if(when_LsuPlugin_l975) begin
      LsuPlugin_logic_onCtrl_lsuTrap = 1'b0;
    end
    if(when_LsuPlugin_l985) begin
      LsuPlugin_logic_onCtrl_lsuTrap = 1'b1;
    end
  end

  always @(*) begin
    LsuPlugin_logic_onCtrl_writeData = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    LsuPlugin_logic_onCtrl_writeData[31 : 0] = execute_ctrl4_up_integer_RS2_lane0;
  end

  assign when_LsuPlugin_l701 = (((((! LsuPlugin_logic_onCtrl_lsuTrap) && (! execute_lane0_ctrls_4_upIsCancel)) && execute_ctrl4_down_LsuPlugin_logic_FROM_LSU_lane0) && (! execute_ctrl4_down_LsuL1_CLEAN_lane0)) && (! execute_ctrl4_down_LsuL1_INVALID_lane0));
  assign LsuPlugin_logic_onCtrl_io_doIt = ((execute_ctrl4_up_LANE_SEL_lane0 && execute_ctrl4_down_LsuL1_SEL_lane0) && execute_ctrl4_down_LsuPlugin_logic_onPma_IO_lane0);
  assign LsuPlugin_logic_bus_cmd_fire = (LsuPlugin_logic_bus_cmd_valid && LsuPlugin_logic_bus_cmd_ready);
  assign when_LsuPlugin_l705 = (! execute_freeze_valid);
  assign LsuPlugin_logic_bus_cmd_valid = (((LsuPlugin_logic_onCtrl_io_doItReg && (! LsuPlugin_logic_onCtrl_io_cmdSent)) && LsuPlugin_logic_onCtrl_io_allowIt) && (! LsuPlugin_logic_onCtrl_io_tooEarly));
  assign LsuPlugin_logic_bus_cmd_payload_write = execute_ctrl4_down_LsuL1_STORE_lane0;
  assign LsuPlugin_logic_bus_cmd_payload_address = execute_ctrl4_down_LsuL1_PHYSICAL_ADDRESS_lane0;
  assign LsuPlugin_logic_bus_cmd_payload_data = execute_ctrl4_down_LsuL1_WRITE_DATA_lane0;
  assign LsuPlugin_logic_bus_cmd_payload_size = execute_ctrl4_down_LsuL1_SIZE_lane0;
  assign LsuPlugin_logic_bus_cmd_payload_mask = execute_ctrl4_down_LsuL1_MASK_lane0;
  assign LsuPlugin_logic_bus_cmd_payload_io = 1'b1;
  assign LsuPlugin_logic_bus_cmd_payload_fromHart = 1'b1;
  assign LsuPlugin_logic_bus_cmd_payload_uopId = execute_ctrl4_down_Decode_UOP_ID_lane0;
  assign LsuPlugin_logic_bus_rsp_toStream_valid = LsuPlugin_logic_bus_rsp_valid;
  assign LsuPlugin_logic_bus_rsp_toStream_payload_error = LsuPlugin_logic_bus_rsp_payload_error;
  assign LsuPlugin_logic_bus_rsp_toStream_payload_data = LsuPlugin_logic_bus_rsp_payload_data;
  assign LsuPlugin_logic_onCtrl_io_rsp_fire = (LsuPlugin_logic_onCtrl_io_rsp_valid && LsuPlugin_logic_onCtrl_io_rsp_ready);
  assign LsuPlugin_logic_bus_rsp_toStream_ready = (! LsuPlugin_logic_bus_rsp_toStream_rValid);
  assign LsuPlugin_logic_onCtrl_io_rsp_valid = LsuPlugin_logic_bus_rsp_toStream_rValid;
  assign LsuPlugin_logic_onCtrl_io_rsp_payload_error = LsuPlugin_logic_bus_rsp_toStream_rData_error;
  assign LsuPlugin_logic_onCtrl_io_rsp_payload_data = LsuPlugin_logic_bus_rsp_toStream_rData_data;
  assign LsuPlugin_logic_onCtrl_io_rsp_ready = (! execute_freeze_valid);
  assign LsuPlugin_logic_onCtrl_io_freezeIt = (LsuPlugin_logic_onCtrl_io_doIt && (LsuPlugin_logic_onCtrl_io_tooEarly || ((! LsuPlugin_logic_onCtrl_io_rsp_valid) && LsuPlugin_logic_onCtrl_io_allowIt)));
  assign LsuPlugin_logic_onCtrl_loadData_input = (LsuPlugin_logic_onCtrl_io_cmdSent ? LsuPlugin_logic_onCtrl_io_rsp_payload_data : execute_ctrl4_down_LsuL1_READ_DATA_lane0);
  assign LsuPlugin_logic_onCtrl_loadData_splitted_0 = LsuPlugin_logic_onCtrl_loadData_input[7 : 0];
  assign LsuPlugin_logic_onCtrl_loadData_splitted_1 = LsuPlugin_logic_onCtrl_loadData_input[15 : 8];
  assign LsuPlugin_logic_onCtrl_loadData_splitted_2 = LsuPlugin_logic_onCtrl_loadData_input[23 : 16];
  assign LsuPlugin_logic_onCtrl_loadData_splitted_3 = LsuPlugin_logic_onCtrl_loadData_input[31 : 24];
  always @(*) begin
    LsuPlugin_logic_onCtrl_loadData_shifted[7 : 0] = _zz_LsuPlugin_logic_onCtrl_loadData_shifted;
    LsuPlugin_logic_onCtrl_loadData_shifted[15 : 8] = _zz_LsuPlugin_logic_onCtrl_loadData_shifted_2;
    LsuPlugin_logic_onCtrl_loadData_shifted[23 : 16] = LsuPlugin_logic_onCtrl_loadData_splitted_2;
    LsuPlugin_logic_onCtrl_loadData_shifted[31 : 24] = LsuPlugin_logic_onCtrl_loadData_splitted_3;
  end

  assign execute_ctrl4_down_LsuPlugin_logic_onCtrl_loadData_RESULT_lane0 = LsuPlugin_logic_onCtrl_loadData_shifted;
  assign LsuPlugin_logic_onCtrl_storeData_mapping_0_1 = {4{LsuPlugin_logic_onCtrl_writeData[7 : 0]}};
  assign LsuPlugin_logic_onCtrl_storeData_mapping_1_1 = {2{LsuPlugin_logic_onCtrl_writeData[15 : 0]}};
  assign LsuPlugin_logic_onCtrl_storeData_mapping_2_1 = {1{LsuPlugin_logic_onCtrl_writeData[31 : 0]}};
  always @(*) begin
    _zz_execute_ctrl4_down_LsuL1_WRITE_DATA_lane0 = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    case(execute_ctrl4_down_LsuL1_SIZE_lane0)
      2'b00 : begin
        _zz_execute_ctrl4_down_LsuL1_WRITE_DATA_lane0 = LsuPlugin_logic_onCtrl_storeData_mapping_0_1;
      end
      2'b01 : begin
        _zz_execute_ctrl4_down_LsuL1_WRITE_DATA_lane0 = LsuPlugin_logic_onCtrl_storeData_mapping_1_1;
      end
      2'b10 : begin
        _zz_execute_ctrl4_down_LsuL1_WRITE_DATA_lane0 = LsuPlugin_logic_onCtrl_storeData_mapping_2_1;
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    execute_ctrl4_down_LsuL1_WRITE_DATA_lane0 = _zz_execute_ctrl4_down_LsuL1_WRITE_DATA_lane0;
    if(execute_ctrl4_down_LsuPlugin_logic_FROM_WB_lane0) begin
      execute_ctrl4_down_LsuL1_WRITE_DATA_lane0 = execute_ctrl4_down_LsuPlugin_logic_onAddress0_SB_DATA_lane0;
    end
  end

  assign execute_ctrl4_down_LsuPlugin_logic_onCtrl_SC_MISS_lane0 = LsuPlugin_logic_onCtrl_scMiss;
  assign LsuPlugin_logic_onCtrl_scMiss = 1'b0;
  assign LsuL1_lockPort_valid = 1'b0;
  assign LsuL1_lockPort_address = 32'h0;
  assign LsuPlugin_logic_onCtrl_wb_tag = execute_ctrl4_down_LsuL1_PHYSICAL_ADDRESS_lane0[11 : 6];
  assign LsuPlugin_logic_onCtrl_wb_hits = {(LsuPlugin_logic_storeBuffer_slots_3_valid && (LsuPlugin_logic_storeBuffer_slots_3_tag == LsuPlugin_logic_onCtrl_wb_tag)),(LsuPlugin_logic_storeBuffer_slots_2_valid && (LsuPlugin_logic_storeBuffer_slots_2_tag == LsuPlugin_logic_onCtrl_wb_tag)),(LsuPlugin_logic_storeBuffer_slots_1_valid && (LsuPlugin_logic_storeBuffer_slots_1_tag == LsuPlugin_logic_onCtrl_wb_tag)),(LsuPlugin_logic_storeBuffer_slots_0_valid && (LsuPlugin_logic_storeBuffer_slots_0_tag == LsuPlugin_logic_onCtrl_wb_tag))};
  assign LsuPlugin_logic_onCtrl_wb_hit = (|LsuPlugin_logic_onCtrl_wb_hits);
  assign LsuPlugin_logic_onCtrl_wb_compatibleOp = (((execute_ctrl4_down_LsuPlugin_logic_FROM_LSU_lane0 && execute_ctrl4_down_LsuL1_STORE_lane0) && (! execute_ctrl4_down_LsuL1_ATOMIC_lane0)) && (! execute_ctrl4_down_LsuPlugin_logic_onPma_IO_lane0));
  assign LsuPlugin_logic_onCtrl_wb_notFull = ((! LsuPlugin_logic_storeBuffer_ops_full) && (LsuPlugin_logic_storeBuffer_slotsFree || LsuPlugin_logic_onCtrl_wb_hit));
  assign LsuPlugin_logic_onCtrl_wb_allowed = (LsuPlugin_logic_onCtrl_wb_notFull && LsuPlugin_logic_onCtrl_wb_compatibleOp);
  assign LsuPlugin_logic_onCtrl_wb_slotOh = (LsuPlugin_logic_onCtrl_wb_hits | ((! LsuPlugin_logic_onCtrl_wb_hit) ? LsuPlugin_logic_storeBuffer_slotsFreeFirst : 4'b0000));
  assign LsuPlugin_logic_onCtrl_wb_loadHazard = ((execute_ctrl4_down_LsuL1_LOAD_lane0 || execute_ctrl4_down_LsuL1_EXECUTE_lane0) && LsuPlugin_logic_onCtrl_wb_hit);
  assign LsuPlugin_logic_onCtrl_wb_selfHazard = (execute_ctrl4_down_LsuPlugin_logic_FROM_WB_lane0 && (execute_ctrl4_down_LsuPlugin_SB_PTR_lane0 != LsuPlugin_logic_storeBuffer_ops_freePtr));
  always @(*) begin
    LsuPlugin_logic_flushPort_valid = 1'b0;
    if(when_LsuPlugin_l1036) begin
      if(LsuPlugin_logic_onCtrl_lsuTrap) begin
        LsuPlugin_logic_flushPort_valid = 1'b1;
      end
    end
  end

  assign LsuPlugin_logic_flushPort_payload_uopId = execute_ctrl4_down_Decode_UOP_ID_lane0;
  assign LsuPlugin_logic_flushPort_payload_laneAge = execute_ctrl4_down_LANE_AGE_lane0;
  assign LsuPlugin_logic_flushPort_payload_self = 1'b0;
  always @(*) begin
    LsuPlugin_logic_trapPort_valid = 1'b0;
    if(when_LsuPlugin_l1036) begin
      if(LsuPlugin_logic_onCtrl_lsuTrap) begin
        LsuPlugin_logic_trapPort_valid = 1'b1;
      end
    end
  end

  assign LsuPlugin_logic_trapPort_payload_laneAge = execute_ctrl4_down_LANE_AGE_lane0;
  always @(*) begin
    LsuPlugin_logic_trapPort_payload_tval = execute_ctrl4_down_LsuL1_MIXED_ADDRESS_lane0;
    if(execute_ctrl4_down_LsuPlugin_logic_onTrigger_HIT_lane0) begin
      LsuPlugin_logic_trapPort_payload_tval = 32'h0;
    end
  end

  assign LsuPlugin_logic_trapPort_payload_tval2 = {2'd0, _zz_LsuPlugin_logic_trapPort_payload_tval2};
  always @(*) begin
    LsuPlugin_logic_trapPort_payload_exception = 1'bx;
    if(LsuPlugin_logic_onCtrl_traps_accessFault) begin
      LsuPlugin_logic_trapPort_payload_exception = 1'b1;
    end
    if(when_LsuPlugin_l866) begin
      LsuPlugin_logic_trapPort_payload_exception = 1'b0;
    end
    if(LsuPlugin_logic_onCtrl_traps_pmaFault) begin
      LsuPlugin_logic_trapPort_payload_exception = 1'b1;
    end
    if(execute_ctrl4_down_LsuPlugin_logic_MMU_PAGE_FAULT_lane0) begin
      LsuPlugin_logic_trapPort_payload_exception = 1'b1;
    end
    if(execute_ctrl4_down_LsuPlugin_logic_onAddress0_translationPort_keys_ACCESS_FAULT_lane0) begin
      LsuPlugin_logic_trapPort_payload_exception = 1'b1;
    end
    if(execute_ctrl4_down_LsuPlugin_logic_onAddress0_translationPort_keys_REFILL_lane0) begin
      LsuPlugin_logic_trapPort_payload_exception = 1'b0;
    end
    if(execute_ctrl4_down_LsuPlugin_logic_onAddress0_translationPort_keys_HAZARD_lane0) begin
      LsuPlugin_logic_trapPort_payload_exception = 1'b0;
    end
    if(execute_ctrl4_down_LsuPlugin_logic_onPma_FROM_LSU_MSB_FAILED_lane0) begin
      LsuPlugin_logic_trapPort_payload_exception = 1'b1;
    end
    if(execute_ctrl4_down_LsuPlugin_logic_preCtrl_MISS_ALIGNED_lane0) begin
      LsuPlugin_logic_trapPort_payload_exception = 1'b1;
    end
    if(execute_ctrl4_down_LsuPlugin_logic_onTrigger_HIT_lane0) begin
      LsuPlugin_logic_trapPort_payload_exception = 1'b0;
    end
    if(when_LsuPlugin_l985) begin
      LsuPlugin_logic_trapPort_payload_exception = 1'b0;
    end
  end

  always @(*) begin
    LsuPlugin_logic_trapPort_payload_code = 5'bxxxxx;
    if(LsuPlugin_logic_onCtrl_traps_accessFault) begin
      LsuPlugin_logic_trapPort_payload_code = 5'h05;
      if(execute_ctrl4_down_LsuL1_STORE_lane0) begin
        LsuPlugin_logic_trapPort_payload_code[1] = 1'b1;
      end
    end
    if(when_LsuPlugin_l866) begin
      LsuPlugin_logic_trapPort_payload_code = 5'h04;
    end
    if(LsuPlugin_logic_onCtrl_traps_pmaFault) begin
      LsuPlugin_logic_trapPort_payload_code = 5'h05;
      if(execute_ctrl4_down_LsuL1_STORE_lane0) begin
        LsuPlugin_logic_trapPort_payload_code[1] = 1'b1;
      end
    end
    if(execute_ctrl4_down_LsuPlugin_logic_MMU_PAGE_FAULT_lane0) begin
      LsuPlugin_logic_trapPort_payload_code = 5'h0d;
      if(execute_ctrl4_down_LsuL1_STORE_lane0) begin
        LsuPlugin_logic_trapPort_payload_code[1] = 1'b1;
      end
    end
    if(execute_ctrl4_down_LsuPlugin_logic_onAddress0_translationPort_keys_ACCESS_FAULT_lane0) begin
      LsuPlugin_logic_trapPort_payload_code = 5'h05;
      if(execute_ctrl4_down_LsuL1_STORE_lane0) begin
        LsuPlugin_logic_trapPort_payload_code[1] = 1'b1;
      end
    end
    if(execute_ctrl4_down_LsuPlugin_logic_onAddress0_translationPort_keys_REFILL_lane0) begin
      LsuPlugin_logic_trapPort_payload_code = 5'h07;
    end
    if(execute_ctrl4_down_LsuPlugin_logic_onAddress0_translationPort_keys_HAZARD_lane0) begin
      LsuPlugin_logic_trapPort_payload_code = 5'h04;
    end
    if(execute_ctrl4_down_LsuPlugin_logic_onPma_FROM_LSU_MSB_FAILED_lane0) begin
      LsuPlugin_logic_trapPort_payload_code = 5'h05;
      if(execute_ctrl4_down_AguPlugin_STORE_lane0) begin
        LsuPlugin_logic_trapPort_payload_code[1] = 1'b1;
      end
      if(when_LsuPlugin_l923) begin
        LsuPlugin_logic_trapPort_payload_code[3] = 1'b1;
      end
    end
    if(execute_ctrl4_down_LsuPlugin_logic_preCtrl_MISS_ALIGNED_lane0) begin
      LsuPlugin_logic_trapPort_payload_code = {2'd0, _zz_LsuPlugin_logic_trapPort_payload_code};
    end
    if(execute_ctrl4_down_LsuPlugin_logic_onTrigger_HIT_lane0) begin
      LsuPlugin_logic_trapPort_payload_code = 5'h03;
    end
    if(when_LsuPlugin_l985) begin
      LsuPlugin_logic_trapPort_payload_code = 5'h04;
    end
  end

  always @(*) begin
    LsuPlugin_logic_trapPort_payload_arg = 3'b000;
    LsuPlugin_logic_trapPort_payload_arg[1 : 0] = _zz_LsuPlugin_logic_trapPort_payload_arg;
    LsuPlugin_logic_trapPort_payload_arg[2] = execute_ctrl4_down_LsuL1_GUEST_lane0;
  end

  assign LsuPlugin_logic_onCtrl_traps_accessFault = ((execute_ctrl4_down_LsuPlugin_logic_onPma_CACHED_RSP_lane0_fault ? (LsuPlugin_logic_onCtrl_io_rsp_valid && LsuPlugin_logic_onCtrl_io_rsp_payload_error) : execute_ctrl4_down_LsuL1_FAULT_lane0) || execute_ctrl4_down_LsuPlugin_logic_pmpPort_ACCESS_FAULT_lane0);
  assign LsuPlugin_logic_onCtrl_traps_l1Failed = (execute_ctrl4_down_LsuL1_SEL_lane0 && ((! execute_ctrl4_down_LsuPlugin_logic_onPma_CACHED_RSP_lane0_fault) && (execute_ctrl4_down_LsuL1_HAZARD_lane0 || ((execute_ctrl4_down_LsuL1_MISS_lane0 || execute_ctrl4_down_LsuL1_MISS_UNIQUE_lane0) && ((execute_ctrl4_down_LsuL1_LOAD_lane0 || execute_ctrl4_down_LsuL1_EXECUTE_lane0) || execute_ctrl4_down_LsuL1_STORE_lane0)))));
  assign when_LsuPlugin_l866 = ((LsuPlugin_logic_onCtrl_traps_l1Failed || LsuPlugin_logic_onCtrl_wb_hit) && (! LsuPlugin_logic_onCtrl_wb_allowed));
