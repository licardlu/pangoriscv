// Answer assets 2/3 are followed by the latched correct-bin phrase (4..7).
// HDMI MS7210 must separately be configured for the same I2S format/48 kHz.
// This module deliberately does not invent or write MS7210 register values.
module trash_voice_i2s #(
    parameter integer CLK_HZ = 50000000,
    parameter ROM_FILE = "../../extensions/business/application/assets/audio_rom/voice_pcm8.hex"
)(
    input wire clk, rst,
    input wire request_valid,
    input wire [3:0] request_asset_id,
    input wire [1:0] request_bin_index,
    input tri0 media_active,media_valid,
    input tri0 mute_voice,
    input tri0 [31:0] media_pcm,
    output wire media_ready,
    output wire audio_busy,
    output wire playback_done,
    output wire i2s_bclk, i2s_lrclk, i2s_data
);
    wire sample_ready, sample_valid, sample_last, rom_busy, frame_active, clip_done, tx_ready;
    wire [15:0] sample_pcm;
    reg suffix_pending;
    reg [3:0] suffix_asset;
    wire append_suffix = clip_done && suffix_pending;
    wire player_request_valid = request_valid || append_suffix;
    wire [3:0] player_request_asset = request_valid ? request_asset_id : suffix_asset;
    always @(posedge clk) begin
        if(rst || media_active || mute_voice) begin suffix_pending<=0; suffix_asset<=0; end
        else if(request_valid && request_asset_id>=1 && request_asset_id<=13) begin
            suffix_pending <= request_asset_id==2 || request_asset_id==3 || request_asset_id>=8;
            suffix_asset <= 4'd4 + {2'b0,request_bin_index};
        end else if(append_suffix) suffix_pending<=0;
    end
    trash_voice_rom_player #(.ROM_FILE(ROM_FILE)) player (
        .clk(clk), .rst(rst||media_active||mute_voice), .request_valid(player_request_valid&&!media_active&&!mute_voice),
        .request_asset_id(player_request_asset), .sample_ready(sample_ready),
        .sample_valid(sample_valid), .sample_pcm(sample_pcm),
        .sample_last(sample_last), .busy(rom_busy));
    trash_i2s_tx #(.CLK_HZ(CLK_HZ), .SAMPLE_HZ(48000)) transmitter (
        .clk(clk), .rst(rst), .sample_valid(media_active?media_valid:sample_valid),
        .sample_pcm(media_active?media_pcm[15:0]:sample_pcm),
        .stereo(media_active),.sample_right(media_pcm[31:16]),
        .sample_last(!media_active&&sample_last), .sample_ready(tx_ready),
        .bclk(i2s_bclk), .lrclk(i2s_lrclk), .sdout(i2s_data),
        .frame_active(frame_active), .playback_done(clip_done));
    assign audio_busy = rom_busy || frame_active || suffix_pending;
    assign sample_ready=tx_ready&&!media_active;
    assign media_ready=tx_ready&&media_active;
    assign playback_done = clip_done && !suffix_pending;
endmodule
