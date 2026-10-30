  assign when_TrapPlugin_l630 = ((TrapPlugin_logic_harts_0_trap_pending_state_exception || TrapPlugin_logic_harts_0_trap_fsm_triggerEbreak) || TrapPlugin_logic_harts_0_trap_fsm_buffer_trap_interrupt);
  assign when_TrapPlugin_l693 = (! TrapPlugin_api_harts_0_holdPrivChange);
  always @(*) begin
    _zz_TrapPlugin_logic_harts_0_crsPorts_write_address = 3'b101;
    case(TrapPlugin_logic_harts_0_trap_fsm_buffer_trap_targetPrivilege)
      3'b011 : begin
        _zz_TrapPlugin_logic_harts_0_crsPorts_write_address = 3'b101;
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    _zz_TrapPlugin_logic_harts_0_crsPorts_write_address_1 = 3'b110;
    case(TrapPlugin_logic_harts_0_trap_fsm_buffer_trap_targetPrivilege)
      3'b011 : begin
        _zz_TrapPlugin_logic_harts_0_crsPorts_write_address_1 = 3'b110;
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    _zz_TrapPlugin_logic_harts_0_crsPorts_read_address = 3'b111;
    case(TrapPlugin_logic_harts_0_trap_fsm_buffer_trap_targetPrivilege)
      3'b011 : begin
        _zz_TrapPlugin_logic_harts_0_crsPorts_read_address = 3'b111;
      end
      default : begin
      end
    endcase
  end

  assign when_TrapPlugin_l955 = (! TrapPlugin_api_harts_0_holdPrivChange);
  always @(*) begin
    _zz_TrapPlugin_logic_harts_0_crsPorts_read_address_1 = 3'b101;
    case(TrapPlugin_logic_harts_0_trap_fsm_xretPrivilege)
      3'b011 : begin
        _zz_TrapPlugin_logic_harts_0_crsPorts_read_address_1 = 3'b101;
      end
      default : begin
      end
    endcase
  end

  assign when_TrapPlugin_l1075 = ($signed(TrapPlugin_logic_harts_0_trap_pending_xret_targetPrivilege) != $signed(3'b011));
  assign switch_TrapPlugin_l1076 = TrapPlugin_logic_harts_0_trap_pending_state_arg[2 : 0];
  assign when_TrapPlugin_l556 = (&TrapPlugin_logic_harts_0_trap_fsm_resetToRunConditions_0);
  always @(*) begin
    CsrAccessPlugin_logic_fsm_stateNext = CsrAccessPlugin_logic_fsm_stateReg;
    case(CsrAccessPlugin_logic_fsm_stateReg)
      CsrAccessPlugin_logic_fsm_READ : begin
        if(when_CsrAccessPlugin_l325) begin
          CsrAccessPlugin_logic_fsm_stateNext = CsrAccessPlugin_logic_fsm_WRITE;
        end
      end
      CsrAccessPlugin_logic_fsm_WRITE : begin
        if(when_CsrAccessPlugin_l357) begin
          CsrAccessPlugin_logic_fsm_stateNext = CsrAccessPlugin_logic_fsm_COMPLETION;
        end
      end
      CsrAccessPlugin_logic_fsm_COMPLETION : begin
        if(execute_ctrl2_down_isReady) begin
          CsrAccessPlugin_logic_fsm_stateNext = CsrAccessPlugin_logic_fsm_IDLE;
        end
      end
      default : begin
        if(CsrAccessPlugin_logic_fsm_inject_onDecodeDo) begin
          if(when_CsrAccessPlugin_l237) begin
            if(when_CsrAccessPlugin_l238) begin
              CsrAccessPlugin_logic_fsm_stateNext = CsrAccessPlugin_logic_fsm_READ;
            end
          end
          if(CsrAccessPlugin_logic_fsm_inject_sampled) begin
            if(!CsrAccessPlugin_logic_fsm_inject_trapReg) begin
              if(when_CsrAccessPlugin_l250) begin
                CsrAccessPlugin_logic_fsm_stateNext = CsrAccessPlugin_logic_fsm_READ;
              end
            end
          end
        end
      end
    endcase
    if(CsrAccessPlugin_logic_fsm_wantKill) begin
      CsrAccessPlugin_logic_fsm_stateNext = CsrAccessPlugin_logic_fsm_IDLE;
    end
  end

  assign when_CsrAccessPlugin_l325 = (! CsrAccessPlugin_bus_read_halt);
  assign when_CsrAccessPlugin_l357 = (! CsrAccessPlugin_bus_write_halt);
  assign when_CsrAccessPlugin_l237 = ((! CsrAccessPlugin_logic_fsm_inject_trap) && (! CsrAccessPlugin_bus_decode_trap));
  assign when_CsrAccessPlugin_l238 = (! CsrAccessPlugin_bus_decode_fence);
  assign when_CsrAccessPlugin_l250 = (! CsrAccessPlugin_bus_decode_fence);
  always @(*) begin
    LsuPlugin_logic_flusher_stateNext = LsuPlugin_logic_flusher_stateReg;
    case(LsuPlugin_logic_flusher_stateReg)
      LsuPlugin_logic_flusher_SB_DRAIN : begin
        if(LsuPlugin_logic_storeBuffer_empty) begin
          LsuPlugin_logic_flusher_stateNext = LsuPlugin_logic_flusher_CMD;
        end
      end
      LsuPlugin_logic_flusher_CMD : begin
        if(when_LsuPlugin_l411) begin
          LsuPlugin_logic_flusher_stateNext = LsuPlugin_logic_flusher_COMPLETION;
        end
      end
      LsuPlugin_logic_flusher_COMPLETION : begin
        if(when_LsuPlugin_l419) begin
          LsuPlugin_logic_flusher_stateNext = LsuPlugin_logic_flusher_IDLE;
        end
      end
      default : begin
        if(LsuPlugin_logic_flusher_arbiter_io_output_valid) begin
          LsuPlugin_logic_flusher_stateNext = LsuPlugin_logic_flusher_SB_DRAIN;
        end
      end
    endcase
    if(LsuPlugin_logic_flusher_wantKill) begin
      LsuPlugin_logic_flusher_stateNext = LsuPlugin_logic_flusher_IDLE;
    end
  end

  assign when_LsuPlugin_l411 = (LsuPlugin_logic_flusher_cmdCounter[6] && (! LsuPlugin_logic_flusher_inflight));
  assign when_LsuPlugin_l419 = (! (|LsuPlugin_logic_flusher_waiter));
  always @(posedge socCtrl_systemClk or posedge socCtrl_system_reset) begin
    if(socCtrl_system_reset) begin
      PrefetcherRptPlugin_logic_csr_disable <= 1'b0;
      PrefetcherRptPlugin_logic_counter <= 3'b000;
      PrefetcherRptPlugin_logic_pip2_node_1_valid <= 1'b0;
      _zz_11 <= 1'b0;
      early0_DivPlugin_logic_processing_cmdSent <= 1'b0;
      early0_DivPlugin_logic_processing_unscheduleRequest <= 1'b0;
      PrivilegedPlugin_logic_harts_0_privilege <= 3'b011;
      PrivilegedPlugin_logic_harts_0_m_status_mie <= 1'b0;
      PrivilegedPlugin_logic_harts_0_m_status_mpie <= 1'b0;
      PrivilegedPlugin_logic_harts_0_m_status_mprv <= 1'b0;
      PrivilegedPlugin_logic_harts_0_m_cause_interrupt <= 1'b0;
      PrivilegedPlugin_logic_harts_0_m_cause_code <= 5'h0;
      PrivilegedPlugin_logic_harts_0_m_ip_meip <= 1'b0;
      PrivilegedPlugin_logic_harts_0_m_ip_mtip <= 1'b0;
      PrivilegedPlugin_logic_harts_0_m_ip_msip <= 1'b0;
      PrivilegedPlugin_logic_harts_0_m_ie_meie <= 1'b0;
      PrivilegedPlugin_logic_harts_0_m_ie_mtie <= 1'b0;
      PrivilegedPlugin_logic_harts_0_m_ie_msie <= 1'b0;
      PrivilegedPlugin_logic_harts_0_m_counteren_tm <= 1'b1;
      FetchL1Plugin_logic_invalidate_counter <= 8'h0;
      FetchL1Plugin_logic_invalidate_firstEver <= 1'b1;
      FetchL1Plugin_logic_refill_slots_0_valid <= 1'b0;
      FetchL1Plugin_logic_refill_slots_0_cmdSent <= 1'b1;
      FetchL1Plugin_logic_refill_slots_1_valid <= 1'b0;
      FetchL1Plugin_logic_refill_slots_1_cmdSent <= 1'b1;
      FetchL1Plugin_logic_refill_slots_2_valid <= 1'b0;
      FetchL1Plugin_logic_refill_slots_2_cmdSent <= 1'b1;
      FetchL1Plugin_logic_refill_slots_3_valid <= 1'b0;
      FetchL1Plugin_logic_refill_slots_3_cmdSent <= 1'b1;
      FetchL1Plugin_logic_refill_slots_4_valid <= 1'b0;
      FetchL1Plugin_logic_refill_slots_4_cmdSent <= 1'b1;
      FetchL1Plugin_logic_refill_slots_5_valid <= 1'b0;
      FetchL1Plugin_logic_refill_slots_5_cmdSent <= 1'b1;
      FetchL1Plugin_logic_refill_slots_6_valid <= 1'b0;
      FetchL1Plugin_logic_refill_slots_6_cmdSent <= 1'b1;
      FetchL1Plugin_logic_refill_slots_7_valid <= 1'b0;
      FetchL1Plugin_logic_refill_slots_7_cmdSent <= 1'b1;
      FetchL1Plugin_logic_refill_pushCounter <= 32'h0;
      FetchL1Plugin_logic_refill_onCmd_locked <= 1'b0;
      FetchL1Plugin_logic_refill_onRsp_wordIndex <= 3'b000;
      FetchL1Plugin_logic_refill_onRsp_firstCycle <= 1'b1;
      FetchL1Plugin_logic_hazard_checkHold <= 1'b0;
      _zz_fetch_logic_ctrls_2_FetchL1Plugin_logic_HAZARD_bypass_1 <= 1'b0;
      FetchL1Plugin_logic_ctrl_plruLogic_buffer_regNext_valid <= 1'b0;
      FetchL1Plugin_logic_ctrl_trapSent <= 1'b0;
      FetchL1Plugin_logic_ctrl_firstCycle <= 1'b1;
      FetchL1Plugin_logic_ctrl_onEvents_waiting <= 1'b0;
      FetchL1Plugin_logic_initializer_counter <= 11'h0;
      BtbPlugin_logic_ras_ptr_push <= 2'b00;
      BtbPlugin_logic_ras_ptr_pop <= 2'b11;
      PerformanceCounterPlugin_logic_ignoreNextCommit <= 1'b0;
      PerformanceCounterPlugin_logic_counters_cycle_value <= 8'h0;
      PerformanceCounterPlugin_logic_counters_cycle_mcounteren <= 1'b0;
      PerformanceCounterPlugin_logic_counters_cycle_mcountinhibit <= 1'b0;
      PerformanceCounterPlugin_logic_counters_instret_value <= 8'h0;
      PerformanceCounterPlugin_logic_counters_instret_mcounteren <= 1'b0;
      PerformanceCounterPlugin_logic_counters_instret_mcountinhibit <= 1'b0;
      _zz_PerformanceCounterPlugin_logic_counters_instret_value <= 2'b00;
      PerformanceCounterPlugin_logic_interrupt_ip <= 1'b0;
      PerformanceCounterPlugin_logic_interrupt_ie <= 1'b0;
      AlignerPlugin_logic_feeder_harts_0_dopId <= 10'h0;
      AlignerPlugin_logic_buffer_mask <= 4'b0000;
      AlignerPlugin_logic_buffer_last <= 4'b0000;
      AlignerPlugin_logic_buffer_trap <= 1'b0;
      LsuPlugin_logic_storeBuffer_ops_pushPtr <= 6'h0;
      LsuPlugin_logic_storeBuffer_ops_popPtr <= 6'h0;
      LsuPlugin_logic_storeBuffer_ops_freePtr <= 6'h0;
      LsuPlugin_logic_storeBuffer_slots_0_valid <= 1'b0;
      LsuPlugin_logic_storeBuffer_slots_1_valid <= 1'b0;
      LsuPlugin_logic_storeBuffer_slots_2_valid <= 1'b0;
      LsuPlugin_logic_storeBuffer_slots_3_valid <= 1'b0;
      LsuPlugin_logic_storeBuffer_holdHart_waitIt <= 1'b0;
      DecoderPlugin_logic_harts_0_uopId <= 16'h0;
      DecoderPlugin_logic_interrupt_buffered <= 1'b0;
      decode_ctrls_1_up_LANE_SEL_0_regNext <= 1'b0;
      decode_ctrls_1_up_LANE_SEL_1_regNext <= 1'b0;
      DispatchPlugin_logic_slots_0_ctx_valid <= 1'b0;
      DispatchPlugin_logic_feeds_0_sent <= 1'b0;
      DispatchPlugin_logic_feeds_1_sent <= 1'b0;
      late0_BranchPlugin_logic_jumpLogic_learn_rValid <= 1'b0;
      late1_BranchPlugin_logic_jumpLogic_learn_rValid <= 1'b0;
      CsrRamPlugin_csrMapper_fired <= 1'b0;
      GSharePlugin_logic_initializer_counter <= 13'h0;
      BtbPlugin_logic_applyIt_correctionSent <= 1'b0;
      BtbPlugin_logic_initializer_counter <= 9'h0;
      decode_ctrls_1_up_LANE_SEL_0 <= 1'b0;
      decode_ctrls_1_up_LANE_SEL_1 <= 1'b0;
      PerformanceCounterPlugin_logic_csrRead_fired <= 1'b0;
      PerformanceCounterPlugin_logic_csrWrite_fired <= 1'b0;
      TrapPlugin_logic_harts_0_interrupt_validBuffer <= 1'b0;
      TrapPlugin_logic_harts_0_trap_fsm_trapEnterDebug <= 1'b0;
      LsuL1Plugin_logic_refill_slots_0_valid <= 1'b0;
      LsuL1Plugin_logic_refill_slots_0_loaded <= 1'b1;
      LsuL1Plugin_logic_refill_slots_1_valid <= 1'b0;
      LsuL1Plugin_logic_refill_slots_1_loaded <= 1'b1;
      LsuL1Plugin_logic_refill_slots_2_valid <= 1'b0;
      LsuL1Plugin_logic_refill_slots_2_loaded <= 1'b1;
      LsuL1Plugin_logic_refill_slots_3_valid <= 1'b0;
      LsuL1Plugin_logic_refill_slots_3_loaded <= 1'b1;
      LsuL1Plugin_logic_refill_slots_4_valid <= 1'b0;
      LsuL1Plugin_logic_refill_slots_4_loaded <= 1'b1;
      LsuL1Plugin_logic_refill_slots_5_valid <= 1'b0;
      LsuL1Plugin_logic_refill_slots_5_loaded <= 1'b1;
      LsuL1Plugin_logic_refill_slots_6_valid <= 1'b0;
      LsuL1Plugin_logic_refill_slots_6_loaded <= 1'b1;
      LsuL1Plugin_logic_refill_slots_7_valid <= 1'b0;
      LsuL1Plugin_logic_refill_slots_7_loaded <= 1'b1;
      LsuL1Plugin_logic_refill_pushCounter <= 32'h0;
      LsuL1Plugin_logic_refill_read_arbiter_lock <= 8'h0;
      LsuL1Plugin_logic_refill_read_wordIndex <= 3'b000;
      LsuL1Plugin_logic_refill_read_hadError <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_0_valid <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_0_busy <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_1_valid <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_1_busy <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_2_valid <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_2_busy <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_3_valid <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_3_busy <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_4_valid <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_4_busy <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_5_valid <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_5_busy <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_6_valid <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_6_busy <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_7_valid <= 1'b0;
      LsuL1Plugin_logic_writeback_slots_7_busy <= 1'b0;
      LsuL1Plugin_logic_writeback_read_arbiter_lock <= 8'h0;
      LsuL1Plugin_logic_writeback_read_wordIndex <= 3'b000;
      LsuL1Plugin_logic_writeback_read_slotReadLast_valid <= 1'b0;
      LsuL1Plugin_logic_writeback_write_arbiter_lock <= 8'h0;
      LsuL1Plugin_logic_writeback_write_wordIndex <= 3'b000;
      LsuL1Plugin_logic_writeback_write_bufferRead_rValid <= 1'b0;
      LsuL1Plugin_logic_lsu_rb1_onBanks_0_busyReg <= 1'b0;
      LsuL1Plugin_logic_lsu_rb1_onBanks_1_busyReg <= 1'b0;
      LsuL1Plugin_logic_lsu_ctrl_hazardReg <= 1'b0;
      LsuL1Plugin_logic_lsu_ctrl_flushHazardReg <= 1'b0;
      LsuL1Plugin_logic_initializer_counter <= 7'h0;
      LsuL1Plugin_logic_initializerMem_counter <= 10'h0;
      PcPlugin_logic_harts_0_self_id <= 10'h0;
      PcPlugin_logic_harts_0_self_increment <= 1'b0;
      PcPlugin_logic_harts_0_self_fault <= 1'b0;
      PcPlugin_logic_harts_0_self_state <= 32'h80000000;
      PcPlugin_logic_harts_0_holdReg <= 1'b1;
      CsrAccessPlugin_logic_fsm_inject_unfreeze <= 1'b0;
      CsrAccessPlugin_logic_fsm_inject_flushReg <= 1'b0;
      CsrAccessPlugin_logic_fsm_inject_sampled <= 1'b0;
      HistoryPlugin_logic_onFetch_value <= 12'h0;
      LsuPlugin_logic_storeBuffer_waitL1_valid <= 1'b0;
      LsuPlugin_logic_onAddress0_ls_storeId <= 12'h0;
      execute_ctrl3_up_LsuL1_SEL_lane0 <= 1'b0;
      execute_ctrl4_up_LsuL1_SEL_lane0 <= 1'b0;
      LsuPlugin_logic_onCtrl_io_tooEarly <= 1'b0;
      LsuPlugin_logic_onCtrl_io_allowIt <= 1'b0;
      LsuPlugin_logic_onCtrl_io_doItReg <= 1'b0;
      LsuPlugin_logic_onCtrl_io_cmdSent <= 1'b0;
      LsuPlugin_logic_bus_rsp_toStream_rValid <= 1'b0;
      LsuPlugin_logic_onCtrl_fenceTrap_doItReg <= 1'b0;
      LsuPlugin_logic_onCtrl_hartRegulation_valid <= 1'b0;
      LsuPlugin_logic_onCtrl_commitProbeToken <= 1'b0;
      LsuPlugin_logic_storeBuffer_ops_pip_node_1_valid <= 1'b0;
      LsuPlugin_logic_storeBuffer_ops_pip_node_2_valid <= 1'b0;
      LsuL1Plugin_logic_bus_toTilelink_nonCoherent_onA_lock <= 1'b0;
      LsuL1TileLinkPlugin_logic_down_a_tracker_beat <= 3'b000;
      CsrRamPlugin_logic_readLogic_ohReg <= 3'b000;
      CsrRamPlugin_logic_readLogic_busy <= 1'b0;
      CsrRamPlugin_logic_flush_counter <= 4'b0000;
      execute_ctrl1_up_LANE_SEL_lane0 <= 1'b0;
      execute_ctrl2_up_LANE_SEL_lane0 <= 1'b0;
      execute_ctrl3_up_LANE_SEL_lane0 <= 1'b0;
      execute_ctrl4_up_LANE_SEL_lane0 <= 1'b0;
      execute_ctrl5_up_LANE_SEL_lane0 <= 1'b0;
      PrefetcherRptPlugin_logic_initializer_counter <= 8'h0;
      PrefetcherRptPlugin_logic_pip_node_1_valid <= 1'b0;
      PrefetcherRptPlugin_logic_pip_node_2_valid <= 1'b0;
      fetch_logic_ctrls_0_down_isValid_regNext <= 1'b0;
      fetch_logic_ctrls_1_down_isValid_regNext <= 1'b0;
      fetch_logic_ctrls_2_down_isValid_regNext <= 1'b0;
      decode_ctrls_0_up_LANE_SEL_0_regNext <= 1'b0;
      decode_ctrls_1_up_LANE_SEL_0_regNext_1 <= 1'b0;
      decode_ctrls_0_up_LANE_SEL_1_regNext <= 1'b0;
      decode_ctrls_1_up_LANE_SEL_1_regNext_1 <= 1'b0;
      decode_ctrls_1_up_LANE_SEL_0_regNext_2 <= 1'b0;
      decode_ctrls_1_up_LANE_SEL_1_regNext_2 <= 1'b0;
      execute_ctrl0_down_LANE_SEL_lane0_regNext <= 1'b0;
      execute_ctrl0_down_LANE_SEL_lane1_regNext <= 1'b0;
      execute_ctrl1_up_LANE_SEL_lane1 <= 1'b0;
      execute_ctrl2_up_LANE_SEL_lane1 <= 1'b0;
      execute_ctrl3_up_LANE_SEL_lane1 <= 1'b0;
      execute_ctrl4_up_LANE_SEL_lane1 <= 1'b0;
      execute_ctrl5_up_LANE_SEL_lane1 <= 1'b0;
      integer_RegFilePlugin_logic_initalizer_counter <= 6'h0;
      execute_ctrl2_down_LANE_SEL_lane0_regNext <= 1'b0;
      execute_ctrl3_down_LANE_SEL_lane0_regNext <= 1'b0;
      execute_ctrl4_down_LANE_SEL_lane0_regNext <= 1'b0;
      execute_ctrl5_down_LANE_SEL_lane0_regNext <= 1'b0;
      execute_ctrl2_down_LANE_SEL_lane1_regNext <= 1'b0;
      execute_ctrl3_down_LANE_SEL_lane1_regNext <= 1'b0;
      execute_ctrl4_down_LANE_SEL_lane1_regNext <= 1'b0;
      execute_ctrl5_down_LANE_SEL_lane1_regNext <= 1'b0;
      _zz_WhiteboxerPlugin_logic_perf_executeFreezedCounter_2 <= 60'h0;
      _zz_WhiteboxerPlugin_logic_perf_dispatchHazardsCounter_2 <= 60'h0;
      _zz_WhiteboxerPlugin_logic_perf_candidatesCountCounters_0_2 <= 60'h0;
      _zz_WhiteboxerPlugin_logic_perf_candidatesCountCounters_1_2 <= 60'h0;
      _zz_WhiteboxerPlugin_logic_perf_candidatesCountCounters_2_2 <= 60'h0;
      _zz_WhiteboxerPlugin_logic_perf_candidatesCountCounters_3_2 <= 60'h0;
      _zz_WhiteboxerPlugin_logic_perf_dispatchFeedCounters_0_2 <= 60'h0;
      _zz_WhiteboxerPlugin_logic_perf_dispatchFeedCounters_1_2 <= 60'h0;
      _zz_WhiteboxerPlugin_logic_perf_dispatchFeedCounters_2_2 <= 60'h0;
      fetch_logic_ctrls_1_up_valid <= 1'b0;
      fetch_logic_ctrls_2_up_valid <= 1'b0;
      decode_ctrls_1_up_valid <= 1'b0;
      PerformanceCounterPlugin_logic_fsm_stateReg <= PerformanceCounterPlugin_logic_fsm_BOOT;
      TrapPlugin_logic_harts_0_trap_fsm_stateReg <= TrapPlugin_logic_harts_0_trap_fsm_RESET;
      CsrAccessPlugin_logic_fsm_stateReg <= CsrAccessPlugin_logic_fsm_IDLE;
      LsuPlugin_logic_flusher_stateReg <= LsuPlugin_logic_flusher_IDLE;
    end else begin
      PrefetcherRptPlugin_logic_counter <= ((! PrefetcherRptPlugin_logic_queued_ready) ? _zz_PrefetcherRptPlugin_logic_counter : 3'b000);
      if(PrefetcherRptPlugin_logic_pip2_node_0_isReady) begin
        PrefetcherRptPlugin_logic_pip2_node_1_valid <= PrefetcherRptPlugin_logic_pip2_node_0_isValid;
      end
      _zz_11 <= (3'b010 < PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_occupancy);
      if(early0_DivPlugin_logic_processing_div_io_cmd_fire) begin
        early0_DivPlugin_logic_processing_cmdSent <= 1'b1;
      end
      if(execute_ctrl2_down_isReady) begin
        early0_DivPlugin_logic_processing_cmdSent <= 1'b0;
      end
      early0_DivPlugin_logic_processing_unscheduleRequest <= execute_lane0_ctrls_2_upIsCancel;
      if(execute_ctrl2_down_isReady) begin
        early0_DivPlugin_logic_processing_unscheduleRequest <= 1'b0;
      end
      if(PrivilegedPlugin_logic_harts_0_xretAwayFromMachine) begin
        PrivilegedPlugin_logic_harts_0_m_status_mprv <= 1'b0;
      end
      PrivilegedPlugin_logic_harts_0_m_ip_meip <= PrivilegedPlugin_logic_harts_0_int_m_external;
      PrivilegedPlugin_logic_harts_0_m_ip_mtip <= PrivilegedPlugin_logic_harts_0_int_m_timer;
      PrivilegedPlugin_logic_harts_0_m_ip_msip <= PrivilegedPlugin_logic_harts_0_int_m_software;
      if(FetchL1Plugin_logic_invalidate_done) begin
        FetchL1Plugin_logic_invalidate_firstEver <= 1'b0;
      end
      if(when_FetchL1Plugin_l211) begin
        FetchL1Plugin_logic_invalidate_counter <= FetchL1Plugin_logic_invalidate_counterIncr;
      end
      if(when_FetchL1Plugin_l218) begin
        FetchL1Plugin_logic_invalidate_counter <= 8'h0;
      end
      if(when_FetchL1Plugin_l262) begin
        if(_zz_24) begin
          FetchL1Plugin_logic_refill_slots_0_valid <= 1'b1;
          FetchL1Plugin_logic_refill_slots_0_cmdSent <= 1'b0;
        end
        if(_zz_when) begin
          FetchL1Plugin_logic_refill_slots_1_valid <= 1'b1;
          FetchL1Plugin_logic_refill_slots_1_cmdSent <= 1'b0;
        end
        if(_zz_when_1) begin
          FetchL1Plugin_logic_refill_slots_2_valid <= 1'b1;
          FetchL1Plugin_logic_refill_slots_2_cmdSent <= 1'b0;
        end
        if(_zz_when_2) begin
          FetchL1Plugin_logic_refill_slots_3_valid <= 1'b1;
          FetchL1Plugin_logic_refill_slots_3_cmdSent <= 1'b0;
        end
        if(_zz_when_3) begin
          FetchL1Plugin_logic_refill_slots_4_valid <= 1'b1;
          FetchL1Plugin_logic_refill_slots_4_cmdSent <= 1'b0;
        end
        if(_zz_when_4) begin
          FetchL1Plugin_logic_refill_slots_5_valid <= 1'b1;
          FetchL1Plugin_logic_refill_slots_5_cmdSent <= 1'b0;
        end
        if(_zz_when_5) begin
          FetchL1Plugin_logic_refill_slots_6_valid <= 1'b1;
          FetchL1Plugin_logic_refill_slots_6_cmdSent <= 1'b0;
        end
        if(_zz_when_6) begin
          FetchL1Plugin_logic_refill_slots_7_valid <= 1'b1;
          FetchL1Plugin_logic_refill_slots_7_cmdSent <= 1'b0;
        end
        FetchL1Plugin_logic_refill_pushCounter <= (FetchL1Plugin_logic_refill_pushCounter + 32'h00000001);
      end
      if(FetchL1Plugin_logic_bus_cmd_valid) begin
        FetchL1Plugin_logic_refill_onCmd_locked <= 1'b1;
      end
      if(FetchL1Plugin_logic_bus_cmd_ready) begin
        FetchL1Plugin_logic_refill_onCmd_locked <= 1'b0;
      end
      if(FetchL1Plugin_logic_bus_cmd_ready) begin
        if(_zz_FetchL1Plugin_logic_bus_cmd_payload_address) begin
          FetchL1Plugin_logic_refill_slots_0_cmdSent <= 1'b1;
        end
        if(_zz_FetchL1Plugin_logic_bus_cmd_payload_address_1) begin
          FetchL1Plugin_logic_refill_slots_1_cmdSent <= 1'b1;
        end
        if(_zz_FetchL1Plugin_logic_bus_cmd_payload_address_2) begin
          FetchL1Plugin_logic_refill_slots_2_cmdSent <= 1'b1;
        end
        if(_zz_FetchL1Plugin_logic_bus_cmd_payload_address_3) begin
          FetchL1Plugin_logic_refill_slots_3_cmdSent <= 1'b1;
        end
        if(_zz_FetchL1Plugin_logic_bus_cmd_payload_address_4) begin
          FetchL1Plugin_logic_refill_slots_4_cmdSent <= 1'b1;
        end
        if(_zz_FetchL1Plugin_logic_bus_cmd_payload_address_5) begin
          FetchL1Plugin_logic_refill_slots_5_cmdSent <= 1'b1;
        end
        if(_zz_FetchL1Plugin_logic_bus_cmd_payload_address_6) begin
          FetchL1Plugin_logic_refill_slots_6_cmdSent <= 1'b1;
        end
        if(_zz_FetchL1Plugin_logic_bus_cmd_payload_address_7) begin
          FetchL1Plugin_logic_refill_slots_7_cmdSent <= 1'b1;
        end
      end
      if(FetchL1Plugin_logic_bus_rsp_fire) begin
        FetchL1Plugin_logic_refill_onRsp_firstCycle <= 1'b0;
      end
      if(FetchL1Plugin_logic_bus_rsp_valid) begin
        FetchL1Plugin_logic_refill_onRsp_wordIndex <= (FetchL1Plugin_logic_refill_onRsp_wordIndex + 3'b001);
        if(when_FetchL1Plugin_l337) begin
          FetchL1Plugin_logic_refill_onRsp_firstCycle <= 1'b1;
          case(FetchL1Plugin_logic_bus_rsp_payload_id)
            3'b000 : begin
              FetchL1Plugin_logic_refill_slots_0_valid <= 1'b0;
            end
            3'b001 : begin
              FetchL1Plugin_logic_refill_slots_1_valid <= 1'b0;
            end
            3'b010 : begin
              FetchL1Plugin_logic_refill_slots_2_valid <= 1'b0;
            end
            3'b011 : begin
              FetchL1Plugin_logic_refill_slots_3_valid <= 1'b0;
            end
            3'b100 : begin
              FetchL1Plugin_logic_refill_slots_4_valid <= 1'b0;
            end
            3'b101 : begin
              FetchL1Plugin_logic_refill_slots_5_valid <= 1'b0;
            end
            3'b110 : begin
              FetchL1Plugin_logic_refill_slots_6_valid <= 1'b0;
            end
            default : begin
              FetchL1Plugin_logic_refill_slots_7_valid <= 1'b0;
            end
          endcase
        end
      end
      if(FetchL1Plugin_logic_hazard_writeCheck) begin
        FetchL1Plugin_logic_hazard_checkHold <= 1'b1;
      end
      if(fetch_logic_ctrls_1_up_isReady) begin
        FetchL1Plugin_logic_hazard_checkHold <= 1'b0;
      end
      if(_zz_fetch_logic_ctrls_2_FetchL1Plugin_logic_HAZARD_bypass) begin
        _zz_fetch_logic_ctrls_2_FetchL1Plugin_logic_HAZARD_bypass_1 <= 1'b1;
      end
      if(fetch_logic_ctrls_2_up_isReady) begin
        _zz_fetch_logic_ctrls_2_FetchL1Plugin_logic_HAZARD_bypass_1 <= 1'b0;
      end
      FetchL1Plugin_logic_ctrl_plruLogic_buffer_regNext_valid <= FetchL1Plugin_logic_ctrl_plruLogic_buffer_valid;
      if(FetchL1Plugin_logic_trapPort_valid) begin
        FetchL1Plugin_logic_ctrl_trapSent <= 1'b1;
      end
      if(fetch_logic_ctrls_2_up_isCancel) begin
        FetchL1Plugin_logic_ctrl_trapSent <= 1'b0;
      end
      if(fetch_logic_ctrls_2_up_isValid) begin
        FetchL1Plugin_logic_ctrl_firstCycle <= 1'b0;
      end
      if(when_FetchL1Plugin_l656) begin
        FetchL1Plugin_logic_ctrl_firstCycle <= 1'b1;
      end
      if(when_FetchL1Plugin_l664) begin
        FetchL1Plugin_logic_ctrl_onEvents_waiting <= 1'b0;
      end
      if(FetchL1Plugin_logic_events_miss) begin
        FetchL1Plugin_logic_ctrl_onEvents_waiting <= 1'b1;
      end
      `ifndef SYNTHESIS
        `ifdef FORMAL
          assert((! ((|{FetchL1Plugin_logic_refill_slots_7_valid,FetchL1Plugin_logic_refill_slots_6_valid,FetchL1Plugin_logic_refill_slots_5_valid,FetchL1Plugin_logic_refill_slots_4_valid,FetchL1Plugin_logic_refill_slots_3_valid,FetchL1Plugin_logic_refill_slots_2_valid,FetchL1Plugin_logic_refill_slots_1_valid,FetchL1Plugin_logic_refill_slots_0_valid}) && (! FetchL1Plugin_logic_invalidate_done)))); // FetchL1Plugin.scala:L671
        `else
          if(!(! ((|{FetchL1Plugin_logic_refill_slots_7_valid,FetchL1Plugin_logic_refill_slots_6_valid,FetchL1Plugin_logic_refill_slots_5_valid,FetchL1Plugin_logic_refill_slots_4_valid,FetchL1Plugin_logic_refill_slots_3_valid,FetchL1Plugin_logic_refill_slots_2_valid,FetchL1Plugin_logic_refill_slots_1_valid,FetchL1Plugin_logic_refill_slots_0_valid}) && (! FetchL1Plugin_logic_invalidate_done)))) begin
            $display("FAILURE "); // FetchL1Plugin.scala:L671
            $finish;
          end
        `endif
      `endif
      if(FetchL1Plugin_logic_initializer_busy) begin
        FetchL1Plugin_logic_initializer_counter <= (FetchL1Plugin_logic_initializer_counter + 11'h001);
      end
      BtbPlugin_logic_ras_ptr_push <= (_zz_BtbPlugin_logic_ras_ptr_push - _zz_BtbPlugin_logic_ras_ptr_push_3);
      if(when_PerformanceCounterPlugin_l47) begin
        PerformanceCounterPlugin_logic_ignoreNextCommit <= 1'b0;
      end
      PerformanceCounterPlugin_logic_counters_cycle_value <= (PerformanceCounterPlugin_logic_counters_cycle_value + _zz_PerformanceCounterPlugin_logic_counters_cycle_value);
      _zz_PerformanceCounterPlugin_logic_counters_instret_value <= ((! (PerformanceCounterPlugin_logic_counters_instret_mcountinhibit || PerformanceCounterPlugin_logic_stopCount)) ? PerformanceCounterPlugin_logic_commitCount : 2'b00);
      PerformanceCounterPlugin_logic_counters_instret_value <= (PerformanceCounterPlugin_logic_counters_instret_value + _zz_PerformanceCounterPlugin_logic_counters_instret_value_1);
      if(when_AlignerPlugin_l171) begin
        AlignerPlugin_logic_feeder_harts_0_dopId <= (decode_ctrls_0_down_Decode_DOP_ID_1 + 10'h001);
      end
      if(AlignerPlugin_logic_buffer_downFire) begin
        AlignerPlugin_logic_buffer_mask <= (AlignerPlugin_logic_buffer_mask & (~ AlignerPlugin_logic_buffer_usedMask[3 : 0]));
        AlignerPlugin_logic_buffer_last <= (AlignerPlugin_logic_buffer_last & (~ AlignerPlugin_logic_buffer_usedMask[3 : 0]));
      end
      if(when_AlignerPlugin_l256) begin
        AlignerPlugin_logic_buffer_mask <= (fetch_logic_ctrls_2_down_AlignerPlugin_logic_FETCH_MASK & (~ (AlignerPlugin_logic_buffer_downFire ? AlignerPlugin_logic_buffer_usedMask[7 : 4] : 4'b0000)));
        AlignerPlugin_logic_buffer_trap <= fetch_logic_ctrls_2_down_TRAP;
        AlignerPlugin_logic_buffer_last <= fetch_logic_ctrls_2_down_AlignerPlugin_logic_FETCH_LAST;
      end
      LsuPlugin_logic_storeBuffer_ops_popPtr <= (LsuPlugin_logic_storeBuffer_ops_popPtr + _zz_LsuPlugin_logic_storeBuffer_ops_popPtr);
      if(LsuPlugin_logic_storeBuffer_push_valid) begin
        LsuPlugin_logic_storeBuffer_ops_pushPtr <= (LsuPlugin_logic_storeBuffer_ops_pushPtr + _zz_LsuPlugin_logic_storeBuffer_ops_pushPtr);
        if(_zz_when_7) begin
          LsuPlugin_logic_storeBuffer_slots_0_valid <= 1'b1;
        end
        if(_zz_when_8) begin
          LsuPlugin_logic_storeBuffer_slots_1_valid <= 1'b1;
        end
        if(_zz_when_9) begin
          LsuPlugin_logic_storeBuffer_slots_2_valid <= 1'b1;
        end
        if(_zz_when_10) begin
          LsuPlugin_logic_storeBuffer_slots_3_valid <= 1'b1;
        end
      end
      if(when_LsuPlugin_l379) begin
        LsuPlugin_logic_storeBuffer_holdHart_waitIt <= 1'b0;
      end
      if(when_DecoderPlugin_l148) begin
        DecoderPlugin_logic_harts_0_uopId <= (DecoderPlugin_logic_harts_0_uopId + 16'h0002);
      end
      if(when_DecoderPlugin_l156) begin
        DecoderPlugin_logic_interrupt_buffered <= DecoderPlugin_logic_interrupt_async;
      end
      decode_ctrls_1_up_LANE_SEL_0_regNext <= decode_ctrls_1_up_LANE_SEL_0;
      if(when_CtrlLaneApi_l50) begin
        decode_ctrls_1_up_LANE_SEL_0_regNext <= 1'b0;
      end
      decode_ctrls_1_up_LANE_SEL_1_regNext <= decode_ctrls_1_up_LANE_SEL_1;
      if(when_CtrlLaneApi_l50_1) begin
        decode_ctrls_1_up_LANE_SEL_1_regNext <= 1'b0;
      end
      if(DispatchPlugin_logic_feeds_0_sending) begin
        DispatchPlugin_logic_feeds_0_sent <= 1'b1;
      end
      if(decode_ctrls_1_up_isMoving) begin
        DispatchPlugin_logic_feeds_0_sent <= 1'b0;
      end
      if(DispatchPlugin_logic_feeds_1_sending) begin
        DispatchPlugin_logic_feeds_1_sent <= 1'b1;
      end
      if(decode_ctrls_1_up_isMoving) begin
        DispatchPlugin_logic_feeds_1_sent <= 1'b0;
      end
      if(when_DispatchPlugin_l385) begin
        DispatchPlugin_logic_slots_0_ctx_valid <= 1'b0;
      end
      if(late0_BranchPlugin_logic_jumpLogic_learn_ready) begin
        late0_BranchPlugin_logic_jumpLogic_learn_rValid <= late0_BranchPlugin_logic_jumpLogic_learn_valid;
      end
      if(late1_BranchPlugin_logic_jumpLogic_learn_ready) begin
        late1_BranchPlugin_logic_jumpLogic_learn_rValid <= late1_BranchPlugin_logic_jumpLogic_learn_valid;
      end
      if(when_CsrRamPlugin_l92) begin
        CsrRamPlugin_csrMapper_fired <= 1'b1;
      end
      if(CsrAccessPlugin_bus_write_moving) begin
        CsrRamPlugin_csrMapper_fired <= 1'b0;
      end
      if(GSharePlugin_logic_initializer_busy) begin
        GSharePlugin_logic_initializer_counter <= (GSharePlugin_logic_initializer_counter + 13'h0001);
      end
      `ifndef SYNTHESIS
        `ifdef FORMAL
          assert((! (fetch_logic_ctrls_1_up_isValid && fetch_logic_ctrls_1_down_BtbPlugin_logic_readCmd_HAZARDS[0]))); // BtbPlugin.scala:L215
        `else
          if(!(! (fetch_logic_ctrls_1_up_isValid && fetch_logic_ctrls_1_down_BtbPlugin_logic_readCmd_HAZARDS[0]))) begin
            $display("FAILURE "); // BtbPlugin.scala:L215
            $finish;
          end
        `endif
      `endif
      `ifndef SYNTHESIS
        `ifdef FORMAL
          assert((! (fetch_logic_ctrls_1_up_isValid && fetch_logic_ctrls_1_down_BtbPlugin_logic_readCmd_HAZARDS[1]))); // BtbPlugin.scala:L215
        `else
          if(!(! (fetch_logic_ctrls_1_up_isValid && fetch_logic_ctrls_1_down_BtbPlugin_logic_readCmd_HAZARDS[1]))) begin
            $display("FAILURE "); // BtbPlugin.scala:L215
            $finish;
          end
        `endif
      `endif
      if(fetch_logic_ctrls_1_up_isValid) begin
        BtbPlugin_logic_applyIt_correctionSent <= 1'b1;
      end
      if(when_BtbPlugin_l233) begin
        BtbPlugin_logic_applyIt_correctionSent <= 1'b0;
      end
      if(BtbPlugin_logic_initializer_busy) begin
        BtbPlugin_logic_initializer_counter <= (BtbPlugin_logic_initializer_counter + 9'h001);
      end
      if(AlignerPlugin_logic_buffer_flushIt) begin
        AlignerPlugin_logic_buffer_mask <= 4'b0000;
        AlignerPlugin_logic_buffer_last <= 4'b0000;
      end
      if(DispatchPlugin_logic_slotsFeeds_doIt) begin
        DispatchPlugin_logic_slots_0_ctx_valid <= _zz_DispatchPlugin_logic_slots_0_ctx_valid_4[0];
      end
      if(PerformanceCounterPlugin_logic_fsm_csrReadCmd_fire) begin
        PerformanceCounterPlugin_logic_csrRead_fired <= 1'b1;
      end
      if(CsrAccessPlugin_bus_read_moving) begin
        PerformanceCounterPlugin_logic_csrRead_fired <= 1'b0;
      end
      if(PerformanceCounterPlugin_logic_fsm_csrWriteCmd_fire) begin
        PerformanceCounterPlugin_logic_csrWrite_fired <= 1'b1;
      end
      if(CsrAccessPlugin_bus_write_moving) begin
        PerformanceCounterPlugin_logic_csrWrite_fired <= 1'b0;
      end
      TrapPlugin_logic_harts_0_interrupt_validBuffer <= TrapPlugin_logic_harts_0_interrupt_valid;
      if(LsuL1Plugin_logic_refill_slots_0_loadedSet) begin
        LsuL1Plugin_logic_refill_slots_0_loaded <= 1'b1;
      end
      if(LsuL1Plugin_logic_refill_slots_0_fire) begin
        LsuL1Plugin_logic_refill_slots_0_valid <= 1'b0;
      end
      if(LsuL1Plugin_logic_refill_slots_1_loadedSet) begin
        LsuL1Plugin_logic_refill_slots_1_loaded <= 1'b1;
      end
      if(LsuL1Plugin_logic_refill_slots_1_fire) begin
        LsuL1Plugin_logic_refill_slots_1_valid <= 1'b0;
      end
      if(LsuL1Plugin_logic_refill_slots_2_loadedSet) begin
        LsuL1Plugin_logic_refill_slots_2_loaded <= 1'b1;
      end
      if(LsuL1Plugin_logic_refill_slots_2_fire) begin
        LsuL1Plugin_logic_refill_slots_2_valid <= 1'b0;
      end
      if(LsuL1Plugin_logic_refill_slots_3_loadedSet) begin
        LsuL1Plugin_logic_refill_slots_3_loaded <= 1'b1;
      end
      if(LsuL1Plugin_logic_refill_slots_3_fire) begin
        LsuL1Plugin_logic_refill_slots_3_valid <= 1'b0;
      end
      if(LsuL1Plugin_logic_refill_slots_4_loadedSet) begin
        LsuL1Plugin_logic_refill_slots_4_loaded <= 1'b1;
      end
      if(LsuL1Plugin_logic_refill_slots_4_fire) begin
        LsuL1Plugin_logic_refill_slots_4_valid <= 1'b0;
      end
      if(LsuL1Plugin_logic_refill_slots_5_loadedSet) begin
        LsuL1Plugin_logic_refill_slots_5_loaded <= 1'b1;
      end
      if(LsuL1Plugin_logic_refill_slots_5_fire) begin
        LsuL1Plugin_logic_refill_slots_5_valid <= 1'b0;
      end
      if(LsuL1Plugin_logic_refill_slots_6_loadedSet) begin
        LsuL1Plugin_logic_refill_slots_6_loaded <= 1'b1;
      end
      if(LsuL1Plugin_logic_refill_slots_6_fire) begin
        LsuL1Plugin_logic_refill_slots_6_valid <= 1'b0;
      end
      if(LsuL1Plugin_logic_refill_slots_7_loadedSet) begin
        LsuL1Plugin_logic_refill_slots_7_loaded <= 1'b1;
      end
      if(LsuL1Plugin_logic_refill_slots_7_fire) begin
        LsuL1Plugin_logic_refill_slots_7_valid <= 1'b0;
      end
      if(LsuL1Plugin_logic_refill_push_valid) begin
        LsuL1Plugin_logic_refill_pushCounter <= (LsuL1Plugin_logic_refill_pushCounter + 32'h00000001);
      end
      if(when_LsuL1Plugin_l384) begin
        LsuL1Plugin_logic_refill_slots_0_valid <= 1'b1;
        LsuL1Plugin_logic_refill_slots_0_loaded <= 1'b0;
      end
      if(when_LsuL1Plugin_l384_1) begin
        LsuL1Plugin_logic_refill_slots_1_valid <= 1'b1;
        LsuL1Plugin_logic_refill_slots_1_loaded <= 1'b0;
      end
      if(when_LsuL1Plugin_l384_2) begin
        LsuL1Plugin_logic_refill_slots_2_valid <= 1'b1;
        LsuL1Plugin_logic_refill_slots_2_loaded <= 1'b0;
      end
      if(when_LsuL1Plugin_l384_3) begin
        LsuL1Plugin_logic_refill_slots_3_valid <= 1'b1;
        LsuL1Plugin_logic_refill_slots_3_loaded <= 1'b0;
      end
      if(when_LsuL1Plugin_l384_4) begin
        LsuL1Plugin_logic_refill_slots_4_valid <= 1'b1;
        LsuL1Plugin_logic_refill_slots_4_loaded <= 1'b0;
      end
      if(when_LsuL1Plugin_l384_5) begin
        LsuL1Plugin_logic_refill_slots_5_valid <= 1'b1;
        LsuL1Plugin_logic_refill_slots_5_loaded <= 1'b0;
      end
      if(when_LsuL1Plugin_l384_6) begin
        LsuL1Plugin_logic_refill_slots_6_valid <= 1'b1;
        LsuL1Plugin_logic_refill_slots_6_loaded <= 1'b0;
      end
      if(when_LsuL1Plugin_l384_7) begin
        LsuL1Plugin_logic_refill_slots_7_valid <= 1'b1;
        LsuL1Plugin_logic_refill_slots_7_loaded <= 1'b0;
      end
      LsuL1Plugin_logic_refill_read_arbiter_lock <= LsuL1Plugin_logic_refill_read_arbiter_oh;
      if(LsuL1Plugin_logic_bus_read_cmd_fire) begin
        LsuL1Plugin_logic_refill_read_arbiter_lock <= 8'h0;
      end
      if(LsuL1Plugin_logic_bus_read_rsp_valid) begin
        `ifndef SYNTHESIS
          `ifdef FORMAL
            assert(LsuL1Plugin_logic_refill_read_writeReservation_win); // LsuL1Plugin.scala:L434
          `else
            if(!LsuL1Plugin_logic_refill_read_writeReservation_win) begin
              $display("FAILURE "); // LsuL1Plugin.scala:L434
              $finish;
            end
          `endif
        `endif
      end
      if(when_LsuL1Plugin_l455) begin
        LsuL1Plugin_logic_refill_read_hadError <= 1'b1;
      end
      if(LsuL1Plugin_logic_bus_read_rsp_valid) begin
        `ifndef SYNTHESIS
          `ifdef FORMAL
            assert(LsuL1Plugin_logic_refill_read_reservation_win); // LsuL1Plugin.scala:L464
          `else
            if(!LsuL1Plugin_logic_refill_read_reservation_win) begin
              $display("FAILURE "); // LsuL1Plugin.scala:L464
              $finish;
            end
          `endif
        `endif
        if(LsuL1Plugin_logic_refill_read_rspWithData) begin
          LsuL1Plugin_logic_refill_read_wordIndex <= (LsuL1Plugin_logic_refill_read_wordIndex + 3'b001);
        end
        if(when_LsuL1Plugin_l468) begin
          LsuL1Plugin_logic_refill_read_hadError <= 1'b0;
        end
      end
      if(LsuL1Plugin_logic_writeback_slots_0_fire) begin
        LsuL1Plugin_logic_writeback_slots_0_busy <= 1'b0;
      end
      if(when_LsuL1Plugin_l535) begin
        LsuL1Plugin_logic_writeback_slots_0_valid <= 1'b0;
      end
      if(LsuL1Plugin_logic_writeback_slots_1_fire) begin
        LsuL1Plugin_logic_writeback_slots_1_busy <= 1'b0;
      end
      if(when_LsuL1Plugin_l535_1) begin
        LsuL1Plugin_logic_writeback_slots_1_valid <= 1'b0;
      end
      if(LsuL1Plugin_logic_writeback_slots_2_fire) begin
        LsuL1Plugin_logic_writeback_slots_2_busy <= 1'b0;
      end
      if(when_LsuL1Plugin_l535_2) begin
        LsuL1Plugin_logic_writeback_slots_2_valid <= 1'b0;
      end
      if(LsuL1Plugin_logic_writeback_slots_3_fire) begin
        LsuL1Plugin_logic_writeback_slots_3_busy <= 1'b0;
      end
      if(when_LsuL1Plugin_l535_3) begin
        LsuL1Plugin_logic_writeback_slots_3_valid <= 1'b0;
      end
      if(LsuL1Plugin_logic_writeback_slots_4_fire) begin
        LsuL1Plugin_logic_writeback_slots_4_busy <= 1'b0;
      end
      if(when_LsuL1Plugin_l535_4) begin
        LsuL1Plugin_logic_writeback_slots_4_valid <= 1'b0;
      end
      if(LsuL1Plugin_logic_writeback_slots_5_fire) begin
        LsuL1Plugin_logic_writeback_slots_5_busy <= 1'b0;
      end
      if(when_LsuL1Plugin_l535_5) begin
        LsuL1Plugin_logic_writeback_slots_5_valid <= 1'b0;
      end
      if(LsuL1Plugin_logic_writeback_slots_6_fire) begin
        LsuL1Plugin_logic_writeback_slots_6_busy <= 1'b0;
      end
      if(when_LsuL1Plugin_l535_6) begin
        LsuL1Plugin_logic_writeback_slots_6_valid <= 1'b0;
      end
      if(LsuL1Plugin_logic_writeback_slots_7_fire) begin
        LsuL1Plugin_logic_writeback_slots_7_busy <= 1'b0;
      end
      if(when_LsuL1Plugin_l535_7) begin
        LsuL1Plugin_logic_writeback_slots_7_valid <= 1'b0;
      end
      if(when_LsuL1Plugin_l561) begin
        LsuL1Plugin_logic_writeback_slots_0_valid <= 1'b1;
        LsuL1Plugin_logic_writeback_slots_0_busy <= 1'b1;
      end
      if(when_LsuL1Plugin_l561_1) begin
        LsuL1Plugin_logic_writeback_slots_1_valid <= 1'b1;
        LsuL1Plugin_logic_writeback_slots_1_busy <= 1'b1;
      end
      if(when_LsuL1Plugin_l561_2) begin
        LsuL1Plugin_logic_writeback_slots_2_valid <= 1'b1;
        LsuL1Plugin_logic_writeback_slots_2_busy <= 1'b1;
      end
      if(when_LsuL1Plugin_l561_3) begin
        LsuL1Plugin_logic_writeback_slots_3_valid <= 1'b1;
        LsuL1Plugin_logic_writeback_slots_3_busy <= 1'b1;
      end
      if(when_LsuL1Plugin_l561_4) begin
        LsuL1Plugin_logic_writeback_slots_4_valid <= 1'b1;
        LsuL1Plugin_logic_writeback_slots_4_busy <= 1'b1;
      end
      if(when_LsuL1Plugin_l561_5) begin
        LsuL1Plugin_logic_writeback_slots_5_valid <= 1'b1;
        LsuL1Plugin_logic_writeback_slots_5_busy <= 1'b1;
      end
      if(when_LsuL1Plugin_l561_6) begin
        LsuL1Plugin_logic_writeback_slots_6_valid <= 1'b1;
        LsuL1Plugin_logic_writeback_slots_6_busy <= 1'b1;
      end
      if(when_LsuL1Plugin_l561_7) begin
        LsuL1Plugin_logic_writeback_slots_7_valid <= 1'b1;
        LsuL1Plugin_logic_writeback_slots_7_busy <= 1'b1;
      end
      LsuL1Plugin_logic_writeback_read_arbiter_lock <= LsuL1Plugin_logic_writeback_read_arbiter_oh;
      LsuL1Plugin_logic_writeback_read_wordIndex <= (LsuL1Plugin_logic_writeback_read_wordIndex + _zz_LsuL1Plugin_logic_writeback_read_wordIndex);
      if(when_LsuL1Plugin_l610) begin
        LsuL1Plugin_logic_writeback_read_arbiter_lock <= 8'h0;
      end
      LsuL1Plugin_logic_writeback_read_slotReadLast_valid <= LsuL1Plugin_logic_writeback_read_slotRead_valid;
      LsuL1Plugin_logic_writeback_write_arbiter_lock <= LsuL1Plugin_logic_writeback_write_arbiter_oh;
      LsuL1Plugin_logic_writeback_write_wordIndex <= (LsuL1Plugin_logic_writeback_write_wordIndex + _zz_LsuL1Plugin_logic_writeback_write_wordIndex);
      if(when_LsuL1Plugin_l681) begin
        LsuL1Plugin_logic_writeback_write_arbiter_lock <= 8'h0;
      end
      if(LsuL1Plugin_logic_writeback_write_bufferRead_ready) begin
        LsuL1Plugin_logic_writeback_write_bufferRead_rValid <= LsuL1Plugin_logic_writeback_write_bufferRead_valid;
      end
      if(LsuL1Plugin_logic_banks_0_usedByWriteback) begin
        LsuL1Plugin_logic_lsu_rb1_onBanks_0_busyReg <= 1'b1;
      end
      if(when_LsuL1Plugin_l740) begin
        LsuL1Plugin_logic_lsu_rb1_onBanks_0_busyReg <= 1'b0;
      end
      if(LsuL1Plugin_logic_banks_1_usedByWriteback) begin
        LsuL1Plugin_logic_lsu_rb1_onBanks_1_busyReg <= 1'b1;
      end
      if(when_LsuL1Plugin_l740_1) begin
        LsuL1Plugin_logic_lsu_rb1_onBanks_1_busyReg <= 1'b0;
      end
      LsuL1Plugin_logic_lsu_ctrl_hazardReg <= (execute_ctrl4_down_LsuL1_HAZARD_lane0 && execute_freeze_valid);
      LsuL1Plugin_logic_lsu_ctrl_flushHazardReg <= (execute_ctrl4_down_LsuL1_FLUSH_HAZARD_lane0 && execute_freeze_valid);
      if(execute_ctrl4_down_LsuL1_SEL_lane0) begin
        `ifndef SYNTHESIS
          `ifdef FORMAL
            assert((_zz_51 <= 2'b01)); // LsuL1Plugin.scala:L906
          `else
            if(!(_zz_51 <= 2'b01)) begin
              $display("FAILURE Multiple way hit ???"); // LsuL1Plugin.scala:L906
              $finish;
            end
          `endif
        `endif
      end
      if(when_LsuL1Plugin_l928) begin
        `ifndef SYNTHESIS
          `ifdef FORMAL
            assert((_zz_53 < 2'b10)); // LsuL1Plugin.scala:L929
          `else
            if(!(_zz_53 < 2'b10)) begin
              $display("FAILURE "); // LsuL1Plugin.scala:L929
              $finish;
            end
          `endif
        `endif
      end
      if(when_LsuL1Plugin_l1236) begin
        LsuL1Plugin_logic_initializer_counter <= (LsuL1Plugin_logic_initializer_counter + 7'h01);
      end
      if(LsuL1Plugin_logic_initializerMem_busy) begin
        LsuL1Plugin_logic_initializerMem_counter <= (LsuL1Plugin_logic_initializerMem_counter + 10'h001);
      end
      PcPlugin_logic_harts_0_holdReg <= PcPlugin_logic_harts_0_holdComb;
      PcPlugin_logic_harts_0_self_state <= PcPlugin_logic_harts_0_output_payload_pc;
      PcPlugin_logic_harts_0_self_fault <= PcPlugin_logic_harts_0_output_payload_fault;
      PcPlugin_logic_harts_0_self_increment <= 1'b0;
      if(PcPlugin_logic_harts_0_output_fire) begin
        PcPlugin_logic_harts_0_self_increment <= 1'b1;
        PcPlugin_logic_harts_0_self_state[2 : 1] <= 2'b00;
      end
      if(fetch_logic_ctrls_0_up_isFiring) begin
        PcPlugin_logic_harts_0_self_id <= (PcPlugin_logic_harts_0_self_id + 10'h001);
      end
      `ifndef SYNTHESIS
        `ifdef FORMAL
          assert((! ((execute_ctrl2_up_LANE_SEL_lane0 && execute_ctrl2_down_CsrAccessPlugin_SEL_lane0) && execute_lane0_ctrls_2_upIsCancel))); // CsrAccessPlugin.scala:L151
        `else
          if(!(! ((execute_ctrl2_up_LANE_SEL_lane0 && execute_ctrl2_down_CsrAccessPlugin_SEL_lane0) && execute_lane0_ctrls_2_upIsCancel))) begin
            $display("FAILURE CsrAccessPlugin saw forbidden select && cancel request"); // CsrAccessPlugin.scala:L151
            $finish;
          end
        `endif
      `endif
      CsrAccessPlugin_logic_fsm_inject_unfreeze <= 1'b0;
      if(CsrAccessPlugin_logic_flushPort_valid) begin
        CsrAccessPlugin_logic_fsm_inject_flushReg <= 1'b1;
      end
      if(when_CsrAccessPlugin_l222) begin
        CsrAccessPlugin_logic_fsm_inject_flushReg <= 1'b0;
      end
      CsrAccessPlugin_logic_fsm_inject_sampled <= execute_freeze_valid;
      if(when_CsrAccessPlugin_l378) begin
        PrefetcherRptPlugin_logic_csr_disable <= CsrAccessPlugin_bus_write_bits[1];
      end
      if(when_CsrAccessPlugin_l378_1) begin
        PrivilegedPlugin_logic_harts_0_m_status_mpie <= CsrAccessPlugin_bus_write_bits[7];
        PrivilegedPlugin_logic_harts_0_m_status_mie <= CsrAccessPlugin_bus_write_bits[3];
        PrivilegedPlugin_logic_harts_0_m_status_mprv <= CsrAccessPlugin_bus_write_bits[17];
      end
      if(when_CsrAccessPlugin_l378_2) begin
        PrivilegedPlugin_logic_harts_0_m_cause_interrupt <= CsrAccessPlugin_bus_write_bits[31];
        PrivilegedPlugin_logic_harts_0_m_cause_code <= CsrAccessPlugin_bus_write_bits[4 : 0];
      end
      if(when_CsrAccessPlugin_l378_3) begin
        PerformanceCounterPlugin_logic_interrupt_ip <= CsrAccessPlugin_bus_write_bits[13];
      end
      if(when_CsrAccessPlugin_l378_4) begin
        PrivilegedPlugin_logic_harts_0_m_ie_meie <= CsrAccessPlugin_bus_write_bits[11];
        PrivilegedPlugin_logic_harts_0_m_ie_mtie <= CsrAccessPlugin_bus_write_bits[7];
        PrivilegedPlugin_logic_harts_0_m_ie_msie <= CsrAccessPlugin_bus_write_bits[3];
        PerformanceCounterPlugin_logic_interrupt_ie <= CsrAccessPlugin_bus_write_bits[13];
      end
      if(when_CsrAccessPlugin_l378_5) begin
        PrivilegedPlugin_logic_harts_0_m_counteren_tm <= CsrAccessPlugin_bus_write_bits[1];
        PerformanceCounterPlugin_logic_counters_cycle_mcounteren <= CsrAccessPlugin_bus_write_bits[0];
        PerformanceCounterPlugin_logic_counters_instret_mcounteren <= CsrAccessPlugin_bus_write_bits[2];
      end
      if(when_CsrAccessPlugin_l378_6) begin
        PerformanceCounterPlugin_logic_counters_cycle_mcountinhibit <= CsrAccessPlugin_bus_write_bits[0];
        PerformanceCounterPlugin_logic_counters_instret_mcountinhibit <= CsrAccessPlugin_bus_write_bits[2];
      end
      HistoryPlugin_logic_onFetch_value <= HistoryPlugin_logic_onFetch_valueNext;
      if(when_LsuPlugin_l307) begin
        LsuPlugin_logic_storeBuffer_waitL1_valid <= 1'b0;
      end
      LsuPlugin_logic_onAddress0_ls_storeId <= (LsuPlugin_logic_onAddress0_ls_storeId + _zz_LsuPlugin_logic_onAddress0_ls_storeId);
      LsuPlugin_logic_onCtrl_io_tooEarly <= 1'b1;
      if(execute_freeze_valid) begin
        LsuPlugin_logic_onCtrl_io_tooEarly <= 1'b0;
      end
      LsuPlugin_logic_onCtrl_io_allowIt <= 1'b0;
      if(when_LsuPlugin_l701) begin
        LsuPlugin_logic_onCtrl_io_allowIt <= 1'b1;
      end
      LsuPlugin_logic_onCtrl_io_doItReg <= LsuPlugin_logic_onCtrl_io_doIt;
      if(LsuPlugin_logic_bus_cmd_fire) begin
        LsuPlugin_logic_onCtrl_io_cmdSent <= 1'b1;
      end
      if(when_LsuPlugin_l705) begin
        LsuPlugin_logic_onCtrl_io_cmdSent <= 1'b0;
      end
      if(LsuPlugin_logic_bus_rsp_toStream_valid) begin
        LsuPlugin_logic_bus_rsp_toStream_rValid <= 1'b1;
      end
      if(LsuPlugin_logic_onCtrl_io_rsp_fire) begin
        LsuPlugin_logic_bus_rsp_toStream_rValid <= 1'b0;
      end
      if(LsuPlugin_logic_onCtrl_fenceTrap_doIt) begin
        LsuPlugin_logic_onCtrl_fenceTrap_doItReg <= 1'b1;
      end
      if(when_LsuPlugin_l983) begin
        LsuPlugin_logic_onCtrl_fenceTrap_doItReg <= 1'b0;
      end
      if(when_LsuPlugin_l1036) begin
        if(when_LsuPlugin_l1047) begin
          LsuPlugin_logic_storeBuffer_holdHart_waitIt <= 1'b1;
        end
      end
      if(when_LsuPlugin_l1082) begin
        if(LsuPlugin_logic_onCtrl_traps_l1Failed) begin
          LsuPlugin_logic_storeBuffer_ops_popPtr <= LsuPlugin_logic_storeBuffer_ops_freePtr;
          if(when_LsuPlugin_l1085) begin
            if(when_LsuPlugin_l311) begin
              LsuPlugin_logic_storeBuffer_waitL1_valid <= 1'b1;
            end
          end
        end else begin
          LsuPlugin_logic_storeBuffer_ops_freePtr <= (LsuPlugin_logic_storeBuffer_ops_freePtr + 6'h01);
          if(when_LsuPlugin_l1090) begin
            LsuPlugin_logic_storeBuffer_slots_0_valid <= 1'b0;
          end
          if(when_LsuPlugin_l1090_1) begin
            LsuPlugin_logic_storeBuffer_slots_1_valid <= 1'b0;
          end
          if(when_LsuPlugin_l1090_2) begin
            LsuPlugin_logic_storeBuffer_slots_2_valid <= 1'b0;
          end
          if(when_LsuPlugin_l1090_3) begin
            LsuPlugin_logic_storeBuffer_slots_3_valid <= 1'b0;
          end
        end
      end
      if(when_LsuPlugin_l307_1) begin
        LsuPlugin_logic_onCtrl_hartRegulation_valid <= 1'b0;
      end
      if(when_LsuPlugin_l1121) begin
        if(when_LsuPlugin_l311_1) begin
          LsuPlugin_logic_onCtrl_hartRegulation_valid <= 1'b1;
        end
      end
      if(LsuPlugin_logic_onCtrl_commitProbeReq) begin
        LsuPlugin_logic_onCtrl_commitProbeToken <= LsuPlugin_logic_onCtrl_lsuTrap;
      end
      if(LsuPlugin_logic_storeBuffer_ops_pip_node_0_isReady) begin
        LsuPlugin_logic_storeBuffer_ops_pip_node_1_valid <= LsuPlugin_logic_storeBuffer_ops_pip_node_0_isValid;
      end
      if(LsuPlugin_logic_storeBuffer_ops_pip_node_1_isReady) begin
        LsuPlugin_logic_storeBuffer_ops_pip_node_2_valid <= LsuPlugin_logic_storeBuffer_ops_pip_node_1_isValid;
      end
      if(LsuL1TileLinkPlugin_logic_down_a_valid) begin
        LsuL1Plugin_logic_bus_toTilelink_nonCoherent_onA_lock <= 1'b1;
      end
      if(LsuL1TileLinkPlugin_logic_down_a_fire) begin
        LsuL1TileLinkPlugin_logic_down_a_tracker_beat <= (LsuL1TileLinkPlugin_logic_down_a_tracker_beat + 3'b001);
        if(LsuL1TileLinkPlugin_logic_down_a_tracker_last) begin
          LsuL1TileLinkPlugin_logic_down_a_tracker_beat <= 3'b000;
        end
      end
      if(when_LsuL1Bus_l151) begin
        LsuL1Plugin_logic_bus_toTilelink_nonCoherent_onA_lock <= 1'b0;
      end
      CsrRamPlugin_logic_readLogic_ohReg <= (CsrRamPlugin_logic_readLogic_port_cmd_valid ? CsrRamPlugin_logic_readLogic_oh : 3'b000);
      CsrRamPlugin_logic_readLogic_busy <= CsrRamPlugin_logic_readLogic_port_cmd_valid;
      CsrRamPlugin_logic_flush_counter <= (CsrRamPlugin_logic_flush_counter + _zz_CsrRamPlugin_logic_flush_counter);
      if(PrefetcherRptPlugin_logic_initializer_busy) begin
        PrefetcherRptPlugin_logic_initializer_counter <= (PrefetcherRptPlugin_logic_initializer_counter + 8'h01);
      end
      PrefetcherRptPlugin_logic_pip_node_1_valid <= PrefetcherRptPlugin_logic_pip_node_0_isValid;
      PrefetcherRptPlugin_logic_pip_node_2_valid <= PrefetcherRptPlugin_logic_pip_node_1_isValid;
      fetch_logic_ctrls_0_down_isValid_regNext <= fetch_logic_ctrls_0_down_isValid;
      if(when_WhiteboxerPlugin_l46) begin
        fetch_logic_ctrls_0_down_isValid_regNext <= 1'b0;
      end
      fetch_logic_ctrls_1_down_isValid_regNext <= fetch_logic_ctrls_1_down_isValid;
      if(when_WhiteboxerPlugin_l46_1) begin
        fetch_logic_ctrls_1_down_isValid_regNext <= 1'b0;
      end
      fetch_logic_ctrls_2_down_isValid_regNext <= fetch_logic_ctrls_2_down_isValid;
      if(when_WhiteboxerPlugin_l46_2) begin
        fetch_logic_ctrls_2_down_isValid_regNext <= 1'b0;
      end
      decode_ctrls_0_up_LANE_SEL_0_regNext <= decode_ctrls_0_up_LANE_SEL_0;
      if(when_CtrlLaneApi_l50_2) begin
        decode_ctrls_0_up_LANE_SEL_0_regNext <= 1'b0;
      end
      decode_ctrls_1_up_LANE_SEL_0_regNext_1 <= decode_ctrls_1_up_LANE_SEL_0;
      if(when_CtrlLaneApi_l50_3) begin
        decode_ctrls_1_up_LANE_SEL_0_regNext_1 <= 1'b0;
      end
      decode_ctrls_0_up_LANE_SEL_1_regNext <= decode_ctrls_0_up_LANE_SEL_1;
      if(when_CtrlLaneApi_l50_4) begin
        decode_ctrls_0_up_LANE_SEL_1_regNext <= 1'b0;
      end
      decode_ctrls_1_up_LANE_SEL_1_regNext_1 <= decode_ctrls_1_up_LANE_SEL_1;
      if(when_CtrlLaneApi_l50_5) begin
        decode_ctrls_1_up_LANE_SEL_1_regNext_1 <= 1'b0;
      end
      decode_ctrls_1_up_LANE_SEL_0_regNext_2 <= decode_ctrls_1_up_LANE_SEL_0;
      if(when_CtrlLaneApi_l50_6) begin
        decode_ctrls_1_up_LANE_SEL_0_regNext_2 <= 1'b0;
      end
      decode_ctrls_1_up_LANE_SEL_1_regNext_2 <= decode_ctrls_1_up_LANE_SEL_1;
      if(when_CtrlLaneApi_l50_7) begin
        decode_ctrls_1_up_LANE_SEL_1_regNext_2 <= 1'b0;
      end
      execute_ctrl0_down_LANE_SEL_lane0_regNext <= execute_ctrl0_down_LANE_SEL_lane0;
      if(when_CtrlLaneApi_l50_8) begin
        execute_ctrl0_down_LANE_SEL_lane0_regNext <= 1'b0;
      end
      execute_ctrl0_down_LANE_SEL_lane1_regNext <= execute_ctrl0_down_LANE_SEL_lane1;
      if(when_CtrlLaneApi_l50_9) begin
        execute_ctrl0_down_LANE_SEL_lane1_regNext <= 1'b0;
      end
      if(when_RegFilePlugin_l149) begin
        integer_RegFilePlugin_logic_initalizer_counter <= (integer_RegFilePlugin_logic_initalizer_counter + 6'h01);
      end
      execute_ctrl2_down_LANE_SEL_lane0_regNext <= execute_ctrl2_down_LANE_SEL_lane0;
      if(when_CtrlLaneApi_l50_10) begin
        execute_ctrl2_down_LANE_SEL_lane0_regNext <= 1'b0;
      end
      execute_ctrl3_down_LANE_SEL_lane0_regNext <= execute_ctrl3_down_LANE_SEL_lane0;
      if(when_CtrlLaneApi_l50_11) begin
        execute_ctrl3_down_LANE_SEL_lane0_regNext <= 1'b0;
      end
      execute_ctrl4_down_LANE_SEL_lane0_regNext <= execute_ctrl4_down_LANE_SEL_lane0;
      if(when_CtrlLaneApi_l50_12) begin
        execute_ctrl4_down_LANE_SEL_lane0_regNext <= 1'b0;
      end
      execute_ctrl5_down_LANE_SEL_lane0_regNext <= execute_ctrl5_down_LANE_SEL_lane0;
      if(when_CtrlLaneApi_l50_13) begin
        execute_ctrl5_down_LANE_SEL_lane0_regNext <= 1'b0;
      end
      execute_ctrl2_down_LANE_SEL_lane1_regNext <= execute_ctrl2_down_LANE_SEL_lane1;
      if(when_CtrlLaneApi_l50_14) begin
        execute_ctrl2_down_LANE_SEL_lane1_regNext <= 1'b0;
      end
      execute_ctrl3_down_LANE_SEL_lane1_regNext <= execute_ctrl3_down_LANE_SEL_lane1;
      if(when_CtrlLaneApi_l50_15) begin
        execute_ctrl3_down_LANE_SEL_lane1_regNext <= 1'b0;
      end
      execute_ctrl4_down_LANE_SEL_lane1_regNext <= execute_ctrl4_down_LANE_SEL_lane1;
      if(when_CtrlLaneApi_l50_16) begin
        execute_ctrl4_down_LANE_SEL_lane1_regNext <= 1'b0;
      end
      execute_ctrl5_down_LANE_SEL_lane1_regNext <= execute_ctrl5_down_LANE_SEL_lane1;
      if(when_CtrlLaneApi_l50_17) begin
        execute_ctrl5_down_LANE_SEL_lane1_regNext <= 1'b0;
      end
      _zz_WhiteboxerPlugin_logic_perf_executeFreezedCounter_2 <= _zz_WhiteboxerPlugin_logic_perf_executeFreezedCounter_1;
      _zz_WhiteboxerPlugin_logic_perf_dispatchHazardsCounter_2 <= _zz_WhiteboxerPlugin_logic_perf_dispatchHazardsCounter_1;
      _zz_WhiteboxerPlugin_logic_perf_candidatesCountCounters_0_2 <= _zz_WhiteboxerPlugin_logic_perf_candidatesCountCounters_0_1;
      _zz_WhiteboxerPlugin_logic_perf_candidatesCountCounters_1_2 <= _zz_WhiteboxerPlugin_logic_perf_candidatesCountCounters_1_1;
      _zz_WhiteboxerPlugin_logic_perf_candidatesCountCounters_2_2 <= _zz_WhiteboxerPlugin_logic_perf_candidatesCountCounters_2_1;
      _zz_WhiteboxerPlugin_logic_perf_candidatesCountCounters_3_2 <= _zz_WhiteboxerPlugin_logic_perf_candidatesCountCounters_3_1;
      _zz_WhiteboxerPlugin_logic_perf_dispatchFeedCounters_0_2 <= _zz_WhiteboxerPlugin_logic_perf_dispatchFeedCounters_0_1;
      _zz_WhiteboxerPlugin_logic_perf_dispatchFeedCounters_1_2 <= _zz_WhiteboxerPlugin_logic_perf_dispatchFeedCounters_1_1;
      _zz_WhiteboxerPlugin_logic_perf_dispatchFeedCounters_2_2 <= _zz_WhiteboxerPlugin_logic_perf_dispatchFeedCounters_2_1;
      if(fetch_logic_ctrls_1_up_forgetOne) begin
        fetch_logic_ctrls_1_up_valid <= 1'b0;
      end
      if(fetch_logic_ctrls_0_down_isReady) begin
        fetch_logic_ctrls_1_up_valid <= fetch_logic_ctrls_0_down_isValid;
      end
      if(fetch_logic_ctrls_2_up_forgetOne) begin
        fetch_logic_ctrls_2_up_valid <= 1'b0;
      end
      if(fetch_logic_ctrls_1_down_isReady) begin
        fetch_logic_ctrls_2_up_valid <= fetch_logic_ctrls_1_down_isValid;
      end
      if(decode_ctrls_0_down_isReady) begin
        decode_ctrls_1_up_valid <= decode_ctrls_0_down_isValid;
      end
      if(decode_ctrls_0_down_isReady) begin
        decode_ctrls_1_up_LANE_SEL_0 <= decode_ctrls_0_down_LANE_SEL_0;
        decode_ctrls_1_up_LANE_SEL_1 <= decode_ctrls_0_down_LANE_SEL_1;
      end
      if(when_DecodePipelinePlugin_l70) begin
        decode_ctrls_1_up_LANE_SEL_0 <= 1'b0;
      end
      if(when_DecodePipelinePlugin_l70_1) begin
        decode_ctrls_1_up_LANE_SEL_1 <= 1'b0;
      end
      if(execute_ctrl0_down_isReady) begin
        execute_ctrl1_up_LANE_SEL_lane0 <= execute_ctrl0_down_LANE_SEL_lane0;
        execute_ctrl1_up_LANE_SEL_lane1 <= execute_ctrl0_down_LANE_SEL_lane1;
      end
      if(execute_ctrl1_down_isReady) begin
        execute_ctrl2_up_LANE_SEL_lane0 <= execute_ctrl1_down_LANE_SEL_lane0;
        execute_ctrl2_up_LANE_SEL_lane1 <= execute_ctrl1_down_LANE_SEL_lane1;
      end
      if(execute_ctrl2_down_isReady) begin
        execute_ctrl3_up_LANE_SEL_lane0 <= execute_ctrl2_down_LANE_SEL_lane0;
        execute_ctrl3_up_LANE_SEL_lane1 <= execute_ctrl2_down_LANE_SEL_lane1;
        execute_ctrl3_up_LsuL1_SEL_lane0 <= execute_ctrl2_down_LsuL1_SEL_lane0;
      end
      if(execute_ctrl3_down_isReady) begin
        execute_ctrl4_up_LANE_SEL_lane0 <= execute_ctrl3_down_LANE_SEL_lane0;
        execute_ctrl4_up_LANE_SEL_lane1 <= execute_ctrl3_down_LANE_SEL_lane1;
        execute_ctrl4_up_LsuL1_SEL_lane0 <= execute_ctrl3_down_LsuL1_SEL_lane0;
      end
      if(execute_ctrl4_down_isReady) begin
        execute_ctrl5_up_LANE_SEL_lane0 <= execute_ctrl4_down_LANE_SEL_lane0;
        execute_ctrl5_up_LANE_SEL_lane1 <= execute_ctrl4_down_LANE_SEL_lane1;
      end
      PerformanceCounterPlugin_logic_fsm_stateReg <= PerformanceCounterPlugin_logic_fsm_stateNext;
      case(PerformanceCounterPlugin_logic_fsm_stateReg)
        PerformanceCounterPlugin_logic_fsm_IDLE : begin
        end
        PerformanceCounterPlugin_logic_fsm_READ_LOW : begin
        end
        PerformanceCounterPlugin_logic_fsm_CALC_LOW : begin
          if(when_PerformanceCounterPlugin_l338) begin
            if(_zz_PerformanceCounterPlugin_logic_fsm_cmd_address) begin
              PerformanceCounterPlugin_logic_counters_cycle_value[7] <= 1'b0;
            end
            if(_zz_PerformanceCounterPlugin_logic_fsm_cmd_address_1) begin
              PerformanceCounterPlugin_logic_counters_instret_value[7] <= 1'b0;
            end
          end
        end
        PerformanceCounterPlugin_logic_fsm_READ_HIGH : begin
        end
        PerformanceCounterPlugin_logic_fsm_CALC_HIGH : begin
        end
        PerformanceCounterPlugin_logic_fsm_CSR_WRITE : begin
          if(when_PerformanceCounterPlugin_l316) begin
            if(_zz_PerformanceCounterPlugin_logic_fsm_cmd_address) begin
              PerformanceCounterPlugin_logic_counters_cycle_value <= _zz_PerformanceCounterPlugin_logic_counters_cycle_value_2[7:0];
              PerformanceCounterPlugin_logic_counters_cycle_value[7] <= 1'b0;
            end
            if(_zz_PerformanceCounterPlugin_logic_fsm_cmd_address_1) begin
              PerformanceCounterPlugin_logic_counters_instret_value <= _zz_PerformanceCounterPlugin_logic_counters_instret_value_2[7:0];
              PerformanceCounterPlugin_logic_counters_instret_value[7] <= 1'b0;
            end
          end
          if(when_PerformanceCounterPlugin_l322) begin
            PerformanceCounterPlugin_logic_ignoreNextCommit <= 1'b1;
          end
        end
        default : begin
        end
      endcase
      TrapPlugin_logic_harts_0_trap_fsm_stateReg <= TrapPlugin_logic_harts_0_trap_fsm_stateNext;
      case(TrapPlugin_logic_harts_0_trap_fsm_stateReg)
        TrapPlugin_logic_harts_0_trap_fsm_RUNNING : begin
        end
        TrapPlugin_logic_harts_0_trap_fsm_COMPUTE : begin
          TrapPlugin_logic_harts_0_trap_fsm_trapEnterDebug <= 1'b0;
          if(!when_TrapPlugin_l630) begin
            case(TrapPlugin_logic_harts_0_trap_pending_state_code)
              5'h0 : begin
                `ifndef SYNTHESIS
                  `ifdef FORMAL
                    assert((! TrapPlugin_logic_harts_0_trap_fsm_buffer_i_valid)); // TrapPlugin.scala:L687
                  `else
                    if(!(! TrapPlugin_logic_harts_0_trap_fsm_buffer_i_valid)) begin
                      $display("FAILURE "); // TrapPlugin.scala:L687
                      $finish;
                    end
                  `endif
                `endif
              end
              5'h01 : begin
              end
              5'h02 : begin
              end
              5'h04 : begin
              end
              5'h05 : begin
              end
              5'h08 : begin
              end
              5'h06 : begin
              end
              5'h09 : begin
              end
              default : begin
                `ifndef SYNTHESIS
                  `ifdef FORMAL
                    assert(1'b0); // TrapPlugin.scala:L756
                  `else
                    if(!1'b0) begin
                      $display("FAILURE Unexpected trap reason"); // TrapPlugin.scala:L756
                      $finish;
                    end
                  `endif
                `endif
              end
            endcase
          end
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
          PrivilegedPlugin_logic_harts_0_privilege <= TrapPlugin_logic_harts_0_trap_fsm_buffer_trap_targetPrivilege;
          case(TrapPlugin_logic_harts_0_trap_fsm_buffer_trap_targetPrivilege)
            3'b011 : begin
              PrivilegedPlugin_logic_harts_0_m_status_mie <= 1'b0;
              PrivilegedPlugin_logic_harts_0_m_status_mpie <= PrivilegedPlugin_logic_harts_0_m_status_mie;
              PrivilegedPlugin_logic_harts_0_m_cause_code <= TrapPlugin_logic_harts_0_trap_fsm_buffer_trap_code;
              PrivilegedPlugin_logic_harts_0_m_cause_interrupt <= TrapPlugin_logic_harts_0_trap_fsm_buffer_trap_interrupt;
            end
            default : begin
            end
          endcase
        end
        TrapPlugin_logic_harts_0_trap_fsm_XRET_EPC : begin
        end
        TrapPlugin_logic_harts_0_trap_fsm_XRET_APPLY : begin
          PrivilegedPlugin_logic_harts_0_privilege <= TrapPlugin_logic_harts_0_trap_pending_xret_targetPrivilege;
          case(switch_TrapPlugin_l1076)
            3'b011 : begin
              PrivilegedPlugin_logic_harts_0_m_status_mie <= PrivilegedPlugin_logic_harts_0_m_status_mpie;
              PrivilegedPlugin_logic_harts_0_m_status_mpie <= 1'b1;
            end
            default : begin
            end
          endcase
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
      CsrAccessPlugin_logic_fsm_stateReg <= CsrAccessPlugin_logic_fsm_stateNext;
      case(CsrAccessPlugin_logic_fsm_stateReg)
        CsrAccessPlugin_logic_fsm_READ : begin
        end
        CsrAccessPlugin_logic_fsm_WRITE : begin
        end
        CsrAccessPlugin_logic_fsm_COMPLETION : begin
        end
        default : begin
          if(CsrAccessPlugin_logic_fsm_inject_onDecodeDo) begin
            if(CsrAccessPlugin_logic_fsm_inject_sampled) begin
              if(CsrAccessPlugin_logic_fsm_inject_trapReg) begin
                CsrAccessPlugin_logic_fsm_inject_unfreeze <= execute_freeze_valid;
              end
            end
          end
        end
      endcase
      case(CsrAccessPlugin_logic_fsm_stateNext)
        CsrAccessPlugin_logic_fsm_READ : begin
        end
        CsrAccessPlugin_logic_fsm_WRITE : begin
        end
        CsrAccessPlugin_logic_fsm_COMPLETION : begin
          CsrAccessPlugin_logic_fsm_inject_unfreeze <= 1'b1;
        end
        default : begin
        end
      endcase
      LsuPlugin_logic_flusher_stateReg <= LsuPlugin_logic_flusher_stateNext;
      BtbPlugin_logic_ras_ptr_pop <= BtbPlugin_logic_ras_ptr_pop_aheadValue;
    end
  end

