// Raw YOLO labels: 0 biodegradable, 1 cardboard, 2 glass, 3 metal,
// 4 paper, 5 plastic. This model has no trained hazardous/other class.
// Bin codes follow the user's keys: 1 green=organic, 2 red=hazardous,
// 3 gray=other, 4 blue=recyclable; 0 disables a mapping.
// FOUR_BIN_CLASSES=1 instead accepts only 0 kitchen, 1 recyclable,
// 2 hazardous, 3 other -> business codes 1,4,2,3. Select together with weights,
// firmware and OSD; this switch alone does not deploy the new trained model.
module yolo_class_to_bin #(
    // Must match the deployed model and the frontend's color schema.
    parameter integer FOUR_BIN_CLASSES=0,
    parameter [2:0] CLASS0_BIN=3'd1,
    parameter [2:0] CLASS1_BIN=3'd4,
    parameter [2:0] CLASS2_BIN=FOUR_BIN_CLASSES ? 3'd2 : 3'd4,
    parameter [2:0] CLASS3_BIN=FOUR_BIN_CLASSES ? 3'd3 : 3'd4,
    parameter [2:0] CLASS4_BIN=FOUR_BIN_CLASSES ? 3'd0 : 3'd4,
    parameter [2:0] CLASS5_BIN=FOUR_BIN_CLASSES ? 3'd0 : 3'd4
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
