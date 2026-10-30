`include "core_defs.vh"

module core_operand_select (
    input  wire [31:0] rf_data,
    input  wire [4:0]  rf_addr,

    input  wire        exmem_we,
    input  wire [4:0]  exmem_rd,
    input  wire [31:0] exmem_data,

    input  wire        memwb_we,
    input  wire [4:0]  memwb_rd,
    input  wire [31:0] memwb_data,

    output wire [31:0] data
);
    wire hit_exmem = exmem_we && (exmem_rd != 5'd0) && (exmem_rd == rf_addr);
    wire hit_memwb = memwb_we && (memwb_rd != 5'd0) && (memwb_rd == rf_addr);

    assign data = hit_exmem ? exmem_data
                : hit_memwb ? memwb_data
                : rf_data;
endmodule
