// Supplemental MS7210 PCM/I2S initialization, run AFTER video initialization.
// Hold rstn low until the existing video init completes. ENABLE=0 bypasses
// this controller without I2C traffic. Inputs/outputs use the same transaction
// contract as ms7210_ctl: w_r=1 writes, w_r=0 reads, trigger is a one-cycle
// pulse, and busy must rise and fall before another transaction is launched.
//
// Register identities and masked field values were checked against the
// original MS7210 Linux driver by Andrey Mitrofanov (2023):
// https://github.com/avmwww/ms7210-linux-driver
// commit d7632336b5369c3241256108e336310d018f8259, ms7210.c/ms7210.h.
// Its C header says GPL-2; its repository LICENSE contains GPL-3.0 text.
// The unmodified source and LICENSE snapshots are retained with provenance.
// This is an independently written transaction FSM, not a copied driver.
// Configuration: PCM, I2S pad mode, 48 kHz family, 16-bit, two channels.
// That driver does not document I2S slot/BCLK ratios; do not infer an extra
// MCLK or a proven 32/64-fs requirement from this register sequence.
module ms7210_audio_init #(
    parameter integer ENABLE=1
)(
    input wire clk,
    input wire rstn,
    input wire busy,
    input wire [7:0] data_out,
    input wire byte_over,
    output reg [15:0] addr,
    output reg [7:0] data_in,
    output reg w_r,
    output reg iic_trig,
    output reg init_over,
    output wire [7:0] device_id
);
    assign device_id=8'hb2;
    localparam [3:0] LOAD=0,READ_LAUNCH=1,READ_ACCEPT=2,READ_WAIT=3,
        WRITE_LAUNCH=4,WRITE_ACCEPT=5,WRITE_WAIT=6,DONE=7;
    localparam [4:0] LAST_STEP=29;
    // Numeric addresses are independently checked against the pinned header
    // by tools/test_ms7210_register_contract.py.
    localparam [15:0] MS7210_HDMI_TX_MISC_HDMI_RST_REG=16'h000b;
    localparam [15:0] MS7210_HDMI_TX_MISC_HDMI_CLK_REG=16'h0006;
    localparam [15:0] MS7210_HDMI_TX_MISC_AUD_CTRL=16'h0048;
    localparam [15:0] MS7210_CLK_CTRL5_REG=16'h0008;
    localparam [15:0] MS7210_PINMUX_REG=16'h00a5;
    localparam [15:0] MS7210_HDMI_TX_AUDIO_CFG_REG=16'h0530;
    localparam [15:0] MS7210_HDMI_TX_SHELL_DVI_REG=16'h0503;
    localparam [15:0] MS7210_HDMI_TX_AUDIO_RATE_REG=16'h0531;
    localparam [15:0] MS7210_HDMI_TX_AUDIO_CFG_I2S_REG=16'h0535;
    localparam [15:0] MS7210_HDMI_TX_AUDIO_CH_EN_REG=16'h0532;
    localparam [15:0] MS7210_HDMI_TX_SHELL_VOLUME_CFG0_REG=16'h0570;
    localparam [15:0] MS7210_HDMI_TX_SHELL_CTRL_REG=16'h050e;
    localparam [15:0] MS7210_HDMI_TX_SHELL_INFO_TYPE_REG=16'h050a;
    localparam [15:0] MS7210_HDMI_TX_SHELL_INFO_VER_REG=16'h0509;
    localparam [15:0] MS7210_HDMI_TX_SHELL_INFO_LEN_REG=16'h050b;
    localparam [15:0] MS7210_HDMI_TX_SHELL_INFO_PACK_REG=16'h050d;
    localparam [15:0] MS7210_HDMI_TX_SHELL_AVMUTE_REG=16'h0507;
    reg [3:0] state;
    reg [4:0] step;

    // {address, write mask, field value}. Full-mask entries are FIFO/header
    // writes. Partial-mask entries are always read-modify-write transactions.
    function [31:0] operation;
        input [4:0] index;
        begin
            case(index)
                0:operation={MS7210_HDMI_TX_MISC_HDMI_RST_REG,8'h11,8'h00}; // Assert video/audio resets.
                1:operation={MS7210_HDMI_TX_MISC_HDMI_CLK_REG,8'h11,8'h11}; // Video/audio clock enable.
                2:operation={MS7210_HDMI_TX_MISC_AUD_CTRL,8'h0f,8'h00}; // Audio misc control.
                3:operation={MS7210_CLK_CTRL5_REG,8'h03,8'h00}; // Audio clock from pad.
                4:operation={MS7210_PINMUX_REG,8'h18,8'h00}; // I2S rather than SPDIF.
                5:operation={MS7210_HDMI_TX_AUDIO_CFG_REG,8'h01,8'h00}; // Ordinary PCM sample mode.
                6:operation={MS7210_HDMI_TX_SHELL_DVI_REG,8'h01,8'h00}; // HDMI rather than DVI.
                7:operation={MS7210_HDMI_TX_AUDIO_RATE_REG,8'h80,8'h80}; // Audio enable.
                8:operation={MS7210_HDMI_TX_AUDIO_RATE_REG,8'h7f,8'h04}; // 44.1/48 kHz family divider.
                9:operation={MS7210_HDMI_TX_AUDIO_CFG_I2S_REG,8'h30,8'h10}; // 16-bit samples.
               10:operation={MS7210_HDMI_TX_AUDIO_CH_EN_REG,8'h0f,8'h01}; // One I2S lane / two channels.
               11:operation={MS7210_HDMI_TX_SHELL_VOLUME_CFG0_REG,8'h01,8'h01}; // Shell volume configuration.
               12:operation={MS7210_HDMI_TX_MISC_HDMI_RST_REG,8'h11,8'h11}; // Release video/audio reset.
               13:operation={MS7210_HDMI_TX_SHELL_CTRL_REG,8'h20,8'h00}; // Disable Audio InfoFrame.
               14:operation={MS7210_HDMI_TX_SHELL_INFO_TYPE_REG,8'hff,8'h84}; // Audio InfoFrame type.
               15:operation={MS7210_HDMI_TX_SHELL_INFO_VER_REG,8'hff,8'h01}; // Version 1.
               16:operation={MS7210_HDMI_TX_SHELL_INFO_LEN_REG,8'hff,8'h0a}; // Ten payload bytes.
               17:operation={MS7210_HDMI_TX_SHELL_INFO_PACK_REG,8'hff,8'h70}; // Checksum: -(84+01+0a+01).
               18:operation={MS7210_HDMI_TX_SHELL_INFO_PACK_REG,8'hff,8'h01}; // Two-channel count minus one.
               19,20,21,22,23,24,25,26,27:
                  operation={MS7210_HDMI_TX_SHELL_INFO_PACK_REG,8'hff,8'h00}; // Stream-derived/default fields.
               28:operation={MS7210_HDMI_TX_SHELL_CTRL_REG,8'h20,8'h20}; // Enable, preserve AVI bit 6.
               29:operation={MS7210_HDMI_TX_SHELL_AVMUTE_REG,8'h04,8'h00}; // Unmute audio only.
               default:operation={16'h0000,8'hff,8'h00};
            endcase
        end
    endfunction
    wire [31:0] op=operation(step);
    // byte_over can precede the end of a bus transaction. Completion is
    // deliberately based on busy after seeing it asserted, as in the video
    // controller. data_out is stable by that completion edge.
    always @(posedge clk) begin
        if(!rstn) begin
            state<=LOAD;step<=0;addr<=0;data_in<=0;
            w_r<=0;iic_trig<=0;init_over<=0;
        end else begin
            iic_trig<=0;
            case(state)
                LOAD:begin
                    if(ENABLE==0) begin init_over<=1;state<=DONE;end
                    else begin
                        addr<=op[31:16];
                        if(op[15:8]==8'hff) begin
                            w_r<=1;data_in<=op[7:0];state<=WRITE_LAUNCH;
                        end else begin
                            w_r<=0;state<=READ_LAUNCH;
                        end
                    end
                end
                READ_LAUNCH:if(!busy) begin iic_trig<=1;state<=READ_ACCEPT;end
                READ_ACCEPT:if(busy) state<=READ_WAIT;
                READ_WAIT:if(!busy) begin
                    data_in<=(data_out & ~op[15:8]) | (op[7:0] & op[15:8]);
                    w_r<=1;state<=WRITE_LAUNCH;
                end
                WRITE_LAUNCH:if(!busy) begin iic_trig<=1;state<=WRITE_ACCEPT;end
                WRITE_ACCEPT:if(busy) state<=WRITE_WAIT;
                WRITE_WAIT:if(!busy) begin
                    if(step==LAST_STEP) begin init_over<=1;state<=DONE;end
                    else begin step<=step+1'b1;state<=LOAD;end
                end
                DONE:begin init_over<=1;end
                default:begin state<=LOAD;step<=0;init_over<=0;end
            endcase
        end
    end
endmodule
