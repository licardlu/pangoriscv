// -----------------------------------------------------------------------------
// core_lsu.v -- 访存字节掩码 / 对齐检查 / 载入扩展 / Store 前递合并
//
// 与 upstream/.../execute/lsu/LsuPlugin.scala 的职责边界一致:
//   本模块只做"地址 -> 掩码/移位/扩展"的纯组合变换, 不含时序, 不含队列。
//   Store Buffer / Cache / 预取是 P12/P13 的内容, V1 直连 RAM。
//
// 为什么需要 fwd_* 这一组输入 (重要, 不要删):
//   数据 RAM 是同步读的。载入在 EX 级发地址、MEM 级收回数据。如果紧邻的前一条
//   指令是 store, 它的写在同一个时钟沿完成, 同步读拿到的仍是旧值 —— 这是真实
//   的 store->load 冒险。这里用一级 store 记录做字节级合并:
//     merged = (fwd 有效且同字) ? 按 fwd_be 把 fwd_data 的字节盖到 RAM 数据上
//                                  : RAM 数据
//   参考设计的对应物是 D$ + Store Buffer 的字节转发 (P12); V1 只做 V1 需要的那一格。
//
// 对齐策略 (V1, 已登记差异 D-05):
//   - 字节: 任意地址
//   - 半字: 要求 addr[0]==0
//   - 字  : 要求 addr[1:0]==0
//   其余产生 misaligned, 由 trap_control 转成精确异常, 不做硬件跨字拆分。
// -----------------------------------------------------------------------------
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
