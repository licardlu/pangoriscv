  assign BtbPlugin_logic_memDp_rp_rsp_1_isBranch = _zz_BtbPlugin_logic_memDp_rp_rsp_1_hash[48];
  assign BtbPlugin_logic_memDp_rp_rsp_1_isPush = _zz_BtbPlugin_logic_memDp_rp_rsp_1_hash[49];
  assign BtbPlugin_logic_memDp_rp_rsp_1_isPop = _zz_BtbPlugin_logic_memDp_rp_rsp_1_hash[50];
  assign BtbPlugin_logic_memDp_rp_cmd_valid = BtbPlugin_logic_memRead_cmd_valid;
  assign BtbPlugin_logic_memDp_rp_cmd_payload = BtbPlugin_logic_memRead_cmd_payload;
  assign BtbPlugin_logic_memRead_rsp_0_hash = BtbPlugin_logic_memDp_rp_rsp_0_hash;
  assign BtbPlugin_logic_memRead_rsp_0_sliceLow = BtbPlugin_logic_memDp_rp_rsp_0_sliceLow;
  assign BtbPlugin_logic_memRead_rsp_0_pcTarget = BtbPlugin_logic_memDp_rp_rsp_0_pcTarget;
  assign BtbPlugin_logic_memRead_rsp_0_isBranch = BtbPlugin_logic_memDp_rp_rsp_0_isBranch;
  assign BtbPlugin_logic_memRead_rsp_0_isPush = BtbPlugin_logic_memDp_rp_rsp_0_isPush;
  assign BtbPlugin_logic_memRead_rsp_0_isPop = BtbPlugin_logic_memDp_rp_rsp_0_isPop;
  assign BtbPlugin_logic_memRead_rsp_1_hash = BtbPlugin_logic_memDp_rp_rsp_1_hash;
  assign BtbPlugin_logic_memRead_rsp_1_sliceLow = BtbPlugin_logic_memDp_rp_rsp_1_sliceLow;
  assign BtbPlugin_logic_memRead_rsp_1_pcTarget = BtbPlugin_logic_memDp_rp_rsp_1_pcTarget;
  assign BtbPlugin_logic_memRead_rsp_1_isBranch = BtbPlugin_logic_memDp_rp_rsp_1_isBranch;
  assign BtbPlugin_logic_memRead_rsp_1_isPush = BtbPlugin_logic_memDp_rp_rsp_1_isPush;
  assign BtbPlugin_logic_memRead_rsp_1_isPop = BtbPlugin_logic_memDp_rp_rsp_1_isPop;
  always @(*) begin
    early0_EnvPlugin_logic_flushPort_valid = 1'b0;
    if(when_EnvPlugin_l214) begin
      early0_EnvPlugin_logic_flushPort_valid = 1'b1;
    end
  end

  assign early0_EnvPlugin_logic_flushPort_payload_uopId = execute_ctrl2_down_Decode_UOP_ID_lane0;
  assign early0_EnvPlugin_logic_flushPort_payload_laneAge = execute_ctrl2_down_LANE_AGE_lane0;
  assign early0_EnvPlugin_logic_flushPort_payload_self = 1'b0;
  always @(*) begin
    early0_EnvPlugin_logic_trapPort_valid = 1'b0;
    if(when_EnvPlugin_l214) begin
      early0_EnvPlugin_logic_trapPort_valid = 1'b1;
    end
  end

  always @(*) begin
    early0_EnvPlugin_logic_trapPort_payload_exception = 1'b1;
    case(execute_ctrl2_down_early0_EnvPlugin_OP_lane0)
      EnvPluginOp_PRIV_RET : begin
        if(when_EnvPlugin_l132) begin
          early0_EnvPlugin_logic_trapPort_payload_exception = 1'b0;
        end
      end
      EnvPluginOp_WFI : begin
        if(when_EnvPlugin_l146) begin
          early0_EnvPlugin_logic_trapPort_payload_exception = 1'b0;
        end
      end
      EnvPluginOp_FENCE_I : begin
        early0_EnvPlugin_logic_trapPort_payload_exception = 1'b0;
      end
      default : begin
      end
    endcase
  end

  assign PrivilegedPlugin_logic_defaultTrap_csrPrivilege = CsrAccessPlugin_bus_decode_privilege;
  assign PrivilegedPlugin_logic_defaultTrap_csrReadOnly = (CsrAccessPlugin_bus_decode_address[11 : 10] == 2'b11);
  assign PrivilegedPlugin_logic_defaultTrap_hartPrivilege = PrivilegedPlugin_logic_harts_0_privilege;
  assign PrivilegedPlugin_logic_defaultTrap_adjustPrivilege = _zz_PrivilegedPlugin_logic_defaultTrap_adjustPrivilege;
  assign when_PrivilegedPlugin_l1341 = (PrivilegedPlugin_logic_defaultTrap_adjustPrivilege < PrivilegedPlugin_logic_defaultTrap_csrPrivilege);
  assign when_PrivilegedPlugin_l1345 = (PrivilegedPlugin_logic_defaultTrap_csrReadOnly && CsrAccessPlugin_bus_decode_write);
  assign FetchL1TileLinkPlugin_logic_down_a_valid = FetchL1Plugin_logic_bus_cmd_valid;
  assign FetchL1TileLinkPlugin_logic_down_a_payload_opcode = A_GET;
  assign FetchL1TileLinkPlugin_logic_down_a_payload_param = 3'b000;
  assign FetchL1TileLinkPlugin_logic_down_a_payload_source = FetchL1Plugin_logic_bus_cmd_payload_id;
  assign FetchL1TileLinkPlugin_logic_down_a_payload_address = FetchL1Plugin_logic_bus_cmd_payload_address;
  assign FetchL1TileLinkPlugin_logic_down_a_payload_size = 3'b110;
  assign FetchL1Plugin_logic_bus_cmd_ready = FetchL1TileLinkPlugin_logic_down_a_ready;
  assign FetchL1Plugin_logic_bus_rsp_valid = FetchL1TileLinkPlugin_logic_down_d_valid;
  assign FetchL1Plugin_logic_bus_rsp_payload_id = FetchL1TileLinkPlugin_logic_down_d_payload_source;
  assign FetchL1Plugin_logic_bus_rsp_payload_data = FetchL1TileLinkPlugin_logic_down_d_payload_data;
  assign FetchL1Plugin_logic_bus_rsp_payload_error = (FetchL1TileLinkPlugin_logic_down_d_payload_denied || FetchL1TileLinkPlugin_logic_down_d_payload_corrupt);
  assign FetchL1TileLinkPlugin_logic_down_d_ready = 1'b1;
  always @(*) begin
    DecoderPlugin_logic_forgetPort_valid = 1'b0;
    if(DecoderPlugin_logic_laneLogic_0_fixer_doIt) begin
      DecoderPlugin_logic_forgetPort_valid = 1'b1;
    end
    if(DecoderPlugin_logic_laneLogic_1_fixer_doIt) begin
      DecoderPlugin_logic_forgetPort_valid = 1'b1;
    end
  end

  always @(*) begin
    DecoderPlugin_logic_forgetPort_payload_pcOnLastSlice = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    if(DecoderPlugin_logic_laneLogic_0_fixer_doIt) begin
      DecoderPlugin_logic_forgetPort_payload_pcOnLastSlice = (decode_ctrls_1_down_PC_0 + _zz_DecoderPlugin_logic_forgetPort_payload_pcOnLastSlice);
    end
    if(DecoderPlugin_logic_laneLogic_1_fixer_doIt) begin
      DecoderPlugin_logic_forgetPort_payload_pcOnLastSlice = (decode_ctrls_1_down_PC_1 + _zz_DecoderPlugin_logic_forgetPort_payload_pcOnLastSlice_3);
    end
  end

  always @(*) begin
    _zz_execute_ctrl2_down_early0_SrcPlugin_SRC1_lane0 = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    case(execute_ctrl2_down_early0_SrcPlugin_logic_SRC1_CTRL_lane0)
      1'b0 : begin
        _zz_execute_ctrl2_down_early0_SrcPlugin_SRC1_lane0 = execute_ctrl2_up_integer_RS1_lane0;
      end
      default : begin
        _zz_execute_ctrl2_down_early0_SrcPlugin_SRC1_lane0 = {execute_ctrl2_down_Decode_UOP_lane0[31 : 12],12'h0};
      end
    endcase
  end

  assign execute_ctrl2_down_early0_SrcPlugin_SRC1_lane0 = _zz_execute_ctrl2_down_early0_SrcPlugin_SRC1_lane0;
  always @(*) begin
    _zz_execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0 = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    case(execute_ctrl2_down_early0_SrcPlugin_logic_SRC2_CTRL_lane0)
      2'b00 : begin
        _zz_execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0 = execute_ctrl2_up_integer_RS2_lane0;
      end
      2'b01 : begin
        _zz_execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0 = {{20{_zz__zz_execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0[11]}}, _zz__zz_execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0};
      end
      2'b10 : begin
        _zz_execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0 = execute_ctrl2_down_PC_lane0;
      end
      default : begin
        _zz_execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0 = {{20{_zz__zz_execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0_1[11]}}, _zz__zz_execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0_1};
      end
    endcase
  end

  assign execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0 = _zz_execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0;
  always @(*) begin
    early0_SrcPlugin_logic_addsub_combined_rs2Patched = execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0;
    if(execute_ctrl2_down_SrcStageables_REVERT_lane0) begin
      early0_SrcPlugin_logic_addsub_combined_rs2Patched = (~ execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0);
    end
    if(execute_ctrl2_down_SrcStageables_ZERO_lane0) begin
      early0_SrcPlugin_logic_addsub_combined_rs2Patched = 32'h0;
    end
  end

  assign execute_ctrl2_down_early0_SrcPlugin_ADD_SUB_lane0 = ($signed(_zz_execute_ctrl2_down_early0_SrcPlugin_ADD_SUB_lane0) + $signed(_zz_execute_ctrl2_down_early0_SrcPlugin_ADD_SUB_lane0_1));
  assign execute_ctrl2_down_early0_SrcPlugin_LESS_lane0 = ((execute_ctrl2_down_early0_SrcPlugin_SRC1_lane0[31] == execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0[31]) ? execute_ctrl2_down_early0_SrcPlugin_ADD_SUB_lane0[31] : (execute_ctrl2_down_SrcStageables_UNSIGNED_lane0 ? execute_ctrl2_down_early0_SrcPlugin_SRC2_lane0[31] : execute_ctrl2_down_early0_SrcPlugin_SRC1_lane0[31]));
  assign lane0_IntFormatPlugin_logic_stages_0_hits = {early0_BarrelShifterPlugin_logic_wb_valid,early0_IntAluPlugin_logic_wb_valid};
  assign lane0_IntFormatPlugin_logic_stages_0_wb_valid = (execute_ctrl2_up_LANE_SEL_lane0 && (|lane0_IntFormatPlugin_logic_stages_0_hits));
  assign lane0_IntFormatPlugin_logic_stages_0_raw = ((lane0_IntFormatPlugin_logic_stages_0_hits[0] ? early0_IntAluPlugin_logic_wb_payload : 32'h0) | (lane0_IntFormatPlugin_logic_stages_0_hits[1] ? early0_BarrelShifterPlugin_logic_wb_payload : 32'h0));
  assign lane0_IntFormatPlugin_logic_stages_0_wb_payload = lane0_IntFormatPlugin_logic_stages_0_raw;
  assign lane0_IntFormatPlugin_logic_stages_1_hits = {LsuPlugin_logic_iwb_valid,late0_BarrelShifterPlugin_logic_wb_valid,late0_IntAluPlugin_logic_wb_valid,early0_MulPlugin_logic_formatBus_valid};
  assign lane0_IntFormatPlugin_logic_stages_1_wb_valid = (execute_ctrl4_up_LANE_SEL_lane0 && (|lane0_IntFormatPlugin_logic_stages_1_hits));
  assign lane0_IntFormatPlugin_logic_stages_1_raw = (((lane0_IntFormatPlugin_logic_stages_1_hits[0] ? early0_MulPlugin_logic_formatBus_payload : 32'h0) | (lane0_IntFormatPlugin_logic_stages_1_hits[1] ? late0_IntAluPlugin_logic_wb_payload : 32'h0)) | ((lane0_IntFormatPlugin_logic_stages_1_hits[2] ? late0_BarrelShifterPlugin_logic_wb_payload : 32'h0) | (lane0_IntFormatPlugin_logic_stages_1_hits[3] ? LsuPlugin_logic_iwb_payload : 32'h0)));
  always @(*) begin
    lane0_IntFormatPlugin_logic_stages_1_wb_payload = lane0_IntFormatPlugin_logic_stages_1_raw;
    if(lane0_IntFormatPlugin_logic_stages_1_segments_0_doIt) begin
      lane0_IntFormatPlugin_logic_stages_1_wb_payload[15 : 8] = {8{lane0_IntFormatPlugin_logic_stages_1_segments_0_sign_value}};
    end
    if(lane0_IntFormatPlugin_logic_stages_1_segments_1_doIt) begin
      lane0_IntFormatPlugin_logic_stages_1_wb_payload[31 : 16] = {16{lane0_IntFormatPlugin_logic_stages_1_segments_1_sign_value}};
    end
  end

  assign lane0_IntFormatPlugin_logic_stages_1_segments_0_sign_sels_0 = lane0_IntFormatPlugin_logic_stages_1_raw[7];
  always @(*) begin
    _zz_lane0_IntFormatPlugin_logic_stages_1_segments_0_sign_value = 1'bx;
    case(execute_ctrl4_down_lane0_IntFormatPlugin_logic_WIDTH_ID_lane0)
      2'b00 : begin
        _zz_lane0_IntFormatPlugin_logic_stages_1_segments_0_sign_value = lane0_IntFormatPlugin_logic_stages_1_segments_0_sign_sels_0;
      end
      default : begin
      end
    endcase
  end

  assign lane0_IntFormatPlugin_logic_stages_1_segments_0_sign_value = (execute_ctrl4_down_lane0_IntFormatPlugin_logic_SIGNED_lane0 && _zz_lane0_IntFormatPlugin_logic_stages_1_segments_0_sign_value);
  assign lane0_IntFormatPlugin_logic_stages_1_segments_0_doIt = (execute_ctrl4_down_lane0_IntFormatPlugin_logic_WIDTH_ID_lane0 < 2'b01);
  assign lane0_IntFormatPlugin_logic_stages_1_segments_1_sign_sels_0 = lane0_IntFormatPlugin_logic_stages_1_raw[7];
  assign lane0_IntFormatPlugin_logic_stages_1_segments_1_sign_sels_1 = lane0_IntFormatPlugin_logic_stages_1_raw[15];
  always @(*) begin
    _zz_lane0_IntFormatPlugin_logic_stages_1_segments_1_sign_value = 1'bx;
    case(execute_ctrl4_down_lane0_IntFormatPlugin_logic_WIDTH_ID_lane0)
      2'b00 : begin
        _zz_lane0_IntFormatPlugin_logic_stages_1_segments_1_sign_value = lane0_IntFormatPlugin_logic_stages_1_segments_1_sign_sels_0;
      end
      2'b01 : begin
        _zz_lane0_IntFormatPlugin_logic_stages_1_segments_1_sign_value = lane0_IntFormatPlugin_logic_stages_1_segments_1_sign_sels_1;
      end
      default : begin
      end
    endcase
  end

  assign lane0_IntFormatPlugin_logic_stages_1_segments_1_sign_value = (execute_ctrl4_down_lane0_IntFormatPlugin_logic_SIGNED_lane0 && _zz_lane0_IntFormatPlugin_logic_stages_1_segments_1_sign_value);
  assign lane0_IntFormatPlugin_logic_stages_1_segments_1_doIt = (execute_ctrl4_down_lane0_IntFormatPlugin_logic_WIDTH_ID_lane0 < 2'b10);
  assign lane0_IntFormatPlugin_logic_stages_2_hits = {CsrAccessPlugin_logic_wbWi_valid,early0_DivPlugin_logic_formatBus_valid};
  assign lane0_IntFormatPlugin_logic_stages_2_wb_valid = (execute_ctrl3_up_LANE_SEL_lane0 && (|lane0_IntFormatPlugin_logic_stages_2_hits));
  assign lane0_IntFormatPlugin_logic_stages_2_raw = ((lane0_IntFormatPlugin_logic_stages_2_hits[0] ? early0_DivPlugin_logic_formatBus_payload : 32'h0) | (lane0_IntFormatPlugin_logic_stages_2_hits[1] ? CsrAccessPlugin_logic_wbWi_payload : 32'h0));
  assign lane0_IntFormatPlugin_logic_stages_2_wb_payload = lane0_IntFormatPlugin_logic_stages_2_raw;
  always @(*) begin
    _zz_execute_ctrl4_down_late0_SrcPlugin_SRC1_lane0 = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    case(execute_ctrl4_down_late0_SrcPlugin_logic_SRC1_CTRL_lane0)
      1'b0 : begin
        _zz_execute_ctrl4_down_late0_SrcPlugin_SRC1_lane0 = execute_ctrl4_up_integer_RS1_lane0;
      end
      default : begin
        _zz_execute_ctrl4_down_late0_SrcPlugin_SRC1_lane0 = {execute_ctrl4_down_Decode_UOP_lane0[31 : 12],12'h0};
      end
    endcase
  end

  assign execute_ctrl4_down_late0_SrcPlugin_SRC1_lane0 = _zz_execute_ctrl4_down_late0_SrcPlugin_SRC1_lane0;
  always @(*) begin
    _zz_execute_ctrl4_down_late0_SrcPlugin_SRC2_lane0 = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    case(execute_ctrl4_down_late0_SrcPlugin_logic_SRC2_CTRL_lane0)
      2'b00 : begin
        _zz_execute_ctrl4_down_late0_SrcPlugin_SRC2_lane0 = execute_ctrl4_up_integer_RS2_lane0;
      end
      2'b01 : begin
        _zz_execute_ctrl4_down_late0_SrcPlugin_SRC2_lane0 = {{20{_zz__zz_execute_ctrl4_down_late0_SrcPlugin_SRC2_lane0[11]}}, _zz__zz_execute_ctrl4_down_late0_SrcPlugin_SRC2_lane0};
      end
      2'b10 : begin
        _zz_execute_ctrl4_down_late0_SrcPlugin_SRC2_lane0 = execute_ctrl4_down_PC_lane0;
      end
      default : begin
      end
    endcase
  end

  assign execute_ctrl4_down_late0_SrcPlugin_SRC2_lane0 = _zz_execute_ctrl4_down_late0_SrcPlugin_SRC2_lane0;
  always @(*) begin
    late0_SrcPlugin_logic_addsub_combined_rs2Patched = execute_ctrl4_down_late0_SrcPlugin_SRC2_lane0;
    if(execute_ctrl4_down_SrcStageables_REVERT_lane0) begin
      late0_SrcPlugin_logic_addsub_combined_rs2Patched = (~ execute_ctrl4_down_late0_SrcPlugin_SRC2_lane0);
    end
    if(execute_ctrl4_down_SrcStageables_ZERO_lane0) begin
      late0_SrcPlugin_logic_addsub_combined_rs2Patched = 32'h0;
    end
  end

  assign execute_ctrl4_down_late0_SrcPlugin_ADD_SUB_lane0 = ($signed(_zz_execute_ctrl4_down_late0_SrcPlugin_ADD_SUB_lane0) + $signed(_zz_execute_ctrl4_down_late0_SrcPlugin_ADD_SUB_lane0_1));
  assign execute_ctrl4_down_late0_SrcPlugin_LESS_lane0 = ((execute_ctrl4_down_late0_SrcPlugin_SRC1_lane0[31] == execute_ctrl4_down_late0_SrcPlugin_SRC2_lane0[31]) ? execute_ctrl4_down_late0_SrcPlugin_ADD_SUB_lane0[31] : (execute_ctrl4_down_SrcStageables_UNSIGNED_lane0 ? execute_ctrl4_down_late0_SrcPlugin_SRC2_lane0[31] : execute_ctrl4_down_late0_SrcPlugin_SRC1_lane0[31]));
  always @(*) begin
    _zz_execute_ctrl2_down_early1_SrcPlugin_SRC1_lane1 = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    case(execute_ctrl2_down_early1_SrcPlugin_logic_SRC1_CTRL_lane1)
      1'b0 : begin
        _zz_execute_ctrl2_down_early1_SrcPlugin_SRC1_lane1 = execute_ctrl2_up_integer_RS1_lane1;
      end
      default : begin
        _zz_execute_ctrl2_down_early1_SrcPlugin_SRC1_lane1 = {execute_ctrl2_down_Decode_UOP_lane1[31 : 12],12'h0};
      end
    endcase
  end

  assign execute_ctrl2_down_early1_SrcPlugin_SRC1_lane1 = _zz_execute_ctrl2_down_early1_SrcPlugin_SRC1_lane1;
  always @(*) begin
    _zz_execute_ctrl2_down_early1_SrcPlugin_SRC2_lane1 = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    case(execute_ctrl2_down_early1_SrcPlugin_logic_SRC2_CTRL_lane1)
      2'b00 : begin
        _zz_execute_ctrl2_down_early1_SrcPlugin_SRC2_lane1 = execute_ctrl2_up_integer_RS2_lane1;
      end
      2'b01 : begin
        _zz_execute_ctrl2_down_early1_SrcPlugin_SRC2_lane1 = {{20{_zz__zz_execute_ctrl2_down_early1_SrcPlugin_SRC2_lane1[11]}}, _zz__zz_execute_ctrl2_down_early1_SrcPlugin_SRC2_lane1};
      end
      2'b10 : begin
        _zz_execute_ctrl2_down_early1_SrcPlugin_SRC2_lane1 = execute_ctrl2_down_PC_lane1;
      end
      default : begin
      end
    endcase
  end

  assign execute_ctrl2_down_early1_SrcPlugin_SRC2_lane1 = _zz_execute_ctrl2_down_early1_SrcPlugin_SRC2_lane1;
  always @(*) begin
    early1_SrcPlugin_logic_addsub_combined_rs2Patched = execute_ctrl2_down_early1_SrcPlugin_SRC2_lane1;
    if(execute_ctrl2_down_SrcStageables_REVERT_lane1) begin
      early1_SrcPlugin_logic_addsub_combined_rs2Patched = (~ execute_ctrl2_down_early1_SrcPlugin_SRC2_lane1);
    end
    if(execute_ctrl2_down_SrcStageables_ZERO_lane1) begin
      early1_SrcPlugin_logic_addsub_combined_rs2Patched = 32'h0;
    end
  end

  assign execute_ctrl2_down_early1_SrcPlugin_ADD_SUB_lane1 = ($signed(_zz_execute_ctrl2_down_early1_SrcPlugin_ADD_SUB_lane1) + $signed(_zz_execute_ctrl2_down_early1_SrcPlugin_ADD_SUB_lane1_1));
  assign execute_ctrl2_down_early1_SrcPlugin_LESS_lane1 = ((execute_ctrl2_down_early1_SrcPlugin_SRC1_lane1[31] == execute_ctrl2_down_early1_SrcPlugin_SRC2_lane1[31]) ? execute_ctrl2_down_early1_SrcPlugin_ADD_SUB_lane1[31] : (execute_ctrl2_down_SrcStageables_UNSIGNED_lane1 ? execute_ctrl2_down_early1_SrcPlugin_SRC2_lane1[31] : execute_ctrl2_down_early1_SrcPlugin_SRC1_lane1[31]));
  assign lane1_IntFormatPlugin_logic_stages_0_hits = {early1_BarrelShifterPlugin_logic_wb_valid,early1_IntAluPlugin_logic_wb_valid};
  assign lane1_IntFormatPlugin_logic_stages_0_wb_valid = (execute_ctrl2_up_LANE_SEL_lane1 && (|lane1_IntFormatPlugin_logic_stages_0_hits));
  assign lane1_IntFormatPlugin_logic_stages_0_raw = ((lane1_IntFormatPlugin_logic_stages_0_hits[0] ? early1_IntAluPlugin_logic_wb_payload : 32'h0) | (lane1_IntFormatPlugin_logic_stages_0_hits[1] ? early1_BarrelShifterPlugin_logic_wb_payload : 32'h0));
  assign lane1_IntFormatPlugin_logic_stages_0_wb_payload = lane1_IntFormatPlugin_logic_stages_0_raw;
  assign lane1_IntFormatPlugin_logic_stages_1_hits = {late1_BarrelShifterPlugin_logic_wb_valid,late1_IntAluPlugin_logic_wb_valid};
  assign lane1_IntFormatPlugin_logic_stages_1_wb_valid = (execute_ctrl4_up_LANE_SEL_lane1 && (|lane1_IntFormatPlugin_logic_stages_1_hits));
  assign lane1_IntFormatPlugin_logic_stages_1_raw = ((lane1_IntFormatPlugin_logic_stages_1_hits[0] ? late1_IntAluPlugin_logic_wb_payload : 32'h0) | (lane1_IntFormatPlugin_logic_stages_1_hits[1] ? late1_BarrelShifterPlugin_logic_wb_payload : 32'h0));
  assign lane1_IntFormatPlugin_logic_stages_1_wb_payload = lane1_IntFormatPlugin_logic_stages_1_raw;
  always @(*) begin
    _zz_execute_ctrl4_down_late1_SrcPlugin_SRC1_lane1 = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    case(execute_ctrl4_down_late1_SrcPlugin_logic_SRC1_CTRL_lane1)
      1'b0 : begin
        _zz_execute_ctrl4_down_late1_SrcPlugin_SRC1_lane1 = execute_ctrl4_up_integer_RS1_lane1;
      end
      default : begin
        _zz_execute_ctrl4_down_late1_SrcPlugin_SRC1_lane1 = {execute_ctrl4_down_Decode_UOP_lane1[31 : 12],12'h0};
      end
    endcase
  end

  assign execute_ctrl4_down_late1_SrcPlugin_SRC1_lane1 = _zz_execute_ctrl4_down_late1_SrcPlugin_SRC1_lane1;
  always @(*) begin
    _zz_execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1 = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
    case(execute_ctrl4_down_late1_SrcPlugin_logic_SRC2_CTRL_lane1)
      2'b00 : begin
        _zz_execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1 = execute_ctrl4_up_integer_RS2_lane1;
      end
      2'b01 : begin
        _zz_execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1 = {{20{_zz__zz_execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1[11]}}, _zz__zz_execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1};
      end
      2'b10 : begin
        _zz_execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1 = execute_ctrl4_down_PC_lane1;
      end
      default : begin
      end
    endcase
  end

  assign execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1 = _zz_execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1;
  always @(*) begin
    late1_SrcPlugin_logic_addsub_combined_rs2Patched = execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1;
    if(execute_ctrl4_down_SrcStageables_REVERT_lane1) begin
      late1_SrcPlugin_logic_addsub_combined_rs2Patched = (~ execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1);
    end
    if(execute_ctrl4_down_SrcStageables_ZERO_lane1) begin
      late1_SrcPlugin_logic_addsub_combined_rs2Patched = 32'h0;
    end
  end

  assign execute_ctrl4_down_late1_SrcPlugin_ADD_SUB_lane1 = ($signed(_zz_execute_ctrl4_down_late1_SrcPlugin_ADD_SUB_lane1) + $signed(_zz_execute_ctrl4_down_late1_SrcPlugin_ADD_SUB_lane1_1));
  assign execute_ctrl4_down_late1_SrcPlugin_LESS_lane1 = ((execute_ctrl4_down_late1_SrcPlugin_SRC1_lane1[31] == execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1[31]) ? execute_ctrl4_down_late1_SrcPlugin_ADD_SUB_lane1[31] : (execute_ctrl4_down_SrcStageables_UNSIGNED_lane1 ? execute_ctrl4_down_late1_SrcPlugin_SRC2_lane1[31] : execute_ctrl4_down_late1_SrcPlugin_SRC1_lane1[31]));
  assign PerformanceCounterPlugin_logic_commitMask = PrivilegedPlugin_logic_harts_0_commitMask;
  assign when_PerformanceCounterPlugin_l47 = (|PerformanceCounterPlugin_logic_commitMask);
  assign PerformanceCounterPlugin_logic_commitCount = (_zz_PerformanceCounterPlugin_logic_commitCount - _zz_PerformanceCounterPlugin_logic_commitCount_2);
  assign PerformanceCounterPlugin_logic_stopCount = 1'b0;
  assign PerformanceCounterPlugin_logic_privValue = PrivilegedPlugin_logic_harts_0_privilege;
  assign PerformanceCounterPlugin_logic_rawPrivValue = _zz_PerformanceCounterPlugin_logic_rawPrivValue;
  assign PerformanceCounterPlugin_logic_counters_cycle_needFlush = PerformanceCounterPlugin_logic_counters_cycle_value[7];
  assign PerformanceCounterPlugin_logic_counters_cycle_MINH = 1'b0;
  assign PerformanceCounterPlugin_logic_counters_cycle_SINH = 1'b0;
  assign PerformanceCounterPlugin_logic_counters_cycle_UINH = 1'b0;
  assign PerformanceCounterPlugin_logic_counters_cycle_VSINH = 1'b0;
  assign PerformanceCounterPlugin_logic_counters_cycle_VUINH = 1'b0;
  assign PerformanceCounterPlugin_logic_counters_cycle_inhibit = PerformanceCounterPlugin_logic_counters_cycle_mcountinhibit;
  assign PerformanceCounterPlugin_logic_counters_instret_needFlush = PerformanceCounterPlugin_logic_counters_instret_value[7];
  assign PerformanceCounterPlugin_logic_counters_instret_MINH = 1'b0;
  assign PerformanceCounterPlugin_logic_counters_instret_SINH = 1'b0;
  assign PerformanceCounterPlugin_logic_counters_instret_UINH = 1'b0;
  assign PerformanceCounterPlugin_logic_counters_instret_VSINH = 1'b0;
  assign PerformanceCounterPlugin_logic_counters_instret_VUINH = 1'b0;
  assign PerformanceCounterPlugin_logic_counters_instret_inhibit = PerformanceCounterPlugin_logic_counters_instret_mcountinhibit;
  assign PerformanceCounterPlugin_logic_eventCycles = 1'b1;
  assign _zz_PerformanceCounterPlugin_logic_eventInstructions_0 = ((! PerformanceCounterPlugin_logic_ignoreNextCommit) ? PerformanceCounterPlugin_logic_commitMask : 2'b00);
  assign PerformanceCounterPlugin_logic_eventInstructions_0 = _zz_PerformanceCounterPlugin_logic_eventInstructions_0[0];
  assign PerformanceCounterPlugin_logic_eventInstructions_1 = _zz_PerformanceCounterPlugin_logic_eventInstructions_0[1];
  assign PerformanceCounterPlugin_logic_interrupt_nonGuestMode = 1'b1;
  always @(*) begin
    case(execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane0)
      BranchPlugin_BranchCtrlEnum_JALR : begin
        early0_BranchPlugin_pcCalc_target_a = execute_ctrl2_down_early0_SrcPlugin_SRC1_lane0;
      end
      default : begin
        early0_BranchPlugin_pcCalc_target_a = execute_ctrl2_down_PC_lane0;
      end
    endcase
  end

  always @(*) begin
    case(execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane0)
      BranchPlugin_BranchCtrlEnum_JAL : begin
        early0_BranchPlugin_pcCalc_target_b = {{11{_zz_early0_BranchPlugin_pcCalc_target_b[20]}}, _zz_early0_BranchPlugin_pcCalc_target_b};
      end
      BranchPlugin_BranchCtrlEnum_JALR : begin
        early0_BranchPlugin_pcCalc_target_b = {{20{_zz_early0_BranchPlugin_pcCalc_target_b_1[11]}}, _zz_early0_BranchPlugin_pcCalc_target_b_1};
      end
      default : begin
        early0_BranchPlugin_pcCalc_target_b = {{19{_zz_early0_BranchPlugin_pcCalc_target_b_2[12]}}, _zz_early0_BranchPlugin_pcCalc_target_b_2};
      end
    endcase
  end

  assign early0_BranchPlugin_pcCalc_slices = ({1'b0,execute_ctrl2_down_Decode_INSTRUCTION_SLICE_COUNT_lane0} + {1'b0,1'b1});
  always @(*) begin
    execute_ctrl2_down_early0_BranchPlugin_pcCalc_PC_TRUE_lane0 = _zz_execute_ctrl2_down_early0_BranchPlugin_pcCalc_PC_TRUE_lane0;
    execute_ctrl2_down_early0_BranchPlugin_pcCalc_PC_TRUE_lane0[0] = 1'b0;
  end

  assign execute_ctrl2_down_early0_BranchPlugin_pcCalc_PC_FALSE_lane0 = (execute_ctrl2_down_PC_lane0 + _zz_execute_ctrl2_down_early0_BranchPlugin_pcCalc_PC_FALSE_lane0);
  assign execute_ctrl2_down_early0_BranchPlugin_pcCalc_PC_LAST_SLICE_lane0 = (execute_ctrl2_down_PC_lane0 + _zz_execute_ctrl2_down_early0_BranchPlugin_pcCalc_PC_LAST_SLICE_lane0);
  always @(*) begin
    case(execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane1)
      BranchPlugin_BranchCtrlEnum_JALR : begin
        early1_BranchPlugin_pcCalc_target_a = execute_ctrl2_down_early1_SrcPlugin_SRC1_lane1;
      end
      default : begin
        early1_BranchPlugin_pcCalc_target_a = execute_ctrl2_down_PC_lane1;
      end
    endcase
  end

  always @(*) begin
    case(execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane1)
      BranchPlugin_BranchCtrlEnum_JAL : begin
        early1_BranchPlugin_pcCalc_target_b = {{11{_zz_early1_BranchPlugin_pcCalc_target_b[20]}}, _zz_early1_BranchPlugin_pcCalc_target_b};
      end
      BranchPlugin_BranchCtrlEnum_JALR : begin
        early1_BranchPlugin_pcCalc_target_b = {{20{_zz_early1_BranchPlugin_pcCalc_target_b_1[11]}}, _zz_early1_BranchPlugin_pcCalc_target_b_1};
      end
      default : begin
        early1_BranchPlugin_pcCalc_target_b = {{19{_zz_early1_BranchPlugin_pcCalc_target_b_2[12]}}, _zz_early1_BranchPlugin_pcCalc_target_b_2};
      end
    endcase
  end

  assign early1_BranchPlugin_pcCalc_slices = ({1'b0,execute_ctrl2_down_Decode_INSTRUCTION_SLICE_COUNT_lane1} + {1'b0,1'b1});
  always @(*) begin
    execute_ctrl2_down_early1_BranchPlugin_pcCalc_PC_TRUE_lane1 = _zz_execute_ctrl2_down_early1_BranchPlugin_pcCalc_PC_TRUE_lane1;
    execute_ctrl2_down_early1_BranchPlugin_pcCalc_PC_TRUE_lane1[0] = 1'b0;
  end

  assign execute_ctrl2_down_early1_BranchPlugin_pcCalc_PC_FALSE_lane1 = (execute_ctrl2_down_PC_lane1 + _zz_execute_ctrl2_down_early1_BranchPlugin_pcCalc_PC_FALSE_lane1);
  assign execute_ctrl2_down_early1_BranchPlugin_pcCalc_PC_LAST_SLICE_lane1 = (execute_ctrl2_down_PC_lane1 + _zz_execute_ctrl2_down_early1_BranchPlugin_pcCalc_PC_LAST_SLICE_lane1);
  assign AlignerPlugin_logic_maskGen_frontMasks_0 = 4'b1111;
  assign AlignerPlugin_logic_maskGen_frontMasks_1 = 4'b1110;
