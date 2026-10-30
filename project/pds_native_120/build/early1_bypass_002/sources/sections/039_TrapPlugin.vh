  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_oh = _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_oh_4;
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_down_valid = (|{_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_valid_1,_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_valid,_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_valid_1,_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_0_valid,_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_3_valid,_zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_valid});
  assign _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_down_payload_exception = (((TrapPlugin_logic_harts_0_trap_pending_arbiter_oh[0] ? {TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_0_payload_arg,TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_0_payload_code,TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_0_payload_tval2,TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_0_payload_tval,TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_0_payload_exception} : 73'h0) | (TrapPlugin_logic_harts_0_trap_pending_arbiter_oh[1] ? {TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_payload_arg,TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_payload_code,TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_payload_tval2,TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_payload_tval,TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_1_payload_exception} : 73'h0)) | ((TrapPlugin_logic_harts_0_trap_pending_arbiter_oh[2] ? {TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_payload_arg,TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_payload_code,TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_payload_tval2,TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_payload_tval,TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_2_payload_exception} : 73'h0) | (TrapPlugin_logic_harts_0_trap_pending_arbiter_oh[3] ? {TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_3_payload_arg,TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_3_payload_code,TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_3_payload_tval2,TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_3_payload_tval,TrapPlugin_logic_harts_0_trap_pending_arbiter_ports_3_payload_exception} : 73'h0)));
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_down_payload_exception = _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_down_payload_exception[0];
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_down_payload_tval = _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_down_payload_exception[32 : 1];
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_down_payload_tval2 = _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_down_payload_exception[64 : 33];
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_down_payload_code = _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_down_payload_exception[69 : 65];
  assign TrapPlugin_logic_harts_0_trap_pending_arbiter_down_payload_arg = _zz_TrapPlugin_logic_harts_0_trap_pending_arbiter_down_payload_exception[72 : 70];
  assign TrapPlugin_logic_harts_0_trap_pending_xret_sourcePrivilege = TrapPlugin_logic_harts_0_trap_pending_state_arg[2 : 0];
  assign TrapPlugin_logic_harts_0_trap_pending_xret_targetPrivilegeMapping_0 = {((PrivilegedPlugin_logic_harts_0_m_status_mpp == 2'b11) ? 1'b0 : PrivilegedPlugin_logic_harts_0_m_status_mpv),PrivilegedPlugin_logic_harts_0_m_status_mpp};
  always @(*) begin
    TrapPlugin_logic_harts_0_trap_pending_xret_targetPrivilege = TrapPlugin_logic_harts_0_trap_pending_xret_targetPrivilegeMapping_0;
    case(TrapPlugin_logic_harts_0_trap_pending_xret_sourcePrivilege)
      3'b011 : begin
        TrapPlugin_logic_harts_0_trap_pending_xret_targetPrivilege = TrapPlugin_logic_harts_0_trap_pending_xret_targetPrivilegeMapping_0;
      end
      default : begin
      end
    endcase
  end

  assign TrapPlugin_logic_harts_0_trap_exception_exceptionTargetPrivilegeUncapped = 3'b011;
  assign TrapPlugin_logic_harts_0_trap_exception_code = TrapPlugin_logic_harts_0_trap_pending_state_code;
  assign _zz_TrapPlugin_logic_harts_0_trap_exception_targetPrivilege = (PrivilegedPlugin_logic_harts_0_privilege | 3'b001);
  assign TrapPlugin_logic_harts_0_trap_exception_targetPrivilege = (($signed(_zz_TrapPlugin_logic_harts_0_trap_exception_targetPrivilege) < $signed(TrapPlugin_logic_harts_0_trap_exception_exceptionTargetPrivilegeUncapped)) ? TrapPlugin_logic_harts_0_trap_exception_exceptionTargetPrivilegeUncapped : _zz_TrapPlugin_logic_harts_0_trap_exception_targetPrivilege);
  assign PrivilegedPlugin_logic_harts_0_commitMask = {(((execute_ctrl5_down_LANE_SEL_lane1 && execute_ctrl5_down_isReady) && (! execute_lane1_ctrls_5_downIsCancel)) && execute_ctrl5_down_COMMIT_lane1),(((execute_ctrl5_down_LANE_SEL_lane0 && execute_ctrl5_down_isReady) && (! execute_lane0_ctrls_5_downIsCancel)) && execute_ctrl5_down_COMMIT_lane0)};
  assign TrapPlugin_logic_harts_0_trap_trigger_oh = {(((execute_ctrl4_down_LANE_SEL_lane1 && execute_ctrl4_down_isReady) && (! execute_lane1_ctrls_4_downIsCancel)) && execute_ctrl4_down_TRAP_lane1),(((execute_ctrl4_down_LANE_SEL_lane0 && execute_ctrl4_down_isReady) && (! execute_lane0_ctrls_4_downIsCancel)) && execute_ctrl4_down_TRAP_lane0)};
  assign TrapPlugin_logic_harts_0_trap_trigger_valid = (|TrapPlugin_logic_harts_0_trap_trigger_oh);
  assign _zz_TrapPlugin_logic_harts_0_trap_pending_pc = TrapPlugin_logic_harts_0_trap_trigger_oh[0];
  assign _zz_TrapPlugin_logic_harts_0_trap_pending_pc_1 = TrapPlugin_logic_harts_0_trap_trigger_oh[1];
  always @(*) begin
    TrapPlugin_logic_harts_0_trap_whitebox_trap = 1'b0;
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
        TrapPlugin_logic_harts_0_trap_whitebox_trap = 1'b1;
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
    TrapPlugin_logic_harts_0_trap_whitebox_interrupt = 1'bx;
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
        TrapPlugin_logic_harts_0_trap_whitebox_interrupt = TrapPlugin_logic_harts_0_trap_fsm_buffer_trap_interrupt;
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
    TrapPlugin_logic_harts_0_trap_whitebox_code = 5'bxxxxx;
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
        TrapPlugin_logic_harts_0_trap_whitebox_code = TrapPlugin_logic_harts_0_trap_fsm_buffer_trap_code;
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
    TrapPlugin_logic_harts_0_trap_historyPort_valid = 1'b0;
    case(TrapPlugin_logic_harts_0_trap_fsm_stateReg)
      TrapPlugin_logic_harts_0_trap_fsm_RUNNING : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_COMPUTE : begin
        TrapPlugin_logic_harts_0_trap_historyPort_valid = 1'b1;
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

  assign TrapPlugin_logic_harts_0_trap_historyPort_payload_history = TrapPlugin_logic_harts_0_trap_pending_history;
  always @(*) begin
    TrapPlugin_logic_harts_0_trap_pcPort_valid = 1'b0;
    case(TrapPlugin_logic_harts_0_trap_fsm_stateReg)
      TrapPlugin_logic_harts_0_trap_fsm_RUNNING : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_COMPUTE : begin
        if(!when_TrapPlugin_l630) begin
          case(TrapPlugin_logic_harts_0_trap_pending_state_code)
            5'h0 : begin
              TrapPlugin_logic_harts_0_trap_pcPort_valid = 1'b1;
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
        TrapPlugin_logic_harts_0_trap_pcPort_valid = 1'b1;
      end
      TrapPlugin_logic_harts_0_trap_fsm_XRET_EPC : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_XRET_APPLY : begin
        TrapPlugin_logic_harts_0_trap_pcPort_valid = 1'b1;
      end
      TrapPlugin_logic_harts_0_trap_fsm_JUMP : begin
        TrapPlugin_logic_harts_0_trap_pcPort_valid = 1'b1;
      end
      TrapPlugin_logic_harts_0_trap_fsm_LSU_FLUSH : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_FETCH_FLUSH : begin
      end
      default : begin
      end
    endcase
  end

  assign TrapPlugin_logic_harts_0_trap_pcPort_payload_fault = 1'b0;
  always @(*) begin
    TrapPlugin_logic_harts_0_trap_pcPort_payload_pc = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    case(TrapPlugin_logic_harts_0_trap_fsm_stateReg)
      TrapPlugin_logic_harts_0_trap_fsm_RUNNING : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_COMPUTE : begin
        if(!when_TrapPlugin_l630) begin
          case(TrapPlugin_logic_harts_0_trap_pending_state_code)
            5'h0 : begin
              TrapPlugin_logic_harts_0_trap_pcPort_payload_pc = TrapPlugin_logic_harts_0_trap_pending_pc;
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
        TrapPlugin_logic_harts_0_trap_pcPort_payload_pc = TrapPlugin_logic_harts_0_trap_fsm_readed;
      end
      TrapPlugin_logic_harts_0_trap_fsm_XRET_EPC : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_XRET_APPLY : begin
        TrapPlugin_logic_harts_0_trap_pcPort_payload_pc = TrapPlugin_logic_harts_0_trap_fsm_readed;
      end
      TrapPlugin_logic_harts_0_trap_fsm_JUMP : begin
        TrapPlugin_logic_harts_0_trap_pcPort_payload_pc = TrapPlugin_logic_harts_0_trap_fsm_jumpTarget;
      end
      TrapPlugin_logic_harts_0_trap_fsm_LSU_FLUSH : begin
      end
      TrapPlugin_logic_harts_0_trap_fsm_FETCH_FLUSH : begin
      end
      default : begin
      end
    endcase
  end

  assign TrapPlugin_logic_harts_0_trap_fsm_wantExit = 1'b0;
  always @(*) begin
    TrapPlugin_logic_harts_0_trap_fsm_wantStart = 1'b0;
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
      end
      default : begin
        TrapPlugin_logic_harts_0_trap_fsm_wantStart = 1'b1;
      end
    endcase
  end

  assign TrapPlugin_logic_harts_0_trap_fsm_wantKill = 1'b0;
  assign TrapPlugin_logic_harts_0_trap_fsm_inflightTrap = (|{execute_lane1_logic_trapPending[0],execute_lane0_logic_trapPending[0],DispatchPlugin_logic_trapPendings[0],decode_logic_trapPending[0]});
  assign TrapPlugin_logic_harts_0_trap_fsm_holdPort = (TrapPlugin_logic_harts_0_trap_fsm_inflightTrap || (! (TrapPlugin_logic_harts_0_trap_fsm_stateReg == TrapPlugin_logic_harts_0_trap_fsm_RUNNING)));
  assign TrapPlugin_api_harts_0_fsmBusy = (! (TrapPlugin_logic_harts_0_trap_fsm_stateReg == TrapPlugin_logic_harts_0_trap_fsm_RUNNING));
  always @(*) begin
    TrapPlugin_logic_harts_0_trap_fsm_wfi = 1'b0;
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
            end
            5'h05 : begin
            end
            5'h08 : begin
              TrapPlugin_logic_harts_0_trap_fsm_wfi = 1'b1;
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
    TrapPlugin_logic_harts_0_trap_fsm_buffer_sampleIt = 1'b0;
    case(TrapPlugin_logic_harts_0_trap_fsm_stateReg)
      TrapPlugin_logic_harts_0_trap_fsm_RUNNING : begin
        if(TrapPlugin_logic_harts_0_trap_trigger_valid) begin
          TrapPlugin_logic_harts_0_trap_fsm_buffer_sampleIt = 1'b1;
        end
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
      end
      default : begin
      end
    endcase
  end

