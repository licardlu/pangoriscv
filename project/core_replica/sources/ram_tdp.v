// -----------------------------------------------------------------------------
// core_ram_tdp.v -- 64 KiB 主存 (8192 x 64, 真双端口 + 字节使能)
//
// 为什么从 32 位宽改成 64 位宽:
//   双发射每拍要喂两条指令。32 位块一拍只给 4 字节, 供给上限就是 1 条/拍,
//   发射宽度再加也没用。64 位块一拍 8 字节, 可以切出两条 32 位指令。
//   参考设计的取指也是 64 位。
//
// 端口分配:
//   A: 取指读 / Store 写 (SoC 仲裁, store 优先)。store 抢占时用 imem_rvalid=0
//      告知对齐器, 对齐器丢弃这笔数据并按同一块号重发。这条机制不能去掉:
//      没有它取指会把别的地址的数据当指令缓存起来 (V1 实测 pc 撞非法指令)。
//   B: Load 只读, 64 位字读出后由 SoC 按地址 bit[2] 选高低半字。
//
// 初始化: $readmemh 读 firmware.hex (每行一个 64 位字)。
// -----------------------------------------------------------------------------
module core_ram_tdp #(
    parameter WORDS = 8192,
    parameter AW    = 13
) (
    input  wire            clk,

    // 端口 A: 取指读 / Store 写 (8 字节粒度)
    input  wire [AW-1:0]   addr_a,
    input  wire            we_a,
    input  wire [7:0]      be_a,
    input  wire [63:0]     wdata_a,
    output reg  [63:0]     rdata_a,

    // 端口 B: Load 只读
    input  wire [AW-1:0]   addr_b,
    output reg  [63:0]     rdata_b
);
    reg [63:0] mem [0:WORDS-1];

    initial begin
        $readmemh("firmware.hex", mem);
    end

    always @(posedge clk) begin
        if (we_a) begin
            if (be_a[0]) mem[addr_a][7:0]   <= wdata_a[7:0];
            if (be_a[1]) mem[addr_a][15:8]  <= wdata_a[15:8];
            if (be_a[2]) mem[addr_a][23:16] <= wdata_a[23:16];
            if (be_a[3]) mem[addr_a][31:24] <= wdata_a[31:24];
            if (be_a[4]) mem[addr_a][39:32] <= wdata_a[39:32];
            if (be_a[5]) mem[addr_a][47:40] <= wdata_a[47:40];
            if (be_a[6]) mem[addr_a][55:48] <= wdata_a[55:48];
            if (be_a[7]) mem[addr_a][63:56] <= wdata_a[63:56];
        end
        rdata_a <= mem[addr_a];
    end

    always @(posedge clk) begin
        rdata_b <= mem[addr_b];
    end
endmodule
