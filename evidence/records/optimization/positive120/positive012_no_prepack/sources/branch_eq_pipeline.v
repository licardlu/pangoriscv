// Retimed VexiiRiscv-derived source comparison. Upstream MIT notice is retained
// in provenance/licenses/VexiiRiscv-MIT.txt and THIRD_PARTY_NOTICES.md.
module branch_eq_pipeline(
  input wire clk,
  input wire enable,
  input wire src1_upper,
  input wire [1:0] src2_ctrl,
  input wire [31:0] rs1, rs2, uop, pc,
  output reg eq
);
  reg [31:0] a,b;
  always @* begin
    a=32'hxxxxxxxx;
    case(src1_upper)
      1'b0:a=rs1;
      default:a={uop[31:12],12'b0};
    endcase
    b=32'hxxxxxxxx;
    case(src2_ctrl)
      2'd0:b=rs2;
      2'd1:b={{20{uop[31]}},uop[31:20]};
      2'd2:b=pc;
      default:begin end
    endcase
  end
  // No reset: mirrors the existing operand data registers, not lane-valid.
  always @(posedge clk) if(enable) eq <= (a==b);
endmodule
