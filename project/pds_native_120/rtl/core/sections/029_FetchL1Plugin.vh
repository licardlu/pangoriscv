  assign execute_ctrl2_down_RsUnsignedPlugin_RS2_UNSIGNED_lane0 = ((execute_ctrl2_down_RsUnsignedPlugin_RS2_REVERT_lane0 ? (~ execute_ctrl2_down_RsUnsignedPlugin_RS2_FORMATED_lane0) : execute_ctrl2_down_RsUnsignedPlugin_RS2_FORMATED_lane0) + _zz_execute_ctrl2_down_RsUnsignedPlugin_RS2_UNSIGNED_lane0);
  assign early0_DivPlugin_logic_processing_div_io_cmd_fire = (early0_DivPlugin_logic_processing_div_io_cmd_valid && early0_DivPlugin_logic_processing_div_io_cmd_ready);
  assign early0_DivPlugin_logic_processing_request = (execute_ctrl2_up_LANE_SEL_lane0 && execute_ctrl2_down_early0_DivPlugin_SEL_lane0);
  assign early0_DivPlugin_logic_processing_a = execute_ctrl2_down_RsUnsignedPlugin_RS1_UNSIGNED_lane0;
  assign early0_DivPlugin_logic_processing_b = execute_ctrl2_down_RsUnsignedPlugin_RS2_UNSIGNED_lane0;
  assign early0_DivPlugin_logic_processing_div_io_cmd_valid = (early0_DivPlugin_logic_processing_request && (! early0_DivPlugin_logic_processing_cmdSent));
  assign early0_DivPlugin_logic_processing_freeze = ((early0_DivPlugin_logic_processing_request && (! early0_DivPlugin_logic_processing_div_io_rsp_valid)) && (! early0_DivPlugin_logic_processing_unscheduleRequest));
  assign early0_DivPlugin_logic_processing_selected = (execute_ctrl2_down_DivPlugin_REM_lane0 ? early0_DivPlugin_logic_processing_div_io_rsp_payload_remain : early0_DivPlugin_logic_processing_div_io_rsp_payload_result);
  assign _zz_execute_ctrl2_down_DivPlugin_DIV_RESULT_lane0 = early0_DivPlugin_logic_processing_selected;
  assign execute_ctrl2_down_DivPlugin_DIV_RESULT_lane0 = _zz_execute_ctrl2_down_DivPlugin_DIV_RESULT_lane0_1;
  assign early0_DivPlugin_logic_formatBus_valid = execute_ctrl3_down_early0_DivPlugin_SEL_lane0;
  assign early0_DivPlugin_logic_formatBus_payload = execute_ctrl3_down_DivPlugin_DIV_RESULT_lane0;
  always @(*) begin
    PrivilegedPlugin_logic_harts_0_xretAwayFromMachine = 1'b0;
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
        if(when_TrapPlugin_l1075) begin
          PrivilegedPlugin_logic_harts_0_xretAwayFromMachine = 1'b1;
        end
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
  end

  always @(*) begin
    PrivilegedPlugin_logic_harts_0_int_pending = 1'b0;
    if(TrapPlugin_logic_harts_0_interrupt_pendingInterrupt) begin
      PrivilegedPlugin_logic_harts_0_int_pending = 1'b1;
    end
  end

  assign PrivilegedPlugin_logic_harts_0_privilegeMode = _zz_PrivilegedPlugin_logic_harts_0_privilegeMode;
  assign PrivilegedPlugin_logic_harts_0_withMachinePrivilege = ($signed(3'b011) <= $signed(PrivilegedPlugin_logic_harts_0_privilege));
  assign PrivilegedPlugin_logic_harts_0_withHostSupervisorPrivilege = ($signed(3'b001) <= $signed(PrivilegedPlugin_logic_harts_0_privilege));
  assign PrivilegedPlugin_logic_harts_0_withVirtualSupervisorPrivilege = ($signed(3'b101) <= $signed(PrivilegedPlugin_logic_harts_0_privilege));
  assign PrivilegedPlugin_logic_harts_0_withSupervisorPrivilege = (2'b01 <= PrivilegedPlugin_logic_harts_0_privilegeMode);
  assign PrivilegedPlugin_logic_harts_0_isGuestMode = PrivilegedPlugin_logic_harts_0_privilege[2];
  assign PrivilegedPlugin_logic_harts_0_isHostMode = (! PrivilegedPlugin_logic_harts_0_isGuestMode);
  assign PrivilegedPlugin_logic_harts_0_hartRunning = 1'b1;
  assign PrivilegedPlugin_logic_harts_0_debugMode = (! PrivilegedPlugin_logic_harts_0_hartRunning);
  assign PrivilegedPlugin_logic_harts_0_m_status_mpp = 2'b11;
  assign PrivilegedPlugin_logic_harts_0_m_status_mpv = 1'b0;
  assign PrivilegedPlugin_logic_harts_0_m_status_sd = 1'b0;
  assign PrivilegedPlugin_logic_harts_0_m_status_tw = 1'b0;
  assign _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue = (_zz_when_CsrService_l223 && REG_CSR_768);
  assign _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_1 = (_zz_when_CsrService_l223 && REG_CSR_834);
  assign _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_3 = (_zz_when_CsrService_l223 && _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_2);
  assign _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_5 = (_zz_when_CsrService_l223 && _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_4);
  always @(*) begin
    PrivilegedPlugin_logic_harts_0_m_candidate_interrupt = 5'bxxxxx;
    PrivilegedPlugin_logic_harts_0_m_candidate_interrupt = TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_triggerId;
  end

  always @(*) begin
    PrivilegedPlugin_logic_harts_0_m_candidate_priority = 4'bxxxx;
    PrivilegedPlugin_logic_harts_0_m_candidate_priority = TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_triggerPriority;
  end

  always @(*) begin
    PrivilegedPlugin_logic_harts_0_m_topi_interrupt = 5'bxxxxx;
    PrivilegedPlugin_logic_harts_0_m_topi_interrupt = TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_effectiveInterrupt;
  end

  assign PrivilegedPlugin_logic_harts_0_m_topi_priority = ((PrivilegedPlugin_logic_harts_0_m_topi_interrupt == 5'h0) ? 1'b0 : 1'b1);
  assign _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_6 = (_zz_when_CsrService_l223 && REG_CSR_4016);
  assign PrivilegedPlugin_logic_harts_0_m_envcfg_stce = 1'b0;
  always @(*) begin
    case(execute_ctrl4_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0)
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : begin
        late0_IntAluPlugin_logic_alu_bitwise = (execute_ctrl4_down_late0_SrcPlugin_SRC1_lane0 & execute_ctrl4_down_late0_SrcPlugin_SRC2_lane0);
      end
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : begin
        late0_IntAluPlugin_logic_alu_bitwise = (execute_ctrl4_down_late0_SrcPlugin_SRC1_lane0 | execute_ctrl4_down_late0_SrcPlugin_SRC2_lane0);
      end
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : begin
        late0_IntAluPlugin_logic_alu_bitwise = (execute_ctrl4_down_late0_SrcPlugin_SRC1_lane0 ^ execute_ctrl4_down_late0_SrcPlugin_SRC2_lane0);
      end
      default : begin
        late0_IntAluPlugin_logic_alu_bitwise = 32'h0;
      end
    endcase
  end

  assign late0_IntAluPlugin_logic_alu_result = (_zz_late0_IntAluPlugin_logic_alu_result | _zz_late0_IntAluPlugin_logic_alu_result_2);
  assign execute_ctrl4_down_late0_IntAluPlugin_ALU_RESULT_lane0 = late0_IntAluPlugin_logic_alu_result;
  assign late0_IntAluPlugin_logic_wb_valid = execute_ctrl4_down_late0_IntAluPlugin_SEL_lane0;
  assign late0_IntAluPlugin_logic_wb_payload = execute_ctrl4_down_late0_IntAluPlugin_ALU_RESULT_lane0;
  // Reference line 20599 moved verbatim to replica_late0_shifter.
  // Reference line 20600 moved verbatim to replica_late0_shifter.
  // Reference line 20601 moved verbatim to replica_late0_shifter.
  // Reference line 20602 moved verbatim to replica_late0_shifter.
  // Reference line 20603 moved verbatim to replica_late0_shifter.
  assign late0_BarrelShifterPlugin_logic_wb_valid = execute_ctrl4_down_late0_BarrelShifterPlugin_SEL_lane0;
  assign late0_BarrelShifterPlugin_logic_wb_payload = execute_ctrl4_down_late0_BarrelShifterPlugin_SHIFT_RESULT_lane0;
  always @(*) begin
    case(execute_ctrl2_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1)
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : begin
        early1_IntAluPlugin_logic_alu_bitwise = (execute_ctrl2_down_early1_SrcPlugin_SRC1_lane1 & execute_ctrl2_down_early1_SrcPlugin_SRC2_lane1);
      end
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : begin
        early1_IntAluPlugin_logic_alu_bitwise = (execute_ctrl2_down_early1_SrcPlugin_SRC1_lane1 | execute_ctrl2_down_early1_SrcPlugin_SRC2_lane1);
      end
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : begin
        early1_IntAluPlugin_logic_alu_bitwise = (execute_ctrl2_down_early1_SrcPlugin_SRC1_lane1 ^ execute_ctrl2_down_early1_SrcPlugin_SRC2_lane1);
      end
      default : begin
        early1_IntAluPlugin_logic_alu_bitwise = 32'h0;
      end
    endcase
  end

  assign early1_IntAluPlugin_logic_alu_result = (_zz_early1_IntAluPlugin_logic_alu_result | _zz_early1_IntAluPlugin_logic_alu_result_2);
  assign execute_ctrl2_down_early1_IntAluPlugin_ALU_RESULT_lane1 = early1_IntAluPlugin_logic_alu_result;
  assign early1_IntAluPlugin_logic_wb_valid = execute_ctrl2_down_early1_IntAluPlugin_SEL_lane1;
  assign early1_IntAluPlugin_logic_wb_payload = execute_ctrl2_down_early1_IntAluPlugin_ALU_RESULT_lane1;
  // Reference line 20627 moved verbatim to replica_early1_shifter.
  // Reference line 20628 moved verbatim to replica_early1_shifter.
  // Reference line 20629 moved verbatim to replica_early1_shifter.
  // Reference line 20630 moved verbatim to replica_early1_shifter.
  // Reference line 20631 moved verbatim to replica_early1_shifter.
  assign early1_BarrelShifterPlugin_logic_wb_valid = execute_ctrl2_down_early1_BarrelShifterPlugin_SEL_lane1;
  assign early1_BarrelShifterPlugin_logic_wb_payload = execute_ctrl2_down_early1_BarrelShifterPlugin_SHIFT_RESULT_lane1;
  always @(*) begin
    case(execute_ctrl4_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1)
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : begin
        late1_IntAluPlugin_logic_alu_bitwise = (execute_ctrl4_down_late1_SrcPlugin_SRC1_lane1 & execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1);
      end
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : begin
        late1_IntAluPlugin_logic_alu_bitwise = (execute_ctrl4_down_late1_SrcPlugin_SRC1_lane1 | execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1);
      end
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : begin
        late1_IntAluPlugin_logic_alu_bitwise = (execute_ctrl4_down_late1_SrcPlugin_SRC1_lane1 ^ execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1);
      end
      default : begin
        late1_IntAluPlugin_logic_alu_bitwise = 32'h0;
      end
    endcase
  end

  assign late1_IntAluPlugin_logic_alu_result = (_zz_late1_IntAluPlugin_logic_alu_result | _zz_late1_IntAluPlugin_logic_alu_result_2);
  assign execute_ctrl4_down_late1_IntAluPlugin_ALU_RESULT_lane1 = late1_IntAluPlugin_logic_alu_result;
  assign late1_IntAluPlugin_logic_wb_valid = execute_ctrl4_down_late1_IntAluPlugin_SEL_lane1;
  assign late1_IntAluPlugin_logic_wb_payload = execute_ctrl4_down_late1_IntAluPlugin_ALU_RESULT_lane1;
  // Reference line 20655 moved verbatim to replica_late1_shifter.
  // Reference line 20656 moved verbatim to replica_late1_shifter.
  // Reference line 20657 moved verbatim to replica_late1_shifter.
  // Reference line 20658 moved verbatim to replica_late1_shifter.
  // Reference line 20659 moved verbatim to replica_late1_shifter.
  assign late1_BarrelShifterPlugin_logic_wb_valid = execute_ctrl4_down_late1_BarrelShifterPlugin_SEL_lane1;
  assign late1_BarrelShifterPlugin_logic_wb_payload = execute_ctrl4_down_late1_BarrelShifterPlugin_SHIFT_RESULT_lane1;
  always @(*) begin
    CsrAccessPlugin_bus_decode_exception = 1'b0;
    if(when_PrivilegedPlugin_l1341) begin
      CsrAccessPlugin_bus_decode_exception = 1'b1;
    end
    if(when_CsrAccessPlugin_l174) begin
      if(when_CsrService_l223) begin
        if(when_CsrService_l224) begin
          CsrAccessPlugin_bus_decode_exception = 1'b1;
        end
      end
    end
    if(when_CsrAccessPlugin_l174_1) begin
      if(when_CsrService_l223_1) begin
        if(when_CsrService_l224_1) begin
          CsrAccessPlugin_bus_decode_exception = 1'b1;
        end
      end
    end
    if(when_CsrAccessPlugin_l174_2) begin
      if(when_CsrService_l223_2) begin
        if(when_CsrService_l224_2) begin
          CsrAccessPlugin_bus_decode_exception = 1'b1;
        end
      end
    end
    if(when_CsrAccessPlugin_l174_5) begin
      if(when_CsrService_l137) begin
        CsrAccessPlugin_bus_decode_exception = 1'b1;
      end
    end
    if(when_CsrAccessPlugin_l174_6) begin
      if(when_CsrService_l137_1) begin
        CsrAccessPlugin_bus_decode_exception = 1'b1;
      end
    end
    if(when_CsrAccessPlugin_l174_7) begin
      if(when_PerformanceCounterPlugin_l396) begin
        if(when_PerformanceCounterPlugin_l400) begin
          CsrAccessPlugin_bus_decode_exception = 1'b1;
        end
      end
    end
  end

  always @(*) begin
    CsrAccessPlugin_bus_decode_trap = 1'b0;
    if(when_CsrAccessPlugin_l174_8) begin
      if(CsrAccessPlugin_bus_decode_write) begin
        CsrAccessPlugin_bus_decode_trap = 1'b1;
      end
    end
  end

  always @(*) begin
    CsrAccessPlugin_bus_decode_trapCode = 5'bxxxxx;
    if(when_CsrAccessPlugin_l174_8) begin
      if(CsrAccessPlugin_bus_decode_write) begin
        CsrAccessPlugin_bus_decode_trapCode = 5'h05;
      end
    end
  end

  assign CsrAccessPlugin_bus_decode_fence = 1'b0;
  assign CsrAccessPlugin_bus_decode_virtual = 1'b0;
  always @(*) begin
    CsrAccessPlugin_bus_decode_hostDenied = 1'b0;
    if(when_PrivilegedPlugin_l1345) begin
      CsrAccessPlugin_bus_decode_hostDenied = 1'b1;
    end
    if(when_CsrAccessPlugin_l174_3) begin
      if(when_CsrService_l231) begin
        if(when_CsrService_l232) begin
          CsrAccessPlugin_bus_decode_hostDenied = 1'b1;
        end
      end
    end
    if(when_CsrAccessPlugin_l174_4) begin
      if(when_CsrService_l231_1) begin
        if(when_CsrService_l232_1) begin
          CsrAccessPlugin_bus_decode_hostDenied = 1'b1;
        end
      end
    end
    if(when_CsrAccessPlugin_l174_7) begin
      if(when_PerformanceCounterPlugin_l396) begin
        if(CsrAccessPlugin_bus_decode_write) begin
          CsrAccessPlugin_bus_decode_hostDenied = 1'b1;
        end
        if(when_PerformanceCounterPlugin_l400) begin
          if(when_PerformanceCounterPlugin_l402) begin
            CsrAccessPlugin_bus_decode_hostDenied = 1'b1;
          end
        end
      end
    end
  end

  always @(*) begin
    CsrAccessPlugin_bus_read_halt = 1'b0;
    if(when_CsrRamPlugin_l85) begin
      CsrAccessPlugin_bus_read_halt = 1'b1;
    end
  end

  always @(*) begin
    CsrAccessPlugin_bus_write_halt = 1'b0;
    if(when_CsrRamPlugin_l96) begin
      CsrAccessPlugin_bus_write_halt = 1'b1;
    end
    if(when_CsrAccessPlugin_l375_3) begin
      if(when_PerformanceCounterPlugin_l432) begin
        if(when_PerformanceCounterPlugin_l434) begin
          CsrAccessPlugin_bus_write_halt = 1'b1;
        end
      end
    end
  end

  assign FetchL1Plugin_logic_banks_0_read_rsp = FetchL1Plugin_logic_banks_0_mem_spinal_port1;
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_BANKS_WORDS_0 = FetchL1Plugin_logic_banks_0_read_rsp;
  assign FetchL1Plugin_logic_banks_1_read_rsp = FetchL1Plugin_logic_banks_1_mem_spinal_port1;
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_BANKS_WORDS_1 = FetchL1Plugin_logic_banks_1_read_rsp;
  always @(*) begin
    FetchL1Plugin_logic_waysWrite_mask = 2'b00;
    if(when_FetchL1Plugin_l211) begin
      FetchL1Plugin_logic_waysWrite_mask = 2'b11;
    end
    if(FetchL1Plugin_logic_invalidate_done) begin
      if(when_FetchL1Plugin_l311) begin
        FetchL1Plugin_logic_waysWrite_mask[FetchL1Plugin_logic_refill_onRsp_wayToAllocate] = 1'b1;
      end
    end
  end

  always @(*) begin
    FetchL1Plugin_logic_waysWrite_address = 7'bxxxxxxx;
    if(when_FetchL1Plugin_l211) begin
      FetchL1Plugin_logic_waysWrite_address = FetchL1Plugin_logic_invalidate_counter[6:0];
    end
    if(FetchL1Plugin_logic_invalidate_done) begin
      FetchL1Plugin_logic_waysWrite_address = FetchL1Plugin_logic_refill_onRsp_address[12 : 6];
    end
  end

  always @(*) begin
    FetchL1Plugin_logic_waysWrite_tag_loaded = 1'bx;
    if(when_FetchL1Plugin_l211) begin
      FetchL1Plugin_logic_waysWrite_tag_loaded = 1'b0;
    end
    if(FetchL1Plugin_logic_invalidate_done) begin
      FetchL1Plugin_logic_waysWrite_tag_loaded = 1'b1;
    end
  end

  always @(*) begin
    FetchL1Plugin_logic_waysWrite_tag_error = 1'bx;
    if(FetchL1Plugin_logic_invalidate_done) begin
      FetchL1Plugin_logic_waysWrite_tag_error = (FetchL1Plugin_logic_bus_rsp_valid && FetchL1Plugin_logic_bus_rsp_payload_error);
    end
  end

  always @(*) begin
    FetchL1Plugin_logic_waysWrite_tag_address = 19'bxxxxxxxxxxxxxxxxxxx;
    if(FetchL1Plugin_logic_invalidate_done) begin
      FetchL1Plugin_logic_waysWrite_tag_address = FetchL1Plugin_logic_refill_onRsp_address[31 : 13];
    end
  end

  assign _zz_FetchL1Plugin_logic_ways_0_read_rsp_loaded = FetchL1Plugin_logic_ways_0_mem_spinal_port1;
  assign FetchL1Plugin_logic_ways_0_read_rsp_loaded = _zz_FetchL1Plugin_logic_ways_0_read_rsp_loaded[0];
  assign FetchL1Plugin_logic_ways_0_read_rsp_error = _zz_FetchL1Plugin_logic_ways_0_read_rsp_loaded[1];
  assign FetchL1Plugin_logic_ways_0_read_rsp_address = _zz_FetchL1Plugin_logic_ways_0_read_rsp_loaded[20 : 2];
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_TAGS_0_loaded = FetchL1Plugin_logic_ways_0_read_rsp_loaded;
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_TAGS_0_error = FetchL1Plugin_logic_ways_0_read_rsp_error;
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_TAGS_0_address = FetchL1Plugin_logic_ways_0_read_rsp_address;
  assign _zz_FetchL1Plugin_logic_ways_1_read_rsp_loaded = FetchL1Plugin_logic_ways_1_mem_spinal_port1;
  assign FetchL1Plugin_logic_ways_1_read_rsp_loaded = _zz_FetchL1Plugin_logic_ways_1_read_rsp_loaded[0];
  assign FetchL1Plugin_logic_ways_1_read_rsp_error = _zz_FetchL1Plugin_logic_ways_1_read_rsp_loaded[1];
  assign FetchL1Plugin_logic_ways_1_read_rsp_address = _zz_FetchL1Plugin_logic_ways_1_read_rsp_loaded[20 : 2];
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_TAGS_1_loaded = FetchL1Plugin_logic_ways_1_read_rsp_loaded;
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_TAGS_1_error = FetchL1Plugin_logic_ways_1_read_rsp_error;
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_WAYS_TAGS_1_address = FetchL1Plugin_logic_ways_1_read_rsp_address;
  assign FetchL1Plugin_logic_plru_read_rsp_0 = FetchL1Plugin_logic_plru_mem_spinal_port1[0 : 0];
  assign fetch_logic_ctrls_1_down_FetchL1Plugin_logic_PLRU_READ_0 = FetchL1Plugin_logic_plru_read_rsp_0;
  assign FetchL1Plugin_logic_invalidate_cmd_valid = (|TrapPlugin_logic_fetchL1Invalidate_0_cmd_valid);
  always @(*) begin
    FetchL1Plugin_logic_invalidate_canStart = 1'b1;
    if(when_FetchL1Plugin_l275) begin
      FetchL1Plugin_logic_invalidate_canStart = 1'b0;
    end
  end

  assign FetchL1Plugin_logic_invalidate_counterIncr = (FetchL1Plugin_logic_invalidate_counter + 8'h01);
  assign FetchL1Plugin_logic_invalidate_done = FetchL1Plugin_logic_invalidate_counter[7];
  assign FetchL1Plugin_logic_invalidate_last = FetchL1Plugin_logic_invalidate_counterIncr[7];
  assign when_FetchL1Plugin_l211 = (! FetchL1Plugin_logic_invalidate_done);
  assign when_FetchL1Plugin_l218 = ((FetchL1Plugin_logic_invalidate_done && FetchL1Plugin_logic_invalidate_cmd_valid) && FetchL1Plugin_logic_invalidate_canStart);
  always @(*) begin
    TrapPlugin_logic_fetchL1Invalidate_0_cmd_ready = 1'b0;
    if(when_FetchL1Plugin_l223) begin
      if(FetchL1Plugin_logic_invalidate_last) begin
        TrapPlugin_logic_fetchL1Invalidate_0_cmd_ready = 1'b1;
      end
    end
  end

  assign when_FetchL1Plugin_l223 = (! FetchL1Plugin_logic_invalidate_done);
  assign fetch_logic_ctrls_0_haltRequest_FetchL1Plugin_l224 = _zz_fetch_logic_ctrls_0_haltRequest_FetchL1Plugin_l224;
  assign FetchL1Plugin_logic_refill_slots_0_askCmd = (FetchL1Plugin_logic_refill_slots_0_valid && (! FetchL1Plugin_logic_refill_slots_0_cmdSent));
  assign FetchL1Plugin_logic_refill_slots_1_askCmd = (FetchL1Plugin_logic_refill_slots_1_valid && (! FetchL1Plugin_logic_refill_slots_1_cmdSent));
  assign FetchL1Plugin_logic_refill_slots_2_askCmd = (FetchL1Plugin_logic_refill_slots_2_valid && (! FetchL1Plugin_logic_refill_slots_2_cmdSent));
  assign FetchL1Plugin_logic_refill_slots_3_askCmd = (FetchL1Plugin_logic_refill_slots_3_valid && (! FetchL1Plugin_logic_refill_slots_3_cmdSent));
  assign FetchL1Plugin_logic_refill_slots_4_askCmd = (FetchL1Plugin_logic_refill_slots_4_valid && (! FetchL1Plugin_logic_refill_slots_4_cmdSent));
  assign FetchL1Plugin_logic_refill_slots_5_askCmd = (FetchL1Plugin_logic_refill_slots_5_valid && (! FetchL1Plugin_logic_refill_slots_5_cmdSent));
  assign FetchL1Plugin_logic_refill_slots_6_askCmd = (FetchL1Plugin_logic_refill_slots_6_valid && (! FetchL1Plugin_logic_refill_slots_6_cmdSent));
  assign FetchL1Plugin_logic_refill_slots_7_askCmd = (FetchL1Plugin_logic_refill_slots_7_valid && (! FetchL1Plugin_logic_refill_slots_7_cmdSent));
  assign when_FetchL1Plugin_l253 = (! FetchL1Plugin_logic_refill_slots_1_valid);
  assign when_FetchL1Plugin_l253_1 = (! FetchL1Plugin_logic_refill_slots_2_valid);
  assign when_FetchL1Plugin_l253_2 = (! FetchL1Plugin_logic_refill_slots_3_valid);
  assign when_FetchL1Plugin_l253_3 = (! FetchL1Plugin_logic_refill_slots_4_valid);
  assign when_FetchL1Plugin_l253_4 = (! FetchL1Plugin_logic_refill_slots_5_valid);
  assign when_FetchL1Plugin_l253_5 = (! FetchL1Plugin_logic_refill_slots_6_valid);
  assign when_FetchL1Plugin_l253_6 = (! FetchL1Plugin_logic_refill_slots_7_valid);
  assign when_FetchL1Plugin_l253_7 = (! FetchL1Plugin_logic_refill_slots_0_valid);
  assign when_FetchL1Plugin_l253_8 = (! FetchL1Plugin_logic_refill_slots_2_valid);
  assign when_FetchL1Plugin_l253_9 = (! FetchL1Plugin_logic_refill_slots_3_valid);
  assign when_FetchL1Plugin_l253_10 = (! FetchL1Plugin_logic_refill_slots_4_valid);
  assign when_FetchL1Plugin_l253_11 = (! FetchL1Plugin_logic_refill_slots_5_valid);
  assign when_FetchL1Plugin_l253_12 = (! FetchL1Plugin_logic_refill_slots_6_valid);
  assign when_FetchL1Plugin_l253_13 = (! FetchL1Plugin_logic_refill_slots_7_valid);
  assign when_FetchL1Plugin_l253_14 = (! FetchL1Plugin_logic_refill_slots_0_valid);
  assign when_FetchL1Plugin_l253_15 = (! FetchL1Plugin_logic_refill_slots_1_valid);
  assign when_FetchL1Plugin_l253_16 = (! FetchL1Plugin_logic_refill_slots_3_valid);
  assign when_FetchL1Plugin_l253_17 = (! FetchL1Plugin_logic_refill_slots_4_valid);
  assign when_FetchL1Plugin_l253_18 = (! FetchL1Plugin_logic_refill_slots_5_valid);
  assign when_FetchL1Plugin_l253_19 = (! FetchL1Plugin_logic_refill_slots_6_valid);
  assign when_FetchL1Plugin_l253_20 = (! FetchL1Plugin_logic_refill_slots_7_valid);
  assign when_FetchL1Plugin_l253_21 = (! FetchL1Plugin_logic_refill_slots_0_valid);
  assign when_FetchL1Plugin_l253_22 = (! FetchL1Plugin_logic_refill_slots_1_valid);
  assign when_FetchL1Plugin_l253_23 = (! FetchL1Plugin_logic_refill_slots_2_valid);
  assign when_FetchL1Plugin_l253_24 = (! FetchL1Plugin_logic_refill_slots_4_valid);
  assign when_FetchL1Plugin_l253_25 = (! FetchL1Plugin_logic_refill_slots_5_valid);
