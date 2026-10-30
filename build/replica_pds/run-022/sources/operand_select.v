// -----------------------------------------------------------------------------
// core_operand_select.v -- 前递选择 (4 个候选源, 按程序年龄选最近的)
//
// 对应 upstream ExecuteLanePlugin 的 bypass 逻辑, 规则是
// "选择该消费者之前最近的一次有效写入", 不是固定 lane 优先级。
//
// 年龄顺序 (最年轻 -> 最老):
//   exmem lane1 > exmem lane0 > memwb lane1 > memwb lane0 > 寄存器堆
//
// 为什么不能写成"lane1 永远优先于 lane0":
//   同一对里 lane1 确实比 lane0 年轻, 但更早那一对的 lane0 比这一对的 lane1 老。
//   跨组比较必须整组按年龄排序, 否则年轻指令会拿到更老的值。
//
// 为什么 EX/MEM 的源要排除 Load:
//   Load 的数据到 MEM 结束才有效, EX 级不存在。让 Load 当选源会把地址当数据。
// -----------------------------------------------------------------------------
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
