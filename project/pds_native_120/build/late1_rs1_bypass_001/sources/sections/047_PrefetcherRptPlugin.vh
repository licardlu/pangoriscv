  always @(*) begin
    PrefetcherRptPlugin_logic_storage_write_payload_data_tag = PrefetcherRptPlugin_logic_pip_node_2_ENTRY_tag;
    if(when_Prefetcher_l203) begin
      if(when_Prefetcher_l204) begin
        if(!when_Prefetcher_l205) begin
          PrefetcherRptPlugin_logic_storage_write_payload_data_tag = PrefetcherRptPlugin_logic_pip_node_2_PROBE_pc[22 : 8];
        end
      end
    end
    if(PrefetcherRptPlugin_logic_initializer_busy) begin
      PrefetcherRptPlugin_logic_storage_write_payload_data_tag = _zz_PrefetcherRptPlugin_logic_storage_write_payload_data_tag[14 : 0];
    end
  end

  always @(*) begin
    PrefetcherRptPlugin_logic_storage_write_payload_data_address = PrefetcherRptPlugin_logic_pip_node_2_PROBE_address[15:0];
    if(PrefetcherRptPlugin_logic_initializer_busy) begin
      PrefetcherRptPlugin_logic_storage_write_payload_data_address = _zz_PrefetcherRptPlugin_logic_storage_write_payload_data_tag[30 : 15];
    end
  end

  always @(*) begin
    PrefetcherRptPlugin_logic_storage_write_payload_data_stride = ((PrefetcherRptPlugin_logic_pip_node_2_ENTRY_score < 5'h03) ? PrefetcherRptPlugin_logic_pip_node_2_STRIDE : PrefetcherRptPlugin_logic_pip_node_2_ENTRY_stride);
    if(when_Prefetcher_l203) begin
      if(when_Prefetcher_l204) begin
        if(!when_Prefetcher_l205) begin
          PrefetcherRptPlugin_logic_storage_write_payload_data_stride = 12'h0;
        end
      end
    end
    if(PrefetcherRptPlugin_logic_initializer_busy) begin
      PrefetcherRptPlugin_logic_storage_write_payload_data_stride = _zz_PrefetcherRptPlugin_logic_storage_write_payload_data_tag[42 : 31];
    end
  end

  always @(*) begin
    PrefetcherRptPlugin_logic_storage_write_payload_data_score = PrefetcherRptPlugin_logic_onCtrl_score;
    if(when_Prefetcher_l203) begin
      if(when_Prefetcher_l204) begin
        if(!when_Prefetcher_l205) begin
          PrefetcherRptPlugin_logic_storage_write_payload_data_score = 5'h0;
        end
      end
    end
    if(PrefetcherRptPlugin_logic_initializer_busy) begin
      PrefetcherRptPlugin_logic_storage_write_payload_data_score = _zz_PrefetcherRptPlugin_logic_storage_write_payload_data_tag[47 : 43];
    end
  end

  assign PrefetcherRptPlugin_logic_onCtrl_unfiltred_fire = (PrefetcherRptPlugin_logic_onCtrl_unfiltred_valid && PrefetcherRptPlugin_logic_onCtrl_unfiltred_ready);
  always @(*) begin
    PrefetcherRptPlugin_logic_storage_write_payload_data_advance = (PrefetcherRptPlugin_logic_onCtrl_unfiltred_fire ? PrefetcherRptPlugin_logic_onCtrl_unfiltred_payload_to : PrefetcherRptPlugin_logic_onCtrl_advanceSubed);
    if(when_Prefetcher_l203) begin
      if(when_Prefetcher_l204) begin
        if(!when_Prefetcher_l205) begin
          PrefetcherRptPlugin_logic_storage_write_payload_data_advance = 3'b000;
        end
      end
    end
    if(PrefetcherRptPlugin_logic_initializer_busy) begin
      PrefetcherRptPlugin_logic_storage_write_payload_data_advance = _zz_PrefetcherRptPlugin_logic_storage_write_payload_data_tag[50 : 48];
    end
  end

  always @(*) begin
    PrefetcherRptPlugin_logic_storage_write_payload_data_missed = (PrefetcherRptPlugin_logic_pip_node_2_PROBE_miss || (PrefetcherRptPlugin_logic_pip_node_2_ENTRY_missed && PrefetcherRptPlugin_logic_pip_node_2_STRIDE_HIT));
    if(PrefetcherRptPlugin_logic_initializer_busy) begin
      PrefetcherRptPlugin_logic_storage_write_payload_data_missed = _zz_PrefetcherRptPlugin_logic_storage_write_payload_data_tag[51];
    end
  end

  assign PrefetcherRptPlugin_logic_onCtrl_unfiltred_valid = (((PrefetcherRptPlugin_logic_pip_node_2_isFiring && PrefetcherRptPlugin_logic_onCtrl_orderAsk) && (! PrefetcherRptPlugin_logic_pip_node_2_PROBE_prefetchFailed)) && PrefetcherRptPlugin_logic_storage_write_payload_data_missed);
  assign PrefetcherRptPlugin_logic_onCtrl_unfiltred_payload_address = PrefetcherRptPlugin_logic_pip_node_2_PROBE_address;
  assign PrefetcherRptPlugin_logic_onCtrl_unfiltred_payload_unique = PrefetcherRptPlugin_logic_pip_node_2_PROBE_store;
  assign PrefetcherRptPlugin_logic_onCtrl_unfiltred_payload_from = (PrefetcherRptPlugin_logic_pip_node_2_PROBE_miss ? 3'b000 : _zz_PrefetcherRptPlugin_logic_onCtrl_unfiltred_payload_from);
  assign _zz_PrefetcherRptPlugin_logic_onCtrl_unfiltred_payload_to = 3'b100;
  assign PrefetcherRptPlugin_logic_onCtrl_unfiltred_payload_to = _zz_PrefetcherRptPlugin_logic_onCtrl_unfiltred_payload_to_1[2:0];
  assign _zz_PrefetcherRptPlugin_logic_onCtrl_unfiltred_payload_stride = 7'h40;
  assign _zz_PrefetcherRptPlugin_logic_onCtrl_unfiltred_payload_stride_1 = 8'h40;
  assign PrefetcherRptPlugin_logic_onCtrl_unfiltred_payload_stride = (PrefetcherRptPlugin_logic_pip_node_2_ENTRY_stride[11] ? _zz_PrefetcherRptPlugin_logic_onCtrl_unfiltred_payload_stride_2 : _zz_PrefetcherRptPlugin_logic_onCtrl_unfiltred_payload_stride_5);
  assign when_Prefetcher_l203 = (! PrefetcherRptPlugin_logic_pip_node_2_TAG_HIT);
  assign when_Prefetcher_l204 = ($signed(PrefetcherRptPlugin_logic_pip_node_2_STRIDE) != $signed(12'h0));
  assign when_Prefetcher_l205 = (PrefetcherRptPlugin_logic_pip_node_2_ENTRY_score != 5'h0);
  assign when_Prefetcher_l215 = (! PrefetcherRptPlugin_logic_pip_node_2_STRIDE_HIT);
  assign when_Prefetcher_l223 = ((PrefetcherRptPlugin_logic_onCtrl_advanceSubed < 3'b100) && (_zz_when_Prefetcher_l223 < PrefetcherRptPlugin_logic_onCtrl_advanceAllowed));
  assign PrefetcherRptPlugin_logic_initializer_busy = (! PrefetcherRptPlugin_logic_initializer_counter[7]);
  assign _zz_PrefetcherRptPlugin_logic_storage_write_payload_data_tag = 52'h0;
  assign PrefetcherRptPlugin_logic_pip_node_0_isFiring = (PrefetcherRptPlugin_logic_pip_node_0_isValid && PrefetcherRptPlugin_logic_pip_node_0_isReady);
  assign PrefetcherRptPlugin_logic_pip_node_0_isValid = PrefetcherRptPlugin_logic_pip_node_0_valid;
  assign PrefetcherRptPlugin_logic_pip_node_0_isReady = 1'b1;
  assign PrefetcherRptPlugin_logic_pip_node_1_isValid = PrefetcherRptPlugin_logic_pip_node_1_valid;
  assign PrefetcherRptPlugin_logic_pip_node_2_isFiring = (PrefetcherRptPlugin_logic_pip_node_2_isValid && PrefetcherRptPlugin_logic_pip_node_2_isReady);
  assign PrefetcherRptPlugin_logic_pip_node_2_isValid = PrefetcherRptPlugin_logic_pip_node_2_valid;
  assign PrefetcherRptPlugin_logic_pip_node_2_isReady = 1'b1;
  assign LsuTileLinkPlugin_logic_bridge_cmdHash = LsuPlugin_logic_bus_cmd_payload_address[9 : 2];
  assign LsuTileLinkPlugin_logic_bridge_down_a_valid = LsuPlugin_logic_bus_cmd_valid;
  assign LsuPlugin_logic_bus_cmd_ready = LsuTileLinkPlugin_logic_bridge_down_a_ready;
  assign _zz_LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode = (LsuPlugin_logic_bus_cmd_payload_write ? A_PUT_FULL_DATA : A_GET);
  assign LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode = _zz_LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode;
  assign LsuTileLinkPlugin_logic_bridge_down_a_payload_param = 3'b000;
  assign LsuTileLinkPlugin_logic_bridge_down_a_payload_address = LsuPlugin_logic_bus_cmd_payload_address;
  assign LsuTileLinkPlugin_logic_bridge_down_a_payload_size = LsuPlugin_logic_bus_cmd_payload_size;
  assign LsuTileLinkPlugin_logic_bridge_down_a_payload_mask = LsuPlugin_logic_bus_cmd_payload_mask;
  assign LsuTileLinkPlugin_logic_bridge_down_a_payload_data = LsuPlugin_logic_bus_cmd_payload_data;
  assign LsuTileLinkPlugin_logic_bridge_down_a_payload_corrupt = 1'b0;
  assign LsuTileLinkPlugin_logic_bridge_down_d_ready = 1'b1;
  assign LsuPlugin_logic_bus_rsp_valid = LsuTileLinkPlugin_logic_bridge_down_d_valid;
  assign LsuPlugin_logic_bus_rsp_payload_error = LsuTileLinkPlugin_logic_bridge_down_d_payload_denied;
  assign LsuPlugin_logic_bus_rsp_payload_data = LsuTileLinkPlugin_logic_bridge_down_d_payload_data;
  assign when_WhiteboxerPlugin_l46 = (fetch_logic_ctrls_0_down_isReady || fetch_logic_ctrls_0_down_isCancel);
  assign WhiteboxerPlugin_logic_fetchs_0_fire = (fetch_logic_ctrls_0_down_isValid && (! fetch_logic_ctrls_0_down_isValid_regNext));
  assign WhiteboxerPlugin_logic_fetchs_0_fetchId = fetch_logic_ctrls_0_down_Fetch_ID;
  assign when_WhiteboxerPlugin_l46_1 = (fetch_logic_ctrls_1_down_isReady || fetch_logic_ctrls_1_down_isCancel);
  assign WhiteboxerPlugin_logic_fetchs_1_fire = (fetch_logic_ctrls_1_down_isValid && (! fetch_logic_ctrls_1_down_isValid_regNext));
  assign WhiteboxerPlugin_logic_fetchs_1_fetchId = fetch_logic_ctrls_1_down_Fetch_ID;
  assign when_WhiteboxerPlugin_l46_2 = (fetch_logic_ctrls_2_down_isReady || fetch_logic_ctrls_2_down_isCancel);
  assign WhiteboxerPlugin_logic_fetchs_2_fire = (fetch_logic_ctrls_2_down_isValid && (! fetch_logic_ctrls_2_down_isValid_regNext));
  assign WhiteboxerPlugin_logic_fetchs_2_fetchId = fetch_logic_ctrls_2_down_Fetch_ID;
  assign WhiteboxerPlugin_logic_decodes_0_fire = ((decode_ctrls_0_up_LANE_SEL_0 && decode_ctrls_0_up_isReady) && (! decode_ctrls_0_lane0_upIsCancel));
  assign when_CtrlLaneApi_l50_2 = (decode_ctrls_0_up_isReady || decode_ctrls_0_lane0_upIsCancel);
  assign WhiteboxerPlugin_logic_decodes_0_spawn = (decode_ctrls_0_up_LANE_SEL_0 && (! decode_ctrls_0_up_LANE_SEL_0_regNext));
  assign WhiteboxerPlugin_logic_decodes_0_pc = _zz_WhiteboxerPlugin_logic_decodes_0_pc;
  assign WhiteboxerPlugin_logic_decodes_0_fetchId = decode_ctrls_0_down_Fetch_ID_0;
  assign WhiteboxerPlugin_logic_decodes_0_decodeId = decode_ctrls_0_down_Decode_DOP_ID_0;
  assign WhiteboxerPlugin_logic_decodes_1_fire = ((decode_ctrls_1_up_LANE_SEL_0 && decode_ctrls_1_up_isReady) && (! decode_ctrls_1_lane0_upIsCancel));
  assign when_CtrlLaneApi_l50_3 = (decode_ctrls_1_up_isReady || decode_ctrls_1_lane0_upIsCancel);
  assign WhiteboxerPlugin_logic_decodes_1_spawn = (decode_ctrls_1_up_LANE_SEL_0 && (! decode_ctrls_1_up_LANE_SEL_0_regNext_1));
  assign WhiteboxerPlugin_logic_decodes_1_pc = _zz_WhiteboxerPlugin_logic_decodes_1_pc;
  assign WhiteboxerPlugin_logic_decodes_1_fetchId = decode_ctrls_1_down_Fetch_ID_0;
  assign WhiteboxerPlugin_logic_decodes_1_decodeId = decode_ctrls_1_down_Decode_DOP_ID_0;
  assign WhiteboxerPlugin_logic_decodes_2_fire = ((decode_ctrls_0_up_LANE_SEL_1 && decode_ctrls_0_up_isReady) && (! decode_ctrls_0_lane1_upIsCancel));
  assign when_CtrlLaneApi_l50_4 = (decode_ctrls_0_up_isReady || decode_ctrls_0_lane1_upIsCancel);
  assign WhiteboxerPlugin_logic_decodes_2_spawn = (decode_ctrls_0_up_LANE_SEL_1 && (! decode_ctrls_0_up_LANE_SEL_1_regNext));
  assign WhiteboxerPlugin_logic_decodes_2_pc = _zz_WhiteboxerPlugin_logic_decodes_2_pc;
  assign WhiteboxerPlugin_logic_decodes_2_fetchId = decode_ctrls_0_down_Fetch_ID_1;
  assign WhiteboxerPlugin_logic_decodes_2_decodeId = decode_ctrls_0_down_Decode_DOP_ID_1;
  assign WhiteboxerPlugin_logic_decodes_3_fire = ((decode_ctrls_1_up_LANE_SEL_1 && decode_ctrls_1_up_isReady) && (! decode_ctrls_1_lane1_upIsCancel));
  assign when_CtrlLaneApi_l50_5 = (decode_ctrls_1_up_isReady || decode_ctrls_1_lane1_upIsCancel);
  assign WhiteboxerPlugin_logic_decodes_3_spawn = (decode_ctrls_1_up_LANE_SEL_1 && (! decode_ctrls_1_up_LANE_SEL_1_regNext_1));
  assign WhiteboxerPlugin_logic_decodes_3_pc = _zz_WhiteboxerPlugin_logic_decodes_3_pc;
  assign WhiteboxerPlugin_logic_decodes_3_fetchId = decode_ctrls_1_down_Fetch_ID_1;
  assign WhiteboxerPlugin_logic_decodes_3_decodeId = decode_ctrls_1_down_Decode_DOP_ID_1;
  assign when_CtrlLaneApi_l50_6 = (decode_ctrls_1_up_isReady || decode_ctrls_1_lane0_upIsCancel);
  assign WhiteboxerPlugin_logic_serializeds_0_fire = (decode_ctrls_1_up_LANE_SEL_0 && (! decode_ctrls_1_up_LANE_SEL_0_regNext_2));
  assign WhiteboxerPlugin_logic_serializeds_0_decodeId = decode_ctrls_1_down_Decode_DOP_ID_0;
  assign WhiteboxerPlugin_logic_serializeds_0_microOpId = decode_ctrls_1_down_Decode_UOP_ID_0;
  assign WhiteboxerPlugin_logic_serializeds_0_microOp = decode_ctrls_1_down_Decode_UOP_0;
  assign when_CtrlLaneApi_l50_7 = (decode_ctrls_1_up_isReady || decode_ctrls_1_lane1_upIsCancel);
  assign WhiteboxerPlugin_logic_serializeds_1_fire = (decode_ctrls_1_up_LANE_SEL_1 && (! decode_ctrls_1_up_LANE_SEL_1_regNext_2));
  assign WhiteboxerPlugin_logic_serializeds_1_decodeId = decode_ctrls_1_down_Decode_DOP_ID_1;
  assign WhiteboxerPlugin_logic_serializeds_1_microOpId = decode_ctrls_1_down_Decode_UOP_ID_1;
  assign WhiteboxerPlugin_logic_serializeds_1_microOp = decode_ctrls_1_down_Decode_UOP_1;
  assign when_CtrlLaneApi_l50_8 = (execute_ctrl0_down_isReady || execute_lane0_ctrls_0_downIsCancel);
  assign WhiteboxerPlugin_logic_dispatches_0_fire = (execute_ctrl0_down_LANE_SEL_lane0 && (! execute_ctrl0_down_LANE_SEL_lane0_regNext));
  assign WhiteboxerPlugin_logic_dispatches_0_microOpId = execute_ctrl0_down_Decode_UOP_ID_lane0;
  assign when_CtrlLaneApi_l50_9 = (execute_ctrl0_down_isReady || execute_lane1_ctrls_0_downIsCancel);
  assign WhiteboxerPlugin_logic_dispatches_1_fire = (execute_ctrl0_down_LANE_SEL_lane1 && (! execute_ctrl0_down_LANE_SEL_lane1_regNext));
  assign WhiteboxerPlugin_logic_dispatches_1_microOpId = execute_ctrl0_down_Decode_UOP_ID_lane1;
  always @(*) begin
    execute_lane1_bypasser_integer_RS1_bypassEnables[0] = (((execute_ctrl2_up_LANE_SEL_lane0 && execute_ctrl2_up_RD_ENABLE_lane0) && (execute_ctrl2_down_RD_PHYS_lane0 == execute_ctrl1_down_RS1_PHYS_lane1)) && 1'b1);
    execute_lane1_bypasser_integer_RS1_bypassEnables[1] = (((execute_ctrl2_up_LANE_SEL_lane1 && execute_ctrl2_up_RD_ENABLE_lane1) && (execute_ctrl2_down_RD_PHYS_lane1 == execute_ctrl1_down_RS1_PHYS_lane1)) && 1'b1);
    execute_lane1_bypasser_integer_RS1_bypassEnables[2] = (((execute_ctrl3_up_LANE_SEL_lane0 && execute_ctrl3_up_RD_ENABLE_lane0) && (execute_ctrl3_down_RD_PHYS_lane0 == execute_ctrl1_down_RS1_PHYS_lane1)) && 1'b1);
    execute_lane1_bypasser_integer_RS1_bypassEnables[3] = (((execute_ctrl3_up_LANE_SEL_lane1 && execute_ctrl3_up_RD_ENABLE_lane1) && (execute_ctrl3_down_RD_PHYS_lane1 == execute_ctrl1_down_RS1_PHYS_lane1)) && 1'b1);
    execute_lane1_bypasser_integer_RS1_bypassEnables[4] = (((execute_ctrl4_up_LANE_SEL_lane0 && execute_ctrl4_up_RD_ENABLE_lane0) && (execute_ctrl4_down_RD_PHYS_lane0 == execute_ctrl1_down_RS1_PHYS_lane1)) && 1'b1);
    execute_lane1_bypasser_integer_RS1_bypassEnables[5] = (((execute_ctrl4_up_LANE_SEL_lane1 && execute_ctrl4_up_RD_ENABLE_lane1) && (execute_ctrl4_down_RD_PHYS_lane1 == execute_ctrl1_down_RS1_PHYS_lane1)) && 1'b1);
    execute_lane1_bypasser_integer_RS1_bypassEnables[6] = (((execute_ctrl5_up_LANE_SEL_lane0 && execute_ctrl5_up_RD_ENABLE_lane0) && (execute_ctrl5_down_RD_PHYS_lane0 == execute_ctrl1_down_RS1_PHYS_lane1)) && 1'b1);
    execute_lane1_bypasser_integer_RS1_bypassEnables[7] = (((execute_ctrl5_up_LANE_SEL_lane1 && execute_ctrl5_up_RD_ENABLE_lane1) && (execute_ctrl5_down_RD_PHYS_lane1 == execute_ctrl1_down_RS1_PHYS_lane1)) && 1'b1);
    execute_lane1_bypasser_integer_RS1_bypassEnables[8] = 1'b1;
  end

  assign _zz_execute_lane1_bypasser_integer_RS1_bypassEnables_bools_0 = execute_lane1_bypasser_integer_RS1_bypassEnables;
  assign execute_lane1_bypasser_integer_RS1_bypassEnables_bools_0 = _zz_execute_lane1_bypasser_integer_RS1_bypassEnables_bools_0[0];
  assign execute_lane1_bypasser_integer_RS1_bypassEnables_bools_1 = _zz_execute_lane1_bypasser_integer_RS1_bypassEnables_bools_0[1];
  assign execute_lane1_bypasser_integer_RS1_bypassEnables_bools_2 = _zz_execute_lane1_bypasser_integer_RS1_bypassEnables_bools_0[2];
  assign execute_lane1_bypasser_integer_RS1_bypassEnables_bools_3 = _zz_execute_lane1_bypasser_integer_RS1_bypassEnables_bools_0[3];
  assign execute_lane1_bypasser_integer_RS1_bypassEnables_bools_4 = _zz_execute_lane1_bypasser_integer_RS1_bypassEnables_bools_0[4];
  assign execute_lane1_bypasser_integer_RS1_bypassEnables_bools_5 = _zz_execute_lane1_bypasser_integer_RS1_bypassEnables_bools_0[5];
  assign execute_lane1_bypasser_integer_RS1_bypassEnables_bools_6 = _zz_execute_lane1_bypasser_integer_RS1_bypassEnables_bools_0[6];
  assign execute_lane1_bypasser_integer_RS1_bypassEnables_bools_7 = _zz_execute_lane1_bypasser_integer_RS1_bypassEnables_bools_0[7];
  assign execute_lane1_bypasser_integer_RS1_bypassEnables_bools_8 = _zz_execute_lane1_bypasser_integer_RS1_bypassEnables_bools_0[8];
  always @(*) begin
    _zz_execute_lane1_bypasser_integer_RS1_sel[0] = (execute_lane1_bypasser_integer_RS1_bypassEnables_bools_0 && (! 1'b0));
    _zz_execute_lane1_bypasser_integer_RS1_sel[1] = (execute_lane1_bypasser_integer_RS1_bypassEnables_bools_1 && (! execute_lane1_bypasser_integer_RS1_bypassEnables_bools_0));
    _zz_execute_lane1_bypasser_integer_RS1_sel[2] = (execute_lane1_bypasser_integer_RS1_bypassEnables_bools_2 && (! execute_lane1_bypasser_integer_RS1_bypassEnables_range_0_to_1));
    _zz_execute_lane1_bypasser_integer_RS1_sel[3] = (execute_lane1_bypasser_integer_RS1_bypassEnables_bools_3 && (! execute_lane1_bypasser_integer_RS1_bypassEnables_range_0_to_2));
    _zz_execute_lane1_bypasser_integer_RS1_sel[4] = (execute_lane1_bypasser_integer_RS1_bypassEnables_bools_4 && (! execute_lane1_bypasser_integer_RS1_bypassEnables_range_0_to_3));
    _zz_execute_lane1_bypasser_integer_RS1_sel[5] = (execute_lane1_bypasser_integer_RS1_bypassEnables_bools_5 && (! (execute_lane1_bypasser_integer_RS1_bypassEnables_bools_4 || execute_lane1_bypasser_integer_RS1_bypassEnables_range_0_to_3)));
    _zz_execute_lane1_bypasser_integer_RS1_sel[6] = (execute_lane1_bypasser_integer_RS1_bypassEnables_bools_6 && (! (execute_lane1_bypasser_integer_RS1_bypassEnables_range_4_to_5 || execute_lane1_bypasser_integer_RS1_bypassEnables_range_0_to_3)));
    _zz_execute_lane1_bypasser_integer_RS1_sel[7] = (execute_lane1_bypasser_integer_RS1_bypassEnables_bools_7 && (! (execute_lane1_bypasser_integer_RS1_bypassEnables_range_4_to_6 || execute_lane1_bypasser_integer_RS1_bypassEnables_range_0_to_3)));
    _zz_execute_lane1_bypasser_integer_RS1_sel[8] = (execute_lane1_bypasser_integer_RS1_bypassEnables_bools_8 && (! (execute_lane1_bypasser_integer_RS1_bypassEnables_range_4_to_7 || execute_lane1_bypasser_integer_RS1_bypassEnables_range_0_to_3)));
  end

  assign execute_lane1_bypasser_integer_RS1_bypassEnables_range_0_to_1 = (|{execute_lane1_bypasser_integer_RS1_bypassEnables_bools_1,execute_lane1_bypasser_integer_RS1_bypassEnables_bools_0});
  assign execute_lane1_bypasser_integer_RS1_bypassEnables_range_0_to_2 = (|{execute_lane1_bypasser_integer_RS1_bypassEnables_bools_2,execute_lane1_bypasser_integer_RS1_bypassEnables_bools_1,execute_lane1_bypasser_integer_RS1_bypassEnables_bools_0});
  assign execute_lane1_bypasser_integer_RS1_bypassEnables_range_0_to_3 = (|{execute_lane1_bypasser_integer_RS1_bypassEnables_bools_3,execute_lane1_bypasser_integer_RS1_bypassEnables_bools_2,execute_lane1_bypasser_integer_RS1_bypassEnables_bools_1,execute_lane1_bypasser_integer_RS1_bypassEnables_bools_0});
  assign execute_lane1_bypasser_integer_RS1_bypassEnables_range_4_to_5 = (|{execute_lane1_bypasser_integer_RS1_bypassEnables_bools_5,execute_lane1_bypasser_integer_RS1_bypassEnables_bools_4});
  assign execute_lane1_bypasser_integer_RS1_bypassEnables_range_4_to_6 = (|{execute_lane1_bypasser_integer_RS1_bypassEnables_bools_6,execute_lane1_bypasser_integer_RS1_bypassEnables_bools_5,execute_lane1_bypasser_integer_RS1_bypassEnables_bools_4});
  assign execute_lane1_bypasser_integer_RS1_bypassEnables_range_4_to_7 = (|{execute_lane1_bypasser_integer_RS1_bypassEnables_bools_7,execute_lane1_bypasser_integer_RS1_bypassEnables_bools_6,execute_lane1_bypasser_integer_RS1_bypassEnables_bools_5,execute_lane1_bypasser_integer_RS1_bypassEnables_bools_4});
  assign execute_lane1_bypasser_integer_RS1_sel = _zz_execute_lane1_bypasser_integer_RS1_sel;
  assign _zz_execute_ctrl1_down_integer_RS1_lane1 = execute_lane1_bypasser_integer_RS1_sel[8 : 1];
  always @(*) begin
    _zz_execute_ctrl1_down_integer_RS1_lane1_1 = ((((_zz__zz_execute_ctrl1_down_integer_RS1_lane1_1 ? execute_ctrl2_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : _zz__zz_execute_ctrl1_down_integer_RS1_lane1_1_1) | (_zz__zz_execute_ctrl1_down_integer_RS1_lane1_1_2 ? execute_ctrl3_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : _zz__zz_execute_ctrl1_down_integer_RS1_lane1_1_3)) | ((_zz__zz_execute_ctrl1_down_integer_RS1_lane1_1_4 ? execute_ctrl3_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : _zz__zz_execute_ctrl1_down_integer_RS1_lane1_1_5) | (_zz__zz_execute_ctrl1_down_integer_RS1_lane1_1_6 ? execute_ctrl4_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : _zz__zz_execute_ctrl1_down_integer_RS1_lane1_1_7))) | (((_zz__zz_execute_ctrl1_down_integer_RS1_lane1_1_8 ? execute_ctrl4_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : _zz__zz_execute_ctrl1_down_integer_RS1_lane1_1_9) | (_zz__zz_execute_ctrl1_down_integer_RS1_lane1_1_10 ? execute_ctrl5_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : _zz__zz_execute_ctrl1_down_integer_RS1_lane1_1_11)) | ((_zz__zz_execute_ctrl1_down_integer_RS1_lane1_1_12 ? execute_ctrl5_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : _zz__zz_execute_ctrl1_down_integer_RS1_lane1_1_13) | (_zz__zz_execute_ctrl1_down_integer_RS1_lane1_1_14 ? execute_lane1_bypasser_integer_RS1_port_data : _zz__zz_execute_ctrl1_down_integer_RS1_lane1_1_15))));
    if(when_ExecuteLanePlugin_l196_2) begin
      _zz_execute_ctrl1_down_integer_RS1_lane1_1 = execute_ctrl2_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0;
    end
  end

  assign execute_ctrl1_down_integer_RS1_lane1 = _zz_execute_ctrl1_down_integer_RS1_lane1_1;
  assign when_ExecuteLanePlugin_l196_2 = execute_lane1_bypasser_integer_RS1_sel[0];
  assign execute_lane1_bypasser_integer_RS1_along_bypasses_0_checks_0_selfHit = (((execute_ctrl4_up_LANE_SEL_lane0 && execute_ctrl4_up_RD_ENABLE_lane0) && (execute_ctrl4_down_RD_PHYS_lane0 == execute_ctrl2_down_RS1_PHYS_lane1)) && 1'b1);
  assign execute_lane1_bypasser_integer_RS1_along_bypasses_0_checks_0_youngerHits_0 = (((execute_ctrl3_up_LANE_SEL_lane0 && execute_ctrl3_up_RD_ENABLE_lane0) && (execute_ctrl3_down_RD_PHYS_lane0 == execute_ctrl2_down_RS1_PHYS_lane1)) && 1'b1);
  assign execute_lane1_bypasser_integer_RS1_along_bypasses_0_checks_0_youngerHits_1 = (((execute_ctrl3_up_LANE_SEL_lane1 && execute_ctrl3_up_RD_ENABLE_lane1) && (execute_ctrl3_down_RD_PHYS_lane1 == execute_ctrl2_down_RS1_PHYS_lane1)) && 1'b1);
  assign execute_lane1_bypasser_integer_RS1_along_bypasses_0_checks_0_hit = (execute_lane1_bypasser_integer_RS1_along_bypasses_0_checks_0_selfHit && (! (|{execute_lane1_bypasser_integer_RS1_along_bypasses_0_checks_0_youngerHits_1,execute_lane1_bypasser_integer_RS1_along_bypasses_0_checks_0_youngerHits_0})));
  assign execute_lane1_bypasser_integer_RS1_along_bypasses_0_checks_1_selfHit = (((execute_ctrl3_up_LANE_SEL_lane0 && execute_ctrl3_up_RD_ENABLE_lane0) && (execute_ctrl3_down_RD_PHYS_lane0 == execute_ctrl2_down_RS1_PHYS_lane1)) && 1'b1);
  assign execute_lane1_bypasser_integer_RS1_along_bypasses_0_checks_1_hit = (execute_lane1_bypasser_integer_RS1_along_bypasses_0_checks_1_selfHit && (! 1'b0));
  assign execute_lane1_bypasser_integer_RS1_along_bypasses_0_checks_2_selfHit = (((execute_ctrl4_up_LANE_SEL_lane1 && execute_ctrl4_up_RD_ENABLE_lane1) && (execute_ctrl4_down_RD_PHYS_lane1 == execute_ctrl2_down_RS1_PHYS_lane1)) && 1'b1);
  assign execute_lane1_bypasser_integer_RS1_along_bypasses_0_checks_2_youngerHits_0 = (((execute_ctrl3_up_LANE_SEL_lane0 && execute_ctrl3_up_RD_ENABLE_lane0) && (execute_ctrl3_down_RD_PHYS_lane0 == execute_ctrl2_down_RS1_PHYS_lane1)) && 1'b1);
  assign execute_lane1_bypasser_integer_RS1_along_bypasses_0_checks_2_youngerHits_1 = (((execute_ctrl3_up_LANE_SEL_lane1 && execute_ctrl3_up_RD_ENABLE_lane1) && (execute_ctrl3_down_RD_PHYS_lane1 == execute_ctrl2_down_RS1_PHYS_lane1)) && 1'b1);
  assign execute_lane1_bypasser_integer_RS1_along_bypasses_0_checks_2_hit = (execute_lane1_bypasser_integer_RS1_along_bypasses_0_checks_2_selfHit && (! (|{execute_lane1_bypasser_integer_RS1_along_bypasses_0_checks_2_youngerHits_1,execute_lane1_bypasser_integer_RS1_along_bypasses_0_checks_2_youngerHits_0})));
  assign execute_lane1_bypasser_integer_RS1_along_bypasses_0_hits = {execute_lane1_bypasser_integer_RS1_along_bypasses_0_checks_2_hit,execute_lane1_bypasser_integer_RS1_along_bypasses_0_checks_1_hit,execute_lane1_bypasser_integer_RS1_along_bypasses_0_checks_0_hit};
  assign _zz_execute_ctrl2_integer_RS1_lane1_bypass = {execute_lane1_bypasser_integer_RS1_along_bypasses_0_hits,(! (|execute_lane1_bypasser_integer_RS1_along_bypasses_0_hits))};
  assign execute_ctrl2_integer_RS1_lane1_bypass = (((_zz_execute_ctrl2_integer_RS1_lane1_bypass[0] ? execute_ctrl2_up_integer_RS1_lane1 : 32'h0) | (_zz_execute_ctrl2_integer_RS1_lane1_bypass[1] ? execute_ctrl4_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : 32'h0)) | ((_zz_execute_ctrl2_integer_RS1_lane1_bypass[2] ? execute_ctrl3_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : 32'h0) | (_zz_execute_ctrl2_integer_RS1_lane1_bypass[3] ? execute_ctrl4_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : 32'h0)));
  assign execute_lane1_bypasser_integer_RS1_along_bypasses_1_checks_0_selfHit = (((execute_ctrl4_up_LANE_SEL_lane0 && execute_ctrl4_up_RD_ENABLE_lane0) && (execute_ctrl4_down_RD_PHYS_lane0 == execute_ctrl3_down_RS1_PHYS_lane1)) && 1'b1);
  assign execute_lane1_bypasser_integer_RS1_along_bypasses_1_checks_0_hit = (execute_lane1_bypasser_integer_RS1_along_bypasses_1_checks_0_selfHit && (! 1'b0));
  assign execute_lane1_bypasser_integer_RS1_along_bypasses_1_checks_1_selfHit = (((execute_ctrl4_up_LANE_SEL_lane1 && execute_ctrl4_up_RD_ENABLE_lane1) && (execute_ctrl4_down_RD_PHYS_lane1 == execute_ctrl3_down_RS1_PHYS_lane1)) && 1'b1);
  assign execute_lane1_bypasser_integer_RS1_along_bypasses_1_checks_1_hit = (execute_lane1_bypasser_integer_RS1_along_bypasses_1_checks_1_selfHit && (! 1'b0));
  assign execute_lane1_bypasser_integer_RS1_along_bypasses_1_hits = {execute_lane1_bypasser_integer_RS1_along_bypasses_1_checks_1_hit,execute_lane1_bypasser_integer_RS1_along_bypasses_1_checks_0_hit};
  assign _zz_execute_ctrl3_integer_RS1_lane1_bypass = {execute_lane1_bypasser_integer_RS1_along_bypasses_1_hits,(! (|execute_lane1_bypasser_integer_RS1_along_bypasses_1_hits))};
  assign execute_ctrl3_integer_RS1_lane1_bypass = (((_zz_execute_ctrl3_integer_RS1_lane1_bypass[0] ? execute_ctrl3_up_integer_RS1_lane1 : 32'h0) | (_zz_execute_ctrl3_integer_RS1_lane1_bypass[1] ? execute_ctrl4_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : 32'h0)) | (_zz_execute_ctrl3_integer_RS1_lane1_bypass[2] ? execute_ctrl4_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : 32'h0));
  assign execute_lane1_bypasser_integer_RS2_port_valid = (! execute_freeze_valid);
  assign execute_lane1_bypasser_integer_RS2_port_address = execute_ctrl0_down_RS2_PHYS_lane1[4 : 0];
  always @(*) begin
    execute_lane1_bypasser_integer_RS2_bypassEnables[0] = (((execute_ctrl2_up_LANE_SEL_lane0 && execute_ctrl2_up_RD_ENABLE_lane0) && (execute_ctrl2_down_RD_PHYS_lane0 == execute_ctrl1_down_RS2_PHYS_lane1)) && 1'b1);
    execute_lane1_bypasser_integer_RS2_bypassEnables[1] = (((execute_ctrl2_up_LANE_SEL_lane1 && execute_ctrl2_up_RD_ENABLE_lane1) && (execute_ctrl2_down_RD_PHYS_lane1 == execute_ctrl1_down_RS2_PHYS_lane1)) && 1'b1);
    execute_lane1_bypasser_integer_RS2_bypassEnables[2] = (((execute_ctrl3_up_LANE_SEL_lane0 && execute_ctrl3_up_RD_ENABLE_lane0) && (execute_ctrl3_down_RD_PHYS_lane0 == execute_ctrl1_down_RS2_PHYS_lane1)) && 1'b1);
    execute_lane1_bypasser_integer_RS2_bypassEnables[3] = (((execute_ctrl3_up_LANE_SEL_lane1 && execute_ctrl3_up_RD_ENABLE_lane1) && (execute_ctrl3_down_RD_PHYS_lane1 == execute_ctrl1_down_RS2_PHYS_lane1)) && 1'b1);
    execute_lane1_bypasser_integer_RS2_bypassEnables[4] = (((execute_ctrl4_up_LANE_SEL_lane0 && execute_ctrl4_up_RD_ENABLE_lane0) && (execute_ctrl4_down_RD_PHYS_lane0 == execute_ctrl1_down_RS2_PHYS_lane1)) && 1'b1);
    execute_lane1_bypasser_integer_RS2_bypassEnables[5] = (((execute_ctrl4_up_LANE_SEL_lane1 && execute_ctrl4_up_RD_ENABLE_lane1) && (execute_ctrl4_down_RD_PHYS_lane1 == execute_ctrl1_down_RS2_PHYS_lane1)) && 1'b1);
    execute_lane1_bypasser_integer_RS2_bypassEnables[6] = (((execute_ctrl5_up_LANE_SEL_lane0 && execute_ctrl5_up_RD_ENABLE_lane0) && (execute_ctrl5_down_RD_PHYS_lane0 == execute_ctrl1_down_RS2_PHYS_lane1)) && 1'b1);
    execute_lane1_bypasser_integer_RS2_bypassEnables[7] = (((execute_ctrl5_up_LANE_SEL_lane1 && execute_ctrl5_up_RD_ENABLE_lane1) && (execute_ctrl5_down_RD_PHYS_lane1 == execute_ctrl1_down_RS2_PHYS_lane1)) && 1'b1);
    execute_lane1_bypasser_integer_RS2_bypassEnables[8] = 1'b1;
  end

  assign _zz_execute_lane1_bypasser_integer_RS2_bypassEnables_bools_0 = execute_lane1_bypasser_integer_RS2_bypassEnables;
  assign execute_lane1_bypasser_integer_RS2_bypassEnables_bools_0 = _zz_execute_lane1_bypasser_integer_RS2_bypassEnables_bools_0[0];
  assign execute_lane1_bypasser_integer_RS2_bypassEnables_bools_1 = _zz_execute_lane1_bypasser_integer_RS2_bypassEnables_bools_0[1];
  assign execute_lane1_bypasser_integer_RS2_bypassEnables_bools_2 = _zz_execute_lane1_bypasser_integer_RS2_bypassEnables_bools_0[2];
  assign execute_lane1_bypasser_integer_RS2_bypassEnables_bools_3 = _zz_execute_lane1_bypasser_integer_RS2_bypassEnables_bools_0[3];
  assign execute_lane1_bypasser_integer_RS2_bypassEnables_bools_4 = _zz_execute_lane1_bypasser_integer_RS2_bypassEnables_bools_0[4];
  assign execute_lane1_bypasser_integer_RS2_bypassEnables_bools_5 = _zz_execute_lane1_bypasser_integer_RS2_bypassEnables_bools_0[5];
  assign execute_lane1_bypasser_integer_RS2_bypassEnables_bools_6 = _zz_execute_lane1_bypasser_integer_RS2_bypassEnables_bools_0[6];
  assign execute_lane1_bypasser_integer_RS2_bypassEnables_bools_7 = _zz_execute_lane1_bypasser_integer_RS2_bypassEnables_bools_0[7];
  assign execute_lane1_bypasser_integer_RS2_bypassEnables_bools_8 = _zz_execute_lane1_bypasser_integer_RS2_bypassEnables_bools_0[8];
  always @(*) begin
    _zz_execute_lane1_bypasser_integer_RS2_sel[0] = (execute_lane1_bypasser_integer_RS2_bypassEnables_bools_0 && (! 1'b0));
    _zz_execute_lane1_bypasser_integer_RS2_sel[1] = (execute_lane1_bypasser_integer_RS2_bypassEnables_bools_1 && (! execute_lane1_bypasser_integer_RS2_bypassEnables_bools_0));
    _zz_execute_lane1_bypasser_integer_RS2_sel[2] = (execute_lane1_bypasser_integer_RS2_bypassEnables_bools_2 && (! execute_lane1_bypasser_integer_RS2_bypassEnables_range_0_to_1));
    _zz_execute_lane1_bypasser_integer_RS2_sel[3] = (execute_lane1_bypasser_integer_RS2_bypassEnables_bools_3 && (! execute_lane1_bypasser_integer_RS2_bypassEnables_range_0_to_2));
    _zz_execute_lane1_bypasser_integer_RS2_sel[4] = (execute_lane1_bypasser_integer_RS2_bypassEnables_bools_4 && (! execute_lane1_bypasser_integer_RS2_bypassEnables_range_0_to_3));
    _zz_execute_lane1_bypasser_integer_RS2_sel[5] = (execute_lane1_bypasser_integer_RS2_bypassEnables_bools_5 && (! (execute_lane1_bypasser_integer_RS2_bypassEnables_bools_4 || execute_lane1_bypasser_integer_RS2_bypassEnables_range_0_to_3)));
    _zz_execute_lane1_bypasser_integer_RS2_sel[6] = (execute_lane1_bypasser_integer_RS2_bypassEnables_bools_6 && (! (execute_lane1_bypasser_integer_RS2_bypassEnables_range_4_to_5 || execute_lane1_bypasser_integer_RS2_bypassEnables_range_0_to_3)));
    _zz_execute_lane1_bypasser_integer_RS2_sel[7] = (execute_lane1_bypasser_integer_RS2_bypassEnables_bools_7 && (! (execute_lane1_bypasser_integer_RS2_bypassEnables_range_4_to_6 || execute_lane1_bypasser_integer_RS2_bypassEnables_range_0_to_3)));
    _zz_execute_lane1_bypasser_integer_RS2_sel[8] = (execute_lane1_bypasser_integer_RS2_bypassEnables_bools_8 && (! (execute_lane1_bypasser_integer_RS2_bypassEnables_range_4_to_7 || execute_lane1_bypasser_integer_RS2_bypassEnables_range_0_to_3)));
  end

  assign execute_lane1_bypasser_integer_RS2_bypassEnables_range_0_to_1 = (|{execute_lane1_bypasser_integer_RS2_bypassEnables_bools_1,execute_lane1_bypasser_integer_RS2_bypassEnables_bools_0});
  assign execute_lane1_bypasser_integer_RS2_bypassEnables_range_0_to_2 = (|{execute_lane1_bypasser_integer_RS2_bypassEnables_bools_2,execute_lane1_bypasser_integer_RS2_bypassEnables_bools_1,execute_lane1_bypasser_integer_RS2_bypassEnables_bools_0});
  assign execute_lane1_bypasser_integer_RS2_bypassEnables_range_0_to_3 = (|{execute_lane1_bypasser_integer_RS2_bypassEnables_bools_3,execute_lane1_bypasser_integer_RS2_bypassEnables_bools_2,execute_lane1_bypasser_integer_RS2_bypassEnables_bools_1,execute_lane1_bypasser_integer_RS2_bypassEnables_bools_0});
  assign execute_lane1_bypasser_integer_RS2_bypassEnables_range_4_to_5 = (|{execute_lane1_bypasser_integer_RS2_bypassEnables_bools_5,execute_lane1_bypasser_integer_RS2_bypassEnables_bools_4});
  assign execute_lane1_bypasser_integer_RS2_bypassEnables_range_4_to_6 = (|{execute_lane1_bypasser_integer_RS2_bypassEnables_bools_6,execute_lane1_bypasser_integer_RS2_bypassEnables_bools_5,execute_lane1_bypasser_integer_RS2_bypassEnables_bools_4});
  assign execute_lane1_bypasser_integer_RS2_bypassEnables_range_4_to_7 = (|{execute_lane1_bypasser_integer_RS2_bypassEnables_bools_7,execute_lane1_bypasser_integer_RS2_bypassEnables_bools_6,execute_lane1_bypasser_integer_RS2_bypassEnables_bools_5,execute_lane1_bypasser_integer_RS2_bypassEnables_bools_4});
  assign execute_lane1_bypasser_integer_RS2_sel = _zz_execute_lane1_bypasser_integer_RS2_sel;
  assign _zz_execute_ctrl1_down_integer_RS2_lane1 = execute_lane1_bypasser_integer_RS2_sel[8 : 1];
  always @(*) begin
    _zz_execute_ctrl1_down_integer_RS2_lane1_1 = ((((_zz__zz_execute_ctrl1_down_integer_RS2_lane1_1 ? execute_ctrl2_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : _zz__zz_execute_ctrl1_down_integer_RS2_lane1_1_1) | (_zz__zz_execute_ctrl1_down_integer_RS2_lane1_1_2 ? execute_ctrl3_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : _zz__zz_execute_ctrl1_down_integer_RS2_lane1_1_3)) | ((_zz__zz_execute_ctrl1_down_integer_RS2_lane1_1_4 ? execute_ctrl3_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : _zz__zz_execute_ctrl1_down_integer_RS2_lane1_1_5) | (_zz__zz_execute_ctrl1_down_integer_RS2_lane1_1_6 ? execute_ctrl4_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : _zz__zz_execute_ctrl1_down_integer_RS2_lane1_1_7))) | (((_zz__zz_execute_ctrl1_down_integer_RS2_lane1_1_8 ? execute_ctrl4_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : _zz__zz_execute_ctrl1_down_integer_RS2_lane1_1_9) | (_zz__zz_execute_ctrl1_down_integer_RS2_lane1_1_10 ? execute_ctrl5_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : _zz__zz_execute_ctrl1_down_integer_RS2_lane1_1_11)) | ((_zz__zz_execute_ctrl1_down_integer_RS2_lane1_1_12 ? execute_ctrl5_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : _zz__zz_execute_ctrl1_down_integer_RS2_lane1_1_13) | (_zz__zz_execute_ctrl1_down_integer_RS2_lane1_1_14 ? execute_lane1_bypasser_integer_RS2_port_data : _zz__zz_execute_ctrl1_down_integer_RS2_lane1_1_15))));
    if(when_ExecuteLanePlugin_l196_3) begin
      _zz_execute_ctrl1_down_integer_RS2_lane1_1 = execute_ctrl2_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0;
    end
  end

  assign execute_ctrl1_down_integer_RS2_lane1 = _zz_execute_ctrl1_down_integer_RS2_lane1_1;
  assign when_ExecuteLanePlugin_l196_3 = execute_lane1_bypasser_integer_RS2_sel[0];
  assign execute_lane1_bypasser_integer_RS2_along_bypasses_0_checks_0_selfHit = (((execute_ctrl4_up_LANE_SEL_lane0 && execute_ctrl4_up_RD_ENABLE_lane0) && (execute_ctrl4_down_RD_PHYS_lane0 == execute_ctrl2_down_RS2_PHYS_lane1)) && 1'b1);
  assign execute_lane1_bypasser_integer_RS2_along_bypasses_0_checks_0_youngerHits_0 = (((execute_ctrl3_up_LANE_SEL_lane0 && execute_ctrl3_up_RD_ENABLE_lane0) && (execute_ctrl3_down_RD_PHYS_lane0 == execute_ctrl2_down_RS2_PHYS_lane1)) && 1'b1);
  assign execute_lane1_bypasser_integer_RS2_along_bypasses_0_checks_0_youngerHits_1 = (((execute_ctrl3_up_LANE_SEL_lane1 && execute_ctrl3_up_RD_ENABLE_lane1) && (execute_ctrl3_down_RD_PHYS_lane1 == execute_ctrl2_down_RS2_PHYS_lane1)) && 1'b1);
  assign execute_lane1_bypasser_integer_RS2_along_bypasses_0_checks_0_hit = (execute_lane1_bypasser_integer_RS2_along_bypasses_0_checks_0_selfHit && (! (|{execute_lane1_bypasser_integer_RS2_along_bypasses_0_checks_0_youngerHits_1,execute_lane1_bypasser_integer_RS2_along_bypasses_0_checks_0_youngerHits_0})));
  assign execute_lane1_bypasser_integer_RS2_along_bypasses_0_checks_1_selfHit = (((execute_ctrl3_up_LANE_SEL_lane0 && execute_ctrl3_up_RD_ENABLE_lane0) && (execute_ctrl3_down_RD_PHYS_lane0 == execute_ctrl2_down_RS2_PHYS_lane1)) && 1'b1);
  assign execute_lane1_bypasser_integer_RS2_along_bypasses_0_checks_1_hit = (execute_lane1_bypasser_integer_RS2_along_bypasses_0_checks_1_selfHit && (! 1'b0));
  assign execute_lane1_bypasser_integer_RS2_along_bypasses_0_checks_2_selfHit = (((execute_ctrl4_up_LANE_SEL_lane1 && execute_ctrl4_up_RD_ENABLE_lane1) && (execute_ctrl4_down_RD_PHYS_lane1 == execute_ctrl2_down_RS2_PHYS_lane1)) && 1'b1);
  assign execute_lane1_bypasser_integer_RS2_along_bypasses_0_checks_2_youngerHits_0 = (((execute_ctrl3_up_LANE_SEL_lane0 && execute_ctrl3_up_RD_ENABLE_lane0) && (execute_ctrl3_down_RD_PHYS_lane0 == execute_ctrl2_down_RS2_PHYS_lane1)) && 1'b1);
  assign execute_lane1_bypasser_integer_RS2_along_bypasses_0_checks_2_youngerHits_1 = (((execute_ctrl3_up_LANE_SEL_lane1 && execute_ctrl3_up_RD_ENABLE_lane1) && (execute_ctrl3_down_RD_PHYS_lane1 == execute_ctrl2_down_RS2_PHYS_lane1)) && 1'b1);
  assign execute_lane1_bypasser_integer_RS2_along_bypasses_0_checks_2_hit = (execute_lane1_bypasser_integer_RS2_along_bypasses_0_checks_2_selfHit && (! (|{execute_lane1_bypasser_integer_RS2_along_bypasses_0_checks_2_youngerHits_1,execute_lane1_bypasser_integer_RS2_along_bypasses_0_checks_2_youngerHits_0})));
  assign execute_lane1_bypasser_integer_RS2_along_bypasses_0_hits = {execute_lane1_bypasser_integer_RS2_along_bypasses_0_checks_2_hit,execute_lane1_bypasser_integer_RS2_along_bypasses_0_checks_1_hit,execute_lane1_bypasser_integer_RS2_along_bypasses_0_checks_0_hit};
  assign _zz_execute_ctrl2_integer_RS2_lane1_bypass = {execute_lane1_bypasser_integer_RS2_along_bypasses_0_hits,(! (|execute_lane1_bypasser_integer_RS2_along_bypasses_0_hits))};
  assign execute_ctrl2_integer_RS2_lane1_bypass = (((_zz_execute_ctrl2_integer_RS2_lane1_bypass[0] ? execute_ctrl2_up_integer_RS2_lane1 : 32'h0) | (_zz_execute_ctrl2_integer_RS2_lane1_bypass[1] ? execute_ctrl4_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : 32'h0)) | ((_zz_execute_ctrl2_integer_RS2_lane1_bypass[2] ? execute_ctrl3_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : 32'h0) | (_zz_execute_ctrl2_integer_RS2_lane1_bypass[3] ? execute_ctrl4_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : 32'h0)));
  assign execute_lane1_bypasser_integer_RS2_along_bypasses_1_checks_0_selfHit = (((execute_ctrl4_up_LANE_SEL_lane0 && execute_ctrl4_up_RD_ENABLE_lane0) && (execute_ctrl4_down_RD_PHYS_lane0 == execute_ctrl3_down_RS2_PHYS_lane1)) && 1'b1);
  assign execute_lane1_bypasser_integer_RS2_along_bypasses_1_checks_0_hit = (execute_lane1_bypasser_integer_RS2_along_bypasses_1_checks_0_selfHit && (! 1'b0));
  assign execute_lane1_bypasser_integer_RS2_along_bypasses_1_checks_1_selfHit = (((execute_ctrl4_up_LANE_SEL_lane1 && execute_ctrl4_up_RD_ENABLE_lane1) && (execute_ctrl4_down_RD_PHYS_lane1 == execute_ctrl3_down_RS2_PHYS_lane1)) && 1'b1);
  assign execute_lane1_bypasser_integer_RS2_along_bypasses_1_checks_1_hit = (execute_lane1_bypasser_integer_RS2_along_bypasses_1_checks_1_selfHit && (! 1'b0));
  assign execute_lane1_bypasser_integer_RS2_along_bypasses_1_hits = {execute_lane1_bypasser_integer_RS2_along_bypasses_1_checks_1_hit,execute_lane1_bypasser_integer_RS2_along_bypasses_1_checks_0_hit};
  assign _zz_execute_ctrl3_integer_RS2_lane1_bypass = {execute_lane1_bypasser_integer_RS2_along_bypasses_1_hits,(! (|execute_lane1_bypasser_integer_RS2_along_bypasses_1_hits))};
  assign execute_ctrl3_integer_RS2_lane1_bypass = (((_zz_execute_ctrl3_integer_RS2_lane1_bypass[0] ? execute_ctrl3_up_integer_RS2_lane1 : 32'h0) | (_zz_execute_ctrl3_integer_RS2_lane1_bypass[1] ? execute_ctrl4_down_lane0_integer_WriteBackPlugin_logic_DATA_lane0 : 32'h0)) | (_zz_execute_ctrl3_integer_RS2_lane1_bypass[2] ? execute_ctrl4_down_lane1_integer_WriteBackPlugin_logic_DATA_lane1 : 32'h0));
  assign execute_lane1_logic_completions_onCtrl_0_port_valid = (((execute_ctrl2_down_LANE_SEL_lane1 && execute_ctrl2_down_isReady) && (! execute_lane1_ctrls_2_downIsCancel)) && execute_ctrl2_down_lane1_logic_completions_onCtrl_0_ENABLE_lane1);
  assign execute_lane1_logic_completions_onCtrl_0_port_payload_uopId = execute_ctrl2_down_Decode_UOP_ID_lane1;
  assign execute_lane1_logic_completions_onCtrl_0_port_payload_trap = execute_ctrl2_down_TRAP_lane1;
  assign execute_lane1_logic_completions_onCtrl_0_port_payload_commit = execute_ctrl2_down_COMMIT_lane1;
  assign execute_lane1_logic_completions_onCtrl_1_port_valid = (((execute_ctrl4_down_LANE_SEL_lane1 && execute_ctrl4_down_isReady) && (! execute_lane1_ctrls_4_downIsCancel)) && execute_ctrl4_down_lane1_logic_completions_onCtrl_1_ENABLE_lane1);
  assign execute_lane1_logic_completions_onCtrl_1_port_payload_uopId = execute_ctrl4_down_Decode_UOP_ID_lane1;
  assign execute_lane1_logic_completions_onCtrl_1_port_payload_trap = execute_ctrl4_down_TRAP_lane1;
  assign execute_lane1_logic_completions_onCtrl_1_port_payload_commit = execute_ctrl4_down_COMMIT_lane1;
  assign execute_lane1_logic_decoding_decodingBits = {execute_ctrl1_down_lane1_LAYER_SEL_lane1,execute_ctrl1_down_Decode_UOP_lane1};
  always @(*) begin
    execute_ctrl1_down_early1_IntAluPlugin_SEL_lane1 = _zz_execute_ctrl1_down_early1_IntAluPlugin_SEL_lane1[0];
    if(execute_ctrl1_down_TRAP_lane1) begin
      execute_ctrl1_down_early1_IntAluPlugin_SEL_lane1 = 1'b0;
    end
  end

  always @(*) begin
    execute_ctrl1_down_early1_BarrelShifterPlugin_SEL_lane1 = _zz_execute_ctrl1_down_early1_BarrelShifterPlugin_SEL_lane1[0];
    if(execute_ctrl1_down_TRAP_lane1) begin
      execute_ctrl1_down_early1_BarrelShifterPlugin_SEL_lane1 = 1'b0;
    end
  end

  always @(*) begin
    execute_ctrl1_down_early1_BranchPlugin_SEL_lane1 = _zz_execute_ctrl1_down_early1_BranchPlugin_SEL_lane1[0];
    if(execute_ctrl1_down_TRAP_lane1) begin
      execute_ctrl1_down_early1_BranchPlugin_SEL_lane1 = 1'b0;
    end
  end

  always @(*) begin
    execute_ctrl1_down_late1_IntAluPlugin_SEL_lane1 = _zz_execute_ctrl1_down_late1_IntAluPlugin_SEL_lane1[0];
    if(execute_ctrl1_down_TRAP_lane1) begin
      execute_ctrl1_down_late1_IntAluPlugin_SEL_lane1 = 1'b0;
    end
  end

  always @(*) begin
    execute_ctrl1_down_late1_BarrelShifterPlugin_SEL_lane1 = _zz_execute_ctrl1_down_late1_BarrelShifterPlugin_SEL_lane1[0];
    if(execute_ctrl1_down_TRAP_lane1) begin
      execute_ctrl1_down_late1_BarrelShifterPlugin_SEL_lane1 = 1'b0;
    end
  end

  assign _zz_execute_ctrl1_down_late1_BranchPlugin_SEL_lane1 = ((execute_lane1_logic_decoding_decodingBits & 33'h100000010) == 33'h0);
  always @(*) begin
    execute_ctrl1_down_late1_BranchPlugin_SEL_lane1 = _zz_execute_ctrl1_down_late1_BranchPlugin_SEL_lane1_1[0];
    if(execute_ctrl1_down_TRAP_lane1) begin
      execute_ctrl1_down_late1_BranchPlugin_SEL_lane1 = 1'b0;
    end
  end

  assign _zz_execute_ctrl1_down_late1_SrcPlugin_logic_SRC2_CTRL_lane1 = ((execute_lane1_logic_decoding_decodingBits & 33'h000000004) == 33'h000000004);
  always @(*) begin
    execute_ctrl1_down_lane1_integer_WriteBackPlugin_SEL_lane1 = _zz_execute_ctrl1_down_lane1_integer_WriteBackPlugin_SEL_lane1[0];
    if(execute_ctrl1_down_TRAP_lane1) begin
      execute_ctrl1_down_lane1_integer_WriteBackPlugin_SEL_lane1 = 1'b0;
    end
  end

  assign _zz_execute_ctrl1_down_BYPASSED_AT_3_lane1 = ((execute_lane1_logic_decoding_decodingBits & 33'h100000000) == 33'h100000000);
  always @(*) begin
    execute_ctrl1_down_COMPLETION_AT_2_lane1 = _zz_execute_ctrl1_down_COMPLETION_AT_2_lane1[0];
    if(execute_ctrl1_down_TRAP_lane1) begin
      execute_ctrl1_down_COMPLETION_AT_2_lane1 = 1'b0;
    end
  end

  assign _zz_execute_ctrl1_down_lane1_logic_completions_onCtrl_1_ENABLE_lane1 = ((execute_lane1_logic_decoding_decodingBits & 33'h100000000) == 33'h0);
  always @(*) begin
    execute_ctrl1_down_COMPLETION_AT_4_lane1 = _zz_execute_ctrl1_down_COMPLETION_AT_4_lane1[0];
    if(execute_ctrl1_down_TRAP_lane1) begin
      execute_ctrl1_down_COMPLETION_AT_4_lane1 = 1'b0;
    end
  end

  always @(*) begin
    execute_ctrl1_down_lane1_logic_completions_onCtrl_0_ENABLE_lane1 = _zz_execute_ctrl1_down_lane1_logic_completions_onCtrl_0_ENABLE_lane1[0];
    if(execute_ctrl1_down_TRAP_lane1) begin
      execute_ctrl1_down_lane1_logic_completions_onCtrl_0_ENABLE_lane1 = 1'b0;
    end
  end

  always @(*) begin
    execute_ctrl1_down_lane1_logic_completions_onCtrl_1_ENABLE_lane1 = _zz_execute_ctrl1_down_lane1_logic_completions_onCtrl_1_ENABLE_lane1_1[0];
    if(execute_ctrl1_down_TRAP_lane1) begin
      execute_ctrl1_down_lane1_logic_completions_onCtrl_1_ENABLE_lane1 = 1'b0;
    end
  end

  assign _zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_ADD_SUB_lane1 = ((execute_lane1_logic_decoding_decodingBits & 33'h000006000) == 33'h0);
  assign execute_ctrl1_down_early1_IntAluPlugin_ALU_ADD_SUB_lane1 = _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_ADD_SUB_lane1[0];
  assign _zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_SLTX_lane1 = ((execute_lane1_logic_decoding_decodingBits & 33'h000006004) == 33'h000002000);
  assign execute_ctrl1_down_early1_IntAluPlugin_ALU_SLTX_lane1 = _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_SLTX_lane1[0];
  assign _zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1 = ((execute_lane1_logic_decoding_decodingBits & 33'h000003000) == 33'h000002000);
  assign _zz_execute_ctrl1_down_BarrelShifterPlugin_LEFT_lane1 = ((execute_lane1_logic_decoding_decodingBits & 33'h000004000) == 33'h0);
  assign _zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_1 = ((execute_lane1_logic_decoding_decodingBits & 33'h000001000) == 33'h000001000);
  assign _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_1 = {(|{_zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_1,_zz_execute_ctrl1_down_late1_SrcPlugin_logic_SRC2_CTRL_lane1,_zz_execute_ctrl1_down_BarrelShifterPlugin_LEFT_lane1}),(|{_zz_execute_ctrl1_down_late1_SrcPlugin_logic_SRC2_CTRL_lane1,_zz_execute_ctrl1_down_BarrelShifterPlugin_LEFT_lane1,_zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1})};
  assign _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1 = _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_1;
  assign _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_2 = _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1;
  assign execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1 = _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_2;
  assign execute_ctrl1_down_SrcStageables_REVERT_lane1 = _zz_execute_ctrl1_down_SrcStageables_REVERT_lane1[0];
  assign execute_ctrl1_down_SrcStageables_ZERO_lane1 = _zz_execute_ctrl1_down_SrcStageables_ZERO_lane1[0];
  assign execute_ctrl1_down_early1_SrcPlugin_logic_SRC1_CTRL_lane1 = (|((execute_lane1_logic_decoding_decodingBits & 33'h000000044) == 33'h000000004));
  assign _zz_execute_ctrl1_down_late1_SrcPlugin_logic_SRC2_CTRL_lane1_1 = ((execute_lane1_logic_decoding_decodingBits & 33'h000000024) == 33'h0);
  assign execute_ctrl1_down_early1_SrcPlugin_logic_SRC2_CTRL_lane1 = {(|_zz_execute_ctrl1_down_late1_SrcPlugin_logic_SRC2_CTRL_lane1),(|_zz_execute_ctrl1_down_late1_SrcPlugin_logic_SRC2_CTRL_lane1_1)};
  assign execute_ctrl1_down_lane1_IntFormatPlugin_logic_SIGNED_lane1 = _zz_execute_ctrl1_down_lane1_IntFormatPlugin_logic_SIGNED_lane1[0];
  assign execute_ctrl1_down_BYPASSED_AT_2_lane1 = _zz_execute_ctrl1_down_BYPASSED_AT_2_lane1[0];
  assign execute_ctrl1_down_BYPASSED_AT_3_lane1 = _zz_execute_ctrl1_down_BYPASSED_AT_3_lane1_1[0];
  assign execute_ctrl1_down_MAY_FLUSH_PRECISE_3_lane1 = _zz_execute_ctrl1_down_MAY_FLUSH_PRECISE_3_lane1[0];
  assign execute_ctrl1_down_MAY_FLUSH_PRECISE_4_lane1 = _zz_execute_ctrl1_down_MAY_FLUSH_PRECISE_4_lane1[0];
  assign execute_ctrl1_down_SrcStageables_UNSIGNED_lane1 = _zz_execute_ctrl1_down_SrcStageables_UNSIGNED_lane1[0];
  assign execute_ctrl1_down_BarrelShifterPlugin_LEFT_lane1 = _zz_execute_ctrl1_down_BarrelShifterPlugin_LEFT_lane1_1[0];
  assign execute_ctrl1_down_BarrelShifterPlugin_SIGNED_lane1 = _zz_execute_ctrl1_down_BarrelShifterPlugin_SIGNED_lane1[0];
  assign _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_1 = {(|((execute_lane1_logic_decoding_decodingBits & 33'h00000000c) == 33'h000000004)),(|((execute_lane1_logic_decoding_decodingBits & 33'h000000008) == 33'h000000008))};
  assign _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1 = _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_1;
  assign _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_2 = _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1;
  assign execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1 = _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_2;
