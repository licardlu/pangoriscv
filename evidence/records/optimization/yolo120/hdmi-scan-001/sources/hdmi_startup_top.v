`timescale 1ns/1ps
`default_nettype none
// Independent HDMI bring-up. No CPU, DDR, camera, or model is required.
module hdmi_startup_top #(
    parameter integer SYS_HZ = 27000000,
    parameter integer REPORT_CYCLES = 270000,
    parameter integer SCAN_CYCLES = 200000
)(
    input wire sys_clk,
    output wire pix_clk,
    output reg vs_out,
    output reg hs_out,
    output reg de_out,
    output reg [7:0] r_out,
    output reg [7:0] g_out,
    output reg [7:0] b_out,
    output wire rstn_out,
    output wire iic_tx_scl,
    inout wire iic_tx_sda,
    output wire uart_txd
);
    wire cfg_clk, unused_cam_clk, locked;
    pll u_pll(.clkin1(sys_clk), .clkout0(pix_clk), .clkout1(cfg_clk),
              .clkout2(unused_cam_clk), .lock(locked));
    reg [15:0] reset_delay = 0;
    always @(posedge cfg_clk) begin
        if (!locked) reset_delay <= 0;
        else if (reset_delay != 16'd10000) reset_delay <= reset_delay + 1'b1;
    end
    assign rstn_out = locked && (reset_delay == 16'd10000);

    wire init_over, trigger, write_read, busy, byte_over;
    wire [15:0] controller_address;
    wire [15:0] address;
    wire [7:0] write_data, read_data, device_id;
    wire sda_value, sda_enable;
    ms7210_ctl hdmi_controller(
        .clk(cfg_clk), .rstn(rstn_out), .init_over(init_over),
        .device_id(device_id), .iic_trig(trigger), .w_r(write_read),
        .addr(controller_address), .data_in(write_data), .busy(busy),
        .data_out(read_data), .byte_over(byte_over));
    // Keep the actual 27 MHz PLL ratio, rather than the old "10 MHz" comment.
    iic_dri #(.CLK_FRE(9983193), .IIC_FREQ(400000), .T_WR(1),
              .ADDR_BYTE(2), .LEN_WIDTH(3), .DATA_BYTE(1)) hdmi_i2c(
        .clk(cfg_clk), .rstn(rstn_out), .device_id(device_id),
        .pluse(trigger), .w_r(write_read), .byte_len(4'd1),
        .addr(address), .data_in(write_data), .busy(busy),
        .byte_over(byte_over), .data_out(read_data), .scl(iic_tx_scl),
        .sda_in(iic_tx_sda), .sda_out(sda_value), .sda_out_en(sda_enable));
    assign iic_tx_sda = sda_enable ? sda_value : 1'bz;
    // After the vendor sequence completes, read status/configuration without
    // changing any register. Keep each address stable for the entire transfer.
    // Register names: avmwww/ms7210-linux-driver, commit d7632336 (see README).
    function [15:0] scan_address;
        input [3:0] index;
        begin
            case (index)
                0: scan_address = 16'h0502; // sink connection status
                1: scan_address = 16'h051d; // CTS timing stable, bit 4
                2: scan_address = 16'h0507; // mute controls
                3: scan_address = 16'h0900; // PLL power
                4: scan_address = 16'h0906; // PLL control
                5: scan_address = 16'h090f; // PLL configuration source
                6: scan_address = 16'h091f; // TMDS data drive
                7: scan_address = 16'h0920; // TMDS PHY/clock power
                8: scan_address = 16'h1200; // input sync source
                9: scan_address = 16'h1202; // input RGB/SDR mode
                10: scan_address = 16'h1206; // input sync polarity
                11: scan_address = 16'h120b; // output sync/DE controls
                12: scan_address = 16'h00c0; // digital clock selection
                13: scan_address = 16'h0016; // input enable
                14: scan_address = 16'h0009; // input reset release
                15: scan_address = 16'h1281; // input clock phase
            endcase
        end
    endfunction
    reg scanning = 0;
    reg [3:0] scan_index = 0;
    reg [31:0] scan_count = 0;
    assign address = scanning ? scan_address(scan_index) : controller_address;
    reg busy_d = 0;
    reg [7:0] last_read = 0;
    reg [15:0] last_address = 16'h0003;
    always @(posedge cfg_clk) begin
        busy_d <= busy;
        if (!rstn_out) begin
            last_read <= 0;
            last_address <= 16'h0003;
            scanning <= 0;
            scan_index <= 0;
            scan_count <= 0;
        end else begin
            if (scanning && scan_count < SCAN_CYCLES)
                scan_count <= scan_count + 1'b1;
            if (busy_d && !busy && !write_read) begin
                last_read <= read_data;
                last_address <= address;
                // Hand over only after a completed read, when the vendor FSM
                // is already permanently in read mode.
                if (init_over) scanning <= 1;
                if (scanning && scan_count >= SCAN_CYCLES) begin
                    scan_index <= scan_index + 1'b1;
                    scan_count <= 0;
                end
            end
        end
    end

    wire raw_vs, raw_hs, raw_de, unused_read;
    wire [11:0] x, y;
    reg [1:0] pixel_reset = 0;
    always @(posedge pix_clk or negedge locked) begin
        if (!locked) pixel_reset <= 0;
        else pixel_reset <= {pixel_reset[0], 1'b1};
    end
    sync_vg timing(.clk(pix_clk), .rstn(pixel_reset[1]), .vs_out(raw_vs),
        .hs_out(raw_hs), .de_out(raw_de), .de_re(unused_read),
        .x_act(x), .y_act(y));
    reg [23:0] bar_rgb;
    always @* begin
        if      (x < 12'd160)  bar_rgb = 24'hffffff;
        else if (x < 12'd320)  bar_rgb = 24'hffff00;
        else if (x < 12'd480)  bar_rgb = 24'h00ffff;
        else if (x < 12'd640)  bar_rgb = 24'h00ff00;
        else if (x < 12'd800)  bar_rgb = 24'hff00ff;
        else if (x < 12'd960)  bar_rgb = 24'hff0000;
        else if (x < 12'd1120) bar_rgb = 24'h0000ff;
        else                  bar_rgb = 24'h808080;
    end
    always @(posedge pix_clk) begin
        if (!pixel_reset[1]) begin
            vs_out <= 0; hs_out <= 0; de_out <= 0;
            r_out <= 0; g_out <= 0; b_out <= 0;
        end else begin
            vs_out <= raw_vs; hs_out <= raw_hs; de_out <= raw_de;
            {r_out,g_out,b_out} <= raw_de ? bar_rgb : 24'd0;
        end
    end

    // Informational slow status snapshot; these values do not attest a picture.
    (* ASYNC_REG = "TRUE" *) reg [26:0] status1 = 0, status2 = 0;
    always @(posedge sys_clk) begin
        status1 <= {locked, rstn_out, init_over, last_read, last_address};
        status2 <= status1;
    end
    function [7:0] hex_ascii;
        input [3:0] value;
        begin hex_ascii = value < 10 ? 8'h30 + value : 8'h41 + value - 10; end
    endfunction
    localparam integer BAUD_DIV = (SYS_HZ + 57600) / 115200;
    reg [31:0] report_count = 0;
    reg [271:0] message = 0;
    reg [5:0] bytes_left = 0;
    reg [9:0] tx_shift = 10'h3ff;
    reg [3:0] bits_left = 0;
    reg [15:0] baud_count = 0;
    assign uart_txd = tx_shift[0];
    always @(posedge sys_clk) begin
        if (report_count == REPORT_CYCLES-1) begin
            report_count <= 0;
            if (bytes_left == 0 && bits_left == 0) begin
                message <= {"HDMI720 L=", (8'h30 + {7'd0,status2[26]}),
                    " R=", (8'h30 + {7'd0,status2[25]}),
                    " I=", (8'h30 + {7'd0,status2[24]}),
                    " RD=", hex_ascii(status2[23:20]), hex_ascii(status2[19:16]),
                    " A=", hex_ascii(status2[15:12]), hex_ascii(status2[11:8]),
                    hex_ascii(status2[7:4]), hex_ascii(status2[3:0]), 8'h0d, 8'h0a};
                bytes_left <= 34;
            end
        end else report_count <= report_count + 1'b1;
        if (bits_left != 0) begin
            if (baud_count == 0) begin
                tx_shift <= {1'b1,tx_shift[9:1]};
                bits_left <= bits_left - 1'b1;
                baud_count <= BAUD_DIV-1;
            end else baud_count <= baud_count - 1'b1;
        end else if (bytes_left != 0) begin
            tx_shift <= {1'b1,message[271:264],1'b0};
            message <= {message[263:0],8'd0};
            bytes_left <= bytes_left - 1'b1;
            bits_left <= 10;
            baud_count <= BAUD_DIV-1;
        end
    end
endmodule
`default_nettype wire
