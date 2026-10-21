//=============================================================================
// pangoriscv - rv32 core
// Module : rv32_alu               File : rtl/core/rv32/rv32_alu.v
// Rev    : 1.0                    Date : 2026-10-21
// Brief  : Integer ALU: add/sub, logic, shift, compare (no multiply)
//=============================================================================

// One adder, one shifter and one comparator tree, all selected after the
// operation is already known (rv32_decode).  The old `ex_alu` also decoded the
// instruction inside the ALU and put a second operand mux in front of it; both
// are gone from the S3 path (plan v2 section 3).
module rv32_alu(
    input  wire [3:0]  op,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  [31:0] y,
    output wire        eq,
    output wire        lt,
    output wire        ltu
);
    localparam [3:0] ALU_ADD = 4'd0, ALU_SUB = 4'd1, ALU_AND = 4'd2,
                     ALU_OR  = 4'd3, ALU_XOR = 4'd4, ALU_SLL = 4'd5,
                     ALU_SRL = 4'd6, ALU_SRA = 4'd7, ALU_SLT = 4'd8,
                     ALU_SLTU= 4'd9, ALU_PB  = 4'd10, ALU_PA = 4'd11;

    wire [4:0] shamt = b[4:0];

    assign eq  = (a == b);
    assign lt  = ($signed(a) < $signed(b));
    assign ltu = (a < b);

    always @(*) begin
        case (op)
            ALU_ADD:  y = a + b;
            ALU_SUB:  y = a - b;
            ALU_AND:  y = a & b;
            ALU_OR:   y = a | b;
            ALU_XOR:  y = a ^ b;
            ALU_SLL:  y = a << shamt;
            ALU_SRL:  y = a >> shamt;
            ALU_SRA:  y = $signed(a) >>> shamt;
            ALU_SLT:  y = {31'd0, lt};
            ALU_SLTU: y = {31'd0, ltu};
            ALU_PB:   y = b;
            ALU_PA:   y = a;
            default:  y = a + b;
        endcase
    end
endmodule
