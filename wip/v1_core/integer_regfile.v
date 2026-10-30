module core_regfile (
    input  wire        clk,
    input  wire        rst,

    // 读口
    input  wire [4:0]  ra1,
    input  wire [4:0]  ra2,
    output reg  [31:0] rd1,
    output reg  [31:0] rd2,

    // 写口 0
    input  wire        we0,
    input  wire [4:0]  wa0,
    input  wire [31:0] wd0,
    // 写口 1
    input  wire        we1,
    input  wire [4:0]  wa1,
    input  wire [31:0] wd1
);
    reg [31:0] mem [0:31];
    integer i;

    // 复位只清控制所需的 x0, 其余寄存器不强制清零。
    // (RISC-V 不要求复位寄存器堆; CoreMark 的 .bss 清零由软件完成)
    initial begin
        for (i = 0; i < 32; i = i + 1) mem[i] = 32'd0;
    end

    wire wr0 = we0 && (wa0 != 5'd0);
    wire wr1 = we1 && (wa1 != 5'd0);

    always @(posedge clk) begin
        if (rst) begin
            rd1 <= 32'd0;
            rd2 <= 32'd0;
        end else begin
            // 同址同拍写透: 写口 1 比写口 0 年轻, 优先
            if (wr0 && (wa0 == ra1) && !(wr1 && (wa1 == ra1)))     rd1 <= wd0;
            else if (wr1 && (wa1 == ra1))                          rd1 <= wd1;
            else                                                   rd1 <= (ra1 == 5'd0) ? 32'd0 : mem[ra1];

            if (wr0 && (wa0 == ra2) && !(wr1 && (wa1 == ra2)))     rd2 <= wd0;
            else if (wr1 && (wa1 == ra2))                          rd2 <= wd1;
            else                                                   rd2 <= (ra2 == 5'd0) ? 32'd0 : mem[ra2];
        end
    end

    always @(posedge clk) begin
        if (wr0) mem[wa0] <= wd0;
        if (wr1) mem[wa1] <= wd1;
    end
endmodule
