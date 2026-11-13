// Integration boundary: request asset 1/2/3 and obtain physical I2S signals.
// HDMI MS7210 must separately be configured for the same I2S format/48 kHz.
// This module deliberately does not invent or write MS7210 register values.
module trash_voice_i2s #(
    parameter integer CLK_HZ = 50000000,
    parameter ROM_FILE = "../../extensions/business/application/assets/audio_rom/voice_pcm8.hex"
)(
    input wire clk, rst,
    input wire request_valid,
    input wire [2:0] request_asset_id,
    output wire audio_busy,
    output wire playback_done,
    output wire i2s_bclk, i2s_lrclk, i2s_data
);
    wire sample_ready, sample_valid, sample_last, rom_busy, frame_active;
    wire [15:0] sample_pcm;
    trash_voice_rom_player #(.ROM_FILE(ROM_FILE)) player (
        .clk(clk), .rst(rst), .request_valid(request_valid),
        .request_asset_id(request_asset_id), .sample_ready(sample_ready),
        .sample_valid(sample_valid), .sample_pcm(sample_pcm),
        .sample_last(sample_last), .busy(rom_busy));
    trash_i2s_tx #(.CLK_HZ(CLK_HZ), .SAMPLE_HZ(48000)) transmitter (
        .clk(clk), .rst(rst), .sample_valid(sample_valid), .sample_pcm(sample_pcm),
        .sample_last(sample_last), .sample_ready(sample_ready),
        .bclk(i2s_bclk), .lrclk(i2s_lrclk), .sdout(i2s_data),
        .frame_active(frame_active), .playback_done(playback_done));
    assign audio_busy = rom_busy || frame_active;
endmodule
