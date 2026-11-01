  always @(*) begin
    early0_BranchPlugin_logic_jumpLogic_history_shifter_2 = early0_BranchPlugin_logic_jumpLogic_history_shifter_1;
    if(when_BranchPlugin_l213_1) begin
      early0_BranchPlugin_logic_jumpLogic_history_shifter_2 = _zz_early0_BranchPlugin_logic_jumpLogic_history_shifter_2[11 : 0];
    end
  end

  always @(*) begin
    early0_BranchPlugin_logic_jumpLogic_history_shifter_1 = early0_BranchPlugin_logic_jumpLogic_history_shifter;
    if(when_BranchPlugin_l213) begin
      early0_BranchPlugin_logic_jumpLogic_history_shifter_1 = _zz_early0_BranchPlugin_logic_jumpLogic_history_shifter_1[11 : 0];
    end
  end

  assign execute_ctrl2_down_COMMIT_lane0 = execute_ctrl2_COMMIT_lane0_bypass;
  always @(*) begin
    execute_ctrl2_COMMIT_lane0_bypass = execute_ctrl2_up_COMMIT_lane0;
    if(when_EnvPlugin_l214) begin
      if(when_EnvPlugin_l218) begin
        execute_ctrl2_COMMIT_lane0_bypass = 1'b0;
      end
    end
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
              execute_ctrl2_COMMIT_lane0_bypass = 1'b0;
            end
          end
        end
      end
    endcase
  end

  assign execute_ctrl2_down_TRAP_lane0 = execute_ctrl2_TRAP_lane0_bypass;
  always @(*) begin
    execute_ctrl2_TRAP_lane0_bypass = execute_ctrl2_up_TRAP_lane0;
    if(when_EnvPlugin_l214) begin
      execute_ctrl2_TRAP_lane0_bypass = 1'b1;
    end
    if(CsrAccessPlugin_logic_fsm_inject_flushReg) begin
      execute_ctrl2_TRAP_lane0_bypass = 1'b1;
    end
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
              execute_ctrl2_TRAP_lane0_bypass = 1'b1;
            end else begin
              if(CsrAccessPlugin_logic_fsm_inject_busTrapReg) begin
                execute_ctrl2_TRAP_lane0_bypass = 1'b1;
              end
            end
          end
        end
      end
    endcase
  end

  always @(*) begin
    _zz_4 = 1'b0;
    if(LsuPlugin_logic_storeBuffer_push_valid) begin
      _zz_4 = 1'b1;
    end
  end

  always @(*) begin
    _zz_5 = 1'b0;
    if(BtbPlugin_logic_ras_write_valid) begin
      _zz_5 = 1'b1;
    end
  end

  always @(*) begin
    _zz_6 = 1'b0;
    if(GSharePlugin_logic_mem_writes_0_valid) begin
      _zz_6 = 1'b1;
    end
  end

  assign fetch_logic_ctrls_2_down_FetchL1Plugin_logic_HAZARD = fetch_logic_ctrls_2_FetchL1Plugin_logic_HAZARD_bypass;
  always @(*) begin
    _zz_fetch_logic_ctrls_0_haltRequest_FetchL1Plugin_l224 = 1'b0;
    if(when_FetchL1Plugin_l223) begin
      _zz_fetch_logic_ctrls_0_haltRequest_FetchL1Plugin_l224 = 1'b1;
    end
  end

  always @(*) begin
    _zz_7 = 1'b0;
    if(FetchL1Plugin_logic_plru_write_valid) begin
      _zz_7 = 1'b1;
    end
  end

  always @(*) begin
    _zz_8 = 1'b0;
    if(FetchL1Plugin_logic_banks_1_write_valid) begin
      _zz_8 = 1'b1;
    end
  end

  always @(*) begin
    _zz_9 = 1'b0;
    if(FetchL1Plugin_logic_banks_0_write_valid) begin
      _zz_9 = 1'b1;
    end
  end

  always @(*) begin
    _zz_10 = 1'b0;
    if(PrefetcherRptPlugin_logic_storage_write_valid) begin
      _zz_10 = 1'b1;
    end
  end

  assign AlignerPlugin_api_singleFetch = 1'b0;
  assign AlignerPlugin_api_haltIt = 1'b0;
  always @(*) begin
    DispatchPlugin_api_haltDispatch = 1'b0;
    if(_zz_11) begin
      DispatchPlugin_api_haltDispatch = 1'b1;
    end
    if(LsuPlugin_logic_storeBuffer_holdHart_waitIt) begin
      DispatchPlugin_api_haltDispatch = 1'b1;
    end
    if(LsuPlugin_logic_onCtrl_hartRegulation_valid) begin
      DispatchPlugin_api_haltDispatch = 1'b1;
    end
  end

  always @(*) begin
    CsrRamPlugin_api_holdRead = 1'b0;
    if(PerformanceCounterPlugin_logic_csrRead_requested) begin
      if(when_PerformanceCounterPlugin_l417) begin
        CsrRamPlugin_api_holdRead = 1'b1;
      end
    end
  end

  always @(*) begin
    CsrRamPlugin_api_holdWrite = 1'b0;
    if(PerformanceCounterPlugin_logic_fsm_holdCsrWrite) begin
      CsrRamPlugin_api_holdWrite = 1'b1;
    end
  end

  assign PrivilegedPlugin_api_harts_0_allowInterrupts = 1'b1;
  assign PrivilegedPlugin_api_harts_0_allowException = 1'b1;
  assign PrivilegedPlugin_api_harts_0_allowEbreakException = 1'b1;
  assign PrivilegedPlugin_api_harts_0_fpuEnable = 1'b0;
  always @(*) begin
    TrapPlugin_api_harts_0_redo = 1'b0;
    case(TrapPlugin_logic_harts_0_trap_fsm_stateReg)
      TrapPlugin_logic_harts_0_trap_fsm_RUNNING : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_COMPUTE : begin
        if(!when_TrapPlugin_l630) begin
          case(TrapPlugin_logic_harts_0_trap_pending_state_code)
            5'h0 : begin
            end
            5'h01 : begin
            end
            5'h02 : begin
            end
            5'h04 : begin
              TrapPlugin_api_harts_0_redo = 1'b1;
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
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    TrapPlugin_api_harts_0_askWake = 1'b0;
    if(when_TrapPlugin_l358) begin
      TrapPlugin_api_harts_0_askWake = 1'b1;
    end
  end

  always @(*) begin
    TrapPlugin_api_harts_0_rvTrap = 1'b0;
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
        TrapPlugin_api_harts_0_rvTrap = 1'b1;
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
      end
      default : begin
      end
    endcase
  end

  assign TrapPlugin_api_harts_0_holdPrivChange = 1'b0;
  always @(*) begin
    case(execute_ctrl2_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0)
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : begin
        early0_IntAluPlugin_logic_alu_bitwise = (execute_ctrl2_down_early0_SrcPlugin_SRC1_lane0 & execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0);
      end
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : begin
        early0_IntAluPlugin_logic_alu_bitwise = (execute_ctrl2_down_early0_SrcPlugin_SRC1_lane0 | execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0);
      end
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : begin
        early0_IntAluPlugin_logic_alu_bitwise = (execute_ctrl2_down_early0_SrcPlugin_SRC1_lane0 ^ execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0);
      end
      default : begin
        early0_IntAluPlugin_logic_alu_bitwise = 32'h0;
      end
    endcase
  end

  assign early0_IntAluPlugin_logic_alu_result = (_zz_early0_IntAluPlugin_logic_alu_result | _zz_early0_IntAluPlugin_logic_alu_result_2);
  assign execute_ctrl2_down_early0_IntAluPlugin_ALU_RESULT_lane0 = early0_IntAluPlugin_logic_alu_result;
  assign early0_IntAluPlugin_logic_wb_valid = execute_ctrl2_down_early0_IntAluPlugin_SEL_lane0;
  assign early0_IntAluPlugin_logic_wb_payload = execute_ctrl2_down_early0_IntAluPlugin_ALU_RESULT_lane0;
  // Reference line 20355 moved verbatim to replica_early0_shifter.
  // Reference line 20356 moved verbatim to replica_early0_shifter.
  // Reference line 20357 moved verbatim to replica_early0_shifter.
  // Reference line 20358 moved verbatim to replica_early0_shifter.
  // Reference line 20359 moved verbatim to replica_early0_shifter.
  assign early0_BarrelShifterPlugin_logic_wb_valid = execute_ctrl2_down_early0_BarrelShifterPlugin_SEL_lane0;
  assign early0_BarrelShifterPlugin_logic_wb_payload = execute_ctrl2_down_early0_BarrelShifterPlugin_SHIFT_RESULT_lane0;
  always @(*) begin
    LsuPlugin_logic_events_waiting = 1'b0;
    if(LsuPlugin_logic_storeBuffer_holdHart_waitIt) begin
      LsuPlugin_logic_events_waiting = 1'b1;
    end
    if(LsuPlugin_logic_onCtrl_hartRegulation_valid) begin
      LsuPlugin_logic_events_waiting = 1'b1;
    end
  end

  always @(*) begin
    LsuL1_ackUnlock = 1'b0;
    if(LsuPlugin_logic_onCtrl_io_cmdSent) begin
      LsuL1_ackUnlock = 1'b1;
    end
  end

  assign PrefetcherRptPlugin_logic_order_ready = PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_push_ready;
  assign PrefetcherRptPlugin_logic_queued_valid = PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_pop_valid;
  assign PrefetcherRptPlugin_logic_queued_payload_address = PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_pop_payload_address;
  assign PrefetcherRptPlugin_logic_queued_payload_unique = PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_pop_payload_unique;
  assign PrefetcherRptPlugin_logic_queued_payload_from = PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_pop_payload_from;
  assign PrefetcherRptPlugin_logic_queued_payload_to = PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_pop_payload_to;
  assign PrefetcherRptPlugin_logic_queued_payload_stride = PrefetcherRptPlugin_logic_order_queueWithOccupancy_io_pop_payload_stride;
  assign PrefetcherRptPlugin_logic_advanceAt = (PrefetcherRptPlugin_logic_queued_payload_from + PrefetcherRptPlugin_logic_counter);
  assign PrefetcherRptPlugin_logic_done = (PrefetcherRptPlugin_logic_advanceAt == PrefetcherRptPlugin_logic_queued_payload_to);
  assign PrefetcherRptPlugin_logic_queued_forkSerial_next_valid = PrefetcherRptPlugin_logic_queued_valid;
  assign PrefetcherRptPlugin_logic_queued_forkSerial_next_payload_address = PrefetcherRptPlugin_logic_queued_payload_address;
  assign PrefetcherRptPlugin_logic_queued_forkSerial_next_payload_unique = PrefetcherRptPlugin_logic_queued_payload_unique;
  assign PrefetcherRptPlugin_logic_queued_forkSerial_next_payload_from = PrefetcherRptPlugin_logic_queued_payload_from;
  assign PrefetcherRptPlugin_logic_queued_forkSerial_next_payload_to = PrefetcherRptPlugin_logic_queued_payload_to;
  assign PrefetcherRptPlugin_logic_queued_forkSerial_next_payload_stride = PrefetcherRptPlugin_logic_queued_payload_stride;
  assign PrefetcherRptPlugin_logic_queued_ready = (PrefetcherRptPlugin_logic_queued_forkSerial_next_ready && PrefetcherRptPlugin_logic_done);
  assign PrefetcherRptPlugin_logic_pip2_node_0_valid = PrefetcherRptPlugin_logic_queued_forkSerial_next_valid;
  assign PrefetcherRptPlugin_logic_queued_forkSerial_next_ready = (PrefetcherRptPlugin_logic_pip2_node_0_isReady || PrefetcherRptPlugin_logic_pip2_node_0_isCancel);
  assign PrefetcherRptPlugin_logic_pip2_node_0_CMD_address = PrefetcherRptPlugin_logic_queued_payload_address;
  assign PrefetcherRptPlugin_logic_pip2_node_0_CMD_unique = PrefetcherRptPlugin_logic_queued_payload_unique;
  assign PrefetcherRptPlugin_logic_pip2_node_0_CMD_from = PrefetcherRptPlugin_logic_queued_payload_from;
  assign PrefetcherRptPlugin_logic_pip2_node_0_CMD_to = PrefetcherRptPlugin_logic_queued_payload_to;
  assign PrefetcherRptPlugin_logic_pip2_node_0_CMD_stride = PrefetcherRptPlugin_logic_queued_payload_stride;
  assign PrefetcherRptPlugin_logic_pip2_node_0_MUL = ($signed(_zz_PrefetcherRptPlugin_logic_pip2_node_0_MUL) * $signed(PrefetcherRptPlugin_logic_queued_payload_stride));
  assign PrefetcherRptPlugin_logic_pip2_node_1_adder_ADDR = _zz_PrefetcherRptPlugin_logic_pip2_node_1_adder_ADDR;
  assign PrefetcherRptPlugin_io_valid = PrefetcherRptPlugin_logic_pip2_node_1_isValid;
  assign PrefetcherRptPlugin_logic_pip2_node_1_ready = PrefetcherRptPlugin_io_ready;
  assign PrefetcherRptPlugin_io_payload_address = PrefetcherRptPlugin_logic_pip2_node_1_adder_ADDR;
  assign PrefetcherRptPlugin_io_payload_unique = PrefetcherRptPlugin_logic_pip2_node_1_CMD_unique;
  always @(*) begin
    PrefetcherRptPlugin_logic_pip2_node_0_ready = PrefetcherRptPlugin_logic_pip2_node_1_ready;
    if(when_StageLink_l71) begin
      PrefetcherRptPlugin_logic_pip2_node_0_ready = 1'b1;
    end
  end

  assign when_StageLink_l71 = (! PrefetcherRptPlugin_logic_pip2_node_1_isValid);
  assign PrefetcherRptPlugin_logic_pip2_node_0_isFiring = (PrefetcherRptPlugin_logic_pip2_node_0_isValid && PrefetcherRptPlugin_logic_pip2_node_0_isReady);
  assign PrefetcherRptPlugin_logic_pip2_node_0_isValid = PrefetcherRptPlugin_logic_pip2_node_0_valid;
  assign PrefetcherRptPlugin_logic_pip2_node_0_isReady = PrefetcherRptPlugin_logic_pip2_node_0_ready;
  assign PrefetcherRptPlugin_logic_pip2_node_0_isCancel = 1'b0;
  assign PrefetcherRptPlugin_logic_pip2_node_1_isValid = PrefetcherRptPlugin_logic_pip2_node_1_valid;
  assign _zz_PrefetcherRptPlugin_logic_storage_read_rsp_tag = PrefetcherRptPlugin_logic_storage_ram_spinal_port0;
  assign PrefetcherRptPlugin_logic_storage_read_rsp_tag = _zz_PrefetcherRptPlugin_logic_storage_read_rsp_tag[14 : 0];
  assign PrefetcherRptPlugin_logic_storage_read_rsp_address = _zz_PrefetcherRptPlugin_logic_storage_read_rsp_tag[30 : 15];
  assign PrefetcherRptPlugin_logic_storage_read_rsp_stride = _zz_PrefetcherRptPlugin_logic_storage_read_rsp_tag[42 : 31];
  assign PrefetcherRptPlugin_logic_storage_read_rsp_score = _zz_PrefetcherRptPlugin_logic_storage_read_rsp_tag[47 : 43];
  assign PrefetcherRptPlugin_logic_storage_read_rsp_advance = _zz_PrefetcherRptPlugin_logic_storage_read_rsp_tag[50 : 48];
  assign PrefetcherRptPlugin_logic_storage_read_rsp_missed = _zz_PrefetcherRptPlugin_logic_storage_read_rsp_tag[51];
  assign execute_ctrl2_down_MUL_SRC1_lane0 = _zz_execute_ctrl2_down_MUL_SRC1_lane0;
  assign execute_ctrl2_down_MUL_SRC2_lane0 = _zz_execute_ctrl2_down_MUL_SRC2_lane0;
  assign execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_0_lane0 = (execute_ctrl2_down_MUL_SRC1_lane0[16 : 0] * execute_ctrl2_down_MUL_SRC2_lane0[16 : 0]);
  assign execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_1_lane0 = _zz_execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_1_lane0;
  assign execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_2_lane0 = _zz_execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_2_lane0;
  assign execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_3_lane0 = _zz_execute_ctrl2_down_early0_MulPlugin_logic_mul_VALUES_3_lane0;
  always @(*) begin
    _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_0_lane0 = 61'h0;
    _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_0_lane0[33 : 0] = execute_ctrl3_down_early0_MulPlugin_logic_mul_VALUES_0_lane0[33 : 0];
    _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_0_lane0[60 : 34] = execute_ctrl3_down_early0_MulPlugin_logic_mul_VALUES_3_lane0[26 : 0];
  end

  always @(*) begin
    _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_0_lane0_1 = 61'h0;
    _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_0_lane0_1[60 : 17] = execute_ctrl3_down_early0_MulPlugin_logic_mul_VALUES_1_lane0[43 : 0];
  end

  always @(*) begin
    _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_0_lane0_2 = 61'h0;
    _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_0_lane0_2[60 : 17] = execute_ctrl3_down_early0_MulPlugin_logic_mul_VALUES_2_lane0[43 : 0];
  end

  always @(*) begin
    _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_1_lane0 = 3'b000;
    _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_1_lane0[2 : 0] = execute_ctrl3_down_early0_MulPlugin_logic_mul_VALUES_3_lane0[29 : 27];
  end

  always @(*) begin
    _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_1_lane0_1 = 3'b000;
    _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_1_lane0_1[2 : 0] = execute_ctrl3_down_early0_MulPlugin_logic_mul_VALUES_1_lane0[46 : 44];
  end

  always @(*) begin
    _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_1_lane0_2 = 3'b000;
    _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_1_lane0_2[2 : 0] = execute_ctrl3_down_early0_MulPlugin_logic_mul_VALUES_2_lane0[46 : 44];
  end

  assign execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_0_lane0 = (_zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_0_lane0_3 + _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_0_lane0_6);
  assign execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_1_lane0 = (_zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_1_lane0_3 + _zz_execute_ctrl3_down_early0_MulPlugin_logic_steps_0_adders_1_lane0_6);
  always @(*) begin
    _zz_execute_ctrl4_down_early0_MulPlugin_logic_steps_1_adders_0_lane0 = 66'h0;
    _zz_execute_ctrl4_down_early0_MulPlugin_logic_steps_1_adders_0_lane0[62 : 0] = execute_ctrl4_down_early0_MulPlugin_logic_steps_0_adders_0_lane0[62 : 0];
  end

  always @(*) begin
    _zz_execute_ctrl4_down_early0_MulPlugin_logic_steps_1_adders_0_lane0_1 = 66'h0;
    _zz_execute_ctrl4_down_early0_MulPlugin_logic_steps_1_adders_0_lane0_1[65 : 61] = execute_ctrl4_down_early0_MulPlugin_logic_steps_0_adders_1_lane0[4 : 0];
  end

  assign execute_ctrl4_down_early0_MulPlugin_logic_steps_1_adders_0_lane0 = (_zz_execute_ctrl4_down_early0_MulPlugin_logic_steps_1_adders_0_lane0 + _zz_execute_ctrl4_down_early0_MulPlugin_logic_steps_1_adders_0_lane0_1);
  assign early0_MulPlugin_logic_formatBus_valid = execute_ctrl4_down_early0_MulPlugin_SEL_lane0;
  assign early0_MulPlugin_logic_formatBus_payload = (execute_ctrl4_down_MulPlugin_HIGH_lane0 ? execute_ctrl4_down_early0_MulPlugin_logic_steps_1_adders_0_lane0[63 : 32] : execute_ctrl4_down_early0_MulPlugin_logic_steps_1_adders_0_lane0[31 : 0]);
  assign execute_ctrl2_down_RsUnsignedPlugin_RS1_FORMATED_lane0 = execute_ctrl2_up_integer_RS1_lane0;
  assign execute_ctrl2_down_RsUnsignedPlugin_RS2_FORMATED_lane0 = execute_ctrl2_up_integer_RS2_lane0;
  assign execute_ctrl2_down_RsUnsignedPlugin_RS1_REVERT_lane0 = (execute_ctrl2_down_RsUnsignedPlugin_RS1_SIGNED_lane0 && execute_ctrl2_down_RsUnsignedPlugin_RS1_FORMATED_lane0[31]);
  assign execute_ctrl2_down_RsUnsignedPlugin_RS2_REVERT_lane0 = (execute_ctrl2_down_RsUnsignedPlugin_RS2_SIGNED_lane0 && execute_ctrl2_down_RsUnsignedPlugin_RS2_FORMATED_lane0[31]);
  assign execute_ctrl2_down_RsUnsignedPlugin_RS1_UNSIGNED_lane0 = ((execute_ctrl2_down_RsUnsignedPlugin_RS1_REVERT_lane0 ? (~ execute_ctrl2_down_RsUnsignedPlugin_RS1_FORMATED_lane0) : execute_ctrl2_down_RsUnsignedPlugin_RS1_FORMATED_lane0) + _zz_execute_ctrl2_down_RsUnsignedPlugin_RS1_UNSIGNED_lane0);
