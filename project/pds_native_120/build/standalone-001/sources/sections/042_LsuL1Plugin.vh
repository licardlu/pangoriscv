  assign when_LsuL1Plugin_l566_3 = LsuL1Plugin_logic_writeback_free[3];
  assign when_LsuL1Plugin_l561_4 = (LsuL1Plugin_logic_writeback_free[4] && LsuL1Plugin_logic_writeback_push_valid);
  assign when_LsuL1Plugin_l566_4 = LsuL1Plugin_logic_writeback_free[4];
  assign when_LsuL1Plugin_l561_5 = (LsuL1Plugin_logic_writeback_free[5] && LsuL1Plugin_logic_writeback_push_valid);
  assign when_LsuL1Plugin_l566_5 = LsuL1Plugin_logic_writeback_free[5];
  assign when_LsuL1Plugin_l561_6 = (LsuL1Plugin_logic_writeback_free[6] && LsuL1Plugin_logic_writeback_push_valid);
  assign when_LsuL1Plugin_l566_6 = LsuL1Plugin_logic_writeback_free[6];
  assign when_LsuL1Plugin_l561_7 = (LsuL1Plugin_logic_writeback_free[7] && LsuL1Plugin_logic_writeback_push_valid);
  assign when_LsuL1Plugin_l566_7 = LsuL1Plugin_logic_writeback_free[7];
  assign LsuL1Plugin_logic_writeback_read_arbiter_slotsWithId_0_0 = (LsuL1Plugin_logic_writeback_slots_0_valid && (! LsuL1Plugin_logic_writeback_slots_0_readCmdDone));
  assign LsuL1Plugin_logic_writeback_read_arbiter_slotsWithId_1_0 = (LsuL1Plugin_logic_writeback_slots_1_valid && (! LsuL1Plugin_logic_writeback_slots_1_readCmdDone));
  assign LsuL1Plugin_logic_writeback_read_arbiter_slotsWithId_2_0 = (LsuL1Plugin_logic_writeback_slots_2_valid && (! LsuL1Plugin_logic_writeback_slots_2_readCmdDone));
  assign LsuL1Plugin_logic_writeback_read_arbiter_slotsWithId_3_0 = (LsuL1Plugin_logic_writeback_slots_3_valid && (! LsuL1Plugin_logic_writeback_slots_3_readCmdDone));
  assign LsuL1Plugin_logic_writeback_read_arbiter_slotsWithId_4_0 = (LsuL1Plugin_logic_writeback_slots_4_valid && (! LsuL1Plugin_logic_writeback_slots_4_readCmdDone));
  assign LsuL1Plugin_logic_writeback_read_arbiter_slotsWithId_5_0 = (LsuL1Plugin_logic_writeback_slots_5_valid && (! LsuL1Plugin_logic_writeback_slots_5_readCmdDone));
  assign LsuL1Plugin_logic_writeback_read_arbiter_slotsWithId_6_0 = (LsuL1Plugin_logic_writeback_slots_6_valid && (! LsuL1Plugin_logic_writeback_slots_6_readCmdDone));
  assign LsuL1Plugin_logic_writeback_read_arbiter_slotsWithId_7_0 = (LsuL1Plugin_logic_writeback_slots_7_valid && (! LsuL1Plugin_logic_writeback_slots_7_readCmdDone));
  assign LsuL1Plugin_logic_writeback_read_arbiter_hits = {LsuL1Plugin_logic_writeback_read_arbiter_slotsWithId_7_0,LsuL1Plugin_logic_writeback_read_arbiter_slotsWithId_6_0,LsuL1Plugin_logic_writeback_read_arbiter_slotsWithId_5_0,LsuL1Plugin_logic_writeback_read_arbiter_slotsWithId_4_0,LsuL1Plugin_logic_writeback_read_arbiter_slotsWithId_3_0,LsuL1Plugin_logic_writeback_read_arbiter_slotsWithId_2_0,LsuL1Plugin_logic_writeback_read_arbiter_slotsWithId_1_0,LsuL1Plugin_logic_writeback_read_arbiter_slotsWithId_0_0};
  assign LsuL1Plugin_logic_writeback_read_arbiter_hit = (|LsuL1Plugin_logic_writeback_read_arbiter_hits);
  always @(*) begin
    LsuL1Plugin_logic_writeback_read_arbiter_oh = (LsuL1Plugin_logic_writeback_read_arbiter_hits & {(({_zz_LsuL1Plugin_logic_writeback_read_arbiter_oh,_zz_LsuL1Plugin_logic_writeback_read_arbiter_oh_1,_zz_LsuL1Plugin_logic_writeback_read_arbiter_oh_3,_zz_LsuL1Plugin_logic_writeback_read_arbiter_oh_4,_zz_LsuL1Plugin_logic_writeback_read_arbiter_oh_6,_zz_LsuL1Plugin_logic_writeback_read_arbiter_oh_7,_zz_LsuL1Plugin_logic_writeback_read_arbiter_oh_8} & LsuL1Plugin_logic_writeback_slots_7_priority) == 7'h0),(({_zz_LsuL1Plugin_logic_writeback_read_arbiter_oh_9,_zz_LsuL1Plugin_logic_writeback_read_arbiter_oh_11,_zz_LsuL1Plugin_logic_writeback_read_arbiter_oh_12,_zz_LsuL1Plugin_logic_writeback_read_arbiter_oh_14,_zz_LsuL1Plugin_logic_writeback_read_arbiter_oh_15,_zz_LsuL1Plugin_logic_writeback_read_arbiter_oh_17,_zz_LsuL1Plugin_logic_writeback_read_arbiter_oh_18} & LsuL1Plugin_logic_writeback_slots_6_priority) == 7'h0),((_zz_LsuL1Plugin_logic_writeback_read_arbiter_oh_19 & LsuL1Plugin_logic_writeback_slots_5_priority) == 7'h0),(_zz_LsuL1Plugin_logic_writeback_read_arbiter_oh_29 == _zz_LsuL1Plugin_logic_writeback_read_arbiter_oh_38),_zz_LsuL1Plugin_logic_writeback_read_arbiter_oh_39,_zz_LsuL1Plugin_logic_writeback_read_arbiter_oh_49,_zz_LsuL1Plugin_logic_writeback_read_arbiter_oh_61,_zz_LsuL1Plugin_logic_writeback_read_arbiter_oh_69});
    if(when_LsuL1Plugin_l305_1) begin
      LsuL1Plugin_logic_writeback_read_arbiter_oh = LsuL1Plugin_logic_writeback_read_arbiter_lock;
    end
  end

  assign _zz_LsuL1Plugin_logic_writeback_read_arbiter_sel = LsuL1Plugin_logic_writeback_read_arbiter_oh[1];
  assign _zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_1 = LsuL1Plugin_logic_writeback_read_arbiter_oh[2];
  assign _zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_2 = LsuL1Plugin_logic_writeback_read_arbiter_oh[3];
  assign _zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_3 = LsuL1Plugin_logic_writeback_read_arbiter_oh[4];
  assign _zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_4 = LsuL1Plugin_logic_writeback_read_arbiter_oh[5];
  assign _zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_5 = LsuL1Plugin_logic_writeback_read_arbiter_oh[6];
  assign _zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_6 = LsuL1Plugin_logic_writeback_read_arbiter_oh[7];
  assign _zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_7 = (((_zz_LsuL1Plugin_logic_writeback_read_arbiter_sel || _zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_2) || _zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_4) || _zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_6);
  assign _zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_8 = (((_zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_1 || _zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_2) || _zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_5) || _zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_6);
  assign _zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_9 = (((_zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_3 || _zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_4) || _zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_5) || _zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_6);
  assign LsuL1Plugin_logic_writeback_read_arbiter_sel = {_zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_9,_zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_8,_zz_LsuL1Plugin_logic_writeback_read_arbiter_sel_7};
  assign when_LsuL1Plugin_l305_1 = (|LsuL1Plugin_logic_writeback_read_arbiter_lock);
  assign LsuL1Plugin_logic_writeback_read_address = _zz_LsuL1Plugin_logic_writeback_read_address;
  assign LsuL1Plugin_logic_writeback_read_way = _zz_LsuL1Plugin_logic_writeback_read_way;
  assign LsuL1Plugin_logic_writeback_read_slotRead_valid = LsuL1Plugin_logic_writeback_read_arbiter_hit;
  assign LsuL1Plugin_logic_writeback_read_slotRead_payload_id = LsuL1Plugin_logic_writeback_read_arbiter_sel;
  assign LsuL1Plugin_logic_writeback_read_slotRead_payload_wordIndex = LsuL1Plugin_logic_writeback_read_wordIndex;
  assign LsuL1Plugin_logic_writeback_read_slotRead_payload_way = LsuL1Plugin_logic_writeback_read_way;
  assign LsuL1Plugin_logic_writeback_read_slotRead_payload_last = (LsuL1Plugin_logic_writeback_read_wordIndex == 3'b111);
  assign when_LsuL1Plugin_l610 = (LsuL1Plugin_logic_writeback_read_slotRead_valid && LsuL1Plugin_logic_writeback_read_slotRead_payload_last);
  always @(*) begin
    LsuL1Plugin_logic_banks_0_read_cmd_valid = LsuL1Plugin_logic_banks_0_usedByWriteback;
    if(when_LsuL1Plugin_l723) begin
      LsuL1Plugin_logic_banks_0_read_cmd_valid = 1'b1;
    end
  end

  assign LsuL1Plugin_logic_banks_0_usedByWriteback = (LsuL1Plugin_logic_writeback_read_slotRead_valid && (LsuL1Plugin_logic_writeback_read_way == 1'b0));
  always @(*) begin
    LsuL1Plugin_logic_banks_0_read_cmd_payload = {LsuL1Plugin_logic_writeback_read_address[11 : 6],LsuL1Plugin_logic_writeback_read_wordIndex};
    if(when_LsuL1Plugin_l724) begin
      LsuL1Plugin_logic_banks_0_read_cmd_payload = LsuL1Plugin_logic_lsu_rb0_readAddress;
    end
  end

  always @(*) begin
    LsuL1Plugin_logic_banks_1_read_cmd_valid = LsuL1Plugin_logic_banks_1_usedByWriteback;
    if(when_LsuL1Plugin_l723_1) begin
      LsuL1Plugin_logic_banks_1_read_cmd_valid = 1'b1;
    end
  end

  assign LsuL1Plugin_logic_banks_1_usedByWriteback = (LsuL1Plugin_logic_writeback_read_slotRead_valid && (LsuL1Plugin_logic_writeback_read_way == 1'b1));
  always @(*) begin
    LsuL1Plugin_logic_banks_1_read_cmd_payload = {LsuL1Plugin_logic_writeback_read_address[11 : 6],LsuL1Plugin_logic_writeback_read_wordIndex};
    if(when_LsuL1Plugin_l724_1) begin
      LsuL1Plugin_logic_banks_1_read_cmd_payload = LsuL1Plugin_logic_lsu_rb0_readAddress;
    end
  end

  assign LsuL1Plugin_logic_writeback_read_readedData = _zz_LsuL1Plugin_logic_writeback_read_readedData;
  assign LsuL1Plugin_logic_writeback_write_arbiter_slotsWithId_0_0 = ((LsuL1Plugin_logic_writeback_slots_0_valid && LsuL1Plugin_logic_writeback_slots_0_victimBufferReady) && (! LsuL1Plugin_logic_writeback_slots_0_writeCmdDone));
  assign LsuL1Plugin_logic_writeback_write_arbiter_slotsWithId_1_0 = ((LsuL1Plugin_logic_writeback_slots_1_valid && LsuL1Plugin_logic_writeback_slots_1_victimBufferReady) && (! LsuL1Plugin_logic_writeback_slots_1_writeCmdDone));
  assign LsuL1Plugin_logic_writeback_write_arbiter_slotsWithId_2_0 = ((LsuL1Plugin_logic_writeback_slots_2_valid && LsuL1Plugin_logic_writeback_slots_2_victimBufferReady) && (! LsuL1Plugin_logic_writeback_slots_2_writeCmdDone));
  assign LsuL1Plugin_logic_writeback_write_arbiter_slotsWithId_3_0 = ((LsuL1Plugin_logic_writeback_slots_3_valid && LsuL1Plugin_logic_writeback_slots_3_victimBufferReady) && (! LsuL1Plugin_logic_writeback_slots_3_writeCmdDone));
  assign LsuL1Plugin_logic_writeback_write_arbiter_slotsWithId_4_0 = ((LsuL1Plugin_logic_writeback_slots_4_valid && LsuL1Plugin_logic_writeback_slots_4_victimBufferReady) && (! LsuL1Plugin_logic_writeback_slots_4_writeCmdDone));
  assign LsuL1Plugin_logic_writeback_write_arbiter_slotsWithId_5_0 = ((LsuL1Plugin_logic_writeback_slots_5_valid && LsuL1Plugin_logic_writeback_slots_5_victimBufferReady) && (! LsuL1Plugin_logic_writeback_slots_5_writeCmdDone));
  assign LsuL1Plugin_logic_writeback_write_arbiter_slotsWithId_6_0 = ((LsuL1Plugin_logic_writeback_slots_6_valid && LsuL1Plugin_logic_writeback_slots_6_victimBufferReady) && (! LsuL1Plugin_logic_writeback_slots_6_writeCmdDone));
  assign LsuL1Plugin_logic_writeback_write_arbiter_slotsWithId_7_0 = ((LsuL1Plugin_logic_writeback_slots_7_valid && LsuL1Plugin_logic_writeback_slots_7_victimBufferReady) && (! LsuL1Plugin_logic_writeback_slots_7_writeCmdDone));
  assign LsuL1Plugin_logic_writeback_write_arbiter_hits = {LsuL1Plugin_logic_writeback_write_arbiter_slotsWithId_7_0,LsuL1Plugin_logic_writeback_write_arbiter_slotsWithId_6_0,LsuL1Plugin_logic_writeback_write_arbiter_slotsWithId_5_0,LsuL1Plugin_logic_writeback_write_arbiter_slotsWithId_4_0,LsuL1Plugin_logic_writeback_write_arbiter_slotsWithId_3_0,LsuL1Plugin_logic_writeback_write_arbiter_slotsWithId_2_0,LsuL1Plugin_logic_writeback_write_arbiter_slotsWithId_1_0,LsuL1Plugin_logic_writeback_write_arbiter_slotsWithId_0_0};
  assign LsuL1Plugin_logic_writeback_write_arbiter_hit = (|LsuL1Plugin_logic_writeback_write_arbiter_hits);
  always @(*) begin
    LsuL1Plugin_logic_writeback_write_arbiter_oh = (LsuL1Plugin_logic_writeback_write_arbiter_hits & {(({_zz_LsuL1Plugin_logic_writeback_write_arbiter_oh,_zz_LsuL1Plugin_logic_writeback_write_arbiter_oh_1,_zz_LsuL1Plugin_logic_writeback_write_arbiter_oh_3,_zz_LsuL1Plugin_logic_writeback_write_arbiter_oh_4,_zz_LsuL1Plugin_logic_writeback_write_arbiter_oh_6,_zz_LsuL1Plugin_logic_writeback_write_arbiter_oh_7,_zz_LsuL1Plugin_logic_writeback_write_arbiter_oh_8} & LsuL1Plugin_logic_writeback_slots_7_priority) == 7'h0),(({_zz_LsuL1Plugin_logic_writeback_write_arbiter_oh_9,_zz_LsuL1Plugin_logic_writeback_write_arbiter_oh_11,_zz_LsuL1Plugin_logic_writeback_write_arbiter_oh_12,_zz_LsuL1Plugin_logic_writeback_write_arbiter_oh_14,_zz_LsuL1Plugin_logic_writeback_write_arbiter_oh_15,_zz_LsuL1Plugin_logic_writeback_write_arbiter_oh_17,_zz_LsuL1Plugin_logic_writeback_write_arbiter_oh_18} & LsuL1Plugin_logic_writeback_slots_6_priority) == 7'h0),((_zz_LsuL1Plugin_logic_writeback_write_arbiter_oh_19 & LsuL1Plugin_logic_writeback_slots_5_priority) == 7'h0),(_zz_LsuL1Plugin_logic_writeback_write_arbiter_oh_29 == _zz_LsuL1Plugin_logic_writeback_write_arbiter_oh_38),_zz_LsuL1Plugin_logic_writeback_write_arbiter_oh_39,_zz_LsuL1Plugin_logic_writeback_write_arbiter_oh_49,_zz_LsuL1Plugin_logic_writeback_write_arbiter_oh_61,_zz_LsuL1Plugin_logic_writeback_write_arbiter_oh_69});
    if(when_LsuL1Plugin_l305_2) begin
      LsuL1Plugin_logic_writeback_write_arbiter_oh = LsuL1Plugin_logic_writeback_write_arbiter_lock;
    end
  end

  assign _zz_LsuL1Plugin_logic_writeback_write_arbiter_sel = LsuL1Plugin_logic_writeback_write_arbiter_oh[1];
  assign _zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_1 = LsuL1Plugin_logic_writeback_write_arbiter_oh[2];
  assign _zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_2 = LsuL1Plugin_logic_writeback_write_arbiter_oh[3];
  assign _zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_3 = LsuL1Plugin_logic_writeback_write_arbiter_oh[4];
  assign _zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_4 = LsuL1Plugin_logic_writeback_write_arbiter_oh[5];
  assign _zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_5 = LsuL1Plugin_logic_writeback_write_arbiter_oh[6];
  assign _zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_6 = LsuL1Plugin_logic_writeback_write_arbiter_oh[7];
  assign _zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_7 = (((_zz_LsuL1Plugin_logic_writeback_write_arbiter_sel || _zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_2) || _zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_4) || _zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_6);
  assign _zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_8 = (((_zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_1 || _zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_2) || _zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_5) || _zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_6);
  assign _zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_9 = (((_zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_3 || _zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_4) || _zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_5) || _zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_6);
  assign LsuL1Plugin_logic_writeback_write_arbiter_sel = {_zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_9,_zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_8,_zz_LsuL1Plugin_logic_writeback_write_arbiter_sel_7};
  assign when_LsuL1Plugin_l305_2 = (|LsuL1Plugin_logic_writeback_write_arbiter_lock);
  assign LsuL1Plugin_logic_writeback_write_last = (LsuL1Plugin_logic_writeback_write_wordIndex == 3'b111);
  assign LsuL1Plugin_logic_writeback_write_bufferRead_valid = LsuL1Plugin_logic_writeback_write_arbiter_hit;
  assign LsuL1Plugin_logic_writeback_write_bufferRead_payload_id = LsuL1Plugin_logic_writeback_write_arbiter_sel;
  assign LsuL1Plugin_logic_writeback_write_bufferRead_payload_last = LsuL1Plugin_logic_writeback_write_last;
  assign LsuL1Plugin_logic_writeback_write_bufferRead_payload_address = _zz_LsuL1Plugin_logic_writeback_write_bufferRead_payload_address;
  assign LsuL1Plugin_logic_writeback_write_bufferRead_fire = (LsuL1Plugin_logic_writeback_write_bufferRead_valid && LsuL1Plugin_logic_writeback_write_bufferRead_ready);
  assign when_LsuL1Plugin_l681 = (LsuL1Plugin_logic_writeback_write_bufferRead_fire && LsuL1Plugin_logic_writeback_write_last);
  always @(*) begin
    LsuL1Plugin_logic_writeback_write_bufferRead_ready = LsuL1Plugin_logic_writeback_write_cmd_ready;
    if(when_Stream_l477_2) begin
      LsuL1Plugin_logic_writeback_write_bufferRead_ready = 1'b1;
    end
  end

  assign when_Stream_l477_2 = (! LsuL1Plugin_logic_writeback_write_cmd_valid);
  assign LsuL1Plugin_logic_writeback_write_cmd_valid = LsuL1Plugin_logic_writeback_write_bufferRead_rValid;
  assign LsuL1Plugin_logic_writeback_write_cmd_payload_id = LsuL1Plugin_logic_writeback_write_bufferRead_rData_id;
  assign LsuL1Plugin_logic_writeback_write_cmd_payload_address = LsuL1Plugin_logic_writeback_write_bufferRead_rData_address;
  assign LsuL1Plugin_logic_writeback_write_cmd_payload_last = LsuL1Plugin_logic_writeback_write_bufferRead_rData_last;
  assign _zz_LsuL1Plugin_logic_writeback_write_word = {LsuL1Plugin_logic_writeback_write_bufferRead_payload_id,LsuL1Plugin_logic_writeback_write_wordIndex};
  assign LsuL1Plugin_logic_writeback_write_word = LsuL1Plugin_logic_writeback_victimBuffer_spinal_port1;
  assign LsuL1Plugin_logic_bus_write_cmd_valid = LsuL1Plugin_logic_writeback_write_cmd_valid;
  assign LsuL1Plugin_logic_writeback_write_cmd_ready = LsuL1Plugin_logic_bus_write_cmd_ready;
  assign LsuL1Plugin_logic_bus_write_cmd_payload_fragment_address = LsuL1Plugin_logic_writeback_write_cmd_payload_address;
  assign LsuL1Plugin_logic_bus_write_cmd_payload_fragment_data = LsuL1Plugin_logic_writeback_write_word;
  assign LsuL1Plugin_logic_bus_write_cmd_payload_fragment_id = LsuL1Plugin_logic_writeback_write_cmd_payload_id;
  assign LsuL1Plugin_logic_bus_write_cmd_payload_last = LsuL1Plugin_logic_writeback_write_cmd_payload_last;
  assign LsuL1Plugin_logic_lsu_rb0_readAddress = execute_ctrl2_down_LsuL1_MIXED_ADDRESS_lane0[11 : 3];
  always @(*) begin
    execute_ctrl2_down_LsuL1Plugin_logic_BANK_BUSY_lane0[0] = LsuL1Plugin_logic_banks_0_usedByWriteback;
    execute_ctrl2_down_LsuL1Plugin_logic_BANK_BUSY_lane0[1] = LsuL1Plugin_logic_banks_1_usedByWriteback;
  end

  assign when_LsuL1Plugin_l723 = (! execute_freeze_valid);
  assign when_LsuL1Plugin_l724 = (! LsuL1Plugin_logic_banks_0_usedByWriteback);
  assign when_LsuL1Plugin_l723_1 = (! execute_freeze_valid);
  assign when_LsuL1Plugin_l724_1 = (! LsuL1Plugin_logic_banks_1_usedByWriteback);
  assign when_LsuL1Plugin_l740 = (! execute_freeze_valid);
  assign execute_ctrl3_down_LsuL1Plugin_logic_BANKS_WORDS_lane0_0 = LsuL1Plugin_logic_banks_0_read_rsp;
  always @(*) begin
    execute_ctrl3_down_LsuL1Plugin_logic_BANK_BUSY_REMAPPED_lane0[0] = (execute_ctrl3_down_LsuL1Plugin_logic_BANK_BUSY_lane0[1'b0] || LsuL1Plugin_logic_lsu_rb1_onBanks_0_busyReg);
    execute_ctrl3_down_LsuL1Plugin_logic_BANK_BUSY_REMAPPED_lane0[1] = (execute_ctrl3_down_LsuL1Plugin_logic_BANK_BUSY_lane0[1'b1] || LsuL1Plugin_logic_lsu_rb1_onBanks_1_busyReg);
  end

  assign when_LsuL1Plugin_l740_1 = (! execute_freeze_valid);
  assign execute_ctrl3_down_LsuL1Plugin_logic_BANKS_WORDS_lane0_1 = LsuL1Plugin_logic_banks_1_read_rsp;
  assign execute_ctrl3_down_LsuL1Plugin_logic_BANKS_MUXES_lane0_0 = _zz_execute_ctrl3_down_LsuL1Plugin_logic_BANKS_MUXES_lane0_0;
  assign execute_ctrl3_down_LsuL1Plugin_logic_BANKS_MUXES_lane0_1 = _zz_execute_ctrl3_down_LsuL1Plugin_logic_BANKS_MUXES_lane0_1;
  assign _zz_execute_ctrl4_down_LsuL1Plugin_logic_MUXED_DATA_lane0 = execute_ctrl4_down_LsuL1Plugin_logic_WAYS_HITS_lane0[0];
  assign _zz_execute_ctrl4_down_LsuL1Plugin_logic_MUXED_DATA_lane0_1 = execute_ctrl4_down_LsuL1Plugin_logic_WAYS_HITS_lane0[1];
  assign execute_ctrl4_down_LsuL1Plugin_logic_MUXED_DATA_lane0 = ((_zz_execute_ctrl4_down_LsuL1Plugin_logic_MUXED_DATA_lane0 ? execute_ctrl4_down_LsuL1Plugin_logic_BANKS_MUXES_lane0_0 : 32'h0) | (_zz_execute_ctrl4_down_LsuL1Plugin_logic_MUXED_DATA_lane0_1 ? execute_ctrl4_down_LsuL1Plugin_logic_BANKS_MUXES_lane0_1 : 32'h0));
  always @(*) begin
    execute_ctrl3_down_LsuL1Plugin_logic_WRITE_TO_READ_HAZARDS_lane0[0] = ((execute_ctrl2_down_LsuL1Plugin_logic_EVENT_WRITE_VALID_lane0 && (execute_ctrl2_down_LsuL1Plugin_logic_EVENT_WRITE_ADDRESS_lane0[31 : 2] == execute_ctrl3_down_LsuL1_PHYSICAL_ADDRESS_lane0[31 : 2])) && 1'b1);
    execute_ctrl3_down_LsuL1Plugin_logic_WRITE_TO_READ_HAZARDS_lane0[1] = ((execute_ctrl3_down_LsuL1Plugin_logic_EVENT_WRITE_VALID_lane0 && (execute_ctrl3_down_LsuL1Plugin_logic_EVENT_WRITE_ADDRESS_lane0[31 : 2] == execute_ctrl3_down_LsuL1_PHYSICAL_ADDRESS_lane0[31 : 2])) && 1'b1);
  end

  assign execute_ctrl2_up_LsuL1Plugin_logic_FREEZE_HAZARD_lane0 = 1'b0;
  assign execute_ctrl3_LsuL1Plugin_logic_FREEZE_HAZARD_lane0_bypass = (execute_ctrl3_up_LsuL1Plugin_logic_FREEZE_HAZARD_lane0 || LsuL1Plugin_logic_slotsFreezeHazard);
  assign execute_ctrl4_LsuL1Plugin_logic_FREEZE_HAZARD_lane0_bypass = (execute_ctrl4_up_LsuL1Plugin_logic_FREEZE_HAZARD_lane0 || LsuL1Plugin_logic_slotsFreezeHazard);
  assign LsuL1Plugin_logic_shared_lsuRead_cmd_valid = (! execute_freeze_valid);
  assign LsuL1Plugin_logic_shared_lsuRead_cmd_payload = execute_ctrl2_down_LsuL1_MIXED_ADDRESS_lane0[11 : 6];
  assign execute_ctrl2_down_LsuL1Plugin_logic_lsu_rt0_SHARED_BYPASS_VALID_lane0 = (LsuL1Plugin_logic_shared_write_valid && (LsuL1Plugin_logic_shared_write_payload_address == execute_ctrl2_down_LsuL1_MIXED_ADDRESS_lane0[11 : 6]));
  assign execute_ctrl2_down_LsuL1Plugin_logic_lsu_rt0_SHARED_BYPASS_VALUE_lane0_plru_0 = LsuL1Plugin_logic_shared_write_payload_data_plru_0;
  assign execute_ctrl2_down_LsuL1Plugin_logic_lsu_rt0_SHARED_BYPASS_VALUE_lane0_dirty = LsuL1Plugin_logic_shared_write_payload_data_dirty;
  assign LsuL1Plugin_logic_ways_0_lsuRead_cmd_valid = (! execute_freeze_valid);
  assign LsuL1Plugin_logic_ways_0_lsuRead_cmd_payload = execute_ctrl2_down_LsuL1_MIXED_ADDRESS_lane0[11 : 6];
  assign LsuL1Plugin_logic_ways_1_lsuRead_cmd_valid = (! execute_freeze_valid);
  assign LsuL1Plugin_logic_ways_1_lsuRead_cmd_payload = execute_ctrl2_down_LsuL1_MIXED_ADDRESS_lane0[11 : 6];
  always @(*) begin
    execute_ctrl3_up_LsuL1Plugin_logic_SHARED_lane0_plru_0 = LsuL1Plugin_logic_shared_lsuRead_rsp_plru_0;
    if(execute_ctrl3_down_LsuL1Plugin_logic_lsu_rt0_SHARED_BYPASS_VALID_lane0) begin
      execute_ctrl3_up_LsuL1Plugin_logic_SHARED_lane0_plru_0 = execute_ctrl3_down_LsuL1Plugin_logic_lsu_rt0_SHARED_BYPASS_VALUE_lane0_plru_0;
    end
  end

  always @(*) begin
    execute_ctrl3_up_LsuL1Plugin_logic_SHARED_lane0_dirty = LsuL1Plugin_logic_shared_lsuRead_rsp_dirty;
    if(execute_ctrl3_down_LsuL1Plugin_logic_lsu_rt0_SHARED_BYPASS_VALID_lane0) begin
      execute_ctrl3_up_LsuL1Plugin_logic_SHARED_lane0_dirty = execute_ctrl3_down_LsuL1Plugin_logic_lsu_rt0_SHARED_BYPASS_VALUE_lane0_dirty;
    end
  end

  assign execute_ctrl3_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_0_loaded = LsuL1Plugin_logic_ways_0_lsuRead_rsp_loaded;
  assign execute_ctrl3_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_0_address = LsuL1Plugin_logic_ways_0_lsuRead_rsp_address;
  assign execute_ctrl3_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_0_fault = LsuL1Plugin_logic_ways_0_lsuRead_rsp_fault;
  assign execute_ctrl3_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_1_loaded = LsuL1Plugin_logic_ways_1_lsuRead_rsp_loaded;
  assign execute_ctrl3_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_1_address = LsuL1Plugin_logic_ways_1_lsuRead_rsp_address;
  assign execute_ctrl3_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_1_fault = LsuL1Plugin_logic_ways_1_lsuRead_rsp_fault;
  assign LsuL1Plugin_logic_lsu_sharedBypassers_0_hit = (LsuL1Plugin_logic_shared_write_valid && (LsuL1Plugin_logic_shared_write_payload_address == execute_ctrl3_down_LsuL1_MIXED_ADDRESS_lane0[11 : 6]));
  assign execute_ctrl3_LsuL1Plugin_logic_SHARED_lane0_bypass_plru_0 = (LsuL1Plugin_logic_lsu_sharedBypassers_0_hit ? LsuL1Plugin_logic_shared_write_payload_data_plru_0 : execute_ctrl3_up_LsuL1Plugin_logic_SHARED_lane0_plru_0);
  assign execute_ctrl3_LsuL1Plugin_logic_SHARED_lane0_bypass_dirty = (LsuL1Plugin_logic_lsu_sharedBypassers_0_hit ? LsuL1Plugin_logic_shared_write_payload_data_dirty : execute_ctrl3_up_LsuL1Plugin_logic_SHARED_lane0_dirty);
  always @(*) begin
    execute_ctrl3_down_LsuL1Plugin_logic_WAYS_HITS_lane0[0] = (execute_ctrl3_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_0_loaded && (execute_ctrl3_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_0_address == execute_ctrl3_down_LsuL1_PHYSICAL_ADDRESS_lane0[31 : 12]));
    execute_ctrl3_down_LsuL1Plugin_logic_WAYS_HITS_lane0[1] = (execute_ctrl3_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_1_loaded && (execute_ctrl3_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_1_address == execute_ctrl3_down_LsuL1_PHYSICAL_ADDRESS_lane0[31 : 12]));
  end

  assign execute_ctrl4_down_LsuL1Plugin_logic_WAYS_HIT_lane0 = (|execute_ctrl4_down_LsuL1Plugin_logic_WAYS_HITS_lane0);
  assign execute_ctrl4_down_LsuL1Plugin_logic_NEED_UNIQUE_lane0 = (execute_ctrl4_down_LsuL1_STORE_lane0 || execute_ctrl4_down_LsuL1_ATOMIC_lane0);
  assign LsuL1Plugin_logic_lsu_ctrl_plruLogic_core_evict_logic_0_state = LsuL1Plugin_logic_lsu_ctrl_plruLogic_core_io_context_state_0[0];
  assign LsuL1Plugin_logic_lsu_ctrl_plruLogic_core_evict_sel_0 = (! LsuL1Plugin_logic_lsu_ctrl_plruLogic_core_evict_logic_0_state);
  assign LsuL1Plugin_logic_lsu_ctrl_plruLogic_core_io_evict_id = LsuL1Plugin_logic_lsu_ctrl_plruLogic_core_evict_sel_0;
  assign LsuL1Plugin_logic_lsu_ctrl_plruLogic_core_io_update_state_0[0] = LsuL1Plugin_logic_lsu_ctrl_plruLogic_core_io_update_id[0];
  assign LsuL1Plugin_logic_lsu_ctrl_plruLogic_core_io_context_state_0 = execute_ctrl4_down_LsuL1Plugin_logic_SHARED_lane0_plru_0;
  always @(*) begin
    LsuL1Plugin_logic_lsu_ctrl_wayWriteReservation_take = 1'b0;
    if(LsuL1Plugin_logic_lsu_ctrl_doFlush) begin
      LsuL1Plugin_logic_lsu_ctrl_wayWriteReservation_take = 1'b1;
    end
  end

  assign LsuL1Plugin_logic_lsu_ctrl_bankWriteReservation_take = 1'b0;
  assign LsuL1Plugin_logic_lsu_ctrl_refillWayWithoutUpdate = LsuL1Plugin_logic_lsu_ctrl_plruLogic_core_io_evict_id;
  assign LsuL1Plugin_logic_lsu_ctrl_refillWayNeedWriteback = _zz_LsuL1Plugin_logic_lsu_ctrl_refillWayNeedWriteback[LsuL1Plugin_logic_lsu_ctrl_refillWayWithoutUpdate];
  assign LsuL1Plugin_logic_lsu_ctrl_refillHazards = {(LsuL1Plugin_logic_refill_slots_7_valid && (LsuL1Plugin_logic_refill_slots_7_address[11 : 6] == execute_ctrl4_down_LsuL1_PHYSICAL_ADDRESS_lane0[11 : 6])),(LsuL1Plugin_logic_refill_slots_6_valid && (LsuL1Plugin_logic_refill_slots_6_address[11 : 6] == execute_ctrl4_down_LsuL1_PHYSICAL_ADDRESS_lane0[11 : 6])),(LsuL1Plugin_logic_refill_slots_5_valid && (_zz_LsuL1Plugin_logic_lsu_ctrl_refillHazards == _zz_LsuL1Plugin_logic_lsu_ctrl_refillHazards_1)),(LsuL1Plugin_logic_refill_slots_4_valid && _zz_LsuL1Plugin_logic_lsu_ctrl_refillHazards_2),_zz_LsuL1Plugin_logic_lsu_ctrl_refillHazards_3,_zz_LsuL1Plugin_logic_lsu_ctrl_refillHazards_4,(LsuL1Plugin_logic_refill_slots_1_valid && (LsuL1Plugin_logic_refill_slots_1_address[11 : 6] == execute_ctrl4_down_LsuL1_PHYSICAL_ADDRESS_lane0[11 : 6])),(LsuL1Plugin_logic_refill_slots_0_valid && (LsuL1Plugin_logic_refill_slots_0_address[11 : 6] == execute_ctrl4_down_LsuL1_PHYSICAL_ADDRESS_lane0[11 : 6]))};
  assign LsuL1Plugin_logic_lsu_ctrl_writebackHazards = {(LsuL1Plugin_logic_writeback_slots_7_valid && (LsuL1Plugin_logic_writeback_slots_7_address[11 : 6] == execute_ctrl4_down_LsuL1_PHYSICAL_ADDRESS_lane0[11 : 6])),(LsuL1Plugin_logic_writeback_slots_6_valid && (LsuL1Plugin_logic_writeback_slots_6_address[11 : 6] == execute_ctrl4_down_LsuL1_PHYSICAL_ADDRESS_lane0[11 : 6])),(LsuL1Plugin_logic_writeback_slots_5_valid && (_zz_LsuL1Plugin_logic_lsu_ctrl_writebackHazards == _zz_LsuL1Plugin_logic_lsu_ctrl_writebackHazards_1)),(LsuL1Plugin_logic_writeback_slots_4_valid && _zz_LsuL1Plugin_logic_lsu_ctrl_writebackHazards_2),_zz_LsuL1Plugin_logic_lsu_ctrl_writebackHazards_3,_zz_LsuL1Plugin_logic_lsu_ctrl_writebackHazards_4,(LsuL1Plugin_logic_writeback_slots_1_valid && (LsuL1Plugin_logic_writeback_slots_1_address[11 : 6] == execute_ctrl4_down_LsuL1_PHYSICAL_ADDRESS_lane0[11 : 6])),(LsuL1Plugin_logic_writeback_slots_0_valid && (LsuL1Plugin_logic_writeback_slots_0_address[11 : 6] == execute_ctrl4_down_LsuL1_PHYSICAL_ADDRESS_lane0[11 : 6]))};
  assign LsuL1Plugin_logic_lsu_ctrl_refillHazard = (|LsuL1Plugin_logic_lsu_ctrl_refillHazards);
  assign LsuL1Plugin_logic_lsu_ctrl_writebackHazard = (|LsuL1Plugin_logic_lsu_ctrl_writebackHazards);
  assign LsuL1Plugin_logic_lsu_ctrl_wasDirty = (|(execute_ctrl4_down_LsuL1Plugin_logic_SHARED_lane0_dirty & execute_ctrl4_down_LsuL1Plugin_logic_WAYS_HITS_lane0));
  assign LsuL1Plugin_logic_lsu_ctrl_loadedDirties = ({execute_ctrl4_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_1_loaded,execute_ctrl4_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_0_loaded} & execute_ctrl4_down_LsuL1Plugin_logic_SHARED_lane0_dirty);
  assign LsuL1Plugin_logic_lsu_ctrl_refillWayWasDirty = LsuL1Plugin_logic_lsu_ctrl_loadedDirties[LsuL1Plugin_logic_lsu_ctrl_refillWayWithoutUpdate];
  assign LsuL1Plugin_logic_lsu_ctrl_writeToReadHazard = 1'b0;
  assign LsuL1Plugin_logic_lsu_ctrl_bankNotRead = (|(execute_ctrl4_down_LsuL1Plugin_logic_BANK_BUSY_REMAPPED_lane0 & execute_ctrl4_down_LsuL1Plugin_logic_WAYS_HITS_lane0));
  assign LsuL1Plugin_logic_lsu_ctrl_loadHazard = (((execute_ctrl4_down_LsuL1_LOAD_lane0 || execute_ctrl4_down_LsuL1_EXECUTE_lane0) && (! execute_ctrl4_down_LsuL1_PREFETCH_lane0)) && (LsuL1Plugin_logic_lsu_ctrl_bankNotRead || LsuL1Plugin_logic_lsu_ctrl_writeToReadHazard));
  assign LsuL1Plugin_logic_lsu_ctrl_storeHazard = ((execute_ctrl4_down_LsuL1_STORE_lane0 && (! execute_ctrl4_down_LsuL1_PREFETCH_lane0)) && (! LsuL1Plugin_logic_lsu_ctrl_bankWriteReservation_win));
  assign LsuL1Plugin_logic_lsu_ctrl_preventSideEffects = (execute_ctrl4_down_LsuL1_ABORD_lane0 || execute_freeze_valid);
  assign LsuL1Plugin_logic_lsu_ctrl_flushHazard = (execute_ctrl4_down_LsuL1_FLUSH_lane0 && (! LsuL1Plugin_logic_lsu_ctrl_wayWriteReservation_win));
  assign LsuL1Plugin_logic_lsu_ctrl_coherencyHazard = 1'b0;
  assign execute_ctrl4_down_LsuL1Plugin_logic_HAZARD_FORCED_lane0 = 1'b0;
  assign execute_ctrl4_down_LsuL1_HAZARD_lane0 = ((((((LsuL1Plugin_logic_lsu_ctrl_hazardReg || LsuL1Plugin_logic_lsu_ctrl_loadHazard) || LsuL1Plugin_logic_lsu_ctrl_refillHazard) || LsuL1Plugin_logic_lsu_ctrl_storeHazard) || LsuL1Plugin_logic_lsu_ctrl_coherencyHazard) || execute_ctrl4_down_LsuL1Plugin_logic_HAZARD_FORCED_lane0) || execute_ctrl4_down_LsuL1Plugin_logic_FREEZE_HAZARD_lane0);
  assign execute_ctrl4_down_LsuL1_FLUSH_HAZARD_lane0 = (LsuL1Plugin_logic_lsu_ctrl_flushHazardReg || LsuL1Plugin_logic_lsu_ctrl_flushHazard);
  assign execute_ctrl4_down_LsuL1_MISS_lane0 = (! execute_ctrl4_down_LsuL1Plugin_logic_WAYS_HIT_lane0);
  assign execute_ctrl4_down_LsuL1_FAULT_lane0 = ((execute_ctrl4_down_LsuL1Plugin_logic_WAYS_HIT_lane0 && (|(execute_ctrl4_down_LsuL1Plugin_logic_WAYS_HITS_lane0 & {execute_ctrl4_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_1_fault,execute_ctrl4_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_0_fault}))) && (! execute_ctrl4_down_LsuL1_FLUSH_lane0));
  assign execute_ctrl4_down_LsuL1_MISS_UNIQUE_lane0 = ((execute_ctrl4_down_LsuL1Plugin_logic_WAYS_HIT_lane0 && execute_ctrl4_down_LsuL1Plugin_logic_NEED_UNIQUE_lane0) && 1'b0);
  assign execute_ctrl4_down_LsuL1_REFILL_HIT_lane0 = LsuL1Plugin_logic_lsu_ctrl_refillHazard;
  assign LsuL1Plugin_logic_events_loadAccess = ((((execute_ctrl4_up_LANE_SEL_lane0 && execute_ctrl4_up_isReady) && (! execute_lane0_ctrls_4_upIsCancel)) && execute_ctrl4_down_LsuL1_SEL_lane0) && (execute_ctrl4_down_LsuL1_LOAD_lane0 || execute_ctrl4_down_LsuL1_EXECUTE_lane0));
  assign LsuL1Plugin_logic_events_loadMiss = ((LsuL1Plugin_logic_events_loadAccess && (! execute_ctrl4_down_LsuL1_HAZARD_lane0)) && execute_ctrl4_down_LsuL1_MISS_lane0);
  assign LsuL1Plugin_logic_lsu_ctrl_canRefill = (((! (LsuL1Plugin_logic_lsu_ctrl_refillWayNeedWriteback && LsuL1Plugin_logic_writeback_full)) && (! LsuL1Plugin_logic_refill_full)) && (! LsuL1Plugin_logic_lsu_ctrl_writebackHazard));
  assign LsuL1Plugin_logic_lsu_ctrl_canFlush = (((LsuL1Plugin_logic_lsu_ctrl_wayWriteReservation_win && (! LsuL1Plugin_logic_writeback_full)) && (! (|{LsuL1Plugin_logic_refill_slots_7_valid,LsuL1Plugin_logic_refill_slots_6_valid,LsuL1Plugin_logic_refill_slots_5_valid,LsuL1Plugin_logic_refill_slots_4_valid,LsuL1Plugin_logic_refill_slots_3_valid,LsuL1Plugin_logic_refill_slots_2_valid,LsuL1Plugin_logic_refill_slots_1_valid,LsuL1Plugin_logic_refill_slots_0_valid}))) && (! LsuL1Plugin_logic_lsu_ctrl_writebackHazard));
  assign LsuL1Plugin_logic_lsu_ctrl_needFlushs = LsuL1Plugin_logic_lsu_ctrl_loadedDirties;
  assign _zz_LsuL1Plugin_logic_lsu_ctrl_needFlushs_bools_0 = LsuL1Plugin_logic_lsu_ctrl_needFlushs;
  assign LsuL1Plugin_logic_lsu_ctrl_needFlushs_bools_0 = _zz_LsuL1Plugin_logic_lsu_ctrl_needFlushs_bools_0[0];
  assign LsuL1Plugin_logic_lsu_ctrl_needFlushs_bools_1 = _zz_LsuL1Plugin_logic_lsu_ctrl_needFlushs_bools_0[1];
  always @(*) begin
    _zz_LsuL1Plugin_logic_lsu_ctrl_needFlushOh[0] = (LsuL1Plugin_logic_lsu_ctrl_needFlushs_bools_0 && (! 1'b0));
    _zz_LsuL1Plugin_logic_lsu_ctrl_needFlushOh[1] = (LsuL1Plugin_logic_lsu_ctrl_needFlushs_bools_1 && (! LsuL1Plugin_logic_lsu_ctrl_needFlushs_bools_0));
  end

  assign LsuL1Plugin_logic_lsu_ctrl_needFlushOh = _zz_LsuL1Plugin_logic_lsu_ctrl_needFlushOh;
  assign _zz_LsuL1Plugin_logic_lsu_ctrl_needFlushSel = LsuL1Plugin_logic_lsu_ctrl_needFlushOh[1];
  assign LsuL1Plugin_logic_lsu_ctrl_needFlushSel = _zz_LsuL1Plugin_logic_lsu_ctrl_needFlushSel;
  assign LsuL1Plugin_logic_lsu_ctrl_isAccess = ((! execute_ctrl4_down_LsuL1_FLUSH_lane0) && 1'b1);
  assign LsuL1Plugin_logic_lsu_ctrl_askRefill = ((LsuL1Plugin_logic_lsu_ctrl_isAccess && execute_ctrl4_down_LsuL1_MISS_lane0) && LsuL1Plugin_logic_lsu_ctrl_canRefill);
  assign LsuL1Plugin_logic_lsu_ctrl_askUpgrade = ((LsuL1Plugin_logic_lsu_ctrl_isAccess && execute_ctrl4_down_LsuL1_MISS_UNIQUE_lane0) && LsuL1Plugin_logic_lsu_ctrl_canRefill);
  assign LsuL1Plugin_logic_lsu_ctrl_askFlush = ((execute_ctrl4_down_LsuL1_FLUSH_lane0 && LsuL1Plugin_logic_lsu_ctrl_canFlush) && (|LsuL1Plugin_logic_lsu_ctrl_needFlushs));
  assign LsuL1Plugin_logic_lsu_ctrl_askCbm = 1'b0;
  assign LsuL1Plugin_logic_lsu_ctrl_doRefill = (execute_ctrl4_down_LsuL1_SEL_lane0 && LsuL1Plugin_logic_lsu_ctrl_askRefill);
  assign LsuL1Plugin_logic_lsu_ctrl_doUpgrade = (execute_ctrl4_down_LsuL1_SEL_lane0 && LsuL1Plugin_logic_lsu_ctrl_askUpgrade);
  assign LsuL1Plugin_logic_lsu_ctrl_doFlush = (execute_ctrl4_down_LsuL1_SEL_lane0 && LsuL1Plugin_logic_lsu_ctrl_askFlush);
  assign LsuL1Plugin_logic_lsu_ctrl_doWrite = ((((execute_ctrl4_down_LsuL1_SEL_lane0 && execute_ctrl4_down_LsuL1_STORE_lane0) && execute_ctrl4_down_LsuL1Plugin_logic_WAYS_HIT_lane0) && _zz_LsuL1Plugin_logic_lsu_ctrl_doWrite[0]) && (! execute_ctrl4_down_LsuL1_SKIP_WRITE_lane0));
  assign LsuL1Plugin_logic_lsu_ctrl_doCbm = 1'b0;
  assign LsuL1Plugin_logic_lsu_ctrl_wayId = _zz_execute_ctrl4_down_LsuL1Plugin_logic_MUXED_DATA_lane0_1;
  assign LsuL1Plugin_logic_lsu_ctrl_targetWay = (LsuL1Plugin_logic_lsu_ctrl_askUpgrade ? LsuL1Plugin_logic_lsu_ctrl_wayId : LsuL1Plugin_logic_lsu_ctrl_refillWayWithoutUpdate);
  always @(*) begin
    LsuL1Plugin_logic_lsu_ctrl_plruLogic_core_io_update_id = LsuL1Plugin_logic_lsu_ctrl_wayId;
    if(LsuL1Plugin_logic_lsu_ctrl_doRefill) begin
      LsuL1Plugin_logic_lsu_ctrl_plruLogic_core_io_update_id = LsuL1Plugin_logic_lsu_ctrl_targetWay;
    end
  end

  assign LsuL1Plugin_logic_lsu_ctrl_doRefillPush = (LsuL1Plugin_logic_lsu_ctrl_doRefill || LsuL1Plugin_logic_lsu_ctrl_doUpgrade);
  always @(*) begin
    LsuL1Plugin_logic_refill_push_valid = LsuL1Plugin_logic_lsu_ctrl_doRefillPush;
    if(LsuL1Plugin_logic_lsu_ctrl_preventSideEffects) begin
      LsuL1Plugin_logic_refill_push_valid = 1'b0;
    end
  end

  assign LsuL1Plugin_logic_refill_push_payload_address = execute_ctrl4_down_LsuL1_PHYSICAL_ADDRESS_lane0;
  assign LsuL1Plugin_logic_refill_push_payload_unique = execute_ctrl4_down_LsuL1Plugin_logic_NEED_UNIQUE_lane0;
  assign LsuL1Plugin_logic_refill_push_payload_data = LsuL1Plugin_logic_lsu_ctrl_askRefill;
  always @(*) begin
    LsuL1Plugin_logic_refill_push_payload_way = LsuL1Plugin_logic_lsu_ctrl_targetWay;
    if(LsuL1Plugin_logic_lsu_ctrl_askUpgrade) begin
      LsuL1Plugin_logic_refill_push_payload_way = LsuL1Plugin_logic_lsu_ctrl_wayId;
    end
  end

  always @(*) begin
    LsuL1Plugin_logic_refill_push_payload_victim = ((LsuL1Plugin_logic_lsu_ctrl_refillWayNeedWriteback && LsuL1Plugin_logic_lsu_ctrl_refillWayWasDirty) ? LsuL1Plugin_logic_writeback_free : 8'h0);
    if(LsuL1Plugin_logic_lsu_ctrl_askUpgrade) begin
      LsuL1Plugin_logic_refill_push_payload_victim = 8'h0;
    end
  end

  assign execute_ctrl4_down_LsuL1_WAIT_REFILL_lane0 = (LsuL1Plugin_logic_lsu_ctrl_refillHazards | (((! execute_ctrl4_down_LsuL1_HAZARD_lane0) && (LsuL1Plugin_logic_lsu_ctrl_askRefill || LsuL1Plugin_logic_lsu_ctrl_askUpgrade)) ? (LsuL1Plugin_logic_refill_full ? 8'hff : LsuL1Plugin_logic_refill_free) : 8'h0));
  assign execute_ctrl4_down_LsuL1_WAIT_WRITEBACK_lane0 = 8'h0;
  assign when_LsuL1Plugin_l928 = (execute_ctrl4_down_LsuL1_SEL_lane0 && (! execute_ctrl4_down_LsuL1_ABORD_lane0));
  assign _zz_47 = {LsuL1Plugin_logic_lsu_ctrl_askRefill,LsuL1Plugin_logic_lsu_ctrl_doUpgrade,LsuL1Plugin_logic_lsu_ctrl_doFlush};
  always @(*) begin
    LsuL1Plugin_logic_shared_write_valid = 1'b0;
    if(LsuL1Plugin_logic_lsu_ctrl_doFlush) begin
      LsuL1Plugin_logic_shared_write_valid = 1'b1;
    end
    if(LsuL1Plugin_logic_lsu_ctrl_doRefill) begin
      LsuL1Plugin_logic_shared_write_valid = 1'b1;
    end
    if(when_LsuL1Plugin_l1030) begin
      LsuL1Plugin_logic_shared_write_valid = 1'b1;
    end
    if(LsuL1Plugin_logic_lsu_ctrl_preventSideEffects) begin
      LsuL1Plugin_logic_shared_write_valid = 1'b0;
    end
    if(when_LsuL1Plugin_l1236) begin
      LsuL1Plugin_logic_shared_write_valid = 1'b1;
    end
  end

  always @(*) begin
    LsuL1Plugin_logic_shared_write_payload_address = execute_ctrl4_down_LsuL1_MIXED_ADDRESS_lane0[11 : 6];
    if(when_LsuL1Plugin_l1236) begin
      LsuL1Plugin_logic_shared_write_payload_address = LsuL1Plugin_logic_initializer_counter[5:0];
    end
  end

  always @(*) begin
    LsuL1Plugin_logic_shared_write_payload_data_plru_0 = LsuL1Plugin_logic_lsu_ctrl_plruLogic_core_io_update_state_0;
    if(when_LsuL1Plugin_l1236) begin
      LsuL1Plugin_logic_shared_write_payload_data_plru_0 = _zz_LsuL1Plugin_logic_shared_write_payload_data_plru_0_1[0 : 0];
    end
  end

  always @(*) begin
    LsuL1Plugin_logic_shared_write_payload_data_dirty = ((execute_ctrl4_down_LsuL1Plugin_logic_SHARED_lane0_dirty | (LsuL1Plugin_logic_lsu_ctrl_doWrite ? execute_ctrl4_down_LsuL1Plugin_logic_WAYS_HITS_lane0 : 2'b00)) & (~ ((LsuL1Plugin_logic_lsu_ctrl_doRefill ? _zz_LsuL1Plugin_logic_shared_write_payload_data_dirty : 2'b00) | (LsuL1Plugin_logic_lsu_ctrl_doFlush ? LsuL1Plugin_logic_lsu_ctrl_needFlushOh : 2'b00))));
    if(when_LsuL1Plugin_l1236) begin
      LsuL1Plugin_logic_shared_write_payload_data_dirty = _zz_LsuL1Plugin_logic_shared_write_payload_data_plru_0[2 : 1];
    end
  end

  assign _zz_48 = ({1'd0,1'b1} <<< execute_ctrl4_down_LsuL1_PHYSICAL_ADDRESS_lane0[2 : 2]);
  assign when_LsuL1Plugin_l942 = execute_ctrl4_down_LsuL1Plugin_logic_WAYS_HITS_lane0[0];
  assign when_LsuL1Plugin_l942_1 = execute_ctrl4_down_LsuL1Plugin_logic_WAYS_HITS_lane0[1];
  assign execute_ctrl4_down_LsuL1_FLUSH_HIT_lane0 = (|LsuL1Plugin_logic_lsu_ctrl_needFlushs);
  assign _zz_LsuL1Plugin_logic_waysWrite_tag_address = _zz__zz_LsuL1Plugin_logic_waysWrite_tag_address;
  assign execute_ctrl2_down_LsuL1Plugin_logic_EVENT_WRITE_VALID_lane0 = LsuL1Plugin_logic_lsu_ctrl_doWrite;
  assign execute_ctrl2_down_LsuL1Plugin_logic_EVENT_WRITE_ADDRESS_lane0 = execute_ctrl4_down_LsuL1_PHYSICAL_ADDRESS_lane0;
  assign execute_ctrl2_down_LsuL1Plugin_logic_EVENT_WRITE_DATA_lane0 = execute_ctrl4_down_LsuL1_WRITE_DATA_lane0;
  assign execute_ctrl2_down_LsuL1Plugin_logic_EVENT_WRITE_MASK_lane0 = execute_ctrl4_down_LsuL1_MASK_lane0;
  assign when_LsuL1Plugin_l1030 = ((execute_ctrl4_down_LsuL1_SEL_lane0 && (! execute_ctrl4_down_LsuL1_HAZARD_lane0)) && (! execute_ctrl4_down_LsuL1_MISS_lane0));
  always @(*) begin
    execute_ctrl4_down_LsuL1Plugin_logic_BYPASSED_DATA_lane0 = execute_ctrl4_down_LsuL1Plugin_logic_MUXED_DATA_lane0;
    if(when_LsuL1Plugin_l1037) begin
      if(when_LsuL1Plugin_l1041) begin
        execute_ctrl4_down_LsuL1Plugin_logic_BYPASSED_DATA_lane0[7 : 0] = execute_ctrl4_down_LsuL1Plugin_logic_EVENT_WRITE_DATA_lane0[7 : 0];
      end
      if(when_LsuL1Plugin_l1041_1) begin
        execute_ctrl4_down_LsuL1Plugin_logic_BYPASSED_DATA_lane0[15 : 8] = execute_ctrl4_down_LsuL1Plugin_logic_EVENT_WRITE_DATA_lane0[15 : 8];
      end
      if(when_LsuL1Plugin_l1041_2) begin
        execute_ctrl4_down_LsuL1Plugin_logic_BYPASSED_DATA_lane0[23 : 16] = execute_ctrl4_down_LsuL1Plugin_logic_EVENT_WRITE_DATA_lane0[23 : 16];
      end
      if(when_LsuL1Plugin_l1041_3) begin
        execute_ctrl4_down_LsuL1Plugin_logic_BYPASSED_DATA_lane0[31 : 24] = execute_ctrl4_down_LsuL1Plugin_logic_EVENT_WRITE_DATA_lane0[31 : 24];
      end
    end
    if(when_LsuL1Plugin_l1037_1) begin
      if(when_LsuL1Plugin_l1041_4) begin
        execute_ctrl4_down_LsuL1Plugin_logic_BYPASSED_DATA_lane0[7 : 0] = execute_ctrl3_down_LsuL1Plugin_logic_EVENT_WRITE_DATA_lane0[7 : 0];
      end
      if(when_LsuL1Plugin_l1041_5) begin
        execute_ctrl4_down_LsuL1Plugin_logic_BYPASSED_DATA_lane0[15 : 8] = execute_ctrl3_down_LsuL1Plugin_logic_EVENT_WRITE_DATA_lane0[15 : 8];
      end
      if(when_LsuL1Plugin_l1041_6) begin
        execute_ctrl4_down_LsuL1Plugin_logic_BYPASSED_DATA_lane0[23 : 16] = execute_ctrl3_down_LsuL1Plugin_logic_EVENT_WRITE_DATA_lane0[23 : 16];
      end
      if(when_LsuL1Plugin_l1041_7) begin
        execute_ctrl4_down_LsuL1Plugin_logic_BYPASSED_DATA_lane0[31 : 24] = execute_ctrl3_down_LsuL1Plugin_logic_EVENT_WRITE_DATA_lane0[31 : 24];
      end
    end
  end

  assign when_LsuL1Plugin_l1037 = execute_ctrl4_down_LsuL1Plugin_logic_WRITE_TO_READ_HAZARDS_lane0[1];
  assign when_LsuL1Plugin_l1041 = execute_ctrl4_down_LsuL1Plugin_logic_EVENT_WRITE_MASK_lane0[0];
  assign when_LsuL1Plugin_l1041_1 = execute_ctrl4_down_LsuL1Plugin_logic_EVENT_WRITE_MASK_lane0[1];
  assign when_LsuL1Plugin_l1041_2 = execute_ctrl4_down_LsuL1Plugin_logic_EVENT_WRITE_MASK_lane0[2];
  assign when_LsuL1Plugin_l1041_3 = execute_ctrl4_down_LsuL1Plugin_logic_EVENT_WRITE_MASK_lane0[3];
  assign when_LsuL1Plugin_l1037_1 = execute_ctrl4_down_LsuL1Plugin_logic_WRITE_TO_READ_HAZARDS_lane0[0];
  assign when_LsuL1Plugin_l1041_4 = execute_ctrl3_down_LsuL1Plugin_logic_EVENT_WRITE_MASK_lane0[0];
  assign when_LsuL1Plugin_l1041_5 = execute_ctrl3_down_LsuL1Plugin_logic_EVENT_WRITE_MASK_lane0[1];
  assign when_LsuL1Plugin_l1041_6 = execute_ctrl3_down_LsuL1Plugin_logic_EVENT_WRITE_MASK_lane0[2];
  assign when_LsuL1Plugin_l1041_7 = execute_ctrl3_down_LsuL1Plugin_logic_EVENT_WRITE_MASK_lane0[3];
  assign execute_ctrl4_down_LsuL1_READ_DATA_lane0 = execute_ctrl4_down_LsuL1Plugin_logic_BYPASSED_DATA_lane0;
  assign LsuL1Plugin_logic_initializer_done = LsuL1Plugin_logic_initializer_counter[6];
  assign when_LsuL1Plugin_l1236 = (! LsuL1Plugin_logic_initializer_done);
  assign _zz_LsuL1Plugin_logic_shared_write_payload_data_plru_0 = 3'b000;
  assign LsuL1Plugin_logic_initializerMem_busy = (! LsuL1Plugin_logic_initializerMem_counter[9]);
  assign LsuL1Plugin_logic_refill_read_reservation_win = (! 1'b0);
  assign LsuL1Plugin_logic_lsu_ctrl_wayWriteReservation_win = (! (|LsuL1Plugin_logic_refill_read_reservation_take));
  assign LsuL1Plugin_logic_refill_read_writeReservation_win = (! 1'b0);
  assign LsuL1Plugin_logic_lsu_ctrl_bankWriteReservation_win = (! (|LsuL1Plugin_logic_refill_read_writeReservation_take));
  assign PcPlugin_logic_forcedSpawn = (|{TrapPlugin_logic_harts_0_trap_pcPort_valid,late1_BranchPlugin_logic_pcPort_valid,early1_BranchPlugin_logic_pcPort_valid,late0_BranchPlugin_logic_pcPort_valid,early0_BranchPlugin_logic_pcPort_valid,BtbPlugin_logic_pcPort_valid});
  assign PcPlugin_logic_harts_0_self_pc = (PcPlugin_logic_harts_0_self_state + _zz_PcPlugin_logic_harts_0_self_pc);
  assign PcPlugin_logic_harts_0_self_flow_valid = 1'b1;
  assign PcPlugin_logic_harts_0_self_flow_payload_fault = PcPlugin_logic_harts_0_self_fault;
  assign PcPlugin_logic_harts_0_self_flow_payload_pc = PcPlugin_logic_harts_0_self_pc;
  assign PcPlugin_logic_harts_0_aggregator_sortedByPriority_5_laneValid = 1'b1;
  assign PcPlugin_logic_harts_0_aggregator_sortedByPriority_3_laneValid = (&((! early1_BranchPlugin_logic_pcPort_valid) || (early0_BranchPlugin_logic_pcPort_payload_laneAge < early1_BranchPlugin_logic_pcPort_payload_laneAge)));
  assign PcPlugin_logic_harts_0_aggregator_sortedByPriority_1_laneValid = (&((! late1_BranchPlugin_logic_pcPort_valid) || (late0_BranchPlugin_logic_pcPort_payload_laneAge < late1_BranchPlugin_logic_pcPort_payload_laneAge)));
  assign PcPlugin_logic_harts_0_aggregator_sortedByPriority_4_laneValid = (&((! early0_BranchPlugin_logic_pcPort_valid) || (early1_BranchPlugin_logic_pcPort_payload_laneAge < early0_BranchPlugin_logic_pcPort_payload_laneAge)));
  assign PcPlugin_logic_harts_0_aggregator_sortedByPriority_2_laneValid = (&((! late0_BranchPlugin_logic_pcPort_valid) || (late1_BranchPlugin_logic_pcPort_payload_laneAge < late0_BranchPlugin_logic_pcPort_payload_laneAge)));
  assign PcPlugin_logic_harts_0_aggregator_sortedByPriority_0_laneValid = 1'b1;
  assign PcPlugin_logic_harts_0_aggregator_sortedByPriority_6_laneValid = 1'b1;
  assign PcPlugin_logic_harts_0_aggregator_valids_0 = ((TrapPlugin_logic_harts_0_trap_pcPort_valid && 1'b1) && PcPlugin_logic_harts_0_aggregator_sortedByPriority_0_laneValid);
  assign PcPlugin_logic_harts_0_aggregator_valids_1 = ((late0_BranchPlugin_logic_pcPort_valid && 1'b1) && PcPlugin_logic_harts_0_aggregator_sortedByPriority_1_laneValid);
  assign PcPlugin_logic_harts_0_aggregator_valids_2 = ((late1_BranchPlugin_logic_pcPort_valid && 1'b1) && PcPlugin_logic_harts_0_aggregator_sortedByPriority_2_laneValid);
