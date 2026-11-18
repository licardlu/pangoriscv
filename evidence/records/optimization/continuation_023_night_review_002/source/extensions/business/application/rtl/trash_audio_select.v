// Standalone answer-to-voice selector for the first peripheral bring-up.
// key_index is zero-based: 0..3 correspond to buttons 1..4.  The temporary
// known-good answer is button 1 (recyclable).  Asset IDs follow app.h:
// 2 = CORRECT.WAV, 3 = WRONG.WAV.  This module only issues a request; it does
// not generate PCM/I2S or drive a physical audio output.
module trash_audio_select (
    input  wire       clk,
    input  wire       rst,
    input  wire       key_valid,
    input  wire [1:0] key_index,
    output reg        voice_valid,
    output reg  [2:0] voice_asset_id,
    output reg        answer_correct
);

    always @(posedge clk) begin
        if (rst) begin
            voice_valid   <= 1'b0;
            voice_asset_id <= 3'd0;
            answer_correct <= 1'b0;
        end else begin
            // Default to a one-cycle request pulse.
            voice_valid <= 1'b0;
            if (key_valid) begin
                voice_valid    <= 1'b1;
                answer_correct <= (key_index == 2'd0);
                voice_asset_id <= (key_index == 2'd0) ? 3'd2 : 3'd3;
            end
        end
    end

endmodule
