module core_operand_select (
    input  wire [31:0] rf_data,
    input  wire [4:0]  rf_addr,

    // 最新: EX/MEM lane1
    input  wire        s0_we,
    input  wire [4:0]  s0_rd,
    input  wire [31:0] s0_data,
    // EX/MEM lane0
    input  wire        s1_we,
    input  wire [4:0]  s1_rd,
    input  wire [31:0] s1_data,
    // MEM/WB lane1
    input  wire        s2_we,
    input  wire [4:0]  s2_rd,
    input  wire [31:0] s2_data,
    // MEM/WB lane0
    input  wire        s3_we,
    input  wire [4:0]  s3_rd,
    input  wire [31:0] s3_data,

    output wire [31:0] data
);
    wire hit0 = s0_we && (rf_addr != 5'd0) && (s0_rd == rf_addr);
    wire hit1 = s1_we && (rf_addr != 5'd0) && (s1_rd == rf_addr);
    wire hit2 = s2_we && (rf_addr != 5'd0) && (s2_rd == rf_addr);
    wire hit3 = s3_we && (rf_addr != 5'd0) && (s3_rd == rf_addr);

    assign data = hit0 ? s0_data
                : hit1 ? s1_data
                : hit2 ? s2_data
                : hit3 ? s3_data
                :        rf_data;
endmodule
