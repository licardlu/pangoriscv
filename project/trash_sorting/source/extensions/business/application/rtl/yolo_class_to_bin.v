// Raw YOLO labels: 0 biodegradable, 1 cardboard, 2 glass, 3 metal,
// 4 paper, 5 plastic. This model has no trained hazardous/other class.
// Bin codes follow the user's keys: 1 green=organic, 2 red=hazardous,
// 3 gray=other, 4 blue=recyclable; 0 disables a mapping.
// Keep this module independent of key/servo testing. Configure the six
// parameters only when the deployed label policy or model has been checked.
module yolo_class_to_bin #(
    parameter [2:0] CLASS0_BIN=3'd1,
    parameter [2:0] CLASS1_BIN=3'd4,
    parameter [2:0] CLASS2_BIN=3'd4,
    parameter [2:0] CLASS3_BIN=3'd4,
    parameter [2:0] CLASS4_BIN=3'd4,
    parameter [2:0] CLASS5_BIN=3'd4
)(
    input wire result_valid,
    input wire [7:0] result_class_id,
    output reg bin_valid,
    output reg [2:0] bin_code
);
    reg [2:0] configured_bin;
    always @(*) begin
        case(result_class_id)
            8'd0:configured_bin=CLASS0_BIN;
            8'd1:configured_bin=CLASS1_BIN;
            8'd2:configured_bin=CLASS2_BIN;
            8'd3:configured_bin=CLASS3_BIN;
            8'd4:configured_bin=CLASS4_BIN;
            8'd5:configured_bin=CLASS5_BIN;
            default:configured_bin=3'd0;
        endcase
        bin_valid=result_valid && configured_bin>=1 && configured_bin<=4;
        bin_code=bin_valid?configured_bin:3'd0;
    end
endmodule
