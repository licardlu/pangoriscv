  assign PcPlugin_logic_harts_0_aggregator_valids_3 = ((early0_BranchPlugin_logic_pcPort_valid && 1'b1) && PcPlugin_logic_harts_0_aggregator_sortedByPriority_3_laneValid);
  assign PcPlugin_logic_harts_0_aggregator_valids_4 = ((early1_BranchPlugin_logic_pcPort_valid && 1'b1) && PcPlugin_logic_harts_0_aggregator_sortedByPriority_4_laneValid);
  assign PcPlugin_logic_harts_0_aggregator_valids_5 = ((BtbPlugin_logic_pcPort_valid && 1'b1) && PcPlugin_logic_harts_0_aggregator_sortedByPriority_5_laneValid);
  assign PcPlugin_logic_harts_0_aggregator_valids_6 = ((PcPlugin_logic_harts_0_self_flow_valid && 1'b1) && PcPlugin_logic_harts_0_aggregator_sortedByPriority_6_laneValid);
  assign _zz_PcPlugin_logic_harts_0_aggregator_oh = {PcPlugin_logic_harts_0_aggregator_valids_6,PcPlugin_logic_harts_0_aggregator_valids_5,PcPlugin_logic_harts_0_aggregator_valids_4,PcPlugin_logic_harts_0_aggregator_valids_3,PcPlugin_logic_harts_0_aggregator_valids_2,PcPlugin_logic_harts_0_aggregator_valids_1,PcPlugin_logic_harts_0_aggregator_valids_0};
  assign _zz_PcPlugin_logic_harts_0_aggregator_oh_1 = _zz_PcPlugin_logic_harts_0_aggregator_oh[0];
  assign _zz_PcPlugin_logic_harts_0_aggregator_oh_2 = _zz_PcPlugin_logic_harts_0_aggregator_oh[1];
  assign _zz_PcPlugin_logic_harts_0_aggregator_oh_3 = _zz_PcPlugin_logic_harts_0_aggregator_oh[2];
  assign _zz_PcPlugin_logic_harts_0_aggregator_oh_4 = _zz_PcPlugin_logic_harts_0_aggregator_oh[3];
  assign _zz_PcPlugin_logic_harts_0_aggregator_oh_5 = _zz_PcPlugin_logic_harts_0_aggregator_oh[4];
  assign _zz_PcPlugin_logic_harts_0_aggregator_oh_6 = _zz_PcPlugin_logic_harts_0_aggregator_oh[5];
  always @(*) begin
    _zz_PcPlugin_logic_harts_0_aggregator_oh_7[0] = (_zz_PcPlugin_logic_harts_0_aggregator_oh_1 && (! 1'b0));
    _zz_PcPlugin_logic_harts_0_aggregator_oh_7[1] = (_zz_PcPlugin_logic_harts_0_aggregator_oh_2 && (! _zz_PcPlugin_logic_harts_0_aggregator_oh_1));
    _zz_PcPlugin_logic_harts_0_aggregator_oh_7[2] = (_zz_PcPlugin_logic_harts_0_aggregator_oh_3 && (! (|{_zz_PcPlugin_logic_harts_0_aggregator_oh_2,_zz_PcPlugin_logic_harts_0_aggregator_oh_1})));
    _zz_PcPlugin_logic_harts_0_aggregator_oh_7[3] = (_zz_PcPlugin_logic_harts_0_aggregator_oh_4 && (! (|{_zz_PcPlugin_logic_harts_0_aggregator_oh_3,_zz_PcPlugin_logic_harts_0_aggregator_oh_2,_zz_PcPlugin_logic_harts_0_aggregator_oh_1})));
    _zz_PcPlugin_logic_harts_0_aggregator_oh_7[4] = (_zz_PcPlugin_logic_harts_0_aggregator_oh_5 && (! _zz_PcPlugin_logic_harts_0_aggregator_oh_8));
    _zz_PcPlugin_logic_harts_0_aggregator_oh_7[5] = (_zz_PcPlugin_logic_harts_0_aggregator_oh_6 && (! (_zz_PcPlugin_logic_harts_0_aggregator_oh_5 || _zz_PcPlugin_logic_harts_0_aggregator_oh_8)));
    _zz_PcPlugin_logic_harts_0_aggregator_oh_7[6] = (_zz_PcPlugin_logic_harts_0_aggregator_oh[6] && (! ((|{_zz_PcPlugin_logic_harts_0_aggregator_oh_6,_zz_PcPlugin_logic_harts_0_aggregator_oh_5}) || _zz_PcPlugin_logic_harts_0_aggregator_oh_8)));
  end

  assign _zz_PcPlugin_logic_harts_0_aggregator_oh_8 = (|{_zz_PcPlugin_logic_harts_0_aggregator_oh_4,_zz_PcPlugin_logic_harts_0_aggregator_oh_3,_zz_PcPlugin_logic_harts_0_aggregator_oh_2,_zz_PcPlugin_logic_harts_0_aggregator_oh_1});
  assign PcPlugin_logic_harts_0_aggregator_oh = _zz_PcPlugin_logic_harts_0_aggregator_oh_7;
  assign _zz_PcPlugin_logic_harts_0_aggregator_target = PcPlugin_logic_harts_0_aggregator_oh[0];
  assign _zz_PcPlugin_logic_harts_0_aggregator_target_1 = PcPlugin_logic_harts_0_aggregator_oh[1];
  assign _zz_PcPlugin_logic_harts_0_aggregator_target_2 = PcPlugin_logic_harts_0_aggregator_oh[2];
  assign _zz_PcPlugin_logic_harts_0_aggregator_target_3 = PcPlugin_logic_harts_0_aggregator_oh[3];
  assign _zz_PcPlugin_logic_harts_0_aggregator_target_4 = PcPlugin_logic_harts_0_aggregator_oh[4];
  assign _zz_PcPlugin_logic_harts_0_aggregator_target_5 = PcPlugin_logic_harts_0_aggregator_oh[6];
  assign PcPlugin_logic_harts_0_aggregator_target = ((((_zz_PcPlugin_logic_harts_0_aggregator_target ? _zz_PcPlugin_logic_harts_0_aggregator_target_6 : _zz_PcPlugin_logic_harts_0_aggregator_target_7) | (_zz_PcPlugin_logic_harts_0_aggregator_target_1 ? _zz_PcPlugin_logic_harts_0_aggregator_target_8 : _zz_PcPlugin_logic_harts_0_aggregator_target_9)) | ((_zz_PcPlugin_logic_harts_0_aggregator_target_2 ? _zz_PcPlugin_logic_harts_0_aggregator_target_10 : _zz_PcPlugin_logic_harts_0_aggregator_target_11) | (_zz_PcPlugin_logic_harts_0_aggregator_target_3 ? _zz_PcPlugin_logic_harts_0_aggregator_target_12 : _zz_PcPlugin_logic_harts_0_aggregator_target_13))) | ((_zz_PcPlugin_logic_harts_0_aggregator_target_4 ? early1_BranchPlugin_logic_pcPort_payload_pc : 32'h0) | (_zz_PcPlugin_logic_harts_0_aggregator_target_5 ? PcPlugin_logic_harts_0_self_flow_payload_pc : 32'h0)));
  assign PcPlugin_logic_harts_0_aggregator_fault = _zz_PcPlugin_logic_harts_0_aggregator_fault[0];
  assign _zz_PcPlugin_logic_harts_0_aggregator_fault_1 = PcPlugin_logic_harts_0_aggregator_oh[5];
  assign when_PcPlugin_l80 = (|_zz_PcPlugin_logic_harts_0_aggregator_fault_1);
  assign PcPlugin_logic_harts_0_holdComb = (|TrapPlugin_logic_harts_0_trap_fsm_holdPort);
  assign PcPlugin_logic_harts_0_output_valid = (! PcPlugin_logic_harts_0_holdReg);
  assign PcPlugin_logic_harts_0_output_payload_fault = PcPlugin_logic_harts_0_aggregator_fault_1;
  always @(*) begin
    PcPlugin_logic_harts_0_output_payload_pc = PcPlugin_logic_harts_0_aggregator_target_1;
    PcPlugin_logic_harts_0_output_payload_pc[0 : 0] = 1'b0;
  end

  assign PcPlugin_logic_harts_0_output_fire = (PcPlugin_logic_harts_0_output_valid && PcPlugin_logic_harts_0_output_ready);
  assign fetch_logic_ctrls_0_up_valid = PcPlugin_logic_harts_0_output_valid;
  assign PcPlugin_logic_harts_0_output_ready = fetch_logic_ctrls_0_up_ready;
  assign fetch_logic_ctrls_0_up_Fetch_WORD_PC = PcPlugin_logic_harts_0_output_payload_pc;
  assign fetch_logic_ctrls_0_up_Fetch_PC_FAULT = PcPlugin_logic_harts_0_output_payload_fault;
  always @(*) begin
    fetch_logic_ctrls_0_up_Fetch_ID = 10'bxxxxxxxxxx;
    fetch_logic_ctrls_0_up_Fetch_ID = PcPlugin_logic_harts_0_self_id;
  end

  assign PcPlugin_logic_holdHalter_doIt = PcPlugin_logic_harts_0_holdComb;
  assign fetch_logic_ctrls_0_haltRequest_PcPlugin_l133 = PcPlugin_logic_holdHalter_doIt;
  assign CsrAccessPlugin_logic_fsm_wantExit = 1'b0;
  always @(*) begin
    CsrAccessPlugin_logic_fsm_wantStart = 1'b0;
    case(CsrAccessPlugin_logic_fsm_stateReg)
      CsrAccessPlugin_logic_fsm_READ : begin
      end
      CsrAccessPlugin_logic_fsm_WRITE : begin
      end
      CsrAccessPlugin_logic_fsm_COMPLETION : begin
      end
      default : begin
        CsrAccessPlugin_logic_fsm_wantStart = 1'b1;
      end
    endcase
  end

  assign CsrAccessPlugin_logic_fsm_wantKill = 1'b0;
  always @(*) begin
    CsrAccessPlugin_logic_fsm_interface_fire = 1'b0;
    case(CsrAccessPlugin_logic_fsm_stateReg)
      CsrAccessPlugin_logic_fsm_READ : begin
      end
      CsrAccessPlugin_logic_fsm_WRITE : begin
      end
      CsrAccessPlugin_logic_fsm_COMPLETION : begin
        if(execute_ctrl2_down_isReady) begin
          CsrAccessPlugin_logic_fsm_interface_fire = 1'b1;
        end
      end
      default : begin
      end
    endcase
  end

  assign CsrAccessPlugin_logic_fsm_inject_csrAddress = execute_ctrl2_down_Decode_UOP_lane0[31 : 20];
  assign CsrAccessPlugin_logic_fsm_inject_csrPriv = _zz_CsrAccessPlugin_logic_fsm_inject_csrPriv[9 : 8];
  assign CsrAccessPlugin_logic_fsm_inject_immZero = (execute_ctrl2_down_Decode_UOP_lane0[19 : 15] == 5'h0);
  assign CsrAccessPlugin_logic_fsm_inject_srcZero = (execute_ctrl2_down_CsrAccessPlugin_CSR_IMM_lane0 ? CsrAccessPlugin_logic_fsm_inject_immZero : (execute_ctrl2_down_Decode_UOP_lane0[19 : 15] == 5'h0));
  assign CsrAccessPlugin_logic_fsm_inject_csrWrite = (! (execute_ctrl2_down_CsrAccessPlugin_CSR_MASK_lane0 && CsrAccessPlugin_logic_fsm_inject_srcZero));
  assign CsrAccessPlugin_logic_fsm_inject_csrRead = (! ((! execute_ctrl2_down_CsrAccessPlugin_CSR_MASK_lane0) && (! execute_ctrl2_up_RD_ENABLE_lane0)));
  assign COMB_CSR_2047 = (CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h7ff);
  assign COMB_CSR_3857 = (CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hf11);
  assign COMB_CSR_3858 = (CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hf12);
  assign COMB_CSR_3859 = (CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hf13);
  assign COMB_CSR_3860 = (CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hf14);
  assign COMB_CSR_769 = (CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h301);
  assign COMB_CSR_768 = (CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h300);
  assign COMB_CSR_834 = (CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h342);
  assign COMB_CSR_836 = (CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h344);
  assign COMB_CSR_772 = (CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h304);
  assign COMB_CSR_UNAMED_2 = (|{(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h310),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h312),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h313)});
  assign COMB_CSR_4016 = (CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hfb0);
  assign COMB_CSR_794 = (CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h31a);
  assign COMB_CSR_778 = (CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h30a);
  assign COMB_CSR_774 = (CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h306);
  assign COMB_CSR_3073 = (CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc01);
  assign COMB_CSR_3201 = (CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc81);
  assign COMB_CSR_PrivilegedPlugin_logic_readAnyWriteLegal_tvecFilter = (|(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h305));
  assign COMB_CSR_PrivilegedPlugin_logic_readAnyWriteLegal_epcFilter = (|(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h341));
  assign COMB_CSR_800 = (CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h320);
  assign COMB_CSR_UNAMED_3 = (|{(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h73f),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc9f),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb9f),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h33f),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3),_zz_COMB_CSR_UNAMED_3_1,_zz_COMB_CSR_UNAMED_3_2,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc9e),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb9e),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h33e),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc1e),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb1e),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3_4),_zz_COMB_CSR_UNAMED_3_5,_zz_COMB_CSR_UNAMED_3_6,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h33d),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc1d),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb1d),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h73c),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc9c),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3_8),_zz_COMB_CSR_UNAMED_3_9,_zz_COMB_CSR_UNAMED_3_10,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb1c),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h73b),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc9b),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb9b),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h33b),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3_12),_zz_COMB_CSR_UNAMED_3_13,_zz_COMB_CSR_UNAMED_3_14,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc9a),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb9a),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h33a),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc1a),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb1a),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3_16),_zz_COMB_CSR_UNAMED_3_17,_zz_COMB_CSR_UNAMED_3_18,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h339),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc19),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb19),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h738),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc98),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3_20),_zz_COMB_CSR_UNAMED_3_21,_zz_COMB_CSR_UNAMED_3_22,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb18),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h737),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc97),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb97),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h337),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3_24),_zz_COMB_CSR_UNAMED_3_25,_zz_COMB_CSR_UNAMED_3_26,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc96),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb96),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h336),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc16),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb16),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3_28),_zz_COMB_CSR_UNAMED_3_29,_zz_COMB_CSR_UNAMED_3_30,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h335),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc15),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb15),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h734),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc94),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3_32),_zz_COMB_CSR_UNAMED_3_33,_zz_COMB_CSR_UNAMED_3_34,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb14),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h733),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc93),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb93),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h333),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3_36),_zz_COMB_CSR_UNAMED_3_37,_zz_COMB_CSR_UNAMED_3_38,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc92),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb92),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h332),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc12),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb12),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3_40),_zz_COMB_CSR_UNAMED_3_41,_zz_COMB_CSR_UNAMED_3_42,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h331),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc11),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb11),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h730),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc90),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3_44),_zz_COMB_CSR_UNAMED_3_45,_zz_COMB_CSR_UNAMED_3_46,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb10),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h72f),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc8f),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb8f),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h32f),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3_48),_zz_COMB_CSR_UNAMED_3_49,_zz_COMB_CSR_UNAMED_3_50,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc8e),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb8e),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h32e),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc0e),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb0e),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3_52),_zz_COMB_CSR_UNAMED_3_53,_zz_COMB_CSR_UNAMED_3_54,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h32d),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc0d),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb0d),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h72c),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc8c),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3_56),_zz_COMB_CSR_UNAMED_3_57,_zz_COMB_CSR_UNAMED_3_58,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb0c),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h72b),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc8b),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb8b),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h32b),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3_60),_zz_COMB_CSR_UNAMED_3_61,_zz_COMB_CSR_UNAMED_3_62,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc8a),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb8a),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h32a),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc0a),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb0a),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3_64),_zz_COMB_CSR_UNAMED_3_65,_zz_COMB_CSR_UNAMED_3_66,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h329),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc09),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb09),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h728),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc88),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3_68),_zz_COMB_CSR_UNAMED_3_69,_zz_COMB_CSR_UNAMED_3_70,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb08),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h727),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc87),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb87),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h327),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3_72),_zz_COMB_CSR_UNAMED_3_73,_zz_COMB_CSR_UNAMED_3_74,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc86),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb86),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h326),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc06),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb06),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3_76),_zz_COMB_CSR_UNAMED_3_77,_zz_COMB_CSR_UNAMED_3_78,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h325),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc05),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb05),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h724),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc84),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_UNAMED_3_80),_zz_COMB_CSR_UNAMED_3_81,_zz_COMB_CSR_UNAMED_3_82,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb04),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h723),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc83),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb83),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h323),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc03),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb03)});
  assign COMB_CSR_CsrRamPlugin_csrMapper_selFilter = (|{(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc82),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb82),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc80),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb80),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc02),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb02),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_CsrRamPlugin_csrMapper_selFilter),_zz_COMB_CSR_CsrRamPlugin_csrMapper_selFilter_1,_zz_COMB_CSR_CsrRamPlugin_csrMapper_selFilter_2,(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h341),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h343),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h305)});
  assign COMB_CSR_PerformanceCounterPlugin_logic_csrFilter = (|{(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc82),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb82),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc80),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb80),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hc02),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'hb02),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_PerformanceCounterPlugin_logic_csrFilter),(CsrAccessPlugin_logic_fsm_inject_csrAddress == _zz_COMB_CSR_PerformanceCounterPlugin_logic_csrFilter_1)});
  assign COMB_CSR_CsrAccessPlugin_logic_trapNextOnWriteFilter = (|{(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h304),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h344),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h310),(CsrAccessPlugin_logic_fsm_inject_csrAddress == 12'h300)});
  assign CsrAccessPlugin_logic_fsm_inject_implemented = (|{COMB_CSR_CsrAccessPlugin_logic_trapNextOnWriteFilter,COMB_CSR_PerformanceCounterPlugin_logic_csrFilter,COMB_CSR_CsrRamPlugin_csrMapper_selFilter,COMB_CSR_UNAMED_3,COMB_CSR_800,COMB_CSR_PrivilegedPlugin_logic_readAnyWriteLegal_epcFilter,COMB_CSR_PrivilegedPlugin_logic_readAnyWriteLegal_tvecFilter,COMB_CSR_3201,COMB_CSR_3073,COMB_CSR_774,_zz_CsrAccessPlugin_logic_fsm_inject_implemented,COMB_CSR_794,COMB_CSR_4016,COMB_CSR_UNAMED_2,COMB_CSR_772,COMB_CSR_836,COMB_CSR_834,COMB_CSR_768,COMB_CSR_769,COMB_CSR_3860,COMB_CSR_3859,_zz_CsrAccessPlugin_logic_fsm_inject_implemented_2,COMB_CSR_3857,COMB_CSR_2047});
  assign CsrAccessPlugin_logic_fsm_inject_condImplemented = 1'b0;
  assign CsrAccessPlugin_logic_fsm_inject_onDecodeDo = ((execute_ctrl2_up_LANE_SEL_lane0 && execute_ctrl2_down_CsrAccessPlugin_SEL_lane0) && (CsrAccessPlugin_logic_fsm_stateReg == CsrAccessPlugin_logic_fsm_IDLE));
  assign when_CsrAccessPlugin_l174 = (CsrAccessPlugin_logic_fsm_inject_onDecodeDo && COMB_CSR_UNAMED_2);
  assign when_CsrService_l223 = (_zz_when_CsrService_l223_1 || _zz_when_CsrService_l223);
  assign when_CsrService_l224 = (! 1'b1);
  assign when_CsrAccessPlugin_l174_1 = (CsrAccessPlugin_logic_fsm_inject_onDecodeDo && COMB_CSR_794);
  assign when_CsrService_l223_1 = (_zz_when_CsrService_l223_1 || _zz_when_CsrService_l223);
  assign when_CsrService_l224_1 = (! 1'b1);
  assign when_CsrAccessPlugin_l174_2 = (CsrAccessPlugin_logic_fsm_inject_onDecodeDo && COMB_CSR_778);
  assign when_CsrService_l223_2 = (_zz_when_CsrService_l223_1 || _zz_when_CsrService_l223);
  assign when_CsrService_l224_2 = (! 1'b1);
  assign when_CsrAccessPlugin_l174_3 = (CsrAccessPlugin_logic_fsm_inject_onDecodeDo && COMB_CSR_3073);
  assign when_CsrService_l231 = (_zz_when_CsrService_l223_1 || _zz_when_CsrService_l223);
  assign when_CsrService_l232 = (! (PrivilegedPlugin_logic_harts_0_withMachinePrivilege || PrivilegedPlugin_logic_harts_0_m_counteren_tm));
  assign when_CsrAccessPlugin_l174_4 = (CsrAccessPlugin_logic_fsm_inject_onDecodeDo && COMB_CSR_3201);
  assign when_CsrService_l231_1 = (_zz_when_CsrService_l223_1 || _zz_when_CsrService_l223);
  assign when_CsrService_l232_1 = (! (PrivilegedPlugin_logic_harts_0_withMachinePrivilege || PrivilegedPlugin_logic_harts_0_m_counteren_tm));
  assign when_CsrAccessPlugin_l174_5 = (CsrAccessPlugin_logic_fsm_inject_onDecodeDo && COMB_CSR_UNAMED_3);
  assign when_CsrService_l137 = (! 1'b1);
  assign when_CsrAccessPlugin_l174_6 = (CsrAccessPlugin_logic_fsm_inject_onDecodeDo && COMB_CSR_CsrRamPlugin_csrMapper_selFilter);
  assign when_CsrService_l137_1 = (! 1'b1);
  assign when_CsrAccessPlugin_l174_7 = (CsrAccessPlugin_logic_fsm_inject_onDecodeDo && COMB_CSR_PerformanceCounterPlugin_logic_csrFilter);
  assign when_PerformanceCounterPlugin_l396 = (CsrAccessPlugin_bus_decode_address[9 : 8] == 2'b00);
  assign when_PerformanceCounterPlugin_l400 = (! PerformanceCounterPlugin_logic_csrDecode_privOk);
  assign when_PerformanceCounterPlugin_l402 = (! PerformanceCounterPlugin_logic_csrDecode_mok);
  assign when_CsrAccessPlugin_l174_8 = (CsrAccessPlugin_logic_fsm_inject_onDecodeDo && COMB_CSR_CsrAccessPlugin_logic_trapNextOnWriteFilter);
  assign CsrAccessPlugin_logic_fsm_inject_trap = (((! CsrAccessPlugin_logic_fsm_inject_implemented) || CsrAccessPlugin_bus_decode_exception) || CsrAccessPlugin_bus_decode_hostDenied);
  assign CsrAccessPlugin_bus_decode_read = CsrAccessPlugin_logic_fsm_inject_csrRead;
  assign CsrAccessPlugin_bus_decode_write = CsrAccessPlugin_logic_fsm_inject_csrWrite;
  assign CsrAccessPlugin_bus_decode_address = CsrAccessPlugin_logic_fsm_inject_csrAddress;
  assign CsrAccessPlugin_bus_decode_privilege = CsrAccessPlugin_logic_fsm_inject_csrPriv;
  assign CsrAccessPlugin_logic_fsm_interface_uopId = execute_ctrl2_down_Decode_UOP_ID_lane0;
  assign CsrAccessPlugin_logic_fsm_interface_rs1 = execute_ctrl2_up_integer_RS1_lane0;
  assign CsrAccessPlugin_logic_fsm_interface_uop = execute_ctrl2_down_Decode_UOP_lane0;
  assign CsrAccessPlugin_logic_fsm_interface_doImm = execute_ctrl2_down_CsrAccessPlugin_CSR_IMM_lane0;
  assign CsrAccessPlugin_logic_fsm_interface_doMask = execute_ctrl2_down_CsrAccessPlugin_CSR_MASK_lane0;
  assign CsrAccessPlugin_logic_fsm_interface_doClear = execute_ctrl2_down_CsrAccessPlugin_CSR_CLEAR_lane0;
  assign CsrAccessPlugin_logic_fsm_interface_rdEnable = execute_ctrl2_up_RD_ENABLE_lane0;
  assign CsrAccessPlugin_logic_fsm_interface_rdPhys = execute_ctrl2_down_RD_PHYS_lane0;
  assign CsrAccessPlugin_logic_fsm_inject_freeze = ((execute_ctrl2_up_LANE_SEL_lane0 && execute_ctrl2_down_CsrAccessPlugin_SEL_lane0) && (! CsrAccessPlugin_logic_fsm_inject_unfreeze));
  always @(*) begin
    CsrAccessPlugin_logic_flushPort_valid = 1'b0;
    if(CsrAccessPlugin_logic_fsm_inject_flushReg) begin
      CsrAccessPlugin_logic_flushPort_valid = 1'b1;
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
              CsrAccessPlugin_logic_flushPort_valid = 1'b1;
            end else begin
              if(CsrAccessPlugin_logic_fsm_inject_busTrapReg) begin
                CsrAccessPlugin_logic_flushPort_valid = 1'b1;
              end
            end
          end
        end
      end
    endcase
  end

  assign CsrAccessPlugin_logic_flushPort_payload_uopId = execute_ctrl2_down_Decode_UOP_ID_lane0;
  assign CsrAccessPlugin_logic_flushPort_payload_laneAge = execute_ctrl2_down_LANE_AGE_lane0;
  assign CsrAccessPlugin_logic_flushPort_payload_self = 1'b0;
  always @(*) begin
    CsrAccessPlugin_logic_trapPort_valid = 1'b0;
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
              CsrAccessPlugin_logic_trapPort_valid = 1'b1;
            end else begin
              if(CsrAccessPlugin_logic_fsm_inject_busTrapReg) begin
                CsrAccessPlugin_logic_trapPort_valid = 1'b1;
              end
            end
          end
        end
      end
    endcase
  end

  always @(*) begin
    CsrAccessPlugin_logic_trapPort_payload_exception = 1'b1;
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
            if(!CsrAccessPlugin_logic_fsm_inject_trapReg) begin
              if(CsrAccessPlugin_logic_fsm_inject_busTrapReg) begin
                CsrAccessPlugin_logic_trapPort_payload_exception = 1'b0;
              end
            end
          end
        end
      end
    endcase
  end

  always @(*) begin
    CsrAccessPlugin_logic_trapPort_payload_code = 5'h02;
    if(when_CsrAccessPlugin_l218) begin
      CsrAccessPlugin_logic_trapPort_payload_code = 5'h16;
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
            if(!CsrAccessPlugin_logic_fsm_inject_trapReg) begin
              if(CsrAccessPlugin_logic_fsm_inject_busTrapReg) begin
                CsrAccessPlugin_logic_trapPort_payload_code = CsrAccessPlugin_logic_fsm_inject_busTrapCodeReg;
              end
            end
          end
        end
      end
    endcase
  end

  assign CsrAccessPlugin_logic_trapPort_payload_tval = execute_ctrl2_down_Decode_UOP_lane0;
  assign CsrAccessPlugin_logic_trapPort_payload_tval2 = 32'h0;
  assign CsrAccessPlugin_logic_trapPort_payload_arg = 3'b000;
  assign CsrAccessPlugin_logic_trapPort_payload_laneAge = execute_ctrl2_down_LANE_AGE_lane0;
  assign when_CsrAccessPlugin_l218 = (((CsrAccessPlugin_logic_fsm_inject_implemented || CsrAccessPlugin_logic_fsm_inject_condImplemented) && (! CsrAccessPlugin_bus_decode_hostDenied)) && CsrAccessPlugin_bus_decode_virtual);
  assign when_CsrAccessPlugin_l222 = (! execute_freeze_valid);
  always @(*) begin
    CsrAccessPlugin_logic_fsm_readLogic_onReadsDo = 1'b0;
    case(CsrAccessPlugin_logic_fsm_stateReg)
      CsrAccessPlugin_logic_fsm_READ : begin
        CsrAccessPlugin_logic_fsm_readLogic_onReadsDo = CsrAccessPlugin_logic_fsm_interface_read;
      end
      CsrAccessPlugin_logic_fsm_WRITE : begin
      end
      CsrAccessPlugin_logic_fsm_COMPLETION : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    CsrAccessPlugin_logic_fsm_readLogic_onReadsFireDo = 1'b0;
    case(CsrAccessPlugin_logic_fsm_stateReg)
      CsrAccessPlugin_logic_fsm_READ : begin
        if(when_CsrAccessPlugin_l325) begin
          CsrAccessPlugin_logic_fsm_readLogic_onReadsFireDo = CsrAccessPlugin_logic_fsm_interface_read;
        end
      end
      CsrAccessPlugin_logic_fsm_WRITE : begin
      end
      CsrAccessPlugin_logic_fsm_COMPLETION : begin
      end
      default : begin
      end
    endcase
  end

  assign CsrAccessPlugin_bus_read_valid = CsrAccessPlugin_logic_fsm_readLogic_onReadsDo;
  assign CsrAccessPlugin_bus_read_address = CsrAccessPlugin_logic_fsm_interface_csrId;
  assign CsrAccessPlugin_bus_read_moving = (! CsrAccessPlugin_bus_read_halt);
  assign when_CsrAccessPlugin_l281 = (CsrAccessPlugin_logic_fsm_readLogic_onReadsDo && REG_CSR_CsrRamPlugin_csrMapper_selFilter);
  assign CsrAccessPlugin_logic_fsm_readLogic_csrValue = (((((_zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_9 | _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_11) | (_zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_12 | _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_14)) | ((_zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_15 | _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_16) | (_zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_17 | _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_19))) | (((_zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_21 | _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_23) | (_zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_24 | _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_26)) | ((_zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_27 | _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_29) | (_zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_31 | _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_33)))) | ((((_zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_35 | _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_37) | (_zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_39 | _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_41)) | ((_zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_43 | _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_45) | (_zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_46 | _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_48))) | (((_zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_49 | _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_50) | (_zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_52 | _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_54)) | ((_zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_56 | _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_58) | (_zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_60 | _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_62)))));
  assign CsrAccessPlugin_bus_read_data = CsrAccessPlugin_logic_fsm_readLogic_csrValue;
  assign CsrAccessPlugin_bus_read_toWriteBits = CsrAccessPlugin_logic_fsm_readLogic_csrValue;
  assign _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_2 = REG_CSR_836;
  assign _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_4 = REG_CSR_772;
  assign _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_7 = REG_CSR_774;
  assign _zz_CsrAccessPlugin_logic_fsm_readLogic_csrValue_8 = REG_CSR_800;
  assign _zz_when_CsrService_l223 = 1'b1;
  assign CsrAccessPlugin_bus_write_moving = (! CsrAccessPlugin_bus_write_halt);
  assign CsrAccessPlugin_logic_fsm_writeLogic_alu_mask = (CsrAccessPlugin_logic_fsm_interface_doImm ? _zz_CsrAccessPlugin_logic_fsm_writeLogic_alu_mask : CsrAccessPlugin_logic_fsm_interface_rs1);
  assign CsrAccessPlugin_logic_fsm_writeLogic_alu_masked = (CsrAccessPlugin_logic_fsm_interface_doClear ? (CsrAccessPlugin_logic_fsm_interface_aluInput & (~ CsrAccessPlugin_logic_fsm_writeLogic_alu_mask)) : (CsrAccessPlugin_logic_fsm_interface_aluInput | CsrAccessPlugin_logic_fsm_writeLogic_alu_mask));
  assign CsrAccessPlugin_logic_fsm_writeLogic_alu_result = (CsrAccessPlugin_logic_fsm_interface_doMask ? CsrAccessPlugin_logic_fsm_writeLogic_alu_masked : CsrAccessPlugin_logic_fsm_writeLogic_alu_mask);
  always @(*) begin
    CsrAccessPlugin_bus_write_bits = CsrAccessPlugin_logic_fsm_writeLogic_alu_result;
    if(when_CsrAccessPlugin_l375) begin
      CsrAccessPlugin_bus_write_bits[1 : 0] = 2'b00;
    end
    if(when_CsrAccessPlugin_l375_1) begin
      CsrAccessPlugin_bus_write_bits[0 : 0] = 1'b0;
    end
  end

  assign CsrAccessPlugin_bus_write_maskBit = CsrAccessPlugin_logic_fsm_writeLogic_alu_mask;
  assign CsrAccessPlugin_bus_write_clear = CsrAccessPlugin_logic_fsm_interface_doClear;
  assign CsrAccessPlugin_bus_write_mask = CsrAccessPlugin_logic_fsm_interface_doMask;
  assign CsrAccessPlugin_bus_write_address = CsrAccessPlugin_logic_fsm_interface_csrId;
  always @(*) begin
    CsrAccessPlugin_logic_fsm_writeLogic_onWritesDo = 1'b0;
    case(CsrAccessPlugin_logic_fsm_stateReg)
      CsrAccessPlugin_logic_fsm_READ : begin
      end
      CsrAccessPlugin_logic_fsm_WRITE : begin
        CsrAccessPlugin_logic_fsm_writeLogic_onWritesDo = CsrAccessPlugin_logic_fsm_interface_write;
      end
      CsrAccessPlugin_logic_fsm_COMPLETION : begin
      end
      default : begin
      end
    endcase
  end

  always @(*) begin
    CsrAccessPlugin_logic_fsm_writeLogic_onWritesFireDo = 1'b0;
    case(CsrAccessPlugin_logic_fsm_stateReg)
      CsrAccessPlugin_logic_fsm_READ : begin
      end
      CsrAccessPlugin_logic_fsm_WRITE : begin
        if(when_CsrAccessPlugin_l357) begin
          CsrAccessPlugin_logic_fsm_writeLogic_onWritesFireDo = CsrAccessPlugin_logic_fsm_interface_write;
        end
      end
      CsrAccessPlugin_logic_fsm_COMPLETION : begin
      end
      default : begin
      end
    endcase
  end

  assign CsrAccessPlugin_bus_write_valid = CsrAccessPlugin_logic_fsm_writeLogic_onWritesDo;
  assign _zz_when_CsrService_l223_1 = 1'b1;
  assign when_CsrAccessPlugin_l378 = (CsrAccessPlugin_logic_fsm_writeLogic_onWritesFireDo && REG_CSR_2047);
  assign when_CsrAccessPlugin_l378_1 = (CsrAccessPlugin_logic_fsm_writeLogic_onWritesFireDo && REG_CSR_768);
  assign when_CsrAccessPlugin_l378_2 = (CsrAccessPlugin_logic_fsm_writeLogic_onWritesFireDo && REG_CSR_834);
  assign when_CsrAccessPlugin_l378_3 = (CsrAccessPlugin_logic_fsm_writeLogic_onWritesFireDo && REG_CSR_836);
  assign when_CsrAccessPlugin_l378_4 = (CsrAccessPlugin_logic_fsm_writeLogic_onWritesFireDo && REG_CSR_772);
  assign when_CsrAccessPlugin_l378_5 = (CsrAccessPlugin_logic_fsm_writeLogic_onWritesFireDo && REG_CSR_774);
  assign when_CsrAccessPlugin_l375 = (CsrAccessPlugin_logic_fsm_writeLogic_onWritesDo && REG_CSR_PrivilegedPlugin_logic_readAnyWriteLegal_tvecFilter);
  assign when_CsrAccessPlugin_l375_1 = (CsrAccessPlugin_logic_fsm_writeLogic_onWritesDo && REG_CSR_PrivilegedPlugin_logic_readAnyWriteLegal_epcFilter);
  assign when_CsrAccessPlugin_l378_6 = (CsrAccessPlugin_logic_fsm_writeLogic_onWritesFireDo && REG_CSR_800);
  assign when_CsrAccessPlugin_l375_2 = (CsrAccessPlugin_logic_fsm_writeLogic_onWritesDo && REG_CSR_CsrRamPlugin_csrMapper_selFilter);
  assign when_CsrAccessPlugin_l375_3 = (CsrAccessPlugin_logic_fsm_writeLogic_onWritesDo && REG_CSR_PerformanceCounterPlugin_logic_csrFilter);
  assign when_PerformanceCounterPlugin_l432 = (! PerformanceCounterPlugin_logic_csrWrite_fired);
  assign when_PerformanceCounterPlugin_l434 = (! PerformanceCounterPlugin_logic_fsm_csrWriteCmd_ready);
  assign CsrAccessPlugin_logic_wbWi_valid = execute_ctrl3_down_CsrAccessPlugin_SEL_lane0;
  assign CsrAccessPlugin_logic_wbWi_payload = CsrAccessPlugin_logic_fsm_interface_csrValue;
  always @(*) begin
    HistoryPlugin_logic_onFetch_valueNext = HistoryPlugin_logic_onFetch_value;
    if(HistoryPlugin_logic_onFetch_ports_0_valid) begin
      HistoryPlugin_logic_onFetch_valueNext = HistoryPlugin_logic_onFetch_ports_0_payload_history;
    end
    if(HistoryPlugin_logic_onFetch_ports_1_valid) begin
      HistoryPlugin_logic_onFetch_valueNext = HistoryPlugin_logic_onFetch_ports_1_payload_history;
    end
    if(HistoryPlugin_logic_onFetch_ports_2_valid) begin
      HistoryPlugin_logic_onFetch_valueNext = HistoryPlugin_logic_onFetch_ports_2_payload_history;
    end
    if(HistoryPlugin_logic_onFetch_ports_3_valid) begin
      HistoryPlugin_logic_onFetch_valueNext = HistoryPlugin_logic_onFetch_ports_3_payload_history;
    end
  end

  assign HistoryPlugin_logic_onFetch_ports_0_valid = (|BtbPlugin_logic_historyPort_valid);
  assign HistoryPlugin_logic_onFetch_ports_0_payload_history = BtbPlugin_logic_historyPort_payload_history;
  assign HistoryPlugin_logic_onFetch_ports_1_valid = (|{early1_BranchPlugin_logic_historyPort_valid,early0_BranchPlugin_logic_historyPort_valid});
  assign _zz_HistoryPlugin_logic_onFetch_ports_1_payload_history = (((early0_BranchPlugin_logic_historyPort_valid && (&(! (early1_BranchPlugin_logic_historyPort_valid && (early1_BranchPlugin_logic_historyPort_payload_age < early0_BranchPlugin_logic_historyPort_payload_age))))) ? {early0_BranchPlugin_logic_historyPort_payload_age,early0_BranchPlugin_logic_historyPort_payload_history} : 13'h0) | ((early1_BranchPlugin_logic_historyPort_valid && (&(! (early0_BranchPlugin_logic_historyPort_valid && (early0_BranchPlugin_logic_historyPort_payload_age < early1_BranchPlugin_logic_historyPort_payload_age))))) ? {early1_BranchPlugin_logic_historyPort_payload_age,early1_BranchPlugin_logic_historyPort_payload_history} : 13'h0));
  assign HistoryPlugin_logic_onFetch_ports_1_payload_history = _zz_HistoryPlugin_logic_onFetch_ports_1_payload_history[11 : 0];
  assign HistoryPlugin_logic_onFetch_ports_1_payload_age = _zz_HistoryPlugin_logic_onFetch_ports_1_payload_history[12 : 12];
  assign HistoryPlugin_logic_onFetch_ports_2_valid = (|{late1_BranchPlugin_logic_historyPort_valid,late0_BranchPlugin_logic_historyPort_valid});
  assign _zz_HistoryPlugin_logic_onFetch_ports_2_payload_history = (((late0_BranchPlugin_logic_historyPort_valid && (&(! (late1_BranchPlugin_logic_historyPort_valid && (late1_BranchPlugin_logic_historyPort_payload_age < late0_BranchPlugin_logic_historyPort_payload_age))))) ? {late0_BranchPlugin_logic_historyPort_payload_age,late0_BranchPlugin_logic_historyPort_payload_history} : 13'h0) | ((late1_BranchPlugin_logic_historyPort_valid && (&(! (late0_BranchPlugin_logic_historyPort_valid && (late0_BranchPlugin_logic_historyPort_payload_age < late1_BranchPlugin_logic_historyPort_payload_age))))) ? {late1_BranchPlugin_logic_historyPort_payload_age,late1_BranchPlugin_logic_historyPort_payload_history} : 13'h0));
  assign HistoryPlugin_logic_onFetch_ports_2_payload_history = _zz_HistoryPlugin_logic_onFetch_ports_2_payload_history[11 : 0];
  assign HistoryPlugin_logic_onFetch_ports_2_payload_age = _zz_HistoryPlugin_logic_onFetch_ports_2_payload_history[12 : 12];
  assign HistoryPlugin_logic_onFetch_ports_3_valid = (|TrapPlugin_logic_harts_0_trap_historyPort_valid);
  assign HistoryPlugin_logic_onFetch_ports_3_payload_history = TrapPlugin_logic_harts_0_trap_historyPort_payload_history;
  assign fetch_logic_ctrls_0_down_Prediction_BRANCH_HISTORY = HistoryPlugin_logic_onFetch_valueNext;
  assign when_LsuPlugin_l307 = (|(LsuPlugin_logic_storeBuffer_waitL1_refill & (~ LsuL1_REFILL_BUSY)));
  assign LsuPlugin_logic_storeBuffer_empty = (&{(! LsuPlugin_logic_storeBuffer_slots_3_valid),(! LsuPlugin_logic_storeBuffer_slots_2_valid),(! LsuPlugin_logic_storeBuffer_slots_1_valid),(! LsuPlugin_logic_storeBuffer_slots_0_valid)});
  assign LsuPlugin_logic_flusher_wantExit = 1'b0;
  always @(*) begin
    LsuPlugin_logic_flusher_wantStart = 1'b0;
    case(LsuPlugin_logic_flusher_stateReg)
      LsuPlugin_logic_flusher_SB_DRAIN : begin
      end
      LsuPlugin_logic_flusher_CMD : begin
      end
      LsuPlugin_logic_flusher_COMPLETION : begin
      end
      default : begin
        LsuPlugin_logic_flusher_wantStart = 1'b1;
      end
    endcase
  end

