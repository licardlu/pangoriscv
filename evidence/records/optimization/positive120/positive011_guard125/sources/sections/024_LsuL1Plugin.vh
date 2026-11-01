  always @(posedge socCtrl_systemClk) begin
    if(FetchL1Plugin_logic_banks_0_read_cmd_valid) begin
      FetchL1Plugin_logic_banks_0_mem_spinal_port1 <= FetchL1Plugin_logic_banks_0_mem[FetchL1Plugin_logic_banks_0_read_cmd_payload];
    end
  end


initial begin
  for (verilogIndex = 0; verilogIndex < 1024; verilogIndex = verilogIndex + 1)begin
FetchL1Plugin_logic_banks_1_mem[verilogIndex] = -1;
  end
end
  always @(posedge socCtrl_systemClk) begin
    if(_zz_8) begin
      FetchL1Plugin_logic_banks_1_mem[FetchL1Plugin_logic_banks_1_write_payload_address] <= FetchL1Plugin_logic_banks_1_write_payload_data;
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(FetchL1Plugin_logic_banks_1_read_cmd_valid) begin
      FetchL1Plugin_logic_banks_1_mem_spinal_port1 <= FetchL1Plugin_logic_banks_1_mem[FetchL1Plugin_logic_banks_1_read_cmd_payload];
    end
  end


initial begin
  for (verilogIndex = 0; verilogIndex < 128; verilogIndex = verilogIndex + 1)begin
FetchL1Plugin_logic_ways_0_mem[verilogIndex] = -1;
  end
end
  always @(posedge socCtrl_systemClk) begin
    if(_zz_FetchL1Plugin_logic_ways_0_mem_port_1) begin
      FetchL1Plugin_logic_ways_0_mem[FetchL1Plugin_logic_waysWrite_address] <= _zz_FetchL1Plugin_logic_ways_0_mem_port;
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(FetchL1Plugin_logic_ways_0_read_cmd_valid) begin
      FetchL1Plugin_logic_ways_0_mem_spinal_port1 <= FetchL1Plugin_logic_ways_0_mem[FetchL1Plugin_logic_ways_0_read_cmd_payload];
    end
  end


initial begin
  for (verilogIndex = 0; verilogIndex < 128; verilogIndex = verilogIndex + 1)begin
FetchL1Plugin_logic_ways_1_mem[verilogIndex] = -1;
  end
end
  always @(posedge socCtrl_systemClk) begin
    if(_zz_FetchL1Plugin_logic_ways_1_mem_port_1) begin
      FetchL1Plugin_logic_ways_1_mem[FetchL1Plugin_logic_waysWrite_address] <= _zz_FetchL1Plugin_logic_ways_1_mem_port;
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(FetchL1Plugin_logic_ways_1_read_cmd_valid) begin
      FetchL1Plugin_logic_ways_1_mem_spinal_port1 <= FetchL1Plugin_logic_ways_1_mem[FetchL1Plugin_logic_ways_1_read_cmd_payload];
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(_zz_7) begin
      FetchL1Plugin_logic_plru_mem[FetchL1Plugin_logic_plru_write_payload_address] <= FetchL1Plugin_logic_plru_write_payload_data_0;
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(FetchL1Plugin_logic_plru_read_cmd_valid) begin
      FetchL1Plugin_logic_plru_mem_spinal_port1 <= FetchL1Plugin_logic_plru_mem[FetchL1Plugin_logic_plru_read_cmd_payload];
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(_zz_6) begin
      GSharePlugin_logic_mem_banks_0[GSharePlugin_logic_mem_writes_0_payload_address] <= _zz_GSharePlugin_logic_mem_banks_0_port;
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(fetch_logic_ctrls_0_down_isReady) begin
      GSharePlugin_logic_mem_banks_0_spinal_port1 <= GSharePlugin_logic_mem_banks_0[_zz_GSharePlugin_logic_readRsp_readed_0_0];
    end
  end

  always @(*) begin
    BtbPlugin_logic_mem_spinal_port1 = {_zz_BtbPlugin_logic_memsymbol_read_1, _zz_BtbPlugin_logic_memsymbol_read};
  end
  always @(posedge socCtrl_systemClk) begin
    if(BtbPlugin_logic_memDp_wp_payload_mask[0] && BtbPlugin_logic_memDp_wp_valid) begin
      BtbPlugin_logic_mem_symbol0[BtbPlugin_logic_memDp_wp_payload_address] <= _zz_BtbPlugin_logic_mem_port[50 : 0];
    end
    if(BtbPlugin_logic_memDp_wp_payload_mask[1] && BtbPlugin_logic_memDp_wp_valid) begin
      BtbPlugin_logic_mem_symbol1[BtbPlugin_logic_memDp_wp_payload_address] <= _zz_BtbPlugin_logic_mem_port[101 : 51];
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(BtbPlugin_logic_memDp_rp_cmd_valid) begin
      _zz_BtbPlugin_logic_memsymbol_read <= BtbPlugin_logic_mem_symbol0[BtbPlugin_logic_memDp_rp_cmd_payload];
      _zz_BtbPlugin_logic_memsymbol_read_1 <= BtbPlugin_logic_mem_symbol1[BtbPlugin_logic_memDp_rp_cmd_payload];
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(LsuPlugin_logic_storeBuffer_ops_pip_node_0_isFiring) begin
      LsuPlugin_logic_storeBuffer_ops_mem_spinal_port0 <= LsuPlugin_logic_storeBuffer_ops_mem[_zz__zz_LsuPlugin_logic_storeBuffer_ops_pip_node_1_read_OPS_address_1];
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(_zz_4) begin
      LsuPlugin_logic_storeBuffer_ops_mem[_zz_LsuPlugin_logic_storeBuffer_ops_mem_port_1] <= _zz_LsuPlugin_logic_storeBuffer_ops_mem_port_2;
    end
  end

  always @(*) begin
    LsuL1Plugin_logic_banks_0_mem_spinal_port1 = {_zz_LsuL1Plugin_logic_banks_0_memsymbol_read_7, _zz_LsuL1Plugin_logic_banks_0_memsymbol_read_6, _zz_LsuL1Plugin_logic_banks_0_memsymbol_read_5, _zz_LsuL1Plugin_logic_banks_0_memsymbol_read_4, _zz_LsuL1Plugin_logic_banks_0_memsymbol_read_3, _zz_LsuL1Plugin_logic_banks_0_memsymbol_read_2, _zz_LsuL1Plugin_logic_banks_0_memsymbol_read_1, _zz_LsuL1Plugin_logic_banks_0_memsymbol_read};
  end
  always @(posedge socCtrl_systemClk) begin
    if(LsuL1Plugin_logic_banks_0_write_payload_mask[0] && LsuL1Plugin_logic_banks_0_write_valid) begin
      LsuL1Plugin_logic_banks_0_mem_symbol0[LsuL1Plugin_logic_banks_0_write_payload_address] <= LsuL1Plugin_logic_banks_0_write_payload_data[7 : 0];
    end
    if(LsuL1Plugin_logic_banks_0_write_payload_mask[1] && LsuL1Plugin_logic_banks_0_write_valid) begin
      LsuL1Plugin_logic_banks_0_mem_symbol1[LsuL1Plugin_logic_banks_0_write_payload_address] <= LsuL1Plugin_logic_banks_0_write_payload_data[15 : 8];
    end
    if(LsuL1Plugin_logic_banks_0_write_payload_mask[2] && LsuL1Plugin_logic_banks_0_write_valid) begin
      LsuL1Plugin_logic_banks_0_mem_symbol2[LsuL1Plugin_logic_banks_0_write_payload_address] <= LsuL1Plugin_logic_banks_0_write_payload_data[23 : 16];
    end
    if(LsuL1Plugin_logic_banks_0_write_payload_mask[3] && LsuL1Plugin_logic_banks_0_write_valid) begin
      LsuL1Plugin_logic_banks_0_mem_symbol3[LsuL1Plugin_logic_banks_0_write_payload_address] <= LsuL1Plugin_logic_banks_0_write_payload_data[31 : 24];
    end
    if(LsuL1Plugin_logic_banks_0_write_payload_mask[4] && LsuL1Plugin_logic_banks_0_write_valid) begin
      LsuL1Plugin_logic_banks_0_mem_symbol4[LsuL1Plugin_logic_banks_0_write_payload_address] <= LsuL1Plugin_logic_banks_0_write_payload_data[39 : 32];
    end
    if(LsuL1Plugin_logic_banks_0_write_payload_mask[5] && LsuL1Plugin_logic_banks_0_write_valid) begin
      LsuL1Plugin_logic_banks_0_mem_symbol5[LsuL1Plugin_logic_banks_0_write_payload_address] <= LsuL1Plugin_logic_banks_0_write_payload_data[47 : 40];
    end
    if(LsuL1Plugin_logic_banks_0_write_payload_mask[6] && LsuL1Plugin_logic_banks_0_write_valid) begin
      LsuL1Plugin_logic_banks_0_mem_symbol6[LsuL1Plugin_logic_banks_0_write_payload_address] <= LsuL1Plugin_logic_banks_0_write_payload_data[55 : 48];
    end
    if(LsuL1Plugin_logic_banks_0_write_payload_mask[7] && LsuL1Plugin_logic_banks_0_write_valid) begin
      LsuL1Plugin_logic_banks_0_mem_symbol7[LsuL1Plugin_logic_banks_0_write_payload_address] <= LsuL1Plugin_logic_banks_0_write_payload_data[63 : 56];
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(LsuL1Plugin_logic_banks_0_read_cmd_valid) begin
      _zz_LsuL1Plugin_logic_banks_0_memsymbol_read <= LsuL1Plugin_logic_banks_0_mem_symbol0[LsuL1Plugin_logic_banks_0_read_cmd_payload];
      _zz_LsuL1Plugin_logic_banks_0_memsymbol_read_1 <= LsuL1Plugin_logic_banks_0_mem_symbol1[LsuL1Plugin_logic_banks_0_read_cmd_payload];
      _zz_LsuL1Plugin_logic_banks_0_memsymbol_read_2 <= LsuL1Plugin_logic_banks_0_mem_symbol2[LsuL1Plugin_logic_banks_0_read_cmd_payload];
      _zz_LsuL1Plugin_logic_banks_0_memsymbol_read_3 <= LsuL1Plugin_logic_banks_0_mem_symbol3[LsuL1Plugin_logic_banks_0_read_cmd_payload];
      _zz_LsuL1Plugin_logic_banks_0_memsymbol_read_4 <= LsuL1Plugin_logic_banks_0_mem_symbol4[LsuL1Plugin_logic_banks_0_read_cmd_payload];
      _zz_LsuL1Plugin_logic_banks_0_memsymbol_read_5 <= LsuL1Plugin_logic_banks_0_mem_symbol5[LsuL1Plugin_logic_banks_0_read_cmd_payload];
      _zz_LsuL1Plugin_logic_banks_0_memsymbol_read_6 <= LsuL1Plugin_logic_banks_0_mem_symbol6[LsuL1Plugin_logic_banks_0_read_cmd_payload];
      _zz_LsuL1Plugin_logic_banks_0_memsymbol_read_7 <= LsuL1Plugin_logic_banks_0_mem_symbol7[LsuL1Plugin_logic_banks_0_read_cmd_payload];
    end
  end

  always @(*) begin
    LsuL1Plugin_logic_banks_1_mem_spinal_port1 = {_zz_LsuL1Plugin_logic_banks_1_memsymbol_read_7, _zz_LsuL1Plugin_logic_banks_1_memsymbol_read_6, _zz_LsuL1Plugin_logic_banks_1_memsymbol_read_5, _zz_LsuL1Plugin_logic_banks_1_memsymbol_read_4, _zz_LsuL1Plugin_logic_banks_1_memsymbol_read_3, _zz_LsuL1Plugin_logic_banks_1_memsymbol_read_2, _zz_LsuL1Plugin_logic_banks_1_memsymbol_read_1, _zz_LsuL1Plugin_logic_banks_1_memsymbol_read};
  end
  always @(posedge socCtrl_systemClk) begin
    if(LsuL1Plugin_logic_banks_1_write_payload_mask[0] && LsuL1Plugin_logic_banks_1_write_valid) begin
      LsuL1Plugin_logic_banks_1_mem_symbol0[LsuL1Plugin_logic_banks_1_write_payload_address] <= LsuL1Plugin_logic_banks_1_write_payload_data[7 : 0];
    end
    if(LsuL1Plugin_logic_banks_1_write_payload_mask[1] && LsuL1Plugin_logic_banks_1_write_valid) begin
      LsuL1Plugin_logic_banks_1_mem_symbol1[LsuL1Plugin_logic_banks_1_write_payload_address] <= LsuL1Plugin_logic_banks_1_write_payload_data[15 : 8];
    end
    if(LsuL1Plugin_logic_banks_1_write_payload_mask[2] && LsuL1Plugin_logic_banks_1_write_valid) begin
      LsuL1Plugin_logic_banks_1_mem_symbol2[LsuL1Plugin_logic_banks_1_write_payload_address] <= LsuL1Plugin_logic_banks_1_write_payload_data[23 : 16];
    end
    if(LsuL1Plugin_logic_banks_1_write_payload_mask[3] && LsuL1Plugin_logic_banks_1_write_valid) begin
      LsuL1Plugin_logic_banks_1_mem_symbol3[LsuL1Plugin_logic_banks_1_write_payload_address] <= LsuL1Plugin_logic_banks_1_write_payload_data[31 : 24];
    end
    if(LsuL1Plugin_logic_banks_1_write_payload_mask[4] && LsuL1Plugin_logic_banks_1_write_valid) begin
      LsuL1Plugin_logic_banks_1_mem_symbol4[LsuL1Plugin_logic_banks_1_write_payload_address] <= LsuL1Plugin_logic_banks_1_write_payload_data[39 : 32];
    end
    if(LsuL1Plugin_logic_banks_1_write_payload_mask[5] && LsuL1Plugin_logic_banks_1_write_valid) begin
      LsuL1Plugin_logic_banks_1_mem_symbol5[LsuL1Plugin_logic_banks_1_write_payload_address] <= LsuL1Plugin_logic_banks_1_write_payload_data[47 : 40];
    end
    if(LsuL1Plugin_logic_banks_1_write_payload_mask[6] && LsuL1Plugin_logic_banks_1_write_valid) begin
      LsuL1Plugin_logic_banks_1_mem_symbol6[LsuL1Plugin_logic_banks_1_write_payload_address] <= LsuL1Plugin_logic_banks_1_write_payload_data[55 : 48];
    end
    if(LsuL1Plugin_logic_banks_1_write_payload_mask[7] && LsuL1Plugin_logic_banks_1_write_valid) begin
      LsuL1Plugin_logic_banks_1_mem_symbol7[LsuL1Plugin_logic_banks_1_write_payload_address] <= LsuL1Plugin_logic_banks_1_write_payload_data[63 : 56];
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(LsuL1Plugin_logic_banks_1_read_cmd_valid) begin
      _zz_LsuL1Plugin_logic_banks_1_memsymbol_read <= LsuL1Plugin_logic_banks_1_mem_symbol0[LsuL1Plugin_logic_banks_1_read_cmd_payload];
      _zz_LsuL1Plugin_logic_banks_1_memsymbol_read_1 <= LsuL1Plugin_logic_banks_1_mem_symbol1[LsuL1Plugin_logic_banks_1_read_cmd_payload];
      _zz_LsuL1Plugin_logic_banks_1_memsymbol_read_2 <= LsuL1Plugin_logic_banks_1_mem_symbol2[LsuL1Plugin_logic_banks_1_read_cmd_payload];
      _zz_LsuL1Plugin_logic_banks_1_memsymbol_read_3 <= LsuL1Plugin_logic_banks_1_mem_symbol3[LsuL1Plugin_logic_banks_1_read_cmd_payload];
      _zz_LsuL1Plugin_logic_banks_1_memsymbol_read_4 <= LsuL1Plugin_logic_banks_1_mem_symbol4[LsuL1Plugin_logic_banks_1_read_cmd_payload];
      _zz_LsuL1Plugin_logic_banks_1_memsymbol_read_5 <= LsuL1Plugin_logic_banks_1_mem_symbol5[LsuL1Plugin_logic_banks_1_read_cmd_payload];
      _zz_LsuL1Plugin_logic_banks_1_memsymbol_read_6 <= LsuL1Plugin_logic_banks_1_mem_symbol6[LsuL1Plugin_logic_banks_1_read_cmd_payload];
      _zz_LsuL1Plugin_logic_banks_1_memsymbol_read_7 <= LsuL1Plugin_logic_banks_1_mem_symbol7[LsuL1Plugin_logic_banks_1_read_cmd_payload];
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(_zz_LsuL1Plugin_logic_ways_0_mem_port_1) begin
      LsuL1Plugin_logic_ways_0_mem[LsuL1Plugin_logic_waysWrite_address] <= _zz_LsuL1Plugin_logic_ways_0_mem_port;
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(LsuL1Plugin_logic_ways_0_lsuRead_cmd_valid) begin
      LsuL1Plugin_logic_ways_0_mem_spinal_port1 <= LsuL1Plugin_logic_ways_0_mem[LsuL1Plugin_logic_ways_0_lsuRead_cmd_payload];
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(_zz_LsuL1Plugin_logic_ways_1_mem_port_1) begin
      LsuL1Plugin_logic_ways_1_mem[LsuL1Plugin_logic_waysWrite_address] <= _zz_LsuL1Plugin_logic_ways_1_mem_port;
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(LsuL1Plugin_logic_ways_1_lsuRead_cmd_valid) begin
      LsuL1Plugin_logic_ways_1_mem_spinal_port1 <= LsuL1Plugin_logic_ways_1_mem[LsuL1Plugin_logic_ways_1_lsuRead_cmd_payload];
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(_zz_3) begin
      LsuL1Plugin_logic_shared_mem[LsuL1Plugin_logic_shared_write_payload_address] <= _zz_LsuL1Plugin_logic_shared_mem_port;
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(LsuL1Plugin_logic_shared_lsuRead_cmd_valid) begin
      LsuL1Plugin_logic_shared_mem_spinal_port1 <= LsuL1Plugin_logic_shared_mem[LsuL1Plugin_logic_shared_lsuRead_cmd_payload];
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(_zz_2) begin
      LsuL1Plugin_logic_writeback_victimBuffer[_zz_LsuL1Plugin_logic_writeback_victimBuffer_port] <= LsuL1Plugin_logic_writeback_read_readedData;
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(LsuL1Plugin_logic_writeback_write_bufferRead_ready) begin
      LsuL1Plugin_logic_writeback_victimBuffer_spinal_port1 <= LsuL1Plugin_logic_writeback_victimBuffer[_zz_LsuL1Plugin_logic_writeback_write_word];
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(_zz_1) begin
      CsrRamPlugin_logic_mem[CsrRamPlugin_logic_writeLogic_port_payload_address] <= CsrRamPlugin_logic_writeLogic_port_payload_data;
    end
  end

  always @(posedge socCtrl_systemClk) begin
    if(CsrRamPlugin_logic_readLogic_port_cmd_valid) begin
      CsrRamPlugin_logic_mem_spinal_port1 <= CsrRamPlugin_logic_mem[CsrRamPlugin_logic_readLogic_port_cmd_payload];
    end
  end

  StreamFifo PrefetcherRptPlugin_logic_order_queueWithOccupancy (
    .io_push_valid           (PrefetcherRptPlugin_logic_order_valid                                          ), //i
    .io_push_ready           (PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_push_ready               ), //o
    .io_push_payload_address (PrefetcherRptPlugin_logic_order_payload_address[31:0]                          ), //i
    .io_push_payload_unique  (PrefetcherRptPlugin_logic_order_payload_unique                                 ), //i
    .io_push_payload_from    (PrefetcherRptPlugin_logic_order_payload_from[2:0]                              ), //i
    .io_push_payload_to      (PrefetcherRptPlugin_logic_order_payload_to[2:0]                                ), //i
    .io_push_payload_stride  (PrefetcherRptPlugin_logic_order_payload_stride[11:0]                           ), //i
    .io_pop_valid            (PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_pop_valid                ), //o
    .io_pop_ready            (PrefetcherRptPlugin_logic_queued_ready                                         ), //i
    .io_pop_payload_address  (PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_pop_payload_address[31:0]), //o
    .io_pop_payload_unique   (PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_pop_payload_unique       ), //o
    .io_pop_payload_from     (PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_pop_payload_from[2:0]    ), //o
    .io_pop_payload_to       (PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_pop_payload_to[2:0]      ), //o
    .io_pop_payload_stride   (PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_pop_payload_stride[11:0] ), //o
    .io_flush                (1'b0                                                                           ), //i
    .io_occupancy            (PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_occupancy[2:0]           ), //o
    .io_availability         (PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_availability[2:0]        ), //o
    .socCtrl_systemClk       (socCtrl_systemClk                                                              ), //i
    .socCtrl_system_reset    (socCtrl_system_reset                                                           )  //i
  );
  DivRadix early0_DivPlugin_logic_processing_div (
    .io_flush                  (execute_ctrl2_down_isReady                                       ), //i
    .io_cmd_valid              (early0_DivPlugin_logic_processing_div_io_cmd_valid               ), //i
    .io_cmd_ready              (early0_DivPlugin_logic_processing_div_io_cmd_ready               ), //o
    .io_cmd_payload_a          (early0_DivPlugin_logic_processing_a[31:0]                        ), //i
    .io_cmd_payload_b          (early0_DivPlugin_logic_processing_b[31:0]                        ), //i
    .io_cmd_payload_normalized (1'b0                                                             ), //i
    .io_cmd_payload_iterations (4'bxxxx                                                          ), //i
    .io_rsp_valid              (early0_DivPlugin_logic_processing_div_io_rsp_valid               ), //o
    .io_rsp_ready              (1'b0                                                             ), //i
    .io_rsp_payload_result     (early0_DivPlugin_logic_processing_div_io_rsp_payload_result[31:0]), //o
    .io_rsp_payload_remain     (early0_DivPlugin_logic_processing_div_io_rsp_payload_remain[31:0]), //o
    .socCtrl_systemClk         (socCtrl_systemClk                                                ), //i
    .socCtrl_system_reset      (socCtrl_system_reset                                             )  //i
  );
  StreamArbiter streamArbiter_7 (
    .io_inputs_0_valid                                     (LearnPlugin_logic_buffered_0_valid                                         ), //i
    .io_inputs_0_ready                                     (streamArbiter_7_io_inputs_0_ready                                          ), //o
    .io_inputs_0_payload_pcOnLastSlice                     (LearnPlugin_logic_buffered_0_payload_pcOnLastSlice[31:0]                   ), //i
    .io_inputs_0_payload_pcTarget                          (LearnPlugin_logic_buffered_0_payload_pcTarget[31:0]                        ), //i
    .io_inputs_0_payload_taken                             (LearnPlugin_logic_buffered_0_payload_taken                                 ), //i
    .io_inputs_0_payload_isBranch                          (LearnPlugin_logic_buffered_0_payload_isBranch                              ), //i
    .io_inputs_0_payload_isPush                            (LearnPlugin_logic_buffered_0_payload_isPush                                ), //i
    .io_inputs_0_payload_isPop                             (LearnPlugin_logic_buffered_0_payload_isPop                                 ), //i
    .io_inputs_0_payload_wasWrong                          (LearnPlugin_logic_buffered_0_payload_wasWrong                              ), //i
    .io_inputs_0_payload_badPredictedTarget                (LearnPlugin_logic_buffered_0_payload_badPredictedTarget                    ), //i
    .io_inputs_0_payload_history                           (LearnPlugin_logic_buffered_0_payload_history[11:0]                         ), //i
    .io_inputs_0_payload_uopId                             (LearnPlugin_logic_buffered_0_payload_uopId[15:0]                           ), //i
    .io_inputs_0_payload_ctx_GSharePlugin_GSHARE_COUNTER_0 (LearnPlugin_logic_buffered_0_payload_ctx_GSharePlugin_GSHARE_COUNTER_0[1:0]), //i
    .io_inputs_0_payload_ctx_GSharePlugin_GSHARE_COUNTER_1 (LearnPlugin_logic_buffered_0_payload_ctx_GSharePlugin_GSHARE_COUNTER_1[1:0]), //i
    .io_inputs_0_payload_ctx_GSharePlugin_GSHARE_COUNTER_2 (LearnPlugin_logic_buffered_0_payload_ctx_GSharePlugin_GSHARE_COUNTER_2[1:0]), //i
    .io_inputs_0_payload_ctx_GSharePlugin_GSHARE_COUNTER_3 (LearnPlugin_logic_buffered_0_payload_ctx_GSharePlugin_GSHARE_COUNTER_3[1:0]), //i
    .io_inputs_1_valid                                     (LearnPlugin_logic_buffered_1_valid                                         ), //i
    .io_inputs_1_ready                                     (streamArbiter_7_io_inputs_1_ready                                          ), //o
    .io_inputs_1_payload_pcOnLastSlice                     (LearnPlugin_logic_buffered_1_payload_pcOnLastSlice[31:0]                   ), //i
    .io_inputs_1_payload_pcTarget                          (LearnPlugin_logic_buffered_1_payload_pcTarget[31:0]                        ), //i
    .io_inputs_1_payload_taken                             (LearnPlugin_logic_buffered_1_payload_taken                                 ), //i
    .io_inputs_1_payload_isBranch                          (LearnPlugin_logic_buffered_1_payload_isBranch                              ), //i
    .io_inputs_1_payload_isPush                            (LearnPlugin_logic_buffered_1_payload_isPush                                ), //i
    .io_inputs_1_payload_isPop                             (LearnPlugin_logic_buffered_1_payload_isPop                                 ), //i
    .io_inputs_1_payload_wasWrong                          (LearnPlugin_logic_buffered_1_payload_wasWrong                              ), //i
    .io_inputs_1_payload_badPredictedTarget                (LearnPlugin_logic_buffered_1_payload_badPredictedTarget                    ), //i
    .io_inputs_1_payload_history                           (LearnPlugin_logic_buffered_1_payload_history[11:0]                         ), //i
    .io_inputs_1_payload_uopId                             (LearnPlugin_logic_buffered_1_payload_uopId[15:0]                           ), //i
    .io_inputs_1_payload_ctx_GSharePlugin_GSHARE_COUNTER_0 (LearnPlugin_logic_buffered_1_payload_ctx_GSharePlugin_GSHARE_COUNTER_0[1:0]), //i
    .io_inputs_1_payload_ctx_GSharePlugin_GSHARE_COUNTER_1 (LearnPlugin_logic_buffered_1_payload_ctx_GSharePlugin_GSHARE_COUNTER_1[1:0]), //i
    .io_inputs_1_payload_ctx_GSharePlugin_GSHARE_COUNTER_2 (LearnPlugin_logic_buffered_1_payload_ctx_GSharePlugin_GSHARE_COUNTER_2[1:0]), //i
    .io_inputs_1_payload_ctx_GSharePlugin_GSHARE_COUNTER_3 (LearnPlugin_logic_buffered_1_payload_ctx_GSharePlugin_GSHARE_COUNTER_3[1:0]), //i
    .io_output_valid                                       (streamArbiter_7_io_output_valid                                            ), //o
    .io_output_ready                                       (LearnPlugin_logic_arbitrated_ready                                         ), //i
    .io_output_payload_pcOnLastSlice                       (streamArbiter_7_io_output_payload_pcOnLastSlice[31:0]                      ), //o
    .io_output_payload_pcTarget                            (streamArbiter_7_io_output_payload_pcTarget[31:0]                           ), //o
    .io_output_payload_taken                               (streamArbiter_7_io_output_payload_taken                                    ), //o
    .io_output_payload_isBranch                            (streamArbiter_7_io_output_payload_isBranch                                 ), //o
    .io_output_payload_isPush                              (streamArbiter_7_io_output_payload_isPush                                   ), //o
    .io_output_payload_isPop                               (streamArbiter_7_io_output_payload_isPop                                    ), //o
    .io_output_payload_wasWrong                            (streamArbiter_7_io_output_payload_wasWrong                                 ), //o
    .io_output_payload_badPredictedTarget                  (streamArbiter_7_io_output_payload_badPredictedTarget                       ), //o
    .io_output_payload_history                             (streamArbiter_7_io_output_payload_history[11:0]                            ), //o
    .io_output_payload_uopId                               (streamArbiter_7_io_output_payload_uopId[15:0]                              ), //o
    .io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_0   (streamArbiter_7_io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_0[1:0]   ), //o
    .io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_1   (streamArbiter_7_io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_1[1:0]   ), //o
    .io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_2   (streamArbiter_7_io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_2[1:0]   ), //o
    .io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_3   (streamArbiter_7_io_output_payload_ctx_GSharePlugin_GSHARE_COUNTER_3[1:0]   ), //o
    .io_chosen                                             (streamArbiter_7_io_chosen                                                  ), //o
    .io_chosenOH                                           (streamArbiter_7_io_chosenOH[1:0]                                           ), //o
    .socCtrl_systemClk                                     (socCtrl_systemClk                                                          ), //i
    .socCtrl_system_reset                                  (socCtrl_system_reset                                                       )  //i
  );
  StreamArbiter_1 LsuPlugin_logic_flusher_arbiter (
    .io_inputs_0_valid (TrapPlugin_logic_lsuL1Invalidate_0_cmd_valid     ), //i
    .io_inputs_0_ready (LsuPlugin_logic_flusher_arbiter_io_inputs_0_ready), //o
    .io_output_valid   (LsuPlugin_logic_flusher_arbiter_io_output_valid  ), //o
    .io_output_ready   (LsuPlugin_logic_flusher_arbiter_io_output_ready  ), //i
    .io_chosenOH       (LsuPlugin_logic_flusher_arbiter_io_chosenOH      )  //o
  );
  StreamArbiter_2 LsuPlugin_logic_onAddress0_arbiter (
    .io_inputs_0_valid              (LsuPlugin_logic_onAddress0_ls_port_valid                          ), //i
    .io_inputs_0_ready              (LsuPlugin_logic_onAddress0_arbiter_io_inputs_0_ready              ), //o
    .io_inputs_0_payload_op         (LsuPlugin_logic_onAddress0_ls_port_payload_op[2:0]                ), //i
    .io_inputs_0_payload_address    (LsuPlugin_logic_onAddress0_ls_port_payload_address[31:0]          ), //i
    .io_inputs_0_payload_size       (LsuPlugin_logic_onAddress0_ls_port_payload_size[1:0]              ), //i
    .io_inputs_0_payload_load       (LsuPlugin_logic_onAddress0_ls_port_payload_load                   ), //i
    .io_inputs_0_payload_store      (LsuPlugin_logic_onAddress0_ls_port_payload_store                  ), //i
    .io_inputs_0_payload_execute    (LsuPlugin_logic_onAddress0_ls_port_payload_execute                ), //i
    .io_inputs_0_payload_atomic     (LsuPlugin_logic_onAddress0_ls_port_payload_atomic                 ), //i
    .io_inputs_0_payload_clean      (LsuPlugin_logic_onAddress0_ls_port_payload_clean                  ), //i
    .io_inputs_0_payload_invalidate (LsuPlugin_logic_onAddress0_ls_port_payload_invalidate             ), //i
    .io_inputs_0_payload_guest      (LsuPlugin_logic_onAddress0_ls_port_payload_guest                  ), //i
    .io_inputs_0_payload_storeId    (LsuPlugin_logic_onAddress0_ls_port_payload_storeId[11:0]          ), //i
    .io_inputs_1_valid              (LsuPlugin_logic_onAddress0_flush_port_valid                       ), //i
    .io_inputs_1_ready              (LsuPlugin_logic_onAddress0_arbiter_io_inputs_1_ready              ), //o
    .io_inputs_1_payload_op         (LsuPlugin_logic_onAddress0_flush_port_payload_op[2:0]             ), //i
    .io_inputs_1_payload_address    (LsuPlugin_logic_onAddress0_flush_port_payload_address[31:0]       ), //i
    .io_inputs_1_payload_size       (LsuPlugin_logic_onAddress0_flush_port_payload_size[1:0]           ), //i
    .io_inputs_1_payload_load       (LsuPlugin_logic_onAddress0_flush_port_payload_load                ), //i
    .io_inputs_1_payload_store      (LsuPlugin_logic_onAddress0_flush_port_payload_store               ), //i
    .io_inputs_1_payload_execute    (LsuPlugin_logic_onAddress0_flush_port_payload_execute             ), //i
    .io_inputs_1_payload_atomic     (LsuPlugin_logic_onAddress0_flush_port_payload_atomic              ), //i
    .io_inputs_1_payload_clean      (LsuPlugin_logic_onAddress0_flush_port_payload_clean               ), //i
    .io_inputs_1_payload_invalidate (LsuPlugin_logic_onAddress0_flush_port_payload_invalidate          ), //i
    .io_inputs_1_payload_guest      (LsuPlugin_logic_onAddress0_flush_port_payload_guest               ), //i
    .io_inputs_1_payload_storeId    (LsuPlugin_logic_onAddress0_flush_port_payload_storeId[11:0]       ), //i
    .io_inputs_2_valid              (LsuPlugin_logic_onAddress0_fromHp_port_valid                      ), //i
    .io_inputs_2_ready              (LsuPlugin_logic_onAddress0_arbiter_io_inputs_2_ready              ), //o
    .io_inputs_2_payload_op         (LsuPlugin_logic_onAddress0_fromHp_port_payload_op[2:0]            ), //i
    .io_inputs_2_payload_address    (LsuPlugin_logic_onAddress0_fromHp_port_payload_address[31:0]      ), //i
    .io_inputs_2_payload_size       (LsuPlugin_logic_onAddress0_fromHp_port_payload_size[1:0]          ), //i
    .io_inputs_2_payload_load       (LsuPlugin_logic_onAddress0_fromHp_port_payload_load               ), //i
    .io_inputs_2_payload_store      (LsuPlugin_logic_onAddress0_fromHp_port_payload_store              ), //i
    .io_inputs_2_payload_execute    (LsuPlugin_logic_onAddress0_fromHp_port_payload_execute            ), //i
    .io_inputs_2_payload_atomic     (LsuPlugin_logic_onAddress0_fromHp_port_payload_atomic             ), //i
    .io_inputs_2_payload_clean      (LsuPlugin_logic_onAddress0_fromHp_port_payload_clean              ), //i
    .io_inputs_2_payload_invalidate (LsuPlugin_logic_onAddress0_fromHp_port_payload_invalidate         ), //i
    .io_inputs_2_payload_guest      (LsuPlugin_logic_onAddress0_fromHp_port_payload_guest              ), //i
    .io_inputs_2_payload_storeId    (LsuPlugin_logic_onAddress0_fromHp_port_payload_storeId[11:0]      ), //i
    .io_inputs_3_valid              (LsuPlugin_logic_onAddress0_sb_port_valid                          ), //i
    .io_inputs_3_ready              (LsuPlugin_logic_onAddress0_arbiter_io_inputs_3_ready              ), //o
    .io_inputs_3_payload_op         (LsuPlugin_logic_onAddress0_sb_port_payload_op[2:0]                ), //i
    .io_inputs_3_payload_address    (LsuPlugin_logic_onAddress0_sb_port_payload_address[31:0]          ), //i
    .io_inputs_3_payload_size       (LsuPlugin_logic_onAddress0_sb_port_payload_size[1:0]              ), //i
    .io_inputs_3_payload_load       (LsuPlugin_logic_onAddress0_sb_port_payload_load                   ), //i
    .io_inputs_3_payload_store      (LsuPlugin_logic_onAddress0_sb_port_payload_store                  ), //i
    .io_inputs_3_payload_execute    (LsuPlugin_logic_onAddress0_sb_port_payload_execute                ), //i
    .io_inputs_3_payload_atomic     (LsuPlugin_logic_onAddress0_sb_port_payload_atomic                 ), //i
    .io_inputs_3_payload_clean      (LsuPlugin_logic_onAddress0_sb_port_payload_clean                  ), //i
    .io_inputs_3_payload_invalidate (LsuPlugin_logic_onAddress0_sb_port_payload_invalidate             ), //i
    .io_inputs_3_payload_guest      (LsuPlugin_logic_onAddress0_sb_port_payload_guest                  ), //i
    .io_inputs_3_payload_storeId    (LsuPlugin_logic_onAddress0_sb_port_payload_storeId[11:0]          ), //i
    .io_output_valid                (LsuPlugin_logic_onAddress0_arbiter_io_output_valid                ), //o
    .io_output_ready                (LsuPlugin_logic_onAddress0_arbiter_io_output_ready                ), //i
    .io_output_payload_op           (LsuPlugin_logic_onAddress0_arbiter_io_output_payload_op[2:0]      ), //o
    .io_output_payload_address      (LsuPlugin_logic_onAddress0_arbiter_io_output_payload_address[31:0]), //o
    .io_output_payload_size         (LsuPlugin_logic_onAddress0_arbiter_io_output_payload_size[1:0]    ), //o
    .io_output_payload_load         (LsuPlugin_logic_onAddress0_arbiter_io_output_payload_load         ), //o
    .io_output_payload_store        (LsuPlugin_logic_onAddress0_arbiter_io_output_payload_store        ), //o
    .io_output_payload_execute      (LsuPlugin_logic_onAddress0_arbiter_io_output_payload_execute      ), //o
    .io_output_payload_atomic       (LsuPlugin_logic_onAddress0_arbiter_io_output_payload_atomic       ), //o
    .io_output_payload_clean        (LsuPlugin_logic_onAddress0_arbiter_io_output_payload_clean        ), //o
    .io_output_payload_invalidate   (LsuPlugin_logic_onAddress0_arbiter_io_output_payload_invalidate   ), //o
    .io_output_payload_guest        (LsuPlugin_logic_onAddress0_arbiter_io_output_payload_guest        ), //o
    .io_output_payload_storeId      (LsuPlugin_logic_onAddress0_arbiter_io_output_payload_storeId[11:0]), //o
    .io_chosen                      (LsuPlugin_logic_onAddress0_arbiter_io_chosen[1:0]                 ), //o
    .io_chosenOH                    (LsuPlugin_logic_onAddress0_arbiter_io_chosenOH[3:0]               )  //o
  );
  RegFileMem integer_RegFilePlugin_logic_regfile_fpga (
    .io_writes_0_valid    (integer_RegFilePlugin_logic_regfile_fpga_io_writes_0_valid       ), //i
    .io_writes_0_address  (integer_RegFilePlugin_logic_regfile_fpga_io_writes_0_address[4:0]), //i
    .io_writes_0_data     (integer_RegFilePlugin_logic_regfile_fpga_io_writes_0_data[31:0]  ), //i
    .io_writes_0_uopId    (integer_RegFilePlugin_logic_writeMerges_0_bus_uopId[15:0]        ), //i
    .io_writes_1_valid    (integer_RegFilePlugin_logic_writeMerges_1_bus_valid              ), //i
    .io_writes_1_address  (integer_RegFilePlugin_logic_writeMerges_1_bus_address[4:0]       ), //i
    .io_writes_1_data     (integer_RegFilePlugin_logic_writeMerges_1_bus_data[31:0]         ), //i
    .io_writes_1_uopId    (integer_RegFilePlugin_logic_writeMerges_1_bus_uopId[15:0]        ), //i
    .io_reads_0_valid     (execute_lane1_bypasser_integer_RS1_port_valid                    ), //i
    .io_reads_0_address   (execute_lane1_bypasser_integer_RS1_port_address[4:0]             ), //i
    .io_reads_0_data      (integer_RegFilePlugin_logic_regfile_fpga_io_reads_0_data[31:0]   ), //o
    .io_reads_1_valid     (execute_lane0_bypasser_integer_RS1_port_valid                    ), //i
    .io_reads_1_address   (execute_lane0_bypasser_integer_RS1_port_address[4:0]             ), //i
    .io_reads_1_data      (integer_RegFilePlugin_logic_regfile_fpga_io_reads_1_data[31:0]   ), //o
    .io_reads_2_valid     (execute_lane0_bypasser_integer_RS2_port_valid                    ), //i
    .io_reads_2_address   (execute_lane0_bypasser_integer_RS2_port_address[4:0]             ), //i
    .io_reads_2_data      (integer_RegFilePlugin_logic_regfile_fpga_io_reads_2_data[31:0]   ), //o
    .io_reads_3_valid     (execute_lane1_bypasser_integer_RS2_port_valid                    ), //i
    .io_reads_3_address   (execute_lane1_bypasser_integer_RS2_port_address[4:0]             ), //i
    .io_reads_3_data      (integer_RegFilePlugin_logic_regfile_fpga_io_reads_3_data[31:0]   ), //o
    .socCtrl_systemClk    (socCtrl_systemClk                                                ), //i
    .socCtrl_system_reset (socCtrl_system_reset                                             )  //i
  );
