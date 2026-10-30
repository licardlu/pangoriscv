// -----------------------------------------------------------------------------
// core_ram_tdp.v -- 64 KiB 主存 (16384 x 32, 真双端口 + 字节使能)
//
// 端口分配 (V1 的关键决定, 不要改回"store 抢取指口"):
//   A: 只读, 专供取指。绝不被 store 抢占 —— 一旦某一拍被抢, 取指单元拿到的
//      就是别的地址的数据, 而它无法分辨, 会把这笔错误数据当成指令缓存起来。
//      实测后果: 取指队列里出现 0x00000001, pc 撞上非法指令 (mcause=2)。
//   B: Load 读 / Store 写 复用 (同一拍只会有一个方向, 见 pango_cpu 的 hold_front)。
//
// 为什么不用简单双端口:
//   取指与 Load 在同一拍都可能要读, Store 在 MEM 拍要写。三者两两重叠, 所以必须
//   两个独立读口 + 一路写。TDP 综合成两块 16Kx32, 与参考 DRM=34 同量级。
//
// 初始化: $readmemh 读 firmware.hex (由 tools/core_replica/elf2hex.py 生成)。
// -----------------------------------------------------------------------------
module core_ram_tdp #(
    parameter WORDS = 16384,
    parameter AW    = 14
) (
    input  wire            clk,

    // 端口 A: 取指读 / Store 写 (SoC 仲裁, store 优先)
    input  wire [AW-1:0]   addr_a,
    input  wire            we_a,
    input  wire [3:0]      be_a,
    input  wire [31:0]     wdata_a,
    output reg  [31:0]     rdata_a,

    // 端口 B: Load 只读
    input  wire [AW-1:0]   addr_b,
    output reg  [31:0]     rdata_b
);
    reg [31:0] mem [0:WORDS-1];

    initial begin
        $readmemh("firmware.hex", mem);
    end

    always @(posedge clk) begin
        if (we_a) begin
            if (be_a[0]) mem[addr_a][7:0]   <= wdata_a[7:0];
            if (be_a[1]) mem[addr_a][15:8]  <= wdata_a[15:8];
            if (be_a[2]) mem[addr_a][23:16] <= wdata_a[23:16];
            if (be_a[3]) mem[addr_a][31:24] <= wdata_a[31:24];
        end
        rdata_a <= mem[addr_a];
    end

    always @(posedge clk) begin
        rdata_b <= mem[addr_b];
    end
endmodule
