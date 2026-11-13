// I2S stereo transmitter using a system-clock enable, no fabric clock domain.
// 32 BCLK periods/channel; signed 16-bit mono is copied to both channels.
// Fractional BCLK: exactly SAMPLE_HZ*64 on average from CLK_HZ (50 MHz
// default).  Edge quantization is <= one sys_clk period.  For a codec that
// requires low-jitter MCLK, use an audio PLL instead of this CE clock source.
module trash_i2s_tx #(
    parameter integer CLK_HZ = 50000000,
    parameter integer SAMPLE_HZ = 48000
)(
    input wire clk, rst,
    input wire sample_valid,
    input wire [15:0] sample_pcm,
    input wire sample_last,
    output wire sample_ready,
    output reg bclk, lrclk, sdout,
    output reg frame_active,
    output reg playback_done
);
    localparam integer EDGE_HZ = SAMPLE_HZ * 128;
    reg [31:0] phase;
    wire [32:0] phase_sum = {1'b0, phase} + EDGE_HZ;
    wire edge_tick = phase_sum >= CLK_HZ;
    reg [5:0] bit_index;
    reg [15:0] frame;
    reg frame_last;
    wire [5:0] next_bit = bit_index + 1'b1;
    // A sample is consumed at the falling edge starting the left channel.
    assign sample_ready = edge_tick && bclk && bit_index == 63;
    always @(posedge clk) begin
        if(rst) begin
            phase <= 0; bclk <= 0; lrclk <= 1; sdout <= 0;
            bit_index <= 63; frame <= 0; frame_active <= 0;
            frame_last <= 0; playback_done <= 0;
        end else begin
            playback_done <= 0;
            if(edge_tick) begin
                phase <= phase_sum - CLK_HZ;
                bclk <= ~bclk;
                if(bclk) begin
                    bit_index <= next_bit;
                    lrclk <= next_bit >= 32;
                    sdout <= 0;
                    if(next_bit == 0) begin
                        if(frame_active && frame_last) playback_done <= 1;
                        frame <= sample_valid ? sample_pcm : 16'b0;
                        frame_active <= sample_valid;
                        frame_last <= sample_valid && sample_last;
                    end else if(next_bit >= 1 && next_bit <= 16)
                        sdout <= frame[16-next_bit];
                    else if(next_bit >= 33 && next_bit <= 48)
                        sdout <= frame[48-next_bit];
                end
            end else phase <= phase_sum[31:0];
        end
    end
endmodule
