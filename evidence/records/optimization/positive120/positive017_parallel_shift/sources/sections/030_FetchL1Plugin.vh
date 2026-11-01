  assign when_FetchL1Plugin_l253_26 = (! FetchL1Plugin_logic_refill_slots_6_valid);
  assign when_FetchL1Plugin_l253_27 = (! FetchL1Plugin_logic_refill_slots_7_valid);
  assign when_FetchL1Plugin_l253_28 = (! FetchL1Plugin_logic_refill_slots_0_valid);
  assign when_FetchL1Plugin_l253_29 = (! FetchL1Plugin_logic_refill_slots_1_valid);
  assign when_FetchL1Plugin_l253_30 = (! FetchL1Plugin_logic_refill_slots_2_valid);
  assign when_FetchL1Plugin_l253_31 = (! FetchL1Plugin_logic_refill_slots_3_valid);
  assign when_FetchL1Plugin_l253_32 = (! FetchL1Plugin_logic_refill_slots_5_valid);
  assign when_FetchL1Plugin_l253_33 = (! FetchL1Plugin_logic_refill_slots_6_valid);
  assign when_FetchL1Plugin_l253_34 = (! FetchL1Plugin_logic_refill_slots_7_valid);
  assign when_FetchL1Plugin_l253_35 = (! FetchL1Plugin_logic_refill_slots_0_valid);
  assign when_FetchL1Plugin_l253_36 = (! FetchL1Plugin_logic_refill_slots_1_valid);
  assign when_FetchL1Plugin_l253_37 = (! FetchL1Plugin_logic_refill_slots_2_valid);
  assign when_FetchL1Plugin_l253_38 = (! FetchL1Plugin_logic_refill_slots_3_valid);
  assign when_FetchL1Plugin_l253_39 = (! FetchL1Plugin_logic_refill_slots_4_valid);
  assign when_FetchL1Plugin_l253_40 = (! FetchL1Plugin_logic_refill_slots_6_valid);
  assign when_FetchL1Plugin_l253_41 = (! FetchL1Plugin_logic_refill_slots_7_valid);
  assign when_FetchL1Plugin_l253_42 = (! FetchL1Plugin_logic_refill_slots_0_valid);
  assign when_FetchL1Plugin_l253_43 = (! FetchL1Plugin_logic_refill_slots_1_valid);
  assign when_FetchL1Plugin_l253_44 = (! FetchL1Plugin_logic_refill_slots_2_valid);
  assign when_FetchL1Plugin_l253_45 = (! FetchL1Plugin_logic_refill_slots_3_valid);
  assign when_FetchL1Plugin_l253_46 = (! FetchL1Plugin_logic_refill_slots_4_valid);
  assign when_FetchL1Plugin_l253_47 = (! FetchL1Plugin_logic_refill_slots_5_valid);
  assign when_FetchL1Plugin_l253_48 = (! FetchL1Plugin_logic_refill_slots_7_valid);
  assign when_FetchL1Plugin_l253_49 = (! FetchL1Plugin_logic_refill_slots_0_valid);
  assign when_FetchL1Plugin_l253_50 = (! FetchL1Plugin_logic_refill_slots_1_valid);
  assign when_FetchL1Plugin_l253_51 = (! FetchL1Plugin_logic_refill_slots_2_valid);
  assign when_FetchL1Plugin_l253_52 = (! FetchL1Plugin_logic_refill_slots_3_valid);
  assign when_FetchL1Plugin_l253_53 = (! FetchL1Plugin_logic_refill_slots_4_valid);
  assign when_FetchL1Plugin_l253_54 = (! FetchL1Plugin_logic_refill_slots_5_valid);
  assign when_FetchL1Plugin_l253_55 = (! FetchL1Plugin_logic_refill_slots_6_valid);
  assign _zz_24 = (! FetchL1Plugin_logic_refill_slots_0_valid);
  assign _zz_25 = {(! FetchL1Plugin_logic_refill_slots_7_valid),(! FetchL1Plugin_logic_refill_slots_6_valid),(! FetchL1Plugin_logic_refill_slots_5_valid),(! FetchL1Plugin_logic_refill_slots_4_valid),(! FetchL1Plugin_logic_refill_slots_3_valid),(! FetchL1Plugin_logic_refill_slots_2_valid),(! FetchL1Plugin_logic_refill_slots_1_valid),_zz_24};
  assign _zz_26 = (_zz_25 & (~ _zz__zz_26));
  assign FetchL1Plugin_logic_refill_hazard = (|{(FetchL1Plugin_logic_refill_slots_7_valid && (FetchL1Plugin_logic_refill_slots_7_address[12 : 6] == FetchL1Plugin_logic_refill_start_address[12 : 6])),(FetchL1Plugin_logic_refill_slots_6_valid && (FetchL1Plugin_logic_refill_slots_6_address[12 : 6] == FetchL1Plugin_logic_refill_start_address[12 : 6])),(FetchL1Plugin_logic_refill_slots_5_valid && (_zz_FetchL1Plugin_logic_refill_hazard == _zz_FetchL1Plugin_logic_refill_hazard_1)),(FetchL1Plugin_logic_refill_slots_4_valid && _zz_FetchL1Plugin_logic_refill_hazard_2),_zz_FetchL1Plugin_logic_refill_hazard_3,_zz_FetchL1Plugin_logic_refill_hazard_4,(FetchL1Plugin_logic_refill_slots_1_valid && (FetchL1Plugin_logic_refill_slots_1_address[12 : 6] == FetchL1Plugin_logic_refill_start_address[12 : 6])),(FetchL1Plugin_logic_refill_slots_0_valid && (FetchL1Plugin_logic_refill_slots_0_address[12 : 6] == FetchL1Plugin_logic_refill_start_address[12 : 6]))});
  assign when_FetchL1Plugin_l262 = ((FetchL1Plugin_logic_refill_start_valid && FetchL1Plugin_logic_invalidate_done) && (! FetchL1Plugin_logic_refill_hazard));
  assign when_FetchL1Plugin_l275 = ((|{FetchL1Plugin_logic_refill_slots_7_valid,FetchL1Plugin_logic_refill_slots_6_valid,FetchL1Plugin_logic_refill_slots_5_valid,FetchL1Plugin_logic_refill_slots_4_valid,FetchL1Plugin_logic_refill_slots_3_valid,FetchL1Plugin_logic_refill_slots_2_valid,FetchL1Plugin_logic_refill_slots_1_valid,FetchL1Plugin_logic_refill_slots_0_valid}) || FetchL1Plugin_logic_refill_start_valid);
  assign FetchL1Plugin_logic_refill_onCmd_propoedOh = {(FetchL1Plugin_logic_refill_slots_7_askCmd && (&{_zz_FetchL1Plugin_logic_refill_onCmd_propoedOh,_zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_2,_zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_6,_zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_8,_zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_13,_zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_17,_zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_22})),(FetchL1Plugin_logic_refill_slots_6_askCmd && (&{_zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_27,_zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_31,_zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_33,_zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_38,_zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_42,_zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_48,_zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_53})),(FetchL1Plugin_logic_refill_slots_5_askCmd && (&_zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_58)),(FetchL1Plugin_logic_refill_slots_4_askCmd && _zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_90),_zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_123,_zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_156,_zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_186,_zz_FetchL1Plugin_logic_refill_onCmd_propoedOh_212};
  assign when_FetchL1Plugin_l283 = (! FetchL1Plugin_logic_refill_onCmd_locked);
  assign FetchL1Plugin_logic_refill_onCmd_oh = (FetchL1Plugin_logic_refill_onCmd_locked ? FetchL1Plugin_logic_refill_onCmd_lockedOh : FetchL1Plugin_logic_refill_onCmd_propoedOh);
  assign _zz_FetchL1Plugin_logic_bus_cmd_payload_address = FetchL1Plugin_logic_refill_onCmd_oh[0];
  assign _zz_FetchL1Plugin_logic_bus_cmd_payload_address_1 = FetchL1Plugin_logic_refill_onCmd_oh[1];
  assign _zz_FetchL1Plugin_logic_bus_cmd_payload_address_2 = FetchL1Plugin_logic_refill_onCmd_oh[2];
  assign _zz_FetchL1Plugin_logic_bus_cmd_payload_address_3 = FetchL1Plugin_logic_refill_onCmd_oh[3];
  assign _zz_FetchL1Plugin_logic_bus_cmd_payload_address_4 = FetchL1Plugin_logic_refill_onCmd_oh[4];
  assign _zz_FetchL1Plugin_logic_bus_cmd_payload_address_5 = FetchL1Plugin_logic_refill_onCmd_oh[5];
  assign _zz_FetchL1Plugin_logic_bus_cmd_payload_address_6 = FetchL1Plugin_logic_refill_onCmd_oh[6];
  assign _zz_FetchL1Plugin_logic_bus_cmd_payload_address_7 = FetchL1Plugin_logic_refill_onCmd_oh[7];
  assign FetchL1Plugin_logic_bus_cmd_valid = (|FetchL1Plugin_logic_refill_onCmd_oh);
  assign FetchL1Plugin_logic_bus_cmd_payload_address = {((((_zz_FetchL1Plugin_logic_bus_cmd_payload_address ? _zz_FetchL1Plugin_logic_bus_cmd_payload_address_8 : _zz_FetchL1Plugin_logic_bus_cmd_payload_address_9) | (_zz_FetchL1Plugin_logic_bus_cmd_payload_address_1 ? _zz_FetchL1Plugin_logic_bus_cmd_payload_address_10 : _zz_FetchL1Plugin_logic_bus_cmd_payload_address_11)) | ((_zz_FetchL1Plugin_logic_bus_cmd_payload_address_2 ? _zz_FetchL1Plugin_logic_bus_cmd_payload_address_12 : _zz_FetchL1Plugin_logic_bus_cmd_payload_address_13) | (_zz_FetchL1Plugin_logic_bus_cmd_payload_address_3 ? _zz_FetchL1Plugin_logic_bus_cmd_payload_address_14 : _zz_FetchL1Plugin_logic_bus_cmd_payload_address_15))) | (((_zz_FetchL1Plugin_logic_bus_cmd_payload_address_4 ? _zz_FetchL1Plugin_logic_bus_cmd_payload_address_16 : _zz_FetchL1Plugin_logic_bus_cmd_payload_address_17) | (_zz_FetchL1Plugin_logic_bus_cmd_payload_address_5 ? _zz_FetchL1Plugin_logic_bus_cmd_payload_address_18 : _zz_FetchL1Plugin_logic_bus_cmd_payload_address_19)) | ((_zz_FetchL1Plugin_logic_bus_cmd_payload_address_6 ? _zz_FetchL1Plugin_logic_bus_cmd_payload_address_20 : _zz_FetchL1Plugin_logic_bus_cmd_payload_address_21) | (_zz_FetchL1Plugin_logic_bus_cmd_payload_address_7 ? _zz_FetchL1Plugin_logic_bus_cmd_payload_address_22 : _zz_FetchL1Plugin_logic_bus_cmd_payload_address_23)))),6'h0};
  assign FetchL1Plugin_logic_bus_cmd_payload_io = _zz_FetchL1Plugin_logic_bus_cmd_payload_io[0];
  assign _zz_FetchL1Plugin_logic_bus_cmd_payload_id = (((_zz_FetchL1Plugin_logic_bus_cmd_payload_address_1 || _zz_FetchL1Plugin_logic_bus_cmd_payload_address_3) || _zz_FetchL1Plugin_logic_bus_cmd_payload_address_5) || _zz_FetchL1Plugin_logic_bus_cmd_payload_address_7);
  assign _zz_FetchL1Plugin_logic_bus_cmd_payload_id_1 = (((_zz_FetchL1Plugin_logic_bus_cmd_payload_address_2 || _zz_FetchL1Plugin_logic_bus_cmd_payload_address_3) || _zz_FetchL1Plugin_logic_bus_cmd_payload_address_6) || _zz_FetchL1Plugin_logic_bus_cmd_payload_address_7);
  assign _zz_FetchL1Plugin_logic_bus_cmd_payload_id_2 = (((_zz_FetchL1Plugin_logic_bus_cmd_payload_address_4 || _zz_FetchL1Plugin_logic_bus_cmd_payload_address_5) || _zz_FetchL1Plugin_logic_bus_cmd_payload_address_6) || _zz_FetchL1Plugin_logic_bus_cmd_payload_address_7);
  assign FetchL1Plugin_logic_bus_cmd_payload_id = {_zz_FetchL1Plugin_logic_bus_cmd_payload_id_2,_zz_FetchL1Plugin_logic_bus_cmd_payload_id_1,_zz_FetchL1Plugin_logic_bus_cmd_payload_id};
  assign FetchL1Plugin_logic_refill_onRsp_holdHarts = ((|FetchL1Plugin_logic_waysWrite_mask) || (|{((FetchL1Plugin_logic_refill_slots_7_valid && (_zz_FetchL1Plugin_logic_refill_onRsp_holdHarts == _zz_FetchL1Plugin_logic_refill_onRsp_holdHarts_1)) && (! (_zz_FetchL1Plugin_logic_refill_onRsp_holdHarts_2 && _zz_FetchL1Plugin_logic_refill_onRsp_holdHarts_3))),((FetchL1Plugin_logic_refill_slots_6_valid && _zz_FetchL1Plugin_logic_refill_onRsp_holdHarts_4) && (! _zz_FetchL1Plugin_logic_refill_onRsp_holdHarts_5)),(_zz_FetchL1Plugin_logic_refill_onRsp_holdHarts_8 && _zz_FetchL1Plugin_logic_refill_onRsp_holdHarts_11),_zz_FetchL1Plugin_logic_refill_onRsp_holdHarts_14,_zz_FetchL1Plugin_logic_refill_onRsp_holdHarts_17,_zz_FetchL1Plugin_logic_refill_onRsp_holdHarts_23,_zz_FetchL1Plugin_logic_refill_onRsp_holdHarts_28,_zz_FetchL1Plugin_logic_refill_onRsp_holdHarts_31}));
  assign fetch_logic_ctrls_0_haltRequest_FetchL1Plugin_l304 = FetchL1Plugin_logic_refill_onRsp_holdHarts;
  assign FetchL1Plugin_logic_bus_rsp_fire = (FetchL1Plugin_logic_bus_rsp_valid && FetchL1Plugin_logic_bus_rsp_ready);
  assign FetchL1Plugin_logic_refill_onRsp_wayToAllocate = _zz_FetchL1Plugin_logic_refill_onRsp_wayToAllocate;
  assign FetchL1Plugin_logic_refill_onRsp_address = _zz_FetchL1Plugin_logic_refill_onRsp_address;
  assign when_FetchL1Plugin_l311 = (FetchL1Plugin_logic_bus_rsp_valid && (FetchL1Plugin_logic_refill_onRsp_firstCycle || FetchL1Plugin_logic_bus_rsp_payload_error));
  always @(*) begin
    FetchL1Plugin_logic_banks_0_write_valid = (FetchL1Plugin_logic_bus_rsp_valid && (FetchL1Plugin_logic_refill_onRsp_wayToAllocate == 1'b0));
    if(FetchL1Plugin_logic_initializer_busy) begin
      FetchL1Plugin_logic_banks_0_write_valid = 1'b1;
    end
  end

  always @(*) begin
    FetchL1Plugin_logic_banks_0_write_payload_address = {FetchL1Plugin_logic_refill_onRsp_address[12 : 6],FetchL1Plugin_logic_refill_onRsp_wordIndex};
    if(FetchL1Plugin_logic_initializer_busy) begin
      FetchL1Plugin_logic_banks_0_write_payload_address = FetchL1Plugin_logic_initializer_counter[9:0];
    end
  end

  always @(*) begin
    FetchL1Plugin_logic_banks_0_write_payload_data = FetchL1Plugin_logic_bus_rsp_payload_data;
    if(FetchL1Plugin_logic_initializer_busy) begin
      FetchL1Plugin_logic_banks_0_write_payload_data = 64'h0;
    end
  end

  always @(*) begin
    FetchL1Plugin_logic_banks_1_write_valid = (FetchL1Plugin_logic_bus_rsp_valid && (FetchL1Plugin_logic_refill_onRsp_wayToAllocate == 1'b1));
    if(FetchL1Plugin_logic_initializer_busy) begin
      FetchL1Plugin_logic_banks_1_write_valid = 1'b1;
    end
  end

  always @(*) begin
    FetchL1Plugin_logic_banks_1_write_payload_address = {FetchL1Plugin_logic_refill_onRsp_address[12 : 6],FetchL1Plugin_logic_refill_onRsp_wordIndex};
    if(FetchL1Plugin_logic_initializer_busy) begin
      FetchL1Plugin_logic_banks_1_write_payload_address = FetchL1Plugin_logic_initializer_counter[9:0];
    end
  end

  always @(*) begin
    FetchL1Plugin_logic_banks_1_write_payload_data = FetchL1Plugin_logic_bus_rsp_payload_data;
    if(FetchL1Plugin_logic_initializer_busy) begin
      FetchL1Plugin_logic_banks_1_write_payload_data = 64'h0;
    end
  end

  assign FetchL1Plugin_logic_bus_rsp_ready = 1'b1;
  assign when_FetchL1Plugin_l337 = (FetchL1Plugin_logic_refill_onRsp_wordIndex == 3'b111);
  assign FetchL1Plugin_logic_cmd_doIt = (fetch_logic_ctrls_1_up_ready || ((! fetch_logic_ctrls_1_up_valid) && 1'b1));
  assign FetchL1Plugin_logic_banks_0_read_cmd_valid = FetchL1Plugin_logic_cmd_doIt;
  assign FetchL1Plugin_logic_banks_0_read_cmd_payload = fetch_logic_ctrls_0_down_Fetch_WORD_PC[12 : 3];
  assign FetchL1Plugin_logic_banks_1_read_cmd_valid = FetchL1Plugin_logic_cmd_doIt;
  assign FetchL1Plugin_logic_banks_1_read_cmd_payload = fetch_logic_ctrls_0_down_Fetch_WORD_PC[12 : 3];
  assign FetchL1Plugin_logic_ways_0_read_cmd_valid = FetchL1Plugin_logic_cmd_doIt;
  assign FetchL1Plugin_logic_ways_0_read_cmd_payload = fetch_logic_ctrls_0_down_Fetch_WORD_PC[12 : 6];
  assign FetchL1Plugin_logic_ways_1_read_cmd_valid = FetchL1Plugin_logic_cmd_doIt;
  assign FetchL1Plugin_logic_ways_1_read_cmd_payload = fetch_logic_ctrls_0_down_Fetch_WORD_PC[12 : 6];
  assign FetchL1Plugin_logic_plru_read_cmd_valid = FetchL1Plugin_logic_cmd_doIt;
  assign FetchL1Plugin_logic_plru_read_cmd_payload = fetch_logic_ctrls_0_down_Fetch_WORD_PC[12 : 6];
  assign fetch_logic_ctrls_0_down_FetchL1Plugin_logic_cmd_PLRU_BYPASS_VALID = (FetchL1Plugin_logic_plru_write_valid && (FetchL1Plugin_logic_plru_write_payload_address == FetchL1Plugin_logic_plru_read_cmd_payload));
  assign fetch_logic_ctrls_0_down_FetchL1Plugin_logic_cmd_PLRU_BYPASS_DATA_0 = FetchL1Plugin_logic_plru_write_payload_data_0;
  assign fetch_logic_ctrls_0_down_FetchL1Plugin_logic_cmd_TAGS_UPDATE = (|FetchL1Plugin_logic_waysWrite_mask);
  assign fetch_logic_ctrls_0_down_FetchL1Plugin_logic_cmd_TAGS_UPDATE_ADDRESS = FetchL1Plugin_logic_waysWrite_address;
  always @(*) begin
    fetch_logic_ctrls_1_down_FetchL1Plugin_logic_PLRU_BYPASSED_0 = fetch_logic_ctrls_1_down_FetchL1Plugin_logic_PLRU_READ_0;
    if(fetch_logic_ctrls_1_down_FetchL1Plugin_logic_cmd_PLRU_BYPASS_VALID) begin
      fetch_logic_ctrls_1_down_FetchL1Plugin_logic_PLRU_BYPASSED_0 = fetch_logic_ctrls_1_down_FetchL1Plugin_logic_cmd_PLRU_BYPASS_DATA_0;
    end
  end

  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_BANKS_MUXES_0 = fetch_logic_ctrls_1_down_FetchL1Plugin_logic_BANKS_WORDS_0[63 : 0];
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_BANKS_MUXES_1 = fetch_logic_ctrls_1_down_FetchL1Plugin_logic_BANKS_WORDS_1[63 : 0];
  assign fetch_logic_ctrls_2_down_Fetch_WORD = ((fetch_logic_ctrls_2_down_FetchL1Plugin_logic_WAYS_HITS_0 ? fetch_logic_ctrls_2_down_FetchL1Plugin_logic_BANKS_MUXES_0 : 64'h0) | (fetch_logic_ctrls_2_down_FetchL1Plugin_logic_WAYS_HITS_1 ? fetch_logic_ctrls_2_down_FetchL1Plugin_logic_BANKS_MUXES_1 : 64'h0));
  assign FetchL1Plugin_logic_hazard_pcRange = fetch_logic_ctrls_1_down_Fetch_WORD_PC[12 : 6];
  assign FetchL1Plugin_logic_hazard_writeCheck = ((|FetchL1Plugin_logic_waysWrite_mask) && (FetchL1Plugin_logic_waysWrite_address == FetchL1Plugin_logic_hazard_pcRange));
  assign FetchL1Plugin_logic_hazard_wayWriteCheck = (FetchL1Plugin_logic_hazard_writeCheck || FetchL1Plugin_logic_hazard_checkHold);
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_HAZARD = ((fetch_logic_ctrls_1_down_FetchL1Plugin_logic_cmd_TAGS_UPDATE && (fetch_logic_ctrls_1_down_FetchL1Plugin_logic_cmd_TAGS_UPDATE_ADDRESS == FetchL1Plugin_logic_hazard_pcRange)) || FetchL1Plugin_logic_hazard_wayWriteCheck);
  assign _zz_fetch_logic_ctrls_2_FetchL1Plugin_logic_HAZARD_bypass = ((|FetchL1Plugin_logic_waysWrite_mask) && (FetchL1Plugin_logic_waysWrite_address == fetch_logic_ctrls_2_down_Fetch_WORD_PC[12 : 6]));
  assign fetch_logic_ctrls_2_FetchL1Plugin_logic_HAZARD_bypass = (fetch_logic_ctrls_2_up_FetchL1Plugin_logic_HAZARD || (_zz_fetch_logic_ctrls_2_FetchL1Plugin_logic_HAZARD_bypass || _zz_fetch_logic_ctrls_2_FetchL1Plugin_logic_HAZARD_bypass_1));
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_HITS_0 = (fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_TAGS_0_loaded && (fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_TAGS_0_address == fetch_logic_ctrls_1_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_TRANSLATED[31 : 13]));
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_HITS_1 = (fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_TAGS_1_loaded && (fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_TAGS_1_address == fetch_logic_ctrls_1_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_TRANSLATED[31 : 13]));
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_HIT = (|{fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_HITS_1,fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_HITS_0});
  assign FetchL1Plugin_logic_ctrl_pmaPort_cmd_address = fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_TRANSLATED;
  assign FetchL1Plugin_logic_ctrl_plruLogic_core_evict_logic_0_state = FetchL1Plugin_logic_ctrl_plruLogic_core_io_context_state_0[0];
  assign FetchL1Plugin_logic_ctrl_plruLogic_core_evict_sel_0 = (! FetchL1Plugin_logic_ctrl_plruLogic_core_evict_logic_0_state);
  assign FetchL1Plugin_logic_ctrl_plruLogic_core_io_evict_id = FetchL1Plugin_logic_ctrl_plruLogic_core_evict_sel_0;
  assign FetchL1Plugin_logic_ctrl_plruLogic_core_io_update_state_0[0] = FetchL1Plugin_logic_ctrl_plruLogic_core_io_update_id[0];
  assign FetchL1Plugin_logic_ctrl_plruLogic_core_io_context_state_0 = fetch_logic_ctrls_2_down_FetchL1Plugin_logic_PLRU_BYPASSED_0;
  assign FetchL1Plugin_logic_ctrl_plruLogic_core_io_update_id = fetch_logic_ctrls_2_down_FetchL1Plugin_logic_WAYS_HITS_1;
  always @(*) begin
    FetchL1Plugin_logic_plru_write_valid = FetchL1Plugin_logic_ctrl_plruLogic_buffer_regNext_valid;
    if(when_FetchL1Plugin_l673) begin
      FetchL1Plugin_logic_plru_write_valid = 1'b1;
    end
  end

  always @(*) begin
    FetchL1Plugin_logic_plru_write_payload_address = FetchL1Plugin_logic_ctrl_plruLogic_buffer_regNext_payload_address;
    if(when_FetchL1Plugin_l673) begin
      FetchL1Plugin_logic_plru_write_payload_address = FetchL1Plugin_logic_invalidate_counter[6:0];
    end
  end

  always @(*) begin
    FetchL1Plugin_logic_plru_write_payload_data_0 = FetchL1Plugin_logic_ctrl_plruLogic_buffer_regNext_payload_data_0;
    if(when_FetchL1Plugin_l673) begin
      FetchL1Plugin_logic_plru_write_payload_data_0 = _zz_FetchL1Plugin_logic_plru_write_payload_data_0[0 : 0];
    end
  end

  assign FetchL1Plugin_logic_ctrl_plruLogic_buffer_valid = (fetch_logic_ctrls_2_up_isValid && fetch_logic_ctrls_2_up_isReady);
  assign FetchL1Plugin_logic_ctrl_plruLogic_buffer_payload_address = fetch_logic_ctrls_2_down_Fetch_WORD_PC[12 : 6];
  assign FetchL1Plugin_logic_ctrl_plruLogic_buffer_payload_data_0 = FetchL1Plugin_logic_ctrl_plruLogic_core_io_update_state_0;
  assign FetchL1Plugin_logic_refill_start_wayToAllocate = FetchL1Plugin_logic_ctrl_plruLogic_core_io_evict_id;
  assign FetchL1Plugin_logic_ctrl_dataAccessFault = (_zz_FetchL1Plugin_logic_ctrl_dataAccessFault[0] && (! fetch_logic_ctrls_2_down_FetchL1Plugin_logic_HAZARD));
  always @(*) begin
    FetchL1Plugin_logic_trapPort_valid = 1'b0;
    if(when_FetchL1Plugin_l560) begin
      FetchL1Plugin_logic_trapPort_valid = 1'b1;
    end
    if(when_FetchL1Plugin_l566) begin
      FetchL1Plugin_logic_trapPort_valid = 1'b1;
    end
    if(fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_PAGE_FAULT) begin
      FetchL1Plugin_logic_trapPort_valid = 1'b1;
    end
    if(fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_ACCESS_FAULT) begin
      FetchL1Plugin_logic_trapPort_valid = 1'b1;
    end
    if(fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_REFILL) begin
      FetchL1Plugin_logic_trapPort_valid = 1'b1;
    end
    if(fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_HAZARD) begin
      FetchL1Plugin_logic_trapPort_valid = 1'b1;
    end
    if(fetch_logic_ctrls_2_down_Fetch_PC_FAULT) begin
      FetchL1Plugin_logic_trapPort_valid = 1'b1;
    end
    if(when_FetchL1Plugin_l648) begin
      FetchL1Plugin_logic_trapPort_valid = 1'b0;
    end
  end

  assign FetchL1Plugin_logic_trapPort_payload_tval = fetch_logic_ctrls_2_down_Fetch_WORD_PC;
  assign FetchL1Plugin_logic_trapPort_payload_tval2 = {2'd0, _zz_FetchL1Plugin_logic_trapPort_payload_tval2};
  always @(*) begin
    FetchL1Plugin_logic_trapPort_payload_exception = 1'bx;
    if(when_FetchL1Plugin_l560) begin
      FetchL1Plugin_logic_trapPort_payload_exception = 1'b0;
    end
    if(when_FetchL1Plugin_l566) begin
      FetchL1Plugin_logic_trapPort_payload_exception = 1'b1;
    end
    if(fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_PAGE_FAULT) begin
      FetchL1Plugin_logic_trapPort_payload_exception = 1'b1;
    end
    if(fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_ACCESS_FAULT) begin
      FetchL1Plugin_logic_trapPort_payload_exception = 1'b1;
    end
    if(fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_REFILL) begin
      FetchL1Plugin_logic_trapPort_payload_exception = 1'b0;
    end
    if(fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_HAZARD) begin
      FetchL1Plugin_logic_trapPort_payload_exception = 1'b0;
    end
    if(fetch_logic_ctrls_2_down_Fetch_PC_FAULT) begin
      FetchL1Plugin_logic_trapPort_payload_exception = 1'b1;
    end
  end

  always @(*) begin
    FetchL1Plugin_logic_trapPort_payload_code = 5'bxxxxx;
    if(when_FetchL1Plugin_l560) begin
      FetchL1Plugin_logic_trapPort_payload_code = 5'h04;
    end
    if(when_FetchL1Plugin_l566) begin
      FetchL1Plugin_logic_trapPort_payload_code = 5'h01;
    end
    if(fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_PAGE_FAULT) begin
      FetchL1Plugin_logic_trapPort_payload_code = 5'h0c;
    end
    if(fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_ACCESS_FAULT) begin
      FetchL1Plugin_logic_trapPort_payload_code = 5'h01;
    end
    if(fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_REFILL) begin
      FetchL1Plugin_logic_trapPort_payload_code = 5'h07;
    end
    if(fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_HAZARD) begin
      FetchL1Plugin_logic_trapPort_payload_code = 5'h04;
    end
    if(fetch_logic_ctrls_2_down_Fetch_PC_FAULT) begin
      FetchL1Plugin_logic_trapPort_payload_code = 5'h01;
      if(when_FetchL1Plugin_l609) begin
        FetchL1Plugin_logic_trapPort_payload_code = 5'h0c;
      end
    end
  end

  assign _zz_55 = zz_FetchL1Plugin_logic_trapPort_payload_arg(1'b0);
  always @(*) FetchL1Plugin_logic_trapPort_payload_arg = _zz_55;
  always @(*) begin
    FetchL1Plugin_logic_ctrl_allowRefill = ((! fetch_logic_ctrls_2_down_FetchL1Plugin_logic_WAYS_HIT) && (! fetch_logic_ctrls_2_down_FetchL1Plugin_logic_HAZARD));
    if(when_FetchL1Plugin_l566) begin
      FetchL1Plugin_logic_ctrl_allowRefill = 1'b0;
    end
    if(fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_PAGE_FAULT) begin
      FetchL1Plugin_logic_ctrl_allowRefill = 1'b0;
    end
    if(fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_ACCESS_FAULT) begin
      FetchL1Plugin_logic_ctrl_allowRefill = 1'b0;
    end
    if(fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_REFILL) begin
      FetchL1Plugin_logic_ctrl_allowRefill = 1'b0;
    end
    if(fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_HAZARD) begin
      FetchL1Plugin_logic_ctrl_allowRefill = 1'b0;
    end
    if(fetch_logic_ctrls_2_down_Fetch_PC_FAULT) begin
      FetchL1Plugin_logic_ctrl_allowRefill = 1'b0;
    end
  end

  assign when_FetchL1Plugin_l560 = ((! fetch_logic_ctrls_2_down_FetchL1Plugin_logic_WAYS_HIT) || fetch_logic_ctrls_2_down_FetchL1Plugin_logic_HAZARD);
  assign when_FetchL1Plugin_l566 = ((FetchL1Plugin_logic_ctrl_dataAccessFault || FetchL1Plugin_logic_ctrl_pmaPort_rsp_fault) || fetch_logic_ctrls_2_down_FetchL1Plugin_logic_pmpPort_ACCESS_FAULT);
  assign when_FetchL1Plugin_l609 = (! fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_BYPASS_TRANSLATION);
  always @(*) begin
    FetchL1Plugin_logic_refill_start_valid = (FetchL1Plugin_logic_ctrl_allowRefill && (! FetchL1Plugin_logic_ctrl_trapSent));
    if(when_FetchL1Plugin_l652) begin
      FetchL1Plugin_logic_refill_start_valid = 1'b0;
    end
  end

  assign FetchL1Plugin_logic_refill_start_address = fetch_logic_ctrls_2_down_FetchL1Plugin_logic_onAddress0_translationPort_keys_TRANSLATED;
  assign FetchL1Plugin_logic_refill_start_isIo = FetchL1Plugin_logic_ctrl_pmaPort_rsp_io;
  assign fetch_logic_ctrls_2_down_TRAP = (FetchL1Plugin_logic_trapPort_valid || FetchL1Plugin_logic_ctrl_trapSent);
  assign when_FetchL1Plugin_l648 = ((! fetch_logic_ctrls_2_up_isValid) || FetchL1Plugin_logic_ctrl_trapSent);
  assign when_FetchL1Plugin_l652 = ((! fetch_logic_ctrls_2_up_isValid) && 1'b1);
  assign when_FetchL1Plugin_l656 = (((! fetch_logic_ctrls_2_up_isValid) || fetch_logic_ctrls_2_down_isReady) || fetch_logic_ctrls_2_up_isCanceling);
  assign when_FetchL1Plugin_l664 = (fetch_logic_ctrls_2_up_isValid && (! fetch_logic_ctrls_2_down_TRAP));
  assign FetchL1Plugin_logic_events_access = fetch_logic_ctrls_2_up_isMoving;
  assign FetchL1Plugin_logic_events_miss = (fetch_logic_ctrls_2_up_isMoving && FetchL1Plugin_logic_ctrl_allowRefill);
  assign FetchL1Plugin_logic_events_waiting = FetchL1Plugin_logic_ctrl_onEvents_waiting;
  assign when_FetchL1Plugin_l673 = (! FetchL1Plugin_logic_invalidate_done);
  assign FetchL1Plugin_logic_initializer_busy = (! FetchL1Plugin_logic_initializer_counter[10]);
  assign LsuPlugin_logic_frontend_defaultsDecodings_0 = 1'b0;
  assign LsuPlugin_logic_frontend_defaultsDecodings_1 = 1'b0;
  assign LsuPlugin_logic_frontend_defaultsDecodings_2 = 1'b0;
  assign LsuPlugin_logic_frontend_defaultsDecodings_3 = 1'b0;
  assign LsuPlugin_logic_frontend_defaultsDecodings_4 = 1'b0;
  assign LsuPlugin_logic_frontend_defaultsDecodings_5 = 1'b0;
  assign LsuPlugin_logic_frontend_defaultsDecodings_6 = 1'b0;
  assign LsuPlugin_logic_frontend_defaultsDecodings_7 = 1'b0;
  assign GSharePlugin_logic_mem_writes_0_valid = (GSharePlugin_logic_mem_write_valid && 1'b1);
  assign GSharePlugin_logic_mem_writes_0_payload_address = GSharePlugin_logic_mem_write_payload_address;
  assign GSharePlugin_logic_mem_writes_0_payload_data_0 = GSharePlugin_logic_mem_write_payload_data_0;
  assign GSharePlugin_logic_mem_writes_0_payload_data_1 = GSharePlugin_logic_mem_write_payload_data_1;
  assign GSharePlugin_logic_mem_writes_0_payload_data_2 = GSharePlugin_logic_mem_write_payload_data_2;
  assign GSharePlugin_logic_mem_writes_0_payload_data_3 = GSharePlugin_logic_mem_write_payload_data_3;
  assign _zz_fetch_logic_ctrls_0_down_GSharePlugin_logic_HASH = fetch_logic_ctrls_0_down_Fetch_WORD_PC[14 : 3];
  assign fetch_logic_ctrls_0_down_GSharePlugin_logic_HASH = ({_zz_fetch_logic_ctrls_0_down_GSharePlugin_logic_HASH[0],_zz_fetch_logic_ctrls_0_down_GSharePlugin_logic_HASH[1],_zz_fetch_logic_ctrls_0_down_GSharePlugin_logic_HASH[2],_zz_fetch_logic_ctrls_0_down_GSharePlugin_logic_HASH[3],_zz_fetch_logic_ctrls_0_down_GSharePlugin_logic_HASH[4],_zz_fetch_logic_ctrls_0_down_GSharePlugin_logic_HASH[5],_zz_fetch_logic_ctrls_0_down_GSharePlugin_logic_HASH_1,_zz_fetch_logic_ctrls_0_down_GSharePlugin_logic_HASH_2,_zz_fetch_logic_ctrls_0_down_GSharePlugin_logic_HASH[8],_zz_fetch_logic_ctrls_0_down_GSharePlugin_logic_HASH[9],_zz_fetch_logic_ctrls_0_down_GSharePlugin_logic_HASH[10],_zz_fetch_logic_ctrls_0_down_GSharePlugin_logic_HASH[11]} ^ fetch_logic_ctrls_0_down_Prediction_BRANCH_HISTORY);
  assign fetch_logic_ctrls_0_down_GSharePlugin_logic_BYPASS_valid = GSharePlugin_logic_mem_write_valid;
  assign fetch_logic_ctrls_0_down_GSharePlugin_logic_BYPASS_payload_address = GSharePlugin_logic_mem_write_payload_address;
  assign fetch_logic_ctrls_0_down_GSharePlugin_logic_BYPASS_payload_data_0 = GSharePlugin_logic_mem_write_payload_data_0;
  assign fetch_logic_ctrls_0_down_GSharePlugin_logic_BYPASS_payload_data_1 = GSharePlugin_logic_mem_write_payload_data_1;
  assign fetch_logic_ctrls_0_down_GSharePlugin_logic_BYPASS_payload_data_2 = GSharePlugin_logic_mem_write_payload_data_2;
  assign fetch_logic_ctrls_0_down_GSharePlugin_logic_BYPASS_payload_data_3 = GSharePlugin_logic_mem_write_payload_data_3;
  assign _zz_GSharePlugin_logic_readRsp_readed_0_0 = fetch_logic_ctrls_0_down_GSharePlugin_logic_HASH;
  assign _zz_GSharePlugin_logic_readRsp_readed_0_0_1 = GSharePlugin_logic_mem_banks_0_spinal_port1;
  assign GSharePlugin_logic_readRsp_readed_0_0 = _zz_GSharePlugin_logic_readRsp_readed_0_0_1[1 : 0];
  assign GSharePlugin_logic_readRsp_readed_0_1 = _zz_GSharePlugin_logic_readRsp_readed_0_0_1[3 : 2];
  assign GSharePlugin_logic_readRsp_readed_0_2 = _zz_GSharePlugin_logic_readRsp_readed_0_0_1[5 : 4];
  assign GSharePlugin_logic_readRsp_readed_0_3 = _zz_GSharePlugin_logic_readRsp_readed_0_0_1[7 : 6];
  always @(*) begin
    fetch_logic_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_0 = GSharePlugin_logic_readRsp_readed_0_0;
    if(when_GSharePlugin_l100) begin
      fetch_logic_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_0 = fetch_logic_ctrls_1_down_GSharePlugin_logic_BYPASS_payload_data_0;
    end
  end

  always @(*) begin
    fetch_logic_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_1 = GSharePlugin_logic_readRsp_readed_0_1;
    if(when_GSharePlugin_l100) begin
      fetch_logic_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_1 = fetch_logic_ctrls_1_down_GSharePlugin_logic_BYPASS_payload_data_1;
    end
  end

  always @(*) begin
    fetch_logic_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_2 = GSharePlugin_logic_readRsp_readed_0_2;
    if(when_GSharePlugin_l100) begin
      fetch_logic_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_2 = fetch_logic_ctrls_1_down_GSharePlugin_logic_BYPASS_payload_data_2;
    end
  end

  always @(*) begin
    fetch_logic_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_3 = GSharePlugin_logic_readRsp_readed_0_3;
    if(when_GSharePlugin_l100) begin
      fetch_logic_ctrls_1_down_GSharePlugin_GSHARE_COUNTER_3 = fetch_logic_ctrls_1_down_GSharePlugin_logic_BYPASS_payload_data_3;
    end
  end

  assign when_GSharePlugin_l100 = (fetch_logic_ctrls_1_down_GSharePlugin_logic_BYPASS_valid && (fetch_logic_ctrls_1_down_GSharePlugin_logic_BYPASS_payload_address == fetch_logic_ctrls_1_down_GSharePlugin_logic_HASH));
  always @(*) begin
    BtbPlugin_logic_ras_ptr_pushIt = 1'b0;
    if(BtbPlugin_logic_applyIt_rasLogic_pushValid) begin
      BtbPlugin_logic_ras_ptr_pushIt = 1'b1;
    end
  end

  always @(*) begin
    BtbPlugin_logic_ras_ptr_popIt = 1'b0;
    if(when_BtbPlugin_l246) begin
      BtbPlugin_logic_ras_ptr_popIt = 1'b1;
    end
  end

  always @(*) begin
    BtbPlugin_logic_ras_write_valid = BtbPlugin_logic_ras_ptr_pushIt;
    if(BtbPlugin_logic_initializer_busy) begin
      BtbPlugin_logic_ras_write_valid = 1'b1;
    end
  end

  always @(*) begin
    BtbPlugin_logic_ras_write_payload_address = BtbPlugin_logic_ras_ptr_push;
    if(BtbPlugin_logic_initializer_busy) begin
      BtbPlugin_logic_ras_write_payload_address = BtbPlugin_logic_initializer_counter[1:0];
    end
  end

  always @(*) begin
    BtbPlugin_logic_ras_write_payload_data = 31'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    BtbPlugin_logic_ras_write_payload_data = (_zz_BtbPlugin_logic_ras_write_payload_data >>> 1'd1);
    if(BtbPlugin_logic_initializer_busy) begin
      BtbPlugin_logic_ras_write_payload_data = 31'h0;
    end
  end

  assign BtbPlugin_logic_memDp_wp_valid = BtbPlugin_logic_memWrite_valid;
  assign BtbPlugin_logic_memDp_wp_payload_address = BtbPlugin_logic_memWrite_payload_address;
  assign BtbPlugin_logic_memDp_wp_payload_data_0_hash = BtbPlugin_logic_memWrite_payload_data_0_hash;
  assign BtbPlugin_logic_memDp_wp_payload_data_0_sliceLow = BtbPlugin_logic_memWrite_payload_data_0_sliceLow;
  assign BtbPlugin_logic_memDp_wp_payload_data_0_pcTarget = BtbPlugin_logic_memWrite_payload_data_0_pcTarget;
  assign BtbPlugin_logic_memDp_wp_payload_data_0_isBranch = BtbPlugin_logic_memWrite_payload_data_0_isBranch;
  assign BtbPlugin_logic_memDp_wp_payload_data_0_isPush = BtbPlugin_logic_memWrite_payload_data_0_isPush;
  assign BtbPlugin_logic_memDp_wp_payload_data_0_isPop = BtbPlugin_logic_memWrite_payload_data_0_isPop;
  assign BtbPlugin_logic_memDp_wp_payload_data_1_hash = BtbPlugin_logic_memWrite_payload_data_1_hash;
  assign BtbPlugin_logic_memDp_wp_payload_data_1_sliceLow = BtbPlugin_logic_memWrite_payload_data_1_sliceLow;
  assign BtbPlugin_logic_memDp_wp_payload_data_1_pcTarget = BtbPlugin_logic_memWrite_payload_data_1_pcTarget;
  assign BtbPlugin_logic_memDp_wp_payload_data_1_isBranch = BtbPlugin_logic_memWrite_payload_data_1_isBranch;
  assign BtbPlugin_logic_memDp_wp_payload_data_1_isPush = BtbPlugin_logic_memWrite_payload_data_1_isPush;
  assign BtbPlugin_logic_memDp_wp_payload_data_1_isPop = BtbPlugin_logic_memWrite_payload_data_1_isPop;
  assign BtbPlugin_logic_memDp_wp_payload_mask = BtbPlugin_logic_memWrite_payload_mask;
  assign _zz_BtbPlugin_logic_memDp_rp_rsp_0_hash = BtbPlugin_logic_mem_spinal_port1;
  assign _zz_BtbPlugin_logic_memDp_rp_rsp_0_hash_1 = _zz_BtbPlugin_logic_memDp_rp_rsp_0_hash[50 : 0];
  assign _zz_BtbPlugin_logic_memDp_rp_rsp_1_hash = _zz_BtbPlugin_logic_memDp_rp_rsp_0_hash[101 : 51];
  assign BtbPlugin_logic_memDp_rp_rsp_0_hash = _zz_BtbPlugin_logic_memDp_rp_rsp_0_hash_1[15 : 0];
  assign BtbPlugin_logic_memDp_rp_rsp_0_sliceLow = _zz_BtbPlugin_logic_memDp_rp_rsp_0_hash_1[16 : 16];
  assign BtbPlugin_logic_memDp_rp_rsp_0_pcTarget = _zz_BtbPlugin_logic_memDp_rp_rsp_0_hash_1[47 : 17];
  assign BtbPlugin_logic_memDp_rp_rsp_0_isBranch = _zz_BtbPlugin_logic_memDp_rp_rsp_0_hash_1[48];
  assign BtbPlugin_logic_memDp_rp_rsp_0_isPush = _zz_BtbPlugin_logic_memDp_rp_rsp_0_hash_1[49];
  assign BtbPlugin_logic_memDp_rp_rsp_0_isPop = _zz_BtbPlugin_logic_memDp_rp_rsp_0_hash_1[50];
  assign BtbPlugin_logic_memDp_rp_rsp_1_hash = _zz_BtbPlugin_logic_memDp_rp_rsp_1_hash[15 : 0];
  assign BtbPlugin_logic_memDp_rp_rsp_1_sliceLow = _zz_BtbPlugin_logic_memDp_rp_rsp_1_hash[16 : 16];
  assign BtbPlugin_logic_memDp_rp_rsp_1_pcTarget = _zz_BtbPlugin_logic_memDp_rp_rsp_1_hash[47 : 17];
