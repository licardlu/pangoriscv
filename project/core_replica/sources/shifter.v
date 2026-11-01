`include "core_defs.vh"

module core_shifter (
    input  wire [31:0] data,
    input  wire [4:0]  shamt,
    input  wire [1:0]  mode,     // 0=SLL 1=SRL 2=SRA
    output wire [31:0] result
);
    wire [31:0] sll = data << shamt;
    wire [31:0] srl = data >> shamt;
    // 算术右移: 逻辑右移后把高位补回符号
    wire [31:0] sra_mask = ~(32'hFFFF_FFFF >> shamt);
    wire [31:0] sra = srl | (data[31] ? sra_mask : 32'd0);

    reg [31:0] r;
    always @(*) begin
        case (mode)
            2'd0:    r = sll;
            2'd1:    r = srl;
            default: r = sra;
        endcase
    end
    assign result = r;
endmodule
