`timescale 1ns/1ps
module trash_audio_select_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    reg key_valid = 0;
    reg [1:0] key_index = 0;
    wire voice_valid;
    wire [2:0] voice_asset_id;
    wire answer_correct;

    trash_audio_select dut (
        .clk(clk), .rst(rst), .key_valid(key_valid), .key_index(key_index),
        .voice_valid(voice_valid), .voice_asset_id(voice_asset_id),
        .answer_correct(answer_correct)
    );

    task press(input [1:0] idx, input [2:0] expected_asset, input expected_correct);
        begin
            @(negedge clk); key_index = idx; key_valid = 1;
            @(posedge clk); #1;
            if (voice_valid !== 1'b1 || voice_asset_id !== expected_asset ||
                answer_correct !== expected_correct)
                $fatal(1, "key %0d: valid=%b asset=%0d correct=%b", idx+1,
                       voice_valid, voice_asset_id, answer_correct);
            @(negedge clk); key_valid = 0;
            @(posedge clk); #1;
            if (voice_valid !== 1'b0)
                $fatal(1, "voice_valid did not return low after request");
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        @(negedge clk); rst = 0;
        press(2'd0, 3'd2, 1'b1);
        press(2'd1, 3'd3, 1'b0);
        press(2'd2, 3'd3, 1'b0);
        press(2'd3, 3'd3, 1'b0);
        $display("PASS: keys 1..4 select CORRECT(2), WRONG(3), WRONG(3), WRONG(3)");
        $finish;
    end
endmodule
