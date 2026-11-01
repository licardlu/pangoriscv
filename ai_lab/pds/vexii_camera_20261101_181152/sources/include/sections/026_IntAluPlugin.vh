  always @(*) begin
    case(_zz_WhiteboxerPlugin_logic_perf_candidatesCount_1)
      3'b000 : _zz_WhiteboxerPlugin_logic_perf_candidatesCount = 2'b00;
      3'b001 : _zz_WhiteboxerPlugin_logic_perf_candidatesCount = 2'b01;
      3'b010 : _zz_WhiteboxerPlugin_logic_perf_candidatesCount = 2'b01;
      3'b011 : _zz_WhiteboxerPlugin_logic_perf_candidatesCount = 2'b10;
      3'b100 : _zz_WhiteboxerPlugin_logic_perf_candidatesCount = 2'b01;
      3'b101 : _zz_WhiteboxerPlugin_logic_perf_candidatesCount = 2'b10;
      3'b110 : _zz_WhiteboxerPlugin_logic_perf_candidatesCount = 2'b10;
      default : _zz_WhiteboxerPlugin_logic_perf_candidatesCount = 2'b11;
    endcase
  end

  always @(*) begin
    case(_zz_WhiteboxerPlugin_logic_perf_dispatchFeedCount_1)
      2'b00 : _zz_WhiteboxerPlugin_logic_perf_dispatchFeedCount = 2'b00;
      2'b01 : _zz_WhiteboxerPlugin_logic_perf_dispatchFeedCount = 2'b01;
      2'b10 : _zz_WhiteboxerPlugin_logic_perf_dispatchFeedCount = 2'b01;
      default : _zz_WhiteboxerPlugin_logic_perf_dispatchFeedCount = 2'b10;
    endcase
  end

  `ifndef SYNTHESIS
  always @(*) begin
    case(execute_ctrl3_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : execute_ctrl3_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : execute_ctrl3_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : execute_ctrl3_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : execute_ctrl3_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "ZERO ";
      default : execute_ctrl3_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl3_down_BranchPlugin_BRANCH_CTRL_lane1)
      BranchPlugin_BranchCtrlEnum_B : execute_ctrl3_down_BranchPlugin_BRANCH_CTRL_lane1_string = "B   ";
      BranchPlugin_BranchCtrlEnum_JAL : execute_ctrl3_down_BranchPlugin_BRANCH_CTRL_lane1_string = "JAL ";
      BranchPlugin_BranchCtrlEnum_JALR : execute_ctrl3_down_BranchPlugin_BRANCH_CTRL_lane1_string = "JALR";
      default : execute_ctrl3_down_BranchPlugin_BRANCH_CTRL_lane1_string = "????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl3_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : execute_ctrl3_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : execute_ctrl3_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : execute_ctrl3_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : execute_ctrl3_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "ZERO ";
      default : execute_ctrl3_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl3_down_BranchPlugin_BRANCH_CTRL_lane0)
      BranchPlugin_BranchCtrlEnum_B : execute_ctrl3_down_BranchPlugin_BRANCH_CTRL_lane0_string = "B   ";
      BranchPlugin_BranchCtrlEnum_JAL : execute_ctrl3_down_BranchPlugin_BRANCH_CTRL_lane0_string = "JAL ";
      BranchPlugin_BranchCtrlEnum_JALR : execute_ctrl3_down_BranchPlugin_BRANCH_CTRL_lane0_string = "JALR";
      default : execute_ctrl3_down_BranchPlugin_BRANCH_CTRL_lane0_string = "????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl4_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : execute_ctrl4_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : execute_ctrl4_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : execute_ctrl4_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : execute_ctrl4_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "ZERO ";
      default : execute_ctrl4_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl4_up_BranchPlugin_BRANCH_CTRL_lane1)
      BranchPlugin_BranchCtrlEnum_B : execute_ctrl4_up_BranchPlugin_BRANCH_CTRL_lane1_string = "B   ";
      BranchPlugin_BranchCtrlEnum_JAL : execute_ctrl4_up_BranchPlugin_BRANCH_CTRL_lane1_string = "JAL ";
      BranchPlugin_BranchCtrlEnum_JALR : execute_ctrl4_up_BranchPlugin_BRANCH_CTRL_lane1_string = "JALR";
      default : execute_ctrl4_up_BranchPlugin_BRANCH_CTRL_lane1_string = "????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl4_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : execute_ctrl4_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : execute_ctrl4_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : execute_ctrl4_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : execute_ctrl4_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "ZERO ";
      default : execute_ctrl4_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl4_up_BranchPlugin_BRANCH_CTRL_lane0)
      BranchPlugin_BranchCtrlEnum_B : execute_ctrl4_up_BranchPlugin_BRANCH_CTRL_lane0_string = "B   ";
      BranchPlugin_BranchCtrlEnum_JAL : execute_ctrl4_up_BranchPlugin_BRANCH_CTRL_lane0_string = "JAL ";
      BranchPlugin_BranchCtrlEnum_JALR : execute_ctrl4_up_BranchPlugin_BRANCH_CTRL_lane0_string = "JALR";
      default : execute_ctrl4_up_BranchPlugin_BRANCH_CTRL_lane0_string = "????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl2_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : execute_ctrl2_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : execute_ctrl2_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : execute_ctrl2_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : execute_ctrl2_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "ZERO ";
      default : execute_ctrl2_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl2_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : execute_ctrl2_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : execute_ctrl2_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : execute_ctrl2_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : execute_ctrl2_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "ZERO ";
      default : execute_ctrl2_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl3_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : execute_ctrl3_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : execute_ctrl3_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : execute_ctrl3_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : execute_ctrl3_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "ZERO ";
      default : execute_ctrl3_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl3_up_BranchPlugin_BRANCH_CTRL_lane1)
      BranchPlugin_BranchCtrlEnum_B : execute_ctrl3_up_BranchPlugin_BRANCH_CTRL_lane1_string = "B   ";
      BranchPlugin_BranchCtrlEnum_JAL : execute_ctrl3_up_BranchPlugin_BRANCH_CTRL_lane1_string = "JAL ";
      BranchPlugin_BranchCtrlEnum_JALR : execute_ctrl3_up_BranchPlugin_BRANCH_CTRL_lane1_string = "JALR";
      default : execute_ctrl3_up_BranchPlugin_BRANCH_CTRL_lane1_string = "????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl3_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : execute_ctrl3_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : execute_ctrl3_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : execute_ctrl3_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : execute_ctrl3_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "ZERO ";
      default : execute_ctrl3_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl3_up_BranchPlugin_BRANCH_CTRL_lane0)
      BranchPlugin_BranchCtrlEnum_B : execute_ctrl3_up_BranchPlugin_BRANCH_CTRL_lane0_string = "B   ";
      BranchPlugin_BranchCtrlEnum_JAL : execute_ctrl3_up_BranchPlugin_BRANCH_CTRL_lane0_string = "JAL ";
      BranchPlugin_BranchCtrlEnum_JALR : execute_ctrl3_up_BranchPlugin_BRANCH_CTRL_lane0_string = "JALR";
      default : execute_ctrl3_up_BranchPlugin_BRANCH_CTRL_lane0_string = "????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl2_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : execute_ctrl2_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : execute_ctrl2_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : execute_ctrl2_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : execute_ctrl2_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "ZERO ";
      default : execute_ctrl2_up_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl2_up_BranchPlugin_BRANCH_CTRL_lane1)
      BranchPlugin_BranchCtrlEnum_B : execute_ctrl2_up_BranchPlugin_BRANCH_CTRL_lane1_string = "B   ";
      BranchPlugin_BranchCtrlEnum_JAL : execute_ctrl2_up_BranchPlugin_BRANCH_CTRL_lane1_string = "JAL ";
      BranchPlugin_BranchCtrlEnum_JALR : execute_ctrl2_up_BranchPlugin_BRANCH_CTRL_lane1_string = "JALR";
      default : execute_ctrl2_up_BranchPlugin_BRANCH_CTRL_lane1_string = "????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl2_up_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : execute_ctrl2_up_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : execute_ctrl2_up_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : execute_ctrl2_up_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : execute_ctrl2_up_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "ZERO ";
      default : execute_ctrl2_up_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl2_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : execute_ctrl2_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : execute_ctrl2_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : execute_ctrl2_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : execute_ctrl2_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "ZERO ";
      default : execute_ctrl2_up_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl2_up_early0_EnvPlugin_OP_lane0)
      EnvPluginOp_ECALL : execute_ctrl2_up_early0_EnvPlugin_OP_lane0_string = "ECALL      ";
      EnvPluginOp_EBREAK : execute_ctrl2_up_early0_EnvPlugin_OP_lane0_string = "EBREAK     ";
      EnvPluginOp_PRIV_RET : execute_ctrl2_up_early0_EnvPlugin_OP_lane0_string = "PRIV_RET   ";
      EnvPluginOp_FENCE_I : execute_ctrl2_up_early0_EnvPlugin_OP_lane0_string = "FENCE_I    ";
      EnvPluginOp_SFENCE_VMA : execute_ctrl2_up_early0_EnvPlugin_OP_lane0_string = "SFENCE_VMA ";
      EnvPluginOp_WFI : execute_ctrl2_up_early0_EnvPlugin_OP_lane0_string = "WFI        ";
      EnvPluginOp_HFENCE_GVMA : execute_ctrl2_up_early0_EnvPlugin_OP_lane0_string = "HFENCE_GVMA";
      EnvPluginOp_HFENCE_VVMA : execute_ctrl2_up_early0_EnvPlugin_OP_lane0_string = "HFENCE_VVMA";
      default : execute_ctrl2_up_early0_EnvPlugin_OP_lane0_string = "???????????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl2_up_BranchPlugin_BRANCH_CTRL_lane0)
      BranchPlugin_BranchCtrlEnum_B : execute_ctrl2_up_BranchPlugin_BRANCH_CTRL_lane0_string = "B   ";
      BranchPlugin_BranchCtrlEnum_JAL : execute_ctrl2_up_BranchPlugin_BRANCH_CTRL_lane0_string = "JAL ";
      BranchPlugin_BranchCtrlEnum_JALR : execute_ctrl2_up_BranchPlugin_BRANCH_CTRL_lane0_string = "JALR";
      default : execute_ctrl2_up_BranchPlugin_BRANCH_CTRL_lane0_string = "????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl2_up_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : execute_ctrl2_up_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : execute_ctrl2_up_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : execute_ctrl2_up_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : execute_ctrl2_up_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "ZERO ";
      default : execute_ctrl2_up_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "ZERO ";
      default : execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1)
      BranchPlugin_BranchCtrlEnum_B : execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_string = "B   ";
      BranchPlugin_BranchCtrlEnum_JAL : execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_string = "JAL ";
      BranchPlugin_BranchCtrlEnum_JALR : execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_string = "JALR";
      default : execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_string = "????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "ZERO ";
      default : execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "ZERO ";
      default : execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl1_down_early0_EnvPlugin_OP_lane0)
      EnvPluginOp_ECALL : execute_ctrl1_down_early0_EnvPlugin_OP_lane0_string = "ECALL      ";
      EnvPluginOp_EBREAK : execute_ctrl1_down_early0_EnvPlugin_OP_lane0_string = "EBREAK     ";
      EnvPluginOp_PRIV_RET : execute_ctrl1_down_early0_EnvPlugin_OP_lane0_string = "PRIV_RET   ";
      EnvPluginOp_FENCE_I : execute_ctrl1_down_early0_EnvPlugin_OP_lane0_string = "FENCE_I    ";
      EnvPluginOp_SFENCE_VMA : execute_ctrl1_down_early0_EnvPlugin_OP_lane0_string = "SFENCE_VMA ";
      EnvPluginOp_WFI : execute_ctrl1_down_early0_EnvPlugin_OP_lane0_string = "WFI        ";
      EnvPluginOp_HFENCE_GVMA : execute_ctrl1_down_early0_EnvPlugin_OP_lane0_string = "HFENCE_GVMA";
      EnvPluginOp_HFENCE_VVMA : execute_ctrl1_down_early0_EnvPlugin_OP_lane0_string = "HFENCE_VVMA";
      default : execute_ctrl1_down_early0_EnvPlugin_OP_lane0_string = "???????????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0)
      BranchPlugin_BranchCtrlEnum_B : execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_string = "B   ";
      BranchPlugin_BranchCtrlEnum_JAL : execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_string = "JAL ";
      BranchPlugin_BranchCtrlEnum_JALR : execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_string = "JALR";
      default : execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_string = "????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "ZERO ";
      default : execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane1)
      BranchPlugin_BranchCtrlEnum_B : execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane1_string = "B   ";
      BranchPlugin_BranchCtrlEnum_JAL : execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane1_string = "JAL ";
      BranchPlugin_BranchCtrlEnum_JALR : execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane1_string = "JALR";
      default : execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane1_string = "????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane0)
      BranchPlugin_BranchCtrlEnum_B : execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane0_string = "B   ";
      BranchPlugin_BranchCtrlEnum_JAL : execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane0_string = "JAL ";
      BranchPlugin_BranchCtrlEnum_JALR : execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane0_string = "JALR";
      default : execute_ctrl4_down_BranchPlugin_BRANCH_CTRL_lane0_string = "????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane1)
      BranchPlugin_BranchCtrlEnum_B : execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane1_string = "B   ";
      BranchPlugin_BranchCtrlEnum_JAL : execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane1_string = "JAL ";
      BranchPlugin_BranchCtrlEnum_JALR : execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane1_string = "JALR";
      default : execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane1_string = "????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane0)
      BranchPlugin_BranchCtrlEnum_B : execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane0_string = "B   ";
      BranchPlugin_BranchCtrlEnum_JAL : execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane0_string = "JAL ";
      BranchPlugin_BranchCtrlEnum_JALR : execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane0_string = "JALR";
      default : execute_ctrl2_down_BranchPlugin_BRANCH_CTRL_lane0_string = "????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl2_down_early0_EnvPlugin_OP_lane0)
      EnvPluginOp_ECALL : execute_ctrl2_down_early0_EnvPlugin_OP_lane0_string = "ECALL      ";
      EnvPluginOp_EBREAK : execute_ctrl2_down_early0_EnvPlugin_OP_lane0_string = "EBREAK     ";
      EnvPluginOp_PRIV_RET : execute_ctrl2_down_early0_EnvPlugin_OP_lane0_string = "PRIV_RET   ";
      EnvPluginOp_FENCE_I : execute_ctrl2_down_early0_EnvPlugin_OP_lane0_string = "FENCE_I    ";
      EnvPluginOp_SFENCE_VMA : execute_ctrl2_down_early0_EnvPlugin_OP_lane0_string = "SFENCE_VMA ";
      EnvPluginOp_WFI : execute_ctrl2_down_early0_EnvPlugin_OP_lane0_string = "WFI        ";
      EnvPluginOp_HFENCE_GVMA : execute_ctrl2_down_early0_EnvPlugin_OP_lane0_string = "HFENCE_GVMA";
      EnvPluginOp_HFENCE_VVMA : execute_ctrl2_down_early0_EnvPlugin_OP_lane0_string = "HFENCE_VVMA";
      default : execute_ctrl2_down_early0_EnvPlugin_OP_lane0_string = "???????????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl4_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : execute_ctrl4_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : execute_ctrl4_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : execute_ctrl4_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : execute_ctrl4_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "ZERO ";
      default : execute_ctrl4_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl2_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : execute_ctrl2_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : execute_ctrl2_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : execute_ctrl2_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : execute_ctrl2_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "ZERO ";
      default : execute_ctrl2_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl4_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : execute_ctrl4_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : execute_ctrl4_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : execute_ctrl4_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : execute_ctrl4_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "ZERO ";
      default : execute_ctrl4_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "?????";
    endcase
  end
  always @(*) begin
    case(execute_ctrl2_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : execute_ctrl2_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : execute_ctrl2_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : execute_ctrl2_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : execute_ctrl2_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "ZERO ";
      default : execute_ctrl2_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "?????";
    endcase
  end
  always @(*) begin
    case(FetchL1TileLinkPlugin_logic_down_a_payload_opcode)
      A_PUT_FULL_DATA : FetchL1TileLinkPlugin_logic_down_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : FetchL1TileLinkPlugin_logic_down_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : FetchL1TileLinkPlugin_logic_down_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : FetchL1TileLinkPlugin_logic_down_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : FetchL1TileLinkPlugin_logic_down_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : FetchL1TileLinkPlugin_logic_down_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : FetchL1TileLinkPlugin_logic_down_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : FetchL1TileLinkPlugin_logic_down_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(FetchL1TileLinkPlugin_logic_down_d_payload_opcode)
      D_ACCESS_ACK : FetchL1TileLinkPlugin_logic_down_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : FetchL1TileLinkPlugin_logic_down_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : FetchL1TileLinkPlugin_logic_down_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : FetchL1TileLinkPlugin_logic_down_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : FetchL1TileLinkPlugin_logic_down_d_payload_opcode_string = "RELEASE_ACK    ";
      default : FetchL1TileLinkPlugin_logic_down_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(LsuPlugin_logic_onAddress0_ls_port_payload_op)
      LsuL1CmdOpcode_LSU : LsuPlugin_logic_onAddress0_ls_port_payload_op_string = "LSU         ";
      LsuL1CmdOpcode_ACCESS_1 : LsuPlugin_logic_onAddress0_ls_port_payload_op_string = "ACCESS_1    ";
      LsuL1CmdOpcode_STORE_BUFFER : LsuPlugin_logic_onAddress0_ls_port_payload_op_string = "STORE_BUFFER";
      LsuL1CmdOpcode_FLUSH : LsuPlugin_logic_onAddress0_ls_port_payload_op_string = "FLUSH       ";
      LsuL1CmdOpcode_PREFETCH : LsuPlugin_logic_onAddress0_ls_port_payload_op_string = "PREFETCH    ";
      default : LsuPlugin_logic_onAddress0_ls_port_payload_op_string = "????????????";
    endcase
  end
  always @(*) begin
    case(LsuPlugin_logic_onAddress0_flush_port_payload_op)
      LsuL1CmdOpcode_LSU : LsuPlugin_logic_onAddress0_flush_port_payload_op_string = "LSU         ";
      LsuL1CmdOpcode_ACCESS_1 : LsuPlugin_logic_onAddress0_flush_port_payload_op_string = "ACCESS_1    ";
      LsuL1CmdOpcode_STORE_BUFFER : LsuPlugin_logic_onAddress0_flush_port_payload_op_string = "STORE_BUFFER";
      LsuL1CmdOpcode_FLUSH : LsuPlugin_logic_onAddress0_flush_port_payload_op_string = "FLUSH       ";
      LsuL1CmdOpcode_PREFETCH : LsuPlugin_logic_onAddress0_flush_port_payload_op_string = "PREFETCH    ";
      default : LsuPlugin_logic_onAddress0_flush_port_payload_op_string = "????????????";
    endcase
  end
  always @(*) begin
    case(LsuPlugin_logic_onAddress0_fromHp_port_payload_op)
      LsuL1CmdOpcode_LSU : LsuPlugin_logic_onAddress0_fromHp_port_payload_op_string = "LSU         ";
      LsuL1CmdOpcode_ACCESS_1 : LsuPlugin_logic_onAddress0_fromHp_port_payload_op_string = "ACCESS_1    ";
      LsuL1CmdOpcode_STORE_BUFFER : LsuPlugin_logic_onAddress0_fromHp_port_payload_op_string = "STORE_BUFFER";
      LsuL1CmdOpcode_FLUSH : LsuPlugin_logic_onAddress0_fromHp_port_payload_op_string = "FLUSH       ";
      LsuL1CmdOpcode_PREFETCH : LsuPlugin_logic_onAddress0_fromHp_port_payload_op_string = "PREFETCH    ";
      default : LsuPlugin_logic_onAddress0_fromHp_port_payload_op_string = "????????????";
    endcase
  end
  always @(*) begin
    case(LsuPlugin_logic_onAddress0_sb_port_payload_op)
      LsuL1CmdOpcode_LSU : LsuPlugin_logic_onAddress0_sb_port_payload_op_string = "LSU         ";
      LsuL1CmdOpcode_ACCESS_1 : LsuPlugin_logic_onAddress0_sb_port_payload_op_string = "ACCESS_1    ";
      LsuL1CmdOpcode_STORE_BUFFER : LsuPlugin_logic_onAddress0_sb_port_payload_op_string = "STORE_BUFFER";
      LsuL1CmdOpcode_FLUSH : LsuPlugin_logic_onAddress0_sb_port_payload_op_string = "FLUSH       ";
      LsuL1CmdOpcode_PREFETCH : LsuPlugin_logic_onAddress0_sb_port_payload_op_string = "PREFETCH    ";
      default : LsuPlugin_logic_onAddress0_sb_port_payload_op_string = "????????????";
    endcase
  end
  always @(*) begin
    case(LsuL1TileLinkPlugin_logic_down_a_payload_opcode)
      A_PUT_FULL_DATA : LsuL1TileLinkPlugin_logic_down_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : LsuL1TileLinkPlugin_logic_down_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : LsuL1TileLinkPlugin_logic_down_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : LsuL1TileLinkPlugin_logic_down_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : LsuL1TileLinkPlugin_logic_down_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : LsuL1TileLinkPlugin_logic_down_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : LsuL1TileLinkPlugin_logic_down_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : LsuL1TileLinkPlugin_logic_down_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(LsuL1TileLinkPlugin_logic_down_d_payload_opcode)
      D_ACCESS_ACK : LsuL1TileLinkPlugin_logic_down_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : LsuL1TileLinkPlugin_logic_down_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : LsuL1TileLinkPlugin_logic_down_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : LsuL1TileLinkPlugin_logic_down_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : LsuL1TileLinkPlugin_logic_down_d_payload_opcode_string = "RELEASE_ACK    ";
      default : LsuL1TileLinkPlugin_logic_down_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "ZERO ";
      default : _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_1)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_1_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_1_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_1_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_1_string = "ZERO ";
      default : _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_1_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_2)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_2_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_2_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_2_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_2_string = "ZERO ";
      default : _zz_execute_ctrl1_down_early0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_2_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0)
      BranchPlugin_BranchCtrlEnum_B : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_string = "B   ";
      BranchPlugin_BranchCtrlEnum_JAL : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_string = "JAL ";
      BranchPlugin_BranchCtrlEnum_JALR : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_string = "JALR";
      default : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_1)
      BranchPlugin_BranchCtrlEnum_B : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_1_string = "B   ";
      BranchPlugin_BranchCtrlEnum_JAL : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_1_string = "JAL ";
      BranchPlugin_BranchCtrlEnum_JALR : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_1_string = "JALR";
      default : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_1_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_2)
      BranchPlugin_BranchCtrlEnum_B : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_2_string = "B   ";
      BranchPlugin_BranchCtrlEnum_JAL : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_2_string = "JAL ";
      BranchPlugin_BranchCtrlEnum_JALR : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_2_string = "JALR";
      default : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane0_2_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_1)
      EnvPluginOp_ECALL : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_1_string = "ECALL      ";
      EnvPluginOp_EBREAK : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_1_string = "EBREAK     ";
      EnvPluginOp_PRIV_RET : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_1_string = "PRIV_RET   ";
      EnvPluginOp_FENCE_I : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_1_string = "FENCE_I    ";
      EnvPluginOp_SFENCE_VMA : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_1_string = "SFENCE_VMA ";
      EnvPluginOp_WFI : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_1_string = "WFI        ";
      EnvPluginOp_HFENCE_GVMA : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_1_string = "HFENCE_GVMA";
      EnvPluginOp_HFENCE_VVMA : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_1_string = "HFENCE_VVMA";
      default : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_1_string = "???????????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_2)
      EnvPluginOp_ECALL : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_2_string = "ECALL      ";
      EnvPluginOp_EBREAK : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_2_string = "EBREAK     ";
      EnvPluginOp_PRIV_RET : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_2_string = "PRIV_RET   ";
      EnvPluginOp_FENCE_I : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_2_string = "FENCE_I    ";
      EnvPluginOp_SFENCE_VMA : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_2_string = "SFENCE_VMA ";
      EnvPluginOp_WFI : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_2_string = "WFI        ";
      EnvPluginOp_HFENCE_GVMA : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_2_string = "HFENCE_GVMA";
      EnvPluginOp_HFENCE_VVMA : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_2_string = "HFENCE_VVMA";
      default : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_2_string = "???????????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_3)
      EnvPluginOp_ECALL : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_3_string = "ECALL      ";
      EnvPluginOp_EBREAK : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_3_string = "EBREAK     ";
      EnvPluginOp_PRIV_RET : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_3_string = "PRIV_RET   ";
      EnvPluginOp_FENCE_I : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_3_string = "FENCE_I    ";
      EnvPluginOp_SFENCE_VMA : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_3_string = "SFENCE_VMA ";
      EnvPluginOp_WFI : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_3_string = "WFI        ";
      EnvPluginOp_HFENCE_GVMA : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_3_string = "HFENCE_GVMA";
      EnvPluginOp_HFENCE_VVMA : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_3_string = "HFENCE_VVMA";
      default : _zz_execute_ctrl1_down_early0_EnvPlugin_OP_lane0_3_string = "???????????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_1)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_1_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_1_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_1_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_1_string = "ZERO ";
      default : _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_1_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_2)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_2_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_2_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_2_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_2_string = "ZERO ";
      default : _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_2_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_3)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_3_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_3_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_3_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_3_string = "ZERO ";
      default : _zz_execute_ctrl1_down_late0_IntAluPlugin_ALU_BITWISE_CTRL_lane0_3_string = "?????";
    endcase
  end
  always @(*) begin
    case(LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode)
      A_PUT_FULL_DATA : LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(LsuTileLinkPlugin_logic_bridge_down_d_payload_opcode)
      D_ACCESS_ACK : LsuTileLinkPlugin_logic_bridge_down_d_payload_opcode_string = "ACCESS_ACK     ";
      D_ACCESS_ACK_DATA : LsuTileLinkPlugin_logic_bridge_down_d_payload_opcode_string = "ACCESS_ACK_DATA";
      D_GRANT : LsuTileLinkPlugin_logic_bridge_down_d_payload_opcode_string = "GRANT          ";
      D_GRANT_DATA : LsuTileLinkPlugin_logic_bridge_down_d_payload_opcode_string = "GRANT_DATA     ";
      D_RELEASE_ACK : LsuTileLinkPlugin_logic_bridge_down_d_payload_opcode_string = "RELEASE_ACK    ";
      default : LsuTileLinkPlugin_logic_bridge_down_d_payload_opcode_string = "???????????????";
    endcase
  end
  always @(*) begin
    case(_zz_LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode)
      A_PUT_FULL_DATA : _zz_LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode_string = "PUT_FULL_DATA   ";
      A_PUT_PARTIAL_DATA : _zz_LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode_string = "PUT_PARTIAL_DATA";
      A_ARITHMETIC_DATA : _zz_LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode_string = "ARITHMETIC_DATA ";
      A_LOGICAL_DATA : _zz_LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode_string = "LOGICAL_DATA    ";
      A_GET : _zz_LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode_string = "GET             ";
      A_ACQUIRE_BLOCK : _zz_LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode_string = "ACQUIRE_BLOCK   ";
      A_ACQUIRE_PERM : _zz_LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode_string = "ACQUIRE_PERM    ";
      default : _zz_LsuTileLinkPlugin_logic_bridge_down_a_payload_opcode_string = "????????????????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "ZERO ";
      default : _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_1)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_1_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_1_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_1_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_1_string = "ZERO ";
      default : _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_1_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_2)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_2_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_2_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_2_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_2_string = "ZERO ";
      default : _zz_execute_ctrl1_down_early1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_2_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1)
      BranchPlugin_BranchCtrlEnum_B : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_string = "B   ";
      BranchPlugin_BranchCtrlEnum_JAL : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_string = "JAL ";
      BranchPlugin_BranchCtrlEnum_JALR : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_string = "JALR";
      default : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_1)
      BranchPlugin_BranchCtrlEnum_B : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_1_string = "B   ";
      BranchPlugin_BranchCtrlEnum_JAL : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_1_string = "JAL ";
      BranchPlugin_BranchCtrlEnum_JALR : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_1_string = "JALR";
      default : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_1_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_2)
      BranchPlugin_BranchCtrlEnum_B : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_2_string = "B   ";
      BranchPlugin_BranchCtrlEnum_JAL : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_2_string = "JAL ";
      BranchPlugin_BranchCtrlEnum_JALR : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_2_string = "JALR";
      default : _zz_execute_ctrl1_down_BranchPlugin_BRANCH_CTRL_lane1_2_string = "????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_2)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : _zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_2_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : _zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_2_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : _zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_2_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : _zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_2_string = "ZERO ";
      default : _zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_2_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_3)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : _zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_3_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : _zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_3_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : _zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_3_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : _zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_3_string = "ZERO ";
      default : _zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_3_string = "?????";
    endcase
  end
  always @(*) begin
    case(_zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_4)
      IntAluPlugin_AluBitwiseCtrlEnum_XOR_1 : _zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_4_string = "XOR_1";
      IntAluPlugin_AluBitwiseCtrlEnum_OR_1 : _zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_4_string = "OR_1 ";
      IntAluPlugin_AluBitwiseCtrlEnum_AND_1 : _zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_4_string = "AND_1";
      IntAluPlugin_AluBitwiseCtrlEnum_ZERO : _zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_4_string = "ZERO ";
      default : _zz_execute_ctrl1_down_late1_IntAluPlugin_ALU_BITWISE_CTRL_lane1_4_string = "?????";
    endcase
  end
  always @(*) begin
    case(PerformanceCounterPlugin_logic_fsm_stateReg)
      PerformanceCounterPlugin_logic_fsm_BOOT : PerformanceCounterPlugin_logic_fsm_stateReg_string = "BOOT     ";
      PerformanceCounterPlugin_logic_fsm_IDLE : PerformanceCounterPlugin_logic_fsm_stateReg_string = "IDLE     ";
      PerformanceCounterPlugin_logic_fsm_READ_LOW : PerformanceCounterPlugin_logic_fsm_stateReg_string = "READ_LOW ";
      PerformanceCounterPlugin_logic_fsm_CALC_LOW : PerformanceCounterPlugin_logic_fsm_stateReg_string = "CALC_LOW ";
      PerformanceCounterPlugin_logic_fsm_READ_HIGH : PerformanceCounterPlugin_logic_fsm_stateReg_string = "READ_HIGH";
      PerformanceCounterPlugin_logic_fsm_CALC_HIGH : PerformanceCounterPlugin_logic_fsm_stateReg_string = "CALC_HIGH";
      PerformanceCounterPlugin_logic_fsm_CSR_WRITE : PerformanceCounterPlugin_logic_fsm_stateReg_string = "CSR_WRITE";
      default : PerformanceCounterPlugin_logic_fsm_stateReg_string = "?????????";
    endcase
  end
  always @(*) begin
    case(PerformanceCounterPlugin_logic_fsm_stateNext)
      PerformanceCounterPlugin_logic_fsm_BOOT : PerformanceCounterPlugin_logic_fsm_stateNext_string = "BOOT     ";
      PerformanceCounterPlugin_logic_fsm_IDLE : PerformanceCounterPlugin_logic_fsm_stateNext_string = "IDLE     ";
      PerformanceCounterPlugin_logic_fsm_READ_LOW : PerformanceCounterPlugin_logic_fsm_stateNext_string = "READ_LOW ";
      PerformanceCounterPlugin_logic_fsm_CALC_LOW : PerformanceCounterPlugin_logic_fsm_stateNext_string = "CALC_LOW ";
      PerformanceCounterPlugin_logic_fsm_READ_HIGH : PerformanceCounterPlugin_logic_fsm_stateNext_string = "READ_HIGH";
      PerformanceCounterPlugin_logic_fsm_CALC_HIGH : PerformanceCounterPlugin_logic_fsm_stateNext_string = "CALC_HIGH";
      PerformanceCounterPlugin_logic_fsm_CSR_WRITE : PerformanceCounterPlugin_logic_fsm_stateNext_string = "CSR_WRITE";
      default : PerformanceCounterPlugin_logic_fsm_stateNext_string = "?????????";
    endcase
  end
  always @(*) begin
    case(TrapPlugin_logic_harts_0_trap_fsm_stateReg)
      TrapPlugin_logic_harts_0_trap_fsm_RESET : TrapPlugin_logic_harts_0_trap_fsm_stateReg_string = "RESET      ";
      TrapPlugin_logic_harts_0_trap_fsm_RUNNING : TrapPlugin_logic_harts_0_trap_fsm_stateReg_string = "RUNNING    ";
      TrapPlugin_logic_harts_0_trap_fsm_COMPUTE : TrapPlugin_logic_harts_0_trap_fsm_stateReg_string = "COMPUTE    ";
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_EPC : TrapPlugin_logic_harts_0_trap_fsm_stateReg_string = "TRAP_EPC   ";
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_TVAL : TrapPlugin_logic_harts_0_trap_fsm_stateReg_string = "TRAP_TVAL  ";
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_HTVAL : TrapPlugin_logic_harts_0_trap_fsm_stateReg_string = "TRAP_HTVAL ";
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_HTINST : TrapPlugin_logic_harts_0_trap_fsm_stateReg_string = "TRAP_HTINST";
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_TVEC : TrapPlugin_logic_harts_0_trap_fsm_stateReg_string = "TRAP_TVEC  ";
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_WAIT : TrapPlugin_logic_harts_0_trap_fsm_stateReg_string = "TRAP_WAIT  ";
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_APPLY : TrapPlugin_logic_harts_0_trap_fsm_stateReg_string = "TRAP_APPLY ";
      TrapPlugin_logic_harts_0_trap_fsm_XRET_EPC : TrapPlugin_logic_harts_0_trap_fsm_stateReg_string = "XRET_EPC   ";
      TrapPlugin_logic_harts_0_trap_fsm_XRET_APPLY : TrapPlugin_logic_harts_0_trap_fsm_stateReg_string = "XRET_APPLY ";
      TrapPlugin_logic_harts_0_trap_fsm_JUMP : TrapPlugin_logic_harts_0_trap_fsm_stateReg_string = "JUMP       ";
      TrapPlugin_logic_harts_0_trap_fsm_LSU_FLUSH : TrapPlugin_logic_harts_0_trap_fsm_stateReg_string = "LSU_FLUSH  ";
      TrapPlugin_logic_harts_0_trap_fsm_FETCH_FLUSH : TrapPlugin_logic_harts_0_trap_fsm_stateReg_string = "FETCH_FLUSH";
      default : TrapPlugin_logic_harts_0_trap_fsm_stateReg_string = "???????????";
    endcase
  end
  always @(*) begin
    case(TrapPlugin_logic_harts_0_trap_fsm_stateNext)
      TrapPlugin_logic_harts_0_trap_fsm_RESET : TrapPlugin_logic_harts_0_trap_fsm_stateNext_string = "RESET      ";
      TrapPlugin_logic_harts_0_trap_fsm_RUNNING : TrapPlugin_logic_harts_0_trap_fsm_stateNext_string = "RUNNING    ";
      TrapPlugin_logic_harts_0_trap_fsm_COMPUTE : TrapPlugin_logic_harts_0_trap_fsm_stateNext_string = "COMPUTE    ";
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_EPC : TrapPlugin_logic_harts_0_trap_fsm_stateNext_string = "TRAP_EPC   ";
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_TVAL : TrapPlugin_logic_harts_0_trap_fsm_stateNext_string = "TRAP_TVAL  ";
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_HTVAL : TrapPlugin_logic_harts_0_trap_fsm_stateNext_string = "TRAP_HTVAL ";
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_HTINST : TrapPlugin_logic_harts_0_trap_fsm_stateNext_string = "TRAP_HTINST";
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_TVEC : TrapPlugin_logic_harts_0_trap_fsm_stateNext_string = "TRAP_TVEC  ";
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_WAIT : TrapPlugin_logic_harts_0_trap_fsm_stateNext_string = "TRAP_WAIT  ";
      TrapPlugin_logic_harts_0_trap_fsm_TRAP_APPLY : TrapPlugin_logic_harts_0_trap_fsm_stateNext_string = "TRAP_APPLY ";
      TrapPlugin_logic_harts_0_trap_fsm_XRET_EPC : TrapPlugin_logic_harts_0_trap_fsm_stateNext_string = "XRET_EPC   ";
      TrapPlugin_logic_harts_0_trap_fsm_XRET_APPLY : TrapPlugin_logic_harts_0_trap_fsm_stateNext_string = "XRET_APPLY ";
      TrapPlugin_logic_harts_0_trap_fsm_JUMP : TrapPlugin_logic_harts_0_trap_fsm_stateNext_string = "JUMP       ";
      TrapPlugin_logic_harts_0_trap_fsm_LSU_FLUSH : TrapPlugin_logic_harts_0_trap_fsm_stateNext_string = "LSU_FLUSH  ";
      TrapPlugin_logic_harts_0_trap_fsm_FETCH_FLUSH : TrapPlugin_logic_harts_0_trap_fsm_stateNext_string = "FETCH_FLUSH";
      default : TrapPlugin_logic_harts_0_trap_fsm_stateNext_string = "???????????";
    endcase
  end
  always @(*) begin
    case(CsrAccessPlugin_logic_fsm_stateReg)
      CsrAccessPlugin_logic_fsm_IDLE : CsrAccessPlugin_logic_fsm_stateReg_string = "IDLE      ";
      CsrAccessPlugin_logic_fsm_READ : CsrAccessPlugin_logic_fsm_stateReg_string = "READ      ";
      CsrAccessPlugin_logic_fsm_WRITE : CsrAccessPlugin_logic_fsm_stateReg_string = "WRITE     ";
      CsrAccessPlugin_logic_fsm_COMPLETION : CsrAccessPlugin_logic_fsm_stateReg_string = "COMPLETION";
      default : CsrAccessPlugin_logic_fsm_stateReg_string = "??????????";
    endcase
  end
  always @(*) begin
    case(CsrAccessPlugin_logic_fsm_stateNext)
      CsrAccessPlugin_logic_fsm_IDLE : CsrAccessPlugin_logic_fsm_stateNext_string = "IDLE      ";
      CsrAccessPlugin_logic_fsm_READ : CsrAccessPlugin_logic_fsm_stateNext_string = "READ      ";
      CsrAccessPlugin_logic_fsm_WRITE : CsrAccessPlugin_logic_fsm_stateNext_string = "WRITE     ";
      CsrAccessPlugin_logic_fsm_COMPLETION : CsrAccessPlugin_logic_fsm_stateNext_string = "COMPLETION";
      default : CsrAccessPlugin_logic_fsm_stateNext_string = "??????????";
    endcase
  end
  always @(*) begin
    case(LsuPlugin_logic_flusher_stateReg)
      LsuPlugin_logic_flusher_IDLE : LsuPlugin_logic_flusher_stateReg_string = "IDLE      ";
      LsuPlugin_logic_flusher_SB_DRAIN : LsuPlugin_logic_flusher_stateReg_string = "SB_DRAIN  ";
      LsuPlugin_logic_flusher_CMD : LsuPlugin_logic_flusher_stateReg_string = "CMD       ";
      LsuPlugin_logic_flusher_COMPLETION : LsuPlugin_logic_flusher_stateReg_string = "COMPLETION";
      default : LsuPlugin_logic_flusher_stateReg_string = "??????????";
    endcase
  end
  always @(*) begin
    case(LsuPlugin_logic_flusher_stateNext)
      LsuPlugin_logic_flusher_IDLE : LsuPlugin_logic_flusher_stateNext_string = "IDLE      ";
      LsuPlugin_logic_flusher_SB_DRAIN : LsuPlugin_logic_flusher_stateNext_string = "SB_DRAIN  ";
      LsuPlugin_logic_flusher_CMD : LsuPlugin_logic_flusher_stateNext_string = "CMD       ";
      LsuPlugin_logic_flusher_COMPLETION : LsuPlugin_logic_flusher_stateNext_string = "COMPLETION";
      default : LsuPlugin_logic_flusher_stateNext_string = "??????????";
    endcase
  end
  `endif

