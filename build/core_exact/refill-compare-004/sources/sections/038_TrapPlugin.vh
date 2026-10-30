  assign PerformanceCounterPlugin_logic_fsm_wantKill = 1'b0;
  always @(*) begin
    PerformanceCounterPlugin_logic_fsm_csrReadCmd_ready = 1'b0;
    case(PerformanceCounterPlugin_logic_fsm_stateReg)
      PerformanceCounterPlugin_logic_fsm_IDLE : begin
        if(!PerformanceCounterPlugin_logic_fsm_csrWriteCmd_valid) begin
          if(!PerformanceCounterPlugin_logic_fsm_flusherCmd_valid) begin
            if(PerformanceCounterPlugin_logic_fsm_csrReadCmd_valid) begin
              PerformanceCounterPlugin_logic_fsm_csrReadCmd_ready = 1'b1;
            end
          end
        end
      end
      PerformanceCounterPlugin_logic_fsm_READ_LOW : begin
      end
      PerformanceCounterPlugin_logic_fsm_CALC_LOW : begin
      end
      PerformanceCounterPlugin_logic_fsm_READ_HIGH : begin
      end
      PerformanceCounterPlugin_logic_fsm_CALC_HIGH : begin
      end
      PerformanceCounterPlugin_logic_fsm_CSR_WRITE : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    PerformanceCounterPlugin_logic_fsm_flusherCmd_ready = 1'b0;
    case(PerformanceCounterPlugin_logic_fsm_stateReg)
      PerformanceCounterPlugin_logic_fsm_IDLE : begin
        if(!PerformanceCounterPlugin_logic_fsm_csrWriteCmd_valid) begin
          if(PerformanceCounterPlugin_logic_fsm_flusherCmd_valid) begin
            PerformanceCounterPlugin_logic_fsm_flusherCmd_ready = 1'b1;
          end
        end
      end
      PerformanceCounterPlugin_logic_fsm_READ_LOW : begin
      end
      PerformanceCounterPlugin_logic_fsm_CALC_LOW : begin
      end
      PerformanceCounterPlugin_logic_fsm_READ_HIGH : begin
      end
      PerformanceCounterPlugin_logic_fsm_CALC_HIGH : begin
      end
      PerformanceCounterPlugin_logic_fsm_CSR_WRITE : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    PerformanceCounterPlugin_logic_fsm_csrWriteCmd_ready = 1'b0;
    case(PerformanceCounterPlugin_logic_fsm_stateReg)
      PerformanceCounterPlugin_logic_fsm_IDLE : begin
      end
      PerformanceCounterPlugin_logic_fsm_READ_LOW : begin
      end
      PerformanceCounterPlugin_logic_fsm_CALC_LOW : begin
      end
      PerformanceCounterPlugin_logic_fsm_READ_HIGH : begin
      end
      PerformanceCounterPlugin_logic_fsm_CALC_HIGH : begin
      end
      PerformanceCounterPlugin_logic_fsm_CSR_WRITE : begin
        PerformanceCounterPlugin_logic_fsm_csrWriteCmd_ready = 1'b1;
      end
      default : begin
      end
    endcase
  end

  assign _zz_PerformanceCounterPlugin_logic_fsm_cmd_address = PerformanceCounterPlugin_logic_fsm_cmd_oh[0];
  assign _zz_PerformanceCounterPlugin_logic_fsm_cmd_address_1 = PerformanceCounterPlugin_logic_fsm_cmd_oh[1];
  assign PerformanceCounterPlugin_logic_fsm_cmd_address = ((_zz_PerformanceCounterPlugin_logic_fsm_cmd_address ? 2'b01 : 2'b00) | (_zz_PerformanceCounterPlugin_logic_fsm_cmd_address_1 ? 2'b00 : 2'b00));
  always @(*) begin
    PerformanceCounterPlugin_logic_readPort_valid = 1'b0;
    case(PerformanceCounterPlugin_logic_fsm_stateReg)
      PerformanceCounterPlugin_logic_fsm_IDLE : begin
      end
      PerformanceCounterPlugin_logic_fsm_READ_LOW : begin
        PerformanceCounterPlugin_logic_readPort_valid = 1'b1;
      end
      PerformanceCounterPlugin_logic_fsm_CALC_LOW : begin
      end
      PerformanceCounterPlugin_logic_fsm_READ_HIGH : begin
        PerformanceCounterPlugin_logic_readPort_valid = 1'b1;
      end
      PerformanceCounterPlugin_logic_fsm_CALC_HIGH : begin
      end
      PerformanceCounterPlugin_logic_fsm_CSR_WRITE : begin
      end
      default : begin
      end
    endcase
  end

  assign PerformanceCounterPlugin_logic_readPort_address = {PerformanceCounterPlugin_logic_fsm_cmd_address,PerformanceCounterPlugin_logic_fsm_carry};
  always @(*) begin
    PerformanceCounterPlugin_logic_writePort_valid = 1'b0;
    case(PerformanceCounterPlugin_logic_fsm_stateReg)
      PerformanceCounterPlugin_logic_fsm_IDLE : begin
      end
      PerformanceCounterPlugin_logic_fsm_READ_LOW : begin
      end
      PerformanceCounterPlugin_logic_fsm_CALC_LOW : begin
        PerformanceCounterPlugin_logic_writePort_valid = 1'b1;
      end
      PerformanceCounterPlugin_logic_fsm_READ_HIGH : begin
      end
      PerformanceCounterPlugin_logic_fsm_CALC_HIGH : begin
        PerformanceCounterPlugin_logic_writePort_valid = 1'b1;
      end
      PerformanceCounterPlugin_logic_fsm_CSR_WRITE : begin
      end
      default : begin
      end
    endcase
  end

  assign PerformanceCounterPlugin_logic_writePort_address = PerformanceCounterPlugin_logic_readPort_address;
  always @(*) begin
    PerformanceCounterPlugin_logic_writePort_data = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    case(PerformanceCounterPlugin_logic_fsm_stateReg)
      PerformanceCounterPlugin_logic_fsm_IDLE : begin
      end
      PerformanceCounterPlugin_logic_fsm_READ_LOW : begin
      end
      PerformanceCounterPlugin_logic_fsm_CALC_LOW : begin
        PerformanceCounterPlugin_logic_writePort_data = _zz_PerformanceCounterPlugin_logic_writePort_data[31:0];
      end
      PerformanceCounterPlugin_logic_fsm_READ_HIGH : begin
      end
      PerformanceCounterPlugin_logic_fsm_CALC_HIGH : begin
        PerformanceCounterPlugin_logic_writePort_data = _zz_PerformanceCounterPlugin_logic_writePort_data_1[31:0];
      end
      PerformanceCounterPlugin_logic_fsm_CSR_WRITE : begin
      end
      default : begin
      end
    endcase
  end

  assign PerformanceCounterPlugin_logic_fsm_calc_a = (PerformanceCounterPlugin_logic_fsm_carry ? PerformanceCounterPlugin_logic_fsm_ramReaded : {PerformanceCounterPlugin_logic_fsm_ramReaded[31 : 7],_zz_PerformanceCounterPlugin_logic_fsm_calc_a});
  assign PerformanceCounterPlugin_logic_fsm_calc_b = (PerformanceCounterPlugin_logic_fsm_carry ? 8'h01 : _zz_PerformanceCounterPlugin_logic_fsm_calc_b);
  assign PerformanceCounterPlugin_logic_fsm_calc_sum = ({1'b0,PerformanceCounterPlugin_logic_fsm_calc_a} + _zz_PerformanceCounterPlugin_logic_fsm_calc_sum);
  assign PerformanceCounterPlugin_logic_fsm_idleCsrAddress = (PerformanceCounterPlugin_logic_fsm_csrReadCmd_valid ? PerformanceCounterPlugin_logic_fsm_csrReadCmd_payload_address : PerformanceCounterPlugin_logic_fsm_csrWriteCmd_payload_address);
  always @(*) begin
    PerformanceCounterPlugin_logic_fsm_holdCsrWrite = 1'b1;
    case(PerformanceCounterPlugin_logic_fsm_stateReg)
      PerformanceCounterPlugin_logic_fsm_IDLE : begin
        PerformanceCounterPlugin_logic_fsm_holdCsrWrite = 1'b0;
      end
      PerformanceCounterPlugin_logic_fsm_READ_LOW : begin
      end
      PerformanceCounterPlugin_logic_fsm_CALC_LOW : begin
      end
      PerformanceCounterPlugin_logic_fsm_READ_HIGH : begin
      end
      PerformanceCounterPlugin_logic_fsm_CALC_HIGH : begin
      end
      PerformanceCounterPlugin_logic_fsm_CSR_WRITE : begin
        PerformanceCounterPlugin_logic_fsm_holdCsrWrite = 1'b0;
      end
      default : begin
      end
    endcase
  end

  assign PerformanceCounterPlugin_logic_flusher_hits = {PerformanceCounterPlugin_logic_counters_instret_needFlush,PerformanceCounterPlugin_logic_counters_cycle_needFlush};
  assign PerformanceCounterPlugin_logic_flusher_hit = (|PerformanceCounterPlugin_logic_flusher_hits);
  assign PerformanceCounterPlugin_logic_flusher_hits_ohFirst_input = PerformanceCounterPlugin_logic_flusher_hits;
  assign PerformanceCounterPlugin_logic_flusher_hits_ohFirst_masked = (PerformanceCounterPlugin_logic_flusher_hits_ohFirst_input & (~ _zz_PerformanceCounterPlugin_logic_flusher_hits_ohFirst_masked));
  assign PerformanceCounterPlugin_logic_flusher_oh = PerformanceCounterPlugin_logic_flusher_hits_ohFirst_masked;
  assign PerformanceCounterPlugin_logic_fsm_flusherCmd_valid = PerformanceCounterPlugin_logic_flusher_hit;
  assign PerformanceCounterPlugin_logic_fsm_flusherCmd_payload_oh = PerformanceCounterPlugin_logic_flusher_oh;
  assign PerformanceCounterPlugin_logic_csrDecode_addr = CsrAccessPlugin_bus_decode_address[1 : 0];
  always @(*) begin
    PerformanceCounterPlugin_logic_csrDecode_mok = 1'bx;
    case(PerformanceCounterPlugin_logic_csrDecode_addr)
      2'b00 : begin
        PerformanceCounterPlugin_logic_csrDecode_mok = PerformanceCounterPlugin_logic_counters_cycle_mcounteren;
      end
      2'b10 : begin
        PerformanceCounterPlugin_logic_csrDecode_mok = PerformanceCounterPlugin_logic_counters_instret_mcounteren;
      end
      default : begin
      end
    endcase
  end

  assign PerformanceCounterPlugin_logic_csrDecode_sok = 1'b1;
  assign PerformanceCounterPlugin_logic_csrDecode_vok = 1'b1;
  assign PerformanceCounterPlugin_logic_csrDecode_privilege = PrivilegedPlugin_logic_harts_0_privilege;
  assign PerformanceCounterPlugin_logic_csrDecode_privOk = (&((PerformanceCounterPlugin_logic_csrDecode_privilege ^ 3'b100) | {PerformanceCounterPlugin_logic_csrDecode_vok,PerformanceCounterPlugin_logic_csrDecode_mok,PerformanceCounterPlugin_logic_csrDecode_sok}));
  assign PerformanceCounterPlugin_logic_fsm_csrReadCmd_fire = (PerformanceCounterPlugin_logic_fsm_csrReadCmd_valid && PerformanceCounterPlugin_logic_fsm_csrReadCmd_ready);
  assign PerformanceCounterPlugin_logic_csrRead_requested = (CsrAccessPlugin_bus_read_valid && REG_CSR_PerformanceCounterPlugin_logic_csrFilter);
  assign PerformanceCounterPlugin_logic_fsm_csrReadCmd_valid = (PerformanceCounterPlugin_logic_csrRead_requested && (! PerformanceCounterPlugin_logic_csrRead_fired));
  assign PerformanceCounterPlugin_logic_fsm_csrReadCmd_payload_address = CsrAccessPlugin_bus_read_address[1 : 0];
  assign when_PerformanceCounterPlugin_l417 = ((! PerformanceCounterPlugin_logic_csrRead_fired) || (! PerformanceCounterPlugin_logic_fsm_done));
  assign PerformanceCounterPlugin_logic_fsm_csrWriteCmd_fire = (PerformanceCounterPlugin_logic_fsm_csrWriteCmd_valid && PerformanceCounterPlugin_logic_fsm_csrWriteCmd_ready);
  always @(*) begin
    PerformanceCounterPlugin_logic_fsm_csrWriteCmd_valid = 1'b0;
    if(when_CsrAccessPlugin_l375_3) begin
      if(when_PerformanceCounterPlugin_l432) begin
        PerformanceCounterPlugin_logic_fsm_csrWriteCmd_valid = 1'b1;
      end
    end
  end

  assign PerformanceCounterPlugin_logic_fsm_csrWriteCmd_payload_address = CsrAccessPlugin_bus_write_address[1 : 0];
  always @(*) begin
    TrapPlugin_logic_harts_0_crsPorts_write_valid = 1'b0;
    case(TrapPlugin_logic_harts_0_trap_fsm_stateReg)
      TrapPlugin_logic_harts_0_trap_fsm_RUNNING : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_COMPUTE : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_EPC : begin
        TrapPlugin_logic_harts_0_crsPorts_write_valid = 1'b1;
      end
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_TVAL : begin
        TrapPlugin_logic_harts_0_crsPorts_write_valid = 1'b1;
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
    TrapPlugin_logic_harts_0_crsPorts_write_address = 3'bxxx;
    case(TrapPlugin_logic_harts_0_trap_fsm_stateReg)
      TrapPlugin_logic_harts_0_trap_fsm_RUNNING : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_COMPUTE : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_EPC : begin
        TrapPlugin_logic_harts_0_crsPorts_write_address = _zz_TrapPlugin_logic_harts_0_crsPorts_write_address;
      end
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_TVAL : begin
        TrapPlugin_logic_harts_0_crsPorts_write_address = _zz_TrapPlugin_logic_harts_0_crsPorts_write_address_1;
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
    TrapPlugin_logic_harts_0_crsPorts_write_data = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    case(TrapPlugin_logic_harts_0_trap_fsm_stateReg)
      TrapPlugin_logic_harts_0_trap_fsm_RUNNING : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_COMPUTE : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_EPC : begin
        TrapPlugin_logic_harts_0_crsPorts_write_data = TrapPlugin_logic_harts_0_trap_pending_pc;
      end
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_TVAL : begin
        TrapPlugin_logic_harts_0_crsPorts_write_data = TrapPlugin_logic_harts_0_trap_fsm_buffer_trap_tval;
        if(TrapPlugin_logic_harts_0_trap_fsm_triggerEbreakReg) begin
          TrapPlugin_logic_harts_0_crsPorts_write_data = TrapPlugin_logic_harts_0_trap_pending_pc;
        end
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

  assign TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_0_id = 5'h07;
  assign TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_0_priority = 4'b0011;
  assign TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_0_privilege = 3'b011;
  assign TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_0_valid = (((PrivilegedPlugin_logic_harts_0_m_ip_mtip && PrivilegedPlugin_logic_harts_0_m_ie_mtie) && 1'b1) && (! 1'b0));
  assign TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_1_id = 5'h03;
  assign TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_1_priority = 4'b0010;
  assign TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_1_privilege = 3'b011;
  assign TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_1_valid = (((PrivilegedPlugin_logic_harts_0_m_ip_msip && PrivilegedPlugin_logic_harts_0_m_ie_msie) && 1'b1) && (! 1'b0));
  assign TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_2_id = 5'h0b;
  assign TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_2_priority = 4'b0001;
  assign TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_2_privilege = 3'b011;
  assign TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_2_valid = (((PrivilegedPlugin_logic_harts_0_m_ip_meip && PrivilegedPlugin_logic_harts_0_m_ie_meie) && 1'b1) && (! 1'b0));
  assign TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_3_id = 5'h0d;
  assign TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_3_priority = 4'b1011;
  assign TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_3_privilege = 3'b011;
  assign TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_3_valid = ((((PerformanceCounterPlugin_logic_interrupt_ip && PerformanceCounterPlugin_logic_interrupt_ie) && PerformanceCounterPlugin_logic_interrupt_nonGuestMode) && 1'b1) && (! 1'b0));
  assign _zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_id = ((! TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_1_valid) || (TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_0_valid && (TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_0_priority < TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_1_priority)));
  assign _zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_priority = (_zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_id ? TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_0_priority : TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_1_priority);
  assign _zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_valid = (_zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_id ? TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_0_valid : TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_1_valid);
  assign _zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_id_1 = ((! TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_3_valid) || (TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_2_valid && (TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_2_priority < TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_3_priority)));
  assign _zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_priority_1 = (_zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_id_1 ? TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_2_priority : TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_3_priority);
  assign _zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_valid_1 = (_zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_id_1 ? TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_2_valid : TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_interrupts_3_valid);
  assign _zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_id_2 = ((! _zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_valid_1) || (_zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_valid && (_zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_priority < _zz_TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_priority_1)));
  assign TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_triggerId = (TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_valid ? TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_id : 5'h0);
  assign TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_triggerPriority = (TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_valid ? TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_priority : 4'b0000);
  assign TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_effectiveInterrupt = (TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_valid ? TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_id : 5'h0);
  assign TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_defaultPriority = TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_priority;
  assign when_Utils_l1360 = (! TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_valid);
  always @(*) begin
    if(when_Utils_l1360) begin
      TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_effectivePriority = 8'h0;
    end else begin
      if(when_Utils_l1363) begin
        TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_effectivePriority = ((TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_defaultPriority < 4'b0000) ? 8'h0 : 8'hff);
      end else begin
        TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_effectivePriority = {4'd0, TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_priority};
      end
    end
  end

  assign when_Utils_l1363 = (TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_priority == 4'b0000);
  assign TrapPlugin_logic_harts_0_interrupt_result_id = TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_id;
  assign TrapPlugin_logic_harts_0_interrupt_result_privilege = TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_privilege;
  assign TrapPlugin_logic_harts_0_interrupt_result_valid = (TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_valid && (PrivilegedPlugin_logic_harts_0_m_status_mie || (! PrivilegedPlugin_logic_harts_0_withMachinePrivilege)));
  assign TrapPlugin_logic_harts_0_interrupt_valid = TrapPlugin_logic_harts_0_interrupt_result_valid;
  assign TrapPlugin_logic_harts_0_interrupt_code = TrapPlugin_logic_harts_0_interrupt_result_id;
  assign TrapPlugin_logic_harts_0_interrupt_targetPrivilege = TrapPlugin_logic_harts_0_interrupt_result_privilege;
  assign TrapPlugin_logic_harts_0_interrupt_pendingInterrupt = (TrapPlugin_logic_harts_0_interrupt_validBuffer && PrivilegedPlugin_api_harts_0_allowInterrupts);
  assign when_TrapPlugin_l358 = (|TrapPlugin_logic_harts_0_interrupt_privilegeTriggers_0_result_valid);
  assign _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_valid = (early0_EnvPlugin_logic_trapPort_valid && 1'b1);
  assign _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_3_valid = (FetchL1Plugin_logic_trapPort_valid && 1'b1);
  assign _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_0_valid = (LsuPlugin_logic_trapPort_valid && 1'b1);
  assign _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_valid_1 = (CsrAccessPlugin_logic_trapPort_valid && 1'b1);
  assign _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_valid = (DecoderPlugin_logic_laneLogic_0_trapPort_valid && 1'b1);
  assign _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_valid_1 = (DecoderPlugin_logic_laneLogic_1_trapPort_valid && 1'b1);
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_0_valid = (|_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_0_valid);
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_0_payload_exception = LsuPlugin_logic_trapPort_payload_exception;
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_0_payload_tval = LsuPlugin_logic_trapPort_payload_tval;
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_0_payload_tval2 = LsuPlugin_logic_trapPort_payload_tval2;
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_0_payload_code = LsuPlugin_logic_trapPort_payload_code;
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_0_payload_arg = LsuPlugin_logic_trapPort_payload_arg;
  assign _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_payload_exception = {(_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_valid_1 && (&(! (_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_valid && (early0_EnvPlugin_logic_trapPort_payload_laneAge < CsrAccessPlugin_logic_trapPort_payload_laneAge))))),(_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_valid && (&(! (_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_valid_1 && (CsrAccessPlugin_logic_trapPort_payload_laneAge < early0_EnvPlugin_logic_trapPort_payload_laneAge)))))};
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_valid = (|{_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_valid_1,_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_valid});
  assign _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_payload_exception_1 = ((_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_payload_exception[0] ? {early0_EnvPlugin_logic_trapPort_payload_arg,early0_EnvPlugin_logic_trapPort_payload_code,early0_EnvPlugin_logic_trapPort_payload_tval2,early0_EnvPlugin_logic_trapPort_payload_tval,early0_EnvPlugin_logic_trapPort_payload_exception} : 73'h0) | (_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_payload_exception[1] ? {CsrAccessPlugin_logic_trapPort_payload_arg,CsrAccessPlugin_logic_trapPort_payload_code,CsrAccessPlugin_logic_trapPort_payload_tval2,CsrAccessPlugin_logic_trapPort_payload_tval,CsrAccessPlugin_logic_trapPort_payload_exception} : 73'h0));
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_payload_exception = _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_payload_exception_1[0];
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_payload_tval = _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_payload_exception_1[32 : 1];
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_payload_tval2 = _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_payload_exception_1[64 : 33];
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_payload_code = _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_payload_exception_1[69 : 65];
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_payload_arg = _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_payload_exception_1[72 : 70];
  assign _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_payload_exception = {(_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_valid_1 && (&(! (_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_valid && (DecoderPlugin_logic_laneLogic_0_trapPort_payload_laneAge < DecoderPlugin_logic_laneLogic_1_trapPort_payload_laneAge))))),(_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_valid && (&(! (_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_valid_1 && (DecoderPlugin_logic_laneLogic_1_trapPort_payload_laneAge < DecoderPlugin_logic_laneLogic_0_trapPort_payload_laneAge)))))};
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_valid = (|{_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_valid_1,_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_valid});
  assign _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_payload_exception_1 = ((_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_payload_exception[0] ? {DecoderPlugin_logic_laneLogic_0_trapPort_payload_arg,DecoderPlugin_logic_laneLogic_0_trapPort_payload_code,DecoderPlugin_logic_laneLogic_0_trapPort_payload_tval2,DecoderPlugin_logic_laneLogic_0_trapPort_payload_tval,DecoderPlugin_logic_laneLogic_0_trapPort_payload_exception} : 73'h0) | (_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_payload_exception[1] ? {DecoderPlugin_logic_laneLogic_1_trapPort_payload_arg,DecoderPlugin_logic_laneLogic_1_trapPort_payload_code,DecoderPlugin_logic_laneLogic_1_trapPort_payload_tval2,DecoderPlugin_logic_laneLogic_1_trapPort_payload_tval,DecoderPlugin_logic_laneLogic_1_trapPort_payload_exception} : 73'h0));
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_payload_exception = _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_payload_exception_1[0];
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_payload_tval = _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_payload_exception_1[32 : 1];
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_payload_tval2 = _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_payload_exception_1[64 : 33];
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_payload_code = _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_payload_exception_1[69 : 65];
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_payload_arg = _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_payload_exception_1[72 : 70];
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_3_valid = (|_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_3_valid);
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_3_payload_exception = FetchL1Plugin_logic_trapPort_payload_exception;
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_3_payload_tval = FetchL1Plugin_logic_trapPort_payload_tval;
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_3_payload_tval2 = FetchL1Plugin_logic_trapPort_payload_tval2;
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_3_payload_code = FetchL1Plugin_logic_trapPort_payload_code;
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_3_payload_arg = FetchL1Plugin_logic_trapPort_payload_arg;
  assign _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh = {TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_3_valid,TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_valid,TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_valid,TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_0_valid};
  assign _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh_1 = _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh[0];
  assign _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh_2 = _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh[1];
  assign _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh_3 = _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh[2];
  always @(*) begin
    _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh_4[0] = (_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh_1 && (! 1'b0));
    _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh_4[1] = (_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh_2 && (! _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh_1));
    _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh_4[2] = (_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh_3 && (! (|{_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh_2,_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh_1})));
    _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh_4[3] = (_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh[3] && (! (|{_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh_3,_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh_2,_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh_1})));
  end

