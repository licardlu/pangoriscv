  assign TrapPlugin_logic_harts_0_trap_fsm_buffer_trap_interrupt = ((TrapPlugin_logic_harts_0_trap_pending_state_code == 5'h0) && TrapPlugin_logic_harts_0_trap_fsm_buffer_i_valid);
  assign TrapPlugin_logic_harts_0_trap_fsm_buffer_trap_targetPrivilege = (TrapPlugin_logic_harts_0_trap_fsm_buffer_trap_interrupt ? TrapPlugin_logic_harts_0_trap_fsm_buffer_i_targetPrivilege : TrapPlugin_logic_harts_0_trap_exception_targetPrivilege);
  assign TrapPlugin_logic_harts_0_trap_fsm_buffer_trap_tval = ((! TrapPlugin_logic_harts_0_trap_fsm_buffer_trap_interrupt) ? TrapPlugin_logic_harts_0_trap_pending_state_tval : 32'h0);
  assign TrapPlugin_logic_harts_0_trap_fsm_buffer_trap_code = (TrapPlugin_logic_harts_0_trap_fsm_buffer_trap_interrupt ? TrapPlugin_logic_harts_0_trap_fsm_buffer_i_code : TrapPlugin_logic_harts_0_trap_pending_state_code);
  assign TrapPlugin_logic_harts_0_trap_fsm_resetToRunConditions_0 = (! TrapPlugin_logic_initHold);
  assign TrapPlugin_logic_harts_0_trap_fsm_jumpOffset = ((|{(TrapPlugin_logic_harts_0_trap_pending_state_code == 5'h08),(TrapPlugin_logic_harts_0_trap_pending_state_code == 5'h09),(TrapPlugin_logic_harts_0_trap_pending_state_code == 5'h06),(TrapPlugin_logic_harts_0_trap_pending_state_code == 5'h02),(TrapPlugin_logic_harts_0_trap_pending_state_code == 5'h05)}) ? TrapPlugin_logic_harts_0_trap_pending_slices : 2'b00);
  assign TrapPlugin_logic_harts_0_trap_fsm_writeGVA = (|{(TrapPlugin_logic_harts_0_trap_pending_state_code == 5'h17),(TrapPlugin_logic_harts_0_trap_pending_state_code == 5'h15),(TrapPlugin_logic_harts_0_trap_pending_state_code == 5'h14),(TrapPlugin_logic_harts_0_trap_pending_state_code == 5'h0f),(TrapPlugin_logic_harts_0_trap_pending_state_code == 5'h0d),(TrapPlugin_logic_harts_0_trap_pending_state_code == 5'h0c),(TrapPlugin_logic_harts_0_trap_pending_state_code == _zz_TrapPlugin_logic_harts_0_trap_fsm_writeGVA),_zz_TrapPlugin_logic_harts_0_trap_fsm_writeGVA_1,_zz_TrapPlugin_logic_harts_0_trap_fsm_writeGVA_2,(TrapPlugin_logic_harts_0_trap_pending_state_code == 5'h06),(TrapPlugin_logic_harts_0_trap_pending_state_code == 5'h04),(TrapPlugin_logic_harts_0_trap_pending_state_code == 5'h0),(TrapPlugin_logic_harts_0_trap_pending_state_code == 5'h03)});
  always @(*) begin
    TrapPlugin_logic_fetchL1Invalidate_0_cmd_valid = 1'b0;
    case(TrapPlugin_logic_harts_0_trap_fsm_stateReg)
      TrapPlugin_logic_harts_0_trap_fsm_RUNNING : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_COMPUTE : begin
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
        TrapPlugin_logic_fetchL1Invalidate_0_cmd_valid = 1'b1;
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    TrapPlugin_logic_lsuL1Invalidate_0_cmd_valid = 1'b0;
    case(TrapPlugin_logic_harts_0_trap_fsm_stateReg)
      TrapPlugin_logic_harts_0_trap_fsm_RUNNING : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_COMPUTE : begin
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
        TrapPlugin_logic_lsuL1Invalidate_0_cmd_valid = 1'b1;
      end
      TrapPlugin_logic_harts_0_trap_fsm_FETCH_FLUSH : begin
      end
      default : begin
      end
    endcase
  end

  assign TrapPlugin_logic_harts_0_trap_fsm_triggerEbreak = 1'b0;
  assign TrapPlugin_logic_harts_0_trap_fsm_isGuestTarget = TrapPlugin_logic_harts_0_trap_fsm_buffer_trap_targetPrivilege[2];
  assign when_TrapPlugin_l940 = (TrapPlugin_logic_harts_0_crsPorts_read_valid && TrapPlugin_logic_harts_0_crsPorts_read_ready);
  assign TrapPlugin_logic_harts_0_trap_fsm_xretPrivilege = TrapPlugin_logic_harts_0_trap_pending_state_arg[2 : 0];
  always @(*) begin
    LsuL1Plugin_logic_banksWrite_address = 9'bxxxxxxxxx;
    LsuL1Plugin_logic_banksWrite_address = {LsuL1Plugin_logic_refill_read_rspAddress[11 : 6],LsuL1Plugin_logic_refill_read_wordIndex};
    if(LsuL1Plugin_logic_lsu_ctrl_bankWriteReservation_win) begin
      LsuL1Plugin_logic_banksWrite_address = execute_ctrl4_down_LsuL1_PHYSICAL_ADDRESS_lane0[11 : 3];
    end
    if(LsuL1Plugin_logic_initializerMem_busy) begin
      LsuL1Plugin_logic_banksWrite_address = LsuL1Plugin_logic_initializerMem_counter[8:0];
    end
  end

  always @(*) begin
    LsuL1Plugin_logic_banksWrite_writeData = 64'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    LsuL1Plugin_logic_banksWrite_writeData = LsuL1Plugin_logic_bus_read_rsp_payload_data;
    if(LsuL1Plugin_logic_lsu_ctrl_bankWriteReservation_win) begin
      LsuL1Plugin_logic_banksWrite_writeData[31 : 0] = execute_ctrl4_down_LsuL1_WRITE_DATA_lane0;
      LsuL1Plugin_logic_banksWrite_writeData[63 : 32] = execute_ctrl4_down_LsuL1_WRITE_DATA_lane0;
    end
    if(LsuL1Plugin_logic_initializerMem_busy) begin
      LsuL1Plugin_logic_banksWrite_writeData = 64'h0;
    end
  end

  always @(*) begin
    LsuL1Plugin_logic_banksWrite_writeMask = 8'bxxxxxxxx;
    LsuL1Plugin_logic_banksWrite_writeMask = 8'hff;
    if(LsuL1Plugin_logic_lsu_ctrl_bankWriteReservation_win) begin
      LsuL1Plugin_logic_banksWrite_writeMask = 8'h0;
      if(_zz_48[0]) begin
        LsuL1Plugin_logic_banksWrite_writeMask[3 : 0] = execute_ctrl4_down_LsuL1_MASK_lane0;
      end
      if(_zz_48[1]) begin
        LsuL1Plugin_logic_banksWrite_writeMask[7 : 4] = execute_ctrl4_down_LsuL1_MASK_lane0;
      end
    end
    if(LsuL1Plugin_logic_lsu_ctrl_preventSideEffects) begin
      if(LsuL1Plugin_logic_lsu_ctrl_bankWriteReservation_win) begin
        LsuL1Plugin_logic_banksWrite_writeMask = 8'h0;
      end
    end
    if(LsuL1Plugin_logic_initializerMem_busy) begin
      LsuL1Plugin_logic_banksWrite_writeMask = 8'hff;
    end
  end

  always @(*) begin
    LsuL1Plugin_logic_waysWrite_mask = 2'b00;
    if(LsuL1Plugin_logic_bus_read_rsp_valid) begin
      if(when_LsuL1Plugin_l468) begin
        LsuL1Plugin_logic_waysWrite_mask[LsuL1Plugin_logic_refill_read_way] = 1'b1;
      end
    end
    if(LsuL1Plugin_logic_lsu_ctrl_doFlush) begin
      LsuL1Plugin_logic_waysWrite_mask = LsuL1Plugin_logic_lsu_ctrl_needFlushOh;
    end
    if(LsuL1Plugin_logic_lsu_ctrl_preventSideEffects) begin
      if(LsuL1Plugin_logic_lsu_ctrl_wayWriteReservation_win) begin
        LsuL1Plugin_logic_waysWrite_mask = 2'b00;
      end
    end
    if(when_LsuL1Plugin_l1236) begin
      LsuL1Plugin_logic_waysWrite_mask = 2'b11;
    end
  end

  always @(*) begin
    LsuL1Plugin_logic_waysWrite_address = 6'bxxxxxx;
    if(LsuL1Plugin_logic_bus_read_rsp_valid) begin
      if(when_LsuL1Plugin_l468) begin
        LsuL1Plugin_logic_waysWrite_address = LsuL1Plugin_logic_refill_read_rspAddress[11 : 6];
      end
    end
    if(LsuL1Plugin_logic_lsu_ctrl_doFlush) begin
      LsuL1Plugin_logic_waysWrite_address = execute_ctrl4_down_LsuL1_MIXED_ADDRESS_lane0[11 : 6];
    end
    if(when_LsuL1Plugin_l1236) begin
      LsuL1Plugin_logic_waysWrite_address = LsuL1Plugin_logic_initializer_counter[5:0];
    end
  end

  always @(*) begin
    LsuL1Plugin_logic_waysWrite_tag_loaded = 1'bx;
    if(LsuL1Plugin_logic_bus_read_rsp_valid) begin
      if(when_LsuL1Plugin_l468) begin
        LsuL1Plugin_logic_waysWrite_tag_loaded = 1'b1;
      end
    end
    if(LsuL1Plugin_logic_lsu_ctrl_doFlush) begin
      LsuL1Plugin_logic_waysWrite_tag_loaded = 1'b1;
    end
    if(when_LsuL1Plugin_l1236) begin
      LsuL1Plugin_logic_waysWrite_tag_loaded = 1'b0;
    end
  end

  always @(*) begin
    LsuL1Plugin_logic_waysWrite_tag_address = 20'bxxxxxxxxxxxxxxxxxxxx;
    if(LsuL1Plugin_logic_bus_read_rsp_valid) begin
      if(when_LsuL1Plugin_l468) begin
        LsuL1Plugin_logic_waysWrite_tag_address = LsuL1Plugin_logic_refill_read_rspAddress[31 : 12];
      end
    end
    if(LsuL1Plugin_logic_lsu_ctrl_doFlush) begin
      LsuL1Plugin_logic_waysWrite_tag_address = _zz_LsuL1Plugin_logic_waysWrite_tag_address;
    end
  end

  always @(*) begin
    LsuL1Plugin_logic_waysWrite_tag_fault = 1'bx;
    if(LsuL1Plugin_logic_bus_read_rsp_valid) begin
      if(when_LsuL1Plugin_l468) begin
        LsuL1Plugin_logic_waysWrite_tag_fault = LsuL1Plugin_logic_refill_read_faulty;
      end
    end
    if(LsuL1Plugin_logic_lsu_ctrl_doFlush) begin
      LsuL1Plugin_logic_waysWrite_tag_fault = _zz_LsuL1Plugin_logic_waysWrite_tag_fault;
    end
  end

  assign LsuL1Plugin_logic_waysWrite_valid = (|LsuL1Plugin_logic_waysWrite_mask);
  assign LsuL1Plugin_logic_banks_0_write_valid = LsuL1Plugin_logic_banksWrite_mask[0];
  assign LsuL1Plugin_logic_banks_0_write_payload_address = LsuL1Plugin_logic_banksWrite_address;
  assign LsuL1Plugin_logic_banks_0_write_payload_data = LsuL1Plugin_logic_banksWrite_writeData;
  assign LsuL1Plugin_logic_banks_0_write_payload_mask = LsuL1Plugin_logic_banksWrite_writeMask;
  assign LsuL1Plugin_logic_banks_0_read_rsp = LsuL1Plugin_logic_banks_0_mem_spinal_port1;
  assign LsuL1Plugin_logic_banks_1_write_valid = LsuL1Plugin_logic_banksWrite_mask[1];
  assign LsuL1Plugin_logic_banks_1_write_payload_address = LsuL1Plugin_logic_banksWrite_address;
  assign LsuL1Plugin_logic_banks_1_write_payload_data = LsuL1Plugin_logic_banksWrite_writeData;
  assign LsuL1Plugin_logic_banks_1_write_payload_mask = LsuL1Plugin_logic_banksWrite_writeMask;
  assign LsuL1Plugin_logic_banks_1_read_rsp = LsuL1Plugin_logic_banks_1_mem_spinal_port1;
  assign _zz_LsuL1Plugin_logic_ways_0_lsuRead_rsp_loaded = LsuL1Plugin_logic_ways_0_mem_spinal_port1;
  assign LsuL1Plugin_logic_ways_0_lsuRead_rsp_loaded = _zz_LsuL1Plugin_logic_ways_0_lsuRead_rsp_loaded[0];
  assign LsuL1Plugin_logic_ways_0_lsuRead_rsp_address = _zz_LsuL1Plugin_logic_ways_0_lsuRead_rsp_loaded[20 : 1];
  assign LsuL1Plugin_logic_ways_0_lsuRead_rsp_fault = _zz_LsuL1Plugin_logic_ways_0_lsuRead_rsp_loaded[21];
  assign _zz_LsuL1Plugin_logic_ways_1_lsuRead_rsp_loaded = LsuL1Plugin_logic_ways_1_mem_spinal_port1;
  assign LsuL1Plugin_logic_ways_1_lsuRead_rsp_loaded = _zz_LsuL1Plugin_logic_ways_1_lsuRead_rsp_loaded[0];
  assign LsuL1Plugin_logic_ways_1_lsuRead_rsp_address = _zz_LsuL1Plugin_logic_ways_1_lsuRead_rsp_loaded[20 : 1];
  assign LsuL1Plugin_logic_ways_1_lsuRead_rsp_fault = _zz_LsuL1Plugin_logic_ways_1_lsuRead_rsp_loaded[21];
  assign _zz_LsuL1Plugin_logic_shared_lsuRead_rsp_plru_0 = LsuL1Plugin_logic_shared_mem_spinal_port1;
  assign LsuL1Plugin_logic_shared_lsuRead_rsp_plru_0 = _zz_LsuL1Plugin_logic_shared_lsuRead_rsp_plru_0_1[0 : 0];
  assign LsuL1Plugin_logic_shared_lsuRead_rsp_dirty = _zz_LsuL1Plugin_logic_shared_lsuRead_rsp_plru_0[2 : 1];
  assign LsuL1Plugin_logic_slotsFreezeHazard = 1'b0;
  assign LsuL1Plugin_logic_slotsFreeze = (execute_freeze_valid && (! LsuL1Plugin_logic_slotsFreezeHazard));
  always @(*) begin
    LsuL1Plugin_logic_refill_slots_0_loadedSet = 1'b0;
    if(LsuL1Plugin_logic_bus_read_rsp_valid) begin
      if(when_LsuL1Plugin_l468) begin
        case(LsuL1Plugin_logic_bus_read_rsp_payload_id)
          3'b000 : begin
            LsuL1Plugin_logic_refill_slots_0_loadedSet = 1'b1;
          end
          3'b001 : begin
          end
          3'b010 : begin
          end
          3'b011 : begin
          end
          3'b100 : begin
          end
          3'b101 : begin
          end
          3'b110 : begin
          end
          default : begin
          end
        endcase
      end
    end
  end

  assign LsuL1Plugin_logic_refill_slots_0_loadedDone = (LsuL1Plugin_logic_refill_slots_0_loadedCounter == 1'b1);
  assign LsuL1Plugin_logic_refill_slots_0_free = ((! LsuL1Plugin_logic_refill_slots_0_valid) && 1'b1);
  assign LsuL1Plugin_logic_refill_slots_0_fire = ((LsuL1Plugin_logic_refill_slots_0_valid && (! LsuL1Plugin_logic_slotsFreeze)) && LsuL1Plugin_logic_refill_slots_0_loadedDone);
  always @(*) begin
    LsuL1Plugin_logic_refill_slots_1_loadedSet = 1'b0;
    if(LsuL1Plugin_logic_bus_read_rsp_valid) begin
      if(when_LsuL1Plugin_l468) begin
        case(LsuL1Plugin_logic_bus_read_rsp_payload_id)
          3'b000 : begin
          end
          3'b001 : begin
            LsuL1Plugin_logic_refill_slots_1_loadedSet = 1'b1;
          end
          3'b010 : begin
          end
          3'b011 : begin
          end
          3'b100 : begin
          end
          3'b101 : begin
          end
          3'b110 : begin
          end
          default : begin
          end
        endcase
      end
    end
  end

  assign LsuL1Plugin_logic_refill_slots_1_loadedDone = (LsuL1Plugin_logic_refill_slots_1_loadedCounter == 1'b1);
  assign LsuL1Plugin_logic_refill_slots_1_free = ((! LsuL1Plugin_logic_refill_slots_1_valid) && 1'b1);
  assign LsuL1Plugin_logic_refill_slots_1_fire = ((LsuL1Plugin_logic_refill_slots_1_valid && (! LsuL1Plugin_logic_slotsFreeze)) && LsuL1Plugin_logic_refill_slots_1_loadedDone);
  always @(*) begin
    LsuL1Plugin_logic_refill_slots_2_loadedSet = 1'b0;
    if(LsuL1Plugin_logic_bus_read_rsp_valid) begin
      if(when_LsuL1Plugin_l468) begin
        case(LsuL1Plugin_logic_bus_read_rsp_payload_id)
          3'b000 : begin
          end
          3'b001 : begin
          end
          3'b010 : begin
            LsuL1Plugin_logic_refill_slots_2_loadedSet = 1'b1;
          end
          3'b011 : begin
          end
          3'b100 : begin
          end
          3'b101 : begin
          end
          3'b110 : begin
          end
          default : begin
          end
        endcase
      end
    end
  end

  assign LsuL1Plugin_logic_refill_slots_2_loadedDone = (LsuL1Plugin_logic_refill_slots_2_loadedCounter == 1'b1);
  assign LsuL1Plugin_logic_refill_slots_2_free = ((! LsuL1Plugin_logic_refill_slots_2_valid) && 1'b1);
  assign LsuL1Plugin_logic_refill_slots_2_fire = ((LsuL1Plugin_logic_refill_slots_2_valid && (! LsuL1Plugin_logic_slotsFreeze)) && LsuL1Plugin_logic_refill_slots_2_loadedDone);
  always @(*) begin
    LsuL1Plugin_logic_refill_slots_3_loadedSet = 1'b0;
    if(LsuL1Plugin_logic_bus_read_rsp_valid) begin
      if(when_LsuL1Plugin_l468) begin
        case(LsuL1Plugin_logic_bus_read_rsp_payload_id)
          3'b000 : begin
          end
          3'b001 : begin
          end
          3'b010 : begin
          end
          3'b011 : begin
            LsuL1Plugin_logic_refill_slots_3_loadedSet = 1'b1;
          end
          3'b100 : begin
          end
          3'b101 : begin
          end
          3'b110 : begin
          end
          default : begin
          end
        endcase
      end
    end
  end

  assign LsuL1Plugin_logic_refill_slots_3_loadedDone = (LsuL1Plugin_logic_refill_slots_3_loadedCounter == 1'b1);
  assign LsuL1Plugin_logic_refill_slots_3_free = ((! LsuL1Plugin_logic_refill_slots_3_valid) && 1'b1);
  assign LsuL1Plugin_logic_refill_slots_3_fire = ((LsuL1Plugin_logic_refill_slots_3_valid && (! LsuL1Plugin_logic_slotsFreeze)) && LsuL1Plugin_logic_refill_slots_3_loadedDone);
  always @(*) begin
    LsuL1Plugin_logic_refill_slots_4_loadedSet = 1'b0;
    if(LsuL1Plugin_logic_bus_read_rsp_valid) begin
      if(when_LsuL1Plugin_l468) begin
        case(LsuL1Plugin_logic_bus_read_rsp_payload_id)
          3'b000 : begin
          end
          3'b001 : begin
          end
          3'b010 : begin
          end
          3'b011 : begin
          end
          3'b100 : begin
            LsuL1Plugin_logic_refill_slots_4_loadedSet = 1'b1;
          end
          3'b101 : begin
          end
          3'b110 : begin
          end
          default : begin
          end
        endcase
      end
    end
  end

  assign LsuL1Plugin_logic_refill_slots_4_loadedDone = (LsuL1Plugin_logic_refill_slots_4_loadedCounter == 1'b1);
  assign LsuL1Plugin_logic_refill_slots_4_free = ((! LsuL1Plugin_logic_refill_slots_4_valid) && 1'b1);
  assign LsuL1Plugin_logic_refill_slots_4_fire = ((LsuL1Plugin_logic_refill_slots_4_valid && (! LsuL1Plugin_logic_slotsFreeze)) && LsuL1Plugin_logic_refill_slots_4_loadedDone);
  always @(*) begin
    LsuL1Plugin_logic_refill_slots_5_loadedSet = 1'b0;
    if(LsuL1Plugin_logic_bus_read_rsp_valid) begin
      if(when_LsuL1Plugin_l468) begin
        case(LsuL1Plugin_logic_bus_read_rsp_payload_id)
          3'b000 : begin
          end
          3'b001 : begin
          end
          3'b010 : begin
          end
          3'b011 : begin
          end
          3'b100 : begin
          end
          3'b101 : begin
            LsuL1Plugin_logic_refill_slots_5_loadedSet = 1'b1;
          end
          3'b110 : begin
          end
          default : begin
          end
        endcase
      end
    end
  end

  assign LsuL1Plugin_logic_refill_slots_5_loadedDone = (LsuL1Plugin_logic_refill_slots_5_loadedCounter == 1'b1);
  assign LsuL1Plugin_logic_refill_slots_5_free = ((! LsuL1Plugin_logic_refill_slots_5_valid) && 1'b1);
  assign LsuL1Plugin_logic_refill_slots_5_fire = ((LsuL1Plugin_logic_refill_slots_5_valid && (! LsuL1Plugin_logic_slotsFreeze)) && LsuL1Plugin_logic_refill_slots_5_loadedDone);
  always @(*) begin
    LsuL1Plugin_logic_refill_slots_6_loadedSet = 1'b0;
    if(LsuL1Plugin_logic_bus_read_rsp_valid) begin
      if(when_LsuL1Plugin_l468) begin
        case(LsuL1Plugin_logic_bus_read_rsp_payload_id)
          3'b000 : begin
          end
          3'b001 : begin
          end
          3'b010 : begin
          end
          3'b011 : begin
          end
          3'b100 : begin
          end
          3'b101 : begin
          end
          3'b110 : begin
            LsuL1Plugin_logic_refill_slots_6_loadedSet = 1'b1;
          end
          default : begin
          end
        endcase
      end
    end
  end

