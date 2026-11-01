`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// uart_cam_report -- ASCII telemetry for the camera front end.
//
// Prints one block every ~1 s on the CP210x UART (115200 8N1):
//
//   W=hhhh L=hhhh A=hh S=h C=h\r\n
//      W = measured DE width of one camera line, in pclk
//      L = measured number of lines between two vsync pulses
//      A = cam1_act[3:0] cam2_act[3:0]   (vsync edge counters)
//      S = cmos_init_done[1:0]           (SCCB sequences finished)
//      C = selected channel (1 = cmos1)
//
// followed by 45 rows of 80 characters: the 160x90 thumbnail of the RAW camera
// stream rendered as a luminance ramp. A real scene looks like a picture, noise
// looks like television static, an all-space block means no data at all.
//
// Everything runs on the 24.75 MHz cfg clock, which divides to 115116 baud
// (0.07 % fast) - well inside the 2 % UART tolerance.
//////////////////////////////////////////////////////////////////////////////////
module uart_cam_report #(
    parameter CLK_HZ   = 24750000,
    parameter BAUD     = 115200,
    parameter GAP_CYC  = 20000000
)(
    input               clk,
    input               rstn,

    input      [12:0]   width_v,
    input      [12:0]   lines_v,
    input      [3:0]    act1,
    input      [3:0]    act2,
    input      [1:0]    sccb,
    input               sel,
    input      [8:0]    reg_idx,
    input      [1:0]    pin_state,

    output     [13:0]   raddr,
    input      [15:0]   rdata,

    output reg          txd,
    output reg          txd_b      // independent 0x55 beacon, used to probe the pin
);
    localparam integer DIV = (CLK_HZ + BAUD/2) / BAUD;   // 215

    // ---------------- baud tick ----------------
    reg [15:0] div_cnt;
    reg        tick;
    always @(posedge clk)
    begin
        if (!rstn) begin
            div_cnt <= 16'd0;
            tick    <= 1'b0;
        end
        else if (div_cnt == DIV-1) begin
            div_cnt <= 16'd0;
            tick    <= 1'b1;
        end
        else begin
            div_cnt <= div_cnt + 16'd1;
            tick    <= 1'b0;
        end
    end

    // ---------------- byte transmitter ----------------
    reg        go;
    reg [7:0]  txdata;
    reg        pending;
    reg [3:0]  bitn;
    reg [8:0]  sh;

    wire busy = pending | go | (bitn != 4'd0);

    always @(posedge clk)
    begin
        if (!rstn) begin
            pending <= 1'b0;
            bitn    <= 4'd0;
            sh      <= 9'h1FF;
            txd     <= 1'b1;
        end
        else begin
            if (go) pending <= 1'b1;
            if (tick) begin
                if (bitn == 4'd0) begin
                    if (pending) begin
                        pending <= 1'b0;
                        sh      <= {1'b1, txdata};
                        txd     <= 1'b0;
                        bitn    <= 4'd1;
                    end
                    else
                        txd <= 1'b1;
                end
                else if (bitn <= 4'd8) begin
                    txd  <= sh[0];
                    sh   <= {1'b0, sh[8:1]};
                    bitn <= bitn + 4'd1;
                end
                else begin
                    txd  <= 1'b1;
                    bitn <= 4'd0;
                end
            end
        end
    end


    // ---------------- 0x55 beacon on a second pin ----------------
    reg [15:0] bt_div;
    reg [3:0]  bt_bitn;
    reg [8:0]  bt_sh;
    reg [23:0] bt_gap;
    reg [7:0]  bt_data;

    always @(posedge clk)
    begin
        if (!rstn) begin
            bt_div  <= 16'd0;
            bt_bitn <= 4'd0;
            bt_sh   <= 9'h1FF;
            bt_gap  <= 24'd0;
            txd_b  <= 1'b1;
            bt_data <= 8'h55;
        end
        else if (bt_div == DIV-1) begin
            bt_div <= 16'd0;
            if (bt_bitn == 4'd0) begin
                if (bt_gap == 24'd2000000) begin
                    bt_gap  <= 24'd0;
                    bt_sh   <= {1'b1, bt_data};
                    txd_b  <= 1'b0;
                    bt_bitn <= 4'd1;
                end
                else begin
                    bt_gap <= bt_gap + 24'd1;
                    txd_b <= 1'b1;
                end
            end
            else if (bt_bitn <= 4'd8) begin
                txd_b  <= bt_sh[0];
                bt_sh   <= {1'b0, bt_sh[8:1]};
                bt_bitn <= bt_bitn + 4'd1;
            end
            else begin
                txd_b  <= 1'b1;
                bt_bitn <= 4'd0;
            end
        end
    end

    // ---------------- synchronise the measured values ----------------
    reg [12:0] w1, w2, l1, l2;
    reg [3:0]  a1s, a2s;
    reg [1:0]  ss, ps1, ps2;
    reg        cs;
    reg [8:0]  r1, r2, rs;
    always @(posedge clk)
    begin
        w1 <= width_v;  w2 <= w1;
        l1 <= lines_v;  l2 <= l1;
        a1s <= act1; a2s <= act2; ss <= sccb; cs <= sel;
        ps1 <= pin_state; ps2 <= ps1;
        r1  <= reg_idx;   r2  <= r1;  rs <= r2;
    end

    // ---------------- header text ----------------
    function [7:0] hexd(input [3:0] v);
        hexd = (v < 4'd10) ? (8'h30 + {4'd0, v}) : (8'h37 + {4'd0, v});
    endfunction

    localparam [5:0] HDRLEN = 6'd36;

    reg [5:0] hi;
    reg [7:0] hdr_byte;
    always @(*)
    begin
        case (hi)
          6'd0 : hdr_byte = "W";
          6'd1 : hdr_byte = "=";
          6'd2 : hdr_byte = hexd({3'b0, w2[12]});
          6'd3 : hdr_byte = hexd(w2[11:8]);
          6'd4 : hdr_byte = hexd(w2[7:4]);
          6'd5 : hdr_byte = hexd(w2[3:0]);
          6'd6 : hdr_byte = " ";
          6'd7 : hdr_byte = "L";
          6'd8 : hdr_byte = "=";
          6'd9 : hdr_byte = hexd({3'b0, l2[12]});
          6'd10: hdr_byte = hexd(l2[11:8]);
          6'd11: hdr_byte = hexd(l2[7:4]);
          6'd12: hdr_byte = hexd(l2[3:0]);
          6'd13: hdr_byte = " ";
          6'd14: hdr_byte = "A";
          6'd15: hdr_byte = "=";
          6'd16: hdr_byte = hexd(a1s[3:0]);
          6'd17: hdr_byte = hexd(a2s[3:0]);
          6'd18: hdr_byte = " ";
          6'd19: hdr_byte = "S";
          6'd20: hdr_byte = "=";
          6'd21: hdr_byte = hexd({2'b00, ss});
          6'd22: hdr_byte = " ";
          6'd23: hdr_byte = "C";
          6'd24: hdr_byte = "=";
          6'd25: hdr_byte = cs ? "1" : "0";
          6'd26: hdr_byte = " ";
          6'd27: hdr_byte = "R";
          6'd28: hdr_byte = "=";
          6'd29: hdr_byte = hexd({3'b0, rs[8]});
          6'd30: hdr_byte = hexd(rs[7:4]);
          6'd31: hdr_byte = hexd(rs[3:0]);
          6'd32: hdr_byte = " ";
          6'd33: hdr_byte = "P";
          6'd34: hdr_byte = "=";
          6'd35: hdr_byte = hexd({2'b00, ps2});
          default: hdr_byte = " ";
        endcase
    end

    // ---------------- luminance ramp ----------------
    function [7:0] ramp(input [3:0] v);
        reg [3:0] i;
        begin
            i = (v * 4'd10) >> 4;
            case (i)
              4'd0: ramp = " ";
              4'd1: ramp = ".";
              4'd2: ramp = ":";
              4'd3: ramp = "-";
              4'd4: ramp = "=";
              4'd5: ramp = "+";
              4'd6: ramp = "*";
              4'd7: ramp = "#";
              4'd8: ramp = "%";
              default: ramp = "@";
            endcase
        end
    endfunction

    wire [7:0] sum = {1'b0, rdata[15:11]} + {1'b0, rdata[10:5]} + {1'b0, rdata[4:0]};
    wire [3:0] lum = sum[6:3];

    // ---------------- report sequencer ----------------
    localparam [1:0] ST_GAP = 2'd0, ST_HDR = 2'd1, ST_ROW = 2'd2;

    reg [1:0]  st;
    reg [5:0]  row;
    reg [6:0]  col;
    reg [25:0] gap;

    assign raddr = ({6'd0, row} * 14'd320) + {7'd0, col, 1'b0};

    always @(posedge clk)
    begin
        if (!rstn) begin
            st     <= ST_GAP;
            hi     <= 6'd0;
            row    <= 6'd0;
            col    <= 7'd0;
            gap    <= 26'd0;
            go     <= 1'b0;
            txdata <= 8'h20;
        end
        else begin
            go <= 1'b0;
            case (st)
              ST_GAP: begin
                  if (gap == GAP_CYC-1) begin
                      gap <= 26'd0;
                      hi  <= 6'd0;
                      st  <= ST_HDR;
                  end
                  else
                      gap <= gap + 26'd1;
              end

              ST_HDR: begin
                  if (!busy) begin
                      if (hi == HDRLEN) begin
                          row <= 6'd0;
                          col <= 7'd0;
                          st  <= ST_ROW;
                          txdata <= 8'h0D;
                          go  <= 1'b1;
                      end
                      else begin
                          txdata <= hdr_byte;
                          go     <= 1'b1;
                          hi     <= hi + 6'd1;
                      end
                  end
              end

              ST_ROW: begin
                  if (!busy) begin
                      if (col < 7'd80) begin
                          txdata <= ramp(lum);
                          go     <= 1'b1;
                          col    <= col + 7'd1;
                      end
                      else if (col == 7'd80) begin
                          txdata <= 8'h0D;
                          go     <= 1'b1;
                          col    <= col + 7'd1;
                      end
                      else begin
                          txdata <= 8'h0A;
                          go     <= 1'b1;
                          col    <= 7'd0;
                          if (row == 6'd44) begin
                              st  <= ST_GAP;
                              gap <= 26'd0;
                          end
                          else
                              row <= row + 6'd1;
                      end
                  end
              end

              default: st <= ST_GAP;
            endcase
        end
    end

endmodule
