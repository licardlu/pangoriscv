`include "core_defs.vh"

module core_alu (
    input  wire [31:0] src1,
    input  wire [31:0] src2,
    input  wire [1:0]  bitwise,      // ALU_BW_*
    input  wire        addsub_en,    // 结果里是否保留加法器输出
    input  wire        revert,       // 1 => src1 + ~src2 + 1 (即减法)
    input  wire        sltx_en,      // 结果里是否保留比较结果
    input  wire        slt_unsigned, // 无符号比较
    input  wire        zero_src2,    // LUI: 强制第二操作数为 0
    output wire [31:0] result,
    output wire        less,         // src1 < src2
    output wire        equal
);
    wire [31:0] src2_mux = zero_src2 ? 32'd0 : src2;
    wire [31:0] src2_pat = revert  ? ~src2_mux : src2_mux;

    // 一个加法器: 减法通过取反 + 进位 1 完成
    wire [31:0] addsub = src1 + src2_pat + {31'd0, revert};

    // 比较: 符号位相同时看差值符号, 否则由操作数符号直接决定
    wire same_sign = (src1[31] == src2_mux[31]);
    assign less  = same_sign ? addsub[31] : (slt_unsigned ? src2_mux[31] : src1[31]);
    assign equal = (src1 == src2_mux);

    reg [31:0] bitwise_out;
    always @(*) begin
        case (bitwise)
            `ALU_BW_XOR: bitwise_out = src1 ^ src2_mux;
            `ALU_BW_OR:  bitwise_out = src1 | src2_mux;
            `ALU_BW_AND: bitwise_out = src1 & src2_mux;
            default:     bitwise_out = 32'd0;
        endcase
    end

    assign result = bitwise_out
                  | (addsub & {32{addsub_en}})
                  | ({31'd0, less} & {32{sltx_en}});
endmodule
