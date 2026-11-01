  always @(*) begin
    case(FetchL1Plugin_logic_bus_rsp_payload_id)
      3'b000 : begin
        _zz_FetchL1Plugin_logic_refill_onRsp_wayToAllocate = FetchL1Plugin_logic_refill_slots_0_wayToAllocate;
        _zz_FetchL1Plugin_logic_refill_onRsp_address = FetchL1Plugin_logic_refill_slots_0_address;
      end
      3'b001 : begin
        _zz_FetchL1Plugin_logic_refill_onRsp_wayToAllocate = FetchL1Plugin_logic_refill_slots_1_wayToAllocate;
        _zz_FetchL1Plugin_logic_refill_onRsp_address = FetchL1Plugin_logic_refill_slots_1_address;
      end
      3'b010 : begin
        _zz_FetchL1Plugin_logic_refill_onRsp_wayToAllocate = FetchL1Plugin_logic_refill_slots_2_wayToAllocate;
        _zz_FetchL1Plugin_logic_refill_onRsp_address = FetchL1Plugin_logic_refill_slots_2_address;
      end
      3'b011 : begin
        _zz_FetchL1Plugin_logic_refill_onRsp_wayToAllocate = FetchL1Plugin_logic_refill_slots_3_wayToAllocate;
        _zz_FetchL1Plugin_logic_refill_onRsp_address = FetchL1Plugin_logic_refill_slots_3_address;
      end
      3'b100 : begin
        _zz_FetchL1Plugin_logic_refill_onRsp_wayToAllocate = FetchL1Plugin_logic_refill_slots_4_wayToAllocate;
        _zz_FetchL1Plugin_logic_refill_onRsp_address = FetchL1Plugin_logic_refill_slots_4_address;
      end
      3'b101 : begin
        _zz_FetchL1Plugin_logic_refill_onRsp_wayToAllocate = FetchL1Plugin_logic_refill_slots_5_wayToAllocate;
        _zz_FetchL1Plugin_logic_refill_onRsp_address = FetchL1Plugin_logic_refill_slots_5_address;
      end
      3'b110 : begin
        _zz_FetchL1Plugin_logic_refill_onRsp_wayToAllocate = FetchL1Plugin_logic_refill_slots_6_wayToAllocate;
        _zz_FetchL1Plugin_logic_refill_onRsp_address = FetchL1Plugin_logic_refill_slots_6_address;
      end
      default : begin
        _zz_FetchL1Plugin_logic_refill_onRsp_wayToAllocate = FetchL1Plugin_logic_refill_slots_7_wayToAllocate;
        _zz_FetchL1Plugin_logic_refill_onRsp_address = FetchL1Plugin_logic_refill_slots_7_address;
      end
    endcase
  end

  always @(*) begin
    case(_zz_PerformanceCounterPlugin_logic_commitCount_1)
      2'b00 : _zz_PerformanceCounterPlugin_logic_commitCount = 2'b00;
      2'b01 : _zz_PerformanceCounterPlugin_logic_commitCount = 2'b01;
      2'b10 : _zz_PerformanceCounterPlugin_logic_commitCount = 2'b01;
      default : _zz_PerformanceCounterPlugin_logic_commitCount = 2'b10;
    endcase
  end

  always @(*) begin
    case(_zz_fetch_logic_ctrls_2_down_AlignerPlugin_logic_FETCH_MASK_1)
      2'b00 : _zz_fetch_logic_ctrls_2_down_AlignerPlugin_logic_FETCH_MASK = AlignerPlugin_logic_maskGen_frontMasks_0;
      2'b01 : _zz_fetch_logic_ctrls_2_down_AlignerPlugin_logic_FETCH_MASK = AlignerPlugin_logic_maskGen_frontMasks_1;
      2'b10 : _zz_fetch_logic_ctrls_2_down_AlignerPlugin_logic_FETCH_MASK = AlignerPlugin_logic_maskGen_frontMasks_2;
      default : _zz_fetch_logic_ctrls_2_down_AlignerPlugin_logic_FETCH_MASK = AlignerPlugin_logic_maskGen_frontMasks_3;
    endcase
  end

  always @(*) begin
    case(fetch_logic_ctrls_2_down_Prediction_WORD_JUMP_SLICE)
      2'b00 : _zz_fetch_logic_ctrls_2_down_AlignerPlugin_logic_FETCH_MASK_2 = AlignerPlugin_logic_maskGen_backMasks_0;
      2'b01 : _zz_fetch_logic_ctrls_2_down_AlignerPlugin_logic_FETCH_MASK_2 = AlignerPlugin_logic_maskGen_backMasks_1;
      2'b10 : _zz_fetch_logic_ctrls_2_down_AlignerPlugin_logic_FETCH_MASK_2 = AlignerPlugin_logic_maskGen_backMasks_2;
      default : _zz_fetch_logic_ctrls_2_down_AlignerPlugin_logic_FETCH_MASK_2 = AlignerPlugin_logic_maskGen_backMasks_3;
    endcase
  end

  always @(*) begin
    case(_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_27)
      2'b00 : _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_26 = _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_21;
      2'b01 : _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_26 = (_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_21 | 32'h40000000);
      2'b10 : _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_26 = {_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_4,_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst,3'b111,_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst,7'h13};
      default : _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_26 = ({7'h0,_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_1,_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst,_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_28,_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst,(AlignerPlugin_logic_extractors_0_ctx_instruction[12] ? 7'h3b : 7'h33)} | ((AlignerPlugin_logic_extractors_0_ctx_instruction[6 : 5] == 2'b00) ? 32'h40000000 : 32'h0));
    endcase
  end

  always @(*) begin
    case(_zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_29)
      3'b000 : _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_28 = 3'b000;
      3'b001 : _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_28 = 3'b100;
      3'b010 : _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_28 = 3'b110;
      3'b011 : _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_28 = 3'b111;
      3'b100 : _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_28 = 3'b000;
      3'b101 : _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_28 = 3'b000;
      3'b110 : _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_28 = 3'b010;
      default : _zz_AlignerPlugin_logic_feeder_lanes_0_withRvc_dec_inst_28 = 3'b011;
    endcase
  end

  always @(*) begin
    case(_zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst_27)
      2'b00 : _zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst_26 = _zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst_21;
      2'b01 : _zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst_26 = (_zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst_21 | 32'h40000000);
      2'b10 : _zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst_26 = {_zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst_4,_zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst,3'b111,_zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst,7'h13};
      default : _zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst_26 = ({7'h0,_zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst_1,_zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst,_zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst_28,_zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst,(AlignerPlugin_logic_extractors_1_ctx_instruction[12] ? 7'h3b : 7'h33)} | ((AlignerPlugin_logic_extractors_1_ctx_instruction[6 : 5] == 2'b00) ? 32'h40000000 : 32'h0));
    endcase
  end

  always @(*) begin
    case(_zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst_29)
      3'b000 : _zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst_28 = 3'b000;
      3'b001 : _zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst_28 = 3'b100;
      3'b010 : _zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst_28 = 3'b110;
      3'b011 : _zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst_28 = 3'b111;
      3'b100 : _zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst_28 = 3'b000;
      3'b101 : _zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst_28 = 3'b000;
      3'b110 : _zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst_28 = 3'b010;
      default : _zz_AlignerPlugin_logic_feeder_lanes_1_withRvc_dec_inst_28 = 3'b011;
    endcase
  end

  always @(*) begin
    case(_zz_DispatchPlugin_logic_candidates_1_age_1)
      1'b0 : _zz_DispatchPlugin_logic_candidates_1_age = 1'b0;
      default : _zz_DispatchPlugin_logic_candidates_1_age = 1'b1;
    endcase
  end

  always @(*) begin
    case(_zz_DispatchPlugin_logic_candidates_2_age_1)
      2'b00 : _zz_DispatchPlugin_logic_candidates_2_age = 2'b00;
      2'b01 : _zz_DispatchPlugin_logic_candidates_2_age = 2'b01;
      2'b10 : _zz_DispatchPlugin_logic_candidates_2_age = 2'b01;
      default : _zz_DispatchPlugin_logic_candidates_2_age = 2'b10;
    endcase
  end

  always @(*) begin
    case(_zz_DispatchPlugin_logic_slotsFeeds_fit_1)
      2'b00 : _zz_DispatchPlugin_logic_slotsFeeds_fit = 2'b00;
      2'b01 : _zz_DispatchPlugin_logic_slotsFeeds_fit = 2'b01;
      2'b10 : _zz_DispatchPlugin_logic_slotsFeeds_fit = 2'b01;
      default : _zz_DispatchPlugin_logic_slotsFeeds_fit = 2'b10;
    endcase
  end

  always @(*) begin
    case(_zz_PerformanceCounterPlugin_logic_events_sums_0_2)
      2'b00 : _zz_PerformanceCounterPlugin_logic_events_sums_0_1 = 2'b00;
      2'b01 : _zz_PerformanceCounterPlugin_logic_events_sums_0_1 = 2'b01;
      2'b10 : _zz_PerformanceCounterPlugin_logic_events_sums_0_1 = 2'b01;
      default : _zz_PerformanceCounterPlugin_logic_events_sums_0_1 = 2'b10;
    endcase
  end

  always @(*) begin
    case(_zz_PerformanceCounterPlugin_logic_events_sums_1_2)
      2'b00 : _zz_PerformanceCounterPlugin_logic_events_sums_1_1 = 2'b00;
      2'b01 : _zz_PerformanceCounterPlugin_logic_events_sums_1_1 = 2'b01;
      2'b10 : _zz_PerformanceCounterPlugin_logic_events_sums_1_1 = 2'b01;
      default : _zz_PerformanceCounterPlugin_logic_events_sums_1_1 = 2'b10;
    endcase
  end

  always @(*) begin
    case(_zz_PerformanceCounterPlugin_logic_events_sums_2_2)
      1'b0 : _zz_PerformanceCounterPlugin_logic_events_sums_2_1 = 1'b0;
      default : _zz_PerformanceCounterPlugin_logic_events_sums_2_1 = 1'b1;
    endcase
  end

  always @(*) begin
    case(_zz_PerformanceCounterPlugin_logic_events_sums_3_2)
      1'b0 : _zz_PerformanceCounterPlugin_logic_events_sums_3_1 = 1'b0;
      default : _zz_PerformanceCounterPlugin_logic_events_sums_3_1 = 1'b1;
    endcase
  end

  always @(*) begin
    case(_zz_PerformanceCounterPlugin_logic_events_sums_4_2)
      1'b0 : _zz_PerformanceCounterPlugin_logic_events_sums_4_1 = 1'b0;
      default : _zz_PerformanceCounterPlugin_logic_events_sums_4_1 = 1'b1;
    endcase
  end

  always @(*) begin
    case(_zz_PerformanceCounterPlugin_logic_events_sums_5_2)
      1'b0 : _zz_PerformanceCounterPlugin_logic_events_sums_5_1 = 1'b0;
      default : _zz_PerformanceCounterPlugin_logic_events_sums_5_1 = 1'b1;
    endcase
  end

  always @(*) begin
    case(_zz_PerformanceCounterPlugin_logic_events_sums_6_2)
      1'b0 : _zz_PerformanceCounterPlugin_logic_events_sums_6_1 = 1'b0;
      default : _zz_PerformanceCounterPlugin_logic_events_sums_6_1 = 1'b1;
    endcase
  end

  always @(*) begin
    case(_zz_PerformanceCounterPlugin_logic_events_sums_7_2)
      1'b0 : _zz_PerformanceCounterPlugin_logic_events_sums_7_1 = 1'b0;
      default : _zz_PerformanceCounterPlugin_logic_events_sums_7_1 = 1'b1;
    endcase
  end

  always @(*) begin
    case(_zz_PerformanceCounterPlugin_logic_events_sums_8_2)
      1'b0 : _zz_PerformanceCounterPlugin_logic_events_sums_8_1 = 1'b0;
      default : _zz_PerformanceCounterPlugin_logic_events_sums_8_1 = 1'b1;
    endcase
  end

  always @(*) begin
    case(_zz_PerformanceCounterPlugin_logic_events_sums_9_2)
      2'b00 : _zz_PerformanceCounterPlugin_logic_events_sums_9_1 = 2'b00;
      2'b01 : _zz_PerformanceCounterPlugin_logic_events_sums_9_1 = 2'b01;
      2'b10 : _zz_PerformanceCounterPlugin_logic_events_sums_9_1 = 2'b01;
      default : _zz_PerformanceCounterPlugin_logic_events_sums_9_1 = 2'b10;
    endcase
  end

  always @(*) begin
    case(_zz_PerformanceCounterPlugin_logic_events_sums_10_2)
      1'b0 : _zz_PerformanceCounterPlugin_logic_events_sums_10_1 = 1'b0;
      default : _zz_PerformanceCounterPlugin_logic_events_sums_10_1 = 1'b1;
    endcase
  end

  always @(*) begin
    case(_zz_PerformanceCounterPlugin_logic_events_sums_11_2)
      1'b0 : _zz_PerformanceCounterPlugin_logic_events_sums_11_1 = 1'b0;
      default : _zz_PerformanceCounterPlugin_logic_events_sums_11_1 = 1'b1;
    endcase
  end

  always @(*) begin
    case(LsuL1Plugin_logic_refill_read_arbiter_sel)
      3'b000 : _zz_LsuL1Plugin_logic_refill_read_cmdAddress = LsuL1Plugin_logic_refill_slots_0_address[31 : 6];
      3'b001 : _zz_LsuL1Plugin_logic_refill_read_cmdAddress = LsuL1Plugin_logic_refill_slots_1_address[31 : 6];
      3'b010 : _zz_LsuL1Plugin_logic_refill_read_cmdAddress = LsuL1Plugin_logic_refill_slots_2_address[31 : 6];
      3'b011 : _zz_LsuL1Plugin_logic_refill_read_cmdAddress = LsuL1Plugin_logic_refill_slots_3_address[31 : 6];
      3'b100 : _zz_LsuL1Plugin_logic_refill_read_cmdAddress = LsuL1Plugin_logic_refill_slots_4_address[31 : 6];
      3'b101 : _zz_LsuL1Plugin_logic_refill_read_cmdAddress = LsuL1Plugin_logic_refill_slots_5_address[31 : 6];
      3'b110 : _zz_LsuL1Plugin_logic_refill_read_cmdAddress = LsuL1Plugin_logic_refill_slots_6_address[31 : 6];
      default : _zz_LsuL1Plugin_logic_refill_read_cmdAddress = LsuL1Plugin_logic_refill_slots_7_address[31 : 6];
    endcase
  end

  always @(*) begin
    case(LsuL1Plugin_logic_bus_read_rsp_payload_id)
      3'b000 : begin
        _zz_LsuL1Plugin_logic_refill_read_rspAddress = LsuL1Plugin_logic_refill_slots_0_address;
        _zz_LsuL1Plugin_logic_refill_read_way = LsuL1Plugin_logic_refill_slots_0_way;
      end
      3'b001 : begin
        _zz_LsuL1Plugin_logic_refill_read_rspAddress = LsuL1Plugin_logic_refill_slots_1_address;
        _zz_LsuL1Plugin_logic_refill_read_way = LsuL1Plugin_logic_refill_slots_1_way;
      end
      3'b010 : begin
        _zz_LsuL1Plugin_logic_refill_read_rspAddress = LsuL1Plugin_logic_refill_slots_2_address;
        _zz_LsuL1Plugin_logic_refill_read_way = LsuL1Plugin_logic_refill_slots_2_way;
      end
      3'b011 : begin
        _zz_LsuL1Plugin_logic_refill_read_rspAddress = LsuL1Plugin_logic_refill_slots_3_address;
        _zz_LsuL1Plugin_logic_refill_read_way = LsuL1Plugin_logic_refill_slots_3_way;
      end
      3'b100 : begin
        _zz_LsuL1Plugin_logic_refill_read_rspAddress = LsuL1Plugin_logic_refill_slots_4_address;
        _zz_LsuL1Plugin_logic_refill_read_way = LsuL1Plugin_logic_refill_slots_4_way;
      end
      3'b101 : begin
        _zz_LsuL1Plugin_logic_refill_read_rspAddress = LsuL1Plugin_logic_refill_slots_5_address;
        _zz_LsuL1Plugin_logic_refill_read_way = LsuL1Plugin_logic_refill_slots_5_way;
      end
      3'b110 : begin
        _zz_LsuL1Plugin_logic_refill_read_rspAddress = LsuL1Plugin_logic_refill_slots_6_address;
        _zz_LsuL1Plugin_logic_refill_read_way = LsuL1Plugin_logic_refill_slots_6_way;
      end
      default : begin
        _zz_LsuL1Plugin_logic_refill_read_rspAddress = LsuL1Plugin_logic_refill_slots_7_address;
        _zz_LsuL1Plugin_logic_refill_read_way = LsuL1Plugin_logic_refill_slots_7_way;
      end
    endcase
  end

  always @(*) begin
    case(LsuL1Plugin_logic_writeback_read_arbiter_sel)
      3'b000 : begin
        _zz_LsuL1Plugin_logic_writeback_read_address = LsuL1Plugin_logic_writeback_slots_0_address;
        _zz_LsuL1Plugin_logic_writeback_read_way = LsuL1Plugin_logic_writeback_slots_0_way;
      end
      3'b001 : begin
        _zz_LsuL1Plugin_logic_writeback_read_address = LsuL1Plugin_logic_writeback_slots_1_address;
        _zz_LsuL1Plugin_logic_writeback_read_way = LsuL1Plugin_logic_writeback_slots_1_way;
      end
      3'b010 : begin
        _zz_LsuL1Plugin_logic_writeback_read_address = LsuL1Plugin_logic_writeback_slots_2_address;
        _zz_LsuL1Plugin_logic_writeback_read_way = LsuL1Plugin_logic_writeback_slots_2_way;
      end
      3'b011 : begin
        _zz_LsuL1Plugin_logic_writeback_read_address = LsuL1Plugin_logic_writeback_slots_3_address;
        _zz_LsuL1Plugin_logic_writeback_read_way = LsuL1Plugin_logic_writeback_slots_3_way;
      end
      3'b100 : begin
        _zz_LsuL1Plugin_logic_writeback_read_address = LsuL1Plugin_logic_writeback_slots_4_address;
        _zz_LsuL1Plugin_logic_writeback_read_way = LsuL1Plugin_logic_writeback_slots_4_way;
      end
      3'b101 : begin
        _zz_LsuL1Plugin_logic_writeback_read_address = LsuL1Plugin_logic_writeback_slots_5_address;
        _zz_LsuL1Plugin_logic_writeback_read_way = LsuL1Plugin_logic_writeback_slots_5_way;
      end
      3'b110 : begin
        _zz_LsuL1Plugin_logic_writeback_read_address = LsuL1Plugin_logic_writeback_slots_6_address;
        _zz_LsuL1Plugin_logic_writeback_read_way = LsuL1Plugin_logic_writeback_slots_6_way;
      end
      default : begin
        _zz_LsuL1Plugin_logic_writeback_read_address = LsuL1Plugin_logic_writeback_slots_7_address;
        _zz_LsuL1Plugin_logic_writeback_read_way = LsuL1Plugin_logic_writeback_slots_7_way;
      end
    endcase
  end

  always @(*) begin
    case(LsuL1Plugin_logic_writeback_read_slotReadLast_payload_way)
      1'b0 : _zz_LsuL1Plugin_logic_writeback_read_readedData = LsuL1Plugin_logic_banks_0_read_rsp;
      default : _zz_LsuL1Plugin_logic_writeback_read_readedData = LsuL1Plugin_logic_banks_1_read_rsp;
    endcase
  end

  always @(*) begin
    case(LsuL1Plugin_logic_writeback_write_arbiter_sel)
      3'b000 : _zz_LsuL1Plugin_logic_writeback_write_bufferRead_payload_address = LsuL1Plugin_logic_writeback_slots_0_address;
      3'b001 : _zz_LsuL1Plugin_logic_writeback_write_bufferRead_payload_address = LsuL1Plugin_logic_writeback_slots_1_address;
      3'b010 : _zz_LsuL1Plugin_logic_writeback_write_bufferRead_payload_address = LsuL1Plugin_logic_writeback_slots_2_address;
      3'b011 : _zz_LsuL1Plugin_logic_writeback_write_bufferRead_payload_address = LsuL1Plugin_logic_writeback_slots_3_address;
      3'b100 : _zz_LsuL1Plugin_logic_writeback_write_bufferRead_payload_address = LsuL1Plugin_logic_writeback_slots_4_address;
      3'b101 : _zz_LsuL1Plugin_logic_writeback_write_bufferRead_payload_address = LsuL1Plugin_logic_writeback_slots_5_address;
      3'b110 : _zz_LsuL1Plugin_logic_writeback_write_bufferRead_payload_address = LsuL1Plugin_logic_writeback_slots_6_address;
      default : _zz_LsuL1Plugin_logic_writeback_write_bufferRead_payload_address = LsuL1Plugin_logic_writeback_slots_7_address;
    endcase
  end

  always @(*) begin
    case(_zz_execute_ctrl3_down_LsuL1Plugin_logic_BANKS_MUXES_lane0_0_1)
      1'b0 : _zz_execute_ctrl3_down_LsuL1Plugin_logic_BANKS_MUXES_lane0_0 = execute_ctrl3_down_LsuL1Plugin_logic_BANKS_WORDS_lane0_0[31 : 0];
      default : _zz_execute_ctrl3_down_LsuL1Plugin_logic_BANKS_MUXES_lane0_0 = execute_ctrl3_down_LsuL1Plugin_logic_BANKS_WORDS_lane0_0[63 : 32];
    endcase
  end

  always @(*) begin
    case(_zz_execute_ctrl3_down_LsuL1Plugin_logic_BANKS_MUXES_lane0_1_1)
      1'b0 : _zz_execute_ctrl3_down_LsuL1Plugin_logic_BANKS_MUXES_lane0_1 = execute_ctrl3_down_LsuL1Plugin_logic_BANKS_WORDS_lane0_1[31 : 0];
      default : _zz_execute_ctrl3_down_LsuL1Plugin_logic_BANKS_MUXES_lane0_1 = execute_ctrl3_down_LsuL1Plugin_logic_BANKS_WORDS_lane0_1[63 : 32];
    endcase
  end

  always @(*) begin
    case(_zz_52)
      2'b00 : _zz_51 = 2'b00;
      2'b01 : _zz_51 = 2'b01;
      2'b10 : _zz_51 = 2'b01;
      default : _zz_51 = 2'b10;
    endcase
  end

  always @(*) begin
    case(_zz_54)
      3'b000 : _zz_53 = 2'b00;
      3'b001 : _zz_53 = 2'b01;
      3'b010 : _zz_53 = 2'b01;
      3'b011 : _zz_53 = 2'b10;
      3'b100 : _zz_53 = 2'b01;
      3'b101 : _zz_53 = 2'b10;
      3'b110 : _zz_53 = 2'b10;
      default : _zz_53 = 2'b11;
    endcase
  end

  always @(*) begin
    case(LsuL1Plugin_logic_lsu_ctrl_needFlushSel)
      1'b0 : begin
        _zz__zz_LsuL1Plugin_logic_waysWrite_tag_address = execute_ctrl4_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_0_address;
        _zz_LsuL1Plugin_logic_waysWrite_tag_fault = execute_ctrl4_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_0_fault;
      end
      default : begin
        _zz__zz_LsuL1Plugin_logic_waysWrite_tag_address = execute_ctrl4_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_1_address;
        _zz_LsuL1Plugin_logic_waysWrite_tag_fault = execute_ctrl4_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_1_fault;
      end
    endcase
  end

  always @(*) begin
    case(LsuL1Plugin_logic_lsu_ctrl_targetWay)
      1'b0 : _zz_LsuL1Plugin_logic_writeback_push_payload_address = execute_ctrl4_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_0_address;
      default : _zz_LsuL1Plugin_logic_writeback_push_payload_address = execute_ctrl4_down_LsuL1Plugin_logic_WAYS_TAGS_lane0_1_address;
    endcase
  end

  always @(*) begin
    case(_zz_LsuPlugin_logic_onCtrl_loadData_shifted_1)
      2'b00 : _zz_LsuPlugin_logic_onCtrl_loadData_shifted = LsuPlugin_logic_onCtrl_loadData_splitted_0;
      2'b01 : _zz_LsuPlugin_logic_onCtrl_loadData_shifted = LsuPlugin_logic_onCtrl_loadData_splitted_1;
      2'b10 : _zz_LsuPlugin_logic_onCtrl_loadData_shifted = LsuPlugin_logic_onCtrl_loadData_splitted_2;
      default : _zz_LsuPlugin_logic_onCtrl_loadData_shifted = LsuPlugin_logic_onCtrl_loadData_splitted_3;
    endcase
  end

  always @(*) begin
    case(_zz_LsuPlugin_logic_onCtrl_loadData_shifted_3)
      1'b0 : _zz_LsuPlugin_logic_onCtrl_loadData_shifted_2 = LsuPlugin_logic_onCtrl_loadData_splitted_1;
      default : _zz_LsuPlugin_logic_onCtrl_loadData_shifted_2 = LsuPlugin_logic_onCtrl_loadData_splitted_3;
    endcase
  end

  always @(*) begin
    case(LsuL1TileLinkPlugin_logic_down_a_payload_size)
      3'b000 : _zz_LsuL1TileLinkPlugin_logic_down_a_tracker_last = 3'b000;
      3'b001 : _zz_LsuL1TileLinkPlugin_logic_down_a_tracker_last = 3'b000;
      3'b010 : _zz_LsuL1TileLinkPlugin_logic_down_a_tracker_last = 3'b000;
      3'b011 : _zz_LsuL1TileLinkPlugin_logic_down_a_tracker_last = 3'b000;
      3'b100 : _zz_LsuL1TileLinkPlugin_logic_down_a_tracker_last = 3'b001;
      3'b101 : _zz_LsuL1TileLinkPlugin_logic_down_a_tracker_last = 3'b011;
      default : _zz_LsuL1TileLinkPlugin_logic_down_a_tracker_last = 3'b111;
    endcase
  end

  always @(*) begin
    case(CsrRamPlugin_logic_readLogic_sel)
      2'b00 : _zz_CsrRamPlugin_logic_readLogic_port_cmd_payload = PerformanceCounterPlugin_logic_readPort_address;
      2'b01 : _zz_CsrRamPlugin_logic_readLogic_port_cmd_payload = TrapPlugin_logic_harts_0_crsPorts_read_address;
      default : _zz_CsrRamPlugin_logic_readLogic_port_cmd_payload = CsrRamPlugin_csrMapper_read_address;
    endcase
  end

