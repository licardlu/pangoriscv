`include "core_defs.vh"

module core_lsu (
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire [1:0]  size,
    input  wire        uns,
    input  wire [31:0] rdata,

    // 上一拍 store 的前递记录
    input  wire        fwd_valid,
    input  wire [29:0] fwd_word,
    input  wire [3:0]  fwd_be,
    input  wire [31:0] fwd_data,

    output reg  [3:0]  be,
    output reg  [31:0] wdata_sh,
    output reg  [31:0] rdata_ext,
    output reg         misaligned
);
    wire [1:0] off = addr[1:0];

    // ------------------------------ store 侧 ---------------------------------
    always @(*) begin
        case (size)
            `MSIZE_B: be = 4'b0001 << off;
            `MSIZE_H: be = 4'b0011 << off;
            default:  be = 4'b1111;
        endcase
        wdata_sh = wdata << {off, 3'b000};
        case (size)
            `MSIZE_B: misaligned = 1'b0;
            `MSIZE_H: misaligned = addr[0];
            default:  misaligned = (addr[1:0] != 2'b00);
        endcase
    end

    // ------------------------------ load 侧 ----------------------------------
    wire same_word = (fwd_word == addr[31:2]);

    reg [31:0] merged;
    integer k;
    always @(*) begin
        merged = rdata;
        if (fwd_valid && same_word) begin
            for (k = 0; k < 4; k = k + 1)
                if (fwd_be[k]) merged[8*k +: 8] = fwd_data[8*k +: 8];
        end
    end

    wire [31:0] rdata_sh   = merged >> {off, 3'b000};
    wire [7:0]  rdata_byte = rdata_sh[7:0];
    wire [15:0] rdata_half = rdata_sh[15:0];

    always @(*) begin
        case (size)
            `MSIZE_B: rdata_ext = uns ? {24'd0, rdata_byte} : {{24{rdata_byte[7]}}, rdata_byte};
            `MSIZE_H: rdata_ext = uns ? {16'd0, rdata_half} : {{16{rdata_half[15]}}, rdata_half};
            default:  rdata_ext = merged;
        endcase
    end
endmodule
