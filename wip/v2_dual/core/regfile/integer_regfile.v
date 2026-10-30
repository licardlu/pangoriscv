module core_regfile (
    input  wire        clk,
    input  wire        rst,

    // 读口 (lane0: ra1/ra2, lane1: ra3/ra4)
    input  wire [4:0]  ra1,
    input  wire [4:0]  ra2,
    input  wire [4:0]  ra3,
    input  wire [4:0]  ra4,
    output reg  [31:0] rd1,
    output reg  [31:0] rd2,
    output reg  [31:0] rd3,
    output reg  [31:0] rd4,

    // 写口 0 (较老)
    input  wire        we0,
    input  wire [4:0]  wa0,
    input  wire [31:0] wd0,
    // 写口 1 (较年轻)
    input  wire        we1,
    input  wire [4:0]  wa1,
    input  wire [31:0] wd1
);
    reg [31:0] mem [0:31];
    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1) mem[i] = 32'd0;
    end

    wire wr0 = we0 && (wa0 != 5'd0);
    wire wr1 = we1 && (wa1 != 5'd0);

    // 写透选择: 写口 1 更年轻, 优先
    function [31:0] rd_sel;
        input [4:0] a;
        begin
            if (wr1 && (wa1 == a))      rd_sel = wd1;
            else if (wr0 && (wa0 == a)) rd_sel = wd0;
            else                        rd_sel = (a == 5'd0) ? 32'd0 : mem[a];
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            rd1 <= 32'd0;
            rd2 <= 32'd0;
            rd3 <= 32'd0;
            rd4 <= 32'd0;
        end else begin
            rd1 <= rd_sel(ra1);
            rd2 <= rd_sel(ra2);
            rd3 <= rd_sel(ra3);
            rd4 <= rd_sel(ra4);
        end
    end

    always @(posedge clk) begin
        if (wr0) mem[wa0] <= wd0;
        if (wr1) mem[wa1] <= wd1;
    end
endmodule
